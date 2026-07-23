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
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        confirmedImportRepo: provider.confirmedImportRepo,
        generationToken: provider.generationToken,
        persistenceState: .intentionalNonDurable(.testMemory),
        protectsGeneration: true
    )
}
