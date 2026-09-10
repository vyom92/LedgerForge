# LedgerForge Future Work

## Process authority

Execution, recovery, Git/worktree safety, evidence handling and material-finding intake are governed by `AGENTS.md`, `Project_Guide.md` and `LedgerForge_Standing_Execution_Harness_Guide.md`.

`FUTURE_WORK.MD` owns the canonical unscheduled queue. It does not duplicate executor mechanics and it does not authorize implementation.

## Purpose

This document is the canonical planning queue for LedgerForge work that is not yet authorized for execution.

It records:

- product feature candidates;
- architectural follow-up work;
- verified bugs;
- maintenance work;
- technical debt;
- engineering-quality improvements;
- product ideas;
- research topics.

It exists so future work is selected from a recorded, evidence-based queue rather than reconstructed from conversations or inferred from incomplete project history.

Completed and verified work belongs in:

`Project documents/PROJECT_STATE.md`

Architectural decisions belong in:

`Project documents/ADR.md`

Execution is authorized only by the complete Chat-approved prompt supplied directly in the current conversation. Reports are returned directly in chat; verified durable facts belong in their subject authorities and Git history.

Items selected for execution must be removed from this document or narrowed to the portion that remains unscheduled.

---

## Authority

This document is a planning queue, not an implementation contract.

An item appearing here means only that the work has been recorded for future consideration.

It does not mean that the item:

- is approved for implementation;
- has been assigned a sprint number;
- will be selected next;
- has completed repository discovery;
- has an approved architecture;
- can be implemented independently of its dependencies.

No future sprint number may be assigned in this document.

A work item becomes executable only when Chat supplies one complete approved prompt to the explicitly authorized execution surface for that task.

---

## Discovery reconciled into existing subject authorities — 2026-09-10

Both read-only discovery rounds are incorporated here, in the existing [current roadmap](<Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md>), [prepared roadmap](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>) and [R1 design handoff](<UI Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md>). The redundant standalone register is retired. First-round research used `adcf83f52d309ddac18d95f0321d0c0f6120dd29`, reconciled at `ffddebc6e12405c812a36855ab6212e973cff5ba` and published at `af2d1949c6e9a73af3bb004422b72882d28195e2`. Second-round research is pinned to `af2d1949c6e9a73af3bb004422b72882d28195e2`; latest production acceptance remains owned by PROJECT_STATE and the current roadmap.

First-round coverage was 153 baseline entries: 151 then-active entries and two separately completed Sprint-83 entries (FW-P1-20/21). Sprint-84 closure subsequently retires FW-P2-73 independently. This campaign preserves every current queue ID, title, status and priority; a discovery closure is a separate research classification, never a status promotion. The second round targets 145 cards; active Sprint-84–87 ownership, dashboard customization and accepted corpus maintenance were excluded as recorded by their first-round dispositions.

All packet recommendations, proposed ADR contexts, personal-v1 classifications and roadmap changes below await Chat review. No architecture is accepted, ADR number allocated, sprint selected, source support certified, or product behavior implemented here. No executable validation was performed by this campaign. Repository citations are immutable research facts; an existing test is a definition or previously accepted result, never newly executed evidence. Statement-dependent acceptance must use complete registered authentic sources and independent semantic projection under ADR-046; absent genuine cases stay uncertified.

The typed dependency lists in each card are the durable graph: a card requires its target; OPTIONAL_ENHANCEMENT is not a blocking edge. The graph was checked as acyclic. An accepted authority is not a missing implementation; backup is a prerequisite of adopted personal-v1 certification, not its dependent; toolbar runtime checks do not depend cyclically on global shortcut closure. Current holdings need not wait for ingestion, external prices or performance. Historical FX and optional complete export do not block the selected current estimates or required backup. Technical decisions belong to Chat; the 19 current user product choices each have bounded options in their owning cards.

The final publication delta checked 519 combined citations, 357 unique dependencies and 44 referenced paths against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`: 91 STILL_VALID, 19 REVALIDATED_AFTER_CHANGE, 35 WAIT_POST_SWIFT6, and zero unresolved stale targets. Source citations retain their original research ref and lines; the per-card delta below records the latest comparison.

## Explicit user-decision chronology

**Current scope:** current holdings first; verified backup/restore required and complete structured export optional; appearance travels with workspace move/restore; reviewable rule suggestions preserve manual categories and expose every disagreeing match; current Al Dar Salary/budget INR receive estimates allow a manual override; current market net-worth estimates use direct INR→USD and QAR→USD observations. Historical conversions and the 2021 floor are superseded. Reporting output currencies/orientation and provider suitability remain Chat decisions.

| Decision | Exact user direction | Disposition |
| --- | --- | --- |
| UD-01 | Propose current holdings first; keep history and performance gated | CURRENT, subject to latest UD-09/10 scope |
| UD-02 | Require backup/restore; keep complete export optional | CURRENT, subject to latest UD-09/10 scope |
| UD-03 | Include appearance preferences when moving/restoring a workspace | CURRENT, subject to latest UD-09/10 scope |
| UD-04 | Require current and historical conversion together | SUPERSEDED by UD-10; chronological evidence only |
| UD-05 | 1 January 2021 onward is sufficient | SUPERSEDED by UD-10; chronological evidence only |
| UD-06 | Use reviewable suggestions first (Recommended) | CURRENT, subject to latest UD-09/10 scope |
| UD-07 | Just to clarify https://www.aldarexchange.com/aldarportal/Home is the source of any qar to inr conversion as that gives actual transfer rate. only for inr to usd or qar to usd you can use market sources | NARROWED by UD-09/10; chronological scope only |
| UD-08 | Use a direct market INR→USD rate | CURRENT, subject to latest UD-09/10 scope |
| UD-09 | i do not need qar to inr historical. its sole purpose is to estimate how much i will get in inr end of the month based on the monthly salary/budget calculator. if needed i can manually override my own fx rate on live/current rate | CURRENT, subject to latest UD-09/10 scope |
| UD-10 | same with inr to usd. i just need current estimation of net worth in different currencies. not a basket of historical conversions | CURRENT, subject to latest UD-09/10 scope |

## Second-round closure inventory

| Research classification | Cards |
| --- | ---: |
| `DECISION_CLOSED_BY_EXISTING_AUTHORITY` | 1 |
| `DECISION_CLOSED_BY_NEW_EVIDENCE` | 0 |
| `DECISION_CLOSED_BY_EXPLICIT_USER_DECISION` | 2 |
| `READY_FOR_CHAT_ARCHITECTURE_DECISION` | 22 |
| `READY_FOR_IMPLEMENTATION_PLANNING` | 2 |
| `READY_AFTER_NAMED_DEPENDENCY` | 53 |
| `BLOCKED_ON_AUTHENTIC_SOURCE` | 17 |
| `BLOCKED_ON_PRIVATE_EVIDENCE_NOT_AVAILABLE` | 1 |
| `BLOCKED_ON_EXTERNAL_PROVIDER_OR_PERMISSION` | 2 |
| `BLOCKED_ON_PRODUCT_DECISION` | 19 |
| `WAIT_POST_SWIFT6` | 1 |
| `WAIT_FOR_RUNTIME_ACCEPTANCE` | 6 |
| `DEFERRED_WITH_REASON` | 19 |
| `REJECTED_WITH_REASON` | 0 |

Total: **145** targets. A whole-card closure can remain blocked after one factual prerequisite closes. The graph contains 301 nodes and 296 typed edges, with no blocking cycles. 35 targets retain a required post-Sprint-87 refresh; source/provider facts do not become stale solely because Swift ownership changes.

## Full Candidate Verification Audit

**Audit date:** 2026-09-09
**Original audit baseline:** `main@a560312db5900645779a499016e13f0c87e81435`
**Sprint-81 queue-closure update:** 2026-09-10 at `main@13552eaf8d22a8e6fcb56fb9a9d7a9dd0892bf91`
**Sprint-82 queue-closure update:** 2026-09-10 at `main@d239f939088b67e5a90c65117f08592891be17bb`
**Sprint-83 queue-closure update:** 2026-09-10 at `main@ffddebc6e12405c812a36855ab6212e973cff5ba` (accepted implementation `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; implementation parent `057d70b6f39929735401d5211cd180db162c94cc`)
**Sprint-84 queue-closure update:** 2026-09-10 at accepted implementation `a4dd6929a2282cc94c850eb1dccf350b1ee5c8a1`
**Active queue count after Sprint-84 acceptance closure:** 150
**Current migration:** V17
**Current source/reliability architecture:** ADR-046 complete-authentic-corpus authority
**Current design authority:** `LF-UI-2026-09-R1` for its bounded scope
**Latest accepted numbered implementation:** Sprint 84 — PR-2 SQLite / Provider / Migration Ownership
**Latest accepted numbered discovery:** Sprint 80 — `SWIFT6_READINESS_COMPLETE`
**Personal-v1:** UNDECLARED / NOT CERTIFIED

The Sprint-83 closure mechanically re-enumerated every active `FW-*` heading: 151 candidates, 151 unique IDs, no duplicate IDs and no malformed candidate headings. The original audit reconciled candidates against `PROJECT_STATE.md`, the current 80–89 roadmap, the Standing Harness, relevant accepted ADRs, Product Vision, R1 design authority and current repository evidence where documentation was insufficient.

Reconciliation outcomes:

- `FW-P2-72` is removed from the active queue because Sprint 81 completed and Chat accepted the PR-1 staging/runtime-publication ownership seam at implementation commit `13552eaf8d22a8e6fcb56fb9a9d7a9dd0892bf91`.
- `FW-P1-19` is removed from the active queue because Sprint 82 completed and Chat accepted the serial Unified Import Centre foundation at implementation commit `d239f939088b67e5a90c65117f08592891be17bb`. Its serial coordinator, per-item identity/state ownership, cancelled-task draining, explicit confirmation, shared production ownership, duplicate/recovery preservation and no-parallel-preparation evidence are recorded in `PROJECT_STATE.md` and the current roadmap.
- `FW-P1-20` and `FW-P1-21` are removed from the active queue because Sprint 83 completed and Chat accepted serial batch import and multi-file picker/drag-and-drop at implementation commit `adcf83f52d309ddac18d95f0321d0c0f6120dd29`. Single and multi-file intake share the serial queue with independent review, explicit confirmation, failure isolation and truthful per-file outcomes. Parallel preparation remains unscheduled research under the existing `FW-P2-51`.
- `FW-P2-73` is removed from the active queue because Sprint 84 completed and Chat accepted PR-2 SQLite/provider/migration ownership at implementation commit `a4dd6929a2282cc94c850eb1dccf350b1ee5c8a1`. The bounded ownership, strict closure and V1–V17 preservation evidence belongs in `PROJECT_STATE.md`. The remaining PR-3 boundary is now Chat-authorized; the current roadmap owns its position and the amended Sprint-85–87 validation policy.
- `FW-P0-25` is removed from the active queue because the unnumbered 127-carrier authentic-corpus reset is technically accepted and complete; newly supplied recurring sources remain governed cumulatively by ADR-046.
- Compound historical statuses are normalized to the defined planning vocabulary. Completed slices remain concise body notes while titles and statuses describe only remaining unscheduled work.
- Exact source-family support remains exact. HDFC whole-statement PDF/XLS equivalence, Axis-card PDF/XLSX equivalence and CBQ current-account source lineage are separate accepted contracts; none is generalized to another institution, financial family or format.
- The accepted reset establishes engineering format-neutral semantic parity for the registered Axis-bank carriers. It does not establish a durable Axis-bank cross-format duplicate/equivalence or supporting-source suppression contract.
- The accepted 127-carrier campaign supplies the current engineering authentic-corpus regression matrix. `FW-P2-61` therefore retains only matrix maintenance/user-facing durability work rather than claiming that the matrix is absent.
- R1 design approval is settled, while native Transactions, Dashboard, appearance and cross-screen conformance remain implementation work.
- `FW-P0-26`, `FW-P2-78` and `FW-P2-79` were mechanically proven unused before being added.

The former 2026-08-01 audit is historical context only. Its Sprint-65-era counts, fixture assumptions and support snapshots are not current planning authority.

### Current statement-dependent acceptance rule

For statement-dependent financial behavior, the complete registered authentic corpus is authority. No synthetic, generated, sanitized, reconstructed, representative, reduced, mutated or hand-authored financial statement may be used at any stage. Production parser output is never its own sole oracle. Private gates fail closed when required evidence is unavailable. A material source/parser/persistence/financial-semantic correction invalidates prior green evidence for the affected candidate boundary, which must be frozen and retested. Exact support never generalizes by institution name, file format, transaction count, page count or layout similarity.

### Roadmap relationship

`FUTURE_WORK.MD` remains the canonical queue. The current and prepared roadmaps may assign non-executable planning positions to recorded queue IDs, but roadmap placement does not remove the candidate, authorize implementation or override P0 → P1 → P2 → P3 triage. A candidate leaves this queue only when a Chat-approved execution selection consumes it or when accepted evidence proves its active boundary fully complete.

---

## Planning Principles

Future work is ordered by:

1. priority;
2. dependency readiness;
3. architectural safety;
4. product value;
5. scope coherence.

Priority and readiness are separate.

A high-priority candidate may remain blocked by unfinished dependencies, missing authentic source evidence, unresolved architecture or insufficient repository evidence.

Several related candidates may be combined into one sprint when repository discovery shows that they:

- produce one coherent user or architectural outcome;
- share the same architectural boundary;
- depend on each other to be useful or safe;
- can be validated through one bounded acceptance plan.

Candidates should remain separate when combining them would:

- cross unrelated product outcomes;
- mix unrelated persistence, parser, UI and domain changes;
- require multiple unresolved architecture decisions;
- make implementation or validation unreasonably broad;
- prevent the result from being accepted independently.

The unit of sprint planning is one coherent outcome, not one backlog bullet.

---

## Priority Definitions

### P0 — Integrity and Safety

Work required to protect financial correctness, durable identity, privacy, persistence integrity or recoverability.

### P1 — Core Product Capability

Major work that expands supported accounts, institutions, formats, import workflows or essential product operations.

### P2 — Workflow and Experience

Important transaction, account, developer, usability and engineering-quality improvements.

### P3 — Later Product Expansion

Analytics, investments, multi-currency and ecosystem capabilities that depend on a mature core platform.

---

## Status Definitions

### Ready for discovery

Dependencies appear satisfied and the candidate may be considered during planning. Targeted Work discovery is used when current repository evidence is insufficient, stale or unable to establish a safe implementation boundary.

### Candidate

Recorded and potentially valuable, but not necessarily the next planning target.

### Blocked

A named dependency, architecture decision, authentic source-evidence boundary or preceding capability is missing.

### Ready for planning

The named dependencies and architecture are accepted, and the candidate may be prepared for a future implementation prompt after any explicit break or sequencing boundary. This status does not authorize implementation or assign a sprint.

### Bug

Verified behaviour that is incorrect and should be corrected.

### Maintenance

Bounded engineering or developer-workflow upkeep.

### Research

The problem is recorded, but architecture or product direction is not yet approved.

### Idea

A possible future direction without planning commitment.

---

## Sprint Selection Procedure

After a completed increment is verified and accepted:

1. Read `PROJECT_STATE.md` and establish the verified repository baseline.

2. Review this document from the highest priority downward.

3. Exclude candidates whose dependencies remain unsatisfied.

4. Identify the highest-priority dependency-ready problems.

5. Determine whether related candidates may form one coherent sprint outcome.

6. When repository evidence is insufficient or the candidate’s implementation boundary is uncertain, send Work a read-only evidence-discovery task.

7. Work records:

   - verified current behaviour;
   - relevant production and test surfaces;
   - architectural constraints;
   - missing decisions;
   - risks;
   - whether candidates should combine or split.

8. Chat reviews the discovery report and relevant architecture evidence.

9. Chat selects one bounded sprint outcome.

10. Create or update an ADR when the selected work requires a new architectural decision.

11. Chat supplies one complete execution prompt to the explicitly authorized execution surface for that task.

12. Remove promoted work from this document.

No candidate is selected merely because it appears first. Dependencies, evidence, risk and user value remain controlling factors.

---

## Upcoming-Work Reporting Rule

When reporting future work:

- identify the latest verified state from `PROJECT_STATE.md`;
- describe future work only using candidates recorded here;
- distinguish Ready for discovery, Candidate, Blocked, Ready for planning, Bug, Maintenance, Research and Idea;
- do not assign sprint numbers inside this queue; planning positions belong only to the applicable roadmap and remain non-executable;
- do not describe a candidate as approved implementation;
- clearly label any new suggestion that has not yet been added to this document.

A valid statement is:

> Candidate `<ID>` is recorded as `<Status>` with the dependencies listed in this document.

An invalid statement is:

> The next sprint will implement `<candidate>`.

A roadmap may forecast a sprint planning position, but the second statement becomes executable only after Chat reruns priority/dependency triage and supplies a complete execution prompt.

---

# P0 — Financial Integrity and Persistence Safety

<a id="fw-p0-02"></a>

## FW-P0-02 — Historical Duplicate Review and Repair

**Status:** Ready for discovery
**Shared prerequisites:** Sprint 40 overlap evidence, Sprint 41 bounded transaction-event ownership, ADR-037 acceptance and post-Sprint-45 lifecycle revalidation are complete.
**Implementation dependency:** Selection and approval of one concrete historical duplicate-repair family contract.

Provide safe review and correction for duplicate transactions already present in durable history.

Targeted discovery may now define one bounded repair family, including:

- independently provable duplicate evidence;
- duplicate-candidate review;
- explanation of matching evidence;
- import-session and source provenance;
- exact native-currency financial-impact preview;
- explicit user confirmation;
- one provider-owned atomic mutation;
- privacy-safe audit evidence;
- family-specific reversal, compensation or explicit irreversibility.

Historical data must never be silently changed. Discovery does not authorize implementation or broad historical cleanup.

**May combine with:** `FW-P1-25` and `FW-P2-12` only if discovery proves that prospective duplicate review and one historical repair family share a single bounded review and acceptance boundary.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRIVATE_EVIDENCE_NOT_AVAILABLE`. **Exact remaining gate:** No supplied affected historical database and no independently provable historical duplicate relation; accepted corpus evidence does not identify historical durable residue.

**Smallest proposed boundary:** Read-only historical duplicate verifier only after a supplied snapshot.

**Decision record:** [CHAT_DECISION_PACKET](#packet-chat-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: exact fingerprint and supported event duplicate outcomes reject the incoming import and retain a bounded attempt; no historical repair API exists.

**First-round scope and constraints:** ADR-037 requires read-only review, exact native-currency impact, confirmation, provider-owned atomic write/audit and family reversal or declared irreversibility. No fuzzy matching, silent edits, bulk cleanup, synthetic-source proof or backup-as-undo.

**First-round question/options:** Choose one historical duplicate repair family without altering history by inference. PROPOSED: select one independently source-provable duplicate relation; defer broad cleanup. A generic candidate scan cannot itself authorize repair.

**First-round remainder and implications:** MISSING: an affected family/database and independent duplicate oracle; static absence is not a reproduced defect. ADR-037 applies; migration unknown and not allocated.

**First-round proposed acceptance/falsifier:** Falsify with ambiguous evidence, stale plan, differing provider result, or any accepted residue on rejected review; prove independent source impact and post-hydration/relaunch. A source-proven family whose records are not representable by the reviewed contract.

**Second-round new evidence/resolved direction:** No new historical duplicate relation; accepted source analysis found only already-governed whole-statement relationships.

**Exact next evidence or decision:** Affected snapshot plus source-side duplicate oracle.

**Personal-v1:** PRE_V1_OPTIONAL: repair only if an affected adoption database exists.

**Recommendation after Chat:** Ready for discovery **Roadmap:** No change

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Any supplied snapshot or source-proven exact duplicate.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, MUTATION_SEMANTICS, REVERSIBILITY, DURABLE_PERSISTENCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `accepted-adr-037`: repair requires family execution lifecycle
- `REQUIRES_AUTHENTIC_SOURCE` → `source-affected-historical-snapshot`: no invented history

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):254-276 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P0-02
- [Services/ImportPersistenceCoordinator.swift](<../Services/ImportPersistenceCoordinator.swift>):1857-1863 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `052b8de5c2de61349a5151d676e1dade3ec005363fb82f4eed290822bea2cfae` — exactDuplicate
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):1012-1036 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — historical repair is separately governed and no fingerprint backfill is inferred

</details>

---

<a id="fw-p0-08"></a>

## FW-P0-08 — Data-Integrity Verification and Repair

**Status:** Ready for discovery
**Shared prerequisites:** ADR-037 acceptance and post-Sprint-45 lifecycle revalidation are complete.
**Implementation dependency:** Selection and approval of one concrete verification or repair family.

Provide privacy-safe verification for:

- broken account relationships;
- missing import sessions;
- orphaned documents or fingerprints;
- identifier conflicts;
- duplicated transactions;
- incomplete imports;
- inconsistent completion states.

The Axis direction-audit family has no retained affected historical database currently identified. No detection or repair run is presently authorized. If a concrete affected database is supplied, the subfamily must first perform read-only detection against durable parser provenance and independently provable source arithmetic; any repair then requires exact impact preview, explicit authorization, provider-owned atomic mutation and recoverability or explicit irreversibility. The Sprint 55A source-truth restoration performed no historical mutation.

Targeted discovery must select one independently verifiable family and define whether the first increment is read-only verification or an explicit repair. Repair actions must be previewed, authorized, atomic and recoverable or explicitly irreversible.

This candidate is not implementation-ready as one broad “repair everything” operation.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Chat must approve the source-independent read-only import-graph verifier contract; no affected database is supplied for execution.

**Smallest proposed boundary:** Read-only complete accepted-import graph verifier with privacy-safe counts and fail-closed unreadable input.

## Authentic relationship acquisition

The accepted Sprint-83 manifest's explicitly referenced `xctestrun` supplied the approved private test configuration. This was a bounded inspection of accepted evidence, not a search of home directories or a new validation. The resolved original/oracle files were read only.

| Family / opaque evidence | Independent source fact | Decision consequence |
|---|---|---|
| Axis-bank oracle | 3 logical statements, each represented by 3 distinct-byte CSV/PDF/XLS carriers; 2 opaque account identities | This is representation evidence, not automatic durable equivalence. |
| Axis-bank cross-account candidates | 2 opposite-direction, same-date, exact-absolute-amount shapes; zero share a nonempty UPI-reference digest and zero share a nonempty narration-reference digest; the oracle supplies no currency field | Neither candidate is a transfer, event duplicate, or same-currency proof. Treat as ambiguous. |
| HDFC oracle | 4 PDF/XLS pairs have zero financial-or-reference mismatches; every pair has literal narration differences | Reconfirms the already accepted ADR-042 family only. |
| Axis-bank three-format groups | all 3 groups have three distinct source bytes; zero match under the tested exact financial/reference projection | No new Axis-bank durable cross-format equivalence candidate is established. |
| Axis-card oracle | 32 carriers / 18 logical statements | No new relationship authority beyond existing accepted bounded card contracts. |

The sources support a negative result with high confidence: date-and-amount coincidence across two opaque owned accounts is insufficient. They do not supply an independently provable first transfer family, a same-format byte-different duplicate, a new cross-format equivalence pair, an extra transaction-event family, a historical duplicate, or a historical affected database.

**Decision record:** [CHAT_DECISION_PACKET](#packet-chat-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: provider rejects malformed/identity/event conflicts; repository protocol contains no cross-domain repair transaction.

**First-round scope and constraints:** The Axis direction audit has no identified affected database; read-only detection must use provenance and independent source arithmetic before a repair is considered. No affected-DB mutation, scan of live DB, broad repair or invented historical oracle.

**First-round question/options:** Select a safe first integrity verification/repair family. PROPOSED: begin with a read-only verifier for one invariant (for example complete import graph), rather than repair-everything.

**First-round remainder and implications:** MISSING: concrete affected database/family and a consistent approved snapshot. ADR-037; no migration decision.

**First-round proposed acceptance/falsifier:** Known malformed graph must be detected; valid graph passes; unreadable/missing evidence fails closed; verifier produces no state change. A supplied database proves the chosen invariant cannot be evaluated from durable data/provenance.

**Second-round new evidence/resolved direction:** Confirmed import retains provenance relationships, while project state forbids broad repair; verifier can be specified without statement-shaped test data.

**Exact next evidence or decision:** Accepted graph/provenance invariants; snapshot only for later use.

**Personal-v1:** PRE_V1_OPTIONAL: a verifier improves adoption evidence but is not certification.

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY after Chat accepts architecture: exact post-Sprint-87 ownership delta, any authentic acceptance source and explicit execution prompt still required. **Roadmap:** No sprint selection

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** provider graph or hydration contract changes.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** DURABLE_PERSISTENCE, PROVENANCE, MUTATION_SEMANTICS, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `accepted-adr-037`: any later repair remains family-owned
- `REQUIRES_POST_SWIFT6` → `FW-P2-74`: provider/migration ownership may change
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p0-08`: Chat must approve the source-independent read-only import-graph verifier contract; no affected database is supplied for execution.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):280-300 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P0-08
- [Database/Repository.swift](<../Database/Repository.swift>):279-288 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — ConfirmedImportRepository
- [Database/Migrations.swift](<../Database/Migrations.swift>):93-225 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — durable graph has explicit relationships

</details>

<a id="packet-chat-decision-packet"></a>

<details>
<summary>CHAT_DECISION_PACKET — complete proposed decision packet</summary>

## CHAT_DECISION_PACKET — `FW-P0-08` verifier before any ADR-037 mutation

1. **Owning FW IDs:** `FW-P0-08`; informs `FW-P0-02`, `FW-P0-16`, `FW-P1-25`, and `FW-P1-27` without merging them.
2. **User problem:** Detect a broken accepted-import relationship graph without silently changing financial history.
3. **Verified current state:** Import/session/document/transaction/identifier/provenance relationships are durable; no cross-domain repair executor exists.
4. **Accepted authorities:** ADR-037; ADR-038; current `PROJECT_STATE`; authentic-input rules.
5. **Exact missing decision:** Chat must accept or reject a source-independent, read-only accepted-import graph verifier as the first integrity increment.
6. **Evidence acquired:** Migration relationships, accepted mutation limits, and retained accepted corpus evidence were inspected; no affected database was supplied.
7. **Options considered:** (A) broad repair; (B) historical duplicate repair; (C) import reversal; (D) read-only graph verifier.
8. **Recommended option:** D: a read-only verifier first.
9. **Why competing options are rejected:** A is undefined; B lacks an affected snapshot/oracle; C lacks an inverse family; none may infer historic financial truth.
10. **Smallest coherent implementation boundary:** Accept a supplied database snapshot read-only and report typed invariant failures, privacy-safe counts, relationship-class counts, and a snapshot digest.
11. **Included scope:** Referential closure, workspace/account ownership closure, import-session/document linkage, identifier-observation linkage, source-row/transaction provenance linkage, and completion-state coherence.
12. **Explicit exclusions:** No repair, no deletion, no account choice, no historical backfill, no parser output as oracle, no live database scan, and no financial statement fixture.
13. **Durable model/persistence requirements:** Read-only repository query surface or readonly snapshot reader; versioned invariant catalogue/digest; no table or financial-row change.
14. **Migration impact:** `NONE` for the verifier.
15. **ADR impact:** `ALIGN_EXISTING` with ADR-037; no new mutation architecture is created.
16. **Privacy/security boundary:** Report only opaque snapshot/invariant identifiers and counts; never display source paths, record IDs, identifiers, narration, or Money.
17. **SQLite/In-Memory implications:** SQLite readonly snapshot is the real execution target; isolated source-independent graph mechanics may establish In-Memory parity only if implementation later exposes the same read model.
18. **Hydration/relaunch implications:** The verifier publishes no runtime state and never hydrates; later repair acceptance must separately prove canonical hydration/relaunch.
19. **Independent acceptance oracle:** An independently authored, nonfinancial malformed relationship graph for isolated mechanics plus a supplied real snapshot's relational invariants; no statement-shaped fixtures.
20. **Failure cases:** Unreadable/unknown schema, missing provenance, inconsistent ownership, dangling relation, conflicting completion state, stale snapshot, or unavailable source fails closed and writes nothing.
21. **Reversal/correction semantics:** None: the operation is read-only. Its output is not authorization for a repair.
22. **Source evidence requirement:** No statement source for graph-only checks; any financial-impact conclusion or repair requires authentic source and independent oracle.
23. **Runtime acceptance requirement:** Later, only after post-Swift-6 provider ownership settles: readonly SQLite execution, no changes before/after, and no hydration side effect.
24. **Dependencies:** Chat approval; post-87 delta review of provider/migration ownership; a user-supplied snapshot only for real execution.
25. **Evidence that falsifies the recommendation:** A required invariant cannot be evaluated from durable records/provenance; provider read behavior differs; or the report requires private financial values to be useful.
26. **Personal-v1 relevance:** `PRE_V1_OPTIONAL`; useful adoption evidence, never certification on its own.
27. **Recommended FUTURE_WORK status after Chat review:** `READY_FOR_CHAT_ARCHITECTURE_DECISION` now. After Chat accepts the read-only verifier, `READY_AFTER_NAMED_DEPENDENCY` until exact post-Sprint-87 ownership and independent acceptance-input gates are satisfied; all repair cards remain separately gated.
28. **Recommended roadmap effect after Chat review:** No sprint selection or renumbering; retain P0 repair boundaries.

### Six-family comparison (ADR-037 mutation factors)

Legend: **N** = no currently sufficient evidence/decision; **S** = source/snapshot needed; **U** = user decision needed; **A** = ADR-037 family decision needed; **E** = existing bounded import evidence only. These are not implementation designs.

| Mandatory factor | Historical duplicate repair | Import-session reversal | Account linking | Identifier detachment | Account split | Account merge |
|---|---|---|---|---|---|---|
| 1. Exact operation meaning | N/S/A | N/U/A | N/U/A | N/U/A | N/U/A | N/U/A |
| 2. Eligible durable records | N/S | N/S | account + identifiers N | identifiers N | graph N/S | two graphs N/S |
| 3. Immutable records | source/provenance E | source/provenance E | account identity E | source observations E | account identity E | both identities E |
| 4. Complete affected discovery | N/S | N/S | N | N | N/S | N/S |
| 5. Shared source/provenance | N/S | N/S | N | N | N/S | N/S |
| 6. Exact native-currency impact | N/S | N/S | none unless linked graph N | none unless relation changes N | N/S | N/S |
| 7. Identifier impact | N/S | N/S | central N/U | central N/U | N/U | central N/U |
| 8. Import-session impact | N/S | central N/S | N | N | N/S | N/S |
| 9. Conflict policy | N/A | N/U/A | N/U/A | N/U/A | N/U/A | N/U/A |
| 10. Deterministic preview | N/S | N/S | N | N | N/S | N/S |
| 11. Stale/precondition | A | A | A | A | A | A |
| 12. Provider generation | A | A | A | A | A | A |
| 13. Exact durable write set | N/A | N/A | N/A | N/A | N/A | N/A |
| 14. Successful audit evidence | A | A | A | A | A | A |
| 15. Privacy-safe audit fields | A | A | A | A | A | A |
| 16. SQLite atomicity | A | A | A | A | A | A |
| 17. In-Memory parity | A | A | A | A | A | A |
| 18. Canonical hydration | A | A | A | A | A | A |
| 19. Relaunch behavior | A | A | A | A | A | A |
| 20. Reversal/compensation/irreversibility | N/U/A | N/U/A | N/U/A | N/U/A | N/U/A | N/U/A |

**Recommendation from the comparison:** no executable ADR-037 mutation family is independently provable today. The `FW-P0-08` verifier is the smallest safe next boundary because it does not claim a financial correction and can reveal the actual family/snapshot that would make a mutation decision concrete.

### ADR candidate context — verifier alignment

- **Context:** ADR-037 requires review before family mutation but leaves no read-only cross-domain integrity verifier.
- **Decision:** if Chat approves, align a verifier with ADR-037; do not reserve a new ADR number, migration, mutation table, or audit ledger.
- **Alternatives:** broad repair, generic mutation framework, or database restore-as-undo are rejected by existing ADR-037 constraints.
- **Consequences:** a concrete affected graph can be discovered without mutation; a future repair still needs its own family packet.
- **Migration:** none.
- **Acceptance:** independently falsifiable invariant catalogue, no writes, fail-closed unreadable input, privacy-safe report.
- **Alignment:** ADR-037 lifecycle; ADR-038 confirmed-import ownership; ADR-046 authentic source rules for any statement-dependent claim.

</details>

---

<a id="fw-p0-11"></a>

## FW-P0-11 — Manual Account Linking and Unlinking

**Status:** Blocked
**Depends on:** Accepted ADR-037 and independently approved linking, unlinking and identifier-detachment semantics

The account-outcome explanation prerequisite was completed by Sprint 61. The remaining blocker is independently approved linking, unlinking and identifier-detachment semantics under ADR-037; this candidate is not implementation-ready.

Allow explicit manual linking and unlinking beyond the current bounded account-choice workflow.

Required protections include:

- immutable repository account identity;
- explicit confirmation;
- identifier conflict detection;
- impact preview;
- preservation of transactions and import provenance;
- no identity decisions based solely on filenames, labels or display metadata.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Chat must choose admissible proof, detach effect, and irreversibility/compensation for manual identifier detachment.

**Smallest proposed boundary:** Read-only relationship impact preview.

**Decision record:** [CHAT_DECISION_PACKET](#packet-chat-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: identifiers attach and resolve inside confirmed import; no detach/move endpoint is exposed.

**First-round scope and constraints:** Immutable account identity, explicit confirmation, impact preview, provenance preservation; labels, filenames and weak metadata are not identity authority. No automatic linking, identifier reassignment, account merge/split or runtime-store authority.

**First-round question/options:** Define manual link/unlink and identifier-detachment semantics. PROPOSED define one detach-only family before a link/move family; merge neither with import choice.

**First-round remainder and implications:** EXPLICIT_USER_DECISION: eligible link proof, detach effect and reversal/irreversibility. ADR-037; possible relation/audit schema is unknown.

**First-round proposed acceptance/falsifier:** Conflicting/weak proof rejects; plan enumerates affected identifiers, sessions and transactions; provider parity/hydration holds. Any contract that needs source identity reconstructed from weak metadata.

**Second-round new evidence/resolved direction:** No source fact can turn similarity into account identity.

**Exact next evidence or decision:** Explicit product decision; later selected incident evidence.

**Personal-v1:** POST_V1: no current adoption requirement.

**Recommendation after Chat:** Preserve queue status; named Chat-owned source/privacy/financial family decision remains before implementation planning. **Roadmap:** No change

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** approved detach semantics.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** IDENTITY, MUTATION_SEMANTICS, REVERSIBILITY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `accepted-adr-037`: family mutation lifecycle
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-chat-family-fw-p0-11`: Chat must choose admissible proof, detach effect, and irreversibility/compensation for manual identifier detachment.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):306-322 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P0-11
- [Database/Repository.swift](<../Database/Repository.swift>):228-237 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — AccountRepository
- [Project documents/ADR.md](<ADR.md>):3451-3466 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — identifier detachment has no approved operation

</details>

---

<a id="fw-p0-12"></a>

## FW-P0-12 — Identifier Backfill Policy

**Status:** Blocked
**Architecture:** ADR-038 accepted in Sprint 49
**Implementation:** Confirmed-import enrichment and observation slice completed by Sprint 50; broader policy remains pending
**Depends on:** Separate future decisions for identifier correction, reassignment and historical repair

Sprint 49 approved the confirmed-import portion of identifier enrichment. When parser-produced strong verified identifiers uniquely resolve one existing account, existing same-account identifiers are idempotently accepted and additional eligible identifiers may be attached automatically only when each is unowned or already owned by that resolved account. Conflicting ownership rejects the complete import, and attachment occurs only as part of a successful provider-owned atomic confirmed import.

ADR-029 remains authoritative for `noMatch`: the user must explicitly choose an eligible unseeded existing account or creation of a new account, no account may be selected automatically, and the choice must be revalidated inside the provider transaction.

Sprint 50 implemented durable identifier ownership and accepted-import observation provenance for successful confirmed imports. Each bounded observation relates identifier ownership to its accepted import session, accepted document, parser provenance and account-association authority; transaction-time ownership enforcement is active, and historical observations are not invented.

The following work remains open and separately gated:

- unlinking;
- reassignment;
- incorrect-link recovery;
- historical backfill;
- repair of contradictory existing ownership.

The completed confirmed-import concurrency slice and this enrichment slice were combined only because they share one atomic confirmation boundary. Identifier-management workflows outside successful confirmed import do not become part of that operation and remain independently governed.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** FW-P0-11 unlink policy and a concrete correction family are unaccepted.

**Smallest proposed boundary:** Correction policy after unlink semantics.

**Decision record:** [CHAT_DECISION_PACKET](#packet-chat-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: atomic confirmed import permits only unowned/same-owner strong identifiers and records observations; conflicting owners reject complete import.

**First-round scope and constraints:** Historical observations are not invented; noMatch requires explicit eligible account choice and transaction-time revalidation. No backfilled observations or automatic reassignment.

**First-round question/options:** What identifier backfill remains after confirmed-import enrichment? PROPOSED keep accepted enrichment separate from later identity repair.

**First-round remainder and implications:** MISSING separate policies for correction, reassignment, unlinking and historical repair. ADR-038 stays; later audit/relation decision unknown.

**First-round proposed acceptance/falsifier:** Provider rejects cross-owner candidate with zero accepted graph; historical data remains unchanged. Evidence that a proposed identifier is not parser-produced strong verified evidence.

**Second-round new evidence/resolved direction:** None; accepted confirmed-import enrichment is intentionally distinct from repair.

**Exact next evidence or decision:** Approved unlink family.

**Personal-v1:** POST_V1: completed enrichment is distinct.

**Recommendation after Chat:** Blocked **Roadmap:** No change

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** unlink decision.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** IDENTITY, MUTATION_SEMANTICS, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-11`: Chat owns this financial/privacy/architecture decision; it is not a technical questionnaire for the user.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):326-347 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P0-12
- [Database/SQLiteConfirmedImportRepository.swift](<../Database/SQLiteConfirmedImportRepository.swift>):182-224 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `94798b9f38227067b2973fdcce07d5d41d8636726849eaac6037aef7470cf8e2` — commitInsideTransaction
- [Project documents/ADR.md](<ADR.md>):4621-4630 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — no unlinking or historical repair

</details>

---

<a id="fw-p0-13"></a>

## FW-P0-13 — Incorrect-Link Recovery and Account Split

**Status:** Blocked
**Depends on:** `FW-P0-11`, Accepted ADR-037, and independently approved split and relationship-movement rules

Recover when transactions, import sessions or identifiers were attached to the wrong account.

Candidate outcomes include:

- moving an import session;
- detaching an incorrect identifier;
- separating incorrectly combined history;
- restoring previous relationships;
- recalculating affected account presentation safely.

No automatic account split is permitted.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** FW-P0-11 plus selected incident/split semantics remain absent.

**Smallest proposed boundary:** Selected-incident read-only impact graph.

**Decision record:** [CHAT_DECISION_PACKET](#packet-chat-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: imported graph has session/document/transaction/identifier relationships but no relationship-movement executor.

**First-round scope and constraints:** No automatic split; immutable account identity and source/import provenance survive any move. No automated split, generic undo or broad repair.

**First-round question/options:** Recover an incorrect account relationship or split safely. PROPOSED separate detachment, session movement and account split; they have distinct write sets.

**First-round remainder and implications:** EXPLICIT_USER_DECISION for split predicate, movement set, survivor relationships and compensation. Unknown until relationships/audit are selected.

**First-round proposed acceptance/falsifier:** Exact impact includes supporting sources/shared transactions; reject incomplete scope; parity, hydration and inverse/irreversibility proved. Cross-format supporting source whose source relationship cannot be moved without falsifying provenance.

**Second-round new evidence/resolved direction:** No durable relationship-movement executor exists.

**Exact next evidence or decision:** Selected incident and approved movement rules.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** No change

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** source relationship not movable without provenance loss.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** IDENTITY, MUTATION_SEMANTICS, REVERSIBILITY, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-11`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. link/detach policy
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p0-13`: A genuine affected incorrectly linked account/transaction snapshot, original identifier evidence and an independent projection of which existing records belong to each account; absent incidents cannot be fabricated.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):351-366 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P0-13
- [Project documents/ADR.md](<ADR.md>):3480-3518 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-037
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):1012-1024 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — split and movement remain separate

</details>

---

<a id="fw-p0-14"></a>

## FW-P0-14 — Duplicate-Account Review

**Status:** Blocked
**Depends on:** `FW-P0-11`

Present accounts that may represent the same real financial account.

The review must distinguish:

- verified shared identity;
- weak similarity;
- overlapping transaction history;
- coincidental display metadata.

Weak evidence must never establish identity automatically.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Chat must approve evidence classes and privacy-safe candidate presentation; weak similarity cannot establish identity.

**Smallest proposed boundary:** Read-only categorized account comparison report.

**Decision record:** [CHAT_DECISION_PACKET](#packet-chat-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: exact account identifiers provide durable ownership; existing review API is import-focused.

**First-round scope and constraints:** Must distinguish verified shared identity, weak similarity, overlap and coincidental metadata; weak evidence never auto-establishes identity. No automatic merge/link/change; no raw identifier exposure.

**First-round question/options:** Review possible duplicate accounts without turning similarity into identity. PROPOSED evidence-only inspector with categories, never a merge suggestion that acts as proof.

**First-round remainder and implications:** Approved non-mutating candidate evidence policy and privacy-safe presentation. No migration for read-only review; later merger needs ADR-037 family decision.

**First-round proposed acceptance/falsifier:** Known weak collision is labelled non-authoritative; verified conflict is surfaced; no writes. Need for unretained private/raw evidence.

**Second-round new evidence/resolved direction:** Two opaque source account identities do not constitute duplicate-account evidence.

**Exact next evidence or decision:** Non-mutating evidence policy.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve queue status; named Chat-owned source/privacy/financial family decision remains before implementation planning. **Roadmap:** No change

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** approved evidence categories.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** IDENTITY, PRIVACY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-11`: Chat owns this financial/privacy/architecture decision; it is not a technical questionnaire for the user.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-chat-family-fw-p0-14`: Chat must approve evidence classes and privacy-safe candidate presentation; weak similarity cannot establish identity.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):370-384 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P0-14
- [Database/SQLiteConfirmedImportRepository.swift](<../Database/SQLiteConfirmedImportRepository.swift>):182-203 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `94798b9f38227067b2973fdcce07d5d41d8636726849eaac6037aef7470cf8e2` — identifier ownership
- [Project documents/ADR.md](<ADR.md>):3476-3495 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — identity and provenance must be preserved

</details>

---

<a id="fw-p0-15"></a>

## FW-P0-15 — Manual Account Merge

**Status:** Blocked
**Depends on:** `FW-P0-14`, Accepted ADR-037, and independently approved survivor-identity, conflict and merge policy

Provide a previewed manual merge that preserves:

- one selected immutable account identity;
- valid transactions;
- import-session provenance;
- verified identifiers;
- account metadata;
- rollback protection.

All conflicts must be surfaced before any write.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** FW-P0-14 review plus survivor and identifier-conflict decisions are absent.

**Smallest proposed boundary:** Read-only selected-survivor impact plan.

**Decision record:** [CHAT_DECISION_PACKET](#packet-chat-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: no account merge protocol; confirmed import creates/reuses one account under restricted rules.

**First-round scope and constraints:** One selected immutable survivor; all conflicts visible; transactions, sessions, identifiers and metadata require exact handling and reversal protection. No automatic merging, raw source modification or backup-based undo.

**First-round question/options:** Manually merge accounts while preserving history and identity. PROPOSED defer merge until review and link policies are accepted; do not treat a database transaction as rollback protection.

**First-round remainder and implications:** EXPLICIT_USER_DECISION survivor/identifier conflict policy and family-specific inverse. Potential relation/audit migration unknown.

**First-round proposed acceptance/falsifier:** Plan covers every related session/document/fingerprint/supporting source; stale/conflicting plan rejects; parity and compensation proven. Any unsolved multi-owner identifier or supporting-source relationship.

**Second-round new evidence/resolved direction:** None.

**Exact next evidence or decision:** Chat-approved survivor, identity-conflict and exact merge-impact semantics after FW-P0-14 evidence review; a user preference alone cannot prove account identity.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** No change

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** shared source/provenance graph.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** IDENTITY, MUTATION_SEMANTICS, REVERSIBILITY, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-14`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. candidate proof policy
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p0-15`: Genuine candidate account records, their authentic identifier/source provenance, all overlapping accepted imports and an independent projection of survivor/conflict impact; user preference alone cannot prove identity.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):388-402 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P0-15
- [Project documents/ADR.md](<ADR.md>):3460-3500 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-037
- [Project documents/ADR.md](<ADR.md>):3451-3462 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — merge has no approved architecture

</details>

---

<a id="fw-p0-16"></a>

## FW-P0-16 — Reversible Financial-Mutation Foundation

**Status:** Candidate
**Discovery:** Complete
**ADR-037:** Accepted
**Post-Sprint-45 lifecycle revalidation:** Complete
**Planning state:** Architecture accepted
**Implementation state:** Gated
**Selected strategy:** Strategy A — contract-first architecture
**Schema state:** No migration authorized
**Depends on:** Independent selection of a concrete mutation family before source-level contracts

Discovery completed against commit `fe1f109bb8a1b9d425187869e91eefe98f4e5bb8` with a clean worktree and no repository changes. General architecture discovery is complete. Focused provider-lifecycle revalidation against the final Sprint 45 design is complete, and ADR-037 is Accepted. No executable mutation is authorized.

**Current discovery disposition — 2026-09-10:** `DECISION_CLOSED_BY_EXISTING_AUTHORITY`. **Exact remaining gate:** An exact family remains required before source protocol/schema work.

**Smallest proposed boundary:** No foundation implementation; first approve read-only verifier or a source-proven family.

**Decision record:** [CHAT_DECISION_PACKET](#packet-chat-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY/EXPLICIT_USER_DECISION: ADR-037 is contract-first only; confirmed import deliberately exposes no generic transaction closure.

**First-round scope and constraints:** Plan/digest/precondition/provider-generation binding, atomic successful audit, canonical hydration, provider parity and family-specific reversal/compensation/irreversibility are mandatory. All repair, deletion, merge/split, reversal, generic audit, migration and UI.

**First-round question/options:** What shared reversible-mutation foundation is accepted? Accepted Strategy A; PROPOSED choose one real family before source contracts.

**First-round remainder and implications:** MISSING concrete mutation family and production-capable planning/executor contracts. No migration authorized.

**First-round proposed acceptance/falsifier:** All listed prerequisite proof; a failed write leaves no family/audit partial state and successful commit hydrates canonically. Family needs generic behavior or unbounded audit schema.

**Second-round new evidence/resolved direction:** ADR-037 already rejects generic executable mutation infrastructure and requires a family-owned contract.

**Exact next evidence or decision:** Selected family only.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Candidate **Roadmap:** No change

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** any generic mutation proposal.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=true, authentic source=false. **Blocker types:** MUTATION_SEMANTICS, DEPENDENCY.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `FW-P0-08`: verifier reduces later mutation risk
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):408-489 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P0-16
- [Database/Repository.swift](<../Database/Repository.swift>):279-288 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — ConfirmedImportRepository
- [Project documents/ADR.md](<ADR.md>):3497-3543 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — lifecycle is accepted but no concrete mutation is authorized

</details>

---

<a id="fw-p0-18"></a>

## FW-P0-18 — Workspace-Scoped Fingerprint Uniqueness

**Status:** Blocked
**Discovery:** Complete
**Depends on:** An approved `FW-P3-40` multiple-workspace architecture that explicitly decides fingerprint scope

Define exact-statement fingerprint ownership when one LedgerForge database contains more than one independent workspace.

The design must determine:

- whether exact-content uniqueness is workspace-scoped or database-wide;
- schema and migration requirements;
- treatment of identical source content imported into independent workspaces;
- conflict and migration behavior for existing database-wide fingerprints;
- privacy and diagnostic boundaries.

Fingerprint scope is a subdecision of the future multiple-workspace architecture. `FW-P0-18` must not be treated as an independent prerequisite that blocks discovery of `FW-P3-40`, because doing so creates a circular dependency.

The source digest must remain derived from source evidence rather than being altered merely to encode workspace identity.

No schema change is authorized until workspace identity, isolation and migration semantics are approved.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** FW-P3-40 owns the single user choice about multiple independent workspaces. If adopted, Chat must approve workspace isolation and fingerprint lookup/uniqueness scope; this card has no separate user product choice.

**Smallest proposed boundary:** Architecture record only.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: current duplicate authority is queried by algorithm/fingerprint without workspace in the visible confirmed-import check.

**First-round scope and constraints:** Digest stays source-derived; fingerprint scope is a subdecision of FW-P3-40, avoiding circular blockage. No schema change or workspace implementation.

**First-round question/options:** Should exact-source fingerprint uniqueness be workspace or database scoped? PROPOSED let workspace architecture select scope then design transition; do not salt digest.

**First-round remainder and implications:** EXPLICIT_USER_DECISION multiple-workspace identity/isolation/migration semantics. Migration required only after scope decision; no number.

**First-round proposed acceptance/falsifier:** Identical source in two isolated workspaces follows selected rule and privacy constraints; existing DB transition is explicit. Chosen workspace design cannot preserve source-derived digest.

**Second-round new evidence/resolved direction:** None.

**Exact next evidence or decision:** Selected FW-P3-40 product outcome and a Chat-approved workspace isolation/fingerprint scope contract, followed by source-backed cross-workspace duplicate/ownership acceptance.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** No change

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** workspace selection.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** IDENTITY, DURABLE_PERSISTENCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-40`: Workspace-scoped fingerprint uniqueness is an isolation subdecision of the selected multi-workspace product; the single user product choice lives only under FW-P3-40.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):493-513 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P0-18
- [Database/SQLiteConfirmedImportRepository.swift](<../Database/SQLiteConfirmedImportRepository.swift>):175-180 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `94798b9f38227067b2973fdcce07d5d41d8636726849eaac6037aef7470cf8e2` — duplicate fingerprint check
- [Project documents/Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md](<Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md>):205-208 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — fingerprint scope is workspace-gated

</details>

---

<a id="fw-p0-19"></a>

## FW-P0-19 — Remaining Cross-Format Statement Duplicate Identity

**Status:** Blocked
**Depends on:** an independently source-proven representation pair and an accepted family-specific identity/equivalence contract beyond the completed HDFC, Axis-card and CBQ-lineage boundaries

**Completed boundary:** ADR-042 establishes exact whole-statement HDFC PDF/XLS equivalence. ADR-044 establishes exact Axis credit-card representation-neutral financial equivalence for the accepted PDF/XLSX family. ADR-043 separately establishes exact reviewed CBQ current-account source lineage; it is not generic equivalence.

**Remaining boundary:** The accepted 127-carrier reset proves format-neutral Axis-bank semantic parity as engineering regression evidence, but no accepted ADR establishes durable Axis-bank cross-format duplicate identity, equivalent-supporting-source suppression or authoritative-source replacement. Axis-bank relationship semantics, additional institution/format pairs, same-format byte-distinct semantic identity, source replacement and unapproved partial-overlap families remain separately source-gated.

Any future relationship must distinguish exact-content duplicates, multiple representations of one statement, revised statements, overlapping statements and coincidentally similar transaction sets. It must use complete relevant authentic-source evidence and an independent architecture-aware source oracle. Filename, count, page or layout similarity is never authority.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No new source-proven family-specific equivalence pair. The inspected Axis-bank three-format groups do not satisfy the tested financial/reference projection; accepted HDFC pairs remain limited to ADR-042.

**Smallest proposed boundary:** Read-only pair/projection comparison, no source suppression or replacement.

**Decision record:** [TRANSFER_FAMILY_DECISION_PACKET](#packet-transfer-family-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: exact content duplicates, accepted HDFC/Axis-card equivalence and CBQ lineage are distinct bounded paths; Axis-bank parity is not durable equivalence.

**First-round scope and constraints:** Every new pair needs complete authentic evidence and independent architecture-aware oracle; layout/count/name similarity is never authority. No fuzzy/same-format semantic matching, source replacement, partial overlap or Axis-bank assumption.

**First-round question/options:** Define remaining cross-format statement duplicate/equivalence identity. PROPOSED nominate one representation pair only after source/oracle availability.

**First-round remainder and implications:** MISSING source-proven pair and accepted family-specific relation contract. Pair-specific relationship schema may be needed; none allocated.

**First-round proposed acceptance/falsifier:** Different representations either establish exact approved projection relation or fail closed with no source residue. Missing complete corpus or any ambiguity between revised/overlap/equivalent sources.

**Second-round new evidence/resolved direction:** Three logical Axis-bank groups have distinct-byte CSV/PDF/XLS carriers, but zero satisfy the tested exact financial/reference projection; HDFC's four exact pairs remain the accepted ADR-042 family.

**Exact next evidence or decision:** A genuine new candidate family/pair with independent source facts, source currency/account/period/ordering and explicit architecture-aware semantic projection that establishes the proposed relation.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Blocked until authentic relationship evidence is complete; no promotion based on unmatched Axis-bank groups. **Roadmap:** No change

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** any mismatch, revised source, account conflict, or same-format claim.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=true, authentic source=true. **Blocker types:** SOURCE_TRUTH, FINANCIAL_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `accepted-adr-042`: existing bounded equivalence model
- `REQUIRES_AUTHENTIC_SOURCE` → `source-new-equivalence-family`: Unmatched source groups do not establish a new equivalence contract.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):517-526 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P0-19
- [Services/ImportPersistenceCoordinator.swift](<../Services/ImportPersistenceCoordinator.swift>):1845-1856 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `052b8de5c2de61349a5151d676e1dade3ec005363fb82f4eed290822bea2cfae` — equivalentSourceRecorded
- [Project documents/ADR.md](<ADR.md>):5032-5064 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — same-format byte-different and source replacement are excluded

</details>

---

<a id="fw-p0-20"></a>

## FW-P0-20 — Additional Transaction-Event Evidence Families

**Status:** Research
**Depends on:** Authentic overlapping source evidence for each proposed family and family-specific deterministic reference, subtype, reuse, conflict and privacy semantics

Investigate additional transaction-event evidence families without expanding the bounded Axis UPI authority prematurely. Possible families include:

- IMPS;
- NEFT;
- e-commerce or card events;
- unstructured references;
- reversal;
- refund.

Each family may require a separate ADR and implementation increment. No family may reuse the Axis UPI algorithm identifier. Stable-looking tokens alone are insufficient; date, amount, narration, balance, filename and row position remain weak evidence. Missing evidence does not prove novelty, and no historical backfill is implied.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No independently established overlapping event family with deterministic reference/subtype/reuse/conflict semantics.

**Smallest proposed boundary:** Evidence register only.

**Decision record:** [TRANSFER_FAMILY_DECISION_PACKET](#packet-transfer-family-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: repeated/existing supported event evidence blocks imports; current algorithm is bounded Axis UPI.

**First-round scope and constraints:** No reuse of Axis UPI identifier; tokens, date, amount, narration, balance, filename and row position are weak evidence. No IMPS/NEFT/card/refund/reversal implementation or historical backfill.

**First-round question/options:** Which additional transaction-event evidence family can safely extend Axis UPI? PROPOSED defer every listed family until authentic overlap is registered; none has source evidence here.

**First-round remainder and implications:** MISSING authentic overlapping sources plus deterministic reference/subtype/reuse/conflict/privacy semantics for each proposed family. Unknown, family-specific.

**First-round proposed acceptance/falsifier:** Oracle proves same event/reuse/conflict; false-positive risk test rejects weak coincidence; zero residue when unsupported. Evidence depends on stable-looking token alone.

**Second-round new evidence/resolved direction:** The two cross-account shapes have zero matching nonempty structured-reference or narration digests; they cannot seed an event algorithm.

**Exact next evidence or decision:** One authenticated overlapping family and independent event oracle.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Research **Roadmap:** No change

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** stable token-only proof.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, FINANCIAL_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-new-event-family`: event truth
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p0-20`: No independently established overlapping event family with deterministic reference/subtype/reuse/conflict semantics.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):530-544 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P0-20
- [Services/ImportPersistenceCoordinator.swift](<../Services/ImportPersistenceCoordinator.swift>):1864-1873 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `052b8de5c2de61349a5151d676e1dade3ec005363fb82f4eed290822bea2cfae` — transaction event blocking
- [Project documents/LedgerForge_Standing_Execution_Harness_Guide.md](<LedgerForge_Standing_Execution_Harness_Guide.md>):192-205 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — parser output and weak similarity cannot be sole authority

</details>

---

<a id="fw-p0-26"></a>

## FW-P0-26 — Personal-v1 Adoption Certification Gate

**Status:** Blocked
**Depends on:** completion or explicit Chat deferral of every product boundary classified as pre-v1, including adopted import, required user backup/restore and support documentation; complete structured/user export is optional under UD-02 and must be completed only if adopted, or explicitly Chat-deferred in the frozen adoption matrix

Personal-v1 may not be declared merely because current automated tests are green. Certification fails closed and must freeze the exact adopted product candidate.

Applicable evidence must include at minimum:

- current complete authentic-source corpus certification;
- exact supported-source documentation;
- Release build and canonical TestPlan;
- import workflow/manual acceptance;
- password/credential-path acceptance where relevant;
- single-file and batch intake as actually adopted;
- duplicate and rejection semantics;
- durable persistence and migration integrity;
- SQLite/In-Memory parity where applicable;
- close/reopen/relaunch/hydration;
- user-owned backup creation, integrity verification and restore drill;
- privacy/residue review;
- structured/user data export only if adopted in the frozen Chat adoption matrix; complete export is optional under UD-02;
- supported institution/source matrix;
- manual period/account reconciliation;
- defined parallel comparison against the existing Budget Analysis workbook or its agreed successor oracle for the applicable planning/analytics boundary;
- documented limitations and source-uncertified cases.

Absent authentic cases remain uncertified and must not be manufactured. Certification does not require every Product Vision feature; it requires every feature Chat explicitly classifies as pre-v1 before the certification attempt. Personal-v1 remains undeclared until Chat explicitly accepts this gate.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Backup/restoration ADR and independently accepted user restore drill; frozen Chat adoption matrix.

**Smallest proposed boundary:** Certify only frozen adopted candidate; required backup, authentic corpus and manual rows; optional export.

**Decision record:** [USER_BACKUP_RESTORE_ARCHITECTURE_PACKET](#packet-user-backup-restore-architecture-packet), [PERSONAL_V1_CERTIFICATION_PACKET](#packet-personal-v1-certification-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY at research ref: committed PROJECT_STATE and roadmap record accepted Sprint82 and complete-corpus alignment. Native import/hydration and migration tests are foundations, while user-owned backup/restore and domain export remain queue items. Subsequent separately owned Sprint83 acceptance closure at ffddebc6e12405c812a36855ab6212e973cff5ba is incorporated as publication authority, not self-accepted by this campaign.

**First-round scope and constraints:** The app remains private, local and explicit. Accepted financial history, native Money, order, multiplicity and provenance cannot be silently rewritten. ADR-046 authentic-input rules apply to financial cases; migration identities remain append-only. Discovery grants no implementation or acceptance. Exclude certification by this report, new full-suite/corpus runs, enterprise/cloud prerequisites, and treating workbook formulas as financial architecture.

**First-round question/options:** What precise boundary must personal-v1 certification freeze? A scope-frozen personal adoption gate serves this owner; requiring every Product Vision item or treating one green suite as certification does not.

**First-round remainder and implications:** Chat-owned adopted pre-v1 feature/deferral matrix; exact accepted candidate; user-owned backup/restore drill and export/support deliverables; independent period/account and applicable workbook comparison. This campaign did not execute certification. Certification record itself needs no migration; each adopted feature retains its own ADR/schema gate.

**First-round proposed acceptance/falsifier:** Freeze the actual adopted bytes and supported corpus; prove Release/TestPlan, credentials/import/manual/batch where adopted, duplicate/rejection residue, provider parity, durable startup/relaunch, backup integrity and isolated restore, export privacy, support matrix and independent period/account comparison. Record absent authentic cases as uncertified. Candidate/code/corpus change, an unclosed adopted dependency, or a workbook comparison using retired assumptions invalidates the certification attempt.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY at research ref: committed PROJECT_STATE and roadmap record accepted Sprint82 and complete-corpus alignment. Native import/hydration and migration tests are foundations, while user-owned backup/restore and domain export remain queue items. Subsequent separately owned Sprint83 acceptance closure at ffddebc6e12405c812a36855ab6212e973cff5ba is incorporated as publication authority, not self-accepted by this campaign. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Backup/restoration ADR and independently accepted user restore drill; frozen Chat adoption matrix. Owning authority: USER_BACKUP_RESTORE_ARCHITECTURE_PACKET, PERSONAL_V1_CERTIFICATION_PACKET.

**Personal-v1:** PRE_V1_REQUIRED

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-36`: The Verified Backup, Restore and Disaster Recovery boundary must provide: User-owned verified package; isolated restore; nonempty target protection.. This enables Certify only frozen adopted candidate; required backup, authentic corpus and manual rows; optional export. Remaining condition: Backup/restoration ADR and independently accepted user restore drill; frozen Chat adoption matrix.
- `REQUIRES_RUNTIME_ACCEPTANCE` → `FW-P3-36`: The Verified Backup, Restore and Disaster Recovery boundary must provide: User-owned verified package; isolated restore; nonempty target protection.. This enables Certify only frozen adopted candidate; required backup, authentic corpus and manual rows; optional export. Remaining condition: Backup/restoration ADR and independently accepted user restore drill; frozen Chat adoption matrix.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-adoption-matrix`: Chat owns this financial/privacy/architecture decision; it is not a technical questionnaire for the user.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p0-26`: The complete registered authentic corpus for every adopted source family, an independently checked adopted workspace snapshot and genuine backup/restore round-trip evidence; no certification from synthetic statements.

**Pinned evidence references:**

- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Services/RepositoryStoreHydrator.swift](<../Services/RepositoryStoreHydrator.swift>):209-269;344-440 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `40cbd69a8a470748fcb637cb10ae5597855d5a03771e165d8f551162d2b94117` — RepositoryStoreHydrator.init(workspaceId:); stageHydration()
- [LedgerForgeTests/MigrationChainIntegrityTests.swift](<../LedgerForgeTests/MigrationChainIntegrityTests.swift>):253-367 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `6ad68d2dd32d041fe1224e644c3d067d3539ecfb63dd53793560e22f3d854688` — empty historical prefixes and fail-closed history tests
- [LedgerForgeTests/MigrationIdentityLockTests.swift](<../LedgerForgeTests/MigrationIdentityLockTests.swift>):1-52 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `722c49a26a6785be7c4d537973d0a2790fc84b162d310e04ed399e6fdd0fcae9` — independent identity lock and drift detection
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):1-90 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7843854eee6c85888f41af52c52aba70f2d0138c5f6f21e518211c75aca62797` — current accepted state and authentic reset
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):530-580 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P0-26 gate
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):3061-3075 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — User backup/restore is a separate user-facing contract.
- [Database/SQLiteDatabase.swift](<../Database/SQLiteDatabase.swift>):90-146 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — WAL, SQLite online backup and checked close exist.

</details>

<a id="packet-personal-v1-certification-packet"></a>

<details>
<summary>PERSONAL_V1_CERTIFICATION_PACKET — complete proposed decision packet</summary>

## PERSONAL_V1_CERTIFICATION_PACKET

| # | Required field | Decision |
| --- | --- | --- |
| 1 | Owning FW IDs | FW-P0-26; aggregates adopted support, recovery, export and validation boundaries. |
| 2 | User problem | A falsifiable adoption declaration rather than a claim derived from green tests. |
| 3 | Verified current state | Accepted Sprint 83 records corpus/provider/order/build/relaunch evidence and explicitly does not declare personal-v1. |
| 4 | Accepted authorities | PROJECT_STATE; FUTURE_WORK gate; ADR-024; ADR-046; immutable migration identity lock. |
| 5 | Exact missing decision | Chat must accept exact candidate/adoption matrix; backup architecture/drill remains unaccepted. |
| 6 | Evidence acquired | Current gate names recovery and export; user now requires backup/restore and marks complete export optional. |
| 7 | Options considered | All vision features; frozen adopted-boundary matrix; green suite only. |
| 8 | Recommended option | Candidate-frozen adoption matrix with each boundary, independent oracle, evidence, limitation and recertification trigger. |
| 9 | Why competing options are rejected | Vision-wide is unbounded; a suite cannot prove source, native recovery, export, privacy or relaunch. |
| 10 | Smallest coherent implementation boundary | Certification record and validations for adopted features; no new product feature. |
| 11 | Included scope | Authentic corpus, candidate identity, supported-source docs, adopted import/credential/manual checks, duplicate/rejection, parity, migration/hydration/relaunch, required backup drill, period/account and agreed workbook-successor comparison. |
| 12 | Explicit exclusions | Unadopted sync/API/plugins/multiworkspace/cross-platform/encryption/analytics; complete export unless user promotes it; appearance unless adopted. |
| 13 | Durable model/persistence requirements | Privacy-safe matrix records candidate digests, evidence class and limitations only; no runtime data change. |
| 14 | Migration impact | NONE; adopted feature changes retain own decision. |
| 15 | ADR impact | ALIGN_EXISTING; backup ADR is separate prerequisite. |
| 16 | Privacy/security boundary | Opaque digests/counts only; no source content, paths, names, financial values or credentials. |
| 17 | SQLite/In-Memory implications | Matrix labels provider-parity checks; In-Memory cannot substitute for restore/relaunch. |
| 18 | Hydration/relaunch implications | Canonical same-database relaunch plus restored-target hydration/relaunch are required rows. |
| 19 | Independent acceptance oracle | Independent source projections, migration/package checks and native evidence where static inspection cannot establish behavior. |
| 20 | Failure cases | Candidate/corpus/schema drift, missing oracle, unresolved limitation, failed restore, unsupported source, obsolete workbook comparison. |
| 21 | Reversal/correction semantics | Failed certification is not repaired retroactively; freeze new candidate and rerun affected rows. |
| 22 | Source evidence requirement | Required for every statement-dependent claim; absent cases remain uncertified. |
| 23 | Runtime acceptance requirement | Required for adopted import/credential/backup and durable UI flows. |
| 24 | Dependencies | Accepted backup ADR+drill; exact candidate; corpus; support docs; Chat adoption matrix; workbook-successor decision. |
| 25 | Evidence that falsifies the recommendation | Any missing matrix row, changed candidate/corpus/financial semantics, or claim lacking independent evidence. |
| 26 | Personal-v1 relevance | PRE_V1_REQUIRED: declaration gate. |
| 27 | Recommended FUTURE_WORK status after Chat review | READY_AFTER_NAMED_DEPENDENCY: backup contract/drill and Chat matrix. |
| 28 | Recommended roadmap effect after Chat review | Add gate only; do not declare personal-v1 or select sprint. |

</details>

---

<a id="fw-p1-01"></a>

## FW-P1-01 — Additional Axis Bank-Account Parser Families

**Status:** Candidate
**Depends on:** complete registered authentic Axis corpora for each materially distinct new or changed bank-account source-family semantic contract

**Completed boundary:** Current accepted Axis bank-account support already covers the source-proven CSV, PDF and legacy-XLS families recorded in `PROJECT_STATE.md`, with the accepted 127-carrier reset providing current ADR-046 reliability certification for the registered corpus. Sprint 78B separately owns the exact Axis credit-card PDF/XLSX family.

**Remaining boundary:** Only additional or materially changed Axis bank-account families remain here, including new historical layouts, account products or source contracts not already covered by current accepted profiles. No new family inherits support from existing Axis profiles.

Each future family requires complete authentic-corpus inventory, independently derived source truth, explicit semantic projection, deterministic routing/profile selection and complete affected-corpus regression. The prohibited synthetic/sanitized financial-fixture retirement is already complete and is not future work.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No selected additional Axis bank family or registered authentic corpus/oracle.

**Smallest proposed boundary:** Register one family before assessing reuse.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: exact certified Axis CSV/PDF/legacy-XLS families exist; shared pipeline does not establish an unselected family.

**First-round scope and constraints:** EXPLICIT_USER_DECISION/VERIFIED_REPOSITORY: ADR-046 requires complete authentic corpus, independent source oracle and deterministic semantic routing; profiles do not generalize. No parser change, certification, credentials, OCR, generic Axis support, migration or duplicate-policy change.

**First-round question/options:** Which additional Axis bank-account family should be expanded? Baseline adcf83f52d309ddac18d95f0321d0c0f6120dd29; reviewed 2026-09-10. PROPOSED: select one supplied recurring family or defer; never infer from Axis name or historical labels.

**First-round remainder and implications:** MISSING: selected product/layout/format, registered originals and independent source truth; no source location or choice is recorded. No migration presumed; ADR-046 governs. ADR only if new durable identity/equivalence contract.

**First-round proposed acceptance/falsifier:** Complete affected corpus via ordinary production, independent projection, persistence/reopen/hydration and shared-corpus regression. Different financial roles, currency, identifier or representation relationship invalidates Axis reuse.

**Second-round new evidence/resolved direction:** Current support is exact-profile only.

**Exact next evidence or decision:** One selected recurring family, complete corpus, independent semantic projection.

**Personal-v1:** PRE_V1_OPTIONAL: no declared adoption need.

**Recommendation after Chat:** Candidate blocked on selected source **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** New family/source contract.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-selected-axis-family`: No family is selected.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-01`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. No selected additional Axis bank family or registered authentic corpus/oracle.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):581-592 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-01
- [Project documents/ADR.md](<ADR.md>):5920-6085 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-046
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):85-95,964-972 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Exact corpus/profile boundary only.

</details>

---

<a id="fw-p1-02"></a>

## FW-P1-02 — Additional HDFC Parser Families

**Status:** Candidate
**Depends on:** complete authentic HDFC evidence for one selected new or changed source-family contract

**Completed boundary:** Exact `hdfc.bank-account.xls@1` and `hdfc.bank-account.pdf@1` bank-account support is accepted, including ADR-042 whole-statement PDF/XLS equivalence and current complete-corpus reliability certification under ADR-046.

**Remaining boundary:** HDFC CSV, XLSX, credit-card families, changed bank layouts and any additional source-format relationship remain unsupported until independently source-proven. Existing HDFC PDF/XLS support does not generalize by institution name or structural similarity.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No selected HDFC CSV/XLSX/card/changed-layout family or corpus/oracle.

**Smallest proposed boundary:** Inventory one family then assess exact reuse.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: only hdfc.bank-account.xls@1 and hdfc.bank-account.pdf@1 are accepted; ADR-042 is exact PDF/XLS equivalence, not generic HDFC.

**First-round scope and constraints:** VERIFIED_REPOSITORY: readers extract generically, parsers own finance/identifiers, ADR-046 forbids synthetic substitutes. No HDFC-wide support, generic XLSX, cards, OCR, password expansion or automatic equivalence.

**First-round question/options:** What additional HDFC bank/card/format contract is worth supporting? PROPOSED: choose one real recurring family and assess reader output; otherwise defer.

**First-round remainder and implications:** MISSING: chosen HDFC CSV/XLSX/card/changed layout and complete originals/source truth. No migration assumed; ADR-042 reuse requires exact proof.

**First-round proposed acceptance/falsifier:** Complete family corpus, independent projection, ordinary import, zero-residue rejection, provider parity and durable hydration. Different card liability, source identifier or PDF/XLS relationship bars reuse.

**Second-round new evidence/resolved direction:** ADR-042 does not generalize HDFC support.

**Exact next evidence or decision:** Selected family and complete independent source projection.

**Personal-v1:** PRE_V1_OPTIONAL: unselected expansion.

**Recommendation after Chat:** Candidate blocked on authentic source **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Different liability/identity/format relationship.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-selected-hdfc-family`: No candidate supplied.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-02`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. No selected HDFC CSV/XLSX/card/changed-layout family or corpus/oracle.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):594-603 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-02
- [Project documents/ADR.md](<ADR.md>):5011-5125 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-042
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):964-972 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No generic HDFC family support.

</details>

---

<a id="fw-p1-03"></a>

## FW-P1-03 — Additional CBQ Parser Families

**Status:** Candidate
**Depends on:** complete authentic CBQ evidence for one selected new or changed bank/card source-family contract

**Completed boundary:** The exact current-account XLS/history-PDF/monthly-PDF family is accepted under ADR-043 source lineage, and exact `cbq.credit-card.pdf@1` v1/v2 is accepted as a separate card family. The accepted unnumbered reset recertified the complete registered CBQ corpora and closed the July compatibility defect for that corpus.

**Remaining boundary:** Only new or materially changed CBQ bank/card layouts, formats or financial families remain. Bank and card domains stay independent. XLSX, OCR/image-only sources and any unapproved card equivalence or identity behavior require their own source and architecture authority.

The prohibited historical synthetic financial-source artifacts were retired by the accepted reset and are not remaining work.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No materially new CBQ family; absent transaction-history XLS remains uncertified.

**Smallest proposed boundary:** Register and project before credential/relationship decisions.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: exact current-account XLS/history/monthly PDFs and card PDF v1/v2 are distinct accepted domains.

**First-round scope and constraints:** VERIFIED_REPOSITORY: ADR-043 lineage is current-account-specific, ADR-044 is card-specific, ADR-046 requires semantic evidence/fail-closed ambiguity. No CBQ-wide support, generic XLSX/OCR or inferred cross-format suppression.

**First-round question/options:** Which materially new CBQ family should be investigated apart from certified current-account and card profiles? PROPOSED: choose actual family or defer; format adjacency is not evidence.

**First-round remainder and implications:** MISSING: selected format/layout/product, authentic corpus/oracle, account/card identity contract. Absent transaction-history XLS is uncertified, not fabricateable. No migration allocated; ADR-043/044 reuse needs relevance proof.

**First-round proposed acceptance/falsifier:** Complete corpus production gate, independent projection, family persistence/reopen and affected shared-corpus gate. Different identity, liability, format relationship or unlock behavior invalidates reuse.

**Second-round new evidence/resolved direction:** Current bank and card profiles are distinct.

**Exact next evidence or decision:** Family selection, corpus, source oracle and bank/card identity decision.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Candidate blocked on authentic source **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Family/domain change.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, IDENTITY, FINANCIAL_SEMANTICS, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-selected-cbq-family`: No authentic candidate.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-03`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. No materially new CBQ family; absent transaction-history XLS remains uncertified.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):605-616 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-03
- [Project documents/ADR.md](<ADR.md>):5126-5334 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-043
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):85-95,964-972 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Absent formats are uncertified.

</details>

---

<a id="fw-p1-04"></a>

## FW-P1-04 — Additional Credit-Card Parser Families

**Status:** Ready for discovery
**Depends on:** a selected remaining authentic card source family plus its exact liability, identity, reconciliation and source-format contract

**Completed boundary:** Exact Amex PDF, CBQ encrypted PDF v1/v2 and Axis PDF/XLSX families are accepted over the shared card-liability architecture, with current complete-corpus reliability certification under ADR-046. The shared domain does not create generic issuer support.

**Remaining boundary:** HDFC card, materially changed Amex/CBQ/Axis card layouts and every other issuer/layout remain separate source-family work. Discovery may compare authentic-source-backed candidates, but each requires independent posted-amount/currency/order/summary/identity truth, deterministic account-versus-instrument semantics, persistence/relaunch evidence and exact exclusions.

The accepted reset completed retirement of prohibited synthetic financial-source artifacts; no fixture-retirement task remains here.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No issuer/layout corpus or card account-versus-instrument decision.

**Smallest proposed boundary:** One card family discovery, not generic issuer support.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: shared card domain serves only exact Amex/CBQ/Axis profiles; readers/registry are reusable seams, finance remains profile-owned.

**First-round scope and constraints:** VERIFIED_REPOSITORY: ADR-044 separates card liabilities from bank semantics; ADR-027 gives identifiers to parsers; ADR-046 needs full authentic family evidence. No issuer-wide support, rewards, payments, refunds, installments, FX or fee inference.

**First-round question/options:** What is the smallest safe discovery shape for one new card family? PROPOSED: discover one supplied candidate or a known changed layout; generic card parser is unsupported.

**First-round remainder and implications:** MISSING: issuer/layout, complete originals, independent posted amount/currency/order/summary/identity truth, account-versus-instrument choice. No migration presumed; ADR only for new durable card semantic/identity.

**First-round proposed acceptance/falsifier:** Complete family, independent oracle, reconciliation, SQLite/In-Memory parity, zero-residue rejection, hydration/relaunch. Multiple instruments, changed liabilities, absent controls or incompatible identity reject shortcuts.

**Second-round new evidence/resolved direction:** Shared card architecture only serves exact profiles.

**Exact next evidence or decision:** Complete family with posted amount/currency/order/summary/identity oracle.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Ready only after authentic-family selection **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Liability/identity/reconciliation variance.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, IDENTITY, FINANCIAL_SEMANTICS, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-selected-card-family`: No family supplied.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-04`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. No issuer/layout corpus or card account-versus-instrument decision.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):618-629 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-04
- [Project documents/ADR.md](<ADR.md>):5335-5619 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-044
- [Parsers/StatementParserRegistry.swift](<../Parsers/StatementParserRegistry.swift>):1-47 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `05eef62bc9b7197975057a309d0b98922732e2cb9f5bb8df0b3c7e2986e53bdf` — StatementParserRegistry
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):974-990 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Exact card profiles only.

</details>

---

<a id="fw-p1-05"></a>

## FW-P1-05 — Additional Salary, Brokerage, Fund, Insurance, Tax and Government Document Families

**Status:** Research
**Depends on:** domain-model and product-scope decisions plus authentic source evidence for the selected financial family

**Completed boundary:** Sprint 79 accepted exact `qatar-airways.salary.pdf@1` salary actuals and the dedicated salary/funding-planner domain under ADR-045. That accepted employer/profile is no longer future work.

**Remaining boundary:** Other employers/payroll layouts, brokerage statements, mutual-fund statements, insurance documents, tax documents and government financial records remain separate research/source domains. No family may inherit support from the Qatar Airways salary profile or be forced into the bank/card transaction model merely for implementation convenience.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Omnibus salary/brokerage/fund/insurance/tax/government item has no selected domain or durable meaning.

**Smallest proposed boundary:** Split to one selected domain and decide events/holdings/planner/document/no-state.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P1-05 | **User product choice:** choose one new document domain, if any. | Salary, brokerage, fund, insurance, tax, and government documents have incompatible facts/models. | Defer omnibus expansion. | Select one domain/family and state intended outcome. | — | A unless a real recurring source is selected. | No new document support. | A source/oracle and one-domain architecture packet. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: only qatar-airways.salary.pdf@1 and its separate planner domain are accepted; the pipeline does not establish a universal model for these domains.

**First-round scope and constraints:** VERIFIED_REPOSITORY: ADR-045 is salary-specific; ADR-046 forbids forcing sources into bank/card models. No generic document library, valuation, tax calculation, government integration or new support.

**First-round question/options:** Can salary/brokerage/fund/insurance/tax/government documents be made one implementation-ready item? PROPOSED: split by one selected domain; defer omnibus campaign.

**First-round remainder and implications:** MISSING: selected domain/family, product scope, domain model, ownership/valuation/tax meaning and authentic corpus/oracle. Likely ADR review; no migration before durable-domain selection.

**First-round proposed acceptance/falsifier:** Independent source truth mapped to approved domain, complete corpus, parity/hydration and privacy-safe presentation. Units, benefits, tax or non-cash entitlement invalidate bank/card reuse.

**Second-round new evidence/resolved direction:** Only exact salary profile/domain is accepted.

**Exact next evidence or decision:** One selected domain, source corpus/oracle, and domain-state decision.

**Personal-v1:** POST_V1: no declared adoption requirement.

**Recommendation after Chat:** Split or defer **Roadmap:** No omnibus sprint

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Units/tax/benefit/ownership semantics.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, ARCHITECTURE_DECISION, USER_PRODUCT_DECISION.

**Typed dependencies:**

- `REQUIRES_USER_DECISION` → `decision-selected-document-domain`: Different domains have incompatible models.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-05`: Omnibus salary/brokerage/fund/insurance/tax/government item has no selected domain or durable meaning.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p1-05`: One selected document domain with authentic originals, source-controlled values/dates/identifiers and an independent domain-specific semantic oracle.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):631-640 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-05
- [Project documents/ADR.md](<ADR.md>):5700-5919 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-045
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):124-145,964-972 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Salary model is exact and separate.

</details>

---

<a id="fw-p1-06"></a>

## FW-P1-06 — Parser Framework Expansion

**Status:** Ready for planning
**Depends on:** Existing reader, parser-selection and `FinancialDocument` boundaries

**Narrow parser-authoritative profile-provenance slice completed 2026-07-23:** Sprint 53 makes the production persistence mapper consume exactly one nonempty profile ID/version pair produced by parser transaction provenance and fail before writes when it is missing, malformed or conflicting. Historical `axis.nre.csv` version `1` remains readable unchanged. Reusable profile architecture, broader CSV grammar, other layouts, formats and institutions remain open.

Expand the internal parser framework so additional institutions, statement families and layout versions can be added without creating parallel import pipelines.

The framework must implement the accepted Import Profile direction rather than scattering institution-specific assumptions across unrelated components.

Candidate outcomes include:

- reusable Import Profiles;
- Import Profile versioning;
- deterministic layout recognition that resolves mandatory semantic roles from unique, exact normalized headers rather than fixed column positions, and fails closed for missing, duplicate, ambiguous or unsupported roles;
- explicit support for historical and changed layouts;
- shared complete-authentic-corpus regression conventions plus separate non-source unit-test conventions, including independent source oracles that do not use the production parser as their sole authority;
- bounded source-evidence contracts;
- parser-family organization by institution and document type.

Remaining CSV-grammar gap: targeted discovery must define deterministic handling for quoted delimiters, escaped quotes, embedded line breaks, line-ending variants, empty fields and malformed records while preserving source-row evidence. The current framework and historical fixtures do not establish broader CSV grammar or production support; the affected authentic corpus must do so.

Readers remain responsible for source-format extraction.

Parsers remain responsible for financial interpretation.

This candidate concerns internal application architecture. External third-party plugins remain governed separately by `FW-P3-39`.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No selected source family or grammar defect proves existing registry/reader/parser seams insufficient.

**Smallest proposed boundary:** Ready-but-not-needed; assess only after concrete family selection.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: format registry, immutable snapshots, deterministic detection/classification, selector/registry and parser-produced profile provenance already form one pipeline.

**First-round scope and constraints:** VERIFIED_REPOSITORY: ADR-016/027/041/046 retain one pipeline, parser-owned identity/profile and adaptive deterministic interpretation. No parallel pipeline, generic support, plugin, parser rewrite or certification.

**First-round question/options:** Is new framework work required before another selected source family? PROPOSED: retain seams and extend narrowly for a proven gap; generic framework work requires deliberate architecture maintenance choice.

**First-round remainder and implications:** MISSING: a candidate proving existing seams cannot express semantic roles or broader CSV grammar; no family selected. No migration expected; ADR only if ownership changes.

**First-round proposed acceptance/falsifier:** Family proof plus full affected authentic corpora for shared changes; unit tests are supplementary. Materially different financial/identity semantics may justify another profile; shifted layout does not.

**Second-round new evidence/resolved direction:** Pipeline already has deterministic routing and profile provenance.

**Exact next evidence or decision:** Source-bounded case that cannot be expressed by existing seams.

**Personal-v1:** POST_V1: no current certification effect.

**Recommendation after Chat:** Ready for planning but not selected **Roadmap:** No standalone sprint

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Documented grammar limitation.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** NO_REAL_USE_CASE, DEPENDENCY.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `source-selected-new-family`: Future reopening condition only; this deferred boundary is not a current prerequisite. Framework work must be demand-led.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):642-671 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-06
- [Import/Readers/DefaultReaderRegistry.swift](<../Import/Readers/DefaultReaderRegistry.swift>):7-29 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `987d6cee9a010d2d72ca73b047d743e45f1c36eef5e72f65b5d76d44cd51f051` — DefaultReaderRegistry
- [Import/Coordinator/DefaultImportCoordinator.swift](<../Import/Coordinator/DefaultImportCoordinator.swift>):15-116 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `721387d0b8cde8125b30d58917cfd7047cf03213d55efb8a9fb8b043d5fe6e2e` — DefaultImportCoordinator
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):88-93 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Adaptive deterministic family parsers and shared pipeline are accepted.

</details>

<a id="packet-source-expansion-packet"></a>

<details>
<summary>SOURCE_EXPANSION_PACKET — complete proposed decision packet</summary>

## SOURCE_EXPANSION_PACKET

1. **Owning FW IDs:** FW-P1-01 through FW-P1-17, FW-P2-63, FW-P2-64, FW-P2-79,
FW-P3-16. This closes all current source expansion candidates as either
blocked by missing real source evidence or deliberately ready-but-not-needed.

2. **User problem:** add only genuinely useful source support without
   generalizing certified profiles.
3. **Verified current state:** the 127-carrier recertification covers exact
   registered Axis/HDFC/CBQ bank, specified card, and exact salary profiles;
   it does not certify newly named institutions, formats, layouts, zero
   activity, OCR, TXT, generic XLSX, or unselected relationships.
4. **Accepted authorities:** ADR-046 and current alignment require complete
   authentic corpus plus independent source oracle for family interpretation.
5. **Exact missing decision:** for every P1 expansion: select one recurring
   source family, its domain, and its intended product outcome.
6. **Evidence acquired:** no additional family was selected in the approved
   source inventory; framework seams already exist.
7. **Options considered:** generic parser/framework advance; select a concrete
   family; defer.
8. **Recommended option:** defer all unselected families; when desired,
   register exactly one family and its independent semantic projection first.
9. **Why competing options are rejected:** format/institution adjacency is not
   semantic source evidence, and shared architecture does not certify support.
10. **Smallest coherent implementation boundary:** exact family inventory → independent oracle
   projection → determine reader/profile reuse → implementation proposal.
11. **Included scope:** source-family selection and static reuse assessment.
12. **Explicit exclusions:** parser coding, corpus recertification, credential
   storage changes, OCR/AI/learning escalation, generic format claims.
13. **Durable model/persistence requirements:** none until family financial
   meaning and identity/relation requirements are accepted.
14. **Migration impact:** NONE presumed; a new durable card/document/identity
   relation is REQUIRES_DECISION, with no migration number allocated.
15. **ADR impact:** ALIGN_EXISTING with ADR-046; NEW_ADR_REQUIRED only for a
   new durable semantic/identity/equivalence/credential contract.
16. **Privacy/security boundary:** originals/oracles remain private/read-only;
   credential scope stays exact-family and no paths/values/credentials appear.
17. **SQLite/In-Memory implications:** future source import needs parity where
   it persists; this discovery has none.
18. **Hydration/relaunch implications:** future source truth must survive
   ordinary persistence/open/hydration; not tested here.
19. **Independent acceptance oracle:** pre-existing independently source-derived
   projection, not production-parser output, per selected authentic family.
20. **Failure cases:** missing/ambiguous source meaning, partial corpus,
   unsupported encryption, no selected domain, or relationship uncertainty
   fails closed with zero durable residue.
21. **Reversal/correction semantics:** not applicable before persistence;
   future durable relationship behavior requires separate review.
22. **Source evidence requirement:** mandatory for all statement-dependent P1
   candidates. FW-P2-64 separates nonfinancial resource mechanics from a real
   large-statement semantic gate.
23. **Runtime acceptance requirement:** only future normal import/unlock/UI
   acceptance; none claimed now.
24. **Dependencies:** concrete authentic family; independent oracle; identity
   decision for cards/relationships; credential policy if encrypted; FW-P0-19
   for durable cross-format effects.
25. **Evidence that falsifies the recommendation:** a selected family that existing deterministic
   seams cannot represent, or a complete oracle proving incompatibility.
26. **Personal-v1 relevance:** unselected families are PRE_V1_OPTIONAL; the
   support matrix is a PRE_V1_REQUIRED adoption input but not certification.
27. **Recommended FUTURE_WORK status after Chat review:** exact P1/P2-63 source blockers remain;
   FW-P1-06 becomes ready-but-not-needed; FW-P2-79 awaits doc writer window.
28. **Recommended roadmap effect after Chat review:** no source-expansion sprint; no generic
   framework sprint; source work must begin after a user selects a family.
**Additional decision detail:** for each desired expansion, supply one exact
   recurring family or defer it. Do not approve a generic family category.

**Compact ADR candidate — source-profile expansion trigger.**

- **Context:** current framework is already an adaptive deterministic pipeline,
  but no new family exposes a seam deficiency.
- **Decision:** no shared framework expansion before a selected authentic family
  demonstrably needs it; each family has a source/oracle/durable-effect packet.
- **Alternatives:** generic CSV/PDF/XLSX/OCR/AI expansion now; rejected as
  unsupported and incapable of certification.
- **Consequences:** prevents speculative migrations and credentials; shared
  changes still trigger all affected authentic-family regressions.
- **Acceptance:** a selected corpus, independent projection, deterministic
  routing, normal import and persistence/hydration gate.
- **Alignment:** ADR-046 exact-family and fail-closed requirements.

### Credential scope notes (no new architecture selected)

**Owning IDs:** FW-P1-11, FW-P1-12, FW-P1-13. Existing secure unlock and
institution-scoped Keychain reuse are limited to exact accepted encrypted
profiles. No actual new encrypted family, credential value, or user need was
provided. Therefore there is no generic credential-profile expansion to plan.
The irreducible order is: selected authentic encrypted family and independent
semantic oracle; explicit scope (use once, replace, or remember); rotation,
deletion and recovery policy; then a narrow family extension. A per-file
override cannot silently replace stored family scope. No credential, path, or
private source detail belongs in planning evidence. This is source/security
blocked, not a parser-framework prerequisite.

### Source relationship notes (no new equivalence accepted)

**Owning IDs:** FW-P1-16 and FW-P2-63. Accepted HDFC/Axis-card equivalence and
CBQ lineage, plus Axis-bank regression parity, are distinct contracts. The
latter does not establish durable duplicate suppression, authority replacement,
or a relationship for a new pair. Before any durable relationship proposal,
one complete new authentic representation pair must establish an independent
projection and declare whether its purpose is regression-only or durable. This
lane did not repeat integrity’s source search; the accepted indexed private
oracle/root chain may be reused later under its existing authority without
publishing locator or source details. FW-P0-19 remains the architecture owner
for duplicate/equivalence effects.

</details>

---

<a id="fw-p1-07"></a>

## FW-P1-07 — Statement Learning Mode and Profile Library

**Status:** Research
**Depends on:** `FW-P1-06`, approved Import Profile semantics and privacy boundaries

Investigate an offline-first workflow that helps LedgerForge recognize new or changed statement layouts while preserving deterministic parsing.

Candidate outcomes include:

- a versioned local Import Profile library;
- explicit profile provenance and compatibility information;
- user-reviewed profile creation or refinement;
- registration of authentic source evidence and independent oracle/projection metadata; synthetic financial-source fixture generation is prohibited at every stage;
- compatibility with historical layouts;
- rollback to an earlier profile version;
- clear separation between learned suggestions and production-approved parser behaviour.

Learning must never silently promote an unreviewed profile into trusted financial parsing.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Needs accepted profile semantics, source family, offline retention/reviewer/rollback policy.

**Smallest proposed boundary:** Versioned reviewed proposal metadata only; no automatic promotion.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: parser provenance exists but no profile library, review workflow, compatibility/rollback store or source-registration workflow exists.

**First-round scope and constraints:** VERIFIED_REPOSITORY: ADR-046 requires deterministic parser and authentic input; ADR-017 makes AI non-authority. No autonomous learning, cloud collection, raw statement retention, automatic promotion or new support.

**First-round question/options:** Can offline statement learning/profile library be safely specified now? PROPOSED: defer, or a local proposal record with no production routing.

**First-round remainder and implications:** MISSING: FW-P1-06 approved profile semantics, ownership/privacy/retention, reviewer role and source family. Likely ADR; no migration presumed.

**First-round proposed acceptance/falsifier:** Proposal/review/reject/rollback privacy proof, then independent full-corpus parser proof. Trusted finance from mapping alone, indefinite raw retention or bypassed validation is invalid.

**Second-round new evidence/resolved direction:** No profile-library contract exists.

**Exact next evidence or decision:** Accepted FW-P1-06 need plus selected authentic family.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Research blocked by framework need **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Any retained source/private mapping.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** DEPENDENCY, PRIVACY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-selected-new-family`: Only a selected genuine family can establish need; current parser framework is not a generic prerequisite.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-source-privacy-review`: Any selected assistance/profile retention and review boundary needs its own direct privacy/source contract.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-07`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Needs accepted profile semantics, source family, offline retention/reviewer/rollback policy.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):673-692 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-07
- [Project documents/ADR.md](<ADR.md>):5960-6062 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-046
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):642-671 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Framework is source-bound.

</details>

---

<a id="fw-p1-08"></a>

## FW-P1-08 — AI-Assisted Column Detection

**Status:** Research
**Depends on:** `FW-P1-06`, editable import provenance and deterministic validation boundaries

Investigate AI-assisted suggestions for identifying dates, descriptions, debit, credit, amount, currency and balance columns in unsupported tabular statements.

Any assistance must remain:

- advisory;
- reviewable;
- explainable;
- local or explicitly opt-in where external processing would be required;
- validated before persistence;
- unable to override approved deterministic parser behaviour.

The original source structure and every user-approved mapping must remain inspectable.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** No unsupported authentic table or approved local/opt-in/review contract.

**Smallest proposed boundary:** Reviewable hypotheses only, validated or rejected deterministically.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: deterministic detector/classifier/parser stages exist; no Vision/CoreML/OCR/LLM implementation found.

**First-round scope and constraints:** VERIFIED_REPOSITORY: ADR-017 AI never replaces parsing/validation; ADR-046 model analysis is not financial authority and external source use needs approval. No automatic detection, upload, parser replacement, financial authority or silent persistence.

**First-round question/options:** What safe role can AI-assisted column detection have? PROPOSED: no AI, local advisory, or separately consented external advisory.

**First-round remainder and implications:** MISSING: local/opt-in boundary, editable provenance, review UX, unsupported authentic table and validation contract. ADR needed before durable mappings; migration unknown.

**First-round proposed acceptance/falsifier:** Refusal of invalid mappings, provenance visibility, consent/no leakage, authentic-corpus proof for promoted parser. Suggestion confidence as financial evidence or default external processing conflicts with ADR-017/046.

**Second-round new evidence/resolved direction:** AI cannot be financial authority.

**Exact next evidence or decision:** Selected unsupported family and deterministic validation boundary.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Research **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Remote processing/retained mappings.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** DEPENDENCY, PRIVACY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-selected-new-family`: Only a selected genuine family can establish need; current parser framework is not a generic prerequisite.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-source-privacy-review`: Any selected assistance/profile retention and review boundary needs its own direct privacy/source contract.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-08`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. No unsupported authentic table or approved local/opt-in/review contract.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):694-712 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-08
- [Project documents/ADR.md](<ADR.md>):553-593 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-017
- [Detectors/SignatureInstitutionDetector.swift](<../Detectors/SignatureInstitutionDetector.swift>):1-240 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `07b6a62efc1f2913f064f894d0b7731d9495aef70dd003f2a76561397097acf0` — SignatureInstitutionDetector
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):88-93 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Semantic parser remains authority.

</details>

---

<a id="fw-p1-09"></a>

## FW-P1-09 — Remaining Credit-Card Financial Semantics

**Status:** Candidate
**Depends on:** exact authentic source evidence and accepted architecture for the selected additional card semantic

**Completed boundary:** The accepted Amex, CBQ and Axis card profiles already preserve card-liability effects, account/instrument boundaries where source-proven, exact source observations, family reconciliation, provider-owned persistence and hydration. The July CBQ compatibility defect is closed for the registered corpus by the accepted reset. Axis representation equivalence remains governed by ADR-044.

**Remaining boundary:** Rewards, payment allocation, bank-card payment matching, refund/reversal matching, installments/loans, calculated FX, fee/markup/tax contracts, manual merge/split and any new card semantic remain separate future work. Axis Active-Loans/EMI metadata remains excluded from historical card transactions unless later authentic evidence and architecture prove a dedicated model.

Card-liability effects remain distinct from bank debit/credit semantics. Missing rates, taxes, fees or ownership evidence remain missing rather than inferred.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No chosen card semantic or authentic evidence establishes durable meaning.

**Smallest proposed boundary:** Map one semantic before implementation.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: exact profiles preserve liabilities/observations/reconciliation; rewards, payments, refund matching, installments, FX, fee/tax inference and merge/split remain excluded.

**First-round scope and constraints:** VERIFIED_REPOSITORY: liability effects differ from bank direction; absent rates/fees/ownership remain missing. No rates/taxes/fees inference, generic payment matching, merge/split or backfill.

**First-round question/options:** Which remaining card semantic deserves discovery? PROPOSED: select one semantic with direct source controls; retain others separately.

**First-round remainder and implications:** MISSING: one semantic, authentic evidence and accepted durable meaning; no priority/source selects one. Likely ADR/migration review if durable semantic selected.

**First-round proposed acceptance/falsifier:** Independent oracle, reconciliation, provider atomicity/zero residue, hydration/relaunch and corpus. Ambiguous allocation/absent ownership/incomplete controls block persistence.

**Second-round new evidence/resolved direction:** Unimplemented card semantics remain explicitly excluded.

**Exact next evidence or decision:** One selected semantic with source controls and unavailable-value policy.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve queue priority/status; explicitly defer until a real selected source or product workflow demonstrates need. See bounded decision queue. **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Summary/identity/reversal variance.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** SOURCE_TRUTH, FINANCIAL_SEMANTICS, NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `decision-card-semantic`: Future reopening condition only; this deferred boundary is not a current prerequisite. Unselected future scope only; no current user decision is pending for the deferred boundary.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):714-727 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-09
- [Project documents/ADR.md](<ADR.md>):5480-5619 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-044
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):984-988 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No inferred extra semantics.

</details>

---

<a id="fw-p1-10"></a>

## FW-P1-10 — Additional Native-Text PDF Statement Families

**Status:** Candidate
**Depends on:** complete authentic evidence for one selected new or changed native-text PDF financial source family

**Completed boundary:** Existing accepted PDF profiles across current Axis, HDFC, CBQ, Amex and Qatar salary families are recorded in `PROJECT_STATE.md` and currently certified against their registered authentic corpora under ADR-046.

**Remaining boundary:** Only new or materially changed native-text PDF families not already covered by accepted source contracts remain here. Encrypted credential policy remains under `FW-P1-11` through `FW-P1-13`; OCR/image-only sources remain under `FW-P1-17`; cross-format identity/equivalence remains under `FW-P0-19` and `FW-P1-16`.

No generic PDF support claim is authorized.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No exact new native-text PDF family/corpus/oracle.

**Smallest proposed boundary:** Registration before parser choice.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: PDF reader preserves page/text/positioned/resource/tagged evidence; accepted families are exact-profile bounded.

**First-round scope and constraints:** VERIFIED_REPOSITORY: ADR-046 gives financial interpretation to parsers and forbids generic-PDF claims. No arbitrary PDF, OCR, generic encryption or automatic equivalence.

**First-round question/options:** Which additional native-text PDF family should be supported? PROPOSED: select one source, compare reader evidence, then add family parser only if controls cohere.

**First-round remainder and implications:** MISSING: exact recurring native-text PDF family, originals/oracle and proof existing extraction suffices. No migration assumed; ADR-046 governs reader reuse.

**First-round proposed acceptance/falsifier:** Complete PDF intake, independent projection, validation/reconciliation, parity/hydration. Image-only, ambiguity or reader resource failure needs separate approved extraction.

**Second-round new evidence/resolved direction:** Native text alone is not support evidence.

**Exact next evidence or decision:** Family corpus and extraction sufficiency assessment.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Candidate blocked on authentic source **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Encrypted/image-only/semantic difference.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-selected-pdf-family`: No family.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-10`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. No exact new native-text PDF family/corpus/oracle.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):729-740 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-10
- [Import/Readers/PDFDocumentReader.swift](<../Import/Readers/PDFDocumentReader.swift>):1-110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `10a0b4760f54715879c2b5c6c6de85371f0fd18926e1c49f511bbecb8909d6a3` — PDFDocumentReader
- [Import/Models/RawDocument.swift](<../Import/Models/RawDocument.swift>):152-205 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `50a482464188c8c07d7bbce51a0da1f35fd968ff6c9265b2f88dfe24f71df645` — RawDocument
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):964-972 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Generic PDF is unsupported.

</details>

---

<a id="fw-p1-11"></a>

## FW-P1-11 — Additional Password-Protected PDF Families

**Status:** Candidate
**Depends on:** an authentic encrypted source family whose credential scope and supported profile can be proven exactly

**Completed boundary:** The shared immutable-snapshot unlock flow is accepted for the exact encrypted Amex, CBQ and Axis credit-card PDF families, including separate Axis App/traditional credential scopes.

**Remaining boundary:** Other institutions or materially changed encrypted layouts require separate exact source, credential-family and parser acceptance. Arbitrary encrypted PDFs, owner-password/permissions variants, OCR and generic encrypted-document support are not implied.

Readers remain credential-policy agnostic and must not own UI, Keychain or institution semantics.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No authentic encrypted family or chosen credential scope.

**Smallest proposed boundary:** Prove unlock/semantic path before adding one Keychain target.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: coordinator tries uncredentialed read, bounded candidates, then challenge; credential saves only after supported parse/validation target.

**First-round scope and constraints:** VERIFIED_REPOSITORY: reader credential-agnostic; no secret in SQLite/evidence/diagnostics; exact scopes only. No arbitrary encrypted PDFs, owner-password variants, generic scan or OCR.

**First-round question/options:** Can secure unlock be reused for another encrypted family? PROPOSED: reuse orchestration after proof, add explicit scope, or defer.

**First-round remainder and implications:** MISSING: authentic encrypted family, scope/persistence target and supported semantic proof. No migration; ADR-015 amendment only for new scope semantics.

**First-round proposed acceptance/falsifier:** Complete corpus, wrong/cancel/unsupported paths, delayed persistence, zero residue, privacy inspection. Ambiguous reuse, path inference or save before supported parse violates boundary.

**Second-round new evidence/resolved direction:** Existing Keychain scopes are exact-family only.

**Exact next evidence or decision:** Encrypted corpus, independent oracle, unlock and lifecycle policy.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Candidate blocked on authentic source **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Credential persistence/sync changes.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, SECURITY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-selected-encrypted-family`: No source.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-credential-scope`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Scope and retention.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):742-753 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-11
- [Import/Coordinator/DefaultImportCoordinator.swift](<../Import/Coordinator/DefaultImportCoordinator.swift>):85-116 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `721387d0b8cde8125b30d58917cfd7047cf03213d55efb8a9fb8b043d5fe6e2e` — readPasswordProtectedPDF
- [Import/Password/DefaultPasswordProvider.swift](<../Import/Password/DefaultPasswordProvider.swift>):334-436 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `de4f93cdfc8c9fdf2d8cf23d4127f649ae05608be2806964812d00e567b43215` — DefaultPasswordProvider
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):968-971 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Arbitrary encrypted PDFs unsupported.

</details>

---

<a id="fw-p1-12"></a>

## FW-P1-12 — Additional Credential Profile and Password-Storage Capabilities

**Status:** Research
**Depends on:** an approved product need beyond the accepted exact Keychain credential-family boundary

**Completed boundary:** Namespaced macOS Keychain storage is accepted for the proven Amex, CBQ and separate Axis credit-card credential families, with persistence only after supported-profile unlock/parse/validation and no password material in SQLite, source evidence or diagnostics.

**Remaining boundary:** Generic credential-profile lifecycle, password-pattern derivation or any broader credential product is not currently approved. Optional cloud/sync behavior, if ever selected, remains separately governed by the later encryption/sync architecture rather than being implied by current Keychain support.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No source requires a new credential profile or lifecycle policy.

**Smallest proposed boundary:** One-family extension only; preserve no-sync deferred write.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: non-synchronizing namespaced Keychain scopes and bounded legacy Axis compatibility exist; no generic profile/pattern lifecycle.

**First-round scope and constraints:** VERIFIED_REPOSITORY: secrets never persist as finance/evidence/diagnostics; candidates bounded; scope follows exact proof. No pattern derivation, cloud/sync, bulk Keychain management or generic secrets product.

**First-round question/options:** Is generic credential-profile lifecycle needed beyond exact Keychain scopes? PROPOSED: retain exact scopes; add one explicit scope if source proves need; generic profiles need product/security decision.

**First-round remainder and implications:** MISSING: user need, rotation/deletion/recovery policy and a new source needing a scope. No DB migration; ADR-015 may need lifecycle amendment.

**First-round proposed acceptance/falsifier:** Scope save/replace/delete/rejection privacy tests and family corpus proof. Unbounded scan, ambiguous scope, path inference or secret persistence invalidates proposal.

**Second-round new evidence/resolved direction:** Exact institution-scoped Keychain reuse exists.

**Exact next evidence or decision:** Concrete family plus rotation/deletion/recovery decision.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve queue priority/status; explicitly defer until a real selected source or product workflow demonstrates need. See bounded decision queue. **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Cloud/sync or recovery request.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** SECURITY, NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `FW-P1-11`: Future reopening condition only; this deferred boundary is not a current prerequisite. Real encrypted source is prerequisite.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):755-764 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-12
- [Import/Password/DefaultPasswordProvider.swift](<../Import/Password/DefaultPasswordProvider.swift>):13-215 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `de4f93cdfc8c9fdf2d8cf23d4127f649ae05608be2806964812d00e567b43215` — KeychainStatementPasswordCredentialStore
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):968-971 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Exact scopes only.

</details>

---

<a id="fw-p1-13"></a>

## FW-P1-13 — Additional Per-File Credential Override Policy

**Status:** Candidate
**Depends on:** an explicit user/product decision for a non-persistent or per-file override beyond the accepted remembered-family challenge flow

**Completed boundary:** Exact supported encrypted PDF families already provide secure user challenge and safe replacement of the proven credential-family item only after successful unlock, supported parsing and validation.

**Remaining boundary:** A use-once/non-persistent credential choice and any genuinely different per-file override semantics remain unimplemented. Cancellation, failed candidates and unsupported unlocked content must never persist a credential.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** Use-once, replace, remember and rotation semantics are not chosen.

**Smallest proposed boundary:** Per-request persistence choice after supported-target selection.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: candidates are request-staged; after parse/validation, target scope persistence occurs; cancel/failed/unsupported discards staging.

**First-round scope and constraints:** VERIFIED_REPOSITORY: accepted remembered-family flow; bytes unlocking alone never persist secret. No persistence on cancel/fail/unsupported, per-file durable identity or generic credentials.

**First-round question/options:** Should per-file passwords be remembered, use-once, or replace stored family scope? PROPOSED: preserve default, add explicit use-once, or add replace-scope choice.

**First-round remainder and implications:** MISSING: user decision on use-once versus replace, and scope rotation semantics. No migration; ADR-015 alignment if semantics change.

**First-round proposed acceptance/falsifier:** All save/discard choices, wrong/cancel rejection, no leakage, scope isolation. Pre-validation save or filename/path scope choice is invalid.

**Second-round new evidence/resolved direction:** No generic override policy follows from current scopes.

**Exact next evidence or decision:** Explicit choice for a supported target.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve queue priority/status; explicitly defer until a real selected source or product workflow demonstrates need. See bounded decision queue. **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Retention/sync behavior.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** SECURITY, NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `decision-credential-lifecycle`: Future reopening condition only; this deferred boundary is not a current prerequisite. Unselected future scope only; no current user decision is pending for the deferred boundary.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):766-775 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-13
- [Import/Password/DefaultPasswordProvider.swift](<../Import/Password/DefaultPasswordProvider.swift>):318-332 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `de4f93cdfc8c9fdf2d8cf23d4127f649ae05608be2806964812d00e567b43215` — StatementPasswordSessionVault
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):968-971 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Existing reuse is bounded.

</details>

---

<a id="fw-p1-14"></a>

## FW-P1-14 — Additional XLS/XLSX Source Families and Spreadsheet Capabilities

**Status:** Candidate
**Depends on:** complete authentic evidence for one selected additional spreadsheet family or an independently approved broader spreadsheet capability

**Completed boundary:** Accepted spreadsheet support already covers the exact Axis bank XLS, HDFC bank XLS, CBQ current-account XLS and Axis-card XLSX source contracts through the ordinary import path. The accepted 127-carrier reset recertified the registered families under ADR-046.

**Remaining boundary:** Other spreadsheet source families, new HDFC/CBQ/Axis layouts, generic OOXML mapping, formulas, macros, password workflows, unsupported worksheet structures and user-authored mappings remain separate work. Existing readers do not imply generic XLS or XLSX support.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No selected workbook/sheet/formula/macro/encryption contract or oracle.

**Smallest proposed boundary:** One worksheet/family with explicit resource and role evidence.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: registry includes Legacy XLS/OOXML; OOXML has explicit resource limits. Accepted sources are exact Axis/HDFC/CBQ XLS and Axis-card XLSX.

**First-round scope and constraints:** VERIFIED_REPOSITORY: reader preserves extraction, parser owns finance; generic OOXML/formula/macro/password mapping remains unsupported. No generic OOXML, formula execution, macros, authoring, generic password or certification.

**First-round question/options:** Does a new spreadsheet source require reader capability or profile/parser only? PROPOSED: select one workbook, assess reader output, add reader only for proven gap.

**First-round remainder and implications:** MISSING: selected workbook, sheet/formula/macro/encryption characteristics, independent oracle and user-mapping decision. No migration; shared reader change triggers full affected corpora.

**First-round proposed acceptance/falsifier:** Complete family, resource error behavior, parity/hydration and affected regression if reader changes. Formula finance, macros, ambiguous sheet or resource failure are not support evidence.

**Second-round new evidence/resolved direction:** Generic XLSX is unsupported despite exact profiles.

**Exact next evidence or decision:** One authentic workbook family and semantic role projection.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Candidate blocked on authentic source **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Reader shared change.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-selected-spreadsheet-family`: No workbook.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-14`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. No selected workbook/sheet/formula/macro/encryption contract or oracle.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):777-786 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-14
- [Import/Readers/DefaultReaderRegistry.swift](<../Import/Readers/DefaultReaderRegistry.swift>):7-29 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `987d6cee9a010d2d72ca73b047d743e45f1c36eef5e72f65b5d76d44cd51f051` — DefaultReaderRegistry
- [Import/Readers/OOXMLDocumentReader.swift](<../Import/Readers/OOXMLDocumentReader.swift>):58-69 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `1f3056f59ec351b4a8e9e2cbe4533cd405ac3dd37fc269a8587cf773d8e88ae5` — OOXMLReaderLimits
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):968-970 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Generic XLSX unsupported.

</details>

---

<a id="fw-p1-15"></a>

## FW-P1-15 — TXT Statement Support

**Status:** Idea
**Depends on:** Supplied authentic TXT financial sources and an independently derived source-truth/semantic-projection boundary

Support deterministic text statements through the existing pipeline.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No authentic TXT family, encoding/record contract or oracle.

**Smallest proposed boundary:** Extraction/semantic discovery before code choice.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: ADR-016 names TXT as future convergence; registry has no TXT reader/profile/authentic source.

**First-round scope and constraints:** VERIFIED_REPOSITORY: text extraction alone does not establish finance; ADR-046 needs source controls/oracle/complete corpus. No generic text finance, copied CSV behavior, OCR or fabricated samples.

**First-round question/options:** Can TXT statements use existing pipeline? PROPOSED: wait for source then add narrow reader/family parser if warranted.

**First-round remainder and implications:** MISSING: authentic TXT source, encoding/record semantics, source truth/projection, institution/family. No migration; reader addition has ADR-046 regression effects.

**First-round proposed acceptance/falsifier:** Complete corpus ordinary path and authentic source-based rejection cases. Ambiguous free text or absent controls/identity/direction blocks support.

**Second-round new evidence/resolved direction:** TXT is not production-supported.

**Exact next evidence or decision:** One family and independent projection.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Idea blocked on authentic source **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Encoding/record/financial roles.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-selected-txt-family`: No source.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-15`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. No authentic TXT family, encoding/record contract or oracle.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):788-795 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-15
- [Import/Readers/DefaultReaderRegistry.swift](<../Import/Readers/DefaultReaderRegistry.swift>):7-29 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `987d6cee9a010d2d72ca73b047d743e45f1c36eef5e72f65b5d76d44cd51f051` — DefaultReaderRegistry
- [Project documents/ADR.md](<ADR.md>):475-551 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-016
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):968-970 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — TXT unsupported.

</details>

---

<a id="fw-p1-16"></a>

## FW-P1-16 — Additional Cross-Format Financial Relationships

**Status:** Blocked
**Depends on:** one exact unimplemented representation relationship with complete authentic source truth and an accepted family-specific equivalence/lineage contract

**Completed boundary:** ADR-042 owns exact HDFC whole-statement PDF/XLS equivalence. ADR-043 owns the separate exact CBQ current-account lineage model. ADR-044 owns exact Axis credit-card PDF/XLSX representation equivalence. The accepted reset additionally establishes format-neutral semantic parity across the registered Axis-bank carriers as engineering evidence.

**Remaining boundary:** Axis-bank durable cross-format duplicate/equivalence behavior is not accepted merely because semantic parity tests pass. Additional card/format families, same-format equivalence, generic partial overlap, source replacement and every other representation relationship require separate source and architecture approval.

This item concerns source-family financial relationships, while `FW-P0-19` owns durable duplicate-identity consequences. Neither authorizes fuzzy matching.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No unimplemented paired relationship with authentic proof and accepted equivalence/lineage semantics.

**Smallest proposed boundary:** One family relationship contract, separate from duplicate repair.

**Decision record:** [TRANSFER_FAMILY_DECISION_PACKET](#packet-transfer-family-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: exact HDFC equivalence, CBQ lineage and Axis-card equivalence are accepted. Axis-bank parity is engineering evidence only.

**First-round scope and constraints:** VERIFIED_REPOSITORY: bytes identity differs from family-specific equivalence; no fuzzy matching; independent projection required. No generic matching, fuzzy same-format, partial overlap, replacement or Axis-bank suppression.

**First-round question/options:** Does existing parity establish new durable source relationship? PROPOSED: keep blocked; select relationship then decide lineage/equivalence before durable effect.

**First-round remainder and implications:** MISSING: one unimplemented relationship with authentic source truth and accepted equivalence/lineage contract. Likely ADR; migration unknown.

**First-round proposed acceptance/falsifier:** Complete pairs, mismatch zero residue, authoritative/supporting persistence, parity/reopen. Missing semantic dimension, multiplicity/order ambiguity or engineering parity alone is insufficient.

**Second-round new evidence/resolved direction:** Axis-bank engineering parity is not durable equivalence.

**Exact next evidence or decision:** Complete pair, independent projection, declared test-only versus durable effect.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Blocked **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Partial/revised/overlap source.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, IDENTITY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-19`: Durable relation semantics.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-new-representation-pair`: No pair.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):797-808 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-16
- [Project documents/ADR.md](<ADR.md>):4769-5619 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-041/042/043/044
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):570-580 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Parity and durable equivalence differ.

</details>

---

<a id="fw-p1-17"></a>

## FW-P1-17 — OCR Fallback

**Status:** Research
**Depends on:** Production PDF support and approved human-review boundaries

Investigate scanned or image-only statements.

OCR output remains untrusted until deterministic parsing and validation succeed.


**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No genuine image-only family or local/consented OCR/review contract.

**Smallest proposed boundary:** Decide privacy and one family; parser validates all OCR output.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: no OCR engine; PDF reader preserves resource/page evidence, parser decides whether other extraction is needed.

**First-round scope and constraints:** VERIFIED_REPOSITORY: ADR-017 OCR/AI remains advisory; ADR-046 requires approved extraction, authentic corpus and fail-closed ambiguity. No automatic acceptance, AI authority, generic image-PDF support, default upload or invented scans.

**First-round question/options:** Can OCR fallback support image-only statements? PROPOSED: defer, local reviewable OCR, or consented external OCR.

**First-round remainder and implications:** MISSING: genuine image-only family, local/consented processing decision, review boundary, parser controls and oracle. Likely ADR; no migration presumed.

**First-round proposed acceptance/falsifier:** Consent/provenance, reject ambiguity, no leakage, complete family acceptance. OCR text without controls, default external processing or automatic repair blocks proposal.

**Second-round new evidence/resolved direction:** OCR is not production-supported.

**Exact next evidence or decision:** Authentic corpus/oracle and approved untrusted OCR boundary.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Research blocked on source **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Remote processing or semantic ambiguity.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, PRIVACY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-selected-image-only-family`: No source.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-17`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. No genuine image-only family or local/consented OCR/review contract.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):810-817 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-17
- [Import/Readers/PDFDocumentReader.swift](<../Import/Readers/PDFDocumentReader.swift>):1-110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `10a0b4760f54715879c2b5c6c6de85371f0fd18926e1c49f511bbecb8909d6a3` — PDFDocumentReader
- [Project documents/ADR.md](<ADR.md>):5984-6014 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-046 reader responsibility
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):968-970 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — OCR unsupported.

</details>

---

<a id="fw-p1-22"></a>

## FW-P1-22 — Editable Import Preview

**Status:** Blocked
**Depends on:** An approved correction and provenance model

Allow bounded correction before persistence without obscuring the distinction between:

- imported source values;
- normalized values;
- user corrections;
- derived financial values.

Every correction must remain explainable and auditable.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Chat-approved correction authority and representation/revalidation/audit rules absent.

**Smallest proposed boundary:** Architecture-only correction record.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: confirmation persists parser-derived templates; no correction layer/provenance exists.

**First-round scope and constraints:** Every correction explainable/auditable; ADR-046 forbids fabricated statements/statement-shaped graphs as proof. No parser rewrite, financial-value mutation or source alteration.

**First-round question/options:** Permit editable preview without obscuring source/normalized/corrected/derived values. PROPOSED one correction type after immutable source/normalization provenance is designed.

**First-round remainder and implications:** EXPLICIT_USER_DECISION correction authority, representation, downstream revalidation and audit retention. Likely additive correction/audit relation, unallocated.

**First-round proposed acceptance/falsifier:** Original values remain recoverable; correction revalidates before persistence; unsupported edit fails closed. Any design making corrected output indistinguishable from source.

**Second-round new evidence/resolved direction:** None.

**Exact next evidence or decision:** Chat-approved correction authority, representation/revalidation/audit contract and a genuine source case with independently proved corrected meaning.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve queue status; named Chat-owned source/privacy/financial family decision remains before implementation planning. **Roadmap:** No change

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** source correction authority.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** MUTATION_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-chat-correction-authority`: Chat-approved correction authority and representation/revalidation/audit rules absent.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p1-22`: An authentic statement whose specific interpretation requires the proposed correction, its unchanged original bytes and an independent source projection proving corrected financial meaning.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):855-867 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-22
- [Project documents/ADR.md](<ADR.md>):3451-3462 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — trusted history correction is unapproved

</details>

---

<a id="fw-p1-23"></a>

## FW-P1-23 — Import Correction Workflow

**Status:** Blocked
**Depends on:** `FW-P1-22` and durable correction provenance

Provide deterministic correction and revalidation before persistence.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** FW-P1-22 correction authority absent.

**Smallest proposed boundary:** No implementation beyond dependency mapping.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: no correction workflow exists.

**First-round scope and constraints:** Must build on FW-P1-22 durable provenance and retain ordinary validation/confirmation authority. No arbitrary editable import or historical edits.

**First-round question/options:** Run deterministic correction/revalidation before persistence. PROPOSED narrow single correction action only after model acceptance.

**First-round remainder and implications:** FW-P1-22 decision and exact correction semantics. Follows selected correction record.

**First-round proposed acceptance/falsifier:** Deterministic replay gives same result; invalid corrections reject with zero accepted residue. Correction changes financial meaning without independent validation.

**Second-round new evidence/resolved direction:** None.

**Exact next evidence or decision:** Approved correction model.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** No change

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** correction model.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** MUTATION_SEMANTICS, PROVENANCE, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P1-22`: Chat owns this financial/privacy/architecture decision; it is not a technical questionnaire for the user.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p1-23`: The authentic source and accepted-import records for the selected correction case, plus independent before/after native amounts, dates, identity and provenance impact.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):871-876 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-23
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):1012-1024 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — correction is separate

</details>

---

<a id="fw-p1-24"></a>

## FW-P1-24 — Account-Match Review and Manual Override

**Status:** Blocked
**Depends on:** Identity explanation and manual linking policies

Extend account choice beyond the bounded no-match workflow while preserving verified identity ownership and explicit user control.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Manual linking policy is absent.

**Smallest proposed boundary:** Explanation surface only.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: noMatch needs explicit eligible choice; identity conflicts reject in transaction.

**First-round scope and constraints:** Verified ownership and explicit user control; no metadata/filename-based identity. No conflict override, identifier reassignment or auto-match.

**First-round question/options:** Extend account review/override beyond noMatch. PROPOSED present evidence-only review before override.

**First-round remainder and implications:** Identity explanation and manual-linking policy. No migration for presentation; mutation impact unknown.

**First-round proposed acceptance/falsifier:** Stale/ambiguous choice rejects inside provider; UI reveals bounded evidence only. Required decision rests on weak identity evidence.

**Second-round new evidence/resolved direction:** None.

**Exact next evidence or decision:** FW-P0-11 decision.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** No change

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** identity policy.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** IDENTITY, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-11`: Chat owns this financial/privacy/architecture decision; it is not a technical questionnaire for the user.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):880-885 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-24
- [Database/SQLiteConfirmedImportRepository.swift](<../Database/SQLiteConfirmedImportRepository.swift>):207-224 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `94798b9f38227067b2973fdcce07d5d41d8636726849eaac6037aef7470cf8e2` — account choice
- [Project documents/ADR.md](<ADR.md>):3476-3495 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — identity must be preserved

</details>

---

<a id="fw-p1-25"></a>

## FW-P1-25 — Duplicate-Import Review and Management

**Status:** Ready for discovery
**Depends on:** Approved durable-attempt-history supported outcomes plus broader duplicate-management semantics

Retain future work for duplicate override, broader duplicate management, partial-import families, ambiguous or speculative duplicate candidates and historical duplicate repair. The former Sprint 56 contiguous-prefix/later-suffix Axis family is suspended because its synthetic overlap fixture lacks immutable source lineage; mixed overlap now fails closed as unsupported evidence.

ADR-040 and Migration V7 retain the implemented reviewed-plan, transaction, durable-disposition and hydration structures, including strict readback of any historical state. Reauthorizing a production partial family requires new immutable source lineage and independent balance/event evidence; no current synthetic fixture can supply that authority. Retain arbitrary override, fuzzy candidates, interleaved or unsupported evidence, other institutions/formats/event families, historical duplicate cleanup and repair, and deletion/reversal for separate architecture and acceptance.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Chat must approve durable-attempt-history outcomes for read-only duplicate review; no repair is included.

**Smallest proposed boundary:** Read-only prior-import evidence review.

**Decision record:** [TRANSFER_FAMILY_DECISION_PACKET](#packet-transfer-family-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: exact duplicates are recorded/rejected; supporting equivalence is bounded; synthetic Axis mixed overlap is suspended and fails closed.

**First-round scope and constraints:** No arbitrary override/fuzzy/interleaved family; reauthorization needs immutable lineage and independent balance/event proof. No override, deletion/reversal, partial or historical repair.

**First-round question/options:** What remains of duplicate-import management after supported prevention? PROPOSED reuse exact-duplicate review first; do not revive partial family.

**First-round remainder and implications:** Approved durable-attempt-history outcomes plus selected management family. Existing V7 readable; no new migration justified.

**First-round proposed acceptance/falsifier:** Exact duplicate links prior import; unsupported overlap has zero accepted residue. Use of synthetic fixture or non-lineage source.

**Second-round new evidence/resolved direction:** Existing exact duplicate rejection is distinct from historical repair and from ambiguous candidates.

**Exact next evidence or decision:** Existing exact duplicate history and selected review semantics.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY after Chat accepts architecture: exact post-Sprint-87 ownership delta, any authentic acceptance source and explicit execution prompt still required. **Roadmap:** Reevaluate before reconciliation

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** new duplicate relation authority.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** PROVENANCE, MUTATION_SEMANTICS, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `FW-P0-02`: only if later historical repair selected
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-25`: Chat must approve durable-attempt-history outcomes for read-only duplicate review; no repair is included.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):889-896 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-25
- [Project documents/ADR.md](<ADR.md>):4720-4770 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-040
- [Services/ImportPersistenceCoordinator.swift](<../Services/ImportPersistenceCoordinator.swift>):1845-1862 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — outcomes are distinct

</details>

---

<a id="fw-p1-27"></a>

## FW-P1-27 — Delete or Reverse an Import Session

**Status:** Ready for discovery
**Shared prerequisites:** ADR-037 acceptance and post-Sprint-45 lifecycle revalidation are complete.
**Implementation dependency:** Selection and approval of one import-session reversal family contract and exact impact preview.

Safely reverse one accepted import without damaging unrelated account history.

Targeted discovery must define:

- the exact session-owned records and shared relationships;
- treatment of accounts, identifiers, observations, documents, fingerprints and overlapping transactions;
- native-currency impact;
- effect on later imports and account presentation;
- immutable reviewed plan and authorization;
- one provider-owned atomic operation;
- successful audit evidence;
- reversal of the reversal, compensation or explicit irreversibility;
- provider parity, hydration and relaunch behavior.

Discovery does not authorize deletion, broad rollback or backup-based undo.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Chat must select one import-session reversal family and inverse/irreversibility rule.

**Smallest proposed boundary:** Read-only reversal-impact verifier.

**Decision record:** [CHAT_DECISION_PACKET](#packet-chat-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: import commit atomically creates a graph but no inverse/reversal entry point exists.

**First-round scope and constraints:** Session ownership must account for accounts, identifiers, observations, documents, fingerprints, overlapping/supporting transactions and later imports; backup is not reversal. No delete button, broad rollback, backup undo, or derived ‘session-owned’ assumption.

**First-round question/options:** Reverse one accepted import session atomically without harming related history. PROPOSED first map selected session graph read-only, including supporting sources/shared transactions; only a wholly exclusive family may be considered.

**First-round remainder and implications:** EXPLICIT_USER_DECISION one exact reversal family and exact ownership/impact rule. Likely family audit/provenance schema; none allocated.

**First-round proposed acceptance/falsifier:** Plan detects later/shared/supporting references and blocks them unless exact rule covers them; provider parity, hydration and relaunch prove outcome. Any shared document/fingerprint/transaction relation outside selected family scope.

**Second-round new evidence/resolved direction:** No reversal is authorized by ADR-037 generic lifecycle.

**Exact next evidence or decision:** Exact session family and source/provenance impact.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve queue status; named Chat-owned source/privacy/financial family decision remains before implementation planning. **Roadmap:** No change

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** shared source evidence.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** MUTATION_SEMANTICS, REVERSIBILITY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-chat-family-fw-p1-27`: Chat must select one import-session reversal family and inverse/irreversibility rule.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p1-27`: A genuine accepted import-session snapshot and all shared source/transaction ownership relations, with an independent exact impact projection for the selected reversal family.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):900-920 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-27
- [Database/Repository.swift](<../Database/Repository.swift>):248-266 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — ImportSessionRepository
- [Project documents/ADR.md](<ADR.md>):3523-3543 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — no import reversal is introduced

</details>

---

<a id="fw-p1-29"></a>

## FW-P1-29 — Better Validation Guidance

**Status:** Ready for planning
**Depends on:** Existing validation pipeline

Provide broader validation education outside the confirmed-import immediate-result and recovery panel while preserving detailed developer diagnostics separately.

Sprint 58 completed bounded privacy-safe preparation-failure summaries. Sprint 66 completed typed, privacy-safe confirmed-import recovery and review guidance for validation failure, exact duplicate, transaction-event block, account-choice review, stale account choice, identity ambiguity or conflict, identifier-ownership conflict and repository-integrity conflict; unknown, malformed, hostile and otherwise unavailable states fail closed.

Retain only broader validation education and unsupported-result guidance outside those completed confirmed-import result surfaces. Do not duplicate Sprint 66 recovery actions, expose raw diagnostics or infer mutation authority from error text.

**Current discovery disposition — 2026-09-10:** `READY_FOR_IMPLEMENTATION_PLANNING`. **Exact remaining gate:** One bounded ordinary-user education surface and fixed unsupported-result copy.

**Smallest proposed boundary:** Read-only explanatory surface; no state/actions/raw diagnostics.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: typed preparation and confirmed-import guidance exists; hostile or unknown states are neutral/fail-closed.

**First-round scope and constraints:** Do not duplicate recovery actions, expose raw diagnostics, or infer mutation authority from error text. No diagnostics history, raw error rendering, or import changes.

**First-round question/options:** What validation guidance remains after accepted recovery guidance? Target an explicit help surface or leave existing recovery focused.

**First-round remainder and implications:** MISSING: a selected ordinary-user education surface and exact unsupported-result copy. No impact.

**First-round proposed acceptance/falsifier:** Copy tests show every known state stays bounded; unknown values do not echo unsafe text. Guidance duplicates or conflicts with accepted recovery actions.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: typed preparation and confirmed-import guidance exists; hostile or unknown states are neutral/fail-closed. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: One bounded ordinary-user education surface and fixed unsupported-result copy. Owning authority: FW-P1-29 pinned queue scope and the named dependency below.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** READY_FOR_IMPLEMENTATION_PLANNING **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY.

**Typed dependencies:**

- None; execution still requires a Chat-approved prompt.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):924-933 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-29
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):848-850 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7843854eee6c85888f41af52c52aba70f2d0138c5f6f21e518211c75aca62797` — typed import-attempt presentation
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1069-1086 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Better Validation Guidance as Ready for planning and records this unresolved boundary: MISSING: a selected ordinary-user education surface and exact unsupported-result copy.

</details>

---

<a id="fw-p1-29a"></a>

## FW-P1-29A — Historical Backfill Import Workflow

**Status:** Blocked
**Depends on:** Mature duplicate handling, statement continuity and reversible repair foundations

Support deliberate import of older financial history without corrupting current account continuity or duplicating already represented activity.

Candidate outcomes include:

- account-scoped historical import ranges;
- clear distinction between backfill and ordinary current-period importing;
- statement coverage previews;
- overlap and gap explanation;
- controlled handling of legacy un-fingerprinted history;
- impact preview before persistence;
- provenance identifying each backfill source;
- cancellation and failure isolation.

Historical backfill must not assume that older statements are complete or that import order determines final financial truth.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Duplicate handling, continuity and repair foundations are unaccepted.

**Smallest proposed boundary:** Account-scoped read-only gap/overlap presentation.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: ordinary imports enforce exact/event duplicate boundaries; no backfill mode or coverage model exists.

**First-round scope and constraints:** Older statements need not be complete; import order is not financial truth; provenance and cancellation/failure isolation matter. No assumed completeness, historical mutation or generic reconciliation.

**First-round question/options:** Deliberately import historical ranges without false continuity/duplication. PROPOSED source-backed coverage review before any import mode.

**First-round remainder and implications:** Mature duplicate handling, statement continuity model and reversible repair foundation. Unknown.

**First-round proposed acceptance/falsifier:** Incomplete source is labelled unknown; gaps/overlaps explain provenance; cancellation causes zero accepted residue. Requirement to invent legacy fingerprints or periods.

**Second-round new evidence/resolved direction:** No eligible historical overlap relationship found.

**Exact next evidence or decision:** Source-proven gap/overlap and reversible family.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** No change

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** continuity source proof.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** SOURCE_TRUTH, MUTATION_SEMANTICS, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P1-25`: duplicate policy
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-16`: repair lifecycle
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p1-29a`: Authentic historical statements showing the actual date gap or overlap, existing accepted-import history and an independent source-order/balance/identity projection.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):937-955 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-29A
- [Project documents/ADR.md](<ADR.md>):4720-4728 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — synthetic overlap is suspended

</details>

---

<a id="fw-p1-30"></a>

## FW-P1-30 — Granular Development Database Reset

**Status:** Blocked
**Depends on:** Separate approved selective-mutation semantics built on ADR-035

Candidate reset operations include:

- transactions only;
- import sessions only;
- financial identity only;
- repository financial data;

Each operation must clearly state what is retained and removed.

ADR-035 and Sprint 45 Phase A provide the reusable canonical lifecycle, activity-gate, provider-generation, backup and recovery boundary. This candidate covers only selective data-domain mutations, which remain unapproved and must not be inferred from whole-database reset.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** User must choose per-domain selective reset semantics.

**Smallest proposed boundary:** Deletion impact inventory only.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: whole non-current lifecycle/reset exists; selective data-domain mutation is absent.

**First-round scope and constraints:** ADR-035/Sprint45 lifecycle does not imply selective reset; each operation must state retained/removed data. No product mutation, Current Database reset or financial repair.

**First-round question/options:** Offer granular development reset safely. PROPOSED no change; developer whole-db profile remains the bounded mechanism.

**First-round remainder and implications:** EXPLICIT_USER_DECISION per-domain selective mutation semantics. Unknown; no migration implied.

**First-round proposed acceptance/falsifier:** Each reset exactly proves retained/deleted graph and generation/hydration behavior. Selective action leaves dangling provenance/identity.

**Second-round new evidence/resolved direction:** None.

**Exact next evidence or decision:** Explicit destructive-operation decision.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve queue priority/status; explicitly defer until a real selected source or product workflow demonstrates need. See bounded decision queue. **Roadmap:** No change

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** reset scope.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** MUTATION_SEMANTICS, REVERSIBILITY, NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `user-reset-decision`: Future reopening condition only; this deferred boundary is not a current prerequisite. Unselected future scope only; no current user decision is pending for the deferred boundary.
- `OPTIONAL_ENHANCEMENT` → `accepted-post-sprint-87-ownership`: Future reopening condition only; this deferred boundary is not a current prerequisite. Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):961-975 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-30
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):1012-1024 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — deletion is separate

</details>

---

<a id="fw-p1-31"></a>

## FW-P1-31 — Repository Inspector

**Status:** Candidate
**Depends on:** Privacy-safe developer presentation

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Chat must approve the shared DEBUG-only nonpersistent diagnostic projection field allowlist; native gating, export/cancel and safe provider-state acceptance remain future checks.

**Smallest proposed boundary:** DEBUG read-only aggregate/status DTO only.

**Decision record:** [DIAGNOSTICS_PROJECTION_DECISION_PACKET](#packet-diagnostics-projection-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: Settings/Developer Console show bounded provider/runtime information and deliberately hide paths, raw SQL and SQLite errors.

**First-round scope and constraints:** Developer-only presentation cannot become a financial-repair surface or disclose sensitive records. No SQL console, query runner, mutations, source fragments, database paths, or export.

**First-round question/options:** What smallest Repository Inspector is privacy-safe? Expose a typed aggregate snapshot; expose raw repository rows; defer. Raw rows conflict with current privacy boundary.

**First-round remainder and implications:** MISSING: approved inspector data projection, enablement, retention, and action set. No migration; ADR-026 review if diagnostics are reused.

**First-round proposed acceptance/falsifier:** Source tests prove omission of identifiers/paths and exact unavailable behavior; later runtime proof confirms developer gating. A desired field requires raw financial/source data.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: Settings/Developer Console show bounded provider/runtime information and deliberately hide paths, raw SQL and SQLite errors. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Chat must approve the shared DEBUG-only nonpersistent diagnostic projection field allowlist; native gating, export/cancel and safe provider-state acceptance remain future checks. Owning authority: DIAGNOSTICS_PROJECTION_DECISION_PACKET.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Keep decision-ready closure until Chat accepts allowlist; revalidate affected provider boundaries and retain runtime acceptance before any support claim. **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-diagnostic-projection`: The explicitly named gate decision-diagnostic-projection must be satisfied. This enables DEBUG read-only aggregate/status DTO only. Remaining condition: Chat must approve the shared DEBUG-only nonpersistent diagnostic projection field allowlist; native gating, export/cancel and safe provider-state acceptance remain future checks.

**Pinned evidence references:**

- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):852-869 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7843854eee6c85888f41af52c52aba70f2d0138c5f6f21e518211c75aca62797` — Settings and repository status
- [Views/DeveloperConsoleView.swift](<../Views/DeveloperConsoleView.swift>):11-109 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d00ad0ad185deca7cd1a3a0f53e522aa6297f839d8552611b9b1d0de35591dd3` — DeveloperConsoleView
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1139-1150 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Repository Inspector as Candidate and records this unresolved boundary: MISSING: approved inspector data projection, enablement, retention, and action set.

</details>

<a id="packet-diagnostics-projection-decision-packet"></a>

<details>
<summary>DIAGNOSTICS_PROJECTION_DECISION_PACKET — complete proposed decision packet</summary>

## DIAGNOSTICS_PROJECTION_DECISION_PACKET

| # | Required field | Decision |
| --- | --- | --- |
| 1 | Owning FW IDs | FW-P1-31 Repository Inspector, FW-P1-33 Import-Session Inspector, and FW-P1-36 Diagnostic Export. |
| 2 | User problem | A developer needs bounded status and import-attempt context and, only by explicit action, a shareable support artifact without exposing ledger rows, source content or credentials. |
| 3 | Verified current state | DeveloperConsole already observes shared console, account and transaction stores; renders runtime/repository panels; filters diagnostics; and has Copy All. ADR-026 makes current diagnostics deterministic, privacy-safe, capped at 1,000 and ephemeral. |
| 4 | Accepted authorities | ADR-026 is accepted and forbids persistent history, unrestricted export, SQL browser and financial-truth role. ADR-035 owns DEBUG lifecycle only. ADR-024 owns canonical hydration. ADR-046 prohibits source disclosure/financial-source substitution. |
| 5 | Exact missing decision | Chat must approve one field-level allowlist and that these three surfaces share one explicit redacted DTO boundary. |
| 6 | Evidence acquired | DeveloperConsole uses a runtime snapshot and filters; its existing UI is DEBUG-profile aware. FUTURE_WORK separately proposes aggregate inspector, redacted attempt summary and opt-in already-redacted export. |
| 7 | Options considered | Raw repository/SQL browser; independent ad-hoc views; one shared typed redacted projection; persistent timeline/history; user-facing document/source browser. |
| 8 | Recommended option | One DEBUG-only, read-only `DeveloperInspectionSnapshot` projection with three renderers: aggregate repository status, selected import-attempt summary, and opt-in single-file diagnostic export. |
| 9 | Why competing options are rejected | Raw access conflicts with accepted privacy restrictions; separate views drift allowlists; timeline/history changes retention/storage; user source browser is a different product/privacy contract. |
| 10 | Smallest coherent implementation boundary | A nonpersistent projection service reads existing typed state at one provider generation, returns closed enums, booleans and bounded counts; views/export consume exactly this DTO. |
| 11 | Included scope | Repository: availability/provider kind/schema-migration compatibility state/hydration state/bounded domain counts. Attempt: outcome/phase/disposition/count summaries and causal code from accepted presentation mappings. Export: format-versioned JSON or plain text containing the same DTO and current already-redacted chronological diagnostic metadata. |
| 12 | Explicit exclusions | No SQL, DB paths, raw rows, account/document/session IDs, filename, parser profile/digest, source fragment/bytes, passwords/Keychain, values/balances, unbounded errors, repository write, repair/reset, source reopen, persistent history, automatic upload, or Release inclusion. |
| 13 | Durable model/persistence requirements | None. DTO, selection, filters, export staging and destination authorization are process-local. Export has no retained index/history; cancellation/failure removes temporary staged artifact and leaves no final artifact. |
| 14 | Migration impact | NONE. |
| 15 | ADR impact | ALIGN_EXISTING with ADR-026, ADR-024, ADR-035 and ADR-046. No new ADR is needed if the approved allowlist remains this bounded; a persistent store or raw access would be a different proposal. |
| 16 | Privacy/security boundary | Compile DEBUG-only. Closed field allowlist and denylist tests; code/enum references instead of raw error/source text; fixed maximum records/metadata size; explicit Save panel; no automatic disclosure or network effect; developer gating must be observed natively. |
| 17 | SQLite/In-Memory implications | Projection reads existing provider-safe interfaces and must state unavailable truthfully. It has no writes. Test same projection semantics across provider states where those interfaces promise parity; no raw SQLite inspection. |
| 18 | Hydration/relaunch implications | Snapshot carries availability/hydration truth and never forces refresh or alters canonical stores. It disappears on relaunch except any separately user-saved exported artifact; no replay/import of artifact. |
| 19 | Independent acceptance oracle | An independent fixture-free nonfinancial DTO oracle enumerates allowed/denied fields and ordering/count rules. Source-level tests attempt hostile/private-like content through typed diagnostics and prove exclusion. Runtime proof confirms DEBUG gating, Save/cancel and unavailable presentation. |
| 20 | Failure cases | Unavailable/stale provider, hydration failure, unknown/future outcome, selection absent, malformed/hostile diagnostic metadata, active lifecycle/import, permission denial, cancel, write failure, partial staging, oversized collection and Release target attempt. Return neutral unavailable/omit unsafe data; no write. |
| 21 | Reversal/correction semantics | Read-only. Closing/cancelling changes no repository state. Deleting a user-chosen exported file has no ledger effect. This is not backup, rollback, audit persistence or financial correction. |
| 22 | Source evidence requirement | None. This is source-independent developer presentation; financial statements, source bytes and statement-shaped data remain excluded. |
| 23 | Runtime acceptance requirement | Required for DEBUG-only visibility, native Save authorization/cancel/no-residue, accessibility labels, developer-mode gating and truthful unavailable state. |
| 24 | Dependencies | Chat accepts the allowlist decision; existing ADR-026/024/035/046 continue unchanged. No FW-P1-38/39/39A dependency and no Swift-6/lifecycle redesign. |
| 25 | Evidence that falsifies the recommendation | Any requested field requires prohibited record/source/credential content; parity cannot be stated from safe interfaces; DEBUG code reaches Release; a selected export cannot clean temporary residue; or persistent retention becomes required. |
| 26 | Personal-v1 relevance | POST_V1 developer tooling; no adoption/certification role. |
| 27 | Recommended FUTURE_WORK status after Chat review | FW-P1-31, FW-P1-33 and FW-P1-36: READY_FOR_CHAT_ARCHITECTURE_DECISION, strictly for this narrow allowlist decision. After approval, use READY_AFTER_NAMED_DEPENDENCY until the exact affected provider/ownership and native availability/gating conditions are settled; do not bypass runtime or post-87 gates. |
| 28 | Recommended roadmap effect after Chat review | Do not select a sprint or merge with lifecycle maintenance. Record one optional bounded DEBUG projection slice and preserve unselected inspector/history candidates as deferred. |

### Compact ADR context

ADR-026 already accepts bounded, deterministic, in-memory, privacy-safe diagnostics and excludes persistent history, unrestricted export, SQL browser and financial-truth role (`ADR.md:1133-1148`). This packet deliberately stays inside that authority: it requires Chat approval of a field allowlist and does **not** propose an ADR. A durable timeline, raw browser, generalized maintenance operation, or automatic/log-history export would leave this packet and require a separately justified product use case and architecture decision.

</details>

---

<a id="fw-p1-32"></a>

## FW-P1-32 — Development SQLite Browser

**Status:** Research
**Depends on:** Development-only access and privacy controls

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Whether raw table browsing is ever allowed; alternatives are reject, redacted snapshot, or raw browser.

**Smallest proposed boundary:** No SQL/raw rows unless separately authorized.

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P1-32 | **User product choice:** whether raw table browsing is ever part of the product. | Raw rows increase privacy exposure and can be mistaken for financial authority. | Reject raw tables; use bounded views. | Redacted read-only snapshot for a named workflow. | Raw browser only with separate authorization. | A. | No raw-table surface. | B only with privacy-safe snapshot contract. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: developer profiles distinguish durable/non-durable stores but deny database paths, raw SQL and raw SQLite errors.

**First-round scope and constraints:** The database is disposable for development but trusted financial history must not be silently altered. No SQL input, mutation, database path reveal, or automatic snapshot.

**First-round question/options:** Can a Development SQLite Browser be made safe? Typed read-only inspection DTO; external developer database tool; raw in-app browser. Only the first matches current disclosure constraints.

**First-round remainder and implications:** MISSING: whether Chat authorizes raw table viewing, a snapshot-only source, redaction policy, and active-import coordination. No migration; may require ADR if durable diagnostics/storage is added.

**First-round proposed acceptance/falsifier:** Static privacy denylist plus isolated lifecycle/active-operation tests. Need for unrestricted table values or active database browsing.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: developer profiles distinguish durable/non-durable stores but deny database paths, raw SQL and raw SQLite errors. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Whether raw table browsing is ever allowed; alternatives are reject, redacted snapshot, or raw browser. Owning authority: FW-P1-32 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** BLOCKED_ON_PRODUCT_DECISION **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-raw-browser-privacy-snapshot`: A selected raw-browser or redacted-snapshot workflow requires its own Chat privacy/authority contract. Deferred maintenance utilities are not a prerequisite.
- `REQUIRES_USER_DECISION` → `decision-product-fw-p1-32`: Whether raw table browsing is ever allowed; alternatives are reject, redacted snapshot, or raw browser.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):986-989 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-32
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):852-860 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7843854eee6c85888f41af52c52aba70f2d0138c5f6f21e518211c75aca62797` — Settings and repository status
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1151-1162 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Development SQLite Browser as Research and records this unresolved boundary: MISSING: whether Chat authorizes raw table viewing, a snapshot-only source, redaction policy, and active-import coordination.

</details>

---

<a id="fw-p1-33"></a>

## FW-P1-33 — Import-Session Inspector

**Status:** Candidate
**Depends on:** Implemented durable import-attempt-history foundation and an approved developer-inspection privacy boundary

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Chat must approve the shared DEBUG-only nonpersistent diagnostic projection field allowlist; native gating, export/cancel and safe provider-state acceptance remain future checks.

**Smallest proposed boundary:** Read-only bounded projection, distinct from diagnostics history.

**Decision record:** [DIAGNOSTICS_PROJECTION_DECISION_PACKET](#packet-diagnostics-projection-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: durable import attempts and imported-document links exist; the current user detail exposes only validated bounded provenance.

**First-round scope and constraints:** No raw identifiers, documents, paths, source fragments, or substitution of a session label for durable document authority. No timeline, raw diagnostics, repair/reversal, or user-facing history redesign.

**First-round question/options:** What can a developer Import-Session Inspector show? Read-only typed attempt summary; extend user history; raw session graphs. The first is smallest.

**First-round remainder and implications:** MISSING: approved developer projection and its relation to the separate user durable-history contract. No migration; do not conflate with ADR-026 history.

**First-round proposed acceptance/falsifier:** Provider parity projection and privacy exclusion tests; runtime gating later. Inspector needs a new durable timeline or unrestricted provenance.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: durable import attempts and imported-document links exist; the current user detail exposes only validated bounded provenance. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Chat must approve the shared DEBUG-only nonpersistent diagnostic projection field allowlist; native gating, export/cancel and safe provider-state acceptance remain future checks. Owning authority: DIAGNOSTICS_PROJECTION_DECISION_PACKET.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Keep decision-ready closure until Chat accepts allowlist; revalidate affected provider boundaries and retain runtime acceptance before any support claim. **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-attempt-projection`: The explicitly named gate decision-attempt-projection must be satisfied. This enables Read-only bounded projection, distinct from diagnostics history. Remaining condition: Chat must approve the shared DEBUG-only nonpersistent diagnostic projection field allowlist; native gating, export/cancel and safe provider-state acceptance remain future checks.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):993-996 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-33
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):1331-1335 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7843854eee6c85888f41af52c52aba70f2d0138c5f6f21e518211c75aca62797` — transaction provenance boundary
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1163-1174 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Import-Session Inspector as Candidate and records this unresolved boundary: MISSING: approved developer projection and its relation to the separate user durable-history contract.

</details>

---

<a id="fw-p1-34"></a>

## FW-P1-34 — Parser and Source-Evidence Inspector

**Status:** Research
**Depends on:** Privacy-safe source-evidence redaction

Source inspection must never expose passwords or unredacted financial identifiers.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Approved parser-evidence redaction taxonomy.

**Smallest proposed boundary:** No profile IDs/digests/paths/source fragments.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: current presentation explicitly excludes parser profile IDs, digests, paths and source fragments from visible/accessibility text.

**First-round scope and constraints:** ADR-046 authentic sources remain private/read-only; passwords and identifiers never appear. No source text, document bytes, filenames, identifiers, passwords, or corpus access.

**First-round question/options:** What source evidence may a Parser Inspector present? Aggregated parser outcome codes; redacted field-level evidence; raw source view. Only aggregate codes are supported now.

**First-round remainder and implications:** MISSING: an approved redaction taxonomy and non-sensitive parser evidence projection. No migration; likely ADR-level privacy decision before expansion.

**First-round proposed acceptance/falsifier:** Negative disclosure tests with hostile/private-like values and independent redaction review. Any required support evidence cannot be safely represented.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: current presentation explicitly excludes parser profile IDs, digests, paths and source fragments from visible/accessibility text. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Approved parser-evidence redaction taxonomy. Owning authority: FW-P1-34 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve queue status; named Chat-owned source/privacy/financial family decision remains before implementation planning. **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `accepted-adr-046`: The explicitly named gate accepted-adr-046 must be satisfied. This enables No profile IDs/digests/paths/source fragments. Remaining condition: Approved parser-evidence redaction taxonomy.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-chat-family-fw-p1-34`: Approved parser-evidence redaction taxonomy.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1000-1005 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-34
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):1356-1360 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7843854eee6c85888f41af52c52aba70f2d0138c5f6f21e518211c75aca62797` — transaction provenance privacy boundary
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1175-1188 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Parser and Source-Evidence Inspector as Research and records this unresolved boundary: MISSING: an approved redaction taxonomy and non-sensitive parser evidence projection.

</details>

---

<a id="fw-p1-35"></a>

## FW-P1-35 — Duplicate and Identity-Conflict Inspector

**Status:** Blocked
**Depends on:** Approved duplicate and conflict semantics

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Typed duplicate/conflict semantics and privacy policy are unaccepted.

**Smallest proposed boundary:** Safe typed-outcome inspector.

**Decision record:** [TRANSFER_FAMILY_DECISION_PACKET](#packet-transfer-family-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: typed outcomes exist, but no approved inspector semantics or privacy presentation.

**First-round scope and constraints:** Inspector must not turn candidates into proof or expose raw private identifiers. No repair/override/raw diagnostics.

**First-round question/options:** Inspect duplicate and identity conflicts safely. A typed read-only inspector can explain existing exact rejection outcomes; a repair/conflict-resolution screen additionally needs one accepted mutation family.

**First-round remainder and implications:** Approved duplicate/conflict semantics from P0/P1 work. None for triage.

**First-round proposed acceptance/falsifier:** Independently compare the displayed classification with the exact typed outcome and provenance; distinguish incoming rejection from proof of historical corruption. Missing evidence must remain missing and no raw identifier or unapproved override may be reachable. Presentation needs undisclosed raw source data.

**Second-round new evidence/resolved direction:** Source analysis distinguishes ambiguous candidate from transfer/duplicate.

**Exact next evidence or decision:** Approved P0/P1 relationship outcome.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** No change

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** privacy policy.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** PRIVACY, IDENTITY, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P1-25`: duplicate outcomes
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-14`: Chat owns this financial/privacy/architecture decision; it is not a technical questionnaire for the user.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1009-1012 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-35
- [Services/ImportPersistenceCoordinator.swift](<../Services/ImportPersistenceCoordinator.swift>):1909-1929 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `052b8de5c2de61349a5151d676e1dade3ec005363fb82f4eed290822bea2cfae` — rejectedAttempt
- [Project documents/ADR.md](<ADR.md>):5079-5085 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — typed source relationship constraints exist

</details>

---

<a id="fw-p1-36"></a>

## FW-P1-36 — Diagnostic Export

**Status:** Candidate
**Depends on:** Privacy filtering and explicit user action

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Chat must approve the shared DEBUG-only nonpersistent diagnostic projection field allowlist; native gating, export/cancel and safe provider-state acceptance remain future checks.

**Smallest proposed boundary:** DEBUG opt-in already-redacted metadata export only.

**Decision record:** [DIAGNOSTICS_PROJECTION_DECISION_PACKET](#packet-diagnostics-projection-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: Copy All is bounded chronological metadata; runtime diagnostics pass through privacy filtering.

**First-round scope and constraints:** Explicit user action, no credentials/source fragments/raw identifiers, no financial truth export masquerading as diagnostics. No automatic upload, raw logs, database/source export, or persistent history.

**First-round question/options:** What diagnostic export boundary is safe? Export existing filtered text; introduce a structured redacted bundle; defer. Text reuse is smallest but needs explicit allowlist proof.

**First-round remainder and implications:** MISSING: export format, destination authorization, retention, and a reviewed allowlist. No migration; ADR-026 bounds remain.

**First-round proposed acceptance/falsifier:** Secret/identifier exclusion tests, cancellation/no-file residue, and manual destination confirmation. Any field is not demonstrably redacted before serialization.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: Copy All is bounded chronological metadata; runtime diagnostics pass through privacy filtering. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Chat must approve the shared DEBUG-only nonpersistent diagnostic projection field allowlist; native gating, export/cancel and safe provider-state acceptance remain future checks. Owning authority: DIAGNOSTICS_PROJECTION_DECISION_PACKET.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Keep decision-ready closure until Chat accepts allowlist; revalidate affected provider boundaries and retain runtime acceptance before any support claim. **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `accepted-adr-026`: The explicitly named gate accepted-adr-026 must be satisfied. This enables DEBUG opt-in already-redacted metadata export only. Remaining condition: Chat must approve the shared DEBUG-only nonpersistent diagnostic projection field allowlist; native gating, export/cancel and safe provider-state acceptance remain future checks.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p1-36`: Chat must approve the shared DEBUG-only nonpersistent diagnostic projection field allowlist; native gating, export/cancel and safe provider-state acceptance remain future checks.

**Pinned evidence references:**

- [Core/DeveloperConsole.swift](<../Core/DeveloperConsole.swift>):47-93 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `f496995df7f425b7f556036d697992aa7bafed3fa4bde39e16031dc7500efc34` — DeveloperConsole.appendEntry
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1016-1019 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-36
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1201-1212 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Diagnostic Export as Candidate and records this unresolved boundary: MISSING: export format, destination authorization, retention, and a reviewed allowlist.

</details>

---

<a id="fw-p1-37"></a>

## FW-P1-37 — Better Developer Diagnostics and Failure Summaries

**Status:** Ready for planning
**Depends on:** Existing structured diagnostic system

Sprint 58 completed bounded privacy-safe preparation-failure summaries and the Developer Console integration related to the approved fixture workflow. Retain only broader structured diagnostics work not completed by that slice.

The Chat-accepted unnumbered startup/monthly-planner package on 2026-09-09 additionally completed typed migration/provider/hydration/save failure summaries, causal references, safe next actions, bounded chronological Copy All metadata and truthful unavailable/non-current presentation. See [PROJECT_STATE.md](PROJECT_STATE.md). These slices are no longer queued here; broader structured diagnostics remain future work. Persistent diagnostic history and an import timeline are not completed or authorized by this closure.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No verified uncovered diagnostic class or audience.

**Smallest proposed boundary:** Do not begin broad diagnostic sweep.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: startup, provider, hydration, save and recovery summaries plus bounded Copy All are recorded as complete; persistent history/timeline are excluded.

**First-round scope and constraints:** Keep diagnostics typed, privacy-safe, bounded and distinct from user import history. No persistent history, import timeline, raw data, or repair.

**First-round question/options:** What broader diagnostics remain? Select one unrepresented failure class; extend history; defer. Selection is needed before work.

**First-round remainder and implications:** MISSING: one concrete uncovered diagnostic class and user/developer audience. ADR-026 is unchanged.

**First-round proposed acceptance/falsifier:** Exact failure classification, filtered rendering, no unsafe echo, and truthful unavailable state. No verified uncovered class exists.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: startup, provider, hydration, save and recovery summaries plus bounded Copy All are recorded as complete; persistent history/timeline are excluded. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: No verified uncovered diagnostic class or audience. Owning authority: FW-P1-37 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** DEFERRED_WITH_REASON **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** NO_REAL_USE_CASE.

**Typed dependencies:**

- None; execution still requires a Chat-approved prompt.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1023-1030 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-37
- [Core/DeveloperConsole.swift](<../Core/DeveloperConsole.swift>):47-100 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `f496995df7f425b7f556036d697992aa7bafed3fa4bde39e16031dc7500efc34` — DeveloperConsole
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1213-1228 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Better Developer Diagnostics and Failure Summaries as Ready for planning and records this unresolved boundary: MISSING: one concrete uncovered diagnostic class and user/developer audience.

</details>

---

<a id="fw-p1-38"></a>

## FW-P1-38 — Import Inspector and Validation Timeline

**Status:** Blocked
**Depends on:** A separate approved diagnostic-history and timeline architecture

Provide development-only inspection of an import’s progression through:

- source reading;
- institution detection;
- statement classification;
- parser selection;
- financial parsing;
- validation;
- user confirmation;
- duplicate evaluation;
- account decision;
- persistence;
- hydration.

The inspector may include a validation timeline showing issues and outcomes in deterministic order.

It must not expose:

- passwords;
- raw financial identifiers;
- unrestricted source fragments;
- production-only sensitive information.

This candidate remains separate from the user-facing durable import-attempt history and is not promoted by the approved sprint.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No selected developer use case requires new persistent history/timeline or a maintenance operation. ADR-026 ephemeral diagnostics and ADR-035 lifecycle are accepted scope, not missing prerequisites.

**Smallest proposed boundary:** No persistent timeline before ADR.

**Decision record:** [DIAGNOSTICS_PROJECTION_DECISION_PACKET](#packet-diagnostics-projection-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: current attempt outcomes are typed and bounded; there is no accepted persistent diagnostic history/timeline architecture.

**First-round scope and constraints:** No passwords, identifiers, source fragments, or replacement of user durable history. No new persistence, UI timeline, or source event replay.

**First-round question/options:** Can an Import Inspector and validation timeline proceed? In-memory current attempt only; durable developer timeline; user import history. They are distinct contracts.

**First-round remainder and implications:** MISSING: approved timeline event model, retention, ordering, privacy projection, and ADR decision. Potential new storage only after architecture; no migration allocated.

**First-round proposed acceptance/falsifier:** Deterministic event order, redaction, deletion/retention, and no cross-role data leakage. Timeline needs raw source evidence or muddles audit history.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: current attempt outcomes are typed and bounded; there is no accepted persistent diagnostic history/timeline architecture. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: No selected developer use case requires new persistent history/timeline or a maintenance operation. ADR-026 ephemeral diagnostics and ADR-035 lifecycle are accepted scope, not missing prerequisites. Owning authority: DIAGNOSTICS_PROJECTION_DECISION_PACKET.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve queue status/priority; explicitly defer until a concrete consumer or operation is selected. **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION, NO_REAL_USE_CASE.

**Typed dependencies:**

- None; execution still requires a Chat-approved prompt.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1034-1062 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-38
- [Project documents/ADR.md](<ADR.md>):1134-1184 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-026
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1229-1265 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Import Inspector and Validation Timeline as Blocked and records this unresolved boundary: MISSING: approved timeline event model, retention, ordering, privacy projection, and ADR decision.

</details>

---

<a id="fw-p1-39"></a>

## FW-P1-39 — Development Database Maintenance Utilities

**Status:** Research
**Depends on:** Separate safety, mutation and validation contracts for each maintenance operation

Investigate safe development-only utilities for:

- opening the active database folder;
- exporting a SQLite snapshot;
- database vacuum or optimization;
- repository rebuild;
- balance recalculation;
- search reindexing.

Each operation requires an explicit safety contract, scope description and validation strategy.

ADR-035 and Sprint 45 Phase A already own canonical Debug identity, exclusive lifecycle activity, provider generations, checked close, coordinated SQLite/WAL/SHM handling, verified lifecycle backup and automatic recovery. Those delivered lifecycle responsibilities are not part of this research item; no snapshot export, vacuum, optimization, repository rebuild, recalculation, reindexing or repair utility was implemented.

No maintenance operation may silently alter trusted financial history or run against an active import without safe coordination.

Production user-facing repair remains governed by `FW-P0-08`.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No selected developer use case requires new persistent history/timeline or a maintenance operation. ADR-026 ephemeral diagnostics and ADR-035 lifecycle are accepted scope, not missing prerequisites.

**Smallest proposed boundary:** First candidate: read-only profile status/open-folder only.

**Decision record:** [DIAGNOSTICS_PROJECTION_DECISION_PACKET](#packet-diagnostics-projection-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: DBP-01 already owns profile lifecycle, activity gate, coordinated SQLite files, recovery and generation protection; utilities are absent.

**First-round scope and constraints:** Every operation needs distinct safety, scope, validation; none may mutate trusted history or run during active import. No reset, vacuum, rebuild, recalculation, reindexing, production repair, or active-import action.

**First-round question/options:** How should developer maintenance utilities be selected? Read-only open-folder/status; export snapshot; vacuum; rebuild/recalculate/reindex. These are not one feature.

**First-round remainder and implications:** MISSING: selected first operation and mutation/reversibility contract. No migration for read-only status; mutations may require ADR review.

**First-round proposed acceptance/falsifier:** Active-import refusal, stale-generation refusal, target identity, and no data writes. Operation requires unapproved selective mutation.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: DBP-01 already owns profile lifecycle, activity gate, coordinated SQLite files, recovery and generation protection; utilities are absent. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: No selected developer use case requires new persistent history/timeline or a maintenance operation. ADR-026 ephemeral diagnostics and ADR-035 lifecycle are accepted scope, not missing prerequisites. Owning authority: DIAGNOSTICS_PROJECTION_DECISION_PACKET.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve queue status/priority; explicitly defer until a concrete consumer or operation is selected. **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION, NO_REAL_USE_CASE.

**Typed dependencies:**

- None; execution still requires a Chat-approved prompt.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1066-1086 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-39
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):871-884 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7843854eee6c85888f41af52c52aba70f2d0138c5f6f21e518211c75aca62797` — Development database lifecycle
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1266-1294 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Development Database Maintenance Utilities as Research and records this unresolved boundary: MISSING: selected first operation and mutation/reversibility contract.

</details>

---

<a id="fw-p1-39a"></a>

## FW-P1-39A — Persistent Developer Diagnostic History

**Status:** Research
**Depends on:** A new ADR replacing or extending ADR-026’s in-memory-only diagnostic constraint

Investigate an optional development-only diagnostic history that survives relaunch.

The design must define:

- explicit enablement and retention limits;
- privacy filtering;
- log rotation and deletion;
- separation from repository financial truth;
- protection from passwords, raw financial identifiers and unrestricted source fragments;
- export compatibility;
- deterministic ordering and schema evolution.

Persistent diagnostics must not become an application persistence mechanism or a substitute for import-session audit history.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No selected developer use case requires new persistent history/timeline or a maintenance operation. ADR-026 ephemeral diagnostics and ADR-035 lifecycle are accepted scope, not missing prerequisites.

**Smallest proposed boundary:** No durable diagnostic history now.

**Decision record:** [DIAGNOSTICS_PROJECTION_DECISION_PACKET](#packet-diagnostics-projection-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: DeveloperConsole holds a capped in-memory chronological list and applies privacy filtering at append; ADR-026 is in-memory-only.

**First-round scope and constraints:** Optional/debug-only, bounded retention/deletion, no financial repository role, no sensitive material. No automatic telemetry, import audit replacement, raw log persistence, or user data storage.

**First-round question/options:** May diagnostics persist across relaunch? Remain in memory; opt-in file-backed DEBUG history; repository storage. The latter two require architecture approval.

**First-round remainder and implications:** MISSING: new ADR, storage owner, enablement/retention/deletion/export contract and schema evolution plan. Architecture decision first; no migration allocation.

**First-round proposed acceptance/falsifier:** Relaunch/rotation/deletion, explicit disabled default, privacy fuzzing, and Release absence. Cannot prove durable privacy filtering or deletion semantics.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: DeveloperConsole holds a capped in-memory chronological list and applies privacy filtering at append; ADR-026 is in-memory-only. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: No selected developer use case requires new persistent history/timeline or a maintenance operation. ADR-026 ephemeral diagnostics and ADR-035 lifecycle are accepted scope, not missing prerequisites. Owning authority: DIAGNOSTICS_PROJECTION_DECISION_PACKET.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve queue status/priority; explicitly defer until a concrete consumer or operation is selected. **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION, NO_REAL_USE_CASE.

**Typed dependencies:**

- None; execution still requires a Chat-approved prompt.

**Pinned evidence references:**

- [Core/DeveloperConsole.swift](<../Core/DeveloperConsole.swift>):47-93 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `f496995df7f425b7f556036d697992aa7bafed3fa4bde39e16031dc7500efc34` — DeveloperConsole
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1090-1107 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P1-39A
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1295-1322 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Persistent Developer Diagnostic History as Research and records this unresolved boundary: MISSING: new ADR, storage owner, enablement/retention/deletion/export contract and schema evolution plan.

</details>

---

<a id="fw-p2-01"></a>

## FW-P2-01 — Source-Document Reopening

**Status:** Candidate
**Depends on:** Approved document-library and source-retention architecture

Sprint 67A corrected the completed read-only transaction-detail presentation so source-document metadata is bound to the transaction's exact durable imported-document record; import-session display labels are not document authority.

Only source-document reopening, browsing or library behavior remains here. It requires a separately approved architecture and privacy boundary; filenames, raw source bytes, paths and display labels must not become durable identity.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Chat must choose reauthorize-original, encrypted retention, or metadata-only library.

**Smallest proposed boundary:** Fingerprint-gated reauthorization is recommended; metadata-only is FW-P2-54.

**Decision record:** [DOCUMENT_LIBRARY_PACKET](#packet-document-library-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: transaction detail presents a durable preferred/source document name and session-backed provenance, while DocumentStore retains only process-local text rows and transactions. Neither establishes retained original bytes, a re-openable security-scoped URL, or availability of an original after import.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Source-Document Reopening: establish the smallest truthful product boundary. PROPOSED: A is least-retention and requires per-open user selection plus exact fingerprint comparison; B gives offline reopening but adds sensitive-content retention/recovery obligations; C is metadata-only navigation and is lower risk but cannot reopen. Do not conflate C with an answer to FW-P2-01.

**First-round remainder and implications:** EXPLICIT_USER_DECISION: choose one reopening contract. A: user re-authorizes the exact original; fingerprint match proves it is the same retained source before opening. B: LedgerForge retains an approved source copy under an explicit encryption/privacy, storage, deletion, migration and recovery contract. C: library metadata only; this is FW-P2-54 and does not implement reopening. MISSING: availability of any original is never assumed. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** A: independent original fingerprint equals durable authority before presentation, while a mismatch/missing file opens nothing and changes no history. B: retention, deletion and restore behavior is proven against an approved privacy contract. C: navigator shows only authoritative safe metadata and never claims content availability. All paths preserve original source values and show provenance limitations. An original whose fingerprint cannot be compared, a retention requirement without privacy/recovery decision, or metadata displayed as proof that a reopenable source exists invalidates the boundary.

**Second-round new evidence/resolved direction:** Durable provenance is not content retention.

**Exact next evidence or decision:** Chosen reopening contract and privacy lifecycle.

**Personal-v1:** PRE_V1_REQUIRED if reopening is adopted

**Recommendation after Chat:** Preserve queue status; named Chat-owned source/privacy/financial family decision remains before implementation planning. **Roadmap:** Do not schedule before choice

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Retention/recovery scope.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** PRIVACY, SECURITY, DURABLE_PERSISTENCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-document-reopening`: Chat owns this financial/privacy/architecture decision; it is not a technical questionnaire for the user.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-chat-family-fw-p2-01`: Chat must choose reauthorize-original, encrypted retention, or metadata-only library.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1113-1185 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-01
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [ViewModels/TransactionListViewModel.swift](<../ViewModels/TransactionListViewModel.swift>):120-209 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7e2dbde244295009d00df9cf6f6f5606f2e123374c912c346df4b07936b1cbd9` — detailPresentation(for:)
- [Core/DocumentStore.swift](<../Core/DocumentStore.swift>):16-48 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `f4bb0ff9bb28d34154d38216130b32e730757b27054a881e17250aa7776c9aec` — DocumentStore
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1323-1334 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — A/B/C decision is explicit.

</details>

---

<a id="fw-p2-03"></a>

## FW-P2-03 — Advanced Transaction Search

**Status:** Ready for planning
**Depends on:** Stable transaction fields

**Owning design authority:** `UI_UX_v1.0_Frozen.md` and `UI Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md`.

Expand the global repository-backed Transactions experience with bounded search/filtering over supported displayed fields and authoritative transaction semantics:

- account, institution, bank/card family, currency, period/date, financial-effect/direction and category filters;
- amount/institution filtering only where the displayed authoritative fields support it;
- AND across filter groups and OR within a multi-select group;
- visible active scope, clear-filters behavior and deterministic no-match presentation;
- immutable account identity and no fuzzy financial inference;
- search only over supported displayed/searchable fields rather than hidden identifiers or source fragments.

The global Transactions store remains the authority; filtering is presentation scope, not a new transaction repository.

**Designer-1 observation / evidence gap — 2026-09-09:** one reviewed screenshot appeared to show internally inconsistent INR inflow/outflow/net colouring. Classification: **OBSERVATION / EVIDENCE GAP, NOT VERIFIED FINANCIAL DEFECT**. Before any calculation or financial-colour semantic change, run targeted source/runtime verification. Do not infer stored-data corruption or create a P0 defect without proof.

**Current discovery disposition — 2026-09-10:** `WAIT_FOR_RUNTIME_ACCEPTANCE`. **Exact remaining gate:** Filter fields may proceed; separate INR-colour observation needs targeted verification before any colour-semantic change.

**Smallest proposed boundary:** Pure presentation filter over trusted snapshot; no repository write.

**Decision record:** [SPRINT89_DATA_ALGEBRA_PACKET](<Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md#packet-sprint89-data-algebra-packet>).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: the current view model searches only description, displayed account and displayed institution, then applies the credit/debit toggle; its tests cover trim/case-insensitive matching and the toggle. R1 is the proposed expansion authority, not evidence that account/currency/period/category multi-filter behavior is already implemented.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Advanced Transaction Search: establish the smallest truthful product boundary. PROPOSED: keep search to explicit displayed/searchable fields; add R1 filter groups only when each has a named authoritative field. Hidden identifiers, source fragments and metadata remain excluded. The reported INR colour observation needs its own source/runtime check and is not a financial defect.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Targeted source/runtime check of the noted INR colour observation before semantic change. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** A cross-product test proves AND/OR semantics, active-scope label, clear filters and stable ordering over authoritative displayed fields; source order, money/direction semantics and hidden identifiers are unchanged. A targeted source/runtime probe settles or rejects the INR-colour observation before any semantic colour change. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Complete deterministic filter/search/sort/totals algebra is now specified.

**Exact next evidence or decision:** UI authority selection and later native acceptance.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve current status; data-algebra proposal is prepared, native filter/selection/accessibility and INR-colour acceptance remains to be observed. **Roadmap:** Retain Sprint 89 boundary

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** New displayed field or INR semantic-colour change.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** ACCESSIBILITY_ACCEPTANCE.

**Typed dependencies:**

- `REQUIRES_RUNTIME_ACCEPTANCE` → `decision-sprint89-ui-acceptance`: Native focus/accessibility owned elsewhere.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1113-1185 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-03
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [ViewModels/TransactionListViewModel.swift](<../ViewModels/TransactionListViewModel.swift>):274-296 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7e2dbde244295009d00df9cf6f6f5606f2e123374c912c346df4b07936b1cbd9` — filteredTransactions
- [LedgerForgeTests/TransactionListViewModelTests.swift](<../LedgerForgeTests/TransactionListViewModelTests.swift>):11-53 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `30c938da8a204989e27b1b070a352b8bd784cf111ef01dd2b04f6dd3f8f3641f` — searchTrimsWhitespaceAndMatchesAuthenticTransactionText
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1339-1361 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — AND/OR and no-write scope.

</details>

---

<a id="fw-p2-04"></a>

## FW-P2-04 — Saved Transaction Filters

**Status:** Blocked
**Depends on:** `FW-P2-03`

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Search specification and saved-filter persistence scope are unresolved.

**Smallest proposed boundary:** Named filter after accepted search, never financial mutation.

**Decision record:** [SPRINT89_DATA_ALGEBRA_PACKET](<Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md#packet-sprint89-data-algebra-packet>).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No saved-filter contract follows from current search UI.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Saved Transaction Filters: establish the smallest truthful product boundary. PROPOSED: Named filter representation after search is accepted. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: FW-P2-03 scope and persistence/privacy decision. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** No saved-filter contract currently exists.

**Exact next evidence or decision:** Accepted FW-P2-03 plus user-owned preference policy.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Separate follow-up

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Cross-workspace sharing or retention.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, PREFERENCE_OWNERSHIP, PRIVACY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-03`: Search representation first.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-04`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Search specification and saved-filter persistence scope are unresolved.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1113-1185 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-04
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1363-1370 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Depends on FW-P2-03.

</details>

---

<a id="fw-p2-05"></a>

## FW-P2-05 — Transaction Multi-Selection

**Status:** Candidate
**Depends on:** Approved bulk-action boundaries

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** No non-financial grouped action justifies selection semantics.

**Smallest proposed boundary:** Presentation-only selection before actions.

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P2-05 | **User product choice:** whether a named nonfinancial batch action needs multi-selection. | Selection without useful action adds interaction state without benefit. | Defer. | Presentation-only multi-selection for one selected action. | — | A until a current action is named. | No multi-select. | P2-06 action packet if B selected. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: Selection is a presentation state; no approved grouped action boundary exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Transaction Multi-Selection: establish the smallest truthful product boundary. PROPOSED: Presentation-only selection behavior before actions. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Which non-financial action family benefits and selection persistence rules. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Selection is only presentation state.

**Exact next evidence or decision:** One action family and selection persistence decision.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Candidate **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Financial mutations/actions.

**Current gate flags:** user product choice=true, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** MUTATION_SEMANTICS, USER_PRODUCT_DECISION.

**Typed dependencies:**

- `REQUIRES_USER_DECISION` → `decision-bulk-action-family`: No action selected.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1113-1185 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-05
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1375-1382 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No approved action boundary.

</details>

---

<a id="fw-p2-06"></a>

## FW-P2-06 — Bulk Transaction Actions

**Status:** Blocked
**Depends on:** `FW-P2-05`, Accepted ADR-037, and an independently approved contract for each concrete bulk-action family

Potential actions include notes, categories, rules and safe deletion or exclusion.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Needs selection, ADR-037 and concrete action-specific review/audit contract.

**Smallest proposed boundary:** One non-financial action only.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No generic mutation executor exists; category actions are separately bounded.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Bulk Transaction Actions: establish the smallest truthful product boundary. PROPOSED: One nonfinancial action with exact review/audit. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: One concrete action-family contract. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** No generic mutation executor exists.

**Exact next evidence or decision:** Approved one-action family.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Any financial delete/exclusion.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, MUTATION_SEMANTICS, REVERSIBILITY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-05`: Selection behavior.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `accepted-adr-037`: Mutation authority.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-06`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Needs selection, ADR-037 and concrete action-specific review/audit contract.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1113-1185 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-06
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1387-1396 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Action family required.

</details>

---

<a id="fw-p2-07"></a>

## FW-P2-07 — Delete Transactions by Import Session

**Status:** Blocked
**Depends on:** Approved `FW-P1-27` import-session reversal

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** FW-P1-27 reversal family is unselected.

**Smallest proposed boundary:** None before session reversal.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: no trusted-transaction delete family; only session-filtered replacement API exists.

**First-round scope and constraints:** Imported provenance and shared/equivalent relations cannot be inferred as session-exclusive. No independent delete action.

**First-round question/options:** Delete transactions by import session. PROPOSED fold only into selected session-reversal family.

**First-round remainder and implications:** Approved FW-P1-27 reversal family. Follows reversal family.

**First-round proposed acceptance/falsifier:** Shared/later/supporting relation blocks unsafe deletion. Any transaction lacks complete session/provenance relation.

**Second-round new evidence/resolved direction:** None.

**Exact next evidence or decision:** Approved exact reversal family.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** No change

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** reversal family.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** MUTATION_SEMANTICS, REVERSIBILITY, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P1-27`: transaction deletion must be a family consequence
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p2-07`: Genuine accepted transactions and session/source ownership records for the approved reversal family; independently prove shared evidence and the exact records affected before any deletion.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1167-1171 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-07
- [Database/Repository.swift](<../Database/Repository.swift>):208-212 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — TransactionRepository
- [Project documents/ADR.md](<ADR.md>):3451-3466 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — trusted transaction deletion unapproved

</details>

---

<a id="fw-p2-08"></a>

## FW-P2-08 — Undo Support

**Status:** Research
**Depends on:** Family-specific reversible repository history; ADR-037 rejects universal application undo

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** No selected mutation family or retention/privacy decision.

**Smallest proposed boundary:** No universal undo model/UI.

**Decision record:** [CHAT_DECISION_PACKET](#packet-chat-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** EXPLICIT_USER_DECISION: ADR-037 rejects universal application undo.

**First-round scope and constraints:** Only family-specific reversible history, compensation or explicit irreversibility is valid. No generic undo ledger or backup undo.

**First-round question/options:** What undo is safe? PROPOSED label each family’s reversal separately.

**First-round remainder and implications:** Selected mutation family and retention/privacy/reversal decision. Family-specific only.

**First-round proposed acceptance/falsifier:** Undo never applies across a later conflicting change; inverse/compensation proven. Any ‘undo’ needs unbounded mutation history.

**Second-round new evidence/resolved direction:** ADR-037 explicitly rejects application-wide undo.

**Exact next evidence or decision:** Family-specific audit/reversal rules.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Research **Roadmap:** No change

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** universal-undo proposal.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** MUTATION_SEMANTICS, REVERSIBILITY, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-16`: family lifecycle
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1174-1177 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-08
- [Project documents/ADR.md](<ADR.md>):3460-3518 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-037
- [Project documents/ADR.md](<ADR.md>):3488-3495 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — no universal undo

</details>

---

<a id="fw-p2-09"></a>

## FW-P2-09 — Transaction Notes

**Status:** Candidate
**Depends on:** Targeted transaction metadata mutation

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** User-note ownership, retention/deletion and mutation semantics are not selected.

**Smallest proposed boundary:** Separate user-authored metadata.

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P2-09 | **User product choice:** whether user-authored transaction notes are needed. | Notes add private metadata, retention/deletion, and export considerations. | Defer notes. | Separate user note metadata, never source alteration. | — | A unless a current workflow needs notes. | No note field. | Bounded note ownership/lifecycle packet. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: Imported financial values/provenance are immutable; no note relation exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Transaction Notes: establish the smallest truthful product boundary. PROPOSED: Separate user-authored note metadata, never source alteration. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Note ownership, privacy, mutation and deletion/retention semantics. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Notes must not alter imported evidence.

**Exact next evidence or decision:** Note privacy and lifecycle decision.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Candidate **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Sync/export/retention.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** PRIVACY, DURABLE_PERSISTENCE, USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_USER_DECISION` → `decision-transaction-note-policy`: Privacy/retention.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-09`: User-note ownership, retention/deletion and mutation semantics are not selected.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1113-1185 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-09
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1321-1361 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Source truth must stay immutable.

</details>

---

<a id="fw-p2-10"></a>

## FW-P2-10 — Transfer Matching Between Owned Accounts

**Status:** Ready for discovery
**Shared prerequisites:** Sprint 40 evidence is complete, and Sprint 53 verifies distinct durable identity for multiple supported owned accounts.
**Implementation dependency:** Independently provable transfer evidence and a reversible family-specific matching contract. Non-source canonical-transaction test values may exercise the algorithm, but financial-source fixtures cannot establish ingestion support.

Match both sides of owned-account transfers without counting them as new income or expense.

Targeted discovery must define:

- independently provable transfer evidence;
- same-currency and future cross-currency boundaries;
- one-to-one, split and fee-bearing cases;
- date and amount tolerances, if any;
- conflict and ambiguity handling;
- explanation and user review;
- durable relationship provenance;
- unmatch or correction semantics;
- interaction with duplicate-event evidence and reconciliation.

Weak similarity must never create a transfer relationship automatically.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** The only inspected two-owned-account counterparty-shape evidence is ambiguous: source currency is absent and both candidate pairs lack matching nonempty reference/narration digests. A source-proven transfer pair and relation contract remain required.

**Smallest proposed boundary:** No transfer persistence; retain a future read-only candidate relation only after sufficient source evidence.

**Decision record:** [TRANSFER_FAMILY_DECISION_PACKET](#packet-transfer-family-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: distinct account identity and duplicate blocking exist; no transfer relation is persisted.

**First-round scope and constraints:** Weak similarity cannot auto-match; one-to-one, split, fee, same/cross currency, conflict, unmatch and review all remain separate choices. No automatic matching, income/expense recoding, FX or reconciliation.

**First-round question/options:** Prove and record owned-account transfer relationships. PROPOSED begin same-currency, exact one-to-one evidence-only review; defer tolerance/split/fee/cross-currency.

**First-round remainder and implications:** MISSING independently provable transfer evidence and approved relation/reversal contract. Likely relation/audit schema; no number.

**First-round proposed acceptance/falsifier:** Independent oracle distinguishes transfer from coincidence; ambiguity blocks; relation survives hydration/reopen; unmatch contract proved. Need for a date/amount tolerance unsupported by source proof.

**Second-round new evidence/resolved direction:** See new_authentic_source_evidence.axis_bank; it disproves promotion from amount/date coincidence.

**Exact next evidence or decision:** Same-currency source fact, debit/credit relation, exact amount and bounded date rule plus independent transfer oracle.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Ready for discovery **Roadmap:** Sprint 93 entry gate remains unmet

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** currency, reference, or source-proven counterparty conflict.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=true, authentic source=true. **Blocker types:** SOURCE_TRUTH, FINANCIAL_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-owned-transfer-pair`: independent financial truth
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `accepted-adr-037`: later correctable relation
- `REQUIRES_POST_SWIFT6` → `FW-P2-74`: provider ownership delta

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1188-1208 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-10
- [LedgerForgeTests/GlobalAuthenticCorpusAcceptanceTests.swift](<../LedgerForgeTests/GlobalAuthenticCorpusAcceptanceTests.swift>):6-13 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — source facts precede production preparation

</details>

<a id="packet-transfer-family-decision-packet"></a>

<details>
<summary>TRANSFER_FAMILY_DECISION_PACKET — complete proposed decision packet</summary>

## TRANSFER_FAMILY_DECISION_PACKET — `FW-P2-10`, with duplicate/reconciliation closure

1. **Owning FW IDs:** `FW-P2-10`, `FW-P2-11`, `FW-P2-12`; informs `FW-P0-19`, `FW-P0-20`, `FW-P1-25`, and `FW-P1-35`.
2. **User problem:** Explain genuine transfers between owned accounts without adding income/expense, suppressing real transactions, or converting coincidence into a financial fact.
3. **Verified current state:** Distinct account identity and import duplicate/event blocks exist; no transfer relation is persisted.
4. **Accepted authorities:** ADR-037, ADR-042/043/044 bounded source relationships, ADR-046, and the current/prepared roadmaps.
5. **Exact missing decision:** A source-proven transfer relation family and its creation/removal semantics.
6. **Evidence acquired:** The two-account Axis-bank independent source oracle yields exactly two amount/date/opposite-direction shapes, but no source currency and no shared nonempty reference/narration digest.
7. **Options considered:** (A) auto-match coincidence; (B) exact same-currency one-to-one reviewable relation; (C) fee/split/FX/remittance/card-payment family; (D) defer.
8. **Recommended option:** D now. If a later authentic pair proves every criterion, bring B to Chat as the first relation family.
9. **Why competing options are rejected:** A is contradicted by source evidence; C expands semantics before B is proven; B lacks currency and counterparty controls in the currently inspected corpus.
10. **Smallest coherent implementation boundary:** Future B only: persisted *reviewed relation* between exactly two existing canonical transactions, never a transaction rewrite.
11. **Included scope:** One debit/one credit; two proven owned accounts; same source-proven currency; exact absolute Money equality; a declared bounded date rule; independent counterparty/reference control; explicit review.
12. **Explicit exclusions:** Fees, splits, cross currency, remittances, card payments, salary receipts, same-day collision inference, reversals, partial evidence, automatic matching, recategorization, and reconciliation mutation.
13. **Durable model/persistence requirements:** Pair relation with two immutable transaction references, source/provenance digests, relation status, plan digest/preconditions, creation audit, and removal/compensation audit; source transactions remain immutable.
14. **Migration impact:** `REQUIRES_DECISION` if a durable relation is accepted; do not allocate a version.
15. **ADR impact:** `NEW_ADR_REQUIRED` for a source-proven transfer relation; ADR-037 supplies lifecycle only.
16. **Privacy/security boundary:** UI/audit show relationship reason categories and opaque digests/counts, never raw narration, reference, account IDs, paths, or values beyond approved normal product presentation.
17. **SQLite/In-Memory implications:** The same plan/precondition/conflict/relation/removal contract is required in both providers; provider generation must reject stale plans.
18. **Hydration/relaunch implications:** Hydration must expose only a proven relation view; reopen must reproduce relation/provenance without recategorizing transactions.
19. **Independent acceptance oracle:** Authentic source pair plus an independent source oracle proving account ownership, native currency, directions, exact amounts, date relation, and counterparty control; production parser/database is never the oracle.
20. **Failure cases:** Missing currency, non-unique candidate, missing/unequal counterparty control, unequal Money/scale, date-rule breach, stale plan, existing incompatible relation, source conflict, or hydration discrepancy fail closed.
21. **Reversal/correction semantics:** A later explicit unmatch removes only the derived relationship after stale-plan revalidation and creates audit evidence; it never deletes, changes, recategorizes, or reimports either transaction. The exact inverse remains unapproved pending ADR.
22. **Source evidence requirement:** Mandatory. Current evidence is insufficient and must not be supplemented with generated statements or parser output.
23. **Runtime acceptance requirement:** After post-Swift-6 provider/migration changes settle: authentic-pair review/confirmation, SQLite/In-Memory parity, reopen/hydration, and no double-counting in a read-only reconciliation projection.
24. **Dependencies:** A sufficient authentic pair/oracle; Chat ADR approval; post-87 delta validation; `FW-P2-12` taxonomy review before `FW-P2-11`/Sprint 97.
25. **Evidence that falsifies the recommendation:** An authentic supposedly eligible pair has ambiguous source ownership/currency/reference, or the relation changes native financial facts or cannot be removed without collateral changes.
26. **Personal-v1 relevance:** `PRE_V1_OPTIONAL`; no certification dependency has been adopted.
27. **Recommended FUTURE_WORK status after Chat review:** `FW-P2-10` remains `Ready for discovery` / `BLOCKED_ON_AUTHENTIC_SOURCE`; `FW-P2-11` remains blocked; `FW-P2-12` may become planning-ready only for read-only taxonomy.
28. **Recommended roadmap effect after Chat review:** Sprint 93 entry gate remains unmet; Sprint 94 remains gated. No date, number, or priority changes.

### Transfer / duplicate taxonomy

| Relationship | Current authority | New evidence result | Correct action |
|---|---|---|---|
| Exact content duplicate | Existing exact source-byte fingerprint authority | Not re-investigated as a new relation | Existing reject/attempt outcome remains bounded. |
| Transaction-event duplicate | Existing supported Axis UPI authority | Cross-account shapes have no matching nonempty source digest | Do not call them event duplicates. |
| Accepted whole-statement equivalence | ADR-042 HDFC; bounded Axis-card contract | HDFC reconfirmed; no new pair | Preserve existing family limits. |
| Historical duplicate | No affected durable database supplied | No source fact identifies historical residue | Verifier first; no repair. |
| Same-format byte-different semantic duplicate | Explicitly unsupported by ADR-042 | No candidate established | Fail closed. |
| Ambiguous candidate | No existing relation authority | 2 Axis-bank date/amount/opposite-direction shapes | Label ambiguous only; no durable relation, suppression, or financial rewrite. |

### Conditional ADR candidate — source-proven owned-account transfer relation

- **Context:** source and canonical records may need a durable, reviewable explanation for one genuine internal transfer, while original transactions remain financial truth.
- **Decision:** only after a real pair satisfies the packet's oracle, allow one reviewed exact same-currency one-to-one relationship; never automatic matching.
- **Alternatives:** fuzzy scoring; date/amount-only matching; recoding income/expense; fees/splits/FX in v1; all rejected as broader or contradicted by current evidence.
- **Consequences:** likely additive relation/audit storage and provider/hydration work; no source replacement or duplicate suppression authority.
- **Migration impact:** `REQUIRES_DECISION`; no number reserved.
- **Acceptance contract:** authentic pair/oracle, exact native-Money equality, two accounts, currency, directions, bounded date/counterparty rule, stale-plan rejection, provider parity, hydration/reopen, no double count, and explicit unmatch.
- **Supersession/alignment:** aligns ADR-037; does not amend ADR-042/043/044, duplicate rules, or parser authority without explicit Chat review.

</details>

---

<a id="fw-p2-11"></a>

## FW-P2-11 — Reconciliation Workflow

**Status:** Blocked
**Depends on:** `FW-P2-10` and transaction provenance

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** FW-P2-10 source/architecture gate and reconciliation period/exception policy remain absent.

**Smallest proposed boundary:** Read-only unexplained-item report after transfer provenance.

**Decision record:** [TRANSFER_FAMILY_DECISION_PACKET](#packet-transfer-family-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: statement-level parser reconciliation exists, not a user transaction reconciliation workflow.

**First-round scope and constraints:** Reconciliation depends on durable transaction provenance and transfer semantics; must not infer financial truth from display state. No bank-statement parsing change or repair.

**First-round question/options:** Reconcile owned-account history. PROPOSED define statement/source reconciliation before ledger workflow.

**First-round remainder and implications:** FW-P2-10 and selected reconciliation evidence/period/exception policy. Unknown.

**First-round proposed acceptance/falsifier:** Reconciliation reports unexplained items without changing transactions; transfer matches do not double-count. Period/statement controls unavailable.

**Second-round new evidence/resolved direction:** No transfer was established; reconciliation cannot treat ambiguous shapes as matched.

**Exact next evidence or decision:** Accepted transfer relation and user/Chat reconciliation boundary.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Blocked **Roadmap:** Sprint 94 remains gated

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** missing statement controls.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-10`: transfer provenance
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-11`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. FW-P2-10 source/architecture gate and reconciliation period/exception policy remain absent.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p2-11`: Authentic source statements for both sides of the selected reconciliation period, known balances/controls and independently proven transfer/exception relationships.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1212-1215 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-11
- [Project documents/ADR.md](<ADR.md>):6000-6035 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-046 validation
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):66-72 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — accepted transfer provenance is entry gate

</details>

---

<a id="fw-p2-12"></a>

## FW-P2-12 — Duplicate-Transaction Review

**Status:** Ready for discovery
**Depends on:** Completed Sprint 40 overlap evidence and Sprint 41 bounded transaction-event enforcement

Retain future work for speculative duplicate-transaction candidates, unsupported transaction-event families, historical duplicate review and repair, and workflows requiring reversible mutation. The approved durable-attempt-history increment explains supported Axis UPI transaction-event blocking only.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Chat must approve a read-only candidate taxonomy and evidence threshold; no mutation/rejection expansion is proposed.

**Smallest proposed boundary:** Read-only candidate classification with explanation and no suppression.

**Decision record:** [TRANSFER_FAMILY_DECISION_PACKET](#packet-transfer-family-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: supported Axis UPI event duplicates block import; exact statement duplicates reject; historical/speculative review is absent.

**First-round scope and constraints:** No static risk is a defect; any mutation requires a reversible ADR-037 family. No fuzzy suppression, cleanup or session reversal.

**First-round question/options:** Review speculative duplicate transactions beyond supported blocking. PROPOSED evidence-only review separate from P0 historical repair.

**First-round remainder and implications:** Selected review evidence threshold and source/oracle family. No migration for review.

**First-round proposed acceptance/falsifier:** Known weak coincident pair remains candidate; proof and scope required for any repair. Candidate relies on metadata similarity alone.

**Second-round new evidence/resolved direction:** Two source counterparty-shape collisions remain ambiguous rather than duplicate or transfer, proving taxonomy needs a distinct ambiguous state.

**Exact next evidence or decision:** Existing exact/event authority plus candidate label policy.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Ready for planning **Roadmap:** Reevaluate before Sprint 94/97

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** candidate becoming source-proven relation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `FW-P1-25`: prior-import context
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-12`: Chat must approve a read-only candidate taxonomy and evidence threshold; no mutation/rejection expansion is proposed.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1219-1224 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-12
- [Services/ImportPersistenceCoordinator.swift](<../Services/ImportPersistenceCoordinator.swift>):1864-1873 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `052b8de5c2de61349a5151d676e1dade3ec005363fb82f4eed290822bea2cfae` — event block
- [Services/ImportPersistenceCoordinator.swift](<../Services/ImportPersistenceCoordinator.swift>):1857-1889 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — exact and event outcomes are distinct

</details>

---

<a id="fw-p2-21"></a>

## FW-P2-21 — Deterministic Categorization Rules

**Status:** Ready for discovery
**Depends on:** Sprint 57 durable category foundation — complete

Sprint 57 completed the manual category foundation with additive Migration V8, durable user-created categories, manual single-transaction classification, SQLite/In-Memory parity, canonical hydration and bounded Settings/transaction UI. It did not implement automatic classification or any rule behavior.

Discovery for this candidate must preserve imported transaction immutability, manual assignments, explicit user control and explainability. It must not infer implementation authority from the completed category foundation.

**Current discovery disposition — 2026-09-10:** `DECISION_CLOSED_BY_EXPLICIT_USER_DECISION`. **Exact remaining gate:** User selected reviewable suggestions; Chat still must accept predicate/scope/version and detailed architecture.

**Smallest proposed boundary:** Pure proposal with rule/version/input explanation; manual assignment wins.

**Decision record:** [FIRST_RULE_ENGINE_DECISION_PACKET](#packet-first-rule-engine-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: CategoryRepository exposes create/rename/archive/delete-unused and assignment; CategoryManagementCoordinator performs a targeted write then forced canonical hydration. Static tests cover category repository behavior. No production rule predicate, automatic assignment, precedence or explanation record was found in this inspected boundary.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Deterministic Categorization Rules: establish the smallest truthful product boundary. PROPOSED: a deterministic rule may produce a proposed category plus rule ID/version, ordered input facts and blocking reason; manual assignment remains authoritative until a separately accepted precedence policy says otherwise. Do not learn from corrections or introduce AI classification in this boundary.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Rule predicate/scope/version and manual-versus-rule precedence. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** The same trusted snapshot/rule version yields identical proposal/explanation; missing or conflicting inputs yield no proposal; a manual assignment is never overwritten; a proposed result survives no persistence/hydration because it has none. A later apply family must separately prove provider parity and canonical hydration. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** 2026-09-10 user answer: reviewable suggestions first; automatic application later.

**Exact next evidence or decision:** Authentic source-backed canonical integration input and independent projection; isolated predicate mechanics may use nonfinancial values, not statement-shaped DTO graphs.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Ready for Chat architecture decision **Roadmap:** Supports prepared 95 only after architecture acceptance

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Any durable auto-apply or ambiguous fact.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** ARCHITECTURE_DECISION, PROVENANCE, MUTATION_SEMANTICS.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-21`: User selected reviewable suggestions; Chat still must accept predicate/scope/version and detailed architecture.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p2-21`: Authentic source-backed canonical records and independent expected category-suggestion/conflict projection; isolated predicates may use nonfinancial values, never statement-shaped fixtures.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1230-1305 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-21
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Services/CategoryManagementCoordinator.swift](<../Services/CategoryManagementCoordinator.swift>):117-148,256-292 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `f43a45ec207ab9ceeeeb306f600956a4596b145bbf705b32a0a2c1bcbead5642` — CategoryManagementCoordinator.setCategory and mutate
- [LedgerForgeTests/CategoryRepositoryTests.swift](<../LedgerForgeTests/CategoryRepositoryTests.swift>):1-300 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `3a5ecd33125ccff21b12b030e77865fab721677d9827ffd1bd65e28515c7a23f` — category repository contract tests
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1230-1305 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Manual category foundation exists; no rules.

</details>

<a id="packet-first-rule-engine-decision-packet"></a>

<details>
<summary>FIRST_RULE_ENGINE_DECISION_PACKET — complete proposed decision packet</summary>

## FIRST_RULE_ENGINE_DECISION_PACKET

1. **Owning FW IDs:** FW-P2-21, FW-P2-22, FW-P2-23; consequential boundaries
FW-P2-24, FW-P2-27, FW-P2-29. The recommended first engine is **read-only
deterministic category proposals**. It does not create a durable category
assignment or alter imported financial fields.

**Exact user-decision log — 2026-09-10:** The question put to the user was
whether the first rules should only suggest categories for review, preserve
manual assignments, and return an explicit conflict when matching rules
disagree, with automatic application left for later. The user selected
**“Use reviewable suggestions first (Recommended)”**. This resolves that
narrow product-policy question only. It does **not** accept the predicate
language, durable model, migration, broad priority/disablement policy, ADR,
or implementation.

2. **User problem:** repeatable categorization without hidden financial edits.
3. **Verified current state:** durable manual category assignment exists;
   repository inspection found no production rule, priority, or result record.
4. **Accepted authorities:** immutable import truth and ADR-046 provenance
   direction; the prepared roadmap also requires manual assignments to remain
   authoritative.
5. **Exact missing decision:** predicate vocabulary, scope, versioning, and
   detailed later precedence/disablement architecture; the first-mode product
   choice is resolved by the recorded user answer.
6. **Evidence acquired:** category mutation/hydration is a bounded existing
   mechanism; it does not establish automatic assignment.
7. **Options considered:** direct auto-apply; proposal-only; learned/AI
   classification.
8. **Recommended option:** proposal-only, evaluated against one trusted,
   hydrated canonical snapshot and an explicit rule version.
9. **Why competing options are rejected:** auto-apply needs correction/reversal and
   durable provenance; learning/AI would not be deterministic authority.
10. **Smallest coherent implementation boundary:** a rule yields either one proposed category
   plus explanation, or an explicit no-proposal reason.
11. **Included scope:** exact/normalized exact text, bounded prefix/suffix or
    contains only if selected; account scope, direction, native currency,
    amount range, date interval, and existing manual assignment as a blocking
    fact.
12. **Explicit exclusions:** source parsing, source-description changes,
    rule learning, recurrence, automatic writes, alerts, cross-currency
    arithmetic, and AI authority.
13. **Durable model/persistence requirements:** none for first evaluation;
    rule definitions are a later separately accepted persistence decision.
14. **Migration impact:** NONE for a pure evaluation boundary.
15. **ADR impact:** NEW_ADR_REQUIRED before durable rules or any apply action;
    ALIGN_EXISTING for immutable-source and provenance constraints.
16. **Privacy/security boundary:** explain only approved display-safe input
    facts; never expose raw identifiers, hidden source fragments, or credentials.
17. **SQLite/In-Memory implications:** first engine is pure over a supplied
    snapshot; later persistence must prove parity.
18. **Hydration/relaunch implications:** no new state survives hydration;
    later rules/results must define hydration semantics.
19. **Independent acceptance oracle:** independently enumerate trusted
    canonical transaction IDs and rule inputs, then recompute the same outcome.
20. **Failure cases:** absent/malformed predicate, stale snapshot, unknown
    category, unsupported field, mixed/ambiguous facts, or more than one
    applicable rule that disagrees with another applicable rule returns explicit conflict and no proposal, regardless of priority.
21. **Reversal/correction semantics:** none because proposal-only makes no
    change; a manual assignment is authoritative and blocks a proposal.
22. **Source evidence requirement:** pure source-independent predicate mechanics may use nonfinancial primitives; statement-dependent integration requires authentic source-backed canonical inputs and independent source projection;
    source-independent canonical values may validate pure mechanics.
23. **Runtime acceptance requirement:** later UI explanation presentation,
    not this decision packet.
24. **Dependencies:** completed category foundation; Chat decision; FW-P2-22
    and FW-P2-23 are required parts of the same first-engine safety boundary.
25. **Evidence that falsifies the recommendation:** any necessary result that cannot be explained
    from declared fields/version or a case where a manual value is overwritten.
26. **Personal-v1 relevance:** POST_V1; it is neither parser reliability nor
    adoption certification.
27. **Recommended FUTURE_WORK status after Chat review:** FW-P2-21 through 23 become ready for
    planning only after Chat accepts this boundary; 24/27/29 remain dependent.
28. **Recommended roadmap effect after Chat review:** the prepared Sprint 95 combination is
    coherent only as proposal + explanation + explicit conflict behavior.
**Additional decision detail:** no additional user decision is needed for the
    initial reviewable-suggestion mode. Chat must decide the remaining
    architecture fields before planning.

**Compact ADR candidate — deterministic proposal rules.**

- **Context:** manual categories are durable, while automatic classification
  has no accepted rule or correction contract.
- **Decision:** authorize only versioned, explainable, read-only proposals;
  manual assignment wins and any disagreement among applicable rules produces explicit conflict; no priority winner is authorized.
- **Alternatives:** direct durable auto-apply; inferred learning; AI decision.
- **Consequences:** no migration now; a later rule-definition/result store or
  apply action requires separate ADR/migration/rollback review.
- **Acceptance:** snapshot/rule version produces identical output; independent
  input enumeration agrees; conflict/missing input and manual assignment yield
  no unauthorized write.
- **Alignment:** preserves ADR-046 source immutability and the prepared
  roadmap’s explicit/manual/explainable direction.

</details>

---

<a id="fw-p2-22"></a>

## FW-P2-22 — Explainable Rule Results

**Status:** Blocked
**Depends on:** `FW-P2-21`

Every automatic categorization must explain the rule that produced it.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Requires accepted FW-P2-21 rule-result contract.

**Smallest proposed boundary:** Per-result deterministic explanation.

**Decision record:** [FIRST_RULE_ENGINE_DECISION_PACKET](#packet-first-rule-engine-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No automatic rule result exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Explainable Rule Results: establish the smallest truthful product boundary. PROPOSED: Per-result rule/version/input explanation. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: FW-P2-21 rule contract. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Explanation is a necessary first-engine safety field.

**Exact next evidence or decision:** Rule/version/input and blocking explanation.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Combine with first engine **Roadmap:** Prepared 95 safety boundary

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Missing provenance.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-21`: No result exists without rule contract.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1230-1305 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-22
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1230-1305 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Depends on FW-P2-21.

</details>

---

<a id="fw-p2-23"></a>

## FW-P2-23 — Rule Priority and Conflict Handling

**Status:** Blocked
**Depends on:** `FW-P2-21`

**Current discovery disposition — 2026-09-10:** `DECISION_CLOSED_BY_EXPLICIT_USER_DECISION`. **Exact remaining gate:** User chose explicit disagreement; Chat still must define any later priority/disablement architecture.

**Smallest proposed boundary:** Manual assignment wins; applicable conflicting rules return no proposal.

**Decision record:** [FIRST_RULE_ENGINE_DECISION_PACKET](#packet-first-rule-engine-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No priority/conflict resolution exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Rule Priority and Conflict Handling: establish the smallest truthful product boundary. PROPOSED: Deterministic conflict matrix before writes. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Explicit precedence, ties, disablement and manual-override rules. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** 2026-09-10 user answer: matching rules that disagree return explicit conflict.

**Exact next evidence or decision:** Two matching rules and deterministic explicit-conflict behavior.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Ready for Chat architecture decision **Roadmap:** Prepared 95 safety boundary

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Hidden priority/automatic winner.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, ARCHITECTURE_DECISION, MUTATION_SEMANTICS.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-21`: Rule language first.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1230-1305 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-23
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):74-80 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Conflicts explicit; manual authoritative.

</details>

---

<a id="fw-p2-24"></a>

## FW-P2-24 — User Corrections as Reusable Rules

**Status:** Blocked
**Depends on:** `FW-P2-21` through `FW-P2-23`

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Needs correction provenance, explanation and conflict policy.

**Smallest proposed boundary:** Explicit rule suggestion, never automatic learning.

**Decision record:** [FIRST_RULE_ENGINE_DECISION_PACKET](#packet-first-rule-engine-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: Manual category assignment is not an inferred reusable rule.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** User Corrections as Reusable Rules: establish the smallest truthful product boundary. PROPOSED: Opt-in rule suggestion, never automatic learning. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Correction provenance and rule/explanation/conflict policy. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Manual assignment is not reusable learning.

**Exact next evidence or decision:** Opt-in proposed rule with source/manual distinction.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Follow-on after 95

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Inferred rule from correction.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-21`: Rule contract.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-23`: Conflict policy.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-24`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Needs correction provenance, explanation and conflict policy.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1230-1305 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-24
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1555-1569 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Original descriptions retained.

</details>

---

<a id="fw-p2-25"></a>

## FW-P2-25 — Merchant and Payee Normalization

**Status:** Blocked
**Depends on:** Stable correction and provenance rules

The original imported transaction description must remain preserved.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Needs derived display alias provenance/confidence/ambiguity contract.

**Smallest proposed boundary:** Derived display normalization retaining exact source text and no inferred identity.

**Decision record:** [RECURRING_ACTIVITY_EVIDENCE_PACKET](#packet-recurring-activity-evidence-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: Original imported description remains preserved; no normalized payee authority exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Merchant and Payee Normalization: establish the smallest truthful product boundary. PROPOSED: Derived display normalization with source text retained. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Stable correction/provenance model and confidence/ambiguity contract. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Original imported descriptions are immutable.

**Exact next evidence or decision:** Canonical transaction snapshots, user-approved aliases; no fabricated statements.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Ready after Chat decision **Roadmap:** Prepared 96 gate

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Source overwrite/weak alias confidence.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION, PROVENANCE, PRIVACY.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-21`: Provenance/explanation foundation.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-25`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Needs derived display alias provenance/confidence/ambiguity contract.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1230-1305 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-25
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1555-1557 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No normalized payee authority.

</details>

---

<a id="fw-p2-26"></a>

## FW-P2-26 — Recurring Transaction and Subscription Detection

**Status:** Blocked
**Depends on:** Reliable duplicate handling and normalized payee evidence

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Needs duplicate-safe normalized evidence and approved recurrence state.

**Smallest proposed boundary:** Explainable candidate suggestion only; confirmation separate.

**Decision record:** [RECURRING_ACTIVITY_EVIDENCE_PACKET](#packet-recurring-activity-evidence-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No recurrence model exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Recurring Transaction and Subscription Detection: establish the smallest truthful product boundary. PROPOSED: Explainable recurrence candidates, never confirmed obligations. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Normalized payee plus duplicate-safe evidence and deterministic recurrence versus suggestion policy. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Cadence never proves merchant identity or confirmed obligation.

**Exact next evidence or decision:** Real canonical recurrence evidence, no manufactured cadence cases.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Prepared 96 after gates

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Duplicate/missing/ambiguous evidence.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, PROVENANCE, IDENTITY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-25`: Normalized evidence.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-19`: Duplicate-safe relationship boundary.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-26`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Needs duplicate-safe normalized evidence and approved recurrence state.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1230-1305 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-26
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1562-1569 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No recurrence model exists.

</details>

<a id="packet-recurring-activity-evidence-packet"></a>

<details>
<summary>RECURRING_ACTIVITY_EVIDENCE_PACKET — complete proposed decision packet</summary>

## RECURRING_ACTIVITY_EVIDENCE_PACKET

1. **Owning FW IDs:** FW-P2-25, FW-P2-26, FW-P2-27, FW-P2-28, FW-P3-09, FW-P3-14.

2. **User problem:** identify possible recurring activity without inventing
   merchant identity or obligations.
3. **Verified current state:** imported descriptions are preserved; no
   normalized-payee or recurrence model exists.
4. **Accepted authorities:** ADR-046 source semantics; prepared Sprint 96 says
   recurrence must separate a deterministic suggestion from confirmed state.
5. **Exact missing decision:** user-facing normalized alias provenance,
   recurrence-evidence threshold, confirmation and alert ownership.
6. **Evidence acquired:** cadence alone is insufficient; a repeat pattern does
   not prove merchant identity.
7. **Options considered:** automatic merchant merge/obligation; suggestion
   candidates; manually confirmed obligations.
8. **Recommended option:** derived display alias only when explicitly
   attributable, then recurrence **candidate** with exact evidence fields;
   confirmed obligation is a later user action.
9. **Why competing options are rejected:** automatic identity/obligation would
   conflate source fact, derivation and user assumption.
10. **Smallest coherent implementation boundary:** non-durable candidate lists with reason,
   source membership and blocking ambiguity.
11. **Included scope:** observed dates, native-currency amounts, direction,
    account scope, source-preserving display alias, eligible trusted records.
12. **Explicit exclusions:** editing descriptions/payees, automatic category
    change, notification delivery, payment instruction, FX and forecast.
13. **Durable model/persistence requirements:** NONE initially; a confirmed
    obligation must separately persist user confirmation and its provenance.
14. **Migration impact:** NONE initially; LIKELY_ADDITIVE only for a later
    confirmed-obligation model.
15. **ADR impact:** ALIGN_EXISTING for source immutability; NEW_ADR_REQUIRED
    before durable alias/obligation/notification authority.
16. **Privacy/security boundary:** all derived display labels retain source
    distinction; no hidden identifiers/source bytes enter the candidate.
17. **SQLite/In-Memory implications:** candidate computation is pure; a
    persisted confirmation later requires parity.
18. **Hydration/relaunch implications:** none initially; no candidate becomes
    a durable fact simply by relaunch.
19. **Independent acceptance oracle:** approved canonical ID/date/amount
    membership list and independently calculated cadence; real private facts
    may be used only through existing source-derived canonical evidence.
20. **Failure cases:** duplicate/overlap uncertain, alias ambiguity, absent
    dates, currency mismatch, insufficient observations, or conflicting
    directions yields no candidate.
21. **Reversal/correction semantics:** a later confirmation must be reversible
    user metadata and may never edit imports; no reversal exists initially.
22. **Source evidence requirement:** statement-independent mechanics may use
    nonfinancial data; real recurrence claims need existing canonical evidence,
    not fabricated financial graphs.
23. **Runtime acceptance requirement:** later candidate/confirmation UI,
    accessibility and notification behavior require native review.
24. **Dependencies:** accepted first rule provenance, reliable duplicate
    relationship policy, and an explicit alias/confirmation decision.
25. **Evidence that falsifies the recommendation:** any cadence-only alias, a duplicate counted
    twice, or an automatically confirmed obligation.
26. **Personal-v1 relevance:** POST_V1.
27. **Recommended FUTURE_WORK status after Chat review:** FW-P2-25 ready for Chat decision;
    FW-P2-26 and dependent candidates remain named-dependency blocked.
28. **Recommended roadmap effect after Chat review:** Sprint 96 stays gated; do not combine
    candidate detection with obligation planning/alerts.
**Additional decision detail:** approve suggestion-only recurrence, with a separate
    explicit confirmation boundary and no automatic notifications.

</details>

---

<a id="fw-p2-27"></a>

## FW-P2-27 — Automatic Transaction Classification

**Status:** Blocked
**Depends on:** Category, rule, normalization and explanation foundations

Deterministic rules take precedence over AI-assisted suggestions.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Needs category/rule/normalization/explanation foundations.

**Smallest proposed boundary:** Read-only deterministic result, no source mutation.

**Decision record:** [FIRST_RULE_ENGINE_DECISION_PACKET](#packet-first-rule-engine-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: Manual category is accepted; no automatic classification exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Automatic Transaction Classification: establish the smallest truthful product boundary. PROPOSED: Deterministic rule results; AI only later suggestion. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Category/rule/normalization/explanation foundations. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** No automatic classification exists.

**Exact next evidence or decision:** Accepted deterministic results; AI remains later suggestion.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Follow-on

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Automatic durable assignment.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, MUTATION_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-21`: Rule.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-25`: Normalization.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1230-1305 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-27
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1574-1583 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Deterministic before AI.

</details>

---

<a id="fw-p2-28"></a>

## FW-P2-28 — Smart Deterministic Alerts

**Status:** Blocked
**Depends on:** Categorization, recurring detection or another approved rule source

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** No trusted alert source or notification ownership.

**Smallest proposed boundary:** Explain eligibility, do not notify or mutate.

**Decision record:** [RECURRING_ACTIVITY_EVIDENCE_PACKET](#packet-recurring-activity-evidence-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No trusted alert source exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Smart Deterministic Alerts: establish the smallest truthful product boundary. PROPOSED: Read-only alert eligibility explanation. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Selected rule/recurrence/category source and notification ownership. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Read-only eligibility explanation is smallest boundary.

**Exact next evidence or decision:** Selected fact/rule/recurrence source and user alert policy.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Unselected notification policy.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-21`: Rule source.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-26`: Recurrence source.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-28`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. No trusted alert source or notification ownership.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1230-1305 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-28
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1588-1595 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No trusted alert source.

</details>

---

<a id="fw-p2-29"></a>

## FW-P2-29 — Explainable Rules Engine v2

**Status:** Blocked
**Depends on:** Stable category, transaction, account, provenance and reversible-action models

Define a general deterministic rules engine for explainable financial automation beyond categorization alone.

Candidate capabilities may include:

- multi-condition rules;
- explicit priority and conflict resolution;
- dry-run previews;
- account, transaction, merchant, amount, date and recurrence predicates;
- actions that never alter original imported financial truth;
- complete reasoning and provenance for every result;
- user-controlled enablement, disabling and rollback;
- testable rule versioning.

Rules must remain deterministic before any AI-assisted suggestion layer is considered.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Needs stable provenance and reversible action models.

**Smallest proposed boundary:** Dry-run deterministic rules only.

**Decision record:** [FIRST_RULE_ENGINE_DECISION_PACKET](#packet-first-rule-engine-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No general rules engine exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Explainable Rules Engine v2: establish the smallest truthful product boundary. PROPOSED: Dry-run deterministic rules; no original-financial mutation. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Stable category, transaction/account provenance and reversible-action models. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** General engine should begin as dry-run.

**Exact next evidence or decision:** Accepted initial rule result and action-family contracts.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Original financial mutation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, MUTATION_SEMANTICS, REVERSIBILITY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-21`: First engine.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `accepted-adr-037`: Any future action.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-29`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Needs stable provenance and reversible action models.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1230-1305 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-29
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1600-1622 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Dry-run proposed.

</details>

---

<a id="fw-p2-30"></a>

## FW-P2-30 — Broader Account Metadata Editing

**Status:** Candidate
**Depends on:** Existing targeted display-name mutation

Define the targeted repository mutation, validation and hydration foundation required for editable account metadata beyond display name while preserving immutable account identity, identifiers, sessions and transactions.

Field-specific product work remains separately tracked in `FW-P2-31`, `FW-P2-32` and `FW-P2-36`.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Choose one non-identity metadata field and field authority.

**Smallest proposed boundary:** One metadata field with provider/hydration parity.

**Decision record:** [ACCOUNT_LIFECYCLE_PACKET](#packet-account-lifecycle-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: Only targeted display-name mutation is accepted.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Broader Account Metadata Editing: establish the smallest truthful product boundary. PROPOSED: One non-identity metadata field with hydration parity. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Field-by-field authority, validation, privacy and lifecycle effects. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Display-name mutation alone is accepted.

**Exact next evidence or decision:** Field-level validation/privacy/lifecycle policy.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Ready after Chat decision **Roadmap:** Do not bundle all metadata

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Identity/identifier/session edits.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION, DURABLE_PERSISTENCE, HYDRATION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-30`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Choose one non-identity metadata field and field authority.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1320-1390 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-30
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1629-1640 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Field authority unresolved.

</details>

---

<a id="fw-p2-31"></a>

## FW-P2-31 — Account Notes

**Status:** Blocked
**Depends on:** `FW-P2-30`

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Needs FW-P2-30 field semantics and note lifecycle policy.

**Smallest proposed boundary:** User metadata separate from financial evidence.

**Decision record:** [ACCOUNT_LIFECYCLE_PACKET](#packet-account-lifecycle-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No account-note contract exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Account Notes: establish the smallest truthful product boundary. PROPOSED: User note metadata separate from financial evidence. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: FW-P2-30 field semantics. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** No account-note contract exists.

**Exact next evidence or decision:** User note ownership/retention/deletion decision.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Follow-on

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Export/sync/privacy.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, PRIVACY, DURABLE_PERSISTENCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-30`: Metadata contract.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-31`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Needs FW-P2-30 field semantics and note lifecycle policy.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1320-1390 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-31
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1645-1652 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Depends on FW-P2-30.

</details>

---

<a id="fw-p2-32"></a>

## FW-P2-32 — Account Colour and Icon Customization

**Status:** Candidate
**Depends on:** Stable account presentation model

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Token/asset persistence and accessible fallback are not selected.

**Smallest proposed boundary:** Presentation-only mapping, no financial semantics.

**Decision record:** [ACCOUNT_LIFECYCLE_PACKET](#packet-account-lifecycle-packet).

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P2-32 | **User product choice:** account colour/icon customization. | Presentation preferences need persistence, accessible fallback, and portability alignment. | Defer; use existing semantics. | Presentation-only token/icon mapping. | — | A until a current visual workflow needs it. | No per-account appearance preference. | Bounded accessible preference design. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No stable account presentation customization contract is accepted.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Account Colour and Icon Customization: establish the smallest truthful product boundary. PROPOSED: Presentation-only colour/icon mapping. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Token/asset persistence and accessibility decisions. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** No customization contract accepted.

**Exact next evidence or decision:** Approved token palette/icon mapping and runtime accessibility acceptance.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Candidate **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Colour-only meaning / accessibility.

**Current gate flags:** user product choice=true, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** ACCESSIBILITY_ACCEPTANCE, PREFERENCE_OWNERSHIP, USER_PRODUCT_DECISION.

**Typed dependencies:**

- `REQUIRES_USER_DECISION` → `decision-account-presentation-preferences`: Preference scope.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1320-1390 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-32
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1657-1664 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Accessibility decision missing.

</details>

---

<a id="fw-p2-33"></a>

## FW-P2-33 — Institution Logos

**Status:** Candidate
**Depends on:** Approved asset and institution-mapping strategy

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Asset licence, institutional mapping and fallback are not selected.

**Smallest proposed boundary:** Bundled presentation assets only.

**Decision record:** [ACCOUNT_LIFECYCLE_PACKET](#packet-account-lifecycle-packet).

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P2-33 | **User product choice:** whether institution logos are useful; asset licensing and identity mapping remain later Chat-owned gates. | Licence, mapping, and fallback can create false financial identity. | No logos; text identity only. | Licensed bundled nonfinancial assets with fallback. | — | A; no current workflow. | No logo assets. | B only after asset policy. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: Institution identity does not presently imply asset identity.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Institution Logos: establish the smallest truthful product boundary. PROPOSED: Bundled, non-financial presentation assets only. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Asset license, mapping and fallback strategy. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Institution identity is not a logo map.

**Exact next evidence or decision:** Licensed bundled asset decision.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Candidate **Roadmap:** Defer

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Remote/logo licensing.

**Current gate flags:** user product choice=true, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** PRIVACY, NO_REAL_USE_CASE, USER_PRODUCT_DECISION.

**Typed dependencies:**

- `REQUIRES_USER_DECISION` → `decision-logo-asset-policy`: Licence/mapping.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1320-1390 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-33
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1627-1664 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Only field-specific candidates exist.

</details>

---

<a id="fw-p2-34"></a>

## FW-P2-34 — Archive and Restore Account

**Status:** Ready for discovery
**Depends on:** Existing targeted account-mutation and repository-identity foundations

Discovery must define account lifecycle semantics, visibility effects and restoration behaviour.

Archiving must not delete financial history.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Archive/restore visibility, import selection and closed-account interaction need decision.

**Smallest proposed boundary:** Archive flag preserves all history; restore explicit.

**Decision record:** [ACCOUNT_LIFECYCLE_PACKET](#packet-account-lifecycle-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: the presentation Account model declares active/archived/closed status and V1 schema contains closed_at, but AccountDTO/repository reads/hydration do not persist or publish a general account lifecycle contract. These are incomplete existing seams, not total absence; no restore workflow or closure-date authority is established.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Archive and Restore Account: establish the smallest truthful product boundary. PROPOSED: Archive flag plus complete history preservation. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Lifecycle visibility, restore, import/selection and closed-account interaction. Account lifecycle semantics/ownership need explicit architecture approval. Inspect and preserve existing closed_at/model status capacity before choosing any additive schema change; no new migration is presumed or allocated.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** AccountStatus exists but no end-to-end durable lifecycle contract does.

**Exact next evidence or decision:** Lifecycle state-transition table and full DTO/repository/hydration mapping.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Ready after lifecycle decision **Roadmap:** Do not combine with close/hide without decision

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** Post-archive imports and totals.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION, DURABLE_PERSISTENCE, HYDRATION, MUTATION_SEMANTICS.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-30`: Account metadata/lifecycle owner.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-34`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Archive/restore visibility, import selection and closed-account interaction need decision.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1320-1390 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-34
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Models/Account.swift](<../Models/Account.swift>):18-22;62 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountStatus and status field
- [Database/Migrations.swift](<../Database/Migrations.swift>):150-164 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — accounts.closed_at
- [Database/DTOs.swift](<../Database/DTOs.swift>):351-390 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `3d481ce8c1d69cbef77687587628a5d8764922fe2d8a4bcd88c7cb4b0ecfd6b3` — AccountDTO
- [Database/SQLiteRepositoryProvider.swift](<../Database/SQLiteRepositoryProvider.swift>):1920-1954 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `29166a1e985c9c4f5b43e6d13243a82fa5ff5e94382747b3fb406ae0dc98b454` — account and accounts queries
- [Services/RepositoryStoreHydrator.swift](<../Services/RepositoryStoreHydrator.swift>):348-361;1913-1956 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `40cbd69a8a470748fcb637cb10ae5597855d5a03771e165d8f551162d2b94117` — canonical account hydration
- [Models/Account.swift](<../Models/Account.swift>):18-22,62 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — active/archived/closed enum exists.
- [Database/DTOs.swift](<../Database/DTOs.swift>):351-378 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — DTO does not carry status.

</details>

<a id="packet-account-lifecycle-packet"></a>

<details>
<summary>ACCOUNT_LIFECYCLE_PACKET — complete proposed decision packet</summary>

## ACCOUNT_LIFECYCLE_PACKET

1. **Owning FW IDs:** FW-P2-30 through FW-P2-37.

2. **User problem:** edit non-identity account information and manage account
   lifecycle without losing history.
3. **Verified current state:** `AccountStatus` has active/archived/closed and
   the historical accounts schema contains `closed_at`; current AccountDTO
   selection and canonical hydration do not carry either. These are capacities,
   not an end-to-end lifecycle contract.
4. **Accepted authorities:** financial identity/provenance remain immutable;
   current repository/hydrator contracts are authority for actual durability.
5. **Exact missing decision:** lifecycle state transitions, closure-date source,
   post-close import rules, archive/hide difference, and field-by-field owner.
6. **Evidence acquired:** current query orders accounts by name/id; status and
   `closed_at` are omitted from current DTO/repository/hydrator flow.
7. **Options considered:** treat existing schema as implemented; add isolated
   archive; unify hide/archive/close; defer.
8. **Recommended option:** one explicit lifecycle state machine, beginning with
   archive/restore that preserves all history; do not claim close support until
   DTO/repository/hydration contract is accepted.
9. **Why competing options are rejected:** existing dormant capacity cannot enforce
   import/visibility/closure semantics or provider parity.
10. **Smallest coherent implementation boundary:** archive/restore visibility state and history
   preservation; close date, hide preferences, notes and presentation remain
   distinct follow-ons.
11. **Included scope:** state transition table, selection/visibility behavior,
    post-archive import policy, hydration/relaunch test plan.
12. **Explicit exclusions:** identity/identifier edits, deletion, historical
    transaction edits, financial reclassification and source changes.
13. **Durable model/persistence requirements:** requires selected lifecycle
    fields end-to-end; existing fields may be reused only after contract proof.
14. **Migration impact:** REQUIRES_DECISION; no migration is presumed merely
    because `closed_at` exists.
15. **ADR impact:** NEW_ADR_REQUIRED for account lifecycle ownership; display
    preferences may later ALIGN with preference architecture.
16. **Privacy/security boundary:** notes/logos/preferences are user metadata;
    never expose identity values or alter imported evidence.
17. **SQLite/In-Memory implications:** both must enforce the same transition,
    allowed import selection and query visibility.
18. **Hydration/relaunch implications:** lifecycle state must round-trip through
    canonical hydration and relaunch, which is currently unproven.
19. **Independent acceptance oracle:** state transition table and a separately
    enumerated expected visible/eligible account set per state.
20. **Failure cases:** unknown state, date without valid transition, post-close
    source conflict, or incomplete DTO/hydrator evidence fails closed.
21. **Reversal/correction semantics:** archive restores explicitly; close
    reversal and closure-date correction need an accepted policy first.
22. **Source evidence requirement:** none; source facts remain immutable.
23. **Runtime acceptance requirement:** later account-selection/navigation and
    accessibility checks.
24. **Dependencies:** FW-P2-30 lifecycle ownership; account presentation and
    preferences separately for hide/ordering/favourites/colour/icon.
25. **Evidence that falsifies the recommendation:** a legacy account whose provider/hydration state
    differs, or any archive/close path that drops history.
26. **Personal-v1 relevance:** PRE_V1_OPTIONAL unless Chat adopts it as an
    adoption boundary.
27. **Recommended FUTURE_WORK status after Chat review:** P2-30/34/36 ready for Chat architecture;
    31/32/33/35/37 remain product-policy gated.
28. **Recommended roadmap effect after Chat review:** do not bundle all account presentation and
    lifecycle candidates.
**Additional decision detail:** approve archive/restore as first lifecycle slice,
    or choose a different single field/state with explicit policy.

</details>

---

<a id="fw-p2-35"></a>

## FW-P2-35 — Hide Account Without Deleting History

**Status:** Candidate
**Depends on:** Account visibility semantics

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Hide is unresolved between view preference and archive/lifecycle, including totals/navigation effects.

**Smallest proposed boundary:** Presentation preference only if chosen.

**Decision record:** [ACCOUNT_LIFECYCLE_PACKET](#packet-account-lifecycle-packet).

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P2-35 | **User product choice:** hide account as view preference versus lifecycle/archive. | It affects totals, navigation, and what complete-account views mean. | Keep all accounts visible. | Presentation-only hide preference; history intact. | Treat as archive/lifecycle. | A until archive semantics are accepted; B later if needed. | No hide setting. | Visibility preference after account lifecycle boundary. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No account visibility contract exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Hide Account Without Deleting History: establish the smallest truthful product boundary. PROPOSED: Presentation preference, not provenance removal. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Whether hide is user-view preference versus lifecycle/archive and effect on totals/navigation. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Hide must not delete provenance.

**Exact next evidence or decision:** Visibility semantics decision.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Candidate **Roadmap:** Defer

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Totals/complete-account views.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** PREFERENCE_OWNERSHIP, USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_USER_DECISION` → `decision-account-visibility`: Hide/archive distinction.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-35`: Hide is unresolved between view preference and archive/lifecycle, including totals/navigation effects.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1320-1390 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-35
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Models/Account.swift](<../Models/Account.swift>):18-22 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Status values do not settle hide semantics.

</details>

---

<a id="fw-p2-36"></a>

## FW-P2-36 — Close-Account Status and Closure Date

**Status:** Blocked
**Depends on:** `FW-P2-30`

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Closure-date authority and allowed post-close imports/transactions are undecided; status/schema capacity is not end-to-end support.

**Smallest proposed boundary:** Status metadata distinct from archive/hide; no migration assumed.

**Decision record:** [ACCOUNT_LIFECYCLE_PACKET](#packet-account-lifecycle-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: the presentation Account model declares active/archived/closed status and V1 schema contains closed_at, but AccountDTO/repository reads/hydration do not persist or publish a general account lifecycle contract. These are incomplete existing seams, not total absence; no restore workflow or closure-date authority is established.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Close-Account Status and Closure Date: establish the smallest truthful product boundary. PROPOSED: Explicit status metadata distinct from archive/hide. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Authority for closure date and allowed post-close imports/transactions. Account lifecycle semantics/ownership need explicit architecture approval. Inspect and preserve existing closed_at/model status capacity before choosing any additive schema change; no new migration is presumed or allocated.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Model has status and old schema has closed_at, but AccountDTO queries/hydration omit both.

**Exact next evidence or decision:** Lifecycle transition/validation contract plus DTO/repository/hydrator propagation proof.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Ready after Chat decision **Roadmap:** No migration allocation

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** Imported post-close evidence, provider parity, relaunch.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION, DURABLE_PERSISTENCE, HYDRATION, MUTATION_SEMANTICS.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-30`: Lifecycle owner.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-36`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Closure-date authority and allowed post-close imports/transactions are undecided; status/schema capacity is not end-to-end support.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1320-1390 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-36
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Models/Account.swift](<../Models/Account.swift>):18-22;62 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountStatus and status field
- [Database/Migrations.swift](<../Database/Migrations.swift>):150-164 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — accounts.closed_at
- [Database/DTOs.swift](<../Database/DTOs.swift>):351-390 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `3d481ce8c1d69cbef77687587628a5d8764922fe2d8a4bcd88c7cb4b0ecfd6b3` — AccountDTO
- [Database/SQLiteRepositoryProvider.swift](<../Database/SQLiteRepositoryProvider.swift>):1920-1954 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `29166a1e985c9c4f5b43e6d13243a82fa5ff5e94382747b3fb406ae0dc98b454` — account and accounts queries
- [Services/RepositoryStoreHydrator.swift](<../Services/RepositoryStoreHydrator.swift>):348-361;1913-1956 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `40cbd69a8a470748fcb637cb10ae5597855d5a03771e165d8f551162d2b94117` — canonical account hydration
- [Models/Account.swift](<../Models/Account.swift>):18-22,62 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — In-memory model capacity.
- [Database/Migrations.swift](<../Database/Migrations.swift>):150-164 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — closed_at schema capacity.
- [Database/SQLiteRepositoryProvider.swift](<../Database/SQLiteRepositoryProvider.swift>):1921-1949 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — closed_at omitted.
- [Services/RepositoryStoreHydrator.swift](<../Services/RepositoryStoreHydrator.swift>):1936-1947 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — status not hydrated.

</details>

---

<a id="fw-p2-37"></a>

## FW-P2-37 — Account Grouping, Ordering and Favourites

**Status:** Candidate
**Depends on:** Stable complete-account collection

Support user-defined or deterministic grouping while preserving immutable account identity and complete account visibility.

Sprint 68A removes an inert star only; it does not implement favourites or change this candidate.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Workspace scope, ordering/grouping/favourite semantics and complete-account visibility are unknown.

**Smallest proposed boundary:** Per-workspace presentation ordering only.

**Decision record:** [ACCOUNT_LIFECYCLE_PACKET](#packet-account-lifecycle-packet).

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P2-37 | **User product choice:** account grouping, ordering, favourites, and preference scope. | It changes navigation but must not change financial membership. | Default stable order. | Per-workspace presentation grouping/order/favourites. | — | A; defer absent current navigation pain. | Default collection order remains. | Bounded preference ownership if B selected. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No groups/favourites; inert historical star removal did not implement them.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Account Grouping, Ordering and Favourites: establish the smallest truthful product boundary. PROPOSED: Per-workspace presentation ordering/grouping only. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: User preference scope/order and complete-account visibility rules. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Repository currently orders accounts by name/id.

**Exact next evidence or decision:** Explicit preference ownership and stable collection contract.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Candidate **Roadmap:** Defer

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Cross-workspace/export behavior.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** PREFERENCE_OWNERSHIP, USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_USER_DECISION` → `decision-account-preference-scope`: Ownership.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-37`: Workspace scope, ordering/grouping/favourite semantics and complete-account visibility are unknown.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1320-1390 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-37
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Database/SQLiteRepositoryProvider.swift](<../Database/SQLiteRepositoryProvider.swift>):1937-1950 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Current order is name/id.

</details>

---

<a id="fw-p2-38"></a>

## FW-P2-38 — Full Account Transaction-History Navigation

**Status:** Ready for planning
**Depends on:** Existing account-scoped activity foundation

**Current discovery disposition — 2026-09-10:** `WAIT_FOR_RUNTIME_ACCEPTANCE`. **Exact remaining gate:** Data/navigation is existing; native R1 selection/focus/accessibility acceptance belongs to recovery-macos lane.

**Smallest proposed boundary:** Navigate canonical account-scoped transactions.

**Decision record:** [SPRINT89_DATA_ALGEBRA_PACKET](<Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md#packet-sprint89-data-algebra-packet>).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: Account-scoped activity foundation exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Full Account Transaction-History Navigation: establish the smallest truthful product boundary. PROPOSED: Navigate existing canonical transactions; no new query authority. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: R1 navigation/selection acceptance details. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** No new query authority required.

**Exact next evidence or decision:** Native keyboard/focus/VoiceOver acceptance.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Wait runtime acceptance **Roadmap:** Retain ready-for-planning data boundary

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Native focus/accessibility results.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** ACCESSIBILITY_ACCEPTANCE, MACOS_PLATFORM.

**Typed dependencies:**

- `REQUIRES_RUNTIME_ACCEPTANCE` → `recovery-macos-native-acceptance`: Native behavior separate.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1320-1390 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-38
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):50-56 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No runtime accessibility proof produced.

</details>

---

<a id="fw-p2-40"></a>

## FW-P2-40 — Remaining User-Facing Terminology Cleanup

**Status:** Candidate
**Depends on:** stable affected R1 screens

**Completed boundary:** Accepted UI work removed/contextualized several misleading internal terms, including replacing the standalone Salary Truth-classes panel with contextual provenance.

**Remaining boundary:** Only genuinely remaining developer/repository terminology on R1-covered ordinary user screens remains. Diagnostics and provenance that are truthful and useful must not be removed merely to simplify wording.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Post-89–91 stable user-surface audit.

**Smallest proposed boundary:** Terminology inventory only; retain truthful provenance.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: accepted work already replaced misleading Salary/developer wording where bounded provenance is useful.

**First-round scope and constraints:** Do not remove truthful diagnostics/provenance merely to simplify language. No semantic rename, diagnostic suppression, or workflow change.

**First-round question/options:** Which remaining ordinary-user labels need R1 cleanup? Audit only R1 ordinary screens; globally rename terms; defer. The first preserves role-specific vocabulary.

**First-round remainder and implications:** MISSING: an audited list of R1 user surfaces after 89–91 stabilize. None.

**First-round proposed acceptance/falsifier:** Each changed label retains source authority and accessibility text; no financial term changes meaning. A label has an accepted technical or audit meaning.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: accepted work already replaced misleading Salary/developer wording where bounded provenance is useful. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Post-89–91 stable user-surface audit. Owning authority: FW-P2-40 pinned queue scope and the named dependency below.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-78`: The LF-UI-2026-09-R1 Dashboard Implementation boundary must provide: Dashboard supports native values only.. This enables Terminology inventory only; retain truthful provenance. Remaining condition: Post-89–91 stable user-surface audit.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1397-1404 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-40
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):1356-1360 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7843854eee6c85888f41af52c52aba70f2d0138c5f6f21e518211c75aca62797` — Sprint 67 detail terminology
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1751-1766 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Remaining User-Facing Terminology Cleanup as Candidate and records this unresolved boundary: MISSING: an audited list of R1 user surfaces after 89–91 stabilize.

</details>

---

<a id="fw-p2-41"></a>

## FW-P2-41 — R1 Contextual Toolbar Conformance

**Status:** Candidate
**Depends on:** stable destination workflows and the accepted R1 shell direction

Conform remaining destination toolbars to functional, page-specific controls with visible scope and consistent hierarchy. Do not force one dominant Import button onto every destination merely for visual uniformity, and do not add inert controls.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Stable destination workflows and exact command/action inventory.

**Smallest proposed boundary:** Page-specific native toolbar/commands.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: ContentView renders a custom contextual toolbar with Import Statement for every selected section, while R1 requires page-specific functional controls.

**First-round scope and constraints:** Do not add inert controls or force Import as the dominant action everywhere. No global Import action, business workflow change, or new menu architecture without planning.

**First-round question/options:** How should R1 toolbar conformance be implemented? Retain custom strip with scoped actions; move frequent actions to SwiftUI toolbar/commands; mixed. Apple documents toolbar and commands, but product placement remains unaccepted.

**First-round remainder and implications:** MISSING: per-destination action inventory, command/shortcut collisions, native resizing and accessibility verification. None.

**First-round proposed acceptance/falsifier:** Keyboard/menu/toolbar action parity, disabled-state truth, no shortcut bypass of confirmations; runtime-required. A proposed control lacks a real active-domain action.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: ContentView renders a custom contextual toolbar with Import Statement for every selected section, while R1 requires page-specific functional controls. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Stable destination workflows and exact command/action inventory. Owning authority: FW-P2-41 pinned queue scope and the named dependency below.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-67`: The App Shell and Workflow Decomposition boundary must provide: Five-phase shell extraction blueprint in packet.. This enables Page-specific native toolbar/commands. Remaining condition: Stable destination workflows and exact command/action inventory.
- `REQUIRES_RUNTIME_ACCEPTANCE` → `runtime-contextual-command-parity`: Toolbar-specific keyboard/menu/confirmation parity is its own acceptance check; cross-screen keyboard closure consumes the implemented toolbar, not vice versa.

**Pinned evidence references:**

- [ContentView.swift](<../ContentView.swift>):1507-1540 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `c315381adf31633a27671b14499fc5dd12d7b794af047c82cfb2acf67990202b` — contextualToolbar
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1408-1413 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-41
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1767-1780 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines R1 Contextual Toolbar Conformance as Candidate and records this unresolved boundary: MISSING: per-destination action inventory, command/shortcut collisions, native resizing and accessibility verification.

</details>

---

<a id="fw-p2-43"></a>

## FW-P2-43 — Better Account Icons

**Status:** Candidate
**Depends on:** Account presentation strategy

Improve default account iconography. User customization remains governed by `FW-P2-32`, while institution logos remain governed by `FW-P2-33`.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Stable per-destination R1 action/shortcut inventory under FW-P2-41 and frozen shell scope, then an account-kind icon map with neutral accessible fallback.

**Smallest proposed boundary:** No institution branding or identity inference.

**Decision record:** [DIAGNOSTICS_PROJECTION_DECISION_PACKET](#packet-diagnostics-projection-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: common icon components exist, but no accepted account presentation taxonomy is identified in this static lane.

**First-round scope and constraints:** User customization and institution logos are separately owned; do not infer identity from branding. No logo ingestion, inferred institution, or custom asset campaign.

**First-round question/options:** What account icon strategy should be adopted? Semantic system defaults need a small account-kind mapping; user-picked icons add preference ownership; institution branding adds separate logo/identity rules. All remain presentation and cannot establish financial identity.

**First-round remainder and implications:** MISSING: approved semantic/default icon taxonomy and fallback rules. No migration.

**First-round proposed acceptance/falsifier:** Fallback, accessibility label, color-independent distinction and no account identity implication. No stable account-kind authority exists.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: common icon components exist, but no accepted account presentation taxonomy is identified in this static lane. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Stable per-destination R1 action/shortcut inventory under FW-P2-41 and frozen shell scope, then an account-kind icon map with neutral accessible fallback. Owning authority: DIAGNOSTICS_PROJECTION_DECISION_PACKET.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Candidate; named stable-R1 dependency remains. **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION, DEPENDENCY.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-41`: The accepted action/shortcut inventory determines the icon semantics; no identity inference or icon storage is needed.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1417-1422 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-43
- [Views/Common/LFIconTile.swift](<../Views/Common/LFIconTile.swift>):1-23 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7615248477db034385ce8ce5f1e904a0f9d9b45a0389bdb6ac7509dc53139f8a` — LFIconTile
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1781-1794 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Better Account Icons as Candidate and records this unresolved boundary: MISSING: approved semantic/default icon taxonomy and fallback rules.

</details>

---

<a id="fw-p2-44"></a>

## FW-P2-44 — Dashboard Customization

**Status:** Idea
**Depends on:** Stable dashboard modules

**Discovery 2026-09-10:** TRIAGE_ONLY / DEFERRED_WITH_EXPLICIT_REASON at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`. VERIFIED_REPOSITORY: Dashboard modules are still subject to R1 native-currency hierarchy work; no stable module contract is accepted.

**Discovery remainder:** MISSING: stable modules and user-selected customization goals. **Next boundary:** PROPOSED: no discovery until Sprint 90 outcome and user objective exist. **Acceptance:** Future plan must identify what may vary without changing financial scope/meaning.


---

<details>
<summary>First-round evidence retained; no second-round scope expansion</summary>

**question (research ref):** Should dashboard customization be researched now?

**current behavior (research ref):** VERIFIED_REPOSITORY: Dashboard modules are still subject to R1 native-currency hierarchy work; no stable module contract is accepted.

**accepted constraints (research ref):** Do not add unsupported analytics, preferences, or financial presentation semantics.

**missing (research ref):** MISSING: stable modules and user-selected customization goals.

**options (research ref):** Fixed R1 dashboard first; configurable modules later; defer. Defer preserves the planned dependency.

**proposed boundary (research ref):** PROPOSED: no discovery until Sprint 90 outcome and user objective exist.

**scope exclusions (research ref):** No widget persistence, drag arrangement, analytics, or multi-workspace assumptions.

**dependencies (research ref):** Stable dashboard modules.

**adr migration impact (research ref):** Unknown until scope exists.

**acceptance (research ref):** Future plan must identify what may vary without changing financial scope/meaning.

**invalidators (research ref):** Sprint 90 changes module boundaries.

**personal v1 (research ref):** INFERENCE: not a gate.

**queue roadmap disposition (research ref):** DEFERRED_WITH_EXPLICIT_REASON; retain Idea.

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1426-1429 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-44
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):34-38 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — Sprint 90

</details>

---

<a id="fw-p2-45"></a>

## FW-P2-45 — Improved Global Search

**Status:** Candidate
**Depends on:** Stable searchable domains

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Searchable domain list, privacy/ranking/navigation and workspace scope.

**Smallest proposed boundary:** Keep accepted transactions search bounded.

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P2-45 | **User product choice:** broaden global search beyond accepted Transactions search. | Domain/ranking/privacy/workspace scope changes what is discoverable. | Keep Transactions search bounded. | Curated named result types after R1 search acceptance. | Full global search later. | A; no selected workflow. | No cross-domain search. | B with explicit domain/privacy map. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: the R1 handoff defines a bounded Transactions search only; global searchable domains remain unsettled.

**First-round scope and constraints:** No fuzzy financial inference or search of undisclosed raw identifiers. No raw source search, identifiers, indexing, or cross-workspace search.

**First-round question/options:** What does global search safely cover? Keep domain-local search; add curated global result types; full text search. The second needs explicit authority.

**First-round remainder and implications:** MISSING: domain list, privacy model, result ranking/navigation and cross-workspace decision. Potential index/storage is unapproved.

**First-round proposed acceptance/falsifier:** Exact searchable fields and result navigation, privacy denial tests, no mutation. Search needs unhydrated/private data.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: the R1 handoff defines a bounded Transactions search only; global searchable domains remain unsettled. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Searchable domain list, privacy/ranking/navigation and workspace scope. Owning authority: FW-P2-45 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** BLOCKED_ON_PRODUCT_DECISION **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=true, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** USER_PRODUCT_DECISION.

**Typed dependencies:**

- `REQUIRES_USER_DECISION` → `decision-global-search`: The explicitly named gate decision-global-search must be satisfied. This enables Keep accepted transactions search bounded. Remaining condition: Searchable domain list, privacy/ranking/navigation and workspace scope.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1433-1436 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-45
- [Project documents/UI Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md](<UI Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md>):79-104 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `628d2b4be1d6f4872c307a4608877e0261811a04dfc5c73a27506dfbcf36c1f2` — Transactions search
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1807-1818 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Improved Global Search as Candidate and records this unresolved boundary: MISSING: domain list, privacy model, result ranking/navigation and cross-workspace decision.

</details>

---

<a id="fw-p2-46"></a>

## FW-P2-46 — Interactive Dashboard Charts

**Status:** Blocked
**Depends on:** Reliable analytical data sources, including the relevant categorization, transfer, recurrence or reporting foundations.

Provide interactive dashboard charts only after their underlying analytical values are derived from authoritative repository-backed financial data.

Until those foundations exist:

- hardcoded spending percentages must not be presented as user financial facts;
- decorative cash-flow values must not appear beside real balances or expenses as though calculated;
- unsupported trends must be removed or shown as unavailable;
- chart labels must not imply categorization, transfer matching, forecasting or historical analysis that is not implemented;
- sample data must remain unmistakably separate from repository data.

Sprint 68 removed the misleading placeholder presentation; that cleanup does not make interactive analytics ready.

Future charts must preserve native-currency safety, provenance, deterministic calculations and the dependency boundaries of `FW-P3-10` and related analytical candidates.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Categorization/transfer/recurrence/reporting semantic foundation and independent series.

**Smallest proposed boundary:** No mixed-currency chart total.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: placeholder charts were removed; native-currency sums are not combined and analytics foundations remain absent.

**First-round scope and constraints:** No decorative financial facts, mixed-currency totals, unsupported trends, or forecast implication. No chart library, sample financial data, trends, forecasts, or preferences.

**First-round question/options:** When can interactive dashboard charts be added? Unavailable/omit; nonfinancial UI-only charts; repository-backed charts after foundations. Only omission is safe now.

**First-round remainder and implications:** MISSING: accepted categorization, transfer, recurrence/reporting semantics and independently checked series. Likely derived-data architecture review; no migration allocated.

**First-round proposed acceptance/falsifier:** Independent source/repository oracle for every displayed value and native-currency scope. Any chart value lacks authoritative derivation.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: placeholder charts were removed; native-currency sums are not combined and analytics foundations remain absent. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Categorization/transfer/recurrence/reporting semantic foundation and independent series. Owning authority: FW-P2-46 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-10`: The Spending Analytics boundary must provide: Facts-only native-currency analytics.. This enables No mixed-currency chart total. Remaining condition: Categorization/transfer/recurrence/reporting semantic foundation and independent series.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1440-1457 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-46
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):842-850 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7843854eee6c85888f41af52c52aba70f2d0138c5f6f21e518211c75aca62797` — currency boundary
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1819-1844 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Interactive Dashboard Charts as Blocked and records this unresolved boundary: MISSING: accepted categorization, transfer, recurrence/reporting semantics and independently checked series.

</details>

---

<a id="fw-p2-47"></a>

## FW-P2-47 — R1 Empty, Loading, Failure and Import Guidance States

**Status:** Candidate
**Depends on:** stable affected workflows

Complete R1 state treatment that distinguishes loading, genuinely empty, unavailable, failed and no-match states. Completed imports must resolve to coherent result/completion presentation. Guidance must not duplicate navigation unnecessarily, fabricate zero financial values or imply unsupported recovery.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Affected R1 workflows stabilize; state matrix then native evidence.

**Smallest proposed boundary:** Truthful loading/unavailable/import outcome states.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: availability distinguishes loading/unavailable and typed import outcomes map unknown states to neutral output; cross-screen native proof is unmeasured.

**First-round scope and constraints:** Never fabricate zero values or unsupported recovery; completion must be coherent. No fake empty data, new import engine, or recovery authority.

**First-round question/options:** What R1 feedback-state work remains? Per-screen ad hoc states; shared typed presentation mapping; defer. Shared mapping fits existing outcome approach.

**First-round remainder and implications:** MISSING: state matrix for Accounts, Import, Settings and Developer Console after each stabilizes. No migration.

**First-round proposed acceptance/falsifier:** Runtime state matrix includes empty/no-match/loading/unavailable/failure and valid action paths. A screen needs new domain state absent from accepted model.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: availability distinguishes loading/unavailable and typed import outcomes map unknown states to neutral output; cross-screen native proof is unmeasured. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Affected R1 workflows stabilize; state matrix then native evidence. Owning authority: FW-P2-47 pinned queue scope and the named dependency below.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-78`: The LF-UI-2026-09-R1 Dashboard Implementation boundary must provide: Dashboard supports native values only.. This enables Truthful loading/unavailable/import outcome states. Remaining condition: Affected R1 workflows stabilize; state matrix then native evidence.
- `REQUIRES_RUNTIME_ACCEPTANCE` → `FW-P2-49`: The R1 Native Accessibility Closure boundary must provide: Static labels do not certify accessibility.. This enables Truthful loading/unavailable/import outcome states. Remaining condition: Affected R1 workflows stabilize; state matrix then native evidence.

**Pinned evidence references:**

- [ContentView.swift](<../ContentView.swift>):1465-1473 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `c315381adf31633a27671b14499fc5dd12d7b794af047c82cfb2acf67990202b` — ContentView availability state
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1461-1466 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-47
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1845-1858 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines R1 Empty, Loading, Failure and Import Guidance States as Candidate and records this unresolved boundary: MISSING: state matrix for Accounts, Import, Settings and Developer Console after each stabilizes.

</details>

---

<a id="fw-p2-48"></a>

## FW-P2-48 — R1 Cross-Screen Visual Polish

**Status:** Candidate
**Depends on:** stable primary layouts and the applicable R1 implementation slices

Remaining shared polish includes readable full native-currency summaries, safe account disambiguation, responsive/collapsible inspectors, settings hierarchy/density and Developer Console clarity between the active database and a selected target.

The Transactions portions may be consumed only as needed by Sprint 89; broader cross-screen polish remains for the later shared conformance boundary. Further Salary visual refinement remains lower priority and must not reopen accepted natural input, Save/Command-S, fee validation or persistence behavior.

**Current discovery disposition — 2026-09-10:** `WAIT_FOR_RUNTIME_ACCEPTANCE`. **Exact remaining gate:** Compare the subjective wide right-column preview proposal with a responsive shared/full-width fallback, preserve accepted Import semantics, then independently verify native width/long-validation/scroll/focus/VoiceOver/footer behavior.

**Smallest proposed boundary:** Rebalance existing read-only Import preview placement without changing source order, identity/validation/confirmation, selection or financial semantics; FW-P2-48 owns it.

# Import Layout Feedback - Draft Discovery Appendix

Lane: recovery_macos
Observation date: 2026-09-10
Evidence boundary: read-only archive declared as af2d1949c6e9a73af3bb004422b72882d28195e2. This external scratch file changes no UI authority, queue entry, frozen status, product source, or runtime claim.

## Evidence classification

- USER_REPORTED_SUBJECTIVE: The user finds the prepared Import screen transaction preview in the left region scroll-heavy while the right Validation Review region can be comparatively empty. The user suggests moving Transaction Preview under Validation Review. This is a preference and candidate layout direction, not a universal rule.
- VERIFIED_USER_IMAGE_LAYOUT_ONLY: The supplied screenshot shows the described two-column geometry: long prepared-import material and preview occupy the left scrolling region while the right review region visibly has unused vertical capacity. Inspection was layout-only. No image is copied, embedded, named, transcribed, or used for a financial, source, validation, runtime, selection, or accessibility claim.
- VERIFIED_PINNED_SOURCE: ContentView places prepared-import body in the left panel and a scrolling Validation Review panel at right (ContentView.swift:1843-1907); the prepared body places Transaction Preview after summary, identity, and equivalence content (:2924-2988). This proves static placement only.

## Existing authority and correct owner

| Question | Existing authority or owner | Disposition |
| --- | --- | --- |
| Preview meaning | Project documents/UI_UX_v1.0_Frozen.md:480-553, Import Workflow and Preview | Binding workflow authority. Preserve source/statement summary, identity review, transactions, validation/duplicate outcome and explicit confirmation distinctions. |
| Responsive and scroll behavior | UI_UX_v1.0_Frozen.md:720-729 and UI Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md:27-45,204-212 | Subject authority. One obvious scroll owner, visible focus/selection, responsive hierarchy; not native certification. |
| Existing FW owner | FW-P2-48 R1 Cross-Screen Visual Polish, FUTURE_WORK.MD:1859-1870 | Owns responsive/cross-screen presentation after stable layouts. FW-P2-49 owns native acceptance. |
| Conditional structural coordination | FW-P2-67, FUTURE_WORK.MD:2137-2165 | Coordinate only if selected shell extraction changes composition; it is not the design owner. |
| Explicit non-owner: terminology | FW-P2-40, FUTURE_WORK.MD:1751-1762 | Wording/provenance only, not panel geometry. |
| Explicit non-owner: editable preview | FW-P1-22, FUTURE_WORK.MD:975-991 | Correction/provenance only, not placement. |
| Suggested FW-P2-02 | No active FW-P2-02 occurs in pinned FUTURE_WORK, discovery register, UI/UX authority, or target matrix. | Do not invent/revive ID. Attach the discovery to FW-P2-48 and FW-P2-49 dependency. |

## Bounded alternatives

### A - wide-window right-column stack - recommended candidate

At a documented broad-width threshold, the right column becomes one vertically scrolling review region: Validation Review first, Transaction Preview immediately below. The left retains queue, prepared statement summary, identity/equivalence/partial-review explanation and other pre-confirmation context. Footer cancel, skip and confirmation controls remain persistently visible.

The table remains read-only prepared evidence. It preserves source order and each existing prepared-import, validation, identity, duplicate, equivalence and confirmation distinction. Moving it creates no selection, edit, filter, source reopen or confirmation behavior.

### B - responsive shared or main preview region

If a right-column table cannot meet documented readable minimum width, or long validation material makes the stack difficult to scan, reflow the one Transaction Preview into a full-width region below the two-column summary/review area. Do not duplicate it. The breakpoint follows minimum table readability, text scaling and visible confirmation/cancel controls, never a screenshot ratio.

### Recommendation

Use A as the broad-layout candidate because it addresses the user-observed left-scroll imbalance while keeping validation and prepared transactions adjacent as pre-confirmation review. Use B as responsive fallback. This is not a rule that every validation view must display a table on the right.

## Invariants and exclusions

| Preserve | Do not add or change |
| --- | --- |
| Prepared source order/multiplicity and bounded prepared-evidence representation. | Financial values, parser/normalizer/source interpretation, identity resolution, validation, duplicate/equivalence, account choice or provider persistence. |
| Separate identity/account, validation, duplicate/equivalence and explicit confirmation review. | Any implication that validation equals persistence, confirmation has succeeded, or equivalent source creates transactions. |
| Safe pre-confirm cancellation, non-cancellable confirmed persistence, footer action visibility and disabled truth. | Edit/correction, new row selection semantics, filtering/sorting, source reopening, queue, provenance, diagnostics or workflow destination. |
| One obvious scroll owner; keyboard/focus accessibility grouping. | Nested unbounded scroll views, duplicated preview, layout-derived financial conclusion, screenshot-derived INR color semantics. |

## Future acceptance required, not performed

Use a task-owned native run after FW-P2-48 implementation. Previewed statement behavior uses approved authentic inputs only; do not manufacture empty or zero-transaction statements.

1. Wide window: validation plus preview appear in right review stack; left does not need disproportionate scroll merely to reach existing preview; review order/footer remain visible and accessible.
2. Narrow window: B reflows before unreadable columns; one preview, no clipped controls or competing scroll owners.
3. Long validation: blocking explanation, identity decision, duplicate/equivalence outcome and confirmation state remain readable and reachable.
4. Keyboard and VoiceOver: coherent focus order through queue, identity/validation, preview and footer; headings/grouping announce purpose; focus and any existing selection remain visible.
5. Scroll and selection: scrolling reaches intended region; reflow retains/clears any owner-defined selection explicitly and never substitutes another row.
6. Confirm/cancel: pre-confirm cancel/skip and eligible confirmation discoverable at all widths; committing remains non-cancellable and shortcuts cannot bypass confirmation.
7. Empty and genuine zero-transaction: truthful prepared/validation/confirmation state. Use real registered authentic zero-transaction case if available; otherwise mark untested, never manufacture.
8. Privacy/color: no raw identifiers/source fragments/image contents in labels. Do not change INR financial color semantics from image; retain its independent source/runtime gate.

## Recommended draft documentation route

Root may append a clearly marked unaccepted appendix named DRAFT - Import Preview Responsive Placement to Project documents/UI Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md, after responsive hierarchy and before component guidance. It should link FW-P2-48, FW-P2-49, frozen Import Workflow/Preview authority, this discovery file and future acceptance. It must state A/B are draft, preserve workflow semantics, select no sprint and change no accepted R1/native status.

## Matrix and revalidation

This adds a second-level discovery row under FW-P2-48, with FW-P2-49 as REQUIRES_RUNTIME_ACCEPTANCE and FW-P2-67 conditional structural coordination. It creates no new FW ID, replaces no campaign, affects no personal-v1 DAG, and is independent of FX/current-historical conversion scope. No verified P0, parser, financial, or privacy defect was found.


<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: written R1 contract specifies readable currency, safe account disambiguation, inspector behavior, density, and Developer Console clarity; Transactions is separately bounded in Sprint 89.

**First-round scope and constraints:** Do not reopen accepted Salary editor/save/fee/persistence or consume broader work in Sprint 89. No Dashboard analytics, Salary semantic change, or source-tree move.

**First-round question/options:** What cross-screen R1 polish can be shared? Consume minimal Transactions slice; consolidated post-91 polish; per-screen styling. Prepared roadmap selects consolidated later boundary.

**First-round remainder and implications:** MISSING: native resizing, color, accessibility and cross-screen comparison evidence. None.

**First-round proposed acceptance/falsifier:** Matched-window/text-size checks and semantic presentation invariants. R1 slice alters a shared component contract.

**Second-round new evidence/resolved direction:** USER_REPORTED_SUBJECTIVE and VERIFIED_USER_IMAGE_LAYOUT_ONLY: Import preview causes disproportionate left scrolling while right Validation Review has spare vertical space. User suggests right-side preview below validation as a candidate, not a forced rule. Pinned ContentView placement corroborates broad geometry only.

**Exact next evidence or decision:** Pinned ContentView.swift:1843-1907,2924-2988 and frozen UI workflow plus private supplied-image layout observation; future native acceptance required, no screenshot financial claim.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** WAIT_FOR_RUNTIME_ACCEPTANCE **Roadmap:** Attach subjective Import rebalancing to existing FW-P2-48/cross-screen R1 gate; no sprint selected and no frozen placement approved.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** MACOS_PLATFORM, ACCESSIBILITY_ACCEPTANCE.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-78`: The LF-UI-2026-09-R1 Dashboard Implementation boundary must provide: Dashboard supports native values only.. This enables Rebalance existing read-only Import preview placement without changing source order, identity/validation/confirmation, selection or financial semantics; FW-P2-48 owns it. Remaining condition: Compare the subjective wide right-column preview proposal with a responsive shared/full-width fallback, preserve accepted Import semantics, then independently verify native width/long-validation/scroll/focus/VoiceOver/footer behavior.
- `REQUIRES_RUNTIME_ACCEPTANCE` → `FW-P2-49`: Independent native resize/keyboard/VoiceOver and action-visibility acceptance; user feedback is subjective.
- `OPTIONAL_ENHANCEMENT` → `FW-P2-67`: Coordinate only if selected shell decomposition changes the composition; not a prerequisite for the layout discovery.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1470-1477 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-48
- [Project documents/UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md](<UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md>):32-37 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `e22c6acfe8e63a124f5f032dd9fb7e09a7102a3f25137e4acbb7a119845c03ab` — UI-01 to UI-06
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1859-1874 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines R1 Cross-Screen Visual Polish as Candidate and records this unresolved boundary: MISSING: native resizing, color, accessibility and cross-screen comparison evidence.
- [ContentView.swift](<../ContentView.swift>):1843-1907;2924-2988 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Static placement only: prepared body left, validation right, transaction preview later in prepared body.

</details>

---

<a id="fw-p2-49"></a>

## FW-P2-49 — R1 Native Accessibility Closure

**Status:** Candidate
**Depends on:** stable R1 implementation surfaces

Native/runtime acceptance must cover complete keyboard paths, useful VoiceOver grouping, visible focus distinct from selection, non-colour status meaning, applicable 4.5:1 text and 3:1 meaningful-boundary targets, reduced motion/transparency and readable fallback for user appearance choices.

Static design approval is not accessibility acceptance. The bounded Transactions portion may be exercised with Sprint 89; cross-screen closure remains later.

**Current discovery disposition — 2026-09-10:** `WAIT_FOR_RUNTIME_ACCEPTANCE`. **Exact remaining gate:** VoiceOver, Full Keyboard Access, focus, contrast, resize and reduced-preference observations.

**Smallest proposed boundary:** Static labels do not certify accessibility.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: many labels exist, but custom shell applies a fixed dark color scheme and static design documents explicitly deny native certification.

**First-round scope and constraints:** Keyboard paths, VoiceOver grouping, visible focus, non-color meaning, contrast, reduced motion/transparency, and readable fallbacks are required. No redesign, accessibility claim from token checks, or financial state alteration.

**First-round question/options:** What distinguishes R1 design approval from native accessibility closure? Static labels only; native acceptance matrix; defer. Static labels are insufficient.

**First-round remainder and implications:** MISSING: actual VoiceOver, Full Keyboard Access, focus, composited contrast, resize and reduced-preference observations. No migration.

**First-round proposed acceptance/falsifier:** Runtime VoiceOver/keyboard/focus/reduced-settings and measured contrast results. Fixed palette or custom material prevents readable fallback.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: many labels exist, but custom shell applies a fixed dark color scheme and static design documents explicitly deny native certification. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Task-owned native runtime evidence

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** WAIT_FOR_RUNTIME_ACCEPTANCE **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** MACOS_PLATFORM, ACCESSIBILITY_ACCEPTANCE.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-55`: The Adaptive Appearance Native Implementation boundary must provide: System/Light/Dark; no financial mutation.. This enables Static labels do not certify accessibility. Remaining condition: VoiceOver, Full Keyboard Access, focus, contrast, resize and reduced-preference observations.
- `REQUIRES_RUNTIME_ACCEPTANCE` → `runtime-acceptance-fw-p2-49`: VoiceOver, Full Keyboard Access, focus, contrast, resize and reduced-preference observations.

**Pinned evidence references:**

- [ContentView.swift](<../ContentView.swift>):1443-1480 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `c315381adf31633a27671b14499fc5dd12d7b794af047c82cfb2acf67990202b` — ContentView root
- [Project documents/UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md](<UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md>):34-37 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `e22c6acfe8e63a124f5f032dd9fb7e09a7102a3f25137e4acbb7a119845c03ab` — UI-04 to UI-06
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1875-1890 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines R1 Native Accessibility Closure as Candidate and records this unresolved boundary: MISSING: actual VoiceOver, Full Keyboard Access, focus, composited contrast, resize and reduced-preference observations.

</details>

---

<a id="fw-p2-50"></a>

## FW-P2-50 — R1 Keyboard Navigation and Shortcuts

**Status:** Candidate
**Depends on:** stable R1 primary workflows

Complete keyboard reachability for search, filters, sortable headings, table/row selection, inspector interactions, collapse/expand behavior and other R1 primary actions. Focus remains visible and distinct from selection, and shortcuts never bypass confirmation or mutation safety.

The bounded Transactions portion may be included in Sprint 89; cross-screen closure remains later.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Toolbar inventory and stable workflows; then runtime shortcut/focus proof.

**Smallest proposed boundary:** Command/focused-value routing without mutation shortcuts.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: only isolated Command-S is found in Salary; app entry has no commands block and the custom shell uses sidebar buttons.

**First-round scope and constraints:** Shortcuts must never bypass confirmation or mutation safety; focus differs from selection. No command that directly persists/imports/reverses without existing gates.

**First-round question/options:** How should keyboard reachability be planned? Per-view shortcuts; shared App commands/focused routing; no new shortcuts. Apple documents command menu integration, but product choices require planning.

**First-round remainder and implications:** MISSING: conflict-free shortcut table, focused-value routing, and runtime keyboard traversal. None.

**First-round proposed acceptance/falsifier:** Keyboard traversal/search/filter/sort/selection/inspector tests with visible focus and confirmation checks. Collision with system or app command, or unsafe mutation bypass.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: only isolated Command-S is found in Salary; app entry has no commands block and the custom shell uses sidebar buttons. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Toolbar inventory and stable workflows; then runtime shortcut/focus proof. Owning authority: FW-P2-50 pinned queue scope and the named dependency below.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-41`: The R1 Contextual Toolbar Conformance boundary must provide: Page-specific native toolbar/commands.. This enables Command/focused-value routing without mutation shortcuts. Remaining condition: Toolbar inventory and stable workflows; then runtime shortcut/focus proof.

**Pinned evidence references:**

- [LedgerForgeApp.swift](<../LedgerForgeApp.swift>):20-40 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `325b5d3cc8d7f32dbb11efb815cd7d82be3b9a79f069fb8434aa4b83fde47185` — LedgerForgeApp.body
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1492-1499 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-50
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1891-1906 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines R1 Keyboard Navigation and Shortcuts as Candidate and records this unresolved boundary: MISSING: conflict-free shortcut table, focused-value routing, and runtime keyboard traversal.

</details>

---

<a id="fw-p2-51"></a>

## FW-P2-51 — Startup, Runtime and Import Performance Optimization

**Status:** Research
**Depends on:** Measured performance evidence plus authentic large sources where source-path performance is under test, or clearly non-source synthetic stress data that makes no parser-support claim

Measure and improve:

- application startup;
- repository hydration;
- large account and transaction presentation;
- import preparation and confirmation;
- large-statement parsing;
- search and filtering.

Sprint 83 completes the serial batch Import Centre. Any future bounded parallel preparation remains unscheduled Research under this existing performance candidate, requiring measured need, transferable `PreparedImport`/source-snapshot ownership and proven dependency thread safety, including the `FW-P2-74` boundary. It must preserve deterministic queue order and per-file review/confirmation and cannot parallelize confirmation or provider commit. This note does not approve implementation.

A splash or launch-progress experience may be considered only when measured startup delay justifies one.

Do not optimize without benchmarks.

**Current discovery disposition — 2026-09-10:** `WAIT_FOR_RUNTIME_ACCEPTANCE`. **Exact remaining gate:** Measured baseline, scenarios, thresholds and profiler captures.

**Smallest proposed boundary:** No optimization from static theory.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: startup triggers persistence and hydration through the root app/shell; no measurement exists in this lane.

**First-round scope and constraints:** Do not optimize without benchmarks; source-path tests require authentic large sources, while non-source stress data may only test mechanics. No splash, benchmark claim, parser corpus substitute, or optimization patch.

**First-round question/options:** What performance work can be recommended without runtime probes? Measure startup/hydration; add launch UI; tune static code. Only measurement is authorized next.

**First-round remainder and implications:** MISSING: baseline measurements, representative scenarios, thresholds, and profiler captures. None inferred.

**First-round proposed acceptance/falsifier:** Pinned build identity, scenario definition, metrics, flame/sample evidence, and repeatability; authentic corpus where source path is tested. Measurement changes due to an uncontrolled database/source or overlaps validation.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: startup triggers persistence and hydration through the root app/shell; no measurement exists in this lane. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Task-owned native runtime evidence

**Personal-v1:** POST_V1

**Recommendation after Chat:** WAIT_FOR_RUNTIME_ACCEPTANCE **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** MACOS_PLATFORM, ACCESSIBILITY_ACCEPTANCE.

**Typed dependencies:**

- `REQUIRES_RUNTIME_ACCEPTANCE` → `runtime-acceptance-fw-p2-51`: Measured baseline, scenarios, thresholds and profiler captures.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1503-1519 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-51
- [LedgerForgeApp.swift](<../LedgerForgeApp.swift>):28-63 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `325b5d3cc8d7f32dbb11efb815cd7d82be3b9a79f069fb8434aa4b83fde47185` — configurePersistence
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1907-1933 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Startup, Runtime and Import Performance Optimization as Research and records this unresolved boundary: MISSING: baseline measurements, representative scenarios, thresholds, and profiler captures.

</details>

---

<a id="fw-p2-52"></a>

## FW-P2-52 — User and Workspace Preferences

**Status:** Ready for discovery
**Depends on:** Existing settings presentation and `WorkspaceSettings` domain direction

Define durable, privacy-safe preferences for existing regional/display behavior and the **user-approved `LF-UI-2026-09-R1` appearance direction**:

- Follow System / Light / Dark;
- System Neutral / optional Deep Indigo preset concept;
- accent;
- app-wide text size;
- a small supported font-style set;
- comfortable/compact density;
- bounded foreground/background customization;
- bounded eligible-surface translucency;
- Preview / Apply / Cancel / Restore defaults;
- automatic readable fallback; and
- reduced-transparency compliance.

Also retain candidate scope for date/time formatting, regional number formatting, base/secondary display currencies, default import behavior, dashboard/account/transaction presentation and developer-mode separation.

**Unresolved architecture:** preference persistence/storage ownership remains discovery work. R1 approval does not choose UserDefaults, SQLite or another store. Preference mutation must never rewrite imported financial truth. Reporting-currency preferences remain dependent on `FW-P3-33`.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Preference-owner ADR: versioned device UserDefaults plus package preference snapshot.

**Smallest proposed boundary:** Display only; reporting currency stays FX-owned.

**Decision record:** [PREFERENCES_ARCHITECTURE_DECISION_PACKET](#packet-preferences-architecture-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: only DEBUG database-profile remembrance uses UserDefaults; no general WorkspaceSettings type or R1 preference owner was found. R1 specifies draft Apply/Cancel/Restore and relaunch behavior but does not choose storage.

**First-round scope and constraints:** Preferences cannot rewrite imported financial truth; reporting currency remains FW-P3-33; light/dark overrides remain separate; malformed values must fall back safely. No preference UI, financial-data write, migration, reporting FX, or developer-profile reuse as general policy.

**First-round question/options:** Who owns and stores user/workspace preferences? UserDefaults for nonfinancial app preferences; workspace repository storage; hybrid. Apple says AppStorage is UserDefaults-backed, not an architecture choice.

**First-round remainder and implications:** MISSING: owner split (app/user/workspace/session), persistence backend, schema/versioning, migration/reset behavior, and separation of display from financial preferences. Likely ADR; migration only if accepted backend requires durable schema.

**First-round proposed acceptance/falsifier:** Draft atomicity, Apply/Cancel/Restore, relaunch, malformed fallback, light/dark separation, and proof imported values never change. A requested setting is workspace-scoped, financial, or multi-workspace dependent.

**Second-round new evidence/resolved direction:** Exact user requirement that appearance preferences travel with move/restore.

**Exact next evidence or decision:** Exact next evidence/decision: Preference-owner ADR: versioned device UserDefaults plus package preference snapshot. Owning authority: PREFERENCES_ARCHITECTURE_DECISION_PACKET.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** READY_FOR_CHAT_ARCHITECTURE_DECISION **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-preferences-adr`: The explicitly named gate decision-preferences-adr must be satisfied. This enables Display only; reporting currency stays FX-owned. Remaining condition: Preference-owner ADR: versioned device UserDefaults plus package preference snapshot.

**Pinned evidence references:**

- [Services/DevelopmentDatabaseProfilePreferences.swift](<../Services/DevelopmentDatabaseProfilePreferences.swift>):7-51 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `f080eb8aadab1fcdff11afb007fc9a3f439c6f36e54a798d3eafc4d10adb98cb` — DevelopmentDatabaseProfilePreferences
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1523-1544 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-52
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1934-1959 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Preference ownership/storage remains unresolved.
- [Services/DevelopmentDatabaseProfilePreferences.swift](<../Services/DevelopmentDatabaseProfilePreferences.swift>):12-49 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — DEBUG UserDefaults validates unsafe values to defaults.

</details>

<a id="packet-preferences-architecture-decision-packet"></a>

<details>
<summary>PREFERENCES_ARCHITECTURE_DECISION_PACKET — complete proposed decision packet</summary>

## PREFERENCES_ARCHITECTURE_DECISION_PACKET

| # | Required field | Decision |
| --- | --- | --- |
| 1 | Owning FW IDs | FW-P2-52, FW-P2-55; informs FW-P2-50 and prepared Sprint 91. |
| 2 | User problem | Accessible appearance across windows/relaunch and move/restore without rewriting financial truth. |
| 3 | Verified current state | Only DEBUG profile remembrance uses UserDefaults with safe defaults; WindowGroup hosts fixed-dark custom ContentView shell. |
| 4 | Accepted authorities | R1 direction; ADR-024 separation; ADR-026; reporting currency remains FW-P3-33. |
| 5 | Exact missing decision | Chat acceptance of typed ownership/storage and portable restore rule. |
| 6 | Evidence acquired | UserDefaults code validates invalid enum/int to defaults; no general WorkspaceSettings exists. |
| 7 | Options considered | Device-local UserDefaults; SQLite workspace settings; view state; portable preference snapshot. |
| 8 | Recommended option | Typed versioned UserDefaults as live device-local authority plus validated appearance-preference snapshot in backup/portable package. |
| 9 | Why competing options are rejected | SQLite adds financial workspace/migration/hydration scope; view state fails relaunch; raw defaults copy unsafe. Snapshot meets explicit user choice. |
| 10 | Smallest coherent implementation boundary | System/Light/Dark, Neutral/Indigo, bounded accent/density/text scale/font, system reduced transparency; draft Apply/Cancel/Restore; backup snapshot after database success. |
| 11 | Included scope | All windows one authority; atomic Apply; Cancel no write; Restore Defaults known keys; System tracks OS; restore preview defaults to applying the backed-up appearance after database validation; retaining current device appearance is an explicit user override. |
| 12 | Explicit exclusions | Reporting/base/secondary currency/FX, import defaults, financial/account semantics, credentials, arbitrary styling, cloud/multiwriter. |
| 13 | Durable model/persistence requirements | Namespaced keys plus schema; package has preference snapshot version/hash; invalid fields default. No draft/history. Unsupported package preferences do not block database recovery. |
| 14 | Migration impact | NONE for UserDefaults; later SQLite store REQUIRES_DECISION. |
| 15 | ADR impact | NEW_ADR_REQUIRED for ownership, snapshot precedence and backup interaction. |
| 16 | Privacy/security boundary | Nonfinancial settings only; no account/record/source/credential/diagnostic values. |
| 17 | SQLite/In-Memory implications | No DB persistence/parity; isolated defaults tests only. |
| 18 | Hydration/relaunch implications | Independent of hydrator. On restore apply snapshot only after candidate DB hydration; failure leaves current prefs intact. |
| 19 | Independent acceptance oracle | Decode/default/reset/draft/restore-precedence matrix, zero repo/migration writes, native OS appearance/transparency/VoiceOver/multiwindow. |
| 20 | Failure cases | Missing/old/new schema, malformed value, failed write, OS change during draft, multiple windows, restore cancel, unsupported snapshot, unavailable ledger. |
| 21 | Reversal/correction semantics | Cancel no write; Restore Defaults/later Apply reverses display choice; backup application confirmable and never financial compensation. |
| 22 | Source evidence requirement | None: source-independent nonfinancial UI. |
| 23 | Runtime acceptance requirement | Required system scheme, contrast, text, transparency, keyboard/VoiceOver, multiwindow. |
| 24 | Dependencies | User decision satisfied; NEW ADR; post-87 recheck if shared shell touched. Financial reporting settings remain separately owned by FW-P3-33 and do not block nonfinancial appearance preferences. |
| 25 | Evidence that falsifies the recommendation | User requires settings as financial workspace truth; required option financial; snapshot cannot safely validate/apply. |
| 26 | Personal-v1 relevance | PRE_V1_OPTIONAL unless explicitly adopted. |
| 27 | Recommended FUTURE_WORK status after Chat review | FW-P2-52 READY_FOR_CHAT_ARCHITECTURE_DECISION; FW-P2-55 READY_AFTER_NAMED_DEPENDENCY. |
| 28 | Recommended roadmap effect after Chat review | Record Sprint-91 ownership gate only; do not activate/select. |

</details>

---

<a id="fw-p2-53"></a>

## FW-P2-53 — Contextual Date-Range and Filter Controls

**Status:** Ready for planning
**Depends on:** Stable date semantics and searchable presentation domains

Implement the approved `LF-UI-2026-09-R1` contextual Transactions/table direction:

- period controls and visible active filter/sort scope;
- sortable supported Date, Description, Account, Category and Amount columns;
- repeated heading action reverses direction;
- currency-safe amount sorting with deterministic/stable tie-breaking;
- resizable columns;
- collapsible inspector with stable selection; and
- contextual controls that remain keyboard accessible and affect only the active presentation domain.

Presentation sorting must never rewrite source order, running-balance semantics or durable transaction ordering. Mixed-currency values must not be silently converted merely to sort or total them.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Sprint-89 selection plus independent filter/sort/total oracle and native procedure.

**Smallest proposed boundary:** Generation-pinned transient filters; native-currency totals.

**Decision record:** [SHELL88_AND_SPRINT89_NATIVE_PROCEDURE](<Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md#packet-shell88-and-sprint89-native-procedure>).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: accepted R1 specification fully defines Transactions control semantics; source implementation remains an unaccepted planned slice.

**First-round scope and constraints:** Stable source-date semantics, currency grouping, deterministic ties, inspector identity; presentation cannot alter financial/source order. No global search, saved filters, FX, categories/rules, or mutation.

**First-round question/options:** What is the implementation boundary for contextual date/filter controls? Implement as one Transactions packet; split filters/sorting; defer. Roadmap already bounds it to Sprint 89.

**First-round remainder and implications:** MISSING: execution prompt and runtime/oracle evidence for financial aggregates/sorting. No migration.

**First-round proposed acceptance/falsifier:** All handoff TX tests plus keyboard/focus runtime checks and source-backed aggregate oracle. Mixed-currency ordering/aggregate requires an unaccepted financial mapping.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: accepted R1 specification fully defines Transactions control semantics; source implementation remains an unaccepted planned slice. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Sprint-89 selection plus independent filter/sort/total oracle and native procedure. Owning authority: SHELL88_AND_SPRINT89_NATIVE_PROCEDURE.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-67`: The App Shell and Workflow Decomposition boundary must provide: Five-phase shell extraction blueprint in packet.. This enables Generation-pinned transient filters; native-currency totals. Remaining condition: Sprint-89 selection plus independent filter/sort/total oracle and native procedure.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-sprint89-oracle`: The explicitly named gate decision-sprint89-oracle must be satisfied. This enables Generation-pinned transient filters; native-currency totals. Remaining condition: Sprint-89 selection plus independent filter/sort/total oracle and native procedure.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1546-1561 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-53
- [Project documents/UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md](<UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md>):38-46 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `e22c6acfe8e63a124f5f032dd9fb7e09a7102a3f25137e4acbb7a119845c03ab` — TX-01 to TX-10
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2137-2165 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Shell decomposition must preserve runtime ownership.
- [ContentView.swift](<../ContentView.swift>):1443-1624 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Archive has a custom monolithic shell.

</details>

---

<a id="fw-p2-54"></a>

## FW-P2-54 — Document Library and Source-Document Browsing

**Status:** Ready for discovery
**Shared prerequisites:** Durable document provenance, transaction-to-source relationships and import-attempt history now exist.
**Implementation dependency:** Approval of the privacy-safe metadata, navigation and retention boundary.

Provide a user-facing place to inspect imported source-document records and their relationships to:

- accounts;
- import sessions;
- statement periods;
- transactions;
- validation and duplicate outcomes.

Targeted discovery must determine:

- which durable metadata is authoritative and safe to display;
- how document identity differs from filename and source-content identity;
- account, session and transaction navigation;
- treatment of exact duplicates, partial outcomes and unavailable legacy evidence;
- whether source reopening or content retention is excluded;
- privacy-safe search and export boundaries.

The library must not expose raw source content by default and must not treat a document record as the owner of account identity.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Safe metadata/navigation/retention and duplicate/partial/legacy handling require choice.

**Smallest proposed boundary:** Read-only metadata library; exact duplicate routes prior outcome, gaps stay explicit.

**Decision record:** [DOCUMENT_LIBRARY_PACKET](#packet-document-library-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: transaction detail derives a privacy-bounded source-document name from durable transaction provenance and exposes session validation status; repository contracts expose import session/document and partial/equivalence read models. This is sufficient evidence for metadata relationship navigation, not for reopening or raw-content retention.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Document Library and Source-Document Browsing: establish the smallest truthful product boundary. PROPOSED: metadata-only library (safe document label, source format/profile where retained, period/count/outcome, account/session/transaction relations) is independently useful. Retained source copy and re-open original are separate options owned by FW-P2-01; path/raw-byte search/export are separate privacy decisions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Privacy-safe authoritative metadata, retention, navigation, duplicate/partial/legacy handling and reopening exclusion. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** A hydrated document relationship is navigable from each permitted entry point and is rejected/labelled unavailable if document/session/workspace provenance is inconsistent. Exact duplicate and partial attempt routes are distinguishable; no raw path, bytes, credential, hidden identifier or reopen control appears. The feature has zero financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Relationship navigation is supported; raw content/reopening is not.

**Exact next evidence or decision:** Authoritative metadata whitelist and explicit reopening exclusion.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Ready after Chat decision **Roadmap:** Separate from source reopening

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Path/bytes/credential exposure.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION, PRIVACY, PROVENANCE, HYDRATION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-document-library-privacy`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Metadata/retention boundary.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-54`: Safe metadata/navigation/retention and duplicate/partial/legacy handling require choice.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1563-1585 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-54
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Database/Repository.swift](<../Database/Repository.swift>):248-276 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — ImportSessionRepository
- [ViewModels/TransactionListViewModel.swift](<../ViewModels/TransactionListViewModel.swift>):120-209 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7e2dbde244295009d00df9cf6f6f5606f2e123374c912c346df4b07936b1cbd9` — detailPresentation(for:)
- [LedgerForgeTests/TransactionListViewModelTests.swift](<../LedgerForgeTests/TransactionListViewModelTests.swift>):65-100 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `30c938da8a204989e27b1b070a352b8bd784cf111ef01dd2b04f6dd3f8f3641f` — detail provenance presentation tests
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1323-1334 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Paths/bytes are not durable identity.

</details>

<a id="packet-document-library-packet"></a>

<details>
<summary>DOCUMENT_LIBRARY_PACKET — complete proposed decision packet</summary>

## DOCUMENT_LIBRARY_PACKET

1. **Owning FW IDs:** FW-P2-01 and FW-P2-54.

2. **User problem:** inspect import provenance without claiming source content
   is retained or reopening it unsafely.
3. **Verified current state:** durable document/session/transaction relations
   permit metadata navigation; process-local text is not durable reopening.
4. **Accepted authorities:** document identity/provenance and privacy boundary.
5. **Exact missing decision:** metadata whitelist, retention/reopening choice,
   partial/duplicate/legacy presentation.
6. **Evidence acquired:** transaction display can use durable provenance but
   paths, names and bytes are not durable identity.
7. **Options considered:** metadata-only; fingerprint reauthorization; encrypted
   retained copy.
8. **Recommended option:** metadata-only library now; if reopening is later
   selected, fingerprint-gated user reauthorization is smaller than retention.
9. **Why competing options are rejected:** retention requires encryption/deletion/
   migration/recovery architecture; assuming availability is false.
10. **Smallest coherent implementation boundary:** list/detail of safe document metadata plus
   account/session/transaction navigation.
11. **Included scope:** safe label, retained format/profile/period/count/outcome
    where authoritative, and explicit unavailable/partial/duplicate states.
12. **Explicit exclusions:** raw source bytes, paths, credential fields, export,
    content search and reopening control.
13. **Durable model/persistence requirements:** use existing relationships;
    extra retention requires a new durable contract.
14. **Migration impact:** NONE for metadata-only; REQUIRES_DECISION for retained
    content.
15. **ADR impact:** NEW_ADR_REQUIRED for retention/reopening; ALIGN_EXISTING
    for metadata-only provenance.
16. **Privacy/security boundary:** raw content unavailable by default and never
    implied to exist.
17. **SQLite/In-Memory implications:** metadata relationship consistency must
    agree; future retained bytes require full parity.
18. **Hydration/relaunch implications:** library sees hydrated relations and
    labels orphan/inconsistent provenance unavailable.
19. **Independent acceptance oracle:** separately enumerate permitted relation
    edges and expected unavailable/duplicate/partial labels.
20. **Failure cases:** inconsistent document/session/workspace provenance,
    missing legacy record or fingerprint mismatch shows unavailable and opens
    nothing.
21. **Reversal/correction semantics:** none for library; retained-copy deletion
    requires a separate policy.
22. **Source evidence requirement:** none beyond existing durable provenance.
23. **Runtime acceptance requirement:** later navigation and privacy UI review.
24. **Dependencies:** Chat privacy decision; FW-P2-01 reopening contract if
    reopening is retained.
25. **Evidence that falsifies the recommendation:** any raw path/byte/credential exposure or a
    claimed original with no verified fingerprint.
26. **Personal-v1 relevance:** PRE_V1_OPTIONAL; it becomes required only if
    chosen for adoption.
27. **Recommended FUTURE_WORK status after Chat review:** FW-P2-54 ready after Chat choice;
    FW-P2-01 remains product-decision blocked.
28. **Recommended roadmap effect after Chat review:** separate metadata browsing from reopening.
**Additional decision detail:** approve metadata-only library as the first slice and
    leave reopening unselected, or choose one reopening contract explicitly.

</details>

---

<a id="fw-p2-55"></a>

## FW-P2-55 — Adaptive Appearance Native Implementation

**Status:** Blocked
**Depends on:** accepted `LF-UI-2026-09-R1` design authority and the bounded preference-storage/ownership decision under `FW-P2-52`

**Completed boundary:** The design revision itself is complete. R1 approves Follow System as default, explicit Light/Dark choices and optional Deep Indigo/System Neutral preset direction.

**Remaining boundary:** Native adaptive rendering and runtime/accessibility acceptance remain unimplemented. This candidate owns implementation of the accepted appearance behavior, not another design campaign. Preference persistence ownership stays under `FW-P2-52`; implementation must not mutate financial data.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** FW-P2-52 owner/ADR and native system-accessibility proof.

**Smallest proposed boundary:** System/Light/Dark; no financial mutation.

**Decision record:** [PREFERENCES_ARCHITECTURE_DECISION_PACKET](#packet-preferences-architecture-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: ContentView forces dark scheme and custom gradient; R1 approves Follow System/Light/Dark and optional preset direction but has no native implementation.

**First-round scope and constraints:** Preference ownership remains FW-P2-52; reduced transparency/readable fallback and no financial mutation are mandatory. No new visual design, financial settings, downloads, or per-widget themes.

**First-round question/options:** What native appearance boundary is ready after R1 design approval? Hardcoded dark; app appearance preference; per-surface theme editor. R1 approves the second only after FW-P2-52.

**First-round remainder and implications:** MISSING: accepted storage owner, native behavior under system changes, contrast/compositing and runtime accessibility evidence. Architecture/storage decision first; no migration implied.

**First-round proposed acceptance/falsifier:** AP-01 through AP-06 plus UI-01/UI-05 runtime evidence. Preference model cannot preserve separate Light/Dark overrides or readable fallback.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: ContentView forces dark scheme and custom gradient; R1 approves Follow System/Light/Dark and optional preset direction but has no native implementation. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: FW-P2-52 owner/ADR and native system-accessibility proof. Owning authority: PREFERENCES_ARCHITECTURE_DECISION_PACKET.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-52`: The User and Workspace Preferences boundary must provide: Display only; reporting currency stays FX-owned.. This enables System/Light/Dark; no financial mutation. Remaining condition: FW-P2-52 owner/ADR and native system-accessibility proof.
- `REQUIRES_IMPLEMENTATION` → `FW-P2-52`: The User and Workspace Preferences boundary must provide: Display only; reporting currency stays FX-owned.. This enables System/Light/Dark; no financial mutation. Remaining condition: FW-P2-52 owner/ADR and native system-accessibility proof.

**Pinned evidence references:**

- [ContentView.swift](<../ContentView.swift>):1475-1480 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `c315381adf31633a27671b14499fc5dd12d7b794af047c82cfb2acf67990202b` — ContentView root appearance
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1590-1597 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-55
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1934-1959 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Preference ownership/storage remains unresolved.
- [Services/DevelopmentDatabaseProfilePreferences.swift](<../Services/DevelopmentDatabaseProfilePreferences.swift>):12-49 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — DEBUG UserDefaults validates unsafe values to defaults.

</details>

---

<a id="fw-p2-56"></a>

## FW-P2-56 — Development Performance Profiling

**Status:** Research
**Depends on:** Privacy-safe developer tooling and measured performance questions

Provide development-only profiling for:

- startup;
- repository hydration;
- parser and validation stages;
- persistence;
- import completion;
- large-view rendering;
- search and filtering.

Profiling output must remain separate from financial truth and must not retain sensitive source content.

**Current discovery disposition — 2026-09-10:** `WAIT_FOR_RUNTIME_ACCEPTANCE`. **Exact remaining gate:** Measured question and privacy-safe metric/retention owner.

**Smallest proposed boundary:** No profiling surface without use case.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: no profiling surface was found; developer console is bounded diagnostics rather than performance telemetry.

**First-round scope and constraints:** Profiling output must be separate from financial truth and retain no sensitive source content. No persistent telemetry, source payloads, automatic uploads, or production behavior.

**First-round question/options:** What development profiling is justified? External Instruments/task evidence; minimal DEBUG metric sink; persistent telemetry. The first has least product/privacy scope.

**First-round remainder and implications:** MISSING: named decision question, metric schema, collection owner, retention and privacy policy. No migration for external evidence; product storage would require architecture.

**First-round proposed acceptance/falsifier:** A metric is tied to a decision, excludes source data, and is reproducible on pinned build/scenario. Metric collection stores a source fragment or affects import behavior.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: no profiling surface was found; developer console is bounded diagnostics rather than performance telemetry. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Task-owned native runtime evidence

**Personal-v1:** POST_V1

**Recommendation after Chat:** WAIT_FOR_RUNTIME_ACCEPTANCE **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** MACOS_PLATFORM, ACCESSIBILITY_ACCEPTANCE.

**Typed dependencies:**

- `REQUIRES_RUNTIME_ACCEPTANCE` → `FW-P2-51`: The Startup, Runtime and Import Performance Optimization boundary must provide: No optimization from static theory.. This enables No profiling surface without use case. Remaining condition: Measured question and privacy-safe metric/retention owner.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1601-1613 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-56
- [Core/DeveloperConsole.swift](<../Core/DeveloperConsole.swift>):47-93 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `f496995df7f425b7f556036d697992aa7bafed3fa4bde39e16031dc7500efc34` — DeveloperConsole
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2030-2055 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Development Performance Profiling as Research and records this unresolved boundary: MISSING: named decision question, metric schema, collection owner, retention and privacy policy.

</details>

---

<a id="fw-p2-61"></a>

## FW-P2-61 — Authentic-Corpus Regression Matrix Maintenance

**Status:** Maintenance
**Depends on:** ADR-046 and the current supported-source/profile registry

**Completed boundary:** The accepted unnumbered reset established the engineering complete-authentic-corpus regression matrix across the registered 127 carriers, including provider/order campaigns and current native-currency regression across INR and QAR families.

**Remaining boundary:** Maintain the cumulative matrix as recurring authentic sources or shared ingestion semantics change, preserve explicit certified/uncertified family boundaries and keep engineering matrix output aligned with user/engineering support documentation under `FW-P2-79`.

This item must not describe LedgerForge as lacking an engineering corpus matrix, and it must never substitute historical implementation acceptance or fixture presence for current ADR-046 certification.

**Discovery 2026-09-10:** REUSED_EVIDENCE / REUSE_EXISTING_DISCOVERY at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`. VERIFIED_REPOSITORY: accepted reset records 127 carriers/103 statements with provider/order campaigns.

**Discovery remainder:** MISSING: only future recurrence/shared changes; no present matrix deficiency evidenced. **Next boundary:** PROPOSED: register each original/exclusion/archive with opaque evidence and rerun based on component reach. **Acceptance:** Record family set, complete ordinary gate, oracle identity and certified/uncertified boundary.


---

<details>
<summary>First-round evidence retained; no second-round scope expansion</summary>

**question (research ref):** Does an authentic-corpus matrix exist and what maintenance remains?

**current behavior (research ref):** VERIFIED_REPOSITORY: accepted reset records 127 carriers/103 statements with provider/order campaigns. Maintenance means adding recurring originals and rerunning affected corpus on shared changes.

**accepted constraints (research ref):** VERIFIED_REPOSITORY: historical fixtures do not replace ADR-046 certification; absent cases cannot be fabricated.

**missing (research ref):** MISSING: only future recurrence/shared changes; no present matrix deficiency evidenced.

**options (research ref):** PROPOSED: event-driven updates; no second generic campaign.

**proposed boundary (research ref):** PROPOSED: register each original/exclusion/archive with opaque evidence and rerun based on component reach.

**scope exclusions (research ref):** No recertification here, synthetic matrix, profile or support expansion.

**dependencies (research ref):** New carrier/shared change; FW-P2-79 alignment.

**adr migration impact (research ref):** No migration/ADR change; ADR-046 is current.

**acceptance (research ref):** Record family set, complete ordinary gate, oracle identity and certified/uncertified boundary.

**invalidators (research ref):** 127 carriers as new-family/zero-activity coverage invalidates claim.

**personal v1 (research ref):** VERIFIED_REPOSITORY: matrix exists; v1 undeclared.

**queue roadmap disposition (research ref):** Keep Maintenance / REUSE_EXISTING_DISCOVERY.

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1622-1633 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-61
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):46-69 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7843854eee6c85888f41af52c52aba70f2d0138c5f6f21e518211c75aca62797` — ADR-046 current alignment

</details>

---

<a id="fw-p2-63"></a>

## FW-P2-63 — Additional Cross-Format Authentic-Source Semantic-Parity Tests

**Status:** Candidate
**Depends on:** a newly selected exact source relationship or materially changed recurring carrier family with complete authentic evidence

**Completed boundary:** HDFC PDF/XLS semantic parity is accepted under ADR-042; CBQ current-account multi-source lineage/parity is covered under ADR-043; Axis-card PDF/XLSX parity is accepted under ADR-044; and the accepted 127-carrier reset establishes format-neutral semantic-parity regression for the registered Axis-bank carriers.

**Remaining boundary:** Only future/new carrier pairs, materially changed recurring families, same-format semantic relationships or newly approved partial-overlap semantics remain. Axis-bank engineering semantic parity does **not** by itself establish durable cross-format duplicate/equivalence/suppression semantics; those remain governed separately by `FW-P0-19` and `FW-P1-16`.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No new pair/changed family or declared regression-only versus durable purpose.

**Smallest proposed boundary:** Register pair and purpose first.

**Decision record:** [TRANSFER_FAMILY_DECISION_PACKET](#packet-transfer-family-decision-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: HDFC/CBQ/Axis-card relationships accepted; Axis-bank parity is not durable equivalence; no new pair selected.

**First-round scope and constraints:** VERIFIED_REPOSITORY: parity needs paired authentic truth/projection; durable effects separately governed. No generic parity/fuzzy matching/suppression/broader support.

**First-round question/options:** What new cross-format parity is justified? PROPOSED: regression-only pair or durable relationship architecture; defer.

**First-round remainder and implications:** MISSING: exact pair/changed family, full relationship evidence and test-only versus durable purpose. No migration test-only; durable may need ADR/migration.

**First-round proposed acceptance/falsifier:** Complete pairs, source projection, authentic mismatch evidence, parity/hydration for durable behavior. Incomplete projection or similar-looking rows insufficient.

**Second-round new evidence/resolved direction:** Accepted pairs do not establish new durable relationships.

**Exact next evidence or decision:** Complete paired authentic source/oracle and relationship classification.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Candidate blocked on source **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Partial/changed pair.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, IDENTITY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P1-16`: Durable relationship only.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-new-representation-pair`: No pair.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p2-63`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. No new pair/changed family or declared regression-only versus durable purpose.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1635-1644 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-63
- [Project documents/ADR.md](<ADR.md>):5011-5619 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-042/043/044
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):570-580 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Semantic parity is not equivalence.

</details>

---

<a id="fw-p2-64"></a>

## FW-P2-64 — Large-Statement and Long-Running Import Tests

**Status:** Candidate
**Depends on:** Authentic large statements for source-path acceptance and/or explicitly non-source generated stress data for resource-limit testing; generated financial-source fixtures cannot certify parser support

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No genuine large carrier, resource target, or approved nonfinancial stress shape.

**Smallest proposed boundary:** Nonfinancial resource/cancel mechanics first; authentic large carrier separately.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: progress type exists; OOXML has explicit source/row/cell limits; queue distinguishes authentic source-path tests from nonfinancial stress mechanics.

**First-round scope and constraints:** VERIFIED_REPOSITORY: ADR-046 technical ceilings are explicit resources, not finance profiles; generated financial fixtures prohibited. No financial fixture, benchmark archaeology/runtime probe here or recertification.

**First-round question/options:** How split large-statement/source and long-running resource tests without fabricated statements? PROPOSED: authentic large-source gate, nonfinancial mechanics gate, or defer budget.

**First-round remainder and implications:** MISSING: genuine large carrier, performance/resource targets and approved nonfinancial stress shape. No migration; changed limits may need architecture review.

**First-round proposed acceptance/falsifier:** Stated limit/latency/cancel, fail-closed resource error, genuine semantics separately. Resource failure as semantic rejection or synthetic load as support invalid.

**Second-round new evidence/resolved direction:** Resource mechanics and financial semantics must remain separate.

**Exact next evidence or decision:** Chosen ceiling/cancel target and, separately, genuine large source for semantic path.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve queue priority/status; explicitly defer until a real selected source or product workflow demonstrates need. See bounded decision queue. **Roadmap:** Do not schedule

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Synthetic source as support claim.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** SOURCE_TRUTH, PERFORMANCE_EVIDENCE, NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `decision-resource-target`: Future reopening condition only; this deferred boundary is not a current prerequisite. Unselected future scope only; no current user decision is pending for the deferred boundary.
- `OPTIONAL_ENHANCEMENT` → `source-large-authentic-carrier`: Future reopening condition only; this deferred boundary is not a current prerequisite. No semantic source.
- `OPTIONAL_ENHANCEMENT` → `post-swift6-performance`: Future reopening condition only; this deferred boundary is not a current prerequisite. Dynamic evidence.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1646-1651 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-64
- [Import/Readers/OOXMLDocumentReader.swift](<../Import/Readers/OOXMLDocumentReader.swift>):58-69 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `1f3056f59ec351b4a8e9e2cbe4533cd405ac3dd37fc269a8587cf773d8e88ae5` — OOXMLReaderLimits
- [Import/Models/ImportProgress.swift](<../Import/Models/ImportProgress.swift>):1-65 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `4b1647261e0d998bcde55622b2694475a293b44284f79bfabe980369108186a6` — ImportProgress
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):85-95 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No fabricated statement cases.

</details>

---

<a id="fw-p2-65"></a>

## FW-P2-65 — Repository Corruption and Recovery Tests

**Status:** Research
**Depends on:** Successful completion and approval of Sprint 47, plus an approved broader corruption-recovery test boundary

Define a broader repository corruption and recovery regression matrix beyond the focused tests required by individual implementation candidates.

Coverage should include:

- SQLite opening or initialization failure;
- migration checksum tampering;
- edited previously applied migrations;
- missing lower migrations;
- duplicated migration versions;
- incomplete migration records;
- unsupported future migration versions;
- corrupted or missing repository relationships;
- interrupted lifecycle operations;
- fail-closed production behaviour;
- recovery without silent substitution of an in-memory provider;
- privacy-safe diagnostics;
- valid upgrades from every supported prior schema version;
- preservation of trusted financial history during recovery.

This item does not authorize automated repair.

Production repair remains governed by `FW-P0-08`. Sprint 47 completed focused fail-closed startup and migration-chain verification tests; this candidate remains limited to the broader corruption and recovery regression matrix.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** Approved wider failure matrix and genuine historical financial upgrade/recovery evidence.

**Smallest proposed boundary:** No invented corruption/history cases.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: tests define duplicate/missing/tampered/incomplete/future migration histories and every EMPTY historical prefix reopening to current. MigrationIdentityLockTests independently pins accepted identities. These definitions do not prove populated historical upgrades or every relationship-corruption/recovery case.

**First-round scope and constraints:** The app remains private, local and explicit. Accepted financial history, native Money, order, multiplicity and provenance cannot be silently rewritten. ADR-046 authentic-input rules apply to financial cases; migration identities remain append-only. Discovery grants no implementation or acceptance. No automated repair, refreshed migration lock, in-memory substitution, current database mutation, fabricated statements or execution of tests in discovery.

**First-round question/options:** Which corruption/recovery coverage remains beyond accepted focused tests? Reuse focused history tests and add only named uncovered transitions; a universal automated repair campaign would need a separate financial authority.

**First-round remainder and implications:** Approved broader failure matrix; genuine trusted historical data for any financial upgrade/recovery case; precise interrupted lifecycle and relationship classes not already owned by focused work. Tests alone should not change schema; a confirmed invariant repair would require its own approved migration/ADR assessment.

**First-round proposed acceptance/falsifier:** Failure must leave trusted source/destination unchanged or explicitly unavailable; compare independent genuine records through reopen/hydration; absent populated prior-version evidence stays missing. Isolated nonfinancial schema mechanics may use source-independent values. New accepted migration/provider lifecycle or newly supplied historical database alters matrix coverage.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: tests define duplicate/missing/tampered/incomplete/future migration histories and every EMPTY historical prefix reopening to current. MigrationIdentityLockTests independently pins accepted identities. These definitions do not prove populated historical upgrades or every relationship-corruption/recovery case. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Approved authentic source evidence

**Personal-v1:** POST_V1

**Recommendation after Chat:** BLOCKED_ON_AUTHENTIC_SOURCE **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** SOURCE_TRUTH, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-08`: The Data-Integrity Verification and Repair boundary must provide: Read-only complete accepted-import graph verifier with privacy-safe counts and fail-closed unreadable input.. This enables No invented corruption/history cases. Remaining condition: Approved wider failure matrix and genuine historical financial upgrade/recovery evidence.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-historical-upgrade`: The explicitly named gate source-historical-upgrade must be satisfied. This enables No invented corruption/history cases. Remaining condition: Approved wider failure matrix and genuine historical financial upgrade/recovery evidence.

**Pinned evidence references:**

- [LedgerForgeTests/MigrationChainIntegrityTests.swift](<../LedgerForgeTests/MigrationChainIntegrityTests.swift>):253-367 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `6ad68d2dd32d041fe1224e644c3d067d3539ecfb63dd53793560e22f3d854688` — empty historical prefixes and fail-closed history tests
- [LedgerForgeTests/MigrationIdentityLockTests.swift](<../LedgerForgeTests/MigrationIdentityLockTests.swift>):1-52 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `722c49a26a6785be7c4d537973d0a2790fc84b162d310e04ed399e6fdd0fcae9` — independent identity lock and drift detection
- [Database/SQLiteDatabase.swift](<../Database/SQLiteDatabase.swift>):109-146 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `5945852ad75513a1fcbd15c692512ab35786523da9defd889b9d4f7f710b474a` — createBackup; checkpointAndClose
- [Database/SQLiteRepositoryProvider.swift](<../Database/SQLiteRepositoryProvider.swift>):1381-1450;1540-1591 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `29166a1e985c9c4f5b43e6d13243a82fa5ff5e94382747b3fb406ae0dc98b454` — createAndVerifyBackup; restorePersistentDebugBackup
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2102-2136 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Repository Corruption and Recovery Tests as Research and records this unresolved boundary: Approved broader failure matrix; genuine trusted historical data for any financial upgrade/recovery case; precise interrupted lifecycle and relationship classes not already owned by focused work.

</details>

---

<a id="fw-p2-67"></a>

## FW-P2-67 — App Shell and Workflow Decomposition

**Status:** Maintenance
**Depends on:** Stable current navigation, window structure and import behaviour; PR-1 where hydration/runtime-store ownership is touched

**Sprint 80 ownership boundary:** Any decomposition that touches hydration,
runtime stores or import coordination must follow PR-1's explicit staging and
MainActor publication seam. The accepted serial Import Centre boundary does not
authorize a parallel coordinator or a Swift-6 migration as part of this
maintenance item.

Decompose the monolithic SwiftUI application shell while preserving approved financial behaviour and the current product design.

Required direction includes:

- the root scene owning structural composition rather than financial workflows;
- purpose-owned views for major presentation domains;
- import preparation, confirmation and result coordination moved out of presentation-only views;
- persistence lifecycle and provider state coordinated outside ordinary view rendering;
- repository hydration coordination moved behind an explicit workflow or application boundary;
- repository, provider and `RepositoryStoreHydrator` authority preserved;
- existing navigation, keyboard behaviour, accessibility and window behaviour retained unless separately approved;
- no financial-domain redesign merely to complete the structural refactor.

The exact file names, scene hierarchy and coordinator types require implementation planning. This candidate does not authorize an application architecture rewrite.

**Current discovery disposition — 2026-09-10:** `WAIT_POST_SWIFT6`. **Exact remaining gate:** Static decomposition is prepared; exact accepted post-Sprint-87 provider/hydrator/actor ownership must be revalidated before any Sprint88 refactor planning. Native parity then remains implementation acceptance.

**Smallest proposed boundary:** Five-phase shell extraction blueprint in packet.

**Decision record:** [SHELL88_AND_SPRINT89_NATIVE_PROCEDURE](<Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md#packet-shell88-and-sprint89-native-procedure>).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: ContentView is 4,103 lines and owns navigation, hydration startup, multiple view models, import presentation and DEBUG profile state; app root is WindowGroup -> ContentView.

**First-round scope and constraints:** Behavior-preserving; preserve repository/hydrator/provider authority and R1 shell direction; do not bundle Swift-6, parallel coordinator, financial redesign or broad moves. No file-tree consolidation, database/provider rewrite, concurrency migration, or navigation redesign.

**First-round question/options:** How should the shell be decomposed without physical reorganization? Extract presentation subviews only; create explicit app workflow boundary; broad architecture rewrite. The first two should be phased under Sprint 88.

**First-round remainder and implications:** MISSING: a responsibility map and stable pre/post behavioral contract; runtime regression evidence. No migration; ADR only if authority changes.

**First-round proposed acceptance/falsifier:** Existing targeted behavior plus hydration, cancellation, keyboard/accessibility and lifecycle parity; runtime as required by future packet. Extraction changes owner/publication order or introduces new coordinator semantics.

**Second-round new evidence/resolved direction:** Five-phase extraction and native acceptance procedure.

**Exact next evidence or decision:** Task-owned native runtime evidence

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** WAIT_POST_SWIFT6, then bounded implementation planning after ownership delta; native parity remains future acceptance. **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=true, authentic source=false. **Blocker types:** MACOS_PLATFORM, ACCESSIBILITY_ACCEPTANCE, DEPENDENCY.

**Typed dependencies:**

- `REQUIRES_POST_SWIFT6` → `FW-P2-73`: The explicitly named gate FW-P2-73 must be satisfied. This enables Five-phase shell extraction blueprint in packet. Remaining condition: Static decomposition is prepared; exact accepted post-Sprint-87 provider/hydrator/actor ownership must be revalidated before any Sprint88 refactor planning. Native parity then remains implementation acceptance.

**Pinned evidence references:**

- [ContentView.swift](<../ContentView.swift>):1322-1480 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `c315381adf31633a27671b14499fc5dd12d7b794af047c82cfb2acf67990202b` — ContentView
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1683-1707 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-67
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2137-2165 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Shell decomposition must preserve runtime ownership.
- [ContentView.swift](<../ContentView.swift>):1443-1624 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Archive has a custom monolithic shell.

</details>

---

<a id="fw-p2-69"></a>

## FW-P2-69 — Remaining macOS CI and UI Smoke Validation

**Status:** Maintenance
**Depends on:** an approved CI/UI-smoke or distribution objective

**Completed boundary:** Repository-owned local build/test entry points, exact-singleton build/run verification, deterministic local cycle-close validation, Debug/Release build foundations and current local runtime/build-identity mechanics are accepted and must not be reopened by this candidate.

**Remaining boundary:** CI-provider setup, commit-status protection, generic UI smoke automation or an approved replacement/enabling of UI-test coverage, plus later distribution/notarization/deployment work where separately selected.

No alternate build configuration may diverge from Xcode project truth.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Exact CI/UI-smoke/distribution objective: provider, protected branch, selectors or channel.

**Smallest proposed boundary:** Local foundations already accepted.

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P2-69 | **User product choice:** desired CI/UI-smoke/distribution outcome. | Provider, protected-branch, selector, and smoke goal depend on delivery workflow. | Local-only validation. | One CI test gate. | Focused UI smoke or distribution objective. | A until delivery objective exists. | No hosted CI/UI smoke claim. | Selected platform qualification only. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: local build/test/run foundations are accepted; scripts explicitly exclude UI smoke, CI and distribution changes.

**First-round scope and constraints:** No alternate configuration divergent from project truth; do not infer UI coverage from local static evidence. No CI config, UI test enablement, signing/distribution work, or runtime probe.

**First-round question/options:** What CI/UI-smoke/distribution outcome is wanted? Remain local-only; approve CI test gate; approve focused UI smoke; approve distribution. Product context does not select one.

**First-round remainder and implications:** MISSING: provider, protected-branch, smoke objective, enabled UI-test strategy, or distribution decision. No impact until objective.

**First-round proposed acceptance/falsifier:** Future plan names exact Xcode truth, platform, test selectors and failure handling. Objective requires secrets, remote services, or unsupported UI test environment.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: local build/test/run foundations are accepted; scripts explicitly exclude UI smoke, CI and distribution changes. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Exact CI/UI-smoke/distribution objective: provider, protected branch, selectors or channel. Owning authority: FW-P2-69 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** BLOCKED_ON_PRODUCT_DECISION **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-distribution`: Chat owns this financial/privacy/architecture decision; it is not a technical questionnaire for the user.
- `REQUIRES_USER_DECISION` → `decision-product-fw-p2-69`: Exact CI/UI-smoke/distribution objective: provider, protected branch, selectors or channel.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1711-1721 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-69
- [script/README.md](<../script/README.md>):156-161 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `a997edab741f740f6367756bb7a451ed7d708dee7ec4d5b9f08f1460a2eb4377` — Explicit exclusions
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2170-2187 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Remaining macOS CI and UI Smoke Validation as Maintenance and records this unresolved boundary: MISSING: provider, protected-branch, smoke objective, enabled UI-test strategy, or distribution decision.

</details>

---

<a id="fw-p2-70"></a>

## FW-P2-70 — Remaining macOS Target and Distribution Metadata Hardening

**Status:** Maintenance
**Depends on:** an approved macOS target/distribution metadata decision for each remaining surface

**Completed boundary:** Bundle-derived version/build presentation, local startup/build identity and R1 resource-containment verification are accepted and are not future work here.

**Remaining boundary:** stale non-macOS platform/device metadata, irrelevant generated plist keys, unexpected governance/development resources in built products, minimum-version and entitlement/capability decisions, hardened-runtime/distribution policy and eventual Developer ID/notarization/packaging if external distribution is approved.

No bundle-inclusion defect may be inferred from navigator visibility; target/build-phase or inspected-product evidence is required.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Supported target/distribution, entitlement, minimum OS, hardened-runtime/notarization matrix.

**Smallest proposed boundary:** Do not audit unselected shipping surfaces.

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P2-70 | **User product choice:** supported target and distribution intent. | Entitlements, minimum OS, hardened runtime, and notarization should follow actual shipping scope. | Keep current local target metadata. | Define Mac distribution matrix then audit selected surfaces. | — | A until product ships beyond local use. | No distribution hardening project. | Bounded target/metadata audit. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: project declares multiple supported platforms and platform-specific generated plist keys; release target permits several capabilities. Current authority says stale metadata/distribution policy remain unselected.

**First-round scope and constraints:** No bundle inclusion conclusion from navigator visibility; no distribution/entitlement change without per-surface decision. No project settings change, signing, notarization, or bundle probe now.

**First-round question/options:** Which target/distribution metadata requires hardening? Mac-only cleanup; retain multi-platform metadata; distribution hardening. Each needs product authorization.

**First-round remainder and implications:** MISSING: supported-platform product decision, entitlement/capability rationale, minimum-version target, hardened-runtime/notarization objective. No migration; entitlement architecture may need accepted decision.

**First-round proposed acceptance/falsifier:** Target-build and inspected-product evidence, entitlement review, and signed product proof. A capability is needed by an accepted product surface.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: project declares multiple supported platforms and platform-specific generated plist keys; release target permits several capabilities. Current authority says stale metadata/distribution policy remain unselected. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Supported target/distribution, entitlement, minimum OS, hardened-runtime/notarization matrix. Owning authority: FW-P2-70 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** BLOCKED_ON_PRODUCT_DECISION **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-distribution`: Chat owns this financial/privacy/architecture decision; it is not a technical questionnaire for the user.
- `REQUIRES_USER_DECISION` → `decision-product-fw-p2-70`: Supported target/distribution, entitlement, minimum OS, hardened-runtime/notarization matrix.

**Pinned evidence references:**

- [LedgerForge.xcodeproj/project.pbxproj](<../LedgerForge.xcodeproj/project.pbxproj>):1368-1461 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `08dbe3df432f0dd1a78fe123eca04cb7d806a2809f599b30034c95eab7212d34` — LedgerForge target build settings
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1724-1735 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-70
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2188-2205 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Remaining macOS Target and Distribution Metadata Hardening as Maintenance and records this unresolved boundary: MISSING: supported-platform product decision, entitlement/capability rationale, minimum-version target, hardened-runtime/notarization objective.

</details>

---

<a id="fw-p2-71"></a>

## FW-P2-71 — Repository and Xcode Metadata Hygiene

**Status:** Maintenance
**Depends on:** None

**Completed slice 2026-07-23:** commit `7ee20a909038d1088f830a6ea588311625f415e5` removed the tracked user-specific Find Navigator scope, breakpoint list and scheme-management state from the Git index.

Remaining work is prevention and broader hygiene:

- verify ignore coverage for user-specific Xcode state;
- distinguish shared schemes/configuration from personal IDE metadata;
- add repository checks where proportionate;
- cover derived products, local databases, temporary SQLite files, generated files, sensitive diagnostics and exported private fixtures;
- document privacy-safe cleanup for prohibited metadata already introduced in future.

Do not remove shared Xcode configuration merely because it lives beneath the project bundle. Repository evidence must distinguish personal from shared state.

**Current discovery disposition — 2026-09-10:** `READY_FOR_IMPLEMENTATION_PLANNING`. **Exact remaining gate:** Proportionate ignored/generated/private metadata inventory and prevention check.

**Smallest proposed boundary:** No behavior/financial change.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: user-specific Xcode state was previously removed; project has a synchronized UI Assets folder with explicit target-membership exclusions, while AGENTS.md remains a resource.

**First-round scope and constraints:** Do not remove shared configuration merely because it is in the project bundle; preserve privacy and exact membership. No clean/reset, broad ignores, source-tree move, or target-membership edit.

**First-round question/options:** What repository/Xcode hygiene remains? Manual documented checks; narrow repo guard; broad clean script. First two preserve safe scope.

**First-round remainder and implications:** MISSING: current ignored/generated/private metadata inventory and a proportionate prevention check. None.

**First-round proposed acceptance/falsifier:** Exact allow/deny paths, zero false positives for shared project assets, and no bundle change. Rule would hide required shared schemes/resources.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: user-specific Xcode state was previously removed; project has a synchronized UI Assets folder with explicit target-membership exclusions, while AGENTS.md remains a resource. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Proportionate ignored/generated/private metadata inventory and prevention check. Owning authority: FW-P2-71 pinned queue scope and the named dependency below.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** READY_FOR_IMPLEMENTATION_PLANNING **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `FW-P2-77`: The Source Tree and Documentation Organization Consolidation boundary must provide: No moves before source boundary map.. This enables No behavior/financial change. Remaining condition: Proportionate ignored/generated/private metadata inventory and prevention check.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1737-1752 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-71
- [LedgerForge.xcodeproj/project.pbxproj](<../LedgerForge.xcodeproj/project.pbxproj>):365-390;966-990 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `08dbe3df432f0dd1a78fe123eca04cb7d806a2809f599b30034c95eab7212d34` — UI Assets exception set/resources
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2206-2229 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Repository and Xcode Metadata Hygiene as Maintenance and records this unresolved boundary: MISSING: current ignored/generated/private metadata inventory and a proportionate prevention check.

</details>

---

<a id="fw-p2-74"></a>

## FW-P2-74 — PR-3 Dependency Concurrency Boundary

**Status:** Candidate
**Depends on:** Sprint 80 accepted readiness discovery; PR-2 ownership accepted in Sprint 84 at `a4dd6929a2282cc94c850eb1dccf350b1ee5c8a1`

Chat has authorized this bounded execution after accepting PR-2. It remains unaccepted work until the next Chat gate; current execution and validation conditions belong to the current roadmap and supplied campaign prompt.

Resolve the dependency boundary before coordinated Swift-6 migration:

- make the ZIPFoundation Swift-6 correction or upgrade decision; and
- define the LegacyXLS/libxls concurrency policy.

The result must remain bounded to the approved dependency surfaces and must not
be treated as generic third-party concurrency support.

**Discovery 2026-09-10:** REUSED_EVIDENCE / OWNED_BY_ACTIVE_SPRINT at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`. VERIFIED_REPOSITORY: FW-P2-74 is bounded to ZIPFoundation and LegacyXLS/libxls; no UI evidence affects it.

**Discovery remainder:** MISSING: dependency-specific diagnostic/upgrade evidence owned by active campaign. **Next boundary:** PROPOSED: no finding beyond preserving strict dependency-only scope. **Acceptance:** Owner supplies dependency-specific compilation/behavior evidence.

<details>
<summary>First-round evidence retained; no second-round scope expansion</summary>

**question (research ref):** Does this lane add to PR-3 dependency policy?

**current behavior (research ref):** VERIFIED_REPOSITORY: FW-P2-74 is bounded to ZIPFoundation and LegacyXLS/libxls; no UI evidence affects it.

**accepted constraints (research ref):** No generic third-party concurrency support or Swift-6 migration.

**missing (research ref):** MISSING: dependency-specific diagnostic/upgrade evidence owned by active campaign.

**options (research ref):** Reuse active proof; independently inspect vendor. Reuse respects ownership.

**proposed boundary (research ref):** PROPOSED: no finding beyond preserving strict dependency-only scope.

**scope exclusions (research ref):** No vendor update, wrappers, flags, or UI code.

**dependencies (research ref):** Active PR-3 campaign.

**adr migration impact (research ref):** None in this lane.

**acceptance (research ref):** Owner supplies dependency-specific compilation/behavior evidence.

**invalidators (research ref):** Dependency surface expands into app architecture.

**personal v1 (research ref):** REPORTED_ONLY: prepared prerequisite.

**queue roadmap disposition (research ref):** OWNED_BY_ACTIVE_SPRINT; reuse only.

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1769-1780 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-74
- [Project documents/Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md](<Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md>):137-141 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `3f65ec7e7fefc1eed15ba874f18a66985ffbec855634bc9bd473c07b928ce82c` — Sprint 85

</details>

---

<a id="fw-p2-75"></a>

## FW-P2-75 — TEST-PR Unit-Test Strict-Concurrency Correction

**Status:** Candidate
**Depends on:** Sprint 80 accepted unit-test strict probe; accepted PR-2 ownership; Chat acceptance of the pending PR-3 boundary before execution

Make the unit-test target honest under coordinated strict migration through
actor-aware fixture construction, async-safe test synchronization, subprocess
Sendable ownership and actor-aware assertions/macros. The accepted strict probe
found 45 distinct error locations and a large warning surface concentrated in
fixtures/support code; this family must preserve independent test oracles and
must not weaken production assertions to silence diagnostics.

TEST-PR is required before the unit-test target can participate in the
coordinated Swift-6 migration.

The current campaign amendment keeps production-source bytes frozen for TEST-PR and requires independent assertion/oracle and inventory preservation. A required production/runtime correction is a stop condition for Chat disposition, not permission to extend test-only work.

**Discovery 2026-09-10:** REUSED_EVIDENCE / OWNED_BY_ACTIVE_SPRINT at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`. VERIFIED_REPOSITORY: the test target is Swift 5 with approachable concurrency but no explicit default MainActor setting in shown configurations; queue records 45 readiness error locations.

**Discovery remainder:** MISSING: exact active diagnostics and offending test fixtures/support symbols. **Next boundary:** PROPOSED: active owner alone checks actor-aware construction/synchronization after matching diagnostics. **Acceptance:** Exact compiler diagnostics plus tests preserving independent assertions.

<details>
<summary>First-round evidence retained; no second-round scope expansion</summary>

**question (research ref):** Does platform research alter TEST-PR?

**current behavior (research ref):** VERIFIED_REPOSITORY: the test target is Swift 5 with approachable concurrency but no explicit default MainActor setting in shown configurations; queue records 45 readiness error locations.

**accepted constraints (research ref):** Preserve independent source/test oracles; never weaken assertions merely to silence diagnostics.

**missing (research ref):** MISSING: exact active diagnostics and offending test fixtures/support symbols.

**options (research ref):** Reuse current active ownership; independently reproduce. The second is forbidden here.

**proposed boundary (research ref):** PROPOSED: active owner alone checks actor-aware construction/synchronization after matching diagnostics.

**scope exclusions (research ref):** No test execution, fixture edits, flag changes, or broad migration.

**dependencies (research ref):** Active TEST-PR campaign.

**adr migration impact (research ref):** None in this lane.

**acceptance (research ref):** Exact compiler diagnostics plus tests preserving independent assertions.

**invalidators (research ref):** Changing language/default-isolation settings invalidates snapshot conclusion.

**personal v1 (research ref):** REPORTED_ONLY: coordinated migration prerequisite.

**queue roadmap disposition (research ref):** OWNED_BY_ACTIVE_SPRINT; reuse only.

- [LedgerForge.xcodeproj/project.pbxproj](<../LedgerForge.xcodeproj/project.pbxproj>):1465-1515 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `08dbe3df432f0dd1a78fe123eca04cb7d806a2809f599b30034c95eab7212d34` — LedgerForgeTests settings
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1782-1795 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-75

</details>

---

<a id="fw-p2-76"></a>

## FW-P2-76 — Coordinated Swift-6 Migration

**Status:** Blocked
**Depends on:** PR-2 accepted in Sprint 84 at `a4dd6929a2282cc94c850eb1dccf350b1ee5c8a1`; pending PR-3 and TEST-PR acceptance. The serial Unified Import Centre boundary is accepted through Sprints 82–83.

After the prerequisite families are accepted, perform one coordinated Swift-6
strict migration and readiness pass. The migration is not a prerequisite to
begin the serial Swift-5 Unified Import Centre, but it is required before
personal-v1 certification. Swift-6 migration is not complete or approved by
Sprint 80; the readiness discovery only establishes that the compiler can be
reached and that the remaining work is materially known.

**Discovery 2026-09-10:** REUSED_EVIDENCE / OWNED_BY_ACTIVE_SPRINT at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`. VERIFIED_REPOSITORY: Swift 6 migration is blocked; only readiness discovery is accepted, and root UI is currently captured by app default MainActor isolation.

**Discovery remainder:** MISSING: acceptance of prerequisites and current full compiler result. **Next boundary:** PROPOSED: no recommendation beyond reuse of recorded sequencing and settings caveat. **Acceptance:** Future owner uses exact diagnostics/settings, build/test plan and behavior-sensitive validation.

**Readiness finding retained after Sprint-84 acceptance — 2026-09-10:** the Swift-5 complete strict-concurrency probe at published parent `af2d1949c6e9a73af3bb004422b72882d28195e2` also exposes five production diagnostics outside PR-2: the `PreparedImport` / `ImportCentrePreparation` conformance in `Import/Coordinator/ImportCentreCoordinator.swift`, the `StatementDropItemProvider.Completion` capture in `Import/Presentation/StatementDropIntakeAdapter.swift`, and three salary/funding-plan reconstruction isolation diagnostics in `Services/RepositoryStoreHydrator.swift`. These are recorded strict-readiness boundaries, not verified runtime or financial defects; no contradictory evidence against accepted PR-1 publication was established. They remain owned here for Chat disposition before Sprint 87 and are excluded from Sprint 84 persistence corrections, Sprint 85 dependency corrections and Sprint 86 test-only corrections. This finding does not authorize their repair or reopen accepted financial semantics. Exact before/after diagnostics belong to the local Sprint-84 acceptance evidence.

<details>
<summary>First-round evidence retained; no second-round scope expansion</summary>

**question (research ref):** Does UI discovery change coordinated Swift-6 migration?

**current behavior (research ref):** VERIFIED_REPOSITORY: Swift 6 migration is blocked; only readiness discovery is accepted, and root UI is currently captured by app default MainActor isolation.

**accepted constraints (research ref):** Prerequisites PR-2/PR-3/TEST-PR plus serial Import Centre; no feature work bundled.

**missing (research ref):** MISSING: acceptance of prerequisites and current full compiler result.

**options (research ref):** Wait for prerequisites; migrate early; combine feature work. Only wait conforms.

**proposed boundary (research ref):** PROPOSED: no recommendation beyond reuse of recorded sequencing and settings caveat.

**scope exclusions (research ref):** No source edit, flag change, actor redesign, or UI refactor.

**dependencies (research ref):** PR-2, PR-3, TEST-PR accepted; serial Import Centre complete.

**adr migration impact (research ref):** No migration in this lane.

**acceptance (research ref):** Future owner uses exact diagnostics/settings, build/test plan and behavior-sensitive validation.

**invalidators (research ref):** Accepted prerequisite scope changes.

**personal v1 (research ref):** REPORTED_ONLY: required before certification in current queue.

**queue roadmap disposition (research ref):** OWNED_BY_ACTIVE_SPRINT; retain Blocked.

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1797-1807 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-76
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):1663-1664 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7843854eee6c85888f41af52c52aba70f2d0138c5f6f21e518211c75aca62797` — Sprint 80 sequencing

</details>

---

<a id="fw-p2-77"></a>

## FW-P2-77 — Source Tree and Documentation Organization Consolidation

**Status:** Ready for discovery
**Type:** Maintenance
**Depends on:** None
**Origin:** User / documentation synchronization, 2026-09-09
**Evidence / authority:** Repository structure reviewed during the 2026-09-09 planning reconciliation at `main@a560312db5900645779a499016e13f0c87e81435`
**Disposition date:** 2026-09-09
**Owning specification / ADR:** Repository organization discovery; no accepted target layout yet
**Personal-v1 relevance:** Maintenance/readability; not itself an adoption gate

**Purpose:** Establish one understandable repository organization and naming model while preserving behavior, Git history, Xcode membership and project authority.

Verified structural signals include root analyzer/detector/normalizer/parser/reader areas coexisting with feature-local import folders, mixed responsibilities in `Core`, an oversized `ContentView.swift`, mixed Project-doc naming and historical roadmap naming residue.

Discovery must cover feature-oriented versus layer-oriented placement, root ownership, Import/Ingestion boundaries, Core ownership, Views/ViewModels, test-tree correspondence, Project-doc archival naming, Xcode references/resources, script/path assumptions and Git-history impact.

Explicit boundaries:

- no financial behavior change merely for neatness;
- no parser consolidation solely because folders look similar;
- no Swift package/framework split without separate architecture approval;
- no mass move mixed with behavioral refactor;
- no private-original/evidence relocation;
- no migration;
- no speculative target tree accepted before discovery.

Cross-links: `FW-P2-67` owns app-shell/workflow decomposition; `FW-P2-71` owns Xcode/user-metadata hygiene; `FW-P2-77` owns repository organization/naming discovery.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Shell ownership clarity and target/path-consumer map.

**Smallest proposed boundary:** No moves before source boundary map.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: root contains mixed layer/feature directories and a 4,103-line ContentView; Xcode groups include docs and synchronized UI assets with explicit target exceptions. R1 package is excluded but AGENTS.md is a resource.

**First-round scope and constraints:** No behavior change, parser consolidation, framework split, mass move with refactor, evidence relocation, migration, or speculative target tree. No moves now; no bundle membership edit, parser reshape, or code architecture decision.

**First-round question/options:** What organization consolidation is safe after shell decomposition? Feature-oriented tree; layer-oriented tree; phased leaf moves. Only a phased plan may be evaluated after ownership map.

**First-round remainder and implications:** MISSING: authoritative target layout, path-consumer inventory, Xcode membership map and Git-history move plan. None.

**First-round proposed acceptance/falsifier:** Pre/post path map, Xcode group/target/build-resource audit, no path-sensitive script breakage, source/test parity and built-product containment in future writer window. A move changes target membership or public/resource path assumption.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: root contains mixed layer/feature directories and a 4,103-line ContentView; Xcode groups include docs and synchronized UI assets with explicit target exceptions. R1 package is excluded but AGENTS.md is a resource. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Shell ownership clarity and target/path-consumer map. Owning authority: FW-P2-77 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-67`: The App Shell and Workflow Decomposition boundary must provide: Five-phase shell extraction blueprint in packet.. This enables No moves before source boundary map. Remaining condition: Shell ownership clarity and target/path-consumer map.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1809-1836 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-77
- [LedgerForge.xcodeproj/project.pbxproj](<../LedgerForge.xcodeproj/project.pbxproj>):365-390;784-803;966-990 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `08dbe3df432f0dd1a78fe123eca04cb7d806a2809f599b30034c95eab7212d34` — synchronized UI Assets/resources
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2299-2334 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Source Tree and Documentation Organization Consolidation as Ready for discovery and records this unresolved boundary: MISSING: authoritative target layout, path-consumer inventory, Xcode membership map and Git-history move plan.

</details>

---

<a id="fw-p2-78"></a>

## FW-P2-78 — LF-UI-2026-09-R1 Dashboard Implementation

**Status:** Ready for planning
**Depends on:** accepted R1 design authority and existing repository-backed Dashboard/account/card/salary summaries

Implement the bounded R1 Dashboard hierarchy using native-currency groups, bank balances distinct from card liabilities, readable full amounts, authoritative as-of/period context where available, and the accepted Salary/current-funding summary without formula changes.

Required exclusions:

- no hidden FX conversion;
- no invented net worth;
- no new analytics, trends or percentages;
- no repository hydration masquerading as Import Activity;
- no source-financial or persistence-semantic changes.

The layout must adapt responsively without losing currency or liability meaning.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Sprint-89 shared R1 pattern acceptance and aggregate oracle.

**Smallest proposed boundary:** Dashboard supports native values only.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: the prepared Sprint 90 contract requires native-currency position, bank/card distinction, full values and authoritative context; unsupported analytics stay omitted.

**First-round scope and constraints:** No FX, net worth, fake trend/percentage/chart, hydration-as-import, or formula change. No interactive charts, customization, reporting FX, or extra financial claims.

**First-round question/options:** What evidence is ready for R1 Dashboard implementation? Implement fixed hierarchy after Sprint 89; add analytics/customization; defer. First is planned.

**First-round remainder and implications:** MISSING: Sprint 89 shared patterns acceptance and future runtime/source-oracle proof for displayed aggregates. No migration.

**First-round proposed acceptance/falsifier:** Native-currency/card-bank/context/oracle checks plus runtime layout/accessibility evidence. Any summary needs unaccepted cross-currency or analytical mapping.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: the prepared Sprint 90 contract requires native-currency position, bank/card distinction, full values and authoritative context; unsupported analytics stay omitted. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Sprint-89 shared R1 pattern acceptance and aggregate oracle. Owning authority: FW-P2-78 pinned queue scope and the named dependency below.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P2-53`: The Contextual Date-Range and Filter Controls boundary must provide: Generation-pinned transient filters; native-currency totals.. This enables Dashboard supports native values only. Remaining condition: Sprint-89 shared R1 pattern acceptance and aggregate oracle.

**Pinned evidence references:**

- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):21;34-38 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — Sprint 90
- [Project documents/UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md](<UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md>):48-50 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `e22c6acfe8e63a124f5f032dd9fb7e09a7102a3f25137e4acbb7a119845c03ab` — DB-01 to DB-03
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2335-2358 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines LF-UI-2026-09-R1 Dashboard Implementation as Ready for planning and records this unresolved boundary: MISSING: Sprint 89 shared patterns acceptance and future runtime/source-oracle proof for displayed aggregates.

</details>

---

<a id="fw-p2-79"></a>

## FW-P2-79 — Supported Institution / Source Coverage Documentation

**Status:** Ready for planning
**Depends on:** current accepted source/profile registry and ADR-046 current certification boundary

Maintain a user-readable and engineering-readable support matrix that distinguishes institution, financial family, source format, profile/parser identity/version where appropriate, credential requirement, active authentic-corpus certification status, known exclusions, historical implementation acceptance, current ADR-046 reliability certification and source-uncertified cases.

Support must never be inferred from institution name, fixture presence, filename, format or structural similarity. The matrix is a required input to `FW-P0-26` personal-v1 certification but does not itself certify personal-v1.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Needs exclusive documentation writer window and accepted registry review.

**Smallest proposed boundary:** Matrix distinguishes profile/credential/certification/exclusion; no private details.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: state names exact profiles/encrypted limits/exclusions; ADR-046 separates historical acceptance from current certification; roadmap makes matrix v1 input only.

**First-round scope and constraints:** VERIFIED_REPOSITORY: document institution/family/format/profile/credential/certification/exclusions/uncertified cases; publish no private details. No support expansion, v1 declaration, recertification, private corpus inventory or code.

**First-round question/options:** What support documentation can be prepared without overclaim? PROPOSED: one matrix plus engineering profile appendix; wait only for writer window.

**First-round remainder and implications:** MISSING: user/engineering matrix presentation design and exclusive documentation window; no new support evidence needed. No migration/ADR; documentation transcribes accepted boundaries.

**First-round proposed acceptance/falsifier:** Accuracy/privacy/certification-label review and no generic coverage inference. Generic implication, private disclosure or historical=current certification is invalid.

**Second-round new evidence/resolved direction:** No new support evidence is needed for documentation.

**Exact next evidence or decision:** Current exact profile/exclusion/certification matrix review.

**Personal-v1:** PRE_V1_REQUIRED: matrix is an adoption input, not certification.

**Recommendation after Chat:** Ready for documentation planning **Roadmap:** Do not activate as sprint

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Generic support claim/private disclosure.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, PRIVACY.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `documentation-writer-window`: Read-only campaign cannot edit product docs.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1859-1870 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P2-79
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):946-972 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `7843854eee6c85888f41af52c52aba70f2d0138c5f6f21e518211c75aca62797` — Current source/profile limits
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):120-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — P2 queue
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):964-972 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Exact support and exclusions.

</details>

---

<a id="fw-p3-01"></a>

## FW-P3-01 — Identifier Confidence Scoring

**Status:** Research
**Depends on:** Approved non-authoritative evidence policy

Confidence must never silently promote weak evidence into verified identity.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No user purpose/calibration authority for a non-authoritative score.

**Smallest proposed boundary:** Evidence labels only.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: FinancialIdentifier uses explicit kind, strong/weak strength, verified/unverified state and provenance, not a probabilistic confidence score.

**First-round scope and constraints:** Confidence cannot silently promote weak evidence. No auto-link/enrichment.

**First-round question/options:** Score identifier confidence without creating identity authority. Retain explicit evidence labels; or add a presentation-only score after independently verifiable calibration. A percentage without an accepted meaning invites false precision.

**First-round remainder and implications:** Chat must identify a real user decision that needs a score and approve its strictly non-authoritative meaning, evidence inputs and explainable calibration. No source-derived calibration corpus is established. A new score/evidence-meaning decision would require explicit ADR review; no persistence change is justified merely to expose current labels.

**First-round proposed acceptance/falsifier:** If later adopted, hold identifiers/provenance constant while varying score and prove matching, verification and durable ownership remain unchanged. Reject unsupported numeric certainty and show missing evidence explicitly. Any score threshold used to promote weak identifiers or trigger linking invalidates this presentation-only proposal.

**Second-round new evidence/resolved direction:** Opaque account facts cannot calibrate confidence.

**Exact next evidence or decision:** Named decision and calibration policy.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve queue priority/status; explicitly defer until a real selected source or product workflow demonstrates need. See bounded decision queue. **Roadmap:** Defer

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** concrete user workflow.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** IDENTITY, NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `user-score-purpose`: Future reopening condition only; this deferred boundary is not a current prerequisite. Unselected future scope only; no current user decision is pending for the deferred boundary.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1872-1877 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-01
- [Services/IdentityResolver.swift](<../Services/IdentityResolver.swift>):6-115 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ca46f8c7f1a3405c68388f5d306985db036bbf70f7cf7713e104dfd5c7ebbe37` — FinancialIdentifier kind/strength/verification/provenance and redaction
- [Project documents/ADR.md](<ADR.md>):3476-3484 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — identity requires durable provenance

</details>

---

<a id="fw-p3-02"></a>

## FW-P3-02 — Identifier Aliases and Alternate Institution Identifiers

**Status:** Research
**Depends on:** Identifier ownership and conflict semantics

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No source-proven alternate identifier pair and no correction lifecycle.

**Smallest proposed boundary:** Observation-to-ownership review contract only.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: FinancialIdentifier separately records normalized identity, strength, verification and provenance. Existing exact import observation contracts do not establish a general alias-correction lifecycle.

**First-round scope and constraints:** Conflict semantics retain sole ownership; aliases cannot weaken verification. No fuzzy aliases.

**First-round question/options:** Support identifier aliases/alternates. Preserve alternate source observations without changing ownership; or introduce an explicitly confirmed alias relation after a source-proven case. Name similarity is insufficient.

**First-round remainder and implications:** Selected authentic alternate-identifier case; accepted proof that both IDs belong to one container; conflict, supersession and reversal policy under FW-P0-11..15. Likely new relation but unknown.

**First-round proposed acceptance/falsifier:** Independently prove both identifiers belong to the same account and preserve their source observations. Conflicting existing ownership, weak-only proof or stale confirmation must reject with zero accepted changes; correction must preserve former evidence. Reused account numbers, card replacement versus account identity, or alias reassignment changes the family and invalidates inferred equivalence.

**Second-round new evidence/resolved direction:** No alternate identity relation found.

**Exact next evidence or decision:** One authentic alternate-ID case and conflict/inverse policy.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Research **Roadmap:** Defer

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** source-proven alias.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** IDENTITY, SOURCE_TRUTH, REVERSIBILITY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-11`: Chat owns this financial/privacy/architecture decision; it is not a technical questionnaire for the user.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p3-02`: An authentic alternate-identifier source case and existing ownership snapshot with independently established account identity and conflict evidence.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1881-1884 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-02
- [Services/IdentityResolver.swift](<../Services/IdentityResolver.swift>):6-115 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ca46f8c7f1a3405c68388f5d306985db036bbf70f7cf7713e104dfd5c7ebbe37` — FinancialIdentifier kind/strength/verification/provenance and redaction
- [Project documents/ADR.md](<ADR.md>):3478-3482 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — parser-owned identity/provenance retained

</details>

---

<a id="fw-p3-03"></a>

## FW-P3-03 — User-Visible Identity History

**Status:** Idea
**Depends on:** Durable identity provenance

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Durable identity history model absent.

**Smallest proposed boundary:** No UI.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: accepted-import observations exist, not a general durable identity-change history.

**First-round scope and constraints:** Display must preserve privacy and distinguish observation from ownership/change. No raw identifiers/change inference.

**First-round question/options:** Show identity history. PROPOSED defer; do not mislabel current observations as history.

**First-round remainder and implications:** Durable identity provenance model. Unknown.

**First-round proposed acceptance/falsifier:** Timeline distinguishes observed/imported/changed and redacts safely. History requires invented past events.

**Second-round new evidence/resolved direction:** None.

**Exact next evidence or decision:** Approved identity correction model.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Idea **Roadmap:** Defer

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** history model.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** IDENTITY, PROVENANCE, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-11`: identity lifecycle
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1888-1891 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-03
- [Services/IdentityResolver.swift](<../Services/IdentityResolver.swift>):6-115 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ca46f8c7f1a3405c68388f5d306985db036bbf70f7cf7713e104dfd5c7ebbe37` — FinancialIdentifier kind/strength/verification/provenance and redaction
- [Project documents/PROJECT_STATE.md](<PROJECT_STATE.md>):1016-1024 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — identity correction remains separate

</details>

---

<a id="fw-p3-04"></a>

## FW-P3-04 — Administrative Identifier Correction

**Status:** Research
**Depends on:** Reversible identity mutations and audit history

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** No selected correction family/audit/inverse policy.

**Smallest proposed boundary:** Read-only impact preview.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: conflicting ownership rejects confirmed import; no correction transaction.

**First-round scope and constraints:** Requires reversible identity mutation and audit history, under ADR-037. No direct DB edits/admin override.

**First-round question/options:** Correct identifier ownership administratively. PROPOSED route to P0-11/12, not separate admin bypass.

**First-round remainder and implications:** Selected correction family, audit/privacy and inverse policy. Family-specific.

**First-round proposed acceptance/falsifier:** Cross-owner correction revalidates and preserves observations/provenance; stale plan rejects. Cannot retain truthful former ownership evidence.

**Second-round new evidence/resolved direction:** None.

**Exact next evidence or decision:** Approved P0 identity family.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Research **Roadmap:** Defer

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** inverse rule.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** IDENTITY, MUTATION_SEMANTICS, REVERSIBILITY, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-11`: Chat owns this financial/privacy/architecture decision; it is not a technical questionnaire for the user.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p3-04`: A genuine selected account/identifier reassignment incident, original source ownership and accepted durable relations with an independent before/after impact projection.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1895-1898 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-04
- [Project documents/ADR.md](<ADR.md>):3451-3462 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — reassignment unapproved

</details>

---

<a id="fw-p3-05"></a>

## FW-P3-05 — Identity Provenance Timeline

**Status:** Idea
**Depends on:** Durable identity history

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Durable identity history and redacted presentation rules absent.

**Smallest proposed boundary:** No model/UI.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: bounded accepted-import observations exist; no general identity history contract.

**First-round scope and constraints:** No invented historical relationships or raw sensitive values. No inferred timeline.

**First-round question/options:** Show an identity provenance timeline. PROPOSED defer with P3-03.

**First-round remainder and implications:** Durable identity history and presentation/redaction decisions. Unknown.

**First-round proposed acceptance/falsifier:** Shows only retained/provable events and preserves privacy. Requested event has no durable provenance.

**Second-round new evidence/resolved direction:** None.

**Exact next evidence or decision:** Approved history/audit model.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Idea **Roadmap:** Defer

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** privacy retention decision.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** IDENTITY, PROVENANCE, PRIVACY, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P3-03`: durable history first
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Revalidate this card only against the accepted post-87 provider/migration/hydration/actor delta.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-05`: Durable identity history and redacted presentation rules absent.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1902-1905 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-05
- [Services/IdentityResolver.swift](<../Services/IdentityResolver.swift>):6-115 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ca46f8c7f1a3405c68388f5d306985db036bbf70f7cf7713e104dfd5c7ebbe37` — FinancialIdentifier kind/strength/verification/provenance and redaction
- [Project documents/LedgerForge_Standing_Execution_Harness_Guide.md](<LedgerForge_Standing_Execution_Harness_Guide.md>):203-208 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — private originals remain isolated

</details>

---

<a id="fw-p3-06"></a>

## FW-P3-06 — Financial Intelligence Engine

**Status:** Research
**Depends on:** Reliable financial truth, provenance, rules and explanation foundations

Define the architecture for deterministic, auditable financial conclusions that operate above imported source data.

The engine may coordinate:

- account and transaction relationships;
- recurring activity;
- transfers;
- salary;
- obligations;
- investments;
- multi-currency reporting;
- anomaly and change detection;
- planning and forecasting.

Every conclusion must identify its supporting evidence, deterministic rules and limitations.

The engine must not become a black-box source of financial truth.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** No deterministic conclusion family with sufficient truth/provenance is selected.

**Smallest proposed boundary:** One derived conclusion, never black-box authority.

**Decision record:** [ROADMAP_REPLANNING_PACKET_97](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-97>).

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P3-06 | **User product choice:** one deterministic conclusion family worth surfacing. | Financial intelligence needs fact/provenance boundary, not black-box authority. | Defer. | One evidence-labeled derived conclusion. | — | A until a concrete conclusion helps a current workflow. | No intelligence layer. | Bounded derived projection packet. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No engine exists; financial data remains source/provenance governed.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Financial Intelligence Engine: establish the smallest truthful product boundary. PROPOSED: One evidence-labelled derived conclusion, not black-box authority. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Which deterministic conclusion family has sufficient truth/provenance. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** No financial-intelligence authority exists.

**Exact next evidence or decision:** One evidence-labelled conclusion contract.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Research **Roadmap:** Do not combine with 97 without provenance

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Assumption presented as fact.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** PROVENANCE, DEPENDENCY, USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-21`: Explainability.
- `REQUIRES_USER_DECISION` → `decision-product-fw-p3-06`: No deterministic conclusion family with sufficient truth/provenance is selected.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-06
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2532-2575 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Typed source/assumption distinction required.

</details>

---

<a id="fw-p3-07"></a>

## FW-P3-07 — Financial Replay, Timeline and Money-Journey Reconstruction

**Status:** Blocked
**Depends on:** Reliable transaction identity, transfer matching, provenance and financial-intelligence foundations

Reconstruct how money moved through the user’s financial entities over time.

Candidate outcomes include:

- a Financial Timeline;
- replay of income, transfers, spending and investment funding;
- explanation of what changed net worth;
- chains showing movement between owned accounts;
- links back to supporting transactions, statements and import sessions;
- deterministic handling of corrected or reversed history.

Internal transfers must never be presented as new income or expense.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Transfer/reconciliation and correction/reversal provenance remain unaccepted.

**Smallest proposed boundary:** Evidence-backed timeline only.

**Decision record:** [ROADMAP_REPLANNING_PACKET_97](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-97>).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No transfer relationship/replay graph is persisted.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Financial Replay, Timeline and Money-Journey Reconstruction: establish the smallest truthful product boundary. PROPOSED: Evidence-backed timeline that keeps transfers out of income/expense. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Transfer/reconciliation and correction/reversal provenance. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Timeline cannot classify transfers as income/expense.

**Exact next evidence or decision:** Accepted transfer/reconciliation semantics.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Separate later outcome

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Weak relationship/mutation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, IDENTITY, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-10`: Transfer relation.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-11`: Reconciliation.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-07
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):58-72 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Relationship semantics first.

</details>

---

<a id="fw-p3-08"></a>

## FW-P3-08 — Broader Salary and Planning Expansion
**Status:** Blocked
**Depends on:** the specific transaction/reconciliation, recurring-obligation, analytics, investment or FX foundations required by the selected broader planning outcome; a future explicit ADR-045 alignment or successor architecture before external remittance-reference evidence can affect Salary calculations

**Completed boundary:** Sprint 79 and the later accepted startup/monthly-planner package completed exact Qatar Airways salary actuals, Salary History/This Month, coherent natural-input editing, Save/Command-S, contextual provenance, compact layout and configured-fee validation. Those slices are not future work.

**Remaining boundary:** Broader cross-employer planning integration, historical planner analytics/variance explanation and other planning outcomes that genuinely extend the accepted current-month workspace. Generic employer source support stays under `FW-P1-05`; recurring obligations under `FW-P3-09`; transfer/reconciliation under `FW-P2-10`/`FW-P2-11`/`FW-P3-19`; investments and general reporting FX remain in their dedicated candidates.

**Latest user scope — 2026-09-10 (UD-09/10):** Al Dar QAR→INR has the sole purpose of estimating the month-end INR receive amount in the monthly Salary/budget calculator from a current/live amount-bound quote. The user may explicitly override the rate with a manually entered current planning rate. No historical QAR→INR or general reporting Al Dar outcome is required. Current market INR→USD/QAR→USD net-worth estimation is separately owned by `FW-P3-31`/`FW-P3-33`. This supersedes the earlier broad Al Dar reporting/history interpretation while preserving accepted ADR-045 calculations, fee separation and explicit manual provenance.

The selected future planner method is:

```text
provisional QAR requirement
→ fetch an amount-specific forward Al Dar QAR→INR quote for that QAR send amount
→ recalculate the planner QAR requirement using the fetched rate
```

This remains a planning approximation/reference, not a guaranteed executable settlement or exact receive amount. Do not silently iterate toward an invented convergence rule, infer Al Dar's proprietary tier schedule, or treat a 1-QAR/table quote as universal. A materially changed funding amount may invalidate the usefulness of an earlier amount-bound quote even when it is recent. The existing ADR-045 upward rounding of the final derived QAR principal to the next QAR minor unit remains the underfunding guard.

Current production remains the explicit dated **user-entered** planning FX contract. A future external quote must retain distinct provider/source/amount/direction/fetch provenance and must never be mislabeled `user_entered`. Manual user-entered FX remains a supported fallback/override. External Al Dar use requires a future explicit ADR-045 alignment or successor architecture before it can affect Salary calculations.

The transfer fee remains a separate editable user/planning input. Public calculator discovery did not establish a universal applicable fee, so LedgerForge must not auto-fetch or auto-change the configured fee without separate evidence. The current accepted configurable-fee behavior remains unchanged.

Historical Budget Analysis percentage haircuts against generic market/reference FX were spreadsheet-specific workarounds for provider spread/commission uncertainty. They are explicitly retired as LedgerForge architecture: do not persist a fixed haircut, create a generic spread multiplier or silently reduce a fetched reference rate.

Further Salary visual polish remains lower priority and must not reopen accepted editor or persistence behavior.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_EXTERNAL_PROVIDER_OR_PERMISSION`. **Exact remaining gate:** Al Dar current forward-quote automation/cache/age/amount-binding permission and future ADR-045 alignment; manual override is explicitly required. No historical QAR→INR evidence is needed.

**Smallest proposed boundary:** Current monthly Salary/budget INR receive estimate for the chosen QAR send amount, using an Al Dar quote or explicitly user-entered FX override, with separate fee/provenance.

**Decision record:** [AL_DAR_PLANNER_REFERENCE_PACKET](#packet-al-dar-planner-reference-packet).

**Settled user direction:** UD-09, UD-10; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: Exact Qatar Airways actuals/current-month planner are accepted; external remittance quote is prospective only.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Broader Salary and Planning Expansion: establish the smallest truthful product boundary. PROPOSED: Keep Salary-remittance planning separate from general FX/investment/reporting. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Selected broader planning outcome and ADR-045 alignment before external reference affects Salary. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Supersession:** any earlier route, broad Al Dar use, combined historical scope or 2021 requirement in this dated first-round evidence is historical only. UD-08/09/10 and the current boundary above govern.

**Second-round new evidence/resolved direction:** UD-09: current/live Salary/budget month-end INR receive estimate from Al Dar with explicit manual rate override. UD-10 confirms current net-worth market estimates only. Historical FX is not required.

**Exact next evidence or decision:** Al Dar current forward-quote automation/cache/age/amount-binding permission and future ADR-045 alignment; manual override is explicitly required. No historical QAR→INR evidence is needed.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Blocked until the exact evidence/architecture gates are accepted; discovery closure is BLOCKED_ON_EXTERNAL_PROVIDER_OR_PERMISSION. **Roadmap:** Retain numbering. Current market net-worth estimation is the Sprint99 proposal; Al Dar is current Salary/budget only with manual override. Historical FX is deferred under UD-10.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, EXTERNAL_DATA_SEMANTICS, PROVIDER_PERMISSION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_PROVIDER_PERMISSION` → `provider-aldar-permission`: Current-scope gate under UD-09/10: provider-aldar-permission must satisfy its separately stated identity/source/architecture/implementation boundary. No historical FX dependency.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-aldar-planner-adr`: Current-scope gate under UD-09/10: decision-aldar-planner-adr must satisfy its separately stated identity/source/architecture/implementation boundary. No historical FX dependency.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-08
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-08
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap

</details>

<a id="packet-al-dar-planner-reference-packet"></a>

<details>
<summary>AL_DAR_PLANNER_REFERENCE_PACKET — complete proposed decision packet</summary>

## AL_DAR_PLANNER_REFERENCE_PACKET

| # | Required field | Proposed decision |
| --- | --- | --- |
| 1 | Owning FW IDs | FW-P3-08 only for the selected current/live monthly Salary/budget receive estimate. FW-P3-31/32/33 market reporting is separate. |
| 2 | User problem | Estimate INR received at month end from the monthly Salary/budget calculator using a current Al Dar forward quote or the user’s explicit manual current-rate override; this is an estimate based on a stated rate, not a forecast or settlement guarantee. |
| 3 | Verified current state | Accepted Salary planner uses explicitly dated user-entered FX and a separate configured fee. Prospective forward quote/recalculate method is a prior user direction. Public GetRate works without observed authentication; no app integration exists. |
| 4 | Accepted authorities | Accepted ADR-045 manual planning FX, fee separation and upward QAR funding guard remain unchanged. UD-09 explicitly limits Al Dar to current monthly Salary/budget INR receive estimates and permits manual override; no historical QAR→INR requirement. |
| 5 | Exact missing decision | Chat must approve external quote provenance, amount binding/requote policy, user consent, freshness and failure behavior. Provider must clarify automated current-quote calls, bounded cache, limits, attribution and quote age/expiry; no historical access is required. Published terms describe rates as indicative. |
| 6 | Evidence acquired | Home page JavaScript issues POST Home/GetRate with currency INR, amount equal to QAR send input, isFCY=false. Two bounded public amounts returned proportional numeric values in the sampled band. Response has no timestamp/expiry/fee/executable ID. Existing earlier evidence showed amount sensitivity and unsafe reverse reciprocity; a same-band pair does not overturn that evidence. |
| 7 | Options considered | Amount-specific forward reference quote followed by one recalculation; reverse target quote; universal table rate; autonomous iterative solver; retain manual only. |
| 8 | Recommended option | Explicitly request a current forward Al Dar quote for the calculator’s chosen/provisional QAR send amount and show the estimated INR receive amount with quote time and amount. Allow the user to enter a separately labeled manual FX override. Preserve the existing future one-recalculation funding method where the planner derives a QAR requirement; do not predict a future month-end rate. |
| 9 | Why competing options are rejected | Reverse quote lacks sufficient-funding proof; table or 1-QAR quote is not universal; iteration invents a convergence and provider-tier contract; hidden replacement of manual provenance is false history. |
| 10 | Smallest coherent implementation boundary | One user-triggered current monthly INR receive estimate with current Al Dar reference or explicit dated manual FX override. Any effect on accepted Salary calculations still requires Chat ADR-045 alignment. |
| 11 | Included scope | Selected QAR send amount, current indicative INR quote/estimate, fetch time, amount binding, explicit manual override and its rate/date, separate fee, stale/unavailable state and assumption label for the month-end estimate. |
| 12 | Explicit exclusions | Historical QAR→INR; general reporting/investment conversion; future-rate prediction; transfer execution; guaranteed settlement; reverse/reciprocal rate; universal tier; auto fee/haircut; unapproved iteration or Salary formula change. |
| 13 | Durable model/persistence requirements | Immutable quote observation with sent QAR Money, quoted INR exact Decimal and provider display precision if known, effective ratio as a derived Decimal, isFCY=false, response digest, fetchedAt, source-time absent marker, adapter/version and indicative purpose. Fee remains separately user-entered. Cached observations are retained only within a clarified permission contract. |
| 14 | Migration impact | REQUIRES_DECISION; likely additive quote/provenance storage, but no migration allocated and no forced reuse of historical market-rate rows. |
| 15 | ADR impact | NEW_ADR_REQUIRED or explicit accepted ADR-045 alignment/successor for Salary external-reference behavior; general directed source ownership belongs to the FX candidate. |
| 16 | Privacy/security boundary | No beneficiary/account/credential sent. A user-selected amount goes to the provider for the requested quote; future UI must expose that external request. No personal amount or raw private response in diagnostics/research publication. |
| 17 | SQLite/In-Memory implications | Quote storage/selection and manual override are equivalent across providers where persisted. Provider failure leaves manual state and last-success quote unchanged with truthful availability. |
| 18 | Hydration/relaunch implications | Reopen retains manual/external distinction, original quoted amount, fee input and recorded derivation. Same-generation publication and cancellation must be checked against post-87 owners. |
| 19 | Independent acceptance oracle | Observed public JavaScript and bounded POST responses establish orientation and field limits only. Future independent oracle uses allowed genuine quote samples and authentic completed-transfer evidence only for executed-rate claims; no inferred proprietary algorithm. |
| 20 | Failure cases | Endpoint/JSON shape change; unsupported currency; rate or amount invalid; timeout/429; no source time; stale quote; changed funding amount; changed fee; cache permission absent; reverse result mistaken for forward; stale in-flight response; executable-rate label on indicative data. |
| 21 | Reversal/correction semantics | Manual override or new quote creates explicit new provenance; earlier accepted manual plan is not silently rewritten. No transfer or selective ledger reversal is introduced. |
| 22 | Source evidence requirement | Official permission for automated personal amount-bound current reference quotes, cache/retention, update/expiry and attribution. Manual rate is explicitly user-entered evidence. Historical Al Dar evidence is not required or requested. |
| 23 | Runtime acceptance requirement | Future native explicit fetch/review/cancel/error/fallback, amount-change invalidation, fee preservation, rounding guard and durable relaunch. This campaign runs no planner. |
| 24 | Dependencies | Chat ADR-045 alignment; provider current-quote permission/freshness contract; exact post-87 lifecycle review. Historical FX is not a dependency. |
| 25 | Evidence that falsifies the recommendation | Provider denies automation/cache or needs unavailable authentication; no safe amount-binding policy; reverse quote used as authority; or a quote materially underfunds under the accepted planner calculation and review contract. |
| 26 | Personal-v1 relevance | PRE_V1_OPTIONAL; existing accepted manual planner remains the production boundary. |
| 27 | Recommended FUTURE_WORK status after Chat review | FW-P3-08 BLOCKED_ON_EXTERNAL_PROVIDER_OR_PERMISSION for the current Al Dar action; explicit manual override requirement is settled. Broader unselected Salary expansion remains deferred. |
| 28 | Recommended roadmap effect after Chat review | Keep this current Salary/budget reference candidate separate from Sprint 99 market reporting. Remove all historical Al Dar evidence requirements and retain numbering. |

</details>

---

<a id="fw-p3-09"></a>

## FW-P3-09 — Upcoming Obligations and Cash-Flow Planning

**Status:** Blocked
**Depends on:** Recurring-transaction detection, reliable categories, account balances and planning semantics

Present upcoming financial obligations such as:

- bills;
- subscriptions;
- expected credit-card payments;
- loan payments;
- recurring transfers;
- planned investments;
- other known commitments.

Cash-flow planning must distinguish confirmed obligations, deterministic projections and user-entered assumptions.

No prediction may be presented as a guaranteed future transaction.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Current planning needs a distinct fact/assumption/projection contract and recurrence foundation.

**Smallest proposed boundary:** Current-period native-currency obligation projection over explicit assumptions only.

**WB1 — reused private workflow observation, 2026-09-10:** workbook earnings/deductions and projected month-end balances mix entered assumptions with formulas; an expense-labelled range includes remittance. That label is not spending truth. The historical rate haircuts remain retired. The workbook is not an independent financial oracle.

**Decision record:** [RECURRING_ACTIVITY_EVIDENCE_PACKET](#packet-recurring-activity-evidence-packet), [ROADMAP_REPLANNING_PACKET_97](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-97>).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: no durable obligation/recurrence model was found in the inspected queue/code boundary. VERIFIED_LOCAL, parent-reported only: the historical workbook combines entered balances/obligations, a fixed fee formula, entered INR commitments and an entered conversion rate; its former percentage rate haircuts are explicitly retired as LedgerForge architecture.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Upcoming Obligations and Cash-Flow Planning: establish the smallest truthful product boundary. PROPOSED: model three independent rows/classes: source-confirmed obligation with retained provenance, user-entered assumption with author/time/version, and deterministic projection with formula/input snapshot. Do not import workbook structures as authority. A discovered recurrence is a suggestion until the user confirms it.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Recurrence/categories/balances/planning semantics and labels for confirmed/projection/assumption. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Independently test each class: source fact reproduces from its durable source relation; changing an assumption changes only the tagged assumption-derived result; changing a formula version recomputes a labelled projection; unsupported/missing recurrence produces no confirmed obligation. Native currencies remain segregated and financial rows are never changed. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Current-period planning can be separated from analytics/forecasting.

**Exact next evidence or decision:** Explicit assumptions, native-currency balances and approved recurrence state.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Ready after Chat decision **Roadmap:** Split Sprint 97 current planning from analytics

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Prediction/FX/automatic obligation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** ARCHITECTURE_DECISION, PROVENANCE, FINANCIAL_SEMANTICS.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-26`: Recurrence evidence.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-09`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Current planning needs a distinct fact/assumption/projection contract and recurrence foundation.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-09
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2532-2553 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Facts/assumptions/projections distinguish.

</details>

---

<a id="fw-p3-10"></a>

## FW-P3-10 — Spending Analytics

**Status:** Blocked
**Depends on:** Reliable duplicate handling and categorization

Includes:

- spending timelines;
- monthly and yearly trends;
- category breakdowns.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Reliable duplicate/transfer treatment and category semantics are missing.

**Smallest proposed boundary:** Facts-only native-currency analytics.

**Decision record:** [ROADMAP_REPLANNING_PACKET_97](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-97>).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: no accepted analytics projection is present; existing transaction UI filtering is presentation-only. VERIFIED_LOCAL, parent-reported only: historical workbook layouts mix planning/summary roles and cannot prove cashflow or performance history; numeric values and names were not published.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Spending Analytics: establish the smallest truthful product boundary. PROPOSED: a current-period native-currency aggregate may be independently derived from canonical trusted transactions with explicit inclusion/exclusion rules. It must remain separate from FW-P3-09 current-planning assumptions. Prepared Sprint 97 may combine only if both consume one shared, versioned derived-finance projection with separate source/assumption namespaces; otherwise split the planning outcome.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Duplicate sufficiency and category semantics. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** A fixture-independent authoritative snapshot projection is independently recomputed from the same transaction identities and yields per-currency totals; duplicate/rejected/transfer treatment is declared and testable; no planning assumption can alter an analytic fact. Sprint 97 combination gate: prove shared typed provenance, formula/versioning, currency segregation, and mutually exclusive fact-versus-assumption result labels; otherwise record scope split/replanning decision required before execution. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Analytics must not be influenced by planning assumptions.

**Exact next evidence or decision:** Canonical facts-only native-currency projection and declared membership.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Separate Sprint 97 analytics from planning

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Mixed currency/assumption/transfer treatment.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, PROVENANCE, FINANCIAL_SEMANTICS, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-21`: Category semantics.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P0-19`: Duplicate sufficiency.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-10`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Reliable duplicate/transfer treatment and category semantics are missing.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-10
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2562-2575 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Combination gate requires typed provenance.

</details>

---

<a id="fw-p3-11"></a>

## FW-P3-11 — Budgets

**Status:** Blocked
**Depends on:** Stable categorization and analytics

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Stable analytics/category scope and budgeting policy missing.

**Smallest proposed boundary:** User-entered envelopes separate from source truth.

**Decision record:** [ROADMAP_REPLANNING_PACKET_97](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-97>).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No budget model exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Budgets: establish the smallest truthful product boundary. PROPOSED: User-entered budget envelopes separate from source truth. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Stable analytics/category scope and user budgeting policy. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** No budget model exists.

**Exact next evidence or decision:** User envelope and category ownership decision.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Later than 97

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Budget changes financial facts.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P3-10`: Analytics.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-11`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Stable analytics/category scope and budgeting policy missing.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-11
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2580-2587 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No budget model.

</details>

---

<a id="fw-p3-12"></a>

## FW-P3-12 — Financial Goals

**Status:** Blocked
**Depends on:** Stable reporting model

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Goal kind/currency/date/progress authority/overlap policy unselected.

**Smallest proposed boundary:** Native-currency target; progress unavailable until source accepted.

**Decision record:** [ROADMAP_REPLANNING_PACKET_97](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-97>).

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P3-12 | **User product choice:** goal kind, target currency/date, and progress basis. | Goals may be target metadata, derived progress, or reserved funds with different overlap semantics. | User-authored target only; progress unavailable. | Progress from accepted eligible holdings. | Reserved-funds model. | A is smallest if goals are currently needed; otherwise defer. | No goal model. | Exact goal/progress architecture selected by B/C. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: current provider interfaces expose accounts/transactions and funding plans; they do not expose a general financial-goal repository or define how a goal reserves funds.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Financial Goals: establish the smallest truthful product boundary. User-entered target metadata is a smaller planning feature; automatic progress needs accepted reporting membership; actual earmarking adds durable allocation and possible double-counting semantics.

**First-round remainder and implications:** Owner-selected goal kind and target currency/date; whether progress is manually attested, derived from eligible holdings, or represents reserved funds; overlap and correction policy. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Changing a target or assumption cannot change canonical funds or create a transaction. Verify independently the selected progress membership and deny cross-currency totals, overlapping earmarks or unsupported forecasts. A goal promising fund reservation, mixed-currency progress or automatic contributions requires a stronger boundary and invalidates metadata-only scope.

**Second-round new evidence/resolved direction:** No general goal repository exists.

**Exact next evidence or decision:** One owner-authored goal contract.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Defer

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** Reservation or cross-currency inference.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** PROVENANCE, DURABLE_PERSISTENCE, USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_USER_DECISION` → `decision-goal-contract`: Goal ownership.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-12`: Goal kind/currency/date/progress authority/overlap policy unselected.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-12
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2592-2599 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Goal semantics unresolved.

</details>

---

<a id="fw-p3-13"></a>

## FW-P3-13 — Forecasting

**Status:** Research
**Depends on:** Reliable historical data and approved explainability standards

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** No historical suitability or scenario/prediction label decision.

**Smallest proposed boundary:** Deterministic scenario, never predicted fact.

**Decision record:** [ROADMAP_REPLANNING_PACKET_97](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-97>).

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P3-13 | **User product choice:** whether deterministic scenarios are useful after history is reliable. | Forecast-like output must never be labeled as fact. | Defer forecasting. | Deterministic scenario with assumptions/limitations. | — | A; no selected decision workflow. | No forecast/scenario. | B after analytics/history authority. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No forecast is accepted.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Forecasting: establish the smallest truthful product boundary. PROPOSED: Deterministic scenario, never predicted fact. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Historical suitability and explainability/prediction labels. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** No forecast is accepted.

**Exact next evidence or decision:** Selected deterministic scenario policy.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Research **Roadmap:** Exclude from 97

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Prediction labelled as fact.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** PROVENANCE, NO_REAL_USE_CASE, USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P3-10`: Reliable history.
- `REQUIRES_USER_DECISION` → `decision-product-fw-p3-13`: No historical suitability or scenario/prediction label decision.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-13`: No historical suitability or scenario/prediction label decision.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-13
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2604-2611 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No forecast accepted.

</details>

---

<a id="fw-p3-14"></a>

## FW-P3-14 — Smart Alerts

**Status:** Blocked
**Depends on:** Reliable categories, rules or forecasting inputs

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** No trusted alert source or notification policy.

**Smallest proposed boundary:** Explainable eligibility notice only.

**Decision record:** [RECURRING_ACTIVITY_EVIDENCE_PACKET](#packet-recurring-activity-evidence-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No reliable input/notification contract exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Smart Alerts: establish the smallest truthful product boundary. PROPOSED: Explainable eligibility notice. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Rule/category/forecast source and alert policy. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Eligibility explanation precedes notification.

**Exact next evidence or decision:** Selected source and notification ownership.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Defer

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Untrusted notification trigger.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-28`: Alert source.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-14`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. No trusted alert source or notification policy.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-14
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2616-2623 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No input contract.

</details>

---

<a id="fw-p3-15"></a>

## FW-P3-15 — Custom Reports

**Status:** Blocked
**Depends on:** Stable analytics

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Metrics, privacy/export and currency presentation require stable analytics.

**Smallest proposed boundary:** Read-only report projection.

**Decision record:** [ROADMAP_REPLANNING_PACKET_97](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-97>).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No stable analytics/report schema exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Custom Reports: establish the smallest truthful product boundary. PROPOSED: Read-only report projection. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Metric definition, privacy/export and currency presentation. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** No stable analytics/report schema.

**Exact next evidence or decision:** One report projection definition.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Defer

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Private export/mixed currency.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, PRIVACY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P3-10`: Analytics.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-15`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Metrics, privacy/export and currency presentation require stable analytics.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-15
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2628-2635 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Metrics unresolved.

</details>

---

<a id="fw-p3-16"></a>

## FW-P3-16 — Tax Views

**Status:** Research
**Depends on:** Jurisdiction and supported-data decisions

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** No jurisdiction, supported tax data, calculation or liability boundary.

**Smallest proposed boundary:** Evidence-labelled tax view/export only.

**Decision record:** [SOURCE_EXPANSION_PACKET](#packet-source-expansion-packet).

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P3-16 | **User product choice:** jurisdiction and desired tax-view outcome. | Tax calculation, sources, and liability wording are jurisdiction-specific. | Defer. | Evidence-labeled tax export/view only. | Calculation/advice is out of scope pending specialist authority. | A until jurisdiction/use case exists. | No tax feature. | Bounded view/export if B selected. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No jurisdiction/supported-tax-data contract exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Tax Views: establish the smallest truthful product boundary. PROPOSED: Evidence-labelled tax export/view only. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Jurisdiction, sources, calculations and liability disclaimers. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** No tax-data contract exists.

**Exact next evidence or decision:** Jurisdiction and evidence-labelled output decision.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Research **Roadmap:** Defer

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Tax calculation/liability claim.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=true. **Blocker types:** FINANCIAL_SEMANTICS, SOURCE_TRUTH, USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_USER_DECISION` → `decision-tax-jurisdiction`: Jurisdiction authority.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-16`: No jurisdiction, supported tax data, calculation or liability boundary.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-evidence-fw-p3-16`: Authentic owner tax-relevant source documents for the selected jurisdiction and reporting purpose, with independently established dates/amounts/classification; no invented tax history.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-16
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2640-2647 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No jurisdiction contract.

</details>

---

<a id="fw-p3-17"></a>

## FW-P3-17 — CSV and Report Export

**Status:** Candidate
**Depends on:** Export schema and privacy policy

Provide user-facing exports of reports and selected financial views. Full machine-readable domain export remains governed by `FW-P3-35`.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** User retained complete export optional and has not selected a report/use case.

**Smallest proposed boundary:** No selected-view report implied by backup.

**Decision record:** [EXPORT_BOUNDARY_PACKET](#packet-export-boundary-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: canonical repositories and hydration provide records/typed projections. The current selected-view export item has no accepted report schema/privacy policy; repository rows alone do not define the visible filter, ordering or displayed totals contract.

**First-round scope and constraints:** The app remains private, local and explicit. Accepted financial history, native Money, order, multiplicity and provenance cannot be silently rewritten. ADR-046 authentic-input rules apply to financial cases; migration identities remain append-only. Discovery grants no implementation or acceptance. No universal export framework, new analytics, hidden currency conversion, raw source copies/passwords/paths or automatic reimport promise.

**First-round question/options:** What does exporting a selected financial view promise? CSV is inspectable but needs explicit escaping/type policy; a formatted report preserves presentation but is not a complete domain archive.

**First-round remainder and implications:** Selected report/view; visible-page vs all matching rows; columns, date/currency formatting, redaction and spreadsheet-safe text policy. Likely no migration for derived export; ADR only if content retention or durable export history changes authority.

**First-round proposed acceptance/falsifier:** Independently compare membership, native Money and ordering against genuine canonical records; verify commas/newlines/Unicode and formula-like nonfinancial strings, cancellation/no partial final artifact, and empty results. Do not manufacture financial statement test graphs. Changed filters, paginated membership, new financial columns or provider rounding can invalidate the chosen schema.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: canonical repositories and hydration provide records/typed projections. The current selected-view export item has no accepted report schema/privacy policy; repository rows alone do not define the visible filter, ordering or displayed totals contract. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: User retained complete export optional and has not selected a report/use case. Owning authority: EXPORT_BOUNDARY_PACKET.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** DEFERRED_WITH_REASON **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `decision-report-export`: Future reopening condition only; this deferred boundary is not a current prerequisite. Unselected future scope only; no current user decision is pending for the deferred boundary.

**Pinned evidence references:**

- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Services/RepositoryStoreHydrator.swift](<../Services/RepositoryStoreHydrator.swift>):209-269;344-440 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `40cbd69a8a470748fcb637cb10ae5597855d5a03771e165d8f551162d2b94117` — RepositoryStoreHydrator.init(workspaceId:); stageHydration()
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2652-2661;3047-3056 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Report and structured export are distinct unresolved contracts.

</details>

---

<a id="fw-p3-18"></a>

## FW-P3-18 — Net-Worth History

**Status:** Blocked
**Depends on:** Multi-account, investment and multi-currency foundations

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Investment and FX valuation/aggregation semantics are incomplete.

**Smallest proposed boundary:** Native-value position history first.

**Decision record:** [ROADMAP_REPLANNING_PACKET_97](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-97>).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No consolidated history; holdings and FX foundations are incomplete.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Net-Worth History: establish the smallest truthful product boundary. PROPOSED: Native-value position history before net worth total. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Account/investment/currency valuation semantics. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** No consolidated history exists.

**Exact next evidence or decision:** Native position history before reporting-currency total.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** History remains gated

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Incomplete valuation/FX.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, FINANCIAL_SEMANTICS, EXTERNAL_DATA_SEMANTICS, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-current-holdings-first`: Holdings architecture.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-18`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Investment and FX valuation/aggregation semantics are incomplete.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-18
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2666-2673 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Holdings/FX incomplete.

</details>

---

<a id="fw-p3-19"></a>

## FW-P3-19 — Salary Actuals to Bank-Transaction Reconciliation

**Status:** Blocked
**Depends on:** accepted salary actuals (complete for exact Qatar Airways), reliable account identity and approved transaction/transfer reconciliation semantics under `FW-P2-10` and `FW-P2-11`

Use immutable imported salary actuals to help verify corresponding bank transactions without collapsing payroll evidence into bank-transaction truth.

The remaining blocker is matching/reconciliation semantics, not generic salary-slip support. Candidate outcomes include explainable likely salary-credit relationships, supported gross/net/deduction comparisons, mismatch explanation and explicit review for ambiguity.

A salary source must never silently create, modify or replace a bank transaction.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Transfer/reconciliation matching and ambiguity review not accepted.

**Smallest proposed boundary:** Explain likely relation; never create/replace bank transaction.

**Decision record:** [ROADMAP_REPLANNING_PACKET_97](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-97>).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: Salary actuals are immutable; no bank matching relation exists.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Salary Actuals to Bank-Transaction Reconciliation: establish the smallest truthful product boundary. PROPOSED: Explain likely relationships; never create/replace bank transaction. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Transfer/reconciliation matching semantics and ambiguity review. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** Salary actuals immutable; no bank matching relation.

**Exact next evidence or decision:** Reviewable likely relationship semantics.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Blocked **Roadmap:** Separate later outcome

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Salary source becomes bank truth.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY, IDENTITY, PROVENANCE, MUTATION_SEMANTICS, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-10`: Transfer matching.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P2-11`: Reconciliation.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-19`: This required source/financial/workflow boundary is Chat-owned; no user technical choice is requested. Transfer/reconciliation matching and ambiguity review not accepted.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-19
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2678-2691 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — No matching relation.

</details>

---

<a id="fw-p3-19a"></a>

## FW-P3-19A — Liabilities, Loans and Financial Health

**Status:** Research
**Depends on:** Liability domain models, reliable account balances, obligations and multi-currency reporting

Support durable representation and understandable presentation of:

- loans;
- credit obligations;
- repayment schedules;
- outstanding principal;
- interest and fees;
- liquidity;
- debt burden;
- emergency-fund coverage;
- other explainable financial-health indicators.

Financial-health conclusions must show the underlying deterministic calculation and must not be presented as regulated financial advice.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Liability ownership, schedule/rate/obligation and reporting-currency semantics unselected.

**Smallest proposed boundary:** Current liabilities/obligations first.

**Decision record:** [ROADMAP_REPLANNING_PACKET_97](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-97>).

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P3-19A | **User product choice:** whether current liabilities/obligations are a current product need. | Loans, schedules, rates, and reporting currency create a separate financial domain. | Defer. | Current obligations/liabilities only. | History/performance later. | A unless owner selects B. | No liability domain. | Bounded current holdings/obligations architecture. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: No loan/health model exists; card liability domain alone is insufficient.

**First-round scope and constraints:** EXPLICIT_USER_DECISION: preserve immutable imported financial truth, durable provenance, native-currency meaning, privacy, deterministic behavior, and fail-closed ambiguity; a roadmap forecast grants no execution authority. No repair, parser/source claim, build/test/runtime validation, database mutation, fabricated statement, unbounded sync, or hidden financial inference.

**First-round question/options:** Liabilities, Loans and Financial Health: establish the smallest truthful product boundary. PROPOSED: Current holdings/obligations first; history/performance remains gated. Defer broader automation, mutation, history, and external-data assumptions.

**First-round remainder and implications:** MISSING/EXPLICIT_USER_DECISION: Liability ownership, schedules, rates, obligations and reporting-currency semantics. No migration or ADR is approved by discovery; any durable relation/derived-state schema requires a selected family and explicit architecture decision.

**First-round proposed acceptance/falsifier:** Falsifiable future acceptance: prove deterministic result from authoritative durable records, label every assumption/limitation, preserve original source values, demonstrate SQLite/In-Memory parity when persistence changes, and reject ambiguity with zero unauthorized financial writes. Missing provenance, mixed-currency total, weak identity/recurrence evidence, changed source contract, or a result that cannot distinguish fact from derived suggestion invalidates this recommendation.

**Second-round new evidence/resolved direction:** User holds current-holdings-first; history/performance stays gated.

**Exact next evidence or decision:** One current-holdings/obligation contract.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Research **Roadmap:** Do not bundle with 97

**Publication delta:** `STILL_VALID` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The cited evidence or relevant source hunk remains valid; no source/provider research was rerun merely because Swift ownership changed.

**Revalidation/falsifiers:** Rate/history/currency inference.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, DURABLE_PERSISTENCE, USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-current-holdings-first`: Owner decision.
- `REQUIRES_USER_DECISION` → `decision-product-fw-p3-19a`: Liability ownership, schedule/rate/obligation and reporting-currency semantics unselected.

**Pinned evidence references:**

- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):1908-2110 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `80e40cc09e11ccb91e37089c21c4e28e75033d18046c5d8cc350f0ce5a78ad2c` — FW-P3-19A
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md>):19-123 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `69a793857804133ce22907f72458b7d72322fc8af56c0bdfac86debd9126a894` — prepared roadmap
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2696-2710 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Liability domain requirements.

</details>

---

<a id="fw-p3-20"></a>

## FW-P3-20 — Mutual-Fund Holdings

**Status:** Research
**Depends on:** accepted investment/holding identity and valuation provenance; source/user-owned position and cost evidence; authentic investment sources where ingestion support is selected

The user's current Indian mutual-fund domain is owned here, not by manual-valuation fallback merely because the historical workbook was manually maintained.

**User-settled plan identity boundary — 2026-09-09:** the selected Indian mutual-fund holdings are **Direct plans**. Recurring identity must use an explicitly qualified configuration such as exact AMFI scheme code + ISIN + plan/option metadata. Display-name similarity, approximate NAV and fuzzy recurring matching are not identity authority. A Regular plan must never substitute for a configured Direct plan.

Holding ownership, units, contributions/cost basis and correction history remain source/user-owned investment evidence. A fetched NAV never establishes those facts. External AMFI NAV retrieval/freshness belongs under `FW-P3-27`; manual/custom valuation fallback belongs under `FW-P3-28` only when required.

Ordinary valuation remains:

```text
holding units × native-currency NAV = derived native-currency market value
```

Any later reporting conversion is a separate provenance-bearing derived layer and never overwrites the native holding value or imported/source evidence.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Investment identity/position/revision ADR; exact adopted dated owner positions and AMFI scheme/ISIN/Direct-plan/option mapping. Provider NAV is not ownership.

**Smallest proposed boundary:** One native-INR Direct-plan current position with typed cost evidence and explicit date/provenance.

**WB2/WB3 — reused private workflow observations, 2026-09-10:** one holdings section has entered units and a total-cost-like field despite its average-price heading; another has fractional units and average unit cost from which total cost is derived. These are different cost-evidence types. A price lookup, formula gain or owner-entered quantity does not establish instrument identity, source-certified ownership, lots or performance. Hidden source sheets/custom functions and complete transaction history were not inspected.

**Decision record:** [INVESTMENT_HOLDINGS_ARCHITECTURE_PACKET](#packet-investment-holdings-architecture-packet), [ROADMAP_REPLANNING_PACKET_98](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-98>).

**Settled user direction:** UD-01; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_LOCAL: Budget Analysis / Savings / Investments B12:J26 uses fetched display/date/price formulas, entered units and a cost-like entered amount, and derives value from units times price; it supplies neither AMFI mapping nor transaction history.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. EXPLICIT_USER_DECISION 2026-09-10: propose current holdings first and keep history/performance gated. This is discovery direction, not architecture acceptance or sprint selection. Exclude Regular-plan substitution, fuzzy matching, inferred lots, performance and reporting FX.

**First-round question/options:** What is the smallest Indian mutual-fund holding boundary? Current-position evidence first needs fewer source events; reconstructing lots/performance first requires dated investment transactions and a cost method.

**First-round remainder and implications:** Exact approved AMFI scheme-code/ISIN/Direct-plan-option mapping for owned positions; effective date, total-cost vs average-price meaning, and correction policy. Investment identity and owned-position ADR required; likely additive persistence and hydration work after approval, no migration number allocated.

**First-round proposed acceptance/falsifier:** Verify exact configured code+ISIN+plan/option and independent unit total; mismatched or missing mapping is unavailable, never substituted. Future implementation must compare against independently reviewed genuine source/user position facts. Preserve source-observed Decimal units, price/NAV and rates at independently evidenced scale; reject malformed/out-of-contract precision only under an approved field contract. Apply explicitly versioned rounding only to final derived currency Money, then enforce its minor-unit scale. Prove SQLite/In-Memory parity where persisted, zero accepted residue on rejection, reopen/hydration and provenance. Absent authentic cases remain uncertified; do not manufacture statement graphs. A source showing distributions, unit-class distinctions, unsettled trades or a different cost interpretation invalidates a flat snapshot that hides them.

**Second-round new evidence/resolved direction:** UD-01 current holdings first and typed WB2–WB4 evidence remain binding; exact immutable source citations rechecked.

**Exact next evidence or decision:** Investment identity/position/revision ADR; exact adopted dated owner positions and AMFI scheme/ISIN/Direct-plan/option mapping. Provider NAV is not ownership.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Research until the exact evidence/architecture gates are accepted; discovery closure is READY_FOR_CHAT_ARCHITECTURE_DECISION. **Roadmap:** Retain numbering; use ROADMAP_REPLANNING_PACKET_98 slices A/B/C/D.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-23`: Investment identity/position/revision ADR; exact adopted dated owner positions and AMFI scheme/ISIN/Direct-plan/option mapping. Provider NAV is not ownership.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-current-mf-position`: Investment identity/position/revision ADR; exact adopted dated owner positions and AMFI scheme/ISIN/Direct-plan/option mapping. Provider NAV is not ownership.
- `OPTIONAL_ENHANCEMENT` → `FW-P3-27`: External refresh is optional for a genuinely evidenced manual position/valuation boundary.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

<a id="packet-investment-holdings-architecture-packet"></a>

<details>
<summary>INVESTMENT_HOLDINGS_ARCHITECTURE_PACKET — complete proposed decision packet</summary>

## INVESTMENT_HOLDINGS_ARCHITECTURE_PACKET

| # | Required field | Proposed decision |
| --- | --- | --- |
| 1 | Owning FW IDs | FW-P3-20, FW-P3-21, FW-P3-23, FW-P3-28, FW-P3-29; constrains FW-P3-22 and FW-P3-24 through FW-P3-27. |
| 2 | User problem | Represent current owned positions and explain their native valuation without inventing acquisition history or treating a fetched price as proof of ownership. |
| 3 | Verified current state | AccountType.investment and account base-currency fields exist. Inspected repository contracts have no holding/security/lot or reference-rate service. Money requires exact currency minor units; price, unit and FX precision are separate. WB2–WB4 describe owner workflows, not certified institution facts. |
| 4 | Accepted authorities | ADR-008/033 native Money and separately approved derived rounding; ADR-024 canonical hydration; ADR-037 exact reviewed mutation ownership; ADR-046 authentic-source policy. UD-01 current holdings first, history/performance gated; Direct plans only; retired ISP multiplier remains excluded. |
| 5 | Exact missing decision | Chat must accept container/instrument/position identity, provenance and revision ownership, effective-date policy, supported manual entry boundary and a separately versioned final derived-Money rounding rule. Exact adopted positions still need genuine dated owner/source evidence. |
| 6 | Evidence acquired | WB2: entered units with total cost-like amount despite average-price label. WB3: average unit cost, with derived total cost. WB4: mandatory and AVC units and contribution allocation, not lots. Four exact Zurich codes now have dated USD bid evidence. Neither prices nor workbook formulas prove ownership dates or cost basis. |
| 7 | Options considered | A current-position evidence model; a trade/lot-first ledger; direct workbook import; prices-only portfolio. |
| 8 | Recommended option | A current-position model with separate container, instrument, position observation, typed cost evidence, and optional price observation. A manually confirmed dated position is explicitly user-owned; source ingestion is a later qualified adapter. |
| 9 | Why competing options are rejected | Trade-first contradicts UD-01 and lacks events; workbook import would flatten different cost meanings and unestablished dates; prices-only invents ownership. Generic identifiers or fuzzy names cannot safely combine instruments. |
| 10 | Smallest coherent implementation boundary | One chosen container and qualified instrument family, current positive/zero explicitly evidenced units, provenance, effective and recorded dates, immutable revisions and an optional dated native valuation. Extend each family only after its own independent evidence gate. |
| 11 | Included scope | Container kind and opaque identity; scoped source identifiers; exact instrument configuration; unit classes; explicit known/unknown cost meaning; review of creation/correction; unavailable/stale valuation state; native-value display. Zero units must be stated, not substituted for missing units. |
| 12 | Explicit exclusions | Lots, trades, corporate actions, realized P/L, IRR/TWR, performance history, contribution-as-profit, forecast prices, vesting inference, old 0.75 factor, mixed-currency totals, fuzzy identifier merge, broker ingestion and autonomous refresh. |
| 13 | Durable model/persistence requirements | Separate immutable ContainerIdentity, InstrumentIdentity and PositionObservation records. Instrument key includes provider namespace, exact scheme/wrapper/listing, currency and plan/option where applicable. Position key includes container, instrument and unit class; effectiveAt and recordedAt are distinct. Store Decimal units at approved source scale. CostEvidence separates total_cost_like (exact native total Money where established), average_unit_cost (Decimal per-unit cost plus currency and its own evidenced precision), contribution_allocation (dimensionless percentage/ratio plus the stated allocation basis and any separately evidenced contribution Money), and unknown. A ratio is never coerced to Money, and an allocation is not acquisition cost. Preserve the evidence owner and explicit basis for each variant. Append corrections with supersedes/void reason and single active revision; do not rewrite imported facts. PriceObservation has native Decimal, civil price date, fetch time, source identity, adapter/version, digest and availability. Derived valuations reference both immutable inputs and rounding version. |
| 14 | Migration impact | LIKELY_ADDITIVE; no migration number. Do not activate unused exchange_rates capacity or overload transaction/account rows merely because columns exist. |
| 15 | ADR impact | NEW_ADR_REQUIRED for investment identity, position evidence, revision family and valuation derivation; align ADR-008/024/033/037/046. |
| 16 | Privacy/security boundary | Private container identifiers, owner units and costs stay private. Diagnostics use opaque IDs/counts only. No provider account access, credentials, originals or workbook rows in published artifacts. |
| 17 | SQLite/In-Memory implications | Both providers must preserve exact position, provenance, revision selection and unavailable states. Rejected identity, precision, cost-currency or stale-revision changes leave zero accepted residue. SQLite parity is future acceptance, not established here. |
| 18 | Hydration/relaunch implications | Canonical hydration reconstructs separate source/user facts and observations, then derives presentation. Close/reopen must select the same active revision and produce the same native result. Re-read provider/actor ownership after Sprint 87. |
| 19 | Independent acceptance oracle | Independently reviewed genuine dated owner/source position facts establish identity and units; do not use production parsing as its own oracle. WB2–WB4 only identify field meanings to confirm. Isolated nonfinancial identity/Decimal mechanics may use ordinary values. Genuine unit-class sums and provider price/date observations independently verify native valuation; no statement-shaped factories. |
| 20 | Failure cases | Same label/different plan; wrapper versus underlying ISIN; missing currency/date; overlapping snapshots; duplicate mandatory/AVC totals; unit-class omission; stale correction token; unknown cost treated as zero; contribution mistaken for acquisition cost; stale price; Decimal overflow/excess approved precision; interruption before atomic revision publication. |
| 21 | Reversal/correction semantics | Append a new explicit user correction or void, retaining prior evidence and review/audit reason. Exact operation, impact closure, stale-token rejection and reversible active-revision selection need a bounded ADR-037-aligned contract; this packet grants no general imported-record mutation. |
| 22 | Source evidence requirement | Exact dated container/position evidence and configuration for the selected family. AMFI scheme/ISIN/Direct-plan/option, broker listing, and ISP policy/mandatory/AVC classes are separately qualified. Unknown source cases remain uncertified. |
| 23 | Runtime acceptance requirement | Future native manual review/correction, failure/cancel, zero residue, provider parity, canonical hydration and same-database relaunch; external refresh only after provider permission. |
| 24 | Dependencies | Chat investment ADR; selected genuine position evidence; exact post-87 provider/lifecycle review. FW-P3-27 is optional for a manual dated valuation boundary, not a prerequisite for merely recording positions. Brokerage history and performance are not foundation dependencies. |
| 25 | Evidence that falsifies the recommendation | An adopted source requires simultaneous multiple snapshots, unsettled units, distributions, ownership restrictions or a materially different identity contract that this bounded family cannot preserve; any cost or units/date inference is a failure. |
| 26 | Personal-v1 relevance | PRE_V1_OPTIONAL unless Chat explicitly adopts a bounded holdings outcome. UD-01 orders investment scope, not all personal-v1 prerequisites. |
| 27 | Recommended FUTURE_WORK status after Chat review | READY_FOR_CHAT_ARCHITECTURE_DECISION for the foundation; no Ready for planning until architecture, exact chosen evidence and post-87 ownership gates are satisfied. Brokerage ingestion stays source-blocked. |
| 28 | Recommended roadmap effect after Chat review | Sprint 98 must be replanned into the coherent A/B/C/D slices in ROADMAP_REPLANNING_PACKET_98; retain numbering and no execution authority. |

</details>

---

<a id="fw-p3-21"></a>

## FW-P3-21 — ETF and Stock Holdings

**Status:** Research
**Depends on:** Investment domain model and approved non-source holdings test data and/or authentic brokerage sources where ingestion support is in scope

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Investment identity ADR and chosen genuine current broker/container/instrument/listing/currency evidence; no trades or performance scope is selected.

**Smallest proposed boundary:** Current equity/ETF units with qualified listing/native currency and explicit average-unit-cost or unknown evidence.

**Decision record:** [INVESTMENT_HOLDINGS_ARCHITECTURE_PACKET](#packet-investment-holdings-architecture-packet), [ROADMAP_REPLANNING_PACKET_98](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-98>).

**Settled user direction:** UD-01; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_LOCAL: Savings / Investments E27:J41 uses entered fractional positions and average price; G multiplies units by average price, while the earlier fund block uses F directly. Tickers are lookup hints, not a durable security identity contract.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. EXPLICIT_USER_DECISION 2026-09-10: propose current holdings first and keep history/performance gated. This is discovery direction, not architecture acceptance or sprint selection. Exclude trade execution, live broker access, invented tax lots and fabricated financial test graphs; existing queue wording about non-source test data does not override ADR-046.

**First-round question/options:** Can ETFs/stocks share the same first boundary as funds/ISP? Current holdings can share arithmetic mechanics; a universal financial importer must also handle unsettled trades, fees and corporate actions and is premature.

**First-round remainder and implications:** Selected exact broker/account/instrument identity, listing/currency, genuine ownership snapshot date and whether current units or trade history is required. New investment-domain ADR and additive schema likely; no change to accepted migrations.

**First-round proposed acceptance/falsifier:** Prove fractional units and matching security/listing/currency; reconcile current position to an independent genuine broker/owner snapshot. Future implementation must compare against independently reviewed genuine source/user position facts. Preserve source-observed Decimal units, price/NAV and rates at independently evidenced scale; reject malformed/out-of-contract precision only under an approved field contract. Apply explicitly versioned rounding only to final derived currency Money, then enforce its minor-unit scale. Prove SQLite/In-Memory parity where persisted, zero accepted residue on rejection, reopen/hydration and provenance. Absent authentic cases remain uncertified; do not manufacture statement graphs. One ticker mapping to multiple listings, a split or pending settlement invalidates ticker-only identity.

**Second-round new evidence/resolved direction:** UD-01 current holdings first and typed WB2–WB4 evidence remain binding; exact immutable source citations rechecked.

**Exact next evidence or decision:** Investment identity ADR and chosen genuine current broker/container/instrument/listing/currency evidence; no trades or performance scope is selected.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Research until the exact evidence/architecture gates are accepted; discovery closure is READY_FOR_CHAT_ARCHITECTURE_DECISION. **Roadmap:** Retain numbering; use ROADMAP_REPLANNING_PACKET_98 slices A/B/C/D.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-23`: Investment identity ADR and chosen genuine current broker/container/instrument/listing/currency evidence; no trades or performance scope is selected.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-current-equity-position`: Investment identity ADR and chosen genuine current broker/container/instrument/listing/currency evidence; no trades or performance scope is selected.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

---

<a id="fw-p3-22"></a>

## FW-P3-22 — Brokerage Support Including IBKR

**Status:** Research
**Depends on:** Brokerage parsing and account-identity decisions

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_AUTHENTIC_SOURCE`. **Exact remaining gate:** No exact authentic brokerage export family, selected account scope or independent trades/fees/positions projection; current manually established positions do not require ingestion.

**Smallest proposed boundary:** Qualify one chosen authentic brokerage source only when requested; keep outside first position slice.

**Decision record:** [ROADMAP_REPLANNING_PACKET_98](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-98>).

**Settled user direction:** UD-01; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_REPOSITORY: existing canonical import support and repository protocols address bank/card/salary, not a qualified IBKR financial family. Workbook holdings are not a brokerage statement parser oracle.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. No trading endpoints, credentials, account changes or inferred support from IBKR naming.

**First-round question/options:** What evidence is required before claiming brokerage/IBKR import support? A downloaded authentic statement/position export fits offline explicit import; authenticated automation adds permissions, token lifecycle and remote dependencies.

**First-round remainder and implications:** A selected authentic brokerage export family, account identity, currency, trades/positions/fees/corporate-action semantics and independent oracle; no broker account was accessed. Brokerage/source identity ADR and likely new position/event persistence before implementation.

**First-round proposed acceptance/falsifier:** Inventory all registered sources of the selected family, independently reconcile cash/positions/fees, preserve source order/currency and reject unknown corporate actions. Future implementation must compare against independently reviewed genuine source/user position facts. Preserve source-observed Decimal units, price/NAV and rates at independently evidenced scale; reject malformed/out-of-contract precision only under an approved field contract. Apply explicitly versioned rounding only to final derived currency Money, then enforce its minor-unit scale. Prove SQLite/In-Memory parity where persisted, zero accepted residue on rejection, reopen/hydration and provenance. Absent authentic cases remain uncertified; do not manufacture statement graphs. A different export version, margin/short positions, corporate actions or absent ownership evidence changes the family boundary.

**Second-round new evidence/resolved direction:** UD-01 current holdings first and typed WB2–WB4 evidence remain binding; exact immutable source citations rechecked.

**Exact next evidence or decision:** No exact authentic brokerage export family, selected account scope or independent trades/fees/positions projection; current manually established positions do not require ingestion.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Research until the exact evidence/architecture gates are accepted; discovery closure is BLOCKED_ON_AUTHENTIC_SOURCE. **Roadmap:** Retain numbering; use ROADMAP_REPLANNING_PACKET_98 slices A/B/C/D.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, SOURCE_TRUTH, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_AUTHENTIC_SOURCE` → `source-selected-broker-family`: No exact authentic brokerage export family, selected account scope or independent trades/fees/positions projection; current manually established positions do not require ingestion.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-23`: No exact authentic brokerage export family, selected account scope or independent trades/fees/positions projection; current manually established positions do not require ingestion.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

---

<a id="fw-p3-23"></a>

## FW-P3-23 — Folio and Broker Identifier Support

**Status:** Research
**Depends on:** Investment identity architecture

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Chat must accept container versus instrument versus position ownership, scoped identifiers, collision policy and explicit immutable revision semantics.

**Smallest proposed boundary:** Namespace-qualified identity and position observations, never names, prices or underlying ISIN substituted for wrapper identity.

**Decision record:** [INVESTMENT_HOLDINGS_ARCHITECTURE_PACKET](#packet-investment-holdings-architecture-packet), [ROADMAP_REPLANNING_PACKET_98](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-98>).

**Settled user direction:** UD-01; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_REPOSITORY: Account carries immutable repository/workspace IDs and redacted identity summaries. That does not establish security, folio, policy or holding-key identity.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. EXPLICIT_USER_DECISION 2026-09-10: propose current holdings first and keep history/performance gated. This is discovery direction, not architecture acceptance or sprint selection. No name-only matching, automatic merge/backfill, or shared bank-account identifier namespace by structural analogy.

**First-round question/options:** How must folio/broker and instrument identity differ? Explicit configured identities are auditable and bounded; display-name/ticker matching reduces input but creates ambiguity.

**First-round remainder and implications:** Exact identity ownership and scope, collision/alias policy, account-policy vs instrument distinctions, correction and historical evidence rules. Investment identity ADR mandatory; schema uniqueness scoped to accepted domain decision, no allocated migration.

**First-round proposed acceptance/falsifier:** Use real observed duplicate/collision/alias evidence when available; isolated identifier mechanics may use nonfinancial opaque values. Future implementation must compare against independently reviewed genuine source/user position facts. Preserve source-observed Decimal units, price/NAV and rates at independently evidenced scale; reject malformed/out-of-contract precision only under an approved field contract. Apply explicitly versioned rounding only to final derived currency Money, then enforce its minor-unit scale. Prove SQLite/In-Memory parity where persisted, zero accepted residue on rejection, reopen/hydration and provenance. Absent authentic cases remain uncertified; do not manufacture statement graphs. Instrument code reuse or different containers holding the same security invalidates a single-key account/security model.

**Second-round new evidence/resolved direction:** UD-01 current holdings first and typed WB2–WB4 evidence remain binding; exact immutable source citations rechecked.

**Exact next evidence or decision:** Chat must accept container versus instrument versus position ownership, scoped identifiers, collision policy and explicit immutable revision semantics.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Research until the exact evidence/architecture gates are accepted; discovery closure is READY_FOR_CHAT_ARCHITECTURE_DECISION. **Roadmap:** Retain numbering; use ROADMAP_REPLANNING_PACKET_98 slices A/B/C/D.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-investment-identity-adr`: Chat must accept container versus instrument versus position ownership, scoped identifiers, collision policy and explicit immutable revision semantics.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

---

<a id="fw-p3-24"></a>

## FW-P3-24 — Portfolio Timeline and Performance

**Status:** Blocked
**Depends on:** Reliable holdings and investment-transaction history

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** UD-01 explicitly gates history/performance; genuine dated contributions/trades/distributions/fees and a performance method are absent.

**Smallest proposed boundary:** No history or performance in first current-holdings boundary; retain exact later evidence/method gate.

**Decision record:** [ROADMAP_REPLANNING_PACKET_98](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-98>).

**Settled user direction:** UD-01; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_LOCAL: Savings / Investments I/J derive current gain and an absolute return from present value and a cost-like base. This is not dated cash-flow history or a time-weighted/money-weighted return series.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. EXPLICIT_USER_DECISION 2026-09-10: propose current holdings first and keep history/performance gated. This is discovery direction, not architecture acceptance or sprint selection. No reconstructing missing flows from current units/NAV, chart interpolation or treating absolute gain as annualized performance.

**First-round question/options:** Can current position snapshots establish portfolio performance? Snapshot value history is less demanding than investment performance; a return series requires independently complete cash flows and date conventions.

**First-round remainder and implications:** Reliable dated contributions, withdrawals, distributions, splits/fees, valuations and accepted performance method. Performance ADR and potentially event/valuation history storage after holdings acceptance.

**First-round proposed acceptance/falsifier:** Independently calculate chosen method on genuine dated evidence and expose incomplete periods; preserve zero denominators as unavailable. Future implementation must compare against independently reviewed genuine source/user position facts. Preserve source-observed Decimal units, price/NAV and rates at independently evidenced scale; reject malformed/out-of-contract precision only under an approved field contract. Apply explicitly versioned rounding only to final derived currency Money, then enforce its minor-unit scale. Prove SQLite/In-Memory parity where persisted, zero accepted residue on rejection, reopen/hydration and provenance. Absent authentic cases remain uncertified; do not manufacture statement graphs. Missing reinvested distributions or timing-sensitive flows invalidate a return conclusion.

**Second-round new evidence/resolved direction:** UD-01 current holdings first and typed WB2–WB4 evidence remain binding; exact immutable source citations rechecked.

**Exact next evidence or decision:** UD-01 explicitly gates history/performance; genuine dated contributions/trades/distributions/fees and a performance method are absent.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve Blocked until the exact evidence/architecture gates are accepted; discovery closure is DEFERRED_WITH_REASON. **Roadmap:** Retain numbering; use ROADMAP_REPLANNING_PACKET_98 slices A/B/C/D.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `source-investment-event-history`: Future reopening condition only; this deferred boundary is not a current prerequisite. Current-scope gate under UD-09/10: source-investment-event-history must satisfy its separately stated identity/source/architecture/implementation boundary. No historical FX dependency.
- `OPTIONAL_ENHANCEMENT` → `decision-performance-method`: Future reopening condition only; this deferred boundary is not a current prerequisite. Current-scope gate under UD-09/10: decision-performance-method must satisfy its separately stated identity/source/architecture/implementation boundary. No historical FX dependency.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

---

<a id="fw-p3-25"></a>

## FW-P3-25 — Asset Allocation

**Status:** Blocked
**Depends on:** Reliable holdings

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** After complete eligible holdings, choose current-market-value allocation, contribution allocation, or separately labeled views of both. Recommendation: current-value allocation for the holdings view; never reuse contribution percentages as current ownership.

**Smallest proposed boundary:** One explicitly labeled allocation basis and complete native-currency denominator; unvalued holdings visibly excluded from any partial result.

**Decision record:** [INVESTMENT_HOLDINGS_ARCHITECTURE_PACKET](#packet-investment-holdings-architecture-packet).

**Settled user direction:** UD-01; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P3-25 | **User product choice:** allocation basis after complete holdings exist. | Contribution share and current-market-value ownership answer different questions. | Current-market-value allocation, explicitly labeled. | Contribution allocation, separately labeled. | Both, separately labeled views. | A for holdings view; do not reuse contribution percentages as ownership. | No allocation view. | Allocation once eligibility/valuation gates close. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_LOCAL: workbook K8/K12/K27/K42 distributions refer to cost/contribution ranges divided by converted totals. They are not uniformly current-market-value weights.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. No applying workbook percentages as ownership or silently excluding missing/stale positions from a supposedly complete denominator.

**First-round question/options:** What should an allocation denominator mean? Native-currency groups avoid premature FX; a consolidated allocation requires an accepted common reporting basis.

**First-round remainder and implications:** User decision between contribution allocation, current valuation allocation or both; complete eligible holdings and stale/unavailable valuation policy. Derived allocation semantics decision required; no schema solely for a computed ratio unless evidence retention is approved.

**First-round proposed acceptance/falsifier:** Independent denominator membership and arithmetic; verify visibility of excluded/unvalued positions and deterministically rounded presentation. Future implementation must compare against independently reviewed genuine source/user position facts. Preserve source-observed Decimal units, price/NAV and rates at independently evidenced scale; reject malformed/out-of-contract precision only under an approved field contract. Apply explicitly versioned rounding only to final derived currency Money, then enforce its minor-unit scale. Prove SQLite/In-Memory parity where persisted, zero accepted residue on rejection, reopen/hydration and provenance. Absent authentic cases remain uncertified; do not manufacture statement graphs. Different valuation dates, unavailable positions or cost-weighted inputs invalidate a current-value allocation claim.

**Second-round new evidence/resolved direction:** UD-01 current holdings first and typed WB2–WB4 evidence remain binding; exact immutable source citations rechecked.

**Exact next evidence or decision:** After complete eligible holdings, choose current-market-value allocation, contribution allocation, or separately labeled views of both. Recommendation: current-value allocation for the holdings view; never reuse contribution percentages as current ownership.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Blocked until the exact evidence/architecture gates are accepted; discovery closure is BLOCKED_ON_PRODUCT_DECISION. **Roadmap:** Retain numbering. Current market net-worth estimation is the Sprint99 proposal; Al Dar is current Salary/budget only with manual override. Historical FX is deferred under UD-10.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_USER_DECISION` → `decision-allocation-basis`: After complete eligible holdings, choose current-market-value allocation, contribution allocation, or separately labeled views of both. Recommendation: current-value allocation for the holdings view; never reuse contribution percentages as current ownership.
- `REQUIRES_IMPLEMENTATION` → `FW-P3-20`: After complete eligible holdings, choose current-market-value allocation, contribution allocation, or separately labeled views of both. Recommendation: current-value allocation for the holdings view; never reuse contribution percentages as current ownership.
- `REQUIRES_IMPLEMENTATION` → `FW-P3-29`: After complete eligible holdings, choose current-market-value allocation, contribution allocation, or separately labeled views of both. Recommendation: current-value allocation for the holdings view; never reuse contribution percentages as current ownership.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-25`: After complete eligible holdings, choose current-market-value allocation, contribution allocation, or separately labeled views of both. Recommendation: current-value allocation for the holdings view; never reuse contribution percentages as current ownership.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

---

<a id="fw-p3-26"></a>

## FW-P3-26 — Net-Worth Integration
**Status:** Blocked
**Depends on:** Investments and multi-currency reporting

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Current holdings/account/liability membership, non-overlap, current valuation dates, reporting basis and completeness remain unaccepted; historical FX/analytics and Al Dar are not current-net-worth dependencies.

**Smallest proposed boundary:** An auditable membership projection with native values and explicit incomplete components; no zero substitution.

**Decision record:** [GENERAL_FX_ARCHITECTURE_PACKET](#packet-general-fx-architecture-packet).

**Settled user direction:** UD-01, UD-09, UD-10; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_REPOSITORY: Account.includeInNetWorth is a model field, not a consolidated valuation implementation. Workbook H46/H47 combines current values and cash with conversion formulas.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. No duplicate inclusion of account cash already represented by a portfolio, no absent asset valued at zero, no unapproved net worth history.

**First-round question/options:** What prevents double counting in net worth? Grouped native positions can remain transparent; one converted net-worth figure needs reliable whole-scope membership and rate evidence.

**First-round remainder and implications:** Accepted holding/account ownership, cash vs invested-asset accounting boundary, liabilities, reporting basis and completeness policy. Derived aggregation/provenance ADR; storage only for approved historical snapshot evidence.

**First-round proposed acceptance/falsifier:** Reconcile source-native positions and liability direction independently, detect duplicate membership and display completeness. Future implementation must compare against independently reviewed genuine source/user position facts. Preserve source-observed Decimal units, price/NAV and rates at independently evidenced scale; reject malformed/out-of-contract precision only under an approved field contract. Apply explicitly versioned rounding only to final derived currency Money, then enforce its minor-unit scale. Prove SQLite/In-Memory parity where persisted, zero accepted residue on rejection, reopen/hydration and provenance. Absent authentic cases remain uncertified; do not manufacture statement graphs. Broker total already includes cash or a missing liability/price invalidates a complete consolidated total.

**Supersession:** any earlier route, broad Al Dar use, combined historical scope or 2021 requirement in this dated first-round evidence is historical only. UD-08/09/10 and the current boundary above govern.

**Second-round new evidence/resolved direction:** UD-10 selects current net-worth estimates only. Current genuine holding/account/liability membership and valuation remain to qualify; no historical FX/analytics prerequisite. Al Dar is current Salary/budget only under UD-09.

**Exact next evidence or decision:** Current holdings/account/liability membership, non-overlap, current valuation dates, reporting basis and completeness remain unaccepted; historical FX/analytics and Al Dar are not current-net-worth dependencies.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Blocked until the exact evidence/architecture gates are accepted; discovery closure is READY_AFTER_NAMED_DEPENDENCY. **Roadmap:** Retain numbering. Current market net-worth estimation is the Sprint99 proposal; Al Dar is current Salary/budget only with manual override. Historical FX is deferred under UD-10.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-23`: Adopted holdings/account/liability membership and non-overlap, valuation dates, reporting basis and completeness remain unaccepted.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-33`: Adopted holdings/account/liability membership and non-overlap, valuation dates, reporting basis and completeness remain unaccepted.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-networth-membership`: Adopted holdings/account/liability membership and non-overlap, valuation dates, reporting basis and completeness remain unaccepted.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

---

<a id="fw-p3-27"></a>

## FW-P3-27 — Optional Market-Data Refresh

**Status:** Research
**Depends on:** verified/user-owned holding identity and units; provider-specific access/terms and retrieval-contract qualification; offline-first cache/freshness policy

This candidate owns **external price/NAV retrieval and freshness**, not holding ownership.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_EXTERNAL_PROVIDER_OR_PERMISSION`. **Exact remaining gate:** FE dates and Change-percent period are now observed; FE/Zurich automated retrieval/persistent cache/feed rights and AMFI selected-row automation/retention remain unqualified. AMFI selected scheme INR and exact Direct mapping require separate evidence.

**Smallest proposed boundary:** Two independent replaceable adapters with exact identity, native Decimal/date, provider provenance and atomic last-success cache only after permission.

## Cross-provider boundary and latest FX scope

UD-09/10 govern the current proposal: Al Dar QAR→INR is solely the current/live monthly Salary/budget INR receive estimate, with an explicit manual-rate override. Current market INR→USD and QAR→USD support net-worth estimates. Historical conversions, the 2021 date floor and paid historical-data access are not requirements. This supersedes the broader intervening UD-07 interpretation. Native holding values, owned units and provider price observations remain distinct from FX and from automation/cache permission. No provider integration or architecture is accepted here.

**Decision record:** [ZURICH_FE_PROVIDER_QUALIFICATION_PACKET](#packet-zurich-fe-provider-qualification-packet), [AMFI_PROVIDER_QUALIFICATION_PACKET](#packet-amfi-provider-qualification-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. REPORTED_ONLY: the queue records successful FE/Zurich and AMFI retrieval on 2026-09-09; this campaign did not replay completed price discovery. VERIFIED_EXTERNAL 2026-09-10: AMFI terms permit personal/noncommercial use but restrict significant electronic storage; Zurich website terms restrict copying and apply separate terms to linked sites. Neither page establishes a precise FE automated-cache license. VERIFIED_EXTERNAL 2026-09-10 user-supplied FE page: footer describes valuation-date prices used for unit transactions on the following working day. The parsed overview exposed headers but no fund rows; no per-row date or Change-% period was established. Its copying notice is limited to incidental viewing/internal single copies, so automation/cache permission remains unestablished.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. No price-as-ownership, global performance date as price date, inferred change period, background-polling mandate or fixed once-per-Qatar-day policy.

**First-round question/options:** Which market-data gaps remain after prior live discovery? Manual dated observation preserves explicit provenance until terms/date evidence exists; automated fetching needs separate provider qualification. An unknown price date can remain explicitly unknown only if the adopted valuation policy permits it.

**First-round remainder and implications:** FE per-row source valuation date and Change-% period; explicit automated retrieval/persistent-cache permission under the linked FE terms; AMFI precise automated-cache scope; provider-specific freshness/fallback and rounding contracts. The footer clarifies date semantics but does not supply the missing actual price dates. Valuation/provenance ADR; additive observation storage likely; existing exchange_rates schema is not an investment-price store.

**First-round proposed acceptance/falsifier:** Independent exact identity/value/date projection; cache failure preserves prior success; no-success failure is unavailable; validate provider rights and accepted time policy before production use. Future implementation must compare against independently reviewed genuine source/user position facts. Preserve source-observed Decimal units, price/NAV and rates at independently evidenced scale; reject malformed/out-of-contract precision only under an approved field contract. Apply explicitly versioned rounding only to final derived currency Money, then enforce its minor-unit scale. Prove SQLite/In-Memory parity where persisted, zero accepted residue on rejection, reopen/hydration and provenance. Absent authentic cases remain uncertified; do not manufacture statement graphs. Provider fields/terms/feed format or observed identity cardinality change; rounding price to displayed cents changes valuation. Sources: https://www.amfiindia.com/terms-of-use and https://www.zurichinternational.com/im/legal/terms-of-use .

**Second-round new evidence/resolved direction:** FE PriceHistory establishes 2026-09-09 USD bid dates for all four configured funds; adjacent change agrees after rounding and official guide states previous-day move. AMFI actual eight-field feed has 14,353 rows, mixed source dates and no currency field. Technical gaps narrowed; permissions not established.

**Exact next evidence or decision:** FE dates and Change-percent period are now observed; FE/Zurich automated retrieval/persistent cache/feed rights and AMFI selected-row automation/retention remain unqualified. AMFI selected scheme INR and exact Direct mapping require separate evidence.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Research until the exact evidence/architecture gates are accepted; discovery closure is BLOCKED_ON_EXTERNAL_PROVIDER_OR_PERMISSION. **Roadmap:** Retain numbering; use ROADMAP_REPLANNING_PACKET_98 slices A/B/C/D.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, EXTERNAL_DATA_SEMANTICS, PROVIDER_PERMISSION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_PROVIDER_PERMISSION` → `provider-fe-permission`: FE dates and Change-percent period are now observed; FE/Zurich automated retrieval/persistent cache/feed rights and AMFI selected-row automation/retention remain unqualified. AMFI selected scheme INR and exact Direct mapping require separate evidence.
- `REQUIRES_PROVIDER_PERMISSION` → `provider-amfi-permission`: FE dates and Change-percent period are now observed; FE/Zurich automated retrieval/persistent cache/feed rights and AMFI selected-row automation/retention remain unqualified. AMFI selected scheme INR and exact Direct mapping require separate evidence.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-amfi-inr-class`: FE dates and Change-percent period are now observed; FE/Zurich automated retrieval/persistent cache/feed rights and AMFI selected-row automation/retention remain unqualified. AMFI selected scheme INR and exact Direct mapping require separate evidence.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-architecture-fw-p3-27`: FE dates and Change-percent period are now observed; FE/Zurich automated retrieval/persistent cache/feed rights and AMFI selected-row automation/retention remain unqualified. AMFI selected scheme INR and exact Direct mapping require separate evidence.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

<a id="packet-amfi-provider-qualification-packet"></a>

<details>
<summary>AMFI_PROVIDER_QUALIFICATION_PACKET — complete proposed decision packet</summary>

## AMFI_PROVIDER_QUALIFICATION_PACKET

| # | Required field | Draft decision packet |
| --- | --- | --- |
| 1 | Owning FW IDs | FW-P3-27; informs FW-P3-20, FW-P3-28, and Sprint 98. |
| 2 | User problem | Obtain an identifiable current NAV observation for a selected Indian mutual-fund holding only after ownership and Direct-plan identity are established. |
| 3 | Verified current state | NAVAll returned a semicolon-delimited eight-field feed with 14,353 numeric rows; dates are mixed, not one snapshot. |
| 4 | Accepted authorities | Native holdings/units and source/user evidence own position identity; ADR-046 governs statement work; roadmap requires Direct-plan-only identity and provider qualification. |
| 5 | Exact missing decision | Whether AMFI grants bounded personal automated retrieval, selected-row cache, retention, attribution, and refresh rights. |
| 6 | Evidence acquired | Header: Scheme Code; two ISIN fields; Scheme Name; Plan; Option; NAV; Date. Every observed row had eight fields; currency absent from header. |
| 7 | Options considered | No integration; manual user-entered observation; selected-row adapter after written clarification. |
| 8 | Recommended option | Keep AMFI a technically usable candidate; request explicit provider clarification before automation or persistent cache. |
| 9 | Why competing options are rejected | Endpoint access is not automation/retention permission; manual fallback is not AMFI; full feed archive conflicts with limited-use/storage terms. |
| 10 | Smallest coherent implementation boundary | One Direct-plan fund: exact configured scheme code plus approved ISIN and plan/option; fetch, exact-match, retain only permitted observation/provenance. |
| 11 | Included scope | Exact identity match, source date, observed NAV Decimal, response digest, fetch time, attribution, explicit unavailable/stale state. |
| 12 | Explicit exclusions | Full-feed archive, generic discovery, Regular-plan substitution, inferred currency, units/ownership, historical performance, import, FX. |
| 13 | Durable model/persistence requirements | Only after permission: selected-row observation with source/fetch timestamps, digest, identity tuple, attribution/version, expiry/retention. |
| 14 | Migration impact | REQUIRES_DECISION; no migration number. |
| 15 | ADR impact | NEW_ADR_REQUIRED for permissions, provenance, storage, freshness, and fallback; holding identity remains separate. |
| 16 | Privacy/security boundary | No credentials; no full feed persistence; minimum permitted data; preserve attribution without owner holding facts. |
| 17 | SQLite/In-Memory implications | Persisted observation/cache requires equivalent identity, expiry, unavailable, and deletion semantics. |
| 18 | Hydration/relaunch implications | Expose provider/fetch/source date and cache state; never zero-substitute or treat a current quote as history. |
| 19 | Independent acceptance oracle | Official AMC evidence establishes selected-scheme INR denomination; independently compare scheme/ISIN/plan/option/date. |
| 20 | Failure cases | No exact tuple, Regular-plan match, malformed NAV/date, unproven currency, stale cache, permission uncertainty, conflict: unavailable, never substitution. |
| 21 | Reversal/correction semantics | Retained observations are append-only; correction is later observation/invalidation, never native-holding rewrite. |
| 22 | Source evidence requirement | Feed supports market observation only; authentic brokerage/fund source or verified user evidence remains required for units/cost. |
| 23 | Runtime acceptance requirement | Future network/cache failure, refresh, attribution, unavailable state require runtime acceptance; none claimed. |
| 24 | Dependencies | Current-holdings-first identity packet; official AMC denomination proof; provider clarification; approved rate/valuation provenance. |
| 25 | Evidence that falsifies the recommendation | AMFI prohibits requested automation/cache; tuple cannot be established; AMC contradicts INR denomination; permitted endpoint gives another contract. |
| 26 | Personal-v1 relevance | POST_V1 unless Chat later adopts external valuation as v1 gate. |
| 27 | Recommended FUTURE_WORK status after Chat review | FW-P3-27: BLOCKED_ON_EXTERNAL_PROVIDER_OR_PERMISSION for automated/cached use; technical observation complete. |
| 28 | Recommended roadmap effect after Chat review | Keep Sprint 98 adapter gated behind holdings identity and provider qualification; do not activate or widen. |

Evidence: public-endpoint-observations.json lines 3-21 records response digest, eight-field header, row/date aggregates, currency absence, and no full-data retention. AMFI Terms of Use: https://www.amfiindia.com/terms-of-use. Endpoint accessibility is not permission. Prepared Sprint 98 roadmap lines 104-110 require Direct-plan-only identity.

### Draft AMFI provider-permission questions -- do not send

1. May an individual automatically retrieve NAVAll.txt for personal, non-commercial use at bounded frequency? State rate limit, user-agent, access method, and attribution.
2. May a client parse transiently and retain only records matching a configured Direct-plan scheme code plus ISIN plus plan/option, not the full download? State count/retention limits.
3. May selected-row source date, NAV, identity tuple, fetch time, and response digest be retained for provenance? If not, what minimum fields may be retained?
4. Is explicit user refresh allowed with no background polling? State freshness, expiry, and retry rules.
5. What attribution, disclaimer, redistribution/export, and deletion terms apply to a personal local cache and report?
6. Is there an official machine-readable endpoint or licence with clearer selected-row terms?

</details>

<a id="packet-zurich-fe-provider-qualification-packet"></a>

<details>
<summary>ZURICH_FE_PROVIDER_QUALIFICATION_PACKET — complete proposed decision packet</summary>

## ZURICH_FE_PROVIDER_QUALIFICATION_PACKET

| # | Required field | Draft decision packet |
| --- | --- | --- |
| 1 | Owning FW IDs | FW-P3-27; informs FW-P3-29 and Sprint 98. |
| 2 | User problem | Obtain dated native-USD price observation for a verified Zurich wrapper/Fund Code holding, never treating price as proof of ownership, policy, units, contributions, or vesting. |
| 3 | Verified current state | Download Tool GetPriceHistory returned dated bid observations for all four configured pairs, each latest recorded date then preceding day. |
| 4 | Accepted authorities | Current-holdings-first direction; exact Fund Code plus expected USD is price identity; wrapper/Fund Code differs from underlying ISIN/security; price never establishes ownership. |
| 5 | Exact missing decision | Provider permission for automated GET, bounded-history retention, persistent cache, refresh, attribution, and local display. |
| 6 | Evidence acquired | Mappings N0USD to GPP7, USDL3 to AUJDP, 3UUSD to LCP0, B0280 to CAZYC; all observed USD. Guide p3 says price and percentage move from previous day; all four adjacent changes agreed after two-decimal rounding. |
| 7 | Options considered | No provider price; manual dated price; explicit-permission adapter using dated history route. |
| 8 | Recommended option | Date-semantics gap is technically closed for observed history route; automated/persistent use remains BLOCKED_ON_EXTERNAL_PROVIDER_OR_PERMISSION. |
| 9 | Why competing options are rejected | Overview/global-performance date and null PriceDate/NAVDate/Time on other row/unit routes are not price authority; replay is not licence/cache right. |
| 10 | Smallest coherent implementation boundary | For one verified/user-owned Fund Code, retrieve one bounded dated bid, preserve price date/fetch time/digest/attribution, show unavailable without permitted data. |
| 11 | Included scope | Four exact mappings, native USD price-date observation, day-over-day percentage semantics, per-observation provenance. |
| 12 | Explicit exclusions | Ownership, units, contributions, policy/account, allocation, vesting, transactions, performance, underlying-security substitution, FX, retired multiplier. |
| 13 | Durable model/persistence requirements | Only after permission: immutable Fund Code/provider code, currency, price date, fetch time, digest, attribution, route/version, bounded cache/retention. |
| 14 | Migration impact | REQUIRES_DECISION; no migration number. |
| 15 | ADR impact | NEW_ADR_REQUIRED for observation, licence/attribution, cache/freshness, wrapper-versus-underlying identity. |
| 16 | Privacy/security boundary | Public code mapping is not policy/account identity. Keep owner units/policy separate; no credentials; retain provider-authorized minimum. |
| 17 | SQLite/In-Memory implications | Persisted observations, expiry, attribution, deletion, and unavailable behavior require provider parity. |
| 18 | Hydration/relaunch implications | Preserve price date separately from fetch time and stale/unavailable status; never substitute global performance date. |
| 19 | Independent acceptance oracle | Public history gives dated price facts; guide p3 supports adjacent-day percentage meaning. Holdings/units need policy/user evidence, not FE. |
| 20 | Failure cases | Unknown/ambiguous Fund Code, provider-code mismatch, non-USD response, invalid/missing date, unavailable history, permission uncertainty, expired cache, ISIN substitution fail closed. |
| 21 | Reversal/correction semantics | Later row is later observation. Invalidation makes valuation unavailable, never changes units/ownership evidence. |
| 22 | Source evidence requirement | No statement needed for public price mechanics. Genuine policy/user evidence remains mandatory for holder, units, contributions, container identity. |
| 23 | Runtime acceptance requirement | Future permission-compliant refresh, expiry/failure, attribution, unknown-code, missing-date display need runtime acceptance; none recorded. |
| 24 | Dependencies | FW-P3-29 identity/units; written FE/provider clarification; cache/attribution policy; derived-value architecture. |
| 25 | Evidence that falsifies the recommendation | Provider terms prohibit automation/cache; official docs contradict route/date semantics; mapping changes; holding evidence requires another wrapper identity. |
| 26 | Personal-v1 relevance | POST_V1 unless Chat adopts valuation as v1 gate. |
| 27 | Recommended FUTURE_WORK status after Chat review | FW-P3-27: price-date gap closed; automated/cached adapter remains BLOCKED_ON_EXTERNAL_PROVIDER_OR_PERMISSION. |
| 28 | Recommended roadmap effect after Chat review | Preserve Sprint 98 split: current holdings/identity first, provider qualification second, performance/history later. |

Evidence: fe-dated-price-observations.json lines 3-43, 46-86, 89-129, 132-172 records all mappings, USD dated history, response digests, rounded adjacent-change agreement. User guide page 3: https://edge.sitecorecloud.io/zurichinsurf8c0-zwpshared-prod-d824/media/project/zurich-headless/zint/general-documents/zil10047-fund-centre-user-guide.pdf. Evidence closes date observation, not permission/licence.

### Draft Zurich/FE provider-permission questions -- do not send

1. Does Zurich and/or FE permit a personal non-commercial local app to call Download Tool GetPriceHistory automatically for the four configured Zurich Fund Codes? Identify terms/responsible provider.
2. If allowed, state frequency, history window, concurrency, user-agent, attribution, and geographic/account restrictions. Is explicit user refresh allowed with no background polling?
3. May app persist only Fund Code, provider code, currency, price date, bid, fetch time, digest, route/version, attribution? State history and retention/deletion limit.
4. May observations appear in private offline-first valuation and user-selected local reports? State attribution, disclaimer, export, redistribution rules.
5. Is history authoritative for price dates, and is displayed percentage change from preceding available price day? State market-calendar/gap treatment.
6. Confirm Fund Code is a wrapper/fund view rather than authority to substitute underlying ISIN/security. Provide any official permitted identity cross-reference.

</details>

---

<a id="fw-p3-28"></a>

## FW-P3-28 — Manual Holdings and Custom-Fund Valuation

**Status:** Research
**Depends on:** Investment domain model, valuation provenance and reversible editing

Support holdings or valuation evidence that cannot be fully reconstructed from approved source/user evidence or a qualified external provider.

Candidate outcomes include:

- manual holding creation where the product explicitly allows it;
- manual units/contribution/cost evidence with clear provenance;
- dated manual valuations or prices;
- custom fund/security definitions;
- correction history;
- clear separation between imported, fetched and user-entered evidence;
- explicit valuation staleness.

This is a **fallback/manual** boundary. It is not the primary owner of the user's Indian mutual-fund domain, which remains `FW-P3-20`; AMFI NAV retrieval remains `FW-P3-27`. Manual entries must never overwrite imported/source-owned records or masquerade as provider observations.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Chat must select the bounded manual position/price input and append-only correction family, including effective/recorded date, provenance and precision rules.

**Smallest proposed boundary:** Explicit user-entered dated snapshot or custom price with preserved prior revisions; never overwrite imported/provider facts.

**Decision record:** [INVESTMENT_HOLDINGS_ARCHITECTURE_PACKET](#packet-investment-holdings-architecture-packet), [ROADMAP_REPLANNING_PACKET_98](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-98>).

**Settled user direction:** UD-01; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_LOCAL: workbook ownership/cost cells are entered values; pricing cells mix entered numbers, GOOGLEFINANCE and custom muFunds functions. One source type cannot honestly describe all cells.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. EXPLICIT_USER_DECISION 2026-09-10: propose current holdings first and keep history/performance gated. This is discovery direction, not architecture acceptance or sprint selection. No primary-domain reassignment to manual fallback, hidden provider substitution or invented cost lots.

**First-round question/options:** How should manual/custom holdings differ from imported and fetched facts? Manual snapshots cover missing providers with less automation; inferring transaction history from them would invent evidence.

**First-round remainder and implications:** Which manual creation/correction cases are adopted; effective/recorded dates; provenance and explicit replacement/void policy. Manual evidence/correction ADR and likely additive storage; no generic mutation framework required merely for abstraction.

**First-round proposed acceptance/falsifier:** Verify round-trip exact entered evidence, correction lineage, independent display labels and rejection without partial durable values. Future implementation must compare against independently reviewed genuine source/user position facts. Preserve source-observed Decimal units, price/NAV and rates at independently evidenced scale; reject malformed/out-of-contract precision only under an approved field contract. Apply explicitly versioned rounding only to final derived currency Money, then enforce its minor-unit scale. Prove SQLite/In-Memory parity where persisted, zero accepted residue on rejection, reopen/hydration and provenance. Absent authentic cases remain uncertified; do not manufacture statement graphs. A correction that changes imported ownership or historical reporting needs a stronger contract than an editable current snapshot.

**Second-round new evidence/resolved direction:** UD-01 current holdings first and typed WB2–WB4 evidence remain binding; exact immutable source citations rechecked.

**Exact next evidence or decision:** Chat must select the bounded manual position/price input and append-only correction family, including effective/recorded date, provenance and precision rules.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Research until the exact evidence/architecture gates are accepted; discovery closure is READY_FOR_CHAT_ARCHITECTURE_DECISION. **Roadmap:** Retain numbering; use ROADMAP_REPLANNING_PACKET_98 slices A/B/C/D.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-23`: Chat must select the bounded manual position/price input and append-only correction family, including effective/recorded date, provenance and precision rules.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-investment-revision-family`: Chat must select the bounded manual position/price input and append-only correction family, including effective/recorded date, provenance and precision rules.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

---

<a id="fw-p3-29"></a>

## FW-P3-29 — Retirement and ISP Tracking

**Status:** Research
**Depends on:** accepted investment/holding identity, contribution/employer-benefit and planning-domain models; source/user-owned evidence for units, ownership and contribution classes

Support retirement and employer-sponsored investment plans, including the user's Qatar Airways ISP boundary, without using an external price table as ownership evidence.

Candidate ISP evidence includes:

- source/user-owned policy/account identity;
- mandatory units;
- AVC units;
- future separately evidenced contribution classes;
- total position derived from the accepted unit classes;
- employee/employer/voluntary contribution and cost evidence where available;
- multiple plan portfolios/allocation history where source/user evidence establishes them;
- links to Salary/planning workflows;
- derived current valuation only after independently owned units exist.

**Zurich price separation:** the prospective external price lookup codes are `N0USD`, `USDL3`, `3UUSD` and `B0280`, all with expected USD price currency. Zurich pricing belongs to `FW-P3-27`. A price row does **not** establish units owned, contribution history, policy/account ownership, policy balance, asset allocation, vesting or transactions. Fund name alone is not identity authority.

The historical Budget Analysis `0.75` Conventional Blend factor represented a temporary vesting/availability workaround. By explicit user decision it is **retired from future LedgerForge requirements**: do not implement a permanent 75% multiplier, apply it to `B0280`, or infer any replacement vesting schedule. Future vesting semantics require new explicit/source evidence if they later matter.

Ordinary ISP valuation remains:

```text
verified/user-owned units × native USD fund price = derived native USD market value
```

Any later reporting conversion is separately derived with its own FX provenance.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Exact genuine policy/container and dated mandatory/AVC ownership evidence remain to qualify; Chat must accept unit-class/cost/revision architecture. FE price dates do not close ownership.

**Smallest proposed boundary:** Separate mandatory/AVC Decimal units, derived unit sum and native USD valuation; contribution allocation explicitly not acquired-lot cost; no 0.75 multiplier or inferred vesting.

**WB4 — reused private workflow observation, 2026-09-10:** ISP mandatory and AVC units are combined while contribution amounts are allocated by entered percentages. Unit observations and contribution allocation do not establish lots, vesting or performance. The historical 0.75 multiplier remains retired; no replacement vesting model is inferred.

**Decision record:** [INVESTMENT_HOLDINGS_ARCHITECTURE_PACKET](#packet-investment-holdings-architecture-packet), [ROADMAP_REPLANNING_PACKET_98](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-98>).

**Settled user direction:** UD-01; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_LOCAL: Monthly ISP balance update G3:H5 holds entered mandatory/AVC units; D3:D5 sums them. E3:E5 allocates total contributions using entered A3:A5 percentages. This proves workbook arithmetic, not genuine tax-lot cost. Savings / Investments B8:F11 contains separately entered observations; dates do not prove provider price dates.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. EXPLICIT_USER_DECISION 2026-09-10: propose current holdings first and keep history/performance gated. This is discovery direction, not architecture acceptance or sprint selection. Retired 0.75 multiplier stays excluded; no replacement vesting schedule, Al Dar FX, fetched-unit inference or policy balance inferred from public price rows.

**First-round question/options:** What ISP position facts can be grounded now? Current unit-class snapshots serve present ownership; contribution/vesting/performance reconstruction needs further source history.

**First-round remainder and implications:** Exact policy/container identity, effective date and source/user attestation for units/classes/contributions; separate future vesting evidence only if later requested. ISP holding/contribution ADR and additive persistence likely; no migration number.

**First-round proposed acceptance/falsifier:** Independent unit-class sum and identity reconciliation; exact Decimal multiplication with separately approved final rounding; preserve missing price date explicitly. Future implementation must compare against independently reviewed genuine source/user position facts. Preserve source-observed Decimal units, price/NAV and rates at independently evidenced scale; reject malformed/out-of-contract precision only under an approved field contract. Apply explicitly versioned rounding only to final derived currency Money, then enforce its minor-unit scale. Prove SQLite/In-Memory parity where persisted, zero accepted residue on rejection, reopen/hydration and provenance. Absent authentic cases remain uncertified; do not manufacture statement graphs. Different source class meanings, contribution reallocations or genuine vesting evidence changes the adopted boundary.

**Second-round new evidence/resolved direction:** UD-01 current holdings first and typed WB2–WB4 evidence remain binding; exact immutable source citations rechecked.

**Exact next evidence or decision:** Exact genuine policy/container and dated mandatory/AVC ownership evidence remain to qualify; Chat must accept unit-class/cost/revision architecture. FE price dates do not close ownership.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Research until the exact evidence/architecture gates are accepted; discovery closure is READY_FOR_CHAT_ARCHITECTURE_DECISION. **Roadmap:** Retain numbering; use ROADMAP_REPLANNING_PACKET_98 slices A/B/C/D.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-23`: Exact genuine policy/container and dated mandatory/AVC ownership evidence remain to qualify; Chat must accept unit-class/cost/revision architecture. FE price dates do not close ownership.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-current-isp-position`: Exact genuine policy/container and dated mandatory/AVC ownership evidence remain to qualify; Chat must accept unit-class/cost/revision architecture. FE price dates do not close ownership.
- `OPTIONAL_ENHANCEMENT` → `FW-P3-27`: External refresh is optional for a genuinely evidenced manual position/valuation boundary.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

---

<a id="fw-p3-30"></a>

## FW-P3-30 — Locale-Aware and Derived Multi-Currency Presentation
**Status:** Blocked
**Depends on:** accepted native Money and a current derived-reporting contract only where converted values are displayed

**Completed boundary:** native QAR/INR Money and per-native-currency grouping remain accepted. **Remaining boundary:** native locale formatting/accessibility and separately governed current net-worth estimates. UD-09/10 exclude historical FX; Al Dar is solely the current Salary/budget receive estimate with manual override. Current reporting uses market observations and preserves original amounts.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Separate pure native locale display from current derived estimates; choose locale/accessibility expectations and approved current reporting orientation, without historical scope.

**Smallest proposed boundary:** Native currency/scale and accessible currency identity remain explicit; locale grouping never triggers conversion. Converted values follow only the directed source contract.

**Decision record:** [GENERAL_FX_ARCHITECTURE_PACKET](#packet-general-fx-architecture-packet), [ROADMAP_REPLANNING_PACKET_99](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-99>).

**Settled user direction:** UD-08, UD-09, UD-10; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_REPOSITORY: native Money and currency grouping already exist; optional Account base-currency fields alone do not authorize converted display.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. No reclassification of supported institutions from catalog membership, hidden conversions or native-value rounding.

**First-round question/options:** What formatting is possible before reporting FX? Formatting-only refinements can reuse native amounts; conversion requires the full reference-rate/provenance boundary.

**First-round remainder and implications:** Specific locale/Indian grouping requirements and a separate decision on derived secondary values. Formatting-only likely no migration; converted presentation requires derived-FX ADR.

**First-round proposed acceptance/falsifier:** Independent locale render expectations for accepted native amounts, no changed stored decimal/minor values, keyboard/accessibility currency clarity. Preserve native Money exactly. Preserve rate/valuation observations at their independently evidenced Decimal scale; apply only the approved final derived-Money rounding/version rule. Future checks use the exact locale, as-of, membership and conversion boundary above; prove provider persistence/reopen parity only where that boundary persists state. Missing genuine financial evidence remains uncertified, never manufactured. Any view silently aggregates currencies or changes numeric value under locale formatting invalidates the boundary.

**Supersession:** any earlier route, broad Al Dar use, combined historical scope or 2021 requirement in this dated first-round evidence is historical only. UD-08/09/10 and the current boundary above govern.

**Second-round new evidence/resolved direction:** UD-10 selects current net-worth estimates only and supersedes historical/2021 requirements. Current direct market INR→USD and QAR→USD observations are acquired; Al Dar remains solely current Salary/budget under UD-09.

**Exact next evidence or decision:** Separate pure native locale display from current derived estimates; choose locale/accessibility expectations and approved current reporting orientation, without historical scope.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Blocked until the exact evidence/architecture gates are accepted; discovery closure is READY_FOR_CHAT_ARCHITECTURE_DECISION. **Roadmap:** Retain numbering. Current market net-worth estimation is the Sprint99 proposal; Al Dar is current Salary/budget only with manual override. Historical FX is deferred under UD-10.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-locale-presentation`: Separate pure native locale formatting from the combined converted-value contract; selected locale/accessibility expectations and derived display basis need review.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-31`: Separate pure native locale formatting from the combined converted-value contract; selected locale/accessibility expectations and derived display basis need review.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

---

<a id="fw-p3-31"></a>

## FW-P3-31 — General Reference-Rate Storage and Provenance
**Status:** Research
**Depends on:** Chat-approved current market-rate provider, freshness/attribution/cache, exact Decimal orientation and derived-rounding contract

UD-08/10 select current market estimation, using directly observed INR→USD and QAR→USD. Store only the bounded current/last-success evidence required by the approved contract: provider, direction, source update/next-update, fetch time, exact Decimal, digest/adapter version and availability. Existing exchange_rates schema capacity is not an implemented service. Historical-rate collection, 2021 coverage and paid historical access are not requirements. Al Dar/manual Salary planning evidence has separate ownership under `FW-P3-08`.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Chat must accept current market provider, source/fetch freshness, direct/reporting orientation, rounding and bounded current-cache ownership; no historical entitlement remains.

**Smallest proposed boundary:** Current and last-success market INR→USD/QAR→USD observations for derived net-worth estimates; no historical collection.

## Derived arithmetic decision for Chat

For a native position, retain unrounded exact Decimal units × price and round only the final derived currency Money. Propose nearest-even rounding at the currency catalog scale with an explicit derivation version; this is not yet accepted and does not alter ADR-045's upward QAR funding guard. For linear market conversion, calculate each included display component from exact native Money and exact directed rate, round once per displayed component, and define the displayed total as the exact sum of those displayed Money components. Show that policy and membership; do not mix a separately rounded aggregate with a different sum of displayed values. Historical valuation is outside the selected outcome under UD-10.

Al Dar remains only a current monthly planner reference. Quote the calculator’s explicit QAR send amount; label the resulting INR as an estimate based on the observed current or manually overridden rate. Do not call it a prediction of the eventual month-end exchange rate or guaranteed settlement. Preserve amount binding, separate fee and manual/provider provenance. This does not add Al Dar aggregation or historical evidence to market reporting.

**Decision record:** [GENERAL_FX_ARCHITECTURE_PACKET](#packet-general-fx-architecture-packet), [ROADMAP_REPLANNING_PACKET_99](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-99>).

**Settled user direction:** UD-08, UD-09, UD-10; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_REPOSITORY: exchange_rates has source and valid_at but lacks explicit fetched/source-time distinction, response digest and adapter/derivation version. No rate repository service is exposed. VERIFIED_EXTERNAL 2026-09-10: ExchangeRate-API open endpoint permits end-use caching with attribution, disallows redistribution and documents once-daily updates; its terms describe informational/illustrative suitability. The candidate remains unselected.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. No live settlement promise, fixed provider selection, hidden haircut, background polling mandate, Al Dar or reused fetch time as historical price date.

**First-round question/options:** Can existing schema and provider evidence establish general FX readiness? One dated QAR-base snapshot preserves coherent INR/USD legs; combining independent provider times requires an additional consistency decision.

**First-round remainder and implications:** Accepted provider/attribution, snapshot completeness, positive finite-rate validation, stale/fallback semantics, rounding point and durable schema contract. Future derived-FX ADR and additive schema decision required; do not assume old table needs no migration or rewrite V1.

**First-round proposed acceptance/falsifier:** Independent rational/Decimal arithmetic and explicit rounding oracle; reject nonpositive/nonfinite/missing/wrong-base legs; cached success survives network failure and never blocks canonical hydration. Future implementation must compare against independently reviewed genuine source/user position facts. Preserve source-observed Decimal units, price/NAV and rates at independently evidenced scale; reject malformed/out-of-contract precision only under an approved field contract. Apply explicitly versioned rounding only to final derived currency Money, then enforce its minor-unit scale. Prove SQLite/In-Memory parity where persisted, zero accepted residue on rejection, reopen/hydration and provenance. Absent authentic cases remain uncertified; do not manufacture statement graphs. Provider terms/data contract, currency orientation or snapshot time change. Sources: https://www.exchangerate-api.com/docs/free and https://www.exchangerate-api.com/terms .

**Supersession:** any earlier route, broad Al Dar use, combined historical scope or 2021 requirement in this dated first-round evidence is historical only. UD-08/09/10 and the current boundary above govern.

**Second-round new evidence/resolved direction:** UD-10 selects current net-worth estimates only and supersedes historical/2021 requirements. Current direct market INR→USD and QAR→USD observations are acquired; Al Dar remains solely current Salary/budget under UD-09.

**Exact next evidence or decision:** Chat must accept current market provider, source/fetch freshness, direct/reporting orientation, rounding and bounded current-cache ownership; no historical entitlement remains.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Research until the exact evidence/architecture gates are accepted; discovery closure is READY_FOR_CHAT_ARCHITECTURE_DECISION. **Roadmap:** Retain numbering. Current market net-worth estimation is the Sprint99 proposal; Al Dar is current Salary/budget only with manual override. Historical FX is deferred under UD-10.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-directed-fx-adr`: Current-scope gate under UD-09/10: decision-directed-fx-adr must satisfy its separately stated identity/source/architecture/implementation boundary. No historical FX dependency.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

<a id="packet-general-fx-architecture-packet"></a>

<details>
<summary>GENERAL_FX_ARCHITECTURE_PACKET — complete proposed decision packet</summary>

## GENERAL_FX_ARCHITECTURE_PACKET

| # | Required field | Proposed decision |
| --- | --- | --- |
| 1 | Owning FW IDs | FW-P3-30, FW-P3-31, FW-P3-32, FW-P3-33; affects FW-P3-34 and the QAR-to-INR boundary of FW-P3-08. |
| 2 | User problem | Estimate current net worth in selected reporting currencies from current market observations, while preserving native holdings/amounts. Current Al Dar QAR→INR serves only the monthly Salary/budget estimate. |
| 3 | Verified current state | Native Money/grouping are accepted and exchange_rates is unused capacity. No general FX service is implemented. The old via-QAR route is superseded by UD-08. UD-09 narrows Al Dar to current Salary/budget estimates; accepted ADR-045 manual calculations remain unchanged. |
| 4 | Accepted authorities | ADR-008/024/033; UD-08 direct market INR→USD and permitted QAR→USD; UD-09 current-only Al Dar Salary/budget estimate with manual override; UD-10 current net-worth estimates only, superseding the historical requirement and 2021 range. |
| 5 | Exact missing decision | Chat must accept current market provider, observation freshness, direct/inverse reporting orientation, rounding/membership and workspace financial setting. No historical source or paid historical entitlement is required. Chat must also accept the provider-suitability gate in field 6. |
| 6 | Evidence acquired | Separate current INR-base/USD and QAR-base/USD observations were acquired with source/fetch timestamps and digests. The INR-base USD Decimal is 0.010513 at source update 2026-09-10T00:02:31Z. Free endpoint documentation permits attributed cached end use and daily updates. Historical research is retained only as historical discovery, not a requirement. Provider terms limit these rates to illustrative information and discourage transaction or financial-data use. Chat must accept an explicitly illustrative current estimate using this candidate, or qualify another provider; cache access alone does not settle suitability. |
| 7 | Options considered | Current market net-worth projection; historical FX ledger; current Salary Al Dar quote reused for investments; stale/missing rates silently substituted. |
| 8 | Recommended option | One current net-worth projection using directly observed market INR→USD and QAR→USD evidence, with source timestamps, availability and explicit displayed estimate basis. Chat approves the selected target-currency set and any reciprocal orientation of the same market observations; no inverse or cross behavior is silently implemented. Keep Al Dar solely in Salary/budget. |
| 9 | Why competing options are rejected | Historical ledger adds scope the user excluded; Al Dar is a current remittance estimate, not net-worth pricing; stale or missing rate substitution hides uncertainty. Native Money remains unchanged. |
| 10 | Smallest coherent implementation boundary | Current market observations plus one selected current net-worth reporting projection; USD reporting can use direct INR→USD/QAR→USD and unchanged native USD. Additional target-currency orientation is explicit Chat architecture, not a new historical service. |
| 11 | Included scope | Current exact directed market observations, source/fetch timestamps, provider attribution, last-success cache, freshness/unavailable states, complete selected native membership, current prices, explicit final rounding and financial reporting preference. |
| 12 | Explicit exclusions | Historical conversion/retained historical rate collection; 2021 coverage; paid historical entitlement; Al Dar net-worth pricing; future-rate prediction; native amount rewrite; silent reciprocal/cross paths; haircuts; automatic polling. |
| 13 | Durable model/persistence requirements | Current MarketRateObservation: provider, base/quote orientation, exact Decimal lexeme/value, source update/next-update when supplied, fetchedAt, adapter/version, response digest and availability. Retain only the bounded current/last-success cache needed by the accepted contract, not a historical-conversion collection. Derived current estimate records native membership, price/rate observations and algorithm/rounding version. Financial reporting settings remain distinct from appearance and Salary rates. |
| 14 | Migration impact | REQUIRES_DECISION: choose a narrow durable current-observation/cache owner after auditing existing unused schema; no historical schema or migration number is allocated. |
| 15 | ADR impact | NEW_ADR_REQUIRED; align ADR-008/024/033. An explicit ADR-045 alignment/successor is separately required before external Al Dar quotes affect Salary. |
| 16 | Privacy/security boundary | Free current requests need no historical API credential and no owner balances. Retain attribution and permitted local end-use cache; no rate redistribution or private ledger upload. Al Dar amount disclosure stays in its separate explicitly triggered Salary action. The suitability limitation in field 6 applies. |
| 17 | SQLite/In-Memory implications | Current observation/availability and derivation behavior must match where persisted. Incomplete or malformed refresh cannot replace last-success state or mutate native financial facts. |
| 18 | Hydration/relaunch implications | Reopen reconstructs current/last-success evidence with its actual source time, marks stale under approved policy, and derives the same selected current view over unchanged native facts. Revalidate post-87 publication ownership. |
| 19 | Independent acceptance oracle | Exact captured current INR-base/USD and QAR-base/USD fields plus independent Decimal arithmetic and genuine current financial membership/price evidence. Test stale/unavailable and rounding independently; historic documentation is not an acceptance dependency. |
| 20 | Failure cases | Unsupported direction/target, invalid rate/precision, HTTP/schema failure or 429, stale/missing source time, incomplete assets/liabilities or current prices, inconsistent freshness/membership, overflow/rounding error or stale async generation. Unavailable components are not zero. |
| 21 | Reversal/correction semantics | An explicit new current refresh or user reporting-setting change updates bounded observation/derivation state; original native Money and position/source facts never change. This is not a historical correction or transaction mutation family. |
| 22 | Source evidence requirement | Current primary rate observations are acquired. The selected genuine current asset/liability/holding membership and price evidence remain necessary for any complete net-worth claim. No historical market or Al Dar data is required. |
| 23 | Runtime acceptance requirement | Future current refresh/review/cancel/error/offline/stale behavior, native invariance, selected reporting orientation, provider parity and durable relaunch; no historical flow. |
| 24 | Dependencies | Chat current-FX/reporting ADR; adopted current financial membership/valuation; exact post-87 provider/actor review. Historical FX, paid services, Al Dar and appearance implementation are not dependencies. |
| 25 | Evidence that falsifies the recommendation | The source cannot provide the selected current direction/freshness under permitted cache use, target orientation is unapproved, or eligible current membership/price evidence is incomplete. Keep the estimate incomplete rather than inventing zero or historical evidence. Falsified if the proposed use exceeds the suitability boundary in field 6. |
| 26 | Personal-v1 relevance | PRE_V1_OPTIONAL unless Chat explicitly adopts current net-worth reporting. No historical FX prerequisite remains. |
| 27 | Recommended FUTURE_WORK status after Chat review | FW-P3-31/33 READY_FOR_CHAT_ARCHITECTURE_DECISION for current estimates; FW-P3-32 DEFERRED_WITH_REASON by UD-10; no automatic implementation-ready claim. |
| 28 | Recommended roadmap effect after Chat review | Sprint 99 proposes current market net-worth reporting only; remove the historical and 2021/paid-source entry gates. Al Dar remains current Salary/budget-only. Keep numbering and Chat activation authority. |

</details>

---

<a id="fw-p3-32"></a>

## FW-P3-32 — Historical FX Conversion
**Status:** Blocked
**Depends on:** a future explicit user request for historical conversions with a concrete period and purpose

**Explicit deferment — UD-10, 2026-09-10:** historical FX is not needed for the selected current net-worth estimate. The earlier combined-current/historical direction and 2021 coverage choice are superseded. This card does not block current market-rate storage, reporting-currency selection, net-worth estimation or the current Al Dar Salary/budget quote. Retain it as unscheduled historical capability only if the user later chooses that outcome.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No current historical-FX product requirement after UD-10. Reopen only if the user later explicitly requests historical conversion and names its required period/purpose.

**Smallest proposed boundary:** Defer historical conversion and paid historical data; current net-worth estimates do not depend on this card.

**Decision record:** [GENERAL_FX_ARCHITECTURE_PACKET](#packet-general-fx-architecture-packet), [ROADMAP_REPLANNING_PACKET_99](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-99>).

**Settled user direction:** UD-08, UD-09, UD-10; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_REPOSITORY: valid_at capacity is not a implemented historical-rate contract. Prior provider discovery qualified a current QAR snapshot only.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. No backdating observations, silently carrying current rates backward, invented market-day values or remittance quotes.

**First-round question/options:** Can current-rate observations provide historical conversion? A current-value view can clearly use a current snapshot; an as-of historical view requires date-specific evidence and cannot substitute latest data.

**First-round remainder and implications:** An accepted source for historical/effective-date rates, market-day/gap policy, as-of vs contemporaneous view definition and historical derivation version. Historical FX ADR and possibly immutable snapshot/version storage.

**First-round proposed acceptance/falsifier:** Compare independently dated source legs and exact source-effective-time coverage; missing dates stay unavailable. Preserve native Money exactly. Preserve rate/valuation observations at their independently evidenced Decimal scale; apply only the approved final derived-Money rounding/version rule. Future checks use the exact locale, as-of, membership and conversion boundary above; prove provider persistence/reopen parity only where that boundary persists state. Missing genuine financial evidence remains uncertified, never manufactured. Different date conventions, revised historical data or missing quote days invalidate an assumed complete history.

**Supersession:** any earlier route, broad Al Dar use, combined historical scope or 2021 requirement in this dated first-round evidence is historical only. UD-08/09/10 and the current boundary above govern.

**Second-round new evidence/resolved direction:** UD-10 selects current net-worth estimates only and supersedes historical/2021 requirements. Current direct market INR→USD and QAR→USD observations are acquired; Al Dar remains solely current Salary/budget under UD-09.

**Exact next evidence or decision:** No current historical-FX product requirement after UD-10. Reopen only if the user later explicitly requests historical conversion and names its required period/purpose.

**Personal-v1:** POST_V1

**Recommendation after Chat:** Preserve current queue priority/status and record DEFERRED_WITH_REASON by UD-10; no historical implementation selected. **Roadmap:** Retain numbering. Current market net-worth estimation is the Sprint99 proposal; Al Dar is current Salary/budget only with manual override. Historical FX is deferred under UD-10.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, EXTERNAL_DATA_SEMANTICS, PROVIDER_PERMISSION, NO_REAL_USE_CASE.

**Typed dependencies:**

- None; execution still requires a Chat-approved prompt.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

---

<a id="fw-p3-33"></a>

## FW-P3-33 — User-Selectable Reporting Currency
**Status:** Blocked
**Depends on:** `FW-P3-31` current market evidence plus Chat-approved current reporting-currency, membership/rounding and workspace financial-setting semantics

Provide a current net-worth estimate in the selected reporting currency without rewriting native amounts. Direct INR→USD/QAR→USD observations are available; Chat must define the exact selected output currencies and any reciprocal orientation over the same current evidence before implementation. Historical FX is not a dependency under UD-10. Appearance preferences are separate nonfinancial settings; Al Dar remains solely current Salary/budget estimation under UD-09.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** Chat must accept current net-worth membership/rounding, selected reporting-currency set and explicit direction/inverse rule over current market observations, plus financial setting ownership.

**Smallest proposed boundary:** A workspace financial reporting setting chooses a derived projection over unchanged native facts and immutable observations; it is separate from portable appearance preferences.

**Decision record:** [GENERAL_FX_ARCHITECTURE_PACKET](#packet-general-fx-architecture-packet), [ROADMAP_REPLANNING_PACKET_99](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-99>).

**Settled user direction:** UD-08, UD-09, UD-10; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_REPOSITORY: native grouping remains current behavior. A UI-selected currency would not supply valuation dates or rate provenance.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. No persisted native-money rewrite, display-only rate being treated as booked economics, or implicit Al Dar.

**First-round question/options:** What does a reporting-currency preference control? Choose current-only reporting as an explicitly approved narrower contract or retain historical dependency; do not silently remove FW-P3-32 from the existing queue.

**First-round remainder and implications:** Accepted current/as-of reporting semantics, supported currencies, rounding/aggregation order and preference ownership. Derived-reporting ADR; preference storage owner and optional derived snapshots only after approval.

**First-round proposed acceptance/falsifier:** Switch currency and relaunch without changing native bytes; independent per-line and aggregate rounding checks; missing components remain explicit. Preserve native Money exactly. Preserve rate/valuation observations at their independently evidenced Decimal scale; apply only the approved final derived-Money rounding/version rule. Future checks use the exact locale, as-of, membership and conversion boundary above; prove provider persistence/reopen parity only where that boundary persists state. Missing genuine financial evidence remains uncertified, never manufactured. A preference affecting imported values, mixing current/historical dates or changing denominator membership invalidates the design.

**Supersession:** any earlier route, broad Al Dar use, combined historical scope or 2021 requirement in this dated first-round evidence is historical only. UD-08/09/10 and the current boundary above govern.

**Second-round new evidence/resolved direction:** UD-10 selects current net-worth estimates only and supersedes historical/2021 requirements. Current direct market INR→USD and QAR→USD observations are acquired; Al Dar remains solely current Salary/budget under UD-09.

**Exact next evidence or decision:** Chat must accept current net-worth membership/rounding, selected reporting-currency set and explicit direction/inverse rule over current market observations, plus financial setting ownership.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Blocked until the exact evidence/architecture gates are accepted; discovery closure is READY_FOR_CHAT_ARCHITECTURE_DECISION. **Roadmap:** Retain numbering. Current market net-worth estimation is the Sprint99 proposal; Al Dar is current Salary/budget only with manual override. Historical FX is deferred under UD-10.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-31`: Current-scope gate under UD-09/10: FW-P3-31 must satisfy its separately stated identity/source/architecture/implementation boundary. No historical FX dependency.
- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-reporting-projection`: Current-scope gate under UD-09/10: decision-reporting-projection must satisfy its separately stated identity/source/architecture/implementation boundary. No historical FX dependency.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

---

<a id="fw-p3-34"></a>

## FW-P3-34 — Currency-Aware Analytics and Net Worth
**Status:** Blocked
**Depends on:** complete adopted current asset/liability/holding membership, current native valuations, and approved current market reporting under `FW-P3-31`/`FW-P3-33`

Current net worth must identify each included native component, its current balance or owned-unit/price basis, exact market-rate observation, source/fetch time and missing/stale status. No missing component becomes zero; incomplete totals remain explicitly incomplete. Historical analytics and historical FX are not prerequisites merely because future analytics is broad. Al Dar Salary estimates do not enter portfolio/reporting totals.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** Accepted genuine current asset/liability/holding membership, prices and current market FX/reporting basis are missing; no historical FX dependency remains.

**Smallest proposed boundary:** Native components and valuation dates plus direct market USD FX observations, missing/stale/completeness state; current Salary Al Dar estimate excluded from portfolio/reporting totals.

**WB5 — reused private workflow observation, 2026-09-10:** workbook totals combine costs, current values and cash across converted categories. They are workflow calculations, not an independent current net-worth or historical-FX oracle. No private values or raw workbook extracts are retained in this document.

**Decision record:** [GENERAL_FX_ARCHITECTURE_PACKET](#packet-general-fx-architecture-packet), [ROADMAP_REPLANNING_PACKET_99](<Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md#packet-roadmap-replanning-packet-99>).

**Settled user direction:** UD-08, UD-09, UD-10; see the [chronology](#explicit-user-decision-chronology), with latest scope governing.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: AccountType.investment and optional base-currency fields exist, but the inspected repository interfaces contain no holding/security/lot or reference-rate service. The exchange_rates table is historical schema capacity, not an implemented FX product. Money rejects excess currency precision. VERIFIED_LOCAL: workbook G46:H47 converts totals through present spreadsheet reference formulas, including retired haircuts. Those computed totals are historical workflow evidence, not a LedgerForge financial oracle.

**First-round scope and constraints:** ADR-008/033 preserve native Money and require separately approved derived rounding/conversion. ADR-046 governs every statement-dependent path. Source/user holding facts, external observations and derived values have separate authority; no invented units, cost, identifiers, price dates or history. All recommendations here are PROPOSED. No zero substitute, interpolated unobserved history, mixed dates labelled one as-of result or deprecated workbook haircuts.

**First-round question/options:** When is currency-aware analytics/net worth meaningful? Complete native-currency reports can precede a mixed-currency view; a single total needs all component dates and values to be acceptable.

**First-round remainder and implications:** Accepted analytics/holding membership, valuation and rate as-of policy, missing-data aggregation and independent reconciliation scope. Derived-finance ADR; persist only approved source observations/versions, not redundant derived truth.

**First-round proposed acceptance/falsifier:** Independent genuine-source membership and arithmetic oracle, including liabilities/transfers; incomplete/stale components must be visible and reproducible. Preserve native Money exactly. Preserve rate/valuation observations at their independently evidenced Decimal scale; apply only the approved final derived-Money rounding/version rule. Future checks use the exact locale, as-of, membership and conversion boundary above; prove provider persistence/reopen parity only where that boundary persists state. Missing genuine financial evidence remains uncertified, never manufactured. A missing asset/liability, overlapping ownership or inconsistent date basis invalidates a complete total.

**Supersession:** any earlier route, broad Al Dar use, combined historical scope or 2021 requirement in this dated first-round evidence is historical only. UD-08/09/10 and the current boundary above govern.

**Second-round new evidence/resolved direction:** UD-10 selects current net-worth estimates only and supersedes historical/2021 requirements. Current direct market INR→USD and QAR→USD observations are acquired; Al Dar remains solely current Salary/budget under UD-09.

**Exact next evidence or decision:** Accepted genuine current asset/liability/holding membership, prices and current market FX/reporting basis are missing; no historical FX dependency remains.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** Preserve Blocked until the exact evidence/architecture gates are accepted; discovery closure is READY_AFTER_NAMED_DEPENDENCY. **Roadmap:** Retain numbering. Current market net-worth estimation is the Sprint99 proposal; Al Dar is current Salary/budget only with manual override. Historical FX is deferred under UD-10.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** Selected source/identity/permission/date contract changes; Any inferred ownership, cost, date, history, conversion direction or missing value; Exact post-Sprint-87 provider/migration/hydrator/actor ownership before implementation.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=false. **Blocker types:** FINANCIAL_SEMANTICS, PROVENANCE, DEPENDENCY, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-26`: Current-scope gate under UD-09/10: FW-P3-26 must satisfy its separately stated identity/source/architecture/implementation boundary. No historical FX dependency.
- `REQUIRES_IMPLEMENTATION` → `FW-P3-33`: Current-scope gate under UD-09/10: FW-P3-33 must satisfy its separately stated identity/source/architecture/implementation boundary. No historical FX dependency.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: Refresh only affected provider/migration/hydration/actor interfaces before planning or implementation; public source facts stay valid independently.

**Pinned evidence references:**

- [Models/Account.swift](<../Models/Account.swift>):10-60 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Models/Account.swift](<../Models/Account.swift>):10-60 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift](<../Models/Money.swift>):258-304 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Migrations.swift](<../Database/Migrations.swift>):233-248 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Project documents/ADR.md](<ADR.md>):269-294;2178-2395;5680-5710;5920-6090 at `af2d1949c6e9a73af3bb004422b72882d28195e2`; SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

</details>

---

<a id="fw-p3-35"></a>

## FW-P3-35 — Structured Data Export

**Status:** Candidate
**Depends on:** Export schema and privacy policy

Provide a machine-readable export of supported LedgerForge domain data. User-facing report and selected-view exports remain governed by `FW-P3-17`.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** Exact user says complete export optional; retain optional schema packet.

**Smallest proposed boundary:** Not a personal-v1 blocker.

**Decision record:** [EXPORT_BOUNDARY_PACKET](#packet-export-boundary-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: repositories/hydration cover accounts, transactions, categories, import attempts and sessions, card and salary/funding domains. A single transactions CSV omits supported relationships and provenance; a SQLite file exposes internal schema rather than a stable public domain contract.

**First-round scope and constraints:** The app remains private, local and explicit. Accepted financial history, native Money, order, multiplicity and provenance cannot be silently rewritten. ADR-046 authentic-input rules apply to financial cases; migration identities remain append-only. Discovery grants no implementation or acceptance. No raw original financial documents, credentials or runtime caches by implication; no promise to reimport or expose internal mutable DTOs as public API.

**First-round question/options:** What is a loss-aware machine-readable domain export? A versioned logical package can describe omissions and preserve domain meaning; database backup is a separate whole-storage recovery mechanism.

**First-round remainder and implications:** Explicit exported entity/relationship scope, redacted vs complete private export policy, format/version contract and whether future round-trip import is promised. Public export schema decision required; exporting accepted records should not require database migration unless a missing durable relationship is independently found.

**First-round proposed acceptance/falsifier:** Independent counts and relationship closure for every adopted domain; exact Money/Decimal/date round-trip decoding and reproducible ordering; detect omission, orphaned identity or unsupported export version; privacy review of artifact, destination and temporary residue. New accepted domain/mutation/provenance fields invalidate completeness until export schema is reconciled.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: repositories/hydration cover accounts, transactions, categories, import attempts and sessions, card and salary/funding domains. A single transactions CSV omits supported relationships and provenance; a SQLite file exposes internal schema rather than a stable public domain contract. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Exact user says complete export optional; retain optional schema packet. Owning authority: EXPORT_BOUNDARY_PACKET.

**Personal-v1:** PRE_V1_OPTIONAL

**Recommendation after Chat:** DEFERRED_WITH_REASON **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `decision-complete-export`: Future reopening condition only; this deferred boundary is not a current prerequisite. Unselected future scope only; no current user decision is pending for the deferred boundary.

**Pinned evidence references:**

- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Services/RepositoryStoreHydrator.swift](<../Services/RepositoryStoreHydrator.swift>):209-269;344-440 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `40cbd69a8a470748fcb637cb10ae5597855d5a03771e165d8f551162d2b94117` — RepositoryStoreHydrator.init(workspaceId:); stageHydration()
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):2652-2661;3047-3056 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — Report and structured export are distinct unresolved contracts.

</details>

<a id="packet-export-boundary-packet"></a>

<details>
<summary>EXPORT_BOUNDARY_PACKET — complete proposed decision packet</summary>

## EXPORT_BOUNDARY_PACKET

| # | Required field | Decision |
| --- | --- | --- |
| 1 | Owning FW IDs | FW-P3-35; FW-P3-17 is separate optional selected-view report. |
| 2 | User problem | Portability without presenting a backup or authentic institution statement. |
| 3 | Verified current state | Hydrated domains exist; CSV is relationally lossy and raw SQLite is not public contract. |
| 4 | Accepted authorities | ADR-024 and ADR-046; current private-data restrictions. |
| 5 | Exact missing decision | Full public schema/privacy policy; user marks complete export optional for v1. |
| 6 | Evidence acquired | Repositories/hydration span accounts, transactions, categories, attempts/sessions, card and salary/funding. |
| 7 | Options considered | Selected report; raw SQLite; versioned full-domain projection; round-trip workspace. |
| 8 | Recommended option | Keep versioned one-way full-domain export optional; if selected, user destination plus deterministic manifest/entity projection. |
| 9 | Why competing options are rejected | Report loses relations; SQLite couples internal schema; round-trip is workspace/restore architecture. |
| 10 | Smallest coherent implementation boundary | Explicit entity/relations, stable exported IDs, exact native Money/decimal/currency, dates, order/multiplicity, bounded provenance and omissions manifest. |
| 11 | Included scope | Schema version, compatible-reader rule, entity counts/closure, deterministic order, atomic output, private user projection. |
| 12 | Explicit exclusions | Credentials, Keychain, original bytes/attachments, parser artifacts, DB paths, diagnostics, auto reimport, source authority, backup/restore. |
| 13 | Durable model/persistence requirements | Read-only export, no history; manifest has format/producer/compatibility/omissions. |
| 14 | Migration impact | NONE unless separately proven durable relation missing. |
| 15 | ADR impact | NEW_ADR_REQUIRED only when optional feature selected. |
| 16 | Privacy/security boundary | Explicit destination, cancel no final artifact, spreadsheet-safe text, no upload/cloud. |
| 17 | SQLite/In-Memory implications | Projection honors repository parity but exposes no provider schema. |
| 18 | Hydration/relaunch implications | Reads one canonical generation/snapshot; no mutation or store replacement. |
| 19 | Independent acceptance oracle | Independent counts, relation closure, exact Money/date decode/order, omissions/unknown-version behavior. |
| 20 | Failure cases | Destination/cancel/temp residue, stale generation, unavailable repo, orphan, malformed native value/date, unknown version. |
| 21 | Reversal/correction semantics | Read-only one-way artifact; filesystem deletion has no ledger effect. |
| 22 | Source evidence requirement | Authentic sources only for financial/provenance meaning; exported bytes never authentic source truth. |
| 23 | Runtime acceptance requirement | Required native destination/cancel/atomic-residue; projection oracle static/testable. |
| 24 | Dependencies | User optional decision; schema/privacy ADR if later selected; FW-P3-36 distinction. |
| 25 | Evidence that falsifies the recommendation | Required relation cannot be represented or export leaks content/is treated as source. |
| 26 | Personal-v1 relevance | PRE_V1_OPTIONAL by exact user decision. |
| 27 | Recommended FUTURE_WORK status after Chat review | DEFERRED_WITH_REASON until user selects; then READY_FOR_CHAT_ARCHITECTURE_DECISION. |
| 28 | Recommended roadmap effect after Chat review | Preserve queue; no portability/API/sync commitment. |

</details>

---

<a id="fw-p3-36"></a>

## FW-P3-36 — Verified Backup, Restore and Disaster Recovery

**Status:** Ready for discovery
**Shared prerequisites:** Canonical database lifecycle, checked close, coordinated SQLite/WAL/SHM handling, DEBUG lifecycle backup, migration-chain integrity and fail-closed recovery foundations exist.
**Implementation dependency:** Approval of the user-facing backup contents, integrity, restore-target, compatibility and confirmation contract.

This is a serious required recoverability input to `FW-P0-26` personal-v1 certification, but importance does not itself promote implementation priority.

Provide explicit user-owned local backup creation, integrity verification, documented contents/exclusions, restore preview/confirmation, safe-target restoration, version/schema compatibility checks, failure-safe recovery and disaster-recovery guidance.

Discovery must distinguish the existing DEBUG lifecycle backup from a production user-owned backup product and ensure restore cannot overwrite unique/newer data without explicit review. A copied file alone is not a trustworthy backup or restore drill.

**Current discovery disposition — 2026-09-10:** `READY_FOR_CHAT_ARCHITECTURE_DECISION`. **Exact remaining gate:** User requires recovery; accept package/restore/rollback ADR.

**Smallest proposed boundary:** User-owned verified package; isolated restore; nonempty target protection.

**External authority distinction:** [SQLite online backup](https://www.sqlite.org/backup.html) and [WAL documentation](https://www.sqlite.org/wal.html) distinguish a consistent snapshot from copying a live database into arbitrary sync software. A backup, portable package, synchronization protocol and restored workspace each require their own accepted boundary.

**Decision record:** [USER_BACKUP_RESTORE_ARCHITECTURE_PACKET](#packet-user-backup-restore-architecture-packet), [PERSONAL_V1_CERTIFICATION_PACKET](#packet-personal-v1-certification-packet).

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: SQLiteDatabase uses the online backup API and checked checkpoint/close exists. DEBUG createAndVerifyBackup checks authorized target, migration chain, identifier schema and required tables. It does not establish a user-facing contents manifest, complete integrity guarantee or safe arbitrary restore target.

**First-round scope and constraints:** The app remains private, local and explicit. Accepted financial history, native Money, order, multiplicity and provenance cannot be silently rewritten. ADR-046 authentic-input rules apply to financial cases; migration identities remain append-only. Discovery grants no implementation or acceptance. No live-file-only copy, same-file restore, overwrite of unique/newer data without review, automatic schema downgrade/repair or assuming DEBUG backup equals product recovery. Credential and retained-source inclusion remain explicit decisions.

**First-round question/options:** How does user-owned backup differ from DEBUG lifecycle backup? A consistent SQLite snapshot can serve one local workspace without exporting credentials; restoring into a new isolated target is easier to verify than replacing an open active database.

**First-round remainder and implications:** Approved contents/exclusions, backup identity/digest and integrity depth, supported versions, safe restore target, explicit replacement confirmation and recovery instructions. An independent user restore drill is absent. Backup/restore lifecycle and privacy architecture decision needed. No migration solely for snapshotting; a manifest format needs its own version policy, no migration number allocated.

**First-round proposed acceptance/falsifier:** Independently verify manifest digest, migration identity, SQLite integrity and required relationship/semantic scope; restore in isolation, compare genuine source-backed counts/identities/Money/provenance, close/reopen/hydrate, and prove interruptions/cancellation/corruption preserve originals and fail closed. Schema/provider/lifecycle change, unaccounted retained data, cross-device credential dependency or snapshot concurrency behavior changes invalidate design.

**Second-round new evidence/resolved direction:** Static distinction between DEBUG lifecycle snapshot and user recovery; exact user requirement.

**Exact next evidence or decision:** Exact next evidence/decision: User requires recovery; accept package/restore/rollback ADR. Owning authority: USER_BACKUP_RESTORE_ARCHITECTURE_PACKET, PERSONAL_V1_CERTIFICATION_PACKET.

**Personal-v1:** PRE_V1_REQUIRED

**Recommendation after Chat:** READY_FOR_CHAT_ARCHITECTURE_DECISION **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `WAIT_POST_SWIFT6` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. The accepted Sprint-84 delta does not establish the remaining post-87 ownership/runtime gate.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=true, post-87 refresh=true, authentic source=true. **Blocker types:** ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `decision-user-backup-adr`: The explicitly named gate decision-user-backup-adr must be satisfied. This enables User-owned verified package; isolated restore; nonempty target protection. Remaining condition: User requires recovery; accept package/restore/rollback ADR.
- `REQUIRES_POST_SWIFT6` → `accepted-post-sprint-87-ownership`: User backup/restore uses the provider/lifecycle/hydrator interfaces owned by Sprints 84–87.
- `REQUIRES_AUTHENTIC_SOURCE` → `source-backup-financial-projection`: Financial restore drill requires authentic source-backed records and independent projection; source-independent package checks do not certify financial preservation.

**Pinned evidence references:**

- [Database/SQLiteDatabase.swift](<../Database/SQLiteDatabase.swift>):109-146 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `5945852ad75513a1fcbd15c692512ab35786523da9defd889b9d4f7f710b474a` — createBackup; checkpointAndClose
- [Database/SQLiteRepositoryProvider.swift](<../Database/SQLiteRepositoryProvider.swift>):1381-1450;1540-1591 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `29166a1e985c9c4f5b43e6d13243a82fa5ff5e94382747b3fb406ae0dc98b454` — createAndVerifyBackup; restorePersistentDebugBackup
- [LedgerForgeTests/MigrationChainIntegrityTests.swift](<../LedgerForgeTests/MigrationChainIntegrityTests.swift>):253-367 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `6ad68d2dd32d041fe1224e644c3d067d3539ecfb63dd53793560e22f3d854688` — empty historical prefixes and fail-closed history tests
- [LedgerForgeTests/MigrationIdentityLockTests.swift](<../LedgerForgeTests/MigrationIdentityLockTests.swift>):1-52 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `722c49a26a6785be7c4d537973d0a2790fc84b162d310e04ed399e6fdd0fcae9` — independent identity lock and drift detection
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):3061-3075 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — User backup/restore is a separate user-facing contract.
- [Database/SQLiteDatabase.swift](<../Database/SQLiteDatabase.swift>):90-146 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — WAL, SQLite online backup and checked close exist.

</details>

<a id="packet-user-backup-restore-architecture-packet"></a>

<details>
<summary>USER_BACKUP_RESTORE_ARCHITECTURE_PACKET — complete proposed decision packet</summary>

## USER_BACKUP_RESTORE_ARCHITECTURE_PACKET

| # | Required field | Decision |
| --- | --- | --- |
| 1 | Owning FW IDs | FW-P3-36; required predecessor of FW-P0-26; constrains FW-P3-41. |
| 2 | User problem | Recover one local workspace without silently overwriting newer/nonempty current data. |
| 3 | Verified current state | SQLite is WAL-mode and provides online backup plus checked checkpoint/close. DEBUG lifecycle backup/recovery is fixed-identity and Release-absent. |
| 4 | Accepted authorities | ADR-024 hydration, ADR-035 DEBUG lifecycle and Release/arbitrary-restore exclusion, ADR-037 backup is not mutation reversal, ADR-046 provenance. |
| 5 | Exact missing decision | Chat architecture acceptance for a distinct user/Release backup and restore contract; product requirement is now explicit. |
| 6 | Evidence acquired | Online backup API copies the open main DB; checked close truncates WAL; DEBUG verification checks migration history and required tables. |
| 7 | Options considered | Live sqlite/sidecar copy; DEBUG snapshot; immutable user package; portable live folder; export only. |
| 8 | Recommended option | Immutable user backup package at explicit user destination, created with SQLite backup API, verified and restored into an isolated candidate before activation. |
| 9 | Why competing options are rejected | Live copies can miss WAL; DEBUG is not a user product; live portable folders need external locking/conflict rules; exports cannot restore repositories. |
| 10 | Smallest coherent implementation boundary | One workspace, ledger.sqlite, manifest.json, Verify, Restore-to-Isolated-Copy, explicit Activate Restored Copy. |
| 11 | Included scope | Snapshot, versioned manifest, hash/size, migration/schema compatibility, isolated verification, preservation/rollback and recovery guidance; validated appearance-preference snapshot. |
| 12 | Explicit exclusions | Credentials/Keychain, passwords, original attachments/source bytes, DEBUG backup UI, sync, multiworkspace, automatic overwrite, reports/exports and financial undo. |
| 13 | Durable model/persistence requirements | Manifest: package major/minor, build identity, migration identity/checksum inputs, schema state, opaque workspace identity, timestamp, file size/SHA-256, content/exclusion list and preference-schema/version/hash. No paths, financial values, source digests, credentials, names or diagnostics. Atomic final publication after verification only. |
| 14 | Migration impact | REQUIRES_DECISION for package reader compatibility only; no database migration allocated. Unknown/future/incomplete identities reject before activation. |
| 15 | ADR impact | NEW_ADR_REQUIRED; align ADR-035 without widening its DEBUG-only decision. |
| 16 | Privacy/security boundary | Explicit file authorization; no secrets/originals/paths/raw identifiers in metadata or diagnostics. Encryption is FW-P3-43, not implied. |
| 17 | SQLite/In-Memory implications | SQLite-only recovery. In-Memory may test manifest mechanics but cannot prove durable restore. |
| 18 | Hydration/relaunch implications | Candidate runs registered migrations and RepositoryStoreHydrator stage hydration; publish only after success. Activation quiesces work, invalidates generation, checked-closes, preserves canonical set, swaps atomically, hydrates, then same-target relaunches. |
| 19 | Independent acceptance oracle | Manifest hash/size, registered migration identity, SQLite integrity/foreign keys/required schema, plus independent canonical IDs, counts, Money scale/currency, relationships, order/multiplicity and permitted provenance comparison. Genuine source-backed records for financial comparisons. |
| 20 | Failure cases | Cancel/permission/disk/temp artifact; tampered hash/manifest; unsupported migration; active operation/stale generation; nonempty/newer target; candidate SQLite/integrity/hydration failure; interruption before/after activation; failed relaunch. Fail closed and retain originals. |
| 21 | Reversal/correction semantics | Before activation cancel safely. Database restore is whole-workspace recovery, never selective undo. Keep original database set and last verified backup until candidate close/reopen succeeds; activation failure restores preserved original and enters unavailable state if rollback fails. |
| 22 | Source evidence requirement | None for package mechanics; authentic source authority required for financial-projection comparison in restore drill. |
| 23 | Runtime acceptance requirement | Required: native destination selection, cancel/access failure, isolated restore, nonempty-current confirmation, activation/rollback, hydration and same-database relaunch. |
| 24 | Dependencies | User decision satisfied; NEW ADR; exact post-Sprint-87 lifecycle/provider/hydrator review. FW-P0-26 consumes backup acceptance; it is not a backup prerequisite. FW-P3-41 is a later consumer only if portable folders are selected. |
| 25 | Evidence that falsifies the recommendation | No coherent online snapshot; relation/value/provenance cannot survive; metadata exposes prohibited data; nonempty current target cannot be protected/rolled back; or migration cannot be isolated-verified. |
| 26 | Personal-v1 relevance | PRE_V1_REQUIRED by exact user decision on 2026-09-10. |
| 27 | Recommended FUTURE_WORK status after Chat review | READY_FOR_CHAT_ARCHITECTURE_DECISION. |
| 28 | Recommended roadmap effect after Chat review | Record recoverability entry gate; no sprint selection or personal-v1 claim. |

</details>

---

<a id="fw-p3-37"></a>

## FW-P3-37 — Optional Encrypted Sync

**Status:** Research
**Depends on:** Backup, encryption, conflict resolution and explicit opt-in architecture

LedgerForge must remain fully functional without synchronization.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No concrete multi-device/second-writer need.

**Smallest proposed boundary:** Manual verified backup transfer precedes sync.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: provider/hydration are local and workspace-scoped; Keychain source-password storage is non-synchronizing and device-bound. There is no adopted remote replication, conflict or key-recovery contract in these interfaces.

**First-round scope and constraints:** The app remains private, local and explicit. Accepted financial history, native Money, order, multiplicity and provenance cannot be silently rewritten. ADR-046 authentic-input rules apply to financial cases; migration identities remain append-only. Discovery grants no implementation or acceptance. No cloud-account prerequisite, background upload, credential sync, automatic last-writer-wins or reduced offline functionality.

**First-round question/options:** Does optional encrypted sync serve the current single-owner product? User-owned verified backup transfer addresses disaster recovery with less architecture; encrypted multi-writer replication requires domain conflict semantics despite transport encryption.

**First-round remainder and implications:** User need for a second writer/device, sync unit/protocol, authenticated peer trust, conflict authority and portable encryption-key recovery. New sync/trust/key-lifecycle ADRs and likely durable replication metadata; no design selected now.

**First-round proposed acceptance/falsifier:** Future qualification must prove offline operation, replay/idempotence, divergent histories, explicit conflicts, interruption recovery and independent key-loss restore; no silent record merge. A genuine required multi-device workflow or accepted portable workspace boundary warrants reopening this deferral.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: provider/hydration are local and workspace-scoped; Keychain source-password storage is non-synchronizing and device-bound. There is no adopted remote replication, conflict or key-recovery contract in these interfaces. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: No concrete multi-device/second-writer need. Owning authority: FW-P3-37 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** DEFERRED_WITH_REASON **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `FW-P3-36`: Future reopening condition only; this deferred boundary is not a current prerequisite. The Verified Backup, Restore and Disaster Recovery boundary must provide: User-owned verified package; isolated restore; nonempty target protection.. This enables Manual verified backup transfer precedes sync. Remaining condition: No concrete multi-device/second-writer need.
- `OPTIONAL_ENHANCEMENT` → `FW-P3-43`: Future reopening condition only; this deferred boundary is not a current prerequisite. The Local-Data Encryption at Rest boundary must provide: FileVault fact is not exported-backup encryption.. This enables Manual verified backup transfer precedes sync. Remaining condition: No concrete multi-device/second-writer need.

**Pinned evidence references:**

- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Services/RepositoryStoreHydrator.swift](<../Services/RepositoryStoreHydrator.swift>):209-269;344-440 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `40cbd69a8a470748fcb637cb10ae5597855d5a03771e165d8f551162d2b94117` — RepositoryStoreHydrator.init(workspaceId:); stageHydration()
- [Import/Password/DefaultPasswordProvider.swift](<../Import/Password/DefaultPasswordProvider.swift>):37-50;178-214 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `de4f93cdfc8c9fdf2d8cf23d4127f649ae05608be2806964812d00e567b43215` — KeychainCredentialStore attributes
- [Database/SQLiteDatabase.swift](<../Database/SQLiteDatabase.swift>):1-100 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `5945852ad75513a1fcbd15c692512ab35786523da9defd889b9d4f7f710b474a` — SQLite open and WAL configuration
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):3080-3093 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Optional Encrypted Sync as Research and records this unresolved boundary: User need for a second writer/device, sync unit/protocol, authenticated peer trust, conflict authority and portable encryption-key recovery.

</details>

---

<a id="fw-p3-38"></a>

## FW-P3-38 — Open API and External Integrations

**Status:** Research
**Depends on:** Stable public data contracts and security policy

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No named external consumer/use case.

**Smallest proposed boundary:** One-way export before API.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: DatabaseProvider and repository interfaces are app-internal read/write contracts; financial import requires staged validation/confirmation. They do not constitute a versioned public authorization boundary.

**First-round scope and constraints:** The app remains private, local and explicit. Accepted financial history, native Money, order, multiplicity and provenance cannot be silently rewritten. ADR-046 authentic-input rules apply to financial cases; migration identities remain append-only. Discovery grants no implementation or acceptance. No remote server, repository handles, credential access, arbitrary SQL, unattended financial writes or implementation framework.

**First-round question/options:** What external integration can avoid exposing internal repository authority? Versioned user-exported files keep explicit control for occasional consumers; a continuously available service adds authorization, lifecycle and attack surface.

**First-round remainder and implications:** Concrete consumer/use case, minimum read/write scope, privacy consent, authentication and compatibility policy. Public API capability/versioning ADR required; no current database migration justified.

**First-round proposed acceptance/falsifier:** Future consumer contract must reject unknown versions/unauthorized operations, expose only selected data, and leave ledger untouched on any rejection. A named repeated workflow needing unavailable incremental semantics may justify a distinct service contract.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: DatabaseProvider and repository interfaces are app-internal read/write contracts; financial import requires staged validation/confirmation. They do not constitute a versioned public authorization boundary. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: No named external consumer/use case. Owning authority: FW-P3-38 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** DEFERRED_WITH_REASON **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `FW-P3-35`: Future reopening condition only; this deferred boundary is not a current prerequisite. The Structured Data Export boundary must provide: Not a personal-v1 blocker.. This enables One-way export before API. Remaining condition: No named external consumer/use case.

**Pinned evidence references:**

- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Services/RepositoryStoreHydrator.swift](<../Services/RepositoryStoreHydrator.swift>):209-269;344-440 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `40cbd69a8a470748fcb637cb10ae5597855d5a03771e165d8f551162d2b94117` — RepositoryStoreHydrator.init(workspaceId:); stageHydration()
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):3094-3105 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Open API and External Integrations as Research and records this unresolved boundary: Concrete consumer/use case, minimum read/write scope, privacy consent, authentication and compatibility policy.

</details>

---

<a id="fw-p3-39"></a>

## FW-P3-39 — External Import Plugin Architecture

**Status:** Research
**Depends on:** Stable parser/reader, ADR-046 authentic-corpus acceptance, non-source test-data, security and public extension contracts

Investigate an optional plugin architecture for adding financial institutions, document families or import adapters without modifying LedgerForge’s core application.

The design must preserve:

- offline-first operation;
- privacy by default;
- deterministic parsing;
- validation before persistence;
- explicit plugin trust and installation controls;
- compatibility and versioning rules;
- isolation from repository and credential internals.

Internal parser-framework expansion remains governed separately by `FW-P1-06`.

No external plugin system is approved until its security, signing, compatibility and data-access boundaries are defined.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No external adapter producer/use case/trust contract.

**Smallest proposed boundary:** Internal parser framework only.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: internal reader and confirmed-import repository seams are reviewed application code. ADR-046 authentic corpus and ordinary production path govern support; externally supplied executable code would introduce a separate trust boundary.

**First-round scope and constraints:** The app remains private, local and explicit. Accepted financial history, native Money, order, multiplicity and provenance cannot be silently rewritten. ADR-046 authentic-input rules apply to financial cases; migration identities remain append-only. Discovery grants no implementation or acceptance. No repository or Keychain internals, arbitrary plugin-driven persistence, implicit source certification, or synthetic statement/domain graphs under the queue phrase non-source test-data.

**First-round question/options:** Can third-party import plugins inherit internal parser trust? Internal source adapters remain the smaller reviewable route for this single developer; an external protocol might accept bounded immutable evidence but still needs host-side deterministic validation.

**First-round remainder and implications:** Actual external adapter producer/use case; plugin identity/signing/version compatibility; process isolation/resource limits and minimal source/credential capabilities. New plugin trust, compatibility and credential ownership ADRs; migration needs unknown, not allocated.

**First-round proposed acceptance/falsifier:** Future adversarial proof must bound file/network/credential effects, reject incompatible or ambiguous evidence before persistence and rerun each affected complete authentic corpus through ordinary host validation. Untrusted code requiring broad file access or irreversible effects invalidates a minimal in-process plugin assumption.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: internal reader and confirmed-import repository seams are reviewed application code. ADR-046 authentic corpus and ordinary production path govern support; externally supplied executable code would introduce a separate trust boundary. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: No external adapter producer/use case/trust contract. Owning authority: FW-P3-39 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** DEFERRED_WITH_REASON **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `accepted-adr-046`: Future reopening condition only; this deferred boundary is not a current prerequisite. The explicitly named gate accepted-adr-046 must be satisfied. This enables Internal parser framework only. Remaining condition: No external adapter producer/use case/trust contract.

**Pinned evidence references:**

- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Services/RepositoryStoreHydrator.swift](<../Services/RepositoryStoreHydrator.swift>):209-269;344-440 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `40cbd69a8a470748fcb637cb10ae5597855d5a03771e165d8f551162d2b94117` — RepositoryStoreHydrator.init(workspaceId:); stageHydration()
- [Import/Readers/DefaultReaderRegistry.swift](<../Import/Readers/DefaultReaderRegistry.swift>):1-31 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `987d6cee9a010d2d72ca73b047d743e45f1c36eef5e72f65b5d76d44cd51f051` — default reader composition
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):3106-3133 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines External Import Plugin Architecture as Research and records this unresolved boundary: Actual external adapter producer/use case; plugin identity/signing/version compatibility; process isolation/resource limits and minimal source/credential capabilities.

</details>

---

<a id="fw-p3-40"></a>

## FW-P3-40 — Multiple Workspaces and Independent Ledgers

**Status:** Research
**Depends on:** Workspace-scoped identity, fingerprint, settings and repository-isolation decisions

Investigate support for more than one independent local financial workspace.

The design must define:

- strict data isolation;
- workspace-scoped account identity;
- workspace-scoped preferences;
- workspace selection and creation;
- import routing;
- fingerprint uniqueness;
- backup and restore boundaries;
- deletion and archival;
- migration from the current single-workspace product model.

No cross-workspace matching or aggregation may occur implicitly.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Whether multiple workspaces are a product need; storage/isolation options remain unselected.

**Smallest proposed boundary:** Do not infer from workspaceId.

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P3-40 | **User product choice:** whether multiple independent ledgers are needed. | It determines workspace isolation, routing, duplicates, credentials, preferences, backups, and migration. | Keep single workspace. | Adopt multi-workspace then choose database-per-workspace/shared architecture in Chat. | — | A; no stated second-ledger workflow. | Single workspace remains. | Isolation map and architecture if B selected. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: hydrator accepts workspaceId but defaults to default-workspace. V9 drops the initial global fingerprint unique indexes in favor of per-document authority and nonunique lookup; application import routing remains part of scope. These mechanisms do not prove complete workspace isolation.

**First-round scope and constraints:** The app remains private, local and explicit. Accepted financial history, native Money, order, multiplicity and provenance cannot be silently rewritten. ADR-046 authentic-input rules apply to financial cases; migration identities remain append-only. Discovery grants no implementation or acceptance. No implicit cross-workspace merge/aggregation, hidden copied credentials or editing accepted migrations.

**First-round question/options:** Does workspace_id establish multiple independent ledgers? Database-per-workspace simplifies physical backup isolation but still needs secure lifecycle/credential routing; shared tables require every query, relationship and uniqueness boundary to enforce workspace scope.

**First-round remainder and implications:** Single database vs database-per-workspace, explicit selection/routing, credential/settings scope, duplicate policy and migration from the current single workspace. Workspace ownership/isolation ADR and likely additive migration if shared schema changes; no option selected.

**First-round proposed acceptance/falsifier:** Independent two-workspace audit must show no cross-returned data, wrong-target import, duplicate leakage, preference bleed or backup/restore crossover; use genuine financial inputs only for statement-dependent checks. A global query/key/cache or active-task switch not scoped to the selected workspace invalidates isolation.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: hydrator accepts workspaceId but defaults to default-workspace. V9 drops the initial global fingerprint unique indexes in favor of per-document authority and nonunique lookup; application import routing remains part of scope. These mechanisms do not prove complete workspace isolation. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Whether multiple workspaces are a product need; storage/isolation options remain unselected. Owning authority: FW-P3-40 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** BLOCKED_ON_PRODUCT_DECISION **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=true, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** USER_PRODUCT_DECISION.

**Typed dependencies:**

- `REQUIRES_USER_DECISION` → `decision-multiworkspace`: The explicitly named gate decision-multiworkspace must be satisfied. This enables Do not infer from workspaceId. Remaining condition: Whether multiple workspaces are a product need; storage/isolation options remain unselected.

**Pinned evidence references:**

- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Services/RepositoryStoreHydrator.swift](<../Services/RepositoryStoreHydrator.swift>):209-269;344-440 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `40cbd69a8a470748fcb637cb10ae5597855d5a03771e165d8f551162d2b94117` — RepositoryStoreHydrator.init(workspaceId:); stageHydration()
- [Database/Migrations.swift](<../Database/Migrations.swift>):556-576;661-674 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — V9 fingerprint indexes; workspace-scoped tables
- [Services/ImportPersistenceCoordinator.swift](<../Services/ImportPersistenceCoordinator.swift>):1377-1480;1850-1875 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `052b8de5c2de61349a5151d676e1dade3ec005363fb82f4eed290822bea2cfae` — workspace-scoped import ownership
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):3134-3161 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Multiple Workspaces and Independent Ledgers as Research and records this unresolved boundary: Single database vs database-per-workspace, explicit selection/routing, credential/settings scope, duplicate policy and migration from the current single workspace.

</details>

---

<a id="fw-p3-41"></a>

## FW-P3-41 — Portable Workspace Folder

**Status:** Research
**Depends on:** `FW-P3-36`, workspace isolation and safe coordination of external file changes

Investigate storing or exporting a complete LedgerForge workspace in a user-selected local folder that may itself be synchronized by services such as iCloud Drive, OneDrive, Dropbox or Synology tools.

LedgerForge must remain offline-first and must not depend on any cloud provider.

The design must address:

- atomic local writes;
- conflict detection;
- concurrent external modifications;
- locking;
- backup and recovery;
- file permissions;
- sandbox access;
- explicit user control.

**Current discovery disposition — 2026-09-10:** `READY_AFTER_NAMED_DEPENDENCY`. **Exact remaining gate:** User backup ADR and later explicit external-folder/open policy.

**Smallest proposed boundary:** Immutable verified package first, no live cloud database.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: SQLite opens with WAL and lifecycle-coordinated backup/close. VERIFIED_EXTERNAL: SQLite documents WAL as part of persistent state and shared-memory WAL coordination on one host. A cloud-synchronized folder is not an accepted multi-device locking protocol.

**First-round scope and constraints:** The app remains private, local and explicit. Accepted financial history, native Money, order, multiplicity and provenance cannot be silently rewritten. ADR-046 authentic-input rules apply to financial cases; migration identities remain append-only. Discovery grants no implementation or acceptance. No live WAL/SHM copying assumptions, silent conflict-copy selection, generic cloud-provider support or cross-device file-lock claims.

**First-round question/options:** Can a portable folder safely carry a LedgerForge workspace? A closed verified backup package transferred by the owner has a smaller boundary; an actively opened DB inside arbitrary sync tooling needs a proven external-writer protocol.

**First-round remainder and implications:** Package format, closed-vs-live workspace policy, external-change detection, access/bookmark lifecycle and conflict/restore behavior. Portable package/access/lifecycle ADR after backup contract; no migration simply to package bytes.

**First-round proposed acceptance/falsifier:** Verify complete contents and digest after transfer, independently restore/relaunch, and fail closed on partial/conflicting/external modifications without losing either copy. Accepted requirement for live external editing or simultaneous devices invalidates the immutable-transfer proposal.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: SQLite opens with WAL and lifecycle-coordinated backup/close. VERIFIED_EXTERNAL: SQLite documents WAL as part of persistent state and shared-memory WAL coordination on one host. A cloud-synchronized folder is not an accepted multi-device locking protocol. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: User backup ADR and later explicit external-folder/open policy. Owning authority: FW-P3-41 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** READY_AFTER_NAMED_DEPENDENCY **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** DEPENDENCY.

**Typed dependencies:**

- `REQUIRES_IMPLEMENTATION` → `FW-P3-36`: The Verified Backup, Restore and Disaster Recovery boundary must provide: User-owned verified package; isolated restore; nonempty target protection.. This enables Immutable verified package first, no live cloud database. Remaining condition: User backup ADR and later explicit external-folder/open policy.
- `OPTIONAL_ENHANCEMENT` → `FW-P3-40`: The Multiple Workspaces and Independent Ledgers boundary must provide: Do not infer from workspaceId.. This enables Immutable verified package first, no live cloud database. Remaining condition: User backup ADR and later explicit external-folder/open policy.

**Pinned evidence references:**

- [Database/SQLiteDatabase.swift](<../Database/SQLiteDatabase.swift>):109-146 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `5945852ad75513a1fcbd15c692512ab35786523da9defd889b9d4f7f710b474a` — createBackup; checkpointAndClose
- [Database/SQLiteRepositoryProvider.swift](<../Database/SQLiteRepositoryProvider.swift>):1381-1450;1540-1591 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `29166a1e985c9c4f5b43e6d13243a82fa5ff5e94382747b3fb406ae0dc98b454` — createAndVerifyBackup; restorePersistentDebugBackup
- [Import/Password/DefaultPasswordProvider.swift](<../Import/Password/DefaultPasswordProvider.swift>):37-50;178-214 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `de4f93cdfc8c9fdf2d8cf23d4127f649ae05608be2806964812d00e567b43215` — KeychainCredentialStore attributes
- [Database/SQLiteDatabase.swift](<../Database/SQLiteDatabase.swift>):1-100 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `5945852ad75513a1fcbd15c692512ab35786523da9defd889b9d4f7f710b474a` — SQLite open and WAL configuration
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):3162-3188 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Portable Workspace Folder as Research and records this unresolved boundary: Package format, closed-vs-live workspace policy, external-change detection, access/bookmark lifecycle and conflict/restore behavior.

</details>

---

<a id="fw-p3-42"></a>

## FW-P3-42 — Cross-Platform Desktop Strategy

**Status:** Research
**Depends on:** Stable public domain, persistence and presentation boundaries

Evaluate whether LedgerForge should eventually support Windows or Linux while preserving macOS as the primary product.

The research must distinguish:

- reusable domain and repository layers;
- Swift and SwiftUI platform constraints;
- storage and Keychain equivalents;
- native desktop interaction expectations;
- testing and release cost;
- whether a separate client or shared core is justified.

No portability claim may be made without an approved architecture and working evidence.

**Current discovery disposition — 2026-09-10:** `DEFERRED_WITH_REASON`. **Exact remaining gate:** No target-user/platform need or support/release capacity.

**Smallest proposed boundary:** No shared-core redesign.

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: SwiftUI owns app/root presentation; source password storage imports Security; repository/domain layers are separated but intertwined with native lifecycle. This is evidence for assessing seams, not proof that a shared core builds elsewhere.

**First-round scope and constraints:** The app remains private, local and explicit. Accepted financial history, native Money, order, multiplicity and provenance cannot be silently rewritten. ADR-046 authentic-input rules apply to financial cases; migration identities remain append-only. Discovery grants no implementation or acceptance. No framework replacement, portability claim from target metadata, cross-platform DB copy promise or distraction from personal-v1.

**First-round question/options:** Is a Windows/Linux port justified by the current product boundary? Retain native macOS delivery for the current owner; later compare a shared domain core with independent native clients against the cost of a rewrite after requirements exist.

**First-round remainder and implications:** An actual target-user/platform need, native UI and credential equivalents, toolchain/support matrix and release/validation capacity. Platform/credential/distribution ADRs required; migrations should remain portable only if future evidence proves it.

**First-round proposed acceptance/falsifier:** Future working evidence must cover equivalent native-money semantics, durable upgrade/hydration, credential isolation and native keyboard/accessibility expectations on each adopted platform. A real required second-platform user or platform-independent core evidence reopens the cost comparison.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: SwiftUI owns app/root presentation; source password storage imports Security; repository/domain layers are separated but intertwined with native lifecycle. This is evidence for assessing seams, not proof that a shared core builds elsewhere. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: No target-user/platform need or support/release capacity. Owning authority: FW-P3-42 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** DEFERRED_WITH_REASON **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=false, Chat architecture=false, post-87 refresh=false, authentic source=false. **Blocker types:** NO_REAL_USE_CASE.

**Typed dependencies:**

- `OPTIONAL_ENHANCEMENT` → `decision-platform`: Future reopening condition only; this deferred boundary is not a current prerequisite. Unselected future scope only; no current user decision is pending for the deferred boundary.

**Pinned evidence references:**

- [Database/Repository.swift](<../Database/Repository.swift>):201-340 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Services/RepositoryStoreHydrator.swift](<../Services/RepositoryStoreHydrator.swift>):209-269;344-440 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `40cbd69a8a470748fcb637cb10ae5597855d5a03771e165d8f551162d2b94117` — RepositoryStoreHydrator.init(workspaceId:); stageHydration()
- [LedgerForgeApp.swift](<../LedgerForgeApp.swift>):1-40 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `325b5d3cc8d7f32dbb11efb815cd7d82be3b9a79f069fb8434aa4b83fde47185` — SwiftUI app entry
- [Import/Password/DefaultPasswordProvider.swift](<../Import/Password/DefaultPasswordProvider.swift>):37-50;178-214 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `de4f93cdfc8c9fdf2d8cf23d4127f649ae05608be2806964812d00e567b43215` — KeychainCredentialStore attributes
- [Database/SQLiteDatabase.swift](<../Database/SQLiteDatabase.swift>):1-100 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `5945852ad75513a1fcbd15c692512ab35786523da9defd889b9d4f7f710b474a` — SQLite open and WAL configuration
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):3189-3213 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Cross-Platform Desktop Strategy as Research and records this unresolved boundary: An actual target-user/platform need, native UI and credential equivalents, toolchain/support matrix and release/validation capacity.

</details>

---

<a id="fw-p3-43"></a>

## FW-P3-43 — Local-Data Encryption at Rest

**Status:** Research
**Depends on:** Database lifecycle, backup, credential and recovery architecture

Investigate encryption of LedgerForge financial data at rest.

The design must address:

- key ownership and storage;
- unlock and recovery;
- backup encryption;
- migration of existing databases;
- performance;
- development and testing workflows;
- loss-of-key consequences;
- interaction with portable workspaces and optional sync;
- explicit user understanding.

Encryption must not create a false promise of security while leaving exported backups or diagnostics unprotected.

**Current discovery disposition — 2026-09-10:** `BLOCKED_ON_PRODUCT_DECISION`. **Exact remaining gate:** Threat model, unlock/recovery ownership and encrypted-backup policy.

**Smallest proposed boundary:** FileVault fact is not exported-backup encryption.

**External authority distinction:** [Apple FileVault](https://support.apple.com/en-euro/guide/security/sec4c6dc1b6e/web) protects a volume, which differs from app-managed database/package encryption and key recovery. No local FileVault setting was inspected or certified.

**Bounded product choice for future selection:**

| FW ID | Decision and owner | Why it matters | Option A | Option B | Option C | Recommendation | Consequence of deferring | What becomes unblocked |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FW-P3-43 | **User product choice:** which concrete disclosure threat must be covered beyond existing device protection; Chat owns encryption, keys and recovery architecture if selected. | Device loss/theft and exposure of a separately exported backup require different protection outcomes. | No additional app-level protection outcome selected. | Protect a backup/package when it leaves this Mac. | Protect local app data beyond the device/volume boundary. | A until a concrete concern is identified; B is the narrower outcome if exported-package disclosure is the concern. | No app-level encryption claim; local FileVault state is not assumed. | A selected outcome permits a Chat-owned threat, key/recovery and artifact-lifecycle packet; no user technical key-policy choice. |

<details>
<summary>Discovery evidence, dependencies and acceptance boundary</summary>

**First-round evidence, read at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`:** VERIFIED_REPOSITORY: SQLite open/configuration does not show application database encryption; Keychain protects source credentials separately. VERIFIED_EXTERNAL: Apple describes FileVault volume encryption. Local FileVault state was not inspected, and volume encryption does not establish encrypted exported artifacts on arbitrary destinations.

**First-round scope and constraints:** The app remains private, local and explicit. Accepted financial history, native Money, order, multiplicity and provenance cannot be silently rewritten. ADR-046 authentic-input rules apply to financial cases; migration identities remain append-only. Discovery grants no implementation or acceptance. No invented FileVault-enabled claim, cryptography implementation, statement-password key reuse, hidden key escrow or encryption promise while plaintext artifacts remain unexplained.

**First-round question/options:** Which at-rest threat boundary is actually required? OS volume protection may meet some device-loss needs; app-managed DB/package encryption introduces independent key loss, unlock and migration obligations. Select only after the owner chooses the actual threats.

**First-round remainder and implications:** Threat model, unattended unlock policy, key/recovery ownership, encrypted-backup format and destination policy, and handling of existing copies/diagnostics. Encryption/key lifecycle ADR and explicit existing-data conversion/rollback policy; no migration or dependency chosen.

**First-round proposed acceptance/falsifier:** Future qualification must inspect all approved artifacts/residue, test wrong/missing keys and interrupted conversion, restore after device loss using approved recovery evidence, and prove plaintext exposure matches the declared threat model. New artifact destinations, background unlock needs or required cross-device recovery change the threat model.

**Second-round new evidence/resolved direction:** No additional source sample is claimed. Reused immutable first-level fact: VERIFIED_REPOSITORY: SQLite open/configuration does not show application database encryption; Keychain protects source credentials separately. VERIFIED_EXTERNAL: Apple describes FileVault volume encryption. Local FileVault state was not inspected, and volume encryption does not establish encrypted exported artifacts on arbitrary destinations. Second-level disposition is the exact decision/dependency/deferral stated here.

**Exact next evidence or decision:** Exact next evidence/decision: Threat model, unlock/recovery ownership and encrypted-backup policy. Owning authority: FW-P3-43 pinned queue scope and the named dependency below.

**Personal-v1:** POST_V1

**Recommendation after Chat:** BLOCKED_ON_PRODUCT_DECISION **Roadmap:** Preserve priority/numbering; record only the stated gate or deferral. No sprint selected.

**Publication delta:** `REVALIDATED_AFTER_CHANGE` against accepted `f44c2b2469f7cc98c0e6b7fd0cd86ba7796db8a6`. Changed referenced ownership/schema/hydration declarations were reread; the cited feature/absence boundary remains a static fact, not newly executed acceptance.

**Revalidation/falsifiers:** exact post-Sprint-87 provider/lifecycle/hydrator ownership where touched; candidate/ref or authority document change; runtime-only interaction must be freshly observed when required.

**Current gate flags:** user product choice=true, Chat architecture=true, post-87 refresh=false, authentic source=false. **Blocker types:** USER_PRODUCT_DECISION, ARCHITECTURE_DECISION.

**Typed dependencies:**

- `REQUIRES_ACCEPTED_ARCHITECTURE` → `FW-P3-36`: The Verified Backup, Restore and Disaster Recovery boundary must provide: User-owned verified package; isolated restore; nonempty target protection.. This enables FileVault fact is not exported-backup encryption. Remaining condition: Threat model, unlock/recovery ownership and encrypted-backup policy.
- `REQUIRES_USER_DECISION` → `decision-encryption`: The explicitly named gate decision-encryption must be satisfied. This enables FileVault fact is not exported-backup encryption. Remaining condition: Threat model, unlock/recovery ownership and encrypted-backup policy.

**Pinned evidence references:**

- [Import/Password/DefaultPasswordProvider.swift](<../Import/Password/DefaultPasswordProvider.swift>):37-50;178-214 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `de4f93cdfc8c9fdf2d8cf23d4127f649ae05608be2806964812d00e567b43215` — KeychainCredentialStore attributes
- [Database/SQLiteDatabase.swift](<../Database/SQLiteDatabase.swift>):1-100 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `5945852ad75513a1fcbd15c692512ab35786523da9defd889b9d4f7f710b474a` — SQLite open and WAL configuration
- [Database/SQLiteDatabase.swift](<../Database/SQLiteDatabase.swift>):109-146 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `5945852ad75513a1fcbd15c692512ab35786523da9defd889b9d4f7f710b474a` — createBackup; checkpointAndClose
- [Database/SQLiteRepositoryProvider.swift](<../Database/SQLiteRepositoryProvider.swift>):1381-1450;1540-1591 at `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; SHA-256 `29166a1e985c9c4f5b43e6d13243a82fa5ff5e94382747b3fb406ae0dc98b454` — createAndVerifyBackup; restorePersistentDebugBackup
- [Project documents/FUTURE_WORK.MD](<FUTURE_WORK.MD>):3214-3293 at `af2d1949c6e9a73af3bb004422b72882d28195e2` — The pinned queue defines Local-Data Encryption at Rest as Research and records this unresolved boundary: Threat model, unattended unlock policy, key/recovery ownership, encrypted-backup format and destination policy, and handling of existing copies/diagnostics.

</details>

---

# Research Queue

Items in this section are not implementation candidates until promoted into a priority section. Research already promoted into a numbered candidate is not repeated here.

The first-round routing remains: parser assistance and cross-format evidence → FW-P1-06/07/08/17; mutation-history compaction → FW-P0-16 after a real mutation family; explainable recommendations → FW-P3-06; anomaly work → FW-P2-28; tax/regulatory assistance → FW-P3-16. These are research, not new IDs or selected sprints.

## Import and Parsing Research

- semi-automated parser-assistance research from authentic source semantics, with generated artifacts explicitly ineligible as parser/source acceptance evidence;
- AI-assisted recovery for unsupported or ambiguous layouts beyond column detection;
- shared parser evidence across CSV, PDF, XLS, XLSX and TXT.

## Persistence Research

- long-term mutation-history compaction and archival after `FW-P0-16` and a concrete durable mutation history exist; compaction cannot precede family-specific retention, privacy and reversibility policy.

## Financial Intelligence Research

- explainable recommendations;
- anomaly detection;
- tax and regulatory assistance.

Research findings must not be reported as planned product work until they are promoted into the prioritized queue.

---

## Maintenance Rules

When editing this document:

- preserve existing candidate IDs;
- add candidates in priority and dependency order;
- update status when dependencies change;
- use only the defined status labels and record unmet conditions under `Depends on` rather than inventing compound status labels;
- record verified bugs explicitly;
- remove completed work;
- remove work selected for execution;
- do not record implementation progress;
- do not duplicate completed sprint history;
- do not place architectural decisions here;
- do not include raw financial identifiers, passwords or source fragments;
- keep candidates implementation-agnostic until repository discovery;
- distinguish candidate work from research and ideas;
- record every approved but unimplemented idea, verified bug, accepted architectural follow-up and deferred sprint exclusion;
- do not remove a candidate merely because its priority is low or its dependency is distant;
- preserve LedgerForge principles:
  - offline first;
  - privacy by default;
  - deterministic before intelligent;
  - single source of truth;
  - resilient parsing;
  - explicit user control;
  - explainable financial decisions;
  - explicit and reversible destructive actions.
