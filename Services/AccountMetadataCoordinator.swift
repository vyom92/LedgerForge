// LedgerForge
// AccountMetadataCoordinator.swift

import Foundation

enum AccountMetadataCoordinatorError: Error, Equatable {
#if DEBUG
    case acknowledgementRequired(DevelopmentProfileAcknowledgementChallenge)
    case staleDevelopmentProfile
#endif
    case persistenceUnavailable
    case saveFailed
    case savedButRefreshFailed
}

protocol AccountMetadataCoordinating: AnyObject {
    func updateDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool
}

/// Coordinates the bounded account display-name write with canonical runtime
/// refresh. It never mutates runtime stores directly.
final class AccountMetadataCoordinator: AccountMetadataCoordinating {

    private let provider: () -> DatabaseProvider
    private let forcedHydration: (DatabaseProvider, String) throws -> RepositoryStoreHydrationResult
    private let developerConsole: DeveloperConsole?
#if DEBUG
    private let acknowledgementGate: DevelopmentProfileAcknowledgementGate
#endif

#if DEBUG
    convenience init(
        databaseProvider: DatabaseProvider? = nil,
        developerConsole: DeveloperConsole? = .shared,
        acknowledgementGate: DevelopmentProfileAcknowledgementGate? = nil
    ) {
        let providerResolver: () -> DatabaseProvider
        if let databaseProvider {
            providerResolver = { databaseProvider }
        } else {
            providerResolver = { DatabaseProvider.shared }
        }
        self.init(
            provider: providerResolver,
            developerConsole: developerConsole,
            acknowledgementGate: acknowledgementGate ?? .shared
        )
    }

    init(
        provider: @escaping () -> DatabaseProvider,
        developerConsole: DeveloperConsole? = .shared,
        forcedHydration: ((DatabaseProvider, String) throws -> RepositoryStoreHydrationResult)? = nil,
        acknowledgementGate: DevelopmentProfileAcknowledgementGate? = nil
    ) {
        self.provider = provider
        self.developerConsole = developerConsole
        self.acknowledgementGate = acknowledgementGate ?? .shared
        self.forcedHydration = forcedHydration ?? { provider, workspaceID in
            try RepositoryStoreHydrator(
                databaseProvider: provider,
                workspaceId: workspaceID,
                participatesInLifecycleGate: false
            ).hydrateIfNeeded(forceRefresh: true)
        }
    }
#else
    convenience init(
        databaseProvider: DatabaseProvider? = nil,
        developerConsole: DeveloperConsole? = .shared
    ) {
        let providerResolver: () -> DatabaseProvider
        if let databaseProvider {
            providerResolver = { databaseProvider }
        } else {
            providerResolver = { DatabaseProvider.shared }
        }
        self.init(
            provider: providerResolver,
            developerConsole: developerConsole
        )
    }

    init(
        provider: @escaping () -> DatabaseProvider,
        developerConsole: DeveloperConsole? = .shared,
        forcedHydration: ((DatabaseProvider, String) throws -> RepositoryStoreHydrationResult)? = nil
    ) {
        self.provider = provider
        self.developerConsole = developerConsole
        self.forcedHydration = forcedHydration ?? { provider, workspaceID in
            try RepositoryStoreHydrator(
                databaseProvider: provider,
                workspaceId: workspaceID,
                participatesInLifecycleGate: false
            ).hydrateIfNeeded(forceRefresh: true)
        }
    }
#endif

    func updateDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool {
#if DEBUG
        let lifecycleLease: DevelopmentDatabaseActivityLease
        do {
            lifecycleLease = try DevelopmentDatabaseActivityGate.shared.begin(.repositoryWrite)
        } catch {
            developerConsole?.error(.runtime, "Account display-name update blocked by database lifecycle")
            throw AccountMetadataCoordinatorError.saveFailed
        }
        defer { lifecycleLease.finish() }
#endif

        let currentProvider = provider()
#if DEBUG
        do {
            try acknowledgementGate.requireAuthorization(
                for: .accountDisplayNameMutation,
                providerGeneration: currentProvider.generationToken
            )
        } catch DevelopmentProfileAcknowledgementError.acknowledgementRequired(let challenge) {
            developerConsole?.warning(.runtime, "Account display-name update requires development profile acknowledgement")
            throw AccountMetadataCoordinatorError.acknowledgementRequired(challenge)
        } catch DevelopmentProfileAcknowledgementError.staleGeneration {
            throw AccountMetadataCoordinatorError.staleDevelopmentProfile
        } catch {
            throw AccountMetadataCoordinatorError.persistenceUnavailable
        }
#endif
        guard currentProvider.persistenceState.isUsable else {
            developerConsole?.error(.runtime, "Account display-name update blocked because persistence is unavailable")
            throw AccountMetadataCoordinatorError.persistenceUnavailable
        }
        developerConsole?.info(.runtime, "Account display-name update requested")

        let didUpdate: Bool
        do {
            didUpdate = try currentProvider.accountRepo.updateAccountDisplayName(
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
            _ = try forcedHydration(currentProvider, workspaceId)
            return true
        } catch {
            developerConsole?.error(.runtime, "Account-detail hydration failed")
            throw AccountMetadataCoordinatorError.savedButRefreshFailed
        }
    }
}
