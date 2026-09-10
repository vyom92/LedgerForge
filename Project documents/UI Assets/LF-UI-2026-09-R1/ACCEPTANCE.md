# Acceptance checklist

**Revision:** LF-UI-2026-09-R1  
**Status:** Requirements, not a record of passed native tests.

> **Publication alignment — 2026-09-10:** The checklist below was authored for the original docs-only handoff. The user subsequently authorized the reversible asset archive/move, Xcode synchronized-folder update and sprint-roadmap publication; those actions are documented in the surrounding handoff and do not turn this checklist into native test evidence.

## A. Documentation-and-assets registration: this packet

| ID | Required evidence |
|---|---|
| DOC-01 | Starting HEAD equals the pinned base; branch/main/origin relationship and complete local safety inventory are recorded. |
| DOC-02 | Supplied approved board decodes at 1536 × 1024 and its SHA-256 equals the manifest. The destination is byte-identical. |
| DOC-03 | Every packaged design-file hash/size matches the manifest; Markdown links and JSON parse successfully. |
| DOC-04 | Only the exact allowed documentation and design paths change. No source, test, Xcode, build, dependency or database changes occur. |
| DOC-05 | All 11 legacy PNG Git blob identities are unchanged. No deletion, move, recompression or historical rewrite occurs. |
| DOC-06 | Current UI authority points to the uniquely identified new handoff for its scope; legacy inheritance and visual exceptions are explicit. |
| DOC-07 | ADR-023 receives only a dated alignment note; financial ADR decisions, roadmap sequence and migration baseline remain unchanged. |
| DOC-08 | Future work records the user's new appearance/filter requirements without claiming implementation, selecting a sprint or promoting readiness. |
| DOC-09 | Design assets are not added to executable resources or target membership. If exclusion cannot be established, stop before copying. |
| DOC-10 | The report distinguishes design approval, documentation integration, app implementation and native validation; no app test is claimed from static checks. |
| DOC-11 | End state is unstaged reviewable changes only; no commit/push/branch/PR or destructive Git operation occurs. |

No Swift build, financial import, fixture generation, TestPlan run, app launch or database reset is needed for this docs-only task. An unexpected resource/build impact is a stop condition, not permission to broaden validation and edit Xcode. Existing production results are historical baseline evidence only.

## B. Future native-app implementation acceptance

Select only the rows applicable to each separately approved implementation packet. Use authentic, read-only source-backed data where statement-dependent values are exercised. Never extract the collage's sample values into a financial fixture or DTO graph.

| ID | Requirement and falsification test |
|---|---|
| UI-01 | Compare matched logical window sizes at 1440 × 900 and 1024 × 768; repeat at largest supported text size. No amount wraps, truncates or loses its currency context. |
| UI-02 | Light, Dark and Follow System render coherently. System mode changes do not alter explicit Light/Dark selection. |
| UI-03 | Sidebar and inspector collapse without losing access to navigation, active filters, selection or details. |
| UI-04 | Keyboard reaches search, filters, sort headings, rows and inspector; focus is visible and distinct from selection. |
| UI-05 | VoiceOver receives useful labels, complete amounts, currency and current control states. Colour is not the only status cue. |
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
| AP-01 | Colour, font, size, density and translucency edits affect the preview until Apply; Cancel discards all draft changes. |
| AP-02 | Invalid custom contrast cannot be applied; the message identifies the setting to correct. |
| AP-03 | Restore defaults affects appearance only and remains a draft until Apply. Imported data and financial settings are unchanged. |
| AP-04 | Applied preferences survive relaunch. Missing fonts/malformed stored preferences fall back without blocking financial hydration. |
| AP-05 | Reduced transparency yields opaque surfaces and fully opaque text; reduced motion suppresses nonessential transitions. |
| AP-06 | Tabular amounts remain aligned across every supported font style and size. Rows grow rather than crop text. |
| SAFE-01 | No renamed “Cleared/Reconciled/Income/Spending/Net worth” label overstates the underlying accepted authority. |
| SAFE-02 | The final report distinguishes static token checks, screenshot inspection, user interaction, build/test evidence and financial oracle evidence. |

## C. Evidence record per implementation packet

Report the exact code ref, runtime build identity, logical window dimensions, appearance/font/density settings, tested actions, named assertions, actual results and remaining gaps. Keep private originals read-only in their approved source location. Record independent-oracle use for financial aggregates, and provider/hydration/relaunch evidence when those boundaries are changed. A passing build or visually plausible screenshot alone is insufficient.
