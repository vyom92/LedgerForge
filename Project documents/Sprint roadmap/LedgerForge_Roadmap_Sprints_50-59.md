# LedgerForge Roadmap: Sprints 50–59

## Control

**File purpose:** Private Chat-user planning, roadmap and decision archive  
**Repository authority:** None  
**Execution authority:** None  
**Visible to Work:** No  
**Visible to Codex:** No  
**Stored in GitHub:** No  
**Current repository baseline:** `main@2aa6346fa0b8dc116ba97a6983f205afd0a206d3`  
**Last reconciled:** 2026-07-22  
**Roadmap cycle:** Sprints 50–59

This file is a private forecast and continuity record for Chat and the user. It does not authorize implementation, Git operations, branches, migrations, ADR changes, repository edits, Work investigation or Codex execution.

Current repository evidence always overrides this roadmap. A sprint becomes executable only after Chat revalidates the current repository and supplies one complete, current-conversation execution prompt.

Do not attach, quote or expose this file to Work or Codex. Work and Codex receive only the bounded prompt approved for their immediate task.

---

## Roadmap operating model

### Ten-sprint cycle

This file covers exactly Sprints 50 through 59. After Sprint 59 is accepted, Chat performs the cycle reconciliation and creates a new private roadmap for Sprints 60 through 69.

The roadmap is reconciled after every accepted sprint, but future sprint numbers are not renumbered merely because corrective work is inserted.

### Corrective sprint rule

When Sprint `N` exposes a defect that blocks acceptance or safe continuation, the correction is inserted as Sprint `NA`, then `NB` only when another independently bounded correction remains directly attributable to Sprint `N`.

Example:

```text
Sprint 52
Sprint 52A — blocking correction
Sprint 53 — original planned sequence resumes
```

Later planned sprints retain their numbers. The roadmap records the interruption instead of silently pushing every future sprint down.

Use an `A` sprint only when the issue:

- arose from implementation or verification of the parent sprint;
- blocks acceptance, trusted use or safe continuation;
- has a bounded corrective outcome;
- takes precedence over the next planned sprint;
- is not an unrelated feature.

A newly verified unrelated P0 defect may interrupt the cycle as a standalone integrity sprint. Chat must explain why it is not attached to the preceding sprint.

### Priority override

Verified financial-correctness, persistence, identity, recoverability or privacy defects take precedence over forecast feature work.

When a roadmapped sprint discovers a blocking defect:

1. stop acceptance of the affected outcome;
2. classify the defect against current repository evidence;
3. insert the appropriate corrective sprint;
4. leave later sprint numbers unchanged;
5. resume the roadmap only after the correction is accepted.

Non-blocking findings are added to `FUTURE_WORK.MD` through the normal documentation process and do not automatically interrupt the roadmap.

### Forecast status vocabulary

| Status | Meaning |
|---|---|
| **Complete** | Implemented or concluded, verified and accepted |
| **Discovery complete** | Read-only evidence returned; architecture or implementation still requires Chat decision |
| **Forecast** | Strongest current expected outcome, not selected for execution |
| **Conditional** | Depends on named earlier evidence or implementation |
| **Selected** | Chat completed formal sprint planning and approved an execution prompt |
| **In progress** | Approved Work or Codex run is active |
| **Correction inserted** | An `A/B` sprint temporarily interrupts the sequence |
| **Replaced** | Current evidence invalidated the forecasted outcome |
| **Deferred** | Still valid but moved beyond this cycle |

Only **Selected** or **In progress** may correspond to an execution prompt.

### Reconciliation rule

After every sprint, Chat updates this file with:

- exact ending `main` commit;
- verified outcome;
- deviations from the forecast;
- inserted corrective sprints;
- newly discovered blockers;
- candidate readiness changes;
- any effect on later roadmap entries;
- the verbatim planning and report-review discussion.

The concise roadmap sections at the top remain current. The planning log at the end is append-only.

---

## Active project state

- **Latest completed implementation sprint:** Sprint 51 — fail-closed recognized Axis source-evidence repair.
- **Latest completed planning/discovery sprint:** Sprint 52 — date-only and durable source-order/provenance architecture discovery.
- **Current repository:** one clean `main` workflow, last pushed baseline recorded above.
- **Current migration:** V5.
- **Latest accepted ADR:** ADR-038 — Atomic Confirmed Import and Durable Identifier Ownership.
- **Production parser support:** approved Axis NRE CSV path only.
- **Trusted production import:** suspended.
- **Current RED blockers:**
  - `FT-P0-01` / `FW-P0-21` — Date-Only Semantic Preservation.
  - `FT-P0-02` / `FW-P0-22` — Durable Source Order and Provenance.
- **Current next decision:** approve or reject the combined trusted-transaction date-and-source-evidence architecture, including date-only type, bounded durable provenance, legacy-history policy, cross-document same-day authority and Migration V6 design.
- **Known intentional limitation:** supported partial overlaps currently block the complete incoming statement; bounded partial import remains future work under `FW-P1-25`.
- **Known support boundary:** Axis NRO is not production-supported merely because a structurally similar source can pass through current code.

---

## Ten-sprint overview

| Sprint | Expected outcome | Candidate IDs | Status | Confidence |
|---|---|---|---|---|
| **50** | Provider-owned atomic confirmed import, durable identifier ownership and Migration V5 activation | `FW-P0-05`, bounded `FW-P0-12` slice, ADR-038 | **Complete** | Verified |
| **51** | Fail closed on malformed recognized Axis transaction-date and account-identity evidence | `FT-P0-03`, `FT-P1-04` | **Complete** | Verified |
| **52** | Discover one coherent architecture for date-only semantics plus durable source order/provenance | `FW-P0-21`, `FW-P0-22` | **Discovery complete** | Verified |
| **53** | Accept the combined trusted-transaction date-and-source-evidence ADR and V6 compatibility policy | `FW-P0-21`, `FW-P0-22` | **Forecast** | High |
| **54** | Implement date-only financial evidence, durable source provenance, legacy quarantine and provider-equivalent V6 persistence | `FW-P0-21`, `FW-P0-22` | **Conditional** | High after Sprint 53 |
| **55** | Prove the Axis NRO and reusable Import Profile boundary; decide combine/split for parser-family expansion | `FW-P1-01`, `FW-P1-06` | **Conditional** | Medium |
| **56** | Implement the smallest approved profile-backed Axis NRO parser-family slice | `FW-P1-01`, possible bounded `FW-P1-06` slice | **Conditional** | Medium |
| **57** | Discover explicit partial-overlap review and unique-transaction import semantics | `FW-P1-25`, possible bounded `FW-P2-12` relationship | **Conditional** | Medium |
| **58** | Implement bounded, explicit partial-overlap import without silent transaction omission | `FW-P1-25` | **Conditional** | Medium |
| **59** | Implement durable categories and manual single-transaction classification | `FW-P2-20`, ADR-036 | **Conditional** | Medium |

Forecast confidence decreases with distance. Any verified P0 defect or failed acceptance boundary overrides this sequence without renumbering later sprints.

---

# Detailed sprint cards

## Sprint 50 — Atomic Confirmed Import and Durable Identifier Ownership

### Status

**Complete and verified**

### Outcome

LedgerForge moved accepted confirmation into one provider-owned atomic transaction that revalidates the prepared decision against current repository truth before committing the complete financial graph.

### Candidate and architecture basis

- `FW-P0-05 — Concurrent Import Guarantees`
- bounded successful-confirmed-import slice of `FW-P0-12 — Identifier Backfill Policy`
- ADR-038
- Migration V5

### Delivered boundary

- provider-owned confirmed-import operation;
- transaction-time provider-generation revalidation;
- account and identity-decision revalidation;
- identifier ownership enforcement;
- exact document-fingerprint and transaction-event claim revalidation;
- atomic account, document, session, transaction, identifier and observation persistence;
- SQLite and In-Memory provider-equivalent outcomes;
- same-process, independent-provider and genuine separate-process competition coverage;
- zero losing-path accepted residue;
- post-commit canonical hydration and reconciliation gating;
- Migration V5 activation.

### Explicit exclusions retained

- generic financial-mutation executor;
- historical identifier repair or invented observations;
- unlinking, reassignment or incorrect-link recovery;
- general rollback or compensation framework;
- unrelated parser or product expansion.

### Completion evidence

Sprint 50 is repository-recorded as the implementation of ADR-038's confirmed-import production slice. It is the baseline architecture on which later provenance-bearing imports must build.

### Roadmap effect

Sprint 50 made future provider-atomic transaction provenance possible, but it did not solve date-only semantics, source order or historical provenance.

---

## Sprint 51 — Fail-Closed Recognized Axis Source Evidence

### Status

**Complete and verified**

### Outcome

Recognized malformed Axis financial evidence now fails before preparation, identity review, confirmation or persistence instead of being silently omitted or downgraded.

### Selected defect families

- `FT-P0-03` — malformed dates in recognized transaction rows were silently omitted, allowing truncated accepted imports;
- `FT-P1-04` — malformed, unconstructable or conflicting recognized structured account evidence was silently downgraded to no identifier.

### Delivered boundary

- strict malformed-date rejection for recognized Axis financial rows;
- typed failure for malformed, unconstructable or conflicting recognized account-identifier evidence;
- parser-owned identity authority preserved;
- valid supported rows and supported zero-value behavior preserved;
- failure before fingerprint lookup, identity review, confirmation and persistence;
- zero accepted financial residue on rejection;
- focused, regression, provider-parity and complete-suite verification;
- no migration or ADR change.

### Integration correction

The original Codex branch also contained a Developer Console filename-redaction change. That change was explicitly rejected as unnecessary scope for the current single-user local app and was not integrated into `main`.

Only the approved parser and identity repair was selectively integrated. Repository documentation was recreated separately to describe the actual accepted scope.

### Completion baseline

- approved repair commit on `main`: `e31343d08258cd3e1c0ce3b91c32f6fad71fda4d`;
- synchronized documentation commit: `2aa6346fa0b8dc116ba97a6983f205afd0a206d3`;
- recorded verification: 377 top-level tests, 401 expanded executions, 47 suites, clean Debug and optimized Release builds, Debug and Release analysis with zero findings, four pre-existing `AccountStore.swift` warnings.

### Roadmap effect

Sprint 51 stopped two fail-open paths but deliberately left the broader date-only and source-provenance defects unresolved. Trusted production import remained suspended.

---

## Sprint 52 — Trusted Transaction Evidence Architecture Discovery

### Status

**Discovery complete; Chat architecture decision pending**

### Candidates

- `FW-P0-21 — Date-Only Semantic Preservation`
- `FW-P0-22 — Durable Source Order and Provenance`

### Purpose

Determine whether the two RED defects should be split or combined, identify the smallest safe domain and persistence boundary, and return the architecture decisions required before implementation.

### Work sequence

1. Verify single-`main` recovery gate and exact baseline.
2. Trace source date and row-order evidence from reader through parser, validation, persistence, hydration and presentation.
3. Reproduce timezone drift and provider-order divergence independently.
4. Audit schema capacity, production provenance writes and legacy-history limitations.
5. Compare date-only, provenance and migration options.
6. Recommend combine/split, ADR and acceptance boundaries.
7. Make no repository changes.

### Verified discovery conclusion

Both defects are real and share one trusted-transaction evidence boundary, but neither was implementation-ready at the start of discovery.

The smallest safe sequence is:

```text
Sprint 53 — one architecture/ADR increment
Sprint 54 — one combined implementation increment
```

### Recommended architecture direction returned by discovery

- immutable `StatementDate` or `FinancialDate` value containing validated Gregorian year, month and day;
- canonical `yyyy-MM-dd` persistence without representing an instant;
- reader-owned one-based physical source ordinal scoped to the durable document;
- parser-attached immutable transaction source-provenance references;
- durable provenance as separate records rather than a naked account-global transaction ordinal;
- provider-atomic transaction and provenance persistence;
- preservation of legacy lexical values without certifying or guessing lost dates/order;
- explicit legacy unverified/quarantine state for order-dependent trusted projections;
- no automatic historical rewrite;
- Migration V6, subject to accepted architecture;
- one combined ADR governing date-only semantics, durable source evidence, privacy boundary, historical policy and cross-document ambiguity.

### Decisions still owned by Chat

- exact date-only type and vocabulary;
- exact bounded persisted provenance contents;
- whether raw text, normalized fields, digest or a combination is retained;
- retention and export policy;
- legacy-history compatibility and quarantine behavior;
- cross-document same-date current-balance authority;
- V6 table and constraint design;
- exact accepted ADR language.

### Roadmap effect

Sprint 52 did not select or authorize implementation. It promoted both candidates to **ready for Chat architecture decision** and established Sprints 53 and 54 as the strongest current sequence.

---

## Sprint 53 — Trusted Transaction Date and Source Evidence Architecture

### Status

**Forecast**

### Confidence

**High**, because Sprint 52 completed the required repository discovery.

### Expected outcome

Accept one bounded architecture for a trusted transaction carrying faithful source calendar date plus document-scoped source evidence, including a non-invented policy for existing history and a Migration V6 design.

### Candidates

- `FW-P0-21`
- `FW-P0-22`

### Expected sequence

1. **Chat** verifies the current pushed `main` baseline and reviews Sprint 52 evidence.
2. **Chat** decides:
   - date-only type and invariants;
   - durable provenance contents and privacy boundary;
   - document-local ordinal semantics;
   - legacy-history quarantine policy;
   - cross-document same-date authority;
   - Migration V6 compatibility and stop behavior.
3. Use **Work** only for one precisely named residual evidence gap that cannot be resolved from the completed report or GitHub.
4. **Chat** drafts the combined ADR and exact acceptance contract.
5. **Codex** records only the approved ADR and synchronized planning/state documentation on `main`; no production implementation.
6. **Chat** verifies the pushed documentation against the approved decision.

### Expected included scope

- immutable date-only financial domain contract;
- source ordinal meaning and scope;
- transaction source-provenance domain contract;
- bounded sensitive-data retention policy;
- provider-atomic transaction/provenance contract;
- SQLite/In-Memory equivalence requirements;
- legacy V5 compatibility preflight and quarantine semantics;
- cross-document same-date ambiguity behavior;
- Migration V6 architecture;
- independent-oracle acceptance matrix;
- exact exclusions and stop conditions.

### Expected exclusions

- production source changes;
- migration execution;
- historical date or ordinal reconstruction;
- parser-family expansion;
- partial-overlap redesign;
- categories or unrelated UI work;
- trusted-import suspension lift.

### Acceptance boundary

Sprint 53 is accepted only when the ADR makes implementation deterministic without guessing source truth, privacy contents, legacy repair or cross-document order.

### Stop conditions

Stop if:

- the source date cannot be represented without an instant;
- source ordinal scope remains ambiguous;
- the privacy boundary for retained evidence is unresolved;
- V5 history would require invented dates, order or provenance;
- cross-document current-balance authority cannot fail closed;
- one combined implementation cannot be validated through a bounded plan.

### Reorder trigger

Failure to reach an accepted architecture leaves Sprint 54 blocked. It does not permit skipping to Sprint 55.

---

## Sprint 54 — Date-Only and Durable Source-Provenance Implementation

### Status

**Conditional on Sprint 53 acceptance**

### Confidence

**High after Sprint 53**, but implementation scope is broad and financially critical.

### Expected outcome

LedgerForge preserves the source calendar date and document-scoped source evidence of every accepted supported Axis transaction through parsing, validation, provider-atomic persistence, hydration, relaunch and presentation. Same-document same-day balance interpretation no longer depends on provider array order or regenerated UUIDs.

### Candidates

- `FW-P0-21`
- `FW-P0-22`

### Expected sequence

1. **Chat** revalidates `main`, the accepted ADR and exact implementation boundary.
2. **Codex** implements from one complete approved prompt directly on `main` after repository safeguard checks.
3. **Codex** runs focused, migration, provider-parity, rollback, concurrency, hydration, presentation, Debug, Release and analysis gates.
4. **Chat** independently reviews the report and pushed diff.
5. Trusted production import is lifted only when the complete acceptance boundary is verified.

### Expected included scope

- approved `StatementDate`/`FinancialDate` value;
- strict Axis date parsing into the date-only domain;
- immutable transaction source-provenance value;
- reader-owned physical source ordinals;
- parser attachment of one or more source references;
- validation errors using authoritative source position;
- date/order-faithful import preview;
- DTO and confirmed-import plan extensions;
- provider-atomic transaction plus provenance writes;
- Migration V6 compatibility preflight and legacy state;
- SQLite/In-Memory parity;
- hydration retaining durable transaction identity, date-only value and provenance;
- source-aware same-document ordering and balance logic;
- bounded Dashboard, Accounts, Transactions and Import presentation updates;
- independent raw-source date, row-order and running-balance oracles;
- cross-timezone, DST, UTC+14 and UTC-12 tests;
- fresh database, V5-to-V6 and malformed-history migration tests;
- failure injection and zero-residue tests;
- relaunch and provider-reconstruction verification.

### Expected exclusions

- automatic repair of existing ambiguous history;
- inferred global order across documents;
- new institution or format support;
- partial-overlap import;
- historical duplicate repair;
- raw full-document retention unless expressly approved by Sprint 53;
- unrelated UI redesign;
- categories.

### Acceptance boundary

Acceptance requires one independent source oracle to prove that parser, persistence, hydration and presentation preserve the same source dates, same-document sequence and running balances across both providers and all tested timezones.

### Corrective policy

Any defect that blocks the trusted-import lift becomes **Sprint 54A**. Sprint 55 does not begin while trusted supported Axis import remains suspended.

---

## Sprint 55 — Axis NRO and Import Profile Readiness

### Status

**Conditional on accepted Sprint 54 and restored trusted Axis NRE import**

### Confidence

**Medium**

### Expected outcome

Determine whether Axis NRO should become the first profile-backed parser-family expansion and whether the minimum reusable Import Profile architecture can be implemented in the same bounded outcome or must precede it.

### Candidates

- `FW-P1-01 — Axis Bank Parser Family Expansion`
- `FW-P1-06 — Parser Framework Expansion`

### Why this follows Sprint 54

Axis NRO cannot be trusted merely because its columns resemble the supported NRE layout. It needs source-faithful fixture provenance, deterministic institution detection, parser selection, identifier evidence, date/order fidelity and expected financial truth. Sprint 54 supplies the correct durable date/provenance foundation on which new parser support must rely.

### Expected sequence

1. **Chat** verifies current parser-support claims and available approved/sanitized source evidence.
2. **Work** performs bounded read-only discovery against the exact pushed ref:
   - inspect Axis NRO source structure and provenance chain;
   - prove or reject deterministic institution detection;
   - prove or reject layout recognition and semantic-role mapping;
   - compare fixed-parser extension against versioned Import Profile architecture;
   - identify identifier evidence and account separation semantics;
   - define independent expected financial truth;
   - recommend combine/split.
3. **Chat** decides the next implementation boundary.
4. No production code is changed in this sprint unless Chat deliberately reclassifies the sprint after reviewing discovery; the default forecast is discovery/architecture only.

### Expected included scope

- approved fixture and sanitization/provenance requirements;
- deterministic NRO detection and classification evidence;
- exact semantic header roles and layout-version identity;
- parser family versus profile framework boundary;
- account identifier and NRE/NRO separation evidence;
- date/order/provenance compatibility with Sprint 54;
- end-to-end acceptance plan;
- migration/ADR impact determination.

### Expected exclusions

- claiming NRO production support;
- generalizing to every Axis account layout;
- Axis cards;
- PDF/XLS/XLSX support;
- learning mode or AI-assisted column mapping;
- silent fallback from unsupported layouts;
- broad parser rewrite without fixture-backed need.

### Stop conditions

Stop if approved source evidence, expected financial truth, deterministic selection or identifier semantics cannot be established.

### Reorder trigger

If Sprint 55 shows that NRO requires a larger parser-framework architecture increment, Sprint 56 implements the prerequisite foundation only. The NRO implementation moves beyond the cycle without renumbering unrelated later work.

---

## Sprint 56 — Profile-Backed Axis NRO Production Support

### Status

**Conditional on Sprint 55 producing an implementation-ready boundary**

### Confidence

**Medium**

### Expected outcome

Implement the smallest approved deterministic Axis NRO parser-family slice through the existing unified import pipeline, using a reusable Import Profile boundary only to the extent proven necessary by Sprint 55.

### Candidates

- `FW-P1-01`
- possible bounded implementation slice of `FW-P1-06`

### Expected sequence

1. **Chat** selects the exact Sprint 55 outcome and exclusions.
2. **Codex** implements directly on `main` after safeguard verification.
3. **Codex** adds fixture-provenance, independent-oracle, parser-selection, persistence, hydration, relaunch and presentation tests.
4. **Chat** verifies that no unsupported Axis family was generalized into production support.

### Expected included scope

Subject to Sprint 55:

- one approved Axis NRO layout/profile;
- deterministic institution detection and statement classification;
- exact semantic header-role resolution;
- strict fail-closed unsupported-layout handling;
- verified account identity evidence where source-supported;
- independent transaction count, direction, native-money, date, order and running-balance truth;
- unified validation, confirmation, provider-atomic persistence and hydration path;
- exact duplicate and supported event-blocking compatibility;
- SQLite/In-Memory parity;
- Debug and Release verification;
- truthful supported-source presentation.

### Expected exclusions

- NRE/NRO account merge;
- savings/current expansion beyond the approved layout;
- cards;
- historical Axis layouts;
- PDF or spreadsheet formats;
- heuristic institution or layout matching;
- learning mode;
- AI column mapping;
- partial overlaps.

### Acceptance boundary

An untouched approved NRO source or privacy-safe equivalent must independently match expected financial truth through preparation, confirmation, atomic commit, hydration, relaunch and exact re-import handling.

### Corrective policy

A support-boundary or financial-truth failure becomes Sprint 56A. Do not proceed to duplicate-management work while the newly claimed parser path is untrustworthy.

---

## Sprint 57 — Partial-Overlap Import Architecture Discovery

### Status

**Conditional on stable trusted parser and provenance foundations**

### Confidence

**Medium**

### Expected outcome

Define a bounded, explicit workflow that can distinguish already-owned supported transactions from source-supported unique transactions, present the impact to the user and atomically persist only the approved unique subset without pretending the source statement was wholly imported.

### Candidates

- `FW-P1-25 — Duplicate-Import Review and Management`
- `FW-P2-12 — Duplicate-Transaction Review` only if discovery proves the review boundary is the same

### Current behavior being evolved

The current supported Axis UPI transaction-event contract intentionally blocks the complete incoming statement when any verified owned event is found. It does not silently omit duplicated rows.

The future goal is not silent discard. It is an explicit partial-import result with preserved source evidence, review and truthful durable outcome.

### Expected sequence

1. **Chat** verifies current duplicate, event-identity, attempt-history and source-provenance boundaries.
2. **Work** performs targeted read-only discovery:
   - classify exact statement duplicate, supported event overlap, repeated incoming event, speculative duplicate and unsupported family;
   - determine which overlap classes may permit partial import;
   - define user review and confirmation evidence;
   - define partial statement/session/attempt provenance;
   - define account balance continuity and same-day order rules;
   - define transaction-time revalidation and concurrent winner/loser behavior;
   - assess migration and ADR needs;
   - separate historical repair from prospective partial import.
3. **Chat** selects the bounded prospective implementation family.

### Expected included scope

- prospective supported overlap review;
- exact explanation of existing versus incoming-unique rows;
- source document and row provenance retention;
- explicit confirmation;
- provider-atomic transaction-time revalidation;
- truthful partial-import durable outcome;
- exact account and statement coverage semantics;
- zero accepted residue on conflict or stale review;
- combine/split decision for `FW-P2-12`.

### Expected exclusions

- silent duplicate removal;
- speculative fuzzy matching;
- unsupported transaction-event families;
- historical duplicate repair;
- legacy fingerprint reconstruction;
- import-session reversal;
- general mutation engine;
- batch import;
- cross-format duplicate identity.

### Stop conditions

Stop if the unique subset cannot be proven from approved event evidence, the partial result cannot be represented truthfully, or commit-time revalidation cannot atomically preserve source provenance and account continuity.

---

## Sprint 58 — Explicit Partial-Overlap Import

### Status

**Conditional on Sprint 57 architecture and acceptance plan**

### Confidence

**Medium**

### Expected outcome

For the approved supported overlap family, LedgerForge shows the existing and unique incoming transactions, requires explicit confirmation, revalidates at commit time and atomically persists only the approved unique transactions with truthful partial-import provenance.

### Candidate

- `FW-P1-25`

### Expected sequence

1. **Chat** approves the exact prospective overlap family and durable outcome.
2. **Codex** implements against the accepted duplicate/provenance architecture.
3. **Codex** verifies full-overlap, partial-overlap, no-overlap, repeated-incoming, contention, injected-failure, hydration and relaunch matrices.
4. **Chat** checks that no transaction is silently omitted and no historical repair was smuggled into scope.

### Expected included scope

Subject to Sprint 57:

- review model for existing and unique supported events;
- explicit user confirmation;
- immutable reviewed partial-import plan;
- provider-generation and account-decision binding;
- transaction-time event ownership revalidation;
- atomic persistence of unique transactions only;
- document/session/attempt provenance for a partial result;
- source-row linkage for imported and rejected-as-existing rows where approved;
- deterministic current-balance and coverage presentation;
- provider parity;
- zero losing-path residue;
- exact supported outcome guidance.

### Expected exclusions

- automatic partial import without review;
- fuzzy duplicates;
- IMPS/NEFT/card/refund/reversal event families unless separately approved;
- historical cleanup;
- delete/reverse import;
- batch queue;
- editable corrections;
- generic duplicate engine.

### Acceptance boundary

Independent source evidence must prove the exact unique subset. The resulting durable history, attempt record and UI must distinguish full import, partial import, full overlap block and exact statement duplicate.

### Corrective policy

Any silent omission, incorrect unique-set selection, source-order loss or account-balance regression becomes Sprint 58A.

---

## Sprint 59 — Durable Categories and Manual Transaction Classification

### Status

**Conditional on earlier integrity work remaining accepted**

### Confidence

**Medium**

### Expected outcome

Users can create and manage durable workspace categories and manually assign, change or clear one category on one persisted transaction without altering imported financial truth.

### Candidate and architecture basis

- `FW-P2-20 — Category Model and Management`
- ADR-036 accepted
- discovery complete and ready for Chat planning

### Why it closes this cycle

This is the first substantial user-facing organization feature after the cycle restores trusted transaction evidence, expands one parser family and improves overlap handling. It is already architecture-prepared but must remain below unresolved P0/P1 integrity work.

### Expected sequence

1. **Chat** verifies current transaction identity, provider generation, hydration, lifecycle backup and migration state.
2. **Chat** confirms the bounded first category implementation remains coherent after Sprints 54 and 58.
3. **Codex** implements directly on `main` from one approved prompt.
4. **Chat** verifies persistence, hydration, relaunch, presentation and mutation boundaries.
5. After acceptance, Chat closes the 50–59 cycle and drafts the private 60–69 roadmap.

### Expected included scope

- workspace-owned durable categories;
- immutable category identity;
- root category plus one child level;
- one current category per transaction;
- Uncategorized represented by no assignment;
- user-created categories only;
- deterministic normalized-name and immutable-ID ordering;
- durable persisted transaction identity exposed during hydration if not already delivered;
- category and transaction-assignment persistence;
- dedicated category repository and SQLite/In-Memory parity;
- provider-generation protection;
- one repository-write lease through canonical reconciliation;
- observer-consistent hydration snapshot;
- Settings category create, rename, archive, restore and delete-unused behavior;
- transaction category display;
- transaction-detail assign, change and clear;
- lifecycle backup and recovery verification;
- additive migration number selected from the then-current chain.

### Expected exclusions

- automatic categorization;
- categorization rules;
- AI suggestions;
- merchant/payee normalization;
- recurring detection;
- analytics or budgets;
- multiple categories or tags;
- transaction splits;
- category filtering;
- bulk assignment;
- delete-with-replacement;
- category merge;
- assignment history;
- global undo.

### Acceptance boundary

The persisted transaction ID must survive forced hydration, provider reconstruction and relaunch. Category mutations must never use regenerated runtime identity or rewrite source financial values.

### Corrective policy

Category identity, assignment or hydration defects become Sprint 59A. Cycle close occurs only after any required correction is accepted.

---

# Cycle close after Sprint 59

After Sprint 59 and any attached corrective sprint are accepted, Chat must:

1. establish the exact pushed `main` baseline;
2. reconcile this file against `PROJECT_STATE.md`, `FUTURE_WORK.MD`, accepted ADRs and production code/tests;
3. classify every Sprint 50–59 outcome as complete, replaced, deferred or carried forward;
4. record all inserted corrective sprints;
5. record all independent discovery campaign outcomes;
6. identify uncompleted forecast work without silently renumbering history;
7. create `LedgerForge Roadmap: Sprints 60–69`;
8. carry forward only evidence-valid unfinished outcomes;
9. preserve this file as the read-only private planning archive for the 50–59 cycle.

---

# Independent discovery campaigns

Independent discovery campaigns reduce future planning cost. They are not sprints, do not select implementation and do not alter the numbered roadmap.

## DC-01 — Independent Backlog Readiness Campaign

### Status

**Available on user request; not automatically scheduled**

### Purpose

Have Work investigate as many currently eligible, implementation-independent `FUTURE_WORK.MD` candidates as possible in one continuous read-only pass so later sprint planning does not repeatedly pay the same discovery cost.

### Launch conditions

- Chat identifies an opportunity while Codex is working on an unrelated sprint.
- The campaign is pinned to one exact immutable pushed commit.
- The active Codex sprint does not alter the architecture boundary of any included candidate.
- Work reads repository/GitHub evidence only and does not inspect a half-edited active checkout.
- The campaign performs no edit, build, commit, branch, push, PR or sprint selection.

### Candidate selection rule

At launch, Chat recalculates the eligible set from the current canonical queue. Include candidates marked Ready for discovery, Research or stale Blocked only when their named evidence boundary is independent of:

- the active Codex sprint;
- the next planned sprint;
- unresolved P0 architecture;
- private runtime state unavailable at the pinned ref.

### Initial likely candidates after the P0 repair sequence

Subject to revalidation at launch:

- `FW-P1-40 — Deterministic Approved-Fixture Launcher`;
- `FW-P2-34 — Archive and Restore Account`;
- `FW-P2-52 — User and Workspace Preferences`, limited to ordinary regional/display preferences independent of reporting currency;
- other candidates proven independent by Chat at the launch baseline.

### Explicitly excluded from DC-01 during this cycle

- `FW-P0-21` and `FW-P0-22`, owned by Sprints 52–54;
- `FW-P1-01` and `FW-P1-06`, owned by Sprints 55–56;
- `FW-P1-25` and overlapping `FW-P2-12` questions, owned by Sprints 57–58;
- `FW-P2-20`, owned by Sprint 59;
- any candidate depending on implementation not yet pushed;
- any candidate requiring active local runtime or private-source inspection that conflicts with Codex work;
- any candidate whose architecture is likely to be rewritten by the active sprint.

### Required candidate-by-candidate output

For each candidate:

- exact candidate ID and current queue wording;
- inspected ref;
- verified current behavior;
- relevant production and test surfaces;
- dependencies and architecture constraints;
- migration or ADR impact;
- independent-oracle requirement where financial truth is involved;
- missing decisions;
- falsification risks;
- one classification:
  - implementation-ready;
  - ready for Chat planning;
  - discovery complete with one named decision remaining;
  - blocked by a named dependency;
  - completed/no longer applicable;
  - insufficient evidence.

Work must not choose or number future sprints.

### Revalidation rule

A campaign conclusion is planning input only. Before future selection, Chat revalidates every material conclusion against the then-current `main`, because a discovery report pinned months earlier is evidence, not prophecy.

## Further campaigns

Repeat the same pattern as `DC-02`, `DC-03`, and so on when the user identifies another safe opportunity. Do not create campaigns merely to keep Work occupied.

---

# Reorder and invalidation rules

The roadmap is invalidated or reordered when any of the following occurs:

- a verified P0 defect appears;
- a planned sprint fails its acceptance boundary;
- the inspected repository differs materially from the roadmap baseline;
- an accepted ADR changes a dependent boundary;
- a required migration cannot preserve existing history without invention;
- a candidate loses fixture or source-evidence support;
- a discovery campaign contradicts roadmap readiness;
- SQLite/In-Memory parity fails where required;
- a new dependency blocks a forecasted outcome;
- the user changes product priority after higher-priority safety work is resolved.

Reordering rules:

1. insert a corrective `A/B` sprint when tied to the preceding sprint;
2. insert a standalone integrity sprint for an unrelated P0 defect;
3. retain original later sprint numbers;
4. mark displaced work **Deferred** or **Replaced** rather than rewriting history;
5. update the overview, affected sprint cards and append-only log;
6. never treat a forecast row as authorization.

---

# File handling and visibility

- Store this file outside the LedgerForge Git checkout.
- Do not add it to Git, GitHub, repository documentation or build resources.
- Do not provide it to Work or Codex.
- At the start of a new Chat planning conversation, attach the latest local copy when continuity is required.
- Chat reads the active state and relevant sprint card, then verifies everything against current repository evidence.
- Keep a normal user-controlled local backup because this file is intentionally outside repository history.

Suggested local location:

```text
~/Documents/LedgerForge Planning/LedgerForge_Roadmap_Sprints_50-59.md
```

---

# Append-only planning and decision log

Do not rewrite or delete prior entries. Add corrections as new dated entries. The concise sections above may be updated to reflect the current plan; this log preserves how and why the plan changed.

## 2026-07-22 — Roadmap visibility problem identified

### User, verbatim

> Brainstorm and come up with cons and pros and then based on that a final recommendation for or against making a sprint roadmap file for only Chat and me as a way to have sprints lined up and plan better as I do not have any visibility of what to expect in coming sprints.

### Decision

Create a private local roadmap. Do not place it in GitHub. Repository authorities remain controlling and the file remains non-executable.

## 2026-07-22 — Ten-sprint cycle, corrective numbering and independent discovery defined

### User, verbatim

> I'd say a 10 sprint roadmap but not to be uploaded on github.
> the sprints would be planned like for eg 50-60. adn then updated as part of doc sync cycle for 60-70. The sprint planning would itself say if any previous sprint identified bug etc is detetced that will take precedence of new sprint so for eg sprint 52 worked but found some new issue, instead of going for sprint 53 and pushing everything down the issue will be resolved calling sprint 52A. 
> codex or work will not see this file at anypoint. This file is basically a file saved on my mac containing all the project planning and roadmap discussion word for word instead of you saving context in memory and the retrieving it later and then distilling or drifting.
>
> The sprints would have brief steps and action eg. 
> Sprint 52 
> - get work to discover or unblock these items
> - codex to implement these items
>
>
> Meanwhile while codex is working and when I identify an oppurtunity, have work have all the "remaining discovery" items sequentially but in 1 big pass. This is not part of planned sprint, just a way to clear backlog from future.md Those items are waiting to be discovered and do not depend on current or upcoming project implementation. Even if they are montsh away form being implemented, when i call for "have work do a discovery on as many candidates as possible" we are doing that to save time later.

### Decision

Adopt ten fixed sprint numbers per cycle, corrective `A/B` suffixes without renumbering later sprints, strict Chat-only visibility, and separate non-sprint discovery campaigns.

## 2026-07-22 — Initial file requested

### User, verbatim

> Ok, draft structure attached. 
> Include sprint 50-60. Although first 2 are done already, it ll give us a baseline structure .
>
> Give me the complete final file with all sprints done till 60

## 2026-07-22 — Cycle corrected

### User, verbatim

> correction to above, sprint 50-59.

### Decision

The first roadmap cycle is Sprints 50–59. The next cycle is Sprints 60–69.

## Future log-entry format

```markdown
## YYYY-MM-DD HH:MM — <decision or review title>

### Repository basis
- Inspected ref:
- Authoritative documents:

### User, verbatim
> <full user planning message>

### Chat, verbatim
> <full Chat planning response>

### Decision effect
- Sprint affected:
- Status change:
- Reorder/correction:
- New blocker:
- Roadmap sections updated:
```
