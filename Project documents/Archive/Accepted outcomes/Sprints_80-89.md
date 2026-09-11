# Accepted outcomes — Sprints 80-89

Historical collection, not current implementation or execution authority. [Current state](../../PROJECT_STATE.md) owns the snapshot. Ordering inherits [Guide rule F](../../Project_Guide.md#documentation-order): known acceptance dates descending, then recorded sequence or natural sprint ID descending as display order. Undated records follow; original evidence interiors are unchanged. A review/observation date is not assigned as an acceptance date. Repeated historical summaries preserve their own limitations and may describe superseded support, fixture policy or migration state. ADR-046 and current scope decisions control all new work.

For repeated records of one outcome, the original state record precedes roadmap detail, then snapshot excerpts in their original source sequence. This is a display tie-break, not a second acceptance chronology. Cross-cycle compiled snapshots and unnumbered records without one acceptance date are separate historical context, ordered by stable record key under Guide rule I. Their placement does not attribute every contained fact to this cycle.

## Index

- [Accepted Sprint 88 — App Shell and Workflow Decomposition — 2026-09-11](#sprint-88) — 2026-09-11
- [Sprint 88 roadmap acceptance detail](#roadmap-sprint-88) — 2026-09-11
- [Historical SHELL88 proposal and acceptance alignment](#historical-shell88-blueprint) — 2026-09-11
- [Accepted Sprint 87 — Coordinated Swift-6 Migration — 2026-09-10](#sprint-87) — 2026-09-10
- [Sprint 87 roadmap acceptance detail](#roadmap-sprint-87) — 2026-09-10
- [Accepted Sprint 86 — TEST-PR Strict-Concurrency Test Correction — 2026-09-10](#sprint-86) — 2026-09-10
- [Sprint 86 roadmap acceptance detail](#roadmap-sprint-86) — 2026-09-10
- [Accepted Sprint 85 — PR-3 Dependency Concurrency Boundary — 2026-09-10](#sprint-85) — 2026-09-10
- [Sprint 85 roadmap acceptance detail](#roadmap-sprint-85) — 2026-09-10
- [Accepted Sprint 84 — PR-2 SQLite / Provider / Migration Ownership — 2026-09-10](#sprint-84) — 2026-09-10
- [Sprint 84 roadmap acceptance detail](#roadmap-sprint-84) — 2026-09-10
- [Accepted Sprint 83 — Serial Batch Import and Multi-File Drag-and-Drop — 2026-09-10](#sprint-83) — 2026-09-10
- [Sprint 83 roadmap acceptance detail](#roadmap-sprint-83) — 2026-09-10
- [Accepted Sprint 82 — Serial Unified Import Centre Foundation — 2026-09-10](#sprint-82) — 2026-09-10
- [Sprint 82 roadmap acceptance detail](#roadmap-sprint-82) — 2026-09-10
- [Accepted Sprint 81 — PR-1 Staging and Runtime Publication Ownership Seam — 2026-09-10](#sprint-81) — 2026-09-10
- [Sprint 81 roadmap acceptance detail](#roadmap-sprint-81) — 2026-09-10
- [Sprint 80 accepted discovery](#sprint-80) — 2026-08-28

---

<a id="sprint-88"></a>

## Accepted Sprint 88 — App Shell and Workflow Decomposition — 2026-09-11

Chat accepts Sprint 88 (`FW-P2-67`) at implementation commit `4f5eeb7b11c0f5879204a06ae9f08045304342b5` (parent documentation closure `4973d2d2507ae5891bfa593b359af2b9393e5fa1`). Sprint 88 is the latest accepted numbered implementation. Acceptance token: `SPRINT_88_APP_SHELL_DECOMPOSITION_ACCEPTED`.

- **Verified repository boundary:** exactly one implementation commit after the parent closure; seven paths, 632 additions / 315 deletions: `AppDestinationContainer.swift`, `AppShellPresentation.swift`, `ContentView.swift`, `ImportCentreFooterRenderer.swift`, `LedgerForge.xcodeproj/project.pbxproj`, `LedgerForgeTests/LedgerForgeTests.swift`, and `Services/ApplicationHydrationWorkflow.swift`.
- **Accepted ownership:** behavior-preserving structural shell/sidebar/contextual-toolbar presentation, lazy selected-destination construction, presentation-only Import Centre footer and stateless `@MainActor` hydration-invocation seam. `ContentView` retains root state, selection, feature view-model lifetimes, importer presentation, root lifecycle/tasks and workflow callbacks. `LedgerForgeApp` retains persistence bootstrap and `WindowGroup`; ADR-024 `RepositoryStoreHydrator` remains the sole persistence-to-runtime authority. MainActor `ProductionImportCentre` / `ImportCentreCoordinator` retains serial ownership, one active preparation, explicit per-statement review/confirmation and existing cancellation, skip, retry, recovery, password, source-snapshot and duplicate behavior.
- **Preserved boundaries:** no financial/source semantics, reader/parser/normalizer/routing, repository/provider financial persistence, duplicate/equivalence, migration, ADR architecture, Swift settings or UI design change. No Sprint 88A, R1 Transactions implementation, parallel preparation or FW-P2-77 consolidation. V17 and native Swift 6 remain current; ADR-046 remains current source/reliability authority.
- **Chat-accepted execution evidence, reused without a new run:** focused **261 definitions / 286 expanded executions / 29 suites**; authoritative complete TestPlan **518 definitions / 576 expanded executions / 79 suites**; both with zero failures, skips or expected failures. Exactly two definitions were added, no prior test identifiers removed and no parameter multiplicity reduced. Debug and optimized Release passed, with zero new compiler source warnings/errors reported. The existing TestPlan corpus gate passed all six provider/order campaigns: 127 carriers, 103 logical statements, 3,165 canonical transactions and 5,286 representation transactions, preserving accepted corpus/oracle/semantic digests. A separate corpus campaign was `NOT_REQUIRED` because no shared financial/source boundary changed.
- **Accepted durable/native evidence:** ordinary same-database quit/relaunch, verified SQLite and complete canonical hydration passed; all 17 migration identities remained preserved, integrity was OK, foreign-key violations were zero and Current Database remained unchanged across the durable gate. All six destinations, contextual navigation/financial display, basic Transactions search/Tab focus, Salary/Settings, Developer Console gating, DEBUG profile warning/acknowledgement and unavailable startup were checked. Final-candidate authentic CSV preparation/cancellation covered 97 transactions with zero accepted durable residue; explicit confirmation persisted 1 account, 97 transactions, 1 document and 1 completed import session. Serial batch review held the second item Pending while the first prepared 62 transactions; Skip advanced to the second item's 178 transactions; Cancel Current yielded 1 skipped / 1 cancelled and no additional accepted financial data.
- **Evidence containment/binding:** the accepted report records all 140 registered originals byte-for-byte unchanged and 457 committed files matching frozen validation inputs. Ignored local build evidence is not published by this documentation closure.
- **Accepted bounded limitations:** physical resize interaction was not separately completed; existing frame/minimum-size constraints remained unchanged. Transient loading was covered through preserved source and focused tests rather than a separately captured native screen. Native selection required explicit user assistance. The agent thread limit rejected a fresh independent Sol reviewer; bounded Terra/Luna and primary-session reviews completed. Chat accepted these limitations; they did not falsify Sprint 88.
- **Queue and continuation:** completed `FW-P2-67` is removed from the active queue. Sprint 89 remains the next planned position in the [current roadmap](../../Sprint%20roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md), **PLANNED / NOT YET CHAT-AUTHORIZED**. This closure authorizes no Sprint-89 implementation; a fresh Chat entry review and P0 → P1 → P2 → P3 triage are required before any execution prompt. FW-P2-77 organization and FW-P2-51 bounded parallel preparation remain separate unscheduled work. SC-01 / UI-UX Designer work remains separate design work; LF-UI-2026-09-R1 authority is unchanged.
- **Personal-v1:** **UNDECLARED / NOT CERTIFIED**.

---

<a id="roadmap-sprint-88"></a>

### Sprint 88 — App Shell and Workflow Decomposition

Completed queue: `FW-P2-67` (removed from active queue).

**ACCEPTED on 2026-09-11** under `SPRINT_88_APP_SHELL_DECOMPOSITION_ACCEPTED`, at implementation commit `4f5eeb7b11c0f5879204a06ae9f08045304342b5` (parent documentation closure `4973d2d2507ae5891bfa593b359af2b9393e5fa1`). The seven-path, behavior-preserving extraction separates shell/sidebar/contextual-toolbar presentation, lazy selected destinations, Import Centre footer presentation and a stateless MainActor hydration-invocation seam. `ContentView` retains state, selection, model lifetimes, importer/lifecycle/tasks and callbacks; `LedgerForgeApp`, ADR-024 `RepositoryStoreHydrator` and the MainActor serial Import Centre retain their authority, including one active preparation and explicit per-statement review/confirmation.

Chat accepted focused 261 definitions / 286 expanded executions / 29 suites and complete TestPlan 518 definitions / 576 expanded executions / 79 suites, with zero failures, skips or expected failures; Debug and optimized Release; the existing six-campaign authentic-corpus gate; native destination/import parity; and durable same-database SQLite relaunch with canonical hydration, all 17 migration identities, integrity and foreign-key checks. CSV cancellation left zero accepted residue; explicit confirmation persisted 97 transactions; the 62/178-transaction serial batch ended with 1 skipped / 1 cancelled and no additional accepted financial data. [PROJECT_STATE](../../PROJECT_STATE.md) records the accepted evidence and containment/binding details. This documentation closure reuses that evidence without an executable run.

Accepted limitations: physical resize was not separately completed, transient loading used preserved-source/focused-test coverage, native selection needed user assistance, and the thread limit prevented a fresh independent Sol reviewer; bounded Terra/Luna and primary-session reviews completed. These limitations did not falsify Sprint 88. No migration, new ADR, financial/source or Swift-setting change, Sprint 88A, R1 implementation or parallel preparation; V17, ADR-046, native Swift 6 and Personal-v1 UNDECLARED / NOT CERTIFIED remain unchanged. FW-P2-77 remains separately unscheduled; the [historical SHELL88 blueprint](#packet-shell88-blueprint) does not authorize its optional phase 5.

---

<a id="historical-shell88-blueprint"></a>

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
| 5 | [FW-P2-77](../../FUTURE_WORK.MD#fw-p2-77) naming/groups only after parity | Resource and target membership | Xcode/path-consumer review |

**Sprint-88 acceptance update — 2026-09-11:** The static ownership gate, characterization and bounded native parity are satisfied by accepted Sprint 88 at `4f5eeb7b11c0f5879204a06ae9f08045304342b5`, with limitations recorded above. Provider, activity-gate, hydrator, Import Centre and actor-publication authority/semantics remain preserved. Phase 5 source-tree organization remains a separate unscheduled queue decision under FW-P2-77 and was excluded from Sprint 88.

---

<a id="sprint-87"></a>

## Accepted Sprint 87 — Coordinated Swift-6 Migration — 2026-09-10

Chat accepts Sprint 87 (`FW-P2-76`) at implementation commit `93c068c23027a8cd59753ac4ac916e6cee75adbf`. Sprint 87 remains an accepted prior numbered implementation; Sprint 88 above is now the latest accepted numbered implementation.

- **Repository continuation baseline:** `b2f7ac2a6a517c1365b93274e2ba868b5068a7a4` contains only the subsequent user-approved Xcode serialization change: quote removal from eleven existing UI-asset membership exclusion strings. It does not change Sprint 87's accepted implementation identity.
- **Accepted boundary:** all native targets are Swift 6. Accepted Sprint-81 through Sprint-87 ownership, serial Import Centre behavior and financial/source semantics remain preserved. No Sprint 87A, schema migration or new ADR; V17 and the accepted ADRs remain current, with ADR-046 governing parser/source authority.
- **Post-Swift-6 static entry gate:** Chat revalidated the accepted implementation/current head. `LedgerForgeApp` owns persistence bootstrap and `WindowGroup` creation; `ContentView` still owns shell/navigation, availability presentation, feature view-model lifetimes, Import Centre presentation and startup hydration invocation. `RepositoryStoreHydrator` remains ADR-024's sole persistence-to-runtime boundary; `ProductionImportCentre` / `ImportCentreCoordinator` remains MainActor-owned. Sprint-87 annotations state existing ownership and do not introduce a workflow architecture.
- **Authorized continuation:** completed `FW-P2-76` leaves the active queue. Sprint 88 — App Shell and Workflow Decomposition (`FW-P2-67`) is **CURRENT / CHAT-AUTHORIZED** under `ACCEPT_SPRINT_87_AND_CONTINUE_TO_88`. Its static post-Swift-6 gate is satisfied; native behavioral parity remains required Sprint-88 acceptance evidence. Characterize the exact current shell before product edits, then extract established structural/presentation and narrowly named startup-invocation seams while preserving existing owners and behavior. No R1 redesign, Sprint-89 work, FW-P2-77 consolidation or financial/source change is authorized. Publish one candidate and stop for Chat acceptance before Sprint 89.
- **Personal-v1:** **UNDECLARED / NOT CERTIFIED**. Sprint 89 and the prepared 90–99 / 100–109 sequence remain unchanged; Sprint 100 remains LedgerForge 1.0 Personal Adoption Validation & Certification.

---

<a id="roadmap-sprint-87"></a>

### Sprint 87 — Coordinated Swift-6 Migration

Completed queue: `FW-P2-76` (removed from active queue).

**ACCEPTED on 2026-09-10** under `ACCEPT_SPRINT_87_AND_CONTINUE_TO_88`, at implementation commit `93c068c23027a8cd59753ac4ac916e6cee75adbf`. The subsequent user-approved continuation head `b2f7ac2a6a517c1365b93274e2ba868b5068a7a4` changes only quoting on eleven existing UI-asset membership exclusion strings and does not change the accepted implementation identity. All native targets are Swift 6. No Sprint 87A, migration or new ADR; V17, accepted ownership/financial semantics and Personal-v1 UNDECLARED / NOT CERTIFIED remain unchanged. [PROJECT_STATE](../../PROJECT_STATE.md) owns the accepted outcome.

---

<a id="sprint-86"></a>

## Accepted Sprint 86 — TEST-PR Strict-Concurrency Test Correction — 2026-09-10

Chat accepts Sprint 86 at implementation commit `022d436fc4563be9b0967ac2751e6114a31474c1` (parent `dee5968c8268e69f8540aefc73613c28736d01ec`). Sprint 86 remains an accepted prior numbered implementation; Sprint 88 above is now the latest accepted numbered implementation.

- **Accepted boundary:** 21 test files gained actor-aware fixture/assertion ownership, actor-owned mutable provider/state captures, checked Sendable subprocess callback state and bounded confirmation/snapshot synchronization. Production/runtime source, project settings, shared corpus machinery, independent source oracles, migrations and resources remained unchanged. No Sprint 86A, migration, new ADR or language-mode switch; V17 remains current and all native targets remain Swift 5 at this acceptance boundary.
- **Verified strict and focused evidence:** the current baseline contained 11 source error locations and 350 warning headers (307 distinct reported location/message combinations). Final Swift-6 complete-strict object/module generation passed for 83 unit-test files, two UI-test files and 18 native subprocess/shared inputs with zero source errors or warnings. Three redundant upcoming-feature notices were reported separately. All 21 corrected suites passed 181 tests; the reviewed snapshot-priority repair passed its five-test rerun with no priority-inversion notice.
- **Verified TestPlan and inventory:** the authoritative frozen-candidate invocation passed **515 definitions / 79 suites / 573 expanded executions**, with zero failures, skips or expected failures. All 516 registered definitions and 12 parameterized declarations / 70 argument executions were preserved; only the explicitly authorized conditional global campaign was excluded from the invocation, with no checked-in TestPlan skip. Independent financial/source assertions were unchanged; the single removed dispatch-timeout expectation was replaced by a throwing structured watchdog. No unsafe suppression or serialization marker was added, and test `@unchecked Sendable` uses decreased from nine to eight.
- **Accepted proportional validation:** the separate complete global corpus/provider-order campaign, Debug/Release product runtime qualification, separate optimized Release compilation and durable startup were `NOT_REQUIRED` because this was test-only work with production and corpus machinery frozen. Native Debug build-for-testing passed; no integrated Swift-6 product/runtime or fresh global-campaign certification was claimed. All 453 committed blobs matched the frozen candidate and all 140 registered originals retained their bytes. The ignored `build/sprint86-test-pr/acceptance-manifest.json` retains the detailed evidence; this explicit acceptance supersedes its historical candidate label.
- **Authorized continuation:** completed `FW-P2-75` leaves the active queue. Chat authorizes Sprint 87 — Coordinated Swift-6 Migration (`FW-P2-76`) across the app, unit tests, UI tests and subprocess helper, preserving accepted ownership and financial semantics. Comprehensive compiler, focused/full TestPlan, complete authentic-corpus/provider-order, Debug/Release, native Import Centre, durable relaunch/hydration, migration, privacy and signing qualification is required. Stop for Chat on a financial-semantic change or new architectural/migration requirement; publish one candidate and return for acceptance before Sprint 88.
- **Personal-v1:** **UNDECLARED / NOT CERTIFIED**. The accepted pre-100 roadmap and Sprint-100 personal-adoption certification milestone remain unchanged; this acceptance does not authorize Sprint 88–100 product work.

---

<a id="roadmap-sprint-86"></a>

### Sprint 86 — TEST-PR Strict-Concurrency Test Correction

Historical queue origin: `FW-P2-75` (removed from the active queue).

**ACCEPTED on 2026-09-10.** Implementation commit `022d436fc4563be9b0967ac2751e6114a31474c1`. The test/support-only correction and its proportional qualification are recorded in `PROJECT_STATE.md`; production bytes and native Swift-5 settings remained frozen. The accepted validation contract below is retained as history.

Make unit-test ownership/synchronization honest for strict migration. Preserve independent source/test oracles and assertions; never weaken tests merely to remove diagnostics.

Treat validation as test/support-only: freeze production-source bytes; reproduce current strict-concurrency test diagnostics and prove zero unresolved Swift-6-blocking test diagnostics; preserve test/suite inventory, skips, expected-failure policy, assertion strength and independent financial/source oracles; run one authoritative complete TestPlan on the frozen candidate. Authentic-corpus campaigns are required only if the corpus/oracle/shared validation harness changes; otherwise record `NOT_REQUIRED` because production financial behavior and corpus machinery are unchanged. Debug/Release product runtime qualification and durable startup are `NOT_REQUIRED` for test-only changes. **STOP and return to Chat if production/runtime changes are required.**

---

<a id="sprint-85"></a>

## Accepted Sprint 85 — PR-3 Dependency Concurrency Boundary — 2026-09-10

Chat accepts Sprint 85 at implementation commit `b4e4e6ffb14deccef238352a6ef834514a2a37c2` (parent `8d2dafd29de543660300ac8f37f16a152603f1f5`). Sprint 85 remains an accepted prior numbered implementation; Sprint 88 above is now the latest accepted numbered implementation.

- **Accepted decisions:** `ZIPFOUNDATION_DECISION = LOCAL_CORRECTION`; vendored ZIPFoundation 0.9.20 closes its two native Swift-6 diagnostics by making two unchanged-value globals immutable. `LEGACYXLS_POLICY = SERIALIZED_PROCESS_LOCAL`; one bounded owner retains the complete source-buffer/open/read/copy/close lifetime and cancellation checks around non-interruptible C work. No libxls concurrent-reentrancy claim is made.
- **Verified qualification:** 19 OOXML and eight LegacyXLS focused tests passed. The frozen TestPlan invocation passed **515 definitions / 79 suites / 573 expanded executions**, with zero failures, skips or expected failures; all prior definitions except the single explicitly authorized conditional global campaign executed, plus 11 added tests. Complete affected authentic Axis bank, HDFC bank-account and Axis credit-card source/oracle and provider gates passed. The checked-in TestPlan and selection settings remain unchanged. Debug and optimized Release, dependency linkage, signature/privacy and bundle containment checks passed; all 452 committed file blobs matched the frozen candidate and all 140 registered originals retained their bytes and registered paths.
- **Proportional validation and remaining boundaries:** the all-family/provider-order campaign and durable startup were `NOT_REQUIRED` because the implementation stayed within the XLS/XLSX dependency surfaces and changed no shared extraction/routing/snapshot/persistence/startup boundary. No fresh global campaign digest is claimed. The strict production probe has zero dependency-attributable diagnostics; five other production diagnostics remain under `FW-P2-76`. At the Sprint-85 boundary, three test capture warnings and the pre-existing `SourceContentSnapshotTests` QoS advisory remained under `FW-P2-75`; Sprint 86 above subsequently resolved them. The ignored `build/sprint85-pr3/acceptance-manifest.json` retains the detailed evidence; this explicit acceptance supersedes its historical candidate label.
- **Preserved state and authorized continuation:** no Sprint 85A, migration, new ADR or language-mode switch. V17 remains current with accepted V1–V17 identity inputs unchanged; native product targets remain Swift 5. Completed `FW-P2-74` leaves the active queue. Chat authorizes Sprint 86 — TEST-PR Strict-Concurrency Test Correction (`FW-P2-75`), test/support-only with production bytes frozen, independent assertions/oracles and test inventory preserved, and a mandatory stop if production/runtime changes are required. Return for Chat acceptance before Sprint 87.
- **Personal-v1 planning decision — 2026-09-10:** adoption/certification remains **UNDECLARED / NOT CERTIFIED**. By explicit user decision, personal adoption is targeted for Sprint 100 after the required pre-1.0 product boundaries, including verified backup/restore, bounded current Al Dar Salary/planning completion, current holdings/valuation and current market FX/net-worth. The prepared [90–99](../../Sprint%20roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md) and [100–109](../../Sprint%20roadmap/Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md) roadmaps and `FW-P0-26` own the detailed sequence and certification matrix. This is future planning, not implemented state, certification, architecture acceptance or a migration allocation.

---

<a id="roadmap-sprint-85"></a>

### Sprint 85 — PR-3 Dependency Concurrency Boundary

Historical queue origin: `FW-P2-74` (removed from the active queue).

**ACCEPTED on 2026-09-10.** Implementation commit `b4e4e6ffb14deccef238352a6ef834514a2a37c2`.

Accepted decisions: `ZIPFOUNDATION_DECISION = LOCAL_CORRECTION` and `LEGACYXLS_POLICY = SERIALIZED_PROCESS_LOCAL`. The bounded dependency correction preserves financial/source semantics, adds no generic third-party concurrency framework, migration, ADR or Swift-6 product switch. Qualification and its explicit exclusions are recorded in `PROJECT_STATE.md`.

The accepted Sprint-85 validation policy remains recorded below as its acceptance contract:

Use dependency-proportional validation: reproduce and resolve exact dependency diagnostics/policy; run focused dependency/reader tests and every affected authentic XLSX family for ZIPFoundation changes and XLS family for LegacyXLS/libxls changes; then run one authoritative TestPlan on the frozen candidate and compile Debug and optimized Release. The complete all-family/provider-order campaign is required only if shared extraction, routing, snapshots, common persistence mapping or another boundary beyond the affected XLS/XLSX dependency surfaces changes. Durable startup/relaunch is required only if persistence, provider/bootstrap, migration, hydration or startup changes. Record `NOT_REQUIRED` with the evidence-based reason for each omitted broad gate; preserve source/oracle correctness.

**Explicit TestPlan invocation clarification:** for dependency-only Sprint 85, Chat authorizes excluding only the conditional global authentic-corpus/provider-order campaign from the invocation. Every other TestPlan test must run. Keep the checked-in TestPlan and tests unchanged, and report the excluded campaign explicitly as `NOT_REQUIRED`; this is not an unchanged full-plan execution claim. If the broader shared-boundary trigger applies, include the campaign.

Chat has accepted that implementation candidate and authorized Sprint 86. The campaign-specific validation amendment supersedes broader repetitive wording in the original 84–87 prompt.

---

<a id="sprint-84"></a>

## Accepted Sprint 84 — PR-2 SQLite / Provider / Migration Ownership — 2026-09-10

Chat accepts Sprint 84 at implementation commit `a4dd6929a2282cc94c850eb1dccf350b1ee5c8a1` (parent `af2d1949c6e9a73af3bb004422b72882d28195e2`). Sprint 84 remains an accepted prior numbered implementation; Sprint 88 above is now the latest accepted numbered implementation.

- **Accepted ownership boundary:** one synchronous SQLite owner protects connection, statement, backup, migration and compound-transaction lifetimes; copied row values leave that owner. Provider-generation validity protects each check and operation and drains active operations before invalidation. The immutable migration registry and Sendable closures, MainActor provider defaults and shared helper/database sources have explicit ownership.
- **Preserved contracts:** financial parsing, source snapshots, provider parity, transaction semantics and canonical hydration remain unchanged. Accepted V1–V17 identities and integrity are preserved, with no schema change or V18. Native targets remain in Swift 5; PR-3, TEST-PR and the final coordinated Swift-6 switch are not accepted by this closure.
- **Verified qualification:** focused PR-2 validation passed 103 definitions / 155 expanded executions. The frozen complete TestPlan passed **505 definitions / 79 suites / 563 expanded executions**, with zero failures, skips or expected failures; all 497 prior definitions remain, plus eight ownership tests. All seven authentic-family gates and six provider/order campaigns passed over 127 carriers / 103 logical statements / 3,165 canonical transactions / 5,286 representation transactions, preserving semantic digest `1464f47c1568438fb33fcd7743d9a094944c11d4f6eb15fced7a889ed5ea35a3`. Debug and optimized Release, bundle containment/signing, and two verified SQLite same-database launches with canonical hydration, 17 migration records and integrity checks passed. All 140 private original files retained their bytes and path inventory.
- **Strict evidence and limits:** complete strict-concurrency probes closed all PR-2 diagnostics in app and helper. Two ZIPFoundation diagnostics remain for PR-3; the test-target and five other production readiness diagnostics remain separately owned by `FW-P2-75` and `FW-P2-76`. The eight ownership tests include bounded scheduling observations; they do not claim exhaustive race scheduling. The retained ignored `build/sprint84-pr2/acceptance-manifest.json` records the frozen candidate and local evidence; this explicit acceptance supersedes its historical candidate label. This documentation closure adds no executable validation.
- **Authorized continuation:** completed `FW-P2-73` leaves the active queue. Chat has authorized Sprint 85 — PR-3 Dependency Concurrency Boundary (`FW-P2-74`) and determined that no higher-priority verified defect currently preempts it. The current roadmap records the dependency-proportional Sprint-85 validation amendment, test/support-only Sprint 86 and comprehensive Sprint 87. Sprint 85 must return for Chat acceptance before Sprint 86. Personal-v1 remains **UNDECLARED / NOT CERTIFIED**.

---

<a id="roadmap-sprint-84"></a>

### Sprint 84 — PR-2 SQLite / Provider / Migration Ownership

Historical queue origin: `FW-P2-73` (removed from the active queue).

**ACCEPTED on 2026-09-10.** Implementation commit:
`a4dd6929a2282cc94c850eb1dccf350b1ee5c8a1` (parent `af2d1949c6e9a73af3bb004422b72882d28195e2`).

The accepted Swift-5 correction gives SQLite operations and lifetimes, provider-generation validity, migration registries/closures and app/helper shared sources explicit bounded ownership. It preserves financial behavior, provider parity, hydration and accepted V1–V17 identities, with no schema migration. Focused and complete TestPlan, complete authentic/provider-order, strict app/helper, Debug/Release and durable relaunch evidence is recorded in `PROJECT_STATE.md`.

---

<a id="sprint-83"></a>

## Accepted Sprint 83 — Serial Batch Import and Multi-File Drag-and-Drop — 2026-09-10

Chat accepts Sprint 83 at implementation commit `adcf83f52d309ddac18d95f0321d0c0f6120dd29` (parent `057d70b6f39929735401d5211cd180db162c94cc`). Sprint 83 remains an accepted prior numbered implementation; Sprint 88 above is now the latest accepted numbered implementation.

- **Accepted intake and ownership:** the shared @MainActor Import Centre coordinator now owns an ordered serial queue of length N. Single-file import uses the same path with N = 1. Multi-file picker and drag-and-drop intake preserve the received selection/provider order, including distinct occurrence identity for repeated URLs; asynchronous drop-provider completion cannot reorder the queue. Exactly one item may own active preparation, and there is no parallel preparation.
- **Per-item control and isolation:** each statement retains independent preparation, progress, review, account/card choice, duplicate/rejection and terminal state. Review and explicit confirmation remain per item. Skip, cancel current, cancel batch, retry and continue preserve cancelled-task draining, stale-callback rejection and one-shot confirmation. A failed, rejected, skipped or cancelled file cannot contaminate another item or undo an already committed item. The batch summary reports actual per-file outcomes; there is no batch-wide atomicity claim.
- **Preserved contracts:** provider-owned persistence and canonical RepositoryStoreHydrator publication remain the accepted commit/hydration boundary. ImportEngine financial behavior, account/card/partial/recovery outcomes, duplicate/equivalence semantics, ADR-041 immutable snapshots and exact source-byte fingerprints, and ADR-046 authentic-corpus authority are preserved. No reader, detector, classifier, parser, normalizer or financial-semantic change was included. No schema change, migration or new ADR was introduced; current migration remains V17 with V1–V16 immutable, and Swift 5 language mode is retained.
- **Verified repository boundary:** the accepted eight-path implementation comprises `ContentView.swift`, `Import/Coordinator/ImportCentreCoordinator.swift`, `Import/Presentation/StatementDropIntakeAdapter.swift`, `Views/ImportCentreBatchViews.swift`, three Import Centre/drop-intake test files and their Xcode project registration. Repository structure, code scope, test definitions and the independent review were verified against the accepted implementation. These checks are distinct from executable qualification.
- **Final executable qualification — local execution evidence:** the retained canonical TestPlan result `LedgerForge-validation.zL9XOs` records **497 definitions / 78 suites / 555 expanded executions / 0 failed / 0 skipped / 0 expected failures**. All seven authentic-family gates executed and passed. The complete registered corpus covers **127 carriers / 103 logical statements / 3,165 canonical transactions / 5,286 representation transactions**. All six In-Memory/SQLite and chronological/reverse/deterministic-mixed campaigns match semantic digest `1464f47c1568438fb33fcd7743d9a094944c11d4f6eb15fced7a889ed5ea35a3`.
- **Build, native and durable evidence — local execution evidence:** Debug and optimized Release builds passed. Native picker and drop checks exercised authentic CSV, PDF, XLS and XLSX inputs, explicit confirmation, skip/cancel, exact replay, per-file isolation and truthful summaries; an unsupported original email carrier was rejected without accepted residue. Direct SQLite checks and ordinary same-database quit/relaunch verified provider reconstruction, canonical hydration, 17 migration records and unchanged state across all 52 tables. These disposable-database checks do not establish migration compatibility or personal-v1 adoption.
- **Evidence attribution and retention:** physical drag gestures and one CSV confirmation were user-assisted after Computer Use failures; the resulting native UI and SQLite state were independently inspected. Other native controls were exercised through direct computer use. After the final test-only assertion restoration, all 450 other repository files and all 28 retained application-bundle files were verified unchanged, preserving the earlier build/native/durable evidence with its original binary identities; focused and complete TestPlan/corpus qualification were rerun for the final tests. The retained `build/sprint83-batch-import/acceptance-manifest.json` records the pre-Chat-review campaign and its limitations; its historical candidate label is superseded by this explicit Chat acceptance. This documentation closure performs no new executable validation.
- **Remaining planning boundary:** completed `FW-P1-20` and `FW-P1-21` leave the active queue. Bounded parallel preparation remains unscheduled research under `FW-P2-51`, without approval to execute. Sprint 84 has since been accepted and Sprint 85 authorized as recorded above. No financial source-support expansion or personal-v1 certification is implied.

---

<a id="roadmap-sprint-83"></a>

### Sprint 83 — Serial Batch Import and Multi-File Drag-and-Drop

Historical queue origins: `FW-P1-20` + `FW-P1-21` (removed from the active queue).

**ACCEPTED on 2026-09-10.** Implementation commit:
`adcf83f52d309ddac18d95f0321d0c0f6120dd29` (parent `057d70b6f39929735401d5211cd180db162c94cc`).

The accepted Swift-5 implementation extends the shared serial coordinator to ordered queue length N, with the same path for single-file import, multi-file picker and drag-and-drop. Received intake order and per-occurrence identity are preserved. One active preparation, independent per-item review and explicit confirmation, skip/cancel/retry/continue, per-file failure isolation and truthful batch summaries are established. Provider-owned persistence and canonical hydration remain unchanged; no batch-wide atomicity is implied.

Repository/code/test verification and the retained final TestPlan, complete authentic-corpus, Debug/Release, native interaction and durable same-database relaunch evidence are classified in `PROJECT_STATE.md`. Native drag gestures and one CSV confirmation were user-assisted. No reader, parser, normalizer, financial-semantic, schema/migration or ADR change was included; V17 and Swift 5 remain current. Bounded parallel preparation remains unscheduled research under existing `FW-P2-51` and is not approved by this acceptance.

---

<a id="sprint-82"></a>

## Accepted Sprint 82 — Serial Unified Import Centre Foundation — 2026-09-10

Chat accepts Sprint 82 at implementation commit `d239f939088b67e5a90c65117f08592891be17bb` (parent `17944e104081279ce6267f26a0bac5d8468a3247`). Sprint 82 remains an accepted prior numbered implementation; Sprint 88 above is now the latest accepted numbered implementation.

- **Accepted outcome:** one shared @MainActor serial Import Centre coordinator owns a deterministic queue of length one. Each item retains stable identity and independent source, preparation, progress, review, account/card choice, duplicate/rejection, confirmation, persistence, terminal and recovery state. Preparation, review, explicit confirmation, provider-owned persistence and canonical hydration remain distinct stages.
- **Accepted orchestration boundary:** cancellation drains the preparation task and releases `PreparedImport` before confirmation; confirmation is explicit and one-shot; commit is provider-owned and non-cancellable; stale callbacks cannot publish into a different item; shared production ownership is used across import surfaces; no multi-file, drag-and-drop, folder, batch or parallel-preparation workflow was introduced.
- **Preserved financial and repository contracts:** existing ImportEngine preparation/commit/cancel, generic source snapshot and fingerprint provenance, duplicate/equivalence behavior, account/card/partial/recovery outcomes, provider transaction boundaries and canonical RepositoryStoreHydrator publication remain unchanged. No reader, detector, classifier, parser, normalizer, schema, migration, Swift-6 or financial-semantic change was included.
- **Exact implementation boundary:** production changes are limited to `ContentView.swift` and `Import/Coordinator/ImportCentreCoordinator.swift`; project metadata adds the coordinator source; tests are limited to `LedgerForgeTests/ImportCentreCoordinatorTests.swift`.
- **Acceptance evidence:** focused validation covered 16 suites, 127 definitions and 139 expanded executions with all passing; the complete TestPlan covered 76 suites, 479 definitions and 537 expanded executions with all passing. The complete registered authentic corpus covered 127 carriers, 103 logical statements, 3,165 canonical transactions and 5,286 representation rows; all six provider/order campaigns matched semantic digest `1464f47c1568438fb33fcd7743d9a094944c11d4f6eb15fced7a889ed5ea35a3`. Debug and optimized Release builds passed. User-assisted native checks showed protected preview/cancel with no persistence, one explicit CSV confirmation persisting 1 document, 1 import session, 2 fingerprints and 97 transactions, navigation without repeat import, and a final protected preview with visible preparation progress before cancellation. Direct SQLite checks covered all 52 tables; durable startup passed two verified-SQLite/current/hydrated/clean-quit launches with 17 migration records and an unchanged database fingerprint.
- **Digest transcription correction — 2026-09-10:** independent inspection of the retained Sprint-82 `build/sprint82-serial-import-centre/acceptance-manifest.json` confirmed that all six `authentic_corpus.aggregate.campaign_semantic_sha256` entries contain the full 64-character value above, ending `35a3`. Its candidate and publication fields identify Sprint-82 implementation `d239f939088b67e5a90c65117f08592891be17bb`; the manifest SHA-256 is `46d91ac52baff9764d0e5a45eb9929c33a3ab9947d4de716c76074030c0e381e`. The missing final `a3` was corrected from Sprint-82 evidence, not inferred from Sprint 83.
- **Evidence classification:** native picker and button observations were user-assisted; direct SQLite, focused/full-suite, complete-corpus and durable-startup results are repository/local evidence from the accepted implementation campaign. The privacy-safe acceptance manifest remains local validation evidence and is not accepted product state. No personal-v1 adoption or parser-reliability expansion is implied by this sprint.
- **Foundation for Sprint 83:** the serial coordinator, per-item identity/state ownership, cancelled-task draining, explicit confirmation, shared production ownership, duplicate/recovery preservation and absence of parallel preparation established the entry evidence for the now-accepted Sprint 83 above.

---

<a id="roadmap-sprint-82"></a>

### Sprint 82 — Serial Unified Import Centre Foundation

Historical queue origin: `FW-P1-19` (removed from the active queue).

**ACCEPTED on 2026-09-10.** Implementation commit:
`d239f939088b67e5a90c65117f08592891be17bb`.

The accepted Swift-5 implementation establishes one shared @MainActor serial Import Centre coordinator with queue length one, deterministic ordering, per-item identity/state ownership, safe cancellation before confirmation, explicit per-statement confirmation, provider-owned persistence and canonical hydration. It preserves the existing ImportEngine/parser/normalizer, duplicate/equivalence, account/card/partial/recovery and provider contracts; no reader, parser, schema, migration or financial-semantic boundary changed.

This foundation established the entry evidence for the now-accepted Sprint 83: serial coordinator; per-item identity/state ownership; cancelled-task draining; explicit confirmation; shared production ownership; duplicate/recovery preservation; and no parallel preparation. The complete focused coordinator validation, canonical TestPlan, complete registered authentic corpus, native preview/cancel/confirm/navigation checks and durable same-database relaunch evidence are recorded in `PROJECT_STATE.md`.

---

<a id="sprint-81"></a>

## Accepted Sprint 81 — PR-1 Staging and Runtime Publication Ownership Seam — 2026-09-10

Chat accepts Sprint 81 at implementation commit `13552eaf8d22a8e6fcb56fb9a9d7a9dd0892bf91` (parent `f2290532b29b9aa057326929bd695a121d790db0`). Sprint 81 remains an accepted prior numbered implementation; Sprint 88 above is now the latest accepted numbered implementation.

- **Accepted outcome:** explicit MainActor ownership for canonical runtime-store installation and notification methods, with synchronous pure staging retained. Complete snapshots are installed before observers are notified, canonical notification order is preserved, and provider-generation/reconciliation semantics remain unchanged. The central observer-atomicity test was independently assessed as `INDEPENDENT_ENOUGH` and establishes that the first observation sees the complete installed snapshot in canonical order.
- **Exact implementation boundary:** production changes are limited to `Core/AccountStore.swift`, `Core/CardStore.swift`, `Core/CategoryStore.swift`, `Core/DeveloperConsole.swift`, `Core/ImportSessionStore.swift`, `Core/TransactionStore.swift` and `Services/RepositoryStoreHydrator.swift`; test changes are limited to `LedgerForgeTests/DeveloperDiagnosticsTests.swift` and `LedgerForgeTests/RepositoryStoreHydratorTests.swift`.
- **Preserved contracts:** Swift 5 language mode, ADR-024's single persistence-to-runtime hydration boundary and current Migration V17 are unchanged. There is no whole-store blanket actorization, SalaryStore/FundingPlanStore refactor, PR-2/PR-3/TEST-PR work, Swift-6 migration, Import Centre implementation, schema/migration change, parser/source change or financial-semantic change.
- **Acceptance evidence:** Codex's final focused validation reported 66 definitions / 88 expanded executions / 88 passed / 0 failed / 0 skipped. The complete TestPlan reported 468 registered definitions / 75 suites / 526 expanded executions / 526 passed / 0 failed / 0 skipped / 0 expected failures. Codex also reported passing Debug and Release builds; complete authentic/provider campaigns over 127 carriers, 103 logical statements, 3,165 canonical transactions and 5,286 representation transactions with all six provider/order campaigns semantically identical; and two successful ordinary Debug launches against the same verified SQLite database, with complete hydration, clean quit/relaunch, 17 migration records on both launches, and passing integrity/foreign-key checks.
- **Evidence classification and portability:** GitHub/MCP independently verified the committed nine-file scope and observer-atomicity oracle and found no contradictory material evidence. Several retained Codex validation artifacts could not be reopened through MCP because their locations were outside MCP's approved evidence roots; Chat explicitly accepted Sprint 81 notwithstanding that post-hoc portability limitation. The Standing Execution Harness now directs future executions to emit a privacy-safe shared acceptance manifest for cross-tool review without treating it as a substitute for native artifacts.
- **Unchanged qualification:** personal-v1 remains **UNDECLARED / NOT CERTIFIED**. Sprints 82–84 are accepted above; Sprint 85 is the authorized current position under the Chat-approved continuation.

---

<a id="roadmap-sprint-81"></a>

### Sprint 81 — PR-1 Staging and Runtime Publication Ownership Seam

Historical queue origin: `FW-P2-72` (removed from the active queue).

**ACCEPTED on 2026-09-10.** Implementation commit:
`13552eaf8d22a8e6fcb56fb9a9d7a9dd0892bf91`.

The accepted behavior-preserving Swift-5 correction establishes pure synchronous staging and explicit MainActor runtime publication while preserving complete-snapshot installation, provider generations, observer ordering and provider parity. It adds no parallel preparation, Swift-6 switch, Import Centre implementation, schema/migration, parser/source or financial-semantic change.

---

<a id="sprint-80"></a>

### Sprint 80 accepted discovery — Swift 6 and macOS readiness

Sprint 80 is accepted as `SWIFT6_READINESS_COMPLETE` on 2026-08-28. This is a
discovery and documentation outcome, not a production implementation. The
current production implementation remains Sprint 79, the current migration is
V16, ADR-045 remains the latest accepted architecture, and personal-v1 remains
undeclared.

#### Toolchain and current configuration

The accepted readiness evidence was gathered with:

- Xcode 26.6, build 17F113;
- Apple Swift 6.3.3; and
- the macOS 26.5 SDK.

All current native targets remain in Swift 5 mode. The current app concurrency
configuration has approachable concurrency enabled, default MainActor
isolation on the application, and member-import visibility enabled. The
project does not set an explicit `SWIFT_STRICT_CONCURRENCY` value.

#### Strict-readiness evidence

The compiler was reached successfully. Readiness is materially non-clean and
is no longer an infrastructure-only unknown. The accepted evidence is recorded
at cluster level rather than as raw compiler-log output:

- production/app diagnostics include ZIPFoundation dependency errors,
  `SQLiteDatabase` teardown-isolation errors,
  `RepositoryStoreHydrator` staging/domain-isolation errors, runtime-store
  closure/publication warnings, one DEBUG provider-conformance error, one
  Salary-view closure warning and redundant upcoming-feature-configuration
  warnings;
- shared helper/database diagnostics include `DatabaseProvider.shared`
  ownership, migration-registry/global ownership, migration-closure/SQLite
  ownership and helper-global-state issues;
- the authoritative unit-test strict probe found 45 distinct error locations,
  with substantial actor/async/sendability migration work and a large warning
  surface concentrated in test fixtures and support code; and
- the direct UI-test strict probe found zero source errors and zero source
  warnings, with three redundant configuration warnings.

Raw compiler-log noise is not itself governance evidence and is not persisted
here.

#### Accepted migration strategy

The accepted sequence is:

1. do not switch the project to Swift 6 immediately;
2. make behavior-preserving prerequisite ownership corrections under Swift 5;
3. implement the first Unified Import Centre in Swift 5, serially and with
   explicit ownership;
4. do not introduce bounded-parallel preparation until transferable ownership
   and dependency thread-safety are proven;
5. complete the remaining prerequisite corrections after the queue foundation;
6. perform a coordinated Swift-6 strict migration; and
7. complete Swift-6 readiness before personal-v1 adoption.

Full Swift-6 migration is not a prerequisite to begin the serial Unified
Import Centre, but it is required before personal-v1 certification.

#### Bounded prerequisite families

Sprint 80 records four future correction families without implementing any of
them:

- **PR-1 — staging/publication ownership seam:**
  `RepositoryStoreHydrator`, `AccountStore`, `CardStore`, `CategoryStore`,
  `TransactionStore`, `ImportSessionStore` and `DeveloperConsole`. The seam
  must preserve synchronous pure staging, explicitly MainActor-owned runtime
  publication, complete-snapshot installation, observer ordering, provider
  generation authority and SQLite/In-Memory parity. PR-1 is the only
  Swift-6-derived prerequisite required before the serial Unified Import
  Centre.
- **PR-2 — SQLite/provider/migration ownership:**
  `SQLiteDatabase` teardown, `DatabaseProvider` ownership, migration
  registry/global ownership and helper/database shared-source ownership. PR-2
  is required before coordinated Swift-6 migration.
- **PR-3 — dependency boundary:** the ZIPFoundation Swift-6
  correction/upgrade decision and the LegacyXLS/libxls concurrency policy. PR-3
  is required before coordinated Swift-6 migration.
- **TEST-PR — unit-test strict-concurrency correction:** actor-aware fixture
  construction, async-safe test synchronization, subprocess Sendable
  ownership and actor-aware assertions/macros. TEST-PR is required before the
  unit-test target can participate honestly in coordinated strict migration.

#### Unified Import Centre concurrency boundary

The first Unified Import Centre implementation may remain in Swift 5 only when
it preserves all of the following:

- serial preparation;
- explicit MainActor task ownership;
- deterministic queue ordering;
- per-file state ownership;
- security-scoped source lifetime;
- `SourceContentSnapshot` lifetime;
- cancellation before confirmation;
- explicit per-statement confirmation;
- synchronous provider-owned persistence transaction;
- canonical `RepositoryStoreHydrator` publication; and
- no concurrent transfer of `PreparedImport`.

Parallel preparation remains an open architecture decision. It is not approved
by Sprint 80.

#### macOS and target findings

The current product artifact is a macOS-native application using the macOS
26.5 SDK, App Sandbox and selected-file import. The readiness discovery also
found stale/project metadata that remains future work: the app, tests and UI
advertise non-macOS platforms; irrelevant device-family/deployment metadata
remains; the generated macOS plist contains iOS-oriented keys; the Release
bundle contains governance/development residue such as `AGENTS.md`; and an
empty debug-fixture resource container is present.

The following remain deliberate architecture/product decisions for future
work, not Sprint 80 decisions: minimum macOS version; read-only versus
read-write selected-file entitlement; network entitlement ownership; broad
folder access; Bluetooth; Calendars; app groups; app hardened runtime; signed
Release/distribution scope; and UI-test policy.

#### CBQ separation and next gates

The accepted `cbq.credit-card.pdf@1` profile remains separate from Sprint 80.
The authentic July 2026 source reaches CBQ normalization and terminates at
`CBQCreditCardPDFNormalizationError.malformedPreamble` at the
statement-period/preamble boundary. Baseline comparison classifies this as
`PRE_EXISTING_OR_EXTERNAL` relative to Sprint 79. Sprint 80 did not fix or
investigate its source grammar; a deliberate corrective disposition remains
required before personal-v1 certification.

The immediate dependency ordering is: Sprint 80 documentation sync; accepted-
profile CBQ corrective closure; PR-1; Unified Import Centre; PR-2, PR-3 and
TEST-PR; coordinated Swift-6 migration; then personal-v1 certification.
