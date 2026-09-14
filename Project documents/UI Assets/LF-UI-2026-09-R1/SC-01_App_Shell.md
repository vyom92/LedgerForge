# SC-01 — App shell

Canonical approved written R1 shell contract. Read the [responsibility-based shared authority](DESIGN_HANDOFF.md#authority), [numeric tokens](DESIGN_TOKENS.json) and [required checks](ACCEPTANCE.md). The approved [SC-01 visual contract](LF-UI-2026-09-R1_SC-01_App_Shell_Visual_Contract.png) controls overall navigation/chrome appearance; the [supporting artwork](LF-UI-2026-09-R1_SC-01_App_Shell_Supporting_Reference.png) is supplementary. The written contract controls the functional boundaries below. Image approval is separate from native implementation acceptance.

**Accepted Sprint 91A — 2026-09-14:** the owner accepts the shared shell/material foundation, all-six Collapse/Expand and current application/sidebar identity. The [accepted outcome](../../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-91a) records native evidence and the final-byte small-window recheck limitation. The [2026-09-13 qualification](../../Work%20notes/Transaction_and_R1_workflows.md#sprint-91a-visual-conformance) is retained as history; its initial exclusions were superseded only by the explicit extensions below.

**2026-09-14 explicit owner extension:** the owner subsequently authorized consistent sidebar width and the existing Collapse/Expand action on all six ordinary destinations. This specifically supersedes the earlier prohibition on making the decorative Collapse label functional. The linked Sprint-91A working note owns the exact transient-state, width, threshold and validation boundaries. No new destination or stored collapse preference is introduced; this behavior is included in the accepted 91A outcome. The later [2026-09-14 owner decision](../../SCOPE_DECISIONS.md#dark-appearance-decision) additionally permits local appearance preferences, a Settings-only minimum adjustment, and a seamless title bar with sidebar tint extending behind the retained native traffic lights. It preserves the existing navigation and window ownership.

### 1.1 Overall product structure

Retain the existing primary destinations: **Dashboard, Accounts, Transactions, Import, Salary, Settings**. Developer Console remains available only through the accepted developer/build gates. Do not introduce inactive destinations, new workspaces or separate institution-specific applications.

The layout remains sidebar, contextual toolbar and primary content. Use one clear page title. Do not restore the static “Vyom / Personal” block, greetings, profile menu or notification badge merely because they appear in artwork. These are not required functional surfaces.

Toolbar actions belong to the active task. Accepted 91A removes the repeated shared-header Import Statement action; Import’s local chooser/empty-state actions and Dashboard Open Import remain. Settings foregrounds its own controls; Developer Console foregrounds diagnostic actions. Preserve existing supported routes and keyboard behavior.

### 1.2 Responsive hierarchy

Use **1440 × 900** and **1024 × 768 logical points** as comparison frames, not as a change to the supported minimum window size. A later implementation packet must establish any minimum-size change explicitly.

Standard Transactions layout: sidebar, searchable/filterable table and optional inspector. In the narrow layout, close the inspector first and retain a labelled Show details control. Prefer an icon-only navigation rail at constrained widths. Hide navigation only when even the rail materially harms usable content width; retain a labelled Show Navigation control. Preserve destination order, selection, focus, useful keyboard access and Developer Console gating. Each rail icon retains a name and tooltip. A compact drawing with hidden navigation is a last-resort example, not an automatic width breakpoint. Move secondary filters under a labelled Filters control with an active-filter count. Never drop account identity, currency or an applied-filter indication solely to fit the window.

Adapt based on measured content fit, not window width alone. Preserve date, description and complete native amount; show account/category on secondary lines or retain horizontal scrolling when required. Reopening details must not lose selection or filter state.

The Dashboard uses at most two currency groups side by side and stacks them when content cannot fit. A group may lay out its metrics vertically. Do not repeat four independent cards per currency across one unbounded row.
