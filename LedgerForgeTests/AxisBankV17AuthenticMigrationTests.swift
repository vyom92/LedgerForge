import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

/// Populates the historical V16 schema only through the ordinary import engine
/// and authentic HDFC statements, then proves the V17 table rebuild preserves
/// that graph before admitting the complete authentic Axis bank corpus.
@MainActor
struct AxisBankV17AuthenticMigrationTests {
    private struct HDFCOracle: Decodable {
        let carriers: HDFCCarriers
        let totals: HDFCTotals
    }

    private struct HDFCCarriers: Decodable {
        let pdf: [HDFCCarrier]
        let xls: [HDFCCarrier]
    }

    private struct HDFCCarrier: Decodable {
        let carrier: String
        let sha256: String
        let account: String
        let periodStart: String
        let periodEnd: String
        let currency: String
        let rows: [HDFCRow]

        var logicalStatementKey: String {
            [account, periodStart, periodEnd, currency].joined(separator: "|")
        }

        var sourceFormat: String {
            carrier.lowercased().hasSuffix(".pdf") ? "pdf" : "xls"
        }
    }

    private struct HDFCRow: Decodable {
        let valueDate: String
    }

    private struct HDFCTotals: Decodable {
        let pdfCarriers: Int
        let xlsCarriers: Int
        let logicalStatements: Int
        let canonicalRows: Int
        let representationRows: Int
    }

    private struct AxisOracle: Decodable {
        let corpus: AxisCorpus
        let carriers: [AxisCarrier]
    }

    private struct AxisCorpus: Decodable {
        let carrierCount: Int
        let logicalStatementCount: Int
        let canonicalEventCount: Int
        let representationRowCount: Int
    }

    private struct AxisCarrier: Decodable {
        let sourceSha256: String
        let sourceSize: Int
        let format: String
        let logicalStatementId: String
        let accountIdentifierSha256: String
        let rowCount: Int
    }

    private struct AmexMigrationOracle: Decodable {
        let sources: [AmexMigrationSource]
    }

    private struct AmexMigrationSource: Decodable {
        let basename: String
        let sourceSHA256: String
        let sourceByteSize: Int
        let rows: [AmexMigrationRow]
    }

    private struct AmexMigrationRow: Decodable {
        let globalSourceOrdinal: Int
    }

    private struct HistoricalCBQExport: Decodable {
        let schema: String
        let sourceAuthority: String
        let sourceInventorySha256: String
        let sourceCount: Int
        let transactionCount: Int
        let cardStatementCount: Int
        let cardSectionCount: Int
        let cardInstrumentCount: Int
        let cardTransactionEvidenceCount: Int
        let migrationVersion: Int
        let databaseSha256: String
        let minimumAmountDuePersistedCount: Int
        let reconciliationRuleCounts: [String: Int]
    }

    private struct ProjectionGraphSnapshot: Equatable {
        let accounts: [AccountDTO]
        let transactions: [TransactionDTO]
        let projections: [StatementFinancialProjectionRecordDTO]
        let groups: [StatementEquivalenceGroupDTO]
        let members: [StatementEquivalenceMemberDTO]
        let attempts: [ImportAttemptDTO]
    }

    private struct GraphCounts: Equatable {
        let accounts: Int
        let transactions: Int
        let projections: Int
        let groups: Int
        let members: Int
        let attempts: Int
        let zeroActivityControls: Int
    }

    @MainActor
    private final class HydrationStores {
        let accounts = AccountStore()
        let transactions = TransactionStore()
        let categories = CategoryStore()
        let cards = CardStore()
        let sessions = ImportSessionStore()
        let attempts = ImportAttemptStore()
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticPopulatedV16UpgradesLosslesslyThenAcceptsAllAxisCarriers() async throws {
        let environment = ProcessInfo.processInfo.environment
        let hdfcRoot = URL(fileURLWithPath: try #require(
            environment["LEDGERFORGE_PRIVATE_HDFC_ORIGINALS_ROOT"]
        ))
        let hdfcPassword = try #require(
            environment["LEDGERFORGE_PRIVATE_HDFC_PASSWORD"]
        )
        let hdfcOracle = try JSONDecoder().decode(
            HDFCOracle.self,
            from: Data(contentsOf: URL(fileURLWithPath: try #require(
                environment["LEDGERFORGE_PRIVATE_HDFC_ORACLE_FILE"]
            )))
        )
        let axisRoot = URL(fileURLWithPath: try #require(
            environment["LEDGERFORGE_AXIS_BANK_ROOT"]
        ))
        let axisDecoder = JSONDecoder()
        axisDecoder.keyDecodingStrategy = .convertFromSnakeCase
        let axisOracle = try axisDecoder.decode(
            AxisOracle.self,
            from: Data(contentsOf: URL(fileURLWithPath: try #require(
                environment["LEDGERFORGE_AXIS_BANK_ORACLE"]
            )))
        )
        let axisSources = try sourceURLsByDigest(root: axisRoot)

        try verifyOracleShape(hdfcOracle, axisOracle: axisOracle, axisSources: axisSources)
        let hdfcCarriers = hdfcOracle.carriers.pdf + hdfcOracle.carriers.xls
        let startingHDFCDigests = try Dictionary(uniqueKeysWithValues: hdfcCarriers.map {
            ($0.carrier, try sourceDigest(hdfcRoot.appendingPathComponent($0.carrier)))
        })
        #expect(startingHDFCDigests == Dictionary(uniqueKeysWithValues: hdfcCarriers.map {
            ($0.carrier, $0.sha256)
        }))
        let startingAxisDigests = try Dictionary(uniqueKeysWithValues: axisSources.map {
            ($0.key, try sourceDigest($0.value))
        })
        #expect(startingAxisDigests.allSatisfy { $0.key == $0.value })

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-Axis-V17-Authentic-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let fresh = try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("fresh-v17.sqlite").path
        )
        try verifyDatabaseIntegrity(
            fresh.database,
            expectedVersion: 17,
            expectsV17Schema: true,
            expectedLegacyAlterTable: 0
        )
        try fresh.database.checkpointAndClose()

        let databaseURL = folder.appendingPathComponent("populated-v16.sqlite")
        let workspaceID = "axis-v17-authentic-\(UUID().uuidString.lowercased())"
        let v16Migrations = Array(allMigrations.prefix(16))
        let v16SQLite = try SQLiteRepositoryProvider(
            path: databaseURL.path,
            migrations: v16Migrations
        )
        try installCurrentReaderCompatibilityView(v16SQLite.database)
        let v16Provider = DatabaseProvider.verifiedSQLite(
            v16SQLite,
            protectsGeneration: false
        )
        let v16Engine = makeEngine(
            provider: v16Provider,
            workspaceID: workspaceID,
            hdfcPassword: hdfcPassword
        )
        try await importHDFCCorpus(
            hdfcCarriers,
            root: hdfcRoot,
            engine: v16Engine
        )

        let expectedHDFCCounts = GraphCounts(
            accounts: 2,
            transactions: hdfcOracle.totals.canonicalRows,
            projections: hdfcOracle.totals.pdfCarriers + hdfcOracle.totals.xlsCarriers,
            groups: hdfcOracle.totals.logicalStatements,
            members: hdfcOracle.totals.pdfCarriers + hdfcOracle.totals.xlsCarriers,
            attempts: hdfcOracle.totals.pdfCarriers + hdfcOracle.totals.xlsCarriers,
            zeroActivityControls: 0
        )
        #expect(try graphCounts(v16Provider, workspaceID: workspaceID) == expectedHDFCCounts)
        let v16Snapshot = try projectionGraphSnapshot(v16Provider, workspaceID: workspaceID)
        #expect(v16Snapshot.projections.allSatisfy {
            $0.projection.algorithmIdentifier == StatementFinancialProjectionDTO.algorithm &&
                $0.projection.isValid() &&
                $0.projection.events.allSatisfy { $0.valueDateISO != nil }
        })
        #expect(v16Snapshot.projections.reduce(0) {
            $0 + $1.projection.eventCount
        } == hdfcOracle.totals.representationRows)
        #expect(try v16SQLite.database.queryInt(
            "SELECT COUNT(*) FROM temp.statement_zero_activity_controls;"
        ) == 0)
        #expect(try v16SQLite.database.queryInt(
            "SELECT COUNT(*) FROM main.sqlite_master WHERE name = 'statement_zero_activity_controls';"
        ) == 0)
        try verifyDatabaseIntegrity(
            v16SQLite.database,
            expectedVersion: 16,
            expectsV17Schema: false,
            expectedLegacyAlterTable: 0
        )
        try v16SQLite.database.checkpointAndClose()

        let v17SQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        let v17Provider = DatabaseProvider.verifiedSQLite(
            v17SQLite,
            protectsGeneration: false
        )
        try verifyDatabaseIntegrity(
            v17SQLite.database,
            expectedVersion: 17,
            expectsV17Schema: true,
            expectedLegacyAlterTable: 0
        )
        #expect(try graphCounts(v17Provider, workspaceID: workspaceID) == expectedHDFCCounts)
        #expect(try projectionGraphSnapshot(v17Provider, workspaceID: workspaceID) == v16Snapshot)

        let hdfcHydration = try hydrate(
            provider: v17Provider,
            workspaceID: workspaceID
        )
        #expect(hdfcHydration.result.accountCount == 2)
        #expect(hdfcHydration.result.transactionCount == hdfcOracle.totals.canonicalRows)
        #expect(hdfcHydration.result.importSessionCount == hdfcCarriers.count)
        #expect(hdfcHydration.stores.transactions.transactions.allSatisfy {
            $0.valueDate != nil
        })

        let v17Engine = makeEngine(
            provider: v17Provider,
            workspaceID: workspaceID,
            hdfcPassword: hdfcPassword
        )
        try await importAxisCorpus(
            axisOracle.carriers,
            sources: axisSources,
            engine: v17Engine
        )
        let expectedCombinedCounts = GraphCounts(
            accounts: expectedHDFCCounts.accounts + 2,
            transactions: expectedHDFCCounts.transactions + axisOracle.corpus.canonicalEventCount,
            projections: expectedHDFCCounts.projections + axisOracle.corpus.carrierCount,
            groups: expectedHDFCCounts.groups + axisOracle.corpus.logicalStatementCount,
            members: expectedHDFCCounts.members + axisOracle.corpus.carrierCount,
            attempts: expectedHDFCCounts.attempts + axisOracle.corpus.carrierCount,
            zeroActivityControls: 0
        )
        #expect(try graphCounts(v17Provider, workspaceID: workspaceID) == expectedCombinedCounts)
        let combinedSnapshot = try projectionGraphSnapshot(v17Provider, workspaceID: workspaceID)
        let hdfcAfterAxis = combinedSnapshot.projections.filter {
            $0.projection.algorithmIdentifier == StatementFinancialProjectionDTO.algorithm
        }
        let axisAfterUpgrade = combinedSnapshot.projections.filter {
            $0.projection.algorithmIdentifier == StatementFinancialProjectionDTO.axisAlgorithm
        }
        #expect(hdfcAfterAxis == v16Snapshot.projections)
        #expect(axisAfterUpgrade.count == axisOracle.corpus.carrierCount)
        #expect(axisAfterUpgrade.allSatisfy {
            $0.projection.isValid() &&
                $0.projection.events.allSatisfy { $0.valueDateISO == nil }
        })
        #expect(Set(axisAfterUpgrade.map { $0.projection.sourceFormatCode }) == ["csv", "pdf", "xls"])

        let combinedHydration = try hydrate(
            provider: v17Provider,
            workspaceID: workspaceID
        )
        #expect(combinedHydration.result.accountCount == expectedCombinedCounts.accounts)
        #expect(combinedHydration.result.transactionCount == expectedCombinedCounts.transactions)
        #expect(combinedHydration.result.importSessionCount == expectedCombinedCounts.members)

        try v17SQLite.database.checkpointAndClose()
        let independentConnection = SQLiteDatabase(path: ":memory:")
        try independentConnection.open()
        let reopenedLegacyAlterTable = try independentConnection.queryInt(
            "PRAGMA legacy_alter_table;"
        )
        independentConnection.close()
        let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        defer { reopenedSQLite.database.close() }
        let reopenedProvider = DatabaseProvider.verifiedSQLite(
            reopenedSQLite,
            protectsGeneration: false
        )
        try verifyDatabaseIntegrity(
            reopenedSQLite.database,
            expectedVersion: 17,
            expectsV17Schema: true,
            expectedLegacyAlterTable: reopenedLegacyAlterTable
        )
        #expect(try graphCounts(reopenedProvider, workspaceID: workspaceID) == expectedCombinedCounts)
        #expect(try projectionGraphSnapshot(reopenedProvider, workspaceID: workspaceID) == combinedSnapshot)
        let reopenedHydration = try hydrate(
            provider: reopenedProvider,
            workspaceID: workspaceID
        )
        #expect(reopenedHydration.result.accountCount == expectedCombinedCounts.accounts)
        #expect(reopenedHydration.result.transactionCount == expectedCombinedCounts.transactions)
        #expect(reopenedHydration.result.importSessionCount == expectedCombinedCounts.members)

        let endingHDFCDigests = try Dictionary(uniqueKeysWithValues: hdfcCarriers.map {
            ($0.carrier, try sourceDigest(hdfcRoot.appendingPathComponent($0.carrier)))
        })
        #expect(endingHDFCDigests == startingHDFCDigests)
        let endingAxisDigests = try Dictionary(uniqueKeysWithValues: axisSources.map {
            ($0.key, try sourceDigest($0.value))
        })
        #expect(endingAxisDigests == startingAxisDigests)
    }

    /// The HDFC graph above cannot establish preservation of populated card
    /// tables. Exercise those V17 rebuilds with all authentic Amex statements;
    /// the independent family gate separately establishes their source meaning.
    @Test(.globalRuntimeStateIsolation)
    func authenticPopulatedV16CardGraphSurvivesV17AndReopen() async throws {
        let environment = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: try #require(environment["LEDGERFORGE_PRIVATE_AMEX_ROOT"]))
        let password = try #require(environment["LEDGERFORGE_PRIVATE_AMEX_PASSWORD"])
        let oracleURL = URL(fileURLWithPath: try #require(environment["LEDGERFORGE_PRIVATE_AMEX_ORACLE_PATH"]))
        let oracleBytes = try Data(contentsOf: oracleURL)
        try #require(sourceDigest(oracleBytes) == "92d14deedec5ba2f6c57be780b06c9e8deeb2703e689c2c1145507a3ca138e81")
        let oracle = try JSONDecoder().decode(AmexMigrationOracle.self, from: oracleBytes)
        let sources = try sourceURLsByDigest(root: root)
        try #require(oracle.sources.count == 20 && sources.count == 20)
        try #require(oracle.sources.reduce(0) { $0 + $1.rows.count } == 902)
        try #require(Set(sources.keys) == Set(oracle.sources.map(\.sourceSHA256)))

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-Card-V17-Authentic-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("authentic-card-v16.sqlite").path
        let workspaceID = "card-v17-authentic-\(UUID().uuidString.lowercased())"
        let v16SQLite = try SQLiteRepositoryProvider(path: path, migrations: Array(allMigrations.prefix(16)))
        defer { v16SQLite.database.close() }
        try installCurrentReaderCompatibilityView(v16SQLite.database)
        let v16Provider = DatabaseProvider.verifiedSQLite(v16SQLite, protectsGeneration: false)
        let engine = makeEngine(
            provider: v16Provider,
            workspaceID: workspaceID,
            hdfcPassword: try #require(environment["LEDGERFORGE_PRIVATE_HDFC_PASSWORD"]),
            amexPassword: password
        )
        var liabilityAccountID: String?
        for source in oracle.sources.sorted(by: { $0.basename < $1.basename }) {
            let url = try #require(sources[source.sourceSHA256])
            let prepared = try await engine.prepareImport(from: url)
            defer { engine.cancelPreparedImport(prepared) }
            try #require(prepared.sourceSnapshot.byteCount == source.sourceByteSize)
            try #require(try prepared.sourceSnapshot.withBytes(sourceDigest) == source.sourceSHA256)
            try #require(prepared.validation.passed && prepared.financialDocument.transactions.count == source.rows.count)
            let choice: ImportAccountChoice
            if let accountID = liabilityAccountID {
                choice = try amexSectionChoice(
                    prepared.financialDocument,
                    accountID: accountID,
                    snapshot: v16Provider.cardRepo.snapshot(workspaceId: workspaceID)
                )
            } else {
                choice = .createNewCardLiabilityAccountAndInstrument
            }
            let committed = await engine.commitPreparedImport(prepared, accountChoice: choice)
            try #require(committed.persisted && committed.transactionCount == source.rows.count)
            try #require(committed.hydrationOutcome == .committedAndHydrated)
            let committedAccountID = try #require(committed.accountId)
            if let accountID = liabilityAccountID { #expect(accountID == committedAccountID) }
            liabilityAccountID = committedAccountID
        }
        let before = try projectionGraphSnapshot(v16Provider, workspaceID: workspaceID)
        let cardsBefore = try v16Provider.cardRepo.snapshot(workspaceId: workspaceID)
        try #require(before.accounts.count == 1 && before.transactions.count == 902 && before.attempts.count == 20)
        try #require(cardsBefore.statements.count == 20 && cardsBefore.sections.count == 31)
        try #require(cardsBefore.transactionEvidence.count == 902 && cardsBefore.semanticProjections.count == 20)
        try #require(!cardsBefore.summaryComponents.isEmpty && !cardsBefore.semanticGroups.isEmpty)
        #expect(try v16SQLite.database.queryInt("SELECT COUNT(*) FROM temp.statement_zero_activity_controls;") == 0)
        #expect(try v16SQLite.database.queryInt("SELECT COUNT(*) FROM main.sqlite_master WHERE name = 'statement_zero_activity_controls';") == 0)
        try v16SQLite.database.checkpointAndClose()

        let upgradedSQLite = try SQLiteRepositoryProvider(path: path)
        defer { upgradedSQLite.database.close() }
        let upgraded = DatabaseProvider.verifiedSQLite(upgradedSQLite, protectsGeneration: false)
        try verifyDatabaseIntegrity(upgradedSQLite.database, expectedVersion: 17,
                                    expectsV17Schema: true, expectedLegacyAlterTable: 0)
        #expect(try projectionGraphSnapshot(upgraded, workspaceID: workspaceID) == before)
        #expect(try upgraded.cardRepo.snapshot(workspaceId: workspaceID) == cardsBefore)
        let upgradedHydration = try hydrate(provider: upgraded, workspaceID: workspaceID)
        #expect(upgradedHydration.result.accountCount == 1)
        #expect(upgradedHydration.result.transactionCount == 902)
        #expect(upgradedHydration.result.importSessionCount == 20)
        #expect(upgradedHydration.stores.cards.snapshot.statements.count == 20)
        try upgradedSQLite.database.checkpointAndClose()

        let reopenedSQLite = try SQLiteRepositoryProvider(path: path)
        defer { reopenedSQLite.database.close() }
        let reopened = DatabaseProvider.verifiedSQLite(reopenedSQLite, protectsGeneration: false)
        #expect(try projectionGraphSnapshot(reopened, workspaceID: workspaceID) == before)
        #expect(try reopened.cardRepo.snapshot(workspaceId: workspaceID) == cardsBefore)
        #expect(try reopenedSQLite.database.query(sql: "PRAGMA foreign_key_check;") { _ in true }.isEmpty)
        let reopenedHydration = try hydrate(provider: reopened, workspaceID: workspaceID)
        #expect(reopenedHydration.result.transactionCount == 902)
        #expect(reopenedHydration.result.importSessionCount == 20)
        #expect(reopenedHydration.stores.cards.snapshot.statements.count == 20)
        for source in oracle.sources {
            #expect(try sourceDigest(try #require(sources[source.sourceSHA256])) == source.sourceSHA256)
        }
    }

    /// This is an exact copy of a database produced by the preserved V16
    /// production binary from authentic originals, not a current graph with
    /// selected components removed. Its external provenance record binds both
    /// the original corpus and the closed database bytes.
    @Test(.globalRuntimeStateIsolation)
    func historicalAuthenticCBQV16GraphPreservesMissingMinimumDueThroughV17() throws {
        let environment = ProcessInfo.processInfo.environment
        let originalDatabase = URL(fileURLWithPath: try #require(
            environment["LEDGERFORGE_CBQ_V16_AUTHENTIC_DATABASE"]
        ))
        let evidenceURL = URL(fileURLWithPath: try #require(
            environment["LEDGERFORGE_CBQ_V16_AUTHENTIC_EVIDENCE"]
        ))
        let root = URL(fileURLWithPath: try #require(
            environment["LEDGERFORGE_PRIVATE_CBQ_TEXT_DIRECTORY"]
        ))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let export = try decoder.decode(HistoricalCBQExport.self, from: Data(contentsOf: evidenceURL))
        let sourceURLs = try sourceURLsByDigest(root: root)
        let sourceInventory = sourceDigest(Data(
            (sourceURLs.keys.sorted().joined(separator: "\n") + "\n").utf8
        ))
        let historicalRules: Set<String> = [
            "cbq.qar.v1.previous-plus-billed-minus-payment.v1",
            "cbq.qar.v2.previous-minus-payment-minus-credit-plus-components.v1"
        ]
        try #require(export.schema == "ledgerforge.cbq-v16-authentic-database-export.v1")
        try #require(export.sourceAuthority == "complete-immutable-authentic-cbq-card-corpus")
        try #require(export.sourceInventorySha256 == sourceInventory)
        try #require(sourceURLs.count == 19 && export.sourceCount == 19)
        try #require(export.cardStatementCount == 19 && export.transactionCount == 352)
        try #require(export.cardSectionCount == 38 && export.cardInstrumentCount == 2)
        try #require(export.cardTransactionEvidenceCount == 352)
        try #require(export.migrationVersion == 16 && export.minimumAmountDuePersistedCount == 0)
        try #require(Set(export.reconciliationRuleCounts.keys) == historicalRules)
        try #require(export.reconciliationRuleCounts.values.reduce(0, +) == 19)
        try #require(try sourceDigest(originalDatabase) == export.databaseSha256)

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-CBQ-Historical-V17-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let copy = folder.appendingPathComponent("authentic-historical-v16.sqlite")
        try FileManager.default.copyItem(at: originalDatabase, to: copy)
        try #require(try sourceDigest(copy) == export.databaseSha256)
        let workspaceID = "cbq-v16-authentic-export"

        let oldSQLite = try SQLiteRepositoryProvider(
            path: copy.path, migrations: Array(allMigrations.prefix(16))
        )
        defer { oldSQLite.database.close() }
        try installCurrentReaderCompatibilityView(oldSQLite.database)
        let oldProvider = DatabaseProvider.verifiedSQLite(oldSQLite, protectsGeneration: false)
        let history = try oldSQLite.database.validatedMigrationHistory(
            against: Array(allMigrations.prefix(16)), requiresCompleteChain: true
        )
        try #require(history.compactMap(\.version) == Array(1...16))
        let before = try projectionGraphSnapshot(oldProvider, workspaceID: workspaceID)
        let cardsBefore = try oldProvider.cardRepo.snapshot(workspaceId: workspaceID)
        let orderedStatements = cardsBefore.statements.sorted { $0.id < $1.id }
        let documentsBefore = try orderedStatements.map {
            try #require(try oldProvider.importSessionRepo.importedDocument(id: $0.documentId))
        }
        let sessionsBefore = try orderedStatements.map {
            try #require(try oldProvider.importSessionRepo.importSession(id: $0.importSessionId))
        }
        let fingerprintsBefore = try migrationSourceFingerprints(oldSQLite.database)
        try #require(before.accounts.count == 1 && before.transactions.count == 352)
        try #require(before.attempts.count == 19 && cardsBefore.statements.count == 19)
        try #require(cardsBefore.sections.count == 38 && cardsBefore.transactionEvidence.count == 352)
        try #require(cardsBefore.instruments.count == 2)
        try #require(Set(cardsBefore.statements.map(\.reconciliationRuleCode)) == historicalRules)
        try #require(!cardsBefore.summaryComponents.contains { $0.componentCode == "minimum_amount_due" })
        let sourceFingerprints = try oldSQLite.database.query(
            sql: "SELECT fingerprint FROM document_fingerprints WHERE algorithm = ? AND is_duplicate_authority = 1;",
            params: [DocumentFingerprintDTO.sourceBytesSHA256Algorithm]
        ) { try #require($0.string(at: 0)) }
        try #require(sourceFingerprints.count == 19 && Set(sourceFingerprints) == Set(sourceURLs.keys))
        try oldSQLite.database.checkpointAndClose()

        let upgradedSQLite = try SQLiteRepositoryProvider(path: copy.path)
        defer { upgradedSQLite.database.close() }
        let upgraded = DatabaseProvider.verifiedSQLite(upgradedSQLite, protectsGeneration: false)
        try verifyDatabaseIntegrity(upgradedSQLite.database, expectedVersion: 17,
                                    expectsV17Schema: true, expectedLegacyAlterTable: 0)
        #expect(try projectionGraphSnapshot(upgraded, workspaceID: workspaceID) == before)
        #expect(try upgraded.cardRepo.snapshot(workspaceId: workspaceID) == cardsBefore)
        #expect(try migrationSourceFingerprints(upgradedSQLite.database) == fingerprintsBefore)
        for (index, statement) in orderedStatements.enumerated() {
            #expect(try upgraded.importSessionRepo.importedDocument(id: statement.documentId) == documentsBefore[index])
            #expect(try upgraded.importSessionRepo.importSession(id: statement.importSessionId) == sessionsBefore[index])
        }
        let upgradedHydration = try hydrate(provider: upgraded, workspaceID: workspaceID)
        #expect(upgradedHydration.result.accountCount == 1)
        #expect(upgradedHydration.result.transactionCount == 352)
        #expect(upgradedHydration.result.importSessionCount == 19)
        #expect(upgradedHydration.stores.cards.snapshot.statements.count == 19)
        #expect(upgradedHydration.stores.cards.snapshot.statements.allSatisfy { $0.minimumAmountDue == nil })
        try verifyHydratedHistoricalCBQGraph(
            before,
            cardsBefore: cardsBefore,
            stores: upgradedHydration.stores,
            workspaceID: workspaceID,
            phase: "post-migration"
        )
        try upgradedSQLite.database.checkpointAndClose()

        let reopenedSQLite = try SQLiteRepositoryProvider(path: copy.path)
        defer { reopenedSQLite.database.close() }
        let reopened = DatabaseProvider.verifiedSQLite(reopenedSQLite, protectsGeneration: false)
        #expect(try projectionGraphSnapshot(reopened, workspaceID: workspaceID) == before)
        #expect(try reopened.cardRepo.snapshot(workspaceId: workspaceID) == cardsBefore)
        #expect(try migrationSourceFingerprints(reopenedSQLite.database) == fingerprintsBefore)
        for (index, statement) in orderedStatements.enumerated() {
            #expect(try reopened.importSessionRepo.importedDocument(id: statement.documentId) == documentsBefore[index])
            #expect(try reopened.importSessionRepo.importSession(id: statement.importSessionId) == sessionsBefore[index])
        }
        #expect(try reopenedSQLite.database.query(sql: "PRAGMA foreign_key_check;") { _ in true }.isEmpty)
        let reopenedHydration = try hydrate(provider: reopened, workspaceID: workspaceID)
        #expect(reopenedHydration.result.transactionCount == 352)
        #expect(reopenedHydration.result.importSessionCount == 19)
        #expect(reopenedHydration.stores.cards.snapshot.statements.count == 19)
        #expect(reopenedHydration.stores.cards.snapshot.statements.allSatisfy { $0.minimumAmountDue == nil })
        try verifyHydratedHistoricalCBQGraph(
            before,
            cardsBefore: cardsBefore,
            stores: reopenedHydration.stores,
            workspaceID: workspaceID,
            phase: "reopen"
        )
        #expect(try sourceDigest(originalDatabase) == export.databaseSha256)
        for (digest, source) in sourceURLs {
            #expect(try sourceDigest(source) == digest)
        }
    }

    private func migrationSourceFingerprints(_ database: SQLiteDatabase) throws -> [[String?]] {
        try database.query(sql: """
            SELECT id, document_id, import_session_id, algorithm, fingerprint,
                   fingerprint_data, created_at, is_duplicate_authority
            FROM document_fingerprints ORDER BY id;
            """) { row in
                (0..<8).map { row.string(at: Int32($0)) }
        }
    }

    /// Compares only fields published by the runtime stores with their exact
    /// durable values from the authentic V16 export. No financial values are
    /// authored here: every expected date, Money, direction, label, identity,
    /// ordering value, and provenance value comes from the preserved database.
    private func verifyHydratedHistoricalCBQGraph(
        _ graph: ProjectionGraphSnapshot,
        cardsBefore: CardRepositorySnapshotDTO,
        stores: HydrationStores,
        workspaceID: String,
        phase: String
    ) throws {
        let accountsByID = Dictionary(uniqueKeysWithValues: graph.accounts.map { account in
            (account.id, account)
        })
        let hydratedAccountsByID = try Dictionary(uniqueKeysWithValues: stores.accounts.accounts.map { account in
            (try #require(account.repositoryAccountId), account)
        })
        #expect(Set(hydratedAccountsByID.keys) == Set(accountsByID.keys), "\(phase): account identities")
        for expected in graph.accounts {
            let actual = try #require(hydratedAccountsByID[expected.id])
            #expect(actual.workspaceId == expected.workspaceId, "\(phase): account workspace")
            #expect(actual.workspaceId == workspaceID, "\(phase): expected workspace")
            #expect(actual.name == expected.name, "\(phase): account name")
            #expect(actual.institution == (expected.institutionId ?? "Unknown"), "\(phase): institution")
            #expect(actual.nativeCurrency.code == expected.nativeCurrency, "\(phase): account currency")
            #expect(actual.type == .creditCard && expected.accountType == "credit_card", "\(phase): account type")
        }

        let transactionEvidenceByID = Dictionary(
            uniqueKeysWithValues: cardsBefore.transactionEvidence.map { ($0.transactionId, $0) }
        )
        let hydratedTransactionsByID = try Dictionary(
            uniqueKeysWithValues: stores.transactions.transactions.map { transaction in
                (try #require(transaction.repositoryTransactionId), transaction)
            }
        )
        #expect(
            Set(hydratedTransactionsByID.keys) == Set(graph.transactions.map(\.id)),
            "\(phase): all authentic transactions published"
        )
        for expected in graph.transactions {
            let actual = try #require(hydratedTransactionsByID[expected.id])
            let account = try #require(expected.accountId.flatMap { accountsByID[$0] })
            let annotation = try #require(transactionEvidenceByID[expected.id])
            #expect(actual.statementDate?.canonical == expected.postedDateISO, "\(phase): transaction date")
            #expect(actual.valueDate?.canonical == expected.valueDateISO, "\(phase): value date")
            #expect(actual.financialDateRole.rawValue == expected.financialDateRole, "\(phase): date role")
            #expect(
                actual.statementTimezoneEvidence.persistenceCode == expected.statementTimezoneEvidence,
                "\(phase): timezone evidence"
            )
            #expect(actual.description == (expected.description ?? ""), "\(phase): narration")
            #expect(actual.reference == expected.reference, "\(phase): reference")
            #expect(
                hydratedMoneyMatches(
                    actual.money,
                    currency: expected.nativeCurrency,
                    minor: expected.amountMinor,
                    decimal: expected.amountDecimal
                ),
                "\(phase): signed transaction Money"
            )
            if let runningBalance = expected.runningBalanceMinor {
                let hydratedRunningBalance = try actual.runningBalanceMoney?.minorUnits()
                #expect(
                    actual.runningBalanceMoney?.currency.code == expected.nativeCurrency &&
                        hydratedRunningBalance == runningBalance,
                    "\(phase): running balance"
                )
            } else {
                #expect(actual.runningBalanceMoney == nil, "\(phase): absent running balance")
            }
            if expected.direction == "debit" {
                #expect(actual.debitMoney?.amount == abs(actual.money.amount), "\(phase): debit direction")
                #expect(actual.creditMoney == nil, "\(phase): debit credit-absence")
            } else if expected.direction == "credit" {
                #expect(actual.creditMoney?.amount == abs(actual.money.amount), "\(phase): credit direction")
                #expect(actual.debitMoney == nil, "\(phase): credit debit-absence")
            } else {
                #expect(actual.debitMoney == nil && actual.creditMoney == nil, "\(phase): card direction")
            }
            #expect(annotation.liabilityEffectCode == expected.direction, "\(phase): stored liability direction")
            #expect(actual.cardLiabilityEffect?.rawValue == annotation.liabilityEffectCode,
                    "\(phase): hydrated liability direction")
            #expect(actual.account == account.name, "\(phase): transaction account label")
            #expect(actual.sourceBank == (account.institutionId ?? ""), "\(phase): transaction institution")
            #expect(actual.sourceFile == (expected.importSessionId ?? ""), "\(phase): transaction source session")
            #expect(actual.repositoryAccountId == expected.accountId, "\(phase): account ownership")
            #expect(actual.repositoryImportSessionId == expected.importSessionId, "\(phase): session ownership")
            #expect(actual.repositoryDocumentId == expected.documentId, "\(phase): document ownership")
            #expect(actual.verifiedAxisUPIEventEvidence == nil, "\(phase): CBQ has no Axis UPI evidence")
            #expect(actual.sourceProvenance.count == expected.rawRows.count, "\(phase): provenance cardinality")
            for (source, durable) in zip(actual.sourceProvenance, expected.rawRows) {
                #expect(source.normalizedDocumentID == durable.normalizedDocumentId,
                        "\(phase): provenance document")
                #expect(source.normalizedRowID == durable.normalizedRowId, "\(phase): provenance row")
                #expect(source.sourceOrdinal == durable.sourceOrdinal, "\(phase): provenance source order")
                #expect(source.normalizedRecordDigest == durable.normalizedRecordDigest,
                        "\(phase): provenance record digest")
                #expect(source.parserProfileID == durable.parserProfileId, "\(phase): provenance profile")
                #expect(source.parserProfileVersion == durable.parserProfileVersion,
                        "\(phase): provenance profile version")
                #expect(source.sourcePage == nil && source.sourceTransactionDate == nil &&
                        source.structuredReferenceDigest == nil,
                        "\(phase): non-persisted provenance remains absent")
            }
        }

        let card = stores.cards.snapshot
        #expect(card.instruments.count == cardsBefore.instruments.count, "\(phase): card instruments")
        #expect(card.relationships.count == cardsBefore.relationships.count, "\(phase): card relationships")
        #expect(card.statements.count == cardsBefore.statements.count, "\(phase): card statements")
        #expect(card.transactionEvidence.count == cardsBefore.transactionEvidence.count,
                "\(phase): card annotations")

        let instrumentsByID = Dictionary(uniqueKeysWithValues: card.instruments.map { ($0.id, $0) })
        let durableSectionByID = Dictionary(uniqueKeysWithValues: cardsBefore.sections.map { ($0.id, $0) })
        for expected in cardsBefore.instruments {
            let actual = try #require(instrumentsByID[expected.id])
            #expect(actual.workspaceID == expected.workspaceId, "\(phase): instrument workspace")
            #expect(actual.liabilityAccountID == expected.liabilityAccountId, "\(phase): instrument ownership")
            #expect(actual.lifecycleState.rawValue == expected.lifecycleStateCode, "\(phase): instrument lifecycle")
            #expect(actual.createdAtISO == expected.createdAtISO, "\(phase): instrument creation")
            let expectedObservations = cardsBefore.sourceObservations.filter {
                $0.subjectKind == CardSourceIdentitySubject.instrument.rawValue && $0.subjectId == expected.id
            }.map { "\($0.observationKind)|\($0.subjectKind)|\($0.sourceValue)" } +
                cardsBefore.sectionObservations.filter {
                    durableSectionByID[$0.cardStatementSectionId]?.instrumentId == expected.id
                }.map {
                    "\($0.observationKind)|\(CardSourceIdentitySubject.instrument.rawValue)|\($0.sourceValue)"
                }
            let actualObservations = actual.sourceObservations.map {
                "\($0.kind.rawValue)|\($0.subject.rawValue)|\($0.value)"
            }
            #expect(actualObservations.sorted() == expectedObservations.sorted(),
                    "\(phase): instrument source observations")
        }

        let expectedAccountObservations = cardsBefore.sourceObservations.filter {
            $0.subjectKind == CardSourceIdentitySubject.liabilityAccount.rawValue
        }.map { "\($0.observationKind)|\($0.subjectKind)|\($0.sourceValue)" }.sorted()
        let actualAccountObservations = card.sourceObservations.map {
            "\($0.kind.rawValue)|\($0.subject.rawValue)|\($0.value)"
        }.sorted()
        #expect(actualAccountObservations == expectedAccountObservations,
                "\(phase): liability source observations")

        let statementsByID = Dictionary(uniqueKeysWithValues: card.statements.map { ($0.id, $0) })
        for expected in cardsBefore.statements {
            let actual = try #require(statementsByID[expected.id])
            let expectedSections = cardsBefore.sections.filter { $0.cardStatementId == expected.id }
                .sorted { $0.sourceOrdinal < $1.sourceOrdinal }
            #expect(actual.liabilityAccountID == expected.liabilityAccountId,
                    "\(phase): statement account ownership")
            #expect(actual.instrumentIDs == expectedSections.map(\.instrumentId),
                    "\(phase): statement instrument order")
            #expect(actual.sourceDocumentID == expected.documentId, "\(phase): statement document")
            #expect(actual.importSessionID == expected.importSessionId, "\(phase): statement session")
            #expect(actual.parserProfileID == expected.parserProfileId, "\(phase): statement profile")
            #expect(actual.parserProfileVersion == expected.parserProfileVersion,
                    "\(phase): statement profile version")
            #expect(actual.statementDate?.canonical == expected.statementDateISO,
                    "\(phase): statement date")
            #expect(actual.period?.start.canonical == expected.statementStartDateISO,
                    "\(phase): statement period start")
            #expect(actual.period?.end.canonical == expected.statementEndDateISO,
                    "\(phase): statement period end")
            #expect(actual.selectedStatementMonth?.canonical == expected.selectedStatementMonthISO,
                    "\(phase): selected statement month")
            #expect(actual.semanticGroupID == nil, "\(phase): historical CBQ has no semantic group")
            #expect(actual.currency.code == expected.statementCurrency, "\(phase): statement currency")
            #expect(actual.sourceRowCount == expected.sourceRowCount, "\(phase): statement row count")
            #expect(actual.reconciliationRuleCode == expected.reconciliationRuleCode,
                    "\(phase): historical reconciliation rule")

            let expectedSummary = cardsBefore.summaryComponents.filter { $0.cardStatementId == expected.id }
            #expect(actual.summaryComponents.count == expectedSummary.count, "\(phase): summary cardinality")
            let actualSummaryByCode = Dictionary(
                uniqueKeysWithValues: actual.summaryComponents.map { ($0.persistenceCode, $0) }
            )
            #expect(Set(actualSummaryByCode.keys) == Set(expectedSummary.map(\.componentCode)),
                    "\(phase): summary component codes")
            for component in expectedSummary {
                let runtime = try #require(actualSummaryByCode[component.componentCode])
                #expect(
                    hydratedMoneyMatches(
                        runtime.money,
                        currency: component.moneyCurrency,
                        minor: component.moneyMinor,
                        decimal: component.moneyDecimal
                    ),
                    "\(phase): summary Money \(component.componentCode)"
                )
                #expect(runtime.date?.canonical == component.dateISO,
                        "\(phase): summary date \(component.componentCode)")
            }
            #expect(!expectedSummary.contains { $0.componentCode == "minimum_amount_due" } &&
                    actual.minimumAmountDue == nil,
                    "\(phase): genuine V16 minimum-due absence")

            #expect(actual.sections.map(\.id) == expectedSections.map(\.id),
                    "\(phase): statement section source order")
            for (runtime, section) in zip(actual.sections, expectedSections) {
                #expect(runtime.documentScopedSectionID == section.documentScopedSectionId,
                        "\(phase): document-scoped section")
                #expect(runtime.sourceOrdinal == section.sourceOrdinal, "\(phase): section ordinal")
                #expect(runtime.instrumentID == section.instrumentId, "\(phase): section instrument")
                #expect(runtime.holderLabel == section.holderLabel, "\(phase): section holder")
                #expect(
                    hydratedMoneyMatches(
                        runtime.signedTotal,
                        currency: section.signedTotalCurrency,
                        minor: section.signedTotalMinor,
                        decimal: section.signedTotalDecimal
                    ),
                    "\(phase): section signed total"
                )
                #expect(runtime.reconciliationRuleCode == section.reconciliationRuleCode,
                        "\(phase): section reconciliation rule")
                let expectedObservations = cardsBefore.sectionObservations.filter {
                    $0.cardStatementSectionId == section.id
                }.map { "\($0.observationKind)|\($0.sourceValue)" }.sorted()
                let actualObservations = runtime.sourceObservations.map {
                    "\($0.kind.rawValue)|\($0.value)"
                }.sorted()
                #expect(actualObservations == expectedObservations,
                        "\(phase): section source observations")
            }
        }

        let hydratedEvidenceByTransactionID = Dictionary(
            uniqueKeysWithValues: card.transactionEvidence.map { ($0.transactionID, $0) }
        )
        #expect(Set(hydratedEvidenceByTransactionID.keys) == Set(transactionEvidenceByID.keys),
                "\(phase): annotation transaction ownership")
        for expected in cardsBefore.transactionEvidence {
            let actual = try #require(hydratedEvidenceByTransactionID[expected.transactionId])
            #expect(actual.statementID == expected.cardStatementId, "\(phase): annotation statement")
            #expect(actual.transactionID == expected.transactionId, "\(phase): annotation transaction")
            #expect(actual.financialScope.persistenceCode == expected.rowScopeCode,
                    "\(phase): annotation scope")
            #expect(actual.documentScopedSectionID == expected.documentScopedSectionId,
                    "\(phase): annotation section")
            #expect(actual.instrumentID == expected.instrumentId, "\(phase): annotation instrument")
            #expect(actual.liabilityEffect.rawValue == expected.liabilityEffectCode,
                    "\(phase): annotation liability effect")
            #expect(actual.sourceTransactionDate.canonical == expected.sourceTransactionDateISO,
                    "\(phase): annotation source date")
            #expect(
                hydratedMoneyMatches(
                    actual.originalMerchantMoney,
                    currency: expected.originalCurrency,
                    minor: expected.originalAmountMinor,
                    decimal: expected.originalAmountDecimal
                ),
                "\(phase): annotation original Money"
            )
            #expect(actual.summaryMembership?.rawValue == expected.summaryMembershipCode,
                    "\(phase): annotation summary membership")
        }
    }

    private func hydratedMoneyMatches(
        _ money: Money?,
        currency: String?,
        minor: Int64?,
        decimal: String?
    ) -> Bool {
        switch (money, currency, minor, decimal) {
        case (nil, nil, nil, nil):
            return true
        case let (money?, currency?, minor?, decimal?):
            return money.currency.code == currency &&
                (try? money.minorUnits()) == minor &&
                (try? money.canonicalDecimalString()) == decimal
        default:
            return false
        }
    }

    private func amexSectionChoice(
        _ document: FinancialDocument,
        accountID: String,
        snapshot: CardRepositorySnapshotDTO
    ) throws -> ImportAccountChoice {
        let evidence = try #require(document.cardStatementEvidence)
        let choices = try Dictionary(uniqueKeysWithValues: evidence.instrumentSections.map { section in
            let value = try #require(section.sourceIdentityObservations.first?.value)
            let matchingIDs = Set(snapshot.sectionObservations.compactMap { observation -> String? in
                guard observation.sourceValue == value,
                      let priorSection = snapshot.sections.first(where: { $0.id == observation.cardStatementSectionId }),
                      snapshot.instruments.contains(where: { $0.id == priorSection.instrumentId && $0.liabilityAccountId == accountID }) else { return nil }
                return priorSection.instrumentId
            })
            try #require(matchingIDs.count <= 1)
            let choice: ImportCardInstrumentChoice = matchingIDs.first.map {
                .reuseExistingInstrument(instrumentId: $0)
            } ?? .createNewInstrument()
            return (section.documentScopedSectionID, choice)
        })
        return .useExistingCardLiabilityAccountSections(accountId: accountID, sectionChoices: choices)
    }

    private func verifyOracleShape(
        _ hdfc: HDFCOracle,
        axisOracle: AxisOracle,
        axisSources: [String: URL]
    ) throws {
        #expect(hdfc.totals.pdfCarriers == 4)
        #expect(hdfc.totals.xlsCarriers == 4)
        #expect(hdfc.totals.logicalStatements == 4)
        #expect(hdfc.totals.canonicalRows == 165)
        #expect(hdfc.totals.representationRows == 330)
        let hdfcGroups = Dictionary(
            grouping: hdfc.carriers.pdf + hdfc.carriers.xls,
            by: \HDFCCarrier.logicalStatementKey
        )
        #expect(hdfcGroups.count == 4)
        #expect(hdfcGroups.values.allSatisfy {
            $0.count == 2 && Set($0.map(\.sourceFormat)) == ["pdf", "xls"] &&
                Set($0.map { $0.rows.count }).count == 1 &&
                $0.allSatisfy { carrier in
                    carrier.currency == "INR" && carrier.rows.allSatisfy { !$0.valueDate.isEmpty }
                }
        })

        #expect(axisOracle.corpus.carrierCount == 9)
        #expect(axisOracle.corpus.logicalStatementCount == 3)
        #expect(axisOracle.corpus.canonicalEventCount == 182)
        #expect(axisOracle.corpus.representationRowCount == 546)
        #expect(axisOracle.carriers.count == 9)
        #expect(axisSources.count == 9)
        #expect(Set(axisOracle.carriers.map(\.sourceSha256)) == Set(axisSources.keys))
    }

    private func importHDFCCorpus(
        _ carriers: [HDFCCarrier],
        root: URL,
        engine: ImportEngine
    ) async throws {
        var representedStatements = Set<String>()
        var createdAccounts = Set<String>()
        let ordered = carriers.sorted {
            if $0.sourceFormat != $1.sourceFormat { return $0.sourceFormat == "pdf" }
            return $0.logicalStatementKey < $1.logicalStatementKey
        }
        for carrier in ordered {
            let source = root.appendingPathComponent(carrier.carrier)
            let prepared = try await engine.prepareImport(from: source)
            #expect(try prepared.sourceSnapshot.withBytes(sourceDigest) == carrier.sha256)
            #expect(prepared.detectedInstitution == .hdfc)
            #expect(prepared.detectedDocumentType == .bankAccount)
            #expect(prepared.validation.passed)
            #expect(prepared.financialDocument.transactions.count == carrier.rows.count)
            #expect(prepared.financialDocument.transactions.allSatisfy { $0.valueDate != nil })
            let isAuthoritative = representedStatements.insert(carrier.logicalStatementKey).inserted
            let createsAccount = createdAccounts.insert(carrier.account).inserted
            let committed = await engine.commitPreparedImport(
                prepared,
                accountChoice: createsAccount ? .createNewAccount : nil
            )
            engine.cancelPreparedImport(prepared)
            #expect(committed.persisted)
            #expect(committed.isEquivalentSupportingSource == !isAuthoritative)
            #expect(committed.transactionCount == (isAuthoritative ? carrier.rows.count : 0))
            guard committed.persisted else { throw MigrationAcceptanceError.importFailed }
        }
        #expect(representedStatements.count == 4)
        #expect(createdAccounts.count == 2)
    }

    private func importAxisCorpus(
        _ carriers: [AxisCarrier],
        sources: [String: URL],
        engine: ImportEngine
    ) async throws {
        let formatRank = ["csv": 0, "pdf": 1, "xls": 2]
        let ordered = carriers.sorted {
            if $0.logicalStatementId != $1.logicalStatementId {
                return $0.logicalStatementId < $1.logicalStatementId
            }
            return formatRank[$0.format, default: 9] < formatRank[$1.format, default: 9]
        }
        var representedStatements = Set<String>()
        var createdAccounts = Set<String>()
        for carrier in ordered {
            let source = try #require(sources[carrier.sourceSha256])
            let prepared = try await engine.prepareImport(from: source)
            #expect(try prepared.sourceSnapshot.withBytes(sourceDigest) == carrier.sourceSha256)
            #expect(prepared.sourceSnapshot.byteCount == carrier.sourceSize)
            #expect(prepared.detectedInstitution == .axis)
            #expect(prepared.detectedDocumentType == .bankAccount)
            #expect(prepared.validation.passed)
            #expect(prepared.financialDocument.transactions.count == carrier.rowCount)
            #expect(prepared.financialDocument.transactions.allSatisfy { $0.valueDate == nil })
            let isAuthoritative = representedStatements.insert(carrier.logicalStatementId).inserted
            let createsAccount = createdAccounts.insert(carrier.accountIdentifierSha256).inserted
            let committed = await engine.commitPreparedImport(
                prepared,
                accountChoice: createsAccount ? .createNewAccount : nil
            )
            engine.cancelPreparedImport(prepared)
            #expect(committed.persisted)
            #expect(committed.isEquivalentSupportingSource == !isAuthoritative)
            #expect(committed.transactionCount == (isAuthoritative ? carrier.rowCount : 0))
            guard committed.persisted else { throw MigrationAcceptanceError.importFailed }
        }
        #expect(representedStatements.count == 3)
        #expect(createdAccounts.count == 2)
    }

    private func projectionGraphSnapshot(
        _ provider: DatabaseProvider,
        workspaceID: String
    ) throws -> ProjectionGraphSnapshot {
        ProjectionGraphSnapshot(
            accounts: try provider.accountRepo.accounts(workspaceId: workspaceID).sorted { $0.id < $1.id },
            transactions: try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
                .sorted { $0.id < $1.id },
            projections: try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspaceID)
                .sorted { $0.projection.id < $1.projection.id },
            groups: try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceID)
                .sorted { $0.id < $1.id },
            members: try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceID)
                .sorted { $0.id < $1.id },
            attempts: try provider.importSessionRepo.importAttempts(workspaceId: workspaceID)
                .sorted { $0.id < $1.id }
        )
    }

    private func graphCounts(
        _ provider: DatabaseProvider,
        workspaceID: String
    ) throws -> GraphCounts {
        GraphCounts(
            accounts: try provider.accountRepo.accounts(workspaceId: workspaceID).count,
            transactions: try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count,
            projections: try provider.importSessionRepo.statementFinancialProjections(workspaceId: workspaceID).count,
            groups: try provider.importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceID).count,
            members: try provider.importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceID).count,
            attempts: try provider.importSessionRepo.importAttempts(workspaceId: workspaceID).count,
            zeroActivityControls: try provider.importSessionRepo.statementZeroActivityControls(
                workspaceId: workspaceID
            ).count
        )
    }

    private func verifyDatabaseIntegrity(
        _ database: SQLiteDatabase,
        expectedVersion: Int,
        expectsV17Schema: Bool,
        expectedLegacyAlterTable: Int
    ) throws {
        let migrations = Array(allMigrations.prefix(expectedVersion))
        let records = try database.validatedMigrationHistory(
            against: migrations,
            requiresCompleteChain: true
        )
        #expect(records.compactMap(\.version) == Array(1...expectedVersion))
        #expect(try database.query(sql: "PRAGMA foreign_key_check;") { _ in true }.isEmpty)
        #expect(try database.query(sql: "PRAGMA integrity_check;") {
            try #require($0.string(at: 0))
        } == ["ok"])
        #expect(try database.queryInt("PRAGMA foreign_keys;") == 1)
        #expect(
            try database.queryInt("PRAGMA legacy_alter_table;") == expectedLegacyAlterTable
        )

        for (table, expectedForeignKeys) in [
            ("statement_financial_projections", 4),
            ("statement_financial_projection_events", 1),
            ("statement_equivalence_groups", 3),
            ("statement_equivalence_members", 2)
        ] {
            #expect(try database.query(sql: "PRAGMA foreign_key_list(\(table));") {
                _ in true
            }.count == expectedForeignKeys)
        }
        let valueDateNotNull = try #require(database.query(
            sql: "PRAGMA table_info(statement_financial_projection_events);"
        ) { row in
            (row.string(at: 1), row.int64(at: 3))
        }.first { $0.0 == "value_date" }?.1)
        #expect(valueDateNotNull == (expectsV17Schema ? 0 : 1))

        let objectNames = Set(try database.query(sql: """
            SELECT name FROM sqlite_master
            WHERE type IN ('table', 'index', 'trigger');
            """) { try #require($0.string(at: 0)) })
        #expect(!objectNames.contains { $0.hasSuffix("_v16") })
        #expect(objectNames.contains("idx_statement_projection_group_lookup"))
        #expect(objectNames.contains("idx_statement_equivalence_one_authoritative_member"))
        #expect(objectNames.contains("validate_statement_projection_relationships"))
        #expect(objectNames.contains("validate_statement_equivalence_group"))
        #expect(objectNames.contains("validate_statement_equivalence_member"))
        #expect(objectNames.contains("validate_statement_projection_event_value_date") == expectsV17Schema)
    }

    /// Current V17 readers include the zero-activity table in read-only joins.
    /// V16 predates that table, so this connection-local, zero-row view exposes
    /// only the expected column surface while authentic transaction-bearing
    /// statements populate the durable V16 schema. It vanishes on close before
    /// the real V17 migration runs and can neither persist nor invent a control.
    private func installCurrentReaderCompatibilityView(_ database: SQLiteDatabase) throws {
        try database.execute(sql: """
            CREATE TEMP VIEW statement_zero_activity_controls AS
            SELECT
              NULL AS id,
              NULL AS workspace_id,
              NULL AS account_id,
              NULL AS document_id,
              NULL AS import_session_id,
              NULL AS normalized_document_id,
              NULL AS parser_profile_id,
              NULL AS parser_profile_version,
              NULL AS source_format_code,
              NULL AS institution_code,
              NULL AS statement_family_code,
              NULL AS statement_date,
              NULL AS statement_start_date,
              NULL AS statement_end_date,
              NULL AS selected_statement_month,
              NULL AS semantic_cycle_key,
              NULL AS native_currency,
              NULL AS opening_balance_minor,
              NULL AS opening_balance_decimal,
              NULL AS closing_balance_minor,
              NULL AS closing_balance_decimal,
              NULL AS debit_total_minor,
              NULL AS debit_total_decimal,
              NULL AS credit_total_minor,
              NULL AS credit_total_decimal,
              NULL AS card_previous_balance_minor,
              NULL AS card_previous_balance_decimal,
              NULL AS card_total_payment_due_minor,
              NULL AS card_total_payment_due_decimal,
              NULL AS card_payment_due_date,
              NULL AS evidence_kind,
              NULL AS financial_region_descriptor,
              NULL AS financial_region_source_unit,
              NULL AS financial_region_start_ordinal,
              NULL AS financial_region_end_ordinal,
              NULL AS financial_region_signature,
              NULL AS semantic_digest_algorithm,
              NULL AS semantic_digest,
              NULL AS source_fingerprint_algorithm,
              NULL AS source_fingerprint_digest,
              NULL AS authority_role,
              NULL AS created_at
            WHERE 0;
            """)
    }

    private func hydrate(
        provider: DatabaseProvider,
        workspaceID: String
    ) throws -> (result: RepositoryStoreHydrationResult, stores: HydrationStores) {
        let stores = HydrationStores()
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo,
            accountStore: stores.accounts,
            transactionStore: stores.transactions,
            categoryStore: stores.categories,
            cardStore: stores.cards,
            importSessionStore: stores.sessions,
            importAttemptStore: stores.attempts,
            workspaceId: workspaceID,
            persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken,
            participatesInLifecycleGate: false
        )
        return (try hydrator.hydrateIfNeeded(forceRefresh: true), stores)
    }

    private func makeEngine(
        provider: DatabaseProvider,
        workspaceID: String,
        hdfcPassword: String,
        amexPassword: String? = nil
    ) -> ImportEngine {
        let stores = HydrationStores()
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo,
            accountStore: stores.accounts,
            transactionStore: stores.transactions,
            categoryStore: stores.categories,
            cardStore: stores.cards,
            importSessionStore: stores.sessions,
            importAttemptStore: stores.attempts,
            workspaceId: workspaceID,
            persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken,
            participatesInLifecycleGate: false
        )
        var passwords = [Institution.hdfc.statementPasswordCredentialScope: hdfcPassword]
        if let amexPassword { passwords[Institution.amex.statementPasswordCredentialScope] = amexPassword }
        let credentials = InMemoryStatementPasswordCredentialStore(passwords: passwords)
        return ImportEngine(
            importCoordinator: DefaultImportCoordinator(
                readerRegistry: DefaultReaderRegistry(),
                passwordProvider: DefaultPasswordProvider(
                    credentialStore: credentials,
                    supportedInstitutionCodes: passwords.keys.sorted(),
                    challenge: { _ in nil }
                )
            ),
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(
                databaseProvider: provider,
                mapper: ImportPersistenceMapper(
                    workspaceId: workspaceID,
                    workspaceName: "Authentic V16 to V17 migration acceptance"
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
    }

    private func sourceURLsByDigest(root: URL) throws -> [String: URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { throw MigrationAcceptanceError.corpusUnavailable }
        var result: [String: URL] = [:]
        for case let url as URL in enumerator {
            guard ["csv", "pdf", "xls"].contains(url.pathExtension.lowercased()),
                  try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
                continue
            }
            let digest = try sourceDigest(url)
            guard result[digest] == nil else {
                throw MigrationAcceptanceError.duplicateSourceDigest
            }
            result[digest] = url
        }
        return result
    }

    private func sourceDigest(_ url: URL) throws -> String {
        sourceDigest(try Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    private func sourceDigest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private enum MigrationAcceptanceError: Error {
        case corpusUnavailable
        case duplicateSourceDigest
        case importFailed
    }
}
