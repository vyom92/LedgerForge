import Foundation
import Testing
@testable import LedgerForge

struct DocumentFingerprintMigrationTests {
    @Test func v8RowsMigrateWithoutRewritingHistory() throws {
        let setup = try makeV8FingerprintDatabase(name: "preservation")
        defer { setup.database.close(); try? FileManager.default.removeItem(at: setup.folder) }

        let trackedTables = ["accounts", "transactions", "import_sessions", "import_attempts", "documents"]
        let beforeCounts = try Dictionary(uniqueKeysWithValues: trackedTables.map {
            ($0, try setup.database.queryInt("SELECT COUNT(*) FROM \($0);"))
        })
        let beforeFingerprint = try v8FingerprintRows(setup.database)
        let beforeDocumentHash = try setup.database.query(sql: "SELECT sha256 FROM documents WHERE id = 'document-v8';") { $0.string(at: 0) ?? "" }.first

        try setup.database.runMigrations(allMigrations)

        #expect(try setup.database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 9)
        let afterFingerprint = try v9FingerprintRows(setup.database)
        #expect(afterFingerprint.count == beforeFingerprint.count)
        for (before, after) in zip(beforeFingerprint, afterFingerprint) {
            #expect(after.id == before.id)
            #expect(after.documentID == before.documentID)
            #expect(after.sessionID == before.sessionID)
            #expect(after.algorithm == before.algorithm)
            #expect(after.digest == before.digest)
            #expect(after.authority)
        }
        #expect(try setup.database.query(sql: "SELECT sha256 FROM documents WHERE id = 'document-v8';") { $0.string(at: 0) ?? "" }.first == beforeDocumentHash)
        #expect(try setup.database.queryInt("SELECT COUNT(*) FROM document_fingerprints WHERE algorithm = '\(DocumentFingerprintDTO.sourceBytesSHA256Algorithm)';") == 0)
        for table in trackedTables {
            #expect(try setup.database.queryInt("SELECT COUNT(*) FROM \(table);") == beforeCounts[table])
        }
    }

    @Test func v9InstallsTheExactFingerprintIndexesAndConstraints() throws {
        let setup = try makeV8FingerprintDatabase(name: "constraints")
        defer { setup.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        try setup.database.runMigrations(allMigrations)

        let indexes = try setup.database.query(
            sql: "SELECT name, sql FROM sqlite_master WHERE type = 'index' AND tbl_name IN ('documents', 'document_fingerprints');"
        ) { ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "") }
        #expect(!indexes.contains { $0.0 == "idx_documents_sha256" })
        #expect(!indexes.contains { $0.0 == "idx_doc_fingerprint_unique" })
        #expect(indexes.contains { $0.0 == "idx_document_fingerprints_document_algorithm" && $0.1.contains("UNIQUE INDEX") })
        #expect(indexes.contains { $0.0 == "idx_document_fingerprints_one_authority" && $0.1.contains("WHERE is_duplicate_authority = 1") })
        #expect(indexes.contains { $0.0 == "idx_document_fingerprints_authority_lookup" && !$0.1.contains("UNIQUE INDEX") })

        try seedSecondDocument(setup.database)
        try setup.database.executePrepared(
            sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, created_at, is_duplicate_authority) VALUES (?,?,?,?,?,?,?);",
            params: ["source-first", "document-v8", "session-v8", DocumentFingerprintDTO.sourceBytesSHA256Algorithm, packet2SourceDigest, "2026-07-28T00:00:00Z", 0]
        )
        #expect(throws: (any Error).self) {
            try setup.database.executePrepared(
                sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, created_at, is_duplicate_authority) VALUES (?,?,?,?,?,?,?);",
                params: ["source-duplicate-algorithm", "document-v8", "session-v8", DocumentFingerprintDTO.sourceBytesSHA256Algorithm, String(repeating: "3", count: 64), "2026-07-28T00:00:00Z", 0]
            )
        }
        #expect(throws: (any Error).self) {
            try setup.database.executePrepared(
                sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, created_at, is_duplicate_authority) VALUES (?,?,?,?,?,?,?);",
                params: ["second-authority-seed", "document-second", "session-second", DocumentFingerprintDTO.rawTextSHA256Algorithm, String(repeating: "4", count: 64), "2026-07-28T00:00:00Z", 1]
            )
            try setup.database.executePrepared(
                sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, created_at, is_duplicate_authority) VALUES (?,?,?,?,?,?,?);",
                params: ["second-authority", "document-second", "session-second", DocumentFingerprintDTO.sourceBytesSHA256Algorithm, String(repeating: "5", count: 64), "2026-07-28T00:00:00Z", 1]
            )
        }
        try setup.database.executePrepared(
            sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, created_at, is_duplicate_authority) VALUES (?,?,?,?,?,?,?);",
            params: ["shared-secondary", "document-second", "session-second", DocumentFingerprintDTO.sourceBytesSHA256Algorithm, packet2SourceDigest, "2026-07-28T00:00:00Z", 0]
        )
        #expect(try setup.database.queryInt("SELECT COUNT(*) FROM document_fingerprints WHERE algorithm = '\(DocumentFingerprintDTO.sourceBytesSHA256Algorithm)' AND fingerprint = '\(packet2SourceDigest)' AND is_duplicate_authority = 0;") == 2)
    }

    @Test func v9PreflightRejectsAmbiguousV8FingerprintEvidence() throws {
        let setup = try makeV8FingerprintDatabase(name: "ambiguous")
        defer { setup.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        try setup.database.executePrepared(
            sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, created_at) VALUES (?,?,?,?,?,?);",
            params: ["ambiguous-source", "document-v8", "session-v8", DocumentFingerprintDTO.sourceBytesSHA256Algorithm, packet2SourceDigest, "2026-07-28T00:00:00Z"]
        )

        #expect(throws: MigrationPreflightError.failed(issueCode: "ambiguous-document-fingerprint-authority")) {
            try setup.database.runMigrations(allMigrations)
        }
        #expect(try setup.database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 8)
        let columns = try setup.database.query(sql: "PRAGMA table_info(document_fingerprints);") { $0.string(at: 1) ?? "" }
        #expect(!columns.contains("is_duplicate_authority"))
    }
}

private typealias MigrationFingerprintRow = (id: String, documentID: String, sessionID: String, algorithm: String, digest: String)

private func v8FingerprintRows(_ database: SQLiteDatabase) throws -> [MigrationFingerprintRow] {
    try database.query(
        sql: "SELECT id, document_id, import_session_id, algorithm, fingerprint FROM document_fingerprints ORDER BY id;"
    ) {
        ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "", $0.string(at: 2) ?? "", $0.string(at: 3) ?? "", $0.string(at: 4) ?? "")
    }
}

private func v9FingerprintRows(_ database: SQLiteDatabase) throws -> [(id: String, documentID: String, sessionID: String, algorithm: String, digest: String, authority: Bool)] {
    try database.query(
        sql: "SELECT id, document_id, import_session_id, algorithm, fingerprint, is_duplicate_authority FROM document_fingerprints ORDER BY id;"
    ) {
        ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "", $0.string(at: 2) ?? "", $0.string(at: 3) ?? "", $0.string(at: 4) ?? "", $0.bool(at: 5))
    }
}

private func makeV8FingerprintDatabase(name: String) throws -> (database: SQLiteDatabase, folder: URL) {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-Packet2-Migration-\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let database = SQLiteDatabase(path: folder.appendingPathComponent("migration.sqlite").path)
    try database.runMigrations(Array(allMigrations.prefix(8)))
    let now = "2026-07-28T00:00:00Z"
    try database.executePrepared(sql: "INSERT INTO workspaces (id, name, created_at) VALUES (?,?,?);", params: ["workspace-v8", "V8", now])
    try database.executePrepared(sql: "INSERT INTO accounts (id, workspace_id, name, native_currency, created_at) VALUES (?,?,?,?,?);", params: ["account-v8", "workspace-v8", "V8", "INR", now])
    try database.executePrepared(sql: "INSERT INTO import_sessions (id, workspace_id, started_at, completed_at, validation_status, created_at) VALUES (?,?,?,?,?,?);", params: ["session-v8", "workspace-v8", now, now, "passed", now])
    try database.executePrepared(sql: "INSERT INTO documents (id, workspace_id, import_session_id, filename, sha256, created_at) VALUES (?,?,?,?,?,?);", params: ["document-v8", "workspace-v8", "session-v8", "fixture.csv", packet2RawDigest, now])
    try database.executePrepared(sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, created_at) VALUES (?,?,?,?,?,?);", params: ["fingerprint-v8", "document-v8", "session-v8", DocumentFingerprintDTO.rawTextSHA256Algorithm, packet2RawDigest, now])
    try database.executePrepared(sql: "INSERT INTO transactions (id, workspace_id, account_id, import_session_id, document_id, posted_date, native_currency, amount_minor, amount_decimal, direction, is_reconciled, is_trusted, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?);", params: ["transaction-v8", "workspace-v8", "account-v8", "session-v8", "document-v8", "2026-07-28", "INR", 100, "1.00", "credit", 0, 1, now])
    try database.executePrepared(sql: "INSERT INTO import_attempts (id, workspace_id, created_at, outcome_code, coverage_code, account_decision_code, guidance_code, persistence_code, transaction_count, account_id, import_session_id, document_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?);", params: ["attempt-v8", "workspace-v8", now, "successful_import", "evaluated_supported_only", "resolved_or_created", "import_completed", "committed", 1, "account-v8", "session-v8", "document-v8"])
    return (database, folder)
}

private func seedSecondDocument(_ database: SQLiteDatabase) throws {
    let now = "2026-07-28T00:00:00Z"
    try database.executePrepared(sql: "INSERT INTO import_sessions (id, workspace_id, started_at, completed_at, validation_status, created_at) VALUES (?,?,?,?,?,?);", params: ["session-second", "workspace-v8", now, now, "passed", now])
    try database.executePrepared(sql: "INSERT INTO documents (id, workspace_id, import_session_id, filename, sha256, created_at) VALUES (?,?,?,?,?,?);", params: ["document-second", "workspace-v8", "session-second", "second.csv", packet2RawDigest, now])
}
