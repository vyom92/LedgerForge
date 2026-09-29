# LedgerForge Roadmap: Sprints 100–109

**Status:** PREPARED FUTURE ROADMAP / NOT CURRENT AUTHORITY.
**Prepared:** 2026-09-10; scope reset by explicit owner decision, 2026-09-11.
**Current authority:** [Sprints 90–99](../LedgerForge_Roadmap_Sprints_90-99_Current.md), through functional Sprint-99 acceptance on 2026-09-29. Accepted Sprint-98 dependencies and Sprint 99 share the authorized integrated publication. This future cycle remains non-current; Sprint 100 is paused / not started.
**PERSONAL-V1: NOT YET ADOPTED.**

Only Sprint 100 is fixed. This document authorizes no implementation, verification run, architecture, migration or cycle activation. Apply the [Private Personal App Scope Gate](../../../AGENTS.md#private-personal-app-scope-gate) before priority triage. Rejected categories are **NOT REQUIRED-DO NOT CONSIDER** and cannot become dependencies or future sprint candidates.

## Prepared milestone overview

Order inherits [Guide rule E](../../Project_Guide.md#documentation-order): sprint number ascending; unassigned numbers remain unassigned.

| Sprint | Planned outcome | Authority |
| --- | --- | --- |
| 100 | LedgerForge 1.0 Personal Adoption Verification | FW-P0-26; explicit owner decision |
| 101–109 | UNASSIGNED | Fresh eligible-work selection only after the owner adoption decision; no capability assigned here |

<a id="sprint-100--ledgerforge-10-personal-adoption-verification"></a>
## Sprint 100 — LedgerForge 1.0 Personal Adoption Verification

Primary queue: [FW-P0-26 — Personal-v1 Adoption Verification Gate](../../FUTURE_WORK.MD#fw-p0-26).

**FIXED FUTURE MILESTONE. PAUSED / NOT STARTED. NO EXECUTION AUTHORIZED BY CLOSEOUT. PERSONAL-V1: NOT YET ADOPTED.**

Is LedgerForge safe, correct and complete enough for the owner to use as the personal system of record? Freeze the exact intended candidate and answer that question using the owner's real financial sources, adopted workflows and recovery evidence. The owner’s 29 September closeout direction adds the required bounded usability phase below before final verification, superseding the earlier verification-only sequence. A known correctness/safety blocker or missing required capability still prevents adoption; the final corrected bytes require verification.

<a id="required-usability-before-adoption"></a>
## Required usability before adoption — owner direction, 29 Sep 2026

Sprint-99 functional acceptance leaves the owner’s UI/UX dissatisfaction unresolved. The following are mandatory adoption work, not optional cosmetic wishes:

1. **Monthly plan:** a compact editable Qatar/India worksheet centred on starting money and salary, bills, transfer available, India requirement and remainder—the practical decision in Budget Analysis. Minimise routine steps, unnecessary scrolling, repeated explanation and unused-account clutter. Preserve exact financial semantics, the separation from long-term reserve targets, explicit Save, owner overrides and source access.
2. **Expanded Salary History:** readable earnings and deductions side by side at the owner’s normal full width, aligned label/amount columns, clear section totals and one primary net-pay figure. Keep distinct source controls accessible; merge or drop no source lines. Stack appropriately at narrow width.
3. **Whole-app hierarchy and interaction:** readable text, concise user language, useful charts, compact contextual detail, consistent account/date/control presentation and ordinary keyboard/pointer workflows. Select and bound the proposed changes before implementation. No new design system or backend feature campaign.
4. **Sequence:** owner-reviewed proposed layouts → bounded implementation → real owner workflow walkthrough → final adoption verification on those exact bytes. The owner must prefer LedgerForge to returning to the sheet for ordinary monthly planning.

This is a future obligation only. No mockups, view changes, UI campaign or Sprint-100 execution occurs during Sprint-99 closeout. Acceptance of financial calculations is not owner adoption.

## Entry gates

Chat must have accepted the adopted Swift-6 and R1 boundaries through Sprint 92; verified backup/restore; Sprint-94 QAR-1 indicative Al Dar unit planning reference and manual fallback under ADR-045; **Sprint-95 Budget Planner / This Month**; Sprint-96 investment identity and manually qualified current holdings; Sprint-97 current valuation and integrated portfolio acceptance; Sprint-98 manual Gmail/combined-bank support and bounded batch intake; Sprint-99 reporting and financial intelligence, including its retained limits; and the [private supported-source matrix](../../FUTURE_WORK.MD#fw-p2-79). **Sprint-95 planner acceptance is a hard prerequisite.** Finishing Sprint-94 planning plumbing or retaining the existing Salary page does not satisfy the monthly workflow gate.

Roadmap positions do not establish accepted architecture, current behavior or readiness. Existing exact Import Centre, credential, source, provider, duplicate/equivalence and Salary contracts remain binding. Complete structured export remains optional unless explicitly adopted.

The [Sprint-98 frozen qualification/population campaign](../LedgerForge_Roadmap_Sprints_90-99_Current.md#sprint-98-qualification-and-adoption-population) and accepted Sprint-99 continuation retain distinct qualification and owner-review ledger lineages. At adoption entry, identify the exact selected populated candidate/build, its qualified original-source set, canonical data, coverage and holds; do not silently combine the 8,036-row qualification lineage with the 7,940-row owner continuation or infer whole-database equality. The gate does not authorize a new population/parser campaign or resetting Current. Personal-v1 remains not adopted until the owner accepts the required usability work and completed final verification.

## Personal adoption verification

1. **Real imports:** the complete registered authentic corpus passes ordinary single-file workflows and, where adopted, the Sprint-98 manual batch workflow, including encrypted families. One explicit batch action may commit only fully validated/resolved items; unsupported, password-needed, unknown-mapping, ambiguous, incomplete or failed items remain exceptions for attention. No failed financial validation may be overridden and no batch-wide atomicity is implied.
2. **Independent financial truth:** compare the original-source interpretation with canonical data after persistence/hydration under the [Sprint-98 source comparison contract](../../Work%20notes/Source_relationships.md#sprint-98-source-qualification): exact Money/currency/scale, date meaning, direction, identity, references/descriptions, balances/controls, multiplicity, missing/extra occurrences, provenance and duplicate/equivalence behavior. Transaction array order is not itself a failure when every occurrence is wholly and uniquely matched, relevant controls agree and source order/provenance is preserved. Source-specific owner adjudications remain binding without a generic tolerance. Rejection leaves zero accepted durable residue.
3. **Durable database:** accepted migration identities, SQLite integrity/foreign keys, applicable SQLite/In-Memory parity, canonical hydration and ordinary same-database quit/relaunch are safe.
4. **Recovery:** owner backup creation, consistent snapshot, manifest/integrity/version checks, isolated restore, nonempty-target protection, explicit confirmation, activation rollback, restored hydration and relaunch actually work. A copied live database file is not proof.
5. **Budget Planner / This Month:** the accepted Sprint-95 workflow uses available funds, selected bank balances, card commitments, expected/actual salary, Qatar/India requirements, remittance, fees, planned investment and the resulting Qatar buffer coherently. Salary History remains supporting evidence. QAR-1 indicative Al Dar unit references and manual fallback preserve full internal precision, accepted fee/rounding/underfunding rules and explicit stale/unavailable states. The Budget Analysis workbook is the workflow reference, not financial source authority.
6. **Current investments:** genuine ownership, exact units, typed cost evidence and independently qualified price/NAV identity/currency/date support the adopted holdings and valuation.
7. **Current FX/net worth:** qualified current market observations, explicit reporting orientation, non-overlapping membership and approved rounding preserve native facts; missing/stale balances, holdings, prices or rates make results incomplete rather than zero. Al Dar remains the accepted shared QAR/INR/USD current reference; a worksheet manual override is not global reporting authority.
8. **Source truth table:** the private supported-source matrix accurately names actual institutions/products, accepted formats/families, exact boundaries and relevant limitations, including source-uncertified gaps.
9. **Owner usability:** actual adopted screens provide readable full Money, no clipping/overlap, sensible resize/reflow, useful ordinary keyboard interaction, visible focus/selection and clear icon controls. Financial meaning does not rely on decorative colour.
10. **No safety blocker:** compare with the owner's actual financial workflows, document material limitations and verify no known correctness/safety blocker remains. The legacy workbook is workflow context, not financial authority.

11. **Background/foreground recovery:** use the exact frozen populated candidate identified at adoption entry, preserving its accepted Sprint-98/99 lineage. Verify enabled, disabled and uninstalled service behavior; app-closed receipt/canonical visibility; offline/authentication exceptions with last-good values intact; no stale-helper migration/create-empty; ordered commit/restore/cancellation outcomes; restored-ledger candidate reconciliation; compatible app/helper/cache versions; and foreground cache convergence with dirty drafts preserved. Use the [background authority](../../Work%20notes/Account_and_document_lifecycle.md#sprint-98-background-updates) and selected [UTC catch-up rule](../../Work%20notes/Current_FX_and_net_worth.md#sprint-98-price-catch-up). A standalone helper heartbeat is not whole-app responsiveness or financial acceptance. Preserve the owner’s accepted clamshell substitution for restart/login and removal of deliberately locked login-Keychain testing; those are not newly required by this gate.

Use the complete TestPlan, Debug and optimized locally signed Release build where technically appropriate for this final integrated candidate. Record exact code/build identity, nonzero execution, zero unexplained failures/skips/expected failures, applicable full authentic provider/order campaigns and privacy/app-resource containment. A green suite or plausible screen alone cannot establish adoption.

No synthetic, generated, reconstructed, sanitized, reduced, mutated or hand-authored financial statement may be created or used. Independent source oracles cannot derive their truth solely from production output. A missing authentic case remains source-uncertified; never manufacture coverage. Private originals and credentials remain outside published artifacts.

## Scope limits and future selection

No external certification/compliance, public-release qualification, formal accessibility campaign, API/plugin, sync, multiple-workspace, cross-platform or support-organization readiness is required. The [canonical rejection register](../../SCOPE_DECISIONS.md#rejected-private-personal-scope) prevents those categories re-entering active scope.

Historical FX/Al Dar, investment history/performance, tax lots, realized P/L, TWR/IRR and corporate-action reconstruction are not required for current holdings and estimates. Generic brokerage ingestion is not required if current holdings can be truthfully established without it. Transfers, reconciliation, rules, recurrence and personally useful analytics may enter future selection only for an actual owner workflow or verified correctness need. No feature is assigned to Sprints 101–109 here.

## Authority

The current roadmap owns active numbering, PROJECT_STATE.md owns accepted production reality, and accepted ADRs own architecture. Chat owns activation, corrective attribution and final technical acceptance; the owner controls adoption. This planning correction allocates no ADR or migration and changes no accepted decision text.

The owner’s [current source-processing decision](../../SCOPE_DECISIONS.md#source-processing-decision) governs future financial execution: in-memory source interpretation and independent comparison, no derived financial evidence files on disk, normal app database retained. Existing scripts were not changed or certified against that rule by this documentation task.
