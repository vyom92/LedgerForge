import Foundation
import Testing
@testable import LedgerForge

@MainActor
@Suite(.serialized)
struct ConfirmedImportHydrationTests {
    @Test(.globalRuntimeStateIsolation)
    func committedImportHydratesBeforeReportingSuccess() async throws {
        let coordinator = HydrationPersistenceCoordinator()
        var hydrationCount = 0
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            forcedHydration: {
                hydrationCount += 1
                return hydrationResult()
            },
            reconciliationGate: ConfirmedImportReconciliationGate()
        )

        let preparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { preparedOwner.cancel() }
        let result = await engine.commitPreparedImport(preparedOwner.preparedImport)

        #expect(result.persisted)
        #expect(result.succeeded)
        #expect(result.hydrationOutcome == .committedAndHydrated)
        #expect(result.recoveryRoute == .none)
        #expect(hydrationCount == 1)
        #expect(coordinator.persistCount == 1)
    }

    @Test(.globalRuntimeStateIsolation)
    func committedHydrationRecoveryActionReconcilesWithoutReimport() async throws {
        let coordinator = HydrationPersistenceCoordinator()
        let gate = ConfirmedImportReconciliationGate()
        var hydrationShouldFail = true
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            forcedHydration: {
                if hydrationShouldFail { throw HydrationTestError.failed }
                return hydrationResult()
            },
            reconciliationGate: gate
        )
        let preparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { preparedOwner.cancel() }
        let committed = await engine.commitPreparedImport(preparedOwner.preparedImport)
        let presentation = try #require(
            ConfirmedImportRecoveryPresentationMapper.presentation(
                for: committed.recoveryRoute
            )
        )
        let action = try #require(presentation.primaryAction)
        let executor = ConfirmedImportRecoveryActionExecutor()
        var preparationCount = 0

        hydrationShouldFail = false
        let execution = await executor.execute(
            action,
            sourceURL: nil,
            retryCanonicalReconciliation: {
                engine.retryCanonicalHydration()
            },
            requestOrdinaryPreparation: { _ in
                preparationCount += 1
                return true
            }
        )

        #expect(committed.persisted)
        #expect(committed.recoveryRoute == .retryCanonicalReconciliation)
        #expect(action == .retryCanonicalReconciliation)
        #expect(execution == .reconciliationSucceeded)
        #expect(preparationCount == 0)
        #expect(coordinator.persistCount == 1)
        #expect(!gate.isBlocked)
    }

    @Test(.globalRuntimeStateIsolation)
    func blockedRecoveryReconcilesBeforeRequestingFreshExplicitPreview() async throws {
        let coordinator = HydrationPersistenceCoordinator()
        let gate = ConfirmedImportReconciliationGate()
        var hydrationShouldFail = true
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            forcedHydration: {
                if hydrationShouldFail { throw HydrationTestError.failed }
                return hydrationResult()
            },
            reconciliationGate: gate
        )

        let committedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { committedOwner.cancel() }
        let committed = await engine.commitPreparedImport(committedOwner.preparedImport)
        let blockedPreparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { blockedPreparedOwner.cancel() }
        let blockedPrepared = blockedPreparedOwner.preparedImport
        let blocked = await engine.commitPreparedImport(blockedPrepared)
        let presentation = try #require(
            ConfirmedImportRecoveryPresentationMapper.presentation(
                for: blocked.recoveryRoute
            )
        )
        let action = try #require(presentation.primaryAction)
        let executor = ConfirmedImportRecoveryActionExecutor()
        var events: [String] = []
        var freshPreview: PreparedImport?

        hydrationShouldFail = false
        let requestedPreviewOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { requestedPreviewOwner.cancel() }
        let requestedPreview = requestedPreviewOwner.preparedImport
        let execution = await executor.execute(
            action,
            sourceURL: blockedPrepared.sourceURL,
            retryCanonicalReconciliation: {
                events.append("reconcile")
                return engine.retryCanonicalHydration()
            },
            requestOrdinaryPreparation: { url in
                events.append("prepare")
                #expect(url == blockedPrepared.sourceURL)
                freshPreview = requestedPreview
                return true
            }
        )
        let fresh = try #require(freshPreview)

        #expect(committed.recoveryRoute == .retryCanonicalReconciliation)
        #expect(blocked.recoveryRoute == .retryCanonicalReconciliationThenPrepareAgain)
        #expect(action == .retryCanonicalReconciliationThenPrepareAgain)
        #expect(execution == .preparationRequested)
        #expect(events == ["reconcile", "prepare"])
        #expect(fresh.id != blockedPrepared.id)
        #expect(fresh.sourceSnapshot.id != blockedPrepared.sourceSnapshot.id)
        #expect(coordinator.persistCount == 1)
        #expect(!gate.isBlocked)

        let explicitlyConfirmed = await engine.commitPreparedImport(fresh)

        #expect(explicitlyConfirmed.recoveryRoute == .none)
        #expect(explicitlyConfirmed.persisted)
        #expect(coordinator.persistCount == 2)
    }

    @Test(.globalRuntimeStateIsolation)
    func blockedRecoveryFailureDoesNotBeginPreparationOrLoop() async throws {
        let coordinator = HydrationPersistenceCoordinator()
        let gate = ConfirmedImportReconciliationGate()
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            forcedHydration: { throw HydrationTestError.failed },
            reconciliationGate: gate
        )

        let failedCommittedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { failedCommittedOwner.cancel() }
        _ = await engine.commitPreparedImport(failedCommittedOwner.preparedImport)
        let blockedPreparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { blockedPreparedOwner.cancel() }
        let blockedPrepared = blockedPreparedOwner.preparedImport
        let blocked = await engine.commitPreparedImport(blockedPrepared)
        let presentation = try #require(
            ConfirmedImportRecoveryPresentationMapper.presentation(
                for: blocked.recoveryRoute
            )
        )
        let executor = ConfirmedImportRecoveryActionExecutor()
        var reconciliationCount = 0
        var preparationCount = 0

        let execution = await executor.execute(
            try #require(presentation.primaryAction),
            sourceURL: blockedPrepared.sourceURL,
            retryCanonicalReconciliation: {
                reconciliationCount += 1
                return engine.retryCanonicalHydration()
            },
            requestOrdinaryPreparation: { _ in
                preparationCount += 1
                return true
            }
        )

        #expect(blocked.recoveryRoute == .retryCanonicalReconciliationThenPrepareAgain)
        #expect(execution == .reconciliationFailed)
        #expect(reconciliationCount == 1)
        #expect(preparationCount == 0)
        #expect(coordinator.persistCount == 1)
        #expect(gate.isBlocked)
    }

    @Test(.globalRuntimeStateIsolation)
    func hydrationFailureBlocksLaterImportsUntilOneCanonicalRetrySucceeds() async throws {
        let coordinator = HydrationPersistenceCoordinator()
        let gate = ConfirmedImportReconciliationGate()
        var hydrationShouldFail = true
        var hydrationCount = 0
        var persistenceState: PersistenceState = .intentionalNonDurable(.testMemory)
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { persistenceState },
            forcedHydration: {
                hydrationCount += 1
                if hydrationShouldFail { throw HydrationTestError.failed }
                return hydrationResult()
            },
            reconciliationGate: gate
        )

        let committedPreparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { committedPreparedOwner.cancel() }
        let committedPrepared = committedPreparedOwner.preparedImport
        let committed = await engine.commitPreparedImport(committedPrepared)
        persistenceState = .unavailable(.databaseOpenFailed)
        let blockedPreparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { blockedPreparedOwner.cancel() }
        let blocked = await engine.commitPreparedImport(blockedPreparedOwner.preparedImport)

        #expect(committed.persisted)
        #expect(!committed.succeeded)
        #expect(committed.requiresReconciliation)
        #expect(committed.recoveryRoute == .retryCanonicalReconciliation)
        #expect(!blocked.requiresReconciliation)
        #expect(!blocked.persisted)
        #expect(blocked.hydrationOutcome == .notRequired)
        #expect(blocked.recoveryRoute == .retryCanonicalReconciliationThenPrepareAgain)
        #expect(coordinator.persistCount == 1)
        #expect(!engine.retryCanonicalHydration())
        #expect(gate.isBlocked)

        hydrationShouldFail = false
        persistenceState = .intentionalNonDurable(.testMemory)
        #expect(engine.retryCanonicalHydration())
        #expect(!gate.isBlocked)

        let consumedConfirmation = await engine.commitPreparedImport(committedPrepared)
        #expect(consumedConfirmation.recoveryRoute == .unavailable)
        #expect(!consumedConfirmation.persisted)
        #expect(coordinator.persistCount == 1)

        let nextPreparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { nextPreparedOwner.cancel() }
        let next = await engine.commitPreparedImport(nextPreparedOwner.preparedImport)
        #expect(next.succeeded)
        #expect(next.recoveryRoute == .none)
        #expect(coordinator.persistCount == 2)
        #expect(hydrationCount == 4)
    }

    @Test(.globalRuntimeStateIsolation)
    func rejectedAttemptRefreshFailurePreservesTheRejection() async throws {
        let coordinator = HydrationPersistenceCoordinator()
        coordinator.result = ImportPersistenceResult(
            persisted: false,
            workspaceId: "workspace-hydration",
            accountId: nil,
            importSessionId: nil,
            transactionCount: 0,
            importAttemptId: "attempt-rejected"
        )
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            rejectedAttemptHydration: { throw HydrationTestError.failed },
            reconciliationGate: ConfirmedImportReconciliationGate()
        )

        let preparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { preparedOwner.cancel() }
        let result = await engine.commitPreparedImport(preparedOwner.preparedImport)

        #expect(!result.persisted)
        #expect(result.importAttemptId == "attempt-rejected")
        #expect(!result.requiresReconciliation)
        #expect(result.recoveryRoute == .unavailable)
    }

    @Test(.globalRuntimeStateIsolation)
    func reconciliationStateDoesNotLeakBetweenWorkflowInstances() async throws {
        let blockedCoordinator = HydrationPersistenceCoordinator()
        let unrelatedCoordinator = HydrationPersistenceCoordinator()
        let blockedEngine = ImportEngine(
            importPersistenceCoordinator: blockedCoordinator,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            forcedHydration: { throw HydrationTestError.failed }
        )
        let unrelatedEngine = ImportEngine(
            importPersistenceCoordinator: unrelatedCoordinator,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            forcedHydration: { hydrationResult() }
        )

        let blockedPreparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { blockedPreparedOwner.cancel() }
        let blocked = await blockedEngine.commitPreparedImport(blockedPreparedOwner.preparedImport)
        let unrelatedPreparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { unrelatedPreparedOwner.cancel() }
        let unrelated = await unrelatedEngine.commitPreparedImport(unrelatedPreparedOwner.preparedImport)

        #expect(blocked.persisted)
        #expect(blocked.requiresReconciliation)
        #expect(blocked.recoveryRoute == .retryCanonicalReconciliation)
        #expect(unrelated.persisted)
        #expect(unrelated.hydrationOutcome == .committedAndHydrated)
        #expect(unrelated.recoveryRoute == .none)
        #expect(unrelatedCoordinator.persistCount == 1)
    }

    @Test(.globalRuntimeStateIsolation)
    func providerReplacementRejectsPreparedGenerationBeforeFinancialWrites() async throws {
        let first = InMemoryRepositoryProvider()
        let second = InMemoryRepositoryProvider()
        var current = databaseProvider(first)
        let coordinator = DefaultImportPersistenceCoordinator(databaseProviderProvider: { current })
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { current.persistenceState },
            providerGenerationProvider: { current.generationToken },
            forcedHydration: { hydrationResult() },
            reconciliationGate: ConfirmedImportReconciliationGate()
        )
        let preparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV(providerGeneration: first.generationToken)
        defer { preparedOwner.cancel() }
        let prepared = preparedOwner.preparedImport

        current = databaseProvider(second)
        let result = await engine.commitPreparedImport(prepared)

        #expect(!result.persisted)
        #expect(result.errorMessage == ImportPersistenceCoordinationError.staleProviderGeneration.localizedDescription)
        #expect(result.recoveryRoute == .prepareAgain(.staleProviderGeneration))
        #expect(try first.accountRepo.accounts(workspaceId: "default-workspace").isEmpty)
        #expect(try second.accountRepo.accounts(workspaceId: "default-workspace").isEmpty)
        #expect(try first.transactionRepo.trustedTransactions(workspaceId: "default-workspace").isEmpty)
        #expect(try second.transactionRepo.trustedTransactions(workspaceId: "default-workspace").isEmpty)
    }

    @Test(.globalRuntimeStateIsolation)
    func invalidatedConfirmedImportRepositoryRejectsBeforeBaseOrSQLiteWork() async throws {
        let memory = InMemoryRepositoryProvider()
        let probe = ConfirmedImportInvocationProbe()
        let protected = DatabaseProvider(
            workspaceRepo: memory.workspaceRepo,
            transactionRepo: memory.transactionRepo,
            categoryRepo: memory.categoryRepo,
            accountRepo: memory.accountRepo,
            cardRepo: memory.cardRepo,
            importSessionRepo: memory.importSessionRepo,
            confirmedImportRepo: probe,
            generationToken: memory.generationToken,
            persistenceState: .intentionalNonDurable(.testMemory),
            protectsGeneration: true
        )
        let probePlan = try await confirmedImportPlan(generationToken: protected.generationToken)
        let capturedProbeRepository = protected.confirmedImportRepo
        protected.invalidateGeneration()

        #expect(capturedProbeRepository.commitConfirmedImport(probePlan) == .staleProviderGeneration)
        #expect(probe.commitCount == 0)

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-ConfirmedGeneration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        try FileManager.default.createDirectory(
            at: identity.canonicalDevelopmentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let sqlite = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        let lifecycle = DevelopmentDatabaseLifecycleCoordinator(
            identity: identity,
            activityGate: DevelopmentDatabaseActivityGate()
        )
        defer { lifecycle.closeOwnedProvider() }
        _ = try lifecycle.installInitialProvider(sqlite)
        let sqliteRuntime = DatabaseProvider.shared
        let sqlitePlan = try await confirmedImportPlan(generationToken: sqliteRuntime.generationToken)
        let capturedSQLiteRepository = sqliteRuntime.confirmedImportRepo
        guard case .activated = lifecycle.activate(.persistentDebug) else {
            Issue.record("Expected lifecycle switch before stale confirmed-import check")
            return
        }

        #expect(capturedSQLiteRepository.commitConfirmedImport(sqlitePlan) == .staleProviderGeneration)
        let inspection = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        #expect(try inspection.database.queryInt("SELECT COUNT(*) FROM workspaces;") == 0)
        #expect(try inspection.database.queryInt("SELECT COUNT(*) FROM import_sessions;") == 0)
        #expect(try inspection.database.queryInt("SELECT COUNT(*) FROM transactions;") == 0)
        try inspection.database.checkpointAndClose()
    }
}

private enum HydrationTestError: Error { case failed }

private final class HydrationPersistenceCoordinator: ImportPersistenceCoordinating {
    var persistCount = 0
    var result = ImportPersistenceResult(
        persisted: true,
        workspaceId: "workspace-hydration",
        accountId: "account-hydration",
        importSessionId: "session-hydration",
        transactionCount: 0
    )

    func persistValidatedImport(financialDocument: FinancialDocument, importSession: ImportSession, validation: ImportValidationResult) throws -> ImportPersistenceResult {
        persistCount += 1
        return financiallyBoundResult(to: financialDocument)
    }

    func persistValidatedImport(financialDocument: FinancialDocument, importSession: ImportSession, validation: ImportValidationResult, fingerprint: ExactStatementFingerprint, accountChoice: ImportAccountChoice?) throws -> ImportPersistenceResult {
        persistCount += 1
        return financiallyBoundResult(to: financialDocument)
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? { nil }

    private func financiallyBoundResult(to document: FinancialDocument) -> ImportPersistenceResult {
        ImportPersistenceResult(
            persisted: result.persisted,
            workspaceId: result.workspaceId,
            accountId: result.accountId,
            importSessionId: result.importSessionId,
            transactionCount: document.transactions.count,
            previousImport: result.previousImport,
            transactionEventBlock: result.transactionEventBlock,
            importAttemptId: result.importAttemptId,
            sourceRowCount: result.sourceRowCount,
            recognizedExistingRowCount: result.recognizedExistingRowCount,
            isPartialImport: result.isPartialImport,
            isEquivalentSupportingSource: result.isEquivalentSupportingSource,
            isSalaryImport: result.isSalaryImport,
            accountOutcome: result.accountOutcome
        )
    }
}

private final class ConfirmedImportInvocationProbe: ConfirmedImportRepository {
    private(set) var reviewCount = 0
    private(set) var commitCount = 0

    func reviewPartialImport(_ plan: ConfirmedImportPlanDTO) -> PartialImportReviewResult {
        reviewCount += 1
        return .ordinaryFullImport
    }

    func commitConfirmedImport(_ plan: ConfirmedImportPlanDTO) -> ConfirmedImportRepositoryResult {
        commitCount += 1
        return .repositoryIntegrityConflict
    }

    func commitReviewedPartialImport(
        _ plan: ReviewedPartialImportPlanDTO
    ) -> ConfirmedImportRepositoryResult {
        commitCount += 1
        return .repositoryIntegrityConflict
    }
}

private func hydrationResult() -> RepositoryStoreHydrationResult {
    RepositoryStoreHydrationResult(didHydrate: true, accountCount: 1, transactionCount: 1, importSessionCount: 1, importAttemptCount: 1)
}

private func databaseProvider(_ provider: InMemoryRepositoryProvider) -> DatabaseProvider {
    DatabaseProvider(
        workspaceRepo: provider.workspaceRepo,
        transactionRepo: provider.transactionRepo,
        categoryRepo: provider.categoryRepo,
        accountRepo: provider.accountRepo,
        cardRepo: provider.cardRepo,
        importSessionRepo: provider.importSessionRepo,
        confirmedImportRepo: provider.confirmedImportRepo,
        generationToken: provider.generationToken,
        persistenceState: .intentionalNonDurable(.testMemory),
        protectsGeneration: true
    )
}
