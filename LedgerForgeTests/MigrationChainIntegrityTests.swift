import Foundation
import Testing
@testable import LedgerForge

struct MigrationChainIntegrityTests {
    @Test func registeredChainRejectsDuplicateVersion() {
        let migrations = [
            Migration(version: 1, name: "one", sql: "SELECT 1;"),
            Migration(version: 1, name: "duplicate", sql: "SELECT 2;")
        ]

        #expect(throws: MigrationIntegrityError.duplicateRegisteredVersion(1)) {
            try MigrationChainValidator.validateRegistered(migrations)
        }
    }

    @Test func registeredChainRejectsMissingAndNonContiguousVersion() {
        let migrations = [
            Migration(version: 1, name: "one", sql: "SELECT 1;"),
            Migration(version: 3, name: "three", sql: "SELECT 3;")
        ]

        #expect(throws: MigrationIntegrityError.missingRegisteredVersion(2)) {
            try MigrationChainValidator.validateRegistered(migrations)
        }
    }

    @Test func registeredChainRejectsNondeterministicInputOrdering() {
        let migrations = [
            Migration(version: 2, name: "two", sql: "SELECT 2;"),
            Migration(version: 1, name: "one", sql: "SELECT 1;")
        ]

        #expect(throws: MigrationIntegrityError.registeredOrderInvalid) {
            try MigrationChainValidator.validateRegistered(migrations)
        }
    }

    @Test func currentV1ThroughV4RegistrationIsValidAndDeterministic() throws {
        try MigrationChainValidator.validateRegistered(allMigrations)

        #expect(allMigrations.map(\.version) == [1, 2, 3, 4])
        #expect(allMigrations.map(\.checksum).allSatisfy { $0.count == 64 })
        #expect(allMigrations.map(\.checksum) == allMigrations.map(\.checksum))
    }

    @Test func persistedHistoryRejectsDuplicateVersion() {
        let records = [record(for: migrationV1), record(for: migrationV1)]

        #expect(throws: MigrationIntegrityError.duplicatePersistedVersion(1)) {
            try MigrationChainValidator.validatePersisted(records, against: allMigrations, requiresCompleteChain: false)
        }
    }

    @Test func persistedHistoryRejectsMissingLowerMigration() {
        let records = [record(for: migrationV1), record(for: migrationV3)]

        #expect(throws: MigrationIntegrityError.missingPersistedVersion(2)) {
            try MigrationChainValidator.validatePersisted(records, against: allMigrations, requiresCompleteChain: false)
        }
    }

    @Test func persistedHistoryRejectsMismatchedName() {
        let records = [PersistedMigrationRecord(version: 1, name: "renamed", checksum: migrationV1.checksum, appliedAt: "2026-07-20T00:00:00Z")]

        #expect(throws: MigrationIntegrityError.persistedNameMismatch(1)) {
            try MigrationChainValidator.validatePersisted(records, against: allMigrations, requiresCompleteChain: false)
        }
    }

    @Test func persistedHistoryRejectsMismatchedChecksum() {
        let records = [PersistedMigrationRecord(version: 1, name: migrationV1.name, checksum: String(repeating: "0", count: 64), appliedAt: "2026-07-20T00:00:00Z")]

        #expect(throws: MigrationIntegrityError.persistedChecksumMismatch(1)) {
            try MigrationChainValidator.validatePersisted(records, against: allMigrations, requiresCompleteChain: false)
        }
    }

    @Test(arguments: [
        PersistedMigrationRecord(version: nil, name: migrationV1.name, checksum: migrationV1.checksum, appliedAt: "2026-07-20T00:00:00Z"),
        PersistedMigrationRecord(version: 1, name: nil, checksum: migrationV1.checksum, appliedAt: "2026-07-20T00:00:00Z"),
        PersistedMigrationRecord(version: 1, name: migrationV1.name, checksum: nil, appliedAt: "2026-07-20T00:00:00Z"),
        PersistedMigrationRecord(version: 1, name: migrationV1.name, checksum: migrationV1.checksum, appliedAt: nil)
    ])
    func persistedHistoryRejectsNullOrIncompleteRecord(_ incomplete: PersistedMigrationRecord) {
        #expect(throws: MigrationIntegrityError.persistedRecordIncomplete(incomplete.version)) {
            try MigrationChainValidator.validatePersisted([incomplete], against: allMigrations, requiresCompleteChain: false)
        }
    }

    @Test func persistedHistoryRejectsUnsupportedFutureVersion() {
        let future = PersistedMigrationRecord(version: 5, name: "future", checksum: String(repeating: "f", count: 64), appliedAt: "2026-07-20T00:00:00Z")

        #expect(throws: MigrationIntegrityError.unsupportedFutureVersion(5)) {
            try MigrationChainValidator.validatePersisted(allMigrations.map(record(for:)) + [future], against: allMigrations, requiresCompleteChain: false)
        }
    }

    @Test func editedPreviouslyAppliedMigrationIsRejected() {
        let editedV1 = Migration(version: 1, name: migrationV1.name, sql: migrationV1.sql + "\nSELECT 1;")

        #expect(throws: MigrationIntegrityError.persistedChecksumMismatch(1)) {
            try MigrationChainValidator.validatePersisted([record(for: migrationV1)], against: [editedV1], requiresCompleteChain: true)
        }
    }

    @Test func validPersistedPrefixAndCompleteChainAreAccepted() throws {
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

    @Test func freshDatabaseCreatesOneExactV1ThroughV4History() throws {
        try withTemporaryDatabase(named: "Fresh") { path in
            let provider = try SQLiteRepositoryProvider(path: path)
            defer { provider.database.close() }

            try expectCurrentHistory(in: provider.database)
        }
    }

    @Test(arguments: [1, 2, 3, 4])
    func everySupportedPriorVersionUpgradesOrReopensToCurrent(_ priorVersion: Int) throws {
        try withTemporaryDatabase(named: "Upgrade-V\(priorVersion)") { path in
            let seed = SQLiteDatabase(path: path)
            try seed.runMigrations(Array(allMigrations.prefix(priorVersion)))
            seed.close()

            let provider = try SQLiteRepositoryProvider(path: path)
            defer { provider.database.close() }

            try expectCurrentHistory(in: provider.database)
        }
    }

    @Test func duplicatePersistedVersionFailsOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Duplicate") { database in
            try database.executePrepared(
                sql: "INSERT INTO schema_migrations(version, name, applied_at, checksum) VALUES(?, ?, ?, ?);",
                params: [1, migrationV1.name, "2026-07-20T00:00:00Z", migrationV1.checksum]
            )
        } assertReopen: {
            MigrationIntegrityError.duplicatePersistedVersion(1)
        }
    }

    @Test func missingLowerPersistedVersionFailsOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Missing") { database in
            try database.executePrepared(sql: "DELETE FROM schema_migrations WHERE version = ?;", params: [2])
        } assertReopen: {
            MigrationIntegrityError.missingPersistedVersion(2)
        }
    }

    @Test func mismatchedPersistedNameFailsOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Name") { database in
            try database.executePrepared(sql: "UPDATE schema_migrations SET name = ? WHERE version = ?;", params: ["renamed", 2])
        } assertReopen: {
            MigrationIntegrityError.persistedNameMismatch(2)
        }
    }

    @Test func mismatchedPersistedChecksumAndEditedMigrationFailOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Checksum") { database in
            try database.executePrepared(
                sql: "UPDATE schema_migrations SET checksum = ? WHERE version = ?;",
                params: [String(repeating: "0", count: 64), 3]
            )
        } assertReopen: {
            MigrationIntegrityError.persistedChecksumMismatch(3)
        }
    }

    @Test(arguments: ["name", "checksum"])
    func incompletePersistedRecordFailsOnReopen(_ column: String) throws {
        try withTamperedCurrentDatabase(named: "Incomplete-\(column)") { database in
            try database.execute(sql: "UPDATE schema_migrations SET \(column) = NULL WHERE version = 1;")
        } assertReopen: {
            MigrationIntegrityError.persistedRecordIncomplete(1)
        }
    }

    @Test func unsupportedFuturePersistedVersionFailsOnReopen() throws {
        try withTamperedCurrentDatabase(named: "Future") { database in
            try database.executePrepared(
                sql: "INSERT INTO schema_migrations(version, name, applied_at, checksum) VALUES(?, ?, ?, ?);",
                params: [5, "future", "2026-07-20T00:00:00Z", String(repeating: "f", count: 64)]
            )
        } assertReopen: {
            MigrationIntegrityError.unsupportedFutureVersion(5)
        }
    }

    @Test func applicationSchemaWithoutMigrationHistoryIsNotAcceptedAsFresh() throws {
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
        try database.query(sql: "SELECT version, name, checksum, applied_at FROM schema_migrations ORDER BY version;") { row in
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
