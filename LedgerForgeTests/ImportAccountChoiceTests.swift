// LedgerForgeTests/ImportAccountChoiceTests.swift

import Testing
import Foundation
import CryptoKit
@testable import LedgerForge

@MainActor
struct ImportAccountChoiceTests {

    @Test(.globalRuntimeStateIsolation)
    func genuineCardSectionReviewRetainsEstablishedLiabilityOwner() async throws {
        let environment = ProcessInfo.processInfo.environment
        let checkpoint = URL(fileURLWithPath: try #require(environment["LEDGERFORGE_S99_IMPORT_OWNER_DATABASE"]))
        let bytes = try Data(contentsOf: checkpoint)
        #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            == environment["LEDGERFORGE_S99_IMPORT_OWNER_SHA256"])
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-card-owner-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let copy = folder.appendingPathComponent("qualification.sqlite")
        try FileManager.default.copyItem(at: checkpoint, to: copy)
        let sqlite = try SQLiteRepositoryProvider(path: copy.path, migrations: allMigrations, access: .existing)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        let workspace = try #require(try sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let before = try NetWorthTestSupport.financialDigest(sqlite.database)
        let inbox = try provider.gmailInboxRepo.load(account: try #require(try provider.gmailInboxRepo.storedAccounts().first))
        let source = try #require(inbox.orderedSources.first {
            $0.sha256 == "e3be5a815dfc9574e03d24ece688084bae7b04a167731efa26f4611ea8bc33ca"
        })
        let url = try #require(source.importURL)
        let original = try provider.gmailInboxRepo.original(sha256: try #require(source.sha256), byteCount: source.expectedByteCount)
        let passwords = DefaultPasswordProvider(supportedInstitutionCodes: [Institution.cbq.statementPasswordCredentialScope], challenge: { _ in nil })
        let password = try #require(try await passwords.rememberedPasswordCandidates(for: ImportRequest(fileURL: url)).first).value
        let compare = try await CBQCreditCardPrivateAcceptanceTests().gmailComparison(bytes: original, url: url, password: password)
        let persistence = DefaultImportPersistenceCoordinator(databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspace, workspaceName: "Authentic owner review"))
        let engine = ImportEngine(importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(), passwordProvider: passwords),
            sourceSnapshotAcquirer: { try GmailImportSource.acquireSnapshot(from: $0, repository: provider.gmailInboxRepo) },
            importPersistenceCoordinator: persistence,
            persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil }))
        let prepared = try await engine.prepareImport(from: url)
        defer { engine.cancelPreparedImport(prepared) }
        try compare(prepared)
        let evidence = try #require(prepared.financialDocument.cardStatementEvidence)
        let observation = try #require(evidence.accountSourceIdentityObservations.first)
        let cards = try provider.cardRepo.snapshot(workspaceId: workspace)
        let owners = Set(cards.sourceObservations.filter {
            $0.subjectKind == CardSourceIdentitySubject.liabilityAccount.rawValue &&
                $0.associationAuthority == "user_confirmed" &&
                $0.observationKind == observation.kind.rawValue && $0.sourceValue == observation.value
        }.map(\.subjectId))
        let owner = try #require(owners.count == 1 ? owners.first : nil)
        let review = try engine.reviewPreparedImport(prepared)
        #expect(review == .cardChoiceRequired(eligibleLiabilityAccountIds: [owner], matchedLiabilityAccountId: owner))
        #expect(review.requiresExplicitChoice)
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review, choice: nil))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review,
            choice: .createNewCardLiabilityAccountAndInstrument(displayName: "Separate account")))
        for account in try provider.accountRepo.accounts(workspaceId: workspace) where account.id != owner {
            #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: review,
                choice: .useExistingCardLiabilityAccount(accountId: account.id,
                    instrumentChoice: .createNewInstrument())))
        }
        let projection = ImportIdentityReviewUIProjection(review: review)
        #expect(projection.matchedAccountID == owner && projection.eligibleAccountIDs == [owner])
        #expect(projection.presentation?.label == "Review card sections")
        #expect(try NetWorthTestSupport.financialDigest(sqlite.database) == before)
    }

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

    @Test func bankSectionChoicesRequireEveryUnresolvedSectionAndKeepSourceAccountsSeparate() {
        let sections: [BankSectionIdentityReview] = [
            BankSectionIdentityReview(
                sectionID: "section-nre",
                product: "NRE Savings",
                sourceAccountLabel: "XXXXXXXXXXX1001",
                period: nil,
                transactionCount: 0,
                identityReview: .matchedExisting(accountId: "account-nre")
            ),
            BankSectionIdentityReview(
                sectionID: "section-nro",
                product: "NRO Savings",
                sourceAccountLabel: "XXXXXXXXXXX2002",
                period: nil,
                transactionCount: 0,
                identityReview: .choiceRequired(eligibleAccountIds: ["account-nro", "account-other"])
            )
        ]

        let complete: [String: ImportBankSectionChoice] = [
            "section-nro": .useExistingAccount(accountId: "account-nro")
        ]
        #expect(ImportAccountConfirmationPolicy.bankSectionChoicesAreComplete(
            sections: sections,
            choices: complete
        ))
        #expect(!ImportAccountConfirmationPolicy.bankSectionChoicesAreComplete(
            sections: sections,
            choices: [:]
        ))
        #expect(!ImportAccountConfirmationPolicy.bankSectionChoicesAreComplete(
            sections: sections,
            choices: ["section-nro": .useExistingAccount(accountId: "account-nre")]
        ))
        #expect(!ImportAccountConfirmationPolicy.bankSectionChoicesAreComplete(
            sections: sections,
            choices: ["section-nro": .createNewAccount(displayName: " \n")]
        ))
        let colliding = [
            sections[0],
            BankSectionIdentityReview(
                sectionID: "section-nro-matched",
                product: "NRO Savings",
                sourceAccountLabel: "XXXXXXXXXXX2002",
                period: nil,
                transactionCount: 0,
                identityReview: .matchedExisting(accountId: "account-nre")
            )
        ]
        #expect(!ImportAccountConfirmationPolicy.bankSectionChoicesAreComplete(
            sections: colliding,
            choices: [:]
        ))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(
            review: .bankSections(sections),
            choice: .bankSections(complete)
        ))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: .bankSections(sections), choice: nil))
        #expect(!ImportAccountConfirmationPolicy.allowsConfirmation(review: .bankSections([]), choice: nil))
        #expect(ImportAccountConfirmationPolicy.allowsConfirmation(review: .bankSections([sections[0]]), choice: nil))
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
