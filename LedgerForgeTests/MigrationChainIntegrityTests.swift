import Foundation
import Testing
@testable import LedgerForge

/// Migration-chain coverage is intentionally schema/history-only. Historical
/// tests that inserted hand-authored financial rows were retired because such
/// rows are not authentic statements or migration authority.
@MainActor
struct MigrationChainIntegrityTests {
    @Test
    func registeredChainRejectsDuplicateVersion() {
        let migrations = [
            Migration(version: 1, name: "one", sql: "SELECT 1;"),
            Migration(version: 1, name: "duplicate", sql: "SELECT 2;")
        ]

        #expect(throws: MigrationIntegrityError.duplicateRegisteredVersion(1)) {
            try MigrationChainValidator.validateRegistered(migrations)
        }
    }

    @Test
    func registeredChainRejectsMissingAndNonContiguousVersion() {
        let migrations = [
            Migration(version: 1, name: "one", sql: "SELECT 1;"),
            Migration(version: 3, name: "three", sql: "SELECT 3;")
        ]

        #expect(throws: MigrationIntegrityError.missingRegisteredVersion(2)) {
            try MigrationChainValidator.validateRegistered(migrations)
        }
    }

    @Test
    func registeredChainRejectsNondeterministicInputOrdering() {
        let migrations = [
            Migration(version: 2, name: "two", sql: "SELECT 2;"),
            Migration(version: 1, name: "one", sql: "SELECT 1;")
        ]

        #expect(throws: MigrationIntegrityError.registeredOrderInvalid) {
            try MigrationChainValidator.validateRegistered(migrations)
        }
    }

    @Test
    func currentRegistrationIsContiguousAndDeterministic() throws {
        try MigrationChainValidator.validateRegistered(allMigrations)

        #expect(allMigrations.map(\.version) == Array(1...allMigrations.count))
        #expect(allMigrations.map(\.checksum).allSatisfy { $0.count == 64 })
        #expect(allMigrations.map(\.checksum) == allMigrations.map(\.checksum))
        #expect(migrationV13.name == "multi-section card statements and exact semantic sources")
        #expect(migrationV14.name == "generalized card reconciliation and structural section evidence")
        #expect(migrationV17.version == allMigrations.count)
    }

    @Test
    func cleanInstallContainsCurrentSchemaAndReopens() throws {
        try withTemporaryDatabase(named: "CurrentCleanInstall") { path in
            let provider = try SQLiteRepositoryProvider(path: path)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM schema_migrations;") == allMigrations.count)
            let requiredTables = [
                "categories",
                "transaction_category_assignments",
                "partial_import_summaries",
                "incoming_row_dispositions",
                "statement_financial_projections",
                "statement_equivalence_groups",
                "card_statements",
                "card_statement_sections",
                "card_statement_semantic_projections",
                "statement_zero_activity_controls"
            ]
            let placeholders = requiredTables.map { _ in "?" }.joined(separator: ",")
            let installed = try provider.database.query(
                sql: "SELECT name FROM sqlite_master WHERE type='table' AND name IN (\(placeholders));",
                params: requiredTables
            ) { $0.string(at: 0) ?? "" }
            #expect(Set(installed) == Set(requiredTables))
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM statement_financial_projections;") == 0)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM card_statements;") == 0)
            #expect(try provider.database.queryInt("SELECT COUNT(*) FROM statement_zero_activity_controls;") == 0)
            #expect(try provider.database.queryInt("PRAGMA legacy_alter_table;") == 0)
            try provider.database.checkpointAndClose()

            // This PRAGMA is connection-scoped, not persisted. Apple's SQLite
            // may default it to ON for a new connection; reopening must match
            // that independent default rather than the migration's exit mode.
            let freshConnection = SQLiteDatabase(path: ":memory:")
            try freshConnection.open()
            defer { freshConnection.close() }
            let connectionDefault = try freshConnection.queryInt("PRAGMA legacy_alter_table;")
            let reopened = try SQLiteRepositoryProvider(path: path)
            defer { reopened.database.close() }
            try expectCurrentHistory(in: reopened.database)
            #expect(try reopened.database.queryInt("PRAGMA foreign_keys;") == 1)
            #expect(try reopened.database.queryInt("PRAGMA legacy_alter_table;") == connectionDefault)
        }
    }

    @Test
    func emptyV9UpgradesToCurrentWithoutInventingFinancialRows() throws {
        try withTemporaryDatabase(named: "EmptyV9ToCurrent") { path in
            let database = SQLiteDatabase(path: path)
            try database.runMigrations(Array(allMigrations.prefix(9)))
            #expect(try database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 9)

            try database.runMigrations(allMigrations)

            #expect(try database.queryInt("SELECT MAX(version) FROM schema_migrations;") == allMigrations.count)
            for table in [
                "transactions",
                "documents",
                "statement_financial_projections",
                "statement_equivalence_groups",
                "card_instruments",
                "card_statements",
                "card_statement_sections",
                "card_statement_semantic_projections",
                "statement_zero_activity_controls"
            ] {
                #expect(try database.queryInt("SELECT COUNT(*) FROM \(table);") == 0)
            }
            try database.checkpointAndClose()

            let reopened = try SQLiteRepositoryProvider(path: path)
            defer { reopened.database.close() }
            try expectCurrentHistory(in: reopened.database)
        }
    }

    @Test
    func persistedHistoryRejectsDuplicateVersion() {
        let records = [record(for: migrationV1), record(for: migrationV1)]

        #expect(throws: MigrationIntegrityError.duplicatePersistedVersion(1)) {
            try MigrationChainValidator.validatePersisted(
                records,
                against: allMigrations,
                requiresCompleteChain: false
            )
        }
    }

    @Test
    func persistedHistoryRejectsMissingLowerMigration() {
        let records = [record(for: migrationV1), record(for: migrationV3)]

        #expect(throws: MigrationIntegrityError.missingPersistedVersion(2)) {
            try MigrationChainValidator.validatePersisted(
                records,
                against: allMigrations,
                requiresCompleteChain: false
            )
        }
    }

    @Test
    func persistedHistoryRejectsMismatchedNameOrChecksum() {
        let renamed = PersistedMigrationRecord(
            version: 1,
            name: "renamed",
            checksum: migrationV1.checksum,
            appliedAt: "2026-07-20T00:00:00Z"
        )
        let edited = PersistedMigrationRecord(
            version: 1,
            name: migrationV1.name,
            checksum: String(repeating: "0", count: 64),
            appliedAt: "2026-07-20T00:00:00Z"
        )

        #expect(throws: MigrationIntegrityError.persistedNameMismatch(1, expected: migrationV1.name, observed: "renamed")) {
            try MigrationChainValidator.validatePersisted([renamed], against: allMigrations, requiresCompleteChain: false)
        }
        #expect(throws: MigrationIntegrityError.persistedChecksumMismatch(1, expected: migrationV1.checksum, observed: String(repeating: "0", count: 64))) {
            try MigrationChainValidator.validatePersisted([edited], against: allMigrations, requiresCompleteChain: false)
        }
    }

    @Test
    func persistedHistoryRejectsNullOrIncompleteRecord() {
        let incompleteRecords = [
            PersistedMigrationRecord(version: nil, name: migrationV1.name, checksum: migrationV1.checksum, appliedAt: "2026-07-20T00:00:00Z"),
            PersistedMigrationRecord(version: 1, name: nil, checksum: migrationV1.checksum, appliedAt: "2026-07-20T00:00:00Z"),
            PersistedMigrationRecord(version: 1, name: migrationV1.name, checksum: nil, appliedAt: "2026-07-20T00:00:00Z"),
            PersistedMigrationRecord(version: 1, name: migrationV1.name, checksum: migrationV1.checksum, appliedAt: nil)
        ]

        for incomplete in incompleteRecords {
            #expect(throws: MigrationIntegrityError.persistedRecordIncomplete(incomplete.version)) {
                try MigrationChainValidator.validatePersisted(
                    [incomplete],
                    against: allMigrations,
                    requiresCompleteChain: false
                )
            }
        }
    }

    @Test
    func persistedHistoryRejectsUnsupportedFutureVersion() {
        let futureVersion = allMigrations.count + 1
        let future = PersistedMigrationRecord(
            version: futureVersion,
            name: "future",
            checksum: String(repeating: "f", count: 64),
            appliedAt: "2026-07-20T00:00:00Z"
        )

        #expect(throws: MigrationIntegrityError.unsupportedFutureVersion(futureVersion)) {
            try MigrationChainValidator.validatePersisted(
                allMigrations.map(record(for:)) + [future],
                against: allMigrations,
                requiresCompleteChain: false
            )
        }
    }

    @Test
    func editedPreviouslyAppliedMigrationIsRejected() {
        let editedV1 = Migration(
            version: 1,
            name: migrationV1.name,
            sql: migrationV1.sql + "\nSELECT 1;"
        )

        #expect(throws: MigrationIntegrityError.persistedChecksumMismatch(1, expected: editedV1.checksum, observed: migrationV1.checksum)) {
            try MigrationChainValidator.validatePersisted(
                [record(for: migrationV1)],
                against: [editedV1],
                requiresCompleteChain: true
            )
        }
    }

    @Test
    func validPersistedPrefixAndCompleteChainAreAccepted() throws {
        try MigrationChainValidator.validatePersisted(
            [record(for: migrationV1), record(for: migrationV2)],
            against: allMigrations,
            requiresCompleteChain: false
        )
        try MigrationChainValidator.validatePersisted(
            allMigrations.map(record(for:)),
            against: allMigrations,
            requiresCompleteChain: true
        )
    }

    @Test
    func freshDatabaseCreatesOneExactCurrentHistory() throws {
        try withTemporaryDatabase(named: "FreshHistory") { path in
            let database = SQLiteDatabase(path: path)
            defer { database.close() }
            try database.runMigrations(allMigrations)
            try expectCurrentHistory(in: database)
        }
    }

    @Test(arguments: Array(1..<allMigrations.count))
    func everyEmptyHistoricalPrefixIsExactBeforeOrdinaryReopenToCurrent(
        _ sourceVersion: Int
    ) throws {
        try withTemporaryDatabase(named: "HistoricalPrefixV\(sourceVersion)") { path in
            let prefix = Array(allMigrations.prefix(sourceVersion))
            let database = SQLiteDatabase(path: path)
            try database.runMigrations(prefix)
            #expect(try persistedRecords(in: database).map(\.version) == Array(1...sourceVersion).map(Optional.init))
            database.close()

            let reopened = try SQLiteRepositoryProvider(path: path)
            defer { reopened.database.close() }
            try expectCurrentHistory(in: reopened.database)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM transactions;") == 0)
            #expect(try reopened.database.queryInt("SELECT COUNT(*) FROM documents;") == 0)
        }
    }

    @Test
    func duplicatePersistedVersionFailsOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Duplicate") { database in
            try database.executePrepared(
                sql: "INSERT INTO schema_migrations(version, name, applied_at, checksum) VALUES(?, ?, ?, ?);",
                params: [1, migrationV1.name, "2026-07-20T00:00:00Z", migrationV1.checksum]
            )
        } assertReopen: {
            .duplicatePersistedVersion(1)
        }
    }

    @Test
    func missingLowerPersistedVersionFailsOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Missing") { database in
            try database.executePrepared(
                sql: "DELETE FROM schema_migrations WHERE version = ?;",
                params: [2]
            )
        } assertReopen: {
            .missingPersistedVersion(2)
        }
    }

    @Test
    func mismatchedPersistedNameFailsOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Name") { database in
            try database.executePrepared(
                sql: "UPDATE schema_migrations SET name = ? WHERE version = ?;",
                params: ["renamed", 2]
            )
        } assertReopen: {
            .persistedNameMismatch(2, expected: allMigrations[1].name, observed: "renamed")
        }
    }

    @Test
    func mismatchedPersistedChecksumFailsOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Checksum") { database in
            try database.executePrepared(
                sql: "UPDATE schema_migrations SET checksum = ? WHERE version = ?;",
                params: [String(repeating: "0", count: 64), 3]
            )
        } assertReopen: {
            .persistedChecksumMismatch(3, expected: allMigrations[2].checksum, observed: String(repeating: "0", count: 64))
        }
    }

    @Test(arguments: ["name", "checksum"])
    func incompletePersistedRecordFailsOnReopen(_ column: String) throws {
        try withTamperedCurrentDatabase(named: "Incomplete-\(column)") { database in
            try database.execute(sql: "UPDATE schema_migrations SET \(column) = NULL WHERE version = 1;")
        } assertReopen: {
            .persistedRecordIncomplete(1)
        }
    }

    @Test
    func unsupportedFuturePersistedVersionFailsOnReopen() throws {
        let futureVersion = allMigrations.count + 1
        try withTamperedCurrentDatabase(named: "Future") { database in
            try database.executePrepared(
                sql: "INSERT INTO schema_migrations(version, name, applied_at, checksum) VALUES(?, ?, ?, ?);",
                params: [futureVersion, "future", "2026-07-20T00:00:00Z", String(repeating: "f", count: 64)]
            )
        } assertReopen: {
            .unsupportedFutureVersion(futureVersion)
        }
    }

    @Test
    func applicationSchemaWithoutMigrationHistoryIsNotAcceptedAsFresh() throws {
        try withTemporaryDatabase(named: "MissingHistory") { path in
            let database = SQLiteDatabase(path: path)
            try database.open()
            try database.execute(sql: "CREATE TABLE workspaces (id TEXT PRIMARY KEY);")
            database.close()

            #expect(throws: MigrationIntegrityError.missingPersistedVersion(1)) {
                let reopened = SQLiteDatabase(path: path)
                defer { reopened.close() }
                try reopened.runMigrations(allMigrations)
            }
        }
    }

    private func record(for migration: Migration) -> PersistedMigrationRecord {
        PersistedMigrationRecord(
            version: migration.version,
            name: migration.name,
            checksum: migration.checksum,
            appliedAt: "2026-07-20T00:00:00Z"
        )
    }

    private func persistedRecords(in database: SQLiteDatabase) throws -> [PersistedMigrationRecord] {
        try database.query(
            sql: "SELECT version, name, checksum, applied_at FROM schema_migrations ORDER BY version;"
        ) { row in
            PersistedMigrationRecord(
                version: row.int64(at: 0).map(Int.init),
                name: row.string(at: 1),
                checksum: row.string(at: 2),
                appliedAt: row.string(at: 3)
            )
        }
    }

    private func expectCurrentHistory(in database: SQLiteDatabase) throws {
        let records = try persistedRecords(in: database)
        #expect(records.map(\.version) == allMigrations.map { Optional($0.version) })
        #expect(records.map(\.name) == allMigrations.map { Optional($0.name) })
        #expect(records.map(\.checksum) == allMigrations.map { Optional($0.checksum) })
        #expect(records.allSatisfy { !($0.appliedAt ?? "").isEmpty })
    }

    private func withTemporaryDatabase(
        named name: String,
        _ body: (String) throws -> Void
    ) throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-MigrationIntegrityTests", isDirectory: true)
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try body(folder.appendingPathComponent("database.sqlite").path)
    }

    private func withTamperedCurrentDatabase(
        named name: String,
        tamper: (SQLiteDatabase) throws -> Void,
        assertReopen expectedError: () -> MigrationIntegrityError
    ) throws {
        try withTemporaryDatabase(named: name) { path in
            let provider = try SQLiteRepositoryProvider(path: path)
            try tamper(provider.database)
            provider.database.close()

            #expect(throws: expectedError()) {
                let reopened = SQLiteDatabase(path: path)
                defer { reopened.close() }
                try reopened.runMigrations(allMigrations)
            }
        }
    }
}
