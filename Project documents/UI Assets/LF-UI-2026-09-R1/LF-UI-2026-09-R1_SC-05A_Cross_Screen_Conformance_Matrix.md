# SC-05A — Cross-Screen Conformance Matrix

**Revision:** LF-UI-2026-09-R1 / SC-05A  
**Review date:** 11 September 2026  
**Status:** Draft audit for coordinator review. Source/reference comparison, not native-screen acceptance.  
**Destinations:** Dashboard · Accounts · Transactions · Import · Salary · Settings

## 1. Result and evidence boundary

**The shared shell and panel foundation should be kept. The small cleanup candidates are inconsistent page insets, Salary display/copy details, and Import terminal/history presentation.** Narrow-width fit, composed materials and focus behavior still need observations in the actual app before they become defects or edits.

This is one conformance matrix, not a new design board, app screen, component library, implementation prompt or sprint authorization. The accepted SC references are comparison targets and remain unchanged.

### Which “existing app” was audited

| Evidence layer | Exact basis | What it establishes |
| --- | --- | --- |
| Current repository documentation | `main@000dfd3866603ed1fd1153afbd37a23573ad342c` | Current status, scope and ownership of planned work. E01–E04, E11. |
| Latest accepted executable baseline | Sprint 88, `4f5eeb7b11c0f5879204a06ae9f08045304342b5` | The six inspected destination implementations and shared presentation. E05–E10. |
| Accepted design direction | User/coordinator decisions in this conversation: SC-01; SC-02 A/B/C; SC-03 A/B/C; SC-04 A/B and the explicitly bounded SC-04 state requirements | Target appearance/interaction rules, not implemented product state. **U** below refers to those decisions. No additional acceptance of SC-04C is inferred from this audit. |
| Native visual evidence | Earlier supplied screenshots and design references are not a matched current six-destination runtime set | They cannot prove today's pixel fit, focus behavior or post-89–91 conformance. No current native pass/fail is assigned from them. |

**Important:** current PROJECT_STATE records Sprint 89 as **PAUSED / UNACCEPTED WIP**, while Sprint 88 remains the accepted implementation. The audit therefore does not promote WIP into the baseline. The prepared roadmap places cross-screen cleanup after 89–91. Missing Transactions/Dashboard/Appearance implementations are not automatically Sprint-92 polish tasks. [E01](https://github.com/vyom92/LedgerForge/blob/000dfd3866603ed1fd1153afbd37a23573ad342c/Project%20documents/PROJECT_STATE.md) · [E02](https://github.com/vyom92/LedgerForge/blob/000dfd3866603ed1fd1153afbd37a23573ad342c/Project%20documents/Sprint%20roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md)

The accepted Sprint-88 record also states that physical resizing was not separately completed. Small reference frames are therefore design targets, not proof that the existing app supports or behaves correctly at those sizes. No app was launched or tested for this matrix.

## 2. Matrix

**K — Keep:** a shared or intentionally distinct structure is supported by inspected source/accepted design. It is not a runtime PASS.  
**P1–P6 — Polish candidate:** a concrete source difference with a bounded presentation correction below; recheck after 89–91.  
**N1–N3 — Native check:** a named observation is missing; no defect asserted.  
**89 / 90 / 91 — Earlier owner:** implement under that already-recorded boundary, then audit only any residue in Sprint 92. Not authorization.  
**— — Not applicable.** Combined entries retain both qualifications.

| ID | Comparison | Dashboard | Accounts | Transactions | Import | Salary | Settings |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | Page title / subtitle hierarchy | K | K | K | K | K | K |
| 02 | Sidebar / icon rail | K · 89 | K · 89 | K · 89 | K · 89 | K · 89 | K · 89 |
| 03 | Contextual toolbar placement | K | K | 89 | K | K | 91 |
| 04 | Page / panel spacing | P1 | P1 | P1 / 89 | P1 | P1 | P1 / 91 |
| 05 | Panel material / appearance | K · 91 | K · 91 | K · 89/91 | K · 91 | K · 91 | 91 |
| 06 | Buttons / action hierarchy | N1 · 90 | N1 | N1 · 89 | N1 | N1 | N1 · 91 |
| 07 | Tables / list rows | 90 | N2 | 89 | N2 | N2 | K |
| 08 | Money / currency readability | 90 | N2 | 89 | N2 | P2 · N2 | — |
| 09 | Empty / loading / unavailable | 90 | K · N1 | 89 | P3 · N1 | K · N1 | K · N1 |
| 10 | Clipping / overlap | N2 · 90 | N2 | N2 · 89 | N2 | N2 | N2 · 91 |
| 11 | Constrained-width reflow | 90 | N2 | 89 | N2 | K · N2 | N2 · 91 |
| 12 | Terminology consistency | 90 | K | 89 | P5 | P4 | K · 91 |
| 13 | Focus versus selection | N3 | N3 | N3 · 89 | N3 | N3 | N3 · 91 |
| 14 | Icon names / tooltips | K · N3 | N3 | N3 · 89 | N3 | P6 | N3 · 91 |
| 15 | Scroll ownership | K · N2 | K · N2 | K · N2 | K · N2 | K · N2 | K · N2 |

### Per-row evidence and interpretation

**01 · Page title / subtitle hierarchy.** One shared page-title/subtitle implementation. No new headings, taglines or second page title. E05–E08.

**02 · Sidebar / icon rail.** Six destinations and developer gating already shared. Native collapse/rail adoption belongs to prior shared R1 work, not six Sprint-92 implementations. E03–E06; U.

**03 · Contextual toolbar placement.** Preserve existing action location/command. Transactions controls and the simple Settings appearance surface have earlier owners. E05–E08; U.

**04 · Page / panel spacing.** 28-pt shared toolbar and five destination margins versus 24-pt Salary content. LFPanel itself is already shared. E05–E09.

**05 · Panel material / appearance.** Reuse the shared panel/material roles. Later residual exceptions need a visual check, not another theme system. E05, E09, E10.

**06 · Buttons / action hierarchy.** Gradient/plain and native bordered controls coexist. Compare like action roles after appearance adoption; differing roles may legitimately differ. E05–E08.

**07 · Tables / list rows.** Do not impose a single row interaction everywhere: account selection, import review and Salary editing are distinct; Dashboard rows remain display-only under SC-03. E04, E06–E08; U.

**08 · Money / currency readability.** Existing formatting is not proof of complete-value fit. Salary display values omit tabular-digit treatment used elsewhere. No formatting or financial calculation change. E06–E08.

**09 · Empty / loading / unavailable.** Keep current typed conditions and recovery actions. Import terminal outcome can coexist with “No statement prepared.” E05–E08.

**10 · Clipping / overlap.** No current matched-window native capture set is available. Fixed-width source constraints identify where to inspect; they are not measured runtime failures. E01, E05–E08.

**11 · Constrained-width reflow.** Salary already switches columns at 850 pt of available geometry; Accounts/Settings retain fixed width commitments. Do not replace accepted narrow designs. E06–E08; U.

**12 · Terminology consistency.** Use explicit existing destinations and accurate state meaning. Never flatten “Not printed”, “Unassigned”, “Incomplete” and “Unavailable” into one word. E04, E06–E08; U.

**13 · Focus versus selection.** Ordinary control operation only. Do not give display cards or Dashboard activity rows new focus/selection interactions. E03–E08; U.

**14 · Icon names / tooltips.** Full sidebar names exist. Check tooltips when the rail is implemented. Salary Remove commitment already has a name but no .help modifier on that button. E05, E08; U.

**15 · Scroll ownership.** Dashboard/Accounts/Salary/Settings have an outer content scroll; Transactions and Import have distinct bounded workspace/detail scrolls. Preserve purposeful splits. E05–E08.

## 3. Smallest supported polish candidates

These are audit findings, **not six authorized changes**. Remove a candidate if earlier implementation already resolves it. Salary remains lower priority except for actual unreadability or misleading wording.

### P1 — Align existing outer content insets

**Observed in source:** `AppShellToolbar` has 28-pt horizontal padding. Dashboard, Accounts, Transactions, Import and Settings use 28-pt content padding; Salary uses 24 pt. Shared `LFPanel` already supplies 16-pt inner padding. This produces a 4-pt source-level leading-edge difference on Salary; no new pixel measurement is claimed. **E05–E09.**

**Smallest correction:** use the same accepted outer inset for the shared header and each destination container. If the prior R1 implementation retains its specified 24-pt page inset, consume that value rather than adding another local constant. Leave internal form/table layouts, the existing 16-pt panel padding, controls and workflow ownership alone. Do not mechanically convert every 14/18/20-pt internal gap: different roles can justify different spacing.

**Check:** page heading and first major content boundary align at the same window size in all six destinations. A shared wrapper correction is one finding, not six independent redesigns.

### P2 — Match Salary's display-number treatment

**Observed in source:** Dashboard account balances, Account detail balances and Transactions display amounts use `.monospacedDigit()`. Salary result rows and the inspected payslip-history amount labels use `MoneyFormatting.display` without that same tabular-digit treatment. **E06–E08.**

**Smallest correction:** apply the existing tabular-number style to display-only Salary Money. Preserve complete currency/sign/fractional text; let the existing row grow or reflow if necessary. Keep natural-entry text fields, parsing, calculations, validation and Save untouched. Do not add a number/font preference.

**Check:** compare the same displayed Money before/after and confirm unchanged characters, currency and value; only presentation changes. Actual long-value fit remains N2.

### P3 — Make Import's terminal review area agree with its result

**Observed in source:** `ValidationReviewPresentation.presentation` returns `noStatementPrepared` for terminal/completed states. The left result can concurrently show the completed import and valid existing destination actions. That is a source-confirmed contradictory-looking composition, not evidence that persistence failed. **E06, lines 1–235 and 2500–2850.**

**Smallest correction:** use the existing terminal state to suppress the obsolete “No statement prepared” prompt or give that region a neutral, state-accurate completion message. Keep active-item switching, result history, footer actions and all prepared/confirmed/cancelled/recovery rules unchanged. This does **not** select Import Preview A or B, move the preview or introduce another result screen.

**Check:** idle still offers file selection; a completed result does not look like an unfinished preparation; committed-but-refresh-needed guidance is never relabelled as fully successful.

### P4 — Clarify two existing Salary labels

**Observed in source:** `SalaryView` labels payslip totals “Salary received” with the qualifier “Total from payslips”. Its rate heading reads “1 QAR = INR per QAR”. Both strings are present in the accepted implementation. **E08.**

**Smallest correction:** change the first label to **“Salary actuals”**, retaining **“Total from payslips”** and the existing no-payslip state. Change the rate heading to **“Planning rate (INR per QAR)”**. Preserve the field, rate direction, dated context, values, manual entry and all calculations. These labels describe existing evidence; they must not imply a bank receipt or introduce current/live FX.

**Check:** the same values and source qualifiers remain visible. No new data mapping or route is required.

### P5 — Present Import-history timestamps consistently

**Observed in source:** Import History prints `attempt.createdAtISO` directly; a prior-import detail also displays `previousImportCompletedAtISO`. Other date surfaces use presentation formatting rather than showing the raw storage string. **E06, lines 2500–2850; E07.**

**Smallest correction:** for an existing import timestamp, reuse the established timestamp display policy, with its time/zone meaning intact. If no suitable existing formatter/policy is established, retain the value and leave the candidate unresolved—do not create a new date engine. Never apply timestamp conversion to financial date-only values, and never use import time as a balance or transaction date.

**Check:** history and prior-import details describe the same instant; source dates, source order and stored strings are unchanged.

### P6 — Give the existing Salary remove icon its existing name on hover

**Observed in source:** the commitment delete button already has the name “Remove commitment”, but the inspected button has no `.help` tooltip modifier. **E08.**

**Smallest correction:** attach **“Remove commitment”** as the ordinary tooltip for this existing icon-only control. Do not add a new control, shortcut, confirmation flow or accessibility programme. For any other icon, change nothing until an actual missing name/tooltip is found.

**Check:** hover reveals the same existing action name; the action and its current gating are unchanged.

## 4. Checks that are not defects yet

### N1 — Same visual role, not identical controls everywhere

The shell uses a custom gradient Import button; Account editing and Salary Save use native bordered/prominent buttons; Import includes both. `LFPanel` titles are shared, while some nested workflow headings use `title3` or `title2`. These are source differences, but role differences can be intentional. **E05–E09.**

After the accepted two-preference appearance implementation, compare equivalent primary/secondary actions and same-level headings. Correct only a concrete residual inconsistency by using the existing shared style. Do not reskin every button, turn all headings into the same size or remove meaningful domain-specific status wording. Verify Dark/Light/System through the existing choices, without adding appearance options.

### N2 — Complete-value fit and scroll boundaries

| Destination | Specific source constraint to inspect | Smallest permissible response if the problem is observed |
| --- | --- | --- |
| Dashboard | Multi-currency metrics in one HStack; four funding values in another | Owned by Sprint 90 / SC-03. Check only remaining fit against the accepted responsive reference afterward. |
| Accounts | An always-present 344-pt account-detail region next to a flexible list, plus currency summaries in an HStack | Reflow the same existing list/detail content or remove an unnecessary width constraint. No new inspector button, filters, tabs, lifecycle controls or financial aggregation. |
| Transactions | Always-present 330-pt detail panel and fixed-width table fields | Owned by Sprint 89 / SC-02. Do not implement its filters/collapse/sorting under cleanup. |
| Import | Two bounded scroll regions and a multi-action footer; long validation/outcome text | Keep existing pane ownership; adjust only proven clipping/spacing or footer wrapping. Choosing a preview relocation remains separate. |
| Salary | Existing 850-pt column switch, header actions, long result rows, 150-pt input maxima and history disclosure headings | Reflow existing rows/actions where genuinely needed. Do not replace the editor or alter draft/Save behavior. |
| Settings | 330-pt columns and 678-pt Category Management width | After SC-04 adoption, let existing sections fit/stack. Do not add a Settings sub-navigation or move unrelated functions into new screens. |

Source inspection identifies these constraints, but does **not** prove their rendered severity. Use the actual supported window range, a long existing description/label and complete native Money already present in the app. No fabricated financial dataset or derived financial evidence file is needed or authorized.

A Dashboard can have one primary vertical content scroll. A Transactions table and its existing detail pane, or the two existing Import review regions, can each have a purposeful bounded scroll. “One sensible scroll owner” does not mean merging every pane into a new global scroll or removing useful independent review behavior. No nested unbounded same-content scrolling should be introduced.

### N3 — Ordinary focus, selection and names

Inspect actual navigation, existing table/list selections, native preference choices and current route buttons. The shared sidebar has text labels and selected styling; source alone does not prove the focus ring is visible. The icon rail's later implementation needs the already-approved names/tooltips and order.

A hover/focus correction must not make a display-only balance card, Salary output or Dashboard activity row actionable. Accounts selection and Import's existing selection/review behavior are intentionally different. No new keyboard navigation framework, formal qualification gate or certification is proposed.

## 5. Changes already owned elsewhere — do not duplicate

| Existing owner | Difference visible in the accepted baseline | SC-05 disposition |
| --- | --- | --- |
| Sprint 89 / SC-02 and shared R1 patterns | Transactions filters/sort/scoped summaries, detail access and narrow composition; shared navigation adaptation | Earlier implementation, not Sprint-92 feature work. The current “Collapse” footer is a static Label, not a working rail implementation. |
| Sprint 90 / SC-03 | Currency grouping, bank/card distinction, Dashboard funding/recent-activity composition and removal of hydration from Import Activity | Earlier implementation. Keep the already-agreed “Required QAR principal”, “View Transactions” and “Open Import” wording when their existing routes are rendered; no new destinations. |
| Sprint 91 / SC-04 | Fixed dark scheme becomes the accepted local Appearance/Accent choice | Exactly Follow System/Light/Dark and System Accent/Deep Indigo; immediate local application. No broader theme settings. |

The approved icon rail is a later R1 interaction, not retroactively a Sprint-88 invariant. Formal-accessibility captions and former font/density/transparency/Preview–Apply requirements in old assets remain superseded. Do not regenerate the accepted images or revive rejected work to satisfy an obsolete caption. **E03–E04, E11; U.**

## 6. Stop boundary and next review

The matrix proposes no executable change, no new screen and no new control. It does not change filtering, accounting, account identity, source dates, totals, Salary formulas, import confirmation/cancellation, typed recovery or preference storage.

Before Sprint-92 edits, rebase this **audit**, not the repository: compare the then-accepted 89–91 implementation, close findings already resolved, and confirm only the remaining observations in the actual six destinations. An unavailable screenshot/interaction is **Not checked**, never PASS or an assumed defect. Preserve the accepted references and already-working workflows.

**SC-05A is returned for coordinator review. No SC-05B, image regeneration, implementation prompt, Git write, app run or test campaign is included.**

## 7. Evidence index

Repository links below are pinned. Source inspection was limited to presentation/related scope documentation; no private originals, personal account data or financial workbook content was used. An unsuccessful direct source-download attempt supplied no evidence; the GitHub connector reads listed here are the source basis.

- **E01 — [Current accepted-state boundary](https://github.com/vyom92/LedgerForge/blob/000dfd3866603ed1fd1153afbd37a23573ad342c/Project%20documents/PROJECT_STATE.md)** · `Project documents/PROJECT_STATE.md`. Sprint 88 accepted; Sprint 89 paused/unaccepted; native resize limitation.
- **E02 — [Prepared Sprint-92 boundary](https://github.com/vyom92/LedgerForge/blob/000dfd3866603ed1fd1153afbd37a23573ad342c/Project%20documents/Sprint%20roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md)** · `Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md`. Sprint 92 selects actual owner usability after 89–91; no formal accessibility campaign.
- **E03 — [Shared R1 authority](https://github.com/vyom92/LedgerForge/blob/000dfd3866603ed1fd1153afbd37a23573ad342c/Project%20documents/UI%20Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md)** · `Project documents/UI Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md`. Readable Money, shared roles, ordinary keyboard operation and exact obsolete-caption exceptions.
- **E04 — [Inherited screens and simple appearance](https://github.com/vyom92/LedgerForge/blob/000dfd3866603ed1fd1153afbd37a23573ad342c/Project%20documents/UI%20Assets/LF-UI-2026-09-R1/Inherited_Screens.md)** · `Project documents/UI Assets/LF-UI-2026-09-R1/Inherited_Screens.md`. Existing Accounts/Import/Salary/Settings behavior; simple local appearance; preserve editor/recovery semantics.
- **E05 — [Shared shell](https://github.com/vyom92/LedgerForge/blob/4f5eeb7b11c0f5879204a06ae9f08045304342b5/AppShellPresentation.swift)** · `AppShellPresentation.swift`. AppShellView, AppShellSidebar, AppShellToolbar. Full source inspected.
- **E06 — [Destination composition](https://github.com/vyom92/LedgerForge/blob/4f5eeb7b11c0f5879204a06ae9f08045304342b5/ContentView.swift)** · `ContentView.swift`. Inspected lines 1–235, 1450–2240 and 2500–2850: destinations, Dashboard, Accounts, Import, Settings and outcome/history presentation.
- **E07 — [Transactions implementation](https://github.com/vyom92/LedgerForge/blob/4f5eeb7b11c0f5879204a06ae9f08045304342b5/Views/TransactionListView.swift)** · `Views/TransactionListView.swift`. Inspected lines 1–310: workspace, summary, filters, table, detail, empty state and category recovery.
- **E08 — [Salary implementation](https://github.com/vyom92/LedgerForge/blob/4f5eeb7b11c0f5879204a06ae9f08045304342b5/Views/SalaryView.swift)** · `Views/SalaryView.swift`. Full source inspected: This Month/History, layout, input labels, display Money, Save and recovery.
- **E09 — [Shared panel](https://github.com/vyom92/LedgerForge/blob/4f5eeb7b11c0f5879204a06ae9f08045304342b5/Views/Common/LFPanel.swift)** · `Views/Common/LFPanel.swift`. Full source inspected: title, padding, spacing, surface and border.
- **E10 — [Shared colours](https://github.com/vyom92/LedgerForge/blob/4f5eeb7b11c0f5879204a06ae9f08045304342b5/Views/Common/LFTheme.swift)** · `Views/Common/LFTheme.swift`. Full source inspected: fixed palette, translucency and gradients.
- **E11 — [Current owner scope](https://github.com/vyom92/LedgerForge/blob/000dfd3866603ed1fd1153afbd37a23573ad342c/Project%20documents/SCOPE_DECISIONS.md)** · `Project documents/SCOPE_DECISIONS.md`. Private personal app; exclusions of formal accessibility and advanced appearance; no financial-evidence generation.

**U — User/coordinator decisions in this conversation:** SC-05's exact six-destination cleanup scope; approved SC-02/03 structures; icon-only rail preference; noninteractive Dashboard display cards/activity rows; ordinary keyboard/naming only; immediate device-local two-preference Appearance. These user decisions take precedence over older instructions. SC-04C remains a supplied state reference, not independently accepted here.

The uploaded July/August private roadmaps and MCP release reports were not used as current product-state evidence. Old runtime screenshots were not promoted to post-Sprint-88/89/90/91 evidence. No numeric financial values or sample records are reproduced in this deliverable.
