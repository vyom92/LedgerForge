# Repository State

## Published discovery index — 2026-09-10

**Discovery reconciliation — 2026-09-10:** both read-only discovery rounds are incorporated in the existing [FUTURE_WORK](FUTURE_WORK.MD#discovery-reconciled-into-existing-subject-authorities--2026-09-10), current/prepared roadmaps and R1 DESIGN_HANDOFF. The redundant standalone register is retired. Findings and decision packets remain proposals unless explicitly identified as settled user scope; this documentation does not accept implementation, migrations, source support, a sprint or personal-v1 certification. The existing accepted-state and current-sprint records below remain authoritative.

## Accepted Sprint 87 — Coordinated Swift-6 Migration — 2026-09-10

Chat accepts Sprint 87 (`FW-P2-76`) at implementation commit `93c068c23027a8cd59753ac4ac916e6cee75adbf`. Sprint 87 is the latest accepted numbered implementation.

- **Repository continuation baseline:** `b2f7ac2a6a517c1365b93274e2ba868b5068a7a4` contains only the subsequent user-approved Xcode serialization change: quote removal from eleven existing UI-asset membership exclusion strings. It does not change Sprint 87's accepted implementation identity.
- **Accepted boundary:** all native targets are Swift 6. Accepted Sprint-81 through Sprint-87 ownership, serial Import Centre behavior and financial/source semantics remain preserved. No Sprint 87A, schema migration or new ADR; V17 and the accepted ADRs remain current, with ADR-046 governing parser/source authority.
- **Post-Swift-6 static entry gate:** Chat revalidated the accepted implementation/current head. `LedgerForgeApp` owns persistence bootstrap and `WindowGroup` creation; `ContentView` still owns shell/navigation, availability presentation, feature view-model lifetimes, Import Centre presentation and startup hydration invocation. `RepositoryStoreHydrator` remains ADR-024's sole persistence-to-runtime boundary; `ProductionImportCentre` / `ImportCentreCoordinator` remains MainActor-owned. Sprint-87 annotations state existing ownership and do not introduce a workflow architecture.
- **Authorized continuation:** completed `FW-P2-76` leaves the active queue. Sprint 88 — App Shell and Workflow Decomposition (`FW-P2-67`) is **CURRENT / CHAT-AUTHORIZED** under `ACCEPT_SPRINT_87_AND_CONTINUE_TO_88`. Its static post-Swift-6 gate is satisfied; native behavioral parity remains required Sprint-88 acceptance evidence. Characterize the exact current shell before product edits, then extract established structural/presentation and narrowly named startup-invocation seams while preserving existing owners and behavior. No R1 redesign, Sprint-89 work, FW-P2-77 consolidation or financial/source change is authorized. Publish one candidate and stop for Chat acceptance before Sprint 89.
- **Personal-v1:** **UNDECLARED / NOT CERTIFIED**. Sprint 89 and the prepared 90–99 / 100–109 sequence remain unchanged; Sprint 100 remains LedgerForge 1.0 Personal Adoption Validation & Certification.

## Accepted Sprint 86 — TEST-PR Strict-Concurrency Test Correction — 2026-09-10

Chat accepts Sprint 86 at implementation commit `022d436fc4563be9b0967ac2751e6114a31474c1` (parent `dee5968c8268e69f8540aefc73613c28736d01ec`). Sprint 86 remains an accepted prior numbered implementation; Sprint 87 above is now the latest accepted numbered implementation.

- **Accepted boundary:** 21 test files gained actor-aware fixture/assertion ownership, actor-owned mutable provider/state captures, checked Sendable subprocess callback state and bounded confirmation/snapshot synchronization. Production/runtime source, project settings, shared corpus machinery, independent source oracles, migrations and resources remained unchanged. No Sprint 86A, migration, new ADR or language-mode switch; V17 remains current and all native targets remain Swift 5 at this acceptance boundary.
- **Verified strict and focused evidence:** the current baseline contained 11 source error locations and 350 warning headers (307 distinct reported location/message combinations). Final Swift-6 complete-strict object/module generation passed for 83 unit-test files, two UI-test files and 18 native subprocess/shared inputs with zero source errors or warnings. Three redundant upcoming-feature notices were reported separately. All 21 corrected suites passed 181 tests; the reviewed snapshot-priority repair passed its five-test rerun with no priority-inversion notice.
- **Verified TestPlan and inventory:** the authoritative frozen-candidate invocation passed **515 definitions / 79 suites / 573 expanded executions**, with zero failures, skips or expected failures. All 516 registered definitions and 12 parameterized declarations / 70 argument executions were preserved; only the explicitly authorized conditional global campaign was excluded from the invocation, with no checked-in TestPlan skip. Independent financial/source assertions were unchanged; the single removed dispatch-timeout expectation was replaced by a throwing structured watchdog. No unsafe suppression or serialization marker was added, and test `@unchecked Sendable` uses decreased from nine to eight.
- **Accepted proportional validation:** the separate complete global corpus/provider-order campaign, Debug/Release product runtime qualification, separate optimized Release compilation and durable startup were `NOT_REQUIRED` because this was test-only work with production and corpus machinery frozen. Native Debug build-for-testing passed; no integrated Swift-6 product/runtime or fresh global-campaign certification was claimed. All 453 committed blobs matched the frozen candidate and all 140 registered originals retained their bytes. The ignored `build/sprint86-test-pr/acceptance-manifest.json` retains the detailed evidence; this explicit acceptance supersedes its historical candidate label.
- **Authorized continuation:** completed `FW-P2-75` leaves the active queue. Chat authorizes Sprint 87 — Coordinated Swift-6 Migration (`FW-P2-76`) across the app, unit tests, UI tests and subprocess helper, preserving accepted ownership and financial semantics. Comprehensive compiler, focused/full TestPlan, complete authentic-corpus/provider-order, Debug/Release, native Import Centre, durable relaunch/hydration, migration, privacy and signing qualification is required. Stop for Chat on a financial-semantic change or new architectural/migration requirement; publish one candidate and return for acceptance before Sprint 88.
- **Personal-v1:** **UNDECLARED / NOT CERTIFIED**. The accepted pre-100 roadmap and Sprint-100 personal-adoption certification milestone remain unchanged; this acceptance does not authorize Sprint 88–100 product work.

## Accepted Sprint 85 — PR-3 Dependency Concurrency Boundary — 2026-09-10

Chat accepts Sprint 85 at implementation commit `b4e4e6ffb14deccef238352a6ef834514a2a37c2` (parent `8d2dafd29de543660300ac8f37f16a152603f1f5`). Sprint 85 remains an accepted prior numbered implementation; Sprint 87 above is now the latest accepted numbered implementation.

- **Accepted decisions:** `ZIPFOUNDATION_DECISION = LOCAL_CORRECTION`; vendored ZIPFoundation 0.9.20 closes its two native Swift-6 diagnostics by making two unchanged-value globals immutable. `LEGACYXLS_POLICY = SERIALIZED_PROCESS_LOCAL`; one bounded owner retains the complete source-buffer/open/read/copy/close lifetime and cancellation checks around non-interruptible C work. No libxls concurrent-reentrancy claim is made.
- **Verified qualification:** 19 OOXML and eight LegacyXLS focused tests passed. The frozen TestPlan invocation passed **515 definitions / 79 suites / 573 expanded executions**, with zero failures, skips or expected failures; all prior definitions except the single explicitly authorized conditional global campaign executed, plus 11 added tests. Complete affected authentic Axis bank, HDFC bank-account and Axis credit-card source/oracle and provider gates passed. The checked-in TestPlan and selection settings remain unchanged. Debug and optimized Release, dependency linkage, signature/privacy and bundle containment checks passed; all 452 committed file blobs matched the frozen candidate and all 140 registered originals retained their bytes and registered paths.
- **Proportional validation and remaining boundaries:** the all-family/provider-order campaign and durable startup were `NOT_REQUIRED` because the implementation stayed within the XLS/XLSX dependency surfaces and changed no shared extraction/routing/snapshot/persistence/startup boundary. No fresh global campaign digest is claimed. The strict production probe has zero dependency-attributable diagnostics; five other production diagnostics remain under `FW-P2-76`. At the Sprint-85 boundary, three test capture warnings and the pre-existing `SourceContentSnapshotTests` QoS advisory remained under `FW-P2-75`; Sprint 86 above subsequently resolved them. The ignored `build/sprint85-pr3/acceptance-manifest.json` retains the detailed evidence; this explicit acceptance supersedes its historical candidate label.
- **Preserved state and authorized continuation:** no Sprint 85A, migration, new ADR or language-mode switch. V17 remains current with accepted V1–V17 identity inputs unchanged; native product targets remain Swift 5. Completed `FW-P2-74` leaves the active queue. Chat authorizes Sprint 86 — TEST-PR Strict-Concurrency Test Correction (`FW-P2-75`), test/support-only with production bytes frozen, independent assertions/oracles and test inventory preserved, and a mandatory stop if production/runtime changes are required. Return for Chat acceptance before Sprint 87.
- **Personal-v1 planning decision — 2026-09-10:** adoption/certification remains **UNDECLARED / NOT CERTIFIED**. By explicit user decision, personal adoption is targeted for Sprint 100 after the required pre-1.0 product boundaries, including verified backup/restore, bounded current Al Dar Salary/planning completion, current holdings/valuation and current market FX/net-worth. The prepared [90–99](Sprint%20roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md) and [100–109](Sprint%20roadmap/Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md) roadmaps and `FW-P0-26` own the detailed sequence and certification matrix. This is future planning, not implemented state, certification, architecture acceptance or a migration allocation.

## Accepted Sprint 84 — PR-2 SQLite / Provider / Migration Ownership — 2026-09-10

Chat accepts Sprint 84 at implementation commit `a4dd6929a2282cc94c850eb1dccf350b1ee5c8a1` (parent `af2d1949c6e9a73af3bb004422b72882d28195e2`). Sprint 84 remains an accepted prior numbered implementation; Sprint 87 above is now the latest accepted numbered implementation.

- **Accepted ownership boundary:** one synchronous SQLite owner protects connection, statement, backup, migration and compound-transaction lifetimes; copied row values leave that owner. Provider-generation validity protects each check and operation and drains active operations before invalidation. The immutable migration registry and Sendable closures, MainActor provider defaults and shared helper/database sources have explicit ownership.
- **Preserved contracts:** financial parsing, source snapshots, provider parity, transaction semantics and canonical hydration remain unchanged. Accepted V1–V17 identities and integrity are preserved, with no schema change or V18. Native targets remain in Swift 5; PR-3, TEST-PR and the final coordinated Swift-6 switch are not accepted by this closure.
- **Verified qualification:** focused PR-2 validation passed 103 definitions / 155 expanded executions. The frozen complete TestPlan passed **505 definitions / 79 suites / 563 expanded executions**, with zero failures, skips or expected failures; all 497 prior definitions remain, plus eight ownership tests. All seven authentic-family gates and six provider/order campaigns passed over 127 carriers / 103 logical statements / 3,165 canonical transactions / 5,286 representation transactions, preserving semantic digest `1464f47c1568438fb33fcd7743d9a094944c11d4f6eb15fced7a889ed5ea35a3`. Debug and optimized Release, bundle containment/signing, and two verified SQLite same-database launches with canonical hydration, 17 migration records and integrity checks passed. All 140 private original files retained their bytes and path inventory.
- **Strict evidence and limits:** complete strict-concurrency probes closed all PR-2 diagnostics in app and helper. Two ZIPFoundation diagnostics remain for PR-3; the test-target and five other production readiness diagnostics remain separately owned by `FW-P2-75` and `FW-P2-76`. The eight ownership tests include bounded scheduling observations; they do not claim exhaustive race scheduling. The retained ignored `build/sprint84-pr2/acceptance-manifest.json` records the frozen candidate and local evidence; this explicit acceptance supersedes its historical candidate label. This documentation closure adds no executable validation.
- **Authorized continuation:** completed `FW-P2-73` leaves the active queue. Chat has authorized Sprint 85 — PR-3 Dependency Concurrency Boundary (`FW-P2-74`) and determined that no higher-priority verified defect currently preempts it. The current roadmap records the dependency-proportional Sprint-85 validation amendment, test/support-only Sprint 86 and comprehensive Sprint 87. Sprint 85 must return for Chat acceptance before Sprint 86. Personal-v1 remains **UNDECLARED / NOT CERTIFIED**.

## Accepted Sprint 83 — Serial Batch Import and Multi-File Drag-and-Drop — 2026-09-10

Chat accepts Sprint 83 at implementation commit `adcf83f52d309ddac18d95f0321d0c0f6120dd29` (parent `057d70b6f39929735401d5211cd180db162c94cc`). Sprint 83 remains an accepted prior numbered implementation; Sprint 87 above is now the latest accepted numbered implementation.

- **Accepted intake and ownership:** the shared @MainActor Import Centre coordinator now owns an ordered serial queue of length N. Single-file import uses the same path with N = 1. Multi-file picker and drag-and-drop intake preserve the received selection/provider order, including distinct occurrence identity for repeated URLs; asynchronous drop-provider completion cannot reorder the queue. Exactly one item may own active preparation, and there is no parallel preparation.
- **Per-item control and isolation:** each statement retains independent preparation, progress, review, account/card choice, duplicate/rejection and terminal state. Review and explicit confirmation remain per item. Skip, cancel current, cancel batch, retry and continue preserve cancelled-task draining, stale-callback rejection and one-shot confirmation. A failed, rejected, skipped or cancelled file cannot contaminate another item or undo an already committed item. The batch summary reports actual per-file outcomes; there is no batch-wide atomicity claim.
- **Preserved contracts:** provider-owned persistence and canonical RepositoryStoreHydrator publication remain the accepted commit/hydration boundary. ImportEngine financial behavior, account/card/partial/recovery outcomes, duplicate/equivalence semantics, ADR-041 immutable snapshots and exact source-byte fingerprints, and ADR-046 authentic-corpus authority are preserved. No reader, detector, classifier, parser, normalizer or financial-semantic change was included. No schema change, migration or new ADR was introduced; current migration remains V17 with V1–V16 immutable, and Swift 5 language mode is retained.
- **Verified repository boundary:** the accepted eight-path implementation comprises `ContentView.swift`, `Import/Coordinator/ImportCentreCoordinator.swift`, `Import/Presentation/StatementDropIntakeAdapter.swift`, `Views/ImportCentreBatchViews.swift`, three Import Centre/drop-intake test files and their Xcode project registration. Repository structure, code scope, test definitions and the independent review were verified against the accepted implementation. These checks are distinct from executable qualification.
- **Final executable qualification — local execution evidence:** the retained canonical TestPlan result `LedgerForge-validation.zL9XOs` records **497 definitions / 78 suites / 555 expanded executions / 0 failed / 0 skipped / 0 expected failures**. All seven authentic-family gates executed and passed. The complete registered corpus covers **127 carriers / 103 logical statements / 3,165 canonical transactions / 5,286 representation transactions**. All six In-Memory/SQLite and chronological/reverse/deterministic-mixed campaigns match semantic digest `1464f47c1568438fb33fcd7743d9a094944c11d4f6eb15fced7a889ed5ea35a3`.
- **Build, native and durable evidence — local execution evidence:** Debug and optimized Release builds passed. Native picker and drop checks exercised authentic CSV, PDF, XLS and XLSX inputs, explicit confirmation, skip/cancel, exact replay, per-file isolation and truthful summaries; an unsupported original email carrier was rejected without accepted residue. Direct SQLite checks and ordinary same-database quit/relaunch verified provider reconstruction, canonical hydration, 17 migration records and unchanged state across all 52 tables. These disposable-database checks do not establish migration compatibility or personal-v1 adoption.
- **Evidence attribution and retention:** physical drag gestures and one CSV confirmation were user-assisted after Computer Use failures; the resulting native UI and SQLite state were independently inspected. Other native controls were exercised through direct computer use. After the final test-only assertion restoration, all 450 other repository files and all 28 retained application-bundle files were verified unchanged, preserving the earlier build/native/durable evidence with its original binary identities; focused and complete TestPlan/corpus qualification were rerun for the final tests. The retained `build/sprint83-batch-import/acceptance-manifest.json` records the pre-Chat-review campaign and its limitations; its historical candidate label is superseded by this explicit Chat acceptance. This documentation closure performs no new executable validation.
- **Remaining planning boundary:** completed `FW-P1-20` and `FW-P1-21` leave the active queue. Bounded parallel preparation remains unscheduled research under `FW-P2-51`, without approval to execute. Sprint 84 has since been accepted and Sprint 85 authorized as recorded above. No financial source-support expansion or personal-v1 certification is implied.

## Accepted Sprint 82 — Serial Unified Import Centre Foundation — 2026-09-10

Chat accepts Sprint 82 at implementation commit `d239f939088b67e5a90c65117f08592891be17bb` (parent `17944e104081279ce6267f26a0bac5d8468a3247`). Sprint 82 remains an accepted prior numbered implementation; Sprint 87 above is now the latest accepted numbered implementation.

- **Accepted outcome:** one shared @MainActor serial Import Centre coordinator owns a deterministic queue of length one. Each item retains stable identity and independent source, preparation, progress, review, account/card choice, duplicate/rejection, confirmation, persistence, terminal and recovery state. Preparation, review, explicit confirmation, provider-owned persistence and canonical hydration remain distinct stages.
- **Accepted orchestration boundary:** cancellation drains the preparation task and releases `PreparedImport` before confirmation; confirmation is explicit and one-shot; commit is provider-owned and non-cancellable; stale callbacks cannot publish into a different item; shared production ownership is used across import surfaces; no multi-file, drag-and-drop, folder, batch or parallel-preparation workflow was introduced.
- **Preserved financial and repository contracts:** existing ImportEngine preparation/commit/cancel, generic source snapshot and fingerprint provenance, duplicate/equivalence behavior, account/card/partial/recovery outcomes, provider transaction boundaries and canonical RepositoryStoreHydrator publication remain unchanged. No reader, detector, classifier, parser, normalizer, schema, migration, Swift-6 or financial-semantic change was included.
- **Exact implementation boundary:** production changes are limited to `ContentView.swift` and `Import/Coordinator/ImportCentreCoordinator.swift`; project metadata adds the coordinator source; tests are limited to `LedgerForgeTests/ImportCentreCoordinatorTests.swift`.
- **Acceptance evidence:** focused validation covered 16 suites, 127 definitions and 139 expanded executions with all passing; the complete TestPlan covered 76 suites, 479 definitions and 537 expanded executions with all passing. The complete registered authentic corpus covered 127 carriers, 103 logical statements, 3,165 canonical transactions and 5,286 representation rows; all six provider/order campaigns matched semantic digest `1464f47c1568438fb33fcd7743d9a094944c11d4f6eb15fced7a889ed5ea35a3`. Debug and optimized Release builds passed. User-assisted native checks showed protected preview/cancel with no persistence, one explicit CSV confirmation persisting 1 document, 1 import session, 2 fingerprints and 97 transactions, navigation without repeat import, and a final protected preview with visible preparation progress before cancellation. Direct SQLite checks covered all 52 tables; durable startup passed two verified-SQLite/current/hydrated/clean-quit launches with 17 migration records and an unchanged database fingerprint.
- **Digest transcription correction — 2026-09-10:** independent inspection of the retained Sprint-82 `build/sprint82-serial-import-centre/acceptance-manifest.json` confirmed that all six `authentic_corpus.aggregate.campaign_semantic_sha256` entries contain the full 64-character value above, ending `35a3`. Its candidate and publication fields identify Sprint-82 implementation `d239f939088b67e5a90c65117f08592891be17bb`; the manifest SHA-256 is `46d91ac52baff9764d0e5a45eb9929c33a3ab9947d4de716c76074030c0e381e`. The missing final `a3` was corrected from Sprint-82 evidence, not inferred from Sprint 83.
- **Evidence classification:** native picker and button observations were user-assisted; direct SQLite, focused/full-suite, complete-corpus and durable-startup results are repository/local evidence from the accepted implementation campaign. The privacy-safe acceptance manifest remains local validation evidence and is not accepted product state. No personal-v1 adoption or parser-reliability expansion is implied by this sprint.
- **Foundation for Sprint 83:** the serial coordinator, per-item identity/state ownership, cancelled-task draining, explicit confirmation, shared production ownership, duplicate/recovery preservation and absence of parallel preparation established the entry evidence for the now-accepted Sprint 83 above.

## Accepted Sprint 81 — PR-1 Staging and Runtime Publication Ownership Seam — 2026-09-10

Chat accepts Sprint 81 at implementation commit `13552eaf8d22a8e6fcb56fb9a9d7a9dd0892bf91` (parent `f2290532b29b9aa057326929bd695a121d790db0`). Sprint 81 remains an accepted prior numbered implementation; Sprint 87 above is now the latest accepted numbered implementation.

- **Accepted outcome:** explicit MainActor ownership for canonical runtime-store installation and notification methods, with synchronous pure staging retained. Complete snapshots are installed before observers are notified, canonical notification order is preserved, and provider-generation/reconciliation semantics remain unchanged. The central observer-atomicity test was independently assessed as `INDEPENDENT_ENOUGH` and establishes that the first observation sees the complete installed snapshot in canonical order.
- **Exact implementation boundary:** production changes are limited to `Core/AccountStore.swift`, `Core/CardStore.swift`, `Core/CategoryStore.swift`, `Core/DeveloperConsole.swift`, `Core/ImportSessionStore.swift`, `Core/TransactionStore.swift` and `Services/RepositoryStoreHydrator.swift`; test changes are limited to `LedgerForgeTests/DeveloperDiagnosticsTests.swift` and `LedgerForgeTests/RepositoryStoreHydratorTests.swift`.
- **Preserved contracts:** Swift 5 language mode, ADR-024's single persistence-to-runtime hydration boundary and current Migration V17 are unchanged. There is no whole-store blanket actorization, SalaryStore/FundingPlanStore refactor, PR-2/PR-3/TEST-PR work, Swift-6 migration, Import Centre implementation, schema/migration change, parser/source change or financial-semantic change.
- **Acceptance evidence:** Codex's final focused validation reported 66 definitions / 88 expanded executions / 88 passed / 0 failed / 0 skipped. The complete TestPlan reported 468 registered definitions / 75 suites / 526 expanded executions / 526 passed / 0 failed / 0 skipped / 0 expected failures. Codex also reported passing Debug and Release builds; complete authentic/provider campaigns over 127 carriers, 103 logical statements, 3,165 canonical transactions and 5,286 representation transactions with all six provider/order campaigns semantically identical; and two successful ordinary Debug launches against the same verified SQLite database, with complete hydration, clean quit/relaunch, 17 migration records on both launches, and passing integrity/foreign-key checks.
- **Evidence classification and portability:** GitHub/MCP independently verified the committed nine-file scope and observer-atomicity oracle and found no contradictory material evidence. Several retained Codex validation artifacts could not be reopened through MCP because their locations were outside MCP's approved evidence roots; Chat explicitly accepted Sprint 81 notwithstanding that post-hoc portability limitation. The Standing Execution Harness now directs future executions to emit a privacy-safe shared acceptance manifest for cross-tool review without treating it as a substitute for native artifacts.
- **Unchanged qualification:** personal-v1 remains **UNDECLARED / NOT CERTIFIED**. Sprints 82–84 are accepted above; Sprint 85 is the authorized current position under the Chat-approved continuation.

## Accepted unnumbered startup reliability and monthly planner package — 2026-09-09

Chat technically accepted the complete reviewed **35-path candidate**, including the non-negative-transfer-fee correction. Implementation review is closed and publication is complete. The accepted product implementation/package commit is `6455f662dd0ea8896d19af3e67be51546badb3ae`; the subsequent user-authorized obsolete-plugin-artifact cleanup is `d8124ef5a1f38a1e7547f4f8905c91f25b2f1194`; the later R1 documentation/planning publication is `a560312db5900645779a499016e13f0c87e81435`. The cleanup and documentation commits did not create a newer product implementation baseline at that time. This remains an accepted unnumbered package; Sprint 85 is now the latest accepted numbered implementation.

- **Accepted boundary:** the diagnosed V17 migration-name mismatch and one-time owner-authorized recreation of the disposable Debug Current Database; typed, bounded ephemeral diagnostics with causal links and privacy-safe chronological Copy All; truthful loading/unavailable/non-current presentation; one coherent Salary draft and Save/Command-S action; natural amount entry, contextual provenance and the compact This Month/Salary History presentation; non-negative configured QAR fees enforced in editing/final Save and shared SQLite/In-Memory validation. Zero fees remain valid. Effective fee remains zero when no India funding is required, while the configured value is retained.
- **Recurrence prevention:** independent accepted-migration identity locking, truthful build identity, explicit namespace-guarded schema experiments and the durable-startup/relaunch gate. Namespace rejection applies to the explicit `script/validate.sh schema-experiment` command; it is not a universal interceptor of arbitrary schema work. The completed Current Database recreation was a one-time maintenance exception, not automatic recovery or standing reset authority.
- **Accepted evidence identities:** `final-validation-hashes.json` pins all 35 paths (SHA-256 `634271a1e2f801fe34d0b20b58097f70b0409b0bfcc6723e7680bdb913151977`). The original review packet SHA-256 is `096500f27041b43b1238b98c0c02f53b4fd9cb3fc2ecb082f8b9a3631b31fec4`; the validated fee-correction supplement SHA-256 is `764ce318eafe2cfb20bc7ddff9d7ae459f7bb64b0e6185d6fccb78877ba25bda`. Retained evidence remains outside the published source set.
- **Reused final validation:** focused 22 definitions / 23 expanded executions; canonical TestPlan **465 definitions / 75 suites / 523 expanded executions**, zero failures/skips/expected failures, in `LedgerForge-validation.VJZLJ9/TestResults.xcresult`. All seven authentic-family gates and six provider/order campaigns passed against frozen source oracles; global artifact SHA-256 `7b2456e683b0a11e7eef35a34dd44f3289c986986853c47f819cc8df1ce23ed4`. Debug and optimized Release, native negative-fee rejection and exact zero/positive saves/reload, and canonical SQLite activation/hydration/quit/relaunch passed. All 35 hashes remained unchanged during final validation. Documentation-only acceptance closure reuses those results without another executable run.
- **Preserved contracts:** accepted V1–V17 definitions and checksum construction, signed Money, financial formulas, conditional effective fees, imported evidence and source parsers remain unchanged. No migration or new architecture decision was introduced. Contextual provenance replaces the standalone Truth classes panel, not the underlying provenance requirement. The earlier authentic-parser reset remains closed, with its separate historical evidence below.

**Retained limitations:** the fee defect was established by static review; historical pre-fix executable reproduction was unavailable. Native no-transfer fee behavior was not separately exercised, while its automated cases passed. Broader native populated-account capture and prior-month rollover were not separately exercised. Ordinary startup verification directly launched the resolved Xcode Debug product; it did not assert a click of Xcode Run. Cache access was resolved by changing the execution policy, not by a proven lid-related cause or cure. The historical writer of the incompatible V17 record remains unknown. Personal-v1 remains undeclared; this package does not complete adoption, PR-1, the Import Centre or Swift-6 migration.

See the [current roadmap](Sprint%20roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md), dated implementation alignments in [ADR.md](ADR.md), the [UI authority](UI_UX_v1.0_Frozen.md), and the remaining bounded queue in [FUTURE_WORK.MD](FUTURE_WORK.MD). `LF-UI-2026-09-R1` is approved design direction only and is not recorded here as implemented product state.

## Accepted Authentic-Parser Reliability Reset — 2026-09-09

The **P0 Authentic-Corpus Parser / Import Reliability Reset** is an unnumbered implementation campaign technically accepted by Chat on 2026-09-09. It is not a numbered sprint. The accepted implementation repairs ordinary source routing and family interpretation, extends format-neutral Axis bank projection support, carries source controls through persistence/hydration, and removes financial statement factories and their dependent tests under the all-stages authentic-input rule. Exact private originals and independently derived source oracles remain isolated, read-only evidence in their approved source location. Private originals are never included in published repository artifacts; only approved sanitized, clean-room or privacy-safe derived artifacts may be published.

- **Accepted schema/current migration:** additive V17, including Axis bank projection compatibility and zero-activity/card-summary schema support. V17 is the current accepted migration; historical V1–V16 migration source bytes remain unchanged and immutable. No V18 is authorized.
- **Registered acceptance boundary:** 127 authentic financial carriers across Axis bank, Axis card, HDFC bank, CBQ bank, CBQ card, American Express and Qatar Airways salary: 103 logical statements, 5,286 representation transaction rows and 3,165 canonical bank/card transactions. The 20 salary statements are included in the statement counts; their 258 components are not bank transactions. The CBQ EML is inventory/container provenance; only its actual attached PDF enters the ordinary PDF path, with no general email ingestion feature.
- **Evidence status:** the final canonical complete TestPlan passed on the integrated source freeze: 443 tests in 72 suites, 500 parameter-expanded executions, zero failures/skips/expected failures and zero Swift source diagnostics. Result identity: `LedgerForge-validation.2Vzm4a/TestResults.xcresult`, 2026-09-08. All seven complete-family gates and the six provider/order global campaigns passed. HDFC/Amex populated migration inputs were imported by the current engine; the separate historical CBQ gate uses a genuine V16 database produced by unchanged preserved production from all 19 authentic sources. Exact durable and hydrated values survive V17 and reopen. Fresh Debug/test and optimized Release builds passed without Swift diagnostics; final Release bytes and local signature were independently verified and retained. Subsequent corrections changed tests/TestPlan/documentation only, so no replacement Release build is claimed or needed.
- **Unobserved cases:** genuine zero-activity statements and currently absent source formats, including CBQ transaction-history XLS, are not certified by these corpus results. No financial statement may be invented or mutated to fill that gap. Historical implementation remains distinct from current source certification.
- **Late independent review:** historical V16 CBQ card summaries lacked minimum due, so requiring the new component under the unchanged durable reconciliation contract would break migrated hydration. The integrated repair distinguishes exact historical-read and current-write rule revisions without changing parser profile identity, editing V1–V16 or inventing a missing value. Both its complete current 19-source/six-campaign CBQ gate and genuine historical upgrade/hydration gate passed; historical missing minimum due remains absent. Axis bank/card zero-activity producer, validation, persistence and hydration repairs are integrated and independently reviewed, preserving actual selected-month versus exact-period authority and rejecting unresolved financial candidates. No authentic zero-activity source exists, so that source case remains uncertified.
- **Global gate:** ordinary per-carrier prepare/validate/confirm, exact renamed replay, source ownership, SQLite checkpoint/close/reopen and canonical hydration passed for In-Memory and SQLite in chronological, reverse and deterministic-mixed orders. All six format-neutral semantic digests match, every source is separately compared with independent source authority, and final source-byte hashes equal the starting freeze. Mandatory result artifact SHA-256: `7b2456e683b0a11e7eef35a34dd44f3289c986986853c47f819cc8df1ce23ed4`. Earlier comparison, mechanics, scheduling and output-export failures remain failed/interrupted history; they are not retroactively counted as passes. This serial acceptance queue does not implement multi-file UI, a Unified Import Centre or batch-wide atomicity.
- **Fixture retirement:** 89 prohibited financial-source artifacts and 34 dependent test/helper/debug paths were removed from the active worktree. Five nonfinancial LegacyXLS resources and their README remain. Historical recovery bytes remain non-executable recovery evidence; committed history is unchanged.
- **Delivery state:** parent-owned integration into the existing unstaged `main` worktree followed exact starting-WIP comparison. Independent result review verified the complete plan, source-bound export and all 122 final-run frozen paths, followed by dependency review of four additional tested inputs. Chat technically accepted the complete 249-path candidate. Publication is recorded by Git history rather than asserted by this state record. Native authentic preparation, preview, cancellation and explicit account-choice gating are verified. Manual final confirmation clicking remains unverified but is not a blocker under the coordinator's explicit decision. Personal-v1 adoption remains undeclared.

See the current [cycle roadmap](Sprint%20roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md) for campaign status and ADR-046 for source authority. This section records the technically accepted unnumbered implementation; personal-v1 certification remains separate and undeclared.

## Current Alignment — 2026-09-10

### Parser Reliability / Import Architecture Reset

This is the current parser/source-support alignment layer. It supersedes conflicting **current-support, fixture-authority and incidental-layout** wording below while preserving historical sprint/ADR records as historical facts.

- **Latest accepted numbered implementation:** Sprint 87 — Coordinated Swift-6 Migration at `93c068c23027a8cd59753ac4ac916e6cee75adbf`. All native targets are Swift 6. Sprint 79 remains the latest numbered financial-domain feature implementation, and historical Sprint 70–79 implementation/acceptance records remain intact.
- **Accepted migration:** additive V17 is current; V1–V16 remain immutable historical migrations.
- **Architecture:** ADR-045 remains the historical accepted architecture through Sprint 79. ADR-046 — Authentic-Corpus-Only Parser Authority and Adaptive Financial Source Interpretation — is accepted by explicit user decision on 2026-09-01 as the current parser/import authority.
- **Historical acceptance versus reliability:** historical parser/profile implementation acceptance alone is not current authentic-corpus production reliability certification. The accepted reset separately established current reliability for the complete registered corpus through ordinary production, persistence, reopen and hydration paths; a synthetic fixture campaign or partial authentic sample remains insufficient.
- **Personal-v1 parser reliability:** the complete registered 127-carrier corpus was recertified through ordinary production by the accepted unnumbered reset; personal-v1 remains **UNDECLARED / NOT CERTIFIED** and requires a separate adoption gate.
- **All-stages authentic-input rule:** no synthetic, generated, recreated, sanitized, reconstructed, representative, reduced, mutated, hand-authored or model-created financial statement may be created or used at any stage, including development/debugging, tests, source oracles/expected outputs, migration/persistence, batch acceptance, developer UI and adversarial review. Statement factories/catalogs/resources and hand-built statement/domain/DTO substitutes must be removed or rewritten around authentic inputs. Exact working/decrypted copies and actual attachments are permitted with original-byte provenance authority. Pure nonfinancial mechanics remain allowed; absent authentic cases remain source-uncertified. This user-settled rule remains binding after technical acceptance and does not authorize fabricated financial inputs or personal-v1 adoption. <!-- user-specified -->
- **Regression authority:** the complete registered authentic corpus supplied by the user is cumulative authority for each supported family. Every newly supplied recurring statement joins that corpus unless explicitly excluded or archived. No representative month or sample substitutes for the complete affected corpus.
- **Current recertification:** the complete registered 127-carrier corpus passed the ordinary production and provider/order acceptance gate recorded above and was technically accepted on 2026-09-09. This certifies only the registered exact corpus/profile boundary; genuine zero-activity statements and CBQ transaction-history XLS remain uncertified.
- **Why the reset was required:** authentic defects encountered across Axis, HDFC and CBQ demonstrated that the older fixture-/layout-bounded acceptance method could report green while recurring authentic statements still failed ordinary production. The accepted reset closes those registered-corpus defects without erasing historical implementation acceptance or authorizing reliance on that history alone.
- **Smart family parsers:** current direction is one adaptive deterministic runtime parser per recurring financial source family unless materially different financial/source semantics justify another profile. Page count, transaction count, absolute row/line positions, harmless whitespace/typographic changes, benign page breaks, extra nonfinancial pages and statement length are not financial identity. Zero-transaction and variable-page statements must be accepted when coherent source evidence proves their semantics.
- **Reader boundary:** generic readers extract and preserve source evidence, including physical PDF page boundaries even when a page has no extractable text. Downstream family interpretation decides whether a page is financial, nonfinancial, requires another extraction mode or is genuinely ambiguous.
- **Strict money, flexible packaging:** semantic labels, column roles, data shapes, source dates, Money, direction, balances, statement/section controls, continuity, multiplicity, source order and surrounding structure jointly establish financial meaning. Fail closed on financial ambiguity, contradiction, malformation or unsupported semantics, not inert presentation variation.
- **Shared ingestion changes:** a change to a generic reader, unlock/password orchestration, source snapshot, detection, classification, routing, normalizer infrastructure, Money, common validation, duplicate/equivalence semantics or persistence mapping requires the complete authentic regression corpus of every affected supported family.
- **Oracle comparison:** independent source oracles record what sources say. Acceptance compares source truth through an explicit architecture-aware semantic projection with ordinary production output. Raw oracle JSON equality with raw production JSON is not itself an acceptance rule where representations intentionally differ.
- **Canonical import direction:** batch intake (queue length one for single import) -> unlock as required -> generic extraction -> identify/segregate -> route -> source-family semantic parser -> source-owned financial events -> normalize -> validate/reconcile -> duplicate/equivalence -> explicit review/confirmation where required -> atomic persistence -> one canonical database -> canonical financial rows -> query/extraction/presentation/viewer layers. Institution parsers are ingestion modules, not analytical silos.

The accepted reset certifies the complete registered corpus supplied through 2026-09-08 under ADR-046. Newly supplied recurring sources extend that corpus, and absent authentic cases remain uncertified until genuine sources exist.

---

## Historical Alignment — 2026-08-28 (superseded by the 2026-09-09 V17 acceptance)

This section preserves the 2026-08-28 alignment snapshot for traceability. The 2026-09-09 alignment above supersedes it wherever current support, migration or planning status differs.

### Accepted production baseline

- **Primary branch:** `main`.
- **Accepted implementation:** Sprint 79 on `main` at implementation commit `9489f6b21c9d585d2d90f2ba4798a931590057f7`; the documentation-reconciliation commit is recorded by Git history.
- **Latest accepted numbered sprint:** Sprint 79.
- **Latest accepted discovery outcome:** Sprint 80 — Swift 6 and macOS readiness closure (`SWIFT6_READINESS_COMPLETE`); no production implementation or migration was performed.
- **Latest accepted ADR:** ADR-045 — Qatar Airways Salary Actuals and Current-Month Funding Planner; implemented with Sprint 79. ADR-044 remains the accepted card-domain authority.
- **Accepted migration:** V16.
- **Accepted card profiles:** exact `amex.credit-card.pdf@1`, exact `cbq.credit-card.pdf@1`, and the exact Axis `axis.credit-card.pdf@1` / `axis.credit-card.xlsx@1` families accepted by Sprint 78B. No generic card/PDF/XLSX support is implied.
- **Personal-v1 adoption:** still undeclared; release/adoption certification remains a separate future gate.

### Sprint 79 closure and current planning

- Sprint 78 failed and Sprint 78A failed; Sprint 78B is accepted and completes the Sprint 78 outcome.
- Exact Axis credit-card PDF/XLSX support, the dual Axis PDF credential scopes, zero-instrument liability semantics, cross-format equivalence and Migration V15 are accepted production state.
- Sprint 79 is technically accepted and published. Exact `qatar-airways.salary.pdf@1`, the dedicated Salary workspace/current-month funding planner and additive Migration V16 are accepted production state.
- No Sprint 78C exists because Sprint 78B completed the required outcome.
- Sprint 78B remains the accepted Axis credit-card closure; Sprint 79 builds on that baseline without reopening the completed Sprint 78 outcome.

### Sprint 79 accepted implementation

Sprint 79 is the exact Qatar Airways salary-PDF and current-month funding-planner increment. Private discovery over the complete active salary boundary proves 20 native-text unlocked PDFs across monthly salary/payslip, Adhoc Payment and Annual Discretionary Bonus source kinds. The earlier seven-document planning statement is superseded.

The approved product boundary is:

- exact `qatar-airways.salary.pdf@1` only; no generic payroll claim;
- employer/source authority remains distinct from bank/card `Institution` authority;
- imported salary statements and ordered earning/deduction lines are immutable source truth and are never fabricated as bank transactions;
- source-owned pay period is chronology authority; print date is retained separately;
- fixed/variable are editable planning semantics only, never imported payroll classifications;
- one dedicated `Salary` sidebar space owns Salary History plus This Month planning; Dashboard receives summary-only funding signals;
- one editable current-month plan may roll forward prior values and account selections as editable defaults;
- checked QAR/INR accounts contribute explicit planning balances with carried/manual/refreshed-snapshot provenance; current balance capture is always user-triggered and never live-linked; missing checked-account balance evidence makes affected outputs incomplete rather than zero, and account inclusion is never auto-selected solely because one eligible account exists;
- India funding uses selected INR liquidity before calculating the Qatar funding shortfall;
- transfer fee starts at editable QAR 25 and contributes only when India funding shortfall is greater than zero; otherwise its effective contribution is QAR 0 while the configured fee remains editable;
- plan-local user-entered FX is positive, dated and oriented as INR per 1 QAR; the dormant global `exchange_rates` domain remains inactive; if India funding is required and FX is missing/invalid, QAR funding and investment-capacity outputs are incomplete rather than zero;
- INR funding conversion rounds the required QAR principal upward to the next QAR minor unit;
- available-for-investment and final buffer are derived planner outputs, while planned investment is editable user input;
- no automatic salary-bank matching, card-payment matching, transfers, obligation inference or investment execution is authorized.

Additive Migration V16 is accepted for truthful salary-actual and current-month funding-plan persistence with SQLite/In-Memory parity and canonical `RepositoryStoreHydrator` integration. V16 is the current migration baseline; V1–V15 remain immutable.

ADR-045 is the accepted and implemented architecture authority for the Sprint 79 boundary.

Sprint 79 acceptance evidence on the final privacy-safe candidate includes a 9/9 Salary parser/planner suite with the complete 20-source authentic oracle gate, plus the authoritative complete TestPlan at 819 total / 814 passed / 5 intentionally skipped / 0 failed. The published implementation commit is `9489f6b21c9d585d2d90f2ba4798a931590057f7`.

The authentic July 2026 CBQ credit-card compatibility defect was separately classified `PRE_EXISTING_OR_EXTERNAL` relative to Sprint 79. It remains future work and does not alter Sprint 79 acceptance.

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

### Accepted Sprint 78B source authority

The active private Axis credit-card corpus is Jan–Jul 2026:

- 7 locked App PDFs;
- 7 unlocked App PDFs;
- 7 App XLSX files;
- 7 locked traditional PDFs;
- 7 unlocked traditional PDFs;
- **35 physical active files total**;
- **21 logical representations total**: 7 App PDF, 7 XLSX, 7 traditional PDF.

Archived/ignored material is excluded.

Current source-proven financial row counts are:

| Month | Rows |
|---|---:|
| Jan | 89 |
| Feb | 95 |
| Mar | 56 |
| Apr | 178 |
| May | 143 |
| Jun | 154 |
| Jul | 81 |

Each logical representation family totals **796** financial rows.

Cross-format financial equivalence is exact multiset equality, including multiplicity, over financial date + liability effect + native currency + exact Money. Narration is not financial identity.

March contains 56 rows / 55 unique neutral financial keys with one multiplicity-two key. June contains 154 rows / 153 unique keys with one multiplicity-two key.

App PDF and XLSX additionally preserve exact source financial order and narration after only approved inert whitespace/Unicode normalization. Traditional PDF source order is not required to match App/XLSX order.

App PDF and XLSX use source-proven selected statement month. Do not invent a statement day or period.

Active Loans Summary is excluded from Sprint 78 financial transactions and historical statement chronology.

### Current Axis ownership semantics

Current authentic Axis sources do not prove row-level primary/add-on physical-card ownership.

Sprint 78B therefore requires:

- one explicit liability-account decision where strong source identity is absent;
- account-level Axis transaction evidence;
- zero fabricated Axis `CardInstrument` records;
- zero fabricated statement instrument sections;
- zero fake mask-derived strong identities;
- no automatic same-bank/family account merge.

The primary/add-on physical-card distinction is not required for the current Axis outcome.

### Accepted Axis PDF/XLSX implementation boundary

- App PDF tagged transaction-table evidence is the current authoritative App transaction carrier.
- The prior positioned App-PDF financial reconstruction/veto is superseded and must not regain acceptance authority.
- Traditional PDF may use the generic positioned-evidence path required by that exact layout.
- `PDFDocumentReader` remains generic source extraction and must not own Axis financial or credential-family policy.
- The accepted Axis XLSX profile uses a bounded deterministic OOXML reader with pinned/vendored ZIPFoundation and strict package/XML validation; this does not establish generic XLSX support.
- V1–V14 migrations remain immutable.
- Additive V15 remains the accepted Sprint 78B migration. Additive V16 is accepted with Sprint 79 and is now the current migration baseline.

### Accepted Axis credential architecture

Explicit user-settled source fact: **Axis App PDFs and Axis traditional PDFs use two different legitimate passwords.**

The accepted Sprint 78B architecture uses two durable canonical credential scopes:

```text
axis-bank.credit-card.app-pdf
axis-bank.credit-card.traditional-pdf
```

The old unscoped `axis-bank` item and registered historical Axis legacy item(s) are compatibility candidates only.

Required behavior:

- uncredentialed read first;
- deterministic bounded remembered candidates;
- secure challenge only after remembered candidates fail;
- exact App/traditional target determined only after successful decryption and structural recognition;
- remembered success in the exact canonical family causes no Keychain write;
- compatibility-origin success may migrate only to the proven family scope after parse + validation;
- challenge success writes only the proven family scope after parse + validation;
- one family rotation must never overwrite the other;
- credentials never enter SQLite, financial evidence, fixtures or logs.

This credential architecture is accepted production state and is published by the 2026-08-27 ADR-015 alignment amendment.

### Sprint 78B acceptance record

Sprint 78B was technically accepted on 2026-08-27 after the final stable post-credential-correction candidate proved, at minimum:

- exact 35-file active private inventory and locked/unlocked pairing;
- locked and unlocked production-path equivalence for each monthly PDF family;
- Jan–Jul 796-row App/XLSX/traditional financial multisets with exact multiplicity;
- March and June duplicate multiplicity in all three representation families;
- exact App↔XLSX source order and narration;
- source-proven selected month;
- zero Active-Loans transaction leakage;
- May representative In-Memory and SQLite multi-source campaigns;
- one liability account, zero fabricated Axis instruments/sections;
- first May source creates 143 canonical transactions and later exact-equivalent representations create zero new canonical transactions;
- SQLite checkpoint/close/reopen and canonical hydration;
- zero accepted financial residue on rejection;
- focused credential/Axis/Amex/CBQ/parser/provider/hydration tests;
- fresh Debug build;
- fresh optimized Release build;
- exactly one authoritative complete `TestPlan.xctestplan` after the shared credential correction stabilizes;
- privacy/residue and `git diff --check` review.

Final accepted validation completed the focused shared boundary, authentic 35-file Axis private gate, fresh Debug build, fresh optimized Release build and exactly one authoritative complete TestPlan. The TestPlan executed 804 tests: 799 passed, 5 external-private-context tests were intentionally skipped with visible reasons, and 0 failed. Earlier green Sprint 78B results from before the dual-credential correction remain historical evidence only.

### Current documentation and execution authorities

- Repository bootstrap: `AGENTS.md`.
- Human routing guide: `Project documents/Project_Guide.md`.
- Current cycle roadmap: `Project documents/Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md`; the prior `Project documents/Sprint roadmap/Archived/LedgerForge_Roadmap_Sprints_70-79_Current.md` is retained as the historical prior-cycle roadmap.
- Standing execution method: `Project documents/LedgerForge_Standing_Execution_Harness_Guide.md`.
- Accepted state: this file.
- Unscheduled queue: `Project documents/FUTURE_WORK.MD`.
- Accepted architecture: `Project documents/ADR.md`.
- Current task authorization: complete Chat-approved prompt.

ChatGPT Chat owns sprint/architecture/prompt/acceptance decisions. MCP executor is the Chat plugin for guarded local Mac repository/Xcode access. Codex is a separate execution environment and does not automatically inherit Chat-only context. Model capability order is **Sol > Terra > Luna** and is independent of execution environment.

---

## Repository Baseline

- **Primary branch:** `main`
- **Current repository implementation baseline:** accepted Sprint 87 at `93c068c23027a8cd59753ac4ac916e6cee75adbf`, followed only by the user-approved project serialization commit `b2f7ac2a6a517c1365b93274e2ba868b5068a7a4`, layered on accepted Sprints 81–86 and the technically accepted unnumbered Authentic-Corpus Parser / Import Reliability Reset with additive V17; Sprint 79 and its commit `9489f6b21c9d585d2d90f2ba4798a931590057f7` remain in Git history
- **Documentation alignment:** Reconciled for accepted Sprints 81–87 and Chat-authorized Sprint 88, the accepted unnumbered reset, additive V17, the Sprint 79 financial-domain implementation and the accepted Sprint 80 readiness-discovery boundary
- **Accepted source-truth repair:** P0 Axis bank-account source-truth restoration remains historical accepted work. Sprint 65's clean-room/sanitized fixture work is retained only as historical mechanics evidence under ADR-046 and is not current parser regression or acceptance authority; no historical financial data was altered
- **Latest chronologically accepted production implementation:** Sprint 87 — Coordinated Swift-6 Migration; the unnumbered Authentic-Corpus Parser / Import Reliability Reset remains the latest accepted parser/source implementation, and Sprint 79 remains the latest numbered financial-domain feature implementation
- **Latest verified Debug development-tooling implementation:** DBP-01 Developer Database Profiles at `2d86f91dc46b9e88bcdfea65c88ddf671968b388`
- **Non-implementation commits after Sprint 53:**
  - `bdb51b0ddcdde097e456a16bab7f0bf999fd595b` — roadmap update
  - `7ee20a909038d1088f830a6ea588311625f415e5` — planning reconciliation and tracked Xcode user-data removal
  - `de238d8abf5ee7dc7d1eb9cd13fab72803f2be28` — roadmap update after the discovery campaign
  - `a64c2d8d67e93631d8b0c32620ded72f389f252f`, `98b1fef111087d3b8c2b26f8c354c2147c6b2412` and `f50127ccb7ddf05641df1af7a14a93be2ea8b42e` — subsequent roadmap updates
- **Latest verified completed numbered increment:** Sprint 84 — PR-2 SQLite / Provider / Migration Ownership
- **Accepted Sprint 63 implementation ref:** `7e1345e3817d3c3e91c24f881b962a48279fd73b`
- **Latest accepted ADR:** ADR-046 — Authentic-Corpus-Only Parser Authority and Adaptive Financial Source Interpretation; the accepted reset implements its complete registered-corpus reliability boundary
- **Current migration:** V17; V1–V16 remain immutable
- **DBP-01 classification:** Accepted DEBUG-only developer tooling and development-database lifecycle implementation; it is not a production financial capability, production database-profile feature, numbered sprint, Sprint 65, schema migration or personal-v1 adoption
- **Sprint 55A:** Axis Bank Source-Truth Restoration, ending at `f3154dbd13a340714179da7f972a6accdd3aca54`; parallel shared-runtime-store isolation remains Sprint 55 acceptance/test infrastructure
- **Sprint 57A:** Category Reconciliation Closure, complete at `251a547cb44712a789a9ad7b23a4eabca742900b`; no migration was added
- **Sprint 58:** Deterministic Import Verification Workspace, complete at `4547083d4d81edc9b6bcd98c3a8e77ee1538e71a`; DEBUG-only ordinary-path verification with Release containment and an isolated exact-duplicate runtime check
- **Sprint 59:** Accepted ADR-041 as an architecture-only source-snapshot and exact source-byte fingerprint contract; implementation was intentionally deferred to a later increment
- **Sprint 62:** Accepted the ADR-041 immutable source snapshot and exact source-byte fingerprint architecture contract; no production implementation was included in Sprint 62
- **Sprint 63:** Implemented and independently accepted the immutable source-snapshot and exact source-byte fingerprint foundation
- **Sprint 64:** Completed the approved read-only Axis bank-account PDF readiness discovery. Its bounded candidate was the two-source account-neutral Axis bank-account PDF v1 family represented by retained NRO evidence.
- **Sprint 65:** Implemented and accepted the exact shared `axis.bank-account.pdf@1` grammar through the ordinary import path. The selected NRE/NRO originals, regenerated sanitized fixtures and independent row-level financial baselines now establish the bounded production boundary; broader Axis PDF layouts remain unsupported.
- **Sprint 65 blocker reconciliation:** `BLOCK-PDF-LINEAGE-01`, `BLOCK-PDF-ORACLE-BINDING-02`, `UNCERTAINTY-PDF-DETERMINISM-03`, `UNCERTAINTY-PDF-SOURCE-CLASS-04` and `UNCERTAINTY-NRE-NRO-GRAMMAR-05` are closed only for the selected unlocked/selectable-text grammar and its account-neutral NRE/NRO family. They remain open for other layouts, OCR, password-protected documents and generic Axis PDF support.
- **Sprint 66:** Implemented typed confirmed-import recovery, privacy-safe route-specific guidance, wholly fresh preparation for eligible zero-commit outcomes and bounded canonical reconciliation without changing persistence architecture
- **Sprint 67:** Preserved the durable imported-document relationship through canonical hydration and added one typed, privacy-safe transaction-detail projection for account, source-document and import-session provenance; missing legacy evidence remains neutral
- **Sprint 67A:** Corrected source-document presentation so only the exact durable `ImportedDocumentDTO` referenced by a transaction can authorize its displayed filename; import-session labels are not document authority
- **Sprint 68:** Removed future-module navigation, global and account placeholder search/filter chrome, disabled transaction ranges and inert row affordances, unsupported dashboard spending/trend presentation, the misleading Add Account action and unimplemented drag-and-drop copy. Repository-backed balances, native-currency transaction summaries, account editing, transaction search/toggles/category assignment, ordinary import workflow and Developer Mode containment remain.
- **Sprint 68 privacy boundary:** Production diagnostic emitters now use fixed messages, typed outcomes, enum values and counts; generic preparation/persistence failures fail closed to bounded presentation. Raw parser names, delimiter/encoding context and unrecognized account-identifier schemes do not reach Developer Console presentation, metadata or copied text.
- **Sprint 68A:** Corrected residual truthful UI from Sprint 68 by replacing the idle Validation Review's four fabricated Pending rows with one neutral empty state, removing the `Awaiting confirmation` footer pseudo-action, the static profile dropdown chevron, dashboard account-row chevrons and the account-detail favourite star. Real validation results, confirmation gating, retry and transaction actions, account editing, transaction search/toggles/category assignment, ordinary import and Developer Mode containment remain.
- **Sprint 68B:** Test-only correction to Sprint 68's bounded persistence-error contract. The generic public wrapper message remains, while typed identity outcomes and durable-attempt authority remain preserved.
- **DBP-01 maintenance correction:** Test lifecycle ownership was corrected so successful prepared imports have explicit terminal ownership and shared lifecycle-gate tests use target-wide isolation. It changed no production lifecycle behaviour, migration or ADR.
- **Sprint 69 repository interface:** `./script/validate.sh`, `./script/build_and_run.sh` and the Codex Run action are repository-verified local interfaces at the Sprint 69 baseline. The action invokes `./script/build_and_run.sh --verify`.
- **Sprint 69 acceptance-evidence classification:** The scripts, configuration and tests are repository-verifiable at the baseline; the build, test, process and runtime results recorded below are reported local execution evidence and were not re-executed by this documentation-only update.
- **Sprint 71:** Added a native OLE2/BIFF8 reader and the exact `axis.bank-account.xls@1` Axis NRO profile through the ordinary reader, detector, classifier, normalizer, parser, review, confirmation, provider and hydration pipeline. The reader is XLS-only; XLSX, OOXML, formula evaluation, macros, generic spreadsheet mapping, other layouts and cross-format duplicate suppression remain unsupported.
- **Sprint 71 third-party boundary:** LedgerForge vendors the required libxls 1.6.3 sources from `libxls/libxls` tag `v1.6.3` at `c199d132494833da696b58aa4acf3fc5a36d930b` under the BSD 2-clause license. The local Swift package builds a static C library, exposes only the LedgerForge bridge and links only the macOS system `iconv` boundary.
- **Sprint 71 source truth:** The committed independent evidence verifies 16 baseline XLS transactions, 20 extended XLS transactions, 16 shared ordered rows and 4 extended-only ordered rows. The Range-1 CSV legitimately contains 17 transactions while its XLS contains 16; no fixture or expected evidence was changed to manufacture parity.
- **Sprint 71 fail-closed boundary:** Invalid or truncated containers, encryption, multiple or hidden worksheets, formulas, boolean/error cells, missing/duplicate/ambiguous/reordered headers, malformed monetary values and unsupported near-match layouts reject before accepted financial writes. Workbook bytes remain confined to the transient immutable source snapshot.
- **Sprint 72:** Added the exact shared `hdfc.bank-account.xls@1` HDFC NRE/NRO legacy-XLS grammar through the accepted reader and ordinary detector, classifier, parser-selection, preview, explicit-confirmation, provider, hydration and relaunch pipeline. Exact source bytes remain the XLS duplicate authority; no PDF/XLS cross-format suppression was added.
- **Sprint 73:** Added the exact native selectable-text `hdfc.bank-account.pdf@1` grammar and the first durable exact whole-statement equivalence contract for the approved HDFC PDF/XLS v1 pair. The first accepted source remains transaction and provenance authority; a later exact-equivalent other-format source retains its own accepted evidence and creates zero transactions.
- **Sprint 73A test-only closure:** Corrected three stale Developer Database Profile expectations after Migration V10. V9 is the newest and default historical migration-sandbox source, V8 remains historical, and V10 remains current. Sprint 73A changed no production, parser, migration, ADR, persistence, fixture, source-truth or financial behaviour. The replacement cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 670 tests across 81 suites and zero failures.
- **Sprint 74:** Added exact `cbq.current-account.xls@1` support for the retained CBQ current-account transaction-history legacy-XLS grammar through the ordinary direct-URL reader, detector, classifier, parser-selection, validation, explicit-confirmation, provider, hydration and relaunch path. Signed QAR amounts, descending physical source order, same-date ambiguity and every printed row-associated balance are preserved without inventing a statement period, value date, timestamp or source-order balance recurrence.
- **Sprint 74 identity and source boundary:** One parser-owned verified full printed institution account identifier is the sole strong account identity. Holder text and filename are not identity. Blank merged-cell placeholders are retained as physical blanks, while hidden cells carrying financial or textual evidence continue to fail closed. Exact source bytes remain duplicate authority.
- **Sprint 74 private-source acceptance:** The bound 61-row legacy-XLS source passed the ordinary `ImportEngine.prepareImport(from:)` path. All 61 dates, signed amounts and row-associated balances matched an independently extracted six-page selectable-text PDF projection in source order with zero mismatches. Preparation wrote nothing; confirmation produced one accepted event set; exact-byte reimport produced no duplicate financial events; In-Memory and SQLite graphs matched; SQLite close/reopen and canonical hydration preserved the complete graph. No private source value, identifier, path, filename, narration, reference or oracle digest was published in repository documentation, and task-owned private artifacts were removed after verification.
- **Sprint 74 focused acceptance:** The final changed reader/CBQ boundary passed 19 tests across 4 suites; the broader adjacent legacy-XLS, Axis/HDFC XLS, detection, classification, selection and validation boundary passed 52 tests across 10 suites. The new CBQ synthetic surface passed 13 tests across 3 suites before the merged-placeholder correction and is subsumed by the final focused boundary.
- **Sprint 74 cycle-close acceptance:** The single authoritative cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 683 tests across 84 suites and zero failures.
- **Sprint 75:** Added exact native selectable-text `cbq.current-account.history.pdf@1` and `cbq.current-account.monthly.pdf@1` profiles beside `cbq.current-account.xls@1`. History PDF preserves its full account identifier, posting dates, signed QAR amounts, descending source order and row-associated balances without inventing a period, value date or summary. Monthly PDF preserves posting date as the canonical event date, source Transaction Date only as a separate observation, masked account/IBAN evidence, debit/credit direction, QAR Money, balances, statement boundary and brought-forward/closing evidence; brought-forward and exact non-financial promotional content are not transactions.
- **Sprint 75 account identity:** Full identifiers remain strong parser-owned ownership evidence. Typed masked CBQ account and IBAN patterns are durable evidence about an account, never fabricated full identifiers. Exact positional masked/full compatibility may resolve or explicitly narrow account choice, and a later compatible full history identifier attaches atomically to the existing monthly-created account. Generic identity resolution and generic no-match selection safety remain unchanged.
- **Sprint 75 source lineage:** ADR-043 keeps one canonical transaction while every accepted source retains its own document, exact source-byte fingerprint, session, normalized rows, statement observation and one transaction observation per financial row. Exact account, posting date, signed QAR amount and row balance establish lineage; a structured-reference digest is used only for exact collision disambiguation. Monthly PDF is preferred over history PDF, then history XLS, for source-evidence presentation only; canonical transaction document/session provenance is never rewritten.
- **Sprint 75 persistence:** Additive Migration V11 introduces typed CBQ source-identity, statement-source and transaction-source observations with restrictive relationships, exact accepted-row coverage and no historical backfill. Reviewed all-new, mixed and fully represented sources are atomically revalidated and committed with SQLite/In-Memory parity. Fully represented sources remain accepted with zero new transactions and complete source evidence.
- **Sprint 75 private-source acceptance:** Four direct-URL source-order campaigns were verified with both SQLite and In-Memory. History-first campaigns imported 60 then 0, 0 and 0 new transactions; monthly-first campaigns imported 9, 8, 43 and 0. Every campaign ended with one account, 60 canonical transactions, four durable attempts and 60 preferred-source mappings; SQLite reopen preserved the same graph. Independent history PDF/XLS comparison covered 60 exact rows with zero ordered or event-set mismatches, and the two monthly sources contributed 9 and 8 exact subset rows. Only aggregate counts are recorded; no private value, path, filename, identifier, narration, reference or digest was published.
- **Sprint 75 focused acceptance:** The new PDF/lineage suite passed 8 tests; the final diagnostic correction passed 35 tests across the four affected legacy suites. The detector now selects exact institution rules by source extension so a broad PDF signature cannot admit a damaged XLS near-match.
- **Sprint 75 cycle-close acceptance:** After the material detector correction, the authoritative replacement cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 691 tests across 85 suites and zero failures. The earlier pre-correction cycle ran the same 691 tests and failed five tests with six reported issues; it is not acceptance evidence.
- **Sprint 76 profile and source semantics:** Added exact native selectable-text `amex.credit-card.pdf@1` for the approved American Express Middle East Platinum QAR statement family. Posting Date remains the canonical transaction date; source Transaction Date is preserved separately. Charges increase amount owed, payments/refunds decrease amount owed, and bank debit/credit fields remain unused. Account-level payments, instrument rows, original merchant Money, multiline narration, references, statement summaries and physical source order are preserved. Rewards and final informational pages remain non-financial only under exact family signatures.
- **Sprint 76 shared card domain:** ADR-044 reuses the durable credit-card `Account` as the liability account and adds immutable application-owned `CardInstrument` identity, source observations, explicit instrument relationships, bounded lifecycle state, card-specific transaction effects, typed statement evidence and a dedicated runtime `CardStore`. Masked Membership Number and Card Account Number observations never become strong identifiers. Exact durable user-confirmed mappings may be reused; changed weak evidence requires explicit account/instrument authority, and lifecycle or replacement is never inferred from chronology.
- **Sprint 76 persistence and hydration:** Additive Migration V12 adds seven restrictive card tables with no historical backfill. Provider-owned confirmed import atomically writes and revalidates the account/instrument/statement/transaction graph with SQLite/In-Memory parity. Canonical hydration reconstructs and validates that graph after close/reopen. Current liability balance is selected by newest source statement date, not import time, and published with net-worth sign; charges/payments do not enter ordinary bank income/expense totals.
- **Sprint 76 private-source acceptance:** The two approved originals were verified directly by SHA-256 and independent PDFKit row extraction. The earlier statement contained 61 rows and the later statement 34 rows. Ordered production-versus-independent comparisons produced zero row mismatches and zero summary mismatches for both statements; closing-to-opening continuity matched exactly. Chronological and reverse campaigns with both providers ended with one liability account, one instrument, 95 transactions, two statements and a runtime balance of negative QAR 7,761.88. Exact-byte duplicate handling, SQLite checkpoint/close/reopen and canonical hydration preserved the same graph. No private source path, filename, transaction list, identifier, narration or source-derived fixture was published.
- **Sprint 76 lifecycle falsification:** Exact previously confirmed observations reuse one instrument; changed weak evidence rejects without accepted residue until an explicit separate-account or additional/replacement/renewal/upgrade decision is supplied. No relationship changes lifecycle from `unknown`; stale provider generation and conflicting strong instrument ownership reject atomically in SQLite and In-Memory. Importing the older statement after the newer statement does not change current balance authority.
- **Sprint 76 focused acceptance:** The frozen Amex/migration/lifecycle boundary passed 61 tests across five suites. The adjacent CBQ, HDFC, Axis, bank-validation, categories, accounts and dashboard regression boundary passed 104 tests across 12 suites. The cycle-discovered V12 metadata correction passed 12 tests across two suites.
- **Sprint 76 cycle-close acceptance:** The authoritative replacement cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 701 tests across 86 suites and zero failures. The first cycle-close completed both builds but found four stale V11 test expectations; after the named V12-only correction, the replacement run is acceptance evidence.
- **Sprint 76A multi-instrument correction:** `CardStatementEvidence`, confirmation, persistence, hydration and presentation now preserve ordered `0...N` document-scoped instrument sections. Each section owns its typed card-account observation, explicit durable-instrument decision, financial rows and signed total; same holder text does not merge sections, section credit totals retain source direction and statement summary arithmetic remains separate.
- **Sprint 76A encrypted PDF and credential boundary:** The shared PDF reader unlocks the same immutable source snapshot and hands native text plus page boundaries to exact Amex normalization in memory; it creates no decrypted PDF file or reconstructed source bytes. Import coordination tries bounded remembered candidates, uses the secure UI challenge only when needed and persists a successfully used password under the detected institution's namespaced Keychain scope only after successful unlock and authoritative detection. Reader, parser, diagnostics, SQLite and source evidence never own the credential. Production Keychain persistence/reuse was manually proven; deterministic automation uses the already-authorized test-host or in-memory credential path.
- **Sprint 76A currency authority:** `ledgerforge.currency-catalog.v2` contains 155 deterministic active ordinary ISO 4217 List One currencies with numeric minor units from the SIX 2026-01-01 publication, excluding current List Two fund codes and List One `N.A.`-scale entries. Catalog membership and 0/2/3-digit Money mechanics do not imply parser or institution support, FX rates, conversion or reporting-currency totals.
- **Sprint 76A persistence and semantic sources:** Additive Migration V13 leaves V1–V12 immutable, migrates readable V12 single-section card graphs deterministically and adds ordered card-statement sections, section observations and exact semantic projection/group/member records. Byte-distinct sources may share one card semantic group only after complete ordered projection equality; the first is authoritative and exact later sources are supporting evidence with zero duplicate canonical transactions. SQLite/In-Memory parity, provider reconstruction, hydration and zero-residue rejection are enforced.
- **Sprint 76A exact Amex and private-source acceptance:** The exact `amex.credit-card.pdf@1` grammar now supports all section/page arrangements proven by ten source documents: eight encrypted originals and two byte-distinct unlocked equivalents. The eight chronological statements contain 21, 32, 49, 63, 34, 61, 34 and 60 financial rows, 354 total; 8/8 statement equations, 7/7 adjacent balance continuities, zero Posting Dates outside period and zero section reconciliation mismatches passed the independent oracle. Three instrument observations were preserved. Production-versus-oracle comparison, chronological/reverse/mixed campaigns, both equivalent-pair orders, combined ten-source import, SQLite/In-Memory parity and reopen/hydration passed. No private value, identifier, path, filename, password or decrypted artifact was published in repository history or documentation.
- **Sprint 76A cycle-close acceptance:** After correcting one stale test oracle that still treated newly supported JPY as unsupported, the authoritative replacement cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 721 tests across 87 suites, zero failures and zero skips. The first cycle-close completed both builds and ran the same 721 tests but failed only that stale expectation; it is not acceptance evidence.
- **Sprint 77 exact profile and model correction:** Added exact encrypted native-text `cbq.credit-card.pdf@1` with deterministic internal v1/v2 layout provenance. Financial account/instrument scope is now independent from optional physical source-section membership, so an account-level payment may contribute to its printed section subtotal without acquiring an instrument. Typed CBQ Card Account Reference and masked companion-instrument observations remain source evidence, not strong identity. CBQ current-account detection and ADR-043 lineage remain separate.
- **Sprint 77 reconciliation and persistence:** Card validation now selects exact Amex, CBQ v1 or CBQ v2 summary and section contracts through typed profile evidence. Additive Migration V14 leaves V1–V13 immutable, generalizes the four constrained card evidence tables, adds printed-summary membership and preserves existing V13 Amex graphs without semantic backfill. SQLite and In-Memory confirmation, exact-byte duplicate rejection, newest-source-date balance authority, close/reopen and canonical hydration preserve the same two-instrument shared-card graph; no CBQ-specific card domain was created.
- **Sprint 77 password boundary:** ADR-015's institution-scoped Keychain-backed PDF credential infrastructure is now a production dependency of exact Amex and exact CBQ card profiles. Remembered reuse, failed remembered-candidate replacement and save-after-authoritative-profile validation are verified. This establishes neither generic encrypted-PDF support nor password proof for unrelated Axis, HDFC, CBQ bank, investment or other layouts.
- **Sprint 77 private-source acceptance:** Eight approved three-page encrypted CBQ originals, split four v1/four v2, contain 15, 19, 28, 14, 11, 18, 12 and 16 financial rows, 133 total. The independent oracle produced 8/8 statement reconciliations, 6/6 valid supplied adjacent continuities, no fabricated May-to-July continuity, and zero row, section or statement-summary mismatches. Chronological, reverse and mixed campaigns in SQLite and In-Memory each ended with one liability account, two companion instruments, eight statements and 133 canonical transactions; exact duplicate rejection, SQLite reopen and hydration preserved the graph. No private value, identifier, path, filename, password, transaction listing or decrypted artifact was published in repository documentation.
- **Sprint 77 focused and cycle-close acceptance:** The final adjacent card, CBQ-bank, migration, password, confirmation and hydration boundary passed 131 tests with 156 parameterized executions and zero failures or skips. The authoritative replacement cycle-close passed fresh Debug and optimized Release builds plus the complete TestPlan with 733 tests across 90 suites, zero failures and zero skips. The earlier 730-test cycle preceded the audit-driven exact tail, ambiguity, source-page oracle and statement-date balance-authority corrections and is not final acceptance evidence.
- **Sprint 72 source semantics:** `Date` is the authoritative transaction date, `Value Dt` is retained separately, `Withdrawal Amt.` is debit/outflow, `Deposit Amt.` is credit/inflow, and source physical row order plus source ordinals are preserved. Printed period, opening/closing balances, debit/credit counts and totals reconcile independently for each statement.
- **Sprint 72 identity and fail-closed boundary:** Only the parser-produced verified full account number is emitted through the strong institution-account identifier contract. Shared customer identity and product metadata are excluded from account resolution. Missing, malformed, duplicate, reordered, near-match or ambiguous grammar, amount, date, identifier and summary evidence fails closed with zero accepted financial residue.
- **Sprint 72 private-source acceptance:** Four private-original XLS/PDF source families were verified locally through an independent paired-PDF oracle: 62, 16, 76 and 7 ordered rows, 161 total. Requested row-field mismatches, printed-summary mismatches and two annual-to-recent continuity mismatches were all zero. No private source value, path, filename, identifier, narration or reference was published in repository documentation; task-owned source-derived artifacts and private-test result bundles were removed after verification.
- **Sprint 60:** Completed the read-only account-outcome explanation contract across the bounded import workflow; no schema or historical rewrite occurred.
- **Sprint 61:** Implemented privacy-safe durable account-outcome presentation and explicit eligible no-match account choice. FinancialIdentityResolver behavior is unchanged: parser-produced strong verified identifiers remain the sole identity authority, and eligible no-match cases require explicit Use Existing Account or Create New Account choice. No automatic account selection was introduced. Prospective successful durable account decisions are `matched_existing`, `user_selected_existing` and `created_new`; rejected outcomes include `account_choice_required`, `identifier_ownership_conflict`, `identity_ambiguity`, `identity_conflict`, `stale_account_choice` and `stale_provider_generation`. Historical `selected_existing` and `resolved_or_created` remain neutral and are not reinterpreted. One shared bounded presentation authority serves preparation, immediate result and Import History; hostile and unknown values fail closed to neutral unavailable presentation. Account IDs, candidate IDs, normalized identifiers, suffixes, filenames, paths, fingerprints, raw codes and unrestricted errors are excluded from account-outcome copy and accessibility text. SQLite/In-Memory parity and rejected-path zero accepted residue were verified. No schema or historical rewrite occurred.
- **Sprint 61 integrated verification:** 466 top-level tests, 498 executions, 39 dynamic-parameter runs, 0 failures and 0 skips; Debug build, explicitly optimized whole-module Release build and Debug analysis passed. Isolated runtime acceptance used the approved sanitized Axis fixture against one fresh namespaced canonical V8 SQLite database. Preview, explicit choice, confirmation, immediate result, live Import History, quit/relaunch and hydration were verified. Runtime persisted and rehydrated 1 account, 4 transactions and 1 durable attempt. The task-owned namespace was removed recoverably after acceptance. No private source or user financial database was used. Manual linking, unlinking, reassignment, repair, account merge/split and raw identifier display remain excluded.
- **Historical repair boundary:** no retained affected historical Axis database is currently identified; no historical repair was performed
- **Architecture baseline:** Architecture v1.0 Frozen and UI/UX v1.0 Frozen
- **Latest verified repository-maintenance change:** `7ee20a909038d1088f830a6ea588311625f415e5`
- **Latest verified implementation-adjacent maintenance repair:** P0 Axis bank-account source-truth restoration; new imports use `axis.bank-account.csv@2`, physical DR is debit/outflow and physical CR is credit/inflow, and header positions remain dynamically resolved
- **Current overlap boundary:** ordinary no-overlap statements remain full imports, exact-content duplicates remain ADR-030 outcomes, and full supported event overlap remains whole-statement blocked; provenance-less mixed-overlap evidence is unsupported and cannot produce a new reviewed partial plan
- **ADR-040/V7 alignment:** reviewed-plan, disposition, attempt-count and hydration structures remain readable and validated, but the former provenance-less Axis partial-import family is suspended; mixed supported overlap currently fails closed
- **Source-byte boundary:** existing CSV history remains authoritative under `ledgerforge.raw-text.sha256.v1` with `ledgerforge.source-bytes.sha256.v1` secondary; PDF and XLS use `ledgerforge.source-bytes.sha256.v1` as their single duplicate authority and retain deterministic extracted/projected text only as secondary evidence, with one transient immutable `SourceContentSnapshot` and no durable raw PDF or workbook bytes
- **Sprint 58 duplicate acceptance:** an isolated exact duplicate left accepted transactions, sessions, documents, fingerprints, account state, balance and hydrated presentation unchanged, adding only one durable rejected duplicate attempt
- **Sprint 56 persistence:** Migration V7, immutable reviewed-plan digests, typed row dispositions, explicit attempt counts and strict hydration/relaunch reconstruction remain readable and validated for historical repository state, but no new partial session is authorized without lineage-backed overlap evidence
- **Current exclusions:** unapproved institutions/profiles, currencies outside exact supported paths, unsupported event families, generic mixed or interleaved overlap, arbitrary omission, fuzzy candidates, ownership override and historical repair remain unavailable
- **Sprint 57 categories:** workspace-owned user categories and one optional current category assignment per trusted imported transaction are durable, hydrated, manually editable and additive metadata only
- **Sprint 57 persistence:** additive Migration V8, SQLite/In-Memory parity, provider-generation protection, canonical hydration, provider reconstruction and SQLite close/reopen verification are implemented
- **Sprint 57 UI:** Settings supports create, rename, archive, restore and permitted delete; transaction detail supports assign, change and clear, and transaction rows display the current category
- **Sprint 57 exclusions:** automatic categorization, rules, suggestions, bulk editing, merge, delete-with-replacement, budgeting, analytics, reports, filtering, tags, splits and import behavior changes remain unavailable
- **Canonical development database:** a disposable canonical database was successfully recreated through the registered migration chain at V9; no private database contents are recorded here
- **Latest Sprint 65 focused result:** 381 tests across 43 suites passed; 0 failures, skips or expected failures; changed-file warnings 0 and analyzer diagnostics 0
- **Latest Sprint 65 complete-TestPlan result:** 607 tests across 73 suites passed; 0 failures, skips or expected failures; changed-file warnings 0 and analyzer diagnostics 0; 9 pre-existing warnings remained
- **Latest Sprint 67 focused result:** 36 tests across 3 suites passed with zero failures; hydration, forced refresh, atomic failure preservation, detail presentation, existing filters, confirmed-import recovery and SQLite relaunch coverage were included
- **Latest Sprint 67 complete-TestPlan result:** 616 tests across 73 suites passed with zero failures; one fresh Debug build passed, with only the pre-existing AppIntents metadata notice and unrelated Swift 6 transition warnings
- **Sprint 67 runtime verification:** one fresh namespaced V9 SQLite database imported the approved sanitized Axis NRE fixture through the ordinary Debug workflow; selected transaction detail showed authoritative account, institution, source document, import time, Money, direction, statement date, running balance, category and validation before and after quit/relaunch. The database held 1 account, 4 transactions, 1 document and 1 session, with all 4 transactions retaining account/document/session relationships. The task-owned namespace and build artifacts were moved recoverably to Trash.
- **Latest Sprint 67A focused result:** 80 tests across 4 suites passed with zero failures; exact document lookup parity, canonical hydration, malformed/legacy fail-closed behavior, typed detail presentation, category/search/toggle preservation and SQLite close/reopen reconstruction were included
- **Latest Sprint 67A complete-TestPlan result:** 622 tests across 73 suites passed with zero failures; one fresh isolated Debug build passed with only the pre-existing AppIntents metadata notice
- **Latest Sprint 68 focused result:** 153 tests across 14 selected suites passed; 0 failures, skips or expected failures. Fresh Debug and Release builds passed; the existing Swift 6 transition warnings remained outside this sprint's source boundary.
- **Sprint 68 runtime verification:** A fresh signed Debug app used one empty task-owned V9 namespace. Accessibility inspection verified only the five ordinary destinations, accurate file-chooser wording, preserved text search and Credits/Debits controls, absence of the removed placeholder affordances, and Developer Console visibility only while Developer Mode was enabled. Console category filtering and Copy All showed bounded diagnostics. Task-owned namespace, build products and result bundles were moved recoverably to Trash.
- **Sprint 68 TestPlan decision:** The complete `TestPlan.xctestplan` trigger did not fire: Developer Console storage/output, shared persistence, Money, hydration, import and mutation semantics were unchanged, and focused tests showed no cross-suite interference. Sprint 69 remains the cycle-wide TestPlan gate.
- **Latest Sprint 68A focused result:** A fresh Debug build passed. 97 tests across 8 selected suites passed with 0 failures, skips or expected failures; `git diff --check` passed. Existing Swift 6 transition warnings remained outside the Sprint 68A source boundary.
- **Sprint 68A runtime verification:** A fresh signed Debug app used one isolated task-owned V9 namespace. The idle import review was neutral with no Pending rows or footer pseudo-action; the ordinary approved sanitized-fixture flow showed real validation, explicit confirmation gating, no dashboard-account chevron, no account-detail star, working display-name editing and real transaction search plus Credits/Debits controls. Task-owned namespace, build products and result bundles were moved recoverably to Trash.
- **Sprint 68A TestPlan decision:** The complete `TestPlan.xctestplan` trigger did not fire: shared import-state logic changed only through presentation mapping; repository, hydration, Money, diagnostics and mutation code were unchanged; and focused tests showed no cross-suite interference. Sprint 69 remains the cycle-wide TestPlan gate.
- **Sprint 68A migration and ADR impact:** Migration remains V9 and ADR-041 remains the latest accepted ADR; neither changed.
- **Latest Axis source-truth automated result:** 426 top-level tests (458 parameterized executions), 0 failures and 0 skips in the complete signed canonical TestPlan before Sprint 65
- **Latest Axis source-truth focused result:** 41 top-level tests (46 parameterized executions), 0 failures and 0 skips across direction, source-oracle, NRO evidence, overlap-quarantine, shared-profile and direct-provider fail-closed suites using SQLite and In-Memory providers
- **Latest Axis source-truth build result:** fresh signed Debug and explicitly optimized Release builds plus Debug and Release static analysis pass
- **Private-source verification:** Sprint 65 exercised four original PDF/CSV pairs through separate fresh signed-app profiles, explicit confirmation and quit/relaunch hydration. Redacted results: NRE1 PDF 46 rows versus CSV 47 with matching first 46 ordered projections and one non-duplicate CSV row outside the PDF date range; NRE2 49/49 full projection, identity and summary parity; NRO1 PDF 16 versus CSV 17 with matching first 16 ordered projections and one non-duplicate CSV row outside the PDF date range; NRO2 20/20 full projection, identity and summary parity. Original PDF parser success is the hard acceptance authority. No private source value, path, filename, database or copied evidence was published in repository documentation, result bundles, diagnostics or build products.
- **Latest reported local automated result:** Sprint 69's canonical complete TestPlan recorded 628/628 tests passed with zero failures and zero skips
- **Latest focused category-reconciliation result:** 71 top-level tests (86 parameterized executions), 0 failures and 0 skips across category, hydrator, import-hydration, development-lifecycle and migration-integrity suites
- **Latest reported local build result:** Sprint 69 fresh Debug and Release builds passed before the reported canonical TestPlan result
- **Sprint 71 acceptance evidence:** All named focused reader, normalizer, parser, detector/classifier, source-snapshot, fingerprint, provider-parity, persistence, hydration and relaunch suites passed with nonzero execution. The authoritative cycle-close passed fresh Debug and Release builds and 643 tests across 76 suites with zero failures or unexpected skips. SQLite and In-Memory exact-reimport outcomes matched, provider reconstruction and SQLite close/reopen preserved the complete XLS graph, and rejection tests left zero accepted residue.
- **Sprint 71 Release boundary:** The arm64 Release app contains the XLS bridge and libxls symbols statically in the executable, links the system `libiconv`, contains no libxls dynamic library and requires no bundled Java, Python or LibreOffice runtime. The repository contains the verbatim upstream license and concise third-party notice. Migration remains V9 and ADR-041 remains the latest accepted ADR.
- **Sprint 72 acceptance evidence:** The consolidated focused boundary discovered and executed 207 tests across 29 selected suites with zero failures. The single authoritative cycle-close passed fresh Debug and optimized Release builds plus 655 tests across 79 complete-TestPlan suites with zero failures or unexpected skips. SQLite and In-Memory outcomes matched; exact-byte duplicate rejection, atomic confirmed persistence, canonical hydration, provider reconstruction and SQLite close/reopen relaunch preservation passed.
- **Sprint 72 migration and ADR impact:** Migration remains V9 and ADR-041 remains the latest accepted ADR. HDFC PDF production support remains the separately bounded Sprint 73 outcome; HDFC CSV, XLSX, cards, generic HDFC layouts and cross-format suppression remain unsupported.
- **Sprint 73 implementation boundary:** `ledgerforge.statement-financial-projection.sha256.v1` deterministically covers institution, statement family, declared period, INR, derived opening balance, debit/credit counts and totals, closing balance, and every ordered event's ordinal, statement date, value date, direction, signed Money, running balance and explicit reference absence. It excludes filenames, source fingerprints, parser profile, physical ordinals, narration, display account name, customer identity and inferred NRE/NRO subtype.
- **Sprint 73 provider behavior:** SQLite and In-Memory resolve the exact account/family/period/currency group inside the provider-owned confirmed-import transaction. First-source and supporting-source graphs are atomic; supporting acceptance records `equivalent_source_recorded`, zero imported transactions, a second document/session/source-byte fingerprint/projection/member and an identifier observation without changing existing transactions, categories or authority. Exact bytes still return `exact_statement_duplicate`; projection conflict, missing pre-V10 evidence and represented byte-different format return `statement_equivalence_conflict`, `statement_equivalence_evidence_unavailable` and `equivalent_format_already_recorded` respectively.
- **Sprint 73 migration and ADR impact:** Additive Migration V10 introduces source projections, contiguous ordered projection events, equivalence groups and authoritative/supporting members with restrictive relationships and no historical backfill. ADR-042 is the latest accepted ADR. Existing V9 history remains readable; complete HDFC event overlap without durable V10 evidence fails closed rather than inventing period or equivalence truth.
- **Sprint 73 private-source acceptance:** All four retained PDF/XLS pairs matched at 62, 16, 76 and 7 ordered rows, 161 total. Direct field mismatches, printed-summary mismatches and production projection mismatches were zero. Both PDF→XLS and XLS→PDF orders retained one transaction set and two source records per pair; SQLite close/reopen and canonical hydration preserved the graph. Only aggregate counts are recorded.
- **Sprint 73 focused verification:** The final consolidated boundary passed 358 tests across 39 suites with zero failures. It covered the ordinary HDFC PDF URL route, exact PDF/XLS projection, Migration V10, SQLite/In-Memory equivalence parity, supporting-write rollback injection, source snapshots and fingerprints, identity ownership, confirmed-import atomicity, canonical hydration, provider reconstruction and result/history presentation.
- **Sprint 73 runtime verification:** One representative 7-row private pair was exercised through the signed Debug app on an isolated Persistent Debug Database at V10. PDF-first explicit confirmation created 7 authoritative transactions; the paired XLS presented and committed `equivalent_source_recorded` with 0 new transactions and no transaction-navigation action. Live Import History distinguished both outcomes, and quit/relaunch plus profile reactivation hydrated the same 7/0 aggregate counts and both durable outcomes.
- **Sprint 73 exact exclusions:** No fuzzy or narration similarity, partial overlap, same-format semantic acceptance, Axis/CBQ/card equivalence, authority switching, source replacement, provenance reassignment, historical repair/backfill, OCR, password workflow, HDFC CSV/XLSX/cards, generic PDF/spreadsheet parsing or document-byte storage is implemented.
- **Post-Sprint 57 runtime verification:** an isolated fresh Debug launch created a category, imported the approved sanitized Axis fixture, assigned that category to a trusted transaction, quit/relaunched and verified the category and assignment persisted; the task-owned process was stopped and only its isolated database set was moved to Trash
- **Previous Sprint 55 automated result:** 409 top-level tests across 49 suites, 0 failures and 0 unexpected skips in each of three consecutive exact canonical default-parallel TestPlan runs
- **Latest focused Sprint 55 results:** 41 Axis direction, fixture-oracle and confirmation-gate tests across 5 suites plus 64 adjacent event, validation, repository, atomicity and hydration tests across 6 suites, all with 0 failures and 0 unexpected skips
- **Sprint 55 acceptance closure:** the first completion attempt exposed cross-suite interference between tests mutating shared runtime singleton stores; a bounded test-only asynchronous exclusivity trait now coordinates only those global-state tests across Swift Testing suites, retains ownership across suspension and restores the shared provider generation, runtime financial/history stores, diagnostics and development activity state after success or failure
- **Sprint 55 overlap-period oracle:** retained only as a quarantined synthetic architecture regression; it verifies internal arithmetic and period parsing but cannot authorize production partial import because immutable source lineage is unavailable
- **Previous Sprint 55 build result:** Debug and explicit `-O` whole-module Release builds passed
- **Generic UI-test state:** `LedgerForgeUITests` remains intentionally disabled
- **Sprint 56 test-host isolation:** `TestPlan.xctestplan` explicitly marks the app-hosted test process with `LEDGERFORGE_TEST_HOST=1`; `LedgerForgeApp` selects intentional test memory for that exact marker before resolving any default SQLite path, while unmarked Debug and Release launches retain normal persistence bootstrap
- **Sprint 56 acceptance correction:** strict hydration now cross-checks each partial session against exactly one committed partial attempt and its document, transaction, source, imported, recognized and blocked counts before replacing any runtime store
- **Sprint 56 runtime verification:** no canonical application launch was used; acceptance uses signed app-hosted tests with isolated providers and source/presentation verification
- **Historical Axis source-truth runtime boundary:** prior automated acceptance did not launch private originals or a canonical database. Sprint 65 additionally performed the explicitly authorized signed-app acceptance against read-only originals through separate disposable profiles; no original was copied, committed or durably stored, and all task-owned profiles were removed recoverably after hydration.

GitHub establishes pushed repository state only. It does not establish local worktree cleanliness, linked worktrees, local branches, stashes, staged or unstaged changes, untracked files or unpushed commits.

---

## Current Project Qualification

LedgerForge is a private, single-user finance application that remains work in progress and is not currently used to store real financial data. Every current database is disposable development/test state until the user explicitly declares the personal-v1 adoption freeze.

This qualification reduces backup, preservation and rollout ceremony during current development. It does not weaken deterministic financial semantics, migration correctness, database switching, provider-generation safety or Release privacy boundaries.

Personal-v1 adoption remains undeclared. LedgerForge is not currently an active production financial database or a multi-user product rollout.

---

## Current Production Capability

The exact Sprint 79 `qatar-airways.salary.pdf@1` salary-actual import and the
dedicated Salary/current-month funding planner are also accepted production
capabilities under ADR-045 and Migration V16. The narrower bank-account and
card summaries below are retained historical sub-summaries; the Current
Alignment section above is authoritative where those summaries predate Sprint
79 or Sprint 78B.

### Salary actuals and current-month planning

- Salary support is limited to the exact source-proven
  `qatar-airways.salary.pdf@1` family; imported salary actuals remain distinct
  from bank transactions and use source-owned periods, kinds, ordered
  earnings/deductions and native QAR Money.
- The dedicated Salary destination owns Salary History and This Month
  planning. Checked account balances are explicit planning snapshots, and
  missing evidence makes affected outputs incomplete rather than zero.
- The editable planner uses user-entered expected salary, native QAR/INR
  commitments, plan-local dated INR-per-QAR FX, explicit transfer-fee
  semantics, upward QAR minor-unit funding rounding and derived investment
  capacity. No automatic salary-bank matching, transfer execution, global FX
  activation or investment execution is supported.

### Supported import family

Production import support is limited to the exact Axis, HDFC and CBQ
bank-account profiles documented in this section. The supported Axis CSV/PDF
families are represented by:

- the approved Axis Bank NRE CSV evidence;
- the supplied shared-layout Axis Bank NRO CSV evidence.
- the two selected unlocked/selectable-text Axis bank-account PDF families exercised in Sprint 65, with NRE/NRO labels treated as source data rather than profile identity.

Both use one production `AxisBankAccountParser`.

The selected PDFs use one account-neutral production `AxisBankAccountPDFParser`.

New supported imports emit:

```text
axis.bank-account.csv
version 2
```

PDF imports emit:

```text
axis.bank-account.pdf
version 1
```

Historical durable provenance using:

```text
axis.nre.csv
version 1
```

remains readable and is never rewritten merely to adopt the neutral forward profile.

The exact retained native-text HDFC bank-account PDF grammar is supported as
`hdfc.bank-account.pdf@1`, paired only with `hdfc.bank-account.xls@1` for exact
whole-statement equivalence.

CBQ current-account production support is limited to the exact retained
profiles:

- `cbq.current-account.xls@1`;
- `cbq.current-account.history.pdf@1`;
- `cbq.current-account.monthly.pdf@1`.

Those three CBQ profiles use ADR-043 exact reviewed source overlap and durable
per-source observations. No broader Axis PDF/XLS layout, OCR,
password-protected statement, historical Axis layout, XLSX, card, HDFC
CSV/XLSX, changed or generic HDFC/CBQ layout, American Express or other
institution support is claimed. ADR-043 is not generic cross-format
equivalence and does not extend ADR-042 beyond HDFC.

### Trusted source semantics

Supported Axis imports preserve:

- dynamic physical source-column position resolution without treating a source header label as a canonical financial role;
- the `axis.bank-account.csv@2` direction contract in which physical DR decreases balance and maps to canonical debit/outflow, while physical CR increases balance and maps to canonical credit/inflow;
- the selected Axis PDF grammar's exact `dd-MM-yyyy` statement dates, `Asia/Kolkata` date authority, source order, running-balance arithmetic, printed totals and opening/closing reconciliation;
- strict date-only financial evidence;
- Axis `Asia/Kolkata` date authority;
- document-scoped source ordinal;
- normalized source-record digest;
- parser-produced profile identity and version;

Supported CBQ current-account imports additionally preserve source-specific
posting-date authority, signed QAR Money, row-associated balances and physical
source order. History exports preserve full account identity while leaving
period, source transaction/value date and unavailable summary evidence absent.
Monthly statements preserve masked account/IBAN evidence, source Transaction
Date separately from posting date, and only printed boundary/opening/closing
evidence; brought-forward and exact promotional-page content do not become
transactions.
- durable transaction-to-source provenance;
- source-supported same-document ordering;
- source-supported running-balance interpretation.
- PDF source-byte identity under `ledgerforge.source-bytes.sha256.v1`; extracted-text identity is retained only as non-authoritative secondary evidence.

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

The active chain ends at V17. Migration V7 adds explicit partial-attempt counts, durable partial-import summaries and one typed incoming-row disposition per normalized source row for ADR-040. Additive Migration V8 adds workspace-owned categories and a separate restrictive current transaction-category assignment relationship without changing imported financial rows or provenance. Migration V9 adds versioned document-fingerprint authority and the source-byte fingerprint relationship without storing source bytes. Additive Migration V10 adds exact statement projections, ordered projection events, equivalence groups and authoritative/supporting members without backfilling existing history. Additive Migration V11 adds typed CBQ masked source-identity observations, statement-source observations and one transaction-source observation for every accepted CBQ financial row. Additive Migration V12 adds durable card instruments, strong instrument identifiers, source observations, explicit instrument relationships, statements, typed summaries and one-to-one card transaction evidence. Additive Migration V13 adds ordered card-statement sections, section-owned observations and exact card semantic projections/groups/members while deterministically migrating readable V12 single-section graphs. Additive Migration V14 transactionally generalizes the four constrained card evidence tables for exact CBQ observations, family summary components, printed-summary membership and account-level physical section membership while preserving V13 Amex rows unchanged. Additive Migration V15 adds the accepted Axis card semantic/equivalence state. Additive Migration V16 adds the accepted Qatar Airways salary-actual and current-month funding-plan state. Additive Migration V17 adds Axis bank-projection compatibility and zero-activity/card-summary schema support without changing V1–V16; schema capacity does not certify an absent genuine zero-activity source. V1–V16 remain immutable and no financial backfill is invented.

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

For ADR-043 CBQ graphs, hydration validates every statement/row observation and
selects monthly PDF, then history PDF, then history XLS for preferred
source-evidence presentation without changing the canonical transaction's
durable document or import-session provenance.

Category definitions and transaction assignments are read with the trusted financial graph, validated before publication and published as one category snapshot. Category mutations reconcile through the same canonical hydrator; runtime category state is not durable authority. A committed mutation whose hydration fails preserves durable repository truth, leaves the last complete runtime snapshot unchanged, blocks later category mutations with a distinct reconciliation-required result, and provides an explicit canonical hydration retry. Provider replacement and lifecycle transitions clear stale prior-generation category state only after replacement hydration succeeds.

### Durable categories and manual classification

Sprint 57 provides user-created workspace categories with stable identifiers, deterministic normalized-name uniqueness and archival state.

Settings supports create, rename, archive, restore and deletion only when unused. Transaction detail supports one manual category assignment, change or clear for a persisted trusted transaction. Archived categories retain existing assignments but cannot receive new ones.

The assignment is stored in a separate relationship. Changing it does not update transaction amounts, dates, balances, identifiers, normalized rows, import sessions, provenance or parser output. SQLite and In-Memory providers enforce equivalent behavior, and deletion remains restrictive while a category is assigned.

Automatic categorization, rules, suggestions, bulk assignment, merge, delete-with-replacement, hierarchy, tags, splits, filters, budgeting, analytics and reports remain future work.

### Financial identity

Parser-owned verified identity resolution supports the approved strong-identity
bank-account paths. ADR-043 adds one typed CBQ-only partial-identity review
without weakening the generic resolver.

Distinct parser-produced full institution account identifiers retain distinct durable accounts. Shared customer context, profile identity, filenames and neutral presentation labels are not account-identity authority.

The supported workflow provides:

- verified existing-account resolution;
- explicit eligible existing-account choice for bounded no-match cases;
- explicit new-account creation;
- transaction-time identifier ownership enforcement;
- durable accepted-import identifier observations.

Identifier unlinking, reassignment, incorrect-link recovery, contradictory-ownership repair and historical backfill remain separately gated.

CBQ masked account/IBAN observations are source evidence, not owned full
identifiers. Exact positional compatibility can resolve a unique current
account, narrow explicit choice to compatible accounts or permit a new
masked-only account. A later compatible full history identifier attaches
atomically through existing ownership rules; ambiguity, stale review or a
conflicting full identifier rejects with zero accepted financial writes.

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

Axis UPI event overlap is currently whole-statement blocked. Ordinary no-overlap statements remain full imports and exact-content duplicates remain ADR-030 outcomes. The former ADR-040 mixed-overlap exception is suspended because its synthetic three-shared/one-later fixture has no immutable source lineage; both providers return unsupported evidence without accepted residue for that shape.

Migration V7, immutable reviewed plans, SQLite/In-Memory commit paths, durable partial summaries and dispositions, strict hydration and bounded UI presentation remain capable of reading and validating historical repository state. They do not authorize a new partial import until immutable source evidence proves a bounded family again. Interleaved overlap, unsupported event families, arbitrary omission, fuzzy matching and historical repair remain unavailable.

Unsupported event families remain unevaluated, including:

- IMPS;
- NEFT;
- e-commerce and card events;
- refunds;
- reversals;
- unstructured references.

Separately, the exact three-profile CBQ current-account family supports
reviewed all-new, mixed and fully represented source overlap under ADR-043. It
uses exact account resolution plus posting date, signed QAR amount and running
balance, with an exact structured-reference digest only when a tuple collision
needs disambiguation. Every accepted source row remains represented; fuzzy
matching and generic partial import remain unavailable.

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

Typed confirmed-import recovery distinguishes wholly fresh preparation for authorized zero-commit outcomes, canonical reconciliation for committed hydration failure, and reconciliation followed by wholly fresh preparation when confirmation was blocked by an earlier reconciliation requirement. Review-required, unknown, malformed, hostile and unavailable outcomes expose no mutation action.

No rollback, compensation, resumable import job, batch queue, retry confirmation, automatic confirmation or cancellation after confirmed persistence exists.

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

`Completed Imports` counts unique hydrated durable sessions represented by committed `successful_import` or `partial_import_committed` attempts with both an import session and a document. Partial sessions are also counted separately as a subset. Duplicate, repeated, failed, rejected and cancelled attempts do not increment either count. Non-durable or unavailable persistence displays `Unavailable`.

### Development database lifecycle

Sprint 45 Phase A provides a DEBUG-only `DevelopmentDatabaseLifecycleCoordinator` and activity gate.

DBP-01 expands that lifecycle into four explicit DEBUG-only profiles:

- Current Database retains the canonical Debug identity and is selected on ordinary launch;
- Persistent Debug Database uses a separate stable application-owned identity;
- Temporary Session uses a lifecycle-owned process-temporary identity;
- Migration Sandbox uses a lifecycle-owned temporary identity constructed from a registered historical migration prefix.

Profile activation is explicit. Candidate construction, migration and staged canonical hydration finish before one observer-atomic publication of provider generation, runtime stores, active profile and schema metadata. Active lifecycle work blocks switching, and repositories or confirmed-import work captured from a stale generation reject.

Developer Mode is process-local and begins off on every launch. Remembered selection is passive until explicit activation, and disabling Developer Mode commits Current Database before the toggle becomes off. Non-current profiles show a bounded app-wide warning, and the first protected mutation in each non-current provider generation requires process-local, generation-scoped acknowledgement. Switching or reset clears that acknowledgement.

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

Current Database cannot be reset through profile controls. Non-current reset and recreation remain lifecycle-owned, and arbitrary or symlink-escaping paths are rejected.

Lifecycle operations are excluded while any of the following is active:

- import preparation;
- prepared confirmation;
- confirmed persistence;
- hydration or reload;
- repository writes;
- another lifecycle operation.

All database-profile selection, warning, reset, acknowledgement and approved-fixture machinery is compile-time absent from optimized Release builds. DBP-01 added no migration and changed no financial parser or durable financial semantics.

### Repository metadata hygiene

Commit `7ee20a909038d1088f830a6ea588311625f415e5` removed tracked user-specific Xcode state, including:

- Find Navigator scope state;
- breakpoint-list state;
- scheme-management user state.

Shared Xcode configuration remains distinct from personal IDE state.

---

## Current Verified Limitations

The limitation summaries below retain older domain-specific wording for
traceability. The Current Alignment and Current Production Capability
sections above supersede any pre-Sprint-79 statement about the accepted Axis
card family, Migration V16, or the exact Qatar Airways salary/planning slice.

### Production format and institution limits

- Production parser support is limited to the exact documented Axis, HDFC and CBQ bank-account profiles, the exact Amex, CBQ and Axis credit-card profiles, and the exact Qatar Airways salary profile; no generic institution, payroll or layout claim exists.
- General Axis NRO coverage and additional Axis layouts remain unsupported.
- Other Axis PDF layouts, OCR, arbitrary password-protected PDFs and generic PDF statement support remain unsupported. Encrypted production support is limited to exact `amex.credit-card.pdf@1`, `cbq.credit-card.pdf@1` and the accepted encrypted Axis credit-card PDF families.
- Generic XLSX/OOXML, TXT and OCR are not production-supported. The exact `axis.credit-card.xlsx@1` profile is accepted separately; XLS remains supported only for the exact documented Axis, HDFC and CBQ profiles.
- HDFC and CBQ bank-account support is limited to their exact documented profiles. Card support is limited separately to exact `amex.credit-card.pdf@1`, `cbq.credit-card.pdf@1`, `axis.credit-card.pdf@1` and `axis.credit-card.xlsx@1`; no other American Express/CBQ/Axis layout or issuer card family is supported.
- Production secure password entry and institution-scoped Keychain reuse exist for exact encrypted `amex.credit-card.pdf@1`, `cbq.credit-card.pdf@1` and the accepted Axis credit-card PDF families; this does not establish arbitrary encrypted-PDF or generic credential-profile support.
- QAR production import exists only for the exact three-profile CBQ current-account family under ADR-043, the exact Amex/CBQ card profiles under ADR-044, and the exact Qatar Airways salary profile under ADR-045.

### Card limits

ADR-034's document-scoped evidence boundary is implemented and refined by
ADR-044 for the shared card foundation and exact
`amex.credit-card.pdf@1`, `cbq.credit-card.pdf@1`, `axis.credit-card.pdf@1`
and `axis.credit-card.xlsx@1` profiles. Durable liability accounts, card instruments,
source observations, explicit relationships, statement sections and summaries,
transaction evidence, Migration V14/V15, SQLite/In-Memory parity, hydration and
bounded presentation are operational for those profiles.

The following remain unimplemented: HDFC card parsers; additional Amex, CBQ or
Axis layouts; generic card profiles or masked identity; rewards persistence or
valuation; payment allocation; bank-card payment matching; refund/reversal
matching; installments/loans; calculated FX; invented fees, markup or tax;
manual merge/split; historical repair/backfill; OCR and arbitrary encrypted-PDF workflows.
Fixture integration, statement classification or schema capacity does not
establish support beyond the exact accepted profile.

### Currency limits

ADR-033, Sprint 44 and Sprint 76A provide:

- the versioned 155-code active ordinary-currency catalog v2;
- canonical catalog-scale persistence;
- exact decimal/minor/currency hydration;
- SQLite/In-Memory parity;
- grouped native-currency presentation.

Sprint 44 itself introduced no migration. The repository later advanced to V6 through other work.

The following remain unimplemented:

- global exchange-rate storage beyond the Sprint 79 plan-local, user-entered
  dated FX quote;
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

Axis bank-account imports accepted with `axis.bank-account.csv@1` from Sprint 55 commit `9598c6de6a701d14b0d4afb37d5adb27e9fc82e0` through the parent of the current P0 restoration commit may contain reversed canonical direction, signed `Money` and direction-dependent UPI subtype. Earlier alternating parser revisions also require provenance-led audit rather than inference. Repository evidence cannot prove which historical databases contain affected rows, so detection and any repair remain a separately gated `FW-P0-08` family. This restoration performs no historical mutation.

### Test and runtime limits

- Generic UI tests remain intentionally disabled.
- Supported UI behavior relies on the documented automated and manual acceptance boundaries.
- Unmanaged manual launches can attach to a stale DerivedData build when multiple LedgerForge processes exist.
- `./script/build_and_run.sh` is the repository-owned exact-singleton local build/run entry point; its contract resolves one fresh Debug bundle and process before UI attachment.
- `./script/validate.sh` is the repository-owned local build/test entry point. CI, generic UI smoke automation, commit-status protection and distribution/notarization remain open maintenance work.

---

## Historical Fixture / Mechanics Evidence — Not Parser Acceptance Authority

**Current alignment — 2026-09-08:** the material below is retained only to explain historical test mechanics and earlier acceptance campaigns. Under ADR-046 and the all-stages user rule, fabricated financial-statement artifacts may not execute even as mechanics. Those artifacts have been retired from the active source/test tree. Only authentic corpus statements may exercise statement-dependent behavior; source-independent mechanics use nonfinancial values/files.

At the time of this historical campaign, direction evidence consisted of NRO clean-room transaction rows and a privacy-safe, non-reversible NRE semantic derivative. Independent exact-decimal oracles derived direction from physical column occupancy plus running-balance deltas and an independently supplied opening balance. They verified physical DR as debit, physical CR as credit, exact amount/delta agreement, source order, totals and complete reconciliation without consulting production parser output. This describes the former method, not current executable source authority.

The original private statements remain isolated, read-only evidence in their approved source location and are never included in published repository artifacts. The then-available two NRE and two NRO private CSV families independently provided 94 and 35 observable row-to-row balance deltas respectively, all conventional. The legacy 81-row/31-row NRE fixtures and synthetic partial-overlap pair lacked immutable transformation lineage and were not source truth; they are now retired and may not execute as mechanics or financial-source inputs.

### Axis bank-account evidence

Approved evidence includes:

- a historical privacy-safe source-derived Axis NRE CSV mechanics artifact, no longer parser regression authority under ADR-046;
- legacy Axis NRE CSV/PDF structural evidence quarantined from financial-truth acceptance pending source lineage;
- verified clean-room Axis NRO CSV transaction rows;
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

Production supports the exact retained HDFC NRE/NRO OLE2/BIFF8 grammar as
`hdfc.bank-account.xls@1` and the exact paired native selectable-text grammar as
`hdfc.bank-account.pdf@1`. The four private-original pairs were independently
verified locally at 62, 16, 76 and 7 ordered rows, 161 total, with zero direct
row-field, printed-summary or production-projection mismatches. Both import
orders produce one financial event set: the first format remains authoritative
for transactions and provenance and the later exact-equivalent format is
durable supporting evidence with zero transactions. The shared semantics do
not infer NRE/NRO subtype from filenames, transaction similarity, customer
identity or the neutral printed product label; the account families remain
distinct through their verified account-number identifiers. HDFC CSV, XLSX,
cards, OCR, locked/password-protected PDFs and other HDFC layouts remain
unsupported.

### CBQ bank-account evidence

Historically, invented self-contained mechanics fixtures covered the history PDF,
monthly PDF, byte-distinct monthly variant and legacy-XLS profiles. Those artifacts
may still exercise isolated mechanics, but ADR-046 prohibits using them as
reader/parser/source regression or acceptance evidence. Current reliability must
come from the complete authentic CBQ corpus through ordinary production.

Private acceptance independently established a 60-event history set with zero
PDF/XLS ordered or set mismatches and two monthly subsets of 9 and 8 events.
Four import orders in each provider ended with one account, 60 canonical
transactions, four durable source attempts and 60 preferred-source mappings;
SQLite reopen preserved that graph. No private source content or identifying
metadata is recorded.

Production bank-account support covers only `cbq.current-account.xls@1`,
`cbq.current-account.history.pdf@1` and
`cbq.current-account.monthly.pdf@1`. Exact CBQ card support is a separate
`cbq.credit-card.pdf@1` family; generic/changed layouts, XLSX, OCR, image-only
PDFs, generic masked identity and generic overlap remain unsupported.

### CBQ card evidence

Clean-room CBQ credit-card PDF evidence remains integrated for four fictional periods, while exact production authority comes from eight approved encrypted originals across:

- v1 legacy layout;
- v2 equation-style layout.

The evidence preserves:

- one fictional customer and account;
- two neutral companion-instrument sections with no primary/supplementary inference;
- exact transaction assignment;
- posted QAR distinct from original merchant amount and currency;
- explicit source-observed fees;
- no invented FX rates, markup, taxes or absent aggregates.

Production `cbq.credit-card.pdf@1` selects internal v1/v2 layouts exactly,
preserves financial scope independently from physical section membership, uses
family-specific reconciliation and typed weak observations, and persists through
the shared ADR-044 card domain. Other CBQ card layouts remain unsupported.

### American Express card evidence

Clean-room American Express card PDF evidence is integrated as a fictional
five-page native-text fixture plus an encrypted semantic twin. The accepted
private source boundary contains eight chronological statements and two
byte-distinct unlocked equivalents; only aggregate acceptance facts are
recorded.

The evidence preserves:

- one fictional liability account and three ordered instrument sections,
  including repeated holder text and a different holder;
- account-level payments distinct from instrument transactions;
- posted QAR separate from original merchant amount and currency;
- signed per-section totals, zero-/two-/three-decimal currency mechanics,
  nonmonotonic Posting Dates and multiline travel relationships;
- exact rewards, legal, pagination and continuation-page exclusion boundaries;
- no invented FX rates, fees, markup or tax.

Exact `amex.credit-card.pdf@1` production parsing, durable multi-instrument card
semantics, exact semantic-source grouping and encrypted import through the
institution-scoped Keychain flow are supported. Other Amex layouts, generic
card equivalence, OCR and arbitrary encrypted PDFs remain unsupported.

---

## Recent Verified Changes

### Sprint 68B, DBP-01 Maintenance Correction and Sprint 69 — Local Validation Closure

**Ref and evidence classification**

The repository implementation closure preceding this documentation-only update is
`main@6873d6c50e63042819a41b859254ff149a8bda3d`. The scripts, Codex Run action,
test changes and documentation present at that ref are repository-verifiable.
The acceptance execution results below are reported local evidence from the
accepted closure; this documentation-only update did not rerun builds or tests.

**Repository-verified scope**

- Sprint 68B is a test-only bounded persistence-error-contract correction. It
  retains the generic public wrapper message while preserving typed identity
  outcomes and durable-attempt authority.
- The DBP-01 maintenance correction gives successful prepared imports explicit
  test lifecycle ownership and uses target-wide isolation for shared
  lifecycle-gate coverage. It changes no production lifecycle behaviour,
  migration or ADR.
- Sprint 69 provides `./script/validate.sh` for the canonical local build/test
  interface and `./script/build_and_run.sh` for exact-singleton local Debug
  Run/stop verification. The Codex Run action invokes
  `./script/build_and_run.sh --verify`.

**Reported local acceptance evidence**

- The two modified containing suites passed 36/36 tests, Account Metadata
  passed 4/4, and each fresh interference combination passed three consecutive
  times: Account Metadata plus Axis Shared (11/11 each) and Account Metadata
  plus the unconfirmed-preparation test (5/5 each). All reported zero failures
  and zero unexpected skips.
- Fresh Debug and Release builds passed. The canonical complete TestPlan
  recorded 628/628 tests passed with zero failures and zero skips.
- The reported isolated Run built a fresh Debug bundle, verified one PID and
  executable path against that bundle, used the intentional non-durable
  `LEDGERFORGE_RUN_HOST=1` marker, found no open SQLite, WAL or SHM database
  files, then stopped with zero exact-name LedgerForge processes and no
  task-owned `xcodebuild` process.

**Open boundary**

CI, generic UI smoke automation, commit-status protection, enabling or
replacing the disabled UI-test target, and distribution/notarization remain
open. Migration V9 and ADR-041 remain unchanged.

### Sprint 65 — Shared Axis Bank-Account PDF Production Path

**Ref**

This state update is the durable record for the Sprint 65 acceptance commit; the exact Git ref is authoritative in history and intentionally is not embedded here.

#### Outcome

Sprint 65 promotes one exact account-neutral Axis bank-account PDF grammar through the existing ordinary URL-driven import path. It does not establish generic Axis PDF, OCR, password, spreadsheet or cross-format-equivalence support.

#### Verified production behavior

- The existing security-scoped immutable `SourceContentSnapshot` is shared by PDF extraction, source-byte fingerprinting and confirmation integrity checks.
- The ordinary importer accepts PDF alongside CSV, dispatches PDF through the existing reader and exact Axis normalizer, then uses the shared detector, classifier, parser selector, validation, review, provider-owned confirmation and canonical hydration path.
- The PDF profile is `axis.bank-account.pdf@1`; the existing CSV profile remains `axis.bank-account.csv@2`. NRE/NRO labels do not select a profile or durable identity authority.
- PDF persistence uses `application/pdf`, makes `ledgerforge.source-bytes.sha256.v1` the single duplicate authority, retains `ledgerforge.raw-text.sha256.v1` only as a secondary fingerprint and records source size from the exact source bytes. CSV remains `text/csv` with raw-text duplicate authority and source bytes secondary.
- The coordinator and mapper fail closed for missing, multiple, unapproved or format-mismatched authorities. No PDF-only repository, provider, schema or migration path was added, and no cross-format duplicate suppression was introduced.
- The normalizer preserves page and row order, multiline particulars, printed references, branch evidence, declared period, opening/closing balances, printed totals and exact balance arithmetic; unsupported or contradictory evidence rejects before accepted persistence.

#### Source and fixture authority

**Current alignment — 2026-09-08:** this subsection records Sprint 65 historical evidence. The formerly committed sanitized PDFs have been removed from the active source/test tree. Historical recovery is not permission to execute them at any stage, including mechanics. Complete authentic originals are the current authority under ADR-046.

- The two committed sanitized NRO PDFs were regenerated clean-room from the supplied read-only originals. Their independent expected JSON remained byte-identical; PDFKit, geometry, pagination, selectable-text, unlocked, privacy and `qpdf --check` gates passed; all four rendered pages were visually inspected.
- The original PDFs remain historical source evidence for that Sprint 65 campaign. The regenerated sanitized PDFs were used for historical mechanics/privacy checks but are now retired from the active tree and may not execute; they never supplied original-source identity.
- Original NRO PDF persistence matched the independent row-level baselines: 16 and 20 ordered rows, with exact dates, debit/credit side, amount magnitudes, running balances, totals and closing balances. No production parser output was used to create either expected baseline.

#### Persistence authority matrix

| Source | Duplicate authority | Secondary fingerprint | Persisted media |
| --- | --- | --- | --- |
| CSV | `ledgerforge.raw-text.sha256.v1` | `ledgerforge.source-bytes.sha256.v1` | `text/csv` |
| PDF | `ledgerforge.source-bytes.sha256.v1` | `ledgerforge.raw-text.sha256.v1` | `application/pdf` |
| XLS | `ledgerforge.source-bytes.sha256.v1` | deterministic reader text projection | `application/vnd.ms-excel` |

#### Acceptance evidence

- Focused acceptance passed 381 tests across 43 suites; the complete TestPlan passed 607 tests across 73 suites. Both had zero failures, skips and expected failures; changed-file warnings were zero and analyzer diagnostics were zero. Nine remaining warnings were pre-existing Swift 6 transition warnings.
- Fresh signed Debug and optimized whole-module `-O` arm64 Release builds, Debug analysis and Release containment passed. Release products contained no PDFs, CSVs, fixtures, private originals, databases or copied source material.
- Four original PDF/CSV pairs were each exercised through separate fresh signed sandboxed app profiles, ordinary file-picker selection, explicit confirmation, quit/relaunch and hydration. Redacted pair outcomes are recorded above; matching projections were treated as financial equivalence evidence only, never exact-content identity.
- Task-owned namespaces, result bundles, render evidence and build products were moved recoverably to Trash after acceptance. The private originals remain read-only and unchanged. No private source value, path, filename, database, screenshot or raw diagnostic was published in documentation, result bundles or products.

#### Scope

Sprint 65 changed only the approved production, test, fixture/manifest and state-document paths: `ContentView.swift`, `Services/ImportEngine.swift`, `Services/ImportPersistenceMapper.swift`, `Services/ImportPersistenceCoordinator.swift`, `Parsers/AxisBankAccountParser.swift`, `Parsers/StatementParserRegistry.swift`, `Normalizers/AxisBankAccountPDFNormalizer.swift`, `Parsers/AxisBankAccountPDFParser.swift`, `Parsers/AxisBankAccountSourceEvidence.swift`, `LedgerForge.xcodeproj/project.pbxproj`, the focused `LedgerForgeTests` files, the two regenerated sanitized PDF fixtures and their manifests, `PROJECT_STATE.md` and `FUTURE_WORK.MD`. No ADR, DTO, repository protocol, schema or migration changed; V9 remains current.

### Sprint 66 — Typed Confirmed-Import Recovery and Truthful Validation Guidance

**Ref**

The single Sprint 66 completion commit containing this state update. Its exact SHA is Git-authoritative and recorded in the closure report.

#### Outcome

Sprint 66 implemented typed confirmed-persistence recovery and truthful validation guidance.

#### Verified production behavior

- Recovery eligibility is a closed typed contract. Localized error strings, filenames, paths and unrestricted errors are not recovery authority; unknown, malformed or hostile errors fail closed to unavailable.
- Eligible zero-commit outcomes may offer only wholly fresh preparation. Fresh preparation re-enters the ordinary retained-URL path, reacquires the source bytes, creates a new immutable snapshot and source-byte fingerprint evidence, and re-runs validation, exact-duplicate, identity, account-choice and provider-generation checks.
- Fresh preparation never reuses a consumed `PreparedImport`, reviewed partial plan, account choice or source snapshot, and never confirms automatically.
- Committed persistence followed by hydration failure offers canonical reconciliation only. Reconciliation refreshes the view without reimporting the statement or duplicating accepted history.
- A pre-existing reconciliation block is distinct from current committed persistence and explicitly records that the current attempt did not save a new import.
- Reconciliation-then-preparation starts wholly fresh preparation only after reconciliation succeeds. A failed reconciliation remains blocked, starts no preparation and does not retry recursively.
- Review-required and unavailable states expose no mutation action. A missing retained source URL suppresses Prepare Again even when the typed route otherwise permits fresh preparation.
- DBP-01 acknowledgement remains required before source acquisition in a non-current Debug profile.
- Process-local action ownership prevents duplicate dispatch, simultaneous preparation and reconciliation, and stale completion publication after a newer action begins.
- Exact-duplicate presentation remains “Previously Imported,” not persistence failure.

#### Persistence and financial boundary

- No schema or migration changed, and no repository or provider API changed.
- No rollback, compensation, resumable job, persisted job, batch queue, cancellation after committed persistence or generalized retry engine was introduced.
- Provider-owned atomic confirmation remains authoritative, and durable commit remains distinct from canonical hydration.
- Rejected zero-commit outcomes leave zero accepted financial residue. A committed hydration failure preserves the accepted commit.
- Reconciliation creates no duplicate account, transaction, session, document, fingerprint, identifier or observation.
- Historical durable guidance remains readable and was not rewritten.

#### Acceptance correction

The first canonical TestPlan run exposed one stale legacy duplicate-presentation test. The test-only correction supplied the typed exact-duplicate route to that previously imported regression case; no production code changed for the correction. The corrected stable implementation state then received the final authoritative acceptance run. This correction occurred before Sprint 66 acceptance and is part of Sprint 66, not Sprint 66A.

#### Acceptance evidence

- The focused four-suite run passed 49 logical tests across 49 executions, with zero parameter runs, failures, skips or expected failures.
- The corrected canonical TestPlan passed 562 logical tests across 607 execution instances and 68 suites, including 55 dynamic parameter runs across 10 parameterized tests, with zero failures, skips or expected failures.
- One fresh Debug build, one optimized whole-module `-O` arm64 Release build and Debug static analysis passed. Only pre-existing Swift 6 transition warnings in unrelated tests and the AppIntents metadata skip remained; no changed file produced a warning.
- Disposable runtime Scenario A verified a zero-commit contention outcome, ordinary-path Prepare Again, new prepared-import and snapshot identities, recomputed source-byte evidence, cleared account choice, explicit confirmation gating and single-dispatch behavior under double activation.
- Disposable runtime Scenario B verified that a committed hydration failure presented saved truth, offered reconciliation only and reconciled without a second preparation or persistence commit.
- Disposable runtime Scenario C verified that a pre-existing reconciliation block saved no current import, failed reconciliation began no preparation or loop, and successful reconciliation then created a wholly fresh preview requiring a new account choice and explicit confirmation.
- Disposable runtime Scenario D verified unavailable, exact-duplicate and missing-retained-URL outcomes with no unauthorized recovery mutation action. The exact duplicate left accepted financial counts unchanged and added only its bounded rejected attempt.
- Disposable runtime Scenario E verified the DBP-01 non-current-profile acknowledgement before source acquisition.
- Runtime SQLite evidence remained confined to the task-owned disposable root, the canonical Current Database was not opened or altered, and corrected automated coverage verified SQLite/In-Memory outcome parity and rejected-path zero accepted residue.
- Build acceptance and Release containment used the normal signed sandboxed products. The isolated interactive runtime walkthrough used a re-signed unsandboxed copy of the passed Debug build solely because sandboxed launch did not honor the task-private home. Executable code was unchanged, but the runtime entitlement environment differed; the walkthrough therefore verifies the accepted code paths under disposable isolation rather than production sandbox-entitlement behavior.
- Release inspection found no CSV, PDF, SQLite, database or fixture payload and no Debug acknowledgement machinery or private recovery material. Task-owned products were moved recoverably to Trash, no generated residue remained in the repository and no LedgerForge or `xcodebuild` process remained.

#### Scope

Sprint 66 changed exactly these implementation and test paths:

- `Services/ImportEngine.swift`
- `Services/ImportPersistenceCoordinator.swift`
- `ContentView.swift`
- `LedgerForgeTests/ImportLifecycleTests.swift`
- `LedgerForgeTests/ConfirmedImportHydrationTests.swift`
- `LedgerForgeTests/PersistenceAvailabilityTests.swift`
- `LedgerForgeTests/SettingsPresentationTests.swift`
- `LedgerForgeTests/ConfirmationGatedImportWorkflowTests.swift`

#### Exclusions

Sprint 66 did not implement retry confirmation, resume of a consumed preparation, rollback or compensation, persisted recovery jobs, batch importing, automatic confirmation, cancellation after committed persistence, generalized retry infrastructure, schema or migration changes, parser or import-format support, production PDF support, or Sprint 65.

### Sprint 67A — Authoritative Source-Document Binding

**Ref**

The single Sprint 67A corrective acceptance commit containing this state update. Its exact SHA is Git-authoritative and recorded in the closure report.

#### Outcome

Sprint 67A corrected Sprint 67's source-document presentation authority without changing the existing detail layout, financial values, schema or accepted architecture.

#### Verified production behavior

- `ImportSessionRepository.importedDocument(id:)` is the smallest read-only durable-document boundary. SQLite and In-Memory providers return one exact `ImportedDocumentDTO` by durable ID; a missing ID returns nil.
- `RepositoryStoreHydrator.stageHydration` deduplicates trusted transaction document references, reads each referenced document once and exposes a trimmed immutable runtime filename only when document ID, active workspace, transaction import-session ID and nonblank filename all agree.
- Nil references, missing rows, session mismatches, workspace mismatches and blank filenames leave the transaction readable and the source document neutral. A repository read error fails staged hydration before publication, preserving the previously published complete snapshot.
- `TransactionListViewModel` presents only the validated runtime document filename. Import time and validation still require one exact matching hydrated import session; `ImportSessionRecordDTO.userVisibleName` is never substituted as source-document authority.
- No repository lookup occurs in the ViewModel or SwiftUI view. Existing category, search, credit/debit toggle and reconciliation behavior is unchanged.

#### Acceptance evidence and boundary

- One fresh isolated Debug build passed. Focused runs passed 80 tests across 4 suites with zero failures, including provider parity, malformed and legacy document graphs, atomic read failure, privacy-safe presentation and SQLite close/reopen reconstruction with an intentionally different import-session label.
- The single canonical TestPlan run passed 622 tests across 73 suites with zero failures.
- The SwiftUI structure was unchanged, automated presentation evidence proved the displayed value and SQLite reconstruction proved the durable relationship, so the approved manual-runtime exemption applied.
- No migration or ADR was added; V9 and ADR-041 remain current. No source-document opening, browsing, library, source-byte retention, backfill or repair was added.

### Sprint 67 — Transaction Provenance and Clearer Detail

**Ref**

The single Sprint 67 acceptance commit containing this state update. Its exact SHA is Git-authoritative and recorded in the closure report.

#### Outcome

Sprint 67 added one repository-backed transaction-detail experience without changing financial semantics, persistence ownership or schema.

#### Verified production behavior

- `TransactionDTO.documentId` now survives ordinary hydration, forced hydration, provider reconstruction and relaunch as immutable runtime `repositoryDocumentId`; `RepositoryStoreHydrator` remains the sole persistence-to-runtime boundary.
- `TransactionListViewModel` owns one typed projection derived only from the hydrated transaction, its exact matching hydrated import session, Money and trusted statement-date authorities. Sprint 67A corrected the source-document field to use validated durable imported-document state rather than the session label.
- Account presentation requires the durable account relationship. After Sprint 67A, source-document presentation requires the exact durable imported-document relationship and a nonblank validated filename. Import time and validation fail closed independently when their matching session is malformed, unknown, missing or conflicting.
- The detail panel retains signed native-currency Money and manual category behavior while presenting bounded Transaction, Account and category, Import provenance and Validation sections. “Direction” and “Institution” replace developer-oriented or ambiguous terminology.
- Repository, normalized-document and normalized-row IDs, digests, raw parser-profile IDs, paths and source fragments are absent from visible and accessibility text. Historical or synthetic transactions without durable provenance remain readable and present neutral Unavailable states.

#### Authority and compatibility boundary

- Displayed amount and currency come from hydrated `Money`; direction comes from its hydrated debit/credit role; date and role come from `StatementDate` and `FinancialDateRole`; balance comes from hydrated running-balance Money.
- Account name and institution come from the hydrated transaction only when `repositoryAccountId` exists. Sprint 67A makes `ImportedDocumentDTO.filename` the sole source-document name authority; import time and validation continue to come from the exact hydrated `RepositoryImportSession`.
- No migration or ADR was added. V9 and ADR-041 remain current. No backfill, repair or durable source-byte presentation was performed.

#### Acceptance evidence

- One fresh Debug build passed.
- The final focused run passed 36 tests across 3 suites with zero failures. It covered document-ID mapping, forced hydration, legacy nil compatibility, atomic failure preservation, complete and unavailable detail projections, conflicting and unrelated sessions, malformed timestamps, unknown validation, internal-text exclusion, search/toggles, confirmed-import recovery and SQLite relaunch reconstruction.
- The single final canonical TestPlan run passed 616 tests across 73 suites with zero failures.
- Isolated runtime acceptance imported the approved sanitized Axis NRE fixture into one fresh namespaced SQLite database, verified the complete selected-transaction detail and accessibility truth, quit and relaunched, then verified the same hydrated provenance. Bounded SQLite inspection found 1 account, 4 transactions, 1 document and 1 session; all 4 transactions retained nonnull account, document and session relationships.
- The task-owned app process was stopped. The namespace, DerivedData and logs were moved recoverably to Trash. No private source, user database, generated result bundle or repository identifier was published in presentation.

#### Scope and exclusions

Sprint 67 changed the runtime transaction model, canonical hydrator, transaction-list presentation authority and view, focused hydration/presentation/relaunch tests, and this bounded state/queue reconciliation. It did not add source-document reopening, raw source retention, a document library, editable imported values, notes, tags, splits, provenance mutation, account relationship mutation, automatic categorization, new filters, analytics, dashboard work, diagnostics persistence, backup/restore, a migration or an ADR.

### DBP-01 — Developer Database Profiles (Debug Development Tooling)

**Ref**

`2d86f91dc46b9e88bcdfea65c88ddf671968b388`

**Verified scope**

DBP-01 is an accepted DEBUG-only developer-tooling and development-database lifecycle implementation. It provides Current Database, Persistent Debug Database, Temporary Session and Migration Sandbox with explicit lifecycle-owned activation; observer-atomic publication; lifecycle-activity blocking and stale-generation rejection; process-local Developer Mode that starts off on launch; an app-wide non-current warning; first-protected-action acknowledgement per non-current provider generation; and lifecycle-owned non-current reset and recreation. Current Database cannot be reset through profile controls.

All database-profile, warning, reset and acknowledgement machinery is absent from optimized Release. DBP-01 added no migration, changed no financial parser or durable financial semantics, established no production database-profile capability and did not declare personal-v1 adoption. Every current database remains disposable development/test state.

Integrated acceptance verified the complete TestPlan with 547 logical tests, 592 execution instances, 68 suites and 55 parameter runs, with zero failures, skips or expected failures. A fresh Debug build, Debug static analysis and isolated disposable runtime verification passed. No private financial source or personal database was used.

The final bounded Release-containment acceptance separately inspected seven authorized correction paths, passed 44 logical focused tests across 46 executions, passed an optimized whole-module `-O` arm64 Release build and passed direct binary `nm`, `strings` and bundled-resource inspection. No acknowledgement gate, Debug database-profile control, profile label, filename, namespace, sandbox control or fixture payload remained in Release. The complete TestPlan, static analysis and runtime walkthrough were not redundantly rerun after that final compile-boundary correction.

### Sprint 57 — Durable Categories and Manual Transaction Classification

**Ref**

The single Sprint 57 completion commit containing this state update.

**Verified scope**

Sprint 57 adds additive Migration V8 with workspace-owned category definitions and one separate optional category relationship for each trusted imported transaction. Categories have stable identifiers, validated names and archival state; Uncategorized is represented by no assignment.

SQLite and In-Memory repositories provide equivalent create, rename, archive, restore, delete-unused, assign, change and clear behavior. Deletion fails while a category is assigned. Archived categories preserve existing assignments but reject new ones. Provider-generation protection and the development repository-write lease cover persistence and forced canonical reconciliation.

`RepositoryStoreHydrator` reads categories and assignments with the trusted graph, rejects invalid names, duplicates, cross-workspace relationships and non-trusted transaction assignments before publication, then replaces one observer-consistent category snapshot. Provider reconstruction, SQLite close/reopen and V7-to-V8 upgrade verification preserve category metadata and leave existing imported financial/history truth unchanged.

Settings provides bounded category management. Transaction rows display the current category, and transaction detail provides assign, change and clear. The first category may be created before an import by establishing the default Personal workspace through the existing workspace repository.

An isolated namespaced Debug launch verified the empty Settings presentation, first-category creation and category survival after a full quit/relaunch. The task-owned process was terminated and the isolated database set was moved to Trash without opening or changing the protected canonical Debug database.

The post-Sprint 57 reconciliation closure adds no migration and preserves the immutable imported financial transaction boundary. Category reconciliation failure injection, blocked mutation zero-write behavior, retry, provider-generation replacement and target-wide category-state cleanup are covered by focused tests.

The closure also verified the normal isolated runtime path: Verified SQLite startup, category creation in Settings, sanitized statement import, transaction assignment, quit/relaunch hydration and persisted assignment presentation. No private source or protected canonical database was opened or changed.

No parser, reader, normalized-row, import-session, transaction financial value, balance, identifier or provenance behavior changed. The dated ADR-036 implementation amendment records the reconciliation closure; no migration was added.

### Sprint 57A — Category Reconciliation Closure

**Ref**

`251a547cb44712a789a9ad7b23a4eabca742900b`

**Verified scope**

Sprint 57A completed category reconciliation closure without a migration. Failure injection, blocked-mutation zero-write behavior, retry, provider-generation replacement and target-wide category-state cleanup preserve the immutable imported financial transaction boundary. The completion state is recorded as complete; no historical financial repair was performed.

### Sprint 58 — Deterministic Import Verification Workspace

**Ref**

`4547083d4d81edc9b6bcd98c3a8e77ee1538e71a`

**Verified scope**

Sprint 58 added a DEBUG-only approved-fixture verification workspace that enters the ordinary URL-driven preparation and confirmation path. Release containment removes the fixture resources and excludes the workspace from Release behavior. The isolated exact-duplicate runtime check preserved accepted transactions, sessions, documents, fingerprints, account state, balance and hydrated presentation, adding only one durable rejected duplicate attempt. Its later bounded build-system correction is recorded as Sprint 58A below.

### Sprint 58A — Debug Fixture Run-Script Sandbox Repair

**Verified scope**

Sprint 58A repaired the `Copy DEBUG approved fixtures` Run Script sandbox contract. The phase now validates and operates only on its two exact declared inputs and two exact declared outputs; directory-level recursive deletion was removed, and User Script Sandboxing remains enabled.

Two consecutive Debug builds using the same DerivedData passed with exactly the two approved fixture files present and matching their source SHA-256 values. Six focused Sprint 58 tests passed with zero failures or skips. Two consecutive optimized whole-module Release builds using the same DerivedData passed with no fixture file, fixture content or approved-fixture launcher payload present; Xcode's empty declared-output parent contained no payload. The canonical TestPlan passed 547 logical tests across 592 execution instances, 68 suites and 55 parameter runs with zero failures, skips or expected failures.

No source fixture, financial behavior, migration, DBP-01 behavior or production capability changed.

### Sprint 63 — Immutable Source Snapshot and Exact Source-Byte Fingerprint Implementation

**Ref**

`7e1345e3817d3c3e91c24f881b962a48279fd73b`

**Verified scope**

Sprint 63 implements the accepted Sprint 62 ADR-041 architecture contract. Preparation acquires one immutable app-owned `SourceContentSnapshot` containing the exact source bytes and `ledgerforge.source-bytes.sha256.v1` fingerprint. CSV retains `ledgerforge.raw-text.sha256.v1` as the duplicate authority and carries the source-byte fingerprint as a secondary fingerprint, with one authoritative fingerprint per document and SQLite/In-Memory Migration V9 provider/schema parity.

The retained snapshot is shared by extraction and fingerprinting, recomputed at confirmation, and consumed exactly once. Successful confirmation, rejection, failure, cancellation and preview supersession deterministically invalidate the snapshot. Acquisition and integrity failures produce bounded rejected outcomes, with no accepted financial residue. Historical source-byte reconstruction and durable source-byte storage are not performed. Production PDF support remains unsupported.

Independent acceptance verified 514 logical tests, 547 executions, 41 parameter runs across 8 tests, 64 suites, 0 failures and 0 skips; Debug, explicitly optimized whole-module Release and Debug analysis passed, with Release/privacy containment passing. No production PDF path was added.

### Sprint 62 — ADR-041 Immutable Source Snapshot Architecture Contract

**Verified scope**

Sprint 62 accepted ADR-041 as the architecture contract later implemented by Sprint 63. It selected `ledgerforge.source-bytes.sha256.v1`, retained `ledgerforge.raw-text.sha256.v1` for existing CSV history, required transient snapshot binding through confirmation and preserved the boundary against historical reconstruction, durable source-byte storage and production PDF support.

### Sprint 59 — Immutable Source Snapshot and Exact Source-Byte Fingerprint Authority

**Ref**

`b661472a58fc24144361322f1853b8001437a3eb`

**Verified scope**

Sprint 59 accepted ADR-041 as architecture only. `ledgerforge.source-bytes.sha256.v1` and one immutable app-owned `SourceContentSnapshot` are prospective requirements shared by extraction and fingerprinting through confirmation; neither is implemented. Existing `ledgerforge.raw-text.sha256.v1` history remains untouched, production PDF support remains unavailable, FW-P1-16 remains blocked and no migration was added.

### Sprint 56 — Explicit Reviewed Partial-Overlap Import

**Current alignment after Axis source-truth restoration:** Sprint 56's persistence schema, provider transaction, hydration and presentation structures remain implemented and readable, but its source-semantic acceptance is invalidated. The three-shared/one-later fixture is quarantined for missing immutable lineage, `axis.bank-account.csv@1` is historical only, and production now rejects mixed supported overlap until lineage-backed evidence authorizes a replacement boundary.

**Ref**

The single Sprint 56 completion commit containing this state update.

**Verified scope**

Sprint 56 accepts ADR-040 and adds additive Migration V7. The parser now owns a required immutable declared Axis statement period using `StatementDate`; the ordinary preview and partial review use that source period rather than transaction extrema.

One bounded prospective family may proceed after provider-backed read-only review: `axis.bank-account.csv@1`, bank-account, INR, one selected existing account, complete valid reconciliation, supported account-scoped Axis UPI evidence on every row, one contiguous recognized prefix and one later unique suffix. Immutable reviewed plans bind provider generation, account, exact fingerprint, profile, period, currency, balances, complete source rows, financial projections, event owners, dispositions and counts through `ledgerforge.partial-import-plan.sha256.v1`.

SQLite and In-Memory revalidate the complete plan atomically. Accepted partial sessions preserve the complete incoming document and normalized source graph, relate recognized incoming rows to unchanged durable transactions, create only unique-suffix transactions, and persist one summary, one disposition per row and one successful partial attempt with explicit counts. Stale, consumed, conflicting and losing paths write no accepted graph.

RepositoryStoreHydrator reconstructs partial summaries, attempt counts, dispositions and recognized source relationships before one observer-consistent store replacement. Missing, duplicate, unknown, cross-document, missing-event, missing-transaction, malformed period/money and count inconsistencies fail closed.

The Import Wizard, Dashboard activity, Import History, account history and Completed Imports presentation distinguish partial sessions. Review surfaces show only privacy-safe period, account, counts, balance evidence, unique impact and row dispositions.

Historical Sprint 56 acceptance used the sanitized Sprint 55 fixture pair as an independent oracle for its then-bounded campaign. Under the 2026-09-01 ADR-046 alignment that fixture pair is not a current independent source oracle or parser reliability authority; the historical transaction/document/disposition results remain recorded as implementation history only.

No canonical app launch or ordinary Debug/Release container access is part of Sprint 56 acceptance. The protected V5 Debug database remains unresolved local-only recovery evidence.

### Sprint 55 — Axis Source-Direction Correction and Partial-Overlap Evidence Closure

**Current alignment after Axis source-truth restoration:** Sprint 55's physical-role naming and dynamic header-position resolution remain useful, but its financial direction conclusion and fixture/oracle acceptance are invalidated. The historical bullets below record what Sprint 55 claimed; current source evidence establishes conventional DR-debit/CR-credit semantics under `axis.bank-account.csv@2`.

Commit:

```text
The single Sprint 55 completion commit containing this state update.
Its exact SHA is Git-authoritative and recorded in the completion report.
```

Sprint 55:

- separated dynamically resolved physical Axis DR/CR source columns from canonical debit/credit roles;
- restored the verified `axis.bank-account.csv@1` contract: physical DR becomes canonical credit with positive `Money`, and physical CR becomes canonical debit with negative `Money`;
- retained the existing parser profile ID/version because this is a source-truth defect correction rather than a new accepted layout;
- corrected sanitised Axis fixture occupancy only where independent running-balance arithmetic established the source semantics, without changing canonical expected financial truth;
- added a privacy-safe derivative of two genuine Axis statements with an independently verified three-shared/one-later-only supported UPI overlap;
- added an expected oracle that does not call production parsing, direction resolution or event-identity code;
- verified posting versus credit-adjustment subtype direction after canonical resolution;
- proved conventional or mixed future semantics fail validation without profile switching, accepted persistence or runtime financial-store residue;
- closed the Axis direction blocker and `BLOCK-PARTIAL-ORACLE-01`;
- passed 41 focused tests across 5 suites, 64 adjacent tests across 6 suites and the canonical 407-test, 49-suite TestPlan;
- passed Debug and explicit `-O` whole-module Release builds.

Migration V6, ADR-039, schema architecture, partial-overlap persistence, review UI and durable partial-import outcomes remain unchanged.

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
- ADR-044 durable card-liability/instrument architecture and exact Amex/CBQ/Axis card support.

Detailed implementation history remains in Git and accepted ADRs.

---

## Historical Planning State — 2026-08-28

- Sprint 79 is the highest-numbered **accepted** implementation, with ADR-045 and Migration V16 as the current accepted architecture/migration baseline.
- Sprint 78 and Sprint 78A failed; Sprint 78B completed the Sprint 78 outcome and no Sprint 78C exists.
- The exact accepted Axis source, ownership, credential, V15 and acceptance boundaries are recorded in the current alignment section above and in the historical `Sprint roadmap/Archived/LedgerForge_Roadmap_Sprints_70-79_Current.md`.
- Exact Axis card PDF/XLSX production support is accepted only for the Sprint 78B profiles and source-proven boundaries; broader Axis/card/XLSX claims remain unsupported.
- Sprint 79 is accepted and published; Sprint 80 is accepted as the `SWIFT6_READINESS_COMPLETE` discovery outcome. No Swift-6 migration or readiness implementation has been performed.
- Sprint 80's accepted sequencing is: documentation sync; accepted-profile CBQ corrective closure; PR-1 ownership seam; serial Unified Import Centre; PR-2 / PR-3 / TEST-PR; coordinated Swift-6 migration; then personal-v1 certification. Parallel preparation remains an open architecture decision.
- `FUTURE_WORK.MD` remains the canonical queue for work that is not currently selected for execution. It is not the active-sprint authority.

---

## Planning Boundary

- `PROJECT_STATE.md` records accepted repository reality plus explicitly labelled active unaccepted WIP when present.
- `Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md` is the repository planning authority for the current cycle's sprint numbering, corrective suffixes, status and next gates. `Sprint roadmap/Archived/LedgerForge_Roadmap_Sprints_70-79_Current.md` is retained as the historical prior-cycle roadmap.
- `LedgerForge_Standing_Execution_Harness_Guide.md` is the repository standing execution/review-method authority.
- `FUTURE_WORK.MD` is the canonical unscheduled planning queue.
- Accepted ADRs govern accepted architecture; ADR-045 governs the implemented Sprint 79 salary/planning boundary, while the Sprint 78B ADR-015 and ADR-044 amendments remain accepted implemented state for their domains.
- The complete Chat-approved prompt is the execution contract for the current task.
- Chat owns sprint/architecture/acceptance decisions. MCP executor provides guarded local Mac repository/Xcode access inside Chat. Codex is a separate execution environment and must receive a self-contained prompt plus repository-local authorities.
- Before any write, exact branch/HEAD/divergence, worktree/index state, branches/worktrees/stashes, active Git operations, validations, MCP lease and independent external writers must be verified.
