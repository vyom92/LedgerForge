<!-- Project documents/Implementation Reports/Sprint10_Phase2B_CodeAudit.md -->

# Sprint 10 Phase 2B — SQLite Architecture Code Audit

This audit reviews the Phase 2B SQLite foundation implementation against the approved
`Database_v1_Architecture.md`, relevant ADRs and the project's Engineering Standards.

Files inspected
- `Database/Migrations.swift`
- `Database/SQLiteDatabase.swift`
- `Database/SQLiteRepositoryProvider.swift`
- `Database/Repository.swift`
- `Project documents/Database_v1_Architecture.md`

Date: 2026-07-06

---

# Architecture Compliance

Summary

- The Phase 2B implementation implements the migration runner and Migration v1 SQL which closely follows
  the approved `Database_v1_Architecture.md` DDL. Primary domain tables are created (workspaces, documents,
  normalized_documents, normalized_rows, import_sessions, document_fingerprints, accounts, transactions, etc.).
- Repository interfaces are present and a `SQLiteRepositoryProvider` runs migrations at initialization.
- The implementation intentionally preserves the sprint scope: transaction persistence is deferred (placeholder
  `SQLiteTransactionRepo.replaceTransactions`), consistent with the documented constraints.

Compliance checklist (high level)
- Migration v1: IMPLEMENTED and recorded via `schema_migrations` — compliant.
- UUID/text PKs, amount_decimal as TEXT, normalized JSON storage: IMPLEMENTED — compliant.
- Validation-before-persistence (ADR-010): design supported by schema (import_sessions.validation_status, transactions.is_trusted), runner does not auto-mark transactions — compliant.
- Normalized documents & rows persisted: IMPLEMENTED — compliant.

Minor non-compliances (implementable improvements, not violations):
- SQLite runtime configuration (WAL, busy_timeout, synchronous) is not configured in code. See recommendations.
- Repositories build SQL via string interpolation and `escape()` rather than prepared statements — technical debt and security risk to remediate.

---

# Database Schema

The migration SQL in `migrationV1` creates the schema described in the architecture document. Below I list each table found in the migration SQL, its purpose (per the architecture doc), columns, PK, FKs and indexes observed in the implementation. I also call out anything missing or different.

- `schema_migrations`
  - Purpose: track applied migrations.
  - Columns: id INTEGER PK AUTOINCREMENT, version INTEGER NOT NULL, name TEXT, applied_at DATETIME NOT NULL, checksum TEXT
  - PK: id
  - FKs: none
  - Indexes: none
  - Notes: Implemented. `SQLiteDatabase.runMigrations` also creates this table if missing.

- `workspaces`
  - Purpose: multi-workspace support
  - Columns: id TEXT PK, name TEXT NOT NULL, created_at DATETIME NOT NULL, updated_at DATETIME
  - PK: id
  - FKs: none
  - Indexes: primary key

- `institutions`
  - Purpose: registry of detected institutions
  - Columns: id TEXT PK, code TEXT UNIQUE, name TEXT, country TEXT, created_at DATETIME
  - PK: id
  - FKs: none
  - Indexes: UNIQUE(code)

- `currencies`
  - Purpose: currency metadata
  - Columns: code TEXT PK, numeric_code INTEGER, name TEXT, minor_unit INTEGER NOT NULL, decimal_places INTEGER NOT NULL
  - PK: code

- `documents`
  - Purpose: original uploaded file metadata
  - Columns: id TEXT PK, workspace_id TEXT NOT NULL, import_session_id TEXT, filename TEXT NOT NULL, mime_type TEXT, size_bytes INTEGER, sha256 TEXT NOT NULL, storage_path TEXT, extracted_text_snippet TEXT, page_count INTEGER, created_at DATETIME NOT NULL
  - PK: id
  - FKs: workspace_id → workspaces(id) ON DELETE CASCADE
  - Indexes: UNIQUE(sha256); (import_session_id) not explicitly created, but the code creates unique index on sha256 only.
  - Note: The migration creates unique index `idx_documents_sha256`.

- `import_sessions`
  - Purpose: import attempt record and validation metadata
  - Columns include id TEXT PK, workspace_id TEXT NOT NULL, user_visible_name TEXT, started_at DATETIME NOT NULL, completed_at DATETIME, importer_version TEXT, source_filename TEXT, num_documents INTEGER, normalized_rows_count INTEGER, parsed_transactions_count INTEGER, validation_status TEXT NOT NULL, validation_summary TEXT (TEXT in migration — architecture preferred JSON), validation_score REAL, created_at DATETIME NOT NULL, updated_at DATETIME
  - PK: id
  - FKs: workspace_id → workspaces(id) ON DELETE CASCADE
  - Indexes: (workspace_id), (started_at) — not explicitly created in migration, but acceptable; architecture recommended indexes for import_sessions; consider adding them in a follow-up migration.
  - Note: `validation_summary` is TEXT in migration (schema uses TEXT instead of JSON affinity). SQLite supports JSON stored as TEXT; this is acceptable.

- `normalized_documents`
  - Purpose: canonical Reader output
  - Columns: id TEXT PK, import_session_id TEXT NOT NULL, document_id TEXT, normalized_json TEXT NOT NULL, schema_version TEXT, primary_language TEXT, created_at DATETIME
  - PK: id
  - FKs: import_session_id → import_sessions(id) ON DELETE CASCADE; document_id → documents(id) ON DELETE SET NULL
  - Indexes: (import_session_id) — not explicitly indexed; consider adding.

- `normalized_rows`
  - Purpose: per-row normalized data
  - Columns: id TEXT PK, normalized_document_id TEXT NOT NULL, row_index INTEGER NOT NULL, row_original TEXT NOT NULL, extracted_text TEXT, created_at DATETIME
  - PK: id
  - FKs: normalized_document_id → normalized_documents(id) ON DELETE CASCADE
  - Indexes: UNIQUE(normalized_document_id, row_index) — implemented as `idx_normalized_rows_doc_idx`.

- `document_fingerprints`
  - Purpose: statement fingerprinting
  - Columns: id TEXT PK, document_id TEXT NOT NULL, import_session_id TEXT, algorithm TEXT NOT NULL, fingerprint TEXT NOT NULL, fingerprint_data TEXT, created_at DATETIME NOT NULL
  - PK: id
  - FKs: document_id → documents(id) ON DELETE CASCADE
  - Indexes: UNIQUE(algorithm, fingerprint) — implemented as `idx_doc_fingerprint_unique`.

- `accounts`
  - Purpose: canonical ledger accounts
  - Columns: id TEXT PK, workspace_id TEXT NOT NULL, name TEXT NOT NULL, institution_id TEXT, account_type TEXT, native_currency TEXT NOT NULL, description TEXT, created_at DATETIME NOT NULL, closed_at DATETIME, created_from_import_session_id TEXT
  - PK: id
  - FKs: workspace_id → workspaces(id) ON DELETE CASCADE; institution_id → institutions(id) ON DELETE SET NULL
  - Indexes: (workspace_id), (institution_id), (native_currency) — not explicitly created; consider adding indexes in follow-up migration.

- `account_identifiers`
  - Purpose: external identifiers for account resolution
  - Columns: id TEXT PK, account_id TEXT NOT NULL, scheme TEXT NOT NULL, identifier TEXT NOT NULL, provenance TEXT, created_at DATETIME NOT NULL
  - PK: id
  - FKs: account_id → accounts(id) ON DELETE CASCADE
  - Indexes: idx_account_identifiers_scheme (scheme, identifier) implemented.

- `transactions`
  - Purpose: canonical parsed transactions
  - Columns: id TEXT PK, workspace_id TEXT NOT NULL, account_id TEXT, import_session_id TEXT, document_id TEXT, original_row_id TEXT, posted_date DATE NOT NULL, value_date DATE, description TEXT, payee TEXT, reference TEXT, native_currency TEXT NOT NULL, amount_minor INTEGER NOT NULL, amount_decimal TEXT NOT NULL, direction TEXT NOT NULL, running_balance_minor INTEGER, is_reconciled INTEGER DEFAULT 0, is_trusted INTEGER DEFAULT 0, trusted_at DATETIME, created_at DATETIME NOT NULL, updated_at DATETIME
  - PK: id
  - FKs: workspace_id → workspaces(id) ON DELETE CASCADE; account_id → accounts(id) ON DELETE SET NULL
  - Indexes: `idx_transactions_account_date` (workspace_id, account_id, posted_date) and `idx_transactions_import` implemented. Architecture also recommended `idx_transactions_account_date_amount` — not present in migration (can be added later).

- `transaction_raw_rows`
  - Purpose: mapping transaction → normalized_rows
  - Columns: id TEXT PK, transaction_id TEXT NOT NULL, normalized_row_id TEXT NOT NULL, contribution_type TEXT, created_at DATETIME
  - PK: id
  - FKs: transaction_id → transactions(id) ON DELETE CASCADE; normalized_row_id → normalized_rows(id) ON DELETE CASCADE

- `validation_issues`
  - Purpose: per-import validation problems
  - Columns: id TEXT PK, import_session_id TEXT NOT NULL, normalized_row_id TEXT, transaction_candidate_id TEXT, severity TEXT NOT NULL, code TEXT NOT NULL, message TEXT NOT NULL, field TEXT, created_at DATETIME NOT NULL
  - PK: id
  - FKs: import_session_id → import_sessions(id) ON DELETE CASCADE
  - Indexes: idx_validation_issues_import implemented.

- `exchange_rates`, `currencies`, `account_balance_snapshots`, `attachments`, `fts_transactions` (placeholder table in migration created as plain table)
  - Purpose & columns: implemented per migration V1; FTS5 virtual table not created by migration (migration creates plain `fts_transactions` table as placeholder). Implementation must enable FTS5 at provider init (if available) and create the virtual table using `CREATE VIRTUAL TABLE ... USING fts5(...)` in a follow-up migration or provider init.

Missing / differences
- Several recommended indexes in the architecture document are not explicitly created in Migration v1 (for import_sessions, normalized_documents, accounts, transactions covering index). These should be added in targeted migrations as performance requirements emerge.
- `validation_summary` and JSON fields are stored as TEXT; SQLite uses JSON as TEXT affinity, which is acceptable, but consider using JSON1 functions in queries and adding JSON usage notes.

---

# Migration Review

Migration runner

- `SQLiteDatabase.runMigrations(_:)`:
  - Opens DB if not already open.
  - Ensures `schema_migrations` exists (creates table if missing).
  - Queries current max applied version: `SELECT COALESCE(MAX(version),0) FROM schema_migrations;`.
  - Iterates migrations sorted by `version`, and for each migration with version > currentVersion:
    - Begins transaction with `BEGIN IMMEDIATE TRANSACTION;`.
    - Executes `migration.sql` via `execute(sql:)`.
    - Computes checksum using SHA256(migration.sql).
    - Inserts a row into `schema_migrations` recording version, name, applied_at, checksum.
    - Commits. On error, rolls back and rethrows.

schema_migrations

- Implemented as described. `runMigrations` also creates the table if missing.
- The runner records checksum and applied_at which supports later verification and auditing.

Transaction boundaries

- Each migration is applied inside a transaction started with `BEGIN IMMEDIATE TRANSACTION;` and ended with `COMMIT;`.
- This is the correct pattern for ensuring that changes from a single migration are atomic where the underlying SQLite engine supports transactional DDL. Note: while SQLite will allow transactional DDL in most versions, some DDL (like `CREATE INDEX` or changes that touch sqlite_schema) are transactional but may have nuances across SQLite versions; the code's use of transactions around the entire migration is appropriate.

Migration ordering

- `runMigrations` sorts migrations by `version` and applies them in ascending order. It skips migrations with version <= currentVersion. This ordering is correct and deterministic.

Potential issues / suggestions
- The runner inserts the migration record after executing the migration SQL and before commit; that's fine. In the event of partial application (e.g., DDL that promotes implicit commits in some sqlite builds) the safe path is to ensure migration SQL is idempotent and recorded only after successful commit — current code records before commit but after SQL execution; it then commits and only on commit success the DB reflects both SQL and schema_migrations row. Because both are inside the same transaction, this is consistent.
- `runMigrations` computes checksum from the migration SQL; consider also including an explicit migration `name` and perhaps a content hash of a canonical DDL artifact (already done) to detect local edits.

---

# SQLite Configuration

Current observed configuration in `SQLiteDatabase.open()` and `runMigrations`:
- The DB is opened with flags: `SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX`.
- The code executes `PRAGMA foreign_keys = ON;` after opening.
- No explicit `PRAGMA journal_mode`, `PRAGMA synchronous`, `PRAGMA busy_timeout`, `PRAGMA wal_autocheckpoint`, cache settings, or page_size settings are configured.

Recommendations (explicit and strongly recommended)
1. WAL mode (journal_mode = WAL)
   - Enable Write-Ahead Logging for better concurrency (readers don't block writers). Execute: `PRAGMA journal_mode = WAL;` (preferably right after opening the DB).
2. busy_timeout
   - Set a reasonable busy timeout to avoid immediate SQLITE_BUSY failures under contention. Use either `sqlite3_busy_timeout(db, timeoutMs)` or `PRAGMA busy_timeout = 5000;` (e.g., 5000ms).
3. synchronous
   - Use `PRAGMA synchronous = NORMAL;` for a balance of durability and performance for local DB on mobile devices. For maximum durability use `FULL` (slower).
4. foreign_keys
   - Already set: `PRAGMA foreign_keys = ON;` — keep it.
5. cache_size and temp_store
   - Consider `PRAGMA cache_size` (negative value denotes KB) and `PRAGMA temp_store = MEMORY` for performance, tuned per device.
6. locking_mode
   - By default `NORMAL` is fine; WAL implies different behavior. No immediate change required.
7. FTS5 availability
   - Ensure the runtime builds link or enable FTS5; if building with system SQLite on some platforms FTS5 may not be available. Guard creation of virtual tables and fallback gracefully.

Where to configure
- Set these PRAGMAs immediately after opening the DB in `SQLiteDatabase.open()` before creating tables or running migrations so migrations run in the desired mode.

---

# Repository Review

Repositories present in `SQLiteRepositoryProvider`:

1) `AccountRepository` / `SQLiteAccountRepo`
   - Methods (implemented): `upsertAccount(_ account: [String:Any]) throws -> String`
   - Current implementation: constructs an `INSERT OR REPLACE INTO accounts (...) VALUES (...)` SQL string with values interpolated after escaping single quotes via a local `escape(_:)` helper, then executes via `db.execute(sql:)`. Returns the account id used.
   - Placeholder / TODO: currently accepts `account` as an untyped dictionary; map to a typed model to improve correctness. Use prepared statements with bound parameters and explicit column lists. Add validation and error propagation (typed errors). Consider returning domain model or `UUID` typed alias rather than raw String.

2) `ImportSessionRepository` / `SQLiteImportSessionRepo`
   - Methods (implemented): `createImportSession(_ payload: [String:Any]) throws -> String`, `updateImportSession(_ id: String, updates: [String:Any]) throws`
   - Current implementation: builds `INSERT INTO import_sessions(...)` and `UPDATE import_sessions SET ...` SQL strings using escaped string interpolation and executes them.
   - Placeholder / TODO: convert to typed parameters, prepared statements, and stronger schema-aware mapping (JSON -> TEXT with clear JSON encoding). Consider returning fully-populated import session row after creation.

3) `TransactionRepository` / `SQLiteTransactionRepo`
   - Methods (declared in repository protocol): `replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [Any]) throws` (from earlier protocol file).
   - Current implementation: NO-OP placeholder (empty method) per Phase 2B scope.
   - Future work: Must implement durable replace semantics that atomically replaces transactions for an import or workspace slice and marks `is_trusted` per validation. Implementation must:
     - Use a write transaction that deletes or deactivates prior transactions for an importSession/workspace and inserts new rows, or write an upsert-based approach preserving history as needed.
     - Use prepared statements / binding for all fields.
     - Create and maintain `transaction_raw_rows` rows and update `fts_transactions` virtual table with triggers or explicit updates.
     - Ensure idempotence and robust error handling.

General repository recommendations
- Replace `escape(_:)` + string interpolation with prepared statements using `sqlite3_prepare_v2`, `sqlite3_bind_*`, `sqlite3_step`, `sqlite3_reset`, `sqlite3_finalize`.
- Use typed parameter bindings for decimals, integers, dates (as strings), booleans (0/1), and JSON (TEXT) to avoid SQL injection and encoding errors.
- Introduce a dedicated serial DispatchQueue or actor to run all DB writes to maintain single-threaded access to the connection and avoid race conditions.
- Consider adding convenience wrappers for preparing and executing statements returning typed results.

---

# Thread Safety

Connection lifetime
- `SQLiteDatabase` holds a single `OpaquePointer?` `db` property per instance. The connection is opened in `open()` and closed in `close()` (deinit calls close()).
- `SQLiteRepositoryProvider` constructs one `SQLiteDatabase` instance and passes it to repository instances which keep a reference to that same `SQLiteDatabase`.

Concurrency model
- The DB is opened with `SQLITE_OPEN_FULLMUTEX`, which requests a serialized connection mode from SQLite, allowing the same connection to be used concurrently from different threads with internal mutexing.
- Despite FULLMUTEX, the implementation does not use an explicit serial queue or higher-level synchronization for repository operations. Repositories call `db.execute(sql:)` directly which uses `sqlite3_exec` or prepared statements internally. This relies on SQLite's internal mutexing for thread-safety but leaves higher-level ordering, batching and backpressure to the application.

Recommendations
- Prefer explicit serialization of DB write operations on a dedicated `DispatchQueue(label: "ledgerforge.db.serial")` (or a Swift actor) to ensure deterministic write ordering, easier reasoning about background writes, and to avoid blocking UI threads.
- Keep a single connection per process / data file; avoid creating multiple connections from different threads unless using a connection pool design.
- Use prepared statements reused across operations to reduce overhead and avoid repeated allocation.

---

# Security Review

Prepared statements & SQL injection
- The current repository implementations construct SQL by interpolating escaped strings via `escape(_:)` which only replaces single quotes. This is fragile and may still allow SQL injection in corner cases (non-string types, encoding issues) and is not recommended for production. Prepared statements with parameter binding are required.

SQLCipher readiness
- The current code uses system SQLite (`import SQLite3`) and does not include SQLCipher hooks. To support SQLCipher, the application must link against SQLCipher and open the DB with the appropriate key using `PRAGMA key = '...';` immediately after opening the connection. The `SQLiteDatabase` abstraction should add a secure key initialization path and a configuration option to enable SQLCipher at startup.

Password handling
- No password handling is implemented in DB code — which is correct for Phase 2B. When DB encryption is introduced (Phase 2C or later), secret keys should be stored in Keychain / secure enclave and never hardcoded. The DB layer must accept a key token provider rather than a plaintext key.

Other security notes
- Ensure file-system permissions for the DB file are restricted to the app sandbox / user and use atomic replace operations when swapping DB files.

---

# Risks

1. SQL injection risk from string-interpolated SQL in repository implementations.
2. Missing runtime PRAGMA tuning (WAL, busy_timeout, synchronous) could lead to poor concurrency and spurious SQLITE_BUSY errors under contention.
3. `SQLiteTransactionRepo` is a placeholder — until Phase 2C is implemented no transactions are persisted; this is a planned gap but an operational risk if code paths start depending on persistence unexpectedly.
4. Lack of explicit write serialization and background queueing may cause UI jank or contention if heavy writes are executed on the main thread.
5. FTS5 availability and creation of virtual tables is not addressed; search features depend on FTS5 being present in the runtime SQLite build.
6. No DB encryption support yet; sensitive documents (PDFs) may be stored on disk unencrypted if the file storage path is used without OS-level protection.
7. Migration DDL for large deployments may require careful testing; some DDL operations can be slow and block the DB.

---

# Recommendations for Sprint 10 Phase 2C (exact list)

Implement the following in Phase 2C, in priority order (each item should be a focused task / PR):

1) Prepared statements & parameter binding
   - Replace all string-interpolated SQL (`escape()` + concatenation) in repository implementations with prepared statements and `sqlite3_bind_*` calls. Add helper methods to prepare, bind, step and finalize statements.

2) Implement `SQLiteTransactionRepo.replaceTransactions` (durable import persistence)
   - Implement atomic semantics: within a transaction, insert/update transactions, create `transaction_raw_rows`, update `document_fingerprints`, and mark `is_trusted=1` for new transactions only after import validation passes. Ensure idempotence and rollbacks on error.

3) Concurrency and threading
   - Introduce a dedicated serial DispatchQueue or a Swift actor to serialize DB writes. Ensure longer running migrations or backfills run on background queues and do not block the main/UI thread.

4) Configure SQLite runtime PRAGMAs at open time
   - Set `PRAGMA journal_mode = WAL;`
   - Set `PRAGMA busy_timeout = 5000;` (or configurable)
   - Set `PRAGMA synchronous = NORMAL;`
   - Ensure `PRAGMA foreign_keys = ON;` remains set (already present).

5) FTS5 and triggers
   - Ensure FTS5 is available at runtime. Create FTS5 virtual table for transactions and add triggers (or explicit sync logic) to keep the FTS index in sync with `transactions` insert/update/delete.

6) Migration & testing
   - Add migration unit tests and sample DB fixtures. Test upgrades across schema versions and backward compatibility.

7) Security enhancements
   - Add optional SQLCipher integration and a Keychain-based key provider. Ensure DB file permissions are restrictive.

8) Error handling & observability
   - Improve error reporting for DB operations with typed errors and better logging. Consider integrating a developer console event for DB errors and migration activity.

9) Performance & indexes
   - Add missing indexes from the architecture doc as needed (transactions by account/date/amount, import_sessions lookup, normalized_documents index). Monitor query plans and add covering indexes where necessary.

10) API typing & domain mapping
   - Move repository payloads from `[String:Any]` dictionaries to typed domain models or DTOs to improve compile-time safety and clarity.

---

# Closing notes

Overall the Phase 2B implementation correctly implements the foundational pieces required by the approved database architecture: a migration runner, Migration v1 DDL, and a SQLite-backed provider with minimal repositories. The main work for Phase 2C is engineering hardening (prepared statements, concurrency, FTS5, durable transaction persistence and security). The recommendations above are intentionally scoped and prioritized so Phase 2C can be implemented with clear milestones and verification steps.

End of audit.
