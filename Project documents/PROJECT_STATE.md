# Repository State

## Repository Baseline

- **Primary branch:** `main`
- **Current pushed ref:** the single Sprint 54 completion commit containing this state update; its exact SHA is Git-authoritative and recorded in the completion report
- **Latest verified implementation:** the single Sprint 54 completion commit containing this state update — Durable Import-Outcome Presentation Exhaustiveness
- **Non-implementation commits after Sprint 53:**
  - `bdb51b0ddcdde097e456a16bab7f0bf999fd595b` — roadmap update
  - `7ee20a909038d1088f830a6ea588311625f415e5` — planning reconciliation and tracked Xcode user-data removal
  - `de238d8abf5ee7dc7d1eb9cd13fab72803f2be28` — roadmap update after the discovery campaign
  - `a64c2d8d67e93631d8b0c32620ded72f389f252f`, `98b1fef111087d3b8c2b26f8c354c2147c6b2412` and `f50127ccb7ddf05641df1af7a14a93be2ea8b42e` — subsequent roadmap updates
- **Latest verified completed increment:** Sprint 54
- **Latest accepted ADR:** ADR-039 — Trusted Statement Dates and Durable Source Provenance
- **Current migration:** V6
- **Architecture baseline:** Architecture v1.0 Frozen and UI/UX v1.0 Frozen
- **Latest verified repository-maintenance change:** `7ee20a909038d1088f830a6ea588311625f415e5`
- **Latest verified implementation-adjacent maintenance repair:** Axis NRE CSV source-fidelity correction and deterministic header-semantic column mapping
- **Latest recorded automated result:** 400 top-level tests across 48 suites, 0 failures and 0 unexpected skips at the Sprint 54 implementation baseline
- **Latest focused Sprint 54 results:** 18 presentation tests across 1 suite and 86 related model, history, hydration, engine, Dashboard and privacy tests across 7 suites, all with 0 failures and 0 unexpected skips
- **Latest recorded build and analysis result:** fresh clean Debug and explicit `-O` whole-module Release builds plus Debug and Release static analysis passed with zero errors or analyzer findings at the Sprint 54 implementation baseline; clean builds emitted Xcode's non-product AppIntents metadata-extraction warning because the target has no AppIntents dependency
- **Generic UI-test state:** `LedgerForgeUITests` remains intentionally disabled
- **Sprint 54 runtime verification:** representative durable successful, known non-success and hostile unknown presentation was unavailable through an existing deterministic approved runtime route; no fixture launcher or runtime-injection infrastructure was added, and the presentation boundary is established by exhaustive automated tests

GitHub establishes pushed repository state only. It does not establish local worktree cleanliness, linked worktrees, local branches, stashes, staged or unstaged changes, untracked files or unpushed commits.

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
version 1
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

The active chain ends at V6.

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

A supported overlap blocks the complete incoming statement. LedgerForge does not silently omit overlapping transactions. Explicit partial-overlap import remains future work.

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

No rollback, resumable import job, batch queue or cancellation after confirmed persistence exists. Confirmed-persistence retry remains unsupported pending typed authoritative safety evidence.

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

`Completed Imports` counts hydrated durable attempts that are committed `successful_import` outcomes with both an import session and a document. Duplicate, failed, rejected and cancelled attempts do not increment it. Non-durable or unavailable persistence displays `Unavailable`.

### Development database lifecycle

Sprint 45 Phase A provides a DEBUG-only `DevelopmentDatabaseLifecycleCoordinator` and activity gate.

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

Lifecycle operations are excluded while any of the following is active:

- import preparation;
- prepared confirmation;
- confirmed persistence;
- hydration or reload;
- repository writes;
- another lifecycle operation.

Permanent reset, temporary sessions, recovery controls and approved-fixture controls are compile-time absent from optimized Release builds.

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

### Test and runtime limits

- Generic UI tests remain intentionally disabled.
- Supported UI behavior relies on the documented automated and manual acceptance boundaries.
- Manual launches can attach to a stale DerivedData build when multiple LedgerForge processes exist.
- No repository-owned deterministic singleton kill/build/run entry point currently exists.
- The permanent singleton launch and macOS smoke-validation workflow remains future maintenance work.

---

## Approved Fixture Evidence

Fixture integration supplies discovery and regression evidence. It does not by itself establish production support.

### Axis bank-account evidence

Approved evidence includes:

- Axis NRE CSV;
- source-faithful Axis NRE PDF;
- supplied shared-layout Axis NRO CSV;
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

- A read-only backlog-readiness campaign inspected `main@bdb51b0ddcdde097e456a16bab7f0bf999fd595b`.
- The campaign performed no build, test, runtime, migration, ADR or implementation work.
- A subsequent full audit reviewed all 155 numbered `FUTURE_WORK.MD` candidates against:
  - the current pushed repository;
  - `PROJECT_STATE.md`;
  - accepted ADRs;
  - completed sprint evidence;
  - current fixture inventory;
  - recent repository history.
- The audit corrected material readiness and dependency drift without authorizing implementation.
- Fixture-backed HDFC, CBQ and card families are eligible for targeted discovery but remain blocked from implementation by their selected source-format and domain contracts.
- `FW-P1-18 — Binary-Document Fingerprint Semantics` is ready for Chat architecture planning.
- `FW-P1-10 — Production PDF Statement Support` remains blocked until the `FW-P1-18` authority is approved.
- `FW-P2-20 — Category Model and Management` remains ready for planning with an expected additive V7 migration, subject to its UI supplement and current-baseline execution planning.
- `FW-P1-37` and `FW-P1-40` remain ready for planning as one possible bounded DEBUG-only import-verification outcome.
- Repair and reversal families whose shared ADR-037 and lifecycle prerequisites are complete are eligible for targeted family-specific discovery, not broad implementation.
- `FW-P0-24 — Durable Import-Outcome Presentation Exhaustiveness` is complete and no longer remains in the unscheduled queue.
- No implementation is authorized.

---

## Planning Boundary

- `PROJECT_STATE.md` records verified repository reality.
- `FUTURE_WORK.MD` is the canonical unscheduled planning queue.
- Accepted ADRs govern architecture.
- The private sprint roadmap is a non-authoritative Chat-user planning aid.
- No repository-stored active work contract exists.
- The complete Chat-approved prompt supplied directly in the current conversation is the sole execution contract.
- Before Codex execution, local branch, HEAD, divergence, worktree, branch, stash and linked-worktree safeguards must be verified.
