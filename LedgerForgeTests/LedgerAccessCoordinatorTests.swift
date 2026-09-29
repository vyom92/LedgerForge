import Foundation
import XCTest
@testable import LedgerForge

@MainActor
final class LedgerAccessCoordinatorTests: XCTestCase {
    private func location() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-authority-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root.appendingPathComponent("mechanics.sqlite")
    }

    private func probe(_ url: URL, scenario: String) throws -> String {
        let executable = try XCTUnwrap(Bundle(for: Self.self).resourceURL?.appendingPathComponent("LedgerForgeSubprocessProbe"))
        let process = Process(), pipe = Pipe()
        process.executableURL = executable
        process.arguments = [url.path, scenario, "mechanics", "authority"]
        process.standardOutput = pipe
        try process.run(); process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(object["result"] as? String)
    }

    func testWritableConnectionCannotBecomeImmutableToBypassAuthority() throws {
        let url = try location(), db = SQLiteDatabase(path: try location().path)
        try db.open(); defer { db.close() }
        XCTAssertThrowsError(try db.open(access: .readOnlySnapshot))
        let target = SQLiteDatabase(path: url.path); try target.open()
        let permit = try LedgerAccessCoordinator.shared(path: url.path).beginLifecycle()
        XCTAssertThrowsError(try target.open(access: .readOnlySnapshot))
        XCTAssertThrowsError(try target.execute(sql: "CREATE TABLE forbidden(value INTEGER);"))
        _ = try permit.finish(schemaVersion: 0)
        target.close()
    }

    func testRecursionAndTwoConnections() throws {
        let url = try location()
        let first = SQLiteDatabase(path: url.path); try first.open(); defer { first.close() }
        try first.execute(sql: "CREATE TABLE mechanics(value INTEGER);")
        let second = SQLiteDatabase(path: url.path); try second.open(access: .existing); defer { second.close() }
        try first.withExclusiveAccess {
            try first.withExclusiveAccess { try first.execute(sql: "INSERT INTO mechanics VALUES(1);") }
            XCTAssertEqual(try second.queryInt("SELECT count(*) FROM mechanics;"), 1)
        }
    }

    func testSeparateThreadsSerializeAndExternalChangesInvalidateRestoreCounter() throws {
        let url = try location()
        let first = SQLiteDatabase(path: url.path); try first.open(); defer { first.close() }
        try first.execute(sql: "CREATE TABLE mechanics(value INTEGER);")
        let second = SQLiteDatabase(path: url.path); try second.open(access: .existing); defer { second.close() }
        let before = try first.totalChangeCounter()
        let entered = DispatchSemaphore(value: 0), completed = DispatchSemaphore(value: 0)
        try first.withExclusiveAccess {
            DispatchQueue.global().async {
                entered.signal()
                try? second.execute(sql: "INSERT INTO mechanics VALUES(2);")
                completed.signal()
            }
            XCTAssertEqual(entered.wait(timeout: .now() + 2), .success)
            XCTAssertEqual(completed.wait(timeout: .now() + 0.05), .timedOut)
        }
        XCTAssertEqual(completed.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(try first.queryInt("SELECT count(*) FROM mechanics;"), 1)
        XCTAssertNotEqual(try first.totalChangeCounter(), before)
    }

    func testEnrolledHelperUsesExactExistingSchemaAndCannotMigrate() throws {
        let url = try location()
        let provider = try SQLiteRepositoryProvider(path: url.path)
        let stamp = try XCTUnwrap(provider.database.currentActivationStamp)
        let helper = try SQLiteRepositoryProvider.openEnrolledExisting(path: url.path, expected: stamp)
        XCTAssertEqual(helper.database.currentActivationStamp, stamp)
        helper.database.close(); provider.database.close()
        let other = url.appendingPathExtension("incomplete")
        let incomplete = SQLiteDatabase(path: other.path); try incomplete.open(); incomplete.close()
        let incompleteStamp = try LedgerAccessCoordinator.shared(path: other.path).readStamp()
        XCTAssertThrowsError(try SQLiteRepositoryProvider.openEnrolledExisting(path: other.path, expected: incompleteStamp))
    }

    func testEnrolledHelperScopesConnectionsAcrossNetworkPauseReplacementAndExplicitClose() throws {
        let url = try location()
        let foreground = try SQLiteRepositoryProvider(path: url.path)
        let initial = try XCTUnwrap(foreground.database.currentActivationStamp)
        let helper = try SQLiteRepositoryProvider.openEnrolledExisting(path: url.path, expected: initial)

        // Nested repository work keeps one handle while the operation is
        // synchronous, then the enrolled helper closes it before its network
        // await begins.
        try helper.database.withExclusiveAccess {
            try helper.database.execute(sql: "CREATE TEMP TABLE scoped_helper_connection(value INTEGER);")
            try helper.database.execute(sql: "INSERT INTO scoped_helper_connection VALUES(1);")
            XCTAssertEqual(try helper.database.queryInt("SELECT count(*) FROM scoped_helper_connection;"), 1)
            try helper.database.execute(sql: "CREATE TABLE scoped_connection_mechanics(value INTEGER);")
            try helper.database.execute(sql: "BEGIN IMMEDIATE;")
            try helper.database.execute(sql: "INSERT INTO scoped_connection_mechanics VALUES(1);")
            try helper.database.execute(sql: "ROLLBACK;")
            XCTAssertEqual(try helper.database.queryInt("SELECT count(*) FROM scoped_connection_mechanics;"), 0)
        }
        XCTAssertThrowsError(try helper.database.withExclusiveAccess {
            try helper.database.queryInt("SELECT count(*) FROM scoped_helper_connection;")
        })

        // The retained helper models an outstanding network request. It owns
        // its old activation but no SQLite vnode while replacement proceeds.
        let candidate = url.appendingPathExtension("candidate")
        try foreground.database.createBackup(at: candidate.path)
        let authority = LedgerAccessCoordinator.shared(path: url.path)
        let permit = try authority.beginLifecycle()
        foreground.database.lifecyclePermit = permit
        try foreground.database.checkpointAndClose()
        try FileManager.default.moveItem(at: url, to: url.appendingPathExtension("previous"))
        try FileManager.default.moveItem(at: candidate, to: url)
        let replacement = SQLiteDatabase(path: url.path, lifecyclePermit: permit)
        try replacement.open(access: .existing)
        let replacementStamp = try permit.finish(schemaVersion: allMigrations.count)
        try replacement.adoptCompletedLifecycle(replacementStamp)

        // The old helper cannot reopen or publish after its simulated network
        // completion, and its old transaction left no writable residue.
        XCTAssertThrowsError(try helper.database.withExclusiveAccess {
            try helper.database.execute(sql: "INSERT INTO scoped_connection_mechanics VALUES(2);")
        })
        XCTAssertEqual(try replacement.queryInt("SELECT count(*) FROM scoped_connection_mechanics;"), 0)

        let renewed = try SQLiteRepositoryProvider.openEnrolledExisting(path: url.path, expected: replacementStamp)
        try renewed.database.closeChecked()
        XCTAssertThrowsError(try renewed.database.queryInt("SELECT 1;"))
        replacement.close()
    }

    func testLifecycleRefusesBodyAndOldInodeThenPublishesNewEpoch() throws {
        let url = try location()
        let old = SQLiteDatabase(path: url.path); try old.open()
        try old.execute(sql: "CREATE TABLE mechanics(value INTEGER);")
        let initial = try XCTUnwrap(old.currentActivationStamp)
        let authority = LedgerAccessCoordinator.shared(path: url.path)
        let permit = try authority.beginLifecycle()
        var executed = false
        XCTAssertThrowsError(try old.withExclusiveAccess { executed = true })
        XCTAssertFalse(executed)
        old.lifecyclePermit = permit
        try old.checkpointAndClose()
        try FileManager.default.moveItem(at: url, to: url.appendingPathExtension("previous"))
        let candidateURL = url.appendingPathExtension("candidate")
        let candidate = SQLiteDatabase(path: candidateURL.path); try candidate.open()
        try candidate.execute(sql: "CREATE TABLE mechanics(value INTEGER);")
        try candidate.checkpointAndClose()
        try FileManager.default.moveItem(at: candidateURL, to: url)
        let next = SQLiteDatabase(path: url.path, lifecyclePermit: permit)
        try next.open(access: .existing)
        let stamp = try permit.finish(schemaVersion: 0)
        try next.adoptCompletedLifecycle(stamp)
        XCTAssertNotEqual(stamp.epoch, initial.epoch)
        XCTAssertNotEqual(stamp.inode, initial.inode)
        XCTAssertThrowsError(try authority.withAccess { try authority.validate(expected: initial, permit: nil) })
        next.close()
    }

    func testFailedTransitionRemainsPendingAndCanRecover() throws {
        let url = try location()
        let db = SQLiteDatabase(path: url.path); try db.open(); db.close()
        let authority = LedgerAccessCoordinator.shared(path: url.path)
        var permit: LedgerLifecyclePermit? = try authority.beginLifecycle()
        XCTAssertNotNil(permit)
        permit = nil
        let blocked = SQLiteDatabase(path: url.path)
        XCTAssertThrowsError(try blocked.open(access: .existing))
        XCTAssertEqual(try probe(url, scenario: "authority-open"), "pending")
        let recovery = try authority.beginLifecycle(recovering: true)
        _ = try recovery.finish(schemaVersion: 0)
        try blocked.open(access: .existing); blocked.close()
    }

    func testHelperRefusesAbsentAuthorityBeforeWritableOpen() throws {
        let url = try location()
        let stamp = LedgerActivationStamp(epoch: UUID(), device: 0, inode: 0, schemaVersion: allMigrations.count,
            compatibilityVersion: LedgerAccessCoordinator.compatibilityVersion, transitioning: false)
        XCTAssertThrowsError(try SQLiteRepositoryProvider.openEnrolledExisting(path: url.path, expected: stamp))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path + "-wal"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path + ".activation.json"))
    }

    func testRecoveryCannotRewriteFutureCompatibilityAndPermitCannotFinishTwice() throws {
        let url = try location()
        let db = SQLiteDatabase(path: url.path); try db.open(); db.close()
        let authority = LedgerAccessCoordinator.shared(path: url.path)
        let permit = try authority.beginLifecycle()
        let stable = try permit.finish(schemaVersion: 0)
        XCTAssertThrowsError(try permit.finish(schemaVersion: 0))
        XCTAssertEqual(try authority.readStamp(), stable)
        let future = LedgerActivationStamp(epoch: stable.epoch, device: stable.device, inode: stable.inode,
            schemaVersion: 0, compatibilityVersion: LedgerAccessCoordinator.compatibilityVersion + 1, transitioning: true)
        try JSONEncoder().encode(future).write(to: authority.activationURL, options: .atomic)
        XCTAssertThrowsError(try authority.beginLifecycle(recovering: true))
        XCTAssertEqual(try authority.readStamp(), future)
    }

    func testImmutableBackupDoesNotCreateAuthority() throws {
        let url = try location()
        let db = SQLiteDatabase(path: url.path); try db.open()
        try db.execute(sql: "CREATE TABLE mechanics(value INTEGER);")
        let copy = url.appendingPathExtension("backup")
        try db.createBackup(at: copy.path); db.close()
        let read = SQLiteDatabase(path: copy.path); try read.open(access: .readOnlySnapshot)
        XCTAssertEqual(try read.queryInt("SELECT count(*) FROM mechanics;"), 0)
        read.close()
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.path + ".activation.json"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.path + ".access.lock"))
    }

    func testDevelopmentResetUsesSameAuthorityWithEmptySchema() throws {
        let root = try location().deletingLastPathComponent()
        let identity = DevelopmentDatabaseIdentity(applicationSupportDirectory: root)
        try FileManager.default.createDirectory(at: identity.canonicalDevelopmentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let saved = DatabaseProvider.shared
        defer { DatabaseProvider.shared = saved }
        let coordinator = DevelopmentDatabaseLifecycleCoordinator(identity: identity, activityGate: DevelopmentDatabaseActivityGate())
        let initial = try SQLiteRepositoryProvider(path: identity.canonicalDevelopmentURL.path)
        _ = try coordinator.installInitialProvider(initial)
        defer { coordinator.closeOwnedProvider() }
        guard case .activated = coordinator.activate(.persistentDebug) else { return XCTFail("Empty profile activation failed") }
        let authority = LedgerAccessCoordinator.shared(path: identity.persistentDebugURL.path)
        let before = try authority.readStamp()
        guard case .activated = coordinator.resetActiveProfile() else { return XCTFail("Empty profile reset failed") }
        let after = try authority.withAccess { try authority.validate(expected: nil, permit: nil) }
        XCTAssertNotEqual(before.epoch, after.epoch)
        XCTAssertFalse(after.transitioning)
        XCTAssertEqual(after.schemaVersion, allMigrations.count)
        XCTAssertFalse(FileManager.default.fileExists(atPath: identity.backupURL.path + ".activation.json"))
    }

    func testIndependentProcessCannotTakeLifecycleLock() throws {
        let url = try location()
        let db = SQLiteDatabase(path: url.path); try db.open(); db.close()
        let authority = LedgerAccessCoordinator.shared(path: url.path)
        let permit = try authority.beginLifecycle()
        XCTAssertEqual(try probe(url, scenario: "authority-lock"), "contention")
        _ = try permit.finish(schemaVersion: 0)
    }
}
