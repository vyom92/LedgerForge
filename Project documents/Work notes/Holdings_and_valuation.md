# Holdings and valuation

<a id="packet-investment-holdings-architecture-packet"></a>
<a id="packet-amfi-provider-qualification-packet"></a>
<a id="packet-zurich-fe-provider-qualification-packet"></a>

**Owners:** [FW-P3-20](../FUTURE_WORK.MD#fw-p3-20), [FW-P3-21](../FUTURE_WORK.MD#fw-p3-21), [FW-P3-22](../FUTURE_WORK.MD#fw-p3-22), [FW-P3-23](../FUTURE_WORK.MD#fw-p3-23), [FW-P3-24](../FUTURE_WORK.MD#fw-p3-24), [FW-P3-25](../FUTURE_WORK.MD#fw-p3-25), [FW-P3-26](../FUTURE_WORK.MD#fw-p3-26), [FW-P3-27](../FUTURE_WORK.MD#fw-p3-27), [FW-P3-28](../FUTURE_WORK.MD#fw-p3-28), [FW-P3-29](../FUTURE_WORK.MD#fw-p3-29).

Substantive unresolved evidence, not accepted architecture or execution authority. Topic/owner order inherits [Guide rule I](../Project_Guide.md#documentation-order); dated observations follow the current conclusion, newest first. Original evidence interiors preserve their semantic order.

## Question

What current holdings model and qualified valuation sources can represent the owner’s actual investments without inventing history?

## Current conclusion

UD-01 selects current holdings first; history/performance is gated. The owner explicitly selects Direct-plan mutual funds. Proposed architecture separates **Container**, **Instrument** and dated **PositionObservation** with exact identifier namespace, effective date versus recorded date, Decimal units at approved scale, currency and provenance. None of that proposal is an accepted new domain/ADR or migration.

Cost evidence needs distinct types: total-cost-like Money; average-unit-cost Decimal plus currency; contribution/allocation ratio with explicit basis and any separately evidenced Money; or unknown. These are not interchangeable and do not establish tax lots. Revisions need explicit supersedes/void relationships with a single active observation, preserving prior evidence. Price observations need exact instrument/provider identity, Decimal price, civil source date, fetch time/provenance and source digest. Final valuation rounding/version and provider/repository/hydration/actor ownership need approval.

The prior workbook review established only the selected visible sheets: WB2 entered units and total-cost-like values despite an average-price heading; WB3 used fractional units and average unit cost with derived total; WB4 separated ISP/AVC units and contribution allocation. WB1's expense range included remittance-labelled cells and was not a spending oracle; WB5's converted net-worth totals showed workflow intent, not independent financial truth. Hidden sheets and complete history were not inspected. This refactor did not reopen the workbook.

Current positions require genuine owned units, dates and cost evidence; a quote feed proves no ownership. Brokerage ingestion is not necessary for manually entered current positions. History, tax lots, realized P/L, TWR/IRR, corporate actions and reconstructed trades remain outside the selected current-holdings outcome. Allocation still needs an owner choice between current value and contribution allocation (or both), with an explicit native-currency denominator and unvalued exclusions. No unvalued component is silently zero.

### AMFI — historical observation, 2026-09-10

The actual NAVAll payload used eight semicolon fields and contained 14,353 numeric rows with mixed source dates and no currency header. Exact scheme code, two ISIN fields, name, Direct/Regular plan, option, NAV and source date must be qualified. Exact selected Direct-plan mapping and independent AMC evidence of INR denomination remained missing. Similar names or numerical-looking prices cannot establish identity/currency. Personal automation and selected-row cache permission were not established. A draft inquiry proposed asking AMFI about that bounded use and feed semantics; it was not sent or answered.

### Zurich / FE — historical observation, 2026-09-10

Four configured USD mappings were observed: `N0USD → GPP7`, `USDL3 → AUJDP`, `3UUSD → LCP0`, `B0280 → CAZYC`. The PriceHistory route established 2026-09-09 USD bid-price dates for all four. The official guide's page 3 described change from the previous day and adjacent observations agreed after two-decimal rounding. Other observed row/unit routes had null PriceDate/NAVDate/Time; an overview-page date is not price authority. These findings narrowed technical date uncertainty but did not establish automation/cache permission.

Keep mandatory ISP and AVC units separate; contribution/allocation is not lots or unit ownership. The old 0.75 multiplier is retired with no replacement vesting guess. A manual fallback must be an explicit dated owner observation/revision, distinguished from source/provider evidence and never overwriting it.

## Evidence and references

Owner direction and visible-workbook discovery recorded 2026-09-09/10; AMFI and Zurich/FE packet observations dated 2026-09-10. Public provider pages and exact pinned repository references below are historical evidence. No provider request, workbook/original access or financial validation was rerun by this restructure.

- [Database/Migrations.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/Migrations.swift#L233); SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Database/Migrations.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Database/Migrations.swift#L233); SHA-256 `ff0e02b72b66486b89255907ce12aa73aaf1919c677c608e9b12c79ed78de6b5` — inactive exchange_rates schema capacity
- [Database/Repository.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Database/Repository.swift#L201); SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Database/Repository.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Database/Repository.swift#L201); SHA-256 `0c4416fa22817a54dc776f3973cf0b0e92aee209e667decc12e62de182b4f92f` — WorkspaceRepository, TransactionRepository, CategoryRepository, AccountRepository, CardRepository, ImportSessionRepository and ConfirmedImportRepository; provider container
- [Models/Account.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Models/Account.swift#L10); SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Account.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Models/Account.swift#L10); SHA-256 `63732666f7e7174f5d38c7c3db4b61082aa8a435fec5dd6e060d3d07265939fc` — AccountType; Account baseCurrencyBalance
- [Models/Money.swift at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Models/Money.swift#L258); SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Models/Money.swift at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Models/Money.swift#L258); SHA-256 `d504f1c49f564c661609ea1085028b650b7c6bb7063f64c9fb4afcd260aa7a0e` — Money.init; minorUnits
- [Project documents/ADR.md at adcf83f](https://github.com/vyom92/LedgerForge/blob/adcf83f52d309ddac18d95f0321d0c0f6120dd29/Project%20documents/ADR.md#L269); SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046
- [Project documents/ADR.md at af2d194](https://github.com/vyom92/LedgerForge/blob/af2d1949c6e9a73af3bb004422b72882d28195e2/Project%20documents/ADR.md#L269); SHA-256 `163d4d8f814bfd43a43b04e98f0396f9d6ac30d643871f1bc2568a49f493ed2c` — ADR-008, ADR-033, ADR-045, ADR-046

## Unresolved decision or blocker

Approve current domain identity/revision/cost/valuation contracts and exact post-Sprint-87/88 provider ownership. Supply genuine current units/costs/dates and exact instrument mapping/denomination. Qualify AMFI and FE permissions independently; neither inherits permission from the other.

## What would invalidate this conclusion

Unknown/contradictory units, plan, currency, source date, cost basis or revision ownership; provider route/terms changes; inferred history/vesting/ownership; or unsegregated native amounts invalidate the proposed current value. A future explicit history decision needs genuine events and an approved performance method.
