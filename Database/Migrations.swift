// Database/Migrations.swift
// Migration definitions for LedgerForge SQLite schema (Sprint 10 Phase 2B)

import CommonCrypto
import Foundation

public struct Migration {
    public let version: Int
    public let name: String
    public let sql: String
    let preflightChecks: [MigrationPreflightCheck]

    public init(version: Int, name: String, sql: String) {
        self.init(version: version, name: name, sql: sql, preflightChecks: [])
    }

    init(version: Int, name: String, sql: String, preflightChecks: [MigrationPreflightCheck]) {
        self.version = version
        self.name = name
        self.sql = sql
        self.preflightChecks = preflightChecks
    }
}

struct MigrationPreflightCheck {
    let issueCode: String
    let run: (SQLiteDatabase) throws -> Bool
}

public let migrationV1 = Migration(version: 1, name: "initial_schema_v1", sql: """
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS schema_migrations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  version INTEGER NOT NULL,
  name TEXT,
  applied_at DATETIME NOT NULL,
  checksum TEXT
);

-- workspaces
CREATE TABLE IF NOT EXISTS workspaces (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME
);

-- institutions
CREATE TABLE IF NOT EXISTS institutions (
  id TEXT PRIMARY KEY,
  code TEXT UNIQUE,
  name TEXT,
  country TEXT,
  created_at DATETIME
);

-- currencies
CREATE TABLE IF NOT EXISTS currencies (
  code TEXT PRIMARY KEY,
  numeric_code INTEGER,
  name TEXT,
  minor_unit INTEGER NOT NULL,
  decimal_places INTEGER NOT NULL
);

-- documents
CREATE TABLE IF NOT EXISTS documents (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  import_session_id TEXT,
  filename TEXT NOT NULL,
  mime_type TEXT,
  size_bytes INTEGER,
  sha256 TEXT NOT NULL,
  storage_path TEXT,
  extracted_text_snippet TEXT,
  page_count INTEGER,
  created_at DATETIME NOT NULL,
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_documents_sha256 ON documents(sha256);

-- import_sessions
CREATE TABLE IF NOT EXISTS import_sessions (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  user_visible_name TEXT,
  started_at DATETIME NOT NULL,
  completed_at DATETIME,
  importer_version TEXT,
  source_filename TEXT,
  num_documents INTEGER,
  normalized_rows_count INTEGER,
  parsed_transactions_count INTEGER,
  validation_status TEXT NOT NULL,
  validation_summary TEXT,
  validation_score REAL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME,
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
);

-- normalized_documents
CREATE TABLE IF NOT EXISTS normalized_documents (
  id TEXT PRIMARY KEY,
  import_session_id TEXT NOT NULL,
  document_id TEXT,
  normalized_json TEXT NOT NULL,
  schema_version TEXT,
  primary_language TEXT,
  created_at DATETIME,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE CASCADE,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE SET NULL
);

-- normalized_rows
CREATE TABLE IF NOT EXISTS normalized_rows (
  id TEXT PRIMARY KEY,
  normalized_document_id TEXT NOT NULL,
  row_index INTEGER NOT NULL,
  row_original TEXT NOT NULL,
  extracted_text TEXT,
  created_at DATETIME,
  FOREIGN KEY(normalized_document_id) REFERENCES normalized_documents(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_normalized_rows_doc_idx ON normalized_rows(normalized_document_id, row_index);

-- document_fingerprints
CREATE TABLE IF NOT EXISTS document_fingerprints (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  import_session_id TEXT,
  algorithm TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  fingerprint_data TEXT,
  created_at DATETIME NOT NULL,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_doc_fingerprint_unique ON document_fingerprints(algorithm, fingerprint);

-- accounts
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  name TEXT NOT NULL,
  institution_id TEXT,
  account_type TEXT,
  native_currency TEXT NOT NULL,
  description TEXT,
  created_at DATETIME NOT NULL,
  closed_at DATETIME,
  created_from_import_session_id TEXT,
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
  FOREIGN KEY(institution_id) REFERENCES institutions(id) ON DELETE SET NULL
);

-- account_identifiers
CREATE TABLE IF NOT EXISTS account_identifiers (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  scheme TEXT NOT NULL,
  identifier TEXT NOT NULL,
  provenance TEXT,
  created_at DATETIME NOT NULL,
  FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_account_identifiers_scheme ON account_identifiers(scheme, identifier);

-- transactions
CREATE TABLE IF NOT EXISTS transactions (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  account_id TEXT,
  import_session_id TEXT,
  document_id TEXT,
  original_row_id TEXT,
  posted_date DATE NOT NULL,
  value_date DATE,
  description TEXT,
  payee TEXT,
  reference TEXT,
  native_currency TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  amount_decimal TEXT NOT NULL,
  direction TEXT NOT NULL,
  running_balance_minor INTEGER,
  is_reconciled INTEGER DEFAULT 0,
  is_trusted INTEGER DEFAULT 0,
  trusted_at DATETIME,
  created_at DATETIME NOT NULL,
  updated_at DATETIME,
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
  FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_transactions_account_date ON transactions(workspace_id, account_id, posted_date);
CREATE INDEX IF NOT EXISTS idx_transactions_import ON transactions(workspace_id, import_session_id);

-- transaction_raw_rows
CREATE TABLE IF NOT EXISTS transaction_raw_rows (
  id TEXT PRIMARY KEY,
  transaction_id TEXT NOT NULL,
  normalized_row_id TEXT NOT NULL,
  contribution_type TEXT,
  created_at DATETIME,
  FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
  FOREIGN KEY(normalized_row_id) REFERENCES normalized_rows(id) ON DELETE CASCADE
);

-- validation_issues
CREATE TABLE IF NOT EXISTS validation_issues (
  id TEXT PRIMARY KEY,
  import_session_id TEXT NOT NULL,
  normalized_row_id TEXT,
  transaction_candidate_id TEXT,
  severity TEXT NOT NULL,
  code TEXT NOT NULL,
  message TEXT NOT NULL,
  field TEXT,
  created_at DATETIME NOT NULL,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_validation_issues_import ON validation_issues(import_session_id, severity);

-- exchange_rates
CREATE TABLE IF NOT EXISTS exchange_rates (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  base_currency TEXT NOT NULL,
  quote_currency TEXT NOT NULL,
  rate_decimal TEXT NOT NULL,
  rate_factor_numerator INTEGER,
  rate_factor_denominator INTEGER,
  valid_at DATETIME NOT NULL,
  source TEXT,
  import_session_id TEXT,
  created_at DATETIME NOT NULL,
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_exchange_rates_lookup ON exchange_rates(workspace_id, base_currency, quote_currency, valid_at);

-- account_balance_snapshots
CREATE TABLE IF NOT EXISTS account_balance_snapshots (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  snapshot_date DATE NOT NULL,
  balance_minor INTEGER NOT NULL,
  currency_code TEXT NOT NULL,
  source_import_session_id TEXT,
  created_at DATETIME NOT NULL,
  FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_account_balance_snapshot ON account_balance_snapshots(account_id, snapshot_date);

-- fts_transactions: implemented as a simple table here; real FTS5 virtual table will be created in provider if available
CREATE TABLE IF NOT EXISTS fts_transactions (
  transaction_id TEXT,
  description TEXT,
  payee TEXT,
  reference TEXT
);

-- attachments
CREATE TABLE IF NOT EXISTS attachments (
  id TEXT PRIMARY KEY,
  document_id TEXT,
  type TEXT,
  blob BLOB,
  created_at DATETIME,
  FOREIGN KEY(document_id) REFERENCES documents(id)
);

""")

public let migrationV2 = Migration(version: 2, name: "import_session_version_columns", sql: """
ALTER TABLE import_sessions ADD COLUMN reader_version TEXT;
ALTER TABLE import_sessions ADD COLUMN parser_version TEXT;
ALTER TABLE import_sessions ADD COLUMN layout_version TEXT;
""")

public let migrationV3 = Migration(version: 3, name: "transaction_event_identities", sql: """
CREATE TABLE transaction_event_identities (
  id TEXT PRIMARY KEY,
  transaction_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  import_session_id TEXT NOT NULL,
  algorithm TEXT NOT NULL,
  digest TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  UNIQUE(algorithm, digest),
  UNIQUE(transaction_id, algorithm),
  FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT,
  FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT
);
CREATE INDEX idx_transaction_event_identities_account ON transaction_event_identities(account_id, import_session_id);
""")

public let migrationV4 = Migration(version: 4, name: "import_attempt_history", sql: """
CREATE TABLE import_attempts (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  outcome_code TEXT NOT NULL,
  coverage_code TEXT NOT NULL,
  account_decision_code TEXT NOT NULL,
  guidance_code TEXT NOT NULL,
  persistence_code TEXT NOT NULL,
  transaction_count INTEGER NOT NULL,
  account_id TEXT,
  import_session_id TEXT,
  document_id TEXT,
  related_import_session_id TEXT,
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
  FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE SET NULL,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE SET NULL,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE SET NULL,
  FOREIGN KEY(related_import_session_id) REFERENCES import_sessions(id) ON DELETE SET NULL
);
CREATE INDEX idx_import_attempts_workspace_created ON import_attempts(workspace_id, created_at DESC, id DESC);

INSERT INTO import_attempts (
  id, workspace_id, created_at, outcome_code, coverage_code, account_decision_code,
  guidance_code, persistence_code, transaction_count, account_id, import_session_id, document_id
)
SELECT
  'backfill-attempt-' || s.id, s.workspace_id, COALESCE(s.completed_at, s.started_at),
  'successful_import', 'evaluated_supported_only', 'resolved_or_created',
  'import_completed', 'committed',
  (SELECT COUNT(*) FROM transactions t WHERE t.import_session_id = s.id),
  (SELECT t.account_id FROM transactions t WHERE t.import_session_id = s.id AND t.account_id IS NOT NULL ORDER BY t.id LIMIT 1),
  s.id,
  (SELECT d.id FROM documents d WHERE d.import_session_id = s.id ORDER BY d.id LIMIT 1)
FROM import_sessions s
WHERE s.validation_status = 'passed' AND s.completed_at IS NOT NULL;
""")

/// The first trusted statement-date and source-provenance schema. Existing
/// financial graphs are deliberately rejected by the pre-production audit;
/// no historical date, row order, or provenance is guessed or rewritten.
public let migrationV6 = Migration(
    version: 6,
    name: "trusted_statement_dates_and_source_provenance",
    sql: """
ALTER TABLE transactions ADD COLUMN financial_date_role TEXT NOT NULL DEFAULT 'transaction_date';
ALTER TABLE transactions ADD COLUMN statement_timezone_evidence TEXT NOT NULL DEFAULT 'unknown';
ALTER TABLE normalized_documents ADD COLUMN profile_id TEXT;
ALTER TABLE normalized_documents ADD COLUMN profile_version TEXT;
ALTER TABLE normalized_rows ADD COLUMN record_digest TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_normalized_rows_document_ordinal ON normalized_rows(normalized_document_id, row_index);
CREATE UNIQUE INDEX IF NOT EXISTS idx_transaction_raw_rows_transaction_row ON transaction_raw_rows(transaction_id, normalized_row_id);
""",
    preflightChecks: [
        MigrationPreflightCheck(issueCode: "preproduction-reset-required") { database in
            try database.queryInt("SELECT COUNT(*) FROM transactions;") == 0
        },
        MigrationPreflightCheck(issueCode: "preproduction-normalized-reset-required") { database in
            try database.queryInt("SELECT COUNT(*) FROM normalized_documents;") == 0 &&
            database.queryInt("SELECT COUNT(*) FROM normalized_rows;") == 0 &&
            database.queryInt("SELECT COUNT(*) FROM transaction_raw_rows;") == 0
        }
    ]
)

public let migrationV7 = Migration(version: 7, name: "reviewed_partial_overlap_import", sql: """
ALTER TABLE import_attempts ADD COLUMN source_row_count INTEGER;
ALTER TABLE import_attempts ADD COLUMN imported_transaction_count INTEGER;
ALTER TABLE import_attempts ADD COLUMN recognized_existing_row_count INTEGER;
ALTER TABLE import_attempts ADD COLUMN blocked_row_count INTEGER;

CREATE TABLE partial_import_summaries (
  import_session_id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL UNIQUE,
  plan_digest_algorithm TEXT NOT NULL,
  plan_digest TEXT NOT NULL,
  statement_start_date DATE NOT NULL,
  statement_end_date DATE NOT NULL,
  native_currency TEXT NOT NULL,
  source_row_count INTEGER NOT NULL CHECK(source_row_count > 0),
  imported_transaction_count INTEGER NOT NULL CHECK(imported_transaction_count > 0),
  recognized_existing_row_count INTEGER NOT NULL CHECK(recognized_existing_row_count > 0),
  blocked_row_count INTEGER NOT NULL CHECK(blocked_row_count = 0),
  opening_balance_minor INTEGER NOT NULL,
  opening_balance_decimal TEXT NOT NULL,
  closing_balance_minor INTEGER NOT NULL,
  closing_balance_decimal TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  CHECK(imported_transaction_count + recognized_existing_row_count = source_row_count),
  CHECK(statement_start_date <= statement_end_date),
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT
);

CREATE TABLE incoming_row_dispositions (
  id TEXT PRIMARY KEY,
  import_session_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  normalized_row_id TEXT NOT NULL UNIQUE,
  source_ordinal INTEGER NOT NULL CHECK(source_ordinal > 0),
  disposition_code TEXT NOT NULL CHECK(disposition_code IN ('imported_unique', 'recognized_existing')),
  transaction_id TEXT NOT NULL,
  transaction_event_identity_id TEXT NOT NULL,
  statement_date DATE NOT NULL,
  financial_date_role TEXT NOT NULL,
  statement_timezone_evidence TEXT NOT NULL,
  native_currency TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  amount_decimal TEXT NOT NULL,
  direction TEXT NOT NULL CHECK(direction IN ('debit', 'credit')),
  running_balance_minor INTEGER NOT NULL,
  created_at DATETIME NOT NULL,
  UNIQUE(document_id, source_ordinal),
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(normalized_row_id) REFERENCES normalized_rows(id) ON DELETE RESTRICT,
  FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT,
  FOREIGN KEY(transaction_event_identity_id) REFERENCES transaction_event_identities(id) ON DELETE RESTRICT
);

CREATE TRIGGER validate_incoming_row_disposition
BEFORE INSERT ON incoming_row_dispositions
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1
    FROM normalized_rows nr
    JOIN normalized_documents nd ON nd.id = nr.normalized_document_id
    WHERE nr.id = NEW.normalized_row_id
      AND nr.row_index = NEW.source_ordinal
      AND nd.import_session_id = NEW.import_session_id
      AND nd.document_id = NEW.document_id
  ) THEN RAISE(ABORT, 'partial disposition source relationship invalid') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM transaction_raw_rows trr
    WHERE trr.transaction_id = NEW.transaction_id
      AND trr.normalized_row_id = NEW.normalized_row_id
  ) THEN RAISE(ABORT, 'partial disposition transaction source relationship missing') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM transaction_event_identities tei
    WHERE tei.id = NEW.transaction_event_identity_id
      AND tei.transaction_id = NEW.transaction_id
  ) THEN RAISE(ABORT, 'partial disposition event relationship invalid') END;
END;

CREATE TRIGGER validate_partial_import_summary
BEFORE INSERT ON partial_import_summaries
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM documents d
    WHERE d.id = NEW.document_id
      AND d.import_session_id = NEW.import_session_id
  ) THEN RAISE(ABORT, 'partial summary document relationship invalid') END;
  SELECT CASE WHEN (
    SELECT COUNT(*)
    FROM normalized_documents nd
    JOIN normalized_rows nr ON nr.normalized_document_id = nd.id
    WHERE nd.import_session_id = NEW.import_session_id
      AND nd.document_id = NEW.document_id
  ) != NEW.source_row_count
  THEN RAISE(ABORT, 'partial summary source count invalid') END;
  SELECT CASE WHEN (
    SELECT COUNT(*) FROM incoming_row_dispositions d
    WHERE d.import_session_id = NEW.import_session_id
      AND d.document_id = NEW.document_id
  ) != NEW.source_row_count
  THEN RAISE(ABORT, 'partial summary disposition count invalid') END;
  SELECT CASE WHEN (
    SELECT COUNT(*) FROM incoming_row_dispositions d
    WHERE d.import_session_id = NEW.import_session_id
      AND d.document_id = NEW.document_id
      AND d.disposition_code = 'imported_unique'
  ) != NEW.imported_transaction_count
  THEN RAISE(ABORT, 'partial summary imported count invalid') END;
  SELECT CASE WHEN (
    SELECT COUNT(*) FROM incoming_row_dispositions d
    WHERE d.import_session_id = NEW.import_session_id
      AND d.document_id = NEW.document_id
      AND d.disposition_code = 'recognized_existing'
  ) != NEW.recognized_existing_row_count
  THEN RAISE(ABORT, 'partial summary recognized count invalid') END;
END;
""")

public let migrationV8 = Migration(version: 8, name: "durable_transaction_categories", sql: """
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  name TEXT NOT NULL,
  normalized_name TEXT NOT NULL,
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK(is_archived IN (0, 1)),
  created_at DATETIME NOT NULL,
  updated_at DATETIME,
  UNIQUE(workspace_id, normalized_name),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE
);
CREATE INDEX idx_categories_workspace_archived_name
  ON categories(workspace_id, is_archived, normalized_name, id);

CREATE TABLE transaction_category_assignments (
  workspace_id TEXT NOT NULL,
  transaction_id TEXT PRIMARY KEY,
  category_id TEXT NOT NULL,
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE CASCADE,
  FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT,
  FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE RESTRICT
);
CREATE INDEX idx_transaction_category_assignments_category
  ON transaction_category_assignments(workspace_id, category_id, transaction_id);

CREATE TRIGGER validate_transaction_category_assignment_insert
BEFORE INSERT ON transaction_category_assignments
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM transactions t
    WHERE t.id = NEW.transaction_id
      AND t.workspace_id = NEW.workspace_id
      AND t.is_trusted = 1
  ) THEN RAISE(ABORT, 'category assignment transaction invalid') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM categories c
    WHERE c.id = NEW.category_id
      AND c.workspace_id = NEW.workspace_id
      AND c.is_archived = 0
  ) THEN RAISE(ABORT, 'category assignment category invalid') END;
END;

CREATE TRIGGER validate_transaction_category_assignment_update
BEFORE UPDATE ON transaction_category_assignments
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM transactions t
    WHERE t.id = NEW.transaction_id
      AND t.workspace_id = NEW.workspace_id
      AND t.is_trusted = 1
  ) THEN RAISE(ABORT, 'category assignment transaction invalid') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM categories c
    WHERE c.id = NEW.category_id
      AND c.workspace_id = NEW.workspace_id
      AND c.is_archived = 0
  ) THEN RAISE(ABORT, 'category assignment category invalid') END;
END;
""")

public let migrationV9 = Migration(
    version: 9,
    name: "versioned_document_fingerprint_authority",
    sql: """
ALTER TABLE document_fingerprints
  ADD COLUMN is_duplicate_authority INTEGER NOT NULL DEFAULT 0
  CHECK(is_duplicate_authority IN (0, 1));

UPDATE document_fingerprints
SET is_duplicate_authority = 1;

DROP INDEX idx_documents_sha256;
DROP INDEX idx_doc_fingerprint_unique;

CREATE UNIQUE INDEX idx_document_fingerprints_document_algorithm
  ON document_fingerprints(document_id, algorithm);

CREATE UNIQUE INDEX idx_document_fingerprints_one_authority
  ON document_fingerprints(document_id)
  WHERE is_duplicate_authority = 1;

CREATE INDEX idx_document_fingerprints_authority_lookup
  ON document_fingerprints(algorithm, fingerprint, is_duplicate_authority);
""",
    preflightChecks: [
        MigrationPreflightCheck(issueCode: "ambiguous-document-fingerprint-authority") { database in
            try database.queryInt("""
                SELECT COUNT(*)
                FROM (
                  SELECT document_id
                  FROM document_fingerprints
                  GROUP BY document_id
                  HAVING COUNT(*) > 1
                );
                """) == 0
        }
    ]
)

public let allMigrations: [Migration] = [migrationV1, migrationV2, migrationV3, migrationV4, migrationV5, migrationV6, migrationV7, migrationV8, migrationV9]

enum MigrationIntegrityError: Error, Equatable, LocalizedError {
    case emptyRegisteredChain
    case duplicateRegisteredVersion(Int)
    case registeredOrderInvalid
    case missingRegisteredVersion(Int)
    case duplicatePersistedVersion(Int)
    case missingPersistedVersion(Int)
    case persistedRecordIncomplete(Int?)
    case persistedNameMismatch(Int)
    case persistedChecksumMismatch(Int)
    case unsupportedFutureVersion(Int)

    var errorDescription: String? {
        switch self {
        case .emptyRegisteredChain: return "No application migrations are registered."
        case .duplicateRegisteredVersion: return "The registered migration chain contains a duplicate version."
        case .registeredOrderInvalid: return "The registered migration chain is not in deterministic order."
        case .missingRegisteredVersion: return "The registered migration chain is incomplete."
        case .duplicatePersistedVersion: return "The persisted migration history contains a duplicate version."
        case .missingPersistedVersion: return "The persisted migration history is incomplete."
        case .persistedRecordIncomplete: return "The persisted migration history contains an incomplete record."
        case .persistedNameMismatch: return "A persisted migration name does not match the application migration chain."
        case .persistedChecksumMismatch: return "A persisted migration checksum does not match the application migration chain."
        case .unsupportedFutureVersion: return "The database was created by an unsupported future migration chain."
        }
    }
}

struct PersistedMigrationRecord: Equatable {
    let version: Int?
    let name: String?
    let checksum: String?
    let appliedAt: String?
}

enum MigrationChainValidator {
    static func validateRegistered(_ migrations: [Migration]) throws {
        guard !migrations.isEmpty else {
            throw MigrationIntegrityError.emptyRegisteredChain
        }

        var seen = Set<Int>()
        for migration in migrations {
            guard seen.insert(migration.version).inserted else {
                throw MigrationIntegrityError.duplicateRegisteredVersion(migration.version)
            }
        }

        guard migrations.map(\.version) == migrations.map(\.version).sorted() else {
            throw MigrationIntegrityError.registeredOrderInvalid
        }

        for (offset, migration) in migrations.enumerated() {
            let expectedVersion = offset + 1
            guard migration.version == expectedVersion else {
                throw MigrationIntegrityError.missingRegisteredVersion(expectedVersion)
            }
        }
    }

    static func validatePersisted(
        _ records: [PersistedMigrationRecord],
        against migrations: [Migration],
        requiresCompleteChain: Bool
    ) throws {
        try validateRegistered(migrations)

        let completeRecords = try records.map { record -> (version: Int, name: String, checksum: String) in
            guard let version = record.version,
                  let name = record.name,
                  !name.isEmpty,
                  let checksum = record.checksum,
                  !checksum.isEmpty,
                  let appliedAt = record.appliedAt,
                  !appliedAt.isEmpty else {
                throw MigrationIntegrityError.persistedRecordIncomplete(record.version)
            }
            return (version, name, checksum)
        }

        var seen = Set<Int>()
        for record in completeRecords {
            guard seen.insert(record.version).inserted else {
                throw MigrationIntegrityError.duplicatePersistedVersion(record.version)
            }
        }

        let latestSupportedVersion = migrations[migrations.count - 1].version
        if let futureVersion = completeRecords.map(\.version).filter({ $0 > latestSupportedVersion }).min() {
            throw MigrationIntegrityError.unsupportedFutureVersion(futureVersion)
        }

        let sortedRecords = completeRecords.sorted { $0.version < $1.version }
        for (offset, record) in sortedRecords.enumerated() {
            let expectedVersion = offset + 1
            guard record.version == expectedVersion else {
                throw MigrationIntegrityError.missingPersistedVersion(expectedVersion)
            }

            let migration = migrations[offset]
            guard record.name == migration.name else {
                throw MigrationIntegrityError.persistedNameMismatch(record.version)
            }
            guard record.checksum == migration.checksum else {
                throw MigrationIntegrityError.persistedChecksumMismatch(record.version)
            }
        }

        if requiresCompleteChain, sortedRecords.count != migrations.count {
            throw MigrationIntegrityError.missingPersistedVersion(sortedRecords.count + 1)
        }
    }
}

extension Migration {
    var checksum: String {
        let source = preflightChecks.isEmpty ? sql : preflightChecks.map(\.issueCode).joined(separator: "\n") + "\n" + sql
        guard let data = source.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
