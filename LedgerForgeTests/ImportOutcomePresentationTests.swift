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
        #expect(blockedPresentation.status == "Supported transaction event blocked")
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

    @Test func everyKnownDurableOutcomeHasIndependentBoundedPresentation() {
        let expected: [(ImportAttemptOutcome, String, String)] = [
            (.successfulImport, "Import completed", "Persisted 2 transaction(s)"),
            (.validationFailure, "Validation failed", "Validation failed before persistence"),
            (.persistenceFailure, "Persistence failed", "Persistence failed after validation"),
            (.exactStatementDuplicate, "Previously imported", "The exact statement was already imported. No new financial history was written"),
            (.existingEligibleAxisUPIEvent, "Supported transaction event blocked", "A supported transaction event already exists. No new financial history was written"),
            (.repeatedEligibleIncomingEvidence, "Repeated incoming evidence", "Supported transaction evidence repeats within this import. No new financial history was written"),
            (.transactionEventOwnershipConflict, "Transaction-event ownership conflict", "Supported transaction-event ownership conflicts. No new financial history was written"),
            (.repositoryIntegrityConflict, "Repository integrity conflict", "Repository integrity prevented confirmation. No new financial history was written"),
            (.identityAmbiguity, "Account identity ambiguous", "Account identity could not be resolved unambiguously. No new financial history was written"),
            (.identityConflict, "Account identity conflict", "Account identity conflicts across accounts. No new financial history was written"),
            (.staleAccountChoice, "Account choice out of date", "The prepared account choice is no longer current. No new financial history was written"),
            (.staleProviderGeneration, "Persistence changed", "Persistence changed after preparation. No new financial history was written"),
            (.sqliteContention, "Persistence busy", "Confirmation did not win persistence contention. No new financial history was written")
        ]

        #expect(Set(expected.map { $0.0 }) == Set(ImportAttemptOutcome.allCases))

        for (outcome, expectedLabel, expectedExplanation) in expected {
            let presentation = DurableImportAttemptPresentation.outcome(
                code: outcome.rawValue,
                transactionCount: 2
            )
            #expect(presentation.label == expectedLabel)
            #expect(presentation.explanation == expectedExplanation)
            #expect(!presentation.label.contains(outcome.rawValue))
            #expect(!presentation.explanation.contains(outcome.rawValue))
        }
    }

    @Test func everyKnownCoverageHasIndependentBoundedPresentation() {
        let expected: [(ImportAttemptCoverage, String)] = [
            (.evaluatedSupportedOnly, "Supported transaction-event checks evaluated"),
            (.unsupportedOrUnevaluated, "Some transaction-event families unsupported or not evaluated")
        ]

        #expect(Set(expected.map { $0.0 }) == Set(ImportAttemptCoverage.allCases))

        for (coverage, expectedValue) in expected {
            let value = DurableImportAttemptPresentation.coverage(code: coverage.rawValue)
            #expect(value == expectedValue)
            #expect(!value.contains(coverage.rawValue))
            #expect(!value.contains("_"))
        }
    }

    @Test func everyKnownGuidanceHasIndependentBoundedPresentation() {
        let expected: [(ImportAttemptGuidance, String)] = [
            (.importCompleted, "Import completed"),
            (.reviewPriorImport, "Review the prior import"),
            (.supportedEventBlocked, "Review the supported transaction-event block"),
            (.correctValidationAndRetry, "Correct validation issues before retrying"),
            (.persistenceUnavailable, "Persistence is unavailable"),
            (.integrityReviewRequired, "Review required"),
            (.prepareAgain, "Prepare the import again"),
            (.retryConfirmation, "Retry confirmation")
        ]

        #expect(Set(expected.map { $0.0 }) == Set(ImportAttemptGuidance.allCases))

        for (guidance, expectedValue) in expected {
            let value = DurableImportAttemptPresentation.guidance(code: guidance.rawValue)
            #expect(value == expectedValue)
            #expect(!value.contains(guidance.rawValue))
            #expect(!value.contains("_"))
        }
    }

    @Test func hostileUnknownDurableValuesAreNeutralAndNeverReflected() {
        let hostileValues = [
            "future_outcome_/Users/private/account.csv",
            "sqlite_error_account-123",
            "identifier_XXXX9876",
            "fingerprint_private-value",
            "../../source-document",
            "raw_sql_DROP_TABLE"
        ]

        for hostileValue in hostileValues {
            let outcome = DurableImportAttemptPresentation.outcome(
                code: hostileValue,
                transactionCount: 0
            )
            let coverage = DurableImportAttemptPresentation.coverage(code: hostileValue)
            let guidance = DurableImportAttemptPresentation.guidance(code: hostileValue)
            let visibleAndAccessiblePresentation = [
                outcome.label,
                outcome.explanation,
                coverage,
                guidance,
                "\(outcome.label). \(outcome.explanation)"
            ].joined(separator: "|")

            #expect(outcome.label == "Outcome unavailable")
            #expect(outcome.explanation == "A durable import outcome is unavailable")
            #expect(coverage == "Coverage unavailable")
            #expect(guidance == "Guidance unavailable")
            #expect(!visibleAndAccessiblePresentation.contains(hostileValue))
            for fragment in ["/Users", "account-123", "XXXX9876", "fingerprint", "../", "DROP_TABLE"] {
                #expect(!visibleAndAccessiblePresentation.localizedCaseInsensitiveContains(fragment))
            }
        }
    }

    @Test func dashboardAndHistoryUseTheSameDurableOutcomeAuthority() {
        for outcome in ImportAttemptOutcome.allCases {
            let attempt = durableAttempt(outcome: outcome, transactionCount: 2)
            let shared = DurableImportAttemptPresentation(attempt: attempt)
            let dashboard = ImportActivityPresentation(
                importState: .idle,
                latestDurableAttempt: attempt
            )

            #expect(dashboard.status == shared.outcome.label)
            #expect(dashboard.subtitle == shared.outcome.explanation)
            #expect(dashboard.iconName == shared.outcome.iconName)
        }
    }

    @Test func materiallyDifferentDurableOutcomesRemainDistinct() {
        let persistenceFailure = DurableImportAttemptPresentation.outcome(code: ImportAttemptOutcome.persistenceFailure.rawValue, transactionCount: 0)
        let validationFailure = DurableImportAttemptPresentation.outcome(code: ImportAttemptOutcome.validationFailure.rawValue, transactionCount: 0)
        let duplicate = DurableImportAttemptPresentation.outcome(code: ImportAttemptOutcome.exactStatementDuplicate.rawValue, transactionCount: 0)
        let success = DurableImportAttemptPresentation.outcome(code: ImportAttemptOutcome.successfulImport.rawValue, transactionCount: 2)
        let contention = DurableImportAttemptPresentation.outcome(code: ImportAttemptOutcome.sqliteContention.rawValue, transactionCount: 0)
        let identityConflict = DurableImportAttemptPresentation.outcome(code: ImportAttemptOutcome.identityConflict.rawValue, transactionCount: 0)
        let eventBlock = DurableImportAttemptPresentation.outcome(code: ImportAttemptOutcome.existingEligibleAxisUPIEvent.rawValue, transactionCount: 0)
        let unknown = DurableImportAttemptPresentation.outcome(code: "future", transactionCount: 0)

        #expect(Set([
            persistenceFailure.label,
            validationFailure.label,
            duplicate.label,
            success.label,
            contention.label,
            identityConflict.label,
            eventBlock.label,
            unknown.label
        ]).count == 8)
        #expect(success.explanation == "Persisted 2 transaction(s)")
        #expect(!duplicate.explanation.contains("Persisted"))
        #expect(!contention.label.localizedCaseInsensitiveContains("failure"))
        #expect(!identityConflict.label.localizedCaseInsensitiveContains("unavailable"))
        #expect(!eventBlock.label.localizedCaseInsensitiveContains("identity"))
        #expect(unknown.label != persistenceFailure.label)
    }
}

private func activityPreparedImport(fileName: String, validationPassed: Bool) throws -> PreparedImport {
    let currency = try CurrencyCode("QAR")
    let transaction = Transaction(
        statementDate: try! StatementDate(canonical: "2023-11-14"),
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
