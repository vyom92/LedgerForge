import Foundation
import Testing
@testable import LedgerForge

#if DEBUG
@MainActor
struct DevelopmentDatabaseLifecycleTests {
    @Test func developmentAndReleaseIdentitiesAreDistinctAndStable() throws {
        let root = try temporaryDirectory(named: "Identity")
        defer { try? FileManager.default.removeItem(at: root) }

        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)

        #expect(identity.canonicalDevelopmentURL == identity.canonicalDevelopmentURL)
        #expect(identity.canonicalDevelopmentURL != identity.nonDevelopmentURL)
        #expect(identity.canonicalDevelopmentURL.lastPathComponent == "ledgerforge-development.sqlite")
        #expect(identity.nonDevelopmentURL.lastPathComponent == "ledgerforge.sqlite")
        #expect(identity.databaseSet(at: identity.canonicalDevelopmentURL).map(\.lastPathComponent) == [
            "ledgerforge-development.sqlite",
            "ledgerforge-development.sqlite-wal",
            "ledgerforge-development.sqlite-shm"
        ])
    }

    @Test func destructiveAuthorizationRequiresExactCanonicalIdentity() throws {
        let root = try temporaryDirectory(named: "ExactIdentity")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)

        #expect(identity.authorizesDestructiveWork(at: identity.canonicalDevelopmentURL))
        #expect(!identity.authorizesDestructiveWork(at: identity.nonDevelopmentURL))
        #expect(!identity.authorizesDestructiveWork(at: root.appendingPathComponent("arbitrary.sqlite")))
        #expect(!identity.authorizesDestructiveWork(at: identity.canonicalDevelopmentURL.appendingPathComponent("nested")))
    }

    @Test func standardizationAndSymlinkResolutionCannotEscapeApprovedTarget() throws {
        let root = try temporaryDirectory(named: "Symlink")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        try FileManager.default.createDirectory(
            at: identity.canonicalDevelopmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let outside = root.appendingPathComponent("outside.sqlite")
        FileManager.default.createFile(atPath: outside.path, contents: Data())
        let disguised = identity.canonicalDevelopmentURL
        try FileManager.default.createSymbolicLink(at: disguised, withDestinationURL: outside)

        #expect(!identity.authorizesDestructiveWork(at: disguised))
        #expect(!identity.authorizesDestructiveWork(at: outside))
    }

    @Test func temporarySessionIsEmptyAndCanonicalDataReturnsAfterRelaunch() throws {
        let root = try temporaryDirectory(named: "Temporary")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        try FileManager.default.createDirectory(at: identity.canonicalDevelopmentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let provider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        try seedAccount(in: provider)
        #expect(FileManager.default.fileExists(atPath: identity.canonicalDevelopmentURL.path + "-wal"))
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(identity: identity, activityGate: DevelopmentDatabaseActivityGate())
        coordinator.installInitialProvider(provider)

        let result = coordinator.startTemporaryEmptySession()

        guard case .temporarySessionStarted = result else {
            Issue.record("Expected a temporary session, received \(result)")
            return
        }
        #expect(coordinator.currentDatabaseURL != identity.canonicalDevelopmentURL)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "workspace-lifecycle").isEmpty)

        let relaunchedProvider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        #expect(try relaunchedProvider.accountRepo.accounts(workspaceId: "workspace-lifecycle").count == 1)
    }

    @Test func permanentResetRecreatesCanonicalIdentityAndSurvivesRelaunch() throws {
        let root = try temporaryDirectory(named: "Reset")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        try FileManager.default.createDirectory(at: identity.canonicalDevelopmentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let provider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        try seedAccount(in: provider)
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(identity: identity, activityGate: DevelopmentDatabaseActivityGate())
        coordinator.installInitialProvider(provider)

        let result = coordinator.resetDevelopmentDatabase()

        guard case .permanentResetCompleted(let hydration) = result else {
            Issue.record("Expected permanent reset completion, received \(result)")
            return
        }
        #expect(hydration.accountCount == 0)
        #expect(hydration.transactionCount == 0)
        #expect(hydration.importSessionCount == 0)
        #expect(hydration.importAttemptCount == 0)
        #expect(coordinator.currentDatabaseURL == identity.canonicalDevelopmentURL)
        #expect(FileManager.default.fileExists(atPath: identity.backupURL.path))

        let backup = try SQLiteRepositoryProvider(path: identity.backupURL.path)
        #expect(try backup.accountRepo.accounts(workspaceId: "workspace-lifecycle").count == 1)
        #expect(try backup.database.queryInt("SELECT MAX(version) FROM schema_migrations;") == allMigrations.map(\.version).max())

        let relaunchedProvider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        #expect(try relaunchedProvider.accountRepo.accounts(workspaceId: "workspace-lifecycle").isEmpty)
        #expect(try relaunchedProvider.database.queryInt("SELECT MAX(version) FROM schema_migrations;") == allMigrations.map(\.version).max())
    }

    @Test(arguments: [
        DevelopmentDatabaseActivity.importPreparation,
        .preparedAwaitingConfirmation,
        .confirmedPersistence,
        .hydration,
        .developerReload,
        .repositoryWrite
    ])
    func resetRejectsEveryActiveProviderOperation(_ activity: DevelopmentDatabaseActivity) throws {
        let root = try temporaryDirectory(named: "Gate-\(activity.rawValue)")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        try FileManager.default.createDirectory(at: identity.canonicalDevelopmentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let provider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        let gate = DevelopmentDatabaseActivityGate()
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(identity: identity, activityGate: gate)
        coordinator.installInitialProvider(provider)
        let lease = try gate.begin(activity)
        defer { lease.finish() }

        #expect(coordinator.resetDevelopmentDatabase() == .rejectedActivityInProgress)
    }

    @Test func concurrentLifecycleOperationsRejectDeterministically() throws {
        let root = try temporaryDirectory(named: "Concurrent")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let gate = DevelopmentDatabaseActivityGate()
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(identity: identity, activityGate: gate)

        #expect(gate.beginExclusive())
        defer { gate.finishExclusive(providerChanged: false) }
        #expect(coordinator.startTemporaryEmptySession() == .rejectedActivityInProgress)
    }

    @Test func successfulProviderReplacementInvalidatesCapturedRepositories() throws {
        let root = try temporaryDirectory(named: "Generation")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        try FileManager.default.createDirectory(at: identity.canonicalDevelopmentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let provider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        let gate = DevelopmentDatabaseActivityGate()
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(identity: identity, activityGate: gate)
        coordinator.installInitialProvider(provider)
        let capturedRepository = DatabaseProvider.shared.accountRepo

        guard case .temporarySessionStarted = coordinator.startTemporaryEmptySession() else {
            Issue.record("Expected temporary provider replacement")
            return
        }

        #expect(throws: RepositoryError.self) {
            _ = try capturedRepository.accounts(workspaceId: "workspace-lifecycle")
        }
    }

    @Test(arguments: [
        (DevelopmentDatabaseLifecycleFailurePoint.backupCreation, DevelopmentDatabaseLifecycleResult.backupFailed),
        (.backupVerification, .backupFailed),
        (.providerQuiescence, .providerQuiescenceFailed)
    ])
    func preReplacementFailureLeavesCanonicalDatabaseAvailable(
        _ failure: DevelopmentDatabaseLifecycleFailurePoint,
        _ expected: DevelopmentDatabaseLifecycleResult
    ) throws {
        let setup = try makeSeededCoordinator(named: "PreFailure-\(failure)", failures: [failure])
        defer { try? FileManager.default.removeItem(at: setup.root) }

        #expect(setup.coordinator.resetDevelopmentDatabase() == expected)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "workspace-lifecycle").count == 1)
        let relaunched = try SQLiteRepositoryProvider(path: setup.identity.canonicalDevelopmentURL.path)
        #expect(try relaunched.accountRepo.accounts(workspaceId: "workspace-lifecycle").count == 1)
    }

    @Test(arguments: [
        (DevelopmentDatabaseLifecycleFailurePoint.recreation, DevelopmentDatabaseLifecycleResult.recreationFailed),
        (.migration, .migrationFailed),
        (.providerInstallation, .providerInstallationFailed),
        (.hydration, .hydrationFailedRecoverySucceeded)
    ])
    func postReplacementFailureRestoresVerifiedBackup(
        _ failure: DevelopmentDatabaseLifecycleFailurePoint,
        _ expected: DevelopmentDatabaseLifecycleResult
    ) throws {
        let setup = try makeSeededCoordinator(named: "Recovery-\(failure)", failures: [failure])
        defer { try? FileManager.default.removeItem(at: setup.root) }

        #expect(setup.coordinator.resetDevelopmentDatabase() == expected)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "workspace-lifecycle").count == 1)
        let relaunched = try SQLiteRepositoryProvider(path: setup.identity.canonicalDevelopmentURL.path)
        #expect(try relaunched.accountRepo.accounts(workspaceId: "workspace-lifecycle").count == 1)
    }

    @Test func recoveryFailureEntersUnavailableStateAndRejectsFurtherLifecycleWork() throws {
        let setup = try makeSeededCoordinator(
            named: "RecoveryFailure",
            failures: [.recreation, .recovery]
        )
        defer { try? FileManager.default.removeItem(at: setup.root) }

        #expect(setup.coordinator.resetDevelopmentDatabase() == .recoveryFailed)
        #expect(setup.coordinator.isUnavailable)
        #expect(setup.coordinator.startTemporaryEmptySession() == .lifecycleUnavailable)
    }

    private func makeSeededCoordinator(
        named name: String,
        failures: Set<DevelopmentDatabaseLifecycleFailurePoint>
    ) throws -> (root: URL, identity: DevelopmentDatabaseIdentity, coordinator: DevelopmentDatabaseLifecycleCoordinator) {
        let root = try temporaryDirectory(named: name)
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        try FileManager.default.createDirectory(at: identity.canonicalDevelopmentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let provider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        try seedAccount(in: provider)
        let gate = DevelopmentDatabaseActivityGate()
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(
            identity: identity,
            activityGate: gate,
            injectedFailures: failures
        )
        coordinator.installInitialProvider(provider)
        return (root, identity, coordinator)
    }

    private func seedAccount(in provider: SQLiteRepositoryProvider) throws {
        _ = try provider.workspaceRepo.upsertWorkspace(WorkspaceDTO(
            id: "workspace-lifecycle",
            name: "Lifecycle Test",
            createdAtISO: "2026-07-17T00:00:00Z"
        ))
        _ = try provider.accountRepo.upsertAccount(AccountDTO(
            id: "account-lifecycle",
            workspaceId: "workspace-lifecycle",
            name: "Sanitized Test Account",
            institutionId: nil,
            accountType: "bank",
            nativeCurrency: "USD",
            description: nil,
            createdAtISO: "2026-07-17T00:00:00Z"
        ))
    }

    private func temporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-LifecycleTests-(name)-(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
#endif
