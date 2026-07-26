// LedgerForge
// CategoryManagementCoordinator.swift

import Foundation

enum CategoryManagementCoordinatorError: Error, Equatable, LocalizedError {
    case persistenceUnavailable
    case lifecycleUnavailable
    case repository(CategoryRepositoryError)
    case saveFailed
    case savedButRefreshFailed

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
            return "The category change was saved, but LedgerForge could not refresh its runtime state."
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
}

/// Coordinates one targeted category metadata mutation and the required
/// canonical repository-to-runtime reconciliation.
@MainActor
final class CategoryManagementCoordinator: CategoryManaging {
    private let provider: () -> DatabaseProvider
    private let workspaceID: String
    private let categoryStore: CategoryStore

    init(
        provider: (() -> DatabaseProvider)? = nil,
        workspaceID: String = "default-workspace",
        categoryStore: CategoryStore? = nil
    ) {
        self.provider = provider ?? { DatabaseProvider.shared }
        self.workspaceID = workspaceID
        self.categoryStore = categoryStore ?? .shared
    }

    @discardableResult
    func create(name: String) throws -> Bool {
        let validated = try CategoryName.validated(name)
        return try mutate { provider, now in
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
            _ = try RepositoryStoreHydrator(
                databaseProvider: currentProvider,
                categoryStore: categoryStore,
                workspaceId: workspaceID,
                participatesInLifecycleGate: false
            ).hydrateIfNeeded(forceRefresh: true)
            return true
        } catch {
            throw CategoryManagementCoordinatorError.savedButRefreshFailed
        }
    }

    nonisolated private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
