# LedgerForge Roadmap: Sprints 50–59

## Control

**File purpose:** Private Chat-user planning, roadmap and decision archive  
**Repository authority:** None  
**Execution authority:** None  
**Visible to Work:** No  
**Visible to Codex:** No  
**Stored in GitHub:** Backup only; never an authoritative repository-planning source and never supplied to Work or Codex  
**Current repository baseline:** `main@d63c54f7a8117b36ff4849c0ad9453abb3fc9a80`  
**Last reconciled:** 2026-07-23  
**Roadmap cycle:** Sprints 50–59

This file is a private forecast and continuity record for Chat and the user. It does not authorize implementation, Git operations, branches, migrations, ADR changes, repository edits, Work investigation or Codex execution.

Current repository evidence always overrides this roadmap. A sprint becomes executable only after Chat revalidates the current repository and supplies one complete, current-conversation execution prompt.

The copy stored in GitHub exists only as user-controlled backup. It must not be treated as repository authority, included in repository-state reasoning, quoted to Work or Codex, or used as an execution prompt.

Work and Codex receive only the bounded prompt approved for their immediate task.

---

## Roadmap operating model

### Ten-sprint cycle

This file covers exactly Sprints 50 through 59.

After Sprint 59 is accepted or the cycle is explicitly closed, Chat performs cycle reconciliation and creates a new private roadmap for Sprints 60 through 69.

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
| **Reserved** | Sprint number retained for later evidence-based selection; no candidate is authorized |

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

- **Latest completed implementation sprint:** Sprint 52A — Strict Trusted Transaction Hydration and Provenance Closure.
- **Latest completed architecture and implementation sprint:** Sprint 52 — Trusted Statement Dates and Durable Source Provenance.
- **Current repository baseline:** pushed `main@d63c54f7a8117b36ff4849c0ad9453abb3fc9a80`.
- **Current migration:** V6.
- **Latest accepted ADR:** ADR-039 — Trusted Statement Dates and Durable Source Provenance.
- **Production parser support:** approved Axis NRE CSV profile only.
- **Trusted production import:** restored for the approved Axis NRE CSV profile after Sprint 52A verification.
- **Completed former RED blockers:**
  - `FT-P0-01` / `FW-P0-21` — Date-Only Semantic Preservation.
  - `FT-P0-02` / `FW-P0-22` — Durable Source Order and Provenance.
- **Current next decision:** perform read-only Axis NRO and Import Profile readiness discovery for `FW-P1-01` and `FW-P1-06`.
- **Known intentional limitation:** supported partial overlaps currently block the complete incoming statement; bounded partial import remains future work under `FW-P1-25`.
- **Known support boundary:** Axis NRO is not production-supported merely because a structurally similar source can pass through current code.
- **Local-state caveat:** GitHub cannot establish local branch, worktree cleanliness, stashes, uncommitted work or unpushed commits. These must be verified before any Codex execution.

---

## Ten-sprint overview

| Sprint | Expected outcome | Candidate IDs | Status | Confidence |
|---|---|---|---|---|
| **50** | Provider-owned atomic confirmed import, durable identifier ownership and Migration V5 activation | `FW-P0-05`, bounded `FW-P0-12` slice, ADR-038 | **Complete** | Verified |
| **51** | Fail closed on malformed recognized Axis transaction-date and account-identity evidence | `FT-P0-03`, `FT-P1-04` | **Complete** | Verified |
| **52** | Accept and implement faithful statement-date semantics plus durable source order and provenance through ADR-039 and Migration V6 | `FW-P0-21`, `FW-P0-22` | **Complete** | Verified |
| **52A** | Close trusted hydration, profile-provenance and trusted-writer boundaries exposed during Sprint 52 verification | Sprint 52 corrective scope | **Complete** | Verified |
| **53** | Prove the Axis NRO and reusable Import Profile boundary; decide combine or split for parser-family expansion | `FW-P1-01`, `FW-P1-06` | **Selected for planning; discovery not yet executed** | High for discovery |
| **54** | Implement the smallest approved profile-backed Axis NRO or prerequisite Import Profile slice | `FW-P1-01`, bounded `FW-P1-06` slice | **Conditional** | Medium |
| **55** | Discover explicit partial-overlap review and unique-transaction import semantics | `FW-P1-25`, possible bounded `FW-P2-12` relationship | **Conditional** | Medium |
| **56** | Implement bounded, explicit partial-overlap import without silent transaction omission | `FW-P1-25` | **Conditional** | Medium |
| **57** | Implement durable categories and manual single-transaction classification | `FW-P2-20`, ADR-036 | **Conditional** | Medium |
| **58** | Strongest evidence-valid P1 or P2 outcome remaining after Sprint 57 reconciliation | To be selected from current `FUTURE_WORK.MD` | **Reserved** | Low |
| **59** | Final bounded outcome or explicit close of the 50–59 cycle | To be selected from current `FUTURE_WORK.MD` | **Reserved** | Low |

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

Sprint 50 is repository-recorded as the implementation of ADR-038's confirmed-import production slice. It is the baseline architecture on which later provenance-bearing imports build.

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

Sprint 51 stopped two fail-open paths but deliberately left the broader date-only and source-provenance defects unresolved.

---

## Sprint 52 — Trusted Statement Dates and Durable Source Provenance

### Status

**Complete and verified**

### Outcome

LedgerForge now preserves supported Axis statement transaction dates as strict date-only financial evidence and retains document-scoped source order and bounded durable provenance through parsing, validation, provider-atomic persistence, hydration, relaunch and presentation.

### Candidates and architecture basis

- `FW-P0-21 — Date-Only Semantic Preservation`
- `FW-P0-22 — Durable Source Order and Provenance`
- ADR-039
- Migration V6

### Delivered boundary

- immutable source-faithful statement-date domain without `Foundation.Date` conversion;
- canonical date-only persistence and exact hydration;
- Axis `Asia/Kolkata` date authority for the approved profile;
- reader-owned document-scoped source ordinal;
- normalized-record digest and parser-profile provenance;
- provider-owned atomic transaction and provenance persistence;
- SQLite and In-Memory provider-equivalent behavior;
- V6 fail-closed treatment of nonempty V5 financial graphs rather than invented history;
- source-supported same-document ordering and running-balance interpretation;
- independent date, source-order and financial-truth verification;
- trusted import restoration for the approved Axis NRE CSV profile, subject to Sprint 52A closure.

### Explicit exclusions retained

- reconstruction of legacy dates, order or provenance;
- inferred global order across documents;
- new institution, layout or format support;
- partial-overlap import;
- historical duplicate repair;
- raw full-document retention;
- unrelated UI redesign;
- categories.

### Roadmap deviation

The original roadmap expected a separate architecture sprint followed by a separate implementation sprint.

Current repository evidence shows that the accepted architecture, ADR-039, Migration V6 and production implementation were completed together as Sprint 52.

The old forecasted Sprint 53 architecture and Sprint 54 implementation entries are therefore replaced by the actual Sprint 52 outcome. Completed reality outranks forecast choreography, despite humanity’s fondness for pretending plans control events.

### Roadmap effect

- `FW-P0-21` is complete.
- `FW-P0-22` is complete.
- Migration V6 is active.
- ADR-039 is accepted.
- The next unresolved product boundary moves to Axis NRO and reusable Import Profiles.

---

## Sprint 52A — Strict Trusted Transaction Hydration and Provenance Closure

### Status

**Complete and verified corrective sprint**

### Outcome

Sprint 52A closed the remaining trusted persistence-to-runtime and writer-authority defects exposed during Sprint 52 verification.

### Why the correction was required

Sprint 52 established the correct durable model, but verification exposed remaining paths where malformed or incomplete trusted provenance could enter hydration or where trusted transactions could be written through an insufficiently constrained mutation surface.

Those defects directly affected acceptance of Sprint 52 and therefore qualified as Sprint 52A rather than unrelated new work.

### Delivered boundary

- trusted hydration rejects unsupported financial-date roles;
- malformed or invalid-IANA timezone evidence fails before runtime-store mutation;
- missing or conflicting source relationships fail closed;
- trusted hydration reads actual parser profile ID and version from both providers;
- no parser-profile provenance is defaulted, reconstructed or hardcoded;
- generic transaction replacement rejects trusted transaction writes;
- confirmed import validates complete normalized source relationships atomically;
- malformed trusted provenance leaves zero accepted durable residue;
- SQLite/In-Memory parity verified;
- hydration and relaunch behavior verified;
- complete serial TestPlan verification passed;
- no migration, ADR, parser-family or format expansion was added.

### Explicit exclusions retained

- new parser support;
- import-profile generalization;
- historical provenance repair;
- partial-overlap import;
- categories;
- unrelated UI work.

### Roadmap effect

Sprint 52A satisfies the corrective-sprint rule.

Trusted Axis NRE import is no longer blocked by the date/provenance hydration boundary.

The original numbered roadmap sequence resumes at Sprint 53.

---

## Sprint 53 — Axis NRO and Import Profile Readiness Discovery

### Status

**Selected for planning; discovery not yet executed**

### Confidence

**High for bounded discovery; implementation remains conditional**

### Selected outcome

Produce an evidence-grade decision on whether one approved Axis NRO layout can enter production through a narrowly reusable, versioned Import Profile boundary, or whether parser-framework work and NRO implementation must remain separate.

### Candidates

- `FW-P1-01 — Axis Bank Parser Family Expansion`
- `FW-P1-06 — Parser Framework Expansion`

### Priority classification

| Candidate | Classification | Reason |
|---|---|---|
| `FW-P0-10` | Ready for discovery but deferred | No verified current financial-correctness defect requires it before parser-family readiness |
| `FW-P0-16` | Blocked | Named dependencies remain unresolved |
| `FW-P0-20` | Research | Not implementation-ready and not stronger than the selected bounded P1 discovery |
| `FW-P1-01` | Ready for targeted discovery | Axis NRO support remains unproven and requires source-backed readiness work |
| `FW-P1-06` | Ready for targeted discovery | The reusable Import Profile boundary is inseparable from deciding the safe NRO implementation shape |
| `FW-P1-10` | Deferred | PDF support is broader and less ready than one proven CSV layout |
| `FW-P1-25` | Deferred to Sprint 55 | Important, but follows parser and provenance foundations |
| `FW-P1-40` | Deferred | Useful development tooling, but not stronger than a user-facing parser-family expansion boundary |
| `FW-P2-20` | Implementation-ready but deferred | Lower priority than unresolved P1 parser expansion |
| `FW-P2-34` | Deferred | Lower-priority lifecycle feature |
| `FW-P2-52` | Deferred | Lower-priority preference work |

### Combine or split decision

Combine `FW-P1-01` and `FW-P1-06` for discovery only because they share one decision boundary:

- deterministic layout recognition;
- semantic column-role resolution;
- parser-profile identity and versioning;
- source-to-fixture provenance;
- CSV grammar;
- account-identity semantics;
- independent financial truth;
- compatibility with the Sprint 52 date and provenance architecture.

Do not combine implementation merely to increase throughput.

A combined implementation is permitted only if discovery proves that:

1. one approved Axis NRO layout is independently verifiable;
2. the minimum reusable Import Profile abstraction is required for that layout;
3. the abstraction does not silently generalize support to unproven layouts;
4. the complete outcome can be validated by one bounded acceptance plan.

### Mode

**Work: bounded, read-only investigation**

Work is justified because the remaining unknowns concern:

- private or locally held Axis NRO source material;
- source-to-fixture provenance;
- filesystem-visible fixture chains;
- broad reader/parser/persistence tracing;
- exact CSV grammar behavior;
- potential repository and local evidence that GitHub alone may not establish efficiently.

Work does not select the sprint, edit files, implement code, create branches or make architecture decisions.

### Exact unknown

Whether one deterministic Axis NRO CSV layout exists that LedgerForge can safely support using a minimal reusable Import Profile without guessing layout semantics, account identity, source dates, source order, balances or financial truth.

### Why the unknown affects the decision

Without this evidence, Chat cannot determine whether Sprint 54 should be:

1. one combined Axis NRO plus minimal Import Profile implementation;
2. an Import Profile foundation sprint only;
3. a fixed parser-family extension without reusable framework work;
4. blocked pending better source or oracle evidence.

### Required Work evidence

Work must return:

1. **Exact baseline**
   - inspected immutable pushed commit;
   - relevant authoritative repository documents;
   - explicit statement that local mutable state was not treated as repository truth unless separately inspected.

2. **Source evidence**
   - available Axis NRO originals or privacy-safe equivalents;
   - document provenance;
   - account type and statement-period evidence;
   - whether each source is approved for local read-only investigation;
   - whether sanitization preserves all financial semantics.

3. **Fixture chain**
   - source-to-sanitized-fixture derivation;
   - fields transformed;
   - fields preserved;
   - proof that transformations do not alter transaction count, direction, scale, currency, dates, source order, balances, identifiers or parser-selection evidence.

4. **Independent financial oracle**
   - transaction count;
   - debit and credit direction;
   - native currency;
   - decimal scale;
   - transaction dates;
   - physical source order;
   - opening balance;
   - closing balance;
   - running-balance continuity;
   - account identifier evidence;
   - statement-period evidence where present.

   Production parser output, generated expected JSON or implementation-derived fixtures must not be the sole oracle.

5. **Reader and CSV grammar**
   - delimiter behavior;
   - quoted commas;
   - escaped quotes;
   - embedded line breaks;
   - CRLF and LF handling;
   - empty fields;
   - leading and trailing whitespace;
   - byte-order mark behavior;
   - malformed records;
   - duplicate or ambiguous headers;
   - repeated header sections;
   - footer and summary-row handling.

6. **Deterministic selection**
   - institution recognition;
   - statement-family recognition;
   - NRO layout recognition;
   - supported-profile identity;
   - unsupported-layout rejection;
   - evidence that NRE and NRO layouts cannot be confused.

7. **Semantic role mapping**
   - transaction date;
   - value date where present;
   - description or narration;
   - debit;
   - credit;
   - amount;
   - direction;
   - balance;
   - currency;
   - account identifier;
   - statement period;
   - source ordinal.

8. **Account identity**
   - exact source-supported identifier evidence;
   - whether NRE and NRO accounts are distinguishable;
   - whether weak or partial values must remain non-authoritative;
   - conflict and malformed-evidence behavior;
   - whether any merge or resolver behavior would be required.

9. **Architecture trace**
   - reader;
   - parser selector;
   - parser;
   - validation;
   - import preparation;
   - confirmation;
   - provider-atomic persistence;
   - durable provenance;
   - hydration;
   - relaunch;
   - presentation;
   - duplicate and event-identity compatibility.

10. **Import Profile boundary**
    - owner and domain location;
    - profile identifier;
    - version semantics;
    - supported institution and account family;
    - required and optional semantic roles;
    - date authority;
    - source-order authority;
    - identifier rules;
    - layout recognition;
    - unsupported-layout handling;
    - migration behavior;
    - whether profiles are code-defined, data-defined or hybrid;
    - explicit reasons not to build a broader framework.

11. **Migration and ADR impact**
    - whether V6 can represent the new profile without migration;
    - whether persisted parser-profile provenance already supports the extension;
    - whether ADR-039 needs amendment;
    - whether a new accepted ADR is required for Import Profiles;
    - whether no ADR change is sufficient.

12. **Falsification analysis**
    - evidence that would disprove NRO readiness;
    - layouts that appear similar but are semantically incompatible;
    - malformed evidence currently accepted;
    - tests that could pass while financial truth remains wrong;
    - risks of fixtures derived from parser behavior;
    - risks of profile abstraction broadening unsupported claims.

13. **Final classification**
    - implementation-ready combined slice;
    - split required;
    - blocked by named missing evidence.

### Included scope

- one or more approved Axis NRO source candidates;
- fixture provenance requirements;
- independent expected financial truth;
- deterministic NRO detection;
- deterministic layout recognition;
- exact semantic column roles;
- account-identifier and NRE/NRO separation semantics;
- reader and CSV grammar requirements;
- Import Profile ownership and version boundary;
- compatibility with Sprint 52 date and provenance semantics;
- migration and ADR impact;
- implementation acceptance plan;
- combine or split recommendation.

### Explicit exclusions

- Swift edits;
- test edits;
- fixture edits;
- repository-document edits;
- production NRO support claims;
- parser implementation;
- generalizing to every Axis account layout;
- Axis cards;
- PDF support;
- XLS or XLSX support;
- learning mode;
- AI-assisted column mapping;
- heuristic institution matching;
- heuristic layout matching;
- silent fallback from unsupported layouts;
- production parser output as the sole financial-truth oracle;
- account merging;
- historical data repair;
- access to this private roadmap.

### Acceptance boundary

Sprint 53 completes only with one of three evidence-backed outcomes.

#### Outcome A — Implementation-ready combined slice

Evidence proves:

- one approved NRO layout;
- deterministic profile selection;
- independent financial truth;
- safe NRE/NRO identity separation;
- complete date and provenance compatibility;
- minimum reusable Import Profile architecture;
- one bounded implementation and acceptance plan.

#### Outcome B — Split required

Evidence proves that:

- a reusable Import Profile foundation is required first;
- NRO implementation cannot safely fit the same bounded outcome;
- the prerequisite boundary and later NRO boundary are each independently testable.

#### Outcome C — Blocked

One or more named dependencies remain unavailable, such as:

- approved source evidence;
- fixture provenance;
- independent financial oracle;
- deterministic parser selection;
- account identity;
- balance truth;
- CSV grammar;
- privacy-safe fixture preparation.

Structural similarity alone is rejection evidence, not support evidence.

### Stop conditions

Stop if:

- approved source provenance cannot be established;
- independent expected financial truth cannot be produced;
- NRO and NRE identity cannot be safely distinguished;
- parser selection requires heuristic guessing;
- source dates, source order, balances or identifiers would require invention;
- the proposed scope silently broadens support beyond the proven layout;
- private source material cannot be inspected within the approved read-only boundary;
- fixture sanitization would destroy evidence needed for acceptance.

### Migration and ADR impact

Sprint 53 performs no migration, ADR or source change.

Discovery must determine whether Sprint 54 requires:

- no migration under V6;
- an ADR-039 amendment;
- a new Import Profile ADR;
- or a prerequisite framework increment.

---

## Sprint 54 — Profile-Backed Axis NRO or Import Profile Foundation

### Status

**Conditional on Sprint 53 producing an implementation-ready boundary**

### Confidence

**Medium**

### Expected outcome

Implement either:

1. the smallest approved deterministic Axis NRO production slice with the minimum required Import Profile boundary; or
2. if Sprint 53 requires a split, the prerequisite Import Profile foundation only.

The implementation must follow the exact combine or split decision returned by Sprint 53.

It must not claim NRO production support unless the approved source and independent financial-truth boundary passes end to end.

### Candidates

- `FW-P1-01 — Axis Bank Parser Family Expansion`
- possible bounded implementation slice of `FW-P1-06 — Parser Framework Expansion`

### Why this follows Sprint 53

Sprint 53 determines whether one approved Axis NRO layout can safely reuse or establish a versioned Import Profile boundary.

Sprint 54 implements only the evidence-approved result.

The trusted date and source-provenance foundation is already delivered by Sprint 52 and Sprint 52A.

### Expected sequence

1. **Chat** verifies:
   - exact Sprint 53 conclusion;
   - current pushed `main`;
   - accepted ADRs;
   - canonical queue;
   - migration state;
   - local branch, worktree, stash and divergence safeguards.

2. **Chat** supplies one complete Codex execution prompt with:
   - exact included scope;
   - exact exclusions;
   - source and fixture boundaries;
   - independent oracle;
   - migration and ADR decisions;
   - acceptance matrix;
   - stop conditions.

3. **Codex** implements directly on `main` only after repository safeguards pass.

4. **Codex** adds the exact required:
   - fixture-provenance tests;
   - parser-selection tests;
   - financial-oracle tests;
   - validation tests;
   - provider-parity tests;
   - atomicity and zero-residue tests;
   - hydration tests;
   - relaunch tests;
   - presentation tests;
   - Debug and Release verification.

5. **Chat** independently verifies:
   - starting and ending refs;
   - changed files;
   - included and excluded scope;
   - migration and ADR impact;
   - independent-oracle use;
   - support claims;
   - documentation;
   - repository cleanliness;
   - push result;
   - limitations and falsification analysis.

### Expected included scope if combined implementation is approved

- one approved Axis NRO layout or profile;
- deterministic institution detection;
- deterministic statement-family classification;
- exact semantic header-role resolution;
- strict unsupported-layout rejection;
- versioned Import Profile identity;
- source-supported account identity;
- NRE/NRO separation;
- strict date-only parsing;
- document-scoped source order;
- durable source provenance;
- transaction count, direction, money, date, order and balance verification;
- unified import validation and confirmation;
- provider-atomic persistence;
- hydration and relaunch;
- duplicate and event-blocking compatibility;
- SQLite/In-Memory parity;
- truthful supported-source presentation;
- synchronized repository documentation.

### Expected included scope if split implementation is approved

- minimum Import Profile domain contract;
- deterministic profile identity and version;
- semantic role definitions;
- required and optional role handling;
- layout recognition contract;
- date and source-order authority;
- account-identifier rules;
- unsupported-layout rejection;
- parser-selection integration;
- provenance compatibility;
- tests proving that no new production layout is claimed;
- no NRO production support until a later sprint.

### Explicit exclusions

- NRE/NRO account merge;
- savings or current-account expansion beyond the approved layout;
- Axis cards;
- historical Axis layouts;
- PDF;
- XLS;
- XLSX;
- heuristic layout matching;
- heuristic institution matching;
- learning mode;
- AI column mapping;
- partial-overlap import;
- historical repair;
- generic parser rewrite;
- unrelated UI redesign;
- categories.

### Acceptance boundary if NRO support is implemented

An untouched approved NRO source or privacy-safe equivalent must independently match expected financial truth through:

1. reading;
2. profile selection;
3. parsing;
4. validation;
5. preparation;
6. confirmation;
7. atomic persistence;
8. hydration;
9. provider reconstruction;
10. relaunch;
11. presentation;
12. exact re-import behavior.

Acceptance must independently prove:

- transaction count;
- debit and credit direction;
- native currency and scale;
- date-only truth;
- source order;
- opening and closing balances;
- running-balance continuity;
- account identity;
- parser-profile provenance;
- zero accepted residue on rejection.

### Acceptance boundary if foundation only is implemented

Acceptance must prove:

- no production NRO support is claimed;
- profile identity and version are deterministic;
- unsupported layouts fail closed;
- existing Axis NRE behavior is unchanged;
- no financial truth is inferred;
- future NRO support can be added without replacing the profile contract;
- both providers remain equivalent where applicable.

### Stop conditions

Stop if:

- repository safeguards fail;
- the Sprint 53 evidence boundary cannot be reproduced;
- fixture provenance differs from the approved chain;
- the independent oracle is unavailable;
- support requires heuristic guessing;
- NRE and NRO identity can conflict;
- malformed or unsupported layouts could enter trusted import;
- implementation broadens beyond one proven layout;
- a migration or ADR is required but was not approved;
- source truth cannot be preserved without invention.

### Corrective policy

A support-boundary, financial-truth, persistence or hydration failure becomes Sprint 54A.

Do not proceed to Sprint 55 while newly claimed parser or profile behavior remains untrustworthy.

---

## Sprint 55 — Partial-Overlap Import Architecture Discovery

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

The current supported Axis UPI transaction-event contract intentionally blocks the complete incoming statement when any verified owned event is found.

It does not silently omit duplicated rows.

The future goal is not silent discard. It is an explicit partial-import result with preserved source evidence, review and truthful durable outcome.

### Expected sequence

1. **Chat** verifies:
   - current duplicate rules;
   - event-identity rules;
   - attempt-history semantics;
   - statement provenance;
   - source-row provenance;
   - account-balance interpretation;
   - provider-atomic confirmation behavior.

2. **Work** performs targeted read-only discovery:
   - classify exact statement duplicate;
   - classify supported event overlap;
   - classify repeated incoming event;
   - classify speculative duplicate;
   - classify unsupported event family;
   - determine which overlap classes may permit partial import;
   - define user review and confirmation evidence;
   - define partial statement/session/attempt provenance;
   - define account-balance continuity;
   - define same-day source-order behavior;
   - define transaction-time revalidation;
   - define concurrent winner and loser behavior;
   - assess migration and ADR needs;
   - separate historical repair from prospective partial import.

3. **Chat** decides:
   - whether `FW-P1-25` and a bounded `FW-P2-12` slice share one outcome;
   - which supported event family is included;
   - durable partial-import representation;
   - review and confirmation contract;
   - next implementation boundary.

### Included scope

- prospective supported overlap review;
- exact explanation of existing versus incoming-unique rows;
- source document provenance;
- source-row provenance;
- explicit confirmation;
- provider-atomic transaction-time revalidation;
- truthful partial-import durable outcome;
- exact account and statement coverage semantics;
- source-supported same-day order;
- zero accepted residue on conflict or stale review;
- combine or split decision for `FW-P2-12`;
- migration and ADR impact.

### Explicit exclusions

- silent duplicate removal;
- speculative fuzzy matching;
- unsupported transaction-event families;
- historical duplicate repair;
- legacy fingerprint reconstruction;
- import-session reversal;
- generic mutation engine;
- batch import;
- cross-format duplicate identity;
- editable imported financial truth;
- automatic conflict resolution.

### Acceptance boundary

Discovery must define:

- the exact supported overlap family;
- authoritative event evidence;
- unique-subset calculation;
- user-visible review;
- immutable confirmation plan;
- transaction-time revalidation;
- source and attempt provenance;
- account balance and coverage semantics;
- provider-equivalent atomic outcomes;
- zero-residue rejection behavior;
- one bounded implementation acceptance matrix.

### Stop conditions

Stop if:

- the unique subset cannot be proven from approved event evidence;
- partial import would require fuzzy inference;
- the durable result cannot truthfully distinguish full and partial import;
- account continuity cannot be preserved;
- source order would be lost;
- commit-time revalidation cannot atomically preserve ownership and provenance;
- historical repair is required to make prospective partial import work.

---

## Sprint 56 — Explicit Partial-Overlap Import

### Status

**Conditional on Sprint 55 architecture and acceptance plan**

### Confidence

**Medium**

### Expected outcome

For the approved supported overlap family, LedgerForge shows the existing and unique incoming transactions, requires explicit confirmation, revalidates at commit time and atomically persists only the approved unique transactions with truthful partial-import provenance.

### Candidate

- `FW-P1-25 — Duplicate-Import Review and Management`

A bounded `FW-P2-12` slice is included only if Sprint 55 proves it is part of the same prospective review outcome.

### Expected sequence

1. **Chat** approves:
   - exact overlap family;
   - durable outcome;
   - review contract;
   - accepted event evidence;
   - exclusions;
   - migration and ADR impact;
   - test oracle.

2. **Codex** implements against the accepted duplicate and provenance architecture.

3. **Codex** verifies:
   - no-overlap;
   - full-overlap;
   - partial-overlap;
   - exact statement duplicate;
   - repeated incoming event;
   - concurrent overlap ownership;
   - stale reviewed plan;
   - injected failure;
   - provider parity;
   - hydration;
   - provider reconstruction;
   - relaunch;
   - presentation.

4. **Chat** checks that:
   - no transaction is silently omitted;
   - the unique subset is independently proven;
   - no historical repair entered scope;
   - no unsupported event family was generalized;
   - losing paths leave zero accepted residue.

### Expected included scope

Subject to Sprint 55:

- review model for existing and unique supported events;
- explicit user confirmation;
- immutable reviewed partial-import plan;
- provider-generation binding;
- account-decision binding;
- transaction-time event ownership revalidation;
- atomic persistence of unique transactions only;
- document provenance;
- session provenance;
- attempt provenance;
- source-row linkage for imported rows;
- source-row treatment for rows rejected as already existing where approved;
- deterministic current-balance presentation;
- truthful statement-coverage presentation;
- SQLite/In-Memory parity;
- zero losing-path residue;
- exact supported outcome guidance.

### Explicit exclusions

- automatic partial import without review;
- fuzzy duplicates;
- unsupported IMPS, NEFT, card, refund or reversal families unless Sprint 55 explicitly proves and approves them;
- historical cleanup;
- delete or reverse import;
- batch queue;
- editable corrections;
- generic duplicate engine;
- cross-format duplicate matching;
- inferred event identity;
- transaction mutation unrelated to partial import.

### Acceptance boundary

Independent source and event evidence must prove the exact unique subset.

The resulting durable history, attempt record and UI must distinguish:

- full import;
- partial import;
- full-overlap block;
- exact statement duplicate;
- rejected stale review;
- concurrent losing attempt.

No imported transaction may lose its source date, source order, document relationship or parser-profile provenance.

### Stop conditions

Stop if:

- the unique subset differs between providers;
- any transaction is silently omitted;
- source provenance cannot represent the partial outcome;
- account balance becomes ambiguous;
- stale review can commit;
- concurrency can produce duplicate ownership;
- losing paths leave accepted residue;
- unsupported event families are required.

### Corrective policy

Any silent omission, incorrect unique-set selection, source-order loss, provenance loss or account-balance regression becomes Sprint 56A.

---

## Sprint 57 — Durable Categories and Manual Transaction Classification

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

### Why it follows the integrity work

This is the first substantial user-facing organization feature after trusted transaction evidence is restored and the selected parser and overlap work is resolved.

It is already architecture-prepared but remains below unresolved P1 financial-import work.

It no longer necessarily closes the cycle because Sprints 58 and 59 are reserved for evidence-valid outcomes selected after reconciliation.

### Expected sequence

1. **Chat** verifies:
   - current transaction identity;
   - provider generation;
   - hydration;
   - provider reconstruction;
   - relaunch;
   - lifecycle backup and recovery;
   - migration state;
   - existing ADR-036 assumptions.

2. **Chat** confirms the bounded first category implementation remains coherent after Sprints 54 and 56.

3. **Chat** supplies one exact Codex execution prompt.

4. **Codex** implements directly on `main` after repository safeguards pass.

5. **Chat** verifies persistence, hydration, relaunch, presentation and mutation boundaries.

6. After acceptance, Chat reconciles the remaining Sprint 58 and Sprint 59 slots against the then-current canonical queue.

### Expected included scope

- workspace-owned durable categories;
- immutable category identity;
- root category plus one child level;
- one current category per transaction;
- Uncategorized represented by no assignment;
- user-created categories only;
- deterministic normalized-name ordering;
- deterministic immutable-ID tie-breaking;
- durable persisted transaction identity exposed during hydration if not already delivered;
- category persistence;
- transaction-assignment persistence;
- dedicated category repository;
- SQLite/In-Memory parity;
- provider-generation protection;
- one repository-write lease through canonical reconciliation;
- observer-consistent hydration snapshot;
- Settings category create;
- Settings category rename;
- Settings category archive;
- Settings category restore;
- Settings category delete when unused;
- transaction category display;
- transaction-detail assign;
- transaction-detail change;
- transaction-detail clear;
- lifecycle backup and recovery verification;
- additive migration number selected from the then-current chain.

### Explicit exclusions

- automatic categorization;
- categorization rules;
- AI suggestions;
- merchant or payee normalization;
- recurring detection;
- analytics;
- budgets;
- multiple categories;
- tags;
- transaction splits;
- category filtering;
- bulk assignment;
- delete with replacement;
- category merge;
- assignment history;
- global undo;
- source financial-value edits;
- imported narration edits.

### Acceptance boundary

The persisted transaction ID must survive:

- forced hydration;
- provider reconstruction;
- relaunch;
- category assignment;
- category clearing;
- category archive and restore;
- lifecycle backup and recovery.

Category mutations must never:

- use regenerated runtime identity;
- rewrite source financial values;
- rewrite source date;
- rewrite source order;
- alter parser-profile provenance;
- bypass provider-generation protection;
- produce SQLite/In-Memory divergence.

### Stop conditions

Stop if:

- durable transaction identity is unavailable;
- category mutation requires source transaction rewriting;
- provider-generation safety is unresolved;
- hydration cannot produce one observer-consistent category snapshot;
- migration cannot preserve existing financial history;
- archived-category behavior is ambiguous;
- delete-unused cannot be proven safe.

### Corrective policy

Category identity, assignment, migration or hydration defects become Sprint 57A.

---

## Sprint 58 — Reserved Evidence-Valid Outcome

### Status

**Reserved; not selected**

### Purpose

Preserve one roadmap slot for the strongest evidence-valid P1 or P2 outcome remaining after Sprint 57.

Selection must be made from the then-current `FUTURE_WORK.MD` against the exact pushed repository state.

No current candidate is authorized merely by occupying this slot. Numbers are not a substitute for evidence, despite project management’s occasional theological commitment to them.

### Candidate-selection requirements

Chat must:

1. verify the exact pushed baseline;
2. review candidates in P0, P1, P2, then P3 order;
3. classify every stronger candidate considered as:
   - implementation-ready;
   - ready for targeted discovery;
   - blocked by a named dependency;
   - completed or no longer applicable;
   - deferred with explicit reason;
4. compare the strongest plausible candidates;
5. explain why each serious non-selected candidate was rejected, split, blocked or deferred;
6. select only one coherent outcome;
7. require one bounded acceptance plan;
8. determine migration and ADR impact;
9. identify whether Work is justified;
10. avoid reusing stale assumptions from this roadmap.

### Possible candidates

Candidates may include, subject to then-current evidence:

- `FW-P1-40 — Deterministic Approved-Fixture Launcher`;
- `FW-P2-34 — Archive and Restore Account`;
- `FW-P2-52 — User and Workspace Preferences`;
- another higher-priority candidate newly promoted by repository evidence;
- a corrective sprint attached to Sprint 57, in which case Sprint 58 remains unchanged.

### Exclusions

- filler work selected merely because the slot exists;
- lower-priority work chosen only because it is easy;
- work blocked by an unresolved higher-priority financial defect;
- bundling unrelated candidates for throughput;
- implementation without a current Chat execution prompt.

---

## Sprint 59 — Cycle Completion or Final Bounded Outcome

### Status

**Reserved; not selected**

### Purpose

Either:

1. deliver one final evidence-valid bounded outcome; or
2. close the 50–59 cycle if no additional candidate can be safely selected.

Sprint 59 must not become ceremonial work performed to make the roadmap look symmetrical. Software has enough invented rituals already.

### Candidate-selection requirements

The same priority, evidence, combine/split and acceptance rules used for Sprint 58 apply.

### Acceptance alternative A — Final bounded sprint

Chat selects one current evidence-valid candidate and provides:

- repository baseline;
- documentation discrepancies;
- candidate triage;
- focused evidence;
- combine or split decision;
- selected outcome;
- exact included scope;
- exact exclusions;
- acceptance boundary;
- stop conditions;
- migration and ADR impact;
- reasons competing candidates were not selected;
- remaining evidence gaps;
- exact execution prompt where applicable.

### Acceptance alternative B — Explicit cycle close

Chat may close the cycle without implementation if:

- no remaining candidate is sufficiently ready;
- stronger candidates are blocked by named dependencies;
- a discovery campaign is more appropriate than forcing implementation;
- starting the 60–69 roadmap provides a cleaner planning boundary.

Cycle close must document why each serious remaining candidate is:

- completed;
- carried forward;
- blocked;
- deferred;
- replaced;
- or no longer applicable.

---

# Cycle close after Sprint 59

After Sprint 59 and any attached corrective sprint are accepted, or after Sprint 59 is explicitly closed without implementation, Chat must:

1. establish the exact pushed `main` baseline;
2. reconcile this file against:
   - `PROJECT_STATE.md`;
   - `FUTURE_WORK.MD`;
   - accepted ADRs;
   - production code and tests where documentation is insufficient;
3. classify every Sprint 50–59 outcome as:
   - complete;
   - replaced;
   - deferred;
   - carried forward;
4. record all inserted corrective sprints;
5. record all independent discovery campaign outcomes;
6. identify uncompleted forecast work without silently rewriting history;
7. create `LedgerForge Roadmap: Sprints 60–69`;
8. carry forward only evidence-valid unfinished outcomes;
9. preserve this file as the read-only private planning archive for the 50–59 cycle;
10. update the GitHub backup copy only after the private local roadmap is reconciled.

---

# Independent discovery campaigns

Independent discovery campaigns reduce future planning cost.

They are not sprints, do not select implementation and do not alter the numbered roadmap.

## DC-01 — Independent Backlog Readiness Campaign

### Status

**Available on user request; not automatically scheduled**

### Purpose

Have Work investigate as many currently eligible, implementation-independent `FUTURE_WORK.MD` candidates as possible in one continuous read-only pass so later sprint planning does not repeatedly pay the same discovery cost.

### Launch conditions

- Chat identifies an opportunity while Codex is working on an unrelated sprint or after a stable pushed baseline exists.
- The campaign is pinned to one exact immutable pushed commit.
- The active Codex sprint does not alter the architecture boundary of any included candidate.
- Work reads repository or GitHub evidence only unless a specifically approved local read-only boundary is required.
- Work does not inspect a half-edited active checkout.
- The campaign performs no edit, build, commit, branch, push, pull request or sprint selection.
- The campaign does not receive this roadmap file.

### Candidate selection rule

At launch, Chat recalculates the eligible set from the current canonical queue.

Include candidates marked Ready for discovery, Research or stale Blocked only when their named evidence boundary is independent of:

- the active Codex sprint;
- the next planned sprint;
- unresolved P0 architecture;
- private runtime state unavailable at the pinned ref;
- source material that cannot be safely inspected.

### Initial likely candidates

Subject to revalidation at launch:

- `FW-P1-40 — Deterministic Approved-Fixture Launcher`;
- `FW-P2-34 — Archive and Restore Account`;
- `FW-P2-52 — User and Workspace Preferences`, limited to ordinary regional and display preferences independent of reporting currency;
- other candidates proven independent by Chat at the launch baseline.

### Explicitly excluded during this cycle unless ownership changes

- completed `FW-P0-21` and `FW-P0-22`;
- `FW-P1-01` and `FW-P1-06`, owned by Sprints 53–54;
- `FW-P1-25` and overlapping `FW-P2-12` questions, owned by Sprints 55–56;
- `FW-P2-20`, owned by Sprint 57;
- any candidate depending on implementation not yet pushed;
- any candidate requiring active local runtime or private-source inspection that conflicts with Codex work;
- any candidate whose architecture is likely to be rewritten by the active sprint;
- any candidate already implementation-ready unless revalidation is specifically required.

### Required candidate-by-candidate output

For each candidate, Work must return:

- exact candidate ID;
- current canonical queue wording;
- inspected ref;
- verified current behavior;
- relevant production surfaces;
- relevant test surfaces;
- dependencies;
- architecture constraints;
- migration impact;
- ADR impact;
- independent-oracle requirement where financial truth is involved;
- missing decisions;
- falsification risks;
- one classification:
  - implementation-ready;
  - ready for Chat planning;
  - discovery complete with one named decision remaining;
  - blocked by a named dependency;
  - completed or no longer applicable;
  - insufficient evidence.

Work must not:

- choose future sprints;
- renumber roadmap items;
- edit repository documents;
- implement code;
- expose private source material;
- infer unsupported financial truth.

### Revalidation rule

A campaign conclusion is planning input only.

Before future selection, Chat revalidates every material conclusion against the then-current `main`, because a discovery report pinned months earlier is evidence, not prophecy.

## Further campaigns

Repeat the same pattern as `DC-02`, `DC-03`, and so on when the user identifies another safe opportunity.

Do not create campaigns merely to keep Work occupied.

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
- the user changes product priority after higher-priority safety work is resolved;
- a newly supported parser or profile is shown to accept unproven layouts;
- trusted hydration loses source date, order, identity or provenance;
- local Git state contains ambiguous unique work that blocks safe execution.

Reordering rules:

1. insert a corrective `A/B` sprint when tied to the preceding sprint;
2. insert a standalone integrity sprint for an unrelated verified P0 defect;
3. retain original later sprint numbers;
4. mark displaced work **Deferred** or **Replaced** rather than rewriting completed history;
5. update the overview, affected sprint cards and append-only log;
6. never treat a forecast or reserved row as authorization;
7. do not skip a blocked higher-priority candidate without naming the blocker;
8. prefer bounded discovery over pretending a candidate is not there.

---

# Financial-truth rules for this roadmap

For any sprint involving imported financial evidence:

- source semantics outrank derived fixtures and expected JSON;
- production parser output must not be the sole oracle;
- preserve native currency;
- preserve decimal scale;
- preserve debit and credit direction;
- preserve source date meaning;
- preserve source order;
- preserve opening, closing and running balances;
- preserve source-supported identifiers;
- preserve parser-profile identity and version;
- preserve document and row provenance;
- fail closed on malformed, ambiguous, conflicting or unsupported evidence;
- verify zero accepted durable residue on rejection;
- require SQLite/In-Memory parity where both matter;
- verify persistence, hydration, provider reconstruction, relaunch and presentation;
- never infer institution, format or layout support from structural similarity;
- never invent historical provenance, ordering, identifiers or repair data;
- keep sanitized fixtures in Git;
- keep private originals only in isolated, read-only local verification;
- distinguish:
  - source truth;
  - implementation behavior;
  - test evidence;
  - inference.

A verified financial defect blocks feature planning until repaired or explicitly accepted by the user.

---

# Tool and mode routing

## Chat

Chat owns:

- sprint planning;
- prioritization;
- architecture decisions;
- execution prompts;
- review of Work and Codex reports;
- final acceptance decisions;
- roadmap reconciliation.

Sprint planning does not authorize implementation.

## Work

Use Work only for bounded, read-only investigation GitHub cannot establish efficiently, including:

- local or unpushed state;
- worktrees;
- filesystem or Xcode configuration;
- build, test or runtime evidence;
- broad cross-file tracing;
- private read-only source verification;
- a specific unresolved architecture boundary.

Before escalating, Chat states:

1. the exact unknown;
2. why it affects the decision;
3. the bounded evidence Work must return.

Work returns evidence and risks.

Work does not:

- select sprints;
- edit files;
- implement;
- create branches;
- commit;
- push;
- open pull requests.

## Codex

Codex edits files, builds, tests and performs Git operations only from an approved Chat execution prompt.

Before Codex execution, verify:

- current branch and `HEAD`;
- `main`, `origin/main` and divergence;
- staged files;
- unstaged files;
- untracked files;
- linked worktrees;
- local branches;
- remote branches;
- stashes.

Never delete, reset, drop, prune or overwrite unique or unexplained work.

Default workflow is one `main` branch.

Do not create a branch unless:

- the user explicitly approves it;
- a repository-specific reason is stated;
- the approved prompt requires it.

## GitHub

Use GitHub for:

- pushed files;
- refs;
- commits;
- issues;
- pull requests;
- CI;
- read-only code evidence.

Always identify the inspected ref or commit.

Do not infer local state from GitHub.

## Build macOS Apps

Use only when macOS-specific expertise materially matters, such as:

- SwiftUI;
- AppKit;
- Xcode;
- SwiftPM;
- runtime logging;
- macOS test triage;
- signing;
- packaging.

Keep it subordinate to accepted ADRs and mode boundaries.

## Google Drive

Use only for explicitly relevant supporting material outside GitHub.

Repository documents remain authoritative.

## Figma

Use for approved visual evidence and design-to-code comparison.

Do not infer:

- business logic;
- persistence;
- financial semantics;
- support boundaries

from visuals.

## Browser

Use for current official documentation and external references unavailable through connected sources.

## Computer Use

Use only when a local Mac application must be inspected and no direct connector can establish the evidence.

Planning and discovery are read-only by default.

Never make destructive changes without explicit authorization.

---

# File handling and visibility

- Maintain the working copy as a private Chat-user planning file.
- The GitHub copy is backup only.
- Do not treat the GitHub copy as repository authority.
- Do not provide this file to Work or Codex.
- Do not quote this file inside Work or Codex prompts.
- Work and Codex receive only the bounded current task prompt.
- At the start of a new Chat planning conversation, attach the latest copy when continuity is required.
- Chat reads the active state and relevant sprint card, then verifies everything against current repository evidence.
- Repository evidence overrides this roadmap.
- Keep a normal user-controlled local backup.
- Update the backup copy only after Chat reconciliation.
- Never treat the presence of this file in GitHub as authorization to use its forecasts during implementation.

Suggested local working location:

```text
~/Documents/LedgerForge Planning/LedgerForge_Roadmap_Sprints_50-59.md
```

---

# Append-only planning and decision log

Do not rewrite or delete prior entries.

Add corrections as new dated entries.

The concise sections above may be updated to reflect the current plan. This log preserves how and why the plan changed.

## 2026-07-22 — Roadmap visibility problem identified

### User, verbatim

> Brainstorm and come up with cons and pros and then based on that a final recommendation for or against making a sprint roadmap file for only Chat and me as a way to have sprints lined up and plan better as I do not have any visibility of what to expect in coming sprints.

### Decision

Create a private roadmap and continuity record.

Repository authorities remain controlling and the file remains non-executable.

The later decision to keep a GitHub copy is treated as backup storage only. It does not change the roadmap’s authority or visibility rules.

---

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

Adopt:

- ten fixed sprint numbers per cycle;
- corrective `A/B` suffixes without renumbering later sprints;
- strict Chat-user planning ownership;
- no roadmap access for Work or Codex;
- separate non-sprint discovery campaigns.

---

## 2026-07-22 — Initial file requested

### User, verbatim

> Ok, draft structure attached. 
> Include sprint 50-60. Although first 2 are done already, it ll give us a baseline structure .
>
> Give me the complete final file with all sprints done till 60

---

## 2026-07-22 — Cycle corrected

### User, verbatim

> correction to above, sprint 50-59.

### Decision

The first roadmap cycle is Sprints 50–59.

The next cycle is Sprints 60–69.

---

## 2026-07-23 — Repository reconciliation invalidated the original Sprint 53–54 forecast

### Repository basis

- Inspected ref: `main@d63c54f7a8117b36ff4849c0ad9453abb3fc9a80`
- Authoritative documents:
  - `Project documents/PROJECT_STATE.md`
  - `Project documents/FUTURE_WORK.MD`
  - `Project documents/ADR.md`
- Repository implementation and tests were treated as controlling where documentation was stale or incomplete.

### Verified outcome

Repository evidence established that:

- Sprint 52 completed the trusted statement-date and durable source-provenance architecture and implementation;
- ADR-039 was accepted;
- Migration V6 was implemented;
- Sprint 52A completed the remaining trusted hydration, parser-profile provenance and writer-authority correction;
- trusted production import was restored for the approved Axis NRE CSV profile;
- the original roadmap’s forecasted Sprint 53 architecture and Sprint 54 implementation had already been overtaken by completed repository history.

### Decision effect

- Sprint 52 is recorded as complete.
- Sprint 52A is recorded as complete.
- The original Sprint 53 and Sprint 54 forecast entries are replaced.
- Sprint 53 becomes Axis NRO and Import Profile readiness discovery.
- Sprint 54 becomes the conditional implementation of the exact Sprint 53 result.
- Partial-overlap discovery and implementation become Sprints 55 and 56.
- Categories become Sprint 57.
- Sprints 58 and 59 remain reserved for later evidence-based selection.
- No implementation is authorized by this reconciliation.

---

## 2026-07-23 — GitHub roadmap copy classified as backup only

### User, verbatim

> Ignore the repository <> roadmap sprint 50-59.md thing. It's backed up in GitHub but wont be used by codex/work.

### Decision

The roadmap may remain backed up in GitHub, but:

- it has no repository authority;
- it is not part of repository-state reasoning;
- Work and Codex must not receive or use it;
- only a current bounded Chat prompt authorizes Work or Codex;
- the local or user-maintained copy remains the working planning record.

---

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
