# LedgerForge Roadmap: Sprints 90–99

**Status:** CURRENT CYCLE / NUMBERING AUTHORITY. Sprint 90 remains accepted; the owner accepted **Sprint 91A — R1 Visual Foundation + Dashboard Visual Conformance**, including dark-only local customizable appearance, on 2026-09-14. Sprints 80–89 remain complete history. Original Sprint-91 System/Light planning is **SUPERSEDED HISTORY**. Sprint 92 is **ACCEPTED**, 2026-09-14; Sprint 93 is **NEXT / NOT STARTED**.
**Prepared:** 2026-09-09; realigned by explicit user decisions through 2026-09-11; current-cycle transition recorded after Sprint-90 acceptance on 2026-09-12.
**Accepted product baseline:** see [PROJECT_STATE](../PROJECT_STATE.md); documentation publication is not product acceptance.
**Prior completed cycle:** [Sprints 80–89](LedgerForge_Roadmap_Sprints_80-89_Current.md).
**PERSONAL-V1: NOT YET ADOPTED.**

This roadmap records accepted Sprints 90, 91A and 92 and the prepared remaining sequence. Sprint 91A includes the subsequently accepted dark-only appearance/Settings work under the owner's explicit identifier; numbering remains unchanged. The roadmap itself authorizes no prepared implementation, accepts no proposed architecture and allocates no ADR or migration number. Before selecting each future sprint, Chat must apply the Private Personal App Scope Gate, then rerun P0 → P1 → P2 → P3 triage only for eligible owner needs, enforce exact entry gates and revalidate the implementation split against accepted post-Swift-6 ownership. A verified higher-priority correctness defect preempts a lower-priority outcome unless explicitly deferred; unmet dependencies do not silently cascade sprint numbers.

## Governing source and financial rules

The complete registered authentic corpus remains authority for statement-dependent work. No synthetic/generated/sanitized/reconstructed/reduced/mutated/hand-authored financial statement is permitted at any stage. Exact support never generalizes from institution, format or layout similarity; production output is never its own sole oracle; private gates fail closed; material corrections invalidate affected prior green evidence; and acceptance is tied to the exact candidate. Missing authentic cases remain uncertified.

## Explicit personal-adoption plan — 2026-09-10

The user fixes [Sprint 100 — LedgerForge 1.0 Personal Adoption Verification](Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md#sprint-100--ledgerforge-10-personal-adoption-verification) after the accepted pre-100 product boundaries. This supersedes the earlier instruction to retain the former 93–99 positions and the earlier statement that current FX/net-worth was not an adoption prerequisite.

Required outcomes include accepted Swift 6 and selected R1/native UI, verified backup/restore, existing Qatar Airways Salary actuals and Salary History, the current This Month planner with bounded current Al Dar reference use and manual override, current holdings and valuation sufficient for the owner's present holdings, current market FX/net-worth reporting, private supported-source matrix and the final Chat adoption matrix. Exact scope and architecture remain gated; assigning a position does not promote a queue status or make every expansion on a broad card required.

Complete structured export remains optional. Historical FX, historical Al Dar, investment history/performance, tax lots, realized P/L, TWR/IRR, corporate-action reconstruction and generic brokerage transaction ingestion are not required merely to establish current holdings. Transfer matching, reconciliation, rule/merchant/recurrence automation and personally useful analytics are eligible only for an actual selected owner workflow or verified correctness need. Generalized platform categories are **NOT REQUIRED-DO NOT CONSIDER** under the [canonical scope register](../SCOPE_DECISIONS.md#rejected-private-personal-scope), not future candidates.

## Current cycle overview

Order inherits [Guide rule E](../Project_Guide.md#documentation-order): sprint number ascending; readiness does not reorder the sequence.

| Sprint | Outcome | Queue | Entry / planning boundary |
|---|---|---|---|
| 90 | R1 Dashboard Native-Currency Hierarchy | Completed `FW-P2-78` | **ACCEPTED**, `619c39ec07402a63c90b646cbba9ced806f5e99d`; [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-90) |
| 91 | R1 Simple Appearance Choice | `FW-P2-52` | **SUPERSEDED PLANNING**; historical System/Light/Dark direction replaced by the explicit dark-only continuation in 91A |
| 91A | R1 Visual Foundation + Dashboard Visual Conformance | completed `FW-P2-52` + bounded `FW-P2-48` | **ACCEPTED**, 2026-09-14; [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-91a), including final-byte small-window verification limitation |
| 92 | Information Presentation and R1 Cross-Screen Polish | Completed `FW-P2-40/41/47/50`; bounded `FW-P2-46/48` | **ACCEPTED**, 2026-09-14; [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-92), with genuine-state and final-byte width limits preserved |
| 93 | Verified Backup, Restore and Disaster Recovery | `FW-P3-36` | **NEXT / NOT STARTED**; PRE_V1_REQUIRED; accepted user-owned backup/restore architecture and independent restore drill |
| 94 | Salary / This Month Current Al Dar Planning Completion | bounded `FW-P3-08` | PRE_V1_REQUIRED current planning slice; explicit ADR-045 alignment or successor architecture, access/permission/freshness/amount binding |
| 95 | Current Investment Domain and Identity Foundation | bounded `FW-P3-20`, `FW-P3-21`, `FW-P3-23` | Container/instrument identity, scoped identifiers, native currency, exact Decimal quantities and current ownership/revision architecture |
| 96 | Current Holdings, Cost-Evidence and ISP Positions | bounded `FW-P3-20`, `FW-P3-21`, `FW-P3-29`, selected fallback `FW-P3-28` | Accepted identity, genuine current owned units/dates/provenance and typed cost evidence; no lots/performance inference |
| 97 | Current Investment Valuation Providers | bounded `FW-P3-27`, selected fallback `FW-P3-28` | Exact provider/instrument/currency/date qualification and automation/cache permission; valuation never establishes ownership |
| 98 | Integrated Current Portfolio and Investment Acceptance | bounded accepted outputs of `FW-P3-20`, `FW-P3-21`, `FW-P3-23`, `FW-P3-27`, `FW-P3-28`, `FW-P3-29` | Accept integrated 95–97 current holdings/valuation; final PRE_V1_REQUIRED investment outcome; history/performance excluded |
| 99 | Current Market FX and Net-Worth Reporting | `FW-P3-26`, bounded `FW-P3-30`, `FW-P3-31`, `FW-P3-33` | PRE_V1_REQUIRED current membership/valuation, direct INR→USD and QAR→USD, reporting choice and incomplete-state contract; historical `FW-P3-32` deferred |

## Accepted and prepared Sprint details

<a id="sprint-90"></a>
### Sprint 90 — R1 Dashboard Native-Currency Hierarchy

**ACCEPTED on 2026-09-12** at `619c39ec07402a63c90b646cbba9ced806f5e99d` under `SPRINT_90_DASHBOARD_NATIVE_CURRENCY_HIERARCHY_ACCEPTED`; completed `FW-P2-78`. Parent baseline: `5b10baa33db653c0c8a263d7acb0805a17be628a`.

Accepted repository-backed native-currency position keeps bank balances and card liabilities separate, without cross-currency totals or hidden FX. Source/as-of context and unavailable positions/days remain truthful; saved current-month Salary/Funding reuses the existing calculator. Recent Activity preserves Sprint-89 projection/order and read-only rows, Import Activity uses genuine current/durable state, and Attention requires an explicit current review-required route. Only View Transactions, Open Import and Open Salary are approved Dashboard actions.

Chat accepted 26 focused definitions/executions (9 Dashboard + 17 Transactions), all passed with zero failures/skips; independent read-only in-memory Current Database comparison; no-write comparison; Debug/optimized Release; bundle containment; and fresh post-fix Sol review. Native 1440 × 900, 1024 × 768, 768 × 768 and 640 × 768 layouts, constrained rail, Transactions/Settings transitions and ordinary focus/Space activation using Shift+Tab passed. Full TestPlan was NOT_RUN for the bounded scope and absence of a recorded full-suite trigger or unexplained cross-area failure.

The first candidate's background calendar-day notification reached an actor-isolated map before scheduling on main and trapped. Moving `receive(on: RunLoop.main)` before that map corrected it; a source-independent background-post/month-boundary regression reproduced the faulty ordering and passed after correction. Lid/sleep/wake causation was not established.

Mixed-native-currency Current Database shape, a populated saved current-month plan and populated saved-plan rollover remain **NOT_OBSERVED**. A genuine missing card source day correctly showed `Date unavailable`. No migration or new ADR; V17, ADR-046 and PERSONAL-V1 NOT YET ADOPTED remain unchanged. The [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-90) owns complete evidence and limitations.

### Sprint 91 — R1 Simple Appearance Choice

**SUPERSEDED PLANNING — 2026-09-14.** The following original plan is retained as history. The owner replaced its System/Light choices with the [dark-only scope](../SCOPE_DECISIONS.md#dark-appearance-decision) in Sprint 91A; it is not a separate feature still to build.

Queue: narrowed [FW-P2-52](../SCOPE_DECISIONS.md#fw-p2-52) only.

Implement Follow System, Light and Dark with optional already-approved Deep Indigo/accent direction and simple device-local persistence. Verify ordinary readable rendering and remembrance after relaunch without financial writes. No theme engine, preference portability, formal qualification or automatic new-ADR gate. If implementation exposes a real architecture decision, return to Chat before widening scope.

### Sprint 91A — R1 Visual Foundation + Dashboard Visual Conformance

**ACCEPTED on 2026-09-14** under `SPRINT_91A_DARK_APPEARANCE_AND_VISUAL_FOUNDATION_ACCEPTED`. Starting baseline: `ee547a46a126426275f5ecddadf13f769f6b1651`; the commit containing the [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-91a) publishes the final candidate and this closure. Completed [FW-P2-52](../SCOPE_DECISIONS.md#fw-p2-52) and the bounded shared-foundation/Dashboard slice of [FW-P2-48](../FUTURE_WORK.MD#fw-p2-48). Numbering is unchanged.

Accepted shared theme/panel/shell materials and current Dashboard composition preserve financial/source semantics, complete native Money, membership/source dates, Salary calculations and the day-change crash correction. The accumulated outcome includes dark-only colour/tint, family/hierarchy-size and background/card-opacity preferences, immediate local persistence and responsive Settings; all-six Collapse/Expand; seamless title-bar/sidebar tint and shared card/control/table finishing; Transactions selection/focus/header sorting; blank untouched-default-zero Salary inputs; removal of the repeated shared-header Import Statement action; and the supplied application/sidebar icon. Current saved overrides remain user state and do not redefine factory defaults. No financial persistence, parser, migration, new ADR or deployment-target change is included.

The [working history](../Work%20notes/Transaction_and_R1_workflows.md#sprint-91a-visual-conformance) retains the earlier checkpoints and Sprint-90 qualification. Final Debug succeeded with zero source warnings and only the existing App Intents notice; final Settings/Dashboard 1440 × 900, Transactions focus/selection, preference relaunch and icon evidence are accepted. **FINAL_BYTE_SMALL_WINDOW_NATIVE_RECHECK_NOT_COMPLETED** is an owner-accepted limitation: earlier r34 small-window evidence is not a pass on final post-HIG/icon bytes. Do not restart resizing. Regression tests remain **SUSPENDED / 0 new executions**. The owner explicitly authorizes intended product/docs/icon publication and the intentional UserJourney deletion; no further implementation is selected by closure.

### Sprint 92 — Information Presentation and R1 Cross-Screen Polish

**ACCEPTED — 2026-09-14**, under `SPRINT_92_INFORMATION_PRESENTATION_AND_R1_POLISH_ACCEPTED`, from published `main@3f1e7e97d5cac0ba9f1c3010ae8c30a79d106c96`. The owner accepts the final native presentation following `SPRINT_92_FINAL_VISUAL_REVIEW_READY` and explicitly authorizes product/documentation publication. [The accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-92) owns exact product paths, final Debug/binary identity, independent comparison, native widths, unobserved cases and non-runs. No further visual, financial, preference or test change is part of closure.

Original owners FW-P2-40/41/47/48/50 were reconciled against actual work. The selected terminology, contextual-action conformance, truthful Import completion and useful keyboard needs are complete under **FW-P2-40/41/47/50**. FW-P2-48's selected R1/layout/Money/copy/colour scope is accepted, with only unselected Import Preview A/B placement retained for a genuine prepared state and later owner selection/native review. No hypothetical full tab/hover or accessibility campaign is created.

The additional **FW-P2-46** slice presents all recorded Bank inflow/outflow and Card increase/decrease owed, with exact Money and separate native currencies. Each Bank/Card section normalizes against its own largest magnitude; physical bar lengths across domains are not comparable. Count/date/currency metadata derives from genuine presenter state. The compact coverage/movement caveat and scale note are accepted. Broader interactive charts remain open; no inferred spending/income/expenses/cash-flow/net-worth/transfers/categories/trends/forecasts are authorized. The bounded read-only comparison and independent Decimal sums agreed for the observed current snapshot; mixed-currency, undated and missing-effect cases remain unobserved.

SC-05A was refreshed against accepted 89–91A: P1 is resolved by prior work; P2–P6 were applicable and corrected, with source/compiled-only versus native evidence retained per finding. Import event times use the owner-selected Mac-local display with an explicit UTC offset and “Time unavailable” fallback, separate from financial civil dates. All ten surviving archived references informed information architecture; old palette/sample values/unsupported actions are not authority and UserJourney remains intentionally deleted.

Final Recorded Activity was inspected at **1323 × 826** and **1024 × 768**, then restored to its starting frame. Earlier six-destination/Developer Console and 760 × 640 evidence is tied to its own bytes. **Regression tests remained SUSPENDED / 0 new executions**; closure runs no new build/native/financial/source campaign. Sprint 93 remains **NEXT / NOT STARTED**, with the 93–100 sequence unchanged.

### Sprint 93 — Verified Backup, Restore and Disaster Recovery

Primary queue: [FW-P3-36](../FUTURE_WORK.MD#fw-p3-36). **NEXT / NOT STARTED. PRE_V1_REQUIRED.**

Implement only the subsequently approved user-owned backup/restore contract. Architecture must settle backup contents, integrity manifest, SQLite/WAL/SHM-consistent snapshot, compatibility/version policy, isolated restore verification, non-empty-current-data protection, explicit confirmation, rollback if activation fails, canonical hydration and same-database relaunch. The owner may save/copy a verified package to a personally chosen destination. This does not create sync, live portable workspace or cloud integration. Appearance stays device-local; no theme preference snapshot is required. Reporting currency remains separate financial configuration.

The [backup/restore packet](../Work%20notes/Backup_and_export.md#packet-user-backup-restore-architecture-packet) retains the unresolved architecture and genuine restore-drill requirements. Complete structured export is optional and separate. A roadmap position does not establish recoverability.

### Sprint 94 — Salary / This Month Current Al Dar Planning Completion

Primary queue: bounded [FW-P3-08](../FUTURE_WORK.MD#fw-p3-08). **PRE_V1_REQUIRED for this current Salary/budget slice only.**

Complete the existing personal planning workflow with current/live Al Dar QAR→INR reference evidence and an explicit manual current-rate override. Do not rebuild Salary: accepted Qatar Airways actuals, Salary History, current-month plan, commitments, selected balances, separate fee behavior, underfunding/rounding safety and calculations remain authoritative.

Intended flow: current/provisional QAR send amount → current amount-bound Al Dar reference quote → approved Salary/This Month estimate → explicit manual current-rate override. Preserve amount binding, provider/source/fetch context, truthful stale/unavailable state and explicit user control. Al Dar is not general LedgerForge FX or net-worth authority.

**REQUIRES EXPLICIT ADR-045 ALIGNMENT OR SUCCESSOR ARCHITECTURE** before implementation, plus the Al Dar access/permission/freshness/amount-binding decision and exact post-Swift-6 ownership review. Current production retains the accepted user-entered planning-rate contract until that future gate is accepted. Exclude historical Al Dar/QAR→INR, forecast month-end rates, guaranteed settlement, automatic remittance execution, automatic fee inference, reverse-rate inference and universal 1-QAR/table-rate assumptions. Broad cross-employer Salary/planning expansion remains outside this sprint.

### Sprint 95 — Current Investment Domain and Identity Foundation

Primary candidates: bounded [FW-P3-20](../FUTURE_WORK.MD#fw-p3-20), [FW-P3-21](../FUTURE_WORK.MD#fw-p3-21) and [FW-P3-23](../FUTURE_WORK.MD#fw-p3-23).

Settle and implement the selected container/instrument identity, scoped identifiers, native currency, exact Decimal quantity semantics and current position ownership/revision architecture. Exact genuine owner/source evidence and Chat architecture acceptance remain entry gates. Current holdings come first; generic brokerage ingestion and transaction-history reconstruction are not prerequisites merely to establish positions.

The [investment architecture packet](../Work%20notes/Holdings_and_valuation.md#packet-investment-holdings-architecture-packet) retains separate evidence, identity, correction and provider blockers. This position does not accept its proposed persistence shape or allocate a migration.

### Sprint 96 — Current Holdings, Cost-Evidence and ISP Positions

Primary candidates: bounded [FW-P3-20](../FUTURE_WORK.MD#fw-p3-20), [FW-P3-21](../FUTURE_WORK.MD#fw-p3-21), [FW-P3-29](../FUTURE_WORK.MD#fw-p3-29), and [FW-P3-28](../FUTURE_WORK.MD#fw-p3-28) only where selected holdings require manual/current entry or fallback.

Consume accepted identity and revision architecture. Establish exact current owned units, explicit effective/observation date, owner/source provenance, typed cost evidence and current Qatar Airways ISP position classes. Keep total-cost-like evidence, average unit cost, contribution allocation and unknown cost distinct. Manual entry follows the approved evidence contract; external prices cannot establish ownership or units. Do not infer lots, performance, missing dates, costs or transaction history.

### Sprint 97 — Current Investment Valuation Providers

Primary candidates: bounded [FW-P3-27](../FUTURE_WORK.MD#fw-p3-27) and selected provider fallback under [FW-P3-28](../FUTURE_WORK.MD#fw-p3-28).

Qualify prospective FE/Zurich adapters for exact adopted ISP identities, AMFI for exact adopted Direct-plan mutual-fund identities, and any other current-price source only after its own provider qualification. Use exact configured identifiers and plan/option metadata; names are secondary and Regular plans cannot substitute for Direct plans. Preserve the existing provider-specific evidence and permission blockers in the owning cards. No legacy workbook multiplier or inferred vesting/performance model becomes valuation authority.

Require exact instrument mapping, native price/NAV currency, actual observation/price date where available, fetched-at time, provider/source identity, freshness and explicit stale/unavailable state. Automation/cache permission must precede automated persistence. Current external valuation is separate from ownership and contributes only the approved derived native market value. Historical performance is not required.

### Sprint 98 — Integrated Current Portfolio and Investment Acceptance

Consume the accepted bounded outputs of Sprints 95–97. This is the **final current-investment outcome required before personal-v1**; the code/persistence split must still be revalidated after Sprint 87 and before selecting each sprint.

Accept coherent current holdings and native-currency market values for current ISP, mutual funds and stock/ETF positions where adopted. Prove container/instrument identity, exact owned units, typed cost evidence, current valuation provenance and truthful unavailable/incomplete states. Where durable state exists, require provider parity, canonical hydration and same-database relaunch. Genuine owner/source facts and independently qualified current price evidence remain distinct acceptance inputs.

Exclude [FW-P3-22](../FUTURE_WORK.MD#fw-p3-22) brokerage transaction ingestion unless independently selected later, trade history, tax lots, performance, realized gains/losses, TWR/IRR and corporate-action reconstruction. Do not make those gates necessary by implication or use the legacy workbook as source truth.

### Sprint 99 — Current Market FX and Net-Worth Reporting

Primary queue: [FW-P3-26](../FUTURE_WORK.MD#fw-p3-26), bounded [FW-P3-30](../FUTURE_WORK.MD#fw-p3-30), [FW-P3-31](../FUTURE_WORK.MD#fw-p3-31) and [FW-P3-33](../FUTURE_WORK.MD#fw-p3-33). **PRE_V1_REQUIRED.** Historical [FW-P3-32](../FUTURE_WORK.MD#fw-p3-32) remains deferred and does not block this current outcome.

Produce current, explainable net-worth estimates after accepted current investments and valuation. Use direct current market INR→USD and QAR→USD evidence, plus any later explicitly accepted current reporting orientation. Native Money remains authoritative; reporting conversion is derived and the user explicitly selects the reporting currency/currencies.

Preserve non-overlapping membership and account/liability/investment distinctions, current observation and fetch timestamps, current/last-success freshness, provider attribution, exact Decimal rates, and deterministic rounding at the approved final Money boundary. Missing/stale balances, holdings, prices or rates make the result explicitly incomplete; never replace missing components with zero or hide them in a complete total.

The [general FX packet](../Work%20notes/Current_FX_and_net_worth.md#packet-general-fx-architecture-packet) still requires provider suitability, permission/cache/freshness, membership, reporting-currency and rounding/orientation decisions. Technical access is not provider qualification; the researched provider's financial-data suitability warning remains unresolved. No history collection or assumed inverse/cross conversion is authorized. Al Dar stays confined to Sprint 94 current Salary/budget QAR→INR evidence and is not net-worth FX authority.

## Displaced outcomes retained as unscheduled post-1.0 candidates

The former 93–97 positions no longer assign the following work. [FUTURE_WORK](../FUTURE_WORK.MD) preserves every existing priority, status, architecture/source blocker and discovery record. No Sprint 101+ number is assigned here.

| Former position | Retained candidates | Remaining boundary |
|---|---|---|
| 93 transfer matching | `FW-P2-10` | Source/architecture-gated reviewable relationships; date/amount/opposite-direction coincidence alone is insufficient |
| 94 reconciliation | `FW-P2-11` | Accepted transfer/provenance/mismatch semantics; reevaluate prospective duplicate review `FW-P2-12` before later reconciliation/analytics |
| 95 categorization rules | `FW-P2-21`, `FW-P2-22`, `FW-P2-23` | POST_V1; manual assignments authoritative; every disagreeing applicable rule remains an explicit conflict, with no silent priority winner |
| 96 merchant/recurrence | `FW-P2-25`, `FW-P2-26` | POST_V1; immutable source descriptions, correction/provenance, independently sufficient recurrence evidence and explicit obligation confirmation |
| 97 broad planning/analytics | `FW-P3-09`, `FW-P3-10` | Separate future projections of facts, user assumptions and derivations; historical analytics/forecasting do not become the accepted Salary current-month planner or Sprint 94 Al Dar completion |

## Other candidates and pre-100 documentation

Existing P0 integrity/identity/reversal candidates and P1 source/duplicate/recovery work remain subject to fresh priority triage, with their current blockers intact. A new verified correctness dependency may preempt this prepared sequence; a roadmap position itself changes no queue status. Only scope-eligible account lifecycle, document retention and bounded local maintenance remain candidates; rejected scope cannot block this cycle.

[FW-P2-79 private supported-source matrix](../FUTURE_WORK.MD#fw-p2-79) is required before Sprint 100, without inventing a numbered implementation sprint here. It must describe the exact accepted supported-source matrix and cumulative authentic corpus accurately. [FW-P3-35 complete structured export](../FUTURE_WORK.MD#fw-p3-35) stays optional unless the user separately promotes it.

## Successor milestone and activation

[Sprints 100–109](Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md) own the fixed future Sprint-100 personal adoption verification milestone. No feature is deliberately deferred into adoption verification. A product defect or missing required capability fails adoption verification and returns to Chat for separate corrective attribution/scheduling; LedgerForge 1.0 remains undeclared until the corrected candidate passes verification. Sprints 101–109 remain unassigned for fresh selection after LedgerForge 1.0.

The 90–99 cycle is current numbering authority following explicit Sprint-90 activation and acceptance. The owner accepted the accumulated Sprint-91A correction and authorized its closure/publication on 2026-09-14. The [completed 80–89 roadmap](LedgerForge_Roadmap_Sprints_80-89_Current.md) retains its historical numbering and accepted outcomes. The original System/Light Appearance plan is superseded by the explicit dark-only 91A continuation. Current-cycle status authorizes no later prepared sprint.

<a id="roadmap-replanning-packets-97-99"></a>
## Earlier replanning evidence — positions superseded, architecture still gated

The following stable anchors retain the relationship to the earlier second-level packets. The explicit 2026-09-10 addendum supersedes their old sprint placements; their source/provider findings and unaccepted architecture remain in the owning FUTURE_WORK packets and Git history. They grant no implementation or architecture acceptance.

<a id="packet-roadmap-replanning-packet-97"></a>
### Former ROADMAP_REPLANNING_PACKET_97 — broad planning and analytics

The proposal to separate current obligations/user-assumption projections from facts-only historical analytics remains unaccepted, unscheduled post-1.0 work under [FW-P3-09](../FUTURE_WORK.MD#fw-p3-09) and [FW-P3-10](../FUTURE_WORK.MD#fw-p3-10). Preserve duplicate/transfer/category/provenance dependencies, independent fact/assumption oracles and the exclusion of forecasts. This is distinct from accepted Salary/This Month and the newly placed Sprint 94 current Al Dar boundary.

<a id="packet-roadmap-replanning-packet-98"></a>
### Former ROADMAP_REPLANNING_PACKET_98 — investment boundaries

The [investment architecture packet](../Work%20notes/Holdings_and_valuation.md#packet-investment-holdings-architecture-packet) preserves the genuine ownership/cost evidence, missing brokerage-source qualification and independent provider permission/date/identity gates. The user now places foundation, current holdings, valuation and integrated acceptance at 95, 96, 97 and 98 respectively. Brokerage ingestion/history/performance remain separately gated and outside the required current outcome. Exact architecture and per-sprint source/persistence splits still need Chat acceptance.

<a id="packet-roadmap-replanning-packet-99"></a>
### ROADMAP_REPLANNING_PACKET_99 — current FX and net worth

The [general FX packet](../Work%20notes/Current_FX_and_net_worth.md#packet-general-fx-architecture-packet) retains the current direct-market evidence and unresolved financial-data suitability, current membership, orientation, rounding, cache/freshness and reporting-setting decisions. The required Sprint-99 queue explicitly includes net-worth owner `FW-P3-26` with bounded `FW-P3-30/31/33`. Historical `FW-P3-32`, historical Al Dar and performance remain non-required. This planning decision changes required adoption scope, not the accepted architecture or provider.

The owner’s [current source-processing decision](../SCOPE_DECISIONS.md#source-processing-decision) governs future financial execution: in-memory source interpretation and independent comparison, no derived financial evidence files on disk, normal app database retained. Existing scripts were not changed or certified against that rule by this documentation task.
