# Repository State

## Current Alignment — 2026-08-27

This section is the current alignment layer. Historical sections below are preserved for traceability; this alignment supersedes their pre-Sprint-78B support, migration and planning limits where they conflict.

### Accepted production baseline

- **Primary branch:** `main`.
- **Accepted implementation:** Sprint 78B in this closure commit on `main`; the exact commit is recorded by Git history.
- **Latest accepted numbered sprint:** Sprint 78B.
- **Latest accepted ADR:** ADR-045 — Qatar Airways Salary Actuals and Current-Month Funding Planner; implementation pending. ADR-044 remains the latest implemented production-domain ADR.
- **Accepted migration:** V15.
- **Accepted card profiles:** exact `amex.credit-card.pdf@1`, exact `cbq.credit-card.pdf@1`, and the exact Axis `axis.credit-card.pdf@1` / `axis.credit-card.xlsx@1` families accepted by Sprint 78B. No generic card/PDF/XLSX support is implied.
- **Personal-v1 adoption:** still undeclared; release/adoption certification remains a separate future gate.

### Sprint 78B closure and current planning

- Sprint 78 failed and Sprint 78A failed; Sprint 78B is accepted and completes the Sprint 78 outcome.
- Exact Axis credit-card PDF/XLSX support, the dual Axis PDF credential scopes, zero-instrument liability semantics, cross-format equivalence and Migration V15 are accepted production state.
- Sprint 79 architecture is approved by Chat but remains unimplemented; execution requires the complete Chat-approved Sprint 79 prompt. Additive V16 is authorized for Sprint 79 implementation but is not yet an accepted migration.
- No Sprint 78C exists because Sprint 78B completed the required outcome.
- This closure commit publishes the accepted Sprint 78B implementation, separately approved `Project_Guide.md` PG-55 state, and reconciled authorities.

### Sprint 79 approved architecture

Sprint 79 is the exact Qatar Airways salary-PDF and current-month funding-planner increment. Private discovery over the complete active salary boundary proves 20 native-text unlocked PDFs across monthly salary/payslip, Adhoc Payment and Annual Discretionary Bonus source kinds. The earlier seven-document planning statement is superseded.

The approved product boundary is:

- exact `qatar-airways.salary.pdf@1` only; no generic payroll claim;
- employer/source authority remains distinct from bank/card `Institution` authority;
- imported salary statements and ordered earning/deduction lines are immutable source truth and are never fabricated as bank transactions;
- source-owned pay period is chronology authority; print date is retained separately;
- fixed/variable are editable planning semantics only, never imported payroll classifications;
- one dedicated `Salary` sidebar space owns Salary History plus This Month planning; Dashboard receives summary-only funding signals;
- one editable current-month plan may roll forward prior values and account selections as editable defaults;
- checked QAR/INR accounts contribute explicit planning balances with carried/manual/refreshed-snapshot provenance; current balance capture is always user-triggered and never live-linked; missing checked-account balance evidence makes affected outputs incomplete rather than zero, and account inclusion is never auto-selected solely because one eligible account exists;
- India funding uses selected INR liquidity before calculating the Qatar funding shortfall;
- transfer fee starts at editable QAR 25 and contributes only when India funding shortfall is greater than zero; otherwise its effective contribution is QAR 0 while the configured fee remains editable;
- plan-local user-entered FX is positive, dated and oriented as INR per 1 QAR; the dormant global `exchange_rates` domain remains inactive; if India funding is required and FX is missing/invalid, QAR funding and investment-capacity outputs are incomplete rather than zero;
- INR funding conversion rounds the required QAR principal upward to the next QAR minor unit;
- available-for-investment and final buffer are derived planner outputs, while planned investment is editable user input;
- no automatic salary-bank matching, card-payment matching, transfers, obligation inference or investment execution is authorized.

Additive Migration V16 is authorized to introduce truthful salary-actual and current-month funding-plan persistence with SQLite/In-Memory parity and canonical `RepositoryStoreHydrator` integration. V15 remains the accepted migration baseline until Sprint 79 is technically accepted.

ADR-045 is the accepted architecture authority for this unimplemented Sprint 79 boundary.

### Accepted Sprint 78B source authority

The active private Axis credit-card corpus is Jan–Jul 2026:

- 7 locked App PDFs;
- 7 unlocked App PDFs;
- 7 App XLSX files;
- 7 locked traditional PDFs;
- 7 unlocked traditional PDFs;
- **35 physical active files total**;
- **21 logical representations total**: 7 App PDF, 7 XLSX, 7 traditional PDF.

Archived/ignored material is excluded.

Current source-proven financial row counts are:

| Month | Rows |
|---|---:|
| Jan | 89 |
| Feb | 95 |
| Mar | 56 |
| Apr | 178 |
| May | 143 |
| Jun | 154 |
| Jul | 81 |

Each logical representation family totals **796** financial rows.

Cross-format financial equivalence is exact multiset equality, including multiplicity, over financial date + liability effect + native currency + exact Money. Narration is not financial identity.

March contains 56 rows / 55 unique neutral financial keys with one multiplicity-two key. June contains 154 rows / 153 unique keys with one multiplicity-two key.

App PDF and XLSX additionally preserve exact source financial order and narration after only approved inert whitespace/Unicode normalization. Traditional PDF source order is not required to match App/XLSX order.

App PDF and XLSX use source-proven selected statement month. Do not invent a statement day or period.

Active Loans Summary is excluded from Sprint 78 financial transactions and historical statement chronology.

### Current Axis ownership semantics

Current authentic Axis sources do not prove row-level primary/add-on physical-card ownership.

Sprint 78B therefore requires:

- one explicit liability-account decision where strong source identity is absent;
- account-level Axis transaction evidence;
- zero fabricated Axis `CardInstrument` records;
- zero fabricated statement instrument sections;
- zero fake mask-derived strong identities;
- no automatic same-bank/family account merge.

The primary/add-on physical-card distinction is not required for the current Axis outcome.

### Accepted Axis PDF/XLSX implementation boundary

- App PDF tagged transaction-table evidence is the current authoritative App transaction carrier.
- The prior positioned App-PDF financial reconstruction/veto is superseded and must not regain acceptance authority.
- Traditional PDF may use the generic positioned-evidence path required by that exact layout.
- `PDFDocumentReader` remains generic source extraction and must not own Axis financial or credential-family policy.
- The accepted Axis XLSX profile uses a bounded deterministic OOXML reader with pinned/vendored ZIPFoundation and strict package/XML validation; this does not establish generic XLSX support.
- V1–V14 migrations remain immutable.
- Additive V15 is accepted with Sprint 78B. Sprint 79 now authorizes additive V16 for its pending implementation; V16 is not yet an accepted migration.

### Accepted Axis credential architecture

Explicit user-settled source fact: **Axis App PDFs and Axis traditional PDFs use two different legitimate passwords.**

The accepted Sprint 78B architecture uses two durable canonical credential scopes:

```text
axis-bank.credit-card.app-pdf
axis-bank.credit-card.traditional-pdf
```

The old unscoped `axis-bank` item and registered historical Axis legacy item(s) are compatibility candidates only.

Required behavior:

- uncredentialed read first;
- deterministic bounded remembered candidates;
- secure challenge only after remembered candidates fail;
- exact App/traditional target determined only after successful decryption and structural recognition;
- remembered success in the exact canonical family causes no Keychain write;
- compatibility-origin success may migrate only to the proven family scope after parse + validation;
- challenge success writes only the proven family scope after parse + validation;
- one family rotation must never overwrite the other;
- credentials never enter SQLite, financial evidence, fixtures or logs.

This credential architecture is accepted production state and is published by the 2026-08-27 ADR-015 alignment amendment.

### Sprint 78B acceptance record

Sprint 78B was technically accepted on 2026-08-27 after the final stable post-credential-correction candidate proved, at minimum:

- exact 35-file active private inventory and locked/unlocked pairing;
- locked and unlocked production-path equivalence for each monthly PDF family;
- Jan–Jul 796-row App/XLSX/traditional financial multisets with exact multiplicity;
- March and June duplicate multiplicity in all three representation families;
- exact App↔XLSX source order and narration;
- source-proven selected month;
- zero Active-Loans transaction leakage;
- May representative In-Memory and SQLite multi-source campaigns;
- one liability account, zero fabricated Axis instruments/sections;
- first May source creates 143 canonical transactions and later exact-equivalent representations create zero new canonical transactions;
- SQLite checkpoint/close/reopen and canonical hydration;
- zero accepted financial residue on rejection;
- focused credential/Axis/Amex/CBQ/parser/provider/hydration tests;
- fresh Debug build;
- fresh optimized Release build;
- exactly one authoritative complete `TestPlan.xctestplan` after the shared credential correction stabilizes;
- privacy/residue and `git diff --check` review.

Final accepted validation completed the focused shared boundary, authentic 35-file Axis private gate, fresh Debug build, fresh optimized Release build and exactly one authoritative complete TestPlan. The TestPlan executed 804 tests: 799 passed, 5 external-private-context tests were intentionally skipped with visible reasons, and 0 failed. Earlier green Sprint 78B results from before the dual-credential correction remain historical evidence only.

### Current documentation and execution authorities

- Repository bootstrap: `AGENTS.md`.
- Human routing guide: `Project documents/Project_Guide.md`.
- Current cycle roadmap: `Project documents/LedgerForge_Roadmap_Sprints_70-79_Current.md`.
- Standing execution method: `Project documents/LedgerForge_Standing_Execution_Harness_Guide.md`.
- Accepted state: this file.
- Unscheduled queue: `Project documents/FUTURE_WORK.MD`.
- Accepted architecture: `Project documents/ADR.md`.
- Current task authorization: complete Chat-approved prompt.

ChatGPT Chat owns sprint/architecture/prompt/acceptance decisions. MCP executor is the Chat plugin for guarded local Mac repository/Xcode access. Codex is a separate execution environment and does not automatically inherit Chat-only context. Model capability order is **Sol > Terra > Luna** and is independent of execution environment.

---

## Repository Baseline

- **Primary branch:** `main`
- **Current repository implementation baseline:** Sprint 78B exact Axis credit-card PDF/XLSX support and equivalence over the shared card domain; the closure commit is recorded by Git history
- **Documentation alignment:** Reconciled for the Sprint 78B implementation and acceptance boundary
- **Accepted source-truth repair:** P0 Axis bank-account source-truth restoration and Sprint 65's clean-room PDF fixture replacement are included in the accepted baseline; no historical financial data was altered
- **Latest chronologically accepted production implementation:** Sprint 78B exact Axis credit-card PDF/XLSX support and equivalence
- **Latest verified Debug development-tooling implementation:** DBP-01 Developer Database Profiles at `2d86f91dc46b9e88bcdfea65c88ddf671968b388`
- **Non-implementation commits after Sprint 53:**
  - `bdb51b0ddcdde097e456a16bab7f0bf999fd595b` — roadmap update
  - `7ee20a909038d1088f830a6ea588311625f415e5` — planning reconciliation and tracked Xcode user-data removal
  - `de238d8abf5ee7dc7d1eb9cd13fab72803f2be28` — roadmap update after the discovery campaign
  - `a64c2d8d67e93631d8b0c32620ded72f389f252f`, `98b1fef111087d3b8c2b26f8c354c2147c6b2412` and `f50127ccb7ddf05641df1af7a14a93be2ea8b42e` — subsequent roadmap updates
- **Latest verified completed numbered increment:** Sprint 78B — Exact Axis Credit-Card PDF/XLSX Support and Equivalence
- **Accepted Sprint 63 implementation ref:** `7e1345e3817d3c3e91c24f881b962a48279fd73b`
- **Latest accepted ADR:** ADR-045 — Qatar Airways Salary Actuals and Current-Month Funding Planner; implementation pending
- **Current migration:** V15
- **DBP-01 classification:** Accepted DEBUG-only developer tooling and development-database lifecycle implementation; it is not a production financial capability, production database-profile feature, numbered sprint, Sprint 65, schema migration or personal-v1 adoption
- **Sprint 55A:** Axis Bank Source-Truth Restoration, ending at `f3154dbd13a340714179da7f972a6accdd3aca54`; parallel shared-runtime-store isolation remains Sprint 55 acceptance/test infrastructure
- **Sprint 57A:** Category Reconciliation Closure, complete at `251a547cb44712a789a9ad7b23a4eabca742900b`; no migration was added
- **Sprint 58:** Deterministic Import Verification Workspace, complete at `4547083d4d81edc9b6bcd98c3a8e77ee1538e71a`; DEBUG-only ordinary-path verification with Release containment and an isolated exact-duplicate runtime check
- **Sprint 59:** Accepted ADR-041 as an architecture-only source-snapshot and exact source-byte fingerprint contract; implementation was intentionally deferred to a later increment
- **Sprint 62:** Accepted the ADR-041 immutable source snapshot and exact source-byte fingerprint architecture contract; no production implementation was included in Sprint 62
- **Sprint 63:** Implemented and independently accepted the immutable source-snapshot and exact source-byte fingerprint foundation
- **Sprint 64:** Completed the approved read-only Axis bank-account PDF readiness discovery. Its bounded candidate was the two-source account-neutral Axis bank-account PDF v1 family represented by retained NRO evidence.
- **Sprint 65:** Implemented and accepted the exact shared `axis.bank-account.pdf@1` grammar through the ordinary import path. The selected NRE/NRO originals, regenerated sanitized fixtures and independent row-level financial baselines now establish the bounded production boundary; broader Axis PDF layouts remain unsupported.
- **Sprint 65 blocker reconciliation:** `BLOCK-PDF-LINEAGE-01`, `BLOCK-PDF-ORACLE-BINDING-02`, `UNCERTAINTY-PDF-DETERMINISM-03`, `UNCERTAINTY-PDF-SOURCE-CLASS-04` and `UNCERTAINTY-NRE-NRO-GRAMMAR-05` are closed only for the selected unlocked/selectable-text grammar and its account-neutral NRE/NRO family. They remain open for other layouts, OCR, password-protected documents and generic Axis PDF support.
- **Sprint 66:** Implemented typed confirmed-import recovery, privacy-safe route-specific guidance, wholly fresh preparation for eligible zero-commit outcomes and bounded canonical reconciliation without changing persistence architecture
- **Sprint 67:** Preserved the durable imported-document relationship through canonical hydration and added one typed, privacy-safe transaction-detail projection for account, source-document and import-session provenance; missing legacy evidence remains neutral
- **Sprint 67A:** Corrected source-document presentation so only the exact durable `ImportedDocumentDTO` referenced by a transaction can authorize its displayed filename; import-session labels are not document authority
- **Sprint 68:** Removed future-module navigation, global and account placeholder search/filter chrome, disabled transaction ranges and inert row affordances, unsupported dashboard spending/trend presentation, the misleading Add Account action and unimplemented drag-and-drop copy. Repository-backed balances, native-currency transaction summaries, account editing, transaction search/toggles/category assignment, ordinary import workflow and Developer Mode containment remain.
- **Sprint 68 privacy boundary:** Production diagnostic emitters now use fixed messages, typed outcomes, enum values and counts; generic preparation/persistence failures fail closed to bounded presentation. Raw parser names, delimiter/encoding context and unrecognized account-identifier schemes do not reach Developer Console presentation, metadata or copied text.
- **Sprint 68A:** Corrected residual truthful UI from Sprint 68 by replacing the idle Validation Review's four fabricated Pending rows with one neutral empty state, removing the `Awaiting confirmation` footer pseudo-action, the static profile dropdown chevron, dashboard account-row chevrons and the account-detail favourite star. Real validation results, confirmation gating, retry and transaction actions, account editing, transaction search/toggles/category assignment, ordinary import and Developer Mode containment remain.
- **Sprint 68B:** Test-only correction to Sprint 68's bounded persistence-error contract. The generic public wrapper message remains, while typed identity outcomes and durable-attempt authority remain preserved.
- **DBP-01 maintenance correction:** Test lifecycle ownership was corrected so successful prepared imports have explicit terminal ownership and shared lifecycle-gate tests use target-wide isolation. It changed no production lifecycle behaviour, migration or ADR.
- **Sprint 69 repository interface:** `./script/validate.sh`, `./script/build_and_run.sh` and the Codex Run action are repository-verified local interfaces at the Sprint 69 baseline. The action invokes `./script/build_and_run.sh --verify`.
- **Sprint 69 acceptance-evidence classification:** The scripts, configuration and tests are repository-verifiable at the baseline; the build, test, process and runtime results recorded below are reported local execution evidence and were not re-executed by this documentation-only update.
- **Sprint 71:** Added a native OLE2/BIFF8 reader and the exact `axis.bank-account.xls@1` Axis NRO profile through the ordinary reader, detector, classifier, normalizer, parser, review, confirmation, provider and hydration pipeline. The reader is XLS-only; XLSX, OOXML, formula evaluation, macros, generic spreadsheet mapping, other layouts and cross-format duplicate suppression remain unsupported.
- **Sprint 71 third-party boundary:** LedgerForge vendors the required libxls 1.6.3 sources from `libxls/libxls` tag `v1.6.3` at `c199d132494833da696b58aa4acf3fc5a36d930b` under the BSD 2-clause license. The local Swift package builds a static C library, exposes only the LedgerForge bridge and links only the macOS system `iconv` boundary.
- **Sprint 71 source truth:** The committed independent evidence verifies 16 baseline XLS transactions, 20 extended XLS transactions, 16 shared ordered rows and 4 extended-only ordered rows. The Range-1 CSV legitimately contains 17 transactions while its XLS contains 16; no fixture or expected evidence was changed to manufacture parity.
- **Sprint 71 fail-closed boundary:** Invalid or truncated containers, encryption, multiple or hidden worksheets, formulas, boolean/error cells, missing/duplicate/ambiguous/reordered headers, malformed monetary values and unsupported near-match layouts reject before accepted financial writes. Workbook bytes remain confined to the transient immutable source snapshot.
- **Sprint 72:** Added the exact shared `hdfc.bank-account.xls@1` HDFC NRE/NRO legacy-XLS grammar through the accepted reader and ordinary detector, classifier, parser-selection, preview, explicit-confirmation, provider, hydration and relaunch pipeline. Exact source bytes remain the XLS duplicate authority; no PDF/XLS cross-format suppression was added.
- **Sprint 73:** Added the exact native selectable-text `hdfc.bank-account.pdf@1` grammar and the first durable exact whole-statement equivalence contract for the approved HDFC PDF/XLS v1 pair. The first accepted source remains transaction and provenance authority; a later exact-equivalent other-format source retains its own accepted evidence and creates zero transactions.
- **Sprint 73A test-only closure:** Corrected three stale Developer Database Profile expectations after Migration V10. V9 is the newest and default historical migration-sandbox source, V8 remains historical, and V10 remains current. Sprint 73A changed no production, parser, migration, ADR, persistence, fixture, source-truth or financial behaviour. The replacement cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 670 tests across 81 suites and zero failures.
- **Sprint 74:** Added exact `cbq.current-account.xls@1` support for the retained CBQ current-account transaction-history legacy-XLS grammar through the ordinary direct-URL reader, detector, classifier, parser-selection, validation, explicit-confirmation, provider, hydration and relaunch path. Signed QAR amounts, descending physical source order, same-date ambiguity and every printed row-associated balance are preserved without inventing a statement period, value date, timestamp or source-order balance recurrence.
- **Sprint 74 identity and source boundary:** One parser-owned verified full printed institution account identifier is the sole strong account identity. Holder text and filename are not identity. Blank merged-cell placeholders are retained as physical blanks, while hidden cells carrying financial or textual evidence continue to fail closed. Exact source bytes remain duplicate authority.
- **Sprint 74 private-source acceptance:** The bound 61-row legacy-XLS source passed the ordinary `ImportEngine.prepareImport(from:)` path. All 61 dates, signed amounts and row-associated balances matched an independently extracted six-page selectable-text PDF projection in source order with zero mismatches. Preparation wrote nothing; confirmation produced one accepted event set; exact-byte reimport produced no duplicate financial events; In-Memory and SQLite graphs matched; SQLite close/reopen and canonical hydration preserved the complete graph. No private source value, identifier, path, filename, narration, reference or oracle digest entered Git or repository documentation, and task-owned private artifacts were removed after verification.
- **Sprint 74 focused acceptance:** The final changed reader/CBQ boundary passed 19 tests across 4 suites; the broader adjacent legacy-XLS, Axis/HDFC XLS, detection, classification, selection and validation boundary passed 52 tests across 10 suites. The new CBQ synthetic surface passed 13 tests across 3 suites before the merged-placeholder correction and is subsumed by the final focused boundary.
- **Sprint 74 cycle-close acceptance:** The single authoritative cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 683 tests across 84 suites and zero failures.
- **Sprint 75:** Added exact native selectable-text `cbq.current-account.history.pdf@1` and `cbq.current-account.monthly.pdf@1` profiles beside `cbq.current-account.xls@1`. History PDF preserves its full account identifier, posting dates, signed QAR amounts, descending source order and row-associated balances without inventing a period, value date or summary. Monthly PDF preserves posting date as the canonical event date, source Transaction Date only as a separate observation, masked account/IBAN evidence, debit/credit direction, QAR Money, balances, statement boundary and brought-forward/closing evidence; brought-forward and exact non-financial promotional content are not transactions.
- **Sprint 75 account identity:** Full identifiers remain strong parser-owned ownership evidence. Typed masked CBQ account and IBAN patterns are durable evidence about an account, never fabricated full identifiers. Exact positional masked/full compatibility may resolve or explicitly narrow account choice, and a later compatible full history identifier attaches atomically to the existing monthly-created account. Generic identity resolution and generic no-match selection safety remain unchanged.
- **Sprint 75 source lineage:** ADR-043 keeps one canonical transaction while every accepted source retains its own document, exact source-byte fingerprint, session, normalized rows, statement observation and one transaction observation per financial row. Exact account, posting date, signed QAR amount and row balance establish lineage; a structured-reference digest is used only for exact collision disambiguation. Monthly PDF is preferred over history PDF, then history XLS, for source-evidence presentation only; canonical transaction document/session provenance is never rewritten.
- **Sprint 75 persistence:** Additive Migration V11 introduces typed CBQ source-identity, statement-source and transaction-source observations with restrictive relationships, exact accepted-row coverage and no historical backfill. Reviewed all-new, mixed and fully represented sources are atomically revalidated and committed with SQLite/In-Memory parity. Fully represented sources remain accepted with zero new transactions and complete source evidence.
- **Sprint 75 private-source acceptance:** Four direct-URL source-order campaigns were verified with both SQLite and In-Memory. History-first campaigns imported 60 then 0, 0 and 0 new transactions; monthly-first campaigns imported 9, 8, 43 and 0. Every campaign ended with one account, 60 canonical transactions, four durable attempts and 60 preferred-source mappings; SQLite reopen preserved the same graph. Independent history PDF/XLS comparison covered 60 exact rows with zero ordered or event-set mismatches, and the two monthly sources contributed 9 and 8 exact subset rows. Only aggregate counts are recorded; no private value, path, filename, identifier, narration, reference or digest entered Git.
- **Sprint 75 focused acceptance:** The new PDF/lineage suite passed 8 tests; the final diagnostic correction passed 35 tests across the four affected legacy suites. The detector now selects exact institution rules by source extension so a broad PDF signature cannot admit a damaged XLS near-match.
- **Sprint 75 cycle-close acceptance:** After the material detector correction, the authoritative replacement cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 691 tests across 85 suites and zero failures. The earlier pre-correction cycle ran the same 691 tests and failed five tests with six reported issues; it is not acceptance evidence.
- **Sprint 76 profile and source semantics:** Added exact native selectable-text `amex.credit-card.pdf@1` for the approved American Express Middle East Platinum QAR statement family. Posting Date remains the canonical transaction date; source Transaction Date is preserved separately. Charges increase amount owed, payments/refunds decrease amount owed, and bank debit/credit fields remain unused. Account-level payments, instrument rows, original merchant Money, multiline narration, references, statement summaries and physical source order are preserved. Rewards and final informational pages remain non-financial only under exact family signatures.
- **Sprint 76 shared card domain:** ADR-044 reuses the durable credit-card `Account` as the liability account and adds immutable application-owned `CardInstrument` identity, source observations, explicit instrument relationships, bounded lifecycle state, card-specific transaction effects, typed statement evidence and a dedicated runtime `CardStore`. Masked Membership Number and Card Account Number observations never become strong identifiers. Exact durable user-confirmed mappings may be reused; changed weak evidence requires explicit account/instrument authority, and lifecycle or replacement is never inferred from chronology.
- **Sprint 76 persistence and hydration:** Additive Migration V12 adds seven restrictive card tables with no historical backfill. Provider-owned confirmed import atomically writes and revalidates the account/instrument/statement/transaction graph with SQLite/In-Memory parity. Canonical hydration reconstructs and validates that graph after close/reopen. Current liability balance is selected by newest source statement date, not import time, and published with net-worth sign; charges/payments do not enter ordinary bank income/expense totals.
- **Sprint 76 private-source acceptance:** The two approved originals were verified directly by SHA-256 and independent PDFKit row extraction. The earlier statement contained 61 rows and the later statement 34 rows. Ordered production-versus-independent comparisons produced zero row mismatches and zero summary mismatches for both statements; closing-to-opening continuity matched exactly. Chronological and reverse campaigns with both providers ended with one liability account, one instrument, 95 transactions, two statements and a runtime balance of negative QAR 7,761.88. Exact-byte duplicate handling, SQLite checkpoint/close/reopen and canonical hydration preserved the same graph. No private source path, filename, transaction list, identifier, narration or source-derived fixture entered Git.
- **Sprint 76 lifecycle falsification:** Exact previously confirmed observations reuse one instrument; changed weak evidence rejects without accepted residue until an explicit separate-account or additional/replacement/renewal/upgrade decision is supplied. No relationship changes lifecycle from `unknown`; stale provider generation and conflicting strong instrument ownership reject atomically in SQLite and In-Memory. Importing the older statement after the newer statement does not change current balance authority.
- **Sprint 76 focused acceptance:** The frozen Amex/migration/lifecycle boundary passed 61 tests across five suites. The adjacent CBQ, HDFC, Axis, bank-validation, categories, accounts and dashboard regression boundary passed 104 tests across 12 suites. The cycle-discovered V12 metadata correction passed 12 tests across two suites.
- **Sprint 76 cycle-close acceptance:** The authoritative replacement cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 701 tests across 86 suites and zero failures. The first cycle-close completed both builds but found four stale V11 test expectations; after the named V12-only correction, the replacement run is acceptance evidence.
- **Sprint 76A multi-instrument correction:** `CardStatementEvidence`, confirmation, persistence, hydration and presentation now preserve ordered `0...N` document-scoped instrument sections. Each section owns its typed card-account observation, explicit durable-instrument decision, financial rows and signed total; same holder text does not merge sections, section credit totals retain source direction and statement summary arithmetic remains separate.
- **Sprint 76A encrypted PDF and credential boundary:** The shared PDF reader unlocks the same immutable source snapshot and hands native text plus page boundaries to exact Amex normalization in memory; it creates no decrypted PDF file or reconstructed source bytes. Import coordination tries bounded remembered candidates, uses the secure UI challenge only when needed and persists a successfully used password under the detected institution's namespaced Keychain scope only after successful unlock and authoritative detection. Reader, parser, diagnostics, SQLite and source evidence never own the credential. Production Keychain persistence/reuse was manually proven; deterministic automation uses the already-authorized test-host or in-memory credential path.
- **Sprint 76A currency authority:** `ledgerforge.currency-catalog.v2` contains 155 deterministic active ordinary ISO 4217 List One currencies with numeric minor units from the SIX 2026-01-01 publication, excluding current List Two fund codes and List One `N.A.`-scale entries. Catalog membership and 0/2/3-digit Money mechanics do not imply parser or institution support, FX rates, conversion or reporting-currency totals.
- **Sprint 76A persistence and semantic sources:** Additive Migration V13 leaves V1–V12 immutable, migrates readable V12 single-section card graphs deterministically and adds ordered card-statement sections, section observations and exact semantic projection/group/member records. Byte-distinct sources may share one card semantic group only after complete ordered projection equality; the first is authoritative and exact later sources are supporting evidence with zero duplicate canonical transactions. SQLite/In-Memory parity, provider reconstruction, hydration and zero-residue rejection are enforced.
- **Sprint 76A exact Amex and private-source acceptance:** The exact `amex.credit-card.pdf@1` grammar now supports all section/page arrangements proven by ten source documents: eight encrypted originals and two byte-distinct unlocked equivalents. The eight chronological statements contain 21, 32, 49, 63, 34, 61, 34 and 60 financial rows, 354 total; 8/8 statement equations, 7/7 adjacent balance continuities, zero Posting Dates outside period and zero section reconciliation mismatches passed the independent oracle. Three instrument observations were preserved. Production-versus-oracle comparison, chronological/reverse/mixed campaigns, both equivalent-pair orders, combined ten-source import, SQLite/In-Memory parity and reopen/hydration passed. No private value, identifier, path, filename, password or decrypted artifact entered Git or documentation.
- **Sprint 76A cycle-close acceptance:** After correcting one stale test oracle that still treated newly supported JPY as unsupported, the authoritative replacement cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 721 tests across 87 suites, zero failures and zero skips. The first cycle-close completed both builds and ran the same 721 tests but failed only that stale expectation; it is not acceptance evidence.
- **Sprint 77 exact profile and model correction:** Added exact encrypted native-text `cbq.credit-card.pdf@1` with deterministic internal v1/v2 layout provenance. Financial account/instrument scope is now independent from optional physical source-section membership, so an account-level payment may contribute to its printed section subtotal without acquiring an instrument. Typed CBQ Card Account Reference and masked companion-instrument observations remain source evidence, not strong identity. CBQ current-account detection and ADR-043 lineage remain separate.
- **Sprint 77 reconciliation and persistence:** Card validation now selects exact Amex, CBQ v1 or CBQ v2 summary and section contracts through typed profile evidence. Additive Migration V14 leaves V1–V13 immutable, generalizes the four constrained card evidence tables, adds printed-summary membership and preserves existing V13 Amex graphs without semantic backfill. SQLite and In-Memory confirmation, exact-byte duplicate rejection, newest-source-date balance authority, close/reopen and canonical hydration preserve the same two-instrument shared-card graph; no CBQ-specific card domain was created.
- **Sprint 77 password boundary:** ADR-015's institution-scoped Keychain-backed PDF credential infrastructure is now a production dependency of exact Amex and exact CBQ card profiles. Remembered reuse, failed remembered-candidate replacement and save-after-authoritative-profile validation are verified. This establishes neither generic encrypted-PDF support nor password proof for unrelated Axis, HDFC, CBQ bank, investment or other layouts.
- **Sprint 77 private-source acceptance:** Eight approved three-page encrypted CBQ originals, split four v1/four v2, contain 15, 19, 28, 14, 11, 18, 12 and 16 financial rows, 133 total. The independent oracle produced 8/8 statement reconciliations, 6/6 valid supplied adjacent continuities, no fabricated May-to-July continuity, and zero row, section or statement-summary mismatches. Chronological, reverse and mixed campaigns in SQLite and In-Memory each ended with one liability account, two companion instruments, eight statements and 133 canonical transactions; exact duplicate rejection, SQLite reopen and hydration preserved the graph. No private value, identifier, path, filename, password, transaction listing or decrypted artifact entered Git or documentation.
- **Sprint 77 focused and cycle-close acceptance:** The final adjacent card, CBQ-bank, migration, password, confirmation and hydration boundary passed 131 tests with 156 parameterized executions and zero failures or skips. The authoritative replacement cycle-close passed fresh Debug and optimized Release builds plus the complete TestPlan with 733 tests across 90 suites, zero failures and zero skips. The earlier 730-test cycle preceded the audit-driven exact tail, ambiguity, source-page oracle and statement-date balance-authority corrections and is not final acceptance evidence.
- **Sprint 72 source semantics:** `Date` is the authoritative transaction date, `Value Dt` is retained separately, `Withdrawal Amt.` is debit/outflow, `Deposit Amt.` is credit/inflow, and source physical row order plus source ordinals are preserved. Printed period, opening/closing balances, debit/credit counts and totals reconcile independently for each statement.
- **Sprint 72 identity and fail-closed boundary:** Only the parser-produced verified full account number is emitted through the strong institution-account identifier contract. Shared customer identity and product metadata are excluded from account resolution. Missing, malformed, duplicate, reordered, near-match or ambiguous grammar, amount, date, identifier and summary evidence fails closed with zero accepted financial residue.
- **Sprint 72 private-source acceptance:** Four private-original XLS/PDF source families were verified locally through an independent paired-PDF oracle: 62, 16, 76 and 7 ordered rows, 161 total. Requested row-field mismatches, printed-summary mismatches and two annual-to-recent continuity mismatches were all zero. No private source value, path, filename, identifier, narration or reference entered Git or repository documentation; task-owned source-derived artifacts and private-test result bundles were removed after verification.
- **Sprint 60:** Completed the read-only account-outcome explanation contract across the bounded import workflow; no schema or historical rewrite occurred.
- **Sprint 61:** Implemented privacy-safe durable account-outcome presentation and explicit eligible no-match account choice. FinancialIdentityResolver behavior is unchanged: parser-produced strong verified identifiers remain the sole identity authority, and eligible no-match cases require explicit Use Existing Account or Create New Account choice. No automatic account selection was introduced. Prospective successful durable account decisions are `matched_existing`, `user_selected_existing` and `created_new`; rejected outcomes include `account_choice_required`, `identifier_ownership_conflict`, `identity_ambiguity`, `identity_conflict`, `stale_account_choice` and `stale_provider_generation`. Historical `selected_existing` and `resolved_or_created` remain neutral and are not reinterpreted. One shared bounded presentation authority serves preparation, immediate result and Import History; hostile and unknown values fail closed to neutral unavailable presentation. Account IDs, candidate IDs, normalized identifiers, suffixes, filenames, paths, fingerprints, raw codes and unrestricted errors are excluded from account-outcome copy and accessibility text. SQLite/In-Memory parity and rejected-path zero accepted residue were verified. No schema or historical rewrite occurred.
- **Sprint 61 integrated verification:** 466 top-level tests, 498 executions, 39 dynamic-parameter runs, 0 failures and 0 skips; Debug build, explicitly optimized whole-module Release build and Debug analysis passed. Isolated runtime acceptance used the approved sanitized Axis fixture against one fresh namespaced canonical V8 SQLite database. Preview, explicit choice, confirmation, immediate result, live Import History, quit/relaunch and hydration were verified. Runtime persisted and rehydrated 1 account, 4 transactions and 1 durable attempt. The task-owned namespace was removed recoverably after acceptance. No private source or user financial database was used. Manual linking, unlinking, reassignment, repair, account merge/split and raw identifier display remain excluded.
- **Historical repair boundary:** no retained affected historical Axis database is currently identified; no historical repair was performed
- **Architecture baseline:** Architecture v1.0 Frozen and UI/UX v1.0 Frozen
- **Latest verified repository-maintenance change:** `7ee20a909038d1088f830a6ea588311625f415e5`
- **Latest verified implementation-adjacent maintenance repair:** P0 Axis bank-account source-truth restoration; new imports use `axis.bank-account.csv@2`, physical DR is debit/outflow and physical CR is credit/inflow, and header positions remain dynamically resolved
- **Current overlap boundary:** ordinary no-overlap statements remain full imports, exact-content duplicates remain ADR-030 outcomes, and full supported event overlap remains whole-statement blocked; provenance-less mixed-overlap evidence is unsupported and cannot produce a new reviewed partial plan
- **ADR-040/V7 alignment:** reviewed-plan, disposition, attempt-count and hydration structures remain readable and validated, but the former provenance-less Axis partial-import family is suspended; mixed supported overlap currently fails closed
- **Source-byte boundary:** existing CSV history remains authoritative under `ledgerforge.raw-text.sha256.v1` with `ledgerforge.source-bytes.sha256.v1` secondary; PDF and XLS use `ledgerforge.source-bytes.sha256.v1` as their single duplicate authority and retain deterministic extracted/projected text only as secondary evidence, with one transient immutable `SourceContentSnapshot` and no durable raw PDF or workbook bytes
- **Sprint 58 duplicate acceptance:** an isolated exact duplicate left accepted transactions, sessions, documents, fingerprints, account state, balance and hydrated presentation unchanged, adding only one durable rejected duplicate attempt
- **Sprint 56 persistence:** Migration V7, immutable reviewed-plan digests, typed row dispositions, explicit attempt counts and strict hydration/relaunch reconstruction remain readable and validated for historical repository state, but no new partial session is authorized without lineage-backed overlap evidence
- **Current exclusions:** unapproved institutions/profiles, currencies outside exact supported paths, unsupported event families, generic mixed or interleaved overlap, arbitrary omission, fuzzy candidates, ownership override and historical repair remain unavailable
- **Sprint 57 categories:** workspace-owned user categories and one optional current category assignment per trusted imported transaction are durable, hydrated, manually editable and additive metadata only
- **Sprint 57 persistence:** additive Migration V8, SQLite/In-Memory parity, provider-generation protection, canonical hydration, provider reconstruction and SQLite close/reopen verification are implemented
- **Sprint 57 UI:** Settings supports create, rename, archive, restore and permitted delete; transaction detail supports assign, change and clear, and transaction rows display the current category
- **Sprint 57 exclusions:** automatic categorization, rules, suggestions, bulk editing, merge, delete-with-replacement, budgeting, analytics, reports, filtering, tags, splits and import behavior changes remain unavailable
- **Canonical development database:** a disposable canonical database was successfully recreated through the registered migration chain at V9; no private database contents are recorded here
- **Latest Sprint 65 focused result:** 381 tests across 43 suites passed; 0 failures, skips or expected failures; changed-file warnings 0 and analyzer diagnostics 0
- **Latest Sprint 65 complete-TestPlan result:** 607 tests across 73 suites passed; 0 failures, skips or expected failures; changed-file warnings 0 and analyzer diagnostics 0; 9 pre-existing warnings remained
- **Latest Sprint 67 focused result:** 36 tests across 3 suites passed with zero failures; hydration, forced refresh, atomic failure preservation, detail presentation, existing filters, confirmed-import recovery and SQLite relaunch coverage were included
- **Latest Sprint 67 complete-TestPlan result:** 616 tests across 73 suites passed with zero failures; one fresh Debug build passed, with only the pre-existing AppIntents metadata notice and unrelated Swift 6 transition warnings
- **Sprint 67 runtime verification:** one fresh namespaced V9 SQLite database imported the approved sanitized Axis NRE fixture through the ordinary Debug workflow; selected transaction detail showed authoritative account, institution, source document, import time, Money, direction, statement date, running balance, category and validation before and after quit/relaunch. The database held 1 account, 4 transactions, 1 document and 1 session, with all 4 transactions retaining account/document/session relationships. The task-owned namespace and build artifacts were moved recoverably to Trash.
- **Latest Sprint 67A focused result:** 80 tests across 4 suites passed with zero failures; exact document lookup parity, canonical hydration, malformed/legacy fail-closed behavior, typed detail presentation, category/search/toggle preservation and SQLite close/reopen reconstruction were included
- **Latest Sprint 67A complete-TestPlan result:** 622 tests across 73 suites passed with zero failures; one fresh isolated Debug build passed with only the pre-existing AppIntents metadata notice
- **Latest Sprint 68 focused result:** 153 tests across 14 selected suites passed; 0 failures, skips or expected failures. Fresh Debug and Release builds passed; the existing Swift 6 transition warnings remained outside this sprint's source boundary.
- **Sprint 68 runtime verification:** A fresh signed Debug app used one empty task-owned V9 namespace. Accessibility inspection verified only the five ordinary destinations, accurate file-chooser wording, preserved text search and Credits/Debits controls, absence of the removed placeholder affordances, and Developer Console visibility only while Developer Mode was enabled. Console category filtering and Copy All showed bounded diagnostics. Task-owned namespace, build products and result bundles were moved recoverably to Trash.
- **Sprint 68 TestPlan decision:** The complete `TestPlan.xctestplan` trigger did not fire: Developer Console storage/output, shared persistence, Money, hydration, import and mutation semantics were unchanged, and focused tests showed no cross-suite interference. Sprint 69 remains the cycle-wide TestPlan gate.
- **Latest Sprint 68A focused result:** A fresh Debug build passed. 97 tests across 8 selected suites passed with 0 failures, skips or expected failures; `git diff --check` passed. Existing Swift 6 transition warnings remained outside the Sprint 68A source boundary.
- **Sprint 68A runtime verification:** A fresh signed Debug app used one isolated task-owned V9 namespace. The idle import review was neutral with no Pending rows or footer pseudo-action; the ordinary approved sanitized-fixture flow showed real validation, explicit confirmation gating, no dashboard-account chevron, no account-detail star, working display-name editing and real transaction search plus Credits/Debits controls. Task-owned namespace, build products and result bundles were moved recoverably to Trash.
- **Sprint 68A TestPlan decision:** The complete `TestPlan.xctestplan` trigger did not fire: shared import-state logic changed only through presentation mapping; repository, hydration, Money, diagnostics and mutation code were unchanged; and focused tests showed no cross-suite interference. Sprint 69 remains the cycle-wide TestPlan gate.
- **Sprint 68A migration and ADR impact:** Migration remains V9 and ADR-041 remains the latest accepted ADR; neither changed.
- **Latest Axis source-truth automated result:** 426 top-level tests (458 parameterized executions), 0 failures and 0 skips in the complete signed canonical TestPlan before Sprint 65
- **Latest Axis source-truth focused result:** 41 top-level tests (46 parameterized executions), 0 failures and 0 skips across direction, source-oracle, NRO evidence, overlap-quarantine, shared-profile and direct-provider fail-closed suites using SQLite and In-Memory providers
- **Latest Axis source-truth build result:** fresh signed Debug and explicitly optimized Release builds plus Debug and Release static analysis pass
- **Private-source verification:** Sprint 65 exercised four original PDF/CSV pairs through separate fresh signed-app profiles, explicit confirmation and quit/relaunch hydration. Redacted results: NRE1 PDF 46 rows versus CSV 47 with matching first 46 ordered projections and one non-duplicate CSV row outside the PDF date range; NRE2 49/49 full projection, identity and summary parity; NRO1 PDF 16 versus CSV 17 with matching first 16 ordered projections and one non-duplicate CSV row outside the PDF date range; NRO2 20/20 full projection, identity and summary parity. Original PDF parser success is the hard acceptance authority. No private source value, path, filename, database or copied evidence entered Git, documentation, result bundles, diagnostics or build products.
- **Latest reported local automated result:** Sprint 69's canonical complete TestPlan recorded 628/628 tests passed with zero failures and zero skips
- **Latest focused category-reconciliation result:** 71 top-level tests (86 parameterized executions), 0 failures and 0 skips across category, hydrator, import-hydration, development-lifecycle and migration-integrity suites
- **Latest reported local build result:** Sprint 69 fresh Debug and Release builds passed before the reported canonical TestPlan result
- **Sprint 71 acceptance evidence:** All named focused reader, normalizer, parser, detector/classifier, source-snapshot, fingerprint, provider-parity, persistence, hydration and relaunch suites passed with nonzero execution. The authoritative cycle-close passed fresh Debug and Release builds and 643 tests across 76 suites with zero failures or unexpected skips. SQLite and In-Memory exact-reimport outcomes matched, provider reconstruction and SQLite close/reopen preserved the complete XLS graph, and rejection tests left zero accepted residue.
- **Sprint 71 Release boundary:** The arm64 Release app contains the XLS bridge and libxls symbols statically in the executable, links the system `libiconv`, contains no libxls dynamic library and requires no bundled Java, Python or LibreOffice runtime. The repository contains the verbatim upstream license and concise third-party notice. Migration remains V9 and ADR-041 remains the latest accepted ADR.
- **Sprint 72 acceptance evidence:** The consolidated focused boundary discovered and executed 207 tests across 29 selected suites with zero failures. The single authoritative cycle-close passed fresh Debug and optimized Release builds plus 655 tests across 79 complete-TestPlan suites with zero failures or unexpected skips. SQLite and In-Memory outcomes matched; exact-byte duplicate rejection, atomic confirmed persistence, canonical hydration, provider reconstruction and SQLite close/reopen relaunch preservation passed.
- **Sprint 72 migration and ADR impact:** Migration remains V9 and ADR-041 remains the latest accepted ADR. HDFC PDF production support remains the separately bounded Sprint 73 outcome; HDFC CSV, XLSX, cards, generic HDFC layouts and cross-format suppression remain unsupported.
- **Sprint 73 implementation boundary:** `ledgerforge.statement-financial-projection.sha256.v1` deterministically covers institution, statement family, declared period, INR, derived opening balance, debit/credit counts and totals, closing balance, and every ordered event's ordinal, statement date, value date, direction, signed Money, running balance and explicit reference absence. It excludes filenames, source fingerprints, parser profile, physical ordinals, narration, display account name, customer identity and inferred NRE/NRO subtype.
- **Sprint 73 provider behavior:** SQLite and In-Memory resolve the exact account/family/period/currency group inside the provider-owned confirmed-import transaction. First-source and supporting-source graphs are atomic; supporting acceptance records `equivalent_source_recorded`, zero imported transactions, a second document/session/source-byte fingerprint/projection/member and an identifier observation without changing existing transactions, categories or authority. Exact bytes still return `exact_statement_duplicate`; projection conflict, missing pre-V10 evidence and represented byte-different format return `statement_equivalence_conflict`, `statement_equivalence_evidence_unavailable` and `equivalent_format_already_recorded` respectively.
- **Sprint 73 migration and ADR impact:** Additive Migration V10 introduces source projections, contiguous ordered projection events, equivalence groups and authoritative/supporting members with restrictive relationships and no historical backfill. ADR-042 is the latest accepted ADR. Existing V9 history remains readable; complete HDFC event overlap without durable V10 evidence fails closed rather than inventing period or equivalence truth.
- **Sprint 73 private-source acceptance:** All four retained PDF/XLS pairs matched at 62, 16, 76 and 7 ordered rows, 161 total. Direct field mismatches, printed-summary mismatches and production projection mismatches were zero. Both PDF→XLS and XLS→PDF orders retained one transaction set and two source records per pair; SQLite close/reopen and canonical hydration preserved the graph. Only aggregate counts are recorded.
- **Sprint 73 focused verification:** The final consolidated boundary passed 358 tests across 39 suites with zero failures. It covered the ordinary HDFC PDF URL route, exact PDF/XLS projection, Migration V10, SQLite/In-Memory equivalence parity, supporting-write rollback injection, source snapshots and fingerprints, identity ownership, confirmed-import atomicity, canonical hydration, provider reconstruction and result/history presentation.
- **Sprint 73 runtime verification:** One representative 7-row private pair was exercised through the signed Debug app on an isolated Persistent Debug Database at V10. PDF-first explicit confirmation created 7 authoritative transactions; the paired XLS presented and committed `equivalent_source_recorded` with 0 new transactions and no transaction-navigation action. Live Import History distinguished both outcomes, and quit/relaunch plus profile reactivation hydrated the same 7/0 aggregate counts and both durable outcomes.
- **Sprint 73 exact exclusions:** No fuzzy or narration similarity, partial overlap, same-format semantic acceptance, Axis/CBQ/card equivalence, authority switching, source replacement, provenance reassignment, historical repair/backfill, OCR, password workflow, HDFC CSV/XLSX/cards, generic PDF/spreadsheet parsing or document-byte storage is implemented.
- **Post-Sprint 57 runtime verification:** an isolated fresh Debug launch created a category, imported the approved sanitized Axis fixture, assigned that category to a trusted transaction, quit/relaunched and verified the category and assignment persisted; the task-owned process was stopped and only its isolated database set was moved to Trash
- **Previous Sprint 55 automated result:** 409 top-level tests across 49 suites, 0 failures and 0 unexpected skips in each of three consecutive exact canonical default-parallel TestPlan runs
- **Latest focused Sprint 55 results:** 41 Axis direction, fixture-oracle and confirmation-gate tests across 5 suites plus 64 adjacent event, validation, repository, atomicity and hydration tests across 6 suites, all with 0 failures and 0 unexpected skips
- **Sprint 55 acceptance closure:** the first completion attempt exposed cross-suite interference between tests mutating shared runtime singleton stores; a bounded test-only asynchronous exclusivity trait now coordinates only those global-state tests across Swift Testing suites, retains ownership across suspension and restores the shared provider generation, runtime financial/history stores, diagnostics and development activity state after success or failure
- **Sprint 55 overlap-period oracle:** retained only as a quarantined synthetic architecture regression; it verifies internal arithmetic and period parsing but cannot authorize production partial import because immutable source lineage is unavailable
- **Previous Sprint 55 build result:** Debug and explicit `-O` whole-module Release builds passed
- **Generic UI-test state:** `LedgerForgeUITests` remains intentionally disabled
- **Sprint 56 test-host isolation:** `TestPlan.xctestplan` explicitly marks the app-hosted test process with `LEDGERFORGE_TEST_HOST=1`; `LedgerForgeApp` selects intentional test memory for that exact marker before resolving any default SQLite path, while unmarked Debug and Release launches retain normal persistence bootstrap
- **Sprint 56 acceptance correction:** strict hydration now cross-checks each partial session against exactly one committed partial attempt and its document, transaction, source, imported, recognized and blocked counts before replacing any runtime store
- **Sprint 56 runtime verification:** no canonical application launch was used; acceptance uses signed app-hosted tests with isolated providers and source/presentation verification
- **Historical Axis source-truth runtime boundary:** prior automated acceptance did not launch private originals or a canonical database. Sprint 65 additionally performed the explicitly authorized signed-app acceptance against read-only originals through separate disposable profiles; no original was copied, committed or durably stored, and all task-owned profiles were removed recoverably after hydration.

GitHub establishes pushed repository state only. It does not establish local worktree cleanliness, linked worktrees, local branches, stashes, staged or unstaged changes, untracked files or unpushed commits.

---

## Current Project Qualification

LedgerForge is a private, single-user finance application that remains work in progress and is not currently used to store real financial data. Every current database is disposable development/test state until the user explicitly declares the personal-v1 adoption freeze.

This qualification reduces backup, preservation and rollout ceremony during current development. It does not weaken deterministic financial semantics, migration correctness, database switching, provider-generation safety or Release privacy boundaries.

Personal-v1 adoption remains undeclared. LedgerForge is not currently an active production financial database or a multi-user product rollout.

---

## Current Production Capability

### Supported import family

Production import support is limited to the exact Axis, HDFC and CBQ
bank-account profiles documented in this section. The supported Axis CSV/PDF
families are represented by:

- the approved Axis Bank NRE CSV evidence;
- the supplied shared-layout Axis Bank NRO CSV evidence.
- the two selected unlocked/selectable-text Axis bank-account PDF families exercised in Sprint 65, with NRE/NRO labels treated as source data rather than profile identity.

Both use one production `AxisBankAccountParser`.

The selected PDFs use one account-neutral production `AxisBankAccountPDFParser`.

New supported imports emit:

```text
axis.bank-account.csv
version 2
```

PDF imports emit:

```text
axis.bank-account.pdf
version 1
```

Historical durable provenance using:

```text
axis.nre.csv
version 1
```

remains readable and is never rewritten merely to adopt the neutral forward profile.

The exact retained native-text HDFC bank-account PDF grammar is supported as
`hdfc.bank-account.pdf@1`, paired only with `hdfc.bank-account.xls@1` for exact
whole-statement equivalence.

CBQ current-account production support is limited to the exact retained
profiles:

- `cbq.current-account.xls@1`;
- `cbq.current-account.history.pdf@1`;
- `cbq.current-account.monthly.pdf@1`.

Those three CBQ profiles use ADR-043 exact reviewed source overlap and durable
per-source observations. No broader Axis PDF/XLS layout, OCR,
password-protected statement, historical Axis layout, XLSX, card, HDFC
CSV/XLSX, changed or generic HDFC/CBQ layout, American Express or other
institution support is claimed. ADR-043 is not generic cross-format
equivalence and does not extend ADR-042 beyond HDFC.

### Trusted source semantics

Supported Axis imports preserve:

- dynamic physical source-column position resolution without treating a source header label as a canonical financial role;
- the `axis.bank-account.csv@2` direction contract in which physical DR decreases balance and maps to canonical debit/outflow, while physical CR increases balance and maps to canonical credit/inflow;
- the selected Axis PDF grammar's exact `dd-MM-yyyy` statement dates, `Asia/Kolkata` date authority, source order, running-balance arithmetic, printed totals and opening/closing reconciliation;
- strict date-only financial evidence;
- Axis `Asia/Kolkata` date authority;
- document-scoped source ordinal;
- normalized source-record digest;
- parser-produced profile identity and version;

Supported CBQ current-account imports additionally preserve source-specific
posting-date authority, signed QAR Money, row-associated balances and physical
source order. History exports preserve full account identity while leaving
period, source transaction/value date and unavailable summary evidence absent.
Monthly statements preserve masked account/IBAN evidence, source Transaction
Date separately from posting date, and only printed boundary/opening/closing
evidence; brought-forward and exact promotional-page content do not become
transactions.
- durable transaction-to-source provenance;
- source-supported same-document ordering;
- source-supported running-balance interpretation.
- PDF source-byte identity under `ledgerforge.source-bytes.sha256.v1`; extracted-text identity is retained only as non-authoritative secondary evidence.

Printed transaction dates do not pass through `Foundation.Date`.

### Universal import pipeline

The production path performs:

1. source reading;
2. institution detection;
3. statement classification;
4. parser selection;
5. immutable `FinancialDocument` creation;
6. validation;
7. duplicate and transaction-event evaluation;
8. explicit user review and confirmation;
9. provider-owned persistence;
10. canonical hydration through `RepositoryStoreHydrator`;
11. runtime-store and presentation publication.

Readers own source-format extraction. Parsers own financial interpretation.

### Atomic confirmed import

Sprint 50 routes accepted confirmations through one provider-owned transaction that revalidates:

- provider generation;
- reviewed account and identity decisions;
- identifier ownership;
- exact-content document fingerprint claims;
- supported transaction-event ownership claims;
- the complete accepted financial graph.

SQLite and In-Memory providers return equivalent typed outcomes.

Verified contention coverage includes:

- same-process competition;
- independent providers;
- genuine separate-process SQLite competition;
- one accepted winner;
- truthful losing outcomes;
- zero losing-path accepted financial residue.

The guarantee applies only to approved writers using the registered schema and enabled constraints. Schema-altering, constraint-disabling or corrupting writers remain outside it.

### Persistence and migration integrity

`DatabaseProvider` is the atomic authority for active repositories and typed persistence state.

Production publishes a SQLite repository only after:

- opening succeeds;
- the complete registered migration-chain history validates;
- pending migrations execute successfully;
- the final migration chain revalidates.

The active chain ends at V14. Migration V7 adds explicit partial-attempt counts, durable partial-import summaries and one typed incoming-row disposition per normalized source row for ADR-040. Additive Migration V8 adds workspace-owned categories and a separate restrictive current transaction-category assignment relationship without changing imported financial rows or provenance. Migration V9 adds versioned document-fingerprint authority and the source-byte fingerprint relationship without storing source bytes. Additive Migration V10 adds exact statement projections, ordered projection events, equivalence groups and authoritative/supporting members without backfilling existing history. Additive Migration V11 adds typed CBQ masked source-identity observations, statement-source observations and one transaction-source observation for every accepted CBQ financial row. Additive Migration V12 adds durable card instruments, strong instrument identifiers, source observations, explicit instrument relationships, statements, typed summaries and one-to-one card transaction evidence. Additive Migration V13 adds ordered card-statement sections, section-owned observations and exact card semantic projections/groups/members while deterministically migrating readable V12 single-section graphs. Additive Migration V14 transactionally generalizes the four constrained card evidence tables for exact CBQ observations, family summary components, printed-summary membership and account-level physical section membership while preserving V13 Amex rows unchanged. V11 and V12 perform no historical backfill; V13 and V14 perform no speculative financial or lifecycle inference.

Open, initialization, migration-integrity or migration-execution failure installs centrally rejecting unavailable repositories rather than silently substituting an in-memory repository.

Import preparation, confirmation, hydration and account metadata mutation gate early when persistence is unavailable. Repository operations remain centrally fail-closed.

### Hydration authority

`RepositoryStoreHydrator` is the sole persistence-to-runtime boundary.

Sprint 52A requires hydration to fail before runtime-store mutation when trusted rows contain:

- unsupported financial-date roles;
- malformed or invalid-IANA timezone evidence;
- missing or conflicting source relationships;
- missing, malformed or conflicting parser-profile provenance.

Trusted transaction graphs are accepted only through the provider-owned confirmed-import path. Generic transaction replacement cannot publish trusted imported transactions.

For ADR-043 CBQ graphs, hydration validates every statement/row observation and
selects monthly PDF, then history PDF, then history XLS for preferred
source-evidence presentation without changing the canonical transaction's
durable document or import-session provenance.

Category definitions and transaction assignments are read with the trusted financial graph, validated before publication and published as one category snapshot. Category mutations reconcile through the same canonical hydrator; runtime category state is not durable authority. A committed mutation whose hydration fails preserves durable repository truth, leaves the last complete runtime snapshot unchanged, blocks later category mutations with a distinct reconciliation-required result, and provides an explicit canonical hydration retry. Provider replacement and lifecycle transitions clear stale prior-generation category state only after replacement hydration succeeds.

### Durable categories and manual classification

Sprint 57 provides user-created workspace categories with stable identifiers, deterministic normalized-name uniqueness and archival state.

Settings supports create, rename, archive, restore and deletion only when unused. Transaction detail supports one manual category assignment, change or clear for a persisted trusted transaction. Archived categories retain existing assignments but cannot receive new ones.

The assignment is stored in a separate relationship. Changing it does not update transaction amounts, dates, balances, identifiers, normalized rows, import sessions, provenance or parser output. SQLite and In-Memory providers enforce equivalent behavior, and deletion remains restrictive while a category is assigned.

Automatic categorization, rules, suggestions, bulk assignment, merge, delete-with-replacement, hierarchy, tags, splits, filters, budgeting, analytics and reports remain future work.

### Financial identity

Parser-owned verified identity resolution supports the approved strong-identity
bank-account paths. ADR-043 adds one typed CBQ-only partial-identity review
without weakening the generic resolver.

Distinct parser-produced full institution account identifiers retain distinct durable accounts. Shared customer context, profile identity, filenames and neutral presentation labels are not account-identity authority.

The supported workflow provides:

- verified existing-account resolution;
- explicit eligible existing-account choice for bounded no-match cases;
- explicit new-account creation;
- transaction-time identifier ownership enforcement;
- durable accepted-import identifier observations.

Identifier unlinking, reassignment, incorrect-link recovery, contradictory-ownership repair and historical backfill remain separately gated.

CBQ masked account/IBAN observations are source evidence, not owned full
identifiers. Exact positional compatibility can resolve a unique current
account, narrow explicit choice to compatible accounts or permit a new
masked-only account. A later compatible full history identifier attaches
atomically through existing ownership rules; ambiguity, stale review or a
conflicting full identifier rejects with zero accepted financial writes.

### Duplicate and overlap handling

Exact reader-content duplicate protection uses the versioned ADR-030 authority.

Exact-content re-import records a bounded duplicate attempt without creating another:

- accepted import session;
- document;
- account;
- identifier;
- identifier observation;
- transaction.

Bounded parser-verified Axis UPI transaction-event ownership uses ADR-031.

Axis UPI event overlap is currently whole-statement blocked. Ordinary no-overlap statements remain full imports and exact-content duplicates remain ADR-030 outcomes. The former ADR-040 mixed-overlap exception is suspended because its synthetic three-shared/one-later fixture has no immutable source lineage; both providers return unsupported evidence without accepted residue for that shape.

Migration V7, immutable reviewed plans, SQLite/In-Memory commit paths, durable partial summaries and dispositions, strict hydration and bounded UI presentation remain capable of reading and validating historical repository state. They do not authorize a new partial import until immutable source evidence proves a bounded family again. Interleaved overlap, unsupported event families, arbitrary omission, fuzzy matching and historical repair remain unavailable.

Unsupported event families remain unevaluated, including:

- IMPS;
- NEFT;
- e-commerce and card events;
- refunds;
- reversals;
- unstructured references.

Separately, the exact three-profile CBQ current-account family supports
reviewed all-new, mixed and fully represented source overlap under ADR-043. It
uses exact account resolution plus posting date, signed QAR amount and running
balance, with an exact structured-reference digest only when a tuple collision
needs disambiguation. Every accepted source row remains represented; fuzzy
matching and generic partial import remain unavailable.

### Import history and workflow state

Sprint 42 provides durable, privacy-safe import-attempt history with bounded:

- outcomes;
- coverage;
- account-decision provenance;
- guidance.

Rejected attempts remain distinct from successful import sessions.

Sprint 43 provides:

- deterministic named preparation stages;
- stable active-operation ownership;
- safe pre-persistence cancellation;
- bounded fresh retry for typed source-reading failures.

Cancelled preparation is neither trusted persistence nor durable attempt history.

Confirmed persistence is explicitly non-cancellable and remains repository-owned.

Typed confirmed-import recovery distinguishes wholly fresh preparation for authorized zero-commit outcomes, canonical reconciliation for committed hydration failure, and reconciliation followed by wholly fresh preparation when confirmation was blocked by an earlier reconciliation requirement. Review-required, unknown, malformed, hostile and unavailable outcomes expose no mutation action.

No rollback, compensation, resumable import job, batch queue, retry confirmation, automatic confirmation or cancellation after confirmed persistence exists.

### Financial presentation

Dashboard, Accounts, Transactions and Imports are repository-backed experiences.

Current presentation preserves:

- authoritative transaction `Money`;
- native currency;
- grouped native-currency summaries;
- transaction-specific validation provenance;
- current-workflow precedence;
- deterministic latest durable-attempt selection;
- neutral handling for some unknown latest-activity states.

Mixed-currency values are not combined into one total. FX conversion is not implemented.

Sprint 54 completed `FW-P0-24` with one typed presentation authority for durable import-attempt outcome, coverage and guidance. Dashboard Import Activity, Import History list/detail and affected accessibility presentation use the same exhaustive bounded mapping. Unknown, malformed or future codes produce neutral output without reflecting raw values. Current-workflow precedence and deterministic latest-attempt ordering remain unchanged.

### Settings and repository status

Settings and Developer Console distinguish:

- verified durable SQLite;
- unavailable persistence;
- explicitly selected non-durable Debug or test providers.

They do not expose database paths, raw SQL or raw SQLite errors.

Settings retains:

- functional Developer Mode;
- authoritative repository/runtime information;
- durable Completed Imports truth;
- bundle-derived version/build presentation.

`Completed Imports` counts unique hydrated durable sessions represented by committed `successful_import` or `partial_import_committed` attempts with both an import session and a document. Partial sessions are also counted separately as a subset. Duplicate, repeated, failed, rejected and cancelled attempts do not increment either count. Non-durable or unavailable persistence displays `Unavailable`.

### Development database lifecycle

Sprint 45 Phase A provides a DEBUG-only `DevelopmentDatabaseLifecycleCoordinator` and activity gate.

DBP-01 expands that lifecycle into four explicit DEBUG-only profiles:

- Current Database retains the canonical Debug identity and is selected on ordinary launch;
- Persistent Debug Database uses a separate stable application-owned identity;
- Temporary Session uses a lifecycle-owned process-temporary identity;
- Migration Sandbox uses a lifecycle-owned temporary identity constructed from a registered historical migration prefix.

Profile activation is explicit. Candidate construction, migration and staged canonical hydration finish before one observer-atomic publication of provider generation, runtime stores, active profile and schema metadata. Active lifecycle work blocks switching, and repositories or confirmed-import work captured from a stale generation reject.

Developer Mode is process-local and begins off on every launch. Remembered selection is passive until explicit activation, and disabling Developer Mode commits Current Database before the toggle becomes off. Non-current profiles show a bounded app-wide warning, and the first protected mutation in each non-current provider generation requires process-local, generation-scoped acknowledgement. Switching or reset clears that acknowledgement.

Canonical identities:

```text
Development:
Application Support/LedgerForge/Development/ledgerforge-development.sqlite

Non-development:
Application Support/LedgerForge/ledgerforge.sqlite
```

Permanent Debug reset:

- checkpoints and closes the provider;
- creates and verifies the lifecycle-owned backup;
- coordinates the SQLite, WAL and SHM set;
- recreates the canonical identity through the registered migration chain;
- forces canonical hydration.

Temporary empty sessions use UUID databases under:

```text
Application Support/LedgerForge/Development/Temporary Sessions
```

They affect only the current process and reconnect to canonical data after relaunch.

Automatic recovery restores the verified lifecycle backup. Failed recovery enters lifecycle-unavailable state.

Current Database cannot be reset through profile controls. Non-current reset and recreation remain lifecycle-owned, and arbitrary or symlink-escaping paths are rejected.

Lifecycle operations are excluded while any of the following is active:

- import preparation;
- prepared confirmation;
- confirmed persistence;
- hydration or reload;
- repository writes;
- another lifecycle operation.

All database-profile selection, warning, reset, acknowledgement and approved-fixture machinery is compile-time absent from optimized Release builds. DBP-01 added no migration and changed no financial parser or durable financial semantics.

### Repository metadata hygiene

Commit `7ee20a909038d1088f830a6ea588311625f415e5` removed tracked user-specific Xcode state, including:

- Find Navigator scope state;
- breakpoint-list state;
- scheme-management user state.

Shared Xcode configuration remains distinct from personal IDE state.

---

## Current Verified Limitations

### Production format and institution limits

- Production parser support is limited to the exact documented Axis, HDFC and CBQ bank-account profiles plus the exact Amex and CBQ credit-card profiles; no generic institution or layout claim exists.
- General Axis NRO coverage and additional Axis layouts remain unsupported.
- Other Axis PDF layouts, OCR, arbitrary password-protected PDFs and generic PDF statement support remain unsupported. Encrypted production support is limited to exact `amex.credit-card.pdf@1` and `cbq.credit-card.pdf@1`.
- XLSX, TXT and OCR are not production-supported. XLS is supported only for the exact documented Axis, HDFC and CBQ profiles.
- HDFC and CBQ bank-account support is limited to their exact documented profiles. Card support is limited separately to exact `amex.credit-card.pdf@1` and `cbq.credit-card.pdf@1`; no other American Express/CBQ layout or issuer card family is supported.
- Production secure password entry and institution-scoped Keychain reuse exist for exact encrypted `amex.credit-card.pdf@1` and `cbq.credit-card.pdf@1`; this does not establish arbitrary encrypted-PDF or generic credential-profile support.
- QAR production import exists only for the exact three-profile CBQ current-account family under ADR-043 and the exact Amex/CBQ card profiles under ADR-044.

### Card limits

ADR-034's document-scoped evidence boundary is implemented and refined by
ADR-044 for the shared Sprint 77 foundation and exact
`amex.credit-card.pdf@1` and `cbq.credit-card.pdf@1` profiles. Durable liability accounts, card instruments,
source observations, explicit relationships, statement sections and summaries,
transaction evidence, Migration V14, SQLite/In-Memory parity, hydration and
bounded presentation are operational for those profiles.

The following remain unimplemented: Axis and HDFC card parsers; additional Amex
or CBQ layouts; generic card profiles or masked identity; rewards persistence or
valuation; payment allocation; bank-card payment matching; refund/reversal
matching; installments/loans; calculated FX; invented fees, markup or tax;
manual merge/split; historical repair/backfill; OCR and arbitrary encrypted-PDF workflows.
Fixture integration, statement classification or schema capacity does not
establish support beyond the exact accepted profile.

### Currency limits

ADR-033, Sprint 44 and Sprint 76A provide:

- the versioned 155-code active ordinary-currency catalog v2;
- canonical catalog-scale persistence;
- exact decimal/minor/currency hydration;
- SQLite/In-Memory parity;
- grouped native-currency presentation.

Sprint 44 itself introduced no migration. The repository later advanced to V6 through other work.

The following remain unimplemented:

- exchange-rate storage;
- historical conversion;
- selectable reporting currency;
- converted or consolidated mixed-currency totals.

### Mutation and repair limits

Sprint 50 does not establish a generic financial-mutation executor, rollback system or compensation framework.

The following remain separately governed:

- historical duplicate repair;
- identifier correction and detachment;
- account split or merge;
- import-session reversal;
- transaction deletion or movement;
- broad data-integrity repair;
- bulk transaction mutation.

### Historical compatibility limits

`FT-P0-01` and `FW-P0-21` referred to the same date-only defect. Sprint 52 completed it through ADR-039 and Migration V6.

`FT-P0-02` and `FW-P0-22` referred to the same source-order/provenance defect. Sprint 52 completed it through ADR-039 and Migration V6.

Existing nonempty V5 financial graphs fail closed for explicit pre-production reset rather than receiving reconstructed dates, order or provenance.

Legacy exact-statement fingerprint backfill is not performed from reduced repository data.

Axis bank-account imports accepted with `axis.bank-account.csv@1` from Sprint 55 commit `9598c6de6a701d14b0d4afb37d5adb27e9fc82e0` through the parent of the current P0 restoration commit may contain reversed canonical direction, signed `Money` and direction-dependent UPI subtype. Earlier alternating parser revisions also require provenance-led audit rather than inference. Repository evidence cannot prove which historical databases contain affected rows, so detection and any repair remain a separately gated `FW-P0-08` family. This restoration performs no historical mutation.

### Test and runtime limits

- Generic UI tests remain intentionally disabled.
- Supported UI behavior relies on the documented automated and manual acceptance boundaries.
- Unmanaged manual launches can attach to a stale DerivedData build when multiple LedgerForge processes exist.
- `./script/build_and_run.sh` is the repository-owned exact-singleton local build/run entry point; its contract resolves one fresh Debug bundle and process before UI attachment.
- `./script/validate.sh` is the repository-owned local build/test entry point. CI, generic UI smoke automation, commit-status protection and distribution/notarization remain open maintenance work.

---

## Approved Fixture Evidence

Fixture integration supplies discovery and regression evidence. It does not by itself establish production support.

Approved direction evidence now consists of the verified NRO clean-room transaction rows and a privacy-safe, non-reversible NRE semantic derivative. Independent exact-decimal oracles derive direction from physical column occupancy plus running-balance deltas and an independently supplied opening balance. They verify physical DR as debit, physical CR as credit, exact amount/delta agreement, source order, totals and complete reconciliation without consulting production parser output.

The original private statements remain outside Git and are read-only evidence. The available two NRE and two NRO private CSV families independently provide 94 and 35 observable row-to-row balance deltas respectively, all conventional. The legacy 81-row/31-row NRE fixtures and the synthetic partial-overlap pair remain privacy-safe structural fixtures but are explicitly ineligible to establish source truth because their immutable transformation lineage is unavailable.

### Axis bank-account evidence

Approved evidence includes:

- a privacy-safe source-derived Axis NRE CSV semantic regression;
- legacy Axis NRE CSV/PDF structural evidence quarantined from financial-truth acceptance pending source lineage;
- verified clean-room Axis NRO CSV transaction rows;
- Axis NRO PDF and XLS evidence across two overlapping ranges.

The supported production path is CSV only.

The approved NRO runtime evidence preserves two distinct durable Axis accounts from two distinct verified full institution account identifiers.

### Axis card evidence

Clean-room Axis credit-card PDF and XLSX evidence is integrated for two consecutive non-overlapping periods.

The evidence preserves:

- one fictional customer, account and instrument;
- source-observed posted INR;
- distinct PDF and XLSX row sets where the source formats genuinely differ;
- source geometry and workbook structure;
- no invented original-currency or FX evidence.

Axis card PDF/XLSX production parsing remains unsupported.

### HDFC bank-account evidence

Clean-room HDFC NRE and NRO evidence is integrated for:

- annual PDF/XLS pairs;
- recent PDF/XLS pairs;
- legacy XLS periods.

Each approved PDF/XLS pair reconciles against its independent financial baseline.

The evidence preserves verified financial, pagination, geometry and multiline relationships while intentionally not preserving original PDF object identity.

Production supports the exact retained HDFC NRE/NRO OLE2/BIFF8 grammar as
`hdfc.bank-account.xls@1` and the exact paired native selectable-text grammar as
`hdfc.bank-account.pdf@1`. The four private-original pairs were independently
verified locally at 62, 16, 76 and 7 ordered rows, 161 total, with zero direct
row-field, printed-summary or production-projection mismatches. Both import
orders produce one financial event set: the first format remains authoritative
for transactions and provenance and the later exact-equivalent format is
durable supporting evidence with zero transactions. The shared semantics do
not infer NRE/NRO subtype from filenames, transaction similarity, customer
identity or the neutral printed product label; the account families remain
distinct through their verified account-number identifiers. HDFC CSV, XLSX,
cards, OCR, locked/password-protected PDFs and other HDFC layouts remain
unsupported.

### CBQ bank-account evidence

Invented, self-contained mechanics fixtures cover the exact history PDF,
monthly PDF, byte-distinct monthly variant and legacy-XLS profiles. The PDFs
retain selectable text and exercise exact pagination, repeated/retained table
geometry, multiline rows, brought-forward handling and non-financial
promotional-page exclusion. They are regression mechanics, not private-source
financial oracles.

Private acceptance independently established a 60-event history set with zero
PDF/XLS ordered or set mismatches and two monthly subsets of 9 and 8 events.
Four import orders in each provider ended with one account, 60 canonical
transactions, four durable source attempts and 60 preferred-source mappings;
SQLite reopen preserved that graph. No private source content or identifying
metadata is recorded.

Production bank-account support covers only `cbq.current-account.xls@1`,
`cbq.current-account.history.pdf@1` and
`cbq.current-account.monthly.pdf@1`. Exact CBQ card support is a separate
`cbq.credit-card.pdf@1` family; generic/changed layouts, XLSX, OCR, image-only
PDFs, generic masked identity and generic overlap remain unsupported.

### CBQ card evidence

Clean-room CBQ credit-card PDF evidence remains integrated for four fictional periods, while exact production authority comes from eight approved encrypted originals across:

- v1 legacy layout;
- v2 equation-style layout.

The evidence preserves:

- one fictional customer and account;
- two neutral companion-instrument sections with no primary/supplementary inference;
- exact transaction assignment;
- posted QAR distinct from original merchant amount and currency;
- explicit source-observed fees;
- no invented FX rates, markup, taxes or absent aggregates.

Production `cbq.credit-card.pdf@1` selects internal v1/v2 layouts exactly,
preserves financial scope independently from physical section membership, uses
family-specific reconciliation and typed weak observations, and persists through
the shared ADR-044 card domain. Other CBQ card layouts remain unsupported.

### American Express card evidence

Clean-room American Express card PDF evidence is integrated as a fictional
five-page native-text fixture plus an encrypted semantic twin. The accepted
private source boundary contains eight chronological statements and two
byte-distinct unlocked equivalents; only aggregate acceptance facts are
recorded.

The evidence preserves:

- one fictional liability account and three ordered instrument sections,
  including repeated holder text and a different holder;
- account-level payments distinct from instrument transactions;
- posted QAR separate from original merchant amount and currency;
- signed per-section totals, zero-/two-/three-decimal currency mechanics,
  nonmonotonic Posting Dates and multiline travel relationships;
- exact rewards, legal, pagination and continuation-page exclusion boundaries;
- no invented FX rates, fees, markup or tax.

Exact `amex.credit-card.pdf@1` production parsing, durable multi-instrument card
semantics, exact semantic-source grouping and encrypted import through the
institution-scoped Keychain flow are supported. Other Amex layouts, generic
card equivalence, OCR and arbitrary encrypted PDFs remain unsupported.

---

## Recent Verified Changes

### Sprint 68B, DBP-01 Maintenance Correction and Sprint 69 — Local Validation Closure

**Ref and evidence classification**

The repository implementation closure preceding this documentation-only update is
`main@6873d6c50e63042819a41b859254ff149a8bda3d`. The scripts, Codex Run action,
test changes and documentation present at that ref are repository-verifiable.
The acceptance execution results below are reported local evidence from the
accepted closure; this documentation-only update did not rerun builds or tests.

**Repository-verified scope**

- Sprint 68B is a test-only bounded persistence-error-contract correction. It
  retains the generic public wrapper message while preserving typed identity
  outcomes and durable-attempt authority.
- The DBP-01 maintenance correction gives successful prepared imports explicit
  test lifecycle ownership and uses target-wide isolation for shared
  lifecycle-gate coverage. It changes no production lifecycle behaviour,
  migration or ADR.
- Sprint 69 provides `./script/validate.sh` for the canonical local build/test
  interface and `./script/build_and_run.sh` for exact-singleton local Debug
  Run/stop verification. The Codex Run action invokes
  `./script/build_and_run.sh --verify`.

**Reported local acceptance evidence**

- The two modified containing suites passed 36/36 tests, Account Metadata
  passed 4/4, and each fresh interference combination passed three consecutive
  times: Account Metadata plus Axis Shared (11/11 each) and Account Metadata
  plus the unconfirmed-preparation test (5/5 each). All reported zero failures
  and zero unexpected skips.
- Fresh Debug and Release builds passed. The canonical complete TestPlan
  recorded 628/628 tests passed with zero failures and zero skips.
- The reported isolated Run built a fresh Debug bundle, verified one PID and
  executable path against that bundle, used the intentional non-durable
  `LEDGERFORGE_RUN_HOST=1` marker, found no open SQLite, WAL or SHM database
  files, then stopped with zero exact-name LedgerForge processes and no
  task-owned `xcodebuild` process.

**Open boundary**

CI, generic UI smoke automation, commit-status protection, enabling or
replacing the disabled UI-test target, and distribution/notarization remain
open. Migration V9 and ADR-041 remain unchanged.

### Sprint 65 — Shared Axis Bank-Account PDF Production Path

**Ref**

This state update is the durable record for the Sprint 65 acceptance commit; the exact Git ref is authoritative in history and intentionally is not embedded here.

#### Outcome

Sprint 65 promotes one exact account-neutral Axis bank-account PDF grammar through the existing ordinary URL-driven import path. It does not establish generic Axis PDF, OCR, password, spreadsheet or cross-format-equivalence support.

#### Verified production behavior

- The existing security-scoped immutable `SourceContentSnapshot` is shared by PDF extraction, source-byte fingerprinting and confirmation integrity checks.
- The ordinary importer accepts PDF alongside CSV, dispatches PDF through the existing reader and exact Axis normalizer, then uses the shared detector, classifier, parser selector, validation, review, provider-owned confirmation and canonical hydration path.
- The PDF profile is `axis.bank-account.pdf@1`; the existing CSV profile remains `axis.bank-account.csv@2`. NRE/NRO labels do not select a profile or durable identity authority.
- PDF persistence uses `application/pdf`, makes `ledgerforge.source-bytes.sha256.v1` the single duplicate authority, retains `ledgerforge.raw-text.sha256.v1` only as a secondary fingerprint and records source size from the exact source bytes. CSV remains `text/csv` with raw-text duplicate authority and source bytes secondary.
- The coordinator and mapper fail closed for missing, multiple, unapproved or format-mismatched authorities. No PDF-only repository, provider, schema or migration path was added, and no cross-format duplicate suppression was introduced.
- The normalizer preserves page and row order, multiline particulars, printed references, branch evidence, declared period, opening/closing balances, printed totals and exact balance arithmetic; unsupported or contradictory evidence rejects before accepted persistence.

#### Source and fixture authority

- The two committed sanitized NRO PDFs were regenerated clean-room from the supplied read-only originals. Their independent expected JSON remained byte-identical; PDFKit, geometry, pagination, selectable-text, unlocked, privacy and `qpdf --check` gates passed; all four rendered pages were visually inspected.
- The original PDFs are the hard source-truth authority. The regenerated sanitized PDFs remain Git fixtures for deterministic grammar and privacy tests but are explicitly non-authoritative and unusable as original-source identity, as recorded in both manifests.
- Original NRO PDF persistence matched the independent row-level baselines: 16 and 20 ordered rows, with exact dates, debit/credit side, amount magnitudes, running balances, totals and closing balances. No production parser output was used to create either expected baseline.

#### Persistence authority matrix

| Source | Duplicate authority | Secondary fingerprint | Persisted media |
| --- | --- | --- | --- |
| CSV | `ledgerforge.raw-text.sha256.v1` | `ledgerforge.source-bytes.sha256.v1` | `text/csv` |
| PDF | `ledgerforge.source-bytes.sha256.v1` | `ledgerforge.raw-text.sha256.v1` | `application/pdf` |
| XLS | `ledgerforge.source-bytes.sha256.v1` | deterministic reader text projection | `application/vnd.ms-excel` |

#### Acceptance evidence

- Focused acceptance passed 381 tests across 43 suites; the complete TestPlan passed 607 tests across 73 suites. Both had zero failures, skips and expected failures; changed-file warnings were zero and analyzer diagnostics were zero. Nine remaining warnings were pre-existing Swift 6 transition warnings.
- Fresh signed Debug and optimized whole-module `-O` arm64 Release builds, Debug analysis and Release containment passed. Release products contained no PDFs, CSVs, fixtures, private originals, databases or copied source material.
- Four original PDF/CSV pairs were each exercised through separate fresh signed sandboxed app profiles, ordinary file-picker selection, explicit confirmation, quit/relaunch and hydration. Redacted pair outcomes are recorded above; matching projections were treated as financial equivalence evidence only, never exact-content identity.
- Task-owned namespaces, result bundles, render evidence and build products were moved recoverably to Trash after acceptance. The private originals remain read-only and unchanged. No private source value, path, filename, database, screenshot or raw diagnostic entered Git, documentation, result bundles or products.

#### Scope

Sprint 65 changed only the approved production, test, fixture/manifest and state-document paths: `ContentView.swift`, `Services/ImportEngine.swift`, `Services/ImportPersistenceMapper.swift`, `Services/ImportPersistenceCoordinator.swift`, `Parsers/AxisBankAccountParser.swift`, `Parsers/StatementParserRegistry.swift`, `Normalizers/AxisBankAccountPDFNormalizer.swift`, `Parsers/AxisBankAccountPDFParser.swift`, `Parsers/AxisBankAccountSourceEvidence.swift`, `LedgerForge.xcodeproj/project.pbxproj`, the focused `LedgerForgeTests` files, the two regenerated sanitized PDF fixtures and their manifests, `PROJECT_STATE.md` and `FUTURE_WORK.MD`. No ADR, DTO, repository protocol, schema or migration changed; V9 remains current.

### Sprint 66 — Typed Confirmed-Import Recovery and Truthful Validation Guidance

**Ref**

The single Sprint 66 completion commit containing this state update. Its exact SHA is Git-authoritative and recorded in the closure report.

#### Outcome

Sprint 66 implemented typed confirmed-persistence recovery and truthful validation guidance.

#### Verified production behavior

- Recovery eligibility is a closed typed contract. Localized error strings, filenames, paths and unrestricted errors are not recovery authority; unknown, malformed or hostile errors fail closed to unavailable.
- Eligible zero-commit outcomes may offer only wholly fresh preparation. Fresh preparation re-enters the ordinary retained-URL path, reacquires the source bytes, creates a new immutable snapshot and source-byte fingerprint evidence, and re-runs validation, exact-duplicate, identity, account-choice and provider-generation checks.
- Fresh preparation never reuses a consumed `PreparedImport`, reviewed partial plan, account choice or source snapshot, and never confirms automatically.
- Committed persistence followed by hydration failure offers canonical reconciliation only. Reconciliation refreshes the view without reimporting the statement or duplicating accepted history.
- A pre-existing reconciliation block is distinct from current committed persistence and explicitly records that the current attempt did not save a new import.
- Reconciliation-then-preparation starts wholly fresh preparation only after reconciliation succeeds. A failed reconciliation remains blocked, starts no preparation and does not retry recursively.
- Review-required and unavailable states expose no mutation action. A missing retained source URL suppresses Prepare Again even when the typed route otherwise permits fresh preparation.
- DBP-01 acknowledgement remains required before source acquisition in a non-current Debug profile.
- Process-local action ownership prevents duplicate dispatch, simultaneous preparation and reconciliation, and stale completion publication after a newer action begins.
- Exact-duplicate presentation remains “Previously Imported,” not persistence failure.

#### Persistence and financial boundary

- No schema or migration changed, and no repository or provider API changed.
- No rollback, compensation, resumable job, persisted job, batch queue, cancellation after committed persistence or generalized retry engine was introduced.
- Provider-owned atomic confirmation remains authoritative, and durable commit remains distinct from canonical hydration.
- Rejected zero-commit outcomes leave zero accepted financial residue. A committed hydration failure preserves the accepted commit.
- Reconciliation creates no duplicate account, transaction, session, document, fingerprint, identifier or observation.
- Historical durable guidance remains readable and was not rewritten.

#### Acceptance correction

The first canonical TestPlan run exposed one stale legacy duplicate-presentation test. The test-only correction supplied the typed exact-duplicate route to that previously imported regression case; no production code changed for the correction. The corrected stable implementation state then received the final authoritative acceptance run. This correction occurred before Sprint 66 acceptance and is part of Sprint 66, not Sprint 66A.

#### Acceptance evidence

- The focused four-suite run passed 49 logical tests across 49 executions, with zero parameter runs, failures, skips or expected failures.
- The corrected canonical TestPlan passed 562 logical tests across 607 execution instances and 68 suites, including 55 dynamic parameter runs across 10 parameterized tests, with zero failures, skips or expected failures.
- One fresh Debug build, one optimized whole-module `-O` arm64 Release build and Debug static analysis passed. Only pre-existing Swift 6 transition warnings in unrelated tests and the AppIntents metadata skip remained; no changed file produced a warning.
- Disposable runtime Scenario A verified a zero-commit contention outcome, ordinary-path Prepare Again, new prepared-import and snapshot identities, recomputed source-byte evidence, cleared account choice, explicit confirmation gating and single-dispatch behavior under double activation.
- Disposable runtime Scenario B verified that a committed hydration failure presented saved truth, offered reconciliation only and reconciled without a second preparation or persistence commit.
- Disposable runtime Scenario C verified that a pre-existing reconciliation block saved no current import, failed reconciliation began no preparation or loop, and successful reconciliation then created a wholly fresh preview requiring a new account choice and explicit confirmation.
- Disposable runtime Scenario D verified unavailable, exact-duplicate and missing-retained-URL outcomes with no unauthorized recovery mutation action. The exact duplicate left accepted financial counts unchanged and added only its bounded rejected attempt.
- Disposable runtime Scenario E verified the DBP-01 non-current-profile acknowledgement before source acquisition.
- Runtime SQLite evidence remained confined to the task-owned disposable root, the canonical Current Database was not opened or altered, and corrected automated coverage verified SQLite/In-Memory outcome parity and rejected-path zero accepted residue.
- Build acceptance and Release containment used the normal signed sandboxed products. The isolated interactive runtime walkthrough used a re-signed unsandboxed copy of the passed Debug build solely because sandboxed launch did not honor the task-private home. Executable code was unchanged, but the runtime entitlement environment differed; the walkthrough therefore verifies the accepted code paths under disposable isolation rather than production sandbox-entitlement behavior.
- Release inspection found no CSV, PDF, SQLite, database or fixture payload and no Debug acknowledgement machinery or private recovery material. Task-owned products were moved recoverably to Trash, no generated residue remained in the repository and no LedgerForge or `xcodebuild` process remained.

#### Scope

Sprint 66 changed exactly these implementation and test paths:

- `Services/ImportEngine.swift`
- `Services/ImportPersistenceCoordinator.swift`
- `ContentView.swift`
- `LedgerForgeTests/ImportLifecycleTests.swift`
- `LedgerForgeTests/ConfirmedImportHydrationTests.swift`
- `LedgerForgeTests/PersistenceAvailabilityTests.swift`
- `LedgerForgeTests/SettingsPresentationTests.swift`
- `LedgerForgeTests/ConfirmationGatedImportWorkflowTests.swift`

#### Exclusions

Sprint 66 did not implement retry confirmation, resume of a consumed preparation, rollback or compensation, persisted recovery jobs, batch importing, automatic confirmation, cancellation after committed persistence, generalized retry infrastructure, schema or migration changes, parser or import-format support, production PDF support, or Sprint 65.

### Sprint 67A — Authoritative Source-Document Binding

**Ref**

The single Sprint 67A corrective acceptance commit containing this state update. Its exact SHA is Git-authoritative and recorded in the closure report.

#### Outcome

Sprint 67A corrected Sprint 67's source-document presentation authority without changing the existing detail layout, financial values, schema or accepted architecture.

#### Verified production behavior

- `ImportSessionRepository.importedDocument(id:)` is the smallest read-only durable-document boundary. SQLite and In-Memory providers return one exact `ImportedDocumentDTO` by durable ID; a missing ID returns nil.
- `RepositoryStoreHydrator.stageHydration` deduplicates trusted transaction document references, reads each referenced document once and exposes a trimmed immutable runtime filename only when document ID, active workspace, transaction import-session ID and nonblank filename all agree.
- Nil references, missing rows, session mismatches, workspace mismatches and blank filenames leave the transaction readable and the source document neutral. A repository read error fails staged hydration before publication, preserving the previously published complete snapshot.
- `TransactionListViewModel` presents only the validated runtime document filename. Import time and validation still require one exact matching hydrated import session; `ImportSessionRecordDTO.userVisibleName` is never substituted as source-document authority.
- No repository lookup occurs in the ViewModel or SwiftUI view. Existing category, search, credit/debit toggle and reconciliation behavior is unchanged.

#### Acceptance evidence and boundary

- One fresh isolated Debug build passed. Focused runs passed 80 tests across 4 suites with zero failures, including provider parity, malformed and legacy document graphs, atomic read failure, privacy-safe presentation and SQLite close/reopen reconstruction with an intentionally different import-session label.
- The single canonical TestPlan run passed 622 tests across 73 suites with zero failures.
- The SwiftUI structure was unchanged, automated presentation evidence proved the displayed value and SQLite reconstruction proved the durable relationship, so the approved manual-runtime exemption applied.
- No migration or ADR was added; V9 and ADR-041 remain current. No source-document opening, browsing, library, source-byte retention, backfill or repair was added.

### Sprint 67 — Transaction Provenance and Clearer Detail

**Ref**

The single Sprint 67 acceptance commit containing this state update. Its exact SHA is Git-authoritative and recorded in the closure report.

#### Outcome

Sprint 67 added one repository-backed transaction-detail experience without changing financial semantics, persistence ownership or schema.

#### Verified production behavior

- `TransactionDTO.documentId` now survives ordinary hydration, forced hydration, provider reconstruction and relaunch as immutable runtime `repositoryDocumentId`; `RepositoryStoreHydrator` remains the sole persistence-to-runtime boundary.
- `TransactionListViewModel` owns one typed projection derived only from the hydrated transaction, its exact matching hydrated import session, Money and trusted statement-date authorities. Sprint 67A corrected the source-document field to use validated durable imported-document state rather than the session label.
- Account presentation requires the durable account relationship. After Sprint 67A, source-document presentation requires the exact durable imported-document relationship and a nonblank validated filename. Import time and validation fail closed independently when their matching session is malformed, unknown, missing or conflicting.
- The detail panel retains signed native-currency Money and manual category behavior while presenting bounded Transaction, Account and category, Import provenance and Validation sections. “Direction” and “Institution” replace developer-oriented or ambiguous terminology.
- Repository, normalized-document and normalized-row IDs, digests, raw parser-profile IDs, paths and source fragments are absent from visible and accessibility text. Historical or synthetic transactions without durable provenance remain readable and present neutral Unavailable states.

#### Authority and compatibility boundary

- Displayed amount and currency come from hydrated `Money`; direction comes from its hydrated debit/credit role; date and role come from `StatementDate` and `FinancialDateRole`; balance comes from hydrated running-balance Money.
- Account name and institution come from the hydrated transaction only when `repositoryAccountId` exists. Sprint 67A makes `ImportedDocumentDTO.filename` the sole source-document name authority; import time and validation continue to come from the exact hydrated `RepositoryImportSession`.
- No migration or ADR was added. V9 and ADR-041 remain current. No backfill, repair or durable source-byte presentation was performed.

#### Acceptance evidence

- One fresh Debug build passed.
- The final focused run passed 36 tests across 3 suites with zero failures. It covered document-ID mapping, forced hydration, legacy nil compatibility, atomic failure preservation, complete and unavailable detail projections, conflicting and unrelated sessions, malformed timestamps, unknown validation, internal-text exclusion, search/toggles, confirmed-import recovery and SQLite relaunch reconstruction.
- The single final canonical TestPlan run passed 616 tests across 73 suites with zero failures.
- Isolated runtime acceptance imported the approved sanitized Axis NRE fixture into one fresh namespaced SQLite database, verified the complete selected-transaction detail and accessibility truth, quit and relaunched, then verified the same hydrated provenance. Bounded SQLite inspection found 1 account, 4 transactions, 1 document and 1 session; all 4 transactions retained nonnull account, document and session relationships.
- The task-owned app process was stopped. The namespace, DerivedData and logs were moved recoverably to Trash. No private source, user database, generated result bundle or repository identifier entered Git or presentation.

#### Scope and exclusions

Sprint 67 changed the runtime transaction model, canonical hydrator, transaction-list presentation authority and view, focused hydration/presentation/relaunch tests, and this bounded state/queue reconciliation. It did not add source-document reopening, raw source retention, a document library, editable imported values, notes, tags, splits, provenance mutation, account relationship mutation, automatic categorization, new filters, analytics, dashboard work, diagnostics persistence, backup/restore, a migration or an ADR.

### DBP-01 — Developer Database Profiles (Debug Development Tooling)

**Ref**

`2d86f91dc46b9e88bcdfea65c88ddf671968b388`

**Verified scope**

DBP-01 is an accepted DEBUG-only developer-tooling and development-database lifecycle implementation. It provides Current Database, Persistent Debug Database, Temporary Session and Migration Sandbox with explicit lifecycle-owned activation; observer-atomic publication; lifecycle-activity blocking and stale-generation rejection; process-local Developer Mode that starts off on launch; an app-wide non-current warning; first-protected-action acknowledgement per non-current provider generation; and lifecycle-owned non-current reset and recreation. Current Database cannot be reset through profile controls.

All database-profile, warning, reset and acknowledgement machinery is absent from optimized Release. DBP-01 added no migration, changed no financial parser or durable financial semantics, established no production database-profile capability and did not declare personal-v1 adoption. Every current database remains disposable development/test state.

Integrated acceptance verified the complete TestPlan with 547 logical tests, 592 execution instances, 68 suites and 55 parameter runs, with zero failures, skips or expected failures. A fresh Debug build, Debug static analysis and isolated disposable runtime verification passed. No private financial source or personal database was used.

The final bounded Release-containment acceptance separately inspected seven authorized correction paths, passed 44 logical focused tests across 46 executions, passed an optimized whole-module `-O` arm64 Release build and passed direct binary `nm`, `strings` and bundled-resource inspection. No acknowledgement gate, Debug database-profile control, profile label, filename, namespace, sandbox control or fixture payload remained in Release. The complete TestPlan, static analysis and runtime walkthrough were not redundantly rerun after that final compile-boundary correction.

### Sprint 57 — Durable Categories and Manual Transaction Classification

**Ref**

The single Sprint 57 completion commit containing this state update.

**Verified scope**

Sprint 57 adds additive Migration V8 with workspace-owned category definitions and one separate optional category relationship for each trusted imported transaction. Categories have stable identifiers, validated names and archival state; Uncategorized is represented by no assignment.

SQLite and In-Memory repositories provide equivalent create, rename, archive, restore, delete-unused, assign, change and clear behavior. Deletion fails while a category is assigned. Archived categories preserve existing assignments but reject new ones. Provider-generation protection and the development repository-write lease cover persistence and forced canonical reconciliation.

`RepositoryStoreHydrator` reads categories and assignments with the trusted graph, rejects invalid names, duplicates, cross-workspace relationships and non-trusted transaction assignments before publication, then replaces one observer-consistent category snapshot. Provider reconstruction, SQLite close/reopen and V7-to-V8 upgrade verification preserve category metadata and leave existing imported financial/history truth unchanged.

Settings provides bounded category management. Transaction rows display the current category, and transaction detail provides assign, change and clear. The first category may be created before an import by establishing the default Personal workspace through the existing workspace repository.

An isolated namespaced Debug launch verified the empty Settings presentation, first-category creation and category survival after a full quit/relaunch. The task-owned process was terminated and the isolated database set was moved to Trash without opening or changing the protected canonical Debug database.

The post-Sprint 57 reconciliation closure adds no migration and preserves the immutable imported financial transaction boundary. Category reconciliation failure injection, blocked mutation zero-write behavior, retry, provider-generation replacement and target-wide category-state cleanup are covered by focused tests.

The closure also verified the normal isolated runtime path: Verified SQLite startup, category creation in Settings, sanitized statement import, transaction assignment, quit/relaunch hydration and persisted assignment presentation. No private source or protected canonical database was opened or changed.

No parser, reader, normalized-row, import-session, transaction financial value, balance, identifier or provenance behavior changed. The dated ADR-036 implementation amendment records the reconciliation closure; no migration was added.

### Sprint 57A — Category Reconciliation Closure

**Ref**

`251a547cb44712a789a9ad7b23a4eabca742900b`

**Verified scope**

Sprint 57A completed category reconciliation closure without a migration. Failure injection, blocked-mutation zero-write behavior, retry, provider-generation replacement and target-wide category-state cleanup preserve the immutable imported financial transaction boundary. The completion state is recorded as complete; no historical financial repair was performed.

### Sprint 58 — Deterministic Import Verification Workspace

**Ref**

`4547083d4d81edc9b6bcd98c3a8e77ee1538e71a`

**Verified scope**

Sprint 58 added a DEBUG-only approved-fixture verification workspace that enters the ordinary URL-driven preparation and confirmation path. Release containment removes the fixture resources and excludes the workspace from Release behavior. The isolated exact-duplicate runtime check preserved accepted transactions, sessions, documents, fingerprints, account state, balance and hydrated presentation, adding only one durable rejected duplicate attempt. Its later bounded build-system correction is recorded as Sprint 58A below.

### Sprint 58A — Debug Fixture Run-Script Sandbox Repair

**Verified scope**

Sprint 58A repaired the `Copy DEBUG approved fixtures` Run Script sandbox contract. The phase now validates and operates only on its two exact declared inputs and two exact declared outputs; directory-level recursive deletion was removed, and User Script Sandboxing remains enabled.

Two consecutive Debug builds using the same DerivedData passed with exactly the two approved fixture files present and matching their source SHA-256 values. Six focused Sprint 58 tests passed with zero failures or skips. Two consecutive optimized whole-module Release builds using the same DerivedData passed with no fixture file, fixture content or approved-fixture launcher payload present; Xcode's empty declared-output parent contained no payload. The canonical TestPlan passed 547 logical tests across 592 execution instances, 68 suites and 55 parameter runs with zero failures, skips or expected failures.

No source fixture, financial behavior, migration, DBP-01 behavior or production capability changed.

### Sprint 63 — Immutable Source Snapshot and Exact Source-Byte Fingerprint Implementation

**Ref**

`7e1345e3817d3c3e91c24f881b962a48279fd73b`

**Verified scope**

Sprint 63 implements the accepted Sprint 62 ADR-041 architecture contract. Preparation acquires one immutable app-owned `SourceContentSnapshot` containing the exact source bytes and `ledgerforge.source-bytes.sha256.v1` fingerprint. CSV retains `ledgerforge.raw-text.sha256.v1` as the duplicate authority and carries the source-byte fingerprint as a secondary fingerprint, with one authoritative fingerprint per document and SQLite/In-Memory Migration V9 provider/schema parity.

The retained snapshot is shared by extraction and fingerprinting, recomputed at confirmation, and consumed exactly once. Successful confirmation, rejection, failure, cancellation and preview supersession deterministically invalidate the snapshot. Acquisition and integrity failures produce bounded rejected outcomes, with no accepted financial residue. Historical source-byte reconstruction and durable source-byte storage are not performed. Production PDF support remains unsupported.

Independent acceptance verified 514 logical tests, 547 executions, 41 parameter runs across 8 tests, 64 suites, 0 failures and 0 skips; Debug, explicitly optimized whole-module Release and Debug analysis passed, with Release/privacy containment passing. No production PDF path was added.

### Sprint 62 — ADR-041 Immutable Source Snapshot Architecture Contract

**Verified scope**

Sprint 62 accepted ADR-041 as the architecture contract later implemented by Sprint 63. It selected `ledgerforge.source-bytes.sha256.v1`, retained `ledgerforge.raw-text.sha256.v1` for existing CSV history, required transient snapshot binding through confirmation and preserved the boundary against historical reconstruction, durable source-byte storage and production PDF support.

### Sprint 59 — Immutable Source Snapshot and Exact Source-Byte Fingerprint Authority

**Ref**

`b661472a58fc24144361322f1853b8001437a3eb`

**Verified scope**

Sprint 59 accepted ADR-041 as architecture only. `ledgerforge.source-bytes.sha256.v1` and one immutable app-owned `SourceContentSnapshot` are prospective requirements shared by extraction and fingerprinting through confirmation; neither is implemented. Existing `ledgerforge.raw-text.sha256.v1` history remains untouched, production PDF support remains unavailable, FW-P1-16 remains blocked and no migration was added.

### Sprint 56 — Explicit Reviewed Partial-Overlap Import

**Current alignment after Axis source-truth restoration:** Sprint 56's persistence schema, provider transaction, hydration and presentation structures remain implemented and readable, but its source-semantic acceptance is invalidated. The three-shared/one-later fixture is quarantined for missing immutable lineage, `axis.bank-account.csv@1` is historical only, and production now rejects mixed supported overlap until lineage-backed evidence authorizes a replacement boundary.

**Ref**

The single Sprint 56 completion commit containing this state update.

**Verified scope**

Sprint 56 accepts ADR-040 and adds additive Migration V7. The parser now owns a required immutable declared Axis statement period using `StatementDate`; the ordinary preview and partial review use that source period rather than transaction extrema.

One bounded prospective family may proceed after provider-backed read-only review: `axis.bank-account.csv@1`, bank-account, INR, one selected existing account, complete valid reconciliation, supported account-scoped Axis UPI evidence on every row, one contiguous recognized prefix and one later unique suffix. Immutable reviewed plans bind provider generation, account, exact fingerprint, profile, period, currency, balances, complete source rows, financial projections, event owners, dispositions and counts through `ledgerforge.partial-import-plan.sha256.v1`.

SQLite and In-Memory revalidate the complete plan atomically. Accepted partial sessions preserve the complete incoming document and normalized source graph, relate recognized incoming rows to unchanged durable transactions, create only unique-suffix transactions, and persist one summary, one disposition per row and one successful partial attempt with explicit counts. Stale, consumed, conflicting and losing paths write no accepted graph.

RepositoryStoreHydrator reconstructs partial summaries, attempt counts, dispositions and recognized source relationships before one observer-consistent store replacement. Missing, duplicate, unknown, cross-document, missing-event, missing-transaction, malformed period/money and count inconsistencies fail closed.

The Import Wizard, Dashboard activity, Import History, account history and Completed Imports presentation distinguish partial sessions. Review surfaces show only privacy-safe period, account, counts, balance evidence, unique impact and row dispositions.

The approved sanitized Sprint 55 fixture pair remains the independent oracle: Source A has four unique supported events; Source B has three recognized events plus one later-only event. Acceptance verifies five total transactions, two documents/sessions, four B dispositions, unchanged recognized transactions with new source relationships and exact-B duplicate resolution.

No canonical app launch or ordinary Debug/Release container access is part of Sprint 56 acceptance. The protected V5 Debug database remains unresolved local-only recovery evidence.

### Sprint 55 — Axis Source-Direction Correction and Partial-Overlap Evidence Closure

**Current alignment after Axis source-truth restoration:** Sprint 55's physical-role naming and dynamic header-position resolution remain useful, but its financial direction conclusion and fixture/oracle acceptance are invalidated. The historical bullets below record what Sprint 55 claimed; current source evidence establishes conventional DR-debit/CR-credit semantics under `axis.bank-account.csv@2`.

Commit:

```text
The single Sprint 55 completion commit containing this state update.
Its exact SHA is Git-authoritative and recorded in the completion report.
```

Sprint 55:

- separated dynamically resolved physical Axis DR/CR source columns from canonical debit/credit roles;
- restored the verified `axis.bank-account.csv@1` contract: physical DR becomes canonical credit with positive `Money`, and physical CR becomes canonical debit with negative `Money`;
- retained the existing parser profile ID/version because this is a source-truth defect correction rather than a new accepted layout;
- corrected sanitised Axis fixture occupancy only where independent running-balance arithmetic established the source semantics, without changing canonical expected financial truth;
- added a privacy-safe derivative of two genuine Axis statements with an independently verified three-shared/one-later-only supported UPI overlap;
- added an expected oracle that does not call production parsing, direction resolution or event-identity code;
- verified posting versus credit-adjustment subtype direction after canonical resolution;
- proved conventional or mixed future semantics fail validation without profile switching, accepted persistence or runtime financial-store residue;
- closed the Axis direction blocker and `BLOCK-PARTIAL-ORACLE-01`;
- passed 41 focused tests across 5 suites, 64 adjacent tests across 6 suites and the canonical 407-test, 49-suite TestPlan;
- passed Debug and explicit `-O` whole-module Release builds.

Migration V6, ADR-039, schema architecture, partial-overlap persistence, review UI and durable partial-import outcomes remain unchanged.

### Sprint 54 — Durable Import-Outcome Presentation Exhaustiveness

Commit:

```text
The single Sprint 54 completion commit containing this state update.
Its exact SHA is Git-authoritative and recorded in the completion report.
```

Sprint 54:

- introduced one typed presentation authority for durable import-attempt outcome, coverage and guidance;
- explicitly presents all 13 known outcomes, both coverage codes and all 8 guidance codes;
- routes Dashboard Import Activity and Import History list/detail through the same bounded semantics;
- removed the separate partial history switch and raw underscore-to-space formatting;
- uses the same bounded outcome text for affected Import History accessibility presentation;
- returns neutral outcome, coverage and guidance labels for unknown, malformed or future codes without reflecting hostile raw values;
- preserves successful transaction-count presentation, current-workflow precedence, valid timestamp ordering, stable equal-timestamp ID tie-breaking and malformed-timestamp behavior;
- passed 18 focused presentation tests across 1 suite and 86 related tests across 7 suites;
- passed the canonical 400-test, 48-suite TestPlan with 0 failures and 0 unexpected skips;
- passed fresh clean Debug and explicit `-O` whole-module Release builds plus Debug and Release static analysis with zero errors or analyzer findings;
- could not perform representative runtime presentation verification because no deterministic approved fixture launcher or injection route exists, and added no infrastructure to bypass that boundary.

Schema, Migration V6, ADR-039, durable raw codes, repository/provider behavior and hydration semantics remain unchanged.

### Sprint 53 — Axis Shared Bank-Account CSV Profile and NRO Identity Closure

Commit:

```text
11035461ce3de0f11ae5262bbc8a38b9639607b2
```

Sprint 53:

- extended the existing Axis bank-account CSV grammar to the supplied NRO evidence;
- retained one production `AxisBankAccountParser`;
- introduced the neutral forward profile `axis.bank-account.csv@1`;
- required exactly one parser-produced profile ID/version pair;
- rejected missing, malformed or conflicting profile provenance before writes;
- preserved historical `axis.nre.csv@1` rows without rewriting;
- reconstructed two sanitized NRO CSV preambles and periods to the shared grammar without claiming byte-for-byte private-source recovery;
- verified independent financial and identity truth;
- verified separate NRE and NRO durable accounts;
- verified exact duplicate and supported overlap behavior;
- verified provider reconstruction, hydration and relaunch;
- completed the 394-test canonical TestPlan;
- passed fresh Debug and optimized Release builds and analysis;
- completed disposable namespaced runtime verification with two accounts, 118 transactions and zero remaining LedgerForge processes.

No migration or ADR changed.

### Sprint 52A — Trusted Hydration and Writer Boundary Closure

Sprint 52A:

- made malformed trusted date-role, timezone, provenance and profile evidence fail hydration before runtime mutation;
- required providers to return actual durable profile ID/version;
- prohibited trusted profile defaults or reconstruction;
- rejected trusted DTOs through generic replacement;
- validated complete normalized source relationships inside confirmed import;
- verified provider-equivalent atomic rejection and zero accepted residue.

V6 remained unchanged.

### Sprint 52 — Trusted Statement Dates and Durable Source Provenance

Sprint 52 implemented ADR-039 and Migration V6.

It introduced:

- strict date-only transaction evidence;
- canonical date-only persistence and hydration;
- document-scoped source ordinal;
- normalized-record digest;
- parser-profile provenance;
- provider-atomic transaction/provenance persistence;
- fail-closed treatment of nonempty V5 financial graphs.

No historical evidence was reconstructed.

### Sprint 51 — Fail-Closed Recognized Axis Evidence

Sprint 51:

- rejected malformed recognized Axis transaction dates;
- rejected malformed, unconstructable or conflicting structured account evidence inside `StatementParser`;
- stopped both failure families before preparation, duplicate lookup, identity review, confirmation or persistence;
- preserved supported valid rows and zero-value behavior.

No migration or ADR changed. No Developer Console filename-redaction behavior was integrated.

### Sprint 50 — Provider-Owned Atomic Confirmed Import

Sprint 50:

- activated Migration V5;
- moved accepted confirmation to the provider-owned atomic path;
- enforced durable identifier ownership;
- recorded accepted-import identifier observations;
- bound prepared imports to provider generation;
- removed the legacy accepted-write authority;
- established provider-equivalent contention outcomes and zero losing-path residue;
- retained canonical post-commit hydration and reconciliation gating.

### Earlier verified foundations

The active repository also includes:

- Sprint 39 exact-content duplicate prevention;
- Sprint 40 approved overlap evidence;
- Sprint 41 bounded Axis UPI event ownership and Migration V3;
- Sprint 42 durable attempt history and Migration V4;
- Sprint 43 truthful preparation stages, cancellation and bounded source-reading retry;
- Sprint 44 Money and grouped native-currency presentation;
- Sprint 45 recoverable Debug database lifecycle;
- Sprint 46 non-destructive workspace/account conflict updates;
- Sprint 47 fail-closed startup and migration-chain verification;
- Sprint 48 truthful Settings cleanup;
- the completed `FW-P0-23` financial-presentation and provenance repair boundary;
- ADR-044 durable card-liability/instrument architecture and exact Amex/CBQ PDF support.

Detailed implementation history remains in Git and accepted ADRs.

---

## Current Planning State — 2026-08-27

- Sprint 78B is the highest-numbered **accepted** implementation, with amended ADR-044/ADR-015 and Migration V15 as the accepted architecture/migration baseline.
- Sprint 78 and Sprint 78A failed; Sprint 78B completed the Sprint 78 outcome and no Sprint 78C exists.
- The exact accepted Axis source, ownership, credential, V15 and acceptance boundaries are recorded in the `Current Alignment — 2026-08-27` section above and in `LedgerForge_Roadmap_Sprints_70-79_Current.md`.
- Exact Axis card PDF/XLSX production support is accepted only for the Sprint 78B profiles and source-proven boundaries; broader Axis/card/XLSX claims remain unsupported.
- Sprint 79 architecture is approved but remains unimplemented and requires the complete Chat-approved execution prompt.
- `FUTURE_WORK.MD` remains the canonical queue for work that is not currently selected for execution. It is not the active-sprint authority.

---

## Planning Boundary

- `PROJECT_STATE.md` records accepted repository reality plus explicitly labelled active unaccepted WIP.
- `LedgerForge_Roadmap_Sprints_70-79_Current.md` is the repository planning authority for the current cycle's sprint numbering, corrective suffixes, status and next gates.
- `LedgerForge_Standing_Execution_Harness_Guide.md` is the repository standing execution/review-method authority.
- `FUTURE_WORK.MD` is the canonical unscheduled planning queue.
- Accepted ADRs govern accepted architecture; ADR-045 now governs the approved but unimplemented Sprint 79 salary/planning boundary, while the Sprint 78B ADR-015 and ADR-044 amendments remain accepted implemented state.
- The complete Chat-approved prompt is the execution contract for the current task.
- Chat owns sprint/architecture/acceptance decisions. MCP executor provides guarded local Mac repository/Xcode access inside Chat. Codex is a separate execution environment and must receive a self-contained prompt plus repository-local authorities.
- Before any write, exact branch/HEAD/divergence, worktree/index state, branches/worktrees/stashes, active Git operations, validations, MCP lease and independent external writers must be verified.
