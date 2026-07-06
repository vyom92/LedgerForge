// Database/Migrations.swift
// Migration definitions for LedgerForge SQLite schema (Sprint 10 Phase 2B)

import Foundation

public struct Migration {
    public let version: Int
    public let name: String
    public let sql: String

    public init(version: Int, name: String, sql: String) {
        self.version = version
        self.name = name
        self.sql = sql
    }
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

public let allMigrations: [Migration] = [migrationV1]
