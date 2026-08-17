import CryptoKit
import Foundation
import PDFKit
import Testing
@testable import LedgerForge

@MainActor
struct AmericanExpressCreditCardPDFTests {
    @Test(.globalRuntimeStateIsolation)
    func syntheticNativeTextPDFPreservesExactCardSemantics() async throws {
        let context = makeContext(workspaceID: "amex-synthetic-parse", inMemory: true)
        let prepared = try await context.engine.prepareImport(from: Self.fixtureURL)
        defer { context.engine.cancelPreparedImport(prepared) }

        #expect(prepared.detectedInstitution == .amex)
        #expect(prepared.detectedDocumentType == .creditCard)
        #expect(prepared.parserName == "American Express Credit Card PDF")
        #expect(prepared.validation.passed)
        #expect(prepared.transactionCount == 9)
        #expect(prepared.financialDocument.bookedCurrency?.code == "QAR")
        #expect(prepared.financialDocument.financialIdentifiers.isEmpty)
        let evidence = try #require(prepared.financialDocument.cardStatementEvidence)
        #expect(evidence.declaredStatementPeriod.start.canonical == "2026-07-01")
        #expect(evidence.declaredStatementPeriod.end.canonical == "2026-07-31")
        #expect(evidence.transactionAnnotations.map(\.rowScope.persistenceCode) == [
            "account_level", "instrument_level", "instrument_level", "instrument_level",
            "instrument_level", "instrument_level", "instrument_level", "instrument_level", "instrument_level"
        ])
        #expect(evidence.transactionAnnotations.map(\.liabilityEffect) == [
            .decreasesAmountOwed, .increasesAmountOwed, .increasesAmountOwed,
            .decreasesAmountOwed, .increasesAmountOwed, .increasesAmountOwed,
            .increasesAmountOwed, .increasesAmountOwed, .decreasesAmountOwed
        ])
        #expect(evidence.transactionAnnotations.first?.sourceTransactionDate.canonical == "2026-06-30")
        #expect(prepared.financialDocument.transactions.first?.statementDate?.canonical == "2026-07-01")
        #expect(prepared.financialDocument.transactions.allSatisfy {
            $0.debitMoney == nil && $0.creditMoney == nil && $0.runningBalanceMoney == nil
        })
        #expect(evidence.transactionAnnotations[2].originalMerchantMoney == (try Money(amount: Decimal(string: "1.234")!, currency: "BHD")))
        #expect(evidence.transactionAnnotations[3].originalMerchantMoney == (try Money(amount: Decimal(string: "-5.678")!, currency: "BHD")))
        #expect(evidence.transactionAnnotations[6].originalMerchantMoney == (try Money(amount: 1000, currency: "KRW")))
        #expect(evidence.transactionAnnotations.filter { $0.originalMerchantMoney != nil }.count == 3)
        #expect(prepared.financialDocument.transactions[7].description == "FICTIONAL AIR JOURNEY\nTBD TO SAMPLE BAY\nTICKET 000-0000000000\nPASSENGER JORDAN SAMPLE")
        #expect(prepared.financialDocument.transactions.map(\.reference) == [
            "PAY-FICTION-001", "BUY-FICTION-002", "BHD-FICTION-003", "BHD-REFUND-FICTION-004",
            "TINY-DEBIT-FICTION-005", "ORDER-FICTION-006", "KRW-FICTION-007",
            "TRAVEL-FICTION-008", "TINY-CREDIT-FICTION-009"
        ])
        #expect(prepared.financialDocument.transactions[4].statementDate?.canonical == "2026-07-20")
        #expect(prepared.financialDocument.transactions[5].statementDate?.canonical == "2026-07-12")
        #expect(try #require(PDFDocument(url: Self.fixtureURL)).pageCount == 5)
        #expect(evidence.instrumentSections.map(\.sourceOrdinal) == [1, 2, 3])
        #expect(evidence.instrumentSections.map(\.holderLabel) == ["AVERY EXAMPLE", "AVERY EXAMPLE", "JORDAN SAMPLE"])
        #expect(evidence.instrumentSections.map { $0.sourceIdentityObservations.first?.value } == [
            "9999-XXXX", "3777-XXXXXX-20002", "3777-XXXXXX-30003"
        ])
        #expect(evidence.instrumentSections.map(\.signedNetTotal) == [
            try Money(amount: 70, currency: "QAR"),
            try Money(amount: Decimal(string: "30.01")!, currency: "QAR"),
            try Money(amount: Decimal(string: "449.99")!, currency: "QAR")
        ])
        #expect(evidence.accountSourceIdentityObservations.first?.value == "9999-XXXX")
        #expect(evidence.accountSourceIdentityObservations.first?.kind == .liabilityMembershipNumber)
        #expect(evidence.instrumentSections.first?.sourceIdentityObservations.first?.kind == .instrumentCardAccountNumber)
        #expect(evidence.accountSourceIdentityObservations.allSatisfy { !$0.value.contains("MR-") })
        #expect(evidence.instrumentSections.flatMap(\.sourceIdentityObservations).allSatisfy { !$0.value.contains("MR-") })
    }

    @Test
    func exactFamilyDetectionRejectsUnsupportedNearMatch() throws {
        let pdf = try #require(PDFDocument(url: Self.fixtureURL))
        let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
        let exact = SignatureInstitutionDetector().detect(from: text)
        #expect(exact.metadata.institution == .amex)
        #expect(exact.metadata.documentType == .creditCard)
        #expect(exact.reasons.count == 5)

        let nearMatch = text
            .replacingOccurrences(of: "The Platinum Card (QAR)", with: "Unsupported Premium Card (QAR)")
            .replacingOccurrences(of: "AMEX (MIDDLE EAST) B.S.C. (C)", with: "UNSUPPORTED CARD ISSUER")
        let rejected = SignatureInstitutionDetector().detect(from: nearMatch)
        #expect(rejected.metadata.institution == .unknown)
        #expect(rejected.metadata.documentType == .unknown)
    }

    @Test
    func sharedCardEvidenceAllowsAccountOnlyStatementsWithoutInventedSections() throws {
        let period = try DeclaredStatementPeriod(
            start: StatementDate(canonical: "2026-07-01"),
            end: StatementDate(canonical: "2026-07-31")
        )
        let evidence = try CardStatementEvidence(
            statementDate: StatementDate(canonical: "2026-07-31"),
            declaredStatementPeriod: period,
            nativeCurrency: CurrencyCode("QAR"),
            accountSourceIdentityObservations: [],
            instrumentSections: [],
            transactionAnnotations: [],
            summaryComponents: [],
            reconciliationRuleIdentifier: "shared.account-only.test.v1"
        )

        #expect(evidence.instrumentSections.isEmpty)
    }

    @Test
    func malformedSummaryHeaderAndTransactionFailClosed() throws {
        let bytes = try Data(contentsOf: Self.fixtureURL)
        let pdf = try #require(PDFDocument(data: bytes))
        let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
        let normalized = try AmericanExpressCreditCardPDFNormalizer().normalize(
            text: text,
            sourceBytes: bytes,
            fileURL: Self.fixtureURL
        )
        let metadata = DocumentMetadata(
            institution: .amex,
            documentType: .creditCard,
            fileFormat: .pdf,
            confidence: 1
        )
        let changedHeader = NormalizedDocument(
            document: normalized.document,
            metadata: metadata,
            rows: normalized.rows,
            header: NormalizedRow(rowNumber: 1, values: ["Changed header"]),
            sourceContext: normalized.sourceContext
        )
        #expect(throws: AmericanExpressCreditCardPDFParserError.changedHeader) {
            _ = try AmericanExpressCreditCardPDFParser().parse(document: changedHeader)
        }

        var malformedValues = normalized.rows[1].values
        malformedValues[6] = "not-money"
        var malformedRows = normalized.rows
        malformedRows[1] = NormalizedRow(rowNumber: normalized.rows[1].rowNumber, values: malformedValues)
        let malformedTransaction = NormalizedDocument(
            document: normalized.document,
            metadata: metadata,
            rows: malformedRows,
            header: normalized.header,
            sourceContext: normalized.sourceContext
        )
        #expect(throws: AmericanExpressCreditCardPDFParserError.self) {
            _ = try AmericanExpressCreditCardPDFParser().parse(document: malformedTransaction)
        }

        let parsed = try AmericanExpressCreditCardPDFParser().parse(document: NormalizedDocument(
            document: normalized.document,
            metadata: metadata,
            rows: normalized.rows,
            header: normalized.header,
            sourceContext: normalized.sourceContext
        ))
        let existing = try #require(parsed.cardStatementEvidence)
        let malformedSummary = try CardStatementEvidence(
            statementDate: existing.statementDate,
            declaredStatementPeriod: existing.declaredStatementPeriod,
            nativeCurrency: existing.nativeCurrency,
            accountSourceIdentityObservations: existing.accountSourceIdentityObservations,
            instrumentSections: existing.instrumentSections,
            transactionAnnotations: existing.transactionAnnotations,
            summaryComponents: existing.summaryComponents.filter { $0.persistenceCode != "new_balance" } + [
                .newBalance(try Money(amount: 999, currency: "QAR"))
            ],
            reconciliationRuleIdentifier: existing.reconciliationRuleIdentifier
        )
        let malformedDocument = FinancialDocument(
            sourceDocument: parsed.sourceDocument,
            metadata: parsed.metadata,
            parserName: parsed.parserName,
            bookedCurrency: parsed.bookedCurrency,
            declaredStatementPeriod: parsed.declaredStatementPeriod,
            transactions: parsed.transactions,
            financialIdentifiers: parsed.financialIdentifiers,
            cardStatementEvidence: malformedSummary
        )
        #expect(!ImportValidator.validate(financialDocument: malformedDocument).passed)
    }

    @Test(.globalRuntimeStateIsolation)
    func providerOwnedCardGraphIsAtomicAndObservableInBothProviders() async throws {
        try await verifyPersistence(inMemory: true)
        try await verifyPersistence(inMemory: false)
    }

    @Test(.globalRuntimeStateIsolation)
    func encryptedAndUnlockedSyntheticSourcesAreExactSemanticEquivalentsInBothOrdersAndProviders() async throws {
        let encrypted = Self.encryptedFixtureURL
        let unlockedHash = SHA256.hash(data: try Data(contentsOf: Self.fixtureURL))
        let encryptedHash = SHA256.hash(data: try Data(contentsOf: encrypted))
        #expect(unlockedHash != encryptedHash)

        for inMemory in [true, false] {
            for (orderName, urls) in [
                ("unlocked-encrypted", [Self.fixtureURL, encrypted]),
                ("encrypted-unlocked", [encrypted, Self.fixtureURL])
            ] {
                let workspaceID = "amex-semantic-\(orderName)-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
                let credentials = InMemoryStatementPasswordCredentialStore(passwords: [
                    Institution.amex.statementPasswordCredentialScope: Self.syntheticFixturePassword
                ])
                let passwordProvider = DefaultPasswordProvider(
                    credentialStore: credentials,
                    challenge: { _ in
                        Issue.record("Remembered synthetic credential should unlock without a challenge")
                        return nil
                    }
                )
                let importCoordinator = DefaultImportCoordinator(
                    readerRegistry: DefaultReaderRegistry(),
                    passwordProvider: passwordProvider
                )
                let context = try makePersistentContext(
                    workspaceID: workspaceID,
                    inMemory: inMemory,
                    importCoordinator: importCoordinator
                )
                defer { context.cleanup() }

                let first = try await context.engine.prepareImport(from: urls[0])
                let firstResult = try persist(
                    first,
                    choice: .createNewCardLiabilityAccountAndInstrument,
                    context: context
                )
                context.engine.cancelPreparedImport(first)
                #expect(firstResult.persisted)
                #expect(firstResult.transactionCount == 9)

                let second = try await context.engine.prepareImport(from: urls[1])
                let secondResult = try persist(second, choice: nil, context: context)
                context.engine.cancelPreparedImport(second)
                #expect(secondResult.persisted)
                #expect(secondResult.isEquivalentSupportingSource)
                #expect(secondResult.transactionCount == 0)
                #expect(secondResult.accountId == firstResult.accountId)

                #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 9)
                let card = try context.provider.cardRepo.snapshot(workspaceId: workspaceID)
                #expect(card.instruments.count == 3)
                #expect(card.statements.count == 2)
                #expect(card.sections.count == 6)
                #expect(card.sectionObservations.count == 6)
                #expect(card.transactionEvidence.count == 9)
                #expect(card.semanticProjections.count == 2)
                #expect(card.semanticGroups.count == 1)
                #expect(card.semanticMembers.map(\.role.rawValue).sorted() == ["authoritative", "supporting"])
                let canonicalEventSets = card.semanticProjections.map { Set($0.events.map(\.canonicalTransactionId)) }
                #expect(canonicalEventSets.count == 2)
                #expect(canonicalEventSets[0] == canonicalEventSets[1])
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func sameAccountAndPeriodWithDifferentExactProjectionFailsClosedInBothProviders() async throws {
        for inMemory in [true, false] {
            let workspaceID = "amex-semantic-conflict-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
            let context = try makePersistentContext(workspaceID: workspaceID, inMemory: inMemory)
            defer { context.cleanup() }

            let first = try await context.engine.prepareImport(from: Self.fixtureURL)
            let firstResult = try persist(
                first,
                choice: .createNewCardLiabilityAccountAndInstrument,
                context: context
            )
            context.engine.cancelPreparedImport(first)
            #expect(firstResult.persisted)

            let variantURL = try Self.variantFixtureURL(label: "semantic-conflict")
            defer { try? FileManager.default.removeItem(at: variantURL) }
            let second = try await context.engine.prepareImport(from: variantURL)
            let conflictingDocument = try replacingFirstReference(in: second.financialDocument)
            let conflictingValidation = ImportValidator.validate(financialDocument: conflictingDocument)
            #expect(conflictingValidation.passed)

            do {
                _ = try context.coordinator.persistValidatedImport(
                    financialDocument: conflictingDocument,
                    importSession: second.importSession,
                    validation: conflictingValidation,
                    fingerprintSet: second.fingerprintSet,
                    accountChoice: nil,
                    providerGeneration: context.provider.generationToken
                )
                Issue.record("Expected exact same-period semantic conflict to reject")
            } catch let failure as ImportPersistenceCommitFailure {
                #expect(failure.originalError as? ImportPersistenceCoordinationError == .statementEquivalenceConflict)
            }
            context.engine.cancelPreparedImport(second)

            #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 9)
            let card = try context.provider.cardRepo.snapshot(workspaceId: workspaceID)
            #expect(card.statements.count == 1)
            #expect(card.semanticProjections.count == 1)
            #expect(card.semanticGroups.count == 1)
            #expect(try context.provider.importSessionRepo.importSession(id: second.importSession.id.uuidString) == nil)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func financialPageAfterRewardsIsRejected() async throws {
        let source = try #require(PDFDocument(url: Self.fixtureURL))
        let hostile = PDFDocument()
        for sourceIndex in [0, 2, 0, 3] {
            hostile.insert(try #require(source.page(at: sourceIndex)?.copy() as? PDFPage), at: hostile.pageCount)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("amex-hostile-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(hostile.write(to: url))
        let bytes = try Data(contentsOf: url)
        let text = (0..<hostile.pageCount).compactMap { hostile.page(at: $0)?.string }.joined(separator: "\n")
        #expect(throws: AmericanExpressCreditCardPDFNormalizationError.self) {
            _ = try AmericanExpressCreditCardPDFNormalizer().normalize(text: text, sourceBytes: bytes, fileURL: url)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func weakIdentityContinuityRelationshipsAndLifecycleRequireExplicitAuthority() async throws {
        try await verifyWeakIdentityDecisions(inMemory: true)
        try await verifyWeakIdentityDecisions(inMemory: false)
    }

    @Test(.globalRuntimeStateIsolation)
    func staleProviderGenerationRejectsCardImportWithoutAcceptedResidue() async throws {
        for inMemory in [true, false] {
            let workspaceID = "amex-stale-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
            let context = try makePersistentContext(workspaceID: workspaceID, inMemory: inMemory)
            defer { context.cleanup() }
            let prepared = try await context.engine.prepareImport(from: Self.fixtureURL)
            do {
                _ = try context.coordinator.persistValidatedImport(
                    financialDocument: prepared.financialDocument,
                    importSession: prepared.importSession,
                    validation: prepared.validation,
                    fingerprintSet: prepared.fingerprintSet,
                    accountChoice: .createNewCardLiabilityAccountAndInstrument,
                    providerGeneration: ProviderGenerationToken()
                )
                Issue.record("Expected stale card provider generation to reject")
            } catch let failure as ImportPersistenceCommitFailure {
                #expect(failure.originalError as? ImportPersistenceCoordinationError == .staleProviderGeneration)
            }
            context.engine.cancelPreparedImport(prepared)
            #expect(try context.provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
            #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
            #expect(try context.provider.cardRepo.snapshot(workspaceId: workspaceID) == .empty)
            #expect(try context.provider.importSessionRepo.importSession(id: prepared.importSession.id.uuidString) == nil)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func strongInstrumentIdentifierConflictRejectsAtomicallyInBothProviders() async throws {
        for inMemory in [true, false] {
            let workspaceID = "amex-strong-conflict-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
            let context = try makePersistentContext(workspaceID: workspaceID, inMemory: inMemory)
            defer { context.cleanup() }
            let mapper = ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "Amex Strong Conflict")

            let first = try await context.engine.prepareImport(from: Self.fixtureURL)
            let firstPlan = try strongIdentifierPlan(
                prepared: first,
                mapper: mapper,
                provider: context.provider,
                accountID: "amex-strong-account-one",
                identifier: "amex-test-verified-identifier"
            )
            guard case .committed = context.provider.confirmedImportRepo.commitConfirmedImport(firstPlan) else {
                Issue.record("Expected the first strong instrument identifier to commit")
                return
            }
            context.engine.cancelPreparedImport(first)

            let secondURL = try Self.variantFixtureURL(label: "strong-identifier-conflict")
            defer { try? FileManager.default.removeItem(at: secondURL) }
            let second = try await context.engine.prepareImport(from: secondURL)
            let secondPlan = try strongIdentifierPlan(
                prepared: second,
                mapper: mapper,
                provider: context.provider,
                accountID: "amex-strong-account-two",
                identifier: "amex-test-verified-identifier"
            )
            #expect(context.provider.confirmedImportRepo.commitConfirmedImport(secondPlan) == .identifierOwnershipConflict)
            context.engine.cancelPreparedImport(second)

            #expect(try context.provider.accountRepo.accounts(workspaceId: workspaceID).count == 1)
            #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 9)
            let card = try context.provider.cardRepo.snapshot(workspaceId: workspaceID)
            #expect(card.instruments.count == 3)
            #expect(card.instrumentIdentifiers.count == 1)
            #expect(card.statements.count == 1)
            #expect(try context.provider.importSessionRepo.importSession(id: second.importSession.id.uuidString) == nil)
        }
    }
    private func verifyPersistence(inMemory: Bool) async throws {
        let workspaceID = "amex-card-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let context = try makePersistentContext(workspaceID: workspaceID, inMemory: inMemory)
        defer { context.cleanup() }
        let prepared = try await context.engine.prepareImport(from: Self.fixtureURL)
        let result = try context.coordinator.persistValidatedImport(
            financialDocument: prepared.financialDocument,
            importSession: prepared.importSession,
            validation: prepared.validation,
            fingerprintSet: prepared.fingerprintSet,
            accountChoice: .createNewCardLiabilityAccountAndInstrument,
            providerGeneration: context.provider.generationToken
        )
        #expect(result.persisted)
        #expect(result.transactionCount == 9)
        #expect(try context.provider.accountRepo.accounts(workspaceId: workspaceID).count == 1)
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 9)
        let card = try context.provider.cardRepo.snapshot(workspaceId: workspaceID)
        #expect(card.instruments.count == 3)
        #expect(card.statements.count == 1)
        #expect(card.sections.count == 3)
        #expect(card.sectionObservations.count == 3)
        #expect(card.summaryComponents.count == 6)
        #expect(card.transactionEvidence.count == 9)
        #expect(card.transactionEvidence.filter { $0.instrumentId == nil }.count == 1)
        #expect(card.transactionEvidence.filter { $0.instrumentId != nil }.count == 8)
        #expect(card.semanticProjections.count == 1)
        #expect(card.semanticGroups.count == 1)
        #expect(card.semanticMembers.count == 1)

        let accounts = AccountStore()
        let transactions = TransactionStore()
        let cards = CardStore()
        let hydrator = RepositoryStoreHydrator(
            accountRepo: context.provider.accountRepo,
            importSessionRepo: context.provider.importSessionRepo,
            transactionRepo: context.provider.transactionRepo,
            categoryRepo: context.provider.categoryRepo,
            cardRepo: context.provider.cardRepo,
            accountStore: accounts,
            transactionStore: transactions,
            categoryStore: CategoryStore(),
            cardStore: cards,
            importSessionStore: ImportSessionStore(),
            importAttemptStore: ImportAttemptStore(),
            workspaceId: workspaceID,
            persistenceState: context.provider.persistenceState,
            providerGeneration: context.provider.generationToken,
            participatesInLifecycleGate: false
        )
        let snapshot = try hydrator.stageHydration()
        let expectedLiability = try Money(amount: -1150, currency: "QAR")
        #expect(snapshot.accounts.first?.currentBalanceMoney == expectedLiability)
        #expect(snapshot.transactions.allSatisfy { $0.debitMoney == nil && $0.creditMoney == nil && $0.cardLiabilityEffect != nil })
        #expect(snapshot.cardSnapshot.instruments.count == 3)
        #expect(snapshot.cardSnapshot.statements.count == 1)
        #expect(snapshot.cardSnapshot.statements.first?.sections.count == 3)
        #expect(snapshot.cardSnapshot.transactionEvidence.count == 9)

        let duplicate = try await context.engine.prepareImport(from: Self.fixtureURL)
        let duplicateResult = try context.coordinator.persistValidatedImport(
            financialDocument: duplicate.financialDocument, importSession: duplicate.importSession,
            validation: duplicate.validation, fingerprintSet: duplicate.fingerprintSet,
            accountChoice: .createNewCardLiabilityAccountAndInstrument,
            providerGeneration: context.provider.generationToken
        )
        #expect(!duplicateResult.persisted)
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 9)
    }

    private func verifyWeakIdentityDecisions(inMemory: Bool) async throws {
        let workspaceID = "amex-identity-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let context = try makePersistentContext(workspaceID: workspaceID, inMemory: inMemory)
        defer { context.cleanup() }
        var temporaryURLs: [URL] = []
        defer { temporaryURLs.forEach { try? FileManager.default.removeItem(at: $0) } }

        let first = try await context.engine.prepareImport(from: Self.fixtureURL)
        #expect(first.financialDocument.financialIdentifiers.isEmpty)
        let firstResult = try persist(first, choice: .createNewCardLiabilityAccountAndInstrument, context: context)
        context.engine.cancelPreparedImport(first)
        let accountID = try #require(firstResult.accountId)
        var card = try context.provider.cardRepo.snapshot(workspaceId: workspaceID)
        let originalInstrumentBySection = Dictionary(uniqueKeysWithValues: card.sections.map {
            ($0.documentScopedSectionId, $0.instrumentId)
        })
        let firstSectionID = try #require(first.financialDocument.cardStatementEvidence?.instrumentSections.first?.documentScopedSectionID)
        let originalInstrumentID = try #require(originalInstrumentBySection[firstSectionID])
        #expect(card.instrumentIdentifiers.isEmpty)
        #expect(card.sourceObservations.allSatisfy { $0.sourceValue.contains("X") })

        let exactReuseURL = try Self.variantFixtureURL(label: "exact-observation-reuse")
        temporaryURLs.append(exactReuseURL)
        let exactReuse = try await context.engine.prepareImport(from: exactReuseURL)
        let exactReuseResult = try persist(exactReuse, choice: nil, context: context)
        context.engine.cancelPreparedImport(exactReuse)
        #expect(exactReuseResult.accountId == accountID)
        card = try context.provider.cardRepo.snapshot(workspaceId: workspaceID)
        #expect(card.instruments.count == 3)
        #expect(card.sourceObservations.filter { $0.associationAuthority == "prior_user_confirmed_mapping" }.count == 1)
        #expect(card.sectionObservations.filter { $0.associationAuthority == "prior_user_confirmed_mapping" }.count == 3)

        let changedURL = try Self.variantFixtureURL(label: "changed-weak-instrument")
        temporaryURLs.append(changedURL)
        let changedPrepared = try await context.engine.prepareImport(from: changedURL)
        let changedDocument = try replacingCardObservations(
            in: changedPrepared.financialDocument,
            instrumentValue: "3777-XXXXXX-20002",
            statementStart: try StatementDate(canonical: "2026-06-30")
        )
        let transactionCountBeforeRejection = try context.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count
        let statementsBeforeRejection = card.statements.count
        do {
            _ = try context.coordinator.persistValidatedImport(
                financialDocument: changedDocument,
                importSession: changedPrepared.importSession,
                validation: ImportValidator.validate(financialDocument: changedDocument),
                fingerprintSet: changedPrepared.fingerprintSet,
                accountChoice: nil,
                providerGeneration: context.provider.generationToken
            )
            Issue.record("Expected changed weak instrument evidence to require an explicit choice")
        } catch let failure as ImportPersistenceCommitFailure {
            #expect(failure.originalError as? ImportPersistenceCoordinationError == .explicitChoiceRequired)
        }
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == transactionCountBeforeRejection)
        #expect(try context.provider.cardRepo.snapshot(workspaceId: workspaceID).statements.count == statementsBeforeRejection)
        #expect(try context.provider.importSessionRepo.importSession(id: changedPrepared.importSession.id.uuidString) == nil)

        let additionalResult = try context.coordinator.persistValidatedImport(
            financialDocument: changedDocument,
            importSession: changedPrepared.importSession,
            validation: ImportValidator.validate(financialDocument: changedDocument),
            fingerprintSet: changedPrepared.fingerprintSet,
            accountChoice: .useExistingCardLiabilityAccountSections(
                accountId: accountID,
                sectionChoices: try sectionChoices(
                    for: changedDocument,
                    originalInstrumentBySection: originalInstrumentBySection,
                    firstChoice: .createNewInstrument(
                        relationship: .additionalConcurrent,
                        relatedInstrumentId: originalInstrumentID
                    )
                )
            ),
            providerGeneration: context.provider.generationToken
        )
        context.engine.cancelPreparedImport(changedPrepared)
        #expect(additionalResult.persisted)

        for (index, kind) in [
            CardInstrumentRelationshipKind.replacement,
            .renewal,
            .upgrade
        ].enumerated() {
            let url = try Self.variantFixtureURL(label: "explicit-\(kind.rawValue)")
            temporaryURLs.append(url)
            let prepared = try await context.engine.prepareImport(from: url)
            let document = try replacingCardObservations(
                in: prepared.financialDocument,
                instrumentValue: "3777-XXXXXX-3\(String(format: "%04d", index + 1))",
                statementStart: try StatementDate(canonical: "2026-06-\(29 - index)")
            )
            let result = try context.coordinator.persistValidatedImport(
                financialDocument: document,
                importSession: prepared.importSession,
                validation: ImportValidator.validate(financialDocument: document),
                fingerprintSet: prepared.fingerprintSet,
                accountChoice: .useExistingCardLiabilityAccountSections(
                    accountId: accountID,
                    sectionChoices: try sectionChoices(
                        for: document,
                        originalInstrumentBySection: originalInstrumentBySection,
                        firstChoice: .createNewInstrument(
                            relationship: kind,
                            relatedInstrumentId: originalInstrumentID
                        )
                    )
                ),
                providerGeneration: context.provider.generationToken
            )
            context.engine.cancelPreparedImport(prepared)
            #expect(result.persisted)
        }

        let separateURL = try Self.variantFixtureURL(label: "explicit-separate-account")
        temporaryURLs.append(separateURL)
        let separatePrepared = try await context.engine.prepareImport(from: separateURL)
        let separateDocument = try replacingCardObservations(
            in: separatePrepared.financialDocument,
            accountValue: "8888-XXXX",
            instrumentValue: "3888-XXXXXX-80008"
        )
        let separateResult = try context.coordinator.persistValidatedImport(
            financialDocument: separateDocument,
            importSession: separatePrepared.importSession,
            validation: ImportValidator.validate(financialDocument: separateDocument),
            fingerprintSet: separatePrepared.fingerprintSet,
            accountChoice: .createNewCardLiabilityAccountAndInstrument,
            providerGeneration: context.provider.generationToken
        )
        context.engine.cancelPreparedImport(separatePrepared)
        #expect(separateResult.persisted)
        #expect(separateResult.accountId != accountID)

        card = try context.provider.cardRepo.snapshot(workspaceId: workspaceID)
        #expect(try context.provider.accountRepo.accounts(workspaceId: workspaceID).count == 2)
        #expect(card.instruments.filter { $0.liabilityAccountId == accountID }.count == 7)
        #expect(card.instruments.allSatisfy { $0.lifecycleStateCode == CardInstrumentLifecycleState.unknown.rawValue })
        #expect(Set(card.relationships.map(\.relationshipKind)) == Set([
            CardInstrumentRelationshipKind.additionalConcurrent.rawValue,
            CardInstrumentRelationshipKind.replacement.rawValue,
            CardInstrumentRelationshipKind.renewal.rawValue,
            CardInstrumentRelationshipKind.upgrade.rawValue
        ]))
        #expect(card.relationships.allSatisfy { $0.effectiveDateISO == nil && $0.authority == "user_confirmed" })
    }

    private func persist(
        _ prepared: PreparedImport,
        choice: ImportAccountChoice?,
        context: (engine: ImportEngine, coordinator: DefaultImportPersistenceCoordinator, provider: DatabaseProvider, cleanup: () -> Void)
    ) throws -> ImportPersistenceResult {
        try context.coordinator.persistValidatedImport(
            financialDocument: prepared.financialDocument,
            importSession: prepared.importSession,
            validation: prepared.validation,
            fingerprintSet: prepared.fingerprintSet,
            accountChoice: choice,
            providerGeneration: context.provider.generationToken
        )
    }

    private func sectionChoices(
        for document: FinancialDocument,
        originalInstrumentBySection: [String: String],
        firstChoice: ImportCardInstrumentChoice
    ) throws -> [String: ImportCardInstrumentChoice] {
        let sections = try #require(document.cardStatementEvidence?.instrumentSections)
        return try Dictionary(uniqueKeysWithValues: sections.map { section in
            if section.sourceOrdinal == 1 {
                return (section.documentScopedSectionID, firstChoice)
            }
            return (
                section.documentScopedSectionID,
                .reuseExistingInstrument(
                    instrumentId: try #require(originalInstrumentBySection[section.documentScopedSectionID])
                )
            )
        })
    }

    private func replacingCardObservations(
        in document: FinancialDocument,
        accountValue: String? = nil,
        instrumentValue: String? = nil,
        statementStart: StatementDate? = nil
    ) throws -> FinancialDocument {
        let existing = try #require(document.cardStatementEvidence)
        let resolvedAccountValue: String
        if let accountValue {
            resolvedAccountValue = accountValue
        } else {
            resolvedAccountValue = try #require(existing.accountSourceIdentityObservations.first?.value)
        }
        let resolvedInstrumentValue: String
        if let instrumentValue {
            resolvedInstrumentValue = instrumentValue
        } else {
            resolvedInstrumentValue = try #require(existing.instrumentSections.first?.sourceIdentityObservations.first?.value)
        }
        let accountObservation = try CardSourceIdentityObservation(
            kind: .liabilityMembershipNumber,
            subject: .liabilityAccount,
            value: resolvedAccountValue
        )
        let instrumentObservation = try CardSourceIdentityObservation(
            kind: .instrumentCardAccountNumber,
            subject: .instrument,
            value: resolvedInstrumentValue
        )
        let declaredPeriod = try DeclaredStatementPeriod(
            start: statementStart ?? existing.declaredStatementPeriod.start,
            end: existing.declaredStatementPeriod.end
        )
        let evidence = try CardStatementEvidence(
            statementDate: existing.statementDate,
            declaredStatementPeriod: declaredPeriod,
            nativeCurrency: existing.nativeCurrency,
            accountSourceIdentityObservations: [accountObservation],
            instrumentSections: existing.instrumentSections.map { section in
                CardInstrumentSectionEvidence(
                    documentScopedSectionID: section.documentScopedSectionID,
                    sourceOrdinal: section.sourceOrdinal,
                    holderLabel: section.holderLabel,
                    sourceIdentityObservations: section.sourceOrdinal == 1
                        ? [instrumentObservation]
                        : section.sourceIdentityObservations,
                    signedNetTotal: section.signedNetTotal,
                    reconciliationRuleIdentifier: section.reconciliationRuleIdentifier
                )
            },
            transactionAnnotations: existing.transactionAnnotations,
            summaryComponents: existing.summaryComponents,
            reconciliationRuleIdentifier: existing.reconciliationRuleIdentifier
        )
        return FinancialDocument(
            id: document.id,
            sourceDocument: document.sourceDocument,
            metadata: document.metadata,
            parserName: document.parserName,
            bookedCurrency: document.bookedCurrency,
            declaredStatementPeriod: declaredPeriod,
            transactions: document.transactions,
            financialIdentifiers: document.financialIdentifiers,
            cbqSourceIdentityObservations: document.cbqSourceIdentityObservations,
            sourceStatementEvidence: document.sourceStatementEvidence,
            cardStatementEvidence: evidence,
            selectionReasons: document.selectionReasons,
            createdAt: document.createdAt
        )
    }

    private func replacingFirstReference(in document: FinancialDocument) throws -> FinancialDocument {
        guard let first = document.transactions.first else { throw CocoaError(.fileReadCorruptFile) }
        let reference = (first.reference ?? "FICTIONAL-REFERENCE") + "-CHANGED"
        let referenceDigest = SHA256.hash(data: Data(reference.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let provenance = first.sourceProvenance.map { source in
            TransactionSourceProvenance(
                normalizedDocumentID: source.normalizedDocumentID,
                normalizedRowID: source.normalizedRowID,
                sourceOrdinal: source.sourceOrdinal,
                normalizedRecordDigest: String.normalizedRecordDigest(values: [reference]),
                parserProfileID: source.parserProfileID,
                parserProfileVersion: source.parserProfileVersion,
                sourceTransactionDate: source.sourceTransactionDate,
                structuredReferenceDigest: referenceDigest
            )
        }
        let replacement = Transaction(
            statementDate: first.statementDate,
            valueDate: first.valueDate,
            description: first.description,
            reference: reference,
            debitMoney: first.debitMoney,
            creditMoney: first.creditMoney,
            money: first.money,
            runningBalanceMoney: first.runningBalanceMoney,
            cardLiabilityEffect: first.cardLiabilityEffect,
            account: first.account,
            sourceBank: first.sourceBank,
            sourceFile: first.sourceFile,
            id: first.id,
            repositoryTransactionId: first.repositoryTransactionId,
            financialDateRole: first.financialDateRole,
            statementTimezoneEvidence: first.statementTimezoneEvidence,
            sourceProvenance: provenance,
            repositoryAccountId: first.repositoryAccountId,
            repositoryImportSessionId: first.repositoryImportSessionId,
            repositoryDocumentId: first.repositoryDocumentId,
            repositorySourceDocumentName: first.repositorySourceDocumentName,
            repositoryPreferredSourceDocumentName: first.repositoryPreferredSourceDocumentName,
            repositoryPreferredSourceFormatCode: first.repositoryPreferredSourceFormatCode,
            repositoryPreferredSourceTransactionDate: first.repositoryPreferredSourceTransactionDate,
            repositoryPreferredStructuredReferenceDigest: referenceDigest,
            verifiedAxisUPIEventEvidence: first.verifiedAxisUPIEventEvidence
        )
        var transactions = document.transactions
        transactions[0] = replacement
        return FinancialDocument(
            id: document.id,
            sourceDocument: document.sourceDocument,
            metadata: document.metadata,
            parserName: document.parserName,
            bookedCurrency: document.bookedCurrency,
            declaredStatementPeriod: document.declaredStatementPeriod,
            transactions: transactions,
            financialIdentifiers: document.financialIdentifiers,
            cbqSourceIdentityObservations: document.cbqSourceIdentityObservations,
            sourceStatementEvidence: document.sourceStatementEvidence,
            cardStatementEvidence: document.cardStatementEvidence,
            selectionReasons: document.selectionReasons,
            createdAt: document.createdAt
        )
    }

    private func strongIdentifierPlan(
        prepared: PreparedImport,
        mapper: ImportPersistenceMapper,
        provider: DatabaseProvider,
        accountID: String,
        identifier: String
    ) throws -> ConfirmedImportPlanDTO {
        let sectionIDs = try #require(prepared.financialDocument.cardStatementEvidence).instrumentSections.map(\.documentScopedSectionID)
        let base = try mapper.confirmedImportPlan(
            financialDocument: prepared.financialDocument,
            importSession: prepared.importSession,
            validation: prepared.validation,
            fingerprintSet: prepared.fingerprintSet,
            providerGeneration: provider.generationToken,
            advisoryIdentity: .noMatch,
            accountChoice: .createProposedAccount,
            selectedAccountId: accountID,
            cardAssociationAuthority: "parser_strong_evidence",
            cardSectionChoices: Dictionary(uniqueKeysWithValues: sectionIDs.map { ($0, .createProposedInstrument) }),
            cardSectionAuthorities: Dictionary(uniqueKeysWithValues: sectionIDs.map { ($0, "parser_strong_evidence") })
        )
        let card = try #require(base.cardImportPlan)
        let firstDecision = try #require(card.sectionDecisions.first)
        let strongIdentifier = CardInstrumentIdentifierDTO(
            id: "card-identifier-\(prepared.importSession.id.uuidString.lowercased())",
            instrumentId: firstDecision.proposedInstrument.id,
            workspaceId: base.workspace.id,
            scheme: "amex_verified_instrument",
            identifier: identifier,
            parserProvenanceCode: "amex.synthetic.strong-evidence-test",
            createdAtISO: firstDecision.proposedInstrument.createdAtISO
        )
        let sectionDecisions = card.sectionDecisions.map { decision in
            ConfirmedCardSectionDecisionDTO(
                instrumentChoice: decision.instrumentChoice,
                proposedInstrument: decision.proposedInstrument,
                instrumentIdentifiers: decision.section.sourceOrdinal == 1 ? [strongIdentifier] : [],
                section: decision.section,
                sourceObservations: decision.sourceObservations,
                relationships: decision.relationships
            )
        }
        let replacedCard = ConfirmedCardImportPlanDTO(
            liabilityAccountId: card.liabilityAccountId,
            instrumentChoice: card.instrumentChoice,
            proposedInstrument: card.proposedInstrument,
            sourceObservations: card.sourceObservations,
            relationships: card.relationships,
            statement: card.statement,
            summaryComponents: card.summaryComponents,
            transactionEvidence: card.transactionEvidence,
            sectionDecisions: sectionDecisions,
            semanticProjection: card.semanticProjection
        )
        return ConfirmedImportPlanDTO(
            providerGeneration: base.providerGeneration,
            workspace: base.workspace,
            proposedAccount: base.proposedAccount,
            accountChoice: base.accountChoice,
            advisoryIdentity: base.advisoryIdentity,
            identifiers: base.identifiers,
            historyTemplate: base.historyTemplate,
            transactionTemplates: base.transactionTemplates,
            declaredStatementStartISO: base.declaredStatementStartISO,
            declaredStatementEndISO: base.declaredStatementEndISO,
            openingBalanceMinor: base.openingBalanceMinor,
            openingBalanceDecimal: base.openingBalanceDecimal,
            closingBalanceMinor: base.closingBalanceMinor,
            closingBalanceDecimal: base.closingBalanceDecimal,
            statementFinancialProjection: base.statementFinancialProjection,
            cbqSourceIdentityPatterns: base.cbqSourceIdentityPatterns,
            cbqSourceRows: base.cbqSourceRows,
            cbqStatementSourceEvidence: base.cbqStatementSourceEvidence,
            cardImportPlan: replacedCard
        )
    }

    private func makeContext(
        workspaceID: String,
        inMemory: Bool
    ) -> (engine: ImportEngine, coordinator: DefaultImportPersistenceCoordinator, provider: DatabaseProvider) {
        makeContext(
            workspaceID: workspaceID,
            inMemory: inMemory,
            importCoordinator: DefaultImportCoordinator(
                readerRegistry: DefaultReaderRegistry(),
                passwordProvider: DefaultPasswordProvider()
            )
        )
    }

    private func makeContext(
        workspaceID: String,
        inMemory: Bool,
        importCoordinator: any ImportFramework.ImportCoordinator
    ) -> (engine: ImportEngine, coordinator: DefaultImportPersistenceCoordinator, provider: DatabaseProvider) {
        let provider = DatabaseProvider(inMemory: inMemory)
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "Amex Synthetic")
        )
        let engine = ImportEngine(
            importCoordinator: importCoordinator,
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { .init(didHydrate: true, accountCount: 0, transactionCount: 0) }
        )
        return (engine, coordinator, provider)
    }

    private func makePersistentContext(
        workspaceID: String,
        inMemory: Bool
    ) throws -> (engine: ImportEngine, coordinator: DefaultImportPersistenceCoordinator, provider: DatabaseProvider, cleanup: () -> Void) {
        try makePersistentContext(
            workspaceID: workspaceID,
            inMemory: inMemory,
            importCoordinator: DefaultImportCoordinator(
                readerRegistry: DefaultReaderRegistry(),
                passwordProvider: DefaultPasswordProvider()
            )
        )
    }

    private func makePersistentContext(
        workspaceID: String,
        inMemory: Bool,
        importCoordinator: any ImportFramework.ImportCoordinator
    ) throws -> (engine: ImportEngine, coordinator: DefaultImportPersistenceCoordinator, provider: DatabaseProvider, cleanup: () -> Void) {
        if inMemory {
            let context = makeContext(workspaceID: workspaceID, inMemory: true, importCoordinator: importCoordinator)
            return (context.engine, context.coordinator, context.provider, {})
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Amex-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("amex.sqlite").path)
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "Amex Synthetic")
        )
        let engine = ImportEngine(
            importCoordinator: importCoordinator,
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { .init(didHydrate: true, accountCount: 0, transactionCount: 0) }
        )
        return (engine, coordinator, provider, {
            sqlite.database.close()
            try? FileManager.default.removeItem(at: folder)
        })
    }

    private static let fixtureURL = FixtureLocator.americanExpressSyntheticPDF("amex_credit_card_pdf_v1_synthetic.pdf")
    private static let encryptedFixtureURL = FixtureLocator.americanExpressSyntheticPDF("amex_credit_card_pdf_v1_synthetic_encrypted.pdf")
    private static let syntheticFixturePassword = "ledgerforge-fixture-only"

    private static func variantFixtureURL(label: String) throws -> URL {
        let document = try #require(PDFDocument(url: fixtureURL))
        var attributes = document.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.titleAttribute] = "Fictional Amex variant \(label) \(UUID().uuidString)"
        document.documentAttributes = attributes
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("amex-\(label)-\(UUID().uuidString).pdf")
        guard document.write(to: url) else { throw CocoaError(.fileWriteUnknown) }
        return url
    }
}
