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
#if DEBUG
    case acknowledgementRequired(DevelopmentProfileAcknowledgementChallenge)
    case staleDevelopmentProfile
#endif
    case persistenceUnavailable
    case lifecycleUnavailable
    case repository(CategoryRepositoryError)
    case saveFailed
    case savedButRefreshFailed
    case reconciliationRequired

    var errorDescription: String? {
        switch self {
#if DEBUG
        case .acknowledgementRequired:
            return "Acknowledge the active development database profile before changing categories."
        case .staleDevelopmentProfile:
            return "The active development database changed. Start the category action again."
#endif
        case .persistenceUnavailable:
            return "Categories are unavailable while persistence is unavailable."
        case .lifecycleUnavailable:
            return "Categories are unavailable while the database lifecycle is changing."
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
    @discardableResult func setCategory(categoryID: String?, transactionID: String) throws -> Bool
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
#if DEBUG
    private let acknowledgementGate: DevelopmentProfileAcknowledgementGate
#endif

#if DEBUG
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
#if DEBUG
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
#if DEBUG
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
#if DEBUG
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
#if DEBUG
        _ = try mutate(protectedAction: .categoryDelete, operation)
#else
        _ = try mutate(operation)
#endif
    }

    @discardableResult
    func setCategory(categoryID: String?, transactionID: String) throws -> Bool {
        let operation: (DatabaseProvider, String) throws -> Bool = { provider, _ in
            try provider.categoryRepo.setCategory(
                categoryId: categoryID,
                transactionId: transactionID,
                workspaceId: self.workspaceID
            )
        }
#if DEBUG
        return try mutate(
            protectedAction: categoryID == nil ? .transactionCategoryClear : .transactionCategoryAssignment,
            operation
        )
#else
        return try mutate(operation)
#endif
    }

    func retryCanonicalHydration() throws -> CategoryReconciliationRetryResult {
#if DEBUG
        let lease: DevelopmentDatabaseActivityLease
        do {
            lease = try DevelopmentDatabaseActivityGate.shared.begin(.repositoryWrite)
        } catch {
            throw CategoryManagementCoordinatorError.lifecycleUnavailable
        }
        defer { lease.finish() }
#endif

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

#if DEBUG
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
        try performMutation(using: provider(), operation)
    }
#endif

    private func performMutation(
        using currentProvider: DatabaseProvider,
        _ operation: (DatabaseProvider, String) throws -> Bool
    ) throws -> Bool {
        guard currentProvider.persistenceState.isUsable else {
            throw CategoryManagementCoordinatorError.persistenceUnavailable
        }
        guard !reconciliationGate.isBlocked(for: currentProvider.generationToken) else {
            throw CategoryManagementCoordinatorError.reconciliationRequired
        }

        let changed: Bool
        do {
            changed = try operation(currentProvider, Self.timestamp())
        } catch let error as CategoryRepositoryError {
            throw CategoryManagementCoordinatorError.repository(error)
        } catch {
            throw CategoryManagementCoordinatorError.saveFailed
        }
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
