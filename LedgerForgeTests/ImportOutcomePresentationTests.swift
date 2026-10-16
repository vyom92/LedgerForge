// LedgerForgeTests/ImportOutcomePresentationTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
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

    @Test func equivalentSupportingSourceShowsZeroTransactionsAndNoTransactionNavigation() {
        let presentation = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "supporting.pdf",
                transactionCount: 0,
                validationPassed: true,
                persisted: true,
                errorMessage: nil,
                isEquivalentSupportingSource: true
            )
        )

        #expect(presentation.transactionCount == 0)
        #expect(presentation.persistenceStatus == "Equivalent Source Recorded")
        #expect(presentation.isEquivalentSupportingSource)
        #expect(!presentation.allowsViewingTransactions)
    }

    @Test func reconciledSupportingSourceRetainsEvidenceStatusAndNavigationExclusion() {
        var pending = ImportOutcomePresentation(result: ImportEngineResult(
            fileName: "supporting.pdf", transactionCount: 0, validationPassed: true,
            persisted: true, errorMessage: "The saved import needs a refresh.",
            hydrationOutcome: .committedReconciliationRequired,
            isEquivalentSupportingSource: true, recoveryRoute: .retryCanonicalReconciliation))
        pending.recoveryContextID = UUID()
        #expect(pending.requiresReconciliation)

        let recovered = pending.markingReconciled()

        #expect(recovered.recoveryRoute == .none)
        #expect(recovered.recoveryContextID == nil)
        #expect(recovered.persistenceStatus == "Equivalent Source Recorded")
        #expect(recovered.fileSubtitle == "Equivalent source evidence recorded — 0 additional transactions")
        #expect(recovered.isEquivalentSupportingSource)
        #expect(!recovered.allowsViewingTransactions)
        #expect(recovered.message == nil)
        #expect(recovered.tone == .success)
    }

    @Test func reconciledOrdinaryPartialSalaryAndInvestmentOutcomesKeepTheirExistingRoutes() {
        let variants = [
            (partial: false, salary: false, investment: false),
            (partial: true, salary: false, investment: false),
            (partial: false, salary: true, investment: false),
            (partial: false, salary: false, investment: true)
        ]
        for variant in variants {
            let pending = ImportOutcomePresentation(result: ImportEngineResult(
                fileName: "outcome", transactionCount: 0, validationPassed: true,
                persisted: true, errorMessage: "The saved import needs a refresh.",
                hydrationOutcome: .committedReconciliationRequired,
                isPartialImport: variant.partial, isSalaryImport: variant.salary,
                isInvestmentImport: variant.investment, recoveryRoute: .retryCanonicalReconciliation))
            let recovered = pending.markingReconciled()
            #expect(recovered.persistenceStatus == (variant.partial ? "Partial Import Succeeded" : "Persistence Succeeded"))
            #expect(recovered.allowsViewingTransactions == (!variant.salary && !variant.investment))
        }
    }

    @Test func salaryImportRoutesToSalaryHistoryWithoutClaimingTransactions() {
        let presentation = ImportOutcomePresentation(result: ImportEngineResult(
            fileName: "salary.pdf", transactionCount: 0, validationPassed: true,
            persisted: true, errorMessage: nil, isSalaryImport: true))
        #expect(presentation.isSalaryImport)
        #expect(!presentation.allowsViewingTransactions)
        #expect(presentation.fileSubtitle == "Imported Salary actual — source truth is available in Salary History")
    }

    @Test func failureHistoryStatesAreBoundedAndPrivacySafe() {
        let cases: [(validationPassed: Bool, attemptID: String?, count: Int,
                     validationStatus: String, persistenceStatus: String, message: String)] = [
            (false, nil, 0, "Validation Failed", "Not Persisted",
             "Import validation failed. The failure could not be added to Import History."),
            (false, "validation-attempt", 0, "Validation Failed", "Not Persisted",
             "Import validation failed. The failure was added to Import History."),
            (true, nil, 2, "Validation Passed", "Persistence Failed",
             "Import persistence failed. The failure could not be added to Import History."),
            (true, "persistence-attempt", 2, "Validation Passed", "Persistence Failed",
             "Import persistence failed. The failure was added to Import History.")
        ]
        for value in cases {
            let presentation = ImportOutcomePresentation(result: ImportEngineResult(
                fileName: "private-statement.csv",
                transactionCount: value.count,
                validationPassed: value.validationPassed,
                persisted: false,
                errorMessage: "Private narration /tmp/source.csv SQLite account-123 fingerprint-456 upi-reference",
                importAttemptId: value.attemptID
            ))
            #expect(presentation.fileName == "private-statement.csv")
            #expect(presentation.transactionCount == value.count)
            #expect(presentation.validationStatus == value.validationStatus)
            #expect(presentation.persistenceStatus == value.persistenceStatus)
            #expect(presentation.message == value.message)
            #expect(!presentation.allowsViewingTransactions)
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

    @MainActor
    @Test(.globalRuntimeStateIsolation)
    func importActivityCoversPreviewValidationCommitCancellationAndFailureWithoutSuccessInference() async throws {
        let readyOwner = try await MechanicsTestSupport.preparedAxisBankCSV()
        defer { readyOwner.cancel() }
        let ready = readyOwner.preparedImport

        #expect(ImportActivityPresentation(importState: .previewReady(ready), latestDurableAttempt: nil).status == "Ready to Import")
        #expect(ImportActivityPresentation(importState: .validationFailed(ready), latestDurableAttempt: nil).status == "Validation Failed")
        #expect(ImportActivityPresentation(importState: .committing(ready), latestDurableAttempt: nil).status == "Persisting")
        #expect(ImportActivityPresentation(importState: .cancelled(fileName: "cancelled.csv"), latestDurableAttempt: nil).status == "Cancelled")
        #expect(ImportActivityPresentation(
            importState: .failed(fileName: "failed.csv", message: "/tmp/private.sqlite", retrySourceURL: URL(fileURLWithPath: "/tmp/private.csv")),
            latestDurableAttempt: nil
        ).status == "Preparation Failed")
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
        let offset = durableAttempt(id: "attempt-z", createdAtISO: "2026-07-20T03:03:00+03:00", outcomeCode: ImportAttemptOutcome.successfulImport.rawValue, transactionCount: 1)
        let fractional = durableAttempt(id: "attempt-c", createdAtISO: "2026-07-20T00:03:00.000Z", outcomeCode: ImportAttemptOutcome.successfulImport.rawValue, transactionCount: 1)
        #expect(ImportActivityPresentation.latestDurableAttempt(from: [offset, fractional, equalTimestampHigherID])?.id == "attempt-z")
    }

    @Test func latestAttemptCacheTracksSameCountReplacementAndEmptyPublication() async throws {
        let original = durableAttempt(id: "retained", createdAtISO: "2026-07-20T00:01:00Z", outcomeCode: ImportAttemptOutcome.successfulImport.rawValue, transactionCount: 1)
        let other = durableAttempt(id: "other", createdAtISO: "2026-07-20T00:02:00Z", outcomeCode: ImportAttemptOutcome.validationFailure.rawValue, transactionCount: 0)
        let store = ImportAttemptStore()
        store.replaceAttempts([original, other])
        let model = ImportHistoryViewModel(store: store)
        #expect(model.latestDurableAttempt?.id == "other")
        model.select(id: "retained")
        let replacement = durableAttempt(id: "retained", createdAtISO: "2026-07-20T00:03:00Z", outcomeCode: ImportAttemptOutcome.successfulImport.rawValue, transactionCount: 1)
        store.replaceAttempts([replacement, other])
        try await Task.sleep(for: .milliseconds(30))
        #expect(model.latestDurableAttempt?.id == "retained")
        #expect(model.selectedAttempt?.createdAtISO == replacement.createdAtISO)
        store.replaceAttempts([])
        try await Task.sleep(for: .milliseconds(30))
        #expect(model.latestDurableAttempt == nil && model.selectedAttempt == nil)
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
            (.equivalentSourceRecorded, "Equivalent source recorded", "Recorded equivalent source evidence and persisted 0 additional transactions"),
            (.cbqSourceOverlapCommitted, "CBQ source recorded", "Recorded exact CBQ source lineage and persisted 2 new transaction(s)"),
            (.statementEquivalenceConflict, "Statement equivalence conflict", "The same statement period differs financially across formats. No new financial history was written"),
            (.statementEquivalenceEvidenceUnavailable, "Equivalence evidence unavailable", "Existing overlapping history lacks exact projection evidence. No new financial history was written"),
            (.bankSourceOverlapHeld, "Bank statement held", "An account section has unresolved or conflicting source evidence. No account section was imported"),
            (.equivalentFormatAlreadyRecorded, "Format already recorded", "This source format is already represented for the statement period. No new financial history was written"),
            (.partialImportCommitted, "Partial import completed", "Persisted 2 new transaction(s) from a reviewed partial statement"),
            (.reviewedPartialPlanStale, "Partial review out of date", "Repository truth changed after review. No new financial history was written"),
            (.partialImportUnsupportedEvidence, "Partial import unavailable", "The complete statement does not meet the supported partial-import evidence boundary"),
            (.validationFailure, "Validation failed", "Validation failed before persistence"),
            (.persistenceFailure, "Persistence failed", "Persistence failed after validation"),
            (.exactStatementDuplicate, "Previously imported", "The exact statement was already imported. No new financial history was written"),
            (.existingEligibleAxisUPIEvent, "Supported transaction event blocked", "A supported transaction event already exists. No new financial history was written"),
            (.repeatedEligibleIncomingEvidence, "Repeated incoming evidence", "Supported transaction evidence repeats within this import. No new financial history was written"),
            (.transactionEventOwnershipConflict, "Transaction-event ownership conflict", "Supported transaction-event ownership conflicts. No new financial history was written"),
            (.repositoryIntegrityConflict, "Repository integrity conflict", "Repository integrity prevented confirmation. No new financial history was written"),
            (.accountChoiceRequired, "Choose an account", "No existing account owns this verified identifier. Choose an eligible account or create a new one."),
            (.identifierOwnershipConflict, "Identifier ownership conflict", "Verified identifier ownership changed or conflicted before confirmation. No financial history was written."),
            (.identityAmbiguity, "Account identity ambiguous", "Account identity could not be resolved unambiguously. No new financial history was written"),
            (.identityConflict, "Account identity conflict", "Account identity conflicts across accounts. No new financial history was written"),
            (.staleAccountChoice, "Account choice out of date", "The prepared account choice is no longer current. No new financial history was written"),
            (.staleProviderGeneration, "Persistence changed", "Persistence changed after preparation. No new financial history was written"),
            (.sqliteContention, "Persistence busy", "Confirmation did not win persistence contention. No new financial history was written"),
            (.sourceSnapshotAcquisitionFailed, "Source could not be read", "Source snapshot acquisition failed. No financial history was written"),
            (.sourceSnapshotIntegrityFailed, "Prepared source could not be verified", "Source snapshot integrity verification failed. No financial history was written")
        ]

        #expect(Set(expected.map { $0.0 }) == Set(ImportAttemptOutcome.allCases))

        for (outcome, expectedLabel, expectedExplanation) in expected {
            let presentation = DurableImportAttemptPresentation.outcome(
                code: outcome.rawValue,
                transactionCount: 2
            )
            #expect(presentation.label == expectedLabel)
            #expect(presentation.explanation == expectedExplanation)
        }
    }

    @Test @MainActor func durableAccountSectionRendersProspectiveAndLegacyDecisions() throws {
        let expected: [(ImportAttemptAccountDecision, String, String)] = [
            (.matchedExisting, "Matched an existing account",
             "A verified account identifier is already owned by this account."),
            (.userSelectedExisting, "Used your selected account",
             "You selected an eligible existing account for this verified identifier."),
            (.createdNew, "Created a new account",
             "The import created a new account for this verified identifier."),
            (.selectedExisting, "Existing account used",
             "This older record does not distinguish an automatic match from an explicit choice."),
            (.resolvedOrCreated, "Account association completed",
             "This older record does not distinguish account matching from account creation."),
            (.noFinancialMutation, "Account outcome unavailable",
             "Detailed account-association information is unavailable."),
            (.sideEffectsMayExist, "Account outcome unavailable",
             "Detailed account-association information is unavailable.")
        ]
        #expect(Set(expected.map(\.0)) == Set(ImportAttemptAccountDecision.allCases))
        for outcome in [ImportAttemptOutcome.successfulImport, .partialImportCommitted] {
            for (decision, label, explanation) in expected {
                let presentation = try #require(DurableImportAccountOutcomeSection.presentation(
                    outcomeCode: outcome.rawValue,
                    accountDecisionCode: decision.rawValue
                ))
                #expect(presentation == ImportAccountOutcomePresentation(
                    label: label, explanation: explanation
                ))
            }
        }
    }

    @Test @MainActor func durableAccountSectionRendersEveryAccountRelatedRejection() throws {
        let expected: [(ImportAttemptOutcome, String, String)] = [
            (
                .accountChoiceRequired,
                "Choose an account",
                "No existing account owns this verified identifier. Choose an eligible account or create a new one."
            ),
            (
                .identifierOwnershipConflict,
                "Identifier ownership conflict",
                "Verified identifier ownership changed or conflicted before confirmation. No financial history was written."
            ),
            (
                .identityAmbiguity,
                "Account match ambiguous",
                "One verified identifier is associated with more than one account. No account was selected."
            ),
            (
                .identityConflict,
                "Account identity conflict",
                "Verified identifiers point to different accounts. No account was selected."
            ),
            (
                .staleAccountChoice,
                "Account choice out of date",
                "The selected account is no longer available or eligible. Prepare or review the import again."
            ),
            (
                .staleProviderGeneration,
                "Preparation out of date",
                "Persistence changed after preparation. Prepare the import again."
            )
        ]

        for (outcome, label, explanation) in expected {
            let presentation = try #require(DurableImportAccountOutcomeSection.presentation(
                outcomeCode: outcome.rawValue,
                accountDecisionCode: ImportAttemptAccountDecision.noFinancialMutation.rawValue
            ))
            #expect(presentation == ImportAccountOutcomePresentation(
                label: label,
                explanation: explanation
            ))
        }
    }

    @Test @MainActor func durableAccountSectionUsesUnavailableForApplicableUnknownValues() throws {
        let unavailable = ImportAccountOutcomePresentation(
            label: "Account outcome unavailable",
            explanation: "Detailed account-association information is unavailable."
        )
        let hostileValues = [
            "001234567890123",
            "XXXX-9876",
            "repository-account-private-123",
            "candidate-account-private-456",
            "private-statement.csv",
            "/Users/private/Documents/statement.csv",
            "sha256:private-fingerprint-value",
            "SQLITE_CONSTRAINT: identifiers.identifier",
            "committed",
            "rejected_recorded"
        ]

        for hostileValue in hostileValues {
            let unknownDecision = try #require(DurableImportAccountOutcomeSection.presentation(
                outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
                accountDecisionCode: hostileValue
            ))
            let unknownOutcome = try #require(DurableImportAccountOutcomeSection.presentation(
                outcomeCode: hostileValue,
                accountDecisionCode: ImportAttemptAccountDecision.matchedExisting.rawValue
            ))
            #expect(unknownDecision == unavailable)
            #expect(unknownOutcome == unavailable)
            let visibleAndAccessibleText = [
                unknownDecision.label,
                unknownDecision.explanation,
                unknownDecision.accessibilityText,
                unknownOutcome.label,
                unknownOutcome.explanation,
                unknownOutcome.accessibilityText
            ].joined(separator: " ")
            #expect(!visibleAndAccessibleText.localizedCaseInsensitiveContains(hostileValue))
        }
    }

    @Test @MainActor func unrelatedDurableOutcomesOmitTheAccountSection() {
        let unrelated: [ImportAttemptOutcome] = [
            .reviewedPartialPlanStale,
            .partialImportUnsupportedEvidence,
            .validationFailure,
            .persistenceFailure,
            .exactStatementDuplicate,
            .existingEligibleAxisUPIEvent,
            .repeatedEligibleIncomingEvidence,
            .transactionEventOwnershipConflict,
            .repositoryIntegrityConflict,
            .sqliteContention
        ]

        for outcome in unrelated {
            #expect(DurableImportAccountOutcomeSection.presentation(
                outcomeCode: outcome.rawValue,
                accountDecisionCode: ImportAttemptAccountDecision.matchedExisting.rawValue
            ) == nil)
        }
    }

    @Test func everyKnownCoverageHasIndependentBoundedPresentation() {
        let expected: [(ImportAttemptCoverage, String)] = [
            (.evaluatedSupportedOnly, "Supported transaction-event checks evaluated"),
            (.allRowsSupportedAxisUPIReviewed, "Every row reviewed with supported account-scoped Axis UPI evidence"),
            (.unsupportedOrUnevaluated, "Some transaction-event families unsupported or not evaluated")
        ]

        #expect(Set(expected.map { $0.0 }) == Set(ImportAttemptCoverage.allCases))

        for (coverage, expectedValue) in expected {
            let value = DurableImportAttemptPresentation.coverage(code: coverage.rawValue)
            #expect(value == expectedValue)
        }
    }

    @Test func everyKnownGuidanceHasIndependentBoundedPresentation() {
        let expected: [(ImportAttemptGuidance, String)] = [
            (.importCompleted, "Import completed"),
            (.equivalentSourceRecorded, "Equivalent source evidence recorded; no additional transactions were created"),
            (.partialImportCompleted, "Reviewed partial import completed"),
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
            #expect(outcome.label == "Outcome unavailable")
            #expect(outcome.explanation == "A durable import outcome is unavailable")
            #expect(coverage == "Coverage unavailable")
            #expect(guidance == "Guidance unavailable")
        }
    }

    @Test func dashboardAndHistoryUseTheSameDurableOutcomeAuthority() {
        let codes = ImportAttemptOutcome.allCases.map(\.rawValue) + ["future_outcome_private-123"]
        for code in codes {
            let attempt = durableAttempt(
                id: "attempt-\(code)", createdAtISO: "2026-07-20T00:00:00Z",
                outcomeCode: code, transactionCount: 3
            )
            let shared = DurableImportAttemptPresentation(attempt: attempt)
            let dashboard = ImportActivityPresentation(
                importState: .idle,
                latestDurableAttempt: attempt
            )

            #expect(dashboard.title == "Last import attempt")
            #expect(dashboard.status == shared.outcome.label)
            #expect(dashboard.subtitle == shared.outcome.explanation)
            #expect(dashboard.iconName == shared.outcome.iconName)
            if code == ImportAttemptOutcome.successfulImport.rawValue {
                #expect(dashboard.status == "Import completed")
                #expect(dashboard.subtitle == "Persisted 3 transaction(s)")
            }
        }
    }

}

@MainActor
private func durableAttempt(outcome: ImportAttemptOutcome, transactionCount: Int) -> RepositoryImportAttempt {
    durableAttempt(
        id: "attempt-\(outcome.rawValue)",
        createdAtISO: "2026-07-20T00:00:00Z",
        outcomeCode: outcome.rawValue,
        transactionCount: transactionCount
    )
}

@MainActor
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
