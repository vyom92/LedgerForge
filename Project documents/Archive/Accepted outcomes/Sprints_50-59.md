# Accepted outcomes — Sprints 50-59

Historical collection, not current implementation or execution authority. [Current state](../../PROJECT_STATE.md) owns the snapshot. Ordering inherits [Guide rule F](../../Project_Guide.md#documentation-order): known acceptance dates descending, then recorded sequence or natural sprint ID descending as display order. Undated records follow; original evidence interiors are unchanged. A review/observation date is not assigned as an acceptance date. Repeated historical summaries preserve their own limitations and may describe superseded support, fixture policy or migration state. ADR-046 and current scope decisions control all new work.

For repeated records of one outcome, the original state record precedes roadmap detail, then snapshot excerpts in their original source sequence. This is a display tie-break, not a second acceptance chronology. Cross-cycle compiled snapshots and unnumbered records without one acceptance date are separate historical context, ordered by stable record key under Guide rule I. Their placement does not attribute every contained fact to this cycle.

## Index

- [Sprint 59 — Immutable Source Snapshot and Exact Source-Byte Fingerprint Authority](#record-sprint-59) — Acceptance date not recorded; historical evidence
- [Sprint 59](#baseline-sprint-59-15) — Acceptance date not recorded; historical evidence
- [Sprint 58A — Debug Fixture Run-Script Sandbox Repair](#record-sprint-58a) — Acceptance date not recorded; historical evidence
- [Sprint 58 — Deterministic Import Verification Workspace](#record-sprint-58) — Acceptance date not recorded; historical evidence
- [Sprint 58](#baseline-sprint-58-14) — Acceptance date not recorded; historical evidence
- [Sprint 58 duplicate acceptance](#baseline-sprint-58-81) — Acceptance date not recorded; historical evidence
- [Sprint 57A — Category Reconciliation Closure](#record-sprint-57a) — Acceptance date not recorded; historical evidence
- [Sprint 57A](#baseline-sprint-57a-13) — Acceptance date not recorded; historical evidence
- [Sprint 57 — Durable Categories and Manual Transaction Classification](#record-sprint-57) — Acceptance date not recorded; historical evidence
- [Sprint 57 categories](#baseline-sprint-57-84) — Acceptance date not recorded; historical evidence
- [Sprint 57 persistence](#baseline-sprint-57-85) — Acceptance date not recorded; historical evidence
- [Sprint 57 UI](#baseline-sprint-57-86) — Acceptance date not recorded; historical evidence
- [Sprint 57 exclusions](#baseline-sprint-57-87) — Acceptance date not recorded; historical evidence
- [Sprint 56 — Explicit Reviewed Partial-Overlap Import](#record-sprint-56) — Acceptance date not recorded; historical evidence
- [Sprint 56 persistence](#baseline-sprint-56-82) — Acceptance date not recorded; historical evidence
- [Sprint 56 test-host isolation](#baseline-sprint-56-128) — Acceptance date not recorded; historical evidence
- [Sprint 56 acceptance correction](#baseline-sprint-56-129) — Acceptance date not recorded; historical evidence
- [Sprint 56 runtime verification](#baseline-sprint-56-130) — Acceptance date not recorded; historical evidence
- [Sprint 55A](#baseline-sprint-55a-12) — Acceptance date not recorded; historical evidence
- [Sprint 55 — Axis Source-Direction Correction and Partial-Overlap Evidence Closure](#record-sprint-55) — Acceptance date not recorded; historical evidence
- [Sprint 55 acceptance closure](#baseline-sprint-55-124) — Acceptance date not recorded; historical evidence
- [Sprint 55 overlap-period oracle](#baseline-sprint-55-125) — Acceptance date not recorded; historical evidence
- [Sprint 54 — Durable Import-Outcome Presentation Exhaustiveness](#record-sprint-54) — Acceptance date not recorded; historical evidence
- [Sprint 53 — Axis Shared Bank-Account CSV Profile and NRO Identity Closure](#record-sprint-53) — Acceptance date not recorded; historical evidence
- [Sprint 52A — Trusted Hydration and Writer Boundary Closure](#record-sprint-52a) — Acceptance date not recorded; historical evidence
- [Sprint 52 — Trusted Statement Dates and Durable Source Provenance](#record-sprint-52) — Acceptance date not recorded; historical evidence
- [Sprint 51 — Fail-Closed Recognized Axis Evidence](#record-sprint-51) — Acceptance date not recorded; historical evidence
- [Sprint 50 — Provider-Owned Atomic Confirmed Import](#record-sprint-50) — Acceptance date not recorded; historical evidence

---

<a id="record-sprint-59"></a>

### Sprint 59 — Immutable Source Snapshot and Exact Source-Byte Fingerprint Authority

**Ref**

`b661472a58fc24144361322f1853b8001437a3eb`

**Verified scope**

Sprint 59 accepted ADR-041 as architecture only. `ledgerforge.source-bytes.sha256.v1` and one immutable app-owned `SourceContentSnapshot` are prospective requirements shared by extraction and fingerprinting through confirmation; neither is implemented. Existing `ledgerforge.raw-text.sha256.v1` history remains untouched, production PDF support remains unavailable, FW-P1-16 remains blocked and no migration was added.

---

<a id="baseline-sprint-59-15"></a>

- **Sprint 59:** Accepted ADR-041 as an architecture-only source-snapshot and exact source-byte fingerprint contract; implementation was intentionally deferred to a later increment

---

<a id="record-sprint-58a"></a>

### Sprint 58A — Debug Fixture Run-Script Sandbox Repair

**Verified scope**

Sprint 58A repaired the `Copy DEBUG approved fixtures` Run Script sandbox contract. The phase now validates and operates only on its two exact declared inputs and two exact declared outputs; directory-level recursive deletion was removed, and User Script Sandboxing remains enabled.

Two consecutive Debug builds using the same DerivedData passed with exactly the two approved fixture files present and matching their source SHA-256 values. Six focused Sprint 58 tests passed with zero failures or skips. Two consecutive optimized whole-module Release builds using the same DerivedData passed with no fixture file, fixture content or approved-fixture launcher payload present; Xcode's empty declared-output parent contained no payload. The canonical TestPlan passed 547 logical tests across 592 execution instances, 68 suites and 55 parameter runs with zero failures, skips or expected failures.

No source fixture, financial behavior, migration, DBP-01 behavior or production capability changed.

---

<a id="record-sprint-58"></a>

### Sprint 58 — Deterministic Import Verification Workspace

**Ref**

`4547083d4d81edc9b6bcd98c3a8e77ee1538e71a`

**Verified scope**

Sprint 58 added a DEBUG-only approved-fixture verification workspace that enters the ordinary URL-driven preparation and confirmation path. Release containment removes the fixture resources and excludes the workspace from Release behavior. The isolated exact-duplicate runtime check preserved accepted transactions, sessions, documents, fingerprints, account state, balance and hydrated presentation, adding only one durable rejected duplicate attempt. Its later bounded build-system correction is recorded as Sprint 58A below.

---

<a id="baseline-sprint-58-14"></a>

- **Sprint 58:** Deterministic Import Verification Workspace, complete at `4547083d4d81edc9b6bcd98c3a8e77ee1538e71a`; DEBUG-only ordinary-path verification with Release containment and an isolated exact-duplicate runtime check

---

<a id="baseline-sprint-58-81"></a>

- **Sprint 58 duplicate acceptance:** an isolated exact duplicate left accepted transactions, sessions, documents, fingerprints, account state, balance and hydrated presentation unchanged, adding only one durable rejected duplicate attempt

---

<a id="record-sprint-57a"></a>

### Sprint 57A — Category Reconciliation Closure

**Ref**

`251a547cb44712a789a9ad7b23a4eabca742900b`

**Verified scope**

Sprint 57A completed category reconciliation closure without a migration. Failure injection, blocked-mutation zero-write behavior, retry, provider-generation replacement and target-wide category-state cleanup preserve the immutable imported financial transaction boundary. The completion state is recorded as complete; no historical financial repair was performed.

---

<a id="baseline-sprint-57a-13"></a>

- **Sprint 57A:** Category Reconciliation Closure, complete at `251a547cb44712a789a9ad7b23a4eabca742900b`; no migration was added

---

<a id="record-sprint-57"></a>

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

---

<a id="baseline-sprint-57-84"></a>

- **Sprint 57 categories:** workspace-owned user categories and one optional current category assignment per trusted imported transaction are durable, hydrated, manually editable and additive metadata only

---

<a id="baseline-sprint-57-85"></a>

- **Sprint 57 persistence:** additive Migration V8, SQLite/In-Memory parity, provider-generation protection, canonical hydration, provider reconstruction and SQLite close/reopen verification are implemented

---

<a id="baseline-sprint-57-86"></a>

- **Sprint 57 UI:** Settings supports create, rename, archive, restore and permitted delete; transaction detail supports assign, change and clear, and transaction rows display the current category

---

<a id="baseline-sprint-57-87"></a>

- **Sprint 57 exclusions:** automatic categorization, rules, suggestions, bulk editing, merge, delete-with-replacement, budgeting, analytics, reports, filtering, tags, splits and import behavior changes remain unavailable

---

<a id="record-sprint-56"></a>

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

Historical Sprint 56 acceptance used the sanitized Sprint 55 fixture pair as an independent oracle for its then-bounded campaign. Under the 2026-09-01 ADR-046 alignment that fixture pair is not a current independent source oracle or parser reliability authority; the historical transaction/document/disposition results remain recorded as implementation history only.

No canonical app launch or ordinary Debug/Release container access is part of Sprint 56 acceptance. The protected V5 Debug database remains unresolved local-only recovery evidence.

---

<a id="baseline-sprint-56-82"></a>

- **Sprint 56 persistence:** Migration V7, immutable reviewed-plan digests, typed row dispositions, explicit attempt counts and strict hydration/relaunch reconstruction remain readable and validated for historical repository state, but no new partial session is authorized without lineage-backed overlap evidence

---

<a id="baseline-sprint-56-128"></a>

- **Sprint 56 test-host isolation:** `TestPlan.xctestplan` explicitly marks the app-hosted test process with `LEDGERFORGE_TEST_HOST=1`; `LedgerForgeApp` selects intentional test memory for that exact marker before resolving any default SQLite path, while unmarked Debug and Release launches retain normal persistence bootstrap

---

<a id="baseline-sprint-56-129"></a>

- **Sprint 56 acceptance correction:** strict hydration now cross-checks each partial session against exactly one committed partial attempt and its document, transaction, source, imported, recognized and blocked counts before replacing any runtime store

---

<a id="baseline-sprint-56-130"></a>

- **Sprint 56 runtime verification:** no canonical application launch was used; acceptance uses signed app-hosted tests with isolated providers and source/presentation verification

---

<a id="baseline-sprint-55a-12"></a>

- **Sprint 55A:** Axis Bank Source-Truth Restoration, ending at `f3154dbd13a340714179da7f972a6accdd3aca54`; parallel shared-runtime-store isolation remains Sprint 55 acceptance/test infrastructure

---

<a id="record-sprint-55"></a>

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

---

<a id="baseline-sprint-55-124"></a>

- **Sprint 55 acceptance closure:** the first completion attempt exposed cross-suite interference between tests mutating shared runtime singleton stores; a bounded test-only asynchronous exclusivity trait now coordinates only those global-state tests across Swift Testing suites, retains ownership across suspension and restores the shared provider generation, runtime financial/history stores, diagnostics and development activity state after success or failure

---

<a id="baseline-sprint-55-125"></a>

- **Sprint 55 overlap-period oracle:** retained only as a quarantined synthetic architecture regression; it verifies internal arithmetic and period parsing but cannot authorize production partial import because immutable source lineage is unavailable

---

<a id="record-sprint-54"></a>

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

---

<a id="record-sprint-53"></a>

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

---

<a id="record-sprint-52a"></a>

### Sprint 52A — Trusted Hydration and Writer Boundary Closure

Sprint 52A:

- made malformed trusted date-role, timezone, provenance and profile evidence fail hydration before runtime mutation;
- required providers to return actual durable profile ID/version;
- prohibited trusted profile defaults or reconstruction;
- rejected trusted DTOs through generic replacement;
- validated complete normalized source relationships inside confirmed import;
- verified provider-equivalent atomic rejection and zero accepted residue.

V6 remained unchanged.

---

<a id="record-sprint-52"></a>

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

---

<a id="record-sprint-51"></a>

### Sprint 51 — Fail-Closed Recognized Axis Evidence

Sprint 51:

- rejected malformed recognized Axis transaction dates;
- rejected malformed, unconstructable or conflicting structured account evidence inside `StatementParser`;
- stopped both failure families before preparation, duplicate lookup, identity review, confirmation or persistence;
- preserved supported valid rows and zero-value behavior.

No migration or ADR changed. No Developer Console filename-redaction behavior was integrated.

---

<a id="record-sprint-50"></a>

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
