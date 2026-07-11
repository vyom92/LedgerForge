// LedgerForgeTests/ConfirmationGatedImportWorkflowTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct ConfirmationGatedImportWorkflowTests {

    @Test func prepareImportParsesAndValidatesWithoutPersistenceOrRuntimeStoreMutation() async throws {
        resetRuntimeStoresForConfirmationWorkflow()
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
        resetRuntimeStoresForConfirmationWorkflow()
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

    @Test func confirmationCommitsUsingPreparedFinancialDocument() async throws {
        resetRuntimeStoresForConfirmationWorkflow()
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
        #expect(TransactionStore.shared.transactions.count == preparedImport.transactionCount)
    }

    @Test func duplicateConfirmationIsRejectedWithoutSecondPersistence() async throws {
        resetRuntimeStoresForConfirmationWorkflow()
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
}

private final class CountingPersistenceCoordinator: ImportPersistenceCoordinating {
    private(set) var persistCallCount = 0
    private(set) var capturedFinancialDocument: FinancialDocument?
    private(set) var capturedImportSession: ImportSession?
    private(set) var capturedValidation: ImportValidationResult?
    var errorToThrow: Error?

    func persistValidatedImport(
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

        return ImportPersistenceResult(
            persisted: validation.passed,
            workspaceId: validation.passed ? "workspace-confirmation-test" : nil,
            accountId: validation.passed ? "account-confirmation-test" : nil,
            importSessionId: validation.passed ? importSession.id.uuidString : nil,
            transactionCount: validation.passed ? financialDocument.transactions.count : 0
        )
    }
}

private func resetRuntimeStoresForConfirmationWorkflow() {
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
}

private func makePreparedImport(
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
