// Database/SQLiteRepositoryProvider.swift
// SQLite-backed repository provider for LedgerForge (Sprint 10 Phase 2B)

import Foundation
import SQLite3

/// SQLite-backed provider that runs migrations and exposes repository implementations.
public final class SQLiteRepositoryProvider {
    public let database: SQLiteDatabase
    public let transactionRepo: TransactionRepository
    public let accountRepo: AccountRepository
    public let importSessionRepo: ImportSessionRepository

    public init(path: String? = nil) throws {
        let dbPath = path ?? Self.defaultDBPath()
        self.database = SQLiteDatabase(path: dbPath)
        try database.open()
        try database.runMigrations(allMigrations)

        self.transactionRepo = SQLiteTransactionRepo(db: database)
        self.accountRepo = SQLiteAccountRepo(db: database)
        self.importSessionRepo = SQLiteImportSessionRepo(db: database)
    }

    public static func defaultDBPath() -> String {
        let fm = FileManager.default
        let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = appSupport?.appendingPathComponent("LedgerForge")
        if let folder = folder {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder.appendingPathComponent("ledgerforge.sqlite").path
        }
        return "ledgerforge.sqlite"
    }
}

// MARK: - Repo implementations (minimal for Phase 2B)
fileprivate final class SQLiteAccountRepo: AccountRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func upsertAccount(_ account: [String : Any]) throws -> String {
        let id = account["id"] as? String ?? UUID().uuidString
        let workspaceId = account["workspace_id"] as? String ?? "default"
        let name = (account["name"] as? String) ?? "Account"
        let institutionId = account["institution_id"] as? String ?? ""
        let nativeCurrency = (account["native_currency"] as? String) ?? "INR"
        let now = ISO8601DateFormatter().string(from: Date())
        let sql = "INSERT OR REPLACE INTO accounts (id, workspace_id, name, institution_id, account_type, native_currency, description, created_at, closed_at, created_from_import_session_id) VALUES ('\(escape(id))','\(escape(workspaceId))','\(escape(name))','\(escape(institutionId))','\(escape((account["account_type"] as? String) ?? ""))','\(escape(nativeCurrency))','\(escape((account["description"] as? String) ?? ""))','\(now)',NULL,NULL);"
        try db.execute(sql: sql)
        return id
    }
}

fileprivate final class SQLiteImportSessionRepo: ImportSessionRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func createImportSession(_ payload: [String : Any]) throws -> String {
        let id = payload["id"] as? String ?? UUID().uuidString
        let workspaceId = payload["workspace_id"] as? String ?? "default"
        let startedAt = (payload["started_at"] as? String) ?? ISO8601DateFormatter().string(from: Date())
        let status = (payload["validation_status"] as? String) ?? "pending"
        let sql = "INSERT INTO import_sessions (id, workspace_id, user_visible_name, started_at, validation_status, created_at) VALUES ('\(escape(id))','\(escape(workspaceId))','\(escape((payload["user_visible_name"] as? String) ?? ""))','\(escape(startedAt))','\(escape(status))','\(escape(startedAt))');"
        try db.execute(sql: sql)
        return id
    }

    func updateImportSession(_ id: String, updates: [String : Any]) throws {
        var sets = [String]()
        if let status = updates["validation_status"] as? String { sets.append("validation_status='\(escape(status))'") }
        if let completed = updates["completed_at"] as? String { sets.append("completed_at='\(escape(completed))'") }
        if sets.isEmpty { return }
        let sql = "UPDATE import_sessions SET \(sets.joined(separator: ",")) , updated_at='\(ISO8601DateFormatter().string(from: Date()))' WHERE id='\(escape(id))';"
        try db.execute(sql: sql)
    }
}

fileprivate final class SQLiteTransactionRepo: TransactionRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [Any]) throws {
        // Phase 2B: do NOT implement import persistence. This is a no-op placeholder
        // The repository exists and migrations are applied; transaction persistence
        // will be implemented in Phase 2C.
    }
}

// MARK: - Utilities
fileprivate func escape(_ s: String) -> String {
    return s.replacingOccurrences(of: "'", with: "''")
}
