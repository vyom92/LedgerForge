# Current FX and net worth

<a id="packet-general-fx-architecture-packet"></a>

**Owners:** [FW-P3-18](../FUTURE_WORK.MD#fw-p3-18), [FW-P3-30](../FUTURE_WORK.MD#fw-p3-30), [FW-P3-31](../FUTURE_WORK.MD#fw-p3-31), [FW-P3-32](../FUTURE_WORK.MD#fw-p3-32), [FW-P3-33](../FUTURE_WORK.MD#fw-p3-33), [FW-P3-34](../FUTURE_WORK.MD#fw-p3-34).

Substantive unresolved evidence, not accepted architecture or execution authority. Topic/owner order inherits [Guide rule I](../Project_Guide.md#documentation-order); dated observations follow the current conclusion, newest first. Original evidence interiors preserve their semantic order.

## Question

How can the owner estimate current net worth in selected currencies while preserving native facts and incomplete states?

## Current conclusion

**Sprint 97 accepted alignment, 2026-09-17:** the [current owning contract](Holdings_and_valuation.md#sprint-97-refresh-contract) supersedes Sprint 95's launch-relative cadence with every real launch plus **00:00/06:00/12:00/18:00 UTC**, including Al Dar, one wake catch-up and one **60-second** retry of failed work. Settings > Live FX owns the single manual Refresh all surface; app-owned sessions and the shared clock remain independent of Settings. The [owner-accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-97) includes exact current-FX conversion for investment-only USD/INR overview/card presentation in Sprint 97. Sprint 99 still owns whole-app reporting currency and net worth across investments, bank assets and card liabilities. The accepted Sprint-95 paragraph below is historical authority for its original implementation; its cadence/control placement is superseded by this accepted contract, while precise legs, cache, freshness and month-local overrides are retained.


**Owner supersession, 2026-09-16:** shared Al Dar QAR/INR/USD reference ownership is accepted in Sprint 95 under [ADR-045](../ADR.md#adr-045) and the [settled owner decisions](../SCOPE_DECISIONS.md#sprint-95-owner-decisions). Exactly two QAR-1 forward legs supply six locally derived display directions; raw precision remains intact. The versioned two-leg cache, per-leg fetch time, six-hour refresh/one 60-second retry and >24-hour stale labels are selected. Dashboard has automatic updates and no manual Refresh button; Budget Planning retains a themed Refresh with temporary result/reason feedback. Both pages share the compact three-row conversion card and one relative-age badge based on the older fetched leg, with partial availability identified. Manual planning overrides remain local to their month and never replace provider cards.

Sprint 99 consumes this same authority after accepted Sprint-96 investment identity/current holdings, Sprint-97 valuation/integrated portfolio acceptance and Sprint-98 manual Gmail/combined-bank intake support. It still needs non-overlapping bank/card/investment membership, reporting-currency preference ownership, complete dated valuation inputs and explicit incomplete combined results. Native Money remains unchanged. Missing components cannot become zero; stale/fetched references cannot become guaranteed settlement or provider market timestamps. No competing provider, peg substitution, workbook haircut, history collection or historical performance is selected.

The earlier public-provider/terms observations below are retained as historical evidence only; they no longer block the owner-selected Al Dar-only current scope. The selected implementation is now accepted under `SPRINT_95_BUDGET_PLANNING_AND_SHARED_AL_DAR_ACCEPTED`; [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-95). This does not accept Sprint-99 reporting/net-worth integration.

<a id="sprint-98-price-catch-up"></a>
**Future Sprint-98 owner rule — 2026-09-17, not a silent Sprint-97 change:** public rates/prices remain due at **00:00/06:00/12:00/18:00 UTC**, fetching configured source scopes rather than every catalogue item or each holding separately. After missed runs, perform at most one current refresh. If the next slot is within **60 minutes inclusive**, defer automatic catch-up; exactly at a slot execute once instead of deferring another six hours. Thus 16:20 runs once, 17:00/17:20 defer to 18:00, and 18:00 runs once. Durable shared receipts and one active operation prevent repeated openings/observers from duplicating work. Manual Refresh all may bypass due timing, joins active work and does not shift fixed slots. With an enabled background agent app opening is due-only; without it retain the Sprint-97 launch-refresh fallback.

Keep one 60-second retry for failed price legs only. Preserve successful unrelated quotes, actual valuation date/date basis and successful-fetch timestamps independently; unchanged success may update fetch time but never relabel stale NAV as newly published. Failed/skipped/cache-only/UI-open events cannot advance success time. Publish accepted cache changes coherently with real dependency/date provenance; do not impose an all-provider simultaneous snapshot. Background UTC policy is separate from machine-local launchd calendar behavior; [mechanism and acceptance](Account_and_document_lifecycle.md#sprint-98-background-updates) own that unresolved scheduling integration boundary.

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

Sprint-95 Budget Planning/shared Al Dar is accepted. Sprint-99 reporting/net worth remains gated on accepted investment/valuation, non-overlapping membership, reporting preferences and its own complete-result proof. The Al Dar provider, two-leg orientation, cache and refresh interval decisions are settled for the selected scope and must not be reopened as a second provider project.

## What would invalidate this conclusion

Changed provider terms/payload, unsupported inverse use, unknown currency/date, hidden conversion, duplicate membership, missing-as-zero or stale values presented as current falsify the recommendation. A later historical purpose requires its own explicit owner decision.
