# Repository State

- Primary branch: `main`.
- Latest verified completed increment: Sprint 47 — Verified Persistence Startup and Migration Integrity.
- Sprint 47 implementation commit: the single Sprint 47 commit containing this state update; its exact SHA is recorded by Git and the completion report.
- Earlier relevant implementation commits: `d9009fb` — Preserve parent state during upsert; `b9e68ce` — Stabilize import-lifecycle cancellation synchronization; `f288834` — Apply approved macOS permission settings.
- Current migration: V4, including the bounded `import_attempts` ledger.
- Current accepted ADR: ADR-035 — Development Database Lifecycle and Recoverable Reset.
- Architecture baseline: Architecture v1.0 Frozen and UI/UX v1.0 Frozen.
- Build state: Debug and normal optimized Release builds pass for Sprint 47; static analysis passes. Debug emitted no source warnings. Optimized Release emitted the same four existing `AccountStore` actor-isolation warnings; no warning is attributable to Sprint 47.
- Latest verified automated result: 284 executed test cases across 37 suites, 0 failures and no unexpected skips. Generic `LedgerForgeUITests` remained intentionally disabled.

## Current Production Capability

- Production import is verified for the approved Axis Bank NRE CSV path through the unified import framework.
- The pipeline performs reader, institution detection, statement classification, parser selection, immutable `FinancialDocument`, validation, duplicate evaluation, explicit confirmation and repository-owned persistence.
- Sprint 47 makes `DatabaseProvider` the atomic authority for active repositories and typed persistence state. Production publishes verified SQLite repositories only after open, complete V1-V4 history validation, pending migration execution and final-chain revalidation all succeed.
- Open, initialization, migration-integrity or migration-execution failure installs centrally rejecting unavailable repositories rather than an in-memory substitute. Import preparation and confirmation, hydration and account metadata mutation gate early, while every repository operation remains centrally fail-closed.
- Settings and Developer Console distinguish verified durable SQLite, unavailable persistence and explicitly selected non-durable test or Debug providers without exposing database paths, raw SQL or raw SQLite errors.
- Parser-owned verified identity resolution supports the approved Axis account path and explicit existing-account or create-account decisions.
- Exact reader-content duplicate protection uses the versioned ADR-030 authority.
- Bounded parser-verified Axis UPI transaction-event blocking uses the ADR-031 authority; blocked imports do not silently omit transactions.
- Sprint 42 provides durable, privacy-safe import-attempt history with bounded outcomes, coverage, account-decision and guidance values. Rejected attempts remain distinct from successful import sessions.
- Sprint 43 provides deterministic named read-only preparation stages, stable active-operation ownership, safe pre-persistence cancellation and bounded fresh retry for typed source-reading failures. Cancelled preparation is neither trusted persistence nor durable attempt history. Confirmed persistence is explicitly non-cancellable and remains repository-owned.
- Sprint 45 Phase A provides a DEBUG-only `DevelopmentDatabaseLifecycleCoordinator` and activity gate. The canonical Debug identity is `Application Support/LedgerForge/Development/ledgerforge-development.sqlite`; the non-development identity remains the separate `Application Support/LedgerForge/ledgerforge.sqlite` path.
- Permanent Debug reset checkpoints and closes the provider, creates and verifies the lifecycle-owned `Development/Lifecycle Backups/previous-development.sqlite` backup, coordinates the main SQLite, WAL and SHM set, recreates the same canonical identity through the registered migration chain and forces `RepositoryStoreHydrator` reconciliation. Provider generations invalidate stale repositories.
- Temporary empty sessions use UUID databases under `Development/Temporary Sessions`, affect only the current process and reconnect to canonical data on relaunch. Permanent reset recreates the canonical database and remains empty after relaunch. Automatic recovery restores the verified backup; failed recovery enters lifecycle-unavailable state.
- Dashboard, Accounts, Transactions and Imports are repository-backed experiences. `RepositoryStoreHydrator` is the only persistence-to-runtime boundary.
- Sprint 46 uses in-place SQLite conflict updates for same-ID workspace and account writes. DTO-owned fields update without parent recreation, while dependent durable records and account lifecycle/provenance columns outside `AccountDTO` ownership remain preserved; SQLite and In-Memory observable repository behavior matches.

## Current Verified Limitations

- Production parser support remains limited to the approved Axis NRE CSV layout.
- PDF is a text-extraction and statement-understanding foundation only; production PDF parsing is not supported.
- No production password-entry or Keychain workflow exists.
- XLS, XLSX, TXT and OCR are not production-supported.
- Credit-card financial semantics and production card parsing are not implemented.
- Sprint 44 establishes the ADR-033 Money boundary: a compiled currency catalog, canonical catalog-scale persistence, exact decimal/minor/currency hydration checks, SQLite/In-Memory parity and grouped native-currency presentation. Schema remains V4 and no production-data migration was introduced. Disposable development and test data must conform to the canonical persistence contract.
- ADR-034 accepts document-scoped card-statement evidence subordinate to ADR-033. Card evidence, persistence, production parsing and institution support remain unimplemented and independently gated.
- Mixed-currency totals and summaries are not presented as one aggregate; Dashboard, Accounts and Transactions group values by native currency. FX conversion remains unimplemented.
- Development lifecycle operations are excluded while import preparation, prepared confirmation, confirmed persistence, hydration/reload, repository writes or another lifecycle operation is active. Direct Sprint 45 runtime checks observed the bounded `activity-in-progress` result for preparation, awaiting confirmation, confirmed persistence and hydration.
- Permanent reset, temporary-session and restore capabilities are compile-time absent from non-Debug builds. Isolated optimized Release runtime inspection exposed no destructive lifecycle or approved-fixture controls; Release symbol, constant-string and resource scans found no such capability or fixture resources.
- Cross-process and external-writer import guarantees are not implemented.
- Broader workspace/account/identifier atomicity remains incomplete; earlier side effects may precede the atomic import-history operation.
- Unsupported transaction-event families, including IMPS, NEFT, e-commerce, refunds, reversals and unstructured references, remain unevaluated.
- Generic UI tests remain intentionally disabled; supported runtime behavior is covered by the documented manual and automated boundaries.
- No rollback, resumable import job, batch queue or cancellation after confirmed persistence exists. Confirmed-persistence failure retry remains unsupported pending typed authoritative safety evidence.

## Recent Verified Changes

- Sprint 39 added versioned exact-content duplicate prevention, same-process confirmation serialization and atomic successful import-history persistence.
- Sprint 40 established sanitized overlapping Axis evidence and the bounded transaction-event identity contract.
- Sprint 41 implemented parser-owned Axis UPI event ownership, pre-write blocking and Migration V3.
- Sprint 42 implemented Migration V4, durable attempt history, bounded rejected outcomes, provider parity, attempt-only hydration and read-only Imports history/detail.
- Sprint 43 implemented truthful preparation progress, cancellation ownership and bounded fresh source-reading retry without a schema migration or ADR change.
- Sprint 44 implemented validated Money parser output, canonical catalog-scale writes, strict decimal/minor/currency hydration and grouped native-currency presentation without a schema migration. Development and test databases may be recreated or reseeded rather than retaining obsolete lexical decimal forms.
- Sprint 45 Phase A accepted ADR-035 and implemented recoverable permanent reset of the canonical Debug development database, distinct temporary-session semantics, verified backup and automatic recovery, provider-generation invalidation, exclusive activity leases and canonical hydration without a schema migration. Temporary-session and permanent-reset relaunch behavior, backup contents and all four active-state exclusions were directly verified. Phase B (`FW-P1-37` and `FW-P1-40`) was not started.
- Sprint 46 replaced destructive SQLite workspace/account parent replacement with explicit in-place conflict updates, preserving dependent durable graphs, immutable IDs and unowned account lifecycle/provenance fields. SQLite-specific foreign-key checks and SQLite/In-Memory parity coverage pass without a migration or ADR change. The import-lifecycle cancellation test now uses a deterministic test-only start/cancellation handshake; production import behavior is unchanged. The approved macOS permission settings build and launch in both Debug and optimized Release.
- Sprint 47 implemented one shared migration-chain validator for startup and Debug backup verification, provider-owned typed persistence state, fail-closed production bootstrap, centrally unavailable repositories, early import/hydration/metadata gates and truthful path-free status presentation. Fresh databases, every V1-V4 upgrade/reopen path, malformed histories, bootstrap failures, unavailable enforcement and intentional memory providers are covered without Migration V5 or an ADR change.
- ADR-034 accepted the document-scoped card-statement evidence boundary after integrated American Express, CBQ and Axis fixture evidence and the completed cross-family review. It does not establish card persistence, production parsing, or card semantics beyond source-owned evidence.
- Source-faithful sanitized Axis NRO CSV, PDF and XLS regression evidence is integrated across two overlapping ranges. Range 1 records institution-supplied cross-format divergence; these fixtures do not constitute Axis NRO production parser support.
- Clean-room Axis credit-card PDF and XLSX fixture evidence is integrated for two consecutive, non-overlapping periods. The PDFs contain 140 and 151 canonical transaction rows; the XLSX workbooks contain 143 and 154, including three legitimate XLSX-only source-format rows per period and no PDF-only rows. One fictional customer, account and instrument continue with no supplementary-instrument evidence. Statement currency is INR; Debit/Credit remains an observed source marker only, and no original-currency or FX evidence was introduced. The PDFs retain native selectable text without OCR, and the declared PDF geometry and workbook structures are preserved while PDF object and OOXML package identity are intentionally not preserved. Axis card PDF/XLSX production parsing and card semantics remain unsupported.
- Clean-room HDFC NRE and NRO fixture evidence is integrated for annual and recent PDF and legacy-XLS periods. Every PDF/XLS pair reconciles; the PDFs retain native selectable text without OCR and preserve the verified financial, geometric, pagination and multiline relationships while intentionally not preserving source PDF object identity. HDFC production parsing remains unsupported.
- Clean-room CBQ current-account PDF fixture evidence is integrated for April, May and June 2026. The periods are contiguous, non-overlapping and balance-continuous with 10, 7 and 9 canonical transactions. The approved layouts retain native selectable text without OCR and preserve their declared pagination, dimensions, repeated-header and multiline relationships while intentionally not preserving source PDF object identity. CBQ production parsing remains unsupported.
- Clean-room CBQ credit-card PDF fixture evidence is integrated for four consecutive, non-overlapping periods across the v1 legacy and v2 equation-style layouts with 28, 14, 11 and 23 canonical transactions. One fictional customer and account continue across the layout transition; primary and supplementary instrument relationships and exact transaction assignment are preserved. Posted QAR remains distinct from original merchant amount and currency evidence; missing FX rates, markup, taxes and absent aggregates were not derived, while source-observed fees remain explicit. The PDFs retain native selectable text without OCR and preserve the declared geometry, pagination, continuation, summary-membership and instrument relationships while intentionally not preserving source PDF object identity. CBQ card production parsing and card semantics remain unsupported.
- Clean-room American Express card-statement PDF fixture evidence is integrated for two contiguous periods from 2026-04-24 through 2026-06-23 with 61 and 34 canonical transactions. One fictional customer, account and instrument relationship continues; account-level payments remain distinct from instrument transactions; posted QAR remains separate from original merchant amount and currency evidence present for 49 and 10 transactions; and missing FX rates, fees, markup and tax were not derived. The PDFs retain native selectable text without OCR and preserve the declared pagination, geometry, rewards, legal and multiline relationships while intentionally not preserving source PDF object identity. American Express production parsing and card semantics remain unsupported.

## Planning Boundary

- No repository-stored active work contract exists.
- The complete Chat-approved prompt supplied directly in the current conversation is the sole execution contract.
- Unscheduled work is selected from `Project documents/FUTURE_WORK.MD` after verified state and optional read-only discovery.
- Detailed implementation history remains in Git, accepted ADRs and clearly archived reports.
