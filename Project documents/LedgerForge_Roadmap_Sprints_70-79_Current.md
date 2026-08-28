# LedgerForge Roadmap: Sprints 70–79

**Status:** Current repository cycle roadmap  
**Refreshed:** 2026-08-28
**Supersedes:** dated/private Sprints 70–79 roadmap copies through 2026-08-03

## Control

- **Planning authority:** This file is the repository authority for Sprints 70–79 numbering, corrective suffixes, cycle status and next gates.
- **Execution authority:** None. A complete Chat-approved prompt authorizes each task.
- **Accepted production baseline:** Sprint 79 on `main` at implementation commit `9489f6b21c9d585d2d90f2ba4798a931590057f7`; the subsequent documentation-reconciliation commit is recorded by Git history.
- **Current migration baseline:** V16 accepted with Sprint 79.
- **Latest accepted ADR:** ADR-045 — Qatar Airways Salary Actuals and Current-Month Funding Planner; implemented and accepted with Sprint 79. ADR-044 remains the accepted card-domain authority.
- **Current active correction:** none. Sprint 79 was technically accepted on 2026-08-28.
- **Sprint 79:** **Accepted 2026-08-28.** Exact `qatar-airways.salary.pdf@1`, the dedicated Salary workspace/current-month funding planner and additive Migration V16 are accepted production state.
- **Standing method:** `LedgerForge_Standing_Execution_Harness_Guide.md`.
- **Post-cycle gate:** Sprint 80 remains reserved for Swift 6 migration-readiness analysis before investment implementation.

Repository/source evidence overrides stale wording in this roadmap. Explicit user decisions remain binding until superseded.

Do not treat active WIP as accepted production support.

---

## Authority and anti-drift gate

Before selecting, naming, prompting, reviewing or accepting a sprint:

1. exact current ref/worktree;
2. this roadmap;
3. standing execution harness;
4. `PROJECT_STATE.md`;
5. `FUTURE_WORK.MD`;
6. relevant accepted ADRs;
7. production code/tests where documents are insufficient;
8. local/private source evidence where required.

Classify material claims as verified, explicit user decision, reported only or inference.

### Corrective numbering

- `NA` = first bounded correction attributable to Sprint `N`;
- `NB` = another separately bounded correction attributable to Sprint `N`;
- later numbered sprints do not move;
- a blocker inside `NB` does not create `NC`;
- `NC` is justified only if `NB` itself ultimately fails the Sprint `N` outcome;
- unrelated P0 defects are not disguised as corrections to the preceding sprint.

---

## Cycle overview

| Sprint | Outcome | Current status |
|---|---|---|
| 70 | Source-evidence reconciliation / implementation matrix | Complete |
| 71 | Legacy XLS reader + exact Axis NRO XLS | Accepted |
| 72 | Exact HDFC NRE/NRO XLS | Accepted |
| 73 | Exact HDFC PDF + cross-format equivalence | Accepted; 73A test-only closure accepted |
| 74 | Exact CBQ current-account XLS | Accepted |
| 75 | Exact CBQ current-account PDFs + source lineage/equivalence | Accepted |
| 76 | Shared card domain + exact Amex PDF | Accepted |
| 76A | Multi-instrument/encrypted/semantic-source hardening | Accepted |
| 77 | Exact encrypted CBQ credit-card PDF v1/v2 | Accepted |
| 78 | Exact Axis credit-card PDF/XLSX support/equivalence | Failed |
| 78A | First bounded Sprint-78 correction | Failed |
| 78B | Bounded Sprint-78 correction that completed the outcome | **Accepted 2026-08-27** |
| 79 | Qatar Airways salary + current-month funding planner | **Accepted 2026-08-28** |

---

# Sprints 70–77 accepted summary

## Sprint 70

Planning/source-evidence reconciliation only. No production implementation.

## Sprint 71

Accepted native OLE2/BIFF8 reader and exact `axis.bank-account.xls@1`.

XLSX/OOXML and generic spreadsheet support remained excluded.

## Sprint 72

Accepted exact `hdfc.bank-account.xls@1` for the source-proven HDFC NRE/NRO family.

## Sprint 73 / 73A

Accepted exact `hdfc.bank-account.pdf@1`, Migration V10 and ADR-042 whole-statement cross-format equivalence. 73A corrected stale test expectations only.

## Sprint 74

Accepted exact `cbq.current-account.xls@1`.

## Sprint 75

Accepted exact CBQ current-account history/monthly PDF families and durable source-specific lineage/equivalence under ADR-043.

## Sprint 76

Accepted shared credit-card liability/instrument domain and exact Amex PDF support.

## Sprint 76A

Accepted ordered multi-instrument statement sections, encrypted PDF/password foundation, semantic-source grouping and Migration V13.

## Sprint 77

Accepted exact encrypted `cbq.credit-card.pdf@1` v1/v2 over the shared card domain.

Accepted baseline after Sprint 77:

- ADR-044 latest accepted ADR;
- Migration V14;
- exact Amex and CBQ encrypted card support only for their proven profiles;
- Axis card remains outside accepted production support until Sprint 78 succeeds.

---

# Sprint 78 — Exact Axis Credit-Card PDF/XLSX Support and Equivalence

## Outcome

Exact Axis credit-card App PDF, traditional PDF and XLSX support over the shared card-liability architecture with deterministic cross-format equivalence, durable provenance, zero fabricated instrument ownership and fail-closed encrypted-source handling.

Accepted production profiles are:

```text
axis.credit-card.pdf@1
axis.credit-card.xlsx@1
```

## Corrective history

- **Sprint 78:** failed.
- **Sprint 78A:** failed.
- **Sprint 78B:** accepted on 2026-08-27 and completes the Sprint 78 outcome.

Sprint 78B was not test-only. Chat authorized the production corrections required to achieve the Sprint 78 outcome while preserving unrelated work.

Technical acceptance and governance reconciliation for Sprint 78B are complete. Sprint 79 was subsequently implemented and technically accepted on 2026-08-28.

---

## Current authentic corpus

Authoritative active private corpus is Jan–Jul 2026.

Physical active files:

- 7 locked App PDFs;
- 7 unlocked App PDFs;
- 7 App XLSX files;
- 7 locked traditional PDFs;
- 7 unlocked traditional PDFs.

Total: **35 physical files**.

Logical representations:

- 7 App PDF statements;
- 7 XLSX statements;
- 7 traditional PDF statements.

Total: **21 logical representations**.

Archived/ignored material is excluded.

Older roadmap claims of only two Axis PDF/XLSX pairs, 143/154-only coverage, 13 logical sources or 9/2/2 format counts are superseded.

---

## Settled Axis source truth

### Monthly financial rows

| Month | Rows |
|---|---:|
| Jan | 89 |
| Feb | 95 |
| Mar | 56 |
| Apr | 178 |
| May | 143 |
| Jun | 154 |
| Jul | 81 |

Total per logical representation family: **796**.

### Financial identity

Cross-format equivalence uses the exact multiset with multiplicity of:

```text
financial date
+ CardLiabilityEffect
+ native currency
+ exact Money
```

Narration is not financial identity.

Physical source order is provenance within a source, not cross-format identity.

### Duplicate multiplicity

March:

- 56 rows;
- 55 unique neutral financial keys;
- exactly one key with multiplicity 2.

June:

- 154 rows;
- 153 unique keys;
- exactly one key with multiplicity 2.

No invented occurrence identifier is allowed for duplicate supporting occurrences.

### App PDF ↔ XLSX order/narration

For every Jan–Jul cycle, App PDF and XLSX must match exactly in source order for financial keys.

Narration must match in source order after only approved inert normalization:

- Unicode canonical normalization;
- NBSP → ordinary space;
- curly-apostrophe normalization where already justified;
- repeated-whitespace collapse;
- trim.

Traditional PDF order is not required to equal App/XLSX order.

### Chronology

App PDF and XLSX use source-proven `selectedStatementMonth`.

Do not infer statement day or period when not source-proven.

Do not derive cycle from filename, transaction count or financial matching.

### Active Loans

Axis App PDF/XLSX Active Loans Summary is excluded from Sprint-78 financial transactions and historical statement chronology.

It is later/download-time EMI metadata and remains future work.

---

## PDF authority

For the current App PDF family, the tagged transaction table is the authoritative production transaction carrier.

The prior positioned App-PDF financial reconstruction/veto is superseded and must not regain acceptance authority.

Traditional PDF may use the generic positioned-evidence path required by that exact layout.

The generic PDF reader remains source-format extraction only and must not contain Axis financial or credential-family policy.

---

## XLSX / OOXML authority

Sprint 78B uses a narrow deterministic OOXML reader with pinned/vendored ZIPFoundation and Foundation XML parsing.

Current exact Axis workbooks are one-sheet transaction workbooks.

The reader must:

- fail closed on unsupported package parts/relationships;
- accept only bounded known inert package metadata;
- parse known core/extended properties strictly;
- reject malformed XML, unsupported properties and hostile package structures;
- preserve ordinary sheet/shared-string/numeric semantics;
- perform no formula execution;
- make no generic XLSX support claim.

Release must contain no unapproved dynamic dependency.

---

## Axis card ownership

Current authentic sources do not prove per-row primary/add-on physical-card ownership.

Sprint 78B therefore requires:

- one explicit liability-account decision;
- zero fabricated Axis `CardInstrument` records;
- zero fabricated statement instrument sections;
- zero fake mask-derived strong identities;
- every accepted Axis financial row account-level unless a later source-proven outcome changes that architecture.

The primary/add-on physical-card distinction is not required for current product use.

Same institution/family never authorizes automatic account merging.

---

## Axis credential architecture

Explicit user-settled fact:

**App PDFs and traditional PDFs use two different legitimate passwords.**

A single `axis-bank` password applied to every PDF is invalid.

Accepted Sprint 78B architecture uses durable canonical credential scopes:

```text
axis-bank.credit-card.app-pdf
axis-bank.credit-card.traditional-pdf
```

Compatibility-only state:

```text
axis-bank
registered historical Axis legacy item(s)
```

Rules:

- uncredentialed read first;
- bounded deterministic remembered candidates;
- secure challenge only after remembered candidates fail;
- generic `PDFDocumentReader` remains credential-agnostic;
- App/traditional target is determined only after successful unlock and exact structural profile recognition;
- successful canonical-family remembered credential causes no Keychain write;
- compatibility-origin success may migrate/upsert only the proven family scope after parse + validation;
- challenge success upserts only the proven family scope after parse + validation;
- compatibility items remain untouched;
- one family rotation must never overwrite the other;
- no credential enters SQLite, financial evidence, fixtures, logs or private acceptance output.

This is an accepted Sprint 78B production architecture and is published by the 2026-08-27 ADR-015 alignment amendment.

---

## Persistence / migration

Accepted production migration baseline is V15.

Sprint 78B accepted the additive V15 migration required for the Axis semantic/equivalence state.

Rules:

- V1–V14 are immutable;
- no V16 is authorized;
- V15 remains minimal and source-proven;
- zero-section Axis semantic projections are representable;
- selected statement month and multiplicity-safe supporting-source evidence persist only as required by the accepted model;
- no speculative Axis identity/summary zoo;
- SQLite/In-Memory parity is required;
- rejection leaves zero accepted durable financial residue.

V15 is **accepted** as part of Sprint 78B. No V16 is authorized by this closure.

---

## Accepted private acceptance boundary

The accepted final private gate proved:

1. exact 35-file physical inventory;
2. exactly one locked + one unlocked App PDF per month;
3. exactly one XLSX per month;
4. exactly one locked + one unlocked traditional PDF per month;
5. locked/unlocked production-output equivalence;
6. 796 rows per logical representation family;
7. exact App/XLSX/traditional financial multisets with multiplicity;
8. March/June duplicate multiplicity;
9. exact App↔XLSX source order and narration;
10. source-proven selected month;
11. no Active-Loans transaction leakage;
12. May representative SQLite/In-Memory multi-source campaigns;
13. first source creates 143 canonical transactions;
14. later exact-equivalent sources create zero new canonical transactions;
15. one liability account, zero Axis instruments/sections;
16. SQLite checkpoint/close/reopen;
17. canonical hydration;
18. no private credential/path/financial listing in Git or durable logs.

The private automated gate must use the production credential seam and must not directly retrieve one raw Axis password or mutate real Keychain state to bootstrap itself.

An explicitly selected private acceptance run must fail if its private corpus is unavailable; it must not silently return green.

---

## Validation status and reuse rule

Earlier Sprint 78B iterations reported green focused/build/full-plan results before the dual-credential correction, including a complete 783-test plan. Those results are historical evidence only.

Because the correction changed shared credential storage/provider/coordinator/ImportEngine semantics, the final stable candidate had to rerun:

- focused credential/Axis/Amex/CBQ/parser/provider/hydration tests;
- authentic 35-file private gate;
- Debug build;
- optimized Release build;
- exactly one authoritative complete `TestPlan.xctestplan`.

No earlier green suite may substitute for those post-correction gates.

The final accepted candidate completed the required post-correction boundary: focused shared tests, the authentic 35-file Axis private gate, fresh Debug and optimized Release builds, and exactly one authoritative complete TestPlan. That TestPlan executed 804 tests: 799 passed, 5 external-private-context tests were intentionally skipped with visible reasons, and 0 failed.

---

## Sprint 78B acceptance closure

Completed on 2026-08-27:

1. Chat performed the technical acceptance review and accepted Sprint 78B.
2. ADR-015 and ADR-044 are reconciled for the accepted Axis credential, ownership and source-equivalence boundary.
3. `PROJECT_STATE.md`, this roadmap and `FUTURE_WORK.MD` are reconciled.
4. Sprint 79 was unblocked for Chat planning, approved on 2026-08-27, and subsequently implemented and accepted on 2026-08-28.

No Sprint 78C is created because Sprint 78B completed the Sprint 78 outcome.

---

# Sprint 79 — Qatar Airways Salary Domain and Current-Month Funding Planner

## Status

**Accepted and implemented on 2026-08-28. Product implementation commit: `9489f6b21c9d585d2d90f2ba4798a931590057f7`.**

## Outcome

Implement the exact Qatar Airways salary PDF family plus a dedicated Salary workspace that replaces the user's current manual monthly funding worksheet with deterministic, editable QAR/INR planning while keeping imported actuals, account snapshots, user assumptions and derived values visibly distinct.

Authoritative private discovery now covers the complete active `Originals/Salary` boundary and supersedes the earlier seven-document planning note:

- 20 active native-text, unlocked PDF sources;
- source-owned monthly salary/payslip documents;
- one source-explicit Adhoc Payment variant;
- one source-explicit Annual Discretionary Bonus variant;
- at least one financial month with more than one salary document;
- print date is separate from pay-period authority;
- exact source-byte identity remains duplicate authority.

Accepted Sprint 79 architecture:

```text
expected net QAR
= expected fixed earnings QAR
+ expected variable earnings QAR
- expected deductions QAR
```

- imported salary actuals are immutable durable source truth and are not bank transactions;
- source earning/deduction section membership and source order are preserved; imported lines are not invented as fixed/variable;
- monthly actual salary is derived from every accepted salary-domain source whose source-owned pay period belongs to that month;
- Qatar Airways is employer/source authority for this exact profile and must not be fabricated as a financial `Institution` merely to reuse bank/card routing;
- the existing unified source snapshot/fingerprint/reader/import-history pipeline is reused, but salary receives a typed payload/persistence branch rather than fabricated `FinancialDocument.transactions`;
- a dedicated `Salary` sidebar destination owns Salary History and This Month planning; Dashboard receives summary-only expected-this-month, planned-obligations/funding-position and available-for-investment values;
- one current-month funding plan is editable user state; explicit rollover seeds the new month from the previous editable plan and every carried value remains editable at any time;
- balance selection is account-driven and explicit: checked accounts contribute an editable planning balance, with provenance distinguishing carried, manual and explicitly refreshed account snapshots; a checked account with no balance makes affected outputs incomplete rather than zero, and the only eligible account is never auto-selected merely because it is unique;
- current Qatar planning uses the selected QAR account set, presently CBQ; current India planning may select Axis NRE, Axis NRO, HDFC NRE and HDFC NRO independently;
- current account balances are never silently treated as historical opening cash; refresh/capture is user-triggered and captured planning balances are not live-linked;
- India funding shortfall is calculated only after checked INR liquidity is considered; commitments may optionally target a funding account for routing math without creating transfers or transactions;
- salary-to-bank and card-to-bank matching remain explicit/manual only; no amount/date auto-match is authorized;
- transfer fee is editable QAR planning input, initially QAR 25; it contributes only when India funding shortfall is greater than zero, otherwise its effective contribution is QAR 0 while the configured value remains retained/editable;
- planning FX is a plan-local, explicit, dated, user-entered positive quote in `INR per 1 QAR`; Sprint 79 does not activate the dormant global `exchange_rates` domain; when India funding is required, missing/invalid FX makes QAR funding and investment-capacity outputs incomplete rather than zero;
- when INR commitments require QAR funding, the derived QAR principal rounds upward to the next QAR minor unit so the plan does not underfund the stated INR requirement;
- available-for-investment is a derived result after checked Qatar liquidity, expected salary, Qatar obligations, India funding shortfall and transfer fee; planned investment remains a separate editable user input;
- the manual Budget Analysis workflow is a product-behaviour reference only, not salary source truth or an acceptance oracle.

Sprint 79 accepts additive **Migration V16** for dedicated salary-actual and current-month funding-plan persistence. V16 is now the current accepted migration baseline; V1–V15 remain immutable historical migrations.

ADR-045 governs the accepted Sprint 79 salary/planning implementation. Broader budgeting, recurring-obligation detection, automated transfers, global FX/reporting-currency conversion, investment execution and generic payroll support remain outside Sprint 79.

## Sprint 79 acceptance closure

Accepted on 2026-08-28:

- implementation commit `9489f6b21c9d585d2d90f2ba4798a931590057f7` is published on `main`;
- exact `qatar-airways.salary.pdf@1` salary actuals and the dedicated current-month funding planner are production state under ADR-045;
- additive Migration V16 is accepted with SQLite/In-Memory parity and canonical hydration;
- the authentic Salary acceptance suite passed 9/9, including the complete 20-source private oracle gate;
- the authoritative complete TestPlan executed 819 tests: 814 passed, 5 intentionally skipped external/private-context tests, and 0 failed;
- the pre-publication privacy scan passed with no private-path or credential residue in the 30-path Sprint 79 implementation commit.

The separately diagnosed authentic July 2026 CBQ credit-card compatibility defect is classified `PRE_EXISTING_OR_EXTERNAL` relative to Sprint 79 and remains future work; it does not reopen Sprint 79.

---

# Sprint 80 gate

Sprint 80 remains reserved for Swift 6 migration-readiness analysis before investment implementation.

---

## Maintenance

When this roadmap changes:

- preserve accepted sprint numbering;
- distinguish accepted state from active WIP;
- record corrective suffixes explicitly;
- remove superseded source assumptions instead of leaving contradictory live claims;
- link detailed implementation truth to `PROJECT_STATE.md` and ADRs;
- never treat private-source filenames, credentials or transaction listings as roadmap content;
- reconcile this file at every sprint/corrective acceptance.
