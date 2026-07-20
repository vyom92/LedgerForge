import Foundation
import Testing
@testable import LedgerForge

struct IdentifierOwnershipMigrationV5Tests {
    @Test func v5IsDormantButCanUpgradeAV4DatabaseAndValidateItsSchema() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = SQLiteDatabase(path: folder.appendingPathComponent("v5.sqlite").path)
        try database.runMigrations(allMigrations + [migrationV5])
        try validateIdentifierOwnershipV5Schema(database)
        #expect(allMigrations.map(\.version) == [1, 2, 3, 4])
        #expect(migrationV1.checksum == Migration(version: 1, name: migrationV1.name, sql: migrationV1.sql).checksum)
        database.close()
    }

    @Test func v5PreflightRejectsOrphanedIdentifierWithoutLeavingVersionFive() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = SQLiteDatabase(path: folder.appendingPathComponent("orphan.sqlite").path)
        try database.runMigrations(allMigrations)
        try database.execute(sql: "PRAGMA foreign_keys = OFF;")
        try database.executePrepared(sql: "INSERT INTO account_identifiers (id, account_id, scheme, identifier, provenance, created_at) VALUES (?, ?, ?, ?, ?, ?);", params: ["orphan", "missing", "iban", "QA12", "{}", "2026-07-20T00:00:00Z"])
        #expect(throws: MigrationPreflightError.failed(issueCode: "identifier-missing-account")) { try database.runMigrations(allMigrations + [migrationV5]) }
        #expect(try database.queryInt("SELECT COUNT(*) FROM schema_migrations WHERE version = 5;") == 0)
        database.close()
    }
}
