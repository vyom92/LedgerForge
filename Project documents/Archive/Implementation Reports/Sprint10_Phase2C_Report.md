<!-- Project documents/Archive/Implementation Reports/Sprint10_Phase2C_Report.md -->

# Sprint 10 Phase 2C — SQLite Repository Persistence Implementation Report

Date: 2026-07-06

# Sprint Summary

- Objective: Implement SQLite-backed repository persistence (prepared statements, runtime PRAGMAs, DTOs, serialized writes, and durable transaction persistence) while preserving Store APIs and application behaviour.

# Build Status

- Build: pending verification — run locally to confirm.

# Test Status

- Repository contract tests added to run against `SQLiteRepositoryProvider` (in-memory path) and will be part of CI.

# Files Created

- `Database/DTOs.swift` — strongly typed DTOs: `TransactionDTO`, `TransactionRawRowDTO`, `AccountDTO`, `ImportSessionDTO`.
- `LedgerForgeTests/RepositoryContractTests.swift` — repository contract tests (in-memory SQLite smoke test).
- `Project documents/Archive/Implementation Reports/Sprint10_Phase2C_Report.md` (this file, subsequently archived).

# Files Modified

- `Database/Repository.swift` — protocols updated to accept/return DTOs; placeholders updated.
- `Database/SQLiteDatabase.swift` — runtime PRAGMA configuration (WAL, busy_timeout, synchronous), prepared statement helper `executePrepared`, and `queryInt` helper.
- `Database/SQLiteRepositoryProvider.swift` — repositories updated to use DTOs and prepared statements; `SQLiteTransactionRepo.replaceTransactions` implemented.
- `LedgerForge.xcodeproj/project.pbxproj` — project file updated to include new files in the Project Navigator and build phases.

# DTOs Added

- `TransactionDTO`
- `TransactionRawRowDTO`
- `AccountDTO`
- `ImportSessionDTO`
- `PartialImportSessionUpdate` (for partial updates)

# Repository Changes

- `TransactionRepository.replaceTransactions` now accepts `[TransactionDTO]` and `SQLiteTransactionRepo` implements atomic persistence, deletion of prior non-trusted candidates for the same `import_session_id`, insertion of `transactions` and `transaction_raw_rows` using prepared statements and parameter binding.
- `AccountRepository.upsertAccount` accepts `AccountDTO` and uses prepared statements (INSERT OR REPLACE) to persist accounts.
- `ImportSessionRepository.createImportSession` and `updateImportSession` accept typed DTOs/updates and persist using prepared statements.

# Database Runtime Configuration

- `SQLiteDatabase.open()` now configures the DB with:
  - `PRAGMA journal_mode = WAL;`
  - `PRAGMA foreign_keys = ON;`
  - `sqlite3_busy_timeout(db, 5000)`
  - `PRAGMA synchronous = NORMAL;`

# Migration Changes

- No historical migrations were modified. All changes are additive at the application layer. Existing `migrationV1` remains untouched.

# Repository Contract Tests

- Added `RepositoryContractTests.repositoryPersistenceSmoke` which:
  - Creates an in-memory `SQLiteRepositoryProvider`.
  - Creates an `ImportSessionDTO`.
  - Upserts an `AccountDTO`.
  - Persists a `TransactionDTO` via `replaceTransactions`.
  - Asserts a row exists in `transactions`.

# Architectural Decisions

- Strongly typed DTOs replace loosely-typed dictionaries to satisfy Engineering Standards and prevent runtime type errors.
- Prepared statements and parameter binding implemented to prevent SQL injection and ensure safe encoding of values.
- Transaction persistence implemented with idempotent `INSERT OR REPLACE` semantics keyed by transaction `id` (UUID) to support safe retries.
- Delete-before-insert semantics for candidate (non-trusted) transactions scoped to `import_session_id` were chosen to implement `replaceTransactions` semantics while preserving trusted historical transactions.
- DB runtime PRAGMAs are set at open-time to ensure production-safe defaults (WAL, busy_timeout, synchronous) per architecture recommendations.

Reference ADRs: ADR-001 (offline-first), ADR-009 (stores), ADR-010 (validation-before-persistence), ADR-011 (Document Reader pipeline), ADR-013 (store ownership).

# Deviations

- None significant. All changes adhere to the approved architecture and implementation plan for Phase 2C.

# Technical Debt

- FTS5 integration not implemented in this phase (planned for Phase 2D).
- SQLCipher/encryption not implemented (out of scope).
- Repository methods currently execute statements one-by-one; batching and prepared statement caching will improve performance and should be implemented in Phase 2D.

# Risks

- Large imports may hit SQLITE_BUSY if background writes are not batched; mitigation: WAL and busy_timeout added and further write queue tuning planned.
- Idempotence relies on stable transaction IDs from upstream parsers; ensure parsers supply deterministic IDs where required.

# Remaining Work (recommend Phase 2D)

1. Prepared-statement caching and statement lifecycle management.
2. FTS5 virtual table creation and triggers or sync logic.
3. Batch insert optimizations for large imports.
4. Migration backfills (amount_minor computation) as background jobs.
5. Optional SQLCipher integration and Keychain key management.

# Git Commit Message

Add SQLite repository persistence: DTOs, PRAGMAs, prepared statements and transaction persistence

- Add Database/DTOs.swift and typed repository APIs
- Harden SQLiteDatabase with WAL, busy_timeout, synchronous and prepared statement helper
- Implement SQLite-backed Account, ImportSession and Transaction repositories using parameterized queries and atomic replaceTransactions
- Add repository contract tests and update project files

# Files Requiring Manual Review

- `Database/SQLiteRepositoryProvider.swift` — verify SQL and transaction semantics match expectations for production imports.
- `Database/SQLiteDatabase.swift` — PRAGMA choices and busy_timeout value.
- `Database/Repository.swift` and `Database/DTOs.swift` — ensure DTO fields align with domain model and parsers.
- `Project documents/Database_v1_Architecture.md` — ensure any necessary DDL changes are reflected in a subsequent migration when enabling persistence in production.

***

End of report.
