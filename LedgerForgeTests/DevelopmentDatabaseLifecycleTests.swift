import Combine
import Foundation
import Testing
@testable import LedgerForge

#if DEBUG
@MainActor
struct DevelopmentDatabaseLifecycleTests {
    @Test(.globalRuntimeStateIsolation)
    func currentToPersistentAndBackIsAtomicAndPreservesCurrentData() throws {
        let setup = try makeCoordinator(named: "RoundTrip", seedCurrent: true)
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }

        let currentToken = DatabaseProvider.shared.generationToken
        let capturedCurrentWorkspaceRepository = DatabaseProvider.shared.workspaceRepo
        let capturedCurrentTransactionRepository = DatabaseProvider.shared.transactionRepo
        let capturedCurrentCategoryRepository = DatabaseProvider.shared.categoryRepo
        let capturedCurrentAccountRepository = DatabaseProvider.shared.accountRepo
        let capturedCurrentImportSessionRepository = DatabaseProvider.shared.importSessionRepo
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(AccountStore.shared.accounts.first?.repositoryAccountId == "account-lifecycle")

        guard case .activated(let persistentActivation) = setup.coordinator.activate(.persistentDebug) else {
            Issue.record("Expected Persistent Debug activation")
            return
        }
        #expect(persistentActivation.profile.kind == .persistentDebug)
        #expect(persistentActivation.profile.verifiedCurrentSchemaVersion == 14)
        #expect(setup.coordinator.activeProfile == persistentActivation.profile)
        #expect(setup.coordinator.currentDatabaseURL == setup.identity.persistentDebugURL)
        #expect(DatabaseProvider.shared.generationToken != currentToken)
        #expect(AccountStore.shared.accounts.isEmpty)
        #expect(FileManager.default.fileExists(atPath: setup.identity.canonicalDevelopmentURL.path))
        #expect(FileManager.default.fileExists(atPath: setup.identity.persistentDebugURL.path))
        #expect(throws: RepositoryError.self) {
            _ = try capturedCurrentAccountRepository.accounts(workspaceId: "default-workspace")
        }
        #expect(throws: RepositoryError.self) {
            _ = try capturedCurrentWorkspaceRepository.workspace(id: "default-workspace")
        }
        #expect(throws: RepositoryError.self) {
            _ = try capturedCurrentTransactionRepository.transactions(
                workspaceId: "default-workspace",
                importSessionId: nil
            )
        }
        #expect(throws: RepositoryError.self) {
            _ = try capturedCurrentCategoryRepository.categories(workspaceId: "default-workspace")
        }
        #expect(throws: RepositoryError.self) {
            _ = try capturedCurrentImportSessionRepository.importAttempts(workspaceId: "default-workspace")
        }

        let currentInspection = try SQLiteRepositoryProvider(path: setup.identity.canonicalDevelopmentURL.path)
        #expect(try currentInspection.accountRepo.accounts(workspaceId: "default-workspace").count == 1)
        try currentInspection.database.checkpointAndClose()

        let capturedPersistentRepository = DatabaseProvider.shared.accountRepo
        guard case .activated(let currentActivation) = setup.coordinator.activate(.current) else {
            Issue.record("Expected Current activation")
            return
        }
        #expect(currentActivation.profile.kind == .current)
        #expect(setup.coordinator.currentDatabaseURL == setup.identity.canonicalDevelopmentURL)
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(AccountStore.shared.accounts.first?.repositoryAccountId == "account-lifecycle")
        #expect(FileManager.default.fileExists(atPath: setup.identity.persistentDebugURL.path))
        #expect(throws: RepositoryError.self) {
            _ = try capturedPersistentRepository.accounts(workspaceId: "default-workspace")
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func successfulActivationPublishesOnlyOneCompleteNewRuntimeStateToSynchronousObservers() throws {
        let setup = try makeDistinctiveRuntimeCoordinator(named: "ObserverAtomicSuccess")
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }

        let oldProvider = DatabaseProvider.shared
        let oldGeneration = oldProvider.generationToken
        let oldEpoch = setup.coordinator.runtimePublicationEpoch
        let oldState = expectedRuntimeObservation(
            coordinator: setup.coordinator,
            provider: oldProvider,
            generation: oldGeneration,
            epoch: oldEpoch,
            profileKind: .current,
            suffix: "old"
        )
        let recorder = RuntimePublicationRecorder(coordinator: setup.coordinator)
        let subscriptions = runtimePublicationSubscriptions(
            coordinator: setup.coordinator,
            recorder: recorder
        )

        guard case .activated(let activation) = setup.coordinator.activate(.persistentDebug) else {
            Issue.record("Expected Persistent Debug activation")
            return
        }

        let newProvider = DatabaseProvider.shared
        let newState = expectedRuntimeObservation(
            coordinator: setup.coordinator,
            provider: newProvider,
            generation: newProvider.generationToken,
            epoch: oldEpoch + 1,
            profileKind: .persistentDebug,
            suffix: "new"
        )
        let captured = recorder.observations

        #expect(activation.profile.kind == .persistentDebug)
        #expect(!captured.isEmpty)
        #expect(captured.first == newState)
        #expect(captured.allSatisfy { $0 == oldState || $0 == newState })
        #expect(captured.allSatisfy { $0 == newState })
        #expect(RuntimePublicationObservation.capture(from: setup.coordinator) == newState)
        withExtendedLifetime(subscriptions) {}
    }

    @Test(.globalRuntimeStateIsolation)
    func failedStagedHydrationEmitsNoRuntimePublicationCallback() throws {
        let setup = try makeDistinctiveRuntimeCoordinator(
            named: "ObserverAtomicHydrationFailure",
            failures: [.hydration]
        )
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }
        let initial = RuntimePublicationObservation.capture(from: setup.coordinator)
        let recorder = RuntimePublicationRecorder(coordinator: setup.coordinator)
        let subscriptions = runtimePublicationSubscriptions(
            coordinator: setup.coordinator,
            recorder: recorder
        )

        #expect(setup.coordinator.activate(.persistentDebug) == .stagedHydrationFailed)
        #expect(recorder.observations.isEmpty)
        #expect(RuntimePublicationObservation.capture(from: setup.coordinator) == initial)
        withExtendedLifetime(subscriptions) {}
    }

    @Test(.globalRuntimeStateIsolation)
    func postCommitCleanupFailureCallbacksStillObserveCompleteNewRuntimeState() throws {
        let setup = try makeDistinctiveRuntimeCoordinator(
            named: "ObserverAtomicCleanupFailure",
            failures: [.priorCleanup]
        )
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }
        let oldEpoch = setup.coordinator.runtimePublicationEpoch
        let recorder = RuntimePublicationRecorder(coordinator: setup.coordinator)
        let subscriptions = runtimePublicationSubscriptions(
            coordinator: setup.coordinator,
            recorder: recorder
        )

        guard case .committedButPriorCleanupFailed(let activation) = setup.coordinator.activate(.persistentDebug) else {
            Issue.record("Expected committed prior-cleanup failure")
            return
        }
        let newProvider = DatabaseProvider.shared
        let expected = expectedRuntimeObservation(
            coordinator: setup.coordinator,
            provider: newProvider,
            generation: newProvider.generationToken,
            epoch: oldEpoch + 1,
            profileKind: .persistentDebug,
            suffix: "new"
        )

        #expect(activation.profile.kind == .persistentDebug)
        #expect(!recorder.observations.isEmpty)
        #expect(recorder.observations.first == expected)
        #expect(recorder.observations.allSatisfy { $0 == expected })
        #expect(RuntimePublicationObservation.capture(from: setup.coordinator) == expected)
        withExtendedLifetime(subscriptions) {}
    }

    @Test(.globalRuntimeStateIsolation, arguments: [
        DevelopmentDatabaseLifecycleFailurePoint.recreation,
        .migration,
        .hydration,
        .providerInstallation
    ])
    func candidateFailureLeavesProviderGenerationProfileAndStoresUnchanged(
        _ failure: DevelopmentDatabaseLifecycleFailurePoint
    ) throws {
        let setup = try makeCoordinator(named: "CandidateFailure-\(failure)", failures: [failure], seedCurrent: true)
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }

        let token = DatabaseProvider.shared.generationToken
        let activeProfile = setup.coordinator.activeProfile
        let accountIDs = AccountStore.shared.accounts.map(\.id)
        let repository = DatabaseProvider.shared.accountRepo

        let result = setup.coordinator.activate(.persistentDebug)

        switch failure {
        case .recreation:
            #expect(result == .candidateCreationFailed)
        case .migration:
            #expect(result == .migrationFailed)
        case .hydration:
            #expect(result == .stagedHydrationFailed)
        case .providerInstallation:
            #expect(result == .publicationFailedBeforeCommit)
        default:
            Issue.record("Unexpected failure point")
        }
        #expect(DatabaseProvider.shared.generationToken == token)
        #expect(setup.coordinator.activeProfile == activeProfile)
        #expect(setup.coordinator.currentDatabaseURL == setup.identity.canonicalDevelopmentURL)
        let currentAccountIDs = AccountStore.shared.accounts.map { $0.id }
        #expect(currentAccountIDs == accountIDs)
        #expect(try repository.accounts(workspaceId: "default-workspace").count == 1)
    }

    @Test(.globalRuntimeStateIsolation)
    func failedOwnedCandidateIsClosedAndRemovedExactly() throws {
        let ownershipID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        let setup = try makeCoordinator(
            named: "OwnedCandidateFailure",
            failures: [.hydration],
            makeOwnershipID: { ownershipID }
        )
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }
        let profile = try DevelopmentDatabaseProfile.resolve(.temporarySession) { ownershipID }
        let candidateTarget = try setup.identity.target(for: profile)

        #expect(setup.coordinator.activate(.temporarySession) == .stagedHydrationFailed)
        #expect(setup.coordinator.activeProfile?.kind == .current)
        for member in setup.identity.databaseSet(at: candidateTarget.databaseURL) {
            #expect(!FileManager.default.fileExists(atPath: member.path))
        }
        #expect(FileManager.default.fileExists(atPath: setup.identity.canonicalDevelopmentURL.path))
    }

    @Test(.globalRuntimeStateIsolation)
    func priorCloseFailureReportsCommittedStateWithoutRepublishingOldGeneration() throws {
        let setup = try makeCoordinator(named: "PriorCloseFailure", failures: [.priorCleanup], seedCurrent: true)
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }
        let oldRepository = DatabaseProvider.shared.accountRepo
        let oldToken = DatabaseProvider.shared.generationToken

        guard case .committedButPriorCleanupFailed(let activation) = setup.coordinator.activate(.persistentDebug) else {
            Issue.record("Expected committed cleanup failure")
            return
        }

        #expect(activation.profile.kind == .persistentDebug)
        #expect(setup.coordinator.activeProfile == activation.profile)
        #expect(DatabaseProvider.shared.generationToken != oldToken)
        #expect(AccountStore.shared.accounts.isEmpty)
        #expect(throws: RepositoryError.self) {
            _ = try oldRepository.accounts(workspaceId: "default-workspace")
        }
    }

    @Test(.globalRuntimeStateIsolation, arguments: [
        DevelopmentDatabaseActivity.importPreparation,
        .confirmedPersistence,
        .hydration,
        .repositoryWrite,
        .developerReload
    ])
    func nonDrainableProviderActivityBlocksSwitch(_ activity: DevelopmentDatabaseActivity) throws {
        let setup = try makeCoordinator(named: "Activity-\(activity.rawValue)")
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }
        let lease = try setup.gate.begin(activity)
        defer { lease.finish() }

        #expect(setup.coordinator.activate(.persistentDebug) == .activityBlocked)
        #expect(setup.coordinator.activeProfile?.kind == .current)
        #expect(!FileManager.default.fileExists(atPath: setup.identity.persistentDebugURL.path))
    }

    @Test(.globalRuntimeStateIsolation)
    func activePreparationGenuinelyOverlapsAndBlocksProfileActivation() async throws {
        let suspension = AsyncOverlapGate()
        let persistence = OverlapPersistenceProbe()
        let importCoordinator = SuspendingSnapshotImportCoordinator(gate: suspension)
        let engine = ImportEngine(
            importCoordinator: importCoordinator,
            importPersistenceCoordinator: persistence
        )
        var drainInvocationCount = 0
        let setup = try makeCoordinator(
            named: "PreparationOverlap",
            activityGate: .shared,
            preparedImportInvalidator: { permit in
                drainInvocationCount += 1
                return engine.invalidatePreparedImportsForProfileSwitch(permit)
            }
        )
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }

        let preparationTask = Task {
            try await engine.prepareImport(
                from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
            )
        }
        await suspension.waitUntilArrived()
        #expect(await suspension.arrivalCount() == 1)
        #expect(DevelopmentDatabaseActivityGate.shared.hasActiveOperations)

        let activationTask = Task {
            setup.coordinator.activate(.persistentDebug)
        }
        let activation = await activationTask.value

        #expect(activation == .activityBlocked)
        #expect(await suspension.arrivalCount() == 1)
        #expect(drainInvocationCount == 0)
        #expect(setup.coordinator.activeProfile?.kind == .current)

        await suspension.release()
        let prepared = try await preparationTask.value
        #expect(prepared.validation.passed)
        #expect(try prepared.sourceSnapshot.withBytes { !$0.isEmpty })
        engine.cancelPreparedImport(prepared)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func activeConfirmationGenuinelyOverlapsAndBlocksProfileActivation() async throws {
        let persistence = OverlapPersistenceProbe()
        let engine = ImportEngine(importPersistenceCoordinator: persistence)
        var drainInvocationCount = 0
        let setup = try makeCoordinator(
            named: "ConfirmationOverlap",
            activityGate: .shared,
            preparedImportInvalidator: { permit in
                drainInvocationCount += 1
                return engine.invalidatePreparedImportsForProfileSwitch(permit)
            }
        )
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )
        let suspension = AsyncOverlapGate()
        DevelopmentDatabaseActivityGate.shared.setTransitionObserverForTesting { activity in
            guard activity == .confirmedPersistence else { return }
            await suspension.arriveAndWaitForRelease()
        }
        defer { DevelopmentDatabaseActivityGate.shared.setTransitionObserverForTesting(nil) }

        let confirmationTask = Task {
            await engine.commitPreparedImport(prepared)
        }
        await suspension.waitUntilArrived()
        #expect(await suspension.arrivalCount() == 1)
        #expect(DevelopmentDatabaseActivityGate.shared.hasActiveOperations)
        #expect(try prepared.sourceSnapshot.withBytes { !$0.isEmpty })

        let activationTask = Task {
            setup.coordinator.activate(.persistentDebug)
        }
        let activation = await activationTask.value

        #expect(activation == .activityBlocked)
        #expect(await suspension.arrivalCount() == 1)
        #expect(drainInvocationCount == 0)
        #expect(persistence.persistInvocationCount == 0)
        #expect(try prepared.sourceSnapshot.withBytes { !$0.isEmpty })

        await suspension.release()
        let result = await confirmationTask.value
        #expect(!result.persisted)
        #expect(result.errorMessage == ImportEngineCommitError.persistenceSkipped.localizedDescription)
        #expect(persistence.persistInvocationCount == 1)
        #expect(persistence.rejectionInvocationCount == 0)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func awaitingConfirmationProfileActivationConsumesSnapshotBeforeProviderUseWithoutAuditWrite() async throws {
        let persistence = OverlapPersistenceProbe()
        let engine = ImportEngine(importPersistenceCoordinator: persistence)
        let setup = try makeCoordinator(
            named: "AwaitingConfirmationDrain",
            activityGate: .shared,
            preparedImportInvalidator: { permit in
                engine.invalidatePreparedImportsForProfileSwitch(permit)
            }
        )
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        )
        #expect(try prepared.sourceSnapshot.withBytes { !$0.isEmpty })

        let activationTask = Task {
            setup.coordinator.activate(.persistentDebug)
        }
        let activationResult = await activationTask.value
        guard case .activated(let activation) = activationResult else {
            Issue.record("Expected activation after awaiting-confirmation drain")
            return
        }

        #expect(activation.preparedImportInvalidation.invalidatedCount == 1)
        #expect(!DevelopmentDatabaseActivityGate.shared.hasActiveOperations)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }

        let laterConfirmation = await engine.commitPreparedImport(prepared)
        #expect(!laterConfirmation.persisted)
        #expect(laterConfirmation.errorMessage == ImportEngineCommitError.alreadyCommitted.localizedDescription)
        #expect(persistence.persistInvocationCount == 0)
        #expect(persistence.rejectionInvocationCount == 0)
    }

    @Test(.globalRuntimeStateIsolation)
    func pendingBarrierBlocksNewWorkBeforePreparedLeaseIsDrained() throws {
        let root = try temporaryDirectory(named: "PendingBarrier")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let gate = DevelopmentDatabaseActivityGate()
        var blockedNewLease = false
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(
            identity: identity,
            activityGate: gate,
            injectedFailures: [],
            preparedImportInvalidator: { _ in
                do {
                    _ = try gate.begin(.repositoryWrite)
                } catch DevelopmentDatabaseActivityError.lifecycleOperationInProgress {
                    blockedNewLease = true
                } catch {
                    Issue.record("Unexpected gate result")
                }
                return .none
            }
        )
        defer { coordinator.closeOwnedProvider() }
        try installCurrent(identity: identity, coordinator: coordinator)

        guard case .activated = coordinator.activate(.persistentDebug) else {
            Issue.record("Expected activation")
            return
        }
        #expect(blockedNewLease)
        #expect(!gate.isProfileSwitchPending)
        #expect(!gate.hasExclusiveOperation)
    }

    @Test(.globalRuntimeStateIsolation)
    func awaitingConfirmationLeaseIsExplicitlyDrainedInsideBarrier() throws {
        let root = try temporaryDirectory(named: "PreparedDrain")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let gate = DevelopmentDatabaseActivityGate()
        let preparedLease = try gate.begin(.preparedAwaitingConfirmation)
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(
            identity: identity,
            activityGate: gate,
            injectedFailures: [],
            preparedImportInvalidator: { _ in
                preparedLease.finish()
                return DevelopmentPreparedImportInvalidationResult(invalidatedCount: 1)
            }
        )
        defer { coordinator.closeOwnedProvider() }
        try installCurrent(identity: identity, coordinator: coordinator)

        guard case .activated(let activation) = coordinator.activate(.persistentDebug) else {
            Issue.record("Expected activation after prepared import drain")
            return
        }
        #expect(activation.preparedImportInvalidation.invalidatedCount == 1)
        #expect(!gate.hasActiveOperations)
    }

    @Test(.globalRuntimeStateIsolation)
    func switchRejectsWhenPreparedInvalidatorDoesNotReleaseOwnership() throws {
        let root = try temporaryDirectory(named: "PreparedDrainFailure")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let gate = DevelopmentDatabaseActivityGate()
        let preparedLease = try gate.begin(.preparedAwaitingConfirmation)
        defer { preparedLease.finish() }
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(
            identity: identity,
            activityGate: gate,
            injectedFailures: [],
            preparedImportInvalidator: { _ in
                DevelopmentPreparedImportInvalidationResult(invalidatedCount: 0)
            }
        )
        defer { coordinator.closeOwnedProvider() }
        try installCurrent(identity: identity, coordinator: coordinator)

        #expect(coordinator.activate(.persistentDebug) == .activityBlocked)
        #expect(coordinator.activeProfile?.kind == .current)
    }

    @Test(.globalRuntimeStateIsolation)
    func currentResetIsRejectedWithoutLifecycleMutation() throws {
        let setup = try makeCoordinator(named: "CurrentReset", seedCurrent: true)
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }
        let token = DatabaseProvider.shared.generationToken
        let data = try Data(contentsOf: setup.identity.canonicalDevelopmentURL)

        #expect(setup.coordinator.resetActiveProfile() == .resetNotPermitted)
        #expect(DatabaseProvider.shared.generationToken == token)
        #expect(try Data(contentsOf: setup.identity.canonicalDevelopmentURL) == data)
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(AccountStore.shared.accounts.first?.repositoryAccountId == "account-lifecycle")
    }

    @Test(.globalRuntimeStateIsolation)
    func persistentResetUsesStableIdentityAndPreservesCurrent() throws {
        let setup = try makeCoordinator(named: "PersistentReset", seedCurrent: true)
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }
        guard case .activated = setup.coordinator.activate(.persistentDebug) else {
            Issue.record("Expected Persistent Debug activation")
            return
        }
        try seedAccount(in: DatabaseProvider.shared)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "default-workspace").count == 1)

        guard case .activated(let activation) = setup.coordinator.resetActiveProfile() else {
            Issue.record("Expected Persistent Debug reset")
            return
        }
        #expect(activation.profile.kind == .persistentDebug)
        #expect(setup.coordinator.currentDatabaseURL == setup.identity.persistentDebugURL)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "default-workspace").isEmpty)
        #expect(FileManager.default.fileExists(atPath: setup.identity.backupURL.path))

        let current = try SQLiteRepositoryProvider(path: setup.identity.canonicalDevelopmentURL.path)
        #expect(try current.accountRepo.accounts(workspaceId: "default-workspace").count == 1)
        try current.database.checkpointAndClose()
    }

    @Test(.globalRuntimeStateIsolation)
    func temporaryResetCreatesNewIdentityAndRemovesOnlyPriorOwnedSet() throws {
        let setup = try makeCoordinator(named: "TemporaryReset")
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }
        guard case .activated = setup.coordinator.activate(.temporarySession),
              let firstURL = setup.coordinator.currentDatabaseURL else {
            Issue.record("Expected first temporary profile")
            return
        }

        guard case .activated(let activation) = setup.coordinator.resetActiveProfile(),
              let secondURL = setup.coordinator.currentDatabaseURL else {
            Issue.record("Expected temporary reset")
            return
        }

        #expect(activation.profile.kind == .temporarySession)
        #expect(secondURL != firstURL)
        for member in setup.identity.databaseSet(at: firstURL) {
            #expect(!FileManager.default.fileExists(atPath: member.path))
        }
        #expect(FileManager.default.fileExists(atPath: setup.identity.canonicalDevelopmentURL.path))
        #expect(FileManager.default.fileExists(atPath: secondURL.path))
    }

    @Test(.globalRuntimeStateIsolation)
    func sandboxResetReusesSourceSemanticsWithFreshIdentityAndCurrentRuntimeSchema() throws {
        let setup = try makeCoordinator(named: "SandboxReset")
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }
        guard case .activated(let first) = setup.coordinator.activate(.migrationSandbox(sourceVersion: 3)),
              let firstURL = setup.coordinator.currentDatabaseURL else {
            Issue.record("Expected first sandbox")
            return
        }
        #expect(first.profile.migrationSourceVersion == 3)
        #expect(first.profile.verifiedCurrentSchemaVersion == 14)

        guard case .activated(let replacement) = setup.coordinator.resetActiveProfile(),
              let replacementURL = setup.coordinator.currentDatabaseURL else {
            Issue.record("Expected sandbox reset")
            return
        }
        #expect(replacement.profile.migrationSourceVersion == 3)
        #expect(replacement.profile.verifiedCurrentSchemaVersion == 14)
        #expect(replacementURL != firstURL)
        for member in setup.identity.databaseSet(at: firstURL) {
            #expect(!FileManager.default.fileExists(atPath: member.path))
        }
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "default-workspace").isEmpty)
    }

    @Test(.globalRuntimeStateIsolation, arguments: Array(1...13))
    func migrationSandboxVerifiesExactHistoricalPrefixBeforeOpeningCurrentRuntime(
        _ sourceVersion: Int
    ) throws {
        let root = try temporaryDirectory(named: "SandboxV\(sourceVersion)")
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let gate = DevelopmentDatabaseActivityGate()
        let initialToken = ProviderGenerationToken()
        var observedPrefix: [Int]?
        var globalTokenDuringPrefix: ProviderGenerationToken?
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(
            identity: identity,
            activityGate: gate,
            injectedFailures: [],
            migrationSandboxPrefixObserver: { versions in
                observedPrefix = versions
                globalTokenDuringPrefix = DatabaseProvider.shared.generationToken
            }
        )
        defer { coordinator.closeOwnedProvider() }
        try installCurrent(identity: identity, coordinator: coordinator)
        let installedCurrentToken = DatabaseProvider.shared.generationToken
        #expect(installedCurrentToken != initialToken)

        guard case .activated(let activation) = coordinator.activate(
            .migrationSandbox(sourceVersion: sourceVersion)
        ) else {
            Issue.record("Expected V\(sourceVersion) sandbox activation")
            return
        }

        #expect(observedPrefix == Array(1...sourceVersion))
        #expect(globalTokenDuringPrefix == installedCurrentToken)
        #expect(activation.profile.migrationSourceVersion == sourceVersion)
        #expect(activation.profile.verifiedCurrentSchemaVersion == 14)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "default-workspace").isEmpty)
        guard let sandboxURL = coordinator.currentDatabaseURL else {
            Issue.record("Missing active sandbox URL")
            return
        }
        let inspection = try SQLiteRepositoryProvider(path: sandboxURL.path)
        #expect(try inspection.database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 14)
        #expect(try inspection.database.validatedMigrationHistory(
            against: allMigrations,
            requiresCompleteChain: true
        ).compactMap(\.version) == Array(1...14))
        try inspection.database.checkpointAndClose()
    }

    @Test(.globalRuntimeStateIsolation)
    func stableProfilesSurviveOrdinarySwitchingWhileOwnedProfilesAreRemoved() throws {
        let setup = try makeCoordinator(named: "CleanupSafety")
        defer { try? FileManager.default.removeItem(at: setup.root) }
        defer { setup.coordinator.closeOwnedProvider() }

        guard case .activated = setup.coordinator.activate(.persistentDebug) else {
            Issue.record("Expected Persistent Debug")
            return
        }
        guard case .activated = setup.coordinator.activate(.temporarySession),
              let temporaryURL = setup.coordinator.currentDatabaseURL else {
            Issue.record("Expected Temporary Session")
            return
        }
        guard case .activated = setup.coordinator.activate(.current) else {
            Issue.record("Expected Current")
            return
        }

        #expect(FileManager.default.fileExists(atPath: setup.identity.canonicalDevelopmentURL.path))
        #expect(FileManager.default.fileExists(atPath: setup.identity.persistentDebugURL.path))
        for member in setup.identity.databaseSet(at: temporaryURL) {
            #expect(!FileManager.default.fileExists(atPath: member.path))
        }
    }

    private func makeDistinctiveRuntimeCoordinator(
        named name: String,
        failures: Set<DevelopmentDatabaseLifecycleFailurePoint> = []
    ) throws -> (
        root: URL,
        identity: DevelopmentDatabaseIdentity,
        coordinator: DevelopmentDatabaseLifecycleCoordinator
    ) {
        let root = try temporaryDirectory(named: name)
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(
            identity: identity,
            activityGate: DevelopmentDatabaseActivityGate(),
            injectedFailures: failures
        )
        try FileManager.default.createDirectory(
            at: identity.canonicalDevelopmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let current = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        try seedDistinctiveRuntime(in: current, suffix: "old")
        _ = try coordinator.installInitialProvider(current)

        let persistent = try SQLiteRepositoryProvider(path: identity.persistentDebugURL.path)
        try seedDistinctiveRuntime(in: persistent, suffix: "new")
        try persistent.database.checkpointAndClose()
        return (root, identity, coordinator)
    }

    private func seedDistinctiveRuntime(
        in provider: SQLiteRepositoryProvider,
        suffix: String
    ) throws {
        let plan = distinctiveConfirmedImportPlan(
            generation: provider.generationToken,
            suffix: suffix
        )
        guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
            throw DevelopmentDatabaseLifecycleTestError.seedCommitFailed
        }

        let categoryID = "category-\(suffix)"
        _ = try provider.categoryRepo.createCategory(
            CategoryDTO(
                id: categoryID,
                workspaceId: "default-workspace",
                name: "\(suffix.capitalized) Category",
                normalizedName: "\(suffix) category",
                createdAtISO: "2026-07-29T00:00:00Z"
            )
        )
        _ = try provider.categoryRepo.setCategory(
            categoryId: categoryID,
            transactionId: distinctiveTransactionID(for: suffix),
            workspaceId: "default-workspace"
        )
    }

    private func distinctiveConfirmedImportPlan(
        generation: ProviderGenerationToken,
        suffix: String
    ) -> ConfirmedImportPlanDTO {
        let timestamp = "2026-07-29T00:00:00Z"
        let workspace = WorkspaceDTO(
            id: "default-workspace",
            name: "Observer Workspace",
            createdAtISO: timestamp
        )
        let account = AccountDTO(
            id: "account-\(suffix)",
            workspaceId: workspace.id,
            name: "\(suffix.capitalized) Account",
            institutionId: "Fixture Institution",
            accountType: "bank",
            nativeCurrency: "INR",
            createdAtISO: timestamp
        )
        let session = ImportSessionDTO(
            id: "session-\(suffix)",
            workspaceId: workspace.id,
            userVisibleName: "\(suffix.capitalized) Import",
            startedAtISO: timestamp,
            validationStatus: "passed",
            parserVersion: "fixture.profile@1"
        )
        let fingerprint = confirmedImportFixtureDigest(seed: "observer-atomic-\(suffix)")
        let document = ImportedDocumentDTO(
            id: "document-\(suffix)",
            workspaceId: workspace.id,
            importSessionId: session.id,
            filename: "\(suffix)-fixture.csv",
            mimeType: "text/csv",
            sizeBytes: 1,
            sha256: fingerprint,
            createdAtISO: timestamp
        )
        let fingerprintDTO = DocumentFingerprintDTO(
            id: "fingerprint-\(suffix)",
            documentId: document.id,
            importSessionId: session.id,
            algorithm: DocumentFingerprintDTO.rawTextSHA256Algorithm,
            fingerprint: fingerprint,
            fingerprintData: nil,
            isDuplicateAuthority: true,
            createdAtISO: timestamp
        )
        let attempt = ImportAttemptDTO(
            id: "attempt-\(suffix)",
            workspaceId: workspace.id,
            createdAtISO: timestamp,
            outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
            coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
            accountDecisionCode: ImportAttemptAccountDecision.createdNew.rawValue,
            guidanceCode: ImportAttemptGuidance.importCompleted.rawValue,
            persistenceCode: ImportAttemptPersistence.committed.rawValue,
            transactionCount: 1,
            accountId: account.id,
            importSessionId: session.id,
            documentId: document.id
        )
        let normalizedDocument = NormalizedDocumentDTO(
            id: "normalized-document-\(suffix)",
            importSessionId: session.id,
            documentId: document.id,
            profileId: "fixture.profile",
            profileVersion: "1"
        )
        let normalizedRow = NormalizedRowDTO(
            id: "normalized-row-\(suffix)",
            normalizedDocumentId: normalizedDocument.id,
            sourceOrdinal: 1,
            digest: String.normalizedRecordDigest(values: ["observer", suffix])
        )
        let rawRow = TransactionRawRowDTO(
            id: "raw-row-\(suffix)",
            normalizedRowId: normalizedRow.id,
            contributionType: "transaction",
            sourceOrdinal: 1,
            normalizedRecordDigest: normalizedRow.digest,
            normalizedDocumentId: normalizedDocument.id
        )
        let amountMinor: Int64 = suffix == "old" ? 100 : 200
        let transaction = TransactionDTO(
            id: distinctiveTransactionID(for: suffix),
            workspaceId: workspace.id,
            postedDateISO: "2026-07-29",
            financialDateRole: FinancialDateRole.transactionDate.rawValue,
            statementTimezoneEvidence: "iana:Asia/Kolkata",
            description: "\(suffix.capitalized) Transaction",
            nativeCurrency: "INR",
            amountMinor: amountMinor,
            amountDecimal: suffix == "old" ? "1.00" : "2.00",
            direction: "credit",
            runningBalanceMinor: suffix == "old" ? 10_100 : 20_200,
            isTrusted: true,
            trustedAtISO: timestamp,
            createdAtISO: timestamp,
            rawRows: [rawRow]
        )
        let eventReference = suffix == "old" ? "111111111111" : "222222222222"

        return ConfirmedImportPlanDTO(
            providerGeneration: generation,
            workspace: workspace,
            proposedAccount: account,
            accountChoice: .createProposedAccount,
            advisoryIdentity: .noMatch,
            identifiers: [
                ConfirmedImportIdentifierCandidateDTO(
                    scheme: "institution-account",
                    normalizedValue: "OBSERVER-\(suffix.uppercased())-001",
                    provenanceCode: "fixture"
                )
            ],
            historyTemplate: ConfirmedImportHistoryTemplateDTO(
                document: document,
                fingerprint: fingerprintDTO,
                importSession: session,
                completedAtISO: timestamp,
                successfulAttempt: attempt,
                normalizedDocument: normalizedDocument,
                normalizedRows: [normalizedRow]
            ),
            transactionTemplates: [
                ConfirmedImportTransactionTemplateDTO(
                    transaction: transaction,
                    eventEvidence: .axisUPI(
                        ConfirmedImportAxisUPIEventEvidenceDTO(
                            operation: .p2a,
                            reference: eventReference,
                            subtype: .posting
                        )
                    )
                )
            ]
        )
    }

    private func distinctiveTransactionID(for suffix: String) -> String {
        suffix == "old"
            ? "11111111-1111-1111-1111-111111111111"
            : "22222222-2222-2222-2222-222222222222"
    }

    private func expectedRuntimeObservation(
        coordinator: DevelopmentDatabaseLifecycleCoordinator,
        provider: DatabaseProvider,
        generation: ProviderGenerationToken,
        epoch: UInt64,
        profileKind: DevelopmentDatabaseProfileKind,
        suffix: String
    ) -> RuntimePublicationObservation {
        let transactionID = distinctiveTransactionID(for: suffix)
        return RuntimePublicationObservation(
            providerIdentity: ObjectIdentifier(provider),
            providerGeneration: generation,
            publicationEpoch: epoch,
            committedEpoch: epoch,
            committedProviderGeneration: generation,
            activeProfileKind: profileKind,
            committedProfileKind: profileKind,
            migrationSourceVersion: nil,
            committedMigrationSourceVersion: nil,
            verifiedCurrentSchemaVersion: 14,
            committedVerifiedCurrentSchemaVersion: 14,
            accountIDs: ["account-\(suffix)"],
            transactionIDs: [transactionID],
            importSessionIDs: ["session-\(suffix)"],
            importAttemptIDs: ["attempt-\(suffix)"],
            categoryIDs: ["category-\(suffix)"],
            categoryAssignments: [transactionID: "category-\(suffix)"],
            committedAccountIDs: ["account-\(suffix)"],
            committedTransactionIDs: [transactionID],
            committedImportSessionIDs: ["session-\(suffix)"],
            committedImportAttemptIDs: ["attempt-\(suffix)"],
            committedCategoryIDs: ["category-\(suffix)"],
            committedCategoryAssignments: [transactionID: "category-\(suffix)"],
            lastValidationIsNil: true
        )
    }

    private func makeCoordinator(
        named name: String,
        failures: Set<DevelopmentDatabaseLifecycleFailurePoint> = [],
        seedCurrent: Bool = false,
        makeOwnershipID: @escaping () -> UUID = UUID.init,
        activityGate: DevelopmentDatabaseActivityGate? = nil,
        preparedImportInvalidator: @escaping @MainActor (DevelopmentDatabasePreparedImportDrainPermit) -> DevelopmentPreparedImportInvalidationResult = {
            ImportEngine.shared.invalidatePreparedImportsForProfileSwitch($0)
        }
    ) throws -> (
        root: URL,
        identity: DevelopmentDatabaseIdentity,
        gate: DevelopmentDatabaseActivityGate,
        coordinator: DevelopmentDatabaseLifecycleCoordinator
    ) {
        let root = try temporaryDirectory(named: name)
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        let gate = activityGate ?? DevelopmentDatabaseActivityGate()
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(
            identity: identity,
            activityGate: gate,
            injectedFailures: failures,
            preparedImportInvalidator: preparedImportInvalidator,
            makeOwnershipID: makeOwnershipID
        )
        try FileManager.default.createDirectory(
            at: identity.canonicalDevelopmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let provider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        if seedCurrent {
            try seedAccount(in: provider)
        }
        _ = try coordinator.installInitialProvider(provider)
        return (root, identity, gate, coordinator)
    }

    private func installCurrent(
        identity: DevelopmentDatabaseIdentity,
        coordinator: DevelopmentDatabaseLifecycleCoordinator
    ) throws {
        try FileManager.default.createDirectory(
            at: identity.canonicalDevelopmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let provider = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        _ = try coordinator.installInitialProvider(provider)
    }

    private func seedAccount(in provider: SQLiteRepositoryProvider) throws {
        _ = try provider.workspaceRepo.upsertWorkspace(workspace())
        _ = try provider.accountRepo.upsertAccount(account())
    }

    private func seedAccount(in provider: DatabaseProvider) throws {
        _ = try provider.workspaceRepo.upsertWorkspace(workspace())
        _ = try provider.accountRepo.upsertAccount(account())
    }

    private func workspace() -> WorkspaceDTO {
        WorkspaceDTO(
            id: "default-workspace",
            name: "Lifecycle Test",
            createdAtISO: "2026-07-29T00:00:00Z"
        )
    }

    private func account() -> AccountDTO {
        AccountDTO(
            id: "account-lifecycle",
            workspaceId: "default-workspace",
            name: "Sanitized Test Account",
            institutionId: nil,
            accountType: "bank",
            nativeCurrency: "USD",
            description: nil,
            createdAtISO: "2026-07-29T00:00:00Z"
        )
    }

    private func temporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-DBP01-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private enum DevelopmentDatabaseLifecycleTestError: Error {
    case seedCommitFailed
}

@MainActor
private struct RuntimePublicationObservation: Equatable {
    let providerIdentity: ObjectIdentifier
    let providerGeneration: ProviderGenerationToken
    let publicationEpoch: UInt64
    let committedEpoch: UInt64?
    let committedProviderGeneration: ProviderGenerationToken?
    let activeProfileKind: DevelopmentDatabaseProfileKind?
    let committedProfileKind: DevelopmentDatabaseProfileKind?
    let migrationSourceVersion: Int?
    let committedMigrationSourceVersion: Int?
    let verifiedCurrentSchemaVersion: Int?
    let committedVerifiedCurrentSchemaVersion: Int?
    let accountIDs: [String]
    let transactionIDs: [String]
    let importSessionIDs: [String]
    let importAttemptIDs: [String]
    let categoryIDs: [String]
    let categoryAssignments: [String: String]
    let committedAccountIDs: [String]
    let committedTransactionIDs: [String]
    let committedImportSessionIDs: [String]
    let committedImportAttemptIDs: [String]
    let committedCategoryIDs: [String]
    let committedCategoryAssignments: [String: String]
    let lastValidationIsNil: Bool

    static func capture(
        from coordinator: DevelopmentDatabaseLifecycleCoordinator
    ) -> RuntimePublicationObservation {
        let committed = coordinator.committedRuntimeState
        return RuntimePublicationObservation(
            providerIdentity: ObjectIdentifier(DatabaseProvider.shared),
            providerGeneration: DatabaseProvider.shared.generationToken,
            publicationEpoch: coordinator.runtimePublicationEpoch,
            committedEpoch: committed?.publicationEpoch,
            committedProviderGeneration: committed?.providerGeneration,
            activeProfileKind: coordinator.activeProfile?.kind,
            committedProfileKind: committed?.activeProfile.kind,
            migrationSourceVersion: coordinator.activeProfile?.migrationSourceVersion,
            committedMigrationSourceVersion: committed?.activeProfile.migrationSourceVersion,
            verifiedCurrentSchemaVersion: coordinator.activeProfile?.verifiedCurrentSchemaVersion,
            committedVerifiedCurrentSchemaVersion: committed?.activeProfile.verifiedCurrentSchemaVersion,
            accountIDs: AccountStore.shared.accounts.compactMap(\.repositoryAccountId).sorted(),
            transactionIDs: TransactionStore.shared.transactions.compactMap(\.repositoryTransactionId).sorted(),
            importSessionIDs: ImportSessionStore.shared.importSessions.map(\.id).sorted(),
            importAttemptIDs: ImportAttemptStore.shared.attempts.map(\.id).sorted(),
            categoryIDs: CategoryStore.shared.snapshot.categories.map(\.id).sorted(),
            categoryAssignments: CategoryStore.shared.snapshot.assignments,
            committedAccountIDs: committed?.runtimeSnapshot.accounts.compactMap(\.repositoryAccountId).sorted() ?? [],
            committedTransactionIDs: committed?.runtimeSnapshot.transactions.compactMap(\.repositoryTransactionId).sorted() ?? [],
            committedImportSessionIDs: committed?.runtimeSnapshot.importSessions.map(\.id).sorted() ?? [],
            committedImportAttemptIDs: committed?.runtimeSnapshot.importAttempts.map(\.id).sorted() ?? [],
            committedCategoryIDs: committed?.runtimeSnapshot.categorySnapshot.categories.map(\.id).sorted() ?? [],
            committedCategoryAssignments: committed?.runtimeSnapshot.categorySnapshot.assignments ?? [:],
            lastValidationIsNil: TransactionStore.shared.lastValidation == nil
        )
    }
}

@MainActor
private final class RuntimePublicationRecorder {
    private let coordinator: DevelopmentDatabaseLifecycleCoordinator
    private(set) var observations: [RuntimePublicationObservation] = []

    init(coordinator: DevelopmentDatabaseLifecycleCoordinator) {
        self.coordinator = coordinator
    }

    func record() {
        observations.append(.capture(from: coordinator))
    }
}

@MainActor
private func runtimePublicationSubscriptions(
    coordinator: DevelopmentDatabaseLifecycleCoordinator,
    recorder: RuntimePublicationRecorder
) -> [AnyCancellable] {
    let record: () -> Void = { recorder.record() }
    return [
        coordinator.$runtimePublicationEpoch.dropFirst().sink { _ in record() },
        coordinator.$activeProfile.dropFirst().sink { _ in record() },
        AccountStore.shared.$accounts.dropFirst().sink { _ in record() },
        TransactionStore.shared.$transactions.dropFirst().sink { _ in record() },
        TransactionStore.shared.$lastValidation.dropFirst().sink { _ in record() },
        ImportSessionStore.shared.$importSessions.dropFirst().sink { _ in record() },
        ImportAttemptStore.shared.$attempts.dropFirst().sink { _ in record() },
        CategoryStore.shared.$snapshot.dropFirst().sink { _ in record() }
    ]
}

private actor AsyncOverlapGate {
    private var arrivals = 0
    private var isReleased = false
    private var arrivalWaiters: [(expected: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func arriveAndWaitForRelease() async {
        arrivals += 1
        let readyWaiters = arrivalWaiters.filter { arrivals >= $0.expected }
        arrivalWaiters.removeAll { arrivals >= $0.expected }
        for waiter in readyWaiters {
            waiter.continuation.resume()
        }
        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            releaseWaiter = continuation
        }
    }

    func waitUntilArrived(expectedCount: Int = 1) async {
        guard arrivals < expectedCount else { return }
        await withCheckedContinuation { continuation in
            arrivalWaiters.append((expectedCount, continuation))
        }
    }

    func arrivalCount() -> Int {
        arrivals
    }

    func release() {
        guard !isReleased else { return }
        isReleased = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

private final class SuspendingSnapshotImportCoordinator: ImportFramework.ImportCoordinator, @unchecked Sendable {
    private let gate: AsyncOverlapGate

    init(gate: AsyncOverlapGate) {
        self.gate = gate
    }

    func importDocument(
        _ request: ImportRequest,
        snapshot: SourceContentSnapshot
    ) async -> ImportResult {
        await gate.arriveAndWaitForRelease()
        do {
            let text = try snapshot.withBytes { bytes -> String in
                guard let value = String(data: bytes, encoding: .utf8) else {
                    throw ImportError.invalidDocument(message: "Fixture is not UTF-8 text.")
                }
                return value
            }
            return .success(
                request: request,
                rawDocument: RawDocument(
                    sourceURL: request.fileURL,
                    fileName: request.fileName,
                    fileExtension: request.fileExtension,
                    content: .text(text)
                )
            )
        } catch {
            return .failure(
                request: request,
                error: .readerFailure(message: "Fixture snapshot unavailable.")
            )
        }
    }
}

@MainActor
private final class OverlapPersistenceProbe: ImportPersistenceCoordinating {
    private(set) var persistInvocationCount = 0
    private(set) var rejectionInvocationCount = 0

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        persistInvocationCount += 1
        return .skipped
    }

    func priorImportedStatement(
        fingerprint: ExactStatementFingerprint
    ) throws -> PreviouslyImportedStatement? {
        nil
    }

    func recordSourceSnapshotRejection(
        _ kind: SourceSnapshotRejectionKind
    ) -> SourceSnapshotRejectionRecord {
        rejectionInvocationCount += 1
        return .auditWriteUnavailable
    }
}
#endif
