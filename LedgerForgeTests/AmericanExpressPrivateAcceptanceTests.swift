import CryptoKit
import Foundation
import PDFKit
import Testing
@testable import LedgerForge

/// Opt-in acceptance for the private Amex source corpus.
///
/// The committed test contains only public aggregate acceptance anchors. It
/// discovers source containers from an explicit environment directory and
/// obtains the real credential from the production Keychain scope. Private
/// paths, hashes, identifiers, rows, statement amounts, and decrypted bytes are
/// never persisted or printed.
@MainActor
struct AmericanExpressPrivateAcceptanceTests {
    private static let directoryEnvironmentKey = "LEDGERFORGE_PRIVATE_AMEX_DIRECTORY"
    private static let expectedChronologicalRowCounts = [21, 32, 49, 63, 34, 61, 34, 60]
    private static let expectedCanonicalTransactionCount = 354

    @Test
    func independentOracleExercisesMultiSectionCreditAndVariableScaleFixture() throws {
        let source = try PrivateSource(
            url: FixtureLocator.americanExpressSyntheticPDF("amex_credit_card_pdf_v1_synthetic.pdf"),
            password: "unused-for-unlocked-fixture"
        )

        #expect(!source.isEncrypted)
        #expect(source.oracle.rows.count == 9)
        #expect(source.oracle.sections.count == 3)
        #expect(source.oracle.statementReconciles)
        #expect(source.oracle.sectionReconciliationMismatchCount == 0)
        #expect(source.oracle.rows.filter { $0.originalMoney != nil }.count == 3)
        #expect(source.oracle.rows.contains { $0.effect == .decreasesAmountOwed })
    }

    @Test(.globalRuntimeStateIsolation)
    func completePrivateCorpusMatchesIndependentOracleAndAllAcceptanceCampaigns() async throws {
        guard let directoryPath = ProcessInfo.processInfo.environment[Self.directoryEnvironmentKey] else {
            return
        }

        let credentialStore = KeychainStatementPasswordCredentialStore()
        guard let password = try await credentialStore.password(
            institutionCode: Institution.amex.statementPasswordCredentialScope
        ), !password.isEmpty else {
            throw PrivateAcceptanceError.missingRememberedCredential
        }

        let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame &&
                (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
        guard urls.count == 10 else { throw PrivateAcceptanceError.unexpectedCorpusShape }

        let sources = try urls.map { try PrivateSource(url: $0, password: password) }
        let encrypted = sources.filter(\.isEncrypted)
        let unlocked = sources.filter { !$0.isEncrypted }
        guard encrypted.count == 8, unlocked.count == 2 else {
            throw PrivateAcceptanceError.unexpectedCorpusShape
        }
        #expect(Set(sources.map(\.sourceByteDigest)).count == 10)

        let chronological = encrypted.sorted {
            $0.oracle.period.start < $1.oracle.period.start
        }
        #expect(chronological.map { $0.oracle.rows.count } == Self.expectedChronologicalRowCounts)
        #expect(chronological.reduce(0) { $0 + $1.oracle.rows.count } == Self.expectedCanonicalTransactionCount)
        #expect(Set(chronological.map { $0.oracle.periodKey }).count == 8)

        let statementEquationCount = chronological.filter { $0.oracle.statementReconciles }.count
        let adjacentContinuityCount = zip(chronological, chronological.dropFirst()).filter {
            $0.0.oracle.summary.newBalance == $0.1.oracle.summary.previousBalance
        }.count
        let outsidePeriodCount = chronological.reduce(0) { count, source in
            count + source.oracle.rows.filter {
                $0.postingDate < source.oracle.period.start || $0.postingDate > source.oracle.period.end
            }.count
        }
        let sectionReconciliationMismatchCount = chronological.reduce(0) {
            $0 + $1.oracle.sectionReconciliationMismatchCount
        }
        #expect(statementEquationCount == 8)
        #expect(adjacentContinuityCount == 7)
        #expect(outsidePeriodCount == 0)
        #expect(sectionReconciliationMismatchCount == 0)

        guard Set(chronological.map { $0.oracle.accountObservation }).count == 1 else {
            throw PrivateAcceptanceError.oracleMismatch
        }
        let distinctInstrumentObservations = Set(
            chronological.flatMap { $0.oracle.sections.map(\.instrumentObservation) }
        )
        #expect(distinctInstrumentObservations.count == 3)

        let periodGroups = Dictionary(grouping: sources, by: \.oracle.periodKey)
        let equivalentPairs = periodGroups.values.filter { $0.count == 2 }
        #expect(periodGroups.count == 8)
        #expect(equivalentPairs.count == 2)
        guard equivalentPairs.allSatisfy({ pair in
            pair.filter(\.isEncrypted).count == 1 &&
                pair.filter { !$0.isEncrypted }.count == 1 &&
                pair[0].oracle.isFinanciallyEquivalent(to: pair[1].oracle)
        }) else {
            throw PrivateAcceptanceError.oracleMismatch
        }

        try await verifyProductionAgainstIndependentOracle(
            sources: sources,
            credentialStore: credentialStore
        )

        let mixedIndices = [7, 2, 5, 0, 6, 1, 4, 3]
        let mixed = mixedIndices.map { chronological[$0] }
        for inMemory in [true, false] {
            try await runCampaign(
                sources: chronological,
                expectedUniqueStatements: 8,
                expectedCanonicalTransactions: Self.expectedCanonicalTransactionCount,
                expectedInstrumentCount: 3,
                inMemory: inMemory,
                credentialStore: credentialStore,
                campaign: "chronological"
            )
            try await runCampaign(
                sources: chronological.reversed(),
                expectedUniqueStatements: 8,
                expectedCanonicalTransactions: Self.expectedCanonicalTransactionCount,
                expectedInstrumentCount: 3,
                inMemory: inMemory,
                credentialStore: credentialStore,
                campaign: "reverse"
            )
            try await runCampaign(
                sources: mixed,
                expectedUniqueStatements: 8,
                expectedCanonicalTransactions: Self.expectedCanonicalTransactionCount,
                expectedInstrumentCount: 3,
                inMemory: inMemory,
                credentialStore: credentialStore,
                campaign: "mixed"
            )

            for (pairIndex, pair) in equivalentPairs.enumerated() {
                let encryptedSource = try requireSingle(pair.filter(\.isEncrypted))
                let unlockedSource = try requireSingle(pair.filter { !$0.isEncrypted })
                for (orderName, order) in [
                    ("unlocked-encrypted", [unlockedSource, encryptedSource]),
                    ("encrypted-unlocked", [encryptedSource, unlockedSource])
                ] {
                    try await runCampaign(
                        sources: order,
                        expectedUniqueStatements: 1,
                        expectedCanonicalTransactions: encryptedSource.oracle.rows.count,
                        expectedInstrumentCount: encryptedSource.oracle.distinctInstrumentObservationCount,
                        inMemory: inMemory,
                        credentialStore: credentialStore,
                        campaign: "pair-\(pairIndex)-\(orderName)"
                    )
                }
            }

            let combined = chronological + unlocked.sorted {
                $0.oracle.period.start < $1.oracle.period.start
            }
            try await runCampaign(
                sources: combined,
                expectedUniqueStatements: 8,
                expectedCanonicalTransactions: Self.expectedCanonicalTransactionCount,
                expectedInstrumentCount: 3,
                inMemory: inMemory,
                credentialStore: credentialStore,
                campaign: "combined-ten-source"
            )
        }
    }

    private func verifyProductionAgainstIndependentOracle(
        sources: [PrivateSource],
        credentialStore: any StatementPasswordCredentialStore
    ) async throws {
        let provider = DatabaseProvider(inMemory: true)
        let workspaceID = "amex-private-oracle-\(UUID().uuidString)"
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "Private acceptance")
        )
        let engine = makeEngine(
            provider: provider,
            coordinator: coordinator,
            credentialStore: credentialStore
        )

        var rowMismatchCount = 0
        var sectionMismatchCount = 0
        var summaryMismatchCount = 0
        for source in sources {
            let prepared = try await engine.prepareImport(from: source.url)
            defer { engine.cancelPreparedImport(prepared) }
            guard prepared.validation.passed,
                  let evidence = prepared.financialDocument.cardStatementEvidence else {
                throw PrivateAcceptanceError.productionRejectedSource
            }

            let productionRows = try productionOracleRows(
                document: prepared.financialDocument,
                evidence: evidence
            )
            rowMismatchCount += mismatchCount(source.oracle.rows, productionRows)

            let productionSections = evidence.instrumentSections.map { section in
                OracleSection(
                    ordinal: section.sourceOrdinal,
                    holderLabel: section.holderLabel,
                    instrumentObservation: section.sourceIdentityObservations.first?.value ?? "",
                    signedTotal: section.signedNetTotal
                )
            }
            sectionMismatchCount += mismatchCount(source.oracle.sections, productionSections)

            let productionSummary = try OracleSummary(
                previousBalance: requiredMoney(evidence, code: "previous_balance"),
                newCredits: requiredMoney(evidence, code: "new_credits"),
                newDebits: requiredMoney(evidence, code: "new_debits"),
                newBalance: requiredMoney(evidence, code: "new_balance"),
                dueDate: requiredDate(evidence, code: "due_date")
            )
            if source.oracle.summary != productionSummary ||
                source.oracle.statementDate != evidence.statementDate ||
                source.oracle.period != evidence.declaredStatementPeriod ||
                source.oracle.accountObservation != evidence.accountSourceIdentityObservations.first?.value {
                summaryMismatchCount += 1
            }
        }
        #expect(rowMismatchCount == 0)
        #expect(sectionMismatchCount == 0)
        #expect(summaryMismatchCount == 0)
    }

    private func runCampaign<S: Sequence>(
        sources: S,
        expectedUniqueStatements: Int,
        expectedCanonicalTransactions: Int,
        expectedInstrumentCount: Int,
        inMemory: Bool,
        credentialStore: any StatementPasswordCredentialStore,
        campaign: String
    ) async throws where S.Element == PrivateSource {
        let orderedSources = Array(sources)
        let workspaceID = "amex-private-\(campaign)-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-Amex-Acceptance-\(UUID().uuidString)", isDirectory: true)
        let sqlitePath = folder.appendingPathComponent("acceptance.sqlite").path
        let sqlite: SQLiteRepositoryProvider?
        let provider: DatabaseProvider
        if inMemory {
            sqlite = nil
            provider = DatabaseProvider(inMemory: true)
        } else {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let opened = try SQLiteRepositoryProvider(path: sqlitePath)
            sqlite = opened
            provider = DatabaseProvider.verifiedSQLite(opened, protectsGeneration: false)
        }
        defer {
            sqlite?.database.close()
            if !inMemory { try? FileManager.default.removeItem(at: folder) }
        }

        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "Private acceptance")
        )
        let engine = makeEngine(
            provider: provider,
            coordinator: coordinator,
            credentialStore: credentialStore
        )

        var accountID: String?
        var importedPeriodKeys = Set<String>()
        var supportingSourceCount = 0
        for source in orderedSources {
            let prepared = try await engine.prepareImport(from: source.url)
            guard prepared.validation.passed else {
                engine.cancelPreparedImport(prepared)
                throw PrivateAcceptanceError.productionRejectedSource
            }
            let isEquivalentContainer = importedPeriodKeys.contains(source.oracle.periodKey)
            let choice: ImportAccountChoice?
            if isEquivalentContainer {
                choice = nil
            } else if let accountID {
                choice = try explicitSectionChoice(
                    for: prepared.financialDocument,
                    accountID: accountID,
                    provider: provider,
                    workspaceID: workspaceID
                )
            } else {
                choice = .createNewCardLiabilityAccountAndInstrument
            }
            let result = try coordinator.persistValidatedImport(
                financialDocument: prepared.financialDocument,
                importSession: prepared.importSession,
                validation: prepared.validation,
                fingerprintSet: prepared.fingerprintSet,
                accountChoice: choice,
                providerGeneration: provider.generationToken
            )
            engine.cancelPreparedImport(prepared)
            guard result.persisted else { throw PrivateAcceptanceError.persistenceRejectedSource }
            if isEquivalentContainer {
                guard result.isEquivalentSupportingSource, result.transactionCount == 0 else {
                    throw PrivateAcceptanceError.semanticEquivalenceMismatch
                }
                supportingSourceCount += 1
            } else {
                guard !result.isEquivalentSupportingSource,
                      result.transactionCount == source.oracle.rows.count else {
                    throw PrivateAcceptanceError.semanticEquivalenceMismatch
                }
                importedPeriodKeys.insert(source.oracle.periodKey)
            }
            if let existingAccountID = accountID {
                guard result.accountId == existingAccountID else {
                    throw PrivateAcceptanceError.persistenceGraphMismatch
                }
            } else {
                accountID = result.accountId
            }
        }

        guard let newest = orderedSources.max(by: {
            $0.oracle.statementDate < $1.oracle.statementDate
        }) else {
            throw PrivateAcceptanceError.unexpectedCorpusShape
        }
        try verifyFinalState(
            provider: provider,
            workspaceID: workspaceID,
            sourceCount: orderedSources.count,
            uniqueStatementCount: expectedUniqueStatements,
            canonicalTransactionCount: expectedCanonicalTransactions,
            instrumentCount: expectedInstrumentCount,
            expectedSectionCount: orderedSources.reduce(0) { $0 + $1.oracle.sections.count },
            expectedProjectionEventCount: orderedSources.reduce(0) { $0 + $1.oracle.rows.count },
            expectedSupportingSourceCount: supportingSourceCount,
            newestSummary: newest.oracle.summary
        )

        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopenedSQLite = try SQLiteRepositoryProvider(path: sqlitePath)
            let reopened = DatabaseProvider.verifiedSQLite(reopenedSQLite, protectsGeneration: false)
            try verifyFinalState(
                provider: reopened,
                workspaceID: workspaceID,
                sourceCount: orderedSources.count,
                uniqueStatementCount: expectedUniqueStatements,
                canonicalTransactionCount: expectedCanonicalTransactions,
                instrumentCount: expectedInstrumentCount,
                expectedSectionCount: orderedSources.reduce(0) { $0 + $1.oracle.sections.count },
                expectedProjectionEventCount: orderedSources.reduce(0) { $0 + $1.oracle.rows.count },
                expectedSupportingSourceCount: supportingSourceCount,
                newestSummary: newest.oracle.summary
            )
            try reopenedSQLite.database.checkpointAndClose()
        }
    }

    private func explicitSectionChoice(
        for document: FinancialDocument,
        accountID: String,
        provider: DatabaseProvider,
        workspaceID: String
    ) throws -> ImportAccountChoice {
        guard let evidence = document.cardStatementEvidence else {
            throw PrivateAcceptanceError.productionRejectedSource
        }
        let snapshot = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        let choices = try Dictionary(uniqueKeysWithValues: evidence.instrumentSections.map { section in
            guard let incoming = section.sourceIdentityObservations.first?.value else {
                throw PrivateAcceptanceError.productionRejectedSource
            }
            let instrumentIDs = Set(snapshot.sectionObservations.compactMap { observation -> String? in
                guard observation.sourceValue == incoming,
                      let durableSection = snapshot.sections.first(where: {
                          $0.id == observation.cardStatementSectionId
                      }),
                      snapshot.instruments.contains(where: {
                          $0.id == durableSection.instrumentId && $0.liabilityAccountId == accountID
                      }) else { return nil }
                return durableSection.instrumentId
            })
            let choice: ImportCardInstrumentChoice
            if instrumentIDs.isEmpty {
                choice = .createNewInstrument()
            } else if instrumentIDs.count == 1, let instrumentID = instrumentIDs.first {
                choice = .reuseExistingInstrument(instrumentId: instrumentID)
            } else {
                throw PrivateAcceptanceError.persistenceGraphMismatch
            }
            return (section.documentScopedSectionID, choice)
        })
        return .useExistingCardLiabilityAccountSections(
            accountId: accountID,
            sectionChoices: choices
        )
    }

    private func verifyFinalState(
        provider: DatabaseProvider,
        workspaceID: String,
        sourceCount: Int,
        uniqueStatementCount: Int,
        canonicalTransactionCount: Int,
        instrumentCount: Int,
        expectedSectionCount: Int,
        expectedProjectionEventCount: Int,
        expectedSupportingSourceCount: Int,
        newestSummary: OracleSummary
    ) throws {
        #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).count == 1)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == canonicalTransactionCount)
        let card = try provider.cardRepo.snapshot(workspaceId: workspaceID)
        #expect(card.instruments.count == instrumentCount)
        #expect(card.instruments.allSatisfy { $0.lifecycleStateCode == CardInstrumentLifecycleState.unknown.rawValue })
        #expect(card.relationships.isEmpty)
        #expect(card.statements.count == sourceCount)
        #expect(card.sections.count == expectedSectionCount)
        #expect(card.sectionObservations.count == expectedSectionCount)
        #expect(card.transactionEvidence.count == canonicalTransactionCount)
        #expect(card.semanticProjections.count == sourceCount)
        #expect(card.semanticGroups.count == uniqueStatementCount)
        #expect(card.semanticMembers.count == sourceCount)
        #expect(card.semanticMembers.filter { $0.role == .supporting }.count == expectedSupportingSourceCount)
        #expect(card.semanticProjections.reduce(0) { $0 + $1.events.count } == expectedProjectionEventCount)
        #expect(Set(card.sections.map(\.instrumentId)).count == instrumentCount)
        for statement in card.statements {
            guard try provider.importSessionRepo.importSession(id: statement.importSessionId) != nil,
                  try provider.importSessionRepo.importedDocument(id: statement.documentId) != nil else {
                throw PrivateAcceptanceError.persistenceGraphMismatch
            }
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
        guard let account = hydrated.accounts.first else {
            throw PrivateAcceptanceError.persistenceGraphMismatch
        }
        let expectedLiability = try Money(
            amount: -newestSummary.newBalance.amount,
            currency: newestSummary.newBalance.currency
        )
        let balanceMismatchCount = account.currentBalanceMoney == expectedLiability ? 0 : 1
        #expect(balanceMismatchCount == 0)
        #expect(hydrated.transactions.count == canonicalTransactionCount)
        #expect(hydrated.cardSnapshot.instruments.count == instrumentCount)
        #expect(hydrated.cardSnapshot.statements.count == sourceCount)
    }

    private func makeEngine(
        provider: DatabaseProvider,
        coordinator: DefaultImportPersistenceCoordinator,
        credentialStore: any StatementPasswordCredentialStore
    ) -> ImportEngine {
        let passwordProvider = DefaultPasswordProvider(
            credentialStore: credentialStore,
            supportedInstitutionCodes: [Institution.amex.statementPasswordCredentialScope],
            challenge: { _ in throw PrivateAcceptanceError.unexpectedPasswordChallenge }
        )
        return ImportEngine(
            importCoordinator: DefaultImportCoordinator(
                readerRegistry: DefaultReaderRegistry(),
                passwordProvider: passwordProvider
            ),
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { .init(didHydrate: true, accountCount: 0, transactionCount: 0) }
        )
    }

    private func productionOracleRows(
        document: FinancialDocument,
        evidence: CardStatementEvidence
    ) throws -> [OracleRow] {
        let annotationByID = Dictionary(
            uniqueKeysWithValues: evidence.transactionAnnotations.map { ($0.parserTransactionID, $0) }
        )
        let ordinalBySectionID = Dictionary(
            uniqueKeysWithValues: evidence.instrumentSections.map {
                ($0.documentScopedSectionID, $0.sourceOrdinal)
            }
        )
        return try document.transactions.map { transaction in
            guard let annotation = annotationByID[transaction.id],
                  let postingDate = transaction.statementDate,
                  let reference = transaction.reference,
                  let sourceOrdinal = transaction.sourceProvenance.first?.sourceOrdinal else {
                throw PrivateAcceptanceError.productionMismatch
            }
            let sectionOrdinal: Int?
            switch annotation.financialScope {
            case .accountLevel:
                sectionOrdinal = annotation.documentScopedSectionID.flatMap { ordinalBySectionID[$0] }
            case .instrument:
                sectionOrdinal = annotation.documentScopedSectionID.flatMap { ordinalBySectionID[$0] }
            }
            return OracleRow(
                sourceOrdinal: sourceOrdinal,
                transactionDate: annotation.sourceTransactionDate,
                postingDate: postingDate,
                effect: annotation.liabilityEffect,
                postedMoney: transaction.money,
                originalMoney: annotation.originalMerchantMoney,
                reference: reference,
                sectionOrdinal: sectionOrdinal
            )
        }
    }

    private func requiredMoney(_ evidence: CardStatementEvidence, code: String) throws -> Money {
        guard let value = evidence.summary(code: code)?.money else {
            throw PrivateAcceptanceError.productionMismatch
        }
        return value
    }

    private func requiredDate(_ evidence: CardStatementEvidence, code: String) throws -> StatementDate {
        guard let value = evidence.summary(code: code)?.date else {
            throw PrivateAcceptanceError.productionMismatch
        }
        return value
    }

    private func mismatchCount<T: Equatable>(_ left: [T], _ right: [T]) -> Int {
        zip(left, right).filter { $0.0 != $0.1 }.count + abs(left.count - right.count)
    }

    private func requireSingle<T>(_ values: [T]) throws -> T {
        guard values.count == 1, let value = values.first else {
            throw PrivateAcceptanceError.unexpectedCorpusShape
        }
        return value
    }
}

private enum PrivateAcceptanceError: Error {
    case missingRememberedCredential
    case unexpectedCorpusShape
    case unreadableSource
    case unlockFailed
    case oracleMismatch
    case productionMismatch
    case productionRejectedSource
    case persistenceRejectedSource
    case persistenceGraphMismatch
    case semanticEquivalenceMismatch
    case unexpectedPasswordChallenge
}

@MainActor
private struct PrivateSource {
    let url: URL
    let isEncrypted: Bool
    let sourceByteDigest: Data
    let oracle: PrivateAmexOracleStatement

    init(url: URL, password: String) throws {
        let bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard let pdf = PDFDocument(data: bytes) else { throw PrivateAcceptanceError.unreadableSource }
        let wasEncrypted = pdf.isLocked
        if wasEncrypted, !pdf.unlock(withPassword: password) {
            throw PrivateAcceptanceError.unlockFailed
        }
        guard !pdf.isLocked else { throw PrivateAcceptanceError.unlockFailed }
        self.url = url
        self.isEncrypted = wasEncrypted
        self.sourceByteDigest = Data(SHA256.hash(data: bytes))
        self.oracle = try PrivateAmexIndependentOracle.parse(pdf: pdf)
    }
}

@MainActor
private struct OracleSummary: Equatable {
    let previousBalance: Money
    let newCredits: Money
    let newDebits: Money
    let newBalance: Money
    let dueDate: StatementDate
}

@MainActor
private struct OracleSection: Equatable {
    let ordinal: Int
    let holderLabel: String?
    let instrumentObservation: String
    let signedTotal: Money
}

@MainActor
private struct OracleRow: Equatable {
    let sourceOrdinal: Int
    let transactionDate: StatementDate
    let postingDate: StatementDate
    let effect: CardLiabilityEffect
    let postedMoney: Money
    let originalMoney: Money?
    let reference: String
    let sectionOrdinal: Int?
}

@MainActor
private struct PrivateAmexOracleStatement: Equatable {
    let statementDate: StatementDate
    let period: DeclaredStatementPeriod
    let accountObservation: String
    let summary: OracleSummary
    let sections: [OracleSection]
    let rows: [OracleRow]

    var periodKey: String { "\(period.start.canonical)/\(period.end.canonical)" }

    var statementReconciles: Bool {
        guard let calculated = try? (try summary.previousBalance - summary.newCredits) + summary.newDebits else {
            return false
        }
        return calculated == summary.newBalance
    }

    var sectionReconciliationMismatchCount: Int {
        sections.filter { section in
            let values = rows.filter { $0.sectionOrdinal == section.ordinal }.map(\.postedMoney)
            guard !values.isEmpty, let calculated = try? Money.aggregate(values) else { return true }
            return calculated != section.signedTotal
        }.count
    }

    var distinctInstrumentObservationCount: Int {
        Set(sections.map(\.instrumentObservation)).count
    }

    func isFinanciallyEquivalent(to other: Self) -> Bool {
        statementDate == other.statementDate && period == other.period &&
            accountObservation == other.accountObservation && summary == other.summary &&
            sections == other.sections && rows == other.rows
    }
}

@MainActor
private enum PrivateAmexIndependentOracle {
    private static let openingPattern = #"^New Transactions For (.+?) Card Account Number: ([0-9X-]+)$"#
    private static let totalPattern = #"^Total of New Transactions For (.+?) ([0-9]+(?:,[0-9]{3})*\.\d{2})(?: ?(CR|DR))?$"#
    private static let rowPattern = #"^(\d{2}-[A-Za-z]{3}-\d{4}) (\d{2}-[A-Za-z]{3}-\d{4}) (.+)$"#
    private static let postedPattern = #"^([0-9]+(?:,[0-9]{3})*\.\d{2})(?: (CR))?$"#
    private static let foreignPattern = #"^([0-9]+(?:,[0-9]{3})*(?:\.\d+)?) ([A-Z]{3})(?: (CR))? ([0-9]+(?:,[0-9]{3})*\.\d{2})(?: (CR))?$"#

    static func parse(pdf: PDFDocument) throws -> PrivateAmexOracleStatement {
        let pages = try (0..<pdf.pageCount).map { index -> String in
            guard let text = pdf.page(at: index)?.string,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PrivateAcceptanceError.oracleMismatch
            }
            return text
        }
        let joined = pages.joined(separator: "\n")
        guard joined.contains("The Platinum Card (QAR)"),
              joined.contains("AMEX (MIDDLE EAST) B.S.C. (C)"),
              joined.contains("Statement of Account") else {
            throw PrivateAcceptanceError.oracleMismatch
        }

        let accountObservation = try uniqueCapture(
            #"Membership Number\s+Statement date\s+Statement Period\s+([0-9X-]+)\s+\d{2}/\d{2}/\d{2}\s+\d{2}/\d{2}/\d{2} to \d{2}/\d{2}/\d{2}"#,
            in: joined
        )
        let statementDate = try shortDate(uniqueCapture(
            #"Membership Number\s+Statement date\s+Statement Period\s+[0-9X-]+\s+(\d{2}/\d{2}/\d{2})\s+\d{2}/\d{2}/\d{2} to \d{2}/\d{2}/\d{2}"#,
            in: joined
        ))
        let periodText = try uniqueCapture(
            #"Membership Number\s+Statement date\s+Statement Period\s+[0-9X-]+\s+\d{2}/\d{2}/\d{2}\s+(\d{2}/\d{2}/\d{2} to \d{2}/\d{2}/\d{2})"#,
            in: joined
        )
        let periodParts = periodText.components(separatedBy: " to ")
        guard periodParts.count == 2 else { throw PrivateAcceptanceError.oracleMismatch }
        let period = try DeclaredStatementPeriod(
            start: shortDate(periodParts[0]),
            end: shortDate(periodParts[1])
        )
        let summaryValues = try capturesRequired(
            #"Previous Balance\s+New Credits\s+New Debits\s+New Balance\s+Due Date\s+- \(QAR\) \+ \(QAR\) = \(QAR\)\s+(?:\(QAR\)\s+)?([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+(\d{2}/\d{2}/\d{2})"#,
            in: pages[0],
            count: 5
        )
        let summary = try OracleSummary(
            previousBalance: money(summaryValues[0], currency: "QAR", negative: false),
            newCredits: money(summaryValues[1], currency: "QAR", negative: false),
            newDebits: money(summaryValues[2], currency: "QAR", negative: false),
            newBalance: money(summaryValues[3], currency: "QAR", negative: false),
            dueDate: shortDate(summaryValues[4])
        )

        var sections = [OracleSection]()
        var rows = [OracleRow]()
        var current: (ordinal: Int, holder: String, observation: String)?
        for page in pages {
            let lines = page.components(separatedBy: .newlines)
            var index = 0
            while index < lines.count {
                let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if let opening = captures(openingPattern, in: line) {
                    guard opening.count == 2 else {
                        throw PrivateAcceptanceError.oracleMismatch
                    }
                    if let current {
                        guard current.holder == opening[0], current.observation == opening[1] else {
                            throw PrivateAcceptanceError.oracleMismatch
                        }
                    } else {
                        current = (sections.count + 1, opening[0], opening[1])
                    }
                    index += 1
                    continue
                }
                if let total = captures(totalPattern, in: line) {
                    guard total.count == 3, let openedSection = current,
                          total[0] == openedSection.holder else {
                        throw PrivateAcceptanceError.oracleMismatch
                    }
                    sections.append(OracleSection(
                        ordinal: openedSection.ordinal,
                        holderLabel: openedSection.holder,
                        instrumentObservation: openedSection.observation,
                        signedTotal: try money(total[1], currency: "QAR", negative: total[2] == "CR")
                    ))
                    current = nil
                    index += 1
                    continue
                }
                guard let start = captures(rowPattern, in: line), start.count == 3 else {
                    index += 1
                    continue
                }
                var block = [start[2]]
                index += 1
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    if captures(rowPattern, in: candidate) != nil ||
                        captures(openingPattern, in: candidate) != nil ||
                        captures(totalPattern, in: candidate) != nil ||
                        candidate.hasPrefix("This Card is issued by AMEX") {
                        break
                    }
                    if !candidate.isEmpty { block.append(candidate) }
                    index += 1
                }
                rows.append(try parseRow(
                    block: block,
                    transactionDate: start[0],
                    postingDate: start[1],
                    sourceOrdinal: rows.count + 1,
                    sectionOrdinal: current?.ordinal
                ))
            }
        }
        guard current == nil, !sections.isEmpty, !rows.isEmpty else {
            throw PrivateAcceptanceError.oracleMismatch
        }
        return PrivateAmexOracleStatement(
            statementDate: statementDate,
            period: period,
            accountObservation: accountObservation,
            summary: summary,
            sections: sections,
            rows: rows
        )
    }

    private static func parseRow(
        block: [String],
        transactionDate: String,
        postingDate: String,
        sourceOrdinal: Int,
        sectionOrdinal: Int?
    ) throws -> OracleRow {
        var effect: CardLiabilityEffect?
        var postedMoney: Money?
        var originalMoney: Money?
        var reference: String?
        for line in block {
            if let values = captures(foreignPattern, in: line), values.count == 5 {
                guard postedMoney == nil, values[2].isEmpty == values[4].isEmpty else {
                    throw PrivateAcceptanceError.oracleMismatch
                }
                let isCredit = !values[4].isEmpty
                effect = isCredit ? .decreasesAmountOwed : .increasesAmountOwed
                originalMoney = try money(values[0], currency: values[1], negative: isCredit)
                postedMoney = try money(values[3], currency: "QAR", negative: isCredit)
            } else if let values = captures(postedPattern, in: line), values.count == 2 {
                guard postedMoney == nil else { throw PrivateAcceptanceError.oracleMismatch }
                let isCredit = !values[1].isEmpty
                effect = isCredit ? .decreasesAmountOwed : .increasesAmountOwed
                postedMoney = try money(values[0], currency: "QAR", negative: isCredit)
            } else if line.hasPrefix("Reference: ") {
                guard reference == nil else { throw PrivateAcceptanceError.oracleMismatch }
                reference = String(line.dropFirst("Reference: ".count))
            }
        }
        guard let effect, let postedMoney, let reference, !reference.isEmpty else {
            throw PrivateAcceptanceError.oracleMismatch
        }
        return OracleRow(
            sourceOrdinal: sourceOrdinal,
            transactionDate: try longDate(transactionDate),
            postingDate: try longDate(postingDate),
            effect: effect,
            postedMoney: postedMoney,
            originalMoney: originalMoney,
            reference: reference,
            sectionOrdinal: sectionOrdinal
        )
    }

    private static func uniqueCapture(_ pattern: String, in text: String) throws -> String {
        let values = allCaptures(pattern, in: text).compactMap(\.first)
        guard let first = values.first, values.allSatisfy({ $0 == first }) else {
            throw PrivateAcceptanceError.oracleMismatch
        }
        return first
    }

    private static func capturesRequired(
        _ pattern: String,
        in text: String,
        count: Int
    ) throws -> [String] {
        guard let values = captures(pattern, in: text), values.count == count else {
            throw PrivateAcceptanceError.oracleMismatch
        }
        return values
    }

    private static func captures(_ pattern: String, in text: String) -> [String]? {
        allCaptures(pattern, in: text).first
    }

    private static func allCaptures(_ pattern: String, in text: String) -> [[String]] {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .anchorsMatchLines]
        ) else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (1..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: text) else { return "" }
                return String(text[range])
            }
        }
    }

    private static func money(_ value: String, currency: String, negative: Bool) throws -> Money {
        guard let amount = Decimal(
            string: value.replacingOccurrences(of: ",", with: ""),
            locale: Locale(identifier: "en_US_POSIX")
        ) else { throw PrivateAcceptanceError.oracleMismatch }
        return try Money(amount: negative ? -amount : amount, currency: CurrencyCode(currency))
    }

    private static func shortDate(_ value: String) throws -> StatementDate {
        let parts = value.split(separator: "/")
        guard parts.count == 3,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]) else {
            throw PrivateAcceptanceError.oracleMismatch
        }
        return try StatementDate(year: 2000 + year, month: month, day: day)
    }

    private static func longDate(_ value: String) throws -> StatementDate {
        let parts = value.split(separator: "-")
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard parts.count == 3,
              let day = Int(parts[0]),
              let monthIndex = months.firstIndex(where: {
                  $0.caseInsensitiveCompare(String(parts[1])) == .orderedSame
              }),
              let year = Int(parts[2]) else {
            throw PrivateAcceptanceError.oracleMismatch
        }
        return try StatementDate(year: year, month: monthIndex + 1, day: day)
    }
}
