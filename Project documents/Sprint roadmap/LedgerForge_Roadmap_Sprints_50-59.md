# LedgerForge Roadmap: Sprints 50–59

## Control

**Purpose:** Private Chat-user roadmap, planning record and continuity aid
**Repository authority:** None
**Execution authority:** None
**Visible to Work:** No
**Visible to Codex:** No
**GitHub status:** Backup copy only, never repository authority
**Repository baseline reviewed:** `main@bdb51b0ddcdde097e456a16bab7f0bf999fd595b`
**Latest verified implementation:** Sprint 53 at `11035461ce3de0f11ae5262bbc8a38b9639607b2`
**Last reconciled:** 2026-07-23
**Cycle:** Sprints 50–59

This file forecasts and records Chat-user planning. It does not authorize Work, Codex, implementation, Git operations, migrations, ADR changes or repository edits.

Before any sprint decision, Chat must read this file and verify it against the exact current repository ref, `PROJECT_STATE.md`, `FUTURE_WORK.MD`, accepted ADRs, and relevant code/tests. Repository evidence overrides this roadmap.

Work and Codex must never receive this file. They receive only the bounded prompt approved for their immediate task.

---

## Operating rules

### Fixed cycle and corrective numbering

The cycle contains Sprints 50 through 59. A blocking defect discovered by Sprint `N` is handled as `NA`, then `NB` only when another separately bounded correction remains directly attributable to Sprint `N`.

Later sprint numbers do not move.

```text
Sprint 52
Sprint 52A — blocking correction
Sprint 53 — original numbered sequence resumes
```

Use a corrective suffix only when the issue:

- arose from implementation or acceptance of the parent sprint;
- blocks acceptance, trusted use or safe continuation;
- has one bounded corrective outcome;
- is not unrelated feature work.

An unrelated verified P0 defect may interrupt the roadmap as a standalone integrity sprint. Chat must state why it is not attached to the preceding sprint.

### Priority override

Verified financial-correctness, persistence, identity, privacy or recoverability defects outrank forecast work.

When such a defect appears:

1. stop acceptance of the affected outcome;
2. verify and classify it against repository evidence;
3. insert corrective or standalone integrity work;
4. retain later sprint numbers;
5. resume only after the blocker is accepted or explicitly deferred by the user.

### Status vocabulary

| Status | Meaning |
|---|---|
| **Complete** | Verified and accepted |
| **Selected** | Chat has approved a complete execution prompt |
| **In progress** | Approved Work or Codex execution is active |
| **Forecast** | Strong current expectation, not authorized |
| **Conditional** | Depends on named earlier evidence or implementation |
| **Discovery** | Read-only evidence sprint; no implementation by default |
| **Correction inserted** | `A/B` sprint interrupts the sequence |
| **Deferred** | Still valid, moved beyond this cycle |
| **Replaced** | Current evidence invalidated or absorbed the earlier forecast |

Only **Selected** and **In progress** correspond to execution authorization.

### Reconciliation

After every accepted sprint, update:

- exact ending `main` commit;
- verified outcome and acceptance evidence;
- deviations from forecast;
- corrective sprints;
- candidate readiness changes;
- effects on later sprint cards;
- append-only decision log.

Keep the active roadmap concise. Preserve detailed discussion in the log only when it materially explains a decision.

---

## Active project state

- **Latest completed sprint:** Sprint 53 — Axis Shared Bank-Account CSV Profile and NRO Identity Closure.
- **Current pushed baseline:** `main@bdb51b0ddcdde097e456a16bab7f0bf999fd595b`.
- **Latest verified implementation:** `11035461ce3de0f11ae5262bbc8a38b9639607b2`; the pushed baseline is one documentation-only commit ahead.
- **Current migration:** V6.
- **Current accepted ADR:** ADR-039 — Trusted Statement Dates and Durable Source Provenance.
- **Trusted production import:** approved Axis NRE and supplied shared-layout Axis NRO CSV evidence through one `AxisBankAccountParser`.
- **Forward parser profile:** `axis.bank-account.csv` version `1`.
- **Historical compatibility:** durable `axis.nre.csv` version `1` provenance remains readable and unchanged.
- **Durable account identity:** distinct verified full institution account identifiers create and retain distinct accounts; shared customer context is non-authoritative.
- **Latest recorded automated result:** 394 top-level tests across 48 suites, zero failures and zero unexpected skips at the Sprint 53 implementation baseline.
- **Latest recorded runtime result:** two durable Axis accounts, 118 transactions after relaunch hydration, exact duplicate handling, supported overlap blocking, neutral presentation and zero remaining LedgerForge processes.
- **Fresh discovery verification:** none. The read-only campaign and documentation cleanup performed no build, test, runtime, migration, ADR or implementation work.
- **Current blocking defect:** `FW-P0-24 — Durable Import-Outcome Presentation Exhaustiveness`.
- **Current next planning outcome:** Sprint 54, a standalone P0 presentation-integrity repair.
- **Why this is not Sprint 53A:** the defect is verified against current code but has not been shown to arise from Sprint 53 implementation or acceptance.
- **Feature-planning gate:** lower-priority feature execution remains paused until `FW-P0-24` is repaired and accepted or explicitly accepted as unresolved by the user.
- **Known import limitation:** supported partial overlap blocks the complete incoming statement; partial import remains future work under `FW-P1-25`.
- **Known support boundary:** broader Axis layouts, PDF, XLS, XLSX, cards, HDFC, CBQ and other institutions are not production-supported.
- **Known runtime-tooling limitation:** manual and automation launches can attach to a stale DerivedData build when multiple LedgerForge processes exist; a deterministic singleton launch entrypoint remains future work.
- **Local-state limitation:** GitHub cannot establish worktree cleanliness, stashes, branches, linked worktrees or unpushed commits. Those checks remain mandatory before implementation execution.

---

## Cycle overview

| Sprint | Outcome | Candidates | Status | Confidence |
|---|---|---|---|---|
| **50** | Provider-atomic confirmed import, durable identifier ownership and Migration V5 | `FW-P0-05`, bounded `FW-P0-12`, ADR-038 | **Complete** | Verified |
| **51** | Fail closed on malformed recognized Axis transaction-date and identity evidence | `FT-P0-03`, `FT-P1-04` | **Complete** | Verified |
| **52** | Trusted statement dates and durable source provenance through ADR-039 and Migration V6 | `FW-P0-21`, `FW-P0-22` | **Complete** | Verified |
| **52A** | Close trusted hydration, profile-provenance and writer-authority gaps | Sprint 52 corrective scope | **Complete** | Verified |
| **53** | Shared Axis bank-account CSV profile and NRO durable-identity closure | supplied slice of `FW-P1-01`, bounded slice of `FW-P1-06` | **Complete** | Verified |
| **54** | Exhaustive, typed and privacy-safe durable import-outcome presentation | `FW-P0-24` | **Forecast** | High |
| **55** | Define explicit partial-overlap review and unique-transaction import semantics | `FW-P1-25`, possible `FW-P2-12` relationship | **Discovery** | Medium-high |
| **56** | Implement one bounded partial-overlap import family without silent omission | `FW-P1-25` | **Conditional** | Medium |
| **57** | Durable categories and manual single-transaction classification | `FW-P2-20`, ADR-036 | **Conditional** | Medium |
| **58** | DEBUG-only deterministic import verification workspace | `FW-P1-40`, bounded `FW-P1-37` | **Conditional** | Medium |
| **59** | Production PDF and binary-fingerprint architecture discovery | `FW-P1-10`, `FW-P1-18`, readiness for `FW-P1-16` | **Discovery** | Medium-low |

Forecast confidence decreases with distance. Any further verified P0 defect or failed acceptance boundary overrides the sequence without disguising unrelated work as a corrective suffix.

The deterministic singleton build and runtime-launch entrypoint remains valid but moves to the 60–69 cycle. It was displaced by the P0 integrity repair rather than completed or cancelled.

---

# Sprint cards

## Sprint 50 — Atomic Confirmed Import and Durable Identifier Ownership

**Status:** Complete
**Architecture:** ADR-038
**Migration:** V5

### Outcome

Accepted confirmation moved into one provider-owned transaction that revalidates repository truth before atomically publishing the accepted financial graph.

### Delivered

- provider-generation, account-choice and identity-decision revalidation;
- identifier ownership, fingerprint and transaction-event claim enforcement;
- atomic account, document, session, transaction, identifier and observation persistence;
- SQLite/In-Memory equivalent typed outcomes;
- same-process, independent-provider and separate-process competition coverage;
- zero losing-path accepted residue;
- canonical post-commit hydration and reconciliation gating.

### Excluded

- generic mutation executor;
- historical identifier repair or invented observations;
- unlinking, reassignment and incorrect-link recovery;
- general rollback or compensation.

---

## Sprint 51 — Fail-Closed Recognized Axis Source Evidence

**Status:** Complete

### Outcome

Recognized malformed Axis transaction rows and malformed, unconstructable or conflicting structured account evidence now fail before preparation, account review, confirmation or persistence.

### Delivered

- strict malformed transaction-date rejection;
- typed parser-owned identity-evidence failure;
- preserved valid rows and supported zero-value behavior;
- zero accepted residue;
- no migration or ADR change.

### Integration note

A Developer Console filename-redaction change produced during the original Codex run was rejected as unrelated scope and not integrated.

### Verified baseline

- repair commit: `e31343d08258cd3e1c0ce3b91c32f6fad71fda4d`;
- synchronized documentation: `2aa6346fa0b8dc116ba97a6983f205afd0a206d3`.

---

## Sprint 52 — Trusted Statement Dates and Durable Source Provenance

**Status:** Complete
**Architecture:** ADR-039
**Migration:** V6

### Outcome

Supported Axis transaction dates remain date-only financial evidence, while document-scoped order and bounded source provenance survive parsing, validation, provider-atomic persistence, hydration, relaunch and presentation.

### Delivered

- immutable source-faithful statement-date domain;
- no `Foundation.Date` conversion for printed transaction dates;
- canonical date-only persistence and exact hydration;
- Axis `Asia/Kolkata` profile date authority;
- document-scoped reader ordinal;
- normalized-record digest and parser-profile provenance;
- provider-atomic transaction/provenance graph;
- SQLite/In-Memory parity;
- V6 fail-closed handling for nonempty V5 financial graphs rather than invented history;
- source-supported same-document order and running-balance behavior;
- independent source-date, order and financial-truth verification.

### Excluded

- reconstructed historical dates, order or provenance;
- inferred global order across documents;
- new institutions, layouts or formats;
- partial-overlap import;
- historical duplicate repair.

### Roadmap deviation

The earlier roadmap split architecture and implementation into later sprints. Repository reality completed ADR-039, V6 and production implementation within Sprint 52, freeing later slots for additional evidence-valid work.

---

## Sprint 52A — Strict Trusted Transaction Hydration and Provenance Closure

**Status:** Complete corrective sprint

### Reason

Sprint 52 verification exposed remaining persistence-to-runtime and writer-authority paths that could accept malformed or incomplete trusted provenance.

### Delivered

- fail-closed hydration for unsupported date-role codes;
- fail-closed hydration for malformed or invalid timezone evidence;
- rejection of missing or conflicting source relationships;
- durable parser profile ID/version read from provider evidence, never reconstructed or hardcoded;
- trusted transaction rejection through generic replacement paths;
- complete normalized source-relationship validation inside confirmed import;
- provider-equivalent atomic rejection with zero residue;
- hydration, relaunch and complete serial TestPlan verification.

### Excluded

- new parser, institution, layout or format support;
- historical repair;
- migration changes beyond existing V6.

---

## Sprint 53 — Axis Shared Bank-Account CSV Profile and NRO Identity Closure

**Status:** Complete
**Commit:** `11035461ce3de0f11ae5262bbc8a38b9639607b2`
**Migration:** V6 unchanged

### Outcome

One production `AxisBankAccountParser` now supports the approved Axis NRE and supplied shared-layout Axis NRO CSV evidence through one neutral forward profile. Different verified full account numbers create and retain different durable accounts.

### Delivered

- forward profile `axis.bank-account.csv` version `1`;
- parser-authoritative profile provenance with no persistence fallback;
- fail-closed missing, malformed and conflicting profile evidence;
- privacy-safe reconstruction of two NRO CSV preambles while preserving transaction rows;
- independent financial and identity oracles;
- explicit first-account creation and subsequent identifier resolution;
- distinct NRE and NRO durable accounts despite shared customer context;
- SQLite/In-Memory lifecycle parity;
- exhaustive confirmed-import failure injection with zero accepted residue;
- exact duplicate and supported event-overlap behavior;
- provider reconstruction, hydration and application relaunch verification;
- neutral presentation with redacted identity summaries;
- historical `axis.nre.csv@1` exact readback without rewriting;
- 394-test canonical TestPlan, Debug/Release builds and analyses, and disposable runtime verification.

### Excluded

- broader Axis NRO or historical layouts;
- PDF, XLS, XLSX and cards;
- HDFC and other institutions;
- broad CSV grammar and reusable profile architecture;
- NRE/NRO classification inference;
- customer-ID matching;
- historical profile rewriting;
- Migration V7.

### Roadmap deviation

Sprint 53 discovery proved the minimum implementation boundary and completed it in the same numbered sprint. The former Sprint 54 Axis-NRO implementation forecast was absorbed and replaced. Later candidates move forward one slot without changing their internal order.

---

## Sprint 54 — Durable Import-Outcome Presentation Exhaustiveness

**Status:** Forecast
**Candidate:** `FW-P0-24`
**Priority:** P0 integrity override
**Migration:** None expected
**ADR:** None expected

### Why standalone

The defect is verified at the current pushed baseline but has not been attributed to Sprint 53. It therefore interrupts the roadmap as standalone integrity work rather than being labelled Sprint 53A.

### Outcome

Every known durable import-attempt outcome, coverage value and guidance value is presented truthfully and consistently across Dashboard Import Activity and Import History, while unknown or malformed persistence values remain neutral and privacy-safe.

### Expected scope

- one shared typed presentation authority;
- exhaustive handling of all 13 currently known durable outcomes;
- exhaustive handling of the bounded coverage and guidance enums;
- Dashboard Import Activity;
- Import History list;
- Import History detail;
- neutral unknown and malformed handling;
- no visible or copied raw persistence code;
- preservation of current-workflow precedence;
- preservation of deterministic valid-date and stable-ID latest-attempt selection;
- focused enumeration tests for all known values;
- hostile unknown-value tests;
- regression coverage preventing known outcomes from silently falling through generic defaults.

### Excluded

- richer account-match explanation under `FW-P0-10`;
- retry or resumable confirmed persistence;
- resolver behavior;
- repository or schema changes;
- partial-overlap import;
- Import Centre redesign;
- general visual polish;
- categories;
- analytics;
- financial mutation.

### Acceptance

1. Every known outcome, coverage and guidance value has one explicit truthful presentation.
2. Unknown or malformed values remain neutral and never become persistence failure.
3. Raw hostile values never reach visible or copied presentation.
4. Dashboard and Import History use the same typed authority.
5. Existing latest-attempt ordering and workflow precedence remain unchanged.
6. Fresh canonical tests, builds and static analyses pass.
7. The accepted result changes no migration or ADR.
8. Local and remote `main` finish synchronized with one clean primary worktree.

### Stop conditions

Stop if:

- the meaning of any durable code is ambiguous;
- the implementation infers retry or mutation safety;
- a raw persisted value can reach presentation;
- unrelated UI or workflow work enters the change;
- local branch, worktree or stash state is ambiguous;
- a schema or ADR change becomes necessary;
- focused or canonical validation fails.

---

## Sprint 55 — Partial-Overlap Import Architecture

**Status:** Discovery
**Candidate:** `FW-P1-25` with a possible bounded relationship to `FW-P2-12`

### Outcome

Define a prospective workflow that distinguishes already-owned supported events from unique incoming transactions, presents the impact, obtains explicit confirmation and preserves truthful partial-import provenance.

### Work

1. Verify current exact-document duplicate, Axis UPI event, attempt-history and ADR-039 provenance boundaries at the exact pushed ref.
2. Classify overlap families and identify the smallest independently provable partial-import family.
3. Decide whether `FW-P2-12` contributes only review/presentation semantics or introduces an inseparable transaction-editing dependency.
4. Select one implementation boundary or stop with named blockers.

### Required decisions

- exact statement duplicate versus supported event overlap;
- full overlap, partial overlap, repeated incoming event and unsupported evidence;
- imported, recognized-existing and rejected row provenance;
- statement, session and attempt representation of a partial outcome;
- opening/closing balance and running-balance interpretation;
- same-day source order;
- immutable user-reviewed plan;
- transaction-time revalidation and contention behavior;
- provider atomicity and losing-path residue;
- migration and ADR need.

### Excluded

- implementation by default;
- silent duplicate removal;
- fuzzy or speculative matching;
- historical duplicate repair;
- unsupported event families;
- import reversal;
- batch import;
- generic mutation machinery.

### Stop conditions

Stop if the unique subset cannot be independently proven, represented truthfully or committed atomically without falsifying statement coverage or balances.

---

## Sprint 56 — Explicit Partial-Overlap Import

**Status:** Conditional on Sprint 55
**Candidate:** `FW-P1-25`

### Outcome

For one approved supported overlap family, show existing and unique transactions, require confirmation, revalidate at commit time and atomically persist only the approved unique subset with truthful provenance.

### Expected scope

- immutable reviewed partial-import plan;
- explicit impact review and confirmation;
- provider-generation and account-decision binding;
- event-ownership revalidation;
- atomic persistence of the approved unique subset;
- truthful document, session and attempt outcome;
- source linkage for imported and recognized-existing rows where approved;
- deterministic balance and coverage presentation;
- SQLite/In-Memory parity;
- zero losing-path residue;
- hydration and relaunch behavior.

### Excluded

- automatic partial import;
- fuzzy duplicates;
- unsupported event families;
- historical cleanup;
- delete or reverse import;
- batch queue;
- editable transaction correction;
- broad mutation framework.

### Acceptance

Independent evidence must prove the unique subset and distinguish full import, partial import, full-overlap block and exact duplicate. Silent omission, false statement coverage or balance regression becomes Sprint 56A.

---

## Sprint 57 — Durable Categories and Manual Classification

**Status:** Conditional
**Candidate:** `FW-P2-20`
**Architecture:** ADR-036
**Migration expectation:** V7

### Outcome

Users can manage durable workspace categories and assign, change or clear one category on one persisted transaction without changing imported financial truth.

### Expected scope

- workspace-owned category identity;
- root plus one child level;
- one current category per transaction;
- no assignment means Uncategorized;
- deterministic normalized-name and immutable-ID ordering;
- durable category and assignment persistence;
- dedicated category repository and store;
- SQLite/In-Memory parity;
- provider-generation and write-lease protection;
- canonical observer-consistent hydration;
- Settings create, rename, archive, restore and delete-unused;
- transaction display and detail assignment controls;
- additive Migration V7;
- clean-install and V6-to-V7 verification;
- lifecycle backup and recovery verification.

### Excluded

- rules or automatic categorization;
- AI suggestions;
- merchant normalization or recurring detection;
- analytics and budgets;
- tags, splits or multiple categories;
- filters and bulk assignment;
- category merge or delete-with-replacement;
- assignment history and global undo.

### Acceptance

Persisted transaction identity must survive hydration, provider reconstruction and relaunch. Any identity or assignment-loss defect becomes Sprint 57A.

---

## Sprint 58 — Deterministic Import Verification Workspace

**Status:** Conditional
**Candidates:** `FW-P1-40` plus bounded `FW-P1-37`

### Outcome

Provide one DEBUG-only workspace that launches approved sanitized fixtures through the ordinary production URL-driven import path and displays clearer typed failure summaries without creating alternate financial logic.

### Why combine

Both candidates share one developer outcome and one validation boundary:

- choose an approved fixture;
- use the real preparation pipeline;
- observe deterministic stage and failure evidence;
- proceed through ordinary review and confirmation;
- verify persistence and hydration;
- remain completely absent from Release.

### Expected scope

- deterministic approved-fixture list;
- fixture provenance presentation;
- ordinary reader, detection, parser, validation, duplicate, account-choice, confirmation, persistence and hydration path;
- no automatic confirmation;
- structured summaries for already-typed source, validation, identity, duplicate, persistence and reconciliation outcomes;
- privacy-safe presentation;
- proof that private originals are not bundled;
- optimized Release symbol, resource and runtime containment checks.

### Excluded

- private statement launcher;
- fixture generation or sanitization;
- alternate parser, validator or repository;
- expected results injected into runtime behavior;
- source editing, raw SQL or database browsing;
- persistent diagnostic history or export;
- general Developer Console rewrite;
- new production support.

### Acceptance

Launching a fixture must behave the same as manually selecting that file through the ordinary application flow. Alternate-path, privacy or Release-containment failure becomes Sprint 58A.

---

## Sprint 59 — Production PDF and Binary-Fingerprint Discovery

**Status:** Discovery
**Confidence:** Medium-low

### Outcome

Determine the smallest safe path for one approved Axis PDF statement to enter the unified production pipeline, decide binary-document fingerprint authority and prepare the future cross-format equivalence acceptance boundary.

### Candidates

- `FW-P1-10 — Production PDF Statement Support`;
- `FW-P1-18 — Binary-Document Fingerprint Semantics`;
- readiness implications for `FW-P1-16 — Cross-Format Financial Equivalence`.

### Why combine for discovery

Production PDF support cannot be planned safely without deciding:

- what representation owns exact binary duplicate identity;
- how PDF extraction preserves date, order and transaction grouping;
- how equivalent CSV and PDF representations preserve the same financial truth.

The shared evidence boundary makes one discovery pass efficient. It does not authorize broad PDF implementation.

### Work

1. Verify the pushed baseline and approved PDF/CSV evidence.
2. Trace sandbox access, extraction, classification, profile selection, identity, provenance, fingerprinting, validation and persistence.
3. Decide exact source bytes versus another explicitly defined stable binary representation.
4. Select one result:
   - combined implementation-ready PDF slice;
   - binary-fingerprint prerequisite first;
   - parser/profile prerequisite first;
   - blocked by named source or oracle evidence.

### Required evidence

- approved PDF and matching CSV where equivalence is claimed;
- source-to-fixture provenance;
- independent financial truth for each format;
- transaction count, direction, money, date, order, identifiers and balances;
- sandbox-authorized production URL opening;
- deterministic extraction and page/row order;
- malformed, encrypted, image-only and unsupported outcomes;
- raw-byte or explicitly approved alternative fingerprint semantics;
- exact duplicate, revised document and cross-format distinction;
- privacy, migration and ADR impact;
- falsification cases.

### Excluded

- production implementation by default;
- password entry, Keychain or OCR;
- arbitrary institutions or card PDFs;
- XLS/XLSX;
- heuristic repair or AI interpretation;
- declaring `FW-P1-16` complete before two formats are production-supported.

### Stop conditions

Stop if financial truth, extraction order, sandbox access or fingerprint authority cannot be established without inference from production parser output.

### Cycle effect

Sprint 59 closes the 50–59 cycle. The deterministic singleton build and runtime-launch entrypoint, any implementation-ready PDF result and unfinished parser expansion move into the 60–69 roadmap rather than being forced into this cycle for cosmetic completeness.

---

# Independent discovery campaigns

Independent campaigns reduce later planning cost. They are not sprints and cannot select implementation.

## DC-01 — Backlog Readiness Campaign

**Status:** Available on user request

### Launch conditions

- pinned to one exact immutable pushed commit;
- candidates do not depend on the active Codex sprint or next planned implementation;
- read-only repository evidence only;
- no inspection of a half-edited active checkout;
- no edits, builds, branches, commits, pushes, PRs or sprint selection.

### Initial likely candidates

Recalculate at launch. Current plausible candidates include:

- `FW-P2-34 — Archive and Restore Account`;
- `FW-P2-52 — User and Workspace Preferences`, limited to ordinary regional/display preferences;
- `FW-P0-10 — Explain Account Match, No-Match and Conflict Outcomes`, only when independent of active import work;
- `FW-P1-02 — HDFC Parser Family`, only after approved HDFC source evidence and sanitized fixtures exist;
- other candidates proven independent at the launch baseline.

### Excluded during this cycle

- `FW-P0-24`, owned by Sprint 54;
- `FW-P1-25` and related `FW-P2-12` questions, owned by Sprints 55–56;
- `FW-P2-20`, owned by Sprint 57;
- `FW-P1-37` and `FW-P1-40`, owned by Sprint 58;
- `FW-P1-10`, `FW-P1-18` and `FW-P1-16` readiness, owned by Sprint 59;
- the singleton build and runtime-launch follow-up, deferred to the 60–69 cycle;
- candidates depending on unpushed work;
- candidates whose architecture is likely to change during the active sprint;
- candidates requiring conflicting private-runtime inspection.

### Required output per candidate

- exact candidate and inspected ref;
- verified current behavior;
- production and test surfaces;
- dependencies and constraints;
- migration/ADR impact;
- independent-oracle needs;
- missing decisions and falsification risks;
- classification as implementation-ready, ready for Chat planning, blocked, completed/no longer applicable or insufficient evidence.

Work must not number or select future sprints.

---

# Cycle close

After Sprint 59 and any attached correction:

1. establish exact pushed `main`;
2. reconcile against repository authorities;
3. classify every outcome as complete, replaced, deferred or carried forward;
4. record corrective sprints and discovery campaigns;
5. create the private Sprints 60–69 roadmap;
6. carry forward only evidence-valid unfinished work;
7. preserve this cycle as read-only history.

---

# File handling

- Keep the primary copy outside the Git checkout.
- A GitHub copy may exist only as user-controlled backup and must remain excluded from repository authority and execution prompts.
- Never supply the file to Work or Codex.
- At the start of a new planning chat, direct Chat to perform the roadmap preflight.
- Replace the ChatGPT project-source copy after each reconciliation so only one active revision exists.
- Maintain a normal local backup.

Suggested local filename:

```text
LedgerForge_Roadmap_Sprints_50-59.md
```

---

# Append-only planning and decision log

## 2026-07-22 — Private roadmap adopted

### User intent

Create a ten-sprint private roadmap to provide visibility, preserve planning context and avoid relying on reconstructed conversational memory.

### Decision

- fixed ten-sprint cycles;
- corrective `A/B` suffixes without later renumbering;
- repository evidence remains authoritative;
- file remains invisible to Work and Codex;
- independent Work discovery campaigns remain outside numbered sprints.

## 2026-07-22 — Cycle corrected

### User, verbatim

> correction to above, sprint 50-59.

### Decision

The first cycle is Sprints 50–59. The next cycle is Sprints 60–69.

## 2026-07-23 — Sprint 52 consolidation reconciled

### Evidence

- Sprint 52 completed ADR-039, Migration V6 and the combined implementation originally forecast across later slots.
- Sprint 52A closed trusted hydration, profile-provenance and writer-authority gaps.
- Trusted import was restored for the approved Axis NRE CSV profile.

### Decision

- move Axis NRO/Profile work to Sprints 53–54;
- move partial-overlap work to Sprints 55–56;
- move categories to Sprint 57;
- use Sprint 58 for the compatible approved-fixture plus failure-summary developer outcome;
- use Sprint 59 for PDF, binary fingerprint and cross-format discovery;
- remove those candidates from DC-01 ownership.

## 2026-07-23 — Full-file rebuild requested

### User, verbatim

> Direct edit failed. Give me full fie output. While shaping teh document remember your previous feedback about trimming the repetitions etc

### Decision

Rebuild the complete file with:

- one centralized operating-rules section;
- concise sprint cards;
- repeated authority and exclusion language removed where the control section already governs it;
- enough acceptance and stop conditions to preserve planning safety;
- no loss of current repository evidence or roadmap ownership.

## 2026-07-23 — Sprint 53 completed and cycle advanced

### Repository basis

- Inspected starting ref: `3e5ab2a636be8a3372a10224de3268fb3d9c1aab`;
- accepted ending ref: `11035461ce3de0f11ae5262bbc8a38b9639607b2`;
- authoritative documents: updated `PROJECT_STATE.md`, `FUTURE_WORK.MD` and ADR-039 at the ending ref.

### Evidence

- one shared Axis bank-account CSV parser/profile supports the approved NRE and supplied NRO evidence;
- distinct full account identifiers produce distinct durable accounts;
- historical `axis.nre.csv@1` provenance remains unchanged;
- canonical TestPlan passed 394 tests across 48 suites;
- Debug/Release builds and analyses passed;
- disposable runtime verified two accounts, 118 transactions, relaunch hydration and zero remaining processes;
- no migration or new ADR was required.

### Decision effect

- Sprint 53 changed from Discovery to Complete implementation;
- former Sprint 54 Axis NRO implementation was absorbed and marked Replaced;
- partial-overlap discovery and implementation move to Sprints 54–55;
- categories move to Sprint 56;
- deterministic import verification workspace moves to Sprint 57;
- PDF and cross-format discovery moves to Sprint 58;
- Sprint 59 becomes the repeated singleton build/launch/runtime-verification follow-up;
- HDFC remains outside the active cycle until approved source evidence and fixtures establish its layout relationships.

## 2026-07-23 — P0 presentation defect overrides Sprint 54 forecast

### Repository basis

- inspected pushed ref: `bdb51b0ddcdde097e456a16bab7f0bf999fd595b`;
- latest verified implementation: `11035461ce3de0f11ae5262bbc8a38b9639607b2`;
- authoritative documents reconciled: `PROJECT_STATE.md` and `FUTURE_WORK.MD`;
- no fresh build, test, runtime, migration, ADR or implementation work was performed.

### Evidence

- the durable attempt model defines 13 known outcomes;
- Dashboard Import Activity does not exhaustively map every known outcome;
- Import History defaults unhandled known and unknown outcomes to persistence failure;
- coverage and guidance presentation currently transforms raw persistence codes;
- the defect is verified but has not been attributed to Sprint 53.

### Decision effect

- insert `FW-P0-24` as standalone Sprint 54 rather than Sprint 53A;
- move partial-overlap discovery and implementation to Sprints 55–56;
- move categories to Sprint 57 with Migration V7 expected;
- move the deterministic import verification workspace to Sprint 58;
- retain PDF and binary-fingerprint discovery as Sprint 59;
- defer the singleton build and runtime-launch entrypoint to the 60–69 cycle;
- pause lower-priority feature execution until the P0 defect is accepted or explicitly deferred;
- authorize no implementation through this roadmap edit.

## Future log format

```markdown
## YYYY-MM-DD — <decision title>

### Repository basis
- Inspected ref:
- Authoritative documents:

### User, verbatim
> <material planning message>

### Decision effect
- Sprint affected:
- Status change:
- Reorder/correction:
- New blocker:
```
