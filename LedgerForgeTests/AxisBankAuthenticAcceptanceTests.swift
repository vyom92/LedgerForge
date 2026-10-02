import CryptoKit
import CLegacyXLS
import PDFKit
import Foundation
import Testing
@testable import LedgerForge

/// Complete external authentic corpus compared only with independently
/// extracted source facts. No source statement or FinancialDocument is made by
/// this test.
@MainActor
struct AxisBankAuthenticAcceptanceTests {
    private struct Oracle: Decodable {
        let schema: String
        let sourceInventorySha256: String
        let corpus: Corpus
        let carriers: [Carrier]
    }

    private struct Corpus: Decodable {
        let carrierCount: Int
        let logicalStatementCount: Int
        let canonicalEventCount: Int
        let representationRowCount: Int
        let formatCounts: [String: Int]
        let pageCounts: [Int]
    }

    private struct Carrier: Decodable {
        let sourceSha256: String
        let sourceSize: Int
        let format: String
        let logicalStatementId: String
        let accountIdentifierSha256: String
        let periodStart: String
        let periodEnd: String
        let rowCount: Int
        let pageCount: Int?
        let headerSourceOrdinal: Int?
        let controls: Controls
        let rows: [Row]
    }

    private struct Controls: Decodable {
        let openingBalance: String
        let closingBalance: String
        let debitTotal: String
        let creditTotal: String
        var printedLiterals: [String: String] = [:]
    }

    private struct Row: Decodable {
        let sourceOrder: Int
        let correspondenceOrder: Int
        let sourceOrdinal: Int
        let sourcePage: Int?
        let date: String
        let direction: String
        let signedAmount: String
        let balance: String
        let descriptionSha256: String
        let chequeReferenceSha256: String?
        let upiOperation: String?
        let upiReference: String?
        let upiReferenceSha256: String?
        let upiSubtype: String?
    }

    private struct Runtime {
        let provider: DatabaseProvider
        let engine: ImportEngine
        let hydrator: RepositoryStoreHydrator
        let accountStore: AccountStore
        let transactionStore: TransactionStore
        let importSessionStore: ImportSessionStore
        let importAttemptStore: ImportAttemptStore
    }

    private struct CampaignEvidence {
        let carrierByImportSessionID: [String: Carrier]
        let accountIDBySourceDigest: [String: String]
        let authoritativeImportSessionIDs: Set<String>
        let eventKeysByImportSessionID: [String: Set<TransactionEventIdentityKeyDTO>]
    }

    @Test(.globalRuntimeStateIsolation)
    func completeAuthenticCorpusMatchesIndependentOracleAndCrossFormatProjection() async throws {
        let environment = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: try #require(environment["LEDGERFORGE_AXIS_BANK_ROOT"]))
        let oracle = try Self.loadOracle(root: root)
        let sources = try sourceURLsByDigest(root: root)

        expectSourceFact(oracle.schema == "ledgerforge.axis-bank.source-oracle.v1")
        expectSourceFact(oracle.sourceInventorySha256 == "022bab027d5e158291ad445a673d40df141f3d5b726decd23aff60d37c6dec2d")
        expectSourceFact(oracle.corpus.carrierCount == 9)
        expectSourceFact(oracle.corpus.logicalStatementCount == 3)
        expectSourceFact(oracle.corpus.canonicalEventCount == 182)
        expectSourceFact(oracle.corpus.representationRowCount == 546)
        expectSourceFact(oracle.corpus.formatCounts == ["csv": 3, "pdf": 3, "xls": 3])
        expectSourceFact(oracle.corpus.pageCounts.sorted() == [2, 3, 4])
        expectSourceFact(oracle.carriers.count == 9)
        expectSourceFact(sources.count == 9)
        expectSourceFact(Set(oracle.carriers.map(\.sourceSha256)) == Set(sources.keys))

        let provider = DatabaseProvider(inMemory: true)
        let workspaceID = "axis-bank-authentic-parse-\(UUID().uuidString.lowercased())"
        let engine = makeEngine(provider: provider, workspaceID: workspaceID)

        for carrier in oracle.carriers {
            let label = privacySafeLabel(carrier)
            let sourceURL = try #require(sources[carrier.sourceSha256])
            let prepared = try await engine.prepareImport(from: sourceURL)
            defer { engine.cancelPreparedImport(prepared) }

            let snapshotDigest = try prepared.sourceSnapshot.withBytes(sha256)
            expectSourceFact(snapshotDigest == carrier.sourceSha256, "\(label): source bytes")
            expectSourceFact(prepared.sourceSnapshot.byteCount == carrier.sourceSize, "\(label): source size")
            expectSourceFact(prepared.detectedInstitution == .axis, "\(label): institution")
            expectSourceFact(prepared.detectedDocumentType == .bankAccount, "\(label): family")
            expectSourceFact(prepared.financialDocument.metadata.fileFormat.rawValue.lowercased() == carrier.format, "\(label): format")
            expectSourceFact(prepared.validation.passed, "\(label): validation")
            try verify(prepared: prepared, against: carrier)
        }

        // loadOracle establishes a unique source-row correspondence directly
        // from the originals. Every parser is then checked against its own
        // original's literal balances, narration and physical ordering above.
        for group in Dictionary(grouping: oracle.carriers, by: \.logicalStatementId).values {
            expectSourceFact(group.count == 3)
            expectSourceFact(Set(group.map(\.format)) == Set(["csv", "pdf", "xls"]))
        }

        expectSourceFact(try provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
        expectSourceFact(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
        expectSourceFact(try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspaceID).isEmpty)
        expectSourceFact(try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceID).isEmpty)
        expectSourceFact(try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceID).isEmpty)
        expectSourceFact(try provider.importSessionRepo.bankSectionSnapshot(workspaceId: workspaceID).sections.isEmpty)
    }

    @Test(.globalRuntimeStateIsolation)
    func completeAuthenticCorpusPersistsWithProviderParityReplayReopenAndHydration() async throws {
        let environment = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: try #require(environment["LEDGERFORGE_AXIS_BANK_ROOT"]))
        let oracle = try Self.loadOracle(root: root)
        let sources = try sourceURLsByDigest(root: root)
        expectSourceFact(oracle.carriers.count == 9)
        expectSourceFact(sources.count == 9)

        for inMemory in [true, false] {
            for reverseSourceOrder in [false, true] {
                try await runAuthenticPersistenceCampaign(
                    oracle: oracle,
                    sources: sources,
                    inMemory: inMemory,
                    reverseSourceOrder: reverseSourceOrder
                )
            }
        }
    }

    private func runAuthenticPersistenceCampaign(
        oracle: Oracle,
        sources: [String: URL],
        inMemory: Bool,
        reverseSourceOrder: Bool
    ) async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-Axis-Bank-Authentic-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let sqlite = inMemory ? nil : try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("acceptance.sqlite").path
        )
        defer { sqlite?.database.close() }
        let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) }
            ?? DatabaseProvider(inMemory: true)
        let workspaceID = "axis-bank-authentic-persistence-\(UUID().uuidString.lowercased())"
        let runtime = makeRuntime(provider: provider, workspaceID: workspaceID)
        let campaignOrder = try orderedCampaignCarriers(oracle.carriers)
        // Only the order in which exact originals are imported changes.
        let ordered = reverseSourceOrder ? Array(campaignOrder.reversed()) : campaignOrder

        let cancelledCarrier = try #require(ordered.first)
        let cancelledURL = try #require(sources[cancelledCarrier.sourceSha256])
        let cancelled = try await runtime.engine.prepareImport(from: cancelledURL)
        runtime.engine.cancelPreparedImport(cancelled)
        let cancelledCommit = await runtime.engine.commitPreparedImport(cancelled)
        expectSourceFact(!cancelledCommit.persisted, "cancelled authentic confirmation is rejected")
        try verifyNoFinancialResidue(provider, workspaceID: workspaceID)

        var carrierByImportSessionID: [String: Carrier] = [:]
        var accountIDBySourceDigest: [String: String] = [:]
        var accountIDByIdentifierDigest: [String: String] = [:]
        var authoritativeImportSessionIDByLogicalStatement: [String: String] = [:]
        var authoritativeImportSessionIDs = Set<String>()
        var eventKeysByImportSessionID: [String: Set<TransactionEventIdentityKeyDTO>] = [:]
        var expectedCanonicalTransactionCount = 0

        for carrier in ordered {
            let label = privacySafeLabel(carrier)
            let sourceURL = try #require(sources[carrier.sourceSha256])
            let prepared = try await runtime.engine.prepareImport(from: sourceURL)
            try verify(prepared: prepared, against: carrier)
            let transactionsBefore = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
            let projectionsBefore = try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspaceID)
            let groupsBefore = try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceID)
            let membersBefore = try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceID)

            let isAuthoritative = authoritativeImportSessionIDByLogicalStatement[carrier.logicalStatementId] == nil
            if isAuthoritative {
                expectSourceFact(prepared.statementEquivalenceReview == .firstAcceptedSource,
                        "\(label): first source review")
            } else {
                // Supporting standalone sources use BankImport occurrence review;
                // the legacy whole-statement projection review is not applicable.
                expectSourceFact(prepared.statementEquivalenceReview == .notApplicable,
                        "\(label): supporting occurrence-route review")
            }

            let accountChoice: ImportAccountChoice
            switch try runtime.engine.reviewPreparedImport(prepared) {
            case .matchedExisting(let accountID):
                accountChoice = .useExistingAccount(accountId: accountID)
            case .choiceRequired:
                accountChoice = .createNewAccount(displayName: "Imported review account")
            default:
                Issue.record("\(label): account identity review did not provide a destination")
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }

            let committed = await runtime.engine.commitPreparedImport(
                prepared,
                accountChoice: accountChoice
            )
            expectSourceFact(committed.persisted, "\(label): \(committed.errorMessage ?? "confirmation failed")")
            expectSourceFact(committed.hydrationOutcome == .committedAndHydrated, "\(label): commit hydration")
            expectSourceFact(committed.isEquivalentSupportingSource == !isAuthoritative,
                    "\(label): source authority role")
            expectSourceFact(committed.transactionCount == (isAuthoritative ? carrier.rowCount : 0),
                    "\(label): canonical transaction delta")
            guard committed.persisted,
                  let importSessionID = committed.importSessionId else {
                Issue.record("\(label): committed source session missing")
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }
            expectSourceFact(importSessionID == prepared.importSession.id.uuidString,
                    "\(label): committed session belongs to the prepared source")
            let accountID: String
            if isAuthoritative {
                accountID = try #require(committed.accountId,
                        "First-source receipt must retain its account destination.")
            } else {
                // BankImport receipts retain destinations on their source sections.
                expectSourceFact(committed.accountId == nil, "\(label): section-owned destination")
                guard committed.bankSections.count == 1,
                      let receipt = committed.bankSections.first else {
                    Issue.record("\(label): supporting receipt must contain one source section")
                    throw AxisBankAuthenticAcceptanceError.campaignInvariant
                }
                let sourceSections = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: workspaceID)
                    .sections.filter { $0.importSessionId == importSessionID }
                guard sourceSections.count == 1, let section = sourceSections.first else {
                    Issue.record("\(label): supporting receipt must bind one durable source section")
                    throw AxisBankAuthenticAcceptanceError.campaignInvariant
                }
                let authoritySessionID = try #require(authoritativeImportSessionIDByLogicalStatement[carrier.logicalStatementId])
                let authorityCarrier = try #require(carrierByImportSessionID[authoritySessionID])
                let authorityAccountID = try #require(accountIDBySourceDigest[authorityCarrier.sourceSha256])
                expectSourceFact(authorityCarrier.accountIdentifierSha256 == carrier.accountIdentifierSha256,
                        "\(label): source-proven authority account identity")
                expectSourceFact(receipt.sectionID == section.id, "\(label): receipt source-section binding")
                expectSourceFact(receipt.accountID == section.accountId && receipt.accountID == authorityAccountID,
                        "\(label): supporting source retains the authority account")
                expectSourceFact(receipt.sourceRowCount == carrier.rowCount, "\(label): receipt source multiplicity")
                expectSourceFact(receipt.importedTransactionCount == 0, "\(label): receipt creates no canonical transactions")
                expectSourceFact(committed.sourceRowCount == carrier.rowCount, "\(label): complete source count")
                expectSourceFact(committed.recognizedExistingRowCount == carrier.rowCount,
                        "\(label): every supporting row is already represented")
                accountID = receipt.accountID
            }

            if !isAuthoritative {
                expectSourceFact(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID) == transactionsBefore,
                        "\(label): supporting source preserves canonical transactions")
                expectSourceFact(try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspaceID) == projectionsBefore,
                        "\(label): supporting source preserves persisted v1 projections")
                expectSourceFact(try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceID) == groupsBefore,
                        "\(label): supporting source preserves persisted v1 groups")
                expectSourceFact(try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceID) == membersBefore,
                        "\(label): supporting source preserves persisted v1 members")
            }

            if let established = accountIDByIdentifierDigest[carrier.accountIdentifierSha256] {
                expectSourceFact(accountID == established, "\(label): stable source-proven account ownership")
            } else {
                accountIDByIdentifierDigest[carrier.accountIdentifierSha256] = accountID
            }
            accountIDBySourceDigest[carrier.sourceSha256] = accountID
            carrierByImportSessionID[importSessionID] = carrier
            if isAuthoritative {
                authoritativeImportSessionIDByLogicalStatement[carrier.logicalStatementId] = importSessionID
                authoritativeImportSessionIDs.insert(importSessionID)
                expectedCanonicalTransactionCount += carrier.rowCount
                let expectedKeys = try carrier.rows.compactMap {
                    try adr031EventKey(row: $0, resolvedAccountID: accountID)
                }
                let keys = Set(expectedKeys)
                expectSourceFact(keys.count == expectedKeys.count,
                        "\(label): unique ADR-031 identities")
                expectSourceFact(expectedKeys.count == carrier.rows.filter { $0.upiReference != nil }.count,
                        "\(label): all eligible authentic UPI rows")
                eventKeysByImportSessionID[importSessionID] = keys
            }

            expectSourceFact(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == expectedCanonicalTransactionCount,
                    "\(label): canonical transaction cardinality")

            let countsBeforeReplay = try financialRepositoryCounts(provider, workspaceID: workspaceID)
            let replay = try await runtime.engine.prepareImport(from: sourceURL)
            expectSourceFact(replay.advisoryPreviousImport != nil, "\(label): exact replay advisory")
            let replayed = await runtime.engine.commitPreparedImport(replay)
            expectSourceFact(!replayed.persisted, "\(label): exact replay rejected")
            expectSourceFact(replayed.previousImport != nil, "\(label): exact replay authority")
            expectSourceFact(try financialRepositoryCounts(provider, workspaceID: workspaceID) == countsBeforeReplay,
                    "\(label): exact replay leaves no financial residue")
        }

        expectSourceFact(accountIDByIdentifierDigest.count == 2, "two source-proven Axis accounts")
        expectSourceFact(expectedCanonicalTransactionCount == oracle.corpus.canonicalEventCount)
        let evidence = CampaignEvidence(
            carrierByImportSessionID: carrierByImportSessionID,
            accountIDBySourceDigest: accountIDBySourceDigest,
            authoritativeImportSessionIDs: authoritativeImportSessionIDs,
            eventKeysByImportSessionID: eventKeysByImportSessionID
        )
        try verifyPersistedCampaign(
            provider,
            workspaceID: workspaceID,
            oracle: oracle,
            evidence: evidence
        )
        let staged = try runtime.hydrator.stageHydration()
        try verifyHydratedSnapshot(staged, oracle: oracle, evidence: evidence)
        expectSourceFact(runtime.accountStore.accounts.count == 2)
        expectSourceFact(runtime.transactionStore.transactions.count == oracle.corpus.canonicalEventCount)
        expectSourceFact(runtime.importSessionStore.importSessions.count == oracle.carriers.count)

        if let sqlite {
            try sqlite.database.checkpointAndClose()
            let reopenedSQLite = try SQLiteRepositoryProvider(path: sqlite.databasePath)
            defer { reopenedSQLite.database.close() }
            let reopenedProvider = DatabaseProvider.verifiedSQLite(
                reopenedSQLite,
                protectsGeneration: false
            )
            try verifyPersistedCampaign(
                reopenedProvider,
                workspaceID: workspaceID,
                oracle: oracle,
                evidence: evidence
            )
            let reopenedRuntime = makeRuntime(
                provider: reopenedProvider,
                workspaceID: workspaceID
            )
            let hydration = try reopenedRuntime.hydrator.hydrateIfNeeded(forceRefresh: true)
            expectSourceFact(hydration.didHydrate)
            expectSourceFact(hydration.accountCount == 2)
            expectSourceFact(hydration.transactionCount == oracle.corpus.canonicalEventCount)
            expectSourceFact(hydration.importSessionCount == oracle.carriers.count)
            let reopenedSnapshot = try reopenedRuntime.hydrator.stageHydration()
            try verifyHydratedSnapshot(reopenedSnapshot, oracle: oracle, evidence: evidence)
        }
    }

    private func orderedCampaignCarriers(_ carriers: [Carrier]) throws -> [Carrier] {
        let groups = Dictionary(grouping: carriers, by: \.logicalStatementId)
        guard groups.count == 3,
              groups.values.allSatisfy({ group in
                  group.count == 3 && Set(group.map(\.format)) == Set(["csv", "pdf", "xls"])
              }) else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        let referenceGroups = groups.values.filter { group in
            group.contains { $0.rows.contains { $0.chequeReferenceSha256 != nil } }
        }
        guard referenceGroups.count == 1, let referenceGroup = referenceGroups.first else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        let remaining = groups.values
            .filter { $0[0].logicalStatementId != referenceGroup[0].logicalStatementId }
            .sorted { $0[0].logicalStatementId < $1[0].logicalStatementId }
        let campaigns = [(referenceGroup, "pdf"), (remaining[0], "csv"), (remaining[1], "xls")]
        let formatOrder = ["csv": 0, "pdf": 1, "xls": 2]
        return try campaigns.flatMap { group, authoritativeFormat in
            guard let authoritative = group.first(where: { $0.format == authoritativeFormat }) else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }
            return [authoritative] + group
                .filter { $0.format != authoritativeFormat }
                .sorted { formatOrder[$0.format, default: 9] < formatOrder[$1.format, default: 9] }
        }
    }

    private func verify(prepared: PreparedImport, against carrier: Carrier) throws {
        let label = privacySafeLabel(carrier)
        let document = prepared.financialDocument
        expectSourceFact(document.bookedCurrency?.code == "INR", "\(label): currency")
        expectSourceFact(document.declaredStatementPeriod?.start.canonical == carrier.periodStart, "\(label): period start")
        expectSourceFact(document.declaredStatementPeriod?.end.canonical == carrier.periodEnd, "\(label): period end")
        expectSourceFact(document.transactions.count == carrier.rowCount, "\(label): row count")
        expectSourceFact(document.transactions.count == carrier.rows.count, "\(label): oracle row count")
        expectSourceFact(document.financialIdentifiers.count == 1, "\(label): identifier count")
        expectSourceFact(document.financialIdentifiers.first?.kind == .institutionAccountId, "\(label): identifier kind")
        expectSourceFact(document.financialIdentifiers.first?.verificationState == .verified, "\(label): identifier verification")
        expectSourceFact(document.financialIdentifiers.first.map { sha256(Data($0.normalizedValue.utf8)) } == carrier.accountIdentifierSha256,
                "\(label): identifier")

        let expectedProfile: (String, String)
        switch carrier.format {
        case "csv": expectedProfile = (AxisBankAccountParser.profileID, AxisBankAccountParser.profileVersion)
        case "pdf": expectedProfile = (AxisBankAccountPDFParser.profileID, AxisBankAccountPDFParser.profileVersion)
        case "xls": expectedProfile = (AxisBankAccountXLSParser.profileID, AxisBankAccountXLSParser.profileVersion)
        default: throw AxisBankAuthenticAcceptanceError.unsupportedFormat
        }

        for (index, pair) in zip(document.transactions, carrier.rows).enumerated() {
            let transaction = pair.0
            let row = pair.1
            let rowLabel = "\(label): event \(index + 1)"
            expectSourceFact(row.sourceOrder == index + 1, "\(rowLabel): oracle order")
            expectSourceFact(transaction.statementDate?.canonical == row.date, "\(rowLabel): date")
            expectSourceFact(transaction.valueDate == nil, "\(rowLabel): absent value date")
            expectSourceFact(transaction.money.amount == decimal(row.signedAmount), "\(rowLabel): signed Money")
            expectSourceFact(transaction.runningBalanceMoney?.amount == decimal(row.balance), "\(rowLabel): balance")
            expectSourceFact(direction(transaction) == row.direction, "\(rowLabel): direction")
            expectSourceFact(transaction.money.currency.code == "INR", "\(rowLabel): currency")
            expectSourceFact(transaction.runningBalanceMoney?.currency.code == "INR", "\(rowLabel): balance currency")
            expectSourceFact(transaction.reference.map { sha256(Data($0.utf8)) } == row.chequeReferenceSha256,
                    "\(rowLabel): reference")
            expectSourceFact(sha256(Data(collapse(transaction.description).utf8)) == row.descriptionSha256,
                    "\(rowLabel): complete source narration")
            expectSourceFact(transaction.verifiedAxisUPIEventEvidence?.operation.rawValue == row.upiOperation,
                    "\(rowLabel): UPI operation")
            expectSourceFact(transaction.verifiedAxisUPIEventEvidence?.reference == row.upiReference,
                    "\(rowLabel): UPI reference value")
            expectSourceFact(transaction.verifiedAxisUPIEventEvidence.map { sha256(Data($0.reference.utf8)) } == row.upiReferenceSha256,
                    "\(rowLabel): UPI reference")
            expectSourceFact(transaction.verifiedAxisUPIEventEvidence?.subtype.rawValue == row.upiSubtype,
                    "\(rowLabel): UPI subtype")
            expectSourceFact(transaction.sourceProvenance.count == 1, "\(rowLabel): provenance cardinality")
            let provenance = try #require(transaction.sourceProvenance.first)
            expectSourceFact(provenance.parserProfileID == expectedProfile.0, "\(rowLabel): profile")
            expectSourceFact(provenance.parserProfileVersion == expectedProfile.1, "\(rowLabel): profile version")
            expectSourceFact(provenance.structuredReferenceDigest == row.chequeReferenceSha256,
                    "\(rowLabel): reference digest")
            expectSourceFact(isLowercaseSHA256(provenance.normalizedRecordDigest), "\(rowLabel): row digest")
            if carrier.format == "pdf" {
                expectSourceFact(provenance.sourcePage == row.sourcePage, "\(rowLabel): page")
            } else {
                expectSourceFact(provenance.sourcePage == nil, "\(rowLabel): no tabular page")
                expectSourceFact(provenance.sourceOrdinal == row.sourceOrdinal, "\(rowLabel): physical source ordinal")
            }
        }

        let ordinals = document.transactions.compactMap { $0.sourceProvenance.first?.sourceOrdinal }
        expectSourceFact(ordinals.count == carrier.rows.count, "\(label): complete ordinals")
        expectSourceFact(zip(ordinals, ordinals.dropFirst()).allSatisfy(<), "\(label): source order")
        if carrier.format == "pdf" {
            let pages = document.transactions.compactMap { $0.sourceProvenance.first?.sourcePage }
            expectSourceFact(pages.count == carrier.rows.count, "\(label): complete pages")
            expectSourceFact(pages.allSatisfy { (1...(carrier.pageCount ?? 0)).contains($0) }, "\(label): page range")
        } else {
            expectSourceFact(carrier.headerSourceOrdinal.map { $0 + 1 } == carrier.rows.first?.sourceOrdinal,
                    "\(label): first transaction source ordinal")
        }

        let evidence = try #require(document.sourceStatementEvidence)
        expectSourceFact(evidence.sourceFormatCode == carrier.format)
        expectSourceFact(evidence.period?.start.canonical == carrier.periodStart)
        expectSourceFact(evidence.period?.end.canonical == carrier.periodEnd)
        if carrier.format == "pdf" {
            expectSourceFact(evidence.openingBalance?.amount == decimal(carrier.controls.openingBalance), "\(label): printed opening")
            expectSourceFact(evidence.closingBalance?.amount == decimal(carrier.controls.closingBalance), "\(label): printed closing")
            expectSourceFact(evidence.printedControls.count == 4, "\(label): all printed controls")
            expectSourceFact(Dictionary(evidence.printedControls.map { ($0.kind.rawValue, $0.literal) }, uniquingKeysWith: { first, _ in first }) == carrier.controls.printedLiterals,
                    "\(label): literal control text")
            expectSourceFact(evidence.printedControls.allSatisfy {
                $0.sourceUnit == .line && $0.sourceOrdinal > 0 && $0.sourcePage == nil
            }, "\(label): truthful control locations")
        } else {
            expectSourceFact(evidence.openingBalance == nil && evidence.closingBalance == nil,
                    "\(label): absent printed controls are not inferred from rows")
            expectSourceFact(evidence.printedControls.isEmpty)
        }
    }

    private func verifyPersistedCampaign(
        _ provider: DatabaseProvider,
        workspaceID: String,
        oracle: Oracle,
        evidence: CampaignEvidence
    ) throws {
        let accounts = try provider.accountRepo.accounts(workspaceId: workspaceID)
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
        let projections = try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspaceID)
        let groups = try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceID)
        let members = try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceID)

        expectSourceFact(accounts.count == 2)
        expectSourceFact(transactions.count == oracle.corpus.canonicalEventCount)
        expectSourceFact(projections.count == oracle.corpus.logicalStatementCount)
        expectSourceFact(groups.count == oracle.corpus.logicalStatementCount)
        expectSourceFact(members.count == oracle.corpus.logicalStatementCount)
        expectSourceFact(members.filter { $0.role == .authoritative }.count == oracle.corpus.logicalStatementCount)
        expectSourceFact(members.allSatisfy { $0.role == .authoritative })
        expectSourceFact(Set(projections.map(\.importSessionID)) == evidence.authoritativeImportSessionIDs)

        let accountIDs = Set(accounts.map(\.id))
        var identifierDigests = Set<String>()
        for account in accounts {
            let identifiers = try provider.accountRepo.identifiers(
                accountId: account.id,
                workspaceId: workspaceID
            ).filter { $0.scheme == FinancialIdentifierKind.institutionAccountId.rawValue }
            expectSourceFact(identifiers.count == 1, "one source-proven identifier per Axis account")
            if let identifier = identifiers.first {
                identifierDigests.insert(sha256(Data(identifier.identifier.utf8)))
            }
        }
        expectSourceFact(identifierDigests == Set(oracle.carriers.map(\.accountIdentifierSha256)))

        guard Set(projections.map { $0.projection.id }).count == projections.count else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        let projectionByID = Dictionary(uniqueKeysWithValues: projections.map { ($0.projection.id, $0) })
        for record in projections {
            let carrier = try #require(evidence.carrierByImportSessionID[record.importSessionID])
            let label = privacySafeLabel(carrier)
            let projection = record.projection
            let controls = try projectionControls(carrier)
            expectSourceFact(projection.isValid(), "\(label): durable projection validity")
            expectSourceFact(projection.algorithmIdentifier == StatementFinancialProjectionDTO.axisAlgorithm,
                    "\(label): distinct Axis projection algorithm")
            expectSourceFact(record.workspaceID == workspaceID, "\(label): projection workspace")
            expectSourceFact(record.accountID == evidence.accountIDBySourceDigest[carrier.sourceSha256],
                    "\(label): projection account")
            expectSourceFact(accountIDs.contains(record.accountID), "\(label): available projection account")
            expectSourceFact(projection.institutionCode == StatementFinancialProjection.axisInstitutionCode)
            expectSourceFact(projection.statementFamilyCode == StatementFinancialProjection.axisBankAccountFamilyCode)
            let expectedProfile = try profile(for: carrier)
            expectSourceFact(projection.parserProfileID == expectedProfile.0, "\(label): projection profile")
            expectSourceFact(projection.parserProfileVersion == expectedProfile.1, "\(label): projection version")
            expectSourceFact(projection.sourceFormatCode == carrier.format, "\(label): source format")
            expectSourceFact(projection.statementStartDateISO == carrier.periodStart, "\(label): period start")
            expectSourceFact(projection.statementEndDateISO == carrier.periodEnd, "\(label): period end")
            expectSourceFact(projection.nativeCurrency == "INR", "\(label): native currency")
            expectSourceFact(projection.eventCount == carrier.rowCount, "\(label): event multiplicity")
            expectSourceFact(projection.openingBalanceMinor == (try minorUnits(controls.openingBalance)))
            expectSourceFact(decimal(projection.openingBalanceDecimal) == decimal(controls.openingBalance))
            expectSourceFact(projection.debitTotalMinor == (try minorUnits(controls.debitTotal)))
            expectSourceFact(decimal(projection.debitTotalDecimal) == decimal(controls.debitTotal))
            expectSourceFact(projection.creditTotalMinor == (try minorUnits(controls.creditTotal)))
            expectSourceFact(decimal(projection.creditTotalDecimal) == decimal(controls.creditTotal))
            expectSourceFact(projection.closingBalanceMinor == (try minorUnits(controls.closingBalance)))
            expectSourceFact(decimal(projection.closingBalanceDecimal) == decimal(controls.closingBalance))
            for (event, row) in zip(projection.events, carrier.rows) {
                expectSourceFact(event.ordinal == row.sourceOrder, "\(label): projection order")
                expectSourceFact(event.statementDateISO == row.date, "\(label): projection date")
                expectSourceFact(event.valueDateISO == nil, "\(label): authentic absent value date")
                expectSourceFact(event.direction == row.direction, "\(label): projection direction")
                expectSourceFact(event.signedAmountMinor == (try minorUnits(row.signedAmount)), "\(label): projection Money")
                expectSourceFact(decimal(event.signedAmountDecimal) == decimal(row.signedAmount),
                        "\(label): projection Money decimal")
                expectSourceFact(event.runningBalanceMinor == (try minorUnits(row.balance)), "\(label): projection balance")
                expectSourceFact(decimal(event.runningBalanceDecimal) == decimal(row.balance),
                        "\(label): projection balance decimal")
                expectSourceFact(event.reference.map { sha256(Data($0.utf8)) } == row.chequeReferenceSha256,
                        "\(label): source-owned cheque/reference")
            }
        }

        for carrierGroup in Dictionary(grouping: oracle.carriers, by: \.logicalStatementId).values {
            let records = projections.filter { record in
                evidence.carrierByImportSessionID[record.importSessionID]?.logicalStatementId == carrierGroup[0].logicalStatementId
            }
            expectSourceFact(records.count == 1,
                    "\(privacySafeLabel(carrierGroup[0])): original authority projection remains unchanged")
        }

        for group in groups {
            let groupMembers = members.filter { $0.groupID == group.id }
            expectSourceFact(groupMembers.count == 1)
            expectSourceFact(group.projectionAlgorithm == StatementFinancialProjectionDTO.axisAlgorithm)
            expectSourceFact(accountIDs.contains(group.accountID))
            let authorityMembers = groupMembers.filter { $0.role == .authoritative }
            expectSourceFact(authorityMembers.count == 1)
            expectSourceFact(authorityMembers.first?.projectionID == group.authoritativeProjectionID)
            for member in groupMembers {
                let record = try #require(projectionByID[member.projectionID])
                let carrier = try #require(evidence.carrierByImportSessionID[record.importSessionID])
                expectSourceFact(record.accountID == group.accountID)
                expectSourceFact(record.projection.digest == group.projectionDigest)
                expectSourceFact(member.sourceFormatCode == carrier.format)
                expectSourceFact(member.role == (evidence.authoritativeImportSessionIDs.contains(record.importSessionID)
                    ? .authoritative : .supporting))
            }
        }

        let transactionIDs = Set(transactions.map(\.id))
        try verifyBankOccurrenceEvidence(provider, workspaceID: workspaceID, oracle: oracle, evidence: evidence)
        for importSessionID in evidence.authoritativeImportSessionIDs {
            let carrier = try #require(evidence.carrierByImportSessionID[importSessionID])
            let label = privacySafeLabel(carrier)
            let expectedProfile = try profile(for: carrier)
            let sourceTransactions = transactions
                .filter { $0.importSessionId == importSessionID }
                .sorted {
                    ($0.rawRows.first?.sourceOrdinal ?? Int.max) <
                        ($1.rawRows.first?.sourceOrdinal ?? Int.max)
                }
            expectSourceFact(sourceTransactions.count == carrier.rowCount, "\(label): canonical source ownership")
            for (transaction, row) in zip(sourceTransactions, carrier.rows) {
                expectSourceFact(transaction.accountId == evidence.accountIDBySourceDigest[carrier.sourceSha256])
                expectSourceFact(transaction.valueDateISO == nil, "\(label): persisted absent value date")
                expectSourceFact(transaction.postedDateISO == row.date, "\(label): persisted date")
                expectSourceFact(transaction.direction == row.direction, "\(label): persisted direction")
                expectSourceFact(transaction.nativeCurrency == "INR", "\(label): persisted currency")
                expectSourceFact(transaction.amountMinor == (try minorUnits(row.signedAmount)), "\(label): persisted Money")
                expectSourceFact(decimal(transaction.amountDecimal) == decimal(row.signedAmount),
                        "\(label): persisted Money decimal")
                expectSourceFact(transaction.runningBalanceMinor == (try minorUnits(row.balance)),
                        "\(label): persisted balance")
                expectSourceFact(transaction.reference.map { sha256(Data($0.utf8)) } == row.chequeReferenceSha256,
                        "\(label): persisted reference")
                expectSourceFact(transaction.description.map { sha256(Data(collapse($0).utf8)) } == row.descriptionSha256,
                        "\(label): complete persisted source narration")
                expectSourceFact(transaction.rawRows.count == 1, "\(label): normalized row provenance")
                let raw = try #require(transaction.rawRows.first)
                if carrier.format == "pdf" {
                    expectSourceFact((raw.sourceOrdinal ?? 0) > 0, "\(label): PDF physical source order")
                } else {
                    expectSourceFact(raw.sourceOrdinal == row.sourceOrdinal, "\(label): physical source ordinal")
                }
                expectSourceFact(raw.parserProfileId == expectedProfile.0, "\(label): persisted profile")
                expectSourceFact(raw.parserProfileVersion == expectedProfile.1, "\(label): persisted profile version")
                expectSourceFact(raw.normalizedRecordDigest.map(isLowercaseSHA256) == true,
                        "\(label): persisted row digest")
            }
            let sourceOrdinals = sourceTransactions.compactMap { $0.rawRows.first?.sourceOrdinal }
            expectSourceFact(sourceOrdinals.count == carrier.rowCount, "\(label): complete persisted source order")
            expectSourceFact(zip(sourceOrdinals, sourceOrdinals.dropFirst()).allSatisfy(<),
                    "\(label): strictly increasing persisted source order")
        }

        var ownerSessionByEventKey: [TransactionEventIdentityKeyDTO: String] = [:]
        for (importSessionID, keys) in evidence.eventKeysByImportSessionID {
            for key in keys {
                guard ownerSessionByEventKey.updateValue(importSessionID, forKey: key) == nil else {
                    throw AxisBankAuthenticAcceptanceError.campaignInvariant
                }
            }
        }
        expectSourceFact(ownerSessionByEventKey.count == 120, "complete eligible ADR-031 authentic set")
        let owners = try provider.importSessionRepo.transactionEventOwners(
            keys: Set(ownerSessionByEventKey.keys)
        )
        expectSourceFact(owners.count == ownerSessionByEventKey.count, "all ADR-031 digests remain durable")
        for (key, expectedImportSessionID) in ownerSessionByEventKey {
            let owner = try #require(owners[key])
            let carrier = try #require(evidence.carrierByImportSessionID[expectedImportSessionID])
            expectSourceFact(owner.importSessionId == expectedImportSessionID)
            expectSourceFact(owner.accountId == evidence.accountIDBySourceDigest[carrier.sourceSha256])
            expectSourceFact(transactionIDs.contains(owner.transactionId))
        }

        let canonicalCarriers = oracle.carriers.reduce(into: [String: Carrier]()) { result, carrier in
            if result[carrier.logicalStatementId] == nil { result[carrier.logicalStatementId] = carrier }
        }.values
        var subtypeSetsByPrivateReference: [String: Set<String>] = [:]
        for carrier in canonicalCarriers {
            for row in carrier.rows where row.upiReference != nil {
                let privateKey = "\(carrier.accountIdentifierSha256)|\(row.upiReference!)"
                subtypeSetsByPrivateReference[privateKey, default: []].insert(try #require(row.upiSubtype))
            }
        }
        expectSourceFact(subtypeSetsByPrivateReference.values.filter { $0.count > 1 }.count == 2,
                "authentic reused references remain distinct through subtype")
    }

    private func verifyBankOccurrenceEvidence(
        _ provider: DatabaseProvider,
        workspaceID: String,
        oracle: Oracle,
        evidence: CampaignEvidence
    ) throws {
        let graph = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: workspaceID)
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
        expectSourceFact(graph.sections.count == oracle.carriers.count)
        expectSourceFact(graph.sections.reduce(0) { $0 + $1.rows.count } == oracle.corpus.representationRowCount)
        expectSourceFact(Set(graph.sections.map(\.importSessionId)) == Set(evidence.carrierByImportSessionID.keys))
        for section in graph.sections {
            let carrier = try #require(evidence.carrierByImportSessionID[section.importSessionId])
            let label = privacySafeLabel(carrier)
            let authoritySession = try #require(evidence.authoritativeImportSessionIDs.first {
                evidence.carrierByImportSessionID[$0]?.logicalStatementId == carrier.logicalStatementId
            })
            let authority = try #require(evidence.carrierByImportSessionID[authoritySession])
            let canonical = transactions.filter { $0.importSessionId == authoritySession }.sorted {
                ($0.rawRows.first?.sourceOrdinal ?? Int.max) < ($1.rawRows.first?.sourceOrdinal ?? Int.max)
            }
            guard canonical.count == authority.rows.count else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }
            let targetByCorrespondence = Dictionary(uniqueKeysWithValues: zip(authority.rows, canonical).map {
                ($0.0.correspondenceOrder, $0.1.id)
            })
            expectSourceFact(section.rows.count == carrier.rows.count, "\(label): source occurrence multiplicity")
            expectSourceFact(section.accountId == evidence.accountIDBySourceDigest[carrier.sourceSha256])
            expectSourceFact(section.nativeCurrency == "INR")
            expectSourceFact(section.sourceEvidence.sourceFormatCode == carrier.format)
            expectSourceFact(section.sourceEvidence.statementStartDateISO == carrier.periodStart)
            expectSourceFact(section.sourceEvidence.statementEndDateISO == carrier.periodEnd)
            if carrier.format == "pdf" {
                expectSourceFact(section.sourceEvidence.openingBalanceDecimal.map(decimal) == decimal(carrier.controls.openingBalance))
                expectSourceFact(section.sourceEvidence.closingBalanceDecimal.map(decimal) == decimal(carrier.controls.closingBalance))
                let details = try #require(section.sourceDetails)
                expectSourceFact(details.controls.count == 4)
                expectSourceFact(Dictionary(details.controls.map { ($0.kind, $0.literal) }, uniquingKeysWith: { first, _ in first }) == carrier.controls.printedLiterals,
                        "\(label): persisted literal controls")
                expectSourceFact(details.controls.allSatisfy {
                    $0.sourceUnit == "line" && $0.sourceOrdinal > 0 && $0.sourcePage == nil
                })
            } else {
                expectSourceFact(section.sourceEvidence.openingBalanceDecimal == nil && section.sourceEvidence.closingBalanceDecimal == nil)
                expectSourceFact(section.sourceDetails == nil)
            }
            let targets = section.rows.map { $0.source.incomingTransactionId }
            expectSourceFact(Set(targets).count == carrier.rows.count)
            expectSourceFact(Set(targets) == Set(targetByCorrespondence.values), "\(label): complete canonical occurrence bijection")
            let ordinals = section.rows.map(\.sourceOrdinal)
            expectSourceFact(ordinals.count == carrier.rowCount && zip(ordinals, ordinals.dropFirst()).allSatisfy(<))
            for (occurrence, row) in zip(section.rows, carrier.rows) {
                // Compare each representation in its own original order. The
                // independently observed correspondence selects its target.
                expectSourceFact(occurrence.source.incomingTransactionId == targetByCorrespondence[row.correspondenceOrder],
                        "\(label): source-proven canonical target")
                expectSourceFact(occurrence.source.postingDateISO == row.date)
                expectSourceFact(occurrence.valueDateISO == nil)
                expectSourceFact(occurrence.source.direction == row.direction)
                expectSourceFact(decimal(occurrence.source.signedAmountDecimal) == decimal(row.signedAmount))
                expectSourceFact(decimal(occurrence.source.runningBalanceDecimal) == decimal(row.balance))
                expectSourceFact(try Self.directRequiredDecimal(occurrence.literalBalance) == decimal(row.balance))
                expectSourceFact(sha256(Data(collapse(occurrence.literalNarration).utf8)) == row.descriptionSha256)
                expectSourceFact(occurrence.literalReference.map { sha256(Data($0.utf8)) } == row.chequeReferenceSha256)
                if carrier.format == "pdf" {
                    expectSourceFact(occurrence.sourceOrdinal > 0)
                } else {
                    expectSourceFact(occurrence.sourceOrdinal == row.sourceOrdinal)
                }
            }
        }
    }

    private func verifyHydratedSnapshot(
        _ snapshot: RepositoryRuntimeSnapshot,
        oracle: Oracle,
        evidence: CampaignEvidence
    ) throws {
        expectSourceFact(snapshot.accounts.count == 2)
        expectSourceFact(snapshot.transactions.count == oracle.corpus.canonicalEventCount)
        expectSourceFact(snapshot.importSessions.count == oracle.carriers.count)
        expectSourceFact(snapshot.hydrationResult.didHydrate)
        expectSourceFact(snapshot.hydrationResult.accountCount == 2)
        expectSourceFact(snapshot.hydrationResult.transactionCount == oracle.corpus.canonicalEventCount)
        expectSourceFact(snapshot.hydrationResult.importSessionCount == oracle.carriers.count)
        expectSourceFact(snapshot.transactions.allSatisfy { $0.valueDate == nil })
        // ADR-031 persists only the privacy-safe owner digest. Hydration must
        // not reconstruct typed UPI evidence from retained narration.
        expectSourceFact(snapshot.transactions.allSatisfy { $0.verifiedAxisUPIEventEvidence == nil })

        for importSessionID in evidence.authoritativeImportSessionIDs {
            let carrier = try #require(evidence.carrierByImportSessionID[importSessionID])
            let expectedProfile = try profile(for: carrier)
            let transactions = snapshot.transactions
                .filter { $0.repositoryImportSessionId == importSessionID }
                .sorted {
                    ($0.sourceProvenance.first?.sourceOrdinal ?? Int.max) <
                        ($1.sourceProvenance.first?.sourceOrdinal ?? Int.max)
                }
            expectSourceFact(transactions.count == carrier.rowCount)
            for (transaction, row) in zip(transactions, carrier.rows) {
                expectSourceFact(transaction.statementDate?.canonical == row.date)
                expectSourceFact(sha256(Data(collapse(transaction.description).utf8)) == row.descriptionSha256,
                        "Complete authoritative source narration survives hydration")
                expectSourceFact(transaction.money.amount == decimal(row.signedAmount))
                expectSourceFact(transaction.runningBalanceMoney?.amount == decimal(row.balance))
                expectSourceFact(direction(transaction) == row.direction)
                expectSourceFact(transaction.reference.map { sha256(Data($0.utf8)) } == row.chequeReferenceSha256)
                expectSourceFact(transaction.sourceProvenance.count == 1)
                let provenance = try #require(transaction.sourceProvenance.first)
                if carrier.format == "pdf" {
                    expectSourceFact(provenance.sourceOrdinal > 0)
                } else {
                    expectSourceFact(provenance.sourceOrdinal == row.sourceOrdinal)
                }
                expectSourceFact(provenance.parserProfileID == expectedProfile.0)
                expectSourceFact(provenance.parserProfileVersion == expectedProfile.1)
                expectSourceFact(provenance.normalizedRecordDigest.isEmpty == false)
            }
            let sourceOrdinals = transactions.compactMap { $0.sourceProvenance.first?.sourceOrdinal }
            expectSourceFact(sourceOrdinals.count == carrier.rowCount)
            expectSourceFact(zip(sourceOrdinals, sourceOrdinals.dropFirst()).allSatisfy(<))
        }
    }

    private func verifyNoFinancialResidue(
        _ provider: DatabaseProvider,
        workspaceID: String
    ) throws {
        expectSourceFact(try provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
        expectSourceFact(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
        expectSourceFact(try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspaceID).isEmpty)
        expectSourceFact(try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceID).isEmpty)
        expectSourceFact(try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceID).isEmpty)
        expectSourceFact(try provider.importSessionRepo.bankSectionSnapshot(workspaceId: workspaceID).sections.isEmpty)
    }

    private func financialRepositoryCounts(
        _ provider: DatabaseProvider,
        workspaceID: String
    ) throws -> [Int] {
        let bank = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: workspaceID)
        return [
            try provider.accountRepo.accounts(workspaceId: workspaceID).count,
            try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count,
            try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspaceID).count,
            try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceID).count,
            try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceID).count,
            bank.sections.count,
            bank.sections.reduce(0) { $0 + $1.rows.count }
        ]
    }

    private func profile(for carrier: Carrier) throws -> (String, String) {
        switch carrier.format {
        case "csv": return (AxisBankAccountParser.profileID, AxisBankAccountParser.profileVersion)
        case "pdf": return (AxisBankAccountPDFParser.profileID, AxisBankAccountPDFParser.profileVersion)
        case "xls": return (AxisBankAccountXLSParser.profileID, AxisBankAccountXLSParser.profileVersion)
        default: throw AxisBankAuthenticAcceptanceError.unsupportedFormat
        }
    }

    private func adr031EventKey(
        row: Row,
        resolvedAccountID: String
    ) throws -> TransactionEventIdentityKeyDTO? {
        let components = (row.upiOperation, row.upiReference, row.upiReferenceSha256, row.upiSubtype)
        if components == (nil, nil, nil, nil) { return nil }
        guard !resolvedAccountID.isEmpty,
              let operation = row.upiOperation,
              let reference = row.upiReference,
              let referenceDigest = row.upiReferenceSha256,
              let subtype = row.upiSubtype,
              ["p2a", "p2m"].contains(operation),
              reference.utf8.count == 12,
              reference.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }),
              sha256(Data(reference.utf8)) == referenceDigest,
              ["posting", "credit-adjustment"].contains(subtype) else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        let algorithm = "ledgerforge.transaction-event.axis-upi-reference.v1"
        let fields = [algorithm, resolvedAccountID, "axis-upi", operation, reference, subtype]
        let payload = fields.map { "\($0.utf8.count):\($0)" }.joined()
        return TransactionEventIdentityKeyDTO(
            algorithm: algorithm,
            digest: sha256(Data(payload.utf8))
        )
    }

    private func minorUnits(_ value: String) throws -> Int64 {
        try Money(
            amount: decimal(value),
            currency: CurrencyCode("INR")
        ).minorUnits()
    }

    private func projectionControls(_ carrier: Carrier) throws -> Controls {
        let first = try #require(carrier.rows.first)
        let last = try #require(carrier.rows.last)
        let debit = carrier.rows.reduce(Decimal.zero) { $0 + max(-decimal($1.signedAmount), .zero) }
        let credit = carrier.rows.reduce(Decimal.zero) { $0 + max(decimal($1.signedAmount), .zero) }
        // Persisted v1 projection fields remain the original row-derived
        // definition. Literal printed controls are asserted separately.
        return Controls(
            openingBalance: Self.directCanonicalDecimal(decimal(first.balance) - decimal(first.signedAmount)),
            closingBalance: last.balance,
            debitTotal: Self.directCanonicalDecimal(debit),
            creditTotal: Self.directCanonicalDecimal(credit)
        )
    }

    private func direction(_ transaction: Transaction) -> String {
        switch (transaction.debitMoney, transaction.creditMoney) {
        case (.some, nil): "debit"
        case (nil, .some): "credit"
        default: "invalid"
        }
    }

    private func makeRuntime(provider: DatabaseProvider, workspaceID: String) -> Runtime {
        let accountStore = AccountStore()
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let importAttemptStore = ImportAttemptStore()
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo,
            accountStore: accountStore,
            transactionStore: transactionStore,
            categoryStore: CategoryStore(),
            cardStore: CardStore(),
            importSessionStore: importSessionStore,
            importAttemptStore: importAttemptStore,
            workspaceId: workspaceID,
            persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken,
            participatesInLifecycleGate: false
        )
        let engine = ImportEngine(
            importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry()),
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(
                databaseProvider: provider,
                mapper: ImportPersistenceMapper(
                    workspaceId: workspaceID,
                    workspaceName: "Axis Bank authentic acceptance"
                )
            ),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) },
            rejectedAttemptHydration: {},
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(
                stateProvider: { nil }
            )
        )
        return Runtime(
            provider: provider,
            engine: engine,
            hydrator: hydrator,
            accountStore: accountStore,
            transactionStore: transactionStore,
            importSessionStore: importSessionStore,
            importAttemptStore: importAttemptStore
        )
    }

    private func makeEngine(provider: DatabaseProvider, workspaceID: String) -> ImportEngine {
        makeRuntime(provider: provider, workspaceID: workspaceID).engine
    }

    private static func directUniqueBalanceMapping(
        _ rows: [DirectUnresolvedCSVRow]
    ) throws -> DirectBalanceMapping {
        guard !rows.isEmpty else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }

        let supported = DirectBalanceMapping.allCases.filter { mapping in
            var priorBalance: Decimal?

            for row in rows {
                guard let signed = try? row.signedAmount(using: mapping) else {
                    return false
                }

                if let priorBalance, priorBalance + signed != row.balance {
                    return false
                }

                // The first row establishes the prior state for the second row.
                // Its opening balance is derived later as `balance - signed`.
                priorBalance = row.balance
            }
            return true
        }

        guard supported.count == 1, let mapping = supported.first else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        return mapping
    }

    /// Share only the original carrier metadata needed by the existing mixed
    /// queue test; its expectations still come from the complete source oracle.
    static func sourceMetadataForMixedBatch(csvURL: URL) throws -> (
        sha256: String, byteCount: Int, logicalStatementID: String, rowCount: Int
    ) {
        let oracle = try loadOracle(root: csvURL.deletingLastPathComponent())
        let data = try Data(contentsOf: csvURL, options: .mappedIfSafe)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let matches = oracle.carriers.filter { $0.sourceSha256 == digest }
        guard matches.count == 1, let carrier = matches.first,
              carrier.format.lowercased() == "csv", carrier.sourceSize == data.count else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        return (digest, data.count, "axis|\(carrier.logicalStatementId)", carrier.rowCount)
    }

    func standaloneComparisonsForRelationshipCampaign(root: URL) throws -> [AuthenticStandaloneBankComparison] {
        let oracle = try Self.loadOracle(root: root)
        let sources = try sourceURLsByDigest(root: root)
        return try oracle.carriers.map { carrier in
            let pdf = try #require(oracle.carriers.first { $0.format == "pdf" && $0.logicalStatementId == carrier.logicalStatementId })
            return AuthenticStandaloneBankComparison(url: try #require(sources[carrier.sourceSha256]),
                sha256: carrier.sourceSha256, equivalentPDFSHA: pdf.sourceSha256, rowCount: carrier.rowCount,
                compare: { prepared in
                    let bytesMatch = try prepared.sourceSnapshot.withBytes(sha256) == carrier.sourceSha256
                    #expect(bytesMatch)
                    try verify(prepared: prepared, against: carrier)
                })
        }
    }

    private static func loadOracle(root: URL) throws -> Oracle {
        let files = try directAxisFiles(root: root)
        let csvStatements = try files
            .filter { $0.format == "csv" }
            .map(directCSVStatement)

        guard csvStatements.count == 3 else {
            throw AxisBankAuthenticAcceptanceError.corpusUnavailable
        }

        let csvByKey = Dictionary(
            uniqueKeysWithValues: csvStatements.map { ($0.key, $0) }
        )

        var carriers = csvStatements.map { statement in
            statement.carrier(
                source: statement.source,
                pages: [:],
                sourceOrdinals: Dictionary(
                    uniqueKeysWithValues: statement.rows.map {
                        ($0.sourceOrder, $0.sourceOrdinal)
                    }
                ),
                headerSourceOrdinal: statement.headerSourceOrdinal
            )
        }

        for source in files where source.format == "pdf" {
            let pdf = try directPDFEvidence(source)
            guard let csv = csvByKey[pdf.key] else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }

            let pdfRows = try directPDFRows(source, expected: csv.rows)
            let pages = pdfRows.pages
            guard pages.count == pdfRows.rows.count else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }

            carriers.append(
                csv.carrier(
                    source: source,
                    pages: pages,
                    sourceOrdinals: [:],
                    headerSourceOrdinal: nil,
                    sourceRows: pdfRows.rows,
                    sourceControls: pdfRows.controls,
                    correspondenceOrdinals: pdfRows.correspondence
                )
            )
        }

        for source in files where source.format == "xls" {
            let grid = try directXLSGrid(source.bytes)
            let xls = try directXLSEvidence(grid)
            let matches = csvStatements.filter { $0.key.accountDigest == xls.key.accountDigest && $0.key.periodStart == xls.key.periodStart && $0.key.periodEnd == xls.key.periodEnd }
            guard matches.count == 1, let csv = matches.first, csv.key.currency == "INR" else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }

            let observed = try directXLSRows(
                grid: grid,
                headerRow: xls.headerRow
            )
            let rows = observed.enumerated().map { index, row in
                DirectSourceRow(sourceOrder: index + 1, sourceOrdinal: row.physicalRow + 1,
                    date: row.date, direction: row.direction, signedAmount: row.signedAmount,
                    balance: row.balance, description: row.description, reference: row.reference,
                    upi: directUPI(narration: row.description, direction: row.direction))
            }
            let correspondence = try directUniqueCorrespondence(expected: csv.rows, observed: rows) { left, right in
                left.representationFingerprint == right.representationFingerprint
            }

            carriers.append(
                csv.carrier(
                    source: source,
                    pages: [:],
                    sourceOrdinals: [:],
                    headerSourceOrdinal: xls.headerRow + 1,
                    sourceRows: rows,
                    sourceControls: try directRowControls(rows),
                    correspondenceOrdinals: correspondence
                )
            )
        }

        guard carriers.count == 9,
              Set(carriers.map(\.sourceSha256)).count == 9 else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }

        let groups = Dictionary(grouping: carriers, by: \.logicalStatementId)
        guard groups.count == 3,
              groups.values.allSatisfy({
                  $0.count == 3 &&
                  Set($0.map(\.format)) == Set(["csv", "pdf", "xls"])
              }) else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }

        let canonicalCount = csvStatements.reduce(0) { $0 + $1.rows.count }
        let inventoryEntries = carriers
            .sorted { $0.sourceSha256 < $1.sourceSha256 }
            .map { "\($0.sourceSha256)|\($0.sourceSize)|\($0.format)" }
            .joined(separator: "\n")

        // v2: UTF-8 version line, followed by digest|decimal-byte-count|lowercase-format
        // records sorted by lowercase SHA-256, with LF after every line.
        let inventory = "ledgerforge.axis-bank.authentic-source-inventory.v2\n" + inventoryEntries + "\n"
        let inventoryDigest = directSHA256(Data(inventory.utf8))
        guard inventoryDigest == "022bab027d5e158291ad445a673d40df141f3d5b726decd23aff60d37c6dec2d" else {
            throw AxisBankAuthenticAcceptanceError.corpusUnavailable
        }

        return Oracle(
            schema: "ledgerforge.axis-bank.source-oracle.v1",
            sourceInventorySha256: inventoryDigest,
            corpus: Corpus(
                carrierCount: carriers.count,
                logicalStatementCount: groups.count,
                canonicalEventCount: canonicalCount,
                representationRowCount: carriers.reduce(0) { $0 + $1.rows.count },
                formatCounts: Dictionary(grouping: carriers, by: \.format)
                    .mapValues(\.count),
                pageCounts: carriers.compactMap(\.pageCount).sorted()
            ),
            carriers: carriers.sorted {
                ($0.logicalStatementId, $0.format, $0.sourceSha256) <
                ($1.logicalStatementId, $1.format, $1.sourceSha256)
            }
        )
    }

    private struct DirectAxisFile {
        let url: URL
        let bytes: Data
        let format: String

        var digest: String { directSHA256(bytes) }
        var size: Int { bytes.count }
    }

    private struct DirectStatementKey: Hashable {
        let accountDigest: String
        let periodStart: String
        let periodEnd: String
        let currency: String

        var logicalStatementID: String {
            directSHA256(Data(
                [accountDigest, periodStart, periodEnd, currency]
                    .joined(separator: "|")
                    .utf8
            ))
        }
    }

    private struct DirectUPI: Equatable {
        let operation: String
        let reference: String
        let subtype: String
    }

    private struct DirectSourceRow {
        let sourceOrder: Int
        let sourceOrdinal: Int
        let date: String
        let direction: String
        let signedAmount: String
        let balance: String
        let description: String
        let reference: String?
        let upi: DirectUPI?

        var signedDecimal: Decimal {
            Decimal(
                string: signedAmount,
                locale: Locale(identifier: "en_US_POSIX")
            )!
        }

        func oracleRow(sourcePage: Int?, sourceOrdinal: Int, correspondenceOrder: Int) -> Row {
            Row(
                sourceOrder: sourceOrder,
                correspondenceOrder: correspondenceOrder,
                sourceOrdinal: sourceOrdinal,
                sourcePage: sourcePage,
                date: date,
                direction: direction,
                signedAmount: signedAmount,
                balance: balance,
                descriptionSha256: directSHA256(Data(directCollapse(description).utf8)),
                chequeReferenceSha256: reference.map { directSHA256(Data($0.utf8)) },
                upiOperation: upi?.operation,
                upiReference: upi?.reference,
                upiReferenceSha256: upi.map { directSHA256(Data($0.reference.utf8)) },
                upiSubtype: upi?.subtype
            )
        }

        var representationFingerprint: String {
            [
                date,
                direction,
                signedAmount,
                directCollapse(description),
                reference ?? ""
            ].joined(separator: "|")
        }
    }

    private struct DirectCSVStatement {
        let source: DirectAxisFile
        let key: DirectStatementKey
        let headerSourceOrdinal: Int
        let rows: [DirectSourceRow]
        let controls: Controls

        func carrier(
            source: DirectAxisFile,
            pages: [Int: Int],
            sourceOrdinals: [Int: Int],
            headerSourceOrdinal: Int?,
            sourceRows: [DirectSourceRow]? = nil,
            sourceControls: Controls? = nil,
            correspondenceOrdinals: [Int: Int] = [:]
        ) -> Carrier {
            let outputRows = (sourceRows ?? rows).map { row in
                row.oracleRow(
                    sourcePage: source.format == "pdf" ? pages[row.sourceOrder] : nil,
                    sourceOrdinal: sourceOrdinals[row.sourceOrder] ?? row.sourceOrdinal,
                    correspondenceOrder: correspondenceOrdinals[row.sourceOrder] ?? row.sourceOrder
                )
            }

            return Carrier(
                sourceSha256: source.digest,
                sourceSize: source.size,
                format: source.format,
                logicalStatementId: key.logicalStatementID,
                accountIdentifierSha256: key.accountDigest,
                periodStart: key.periodStart,
                periodEnd: key.periodEnd,
                rowCount: outputRows.count,
                pageCount: source.format == "pdf" ? pages.values.max() : nil,
                headerSourceOrdinal: headerSourceOrdinal,
                controls: sourceControls ?? controls,
                rows: outputRows
            )
        }
    }

    private struct DirectCSVColumns {
        let date: Int
        let reference: Int
        let particulars: Int
        let dr: Int
        let cr: Int
        let balance: Int

        var maximum: Int {
            [date, reference, particulars, dr, cr, balance].max()!
        }
    }

    private enum DirectBalanceMapping: CaseIterable {
        case conventional
        case reversed
    }

    private struct DirectUnresolvedCSVRow {
        let sourceOrdinal: Int
        let date: String
        let description: String
        let reference: String?
        let physicalDR: Decimal?
        let physicalCR: Decimal?
        let balance: Decimal

        func signedAmount(using mapping: DirectBalanceMapping) throws -> Decimal {
            switch (physicalDR, physicalCR, mapping) {
            case let (.some(amount), nil, .conventional):
                return -amount
            case let (nil, .some(amount), .conventional):
                return amount
            case let (.some(amount), nil, .reversed):
                return amount
            case let (nil, .some(amount), .reversed):
                return -amount
            default:
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }
        }
    }

    private struct DirectPDFEvidence {
        let key: DirectStatementKey
    }

    private struct DirectXLSEvidence {
        let key: DirectStatementKey
        /// zero-based physical source row
        let headerRow: Int
    }

    private struct DirectTabularRow {
        /// zero-based physical source row
        let physicalRow: Int
        let date: String
        let direction: String
        let signedAmount: String
        let balance: String
        let description: String
        let reference: String?

    }

    private static func directAxisFiles(root: URL) throws -> [DirectAxisFile] {
        let authorizedRoot = URL(fileURLWithPath: "/Users/vyom/Documents/Ledger Forge/Originals/Axis/Bank Accounts")
        guard root.resolvingSymlinksInPath().standardizedFileURL == authorizedRoot.resolvingSymlinksInPath().standardizedFileURL else {
            throw AxisBankAuthenticAcceptanceError.corpusUnavailable
        }
        let urls = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let result = try urls.compactMap { url -> DirectAxisFile? in
            guard (try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return nil
            }

            let format = url.pathExtension.lowercased()
            guard ["csv", "pdf", "xls"].contains(format) else {
                return nil
            }

            return DirectAxisFile(
                url: url,
                bytes: try Data(contentsOf: url, options: [.mappedIfSafe]),
                format: format
            )
        }

        guard result.count == 9,
              Set(result.map(\.digest)).count == 9,
              Dictionary(grouping: result, by: \.format).mapValues(\.count) == [
                  "csv": 3, "pdf": 3, "xls": 3
              ] else {
            throw AxisBankAuthenticAcceptanceError.corpusUnavailable
        }

        let pinned: [String: String] = [
            "3b6b8b694a508dcee5eb8a7d4452b04df12ec77e150576a6998b7b0f06fa6f5b": "15510|csv",
            "5032772473bdb7d9e1f7aa5beeebca9b36570102f8ab0af533c74bfbc740518a": "25088|xls",
            "53e4e7e5fcfad2ffa31082dda3a71f626e3c4fea1b990e1d9d1e1f5d3ad7d0db": "10578|pdf",
            "7e95cb897d64dc410d138bf6768202411df1705c05a6bf3f24f580bb9f5d88de": "33792|xls",
            "92ca389ee0cd024f8df6bacaaffd14fa3991f069aa26eaa486e3e3f974c41bc1": "14330|pdf",
            "a466a8507e396473a9500c897627adfa9107bb668f9ae2c43489893124c1ba5a": "18709|pdf",
            "a6d4a08e2b9fca75ece02d65a6e25d9b1767f3ddbac6b5df8c17da64eddee154": "15872|xls",
            "d2af853d96dbb2b8733311db12e99df6801da077b518b575d6036251f305eb6e": "6566|csv",
            "d5ba6fa712933c7391baeb0e6d752438b89e757c3a517513bb6fc55a6adf25f2": "11075|csv"
        ]
        let actual = Dictionary(uniqueKeysWithValues: result.map { ($0.digest, "\($0.size)|\($0.format)") })
        guard actual == pinned else { throw AxisBankAuthenticAcceptanceError.corpusUnavailable }

        return result
    }

    private static func directCSVStatement(
        _ source: DirectAxisFile
    ) throws -> DirectCSVStatement {
        guard source.format == "csv",
              let text = String(data: source.bytes, encoding: .utf8) else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }

        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        let title = try directStatementTitle(text)
        let currency = try directSingleCapture(
            #"(?mi)^\s*Currency\s*:-\s*([A-Z]{3})\s*$"#,
            text
        )

        let headerRow = try directCSVHeaderRow(lines)
        let columns = try directCSVColumns(
            directCSVFields(lines[headerRow])
        )
        var unresolved = [DirectUnresolvedCSVRow]()

        for physicalIndex in (headerRow + 1)..<lines.count {
            let fields = try directCSVFields(lines[physicalIndex])
            guard fields.count > columns.maximum,
                  let date = directISODate(fields[columns.date]) else {
                continue
            }

            let dr = try directDecimalOrNil(fields[columns.dr])
            let cr = try directDecimalOrNil(fields[columns.cr])
            guard (dr == nil) != (cr == nil) else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }

            unresolved.append(
                DirectUnresolvedCSVRow(
                    sourceOrdinal: physicalIndex + 1,
                    date: date,
                    description: fields[columns.particulars],
                    reference: try directNumericReference(fields[columns.reference]),
                    physicalDR: dr,
                    physicalCR: cr,
                    balance: try directRequiredDecimal(fields[columns.balance])
                )
            )
        }

        let mapping = try directUniqueBalanceMapping(unresolved)
        let rows = try unresolved.enumerated().map { offset, row in
            let signed = try row.signedAmount(using: mapping)
            return DirectSourceRow(
                sourceOrder: offset + 1,
                sourceOrdinal: row.sourceOrdinal,
                date: row.date,
                direction: signed < .zero ? "debit" : "credit",
                signedAmount: directCanonicalDecimal(signed),
                balance: directCanonicalDecimal(row.balance),
                description: row.description,
                reference: row.reference,
                upi: directUPI(
                    narration: row.description,
                    direction: signed < .zero ? "debit" : "credit"
                )
            )
        }

        guard let first = rows.first, let last = rows.last else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }

        let opening = unresolved[0].balance - first.signedDecimal
        let debit = rows.reduce(Decimal.zero) {
            $0 + ($1.signedDecimal < .zero ? -$1.signedDecimal : .zero)
        }
        let credit = rows.reduce(Decimal.zero) {
            $0 + ($1.signedDecimal > .zero ? $1.signedDecimal : .zero)
        }

        return DirectCSVStatement(
            source: source,
            key: DirectStatementKey(
                accountDigest: directSHA256(Data(title.account.utf8)),
                periodStart: title.start,
                periodEnd: title.end,
                currency: currency
            ),
            headerSourceOrdinal: headerRow + 1,
            rows: rows,
            controls: Controls(
                openingBalance: directCanonicalDecimal(opening),
                closingBalance: last.balance,
                debitTotal: directCanonicalDecimal(debit),
                creditTotal: directCanonicalDecimal(credit)
            )
        )
    }

    private static func directPDFEvidence(
        _ source: DirectAxisFile
    ) throws -> DirectPDFEvidence {
        guard source.format == "pdf",
              let document = PDFDocument(data: source.bytes),
              document.pageCount > 0 else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }

        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")

        let title = try directStatementTitle(text)
        let currency = try directSingleCapture(
            #"(?mi)^\s*Currency\s*:\s*([A-Z]{3})\s*$"#,
            text
        )

        return DirectPDFEvidence(
            key: DirectStatementKey(
                accountDigest: directSHA256(Data(title.account.utf8)),
                periodStart: title.start,
                periodEnd: title.end,
                currency: currency
            )
        )
    }

    private static func directWrappedNarrationMatches(_ lines: [String], expected: String) -> Bool {
        let pattern = "^" + lines.map { NSRegularExpression.escapedPattern(for: directCollapse($0)) }.joined(separator: "\\s*") + "$"
        return directCollapse(expected).range(of: pattern, options: .regularExpression) != nil
    }

    private static func directPDFRows(_ source: DirectAxisFile, expected: [DirectSourceRow]) throws -> (pages: [Int: Int], rows: [DirectSourceRow], controls: Controls, correspondence: [Int: Int]) {
        guard let document = PDFDocument(data: source.bytes) else { throw AxisBankAuthenticAcceptanceError.campaignInvariant }
        var observed: [(page: Int, ordinal: Int, cells: [String], narrationLines: [String])] = []
        var controlRows: [String: [String]] = [:]
        var physicalLine = 0
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex), let text = page.string else { throw AxisBankAuthenticAcceptanceError.campaignInvariant }
            let ns = text as NSString
            var lines: [Int: [(CGFloat, String)]] = [:]
            for index in 0..<ns.length {
                let character = ns.substring(with: NSRange(location: index, length: 1))
                if character == "\n" || character == "\r" { continue }
                guard let selection = page.selection(for: NSRange(location: index, length: 1)) else { throw AxisBankAuthenticAcceptanceError.campaignInvariant }
                let bounds = selection.bounds(for: page)
                lines[Int((bounds.minY * 10).rounded()), default: []].append((bounds.minX, character))
            }
            var pending: [String] = []
            for y in lines.keys.sorted(by: >) {
                physicalLine += 1
                let characters = lines[y]!.sorted { $0.0 < $1.0 }
                let boundaries: [CGFloat] = [30, 87, 130, 328, 390, 453, 533, 575]
                var cells = (0..<7).map { column in
                    characters.filter { $0.0 >= boundaries[column] && $0.0 < boundaries[column + 1] }.map(\.1).joined().trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if pageIndex == 0 && y > 5519 { continue }
                if ["OPENING BALANCE", "TRANSACTION TOTAL", "CLOSING BALANCE"].contains(cells[2]) {
                    guard controlRows.updateValue(cells, forKey: cells[2]) == nil else { throw AxisBankAuthenticAcceptanceError.campaignInvariant }
                    pending = []
                    continue
                }
                if !cells[2].isEmpty { pending.append(cells[2]) }
                if directISODate(cells[0]) != nil {
                    cells[2] = pending.joined()
                    observed.append((pageIndex + 1, physicalLine, cells, pending))
                    pending = []
                }
            }
        }
        guard observed.count == expected.count,
              let opening = controlRows["OPENING BALANCE"],
              let closing = controlRows["CLOSING BALANCE"],
              let totals = controlRows["TRANSACTION TOTAL"] else { throw AxisBankAuthenticAcceptanceError.campaignInvariant }
        let controls = try Controls(
            openingBalance: directCanonicalDecimal(directRequiredDecimal(opening[5])),
            closingBalance: directCanonicalDecimal(directRequiredDecimal(closing[5])),
            debitTotal: directCanonicalDecimal(directRequiredDecimal(totals[3])),
            creditTotal: directCanonicalDecimal(directRequiredDecimal(totals[4])),
            printedLiterals: ["openingBalance": opening[5], "closingBalance": closing[5],
                              "debitTotal": totals[3], "creditTotal": totals[4]]
        )
        let rows = try observed.enumerated().map { index, occurrence in
            let cells = occurrence.cells
            let debit = try directDecimalOrNil(cells[3]), credit = try directDecimalOrNil(cells[4])
            guard (debit == nil) != (credit == nil),
                  (debit ?? credit ?? 0) > 0 else { throw AxisBankAuthenticAcceptanceError.campaignInvariant }
            let signed = (credit ?? 0) - (debit ?? 0)
            let direction = debit == nil ? "credit" : "debit"
            return try DirectSourceRow(sourceOrder: index + 1, sourceOrdinal: occurrence.ordinal,
                date: directISODateRequired(cells[0]), direction: direction,
                signedAmount: directCanonicalDecimal(signed),
                balance: directCanonicalDecimal(directRequiredDecimal(cells[5])),
                description: occurrence.narrationLines.joined(separator: " "),
                reference: directNumericReference(cells[1]),
                upi: directUPI(narration: occurrence.narrationLines.joined(), direction: direction))
        }
        let correspondence = try directUniqueCorrespondence(expected: expected, observed: rows) { left, right in
            left.date == right.date && left.direction == right.direction &&
                left.signedDecimal == right.signedDecimal && left.reference == right.reference &&
                directWrappedNarrationMatches(observed[right.sourceOrder - 1].narrationLines, expected: left.description)
        }
        let pages = Dictionary(uniqueKeysWithValues: observed.enumerated().map { ($0.offset + 1, $0.element.page) })
        return (pages, rows, controls, correspondence)
    }

    private static func directXLSGrid(_ bytes: Data) throws -> [[String]] {
        try bytes.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }

            var error = LF_XLS_ERROR_OK
            guard let document = lf_xls_open_buffer(base, rawBuffer.count, &error) else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }
            defer { lf_xls_close(document) }

            let rowCount = Int(lf_xls_row_count(document))
            let columnCount = Int(lf_xls_column_count(document))
            guard rowCount > 0, columnCount > 0 else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }

            return try (0..<rowCount).map { row in
                try (0..<columnCount).map { column in
                    switch lf_xls_cell_kind(document, UInt32(row), UInt32(column)) {
                    case LF_XLS_CELL_BLANK:
                        return ""
                    case LF_XLS_CELL_STRING:
                        guard let pointer = lf_xls_cell_string(
                            document,
                            UInt32(row),
                            UInt32(column)
                        ), let string = String(validatingCString: pointer) else {
                            throw AxisBankAuthenticAcceptanceError.campaignInvariant
                        }
                        return string
                    case LF_XLS_CELL_NUMBER:
                        let value = lf_xls_cell_number(
                            document,
                            UInt32(row),
                            UInt32(column)
                        )
                        guard value.isFinite else {
                            throw AxisBankAuthenticAcceptanceError.campaignInvariant
                        }
                        return String(
                            format: "%.15g",
                            locale: Locale(identifier: "en_US_POSIX"),
                            value
                        )
                    default:
                        throw AxisBankAuthenticAcceptanceError.campaignInvariant
                    }
                }
            }
        }
    }

    private static func directXLSEvidence(
        _ grid: [[String]]
    ) throws -> DirectXLSEvidence {
        let joined = grid.map { $0.joined(separator: " ") }.joined(separator: "\n")
        let title = try directStatementTitle(joined)
        let currency = "" // This XLS carrier does not print currency; the unique complete CSV/PDF triplet proves it.


        let headerRows = grid.indices.filter { index in
            let tokens = Set(grid[index].map(directHeaderToken))
            return tokens.isSuperset(
                of: ["tran date", "chqno", "particulars", "dr", "cr", "bal", "sol"]
            )
        }

        guard headerRows.count == 1, let headerRow = headerRows.first else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }

        return DirectXLSEvidence(
            key: DirectStatementKey(
                accountDigest: directSHA256(Data(title.account.utf8)),
                periodStart: title.start,
                periodEnd: title.end,
                currency: currency
            ),
            headerRow: headerRow
        )
    }

    private static func directXLSRows(
        grid: [[String]],
        headerRow: Int
    ) throws -> [DirectTabularRow] {
        guard grid.indices.contains(headerRow) else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }

        let header = grid[headerRow]
        let columns = try directCSVColumns(header)
        var result = [DirectTabularRow]()

        for rowIndex in (headerRow + 1)..<grid.count {
            let row = grid[rowIndex]
            guard row.count > columns.maximum,
                  let date = directISODate(row[columns.date]) else {
                continue
            }

            let dr = try directDecimalOrNil(row[columns.dr])
            let cr = try directDecimalOrNil(row[columns.cr])
            guard (dr == nil) != (cr == nil) else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }

            let balance = try directRequiredDecimal(row[columns.balance])
            let signed: Decimal
            if let dr {
                signed = -dr
            } else if let cr {
                signed = cr
            } else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }

            result.append(
                DirectTabularRow(
                    physicalRow: rowIndex,
                    date: date,
                    direction: signed < .zero ? "debit" : "credit",
                    signedAmount: directCanonicalDecimal(signed),
                    balance: directCanonicalDecimal(balance),
                    description: row[columns.particulars],
                    reference: try directNumericReference(row[columns.reference])
                )
            )
        }

        guard !result.isEmpty else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        return result
    }

    private static func directUniqueCorrespondence(
        expected: [DirectSourceRow],
        observed: [DirectSourceRow],
        agrees: (DirectSourceRow, DirectSourceRow) -> Bool
    ) throws -> [Int: Int] {
        guard expected.count == observed.count else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        var assigned = Set<Int>()
        var result: [Int: Int] = [:]
        for source in expected {
            let matches = observed.filter { agrees(source, $0) }
            guard matches.count == 1, let match = matches.first,
                  assigned.insert(match.sourceOrder).inserted else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }
            result[match.sourceOrder] = source.sourceOrder
        }
        return result
    }

    private static func directRowControls(_ rows: [DirectSourceRow]) throws -> Controls {
        guard let first = rows.first, let last = rows.last else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        return try Controls(
            openingBalance: directCanonicalDecimal(directRequiredDecimal(first.balance) - first.signedDecimal),
            closingBalance: last.balance,
            debitTotal: directCanonicalDecimal(rows.reduce(Decimal.zero) { $0 + max(-$1.signedDecimal, .zero) }),
            creditTotal: directCanonicalDecimal(rows.reduce(Decimal.zero) { $0 + max($1.signedDecimal, .zero) })
        )
    }

    private static func directCSVFields(_ line: String) throws -> [String] {
        var fields = [String]()
        var value = ""
        var quoted = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            if character == "\"" {
                let next = line.index(after: index)
                if quoted, next < line.endIndex, line[next] == "\"" {
                    value.append("\"")
                    index = line.index(after: next)
                    continue
                }
                quoted.toggle()
            } else if character == ",", !quoted {
                fields.append(value)
                value = ""
            } else {
                value.append(character)
            }
            index = line.index(after: index)
        }

        guard !quoted else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        fields.append(value)
        return fields
    }

    private static func directCSVHeaderRow(_ lines: [String]) throws -> Int {
        let candidates = lines.indices.filter { index in
            let fields = (try? directCSVFields(lines[index])) ?? []
            let tokens = Set(fields.map(directHeaderToken))
            return tokens.isSuperset(
                of: ["tran date", "chqno", "particulars", "dr", "cr", "bal", "sol"]
            )
        }
        guard candidates.count == 1, let header = candidates.first else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        return header
    }

    private static func directCSVColumns(_ header: [String]) throws -> DirectCSVColumns {
        func index(for token: String) throws -> Int {
            let candidates = header.indices.filter {
                directHeaderToken(header[$0]) == token
            }
            guard candidates.count == 1, let value = candidates.first else {
                throw AxisBankAuthenticAcceptanceError.campaignInvariant
            }
            return value
        }

        return try DirectCSVColumns(
            date: index(for: "tran date"),
            reference: index(for: "chqno"),
            particulars: index(for: "particulars"),
            dr: index(for: "dr"),
            cr: index(for: "cr"),
            balance: index(for: "bal")
        )
    }

    private static func directStatementTitle(
        _ text: String
    ) throws -> (account: String, start: String, end: String) {
        let pattern = #"""
        Statement\s+of(?:\s+Axis)?\s+Account\s+No\s*[:-]\s*([0-9]+)
        \s+for\s+the\s+period\s*\(\s*From\s*:\s*
        ([0-9]{2}-[0-9]{2}-[0-9]{4})\s+To\s*:\s*
        ([0-9]{2}-[0-9]{2}-[0-9]{4})\s*\)
        """#

        let captures = try directCaptures(pattern, text)
        guard captures.count == 3 else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }

        return (
            captures[0],
            try directISODateRequired(captures[1]),
            try directISODateRequired(captures[2])
        )
    }

    private static func directSingleCapture(
        _ pattern: String,
        _ text: String
    ) throws -> String {
        let captures = try directCaptures(pattern, text)
        guard captures.count == 1 else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        return captures[0]
    }

    private static func directCaptures(
        _ pattern: String,
        _ text: String
    ) throws -> [String] {
        let regex = try NSRegularExpression(
            pattern: pattern,
            options: [.allowCommentsAndWhitespace]
        )
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard matches.count == 1, let match = matches.first else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }

    private static func directISODate(_ value: String) -> String? {
        let pieces = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "-")
        guard pieces.count == 3,
              let day = Int(pieces[0]),
              let month = Int(pieces[1]),
              let year = Int(pieces[2]),
              (1...31).contains(day),
              (1...12).contains(month),
              (1900...2100).contains(year) else {
            return nil
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func directISODateRequired(_ value: String) throws -> String {
        guard let result = directISODate(value) else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        return result
    }

    private static func directPDFDate(_ iso: String) -> String {
        let pieces = iso.split(separator: "-")
        return "\(pieces[2])-\(pieces[1])-\(pieces[0])"
    }

    private static func directHeaderToken(_ value: String) -> String {
        directCollapse(value).lowercased()
    }

    nonisolated private static func directCollapse(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func directNumericReference(_ value: String) throws -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "-" {
            return nil
        }
        guard trimmed.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        return trimmed
    }

    private static func directDecimalOrNil(_ value: String) throws -> Decimal? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.replacingOccurrences(of: ",", with: "")
        guard normalized.range(
            of: #"^[+-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)$"#,
            options: .regularExpression
        ) != nil,
        let decimal = Decimal(
            string: normalized,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        return decimal
    }

    private static func directRequiredDecimal(_ value: String) throws -> Decimal {
        guard let decimal = try directDecimalOrNil(value) else {
            throw AxisBankAuthenticAcceptanceError.campaignInvariant
        }
        return decimal
    }

    private static func directCanonicalDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func directUPI(
        narration: String,
        direction: String
    ) -> DirectUPI? {
        let regex = try? NSRegularExpression(
            pattern: #"(?i)(?<![A-Z0-9])P2([AM])/?([0-9]{12})(?![0-9])"#
        )
        guard let regex else { return nil }

        let range = NSRange(narration.startIndex..., in: narration)
        let matches = regex.matches(in: narration, range: range)
        guard matches.count == 1,
              let operationRange = Range(matches[0].range(at: 1), in: narration),
              let referenceRange = Range(matches[0].range(at: 2), in: narration) else {
            return nil
        }

        let operation = String(narration[operationRange]).uppercased()
        return DirectUPI(
            operation: operation == "A" ? "p2a" : "p2m",
            reference: String(narration[referenceRange]),
            subtype: direction == "credit" ? "credit-adjustment" : "posting"
        )
    }

    nonisolated private static func directSHA256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func sourceURLsByDigest(root: URL) throws -> [String: URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AxisBankAuthenticAcceptanceError.corpusUnavailable
        }
        var result: [String: URL] = [:]
        for case let url as URL in enumerator {
            guard ["csv", "pdf", "xls"].contains(url.pathExtension.lowercased()),
                  (try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            let digest = sha256(try Data(contentsOf: url, options: [.mappedIfSafe]))
            guard result[digest] == nil else {
                throw AxisBankAuthenticAcceptanceError.duplicateSourceDigest
            }
            result[digest] = url
        }
        return result
    }

    private func privacySafeLabel(_ carrier: Carrier) -> String {
        "\(carrier.format):\(carrier.logicalStatementId.prefix(12))"
    }

    private func collapse(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func isLowercaseSHA256(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy {
            ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x61 && $0 <= 0x66)
        }
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private enum AxisBankAuthenticAcceptanceError: Error {
        case corpusUnavailable
        case duplicateSourceDigest
        case unsupportedFormat
        case campaignInvariant
    }
    /// Keep source values in memory when an assertion fails. The test result
    /// records the field, source location and Boolean outcome only.
    private func expectSourceFact(
        _ condition: Bool, _ comment: Comment? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(condition, comment, sourceLocation: sourceLocation)
    }

}

/// Source-independent bipartite-graph mechanics only. These symbols are not
/// statement rows, financial values, domain objects or repository fixtures.
@MainActor
struct BankOccurrenceCorrespondenceMechanicsTests {
    @Test
    func singleCandidatesPreserveMultiplicity() {
        #expect(BankImportDecision.uniqueAssignment([
            "left-a": ["right-a"], "left-b": ["right-b"]
        ]) == ["left-a": "right-a", "left-b": "right-b"])
    }

    @Test
    func completeGraphCanDisambiguateAnIndividualCandidate() {
        #expect(BankImportDecision.uniqueAssignment([
            "left-a": ["right-a", "right-b"], "left-b": ["right-b"]
        ]) == ["left-a": "right-a", "left-b": "right-b"])
    }

    @Test
    func insufficientDistinctTargetsAreRejected() {
        #expect(BankImportDecision.uniqueAssignment([
            "left-a": ["right-a"], "left-b": ["right-a"]
        ]) == nil)
        #expect(BankImportDecision.uniqueAssignment(["left-a": []]) == nil)
    }

    @Test
    func multipleCompleteAssignmentsAreRejected() {
        #expect(BankImportDecision.uniqueAssignment([
            "left-a": ["right-a", "right-b"], "left-b": ["right-a", "right-b"]
        ]) == nil)
    }

    @Test
    func emptyGraphHasOneEmptyAssignment() {
        #expect(BankImportDecision.uniqueAssignment([:]) == [:])
    }
}


/// Opaque text-scanner mechanics only. These literals contain no statement
/// rows, transaction descriptions, financial facts or repository fixtures.
@MainActor
struct AxisStandaloneNarrationWhitespaceMechanicsTests {
    @Test
    func additionalPDFSpacesRetainTabularWordBoundaries() {
        for printed in ["a bc def", "abc d ef", "a bc d ef"] {
            #expect(BankImportDecision.axisStandalonePDFNarrationAgrees(
                pdfNarration: printed, tabularNarration: "abc def"))
        }
    }

    @Test
    func whitespaceRunsAreComparedWithoutRewritingCharacters() {
        #expect(BankImportDecision.axisStandalonePDFNarrationAgrees(
            pdfNarration: " \ta bc\n\n d ef  ", tabularNarration: "abc\t def"))
        #expect(BankImportDecision.axisStandalonePDFNarrationAgrees(
            pdfNarration: "a bc-de f", tabularNarration: "abc-def"))
    }

    @Test
    func missingOrMovedTabularWordBoundaryIsRejected() {
        for printed in ["abcdef", "ab cdef", "abcde f"] {
            #expect(!BankImportDecision.axisStandalonePDFNarrationAgrees(
                pdfNarration: printed, tabularNarration: "abc def"))
        }
    }

    @Test
    func characterCaseAndPunctuationChangesAreRejected() {
        let changed: [(pdf: String, tabular: String)] = [
            ("Abc def", "abc def"),
            ("abc de", "abc def"),
            ("abc defg", "abc def"),
            ("abd def", "abc def"),
            ("abc def", "abc-def"),
            ("abc-def", "abc/def")
        ]
        for pair in changed {
            #expect(!BankImportDecision.axisStandalonePDFNarrationAgrees(
                pdfNarration: pair.pdf, tabularNarration: pair.tabular))
        }
    }

    @Test
    func emptyInputCannotEstablishCorrespondence() {
        let empty: [(pdf: String, tabular: String)] = [
            ("", ""), (" ", "\t\n"), ("abc", ""), ("", "abc"), ("   ", "abc")
        ]
        for pair in empty {
            #expect(!BankImportDecision.axisStandalonePDFNarrationAgrees(
                pdfNarration: pair.pdf, tabularNarration: pair.tabular))
        }
    }
}
