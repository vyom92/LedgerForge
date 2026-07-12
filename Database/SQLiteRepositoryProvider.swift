// Database/SQLiteRepositoryProvider.swift
// SQLite-backed repository provider for LedgerForge (Sprint 10 Phase 2B)

import Foundation
import SQLite3

/// SQLite-backed provider that runs migrations and exposes repository implementations.
public final class SQLiteRepositoryProvider {
    public let databasePath: String
    public let database: SQLiteDatabase
    public let workspaceRepo: WorkspaceRepository
    public let transactionRepo: TransactionRepository
    public let accountRepo: AccountRepository
    public let importSessionRepo: ImportSessionRepository

    public init(path: String? = nil) throws {
        let dbPath = path ?? Self.defaultDBPath()
        self.databasePath = dbPath
        self.database = SQLiteDatabase(path: dbPath)
        try database.open()
        try database.runMigrations(allMigrations)
        try database.execute(sql: "PRAGMA foreign_keys = ON;")

        self.workspaceRepo = SQLiteWorkspaceRepo(db: database)
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
fileprivate final class SQLiteWorkspaceRepo: WorkspaceRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func upsertWorkspace(_ workspace: WorkspaceDTO) throws -> String {
        let sql = "INSERT OR REPLACE INTO workspaces (id, name, created_at, updated_at) VALUES (?,?,?,?);"
        try db.executePrepared(sql: sql, params: [workspace.id, workspace.name, workspace.createdAtISO, workspace.updatedAtISO ?? NSNull()])
        return workspace.id
    }

    func workspace(id: String) throws -> WorkspaceDTO? {
        let sql = "SELECT id, name, created_at, updated_at FROM workspaces WHERE id = ?;"
        return try db.query(sql: sql, params: [id]) { row in
            WorkspaceDTO(
                id: row.string(at: 0) ?? "",
                name: row.string(at: 1) ?? "",
                createdAtISO: row.string(at: 2) ?? "",
                updatedAtISO: row.string(at: 3)
            )
        }.first
    }
}

fileprivate final class SQLiteAccountRepo: AccountRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func upsertAccount(_ account: AccountDTO) throws -> String {
        try ensureInstitutionExists(id: account.institutionId, createdAtISO: account.createdAtISO)

        let now = account.createdAtISO
        let sql = "INSERT OR REPLACE INTO accounts (id, workspace_id, name, institution_id, account_type, native_currency, description, created_at, closed_at, created_from_import_session_id) VALUES (?,?,?,?,?,?,?,?,?,?);"
        try db.executePrepared(sql: sql, params: [account.id, account.workspaceId, account.name, account.institutionId ?? NSNull(), account.accountType ?? NSNull(), account.nativeCurrency, account.description ?? NSNull(), now, NSNull(), NSNull()])
        return account.id
    }

    func account(id: String) throws -> AccountDTO? {
        let sql = "SELECT id, workspace_id, name, institution_id, account_type, native_currency, description, created_at FROM accounts WHERE id = ?;"
        return try db.query(sql: sql, params: [id]) { row in
            AccountDTO(
                id: row.string(at: 0) ?? "",
                workspaceId: row.string(at: 1) ?? "",
                name: row.string(at: 2) ?? "",
                institutionId: row.string(at: 3),
                accountType: row.string(at: 4),
                nativeCurrency: row.string(at: 5) ?? "",
                description: row.string(at: 6),
                createdAtISO: row.string(at: 7) ?? ""
            )
        }.first
    }

    func accounts(workspaceId: String) throws -> [AccountDTO] {
        let sql = "SELECT id, workspace_id, name, institution_id, account_type, native_currency, description, created_at FROM accounts WHERE workspace_id = ? ORDER BY name, id;"
        return try db.query(sql: sql, params: [workspaceId]) { row in
            AccountDTO(
                id: row.string(at: 0) ?? "",
                workspaceId: row.string(at: 1) ?? "",
                name: row.string(at: 2) ?? "",
                institutionId: row.string(at: 3),
                accountType: row.string(at: 4),
                nativeCurrency: row.string(at: 5) ?? "",
                description: row.string(at: 6),
                createdAtISO: row.string(at: 7) ?? ""
            )
        }
    }

    func attachIdentifier(_ identifier: AccountIdentifierDTO) throws -> String {
        try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            guard let account = try account(id: identifier.accountId) else {
                throw RepositoryError.relationshipViolation("Account \(identifier.accountId) does not exist for identifier \(identifier.id).")
            }
            guard account.workspaceId == identifier.workspaceId else {
                throw RepositoryError.relationshipViolation("Account \(identifier.accountId) belongs to workspace \(account.workspaceId), not \(identifier.workspaceId).")
            }

            let existing = try storedIdentifiers(
                workspaceId: identifier.workspaceId,
                scheme: identifier.scheme,
                identifier: identifier.identifier
            )

            if let conflict = existing.first(where: { $0.accountId != identifier.accountId }) {
                throw RepositoryError.conflictingAccountIdentifier(
                    workspaceId: identifier.workspaceId,
                    scheme: identifier.scheme,
                    identifier: identifier.identifier,
                    existingAccountId: conflict.accountId,
                    attemptedAccountId: identifier.accountId
                )
            }

            if let current = existing.sorted(by: { $0.id < $1.id }).first {
                try db.execute(sql: "COMMIT;")
                DeveloperConsole.shared.info(.database, "Existing account identifier reused", metadata: [
                    "scheme": identifier.scheme,
                    "identifier": FinancialIdentifier.redacted(identifier.identifier)
                ])
                return current.id
            }

            let insert = "INSERT INTO account_identifiers (id, account_id, scheme, identifier, provenance, created_at) VALUES (?,?,?,?,?,?);"
            try db.executePrepared(sql: insert, params: [
                identifier.id,
                identifier.accountId,
                identifier.scheme,
                identifier.identifier,
                Self.provenanceJSON(for: identifier),
                identifier.createdAtISO
            ])
            try db.execute(sql: "COMMIT;")
            DeveloperConsole.shared.info(.database, "Account identifier attached", metadata: [
                "scheme": identifier.scheme,
                "identifier": FinancialIdentifier.redacted(identifier.identifier)
            ])
            return identifier.id
        } catch {
            try? db.execute(sql: "ROLLBACK;")
            if case RepositoryError.conflictingAccountIdentifier(_, let scheme, let identifierValue, _, _) = error {
                DeveloperConsole.shared.warning(.database, "Conflicting account identifier rejected", metadata: [
                    "scheme": scheme,
                    "identifier": FinancialIdentifier.redacted(identifierValue)
                ])
            }
            throw error
        }
    }

    func identifiers(accountId: String, workspaceId: String) throws -> [AccountIdentifierDTO] {
        let sql = """
        SELECT ai.id, ai.account_id, a.workspace_id, ai.scheme, ai.identifier, ai.provenance, ai.created_at
        FROM account_identifiers ai
        INNER JOIN accounts a ON a.id = ai.account_id
        WHERE ai.account_id = ? AND a.workspace_id = ?
        ORDER BY ai.scheme, ai.identifier, ai.id;
        """
        return try db.query(sql: sql, params: [accountId, workspaceId]) { row in
            Self.identifierDTO(from: row)
        }
    }

    func accountIds(workspaceId: String, scheme: String, identifier: String) throws -> [String] {
        try storedIdentifiers(workspaceId: workspaceId, scheme: scheme, identifier: identifier)
            .map(\.accountId)
            .sorted()
    }

    private func storedIdentifiers(workspaceId: String, scheme: String, identifier: String) throws -> [AccountIdentifierDTO] {
        let sql = """
        SELECT ai.id, ai.account_id, a.workspace_id, ai.scheme, ai.identifier, ai.provenance, ai.created_at
        FROM account_identifiers ai
        INNER JOIN accounts a ON a.id = ai.account_id
        WHERE a.workspace_id = ? AND ai.scheme = ? AND ai.identifier = ?
        ORDER BY ai.account_id, ai.id;
        """
        return try db.query(sql: sql, params: [workspaceId, scheme, identifier]) { row in
            Self.identifierDTO(from: row)
        }
    }

    private static func identifierDTO(from row: SQLiteRow) -> AccountIdentifierDTO {
        let provenance = row.string(at: 5) ?? ""
        let metadata = provenanceMetadata(from: provenance)
        return AccountIdentifierDTO(
            id: row.string(at: 0) ?? "",
            accountId: row.string(at: 1) ?? "",
            workspaceId: row.string(at: 2) ?? "",
            scheme: row.string(at: 3) ?? "",
            identifier: row.string(at: 4) ?? "",
            strength: metadata["strength"] ?? "",
            verificationState: metadata["verificationState"] ?? "",
            provenance: metadata["provenance"] ?? provenance,
            createdAtISO: row.string(at: 6) ?? ""
        )
    }

    private static func provenanceJSON(for identifier: AccountIdentifierDTO) -> String {
        let payload = [
            "strength": identifier.strength,
            "verificationState": identifier.verificationState,
            "provenance": identifier.provenance
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return identifier.provenance
        }
        return json
    }

    private static func provenanceMetadata(from value: String) -> [String: String] {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return ["provenance": value]
        }
        return object
    }

    private func ensureInstitutionExists(id: String?, createdAtISO: String) throws {
        guard let id, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let code = id
            .lowercased()
            .map { character -> Character in
                if character.isLetter || character.isNumber {
                    return character
                }
                return "-"
            }

        let sql = "INSERT OR IGNORE INTO institutions (id, code, name, country, created_at) VALUES (?,?,?,?,?);"
        try db.executePrepared(sql: sql, params: [id, String(code), id, NSNull(), createdAtISO])
    }
}

fileprivate final class SQLiteImportSessionRepo: ImportSessionRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func createImportSession(_ payload: ImportSessionDTO) throws -> String {
        let sql = "INSERT INTO import_sessions (id, workspace_id, user_visible_name, started_at, validation_status, created_at, reader_version, parser_version, layout_version) VALUES (?,?,?,?,?,?,?,?,?);"
        try db.executePrepared(sql: sql, params: [payload.id, payload.workspaceId, payload.userVisibleName ?? NSNull(), payload.startedAtISO, payload.validationStatus, payload.startedAtISO, payload.readerVersion ?? NSNull(), payload.parserVersion ?? NSNull(), payload.layoutVersion ?? NSNull()])
        return payload.id
    }

    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws {
        var sets = [String]()
        var params: [Any?] = []
        if let status = updates.validationStatus { sets.append("validation_status = ?"); params.append(status) }
        if let completed = updates.completedAtISO { sets.append("completed_at = ?"); params.append(completed) }
        if sets.isEmpty { return }
        let updatedAt = ISO8601DateFormatter().string(from: Date())
        let sql = "UPDATE import_sessions SET \(sets.joined(separator: ",")), updated_at = ? WHERE id = ?;"
        params.append(updatedAt)
        params.append(id)
        try db.executePrepared(sql: sql, params: params)
    }

    func importSession(id: String) throws -> ImportSessionRecordDTO? {
        let sql = "SELECT id, workspace_id, user_visible_name, started_at, completed_at, validation_status, reader_version, parser_version, layout_version FROM import_sessions WHERE id = ?;"
        return try db.query(sql: sql, params: [id]) { row in
            ImportSessionRecordDTO(
                id: row.string(at: 0) ?? "",
                workspaceId: row.string(at: 1) ?? "",
                userVisibleName: row.string(at: 2),
                startedAtISO: row.string(at: 3) ?? "",
                completedAtISO: row.string(at: 4),
                validationStatus: row.string(at: 5) ?? "",
                readerVersion: row.string(at: 6),
                parserVersion: row.string(at: 7),
                layoutVersion: row.string(at: 8)
            )
        }.first
    }
}

fileprivate final class SQLiteTransactionRepo: TransactionRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [TransactionDTO]) throws {
        // Atomic replace of candidate transactions for an import_session_id.
        try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            if let importId = importSessionId {
                // Remove prior non-trusted transactions for this import_session
                let delRaw = "DELETE FROM transaction_raw_rows WHERE transaction_id IN (SELECT id FROM transactions WHERE import_session_id = ? AND is_trusted = 0);"
                try db.executePrepared(sql: delRaw, params: [importId])
                let delTx = "DELETE FROM transactions WHERE import_session_id = ? AND is_trusted = 0;"
                try db.executePrepared(sql: delTx, params: [importId])
            }

            let insertTx = "INSERT OR REPLACE INTO transactions (id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);"

            let insertRaw = "INSERT OR REPLACE INTO transaction_raw_rows (id, transaction_id, normalized_row_id, contribution_type, created_at) VALUES (?,?,?,?,?);"

            for tx in transactions {
                try db.executePrepared(sql: insertTx, params: [tx.id, tx.workspaceId, tx.accountId ?? NSNull(), tx.importSessionId ?? NSNull(), tx.documentId ?? NSNull(), tx.originalRowId ?? NSNull(), tx.postedDateISO, tx.valueDateISO ?? NSNull(), tx.description ?? NSNull(), tx.payee ?? NSNull(), tx.reference ?? NSNull(), tx.nativeCurrency, tx.amountMinor, tx.amountDecimal, tx.direction, tx.runningBalanceMinor ?? NSNull(), tx.isReconciled ? 1 : 0, tx.isTrusted ? 1 : 0, tx.trustedAtISO ?? NSNull(), tx.createdAtISO, tx.updatedAtISO ?? NSNull()])

                for raw in tx.rawRows {
                    try db.executePrepared(sql: insertRaw, params: [raw.id, tx.id, raw.normalizedRowId, raw.contributionType ?? NSNull(), tx.createdAtISO])
                }
            }

            try db.execute(sql: "COMMIT;")
        } catch {
            try? db.execute(sql: "ROLLBACK;")
            throw error
        }
    }

    func transactions(workspaceId: String, importSessionId: String?) throws -> [TransactionDTO] {
        var sql = "SELECT id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at FROM transactions WHERE workspace_id = ?"
        var params: [Any?] = [workspaceId]
        if let importSessionId {
            sql += " AND import_session_id = ?"
            params.append(importSessionId)
        }
        sql += " ORDER BY posted_date DESC, id DESC;"

        return try db.query(sql: sql, params: params) { row in
            let transactionId = row.string(at: 0) ?? ""
            let rawRows = try rawRows(for: transactionId)
            return TransactionDTO(
                id: transactionId,
                workspaceId: row.string(at: 1) ?? "",
                accountId: row.string(at: 2),
                importSessionId: row.string(at: 3),
                documentId: row.string(at: 4),
                originalRowId: row.string(at: 5),
                postedDateISO: row.string(at: 6) ?? "",
                valueDateISO: row.string(at: 7),
                description: row.string(at: 8),
                payee: row.string(at: 9),
                reference: row.string(at: 10),
                nativeCurrency: row.string(at: 11) ?? "",
                amountMinor: row.int64(at: 12) ?? 0,
                amountDecimal: row.string(at: 13) ?? "",
                direction: row.string(at: 14) ?? "",
                runningBalanceMinor: row.int64(at: 15),
                isReconciled: row.bool(at: 16),
                isTrusted: row.bool(at: 17),
                trustedAtISO: row.string(at: 18),
                createdAtISO: row.string(at: 19) ?? "",
                updatedAtISO: row.string(at: 20),
                rawRows: rawRows
            )
        }
    }

    func trustedTransactions(workspaceId: String) throws -> [TransactionDTO] {
        let sql = "SELECT id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at FROM transactions WHERE workspace_id = ? AND is_trusted = 1 ORDER BY posted_date DESC, id DESC;"
        return try db.query(sql: sql, params: [workspaceId]) { row in
            let transactionId = row.string(at: 0) ?? ""
            let rawRows = try rawRows(for: transactionId)
            return TransactionDTO(
                id: transactionId,
                workspaceId: row.string(at: 1) ?? "",
                accountId: row.string(at: 2),
                importSessionId: row.string(at: 3),
                documentId: row.string(at: 4),
                originalRowId: row.string(at: 5),
                postedDateISO: row.string(at: 6) ?? "",
                valueDateISO: row.string(at: 7),
                description: row.string(at: 8),
                payee: row.string(at: 9),
                reference: row.string(at: 10),
                nativeCurrency: row.string(at: 11) ?? "",
                amountMinor: row.int64(at: 12) ?? 0,
                amountDecimal: row.string(at: 13) ?? "",
                direction: row.string(at: 14) ?? "",
                runningBalanceMinor: row.int64(at: 15),
                isReconciled: row.bool(at: 16),
                isTrusted: row.bool(at: 17),
                trustedAtISO: row.string(at: 18),
                createdAtISO: row.string(at: 19) ?? "",
                updatedAtISO: row.string(at: 20),
                rawRows: rawRows
            )
        }
    }

    private func rawRows(for transactionId: String) throws -> [TransactionRawRowDTO] {
        let sql = "SELECT id, normalized_row_id, contribution_type FROM transaction_raw_rows WHERE transaction_id = ? ORDER BY id;"
        return try db.query(sql: sql, params: [transactionId]) { row in
            TransactionRawRowDTO(
                id: row.string(at: 0) ?? "",
                normalizedRowId: row.string(at: 1) ?? "",
                contributionType: row.string(at: 2)
            )
        }
    }
}

// MARK: - Utilities
fileprivate func escape(_ s: String) -> String {
    return s.replacingOccurrences(of: "'", with: "''")
}
