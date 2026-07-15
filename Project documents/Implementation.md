# ======= ACTIVE SPRINT =======

## Sprint 40 — Transaction-Event Evidence Fixture and ADR Preparation

### Status

Evidence and architecture preparation complete; no production transaction-event implementation

---

## Objective

Use two independently generated original Axis Bank CSV exports to determine whether genuine overlapping-statement evidence supports a strong, deterministic and versioned transaction-event identity contract.

Sprint 40 is limited to source-evidence verification, one privacy-safe overlapping fixture, its expected specification, narrow fixture tests, ADR-031 and verified documentation handoff. It does not implement transaction-level duplicate detection.

---

## Verified External Inputs

Two owner-supplied original Axis CSV exports were inspected only at external, non-repository locations.

- Both files were readable and retained the original Axis export structure.
- Their private structured full account identifiers matched exactly after whitespace normalization.
- The baseline declared 03 January through 03 July 2026; the later export declared 16 April through 16 July 2026.
- The baseline contained 81 valid transaction rows observed from 09 January through 02 July 2026.
- The later export contained 31 valid transaction rows observed from 16 April through 04 July 2026.
- Thirty complete original transaction rows were shared exactly and remained in the same ledger sequence.
- Fifty-one rows occurred only in the baseline and one valid event occurred only in the later export.
- The files were not byte-identical, reordered copies, subsets or exact re-downloads of one statement period.

No private identifier, narration, counterparty, UPI handle, complete reference or source digest is recorded here.

---

## Source-Gate Findings

| Check | Finding |
|---|---|
| Both original files accessible | Pass |
| Axis CSV structures valid | Pass |
| Files independently generated | Pass |
| Same structured full account identifier | Yes |
| Baseline declared period | 03 January–03 July 2026 |
| Later declared period | 16 April–16 July 2026 |
| Genuine overlapping period | 16 April–03 July 2026 |
| Baseline valid transaction count | 81 |
| Later valid transaction count | 31 |
| Complete original rows shared | 30 |
| Rows unique to baseline | 51 |
| Rows unique to later statement | 1 |
| Shared source evidence stable | Yes; complete shared rows and eligible rail references were unchanged |
| Candidate reference families | UPI, IMPS, NEFT, e-commerce and unstructured evidence examined |
| Legitimate-repeat separation demonstrated | Yes; recurring source patterns retained distinct eligible UPI references |
| Posting/adjustment/reversal reuse observed | One UPI token was reused by distinct posting and credit-adjustment rows; no source-backed reversal or refund example was present |
| Deterministic sanitization feasible | Yes, with symbolic expected-specification representation for the frozen baseline's pre-existing adjustment-token anonymization limitation |
| Evidence gate | Pass |

---

## Approved Repository Scope

Changes are limited to:

- one sanitized Axis CSV fixture derived from the later export;
- one privacy-safe expected specification;
- narrowly scoped fixture-validation tests;
- ADR-031;
- this ACTIVE Sprint 40 contract;
- the `FW-P0-01` entry only;
- verified `PROJECT_STATE.md` and `Codex response.md` handoff updates.

The file-system-synchronized test target supplies fixture and test membership automatically. No Xcode project-file change is required.

---

## Privacy Controls

- Original exports remain outside Git and are never modified.
- Full account identifiers, customer identifiers, names, addresses, contact information, UPI handles, card details, counterparties, cheque numbers, complete narrations and complete references must not enter committed material.
- No sanitization lookup table may be committed.
- Shared rows in the later fixture reuse the approved baseline's existing fictional values exactly.
- Distinct original values remain distinct in the sanitized derivative.
- The one later-only row uses new fictional instrument and narration values.
- Dates, amounts, debit/credit direction, balances, ordering, SOL structure and account relationship remain unchanged.
- Privacy verification must compare the external originals and committed derivative without logging private values.

---

## Deterministic Sanitization Procedure

1. Pair original baseline rows with the byte-frozen sanitized baseline by exact row order and unchanged financial columns.
2. Pair the 30 complete shared original rows across the two original exports.
3. Reuse the corresponding sanitized baseline row for every shared row in the new derivative.
4. Reuse the sanitized baseline's fictional account and customer metadata while changing only the declared period.
5. Assign new fictional values to the later-only instrument and narration while preserving all financial fields.
6. Preserve shared reference equality and distinct-reference inequality for every row represented in both fixtures.
7. Record the privately verified posting/credit-adjustment token reuse symbolically because the approved baseline is byte-frozen and its earlier anonymization did not preserve that original token equality.
8. Remove any temporary private correspondence after verification; never track it.

---

## Evidence-Family Evaluation

### Accepted bounded family

Axis UPI source evidence supports ADR-031's bounded contract:

- 15 UPI events were shared exactly across the independent exports.
- The parser-recognizable 12-digit UPI reference component remained unchanged with no formatting variation.
- Recurring transaction patterns remained distinct through different UPI references.
- Fifty baseline UPI rows contained 49 unique references because one source token was reused by a posting and a credit-adjustment row.
- The accepted identity must therefore be scoped to the resolver-selected account and include deterministic UPI operation and source subtype. A token alone is not an event identity.

### Not accepted

- IMPS: stable in seven shared events, but broader subtype and reuse evidence is insufficient for approval.
- NEFT: stable in two shared events, but multiple observed token forms require a separate family contract.
- E-commerce/card: no eligible strong source reference was established.
- Unstructured rows: no eligible strong source reference was established.
- Reversal and refund: no genuine source example was present; no semantics may be manufactured.

Weak date, amount, direction, narration, balance, row position, filename, path, institution label, display name, UUID, fuzzy similarity or confidence values remain ineligible.

---

## ADR-031 Decision

ADR-031 is Accepted for the bounded Axis UPI evidence family only, using proposed algorithm identifier:

`ledgerforge.transaction-event.axis-upi-reference.v1`

It defines parser ownership, account scope, exact deterministic normalization, source subtype separation, privacy-safe digest representation, missing and malformed behavior, collision handling, authoritative pre-write timing and compatibility with ADR-019 and ADR-030.

The ADR prepares a later production sprint. Sprint 40 implements none of its production flow.

---

## Automated Validation

Required checks:

- new Sprint 40 fixture-evidence tests;
- Axis CSV regression tests;
- `FinancialDocumentTests`;
- institution-detection tests;
- parser-selection tests;
- PDF reader, extraction and classification regressions;
- all existing fixture-integrity tests;
- complete configured Xcode-native unit and integration test plan;
- Xcode source diagnostics;
- static analysis;
- clean Debug build;
- `git diff --check`;
- conflict-marker and repository-scope checks.

The existing Axis baseline must remain byte-for-byte unchanged and retain 81 transactions, existing totals, balances, parser selection, validation and verified financial identifier behavior.

Generic UI tests remain governed by existing repository policy.

---

## Manual Verification

Verify:

1. Both external files are genuine independent Axis exports.
2. Their structured full account identifiers match privately.
3. Their declared periods overlap.
4. Thirty complete original rows are shared and one later event is new.
5. Shared UPI evidence remains stable before sanitization.
6. Recurring patterns retain distinct references.
7. Posting and credit-adjustment token reuse is recorded as distinct subtype-scoped events.
8. Shared sanitized rows equal their approved baseline counterparts.
9. The later-only event remains financially unchanged but privately anonymized.
10. Neither original source nor a private mapping is tracked.
11. The approved baseline remains byte-for-byte unchanged.
12. No production Swift, repository, schema or migration file changes.
13. ADR-031 states only what the evidence supports.

---

## Stop Conditions

Stop without broadening scope if:

- either source becomes unavailable or cannot be verified;
- account equality, independence, overlap, repeated events or the later-only event cannot be established;
- source-reference stability or deterministic sanitization fails;
- a candidate identity represents multiple legitimate same-subtype events;
- account scope or source subtype cannot be defined deterministically;
- weak financial or presentation fields are required to rescue identity;
- private source material or a mapping would need to enter Git;
- production Swift, repository API, schema, migration, PDF production support, partial import, review, override, repair or broader atomicity becomes necessary;
- ADR-019, ADR-030 or the approved 81-row baseline would need to change.

---

## Explicit Exclusions

Sprint 40 does not implement transaction-event extraction, event persistence, repository lookup, duplicate blocking, partial import, candidate review, override, history repair, statement continuity, audit UI, mutation infrastructure, transaction deletion or movement, account merge or split, identifier backfill, schema migration, broader atomicity, cross-process guarantees, PDF event identity, cross-format identity, fuzzy matching, confidence scoring, new institutions, financial calculation changes or unrelated UI work.

---

## Completion Gate

Sprint 40 is complete only when:

- the source gate and privacy inspection pass;
- the original exports remain outside Git;
- the approved baseline remains byte-for-byte unchanged;
- the sanitized fixture, expected specification and narrow tests are present;
- ADR-031 records the bounded evidence-supported decision;
- `FW-P0-01` remains open for production implementation;
- documentation records verified facts only;
- diagnostics, analysis, build, focused tests and complete configured tests pass;
- diff, conflict and repository-scope checks pass;
- no production Swift, schema or project file changes occur.

---

## Git Handoff

After every completion gate passes:

1. Review the complete diff and privacy scan.
2. Verify only approved fixture, test and documentation files changed.
3. Verify neither original export nor any mapping is tracked.
4. Commit with an accurate Sprint 40 evidence-preparation message.
5. Push `main` using the established workflow.
6. Verify the exact remote commit.
7. Report source-gate facts, sanitized fixture files, ADR status, validation totals, commit SHA, remote verification and remaining evidence limitations.

Do not claim transaction-level duplicate prevention has been implemented.
