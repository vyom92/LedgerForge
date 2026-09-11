# Accepted outcomes — Sprints 60-69

Historical collection, not current implementation or execution authority. [Current state](../../PROJECT_STATE.md) owns the snapshot. Ordering inherits [Guide rule F](../../Project_Guide.md#documentation-order): known acceptance dates descending, then recorded sequence or natural sprint ID descending as display order. Undated records follow; original evidence interiors are unchanged. A review/observation date is not assigned as an acceptance date. Repeated historical summaries preserve their own limitations and may describe superseded support, fixture policy or migration state. ADR-046 and current scope decisions control all new work.

For repeated records of one outcome, the original state record precedes roadmap detail, then snapshot excerpts in their original source sequence. This is a display tie-break, not a second acceptance chronology. Cross-cycle compiled snapshots and unnumbered records without one acceptance date are separate historical context, ordered by stable record key under Guide rule I. Their placement does not attribute every contained fact to this cycle.

## Index

### Acceptance records

- [Sprint 69 repository interface](#baseline-sprint-69-29) — Acceptance date not recorded; historical evidence
- [Sprint 69 acceptance-evidence classification](#baseline-sprint-69-30) — Acceptance date not recorded; historical evidence
- [Sprint 68B, DBP-01 Maintenance Correction and Sprint 69 — Local Validation Closure](#record-sprint-68b) — Acceptance date not recorded; historical evidence
- [Sprint 68B](#baseline-sprint-68b-27) — Acceptance date not recorded; historical evidence
- [Sprint 68A](#baseline-sprint-68a-26) — Acceptance date not recorded; historical evidence
- [Sprint 68A runtime verification](#baseline-sprint-68a-100) — Acceptance date not recorded; historical evidence
- [Sprint 68A TestPlan decision](#baseline-sprint-68a-101) — Acceptance date not recorded; historical evidence
- [Sprint 68A migration and ADR impact](#baseline-sprint-68a-102) — Acceptance date not recorded; historical evidence
- [Sprint 68](#baseline-sprint-68-24) — Acceptance date not recorded; historical evidence
- [Sprint 68 privacy boundary](#baseline-sprint-68-25) — Acceptance date not recorded; historical evidence
- [Sprint 68 runtime verification](#baseline-sprint-68-97) — Acceptance date not recorded; historical evidence
- [Sprint 68 TestPlan decision](#baseline-sprint-68-98) — Acceptance date not recorded; historical evidence
- [Sprint 67A — Authoritative Source-Document Binding](#record-sprint-67a) — Acceptance date not recorded; historical evidence
- [Sprint 67A](#baseline-sprint-67a-23) — Acceptance date not recorded; historical evidence
- [Sprint 67 — Transaction Provenance and Clearer Detail](#record-sprint-67) — Acceptance date not recorded; historical evidence
- [Sprint 67](#baseline-sprint-67-22) — Acceptance date not recorded; historical evidence
- [Sprint 67 runtime verification](#baseline-sprint-67-93) — Acceptance date not recorded; historical evidence
- [Sprint 66 — Typed Confirmed-Import Recovery and Truthful Validation Guidance](#record-sprint-66) — Acceptance date not recorded; historical evidence
- [Sprint 66](#baseline-sprint-66-21) — Acceptance date not recorded; historical evidence
- [Sprint 65 — Shared Axis Bank-Account PDF Production Path](#record-sprint-65) — Acceptance date not recorded; historical evidence
- [Sprint 65](#baseline-sprint-65-19) — Acceptance date not recorded; historical evidence
- [Sprint 65 blocker reconciliation](#baseline-sprint-65-20) — Acceptance date not recorded; historical evidence
- [Sprint 64](#baseline-sprint-64-18) — Acceptance date not recorded; historical evidence
- [Sprint 63 — Immutable Source Snapshot and Exact Source-Byte Fingerprint Implementation](#record-sprint-63) — Acceptance date not recorded; historical evidence
- [Accepted Sprint 63 implementation ref](#baseline-sprint-63-8) — Acceptance date not recorded; historical evidence
- [Sprint 63](#baseline-sprint-63-17) — Acceptance date not recorded; historical evidence
- [Sprint 62 — ADR-041 Immutable Source Snapshot Architecture Contract](#record-sprint-62) — Acceptance date not recorded; historical evidence
- [Sprint 62](#baseline-sprint-62-16) — Acceptance date not recorded; historical evidence
- [Sprint 61](#baseline-sprint-61-72) — Acceptance date not recorded; historical evidence
- [Sprint 61 integrated verification](#baseline-sprint-61-73) — Acceptance date not recorded; historical evidence
- [Sprint 60](#baseline-sprint-60-71) — Acceptance date not recorded; historical evidence

### Historical context with no single acceptance date

- [Non-implementation commits after Sprint 53](#historical-baseline-6) — No single acceptance date assigned; original historical context
- [DBP-01 classification](#historical-baseline-11) — No single acceptance date assigned; original historical context
- [DBP-01 maintenance correction](#historical-baseline-28) — No single acceptance date assigned; original historical context
- [Latest focused Sprint 55 results](#historical-baseline-123) — No single acceptance date assigned; original historical context
- [Historical fixture/mechanics evidence — not current parser authority](#historical-fixture-mechanics) — No single acceptance date assigned; original historical context
- [DBP-01 — Developer Database Profiles (Debug Development Tooling)](#record-dbp01) — No single acceptance date assigned; original historical context
- [Earlier verified foundations](#record-earlier-foundations) — No single acceptance date assigned; original historical context

---

<a id="baseline-sprint-69-29"></a>

- **Sprint 69 repository interface:** `./script/validate.sh`, `./script/build_and_run.sh` and the Codex Run action are repository-verified local interfaces at the Sprint 69 baseline. The action invokes `./script/build_and_run.sh --verify`.

---

<a id="baseline-sprint-69-30"></a>

- **Sprint 69 acceptance-evidence classification:** The scripts, configuration and tests are repository-verifiable at the baseline; the build, test, process and runtime results recorded below are reported local execution evidence and were not re-executed by this documentation-only update.

---

<a id="record-sprint-68b"></a>

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

---

<a id="baseline-sprint-68b-27"></a>

- **Sprint 68B:** Test-only correction to Sprint 68's bounded persistence-error contract. The generic public wrapper message remains, while typed identity outcomes and durable-attempt authority remain preserved.

---

<a id="baseline-sprint-68a-26"></a>

- **Sprint 68A:** Corrected residual truthful UI from Sprint 68 by replacing the idle Validation Review's four fabricated Pending rows with one neutral empty state, removing the `Awaiting confirmation` footer pseudo-action, the static profile dropdown chevron, dashboard account-row chevrons and the account-detail favourite star. Real validation results, confirmation gating, retry and transaction actions, account editing, transaction search/toggles/category assignment, ordinary import and Developer Mode containment remain.

---

<a id="baseline-sprint-68a-100"></a>

- **Sprint 68A runtime verification:** A fresh signed Debug app used one isolated task-owned V9 namespace. The idle import review was neutral with no Pending rows or footer pseudo-action; the ordinary approved sanitized-fixture flow showed real validation, explicit confirmation gating, no dashboard-account chevron, no account-detail star, working display-name editing and real transaction search plus Credits/Debits controls. Task-owned namespace, build products and result bundles were moved recoverably to Trash.

---

<a id="baseline-sprint-68a-101"></a>

- **Sprint 68A TestPlan decision:** The complete `TestPlan.xctestplan` trigger did not fire: shared import-state logic changed only through presentation mapping; repository, hydration, Money, diagnostics and mutation code were unchanged; and focused tests showed no cross-suite interference. Sprint 69 remains the cycle-wide TestPlan gate.

---

<a id="baseline-sprint-68a-102"></a>

- **Sprint 68A migration and ADR impact:** Migration remains V9 and ADR-041 remains the latest accepted ADR; neither changed.

---

<a id="baseline-sprint-68-24"></a>

- **Sprint 68:** Removed future-module navigation, global and account placeholder search/filter chrome, disabled transaction ranges and inert row affordances, unsupported dashboard spending/trend presentation, the misleading Add Account action and unimplemented drag-and-drop copy. Repository-backed balances, native-currency transaction summaries, account editing, transaction search/toggles/category assignment, ordinary import workflow and Developer Mode containment remain.

---

<a id="baseline-sprint-68-25"></a>

- **Sprint 68 privacy boundary:** Production diagnostic emitters now use fixed messages, typed outcomes, enum values and counts; generic preparation/persistence failures fail closed to bounded presentation. Raw parser names, delimiter/encoding context and unrecognized account-identifier schemes do not reach Developer Console presentation, metadata or copied text.

---

<a id="baseline-sprint-68-97"></a>

- **Sprint 68 runtime verification:** A fresh signed Debug app used one empty task-owned V9 namespace. Accessibility inspection verified only the five ordinary destinations, accurate file-chooser wording, preserved text search and Credits/Debits controls, absence of the removed placeholder affordances, and Developer Console visibility only while Developer Mode was enabled. Console category filtering and Copy All showed bounded diagnostics. Task-owned namespace, build products and result bundles were moved recoverably to Trash.

---

<a id="baseline-sprint-68-98"></a>

- **Sprint 68 TestPlan decision:** The complete `TestPlan.xctestplan` trigger did not fire: Developer Console storage/output, shared persistence, Money, hydration, import and mutation semantics were unchanged, and focused tests showed no cross-suite interference. Sprint 69 remains the cycle-wide TestPlan gate.

---

<a id="record-sprint-67a"></a>

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

---

<a id="baseline-sprint-67a-23"></a>

- **Sprint 67A:** Corrected source-document presentation so only the exact durable `ImportedDocumentDTO` referenced by a transaction can authorize its displayed filename; import-session labels are not document authority

---

<a id="record-sprint-67"></a>

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
- The task-owned app process was stopped. The namespace, DerivedData and logs were moved recoverably to Trash. No private source, user database, generated result bundle or repository identifier was published in presentation.

#### Scope and exclusions

Sprint 67 changed the runtime transaction model, canonical hydrator, transaction-list presentation authority and view, focused hydration/presentation/relaunch tests, and this bounded state/queue reconciliation. It did not add source-document reopening, raw source retention, a document library, editable imported values, notes, tags, splits, provenance mutation, account relationship mutation, automatic categorization, new filters, analytics, dashboard work, diagnostics persistence, backup/restore, a migration or an ADR.

---

<a id="baseline-sprint-67-22"></a>

- **Sprint 67:** Preserved the durable imported-document relationship through canonical hydration and added one typed, privacy-safe transaction-detail projection for account, source-document and import-session provenance; missing legacy evidence remains neutral

---

<a id="baseline-sprint-67-93"></a>

- **Sprint 67 runtime verification:** one fresh namespaced V9 SQLite database imported the approved sanitized Axis NRE fixture through the ordinary Debug workflow; selected transaction detail showed authoritative account, institution, source document, import time, Money, direction, statement date, running balance, category and validation before and after quit/relaunch. The database held 1 account, 4 transactions, 1 document and 1 session, with all 4 transactions retaining account/document/session relationships. The task-owned namespace and build artifacts were moved recoverably to Trash.

---

<a id="record-sprint-66"></a>

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

---

<a id="baseline-sprint-66-21"></a>

- **Sprint 66:** Implemented typed confirmed-import recovery, privacy-safe route-specific guidance, wholly fresh preparation for eligible zero-commit outcomes and bounded canonical reconciliation without changing persistence architecture

---

<a id="record-sprint-65"></a>

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

**Current alignment — 2026-09-08:** this subsection records Sprint 65 historical evidence. The formerly committed sanitized PDFs have been removed from the active source/test tree. Historical recovery is not permission to execute them at any stage, including mechanics. Complete authentic originals are the current authority under ADR-046.

- The two committed sanitized NRO PDFs were regenerated clean-room from the supplied read-only originals. Their independent expected JSON remained byte-identical; PDFKit, geometry, pagination, selectable-text, unlocked, privacy and `qpdf --check` gates passed; all four rendered pages were visually inspected.
- The original PDFs remain historical source evidence for that Sprint 65 campaign. The regenerated sanitized PDFs were used for historical mechanics/privacy checks but are now retired from the active tree and may not execute; they never supplied original-source identity.
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
- Task-owned namespaces, result bundles, render evidence and build products were moved recoverably to Trash after acceptance. The private originals remain read-only and unchanged. No private source value, path, filename, database, screenshot or raw diagnostic was published in documentation, result bundles or products.

#### Scope

Sprint 65 changed only the approved production, test, fixture/manifest and state-document paths: `ContentView.swift`, `Services/ImportEngine.swift`, `Services/ImportPersistenceMapper.swift`, `Services/ImportPersistenceCoordinator.swift`, `Parsers/AxisBankAccountParser.swift`, `Parsers/StatementParserRegistry.swift`, `Normalizers/AxisBankAccountPDFNormalizer.swift`, `Parsers/AxisBankAccountPDFParser.swift`, `Parsers/AxisBankAccountSourceEvidence.swift`, `LedgerForge.xcodeproj/project.pbxproj`, the focused `LedgerForgeTests` files, the two regenerated sanitized PDF fixtures and their manifests, `PROJECT_STATE.md` and `FUTURE_WORK.MD`. No ADR, DTO, repository protocol, schema or migration changed; V9 remains current.

---

<a id="baseline-sprint-65-19"></a>

- **Sprint 65:** Implemented and accepted the exact shared `axis.bank-account.pdf@1` grammar through the ordinary import path. The selected NRE/NRO originals, regenerated sanitized fixtures and independent row-level financial baselines now establish the bounded production boundary; broader Axis PDF layouts remain unsupported.

---

<a id="baseline-sprint-65-20"></a>

- **Sprint 65 blocker reconciliation:** `BLOCK-PDF-LINEAGE-01`, `BLOCK-PDF-ORACLE-BINDING-02`, `UNCERTAINTY-PDF-DETERMINISM-03`, `UNCERTAINTY-PDF-SOURCE-CLASS-04` and `UNCERTAINTY-NRE-NRO-GRAMMAR-05` are closed only for the selected unlocked/selectable-text grammar and its account-neutral NRE/NRO family. They remain open for other layouts, OCR, password-protected documents and generic Axis PDF support.

---

<a id="baseline-sprint-64-18"></a>

- **Sprint 64:** Completed the approved read-only Axis bank-account PDF readiness discovery. Its bounded candidate was the two-source account-neutral Axis bank-account PDF v1 family represented by retained NRO evidence.

---

<a id="record-sprint-63"></a>

### Sprint 63 — Immutable Source Snapshot and Exact Source-Byte Fingerprint Implementation

**Ref**

`7e1345e3817d3c3e91c24f881b962a48279fd73b`

**Verified scope**

Sprint 63 implements the accepted Sprint 62 ADR-041 architecture contract. Preparation acquires one immutable app-owned `SourceContentSnapshot` containing the exact source bytes and `ledgerforge.source-bytes.sha256.v1` fingerprint. CSV retains `ledgerforge.raw-text.sha256.v1` as the duplicate authority and carries the source-byte fingerprint as a secondary fingerprint, with one authoritative fingerprint per document and SQLite/In-Memory Migration V9 provider/schema parity.

The retained snapshot is shared by extraction and fingerprinting, recomputed at confirmation, and consumed exactly once. Successful confirmation, rejection, failure, cancellation and preview supersession deterministically invalidate the snapshot. Acquisition and integrity failures produce bounded rejected outcomes, with no accepted financial residue. Historical source-byte reconstruction and durable source-byte storage are not performed. Production PDF support remains unsupported.

Independent acceptance verified 514 logical tests, 547 executions, 41 parameter runs across 8 tests, 64 suites, 0 failures and 0 skips; Debug, explicitly optimized whole-module Release and Debug analysis passed, with Release/privacy containment passing. No production PDF path was added.

---

<a id="baseline-sprint-63-8"></a>

- **Accepted Sprint 63 implementation ref:** `7e1345e3817d3c3e91c24f881b962a48279fd73b`

---

<a id="baseline-sprint-63-17"></a>

- **Sprint 63:** Implemented and independently accepted the immutable source-snapshot and exact source-byte fingerprint foundation

---

<a id="record-sprint-62"></a>

### Sprint 62 — ADR-041 Immutable Source Snapshot Architecture Contract

**Verified scope**

Sprint 62 accepted ADR-041 as the architecture contract later implemented by Sprint 63. It selected `ledgerforge.source-bytes.sha256.v1`, retained `ledgerforge.raw-text.sha256.v1` for existing CSV history, required transient snapshot binding through confirmation and preserved the boundary against historical reconstruction, durable source-byte storage and production PDF support.

---

<a id="baseline-sprint-62-16"></a>

- **Sprint 62:** Accepted the ADR-041 immutable source snapshot and exact source-byte fingerprint architecture contract; no production implementation was included in Sprint 62

---

<a id="baseline-sprint-61-72"></a>

- **Sprint 61:** Implemented privacy-safe durable account-outcome presentation and explicit eligible no-match account choice. FinancialIdentityResolver behavior is unchanged: parser-produced strong verified identifiers remain the sole identity authority, and eligible no-match cases require explicit Use Existing Account or Create New Account choice. No automatic account selection was introduced. Prospective successful durable account decisions are `matched_existing`, `user_selected_existing` and `created_new`; rejected outcomes include `account_choice_required`, `identifier_ownership_conflict`, `identity_ambiguity`, `identity_conflict`, `stale_account_choice` and `stale_provider_generation`. Historical `selected_existing` and `resolved_or_created` remain neutral and are not reinterpreted. One shared bounded presentation authority serves preparation, immediate result and Import History; hostile and unknown values fail closed to neutral unavailable presentation. Account IDs, candidate IDs, normalized identifiers, suffixes, filenames, paths, fingerprints, raw codes and unrestricted errors are excluded from account-outcome copy and accessibility text. SQLite/In-Memory parity and rejected-path zero accepted residue were verified. No schema or historical rewrite occurred.

---

<a id="baseline-sprint-61-73"></a>

- **Sprint 61 integrated verification:** 466 top-level tests, 498 executions, 39 dynamic-parameter runs, 0 failures and 0 skips; Debug build, explicitly optimized whole-module Release build and Debug analysis passed. Isolated runtime acceptance used the approved sanitized Axis fixture against one fresh namespaced canonical V8 SQLite database. Preview, explicit choice, confirmation, immediate result, live Import History, quit/relaunch and hydration were verified. Runtime persisted and rehydrated 1 account, 4 transactions and 1 durable attempt. The task-owned namespace was removed recoverably after acceptance. No private source or user financial database was used. Manual linking, unlinking, reassignment, repair, account merge/split and raw identifier display remain excluded.

---

<a id="baseline-sprint-60-71"></a>

- **Sprint 60:** Completed the read-only account-outcome explanation contract across the bounded import workflow; no schema or historical rewrite occurred.

## Historical context

These source snapshots retain earlier mixed or unnumbered evidence. Their original claims and internal order are preserved; no shared acceptance date or new sprint attribution is inferred.

---

<a id="historical-baseline-6"></a>

- **Non-implementation commits after Sprint 53:**
  - `bdb51b0ddcdde097e456a16bab7f0bf999fd595b` — roadmap update
  - `7ee20a909038d1088f830a6ea588311625f415e5` — planning reconciliation and tracked Xcode user-data removal
  - `de238d8abf5ee7dc7d1eb9cd13fab72803f2be28` — roadmap update after the discovery campaign
  - `a64c2d8d67e93631d8b0c32620ded72f389f252f`, `98b1fef111087d3b8c2b26f8c354c2147c6b2412` and `f50127ccb7ddf05641df1af7a14a93be2ea8b42e` — subsequent roadmap updates

---

<a id="historical-baseline-11"></a>

- **DBP-01 classification:** Accepted DEBUG-only developer tooling and development-database lifecycle implementation; it is not a production financial capability, production database-profile feature, numbered sprint, Sprint 65, schema migration or personal-v1 adoption

---

<a id="historical-baseline-28"></a>

- **DBP-01 maintenance correction:** Test lifecycle ownership was corrected so successful prepared imports have explicit terminal ownership and shared lifecycle-gate tests use target-wide isolation. It changed no production lifecycle behaviour, migration or ADR.

---

<a id="historical-baseline-123"></a>

- **Latest focused Sprint 55 results:** 41 Axis direction, fixture-oracle and confirmation-gate tests across 5 suites plus 64 adjacent event, validation, repository, atomicity and hydration tests across 6 suites, all with 0 failures and 0 unexpected skips

---

<a id="historical-fixture-mechanics"></a>

## Historical Fixture / Mechanics Evidence — Not Parser Acceptance Authority

**Current alignment — 2026-09-08:** the material below is retained only to explain historical test mechanics and earlier acceptance campaigns. Under ADR-046 and the all-stages user rule, fabricated financial-statement artifacts may not execute even as mechanics. Those artifacts have been retired from the active source/test tree. Only authentic corpus statements may exercise statement-dependent behavior; source-independent mechanics use nonfinancial values/files.

At the time of this historical campaign, direction evidence consisted of NRO clean-room transaction rows and a privacy-safe, non-reversible NRE semantic derivative. Independent exact-decimal oracles derived direction from physical column occupancy plus running-balance deltas and an independently supplied opening balance. They verified physical DR as debit, physical CR as credit, exact amount/delta agreement, source order, totals and complete reconciliation without consulting production parser output. This describes the former method, not current executable source authority.

The original private statements remain isolated, read-only evidence in their approved source location and are never included in published repository artifacts. The then-available two NRE and two NRO private CSV families independently provided 94 and 35 observable row-to-row balance deltas respectively, all conventional. The legacy 81-row/31-row NRE fixtures and synthetic partial-overlap pair lacked immutable transformation lineage and were not source truth; they are now retired and may not execute as mechanics or financial-source inputs.

### Axis bank-account evidence

Approved evidence includes:

- a historical privacy-safe source-derived Axis NRE CSV mechanics artifact, no longer parser regression authority under ADR-046;
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

Historically, invented self-contained mechanics fixtures covered the history PDF,
monthly PDF, byte-distinct monthly variant and legacy-XLS profiles. Those artifacts
may still exercise isolated mechanics, but ADR-046 prohibits using them as
reader/parser/source regression or acceptance evidence. Current reliability must
come from the complete authentic CBQ corpus through ordinary production.

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

---

<a id="record-dbp01"></a>

### DBP-01 — Developer Database Profiles (Debug Development Tooling)

**Ref**

`2d86f91dc46b9e88bcdfea65c88ddf671968b388`

**Verified scope**

DBP-01 is an accepted DEBUG-only developer-tooling and development-database lifecycle implementation. It provides Current Database, Persistent Debug Database, Temporary Session and Migration Sandbox with explicit lifecycle-owned activation; observer-atomic publication; lifecycle-activity blocking and stale-generation rejection; process-local Developer Mode that starts off on launch; an app-wide non-current warning; first-protected-action acknowledgement per non-current provider generation; and lifecycle-owned non-current reset and recreation. Current Database cannot be reset through profile controls.

All database-profile, warning, reset and acknowledgement machinery is absent from optimized Release. DBP-01 added no migration, changed no financial parser or durable financial semantics, established no production database-profile capability and did not declare personal-v1 adoption. Every current database remains disposable development/test state.

Integrated acceptance verified the complete TestPlan with 547 logical tests, 592 execution instances, 68 suites and 55 parameter runs, with zero failures, skips or expected failures. A fresh Debug build, Debug static analysis and isolated disposable runtime verification passed. No private financial source or personal database was used.

The final bounded Release-containment acceptance separately inspected seven authorized correction paths, passed 44 logical focused tests across 46 executions, passed an optimized whole-module `-O` arm64 Release build and passed direct binary `nm`, `strings` and bundled-resource inspection. No acknowledgement gate, Debug database-profile control, profile label, filename, namespace, sandbox control or fixture payload remained in Release. The complete TestPlan, static analysis and runtime walkthrough were not redundantly rerun after that final compile-boundary correction.

---

<a id="record-earlier-foundations"></a>

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
- ADR-044 durable card-liability/instrument architecture and exact Amex/CBQ/Axis card support.

Detailed implementation history remains in Git and accepted ADRs.

---
