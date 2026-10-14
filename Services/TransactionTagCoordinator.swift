import Foundation

@MainActor
protocol TransactionTagManaging: AnyObject {
    @discardableResult
    func saveTag(_ tag: TransactionTagDefinition, replacing expected: TransactionTagDefinition?,
                 generation: ProviderGenerationToken) throws -> Bool
    @discardableResult
    func removeTag(_ tag: TransactionTagDefinition, expectedTransactionIDs: Set<String>,
                   generation: ProviderGenerationToken) throws -> Bool
    @discardableResult
    func setMembership(tag: TransactionTagDefinition, transactionIDs: Set<String>, isAttached: Bool,
                       expectedAttachedTransactionIDs: Set<String>, generation: ProviderGenerationToken) throws -> Bool
    func retryRefresh(workspaceID: String, generation: ProviderGenerationToken) throws
}

/// One generation-bound metadata write followed by canonical tag hydration.
/// Initial or failed runtime reconciliation still requires full hydration.
@MainActor
final class TransactionTagCoordinator: TransactionTagManaging {
    private let provider: () -> DatabaseProvider
    private let tagStore: TransactionTagStore
    private let gate: CategoryReconciliationGate
    private let refresh: (DatabaseProvider, TransactionTagStore, String) throws -> Void
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
    private let acknowledgementGate: DevelopmentProfileAcknowledgementGate

    init(provider: (() -> DatabaseProvider)? = nil,
         tagStore: TransactionTagStore? = nil,
         gate: CategoryReconciliationGate? = nil,
         refresh: ((DatabaseProvider, TransactionTagStore, String) throws -> Void)? = nil,
         acknowledgementGate: DevelopmentProfileAcknowledgementGate? = nil) {
        let resolvedGate = gate ?? .shared
        self.provider = provider ?? { .shared }
        self.tagStore = tagStore ?? .shared
        self.gate = resolvedGate
        self.acknowledgementGate = acknowledgementGate ?? .shared
        self.refresh = refresh ?? { provider, store, workspaceID in
            _ = try RepositoryStoreHydrator(databaseProvider: provider, tagStore: store, workspaceId: workspaceID,
                categoryReconciliationGate: resolvedGate, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
        }
    }
#else
    init(provider: (() -> DatabaseProvider)? = nil,
         tagStore: TransactionTagStore? = nil,
         gate: CategoryReconciliationGate? = nil,
         refresh: ((DatabaseProvider, TransactionTagStore, String) throws -> Void)? = nil) {
        let resolvedGate = gate ?? .shared
        self.provider = provider ?? { .shared }
        self.tagStore = tagStore ?? .shared
        self.gate = resolvedGate
        self.refresh = refresh ?? { provider, store, workspaceID in
            _ = try RepositoryStoreHydrator(databaseProvider: provider, tagStore: store, workspaceId: workspaceID,
                categoryReconciliationGate: resolvedGate, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
        }
    }
#endif

    @discardableResult
    func saveTag(_ tag: TransactionTagDefinition, replacing expected: TransactionTagDefinition?,
                 generation: ProviderGenerationToken) throws -> Bool {
        try mutate(workspaceID: tag.workspaceID, generation: generation) { provider in
            let value = try tag.canonicalized()
            // As with category creation, tags are usable before the first
            // import. The first explicit definition creates its workspace.
            if expected == nil, try provider.workspaceRepo.workspace(id: value.workspaceID) == nil {
                guard try provider.tagRepo.snapshot(workspaceID: value.workspaceID) != nil else {
                    throw TransactionTagError.unavailable
                }
                _ = try provider.workspaceRepo.upsertWorkspace(WorkspaceDTO(id: value.workspaceID, name: "Personal",
                    createdAtISO: ISO8601DateFormatter().string(from: Date())))
            }
            return try provider.tagRepo.saveTag(value, replacing: expected)
        }
    }

    @discardableResult
    func removeTag(_ tag: TransactionTagDefinition, expectedTransactionIDs: Set<String>,
                   generation: ProviderGenerationToken) throws -> Bool {
        try mutate(workspaceID: tag.workspaceID, generation: generation) {
            try $0.tagRepo.removeTag(tag, expectedTransactionIDs: expectedTransactionIDs)
        }
    }

    @discardableResult
    func setMembership(tag: TransactionTagDefinition, transactionIDs: Set<String>, isAttached: Bool,
                       expectedAttachedTransactionIDs: Set<String>, generation: ProviderGenerationToken) throws -> Bool {
        try mutate(workspaceID: tag.workspaceID, generation: generation) {
            try $0.tagRepo.setMembership(tag: tag, transactionIDs: transactionIDs, isAttached: isAttached,
                expectedAttachedTransactionIDs: expectedAttachedTransactionIDs)
        }
    }

    func retryRefresh(workspaceID: String, generation: ProviderGenerationToken) throws {
        let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
        defer { lease.finish() }
        let current = provider()
        guard current.generationToken == generation else { throw RepositoryError.staleProviderGeneration }
        guard current.persistenceState.isUsable else { throw TransactionTagError.unavailable }
        do {
            try refresh(current, tagStore, workspaceID)
            gate.clearAfterCanonicalHydration(for: generation)
        } catch {
            throw TransactionTagError.refreshRequired
        }
    }

    private func mutate(workspaceID: String, generation: ProviderGenerationToken,
                        _ operation: (DatabaseProvider) throws -> Bool) throws -> Bool {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.tagMutation)
        defer { GmailQualificationTiming.end(.tagMutation, started: timing) }
#endif
        let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
        defer { lease.finish() }
        let current = provider()
        guard current.generationToken == generation else { throw RepositoryError.staleProviderGeneration }
        guard current.persistenceState.isUsable else { throw TransactionTagError.unavailable }
        guard !gate.isBlocked(for: generation) else { throw TransactionTagError.refreshRequired }
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        try acknowledgementGate.requireAuthorization(for: .financialIntelligenceMutation, providerGeneration: generation)
#endif
        let changed: Bool
        do {
            changed = try operation(current)
        } catch let error as TransactionTagError {
            throw error
        } catch let error as RepositoryError {
            if case .staleProviderGeneration = error { throw error }
            throw TransactionTagError.saveFailed
        } catch {
            throw TransactionTagError.saveFailed
        }
        guard changed else { return false }
        do {
            let hydrator = RepositoryStoreHydrator(databaseProvider: current, tagStore: tagStore,
                workspaceId: workspaceID, categoryReconciliationGate: gate, participatesInLifecycleGate: false)
            if try !hydrator.refreshTransactionTagsIfCurrent() {
                try refresh(current, tagStore, workspaceID)
            }
            return true
        } catch {
            gate.requireReconciliation(for: generation)
            throw TransactionTagError.savedButRefreshFailed
        }
    }
}
