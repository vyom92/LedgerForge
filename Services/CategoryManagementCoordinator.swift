// LedgerForge
// CategoryManagementCoordinator.swift

import Foundation

/// Process-local protection for category metadata that is durably committed
/// while its canonical runtime reconciliation is still outstanding.
final class CategoryReconciliationGate {
    static let shared = CategoryReconciliationGate()

    private let lock = NSLock()
    private var pendingProviderGeneration: ProviderGenerationToken?
    private var lastCanonicalHydrationProviderGeneration: ProviderGenerationToken?

    var hasPendingReconciliation: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingProviderGeneration != nil
    }

    func isBlocked(for providerGeneration: ProviderGenerationToken) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingProviderGeneration == providerGeneration
    }

    func requireReconciliation(for providerGeneration: ProviderGenerationToken) {
        lock.lock()
        pendingProviderGeneration = providerGeneration
        lock.unlock()
    }

    /// A successful canonical hydration is the only operation that clears the
    /// pending state. The generation argument records which provider was
    /// reconciled, while allowing successful replacement-provider hydration to
    /// retire stale state from the prior generation.
    func clearAfterCanonicalHydration(for providerGeneration: ProviderGenerationToken) {
        lock.lock()
        guard pendingProviderGeneration != nil else {
            lock.unlock()
            return
        }
        lastCanonicalHydrationProviderGeneration = providerGeneration
        pendingProviderGeneration = nil
        lock.unlock()
    }

    func resetForTesting() {
        lock.lock()
        pendingProviderGeneration = nil
        lastCanonicalHydrationProviderGeneration = nil
        lock.unlock()
    }
}

enum CategoryReconciliationRetryResult: Equatable {
    case notRequired
    case succeeded
    case failed
}

enum CategoryManagementCoordinatorError: Error, Equatable, LocalizedError {
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
    case acknowledgementRequired(DevelopmentProfileAcknowledgementChallenge)
    case staleDevelopmentProfile
#endif
    case persistenceUnavailable
    case lifecycleUnavailable
    case repository(CategoryRepositoryError)
    case automation(CategoryAutomationError)
    case saveFailed
    case savedButRefreshFailed
    case reconciliationRequired

    var errorDescription: String? {
        switch self {
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        case .acknowledgementRequired:
            return "Acknowledge the active development database profile before changing categories."
        case .staleDevelopmentProfile:
            return "The active development database changed. Start the category action again."
#endif
        case .persistenceUnavailable:
            return "Categories are unavailable while persistence is unavailable."
        case .lifecycleUnavailable:
            return "Categories are unavailable while the database lifecycle is changing."
        case .automation(let error):
            return error.localizedDescription
        case .repository(let error):
            return error.localizedDescription
        case .saveFailed:
            return "The category change could not be saved."
        case .savedButRefreshFailed:
            return "The category change was saved, but LedgerForge could not refresh its runtime state. Later category changes are temporarily blocked until you retry refresh."
        case .reconciliationRequired:
            return "Category changes are temporarily blocked because runtime refresh is required. Retry refresh before making another change."
        }
    }
}

enum CategoryManagementPresentation {
    static func message(for error: Error) -> String {
        guard let error = error as? CategoryManagementCoordinatorError else {
            return "The category action could not be completed."
        }
        return error.errorDescription ?? "The category action could not be completed."
    }
}

@MainActor
protocol CategoryManaging: AnyObject {
    @discardableResult func create(name: String) throws -> Bool
    @discardableResult func rename(categoryID: String, name: String) throws -> Bool
    @discardableResult func setArchived(categoryID: String, isArchived: Bool) throws -> Bool
    func deleteUnused(categoryID: String) throws
    @discardableResult func setCategory(categoryID: String?, transactionID: String) async throws -> Bool
    func applyCategoryBatch(_ review: CategoryBatchReview, expectedGeneration: ProviderGenerationToken) async throws -> CategoryBatchReceipt
    func retryCanonicalHydration() throws -> CategoryReconciliationRetryResult
}

/// Coordinates one targeted category metadata mutation and the required
/// canonical repository-to-runtime reconciliation.
@MainActor
final class CategoryManagementCoordinator: CategoryManaging {
    private let provider: () -> DatabaseProvider
    private let workspaceID: String
    private let categoryStore: CategoryStore
    private let reconciliationGate: CategoryReconciliationGate
    private let forcedHydration: (DatabaseProvider, CategoryStore, String) throws -> RepositoryStoreHydrationResult
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
    private let acknowledgementGate: DevelopmentProfileAcknowledgementGate
#endif

#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
    init(
        provider: (() -> DatabaseProvider)? = nil,
        workspaceID: String = "default-workspace",
        categoryStore: CategoryStore? = nil,
        reconciliationGate: CategoryReconciliationGate? = nil,
        forcedHydration: ((DatabaseProvider, CategoryStore, String) throws -> RepositoryStoreHydrationResult)? = nil,
        acknowledgementGate: DevelopmentProfileAcknowledgementGate? = nil
    ) {
        let resolvedGate = reconciliationGate ?? CategoryReconciliationGate.shared
        self.provider = provider ?? { DatabaseProvider.shared }
        self.workspaceID = workspaceID
        self.categoryStore = categoryStore ?? .shared
        self.reconciliationGate = resolvedGate
        self.acknowledgementGate = acknowledgementGate ?? .shared
        self.forcedHydration = forcedHydration ?? { provider, categoryStore, workspaceID in
            try RepositoryStoreHydrator(
                databaseProvider: provider,
                categoryStore: categoryStore,
                workspaceId: workspaceID,
                categoryReconciliationGate: resolvedGate,
                participatesInLifecycleGate: false
            ).hydrateIfNeeded(forceRefresh: true)
        }
    }
#else
    init(
        provider: (() -> DatabaseProvider)? = nil,
        workspaceID: String = "default-workspace",
        categoryStore: CategoryStore? = nil,
        reconciliationGate: CategoryReconciliationGate? = nil,
        forcedHydration: ((DatabaseProvider, CategoryStore, String) throws -> RepositoryStoreHydrationResult)? = nil
    ) {
        let resolvedGate = reconciliationGate ?? CategoryReconciliationGate.shared
        self.provider = provider ?? { DatabaseProvider.shared }
        self.workspaceID = workspaceID
        self.categoryStore = categoryStore ?? .shared
        self.reconciliationGate = resolvedGate
        self.forcedHydration = forcedHydration ?? { provider, categoryStore, workspaceID in
            try RepositoryStoreHydrator(
                databaseProvider: provider,
                categoryStore: categoryStore,
                workspaceId: workspaceID,
                categoryReconciliationGate: resolvedGate,
                participatesInLifecycleGate: false
            ).hydrateIfNeeded(forceRefresh: true)
        }
    }
#endif

    @discardableResult
    func create(name: String) throws -> Bool {
        let operation: (DatabaseProvider, String) throws -> Bool = { provider, now in
            let validated = try CategoryName.validated(name)
            if try provider.workspaceRepo.workspace(id: self.workspaceID) == nil {
                _ = try provider.workspaceRepo.upsertWorkspace(WorkspaceDTO(
                    id: self.workspaceID,
                    name: "Personal",
                    createdAtISO: now
                ))
            }
            _ = try provider.categoryRepo.createCategory(CategoryDTO(
                workspaceId: self.workspaceID,
                name: validated.display,
                normalizedName: validated.normalized,
                createdAtISO: now
            ))
            return true
        }
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        return try mutate(protectedAction: .categoryCreate, operation)
#else
        return try mutate(operation)
#endif
    }

    @discardableResult
    func rename(categoryID: String, name: String) throws -> Bool {
        let operation: (DatabaseProvider, String) throws -> Bool = { provider, now in
            try provider.categoryRepo.renameCategory(
                id: categoryID,
                workspaceId: self.workspaceID,
                name: name,
                updatedAtISO: now
            )
        }
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        return try mutate(protectedAction: .categoryRename, operation)
#else
        return try mutate(operation)
#endif
    }

    @discardableResult
    func setArchived(categoryID: String, isArchived: Bool) throws -> Bool {
        let operation: (DatabaseProvider, String) throws -> Bool = { provider, now in
            try provider.categoryRepo.setCategoryArchived(
                id: categoryID,
                workspaceId: self.workspaceID,
                isArchived: isArchived,
                updatedAtISO: now
            )
        }
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        return try mutate(
            protectedAction: isArchived ? .categoryArchive : .categoryRestore,
            operation
        )
#else
        return try mutate(operation)
#endif
    }

    func deleteUnused(categoryID: String) throws {
        let operation: (DatabaseProvider, String) throws -> Bool = { provider, _ in
            try provider.categoryRepo.deleteUnusedCategory(id: categoryID, workspaceId: self.workspaceID)
            return true
        }
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        _ = try mutate(protectedAction: .categoryDelete, operation)
#else
        _ = try mutate(operation)
#endif
    }

    @discardableResult
    func setCategory(categoryID: String?, transactionID: String) async throws -> Bool {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.categoryOverrideMutation)
        defer { GmailQualificationTiming.end(.categoryOverrideMutation, started: timing) }
#endif
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        let lease: DevelopmentDatabaseActivityLease
        do { lease = try DevelopmentDatabaseActivityGate.shared.begin(.repositoryWrite) }
        catch { throw CategoryManagementCoordinatorError.lifecycleUnavailable }
        defer { lease.finish() }
        let currentProvider = provider()
        do {
            try acknowledgementGate.requireAuthorization(
                for: categoryID == nil ? .transactionCategoryClear : .transactionCategoryAssignment,
                providerGeneration: currentProvider.generationToken)
        } catch DevelopmentProfileAcknowledgementError.acknowledgementRequired(let challenge) {
            throw CategoryManagementCoordinatorError.acknowledgementRequired(challenge)
        } catch DevelopmentProfileAcknowledgementError.staleGeneration {
            throw CategoryManagementCoordinatorError.staleDevelopmentProfile
        } catch { throw CategoryManagementCoordinatorError.persistenceUnavailable }
#else
        let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
        defer { lease.finish() }
        let currentProvider = provider()
#endif
        let changed = try saveMutation(using: currentProvider) { provider, _ in
            try provider.categoryRepo.setCategory(categoryId: categoryID, transactionId: transactionID, workspaceId: self.workspaceID)
        }
        guard changed else { return false }
        try await reconcileSavedCategoryMetadata(using: currentProvider)
        return true
    }

    func applyCategoryBatch(_ review: CategoryBatchReview, expectedGeneration: ProviderGenerationToken) async throws -> CategoryBatchReceipt {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.categoryOverrideMutation)
        defer { GmailQualificationTiming.end(.categoryOverrideMutation, started: timing) }
#endif
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        let lease: DevelopmentDatabaseActivityLease
        do { lease = try DevelopmentDatabaseActivityGate.shared.begin(.repositoryWrite) }
        catch { throw CategoryManagementCoordinatorError.lifecycleUnavailable }
        defer { lease.finish() }
        let currentProvider = provider()
        do {
            try acknowledgementGate.requireAuthorization(
                for: review.categoryID == nil ? .transactionCategoryClear : .transactionCategoryAssignment,
                providerGeneration: currentProvider.generationToken)
        } catch DevelopmentProfileAcknowledgementError.acknowledgementRequired(let challenge) {
            throw CategoryManagementCoordinatorError.acknowledgementRequired(challenge)
        } catch DevelopmentProfileAcknowledgementError.staleGeneration {
            throw CategoryManagementCoordinatorError.staleDevelopmentProfile
        } catch { throw CategoryManagementCoordinatorError.persistenceUnavailable }
#else
        let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
        defer { lease.finish() }
        let currentProvider = provider()
#endif
        var receipt: CategoryBatchReceipt?
        let changed = try saveMutation(using: currentProvider) { provider, _ in
            guard provider.generationToken == expectedGeneration, review.workspaceID == self.workspaceID else {
                throw CategoryAutomationError.stalePreview
            }
            let result = try provider.categoryRepo.applyCategoryBatch(review)
            receipt = result
            return !result.changedIDs.isEmpty
        }
        if changed { try await reconcileSavedCategoryMetadata(using: currentProvider) }
        guard let receipt else { throw CategoryManagementCoordinatorError.saveFailed }
        return receipt
    }

    func saveRule(_ rule: CategoryRule, previousVersion: Int?, expectedGeneration: ProviderGenerationToken) throws {
        let operation: (DatabaseProvider, String) throws -> Bool = { provider, _ in
            guard provider.generationToken == expectedGeneration else { throw CategoryAutomationError.stalePreview }
            try provider.categoryRepo.saveRule(rule, previousVersion: previousVersion)
            return true
        }
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        _ = try mutate(protectedAction: .categoryCreate, operation)
#else
        _ = try mutate(operation)
#endif
    }

    @discardableResult
    func setSpendingSuppressed(_ suppressed: Bool, transactionID: String,
                               expected: TransactionSpendingIntent?, expectedGeneration: ProviderGenerationToken) throws -> Bool {
        let operation: (DatabaseProvider, String) throws -> Bool = { provider, _ in
            guard provider.generationToken == expectedGeneration else { throw CategoryAutomationError.stalePreview }
            return try provider.categoryRepo.setSpendingSuppressed(suppressed, transactionID: transactionID,
                workspaceId: self.workspaceID, expected: expected)
        }
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        return try mutate(protectedAction: .transactionCategoryAssignment, operation)
#else
        return try mutate(operation)
#endif
    }

    func deleteRule(_ rule: CategoryRule, expectedGeneration: ProviderGenerationToken) throws {
        let operation: (DatabaseProvider, String) throws -> Bool = { provider, _ in
            guard provider.generationToken == expectedGeneration else { throw CategoryAutomationError.stalePreview }
            try provider.categoryRepo.deleteRule(id: rule.id, workspaceId: self.workspaceID, version: rule.version)
            return true
        }
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        _ = try mutate(protectedAction: .categoryDelete, operation)
#else
        _ = try mutate(operation)
#endif
    }

    @discardableResult
    func applyEvaluation(_ evaluation: CategoryEvaluation, historical: Bool, expectedGeneration: ProviderGenerationToken) async throws -> Bool {
        try await applyEvaluationOutcome(evaluation, historical: historical, expectedGeneration: expectedGeneration).changed
    }

    func applyReviewedEvaluation(_ preview: CategoryHistoricalPreview, expectedGeneration: ProviderGenerationToken) async throws -> CategoryApplyReceipt {
        let outcome = try await applyEvaluationOutcome(preview.evaluation, historical: true,
            expectedGeneration: expectedGeneration, review: preview)
        guard let receipt = outcome.receipt else { throw CategoryManagementCoordinatorError.saveFailed }
        return receipt
    }

    private func applyEvaluationOutcome(_ evaluation: CategoryEvaluation, historical: Bool,
        expectedGeneration: ProviderGenerationToken, review: CategoryHistoricalPreview? = nil) async throws -> (changed: Bool, receipt: CategoryApplyReceipt?) {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.categoryApplyMutation, count: evaluation.decisions.count)
        defer { GmailQualificationTiming.end(.categoryApplyMutation, started: timing, count: evaluation.decisions.count) }
#endif
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        let lease: DevelopmentDatabaseActivityLease
        do { lease = try DevelopmentDatabaseActivityGate.shared.begin(.repositoryWrite) }
        catch { throw CategoryManagementCoordinatorError.lifecycleUnavailable }
        defer { lease.finish() }
        let currentProvider = provider()
        do {
            try acknowledgementGate.requireAuthorization(for: .transactionCategoryAssignment,
                providerGeneration: currentProvider.generationToken)
        } catch DevelopmentProfileAcknowledgementError.acknowledgementRequired(let challenge) {
            throw CategoryManagementCoordinatorError.acknowledgementRequired(challenge)
        } catch DevelopmentProfileAcknowledgementError.staleGeneration {
            throw CategoryManagementCoordinatorError.staleDevelopmentProfile
        } catch { throw CategoryManagementCoordinatorError.persistenceUnavailable }
#else
        let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
        defer { lease.finish() }
        let currentProvider = provider()
#endif
        try requireSavePreconditions(using: currentProvider)
        let changed: Bool
        var receipt: CategoryApplyReceipt?
        do {
            guard currentProvider.generationToken == expectedGeneration else { throw CategoryAutomationError.stalePreview }
            let hydrator = RepositoryStoreHydrator(databaseProvider: currentProvider, categoryStore: categoryStore,
                workspaceId: workspaceID, categoryReconciliationGate: reconciliationGate)
            if let context = try hydrator.categoryOverrideContextIfCurrent(),
               let request = currentProvider.categoryApplyWriteRequest(workspaceID: workspaceID),
               request.read.binding == context.request.binding {
                let expected = context.witness, canonical = categoryStore.snapshot
                let worker = Task.detached(priority: .userInitiated) {
                    let prepared = try await request.read.prepare(expected: expected)
                    return try request.applyWithReceipt(evaluation, historical: historical, prepared: prepared,
                        expected: expected, canonical: canonical, review: review)
                }
                let result = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                receipt = result; changed = !result.changedIDs.isEmpty
            } else {
                // Custom/historical contexts retain the existing repository path.
#if DEBUG
                let timing = GmailQualificationTiming.begin(.categoryApply, count: evaluation.decisions.count)
                defer { GmailQualificationTiming.end(.categoryApply, started: timing, count: evaluation.decisions.count) }
#endif
                if let review {
                    let result = try currentProvider.categoryRepo.applyReviewedCategoryEvaluation(review, workspaceId: workspaceID)
                    receipt = result; changed = !result.changedIDs.isEmpty
                } else {
                    changed = try currentProvider.categoryRepo.applyCategoryEvaluation(evaluation, workspaceId: workspaceID, historical: historical) > 0
                }
            }
        } catch let error as CategoryAutomationError {
            throw CategoryManagementCoordinatorError.automation(error)
        } catch let error as CategoryRepositoryError {
            throw CategoryManagementCoordinatorError.repository(error)
        } catch { throw CategoryManagementCoordinatorError.saveFailed }
        if changed { try await reconcileSavedCategoryMetadata(using: currentProvider) }
        return (changed, receipt)
    }

    private func reconcileSavedCategoryMetadata(using currentProvider: DatabaseProvider) async throws {
        do {
            let hydrator = RepositoryStoreHydrator(databaseProvider: currentProvider, categoryStore: categoryStore,
                workspaceId: workspaceID, categoryReconciliationGate: reconciliationGate)
            if try await hydrator.refreshCategoryOverrideIfCurrent() == false {
                _ = try forcedHydration(currentProvider, categoryStore, workspaceID)
                reconciliationGate.clearAfterCanonicalHydration(for: currentProvider.generationToken)
            }
        } catch {
            reconciliationGate.requireReconciliation(for: currentProvider.generationToken)
            throw CategoryManagementCoordinatorError.savedButRefreshFailed
        }
    }

    func retryCanonicalHydration() throws -> CategoryReconciliationRetryResult {
        let lease: DatabaseActivityLease
        do {
            lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
        } catch {
            throw CategoryManagementCoordinatorError.lifecycleUnavailable
        }
        defer { lease.finish() }

        let currentProvider = provider()
        guard currentProvider.persistenceState.isUsable else {
            throw CategoryManagementCoordinatorError.persistenceUnavailable
        }
        guard reconciliationGate.hasPendingReconciliation else { return .notRequired }

        do {
            _ = try forcedHydration(currentProvider, categoryStore, workspaceID)
            reconciliationGate.clearAfterCanonicalHydration(for: currentProvider.generationToken)
            return .succeeded
        } catch {
            return .failed
        }
    }

#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
    private func mutate(
        protectedAction: DevelopmentProtectedAction,
        _ operation: (DatabaseProvider, String) throws -> Bool
    ) throws -> Bool {
        let lease: DevelopmentDatabaseActivityLease
        do {
            lease = try DevelopmentDatabaseActivityGate.shared.begin(.repositoryWrite)
        } catch {
            throw CategoryManagementCoordinatorError.lifecycleUnavailable
        }
        defer { lease.finish() }

        let currentProvider = provider()
        do {
            try acknowledgementGate.requireAuthorization(
                for: protectedAction,
                providerGeneration: currentProvider.generationToken
            )
        } catch DevelopmentProfileAcknowledgementError.acknowledgementRequired(let challenge) {
            throw CategoryManagementCoordinatorError.acknowledgementRequired(challenge)
        } catch DevelopmentProfileAcknowledgementError.staleGeneration {
            throw CategoryManagementCoordinatorError.staleDevelopmentProfile
        } catch {
            throw CategoryManagementCoordinatorError.persistenceUnavailable
        }
        return try performMutation(using: currentProvider, operation)
    }
#else
    private func mutate(
        _ operation: (DatabaseProvider, String) throws -> Bool
    ) throws -> Bool {
        let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
        defer { lease.finish() }
        return try performMutation(using: provider(), operation)
    }
#endif

    private func requireSavePreconditions(using currentProvider: DatabaseProvider) throws {
        guard currentProvider.persistenceState.isUsable else {
            throw CategoryManagementCoordinatorError.persistenceUnavailable
        }
        guard !reconciliationGate.isBlocked(for: currentProvider.generationToken) else {
            throw CategoryManagementCoordinatorError.reconciliationRequired
        }
    }

    private func saveMutation(using currentProvider: DatabaseProvider,
                              _ operation: (DatabaseProvider, String) throws -> Bool) throws -> Bool {
        try requireSavePreconditions(using: currentProvider)

        do {
            return try operation(currentProvider, Self.timestamp())
        } catch let error as CategoryAutomationError {
            throw CategoryManagementCoordinatorError.automation(error)
        } catch let error as CategoryRepositoryError {
            throw CategoryManagementCoordinatorError.repository(error)
        } catch {
            throw CategoryManagementCoordinatorError.saveFailed
        }
    }

    private func performMutation(
        using currentProvider: DatabaseProvider,
        _ operation: (DatabaseProvider, String) throws -> Bool
    ) throws -> Bool {
        let changed = try saveMutation(using: currentProvider, operation)
        guard changed else { return false }

        do {
            _ = try forcedHydration(currentProvider, categoryStore, workspaceID)
            reconciliationGate.clearAfterCanonicalHydration(for: currentProvider.generationToken)
            return true
        } catch {
            reconciliationGate.requireReconciliation(for: currentProvider.generationToken)
            throw CategoryManagementCoordinatorError.savedButRefreshFailed
        }
    }

    nonisolated private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
