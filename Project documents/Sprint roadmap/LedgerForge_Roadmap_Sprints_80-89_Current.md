# LedgerForge Roadmap: Sprints 80–89

**Status:** Current repository cycle roadmap
**Refreshed:** 2026-09-11
**Planning review baseline:** accepted Sprint 88, `main@4f5eeb7b11c0f5879204a06ae9f08045304342b5`; parent documentation closure `4973d2d2507ae5891bfa593b359af2b9393e5fa1`
**Supersedes:** `Project documents/Sprint roadmap/Archived/LedgerForge_Roadmap_Sprints_70-79_Current.md` as current-cycle authority; that file remains historical

**Private personal scope reset — 2026-09-11:** apply the [Private Personal App Scope Gate](../../AGENTS.md#private-personal-app-scope-gate) before P0 → P3 triage. Rejected work is **NOT REQUIRED-DO NOT CONSIDER**, excluded from scheduling and dependencies. The [canonical register](../FUTURE_WORK.MD#rejected-private-personal-scope) owns the exact rejected categories. Accepted Sprint 80–88 sections and the SHELL88 blueprint below remain historical records; their former future-work references cannot reopen rejected scope.

**Forward planning:** the prepared [90–99](Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md) and [100–109](Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md) roadmaps retain the owner's selected personal outcomes and Sprint 100 — LedgerForge 1.0 Personal Adoption Verification. Neither successor cycle is current or implementation-authorized. Sprint 89 has existing local unaccepted WIP, paused for this documentation correction; continuation requires the corrected execution contract and a fresh exact-ref preflight.

## Control

- **Planning authority:** This file owns Sprint 80–89 numbering, corrective suffixes, cycle status and planned positions.
- **Execution authority:** None. Roadmap assignment is planning, not implementation authorization; each sprint still requires Chat priority/dependency triage and a complete execution prompt.
- **Latest accepted numbered implementation:** Sprint 88 — App Shell and Workflow Decomposition, accepted at `4f5eeb7b11c0f5879204a06ae9f08045304342b5`. Behavior-preserving shell/workflow extraction retains root, provider, hydrator and serial Import Centre ownership. All native targets remain Swift 6; no Sprint 88A, migration, new ADR or financial/source change.
- **Current migration:** V17; V1–V16 remain immutable.
- **Current source/reliability authority:** ADR-046 complete-authentic-corpus certification.
- **Current UI design authority:** `LF-UI-2026-09-R1` for its bounded scope; design approval is not native implementation.
- **Latest accepted discovery:** Sprint 80 — `SWIFT6_READINESS_COMPLETE`.
- **PERSONAL-V1: NOT YET ADOPTED.**
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
| 84 | PR-2 SQLite / Provider / Migration Ownership | historical `FW-P2-73` (removed from active queue) | Swift-6 prerequisite | **ACCEPTED** — implementation commit `a4dd6929a2282cc94c850eb1dccf350b1ee5c8a1`; no schema migration |
| 85 | PR-3 Dependency Concurrency Boundary | historical `FW-P2-74` (removed from active queue) | Swift-6 prerequisite | **ACCEPTED** — implementation commit `b4e4e6ffb14deccef238352a6ef834514a2a37c2`; local ZIPFoundation correction and process-local libxls serialization |
| 86 | TEST-PR Strict-Concurrency Test Correction | historical `FW-P2-75` (removed from active queue) | Swift-6 prerequisite | **ACCEPTED** — implementation commit `022d436fc4563be9b0967ac2751e6114a31474c1`; test/support-only, production bytes frozen |
| 87 | Coordinated Swift-6 Migration | completed `FW-P2-76` (removed from active queue) | Implementation | **ACCEPTED** — implementation `93c068c23027a8cd59753ac4ac916e6cee75adbf`; all native targets Swift 6; V17 and ADRs unchanged |
| 88 | App Shell and Workflow Decomposition | completed `FW-P2-67` (removed from active queue) | Behavior-preserving maintenance | **ACCEPTED** — implementation `4f5eeb7b11c0f5879204a06ae9f08045304342b5`; ownership and native parity preserved; V17 and ADRs unchanged |
| 89 | LF-UI-2026-09-R1 Transactions Reference Implementation | `FW-P2-03` + `FW-P2-53`, necessary Transactions portions of `FW-P2-48` + `FW-P2-50` | Bounded owner-facing R1 implementation | **PAUSED / UNACCEPTED WIP**; scope reset preempts continuation; re-preflight against the published correction and complete corrected execution contract |

## Sprint entry-gate rule

Before every planned sprint starts, Chat applies PRIVATE PERSONAL APP ELIGIBILITY, then reruns P0 → P1 → P2 → P3 triage only over eligible work. A verified higher-priority defect preempts lower-priority execution unless the user explicitly defers it. If a dependency remains unsatisfied, do not silently substitute another implementation or shift every later sprint number: record/update the block in `FUTURE_WORK.MD`, return to Chat and revise the roadmap only through an explicit planning decision.


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
since completed and accepted PR-1 and Sprint 84 has completed and accepted PR-2.
Sprint 85 has since completed and accepted PR-3; TEST-PR is now Chat-authorized and the coordinated migration remains gated.

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

## Accepted Sprints 81–88 and paused, unaccepted Sprint 89

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

Historical queue origin: `FW-P2-73` (removed from the active queue).

**ACCEPTED on 2026-09-10.** Implementation commit:
`a4dd6929a2282cc94c850eb1dccf350b1ee5c8a1` (parent `af2d1949c6e9a73af3bb004422b72882d28195e2`).

The accepted Swift-5 correction gives SQLite operations and lifetimes, provider-generation validity, migration registries/closures and app/helper shared sources explicit bounded ownership. It preserves financial behavior, provider parity, hydration and accepted V1–V17 identities, with no schema migration. Focused and complete TestPlan, complete authentic/provider-order, strict app/helper, Debug/Release and durable relaunch evidence is recorded in `PROJECT_STATE.md`.

### Sprint 85 — PR-3 Dependency Concurrency Boundary

Historical queue origin: `FW-P2-74` (removed from the active queue).

**ACCEPTED on 2026-09-10.** Implementation commit `b4e4e6ffb14deccef238352a6ef834514a2a37c2`.

Accepted decisions: `ZIPFOUNDATION_DECISION = LOCAL_CORRECTION` and `LEGACYXLS_POLICY = SERIALIZED_PROCESS_LOCAL`. The bounded dependency correction preserves financial/source semantics, adds no generic third-party concurrency framework, migration, ADR or Swift-6 product switch. Qualification and its explicit exclusions are recorded in `PROJECT_STATE.md`.

The accepted Sprint-85 validation policy remains recorded below as its acceptance contract:

Use dependency-proportional validation: reproduce and resolve exact dependency diagnostics/policy; run focused dependency/reader tests and every affected authentic XLSX family for ZIPFoundation changes and XLS family for LegacyXLS/libxls changes; then run one authoritative TestPlan on the frozen candidate and compile Debug and optimized Release. The complete all-family/provider-order campaign is required only if shared extraction, routing, snapshots, common persistence mapping or another boundary beyond the affected XLS/XLSX dependency surfaces changes. Durable startup/relaunch is required only if persistence, provider/bootstrap, migration, hydration or startup changes. Record `NOT_REQUIRED` with the evidence-based reason for each omitted broad gate; preserve source/oracle correctness.

**Explicit TestPlan invocation clarification:** for dependency-only Sprint 85, Chat authorizes excluding only the conditional global authentic-corpus/provider-order campaign from the invocation. Every other TestPlan test must run. Keep the checked-in TestPlan and tests unchanged, and report the excluded campaign explicitly as `NOT_REQUIRED`; this is not an unchanged full-plan execution claim. If the broader shared-boundary trigger applies, include the campaign.

Chat has accepted that implementation candidate and authorized Sprint 86. The campaign-specific validation amendment supersedes broader repetitive wording in the original 84–87 prompt.

### Sprint 86 — TEST-PR Strict-Concurrency Test Correction

Historical queue origin: `FW-P2-75` (removed from the active queue).

**ACCEPTED on 2026-09-10.** Implementation commit `022d436fc4563be9b0967ac2751e6114a31474c1`. The test/support-only correction and its proportional qualification are recorded in `PROJECT_STATE.md`; production bytes and native Swift-5 settings remained frozen. The accepted validation contract below is retained as history.

Make unit-test ownership/synchronization honest for strict migration. Preserve independent source/test oracles and assertions; never weaken tests merely to remove diagnostics.

Treat validation as test/support-only: freeze production-source bytes; reproduce current strict-concurrency test diagnostics and prove zero unresolved Swift-6-blocking test diagnostics; preserve test/suite inventory, skips, expected-failure policy, assertion strength and independent financial/source oracles; run one authoritative complete TestPlan on the frozen candidate. Authentic-corpus campaigns are required only if the corpus/oracle/shared validation harness changes; otherwise record `NOT_REQUIRED` because production financial behavior and corpus machinery are unchanged. Debug/Release product runtime qualification and durable startup are `NOT_REQUIRED` for test-only changes. **STOP and return to Chat if production/runtime changes are required.**

### Sprint 87 — Coordinated Swift-6 Migration

Completed queue: `FW-P2-76` (removed from active queue).

**ACCEPTED on 2026-09-10** under `ACCEPT_SPRINT_87_AND_CONTINUE_TO_88`, at implementation commit `93c068c23027a8cd59753ac4ac916e6cee75adbf`. The subsequent user-approved continuation head `b2f7ac2a6a517c1365b93274e2ba868b5068a7a4` changes only quoting on eleven existing UI-asset membership exclusion strings and does not change the accepted implementation identity. All native targets are Swift 6. No Sprint 87A, migration or new ADR; V17, accepted ownership/financial semantics and Personal-v1 UNDECLARED / NOT CERTIFIED remain unchanged. [PROJECT_STATE](../PROJECT_STATE.md) owns the accepted outcome.

### Sprint 88 — App Shell and Workflow Decomposition

Completed queue: `FW-P2-67` (removed from active queue).

**ACCEPTED on 2026-09-11** under `SPRINT_88_APP_SHELL_DECOMPOSITION_ACCEPTED`, at implementation commit `4f5eeb7b11c0f5879204a06ae9f08045304342b5` (parent documentation closure `4973d2d2507ae5891bfa593b359af2b9393e5fa1`). The seven-path, behavior-preserving extraction separates shell/sidebar/contextual-toolbar presentation, lazy selected destinations, Import Centre footer presentation and a stateless MainActor hydration-invocation seam. `ContentView` retains state, selection, model lifetimes, importer/lifecycle/tasks and callbacks; `LedgerForgeApp`, ADR-024 `RepositoryStoreHydrator` and the MainActor serial Import Centre retain their authority, including one active preparation and explicit per-statement review/confirmation.

Chat accepted focused 261 definitions / 286 expanded executions / 29 suites and complete TestPlan 518 definitions / 576 expanded executions / 79 suites, with zero failures, skips or expected failures; Debug and optimized Release; the existing six-campaign authentic-corpus gate; native destination/import parity; and durable same-database SQLite relaunch with canonical hydration, all 17 migration identities, integrity and foreign-key checks. CSV cancellation left zero accepted residue; explicit confirmation persisted 97 transactions; the 62/178-transaction serial batch ended with 1 skipped / 1 cancelled and no additional accepted financial data. [PROJECT_STATE](../PROJECT_STATE.md) records the accepted evidence and containment/binding details. This documentation closure reuses that evidence without an executable run.

Accepted limitations: physical resize was not separately completed, transient loading used preserved-source/focused-test coverage, native selection needed user assistance, and the thread limit prevented a fresh independent Sol reviewer; bounded Terra/Luna and primary-session reviews completed. These limitations did not falsify Sprint 88. No migration, new ADR, financial/source or Swift-setting change, Sprint 88A, R1 implementation or parallel preparation; V17, ADR-046, native Swift 6 and Personal-v1 UNDECLARED / NOT CERTIFIED remain unchanged. FW-P2-77 remains separately unscheduled; the [historical SHELL88 blueprint](#packet-shell88-blueprint) does not authorize its optional phase 5.

### Sprint 89 — LF-UI-2026-09-R1 Transactions Reference Implementation

**PAUSED / UNACCEPTED WIP.** Existing Sprint-89 product changes remain separate and unaccepted. The explicit 2026-09-11 scope correction removes the formal accessibility work before acceptance. This documentation task does not accept Sprint 89 or implement product changes; continuation uses the corrected approved contract after a fresh exact-ref preflight.

Queue: `FW-P2-03` + `FW-P2-53`, with only necessary bounded portions of `FW-P2-48` and `FW-P2-50`.

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

**Owner usability acceptance:** no clipping/overlap; usable target widths and full readable Money/currency; deterministic filters, sorting and matching-scope totals; stable selection and inspector behavior; useful ordinary keyboard interaction; focus distinct from selection; useful names/tooltips for icon-rail controls. No formal accessibility campaign is part of this sprint.

The [data algebra](#packet-sprint89-data-algebra) retains the independent membership/order/native-currency-total oracle. The [native procedure](#packet-sprint89-native-acceptance-procedure) tests the actual Transactions workflow. Targeted source/runtime evidence remains required before changing the observed INR colour semantics; a screenshot alone cannot establish a financial defect.

`FW-P2-77` remains explicitly deferred, not forgotten. Its maintenance value does not outrank the P1/P2 user outcomes above, and broad physical moves must not be mixed with app-shell or R1 behavioral work.


## Second-level entry-gate reconciliation — 2026-09-10

PROPOSED documentation reconciliation at `af2d1949c6e9a73af3bb004422b72882d28195e2`; no sprint selection, acceptance or numbering change. [The proposed appendix](#second-level-sprint-88-and-sprint-89-packets) preserves all first-level evidence and records explicit user decisions. Sprint 88 has a static five-phase shell blueprint (characterization through bounded bootstrap adapter), followed only later by optional source-tree organization; exact accepted post-Sprint-87 ownership is its entry gate. Sprint 89 has an independent filter/search/stable-sort/native-currency-total/selection oracle plus ordinary native keyboard/focus/resize checks, narrowed by the scope reset. These procedures do not establish runtime acceptance. No Sprint 84–87 implementation or acceptance section is changed by this campaign.

## Read-only discovery index — 2026-09-10

The actionable queue is [FUTURE_WORK.MD](../FUTURE_WORK.MD); historical Sprint-88 guidance and proposed Sprint-89 work are preserved in the appendix below. The appendix does not authorize Sprint 89; Sprint 88 acceptance is recorded above. Historical repair/reversal still requires an exact source-provable family; verified user backup/restore and support documentation remain explicit adoption inputs; complete structured export is optional under UD-02 and is required only if adopted in the frozen Chat scope. The prepared 90–99 entry refinements remain a forecast and do not activate that cycle.

## Serious candidates not silently selected

The cycle forecast does not erase higher-priority or competing queue work. Before every sprint starts, Chat re-triages the complete queue.

| Priority | Candidate(s) | Current classification / exact reason not scheduled here |
|---|---|---|
| P0 | `FW-P0-02` | Ready for discovery, but no one historical duplicate-repair family has been selected with independently provable impact/reversal semantics. |
| P0 | `FW-P0-08` | Ready for discovery, but no concrete affected repository/family is selected; a broad repair-everything operation remains invalid. |
| P0 | `FW-P0-11`, `FW-P0-12`, `FW-P0-13`, `FW-P0-14`, `FW-P0-15` | Blocked by linking/unlinking, identifier-detachment, split, duplicate-account and survivor/conflict semantics. |
| P0 | `FW-P0-16` | Architecture accepted, but executable mutation is gated on selecting one concrete family with exact impact and reversal/irreversibility. |
| P0 | `FW-P0-18` | Owner-retained single-ledger fingerprint review; waits for one concrete replay/restore question and authentic evidence, with no fingerprint/schema change implied. |
| P0 | `FW-P0-19` | Owner-retained bounded review of the three existing Axis-bank source groups; explain the recorded projection mismatches without inferring durable equivalence or extending source families. |
| P0 | `FW-P0-26` | Personal adoption verification waits for the actual adopted import, recovery, planning, holdings/valuation, current-FX/net-worth and private source-matrix outcomes; complete export remains optional. |
| P1 | Actual owner-source correctness | Existing registered-family limits remain governed by ADR-046. A newly supplied/selected source may establish a bounded new need; hypothetical source placeholders are removed. |
| P1 | `FW-P1-25` | Ready for discovery; broader duplicate-management/override/reversible semantics remain unresolved and must be reevaluated before dependent reconciliation/analytics. |
| P1 | `FW-P1-27` | Ready for discovery, but no exact import-session reversal family/impact contract has been selected. |
| P2 | `FW-P2-12` | Ready for discovery; must preempt reconciliation/analytics if current duplicate guarantees prove insufficient, otherwise remains separate. |
| P2 | account lifecycle (`FW-P2-30`, `FW-P2-31`, `FW-P2-32`, `FW-P2-33`, `FW-P2-34`, `FW-P2-35`, `FW-P2-36`, `FW-P2-37`) | Several are blocked/candidate pending targeted mutation, visibility, closure or asset semantics; none is an entry dependency for the planned cycle. |
| P2 | `FW-P2-54` | Ready for discovery, but user-facing document browsing still needs an approved privacy-safe metadata/retention/navigation boundary. |
| P2 | `FW-P2-77` | Ready for discovery and explicitly deferred: broad structural moves must not be mixed with app-shell or R1 behavioral work. |
| P2 | `FW-P2-79` | Ready for planning and mandatory input to personal adoption verification, but it is a small private supported-source truth table rather than an 81–89 executable product dependency. |
| P3 | net worth | Blocked on investment and reporting-currency foundations; no current consolidated net-worth authority exists. |
| P3 | `FW-P3-36` backup/restore | Ready for discovery, but the user-owned backup contents/integrity/restore-target/compatibility contract is not approved. |
| P3 | export (`FW-P3-17`, `FW-P3-35`) | Optional under UD-02; selection of an export feature still requires its schema/privacy contract. Its absence alone does not block personal adoption verification. |

## Maintenance

When this roadmap changes, preserve accepted numbering/history, distinguish plans from execution/acceptance, keep detailed implementation truth in `PROJECT_STATE.md`/ADRs, retain exact source-support boundaries, keep private source/credential/transaction detail out of roadmap prose and update queue dispositions before scheduling new work.

<a id="second-level-sprint-88-and-sprint-89-packets"></a>
## Second-level packets — historical Sprint-88 guidance and proposed Sprint-89 work

This appendix preserves historical discovery/planning material. Sprint 88 is now accepted in its section above; the retained blueprint is historical guidance, not new work. Sprint-89 data proposals remain unaccepted; the current scope correction above governs its paused local WIP and next acceptance boundary. References to queue work use durable [FUTURE_WORK.MD](../FUTURE_WORK.MD) anchors.

<a id="packet-shell88-and-sprint89-native-procedure"></a>
<a id="packet-shell88-blueprint"></a>
### SHELL88 blueprint

**Scope and invariant.** The proposal is a behavior-preserving decomposition of the existing application shell. It changes neither provider ownership, financial semantics, import coordination, migration, source interpretation, nor Swift language mode. Its evidence pin is that the application root is a `WindowGroup` to `ContentView`, whose current composition is an all-purpose shell. The source pin is stale for SQLite ownership; this appendix performs no PR-2 research.

| Phase | Extract | Preserve | Proposed acceptance surface |
| --- | --- | --- | --- |
| 0 | Characterization: section, availability, import phase, profile warning, shortcut and label map | Navigation, enabled state, provider generation, hydration and import cancel/confirm | Static map and later native baseline |
| 1 | `AppShellView`: split composition, slots, banner and content switch | No workflow or state-owner move | Existing checks plus resize/selection |
| 2 | `AppShellSidebar` and `AppShellToolbar` with explicit inputs/callbacks | Actions, labels, focus and accessibility; no rendering mutation | Keyboard, VoiceOver and toolbar review |
| 3 | Feature containers for each destination | Existing view-model and domain behavior | Destination smoke matrix |
| 4 | Explicit bootstrap adapter around existing setup, hydrator and import | ADR-024, generation, MainActor and cancellation | Focused hydration/import/lifecycle proof |
| 5 | [FW-P2-77](../FUTURE_WORK.MD#fw-p2-77) naming/groups only after parity | Resource and target membership | Xcode/path-consumer review |

**Sprint-88 acceptance update — 2026-09-11:** The static ownership gate, characterization and bounded native parity are satisfied by accepted Sprint 88 at `4f5eeb7b11c0f5879204a06ae9f08045304342b5`, with limitations recorded above. Provider, activity-gate, hydrator, Import Centre and actor-publication authority/semantics remain preserved. Phase 5 source-tree organization remains a separate unscheduled queue decision under FW-P2-77 and was excluded from Sprint 88.

<a id="packet-sprint89-data-algebra-packet"></a>
<a id="packet-sprint89-data-algebra"></a>
### SPRINT89_DATA_ALGEBRA_PACKET

1. **Owning FW IDs:** [FW-P2-03](../FUTURE_WORK.MD#fw-p2-03), [FW-P2-04](../FUTURE_WORK.MD#fw-p2-04) and [FW-P2-38](../FUTURE_WORK.MD#fw-p2-38). Ordinary native focus/selection is intentionally separated into the procedure below.

2. **User problem:** reproducible transaction search/filter/navigation that does not alter financial truth.
3. **Verified current state:** current search is presentation-only and narrow; no saved-filter contract exists.
4. **Accepted authorities:** current FW-P2-03 scope and R1 design authority; canonical transaction provenance remains authoritative.
5. **Exact missing decision:** none for pure algebra; saved-filter scope is a later preference/privacy decision.
6. **Evidence acquired:** first-level scope establishes AND across filter groups and OR within a multi-select group.
7. **Options considered:** repository-side filtering, transient projection, saved-filter persistence.
8. **Recommended option:** one pure transient filter specification.
9. **Why competing options are rejected:** repository query authority/persistence expands scope without need.
10. **Smallest coherent implementation boundary:** given trusted canonical snapshot `R`, return ordered matching rows and segregated native-currency totals.
11. **Included scope:** account, native currency, direction, inclusive financial-date interval, assigned category and privacy-safe current display text.
12. **Explicit exclusions:** hidden identifiers/source fragments, import change, category mutation, saved filters, FX and financial-colour semantic change.
13. **Durable model/persistence requirements:** none.
14. **Migration impact:** none.
15. **ADR impact:** none; align existing immutable-evidence authority.
16. **Privacy/security boundary:** transient folded comparison projection never rewrites description, payee or reference.
17. **SQLite/In-Memory implications:** input is a hydrated trusted canonical snapshot at one provider generation, not a new repository query contract.
18. **Hydration/relaunch implications:** none; no filter is durable.
19. **Independent acceptance oracle:** enumerate `R`; every enabled group passes (AND); selected values within a group match by set membership (OR).
20. **Failure cases:** missing supported field, unavailable snapshot, unknown filter value or empty match set returns no rows/no totals and performs no write.
21. **Reversal/correction semantics:** none.
22. **Source evidence requirement:** authentic source-backed canonical integration input; isolated source-independent query mechanics may use nonfinancial primitive values, never fabricated statement-shaped rows.
23. **Runtime acceptance requirement:** ordinary native focus/keyboard/selection is the separate procedure below; an INR-colour change requires its own targeted probe.
24. **Dependencies:** stable displayed fields and native acceptance only.
25. **Evidence that falsifies the recommendation:** differing output for the same snapshot/spec, hidden-field search or an unsegregated cross-currency total.
26. **Personal-v1 relevance:** PRE_V1_OPTIONAL.
27. **Recommended FUTURE_WORK status after Chat review:** FW-P2-03 waits for the predicate and runtime acceptance; FW-P2-04 waits for accepted search/preference policy; FW-P2-38 waits runtime proof.
28. **Recommended roadmap effect after Chat review:** retain Sprint 89's bounded Transactions slice; no broader cross-screen polish.
**Additional decision detail:** `F={t in R | all enabled groups pass(t) AND search(t,q)}`; each multi-value group passes by OR/set membership; order uses selected primary key/direction then the exact document/ordinal/identity tie contract; totals partition by native currency and accepted bank/card financial-domain/effect, never a mixed grand total.

#### Exact proposed search, sort and total oracle

At one trusted canonical provider generation, take genuine source-backed rows `R` and separately captured visible labels. Allowed search fields are exactly displayed transaction description, account label, institution label and assigned-category label. Hidden account/transaction IDs, raw source/reference fragments, formatted balances, dates and undrawn fields are excluded. A nil field never matches; an empty field matters only when search is disabled.

`fold-v1` is pinned Unicode 15.1 default case folding, canonical NFD, removal of nonspacing combining marks (`Mn`), each Unicode White_Space run replaced by one ASCII space, then trim. Apply it locale-independently to the query and every allowed field. A folded empty query disables search; otherwise split on normalized spaces. `search(t,q)` is true only when **every** literal contiguous term occurs in at least one non-nil allowed displayed field; terms may occur in different fields. Punctuation is literal. Regex, fuzzy matching, token-OR, hidden-field search and stored-text alteration are excluded.

`F={t in R | AND over enabled filter groups(groupMatches(t)) AND search(t,q)}`. Multi-value groups use OR/set membership. Empty selected sets disable their group. An unknown selected value is an explicit invalid filter specification. Inclusive endpoints use the source-established financial civil date. Nil category matches only the explicit uncategorized choice.

Sort only expressly selected visible keys. Nullable display/category is nil-last in both directions; non-nil values use the same pinned fold and scalar lexical ordering. Date, currency and description use their actual canonical key. Amount sorting first groups by native currency code ascending, then uses exact native amount in the requested direction within that currency; it never compares Money across currencies. Default order is newest source date first. Ties use stable opaque durable document/import identity, independently proven source ordinal within document, then immutable transaction identity. Missing optional date/ordinal is last. No ordinal, chronology or cross-document historical chronology is invented. A new sortable key requires an explicit null/type/order contract.

Compute totals over all `F`, independent of viewport or selection, partitioned by native currency **and** accepted financial domain/effect. Do not combine bank cash movement with card purchase/payment liability effects as a spending/income total. Withhold an aggregate when its effect mapping is unaccepted. Use exact Money arithmetic within an accepted partition. A successful empty `F` has no currency-total rows; unavailable snapshot and invalid filter are distinct states. Selection survives only while its canonical member remains in `F`; otherwise it becomes nil and the inspector clears. Collapsing the inspector mutates neither membership, totals nor selection.

The independent oracle enumerates `R` and the predicate/order directly, never production filtering. Required cases cover empty/whitespace query, literal punctuation, composed/decomposed accents, locale-independent case folds, nil/empty fields, multiple allowed fields, unknown values, combined group/search, equal keys, nil-last both directions, multiple currencies, stale generation and selection removed by filtering. A hidden-field match; regex/token-OR behavior; omitted required term; lost source ordinal; cross-currency amount ordering; locale dependence; wrong null position; or viewport-only totals falsifies the proposal.

<a id="packet-sprint89-native-acceptance-procedure"></a>
### Sprint 89 independent native acceptance procedure

This procedure is a proposed runtime gate, not evidence of a pass. The data lane supplies the trusted `R` oracle above: AND groups, OR values, transient normalized case/diacritic-folded multi-term search over the frozen display fields, stable source-ordinal/durable-identity order, and native-currency plus accepted bank/card-domain/effect totals without conversion or grand total.

1. Freeze `R`, provider generation, filter specification, expected membership/order/totals and an opaque oracle hash.
2. Exercise pointer and keyboard date/account/currency/direction/category/search/sort/reverse/inspector/selection/clear; compare visible output to the oracle.
3. Resize, collapse/reopen inspector and change focus. Selection persists only while a member; otherwise it becomes explicit nil and no substitute row is selected.
4. Check Tab/Shift-Tab, arrows, Space/Return as native-owned, shortcut collisions, and absence of implicit import or financial write.
5. Check complete readable Money/currency, useful icon names/tooltips, visible sort/filter scope and count, and focus distinct from selection.
6. Check broad/narrow target widths, no clipping/overlap, readable contrast and no colour-only financial semantics; preserve actual action visibility.
7. For empty/loading/unavailable/stale generation, require truthful enabled state and no stale totals/selection or fabricated zero Money.
8. Use adversarial presentation text only through the oracle: membership may change; source fields never do.
9. Store only a privacy-safe manifest: build, opaque generation, case/oracle hash, counts and observed interaction result/failure; never values, rows, text, IDs, paths or sensitive screenshots.

Actual Transactions focus, useful keyboard interaction, resize/readability, selection and panel cancellation still require observation. This is a bounded owner-usability check; no discovery text establishes a native pass.
