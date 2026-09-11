# Accepted outcomes — Sprints 70-79

Historical collection, not current implementation or execution authority. [Current state](../../PROJECT_STATE.md) owns the snapshot. Ordering inherits [Guide rule F](../../Project_Guide.md#documentation-order): known acceptance dates descending, then recorded sequence or natural sprint ID descending as display order. Undated records follow; original evidence interiors are unchanged. A review/observation date is not assigned as an acceptance date. Repeated historical summaries preserve their own limitations and may describe superseded support, fixture policy or migration state. ADR-046 and current scope decisions control all new work.

For repeated records of one outcome, the original state record precedes roadmap detail, then snapshot excerpts in their original source sequence. This is a display tie-break, not a second acceptance chronology. Cross-cycle compiled snapshots and unnumbered records without one acceptance date are separate historical context, ordered by stable record key under Guide rule I. Their placement does not attribute every contained fact to this cycle.

## Index

### Acceptance records

- [Sprint 77 exact profile and model correction](#baseline-sprint-77-63) — Acceptance date not recorded; historical evidence
- [Sprint 77 reconciliation and persistence](#baseline-sprint-77-64) — Acceptance date not recorded; historical evidence
- [Sprint 77 password boundary](#baseline-sprint-77-65) — Acceptance date not recorded; historical evidence
- [Sprint 77 private-source acceptance](#baseline-sprint-77-66) — Acceptance date not recorded; historical evidence
- [Sprint 77 focused and cycle-close acceptance](#baseline-sprint-77-67) — Acceptance date not recorded; historical evidence
- [Sprint 76A multi-instrument correction](#baseline-sprint-76a-57) — Acceptance date not recorded; historical evidence
- [Sprint 76A encrypted PDF and credential boundary](#baseline-sprint-76a-58) — Acceptance date not recorded; historical evidence
- [Sprint 76A currency authority](#baseline-sprint-76a-59) — Acceptance date not recorded; historical evidence
- [Sprint 76A persistence and semantic sources](#baseline-sprint-76a-60) — Acceptance date not recorded; historical evidence
- [Sprint 76A exact Amex and private-source acceptance](#baseline-sprint-76a-61) — Acceptance date not recorded; historical evidence
- [Sprint 76A cycle-close acceptance](#baseline-sprint-76a-62) — Acceptance date not recorded; historical evidence
- [Sprint 76 profile and source semantics](#baseline-sprint-76-50) — Acceptance date not recorded; historical evidence
- [Sprint 76 shared card domain](#baseline-sprint-76-51) — Acceptance date not recorded; historical evidence
- [Sprint 76 persistence and hydration](#baseline-sprint-76-52) — Acceptance date not recorded; historical evidence
- [Sprint 76 private-source acceptance](#baseline-sprint-76-53) — Acceptance date not recorded; historical evidence
- [Sprint 76 lifecycle falsification](#baseline-sprint-76-54) — Acceptance date not recorded; historical evidence
- [Sprint 76 focused acceptance](#baseline-sprint-76-55) — Acceptance date not recorded; historical evidence
- [Sprint 76 cycle-close acceptance](#baseline-sprint-76-56) — Acceptance date not recorded; historical evidence
- [Sprint 75](#baseline-sprint-75-43) — Acceptance date not recorded; historical evidence
- [Sprint 75 account identity](#baseline-sprint-75-44) — Acceptance date not recorded; historical evidence
- [Sprint 75 source lineage](#baseline-sprint-75-45) — Acceptance date not recorded; historical evidence
- [Sprint 75 persistence](#baseline-sprint-75-46) — Acceptance date not recorded; historical evidence
- [Sprint 75 private-source acceptance](#baseline-sprint-75-47) — Acceptance date not recorded; historical evidence
- [Sprint 75 focused acceptance](#baseline-sprint-75-48) — Acceptance date not recorded; historical evidence
- [Sprint 75 cycle-close acceptance](#baseline-sprint-75-49) — Acceptance date not recorded; historical evidence
- [Sprint 74](#baseline-sprint-74-38) — Acceptance date not recorded; historical evidence
- [Sprint 74 identity and source boundary](#baseline-sprint-74-39) — Acceptance date not recorded; historical evidence
- [Sprint 74 private-source acceptance](#baseline-sprint-74-40) — Acceptance date not recorded; historical evidence
- [Sprint 74 focused acceptance](#baseline-sprint-74-41) — Acceptance date not recorded; historical evidence
- [Sprint 74 cycle-close acceptance](#baseline-sprint-74-42) — Acceptance date not recorded; historical evidence
- [Sprint 73A test-only closure](#baseline-sprint-73a-37) — Acceptance date not recorded; historical evidence
- [Sprint 73](#baseline-sprint-73-36) — Acceptance date not recorded; historical evidence
- [Sprint 73 implementation boundary](#baseline-sprint-73-114) — Acceptance date not recorded; historical evidence
- [Sprint 73 provider behavior](#baseline-sprint-73-115) — Acceptance date not recorded; historical evidence
- [Sprint 73 migration and ADR impact](#baseline-sprint-73-116) — Acceptance date not recorded; historical evidence
- [Sprint 73 private-source acceptance](#baseline-sprint-73-117) — Acceptance date not recorded; historical evidence
- [Sprint 73 focused verification](#baseline-sprint-73-118) — Acceptance date not recorded; historical evidence
- [Sprint 73 runtime verification](#baseline-sprint-73-119) — Acceptance date not recorded; historical evidence
- [Sprint 73 exact exclusions](#baseline-sprint-73-120) — Acceptance date not recorded; historical evidence
- [Sprint 72](#baseline-sprint-72-35) — Acceptance date not recorded; historical evidence
- [Sprint 72 source semantics](#baseline-sprint-72-68) — Acceptance date not recorded; historical evidence
- [Sprint 72 identity and fail-closed boundary](#baseline-sprint-72-69) — Acceptance date not recorded; historical evidence
- [Sprint 72 private-source acceptance](#baseline-sprint-72-70) — Acceptance date not recorded; historical evidence
- [Sprint 72 acceptance evidence](#baseline-sprint-72-112) — Acceptance date not recorded; historical evidence
- [Sprint 72 migration and ADR impact](#baseline-sprint-72-113) — Acceptance date not recorded; historical evidence
- [Sprint 71](#baseline-sprint-71-31) — Acceptance date not recorded; historical evidence
- [Sprint 71 third-party boundary](#baseline-sprint-71-32) — Acceptance date not recorded; historical evidence
- [Sprint 71 source truth](#baseline-sprint-71-33) — Acceptance date not recorded; historical evidence
- [Sprint 71 fail-closed boundary](#baseline-sprint-71-34) — Acceptance date not recorded; historical evidence
- [Sprint 71 acceptance evidence](#baseline-sprint-71-110) — Acceptance date not recorded; historical evidence
- [Sprint 71 Release boundary](#baseline-sprint-71-111) — Acceptance date not recorded; historical evidence

### Historical context with no single acceptance date

- [Historical alignment recorded 2026-08-28](#historical-alignment-2026-08-28) — Mixed snapshot; Sprint 78B accepted 2026-08-27; Sprint 79 acceptance date not recorded. The 2026-08-28 heading is a review date.
- [Current repository implementation baseline](#historical-baseline-1) — No single acceptance date assigned; original historical context
- [Latest chronologically accepted production implementation](#historical-baseline-4) — No single acceptance date assigned; original historical context
- [Latest verified Debug development-tooling implementation](#historical-baseline-5) — No single acceptance date assigned; original historical context
- [Latest verified completed numbered increment](#historical-baseline-7) — No single acceptance date assigned; original historical context
- [Latest accepted ADR](#historical-baseline-9) — No single acceptance date assigned; original historical context
- [Latest verified repository-maintenance change](#historical-baseline-76) — No single acceptance date assigned; original historical context
- [Latest verified implementation-adjacent maintenance repair](#historical-baseline-77) — No single acceptance date assigned; original historical context
- [Current overlap boundary](#historical-baseline-78) — No single acceptance date assigned; original historical context
- [Current exclusions](#historical-baseline-83) — No single acceptance date assigned; original historical context
- [Latest Sprint 65 focused result](#historical-baseline-89) — No single acceptance date assigned; original historical context
- [Latest Sprint 65 complete-TestPlan result](#historical-baseline-90) — No single acceptance date assigned; original historical context
- [Latest Sprint 67 focused result](#historical-baseline-91) — No single acceptance date assigned; original historical context
- [Latest Sprint 67 complete-TestPlan result](#historical-baseline-92) — No single acceptance date assigned; original historical context
- [Latest Sprint 67A focused result](#historical-baseline-94) — No single acceptance date assigned; original historical context
- [Latest Sprint 67A complete-TestPlan result](#historical-baseline-95) — No single acceptance date assigned; original historical context
- [Latest Sprint 68 focused result](#historical-baseline-96) — No single acceptance date assigned; original historical context
- [Latest Sprint 68A focused result](#historical-baseline-99) — No single acceptance date assigned; original historical context
- [Latest Axis source-truth automated result](#historical-baseline-103) — No single acceptance date assigned; original historical context
- [Latest Axis source-truth focused result](#historical-baseline-104) — No single acceptance date assigned; original historical context
- [Latest Axis source-truth build result](#historical-baseline-105) — No single acceptance date assigned; original historical context
- [Latest reported local automated result](#historical-baseline-107) — No single acceptance date assigned; original historical context
- [Latest focused category-reconciliation result](#historical-baseline-108) — No single acceptance date assigned; original historical context
- [Latest reported local build result](#historical-baseline-109) — No single acceptance date assigned; original historical context
- [Previous Sprint 55 automated result](#historical-baseline-122) — No single acceptance date assigned; original historical context
- [Generic UI-test state](#historical-baseline-127) — No single acceptance date assigned; original historical context
- [Cross-cycle historical capability and limitation snapshot](#historical-capabilities-and-limitations) — No single acceptance date assigned; original historical context

---

<a id="baseline-sprint-77-63"></a>

- **Sprint 77 exact profile and model correction:** Added exact encrypted native-text `cbq.credit-card.pdf@1` with deterministic internal v1/v2 layout provenance. Financial account/instrument scope is now independent from optional physical source-section membership, so an account-level payment may contribute to its printed section subtotal without acquiring an instrument. Typed CBQ Card Account Reference and masked companion-instrument observations remain source evidence, not strong identity. CBQ current-account detection and ADR-043 lineage remain separate.

---

<a id="baseline-sprint-77-64"></a>

- **Sprint 77 reconciliation and persistence:** Card validation now selects exact Amex, CBQ v1 or CBQ v2 summary and section contracts through typed profile evidence. Additive Migration V14 leaves V1–V13 immutable, generalizes the four constrained card evidence tables, adds printed-summary membership and preserves existing V13 Amex graphs without semantic backfill. SQLite and In-Memory confirmation, exact-byte duplicate rejection, newest-source-date balance authority, close/reopen and canonical hydration preserve the same two-instrument shared-card graph; no CBQ-specific card domain was created.

---

<a id="baseline-sprint-77-65"></a>

- **Sprint 77 password boundary:** ADR-015's institution-scoped Keychain-backed PDF credential infrastructure is now a production dependency of exact Amex and exact CBQ card profiles. Remembered reuse, failed remembered-candidate replacement and save-after-authoritative-profile validation are verified. This establishes neither generic encrypted-PDF support nor password proof for unrelated Axis, HDFC, CBQ bank, investment or other layouts.

---

<a id="baseline-sprint-77-66"></a>

- **Sprint 77 private-source acceptance:** Eight approved three-page encrypted CBQ originals, split four v1/four v2, contain 15, 19, 28, 14, 11, 18, 12 and 16 financial rows, 133 total. The independent oracle produced 8/8 statement reconciliations, 6/6 valid supplied adjacent continuities, no fabricated May-to-July continuity, and zero row, section or statement-summary mismatches. Chronological, reverse and mixed campaigns in SQLite and In-Memory each ended with one liability account, two companion instruments, eight statements and 133 canonical transactions; exact duplicate rejection, SQLite reopen and hydration preserved the graph. No private value, identifier, path, filename, password, transaction listing or decrypted artifact was published in repository documentation.

---

<a id="baseline-sprint-77-67"></a>

- **Sprint 77 focused and cycle-close acceptance:** The final adjacent card, CBQ-bank, migration, password, confirmation and hydration boundary passed 131 tests with 156 parameterized executions and zero failures or skips. The authoritative replacement cycle-close passed fresh Debug and optimized Release builds plus the complete TestPlan with 733 tests across 90 suites, zero failures and zero skips. The earlier 730-test cycle preceded the audit-driven exact tail, ambiguity, source-page oracle and statement-date balance-authority corrections and is not final acceptance evidence.

---

<a id="baseline-sprint-76a-57"></a>

- **Sprint 76A multi-instrument correction:** `CardStatementEvidence`, confirmation, persistence, hydration and presentation now preserve ordered `0...N` document-scoped instrument sections. Each section owns its typed card-account observation, explicit durable-instrument decision, financial rows and signed total; same holder text does not merge sections, section credit totals retain source direction and statement summary arithmetic remains separate.

---

<a id="baseline-sprint-76a-58"></a>

- **Sprint 76A encrypted PDF and credential boundary:** The shared PDF reader unlocks the same immutable source snapshot and hands native text plus page boundaries to exact Amex normalization in memory; it creates no decrypted PDF file or reconstructed source bytes. Import coordination tries bounded remembered candidates, uses the secure UI challenge only when needed and persists a successfully used password under the detected institution's namespaced Keychain scope only after successful unlock and authoritative detection. Reader, parser, diagnostics, SQLite and source evidence never own the credential. Production Keychain persistence/reuse was manually proven; deterministic automation uses the already-authorized test-host or in-memory credential path.

---

<a id="baseline-sprint-76a-59"></a>

- **Sprint 76A currency authority:** `ledgerforge.currency-catalog.v2` contains 155 deterministic active ordinary ISO 4217 List One currencies with numeric minor units from the SIX 2026-01-01 publication, excluding current List Two fund codes and List One `N.A.`-scale entries. Catalog membership and 0/2/3-digit Money mechanics do not imply parser or institution support, FX rates, conversion or reporting-currency totals.

---

<a id="baseline-sprint-76a-60"></a>

- **Sprint 76A persistence and semantic sources:** Additive Migration V13 leaves V1–V12 immutable, migrates readable V12 single-section card graphs deterministically and adds ordered card-statement sections, section observations and exact semantic projection/group/member records. Byte-distinct sources may share one card semantic group only after complete ordered projection equality; the first is authoritative and exact later sources are supporting evidence with zero duplicate canonical transactions. SQLite/In-Memory parity, provider reconstruction, hydration and zero-residue rejection are enforced.

---

<a id="baseline-sprint-76a-61"></a>

- **Sprint 76A exact Amex and private-source acceptance:** The exact `amex.credit-card.pdf@1` grammar now supports all section/page arrangements proven by ten source documents: eight encrypted originals and two byte-distinct unlocked equivalents. The eight chronological statements contain 21, 32, 49, 63, 34, 61, 34 and 60 financial rows, 354 total; 8/8 statement equations, 7/7 adjacent balance continuities, zero Posting Dates outside period and zero section reconciliation mismatches passed the independent oracle. Three instrument observations were preserved. Production-versus-oracle comparison, chronological/reverse/mixed campaigns, both equivalent-pair orders, combined ten-source import, SQLite/In-Memory parity and reopen/hydration passed. No private value, identifier, path, filename, password or decrypted artifact was published in repository history or documentation.

---

<a id="baseline-sprint-76a-62"></a>

- **Sprint 76A cycle-close acceptance:** After correcting one stale test oracle that still treated newly supported JPY as unsupported, the authoritative replacement cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 721 tests across 87 suites, zero failures and zero skips. The first cycle-close completed both builds and ran the same 721 tests but failed only that stale expectation; it is not acceptance evidence.

---

<a id="baseline-sprint-76-50"></a>

- **Sprint 76 profile and source semantics:** Added exact native selectable-text `amex.credit-card.pdf@1` for the approved American Express Middle East Platinum QAR statement family. Posting Date remains the canonical transaction date; source Transaction Date is preserved separately. Charges increase amount owed, payments/refunds decrease amount owed, and bank debit/credit fields remain unused. Account-level payments, instrument rows, original merchant Money, multiline narration, references, statement summaries and physical source order are preserved. Rewards and final informational pages remain non-financial only under exact family signatures.

---

<a id="baseline-sprint-76-51"></a>

- **Sprint 76 shared card domain:** ADR-044 reuses the durable credit-card `Account` as the liability account and adds immutable application-owned `CardInstrument` identity, source observations, explicit instrument relationships, bounded lifecycle state, card-specific transaction effects, typed statement evidence and a dedicated runtime `CardStore`. Masked Membership Number and Card Account Number observations never become strong identifiers. Exact durable user-confirmed mappings may be reused; changed weak evidence requires explicit account/instrument authority, and lifecycle or replacement is never inferred from chronology.

---

<a id="baseline-sprint-76-52"></a>

- **Sprint 76 persistence and hydration:** Additive Migration V12 adds seven restrictive card tables with no historical backfill. Provider-owned confirmed import atomically writes and revalidates the account/instrument/statement/transaction graph with SQLite/In-Memory parity. Canonical hydration reconstructs and validates that graph after close/reopen. Current liability balance is selected by newest source statement date, not import time, and published with net-worth sign; charges/payments do not enter ordinary bank income/expense totals.

---

<a id="baseline-sprint-76-53"></a>

- **Sprint 76 private-source acceptance:** The two approved originals were verified directly by SHA-256 and independent PDFKit row extraction. The earlier statement contained 61 rows and the later statement 34 rows. Ordered production-versus-independent comparisons produced zero row mismatches and zero summary mismatches for both statements; closing-to-opening continuity matched exactly. Chronological and reverse campaigns with both providers ended with one liability account, one instrument, 95 transactions, two statements and a runtime balance of negative QAR 7,761.88. Exact-byte duplicate handling, SQLite checkpoint/close/reopen and canonical hydration preserved the same graph. No private source path, filename, transaction list, identifier, narration or source-derived fixture was published.

---

<a id="baseline-sprint-76-54"></a>

- **Sprint 76 lifecycle falsification:** Exact previously confirmed observations reuse one instrument; changed weak evidence rejects without accepted residue until an explicit separate-account or additional/replacement/renewal/upgrade decision is supplied. No relationship changes lifecycle from `unknown`; stale provider generation and conflicting strong instrument ownership reject atomically in SQLite and In-Memory. Importing the older statement after the newer statement does not change current balance authority.

---

<a id="baseline-sprint-76-55"></a>

- **Sprint 76 focused acceptance:** The frozen Amex/migration/lifecycle boundary passed 61 tests across five suites. The adjacent CBQ, HDFC, Axis, bank-validation, categories, accounts and dashboard regression boundary passed 104 tests across 12 suites. The cycle-discovered V12 metadata correction passed 12 tests across two suites.

---

<a id="baseline-sprint-76-56"></a>

- **Sprint 76 cycle-close acceptance:** The authoritative replacement cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 701 tests across 86 suites and zero failures. The first cycle-close completed both builds but found four stale V11 test expectations; after the named V12-only correction, the replacement run is acceptance evidence.

---

<a id="baseline-sprint-75-43"></a>

- **Sprint 75:** Added exact native selectable-text `cbq.current-account.history.pdf@1` and `cbq.current-account.monthly.pdf@1` profiles beside `cbq.current-account.xls@1`. History PDF preserves its full account identifier, posting dates, signed QAR amounts, descending source order and row-associated balances without inventing a period, value date or summary. Monthly PDF preserves posting date as the canonical event date, source Transaction Date only as a separate observation, masked account/IBAN evidence, debit/credit direction, QAR Money, balances, statement boundary and brought-forward/closing evidence; brought-forward and exact non-financial promotional content are not transactions.

---

<a id="baseline-sprint-75-44"></a>

- **Sprint 75 account identity:** Full identifiers remain strong parser-owned ownership evidence. Typed masked CBQ account and IBAN patterns are durable evidence about an account, never fabricated full identifiers. Exact positional masked/full compatibility may resolve or explicitly narrow account choice, and a later compatible full history identifier attaches atomically to the existing monthly-created account. Generic identity resolution and generic no-match selection safety remain unchanged.

---

<a id="baseline-sprint-75-45"></a>

- **Sprint 75 source lineage:** ADR-043 keeps one canonical transaction while every accepted source retains its own document, exact source-byte fingerprint, session, normalized rows, statement observation and one transaction observation per financial row. Exact account, posting date, signed QAR amount and row balance establish lineage; a structured-reference digest is used only for exact collision disambiguation. Monthly PDF is preferred over history PDF, then history XLS, for source-evidence presentation only; canonical transaction document/session provenance is never rewritten.

---

<a id="baseline-sprint-75-46"></a>

- **Sprint 75 persistence:** Additive Migration V11 introduces typed CBQ source-identity, statement-source and transaction-source observations with restrictive relationships, exact accepted-row coverage and no historical backfill. Reviewed all-new, mixed and fully represented sources are atomically revalidated and committed with SQLite/In-Memory parity. Fully represented sources remain accepted with zero new transactions and complete source evidence.

---

<a id="baseline-sprint-75-47"></a>

- **Sprint 75 private-source acceptance:** Four direct-URL source-order campaigns were verified with both SQLite and In-Memory. History-first campaigns imported 60 then 0, 0 and 0 new transactions; monthly-first campaigns imported 9, 8, 43 and 0. Every campaign ended with one account, 60 canonical transactions, four durable attempts and 60 preferred-source mappings; SQLite reopen preserved the same graph. Independent history PDF/XLS comparison covered 60 exact rows with zero ordered or event-set mismatches, and the two monthly sources contributed 9 and 8 exact subset rows. Only aggregate counts are recorded; no private value, path, filename, identifier, narration, reference or digest was published.

---

<a id="baseline-sprint-75-48"></a>

- **Sprint 75 focused acceptance:** The new PDF/lineage suite passed 8 tests; the final diagnostic correction passed 35 tests across the four affected legacy suites. The detector now selects exact institution rules by source extension so a broad PDF signature cannot admit a damaged XLS near-match.

---

<a id="baseline-sprint-75-49"></a>

- **Sprint 75 cycle-close acceptance:** After the material detector correction, the authoritative replacement cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 691 tests across 85 suites and zero failures. The earlier pre-correction cycle ran the same 691 tests and failed five tests with six reported issues; it is not acceptance evidence.

---

<a id="baseline-sprint-74-38"></a>

- **Sprint 74:** Added exact `cbq.current-account.xls@1` support for the retained CBQ current-account transaction-history legacy-XLS grammar through the ordinary direct-URL reader, detector, classifier, parser-selection, validation, explicit-confirmation, provider, hydration and relaunch path. Signed QAR amounts, descending physical source order, same-date ambiguity and every printed row-associated balance are preserved without inventing a statement period, value date, timestamp or source-order balance recurrence.

---

<a id="baseline-sprint-74-39"></a>

- **Sprint 74 identity and source boundary:** One parser-owned verified full printed institution account identifier is the sole strong account identity. Holder text and filename are not identity. Blank merged-cell placeholders are retained as physical blanks, while hidden cells carrying financial or textual evidence continue to fail closed. Exact source bytes remain duplicate authority.

---

<a id="baseline-sprint-74-40"></a>

- **Sprint 74 private-source acceptance:** The bound 61-row legacy-XLS source passed the ordinary `ImportEngine.prepareImport(from:)` path. All 61 dates, signed amounts and row-associated balances matched an independently extracted six-page selectable-text PDF projection in source order with zero mismatches. Preparation wrote nothing; confirmation produced one accepted event set; exact-byte reimport produced no duplicate financial events; In-Memory and SQLite graphs matched; SQLite close/reopen and canonical hydration preserved the complete graph. No private source value, identifier, path, filename, narration, reference or oracle digest was published in repository documentation, and task-owned private artifacts were removed after verification.

---

<a id="baseline-sprint-74-41"></a>

- **Sprint 74 focused acceptance:** The final changed reader/CBQ boundary passed 19 tests across 4 suites; the broader adjacent legacy-XLS, Axis/HDFC XLS, detection, classification, selection and validation boundary passed 52 tests across 10 suites. The new CBQ synthetic surface passed 13 tests across 3 suites before the merged-placeholder correction and is subsumed by the final focused boundary.

---

<a id="baseline-sprint-74-42"></a>

- **Sprint 74 cycle-close acceptance:** The single authoritative cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 683 tests across 84 suites and zero failures.

---

<a id="baseline-sprint-73a-37"></a>

- **Sprint 73A test-only closure:** Corrected three stale Developer Database Profile expectations after Migration V10. V9 is the newest and default historical migration-sandbox source, V8 remains historical, and V10 remains current. Sprint 73A changed no production, parser, migration, ADR, persistence, fixture, source-truth or financial behaviour. The replacement cycle-close passed a fresh Debug build, fresh optimized Release build and the complete TestPlan with 670 tests across 81 suites and zero failures.

---

<a id="baseline-sprint-73-36"></a>

- **Sprint 73:** Added the exact native selectable-text `hdfc.bank-account.pdf@1` grammar and the first durable exact whole-statement equivalence contract for the approved HDFC PDF/XLS v1 pair. The first accepted source remains transaction and provenance authority; a later exact-equivalent other-format source retains its own accepted evidence and creates zero transactions.

---

<a id="baseline-sprint-73-114"></a>

- **Sprint 73 implementation boundary:** `ledgerforge.statement-financial-projection.sha256.v1` deterministically covers institution, statement family, declared period, INR, derived opening balance, debit/credit counts and totals, closing balance, and every ordered event's ordinal, statement date, value date, direction, signed Money, running balance and explicit reference absence. It excludes filenames, source fingerprints, parser profile, physical ordinals, narration, display account name, customer identity and inferred NRE/NRO subtype.

---

<a id="baseline-sprint-73-115"></a>

- **Sprint 73 provider behavior:** SQLite and In-Memory resolve the exact account/family/period/currency group inside the provider-owned confirmed-import transaction. First-source and supporting-source graphs are atomic; supporting acceptance records `equivalent_source_recorded`, zero imported transactions, a second document/session/source-byte fingerprint/projection/member and an identifier observation without changing existing transactions, categories or authority. Exact bytes still return `exact_statement_duplicate`; projection conflict, missing pre-V10 evidence and represented byte-different format return `statement_equivalence_conflict`, `statement_equivalence_evidence_unavailable` and `equivalent_format_already_recorded` respectively.

---

<a id="baseline-sprint-73-116"></a>

- **Sprint 73 migration and ADR impact:** Additive Migration V10 introduces source projections, contiguous ordered projection events, equivalence groups and authoritative/supporting members with restrictive relationships and no historical backfill. ADR-042 is the latest accepted ADR. Existing V9 history remains readable; complete HDFC event overlap without durable V10 evidence fails closed rather than inventing period or equivalence truth.

---

<a id="baseline-sprint-73-117"></a>

- **Sprint 73 private-source acceptance:** All four retained PDF/XLS pairs matched at 62, 16, 76 and 7 ordered rows, 161 total. Direct field mismatches, printed-summary mismatches and production projection mismatches were zero. Both PDF→XLS and XLS→PDF orders retained one transaction set and two source records per pair; SQLite close/reopen and canonical hydration preserved the graph. Only aggregate counts are recorded.

---

<a id="baseline-sprint-73-118"></a>

- **Sprint 73 focused verification:** The final consolidated boundary passed 358 tests across 39 suites with zero failures. It covered the ordinary HDFC PDF URL route, exact PDF/XLS projection, Migration V10, SQLite/In-Memory equivalence parity, supporting-write rollback injection, source snapshots and fingerprints, identity ownership, confirmed-import atomicity, canonical hydration, provider reconstruction and result/history presentation.

---

<a id="baseline-sprint-73-119"></a>

- **Sprint 73 runtime verification:** One representative 7-row private pair was exercised through the signed Debug app on an isolated Persistent Debug Database at V10. PDF-first explicit confirmation created 7 authoritative transactions; the paired XLS presented and committed `equivalent_source_recorded` with 0 new transactions and no transaction-navigation action. Live Import History distinguished both outcomes, and quit/relaunch plus profile reactivation hydrated the same 7/0 aggregate counts and both durable outcomes.

---

<a id="baseline-sprint-73-120"></a>

- **Sprint 73 exact exclusions:** No fuzzy or narration similarity, partial overlap, same-format semantic acceptance, Axis/CBQ/card equivalence, authority switching, source replacement, provenance reassignment, historical repair/backfill, OCR, password workflow, HDFC CSV/XLSX/cards, generic PDF/spreadsheet parsing or document-byte storage is implemented.

---

<a id="baseline-sprint-72-35"></a>

- **Sprint 72:** Added the exact shared `hdfc.bank-account.xls@1` HDFC NRE/NRO legacy-XLS grammar through the accepted reader and ordinary detector, classifier, parser-selection, preview, explicit-confirmation, provider, hydration and relaunch pipeline. Exact source bytes remain the XLS duplicate authority; no PDF/XLS cross-format suppression was added.

---

<a id="baseline-sprint-72-68"></a>

- **Sprint 72 source semantics:** `Date` is the authoritative transaction date, `Value Dt` is retained separately, `Withdrawal Amt.` is debit/outflow, `Deposit Amt.` is credit/inflow, and source physical row order plus source ordinals are preserved. Printed period, opening/closing balances, debit/credit counts and totals reconcile independently for each statement.

---

<a id="baseline-sprint-72-69"></a>

- **Sprint 72 identity and fail-closed boundary:** Only the parser-produced verified full account number is emitted through the strong institution-account identifier contract. Shared customer identity and product metadata are excluded from account resolution. Missing, malformed, duplicate, reordered, near-match or ambiguous grammar, amount, date, identifier and summary evidence fails closed with zero accepted financial residue.

---

<a id="baseline-sprint-72-70"></a>

- **Sprint 72 private-source acceptance:** Four private-original XLS/PDF source families were verified locally through an independent paired-PDF oracle: 62, 16, 76 and 7 ordered rows, 161 total. Requested row-field mismatches, printed-summary mismatches and two annual-to-recent continuity mismatches were all zero. No private source value, path, filename, identifier, narration or reference was published in repository documentation; task-owned source-derived artifacts and private-test result bundles were removed after verification.

---

<a id="baseline-sprint-72-112"></a>

- **Sprint 72 acceptance evidence:** The consolidated focused boundary discovered and executed 207 tests across 29 selected suites with zero failures. The single authoritative cycle-close passed fresh Debug and optimized Release builds plus 655 tests across 79 complete-TestPlan suites with zero failures or unexpected skips. SQLite and In-Memory outcomes matched; exact-byte duplicate rejection, atomic confirmed persistence, canonical hydration, provider reconstruction and SQLite close/reopen relaunch preservation passed.

---

<a id="baseline-sprint-72-113"></a>

- **Sprint 72 migration and ADR impact:** Migration remains V9 and ADR-041 remains the latest accepted ADR. HDFC PDF production support remains the separately bounded Sprint 73 outcome; HDFC CSV, XLSX, cards, generic HDFC layouts and cross-format suppression remain unsupported.

---

<a id="baseline-sprint-71-31"></a>

- **Sprint 71:** Added a native OLE2/BIFF8 reader and the exact `axis.bank-account.xls@1` Axis NRO profile through the ordinary reader, detector, classifier, normalizer, parser, review, confirmation, provider and hydration pipeline. The reader is XLS-only; XLSX, OOXML, formula evaluation, macros, generic spreadsheet mapping, other layouts and cross-format duplicate suppression remain unsupported.

---

<a id="baseline-sprint-71-32"></a>

- **Sprint 71 third-party boundary:** LedgerForge vendors the required libxls 1.6.3 sources from `libxls/libxls` tag `v1.6.3` at `c199d132494833da696b58aa4acf3fc5a36d930b` under the BSD 2-clause license. The local Swift package builds a static C library, exposes only the LedgerForge bridge and links only the macOS system `iconv` boundary.

---

<a id="baseline-sprint-71-33"></a>

- **Sprint 71 source truth:** The committed independent evidence verifies 16 baseline XLS transactions, 20 extended XLS transactions, 16 shared ordered rows and 4 extended-only ordered rows. The Range-1 CSV legitimately contains 17 transactions while its XLS contains 16; no fixture or expected evidence was changed to manufacture parity.

---

<a id="baseline-sprint-71-34"></a>

- **Sprint 71 fail-closed boundary:** Invalid or truncated containers, encryption, multiple or hidden worksheets, formulas, boolean/error cells, missing/duplicate/ambiguous/reordered headers, malformed monetary values and unsupported near-match layouts reject before accepted financial writes. Workbook bytes remain confined to the transient immutable source snapshot.

---

<a id="baseline-sprint-71-110"></a>

- **Sprint 71 acceptance evidence:** All named focused reader, normalizer, parser, detector/classifier, source-snapshot, fingerprint, provider-parity, persistence, hydration and relaunch suites passed with nonzero execution. The authoritative cycle-close passed fresh Debug and Release builds and 643 tests across 76 suites with zero failures or unexpected skips. SQLite and In-Memory exact-reimport outcomes matched, provider reconstruction and SQLite close/reopen preserved the complete XLS graph, and rejection tests left zero accepted residue.

---

<a id="baseline-sprint-71-111"></a>

- **Sprint 71 Release boundary:** The arm64 Release app contains the XLS bridge and libxls symbols statically in the executable, links the system `libiconv`, contains no libxls dynamic library and requires no bundled Java, Python or LibreOffice runtime. The repository contains the verbatim upstream license and concise third-party notice. Migration remains V9 and ADR-041 remains the latest accepted ADR.

## Historical context

These source snapshots retain earlier mixed or unnumbered evidence. Their original claims and internal order are preserved; no shared acceptance date or new sprint attribution is inferred.

---

<a id="historical-alignment-2026-08-28"></a>

## Historical Alignment — 2026-08-28 (superseded by the 2026-09-09 V17 acceptance)

This section preserves the 2026-08-28 alignment snapshot for traceability. The 2026-09-09 alignment above supersedes it wherever current support, migration or planning status differs.

### Accepted production baseline

- **Primary branch:** `main`.
- **Accepted implementation:** Sprint 79 on `main` at implementation commit `9489f6b21c9d585d2d90f2ba4798a931590057f7`; the documentation-reconciliation commit is recorded by Git history.
- **Latest accepted numbered sprint:** Sprint 79.
- **Latest accepted discovery outcome:** Sprint 80 — Swift 6 and macOS readiness closure (`SWIFT6_READINESS_COMPLETE`); no production implementation or migration was performed.
- **Latest accepted ADR:** ADR-045 — Qatar Airways Salary Actuals and Current-Month Funding Planner; implemented with Sprint 79. ADR-044 remains the accepted card-domain authority.
- **Accepted migration:** V16.
- **Accepted card profiles:** exact `amex.credit-card.pdf@1`, exact `cbq.credit-card.pdf@1`, and the exact Axis `axis.credit-card.pdf@1` / `axis.credit-card.xlsx@1` families accepted by Sprint 78B. No generic card/PDF/XLSX support is implied.
- **Personal-v1 adoption:** still undeclared; release/adoption certification remains a separate future gate.

### Sprint 79 closure and current planning

- Sprint 78 failed and Sprint 78A failed; Sprint 78B is accepted and completes the Sprint 78 outcome.
- Exact Axis credit-card PDF/XLSX support, the dual Axis PDF credential scopes, zero-instrument liability semantics, cross-format equivalence and Migration V15 are accepted production state.
- Sprint 79 is technically accepted and published. Exact `qatar-airways.salary.pdf@1`, the dedicated Salary workspace/current-month funding planner and additive Migration V16 are accepted production state.
- No Sprint 78C exists because Sprint 78B completed the required outcome.
- Sprint 78B remains the accepted Axis credit-card closure; Sprint 79 builds on that baseline without reopening the completed Sprint 78 outcome.

### Sprint 79 accepted implementation

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

Additive Migration V16 is accepted for truthful salary-actual and current-month funding-plan persistence with SQLite/In-Memory parity and canonical `RepositoryStoreHydrator` integration. V16 is the current migration baseline; V1–V15 remain immutable.

ADR-045 is the accepted and implemented architecture authority for the Sprint 79 boundary.

Sprint 79 acceptance evidence on the final privacy-safe candidate includes a 9/9 Salary parser/planner suite with the complete 20-source authentic oracle gate, plus the authoritative complete TestPlan at 819 total / 814 passed / 5 intentionally skipped / 0 failed. The published implementation commit is `9489f6b21c9d585d2d90f2ba4798a931590057f7`.

The authentic July 2026 CBQ credit-card compatibility defect was separately classified `PRE_EXISTING_OR_EXTERNAL` relative to Sprint 79. It remains future work and does not alter Sprint 79 acceptance.

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
- Additive V15 remains the accepted Sprint 78B migration. Additive V16 is accepted with Sprint 79 and is now the current migration baseline.

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
- Current cycle roadmap: `Project documents/Sprint roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md`; the prior `Project documents/Sprint roadmap/Archived/LedgerForge_Roadmap_Sprints_70-79_Current.md` is retained as the historical prior-cycle roadmap.
- Standing execution method: `Project documents/LedgerForge_Standing_Execution_Harness_Guide.md`.
- Accepted state: this file.
- Unscheduled queue: `Project documents/FUTURE_WORK.MD`.
- Accepted architecture: `Project documents/ADR.md`.
- Current task authorization: complete Chat-approved prompt.

ChatGPT Chat owns sprint/architecture/prompt/acceptance decisions. MCP executor is the Chat plugin for guarded local Mac repository/Xcode access. Codex is a separate execution environment and does not automatically inherit Chat-only context. Model capability order is **Sol > Terra > Luna** and is independent of execution environment.

---

---

<a id="historical-baseline-1"></a>

- **Current repository implementation baseline:** accepted Sprint 88 at `4f5eeb7b11c0f5879204a06ae9f08045304342b5` (parent documentation closure `4973d2d2507ae5891bfa593b359af2b9393e5fa1`), layered on accepted Sprints 81–87 and the technically accepted unnumbered Authentic-Corpus Parser / Import Reliability Reset with additive V17; Sprint 79 and its commit `9489f6b21c9d585d2d90f2ba4798a931590057f7` remain in Git history

---

<a id="historical-baseline-4"></a>

- **Latest chronologically accepted production implementation:** Sprint 88 — App Shell and Workflow Decomposition; the unnumbered Authentic-Corpus Parser / Import Reliability Reset remains the latest accepted parser/source implementation, and Sprint 79 remains the latest numbered financial-domain feature implementation

---

<a id="historical-baseline-5"></a>

- **Latest verified Debug development-tooling implementation:** DBP-01 Developer Database Profiles at `2d86f91dc46b9e88bcdfea65c88ddf671968b388`

---

<a id="historical-baseline-7"></a>

- **Latest verified completed numbered increment:** Sprint 84 — PR-2 SQLite / Provider / Migration Ownership

---

<a id="historical-baseline-9"></a>

- **Latest accepted ADR:** ADR-046 — Authentic-Corpus-Only Parser Authority and Adaptive Financial Source Interpretation; the accepted reset implements its complete registered-corpus reliability boundary

---

<a id="historical-baseline-76"></a>

- **Latest verified repository-maintenance change:** `7ee20a909038d1088f830a6ea588311625f415e5`

---

<a id="historical-baseline-77"></a>

- **Latest verified implementation-adjacent maintenance repair:** P0 Axis bank-account source-truth restoration; new imports use `axis.bank-account.csv@2`, physical DR is debit/outflow and physical CR is credit/inflow, and header positions remain dynamically resolved

---

<a id="historical-baseline-78"></a>

- **Current overlap boundary:** ordinary no-overlap statements remain full imports, exact-content duplicates remain ADR-030 outcomes, and full supported event overlap remains whole-statement blocked; provenance-less mixed-overlap evidence is unsupported and cannot produce a new reviewed partial plan

---

<a id="historical-baseline-83"></a>

- **Current exclusions:** unapproved institutions/profiles, currencies outside exact supported paths, unsupported event families, generic mixed or interleaved overlap, arbitrary omission, fuzzy candidates, ownership override and historical repair remain unavailable

---

<a id="historical-baseline-89"></a>

- **Latest Sprint 65 focused result:** 381 tests across 43 suites passed; 0 failures, skips or expected failures; changed-file warnings 0 and analyzer diagnostics 0

---

<a id="historical-baseline-90"></a>

- **Latest Sprint 65 complete-TestPlan result:** 607 tests across 73 suites passed; 0 failures, skips or expected failures; changed-file warnings 0 and analyzer diagnostics 0; 9 pre-existing warnings remained

---

<a id="historical-baseline-91"></a>

- **Latest Sprint 67 focused result:** 36 tests across 3 suites passed with zero failures; hydration, forced refresh, atomic failure preservation, detail presentation, existing filters, confirmed-import recovery and SQLite relaunch coverage were included

---

<a id="historical-baseline-92"></a>

- **Latest Sprint 67 complete-TestPlan result:** 616 tests across 73 suites passed with zero failures; one fresh Debug build passed, with only the pre-existing AppIntents metadata notice and unrelated Swift 6 transition warnings

---

<a id="historical-baseline-94"></a>

- **Latest Sprint 67A focused result:** 80 tests across 4 suites passed with zero failures; exact document lookup parity, canonical hydration, malformed/legacy fail-closed behavior, typed detail presentation, category/search/toggle preservation and SQLite close/reopen reconstruction were included

---

<a id="historical-baseline-95"></a>

- **Latest Sprint 67A complete-TestPlan result:** 622 tests across 73 suites passed with zero failures; one fresh isolated Debug build passed with only the pre-existing AppIntents metadata notice

---

<a id="historical-baseline-96"></a>

- **Latest Sprint 68 focused result:** 153 tests across 14 selected suites passed; 0 failures, skips or expected failures. Fresh Debug and Release builds passed; the existing Swift 6 transition warnings remained outside this sprint's source boundary.

---

<a id="historical-baseline-99"></a>

- **Latest Sprint 68A focused result:** A fresh Debug build passed. 97 tests across 8 selected suites passed with 0 failures, skips or expected failures; `git diff --check` passed. Existing Swift 6 transition warnings remained outside the Sprint 68A source boundary.

---

<a id="historical-baseline-103"></a>

- **Latest Axis source-truth automated result:** 426 top-level tests (458 parameterized executions), 0 failures and 0 skips in the complete signed canonical TestPlan before Sprint 65

---

<a id="historical-baseline-104"></a>

- **Latest Axis source-truth focused result:** 41 top-level tests (46 parameterized executions), 0 failures and 0 skips across direction, source-oracle, NRO evidence, overlap-quarantine, shared-profile and direct-provider fail-closed suites using SQLite and In-Memory providers

---

<a id="historical-baseline-105"></a>

- **Latest Axis source-truth build result:** fresh signed Debug and explicitly optimized Release builds plus Debug and Release static analysis pass

---

<a id="historical-baseline-107"></a>

- **Latest reported local automated result:** Sprint 69's canonical complete TestPlan recorded 628/628 tests passed with zero failures and zero skips

---

<a id="historical-baseline-108"></a>

- **Latest focused category-reconciliation result:** 71 top-level tests (86 parameterized executions), 0 failures and 0 skips across category, hydrator, import-hydration, development-lifecycle and migration-integrity suites

---

<a id="historical-baseline-109"></a>

- **Latest reported local build result:** Sprint 69 fresh Debug and Release builds passed before the reported canonical TestPlan result

---

<a id="historical-baseline-122"></a>

- **Previous Sprint 55 automated result:** 409 top-level tests across 49 suites, 0 failures and 0 unexpected skips in each of three consecutive exact canonical default-parallel TestPlan runs

---

<a id="historical-baseline-127"></a>

- **Generic UI-test state:** `LedgerForgeUITests` remains intentionally disabled

---

<a id="historical-capabilities-and-limitations"></a>

## Historical capability and limitation record

Original compiled PROJECT_STATE capability/limitation body from the pre-refactor baseline. It mixes earlier accepted boundaries and source exclusions; headings containing “Current” refer to that historical text, not today. Current applicability is exclusively [PROJECT_STATE](../../PROJECT_STATE.md) and ADR-046. This preserves the specific Axis direction-risk commit range, missing-evidence qualifications and non-runs rather than silently losing them. No new acceptance date is assigned.

## Current Production Capability

The exact Sprint 79 `qatar-airways.salary.pdf@1` salary-actual import and the
dedicated Salary/current-month funding planner are also accepted production
capabilities under ADR-045 and Migration V16. The narrower bank-account and
card summaries below are retained historical sub-summaries; the Current
Alignment section above is authoritative where those summaries predate Sprint
79 or Sprint 78B.

### Salary actuals and current-month planning

- Salary support is limited to the exact source-proven
  `qatar-airways.salary.pdf@1` family; imported salary actuals remain distinct
  from bank transactions and use source-owned periods, kinds, ordered
  earnings/deductions and native QAR Money.
- The dedicated Salary destination owns Salary History and This Month
  planning. Checked account balances are explicit planning snapshots, and
  missing evidence makes affected outputs incomplete rather than zero.
- The editable planner uses user-entered expected salary, native QAR/INR
  commitments, plan-local dated INR-per-QAR FX, explicit transfer-fee
  semantics, upward QAR minor-unit funding rounding and derived investment
  capacity. No automatic salary-bank matching, transfer execution, global FX
  activation or investment execution is supported.

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

The active chain ends at V17. Migration V7 adds explicit partial-attempt counts, durable partial-import summaries and one typed incoming-row disposition per normalized source row for ADR-040. Additive Migration V8 adds workspace-owned categories and a separate restrictive current transaction-category assignment relationship without changing imported financial rows or provenance. Migration V9 adds versioned document-fingerprint authority and the source-byte fingerprint relationship without storing source bytes. Additive Migration V10 adds exact statement projections, ordered projection events, equivalence groups and authoritative/supporting members without backfilling existing history. Additive Migration V11 adds typed CBQ masked source-identity observations, statement-source observations and one transaction-source observation for every accepted CBQ financial row. Additive Migration V12 adds durable card instruments, strong instrument identifiers, source observations, explicit instrument relationships, statements, typed summaries and one-to-one card transaction evidence. Additive Migration V13 adds ordered card-statement sections, section-owned observations and exact card semantic projections/groups/members while deterministically migrating readable V12 single-section graphs. Additive Migration V14 transactionally generalizes the four constrained card evidence tables for exact CBQ observations, family summary components, printed-summary membership and account-level physical section membership while preserving V13 Amex rows unchanged. Additive Migration V15 adds the accepted Axis card semantic/equivalence state. Additive Migration V16 adds the accepted Qatar Airways salary-actual and current-month funding-plan state. Additive Migration V17 adds Axis bank-projection compatibility and zero-activity/card-summary schema support without changing V1–V16; schema capacity does not certify an absent genuine zero-activity source. V1–V16 remain immutable and no financial backfill is invented.

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

The limitation summaries below retain older domain-specific wording for
traceability. The Current Alignment and Current Production Capability
sections above supersede any pre-Sprint-79 statement about the accepted Axis
card family, Migration V16, or the exact Qatar Airways salary/planning slice.

### Production format and institution limits

- Production parser support is limited to the exact documented Axis, HDFC and CBQ bank-account profiles, the exact Amex, CBQ and Axis credit-card profiles, and the exact Qatar Airways salary profile; no generic institution, payroll or layout claim exists.
- General Axis NRO coverage and additional Axis layouts remain unsupported.
- Other Axis PDF layouts, OCR, arbitrary password-protected PDFs and generic PDF statement support remain unsupported. Encrypted production support is limited to exact `amex.credit-card.pdf@1`, `cbq.credit-card.pdf@1` and the accepted encrypted Axis credit-card PDF families.
- Generic XLSX/OOXML, TXT and OCR are not production-supported. The exact `axis.credit-card.xlsx@1` profile is accepted separately; XLS remains supported only for the exact documented Axis, HDFC and CBQ profiles.
- HDFC and CBQ bank-account support is limited to their exact documented profiles. Card support is limited separately to exact `amex.credit-card.pdf@1`, `cbq.credit-card.pdf@1`, `axis.credit-card.pdf@1` and `axis.credit-card.xlsx@1`; no other American Express/CBQ/Axis layout or issuer card family is supported.
- Production secure password entry and institution-scoped Keychain reuse exist for exact encrypted `amex.credit-card.pdf@1`, `cbq.credit-card.pdf@1` and the accepted Axis credit-card PDF families; this does not establish arbitrary encrypted-PDF or generic credential-profile support.
- QAR production import exists only for the exact three-profile CBQ current-account family under ADR-043, the exact Amex/CBQ card profiles under ADR-044, and the exact Qatar Airways salary profile under ADR-045.

### Card limits

ADR-034's document-scoped evidence boundary is implemented and refined by
ADR-044 for the shared card foundation and exact
`amex.credit-card.pdf@1`, `cbq.credit-card.pdf@1`, `axis.credit-card.pdf@1`
and `axis.credit-card.xlsx@1` profiles. Durable liability accounts, card instruments,
source observations, explicit relationships, statement sections and summaries,
transaction evidence, Migration V14/V15, SQLite/In-Memory parity, hydration and
bounded presentation are operational for those profiles.

The following remain unimplemented: HDFC card parsers; additional Amex, CBQ or
Axis layouts; generic card profiles or masked identity; rewards persistence or
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

- global exchange-rate storage beyond the Sprint 79 plan-local, user-entered
  dated FX quote;
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
