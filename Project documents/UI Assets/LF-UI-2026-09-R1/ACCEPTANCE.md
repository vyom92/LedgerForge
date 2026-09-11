# R1 implementation acceptance

**Revision:** LF-UI-2026-09-R1. Requirements only; no native pass is implied. Use only the applicable rows of a separately approved implementation contract. [README](README.md) owns canonical/draft routing; [SOURCES](SOURCES.md) retains original registration provenance. The original docs-only no-publication checklist is historical and superseded by subsequent explicit publication instructions; [Harness](../../LedgerForge_Standing_Execution_Harness_Guide.md) owns current documentation checks.

Order inherits [Guide rules H/J](../../Project_Guide.md#documentation-order): shared prerequisites, SC-02 Transactions, SC-03 Dashboard, simple appearance, then final truthfulness checks; natural numeric IDs within each group.

## Required native-app checks

Select only the rows applicable to each separately approved implementation packet. Use authentic, read-only source-backed data where statement-dependent values are exercised. Never extract the collage's sample values into a financial fixture or DTO graph.

| ID | Requirement and falsification test |
|---|---|
| UI-01 | Compare matched logical window sizes at 1440 × 900 and 1024 × 768; inspect actual content fit and ordinary readability. No amount wraps, truncates or loses its currency context. |
| UI-02 | Light, Dark and Follow System render coherently. System mode changes do not alter explicit Light/Dark selection. |
| UI-03 | Sidebar and inspector collapse without losing access to navigation, active filters, selection or details. |
| UI-04 | Keyboard reaches search, filters, sort headings, rows and inspector; focus is visible and distinct from selection. |
| UI-05 | Controls retain meaningful names and useful icon tooltips; full amounts, currency and current states are readable. Colour is not the only status cue. |
| UI-06 | Empty repository, no matches, loading, unavailable and failure have distinct text and valid actions; none fabricates zero data. |
| TX-01 | Each filter matches independently checked canonical records. Combined groups use AND; within-group selections use OR. |
| TX-02 | Search respects the documented field/term scope; clearing it restores matching rows without changing data. |
| TX-03 | Custom date boundaries are inclusive and use displayed source-date roles. Date-only values do not shift across timezones. |
| TX-04 | Every sortable heading reverses order deterministically; tied/missing values follow a documented stable rule. |
| TX-05 | Multiple currencies are grouped for amount sorting; no hidden FX conversion or unlike-currency numeric ranking occurs. |
| TX-06 | Totals cover all matches, not selected/visible rows. Bank cash flow and card liability effects are not silently combined. |
| TX-07 | Independent expected aggregates agree with the UI. Specifically revisit the screenshot's apparent identical inflow/outflow plus non-zero net before presentation acceptance. |
| TX-08 | Sorting/filtering leaves financial values, source ordinals, source balances and durable identities unchanged. |
| TX-09 | Narrow layout retains account and currency context; removing a selected row from results clears its details without selecting another record. |
| TX-10 | Source running balance remains source evidence after sorting, not a recomputed running result. |
| DB-01 | Currency groups separate bank position and card liability; omitted unsupported analytics do not reappear as decorative truths. |
| DB-02 | Flow period and balance-as-of information are not confused; unavailable dates remain unavailable. |
| DB-03 | Funding summary reads the existing accepted calculation without changed FX, fee, balance or investment semantics. |
| AP-01 | Follow System/Light/Dark and any selected existing accent choice render readable controls and complete tabular Money. |
| AP-02 | The local appearance choice survives relaunch; malformed values fall back without blocking financial hydration. |
| AP-03 | Appearance changes leave imported data and financial settings unchanged. No advanced preference or portable-workspace matrix is required. |
| SAFE-01 | No renamed “Cleared/Reconciled/Income/Spending/Net worth” label overstates the underlying accepted authority. |
| SAFE-02 | The final report distinguishes static token checks, screenshot inspection, user interaction, build/test evidence and financial oracle evidence. |

## Evidence record per implementation packet

Report the exact code ref, runtime build identity, logical window dimensions, appearance choice, tested actions, named assertions, actual results and remaining gaps. Keep private originals isolated as read-only source evidence in their approved source location; they are never included in published repository artifacts. The owner’s [current processing rule](../../SCOPE_DECISIONS.md#source-processing-decision) prohibits derived financial evidence files on disk; source/oracle comparison stays in memory, while the normal app database remains permitted. Report only permitted operational evidence. Existing images remain preserved historical/reference bytes. Record independent-oracle use for financial aggregates, and provider/hydration/relaunch evidence when those boundaries are changed. A passing build or visually plausible screenshot alone is insufficient.
