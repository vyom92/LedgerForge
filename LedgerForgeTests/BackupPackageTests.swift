import CryptoKit
import Foundation
import XCTest
@testable import LedgerForge

@MainActor
final class BackupPackageTests: XCTestCase {
    private func temporary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s93-mechanics-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }
    private func package(at parent: URL) throws -> URL {
        let package = parent.appendingPathComponent("test.ledgerforgebackup")
        try BackupFiles.createDirectory(package)
        let source = SQLiteDatabase(path: ":memory:")
        try source.open(); defer { source.close() }
        try source.runMigrations(allMigrations)
        let payload = package.appendingPathComponent("ledger.sqlite")
        try source.createBackup(at: payload.path)
        let hash = try BackupFiles.hash(payload)
        let manifest = BackupManifest(formatVersion: 1, backupID: UUID(), createdAt: "2026-09-14T00:00:00Z",
            application: .init(identifier: nil, version: nil, build: nil),
            database: .init(file: "ledger.sqlite", byteSize: hash.size, sha256: hash.sha256),
            schemaVersion: BackupCompatibility.supportedSchemaVersion, migrations: BackupCompatibility.migrationIdentities,
            contents: BackupManifest.contentDescription, exclusions: BackupManifest.excluded)
        try JSONEncoder().encode(manifest).write(to: package.appendingPathComponent("manifest.json"))
        return package
    }
    private func withPackage(_ body: (URL) throws -> Void) throws {
        let directory = try temporary(); defer { try? FileManager.default.removeItem(at: directory) }
        try body(package(at: directory))
    }
    private func changeMetadata(_ url: URL, _ change: (inout [String: Any]) -> Void) throws {
        let path = url.appendingPathComponent("manifest.json")
        var value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        change(&value)
        try JSONSerialization.data(withJSONObject: value).write(to: path)
    }

    func testValidEmptySchemaPackageAndImmutableVerification() throws {
        try withPackage { url in
            let before = try BackupFiles.hash(url.appendingPathComponent("ledger.sqlite"))
            _ = try BackupFiles.verifyPackage(url)
            let after = try BackupFiles.hash(url.appendingPathComponent("ledger.sqlite"))
            XCTAssertEqual(before.sha256, after.sha256)
            XCTAssertEqual(try Set(FileManager.default.contentsOfDirectory(atPath: url.path)), BackupFiles.members)
        }
    }
    func testUnsupportedFormat() throws {
        try withPackage { url in
            try changeMetadata(url) { $0["formatVersion"] = 99 }
            XCTAssertThrowsError(try BackupFiles.verifyPackage(url)) { XCTAssertEqual($0 as? BackupError, .incompatible) }
        }
    }
    func testOlderSchemaRejected() throws {
        try withPackage { url in
            try changeMetadata(url) { $0["schemaVersion"] = BackupCompatibility.supportedSchemaVersion - 1 }
            XCTAssertThrowsError(try BackupFiles.verifyPackage(url)) { XCTAssertEqual($0 as? BackupError, .incompatible) }
        }
    }
    func testFutureSchemaRejected() throws {
        try withPackage { url in
            try changeMetadata(url) { $0["schemaVersion"] = BackupCompatibility.supportedSchemaVersion + 1 }
            XCTAssertThrowsError(try BackupFiles.verifyPackage(url)) { XCTAssertEqual($0 as? BackupError, .incompatible) }
        }
    }
    func testActualDatabaseHistoryMustMatchManifest() throws {
        try withPackage { url in
            let payload = url.appendingPathComponent("ledger.sqlite")
            let db = SQLiteDatabase(path: payload.path)
            try db.open(access: .existing)
            try db.execute(sql: "UPDATE schema_migrations SET name = 'unrecognized' WHERE version = 1;")
            try db.checkpointAndClose()
            let hash = try BackupFiles.hash(payload)
            try changeMetadata(url) { value in
                value["database"] = ["file": "ledger.sqlite", "byteSize": hash.size, "sha256": hash.sha256]
            }
            XCTAssertThrowsError(try BackupFiles.verifyPackage(url))
        }
    }
    func testUnknownMigrationIdentityRejected() throws {
        try withPackage { url in
            try changeMetadata(url) { value in
                var chain = value["migrations"] as! [[String: Any]]
                chain[0]["name"] = "unrecognized"; value["migrations"] = chain
            }
            XCTAssertThrowsError(try BackupFiles.verifyPackage(url))
        }
    }
    func testMissingMemberRejected() throws {
        try withPackage { url in
            try FileManager.default.removeItem(at: url.appendingPathComponent("manifest.json"))
            XCTAssertThrowsError(try BackupFiles.verifyPackage(url))
        }
    }
    func testExtraMemberRejected() throws {
        try withPackage { url in
            try Data("nonfinancial metadata".utf8).write(to: url.appendingPathComponent("extra.txt"))
            XCTAssertThrowsError(try BackupFiles.verifyPackage(url))
        }
    }
    func testSymlinkedMemberRejected() throws {
        try withPackage { url in
            let manifest = url.appendingPathComponent("manifest.json")
            let outside = url.deletingLastPathComponent().appendingPathComponent("metadata.json")
            try FileManager.default.moveItem(at: manifest, to: outside)
            try FileManager.default.createSymbolicLink(at: manifest, withDestinationURL: outside)
            XCTAssertThrowsError(try BackupFiles.verifyPackage(url))
        }
    }
    func testChecksumMismatchRejected() throws {
        try withPackage { url in
            try changeMetadata(url) { value in
                var payload = value["database"] as! [String: Any]
                payload["sha256"] = String(repeating: "0", count: 64); value["database"] = payload
            }
            XCTAssertThrowsError(try BackupFiles.verifyPackage(url)) { XCTAssertEqual($0 as? BackupError, .damaged) }
        }
    }
    func testPublicationNeverOverwrites() throws {
        let directory = try temporary(); defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source"), destination = directory.appendingPathComponent("destination")
        try Data("first".utf8).write(to: source); try Data("second".utf8).write(to: destination)
        XCTAssertThrowsError(try BackupFiles.moveWithoutOverwrite(source, destination))
        XCTAssertEqual(try Data(contentsOf: destination), Data("second".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }
    func testExistingOnlyOpenNeverCreates() throws {
        let directory = try temporary(); defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("missing.sqlite")
        XCTAssertThrowsError(try SQLiteDatabase(path: url.path).open(access: .existing))
        XCTAssertThrowsError(try SQLiteDatabase(path: url.path).open(access: .readOnlySnapshot))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    func testNormalExistingStartupMigrationIsSeparateFromStrictRecovery() throws {
        let directory = try temporary(); defer { try? FileManager.default.removeItem(at: directory) }
        let current = directory.appendingPathComponent("legacy.sqlite")
        let legacy = try SQLiteRepositoryProvider(path: current.path, migrations: Array(allMigrations.prefix(4)))
        try legacy.database.checkpointAndClose()
        XCTAssertThrowsError(try SQLiteRepositoryProvider(path: current.path, migrations: allMigrations, access: .existing))
        let startup = try SQLiteRepositoryProvider(path: current.path, migrations: allMigrations, access: .existing, migrateExisting: true)
        defer { startup.database.close() }
        try BackupCompatibility.verifyDatabase(startup.database)
    }
    func testFirstUseNeedsExplicitCreationAndNoRecoveryAssets() throws {
        let directory = try temporary(); defer { try? FileManager.default.removeItem(at: directory) }
        let layout = RestoreLayout(current: directory.appendingPathComponent("missing-parent/current.sqlite"))
        XCTAssertTrue(try layout.permitsExplicitCreation())
        XCTAssertFalse(FileManager.default.fileExists(atPath: layout.parent.path))
        try BackupFiles.createDirectory(layout.parent)
        try Data("nonfinancial interrupted-operation metadata".utf8).write(to: layout.receipt)
        XCTAssertFalse(try layout.permitsExplicitCreation())
    }
    func testRestoreStagingCreatesMissingParentWithoutCreatingLedger() throws {
        let directory = try temporary(); defer { try? FileManager.default.removeItem(at: directory) }
        let layout = RestoreLayout(current: directory.appendingPathComponent("missing-parent/current.sqlite"))
        let operation = UUID()
        try layout.createOperation(operation)
        XCTAssertTrue(BackupFiles.exists(layout.operation(operation)))
        XCTAssertFalse(BackupFiles.exists(layout.current))
        XCTAssertFalse(try layout.permitsExplicitCreation())
        try layout.removeOperation(operation)
        XCTAssertTrue(try layout.permitsExplicitCreation())
    }
    func testStaleFirstUseChoiceKeepsValidCurrentProviderAvailable() async throws {
        let directory = try temporary(); defer { try? FileManager.default.removeItem(at: directory) }
        let current = directory.appendingPathComponent("current.sqlite")
        let coordinator = BackupRestoreCoordinator(testingAt: current)
        coordinator.configureTarget(current)
        XCTAssertTrue(coordinator.canCreateNewLedger)
        let provider = try SQLiteRepositoryProvider(path: current.path, migrations: allMigrations)
        defer { provider.database.close() }
        let saved = DatabaseProvider.shared
        DatabaseProvider.shared = .verifiedSQLite(provider)
        defer { DatabaseProvider.shared = saved }
        let generation = DatabaseProvider.shared.generationToken
        await coordinator.createNewLedger()
        XCTAssertFalse(coordinator.canCreateNewLedger)
        XCTAssertTrue(DatabaseProvider.shared.persistenceState.isUsable)
        XCTAssertEqual(DatabaseProvider.shared.generationToken, generation)
        XCTAssertFalse(DatabaseActivityGate.shared.hasExclusiveOperation)
    }
    func testCancelledBackupPublishesNothingAndReleasesOwnership() async throws {
        let directory = try temporary(); defer { try? FileManager.default.removeItem(at: directory) }
        let current = directory.appendingPathComponent("current.sqlite")
        let destination = directory.appendingPathComponent("destination")
        try BackupFiles.createDirectory(destination)
        let provider = try SQLiteRepositoryProvider(path: current.path, migrations: allMigrations)
        defer { provider.database.close() }
        let saved = DatabaseProvider.shared
        DatabaseProvider.shared = .verifiedSQLite(provider)
        defer { DatabaseProvider.shared = saved }
        let coordinator = BackupRestoreCoordinator(testingAt: current)
        coordinator.installTestProvider(provider)
        let operation = Task { await coordinator.createBackup(to: destination) }
        operation.cancel()
        await operation.value
        XCTAssertFalse(coordinator.isBusy)
        XCTAssertNil(coordinator.lastBackupURL)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: destination.path).isEmpty)
        XCTAssertFalse(DatabaseActivityGate.shared.hasActiveOperations)
        XCTAssertEqual(coordinator.message, "Cancelled. Current Database is unchanged.")
    }
    func testPreparedWorkAndDraftsBlockReplacement() throws {
        let gate = DatabaseActivityGate()
        let lease = try gate.begin(.preparedAwaitingConfirmation)
        XCTAssertFalse(gate.beginExclusive())
        lease.finish()
        final class Draft { var dirty = true }
        let draft = Draft()
        gate.registerDraftOwner(draft) { [weak draft] in draft?.dirty == true }
        XCTAssertFalse(gate.beginExclusive())
        draft.dirty = false
        XCTAssertTrue(gate.beginExclusive())
        XCTAssertThrowsError(try gate.begin(.repositoryWrite))
        gate.finishExclusive(providerChanged: true)
        XCTAssertFalse(gate.hasActiveOperations)
    }
    func testStaleGenerationRejectsOperations() throws {
        let validity = ProviderGenerationValidity()
        XCTAssertEqual(try validity.withValidOperation { 7 }, 7)
        validity.invalidate()
        XCTAssertThrowsError(try validity.withValidOperation { 9 })
    }
}
