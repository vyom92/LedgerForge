# LedgerForge UI implementation handoff

**Revision:** LF-UI-2026-09-R1  
**Prepared:** 2026-09-09  
**Repository baseline:** `main@d8124ef5a1f38a1e7547f4f8905c91f25b2f1194`  
**Status:** Approved visual direction; consolidated written design specification; not implemented or natively verified.  
**Scope:** Presentation and interaction requirements, not a sprint selection or financial-domain redesign.

**Publication alignment — 2026-09-10:** At the user's explicit direction, this handoff is published under `Project documents/UI Assets/LF-UI-2026-09-R1/`, the unchanged legacy PNGs are archived under `Project documents/UI Assets/Archived/`, and the sprint roadmaps are organized under `Project documents/Sprint roadmap/`. These layout changes do not claim native implementation or financial validation.

## 0. Authority, approval and provenance

The user approved the latest supplied collage labelled **LedgerForge v2.0**, following the agreed practical refresh: adaptive appearance, readable currency summaries, usable transaction filters/sorting, and native desktop interactions. The exact approved PNG is retained, without editing or recompression, as [MasterBoard_LF-UI-2026-09-R1.png](MasterBoard_LF-UI-2026-09-R1.png). Its embedded “v2.0” is not an app release version and does not identify the older repository `DesignBoard_v2.0.png`.

Approval covers the visual direction and agreed requirements. The numeric sizes, token defaults and detailed interactions below are the designer's explicit implementation specification, prepared now; they are not claimed to have been individually measured from or approved as pixels in the collage. Native implementation and acceptance remain separate.

The following order applies to this handoff: explicit user decisions and accepted financial/architecture contracts; this written specification and its documented visual exceptions; the token file; the approved collage for appearance/composition; inherited legacy references for untouched screens. Register this relationship through the existing UI specification and ADR-023 before implementation. The handoff does not independently rewrite repository authority.

**Repository evidence at preparation:** the source baseline recorded V17, ADR-046, the accepted startup/monthly-planner corrections, and personal-v1 undeclared. Natural amount entry and coherent Salary Save were accepted work; the roadmap then retained PR-1 before a serial Unified Import Centre. Sprint 82 is now accepted in the current roadmap, while this handoff still assigns no sprint number or migration. See [SOURCES.md](SOURCES.md).

**Explicit user decisions:** avoid a compulsory fixed palette; offer simple appearance controls with optional advanced customization; include Transactions filtering/sorting; use Budget Analysis for task flow and existing master assets as an evolvable visual reference; keep Salary refinement lower priority. The user identifies supplied runtime data as disposable. This does not authorize publishing private originals or unsanitized private-source material or manufacturing financial acceptance inputs; approved sanitized, clean-room or privacy-safe derived artifacts remain governed by the repository privacy policy.

## 1. Master design board: shell and information hierarchy

### 1.1 Overall product structure

Retain the existing primary destinations: **Dashboard, Accounts, Transactions, Import, Salary, Settings**. Developer Console remains available only through the accepted developer/build gates. Do not introduce inactive destinations, new workspaces or separate institution-specific applications.

The layout remains sidebar, contextual toolbar and primary content. Use one clear page title. Do not restore the static “Vyom / Personal” block, greetings, profile menu or notification badge merely because they appear in artwork. These are not required functional surfaces.

Toolbar actions belong to the active task. Financial destinations retain access to the supported import command. Settings foregrounds its own controls; Developer Console foregrounds diagnostic actions. Preserve keyboard access to import rather than forcing an identical dominant button onto every page.

### 1.2 Responsive hierarchy

Use **1440 × 900** and **1024 × 768 logical points** as comparison frames, not as a change to the supported minimum window size. A later implementation packet must establish any minimum-size change explicitly.

Standard Transactions layout: sidebar, searchable/filterable table and optional inspector. In the narrow layout, close the inspector first and offer it through a clearly labelled control; collapse the sidebar when needed. Keep its navigation toggle accessible. Move secondary filters under a labelled Filters control with an active-filter count. Never drop account identity, currency or an applied-filter indication solely to fit the window.

At larger font sizes, adapt based on measured content fit, not window width alone. Preserve date, description and complete native amount; show account/category on secondary lines or retain horizontal scrolling when required. Reopening details must not lose selection or filter state.

The Dashboard uses at most two currency groups side by side and stacks them when content cannot fit. A group may lay out its metrics vertically. Do not repeat four independent cards per currency across one unbounded row.

### 1.3 Text and visual density

Use the shared token values rather than local per-view substitutions. Body text defaults to 16 points. Text size adjusts within the defined range, while captions have a 12-point floor. Compact density reduces spacing; it does not reduce text size or omit important fields.

Full amounts, minus signs, currency context and fractional digits must remain readable. Never wrap an amount, truncate it, display an unexplained abbreviation, or shrink it until it fits. Reallocate width, reflow the group or allow scrolling instead.

## 2. Shared design system and components

### 2.1 Appearance system

Default to **Follow System** with a neutral system-oriented preset. **Light** and **Dark** are explicit overrides. **Deep Indigo** is an optional preset, not the only valid appearance. The JSON palettes are deterministic fallback/reference values for the handoff, not permission to override native control accessibility.

Use semantic roles: background, surface, raised surface, primary/secondary text, control border, separator, accent, focus, selected surface and semantic status text. Do not scatter arbitrary colours through screens. Accent is not a substitute for success/error semantics. A negative number is not automatically a problem and a credit is not automatically income.

The token file records a small consistent spacing/radius scale, typography, minimum control sizes, row density, column widths and responsive policies. Sizes are minima or defaults where labelled, not rigid constraints that can crop larger text.

### 2.2 Components and states

| Component | Required interaction and state contract |
|---|---|
| Sidebar row | Label plus icon; selected state is explicit; keyboard focus remains distinguishable from selection. |
| Primary/secondary buttons | Clear action text, ordinary keyboard focus, visible pressed/disabled state. One dominant action per task region. |
| Search field | One main search per transaction workspace; clear control; search scope stated; no duplicated global/local searches without different implemented purposes. |
| Filter control/chip | Shows selection and count; removable; access is preserved when collapsed. |
| Table | Sortable/resizable supported columns; right-aligned tabular amounts; readable selection; row access by keyboard. |
| Inspector | Selected-record details; close control; stable record identity; unavailable provenance is not inferred. |
| Metric | Label, native-currency context, value and time/coverage context where available. Missing evidence is distinct from zero. |
| Money input | Natural exact user entry; deterministic validation and formatting; persisted Money validation is not weakened. |
| Feedback | Field-specific errors, meaningful empty/loading states and bounded recovery; no green “success” before durable acceptance. |
| Appearance preview | Existing draft preference values only; no financial data generation or imported-data edits. |

Check selected, focus, hover, pressed, disabled, loading, empty, no-matches, unavailable and error states. Do not add animation beyond brief purposeful transitions; accessibility preferences take precedence.

A successful import validation badge is not the same as a cleared or reconciled transaction. Prefer contextual validation information in the inspector, with prominent row attention only where an authoritative actionable state exists. Do not invent a new transaction-review status model to support a badge.

### 2.3 Accessibility boundary

All core actions need a keyboard path and useful accessibility labels. Control state cannot rely on colour alone. Honour reduced motion and reduced transparency. User text size must also affect tables and forms, not just headings.

Product contrast targets are at least 4.5:1 for ordinary text and 3:1 for meaningful control boundaries/focus against adjacent surfaces. The package checks opaque fallback token pairs only. A collage, a token check or an “AA” label is not native accessibility certification. Custom/system colours and composited materials need runtime verification.

## 3. Transactions reference

### 3.1 Standard composition

Toolbar: **Transactions**, period selector, inspector visibility and supported contextual actions. The main region contains a clearly scoped currency-grouped summary, one search field, primary filters and the table. The inspector shows the selected record. Omit unsupported Add Transaction, Export, Split, Notes and attachment actions.

Default table columns: **Date, Description, Account, Category, Amount**. Direction remains visible as text/icon or in amount presentation according to existing authoritative semantics. Source balance is optional, labelled by its actual meaning, and never a recalculated running total after sorting. Additional provenance details belong in the inspector.

Account names need a safe disambiguator when names collide. Use trusted display metadata and bounded identifiers, not inferred NRE/NRO classification or filename identity. The inspector provides complete readable description and applicable source-date roles.

### 3.2 Filters and search

| Control | Contract |
|---|---|
| Period | All dates, this month, last month, year to date, custom inclusive date range. Default is All dates so existing data is not silently hidden. The active range is always visible. |
| Accounts | Multi-select; “All accounts” when unrestricted. Filter using durable account identity. |
| Currency | Native currency, never implicit converted value. |
| Category | Current category plus Uncategorized; no rule-based categorization implied. |
| Family/direction | Expose only authoritative bank/card family and supported financial-effect values. Do not reuse bank debit/credit semantics for card liabilities without accepted mapping. |
| More Filters | Institution and optional amount range. An amount range requires a selected currency. |
| Search | Plain case-insensitive matching against supported displayed description, account, institution and current category fields. Multiple entered terms must all match somewhere in the supported fields. No fuzzy financial inference or searching undisclosed raw identifiers. |

Combine different filter groups with AND; multiple selections inside one group use OR. No checked choice means unrestricted for that group. Explicitly show when filters produce no results; offer Clear filters rather than presenting an empty database.

Date filtering uses the same approved primary source-date field shown by the row, not import time. Preserve date-only semantics without timezone shifts. A bounded date range excludes unavailable dates and reports that exclusion; All dates includes them. Do not manufacture transaction times.

**Clear filters** restores All dates, clears search and removes field restrictions. It does not reset column widths, inspector visibility or the user's sort choice. Named saved-filter sets remain separate future work; ordinary current-session state is not a saved-filter feature.

### 3.3 Sorting and state

Default to newest source date first. Clicking a supported heading selects that sort; repeating reverses it. Show direction in the heading and expose the action/state to accessibility. Support Date, Description, Account, Category and Amount as their data contracts permit.

Amount sorting is exact within a single native currency. With several currencies, group by currency before sorting amounts and label that grouping; never numerically rank mixed currencies as if converted. Missing values remain last in both directions.

Tie-breakers must be stable across refresh: preserve proven source ordinal within a source document; use durable identities only as a presentation tie-break across unrelated sources. Never claim the latter establishes historical chronology. The implementation packet must document its complete sort key before acceptance.

Sorting, filtering, resizing and opening details are read-only presentation operations. They must not change financial events, categories, source order or source balances. Keep selection by immutable identity. When filters hide the selected record, clear the visible selection/detail instead of silently selecting a different transaction.

### 3.4 Scoped summaries and totals

Summaries describe **all matching records**, not only currently rendered rows or a page, and are not changed by selecting a row. Show matching count versus available count and one summary group per currency.

Retain separate financial domains in any mixed bank/card result. Bank credits/debits may be labelled Inflow/Outflow only where the existing canonical projection supports those meanings. Card movements require their accepted liability-effect mapping. Do not sum bank cash movement and card purchases/payments into a supposed spending or income metric. If that mapping is not established in the implementation review, withhold the affected aggregate rather than invent it.

No unapproved FX conversion, transfer matching, income classification, spending analytics or net-worth calculation is added by these controls. Use independently checked authentic records to verify any financial aggregate.

### 3.5 Narrow layout

Keep search, period, active-filter indication and Sort accessible. Filters may be presented in a compact popover; all selected criteria remain inspectable. Show full amount with currency context and readable description; account/category may move to the second line. A details control opens the inspector as an appropriate constrained presentation rather than squeezing the table into unreadability.

Do not hide Currency or Amount semantics in the compact view. Do not implement artificial pagination merely to match the illustration. Existing collection/virtualization behaviour can remain if all records are accessible and counts stay truthful.

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

## 5. Appearance settings reference

### 5.1 Default view

Offer Appearance (Follow System/Light/Dark), preset (System Neutral/Deep Indigo), accent choice, Text size, Font style and Density. Keep this one simple panel with an adjacent or stacked preview. Use native controls rather than an elaborate custom theme editor.

The font-style set is intentionally small: System, Rounded and Serif. Use the locally supported system fallback; do not download or distribute fonts. Monetary columns always retain tabular/aligned digits, even when prose uses another supported style. The artwork's optional “monospace numbers” checkbox does not make amount alignment optional.

Text-size range is body-equivalent 14 to 22 points, default 16, in one-point steps. Secondary text follows the scale with its documented minimum. Comfortable and Compact change spacing and row minima, not text size or data inclusion.

### 5.2 Advanced appearance

Keep Advanced collapsed initially. It contains **Background colour**, **Foreground colour: Automatic/Custom**, and **Translucency**. Use native colour pickers with their colour-channel sliders. Do not add per-widget colour settings or a dozen interdependent sliders.

Store light and dark overrides separately; selecting one appearance does not destructively overwrite the other. Automatic foreground derives readable text roles. Validate Custom foreground/background and selection/focus combinations before Apply; explain an unreadable choice without applying it. Do not silently alter an explicitly chosen custom colour.

Translucency ranges from 0 to 30%, default 0, on eligible surfaces only. It never changes whole-window, text or amount opacity. Reduced transparency forces an opaque rendering while retaining the saved preference for later restoration. Do not allow the background to make text illegible.

### 5.3 Preview, Apply and recovery

Changing controls modifies a draft preview. **Apply** commits the validated appearance preferences together. **Cancel** discards that draft. **Restore defaults** resets the preview to the documented defaults; it takes effect only on Apply and touches appearance preferences only.

When leaving with unapplied changes, provide Keep editing or Discard, without applying silently. After Apply, relaunch restores the chosen settings. Follow System continues following system mode. Missing fonts and malformed preference values fall back to readable defaults with bounded diagnostics; they must not stop financial data loading.

Preference storage remains an implementation/architecture decision under FW-P2-52. This handoff does not choose UserDefaults, SQLite, a new settings repository or a migration. No network or financial-data mutation is required by this design.

## 6. Exact visual exceptions and inherited screens

The approved PNG remains intact as the visual reference. These limitations are explicit, not a new unapproved redraw:

| Artwork element | Implementation treatment |
|---|---|
| “v2.0” | Design-image label only; use LF-UI-2026-09-R1 to identify this handoff; do not change app version. |
| Greetings/profile chrome | Not required; keep the ordinary Dashboard title and omit static personal/workspace decoration. |
| Insights/Budgets/Reports/Investments/Soon | Omit until approved, functional, repository-backed destinations exist. |
| Add Transaction, arbitrary export, notes/splits/tags/attachments | Not authorized by this image; preserve only implemented separately approved actions. |
| Charts, percentages, sample totals and historical dates | Illustrative pixels, never financial fixtures, expected values, product facts or an independent oracle. |
| “Cleared”, salary receipt and bank/payroll association | Use only proven meanings. Import validation is not bank clearing; payroll is not bank receipt. |
| Raw identifiers and source filenames | Retain applicable privacy rules; the disposable screenshot decision does not override repository policy. |
| Always-visible Developer Console | Retain current developer/build gating. |
| Tight mobile-looking narrow table | Treat as compact composition guidance; native macOS keyboard, account and currency context remain required. |
| Optional numeric alignment | Tabular amount alignment is mandatory. |
| Multiple visible logos | No icon or branding replacement is authorized; retain the existing app asset until separately selected. |

The collage is 1536 × 1024 pixels and contains small embedded panels. It is **not** five independently rendered, full-size pixel-perfect screens, an editable native prototype or a complete component-state sheet. This written contract supplies details absent from the image. Do not claim missing renders or native interaction tests exist.

Accounts, Import, Salary and Developer Console inherit the common system while retaining their accepted behaviour. Accounts needs readable identity distinctions. Import needs coherent per-task completion/empty states, not a new queue in this task. Salary needs only later bounded refinement. Developer Console preserves typed diagnostics and clear active-profile versus selected-target labels.

## 7. Boundaries and delivery status

This package is registered as a design-reference update without native app implementation. Do not implement app screens, preference storage, queries, filters or sorting under this handoff. Preserve existing asset bytes; the user explicitly authorized their archival under `Project documents/UI Assets/Archived/` and publication of this handoff on 2026-09-10. Unchanged legacy screens remain inherited with the explicit exceptions above.

No migration, parser, Money contract, source identity, provenance, accepted financial formula or roadmap ordering changes here. A later app prompt must name its code/test surfaces and prove applicable financial mappings before implementation. Repository or runtime defects established during that work retain the project's financial-correctness priority.

**Remaining evidence gaps:** local branch/worktree/writer state; exact current native behaviour after the supplied screenshots; preference storage ownership; complete financial mapping for mixed bank/card aggregates; runtime accessibility and resizing; the apparent transaction-summary mismatch noticed in the screenshot. The latter is an observation requiring verification, not a diagnosed defect or an excuse to infer new totals.

Approval of the design is settled. Implementation acceptance is not. Use [ACCEPTANCE.md](ACCEPTANCE.md) for the bounded checks rather than reopening the visual direction at every prompt.
