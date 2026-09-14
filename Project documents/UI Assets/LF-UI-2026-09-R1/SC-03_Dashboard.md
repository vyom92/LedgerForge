# SC-03 — Dashboard

Canonical approved written R1 Dashboard contract. Read the [responsibility-based shared authority](DESIGN_HANDOFF.md#authority), [numeric tokens](DESIGN_TOKENS.json) and [required checks](ACCEPTANCE.md). Approved [SC-03A](LF-UI-2026-09-R1_SC-03A_Dashboard_Wide_Reference.png) controls composition, visual emphasis and material direction; [SC-03B](LF-UI-2026-09-R1_SC-03B_Dashboard_Narrow_Responsive_Reference.png) controls constrained reflow; [SC-03C](LF-UI-2026-09-R1_SC-03C_Dashboard_State_Component_Contract.png) controls truthful states and interactivity. Written financial/workflow rules preserve meaning; they do not replace the approved appearance with a schematic aesthetic.

**Accepted Sprint 91A — 2026-09-14:** Sprint 90's data, behavior and day-change crash correction remain accepted. The owner now accepts the current Dashboard visual foundation and truthful compact composition in [Sprint 91A](../../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-91a). Final Settings/Dashboard 1440 × 900 observations and the accepted final-byte small-window recheck limitation remain distinct; no full responsive PASS is inferred. The [original visual qualification](../../Work%20notes/Transaction_and_R1_workflows.md#sprint-91a-visual-conformance) is historical.

## 4. Dashboard reference

### 4.1 Hierarchy

Show **position by native currency**, relevant attention, current-month funding summary, and recent activity. Keep Import Activity secondary. Do not show repository hydration as though it were an imported statement.

Within each currency group, distinguish bank balances from card amounts owed. A combined position is allowed only if its signed financial projection is already accepted and independently verified. It is not automatically net worth or available cash. Do not silently convert QAR and INR or assume that a credit balance on a card is bank liquidity.

Keep full amounts on one line. Use shared label/metric hierarchy and aligned labels rather than eight unrelated oversized cards. Display balance as-of/source coverage where supported; otherwise state that its date is unavailable. The flow period is distinct from balance as-of dates.

Use the 28-point headline metric role for available domain totals. Keep account names, full Money and each applicable source date in compact aligned supporting rows; an unavailable constituent stays visible. Design a single currency intentionally without a ghost currency column or an expanding paragraph-like slab. At most two currency groups sit side by side when they fit; reflow preserves every member. Bank cash and card amount owed remain distinct, with no combined net figure in Sprint 91A.

Funding retains the four existing calculation outputs and currency contexts, with one relevant unavailable-data or partial-input explanation. **Owner-directed empty-state correction, 2026-09-13, clarified 2026-09-14:** when there is no saved current-month plan, show the subordinate **Current-month Salary & Funding** heading, “No saved plan for the current month.” and a compact **Open Salary** action, instead of four repeated unavailable values. This presentation uses the existing empty state; it does not change the plan calculation, equate missing with zero, hide unaffected outputs from a partial calculation, or conflate a missing plan with unavailable data. Recent Activity retains its accepted three-row membership/order, date, description, full Money, account/category and effect. Import Activity remains secondary and Attention retains its exact authoritative condition and omission. Only the existing **View Transactions**, **Open Import** and **Open Salary** routes are interactive; metric, funding and activity rows remain display-only. No charts, sample numbers, financial recolouring or artwork annotation panels enter the app.

### 4.2 Supported content only

Do not reproduce the collage's trend lines, change percentages, Income/Expenses wording or charts unless their independent analytical authority exists in a later approved outcome. Omit unsupported widgets instead of creating empty advertising space for future modules.

The funding summary reads the accepted plan calculation. A short route to Salary is appropriate, but this refresh must not change formulas, investment-capacity meaning, FX rounding, selected balances or monthly rollover. Salary actuals, bank receipts and estimates remain distinct.

Recent activity can navigate to its existing account or transaction details only through supported routes. Filtered drill-down is an intended interaction where the relevant filtering/navigation implementation is included; it is not permission to add unrelated workflows during a visual packet.

### 4.3 Feedback

Loading, empty, unavailable and failed are different states. Never display zero financial values as a loading placeholder. Show data freshness limits without claiming live bank connectivity. “Saved, view refresh required” remains distinct from “Nothing saved”; the design cannot simplify away that difference.
