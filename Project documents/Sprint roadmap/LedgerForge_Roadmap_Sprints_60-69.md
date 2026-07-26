# LedgerForge Roadmap: Sprints 60–69

## Control

**Purpose:** Private Chat-user roadmap, planning record and continuity aid  
**Repository authority:** None  
**Execution authority:** None  
**Visible to Work:** No  
**Visible to Codex:** No  
**GitHub status:** Keep outside Git; never repository authority  
**Synchronized repository baseline:** `main@e6926e9f74dcb68ecc724787cfb617e0b1dc7b6e`  
**Accepted prior-cycle ending ref:** `main@b661472a58fc24144361322f1853b8001437a3eb`  
**Latest verified production implementation:** Sprint 58 — Deterministic Import Verification Workspace  
**Latest completed sprint:** Sprint 59 — Immutable Source Snapshot and Exact Source-Byte Fingerprint Authority  
**Latest accepted ADR:** ADR-041  
**Current migration:** V8  
**Created:** 2026-07-26  
**Cycle:** Sprints 60–69

This file forecasts and records Chat-user planning. It does not authorize Work, Codex, implementation, Git operations, migrations, ADR changes or repository edits.

Before every sprint decision, Chat must inspect the exact current repository ref, the current private roadmap, `PROJECT_STATE.md`, `FUTURE_WORK.MD`, accepted ADRs and relevant code/tests. Repository evidence overrides this roadmap.

Work and Codex must never receive this file. They receive only the bounded prompt approved for their immediate task.

---

## Operating rules

### Fixed cycle and corrective numbering

This cycle contains Sprints 60 through 69.

A blocking defect directly attributable to Sprint `N` is handled as Sprint `NA`. Sprint `NB` is used only for another separately bounded correction directly attributable to the same parent sprint. Later numbered sprints do not move.

An unrelated verified P0 defect interrupts the roadmap as standalone integrity work. It must not be disguised as a correction to the preceding sprint.

### Priority and readiness

Review candidates in this order:

1. P0 integrity and safety;
2. P1 core capability;
3. P2 workflow and experience;
4. P3 later expansion.

Priority and readiness are separate. A high-priority candidate may remain outside the numbered sequence when it lacks a concrete evidence family, affected database, accepted architecture or bounded validation oracle.

### Status vocabulary

| Status | Meaning |
|---|---|
| **Complete** | Verified and accepted |
| **Selected** | Chat has approved one complete execution prompt |
| **In progress** | Approved Work or Codex execution is active |
| **Forecast** | Strong current expectation; not authorized |
| **Conditional** | Depends on named earlier evidence or acceptance |
| **Discovery** | Read-only decision or readiness outcome |
| **Ready for planning** | Sufficiently bounded for fresh Chat planning |
| **Deferred** | Valid work outside the active numbered sequence |
| **Replaced** | Later evidence invalidated or absorbed the earlier forecast |

Only **Selected** and **In progress** authorize execution.

### Mode ownership

- **Chat:** roadmap, sprint selection, architecture, prompt preparation and report acceptance.
- **Work:** bounded read-only local evidence that GitHub cannot establish.
- **Codex:** edits, builds, tests and Git operations only from an approved Chat prompt.
- **Private roadmap:** Chat-user only; invisible to Work and Codex.

### Acceptance and reconciliation

After every accepted sprint:

- verify the exact ending pushed ref;
- reconcile the sprint card and later dependencies;
- record migration and ADR impact;
- insert any justified corrective suffix without moving later numbers;
- update the append-only decision log;
- replace the active project-source copy so one current roadmap remains.

A green suite is not acceptance until its scope and oracle independence are verified.

---

## Current project state

- Production import support remains limited to the approved Axis bank-account CSV grammar.
- New supported Axis imports use `axis.bank-account.csv@2`: physical DR is debit/outflow and physical CR is credit/inflow.
- Migration V8 is current.
- ADR-041 accepts `ledgerforge.source-bytes.sha256.v1` and one immutable app-owned `SourceContentSnapshot` for future binary-capable imports.
- The source snapshot, source-byte fingerprint foundation and any related migration are not implemented.
- Existing `ledgerforge.raw-text.sha256.v1` history remains untouched.
- Production PDF, XLS, XLSX, card, HDFC and CBQ import support does not exist.
- ADR-040/V7 compatibility structures remain readable; the former Axis partial-import family is suspended and mixed supported overlap fails closed.
- Sprint 57 categories and current transaction assignments are operational; automatic categorization is not.
- Sprint 58's approved-fixture workspace is DEBUG-only and uses the ordinary production preparation/confirmation path.
- No retained affected historical Axis database is identified.
- `FW-P1-16` remains blocked until two equivalent formats are independently production-supported and a separate equivalence architecture is accepted.

---

## P0 priority gate

| Candidate | Current classification | Cycle treatment |
|---|---|---|
| `FW-P0-02` Historical Duplicate Review and Repair | Ready for targeted discovery, but no concrete independently provable repair family is selected | Deferred to a condition-triggered discovery campaign; not implementation-ready |
| `FW-P0-08` Data-Integrity Verification and Repair | Ready for targeted discovery, but broad and without a retained affected Axis database | Deferred until a concrete database or independently verifiable family exists |
| `FW-P0-10` Explain Account Match, No-Match and Conflict Outcomes | Ready for targeted discovery with reusable identity and attempt evidence | Assigned to Sprint 60; conditional implementation reserved for Sprint 61 |
| Other P0 work | Blocked or not supported by a current concrete defect | Re-evaluate before every sprint |

Lower-priority work may proceed only after every serious P0 candidate is classified at the exact ref under review.

---

## Cycle strategy

The cycle follows five stages:

1. **Identity truth:** discover and, if safe, implement privacy-safe account-outcome explanations.
2. **Binary source authority:** close the remaining ADR-041 schema/lifecycle decisions, then implement the source-snapshot foundation.
3. **Format expansion:** revalidate and implement one bounded Axis NRO PDF family only after foundation acceptance.
4. **Workflow truth:** improve confirmed-persistence recovery/guidance, transaction provenance and misleading UI/privacy boundaries.
5. **Execution reliability:** establish the local repository-owned build/test/singleton-launch entry points deferred from the prior cycle.

This sequence does not reserve space for every valid candidate. Deferred work remains in the canonical queue and is reconsidered after every accepted sprint.

---

## Cycle overview

| Sprint | Outcome | Candidates | Status | Confidence |
|---|---|---|---|---|
| **60** | Privacy-safe account-outcome explanation discovery | `FW-P0-10` | Discovery | High |
| **61** | Account match/no-match/conflict explanation implementation | `FW-P0-10` | Conditional on Sprint 60 | Medium-high |
| **62** | ADR-041 source-snapshot schema and lifecycle discovery | `FW-P1-18` | Discovery | High |
| **63** | Immutable source snapshot and source-byte fingerprint foundation | `FW-P1-18`, ADR-041 | Conditional on Sprint 62 | Medium |
| **64** | Axis NRO PDF R1 family revalidation and implementation-readiness decision | `FW-P1-10`, bounded `FW-P1-01` | Conditional discovery | Medium-high |
| **65** | One approved Axis NRO PDF production path | `FW-P1-10`, bounded `FW-P1-01` | Conditional on Sprints 63–64 | Medium |
| **66** | Confirmed-persistence recovery and bounded validation guidance | `FW-P1-28`, remaining `FW-P1-29` | Ready for planning | Medium-high |
| **67** | Transaction provenance and clearer detail presentation | `FW-P2-01`, `FW-P2-02` | Ready for planning | High |
| **68** | Truthful UI cleanup and privacy regression closure | `FW-P2-42`, `FW-P2-66` | Ready for planning | High |
| **69** | Repository-owned local validation and singleton launch entry points | bounded `FW-P2-69` | Forecast maintenance | Medium-high |

Forecast confidence decreases with distance. A verified P0 defect or failed acceptance boundary overrides this sequence without moving later sprint numbers.

---

# Sprint 60 — Account Outcome Explanation Discovery

**Status:** Discovery  
**Confidence:** High  
**Candidate:** `FW-P0-10`  
**Priority basis:** P0 financial identity safety

## Expected outcome

Define one bounded, privacy-safe explanation contract for why an import:

- matched an existing account;
- produced no match;
- required explicit account choice;
- became ambiguous;
- conflicted with existing identifier ownership.

The sprint returns an implementation-ready contract or a named blocker. It does not implement by default.

## Why first

`FW-P0-02` and `FW-P0-08` lack a concrete repair target. `FW-P0-10` is the highest-priority candidate with current reusable typed evidence and a bounded discovery question.

## Sequence

1. Chat verifies the current ref and roadmap.
2. Work performs read-only tracing only where repository documents and GitHub cannot establish presentation evidence efficiently.
3. Chat decides the allowed explanation vocabulary, redaction and surfaces.
4. If architecture changes are required, Chat records the ADR impact before Sprint 61.

## Included scope

- identity resolver and provider outcomes;
- account-decision provenance;
- prepared review, durable attempt history and account presentation boundaries;
- redacted reason codes and user guidance;
- accessibility and copy surfaces;
- hostile/unknown outcome behavior;
- distinction between strong identifier authority and weak labels.

## Exclusions

- manual linking or unlinking;
- identifier reassignment;
- incorrect-link repair;
- historical backfill;
- exposure of raw identifiers;
- account merge or split;
- automatic account choice.

## Acceptance boundary

- every supported outcome maps to independently justified evidence;
- weak names, filenames and labels are never presented as identity authority;
- raw identifiers cannot reach visible or copied presentation;
- implementation scope, tests, migration and ADR impact are explicit;
- Sprint 61 is either implementation-ready or cancelled with a named blocker.

## Stop conditions

Stop if the repository cannot prove an explanation without revealing identifier material, if durable evidence is insufficient, or if the work requires manual-linking policy.

## Migration and ADR impact

No migration is expected. An ADR amendment is required only if explanation semantics materially expand accepted identity architecture.

## Corrective policy

A discovery-document defect is corrected within Sprint 60 planning. No `60A` exists unless Sprint 60 is accepted and later found to have a separately bounded architecture defect.

---

# Sprint 61 — Privacy-Safe Account Outcome Explanations

**Status:** Conditional  
**Confidence:** Medium-high  
**Candidate:** `FW-P0-10`  
**Depends on:** Sprint 60 acceptance

## Expected outcome

Implement the bounded explanation contract across the approved preparation, review, attempt-history and account surfaces without changing identity decisions.

## Included scope

- typed presentation authority;
- neutral unknown handling;
- privacy-safe explanatory copy;
- shared semantics across approved surfaces;
- focused outcome-enumeration tests;
- privacy and accessibility regression coverage.

## Exclusions

- identity resolver changes;
- linking, unlinking or reassignment;
- raw identifier display;
- mutation or migration unless Sprint 60 explicitly proves one necessary;
- broad Import Centre redesign.

## Acceptance boundary

- explanations match authoritative typed outcomes;
- no explanation changes matching behavior;
- hostile values remain neutral;
- privacy tests prove no raw identifiers or source fragments;
- existing successful, no-match, conflict and duplicate flows remain unchanged;
- fresh builds/tests and representative presentation verification pass.

## Stop conditions

Stop if implementation would infer reasons not durably supported, alter resolver behavior, or widen into manual account management.

## Migration and ADR impact

Expected none. Any newly discovered migration or architecture requirement returns the sprint to Chat.

## Corrective policy

A shipped explanation defect directly caused by this sprint is Sprint 61A.

---

# Sprint 62 — Source Snapshot and Fingerprint Foundation Discovery

**Status:** Discovery  
**Confidence:** High  
**Candidate:** `FW-P1-18`  
**Architecture:** ADR-041

## Expected outcome

Resolve the remaining schema and lifecycle decisions required to implement ADR-041 without reopening the accepted exact-source-byte authority.

## Required decisions

- legacy role of `documents.sha256`;
- whether an additive migration is required;
- singular-to-multiple fingerprint ownership in domains, plans and providers;
- immutable `SourceContentSnapshot` storage form;
- security-scoped URL acquisition and ownership transfer;
- extraction and fingerprint consumption of the same snapshot;
- cleanup after success, rejection, cancellation and failure;
- concurrent preparation and contention;
- confirmation-time digest recomputation;
- typed rejected-attempt outcomes;
- SQLite/In-Memory parity and hydration behavior;
- diagnostics and privacy boundaries.

## Exclusions

- production implementation;
- PDF family implementation;
- historical fingerprint backfill;
- cross-format equivalence;
- password UI, Keychain or OCR;
- changing `ledgerforge.source-bytes.sha256.v1`.

## Acceptance boundary

The sprint must return:

- one bounded implementation contract;
- exact migration/no-migration decision;
- data ownership and cleanup lifecycle;
- provider and concurrency semantics;
- independent acceptance oracle;
- falsification matrix;
- exact included and excluded files/surfaces.

## Stop conditions

Stop if coexistence with raw-text history cannot be preserved, if source bytes would need durable retention merely for fingerprinting, or if schema semantics remain ambiguous.

## Migration and ADR impact

Migration is undecided until this sprint. ADR-041 remains authoritative; amend only if the implementation contract exposes a true architecture gap.

## Corrective policy

A discovery error is corrected before Sprint 63 selection. A post-acceptance architecture defect directly attributable to Sprint 62 may become 62A.

---

# Sprint 63 — Immutable Source Snapshot and Source-Byte Fingerprint Foundation

**Status:** Conditional  
**Confidence:** Medium  
**Candidate:** `FW-P1-18`  
**Depends on:** Sprint 62 acceptance  
**Architecture:** ADR-041

## Expected outcome

Implement one immutable app-owned source snapshot and `ledgerforge.source-bytes.sha256.v1` through preparation, confirmation, provider persistence and rejection paths without adding production PDF support.

## Included scope

- snapshot acquisition from sandbox-authorized source;
- exact source-byte digest;
- same-snapshot extraction and fingerprinting;
- confirmation-time recomputation;
- versioned fingerprint coexistence;
- provider parity;
- deterministic cleanup;
- typed acquisition/loss/mutation rejection;
- contention and injected-failure tests;
- hydration/relaunch without retained source bytes;
- privacy-safe diagnostics.

## Exclusions

- production PDF parser/profile;
- historical backfill;
- cross-format suppression;
- OCR or password workflow;
- durable full-source storage;
- unrelated reader or parser expansion.

## Acceptance boundary

- same bytes under another name produce the same source-byte digest;
- one-byte change produces a different digest;
- same extracted text with different bytes remains different exact content;
- missing or mutated snapshot rejects before accepted writes;
- every losing path leaves zero accepted financial residue;
- SQLite/In-Memory parity holds;
- legacy raw-text records remain untouched;
- success, cancellation and all failure paths clean task-owned source bytes;
- Release/privacy checks pass.

## Stop conditions

Stop if implementation requires inventing historical fingerprints, weakens existing CSV duplicate behavior, or cannot prove cleanup and provider parity.

## Migration and ADR impact

As decided by Sprint 62. No unapproved migration may be improvised.

## Corrective policy

Any blocking source-ownership, cleanup, duplicate or migration defect caused by this sprint is Sprint 63A.

---

# Sprint 64 — Axis NRO PDF R1 Revalidation and Readiness

**Status:** Conditional discovery  
**Confidence:** Medium-high  
**Candidates:** `FW-P1-10`, bounded `FW-P1-01`  
**Depends on:** Sprint 63 acceptance

## Expected outcome

Revalidate one approved Axis NRO bank-account PDF R1 family and return a deterministic production implementation contract or a named evidence blocker.

## Why this family

Current repository evidence makes Axis NRO R1 the smallest likely first PDF family because Axis detection, bank-account semantics, INR truth and account identity already exist. That is a hypothesis to falsify, not production support.

## Required evidence

- source-to-sanitized-fixture lineage;
- independent financial oracle;
- sandbox/security-scoped opening;
- deterministic page, row and multiline extraction;
- transaction order and grouping;
- statement period and dates;
- exact Money, direction and balances;
- account identifiers and parser/profile provenance;
- malformed, encrypted, image-only and unsupported-layout outcomes;
- falsification against similar unsupported Axis PDFs;
- ordinary picker/registry/reader/preparation path;
- Debug and optimized Release boundary.

## Exclusions

- implementation by default;
- HDFC or CBQ;
- card PDFs;
- password entry;
- OCR;
- generic PDF framework;
- cross-format duplicate suppression.

## Acceptance boundary

Select one exact layout/profile and prove its complete truth oracle, unsupported-layout boundary, implementation scope and acceptance plan. Otherwise return a blocker.

## Stop conditions

Stop if source lineage is inadequate, extraction order is not deterministic, the independent oracle depends on production parser output, or the selected PDF requires password/OCR support.

## Migration and ADR impact

No additional migration is expected beyond the accepted Sprint 63 foundation. A new parser/profile ADR is required only if current architecture cannot represent the selected layout safely.

## Corrective policy

A discovery defect is corrected before Sprint 65 selection. No 64A unless an accepted architecture defect is later proven.

---

# Sprint 65 — One Approved Axis NRO PDF Production Path

**Status:** Conditional  
**Confidence:** Medium  
**Candidates:** `FW-P1-10`, bounded `FW-P1-01`  
**Depends on:** Sprints 63 and 64 accepted

## Expected outcome

Promote exactly one approved Axis NRO PDF R1 layout through the ordinary production import pipeline.

## Included scope

- picker and source-format registry;
- production reader consuming the immutable snapshot;
- deterministic Axis institution/layout selection;
- one versioned parser/profile;
- complete independent-oracle parity;
- account identity;
- exact source-byte duplicate behavior;
- confirmation-gated provider persistence;
- hydration, relaunch and presentation;
- malformed/encrypted/image-only/unsupported rejection;
- Debug and optimized Release validation.

## Exclusions

- arbitrary Axis PDFs;
- HDFC, CBQ or card PDFs;
- password entry or Keychain;
- OCR;
- cross-format equivalence or suppression;
- generic PDF-layout inference;
- XLS/XLSX.

## Acceptance boundary

- source truth, ordering, Money, direction, balances, identifiers and provenance match the independent oracle;
- exact same PDF is rejected as an exact duplicate with zero accepted residue;
- a byte-different PDF with equivalent extracted text is not treated as exact duplicate;
- unsupported similar layouts fail closed;
- SQLite/In-Memory parity and relaunch behavior pass;
- production support claims remain limited to the one approved profile.

## Stop conditions

Stop if the parser must generalize beyond proven evidence, if security-scoped access is not deterministic, or if any PDF-only persistence path appears.

## Migration and ADR impact

Expected to use the Sprint 63 foundation. Any new schema or architecture need returns to Chat.

## Corrective policy

Financial, duplicate, provenance or Release defects caused by this sprint become Sprint 65A.

---

# Sprint 66 — Confirmed-Persistence Recovery and Validation Guidance

**Status:** Ready for planning  
**Confidence:** Medium-high  
**Candidates:** `FW-P1-28`, remaining `FW-P1-29`

## Expected outcome

For typed safe cases only, present truthful guidance and allow a wholly fresh re-preparation after confirmed-persistence failure without weakening repository authority.

## Why combine

The remaining recovery action and its user guidance share one outcome and safety boundary. Broad validation education remains excluded.

## Included scope

- enumerate retryable confirmed-persistence outcomes;
- fresh preparation only;
- no reuse of stale prepared state;
- repository and provider-generation rechecks;
- explicit non-retryable outcomes;
- user guidance matching actual safety;
- privacy-safe diagnostics;
- focused failure and zero-residue tests.

## Exclusions

- rollback;
- resumable jobs;
- cancellation after confirmation begins;
- batch import;
- retry of unsupported or ambiguous outcomes;
- broad Import Centre redesign.

## Acceptance boundary

Every offered action is supported by typed authoritative evidence; unavailable retry families remain unavailable; a fresh retry cannot duplicate accepted state or bypass confirmation.

## Stop conditions

Stop if any persistence failure lacks a trustworthy final-state classification or if retry requires rollback/compensation.

## Migration and ADR impact

None expected. New mutation or compensation semantics require separate architecture.

## Corrective policy

A retry-safety defect caused by this sprint is Sprint 66A.

---

# Sprint 67 — Transaction Provenance and Clearer Detail

**Status:** Ready for planning  
**Confidence:** High  
**Candidates:** `FW-P2-01`, `FW-P2-02`

## Expected outcome

Present authoritative account, source document and import-session provenance in a clearer transaction-detail layout without exposing developer-only or sensitive evidence.

## Why combine

The provenance fields and layout changes occupy one user surface and one acceptance boundary.

## Included scope

- account and import-session relationship;
- privacy-safe source-document metadata;
- current category display;
- clearer Money/date/direction presentation;
- removal of developer terminology;
- navigation to approved related surfaces;
- accessibility and empty/legacy states.

## Exclusions

- source-file reopening;
- raw source content;
- editable financial fields;
- notes, tags or splits;
- global document library;
- search/filter implementation;
- mutation of provenance.

## Acceptance boundary

Displayed provenance must come from durable relationships, not filenames or inference; legacy/unavailable evidence remains neutral; no sensitive identifier or source fragment is exposed.

## Stop conditions

Stop if required provenance is not durably available or if the layout requires a new source-retention policy.

## Migration and ADR impact

None expected.

## Corrective policy

A provenance misrepresentation or privacy defect caused by this sprint is Sprint 67A.

---

# Sprint 68 — Truthful UI and Privacy Regression Closure

**Status:** Ready for planning  
**Confidence:** High  
**Candidates:** `FW-P2-42`, `FW-P2-66`

## Expected outcome

Remove user-facing controls and financial claims that imply unsupported functionality, and add regression coverage preventing sensitive data from entering presentation or diagnostics.

## Why combine

Both candidates enforce truthful, privacy-safe presentation. The cleanup and regression suite can be accepted through one bounded UI/privacy plan.

## Included scope

- hardcoded spending percentages and unsupported trends;
- nonfunctional report affordances;
- pending/soon controls without actionable behavior;
- search placeholders that overstate implemented scope;
- drag-and-drop wording without drop behavior;
- raw identifier, password and source-fragment privacy tests;
- accessibility text aligned with real capability.

## Exclusions

- implementation of analytics;
- charts, budgeting or reporting;
- global search;
- drag-and-drop import;
- automatic categorization;
- broad visual redesign.

## Acceptance boundary

No user-facing element presents sample or hardcoded values as repository financial truth; unsupported actions are removed or clearly unavailable; privacy regressions cover visible, copied and diagnostic text.

## Stop conditions

Stop if removing a placeholder would conceal a real reachable feature, or if the scope expands into implementing the missing capability.

## Migration and ADR impact

None expected.

## Corrective policy

A new misleading financial claim or privacy leak introduced by this sprint becomes Sprint 68A.

---

# Sprint 69 — Repository-Owned Local Validation and Singleton Launch

**Status:** Forecast maintenance  
**Confidence:** Medium-high  
**Candidate:** bounded first slice of `FW-P2-69`

## Expected outcome

Provide repository-owned local entry points for deterministic build/test and exact-singleton LedgerForge launch, without attempting CI or broad UI automation.

## Why last

The capability reduces validation ambiguity across later cycles but does not outrank the earlier identity, source-truth and production-path work. It closes a repeatedly observed local workflow gap.

## Included scope

- one canonical local build/test entry point;
- one exact-name singleton kill/build/run entry point;
- graceful termination before escalation;
- proof of zero-instance precondition;
- one resolved freshly built app bundle;
- PID and executable-path verification before UI attachment;
- task-owned DerivedData;
- Debug/Release command documentation;
- privacy-safe logs;
- regression tests for script logic where practical.

## Exclusions

- CI service configuration;
- generic process killing;
- UI-test framework activation;
- release notarization;
- deployment;
- source-fixture mutation;
- canonical database launch by default.

## Acceptance boundary

The entry point cannot attach to stale DerivedData or a second process; it identifies the exact built bundle and process; it leaves no task-owned process or temporary build residue after verification; repository conventions document the supported commands.

## Stop conditions

Stop if safe process identification cannot be limited to exact LedgerForge targets, if signing/build provenance is ambiguous, or if implementation requires CI secrets or destructive cleanup.

## Migration and ADR impact

None expected. Build-convention documentation may change.

## Corrective policy

A process-safety or stale-build defect caused by this sprint becomes Sprint 69A.

---

## Deferred and conditional pool

| Candidate/group | Reason not numbered now |
|---|---|
| `FW-P0-02` historical duplicate repair | No selected independently provable historical family |
| `FW-P0-08` integrity repair | No retained affected Axis database and no single bounded family |
| `FW-P1-02` HDFC parser family | New institution plus unresolved first production format; reconsider after PDF foundation |
| `FW-P1-06` parser framework expansion | Too broad; requires a separately split outcome |
| `FW-P1-25` duplicate review/management | Former partial family suspended; no new immutable lineage family |
| `FW-P1-27` import-session reversal | Needs family-specific discovery, impact preview and atomic mutation contract |
| `FW-P1-16` cross-format equivalence | Blocked until two formats are independently production-supported |
| `FW-P2-03` + `FW-P2-53` search/filter controls | Valid bounded pair but displaced by higher-priority identity/source work and truth cleanup |
| `FW-P2-38` full account history | Ready for planning, displaced from this cycle |
| `FW-P2-34` account archive/restore | Needs lifecycle and persistence discovery |
| `FW-P2-52` preferences | Needs durable settings direction; reporting currency remains separately blocked |
| CI/UI-smoke portion of `FW-P2-69` | Split from local entry points; reconsider after Sprint 69 |

Deferred does not mean rejected. Every item is re-evaluated after accepted work or new evidence.

---

## Independent discovery campaigns

Independent campaigns are Chat-triggered, read-only and outside numbered sprints. They reduce later planning cost but cannot select implementation.

### DC-A — Historical integrity candidate intake

Launch only when the user supplies a concrete retained database or independently provable historical family.

Possible candidates:

- `FW-P0-02`;
- `FW-P0-08`;
- Axis provenance-led direction detection.

No private source is copied or mutated. No repair is authorized.

### DC-B — Institution and format comparison

After Sprint 63, compare:

- HDFC PDF versus XLS;
- CBQ bank-account PDF;
- remaining Axis layouts;
- parser-framework prerequisites.

Fixture availability is evidence for discovery, never production support.

### DC-C — Account lifecycle and preferences

Read-only discovery for:

- `FW-P2-34`;
- ordinary regional/display slice of `FW-P2-52`;
- durable account visibility and restoration semantics.

### Campaign rules

- pin one immutable pushed ref;
- do not inspect a half-edited checkout;
- no edits, branches, commits, pushes, builds or canonical database launch by default;
- return evidence, dependencies, risks and readiness only;
- never assign sprint numbers;
- never receive this private roadmap.

---

## Cycle-close procedure

After Sprint 69 and any attached correction:

1. establish exact pushed `main`;
2. inspect repository authorities and production evidence;
3. classify every Sprint 60–69 outcome;
4. record corrective sprints and independent discoveries;
5. perform one documentation synchronization;
6. create the private Sprints 70–79 roadmap;
7. archive this file as read-only history;
8. retain only evidence-valid unfinished work.

---

## File handling rules

- Keep the primary copy outside the Git checkout.
- Never supply this file to Work or Codex.
- Replace the ChatGPT project-source copy after every reconciliation so only one active revision exists.
- Keep the Sprints 50–59 archive separately as read-only history.
- Maintain a normal local backup.
- Do not use an archived roadmap as current sprint authority.

Suggested active filename:

```text
LedgerForge_Roadmap_Sprints_60-69.md
```

---

## Append-only planning and decision log

## 2026-07-26 — Sprints 60–69 cycle created

### Repository basis

- Synchronized baseline: `main@e6926e9f74dcb68ecc724787cfb617e0b1dc7b6e`
- Accepted prior-cycle ending ref: `main@b661472a58fc24144361322f1853b8001437a3eb`
- Latest production implementation: Sprint 58
- Latest completed sprint: Sprint 59
- Latest ADR: ADR-041
- Migration: V8

### Decision effect

- assign `FW-P0-10` discovery to Sprint 60 and conditional implementation to Sprint 61;
- assign ADR-041 implementation-foundation discovery and conditional implementation to Sprints 62–63;
- assign Axis NRO PDF R1 revalidation and conditional implementation to Sprints 64–65;
- assign bounded recovery/guidance, transaction provenance/detail and UI/privacy truth work to Sprints 66–68;
- assign the local entry-point slice of `FW-P2-69` to Sprint 69;
- defer broad historical repair until a concrete target exists;
- keep HDFC, reversal, search/filter and account lifecycle work in the deferred or discovery pools;
- authorize no implementation through roadmap creation.

## Future log-entry template

```markdown
## YYYY-MM-DD — <decision title>

### Repository basis
- Inspected ref:
- Roadmap revision:
- Authoritative documents:

### User, verbatim
> <material planning message>

### Decision effect
- Sprint affected:
- Status change:
- Reorder/correction:
- New blocker:
- Migration/ADR effect:
```
