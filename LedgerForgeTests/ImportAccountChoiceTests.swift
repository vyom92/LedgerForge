// LedgerForgeTests/ImportAccountChoiceTests.swift

import Testing
@testable import LedgerForge

@MainActor
struct ImportAccountChoiceTests {

    @Test func noIdentityReviewStateSelectsAnAccountAutomatically() {
        let reviews: [ImportIdentityReview] = [
            .matchedExisting(accountId: "repository-account-private"),
            .choiceRequired(eligibleAccountIds: ["candidate-account-private"]),
            .ambiguous,
            .conflict,
            .unavailable
        ]

        for review in reviews {
            #expect(ImportAccountConfirmationPolicy.initialChoice(for: review) == nil)
        }
    }

    @Test func matchedExistingDoesNotRequireAnArtificialChoice() {
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: .matchedExisting(accountId: "repository-account-private"),
            choice: nil
        ))
    }

    @Test func choiceRequiredNeedsAValidExplicitChoice() {
        let review = ImportIdentityReview.choiceRequired(
            eligibleAccountIds: ["eligible-account-a", "eligible-account-b"]
        )

        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: nil
        ))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingAccount(accountId: "ineligible-account")
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingAccount(accountId: "eligible-account-b")
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .createNewAccount
        ))
    }

    @Test func ambiguityAndConflictAlwaysBlockConfirmation() {
        let choices: [ImportAccountChoice?] = [
            nil,
            .useExistingAccount(accountId: "candidate-account-private"),
            .createNewAccount
        ]

        for choice in choices {
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
                review: .ambiguous,
                choice: choice
            ))
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
                review: .conflict,
                choice: choice
            ))
        }
    }

    @Test func unavailablePreservesTheExistingNonIdentityConfirmationContract() {
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: .unavailable,
            choice: nil
        ))
    }
}
