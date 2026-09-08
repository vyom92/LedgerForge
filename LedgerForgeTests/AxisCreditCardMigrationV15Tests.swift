import Foundation
import Testing
@testable import LedgerForge

/// Schema-only mechanics for historical V15. These tests create no financial
/// rows. Historical populated migration and negative cases authored as financial
/// statement graphs were retired under the authentic-source-only rule.
@MainActor
struct AxisCreditCardMigrationV15Tests {
    @Test func freshV1ThroughV15InstallsAnExactChainAndAxisSchema() throws {
        try withDatabase(named: "FreshV15") { database in
            try database.runMigrations(Array(allMigrations.prefix(15)))

            #expect(try database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 15)
            #expect(try database.queryInt("SELECT COUNT(*) FROM schema_migrations;") == 15)
            #expect(Array(allMigrations.prefix(15)).map(\.version) == Array(1...15))
            #expect(migrationV15.name == "Axis card observations and representation-neutral semantic events")

            let observationSQL = try database.query(
                sql: "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'card_source_identity_observations';",
                params: []
            ) { $0.string(at: 0) ?? "" }.first ?? ""
            #expect(!observationSQL.contains("axis_card_account_mask"))
            #expect(!observationSQL.contains("axis_masked_card_number"))

            let eventColumns = try database.query(
                sql: "PRAGMA table_info(card_statement_semantic_projection_events);",
                params: []
            ) { $0.string(at: 1) ?? "" }
            #expect(eventColumns.contains("financial_date"))
            #expect(eventColumns.contains("financial_date_role"))
            #expect(eventColumns.contains("source_transaction_date"))
            #expect(try database.queryInt("SELECT COUNT(*) FROM card_statement_semantic_projection_events;") == 0)
        }
    }

    @Test func emptyV14ToV15PreservesHistoryWithoutManufacturingFinancialEvidence() throws {
        try withDatabase(named: "EmptyV14Upgrade") { database in
            try database.runMigrations(Array(allMigrations.prefix(14)))
            let beforeHistory = try database.query(
                sql: "SELECT version, name, checksum FROM schema_migrations ORDER BY version;",
                params: []
            ) { row in
                "\(row.int64(at: 0) ?? 0)|\(row.string(at: 1) ?? "")|\(row.string(at: 2) ?? "")"
            }

            try database.runMigrations(Array(allMigrations.prefix(15)))

            let afterHistory = try database.query(
                sql: "SELECT version, name, checksum FROM schema_migrations WHERE version <= 14 ORDER BY version;",
                params: []
            ) { row in
                "\(row.int64(at: 0) ?? 0)|\(row.string(at: 1) ?? "")|\(row.string(at: 2) ?? "")"
            }
            #expect(afterHistory == beforeHistory)
            #expect(try database.queryInt("SELECT COUNT(*) FROM schema_migrations;") == 15)
            for table in [
                "documents", "transactions", "card_statements",
                "card_statement_semantic_projections",
                "card_statement_semantic_projection_events",
                "card_statement_semantic_groups"
            ] {
                #expect(try database.queryInt("SELECT COUNT(*) FROM \(table);") == 0)
            }
            let foreignKeyFailures = try database.query(
                sql: "PRAGMA foreign_key_check;", params: []
            ) { $0.string(at: 0) ?? "" }
            #expect(foreignKeyFailures.isEmpty)
        }
    }

    private func withDatabase(named name: String, _ body: (SQLiteDatabase) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-AxisV15Tests", isDirectory: true)
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = SQLiteDatabase(path: folder.appendingPathComponent("database.sqlite").path)
        defer { database.close() }
        try body(database)
    }
}
