import Foundation

/// Stateless startup workflow. ContentView retains the one-shot task guard and all view-model lifetimes.
@MainActor
struct ApplicationHydrationWorkflow {
    let dashboardViewModel: DashboardViewModel
    let availability: ApplicationAvailability

    func hydrateDashboard(force: Bool) {
        dashboardViewModel.markHydrationStarted()
        do {
            let result = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: force)
            dashboardViewModel.markHydrationCompleted(result)
            DurableStartupEvidence.checkpoint()
        } catch {
            dashboardViewModel.markHydrationFailed(error)
            if !DatabaseProvider.shared.persistenceState.isUsable {
                let root = DatabaseProvider.shared.failureContext
                let failure = RuntimeDiagnostic.failure(
                    error,
                    operation: "startup hydration",
                    stage: "provider availability",
                    effect: "canonical data not loaded",
                    relatedRoot: root
                )
                if root == nil { availability.didFail(failure, generation: nil) }
                RuntimeDiagnostic.record(failure, category: .runtime)
            }
        }
    }
}
