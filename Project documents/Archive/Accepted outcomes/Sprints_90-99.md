# Accepted outcomes — Sprints 90-99

Accepted evidence by cycle, not execution authority. [Current state](../../PROJECT_STATE.md) owns the accepted product snapshot; the [current roadmap](../../Sprint%20roadmap/LedgerForge_Roadmap_Sprints_90-99_Current.md) owns numbering. Ordering inherits [Guide rule F](../../Project_Guide.md#documentation-order): known acceptance dates descending, then recorded acceptance sequence or natural sprint ID descending. Earlier cycle records retain their original evidence and limitations.

## Index

- [Accepted Sprint 90 — R1 Dashboard Native-Currency Hierarchy — 2026-09-12](#sprint-90)

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
