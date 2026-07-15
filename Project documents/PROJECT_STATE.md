# PROJECT STATE

This document is the permanent, authoritative handoff between development sessions.

It records only verified project state. Temporary planning, implementation notes, build logs and reasoning belong in `Project documents/Codex response.md`.

Principles:
- Facts only.
- Repository-verifiable information only.
- Minimal manual editing.
- Updated only after successful build, required validation, commit, push and tag when applicable.

# Current Project State

## Repository

* Primary Branch: main
* Latest Implementation Commit: 0b387a6812542f41eea450aa0bcc7f9d74d077e0 — Implement Sprint 41 Axis UPI duplicate blocking
* Latest Evidence Commit: 416fc88 — Prepare Sprint 40 transaction-event evidence
* Latest Documentation Handoff Commit: 7946483f66b18e3735749069ea7ad57812a43a18 — Finalize Sprint 41 documentation handoff
* Latest Tag: sprint-21
* Sprint 26 Documentation Alignment Commit: 70a8cc1
* Latest ADR: ADR-032 — Durable Import Attempt History and Rejected-Outcome Semantics (Accepted for Sprint 42; implementation not started)
* Architecture Baseline: Architecture v1.0 Frozen / UI_UX v1.0 Frozen
* Current Milestone: M7 — Dashboard Experience
* Current Sprint State: Sprint 42 — Durable Import Attempt History (sole ACTIVE sprint; implementation not started)
* Current Phase: Sprint 42 planning approved; implementation not started; Sprint 41 remains the latest completed and verified sprint
* Build Status: Passing
* Validation Status: Sprint 41 clean Debug build passed; complete configured unit/integration plan passed (175 tests in 26 suites, 0 failures, 0 skipped). Generic `LedgerForgeUITests` remained intentionally disabled.
* Latest Maintenance Commit: 481185a — repository DTO Equatable conformances explicitly made nonisolated while preserving `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
* Latest Verified Implementation Remote: 0b387a6812542f41eea450aa0bcc7f9d74d077e0
* Latest Verified Evidence Remote: 416fc884c888982f996b01256fb99b70bcae6c78
* Latest Verified Repository Remote: 7946483f66b18e3735749069ea7ad57812a43a18

## Bootstrap

The authoritative bootstrap order is defined in:

`Project documents/.github/Context_Manifest.yaml`

Approved bootstrap order:

1. Project documents/.github/Context_Manifest.yaml
2. AGENTS.md
3. Project documents/Project_Guide.md
4. Project documents/PROJECT_STATE.md
5. Project documents/Implementation.md — ACTIVE sprint only

Additional documentation is loaded only when required by the Task Routing Guide.

## Current Pipeline

ImportCoordinator
↓
PasswordProvider
↓
ReaderRegistry
↓
Reader
↓
RawDocument
↓
Institution Detection
↓
Statement Classification
↓
Parser Selection
↓
Statement Parser
↓
FinancialDocument
↓
Validation
↓
Read-Only Advisory Exact-Statement Duplicate Evaluation
↓
User Review & Explicit Confirmation
↓
Same-Process Serialized Authoritative Exact-Statement Duplicate Recheck
↓
Financial Identity Resolution and Account Decision
↓
Provider-Owned Atomic Import-History Persistence
↓
Repositories
↓
SQLite
↓
RepositoryStoreHydrator
↓
Runtime Stores
↓
ViewModels
↓
Views

For parser-verified eligible Axis UPI rows only, confirmation canonicalizes account-scoped event identity and authoritatively checks durable ownership before supported writes. Accepted event ownership is included in provider-owned atomic import-history persistence; exact-content duplicate handling remains a separate ADR-030 authority.

## Current Work

Active Work: Sprint 42 planning is approved and recorded as the sole ACTIVE contract; implementation has not started.

Verified planning state:

* Sprint 40 verified two genuine independent overlapping Axis CSV exports with the same private structured full account identifier, 30 complete shared rows, 51 baseline-only rows and one later-only row.
* ADR-031 accepts only account-scoped, parser-owned Axis UPI evidence under proposed algorithm `ledgerforge.transaction-event.axis-upi-reference.v1`, with deterministic operation and posting-versus-credit-adjustment subtype separation.
* IMPS, NEFT, e-commerce, unstructured, reversal and refund event identity remains unsupported pending additional family-specific source evidence.
* One privacy-safe 31-row overlapping Axis fixture and expected specification are tracked; the approved 81-row baseline remains byte-for-byte unchanged.
* Sprint 40 changed no production Swift, repository API, schema, migration, Xcode project, runtime-store, ViewModel or UI file.
* Focused evidence and regression suites passed (54 tests in 8 suites, 0 failures, 0 skipped); the complete configured unit/integration plan passed (175 tests in 26 suites, 0 failures, 0 skipped).
* Static analysis, clean Debug build, privacy inspection, diff checks and conflict checks passed. Generic `LedgerForgeUITests` remained intentionally disabled.
* Sprint 40 evidence commit `416fc884c888982f996b01256fb99b70bcae6c78` is pushed and remains verified in repository history.
* Sprint 38 remains completed and verified; its implementation history and validation evidence are unchanged.
* Sprint 39 prevents exact re-import of successfully imported reader-produced text using the versioned fingerprint `ledgerforge.raw-text.sha256.v1`. Changed text is not an exact-content duplicate, but remains importable only when no separate authoritative rule, including eligible Sprint 41 event ownership, blocks it.
* Sprint 39 is implemented with bounded prior-import provenance, same-process confirmation serialization and provider-owned atomic import-history persistence.
* ADR-030 remains Accepted and records implementation in Sprint 39.
* Sprint 39 implementation commit `3b4b2ec76c0aca86d9e065182e201740cef829bd` is pushed and remains verified in repository history.
* Focused Sprint 39 suites passed (45 tests, 0 failures, 0 skipped); financial regressions passed (18 tests, 0 failures, 0 skipped); DeveloperDiagnostics passed (14 tests, 0 failures, 0 skipped); complete configured unit/integration test plan passed (171 tests, 0 failures, 0 skipped).
* Generic `LedgerForgeUITests` remains intentionally disabled and did not execute. Sprint 39 UI behavior was manually verified; the same-reset-database UI relaunch limitation remains, with durable provider recreation covered automatically.
* Sprint 39 targets same-process serialization and atomic document/fingerprint/import-session/transaction commit only; cross-process guarantees and broader cross-repository atomicity remain future work.
* No schema migration was required for Sprint 39.

## Approved Sprint 42 Planning State

* Sprint 41 remains the latest completed and verified sprint. Its implementation history, automated validation and manual verification record remain unchanged.
* ADR-032 — Durable Import Attempt History and Rejected-Outcome Semantics is accepted for Sprint 42 implementation.
* Sprint 42 — Durable Import Attempt History is the sole ACTIVE sprint. It will persist and present privacy-safe, read-only supported import outcomes without treating rejected content as imported financial history or authorizing corrective mutation.
* Core scope is `FW-P0-07` durable import audit trail and `FW-P1-26` global import-session history. Narrowed scope is read-only supported duplicate review (`FW-P1-25`), supported Axis UPI explanation (`FW-P2-12`), bounded guidance (`FW-P1-29`), import-history account-decision provenance (`FW-P0-10`) and import-attempt provenance (`FW-P2-01`). Broader candidate forms remain future work.
* Sprint 42 implementation has not started. Build and test status remain the last verified Sprint 41 results: clean Debug build and 175 tests in 26 suites, 0 failures, 0 skipped; generic `LedgerForgeUITests` remained intentionally disabled.
* No Sprint 42 production, test, schema, migration, fixture or Xcode change is claimed.

## Verified Sprint 40 State

* Both original external Axis exports were readable, structurally valid, non-identical and independently generated. Their private full account identifiers matched and their declared periods overlapped from 16 April through 03 July 2026.
* Thirty complete original rows were shared exactly in ledger order; 51 rows were unique to the baseline and one valid event was unique to the later export.
* Fifteen shared UPI events retained stable structured references. Recurring source patterns retained distinct references. One UPI token was reused by a posting and credit-adjustment pair, proving token-only identity unsafe and requiring deterministic source subtype.
* The accepted ADR boundary is prospective, account-scoped Axis UPI only. Missing or malformed evidence does not prove novelty, and weak financial or presentation fields remain ineligible.
* The sanitized derivative reuses the approved baseline's fictional metadata and 30 shared sanitized rows exactly. The one later-only row uses new fictional instrument and narration values while preserving all financial values and ordering.
* Privacy inspection found no original account metadata, candidate references, complete long narrations, source paths or mapping material in tracked changes.
* Sprint 40 prepared the evidence and ADR boundary subsequently implemented by Sprint 41.
* Evidence commit: `416fc884c888982f996b01256fb99b70bcae6c78` — Prepare Sprint 40 transaction-event evidence.

## Verified Sprint 41 State

* `AxisBankAccountParser` produces evidence only for exact `UPI/P2A|P2M/<12 ASCII digits>/...` rows, with debit-only `posting` and credit-only `credit-adjustment` subtype. Malformed or unsupported rows retain their financial transaction with no evidence.
* `ledgerforge.transaction-event.axis-upi-reference.v1` canonically length-prefixes algorithm, immutable repository account ID, `axis-upi`, operation, reference and subtype, then persists only its lowercase SHA-256 digest with the algorithm.
* Migration V3 creates `transaction_event_identities`; SQLite and In-Memory providers batch-look up ownership and atomically persist accepted event records with document, import-session and transaction provenance.
* Incoming repeated eligible identity, existing event ownership and ownership conflict block the whole statement before supported writes. Blocked imports do not hydrate runtime state and rejected attempts are not persisted.
* Exact-content duplicate behavior remains separate. Unsupported non-UPI families remain unevaluated; no historical backfill, cross-process safety or external-writer safety is claimed.
* Manual UI/runtime verification completed on 16 July 2026 using approved sanitized fixtures and isolated development-reset SQLite providers. Baseline-first persisted 1 account and 81 transactions; exact re-import remained an ADR-030 prior-statement outcome; overlap-second was blocked with counts unchanged. Reverse order persisted 1 account and 31 transactions, then blocked the baseline with counts unchanged.
* No partial persistence or post-rejection hydration was observed. Accepted imports hydrated runtime state, blocked outcomes remained bounded, diagnostics exposed no identity digest or canonical payload, and unsupported rows remained part of otherwise accepted statements without a universal duplicate-safety claim.
* Provider-recreation manual verification was blocked by the documented development-reset relaunch limitation: relaunch restores the primary database instead of reopening the temporary reset provider. No production database-selection behavior was changed; durable provider recreation remains covered by the prior automated Sprint 41 verification.
* No executable files changed during manual verification. The retained prior Sprint 41 automated result remains a clean Debug build and 175 tests in 26 suites, 0 failures; build and tests were not rerun for this documentation-only verification cycle.
* Sprint 41 implementation commit: `0b387a6812542f41eea450aa0bcc7f9d74d077e0` — Implement Sprint 41 Axis UPI duplicate blocking. The final handoff commit `d0cd356072ad5de3ef9badc23c88039072757b7b` is pushed and verified at `origin/main`.

## Verified Sprint 39 State

* Exact reader-produced text fingerprinting uses `ledgerforge.raw-text.sha256.v1`; filename and path changes do not defeat duplicate detection. Changed text is not an exact-content duplicate, but remains importable only when no separate authoritative rule, including eligible Sprint 41 event ownership, blocks it.
* Advisory duplicate lookup is read-only. Confirmation performs an authoritative duplicate recheck inside same-process serialization before account, identifier, session or transaction mutation.
* Option 3 bounded prior-import provenance reports completion date, persisted transaction count and recoverable account presentation without exposing raw text, full fingerprints or raw identifiers.
* SQLite and in-memory providers atomically persist documents, fingerprints, sessions, transactions and successful completion state; rollback preserves the original database error.
* Duplicate rejection creates no new supported history rows and performs no hydration. New success performs one canonical forced hydration.
* Existing parser, validation, financial and runtime-store behavior remained covered by unchanged regressions and the configured test plan.
* Sprint 39 has no schema, migration, parser, reader, normalizer, DTO, runtime-store, ViewModel or hydrator redesign.

## Verified Sprint 38 State

* Validated `.noMatch` imports carrying exactly one parser-produced verified strong identifier receive read-only advisory review and explicit user choice between Use Existing Account and Create New Account.
* The Import Wizard never preselects an outcome or account and disables confirmation until an explicit choice is made. Choice state is discarded on cancellation and prepared-import replacement.
* Same-workspace accounts with zero identifiers are eligible independent of display name, institution or other presentation metadata. Internal selection uses only immutable repository account ID.
* Confirmation re-runs resolver, identifier and selected-account eligibility checks before writes. A missing choice, stale selection, workspace mismatch, newly identified target or identifier owner change rejects before writes; no missing-choice create-new fallback remains.
* Existing-account selection preserves immutable account ID, metadata and financial relationships, attaches only the verified parser-produced identifier and maps every new transaction to the selected account ID without replacement upsert.
* Create-new selection retains the opaque account-ID policy and existing confirmed persistence path. Both paths present bounded redacted verification and View Account selects by immutable repository account ID.
* `RepositoryStoreHydrator` remains the only persistence-to-runtime boundary. Runtime stores remain unchanged before complete success and one forced canonical hydration follows successful persistence.
* Focused tests passed (70 tests, 0 failures, 0 skipped); complete Xcode-native testing passed (161 test cases, 0 failures, 0 skipped); the Axis CSV financial baseline passed unchanged; both manual account-choice paths, View Account and relaunch restoration passed.
* No schema, migration, DTO, parser, reader, normalizer, repository API, duplicate-detection or cross-repository atomicity change was made. The existing non-atomic persistence limitation remains.
* `Project documents/Implementation.md` remained planning-frozen and unmodified.
* Sprint 38 implementation commit `11a5f47cb8e9cba683f60755be339b4feb9c851c` is pushed and verified at `origin/main`.

## Verified Sprint 37 State

* Account display-name mutation uses one targeted repository operation with In-Memory and SQLite parity; SQLite uses `UPDATE` and preserves unmodeled metadata and relationships.
* Repository account and workspace IDs now survive canonical hydration; hydrated transactions retain repository account and import-session IDs.
* RepositoryStoreHydrator is still the only persistence-to-runtime boundary and now supplies bounded, trusted import-session runtime state and verified-strong, redacted identity summaries.
* AccountsViewModel owns the complete Accounts-page collection, immutable-ID selection, inspector-scoped activity and history, edit state, validation and selection restoration; Dashboard retains its existing three-account summary limit.
* Account display-name edits are non-optimistic: target mutation succeeds before forced canonical hydration, with separate save-failed and saved-but-refresh-failed presentation states.
* Account import history is composed only from trusted transactions carrying both immutable repository references; referenced sessions are loaded once and ordered deterministically.
* No DTO, schema, migration, parser, reader, normalizer, validation, import-persistence, financial-calculation, duplicate-detection or repository redesign was required.
* `Project documents/Implementation.md` remained planning-frozen and unmodified.
* Sprint 37 implementation commit `e0d9440c290fd15890104a088f3c1be7936586c0` is pushed and verified at `origin/main`.

## Current Product Review

### Product Phase

- Foundation: Complete
- Core Desktop Experience: In progress
- Production Ready: Not yet
- Financial Intelligence: Not started
- Investments: Not started
- AI Assistance: Not started

### Verified Strengths

- Permanent desktop application shell implemented.
- Repository-backed Dashboard implemented.
- Accounts and Transactions screens use runtime-store-backed data.
- Confirmation-gated Import Wizard implemented.
- Import Wizard preview and validation panels use independent constrained scroll regions with the action footer outside both scroll areas.
- Import preview and validation review occur before persistence.
- Explicit confirmation is required before financial data is written.
- Cancellation performs no writes.
- Import outcome visibility distinguishes validation and persistence results.
- Exact re-import of successfully imported reader-produced text is blocked by the versioned fingerprint `ledgerforge.raw-text.sha256.v1`.
- Same-process confirmation serialization prevents two identical confirmations in one running process from both persisting financial history.
- Document, fingerprint, import-session, transaction and successful completion records are committed atomically by the provider-owned import-history operation.
- Exact-duplicate rejection performs no supported persistence write and no hydration; successful new import performs one canonical forced hydration.
- Sprint 40 provides privacy-safe overlapping Axis evidence and accepted ADR-031 architecture for prospective account-scoped Axis UPI transaction-event identity.
- Bounded transaction-event duplicate prevention is implemented for parser-verified Axis UPI P2A/P2M evidence; unsupported families remain unevaluated.
- Developer Console is available behind Developer Mode.
- Developer Console can reset the development SQLite provider without restart.
- Runtime Inspector and Repository Summary show runtime account and transaction counts.
- Developer Console uses structured diagnostic entries with levels, categories, timestamps, sequence numbers and optional metadata.
- Developer Console displays newest diagnostics first while preserving chronological stored history.
- Developer Console hides Debug entries by default.
- Developer Console level filtering, category filtering and combined filtering are implemented.
- Developer Console search operates after filters and searches message plus visible metadata.
- Developer Console `Copy All` copies complete chronological diagnostic history.
- Developer Console `Clear` removes diagnostics and resets diagnostic presentation state only.
- Developer Console `Reload Data` uses canonical forced hydration.
- Developer Console destructive and utility controls use full visible hit targets.
- Import diagnostics show concise lifecycle events by default.
- Parser implementation details are available as Debug diagnostics.
- Database reset preserves Developer Mode and non-financial preferences during the active session.
- Reset Development Database switches the running app to a fresh temporary SQLite provider, but the primary database is restored on the next application launch; this is tracked as a current maintenance issue.
- Canonical financial identifier domain types are implemented.
- Deterministic financial identifier normalization is implemented.
- Strong and weak identifier classification is implemented.
- Verification state and provenance representation are implemented.
- Workspace-scoped account identifier repository operations are implemented.
- In-Memory and SQLite repository providers have parity for identifier operations.
- SQLite identifier conflict prevention is transactional through repository logic.
- Deterministic financial identity resolution is integrated into confirmed production import persistence for parser-produced verified strong identifiers.
- Identity diagnostics are concise and redact identifier values.
- Axis CSV parsing produces one verified strong account identifier only from one unambiguous full structured statement-account field.
- Architecture v1.0 and UI/UX v1.0 remain preserved.

### Current Critical Product Issues

- Bounded transaction-event duplicate prevention is implemented for parser-verified Axis UPI P2A/P2M evidence.
- Unsupported event families remain unevaluated; no historical backfill, cross-format identity, duplicate-management workflow, cross-process guarantee or external-writer guarantee exists.
- Broader atomicity across workspace, account, identifier and import-history writes remains unimplemented.
- Cross-process and external-writer import concurrency guarantees remain unimplemented.

### Current Important Product Issues

- IMPS, NEFT, e-commerce, unstructured, reversal and refund transaction-event identity remains unsupported pending family-specific source evidence.
- Some user-facing screens expose developer terminology such as repository or hydration language.
- Toolbar composition varies across major screens.
- Several user-facing controls display `Pending` or `Soon` states that add visual noise.
- Transaction detail presentation does not yet use the available space effectively.
- Reset Development Database does not persist across application restart; reset switches to a temporary SQLite file under Development Resets, but startup bootstrap reconnects to `ledgerforge.sqlite`.

### Current Cosmetic Issues

- Institution logos are not implemented.
- Dashboard charts are not interactive.
- Hover and minor spacing polish remain future work.
- Future sidebar modules remain visibly marked as unavailable.

### Ready for Next Feature Sprint?

Ready for the next planning cycle. No next sprint has been selected.

### Reason

Sprint 41 repository implementation, automated validation, bounded manual runtime verification, documentation synchronization, commit and push are complete. The provider-recreation manual scenario remains constrained only by the documented temporary reset-provider relaunch limitation.

### Current Next-Step Boundary

The next implementation may use only repository-verified and ADR-approved scope. At the current verified baseline:

- prospective account-scoped Axis UPI transaction-event evidence is approved for bounded implementation;
- operation and posting-versus-credit-adjustment subtype separation are required;
- missing or malformed evidence must not prove novelty;
- weak financial or presentation fields remain ineligible;
- historical duplicate repair remains future work;
- duplicate-management UI remains future work;
- IMPS, NEFT, e-commerce, unstructured, reversal and refund event identity remains unsupported;
- PDF, XLS, XLSX, OCR, additional institutions, batch import, analytics, multi-currency and investments remain unscheduled future work;
- broader cross-repository atomicity and cross-process guarantees remain future work.

### Next Major Milestone

When Chat begins the next planning cycle, select future work from `PROJECT_STATE.md`, then `FUTURE_WORK.MD`, followed by relevant architecture evidence. No next sprint is selected here.

---

# Sprint 37

## Objective
Deliver repository-backed account detail, safe display-name editing and account-scoped import provenance without changing import, parser, validation or financial behaviour.

## Status
Implemented, fully tested and manually verified

## Outcome
- AccountRepository now exposes a targeted display-name update with In-Memory and SQLite parity; whitespace-only names are rejected, unchanged trimmed input is a no-op, duplicates and case-only changes are supported, and SQLite uses `UPDATE` rather than replacement upsert.
- SQLite verification confirmed `closed_at` and `created_from_import_session_id`, identifier rows and import-session relationships survive a rename.
- Canonical hydration preserves immutable repository account/workspace references, transaction account/import-session references, trusted import-session summaries and redacted verified-strong identity summaries.
- AccountsViewModel provides complete-account presentation, immutable-ID selection and restoration, selected-account activity, deterministic trusted import history, inline import detail and edit-state protection against draft retargeting.
- AccountMetadataCoordinator performs the target write followed by canonical forced hydration; runtime stores are not mutated optimistically.
- Dedicated Accounts rows are selectable without chevrons; the inspector is selected-account scoped, uses repository-backed account type, omits the Status row and shows safe empty states.
- Xcode diagnostics, static analysis and clean build passed.
- Focused Sprint 37 suites passed: 63 tests, 0 failures, 0 skipped.
- Complete Xcode-native test plan passed: 156 tests, 0 failures, 0 skipped.
- Axis CSV financial regression, `git diff --check` and conflict-marker checks passed.
- Manual runtime verification passed against the existing Sprint 36 SQLite database: one Axis account, 81 transactions, trimmed save, relaunch restoration, scoped import history/detail and original display-name restoration were verified.

## Implementation Commit
`e0d9440c290fd15890104a088f3c1be7936586c0` — Implement Sprint 37 account detail and provenance

## Current Phase
Awaiting Sprint 38 planning

---

# Sprint 35

## Objective
Deterministically extract one verified full Axis Bank account identifier from bounded parser source context while preserving financial and runtime behaviour.

## Status
Implemented and manually verified

## Outcome
- `AxisBankAccountParser` recognises only the supported full structured statement-account-number field in `NormalizedDocument.sourceContext.preTransactionFragments`.
- One unique valid full numeric value produces one verified strong `.institutionAccountId` with `.institutionStructuredField` provenance.
- Repeated identical matches are deduplicated.
- Missing, masked, suffix-only, unrelated, malformed and conflicting evidence returns no identifier without failing the import.
- Identifier extraction is independent of transaction parsing and is used by both parser return paths.
- No source fragment or unredacted identifier is logged.
- Parser selection, institution, 81 transactions, currency, transaction ordering, financial totals, balances, validation and import-preview behaviour remain unchanged.
- No resolver, repository lookup, account reuse, identifier attachment, persistence, schema, DTO, runtime-store, ViewModel, UI or project-file changes were made.
- Xcode diagnostics, static analysis and clean build passed.
- Focused `FinancialDocumentTests` passed: 13 tests, 0 failures, 0 skipped.
- Focused `CSVImportRegressionTests` passed: 5 tests, 0 failures, 0 skipped.
- Complete Xcode-native test plan passed: 140 tests, 0 failures, 0 skipped (`LedgerForgeTests`: 137; `LedgerForgeUITests`: 3).
- Axis CSV financial regression and `git diff --check` passed.
- Manual runtime verification passed; the unchanged read-only preview was cancelled without persistence.

## Implementation Commit
`3b682fc2f0b43979388196b739a38b7f350e2be7` — Implement Sprint 35 verified Axis account identifier extraction

---

# Sprint 36

## Objective
Integrate parser-produced verified strong financial identifiers into confirmed production persistence for deterministic account reuse, new-account identity seeding and failure-gated runtime mutation.

## Status
Implemented and manually verified

## Outcome
- `DefaultImportPersistenceCoordinator` invokes `FinancialIdentityResolver` only after validation passes.
- A uniquely resolved account is reused by immutable repository ID, with its existing account and workspace records preserved exactly.
- A no-match import creates one opaque import-scoped account ID and attaches only verified strong parser-produced identifiers.
- Missing, weak and unverified identifiers neither resolve nor attach.
- Ambiguous and conflicting outcomes fail before repository writes and preserve existing relationships.
- `ImportPersistenceMapper` propagates the coordinator-selected account ID to the account DTO and every transaction DTO; filename-derived account identity was removed.
- Runtime financial-store mutation is gated on successful persistence, and queued legacy account publication completes before repository hydration.
- Existing sequential persistence remains non-atomic; failures after early successful writes may retain those earlier records.
- No parser, reader, normalizer, repository protocol, DTO, schema, migration, runtime-store type, ViewModel, UI or project-file changes were made.
- Xcode diagnostics, static analysis and clean build passed.
- Focused Sprint 36 integration/workflow tests passed: 21 tests, 0 failures, 0 skipped.
- Unchanged identity/repository regression suites passed: 31 tests, 0 failures, 0 skipped.
- Complete Xcode-native test plan passed: 149 tests, 0 failures, 0 skipped (`LedgerForgeTests`: 146; `LedgerForgeUITests`: 3).
- Axis CSV financial regression and approved implementation diff checks passed.
- Manual runtime verification passed for cancellation without persistence, confirmed import, immediate hydration and SQLite restoration after relaunch.

## Implementation Commit
`eab8c885431492d3092f24d1185d71d169f2b1ae` — Implement Sprint 36 verified account resolution

## Current Phase
Awaiting Sprint 37 planning

---

# Sprint 34

## Objective
Carry ordered, bounded and uninterpreted pre-transaction source evidence into the existing `NormalizedDocument` parser input without changing runtime or financial behaviour.

## Status
Implemented and manually verified

## Outcome
- Added immutable `NormalizedDocument.SourceFragment` and `NormalizedDocument.SourceContext` types.
- Added immutable `sourceContext` to `NormalizedDocument` with a default empty value that preserves existing construction.
- Added `CSVNormalizationResult` containing normalized rows and bounded source context.
- Added the context-aware CSV normalization path and retained the existing row-only API as a compatibility wrapper.
- Source fragments preserve exact extracted pre-transaction line content, empty lines, original ordering and one-based source ordinals.
- The first transaction and all later source lines are excluded from source context.
- Invalid or missing normalization prerequisites return empty rows and empty context.
- `ImportEngine` carries the coherent normalization result and passes context unchanged into `NormalizedDocument`.
- No fragment text is interpreted or logged by generic processing.
- Normalized transaction rows, parser selection, parser behaviour, `FinancialDocument` output, validation, persistence, runtime behaviour and financial calculations remain unchanged.
- Axis parser output continues to contain an empty financial identifier collection.
- No parser, reader, schema, repository, persistence, DTO, runtime-store, ViewModel, UI or Xcode project-file changes were made.
- Xcode diagnostics passed with zero issues for the modified Swift files.
- Xcode static analysis passed.
- Xcode clean build passed.
- Focused `CSVImportRegressionTests` passed: 5 tests, 0 failures, 0 skipped.
- Complete Xcode-native test plan passed: 132 tests, 0 failures, 0 skipped.
- Axis CSV financial regression passed with 81 transactions and unchanged approved financial values.
- `git diff --check` passed.
- Manual runtime verification passed; the Axis import preview remained unchanged and cancellation completed without persistence.
- Planning commit: `56ffaec2c4c7c230a54f6b212b90b3659e1cbb17`
- Implementation commit: `5025c8a`
- Full implementation commit: `5025c8ae85a36c71e0d5e97c7cf8d0ff00161095`
- Git push to `origin/main` completed successfully.
- Direct remote verification: `git ls-remote origin refs/heads/main` returned `5025c8ae85a36c71e0d5e97c7cf8d0ff00161095` before the documentation handoff.

---

# Sprint 32

## Objective
Establish LedgerForge's deterministic Financial Identity Foundation without changing production import behaviour, parser behaviour, runtime hydration, UI or existing financial relationships.

## Status
Implemented and manually verified

## Outcome
- Canonical financial identifier model implemented.
- Identifier kinds, strength categories, verification state and provenance are represented.
- Deterministic normalization is implemented and invalid normalized values are rejected.
- Repository contracts now expose workspace-scoped financial identifier operations.
- In-Memory repository provider implements identifier storage, lookup, idempotent writes, workspace isolation and conflict rejection.
- SQLite repository provider reuses the existing `account_identifiers` table.
- SQLite schema version remains 2.
- No migration was introduced.
- SQLite attach behaviour uses `BEGIN IMMEDIATE TRANSACTION`, checks existing workspace-scoped mappings, reuses identical mappings, rejects conflicting ownership, inserts only when safe, commits successful writes and rolls back failed writes.
- Duplicate stored mappings are surfaced as candidate ambiguity rather than collapsed.
- Deterministic `FinancialIdentityResolver` is implemented.
- Resolver outcomes include Resolved, No Match, Ambiguous and Conflict.
- Resolver remains disconnected from production import workflows.
- Concise identity diagnostics were added with redacted identifier values.
- No parser files, `FinancialDocument`, `ImportPersistenceMapper`, `ImportPersistenceCoordinator`, account-ID generation, UI files or runtime stores were changed.
- `Project documents/Implementation.md` was not modified.
- Xcode diagnostics passed with 0 issues for all modified Swift files Xcode resolved.
- Xcode BuildProject passed.
- Focused Sprint 32 tests passed: 15 tests, 0 failures, 0 skipped.
- Complete Xcode-native RunAllTests passed: 127 tests, 0 failures, 0 skipped.
- Manual runtime verification passed.
- Implementation commit: `63c18cc`
- Full implementation commit: `63c18cc990f1fca1931bdb055160c739512c52f3`
- Git push to `origin/main` completed successfully.
- Direct remote verification: `git ls-remote origin refs/heads/main` returned `63c18cc990f1fca1931bdb055160c739512c52f3`.

## Follow-Up Maintenance
- Reset Development Database does not persist across application restart because reset switches to a temporary SQLite file under Development Resets while startup bootstrap reconnects to `ledgerforge.sqlite`.

# Sprint 31

## Objective
Transform the existing Developer Console into a cohesive developer diagnostics workspace with structured diagnostic entries, concise import lifecycle logging, filtering, search, newest-first presentation and reusable Developer Console controls.

## Status
Completed

## Outcome
- Plain-string Developer Console storage was replaced with structured `DeveloperLogEntry` values.
- Every diagnostic entry has stable identity, sequence number, timestamp, level, category, message and optional metadata.
- Diagnostic levels are Debug, Info, Warning and Error.
- Diagnostic categories are Application, Import, Parser, Validation, Database and Runtime.
- Stored diagnostic history remains chronological.
- Developer Console presentation displays newest entries first without renumbering sequence numbers.
- Debug diagnostics are hidden by default.
- Selecting Debug reveals existing parser diagnostics.
- Level filtering, category filtering and combined filtering are implemented.
- Case-insensitive search applies after filters and searches message plus visible metadata.
- Copy All copies complete stored diagnostic history in chronological order.
- Clear removes diagnostic entries and resets diagnostic search/filter state only.
- Import lifecycle logging is concise by default.
- Parser internals are emitted as Debug / Parser diagnostics.
- Runtime Inspector remains accurate.
- Repository Summary remains accurate.
- Reload Data remains functional through `RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)`.
- Reset Development Database remains functional through existing app reset wiring.
- Full visible Developer Console button hit targets were manually verified.
- Dashboard, Accounts, Transactions, Imports and financial calculations remain unchanged.
- No parser, validation, repository contract, runtime-store contract, SQLite schema or financial calculation changes were made.
- Xcode diagnostics passed with 0 issues for resolvable modified Swift files.
- Xcode diagnostics could not directly resolve `LedgerForge/Services/Services/ImportEngine.swift` by project path, but Xcode build compiled it successfully.
- Xcode build passed.
- Active Xcode test plan passed: 112 tests, 0 failures, 0 skipped.
- Manual runtime verification passed.
- Implementation commit: `274e1f5`
- Full implementation commit: `274e1f5e8f1f6a90d0701442c8f7fb0286ec2c5b`
- Git push to `origin/main` completed successfully.
- Remote verification: `git ls-remote origin refs/heads/main` returned `274e1f5e8f1f6a90d0701442c8f7fb0286ec2c5b`.
- Documentation handoff commit: `c86d360`
- Full documentation handoff commit: `c86d360ae2ce63bb31b22928e6368307193bd7be`
- Final remote `main` verification returned `c86d360ae2ce63bb31b22928e6368307193bd7be`.

---

# Sprint 30

## Objective
Expand the existing Developer Console into a safe internal testing and diagnosis surface for database reset, runtime inspection, repository summary, log management and canonical data reload.

## Status
Completed

## Outcome
- Developer Mode exposes the completed Developer Console foundation.
- `Reset Development Database` is available inside the Developer Console only.
- Reset is destructive/red and protected by an explicit confirmation dialog.
- The full visible rounded rectangles of `Copy All`, `Clear`, `Reload Data` and `Reset Development Database` are clickable.
- Cancelling reset leaves database path, accounts, transactions, Dashboard, Developer Mode and preferences unchanged.
- Confirming reset installs a fresh SQLite provider without restart.
- Reset uses provider replacement and `RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)`.
- Reset does not delete the old active SQLite file.
- Reset produces 0 accounts and 0 transactions.
- Dashboard, Accounts and Transactions show empty states after reset.
- Runtime Inspector and Repository Summary show 0 accounts and 0 transactions after reset.
- Developer Mode and non-financial preferences remain preserved.
- `Reload Data` uses canonical forced hydration and does not restore old data after reset.
- Importing the Axis CSV after reset succeeds, updates the fresh provider and runtime state, and remains persisted after app relaunch.
- Old pre-reset data does not return.
- Log Console plain-text search, `Copy All` and `Clear` are implemented.
- Runtime Inspector displays provider state, hydration status, latest refresh result, account count, transaction count and SQLite path when available.
- Repository Summary displays Accounts and Transactions counts only.
- No parser, reader, validation, repository contract, runtime-store contract, SQLite schema or financial calculation changes were made.
- Xcode diagnostics passed with 0 issues for resolvable modified Swift files.
- Xcode diagnostics could not directly resolve `LedgerForge/Services/Services/ImportEngine.swift` by project path, but Xcode build compiled it successfully.
- Xcode build passed.
- Active Xcode test plan passed: 98 tests, 0 failures, 0 skipped.
- Manual runtime verification passed.
- Implementation commit: `dd248c4`
- Full implementation commit: `dd248c41b011c125e1d0d0b56020b288a6b0b1c1`
- Git push to `origin/main` completed successfully.
- Remote verification: `git ls-remote origin refs/heads/main` returned `dd248c41b011c125e1d0d0b56020b288a6b0b1c1`.
- Documentation handoff commit: `9148c3d`
- Full documentation handoff commit: `9148c3d5c3c928037edaaf267af15bc9592bac4e`
- Final remote `main` verification returned `9148c3d5c3c928037edaaf267af15bc9592bac4e`.

---

# Sprint 29

## Objective
Stabilize Import Wizard usability by keeping long review content scrollable within the wizard workspace while preserving continuously visible action controls.

## Status
Completed

## Outcome
- `ContentView.swift` layout-only change implemented for the Import Wizard.
- Existing wizard stepper/header preserved.
- Import Wizard preview and validation panels use independent constrained scroll regions.
- The action footer remains outside both scroll regions and continuously visible.
- No duplicate footer was introduced.
- Validation gating remains implemented by the existing `ImportPresentationState` flow.
- Cancellation behaviour remains implemented by the existing `cancelPreparedImport()` path.
- No parser, reader, validation, persistence, repository, runtime-store, hydrator, SQLite or financial calculation changes were made.
- Xcode diagnostics for `ContentView.swift` passed with 0 issues.
- Xcode build passed.
- Active Xcode test plan passed: 94 tests, 0 failures, 0 skipped.
- Full visible Cancel and primary-action button hit targets were manually verified.
- The stale no-write completion message is hidden after successful completion.
- Manual runtime verification passed.
- Implementation commit: `bc0af0c`
- Git push to `origin/main` completed successfully.
- Remote verification: `git ls-remote origin refs/heads/main` returned `bc0af0c65f092ad0302543b823d05c6b95120cab`.

---

# Sprint 28

## Objective
Implement the Confirmation-Gated Import Workflow by introducing an explicit review and confirmation boundary between validation and persistence.

## Status
Completed

## Outcome
- Confirmation-gated import workflow implemented.
- Prepared import model implemented as the in-memory bridge between prepare, review and commit.
- Prepare stage performs read, detection, classification, parser selection, parsing and validation without persistence, runtime-store updates or dashboard refresh.
- Read-only import preview implemented in the Import Wizard.
- Validation review implemented before persistence.
- Explicit confirmation is required before persistence.
- Validation failure cannot be persisted.
- Cancellation discards prepared state and performs no writes, runtime-store updates or dashboard refresh.
- Commit uses the prepared `FinancialDocument` and existing `ImportPersistenceCoordinator`.
- Existing post-commit forced `RepositoryStoreHydrator` dashboard refresh preserved.
- Existing Sprint 27 import outcome presentation preserved after commit.
- Xcode build passed.
- Active Xcode test plan passed: 94 tests, 0 failures.
- Implementation commit: `262a07d`
- Documentation handoff commit: `0170b44`
- Git push to `origin/main` completed successfully.
- Local tracking ref note: remote push succeeded; sandbox could not update local `origin/main` ref lock under `.git`.

---

# Sprint 27

## Objective
Make import outcomes explicit in the existing import result panel by showing verified validation and persistence states without changing the import pipeline, financial behaviour or repository architecture.

## Status
Completed

## Outcome
- Import Outcome Visibility implemented in the existing import result panel.
- Successful imports show filename, transaction count, Validation Passed, Persistence Succeeded and View Transactions.
- Validation failures show filename, transaction count where available, Validation Failed, Not Persisted and the existing error message.
- Persistence failures show filename, transaction count, Validation Passed, Persistence Failed and the existing error message.
- View Transactions is available only after successful validation and persistence.
- Existing import execution, validation-before-persistence, repository boundaries and post-import hydration behaviour preserved.
- Focused import outcome presentation coverage added.
- Xcode build passed.
- Active Xcode test plan passed: 89 tests, 0 failures.
- Implementation commit: `152ad12`
- Git push to `origin/main` completed successfully.
- Local tracking ref note: remote push succeeded; sandbox could not update local `origin/main` ref lock under `.git`.

---

# Sprint 26

## Objective
Align repository documentation to the approved Context_Manifest.yaml bootstrap, fix stale references and ensure a clean, fast startup path for assistants without changing source code.

## Status
Completed

## Outcome
- Documentation bootstrap and workflow alignment completed.
- Root `AGENTS.md` confirmed as the authoritative AGENTS path.
- Active documentation aligned through ADR-025.
- Sprint 25 remains the verified implementation baseline.
- Build status remains the last verified Sprint 25 build status.
- Test status remains the last verified Sprint 25 result: 86 tests, 0 failures.
- No source code, tests, project files, database files or assets changed during Sprint 26.
- Documentation alignment commit: `70a8cc1`
- Git push to `origin/main` completed successfully.
- Local tracking ref note: remote push succeeded; sandbox could not update local `origin/main` ref lock under `.git`.
- Await the next ACTIVE sprint in `Project documents/Implementation.md`.

---

# Sprint 25

## Objective
Strengthen account identity foundations by persisting institution attribution, preserving stable repository account IDs, preventing duplicate accounts for the current stable identity path and preparing the import pipeline for future format processing.

## Status
Completed

## Outcome
- Known import institutions now persist through `AccountDTO.institutionId`.
- SQLite account upserts now ensure referenced institution rows exist before storing attributed accounts.
- Repository account IDs remain unchanged and continue to use the existing stable ID components.
- Account display names remain metadata-driven and do not participate in matching.
- Restart hydration now restores account institution and transaction source bank from repository data.
- Repeat imports using the same current stable identity do not create duplicate repository accounts.
- ImportEngine now separates current CSV format processing from orchestration while preserving CSV analyzer, normalizer, parser selection, validation and persistence behavior.
- No automatic account matching, verified-identifier matching service, PDF parsing, OCR, Import Wizard implementation, category engine, rules engine or database schema change was introduced.
- TransactionListViewModel now initializes from the current runtime-store snapshot, preserving search/filter behavior and stabilizing full-suite validation against shared-store timing.
- Xcode build passed.
- Active Xcode test plan passed: 86 tests, 0 failures.
- Implementation commit: `9424d5a`
- Git push to `origin/main` completed successfully.
- Local tracking ref note: remote push succeeded; sandbox could not update local `origin/main` ref lock under `.git`.

---

# Sprint 24

## Objective
Stabilise LedgerForge after Sprint 23 by resolving verified persistence and user-interface behaviour defects without introducing unrelated functionality.

## Status
Completed

## Outcome
- Production startup now configures durable SQLite persistence through `DatabaseProvider.shared`.
- In-memory repository providers remain available for tests.
- Import persistence still writes through `DefaultImportPersistenceCoordinator`.
- Startup and post-import runtime restoration still flow through `RepositoryStoreHydrator`.
- Import completion now displays success/failure state, imported filename, transaction count and `View Transactions`.
- Sidebar rows and Credit/Debit controls now use full visible hit targets.
- Duplicate fake macOS traffic-light controls were removed.
- Placeholder controls now display pending state instead of active menu/action affordances where functionality is not implemented.
- Account display names no longer use raw `.csv` filenames when institution/currency metadata is available.
- Stable repository account identity was preserved.
- No parser, validation, financial calculation, database schema, PDF, OCR or navigation architecture changes were made.
- Xcode build passed.
- Active Xcode test plan passed: 84 tests, 0 failures.
- Implementation commit: `abbef6f`

---

# Sprint 23

## Objective
Extract reusable SwiftUI presentation components from the Sprint 22 interface while preserving the approved UI/UX v1.0 appearance, existing behavior and architecture.

## Status
Completed

## Outcome
- Shared SwiftUI presentation primitives extracted under `Views/Common`.
- `LFTheme`, `LFPanel`, `LFSearchField`, `LFStatusBadge`, `LFFilterChip`, `LFInfoRow`, `LFEmptyState`, `LFCompactEmptyState`, `LFIconTile`, `LFActionRow` and `LFInlineBadge` introduced as reusable components.
- Generic reusable component definitions removed from `ContentView.swift`.
- Duplicated filter, status badge, info row and empty-state helpers removed from `TransactionListView.swift` and `DeveloperConsoleView.swift` where exact visual equivalence was safe.
- `ContentView` remains the application composition root and startup hydration coordinator.
- Developer Console default visibility corrected so it is hidden until Developer Mode is enabled.
- Existing transaction search and credit/debit toggle behavior preserved.
- Import, parser, validation, repository, database, runtime store, ViewModel, financial truth and transaction extraction behavior preserved.
- Xcode-safe project tooling used for new Swift file target membership.
- Focused dashboard/hydrator validation passed: 7 tests, 0 failures.
- Full active validation passed: 77 tests, 0 failures.
- Build passed.
- Implementation commit: `8090de4`
- Git push to `origin/main` completed successfully.

---

# Sprint 22

## Objective
Translate the approved UI/UX v1.0 assets into SwiftUI presentation while preserving the existing LedgerForge architecture and data flows.

## Status
Completed

## Outcome
- Deep Indigo application shell translated into SwiftUI.
- Dashboard, Accounts, Transactions, Import Wizard shell, Settings and Developer Console foundation screens implemented from approved assets.
- Reusable UI presentation helpers introduced, including `LFTheme`, `LFPanel` and `LFSearchField`.
- `TransactionListView` restyled while preserving `TransactionListViewModel` search and credit/debit toggle behaviour.
- `DeveloperConsoleView` restyled while preserving `DeveloperConsole.shared` as the read-only message source.
- Import Wizard remains a shell; full multi-step import workflow remains future work.
- Settings and Developer Console controls remain non-mutating unless behaviour already existed.
- No repository, database, validation, parser, import pipeline, CSV import, hydration, financial truth or transaction extraction changes were made.
- Baseline build passed.
- Post-implementation build passed.
- Focused dashboard/hydrator validation passed: 7 tests, 0 failures.
- Full active validation passed: 77 tests, 0 failures.
- Checkpoint commit: `b7013c6`
- Implementation commit: `eb5e5ee`
- Git push to `origin/main` completed successfully.

---

# Sprint 21

## Objective
Implement the frozen Application Shell defined in `UI_UX_v1.0_Frozen.md`.

## Status
Completed

## Outcome
- Tab-based layout replaced with the approved permanent sidebar and top toolbar shell.
- Dashboard remains the default content view.
- Preview moved out of normal navigation and reserved for the future Import Wizard.
- Developer Console moved out of primary navigation and into the Developer section.
- Existing CSV import, repository hydration, runtime stores, dashboard data and transaction viewer behaviour preserved.
- Import, parser, validation, repository write semantics, financial truth and transaction extraction preserved.
- 77 active tests passed through Xcode.
- Build passed.
- Implementation commit: `539e4a5`
- Documentation report commit: `7430224`
- Git push to `origin/main` completed successfully.

---

# Sprint 20

## Objective
Refine the repository-backed dashboard foundation built in Sprint 19 without changing import, parser, validation or repository semantics.

## Status
Completed

## Outcome
- Dashboard presentation state refined for loading, empty, loaded and failed hydration outcomes.
- `DashboardViewModel` now exposes store-derived account summaries and recent transaction summaries.
- `ContentView` now consumes dashboard presentation state from `DashboardViewModel` while remaining the startup hydration trigger.
- `DashboardViewModelTests` added.
- Existing transaction search and credit/debit toggle behavior preserved.
- Import, parser, validation, repository semantics, financial truth and transaction extraction preserved.
- 77 active tests passed through Xcode.
- Build passed.
- Commit: `d327576`
- Git push to `origin/main` completed successfully.
- Git tag: `sprint-20`

---

# Sprint 19

## Objective
Build the dashboard foundation using repository-backed runtime store hydration.

## Status
Completed

## Outcome
- Repository-backed runtime store hydration implemented.
- `RepositoryStoreHydrator` added.
- Repository read capabilities extended to support dashboard hydration while preserving existing repository semantics.
- Dashboard startup hydrates runtime stores once per application launch unless explicitly refreshed.
- Existing dashboard panel now shows repository-backed account overview and hydration status.
- `RepositoryStoreHydratorTests` added.
- Repository contract coverage expanded for dashboard reads.
- Parser, validation, repository write semantics, UI flow, financial truth and transaction extraction preserved.
- 65 required Sprint 19 regression tests passed through Xcode.
- Build passed.
- Commit: `65b18f7`
- Git push to `origin/main` completed successfully.
- Git tag: `sprint-19`

---

# Sprint 18

## Objective
Clean up repository integration while preserving the parser -> FinancialDocument -> ImportValidator pipeline.

## Status
Completed

## Outcome
- Repository integration cleanup implemented.
- `ImportPersistenceCoordinator` added.
- `ImportPersistenceMapper` added.
- `ImportRepositoryIntegrationTests` added.
- Validation-before-persistence preserved.
- Repository persistence now flows through the approved repository boundary before updating runtime stores.
- Parser, validation, repository semantics, UI behaviour, financial truth and transaction extraction preserved.
- SwiftUI Preview macro blocker resolved using `PreviewProvider` compatibility.
- ADR-022 documents preview compatibility during test builds.
- 60 required Sprint 18 regression tests passed through Xcode.
- Build passed.
- Commit: `9773b72`
- Git push to `origin/main` completed successfully.
- Git tag: `sprint-18`

---

# Sprint 17

## Objective
Refine the validation pipeline while preserving the parser-produced FinancialDocument boundary introduced in Sprint 16.

## Status
Completed

## Outcome
- Dedicated ImportValidator regression tests added.
- Empty import validation behaviour verified.
- FinancialDocument validation equivalence to transaction validation verified.
- Valid FinancialDocument validation verified.
- Validation immutability verified.
- ImportValidator production implementation left unchanged because tests exposed no real implementation issue.
- Approved Axis CSV financial truth remains unchanged.
- Existing parser, repository, store and UI behaviour preserved.
- 53 required Sprint 17 regression tests passed through Xcode.
- Build passed.
- Commit: `dcac92a0d8e5078a3014e7ef52af8917f130940d`
- Git push to `origin/main` completed successfully.
- Git tag: `sprint-17-complete`

---

# Sprint 16

## Objective
Migrate StatementParser so every production parser returns FinancialDocument directly instead of [Transaction].

## Status
Completed

## Outcome
- StatementParser now returns FinancialDocument directly.
- AxisBankAccountParser now returns FinancialDocument while preserving existing transaction extraction behaviour.
- ImportEngine now consumes parser-produced FinancialDocument directly.
- FinancialDocumentBuilder was removed after all production and test references were migrated.
- Approved Axis CSV financial truth remains unchanged.
- Existing validation, repository, store and UI behaviour preserved.
- 46 required Sprint 16 regression tests passed through Xcode.
- Build passed.
- Commit: `7013d99e55a5cdcf750cf5ad783a71168d59ee3e`
- Git push to `origin/main` completed successfully.
- Git tag: `sprint-16-complete`

---

# Sprint 15

## Objective
Introduce FinancialDocument as the canonical immutable handoff after Statement Parser and before Validation.

## Status
Completed

## Outcome
- Immutable FinancialDocument model implemented.
- FinancialDocumentBuilder implemented without financial recalculation.
- ImportValidator gained a FinancialDocument validation entry point that delegates to transaction validation.
- ImportEngine now validates through FinancialDocument after parser execution.
- Existing parser extraction, validation, repository, store and UI behaviour preserved.
- 46 required Sprint 15 regression tests passed through Xcode.
- Build passed.
- Commit: `29c50a9970e74396a7d9be4391efea59b77df4c9`
- Git push to `origin/main` completed successfully.
- Git tag: `sprint-15-complete`

---

# Sprint 14

## Objective
Introduce the deterministic Parser Selection Framework while preserving Statement Classification behaviour and preparing for FinancialDocument Integration.

## Status
Completed

## Outcome
- Deterministic Parser Selection Framework implemented.
- Legacy `StatementParserRegistry` compatibility preserved.
- Axis CSV and PDF parser-selection context validated.
- Unknown institution and unknown statement type handling validated.
- 42 required Sprint 14 regression tests passed through Xcode.
- Build passed.
- Commit: `da117422d47ef9fe6f09fdfe110f88f54182b590`
- Git push to `origin/main` completed successfully.

---

# Sprint 13

## Objective
Introduce the deterministic Statement Classification Framework while preserving Institution Detection behaviour and preparing for Parser Selection.

## Status
Completed

## Outcome
- Deterministic Statement Classification Framework implemented.
- Legacy-compatible statement classification mapping preserved.
- Explainable classification reasons added.
- Unknown and non-text document classification validated.
- Statement Classification regression suite added.
- 46 tests passed across 10 suites.
- Build passed.
- Git tag: `sprint-13-complete`

---

# Sprint 12C

## Objective
Introduce the deterministic Institution Detection Framework while preserving legacy behaviour.

## Status
Completed

## Outcome
- Institution Detection Framework implemented.
- Legacy detector compatibility preserved.
- Axis CSV and PDF detection validated.
- Unknown document handling validated.
- 37 tests passed across 9 suites.
- Build passed.
- Git tag: `sprint-12c-complete`

---

# Sprint 12B

## Objective
Establish approved PDF regression fixtures and verify reader behaviour against deterministic financial baselines.

## Status
Completed

## Outcome
- Approved Axis PDF fixture established.
- Shared financial baseline introduced.
- PDF reader regression suite implemented.
- Build passed.
- Regression tests passed.
- Git tag: `sprint-12b-complete`

---
