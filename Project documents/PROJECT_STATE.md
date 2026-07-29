# Repository State

## Repository Baseline

- **Primary branch:** `main`
- **Current repository implementation baseline:** `main` at the single Sprint 66 completion commit containing this state update; its exact SHA is Git-authoritative and recorded in the closure report
- **Documentation alignment:** Reconciled on 2026-07-30 in that same Sprint 66 completion commit; this document intentionally does not embed its own commit SHA
- **Accepted source-truth repair:** P0 Axis bank-account source-truth restoration is included in the current pushed baseline; this task does not alter parser, fixture or historical financial data
- **Latest verified production implementation:** Sprint 66 typed confirmed-import recovery and truthful validation guidance
- **Latest verified Debug development-tooling implementation:** DBP-01 Developer Database Profiles at `2d86f91dc46b9e88bcdfea65c88ddf671968b388`
- **Non-implementation commits after Sprint 53:**
  - `bdb51b0ddcdde097e456a16bab7f0bf999fd595b` — roadmap update
  - `7ee20a909038d1088f830a6ea588311625f415e5` — planning reconciliation and tracked Xcode user-data removal
  - `de238d8abf5ee7dc7d1eb9cd13fab72803f2be28` — roadmap update after the discovery campaign
  - `a64c2d8d67e93631d8b0c32620ded72f389f252f`, `98b1fef111087d3b8c2b26f8c354c2147c6b2412` and `f50127ccb7ddf05641df1af7a14a93be2ea8b42e` — subsequent roadmap updates
- **Latest verified completed numbered increment:** Sprint 66
- **Accepted Sprint 63 implementation ref:** `7e1345e3817d3c3e91c24f881b962a48279fd73b`
- **Latest accepted ADR:** ADR-041 — Immutable Source Snapshot and Exact Source-Byte Fingerprint Authority
- **Current migration:** V9
- **DBP-01 classification:** Accepted DEBUG-only developer tooling and development-database lifecycle implementation; it is not a production financial capability, production database-profile feature, numbered sprint, Sprint 65, schema migration or personal-v1 adoption
- **Sprint 55A:** Axis Bank Source-Truth Restoration, ending at `f3154dbd13a340714179da7f972a6accdd3aca54`; parallel shared-runtime-store isolation remains Sprint 55 acceptance/test infrastructure
- **Sprint 57A:** Category Reconciliation Closure, complete at `251a547cb44712a789a9ad7b23a4eabca742900b`; no migration was added
- **Sprint 58:** Deterministic Import Verification Workspace, complete at `4547083d4d81edc9b6bcd98c3a8e77ee1538e71a`; DEBUG-only ordinary-path verification with Release containment and an isolated exact-duplicate runtime check
- **Sprint 59:** Accepted ADR-041 as an architecture-only source-snapshot and exact source-byte fingerprint contract; implementation was intentionally deferred to a later increment
- **Sprint 62:** Accepted the ADR-041 immutable source snapshot and exact source-byte fingerprint architecture contract; no production implementation was included in Sprint 62
- **Sprint 63:** Implemented and independently accepted the immutable source-snapshot and exact source-byte fingerprint foundation
- **Sprint 64:** Completed the approved read-only Axis bank-account PDF readiness discovery. The strongest bounded candidate is the two-source account-neutral Axis bank-account PDF v1 family represented by retained NRO evidence. No production, migration, ADR, fixture, database or source change occurred; production PDF support was not established. No user resupply is required. Retained originals remain available for bounded future read-only evidence reconciliation.
- **Sprint 64 blockers:** `BLOCK-PDF-LINEAGE-01` — exact private-original to sanitisation to committed-fixture lineage is not independently provable from retained records; `BLOCK-PDF-ORACLE-BINDING-02` — expected financial data exists but independent derivation and exact row-level binding to each original are not established; `UNCERTAINTY-PDF-DETERMINISM-03` — repeated extraction and multiline grouping are not proven; `UNCERTAINTY-PDF-SOURCE-CLASS-04` — text-based/unlocked was observed, but OCR/password classification is not fully recorded; `UNCERTAINTY-NRE-NRO-GRAMMAR-05` — shared NRE/NRO grammar cannot yet be claimed from lineage-backed evidence.
- **Sprint 66:** Implemented typed confirmed-import recovery, privacy-safe route-specific guidance, wholly fresh preparation for eligible zero-commit outcomes and bounded canonical reconciliation without changing persistence architecture
- **Sprint 60:** Completed the read-only account-outcome explanation contract across the bounded import workflow; no schema or historical rewrite occurred.
- **Sprint 61:** Implemented privacy-safe durable account-outcome presentation and explicit eligible no-match account choice. FinancialIdentityResolver behavior is unchanged: parser-produced strong verified identifiers remain the sole identity authority, and eligible no-match cases require explicit Use Existing Account or Create New Account choice. No automatic account selection was introduced. Prospective successful durable account decisions are `matched_existing`, `user_selected_existing` and `created_new`; rejected outcomes include `account_choice_required`, `identifier_ownership_conflict`, `identity_ambiguity`, `identity_conflict`, `stale_account_choice` and `stale_provider_generation`. Historical `selected_existing` and `resolved_or_created` remain neutral and are not reinterpreted. One shared bounded presentation authority serves preparation, immediate result and Import History; hostile and unknown values fail closed to neutral unavailable presentation. Account IDs, candidate IDs, normalized identifiers, suffixes, filenames, paths, fingerprints, raw codes and unrestricted errors are excluded from account-outcome copy and accessibility text. SQLite/In-Memory parity and rejected-path zero accepted residue were verified. No schema or historical rewrite occurred.
- **Sprint 61 integrated verification:** 466 top-level tests, 498 executions, 39 dynamic-parameter runs, 0 failures and 0 skips; Debug build, explicitly optimized whole-module Release build and Debug analysis passed. Isolated runtime acceptance used the approved sanitized Axis fixture against one fresh namespaced canonical V8 SQLite database. Preview, explicit choice, confirmation, immediate result, live Import History, quit/relaunch and hydration were verified. Runtime persisted and rehydrated 1 account, 4 transactions and 1 durable attempt. The task-owned namespace was removed recoverably after acceptance. No private source or user financial database was used. Manual linking, unlinking, reassignment, repair, account merge/split and raw identifier display remain excluded.
- **Historical repair boundary:** no retained affected historical Axis database is currently identified; no historical repair was performed
- **Architecture baseline:** Architecture v1.0 Frozen and UI/UX v1.0 Frozen
- **Latest verified repository-maintenance change:** `7ee20a909038d1088f830a6ea588311625f415e5`
- **Latest verified implementation-adjacent maintenance repair:** P0 Axis bank-account source-truth restoration; new imports use `axis.bank-account.csv@2`, physical DR is debit/outflow and physical CR is credit/inflow, and header positions remain dynamically resolved
- **Current overlap boundary:** ordinary no-overlap statements remain full imports, exact-content duplicates remain ADR-030 outcomes, and full supported event overlap remains whole-statement blocked; provenance-less mixed-overlap evidence is unsupported and cannot produce a new reviewed partial plan
- **ADR-040/V7 alignment:** reviewed-plan, disposition, attempt-count and hydration structures remain readable and validated, but the former provenance-less Axis partial-import family is suspended; mixed supported overlap currently fails closed
- **Source-byte boundary:** `ledgerforge.raw-text.sha256.v1` remains authoritative for existing CSV history; Sprint 63 operationalizes `ledgerforge.source-bytes.sha256.v1` through one transient immutable `SourceContentSnapshot` and a secondary CSV fingerprint, without establishing production PDF support
- **Sprint 58 duplicate acceptance:** an isolated exact duplicate left accepted transactions, sessions, documents, fingerprints, account state, balance and hydrated presentation unchanged, adding only one durable rejected duplicate attempt
- **Sprint 56 persistence:** Migration V7, immutable reviewed-plan digests, typed row dispositions, explicit attempt counts and strict hydration/relaunch reconstruction remain readable and validated for historical repository state, but no new partial session is authorized without lineage-backed overlap evidence
- **Current exclusions:** unsupported institutions, profiles, currencies, event families, mixed or interleaved overlap, arbitrary omission, fuzzy candidates, ownership override and historical repair remain unavailable
- **Sprint 57 categories:** workspace-owned user categories and one optional current category assignment per trusted imported transaction are durable, hydrated, manually editable and additive metadata only
- **Sprint 57 persistence:** additive Migration V8, SQLite/In-Memory parity, provider-generation protection, canonical hydration, provider reconstruction and SQLite close/reopen verification are implemented
- **Sprint 57 UI:** Settings supports create, rename, archive, restore and permitted delete; transaction detail supports assign, change and clear, and transaction rows display the current category
- **Sprint 57 exclusions:** automatic categorization, rules, suggestions, bulk editing, merge, delete-with-replacement, budgeting, analytics, reports, filtering, tags, splits and import behavior changes remain unavailable
- **Canonical development database:** a disposable canonical database was successfully recreated through the registered migration chain at V9; no private database contents are recorded here
- **Latest Axis source-truth automated result:** 426 top-level tests (458 parameterized executions), 0 failures and 0 skips in the complete signed canonical TestPlan
- **Latest Axis source-truth focused result:** 41 top-level tests (46 parameterized executions), 0 failures and 0 skips across direction, source-oracle, NRO evidence, overlap-quarantine, shared-profile and direct-provider fail-closed suites using SQLite and In-Memory providers
- **Latest Axis source-truth build result:** fresh signed Debug and explicitly optimized Release builds plus Debug and Release static analysis pass
- **Private-source verification:** two read-only NRE originals provide 94 observable conventional row-to-row balance deltas and two read-only NRO originals provide 35; no private source was copied, launched or committed
- **Latest recorded automated result:** 433 top-level tests (465 parameterized executions), 0 failures and 0 skips in the complete signed canonical TestPlan for category reconciliation closure
- **Latest focused category-reconciliation result:** 71 top-level tests (86 parameterized executions), 0 failures and 0 skips across category, hydrator, import-hydration, development-lifecycle and migration-integrity suites
- **Latest recorded build result:** fresh signed Debug and explicitly optimized whole-module Release builds plus Debug and Release static analysis passed for the category reconciliation closure
- **Post-Sprint 57 runtime verification:** an isolated fresh Debug launch created a category, imported the approved sanitized Axis fixture, assigned that category to a trusted transaction, quit/relaunched and verified the category and assignment persisted; the task-owned process was stopped and only its isolated database set was moved to Trash
- **Previous Sprint 55 automated result:** 409 top-level tests across 49 suites, 0 failures and 0 unexpected skips in each of three consecutive exact canonical default-parallel TestPlan runs
- **Latest focused Sprint 55 results:** 41 Axis direction, fixture-oracle and confirmation-gate tests across 5 suites plus 64 adjacent event, validation, repository, atomicity and hydration tests across 6 suites, all with 0 failures and 0 unexpected skips
- **Sprint 55 acceptance closure:** the first completion attempt exposed cross-suite interference between tests mutating shared runtime singleton stores; a bounded test-only asynchronous exclusivity trait now coordinates only those global-state tests across Swift Testing suites, retains ownership across suspension and restores the shared provider generation, runtime financial/history stores, diagnostics and development activity state after success or failure
- **Sprint 55 overlap-period oracle:** retained only as a quarantined synthetic architecture regression; it verifies internal arithmetic and period parsing but cannot authorize production partial import because immutable source lineage is unavailable
- **Previous Sprint 55 build result:** Debug and explicit `-O` whole-module Release builds passed
- **Generic UI-test state:** `LedgerForgeUITests` remains intentionally disabled
- **Sprint 56 test-host isolation:** `TestPlan.xctestplan` explicitly marks the app-hosted test process with `LEDGERFORGE_TEST_HOST=1`; `LedgerForgeApp` selects intentional test memory for that exact marker before resolving any default SQLite path, while unmarked Debug and Release launches retain normal persistence bootstrap
- **Sprint 56 acceptance correction:** strict hydration now cross-checks each partial session against exactly one committed partial attempt and its document, transaction, source, imported, recognized and blocked counts before replacing any runtime store
- **Sprint 56 runtime verification:** no canonical application launch was used; acceptance uses signed app-hosted tests with isolated providers and source/presentation verification
- **Axis source-truth runtime boundary:** no private original or canonical database is launched or copied; automated production-path coverage verifies conventional semantics, rejects contradictory evidence before accepted persistence and exercises SQLite/In-Memory persistence, hydration and reconstruction with disposable providers

GitHub establishes pushed repository state only. It does not establish local worktree cleanliness, linked worktrees, local branches, stashes, staged or unstaged changes, untracked files or unpushed commits.

---

## Current Project Qualification

LedgerForge is a private, single-user finance application that remains work in progress and is not currently used to store real financial data. Every current database is disposable development/test state until the user explicitly declares the personal-v1 adoption freeze.

This qualification reduces backup, preservation and rollout ceremony during current development. It does not weaken deterministic financial semantics, migration correctness, database switching, provider-generation safety or Release privacy boundaries.

Personal-v1 adoption remains undeclared. LedgerForge is not currently an active production financial database or a multi-user product rollout.

---

## Current Production Capability

### Supported import family

Production import support is limited to the verified shared Axis bank-account CSV grammar represented by:

- the approved Axis Bank NRE CSV evidence;
- the supplied shared-layout Axis Bank NRO CSV evidence.

Both use one production `AxisBankAccountParser`.

New supported imports emit:

```text
axis.bank-account.csv
version 2
```

Historical durable provenance using:

```text
axis.nre.csv
version 1
```

remains readable and is never rewritten merely to adopt the neutral forward profile.

No broader Axis NRO, historical Axis layout, PDF, XLS, XLSX, card, HDFC, CBQ, American Express or other institution support is claimed.

### Trusted source semantics

Supported Axis imports preserve:

- dynamic physical source-column position resolution without treating a source header label as a canonical financial role;
- the `axis.bank-account.csv@2` direction contract in which physical DR decreases balance and maps to canonical debit/outflow, while physical CR increases balance and maps to canonical credit/inflow;
- strict date-only financial evidence;
- Axis `Asia/Kolkata` date authority;
- document-scoped source ordinal;
- normalized source-record digest;
- parser-produced profile identity and version;
- durable transaction-to-source provenance;
- source-supported same-document ordering;
- source-supported running-balance interpretation.

Printed transaction dates do not pass through `Foundation.Date`.

### Universal import pipeline

The production path performs:

1. source reading;
2. institution detection;
3. statement classification;
4. parser selection;
5. immutable `FinancialDocument` creation;
6. validation;
7. duplicate and transaction-event evaluation;
8. explicit user review and confirmation;
9. provider-owned persistence;
10. canonical hydration through `RepositoryStoreHydrator`;
11. runtime-store and presentation publication.

Readers own source-format extraction. Parsers own financial interpretation.

### Atomic confirmed import

Sprint 50 routes accepted confirmations through one provider-owned transaction that revalidates:

- provider generation;
- reviewed account and identity decisions;
- identifier ownership;
- exact-content document fingerprint claims;
- supported transaction-event ownership claims;
- the complete accepted financial graph.

SQLite and In-Memory providers return equivalent typed outcomes.

Verified contention coverage includes:

- same-process competition;
- independent providers;
- genuine separate-process SQLite competition;
- one accepted winner;
- truthful losing outcomes;
- zero losing-path accepted financial residue.

The guarantee applies only to approved writers using the registered schema and enabled constraints. Schema-altering, constraint-disabling or corrupting writers remain outside it.

### Persistence and migration integrity

`DatabaseProvider` is the atomic authority for active repositories and typed persistence state.

Production publishes a SQLite repository only after:

- opening succeeds;
- the complete registered migration-chain history validates;
- pending migrations execute successfully;
- the final migration chain revalidates.

The active chain ends at V9. Migration V7 adds explicit partial-attempt counts, durable partial-import summaries and one typed incoming-row disposition per normalized source row for ADR-040. Additive Migration V8 adds workspace-owned categories and a separate restrictive current transaction-category assignment relationship without changing imported financial rows or provenance. Migration V9 adds versioned document-fingerprint authority and the source-byte fingerprint relationship without storing source bytes.

Open, initialization, migration-integrity or migration-execution failure installs centrally rejecting unavailable repositories rather than silently substituting an in-memory repository.

Import preparation, confirmation, hydration and account metadata mutation gate early when persistence is unavailable. Repository operations remain centrally fail-closed.

### Hydration authority

`RepositoryStoreHydrator` is the sole persistence-to-runtime boundary.

Sprint 52A requires hydration to fail before runtime-store mutation when trusted rows contain:

- unsupported financial-date roles;
- malformed or invalid-IANA timezone evidence;
- missing or conflicting source relationships;
- missing, malformed or conflicting parser-profile provenance.

Trusted transaction graphs are accepted only through the provider-owned confirmed-import path. Generic transaction replacement cannot publish trusted imported transactions.

Category definitions and transaction assignments are read with the trusted financial graph, validated before publication and published as one category snapshot. Category mutations reconcile through the same canonical hydrator; runtime category state is not durable authority. A committed mutation whose hydration fails preserves durable repository truth, leaves the last complete runtime snapshot unchanged, blocks later category mutations with a distinct reconciliation-required result, and provides an explicit canonical hydration retry. Provider replacement and lifecycle transitions clear stale prior-generation category state only after replacement hydration succeeds.

### Durable categories and manual classification

Sprint 57 provides user-created workspace categories with stable identifiers, deterministic normalized-name uniqueness and archival state.

Settings supports create, rename, archive, restore and deletion only when unused. Transaction detail supports one manual category assignment, change or clear for a persisted trusted transaction. Archived categories retain existing assignments but cannot receive new ones.

The assignment is stored in a separate relationship. Changing it does not update transaction amounts, dates, balances, identifiers, normalized rows, import sessions, provenance or parser output. SQLite and In-Memory providers enforce equivalent behavior, and deletion remains restrictive while a category is assigned.

Automatic categorization, rules, suggestions, bulk assignment, merge, delete-with-replacement, hierarchy, tags, splits, filters, budgeting, analytics and reports remain future work.

### Financial identity

Parser-owned verified identity resolution supports the approved Axis bank-account path.

Distinct parser-produced full institution account identifiers retain distinct durable accounts. Shared customer context, profile identity, filenames and neutral presentation labels are not account-identity authority.

The supported workflow provides:

- verified existing-account resolution;
- explicit eligible existing-account choice for bounded no-match cases;
- explicit new-account creation;
- transaction-time identifier ownership enforcement;
- durable accepted-import identifier observations.

Identifier unlinking, reassignment, incorrect-link recovery, contradictory-ownership repair and historical backfill remain separately gated.

### Duplicate and overlap handling

Exact reader-content duplicate protection uses the versioned ADR-030 authority.

Exact-content re-import records a bounded duplicate attempt without creating another:

- accepted import session;
- document;
- account;
- identifier;
- identifier observation;
- transaction.

Bounded parser-verified Axis UPI transaction-event ownership uses ADR-031.

Supported event overlap is currently whole-statement blocked. Ordinary no-overlap statements remain full imports and exact-content duplicates remain ADR-030 outcomes. The former ADR-040 mixed-overlap exception is suspended because its synthetic three-shared/one-later fixture has no immutable source lineage; both providers return unsupported evidence without accepted residue for that shape.

Migration V7, immutable reviewed plans, SQLite/In-Memory commit paths, durable partial summaries and dispositions, strict hydration and bounded UI presentation remain capable of reading and validating historical repository state. They do not authorize a new partial import until immutable source evidence proves a bounded family again. Interleaved overlap, unsupported event families, arbitrary omission, fuzzy matching and historical repair remain unavailable.

Unsupported event families remain unevaluated, including:

- IMPS;
- NEFT;
- e-commerce and card events;
- refunds;
- reversals;
- unstructured references.

### Import history and workflow state

Sprint 42 provides durable, privacy-safe import-attempt history with bounded:

- outcomes;
- coverage;
- account-decision provenance;
- guidance.

Rejected attempts remain distinct from successful import sessions.

Sprint 43 provides:

- deterministic named preparation stages;
- stable active-operation ownership;
- safe pre-persistence cancellation;
- bounded fresh retry for typed source-reading failures.

Cancelled preparation is neither trusted persistence nor durable attempt history.

Confirmed persistence is explicitly non-cancellable and remains repository-owned.

Typed confirmed-import recovery distinguishes wholly fresh preparation for authorized zero-commit outcomes, canonical reconciliation for committed hydration failure, and reconciliation followed by wholly fresh preparation when confirmation was blocked by an earlier reconciliation requirement. Review-required, unknown, malformed, hostile and unavailable outcomes expose no mutation action.

No rollback, compensation, resumable import job, batch queue, retry confirmation, automatic confirmation or cancellation after confirmed persistence exists.

### Financial presentation

Dashboard, Accounts, Transactions and Imports are repository-backed experiences.

Current presentation preserves:

- authoritative transaction `Money`;
- native currency;
- grouped native-currency summaries;
- transaction-specific validation provenance;
- current-workflow precedence;
- deterministic latest durable-attempt selection;
- neutral handling for some unknown latest-activity states.

Mixed-currency values are not combined into one total. FX conversion is not implemented.

Sprint 54 completed `FW-P0-24` with one typed presentation authority for durable import-attempt outcome, coverage and guidance. Dashboard Import Activity, Import History list/detail and affected accessibility presentation use the same exhaustive bounded mapping. Unknown, malformed or future codes produce neutral output without reflecting raw values. Current-workflow precedence and deterministic latest-attempt ordering remain unchanged.

### Settings and repository status

Settings and Developer Console distinguish:

- verified durable SQLite;
- unavailable persistence;
- explicitly selected non-durable Debug or test providers.

They do not expose database paths, raw SQL or raw SQLite errors.

Settings retains:

- functional Developer Mode;
- authoritative repository/runtime information;
- durable Completed Imports truth;
- bundle-derived version/build presentation.

`Completed Imports` counts unique hydrated durable sessions represented by committed `successful_import` or `partial_import_committed` attempts with both an import session and a document. Partial sessions are also counted separately as a subset. Duplicate, repeated, failed, rejected and cancelled attempts do not increment either count. Non-durable or unavailable persistence displays `Unavailable`.

### Development database lifecycle

Sprint 45 Phase A provides a DEBUG-only `DevelopmentDatabaseLifecycleCoordinator` and activity gate.

DBP-01 expands that lifecycle into four explicit DEBUG-only profiles:

- Current Database retains the canonical Debug identity and is selected on ordinary launch;
- Persistent Debug Database uses a separate stable application-owned identity;
- Temporary Session uses a lifecycle-owned process-temporary identity;
- Migration Sandbox uses a lifecycle-owned temporary identity constructed from a registered historical migration prefix.

Profile activation is explicit. Candidate construction, migration and staged canonical hydration finish before one observer-atomic publication of provider generation, runtime stores, active profile and schema metadata. Active lifecycle work blocks switching, and repositories or confirmed-import work captured from a stale generation reject.

Developer Mode is process-local and begins off on every launch. Remembered selection is passive until explicit activation, and disabling Developer Mode commits Current Database before the toggle becomes off. Non-current profiles show a bounded app-wide warning, and the first protected mutation in each non-current provider generation requires process-local, generation-scoped acknowledgement. Switching or reset clears that acknowledgement.

Canonical identities:

```text
Development:
Application Support/LedgerForge/Development/ledgerforge-development.sqlite

Non-development:
Application Support/LedgerForge/ledgerforge.sqlite
```

Permanent Debug reset:

- checkpoints and closes the provider;
- creates and verifies the lifecycle-owned backup;
- coordinates the SQLite, WAL and SHM set;
- recreates the canonical identity through the registered migration chain;
- forces canonical hydration.

Temporary empty sessions use UUID databases under:

```text
Application Support/LedgerForge/Development/Temporary Sessions
```

They affect only the current process and reconnect to canonical data after relaunch.

Automatic recovery restores the verified lifecycle backup. Failed recovery enters lifecycle-unavailable state.

Current Database cannot be reset through profile controls. Non-current reset and recreation remain lifecycle-owned, and arbitrary or symlink-escaping paths are rejected.

Lifecycle operations are excluded while any of the following is active:

- import preparation;
- prepared confirmation;
- confirmed persistence;
- hydration or reload;
- repository writes;
- another lifecycle operation.

All database-profile selection, warning, reset, acknowledgement and approved-fixture machinery is compile-time absent from optimized Release builds. DBP-01 added no migration and changed no financial parser or durable financial semantics.

### Repository metadata hygiene

Commit `7ee20a909038d1088f830a6ea588311625f415e5` removed tracked user-specific Xcode state, including:

- Find Navigator scope state;
- breakpoint-list state;
- scheme-management user state.

Shared Xcode configuration remains distinct from personal IDE state.

---

## Current Verified Limitations

### Production format and institution limits

- Production parser support is limited to the approved Axis bank-account CSV grammar.
- General Axis NRO coverage and additional Axis layouts remain unsupported.
- PDF is a text-extraction and statement-understanding foundation only.
- XLS, XLSX, TXT and OCR are not production-supported.
- HDFC, CBQ, American Express and card-statement production parsing are unsupported.
- No production password-entry or Keychain workflow exists.
- No QAR parser or production QAR import path exists.

### Card limits

ADR-034 accepts a document-scoped card-statement evidence boundary subordinate to ADR-033.

The following remain unimplemented:

- concrete card validation;
- durable card persistence;
- card hydration;
- card migration;
- production card parsing;
- institution-specific card support.

Fixture integration, statement classification, schema capacity or parser candidates do not establish production card support.

### Currency limits

ADR-033 and Sprint 44 provide:

- a compiled currency catalog;
- canonical catalog-scale persistence;
- exact decimal/minor/currency hydration;
- SQLite/In-Memory parity;
- grouped native-currency presentation.

Sprint 44 itself introduced no migration. The repository later advanced to V6 through other work.

The following remain unimplemented:

- exchange-rate storage;
- historical conversion;
- selectable reporting currency;
- converted or consolidated mixed-currency totals.

### Mutation and repair limits

Sprint 50 does not establish a generic financial-mutation executor, rollback system or compensation framework.

The following remain separately governed:

- historical duplicate repair;
- identifier correction and detachment;
- account split or merge;
- import-session reversal;
- transaction deletion or movement;
- broad data-integrity repair;
- bulk transaction mutation.

### Historical compatibility limits

`FT-P0-01` and `FW-P0-21` referred to the same date-only defect. Sprint 52 completed it through ADR-039 and Migration V6.

`FT-P0-02` and `FW-P0-22` referred to the same source-order/provenance defect. Sprint 52 completed it through ADR-039 and Migration V6.

Existing nonempty V5 financial graphs fail closed for explicit pre-production reset rather than receiving reconstructed dates, order or provenance.

Legacy exact-statement fingerprint backfill is not performed from reduced repository data.

Axis bank-account imports accepted with `axis.bank-account.csv@1` from Sprint 55 commit `9598c6de6a701d14b0d4afb37d5adb27e9fc82e0` through the parent of the current P0 restoration commit may contain reversed canonical direction, signed `Money` and direction-dependent UPI subtype. Earlier alternating parser revisions also require provenance-led audit rather than inference. Repository evidence cannot prove which historical databases contain affected rows, so detection and any repair remain a separately gated `FW-P0-08` family. This restoration performs no historical mutation.

### Test and runtime limits

- Generic UI tests remain intentionally disabled.
- Supported UI behavior relies on the documented automated and manual acceptance boundaries.
- Manual launches can attach to a stale DerivedData build when multiple LedgerForge processes exist.
- No repository-owned deterministic singleton kill/build/run entry point currently exists.
- The permanent singleton launch and macOS smoke-validation workflow remains future maintenance work.

---

## Approved Fixture Evidence

Fixture integration supplies discovery and regression evidence. It does not by itself establish production support.

Approved direction evidence now consists of the verified NRO clean-room transaction rows and a privacy-safe, non-reversible NRE semantic derivative. Independent exact-decimal oracles derive direction from physical column occupancy plus running-balance deltas and an independently supplied opening balance. They verify physical DR as debit, physical CR as credit, exact amount/delta agreement, source order, totals and complete reconciliation without consulting production parser output.

The original private statements remain outside Git and are read-only evidence. The available two NRE and two NRO private CSV families independently provide 94 and 35 observable row-to-row balance deltas respectively, all conventional. The legacy 81-row/31-row NRE fixtures and the synthetic partial-overlap pair remain privacy-safe structural fixtures but are explicitly ineligible to establish source truth because their immutable transformation lineage is unavailable.

### Axis bank-account evidence

Approved evidence includes:

- a privacy-safe source-derived Axis NRE CSV semantic regression;
- legacy Axis NRE CSV/PDF structural evidence quarantined from financial-truth acceptance pending source lineage;
- verified clean-room Axis NRO CSV transaction rows;
- Axis NRO PDF and XLS evidence across two overlapping ranges.

The supported production path is CSV only.

The approved NRO runtime evidence preserves two distinct durable Axis accounts from two distinct verified full institution account identifiers.

### Axis card evidence

Clean-room Axis credit-card PDF and XLSX evidence is integrated for two consecutive non-overlapping periods.

The evidence preserves:

- one fictional customer, account and instrument;
- source-observed posted INR;
- distinct PDF and XLSX row sets where the source formats genuinely differ;
- source geometry and workbook structure;
- no invented original-currency or FX evidence.

Axis card PDF/XLSX production parsing remains unsupported.

### HDFC bank-account evidence

Clean-room HDFC NRE and NRO evidence is integrated for:

- annual PDF/XLS pairs;
- recent PDF/XLS pairs;
- legacy XLS periods.

Each approved PDF/XLS pair reconciles against its independent financial baseline.

The evidence preserves verified financial, pagination, geometry and multiline relationships while intentionally not preserving original PDF object identity.

HDFC production parsing remains unsupported. The evidence makes targeted parser/format discovery eligible.

### CBQ bank-account evidence

Clean-room CBQ current-account PDF evidence is integrated for April, May and June 2026.

The periods are:

- contiguous;
- non-overlapping;
- balance-continuous.

They contain 10, 7 and 9 canonical transactions.

The PDFs retain selectable text and preserve declared pagination, dimensions, repeated-header and multiline relationships.

CBQ current-account production parsing remains unsupported.

### CBQ card evidence

Clean-room CBQ credit-card PDF evidence is integrated for four consecutive periods across:

- v1 legacy layout;
- v2 equation-style layout.

The evidence preserves:

- one fictional customer and account;
- primary and supplementary instrument relationships;
- exact transaction assignment;
- posted QAR distinct from original merchant amount and currency;
- explicit source-observed fees;
- no invented FX rates, markup, taxes or absent aggregates.

CBQ card production parsing and durable card semantics remain unsupported.

### American Express card evidence

Clean-room American Express card PDF evidence is integrated for two contiguous periods from 24 April 2026 through 23 June 2026.

The periods contain 61 and 34 canonical transactions.

The evidence preserves:

- one fictional customer, account and instrument;
- account-level payments distinct from instrument transactions;
- posted QAR separate from original merchant amount and currency;
- source rewards, legal, pagination, geometry and multiline relationships;
- no invented FX rates, fees, markup or tax.

American Express production parsing and durable card semantics remain unsupported.

---

## Recent Verified Changes

### Sprint 66 — Typed Confirmed-Import Recovery and Truthful Validation Guidance

**Ref**

The single Sprint 66 completion commit containing this state update. Its exact SHA is Git-authoritative and recorded in the closure report.

#### Outcome

Sprint 66 implemented typed confirmed-persistence recovery and truthful validation guidance.

#### Verified production behavior

- Recovery eligibility is a closed typed contract. Localized error strings, filenames, paths and unrestricted errors are not recovery authority; unknown, malformed or hostile errors fail closed to unavailable.
- Eligible zero-commit outcomes may offer only wholly fresh preparation. Fresh preparation re-enters the ordinary retained-URL path, reacquires the source bytes, creates a new immutable snapshot and source-byte fingerprint evidence, and re-runs validation, exact-duplicate, identity, account-choice and provider-generation checks.
- Fresh preparation never reuses a consumed `PreparedImport`, reviewed partial plan, account choice or source snapshot, and never confirms automatically.
- Committed persistence followed by hydration failure offers canonical reconciliation only. Reconciliation refreshes the view without reimporting the statement or duplicating accepted history.
- A pre-existing reconciliation block is distinct from current committed persistence and explicitly records that the current attempt did not save a new import.
- Reconciliation-then-preparation starts wholly fresh preparation only after reconciliation succeeds. A failed reconciliation remains blocked, starts no preparation and does not retry recursively.
- Review-required and unavailable states expose no mutation action. A missing retained source URL suppresses Prepare Again even when the typed route otherwise permits fresh preparation.
- DBP-01 acknowledgement remains required before source acquisition in a non-current Debug profile.
- Process-local action ownership prevents duplicate dispatch, simultaneous preparation and reconciliation, and stale completion publication after a newer action begins.
- Exact-duplicate presentation remains “Previously Imported,” not persistence failure.

#### Persistence and financial boundary

- No schema or migration changed, and no repository or provider API changed.
- No rollback, compensation, resumable job, persisted job, batch queue, cancellation after committed persistence or generalized retry engine was introduced.
- Provider-owned atomic confirmation remains authoritative, and durable commit remains distinct from canonical hydration.
- Rejected zero-commit outcomes leave zero accepted financial residue. A committed hydration failure preserves the accepted commit.
- Reconciliation creates no duplicate account, transaction, session, document, fingerprint, identifier or observation.
- Historical durable guidance remains readable and was not rewritten.

#### Acceptance correction

The first canonical TestPlan run exposed one stale legacy duplicate-presentation test. The test-only correction supplied the typed exact-duplicate route to that previously imported regression case; no production code changed for the correction. The corrected stable implementation state then received the final authoritative acceptance run. This correction occurred before Sprint 66 acceptance and is part of Sprint 66, not Sprint 66A.

#### Acceptance evidence

- The focused four-suite run passed 49 logical tests across 49 executions, with zero parameter runs, failures, skips or expected failures.
- The corrected canonical TestPlan passed 562 logical tests across 607 execution instances and 68 suites, including 55 dynamic parameter runs across 10 parameterized tests, with zero failures, skips or expected failures.
- One fresh Debug build, one optimized whole-module `-O` arm64 Release build and Debug static analysis passed. Only pre-existing Swift 6 transition warnings in unrelated tests and the AppIntents metadata skip remained; no changed file produced a warning.
- Disposable runtime Scenario A verified a zero-commit contention outcome, ordinary-path Prepare Again, new prepared-import and snapshot identities, recomputed source-byte evidence, cleared account choice, explicit confirmation gating and single-dispatch behavior under double activation.
- Disposable runtime Scenario B verified that a committed hydration failure presented saved truth, offered reconciliation only and reconciled without a second preparation or persistence commit.
- Disposable runtime Scenario C verified that a pre-existing reconciliation block saved no current import, failed reconciliation began no preparation or loop, and successful reconciliation then created a wholly fresh preview requiring a new account choice and explicit confirmation.
- Disposable runtime Scenario D verified unavailable, exact-duplicate and missing-retained-URL outcomes with no unauthorized recovery mutation action. The exact duplicate left accepted financial counts unchanged and added only its bounded rejected attempt.
- Disposable runtime Scenario E verified the DBP-01 non-current-profile acknowledgement before source acquisition.
- Runtime SQLite evidence remained confined to the task-owned disposable root, the canonical Current Database was not opened or altered, and corrected automated coverage verified SQLite/In-Memory outcome parity and rejected-path zero accepted residue.
- Build acceptance and Release containment used the normal signed sandboxed products. The isolated interactive runtime walkthrough used a re-signed unsandboxed copy of the passed Debug build solely because sandboxed launch did not honor the task-private home. Executable code was unchanged, but the runtime entitlement environment differed; the walkthrough therefore verifies the accepted code paths under disposable isolation rather than production sandbox-entitlement behavior.
- Release inspection found no CSV, PDF, SQLite, database or fixture payload and no Debug acknowledgement machinery or private recovery material. Task-owned products were moved recoverably to Trash, no generated residue remained in the repository and no LedgerForge or `xcodebuild` process remained.

#### Scope

Sprint 66 changed exactly these implementation and test paths:

- `Services/ImportEngine.swift`
- `Services/ImportPersistenceCoordinator.swift`
- `ContentView.swift`
- `LedgerForgeTests/ImportLifecycleTests.swift`
- `LedgerForgeTests/ConfirmedImportHydrationTests.swift`
- `LedgerForgeTests/PersistenceAvailabilityTests.swift`
- `LedgerForgeTests/SettingsPresentationTests.swift`
- `LedgerForgeTests/ConfirmationGatedImportWorkflowTests.swift`

#### Exclusions

Sprint 66 did not implement retry confirmation, resume of a consumed preparation, rollback or compensation, persisted recovery jobs, batch importing, automatic confirmation, cancellation after committed persistence, generalized retry infrastructure, schema or migration changes, parser or import-format support, production PDF support, or Sprint 65.

### DBP-01 — Developer Database Profiles (Debug Development Tooling)

**Ref**

`2d86f91dc46b9e88bcdfea65c88ddf671968b388`

**Verified scope**

DBP-01 is an accepted DEBUG-only developer-tooling and development-database lifecycle implementation. It provides Current Database, Persistent Debug Database, Temporary Session and Migration Sandbox with explicit lifecycle-owned activation; observer-atomic publication; lifecycle-activity blocking and stale-generation rejection; process-local Developer Mode that starts off on launch; an app-wide non-current warning; first-protected-action acknowledgement per non-current provider generation; and lifecycle-owned non-current reset and recreation. Current Database cannot be reset through profile controls.

All database-profile, warning, reset and acknowledgement machinery is absent from optimized Release. DBP-01 added no migration, changed no financial parser or durable financial semantics, established no production database-profile capability and did not declare personal-v1 adoption. Every current database remains disposable development/test state.

Integrated acceptance verified the complete TestPlan with 547 logical tests, 592 execution instances, 68 suites and 55 parameter runs, with zero failures, skips or expected failures. A fresh Debug build, Debug static analysis and isolated disposable runtime verification passed. No private financial source or personal database was used.

The final bounded Release-containment acceptance separately inspected seven authorized correction paths, passed 44 logical focused tests across 46 executions, passed an optimized whole-module `-O` arm64 Release build and passed direct binary `nm`, `strings` and bundled-resource inspection. No acknowledgement gate, Debug database-profile control, profile label, filename, namespace, sandbox control or fixture payload remained in Release. The complete TestPlan, static analysis and runtime walkthrough were not redundantly rerun after that final compile-boundary correction.

### Sprint 57 — Durable Categories and Manual Transaction Classification

**Ref**

The single Sprint 57 completion commit containing this state update.

**Verified scope**

Sprint 57 adds additive Migration V8 with workspace-owned category definitions and one separate optional category relationship for each trusted imported transaction. Categories have stable identifiers, validated names and archival state; Uncategorized is represented by no assignment.

SQLite and In-Memory repositories provide equivalent create, rename, archive, restore, delete-unused, assign, change and clear behavior. Deletion fails while a category is assigned. Archived categories preserve existing assignments but reject new ones. Provider-generation protection and the development repository-write lease cover persistence and forced canonical reconciliation.

`RepositoryStoreHydrator` reads categories and assignments with the trusted graph, rejects invalid names, duplicates, cross-workspace relationships and non-trusted transaction assignments before publication, then replaces one observer-consistent category snapshot. Provider reconstruction, SQLite close/reopen and V7-to-V8 upgrade verification preserve category metadata and leave existing imported financial/history truth unchanged.

Settings provides bounded category management. Transaction rows display the current category, and transaction detail provides assign, change and clear. The first category may be created before an import by establishing the default Personal workspace through the existing workspace repository.

An isolated namespaced Debug launch verified the empty Settings presentation, first-category creation and category survival after a full quit/relaunch. The task-owned process was terminated and the isolated database set was moved to Trash without opening or changing the protected canonical Debug database.

The post-Sprint 57 reconciliation closure adds no migration and preserves the immutable imported financial transaction boundary. Category reconciliation failure injection, blocked mutation zero-write behavior, retry, provider-generation replacement and target-wide category-state cleanup are covered by focused tests.

The closure also verified the normal isolated runtime path: Verified SQLite startup, category creation in Settings, sanitized statement import, transaction assignment, quit/relaunch hydration and persisted assignment presentation. No private source or protected canonical database was opened or changed.

No parser, reader, normalized-row, import-session, transaction financial value, balance, identifier or provenance behavior changed. The dated ADR-036 implementation amendment records the reconciliation closure; no migration was added.

### Sprint 57A — Category Reconciliation Closure

**Ref**

`251a547cb44712a789a9ad7b23a4eabca742900b`

**Verified scope**

Sprint 57A completed category reconciliation closure without a migration. Failure injection, blocked-mutation zero-write behavior, retry, provider-generation replacement and target-wide category-state cleanup preserve the immutable imported financial transaction boundary. The completion state is recorded as complete; no historical financial repair was performed.

### Sprint 58 — Deterministic Import Verification Workspace

**Ref**

`4547083d4d81edc9b6bcd98c3a8e77ee1538e71a`

**Verified scope**

Sprint 58 added a DEBUG-only approved-fixture verification workspace that enters the ordinary URL-driven preparation and confirmation path. Release containment removes the fixture resources and excludes the workspace from Release behavior. The isolated exact-duplicate runtime check preserved accepted transactions, sessions, documents, fingerprints, account state, balance and hydrated presentation, adding only one durable rejected duplicate attempt. Its later bounded build-system correction is recorded as Sprint 58A below.

### Sprint 58A — Debug Fixture Run-Script Sandbox Repair

**Verified scope**

Sprint 58A repaired the `Copy DEBUG approved fixtures` Run Script sandbox contract. The phase now validates and operates only on its two exact declared inputs and two exact declared outputs; directory-level recursive deletion was removed, and User Script Sandboxing remains enabled.

Two consecutive Debug builds using the same DerivedData passed with exactly the two approved fixture files present and matching their source SHA-256 values. Six focused Sprint 58 tests passed with zero failures or skips. Two consecutive optimized whole-module Release builds using the same DerivedData passed with no fixture file, fixture content or approved-fixture launcher payload present; Xcode's empty declared-output parent contained no payload. The canonical TestPlan passed 547 logical tests across 592 execution instances, 68 suites and 55 parameter runs with zero failures, skips or expected failures.

No source fixture, financial behavior, migration, DBP-01 behavior or production capability changed.

### Sprint 63 — Immutable Source Snapshot and Exact Source-Byte Fingerprint Implementation

**Ref**

`7e1345e3817d3c3e91c24f881b962a48279fd73b`

**Verified scope**

Sprint 63 implements the accepted Sprint 62 ADR-041 architecture contract. Preparation acquires one immutable app-owned `SourceContentSnapshot` containing the exact source bytes and `ledgerforge.source-bytes.sha256.v1` fingerprint. CSV retains `ledgerforge.raw-text.sha256.v1` as the duplicate authority and carries the source-byte fingerprint as a secondary fingerprint, with one authoritative fingerprint per document and SQLite/In-Memory Migration V9 provider/schema parity.

The retained snapshot is shared by extraction and fingerprinting, recomputed at confirmation, and consumed exactly once. Successful confirmation, rejection, failure, cancellation and preview supersession deterministically invalidate the snapshot. Acquisition and integrity failures produce bounded rejected outcomes, with no accepted financial residue. Historical source-byte reconstruction and durable source-byte storage are not performed. Production PDF support remains unsupported.

Independent acceptance verified 514 logical tests, 547 executions, 41 parameter runs across 8 tests, 64 suites, 0 failures and 0 skips; Debug, explicitly optimized whole-module Release and Debug analysis passed, with Release/privacy containment passing. No production PDF path was added.

### Sprint 62 — ADR-041 Immutable Source Snapshot Architecture Contract

**Verified scope**

Sprint 62 accepted ADR-041 as the architecture contract later implemented by Sprint 63. It selected `ledgerforge.source-bytes.sha256.v1`, retained `ledgerforge.raw-text.sha256.v1` for existing CSV history, required transient snapshot binding through confirmation and preserved the boundary against historical reconstruction, durable source-byte storage and production PDF support.

### Sprint 59 — Immutable Source Snapshot and Exact Source-Byte Fingerprint Authority

**Ref**

`b661472a58fc24144361322f1853b8001437a3eb`

**Verified scope**

Sprint 59 accepted ADR-041 as architecture only. `ledgerforge.source-bytes.sha256.v1` and one immutable app-owned `SourceContentSnapshot` are prospective requirements shared by extraction and fingerprinting through confirmation; neither is implemented. Existing `ledgerforge.raw-text.sha256.v1` history remains untouched, production PDF support remains unavailable, FW-P1-16 remains blocked and no migration was added.

### Sprint 56 — Explicit Reviewed Partial-Overlap Import

**Current alignment after Axis source-truth restoration:** Sprint 56's persistence schema, provider transaction, hydration and presentation structures remain implemented and readable, but its source-semantic acceptance is invalidated. The three-shared/one-later fixture is quarantined for missing immutable lineage, `axis.bank-account.csv@1` is historical only, and production now rejects mixed supported overlap until lineage-backed evidence authorizes a replacement boundary.

**Ref**

The single Sprint 56 completion commit containing this state update.

**Verified scope**

Sprint 56 accepts ADR-040 and adds additive Migration V7. The parser now owns a required immutable declared Axis statement period using `StatementDate`; the ordinary preview and partial review use that source period rather than transaction extrema.

One bounded prospective family may proceed after provider-backed read-only review: `axis.bank-account.csv@1`, bank-account, INR, one selected existing account, complete valid reconciliation, supported account-scoped Axis UPI evidence on every row, one contiguous recognized prefix and one later unique suffix. Immutable reviewed plans bind provider generation, account, exact fingerprint, profile, period, currency, balances, complete source rows, financial projections, event owners, dispositions and counts through `ledgerforge.partial-import-plan.sha256.v1`.

SQLite and In-Memory revalidate the complete plan atomically. Accepted partial sessions preserve the complete incoming document and normalized source graph, relate recognized incoming rows to unchanged durable transactions, create only unique-suffix transactions, and persist one summary, one disposition per row and one successful partial attempt with explicit counts. Stale, consumed, conflicting and losing paths write no accepted graph.

RepositoryStoreHydrator reconstructs partial summaries, attempt counts, dispositions and recognized source relationships before one observer-consistent store replacement. Missing, duplicate, unknown, cross-document, missing-event, missing-transaction, malformed period/money and count inconsistencies fail closed.

The Import Wizard, Dashboard activity, Import History, account history and Completed Imports presentation distinguish partial sessions. Review surfaces show only privacy-safe period, account, counts, balance evidence, unique impact and row dispositions.

The approved sanitized Sprint 55 fixture pair remains the independent oracle: Source A has four unique supported events; Source B has three recognized events plus one later-only event. Acceptance verifies five total transactions, two documents/sessions, four B dispositions, unchanged recognized transactions with new source relationships and exact-B duplicate resolution.

No canonical app launch or ordinary Debug/Release container access is part of Sprint 56 acceptance. The protected V5 Debug database remains unresolved local-only recovery evidence.

### Sprint 55 — Axis Source-Direction Correction and Partial-Overlap Evidence Closure

**Current alignment after Axis source-truth restoration:** Sprint 55's physical-role naming and dynamic header-position resolution remain useful, but its financial direction conclusion and fixture/oracle acceptance are invalidated. The historical bullets below record what Sprint 55 claimed; current source evidence establishes conventional DR-debit/CR-credit semantics under `axis.bank-account.csv@2`.

Commit:

```text
The single Sprint 55 completion commit containing this state update.
Its exact SHA is Git-authoritative and recorded in the completion report.
```

Sprint 55:

- separated dynamically resolved physical Axis DR/CR source columns from canonical debit/credit roles;
- restored the verified `axis.bank-account.csv@1` contract: physical DR becomes canonical credit with positive `Money`, and physical CR becomes canonical debit with negative `Money`;
- retained the existing parser profile ID/version because this is a source-truth defect correction rather than a new accepted layout;
- corrected sanitised Axis fixture occupancy only where independent running-balance arithmetic established the source semantics, without changing canonical expected financial truth;
- added a privacy-safe derivative of two genuine Axis statements with an independently verified three-shared/one-later-only supported UPI overlap;
- added an expected oracle that does not call production parsing, direction resolution or event-identity code;
- verified posting versus credit-adjustment subtype direction after canonical resolution;
- proved conventional or mixed future semantics fail validation without profile switching, accepted persistence or runtime financial-store residue;
- closed the Axis direction blocker and `BLOCK-PARTIAL-ORACLE-01`;
- passed 41 focused tests across 5 suites, 64 adjacent tests across 6 suites and the canonical 407-test, 49-suite TestPlan;
- passed Debug and explicit `-O` whole-module Release builds.

Migration V6, ADR-039, schema architecture, partial-overlap persistence, review UI and durable partial-import outcomes remain unchanged.

### Sprint 54 — Durable Import-Outcome Presentation Exhaustiveness

Commit:

```text
The single Sprint 54 completion commit containing this state update.
Its exact SHA is Git-authoritative and recorded in the completion report.
```

Sprint 54:

- introduced one typed presentation authority for durable import-attempt outcome, coverage and guidance;
- explicitly presents all 13 known outcomes, both coverage codes and all 8 guidance codes;
- routes Dashboard Import Activity and Import History list/detail through the same bounded semantics;
- removed the separate partial history switch and raw underscore-to-space formatting;
- uses the same bounded outcome text for affected Import History accessibility presentation;
- returns neutral outcome, coverage and guidance labels for unknown, malformed or future codes without reflecting hostile raw values;
- preserves successful transaction-count presentation, current-workflow precedence, valid timestamp ordering, stable equal-timestamp ID tie-breaking and malformed-timestamp behavior;
- passed 18 focused presentation tests across 1 suite and 86 related tests across 7 suites;
- passed the canonical 400-test, 48-suite TestPlan with 0 failures and 0 unexpected skips;
- passed fresh clean Debug and explicit `-O` whole-module Release builds plus Debug and Release static analysis with zero errors or analyzer findings;
- could not perform representative runtime presentation verification because no deterministic approved fixture launcher or injection route exists, and added no infrastructure to bypass that boundary.

Schema, Migration V6, ADR-039, durable raw codes, repository/provider behavior and hydration semantics remain unchanged.

### Sprint 53 — Axis Shared Bank-Account CSV Profile and NRO Identity Closure

Commit:

```text
11035461ce3de0f11ae5262bbc8a38b9639607b2
```

Sprint 53:

- extended the existing Axis bank-account CSV grammar to the supplied NRO evidence;
- retained one production `AxisBankAccountParser`;
- introduced the neutral forward profile `axis.bank-account.csv@1`;
- required exactly one parser-produced profile ID/version pair;
- rejected missing, malformed or conflicting profile provenance before writes;
- preserved historical `axis.nre.csv@1` rows without rewriting;
- reconstructed two sanitized NRO CSV preambles and periods to the shared grammar without claiming byte-for-byte private-source recovery;
- verified independent financial and identity truth;
- verified separate NRE and NRO durable accounts;
- verified exact duplicate and supported overlap behavior;
- verified provider reconstruction, hydration and relaunch;
- completed the 394-test canonical TestPlan;
- passed fresh Debug and optimized Release builds and analysis;
- completed disposable namespaced runtime verification with two accounts, 118 transactions and zero remaining LedgerForge processes.

No migration or ADR changed.

### Sprint 52A — Trusted Hydration and Writer Boundary Closure

Sprint 52A:

- made malformed trusted date-role, timezone, provenance and profile evidence fail hydration before runtime mutation;
- required providers to return actual durable profile ID/version;
- prohibited trusted profile defaults or reconstruction;
- rejected trusted DTOs through generic replacement;
- validated complete normalized source relationships inside confirmed import;
- verified provider-equivalent atomic rejection and zero accepted residue.

V6 remained unchanged.

### Sprint 52 — Trusted Statement Dates and Durable Source Provenance

Sprint 52 implemented ADR-039 and Migration V6.

It introduced:

- strict date-only transaction evidence;
- canonical date-only persistence and hydration;
- document-scoped source ordinal;
- normalized-record digest;
- parser-profile provenance;
- provider-atomic transaction/provenance persistence;
- fail-closed treatment of nonempty V5 financial graphs.

No historical evidence was reconstructed.

### Sprint 51 — Fail-Closed Recognized Axis Evidence

Sprint 51:

- rejected malformed recognized Axis transaction dates;
- rejected malformed, unconstructable or conflicting structured account evidence inside `StatementParser`;
- stopped both failure families before preparation, duplicate lookup, identity review, confirmation or persistence;
- preserved supported valid rows and zero-value behavior.

No migration or ADR changed. No Developer Console filename-redaction behavior was integrated.

### Sprint 50 — Provider-Owned Atomic Confirmed Import

Sprint 50:

- activated Migration V5;
- moved accepted confirmation to the provider-owned atomic path;
- enforced durable identifier ownership;
- recorded accepted-import identifier observations;
- bound prepared imports to provider generation;
- removed the legacy accepted-write authority;
- established provider-equivalent contention outcomes and zero losing-path residue;
- retained canonical post-commit hydration and reconciliation gating.

### Earlier verified foundations

The active repository also includes:

- Sprint 39 exact-content duplicate prevention;
- Sprint 40 approved overlap evidence;
- Sprint 41 bounded Axis UPI event ownership and Migration V3;
- Sprint 42 durable attempt history and Migration V4;
- Sprint 43 truthful preparation stages, cancellation and bounded source-reading retry;
- Sprint 44 Money and grouped native-currency presentation;
- Sprint 45 recoverable Debug database lifecycle;
- Sprint 46 non-destructive workspace/account conflict updates;
- Sprint 47 fail-closed startup and migration-chain verification;
- Sprint 48 truthful Settings cleanup;
- the completed `FW-P0-23` financial-presentation and provenance repair boundary;
- ADR-034 card-statement evidence architecture.

Detailed implementation history remains in Git and accepted ADRs.

---

## Current Planning State

- The current planning alignment is based on the single Sprint 66 completion commit containing this state update, completed Sprints 50–64 and Sprint 66, completed DBP-01 Debug development tooling, Migration V9 and accepted ADR-041.
- DBP-01 is complete and no DBP-01 implementation remains pending. It is a separate post-Sprint-64 Debug tooling increment, not a numbered sprint or Sprint 65; no sprint renumbering occurred.
- Sprint 63 implementation of the ADR-041 source-snapshot and source-byte foundation is complete; no source-snapshot implementation remains in the unscheduled queue.
- `FW-P1-10 — Production PDF Statement Support` is blocked after Sprint 64 discovery by the named lineage/oracle evidence gap. Sprint 65 implementation is blocked; production PDF, OCR, password workflow, generic Axis PDF support and cross-format equivalence remain unsupported.
- `FW-P1-16` remains blocked until two equivalent formats are independently production-supported and a separate equivalence architecture is accepted.
- `FW-P1-40 — Deterministic Approved-Fixture Launcher` was completed by Sprint 58 and is removed from the unscheduled queue.
- `FW-P1-37` retains only broader structured diagnostics work not completed by Sprint 58; its bounded privacy-safe preparation-failure summary and Developer Console fixture-workflow slice is complete.
- `FW-P1-28 — Confirmed-Persistence Recovery and Unsupported Retry` is complete in Sprint 66 and removed from the unscheduled queue.
- `FW-P1-29 — Better Validation Guidance` retains only broader validation education outside the typed immediate-result and recovery guidance completed by Sprint 66.
- Fixture-backed HDFC, CBQ and card families remain eligible for targeted discovery but are not production support.
- `FW-P2-20 — Category Model and Management` is complete in Sprint 57 and removed from the unscheduled queue.
- `FW-P2-21 — Deterministic Categorization Rules` is now eligible for bounded discovery; no rule behavior is implemented or authorized.
- Repair and reversal families whose shared ADR-037 and lifecycle prerequisites are complete are eligible for targeted family-specific discovery, not broad implementation.
- `FW-P0-24 — Durable Import-Outcome Presentation Exhaustiveness` is complete and no longer remains in the unscheduled queue.
- Sprint 66 is the latest completed numbered outcome. Sprint 65 remains blocked by the Sprint 64 PDF lineage and independent-oracle evidence gap, production PDF support remains unsupported and no Sprint 65 implementation prompt is authorized.

---

## Planning Boundary

- `PROJECT_STATE.md` records verified repository reality.
- `FUTURE_WORK.MD` is the canonical unscheduled planning queue.
- Accepted ADRs govern architecture.
- The private sprint roadmap is a non-authoritative Chat-user planning aid.
- No repository-stored active work contract exists.
- The complete Chat-approved prompt supplied directly in the current conversation is the sole execution contract.
- Before Codex execution, local branch, HEAD, divergence, worktree, branch, stash and linked-worktree safeguards must be verified.
