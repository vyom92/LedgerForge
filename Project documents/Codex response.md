# Sprint 40 Execution Report

## Outcome

Sprint 40 transaction-event evidence and architecture preparation completed successfully.

Two original owner-supplied Axis CSV exports were compared privately outside the repository. The evidence supports one bounded strong family: parser-owned, resolver-account-scoped Axis UPI reference identity with deterministic UPI operation and posting-versus-credit-adjustment subtype separation.

ADR-031 is Accepted for architecture preparation only. No production transaction-event extraction, persistence, lookup or duplicate blocking was implemented.

## Source-Evidence Gate

| Check | Finding |
|---|---|
| Both original files accessible | Pass |
| Axis CSV structures valid | Pass |
| Files independently generated | Pass |
| Same structured full account identifier | Yes; verified privately |
| Baseline declared period | 03 January–03 July 2026 |
| Later declared period | 16 April–16 July 2026 |
| Genuine overlapping period | 16 April–03 July 2026 |
| Baseline valid transaction count | 81 |
| Later valid transaction count | 31 |
| Complete original rows shared | 30 |
| Rows unique to baseline | 51 |
| Rows unique to later statement | 1 |
| Shared source evidence stable | Yes; complete rows, sequence and eligible rail references were unchanged |
| Candidate reference families | UPI, IMPS, NEFT, e-commerce and unstructured evidence examined |
| Legitimate-repeat separation demonstrated | Yes; recurring patterns retained distinct UPI references |
| Posting/adjustment/reversal reuse observed | One UPI token was reused by distinct posting and credit-adjustment rows; no genuine reversal or refund example was present |
| Deterministic sanitization feasible | Pass, with a symbolic expected-specification record for the frozen baseline's earlier adjustment-token anonymization limitation |
| Evidence gate | Pass |

The two original files were not byte-identical, reordered copies, row-removal subsets or exact exports of one period. Complete source correspondence, matching private account identity, shared references and balance sequence proved the 30 repeated ledger events. One later-only valid event proved the later export was independently extended.

## Evidence-Family Decision

### Accepted

Axis UPI reference evidence:

- 15 complete UPI rows were shared across both independent exports.
- Each retained the same structured 12-digit source reference with no formatting change.
- Recurring source patterns remained distinct through different references.
- The baseline contained 50 UPI rows and 49 unique references.
- One reference was reused across distinct posting and credit-adjustment rows, so token-only identity was rejected.

ADR-031 proposes `ledgerforge.transaction-event.axis-upi-reference.v1`, scoped by immutable resolver-selected account ID and including exact UPI operation, exact 12-digit reference and deterministic source subtype.

### Not accepted

- IMPS: seven stable shared references, but insufficient subtype and reuse evidence.
- NEFT: two stable shared references, but multiple observed formats require a separate contract.
- E-commerce/card and unstructured rows: no eligible strong reference established.
- Reversal and refund: no genuine source example available; no semantics manufactured.

Missing or malformed strong evidence is not proof that an event is new. The accepted family must not be presented as universal overlapping-statement protection.

## Sanitized Fixture

Added:

- `LedgerForgeTests/Fixtures/Axis/CSV/axis_bank_nre_account_statement_overlap.csv`
- `LedgerForgeTests/Fixtures/Axis/Expected/axis_bank_nre_account_statement_overlap.expected.json`
- `LedgerForgeTests/TransactionEventEvidenceFixtureTests.swift`

Sanitization method:

- reused the approved baseline's fictional account and customer metadata;
- reused the corresponding approved sanitized row exactly for every shared original row;
- changed only the declared period in the fictional header;
- assigned new fictional instrument and narration values to the one later-only row;
- preserved transaction dates, order, debit/credit direction, amounts, balances and SOL;
- recorded source relationships using privacy-safe symbolic labels;
- retained no private mapping.

The approved 81-row baseline fixture remains byte-for-byte unchanged.

The original private baseline proves one UPI reference reused by posting and credit-adjustment rows. The pre-existing frozen baseline anonymization did not preserve that token equality, so the new expected specification records the relationship symbolically without changing historical fixture truth.

## Privacy Verification

- Original external exports remain outside Git.
- No original full account metadata or candidate reference appears in the derivative.
- No complete long original narration appears in the derivative.
- No external source path appears in tracked Sprint 40 material.
- No private mapping file exists or is tracked.
- No original source file is tracked.

## Automated Validation

- New Sprint 40 evidence suite: 4 tests, 0 failures.
- Focused evidence and import regressions: 54 tests in 8 suites, 0 failures, 0 skipped.
- Complete configured unit/integration plan: 175 tests in 26 suites, 0 failures, 0 skipped.
- Generic `LedgerForgeUITests`: intentionally disabled under existing policy.
- Static analysis: passed.
- Clean Debug build: passed.
- Source diagnostics: passed; only the existing App Intents metadata-skip warning was emitted.
- JSON validity, fixture-integrity, privacy, `git diff --check`, conflict-marker and scope checks: passed.

## Repository Scope

No production Swift, parser, reader, normalizer, model, import engine, persistence coordinator, mapper, DTO, repository, provider, migration, hydrator, runtime store, ViewModel, View, asset or Xcode project file changed.

Documentation changes are limited to ADR-031, the ACTIVE Sprint 40 contract, the `FW-P0-01` entry and verified handoff documents.

## Git Handoff

- Evidence commit: `416fc884c888982f996b01256fb99b70bcae6c78` — Prepare Sprint 40 transaction-event evidence.
- Evidence commit pushed to `origin/main` and exact remote SHA verified.
- Documentation handoff is committed and pushed separately after this report records the verified evidence SHA.

## Future State

`FW-P0-01` remains open and is ready for bounded production implementation planning. A later sprint may define parser extraction, privacy-safe event representation, repository lookup and whole-import pre-write blocking for the accepted Axis UPI family only.

IMPS, NEFT, e-commerce, unstructured rows, reversals, refunds, historical backfill, partial import, review UI, schema changes, broader atomicity and cross-process guarantees remain future work.

Current phase: awaiting bounded Sprint 41 production implementation planning.
