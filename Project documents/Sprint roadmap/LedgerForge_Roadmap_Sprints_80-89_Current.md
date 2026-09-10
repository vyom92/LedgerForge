# LedgerForge Roadmap: Sprints 80–89

**Status:** Current repository cycle roadmap
**Refreshed:** 2026-09-10
**Planning review baseline:** `main@adcf83f52d309ddac18d95f0321d0c0f6120dd29`
**Supersedes:** `Project documents/Sprint roadmap/Archived/LedgerForge_Roadmap_Sprints_70-79_Current.md` as current-cycle authority; that file remains historical

## Control

- **Planning authority:** This file owns Sprint 80–89 numbering, corrective suffixes, cycle status and planned positions.
- **Execution authority:** None. Roadmap assignment is planning, not implementation authorization; each sprint still requires Chat priority/dependency triage and a complete execution prompt.
- **Latest numbered product implementation:** Sprint 83 — Serial Batch Import and Multi-File Drag-and-Drop, accepted at implementation commit `adcf83f52d309ddac18d95f0321d0c0f6120dd29` (parent `057d70b6f39929735401d5211cd180db162c94cc`). Sprint 82 — Serial Unified Import Centre Foundation remains accepted at `d239f939088b67e5a90c65117f08592891be17bb`. Sprint 81 — PR-1 Staging and Runtime Publication Ownership Seam remains accepted at `13552eaf8d22a8e6fcb56fb9a9d7a9dd0892bf91`. The accepted startup/monthly-planner product package is commit `6455f662dd0ea8896d19af3e67be51546badb3ae`; the later `d8124ef5a1f38a1e7547f4f8905c91f25b2f1194` cleanup is non-product repository maintenance, and `a560312db5900645779a499016e13f0c87e81435` is the R1 documentation/planning publication.
- **Current migration:** V17; V1–V16 remain immutable.
- **Current source/reliability authority:** ADR-046 complete-authentic-corpus certification.
- **Current UI design authority:** `LF-UI-2026-09-R1` for its bounded scope; design approval is not native implementation.
- **Latest accepted discovery:** Sprint 80 — `SWIFT6_READINESS_COMPLETE`.
- **Personal-v1:** UNDECLARED / NOT CERTIFIED.
- **Canonical queue:** `FUTURE_WORK.MD`. This roadmap consumes recorded IDs and must not become a second backlog.

Repository/source evidence overrides stale wording. Explicit user decisions remain binding until superseded. Active WIP is not accepted product state.

### Corrective numbering and no-cascade rule

- `NA` is the first bounded correction attributable to Sprint `N`.
- `NB` is another separately bounded correction attributable to Sprint `N`.
- An internal blocker in `NB` does not create `NC`; `NC` exists only if `NB` itself fails the original Sprint-N outcome.
- Unrelated P0 defects are never disguised as a correction to the preceding feature sprint.
- Planned later numbers do not silently move when an entry gate blocks. Chat must explicitly revise this roadmap if sequencing changes.

## Financial correctness entry and acceptance rules

For every statement-dependent sprint, the complete registered authentic corpus is authority. No representative-month/sample shortcut and no synthetic/generated/sanitized/reconstructed/reduced/mutated/hand-authored financial statement is permitted at any stage. Production output is not its own oracle, exact support does not generalize across institution/product/format/layout/credential/currency boundaries, and private gates fail closed when unavailable.

A material source, credential, parser, persistence, orchestration or financial-semantic correction invalidates earlier green evidence for the affected boundary. Freeze and retest the final candidate. Acceptance must identify exactly what was tested. A newly verified financial-correctness defect preempts unrelated lower-priority work unless the user explicitly accepts/defers it.

## Cycle overview

| Sprint | Outcome | Queue | Planning type | Status / entry gate |
|---|---|---|---|---|
| 80 | Swift 6 and macOS readiness closure | accepted discovery | Technical discovery | **Accepted / discovery complete** |
| 81 | PR-1 Staging and Runtime Publication Ownership Seam | historical `FW-P2-72` (removed from active queue) | Behavior-preserving implementation gate | **ACCEPTED** — implementation commit `13552eaf8d22a8e6fcb56fb9a9d7a9dd0892bf91` |
| 82 | Serial Unified Import Centre Foundation | completed `FW-P1-19` (removed from active queue) | Core product implementation | **ACCEPTED** — implementation commit `d239f939088b67e5a90c65117f08592891be17bb`; serial queue length one and the Sprint 83 entry evidence are established |
| 83 | Serial Batch Import and Multi-File Drag-and-Drop | completed `FW-P1-20` + `FW-P1-21` (removed from active queue) | Core product implementation | **ACCEPTED** — implementation commit `adcf83f52d309ddac18d95f0321d0c0f6120dd29`; ordered serial queue length N, multi-file picker/drop, independent per-item review/confirmation and outcomes |
| 84 | PR-2 SQLite / Provider / Migration Ownership | `FW-P2-73` | Swift-6 prerequisite | **Next planned position; not selected** — fresh P0 → P1 → P2 → P3 gate and readiness review required; the name implies no schema migration |
| 85 | PR-3 Dependency Concurrency Boundary | `FW-P2-74` | Swift-6 prerequisite | Planned position |
| 86 | TEST-PR Strict-Concurrency Test Correction | `FW-P2-75` | Swift-6 prerequisite | Planned; never weaken independent assertions merely to silence diagnostics |
| 87 | Coordinated Swift-6 Migration | `FW-P2-76` | Implementation | Entry gate: serial Unified Import Centre through Sprints 82–83 accepted, plus acceptance of Sprints 84–86; no feature work bundled |
| 88 | App Shell and Workflow Decomposition | `FW-P2-67` | Behavior-preserving maintenance | No financial redesign or broad source-tree move; preserve R1 shell direction |
| 89 | LF-UI-2026-09-R1 Transactions Reference Implementation | `FW-P2-03` + `FW-P2-53`, bounded `FW-P2-48` + `FW-P2-49` + `FW-P2-50` | User-facing implementation / representative R1 proof surface | Planned position; financial semantics remain source/repository-authoritative |

## Sprint entry-gate rule

Before every planned sprint starts, Chat reruns P0 → P1 → P2 → P3 triage. A verified higher-priority defect preempts lower-priority execution unless the user explicitly defers it. If a dependency remains unsatisfied, do not silently substitute another implementation or shift every later sprint number: record/update the block in `FUTURE_WORK.MD`, return to Chat and revise the roadmap only through an explicit planning decision.


## Sprint 80 — Swift 6 and macOS readiness closure

### Status

**Accepted / discovery complete on 2026-08-28.** Sprint 80 is an accepted
technical-evidence outcome, not a production implementation.

### Accepted result

The compiler was reached with Xcode 26.6 (build 17F113), Apple Swift 6.3.3 and
the macOS 26.5 SDK. All current native targets remain Swift 5. The current app
configuration enables approachable concurrency, default MainActor isolation and
member-import visibility, with no explicit project `SWIFT_STRICT_CONCURRENCY`
setting. Strict readiness is materially non-clean and is no longer an
infrastructure-only unknown. Cluster-level diagnostics, the 45-location unit-
test probe, the zero-source-error/zero-source-warning UI-test probe and the
macOS metadata findings are recorded in `PROJECT_STATE.md`; raw compiler-log
noise is not governance evidence.

The accepted strategy is to make behavior-preserving ownership corrections
under Swift 5, implement the first Unified Import Centre serially with explicit
ownership, defer bounded parallel preparation until transferable ownership and
dependency thread-safety are proven, then complete the remaining prerequisite
families and perform a coordinated Swift-6 migration. Swift 6 is not required
before the serial Import Centre, but it is required before personal-v1
certification.

Sprint 80 recorded four bounded prerequisite families: `FW-P2-72`
(PR-1 staging/publication ownership seam), `FW-P2-73` (PR-2
SQLite/provider/migration ownership), `FW-P2-74` (PR-3 dependency boundary) and
`FW-P2-75` (TEST-PR unit-test strict-concurrency correction). The coordinated
migration gate is `FW-P2-76`. Sprint 80 authorized none of them; Sprint 81 has
since completed and accepted PR-1, while PR-2, PR-3, TEST-PR and the coordinated
migration remain future work.

The current product artifact is macOS-native, uses the macOS 26.5 SDK, App
Sandbox and selected-file import. Stale platform/bundle metadata and the
remaining minimum-version, entitlement, capability, hardened-runtime,
distribution and UI-test policy decisions remain future work under `FW-P2-70`.

The accepted `cbq.credit-card.pdf@1` July-2026 `malformedPreamble` defect was
`PRE_EXISTING_OR_EXTERNAL` relative to Sprint 79. Sprint 80 did not repair or
investigate its source grammar. The later accepted unnumbered reset corrected
the exact registered CBQ boundary while preserving historical minimum-due
absence and enforcing the current authentic minimum-due contract. Personal-v1
adoption remains a separate later gate.

## Accepted Sprints 81–83 and planned Sprints 84–89

### Sprint 81 — PR-1 Staging and Runtime Publication Ownership Seam

Historical queue origin: `FW-P2-72` (removed from the active queue).

**ACCEPTED on 2026-09-10.** Implementation commit:
`13552eaf8d22a8e6fcb56fb9a9d7a9dd0892bf91`.

The accepted behavior-preserving Swift-5 correction establishes pure synchronous staging and explicit MainActor runtime publication while preserving complete-snapshot installation, provider generations, observer ordering and provider parity. It adds no parallel preparation, Swift-6 switch, Import Centre implementation, schema/migration, parser/source or financial-semantic change.

### Sprint 82 — Serial Unified Import Centre Foundation

Historical queue origin: `FW-P1-19` (removed from the active queue).

**ACCEPTED on 2026-09-10.** Implementation commit:
`d239f939088b67e5a90c65117f08592891be17bb`.

The accepted Swift-5 implementation establishes one shared @MainActor serial Import Centre coordinator with queue length one, deterministic ordering, per-item identity/state ownership, safe cancellation before confirmation, explicit per-statement confirmation, provider-owned persistence and canonical hydration. It preserves the existing ImportEngine/parser/normalizer, duplicate/equivalence, account/card/partial/recovery and provider contracts; no reader, parser, schema, migration or financial-semantic boundary changed.

This foundation established the entry evidence for the now-accepted Sprint 83: serial coordinator; per-item identity/state ownership; cancelled-task draining; explicit confirmation; shared production ownership; duplicate/recovery preservation; and no parallel preparation. The complete focused coordinator validation, canonical TestPlan, complete registered authentic corpus, native preview/cancel/confirm/navigation checks and durable same-database relaunch evidence are recorded in `PROJECT_STATE.md`.

### Sprint 83 — Serial Batch Import and Multi-File Drag-and-Drop

Historical queue origins: `FW-P1-20` + `FW-P1-21` (removed from the active queue).

**ACCEPTED on 2026-09-10.** Implementation commit:
`adcf83f52d309ddac18d95f0321d0c0f6120dd29` (parent `057d70b6f39929735401d5211cd180db162c94cc`).

The accepted Swift-5 implementation extends the shared serial coordinator to ordered queue length N, with the same path for single-file import, multi-file picker and drag-and-drop. Received intake order and per-occurrence identity are preserved. One active preparation, independent per-item review and explicit confirmation, skip/cancel/retry/continue, per-file failure isolation and truthful batch summaries are established. Provider-owned persistence and canonical hydration remain unchanged; no batch-wide atomicity is implied.

Repository/code/test verification and the retained final TestPlan, complete authentic-corpus, Debug/Release, native interaction and durable same-database relaunch evidence are classified in `PROJECT_STATE.md`. Native drag gestures and one CSV confirmation were user-assisted. No reader, parser, normalizer, financial-semantic, schema/migration or ADR change was included; V17 and Swift 5 remain current. Bounded parallel preparation remains unscheduled research under existing `FW-P2-51` and is not approved by this acceptance.

### Sprint 84 — PR-2 SQLite / Provider / Migration Ownership

Queue: `FW-P2-73`.

**Next planned position; not selected.** A fresh Chat P0 → P1 → P2 → P3 gate, readiness review and separate execution prompt are required before selection or execution.

Correct only the bounded Swift-6 prerequisite ownership surfaces. The sprint title does not authorize schema change or a new migration.

### Sprint 85 — PR-3 Dependency Concurrency Boundary

Queue: `FW-P2-74`.

Resolve the bounded ZIPFoundation decision and LegacyXLS/libxls concurrency policy without inventing generic third-party concurrency architecture.

### Sprint 86 — TEST-PR Strict-Concurrency Test Correction

Queue: `FW-P2-75`.

Make unit-test ownership/synchronization honest for strict migration. Preserve independent source/test oracles and assertions; never weaken tests merely to remove diagnostics.

### Sprint 87 — Coordinated Swift-6 Migration

Queue: `FW-P2-76`.

Entry gate: the serial Unified Import Centre through Sprints 82–83 is accepted; Sprints 84–86 must also be accepted before Swift-6 migration. Perform the coordinated language/strict-concurrency migration only; no feature work bundled.

### Sprint 88 — App Shell and Workflow Decomposition

Queue: `FW-P2-67`.

Behavior-preserving decomposition only. Preserve financial/repository semantics and R1 shell direction. Do not combine broad source-tree moves (`FW-P2-77`) or financial redesign with this maintenance boundary.

Discovery 2026-09-10: [FW-P2-67](../Discovery/Read_Only_Discovery_Register.md#fw-p2-67) maps shell, hydration/publication and import-presentation ownership. Preserve behavior while extracting established seams; [FW-P2-77](../Discovery/Read_Only_Discovery_Register.md#fw-p2-77) remains a separate path/membership/resource audit before any physical move. Native runtime parity remains future acceptance, not a discovery result.

### Sprint 89 — LF-UI-2026-09-R1 Transactions Reference Implementation

Queue: `FW-P2-03` + `FW-P2-53`, with only necessary bounded portions of `FW-P2-48`, `FW-P2-49` and `FW-P2-50`.

Required boundary:

- AND across filter groups and OR within a multi-select group;
- native-currency presentation and totals only;
- exact source-date semantics without timezone invention;
- deterministic sorting with stable tie behavior;
- stable selection and collapsible inspector;
- totals over the full matching scope, not merely visible rows;
- bank cash movement and card-liability effects remain distinct;
- no hidden FX conversion;
- no debit = spending or credit = income inference;
- targeted source/runtime verification of the existing INR colour observation **before** any financial-colour semantic change.

Discovery 2026-09-10: [FW-P2-03](../Discovery/Read_Only_Discovery_Register.md#fw-p2-03), [FW-P2-53](../Discovery/Read_Only_Discovery_Register.md#fw-p2-53) and the linked accessibility cards retain the R1 contract. Current search/presentation evidence does not settle all new filter semantics or the INR colour observation. Require independent matching-scope totals/order and targeted native keyboard, VoiceOver, resize and contrast evidence; no financial-colour change from a screenshot inference.

`FW-P2-77` remains explicitly deferred, not forgotten. Its maintenance value does not outrank the P1/P2 user outcomes above, and broad physical moves must not be mixed with app-shell or R1 behavioral work.


## Read-only discovery index — 2026-09-10

[The complete discovery register](../Discovery/Read_Only_Discovery_Register.md) records evidence, proposed boundaries and named blockers without selecting any sprint. Sprints 84–87 remain with their existing campaign owner. Historical repair/reversal still requires an exact source-provable family; backup, export and support documentation remain explicit adoption inputs. The prepared 90–99 entry refinements remain a forecast and do not activate that cycle.

## Serious candidates not silently selected

The cycle forecast does not erase higher-priority or competing queue work. Before every sprint starts, Chat re-triages the complete queue.

| Priority | Candidate(s) | Current classification / exact reason not scheduled here |
|---|---|---|
| P0 | `FW-P0-02` | Ready for discovery, but no one historical duplicate-repair family has been selected with independently provable impact/reversal semantics. |
| P0 | `FW-P0-08` | Ready for discovery, but no concrete affected repository/family is selected; a broad repair-everything operation remains invalid. |
| P0 | `FW-P0-11`, `FW-P0-12`, `FW-P0-13`, `FW-P0-14`, `FW-P0-15` | Blocked by linking/unlinking, identifier-detachment, split, duplicate-account and survivor/conflict semantics. |
| P0 | `FW-P0-16` | Architecture accepted, but executable mutation is gated on selecting one concrete family with exact impact and reversal/irreversibility. |
| P0 | `FW-P0-18` | Blocked on the future multiple-workspace architecture and fingerprint-scope decision. |
| P0 | `FW-P0-19` | Blocked until one new exact representation relationship has source truth and family-specific identity/equivalence authority; Axis-bank semantic parity alone is not durable equivalence. |
| P0 | `FW-P0-20` | Research only; each additional transaction-event family needs authentic overlapping evidence and its own deterministic semantics. |
| P0 | `FW-P0-26` | Blocked certification gate; adopted pre-v1 import, backup/restore, export, support-matrix and other designated prerequisites remain incomplete or unaccepted. |
| P1 | parser-family expansion | Existing registered families are certified; no additional exact source family has been selected. `FW-P1-04` is discovery-ready, while other families remain Candidate/Research by their evidence. |
| P1 | `FW-P1-06` | Ready for planning, but no new parser family requires framework expansion before the ownership/import/Swift sequence; it does not outrank an active financial defect if one appears. |
| P1 | `FW-P1-25` | Ready for discovery; broader duplicate-management/override/reversible semantics remain unresolved and must be reevaluated before dependent reconciliation/analytics. |
| P1 | `FW-P1-27` | Ready for discovery, but no exact import-session reversal family/impact contract has been selected. |
| P1 | `FW-P1-29` | Ready for planning, but accepted immediate recovery guidance already exists; only broader education remains and is not an entry dependency for 81–89. |
| P1 | `FW-P1-37` | Ready for planning, but broader diagnostics remain nonblocking absent a newly verified diagnostic correctness defect. |
| P2 | `FW-P2-12` | Ready for discovery; must preempt reconciliation/analytics if current duplicate guarantees prove insufficient, otherwise remains separate. |
| P2 | account lifecycle (`FW-P2-30`, `FW-P2-31`, `FW-P2-32`, `FW-P2-33`, `FW-P2-34`, `FW-P2-35`, `FW-P2-36`, `FW-P2-37`) | Several are blocked/candidate pending targeted mutation, visibility, closure or asset semantics; none is an entry dependency for the planned cycle. |
| P2 | `FW-P2-54` | Ready for discovery, but user-facing document browsing still needs an approved privacy-safe metadata/retention/navigation boundary. |
| P2 | `FW-P2-77` | Ready for discovery and explicitly deferred: broad structural moves must not be mixed with app-shell or R1 behavioral work. |
| P2 | `FW-P2-79` | Ready for planning and mandatory input to personal-v1 certification, but it is documentation/support-matrix work rather than an 81–89 executable product dependency. |
| P3 | net worth | Blocked on investment and reporting-currency foundations; no current consolidated net-worth authority exists. |
| P3 | `FW-P3-36` backup/restore | Ready for discovery, but the user-owned backup contents/integrity/restore-target/compatibility contract is not approved. |
| P3 | export (`FW-P3-17`, `FW-P3-35`) | Candidate work blocked from adoption by unresolved export schema/privacy decisions. |
| P3 | `FW-P3-40` multiple workspaces | Research; identity, fingerprint, settings and repository isolation are undecided. |
| P3 | encryption/sync (`FW-P3-37`, `FW-P3-43`) | Research; depends on backup, key ownership/recovery, conflict and opt-in architecture. |

## Maintenance

When this roadmap changes, preserve accepted numbering/history, distinguish plans from execution/acceptance, keep detailed implementation truth in `PROJECT_STATE.md`/ADRs, retain exact source-support boundaries, keep private source/credential/transaction detail out of roadmap prose and update queue dispositions before scheduling new work.
