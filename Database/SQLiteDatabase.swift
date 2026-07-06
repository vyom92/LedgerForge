// Database/SQLiteDatabase.swift
// Lightweight SQLite helper and migration runner for LedgerForge

import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum SQLiteDatabaseError: Error, LocalizedError {
    case databaseNotOpen
    case prepareFailed(sql: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .databaseNotOpen:
            return "SQLite database is not open."
        case .prepareFailed(let sql, let message):
            return "Failed to prepare SQLite statement: \(message). SQL: \(sql)"
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
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteDatabaseError.prepareFailed(sql: sql, message: msg)
        }

        bind(params, to: stmt)

        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE && rc != SQLITE_ROW {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    public func query<T>(sql: String, params: [Any?] = [], map: (SQLiteRow) throws -> T) throws -> [T] {
        guard let db = db else { throw SQLiteDatabaseError.databaseNotOpen }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteDatabaseError.prepareFailed(sql: sql, message: msg)
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
                let msg = String(cString: sqlite3_errmsg(db))
                throw NSError(domain: "SQLite", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: msg])
            }
        }
    }

    public func runMigrations(_ migrations: [Migration]) throws {
        try open()
        // Ensure schema_migrations exists
        try execute(sql: "CREATE TABLE IF NOT EXISTS schema_migrations (id INTEGER PRIMARY KEY AUTOINCREMENT, version INTEGER NOT NULL, name TEXT, applied_at DATETIME NOT NULL, checksum TEXT);")

        // Find current max version
        let currentVersion = try querySingleInt(sql: "SELECT COALESCE(MAX(version),0) FROM schema_migrations;")

        for migration in migrations.sorted(by: { $0.version < $1.version }) {
            if migration.version <= currentVersion { continue }
            try beginTransaction()
            do {
                try execute(sql: migration.sql)
                let checksum = sha256(migration.sql)
                let now = iso8601Now()
                let insert = "INSERT INTO schema_migrations(version,name,applied_at,checksum) VALUES(\(migration.version),'\(escape(migration.name))','\(now)','\(checksum)');"
                try execute(sql: insert)
                try commit()
            } catch {
                try rollback()
                throw error
            }
        }
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
            let msg = String(cString: sqlite3_errmsg(db))
            throw SQLiteDatabaseError.prepareFailed(sql: sql, message: msg)
        }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        }
        return 0
    }

    public func queryInt(_ sql: String) throws -> Int {
        return try querySingleInt(sql: sql)
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

    private func iso8601Now() -> String {
        let f = ISO8601DateFormatter()
        return f.string(from: Date())
    }

    private func sha256(_ s: String) -> String {
        guard let data = s.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func escape(_ s: String) -> String {
        return s.replacingOccurrences(of: "'", with: "''")
    }
}

// Import CommonCrypto SHA256 symbol
import CommonCrypto
