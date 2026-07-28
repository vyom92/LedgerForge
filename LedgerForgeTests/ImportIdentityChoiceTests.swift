// LedgerForgeTests/ImportIdentityChoiceTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct ImportIdentityChoiceTests {

    @Test func everyPresentableIdentityReviewUsesIndependentApprovedCopy() {
        let expected: [(ImportIdentityReview, String, String)] = [
            (
                .matchedExisting(accountId: "repository-account-private"),
                "Matched an existing account",
                "A verified account identifier is already owned by this account."
            ),
            (
                .choiceRequired(eligibleAccountIds: ["candidate-account-private"]),
                "Choose an account",
                "No existing account owns this verified identifier. Choose an eligible account or create a new one."
            ),
            (
                .ambiguous,
                "Account match ambiguous",
                "One verified identifier is associated with more than one account. No account was selected."
            ),
            (
                .conflict,
                "Account identity conflict",
                "Verified identifiers point to different accounts. No account was selected."
            )
        ]

        for (review, label, explanation) in expected {
            let projection = ImportIdentityReviewUIProjection(review: review)
            #expect(projection.presentation == ImportAccountOutcomePresentation(
                label: label,
                explanation: explanation
            ))
            #expect(projection.presentation?.accessibilityText == "\(label). \(explanation)")
        }
    }

    @Test func matchedAndChoiceIdentifiersRemainInternalToTheProjection() {
        let matchedID = "repository-account-private-123"
        let candidateIDs = ["candidate-account-private-456", "candidate-account-private-789"]
        let matched = ImportIdentityReviewUIProjection(
            review: .matchedExisting(accountId: matchedID)
        )
        let choice = ImportIdentityReviewUIProjection(
            review: .choiceRequired(eligibleAccountIds: candidateIDs)
        )

        #expect(matched.matchedAccountID == matchedID)
        #expect(choice.eligibleAccountIDs == candidateIDs)

        let visibleAndAccessibleText = [matched.presentation, choice.presentation]
            .compactMap { $0 }
            .flatMap { [$0.label, $0.explanation, $0.accessibilityText] }
            .joined(separator: " ")
        for privateID in [matchedID] + candidateIDs {
            #expect(!visibleAndAccessibleText.contains(privateID))
        }
    }

    @Test func ambiguousConflictAndUnavailableDoNotExposeIdentityEvidence() {
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
        let projections = [
            ImportIdentityReviewUIProjection(review: .ambiguous),
            ImportIdentityReviewUIProjection(review: .conflict)
        ]
        let visibleAndAccessibleText = projections
            .compactMap(\.presentation)
            .flatMap { [$0.label, $0.explanation, $0.accessibilityText] }
            .joined(separator: " ")

        for hostileValue in hostileValues {
            #expect(!visibleAndAccessibleText.localizedCaseInsensitiveContains(hostileValue))
        }

        let unavailable = ImportIdentityReviewUIProjection(review: .unavailable)
        #expect(unavailable.presentation == nil)
        #expect(unavailable.iconName == nil)
        #expect(unavailable.matchedAccountID == nil)
        #expect(unavailable.eligibleAccountIDs.isEmpty)
    }
}
