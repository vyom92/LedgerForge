# Transaction and R1 workflows

<a id="packet-sprint89-data-algebra-packet"></a>
<a id="packet-sprint89-data-algebra"></a>
<a id="packet-import-preview-responsive-placement"></a>

**Owners:** [FW-P2-03](../FUTURE_WORK.MD#fw-p2-03), [FW-P2-04](../FUTURE_WORK.MD#fw-p2-04), [FW-P2-05](../FUTURE_WORK.MD#fw-p2-05), [FW-P2-06](../FUTURE_WORK.MD#fw-p2-06), [FW-P2-07](../FUTURE_WORK.MD#fw-p2-07), [FW-P2-08](../FUTURE_WORK.MD#fw-p2-08), [FW-P2-09](../FUTURE_WORK.MD#fw-p2-09), [FW-P2-12](../FUTURE_WORK.MD#fw-p2-12), [FW-P2-40](../FUTURE_WORK.MD#fw-p2-40), [FW-P2-41](../FUTURE_WORK.MD#fw-p2-41), [FW-P2-43](../FUTURE_WORK.MD#fw-p2-43), [FW-P2-44](../FUTURE_WORK.MD#fw-p2-44), [FW-P2-46](../FUTURE_WORK.MD#fw-p2-46), [FW-P2-47](../FUTURE_WORK.MD#fw-p2-47), [FW-P2-48](../FUTURE_WORK.MD#fw-p2-48), [FW-P2-50](../FUTURE_WORK.MD#fw-p2-50), [FW-P2-52](../FUTURE_WORK.MD#fw-p2-52), [FW-P2-53](../FUTURE_WORK.MD#fw-p2-53), [FW-P2-78](../FUTURE_WORK.MD#fw-p2-78), [FW-P2-79](../FUTURE_WORK.MD#fw-p2-79).

Substantive unresolved evidence, not accepted architecture or execution authority. Topic/owner order inherits [Guide rule I](../Project_Guide.md#documentation-order); dated observations follow the current conclusion, newest first. Original evidence interiors preserve their semantic order.

## Question

What remains to prove the selected Transactions behavior and the owner’s practical R1 usability?

## Current conclusion

Sprint 89 is paused/unaccepted; it retains FW-P2-03/53 and only necessary Transactions portions of FW-P2-48/50. The global canonical Transactions snapshot remains authority. Presentation search/filter/sort must not write repositories, change financial meaning or replace source order. Saved filters are separate and need an approved preference contract.

Filters cover supported authoritative displayed fields, including account/institution, bank/card family, native currency, date/period, financial effect/direction and assigned category. Amount/institution filtering is only eligible where supported displayed fields establish it. AND joins groups; OR joins selected values within a group. Active scope, clear/reset and truthful no-match states remain visible. Supported columns are Date, Description, Account, Category and Amount; repeated heading action reverses direction. Resize/reflow, stable selection, collapsible inspector and full matching-scope native totals remain required.

The designer's 2026-09-09 INR inflow/outflow/net-colour observation is **reported, not a verified financial defect**. A screenshot alone cannot prove financial meaning or stored corruption. Targeted authentic-source/runtime evidence is required before any semantic colour change.

The exact proposed independent oracle and native procedure below are retained as unaccepted implementation/acceptance detail. They do not establish any runtime pass. Simple local appearance, toolbar action inventory, account-history browsing, truthful states, chart series and bounded cross-screen polish retain their separate queue outcomes. Dashboard customization has an explicit deferral until stable modules after Sprint 90 and a selected owner objective; this does not park other blocked work.

#### Exact proposed search, sort and total oracle

At one trusted canonical provider generation, take genuine source-backed rows `R` and separately captured visible labels. Allowed search fields are exactly displayed transaction description, account label, institution label and assigned-category label. Hidden account/transaction IDs, raw source/reference fragments, formatted balances, dates and undrawn fields are excluded. A nil field never matches; an empty field matters only when search is disabled.

`fold-v1` is pinned Unicode 15.1 default case folding, canonical NFD, removal of nonspacing combining marks (`Mn`), each Unicode White_Space run replaced by one ASCII space, then trim. Apply it locale-independently to the query and every allowed field. A folded empty query disables search; otherwise split on normalized spaces. `search(t,q)` is true only when **every** literal contiguous term occurs in at least one non-nil allowed displayed field; terms may occur in different fields. Punctuation is literal. Regex, fuzzy matching, token-OR, hidden-field search and stored-text alteration are excluded.

`F={t in R | AND over enabled filter groups(groupMatches(t)) AND search(t,q)}`. Multi-value groups use OR/set membership. Empty selected sets disable their group. An unknown selected value is an explicit invalid filter specification. Inclusive endpoints use the source-established financial civil date. Nil category matches only the explicit uncategorized choice.

Sort only expressly selected visible keys. Nullable display/category is nil-last in both directions; non-nil values use the same pinned fold and scalar lexical ordering. Date, currency and description use their actual canonical key. Amount sorting first groups by native currency code ascending, then uses exact native amount in the requested direction within that currency; it never compares Money across currencies. Default order is newest source date first. Ties use stable opaque durable document/import identity, independently proven source ordinal within document, then immutable transaction identity. Missing optional date/ordinal is last. No ordinal, chronology or cross-document historical chronology is invented. A new sortable key requires an explicit null/type/order contract.

Compute totals over all `F`, independent of viewport or selection, partitioned by native currency **and** accepted financial domain/effect. Do not combine bank cash movement with card purchase/payment liability effects as a spending/income total. Withhold an aggregate when its effect mapping is unaccepted. Use exact Money arithmetic within an accepted partition. A successful empty `F` has no currency-total rows; unavailable snapshot and invalid filter are distinct states. Selection survives only while its canonical member remains in `F`; otherwise it becomes nil and the inspector clears. Collapsing the inspector mutates neither membership, totals nor selection.

The independent oracle enumerates `R` and the predicate/order directly, never production filtering. Required cases cover empty/whitespace query, literal punctuation, composed/decomposed accents, locale-independent case folds, nil/empty fields, multiple allowed fields, unknown values, combined group/search, equal keys, nil-last both directions, multiple currencies, stale generation and selection removed by filtering. A hidden-field match; regex/token-OR behavior; omitted required term; lost source ordinal; cross-currency amount ordering; locale dependence; wrong null position; or viewport-only totals falsifies the proposal.

<a id="packet-sprint89-native-acceptance-procedure"></a>
### Sprint 89 independent native acceptance procedure

This procedure is a proposed runtime gate, not evidence of a pass. The data lane supplies the trusted `R` oracle above: AND groups, OR values, transient normalized case/diacritic-folded multi-term search over the frozen display fields, stable source-ordinal/durable-identity order, and native-currency plus accepted bank/card-domain/effect totals without conversion or grand total.

1. Freeze `R`, provider generation, filter specification, expected membership/order/totals and an opaque oracle hash.
2. Exercise pointer and keyboard date/account/currency/direction/category/search/sort/reverse/inspector/selection/clear; compare visible output to the oracle.
3. Resize, collapse/reopen inspector and change focus. Selection persists only while a member; otherwise it becomes explicit nil and no substitute row is selected.
4. Check Tab/Shift-Tab, arrows, Space/Return as native-owned, shortcut collisions, and absence of implicit import or financial write.
5. Check complete readable Money/currency, useful icon names/tooltips, visible sort/filter scope and count, and focus distinct from selection.
6. Check broad/narrow target widths, no clipping/overlap, readable contrast and no colour-only financial semantics; preserve actual action visibility.
7. For empty/loading/unavailable/stale generation, require truthful enabled state and no stale totals/selection or fabricated zero Money.
8. Use adversarial presentation text only through the oracle: membership may change; source fields never do.
9. Store only a privacy-safe manifest: build, opaque generation, case/oracle hash, counts and observed interaction result/failure; never values, rows, text, IDs, paths or sensitive screenshots.

Actual Transactions focus, useful keyboard interaction, resize/readability, selection and panel cancellation still require observation. This is a bounded owner-usability check; no discovery text establishes a native pass.

### DRAFT — Import Preview Responsive Placement (user feedback, 2026-09-10)

This subsection records subjective user feedback and an unaccepted layout proposal. It does not change the approved visual direction, accepted Import workflow, source interpretation or native acceptance status. The user reports heavy scrolling in the left prepared-import region while the right region beneath Validation Review has unused space. The supplied private screenshot supports broad layout geometry only; its financial/source content is neither transcribed nor published.

**Owner:** [FW-P2-48](../FUTURE_WORK.MD#fw-p2-48), including its bounded owner-usability checks. This is an unaccepted discovery proposal, not an implementation or native-acceptance claim. Coordinate with [FW-P2-67](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-88) only when a selected shell decomposition affects this composition; no sprint is selected here.

**Candidate A, preferred for a sufficiently wide window:** place the existing read-only Transaction Preview beneath Validation Review in one right-column review stack. Keep the queue, prepared statement summary, account/identity and duplicate/equivalence explanation readable at left, with confirmation/cancel/skip controls visibly available. This placement is a suggestion, not a forced rule.

**Candidate B, responsive fallback:** place one full-width/shared Transaction Preview below the summary/review split when the right-side table cannot remain readable or validation content is long. Determine the breakpoint from content fit and text size. Do not duplicate the preview or create nested unbounded scroll owners.

Both candidates preserve source order/multiplicity, prepared status, identity/account review, validation, duplicate/equivalence semantics and explicit confirmation. They introduce no editing, filtering, sorting, source reopening, new selection semantics or financial/color change. Future native acceptance must cover broad/narrow windows, long validation, useful keyboard actions, scroll/focus and existing selection, footer visibility, cancellation/confirmation, and truthful empty states. A zero-transaction statement case requires genuine authentic evidence; if absent it stays untested. No native verification is claimed by this appendix.

## Evidence and references

Owner-approved R1 written direction and scope correction; 2026-09-10 proposed Sprint-89 algebra/native procedure and Import Preview alternatives. Evidence at `adcf83f52d309ddac18d95f0321d0c0f6120dd29` / `af2d1949c6e9a73af3bb004422b72882d28195e2`; [canonical R1 map](../UI%20Assets/LF-UI-2026-09-R1/README.md).

- [ContentView.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/ContentView.swift#L1507); SHA-256 `c315381adf31633a27671b14499fc5dd12d7b794af047c82cfb2acf67990202b` — contextualToolbar
- [ContentView.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/ContentView.swift#L1443) — Archive has a custom monolithic shell.
- [Database/Repository.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/Repository.swift#L208); SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — TransactionRepository
- [LedgerForgeTests/TransactionListViewModelTests.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/LedgerForgeTests/TransactionListViewModelTests.swift#L11); SHA-256 `30c938da8a204989e27b1b070a352b8bd784cf111ef01dd2b04f6dd3f8f3641f` — searchTrimsWhitespaceAndMatchesAuthenticTransactionText
- [Project documents/ADR.md at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Project%20documents/ADR.md#L3460); SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-037
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L3451) — trusted transaction deletion unapproved
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L3488) — no universal undo
- [Project documents/UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Project%20documents/UI%20Assets/LF-UI-2026-09-R1/ACCEPTANCE.md#L38); SHA-256 `e22c6acfe8e63a124f5f032dd9fb7e09a7102a3f25137e4acbb7a119845c03ab` — TX-01 to TX-10
- [Project documents/UI Assets/LF-UI-2026-09-R1/ACCEPTANCE.md at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Project%20documents/UI%20Assets/LF-UI-2026-09-R1/ACCEPTANCE.md#L48); SHA-256 `e22c6acfe8e63a124f5f032dd9fb7e09a7102a3f25137e4acbb7a119845c03ab` — DB-01 to DB-03
- [Services/ImportPersistenceCoordinator.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Services/ImportPersistenceCoordinator.swift#L1864); SHA-256 `052b8de5c2de61349a5151d676e1dade3ec005363fb82f4eed290822bea2cfae` — event block
- [Services/ImportPersistenceCoordinator.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Services/ImportPersistenceCoordinator.swift#L1857) — exact and event outcomes are distinct
- [ViewModels/TransactionListViewModel.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/ViewModels/TransactionListViewModel.swift#L274); SHA-256 `7e2dbde244295009d00df9cf6f6f5606f2e123374c912c346df4b07936b1cbd9` — filteredTransactions
- [Views/Common/LFIconTile.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Views/Common/LFIconTile.swift#L1); SHA-256 `7615248477db034385ce8ce5f1e904a0f9d9b45a0389bdb6ac7509dc53139f8a` — LFIconTile

## Unresolved decision or blocker

Complete the corrected authorized Sprint 89 only after refreshed handoff; independently verify authentic membership/order/native totals and actual native interaction. Import Preview alternatives are proposals and require acceptance before selection. Missing genuine zero-activity cases stay untested.

## What would invalidate this conclusion

Different results for identical snapshot/spec, hidden-field search, mixed-currency totals, rewritten source order, lost selection or unclipped-looking but incomplete Money falsifies the proposed contract. A colour-semantic change or new field requires targeted evidence.
