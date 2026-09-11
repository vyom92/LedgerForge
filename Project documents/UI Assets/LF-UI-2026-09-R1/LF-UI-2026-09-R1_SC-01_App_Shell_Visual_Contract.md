# App Shell Visual Contract

**Authority:** LF-UI-2026-09-R1 and the inspected current roadmap.
**Status:** written draft for coordinator review; no native or Figma visual acceptance.
**Owner:** existing `FW-P2-67`; no new sprint or queue ID.
**References:** the current roadmap §§Sprint 88 and SHELL88; [canonical R1 handoff](DESIGN_HANDOFF.md) §§1, 2 and 6; [tokens](DESIGN_TOKENS.json); standing harness.

**Scope alignment — 2026-09-11:** Sprint 88 is accepted history. This draft remains a design reference for later selected work; it does not reopen Sprint 88 or accept Sprint 89. The canonical handoff owns component states, icon-rail responsive treatment and simple local appearance. No formal accessibility or advanced appearance programme is required.

## 1. Preserve now; enable later

The designer must use two distinct comparison baselines.

| Lane | Controls the comparison | Permitted conclusion |
|---|---|---|
| Sprint-88 preservation | Exact accepted post-Sprint-87 app at fixed state and window conditions | Decomposition did or did not preserve the visible behavior |
| R1 target conformance | Written R1, tokens and approved board with its explicit exceptions | A later selected UI increment does or does not meet the approved direction |

Do not demand that Sprint 88 implement a narrower minimum window, a collapsing sidebar, new inspector presentation, new typography, new toolbar labels, theme preferences, transaction filters or new Import Preview placement. Those may be target requirements for later work; they are not authorized by shell decomposition.

The historical screenshots in this chat are not a post-Sprint-87 runtime baseline. The roadmap explicitly makes post-Swift-6 ownership a dependency for changes that touch providers, activity gates, the hydrator, Import Centre or actor publication.

## 2. Structural slots

The following is a composition map, not an instruction to move a state owner or choose Swift type names.

```text
Primary macOS window
  Native window controls / titlebar
  Navigation region              Content region
  - supported destinations       - one page title
  - developer gate               - contextual commands
  - navigation toggle            - persistent warning/status slot, when applicable
                                 - destination workspace
                                   - main content/table/form
                                   - optional details/inspector
                                 - task footer, when the existing workflow requires it
```

| Slot | Required responsibility | Preserve during Sprint 88 | R1 direction, later implementation |
|---|---|---|---|
| Navigation | Select an existing destination | Labels, order, selected destination, developer gating, focus and actions | Label plus icon; separate focus/selection; discoverable collapse toggle |
| Title | Explain the active destination | Existing title, subtitle and accessibility meaning | Exactly one clear title; no decorative user/profile duplication |
| Toolbar | Invoke contextual actions | Callbacks, shortcuts, visibility, enabled state and workflow ownership | Task-specific controls; no identical dominant Import action forced onto Settings/diagnostics |
| Warning/status | Present authoritative lifecycle or task state | Existing scope, priority, timing, recovery affordances and generation | Distinguish loading, unavailable, saved, and saved-but-refresh-required |
| Workspace | Display the destination's existing content | Selection, scroll position where preserved today, edits, focus and view-model behavior | Content-fit layout; no speculative modules |
| Inspector | Explain the selected record | Current identity, details, edit boundaries and behavior | Optional, readable, independently dismissible without selecting a different record |
| Task footer | Present supported task controls | Exact confirm/cancel/skip/retry gating | Remain visible and reachable; no new import state machine |

A presentation-only component receives state and emits existing actions. It must not create a competing provider, import task, hydrator or financial calculation.

## 3. Preservation invariants

**SC-01 Navigation.** Switching destinations must invoke the same route and retain the same existing state semantics. No new reset of import preparation, financial selection, drafts or filters is allowed merely because a child view was extracted.

**SC-02 Commands.** Preserve each action's label, destination, enabled/disabled rule, shortcut and side effects. The shell must not introduce duplicate command handlers or trigger an import during body evaluation.

**SC-03 Workflow.** Preserve accepted serial queue order and per-occurrence identity, one active preparation, cancellation draining, explicit per-item confirmation, non-cancellable commit, duplicate/recovery outcomes and canonical publication. Refactoring is not queue redesign.

**SC-04 Lifecycle.** Preserve generation-specific data availability, startup presentation and warnings. Do not render unavailable data as an empty successful snapshot.

**SC-05 Visual parity.** At the same window dimensions, display scale, app state and appearance, retain the current structural geometry and readable controls. Intentional visual changes require a separately approved deviation, not a claim that R1 demanded them.

**SC-06 Focus and ordinary keyboard use.** A moved view must keep meaningful labels, focus destinations, keyboard access and the existing meaning of selected/disabled states. The same keystroke must not execute twice after decomposition.

**SC-07 Financial semantics.** Keep source dates, account identity, currency, amounts, source order, bank/card distinctions and existing saved-versus-unsaved evidence. No sign/colour correction based solely on a screenshot.

**SC-08 Scope.** No broad source-tree reorganization, new migration, parser, preference store, icon redesign or finance-domain redesign.

## 4. Existing R1 geometry, not Sprint-88 golden measurements

All dimensions below are macOS logical points from the existing R1 token file.

| Item | Existing R1 target |
|---|---|
| Comparison frames | 1440 × 900 and 1024 × 768; not deployment minima |
| Sidebar | Ideal 208; minimum 184; maximum 264; collapsible |
| Inspector | Ideal 320; minimum 280; maximum 384; collapsible |
| Page padding | 24 |
| Panel padding / section gap | 16 / 16 |
| Control gap / small spacing | 12 / 8 |
| Body / secondary / caption | 16 / 13 / 12; caption floor 12 |
| Title / section / metric | 28 / 20 / 28 |
| Controls | Minimum 32 high; focus ring 2 with offset 2 |
| Table rows | Reference minima 44 for roomy composition or 36 for compact composition; grow when content needs it. No user density preference required |

These values establish a design target. They are not measurements of the current binary. Do not overwrite the token file or tune arbitrary replacements to make a collage fit.

## 5. Future responsive behavior

The R1 direction is content-fit rather than a fixed percentage sidebar. Close the inspector first when the table loses readable width, then prefer an icon-only navigation rail. Hide navigation only when even the rail materially harms usable content width. Keep a labelled navigation toggle and inspector toggle available. Secondary filters may move into a labelled Filters control; scope and active criteria must remain inspectable.

An amount, sign and currency context stay complete on one line. Never shrink amounts, truncate them or infer exchange-rate conversion to fit. Increase the amount column, reflow nonfinancial layout or use horizontal scrolling.

Reevaluate actual content fit; a nominal window width alone does not prove that complete Money, five columns and the inspector fit. A hidden inspector is not a cleared selection. A filtered-out selection must clear rather than jump to another row.

**Controlling owner decision:** prefer an icon-only rail for collapsed navigation. Preserve destination order, selection, focus and Developer Console gating; each destination retains a meaningful name and tooltip. Fully hidden navigation is a last resort and keeps a labelled Show Navigation control. No automatic breakpoint is inferred from a compact drawing. A constrained inspector can be an attached presentation rather than a narrower permanent column. Its concrete native presentation and focus behavior require the implementation packet and runtime checks.

## 6. Baseline capture specification

The coordinator's separately authorized native evidence should identify build SHA, bundle/build identity, OS version, window content dimensions, display scale, appearance, relevant data-generation reference, selected destination/record, scroll offsets and task phase. Preserve sensitive screenshots only in their authorized local boundary; a Git-safe manifest can contain opaque evidence IDs and results instead of financial values.

Capture all six financial/settings destinations plus Developer Console only when its existing gate is satisfied. Include the currently supported width, an intermediate resize, warning/unavailable state and the accepted Import Centre prepared/confirming/result states. Do not create unsupported source cases to fill the matrix.

The R1 comparison sizes are useful for later design, but if 1024 × 768 is not supported at the Sprint-88 baseline, record that limitation. Do not silently change the minimum window size or treat the unsupported capture as a regression.

## 7. Review classification and stop conditions

Use the review ledger's categories: expected structural refactor, acceptable native variation, introduced visual/interaction regression, existing R1 gap/future work, or not comparable. Only an observed new deviation is a Sprint-88 regression; an unchanged gap to R1 stays future work.

Stop review acceptance when build identity differs, source/data state is not comparable, post-Sprint-87 ownership is missing, a task action changes meaning, content disappears or becomes unreachable, a financial value is altered, or new persistent behavior is introduced. Obtain bounded evidence; do not invent a golden baseline.

**Completion boundary:** this written contract is ready for coordinator review. Native baseline, actual candidate comparison and Figma slot frames remain outstanding.
