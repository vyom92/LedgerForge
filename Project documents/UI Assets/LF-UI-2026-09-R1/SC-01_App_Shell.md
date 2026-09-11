# SC-01 — App shell

Canonical approved **written** R1 contract relocated from DESIGN_HANDOFF; no new visual direction or native acceptance is claimed. Read [shared design requirements](DESIGN_HANDOFF.md), [numeric tokens](DESIGN_TOKENS.json) and [required checks](ACCEPTANCE.md). Supporting local SC drafts/PNGs are identified in [README](README.md); they do not override this text.

### 1.1 Overall product structure

Retain the existing primary destinations: **Dashboard, Accounts, Transactions, Import, Salary, Settings**. Developer Console remains available only through the accepted developer/build gates. Do not introduce inactive destinations, new workspaces or separate institution-specific applications.

The layout remains sidebar, contextual toolbar and primary content. Use one clear page title. Do not restore the static “Vyom / Personal” block, greetings, profile menu or notification badge merely because they appear in artwork. These are not required functional surfaces.

Toolbar actions belong to the active task. Financial destinations retain access to the supported import command. Settings foregrounds its own controls; Developer Console foregrounds diagnostic actions. Preserve keyboard access to import rather than forcing an identical dominant button onto every page.

### 1.2 Responsive hierarchy

Use **1440 × 900** and **1024 × 768 logical points** as comparison frames, not as a change to the supported minimum window size. A later implementation packet must establish any minimum-size change explicitly.

Standard Transactions layout: sidebar, searchable/filterable table and optional inspector. In the narrow layout, close the inspector first and retain a labelled Show details control. Prefer an icon-only navigation rail at constrained widths. Hide navigation only when even the rail materially harms usable content width; retain a labelled Show Navigation control. Preserve destination order, selection, focus, useful keyboard access and Developer Console gating. Each rail icon retains a name and tooltip. A compact drawing with hidden navigation is a last-resort example, not an automatic width breakpoint. Move secondary filters under a labelled Filters control with an active-filter count. Never drop account identity, currency or an applied-filter indication solely to fit the window.

Adapt based on measured content fit, not window width alone. Preserve date, description and complete native amount; show account/category on secondary lines or retain horizontal scrolling when required. Reopening details must not lose selection or filter state.

The Dashboard uses at most two currency groups side by side and stacks them when content cannot fit. A group may lay out its metrics vertically. Do not repeat four independent cards per currency across one unbounded row.
