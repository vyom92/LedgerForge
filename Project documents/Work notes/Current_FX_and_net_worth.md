# Current FX and net worth

<a id="packet-general-fx-architecture-packet"></a>

**Owners:** [FW-P3-18](../FUTURE_WORK.MD#fw-p3-18), [FW-P3-30](../FUTURE_WORK.MD#fw-p3-30), [FW-P3-31](../FUTURE_WORK.MD#fw-p3-31), [FW-P3-32](../FUTURE_WORK.MD#fw-p3-32), [FW-P3-33](../FUTURE_WORK.MD#fw-p3-33), [FW-P3-34](../FUTURE_WORK.MD#fw-p3-34).

Substantive unresolved evidence, not accepted architecture or execution authority. Topic/owner order inherits [Guide rule I](../Project_Guide.md#documentation-order); dated observations follow the current conclusion, newest first. Original evidence interiors preserve their semantic order.

## Question

How can the owner estimate current net worth in selected currencies while preserving native facts and incomplete states?

## Current conclusion

UD-08 selects direct market INR→USD; UD-10 requires current estimates, not a basket of historical conversions. QAR→USD is also a current market pair. Current QAR→INR Salary/Al Dar remains its separate bounded workflow; it is not a net-worth dependency. Historical FX is explicitly parked, and no 2021 history/cache accumulation or fixed haircut is implied.

The proposed current observation needs exact pair orientation, source time/date, fetch time, source/provenance digest and deterministic rounding. A last-success cache must label staleness and failure rather than silently call an old result live. Reporting currency remains an unresolved financial preference: supported set, inverse/pair orientation, persistence/ownership and incomplete-state rules must be chosen. Simple appearance preferences do not settle it.

An INR→USD observation of `0.010513` at `2026-09-10T00:02:31Z` was historical public evidence only. The inspected free endpoint permitted attributed cache/daily access, but its terms described illustrative use and discouraged financial-data use. Accessible data is not suitable financial authority. Chat must either explicitly accept a bounded illustrative estimate consistent with provider terms or qualify another source; there is no approved provider switch or automatic poller. These terms were not rechecked by this documentation task.

Current net worth needs non-overlapping account, bank/card liability and investment membership; exact native balances/units and dated prices; complete component/rate status; and derived reporting presentation. Missing account evidence, holdings, price or FX must be shown explicitly, never as zero. Imported native Money and identity are not rewritten. Value allocation, historical net worth and historical performance remain separate decisions; current holdings alone cannot establish them.

## Evidence and references

Owner UD-08/10 and historical public-provider observations, 2026-09-10; source-pinned FX/holdings packets at the two discovery refs. [Current Al Dar note](Salary_and_current_AlDar.md) and [holdings note](Holdings_and_valuation.md) own their separate evidence.

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

Provider use/suitability, reporting currency/pair orientation, current cache/freshness/rounding and exact non-overlapping membership need approval. Holdings/valuation must exist before integrated current net worth; historical FX is not a prerequisite.

## What would invalidate this conclusion

Changed provider terms/payload, unsupported inverse use, unknown currency/date, hidden conversion, duplicate membership, missing-as-zero or stale values presented as current falsify the recommendation. A later historical purpose requires its own explicit owner decision.
