// Database/Migrations.swift
// Migration definitions for LedgerForge SQLite schema (Sprint 10 Phase 2B)

import CommonCrypto
import Foundation

public struct Migration {
    public let version: Int
    public let name: String
    public let sql: String
    let preflightChecks: [MigrationPreflightCheck]
    let requiresForeignKeysDisabled: Bool

    public init(version: Int, name: String, sql: String) {
        self.init(version: version, name: name, sql: sql, preflightChecks: [], requiresForeignKeysDisabled: false)
    }

    init(
        version: Int,
        name: String,
        sql: String,
        preflightChecks: [MigrationPreflightCheck],
        requiresForeignKeysDisabled: Bool = false
    ) {
        self.version = version
        self.name = name
        self.sql = sql
        self.preflightChecks = preflightChecks
        self.requiresForeignKeysDisabled = requiresForeignKeysDisabled
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

public let migrationV10 = Migration(
    version: 10,
    name: "exact_cross_format_statement_equivalence",
    sql: """
CREATE TABLE statement_financial_projections (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  document_id TEXT NOT NULL UNIQUE,
  import_session_id TEXT NOT NULL UNIQUE,
  algorithm TEXT NOT NULL,
  digest TEXT NOT NULL CHECK(length(digest) = 64 AND digest NOT GLOB '*[^0-9a-f]*'),
  institution_code TEXT NOT NULL,
  statement_family_code TEXT NOT NULL CHECK(length(statement_family_code) > 0),
  parser_profile_id TEXT NOT NULL CHECK(length(parser_profile_id) > 0),
  parser_profile_version TEXT NOT NULL CHECK(length(parser_profile_version) > 0),
  source_format_code TEXT NOT NULL CHECK(source_format_code IN ('pdf', 'xls')),
  statement_start_date DATE NOT NULL,
  statement_end_date DATE NOT NULL,
  native_currency TEXT NOT NULL,
  event_count INTEGER NOT NULL CHECK(event_count > 0),
  opening_balance_minor INTEGER NOT NULL,
  opening_balance_decimal TEXT NOT NULL CHECK(length(opening_balance_decimal) > 0),
  debit_count INTEGER NOT NULL CHECK(debit_count >= 0),
  credit_count INTEGER NOT NULL CHECK(credit_count >= 0),
  debit_total_minor INTEGER NOT NULL CHECK(debit_total_minor >= 0),
  debit_total_decimal TEXT NOT NULL CHECK(length(debit_total_decimal) > 0),
  credit_total_minor INTEGER NOT NULL CHECK(credit_total_minor >= 0),
  credit_total_decimal TEXT NOT NULL CHECK(length(credit_total_decimal) > 0),
  closing_balance_minor INTEGER NOT NULL,
  closing_balance_decimal TEXT NOT NULL CHECK(length(closing_balance_decimal) > 0),
  created_at DATETIME NOT NULL,
  CHECK(statement_start_date <= statement_end_date),
  CHECK(event_count = debit_count + credit_count),
  CHECK(algorithm = 'ledgerforge.statement-financial-projection.sha256.v1'),
  CHECK(institution_code = 'hdfc'),
  CHECK(statement_family_code = 'hdfc.bank-account'),
  CHECK(parser_profile_id = 'hdfc.bank-account.' || source_format_code),
  CHECK(parser_profile_version = '1'),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT
);
CREATE INDEX idx_statement_projection_group_lookup
  ON statement_financial_projections(workspace_id, account_id, statement_family_code, statement_start_date, statement_end_date, native_currency);

CREATE TABLE statement_financial_projection_events (
  id TEXT PRIMARY KEY,
  projection_id TEXT NOT NULL,
  event_ordinal INTEGER NOT NULL CHECK(event_ordinal > 0),
  statement_date DATE NOT NULL,
  value_date DATE NOT NULL,
  direction TEXT NOT NULL CHECK(direction IN ('debit', 'credit')),
  signed_amount_minor INTEGER NOT NULL,
  signed_amount_decimal TEXT NOT NULL CHECK(length(signed_amount_decimal) > 0),
  running_balance_minor INTEGER NOT NULL,
  running_balance_decimal TEXT NOT NULL CHECK(length(running_balance_decimal) > 0),
  reference TEXT,
  created_at DATETIME NOT NULL,
  UNIQUE(projection_id, event_ordinal),
  CHECK((direction = 'debit' AND signed_amount_minor < 0) OR
        (direction = 'credit' AND signed_amount_minor > 0)),
  FOREIGN KEY(projection_id) REFERENCES statement_financial_projections(id) ON DELETE RESTRICT
);

CREATE TABLE statement_equivalence_groups (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  institution_code TEXT NOT NULL,
  statement_family_code TEXT NOT NULL,
  statement_start_date DATE NOT NULL,
  statement_end_date DATE NOT NULL,
  native_currency TEXT NOT NULL,
  projection_algorithm TEXT NOT NULL,
  projection_digest TEXT NOT NULL CHECK(length(projection_digest) = 64 AND projection_digest NOT GLOB '*[^0-9a-f]*'),
  authoritative_projection_id TEXT NOT NULL UNIQUE,
  created_at DATETIME NOT NULL,
  CHECK(statement_start_date <= statement_end_date),
  UNIQUE(workspace_id, account_id, institution_code, statement_family_code, statement_start_date, statement_end_date, native_currency),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
  FOREIGN KEY(authoritative_projection_id) REFERENCES statement_financial_projections(id) ON DELETE RESTRICT
);

CREATE TABLE statement_equivalence_members (
  id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  projection_id TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL CHECK(role IN ('authoritative', 'supporting')),
  source_format_code TEXT NOT NULL CHECK(source_format_code IN ('pdf', 'xls')),
  created_at DATETIME NOT NULL,
  UNIQUE(group_id, source_format_code),
  FOREIGN KEY(group_id) REFERENCES statement_equivalence_groups(id) ON DELETE RESTRICT,
  FOREIGN KEY(projection_id) REFERENCES statement_financial_projections(id) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX idx_statement_equivalence_one_authoritative_member
  ON statement_equivalence_members(group_id)
  WHERE role = 'authoritative';

CREATE TRIGGER validate_statement_projection_relationships
BEFORE INSERT ON statement_financial_projections
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM accounts a
    WHERE a.id = NEW.account_id AND a.workspace_id = NEW.workspace_id
  ) THEN RAISE(ABORT, 'statement projection account relationship invalid') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM documents d
    WHERE d.id = NEW.document_id
      AND d.workspace_id = NEW.workspace_id
      AND d.import_session_id = NEW.import_session_id
  ) THEN RAISE(ABORT, 'statement projection document relationship invalid') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM import_sessions s
    WHERE s.id = NEW.import_session_id AND s.workspace_id = NEW.workspace_id
  ) THEN RAISE(ABORT, 'statement projection session relationship invalid') END;
END;

CREATE TRIGGER validate_statement_equivalence_group
BEFORE INSERT ON statement_equivalence_groups
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM statement_financial_projections p
    WHERE p.id = NEW.authoritative_projection_id
      AND p.workspace_id = NEW.workspace_id
      AND p.account_id = NEW.account_id
      AND p.institution_code = NEW.institution_code
      AND p.statement_family_code = NEW.statement_family_code
      AND p.statement_start_date = NEW.statement_start_date
      AND p.statement_end_date = NEW.statement_end_date
      AND p.native_currency = NEW.native_currency
      AND p.algorithm = NEW.projection_algorithm
      AND p.digest = NEW.projection_digest
      AND (SELECT COUNT(*) FROM statement_financial_projection_events e WHERE e.projection_id = p.id) = p.event_count
  ) THEN RAISE(ABORT, 'statement equivalence authoritative projection invalid') END;
END;

CREATE TRIGGER validate_statement_equivalence_member
BEFORE INSERT ON statement_equivalence_members
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1
    FROM statement_equivalence_groups g
    JOIN statement_financial_projections p ON p.id = NEW.projection_id
    WHERE g.id = NEW.group_id
      AND p.workspace_id = g.workspace_id
      AND p.account_id = g.account_id
      AND p.institution_code = g.institution_code
      AND p.statement_family_code = g.statement_family_code
      AND p.statement_start_date = g.statement_start_date
      AND p.statement_end_date = g.statement_end_date
      AND p.native_currency = g.native_currency
      AND p.algorithm = g.projection_algorithm
      AND p.digest = g.projection_digest
      AND p.source_format_code = NEW.source_format_code
      AND (SELECT COUNT(*) FROM statement_financial_projection_events e WHERE e.projection_id = p.id) = p.event_count
  ) THEN RAISE(ABORT, 'statement equivalence member projection invalid') END;
  SELECT CASE WHEN NEW.role = 'authoritative' AND NOT EXISTS (
    SELECT 1 FROM statement_equivalence_groups g
    WHERE g.id = NEW.group_id AND g.authoritative_projection_id = NEW.projection_id
  ) THEN RAISE(ABORT, 'statement equivalence authoritative member invalid') END;
  SELECT CASE WHEN NEW.role = 'supporting' AND EXISTS (
    SELECT 1 FROM statement_equivalence_groups g
    WHERE g.id = NEW.group_id AND g.authoritative_projection_id = NEW.projection_id
  ) THEN RAISE(ABORT, 'statement equivalence supporting member invalid') END;
  SELECT CASE WHEN NEW.role = 'authoritative' AND (
    SELECT COUNT(*) FROM transactions t
    JOIN statement_financial_projections p ON p.id = NEW.projection_id
    WHERE t.import_session_id = p.import_session_id AND t.document_id = p.document_id
  ) != (
    SELECT event_count FROM statement_financial_projections p WHERE p.id = NEW.projection_id
  ) THEN RAISE(ABORT, 'statement equivalence authoritative transaction ownership invalid') END;
  SELECT CASE WHEN NEW.role = 'supporting' AND EXISTS (
    SELECT 1 FROM transactions t
    JOIN statement_financial_projections p ON p.id = NEW.projection_id
    WHERE t.import_session_id = p.import_session_id OR t.document_id = p.document_id
  ) THEN RAISE(ABORT, 'statement equivalence supporting transaction ownership invalid') END;
END;
"""
)

public let migrationV11 = Migration(
    version: 11,
    name: "CBQ exact source observations and masked identity evidence",
    sql: """
CREATE TABLE cbq_source_identity_observations (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  import_session_id TEXT NOT NULL,
  normalized_document_id TEXT NOT NULL,
  parser_profile_id TEXT NOT NULL CHECK(parser_profile_id = 'cbq.current-account.monthly.pdf'),
  parser_profile_version TEXT NOT NULL CHECK(parser_profile_version = '1'),
  kind TEXT NOT NULL CHECK(kind IN ('cbq_masked_account_number', 'cbq_masked_iban')),
  pattern TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  UNIQUE(document_id, kind),
  CHECK((kind = 'cbq_masked_account_number' AND length(pattern) = 13) OR
        (kind = 'cbq_masked_iban' AND length(pattern) = 29)),
  CHECK(pattern NOT GLOB '*[^0-9A-Z]*' AND instr(pattern, 'X') > 0),
  CHECK(kind != 'cbq_masked_account_number' OR pattern NOT GLOB '*[^0-9X]*'),
  CHECK(kind != 'cbq_masked_iban' OR
        (substr(pattern, 1, 2) = 'QA' AND
         substr(pattern, 3, 2) NOT GLOB '*[^0-9]*' AND
         substr(pattern, 5, 4) = 'CBQA')),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT,
  FOREIGN KEY(normalized_document_id) REFERENCES normalized_documents(id) ON DELETE RESTRICT
);
CREATE INDEX idx_cbq_source_identity_account
  ON cbq_source_identity_observations(workspace_id, account_id, kind);

CREATE TABLE statement_source_observations (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  import_session_id TEXT NOT NULL UNIQUE,
  document_id TEXT NOT NULL UNIQUE,
  normalized_document_id TEXT NOT NULL UNIQUE,
  parser_profile_id TEXT NOT NULL CHECK(parser_profile_id IN ('cbq.current-account.xls', 'cbq.current-account.history.pdf', 'cbq.current-account.monthly.pdf')),
  parser_profile_version TEXT NOT NULL CHECK(parser_profile_version = '1'),
  source_format_code TEXT NOT NULL CHECK(source_format_code IN ('history-xls', 'history-pdf', 'monthly-pdf')),
  native_currency TEXT NOT NULL CHECK(native_currency = 'QAR'),
  source_row_count INTEGER NOT NULL CHECK(source_row_count > 0),
  newly_imported_transaction_count INTEGER NOT NULL CHECK(newly_imported_transaction_count >= 0),
  represented_transaction_count INTEGER NOT NULL CHECK(represented_transaction_count >= 0),
  blocked_count INTEGER NOT NULL CHECK(blocked_count = 0),
  statement_boundary_date DATE,
  statement_start_date DATE,
  statement_end_date DATE,
  opening_balance_minor INTEGER,
  opening_balance_decimal TEXT,
  closing_balance_minor INTEGER,
  closing_balance_decimal TEXT,
  created_at DATETIME NOT NULL,
  CHECK(source_row_count = newly_imported_transaction_count + represented_transaction_count),
  CHECK((statement_start_date IS NULL AND statement_end_date IS NULL) OR
        (statement_start_date IS NOT NULL AND statement_end_date IS NOT NULL AND statement_start_date <= statement_end_date)),
  CHECK((opening_balance_minor IS NULL) = (opening_balance_decimal IS NULL)),
  CHECK((closing_balance_minor IS NULL) = (closing_balance_decimal IS NULL)),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(normalized_document_id) REFERENCES normalized_documents(id) ON DELETE RESTRICT
);
CREATE INDEX idx_statement_source_observation_account
  ON statement_source_observations(workspace_id, account_id, created_at);

CREATE TABLE transaction_source_observations (
  id TEXT PRIMARY KEY,
  canonical_transaction_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  import_session_id TEXT NOT NULL,
  normalized_row_id TEXT NOT NULL UNIQUE,
  source_ordinal INTEGER NOT NULL CHECK(source_ordinal > 0),
  posting_date DATE NOT NULL,
  source_transaction_date DATE,
  native_currency TEXT NOT NULL CHECK(native_currency = 'QAR'),
  signed_amount_minor INTEGER NOT NULL CHECK(signed_amount_minor != 0),
  signed_amount_decimal TEXT NOT NULL CHECK(length(signed_amount_decimal) > 0),
  running_balance_minor INTEGER NOT NULL,
  running_balance_decimal TEXT NOT NULL CHECK(length(running_balance_decimal) > 0),
  structured_reference_digest TEXT CHECK(structured_reference_digest IS NULL OR (length(structured_reference_digest) = 64 AND structured_reference_digest NOT GLOB '*[^0-9a-f]*')),
  observation_role TEXT NOT NULL CHECK(observation_role IN ('introduced', 'represented-existing')),
  created_at DATETIME NOT NULL,
  UNIQUE(document_id, source_ordinal),
  FOREIGN KEY(canonical_transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT,
  FOREIGN KEY(normalized_row_id) REFERENCES normalized_rows(id) ON DELETE RESTRICT
);
CREATE INDEX idx_transaction_source_observation_canonical
  ON transaction_source_observations(canonical_transaction_id, created_at);

CREATE TRIGGER validate_cbq_source_identity_observation
BEFORE INSERT ON cbq_source_identity_observations
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.id = NEW.account_id AND a.workspace_id = NEW.workspace_id
  ) THEN RAISE(ABORT, 'cbq identity account relationship invalid') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM documents d JOIN import_sessions s ON s.id = d.import_session_id
    JOIN normalized_documents n ON n.document_id = d.id AND n.import_session_id = s.id
    WHERE d.id = NEW.document_id AND s.id = NEW.import_session_id
      AND n.id = NEW.normalized_document_id AND d.workspace_id = NEW.workspace_id
      AND n.profile_id = NEW.parser_profile_id AND n.profile_version = NEW.parser_profile_version
  ) THEN RAISE(ABORT, 'cbq identity source relationship invalid') END;
END;

CREATE TRIGGER validate_statement_source_observation
BEFORE INSERT ON statement_source_observations
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.id = NEW.account_id AND a.workspace_id = NEW.workspace_id
  ) THEN RAISE(ABORT, 'statement source account relationship invalid') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM documents d JOIN import_sessions s ON s.id = d.import_session_id
    JOIN normalized_documents n ON n.document_id = d.id AND n.import_session_id = s.id
    WHERE d.id = NEW.document_id AND s.id = NEW.import_session_id
      AND n.id = NEW.normalized_document_id AND d.workspace_id = NEW.workspace_id
      AND n.profile_id = NEW.parser_profile_id AND n.profile_version = NEW.parser_profile_version
  ) THEN RAISE(ABORT, 'statement source relationship invalid') END;
END;

CREATE TRIGGER validate_transaction_source_observation
BEFORE INSERT ON transaction_source_observations
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM transactions t
    JOIN documents d ON d.id = NEW.document_id
    JOIN import_sessions s ON s.id = NEW.import_session_id
    JOIN normalized_rows r ON r.id = NEW.normalized_row_id
    JOIN normalized_documents n ON n.id = r.normalized_document_id
    WHERE t.id = NEW.canonical_transaction_id
      AND d.import_session_id = s.id
      AND n.document_id = d.id AND n.import_session_id = s.id
  ) THEN RAISE(ABORT, 'transaction source relationship invalid') END;
END;
"""
)

public let migrationV12 = Migration(
    version: 12,
    name: "durable credit card instruments and statement evidence",
    sql: """
CREATE TABLE card_instruments (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  liability_account_id TEXT NOT NULL,
  lifecycle_state TEXT NOT NULL CHECK(lifecycle_state IN ('unknown', 'active', 'retired', 'replaced')),
  created_at DATETIME NOT NULL,
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(liability_account_id) REFERENCES accounts(id) ON DELETE RESTRICT
);
CREATE INDEX idx_card_instrument_account ON card_instruments(workspace_id, liability_account_id);

CREATE TABLE card_instrument_identifiers (
  id TEXT PRIMARY KEY,
  instrument_id TEXT NOT NULL,
  workspace_id TEXT NOT NULL,
  scheme TEXT NOT NULL,
  identifier TEXT NOT NULL,
  parser_provenance TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  UNIQUE(workspace_id, scheme, identifier),
  FOREIGN KEY(instrument_id) REFERENCES card_instruments(id) ON DELETE RESTRICT,
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT
);

CREATE TABLE card_source_identity_observations (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  import_session_id TEXT NOT NULL,
  normalized_document_id TEXT NOT NULL,
  parser_profile_id TEXT NOT NULL,
  parser_profile_version TEXT NOT NULL,
  subject_kind TEXT NOT NULL CHECK(subject_kind IN ('liability_account', 'instrument')),
  subject_id TEXT NOT NULL,
  observation_kind TEXT NOT NULL CHECK(observation_kind IN ('amex_membership_number', 'amex_card_account_number')),
  source_value TEXT NOT NULL CHECK(length(source_value) > 0),
  association_authority TEXT NOT NULL CHECK(association_authority IN ('user_confirmed', 'prior_user_confirmed_mapping', 'parser_strong_evidence')),
  created_at DATETIME NOT NULL,
  UNIQUE(document_id, subject_kind, observation_kind),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT,
  FOREIGN KEY(normalized_document_id) REFERENCES normalized_documents(id) ON DELETE RESTRICT
);
CREATE INDEX idx_card_source_identity_subject ON card_source_identity_observations(workspace_id, subject_kind, subject_id, observation_kind, source_value);

CREATE TABLE card_instrument_relationships (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  liability_account_id TEXT NOT NULL,
  predecessor_instrument_id TEXT NOT NULL,
  successor_instrument_id TEXT NOT NULL,
  relationship_kind TEXT NOT NULL CHECK(relationship_kind IN ('additional_concurrent', 'replacement', 'renewal', 'upgrade', 'unspecified')),
  authority TEXT NOT NULL CHECK(authority IN ('user_confirmed', 'source_proven')),
  effective_date DATE,
  created_at DATETIME NOT NULL,
  CHECK(predecessor_instrument_id != successor_instrument_id),
  UNIQUE(predecessor_instrument_id, successor_instrument_id, relationship_kind),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(liability_account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
  FOREIGN KEY(predecessor_instrument_id) REFERENCES card_instruments(id) ON DELETE RESTRICT,
  FOREIGN KEY(successor_instrument_id) REFERENCES card_instruments(id) ON DELETE RESTRICT
);

CREATE TABLE card_statements (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  liability_account_id TEXT NOT NULL,
  document_id TEXT NOT NULL UNIQUE,
  import_session_id TEXT NOT NULL UNIQUE,
  normalized_document_id TEXT NOT NULL UNIQUE,
  parser_profile_id TEXT NOT NULL,
  parser_profile_version TEXT NOT NULL,
  statement_date DATE NOT NULL,
  statement_start_date DATE NOT NULL,
  statement_end_date DATE NOT NULL,
  statement_currency TEXT NOT NULL,
  source_row_count INTEGER NOT NULL CHECK(source_row_count > 0),
  reconciliation_rule_code TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  CHECK(statement_start_date <= statement_end_date),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(liability_account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT,
  FOREIGN KEY(normalized_document_id) REFERENCES normalized_documents(id) ON DELETE RESTRICT
);
CREATE INDEX idx_card_statement_current ON card_statements(workspace_id, liability_account_id, statement_end_date, statement_date);

CREATE TABLE card_statement_summary_components (
  id TEXT PRIMARY KEY,
  card_statement_id TEXT NOT NULL,
  component_code TEXT NOT NULL CHECK(component_code IN ('previous_balance', 'new_credits', 'new_debits', 'new_balance', 'due_date', 'instrument_net_total')),
  money_currency TEXT,
  money_minor INTEGER,
  money_decimal TEXT,
  date_value DATE,
  UNIQUE(card_statement_id, component_code),
  CHECK((component_code = 'due_date' AND date_value IS NOT NULL AND money_currency IS NULL AND money_minor IS NULL AND money_decimal IS NULL) OR
        (component_code != 'due_date' AND date_value IS NULL AND money_currency IS NOT NULL AND money_minor IS NOT NULL AND money_decimal IS NOT NULL)),
  FOREIGN KEY(card_statement_id) REFERENCES card_statements(id) ON DELETE RESTRICT
);

CREATE TABLE card_transaction_evidence (
  id TEXT PRIMARY KEY,
  card_statement_id TEXT NOT NULL,
  transaction_id TEXT NOT NULL UNIQUE,
  row_scope TEXT NOT NULL CHECK(row_scope IN ('account_level', 'instrument_level')),
  instrument_id TEXT,
  liability_effect TEXT NOT NULL CHECK(liability_effect IN ('card_increase_owed', 'card_decrease_owed')),
  source_transaction_date DATE NOT NULL,
  document_scoped_section_id TEXT,
  original_currency TEXT,
  original_amount_minor INTEGER,
  original_amount_decimal TEXT,
  CHECK((row_scope = 'account_level' AND instrument_id IS NULL AND document_scoped_section_id IS NULL) OR
        (row_scope = 'instrument_level' AND instrument_id IS NOT NULL AND document_scoped_section_id IS NOT NULL)),
  CHECK((original_currency IS NULL AND original_amount_minor IS NULL AND original_amount_decimal IS NULL) OR
        (original_currency IS NOT NULL AND original_amount_minor IS NOT NULL AND original_amount_decimal IS NOT NULL)),
  FOREIGN KEY(card_statement_id) REFERENCES card_statements(id) ON DELETE RESTRICT,
  FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT,
  FOREIGN KEY(instrument_id) REFERENCES card_instruments(id) ON DELETE RESTRICT
);

CREATE TRIGGER validate_card_instrument
BEFORE INSERT ON card_instruments
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.id = NEW.liability_account_id
      AND a.workspace_id = NEW.workspace_id AND a.account_type = 'credit_card'
  ) THEN RAISE(ABORT, 'card instrument liability account invalid') END;
END;

CREATE TRIGGER validate_card_source_identity
BEFORE INSERT ON card_source_identity_observations
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM documents d JOIN import_sessions s ON s.id = d.import_session_id
    JOIN normalized_documents n ON n.document_id = d.id AND n.import_session_id = s.id
    WHERE d.id = NEW.document_id AND s.id = NEW.import_session_id
      AND n.id = NEW.normalized_document_id AND d.workspace_id = NEW.workspace_id
      AND n.profile_id = NEW.parser_profile_id AND n.profile_version = NEW.parser_profile_version
  ) THEN RAISE(ABORT, 'card observation source relationship invalid') END;
  SELECT CASE WHEN NEW.subject_kind = 'liability_account' AND NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.id = NEW.subject_id AND a.workspace_id = NEW.workspace_id AND a.account_type = 'credit_card'
  ) THEN RAISE(ABORT, 'card observation liability account invalid') END;
  SELECT CASE WHEN NEW.subject_kind = 'instrument' AND NOT EXISTS (
    SELECT 1 FROM card_instruments i WHERE i.id = NEW.subject_id AND i.workspace_id = NEW.workspace_id
  ) THEN RAISE(ABORT, 'card observation instrument invalid') END;
END;

CREATE TRIGGER validate_card_relationship
BEFORE INSERT ON card_instrument_relationships
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM card_instruments p JOIN card_instruments s ON s.id = NEW.successor_instrument_id
    WHERE p.id = NEW.predecessor_instrument_id
      AND p.workspace_id = NEW.workspace_id AND s.workspace_id = NEW.workspace_id
      AND p.liability_account_id = NEW.liability_account_id AND s.liability_account_id = NEW.liability_account_id
  ) THEN RAISE(ABORT, 'card instrument relationship account invalid') END;
END;

CREATE TRIGGER validate_card_statement
BEFORE INSERT ON card_statements
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.id = NEW.liability_account_id
      AND a.workspace_id = NEW.workspace_id AND a.account_type = 'credit_card'
  ) THEN RAISE(ABORT, 'card statement liability account invalid') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM documents d JOIN import_sessions s ON s.id = d.import_session_id
    JOIN normalized_documents n ON n.document_id = d.id AND n.import_session_id = s.id
    WHERE d.id = NEW.document_id AND s.id = NEW.import_session_id
      AND n.id = NEW.normalized_document_id AND d.workspace_id = NEW.workspace_id
      AND n.profile_id = NEW.parser_profile_id AND n.profile_version = NEW.parser_profile_version
  ) THEN RAISE(ABORT, 'card statement source relationship invalid') END;
END;

CREATE TRIGGER validate_card_transaction_evidence
BEFORE INSERT ON card_transaction_evidence
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM transactions t JOIN card_statements s ON s.id = NEW.card_statement_id
    WHERE t.id = NEW.transaction_id AND t.account_id = s.liability_account_id
      AND t.document_id = s.document_id AND t.import_session_id = s.import_session_id
      AND t.direction = NEW.liability_effect
  ) THEN RAISE(ABORT, 'card transaction relationship invalid') END;
  SELECT CASE WHEN NEW.instrument_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM card_instruments i JOIN card_statements s ON s.id = NEW.card_statement_id
    WHERE i.id = NEW.instrument_id AND i.liability_account_id = s.liability_account_id
  ) THEN RAISE(ABORT, 'card transaction instrument invalid') END;
END;
"""
)

public let migrationV13 = Migration(
    version: 13,
    name: "multi-section card statements and exact semantic sources",
    sql: """
CREATE TABLE card_statement_sections (
  id TEXT PRIMARY KEY,
  card_statement_id TEXT NOT NULL,
  document_scoped_section_id TEXT NOT NULL CHECK(length(document_scoped_section_id) > 0),
  source_ordinal INTEGER NOT NULL CHECK(source_ordinal > 0),
  instrument_id TEXT NOT NULL,
  holder_label TEXT,
  signed_total_currency TEXT NOT NULL,
  signed_total_minor INTEGER NOT NULL,
  signed_total_decimal TEXT NOT NULL,
  reconciliation_rule_code TEXT NOT NULL CHECK(length(reconciliation_rule_code) > 0),
  UNIQUE(card_statement_id, document_scoped_section_id),
  UNIQUE(card_statement_id, source_ordinal),
  FOREIGN KEY(card_statement_id) REFERENCES card_statements(id) ON DELETE RESTRICT,
  FOREIGN KEY(instrument_id) REFERENCES card_instruments(id) ON DELETE RESTRICT
);
CREATE INDEX idx_card_statement_section_instrument
  ON card_statement_sections(instrument_id, card_statement_id, source_ordinal);

CREATE TABLE card_statement_section_observations (
  id TEXT PRIMARY KEY,
  card_statement_section_id TEXT NOT NULL,
  workspace_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  import_session_id TEXT NOT NULL,
  normalized_document_id TEXT NOT NULL,
  parser_profile_id TEXT NOT NULL,
  parser_profile_version TEXT NOT NULL,
  observation_kind TEXT NOT NULL CHECK(observation_kind = 'amex_card_account_number'),
  source_value TEXT NOT NULL CHECK(length(source_value) > 0),
  association_authority TEXT NOT NULL CHECK(association_authority IN ('user_confirmed', 'prior_user_confirmed_mapping', 'parser_strong_evidence')),
  created_at DATETIME NOT NULL,
  UNIQUE(card_statement_section_id, observation_kind, source_value),
  FOREIGN KEY(card_statement_section_id) REFERENCES card_statement_sections(id) ON DELETE RESTRICT,
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT,
  FOREIGN KEY(normalized_document_id) REFERENCES normalized_documents(id) ON DELETE RESTRICT
);
CREATE INDEX idx_card_section_observation_lookup
  ON card_statement_section_observations(workspace_id, observation_kind, source_value, card_statement_section_id);

CREATE TABLE card_statement_semantic_projections (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  liability_account_id TEXT NOT NULL,
  card_statement_id TEXT NOT NULL UNIQUE,
  document_id TEXT NOT NULL UNIQUE,
  import_session_id TEXT NOT NULL UNIQUE,
  algorithm TEXT NOT NULL,
  digest TEXT NOT NULL CHECK(length(digest) = 64),
  institution_code TEXT NOT NULL,
  statement_family_code TEXT NOT NULL,
  parser_profile_id TEXT NOT NULL,
  parser_profile_version TEXT NOT NULL,
  statement_date DATE NOT NULL,
  statement_start_date DATE NOT NULL,
  statement_end_date DATE NOT NULL,
  native_currency TEXT NOT NULL,
  event_count INTEGER NOT NULL CHECK(event_count > 0),
  section_count INTEGER NOT NULL CHECK(section_count > 0),
  reconciliation_rule_code TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  CHECK(statement_start_date <= statement_end_date),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(liability_account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
  FOREIGN KEY(card_statement_id) REFERENCES card_statements(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT
);
CREATE INDEX idx_card_semantic_projection_period
  ON card_statement_semantic_projections(workspace_id, liability_account_id, statement_start_date, statement_end_date);

CREATE TABLE card_statement_semantic_projection_sections (
  id TEXT PRIMARY KEY,
  projection_id TEXT NOT NULL,
  source_ordinal INTEGER NOT NULL CHECK(source_ordinal > 0),
  document_scoped_section_id TEXT NOT NULL,
  signed_total_currency TEXT NOT NULL,
  signed_total_minor INTEGER NOT NULL,
  signed_total_decimal TEXT NOT NULL,
  reconciliation_rule_code TEXT NOT NULL,
  UNIQUE(projection_id, source_ordinal),
  UNIQUE(projection_id, document_scoped_section_id),
  FOREIGN KEY(projection_id) REFERENCES card_statement_semantic_projections(id) ON DELETE RESTRICT
);

CREATE TABLE card_statement_semantic_projection_events (
  id TEXT PRIMARY KEY,
  projection_id TEXT NOT NULL,
  canonical_transaction_id TEXT NOT NULL,
  normalized_row_id TEXT NOT NULL,
  source_ordinal INTEGER NOT NULL CHECK(source_ordinal > 0),
  posting_date DATE NOT NULL,
  source_transaction_date DATE NOT NULL,
  liability_effect TEXT NOT NULL CHECK(liability_effect IN ('card_increase_owed', 'card_decrease_owed')),
  posted_currency TEXT NOT NULL,
  posted_amount_minor INTEGER NOT NULL,
  posted_amount_decimal TEXT NOT NULL,
  original_currency TEXT,
  original_amount_minor INTEGER,
  original_amount_decimal TEXT,
  source_reference TEXT,
  row_scope TEXT NOT NULL CHECK(row_scope IN ('account_level', 'instrument_level')),
  document_scoped_section_id TEXT,
  document_section_ordinal INTEGER,
  UNIQUE(projection_id, source_ordinal),
  CHECK((row_scope = 'account_level' AND document_scoped_section_id IS NULL AND document_section_ordinal IS NULL) OR
        (row_scope = 'instrument_level' AND document_scoped_section_id IS NOT NULL AND document_section_ordinal IS NOT NULL)),
  CHECK((original_currency IS NULL AND original_amount_minor IS NULL AND original_amount_decimal IS NULL) OR
        (original_currency IS NOT NULL AND original_amount_minor IS NOT NULL AND original_amount_decimal IS NOT NULL)),
  FOREIGN KEY(projection_id) REFERENCES card_statement_semantic_projections(id) ON DELETE RESTRICT,
  FOREIGN KEY(canonical_transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT,
  FOREIGN KEY(normalized_row_id) REFERENCES normalized_rows(id) ON DELETE RESTRICT
);
CREATE INDEX idx_card_semantic_event_transaction
  ON card_statement_semantic_projection_events(canonical_transaction_id, projection_id, source_ordinal);

CREATE TABLE card_statement_semantic_groups (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  liability_account_id TEXT NOT NULL,
  institution_code TEXT NOT NULL,
  statement_family_code TEXT NOT NULL,
  statement_start_date DATE NOT NULL,
  statement_end_date DATE NOT NULL,
  native_currency TEXT NOT NULL,
  projection_algorithm TEXT NOT NULL,
  projection_digest TEXT NOT NULL CHECK(length(projection_digest) = 64),
  authoritative_projection_id TEXT NOT NULL UNIQUE,
  created_at DATETIME NOT NULL,
  UNIQUE(workspace_id, liability_account_id, institution_code, statement_family_code, statement_start_date, statement_end_date, native_currency),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(liability_account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
  FOREIGN KEY(authoritative_projection_id) REFERENCES card_statement_semantic_projections(id) ON DELETE RESTRICT
);

CREATE TABLE card_statement_semantic_members (
  id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  projection_id TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL CHECK(role IN ('authoritative', 'supporting')),
  created_at DATETIME NOT NULL,
  FOREIGN KEY(group_id) REFERENCES card_statement_semantic_groups(id) ON DELETE RESTRICT,
  FOREIGN KEY(projection_id) REFERENCES card_statement_semantic_projections(id) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX idx_card_semantic_authoritative_member
  ON card_statement_semantic_members(group_id) WHERE role = 'authoritative';

CREATE TRIGGER validate_card_statement_section
BEFORE INSERT ON card_statement_sections
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM card_statements s JOIN card_instruments i ON i.id = NEW.instrument_id
    WHERE s.id = NEW.card_statement_id
      AND i.workspace_id = s.workspace_id
      AND i.liability_account_id = s.liability_account_id
      AND NEW.signed_total_currency = s.statement_currency
  ) THEN RAISE(ABORT, 'card statement section relationship invalid') END;
END;

CREATE TRIGGER validate_card_statement_section_observation
BEFORE INSERT ON card_statement_section_observations
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM card_statement_sections cs
    JOIN card_statements s ON s.id = cs.card_statement_id
    JOIN normalized_documents n ON n.id = NEW.normalized_document_id
    WHERE cs.id = NEW.card_statement_section_id
      AND s.workspace_id = NEW.workspace_id
      AND s.document_id = NEW.document_id
      AND s.import_session_id = NEW.import_session_id
      AND s.normalized_document_id = NEW.normalized_document_id
      AND s.parser_profile_id = NEW.parser_profile_id
      AND s.parser_profile_version = NEW.parser_profile_version
      AND n.document_id = NEW.document_id
      AND n.import_session_id = NEW.import_session_id
  ) THEN RAISE(ABORT, 'card section observation relationship invalid') END;
END;

CREATE TRIGGER validate_v13_card_transaction_section
BEFORE INSERT ON card_transaction_evidence
WHEN NEW.row_scope = 'instrument_level'
 AND EXISTS (
   SELECT 1 FROM card_statement_sections
   WHERE card_statement_id = NEW.card_statement_id
 )
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM card_statement_sections cs
    WHERE cs.card_statement_id = NEW.card_statement_id
      AND cs.document_scoped_section_id = NEW.document_scoped_section_id
      AND cs.instrument_id = NEW.instrument_id
  ) THEN RAISE(ABORT, 'card transaction section relationship invalid') END;
END;

CREATE TRIGGER validate_card_semantic_projection
BEFORE INSERT ON card_statement_semantic_projections
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM card_statements s
    WHERE s.id = NEW.card_statement_id
      AND s.workspace_id = NEW.workspace_id
      AND s.liability_account_id = NEW.liability_account_id
      AND s.document_id = NEW.document_id
      AND s.import_session_id = NEW.import_session_id
      AND s.statement_date = NEW.statement_date
      AND s.statement_start_date = NEW.statement_start_date
      AND s.statement_end_date = NEW.statement_end_date
      AND s.statement_currency = NEW.native_currency
      AND s.parser_profile_id = NEW.parser_profile_id
      AND s.parser_profile_version = NEW.parser_profile_version
  ) THEN RAISE(ABORT, 'card semantic projection relationship invalid') END;
END;

CREATE TRIGGER validate_card_semantic_projection_event
BEFORE INSERT ON card_statement_semantic_projection_events
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM card_statement_semantic_projections p
    JOIN normalized_rows r ON r.id = NEW.normalized_row_id
    JOIN normalized_documents n ON n.id = r.normalized_document_id
    JOIN transactions t ON t.id = NEW.canonical_transaction_id
    WHERE p.id = NEW.projection_id
      AND n.document_id = p.document_id
      AND n.import_session_id = p.import_session_id
      AND t.account_id = p.liability_account_id
  ) THEN RAISE(ABORT, 'card semantic event relationship invalid') END;
END;

-- V12 compatibility backfill. Only the exact singular V12 Amex shape is
-- migrated: one known parser-owned section ID, one durable instrument, one
-- instrument observation and the already persisted signed aggregate total.
INSERT INTO card_statement_sections (
  id, card_statement_id, document_scoped_section_id, source_ordinal, instrument_id,
  holder_label, signed_total_currency, signed_total_minor, signed_total_decimal,
  reconciliation_rule_code
)
SELECT
  'card-section-' || s.id,
  s.id,
  'instrument-section-1',
  1,
  e.instrument_id,
  NULL,
  c.money_currency,
  c.money_minor,
  c.money_decimal,
  'amex.section.signed-increases-minus-decreases.v1'
FROM card_statements s
JOIN card_statement_summary_components c
  ON c.card_statement_id = s.id AND c.component_code = 'instrument_net_total'
JOIN (
  SELECT card_statement_id, MIN(instrument_id) AS instrument_id
  FROM card_transaction_evidence
  WHERE row_scope = 'instrument_level'
    AND document_scoped_section_id = 'instrument-section-1'
  GROUP BY card_statement_id
  HAVING COUNT(DISTINCT instrument_id) = 1
     AND COUNT(DISTINCT document_scoped_section_id) = 1
) e ON e.card_statement_id = s.id
WHERE s.parser_profile_id = 'amex.credit-card.pdf'
  AND s.parser_profile_version = '1'
  AND (SELECT COUNT(*) FROM card_source_identity_observations o
        WHERE o.document_id = s.document_id
          AND o.subject_kind = 'instrument'
          AND o.subject_id = e.instrument_id
          AND o.observation_kind = 'amex_card_account_number') = 1;

INSERT INTO card_statement_section_observations (
  id, card_statement_section_id, workspace_id, document_id, import_session_id,
  normalized_document_id, parser_profile_id, parser_profile_version,
  observation_kind, source_value, association_authority, created_at
)
SELECT
  'card-section-observation-' || o.id,
  cs.id,
  o.workspace_id,
  o.document_id,
  o.import_session_id,
  o.normalized_document_id,
  o.parser_profile_id,
  o.parser_profile_version,
  o.observation_kind,
  o.source_value,
  o.association_authority,
  o.created_at
FROM card_statement_sections cs
JOIN card_statements s ON s.id = cs.card_statement_id
JOIN card_source_identity_observations o
  ON o.document_id = s.document_id
 AND o.subject_kind = 'instrument'
 AND o.subject_id = cs.instrument_id
 AND o.observation_kind = 'amex_card_account_number';
"""
)

public let migrationV14 = Migration(
    version: 14,
    name: "generalized card reconciliation and structural section evidence",
    sql: """
DROP TRIGGER validate_card_source_identity;
DROP TRIGGER validate_card_statement_section_observation;
DROP TRIGGER validate_card_transaction_evidence;
DROP TRIGGER validate_v13_card_transaction_section;

ALTER TABLE card_source_identity_observations RENAME TO card_source_identity_observations_v13;
ALTER TABLE card_statement_section_observations RENAME TO card_statement_section_observations_v13;
ALTER TABLE card_statement_summary_components RENAME TO card_statement_summary_components_v13;
ALTER TABLE card_transaction_evidence RENAME TO card_transaction_evidence_v13;

CREATE TABLE card_source_identity_observations (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  import_session_id TEXT NOT NULL,
  normalized_document_id TEXT NOT NULL,
  parser_profile_id TEXT NOT NULL,
  parser_profile_version TEXT NOT NULL,
  subject_kind TEXT NOT NULL CHECK(subject_kind IN ('liability_account', 'instrument')),
  subject_id TEXT NOT NULL,
  observation_kind TEXT NOT NULL CHECK(observation_kind IN (
    'amex_membership_number', 'amex_card_account_number',
    'cbq_card_account_reference', 'cbq_masked_card_number'
  )),
  source_value TEXT NOT NULL CHECK(length(source_value) > 0),
  association_authority TEXT NOT NULL CHECK(association_authority IN ('user_confirmed', 'prior_user_confirmed_mapping', 'parser_strong_evidence')),
  created_at DATETIME NOT NULL,
  UNIQUE(document_id, subject_kind, observation_kind),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT,
  FOREIGN KEY(normalized_document_id) REFERENCES normalized_documents(id) ON DELETE RESTRICT
);
INSERT INTO card_source_identity_observations
SELECT * FROM card_source_identity_observations_v13;
DROP TABLE card_source_identity_observations_v13;
CREATE INDEX idx_card_source_identity_subject ON card_source_identity_observations(workspace_id, subject_kind, subject_id, observation_kind, source_value);

CREATE TABLE card_statement_section_observations (
  id TEXT PRIMARY KEY,
  card_statement_section_id TEXT NOT NULL,
  workspace_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  import_session_id TEXT NOT NULL,
  normalized_document_id TEXT NOT NULL,
  parser_profile_id TEXT NOT NULL,
  parser_profile_version TEXT NOT NULL,
  observation_kind TEXT NOT NULL CHECK(observation_kind IN ('amex_card_account_number', 'cbq_masked_card_number')),
  source_value TEXT NOT NULL CHECK(length(source_value) > 0),
  association_authority TEXT NOT NULL CHECK(association_authority IN ('user_confirmed', 'prior_user_confirmed_mapping', 'parser_strong_evidence')),
  created_at DATETIME NOT NULL,
  UNIQUE(card_statement_section_id, observation_kind, source_value),
  FOREIGN KEY(card_statement_section_id) REFERENCES card_statement_sections(id) ON DELETE RESTRICT,
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT,
  FOREIGN KEY(normalized_document_id) REFERENCES normalized_documents(id) ON DELETE RESTRICT
);
INSERT INTO card_statement_section_observations
SELECT * FROM card_statement_section_observations_v13;
DROP TABLE card_statement_section_observations_v13;
CREATE INDEX idx_card_section_observation_lookup ON card_statement_section_observations(workspace_id, observation_kind, source_value, card_statement_section_id);

CREATE TABLE card_statement_summary_components (
  id TEXT PRIMARY KEY,
  card_statement_id TEXT NOT NULL,
  component_code TEXT NOT NULL CHECK(component_code IN (
    'previous_balance', 'new_credits', 'new_debits', 'amount_billed', 'payment_received',
    'total_payment', 'credit_reversal', 'purchases', 'billed_installment', 'fees_charges',
    'new_balance', 'due_date', 'instrument_net_total', 'source_section_net_total'
  )),
  money_currency TEXT,
  money_minor INTEGER,
  money_decimal TEXT,
  date_value DATE,
  UNIQUE(card_statement_id, component_code),
  CHECK((component_code = 'due_date' AND date_value IS NOT NULL AND money_currency IS NULL AND money_minor IS NULL AND money_decimal IS NULL) OR
        (component_code != 'due_date' AND date_value IS NULL AND money_currency IS NOT NULL AND money_minor IS NOT NULL AND money_decimal IS NOT NULL)),
  FOREIGN KEY(card_statement_id) REFERENCES card_statements(id) ON DELETE RESTRICT
);
INSERT INTO card_statement_summary_components
SELECT * FROM card_statement_summary_components_v13;
DROP TABLE card_statement_summary_components_v13;

CREATE TABLE card_transaction_evidence (
  id TEXT PRIMARY KEY,
  card_statement_id TEXT NOT NULL,
  transaction_id TEXT NOT NULL UNIQUE,
  row_scope TEXT NOT NULL CHECK(row_scope IN ('account_level', 'instrument_level')),
  instrument_id TEXT,
  liability_effect TEXT NOT NULL CHECK(liability_effect IN ('card_increase_owed', 'card_decrease_owed')),
  source_transaction_date DATE NOT NULL,
  document_scoped_section_id TEXT,
  original_currency TEXT,
  original_amount_minor INTEGER,
  original_amount_decimal TEXT,
  summary_membership_code TEXT CHECK(summary_membership_code IS NULL OR summary_membership_code IN (
    'cbq_v1_amount_billed', 'cbq_v1_payment_received', 'cbq_v2_total_payment',
    'cbq_v2_credit_reversal', 'cbq_v2_purchases', 'cbq_v2_billed_installment', 'cbq_v2_fees_charges'
  )),
  CHECK((row_scope = 'account_level' AND instrument_id IS NULL) OR
        (row_scope = 'instrument_level' AND instrument_id IS NOT NULL AND document_scoped_section_id IS NOT NULL)),
  CHECK((original_currency IS NULL AND original_amount_minor IS NULL AND original_amount_decimal IS NULL) OR
        (original_currency IS NOT NULL AND original_amount_minor IS NOT NULL AND original_amount_decimal IS NOT NULL)),
  FOREIGN KEY(card_statement_id) REFERENCES card_statements(id) ON DELETE RESTRICT,
  FOREIGN KEY(transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT,
  FOREIGN KEY(instrument_id) REFERENCES card_instruments(id) ON DELETE RESTRICT
);
INSERT INTO card_transaction_evidence (
  id, card_statement_id, transaction_id, row_scope, instrument_id, liability_effect,
  source_transaction_date, document_scoped_section_id, original_currency,
  original_amount_minor, original_amount_decimal, summary_membership_code
)
SELECT id, card_statement_id, transaction_id, row_scope, instrument_id, liability_effect,
  source_transaction_date, document_scoped_section_id, original_currency,
  original_amount_minor, original_amount_decimal, NULL
FROM card_transaction_evidence_v13;
DROP TABLE card_transaction_evidence_v13;

CREATE TRIGGER validate_card_source_identity
BEFORE INSERT ON card_source_identity_observations
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM documents d JOIN import_sessions s ON s.id = d.import_session_id
    JOIN normalized_documents n ON n.document_id = d.id AND n.import_session_id = s.id
    WHERE d.id = NEW.document_id AND s.id = NEW.import_session_id
      AND n.id = NEW.normalized_document_id AND d.workspace_id = NEW.workspace_id
      AND n.profile_id = NEW.parser_profile_id AND n.profile_version = NEW.parser_profile_version
  ) THEN RAISE(ABORT, 'card observation source relationship invalid') END;
  SELECT CASE WHEN NEW.subject_kind = 'liability_account' AND NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.id = NEW.subject_id AND a.workspace_id = NEW.workspace_id AND a.account_type = 'credit_card'
  ) THEN RAISE(ABORT, 'card observation liability account invalid') END;
  SELECT CASE WHEN NEW.subject_kind = 'instrument' AND NOT EXISTS (
    SELECT 1 FROM card_instruments i WHERE i.id = NEW.subject_id AND i.workspace_id = NEW.workspace_id
  ) THEN RAISE(ABORT, 'card observation instrument invalid') END;
END;

CREATE TRIGGER validate_card_statement_section_observation
BEFORE INSERT ON card_statement_section_observations
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM card_statement_sections cs
    JOIN card_statements s ON s.id = cs.card_statement_id
    JOIN normalized_documents n ON n.id = NEW.normalized_document_id
    WHERE cs.id = NEW.card_statement_section_id
      AND s.workspace_id = NEW.workspace_id
      AND s.document_id = NEW.document_id
      AND s.import_session_id = NEW.import_session_id
      AND s.normalized_document_id = NEW.normalized_document_id
      AND s.parser_profile_id = NEW.parser_profile_id
      AND s.parser_profile_version = NEW.parser_profile_version
      AND n.document_id = NEW.document_id
      AND n.import_session_id = NEW.import_session_id
  ) THEN RAISE(ABORT, 'card section observation relationship invalid') END;
END;

CREATE TRIGGER validate_card_transaction_evidence
BEFORE INSERT ON card_transaction_evidence
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM transactions t JOIN card_statements s ON s.id = NEW.card_statement_id
    WHERE t.id = NEW.transaction_id AND t.account_id = s.liability_account_id
      AND t.document_id = s.document_id AND t.import_session_id = s.import_session_id
      AND t.direction = NEW.liability_effect
  ) THEN RAISE(ABORT, 'card transaction relationship invalid') END;
  SELECT CASE WHEN NEW.instrument_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM card_instruments i JOIN card_statements s ON s.id = NEW.card_statement_id
    WHERE i.id = NEW.instrument_id AND i.liability_account_id = s.liability_account_id
  ) THEN RAISE(ABORT, 'card transaction instrument invalid') END;
END;

CREATE TRIGGER validate_v14_card_transaction_section
BEFORE INSERT ON card_transaction_evidence
WHEN NEW.document_scoped_section_id IS NOT NULL
 AND EXISTS (SELECT 1 FROM card_statement_sections WHERE card_statement_id = NEW.card_statement_id)
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM card_statement_sections cs
    WHERE cs.card_statement_id = NEW.card_statement_id
      AND cs.document_scoped_section_id = NEW.document_scoped_section_id
      AND (NEW.row_scope = 'account_level' OR cs.instrument_id = NEW.instrument_id)
  ) THEN RAISE(ABORT, 'card transaction section relationship invalid') END;
END;
"""
)

public let migrationV15 = Migration(
    version: 15,
    name: "Axis card observations and representation-neutral semantic events",
    sql: """
PRAGMA legacy_alter_table = ON;
DROP TRIGGER validate_card_source_identity;
DROP TRIGGER validate_card_statement_section_observation;
DROP TRIGGER validate_card_semantic_projection_event;
DROP TRIGGER validate_card_semantic_projection;
DROP TRIGGER validate_card_statement;

ALTER TABLE card_statement_summary_components RENAME TO card_statement_summary_components_v14;
CREATE TABLE card_statement_summary_components (
  id TEXT PRIMARY KEY, card_statement_id TEXT NOT NULL,
  component_code TEXT NOT NULL CHECK(component_code IN (
    'previous_balance', 'new_credits', 'new_debits', 'amount_billed', 'payment_received',
    'total_payment', 'credit_reversal', 'purchases', 'billed_installment', 'fees_charges',
    'new_balance', 'due_date', 'instrument_net_total', 'source_section_net_total',
    'axis_total_payment_due'
  )),
  money_currency TEXT, money_minor INTEGER, money_decimal TEXT, date_value DATE,
  UNIQUE(card_statement_id, component_code),
  CHECK((component_code = 'due_date' AND date_value IS NOT NULL AND money_currency IS NULL AND money_minor IS NULL AND money_decimal IS NULL) OR
        (component_code != 'due_date' AND date_value IS NULL AND money_currency IS NOT NULL AND money_minor IS NOT NULL AND money_decimal IS NOT NULL)),
  FOREIGN KEY(card_statement_id) REFERENCES card_statements(id) ON DELETE RESTRICT
);
INSERT INTO card_statement_summary_components SELECT * FROM card_statement_summary_components_v14;
DROP TABLE card_statement_summary_components_v14;

ALTER TABLE card_statements RENAME TO card_statements_v14;
CREATE TABLE card_statements (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  liability_account_id TEXT NOT NULL,
  document_id TEXT NOT NULL UNIQUE,
  import_session_id TEXT NOT NULL UNIQUE,
  normalized_document_id TEXT NOT NULL UNIQUE,
  parser_profile_id TEXT NOT NULL,
  parser_profile_version TEXT NOT NULL,
  statement_date DATE,
  statement_start_date DATE,
  statement_end_date DATE,
  selected_statement_month TEXT,
  statement_currency TEXT NOT NULL,
  source_row_count INTEGER NOT NULL CHECK(source_row_count > 0),
  reconciliation_rule_code TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  CHECK((statement_start_date IS NULL AND statement_end_date IS NULL) OR
        (statement_start_date IS NOT NULL AND statement_end_date IS NOT NULL AND statement_start_date <= statement_end_date)),
  CHECK(selected_statement_month IS NULL OR
        (length(selected_statement_month) = 7 AND substr(selected_statement_month, 5, 1) = '-' AND
         CAST(substr(selected_statement_month, 6, 2) AS INTEGER) BETWEEN 1 AND 12)),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(liability_account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT,
  FOREIGN KEY(normalized_document_id) REFERENCES normalized_documents(id) ON DELETE RESTRICT
);
INSERT INTO card_statements (
  id, workspace_id, liability_account_id, document_id, import_session_id, normalized_document_id,
  parser_profile_id, parser_profile_version, statement_date, statement_start_date, statement_end_date,
  selected_statement_month, statement_currency, source_row_count, reconciliation_rule_code, created_at
)
SELECT id, workspace_id, liability_account_id, document_id, import_session_id, normalized_document_id,
  parser_profile_id, parser_profile_version, statement_date, statement_start_date, statement_end_date,
  NULL, statement_currency, source_row_count, reconciliation_rule_code, created_at
FROM card_statements_v14;
DROP TABLE card_statements_v14;
CREATE INDEX idx_card_statement_current ON card_statements(workspace_id, liability_account_id, statement_end_date, statement_date, selected_statement_month);

ALTER TABLE card_statement_semantic_projections RENAME TO card_statement_semantic_projections_v14;
CREATE TABLE card_statement_semantic_projections (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  liability_account_id TEXT NOT NULL,
  card_statement_id TEXT NOT NULL UNIQUE,
  document_id TEXT NOT NULL UNIQUE,
  import_session_id TEXT NOT NULL UNIQUE,
  algorithm TEXT NOT NULL,
  digest TEXT NOT NULL CHECK(length(digest) = 64),
  institution_code TEXT NOT NULL,
  statement_family_code TEXT NOT NULL,
  parser_profile_id TEXT NOT NULL,
  parser_profile_version TEXT NOT NULL,
  statement_date DATE,
  statement_start_date DATE,
  statement_end_date DATE,
  selected_statement_month TEXT,
  cycle_month TEXT,
  native_currency TEXT NOT NULL,
  event_count INTEGER NOT NULL CHECK(event_count > 0),
  section_count INTEGER NOT NULL CHECK(section_count >= 0),
  reconciliation_rule_code TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  CHECK((algorithm = 'ledgerforge.axis-card-statement-multiset.sha256.v1' AND section_count = 0) OR
        (algorithm != 'ledgerforge.axis-card-statement-multiset.sha256.v1' AND section_count > 0)),
  CHECK((statement_start_date IS NULL AND statement_end_date IS NULL) OR
        (statement_start_date IS NOT NULL AND statement_end_date IS NOT NULL AND statement_start_date <= statement_end_date)),
  CHECK(selected_statement_month IS NULL OR
        (length(selected_statement_month) = 7 AND substr(selected_statement_month, 5, 1) = '-' AND
         CAST(substr(selected_statement_month, 6, 2) AS INTEGER) BETWEEN 1 AND 12)),
  CHECK(cycle_month IS NULL OR
        (length(cycle_month) = 7 AND substr(cycle_month, 5, 1) = '-' AND
         CAST(substr(cycle_month, 6, 2) AS INTEGER) BETWEEN 1 AND 12)),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(liability_account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
  FOREIGN KEY(card_statement_id) REFERENCES card_statements(id) ON DELETE RESTRICT,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE RESTRICT,
  FOREIGN KEY(import_session_id) REFERENCES import_sessions(id) ON DELETE RESTRICT
);
INSERT INTO card_statement_semantic_projections (
  id, workspace_id, liability_account_id, card_statement_id, document_id, import_session_id,
  algorithm, digest, institution_code, statement_family_code, parser_profile_id, parser_profile_version,
  statement_date, statement_start_date, statement_end_date, selected_statement_month, cycle_month,
  native_currency, event_count, section_count, reconciliation_rule_code, created_at
)
SELECT id, workspace_id, liability_account_id, card_statement_id, document_id, import_session_id,
  algorithm, digest, institution_code, statement_family_code, parser_profile_id, parser_profile_version,
  statement_date, statement_start_date, statement_end_date, NULL, NULL,
  native_currency, event_count, section_count, reconciliation_rule_code, created_at
FROM card_statement_semantic_projections_v14;
DROP TABLE card_statement_semantic_projections_v14;
CREATE INDEX idx_card_semantic_projection_period
  ON card_statement_semantic_projections(workspace_id, liability_account_id, statement_start_date, statement_end_date, cycle_month);

ALTER TABLE card_statement_semantic_groups RENAME TO card_statement_semantic_groups_v14;
CREATE TABLE card_statement_semantic_groups (
  id TEXT PRIMARY KEY,
  workspace_id TEXT NOT NULL,
  liability_account_id TEXT NOT NULL,
  institution_code TEXT NOT NULL,
  statement_family_code TEXT NOT NULL,
  statement_start_date DATE,
  statement_end_date DATE,
  cycle_month TEXT,
  native_currency TEXT NOT NULL,
  projection_algorithm TEXT NOT NULL,
  projection_digest TEXT NOT NULL CHECK(length(projection_digest) = 64),
  authoritative_projection_id TEXT NOT NULL UNIQUE,
  created_at DATETIME NOT NULL,
  CHECK((cycle_month IS NOT NULL AND statement_start_date IS NULL AND statement_end_date IS NULL) OR
        (cycle_month IS NULL AND statement_start_date IS NOT NULL AND statement_end_date IS NOT NULL AND statement_start_date <= statement_end_date) OR
        (cycle_month IS NULL AND statement_start_date IS NULL AND statement_end_date IS NULL AND
         projection_algorithm = 'ledgerforge.axis-card-statement-multiset.sha256.v1')),
  CHECK(cycle_month IS NULL OR
        (length(cycle_month) = 7 AND substr(cycle_month, 5, 1) = '-' AND
         CAST(substr(cycle_month, 6, 2) AS INTEGER) BETWEEN 1 AND 12)),
  FOREIGN KEY(workspace_id) REFERENCES workspaces(id) ON DELETE RESTRICT,
  FOREIGN KEY(liability_account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
  FOREIGN KEY(authoritative_projection_id) REFERENCES card_statement_semantic_projections(id) ON DELETE RESTRICT
);
INSERT INTO card_statement_semantic_groups (
  id, workspace_id, liability_account_id, institution_code, statement_family_code,
  statement_start_date, statement_end_date, cycle_month, native_currency, projection_algorithm,
  projection_digest, authoritative_projection_id, created_at
)
SELECT id, workspace_id, liability_account_id, institution_code, statement_family_code,
  statement_start_date, statement_end_date, NULL, native_currency, projection_algorithm,
  projection_digest, authoritative_projection_id, created_at
FROM card_statement_semantic_groups_v14;
DROP TABLE card_statement_semantic_groups_v14;
CREATE UNIQUE INDEX idx_card_semantic_group_period_identity
  ON card_statement_semantic_groups(workspace_id, liability_account_id, institution_code, statement_family_code, statement_start_date, statement_end_date, native_currency)
  WHERE cycle_month IS NULL;
CREATE UNIQUE INDEX idx_card_semantic_group_cycle_identity
  ON card_statement_semantic_groups(workspace_id, liability_account_id, institution_code, statement_family_code, cycle_month, native_currency)
  WHERE cycle_month IS NOT NULL;
CREATE UNIQUE INDEX idx_card_semantic_group_axis_digest_identity
  ON card_statement_semantic_groups(workspace_id, liability_account_id, institution_code, statement_family_code, native_currency, projection_algorithm, projection_digest)
  WHERE cycle_month IS NULL AND statement_start_date IS NULL AND statement_end_date IS NULL
    AND projection_algorithm = 'ledgerforge.axis-card-statement-multiset.sha256.v1';

ALTER TABLE card_statement_semantic_projection_events RENAME TO card_statement_semantic_projection_events_v14;
CREATE TABLE card_statement_semantic_projection_events (
  id TEXT PRIMARY KEY, projection_id TEXT NOT NULL, canonical_transaction_id TEXT,
  normalized_row_id TEXT NOT NULL, source_ordinal INTEGER NOT NULL CHECK(source_ordinal > 0),
  financial_date DATE NOT NULL,
  financial_date_role TEXT NOT NULL CHECK(financial_date_role IN ('transaction_date', 'posting_date')),
  source_transaction_date DATE,
  liability_effect TEXT NOT NULL CHECK(liability_effect IN ('card_increase_owed', 'card_decrease_owed')),
  posted_currency TEXT NOT NULL, posted_amount_minor INTEGER NOT NULL, posted_amount_decimal TEXT NOT NULL,
  original_currency TEXT, original_amount_minor INTEGER, original_amount_decimal TEXT,
  source_reference TEXT, row_scope TEXT NOT NULL CHECK(row_scope IN ('account_level', 'instrument_level')),
  document_scoped_section_id TEXT, document_section_ordinal INTEGER,
  UNIQUE(projection_id, source_ordinal),
  CHECK((row_scope = 'account_level' AND document_scoped_section_id IS NULL AND document_section_ordinal IS NULL) OR
        (row_scope = 'instrument_level' AND document_scoped_section_id IS NOT NULL AND document_section_ordinal IS NOT NULL)),
  CHECK((original_currency IS NULL AND original_amount_minor IS NULL AND original_amount_decimal IS NULL) OR
        (original_currency IS NOT NULL AND original_amount_minor IS NOT NULL AND original_amount_decimal IS NOT NULL)),
  FOREIGN KEY(projection_id) REFERENCES card_statement_semantic_projections(id) ON DELETE RESTRICT,
  FOREIGN KEY(canonical_transaction_id) REFERENCES transactions(id) ON DELETE RESTRICT,
  FOREIGN KEY(normalized_row_id) REFERENCES normalized_rows(id) ON DELETE RESTRICT
);
INSERT INTO card_statement_semantic_projection_events (
  id, projection_id, canonical_transaction_id, normalized_row_id, source_ordinal,
  financial_date, financial_date_role, source_transaction_date, liability_effect,
  posted_currency, posted_amount_minor, posted_amount_decimal, original_currency,
  original_amount_minor, original_amount_decimal, source_reference, row_scope,
  document_scoped_section_id, document_section_ordinal
)
SELECT id, projection_id, canonical_transaction_id, normalized_row_id, source_ordinal,
  posting_date, 'posting_date', source_transaction_date, liability_effect,
  posted_currency, posted_amount_minor, posted_amount_decimal, original_currency,
  original_amount_minor, original_amount_decimal, source_reference, row_scope,
  document_scoped_section_id, document_section_ordinal
FROM card_statement_semantic_projection_events_v14;
DROP TABLE card_statement_semantic_projection_events_v14;
CREATE INDEX idx_card_semantic_event_transaction ON card_statement_semantic_projection_events(canonical_transaction_id, projection_id, source_ordinal);

CREATE TRIGGER validate_card_source_identity
BEFORE INSERT ON card_source_identity_observations
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM documents d JOIN import_sessions s ON s.id = d.import_session_id
    JOIN normalized_documents n ON n.document_id = d.id AND n.import_session_id = s.id
    WHERE d.id = NEW.document_id AND s.id = NEW.import_session_id
      AND n.id = NEW.normalized_document_id AND d.workspace_id = NEW.workspace_id
      AND n.profile_id = NEW.parser_profile_id AND n.profile_version = NEW.parser_profile_version
  ) THEN RAISE(ABORT, 'card observation source relationship invalid') END;
  SELECT CASE WHEN NEW.subject_kind = 'liability_account' AND NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.id = NEW.subject_id AND a.workspace_id = NEW.workspace_id AND a.account_type = 'credit_card'
  ) THEN RAISE(ABORT, 'card observation liability account invalid') END;
  SELECT CASE WHEN NEW.subject_kind = 'instrument' AND NOT EXISTS (
    SELECT 1 FROM card_instruments i WHERE i.id = NEW.subject_id AND i.workspace_id = NEW.workspace_id
  ) THEN RAISE(ABORT, 'card observation instrument invalid') END;
END;

CREATE TRIGGER validate_card_statement_section_observation
BEFORE INSERT ON card_statement_section_observations
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM card_statement_sections cs
    JOIN card_statements s ON s.id = cs.card_statement_id
    JOIN normalized_documents n ON n.id = NEW.normalized_document_id
    WHERE cs.id = NEW.card_statement_section_id AND s.workspace_id = NEW.workspace_id
      AND s.document_id = NEW.document_id AND s.import_session_id = NEW.import_session_id
      AND s.normalized_document_id = NEW.normalized_document_id
      AND s.parser_profile_id = NEW.parser_profile_id AND s.parser_profile_version = NEW.parser_profile_version
      AND n.document_id = NEW.document_id AND n.import_session_id = NEW.import_session_id
  ) THEN RAISE(ABORT, 'card section observation relationship invalid') END;
END;

CREATE TRIGGER validate_card_statement
BEFORE INSERT ON card_statements
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.id = NEW.liability_account_id
      AND a.workspace_id = NEW.workspace_id AND a.account_type = 'credit_card'
  ) THEN RAISE(ABORT, 'card statement liability account invalid') END;
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM documents d JOIN import_sessions s ON s.id = d.import_session_id
    JOIN normalized_documents n ON n.document_id = d.id AND n.import_session_id = s.id
    WHERE d.id = NEW.document_id AND s.id = NEW.import_session_id
      AND n.id = NEW.normalized_document_id AND d.workspace_id = NEW.workspace_id
      AND n.profile_id = NEW.parser_profile_id AND n.profile_version = NEW.parser_profile_version
  ) THEN RAISE(ABORT, 'card statement source relationship invalid') END;
END;

CREATE TRIGGER validate_card_semantic_projection
BEFORE INSERT ON card_statement_semantic_projections
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM card_statements s
    WHERE s.id = NEW.card_statement_id
      AND s.workspace_id = NEW.workspace_id
      AND s.liability_account_id = NEW.liability_account_id
      AND s.document_id = NEW.document_id
      AND s.import_session_id = NEW.import_session_id
      AND s.statement_date IS NEW.statement_date
      AND s.statement_start_date IS NEW.statement_start_date
      AND s.statement_end_date IS NEW.statement_end_date
      AND s.selected_statement_month IS NEW.selected_statement_month
      AND s.statement_currency = NEW.native_currency
      AND s.parser_profile_id = NEW.parser_profile_id
      AND s.parser_profile_version = NEW.parser_profile_version
  ) THEN RAISE(ABORT, 'card semantic projection relationship invalid') END;
  SELECT CASE WHEN NEW.algorithm = 'ledgerforge.amex-card-statement-semantic.sha256.v1'
    AND (NEW.statement_date IS NULL OR NEW.statement_start_date IS NULL OR NEW.statement_end_date IS NULL OR NEW.cycle_month IS NOT NULL)
    THEN RAISE(ABORT, 'Amex semantic projection requires exact period') END;
END;

CREATE TRIGGER validate_card_semantic_projection_event
BEFORE INSERT ON card_statement_semantic_projection_events
BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM card_statement_semantic_projections p
    JOIN normalized_rows r ON r.id = NEW.normalized_row_id
    JOIN normalized_documents n ON n.id = r.normalized_document_id
    WHERE p.id = NEW.projection_id AND n.document_id = p.document_id
      AND n.import_session_id = p.import_session_id
  ) THEN RAISE(ABORT, 'card semantic event source relationship invalid') END;
  SELECT CASE WHEN NEW.canonical_transaction_id IS NULL AND NOT EXISTS (
    SELECT 1 FROM card_statement_semantic_projections p
    WHERE p.id = NEW.projection_id AND p.algorithm = 'ledgerforge.axis-card-statement-multiset.sha256.v1'
  ) THEN RAISE(ABORT, 'unbound semantic event is not permitted for this algorithm') END;
  SELECT CASE WHEN NEW.canonical_transaction_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM card_statement_semantic_projections p
    JOIN transactions t ON t.id = NEW.canonical_transaction_id
    WHERE p.id = NEW.projection_id AND t.account_id = p.liability_account_id
      AND t.posted_date = NEW.financial_date AND t.financial_date_role = NEW.financial_date_role
  ) THEN RAISE(ABORT, 'card semantic event canonical relationship invalid') END;
END;

CREATE TRIGGER validate_card_semantic_authoritative_bindings
BEFORE INSERT ON card_statement_semantic_members
WHEN NEW.role = 'authoritative'
BEGIN
  SELECT CASE WHEN EXISTS (
    SELECT 1 FROM card_statement_semantic_projection_events e
    WHERE e.projection_id = NEW.projection_id AND e.canonical_transaction_id IS NULL
  ) THEN RAISE(ABORT, 'authoritative semantic projection contains unbound event') END;
END;

PRAGMA legacy_alter_table = OFF;
""",
    preflightChecks: [],
    requiresForeignKeysDisabled: true
)

public let allMigrations: [Migration] = [migrationV1, migrationV2, migrationV3, migrationV4, migrationV5, migrationV6, migrationV7, migrationV8, migrationV9, migrationV10, migrationV11, migrationV12, migrationV13, migrationV14, migrationV15]

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
        let preflightSource = preflightChecks.isEmpty ? "" : preflightChecks.map(\.issueCode).joined(separator: "\n") + "\n"
        let executionSource = requiresForeignKeysDisabled ? "requires_foreign_keys_disabled\n" : ""
        let source = executionSource + preflightSource + sql
        guard let data = source.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
