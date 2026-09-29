import Foundation

@MainActor
final class FinancialIntelligenceCoordinator {
    private let provider: () -> DatabaseProvider
    private let refresh: (DatabaseProvider, String) throws -> Void
    private let gate: CategoryReconciliationGate
    init(provider: @escaping () -> DatabaseProvider = { .shared },
         gate: CategoryReconciliationGate = .shared,
         refresh: @escaping (DatabaseProvider, String) throws -> Void = { provider, workspace in
             _ = try RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
         }) {
        self.provider = provider; self.gate = gate; self.refresh = refresh
    }

    func saveMovement(_ event: MovementEvent, replacing expected: MovementEvent?, generation: ProviderGenerationToken) throws {
        guard event.kind.isInScope else { throw FinancialIntelligenceError.outsideScope }
        try mutate(workspaceID: event.workspaceID, generation: generation) { try $0.intelligenceRepo.saveMovement(event, replacing: expected) }
    }
    func removeMovement(_ event: MovementEvent, generation: ProviderGenerationToken) throws {
        try mutate(workspaceID: event.workspaceID, generation: generation) { try $0.intelligenceRepo.removeMovement(event) }
    }
    func applyPlanning(_ edit: PlanningMetadataEdit, generation: ProviderGenerationToken) throws {
        try mutate(workspaceID: edit.workspaceID, generation: generation) { try $0.intelligenceRepo.applyPlanning(edit) }
    }
    func acknowledgePlanningReview(_ value: IntelligencePreferences, replacing previous: IntelligencePreferences?, generation: ProviderGenerationToken, revision: UInt64) throws {
        guard FinancialIntelligenceStore.shared.generation == generation,
              FinancialIntelligenceStore.shared.revision == revision else { throw FinancialIntelligenceError.staleReview }
        try applyPlanning(.preferences(value, replacing: previous), generation: generation)
    }
    func retryRefresh(workspaceID: String, generation: ProviderGenerationToken) throws {
        let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
        defer { lease.finish() }
        let current = provider()
        guard current.generationToken == generation else { throw RepositoryError.staleProviderGeneration }
        try refresh(current, workspaceID)
        gate.clearAfterCanonicalHydration(for: generation)
    }
    private func mutate(workspaceID: String, generation: ProviderGenerationToken, _ operation: (DatabaseProvider) throws -> Void) throws {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.intelligenceMutation, count: 0)
        defer { GmailQualificationTiming.end(.intelligenceMutation, started: timing, count: 0) }
#endif
        let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
        defer { lease.finish() }
        let current = provider()
        guard current.generationToken == generation else { throw RepositoryError.staleProviderGeneration }
        guard current.persistenceState.isUsable else { throw FinancialIntelligenceError.unavailable }
        guard !gate.isBlocked(for: generation) else { throw FinancialIntelligenceError.refreshRequired }
#if DEBUG
        try DevelopmentProfileAcknowledgementGate.shared.requireAuthorization(for: .financialIntelligenceMutation, providerGeneration: generation)
#endif
        try operation(current)
        do { try refresh(current, workspaceID) }
        catch {
            gate.requireReconciliation(for: generation)
            throw FinancialIntelligenceError.refreshRequired
        }
    }
}
