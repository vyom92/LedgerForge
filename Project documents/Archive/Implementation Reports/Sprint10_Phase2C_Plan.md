<!-- Project documents/Archive/Implementation Reports/Sprint10_Phase2C_Plan.md -->

# Sprint 10 Phase 2C — SQLite Repository Persistence Plan

Date: 2026-07-06

Scope

- Purpose: Plan the implementation of SQLite-backed repository adapters and durable persistence for import sessions, accounts and transactions while preserving existing Store APIs and application behaviour.
- Constraints: Documentation-only plan. No Swift code will be changed in this phase. Implementation will follow this plan in subsequent work.
- Architecture references (authoritative):
  - Project documents/Database_v1_Architecture.md
  - Project documents/ADR.md
  - Project documents/Architecture_v1.0_Frozen.md
  - Project documents/Product Vision.md
  - Project documents/Engineering Standards.md

---

# Current State

- Repository protocols are defined in `Database/Repository.swift` (TransactionRepository, AccountRepository, ImportSessionRepository). A `DatabaseProvider` abstraction exists to expose repository instances.
- `Database/SQLiteDatabase.swift` provides a thin SQLite wrapper and a migration runner. It opens a single connection with `SQLITE_OPEN_FULLMUTEX`, enables `PRAGMA foreign_keys = ON` and applies ordered migrations inside transactions.
- `Database/SQLiteRepositoryProvider.swift` runs migrations at init and exposes `SQLiteAccountRepo`, `SQLiteImportSessionRepo` and `SQLiteTransactionRepo` instances. `SQLiteAccountRepo` and `SQLiteImportSessionRepo` implement simple SQL via string interpolation and `escape()`; `SQLiteTransactionRepo.replaceTransactions` is intentionally a Phase 2B no-op placeholder.
- The Import pipeline (Services/ImportEngine.swift) currently produces parsed transactions and, after validation passes, calls `TransactionStore.replaceTransactions(...)` and `AccountStore.integrateImport(...)`. These stores remain in-memory owners for now.
- `ImportCoordinator` is described in architecture docs but has no concrete implementation in the codebase; `ImportEngine` serves orchestration for imports in the current implementation.

---

# Gap Analysis

What remains to be implemented to reach durable persistence for imports:

1. Transaction persistence
   - Implement `SQLiteTransactionRepo.replaceTransactions` to atomically persist parsed transactions, associated transaction_raw_rows, and mark `is_trusted` according to import validation.
2. Safe SQL practices
   - Replace string-interpolated SQL in `SQLiteAccountRepo` and `SQLiteImportSessionRepo` with prepared statements and parameter binding to prevent SQL injection and encoding issues.
3. Concurrency and serialization
   - Introduce a write-serialization model (dedicated DB write queue or actor) for deterministic background writes and to avoid main-thread blocking.
4. FTS5 integration
   - Create FTS5 virtual table for transactions and ensure it is populated and maintained via triggers or explicit sync logic.
5. PRAGMAs and runtime tuning
   - Configure WAL journaling, busy_timeout, synchronous mode and cache settings at DB open-time (in `SQLiteDatabase.open()`).
6. Migration and backfill
   - Add migrations and backfill jobs for any schema additions required by traceability fields added to the architecture (e.g., `documents.statement_start_date`, `import_sessions.reader_version`) and for computed fields like `amount_minor`.
7. Error handling and observability
   - Improve DB error propagation, logging, and expose diagnostic hooks for developer console.
8. Security (optional in Phase 2C but planned)
   - Prepare for SQLCipher integration and Keychain-backed key management; ensure repository code does not hardcode secrets.

---

# Repository-by-Repository Plan

Each repository section below describes the current implementation, the required SQLite-backed implementation, methods to complete, transaction boundaries, and expected SQL operations.

1) TransactionRepository / SQLiteTransactionRepo

Current implementation
- `replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [Any]) throws` exists but is a no-op placeholder.

SQLite implementation (goal)
- Provide an implementation that atomically replaces the set of transactions associated with an `import_session_id` (or workspace slice) with the new set of parsed transactions. The operation must:
  - Persist `transactions` rows (id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at).
  - Persist `transaction_raw_rows` mappings linking transactions → normalized_rows.
  - Update or insert `document_fingerprints` for deduplication records where applicable.
  - Optionally upsert `accounts` / `account_identifiers` if parsers supply new account identifiers (but prefer AccountRepository for account lifecycle to preserve Store ownership separation).
  - Set `is_trusted=1` for transactions only after import validation status is 'passed' — this is coordinated by ImportEngine which will call replaceTransactions only after validation in current design. The repository API should accept validation metadata if needed.

Methods to complete
- replaceTransactions(...)
  - Validate input structure and types (use domain DTOs, not raw `[String:Any]` dictionaries).
  - Start a DB transaction (BEGIN IMMEDIATE).
  - Insert/Upsert transactions in batches using prepared statements and parameter bindings.
  - For each transaction, insert transaction_raw_rows rows (prepared statement); batch where possible.
  - Insert or update document_fingerprints with `INSERT OR IGNORE` or `INSERT` and handle uniqueness constraint violations gracefully.
  - Commit the DB transaction.
  - Return summary (rows inserted, any conflicts) or throw on error.

Transaction boundaries
- Entire replace operation must be contained within a single DB transaction to ensure atomicity. Use `BEGIN IMMEDIATE` so writers obtain required locks and avoid writer starvation.

Expected SQL operations (examples)
- DELETE or mark prior transactions for an import (decision: hard replace vs insert-with-history). Recommended: insert new rows and rely on import_session linkage + is_trusted flag rather than destructive deletes; but if replacing candidate transactions for an import, delete prior candidate transactions where import_session_id matches and is_trusted=0 before insert.
- INSERT INTO transactions (...) VALUES (...)
- INSERT INTO transaction_raw_rows (id, transaction_id, normalized_row_id, contribution_type, created_at) VALUES (...)
- UPDATE transactions SET is_trusted=1, trusted_at=? WHERE import_session_id=? AND <validation rules>

Notes on idempotence
- Design the method to be idempotent for repeated runs (use INSERT OR REPLACE or UPSERT semantics keyed by transaction.id). Maintain uniqueness with the `id` primary key (UUIDs generated by parser or provider).

2) AccountRepository / SQLiteAccountRepo

Current implementation
- `upsertAccount(_ account: [String:Any]) -> String` inserts or replaces the `accounts` row using `INSERT OR REPLACE` and returns the id. Uses string-interpolated SQL and `escape()` helper.

SQLite implementation (goal)
- Harden the upsert implementation:
  - Use prepared statements with parameter binding for `INSERT OR REPLACE` or `INSERT ... ON CONFLICT(id) DO UPDATE SET ...` patterns.
  - Validate the account DTO shape and enforce workspace scoping.

Methods to complete
- upsertAccount(account: AccountDTO) -> String
  - Prepare statement once and reuse for the repo's lifetime.
  - Bind fields and execute.
  - Return the account id.

Transaction boundaries
- Each upsert may be a standalone statement; when called as part of a larger import persistence transaction (e.g., in replaceTransactions), the AccountRepo methods should participate in the outer transaction rather than committing separately. Implement the DB helper to accept an optional transaction context or rely on the repository to call DB transaction control at a higher level.

Expected SQL operations
- INSERT INTO accounts (id, workspace_id, name, institution_id, account_type, native_currency, description, created_at, closed_at, created_from_import_session_id) VALUES (...) ON CONFLICT(id) DO UPDATE SET name=excluded.name, ...

3) ImportSessionRepository / SQLiteImportSessionRepo

Current implementation
- `createImportSession(_ payload: [String:Any]) -> String` and `updateImportSession(_ id: String, updates: [String:Any])` implemented with escaped string interpolation.

SQLite implementation (goal)
- Use prepared statements for INSERT and UPDATE. Ensure JSON fields (validation_summary) are serialized explicitly using JSONEncoder to avoid subtle formatting differences.

Methods to complete
- createImportSession(payload: ImportSessionDTO) -> String
- updateImportSession(id: String, updates: ImportSessionUpdateDTO)

Transaction boundaries
- createImportSession should be a single statement but when used as part of a larger import orchestration (creating documents, normalized_rows and transactions), it should participate in a larger transaction or be followed by transactional operations that persist the rest of the import. Prefer: create ImportSession record first (single statement), then perform rest of import in a transaction.

Expected SQL operations
- INSERT INTO import_sessions (id, workspace_id, user_visible_name, started_at, validation_status, created_at, reader_version, parser_version, layout_version, ...) VALUES (...)
- UPDATE import_sessions SET validation_status=?, completed_at=?, updated_at=? WHERE id=?

---

# Store Impact

- TransactionStore and AccountStore APIs will remain unchanged. The stores continue to be the single owners of in-memory state and their public API methods (e.g., `replaceTransactions`, `integrateImport`, filtering methods) will be called by ImportEngine / ImportCoordinator as before.
- Integration pattern (recommended):
  1. Import pipeline parses documents into candidate domain objects.
  2. Validation runs and ImportEngine/ImportCoordinator receives result.
  3. If validation passes, call repository layer (e.g., `TransactionRepository.replaceTransactions`) to persist transactions atomically.
  4. After successful repository commit, update in-memory stores (TransactionStore.replaceTransactions(...)) so stores reflect persisted state. This separation preserves the existing Store APIs and keeps durable persistence in repositories.

- Important: Do not change Store API signatures. Repositories implement persistence and optionally return success metadata; stores remain authoritative in-memory owners and are updated after persistence success to preserve ADR semantics (validation-before-persistence). This preserves existing UI behaviour and tests.

---

# Migration Strategy

Goals
- Transition from in-memory-only state to durable SQLite persistence with zero downtime and preserved behaviour.

Approach

1. Backwards-compatible additive migrations
   - All schema changes must be additive (new tables/columns/indexes). Use the `schema_migrations` table to record applied migrations.

2. Phased rollout
   - Phase 2B: migration runner and schema v1 applied (already complete).
   - Phase 2C (this plan): implement repository adapters and durable writes but keep Store update semantics identical: stores updated only after persistence success.

3. Idempotent writes and upserts
   - Use `INSERT OR REPLACE` or `INSERT ... ON CONFLICT` Upsert semantics keyed on stable UUIDs to make operations idempotent.

4. Backfill jobs (post-migration)
   - For derived columns (e.g., `amount_minor`) create background backfill jobs that compute values from `amount_decimal` and `currencies.minor_unit`.

5. Data integrity & testing
   - For each migration, include a migration test that upgrades a sample DB snapshot and asserts expected derived state and indexes are present.

Mapping existing in-memory data
- On first run after enabling persistence, the application can perform a bootstrap migration step: if repositories report zero persisted transactions for a workspace, persist current in-memory TransactionStore state as trusted historical imports using a controlled importSession marked as migrated/bootstrapped. Mark such sessions with appropriate provenance. Alternatively, rely on import replay mechanisms for users to re-import.

---

# Testing Strategy

Unit tests
- Repository unit tests (in-memory SQLite test DB) for each repository method using prepared test fixtures and asserting SQL operations and outcomes.
- DTO validation and SQL parameter binding tests.

Repository integration tests
- Use ephemeral SQLite databases (temp files) with migrations applied. Run full import persistence with sample normalized_documents + parsed transactions and assert:
  - `transactions` rows inserted as expected
  - `transaction_raw_rows` mappings created
  - `document_fingerprints` inserted
  - `import_sessions` updated correctly
  - FTS virtual table populated (if present)

Migration tests
- Maintain a set of baseline DB fixtures that represent previous versions and assert that `runMigrations` upgrades them to the latest schema and preserves data.

Regression tests
- Re-run existing application unit tests (TransactionStore, AccountStore, ImportEngine paths) to ensure behaviour unchanged.
- UI-level smoke tests to verify dashboard metrics remain correct when using persisted data vs in-memory data.

Performance tests
- Bulk import stress tests to measure write throughput and ensure busy timeouts / WAL settings avoid SQLITE_BUSY under load.

Test tooling
- Use an in-repo test helper to create ephemeral SQLite DBs and apply migrations before each test. Mock the `DatabaseProvider` to return a provider pointing to the ephemeral DB.

---

# Risks

1. Concurrency & locking
   - Long-running writes and backfills may cause SQLITE_BUSY contention; mitigated by WAL + busy_timeout + serialized write queue.
2. SQL injection / encoding
   - Existing interpolated SQL is vulnerable; replacing with prepared statements is high priority.
3. Migration complexity
   - Large DDL or backfills may be slow on user devices; plan background jobs and incremental backfills.
4. FTS5 availability
   - Some system SQLite builds lack FTS5; provide graceful fallback or build with bundled SQLite/SQLCipher if FTS required.
5. Data duplication / idempotence
   - Ensuring idempotent imports and avoiding duplicates across re-imports requires careful fingerprint checks; design dedupe before marking transactions trusted.

---

# Sprint Breakdown (Milestones)

Each milestone is a small, reviewable unit that must build and preserve functionality.

Milestone 1 — DB runtime hardening (PRAGMAs & config)
- Tasks:
  - Configure `SQLiteDatabase.open()` to apply PRAGMAs: `journal_mode=WAL`, `busy_timeout`, `synchronous=NORMAL`, `foreign_keys=ON` and reasonable cache settings.
  - Add runtime checks for FTS5 availability.
- Goals: Ensure migrations and runtime use production-safe defaults.
- Verification: Unit test that DB opens and PRAGMAs report expected values; migration runner still applies migrationV1.

Milestone 2 — Prepared statement helpers and typed DTOs
- Tasks:
  - Implement DB helper wrappers for preparing, binding and executing statements.
  - Introduce repository DTO types (TransactionDTO, AccountDTO, ImportSessionDTO) in Database layer.
  - Replace `SQLiteAccountRepo` and `SQLiteImportSessionRepo` to use prepared statements (no behaviour change).
- Goals: Eliminate SQL string interpolation and `escape()` usage for existing repos.
- Verification: Unit tests for account and import session upsert/create/update.

Milestone 3 — Write serialization & DB queue
- Tasks:
  - Add a dedicated serial DispatchQueue or a DB actor to serialize writes and expose safe execution helpers.
  - Refactor repository implementations to perform writes on the queue (without changing public sync signatures — methods can be synchronous but call queue.sync where required).
- Goals: Deterministic writes and avoidance of main-thread IO.
- Verification: Concurrency tests that simulate parallel writes and assert no SQLITE_BUSY failures.

Milestone 4 — Transaction persistence implementation
- Tasks:
  - Implement `SQLiteTransactionRepo.replaceTransactions` with transactional semantics, prepared statements and batch insert for transactions and transaction_raw_rows.
  - Ensure idempotence using `INSERT OR REPLACE` or `ON CONFLICT` by `id`.
  - Update document_fingerprints if necessary.
  - Ensure the caller (ImportEngine/ImportCoordinator) calls the repository only after validation passes; repository should assume the caller enforces validation-before-persistence.
- Goals: Durable persistence of transactions, atomicity and idempotence.
- Verification: Repository integration tests with sample parsed transactions; verify persisted rows and store update flow.

Milestone 5 — FTS5 integration and triggers
- Tasks:
  - Create FTS5 virtual table for `transactions` and add triggers or explicit sync steps to keep it updated.
  - Populate the FTS table on initial migration or after batch inserts.
- Goals: Full-text search enabled for payee/description/reference.
- Verification: Search tests against FTS5; fallback tests if FTS5 not available.

Milestone 6 — Backfills, migration tests & bootstrapping
- Tasks:
  - Implement background backfill job(s) for `amount_minor` and other derived columns.
  - Add migration test fixtures and automated upgrade tests.
  - Provide a safe bootstrap path for migrating existing in-memory store contents on first-run (if required).
- Goals: Data integrity and upgrade safety.
- Verification: Migration test suite passes against fixtures.

Milestone 7 — Security & SQLCipher readiness
- Tasks:
  - Add optional SQLCipher initialization path and Keychain-based key provider.
  - Ensure prepared statements remain compatible with SQLCipher.
- Goals: Encrypted DB option available for production builds where required.
- Verification: Manual test verifying DB opens with SQLCipher key and data is persisted encrypted.

---

# Rollout and Verification

- Merge strategy: small PRs per milestone, each with unit and integration tests. Run CI with migration test matrix.
- Monitoring: add developer console logs for migration runs, DB errors and long-running backfills.

---

# Deliverables for Phase 2C (when implementing)

1. `SQLiteDatabase` updated to configure PRAGMAs at open.
2. DB helper utilities for prepared statements and parameter binding.
3. Typed DTOs for repository inputs.
4. `SQLiteAccountRepo` and `SQLiteImportSessionRepo` refactored to prepared statements.
5. Serial DB write queue / actor.
6. `SQLiteTransactionRepo.replaceTransactions` implemented and tested.
7. FTS5 virtual table and sync strategy.
8. Migration/backfill jobs and tests.
9. Optional SQLCipher integration scaffold.

---

# Final notes

- This plan preserves Store APIs and ADR constraints: validation-before-persistence, Document Reader vs Parser separation, and store ownership.
- The recommended milestone order focuses on security and runtime hardening first (PRAGMAs, prepared statements), then implements persistence and search features, and finally addresses migration/backfill and security encryption.

End of plan.
