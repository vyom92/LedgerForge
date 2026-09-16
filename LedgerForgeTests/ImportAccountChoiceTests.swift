// LedgerForgeTests/ImportAccountChoiceTests.swift

import Testing
import Foundation
@testable import LedgerForge

@MainActor
struct ImportAccountChoiceTests {

    @Test func creationNamesAndExplicitRelationshipsMustBeComplete() {
        for name in ["", " \n\t"] {
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
                review: .choiceRequired(eligibleAccountIds: []),
                choice: .createNewAccount(displayName: name)
            ))
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
                review: .cardChoiceRequired(eligibleLiabilityAccountIds: []),
                choice: .createNewCardLiabilityAccountAndInstrument(displayName: name)
            ))
        }
        let review = ImportIdentityReview.cardChoiceRequired(eligibleLiabilityAccountIds: ["liability"])
        let incomplete = ImportCardInstrumentChoice.createNewInstrument(relationship: .replacement)
        #expect(!incomplete.isComplete)
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingCardLiabilityAccount(accountId: "liability", instrumentChoice: incomplete)
        ))
        #expect(ImportCardInstrumentChoice.createNewInstrument().isComplete)
        #expect(ImportCardInstrumentChoice.createNewInstrument(relationship: .replacement, relatedInstrumentId: "existing").isComplete)
        #expect(!ImportCardInstrumentChoice.createNewInstrument(relatedInstrumentId: "existing").isComplete)
        let zeroSectionChoice = ImportAccountChoice.useExistingCardLiabilityAccountSections(accountId: "liability", sectionChoices: [:])
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(review: review, choice: zeroSectionChoice, requiredCardSectionIDs: []))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review, choice: zeroSectionChoice, requiredCardSectionIDs: ["section"]))
    }

    @Test func noIdentityReviewStateSelectsAnAccountAutomatically() {
        let reviews: [ImportIdentityReview] = [
            .matchedExisting(accountId: "repository-account-private"),
            .choiceRequired(eligibleAccountIds: ["candidate-account-private"]),
            .liabilityAccountChoiceRequired(eligibleLiabilityAccountIds: ["axis-liability-account-private"]),
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
            choice: .createNewAccount(displayName: "Imported review account")
        ))
    }

    @Test func ambiguityAndConflictAlwaysBlockConfirmation() {
        let choices: [ImportAccountChoice?] = [
            nil,
            .useExistingAccount(accountId: "candidate-account-private"),
            .createNewAccount(displayName: "Imported review account")
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
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: .unavailable, choice: nil, requiresNamedCreation: true
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: .unavailable, choice: .createNewAccount(displayName: "Bank account"), requiresNamedCreation: true
        ))
    }

    @Test func cardChoiceRequiresEligibleLiabilityAccountAndCompletedSectionDecisions() {
        let review = ImportIdentityReview.cardChoiceRequired(
            eligibleLiabilityAccountIds: ["eligible-card-account"]
        )
        let completeChoices: [String: ImportCardInstrumentChoice] = [
            "instrument-section-1": .reuseExistingInstrument(instrumentId: "instrument-a"),
            "instrument-section-2": .createNewInstrument()
        ]

        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review, choice: nil))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingCardLiabilityAccountSections(
                accountId: "eligible-card-account",
                sectionChoices: [:]
            )
        ))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingCardLiabilityAccountSections(
                accountId: "ineligible-card-account",
                sectionChoices: completeChoices
            )
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingCardLiabilityAccountSections(
                accountId: "eligible-card-account",
                sectionChoices: completeChoices
            )
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .createNewCardLiabilityAccountAndInstrument(displayName: "Imported review card")
        ))
    }

    @Test func axisLiabilityOnlyReviewUsesOrdinaryAccountChoicesWithoutAutomaticSelection() {
        let review = ImportIdentityReview.liabilityAccountChoiceRequired(
            eligibleLiabilityAccountIds: ["axis-account-a", "axis-account-b"]
        )

        #expect(review.eligibleAccountIds == ["axis-account-a", "axis-account-b"])
        #expect(review.requiresExplicitChoice)
        #expect(review.blocksConfirmation)
        #expect(ImportAccountConfirmationPolicy.initialChoice(for: review) == nil)

        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review, choice: nil))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingAccount(accountId: "axis-account-b")
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .createNewAccount(displayName: "Imported review account")
        ))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
            review: review,
            choice: .useExistingAccount(accountId: "other-institution-account")
        ))
    }

    @Test func axisLiabilityOnlyReviewRejectsEveryInstrumentOrSectionChoice() {
        let review = ImportIdentityReview.liabilityAccountChoiceRequired(
            eligibleLiabilityAccountIds: ["axis-account"]
        )
        let instrumentChoices: [ImportAccountChoice] = [
            .useExistingCardLiabilityAccount(
                accountId: "axis-account",
                instrumentChoice: .reuseExistingInstrument(instrumentId: "instrument")
            ),
            .useExistingCardLiabilityAccount(
                accountId: "axis-account",
                instrumentChoice: .createNewInstrument()
            ),
            .useExistingCardLiabilityAccountSections(
                accountId: "axis-account",
                sectionChoices: [
                    "section": .reuseExistingInstrument(instrumentId: "instrument")
                ]
            ),
            .createNewCardLiabilityAccountAndInstrument(displayName: "Imported review card")
        ]

        for choice in instrumentChoices {
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(
                review: review,
                choice: choice
            ))
        }
    }

    @Test func axisLiabilityOnlyProjectionDoesNotExposeInstrumentActions() {
        let projection = ImportIdentityReviewUIProjection(
            review: .liabilityAccountChoiceRequired(eligibleLiabilityAccountIds: ["axis-account"])
        )

        #expect(projection.eligibleAccountIDs == ["axis-account"])
        #expect(projection.presentation?.label == "Choose a liability account")
        #expect(projection.presentation?.explanation.contains("instrument sections") == true)
        #expect(projection.presentation?.label.localizedCaseInsensitiveContains("instrument") == false)
    }
}
