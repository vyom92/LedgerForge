# LedgerForge Roadmap: Sprints 90–99

**Status:** CURRENT CYCLE / NUMBERING AUTHORITY. Sprint 90 remains accepted; the owner accepted **Sprint 91A — R1 Visual Foundation + Dashboard Visual Conformance**, including dark-only local customizable appearance, on 2026-09-14. Sprints 80–89 remain complete history. Original Sprint-91 System/Light planning is **SUPERSEDED HISTORY**. Sprint 92 is **ACCEPTED**, 2026-09-14; Sprint 93 is **ACCEPTED**, 2026-09-15. Sprint 94 is **ACCEPTED**, 2026-09-15, under `SPRINT_94_CURRENT_AL_DAR_AND_THIS_MONTH_PLANNING_ACCEPTED`.
**Post-94 correction status:** ACCEPTED / PUBLISHED, 2026-09-16, under `POST_94_PRE_95_CORRECTIONS_ACCEPTED`; [accepted unnumbered outcome](../Archive/Accepted%20outcomes/Unnumbered_2026-09.md#post-94-pre-95-corrections). Sprint 95 is **ACCEPTED**, 2026-09-16, under `SPRINT_95_BUDGET_PLANNING_AND_SHARED_AL_DAR_ACCEPTED`; [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-95). Shared Al Dar reference ownership is accepted in 95. Sprint 96 is **NEXT / NOT STARTED**.
**Prepared:** 2026-09-09; current-cycle transition recorded after Sprint-90 acceptance on 2026-09-12; remaining sequence realigned by explicit owner/coordinator decision on 2026-09-15.
**Accepted product baseline:** see [PROJECT_STATE](../PROJECT_STATE.md); documentation publication is not product acceptance.
**Prior completed cycle:** [Sprints 80–89](LedgerForge_Roadmap_Sprints_80-89_Current.md).
**PERSONAL-V1: NOT YET ADOPTED.**

This roadmap records accepted Sprints 90, 91A, 92, 93, 94 and 95 and the prepared remaining sequence. Sprint 91A includes the subsequently accepted dark-only appearance/Settings work under the owner's explicit identifier; numbering remains unchanged. The roadmap itself authorizes no prepared implementation, accepts no proposed architecture and allocates no ADR or migration number. Before selecting each future sprint, Chat must apply the Private Personal App Scope Gate, then rerun P0 → P1 → P2 → P3 triage only for eligible owner needs, enforce exact entry gates and revalidate the implementation split against accepted post-Swift-6 ownership. A verified higher-priority correctness defect preempts a lower-priority outcome unless explicitly deferred; unmet dependencies do not silently cascade sprint numbers.

## Governing source and financial rules

The complete registered authentic corpus remains authority for statement-dependent work. No synthetic/generated/sanitized/reconstructed/reduced/mutated/hand-authored financial statement is permitted at any stage. Exact support never generalizes from institution, format or layout similarity; production output is never its own sole oracle; private gates fail closed; material corrections invalidate affected prior green evidence; and acceptance is tied to the exact candidate. Missing authentic cases remain uncertified.

## Explicit personal-adoption plan — 2026-09-10

The user fixes [Sprint 100 — LedgerForge 1.0 Personal Adoption Verification](Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md#sprint-100--ledgerforge-10-personal-adoption-verification) after the accepted pre-100 product boundaries. This supersedes the earlier instruction to retain the former 93–99 positions and the earlier statement that current FX/net-worth was not an adoption prerequisite.

Required outcomes include accepted Swift 6 and selected R1/native UI, verified backup/restore, existing Qatar Airways Salary actuals and Salary History, an accepted **Sprint-95 Budget Planner / This Month** using the QAR-1 indicative Al Dar unit planning reference and manual fallback, current holdings and valuation sufficient for the owner's present holdings, current market FX/net-worth reporting, private supported-source matrix and the final Chat adoption matrix. Sprint-95 planner acceptance is a hard prerequisite for Sprint 100. Exact scope and architecture remain gated; assigning a position does not promote a queue status or make every expansion on a broad card required.

**Settled sequence, 2026-09-16:** 95 Budget Planner → 96 investment identity and current holdings through manually qualified sources → 97 current valuation and integrated current-portfolio acceptance → 98 manual Gmail, combined-bank source support and bounded batch intake → 99 reporting conversion and net worth → 100 personal adoption. Sprint 95 remains unchanged. Compression changes grouping only: prior source, identity, exact-unit, cost, provider, persistence, hydration, reopen and acceptance obligations remain required. The [owner-listed post-94 correction gate](../FUTURE_WORK.MD#post-94-pre-95-corrections) is accepted and published without another permanent sprint number. This adopts future planning, not implementation or architecture.

Complete structured export remains optional. Historical FX, historical Al Dar, investment history/performance, tax lots, realized P/L, TWR/IRR, corporate-action reconstruction and generic brokerage transaction ingestion are not required merely to establish current holdings. Transfer matching, reconciliation, rule/merchant/recurrence automation and personally useful analytics are eligible only for an actual selected owner workflow or verified correctness need. Generalized platform categories are **NOT REQUIRED-DO NOT CONSIDER** under the [canonical scope register](../SCOPE_DECISIONS.md#rejected-private-personal-scope), not future candidates.

## Current cycle overview

Order inherits [Guide rule E](../Project_Guide.md#documentation-order): sprint number ascending; readiness does not reorder the sequence.

| Sprint | Outcome | Queue | Entry / planning boundary |
|---|---|---|---|
| 90 | R1 Dashboard Native-Currency Hierarchy | Completed `FW-P2-78` | **ACCEPTED**, `619c39ec07402a63c90b646cbba9ced806f5e99d`; [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-90) |
| 91 | R1 Simple Appearance Choice | `FW-P2-52` | **SUPERSEDED PLANNING**; historical System/Light/Dark direction replaced by the explicit dark-only continuation in 91A |
| 91A | R1 Visual Foundation + Dashboard Visual Conformance | completed `FW-P2-52` + bounded `FW-P2-48` | **ACCEPTED**, 2026-09-14; [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-91a), including final-byte small-window verification limitation |
| 92 | Information Presentation and R1 Cross-Screen Polish | Completed `FW-P2-40/41/47/50`; bounded `FW-P2-46/48` | **ACCEPTED**, 2026-09-14; [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-92), with genuine-state and final-byte width limits preserved |
| 93 | Verified Backup, Restore and Disaster Recovery | Completed [FW-P3-36](../SCOPE_DECISIONS.md#fw-p3-36) | **ACCEPTED**, 2026-09-15; [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-93), with bounded recovery limits preserved |
| 94 | Salary / This Month Current Al Dar Planning Completion | accepted bounded `FW-P3-08` slice | **ACCEPTED**, explicit QAR-1 unit reference with two-decimal display/full internal precision, separate Use/Save, V18 and exact V17 format-1 bridge; [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-94) |
| 95 | Budget Planning and Shared Al Dar FX | completed selected `FW-P3-08/31`; accepted bounded `FW-P3-09/30`; repaired `FW-P1-40` | **ACCEPTED**, 2026-09-16; V20, format-1 compatibility, independent Amex/Axis proof and retained migration-sequence limit; [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-95) |
| 96 | Investment Identity and Current Holdings | bounded `FW-P3-20`, `FW-P3-21`, `FW-P3-23`, selected `FW-P3-28/29` | Container/instrument/revision identity, scoped identifiers, native currency, exact Decimal units and current holdings through manually qualified sources; prices never establish ownership |
| 97 | Current Valuation and Integrated Current-Portfolio Acceptance | bounded accepted 96 outputs plus `FW-P3-27`, selected `FW-P3-28`, `FW-P3-29` | Independently qualified prices/NAV, then former Sprint-98 integrated acceptance: exact units, typed cost, provenance, provider parity, hydration/reopen and truthful incomplete state |
| 98 | Manual Gmail and Combined-Bank Intake | selected Gmail/combined-bank feasibility; existing Import/source authorities remain binding | Read-only manual Gmail, manually qualified combined HDFC/Axis layouts, bounded preparation and ordered atomic commits; one explicit batch action auto-imports only fully validated/resolved items |
| 99 | Current Reporting Conversion and Net Worth | `FW-P3-26`, bounded `FW-P3-30`, `FW-P3-31`, `FW-P3-33`, `FW-P3-34` | Reuse Sprint-95 shared Al Dar authority; reporting preference, non-overlapping membership, rounding and explicit incomplete results; historical `FW-P3-32` deferred |

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

Original owners FW-P2-40/41/47/48/50 were reconciled against actual work. The selected terminology, contextual-action conformance, truthful Import completion and useful keyboard needs are complete under **FW-P2-40/41/47/50**. FW-P2-48's selected R1/layout/Money/copy/colour scope is accepted, with Import Preview A/B placement then retained for genuine prepared-state review; that remainder is now accepted in the post-94 batch, completing FW-P2-48. No hypothetical full tab/hover or accessibility campaign is created.

The additional **FW-P2-46** slice presents all recorded Bank inflow/outflow and Card increase/decrease owed, with exact Money and separate native currencies. Each Bank/Card section normalizes against its own largest magnitude; physical bar lengths across domains are not comparable. Count/date/currency metadata derives from genuine presenter state. The compact coverage/movement caveat and scale note are accepted. Broader interactive charts remain open; no inferred spending/income/expenses/cash-flow/net-worth/transfers/categories/trends/forecasts are authorized. The bounded read-only comparison and independent Decimal sums agreed for the observed current snapshot; mixed-currency, undated and missing-effect cases remain unobserved.

SC-05A was refreshed against accepted 89–91A: P1 is resolved by prior work; P2–P6 were applicable and corrected, with source/compiled-only versus native evidence retained per finding. Import event times use the owner-selected Mac-local display with an explicit UTC offset and “Time unavailable” fallback, separate from financial civil dates. All ten surviving archived references informed information architecture; old palette/sample values/unsupported actions are not authority and UserJourney remains intentionally deleted.

Final Recorded Activity was inspected at **1323 × 826** and **1024 × 768**, then restored to its starting frame. Earlier six-destination/Developer Console and 760 × 640 evidence is tied to its own bytes. **Regression tests remained SUSPENDED / 0 new executions**; closure runs no new build/native/financial/source campaign. At Sprint-92 closure on 2026-09-14, Sprint 93 was **NEXT / NOT STARTED**, with the 93–100 sequence unchanged; its later acceptance is recorded below.

### Sprint 93 — Verified Backup, Restore and Disaster Recovery

Completed owner: [FW-P3-36](../SCOPE_DECISIONS.md#fw-p3-36). **ACCEPTED — 2026-09-15. PRE_V1_REQUIRED outcome complete.**

The owner/coordinator accepts Sprint 93 under `SPRINT_93_VERIFIED_BACKUP_RESTORE_AND_DISASTER_RECOVERY_ACCEPTED` and accepted [ADR-047](../ADR.md#adr-047), from published `main@7218f536eee5c871243d1170e8db0f4c150728bb`. Closure publishes the unchanged accepted candidate and reconciled documentation; it reruns no product verification. [The accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-93) owns exact executed evidence and unobserved limits.

The approved contract uses a two-member Finder package, SQLite online snapshot, small integrity manifest, strict current migration-chain compatibility, isolated verification, explicit replacement confirmation, preserved-current rollback and receipt-owned activation/relaunch. Debug/Release builds, the genuine native restore drill and selected failure/interruption checks are complete under the bounded authorization. The owner may save/copy a verified package to a personally chosen destination. This does not create sync, live portable workspace or cloud integration. Appearance stays device-local; no theme preference snapshot is required. Reporting currency remains separate financial configuration.

The [backup/restore note](../Work%20notes/Backup_and_export.md#packet-user-backup-restore-architecture-packet) links the accepted architecture and evidence. Complete structured export remains OPTIONAL / NOT SELECTED; backup encryption remains NOT REQUIRED / NOT SELECTED. Appearance stays DEVICE-LOCAL / EXCLUDED FROM BACKUP. Sprint 93 left V17 unchanged and introduced no permanent ledger UUID or V18; the later Sprint-94 additive migration is tracked below. PERSONAL-V1 remains NOT YET ADOPTED.

### Sprint 94 — Salary / This Month Current Al Dar Planning Completion

Primary queue: bounded [FW-P3-08](../FUTURE_WORK.MD#fw-p3-08). **ACCEPTED, 2026-09-15, for this current Salary/budget slice only.** Broader Budget Planner remains Sprint 95.

Complete the existing personal planning workflow with current/live Al Dar QAR→INR reference evidence and an explicit manual current-rate override. Do not rebuild Salary: accepted Qatar Airways actuals, Salary History, current-month plan, commitments, selected balances, separate fee behavior, underfunding/rounding safety and calculations remain authoritative.

Owner-corrected flow: explicit QAR 1 lookup at any time → temporary reference → explicit Use against the current positive INR shortfall → Save; manual planning FX remains an override/fallback. This is a **QAR-1 current Al Dar unit planning reference**, indicative and used to estimate a transfer. Display exactly two decimal places with fetch context, retaining full provider precision and exact application binding internally. It is not an amount-specific transfer quote, settlement authority or general market FX.

**OWNER/COORDINATOR-ACCEPTED** under `SPRINT_94_CURRENT_AL_DAR_AND_THIS_MONTH_PLANNING_ACCEPTED`, from published `main@99f27b376fe6f3a37e6a15f7cd65c5e16a49caed`. [ADR-045](../ADR.md#adr-045) and [ADR-047](../ADR.md#adr-047) retain the exact raw ratio, mutually exclusive manual/external authority, current V18 and exact V17 format-1 isolated backup/receipt bridge. V1–V17 are unchanged. Dashboard planning FX is removed. Typed QAR/INR bank balances, same-currency manual card commitments and saved bank links, blank untouched zeros, actual months, native manual-FX date selection, zero-floored investment availability and the signed final buffer are accepted, along with the measured Dashboard layout correction.

The accepted [outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-94) preserves two verification boundaries: the preceding owner-correction fingerprint passed **567 definitions / 627 executions** ordinary regression and **45/46** focused verification, Debug/optimized Release, owner native verification, genuine mixed INR/QAR observations and unchanged 54-table state. The final two-decimal-only fingerprint passed **1/1** focused display/exact-ratio verification, fresh Debug/optimized Release and native **1 QAR = 26.25 INR** with fetch time; 54 tables and preferences remained unchanged. The ordinary result is accepted retained evidence, not a run against the final display-only bytes or complete authentic/source acceptance. All 17 separately gated definitions remain retained.

The Sprint-94 closure published unchanged accepted product/test bytes without another campaign. Its then-open navigation, Amex and related [post-94 corrections](../FUTURE_WORK.MD#post-94-pre-95-corrections) are now accepted and published as an unnumbered batch. Their exact evidence, attribution and limitations remain in the accepted outcome. The settled Budget Planner, investment and market-FX sequence below is unchanged; this correction publication does not start Sprint 95.

### Sprint 95 — Budget Planning and Shared Al Dar

Bounded [FW-P3-08](../FUTURE_WORK.MD#fw-p3-08), [FW-P3-09](../FUTURE_WORK.MD#fw-p3-09), and the selected shared-reference part of FW-P3-30/31. **ACCEPTED, 2026-09-16; PRE_V1_REQUIRED outcome complete.** Owner/Chat token `SPRINT_95_BUDGET_PLANNING_AND_SHARED_AL_DAR_ACCEPTED` authorizes publication from `cdfb7565893c90a138ddbbfa8beebdfbad98f8f8`; [accepted evidence and limitations](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-95) are retained. This satisfies the Sprint-95 prerequisite for Sprint 100, without accepting personal adoption or later sprint implementation.

Replace visible Salary with Budget Planning, preserving imported Salary History. The Budget Analysis Dashboard guides one compact monthly worksheet selectable from September 2026 onward: explicitly pre-salary QAR funds, fixed/variable earnings minus named nonnegative deductions, Qatar bills, Keep in CBQ, configured fee, India requirements and explicitly selected INR funds. Show available QAR/estimated INR, needed INR/required QAR and a separate signed margin. No offset editor, separate planned-investment subtraction, salary-received switch, payment inference or surplus allocation. Ordinary rows recur, one-offs omit, temporary remaining-bill reductions preserve their next-month basis, and optional due dates repeat on the same calendar day, clamped to the last day of shorter months. Live amount words use lakh/crore. Save/Command-S remains explicit; unsaved monthly drafts survive switching; legacy history is not silently reinterpreted.

Bring forward one app-owned Al Dar INR/USD-per-QAR service/cache, six local directions and shared flag/icon cards. New months use Al Dar; same-month manual override remains local. Opening checks, six-hour refresh, one 60-second retry and >24-hour stale context use real fetch timestamps without invented market time. Dashboard has no manual Refresh button. V19 worksheet state and additive V20 requested bill dates preserve prior migrations; exact backup/receipt compatibility is [ADR-047](../ADR.md#adr-047). Accepted final evidence and sequence limits belong to the [Sprint-95 outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-95); the [existing note](../Work%20notes/Salary_and_current_AlDar.md#sprint-95-candidate) retains the failed-run and repair history. No general investment or Sprint-96 work is included.

### Sprint 96 — Investment Identity and Current Holdings

**NEXT / NOT STARTED.** Closure of Sprint 95 authorizes no implementation here.

Primary candidates: bounded [FW-P3-20](../FUTURE_WORK.MD#fw-p3-20), [FW-P3-21](../FUTURE_WORK.MD#fw-p3-21), [FW-P3-23](../FUTURE_WORK.MD#fw-p3-23), selected [FW-P3-28](../FUTURE_WORK.MD#fw-p3-28) and [FW-P3-29](../FUTURE_WORK.MD#fw-p3-29).

First settle and implement selected container/instrument/position identity, scoped identifiers, native currency, exact Decimal quantity, provenance, revision and provider/hydration ownership. Then establish current holdings through adopted genuine manual source paths. Each adopted format must pass ordinary preparation, validation, account/instrument mapping, duplicate/equivalence handling, provider-owned persistence, canonical hydration and reopen before Sprint 98 uses it through email or parallel preparation. Genuine owner/source evidence and Chat architecture acceptance remain entry gates.

Require exact owned units, effective/observation dates, owner/source provenance and typed cost evidence. Total-cost-like Money, average unit cost plus currency, contribution/allocation evidence and unknown cost remain distinct. Direct-plan mutual-fund plan/option identity and mandatory/AVC ISP position classes remain exact requirements. Manual entry is only the separately selected dated-observation fallback and never overwrites source/provider evidence. Prices/NAV never establish ownership. Do not infer missing dates, costs, vesting, trades, tax lots or performance; generic brokerage ingestion is not a prerequisite.

The [investment architecture packet](../Work%20notes/Holdings_and_valuation.md#packet-investment-holdings-architecture-packet) retains exact source, identity, correction, cost and provider blockers. This position does not accept a persistence shape or allocate a migration.

### Sprint 97 — Current Valuation and Integrated Current-Portfolio Acceptance

Consume accepted Sprint-96 identity and manually qualified current holdings. Primary provider candidates remain [FW-P3-27](../FUTURE_WORK.MD#fw-p3-27), selected [FW-P3-28](../FUTURE_WORK.MD#fw-p3-28) and [FW-P3-29](../FUTURE_WORK.MD#fw-p3-29). Independently qualify FE/Zurich for exact adopted ISP identities, AMFI for exact Direct-plan mutual funds and every additional adopted price source separately. Exact identifiers, plan/option, denomination, native price currency, actual price/observation date where available, fetched-at time, provider identity, freshness and permission/cache boundaries remain mandatory. Regular plans cannot substitute for Direct plans. A price provider or workbook multiplier never establishes personal ownership, units, cost or vesting. Automation/cache permission precedes automated persistence.

Then perform the former Sprint-98 **final current-investment acceptance required before personal-v1**, including adopted ISP, mutual funds and stock/ETF positions. Prove coherent container/instrument identity, exact units, typed cost, native valuation provenance, non-overlapping membership and truthful unavailable/incomplete states. Where durable state exists, require provider parity, canonical hydration and same-database reopen/relaunch. Genuine owner/source facts and independently qualified price evidence remain separate acceptance inputs. Revalidate the code/persistence split against the accepted implementation before selecting work.

Exclude [FW-P3-22](../FUTURE_WORK.MD#fw-p3-22) brokerage transaction ingestion unless separately selected, together with trade history, tax lots, performance, realized gains/losses, TWR/IRR and corporate-action reconstruction. Do not make those gates necessary by implication or use the legacy workbook as financial source truth.

### Sprint 98 — Manual Gmail and Combined-Bank Intake

Adopted investment formats must already have passed ordinary manual qualification. Within Sprint 98, newly identified HDFC/Axis combined layouts must pass their own source interpretation, preparation, validation, per-account mapping, duplicate/equivalence, persistence and reopen gates **before** automatic batch acceptance. Sender, subject, filename and MIME nominate candidates only; exact original bytes and independent financial truth remain decisive. See [the owner decision](../SCOPE_DECISIONS.md#manual-gmail-intake) and [bounded pilot evidence](../Work%20notes/Account_and_document_lifecycle.md#manual-gmail-feasibility).

Use bounded concurrent retrieval/preparation only where reader/thread-safety and queued-byte limits are measured. Recheck identity, mapping, duplicate/equivalence and provider generation immediately before deterministic one-at-a-time ordinary commits. Current bank APIs are single-account: a combined original requires parent/section provenance and complete section accounting. Any invalid/unresolved sibling holds the whole original under the selected policy; section-independent commits need a separate explicit decision. Additional products cannot silently disappear.

One explicit manual batch action authorizes automatic ordinary import only for qualified, unlocked, fully validated and resolved items with complete approved mappings and passing commit-time ownership. Password needs, new unresolved identities/names, ambiguous alignment, unsupported variants, partial overlap and failed validation stay held for attention; invalid sources cannot be forced through. Safe unrelated items continue. Resolving a mapping requires revalidation. Already-imported/equivalent items receive truthful no-duplicate outcomes. Cancellation stops uncommitted work; prior atomic commits remain. No parallel database writers or batch-wide rollback is selected.

Email Statements is the connection/collection/status surface; Import Centre remains the shared unlock, validation, mapping, exception, duplicate/equivalence and result workflow. Native navigation/typing/scrolling must later be compared with intake idle/preparing/committing on the same growing authentic ledger. Scratch network measurements do not prove native responsiveness. No startup fetch, polling, desktop notification, original archive, transaction-deletion feature or current production behavior change is selected by this plan.

### Sprint 99 — Current Reporting and Net Worth

Primary queue: [FW-P3-26](../FUTURE_WORK.MD#fw-p3-26), bounded [FW-P3-30](../FUTURE_WORK.MD#fw-p3-30), [FW-P3-31](../FUTURE_WORK.MD#fw-p3-31), [FW-P3-33](../FUTURE_WORK.MD#fw-p3-33) and [FW-P3-34](../FUTURE_WORK.MD#fw-p3-34). **PRE_V1_REQUIRED; NOT STARTED.** Historical FW-P3-32 remains deferred.

After accepted Sprint-96 investment identity/current holdings, Sprint-97 valuation/integrated portfolio acceptance and Sprint-98 manual Gmail/combined-bank intake, build current explainable net-worth/reporting estimates using the same Al Dar QAR/INR/USD authority brought forward into Sprint 95. Do not introduce a competing provider or restore a saved planning-rate Dashboard card. Reporting-currency/direction selection recalculates locally; native Money remains authoritative and a plan's manual override is not global authority.

Require non-overlapping bank/card/investment membership, exact native quantities/values, truthful source/valuation/fetch times and complete component status. Missing or stale inputs make combined results explicitly incomplete; never omit missing components or substitute zero. Preserve Sprint-95 exact raw precision, final-Money rounding, last-success age, six-hour refresh and one retry semantics. Reporting preference ownership and integrated membership/rounding verification remain Sprint-99 decisions. No historical FX/net-worth/performance work is implied.

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

The [investment architecture packet](../Work%20notes/Holdings_and_valuation.md#packet-investment-holdings-architecture-packet) preserves the genuine ownership/cost evidence, missing brokerage-source qualification and independent provider permission/date/identity gates. The 2026-09-16 owner decision places identity/current holdings together in 96 and valuation/integrated acceptance in 97, reserving 98 for manual Gmail/combined-bank intake. Brokerage ingestion/history/performance remain separately gated and outside the required current outcome. Exact architecture and per-sprint source/persistence splits still need Chat acceptance.

<a id="packet-roadmap-replanning-packet-99"></a>
### ROADMAP_REPLANNING_PACKET_99 — current FX and net worth

The [general FX packet](../Work%20notes/Current_FX_and_net_worth.md#packet-general-fx-architecture-packet) retains the current direct-market evidence and unresolved financial-data suitability, current membership, orientation, rounding, cache/freshness and reporting-setting decisions. The required Sprint-99 queue explicitly includes net-worth owner `FW-P3-26` with bounded `FW-P3-30/31/33`. Historical `FW-P3-32`, historical Al Dar and performance remain non-required. This planning decision changes required adoption scope, not the accepted architecture or provider.

The owner’s [current source-processing decision](../SCOPE_DECISIONS.md#source-processing-decision) governs future financial execution: in-memory source interpretation and independent comparison, no derived financial evidence files on disk, normal app database retained. Existing scripts were not changed or certified against that rule by this documentation task.
