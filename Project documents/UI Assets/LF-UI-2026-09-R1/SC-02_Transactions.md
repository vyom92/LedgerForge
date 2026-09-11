# SC-02 — Transactions

Canonical approved **written** R1 contract relocated from DESIGN_HANDOFF; no new visual direction or native acceptance is claimed. Read [shared design requirements](DESIGN_HANDOFF.md), [numeric tokens](DESIGN_TOKENS.json) and [required checks](ACCEPTANCE.md). Supporting local SC drafts/PNGs are identified in [README](README.md); they do not override this text.

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

Default to newest source date first. Clicking a supported heading selects that sort; repeating reverses it. Show direction in the heading and retain a meaningful native action/state label. Support Date, Description, Account, Category and Amount as their data contracts permit.

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
