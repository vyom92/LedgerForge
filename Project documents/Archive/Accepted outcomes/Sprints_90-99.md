# Accepted outcomes — Sprints 90-99

Accepted evidence by cycle, not execution authority. [Current state](../../PROJECT_STATE.md) owns the accepted product snapshot; the [current roadmap](../../Sprint%20roadmap/LedgerForge_Roadmap_Sprints_90-99_Current.md) owns numbering. Ordering inherits [Guide rule F](../../Project_Guide.md#documentation-order): known acceptance dates descending, then recorded acceptance sequence or natural sprint ID descending. Earlier cycle records retain their original evidence and limitations.

## Index

- [Accepted Sprint 94 — Current Al Dar and This Month Planning — 2026-09-15](#sprint-94)
- [Accepted Sprint 93 — Verified Backup, Restore and Disaster Recovery — 2026-09-15](#sprint-93)
- [Accepted Sprint 92 — Information Presentation and R1 Polish — 2026-09-14](#sprint-92)
- [Accepted Sprint 91A — Dark Appearance and Visual Foundation — 2026-09-14](#sprint-91a)
- [Accepted Sprint 90 — R1 Dashboard Native-Currency Hierarchy — 2026-09-12](#sprint-90)

**Current alignment — 2026-09-15:** the owner/coordinator accepts Sprint 94 and authorizes closure/publication of the unchanged accepted implementation. Original Sprint-90 through Sprint-93 records retain their then-current evidence and limitations. The post-94 correction gate precedes Sprint 95; **PERSONAL-V1 remains NOT YET ADOPTED**.

---

<a id="sprint-94"></a>
## Accepted Sprint 94 — Current Al Dar and This Month Planning — 2026-09-15

**OWNER/COORDINATOR-ACCEPTED** under `SPRINT_94_CURRENT_AL_DAR_AND_THIS_MONTH_PLANNING_ACCEPTED`. Accepted predecessor and publication parent: `main@99f27b376fe6f3a37e6a15f7cd65c5e16a49caed` (Sprint 93). The owner authorizes documentation reconciliation, exact-path commit and normal push of the complete accepted candidate. The commit containing this record publishes the accepted implementation and closure together. Closure changes no product/test behavior and reruns no builds, tests, provider requests, source campaigns or recovery drills. **PERSONAL-V1 remains NOT YET ADOPTED.**

### Accepted product contract

- Explicit Refresh Al Dar always requests QAR 1, independently of Salary input completion or a positive India shortfall. This is a **QAR-1 current Al Dar unit planning reference**, indicative and used to estimate a transfer, not settlement or general market-FX authority.
- A fetched reference stays pending until explicit Use Reference, which binds it to the current positive INR shortfall. Save/Command-S remains explicit. Manual planning FX is a mutually exclusive planner-only fallback; it is not shown on Dashboard. There is no Dashboard Planning FX card.
- The UI displays exactly two rate decimals with fetch context. The raw provider token, full precision, exact-ratio calculation and persisted evidence remain authoritative internally. The display value never feeds calculations or persistence.
- Planning balances select active QAR/INR bank accounts with a valid saved identity, without institution/name/nickname/NRE/NRO heuristics. Same-currency credit cards may link manually entered commitment amounts. Previously saved funding-bank references remain intact and explicitly labelled.
- Untouched zero inputs are blank with a 0 placeholder; meaningful entered/saved/rolled zeros remain valid. Actual months use Aug 2026 format. A native picker selects the manual FX observation date without changing imported source-date meaning.
- Available for investment is floored at zero; the underlying funds-before-investment and final QAR buffer retain deficits. Missing required inputs remain unavailable.
- The measured Dashboard layout correction is retained with the existing native-currency composition, Money, colours and responsive arrangements. It does not close the remaining navigation-performance defect.

### Accepted schema and backup compatibility

**V18 is current**, under accepted [ADR-045](../../ADR.md#adr-045) and [ADR-047](../../ADR.md#adr-047) alignments. The additive reference child table and manual/external exclusion triggers preserve V1–V17 byte-for-byte; no parent-table rebuild or new closure migration/ADR is introduced. Save and staged hydration validate the external reference's durable shortfall binding before canonical publication.

Backup format remains **1**. New backups use V18; exact V18 restore and exactly V17 format-1 isolated upgrade are supported. The selected original V17 package remains untouched. Its original payload SHA remains receipt identity; only the separate app-owned candidate upgrades and receives its own in-memory hash. Valid retained V17 receipt startup can verify, apply V18, hydrate and complete relaunch confirmation. V16/earlier, future, incomplete or unknown histories reject. Appearance remains device-local and excluded from backup.

The earlier genuine V17/V18 isolated restore, product backup, retained-receipt startup, selected rollback/process-interruption and actual Current Database migration/relaunch results remain accepted as recorded in the [implementation history](../../Work%20notes/Salary_and_current_AlDar.md#prior-bounded-verification--2026-09-15). They are not rerun or reclassified as new closure evidence.

### Accepted validation: two distinct byte boundaries

The preceding owner-correction fingerprint covers **334 source/test/build/resource inputs**, SHA-256 `04879c91629c439f8eac09feba2c1e1ff947bca9474233692f2b2cbdb0e82e90`.

| Preceding owner-correction evidence | Accepted result |
| --- | --- |
| Ordinary app regression | **567 definitions / 627 executions / 0 failures / 0 skips**; `LedgerForge-validation.CRey7v/TestResults.xcresult`. Twelve parameterized definitions produced 72 runs, accounting for the extra 60 executions. |
| Final focused correction | **45 definitions / 46 executions / 0 failures / 0 skips**; AlDarReferenceTests 18/18, PlannerEditorTests 19/20, SalaryParserAndPlannerTests 8/8; `LedgerForge-validation.fLIohN/TestResults.xcresult`. Includes populated manual-FX rollover under V18, final hydration, typed account/card eligibility and the owner corrections. |
| Debug / optimized Release | Both PASS; `LedgerForge-validation.73IEXm` / `LedgerForge-validation.Ghb8Gn`. |
| Native / saved state | Owner reported “verified all”; genuine mixed INR/QAR bank/card presentation passed. The corrected restart/native checks preserved all 54 logical tables and preference bytes against the owner's saved baseline. |

The final two-decimal-only fingerprint covers the same **334 inputs**, SHA-256 `4f262c7d8ba35110d9aa77aec162a0d951723c93a57d62455a8c36cde15d1986`.

| Final presentation-only evidence | Accepted result |
| --- | --- |
| Focused display / exact ratio | `AlDarReferenceTests.testUnitRateDisplayUsesTwoDecimalsWithoutChangingExactRatio`: **1 definition / 1 execution / 0 failures / 0 skips**; `LedgerForge-validation.CVNCeX/TestResults.xcresult`. Rounding/trailing zeros and retained raw precision pass, including a calculation case that would differ if the display-rounded rate were used. |
| Fresh Debug / optimized Release | Both PASS; `LedgerForge-validation.5UxLZQ` / `LedgerForge-validation.PbrqL8`. |
| Quick native check | **1 QAR = 26.25 INR**, with **Fetched 15 Sep 2026 at 20:25 · UTC+03:00**. One explicit QAR-1 Refresh through the unchanged client remained pending/not applied. No Apply, Save, financial-field edit, resize or appearance change. |
| Saved state / containment | All **54 tables** and preference bytes remained unchanged. Debug/Release resource containment passed; no statement, credential, database, screenshot or financial comparison artifact entered Git. |

**The 567/627 ordinary run did not execute against the final two-decimal-only bytes.** The owner accepts it as retained evidence from the immediately preceding fingerprint because the final delta changed presentation only and passed its own bounded verification. It is **ordinary app regression, not complete authentic/source acceptance**. No new ordinary, corpus, provider or recovery execution is performed during closure. Earlier failures, retries, superseded fingerprints and unobserved native states remain in the linked work-note history rather than being rewritten as final passes.

### Seventeen definitions retained outside the ordinary selection

The unchanged [TestPlan](../../../TestPlan.xctestplan) uses 12 selectors covering these exact **17 definitions**. The unchanged [validation driver](../../../script/validate.sh) forwards those selectors because plan-only Swift Testing exclusions were not reliably honored. No additional exclusion was introduced for a failed test. The categories remain 13 corpus definitions, one evidence-destination preflight, two copied-source checks and one separately authorized live-client check.

- `AmericanExpressPrivateAcceptanceTests/completePrivateCorpusMatchesFrozenOracleAndImportCampaigns()`
- `AxisBankAuthenticAcceptanceTests/completeAuthenticCorpusMatchesIndependentOracleAndCrossFormatProjection()`
- `AxisBankAuthenticAcceptanceTests/completeAuthenticCorpusPersistsWithProviderParityReplayReopenAndHydration()`
- `AxisBankV17AuthenticMigrationTests/authenticPopulatedV16UpgradesLosslesslyThenAcceptsAllAxisCarriers()`
- `AxisBankV17AuthenticMigrationTests/authenticPopulatedV16CardGraphSurvivesV17AndReopen()`
- `AxisBankV17AuthenticMigrationTests/historicalAuthenticCBQV16GraphPreservesMissingMinimumDueThroughV17()`
- `AxisCreditCardAuthenticAcceptanceTests/completeAuthenticCorpusMatchesIndependentSourceOracle()`
- `AxisCreditCardAuthenticAcceptanceTests/completeAuthenticCorpusPersistsThroughOrdinaryConfirmationWithParityReplayAndReopen()`
- `CBQBankAuthenticAcceptanceTests/completeOriginalsPersistReplayAndReopen()`
- `CBQCreditCardPrivateAcceptanceTests/completePrivateCorpusMatchesProductionGrammarAndIndependentOracle()`
- `GlobalAuthenticCorpusAcceptanceTests/configuredEvidenceDestinationSupportsAtomicWrites()`
- `GlobalAuthenticCorpusAcceptanceTests/completeAuthenticCorpusUsesMixedOrdinaryImportReplayAndReopen()`
- `HDFCBankAccountAuthenticAcceptanceTests/completeOriginalsMatchSourcePersistReplayAndReopen()`
- `ImportRepositoryIntegrationTests/exactAxisReimportIsBlockedDurablyWithBoundedProvenance()`
- `SalaryAuthenticCorpusAcceptanceTests/completeAuthenticCorpusUsesOrdinaryImportPersistenceReplayAndReopen()`
- `SourceSnapshotConfirmationTests/preparationRetainsSnapshotAndConfirmationDoesNotRereadDeletedURL()`
- `Sprint94LiveClientTests/testOneApprovedPublicSample()`

### Accepted limitations and required handoff

Navigation remains an **OPEN defect**: the owner reports approximately five seconds switching to Transactions and two seconds for other destinations. The retained Dashboard correction establishes one measured layout cost; it does not diagnose or resolve every transition. Keep the populated disposable Current Database for the dedicated measured correction and the expected ongoing growth of roughly five authentic statements per month. The [long-term proposal](../../Work%20notes/Salary_and_current_AlDar.md#populated-dashboard-layout-correction-and-growth-observation) remains a proposal, not implemented performance work.

The [post-94/pre-95 correction gate](../../FUTURE_WORK.MD#post-94-pre-95-corrections) requires navigation performance, Amex unsupported currency, Amex account/card chooser cleanup, import-created account naming/type/currency, and Transaction Preview layout before Sprint 95. No permanent sprint number is assigned and closure implements none of them. Uninvestigated reports do not become proven causes or fixes by inclusion here.

Sprint-93 hardware power-loss, real disk-full/permission/durability failure, interruption within individual preservation/rollback loops, real cleanup failure and long genuine-copy cancellation remain **NOT_OBSERVED / NOT_TESTED**. The separate Release owner database was not opened by Sprint-94 final checks. Genuine Debug recovery and the historical separate Release drill retain their own scope. No source-support expansion, original mutation or derived financial evidence is implied by a green ordinary suite or native mixed-currency observation.

### Settled 95–100 sequence

| Sprint | Accepted planning position |
| --- | --- |
| 95 | Salary → Budget Planner / This Month, using Budget Analysis Dashboard as workflow reference; Salary History remains supporting evidence. **Acceptance is a hard prerequisite for Sprint 100.** |
| 96 | Investment domain and identity foundation; no prices in this foundation. |
| 97 | Current holdings followed by current valuation, two ordered phases. Prices never establish ownership. |
| 98 | Separate integrated current portfolio acceptance. |
| 99 | One shared current-market QAR/INR/USD FX authority and net worth. Two-decimal presentation retains greater internal precision; direction/reporting selection recalculates locally without fetching. Dashboard-open, manual and periodic refresh plus the accepted stale/weekend policy remain required. Al Dar stays separate. |
| 100 | Personal-v1 adoption certification after accepted prerequisites; not started by this closure. |

The [90–99 roadmap](../../Sprint%20roadmap/LedgerForge_Roadmap_Sprints_90-99_Current.md) owns the numbering and the [100 entry gate](../../Sprint%20roadmap/Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md#sprint-100--ledgerforge-10-personal-adoption-verification) retains the hard Budget Planner prerequisite. Future architecture/implementation remains separately authorized.

### Publication inventory

The accepted working candidate contained **38 paths**. Closure adds this existing accepted-outcomes collection for **39 published paths: 35 modified and four added**. All **27 non-Markdown product/test/project/validation files** remain byte-for-byte unchanged during closure. The final 334-input fingerprint remains the accepted two-decimal fingerprint above. Exact-path staging, full/staged diff, links, whitespace, source/privacy residue and Git convergence are reviewed separately from the retained runtime evidence. No new build/test/provider/source/recovery campaign is run.

- [ContentView.swift](../../../ContentView.swift)
- [Database/BackupPackage.swift](../../../Database/BackupPackage.swift)
- [Database/Migrations.swift](../../../Database/Migrations.swift)
- [Database/SQLiteSalaryRepository.swift](../../../Database/SQLiteSalaryRepository.swift)
- [Database/SalaryPersistence.swift](../../../Database/SalaryPersistence.swift)
- [LedgerForge.xcodeproj/project.pbxproj](../../../LedgerForge.xcodeproj/project.pbxproj)
- [LedgerForgeApp.swift](../../../LedgerForgeApp.swift)
- [LedgerForgeTests/AlDarReferenceTests.swift](../../../LedgerForgeTests/AlDarReferenceTests.swift)
- [LedgerForgeTests/BackupPackageTests.swift](../../../LedgerForgeTests/BackupPackageTests.swift)
- [LedgerForgeTests/DashboardViewModelTests.swift](../../../LedgerForgeTests/DashboardViewModelTests.swift)
- [LedgerForgeTests/LedgerForgeTests.swift](../../../LedgerForgeTests/LedgerForgeTests.swift)
- [LedgerForgeTests/MigrationChainIntegrityTests.swift](../../../LedgerForgeTests/MigrationChainIntegrityTests.swift)
- [LedgerForgeTests/PlannerEditorTests.swift](../../../LedgerForgeTests/PlannerEditorTests.swift)
- [LedgerForgeTests/SQLiteOwnershipTests.swift](../../../LedgerForgeTests/SQLiteOwnershipTests.swift)
- [LedgerForgeTests/SalaryParserAndPlannerTests.swift](../../../LedgerForgeTests/SalaryParserAndPlannerTests.swift)
- [LedgerForgeTests/Sprint94LiveClientTests.swift](../../../LedgerForgeTests/Sprint94LiveClientTests.swift)
- [LedgerForgeTests/ZeroActivityMigrationV17Tests.swift](../../../LedgerForgeTests/ZeroActivityMigrationV17Tests.swift)
- [Models/AlDarReference.swift](../../../Models/AlDarReference.swift)
- [Models/Salary.swift](../../../Models/Salary.swift)
- [Project documents/ADR.md](../../../Project%20documents/ADR.md)
- [Project documents/Archive/Accepted outcomes/Sprints_90-99.md](../../../Project%20documents/Archive/Accepted%20outcomes/Sprints_90-99.md)
- [Project documents/BUILD_AND_PROJECT_CONVENTIONS.md](../../../Project%20documents/BUILD_AND_PROJECT_CONVENTIONS.md)
- [Project documents/FUTURE_WORK.MD](../../../Project%20documents/FUTURE_WORK.MD)
- [Project documents/PROJECT_STATE.md](../../../Project%20documents/PROJECT_STATE.md)
- [Project documents/SCOPE_DECISIONS.md](../../../Project%20documents/SCOPE_DECISIONS.md)
- [Project documents/Sprint roadmap/LedgerForge_Roadmap_Sprints_90-99_Current.md](../../../Project%20documents/Sprint%20roadmap/LedgerForge_Roadmap_Sprints_90-99_Current.md)
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md](../../../Project%20documents/Sprint%20roadmap/Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md)
- [Project documents/Work notes/Backup_and_export.md](../../../Project%20documents/Work%20notes/Backup_and_export.md)
- [Project documents/Work notes/Current_FX_and_net_worth.md](../../../Project%20documents/Work%20notes/Current_FX_and_net_worth.md)
- [Project documents/Work notes/Salary_and_current_AlDar.md](../../../Project%20documents/Work%20notes/Salary_and_current_AlDar.md)
- [Services/AlDarCurrentReferenceProvider.swift](../../../Services/AlDarCurrentReferenceProvider.swift)
- [Services/BackupRestoreCoordinator.swift](../../../Services/BackupRestoreCoordinator.swift)
- [Services/RepositoryStoreHydrator.swift](../../../Services/RepositoryStoreHydrator.swift)
- [TestPlan.xctestplan](../../../TestPlan.xctestplan)
- [ViewModels/DashboardViewModel.swift](../../../ViewModels/DashboardViewModel.swift)
- [ViewModels/SalaryWorkspaceViewModel.swift](../../../ViewModels/SalaryWorkspaceViewModel.swift)
- [Views/SalaryView.swift](../../../Views/SalaryView.swift)
- [script/README.md](../../../script/README.md)
- [script/validate.sh](../../../script/validate.sh)

---

<a id="sprint-93"></a>
## Accepted Sprint 93 — Verified Backup, Restore and Disaster Recovery — 2026-09-15

**OWNER/COORDINATOR-ACCEPTED** under `SPRINT_93_VERIFIED_BACKUP_RESTORE_AND_DISASTER_RECOVERY_ACCEPTED`, following `SPRINT_93_BACKUP_RESTORE_CANDIDATE_READY_FOR_CHAT_REVIEW`. Required published entry baseline: `main@7218f536eee5c871243d1170e8db0f4c150728bb`; accepted predecessor: Sprint 92. The owner authorizes documentation closure, exact-path commit and normal push of the unchanged product candidate. The commit containing this record publishes that accepted outcome. Closure performs no further product changes, build/test run, genuine restore drill or failure campaign.

### Accepted product and architecture

[ADR-047](../../ADR.md#adr-047) is **ACCEPTED**; [FW-P3-36](../../SCOPE_DECISIONS.md#fw-p3-36) is **COMPLETE** for the selected verified backup/restore outcome. Settings → Application & data → Backup & Restore provides Create Backup… and Restore Backup… through native selection. One Finder `.ledgerforgebackup` package contains exactly `ledger.sqlite` and `manifest.json`, with no archive wrapper and no overwrite of an existing package.

Format 1 uses bounded typed metadata: backup UUID, UTC creation instant, producing app identity/version/build, payload member name/byte size/SHA-256, schema and complete ordered migration versions/names/checksums, contents and exclusions. It does not duplicate financial rows. Strict initial compatibility requires the exact current V1–V17 chain and expected actual schema. Unsupported format, older/future/incomplete/unknown history, identity/checksum mismatch, corruption and missing/extra/symlinked package members are rejected. Future schema changes require an explicit compatibility decision. **V17 is unchanged; no V18, new closure ADR or permanent ledger-lineage UUID.**

SQLite online backup captures the canonical provider under production operation ownership. Checked completion/close, isolated content/history/schema/integrity/foreign-key verification and staged canonical hydration precede hashing and verified destination-local publication. Restore verifies a copied candidate before Cancel-default explicit replacement confirmation. The selected package remains untouched. Unresolved operations/drafts are not silently discarded; replacement owns the gate and invalidates stale generations. A durable receipt precedes preservation of the previous database set. Before committed activation, failure recovers prior valid state or reports unavailable; after durable commit, startup reopens the new ledger rather than discarding later accepted writes. Canonical relaunch confirmation permits operation cleanup. Missing storage never silently creates an empty recovery ledger.

The complete durable SQLite graph, including normalized/source/provenance and import/validation records, remains included. External originals, credentials/Keychain, runtime logs, appearance/window/profile preferences, private screenshots and development artifacts remain excluded. The observed genuine source and closed snapshot contained zero attachment rows and zero nonempty attachment BLOB payloads; arbitrary future databases are not certified by this observation. Conflicting embedded payloads stop for an explicit content decision, without stripping ledger rows.

### Original implementation evidence — 2026-09-14

The following checkpoint was recorded before acceptance and is accepted on 2026-09-15 without rerunning it. Its then-uncommitted status remains historical.

The candidate starts from clean `main@7218f536eee5c871243d1170e8db0f4c150728bb`; HEAD remains there, with candidate changes unstaged and uncommitted. Architecture approval is distinct from product acceptance. No V18 or permanent ledger UUID was introduced.

| Evidence | Executed result and boundary |
| --- | --- |
| Build and membership | Final Debug build 12 and optimized Release build 6 succeeded. Both products identify as `com.vyom.LedgerForge`, version 1.0, build 1, with the package type and native Settings controls present. Release contains no Sprint-93 failure probes or DEBUG profile/reset owner. No recovery databases, verifier scripts or private captures entered app resources. |
| Focused mechanics | `BackupPackageTests` has 19 definitions; the final focused execution passed 19, failed 0, skipped 0. Five focused runs during implementation executed 82 cases in total (12 + 16 + 17 + 18 + 19), all passing. Checks cover format/chain/schema identity, actual history mismatch, missing/extra/symlinked members, checksum mismatch, no-overwrite publication, non-creating open, cancellation, activity/draft refusal, stale generation, and explicit first-use guards. One repeated result-directory setup attempt executed no tests and was rerun with a fresh location. |
| Content contract | The genuine source and closed published snapshot passed the exclusion check: no attachment rows or nonempty BLOB payloads were present. The current complete durable schema was retained; the independent verifier inspected all actual tables, including SQLite-managed state. Unknown future attachment payloads still stop backup for a content decision; this is not proof of arbitrary embedded-file exclusion. No original statements were opened. |
| Genuine native drill | A product backup was created, one existing account display name received the approved temporary suffix through the native editor, and the independent RAM verifier found only that one field changed. Native verified restore returned complete typed logical state P1 = P0. Clean termination and ordinary canonical relaunch produced P2 = P0, with the same restore-operation/backup receipt and successful canonical hydration. The suffix was removed by restore. |
| Release startup and restore | The separate pre-existing Release ledger used its unchanged registered normal-startup migration path, then completed its own native product backup/restore and clean relaunch with exact P0/P1/P2 equality. This Release ledger had no financial rows; it proves the Release path without substituting for the populated genuine Debug drill. Strict recovery never upgrades an older backup. |
| Activation failures | Isolated genuine recovery copies exercised failure after preservation, before candidate open, after candidate hydration, and before activation-record publication. Each reopened/hydrated the exact previous state and reported successful rollback. An injected rollback-open failure retained recovery assets, entered explicit unavailability and left Restore reachable; a subsequent native controlled restore recovered the exact verified backup and relaunched successfully. |
| Process interruption | Real process exit before commit recovered the exact previous state; real process exit after durable commit reopened the restored state. A second restart of each case was idempotent. The same receipt remained authoritative, and committed restore was not reverted to old state. These are process-interruption checks, not hardware power-loss tests. |
| Missing target and first use | Missing canonical storage remained unavailable. Native Cancel created no directory/database; explicit Create New Ledger created only the accepted empty schema on an isolated first-use target. A separate missing target restored the genuine backup, removed the first-use action and passed canonical relaunch. A stale creation choice preserved an already valid provider in the focused check. |
| Native usability and preservation | Folder/package pickers, repeated picker cancellation, Cancel-default replacement confirmation, success, rollback, unavailable recovery and relaunch-confirmed states were inspected in the actual app. Debug and Release kept distinct canonical targets. Selected packages and saved appearance/profile preferences remained unchanged. |

The standalone [acceptance verifier](../../../script/verify_backup_restore.py) compares complete typed logical records, NULLs, exact stored values, BLOBs, multiplicity, schema and SQLite-managed metadata independently of the coordinator/hydrator. Private comparison state was held only in RAM; no financial evidence dump was written. Two verified product packages and a pre-startup Release safety snapshot are retained outside Git and the original-statement directory. All nine verified disposable isolated recovery namespaces and their seed copy were removed after exact comparison and closed-handle checks. Both real restore receipts are relaunch-confirmed and their owned rollback directories are removed. The final Debug product is on ordinary Current Database with no temporary suffix or selected test namespace; Release was cleanly terminated after its verified relaunch.

Unobserved boundaries remain explicit: hardware power loss; real disk-full, permission or durability-call failure; interruption inside a per-member preservation/rollback loop; real rollback-asset cleanup failure; and cancellation during a long genuine copy. Native picker/confirmation cancellation and pre-cancelled operation cleanup passed. Broad TestPlan, unrelated unit/integration/financial regression, parser corpus and source-oracle campaigns remain **SUSPENDED / NOT RUN**. These limits do not represent executed passes.

### Acceptance of limits and retained state

The owner explicitly accepts the recorded limits as **NOT_OBSERVED / NOT_TESTED**: real hardware power loss; real disk-full failure; real filesystem permission failure; real durability/fsync-family failure; interruption inside an individual preservation/rollback file loop; real rollback-asset cleanup failure; and cancellation during a long genuine copy. They remain limitations, not passes, and do not block the selected Sprint-93 outcome.

The independent genuine comparison covered all 53 actual observed tables, including SQLite-managed state, with exact values, NULL distinction, BLOB values, multiplicity, schema and relevant SQLite metadata. P0/P1/P2 were held only in RAM; no financial comparison dump was written. All verifier processes exited and released handles/RAM before closure. The separate optimized Release ledger was empty and followed ordinary startup V4→V17 before its own backup; this does not qualify populated historical migration. Populated restore proof came from the genuine Debug drill.

Native controls/pickers, safe cancellation, explicit confirmation, successful completion, rollback, unavailable recovery and relaunch states were inspected during implementation. Accepted final runtime: ordinary Debug Current Database, no temporary suffix or selected test namespace, canonical Debug handles only, both real receipts relaunchConfirmed, completed operation directories removed and saved appearance/preferences unchanged. Closure does not disturb that runtime.

Two verified product-format packages and the pre-startup Release raw safety snapshot remain outside Git and the authentic-statement directory. The raw snapshot is not a format-1 package. Publication must not modify/delete these artifacts or turn them into app-managed backup history. All nine disposable isolated recovery namespaces and their seed were cleaned during implementation. Build/test results and inline native captures remain outside Git/app resources.

### Publication scope and disposition

The accepted candidate contained 29 paths. Closure adds only this existing accepted-outcomes collection, for **30 intended published paths**. The 23 non-documentation files remain byte-for-byte unchanged during closure. The final staged diff and Git hygiene are checked separately; prior build, containment and 19/19 focused evidence are reused. Five evolving focused runs account for 82 executions, not 82 distinct tests. A result-directory setup attempt executed zero tests before retry. Broad TestPlan, unrelated regression suites, parser corpus and source-oracle campaigns remain **SUSPENDED / NOT RUN**; closure runs none of them.

- [.gitignore](../../../.gitignore)
- [ContentView.swift](../../../ContentView.swift)
- [Core/RuntimeDiagnostics.swift](../../../Core/RuntimeDiagnostics.swift)
- [Database/BackupPackage.swift](../../../Database/BackupPackage.swift)
- [Database/RestoreOperation.swift](../../../Database/RestoreOperation.swift)
- [Database/SQLiteDatabase.swift](../../../Database/SQLiteDatabase.swift)
- [Database/SQLiteRepositoryProvider.swift](../../../Database/SQLiteRepositoryProvider.swift)
- [LedgerForge-Info.plist](../../../LedgerForge-Info.plist)
- [LedgerForge.xcodeproj/project.pbxproj](../../../LedgerForge.xcodeproj/project.pbxproj)
- [LedgerForgeApp.swift](../../../LedgerForgeApp.swift)
- [LedgerForgeTests/BackupPackageTests.swift](../../../LedgerForgeTests/BackupPackageTests.swift)
- [LedgerForgeTests/LedgerForgeTests.swift](../../../LedgerForgeTests/LedgerForgeTests.swift)
- [Project documents/ADR.md](../../../Project%20documents/ADR.md)
- [Project documents/Archive/Accepted outcomes/Sprints_90-99.md](../../../Project%20documents/Archive/Accepted%20outcomes/Sprints_90-99.md)
- [Project documents/FUTURE_WORK.MD](../../../Project%20documents/FUTURE_WORK.MD)
- [Project documents/PROJECT_STATE.md](../../../Project%20documents/PROJECT_STATE.md)
- [Project documents/SCOPE_DECISIONS.md](../../../Project%20documents/SCOPE_DECISIONS.md)
- [Project documents/Sprint roadmap/LedgerForge_Roadmap_Sprints_90-99_Current.md](../../../Project%20documents/Sprint%20roadmap/LedgerForge_Roadmap_Sprints_90-99_Current.md)
- [Project documents/Work notes/Backup_and_export.md](../../../Project%20documents/Work%20notes/Backup_and_export.md)
- [Services/AccountMetadataCoordinator.swift](../../../Services/AccountMetadataCoordinator.swift)
- [Services/ApplicationHydrationWorkflow.swift](../../../Services/ApplicationHydrationWorkflow.swift)
- [Services/BackupRestoreCoordinator.swift](../../../Services/BackupRestoreCoordinator.swift)
- [Services/CategoryManagementCoordinator.swift](../../../Services/CategoryManagementCoordinator.swift)
- [Services/DatabaseActivityGate.swift](../../../Services/DatabaseActivityGate.swift)
- [Services/ImportEngine.swift](../../../Services/ImportEngine.swift)
- [Services/RepositoryStoreHydrator.swift](../../../Services/RepositoryStoreHydrator.swift)
- [ViewModels/SalaryWorkspaceViewModel.swift](../../../ViewModels/SalaryWorkspaceViewModel.swift)
- [Views/BackupRestoreSettingsSection.swift](../../../Views/BackupRestoreSettingsSection.swift)
- [Views/CategoryManagementView.swift](../../../Views/CategoryManagementView.swift)
- [script/verify_backup_restore.py](../../../script/verify_backup_restore.py)

**Sprint 94: NEXT / NOT STARTED. PERSONAL-V1: NOT YET ADOPTED.** Sprint 94–100 order and entry boundaries are unchanged. Complete structured export remains **OPTIONAL / NOT SELECTED**; backup encryption remains **NOT REQUIRED / NOT SELECTED**. Appearance preferences remain **DEVICE-LOCAL / EXCLUDED FROM BACKUP**. Existing rejected NOT REQUIRED-DO NOT CONSIDER decisions and Sprint 90/91A/92 accepted histories remain intact.

---

<a id="sprint-92"></a>
## Accepted Sprint 92 — Information Presentation and R1 Polish — 2026-09-14

**OWNER/COORDINATOR-ACCEPTED** under `SPRINT_92_INFORMATION_PRESENTATION_AND_R1_POLISH_ACCEPTED`, following `SPRINT_92_FINAL_VISUAL_REVIEW_READY`. Authoritative entry baseline: published `main@3f1e7e97d5cac0ba9f1c3010ae8c30a79d106c96`. The owner explicitly authorizes the unchanged accepted product bytes, documentation closure, allowlisted commit and normal push to main. The commit containing this record publishes that outcome. Closure performs no additional visual tuning, appearance reset, implementation, build, native/financial campaign or regression run.

### Accepted outcome and financial boundary

The accepted Sprint-91A theme/local-preference architecture, saved owner overrides, Dashboard position hierarchy, distinct Bank balances/Card liabilities, compact account/source context, Salary/Funding and Import supporting modules, Recent Activity, responsive structure and existing routes remain. Shared financial positive/negative roles are `#429975` / `#BA5861`; they reinforce established meaning in Dashboard, Transactions, Accounts and existing amount/effect consumers. Workflow success/error roles remain separate. Exact Money formatting, sign, currency and date meanings are unchanged.

**Recorded Activity** is one bounded read-only FW-P2-46 slice over **all recorded activity**, using the existing unrestricted Transactions presenter. Bank movements show Inflow/Outflow; Card liability movements show Increase owed/Decrease owed. Each actual currency remains separate. The largest magnitude inside each Bank section defines that Bank scale, and the largest magnitude inside each Card section defines that Card scale. **Physical bar lengths across Bank and Card sections are not comparable.** Exact signed Money labels remain authoritative and fully visible. No log scale or minimum fake magnitude is introduced; zero-only coordinates retain zero-length bars.

Count, source-date extent and native-currency metadata are derived from genuine presentation state, never hardcoded to the review snapshot. The compact footer is **“Coverage may have gaps · Transfers and settlements may be included”** with subordinate **“Bars scaled within each section”**. Missing source-date/undated context and withheld effects retain explicit presentation. No income, spending, expense, cash-flow, net-worth, transfer, category, historical-trend, forecast or hidden-FX semantics are accepted.

Cross-screen corrections include the owner-requested redundant-caption/banner removal; wider aligned Dashboard recent values; accurate Import completed outcome/recovery presentation; display-only Salary Money digits, actuals/planning-rate terminology and Remove commitment help; and preserved genuine contextual controls and Transactions selection/focus. Import-event timestamps use **this Mac's local time with an explicit time-zone offset**, preserving the underlying instant. Missing/invalid instants display **Time unavailable**. This policy does not convert statement civil dates or transaction financial dates.

The new Dashboard adapter is read-only and copies exact accepted partition Money. Financial-domain models/calculations, parser/source handling, identities, repositories/providers/persistence, migration history **V1–V17**, Swift 6, signing/entitlements, deployment configuration and the accepted day-change correction are unchanged. No ADR or migration is added. Appearance settings are not rewritten or reset during closure.

### Original queue reconciliation

| Owner | Accepted disposition |
| --- | --- |
| FW-P2-40 | **Complete** for the selected ordinary-screen terminology and redundant-copy need. Precise financial/provenance terms remain intentional. Completed-ID reference retained in SCOPE_DECISIONS. |
| FW-P2-41 | **Complete** for current six-destination contextual-action conformance and genuine availability. Repeated global Import remains absent; no filler toolbar or new workflow was needed. |
| FW-P2-46 | **OPEN beyond the accepted slice.** Only the all-recorded native-currency bank/card effect comparison is accepted. Broader interactive-chart work needs later owner selection and financial qualification. |
| FW-P2-47 | **Complete** for the selected truthful Import completion/recovery presentation. Unobserved combinations remain evidence limits, not a claim of universal state certification. |
| FW-P2-48 | Selected R1 layout, complete-Money, copy and colour corrections are **accepted**. The concrete **open remainder** is Import Preview Candidate A/B placement, never selected because a genuine prepared preview was unavailable. Later genuine-state comparison and owner selection are required. |
| FW-P2-50 | **Complete** for useful existing R1 keyboard interaction, including row selection/inspector movement and retained selection under Search focus, building on accepted 89/90 behavior. No hypothetical shortcut/full-tab/hover programme is retained to keep the ID open. |

FW-P2-49 remains **NOT REQUIRED-DO NOT CONSIDER**. A formal accessibility programme is not claimed or created. The current queue retains broader charts and the precise Import Preview proposal; completed IDs are not reused. Sprint 93 is **NEXT / NOT STARTED**, with the existing Sprint 93–100 sequence unchanged.

### Refreshed SC-05A outcome

The original Sprint-88 audit body is preserved byte-for-byte. [The dated Sprint-92 refresh](../../UI%20Assets/LF-UI-2026-09-R1/LF-UI-2026-09-R1_SC-05A_Cross_Screen_Conformance_Matrix.md#sprint-92-refresh) rechecks applicability against accepted 89–91A; it does not pretend the historical audit inspected Sprint 92.

| ID | Refreshed outcome | Verification boundary |
| --- | --- | --- |
| P1 · Outer insets | **RESOLVED_BY_PRIOR_WORK** | Already uses the shared page-padding role; no new inset patch. |
| P2 · Salary display digits | **STILL_APPLICABLE → corrected** | Current editor inspected; populated/long authentic Salary history was not available. |
| P3 · Import terminal review | **STILL_APPLICABLE → corrected in source/compiled** | Genuine idle/history inspected; the new completed/refresh-needed/failure branches were not all natively observed. |
| P4 · Salary terminology | **STILL_APPLICABLE → corrected and observed** | Actuals and INR-per-QAR planning-rate labels observed with unchanged existing inputs/calculation. |
| P5 · Import timestamps | **STILL_APPLICABLE → corrected** | Owner-selected Mac-local instant plus explicit offset observed in Dashboard/Import History; missing/invalid/historical-zone cases were not separately exercised. |
| P6 · Remove commitment help | **STILL_APPLICABLE → corrected/compiled** | Hover with a genuine existing commitment remained unobserved. |

N1–N3 remain bounded observations. Different action roles are not automatically defects; unobserved native states stay unobserved. Native Down Arrow selection and retained selection with Search focus are verified, while a complete tab/hover/accessibility matrix is not claimed.

### Accepted correctness and native evidence

This closure reuses the already completed evidence and explicit owner acceptance. It does not rerun those checks or convert older tests into Sprint-92 proof.

| Evidence | Result and exact limit |
| --- | --- |
| Independent current-store comparison | **PASS** on **337 transaction records, one observed native currency, four accepted effect partitions**. Membership, multiplicity, effect classification, domain, currency, exact Money totals, chart handoff and date/coverage context agreed with the accepted unrestricted Transactions presentation. |
| Independent Decimal summation | **PASS** over the eligible reference rows, separately from production Money aggregation. Current-generation readiness, exact adapter partitions and nil preservation also agreed. |
| Comparison method and unchanged boundary | Read-only evaluation in the actual Debug app using already hydrated current stores; no database mutation, financial fixture, private source extraction or derived financial evidence file. Dashboard adapter SHA-256 `60513f8af52f75a99edcb661be3502c485c35b825a4a1b1c472c4ee560348d25` remained unchanged through final render-only normalization/copy/colour corrections. |
| Final Debug | **BUILD SUCCEEDED**, 3.937 seconds, `BuildProject-Log-20260914-143809.txt` under Xcode ActionArtifacts; zero source warnings/errors and zero Issue Navigator issues. Existing App Intents metadata notice only. No closure build. |
| Final executable SHA-256 | `26920d7d71acb154207a80edd08f40ca51f5a72e2548e2d1f1a6faf35722edf4` |
| Final debug dylib SHA-256 | `c8d150855ee2d9e88b45ad0c230716434466b1f2ea85b68284e8c8527939257b` |
| Final Recorded Activity | **1323 × 826** normal window and **1024 × 768**, with exact labels, both section scales, compact metadata/caveat/scale note and responsive placement inspected. |
| Earlier Sprint-92 Dashboard | Wide **1710 × 1073**, intermediate **1024 × 768**, constrained **760 × 640**, with complete observed Money and reachable content. These precede the final Recorded Activity/financial-colour micro-pass; **760 × 640 is not a final-byte pass**. |
| Other ordinary destinations | Transactions normal/selected/Search-focus; Accounts selected card and inspector; genuine Import idle/history (including supported **1180 × 792** minimum); current Salary editor; Settings wide and **760 × 640**. All six received Sprint-92 native inspection, without claiming another six-screen campaign after the final micro-pass. |
| Developer Console | Inspected while already owner-enabled. No profile/log/financial mutation or re-enabling solely for evidence. |
| Saved appearance | Normal quit/relaunch preserved the owner's then-current saved appearance values. Newer owner changes between checkpoints were preserved; no earlier palette/default snapshot was restored. |
| Window restoration | Final window restored to **1323 × 826 at (113, 78)**, verified by native window read and saved frame. Intermittent `-1719` readback failures were resolved with the owner-authorized retry; no new resize campaign during closure. |
| Git/reference hygiene | `git diff --check`, manifest payload size/SHA checks, unchanged reference/branding image bytes and exact scope review passed. Product files are frozen during closure. |
| Regression tests | **SUSPENDED / 0 new regression-test executions** throughout Sprint 92 and closure. The independent presentation comparison was not a regression suite. |

**Genuine unobserved financial shapes:** mixed-currency activity, undated activity and unclassified/missing-effect activity were not observed or manufactured. The actual comparison population had no withheld records or absent expected partitions, so these branches remain unqualified. The check is not a parser/corpus qualification or a substitute for future FW-P2-46 financial qualification.

**Additional native/non-run limits:** no genuine prepared Preview A/B comparison, populated Salary history/long history amounts, genuine commitment hover or complete new Import terminal-state matrix. No regression suite, full TestPlan, Release build, statement corpus, authentic-source campaign, final-byte 760 recheck or whole-app instrumented no-write campaign was run merely for closure. Earlier native captures remain in memory/Chat, outside Git; no private screenshots or financial evidence artifacts are published.

### Presentation reference lesson

All ten surviving archived references were inspected as pixels: Accounts_v1.0, ComponentLibrary_v1.0, Dashboard_v1.0, DesignBoard_v2.0, DesignSystem_v1.0, DeveloperConsole_v1.0, ImportWizard_v1.0, Settings_v1.0, Transactions_v1.0 and AppIcon_v1.0. They remain useful for information density, hierarchy, compact financial tables, module proportions, spacing/rhythm, Money alignment, horizontal-space use, contextual actions, semantic financial colour and useful inspector/detail relationships. The old palette, illustrative financial values and unsupported old modules/actions/navigation are not authority. Current financial meaning and the accepted Sprint-91A appearance system remain authoritative. `UserJourney_v1.0.png` remains intentionally deleted; no Salary_v1.0 asset exists. External HIG/Impeccable installations, detector output or generated design artifacts are not repository payloads.

### Publication scope and ownership

One writer retained the primary worktree; the existing read-only reviewer checked bounded queue closure and residual scope without editing or running validation. The final product diff is confined to nine presentation/project paths. Product path/hash inventory digest (sorted repository-relative path, NUL, SHA-256 and newline): **`a84aa403669e7b430c2e30ed32d390eb8e838a6a73a85d78fd1f63ee778a769d`**. Both new Swift files have application-only Sources membership. No signing, entitlement, configuration, resource or deployment-setting change is included.

<details>
<summary>Exact published product/project paths (9)</summary>

- `ContentView.swift`
- `LedgerForge.xcodeproj/project.pbxproj`
- `Utilities/ImportInstantFormatting.swift`
- `ViewModels/DashboardViewModel.swift`
- `Views/Common/LFInfoRow.swift`
- `Views/Common/LFTheme.swift`
- `Views/DashboardActivityComparisonView.swift`
- `Views/SalaryView.swift`
- `Views/TransactionListView.swift`

</details>

<details>
<summary>Exact documentation/manifest closure paths (15)</summary>

- `Project documents/Archive/Accepted outcomes/Sprints_90-99.md`
- `Project documents/FUTURE_WORK.MD`
- `Project documents/PROJECT_STATE.md`
- `Project documents/SCOPE_DECISIONS.md`
- `Project documents/Sprint roadmap/LedgerForge_Roadmap_Sprints_90-99_Current.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/ASSET_MANIFEST.json`
- `Project documents/UI Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/Inherited_Screens.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/LF-UI-2026-09-R1_SC-05A_Cross_Screen_Conformance_Matrix.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/README.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/SC-02_Transactions.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/SC-03_Dashboard.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/SOURCES.md`
- `Project documents/Work notes/Transaction_and_R1_workflows.md`

</details>

The owner authorizes only the intended Sprint-92 product/documentation commit and normal main push. Local/remote equality, zero ahead/behind and an intended clean worktree are verified after publication; writer ownership is released then. No tag or Sprint-93 execution is included. The published commit containing this record is the ending ref, avoiding a self-referential embedded commit hash.

---

<a id="sprint-91a"></a>
## Accepted Sprint 91A — Dark Appearance and Visual Foundation — 2026-09-14

**OWNER-ACCEPTED** under `SPRINT_91A_DARK_APPEARANCE_AND_VISUAL_FOUNDATION_ACCEPTED`. The owner supplied the coordinator's explicit acceptance/closure/publication instruction and authorized the current task to complete it. Starting published ref: `ee547a46a126426275f5ecddadf13f769f6b1651` on `main`. The commit containing this closure record publishes the accumulated accepted product, icon assets and reconciled documentation together; its Git identity is the Sprint-92 execution baseline. No further visual redesign, runtime campaign or Sprint-92 implementation is included.

### Accepted outcome and preserved state

- Shared modular `LFTheme` roles and reusable panel/control/input/action components own colours, materials, typography, spacing, corners and interaction states. The existing root/theme injection and window/scene identity remain.
- Dark-only local appearance offers 11 shared colour/tint wells, installed font family and semantic hierarchy-size controls, and background/card tint opacity. Changes apply immediately and persist through the existing single UI preference owner. Responsive Settings keeps the existing destination and data/category/developer controls.
- Restore Defaults affects appearance overrides only. The owner's newer live colours, typography and opacity are local user state; they must not be reset, rewritten, or copied into factory defaults during closure. Earlier successful reset demonstrations are evidence, not an instruction to repeat them.
- All six ordinary destinations share Collapse/Expand and consistent sidebar/canvas/header presentation. The accepted title bar retains native traffic lights and sidebar tint. Shared card edges, secondary controls including Clear filters, local focus cues, and coordinated table/scroller corners remain.
- Transactions retains the existing Table, comparator-backed header sorting, selection and focus treatment, exact Money and effect meanings. No filtering, identity, category, source-order or financial aggregation semantics change.
- The owner accepts the current Dashboard visual foundation and truthful compact composition: native-currency bank/card domains and source dates, compact missing-plan treatment, existing funding outputs, three display-only recent rows, genuine import context and the three established routes. No chart or broader analytics is included in 91A.
- Fresh untouched Salary default-zero inputs appear blank; calculated zeroes, entered/saved values and fee behavior remain. The accepted 11-line read-only `isInitialZeroInput` query leaves raw draft, parsing, calculation, update and Save ownership unchanged.
- The repeated shared-header Import Statement action is removed; Import's local chooser/empty-state actions and Dashboard Open Import remain. Import preparation/confirmation/recovery and durable semantics are unchanged.
- The supplied archived `AppIcon_v1.0.png` provides all ten macOS app-icon renditions; the sidebar reads the same application identity. The archived original remains byte-identical, SHA-256 `5593e9ce6ebeed8d564a6a671a4c4bdcf7cd79bcecf9903561fffccf74783aac`.
- The owner intentionally deleted `Project documents/UI Assets/Archived/UserJourney_v1.0.png`. Its deletion is included in publication; it is not an accidental implementation change and must not be restored.

Financial/model, Money/date/effect, Salary calculation/draft/Save, parser/source, repository/provider/hydration, identity and database/migration semantics remain unchanged. **V17**, Swift 6, deployment target, signing/entitlements and the accepted day-change crash correction/regression source are preserved. Appearance preferences are the only newly accepted persistence. **No new ADR or migration.**

### Accepted evidence boundary

This closure reuses the preceding final Debug/native handoff and the coordinator's explicit acceptance. It does not claim fresh execution of those checks.

| Evidence | Accepted result and exact boundary |
| --- | --- |
| Final post-HIG/icon Debug build | BUILD SUCCEEDED; zero source warnings; existing App Intents metadata-extraction notice only. No fresh closure build. |
| Final executable SHA-256 | `734c2423fad9e7253fd0aeb86718930edaa78868baed265c10ea84eca284420a` |
| Compiled Settings source SHA-256 | `8195dad5d3f3f32be0c89d78373e7921c342d707e8e51f92aaf918c611390f8d` |
| Compiled shell source SHA-256 | `5aedc00c96154370eac9e3dcc2e1eec6783b0422a9d4b008960d37f07d1b46f0` |
| Xcode diagnostics | Earlier r34 cleared Issue Navigator and affected source-editor diagnostics to zero; final targeted build had zero source warnings. No fresh editor scan claimed. |
| Appearance persistence | Normal quit/process exit and same-product relaunch restored the complete saved appearance snapshot. Later owner changes were left intact; no reset during closure. |
| Icon identity | Final bundle signature and ten rendition dimensions verified; native sidebar identity observed. Direct Dock pixels are a separate unobserved case. |
| Final native views | Settings and Dashboard at 1440 × 900; Transactions selected record with table focus versus Search focus. |
| Earlier r34 responsive Settings | 1440 × 900, 1024 × 768 and 760 × 640 observed; earlier intermediate 1200 × 850 reflow observation belongs to its own bytes. |
| Financial mutation boundary during review | No financial Save, import confirmation or category mutation used for visual inspection. No final-byte instrumented no-write campaign is claimed. |
| Regression tests | **SUSPENDED / 0 new executions** in the appearance continuation and this closure; no inferred new pass/fail/skip result. Earlier pre-suspension evidence remains historical. |
| Other non-runs | No final-byte optimized Release, full TestPlan, parser/corpus, financial-oracle or crash-negative-control campaign. |

**FINAL_BYTE_SMALL_WINDOW_NATIVE_RECHECK_NOT_COMPLETED — accepted bounded verification limitation.** Exact final post-HIG/icon bytes were not reverified at 1024 × 768 or 760 × 640 after AppleScript repeatedly returned zero LedgerForge windows / invalid index `-1719`. The final targeted 1140 × 800 intermediate check also remains unverified. Earlier r34 responsive observations are not converted into PASS on the final bytes. The owner explicitly accepts moving forward; no repeat resize campaign is authorized by this closure. Final saved frame was 1710 × 1073 after normal quit/relaunch, matching starting size; final AppleScript position readback was unavailable.

Hover and direct Dock pixels remain **NOT_OBSERVED**. Developer Console was not observed in the final build because Developer Mode remained off; the Transactions filter-popover pixels were not visually verified in the earlier shared-theme pass. Additional currencies, populated/partial saved funding, active imports, malformed preference payloads, all installed families/font extremes and the extreme-value horizontal-scroll branch remain unobserved. No records or states were manufactured. These limitations do not become passes through owner acceptance.

### Closure review and publication scope

A fresh read-only Terra/high review found no publication blocker in the accumulated product diff: one UI preference store, accepted Salary presentation query, preserved financial/source/migration/day-change boundaries, exact new source membership and ten icon slots. This is source review, not fresh native or financial qualification. Closure edits are confined to current documentation owners and manifest alignment; accepted product/project/icon bytes are retained unchanged.

The candidate has **52 paths**: **35 product/project/icon paths**, **16 documentation/manifest paths**, and the **one intentional archived image deletion**. The two new Swift sources have application Sources membership; design-reference payloads remain outside the app's resource membership. Private captures, source financial content, external skill installations and temporary design-tool artifacts are excluded.

Product path/hash inventory digest (SHA-256 over sorted repository-relative path, NUL, file SHA-256 and newline): `91105c5aa0224e7efff5b353d3e1eb37f15dac62599600ac6e95d4c4f802a3eb`.

<details>
<summary>Exact published product/project/icon paths (35)</summary>

- `AppShellPresentation.swift`
- `Assets.xcassets/AppIcon.appiconset/AppIcon_128x128@1x.png`
- `Assets.xcassets/AppIcon.appiconset/AppIcon_128x128@2x.png`
- `Assets.xcassets/AppIcon.appiconset/AppIcon_16x16@1x.png`
- `Assets.xcassets/AppIcon.appiconset/AppIcon_16x16@2x.png`
- `Assets.xcassets/AppIcon.appiconset/AppIcon_256x256@1x.png`
- `Assets.xcassets/AppIcon.appiconset/AppIcon_256x256@2x.png`
- `Assets.xcassets/AppIcon.appiconset/AppIcon_32x32@1x.png`
- `Assets.xcassets/AppIcon.appiconset/AppIcon_32x32@2x.png`
- `Assets.xcassets/AppIcon.appiconset/AppIcon_512x512@1x.png`
- `Assets.xcassets/AppIcon.appiconset/AppIcon_512x512@2x.png`
- `Assets.xcassets/AppIcon.appiconset/Contents.json`
- `ContentView.swift`
- `Core/LFConsoleButton.swift`
- `ImportCentreFooterRenderer.swift`
- `LedgerForge.xcodeproj/project.pbxproj`
- `LedgerForgeApp.swift`
- `ViewModels/SalaryWorkspaceViewModel.swift`
- `Views/AppearanceSettingsView.swift`
- `Views/CategoryManagementView.swift`
- `Views/Common/LFActionRow.swift`
- `Views/Common/LFAppearancePreferences.swift`
- `Views/Common/LFEmptyState.swift`
- `Views/Common/LFFilterChip.swift`
- `Views/Common/LFIconTile.swift`
- `Views/Common/LFInfoRow.swift`
- `Views/Common/LFInlineBadge.swift`
- `Views/Common/LFPanel.swift`
- `Views/Common/LFStatusBadge.swift`
- `Views/Common/LFTheme.swift`
- `Views/DeveloperConsoleView.swift`
- `Views/DeveloperDatabaseProfileWarningView.swift`
- `Views/ImportCentreBatchViews.swift`
- `Views/SalaryView.swift`
- `Views/TransactionListView.swift`

</details>

<details>
<summary>Reconciled/published documentation and intentional deletion (17)</summary>

- `Project documents/Archive/Accepted outcomes/Sprints_90-99.md`
- `Project documents/FUTURE_WORK.MD`
- `Project documents/PROJECT_STATE.md`
- `Project documents/SCOPE_DECISIONS.md`
- `Project documents/Sprint roadmap/LedgerForge_Roadmap_Sprints_90-99_Current.md`
- `Project documents/UI Assets/Archived/UserJourney_v1.0.png` — intentional owner deletion
- `Project documents/UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/ASSET_MANIFEST.json`
- `Project documents/UI Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/DESIGN_TOKENS.json`
- `Project documents/UI Assets/LF-UI-2026-09-R1/Inherited_Screens.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/LF-UI-2026-09-R1_SC-05A_Cross_Screen_Conformance_Matrix.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/README.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/SC-01_App_Shell.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/SC-03_Dashboard.md`
- `Project documents/UI Assets/LF-UI-2026-09-R1/SOURCES.md`
- `Project documents/Work notes/Transaction_and_R1_workflows.md`

</details>

`apple-hig` and Impeccable remain external tools, not product dependencies. The accepted handoff records 156 HIG references and a user-wide Impeccable install/smoke verification whose temporary artifacts were rolled back to the pre-smoke repository state. No launcher/detector/browser output is native SwiftUI acceptance evidence, and no external skill payload or parallel PRODUCT.md/DESIGN.md authority is added here.

### Disposition and Sprint 92 handoff

**FW-P2-52 is completed**, with FW-P2-55's consolidation retained in [SCOPE_DECISIONS](../../SCOPE_DECISIONS.md#fw-p2-52). **FW-P2-48 and FW-P2-50 remain open** for actual cross-screen residue; no broad item is closed by a partial slice. Original Sprint-91 System/Light appearance is **SUPERSEDED HISTORY**. **FW-P2-49: NOT REQUIRED-DO NOT CONSIDER. PERSONAL-V1: NOT YET ADOPTED.**

**Sprint 92: NEXT / NOT STARTED.** Its exact baseline is the published commit containing this closure, not `ee547a46…`. Refresh SC-05A and consume the [forward handoff](../../Work%20notes/Transaction_and_R1_workflows.md#sprint-92-handoff). The original five-item queue and owner-requested v1 information-presentation direction remain; FW-P2-46 chart work stays a separately selected bounded slice with independent genuine-data verification required. No broad analytics, inferred spending/income/expenses, hidden FX, invented net worth, financial fixtures or Sprint-93 work is authorized here. The 93–100 sequence is unchanged.

---

<a id="sprint-90"></a>
## Accepted Sprint 90 — R1 Dashboard Native-Currency Hierarchy — 2026-09-12

**ACCEPTED** at implementation commit `619c39ec07402a63c90b646cbba9ced806f5e99d`, `feat: implement Sprint 90 dashboard hierarchy`, under Chat token `SPRINT_90_DASHBOARD_NATIVE_CURRENCY_HIERARCHY_ACCEPTED`. Parent baseline: `5b10baa33db653c0c8a263d7acb0805a17be628a`. The five-path candidate was normally committed and pushed with local main, origin/main and live remote converged and no local residue. This documentation closure records accepted evidence without rerunning executable, native, database or source validation.

### Accepted implementation boundary

The implementation changed exactly five paths:

- `AppShellPresentation.swift`
- `ContentView.swift`
- `ViewModels/DashboardViewModel.swift`
- `LedgerForgeTests/DashboardViewModelTests.swift`
- `LedgerForge.xcodeproj/project.pbxproj`

Dashboard now presents repository-backed position grouped by native currency. Bank balances and card liabilities remain separate financial domains, with no cross-currency combined total or hidden FX. Bank selection retains accepted source-backed latest-running-balance semantics, including same-document source order and unavailable ambiguous cross-document ties. Cards retain accepted source statement amount-owed semantics rather than the sign-inverted runtime account balance. Incomplete member positions remain visible and fail closed; they do not silently disappear into a complete total.

Authoritative source/as-of days are shown where available. A missing source day remains `Date unavailable`; source month or period can be shown separately without inventing a day. Saved current-month Salary/Funding results reuse `FundingPlanCalculator`, with no formula duplication or automatic plan creation. Affected missing planner outputs remain unavailable rather than zero.

Recent Activity reuses accepted Sprint-89 transaction presentation and order, with three read-only rows. Import Activity uses genuine current workflow or latest durable Import state; hydration is not an import. Attention appears only from an existing explicit review-required route, with no fabricated count. The approved Dashboard actions are exactly **View Transactions**, **Open Import** and **Open Salary**. Observation and navigation perform no financial/database writes.

### Calendar-day crash discovery and bounded correction

The first Sprint-90 candidate exposed a real Swift-concurrency crash: Foundation delivered `NSCalendarDayChanged` on a background queue, and an actor-isolated mapping closure ran before the downstream scheduler hop. Swift executor checking trapped with `EXC_BREAKPOINT / SIGTRAP`.

The correction makes delivery reach the main run loop before the first actor-isolated notification closure: **notification publisher → `receive(on: RunLoop.main)` → `map` → existing refresh pipeline**. Main-actor isolation and existing month refresh remain intact. No sleep/wake observers, polling, timers, generic notification framework or unsafe isolation escape were added. Lid closure, sleep and wake were **not established as causes**.

The source-independent regression `backgroundCalendarDayNotificationRefreshesThroughMainActorAfterInitialEmissionsDrain` drains the initial store emissions, crosses a primitive month boundary, posts the notification from a verified background queue and checks refresh through a main-actor assertion. Against faulty ordering it reproduced the original trap: **1 definition / 1 execution / 1 expected crash / 0 skips**. It passed after the correction. This does not certify populated saved-plan rollover when no such plan exists in the Current Database.

### Accepted validation evidence

- **Focused tests:** 26 definitions / 26 executions / 26 passed / 0 failures / 0 skips: 9 Dashboard tests and 17 Transactions regressions. Coverage includes independent Current Database projection, bank/card separation, native-currency grouping, state handling, source/as-of semantics, Salary/Funding mapping, routes, Import Activity, Attention projection, shell sizing/rail and the background calendar-day regression.
- **Independent database check — PASS:** Current Database opened read-only, ordinary repository hydration used, Dashboard projection independently compared in memory. No financial oracle/evidence artifact was written to disk.
- **No-write — PASS:** database bytes, WAL bytes and SQLite `data_version` remained unchanged across Dashboard rendering, scrolling, responsive resizing and Dashboard → Transactions/Import/Salary → Dashboard round trips.
- **Builds — PASS:** final Debug and optimized Release, Swift 6 preserved, no new Sprint-90 source warnings/errors; only the existing App Intents metadata notice remained.
- **Bundle containment — PASS:** final Debug and Release bundles contained no R1/UI design reference files.
- **Fresh post-crash-fix Sol review:** SHIP / no actionable findings; its conditional build, native and no-write gates were subsequently completed.
- **Full TestPlan — NOT_RUN:** the final change remained bounded Dashboard presentation plus selected-destination shell implementation and one notification-delivery correction. No recorded full-suite trigger or unexplained cross-area failure was present.

The owner-approved project-file change removed one orphaned UI Assets exclusion-set object with zero incoming references. Semantic comparison found no added objects and no changed surviving objects; UI Assets remained outside native targets, and final Debug/Release bundle containment passed. The project file is unchanged by this documentation closure.

### Accepted native verification

| Window size | Result |
| --- | --- |
| 1440 × 900 | PASS |
| 1024 × 768 | PASS |
| 768 × 768 | PASS |
| 640 × 768 | PASS |

The constrained checks covered bank/card hierarchy, complete Money and visible native currency, source/as-of text, the four Salary/Funding rows, Recent Activity, Import Activity, authoritative Attention omission/current behavior, one primary Dashboard scroll, constrained icon rail and absence of clipping/overlap. Dashboard → Transactions passed and settled at the accepted 1024 × 768 layout; Dashboard → Settings passed and restored Settings' accepted larger minimum. All three approved Dashboard actions reached their correct destinations.

Ordinary keyboard acceptance confirmed a distinct visible focus ring and Space activation for **View Transactions**, **Open Import** and **Open Salary**, using **Shift+Tab traversal**. No broader forward-Tab behavior is claimed. Keyboard Navigation was restored to **OFF** and verified before publication. Temporary system-verification permissions expired after their checks; they are neither product behavior nor standing authorization.

### Accepted limitations and disposition

**NOT_OBSERVED, not failures:** mixed-native-currency Current Database shape; a populated saved current-month Salary/Funding plan; populated saved-plan month rollover. A genuine absent card source day was observed and correctly displayed as `Date unavailable`. No synthetic financial data was created to fill missing cases.

**FW-P2-78 is completed** and removed from the open queue, with its ID permanently retained in [SCOPE_DECISIONS](../../SCOPE_DECISIONS.md#fw-p2-78). FW-P2-48/50 retain cross-screen work beyond the necessary accepted Dashboard portion. FW-P2-52 remains the next prepared Appearance candidate, with its unresolved entry review intact. Sprint 91 remains **PREPARED / NOT YET CHAT-AUTHORIZED**, unimplemented and unaccepted. SC-04 A/B/C remain owner-curated, Chat-approved, published and unimplemented. SC-05A remains the accepted audit to refresh after Sprint 91 before Sprint-92 implementation; P1–P6 are not consumed by this closure.

**V17 unchanged. No V18. No new ADR. ADR-046 remains current parser/source authority. No parser/source change. No persistence/schema change. FW-P2-49 remains NOT REQUIRED-DO NOT CONSIDER. Sprint 92 remains unimplemented. PERSONAL-V1 remains NOT YET ADOPTED.**
