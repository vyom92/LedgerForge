import Foundation
import CryptoKit
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct MovementIntelligenceTests {
    private struct EligibilityNomination: Decodable {
        let ids: [String: String]
        let expected: [String: [String]]
    }
    private struct OwnerRuleNomination: Decodable {
        let categoryID: String, categoryName: String
        let rule: CategoryRule
        let expectedTransactionIDs: [String]
    }
    private struct TrendOracle: Decodable {
        let accountID: String, currency: String
        let analysis: Period, baseline: Period
        let originalHashes: [String]
        struct Period: Decodable {
            let start: String, end: String, income: String, spending: String, purchaseAmount: String
            let purchaseIDs: [String], unresolvedIDs: [String], unresolvedGross: String
        }
    }
    private struct SourceCase: Decodable {
        let kind: MovementKind, ids: [String], consumption: [String], amounts: [String], dates: [String], currency: String, spending: String, income: String
    }
    private func cases() throws -> [SourceCase] {
        return try JSONDecoder().decode([SourceCase].self, from: AuthenticSourceTestSupport.ramNomination("LEDGERFORGE_S99_MOVEMENT_CASES"))
    }
    private func restoredCopy() throws -> (URL, SQLiteRepositoryProvider) {
        let path = try #require(ProcessInfo.processInfo.environment["LEDGERFORGE_S99_V26_BACKUP"])
        let package = URL(fileURLWithPath: path), manifest = try BackupFiles.verifyPackage(package)
        #expect(manifest.schemaVersion == 26)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s99-movement-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let target = folder.appendingPathComponent("qualification.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: target)
        return (folder, try SQLiteRepositoryProvider(path: target.path, migrations: allMigrations, access: .existing))
    }
    private func event(_ value: SourceCase, workspace: String) -> MovementEvent {
        .init(id: MovementSuggestion.identity(value.kind, ids: value.ids), workspaceID: workspace, kind: value.kind,
            decision: .confirmed, transactionIDs: value.ids, explanation: "Isolated owner-review qualification on independently nominated genuine source entries.",
            reviewedAtISO: "2026-09-21T00:00:00Z", consumptionTransactionIDs: value.consumption)
    }

    /// Reuses the complete original-column oracle in the signed app test host.
    /// Only PDF reading is shared with production; source interpretation and
    /// expected totals are independent and remain in memory for this test.
    private func trendOracle(database: SQLiteDatabase) async throws -> TrendOracle {
        let sources = try database.query(sql: """
            SELECT s.liability_account_id,s.document_id,s.source_row_count,d.filename,f.fingerprint
            FROM card_statements s JOIN documents d ON d.id=s.document_id
            JOIN document_fingerprints f ON f.document_id=d.id AND f.algorithm='ledgerforge.source-bytes.sha256.v1'
            WHERE s.parser_profile_id LIKE 'cbq.credit-card.%' AND s.statement_currency='QAR'
            AND s.statement_date BETWEEN '2024-06-01' AND '2024-08-31' ORDER BY s.statement_date;
            """) { row in
                (account: row.string(at: 0) ?? "", document: row.string(at: 1) ?? "", count: row.int64(at: 2) ?? 0,
                 filename: row.string(at: 3) ?? "", hash: row.string(at: 4) ?? "")
            }
        try #require(sources.count == 3 && Set(sources.map(\.account)).count == 1)
        let password = try #require(try await KeychainStatementPasswordCredentialStore(interaction: .forbidden)
            .password(institutionCode: Institution.cbq.statementPasswordCredentialScope))
        var nominated: [(id: String, row: PrivateCBQOracleRow)] = []
        for source in sources {
            let original = try #require(try database.query(sql: "SELECT byte_count,original_bytes FROM gmail_originals WHERE sha256=?;", params: [source.hash]) {
                (count: $0.int64(at: 0), bytes: $0.data(at: 1))
            }.first)
            let bytes = try #require(original.bytes)
            try #require(original.count == Int64(bytes.count) && GmailInboxSource.digest(bytes) == source.hash)
            let carrier = SourceContentSnapshot(bytes: bytes)
            defer { carrier.invalidate() }
            let raw = try await PDFDocumentReader().read(request: ImportRequest(fileURL: URL(fileURLWithPath: source.filename)), snapshot: carrier, password: password)
            let oracle = try CBQCreditCardPrivateAcceptanceTests().independentOracle(pages: #require(raw.pdfPageTexts), positioned: #require(raw.pdfPageEvidence))
            try #require(oracle.rows.count == source.count)
            let records = try database.query(sql: """
                SELECT t.id,t.original_row_id,t.posted_date,t.amount_decimal,t.description,e.source_transaction_date
                FROM transactions t JOIN card_transaction_evidence e ON e.transaction_id=t.id WHERE t.document_id=?;
                """, params: [source.document]) { row in
                    (id: row.string(at: 0) ?? "", ordinal: row.string(at: 1)?.split(separator: "-").last.flatMap { Int($0) },
                     posted: row.string(at: 2), amount: row.string(at: 3).flatMap { Decimal(string: $0) },
                     description: row.string(at: 4) ?? "", purchase: row.string(at: 5))
                }
            try #require(records.count == oracle.rows.count)
            for row in oracle.rows {
                let matches = records.filter { $0.ordinal == row.sourceOrdinal }
                try #require(matches.count == 1)
                let record = try #require(matches.first)
                try #require(record.posted == row.postingDate.canonical && record.purchase == row.purchaseDate.canonical && record.amount == row.postedMoney.amount)
                let narrative = record.description.uppercased().filter { !$0.isWhitespace }
                let expected = row.description.uppercased().filter { !$0.isWhitespace }
                try #require(narrative == expected || (record.description == "Paid using bankDirect" && row.description == "PAID BY ACCOUNT"))
                nominated.append((record.id, row))
            }
        }
        func period(_ month: String, lastDay: String) throws -> TrendOracle.Period {
            let selected = nominated.filter { $0.row.purchaseDate.canonical.hasPrefix(month) }
            let purchases = selected.filter { $0.row.postedMoney.amount > 0 }
            let payments = selected.filter { $0.row.postedMoney.amount < 0 }
            try #require(payments.allSatisfy { $0.row.description == "PAID BY ACCOUNT" })
            let excludedWords = ["CASH ADVANCE", "INSTALLMENT", "INSTALMENT", "INTEREST", "SERVICE CHARGE", "INSURANCE FEE", "REFUND", "REVERSAL", "TRANSFER"]
            try #require(purchases.allSatisfy { item in !excludedWords.contains { item.row.description.uppercased().contains($0) } })
            let amount = purchases.reduce(Decimal.zero) { $0 + $1.row.postedMoney.amount }
            let unresolved = -payments.reduce(Decimal.zero) { $0 + $1.row.postedMoney.amount }
            return .init(start: month + "-01", end: month + "-" + lastDay, income: "0", spending: NSDecimalNumber(decimal: amount).stringValue,
                         purchaseAmount: NSDecimalNumber(decimal: amount).stringValue, purchaseIDs: purchases.map(\.id).sorted(),
                         unresolvedIDs: payments.map(\.id).sorted(), unresolvedGross: NSDecimalNumber(decimal: unresolved).stringValue)
        }
        return try .init(accountID: #require(sources.first?.account), currency: "QAR", analysis: period("2024-07", lastDay: "31"),
                         baseline: period("2024-06", lastDay: "30"), originalHashes: sources.map(\.hash))
    }

    @Test(.globalRuntimeStateIsolation)
    func genuineSourceRolesKeepOnlySupportedMovementAlternativesWithoutSalarySetup() throws {
        let nomination = try JSONDecoder().decode(EligibilityNomination.self, from: AuthenticSourceTestSupport.ramNomination("LEDGERFORGE_S99_MOVEMENT_ELIGIBILITY"))
        let seeds = try JSONDecoder().decode([OwnerRuleNomination].self, from: AuthenticSourceTestSupport.ramNomination("LEDGERFORGE_S99_CATEGORY_OWNER_DATA"))
        let (folder, sqlite) = try restoredCopy()
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: folder) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let before = try NetWorthTestSupport.financialDigest(sqlite.database, excluding: ["movement_events", "movement_legs"])
        let hydration = try RepositoryStoreHydrator(databaseProvider: .verifiedSQLite(sqlite), workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        let metadata = try #require(hydration.intelligence)
        let rows = try SpendingIntelligence.rows(transactions: hydration.transactions, sources: hydration.financialSources, cards: hydration.cardSnapshot, categories: hydration.categorySnapshot)
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        func id(_ key: String) throws -> String { try #require(nomination.ids[key]) }
        for (key, expected) in nomination.expected {
            let row = try #require(byID[id(key)])
            #expect(row.transaction.money.amount == Decimal(string: expected[0]))
            #expect(row.currency == expected[1])
            #expect(row.date?.canonical == expected[2])
        }
        let salaryID = try id("salary"), externalID = try id("externalCredit")
        #expect(try #require(byID[salaryID]).isEmployerSalaryReceipt)
        #expect(byID[salaryID]?.isRegularSalary == false)
        let suggestions = try SpendingIntelligence.suggestions(rows: rows, metadata: metadata, sources: hydration.financialSources)
        #expect(!suggestions.isEmpty)
        for key in ["salary", "externalCredit"] {
            #expect(suggestions.filter { $0.kind == .ownTransfer }.allSatisfy { !$0.transactionIDs.contains(nomination.ids[key]!) })
        }
        func candidate(_ kind: MovementKind, _ first: String, _ second: String) throws -> MovementSuggestion {
            let identity = MovementSuggestion.identity(kind, ids: try [id(first), id(second)])
            return try #require(suggestions.first { $0.id == identity })
        }
        let reversal = try candidate(.reversal, "reversalDebit", "reversalCredit")
        let domestic = try candidate(.ownTransfer, "domesticDebit", "domesticCredit")
        let remittance = try candidate(.ownTransfer, "exchange", "remittance")
        #expect(reversal.explanation.contains("Complete matching reference"))
        #expect(domestic.explanation.contains("Complete matching reference"))
        #expect(remittance.explanation.contains("different references; exact linkage still needs your review"))
        let reversalIDs = Set(reversal.transactionIDs), interestID = try id("equalInterest")
        #expect(suggestions.filter { $0.kind == .ownTransfer }.allSatisfy { reversalIDs.isDisjoint(with: $0.transactionIDs) })
        #expect(!suggestions.contains { $0.transactionIDs.contains(interestID) && $0.transactionIDs.contains(try! id("domesticDebit")) })
        let groups = SpendingIntelligence.suggestionGroups(suggestions)
        #expect(Set(groups.flatMap { $0.suggestions.map(\.id) }) == Set(suggestions.map(\.id)))
        for (index, group) in groups.enumerated() {
            #expect(groups.dropFirst(index + 1).allSatisfy { $0.transactionIDs.isDisjoint(with: group.transactionIDs) })
        }
        // Category preferences remain owner metadata, independent of source roles.
        let seed = try #require(seeds.first)
        var categorySnapshot = hydration.categorySnapshot
        var automation = categorySnapshot.automation ?? .init()
        var disabledRule = seed.rule; disabledRule.isEnabled = false
        automation.rules = [disabledRule]
        automation.intents[salaryID] = .init(kind: .deliberatelyCleared, categoryID: nil, matches: [])
        categorySnapshot.automation = automation
        let disabledRows = try SpendingIntelligence.rows(transactions: hydration.transactions, sources: hydration.financialSources,
            cards: hydration.cardSnapshot, categories: categorySnapshot, salaryRuleIDs: [disabledRule.id])
        #expect(disabledRows.first { $0.id == salaryID }?.isEmployerSalaryReceipt == true)
        #expect(disabledRows.first { $0.id == salaryID }?.isRegularSalary == false)
        let changed = try SpendingIntelligence.suggestions(rows: disabledRows, metadata: metadata, sources: hydration.financialSources)
        #expect(changed == suggestions)
        #expect(categorySnapshot.automation?.intents[salaryID]?.kind == .deliberatelyCleared)
        let dismissed = MovementEvent(id: remittance.id, workspaceID: workspace, kind: remittance.kind, decision: .rejected,
            transactionIDs: remittance.transactionIDs, explanation: "Isolated review dismissal; exact linkage is not established.", reviewedAtISO: "2026-09-27T00:00:00Z")
        try sqlite.intelligenceRepo.saveMovement(dismissed, replacing: nil)
        let updated = try #require(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace))
        #expect(try !SpendingIntelligence.suggestions(rows: rows, metadata: updated, sources: hydration.financialSources).contains { $0.id == dismissed.id })
        let explicitReview = MovementEvent(id: "contradiction-check", workspaceID: workspace, kind: .ownTransfer, decision: .confirmed,
            transactionIDs: [salaryID, externalID], explanation: "Metadata-only contradiction inspection", reviewedAtISO: "2026-09-27T00:00:00Z")
        #expect(SpendingIntelligence.contradiction(explicitReview, rows: rows, sources: hydration.financialSources) != nil)
        #expect(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace) == updated)
        #expect(try NetWorthTestSupport.financialDigest(sqlite.database, excluding: ["movement_events", "movement_legs"]) == before)
    }

    @Test func comparisonPercentageRequiresPositiveBaseline() {
        #expect(SpendingComparison.percentage(change: 5, baseline: 0) == nil)
        #expect(SpendingComparison.percentage(change: 5, baseline: -5) == nil)
        #expect(SpendingComparison.percentage(change: -5, baseline: 20) == -25)
    }

    @Test(.globalRuntimeStateIsolation)
    func genuinePeriodComparisonMatchesIndependentOriginalColumnOracle() async throws {
        let (folder, sqlite) = try restoredCopy()
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: folder) }
        let oracle = try await trendOracle(database: sqlite.database)
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let snapshot = try RepositoryStoreHydrator(databaseProvider: .verifiedSQLite(sqlite), workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        let metadata = try #require(snapshot.intelligence)
        let rows = try SpendingIntelligence.rows(transactions: snapshot.transactions, sources: snapshot.financialSources, cards: snapshot.cardSnapshot, categories: snapshot.categorySnapshot)
        let start = try StatementDate(canonical: oracle.analysis.start), end = try StatementDate(canonical: oracle.analysis.end)
        let baselineStart = try StatementDate(canonical: oracle.baseline.start), baselineEnd = try StatementDate(canonical: oracle.baseline.end)
        let projection = try SpendingIntelligence.project(rows: rows, metadata: metadata, sources: snapshot.financialSources,
            currency: oracle.currency, accountIDs: [oracle.accountID], start: start, end: end, allSuggestions: [])
        let comparison = try SpendingIntelligence.compare(analysis: projection, rows: rows, metadata: metadata, sources: snapshot.financialSources,
            currency: oracle.currency, accountIDs: [oracle.accountID], start: start, end: end, baselineStart: baselineStart, baselineEnd: baselineEnd)
        for (period, expected) in [(comparison.analysis, oracle.analysis), (comparison.baseline, oracle.baseline)] {
            let spending = try #require(Decimal(string: expected.spending))
            let purchase = try #require(Decimal(string: expected.purchaseAmount))
            #expect(period.report.income == Decimal(string: expected.income))
            #expect(period.report.spending == spending)
            #expect(period.purchaseAmount == purchase)
            #expect(period.purchaseIDs == Set(expected.purchaseIDs))
            #expect(period.averagePurchase == purchase / Decimal(expected.purchaseIDs.count))
            let unresolved = period.report.rows.filter { $0.treatment == .unresolved }
            #expect(Set(unresolved.map(\.id)) == Set(expected.unresolvedIDs))
            #expect(unresolved.reduce(0) { $0 + $1.source.amount } == Decimal(string: expected.unresolvedGross))
            #expect(Set(period.report.rows.map(\.id)) == Set(expected.purchaseIDs + expected.unresolvedIDs))
            #expect(period.chargeIDs.isEmpty)
            #expect(period.report.rows.allSatisfy { $0.treatment != .refund })
            #expect(period.coverage.count == 1 && period.coverage.allSatisfy(\.complete))
            #expect(!period.isPartialCalendarMonth)
            #expect(period.report.categories.count == 1)
            #expect(period.report.categories.first?.id == "uncategorized")
            #expect(period.report.categories.first?.amount == spending)
            #expect(period.report.categories.first?.transactionIDs == Set(expected.purchaseIDs))
        }
        let analysis = try #require(Decimal(string: oracle.analysis.spending)), baseline = try #require(Decimal(string: oracle.baseline.spending))
        #expect(comparison.spendingChange == analysis - baseline)
        #expect(SpendingComparison.percentage(change: comparison.spendingChange, baseline: baseline) == (analysis - baseline) * 100 / baseline)
        #expect(comparison.contributors.count == 1)
        #expect(comparison.contributors.first?.change == analysis - baseline)
        #expect(comparison.contributors.first?.analysisIDs == Set(oracle.analysis.purchaseIDs))
        #expect(comparison.contributors.first?.baselineIDs == Set(oracle.baseline.purchaseIDs))
        #expect(oracle.originalHashes.count == 3 && oracle.originalHashes.allSatisfy { $0.count == 64 })
    }

    @Test(.globalRuntimeStateIsolation)
    func genuinePeriodComparisonReconcilesExactRecordSetsAndCoverage() throws {
        let (folder, sqlite) = try restoredCopy()
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: folder) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let snapshot = try RepositoryStoreHydrator(databaseProvider: .verifiedSQLite(sqlite), workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        let metadata = try #require(snapshot.intelligence)
        let rows = try SpendingIntelligence.rows(transactions: snapshot.transactions, sources: snapshot.financialSources, cards: snapshot.cardSnapshot, categories: snapshot.categorySnapshot)
        let facts = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        let start = try StatementDate(canonical: "2026-08-01"), end = try StatementDate(canonical: "2026-08-31")
        let previousStart = try StatementDate(canonical: "2026-07-01"), previousEnd = try StatementDate(canonical: "2026-07-31")
        for currency in ["INR", "QAR", "USD"] {
            let projection = try SpendingIntelligence.project(rows: rows, metadata: metadata, sources: snapshot.financialSources,
                currency: currency, accountIDs: [], start: start, end: end, allSuggestions: [])
            let comparison = try SpendingIntelligence.compare(analysis: projection, rows: rows, metadata: metadata, sources: snapshot.financialSources,
                currency: currency, accountIDs: [], start: start, end: end, baselineStart: previousStart, baselineEnd: previousEnd)
            for period in [comparison.analysis, comparison.baseline] {
                let selected = Set(rows.filter { $0.currency == currency && $0.date.map { $0 >= period.start && $0 <= period.end } == true }.map(\.id))
                #expect(Set(period.report.rows.map(\.id)) == selected)
                let purchases = period.purchaseIDs.compactMap { facts[$0] }
                #expect(period.purchaseAmount == purchases.reduce(Decimal.zero) { $0 + $1.amount })
                #expect(period.purchaseIDs.isDisjoint(with: period.chargeIDs))
                #expect(period.averagePurchase == (purchases.isEmpty ? nil : purchases.reduce(Decimal.zero) { $0 + $1.amount } / Decimal(purchases.count)))
                let refunds = period.report.rows.filter { $0.treatment == .refund }
                #expect(period.purchaseAmount + period.chargeAmount - refunds.reduce(0) { $0 + $1.source.amount } == period.report.spending)
                for coverage in period.coverage {
                    #expect(coverage.recordedThrough == snapshot.financialSources.periods.filter { $0.accountID == coverage.id && $0.start <= period.end }.map(\.end).max())
                    #expect(coverage.complete == snapshot.financialSources.hasCompleteCoverage(accountID: coverage.id, start: period.start, end: period.end))
                }
            }
            #expect(comparison.contributors.reduce(0) { $0 + $1.change } == comparison.spendingChange)
            #expect(comparison.contributors.reduce(0) { $0 + $1.analysis } == comparison.analysis.report.spending)
            #expect(comparison.contributors.reduce(0) { $0 + $1.baseline } == comparison.baseline.report.spending)
            #expect(Set(comparison.contributors.flatMap(\.analysisIDs)) == Set(comparison.analysis.report.rows.filter { $0.treatment == .expense || $0.treatment == .refund }.map(\.id)))
            #expect(Set(comparison.contributors.flatMap(\.baselineIDs)) == Set(comparison.baseline.report.rows.filter { $0.treatment == .expense || $0.treatment == .refund }.map(\.id)))
            #expect(comparison.analysis.isPartialCalendarMonth == false)
            let partial = try SpendingIntelligence.project(rows: rows, metadata: metadata, sources: snapshot.financialSources,
                currency: currency, accountIDs: [], start: start, end: try StatementDate(canonical: "2026-08-15"), allSuggestions: [])
            #expect(try SpendingIntelligence.compare(analysis: partial, rows: rows, metadata: metadata, sources: snapshot.financialSources,
                currency: currency, accountIDs: [], start: start, end: StatementDate(canonical: "2026-08-15"), baselineStart: previousStart, baselineEnd: previousEnd).analysis.isPartialCalendarMonth)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func genuineTransferReversalAndEMIKeepFactsAndRecoverExactMetadata() async throws {
        let sourceCases = try cases(), (folder, sqlite) = try restoredCopy()
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: folder) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let baseline = try NetWorthTestSupport.financialDigest(sqlite.database, excluding: ["movement_events", "movement_legs"])
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        let snapshot = try RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        let rows = try SpendingIntelligence.rows(transactions: snapshot.transactions, sources: snapshot.financialSources, cards: snapshot.cardSnapshot, categories: snapshot.categorySnapshot)
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        for item in sourceCases {
            let value = event(item, workspace: workspace)
            for (index, id) in item.ids.enumerated() {
                let row = try #require(byID[id])
                #expect(row.transaction.money.amount == Decimal(string: item.amounts[index]))
                #expect(row.currency == item.currency)
                #expect(row.date?.canonical == item.dates[index])
            }
            try sqlite.intelligenceRepo.saveMovement(value, replacing: nil)
            let meanings = item.ids.compactMap { byID[$0] }.map { SpendingIntelligence.interpretation($0, confirmed: value) }
            // The retained independent nomination lists the original purchase
            // first. Its older instalment-date total is now superseded by the
            // owner's original-purchase-once policy.
            let expectedSpending = item.kind == .emiConversion ? item.amounts[0] : item.spending
            #expect(meanings.reduce(Decimal.zero) { $0 + $1.spending } == Decimal(string: expectedSpending))
            #expect(meanings.reduce(Decimal.zero) { $0 + $1.income } == Decimal(string: item.income))
            if item.kind == .emiConversion {
                #expect(meanings.filter { $0.treatment == .expense }.map(\.id) == [item.ids[0]])
                #expect(meanings.filter { $0.treatment == .outsideScope }.count == item.ids.count - 1)
                #expect(meanings.dropFirst().allSatisfy { $0.source.isLoanOrEMI })
                #expect(meanings.first?.source.isLoanOrEMI == false)
                for meaning in meanings {
                    #expect(SpendingIntelligence.interpretation(meaning.source, confirmed: nil).treatment == meaning.treatment)
                }
                #expect(throws: FinancialIntelligenceError.outsideScope) {
                    try FinancialIntelligenceCoordinator(provider: { provider }).saveMovement(value, replacing: value, generation: provider.generationToken)
                }
            }
            var overlap = value; overlap.id = UUID().uuidString
            #expect(throws: FinancialIntelligenceError.occupiedLeg) { try sqlite.intelligenceRepo.saveMovement(overlap, replacing: nil) }
            #expect(throws: FinancialIntelligenceError.staleReview) { try sqlite.intelligenceRepo.saveMovement(value, replacing: nil) }
        }
        let saved = try #require(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace))
        #expect(saved.movements.count == sourceCases.count)
        #expect(try NetWorthTestSupport.financialDigest(sqlite.database, excluding: ["movement_events", "movement_legs"]) == baseline)
        // A failed metadata commit cannot leave half a relationship or consume a leg.
        try sqlite.database.execute(sql: "CREATE TRIGGER s99_movement_failure BEFORE DELETE ON movement_events BEGIN SELECT RAISE(ABORT,'qualification failure'); END;")
        #expect(throws: (any Error).self) { try sqlite.intelligenceRepo.removeMovement(saved.movements[0]) }
        #expect(try sqlite.intelligenceRepo.snapshot(workspaceID: workspace) == saved)
        try sqlite.database.execute(sql: "DROP TRIGGER s99_movement_failure;")
        let backups = folder.appendingPathComponent("backups")
        try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: false)
        DatabaseProvider.shared = provider
        let coordinator = BackupRestoreCoordinator(testingAt: folder.appendingPathComponent("qualification.sqlite")); coordinator.installTestProvider(sqlite)
        await coordinator.createBackup(to: backups)
        let package = try #require(coordinator.lastBackupURL), manifest = try BackupFiles.verifyPackage(package)
        let restored = folder.appendingPathComponent("restored.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: restored)
        let recovered = try SQLiteRepositoryProvider(path: restored.path, migrations: allMigrations, access: .existing)
        #expect(try recovered.intelligenceRepo.snapshot(workspaceID: workspace) == saved)
        try recovered.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: restored.path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        #expect(try reopened.intelligenceRepo.snapshot(workspaceID: workspace) == saved)
        #expect(try NetWorthTestSupport.financialDigest(reopened.database, excluding: ["movement_events", "movement_legs"]) == baseline)
        for value in saved.movements { try reopened.intelligenceRepo.removeMovement(value) }
        #expect(try reopened.intelligenceRepo.snapshot(workspaceID: workspace)?.movements.isEmpty == true)
        provider.invalidateGeneration()
        #expect(throws: (any Error).self) { try provider.intelligenceRepo.snapshot(workspaceID: workspace) }
    }

    @Test(.globalRuntimeStateIsolation)
    func genuineImportedLegMetadataMatchesBothProvidersAndRejectsInvalidRelationships() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s99-movement-parity-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("qualification.sqlite").path)
        defer { sqlite.database.close() }
        let providers = [DatabaseProvider.verifiedSQLite(sqlite), DatabaseProvider(inMemory: true)]
        for provider in providers {
            let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
            guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else { Issue.record("Authentic import must precede metadata qualification"); return }
            let facts = try provider.transactionRepo.trustedTransactions(workspaceId: plan.workspace.id)
            let original = try #require(facts.first)
            var value = MovementEvent(id: "review", workspaceID: plan.workspace.id, kind: .ownTransfer, decision: .rejected,
                transactionIDs: [original.id], explanation: "Dismissed one-sided candidate; no financial treatment is inferred.", reviewedAtISO: "2026-09-21T00:00:00Z")
            try provider.intelligenceRepo.saveMovement(value, replacing: nil)
            let saved = try #require(try provider.intelligenceRepo.snapshot(workspaceID: plan.workspace.id))
            #expect(saved.movements == [value] && saved.confirmedByTransaction.isEmpty)
            let previous = value; value.decision = .confirmed
            #expect(throws: FinancialIntelligenceError.invalidLegs) { try provider.intelligenceRepo.saveMovement(value, replacing: previous) }
            #expect(try provider.intelligenceRepo.snapshot(workspaceID: plan.workspace.id) == saved)
            try provider.intelligenceRepo.removeMovement(previous)
            #expect(try provider.intelligenceRepo.snapshot(workspaceID: plan.workspace.id)?.movements.isEmpty == true)
            #expect(try provider.transactionRepo.trustedTransactions(workspaceId: plan.workspace.id) == facts)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func genuineCoverageLabelsAndChartRowsReconcileWithoutTreatingBankDebitsAsSpending() throws {
        let (folder, sqlite) = try restoredCopy()
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: folder) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.first)
        let snapshot = try RepositoryStoreHydrator(databaseProvider: .verifiedSQLite(sqlite), workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        let rows = try SpendingIntelligence.rows(transactions: snapshot.transactions, sources: snapshot.financialSources, cards: snapshot.cardSnapshot, categories: snapshot.categorySnapshot)
        let metadata = try #require(snapshot.intelligence)
        #expect(rows.count == 8036)
        let names = Set(snapshot.accounts.compactMap(\.sourceProductName))
        #expect(names == ["Axis NRE", "Axis NRO", "HDFC NRE", "HDFC NRO"])
        for account in snapshot.accounts where account.sourceProductName != nil { #expect(account.preferredDisplayName == account.sourceProductName) }
        for observed in try sqlite.importSessionRepo.cbqSourceCoveragePeriods(workspaceId: workspace) {
            #expect(snapshot.financialSources.hasCompleteCoverage(accountID: observed.accountID, start: try StatementDate(canonical: observed.startISO), end: try StatementDate(canonical: observed.endISO)))
        }
        for currency in ["INR", "QAR", "USD"] {
            let report = try SpendingIntelligence.project(rows: rows, metadata: metadata, sources: snapshot.financialSources, currency: currency, accountIDs: [], start: nil, end: nil)
            if currency == "INR" {
                let values = report.suggestions.map {
                    [$0.id, $0.kind.rawValue, $0.transactionIDs.joined(separator: ","), $0.explanation,
                     String($0.ambiguityCount), $0.routeWarning ?? ""].joined(separator: "\u{1f}")
                }.joined(separator: "\n")
                let digest = SHA256.hash(data: Data(values.utf8)).map { String(format: "%02x", $0) }.joined()
                print("Genuine movement suggestions: \(report.suggestions.count); complete result fingerprint \(digest)")
            }
            #expect(report.rows.allSatisfy { $0.source.currency == currency })
            #expect(report.categories.reduce(Decimal.zero) { $0 + $1.amount } == report.spending)
            #expect(report.periods.reduce(Decimal.zero) { $0 + $1.spending } == report.rows.filter { $0.source.date != nil }.reduce(Decimal.zero) { $0 + $1.spending })
            let bankUnknown = report.rows.filter { $0.source.isBankOut && $0.treatment == .unresolved }
            #expect(bankUnknown.allSatisfy { $0.spending == 0 })
            let scoped = try SpendingIntelligence.project(rows: rows, metadata: metadata, sources: snapshot.financialSources, currency: currency, accountIDs: [], start: try StatementDate(canonical: "2026-01-01"), end: nil)
            #expect(scoped.missingDateCount == rows.filter { $0.currency == currency && $0.date == nil }.count)
        }
    }
}
