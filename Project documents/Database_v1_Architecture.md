<!-- Project documents/Database_v1_Architecture.md -->

# LedgerForge — Database v1 Architecture (Design Proposal)

Status: Proposal for Sprint 10 Phase 2A (architecture-only)

Summary

This document defines the LedgerForge Database v1 architecture. It is a vendor-neutral, SQLite-targeted design that fulfills the project's ADRs, Architecture_v1.0, Product Vision and Engineering Standards. The design prioritizes:

- Preservation of imported financial truth and native currency (ADR-008)
- Validation-before-persistence (ADR-010)
- Format-independence (ADR-011)
- Traceability and auditability for every imported value (ADR-004, ADR-007)
- Extensibility for future features (ExchangeRateStore, Money type, synchronization)

-Top-level goals

- Provide a schema that maps Document Reader outputs (PDF, CSV, XLS/XLSX, TXT) into a single canonical ingestion model (normalized_documents + normalized_rows).
- Enable deterministic statement fingerprinting and deduplication.
- Persist validation metadata so only validated imports become trusted application data (transactions marked trusted).
- Preserve native currency at every level and store exchange rates separately and versioned.
- Support efficient queries for dashboards and full-text search for payee/description.
- Clearly separate Source Truth, Derived Data and Presentation throughout the persistence layer.

## Import Coordination

LedgerForge uses an ImportCoordinator as the orchestration layer for every financial document import.

The ImportCoordinator is responsible for:
- Receiving import requests.
- Resolving optional passwords through PasswordProvider.
- Selecting the appropriate Document Reader.
- Invoking the selected Document Reader.
- Creating ImportSessions.
- Coordinating Institution Detection.
- Coordinating Document Classification.
- Selecting the appropriate Import Profile.
- Coordinating Validation.
- Persisting validated domain objects.
- Reporting progress to the user interface.

The ImportCoordinator never performs parsing, validation or business logic itself. It coordinates independent architectural components.

## Financial Truth

LedgerForge separates financial information into three layers:

Source Truth

↓

Derived Data

↓

Presentation

Source Truth consists of imported financial information and is immutable.

Derived Data consists of validation results, fingerprints, exchange-rate calculations and future analytical models. It may be regenerated whenever necessary.

Presentation consists of dashboard calculations, currency conversion, reporting preferences and UI state.

Every architectural decision must preserve this separation.

Checklist — what this proposal contains

- Every required table and a description of its purpose
- Columns, primary keys, foreign keys and recommended types
- Indexes and full-text search recommendations
- Entity relationships (ER summary)
- Future-proofing and JSON metadata choices
- Migration strategy and schema_migrations guidance
- How imported documents map to accounts and transactions
- Multi-currency support details
- Canonical mapping for PDF, CSV, XLS/XLSX, TXT → normalized model
- Validation metadata storage and workflow mapping
- Detailed statement fingerprinting algorithm and schema
- Security, operational and testing notes

Important design conventions

- Use UUID (TEXT) primary keys for domain entities for offline-first portability and easier sync/merge later.
- Preserve exact imported values: store amount_decimal (TEXT) for audit and amount_minor (INTEGER) for efficient numeric queries. The conversion uses currencies.minor_unit.
- Use JSON columns for flexible structured metadata where schema evolution or vendor-specific data is expected (normalized_json, profile metadata, validation_summary).
- Immutable, append-only patterns for exchange_rates, import_sessions and fingerprints to preserve audit history.

I. Schema (tables, columns, PKs, FKs, indexes)

For each table below: I show the purpose, columns (with recommended types), primary key, foreign keys and suggested indexes.

1) workspaces
- Purpose: support multi-workspace or multi-profile usage on-device.
- Columns:
  - id TEXT PRIMARY KEY -- UUID
  - name TEXT NOT NULL
  - created_at DATETIME NOT NULL
  - updated_at DATETIME
- Indexes: PRIMARY KEY (id)
- Notes: All domain tables include `workspace_id` foreign key where appropriate.

2) institutions
- Purpose: canonical registry of detected institutions.
- Columns:
  - id TEXT PRIMARY KEY -- UUID
  - code TEXT UNIQUE -- canonical short code (e.g., "axis")
  - name TEXT
  - country TEXT
  - created_at DATETIME
- Indexes: UNIQUE(code)

3) import_profiles
- Purpose: represent Import Profiles (layouts/versioned parsers) (ADR-005)
- Columns:
  - id TEXT PRIMARY KEY -- UUID
  - institution_id TEXT REFERENCES institutions(id) ON DELETE SET NULL
  - name TEXT
  - version TEXT
  - canonical_signature TEXT -- optional compact layout signature
  - metadata JSON -- column mapping, hints
  - created_at DATETIME
- Indexes: (institution_id), (name, version)
- Notes: Immutable per-version; new profile versions insert new rows.

Parser selection considers:

Institution
↓

Document Type
↓

Layout Version
↓

Parser Version

Parser versions are immutable.

New statement layouts create new parser versions rather than modifying historical parser behaviour.

4) documents
- Purpose: metadata for original uploaded files (one row per physical file)
- Columns:
  - id TEXT PRIMARY KEY -- UUID
  - workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE
  - import_session_id TEXT REFERENCES import_sessions(id) ON DELETE SET NULL
  - filename TEXT NOT NULL
  - mime_type TEXT
  - size_bytes INTEGER
  - sha256 TEXT NOT NULL
  - storage_path TEXT -- app-managed path/URI
  - extracted_text_snippet TEXT -- optional
  - page_count INTEGER
  - statement_start_date DATE
  - statement_end_date DATE
  - document_type TEXT
  - created_at DATETIME NOT NULL
- Indexes:
  - UNIQUE(sha256)
  - (import_session_id)
  - (workspace_id)
- Notes: Prefer storing file blob on disk and reference path; keep sha256 to detect identical files.

Recommended `document_type` values:

- bank_statement
- credit_card_statement
- brokerage_statement
- insurance_statement
- salary_statement
- tax_document
- unknown

5) document_fingerprints
- Purpose: deterministic statement fingerprinting for duplicate detection
- Columns:
  - id TEXT PRIMARY KEY -- UUID
  - document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE
  - import_session_id TEXT REFERENCES import_sessions(id) ON DELETE SET NULL
  - algorithm TEXT NOT NULL -- name of fingerprint algorithm
  - fingerprint TEXT NOT NULL
  - fingerprint_data JSON -- canonical data used to build fingerprint
  - created_at DATETIME NOT NULL
- Indexes:
  - UNIQUE(algorithm, fingerprint)
  - (document_id)
- Notes: Used to mark duplicates and prevent duplicate trusted imports.

6) import_sessions
- Purpose: central record for each import attempt and authoritative validation metadata (ADR-010)
- Columns:
  - id TEXT PRIMARY KEY -- UUID
  - workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE
  - user_visible_name TEXT
  - started_at DATETIME NOT NULL
  - completed_at DATETIME
  - importer_version TEXT
  - reader_version TEXT
  - parser_version TEXT
  - layout_version TEXT
  - source_filename TEXT
  - num_documents INTEGER
  - normalized_rows_count INTEGER
  - parsed_transactions_count INTEGER
  - validation_status TEXT NOT NULL CHECK (validation_status IN ('pending','passed','failed','warning'))
  - validation_summary JSON -- aggregated counts, totalsByCurrency etc.
  - validation_score REAL
  - created_at DATETIME NOT NULL
  - updated_at DATETIME
- Indexes: (workspace_id), (started_at)
- Notes: UI and services read this table to decide whether to mark transactions trusted. Only when validation_status='passed' should transactions be considered trusted for dashboards.

These traceability columns (`reader_version`, `parser_version`, `layout_version`) are intended for long-term parser traceability and debugging: they allow an import session to be associated with the exact reader/parser/layout versions used to produce the normalized output and parsed candidates.

7) normalized_documents
- Purpose: persistent canonical representation of Document Reader output (RawDocument) (ADR-011)
- Columns:
  - id TEXT PRIMARY KEY -- UUID
  - import_session_id TEXT NOT NULL REFERENCES import_sessions(id) ON DELETE CASCADE
  - document_id TEXT REFERENCES documents(id) ON DELETE SET NULL
  - normalized_json JSON NOT NULL -- canonical RawDocument
  - schema_version TEXT
  - primary_language TEXT
  - created_at DATETIME
- Indexes: (import_session_id)
- Notes: Normalized_documents preserve reader output independent of parser.

8) normalized_rows
- Purpose: store per-row normalized data that parsers consume and used for traceability
- Columns:
  - id TEXT PRIMARY KEY -- UUID
  - normalized_document_id TEXT NOT NULL REFERENCES normalized_documents(id) ON DELETE CASCADE
  - row_index INTEGER NOT NULL
  - row_original JSON NOT NULL -- keyed by normalized column names
  - extracted_text TEXT -- OCR cell text
  - created_at DATETIME
- Indexes: UNIQUE(normalized_document_id, row_index)
- Notes: Fundamental for audit, fingerprinting, and row-level validation.

9) accounts
- Purpose: canonical ledger accounts (AccountStore ownership) (ADR-013)
- Columns:
  - id TEXT PRIMARY KEY -- UUID
  - workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE
  - name TEXT NOT NULL
  - institution_id TEXT REFERENCES institutions(id) ON DELETE SET NULL
  - account_type TEXT -- enum: bank, credit_card, brokerage, salary, cash, liability, etc.
  - native_currency TEXT NOT NULL REFERENCES currencies(code)
  - description TEXT
  - created_at DATETIME NOT NULL
  - closed_at DATETIME
  - created_from_import_session_id TEXT REFERENCES import_sessions(id)
- Indexes: (workspace_id), (institution_id), (native_currency)
- Notes: Parsers should provide stable identifiers where possible; otherwise, use account_identifiers and human-in-the-loop merges.

10) account_identifiers
- Purpose: external identifiers (masked PAN, IBAN, institution_id) to support deterministic matching and merging
- Columns:
  - id TEXT PRIMARY KEY
  - account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE
  - scheme TEXT NOT NULL -- e.g., 'masked_pan','iban','institution_account_id'
  - identifier TEXT NOT NULL -- normalized identifier
  - provenance JSON -- (document_id, parser, profile_id)
  - created_at DATETIME NOT NULL
- Indexes: (scheme, identifier)
- Notes: Use to resolve accounts across imports.

11) transactions
- Purpose: canonical parsed transactions owned by TransactionStore (ADR-013). Transactions keep native currency and are flagged trusted only after validation.
- Columns:
  - id TEXT PRIMARY KEY -- UUID
  - workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE
  - account_id TEXT REFERENCES accounts(id) ON DELETE SET NULL
  - import_session_id TEXT REFERENCES import_sessions(id) ON DELETE SET NULL
  - document_id TEXT REFERENCES documents(id) ON DELETE SET NULL
  - original_row_id TEXT REFERENCES normalized_rows(id) ON DELETE SET NULL
  - posted_date DATE NOT NULL
  - value_date DATE
  - description TEXT
  - payee TEXT
  - reference TEXT
  - native_currency TEXT NOT NULL REFERENCES currencies(code)
  - amount_minor INTEGER NOT NULL -- signed (minor units)
  - amount_decimal TEXT NOT NULL -- exact imported decimal
  - direction TEXT NOT NULL CHECK (direction IN ('credit','debit'))
  - running_balance_minor INTEGER
  - is_reconciled INTEGER DEFAULT 0
  - is_trusted INTEGER DEFAULT 0 -- set only after import_session validation passes
  - trusted_at DATETIME
  - created_at DATETIME NOT NULL
  - updated_at DATETIME
- Indexes:
  - idx_transactions_account_date (workspace_id, account_id, posted_date)
  - idx_transactions_import (workspace_id, import_session_id)
  - idx_transactions_account_date_amount (account_id, posted_date, amount_minor)
- Notes: Dashboards must query only is_trusted=1 rows for authoritative metrics.

12) transaction_raw_rows
- Purpose: mapping from transaction → normalized_rows used to construct it (1-to-many).
- Columns:
  - id TEXT PRIMARY KEY
  - transaction_id TEXT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE
  - normalized_row_id TEXT NOT NULL REFERENCES normalized_rows(id) ON DELETE CASCADE
  - contribution_type TEXT -- 'amount','date','description' etc.
  - created_at DATETIME
- Indexes: (transaction_id), (normalized_row_id)
- Notes: Immutable mapping for full auditability.

13) validation_issues
- Purpose: per-import / per-row / per-transaction validation problem records (ADR-010)
- Columns:
  - id TEXT PRIMARY KEY
  - import_session_id TEXT NOT NULL REFERENCES import_sessions(id) ON DELETE CASCADE
  - normalized_row_id TEXT REFERENCES normalized_rows(id) ON DELETE SET NULL
  - transaction_candidate_id TEXT REFERENCES transactions(id) ON DELETE SET NULL
  - severity TEXT NOT NULL CHECK (severity IN ('error','warning','info'))
  - code TEXT NOT NULL -- machine-readable code (e.g., ROW_MISSING_DATE)
  - message TEXT NOT NULL
  - field TEXT -- optional
  - created_at DATETIME NOT NULL
- Indexes: (import_session_id, severity), (normalized_row_id)
- Notes: import_sessions.validation_summary aggregates these issues.

14) exchange_rates
- Purpose: versioned, auditable exchange rates (ADR-008)
- Columns:
  - id TEXT PRIMARY KEY
  - workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE
  - base_currency TEXT NOT NULL REFERENCES currencies(code)
  - quote_currency TEXT NOT NULL REFERENCES currencies(code)
  - rate_decimal TEXT NOT NULL -- exact decimal string
  - rate_factor_numerator INTEGER -- optional
  - rate_factor_denominator INTEGER -- optional
  - valid_at DATETIME NOT NULL -- timestamp the rate is valid at
  - source TEXT -- optional (provider)
  - import_session_id TEXT REFERENCES import_sessions(id)
  - created_at DATETIME NOT NULL
- Indexes: (workspace_id, base_currency, quote_currency, valid_at)
- Notes: Immutable; insert-only for version history.

15) currencies
- Purpose: ISO 4217 metadata and minor unit exponent
- Columns:
  - code TEXT PRIMARY KEY -- e.g., 'INR'
  - numeric_code INTEGER
  - name TEXT
  - minor_unit INTEGER NOT NULL -- exponent (2 for cents)
  - decimal_places INTEGER NOT NULL
- Notes: Used to convert amount_decimal ↔ amount_minor.

16) account_balance_snapshots
- Purpose: snapshot account balances for quick historical queries
- Columns:
  - id TEXT PRIMARY KEY
  - account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE
  - snapshot_date DATE NOT NULL
  - balance_minor INTEGER NOT NULL
  - currency_code TEXT NOT NULL REFERENCES currencies(code)
  - source_import_session_id TEXT REFERENCES import_sessions(id)
  - created_at DATETIME NOT NULL
- Indexes: (account_id, snapshot_date)
- Notes: Snapshots must be derived from trusted transactions only.

17) rules
- Purpose: store automation rules and their provenance (read-only for imported transformation provenance)
- Columns:
  - id TEXT PRIMARY KEY
  - workspace_id TEXT
  - name TEXT
  - rule_json JSON
  - created_at DATETIME
- Notes: Rules must not alter imported truth; they create enrichment metadata only.

18) fts_transactions (FTS virtual table)
- Purpose: full-text search over description, payee, reference
- Columns:
  - transaction_id TEXT
  - description TEXT
  - payee TEXT
  - reference TEXT
- Notes: Implement as SQLite FTS5 table with content=transactions for efficient search.

19) attachments
- Purpose: optional BLOBs (OCR images, thumbnails); prefer filesystem + references for large files
- Columns:
  - id TEXT PRIMARY KEY
  - document_id TEXT REFERENCES documents(id)
  - type TEXT
  - blob BLOB
  - created_at DATETIME
- Notes: Avoid in-DB large binary storage unless necessary; prefer file storage + encryption.

20) schema_migrations
- Purpose: track migrations to support safe upgrades
- Columns:
  - id INTEGER PRIMARY KEY AUTOINCREMENT
  - version INTEGER NOT NULL
  - name TEXT
  - applied_at DATETIME NOT NULL
  - checksum TEXT
- Notes: Tools must record migration application to support safe upgrades.

II. Relationships (ER summary)

- workspace 1 — * import_sessions
- import_session 1 — * documents
- import_session 1 — * normalized_documents
- normalized_document 1 — * normalized_rows
- normalized_row 1 — * transaction_raw_rows
- import_session 1 — * transactions
- document 1 — * document_fingerprints
- account 1 — * account_identifiers
- account 1 — * transactions
- transactions 1 — * transaction_raw_rows
- import_session 1 — * validation_issues
- workspace 1 — * exchange_rates

III. How imported documents map into accounts & transactions (traceability)

1. User triggers import → create `import_sessions` row (validation_status='pending').
2. For each uploaded file, create `documents` row with sha256 and storage_path.
3. Document Reader extracts the file into RawDocument.
4. Normalization produces FinancialDocument and persists normalized_documents and normalized_rows.
5. Institution detection, classification and parser selection determine the Import Profile before parsing creates candidate transactions.
6. ImportValidator runs, writes `validation_issues` and computes `validation_summary`.
7. Update `import_sessions.validation_status` to 'passed' / 'failed' / 'warning'.
8. If 'passed': mark associated transactions `is_trusted=1` and set `trusted_at`. Create/match `accounts` using `account_identifiers`; set `created_from_import_session_id` for provenance.
9. Dashboard and reports query only `transactions WHERE is_trusted=1` to guarantee ADR-010 compliance.

IV. Multi-currency support

- Every monetary value retains its native currency (`transactions.native_currency`, `accounts.native_currency`).
- Store `amount_decimal` (TEXT) exactly as parsed for audit and `amount_minor` (INTEGER) for efficient arithmetic using `currencies.minor_unit`.
- Exchange rates are stored in `exchange_rates` and are versioned and time-bound (valid_at). Conversion is a presentation concern: reports query the appropriate rate at the relevant historical timestamp.
- For aggregate multi-currency reports, the system groups by `native_currency` and uses `exchange_rates` to compute converted values at display time.

## Password Resolution

Password management is outside the responsibility of Document Readers.

Encrypted financial documents are unlocked before extraction using institution-specific credentials stored securely within the operating system's secure credential storage.

Document Readers always receive either an already-accessible document or the resolved password required to open it.

Document Readers never perform decryption.

If no stored credential succeeds, LedgerForge prompts the user once.

Successful credentials update the stored password profile.

## OCR Strategy

PDF Document Readers first determine whether a document contains extractable text.

Pipeline:

PDF
↓

Extractable text?

├── Yes → Text Extraction

└── No → OCR

↓

FinancialDocument

↓

Normal import pipeline

OCR remains an implementation detail of the Document Reader.

Downstream components remain unaware of whether OCR was required.

V. Format-independence: PDF, CSV, XLS/XLSX, TXT mapping

- Document Readers convert each supported file format into RawDocument.
- Normalization converts RawDocument into the canonical FinancialDocument used by parsers.
- normalized_rows persist the canonical row representation so downstream parsers, validators and stores operate identically regardless of file format.
- `documents` preserves original file-level metadata for audit.

VI. Validation metadata storage & workflow (ADR-010)

- `import_sessions.validation_status` — authoritative import outcome (pending/passed/failed/warning).
- `validation_issues` — fine-grained issues linked to rows or transaction candidates.
- `import_sessions.validation_summary` — aggregated counts and totals by currency for quick UI summary.
- Transactions created before validation remain `is_trusted=0`. When an import passes validation, the ImportEngine (or persistence coordinator) atomically marks relevant transactions `is_trusted=1` and records `trusted_at`.

VII. Statement fingerprinting to avoid duplicates

Design goals:
- Deterministically identify exact duplicates across formats and re-exports.
- Provide fingerprint_data to support future fuzzy-matching algorithms.

Recommended algorithm (canonical, upgradeable):
1. Canonical inputs: institution_code (detector), canonical account identifier (parser-provided or masked number), min_date, max_date, normalized row signatures.
2. Row signature: normalize whitespace, unicode normalization, lowercased description, normalize numbers into a standard decimal string using `amount_decimal` and dates to ISO format, produce `date|amount_decimal|normalized_description`.
3. Sort row signatures deterministically (by date, amount, description) and concat them into a buffer.
4. rows_checksum = SHA256(concat_row_signatures).
5. fingerprint_payload = institution_code + '|' + account_identifier + '|' + min_date + '|' + max_date + '|' + row_count + '|' + rows_checksum
6. fingerprint = SHA256(fingerprint_payload)

Store the fingerprint in `document_fingerprints` with algorithm='v1:normalized-rows-sha256' and fingerprint_data includes rows_checksum and provenance.

Deduplication policy:
- If (algorithm,fingerprint) exists for a trusted import in the same workspace, mark the new import as duplicate and set `import_sessions.validation_status='failed'` (or 'warning' per UX policy) and link to original import_session. Optionally present user the option to merge/ignore.
- For near-duplicates, implement LSH/MinHash in the app layer using `fingerprint_data` for fuzzy matching and surface as potential duplicates.

VIII. Indexing & performance

- Transactions: index `(workspace_id, account_id, posted_date)` and `(account_id, posted_date, amount_minor)` for timeline and range queries.
- Documents: UNIQUE index on `sha256` for exact-file dedupe.
- Document fingerprints: UNIQUE on `(algorithm, fingerprint)` to prevent duplicate insertion.
- Normalized_rows: UNIQUE(normalized_document_id, row_index).
- Account identifiers: index on `(scheme, identifier)` for fast account resolution.
- Exchange rates: index `(workspace_id, base_currency, quote_currency, valid_at)`.
- Full-text search: use an FTS5 virtual table for transactions' description, payee and reference fields.
- For heavy analytical queries, create covering indexes as needed (e.g., networth by currency pre-aggregates) or use materialized views / snapshots (`account_balance_snapshots`).

IX. Future-proofing decisions

- Append-only and versioned records: exchange_rates, import_profiles, import_sessions and fingerprints are append-only to preserve auditability.
- JSON metadata fields: allow schema evolution without constant DDL changes (normalized_json, import_profiles.metadata, import_sessions.validation_summary, fingerprint_data).
- UUID PKs: useful for offline, sync and cross-platform portability.
- Schema_version fields where content structure may change (normalized_documents.schema_version).
- Additive migrations: prefer adding new columns/tables and backfilling data in background jobs.
- Keep Document Reader output persisted (normalized_documents + normalized_rows) so automated re-parsing or later parser improvements can be applied without needing original file re-ingestion.

X. Migration strategy

- Use a `schema_migrations` table to record applied migrations.
- Migration rules:
  - Minor releases: additive changes only (new tables/columns/indexes) and background backfills.
  - Major releases: prepare migration scripts that create new tables, copy transformed data, test, then swap.
  - Always back up DB before running destructive migrations.
- Example migration pattern for adding `amount_minor`:
  1. Add column `amount_minor` (nullable).
  2. Launch background job that reads transactions.amount_decimal and currencies.minor_unit and writes computed amount_minor.
  3. After verification, make application rely on amount_minor and optionally mark column NOT NULL in a controlled migration.
- Testing: maintain a migration test suite that contains sample DBs for each previous release and tests the upgrade path.

## SQLite Configuration

LedgerForge configures SQLite using production-safe defaults.

Recommended configuration:

- WAL journaling
- Foreign key enforcement enabled
- Busy timeout configured
- Prepared statements
- Parameterized queries only
- Background write queue

These settings are mandatory for production builds.

XI. Security & privacy

- Sensitive files (PDFs) should be stored encrypted on disk. Use OS-level secure storage APIs (Keychain/KeyStore) or SQLCipher for DB encryption in later phases.
- Mask or encrypt personally identifiable fields where possible (full account numbers). Use `account_identifiers.provenance` to record which document provided the identifier.
- Restrict metadata and document file access to the local user; backups / exports must be explicit and clearly indicated.

XII. Operational considerations

- Backups & exports: provide an export format that includes normalized_documents and transactions to enable restoration and debugging.
- Retention & archival: allow configuration to archive or purge normalized_documents/normalized_rows older than N years while preserving transactions and essential provenance.
- Concurrency: SQLite supports serialized writes; repository adapters should perform writes on background queues and batch updates.
- Performance: use snapshots (`account_balance_snapshots`) for heavy dashboard queries; precompute aggregates offline.

XIII. Reconciliation and user edits (auditability)

- User edits must not overwrite original normalized data. Instead:
  - Record corrections in a corrections/audit table referencing transaction_id with change_json and user_id, or
  - Insert a compensating transaction with provenance marking it as user-correction.
- Keep original transactions and normalized_rows for forensic inspection.

XIV. Example SQL snippets (illustrative)

-- Transactions (illustrative)

CREATE TABLE transactions (
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
  updated_at DATETIME
);
CREATE INDEX idx_transactions_account_date ON transactions (workspace_id, account_id, posted_date);

-- Document fingerprints (illustrative)
CREATE TABLE document_fingerprints (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  import_session_id TEXT,
  algorithm TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  fingerprint_data JSON,
  created_at DATETIME NOT NULL,
  UNIQUE(algorithm, fingerprint)
);

XV. Testing & verification recommendations

- Maintain approved CSV and PDF reference fixtures for every supported institution. Verify identical financial truth across equivalent formats, ensure RawDocument extraction remains stable, FinancialDocument normalization is deterministic, parsers generate expected transactions, validation detects expected issues, and only trusted transactions reach dashboards.
- Add unit tests for fingerprinting: identical normalized inputs must produce identical fingerprints; minor benign whitespace changes should not change fingerprint if normalization rules say so.
- Add migration tests for every schema change using sample DBs representing previous versions.

XVI. Rationale: explanation of key design decisions

1. Preserve native values and store amount_decimal (TEXT) + amount_minor (INTEGER)
   - Why: To fully preserve imported financial truth (no rounding or conversion loss) and to enable efficient numeric queries.
2. Normalized_documents + normalized_rows
   - Why: Document Readers vary by format; normalizing early into a canonical model makes parsers and validators format-agnostic and increases maintainability (ADR-011).
3. Fingerprinting based on normalized rows
   - Why: Identifies duplicates independent of file format and minor layout differences; fingerprint_data supports fuzzy matching later.
4. Transactions can exist pre-validation but are not trusted until validation passes
   - Why: Allows UI/UX to preview parsed candidates while enforcing ADR-010: dashboards use only validated/trusted transactions.
5. Exchange rates as an append-only versioned table
   - Why: Enables historical, auditable conversion and avoids overwriting past rates used in historical reports.
6. Use JSON metadata fields
   - Why: Reduce schema churn and permit storing parsing hints, profile definitions and normalized payloads that can evolve.
7. UUID primary keys
   - Why: Support offline-first workflows and future synchronization; reduce risk with merges and reconciliations.

XVII. Risks and mitigations

- Large DB size due to normalized row persistence
  - Mitigation: compression, archival policies, optional purge of raw normalized rows after a retention period while preserving transactions + essential provenance.
- Duplicate handling and fingerprint collision
  - Mitigation: store fingerprint_data, use deterministic normalization rules, present fuzzy-match UI for ambiguous cases.
- Migration complexity for Money type introduction
  - Mitigation: keep amount_decimal as source-of-truth; backfill derived fields and migrate in background jobs.

XVIII. Next steps (recommended)

1. Produce exact SQL DDL (SQLite-ready) for the schema described here. Ensure types/constraints are compatible with SQLite semantics (not all RDBMS constraints are equal in SQLite).
2. Implement unit tests for fingerprint generation and validation issue storage.
3. Design repository adapter interfaces (already provided in Sprint 10 Phase 1) and a SQLite-backed provider in Phase 2B.
4. Prototype migration scripts for migrating existing in-memory data (transactions, accounts) into the new schema.
5. Create sample import fixtures and run full import → validate → persistence integration tests.

XIX. Appendix: canonical fields and conventions

- ID convention: all domain IDs are UUID v4 stored as TEXT.
- Timestamps: store in UTC in ISO-8601 strings (DATETIME). Use created_at/updated_at on all persistent rows.
- Currency minor unit: use `currencies.minor_unit` to derive minor units. Example: INR minor_unit=2 (paise), USD=2 (cents).
- Amount sign convention: amount_minor positive for credit into account, negative for debit (application must choose and document a consistent convention). Store explicit `direction` for clarity.
- Validation policy: only `is_trusted=1` transactions are included in dashboard calculations. `is_trusted` is set in one atomic step after import validation completes successfully.

XX. Deliverables checklist (for maintainers / reviewers)

- [ ] Approve schema intent and primary entities
- [ ] Request any additional domain fields required by institution-specific profiles
- [ ] Approve fingerprint algorithm or propose variations
- [ ] Approve migration strategy and testing plan
- [ ] Request DDL generation (SQLite-compatible)

End of proposal


--
Created for Sprint 10 Phase 2A (architecture-only). This document references ADR.md, Architecture_v1.0_Frozen.md, Engineering Standards.md and Product Vision.md as the authoritative design inputs.
