# Accepted outcomes — Sprints 90-99

Accepted evidence by cycle, not execution authority. [Current state](../../PROJECT_STATE.md) owns the accepted product snapshot; the [current roadmap](../../Sprint%20roadmap/LedgerForge_Roadmap_Sprints_90-99_Current.md) owns numbering. Ordering inherits [Guide rule F](../../Project_Guide.md#documentation-order): known acceptance dates descending, then recorded acceptance sequence or natural sprint ID descending. Earlier cycle records retain their original evidence and limitations.

## Index

- [Accepted Sprint 91A — Dark Appearance and Visual Foundation — 2026-09-14](#sprint-91a)
- [Accepted Sprint 90 — R1 Dashboard Native-Currency Hierarchy — 2026-09-12](#sprint-90)

**Current alignment — 2026-09-14:** the owner accepts Sprint 91A's accumulated visual foundation and dark-only local customizable appearance, including the current Dashboard composition, with the bounded final-byte small-window limitation below. Original Sprint-91 System/Light planning is superseded history. The 2026-09-13 visual qualification and earlier 91A checkpoints remain in the [working history](../../Work%20notes/Transaction_and_R1_workflows.md#sprint-91a-visual-conformance). The original Sprint-90 record below is preserved, including its then-current forward planning; those historical future-status statements do not override this acceptance.

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
