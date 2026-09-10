import Dispatch
import Foundation
import Synchronization
import Testing
@testable import LedgerForge

/// Source-independent checks for synchronous SQLite and provider-generation
/// ownership. The tables and values here are mechanics-only probes; no
/// financial statement or domain graph is authored by this suite.
@Suite(.serialized)
struct SQLiteOwnershipTests {
    @Test
    func escapedRowsRemainOwnedAfterQuerySecondQueryAndCheckedClose() throws {
        let root = try temporaryDirectory(named: "SQLiteRowOwnership")
        defer { try? FileManager.default.removeItem(at: root) }
        let database = SQLiteDatabase(path: root.appendingPathComponent("probe.sqlite").path)
        try database.open()
        defer { database.close() }

        try database.execute(sql: """
            CREATE TABLE row_ownership_probe (
                id INTEGER PRIMARY KEY,
                label TEXT,
                enabled INTEGER NOT NULL
            );
            """)
        try database.executePrepared(
            sql: "INSERT INTO row_ownership_probe(id, label, enabled) VALUES(?, ?, ?);",
            params: [1, "first", true]
        )
        try database.executePrepared(
            sql: "INSERT INTO row_ownership_probe(id, label, enabled) VALUES(?, ?, ?);",
            params: [2, "second", false]
        )

        var escaped: SQLiteRow?
        let first = try database.query(
            sql: "SELECT id, label, enabled FROM row_ownership_probe WHERE id = 1;"
        ) { row in
            escaped = row
            return RowSnapshot(
                id: row.int64(at: 0),
                label: row.string(at: 1),
                enabled: row.bool(at: 2)
            )
        }
        #expect(first == [RowSnapshot(id: 1, label: "first", enabled: true)])

        let second = try database.query(
            sql: "SELECT id, label, enabled FROM row_ownership_probe WHERE id = 2;"
        ) { row in
            RowSnapshot(
                id: row.int64(at: 0),
                label: row.string(at: 1),
                enabled: row.bool(at: 2)
            )
        }
        #expect(second == [RowSnapshot(id: 2, label: "second", enabled: false)])

        // Exercise SQLite's existing NULL, numeric/text conversion and Int32
        // boolean semantics without constructing any financial input.
        let scalarRows = try database.query(sql: "SELECT NULL, -9, 4294967296, 1.5, '17x';") { $0 }
        try database.checkpointAndClose()

        #expect(escaped?.int64(at: 0) == 1)
        #expect(escaped?.string(at: 1) == "first")
        #expect(escaped?.bool(at: 2) == true)
        #expect(escaped?.string(at: 99) == nil)
        #expect(escaped?.int64(at: -1) == nil)
        let scalars = try #require(scalarRows.first)
        #expect(scalars.string(at: 0) == nil)
        #expect(scalars.int64(at: 0) == nil)
        #expect(!scalars.bool(at: 0))
        #expect(scalars.int64(at: 1) == -9)
        #expect(scalars.bool(at: 1))
        #expect(scalars.int64(at: 2) == 4_294_967_296)
        #expect(!scalars.bool(at: 2))
        #expect(scalars.string(at: 3) == "1.5")
        #expect(scalars.int64(at: 3) == 1)
        #expect(scalars.string(at: 4) == "17x")
        #expect(scalars.int64(at: 4) == 17)
    }

    @Test
    func nestedMapQueryPreservesOuterRowValues() throws {
        let root = try temporaryDirectory(named: "SQLiteNestedQuery")
        defer { try? FileManager.default.removeItem(at: root) }
        let database = SQLiteDatabase(path: root.appendingPathComponent("probe.sqlite").path)
        try database.open()
        defer { database.close() }

        try database.execute(sql: """
            CREATE TABLE nested_query_probe (
                id INTEGER PRIMARY KEY,
                label TEXT NOT NULL
            );
            INSERT INTO nested_query_probe(id, label) VALUES(1, 'outer-one');
            INSERT INTO nested_query_probe(id, label) VALUES(2, 'outer-two');
            """)

        let values = try database.query(
            sql: "SELECT id, label FROM nested_query_probe ORDER BY id;"
        ) { outer in
            let outerID = outer.int64(at: 0) ?? -1
            let beforeNested = outer.string(at: 1)
            let nested = try database.query(
                sql: "SELECT label FROM nested_query_probe WHERE id = ?;",
                params: [outerID]
            ) { inner in
                inner.string(at: 0) ?? ""
            }
            let afterNested = outer.string(at: 1)
            #expect(nested == [beforeNested ?? ""])
            return "\(outerID)|\(beforeNested ?? "")|\(afterNested ?? "")|\(nested.first ?? "")"
        }

        #expect(values == [
            "1|outer-one|outer-one|outer-one",
            "2|outer-two|outer-two|outer-two"
        ])
    }

    @Test
    func exclusiveScopeSerializesSameConnectionTransactionAndRollback() throws {
        let root = try temporaryDirectory(named: "SQLiteTransactionOwnership")
        defer { try? FileManager.default.removeItem(at: root) }
        let database = SQLiteDatabase(path: root.appendingPathComponent("probe.sqlite").path)
        try database.open()
        defer { database.close() }

        try database.execute(sql: """
            CREATE TABLE transaction_ownership_probe (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                owner TEXT NOT NULL
            );
            """)

        let state = Mutex(OwnershipProbeState())
        let outerStartedForMain = DispatchSemaphore(value: 0)
        let outerStartedForCompetitor = DispatchSemaphore(value: 0)
        let competitorAttempted = DispatchSemaphore(value: 0)
        let releaseOuter = DispatchSemaphore(value: 0)
        let competitorEntered = DispatchSemaphore(value: 0)
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { group.leave() }
            do {
                try database.withExclusiveAccess {
                    try database.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
                    try database.executePrepared(
                        sql: "INSERT INTO transaction_ownership_probe(owner) VALUES(?);",
                        params: ["outer-first"]
                    )
                    state.withLock { $0.events.append("outer-started") }
                    outerStartedForMain.signal()
                    outerStartedForCompetitor.signal()
                    _ = releaseOuter.wait(timeout: .now() + 5)
                    try database.executePrepared(
                        sql: "INSERT INTO transaction_ownership_probe(owner) VALUES(?);",
                        params: ["outer-second"]
                    )
                    try database.execute(sql: "ROLLBACK;")
                    state.withLock { $0.events.append("outer-rolled-back") }
                }
            } catch {
                record(error, in: state)
            }
        }

        #expect(outerStartedForMain.wait(timeout: .now() + 5) == .success)

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { group.leave() }
            guard outerStartedForCompetitor.wait(timeout: .now() + 5) == .success else {
                recordMessage("competitor did not observe outer transaction", in: state)
                competitorAttempted.signal()
                return
            }
            competitorAttempted.signal()
            do {
                try database.withExclusiveAccess {
                    state.withLock { $0.events.append("competitor-entered") }
                    competitorEntered.signal()
                    try database.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
                    try database.executePrepared(
                        sql: "INSERT INTO transaction_ownership_probe(owner) VALUES(?);",
                        params: ["competitor"]
                    )
                    try database.execute(sql: "COMMIT;")
                }
            } catch {
                record(error, in: state)
            }
        }

        #expect(competitorAttempted.wait(timeout: .now() + 5) == .success)
        #expect(competitorEntered.wait(timeout: .now() + .milliseconds(100)) == .timedOut)
        releaseOuter.signal()
        #expect(group.wait(timeout: .now() + 10) == .success)

        let snapshot = state.withLock { $0 }
        #expect(snapshot.errors.isEmpty)
        #expect(
            snapshot.events.firstIndex(of: "outer-rolled-back")
                .map { rollback in
                    snapshot.events.firstIndex(of: "competitor-entered")
                        .map { rollback < $0 } ?? false
                } == .some(true)
        )

        let owners = try database.query(
            sql: "SELECT owner FROM transaction_ownership_probe ORDER BY id;"
        ) { row in
            row.string(at: 0) ?? ""
        }
        #expect(owners == ["competitor"])
    }

    @Test
    func checkedCloseWaitsForActiveMappingAndReentrantCloseRetainsHandle() throws {
        let root = try temporaryDirectory(named: "SQLiteCloseOwnership")
        defer { try? FileManager.default.removeItem(at: root) }
        let database = SQLiteDatabase(path: root.appendingPathComponent("probe.sqlite").path)
        try database.open()
        defer { database.close() }

        try database.execute(sql: """
            CREATE TABLE close_ownership_probe (
                id INTEGER PRIMARY KEY,
                label TEXT NOT NULL
            );
            INSERT INTO close_ownership_probe(id, label) VALUES(1, 'held');
            """)

        let state = Mutex(CloseProbeState())
        let mappingEntered = DispatchSemaphore(value: 0)
        let releaseMapping = DispatchSemaphore(value: 0)
        let closeStarted = DispatchSemaphore(value: 0)
        let closeFinished = DispatchSemaphore(value: 0)
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { group.leave() }
            do {
                let values = try database.query(
                    sql: "SELECT label FROM close_ownership_probe;"
                ) { row in
                    mappingEntered.signal()
                    _ = releaseMapping.wait(timeout: .now() + 5)
                    return row.string(at: 0) ?? ""
                }
                state.withLock { $0.queryValues = values }
            } catch {
                state.withLock { $0.queryError = String(describing: error) }
            }
        }

        #expect(mappingEntered.wait(timeout: .now() + 5) == .success)

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { group.leave() }
            closeStarted.signal()
            do {
                try database.checkpointAndClose()
                state.withLock { $0.closeSucceeded = true }
            } catch {
                state.withLock { $0.closeError = String(describing: error) }
            }
            closeFinished.signal()
        }

        #expect(closeStarted.wait(timeout: .now() + 5) == .success)
        #expect(closeFinished.wait(timeout: .now() + .milliseconds(100)) == .timedOut)
        releaseMapping.signal()
        #expect(group.wait(timeout: .now() + 10) == .success)

        let firstRace = state.withLock { $0 }
        #expect(firstRace.queryValues == ["held"])
        #expect(firstRace.queryError == nil)
        #expect(firstRace.closeSucceeded)
        #expect(firstRace.closeError == nil)

        try database.open()
        let reentrantValues = try database.query(
            sql: "SELECT label FROM close_ownership_probe;"
        ) { row in
            database.close()
            return row.string(at: 0) ?? ""
        }
        #expect(reentrantValues == ["held"])
        #expect(try database.queryInt("SELECT COUNT(*) FROM close_ownership_probe;") == 1)
        try database.checkpointAndClose()
    }

    @Test
    func openCloseReopenRetainsIntegrityAndFailedOpenCanRetry() throws {
        let root = try temporaryDirectory(named: "SQLiteOpenRetry")
        defer { try? FileManager.default.removeItem(at: root) }
        let missingParent = root.appendingPathComponent("created-after-failure", isDirectory: true)
        let path = missingParent.appendingPathComponent("probe.sqlite").path
        let database = SQLiteDatabase(path: path)
        defer { database.close() }

        var openError: SQLiteDatabaseError?
        do {
            try database.open()
            Issue.record("open unexpectedly succeeded before its parent directory existed")
        } catch let error as SQLiteDatabaseError {
            openError = error
        } catch {
            Issue.record("open returned an unexpected error: \(error)")
        }
        if let openError {
            guard case .execution(let execution) = openError else {
                Issue.record("failed open did not report an execution error")
                return
            }
            #expect(execution.operation == .open)
        } else {
            Issue.record("failed open did not produce an error")
            return
        }
        expectDatabaseNotOpen(database)

        try FileManager.default.createDirectory(at: missingParent, withIntermediateDirectories: true)
        try database.open()
        try database.execute(sql: """
            CREATE TABLE lifetime_probe (
                id INTEGER PRIMARY KEY,
                label TEXT NOT NULL
            );
            """)
        try database.executePrepared(
            sql: "INSERT INTO lifetime_probe(id, label) VALUES(?, ?);",
            params: [1, "first"]
        )
        try database.checkpointAndClose()
        expectDatabaseNotOpen(database)

        try database.open()
        #expect(try database.queryInt("SELECT COUNT(*) FROM lifetime_probe;") == 1)
        try database.executePrepared(
            sql: "INSERT INTO lifetime_probe(id, label) VALUES(?, ?);",
            params: [2, "second"]
        )
        try database.checkpointAndClose()
        expectDatabaseNotOpen(database)

        let reopened = SQLiteDatabase(path: path)
        try reopened.open()
        defer { reopened.close() }
        let labels = try reopened.query(sql: "SELECT label FROM lifetime_probe ORDER BY id;") { row in
            row.string(at: 0) ?? ""
        }
        #expect(labels == ["first", "second"])
        #expect(try integrityCheck(reopened) == "ok")
        try reopened.checkpointAndClose()
    }

    @Test
    func concurrentMigrationsOnSameConnectionProduceExactCurrentHistory() throws {
        let root = try temporaryDirectory(named: "SQLiteMigrationOwnership")
        defer { try? FileManager.default.removeItem(at: root) }
        let database = SQLiteDatabase(path: root.appendingPathComponent("probe.sqlite").path)
        defer { database.close() }

        let state = Mutex(OwnershipProbeState())
        let group = DispatchGroup()
        for _ in 0..<2 {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                defer { group.leave() }
                do {
                    try database.runMigrations(allMigrations)
                } catch {
                    record(error, in: state)
                }
            }
        }

        #expect(group.wait(timeout: .now() + 30) == .success)
        let errors = state.withLock { $0.errors }
        #expect(errors.isEmpty)

        let versions = try database.query(
            sql: "SELECT version FROM schema_migrations ORDER BY id;"
        ) { row in
            row.int64(at: 0) ?? -1
        }
        #expect(versions == Array(1...17).map { Int64($0) })
        #expect(try database.queryInt("SELECT COUNT(*) FROM schema_migrations;") == 17)
        #expect(try integrityCheck(database) == "ok")
        try database.checkpointAndClose()
    }

    @Test
    func generationInvalidationWaitsForAdmittedOperationAndRejectsFutureCallback() throws {
        let validity = ProviderGenerationValidity()
        let state = Mutex(GenerationProbeState())
        let operationEntered = DispatchSemaphore(value: 0)
        let releaseOperation = DispatchSemaphore(value: 0)
        let invalidationStarted = DispatchSemaphore(value: 0)
        let invalidationFinished = DispatchSemaphore(value: 0)
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { group.leave() }
            do {
                let result = try validity.withValidOperation {
                    state.withLock {
                        $0.callbackCount += 1
                        $0.events.append("operation-entered")
                    }
                    operationEntered.signal()
                    _ = releaseOperation.wait(timeout: .now() + 5)
                    state.withLock { $0.events.append("operation-exited") }
                    return 42
                }
                state.withLock { $0.operationResult = result }
            } catch {
                record(error, in: state)
            }
        }

        #expect(operationEntered.wait(timeout: .now() + 5) == .success)

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { group.leave() }
            invalidationStarted.signal()
            validity.invalidate()
            state.withLock { $0.events.append("invalidated") }
            invalidationFinished.signal()
        }

        #expect(invalidationStarted.wait(timeout: .now() + 5) == .success)
        #expect(invalidationFinished.wait(timeout: .now() + .milliseconds(100)) == .timedOut)
        releaseOperation.signal()
        #expect(group.wait(timeout: .now() + 10) == .success)

        let admitted = state.withLock { $0 }
        #expect(admitted.errors.isEmpty)
        #expect(admitted.callbackCount == 1)
        #expect(admitted.operationResult == 42)
        #expect(
            admitted.events.firstIndex(of: "operation-exited")
                .map { exited in
                    admitted.events.firstIndex(of: "invalidated")
                        .map { exited < $0 } ?? false
                } == .some(true)
        )

        let callbackCountBeforeRejectedCall = state.withLock { $0.callbackCount }
        do {
            _ = try validity.withValidOperation {
                state.withLock { $0.callbackCount += 1 }
                return 99
            }
            Issue.record("invalidated generation unexpectedly admitted a future callback")
        } catch let error as RepositoryError {
            guard case .staleProviderGeneration = error else {
                Issue.record("future operation returned an unexpected repository error")
                return
            }
        } catch {
            Issue.record("future operation returned an unexpected error: \(error)")
        }
        #expect(state.withLock { $0.callbackCount } == callbackCountBeforeRejectedCall)
    }

    @Test
    func generationGuardAllowsSameThreadReentry() throws {
        let validity = ProviderGenerationValidity()
        let callbackCount = Mutex(0)

        let result: String = try validity.withValidOperation {
            callbackCount.withLock { $0 += 1 }
            return try validity.withValidOperation {
                callbackCount.withLock { $0 += 1 }
                return "nested-success"
            }
        }
        #expect(result == "nested-success")
        #expect(callbackCount.withLock { $0 } == 2)

        validity.invalidate()
        do {
            _ = try validity.withValidOperation {
                callbackCount.withLock { $0 += 1 }
                return "unexpected"
            }
            Issue.record("invalidated generation unexpectedly admitted reentry")
        } catch let error as RepositoryError {
            guard case .staleProviderGeneration = error else {
                Issue.record("invalidated reentry returned an unexpected repository error")
                return
            }
        } catch {
            Issue.record("invalidated reentry returned an unexpected error: \(error)")
        }
        #expect(callbackCount.withLock { $0 } == 2)
    }
}

private struct RowSnapshot: Equatable, Sendable {
    let id: Int64?
    let label: String?
    let enabled: Bool
}

private struct OwnershipProbeState: Sendable {
    var events: [String] = []
    var errors: [String] = []
}

private struct CloseProbeState: Sendable {
    var queryValues: [String] = []
    var queryError: String?
    var closeSucceeded = false
    var closeError: String?
}

private struct GenerationProbeState: Sendable {
    var events: [String] = []
    var callbackCount = 0
    var operationResult: Int?
    var errors: [String] = []
}

private func temporaryDirectory(named name: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "LedgerForge-\(name)-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private func integrityCheck(_ database: SQLiteDatabase) throws -> String? {
    try database.query(sql: "PRAGMA integrity_check;") { row in
        row.string(at: 0)
    }.first ?? nil
}

private func record(_ error: Error, in state: borrowing Mutex<OwnershipProbeState>) {
    state.withLock { $0.errors.append(String(describing: error)) }
}

private func record(_ error: Error, in state: borrowing Mutex<GenerationProbeState>) {
    state.withLock { $0.errors.append(String(describing: error)) }
}

private func recordMessage(_ message: String, in state: borrowing Mutex<OwnershipProbeState>) {
    state.withLock { $0.errors.append(message) }
}

private func expectDatabaseNotOpen(_ database: SQLiteDatabase) {
    do {
        _ = try database.queryInt("SELECT 1;")
        Issue.record("database unexpectedly accepted a query while closed")
    } catch let error as SQLiteDatabaseError {
        guard case .databaseNotOpen = error else {
            Issue.record("closed database returned an unexpected SQLite error")
            return
        }
    } catch {
        Issue.record("closed database returned an unexpected error: \(error)")
    }
}
