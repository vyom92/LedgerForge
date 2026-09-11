# Transactions responsive visual specification

**Status:** written working draft; full-size visual frames and native acceptance remain pending.
**Design authority:** LF-UI-2026-09-R1. No new master board.
**Owners:** existing `FW-P2-03`, `FW-P2-53` and bounded `FW-P2-48/50`.
**Sources:** [canonical R1 handoff](DESIGN_HANDOFF.md) §3, [tokens](DESIGN_TOKENS.json), current roadmap Sprint 89 and its unaccepted appendix.

**Scope alignment — 2026-09-11:** Sprint 89 remains paused and unaccepted. Its financial algebra and independent source proof remain required. Formal accessibility and advanced appearance requirements are removed. The canonical handoff’s exact caption exceptions apply to the retained local SC-02A and SC-02C PNGs; those images remain artwork, not passed native evidence.

## 1. Authority boundary

R1 fixes the main structure and practical requirements. The current roadmap fixes AND between filter groups, OR within multi-select groups, native currencies, stable sorting and selection, full-matching-scope totals, and separation of bank movement from card-liability effects.

The detailed `fold-v1` Unicode contract, exact sort/oracle appendix and native acceptance procedure are explicitly **proposed, unaccepted**. The designer must not accept them on the coordinator's behalf. Visual references may annotate how they would appear, but implementation waits for the coordinator's exact selected semantics.

The apparent INR colour/summary observation is not a diagnosed defect in this packet. Preserve accepted financial meaning and require targeted source/runtime evidence before a colour-semantics change.

## 2. Primary composition

```text
Transactions                      All dates    Details toggle    Supported action
Matching-results summary, partitioned by currency AND financial domain/effect
Search displayed fields                           Filters [active group count]
Visible scope controls or chips                    Sort: Date, newest first
Date       Description             Account       Category          Amount
[read-only canonical rows; optional selected-record inspector at the right]
Matching count / available count; exclusions and currency-sort explanation
```

Use one search field. Wide controls expose common criteria; narrow controls consolidate rather than remove them. No unsupported Add Transaction, Export, Notes, Split, attachment, reconciliation-status or saved-filter actions.

**Content safety:** do not populate construction frames with fabricated transaction-shaped financial data. Use clear nonfinancial field-role placeholders or existing approved visual pixels strictly as artwork. Actual financial integration and acceptance use authorized authentic source-backed canonical records only. Static artwork is never an oracle.

## 3. Column contract

| Column | Ideal | Minimum at default type | Expansion / overflow |
|---|---:|---:|---|
| Date | 112 | 96 | Approved civil date; no manufactured time. Missing remains explicit. |
| Description | 360 | 220 | Flexible priority; up to two lines, then visual ellipsis; complete content remains readable in inspector. Source text is unchanged. |
| Account | 176 | 136 | Trusted display name plus bounded distinguishing evidence when available. Do not infer subtype from a name. |
| Category | 144 | 120 | Current assignment or explicit Uncategorized. In compact composition it may be secondary text. |
| Amount | 176 | 160, or measured full width if greater | Trailing-aligned tabular digits. Currency and sign remain clear. Never wrap, truncate, abbreviate or shrink. |

Header minimum height is 32. Reference row minima are 44 for roomy composition or 36 for compact composition; these are layout references, not a user density setting. Rows grow for two lines or secondary account/category text. These are token minima, not promises that two 16-point text lines fit in a 36-point row.

**Priority when width disappears:** preserve complete amount and date; give description remaining readable width; put account/category in an intentional secondary line only in the compact composition; keep access to their sorting/filtering through labelled controls. If neither composition fits, provide horizontal scrolling rather than data loss.

## 4. Reference-frame geometry

The following arithmetic is a **designer refinement for coordinator review**, not a measured app baseline. It uses the unchanged R1 tokens plus a proposed one-point sidebar separator. Column gaps are four × 12; table horizontal padding is two × 16.

| Frame | Allocation at body 16 | Column target |
|---|---|---|
| Wide, inspector closed, 1440 × 900 | 208 sidebar + 1 divider + 48 page margins + 1183 table | Date 112; Description 495; Account 176; Category 144; Amount 176; gaps/padding 80 |
| Wide, inspector open, 1440 × 900 | 208 + 1 + 48 + 847 table + 16 split gap + 320 inspector | Date 96; Description 255; Account 136; Category 120; Amount 160; gaps/padding 80 |
| Last-resort narrow, sidebar hidden, 1024 × 768 | 48 page margins + 976 table | Date 112; Description 288; Account 176; Category 144; Amount 176; gaps/padding 80 |
| Narrow, sidebar expanded, compact composition | 208 + 1 + 48 + 767 table | Date 96; Description/secondary metadata 455; Amount 160; two gaps/padding 56 |

The sum of default five-column minima is 732 before 80 points of padding/gaps. That requires **812 points** for the full table. At 1024 with an expanded 208-point sidebar, only 767 remain; forcing the full default table there would violate the design's own minima. Use a documented compact composition or prefer an icon-only rail. Fully hidden navigation is allowed only when even the rail materially harms usable content; keep a labelled Show Navigation control. The canonical responsive rule preserves destination order, selection, focus, icon names/tooltips and Developer Console gating. No rail width or automatic breakpoint is invented here. Do not quietly reduce type size.

When a formatted amount needs more width, rerun the fit calculation. Measure the actual labels and values instead of assuming the reference arithmetic guarantees fit. Reference height does not justify cropping a footer, focus ring or action.

## 5. Filters, search and sort

R1 default period is **All dates**. Default order is newest approved source date first. Do not silently start in This month.

| Surface | Visual specification | Semantic boundary |
|---|---|---|
| Search | Search icon, one text field, clear control and a discoverable scope explanation | Supported displayed description/account/institution/category fields; no hidden IDs or unrestricted source fragments |
| Period | Active range always visible, including All dates | Source-established date, inclusive custom range, no timezone invention |
| Accounts / Currency / Category | Multi-select values and explicit unrestricted state | Durable identity / native currency / current assignment |
| Family / direction | Distinct controls or clearly scoped values | Expose only accepted domain/effect mappings; never equate bank credit/debit with card liability |
| More Filters | Label plus active indication; all choices inspectable | Institution or amount range only if included in the final selected scope; amount range requires currency |
| Sort | Heading indicator in full table; labelled Sort menu in constrained layout | Only selected supported visible keys with an accepted order/null contract |

**Designer refinements for review:** count active *filter groups*, not individual selected accounts, in the Filters button; show search separately; display no more than two wrapping chip rows before a labelled More filters control. Keep Clear filters visible. A filter popover can stage edits with Apply/Cancel so its intermediate choices do not unexpectedly hide the selected row; the coordinator must confirm this interaction before implementation.

Clear filters restores All dates, clears search and removes field restrictions. It does not reset sort, column widths or inspector visibility. Closing a popover is not a financial mutation. Search response/debounce and exact keyboard shortcuts are not specified by this packet.

For multi-currency Amount sorting, display an explanation that currencies are grouped and amounts are ordered within each currency. Do not imply a converted cross-currency ranking. The proposed appendix specifies currency code ascending; that precise rule remains conditional on acceptance.

## 6. Totals, selection and inspector

Summaries describe every matching record, not the current viewport and not the selected row. Partition by native currency **and** accepted bank/card domain/effect. A combined bank-plus-card total is not Income, Spending or Net Worth. Withhold an aggregate whose effect mapping is not accepted; explain its absence without inventing zero.

A successful no-match result shows a matching count of zero and **no currency-total rows**. Empty data, loading, unavailable snapshot and invalid filter specification must not share that visual. Keep irrelevant stale amounts out of those states.

Selection uses immutable identity. Filtering out the selected member clears selection and the inspector; no substitute is automatically chosen. Sorting a selected member does not select the row that happens to occupy its previous position. Closing the inspector does not clear an otherwise valid selection.

Inspector content: complete description; native amount and accepted direction/effect; account; current category; actual source-date roles; available bounded provenance and validation context. Do not add editing, source reopening or attachment actions to fill space.

**Designer refinement for review:** in wide layout, details form an adjacent 320-point region; in constrained layout, use a 320-point attached detail presentation when appropriate for native macOS. On dismissal return focus to the invocation point or selected row, never to an unrelated primary action. Native choice and focus restoration require runtime proof.

## 7. Required render/state inventory

The following table is a working checklist for selected visual references. It does not require a separate JSON/state inventory or establish completed renders. Only inspected artwork establishes visual coverage, and only actual app evidence establishes native behavior.

| ID | Frame or state | What the reference must demonstrate |
|---|---|---|
| TX-01 | Wide normal; no inspector | Unrestricted scope, default date sort, complete table and summary partitioning |
| TX-02 | Wide selected + inspector | Consistent row/details identity; no duplicated financial action |
| TX-03 | Wide selected; inspector closed | Selection retained with clear Details affordance |
| TX-04 | Wide sidebar collapsed | Navigation remains discoverable; no enlarged empty gap |
| TX-05 | Wide filters active | Multiple groups, removable chips, AND/OR explanation and matching count |
| TX-06 | Wide filter popover | Group states, staged edits if approved, Apply/Cancel, keyboard focus |
| TX-07 | Search results | One query field, clear action, scope explanation and matched-result state |
| TX-08 | No matches | Existing data distinguished from empty database; Clear filters |
| TX-09 | Empty available snapshot | No invented records or zero totals; supported intake guidance only |
| TX-10 | Loading | Neutral placeholders without financial values or misleading completion |
| TX-11 | Unavailable/error | No stale totals; typed allowed recovery only |
| TX-12 | Keyboard-focused selected row | Focus ring distinguishable from selection fill |
| TX-13 | Sorted column | Primary key and direction, reverse affordance, no source-order mutation |
| TX-14 | Multi-currency / mixed-domain | Segregated totals and currency-aware Amount sorting; no grand total |
| TX-15 | Narrow icon rail; hidden navigation only as last resort | Content fit preserves readable columns and persistent search/sort/filter/navigation access |
| TX-16 | Narrow, sidebar expanded | Compact description and secondary metadata; amount never clips |
| TX-17 | Narrow details open | Attached readable inspector without crushing table columns |
| TX-18 | Narrow chips/filter popover | Controls reposition without hiding active scope |
| TX-19 | Long descriptions and complete Money | Reflow/scroll with no clipped amounts or control overlap; no text-scale preference system |
| TX-20 | Selection removed / invalid filter / stale snapshot | Distinct state handling; no substitute row or fabricated total |

Wide references use 1440 × 900 and narrow references 1024 × 768. Include both R1 palette references in verification, but do not imply Sprint 89 implements Sprint-91 preferences. The current appearance can be preserved until its separately selected implementation.

## 8. Native acceptance and limitations

Before implementation acceptance, the coordinator freezes the trusted generation, source-derived expected membership/order/totals and final selected predicate. Independent enumeration must not call the production filter as its oracle.

Verify pointer and keyboard filtering, sort/reverse, resize, navigation, selection, detail dismissal, matching-scope totals and clear state feedback. Include unknown filter values, missing source dates, nil category, equal sort keys, long text, mixed currencies/domains and generation changes only with permitted evidence. Missing authentic cases remain source-uncertified.

Static artwork does not prove ordinary keyboard use, persistence, financial correctness or native readability. No formal accessibility qualification is a gate. This packet does not choose preference storage or authorize saving filters/widths across relaunch. R1-level usability requirements and implementation storage choices stay separate.
