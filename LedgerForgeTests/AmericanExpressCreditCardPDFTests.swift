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
        #expect(prepared.transactionCount == 5)
        #expect(prepared.financialDocument.bookedCurrency?.code == "QAR")
        #expect(prepared.financialDocument.financialIdentifiers.isEmpty)
        let evidence = try #require(prepared.financialDocument.cardStatementEvidence)
        #expect(evidence.declaredStatementPeriod.start.canonical == "2026-07-01")
        #expect(evidence.declaredStatementPeriod.end.canonical == "2026-07-31")
        #expect(evidence.transactionAnnotations.map(\.rowScope.persistenceCode) == [
            "account_level", "instrument_level", "instrument_level", "instrument_level", "instrument_level"
        ])
        #expect(evidence.transactionAnnotations.map(\.liabilityEffect) == [
            .decreasesAmountOwed, .increasesAmountOwed, .increasesAmountOwed,
            .decreasesAmountOwed, .increasesAmountOwed
        ])
        #expect(evidence.transactionAnnotations.first?.sourceTransactionDate.canonical == "2026-06-30")
        #expect(prepared.financialDocument.transactions.first?.statementDate?.canonical == "2026-07-01")
        #expect(prepared.financialDocument.transactions.allSatisfy {
            $0.debitMoney == nil && $0.creditMoney == nil && $0.runningBalanceMoney == nil
        })
        let expectedOriginal = try Money(amount: 40, currency: "USD")
        #expect(evidence.transactionAnnotations[2].originalMerchantMoney == expectedOriginal)
        #expect(evidence.transactionAnnotations.filter { $0.originalMerchantMoney != nil }.count == 1)
        #expect(prepared.financialDocument.transactions[4].description == "FICTIONAL RAIL JOURNEY\nEXAMPLE CITY TO SAMPLE BAY\nPASSENGER AVERY EXAMPLE")
        #expect(prepared.financialDocument.transactions.map(\.reference) == [
            "PAY-FICTION-001", "BUY-FICTION-002", "FX-FICTION-003", "REFUND-FICTION-004", "TRAVEL-FICTION-005"
        ])
        #expect(try #require(PDFDocument(url: Self.fixtureURL)).pageCount == 4)
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
            #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 5)
            let card = try context.provider.cardRepo.snapshot(workspaceId: workspaceID)
            #expect(card.instruments.count == 1)
            #expect(card.instrumentIdentifiers.count == 1)
            #expect(card.statements.count == 1)
            #expect(try context.provider.importSessionRepo.importSession(id: second.importSession.id.uuidString) == nil)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func privateOriginalsMatchApprovedAggregateOracleWhenExplicitlyProvided() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let earlierPath = environment["LEDGERFORGE_PRIVATE_AMEX_EARLIER_PDF"],
              let laterPath = environment["LEDGERFORGE_PRIVATE_AMEX_LATER_PDF"] else { return }
        func decimal(_ value: String) -> Decimal { Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))! }
        let expectations: [(String, Int, String, String, Decimal, Decimal, Decimal, Decimal, String, Decimal)] = [
            (earlierPath, 61, "2026-04-24", "2026-05-23", decimal("12042.19"), decimal("17164.45"), decimal("10572.54"), decimal("5450.28"), "2026-06-17", decimal("4908.09")),
            (laterPath, 34, "2026-05-24", "2026-06-23", decimal("5450.28"), decimal("8037.53"), decimal("10349.13"), decimal("7761.88"), "2026-07-18", decimal("7762.60"))
        ]
        var documents = [FinancialDocument]()
        let expectedHashes = [
            "04bf29025dfcc85225e48c60a82126a6aeed77999f624d22957f74958f5e28b0",
            "c1d02f796fd549ed4914a5b09c5eeb1372810256a35f922302ddbbea41a368a6"
        ]
        for (expectedIndex, expected) in expectations.enumerated() {
            let url = URL(fileURLWithPath: expected.0)
            let sourceBytes = try Data(contentsOf: url)
            let sourceHash = SHA256.hash(data: sourceBytes).map { String(format: "%02x", $0) }.joined()
            #expect(sourceHash == expectedHashes[expectedIndex])
            let independentRows = try IndependentAmexPDFOracle.rows(in: url)
            let context = makeContext(workspaceID: "amex-private-oracle-\(UUID().uuidString)", inMemory: true)
            let prepared = try await context.engine.prepareImport(from: url)
            #expect(prepared.validation.passed)
            #expect(prepared.transactionCount == expected.1)
            let evidence = try #require(prepared.financialDocument.cardStatementEvidence)
            #expect(evidence.declaredStatementPeriod.start.canonical == expected.2)
            #expect(evidence.declaredStatementPeriod.end.canonical == expected.3)
            #expect(evidence.summary(code: "previous_balance")?.money?.amount == expected.4)
            #expect(evidence.summary(code: "new_credits")?.money?.amount == expected.5)
            #expect(evidence.summary(code: "new_debits")?.money?.amount == expected.6)
            #expect(evidence.summary(code: "new_balance")?.money?.amount == expected.7)
            #expect(evidence.summary(code: "due_date")?.date?.canonical == expected.8)
            #expect(evidence.summary(code: "instrument_net_total")?.money?.amount == expected.9)
            #expect(evidence.transactionAnnotations.filter { $0.rowScope == .accountLevel }.count == 1)
            #expect(evidence.transactionAnnotations.filter { $0.rowScope != .accountLevel }.count == expected.1 - 1)
            let productionRows = try zip(prepared.financialDocument.transactions, evidence.transactionAnnotations).map {
                try IndependentAmexPDFOracle.Row(
                    transactionDate: $0.1.sourceTransactionDate,
                    postingDate: #require($0.0.statementDate),
                    effect: $0.1.liabilityEffect,
                    postedMoney: $0.0.money,
                    originalMoney: $0.1.originalMerchantMoney,
                    reference: #require($0.0.reference),
                    scopeCode: $0.1.rowScope.persistenceCode,
                    sourceOrdinal: #require($0.0.sourceProvenance.first?.sourceOrdinal)
                )
            }
            let rowMismatchCount = zip(independentRows, productionRows).filter { pair in pair.0 != pair.1 }.count
                + abs(independentRows.count - productionRows.count)
            #expect(rowMismatchCount == 0)
            #expect(prepared.financialDocument.financialIdentifiers.isEmpty)
            #expect(evidence.accountSourceIdentityObservations.count == 1)
            #expect(evidence.instrumentSections.flatMap(\.sourceIdentityObservations).count == 1)
            documents.append(prepared.financialDocument)
            context.engine.cancelPreparedImport(prepared)
        }
        #expect(documents[0].cardStatementEvidence?.summary(code: "new_balance")?.money ==
                documents[1].cardStatementEvidence?.summary(code: "previous_balance")?.money)
    }

    @Test(.globalRuntimeStateIsolation)
    func privateOriginalsPersistChronologicallyAndInReverseWithProviderParityWhenExplicitlyProvided() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let earlierPath = environment["LEDGERFORGE_PRIVATE_AMEX_EARLIER_PDF"],
              let laterPath = environment["LEDGERFORGE_PRIVATE_AMEX_LATER_PDF"] else { return }
        let earlier = URL(fileURLWithPath: earlierPath)
        let later = URL(fileURLWithPath: laterPath)
        for inMemory in [true, false] {
            try await verifyPrivateCampaign(
                urls: [earlier, later],
                expectedFirstBalance: "-5450.28",
                inMemory: inMemory,
                campaign: "chronological"
            )
            try await verifyPrivateCampaign(
                urls: [later, earlier],
                expectedFirstBalance: "-7761.88",
                inMemory: inMemory,
                campaign: "reverse"
            )
        }
    }

    private func verifyPrivateCampaign(
        urls: [URL],
        expectedFirstBalance: String,
        inMemory: Bool,
        campaign: String
    ) async throws {
        let workspaceID = "amex-private-\(campaign)-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Amex-Private-\(UUID().uuidString)")
        var sqlite: SQLiteRepositoryProvider?
        let provider: DatabaseProvider
        if inMemory {
            provider = DatabaseProvider(inMemory: true)
        } else {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let opened = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("campaign.sqlite").path)
            sqlite = opened
            provider = DatabaseProvider.verifiedSQLite(opened, protectsGeneration: false)
        }
        defer {
            sqlite?.database.close()
            if !inMemory { try? FileManager.default.removeItem(at: folder) }
        }
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "Amex Private Campaign")
        )
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { .init(didHydrate: true, accountCount: 0, transactionCount: 0) }
        )

        var accountID: String?
        for (index, url) in urls.enumerated() {
            let prepared = try await engine.prepareImport(from: url)
            let result = try coordinator.persistValidatedImport(
                financialDocument: prepared.financialDocument,
                importSession: prepared.importSession,
                validation: prepared.validation,
                fingerprintSet: prepared.fingerprintSet,
                accountChoice: index == 0 ? .createNewCardLiabilityAccountAndInstrument : nil,
                providerGeneration: provider.generationToken
            )
            engine.cancelPreparedImport(prepared)
            #expect(result.persisted)
            if index == 0 {
                accountID = result.accountId
                try verifyCardState(
                    provider: provider,
                    workspaceID: workspaceID,
                    expectedTransactions: prepared.transactionCount,
                    expectedStatements: 1,
                    expectedBalance: expectedFirstBalance
                )
            } else {
                #expect(result.accountId == accountID)
            }
        }

        let duplicate = try await engine.prepareImport(from: urls[0])
        let duplicateResult = try coordinator.persistValidatedImport(
            financialDocument: duplicate.financialDocument,
            importSession: duplicate.importSession,
            validation: duplicate.validation,
            fingerprintSet: duplicate.fingerprintSet,
            accountChoice: nil,
            providerGeneration: provider.generationToken
        )
        engine.cancelPreparedImport(duplicate)
        #expect(!duplicateResult.persisted)
        try verifyCardState(
            provider: provider,
            workspaceID: workspaceID,
            expectedTransactions: 95,
            expectedStatements: 2,
            expectedBalance: "-7761.88"
        )

        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopenedSQLite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("campaign.sqlite").path)
            let reopened = DatabaseProvider.verifiedSQLite(reopenedSQLite, protectsGeneration: false)
            try verifyCardState(
                provider: reopened,
                workspaceID: workspaceID,
                expectedTransactions: 95,
                expectedStatements: 2,
                expectedBalance: "-7761.88"
            )
            try reopenedSQLite.database.checkpointAndClose()
        }
    }

    private func verifyCardState(
        provider: DatabaseProvider,
        workspaceID: String,
        expectedTransactions: Int,
        expectedStatements: Int,
        expectedBalance: String
    ) throws {
        #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).count == 1)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == expectedTransactions)
        let card = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        #expect(card.instruments.count == 1)
        #expect(card.instruments.allSatisfy { $0.lifecycleStateCode == "unknown" })
        #expect(card.instrumentIdentifiers.isEmpty)
        #expect(card.relationships.isEmpty)
        #expect(card.statements.count == expectedStatements)
        #expect(card.sourceObservations.count == expectedStatements * 2)
        #expect(card.summaryComponents.count == expectedStatements * 6)
        #expect(card.transactionEvidence.count == expectedTransactions)
        for statement in card.statements {
            #expect(try provider.importSessionRepo.importSession(id: statement.importSessionId) != nil)
            #expect(try provider.importSessionRepo.importedDocument(id: statement.documentId) != nil)
        }

        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo,
            accountStore: AccountStore(),
            transactionStore: TransactionStore(),
            categoryStore: CategoryStore(),
            cardStore: CardStore(),
            importSessionStore: ImportSessionStore(),
            importAttemptStore: ImportAttemptStore(),
            workspaceId: workspaceID,
            persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken,
            participatesInLifecycleGate: false
        )
        let hydrated = try hydrator.stageHydration()
        #expect(hydrated.accounts.count == 1)
        #expect(hydrated.accounts.first?.type == .creditCard)
        let amount = try #require(Decimal(string: expectedBalance, locale: Locale(identifier: "en_US_POSIX")))
        #expect(hydrated.accounts.first?.currentBalanceMoney == (try Money(amount: amount, currency: "QAR")))
        #expect(hydrated.transactions.count == expectedTransactions)
        #expect(hydrated.cardSnapshot.statements.count == expectedStatements)
        #expect(hydrated.cardSnapshot.transactionEvidence.count == expectedTransactions)
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
        #expect(result.transactionCount == 5)
        #expect(try context.provider.accountRepo.accounts(workspaceId: workspaceID).count == 1)
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 5)
        let card = try context.provider.cardRepo.snapshot(workspaceId: workspaceID)
        #expect(card.instruments.count == 1)
        #expect(card.statements.count == 1)
        #expect(card.summaryComponents.count == 6)
        #expect(card.transactionEvidence.count == 5)
        #expect(card.transactionEvidence.filter { $0.instrumentId == nil }.count == 1)
        #expect(card.transactionEvidence.filter { $0.instrumentId != nil }.count == 4)

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
        let expectedLiability = try Money(amount: -1000, currency: "QAR")
        #expect(snapshot.accounts.first?.currentBalanceMoney == expectedLiability)
        #expect(snapshot.transactions.allSatisfy { $0.debitMoney == nil && $0.creditMoney == nil && $0.cardLiabilityEffect != nil })
        #expect(snapshot.cardSnapshot.instruments.count == 1)
        #expect(snapshot.cardSnapshot.statements.count == 1)
        #expect(snapshot.cardSnapshot.transactionEvidence.count == 5)

        let duplicate = try await context.engine.prepareImport(from: Self.fixtureURL)
        let duplicateResult = try context.coordinator.persistValidatedImport(
            financialDocument: duplicate.financialDocument, importSession: duplicate.importSession,
            validation: duplicate.validation, fingerprintSet: duplicate.fingerprintSet,
            accountChoice: .createNewCardLiabilityAccountAndInstrument,
            providerGeneration: context.provider.generationToken
        )
        #expect(!duplicateResult.persisted)
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 5)
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
        let originalInstrumentID = try #require(card.instruments.first?.id)
        #expect(card.instrumentIdentifiers.isEmpty)
        #expect(card.sourceObservations.allSatisfy { $0.sourceValue.contains("X") })

        let exactReuseURL = try Self.variantFixtureURL(label: "exact-observation-reuse")
        temporaryURLs.append(exactReuseURL)
        let exactReuse = try await context.engine.prepareImport(from: exactReuseURL)
        let exactReuseResult = try persist(exactReuse, choice: nil, context: context)
        context.engine.cancelPreparedImport(exactReuse)
        #expect(exactReuseResult.accountId == accountID)
        card = try context.provider.cardRepo.snapshot(workspaceId: workspaceID)
        #expect(card.instruments.count == 1)
        #expect(card.sourceObservations.filter { $0.associationAuthority == "prior_user_confirmed_mapping" }.count == 2)

        let changedURL = try Self.variantFixtureURL(label: "changed-weak-instrument")
        temporaryURLs.append(changedURL)
        let changedPrepared = try await context.engine.prepareImport(from: changedURL)
        let changedDocument = try replacingCardObservations(
            in: changedPrepared.financialDocument,
            instrumentValue: "3777-XXXXXX-20002"
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
            accountChoice: .useExistingCardLiabilityAccount(
                accountId: accountID,
                instrumentChoice: .createNewInstrument(
                    relationship: .additionalConcurrent,
                    relatedInstrumentId: originalInstrumentID
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
                instrumentValue: "3777-XXXXXX-3\(String(format: "%04d", index + 1))"
            )
            let result = try context.coordinator.persistValidatedImport(
                financialDocument: document,
                importSession: prepared.importSession,
                validation: ImportValidator.validate(financialDocument: document),
                fingerprintSet: prepared.fingerprintSet,
                accountChoice: .useExistingCardLiabilityAccount(
                    accountId: accountID,
                    instrumentChoice: .createNewInstrument(
                        relationship: kind,
                        relatedInstrumentId: originalInstrumentID
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
        #expect(card.instruments.filter { $0.liabilityAccountId == accountID }.count == 5)
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

    private func replacingCardObservations(
        in document: FinancialDocument,
        accountValue: String? = nil,
        instrumentValue: String? = nil
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
        let evidence = try CardStatementEvidence(
            statementDate: existing.statementDate,
            declaredStatementPeriod: existing.declaredStatementPeriod,
            nativeCurrency: existing.nativeCurrency,
            accountSourceIdentityObservations: [accountObservation],
            instrumentSections: [CardInstrumentSectionEvidence(
                documentScopedSectionID: try #require(existing.instrumentSections.first?.documentScopedSectionID),
                sourceIdentityObservations: [instrumentObservation]
            )],
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
            declaredStatementPeriod: document.declaredStatementPeriod,
            transactions: document.transactions,
            financialIdentifiers: document.financialIdentifiers,
            cbqSourceIdentityObservations: document.cbqSourceIdentityObservations,
            sourceStatementEvidence: document.sourceStatementEvidence,
            cardStatementEvidence: evidence,
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
        let base = try mapper.confirmedImportPlan(
            financialDocument: prepared.financialDocument,
            importSession: prepared.importSession,
            validation: prepared.validation,
            fingerprintSet: prepared.fingerprintSet,
            providerGeneration: provider.generationToken,
            advisoryIdentity: .noMatch,
            accountChoice: .createProposedAccount,
            selectedAccountId: accountID,
            cardInstrumentChoice: .createProposedInstrument,
            cardAssociationAuthority: "parser_strong_evidence"
        )
        let card = try #require(base.cardImportPlan)
        let strongIdentifier = CardInstrumentIdentifierDTO(
            id: "card-identifier-\(prepared.importSession.id.uuidString.lowercased())",
            instrumentId: card.proposedInstrument.id,
            workspaceId: base.workspace.id,
            scheme: "amex_verified_instrument",
            identifier: identifier,
            parserProvenanceCode: "amex.synthetic.strong-evidence-test",
            createdAtISO: card.proposedInstrument.createdAtISO
        )
        let replacedCard = ConfirmedCardImportPlanDTO(
            liabilityAccountId: card.liabilityAccountId,
            instrumentChoice: card.instrumentChoice,
            proposedInstrument: card.proposedInstrument,
            instrumentIdentifiers: [strongIdentifier],
            sourceObservations: card.sourceObservations,
            relationships: card.relationships,
            statement: card.statement,
            summaryComponents: card.summaryComponents,
            transactionEvidence: card.transactionEvidence
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

    private func makeContext(workspaceID: String, inMemory: Bool) -> (engine: ImportEngine, coordinator: DefaultImportPersistenceCoordinator, provider: DatabaseProvider) {
        let provider = DatabaseProvider(inMemory: inMemory)
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "Amex Synthetic")
        )
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { .init(didHydrate: true, accountCount: 0, transactionCount: 0) }
        )
        return (engine, coordinator, provider)
    }

    private func makePersistentContext(workspaceID: String, inMemory: Bool) throws -> (engine: ImportEngine, coordinator: DefaultImportPersistenceCoordinator, provider: DatabaseProvider, cleanup: () -> Void) {
        if inMemory {
            let context = makeContext(workspaceID: workspaceID, inMemory: true)
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

private enum IndependentAmexPDFOracle {
    struct Row: Equatable {
        let transactionDate: StatementDate
        let postingDate: StatementDate
        let effect: CardLiabilityEffect
        let postedMoney: Money
        let originalMoney: Money?
        let reference: String
        let scopeCode: String
        let sourceOrdinal: Int
    }

    static func rows(in url: URL) throws -> [Row] {
        let pdf = try #require(PDFDocument(url: url))
        let startPattern = #"^(\d{2}-[A-Za-z]{3}-\d{4}) (\d{2}-[A-Za-z]{3}-\d{4}) (.+)$"#
        let postedPattern = #"^([0-9]+(?:,[0-9]{3})*\.\d{2})(?: (CR))?$"#
        let foreignPattern = #"^([0-9]+(?:,[0-9]{3})*(?:\.\d{2})?) ([A-Z]{3})(?: (CR))? ([0-9]+(?:,[0-9]{3})*\.\d{2})(?: (CR))?$"#
        var result: [Row] = []
        var scopeCode = "account_level"

        for pageIndex in 0..<pdf.pageCount {
            let lines = try #require(pdf.page(at: pageIndex)?.string).components(separatedBy: .newlines)
            var index = 0
            while index < lines.count {
                let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if line.hasPrefix("New Transactions For ") {
                    scopeCode = "instrument_level"
                    index += 1
                    continue
                }
                guard let start = captures(startPattern, in: line) else {
                    index += 1
                    continue
                }
                var block: [String] = [start[2]]
                index += 1
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    if captures(startPattern, in: candidate) != nil ||
                        candidate.hasPrefix("New Transactions For ") ||
                        candidate.hasPrefix("Total of New Transactions For ") ||
                        candidate.hasPrefix("This Card is issued by AMEX") {
                        break
                    }
                    if !candidate.isEmpty { block.append(candidate) }
                    index += 1
                }
                let reference = try #require(block.first(where: { $0.hasPrefix("Reference: ") }))
                var effect: CardLiabilityEffect?
                var posted: Money?
                var original: Money?
                for candidate in block {
                    if let values = captures(foreignPattern, in: candidate) {
                        let isCredit = !values[4].isEmpty
                        effect = isCredit ? .decreasesAmountOwed : .increasesAmountOwed
                        let originalCurrency = try CurrencyCode(values[1])
                        let originalAmount = try decimal(values[0])
                        let postedAmount = try decimal(values[3])
                        original = try Money(amount: isCredit ? -originalAmount : originalAmount, currency: originalCurrency)
                        posted = try Money(amount: isCredit ? -postedAmount : postedAmount, currency: "QAR")
                    } else if let values = captures(postedPattern, in: candidate) {
                        let isCredit = !values[1].isEmpty
                        effect = isCredit ? .decreasesAmountOwed : .increasesAmountOwed
                        let postedAmount = try decimal(values[0])
                        posted = try Money(amount: isCredit ? -postedAmount : postedAmount, currency: "QAR")
                    }
                }
                result.append(Row(
                    transactionDate: try statementDate(start[0]),
                    postingDate: try statementDate(start[1]),
                    effect: try #require(effect),
                    postedMoney: try #require(posted),
                    originalMoney: original,
                    reference: String(reference.dropFirst("Reference: ".count)),
                    scopeCode: scopeCode,
                    sourceOrdinal: result.count + 1
                ))
            }
        }
        return result
    }

    private static func captures(_ pattern: String, in value: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              match.range == NSRange(value.startIndex..., in: value) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: value) else { return "" }
            return String(value[range])
        }
    }

    private static func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX")))
    }

    private static func statementDate(_ value: String) throws -> StatementDate {
        let parts = value.split(separator: "-")
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let month = try #require(months.firstIndex { $0.caseInsensitiveCompare(String(parts[1])) == .orderedSame }) + 1
        return try StatementDate(year: try #require(Int(parts[2])), month: month, day: try #require(Int(parts[0])))
    }
}
