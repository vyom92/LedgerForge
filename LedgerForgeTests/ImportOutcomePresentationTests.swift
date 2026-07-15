// LedgerForgeTests/ImportOutcomePresentationTests.swift

import Foundation
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
        #expect(presentation.message == "Import validation failed. The failure could not be added to Import History.")
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
        #expect(presentation.message == "Import persistence failed. The failure could not be added to Import History.")
        #expect(!presentation.allowsViewingTransactions)
    }

    @Test func failureHistoryStatesAreBoundedAndPrivacySafe() {
        let validationRecorded = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "private-validation.csv",
                transactionCount: 0,
                validationPassed: false,
                persisted: false,
                errorMessage: "Private validation narration /tmp/source.csv",
                importAttemptId: "validation-attempt"
            )
        )
        let persistenceRecorded = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "private-persistence.csv",
                transactionCount: 2,
                validationPassed: true,
                persisted: false,
                errorMessage: "SQLite leaked account-123 fingerprint-456",
                importAttemptId: "persistence-attempt"
            )
        )
        let persistenceUnrecorded = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "private-audit.csv",
                transactionCount: 2,
                validationPassed: true,
                persisted: false,
                errorMessage: "Secondary audit leaked upi-reference",
                importAttemptId: nil
            )
        )

        #expect(validationRecorded.message == "Import validation failed. The failure was added to Import History.")
        #expect(persistenceRecorded.message == "Import persistence failed. The failure was added to Import History.")
        #expect(persistenceUnrecorded.message == "Import persistence failed. The failure could not be added to Import History.")

        let presentedText = [validationRecorded, persistenceRecorded, persistenceUnrecorded]
            .compactMap(\.message)
            .joined(separator: "|")
        for prohibited in ["/tmp/", "account-123", "fingerprint-456", "upi-reference", "SQLite"] {
            #expect(!presentedText.localizedCaseInsensitiveContains(prohibited))
        }
    }
}
