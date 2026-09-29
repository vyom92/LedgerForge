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
    func markCreditCardHistoryOnly(accountId: String, workspaceId: String) throws -> Bool
}

/// Coordinates bounded owner account metadata writes with canonical runtime
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

    /// Records the owner's closed-and-settled decision without altering source
    /// balances, due dates, transactions, or historical import eligibility.
    @discardableResult
    func markCreditCardHistoryOnly(accountId: String, workspaceId: String) throws -> Bool {
        let lease: DatabaseActivityLease
        do { lease = try DatabaseActivityGate.shared.begin(.repositoryWrite) }
        catch { throw AccountMetadataCoordinatorError.saveFailed }
        defer { lease.finish() }
        let currentProvider = provider()
#if DEBUG
        do {
            try acknowledgementGate.requireAuthorization(
                for: .creditCardHistoryOnlyMutation,
                providerGeneration: currentProvider.generationToken
            )
        } catch DevelopmentProfileAcknowledgementError.acknowledgementRequired(let challenge) {
            throw AccountMetadataCoordinatorError.acknowledgementRequired(challenge)
        } catch DevelopmentProfileAcknowledgementError.staleGeneration {
            throw AccountMetadataCoordinatorError.staleDevelopmentProfile
        } catch { throw AccountMetadataCoordinatorError.persistenceUnavailable }
#endif
        guard currentProvider.persistenceState.isUsable else {
            throw AccountMetadataCoordinatorError.persistenceUnavailable
        }
        let changed: Bool
        do {
            changed = try currentProvider.accountRepo.markCreditCardHistoryOnly(
                accountId: accountId, workspaceId: workspaceId,
                markedAtISO: ISO8601DateFormatter().string(from: Date())
            )
        } catch { throw AccountMetadataCoordinatorError.saveFailed }
        // Also refresh an idempotent retry after a previous refresh failure.
        do { _ = try forcedHydration(currentProvider, workspaceId) }
        catch { throw AccountMetadataCoordinatorError.savedButRefreshFailed }
        return changed
    }

    func updateDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool {
        let lifecycleLease: DatabaseActivityLease
        do {
            lifecycleLease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
        } catch {
            developerConsole?.error(.runtime, "Account display-name update blocked by database lifecycle")
            throw AccountMetadataCoordinatorError.saveFailed
        }
        defer { lifecycleLease.finish() }

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
