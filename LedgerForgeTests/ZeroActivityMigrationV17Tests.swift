import Foundation
import Testing
@testable import LedgerForge

/// Schema-only values exercise migration mechanics. They are not statement
/// fixtures, parser evidence, or source-family acceptance authority.
@MainActor
struct ZeroActivityMigrationV17Tests {
    @Test
    func freshV17InstallsExactAdditiveSchemaAndLeavesNoInventedRows() throws {
        try withDatabase(named: "fresh") { database in
            try database.runMigrations(allMigrations)

            let versions = try database.query(
                sql: "SELECT version FROM schema_migrations ORDER BY version;",
                params: []
            ) { Int($0.int64(at: 0) ?? -1) }
            #expect(versions == Array(1...17))
            #expect(allMigrations.map(\.version) == Array(1...17))
            #expect(allMigrations.map(\.checksum).allSatisfy { $0.count == 64 })

            let zeroObjects = try database.query(
                sql: "SELECT type || ':' || name FROM sqlite_master WHERE name IN ('statement_zero_activity_controls','idx_zero_activity_semantic_lookup','idx_zero_activity_one_authority','validate_statement_zero_activity_control') ORDER BY type,name;",
                params: []
            ) { $0.string(at: 0) ?? "" }
            #expect(Set(zeroObjects) == Set([
                "table:statement_zero_activity_controls",
                "index:idx_zero_activity_semantic_lookup",
                "index:idx_zero_activity_one_authority",
                "trigger:validate_statement_zero_activity_control"
            ]))

            let zeroCount = try database.queryInt("SELECT COUNT(*) FROM statement_zero_activity_controls;")
            #expect(zeroCount == 0)
            let summarySQL = try #require(database.query(
                sql: "SELECT sql FROM sqlite_master WHERE type='table' AND name='card_statement_summary_components';",
                params: []
            ) { $0.string(at: 0) ?? "" }.first)
            #expect(summarySQL.contains("'minimum_amount_due'"))
            let statementSQL = try #require(database.query(
                sql: "SELECT sql FROM sqlite_master WHERE type='table' AND name='card_statements';",
                params: []
            ) { $0.string(at: 0) ?? "" }.first)
            #expect(statementSQL.contains("source_row_count >= 0"))
            let projectionSQL = try #require(database.query(
                sql: "SELECT sql FROM sqlite_master WHERE type='table' AND name='card_statement_semantic_projections';",
                params: []
            ) { $0.string(at: 0) ?? "" }.first)
            #expect(projectionSQL.contains("event_count >= 0"))
            #expect(projectionSQL.contains("section_count = 0 AND event_count = 0"))

            let legacyAlter = try database.queryInt("PRAGMA legacy_alter_table;")
            #expect(legacyAlter == 0)
            let foreignKeyViolations = try database.query(
                sql: "PRAGMA foreign_key_check;",
                params: []
            ) { _ in true }
            #expect(foreignKeyViolations.isEmpty)
        }
    }

    @Test
    func emptyV16UpgradePreservesHistoryIndexesTriggersAndForeignKeys() throws {
        try withDatabase(named: "empty-upgrade") { database in
            let v16 = Array(allMigrations.prefix(16))
            try database.runMigrations(v16)

            let historyBefore = try migrationHistory(in: database, through: 16)
            let indexColumnsBefore = try affectedIndexColumns(in: database)
            let triggerSQLBefore = try affectedTriggerSQL(in: database)

            try database.runMigrations(allMigrations)

            let historyAfter = try migrationHistory(in: database, through: 16)
            #expect(historyAfter == historyBefore)
            #expect(historyAfter.count == 16)
            let currentVersion = try database.queryInt("SELECT MAX(version) FROM schema_migrations;")
            #expect(currentVersion == 17)
            let currentCount = try database.queryInt("SELECT COUNT(*) FROM schema_migrations;")
            #expect(currentCount == 17)

            #expect(try affectedIndexColumns(in: database) == indexColumnsBefore)
            #expect(try affectedTriggerSQL(in: database) == triggerSQLBefore)

            let childTargets = try dependentForeignKeyTargets(in: database)
            #expect(!childTargets.contains(where: { $0.hasSuffix("_v16") }))
            #expect(childTargets.contains("card_statements"))
            #expect(childTargets.contains("card_statement_semantic_projections"))
            let foreignKeyViolations = try database.query(
                sql: "PRAGMA foreign_key_check;",
                params: []
            ) { _ in true }
            #expect(foreignKeyViolations.isEmpty)

            let legacyAlter = try database.queryInt("PRAGMA legacy_alter_table;")
            #expect(legacyAlter == 0)
        }
    }

    @Test
    func failedMigrationRestoresConnectionScopedPragmasAndRollsBackDDL() throws {
        try withDatabase(named: "failed-pragma-restore") { database in
            let v16 = Array(allMigrations.prefix(16))
            try database.runMigrations(v16)
            #expect(try database.queryInt("PRAGMA foreign_keys;") == 1)
            #expect(try database.queryInt("PRAGMA legacy_alter_table;") == 0)

            let failingV17 = Migration(
                version: 17,
                name: "failure-path connection-state probe",
                sql: """
                PRAGMA legacy_alter_table = ON;
                CREATE TABLE migration_failure_probe(id TEXT PRIMARY KEY);
                INSERT INTO table_that_does_not_exist(id) VALUES('force-rollback');
                """,
                preflightChecks: [],
                requiresForeignKeysDisabled: true
            )
            var didFail = false
            do {
                try database.runMigrations(v16 + [failingV17])
            } catch {
                didFail = true
            }
            #expect(didFail)
            #expect(try database.queryInt("PRAGMA foreign_keys;") == 1)
            #expect(try database.queryInt("PRAGMA legacy_alter_table;") == 0)
            #expect(try database.queryInt("SELECT COUNT(*) FROM schema_migrations;") == 16)
            let leakedProbe = try database.queryInt("""
                SELECT COUNT(*) FROM sqlite_master
                WHERE type = 'table' AND name = 'migration_failure_probe';
                """)
            #expect(leakedProbe == 0)
        }
    }

    private func migrationHistory(in database: SQLiteDatabase, through version: Int) throws -> [String] {
        try database.query(
            sql: "SELECT version,name,checksum,applied_at FROM schema_migrations WHERE version <= ? ORDER BY version;",
            params: [version]
        ) { row in
            [row.string(at: 0), row.string(at: 1), row.string(at: 2), row.string(at: 3)]
                .map { $0 ?? "<NULL>" }
                .joined(separator: "|")
        }
    }

    private func affectedIndexColumns(in database: SQLiteDatabase) throws -> [String: [String]] {
        let names = ["idx_card_statement_current", "idx_card_semantic_projection_period"]
        return try Dictionary(uniqueKeysWithValues: names.map { name in
            let columns = try database.query(
                sql: "PRAGMA index_info('\(name)');",
                params: []
            ) { $0.string(at: 2) ?? "" }
            return (name, columns)
        })
    }

    private func affectedTriggerSQL(in database: SQLiteDatabase) throws -> [String: String] {
        let names = [
            "validate_card_statement",
            "validate_card_semantic_projection",
            "validate_card_semantic_projection_event",
            "validate_card_semantic_authoritative_bindings"
        ]
        let placeholders = names.map { _ in "?" }.joined(separator: ",")
        let rows = try database.query(
            sql: "SELECT name,sql FROM sqlite_master WHERE type='trigger' AND name IN (\(placeholders));",
            params: names
        ) { row in
            (row.string(at: 0) ?? "", canonicalSQL(row.string(at: 1) ?? ""))
        }
        return Dictionary(uniqueKeysWithValues: rows)
    }

    private func dependentForeignKeyTargets(in database: SQLiteDatabase) throws -> [String] {
        let tables = [
            "card_statement_summary_components",
            "card_statement_semantic_projections",
            "card_statement_semantic_projection_events",
            "card_statement_semantic_projection_sections",
            "card_statement_semantic_groups",
            "card_statement_semantic_members"
        ]
        return try tables.flatMap { table in
            try database.query(sql: "PRAGMA foreign_key_list('\(table)');", params: []) {
                $0.string(at: 2) ?? ""
            }
        }
    }

    private func canonicalSQL(_ sql: String) -> String {
        sql.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func withDatabase(named name: String, _ body: (SQLiteDatabase) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-V17MigrationTests", isDirectory: true)
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = SQLiteDatabase(path: folder.appendingPathComponent("database.sqlite").path)
        defer { database.close() }
        try body(database)
    }
}
