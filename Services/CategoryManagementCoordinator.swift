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
    case persistenceUnavailable
    case lifecycleUnavailable
    case repository(CategoryRepositoryError)
    case saveFailed
    case savedButRefreshFailed
    case reconciliationRequired

    var errorDescription: String? {
        switch self {
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

    @discardableResult
    func create(name: String) throws -> Bool {
        return try mutate { provider, now in
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
    }

    @discardableResult
    func rename(categoryID: String, name: String) throws -> Bool {
        try mutate { provider, now in
            try provider.categoryRepo.renameCategory(
                id: categoryID,
                workspaceId: self.workspaceID,
                name: name,
                updatedAtISO: now
            )
        }
    }

    @discardableResult
    func setArchived(categoryID: String, isArchived: Bool) throws -> Bool {
        try mutate { provider, now in
            try provider.categoryRepo.setCategoryArchived(
                id: categoryID,
                workspaceId: self.workspaceID,
                isArchived: isArchived,
                updatedAtISO: now
            )
        }
    }

    func deleteUnused(categoryID: String) throws {
        _ = try mutate { provider, _ in
            try provider.categoryRepo.deleteUnusedCategory(id: categoryID, workspaceId: self.workspaceID)
            return true
        }
    }

    @discardableResult
    func setCategory(categoryID: String?, transactionID: String) throws -> Bool {
        try mutate { provider, _ in
            try provider.categoryRepo.setCategory(
                categoryId: categoryID,
                transactionId: transactionID,
                workspaceId: self.workspaceID
            )
        }
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

    private func mutate(_ operation: (DatabaseProvider, String) throws -> Bool) throws -> Bool {
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
