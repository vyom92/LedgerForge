// Database/SQLiteDatabase.swift
// Lightweight SQLite helper and migration runner for LedgerForge

import Foundation
import SQLite3

nonisolated private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

nonisolated public enum SQLiteOperation: String, Equatable, Sendable { case open, transaction, statement, query, migration, backup, checkpoint, close }

nonisolated public struct SQLiteExecutionError: Error, Equatable, Sendable, CustomStringConvertible {
    public let primaryCode: Int32
    public let extendedCode: Int32
    public let operation: SQLiteOperation
    public init(primaryCode: Int32, extendedCode: Int32, operation: SQLiteOperation) { self.primaryCode = primaryCode; self.extendedCode = extendedCode; self.operation = operation }
    public var isRetryableContention: Bool { primaryCode == SQLITE_BUSY || primaryCode == SQLITE_LOCKED }
    // SQLITE_CONSTRAINT_UNIQUE is a C macro that Swift does not import.
    public var isUniqueConstraint: Bool { primaryCode == SQLITE_CONSTRAINT && extendedCode == 2067 }
    public var description: String { "SQLite \(operation.rawValue) failed (\(primaryCode)/\(extendedCode))." }
}

nonisolated public enum SQLiteDatabaseError: Error, LocalizedError {
    case databaseNotOpen
    case prepareFailed(operation: SQLiteOperation)
    case execution(SQLiteExecutionError)
    case backupFailed(String)
    case checkpointFailed(Int32)
    case closeFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .databaseNotOpen:
            return "SQLite database is not open."
        case .prepareFailed(let operation):
            return "SQLite \(operation.rawValue) could not be prepared."
        case .execution(let error):
            return error.description
        case .backupFailed:
            return "SQLite backup could not be completed."
        case .checkpointFailed:
            return "SQLite checkpoint could not be completed."
        case .closeFailed:
            return "SQLite close could not be completed."
        }
    }
}

/// Owned values copied while the connection owns the prepared statement.
/// A returned row never retains a SQLite statement or column pointer.
nonisolated public struct SQLiteRow: Sendable {
    private struct Column: Sendable {
        let string: String?
        let int64: Int64?
        let bool: Bool
    }
    private let columns: [Column]

    fileprivate init(statement: OpaquePointer?) {
        columns = (0..<sqlite3_column_count(statement)).map { index in
            guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
                return Column(string: nil, int64: nil, bool: false)
            }
            let string = sqlite3_column_text(statement, index).map { String(cString: $0) }
            return Column(
                string: string,
                int64: sqlite3_column_int64(statement, index),
                bool: sqlite3_column_int(statement, index) != 0
            )
        }
    }

    private func column(at index: Int32) -> Column? {
        guard index >= 0, Int(index) < columns.count else { return nil }
        return columns[Int(index)]
    }

    public func string(at index: Int32) -> String? {
        column(at: index)?.string
    }

    public func int64(at index: Int32) -> Int64? {
        column(at: index)?.int64
    }

    public func bool(at index: Int32) -> Bool {
        column(at: index)?.bool ?? false
    }
}

/// Synchronous connection ownership shared by the app and subprocess helper.
///
/// `ownershipLock` protects every access to `db`, all statement/backup lifetimes,
/// and complete migration runs. Multi-call transactions must additionally hold
/// `withExclusiveAccess` from BEGIN through COMMIT or ROLLBACK. The recursive
/// lock permits existing nested repository queries on the same thread; callers
/// must not wait for another thread to use this connection from inside a scope.
/// Query callbacks execute synchronously under ownership and receive only copied
/// values. No SQLite pointer leaves this type. These invariants, rather than
/// SQLITE_OPEN_FULLMUTEX alone, justify the unchecked Sendable conformance.
nonisolated public final class SQLiteDatabase: @unchecked Sendable {
    private let path: String
    private let ownershipLock = NSRecursiveLock()
    private var db: OpaquePointer?

    public init(path: String) {
        self.path = path
    }

    deinit {
        close()
    }

    /// Keeps a synchronous, multi-call operation on this connection indivisible.
    /// Retain the repository's existing transaction decisions inside this scope.
    func withExclusiveAccess<Result>(_ operation: () throws -> Result) rethrows -> Result {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        return try operation()
    }

    public func open() throws {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        if db != nil { return }
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let extended = sqlite3_extended_errcode(db)
            close()
            throw SQLiteDatabaseError.execution(SQLiteExecutionError(primaryCode: extended & 0xff, extendedCode: extended, operation: .open))
        }
        // Protect every startup statement from concurrent openers, including
        // the first WAL-mode pragma used by independent providers.
        sqlite3_busy_timeout(db, 5000)
        // Configure recommended PRAGMAs for production-safe defaults
        // Enable write-ahead logging for concurrency
        do {
            try execute(sql: "PRAGMA journal_mode = WAL;")
            // Enable foreign keys enforcement
            try execute(sql: "PRAGMA foreign_keys = ON;")
            // Use NORMAL synchronous for balanced durability/performance
            try execute(sql: "PRAGMA synchronous = NORMAL;")
        } catch {
            close()
            throw error
        }
    }

    public func close() {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        // A reentrant callback can request close while its statement is active.
        // Preserve the live handle if SQLite refuses; checked close reports why.
        if let db, sqlite3_close(db) == SQLITE_OK {
            self.db = nil
        }
    }

    public func createBackup(at destinationPath: String) throws {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard let db else { throw SQLiteDatabaseError.databaseNotOpen }
        var destination: OpaquePointer?
        guard sqlite3_open_v2(destinationPath, &destination, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let destination else {
            if let destination { sqlite3_close(destination) }
            throw SQLiteDatabaseError.backupFailed("destination-open")
        }
        defer { sqlite3_close(destination) }
        guard let backup = sqlite3_backup_init(destination, "main", db, "main") else {
            throw SQLiteDatabaseError.backupFailed("initialization")
        }
        let stepResult = sqlite3_backup_step(backup, -1)
        let finishResult = sqlite3_backup_finish(backup)
        guard stepResult == SQLITE_DONE, finishResult == SQLITE_OK else {
            throw SQLiteDatabaseError.backupFailed("copy")
        }
    }

    public func checkpointAndClose() throws {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard let db else { throw SQLiteDatabaseError.databaseNotOpen }
        var logFrames: Int32 = 0
        var checkpointedFrames: Int32 = 0
        let checkpointResult = sqlite3_wal_checkpoint_v2(
            db,
            nil,
            SQLITE_CHECKPOINT_TRUNCATE,
            &logFrames,
            &checkpointedFrames
        )
        guard checkpointResult == SQLITE_OK else {
            throw SQLiteDatabaseError.checkpointFailed(checkpointResult)
        }
        let closeResult = sqlite3_close(db)
        guard closeResult == SQLITE_OK else {
            throw SQLiteDatabaseError.closeFailed(closeResult)
        }
        self.db = nil
    }

    public func execute(sql: String) throws {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard let db = db else { throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "DB not open"]) }
        var errMsg: UnsafeMutablePointer<Int8>? = nil
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if result != SQLITE_OK {
            sqlite3_free(errMsg)
            throw executionError(resultCode: result, operation: operation(for: sql))
        }
    }

    // Execute a prepared statement with parameter bindings. Parameters are bound in order.
    public func executePrepared(sql: String, params: [Any?] = []) throws {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard let db = db else { throw SQLiteDatabaseError.databaseNotOpen }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw SQLiteDatabaseError.prepareFailed(operation: operation(for: sql))
        }

        bind(params, to: stmt)

        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE && rc != SQLITE_ROW {
            throw executionError(resultCode: rc, operation: operation(for: sql))
        }
    }

    public func query<T>(sql: String, params: [Any?] = [], map: (SQLiteRow) throws -> T) throws -> [T] {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        guard let db = db else { throw SQLiteDatabaseError.databaseNotOpen }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw SQLiteDatabaseError.prepareFailed(operation: .query)
        }

        bind(params, to: stmt)

        var rows: [T] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW {
                rows.append(try map(SQLiteRow(statement: stmt)))
            } else if rc == SQLITE_DONE {
                return rows
            } else {
                throw executionError(resultCode: rc, operation: .query)
            }
        }
    }

    public func runMigrations(_ migrations: [Migration]) throws {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        try MigrationChainValidator.validateRegistered(migrations)
        try open()

        let hasMigrationTable = try tableExists("schema_migrations")
        let hasApplicationSchema = try querySingleInt(sql: """
            SELECT COUNT(*) FROM sqlite_master
            WHERE type = 'table'
              AND name NOT IN ('schema_migrations', 'sqlite_sequence');
            """) > 0

        if !hasMigrationTable, hasApplicationSchema {
            throw MigrationIntegrityError.missingPersistedVersion(1)
        }

        var persistedRecords = hasMigrationTable ? try migrationRecords() : []
        if persistedRecords.isEmpty, hasApplicationSchema {
            throw MigrationIntegrityError.missingPersistedVersion(1)
        }
        if !persistedRecords.isEmpty {
            try MigrationChainValidator.validatePersisted(
                persistedRecords,
                against: migrations,
                requiresCompleteChain: false
            )
        }

        try execute(sql: "CREATE TABLE IF NOT EXISTS schema_migrations (id INTEGER PRIMARY KEY AUTOINCREMENT, version INTEGER NOT NULL, name TEXT, applied_at DATETIME NOT NULL, checksum TEXT);")

        for migration in migrations.dropFirst(persistedRecords.count) {
            // Some schema rebuilds must temporarily opt into SQLite's legacy
            // ALTER TABLE behavior. PRAGMA state is connection-scoped rather
            // than transactional, so a failed multi-statement migration can
            // otherwise leak that temporary mode after ROLLBACK. Preserve the
            // caller's entry state on failure; a successful migration retains
            // responsibility for its declared final connection state.
            let legacyAlterTableWasEnabled = try querySingleInt(
                sql: "PRAGMA legacy_alter_table;"
            ) != 0
            if migration.requiresForeignKeysDisabled {
                try execute(sql: "PRAGMA foreign_keys = OFF;")
            }
            do {
                try beginTransaction()
                for check in migration.preflightChecks {
                    guard try check.run(self) else {
                        throw MigrationPreflightError.failed(issueCode: check.issueCode)
                    }
                }
                try execute(sql: migration.sql)
                if migration.requiresForeignKeysDisabled {
                    let foreignKeyViolations = try query(
                        sql: "PRAGMA foreign_key_check;",
                        params: []
                    ) { _ in true }
                    guard foreignKeyViolations.isEmpty else {
                        throw MigrationPreflightError.failed(issueCode: "migration.foreign-key-check")
                    }
                }
                let now = iso8601Now()
                try executePrepared(
                    sql: "INSERT INTO schema_migrations(version, name, applied_at, checksum) VALUES(?, ?, ?, ?);",
                    params: [migration.version, migration.name, now, migration.checksum]
                )
                try commit()
                if migration.requiresForeignKeysDisabled {
                    try execute(sql: "PRAGMA foreign_keys = ON;")
                }
            } catch {
                try? rollback()
                if migration.requiresForeignKeysDisabled {
                    try? execute(sql: "PRAGMA foreign_keys = ON;")
                }
                try? execute(sql: legacyAlterTableWasEnabled
                    ? "PRAGMA legacy_alter_table = ON;"
                    : "PRAGMA legacy_alter_table = OFF;")
                throw error
            }
        }

        persistedRecords = try migrationRecords()
        try MigrationChainValidator.validatePersisted(
            persistedRecords,
            against: migrations,
            requiresCompleteChain: true
        )
    }

    // MARK: - Helpers
    private func beginTransaction() throws {
        try execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
    }
    private func commit() throws {
        try execute(sql: "COMMIT;")
    }
    private func rollback() throws {
        try execute(sql: "ROLLBACK;")
    }

    private func querySingleInt(sql: String) throws -> Int {
        guard let db = db else { throw SQLiteDatabaseError.databaseNotOpen }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw SQLiteDatabaseError.prepareFailed(operation: .query)
        }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        }
        return 0
    }

    public func queryInt(_ sql: String) throws -> Int {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        return try querySingleInt(sql: sql)
    }

    func validatedMigrationHistory(
        against migrations: [Migration],
        requiresCompleteChain: Bool
    ) throws -> [PersistedMigrationRecord] {
        ownershipLock.lock()
        defer { ownershipLock.unlock() }
        try MigrationChainValidator.validateRegistered(migrations)
        guard try tableExists("schema_migrations") else {
            throw MigrationIntegrityError.missingPersistedVersion(1)
        }
        let records = try migrationRecords()
        try MigrationChainValidator.validatePersisted(
            records,
            against: migrations,
            requiresCompleteChain: requiresCompleteChain
        )
        return records
    }

    private func bind(_ params: [Any?], to stmt: OpaquePointer?) {
        for (i, p) in params.enumerated() {
            let idx = Int32(i + 1)
            guard let value = p, !(value is NSNull) else {
                sqlite3_bind_null(stmt, idx)
                continue
            }
            switch value {
            case let s as String:
                sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            case let i as Int:
                sqlite3_bind_int64(stmt, idx, sqlite3_int64(i))
            case let i as Int64:
                sqlite3_bind_int64(stmt, idx, sqlite3_int64(i))
            case let d as Double:
                sqlite3_bind_double(stmt, idx, d)
            case let b as Bool:
                sqlite3_bind_int(stmt, idx, b ? 1 : 0)
            default:
                let s = String(describing: value)
                sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            }
        }
    }

    private func executionError(resultCode: Int32, operation: SQLiteOperation) -> SQLiteDatabaseError {
        let extended = db.map(sqlite3_extended_errcode) ?? resultCode
        return .execution(SQLiteExecutionError(primaryCode: resultCode & 0xFF, extendedCode: extended, operation: operation))
    }

    private func operation(for sql: String) -> SQLiteOperation {
        let verb = sql.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if verb.hasPrefix("BEGIN") || verb.hasPrefix("COMMIT") || verb.hasPrefix("ROLLBACK") { return .transaction }
        if verb.hasPrefix("SELECT") || verb.hasPrefix("PRAGMA") { return .query }
        return .statement
    }

    private func iso8601Now() -> String {
        let f = ISO8601DateFormatter()
        return f.string(from: Date())
    }

    private func tableExists(_ name: String) throws -> Bool {
        try querySingleInt(
            sql: "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = '\(name)';"
        ) == 1
    }

    private func migrationRecords() throws -> [PersistedMigrationRecord] {
        do {
            return try query(sql: "SELECT version, name, checksum, applied_at FROM schema_migrations ORDER BY id;") { row in
                PersistedMigrationRecord(
                    version: row.int64(at: 0).map(Int.init),
                    name: row.string(at: 1),
                    checksum: row.string(at: 2),
                    appliedAt: row.string(at: 3)
                )
            }
        } catch let error as MigrationIntegrityError {
            throw error
        } catch {
            throw MigrationIntegrityError.persistedRecordIncomplete(nil)
        }
    }
}
