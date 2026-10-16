// LedgerForgeTests/ImportAccountOutcomePresentationTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct ImportAccountOutcomePresentationTests {

    @Test func confirmedOutcomeUsesOnlySufficientAuthoritativePlanEvidence() {
        #expect(ImportAccountOutcome.confirmed(
            advisoryIdentity: .resolved(accountId: "account-a"),
            accountChoice: .useExistingAccount(accountId: "account-a"),
            eligibleIdentifierCount: 1
        ) == .matchedExisting)
        #expect(ImportAccountOutcome.confirmed(
            advisoryIdentity: .noMatch,
            accountChoice: .useExistingAccount(accountId: "account-a"),
            eligibleIdentifierCount: 1
        ) == .userSelectedExisting)
        #expect(ImportAccountOutcome.confirmed(
            advisoryIdentity: .noMatch,
            accountChoice: .createProposedAccount,
            eligibleIdentifierCount: 1
        ) == .createdNew)
        #expect(ImportAccountOutcome.confirmed(
            advisoryIdentity: .noMatch,
            accountChoice: .createProposedAccount,
            eligibleIdentifierCount: 0
        ) == .unavailable)
        #expect(ImportAccountOutcome.confirmed(
            advisoryIdentity: .noMatch,
            accountChoice: .useExistingAccount(accountId: "account-a"),
            eligibleIdentifierCount: 0
        ) == .unavailable)
        #expect(ImportAccountOutcome.confirmed(
            advisoryIdentity: .resolved(accountId: "account-a"),
            accountChoice: .useExistingAccount(accountId: "account-b"),
            eligibleIdentifierCount: 1
        ) == .unavailable)
    }

    @Test func legacyDecisionValuesRemainReadableWithoutReinterpretation() {
        #expect(
            ImportAttemptAccountDecision(rawValue: "selected_existing") == .selectedExisting
        )
        #expect(
            ImportAttemptAccountDecision(rawValue: "resolved_or_created") == .resolvedOrCreated
        )
        #expect(
            ImportAttemptAccountDecision(rawValue: "no_financial_mutation") == .noFinancialMutation
        )
        #expect(
            ImportAttemptAccountDecision(rawValue: "side_effects_may_exist") == .sideEffectsMayExist
        )
    }

    @Test func hostileUnknownValuesNeverAppearInPresentation() {
        let unavailable = ImportAccountOutcomePresentation(
            label: "Account outcome unavailable",
            explanation: "Detailed account-association information is unavailable."
        )
        let hostileValues = [
            "001234567890123",
            "XXXX-9876",
            "account-repository-private-123",
            "candidate-account-private-456",
            "/Users/private/Documents/statement.csv",
            "sha256:private-fingerprint-value",
            "SQLITE_CONSTRAINT: identifiers.identifier",
            "source-statement-private.csv",
            "future_raw_persistence_value",
            "committed",
            "rejected_recorded"
        ]

        for hostileValue in hostileValues {
            let accountDecision = ImportAccountOutcomePresentationMapper.presentation(
                accountDecisionCode: hostileValue
            )
            let outcome = ImportAccountOutcomePresentationMapper.presentation(
                outcomeCode: hostileValue
            )
            let combined = ImportAccountOutcomePresentationMapper.presentation(
                outcomeCode: hostileValue,
                accountDecisionCode: ImportAttemptAccountDecision.matchedExisting.rawValue
            )
            let successfulWithHostileDecision = ImportAccountOutcomePresentationMapper.presentation(
                outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
                accountDecisionCode: hostileValue
            )
            #expect(accountDecision == unavailable)
            #expect(outcome == unavailable)
            #expect(combined == unavailable)
            #expect(successfulWithHostileDecision == unavailable)
            let visibleText = [
                accountDecision.label,
                accountDecision.explanation,
                outcome.label,
                outcome.explanation,
                combined.label,
                combined.explanation,
                successfulWithHostileDecision.label,
                successfulWithHostileDecision.explanation
            ].joined(separator: " ")
            #expect(!visibleText.contains(hostileValue))
        }
    }

    @Test func immediateResultsUseIndependentApprovedAccountOutcomeCopy() {
        let expected: [(ImportAccountOutcome, Bool, String, String)] = [
            (
                .matchedExisting,
                true,
                "Matched an existing account",
                "A verified account identifier is already owned by this account."
            ),
            (
                .userSelectedExisting,
                true,
                "Used your selected account",
                "You selected an eligible existing account for this verified identifier."
            ),
            (
                .createdNew,
                true,
                "Created a new account",
                "The import created a new account for this verified identifier."
            ),
            (
                .choiceRequired,
                false,
                "Choose an account",
                "No existing account owns this verified identifier. Choose an eligible account or create a new one."
            ),
            (
                .identityAmbiguous,
                false,
                "Account match ambiguous",
                "One verified identifier is associated with more than one account. No account was selected."
            ),
            (
                .identityConflict,
                false,
                "Account identity conflict",
                "Verified identifiers point to different accounts. No account was selected."
            ),
            (
                .identifierOwnershipConflict,
                false,
                "Identifier ownership conflict",
                "Verified identifier ownership changed or conflicted before confirmation. No financial history was written."
            ),
            (
                .staleAccountChoice,
                false,
                "Account choice out of date",
                "The selected account is no longer available or eligible. Prepare or review the import again."
            ),
            (
                .staleProviderGeneration,
                false,
                "Preparation out of date",
                "Persistence changed after preparation. Prepare the import again."
            )
        ]

        for (accountOutcome, persisted, label, explanation) in expected {
            let result = ImportEngineResult(
                fileName: "private-statement.csv",
                transactionCount: persisted ? 1 : 0,
                validationPassed: true,
                persisted: persisted,
                errorMessage: nil,
                accountOutcome: accountOutcome
            )
            let presentation = ImportOutcomePresentation(result: result)
            let expectedPresentation = ImportAccountOutcomePresentation(
                label: label,
                explanation: explanation
            )

            #expect(presentation.accountOutcomePresentation == expectedPresentation)
            #expect(presentation.accountOutcomePresentation?.accessibilityText == "\(label). \(explanation)")
        }
    }

    @Test func immediateUnavailableOutcomeMakesNoAccountClaim() {
        #expect(ImportAccountOutcomePresentationMapper.presentation(for: .unavailable) ==
            ImportAccountOutcomePresentation(label: "Account outcome unavailable",
                explanation: "Detailed account-association information is unavailable."))
        let presentation = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "private-statement.csv",
                transactionCount: 1,
                validationPassed: true,
                persisted: true,
                errorMessage: nil,
                accountOutcome: .unavailable
            )
        )

        #expect(presentation.accountOutcomePresentation == nil)
    }

    @Test func immediateAccountOutcomeAccessibilityExcludesSeparateIdentityEvidence() throws {
        let privateAccountID = "repository-account-private-123"
        let redactedIdentifier = "XXXX-9876"
        let presentation = ImportOutcomePresentation(
            result: ImportEngineResult(
                fileName: "private-statement.csv",
                transactionCount: 1,
                validationPassed: true,
                persisted: true,
                errorMessage: nil,
                accountId: privateAccountID,
                redactedIdentifier: redactedIdentifier,
                accountOutcome: .matchedExisting
            )
        )
        let accountOutcome = try #require(presentation.accountOutcomePresentation)
        let expectedAccessibility = "Matched an existing account. A verified account identifier is already owned by this account."

        #expect(accountOutcome.accessibilityText == expectedAccessibility)
        #expect(presentation.redactedIdentifier == redactedIdentifier)
        #expect(!accountOutcome.explanation.contains(redactedIdentifier))
        let hostileValues = [
            "001234567890123",
            redactedIdentifier,
            privateAccountID,
            "candidate-account-private-456",
            "private-statement.csv",
            "/Users/private/Documents/statement.csv",
            "sha256:private-fingerprint-value",
            "SQLITE_CONSTRAINT: identifiers.identifier",
            "committed",
            "rejected_recorded"
        ]
        for hostileValue in hostileValues {
            #expect(!accountOutcome.accessibilityText.localizedCaseInsensitiveContains(hostileValue))
        }
    }
}
