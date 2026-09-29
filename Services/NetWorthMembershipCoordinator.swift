import Foundation

/// One synchronous metadata transaction followed by the ordinary canonical
/// refresh. The view never changes a financial total optimistically.
final class NetWorthMembershipCoordinator {
    private let provider: () -> DatabaseProvider
    private let forcedHydration: (DatabaseProvider, String) throws -> Void
#if DEBUG
    private let acknowledgementGate: DevelopmentProfileAcknowledgementGate

    init(
        provider: @escaping () -> DatabaseProvider = { .shared },
        forcedHydration: ((DatabaseProvider, String) throws -> Void)? = nil,
        acknowledgementGate: DevelopmentProfileAcknowledgementGate = .shared
    ) {
        self.provider = provider
        self.forcedHydration = forcedHydration ?? Self.refresh
        self.acknowledgementGate = acknowledgementGate
    }
#else
    init(
        provider: @escaping () -> DatabaseProvider = { .shared },
        forcedHydration: ((DatabaseProvider, String) throws -> Void)? = nil
    ) {
        self.provider = provider
        self.forcedHydration = forcedHydration ?? Self.refresh
    }
#endif

    private static func refresh(_ provider: DatabaseProvider, workspaceID: String) throws {
        _ = try RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspaceID,
            participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
    }

    @discardableResult
    func setIncluded(_ included: Bool, member: NetWorthMemberID, workspaceID: String,
                     expectedGeneration: ProviderGenerationToken) throws -> Bool {
        let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
        defer { lease.finish() }
        let current = provider()
        guard current.generationToken == expectedGeneration else { throw RepositoryError.staleProviderGeneration }
        guard current.persistenceState.isUsable else { throw AccountMetadataCoordinatorError.persistenceUnavailable }
#if DEBUG
        try acknowledgementGate.requireAuthorization(for: .netWorthMembershipMutation,
            providerGeneration: current.generationToken)
#endif
        let changed = try current.netWorthMembershipRepo.setIncluded(included, member: member, workspaceID: workspaceID)
        do { try forcedHydration(current, workspaceID) }
        catch { throw AccountMetadataCoordinatorError.savedButRefreshFailed }
        return changed
    }
}
