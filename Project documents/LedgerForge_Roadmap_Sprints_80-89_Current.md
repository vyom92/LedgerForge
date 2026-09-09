# LedgerForge Roadmap: Sprints 80–89

**Status:** Current repository cycle roadmap
**Refreshed:** 2026-09-09
**Planning review baseline:** `main@a560312db5900645779a499016e13f0c87e81435`
**Supersedes:** `Project documents/LedgerForge_Roadmap_Sprints_70-79_Current.md` as current-cycle authority; that file remains historical

## Control

- **Planning authority:** This file owns Sprint 80–89 numbering, corrective suffixes, cycle status and planned positions.
- **Execution authority:** None. Roadmap assignment is planning, not implementation authorization; each sprint still requires Chat priority/dependency triage and a complete execution prompt.
- **Latest numbered product implementation:** Sprint 79. The accepted startup/monthly-planner product package is commit `6455f662dd0ea8896d19af3e67be51546badb3ae`; the later `d8124ef5a1f38a1e7547f4f8905c91f25b2f1194` cleanup is non-product repository maintenance, and `a560312db5900645779a499016e13f0c87e81435` is the R1 documentation/planning publication reviewed by this reconciliation.
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
| 81 | PR-1 Staging and Runtime Publication Ownership Seam | `FW-P2-72` | Behavior-preserving implementation gate | Planned position; rerun P0→P3 triage before start |
| 82 | Serial Unified Import Centre Foundation | `FW-P1-19` | Core product implementation | Planned; single file = queue length one, same orchestration model for future batch |
| 83 | Serial Batch Import and Multi-File Drag-and-Drop | `FW-P1-20` + `FW-P1-21` | P1 entry-gated product outcome | Blocked unless Sprint 82 proves named cancellation, duplicate, failure-isolation and per-file ownership prerequisites |
| 84 | PR-2 SQLite / Provider / Migration Ownership | `FW-P2-73` | Swift-6 prerequisite | Planned; the name implies no schema migration |
| 85 | PR-3 Dependency Concurrency Boundary | `FW-P2-74` | Swift-6 prerequisite | Planned position |
| 86 | TEST-PR Strict-Concurrency Test Correction | `FW-P2-75` | Swift-6 prerequisite | Planned; never weaken independent assertions merely to silence diagnostics |
| 87 | Coordinated Swift-6 Migration | `FW-P2-76` | Implementation | Entry gate: Sprint 82 and Sprints 84–86 accepted; no feature work bundled |
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

The four bounded prerequisite families are separately recorded as `FW-P2-72`
(PR-1 staging/publication ownership seam), `FW-P2-73` (PR-2
SQLite/provider/migration ownership), `FW-P2-74` (PR-3 dependency boundary) and
`FW-P2-75` (TEST-PR unit-test strict-concurrency correction). The coordinated
migration gate is `FW-P2-76`. None is complete or authorized by Sprint 80.

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

## Planned Sprints 81–89

### Sprint 81 — PR-1 Staging and Runtime Publication Ownership Seam

Queue: `FW-P2-72`.

Behavior-preserving Swift-5 correction only. Establish pure synchronous staging and explicit MainActor runtime publication while preserving complete-snapshot installation, provider generations, observer ordering and provider parity. No parallel preparation or Swift-6 switch.

### Sprint 82 — Serial Unified Import Centre Foundation

Queue: `FW-P1-19`.

Single-file import is queue length one. Use deterministic queue order, explicit per-file ownership, safe cancellation before confirmation, explicit per-statement confirmation, provider-owned persistence and canonical hydration. The orchestration shape is the future batch shape; no bounded parallel preparation is accepted here.

### Sprint 83 — Serial Batch Import and Multi-File Drag-and-Drop

Queue: `FW-P1-20` + `FW-P1-21`.

Entry gate: Sprint 82 must have accepted the named cancellation, duplicate, failure-isolation and per-file ownership prerequisites. If the gate is still blocked, Sprint 83 does not implement and returns to Chat. One failed file must not contaminate unrelated files; no batch-wide atomicity is required or implied. Parallel preparation remains unresolved unless separately accepted.

### Sprint 84 — PR-2 SQLite / Provider / Migration Ownership

Queue: `FW-P2-73`.

Correct only the bounded Swift-6 prerequisite ownership surfaces. The sprint title does not authorize schema change or a new migration.

### Sprint 85 — PR-3 Dependency Concurrency Boundary

Queue: `FW-P2-74`.

Resolve the bounded ZIPFoundation decision and LegacyXLS/libxls concurrency policy without inventing generic third-party concurrency architecture.

### Sprint 86 — TEST-PR Strict-Concurrency Test Correction

Queue: `FW-P2-75`.

Make unit-test ownership/synchronization honest for strict migration. Preserve independent source/test oracles and assertions; never weaken tests merely to remove diagnostics.

### Sprint 87 — Coordinated Swift-6 Migration

Queue: `FW-P2-76`.

Entry gate: Sprint 82 plus Sprints 84–86 accepted. Perform the coordinated language/strict-concurrency migration only; no feature work bundled.

### Sprint 88 — App Shell and Workflow Decomposition

Queue: `FW-P2-67`.

Behavior-preserving decomposition only. Preserve financial/repository semantics and R1 shell direction. Do not combine broad source-tree moves (`FW-P2-77`) or financial redesign with this maintenance boundary.

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

`FW-P2-77` remains explicitly deferred, not forgotten. Its maintenance value does not outrank the P1/P2 user outcomes above, and broad physical moves must not be mixed with app-shell or R1 behavioral work.


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
