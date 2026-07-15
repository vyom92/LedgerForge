**ChatGPT mode:** Codex  
**Model:** GPT-5.6 Terra  
**Reasoning:** High  
**Purpose:** Implement, validate, document, commit, and push LedgerForge Sprint 41’s bounded Axis UPI transaction-event duplicate-blocking contract governed by ADR-031.

# Repository

`vyom92/LedgerForge`

Use the local LedgerForge checkout and Xcode integration.

# Sprint

**Sprint 41 — Bounded Axis UPI Transaction-Event Duplicate Blocking**

# Objective

Implement ADR-031’s parser-verified, account-scoped Axis UPI transaction-event identity so an independently generated statement containing an already-owned eligible event is blocked in full before supported writes.

This sprint implements **FW-P0-01 only**.

Durable accepted event ownership is intrinsic to FW-P0-01. It is not a partial implementation of FW-P0-07.

# Mandatory preflight

Before editing production code:

1. Read the repository bootstrap in this order:
   1. `Project documents/.github/Context_Manifest.yaml`
   2. `AGENTS.md`
   3. `Project documents/Project_Guide.md`
   4. `Project documents/PROJECT_STATE.md`
   5. `Project documents/Implementation.md`
   6. `Project documents/FUTURE_WORK.MD`
   7. `Project documents/ADR.md`, especially ADR-019, ADR-030 and ADR-031
   8. Sprint 40 overlap fixture, expected specification and evidence tests
2. Verify:
   - branch is `main`;
   - working tree is clean;
   - local `HEAD` and `origin/main` equal `d6fadb27a16b498a805fe1e1c19bb15af27182d7`, unless a newer explicitly approved planning-only commit exists;
   - `Project documents/Implementation.md` records Sprint 41 as the sole ACTIVE sprint.
3. If `Implementation.md` still records Sprint 40:
   - do not implement;
   - do not modify `Implementation.md`;
   - report the planning-state mismatch and stop.
4. Do not modify the approved Sprint 40 CSV or expected JSON fixtures.
5. Do not use private original bank statements or require them for tests.

# Governing architecture

Preserve:

- offline-first operation;
- parser ownership of source-evidence verification;
- explicit confirmation before financial writes;
- deterministic financial identity resolution;
- immutable repository account identity;
- existing static same-process confirmation serialization;
- ADR-030 exact-content duplicate handling as the earlier authority;
- provider-owned atomic import-history persistence;
- SQLite and In-Memory provider parity;
- `RepositoryStoreHydrator` as the sole persistence-to-runtime boundary;
- the approved 81-row Axis financial baseline;
- whole-import rejection without silently dropping transactions.

Do not:

- reconstruct UPI evidence from narration outside `AxisBankAccountParser`;
- backfill existing transactions;
- introduce a general transaction-identity framework;
- add partial import, override, review or duplicate-management workflows;
- claim cross-process or external-writer safety.

# Approved implementation design

## 1. Parser-owned evidence

Define the bounded immutable domain value with the transaction model, preferably in:

`Models/Transaction.swift`

Use the semantic equivalent of:

```swift
struct AxisUPITransactionEventEvidence: Equatable, Sendable {
    enum Operation: String, Equatable, Sendable {
        case p2a
        case p2m
    }

    enum LedgerSubtype: String, Equatable, Sendable {
        case posting
        case creditAdjustment = "credit-adjustment"
    }

    let operation: Operation
    let reference: String
    let subtype: LedgerSubtype
}
```

Add an optional property to `Transaction`, defaulting to `nil`:

```swift
var verifiedAxisUPIEventEvidence: AxisUPITransactionEventEvidence? = nil
```

The value must contain only:

- exact supported operation;
- exact 12-digit ASCII reference;
- deterministic ledger subtype.

It must not contain:

- repository account ID;
- algorithm;
- digest;
- canonical payload;
- date;
- amount;
- balance;
- filename;
- path;
- narration;
- generated persistence metadata.

Existing transaction call sites must remain source-compatible.

## 2. Axis parser extraction

Modify:

`Parsers/AxisBankAccountParser.swift`

Extract evidence only from the parser’s exact source columns.

An eligible row must satisfy all of:

1. Exact structure beginning:

   ```text
   UPI/<operation>/<reference>/...
   ```

2. Operation is exactly:
   - `P2A`; or
   - `P2M`.

3. Reference consists of exactly 12 ASCII characters in `0...9`.

4. No trimming, punctuation removal, digit insertion/removal, Unicode digit conversion, fuzzy correction or weak fallback is used to rescue an invalid component.

5. Ledger subtype is derived only after the row has passed the exact accepted Axis UPI grammar:
   - debit source column populated and credit source column empty → `posting`;
   - credit source column populated and debit source column empty → `credit-adjustment`;
   - both populated or neither populated → no verified evidence.

This debit/credit mapping is authorised only inside the exact accepted Axis UPI grammar. Do not generalise it to other narrations, rails, institutions, refunds, reversals or arbitrary credit rows.

A malformed or unsupported row must retain its otherwise valid financial transaction with evidence set to `nil`.

The sanitized baseline’s symbolic adjustment row must remain ineligible. Do not alter it to manufacture a production fixture.

## 3. Canonical transaction-event identity

Create:

`Services/TransactionEventIdentity.swift`

Keep the service intentionally bounded to version 1.

Required constants:

```text
algorithm = ledgerforge.transaction-event.axis-upi-reference.v1
family = axis-upi
```

Create an internal canonical identity containing:

- originating transaction UUID;
- immutable repository account ID;
- algorithm identifier;
- lowercase hexadecimal SHA-256 digest.

Do not expose the reference or canonical payload from this value.

Canonical components, in exact order:

1. algorithm identifier;
2. immutable repository account ID;
3. `axis-upi`;
4. lowercase operation raw value;
5. exact 12 ASCII digits;
6. lowercase subtype raw value.

Serialize every component as:

```text
<decimal UTF-8 byte count>:<exact UTF-8 bytes>
```

Concatenate without separators or optional fields.

Validation must reject:

- empty account ID;
- unsupported operation;
- malformed reference;
- unsupported subtype;
- missing component;
- malformed algorithm or family.

The canonical payload may be exposed internally to focused tests through a narrow testable method, but it must never be:

- persisted;
- displayed;
- logged;
- interpolated into errors;
- returned through presentation results.

The digest must:

- be SHA-256;
- be lowercase hexadecimal;
- contain exactly 64 characters;
- be persisted paired with the algorithm;
- never be displayed or logged.

Provide deterministic incoming-batch evaluation that blocks repeated `(algorithm, digest)` values before repository lookup.

## 4. Persistence DTOs and ownership records

Modify:

- `Database/DTOs.swift`
- `Database/Repository.swift`
- `Database/Migrations.swift`
- `Database/SQLiteRepositoryProvider.swift`
- `Database/InMemoryRepositoryProvider.swift`

Create a dedicated ownership representation equivalent to:

```text
transaction_event_identities
```

Required durable fields:

- record ID;
- transaction ID;
- repository account ID;
- document ID;
- import-session ID;
- algorithm identifier;
- privacy-safe digest;
- creation timestamp.

Do not store:

- raw UPI reference;
- raw financial account identifier;
- canonical payload;
- operation;
- subtype;
- family;
- narration;
- source row;
- filename;
- path.

The repository account ID is an internal immutable repository identifier, not a raw bank-account identifier.

Add DTOs equivalent to:

- `TransactionEventIdentityDTO`
- `TransactionEventIdentityKeyDTO`
- `TransactionEventIdentityOwnerDTO`

Add accepted event records to `AtomicImportHistoryDTO`.

Add one batch lookup API to the existing import-history repository boundary. It must retrieve ownership for a set of algorithm-and-digest keys without exposing raw evidence.

Preserve placeholder and test-double conformance.

## 5. Migration V3

Add schema migration V3.

Create `transaction_event_identities` with:

```text
id                TEXT PRIMARY KEY
transaction_id    TEXT NOT NULL
account_id        TEXT NOT NULL
document_id       TEXT NOT NULL
import_session_id TEXT NOT NULL
algorithm         TEXT NOT NULL
digest            TEXT NOT NULL
created_at        DATETIME NOT NULL
```

Required constraints:

- unique `(algorithm, digest)`;
- unique `(transaction_id, algorithm)`;
- foreign keys to transaction, account, document and import session;
- indexes required for bounded account/import-session provenance queries.

Use deletion semantics that preserve durable duplicate ownership. Do not silently cascade-delete event ownership merely for convenience.

Register V3 through `allMigrations`.

Migration must:

- perform no backfill;
- preserve every existing transaction;
- leave the new table empty for existing databases;
- preserve existing fingerprints and histories;
- support repeated provider opening and provider recreation.

## 6. Repository invariants

SQLite and In-Memory providers must enforce equivalent behavior.

Required invariants:

1. One `(algorithm, digest)` has at most one owner.
2. One transaction has at most one identity for this algorithm.
3. Every event record references:
   - a transaction included in the same accepted import-history payload;
   - the same account ID as that transaction;
   - the same document ID;
   - the same import-session ID.
4. An incoming repeated canonical identity blocks the whole import.
5. Existing ownership on the selected account is an ordinary existing-event duplicate.
6. Ownership reporting another account is an ownership or repository-integrity conflict.
7. Missing or inconsistent linked provenance is a repository-integrity conflict.
8. No conflict silently omits one transaction.

A SQLite uniqueness constraint is a final defensive invariant only. Do not claim that it supplies complete cross-process import safety.

## 7. Confirmation-time authority

Modify:

- `Services/ImportPersistenceCoordinator.swift`
- `Services/ImportPersistenceMapper.swift`
- `Services/ImportEngine.swift`

Maintain this exact logical order inside the existing static confirmation lock:

```text
authoritative exact-content fingerprint lookup
→ deterministic financial identity resolution
→ validate explicit account decision
→ establish immutable existing or prospective account ID
→ canonicalize eligible parser evidence
→ reject incoming repeated canonical identities
→ authoritative batch event-ownership lookup
→ duplicate/conflict/integrity result: return before every supported write
→ map document, fingerprint, session, transactions and event records
→ existing account and identifier handling
→ provider-owned atomic import-history commit
→ successful commit only: request exactly one hydration
```

The prospective create-new account ID already exists before persistence and must be used for canonical identity.

No advisory transaction-event lookup is required during preparation.

Case behavior:

- no verified evidence → continue existing behavior without claiming overlap protection;
- mixed eligible and ineligible transactions → evaluate eligible identities and preserve every transaction;
- existing event → block whole statement;
- several matching events → block whole statement and return a bounded eligible-event count;
- incoming repeated identity → block whole statement;
- same reference with different subtype → distinct identity;
- same reference with different supported operation → distinct identity;
- uniqueness failure during atomic commit → roll back import history, perform bounded ownership classification if safe, return duplicate/conflict/integrity result, and do not hydrate;
- exact statement duplicate → preserve existing ADR-030 result and presentation unchanged.

Coordinator-detected event blocks must occur before:

- workspace creation;
- account creation;
- identifier attachment;
- document persistence;
- fingerprint persistence;
- import-session persistence;
- transaction persistence;
- event-identity persistence.

Do not redesign broader account or identifier atomicity.

## 8. Atomic import-history integration

SQLite:

- insert event ownership after its transaction rows exist;
- insert it before marking the import session successfully complete;
- retain the existing provider-owned SQL transaction;
- any event insertion or validation failure must roll back:
  - document;
  - fingerprint;
  - import session;
  - transactions;
  - event identities.

In-Memory:

- validate and construct all updated local copies first;
- publish no state until every invariant succeeds;
- include event identity state in the same all-or-nothing publication.

Do not write event ownership outside `commitImportHistory`.

If this cannot be achieved without event writes outside the atomic operation, stop.

## 9. Result semantics and presentation

Add a bounded event-block result, without changing exact-duplicate semantics.

Required categories:

- existing eligible transaction event;
- repeated incoming eligible evidence;
- ownership conflict;
- repository-integrity conflict.

An affected count refers to eligible verified event identities, not the total statement transaction count.

Update the import result propagation and the existing presentation surface in `ContentView.swift`.

Use bounded wording equivalent to:

- “Overlapping eligible transactions found. Statement blocked.”
- “Repeated verified transaction evidence found. Statement blocked.”
- “Transaction-event ownership conflict. No transaction history was written.”
- “Repository integrity conflict. No transaction history was written.”

Presentation may include:

- eligible-event count;
- no transactions imported;
- bounded Axis UPI version/family wording;
- privacy-safe prior account presentation only when existing infrastructure already provides it safely;
- explicit wording that unsupported transaction families were not evaluated.

Never display or log:

- raw UPI reference;
- raw financial identifier;
- digest;
- canonical payload;
- narration;
- source row;
- transaction-level private evidence.

Do not add:

- row controls;
- dismissal;
- override;
- partial import;
- review queue;
- duplicate-management screen.

Do not persist rejected attempts.

## 10. Required production scope

Expected production and project files:

- `Models/Transaction.swift`
- `Parsers/AxisBankAccountParser.swift`
- `Services/TransactionEventIdentity.swift` — new
- `Services/ImportPersistenceCoordinator.swift`
- `Services/ImportPersistenceMapper.swift`
- `Services/ImportEngine.swift`
- `Database/DTOs.swift`
- `Database/Repository.swift`
- `Database/Migrations.swift`
- `Database/SQLiteRepositoryProvider.swift`
- `Database/InMemoryRepositoryProvider.swift`
- `ContentView.swift`
- `LedgerForge.xcodeproj/project.pbxproj`

Use Xcode-safe project membership for the new production file.

Do not change excluded files unless compilation proves a narrowly necessary conformance update. Report every additional file and why it was unavoidable.

Do not modify:

- `FinancialDocument.swift` merely to add a separate evidence collection;
- `NormalizedRow.swift`;
- `StatementParser.swift`;
- `ImportValidator.swift`;
- `RepositoryStoreHydrator.swift`;
- runtime stores;
- ViewModels unrelated to existing import-result presentation;
- readers or normalizers;
- Sprint 40 fixtures;
- PDF code;
- unrelated UI.

## 11. Required tests

Extend:

- `LedgerForgeTests/FinancialDocumentTests.swift`
- `LedgerForgeTests/TransactionEventEvidenceFixtureTests.swift`
- `LedgerForgeTests/RepositoryContractTests.swift`
- `LedgerForgeTests/ImportRepositoryIntegrationTests.swift`
- `LedgerForgeTests/ConfirmationGatedImportWorkflowTests.swift`
- `LedgerForgeTests/ImportOutcomePresentationTests.swift`

Create:

- `LedgerForgeTests/TransactionEventIdentityTests.swift`
- `LedgerForgeTests/SQLiteMigrationTests.swift`

### Parser tests

Cover:

- P2A debit posting;
- P2M debit posting;
- exact credit-side adjustment under the accepted grammar;
- malformed reference;
- fewer or more than 12 digits;
- Unicode digits;
- punctuation;
- surrounding or inserted whitespace;
- missing component;
- unsupported operation;
- non-UPI narration;
- both debit and credit populated;
- neither debit nor credit populated;
- no weak fallback;
- valid transaction retained with `nil` evidence;
- evidence contains no repository account ID, digest or payload.

### Fixture tests

Verify without modifying fixtures:

- overlap fixture produces exactly 15 eligible posting identities;
- operation distribution is four P2A and eleven P2M;
- evidence stays associated with the originating transaction UUID;
- shared baseline/overlap events canonicalize equally for one fixed account scope;
- the 81-row baseline financial truth remains unchanged;
- the overlap fixture financial truth remains unchanged;
- the symbolic adjustment relationship remains represented only by expected specification and constructed tests.

Do not reuse broad `.isNumber` as production ASCII validation.

### Canonicalization tests

Cover:

- exact component ordering;
- length-prefixed serialization;
- UTF-8 byte count rather than character count;
- deterministic output;
- lowercase 64-character SHA-256;
- account changes digest;
- operation changes digest;
- reference changes digest;
- subtype changes digest;
- algorithm changes canonical output;
- posting and credit-adjustment remain distinct;
- malformed components rejected;
- canonical payload absent from descriptions and errors;
- digest absent from descriptions, diagnostics and presentation;
- incoming repeated identity detection.

### Repository and migration tests

Cover both providers:

- successful event persistence;
- batch lookup;
- provider parity;
- lookup survives SQLite recreation;
- V2 → V3 migration;
- no historical backfill;
- existing transactions preserved;
- empty migrated event table;
- uniqueness constraints;
- transaction/algorithm uniqueness;
- relationship validation;
- ownership conflict;
- repository-integrity conflict;
- rollback leaves no document, fingerprint, session, transaction or event residue;
- repeated provider opening is safe.

### Confirmed-import tests

Cover:

- baseline first, overlap second → overlap blocked;
- overlap first, baseline second → baseline blocked;
- statement with shared and new transactions → whole statement blocked;
- coordinator block causes no account or identifier mutation;
- no document, fingerprint, session, transaction or event record is written;
- no hydration on block;
- one hydration on success;
- rows without evidence continue normally;
- mixed eligible/ineligible rows import together when no eligible duplicate exists;
- different references import normally;
- posting and adjustment sharing one reference remain distinct;
- incoming internal duplicate blocks;
- conflicting ownership blocks;
- same-process competing confirmations cannot both persist one event;
- exact-content duplicate behavior remains unchanged;
- changed text with no repeated eligible event remains importable;
- privacy-safe diagnostics and presentation.

Use constructed values for malformed evidence, adjustment subtype, collisions, corruption and internal duplicates.

Do not require private originals.

## 12. Verification

Run through Xcode integration:

1. focused parser and canonicalization tests;
2. migration tests;
3. repository contract tests;
4. confirmed-import integration tests;
5. presentation tests;
6. all existing Axis and financial-document regressions;
7. exact-fingerprint and identity-resolution regressions;
8. complete configured Xcode-native unit and integration test plan;
9. Xcode source diagnostics;
10. static analysis;
11. clean Debug build.

Also run:

- `git diff --check`;
- conflict-marker scan;
- repository-scope review;
- privacy scan for raw references, identifiers, canonical payloads and digest logging.

Do not declare completion from focused tests alone.

## 13. Manual/runtime verification

Using a disposable clean SQLite database where supported:

1. Import the baseline and create its account.
2. Confirm 81 transactions persist.
3. Confirm exactly one hydration.
4. Import the overlap fixture.
5. Confirm the whole statement is blocked, including its one new row.
6. Confirm supported durable counts do not change.
7. Confirm no second hydration.
8. Recreate or relaunch the provider.
9. Repeat the overlap attempt and confirm durable blocking.
10. Repeat from a second clean database in reverse fixture order.
11. Verify exact-statement duplicate presentation remains unchanged.
12. Inspect UI and diagnostics for redaction and bounded coverage wording.

If a manual UI step cannot be executed through available Xcode integration, report it accurately as pending rather than claiming it passed.

## 14. Stop conditions

Stop without broadening scope if:

- exact P2A/P2M evidence cannot be classified deterministically;
- debit/credit subtype cannot be kept bounded to exact accepted Axis UPI grammar;
- evidence cannot remain associated through the transaction UUID;
- account scope is unavailable before the first supported mutation;
- event records cannot join atomic `commitImportHistory`;
- SQLite/In-Memory parity cannot be maintained;
- private source data is required;
- approved fixtures would need modification;
- broader account/identifier rollback becomes required for same-process correctness;
- cross-process safety becomes necessary;
- a general event framework becomes necessary;
- a new ADR-level decision is uncovered.

Report the exact blocker and stop.

## 15. Explicit exclusions

Do not implement:

- IMPS identity;
- NEFT identity;
- e-commerce or card identity;
- unstructured identity;
- reversal or refund subtype;
- historical event backfill;
- historical duplicate repair;
- partial import;
- row-level acceptance;
- override;
- duplicate-management UI;
- global import history;
- durable rejected-attempt history;
- statement-period continuity;
- transaction deletion, movement or reversal;
- account merge or split;
- identifier recovery;
- reversible-mutation infrastructure;
- broader unit-of-work architecture;
- cross-process or external-writer safety;
- cross-format identity;
- PDF identity;
- fuzzy matching;
- confidence scoring;
- unrelated parser or UI cleanup.

## 16. Documentation after successful verification

Do not modify `Project documents/Implementation.md`.

After every implementation, automated verification and available manual verification gate passes, update only the authorised handoff documentation:

- `Project documents/PROJECT_STATE.md`
  - record verified Sprint 41 behavior;
  - migration V3;
  - exact test/build results;
  - known limitations;
  - final commit and remote SHA.

- `Project documents/ADR.md`
  - status-only implementation note for ADR-031;
  - do not alter accepted semantics.

- `Project documents/FUTURE_WORK.MD`
  - remove completed FW-P0-01;
  - retain FW-P0-03, FW-P0-05, FW-P0-06, FW-P0-07, FW-P0-09 and FW-P1-25;
  - do not claim partial completion of FW-P0-07;
  - retain unsupported evidence families.

- `Project documents/Codex response.md`
  - replace with the complete verified implementation report.

Do not update the unrelated stale ADR-number summary in `Project_Guide.md` during this sprint.

## 17. Git handoff

Only after all applicable completion gates pass:

1. Review the complete diff.
2. Verify only approved or narrowly justified files changed.
3. Verify no private source content entered Git.
4. Commit on `main` with an accurate Sprint 41 implementation message.
5. Push `main`.
6. Verify the exact remote commit SHA.
7. Verify the working tree is clean.

Do not create a branch or pull request unless repository state requires it.

## 18. Final report

Return:

- preflight state;
- files changed;
- exact parser grammar implemented;
- exact subtype rule;
- canonical serialization ownership;
- schema V3 details;
- repository invariants;
- confirmation ordering;
- result and UI behavior;
- tests added and changed;
- exact test counts and outcomes;
- build and diagnostic outcomes;
- manual verification completed or pending;
- privacy scan;
- documentation changes;
- commit SHA;
- pushed remote SHA;
- clean-worktree verification;
- residual limitations.

Never claim:

- universal overlapping-statement protection;
- support for non-UPI families;
- historical coverage;
- cross-process safety;
- completion of FW-P0-07 or FW-P1-25.
