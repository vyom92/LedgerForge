# Repository State

## Repository Baseline

- **Primary branch:** `main`
- **Current repository implementation baseline:** Sprint 73 and Sprint 73A are accepted at main@31d493e421869d6a825aa2db576f82c2be3bdb68
- **Documentation alignment:** Reconciled for the Sprint 73 implementation and acceptance boundary
- **Accepted source-truth repair:** P0 Axis bank-account source-truth restoration and Sprint 65's clean-room PDF fixture replacement are included in the accepted baseline; no historical financial data was altered
- **Latest chronologically accepted production implementation:** Sprint 73 exact HDFC PDF v1 and whole-statement HDFC PDF/XLS equivalence
- **Latest verified Debug development-tooling implementation:** DBP-01 Developer Database Profiles at `2d86f91dc46b9e88bcdfea65c88ddf671968b388`
- **Non-implementation commits after Sprint 53:**
  - `bdb51b0ddcdde097e456a16bab7f0bf999fd595b` — roadmap update
  - `7ee20a909038d1088f830a6ea588311625f415e5` — planning reconciliation and tracked Xcode user-data removal
  - `de238d8abf5ee7dc7d1eb9cd13fab72803f2be28` — roadmap update after the discovery campaign
  - `a64c2d8d67e93631d8b0c32620ded72f389f252f`, `98b1fef111087d3b8c2b26f8c354c2147c6b2412` and `f50127ccb7ddf05641df1af7a14a93be2ea8b42e` — subsequent roadmap updates
- **Latest verified completed numbered increment:** Sprint 73 — Exact HDFC PDF v1 and Whole-Statement Cross-Format Equivalence
- **Accepted Sprint 63 implementation ref:** `7e1345e3817d3c3e91c24f881b962a48279fd73b`
- **Latest accepted ADR:** ADR-042 — Exact Cross-Format Statement Equivalence and Supporting-Source Persistence
- **Current migration:** V10
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
- **Current exclusions:** unsupported institutions, profiles, currencies, event families, mixed or interleaved overlap, arbitrary omission, fuzzy candidates, ownership override and historical repair remain unavailable
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

Production import support is limited to the verified shared Axis bank-account CSV grammar and the exact selected Axis bank-account PDF grammar represented by:

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
whole-statement equivalence. No broader Axis PDF/XLS layout, OCR,
password-protected statement, historical Axis layout, XLSX, card, HDFC
CSV/XLSX, changed or generic HDFC layout, CBQ, American Express or other
institution support is claimed.

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

The active chain ends at V10. Migration V7 adds explicit partial-attempt counts, durable partial-import summaries and one typed incoming-row disposition per normalized source row for ADR-040. Additive Migration V8 adds workspace-owned categories and a separate restrictive current transaction-category assignment relationship without changing imported financial rows or provenance. Migration V9 adds versioned document-fingerprint authority and the source-byte fingerprint relationship without storing source bytes. Additive Migration V10 adds exact statement projections, ordered projection events, equivalence groups and authoritative/supporting members without backfilling existing history.

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

Category definitions and transaction assignments are read with the trusted financial graph, validated before publication and published as one category snapshot. Category mutations reconcile through the same canonical hydrator; runtime category state is not durable authority. A committed mutation whose hydration fails preserves durable repository truth, leaves the last complete runtime snapshot unchanged, blocks later category mutations with a distinct reconciliation-required result, and provides an explicit canonical hydration retry. Provider replacement and lifecycle transitions clear stale prior-generation category state only after replacement hydration succeeds.

### Durable categories and manual classification

Sprint 57 provides user-created workspace categories with stable identifiers, deterministic normalized-name uniqueness and archival state.

Settings supports create, rename, archive, restore and deletion only when unused. Transaction detail supports one manual category assignment, change or clear for a persisted trusted transaction. Archived categories retain existing assignments but cannot receive new ones.

The assignment is stored in a separate relationship. Changing it does not update transaction amounts, dates, balances, identifiers, normalized rows, import sessions, provenance or parser output. SQLite and In-Memory providers enforce equivalent behavior, and deletion remains restrictive while a category is assigned.

Automatic categorization, rules, suggestions, bulk assignment, merge, delete-with-replacement, hierarchy, tags, splits, filters, budgeting, analytics and reports remain future work.

### Financial identity

Parser-owned verified identity resolution supports the approved Axis bank-account path.

Distinct parser-produced full institution account identifiers retain distinct durable accounts. Shared customer context, profile identity, filenames and neutral presentation labels are not account-identity authority.

The supported workflow provides:

- verified existing-account resolution;
- explicit eligible existing-account choice for bounded no-match cases;
- explicit new-account creation;
- transaction-time identifier ownership enforcement;
- durable accepted-import identifier observations.

Identifier unlinking, reassignment, incorrect-link recovery, contradictory-ownership repair and historical backfill remain separately gated.

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

Supported event overlap is currently whole-statement blocked. Ordinary no-overlap statements remain full imports and exact-content duplicates remain ADR-030 outcomes. The former ADR-040 mixed-overlap exception is suspended because its synthetic three-shared/one-later fixture has no immutable source lineage; both providers return unsupported evidence without accepted residue for that shape.

Migration V7, immutable reviewed plans, SQLite/In-Memory commit paths, durable partial summaries and dispositions, strict hydration and bounded UI presentation remain capable of reading and validating historical repository state. They do not authorize a new partial import until immutable source evidence proves a bounded family again. Interleaved overlap, unsupported event families, arbitrary omission, fuzzy matching and historical repair remain unavailable.

Unsupported event families remain unevaluated, including:

- IMPS;
- NEFT;
- e-commerce and card events;
- refunds;
- reversals;
- unstructured references.

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

- Production parser support is limited to the approved Axis bank-account CSV grammar and the selected exact Axis bank-account PDF grammar.
- General Axis NRO coverage and additional Axis layouts remain unsupported.
- Other Axis PDF layouts, OCR, password-protected PDFs and generic PDF statement support remain unsupported.
- XLS, XLSX, TXT and OCR are not production-supported.
- HDFC, CBQ, American Express and card-statement production parsing are unsupported.
- No production password-entry or Keychain workflow exists.
- No QAR parser or production QAR import path exists.

### Card limits

ADR-034 accepts a document-scoped card-statement evidence boundary subordinate to ADR-033.

The following remain unimplemented:

- concrete card validation;
- durable card persistence;
- card hydration;
- card migration;
- production card parsing;
- institution-specific card support.

Fixture integration, statement classification, schema capacity or parser candidates do not establish production card support.

### Currency limits

ADR-033 and Sprint 44 provide:

- a compiled currency catalog;
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

Clean-room CBQ current-account PDF evidence is integrated for April, May and June 2026.

The periods are:

- contiguous;
- non-overlapping;
- balance-continuous.

They contain 10, 7 and 9 canonical transactions.

The PDFs retain selectable text and preserve declared pagination, dimensions, repeated-header and multiline relationships.

CBQ current-account production parsing remains unsupported.

### CBQ card evidence

Clean-room CBQ credit-card PDF evidence is integrated for four consecutive periods across:

- v1 legacy layout;
- v2 equation-style layout.

The evidence preserves:

- one fictional customer and account;
- primary and supplementary instrument relationships;
- exact transaction assignment;
- posted QAR distinct from original merchant amount and currency;
- explicit source-observed fees;
- no invented FX rates, markup, taxes or absent aggregates.

CBQ card production parsing and durable card semantics remain unsupported.

### American Express card evidence

Clean-room American Express card PDF evidence is integrated for two contiguous periods from 24 April 2026 through 23 June 2026.

The periods contain 61 and 34 canonical transactions.

The evidence preserves:

- one fictional customer, account and instrument;
- account-level payments distinct from instrument transactions;
- posted QAR separate from original merchant amount and currency;
- source rewards, legal, pagination, geometry and multiline relationships;
- no invented FX rates, fees, markup or tax.

American Express production parsing and durable card semantics remain unsupported.

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
- ADR-034 card-statement evidence architecture.

Detailed implementation history remains in Git and accepted ADRs.

---

## Current Planning State

- The current planning alignment is based on completed Sprints 50–73, including the Sprint 68B test-only correction, the DBP-01 maintenance correction, the Sprint 69 local validation closure, the bounded Sprint 71 and Sprint 72 XLS increments and Sprint 73 exact HDFC PDF/XLS equivalence, together with Migration V10 and accepted ADR-042.
- DBP-01 is complete and no DBP-01 implementation remains pending. It is a separate post-Sprint-64 Debug tooling increment, not a numbered sprint or Sprint 65; no sprint renumbering occurred.
- Sprint 63 implementation of the ADR-041 source-snapshot and source-byte foundation is complete; no source-snapshot implementation remains in the unscheduled queue.
- `FW-P1-10 — Production PDF Statement Support` is completed and removed from the unscheduled queue by Sprint 65 for the selected exact account-neutral Axis bank-account grammar. Other Axis PDF layouts, OCR, password workflow, generic Axis PDF support and cross-format equivalence remain unsupported.
- `FW-P1-14 — XLS and XLSX Support` is partially completed for the exact Axis NRO XLS v1 profile delivered by Sprint 71 and the exact shared HDFC NRE/NRO legacy-XLS v1 profile delivered by Sprint 72. XLSX, generic spreadsheets, other institutions and other layouts remain unscheduled.
- `FW-P1-16` is partially completed only for the exact HDFC PDF/XLS v1 pair under ADR-042. Axis PDF/CSV/XLS, CBQ, cards, same-format semantic duplicates, partial overlap and every other cross-format relationship remain future work.
- `FW-P1-40 — Deterministic Approved-Fixture Launcher` was completed by Sprint 58 and is removed from the unscheduled queue.
- `FW-P1-37` retains only broader structured diagnostics work not completed by Sprint 58; its bounded privacy-safe preparation-failure summary and Developer Console fixture-workflow slice is complete.
- `FW-P1-28 — Confirmed-Persistence Recovery and Unsupported Retry` is complete in Sprint 66 and removed from the unscheduled queue.
- `FW-P1-29 — Better Validation Guidance` retains only broader validation education outside the typed immediate-result and recovery guidance completed by Sprint 66.
- The exact retained HDFC PDF v1 slice is complete. Fixture-backed CBQ, HDFC card and other card families remain eligible for targeted discovery but are not production support; the separately planned CBQ partial-overlap work for Sprints 74–75 remains future work.
- `FW-P2-20 — Category Model and Management` is complete in Sprint 57 and removed from the unscheduled queue.
- `FW-P2-21 — Deterministic Categorization Rules` is now eligible for bounded discovery; no rule behavior is implemented or authorized.
- Repair and reversal families whose shared ADR-037 and lifecycle prerequisites are complete are eligible for targeted family-specific discovery, not broad implementation.
- `FW-P0-24 — Durable Import-Outcome Presentation Exhaustiveness` is complete and no longer remains in the unscheduled queue.
- Sprint 73 is the highest-numbered completed increment. The selected Axis PDF, exact Axis NRO XLS and exact shared HDFC NRE/NRO PDF/XLS boundaries are accepted, while broader PDF/XLS layouts, XLSX, OCR, password workflow, generic spreadsheet support and cross-format equivalence beyond the exact HDFC pair remain unscheduled or blocked.

---

## Planning Boundary

- `PROJECT_STATE.md` records verified repository reality.
- `FUTURE_WORK.MD` is the canonical unscheduled planning queue.
- Accepted ADRs govern architecture.
- The private sprint roadmap is a non-authoritative Chat-user planning aid.
- No repository-stored active work contract exists.
- The complete Chat-approved prompt supplied directly in the current conversation is the sole execution contract.
- Before Codex execution, local branch, HEAD, divergence, worktree, branch, stash and linked-worktree safeguards must be verified.
