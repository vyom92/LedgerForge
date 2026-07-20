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

    @Test func importActivityUsesCurrentTerminalOutcomeInsteadOfSelectedFileState() {
        let outcome = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "write-failed.csv",
                transactionCount: 2,
                validationPassed: true,
                persisted: false,
                errorMessage: "Repository write failed."
            )
        )

        let presentation = ImportActivityPresentation(
            importState: .completed(outcome),
            latestDurableAttempt: nil
        )

        #expect(presentation.title == "write-failed.csv")
        #expect(presentation.status == "Persistence Failed")
        #expect(presentation.subtitle == "Processed 2 transaction(s)")
    }

    @Test func importActivityUsesNonTerminalWorkflowStateBeforeAnyOutcome() {
        let presentation = ImportActivityPresentation(
            importState: .preparing(fileName: "preparing.csv", phase: .openingSource),
            latestDurableAttempt: nil
        )

        #expect(presentation.title == "preparing.csv")
        #expect(presentation.status == "Preparing")
    }

    @Test func idleImportActivityUsesLatestDurableAttemptAfterHydration() {
        let attempt = RepositoryImportAttempt(
            ImportAttemptDTO(
                id: "attempt-success",
                workspaceId: "workspace",
                createdAtISO: "2026-07-20T00:00:00Z",
                outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
                coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
                accountDecisionCode: ImportAttemptAccountDecision.resolvedOrCreated.rawValue,
                guidanceCode: ImportAttemptGuidance.importCompleted.rawValue,
                persistenceCode: ImportAttemptPersistence.committed.rawValue,
                transactionCount: 3
            )
        )

        let presentation = ImportActivityPresentation(importState: .idle, latestDurableAttempt: attempt)

        #expect(presentation.title == "Latest durable import")
        #expect(presentation.status == "Import completed")
        #expect(presentation.subtitle == "Persisted 3 transaction(s)")
    }

    @Test func importActivityCoversPreviewValidationCommitCancellationAndFailureWithoutSuccessInference() throws {
        let ready = try activityPreparedImport(fileName: "ready.csv", validationPassed: true)
        let invalid = try activityPreparedImport(fileName: "invalid.csv", validationPassed: false)

        #expect(ImportActivityPresentation(importState: .previewReady(ready), latestDurableAttempt: nil).status == "Ready to Import")
        #expect(ImportActivityPresentation(importState: .validationFailed(invalid), latestDurableAttempt: nil).status == "Validation Failed")
        #expect(ImportActivityPresentation(importState: .committing(ready), latestDurableAttempt: nil).status == "Persisting")
        #expect(ImportActivityPresentation(importState: .cancelled(fileName: "cancelled.csv"), latestDurableAttempt: nil).status == "Cancelled")
        #expect(ImportActivityPresentation(
            importState: .failed(fileName: "failed.csv", message: "/tmp/private.sqlite", retrySourceURL: URL(fileURLWithPath: "/tmp/private.csv")),
            latestDurableAttempt: nil
        ).status == "Preparation Failed")
    }

    @Test func durableDuplicateAndSupportedBlockRemainDistinctAndPrivacySafe() {
        let duplicate = durableAttempt(outcome: .exactStatementDuplicate, transactionCount: 4)
        let blocked = durableAttempt(outcome: .existingEligibleAxisUPIEvent, transactionCount: 1)

        let duplicatePresentation = ImportActivityPresentation(importState: .idle, latestDurableAttempt: duplicate)
        let blockedPresentation = ImportActivityPresentation(importState: .idle, latestDurableAttempt: blocked)

        #expect(duplicatePresentation.status == "Previously imported")
        #expect(blockedPresentation.status == "Statement blocked")
        #expect(![duplicatePresentation.subtitle, blockedPresentation.subtitle].joined().contains("UPI"))
    }

    @Test func durablePersistenceFailureAndUnknownOutcomeRemainDistinctAndPrivacySafe() {
        let persistenceFailure = durableAttempt(outcome: .persistenceFailure, transactionCount: 2)
        let unknown = durableAttempt(
            id: "attempt-unknown",
            createdAtISO: "2026-07-20T00:00:01Z",
            outcomeCode: "future_outcome_private-123",
            transactionCount: 0
        )

        let failurePresentation = ImportActivityPresentation(importState: .idle, latestDurableAttempt: persistenceFailure)
        let unknownPresentation = ImportActivityPresentation(importState: .idle, latestDurableAttempt: unknown)

        #expect(failurePresentation.status == "Persistence failed")
        #expect(failurePresentation.subtitle == "Persistence failed after validation")
        #expect(unknownPresentation.status == "Outcome unavailable")
        #expect(unknownPresentation.subtitle == "A durable import outcome is unavailable")
        #expect(![unknownPresentation.title, unknownPresentation.subtitle, unknownPresentation.status].joined().contains("future_outcome_private-123"))
    }

    @Test func latestDurableAttemptUsesValidTimestampThenStableIDAndHandlesMalformedDates() {
        let older = durableAttempt(id: "older", createdAtISO: "2026-07-20T00:00:00Z", outcomeCode: ImportAttemptOutcome.successfulImport.rawValue, transactionCount: 1)
        let newest = durableAttempt(id: "newest", createdAtISO: "2026-07-20T00:02:00Z", outcomeCode: ImportAttemptOutcome.validationFailure.rawValue, transactionCount: 0)
        let malformed = durableAttempt(id: "zz-malformed", createdAtISO: "not-a-date", outcomeCode: ImportAttemptOutcome.persistenceFailure.rawValue, transactionCount: 0)
        let equalTimestampLowerID = durableAttempt(id: "attempt-a", createdAtISO: "2026-07-20T00:03:00Z", outcomeCode: ImportAttemptOutcome.successfulImport.rawValue, transactionCount: 1)
        let equalTimestampHigherID = durableAttempt(id: "attempt-b", createdAtISO: "2026-07-20T00:03:00Z", outcomeCode: ImportAttemptOutcome.validationFailure.rawValue, transactionCount: 0)
        let malformedLowerID = durableAttempt(id: "malformed-a", createdAtISO: "", outcomeCode: ImportAttemptOutcome.successfulImport.rawValue, transactionCount: 1)
        let malformedHigherID = durableAttempt(id: "malformed-b", createdAtISO: "invalid", outcomeCode: ImportAttemptOutcome.validationFailure.rawValue, transactionCount: 0)

        #expect(ImportActivityPresentation.latestDurableAttempt(from: [older, malformed, newest])?.id == "newest")
        #expect(ImportActivityPresentation.latestDurableAttempt(from: [equalTimestampLowerID, equalTimestampHigherID])?.id == "attempt-b")
        #expect(ImportActivityPresentation.latestDurableAttempt(from: [malformedLowerID, malformedHigherID])?.id == "malformed-b")
    }

    @Test func currentWorkflowStateOverridesHydratedDurableHistory() {
        let latestDurableAttempt = durableAttempt(outcome: .successfulImport, transactionCount: 3)

        let presentation = ImportActivityPresentation(
            importState: .preparing(fileName: "current.csv", phase: .openingSource),
            latestDurableAttempt: latestDurableAttempt
        )

        #expect(presentation.title == "current.csv")
        #expect(presentation.status == "Preparing")
    }
}

private func activityPreparedImport(fileName: String, validationPassed: Bool) throws -> PreparedImport {
    let currency = try CurrencyCode("QAR")
    let transaction = Transaction(
        date: Date(timeIntervalSince1970: 1_700_000_000),
        description: "Activity transaction",
        debit: nil,
        credit: 1,
        amount: 1,
        balance: 1,
        currency: currency.code,
        account: "CBQ",
        sourceBank: "CBQ",
        sourceFile: fileName
    )
    let document = FinancialDocument(
        sourceDocument: Document(
            filename: fileName,
            url: URL(fileURLWithPath: "/tmp/\(fileName)"),
            fileType: "CSV",
            importedAt: Date(timeIntervalSince1970: 1_700_000_000)
        ),
        metadata: DocumentMetadata(institution: .axis, documentType: .bankAccount, fileFormat: .csv, confidence: 1),
        parserName: "Activity Test Parser",
        bookedCurrency: currency,
        transactions: [transaction]
    )
    let validation = ImportValidationResult(
        rowsRead: 1,
        transactionsParsed: 1,
        statementCurrency: currency,
        debitTotalMoney: nil,
        creditTotalMoney: try Money(amount: 1, currency: currency),
        openingBalanceMoney: nil,
        closingBalanceMoney: nil,
        passed: validationPassed,
        issues: []
    )
    return PreparedImport(
        sourceURL: document.sourceDocument.url,
        rawContents: "date,amount",
        fileName: fileName,
        detectedInstitution: .axis,
        detectedDocumentType: .bankAccount,
        parserName: document.parserName,
        financialDocument: document,
        validation: validation,
        importSession: ImportSession(fileName: fileName, parserName: document.parserName, transactionCount: 1, validation: validation)
    )
}

private func durableAttempt(outcome: ImportAttemptOutcome, transactionCount: Int) -> RepositoryImportAttempt {
    durableAttempt(
        id: "attempt-\(outcome.rawValue)",
        createdAtISO: "2026-07-20T00:00:00Z",
        outcomeCode: outcome.rawValue,
        transactionCount: transactionCount
    )
}

private func durableAttempt(
    id: String,
    createdAtISO: String,
    outcomeCode: String,
    transactionCount: Int
) -> RepositoryImportAttempt {
    RepositoryImportAttempt(
        ImportAttemptDTO(
            id: id,
            workspaceId: "workspace",
            createdAtISO: createdAtISO,
            outcomeCode: outcomeCode,
            coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
            accountDecisionCode: ImportAttemptAccountDecision.noFinancialMutation.rawValue,
            guidanceCode: ImportAttemptGuidance.integrityReviewRequired.rawValue,
            persistenceCode: ImportAttemptPersistence.rejectedRecorded.rawValue,
            transactionCount: transactionCount
        )
    )
}
