import Foundation

/// A narrowly scoped executable acceptance signal. The marker changes observation only,
/// never persistence selection. Ordinary launches produce no stdout evidence.
enum DurableStartupEvidence {
    static func accepts(persistence: PersistenceState, hydrated: Bool, environment: [String: String]) -> Bool {
        persistence == .verifiedSQLite && hydrated &&
        environment["LEDGERFORGE_TEST_HOST"] == nil && environment["LEDGERFORGE_RUN_HOST"] == nil &&
        environment["LEDGERFORGE_DEVELOPMENT_DATABASE_NAMESPACE"] == nil
    }

    @MainActor
    static func checkpoint() {
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard environment["LEDGERFORGE_DURABLE_STARTUP_PROBE"] == "1",
              accepts(persistence: DatabaseProvider.shared.persistenceState, hydrated: ApplicationAvailability.shared.permitsMutation, environment: environment),
              let profile = DevelopmentDatabaseLifecycleCoordinator.shared.activeProfile,
              profile.kind == .current,
              let path = try? SQLiteRepositoryProvider.defaultDBPath() else { return }
        let identity = BuildIdentity.read()
        let evidence: [String: String] = [
            "provider": "verifiedSQLite", "hydration": "complete", "profile": "current",
            "database": URL(fileURLWithPath: path).resolvingSymlinksInPath().path,
            "executable": Bundle.main.executableURL?.resolvingSymlinksInPath().path ?? "unknown",
            "bundle": Bundle.main.bundleIdentifier ?? "unknown",
            "revision": identity.revision, "worktree": identity.worktree,
            "builtAt": identity.builtAt, "configuration": identity.configuration
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys]), let json = String(data: data, encoding: .utf8) else { return }
        print("LEDGERFORGE_DURABLE_STARTUP " + json)
        fflush(stdout)
#endif
    }
}
