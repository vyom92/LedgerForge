// LedgerForgeTests/ConfirmationGatedImportWorkflowTests.swift

import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct ConfirmationGatedImportWorkflowTests {

    @Test func prepareImportParsesAndValidatesWithoutPersistenceOrRuntimeStoreMutation() async throws {
        await resetRuntimeStoresForConfirmationWorkflow()
        let persistence = CountingPersistenceCoordinator()
        let engine = ImportEngine(importPersistenceCoordinator: persistence)
        let url = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")

        let preparedImport = try await engine.prepareImport(from: url)

        #expect(preparedImport.fileName == "axis_bank_nre_account_statement_baseline.csv")
        #expect(preparedImport.detectedInstitution == .axis)
        #expect(preparedImport.detectedDocumentType == .bankAccount)
        #expect(preparedImport.validation.passed)
        #expect(preparedImport.transactionCount == preparedImport.financialDocument.transactions.count)
        #expect(preparedImport.detectedCurrency == "INR")
        #expect(persistence.persistCallCount == 0)
        #expect(AccountStore.shared.accounts.isEmpty)
        #expect(TransactionStore.shared.transactions.isEmpty)
    }

    @Test func validationFailureBlocksCommitAndDoesNotPersist() async throws {
        await resetRuntimeStoresForConfirmationWorkflow()
        let persistence = CountingPersistenceCoordinator()
        let engine = ImportEngine(importPersistenceCoordinator: persistence)
        let preparedImport = makePreparedImport(transactions: [])

        let result = await engine.commitPreparedImport(preparedImport)

        #expect(!preparedImport.validation.passed)
        #expect(!result.validationPassed)
        #expect(!result.persisted)
        #expect(result.errorMessage == "Import validation failed.")
        #expect(persistence.persistCallCount == 0)
        #expect(AccountStore.shared.accounts.isEmpty)
        #expect(TransactionStore.shared.transactions.isEmpty)
    }

    @Test func confirmationCommitsUsingPreparedFinancialDocumentWithoutRuntimeMutation() async throws {
        await resetRuntimeStoresForConfirmationWorkflow()
        let persistence = CountingPersistenceCoordinator()
        let engine = ImportEngine(importPersistenceCoordinator: persistence)
        let preparedImport = makePreparedImport()

        let result = await engine.commitPreparedImport(preparedImport)

        #expect(result.validationPassed)
        #expect(result.persisted)
        #expect(persistence.persistCallCount == 1)
        #expect(persistence.capturedFinancialDocument?.id == preparedImport.financialDocument.id)
        #expect(persistence.capturedImportSession?.id == preparedImport.importSession.id)
        #expect(persistence.capturedValidation?.passed == preparedImport.validation.passed)
        #expect(persistence.capturedFingerprint?.algorithm == ExactStatementFingerprint.algorithm)
        #expect(persistence.capturedFingerprint?.digest == preparedImport.fingerprint.digest)
        #expect(persistence.fingerprintedPersistCallCount == 1)
        #expect(persistence.legacyPersistCallCount == 0)
        #expect(TransactionStore.shared.transactions.isEmpty)
        #expect(AccountStore.shared.accounts.isEmpty)
    }

    @Test func duplicateConfirmationIsRejectedWithoutSecondPersistence() async throws {
        await resetRuntimeStoresForConfirmationWorkflow()
        let persistence = CountingPersistenceCoordinator()
        let engine = ImportEngine(importPersistenceCoordinator: persistence)
        let preparedImport = makePreparedImport()

        let firstResult = await engine.commitPreparedImport(preparedImport)
        let secondResult = await engine.commitPreparedImport(preparedImport)

        #expect(firstResult.persisted)
        #expect(secondResult.validationPassed)
        #expect(!secondResult.persisted)
        #expect(secondResult.errorMessage == "Prepared import has already been committed.")
        #expect(persistence.persistCallCount == 1)
    }

    @Test func persistenceFailureLeavesEveryRuntimeFinancialStoreUnchanged() async throws {
        await resetRuntimeStoresForConfirmationWorkflow()
        let existingTransaction = makeConfirmationTransaction(
            date: Date(timeIntervalSince1970: 1_804_809_600),
            description: "Existing transaction",
            debit: nil,
            credit: 25,
            amount: 25,
            balance: 25
        )
        let existingAccount = Account(
            institution: "Existing Bank",
            name: "Existing Account",
            type: .bank,
            currencyCode: "INR",
            currentBalance: 25
        )
        AccountStore.shared.replaceAccounts([existingAccount])
        TransactionStore.shared.replaceTransactions([existingTransaction])
        DocumentStore.shared.update(with: "existing,document")
        await Task.yield()

        let originalDocumentRows = DocumentStore.shared.rows
        let originalTransactionIds = TransactionStore.shared.transactions.map(\.id)
        let originalAccountIds = AccountStore.shared.accounts.map(\.id)
        let persistence = CountingPersistenceCoordinator()
        persistence.errorToThrow = ConfirmationPersistenceError.writeFailed
        let engine = ImportEngine(importPersistenceCoordinator: persistence)

        let result = await engine.commitPreparedImport(makePreparedImport())

        #expect(result.validationPassed)
        #expect(!result.persisted)
        #expect(result.errorMessage == "Repository write failed.")
        #expect(persistence.persistCallCount == 1)
        #expect(DocumentStore.shared.rows == originalDocumentRows)
        #expect(TransactionStore.shared.transactions.map(\.id) == originalTransactionIds)
        #expect(AccountStore.shared.accounts.map(\.id) == originalAccountIds)
    }

    @Test func skippedPersistenceLeavesRuntimeStoresEmptyAndReportsFailure() async throws {
        await resetRuntimeStoresForConfirmationWorkflow()
        let persistence = CountingPersistenceCoordinator()
        persistence.resultOverride = .skipped
        let engine = ImportEngine(importPersistenceCoordinator: persistence)

        let result = await engine.commitPreparedImport(makePreparedImport())

        #expect(result.validationPassed)
        #expect(!result.persisted)
        #expect(result.errorMessage == "Import persistence was skipped.")
        #expect(DocumentStore.shared.rows.isEmpty)
        #expect(TransactionStore.shared.transactions.isEmpty)
        #expect(AccountStore.shared.accounts.isEmpty)
    }

    @Test func ambiguousAndConflictingIdentityFailuresLeaveRuntimeStoresUnchanged() async throws {
        let errors: [ImportPersistenceCoordinationError] = [
            .ambiguousIdentity,
            .conflictingIdentity
        ]

        for error in errors {
            await resetRuntimeStoresForConfirmationWorkflow()
            let persistence = CountingPersistenceCoordinator()
            persistence.errorToThrow = error
            let engine = ImportEngine(importPersistenceCoordinator: persistence)

            let result = await engine.commitPreparedImport(makePreparedImport())

            #expect(!result.persisted)
            #expect(result.errorMessage == error.localizedDescription)
            #expect(DocumentStore.shared.rows.isEmpty)
            #expect(TransactionStore.shared.transactions.isEmpty)
            #expect(AccountStore.shared.accounts.isEmpty)
        }
    }

    @Test func sprint27OutcomePresentationStillReflectsCommitResults() async throws {
        let success = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "axis.csv",
                transactionCount: 2,
                validationPassed: true,
                persisted: true,
                errorMessage: nil
            )
        )
        let persistenceFailure = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "axis.csv",
                transactionCount: 2,
                validationPassed: true,
                persisted: false,
                errorMessage: "Repository write failed."
            )
        )

        #expect(success.validationStatus == "Validation Passed")
        #expect(success.persistenceStatus == "Persistence Succeeded")
        #expect(success.allowsViewingTransactions)
        #expect(persistenceFailure.validationStatus == "Validation Passed")
        #expect(persistenceFailure.persistenceStatus == "Persistence Failed")
        #expect(!persistenceFailure.allowsViewingTransactions)
    }

    @Test func exactFingerprintUsesOnlyReaderProducedUTF8Text() {
        let original = ExactStatementFingerprint(text: "Date,Amount\n2026-01-01,10\n")
        let renamed = ExactStatementFingerprint(text: "Date,Amount\n2026-01-01,10\n")
        let whitespaceChanged = ExactStatementFingerprint(text: "Date,Amount\n2026-01-01,10 \n")

        #expect(original.algorithm == "ledgerforge.raw-text.sha256.v1")
        #expect(original.digest.count == 64)
        #expect(original.digest == renamed.digest)
        #expect(original.byteCount == renamed.byteCount)
        #expect(original.digest != whitespaceChanged.digest)
    }

    @Test func previouslyImportedOutcomeIsDistinctAndDoesNotRequireHydration() {
        let previous = PreviouslyImportedStatement(
            importSessionId: "prior-session",
            completedAtISO: "2026-07-14T09:00:00Z",
            transactionCount: 81,
            accountId: "account-prior",
            accountDisplayName: "Axis Bank INR"
        )
        let result = ImportEngineResult(
            fileName: "renamed.csv",
            transactionCount: 81,
            validationPassed: true,
            persisted: false,
            errorMessage: nil,
            accountId: previous.accountId,
            importSessionId: previous.importSessionId,
            previousImport: previous
        )
        let presentation = ImportOutcomePresentation(result: result)

        #expect(!result.succeeded)
        #expect(!result.requiresHydration)
        #expect(presentation.persistenceStatus == "Previously Imported")
        #expect(presentation.isPreviouslyImported)
        #expect(presentation.previousImportCompletedAtISO == previous.completedAtISO)
        #expect(presentation.previousAccountDisplayName == previous.accountDisplayName)
        #expect(!presentation.allowsViewingTransactions)
    }

    @Test func newSuccessRequiresOneCanonicalHydrationSignal() {
        let result = ImportEngineResult(
            fileName: "axis.csv",
            transactionCount: 81,
            validationPassed: true,
            persisted: true,
            errorMessage: nil
        )

        #expect(result.requiresHydration)
    }

    @Test func competingSameProcessConfirmationsProduceOneFinancialHistory() async throws {
        let provider = InMemoryRepositoryProvider()
        let firstCoordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: provider.workspaceRepo,
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-competing-confirmations",
                workspaceName: "Competing Confirmations"
            )
        )
        let secondCoordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: provider.workspaceRepo,
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-competing-confirmations",
                workspaceName: "Competing Confirmations"
            )
        )
        let firstEngine = ImportEngine(importPersistenceCoordinator: firstCoordinator)
        let secondEngine = ImportEngine(importPersistenceCoordinator: secondCoordinator)
        let first = makePreparedImport(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let second = makePreparedImport(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)

        async let firstResult = firstEngine.commitPreparedImport(first, accountChoice: .createNewAccount)
        async let secondResult = secondEngine.commitPreparedImport(second, accountChoice: .createNewAccount)
        let results = await [firstResult, secondResult]

        #expect(results.filter(\.persisted).count == 1)
        #expect(results.filter { $0.previousImport != nil }.count == 1)
        #expect(try provider.accountRepo.accounts(workspaceId: "workspace-competing-confirmations").count == 1)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: "workspace-competing-confirmations").count == 2)
        let successfulSessionIDs = [first, second].compactMap { prepared in
            try? provider.importSessionRepo.importSession(id: prepared.importSession.id.uuidString)
        }.compactMap { $0 }.filter { $0.validationStatus == "passed" }.map(\.id)
        #expect(successfulSessionIDs.count == 1)
        let prior = try #require(try provider.importSessionRepo.priorImportedStatement(
            algorithm: first.fingerprint.algorithm,
            fingerprint: first.fingerprint.digest
        ))
        #expect(prior.importSessionId == successfulSessionIDs[0])
        #expect(prior.transactionCount == 2)
    }
}

private final class CountingPersistenceCoordinator: ImportPersistenceCoordinating {
    private(set) var persistCallCount = 0
    private(set) var legacyPersistCallCount = 0
    private(set) var fingerprintedPersistCallCount = 0
    private(set) var capturedFinancialDocument: FinancialDocument?
    private(set) var capturedImportSession: ImportSession?
    private(set) var capturedValidation: ImportValidationResult?
    private(set) var capturedFingerprint: ExactStatementFingerprint?
    var errorToThrow: Error?
    var resultOverride: ImportPersistenceResult?

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        legacyPersistCallCount += 1
        return try persist(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation
        )
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? {
        nil
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult {
        fingerprintedPersistCallCount += 1
        capturedFingerprint = fingerprint
        return try persist(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation
        )
    }

    private func persist(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        persistCallCount += 1
        capturedFinancialDocument = financialDocument
        capturedImportSession = importSession
        capturedValidation = validation

        if let errorToThrow {
            throw errorToThrow
        }

        if let resultOverride {
            return resultOverride
        }

        return ImportPersistenceResult(
            persisted: validation.passed,
            workspaceId: validation.passed ? "workspace-confirmation-test" : nil,
            accountId: validation.passed ? "account-confirmation-test" : nil,
            importSessionId: validation.passed ? importSession.id.uuidString : nil,
            transactionCount: validation.passed ? financialDocument.transactions.count : 0
        )
    }
}

@MainActor
private func resetRuntimeStoresForConfirmationWorkflow() async {
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
    DocumentStore.shared.clear()
    await Task.yield()
}

private enum ConfirmationPersistenceError: Error, LocalizedError {
    case writeFailed

    var errorDescription: String? {
        "Repository write failed."
    }
}

private func makePreparedImport(
    id: UUID = UUID(),
    transactions: [Transaction] = [
        makeConfirmationTransaction(
            date: Date(timeIntervalSince1970: 1_804_896_000),
            description: "Opening credit",
            debit: nil,
            credit: 100,
            amount: 100,
            balance: 1_100
        ),
        makeConfirmationTransaction(
            date: Date(timeIntervalSince1970: 1_804_982_400),
            description: "Card payment",
            debit: 50,
            credit: nil,
            amount: -50,
            balance: 1_050
        )
    ]
) -> PreparedImport {
    let document = FinancialDocument(
        sourceDocument: Document(
            filename: "confirmation-workflow.csv",
            url: URL(fileURLWithPath: "/tmp/confirmation-workflow.csv"),
            fileType: "CSV",
            importedAt: Date(timeIntervalSince1970: 1_804_896_000)
        ),
        metadata: DocumentMetadata(
            institution: .axis,
            documentType: .bankAccount,
            fileFormat: .csv,
            confidence: 1.0
        ),
        parserName: "Axis Bank Account",
        transactions: transactions,
        selectionReasons: ["Confirmation workflow test parser selection."],
        createdAt: Date(timeIntervalSince1970: 1_804_896_000)
    )
    let validation = ImportValidator.validate(financialDocument: document)
    let importSession = ImportSession(
        importedAt: Date(timeIntervalSince1970: 1_804_896_000),
        fileName: document.sourceDocument.filename,
        institution: document.metadata.institution,
        documentType: document.metadata.documentType,
        parserName: document.parserName,
        transactionCount: document.transactions.count,
        validation: validation
    )

    return PreparedImport(
        id: id,
        sourceURL: document.sourceDocument.url,
        rawContents: "date,description,amount",
        fileName: document.sourceDocument.filename,
        detectedInstitution: document.metadata.institution,
        detectedDocumentType: document.metadata.documentType,
        parserName: document.parserName,
        financialDocument: document,
        validation: validation,
        importSession: importSession
    )
}

private func makeConfirmationTransaction(
    date: Date,
    description: String,
    debit: Decimal?,
    credit: Decimal?,
    amount: Decimal,
    balance: Decimal?
) -> Transaction {
    Transaction(
        date: date,
        description: description,
        debit: debit,
        credit: credit,
        amount: amount,
        balance: balance,
        currency: "INR",
        account: "Axis NRE",
        sourceBank: "Axis Bank",
        sourceFile: "confirmation-workflow.csv"
    )
}
