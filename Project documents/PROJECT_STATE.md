# Repository State

- Primary branch: `main`.
- Latest verified completed increment: Sprint 43 — Honest Import Lifecycle.
- Latest relevant implementation commit: `4f120d18e406f1b06675397c269fa90e4fd80e09` — Preserve pre-confirmation cancellation in Sprint 43.
- Current migration: V4, including the bounded `import_attempts` ledger.
- Current accepted ADR: ADR-032 — Durable Import Attempt History and Rejected-Outcome Semantics.
- Architecture baseline: Architecture v1.0 Frozen and UI/UX v1.0 Frozen.
- Build state: clean Debug build passing for Sprint 43.
- Latest verified automated result: 185 tests in 27 suites, 0 failures, 0 skipped. Generic `LedgerForgeUITests` remained intentionally disabled.

## Current Production Capability

- Production import is verified for the approved Axis Bank NRE CSV path through the unified import framework.
- The pipeline performs reader, institution detection, statement classification, parser selection, immutable `FinancialDocument`, validation, duplicate evaluation, explicit confirmation and repository-owned persistence.
- Parser-owned verified identity resolution supports the approved Axis account path and explicit existing-account or create-account decisions.
- Exact reader-content duplicate protection uses the versioned ADR-030 authority.
- Bounded parser-verified Axis UPI transaction-event blocking uses the ADR-031 authority; blocked imports do not silently omit transactions.
- Sprint 42 provides durable, privacy-safe import-attempt history with bounded outcomes, coverage, account-decision and guidance values. Rejected attempts remain distinct from successful import sessions.
- Sprint 43 provides deterministic named read-only preparation stages, stable active-operation ownership, safe pre-persistence cancellation and bounded fresh retry for typed source-reading failures. Cancelled preparation is neither trusted persistence nor durable attempt history. Confirmed persistence is explicitly non-cancellable and remains repository-owned.
- Dashboard, Accounts, Transactions and Imports are repository-backed experiences. `RepositoryStoreHydrator` is the only persistence-to-runtime boundary.

## Current Verified Limitations

- Production parser support remains limited to the approved Axis NRE CSV layout.
- PDF is a text-extraction and statement-understanding foundation only; production PDF parsing is not supported.
- No production password-entry or Keychain workflow exists.
- XLS, XLSX, TXT and OCR are not production-supported.
- Credit-card financial semantics and production card parsing are not implemented.
- Mixed-currency totals and summaries are not safe for production use; the current persisted transaction model carries one authoritative native amount/currency pair.
- Development reset installs a temporary provider while the canonical database remains intact; relaunch reconnects to canonical data. A permanent recoverable reset contract is future work.
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

## Planning Boundary

- No repository-stored active work contract exists.
- The complete Chat-approved prompt supplied directly in the current conversation is the sole execution contract.
- Unscheduled work is selected from `Project documents/FUTURE_WORK.MD` after verified state and optional read-only discovery.
- Detailed implementation history remains in Git, accepted ADRs and clearly archived reports.
