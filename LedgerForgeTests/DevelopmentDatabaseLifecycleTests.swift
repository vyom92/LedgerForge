import Foundation
import Testing
@testable import LedgerForge

#if DEBUG
@MainActor
struct DevelopmentDatabaseLifecycleTests {
    @Test func absentNamespacePreservesDefaultCanonicalIdentity() throws {
        let root = try temporaryDirectory(named: "NamespaceDefault")
        defer { try? FileManager.default.removeItem(at: root) }
        let direct = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)

        let resolved = try DevelopmentDatabaseIdentity.resolve(
            applicationSupportDirectory: root,
            environment: [:]
        )

        #expect(resolved == direct)
        #expect(resolved.canonicalDevelopmentURL.lastPathComponent == "ledgerforge-development.sqlite")
        #expect(!resolved.isIsolatedCanonicalNamespace)
    }

    @Test func validNamespaceDerivesSeparateStableCanonicalIdentity() throws {
        let root = try temporaryDirectory(named: "NamespaceStable")
        defer { try? FileManager.default.removeItem(at: root) }
        let environment = [DevelopmentDatabaseIdentity.namespaceEnvironmentKey: "sprint50-manual-fixture"]
        let defaultIdentity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)

        let first = try DevelopmentDatabaseIdentity.resolve(applicationSupportDirectory: root, environment: environment)
        let relaunched = try DevelopmentDatabaseIdentity.resolve(applicationSupportDirectory: root, environment: environment)

        #expect(first == relaunched)
        #expect(first.canonicalDevelopmentURL != defaultIdentity.canonicalDevelopmentURL)
        #expect(first.isIsolatedCanonicalNamespace)
        #expect(first.canonicalDevelopmentURL.lastPathComponent == "ledgerforge-development.sqlite")
        #expect(first.nonDevelopmentURL == defaultIdentity.nonDevelopmentURL)

        try FileManager.default.createDirectory(
            at: first.canonicalDevelopmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let provider = try SQLiteRepositoryProvider(path: first.canonicalDevelopmentURL.path)
        try seedAccount(in: provider)
        provider.database.close()
        let relaunchedProvider = try SQLiteRepositoryProvider(path: relaunched.canonicalDevelopmentURL.path)
        defer { relaunchedProvider.database.close() }
        #expect(try relaunchedProvider.accountRepo.accounts(workspaceId: "workspace-lifecycle").count == 1)
    }

    @Test func differentNamespacesResolveToDifferentCanonicalIdentities() throws {
        let root = try temporaryDirectory(named: "NamespaceDistinct")
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try DevelopmentDatabaseIdentity.resolve(
            applicationSupportDirectory: root,
            environment: [DevelopmentDatabaseIdentity.namespaceEnvironmentKey: "sprint50-first"]
        )
        let second = try DevelopmentDatabaseIdentity.resolve(
            applicationSupportDirectory: root,
            environment: [DevelopmentDatabaseIdentity.namespaceEnvironmentKey: "sprint50-second"]
        )

        #expect(first.canonicalDevelopmentURL != second.canonicalDevelopmentURL)
        #expect(first.backupURL != second.backupURL)
        #expect(first.temporaryDirectoryURL != second.temporaryDirectoryURL)
    }

    @Test func unsafeNamespacesFailClosedInsteadOfSelectingDefaultCanonicalIdentity() throws {
        let root = try temporaryDirectory(named: "NamespaceValidation")
        defer { try? FileManager.default.removeItem(at: root) }
        let unsafeValues = [
            "",
            "-leading",
            "trailing-",
            "two--hyphens",
            "UPPERCASE",
            "contains space",
            "contains\ttab",
            "contains\nnewline",
            "contains\u{0000}control",
            ".",
            "..",
            "../escape",
            "nested/path",
            "nested\\path",
            "~",
            "namespace:name",
            "file://namespace",
            "https://namespace.invalid",
            "unicode\u{2215}slash",
            "unicode\u{ff0f}slash",
            "unicode\u{ff0e}dot",
            "lookalike\u{2010}hyphen",
            String(repeating: "a", count: 49)
        ]

        for value in unsafeValues {
            #expect(throws: DevelopmentDatabaseNamespaceError.invalid) {
                _ = try DevelopmentDatabaseIdentity.resolve(
                    applicationSupportDirectory: root,
                    environment: [DevelopmentDatabaseIdentity.namespaceEnvironmentKey: value]
                )
            }
        }
        let defaultIdentity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        #expect(!FileManager.default.fileExists(atPath: defaultIdentity.canonicalDevelopmentURL.path))

        let invalidLifecycle = DevelopmentDatabaseIdentity.lifecycleIdentity(
            applicationSupportDirectory: root,
            environment: [DevelopmentDatabaseIdentity.namespaceEnvironmentKey: "../escape"]
        )
        #expect(invalidLifecycle.canonicalDevelopmentURL != defaultIdentity.canonicalDevelopmentURL)
        #expect(invalidLifecycle.isIsolatedCanonicalNamespace)
    }

    @Test func namespacedIdentityCannotEscapeApprovedDevelopmentRoot() throws {
        let root = try temporaryDirectory(named: "NamespaceContainment")
        defer { try? FileManager.default.removeItem(at: root) }
        let defaultIdentity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let namespaced = try DevelopmentDatabaseIdentity.resolve(
            applicationSupportDirectory: root,
            environment: [DevelopmentDatabaseIdentity.namespaceEnvironmentKey: "sprint50-contained"]
        )
        let approvedRootComponents = defaultIdentity.canonicalDevelopmentURL.deletingLastPathComponent()
            .standardizedFileURL.resolvingSymlinksInPath().pathComponents

        for candidate in [namespaced.canonicalDevelopmentURL, namespaced.backupURL, namespaced.temporaryDirectoryURL] {
            let candidateComponents = candidate.standardizedFileURL.resolvingSymlinksInPath().pathComponents
            #expect(Array(candidateComponents.prefix(approvedRootComponents.count)) == approvedRootComponents)
        }

        let namespaceDirectory = namespaced.canonicalDevelopmentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: namespaceDirectory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let outsideDirectory = root.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: namespaceDirectory, withDestinationURL: outsideDirectory)
        #expect(!namespaced.authorizesDestructiveWork(at: namespaced.canonicalDevelopmentURL))
    }

    @Test func namespacedCanonicalIdentityDoesNotSelectTemporarySessionSemantics() throws {
        let root = try temporaryDirectory(named: "NamespaceCanonical")
        defer { try? FileManager.default.removeItem(at: root) }
        let namespaced = try DevelopmentDatabaseIdentity.resolve(
            applicationSupportDirectory: root,
            environment: [DevelopmentDatabaseIdentity.namespaceEnvironmentKey: "sprint50-canonical"]
        )

        #expect(namespaced.isIsolatedCanonicalNamespace)
        #expect(namespaced.canonicalDevelopmentURL.deletingLastPathComponent() != namespaced.temporaryDirectoryURL)
        #expect(!namespaced.canonicalDevelopmentURL.path.contains("Temporary Sessions"))
    }

    @Test func isolatedLifecycleOperationsLeaveDefaultCanonicalIdentityUnchanged() throws {
        let root = try temporaryDirectory(named: "NamespaceLifecycle")
        defer { try? FileManager.default.removeItem(at: root) }
        let defaultIdentity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let isolatedIdentity = try DevelopmentDatabaseIdentity.resolve(
            applicationSupportDirectory: root,
            environment: [DevelopmentDatabaseIdentity.namespaceEnvironmentKey: "sprint50-lifecycle"]
        )
        try FileManager.default.createDirectory(
            at: defaultIdentity.canonicalDevelopmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let defaultProvider = try SQLiteRepositoryProvider(path: defaultIdentity.canonicalDevelopmentURL.path)
        try seedAccount(in: defaultProvider)
        defaultProvider.database.close()
        let defaultSnapshot = try Data(contentsOf: defaultIdentity.canonicalDevelopmentURL)

        try FileManager.default.createDirectory(
            at: isolatedIdentity.canonicalDevelopmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let isolatedProvider = try SQLiteRepositoryProvider(path: isolatedIdentity.canonicalDevelopmentURL.path)
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(
            identity: isolatedIdentity,
            activityGate: DevelopmentDatabaseActivityGate()
        )
        coordinator.installInitialProvider(isolatedProvider)
        defer { coordinator.closeOwnedProvider() }

        guard case .temporarySessionStarted = coordinator.startTemporaryEmptySession() else {
            Issue.record("Expected isolated temporary session")
            return
        }

        #expect(try Data(contentsOf: defaultIdentity.canonicalDevelopmentURL) == defaultSnapshot)
        #expect(FileManager.default.fileExists(atPath: isolatedIdentity.canonicalDevelopmentURL.path))
    }

    @Test func isolatedCleanupAuthorizationCanNeverTargetDefaultCanonicalIdentity() throws {
        let root = try temporaryDirectory(named: "NamespaceCleanup")
        defer { try? FileManager.default.removeItem(at: root) }
        let defaultIdentity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let isolatedIdentity = try DevelopmentDatabaseIdentity.resolve(
            applicationSupportDirectory: root,
            environment: [DevelopmentDatabaseIdentity.namespaceEnvironmentKey: "sprint50-cleanup"]
        )

        #expect(isolatedIdentity.authorizesIsolatedCleanup(at: isolatedIdentity.canonicalDevelopmentURL))
        #expect(!isolatedIdentity.authorizesIsolatedCleanup(at: defaultIdentity.canonicalDevelopmentURL))
        #expect(!defaultIdentity.authorizesIsolatedCleanup(at: defaultIdentity.canonicalDevelopmentURL))
        #expect(!isolatedIdentity.authorizesIsolatedCleanup(at: isolatedIdentity.temporaryDirectoryURL))
        #expect(!isolatedIdentity.authorizesIsolatedCleanup(at: root.appendingPathComponent("external.sqlite")))
    }

    @Test func namespaceOverrideSurfaceIsDebugOnly() {
        #expect(DevelopmentDatabaseIdentity.namespaceOverrideIsCompiled)
    }

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
        defer { provider.database.close() }
        try seedAccount(in: provider)
        #expect(FileManager.default.fileExists(atPath: identity.canonicalDevelopmentURL.path + "-wal"))
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(identity: identity, activityGate: DevelopmentDatabaseActivityGate())
        coordinator.installInitialProvider(provider)
        defer { coordinator.closeOwnedProvider() }

        let result = coordinator.startTemporaryEmptySession()

        guard case .temporarySessionStarted = result else {
            Issue.record("Expected a temporary session, received \(result)")
            return
        }
        #expect(coordinator.currentDatabaseURL != identity.canonicalDevelopmentURL)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "workspace-lifecycle").isEmpty)

        let relaunchedProvider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        defer { relaunchedProvider.database.close() }
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
        defer { coordinator.closeOwnedProvider() }

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
        defer { backup.database.close() }
        #expect(try backup.accountRepo.accounts(workspaceId: "workspace-lifecycle").count == 1)
        #expect(try backup.database.queryInt("SELECT MAX(version) FROM schema_migrations;") == allMigrations.map(\.version).max())

        let relaunchedProvider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        defer { relaunchedProvider.database.close() }
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
        defer { provider.database.close() }
        let gate = DevelopmentDatabaseActivityGate()
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(identity: identity, activityGate: gate)
        coordinator.installInitialProvider(provider)
        defer { coordinator.closeOwnedProvider() }
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
        defer { provider.database.close() }
        let gate = DevelopmentDatabaseActivityGate()
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(identity: identity, activityGate: gate)
        coordinator.installInitialProvider(provider)
        defer { coordinator.closeOwnedProvider() }
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
        defer { setup.coordinator.closeOwnedProvider() }

        #expect(setup.coordinator.resetDevelopmentDatabase() == expected)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "workspace-lifecycle").count == 1)
        let relaunched = try SQLiteRepositoryProvider(path: setup.identity.canonicalDevelopmentURL.path)
        defer { relaunched.database.close() }
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
        defer { setup.coordinator.closeOwnedProvider() }

        #expect(setup.coordinator.resetDevelopmentDatabase() == expected)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "workspace-lifecycle").count == 1)
        let relaunched = try SQLiteRepositoryProvider(path: setup.identity.canonicalDevelopmentURL.path)
        defer { relaunched.database.close() }
        #expect(try relaunched.accountRepo.accounts(workspaceId: "workspace-lifecycle").count == 1)
    }

    @Test func recoveryFailureEntersUnavailableStateAndRejectsFurtherLifecycleWork() throws {
        let setup = try makeSeededCoordinator(
            named: "RecoveryFailure",
            failures: [.recreation, .recovery]
        )
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }

        #expect(setup.coordinator.resetDevelopmentDatabase() == .recoveryFailed)
        #expect(setup.coordinator.isUnavailable)
        #expect(setup.coordinator.startTemporaryEmptySession() == .lifecycleUnavailable)
    }

    @Test func backupVerificationRejectsTamperedLowerMigrationMetadataEvenWhenHighestVersionIsCurrent() throws {
        let setup = try makeSeededCoordinator(named: "TamperedBackup", failures: [])
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }
        try DatabaseProvider.shared.workspaceRepo.workspace(id: "workspace-lifecycle").map { _ in }
        guard let provider = try? SQLiteRepositoryProvider(path: setup.identity.canonicalDevelopmentURL.path) else {
            Issue.record("Expected canonical provider")
            return
        }
        provider.database.close()

        let tamper = SQLiteDatabase(path: setup.identity.canonicalDevelopmentURL.path)
        try tamper.open()
        try tamper.executePrepared(
            sql: "UPDATE schema_migrations SET name = ? WHERE version = ?;",
            params: ["tampered", 2]
        )
        tamper.close()

        #expect(setup.coordinator.resetDevelopmentDatabase() == .backupFailed)
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
            .appendingPathComponent("LedgerForge-LifecycleTests-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
#endif
