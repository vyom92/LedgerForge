import Foundation
import Testing
@testable import LedgerForge

@MainActor
@Suite(.serialized)
struct ConfirmedImportHydrationTests {
    @Test func committedImportHydratesBeforeReportingSuccess() async {
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

        let result = await engine.commitPreparedImport(hydrationPreparedImport())

        #expect(result.persisted)
        #expect(result.succeeded)
        #expect(result.hydrationOutcome == .committedAndHydrated)
        #expect(hydrationCount == 1)
        #expect(coordinator.persistCount == 1)
    }

    @Test func hydrationFailureBlocksLaterImportsUntilOneCanonicalRetrySucceeds() async {
        let coordinator = HydrationPersistenceCoordinator()
        let gate = ConfirmedImportReconciliationGate()
        var hydrationShouldFail = true
        var hydrationCount = 0
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            forcedHydration: {
                hydrationCount += 1
                if hydrationShouldFail { throw HydrationTestError.failed }
                return hydrationResult()
            },
            reconciliationGate: gate
        )

        let committed = await engine.commitPreparedImport(hydrationPreparedImport())
        let blocked = await engine.commitPreparedImport(hydrationPreparedImport())

        #expect(committed.persisted)
        #expect(!committed.succeeded)
        #expect(committed.requiresReconciliation)
        #expect(blocked.requiresReconciliation)
        #expect(!blocked.persisted)
        #expect(coordinator.persistCount == 1)
        #expect(!engine.retryCanonicalHydration())
        #expect(gate.isBlocked)

        hydrationShouldFail = false
        #expect(engine.retryCanonicalHydration())
        #expect(!gate.isBlocked)

        let next = await engine.commitPreparedImport(hydrationPreparedImport())
        #expect(next.succeeded)
        #expect(coordinator.persistCount == 2)
        #expect(hydrationCount == 4)
    }

    @Test func rejectedAttemptRefreshFailurePreservesTheRejection() async {
        let coordinator = HydrationPersistenceCoordinator()
        coordinator.result = ImportPersistenceResult(
            persisted: false,
            workspaceId: "workspace-hydration",
            accountId: nil,
            importSessionId: nil,
            transactionCount: 1,
            importAttemptId: "attempt-rejected"
        )
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            rejectedAttemptHydration: { throw HydrationTestError.failed },
            reconciliationGate: ConfirmedImportReconciliationGate()
        )

        let result = await engine.commitPreparedImport(hydrationPreparedImport())

        #expect(!result.persisted)
        #expect(result.importAttemptId == "attempt-rejected")
        #expect(!result.requiresReconciliation)
    }

    @Test func reconciliationStateDoesNotLeakBetweenWorkflowInstances() async {
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

        let blocked = await blockedEngine.commitPreparedImport(hydrationPreparedImport())
        let unrelated = await unrelatedEngine.commitPreparedImport(hydrationPreparedImport())

        #expect(blocked.persisted)
        #expect(blocked.requiresReconciliation)
        #expect(unrelated.persisted)
        #expect(unrelated.hydrationOutcome == .committedAndHydrated)
        #expect(unrelatedCoordinator.persistCount == 1)
    }

    @Test func providerReplacementRejectsPreparedGenerationBeforeFinancialWrites() async throws {
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
        let prepared = hydrationPreparedImport(providerGeneration: first.generationToken)

        current = databaseProvider(second)
        let result = await engine.commitPreparedImport(prepared)

        #expect(!result.persisted)
        #expect(result.errorMessage == ImportPersistenceCoordinationError.staleProviderGeneration.localizedDescription)
        #expect(try first.accountRepo.accounts(workspaceId: "default-workspace").isEmpty)
        #expect(try second.accountRepo.accounts(workspaceId: "default-workspace").isEmpty)
        #expect(try first.transactionRepo.trustedTransactions(workspaceId: "default-workspace").isEmpty)
        #expect(try second.transactionRepo.trustedTransactions(workspaceId: "default-workspace").isEmpty)
    }

    @Test(.globalRuntimeStateIsolation)
    func invalidatedConfirmedImportRepositoryRejectsBeforeBaseOrSQLiteWork() throws {
        let memory = InMemoryRepositoryProvider()
        let probe = ConfirmedImportInvocationProbe()
        let protected = DatabaseProvider(
            workspaceRepo: memory.workspaceRepo,
            transactionRepo: memory.transactionRepo,
            categoryRepo: memory.categoryRepo,
            accountRepo: memory.accountRepo,
            importSessionRepo: memory.importSessionRepo,
            confirmedImportRepo: probe,
            generationToken: memory.generationToken,
            persistenceState: .intentionalNonDurable(.testMemory),
            protectsGeneration: true
        )
        let probePlan = confirmedImportPlan(generationToken: protected.generationToken, suffix: "generation-probe")
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
        let sqlitePlan = confirmedImportPlan(
            generationToken: sqliteRuntime.generationToken,
            suffix: "generation-sqlite"
        )
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
        transactionCount: 1
    )

    func persistValidatedImport(financialDocument: FinancialDocument, importSession: ImportSession, validation: ImportValidationResult) throws -> ImportPersistenceResult {
        persistCount += 1
        return result
    }

    func persistValidatedImport(financialDocument: FinancialDocument, importSession: ImportSession, validation: ImportValidationResult, fingerprint: ExactStatementFingerprint, accountChoice: ImportAccountChoice?) throws -> ImportPersistenceResult {
        persistCount += 1
        return result
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? { nil }
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

private func hydrationPreparedImport(
    providerGeneration: ProviderGenerationToken = DatabaseProvider.shared.generationToken
) -> PreparedImport {
    let transaction = Transaction(
        statementDate: try! StatementDate(canonical: "2027-03-13"),
        description: "Hydration fixture",
        debit: nil,
        credit: 10,
        amount: 10,
        balance: 10,
        currency: "INR",
        account: "Fixture",
        sourceBank: "Fixture",
        sourceFile: "hydration.csv",
        statementTimezoneEvidence: .iana("Asia/Kolkata"),
        sourceProvenance: [
            TransactionSourceProvenance(
                normalizedDocumentID: "hydration-normalized-document",
                normalizedRowID: "hydration-normalized-row-1",
                sourceOrdinal: 1,
                normalizedRecordDigest: String.normalizedRecordDigest(values: ["hydration", "1"]),
                parserProfileID: AxisBankAccountParser.profileID,
                parserProfileVersion: AxisBankAccountParser.profileVersion
            )
        ]
    )
    let document = FinancialDocument(
        sourceDocument: Document(filename: "hydration.csv", url: URL(fileURLWithPath: "/tmp/hydration.csv"), fileType: "CSV", importedAt: Date(timeIntervalSince1970: 1_804_896_000)),
        metadata: DocumentMetadata(institution: .axis, documentType: .bankAccount, fileFormat: .csv, confidence: 1),
        parserName: "Hydration fixture",
        bookedCurrency: try! CurrencyCode("INR"),
        transactions: [transaction],
        selectionReasons: ["Fixture"],
        createdAt: Date(timeIntervalSince1970: 1_804_896_000)
    )
    let validation = ImportValidator.validate(financialDocument: document)
    let session = ImportSession(fileName: "hydration.csv", institution: .axis, documentType: .bankAccount, parserName: "Hydration fixture", transactionCount: 1, validation: validation)
    return PreparedImport(sourceURL: document.sourceDocument.url, rawContents: "hydration", fileName: "hydration.csv", detectedInstitution: .axis, detectedDocumentType: .bankAccount, parserName: "Hydration fixture", financialDocument: document, validation: validation, importSession: session, providerGeneration: providerGeneration)
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
        importSessionRepo: provider.importSessionRepo,
        confirmedImportRepo: provider.confirmedImportRepo,
        generationToken: provider.generationToken,
        persistenceState: .intentionalNonDurable(.testMemory),
        protectsGeneration: true
    )
}
