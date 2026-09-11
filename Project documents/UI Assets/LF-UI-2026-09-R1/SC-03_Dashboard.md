# SC-03 — Dashboard

Canonical approved **written** R1 contract relocated from DESIGN_HANDOFF; no new visual direction or native acceptance is claimed. Read [shared design requirements](DESIGN_HANDOFF.md), [numeric tokens](DESIGN_TOKENS.json) and [required checks](ACCEPTANCE.md). Supporting local SC drafts/PNGs are identified in [README](README.md); they do not override this text.

## 4. Dashboard reference

### 4.1 Hierarchy

Show **position by native currency**, relevant attention, current-month funding summary, and recent activity. Keep Import Activity secondary. Do not show repository hydration as though it were an imported statement.

Within each currency group, distinguish bank balances from card amounts owed. A combined position is allowed only if its signed financial projection is already accepted and independently verified. It is not automatically net worth or available cash. Do not silently convert QAR and INR or assume that a credit balance on a card is bank liquidity.

Keep full amounts on one line. Use shared label/metric hierarchy and aligned labels rather than eight unrelated oversized cards. Display balance as-of/source coverage where supported; otherwise state that its date is unavailable. The flow period is distinct from balance as-of dates.

### 4.2 Supported content only

Do not reproduce the collage's trend lines, change percentages, Income/Expenses wording or charts unless their independent analytical authority exists in a later approved outcome. Omit unsupported widgets instead of creating empty advertising space for future modules.

The funding summary reads the accepted plan calculation. A short route to Salary is appropriate, but this refresh must not change formulas, investment-capacity meaning, FX rounding, selected balances or monthly rollover. Salary actuals, bank receipts and estimates remain distinct.

Recent activity can navigate to its existing account or transaction details only through supported routes. Filtered drill-down is an intended interaction where the relevant filtering/navigation implementation is included; it is not permission to add unrelated workflows during a visual packet.

### 4.3 Feedback

Loading, empty, unavailable and failed are different states. Never display zero financial values as a loading placeholder. Show data freshness limits without claiming live bank connectivity. “Saved, view refresh required” remains distinct from “Nothing saved”; the design cannot simplify away that difference.
