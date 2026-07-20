// Database/SQLiteDatabase.swift
// Lightweight SQLite helper and migration runner for LedgerForge

import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum SQLiteOperation: String, Equatable, Sendable { case open, transaction, statement, query, migration, backup, checkpoint, close }

public struct SQLiteExecutionError: Error, Equatable, Sendable, CustomStringConvertible {
    public let primaryCode: Int32
    public let extendedCode: Int32
    public let operation: SQLiteOperation
    public init(primaryCode: Int32, extendedCode: Int32, operation: SQLiteOperation) { self.primaryCode = primaryCode; self.extendedCode = extendedCode; self.operation = operation }
    public var isRetryableContention: Bool { primaryCode == SQLITE_BUSY || primaryCode == SQLITE_LOCKED }
    // SQLITE_CONSTRAINT_UNIQUE is a C macro that Swift does not import.
    public var isUniqueConstraint: Bool { primaryCode == SQLITE_CONSTRAINT && extendedCode == 2067 }
    public var description: String { "SQLite \(operation.rawValue) failed (\(primaryCode)/\(extendedCode))." }
}

public enum SQLiteDatabaseError: Error, LocalizedError {
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

public struct SQLiteRow {
    fileprivate let statement: OpaquePointer?

    public func string(at index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: text)
    }

    public func int64(at index: Int32) -> Int64? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return sqlite3_column_int64(statement, index)
    }

    public func bool(at index: Int32) -> Bool {
        return sqlite3_column_int(statement, index) != 0
    }
}

public final class SQLiteDatabase {
    private let path: String
    private var db: OpaquePointer?

    public init(path: String) {
        self.path = path
    }

    deinit {
        close()
    }

    public func open() throws {
        if db != nil { return }
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        // Configure recommended PRAGMAs for production-safe defaults
        // Enable write-ahead logging for concurrency
        try execute(sql: "PRAGMA journal_mode = WAL;")
        // Enable foreign keys enforcement
        try execute(sql: "PRAGMA foreign_keys = ON;")
        // Set busy timeout (ms)
        sqlite3_busy_timeout(db, 5000)
        // Use NORMAL synchronous for balanced durability/performance
        try execute(sql: "PRAGMA synchronous = NORMAL;")
    }

    public func close() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    public func createBackup(at destinationPath: String) throws {
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
        guard let db = db else { throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "DB not open"]) }
        var errMsg: UnsafeMutablePointer<Int8>? = nil
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let message = errMsg.flatMap { String(cString: $0) } ?? "unknown"
            sqlite3_free(errMsg)
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    // Execute a prepared statement with parameter bindings. Parameters are bound in order.
    public func executePrepared(sql: String, params: [Any?] = []) throws {
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
            try beginTransaction()
            do {
                for check in migration.preflightChecks {
                    guard try check.run(self) else {
                        throw MigrationPreflightError.failed(issueCode: check.issueCode)
                    }
                }
                try execute(sql: migration.sql)
                let now = iso8601Now()
                try executePrepared(
                    sql: "INSERT INTO schema_migrations(version, name, applied_at, checksum) VALUES(?, ?, ?, ?);",
                    params: [migration.version, migration.name, now, migration.checksum]
                )
                try commit()
            } catch {
                try? rollback()
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
        return try querySingleInt(sql: sql)
    }

    func validatedMigrationHistory(
        against migrations: [Migration],
        requiresCompleteChain: Bool
    ) throws -> [PersistedMigrationRecord] {
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
