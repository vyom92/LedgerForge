# ======= ACTIVE SPRINT =======

## Sprint 39 — Exact Statement Re-import Prevention

### Status

🟢 Ready for Implementation

This implementation must begin from the future planning-package commit containing this contract. No commit SHA is specified by planning.

---

## Objective

Prevent a validated and explicitly confirmed text statement whose versioned exact-content fingerprint has already completed a successful import from creating another import session or transaction set.

Present bounded prior-import provenance through the existing import-result experience when that information is recoverable.

Sprint 39 must preserve parser ownership, deterministic identity resolution, existing account decisions, validation semantics, financial calculations and the `RepositoryStoreHydrator` boundary.

---

## Governing Architecture

The required flow is:

```text
Reader-produced text
        ↓
Deterministic versioned fingerprint
        ↓
Parsing and validation
        ↓
Read-only advisory duplicate evaluation
        ↓
Existing explicit review and confirmation
        ↓
Same-process serialized authoritative duplicate recheck
        ↓
Existing identity resolution and account decision
        ↓
Atomic document/fingerprint/import-session/transaction commit
        ↓
Exactly one canonical hydration after new success
```

Duplicate rejection exits before supported persistence writes and performs no runtime-store mutation or hydration.

Fingerprint generation is generic import orchestration over reader-produced text. It does not move into readers, parsers, normalizers, identity resolution, Views, ViewModels or transaction heuristics.

---

## Exact Fingerprint Contract

The initial algorithm identifier is `ledgerforge.raw-text.sha256.v1`.

Its digest input is the exact UTF-8 byte sequence of `RawDocumentContent.text`, after successful document reading and before parsing, normalization or financial interpretation changes the content.

The fingerprint excludes:

- filename, source path, file dates and import date;
- institution labels, financial identifiers and account identity;
- parser selection, normalized rows, parsed transactions and balances;
- display metadata and generated UUIDs.

Renaming or moving identical content must not change its fingerprint. Any change to decoded text, including line endings or whitespace, may produce a different fingerprint under version 1.

Sprint 39 supports the production text-import path. Binary-data fingerprint semantics and cross-format semantic equivalence remain future work.

The fingerprint is immutable and is carried by `PreparedImport` through explicit confirmation.

### Prospective-only compatibility

Sprint 39 exact-import protection is prospective. Import sessions completed before Sprint 39 contain no durable Sprint 39 fingerprint. Existing documents, sessions, accounts, identifiers and transactions are not backfilled or heuristically fingerprinted.

The first post-Sprint 39 import of content that exists only in legacy un-fingerprinted history may be treated as a new import and register the fingerprint. Subsequent imports of that exact content are blocked. Filename, path, institution, account identity, balances, transaction sets, transaction counts, dates and existing import-session metadata must not be used to reconstruct a legacy fingerprint. Historical detection and repair remain future work.

### Database-wide fingerprint scope

Under the existing schema, exact-content fingerprint uniqueness is database-wide. Sprint 39 operates under the current single-workspace product model and must not claim workspace-scoped fingerprint uniqueness. Independent import of identical content into multiple workspaces is not defined by Sprint 39.

Supporting workspace-scoped behaviour requires a separately approved workspace-scoped schema decision and migration. No migration is authorized in Sprint 39. The digest remains solely a function of exact source text and must not be salted with workspace identity.

### Existing-schema field semantics

- `documents.sha256` stores the lowercase hexadecimal SHA-256 digest of the exact UTF-8 bytes of `RawDocumentContent.text`.
- `document_fingerprints.algorithm` stores `ledgerforge.raw-text.sha256.v1`.
- `document_fingerprints.fingerprint` stores the same lowercase hexadecimal digest.
- `document_fingerprints.fingerprint_data` is `nil` for Sprint 39.
- The document record and fingerprint record link to the same import session committed by the atomic import-history operation.
- Transaction DTOs produced by the commit use that document ID.
- No raw document text or full fingerprint is written to diagnostics or presentation.

---

## Advisory and Authoritative Duplicate Evaluation

After validation passes, preparation may perform a read-only duplicate lookup for presentation. Advisory evaluation:

- performs no writes;
- does not claim or reserve the fingerprint;
- is not confirmation-time authority;
- may display bounded prior-import provenance.

Immediately before any supported import-persistence write, the confirmed persistence boundary must:

1. Enter the same-process serialized import-confirmation boundary.
2. Recompute or verify the immutable prepared fingerprint contract.
3. Perform an authoritative durable duplicate lookup.
4. Reject an existing successful fingerprint before account, identifier, import-session or transaction writes begin.

The same-process serialized confirmation boundary begins before the authoritative duplicate lookup and remains held until duplicate rejection completes, or until account and identifier persistence plus the atomic import-history commit complete or fail. It must not be released after lookup and reacquired for persistence. Account and identifier persistence remains outside the narrower atomic import-history transaction while remaining inside the same-process serialized confirmation execution. Do not claim rollback of workspace, account or identifier writes.

Two identical confirmations within the running LedgerForge process must not both persist financial history. Cross-process, distributed and external-writer concurrency guarantees remain future work.

---

## Atomic Import-History Commit

A provider-owned operation must atomically commit these integrity-bearing records:

- document;
- document fingerprint;
- import session;
- imported transactions;
- successful import-session completion state.

SQLite must write these records in one database transaction. The in-memory provider must provide equivalent serialized all-or-nothing behaviour.

A failure inside this atomic operation must leave none of those records durable. The fingerprint becomes durable only as part of a successful import-history commit. Validation failure, cancellation and failed import-history commit leave no durable fingerprint.

Sprint 39 does not create a general unit-of-work across every repository operation. Existing workspace, account and identifier persistence remains governed by prior ADRs. Full atomicity covering workspace, account, identifier, document, session and transactions remains future work.

---

## Durable Duplicate Result

A durable fingerprint lookup may return bounded prior-import provenance:

- prior import-session ID internally;
- prior successful completion date;
- prior persisted transaction count;
- prior account ID internally;
- prior account display name when recoverable.

The fingerprint match remains authoritative even if optional presentation metadata cannot be reconstructed. Missing account presentation must not permit re-import.

A duplicate is a distinct, non-error integrity outcome presented as **Previously imported** or equivalent. When available, show the prior date, persisted transaction count and prior account display name, with the existing **View Account** action when the account remains available.

No new screen, import-history browser or duplicate-management workflow is authorized.

---

## Expected Production Scope

Authorize changes only where implementation evidence requires them within:

- `Services/ImportEngine.swift`;
- `Services/ImportPersistenceCoordinator.swift`;
- `Services/ImportPersistenceMapper.swift`, only for document linkage or commit-payload mapping;
- `Database/Repository.swift`;
- `Database/DTOs.swift`;
- `Database/SQLiteRepositoryProvider.swift`;
- `Database/InMemoryRepositoryProvider.swift`;
- `ContentView.swift`, only for bounded duplicate-result presentation;
- one small production fingerprint value/service file;
- Xcode project membership only if required for that approved new file.

No parser, reader, normalizer, runtime-store, ViewModel, hydrator or financial-calculation change is authorized.

If another file appears necessary, stop and report the conflict.

---

## Expected Test Scope

Approve only focused coverage in the existing test target:

- `LedgerForgeTests/ImportRepositoryIntegrationTests.swift`;
- `LedgerForgeTests/ConfirmationGatedImportWorkflowTests.swift`;
- `LedgerForgeTests/RepositoryContractTests.swift`;
- `LedgerForgeTests/DeveloperDiagnosticsTests.swift`, only if Sprint 39 diagnostics require focused privacy coverage.

Do not approve a new test file or test target. If the approved files cannot express required coverage cleanly, implementation must stop and report.

Require unchanged regression execution for:

- `LedgerForgeTests/CSVImportRegressionTests.swift`;
- `LedgerForgeTests/FinancialDocumentTests.swift`;
- the complete Xcode-native test plan.

---

## Required Behaviour

- Same content and same filename is blocked.
- Same content under a different filename or path is blocked.
- Genuinely changed text is not blocked by the old fingerprint.
- Durable detection survives provider recreation or application relaunch.
- Advisory duplicate evaluation remains write-free.
- Confirmation performs the authoritative duplicate recheck.
- Two same-process competing confirmations produce exactly one successful financial history.
- Duplicate rejection creates no new import-session or transaction rows.
- Under supported serialized execution, duplicate rejection occurs before account or identifier mutation.
- Failed atomic import-history commit leaves no document, fingerprint, session or transaction residue.
- Validation failure and cancellation leave no fingerprint.
- Duplicate outcome may display prior date, transaction count and account when recoverable.
- Missing optional provenance does not allow re-import.
- Duplicate rejection performs no hydration.
- New success performs exactly one forced hydration through `RepositoryStoreHydrator`.

### Option 3 and fallback rule

Option 3 — exact-import prevention with bounded prior-import provenance in the existing result presentation — is the required target.

Fallback to Option 2 is permitted only if prior-import provenance demonstrably requires a global import-session list API, new import-history navigation, a new ViewModel subsystem, runtime-store or hydrator changes, transaction-level matching, historical repair or unrelated schema work. If such a requirement appears, implement exact-import protection without optional provenance and report the fallback clearly. Do not silently broaden scope.

---

## Required Automated Tests

Require coverage for:

1. First approved Axis CSV import persists 81 transactions.
2. Reimporting the same contents is blocked.
3. Renaming the same contents remains blocked.
4. Durable detection survives provider recreation or application relaunch.
5. Prior completion date is returned correctly.
6. Prior transaction count is returned correctly.
7. Prior account presentation is returned when recoverable.
8. Missing prior account presentation does not permit re-import.
9. Duplicate rejection does not create a new session or transactions.
10. Duplicate rejection does not mutate account or identifier state under supported serialized execution.
11. Two same-process competing confirmations cannot both persist.
12. Failure during atomic import-history commit rolls back document, fingerprint, session and transactions.
13. Validation failure leaves no fingerprint.
14. Cancellation leaves no fingerprint.
15. Changed text can import normally.
16. Duplicate rejection performs no hydration.
17. New success performs one forced hydration.
18. In-memory and SQLite repository behaviour remain equivalent.
19. Existing Axis financial regression remains unchanged.
20. The complete Xcode-native test plan passes.

---

## Manual Verification

Use a disposable clean SQLite database for primary Sprint 39 acceptance. Preserve and do not modify the user’s existing database.

1. Start with the disposable clean database.
2. Import the approved Axis CSV and confirm 81 persisted transactions.
3. Reimport identical content under a different filename and verify rejection.
4. Confirm a visible **Previously imported** result and prior date, transaction count and account where available.
5. Confirm **View Account** selects by immutable repository account ID when the prior account remains available.
6. Confirm repository counts remain unchanged after rejection and no forced hydration occurs for the duplicate.
7. Quit and relaunch against the same disposable database and verify durable rejection.
8. Import genuinely changed text and verify normal persistence.
9. Separately verify that a legacy database containing un-fingerprinted sessions is not automatically backfilled or claimed as repaired; its first post-Sprint 39 import may be treated as new and register a fingerprint.
10. Confirm diagnostics expose neither source text nor full fingerprint.
11. Re-run the Axis financial baseline.

Remove or retain disposable verification files only outside Git. Do not use existing duplicated history as the primary acceptance database or as evidence that Sprint 39 repairs historical duplicates.

---

## Explicit Exclusions

Carry forward every ADR-030 non-goal. Also exclude:

- modification or cleanup of already duplicated 81-row history;
- duplicate-transaction review;
- delete or reverse operations;
- account cleanup;
- schema migration without separate approval;
- replacement of existing identity architecture;
- general cross-repository unit-of-work redesign.

---

## Stop Conditions

Stop and report if implementation requires:

- parser, reader or normalizer changes;
- financial heuristics or transaction-level matching;
- historical repair;
- a schema migration;
- a global import-history subsystem;
- runtime-store or hydrator redesign;
- full cross-repository atomicity;
- unsupported files outside the approved scope;
- a weaker lifecycle where fingerprints can remain after failed import-history persistence;
- claims of cross-process concurrency safety;
- changed financial baseline values.

---

## Completion Gate

Sprint 39 is complete only when:

- ADR-030 remains Accepted and is updated to record implementation in Sprint 39 only after implementation, automated validation, manual verification and Chat review succeed.
- the versioned exact-content fingerprint is generated from reader-produced text before parsing;
- advisory lookup is read-only and confirmation-time duplicate recheck is authoritative;
- same-process competing confirmations are serialized;
- the provider-owned import-history commit is atomic for document, fingerprint, session, transactions and successful completion state;
- duplicate rejection leaves no new supported persistence rows and performs no hydration;
- genuinely new success performs exactly one canonical hydration;
- bounded duplicate provenance and View Account presentation contain only approved information;
- no raw source, fingerprint or identifier values enter presentation or diagnostics;
- focused and unchanged regression tests pass;
- the complete Xcode-native test plan passes;
- diagnostics, static analysis, build, manual verification and diff checks pass;
- no unapproved source, test, schema, project or documentation changes are present.

---

## Implementation Handoff

After implementation validation passes, Codex must:

1. Review the complete diff.
2. Confirm only approved implementation and test files changed.
3. Run Xcode diagnostics and static analysis.
4. Run a clean build.
5. Run focused Sprint 39 tests and unchanged financial regressions.
6. Run the complete Xcode-native test plan.
7. Run `git diff --check` and conflict-marker checks.
8. Complete manual verification.
9. Update only the verified implementation handoff documents.
10. Record exact test totals, validation results, manual results and commit state.

Do not claim Sprint 39 implementation completion before all completion-gate requirements pass.
