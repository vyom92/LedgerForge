// LedgerForgeTests/ImportOutcomePresentationTests.swift

import Testing
@testable import LedgerForge

struct ImportOutcomePresentationTests {

    @Test func successfulImportShowsValidationAndPersistenceSuccess() {
        let presentation = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "axis.csv",
                transactionCount: 2,
                validationPassed: true,
                persisted: true,
                errorMessage: nil
            )
        )

        #expect(presentation.fileName == "axis.csv")
        #expect(presentation.transactionCount == 2)
        #expect(presentation.validationStatus == "Validation Passed")
        #expect(presentation.persistenceStatus == "Persistence Succeeded")
        #expect(presentation.message == nil)
        #expect(presentation.allowsViewingTransactions)
    }

    @Test func validationFailureShowsNotPersistedAndHidesTransactionsAction() {
        let presentation = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "empty.csv",
                transactionCount: 0,
                validationPassed: false,
                persisted: false,
                errorMessage: "Import validation failed."
            )
        )

        #expect(presentation.fileName == "empty.csv")
        #expect(presentation.transactionCount == 0)
        #expect(presentation.validationStatus == "Validation Failed")
        #expect(presentation.persistenceStatus == "Not Persisted")
        #expect(presentation.message == "Import validation failed.")
        #expect(!presentation.allowsViewingTransactions)
    }

    @Test func persistenceFailureShowsValidationPassedAndHidesTransactionsAction() {
        let presentation = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "axis.csv",
                transactionCount: 2,
                validationPassed: true,
                persisted: false,
                errorMessage: "Repository write failed."
            )
        )

        #expect(presentation.fileName == "axis.csv")
        #expect(presentation.transactionCount == 2)
        #expect(presentation.validationStatus == "Validation Passed")
        #expect(presentation.persistenceStatus == "Persistence Failed")
        #expect(presentation.message == "Repository write failed.")
        #expect(!presentation.allowsViewingTransactions)
    }
}
