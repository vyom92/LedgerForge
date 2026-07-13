// LedgerForge
// AccountMetadataCoordinator.swift

import Foundation

enum AccountMetadataCoordinatorError: Error, Equatable {
    case saveFailed
    case savedButRefreshFailed
}

protocol AccountMetadataCoordinating: AnyObject {
    func updateDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool
}

/// Coordinates the bounded account display-name write with canonical runtime
/// refresh. It never mutates runtime stores directly.
final class AccountMetadataCoordinator: AccountMetadataCoordinating {

    private let accountRepository: AccountRepository
    private let hydrator: RepositoryStoreHydrator
    private let developerConsole: DeveloperConsole?

    convenience init(
        databaseProvider: DatabaseProvider = .shared,
        workspaceId: String = "default-workspace",
        developerConsole: DeveloperConsole? = .shared
    ) {
        self.init(
            accountRepository: databaseProvider.accountRepo,
            hydrator: RepositoryStoreHydrator(databaseProvider: databaseProvider, workspaceId: workspaceId),
            developerConsole: developerConsole
        )
    }

    init(
        accountRepository: AccountRepository,
        hydrator: RepositoryStoreHydrator,
        developerConsole: DeveloperConsole? = .shared
    ) {
        self.accountRepository = accountRepository
        self.hydrator = hydrator
        self.developerConsole = developerConsole
    }

    func updateDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool {
        developerConsole?.info(.runtime, "Account display-name update requested")

        let didUpdate: Bool
        do {
            didUpdate = try accountRepository.updateAccountDisplayName(
                accountId: accountId,
                workspaceId: workspaceId,
                displayName: displayName
            )
        } catch {
            developerConsole?.error(.runtime, "Account display-name update failed")
            throw AccountMetadataCoordinatorError.saveFailed
        }

        guard didUpdate else {
            return false
        }

        developerConsole?.info(.runtime, "Account display-name update succeeded")
        do {
            _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
            return true
        } catch {
            developerConsole?.error(.runtime, "Account-detail hydration failed")
            throw AccountMetadataCoordinatorError.savedButRefreshFailed
        }
    }
}
