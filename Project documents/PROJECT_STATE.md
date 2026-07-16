# Repository State

- Primary branch: `main`.
- Latest verified completed increment: Sprint 43 — Honest Import Lifecycle.
- Latest relevant implementation commit: `4f120d18e406f1b06675397c269fa90e4fd80e09` — Preserve pre-confirmation cancellation in Sprint 43.
- Current migration: V4, including the bounded `import_attempts` ledger.
- Current accepted ADR: ADR-034 — Document-Scoped Card Statement Evidence.
- Architecture baseline: Architecture v1.0 Frozen and UI/UX v1.0 Frozen.
- Build state: clean Debug build passing for Sprint 43.
- Latest verified automated result: 229 tests in 33 suites, 0 failures, 0 skipped. Generic `LedgerForgeUITests` remained intentionally disabled.

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
- ADR-033 accepts the deterministic Money and native-currency integrity architecture. The read-only INR compatibility audit passed with compatibility requirements: zero blocking findings, exact decimal/minor agreement and 76 legacy decimal strings requiring exact backward-compatible reading. No migration or repair is required. Money implementation is ready for future planning but has not started; grouped native-currency presentation and production non-INR support remain pending.
- ADR-034 accepts document-scoped card-statement evidence subordinate to ADR-033. Card evidence, persistence, production parsing and institution support remain unimplemented and independently gated.
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
- The read-only INR compatibility audit passed against the canonical V4 database with 2 accounts, 81 trusted transactions, INR-only booked currency, zero blocking findings and unchanged database, WAL and SHM surfaces. Of 81 decimal strings, 5 use canonical two-fraction-digit formatting, 73 omit the fractional separator, 3 use one fractional digit and 0 are negative zero; decimal/minor disagreements are 0. Legacy plain decimal strings remain readable only with exact minor-unit agreement; no migration, repair or historical rewrite is authorized.
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
