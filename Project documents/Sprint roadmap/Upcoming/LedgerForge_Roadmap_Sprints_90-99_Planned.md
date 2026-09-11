# LedgerForge Roadmap: Sprints 90–99

**Status:** PREPARED / NOT CURRENT. This successor roadmap becomes current numbering authority only after Sprint 89 is accepted and Chat explicitly activates the cycle.
**Prepared:** 2026-09-09; realigned by explicit user decisions through 2026-09-11.
**Accepted product baseline:** see [PROJECT_STATE](../../PROJECT_STATE.md); documentation publication is not product acceptance.
**Current authority remains:** [Sprints 80–89](../LedgerForge_Roadmap_Sprints_80-89_Current.md).
**PERSONAL-V1: NOT YET ADOPTED.**

This is documentation and planning. It authorizes no Sprint 90–100 implementation, accepts no proposed architecture and allocates no ADR or migration number. Before selecting each future sprint, Chat must apply the Private Personal App Scope Gate, then rerun P0 → P1 → P2 → P3 triage only for eligible owner needs, enforce exact entry gates and revalidate the implementation split against accepted post-Swift-6 ownership. A verified higher-priority correctness defect preempts a lower-priority outcome unless explicitly deferred; unmet dependencies do not silently cascade sprint numbers.

## Governing source and financial rules

The complete registered authentic corpus remains authority for statement-dependent work. No synthetic/generated/sanitized/reconstructed/reduced/mutated/hand-authored financial statement is permitted at any stage. Exact support never generalizes from institution, format or layout similarity; production output is never its own sole oracle; private gates fail closed; material corrections invalidate affected prior green evidence; and acceptance is tied to the exact candidate. Missing authentic cases remain uncertified.

## Explicit personal-adoption plan — 2026-09-10

The user fixes [Sprint 100 — LedgerForge 1.0 Personal Adoption Verification](LedgerForge_Roadmap_Sprints_100-109_Planned.md#sprint-100--ledgerforge-10-personal-adoption-verification) after the accepted pre-100 product boundaries. This supersedes the earlier instruction to retain the former 93–99 positions and the earlier statement that current FX/net-worth was not an adoption prerequisite.

Required outcomes include accepted Swift 6 and selected R1/native UI, verified backup/restore, existing Qatar Airways Salary actuals and Salary History, the current This Month planner with bounded current Al Dar reference use and manual override, current holdings and valuation sufficient for the owner's present holdings, current market FX/net-worth reporting, private supported-source matrix and the final Chat adoption matrix. Exact scope and architecture remain gated; assigning a position does not promote a queue status or make every expansion on a broad card required.

Complete structured export remains optional. Historical FX, historical Al Dar, investment history/performance, tax lots, realized P/L, TWR/IRR, corporate-action reconstruction and generic brokerage transaction ingestion are not required merely to establish current holdings. Transfer matching, reconciliation, rule/merchant/recurrence automation and personally useful analytics are eligible only for an actual selected owner workflow or verified correctness need. Generalized platform categories are **NOT REQUIRED-DO NOT CONSIDER** under the [canonical scope register](../../SCOPE_DECISIONS.md#rejected-private-personal-scope), not future candidates.

## Prepared cycle overview

Order inherits [Guide rule E](../../Project_Guide.md#documentation-order): sprint number ascending; readiness does not reorder the sequence.

| Sprint | Outcome | Queue | Entry / planning boundary |
|---|---|---|---|
| 90 | R1 Dashboard Native-Currency Hierarchy | `FW-P2-78` | Sprint 89 shared R1 patterns accepted; no unsupported analytics |
| 91 | R1 Simple Appearance Choice | `FW-P2-52` | Simple device-local System/Light/Dark; optional approved Deep Indigo/accent direction |
| 92 | R1 Cross-Screen Visual and Interaction Polish | bounded `FW-P2-40` + `FW-P2-41` + `FW-P2-47` + `FW-P2-48` + `FW-P2-50` | Only actual owner usability after 89–91; terminology, truthful states, readable layout and useful native interaction |
| 93 | Verified Backup, Restore and Disaster Recovery | `FW-P3-36` | PRE_V1_REQUIRED; accepted user-owned backup/restore architecture and independent restore drill |
| 94 | Salary / This Month Current Al Dar Planning Completion | bounded `FW-P3-08` | PRE_V1_REQUIRED current planning slice; explicit ADR-045 alignment or successor architecture, access/permission/freshness/amount binding |
| 95 | Current Investment Domain and Identity Foundation | bounded `FW-P3-20`, `FW-P3-21`, `FW-P3-23` | Container/instrument identity, scoped identifiers, native currency, exact Decimal quantities and current ownership/revision architecture |
| 96 | Current Holdings, Cost-Evidence and ISP Positions | bounded `FW-P3-20`, `FW-P3-21`, `FW-P3-29`, selected fallback `FW-P3-28` | Accepted identity, genuine current owned units/dates/provenance and typed cost evidence; no lots/performance inference |
| 97 | Current Investment Valuation Providers | bounded `FW-P3-27`, selected fallback `FW-P3-28` | Exact provider/instrument/currency/date qualification and automation/cache permission; valuation never establishes ownership |
| 98 | Integrated Current Portfolio and Investment Acceptance | bounded accepted outputs of `FW-P3-20`, `FW-P3-21`, `FW-P3-23`, `FW-P3-27`, `FW-P3-28`, `FW-P3-29` | Accept integrated 95–97 current holdings/valuation; final PRE_V1_REQUIRED investment outcome; history/performance excluded |
| 99 | Current Market FX and Net-Worth Reporting | `FW-P3-26`, bounded `FW-P3-30`, `FW-P3-31`, `FW-P3-33` | PRE_V1_REQUIRED current membership/valuation, direct INR→USD and QAR→USD, reporting choice and incomplete-state contract; historical `FW-P3-32` deferred |

## Planned Sprint details

### Sprint 90 — R1 Dashboard Native-Currency Hierarchy

Queue: `FW-P2-78`.

Entry gate: Sprint 89 shared R1 implementation patterns accepted. Implement native-currency grouped position, bank balances distinct from card liabilities, full readable amounts, authoritative period/as-of context and current funding summary without changing formulas. No FX conversion, net-worth invention, fake trend/percentage/chart or hydration-as-import claim.

### Sprint 91 — R1 Simple Appearance Choice

Queue: narrowed [FW-P2-52](../../FUTURE_WORK.MD#fw-p2-52) only.

Implement Follow System, Light and Dark with optional already-approved Deep Indigo/accent direction and simple device-local persistence. Verify ordinary readable rendering and remembrance after relaunch without financial writes. No theme engine, preference portability, formal qualification or automatic new-ADR gate. If implementation exposes a real architecture decision, return to Chat before widening scope.

### Sprint 92 — R1 Cross-Screen Visual and Interaction Polish

Queue: bounded `FW-P2-40`, `FW-P2-41`, `FW-P2-47`, `FW-P2-48`, `FW-P2-50` only.

After 89–91, select only actual owner usability needs across the existing screens: terminology, truthful states, clipping/overlap, responsive layout, readable complete Money, useful ordinary keyboard interaction, focus distinct from selection, icon names/tooltips and visual consistency. Acceptance is the owner's actual workflow. No formal accessibility campaign is scheduled. Salary remains lower priority and accepted editor, fee, source and persistence semantics remain unchanged.

### Sprint 93 — Verified Backup, Restore and Disaster Recovery

Primary queue: [FW-P3-36](../../FUTURE_WORK.MD#fw-p3-36). **PRE_V1_REQUIRED.**

Implement only the subsequently approved user-owned backup/restore contract. Architecture must settle backup contents, integrity manifest, SQLite/WAL/SHM-consistent snapshot, compatibility/version policy, isolated restore verification, non-empty-current-data protection, explicit confirmation, rollback if activation fails, canonical hydration and same-database relaunch. The owner may save/copy a verified package to a personally chosen destination. This does not create sync, live portable workspace or cloud integration. Appearance stays device-local; no theme preference snapshot is required. Reporting currency remains separate financial configuration.

The [backup/restore packet](../../Work%20notes/Backup_and_export.md#packet-user-backup-restore-architecture-packet) retains the unresolved architecture and genuine restore-drill requirements. Complete structured export is optional and separate. A roadmap position does not establish recoverability.

### Sprint 94 — Salary / This Month Current Al Dar Planning Completion

Primary queue: bounded [FW-P3-08](../../FUTURE_WORK.MD#fw-p3-08). **PRE_V1_REQUIRED for this current Salary/budget slice only.**

Complete the existing personal planning workflow with current/live Al Dar QAR→INR reference evidence and an explicit manual current-rate override. Do not rebuild Salary: accepted Qatar Airways actuals, Salary History, current-month plan, commitments, selected balances, separate fee behavior, underfunding/rounding safety and calculations remain authoritative.

Intended flow: current/provisional QAR send amount → current amount-bound Al Dar reference quote → approved Salary/This Month estimate → explicit manual current-rate override. Preserve amount binding, provider/source/fetch context, truthful stale/unavailable state and explicit user control. Al Dar is not general LedgerForge FX or net-worth authority.

**REQUIRES EXPLICIT ADR-045 ALIGNMENT OR SUCCESSOR ARCHITECTURE** before implementation, plus the Al Dar access/permission/freshness/amount-binding decision and exact post-Swift-6 ownership review. Current production retains the accepted user-entered planning-rate contract until that future gate is accepted. Exclude historical Al Dar/QAR→INR, forecast month-end rates, guaranteed settlement, automatic remittance execution, automatic fee inference, reverse-rate inference and universal 1-QAR/table-rate assumptions. Broad cross-employer Salary/planning expansion remains outside this sprint.

### Sprint 95 — Current Investment Domain and Identity Foundation

Primary candidates: bounded [FW-P3-20](../../FUTURE_WORK.MD#fw-p3-20), [FW-P3-21](../../FUTURE_WORK.MD#fw-p3-21) and [FW-P3-23](../../FUTURE_WORK.MD#fw-p3-23).

Settle and implement the selected container/instrument identity, scoped identifiers, native currency, exact Decimal quantity semantics and current position ownership/revision architecture. Exact genuine owner/source evidence and Chat architecture acceptance remain entry gates. Current holdings come first; generic brokerage ingestion and transaction-history reconstruction are not prerequisites merely to establish positions.

The [investment architecture packet](../../Work%20notes/Holdings_and_valuation.md#packet-investment-holdings-architecture-packet) retains separate evidence, identity, correction and provider blockers. This position does not accept its proposed persistence shape or allocate a migration.

### Sprint 96 — Current Holdings, Cost-Evidence and ISP Positions

Primary candidates: bounded [FW-P3-20](../../FUTURE_WORK.MD#fw-p3-20), [FW-P3-21](../../FUTURE_WORK.MD#fw-p3-21), [FW-P3-29](../../FUTURE_WORK.MD#fw-p3-29), and [FW-P3-28](../../FUTURE_WORK.MD#fw-p3-28) only where selected holdings require manual/current entry or fallback.

Consume accepted identity and revision architecture. Establish exact current owned units, explicit effective/observation date, owner/source provenance, typed cost evidence and current Qatar Airways ISP position classes. Keep total-cost-like evidence, average unit cost, contribution allocation and unknown cost distinct. Manual entry follows the approved evidence contract; external prices cannot establish ownership or units. Do not infer lots, performance, missing dates, costs or transaction history.

### Sprint 97 — Current Investment Valuation Providers

Primary candidates: bounded [FW-P3-27](../../FUTURE_WORK.MD#fw-p3-27) and selected provider fallback under [FW-P3-28](../../FUTURE_WORK.MD#fw-p3-28).

Qualify prospective FE/Zurich adapters for exact adopted ISP identities, AMFI for exact adopted Direct-plan mutual-fund identities, and any other current-price source only after its own provider qualification. Use exact configured identifiers and plan/option metadata; names are secondary and Regular plans cannot substitute for Direct plans. Preserve the existing provider-specific evidence and permission blockers in the owning cards. No legacy workbook multiplier or inferred vesting/performance model becomes valuation authority.

Require exact instrument mapping, native price/NAV currency, actual observation/price date where available, fetched-at time, provider/source identity, freshness and explicit stale/unavailable state. Automation/cache permission must precede automated persistence. Current external valuation is separate from ownership and contributes only the approved derived native market value. Historical performance is not required.

### Sprint 98 — Integrated Current Portfolio and Investment Acceptance

Consume the accepted bounded outputs of Sprints 95–97. This is the **final current-investment outcome required before personal-v1**; the code/persistence split must still be revalidated after Sprint 87 and before selecting each sprint.

Accept coherent current holdings and native-currency market values for current ISP, mutual funds and stock/ETF positions where adopted. Prove container/instrument identity, exact owned units, typed cost evidence, current valuation provenance and truthful unavailable/incomplete states. Where durable state exists, require provider parity, canonical hydration and same-database relaunch. Genuine owner/source facts and independently qualified current price evidence remain distinct acceptance inputs.

Exclude [FW-P3-22](../../FUTURE_WORK.MD#fw-p3-22) brokerage transaction ingestion unless independently selected later, trade history, tax lots, performance, realized gains/losses, TWR/IRR and corporate-action reconstruction. Do not make those gates necessary by implication or use the legacy workbook as source truth.

### Sprint 99 — Current Market FX and Net-Worth Reporting

Primary queue: [FW-P3-26](../../FUTURE_WORK.MD#fw-p3-26), bounded [FW-P3-30](../../FUTURE_WORK.MD#fw-p3-30), [FW-P3-31](../../FUTURE_WORK.MD#fw-p3-31) and [FW-P3-33](../../FUTURE_WORK.MD#fw-p3-33). **PRE_V1_REQUIRED.** Historical [FW-P3-32](../../FUTURE_WORK.MD#fw-p3-32) remains deferred and does not block this current outcome.

Produce current, explainable net-worth estimates after accepted current investments and valuation. Use direct current market INR→USD and QAR→USD evidence, plus any later explicitly accepted current reporting orientation. Native Money remains authoritative; reporting conversion is derived and the user explicitly selects the reporting currency/currencies.

Preserve non-overlapping membership and account/liability/investment distinctions, current observation and fetch timestamps, current/last-success freshness, provider attribution, exact Decimal rates, and deterministic rounding at the approved final Money boundary. Missing/stale balances, holdings, prices or rates make the result explicitly incomplete; never replace missing components with zero or hide them in a complete total.

The [general FX packet](../../Work%20notes/Current_FX_and_net_worth.md#packet-general-fx-architecture-packet) still requires provider suitability, permission/cache/freshness, membership, reporting-currency and rounding/orientation decisions. Technical access is not provider qualification; the researched provider's financial-data suitability warning remains unresolved. No history collection or assumed inverse/cross conversion is authorized. Al Dar stays confined to Sprint 94 current Salary/budget QAR→INR evidence and is not net-worth FX authority.

## Displaced outcomes retained as unscheduled post-1.0 candidates

The former 93–97 positions no longer assign the following work. [FUTURE_WORK](../../FUTURE_WORK.MD) preserves every existing priority, status, architecture/source blocker and discovery record. No Sprint 101+ number is assigned here.

| Former position | Retained candidates | Remaining boundary |
|---|---|---|
| 93 transfer matching | `FW-P2-10` | Source/architecture-gated reviewable relationships; date/amount/opposite-direction coincidence alone is insufficient |
| 94 reconciliation | `FW-P2-11` | Accepted transfer/provenance/mismatch semantics; reevaluate prospective duplicate review `FW-P2-12` before later reconciliation/analytics |
| 95 categorization rules | `FW-P2-21`, `FW-P2-22`, `FW-P2-23` | POST_V1; manual assignments authoritative; every disagreeing applicable rule remains an explicit conflict, with no silent priority winner |
| 96 merchant/recurrence | `FW-P2-25`, `FW-P2-26` | POST_V1; immutable source descriptions, correction/provenance, independently sufficient recurrence evidence and explicit obligation confirmation |
| 97 broad planning/analytics | `FW-P3-09`, `FW-P3-10` | Separate future projections of facts, user assumptions and derivations; historical analytics/forecasting do not become the accepted Salary current-month planner or Sprint 94 Al Dar completion |

## Other candidates and pre-100 documentation

Existing P0 integrity/identity/reversal candidates and P1 source/duplicate/recovery work remain subject to fresh priority triage, with their current blockers intact. A new verified correctness dependency may preempt this prepared sequence; a roadmap position itself changes no queue status. Only scope-eligible account lifecycle, document retention and bounded local maintenance remain candidates; rejected scope cannot block this cycle.

[FW-P2-79 private supported-source matrix](../../FUTURE_WORK.MD#fw-p2-79) is required before Sprint 100, without inventing a numbered implementation sprint here. It must describe the exact accepted supported-source matrix and cumulative authentic corpus accurately. [FW-P3-35 complete structured export](../../FUTURE_WORK.MD#fw-p3-35) stays optional unless the user separately promotes it.

## Successor milestone and activation

[Sprints 100–109](LedgerForge_Roadmap_Sprints_100-109_Planned.md) own the fixed future Sprint-100 personal adoption verification milestone. No feature is deliberately deferred into adoption verification. A product defect or missing required capability fails adoption verification and returns to Chat for separate corrective attribution/scheduling; LedgerForge 1.0 remains undeclared until the corrected candidate passes verification. Sprints 101–109 remain unassigned for fresh selection after LedgerForge 1.0.

The 90–99 cycle remains prepared until Sprint 89 acceptance and explicit Chat activation. The [current 80–89 roadmap](../LedgerForge_Roadmap_Sprints_80-89_Current.md) continues to own active numbering and accepted Sprint-86/87 history.

<a id="roadmap-replanning-packets-97-99"></a>
## Earlier replanning evidence — positions superseded, architecture still gated

The following stable anchors retain the relationship to the earlier second-level packets. The explicit 2026-09-10 addendum supersedes their old sprint placements; their source/provider findings and unaccepted architecture remain in the owning FUTURE_WORK packets and Git history. They grant no implementation or architecture acceptance.

<a id="packet-roadmap-replanning-packet-97"></a>
### Former ROADMAP_REPLANNING_PACKET_97 — broad planning and analytics

The proposal to separate current obligations/user-assumption projections from facts-only historical analytics remains unaccepted, unscheduled post-1.0 work under [FW-P3-09](../../FUTURE_WORK.MD#fw-p3-09) and [FW-P3-10](../../FUTURE_WORK.MD#fw-p3-10). Preserve duplicate/transfer/category/provenance dependencies, independent fact/assumption oracles and the exclusion of forecasts. This is distinct from accepted Salary/This Month and the newly placed Sprint 94 current Al Dar boundary.

<a id="packet-roadmap-replanning-packet-98"></a>
### Former ROADMAP_REPLANNING_PACKET_98 — investment boundaries

The [investment architecture packet](../../Work%20notes/Holdings_and_valuation.md#packet-investment-holdings-architecture-packet) preserves the genuine ownership/cost evidence, missing brokerage-source qualification and independent provider permission/date/identity gates. The user now places foundation, current holdings, valuation and integrated acceptance at 95, 96, 97 and 98 respectively. Brokerage ingestion/history/performance remain separately gated and outside the required current outcome. Exact architecture and per-sprint source/persistence splits still need Chat acceptance.

<a id="packet-roadmap-replanning-packet-99"></a>
### ROADMAP_REPLANNING_PACKET_99 — current FX and net worth

The [general FX packet](../../Work%20notes/Current_FX_and_net_worth.md#packet-general-fx-architecture-packet) retains the current direct-market evidence and unresolved financial-data suitability, current membership, orientation, rounding, cache/freshness and reporting-setting decisions. The required Sprint-99 queue explicitly includes net-worth owner `FW-P3-26` with bounded `FW-P3-30/31/33`. Historical `FW-P3-32`, historical Al Dar and performance remain non-required. This planning decision changes required adoption scope, not the accepted architecture or provider.

The owner’s [current source-processing decision](../../SCOPE_DECISIONS.md#source-processing-decision) governs future financial execution: in-memory source interpretation and independent comparison, no derived financial evidence files on disk, normal app database retained. Existing scripts were not changed or certified against that rule by this documentation task.
