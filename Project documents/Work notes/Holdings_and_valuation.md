# Holdings and valuation

<a id="packet-investment-holdings-architecture-packet"></a>
<a id="packet-amfi-provider-qualification-packet"></a>
<a id="packet-zurich-fe-provider-qualification-packet"></a>

**Owners:** [FW-P3-20](../FUTURE_WORK.MD#fw-p3-20), [FW-P3-21](../FUTURE_WORK.MD#fw-p3-21), [FW-P3-22](../FUTURE_WORK.MD#fw-p3-22), [FW-P3-23](../FUTURE_WORK.MD#fw-p3-23), [FW-P3-24](../FUTURE_WORK.MD#fw-p3-24), [FW-P3-25](../FUTURE_WORK.MD#fw-p3-25), [FW-P3-26](../FUTURE_WORK.MD#fw-p3-26), [FW-P3-27](../FUTURE_WORK.MD#fw-p3-27), [FW-P3-28](../FUTURE_WORK.MD#fw-p3-28), [FW-P3-29](../FUTURE_WORK.MD#fw-p3-29).

The accepted Sprint-96 current-holdings contract and retained verification are recorded below. Earlier discovery and provider findings remain dated evidence; they do not authorize additional scope. Topic/owner order inherits [Guide rule I](../Project_Guide.md#documentation-order); dated observations follow the current conclusion, newest first. Original evidence interiors preserve their semantic order.

## Question

What current holdings model and qualified valuation sources can represent the owner’s actual investments without inventing history?

## Current conclusion

**Sprint 96 — ACCEPTED, 2026-09-17**, under `SPRINT_96_INVESTMENT_IDENTITY_AND_CURRENT_HOLDINGS_ACCEPTED`. Published predecessor: `main@2f299b1ced7586fafb390e760dcac56e378e75d3`. The owner accepts the small current-portfolio model, qualified manual statement updates and native presentation; the historical observation/revision graph remains excluded. V21 adds only current investment containers and holdings with existing document/fingerprint/import-session/normalized-document provenance. Exact-path publication is authorized, including the retained owner Xcode changes. Current stayed on V20 throughout qualification and initial publication; post-publication startup activation is recorded separately in the [accepted outcome](../Archive/Accepted%20outcomes/Sprints_90-99.md#sprint-96). Sprint 97 is NEXT / NOT STARTED; PERSONAL-V1 remains NOT YET ADOPTED.

The durable container retains institution, actual account/portfolio/folio/policy identity, confirmed aliases and the latest accepted date/completeness for that replacement scope. A holding retains exact units, optional separately reported average acquisition cost and total cost, native/cost currency, source date/precision/provenance and an optional future price mapping. Bounded `InvestmentDecimal` preserves source text and scale; ordinary Money and Al Dar math are unchanged. Missing cost stays unavailable and cannot prevent a valid holding. Newer quantity and cost evidence replaces together; unavailable new cost is not inherited through a quantity change.

Confirmed complete snapshots add/update/remove only their established scope. Partial coverage leaves other holdings unchanged. Explicit zero rows remove a matching current holding and otherwise remain excluded from active positions. Historical zero-only scopes with no established container or confirmed alias create neither positions nor mapping questions. Exact replay is idempotent and older sources cannot roll holdings back. Same-date differences in exact printed units/cost/scale, display identity or issue/NAV dates require an explicit source choice; lower printed precision cannot silently select the first import. Actual mapping ambiguities affecting current positions are held; confirmed mappings are reused. Private owner-approved folio alias pairs belong in the normal confirmed application data, never hardcoded in Git. No generic suffix stripping or name-based automatic mapping is selected.

Accepted source-specific rules:

| Original family | Replacement scope | Reported acquisition cost |
| --- | --- | --- |
| IBKR PDF/CSV | Complete Open Positions for the printed brokerage account and period end; use full owned quantity | Cost Price and Cost Basis retained separately at their printed precision |
| CAMS/KFin detailed CAS | Closing positions within each printed folio; omit unrelated folios and account for historical zero sections | Printed total cost only; no average reconstructed from trades |
| KFin CAS summary | Positive closing holdings within each printed folio; omitted folios unchanged | Printed Cost Value only; exact ISIN/folio evidence or explicit confirmed mappings link its omitted fund-house heading |
| CBQ modern investment statement | Complete mutual-fund detail table for the printed client portfolio and Report Date | Printed average purchase price and total invested amount; issue and NAV dates remain separate |
| CBQ legacy holding statement | Complete current fund grid for the printed Unit Holder and Date of Report | Printed Avg. Cost and Total Cost; legacy name-to-ISIN mappings are asked only when they affect a current update |
| ISP closing CSVs | Each policy's complete Closing balance section | No source acquisition cost; UnitPrice is valuation evidence only |

The three new ISP reports establish seven positive positions and thirteen explicit zero rows across separate employee mandatory, employee AVC and employer policies. Policy totals are controls. Their earlier policy-only originals cannot supply fund units or cost. Lending/collateral, bank cash, policy contribution allocation, trade history, tax lots, realized gains, dividends, corporate-action reconstruction and historical performance are outside Sprint 96.

**Owner UI review approved, 2026-09-16; column dragging manually verified and accepted at closure, 2026-09-17.** Investments follows Accounts. The approved centered native table is `Investment | ISIN / Ticker | Portfolio/Folio | Units | Currency | Avg Cost | Total Cost | NAV / Price date`. Identifiers occupy their own column, and persisted native column customization enables header reordering. Zurich is visibly labelled ISP. NAV/price dates use `DD MMM YYYY` and Al Dar's green-to-yellow-to-red visual scale, applied to calendar-day age (today / one day / four days); source holdings dates remain in compact Details. The seven ISP holdings now say **Not in statement** in the identifier column because their originals contain neither ISIN nor ticker. Missing costs and valuation dates remain unavailable. Sprint-96 dates come from statements; no live provider, price/value/P&L placeholder columns or oversized evidence cards are introduced. Final native inspection observed 41 genuine holdings in the isolated durable app, including populated IBKR/CAS/CBQ identifiers, corrected Invesco ownership, ISP labels and the new missing-identifier copy.

**Local qualification, 2026-09-16–17.** No source, decrypted statement or financial oracle file was created. Unchanged originals and independent comparisons traversed RAM only; normal isolated app databases and product backup packages were used for persistence/recovery.

| Check | Executed result |
| --- | --- |
| Investment sources | All 36 distinct nominated originals (12 local + 24 email) matched independent exact unit/cost/currency/date/identity comparisons after In-Memory/SQLite confirmation, hydration and SQLite reopen. This is qualification transport, not production email intake. |
| CAS identity | Both detailed/summary orders after the earlier local reports retained 15 positive holdings in ten folios, persisted all seven owner-confirmed alias pairs and reused them on replay. Native source-order fund-house evidence independently caught an Invesco heading sharing a geometry line with a version footer; the bounded parser correction and all three detailed originals passed. |
| Update and failure behavior | Coupled units/cost updates, unrelated policy preservation, exact replay, unseen older-source rejection, same-date PDF/CSV choices in both orders, failed atomic publication and stale-generation rejection passed. The four older ISP policy-only originals did not enter fund-holdings parsing. Final investment-focused run: 11 definitions/executions, zero failures. |
| Ordinary regression | 613 definitions / 679 executions, zero failures/skips. Existing 12 selectors / 17 gated definitions remain retained; two new investment selectors separately gate eight original-dependent definitions. The original-based mixed queue ran in the ordinary selection. |
| Shared ingestion regression | Six complete bank/card family suites passed (10 definitions/executions). The 20-original salary suite passed every provider/order/replay/reopen campaign using independent pdfplumber geometry and pypdf native-text controls supplied through a FIFO; 34 pages, 158 earnings and 100 deductions reconciled. |
| Recovery | Populated format-1 V21 backup, verification, replacement, complete staged hydration and connection reopen passed. A separate real app process restored 41 holdings across 15 containers in `s93-recovery-s96-20260917`, then a fresh process confirmed relaunch and cleanup. Exact current records/provenance, the input package hash and the owner's actual Current database hash remained unchanged. Existing format-1 V17–V20 isolated upgrade and package mechanics passed. |
| Builds and review | Debug/test builds, the open Xcode project build and optimized Release passed. Fresh Sol review identified same-date precision/date loss and missing populated recovery proof; primary repaired and verified both. The two real SQLite subprocess tests passed with the owner's CodeSignOnCopy retained and the signing dependency cycle corrected. |

**Accepted authentic-source limits.** Two cases remain **UNOBSERVED**, not failures: (1) a genuine holding exit solely by absence from a later complete statement; (2) a genuine newer statement clearing previously known acquisition cost. The code paths exist and received structural review; no authentic financial qualification is claimed for those cases and no synthetic fixture is invited. The owner manually verified native column drag reordering and accepts the persisted arrangement. Earlier automation returned `noWindowsAvailable` for dragging; that tooling failure remains historical and is not the owner verification. The Xcode editor-diagnostics bridge could list files but not refresh those paths; the Xcode build passed without compiler errors. The retained ordinary run has 25 LFTheme harness warnings, and builds retain App Intents metadata notices. Release was built, not launched against the owner's Release database. The benchmark remains an isolated research result; closure introduces no production fallback or new parser work.

**Local evidence locations.** The task-owned `LedgerForge-s96-focused` artifact directory retains the failed diagnostic runs and `TestResults-pass19.xcresult` (investment), `TestResults-pass-full21.xcresult` (ordinary) and `TestResults-pass-families22.xcresult` (bank/card); its final `TestResults.xcresult` contains the successful salary/recovery continuation. `/tmp/LedgerForge-s96-process-restore.log` and `/tmp/LedgerForge-s96-process-reopen.log` contain only bounded operational recovery signals. `/tmp/LedgerForge-s96-release24.log` records the Release build. Failures before the final passes included the test-provider generation flag, CAS heading ownership, and ordinary-run environment/schema expectations; they were repaired without weakening source assertions or excluding a failing definition.

Final native/recovery Debug SHA-256: launcher `16d0e38c89998104d3b5872da93465d64e7ea1bd9493c0d279b7e85b62a3dfbf`, debug dylib `4c78bb94b9dce2b0beb1a53ef52845d05b197f7eb35b1e583317d2c152cf813c`. Optimized Release executable: `f6e4997839935ce40cfae19ad989bea8f25f28eacbcfdcb61e8b91c4bf6e1308`. These identify the accepted qualification products built before publication; the post-publication Current activation product has its own recorded clean-build identity.

The prior workbook review established only the selected visible sheets: WB2 entered units and total-cost-like values despite an average-price heading; WB3 used fractional units and average unit cost with derived total; WB4 separated ISP/AVC units and contribution allocation. WB1's expense range included remittance-labelled cells and was not a spending oracle; WB5's converted net-worth totals showed workflow intent, not independent financial truth. Hidden sheets and complete history were not inspected. This refactor did not reopen the workbook.

Current positions require genuine owned units, dates and cost evidence; a quote feed proves no ownership. Sprint 96 is current holdings and reliable manual updates; Sprint 97 qualifies latest prices/NAV and the integrated valued portfolio; production email retrieval and bounded parallel batch intake remain Sprint 98. These are stages of one portfolio-monitoring feature. No contribution allocation calculator or manual ISP holdings fallback is required by the now-available closing reports.

### AMFI — historical observation, 2026-09-10

The actual NAVAll payload used eight semicolon fields and contained 14,353 numeric rows with mixed source dates and no currency header. Exact scheme code, two ISIN fields, name, Direct/Regular plan, option, NAV and source date must be qualified. Exact selected Direct-plan mapping and independent AMC evidence of INR denomination remained missing. Similar names or numerical-looking prices cannot establish identity/currency. Personal automation and selected-row cache permission were not established. A draft inquiry proposed asking AMFI about that bounded use and feed semantics; it was not sent or answered.

### Zurich / FE — historical observation, 2026-09-10

Four configured USD mappings were observed: `N0USD → GPP7`, `USDL3 → AUJDP`, `3UUSD → LCP0`, `B0280 → CAZYC`. The PriceHistory route established 2026-09-09 USD bid-price dates for all four. The official guide's page 3 described change from the previous day and adjacent observations agreed after two-decimal rounding. Other observed row/unit routes had null PriceDate/NAVDate/Time; an overview-page date is not price authority. These findings narrowed technical date uncertainty but did not establish automation/cache permission.

Keep mandatory ISP and AVC units separate; contribution/allocation is not lots or unit ownership. The old 0.75 multiplier is retired with no replacement vesting guess. That earlier discovery did not establish a manual fallback. The later closing reports above remove the need for one in Sprint 96; exact FE fund/share-class mapping remains Sprint 97 work.

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

The current-holdings model, source cost policy, CBQ date role, specific folio aliases and initial UI arrangement are approved. Remaining Sprint-96 work is candidate verification and any real current-position ambiguity exposed by an original; historical CBQ aliases and the older same-date IBKR cost disagreement do not block a newer unambiguous snapshot. Exact pricing mappings, provider permissions, denomination and current valuation remain Sprint 97 gates. AMFI and FE require separate qualification.

## What would invalidate this conclusion

Unknown/contradictory units, plan, currency, source date, cost basis or revision ownership; provider route/terms changes; inferred history/vesting/ownership; or unsegregated native amounts invalidate the proposed current value. A future explicit history decision needs genuine events and an approved performance method.


<a id="accepted-publication-file-inventory"></a>
## Accepted publication file inventory

The Sprint-96 publication from `2f299b1ced7586fafb390e760dcac56e378e75d3` contains exactly **56 paths** below. The owner's `LedgerForge.xcodeproj/project.pbxproj` and shared `LedgerForge.xcscheme` changes are explicitly included and preserved. Product/test/project bytes are unchanged during closure; additional closure edits are existing authority documentation only. No private source, credential, database, backup, benchmark scratch or build artifact is in this inventory.

- [AppDestinationContainer.swift](../../AppDestinationContainer.swift)
- [AppShellPresentation.swift](../../AppShellPresentation.swift)
- [ContentView.swift](../../ContentView.swift)
- [Core/InvestmentStore.swift](../../Core/InvestmentStore.swift)
- [Database/BackupPackage.swift](../../Database/BackupPackage.swift)
- [Database/InMemoryRepositoryProvider.swift](../../Database/InMemoryRepositoryProvider.swift)
- [Database/InvestmentPersistence.swift](../../Database/InvestmentPersistence.swift)
- [Database/Migrations.swift](../../Database/Migrations.swift)
- [Database/Repository.swift](../../Database/Repository.swift)
- [Database/SQLiteInvestmentRepository.swift](../../Database/SQLiteInvestmentRepository.swift)
- [Database/SQLiteRepositoryProvider.swift](../../Database/SQLiteRepositoryProvider.swift)
- [Import/Coordinator/ImportCentreCoordinator.swift](../../Import/Coordinator/ImportCentreCoordinator.swift)
- [Import/Models/ImportFailureSummary.swift](../../Import/Models/ImportFailureSummary.swift)
- [LedgerForge.xcodeproj/project.pbxproj](../../LedgerForge.xcodeproj/project.pbxproj)
- [LedgerForge.xcodeproj/xcshareddata/xcschemes/LedgerForge.xcscheme](../../LedgerForge.xcodeproj/xcshareddata/xcschemes/LedgerForge.xcscheme)
- [LedgerForgeTests/AlDarReferenceTests.swift](../../LedgerForgeTests/AlDarReferenceTests.swift)
- [LedgerForgeTests/BackupPackageTests.swift](../../LedgerForgeTests/BackupPackageTests.swift)
- [LedgerForgeTests/DashboardViewModelTests.swift](../../LedgerForgeTests/DashboardViewModelTests.swift)
- [LedgerForgeTests/GlobalRuntimeStateIsolation.swift](../../LedgerForgeTests/GlobalRuntimeStateIsolation.swift)
- [LedgerForgeTests/InvestmentDecimalTests.swift](../../LedgerForgeTests/InvestmentDecimalTests.swift)
- [LedgerForgeTests/InvestmentRAMOriginalTests.swift](../../LedgerForgeTests/InvestmentRAMOriginalTests.swift)
- [LedgerForgeTests/InvestmentSourceImportTests.swift](../../LedgerForgeTests/InvestmentSourceImportTests.swift)
- [LedgerForgeTests/LedgerForgeTests.swift](../../LedgerForgeTests/LedgerForgeTests.swift)
- [LedgerForgeTests/MigrationChainIntegrityTests.swift](../../LedgerForgeTests/MigrationChainIntegrityTests.swift)
- [LedgerForgeTests/MigrationIdentityLockTests.swift](../../LedgerForgeTests/MigrationIdentityLockTests.swift)
- [LedgerForgeTests/SalaryAuthenticCorpusAcceptanceTests.swift](../../LedgerForgeTests/SalaryAuthenticCorpusAcceptanceTests.swift)
- [LedgerForgeTests/SalaryParserAndPlannerTests.swift](../../LedgerForgeTests/SalaryParserAndPlannerTests.swift)
- [LedgerForgeTests/TestSupport/AuthenticSourceTestSupport.swift](../../LedgerForgeTests/TestSupport/AuthenticSourceTestSupport.swift)
- [LedgerForgeTests/TransactionListViewModelTests.swift](../../LedgerForgeTests/TransactionListViewModelTests.swift)
- [Models/FinancialDocument.swift](../../Models/FinancialDocument.swift)
- [Models/Investment.swift](../../Models/Investment.swift)
- [Parsers/FundCurrentHoldingsParsers.swift](../../Parsers/FundCurrentHoldingsParsers.swift)
- [Parsers/IBKRCurrentHoldingsParser.swift](../../Parsers/IBKRCurrentHoldingsParser.swift)
- [Parsers/InvestmentStatementParser.swift](../../Parsers/InvestmentStatementParser.swift)
- [Project documents/ADR.md](../ADR.md)
- [Project documents/Archive/Accepted outcomes/Sprints_90-99.md](../Archive/Accepted%20outcomes/Sprints_90-99.md)
- [Project documents/Database_v1_Architecture.md](../Database_v1_Architecture.md)
- [Project documents/FUTURE_WORK.MD](../FUTURE_WORK.MD)
- [Project documents/PROJECT_STATE.md](../PROJECT_STATE.md)
- [Project documents/SCOPE_DECISIONS.md](../SCOPE_DECISIONS.md)
- [Project documents/Sprint roadmap/LedgerForge_Roadmap_Sprints_90-99_Current.md](../Sprint%20roadmap/LedgerForge_Roadmap_Sprints_90-99_Current.md)
- [Project documents/Sprint roadmap/Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md](../Sprint%20roadmap/Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md)
- [Project documents/Work notes/Account_and_document_lifecycle.md](Account_and_document_lifecycle.md)
- [Project documents/Work notes/Backup_and_export.md](Backup_and_export.md)
- [Project documents/Work notes/Holdings_and_valuation.md](Holdings_and_valuation.md)
- [Project documents/Work notes/Source_relationships.md](Source_relationships.md)
- [Services/BackupRestoreCoordinator.swift](../../Services/BackupRestoreCoordinator.swift)
- [Services/ImportEngine.swift](../../Services/ImportEngine.swift)
- [Services/ImportPersistenceCoordinator.swift](../../Services/ImportPersistenceCoordinator.swift)
- [Services/ImportValidator.swift](../../Services/ImportValidator.swift)
- [Services/RepositoryStoreHydrator.swift](../../Services/RepositoryStoreHydrator.swift)
- [TestPlan.xctestplan](../../TestPlan.xctestplan)
- [Views/InvestmentImportReviewView.swift](../../Views/InvestmentImportReviewView.swift)
- [Views/InvestmentListView.swift](../../Views/InvestmentListView.swift)
- [Views/TransactionListView.swift](../../Views/TransactionListView.swift)
- [script/README.md](../../script/README.md)
