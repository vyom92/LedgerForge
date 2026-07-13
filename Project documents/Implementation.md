# ======= ACTIVE SPRINT =======

## Sprint 36 — Verified Account Resolution & Identity Seeding

### Status

🟢 Ready for Implementation

---

## Objective

Integrate parser-produced verified financial identifiers into production import persistence so LedgerForge can:

1. Reuse an existing repository account when identity resolves uniquely.
2. Create and seed a new repository account when no match exists.
3. Reject ambiguous or conflicting identity before any repository write.
4. Prevent runtime-store mutation when persistence does not succeed.
5. Remove filenames, institution labels and display metadata from durable account-ID construction.

Sprint 36 completes the first production path from:

```text
StatementParser
      ↓
FinancialDocument.financialIdentifiers
      ↓
FinancialIdentityResolver
      ↓
Repository account selection
      ↓
Confirmed persistence
```

---

## Governing Architecture

Sprint 36 implements existing decisions from:

- ADR-010 — Validation Before Persistence
- ADR-019 — Reference Fixtures Define Financial Truth
- ADR-024 — Repository Hydration Boundary
- ADR-025 — Stable Financial Entity Identity
- ADR-026 — Structured Developer Diagnostics
- ADR-027 — Parser-Owned Financial Identifier Extraction
- ADR-028 — Bounded Parser Source Evidence

No new ADR is required.

Only parsers may create or verify `FinancialIdentifier` values.

Persistence coordination may consume parser-produced identifiers to select a repository account, but it must never derive identifiers, upgrade evidence, interpret source fragments, or use presentation metadata as identity.

---

## Approved Production Flow

```text
Passed validation
      ↓
FinancialIdentityResolver.resolve(
    workspaceId,
    financialDocument.financialIdentifiers
)
      ↓
┌──────────────────────────────────────────────┐
│ resolved(existingAccountId)                  │
│   → verify existing account                  │
│   → preserve existing account unchanged      │
│   → persist against existing account ID      │
│                                              │
│ noMatch                                      │
│   → generate opaque import-scoped account ID │
│   → create account                           │
│   → attach verified strong identifiers       │
│   → persist against new account ID           │
│                                              │
│ ambiguous / conflict                         │
│   → throw before every repository write      │
│   → do not guess                             │
└──────────────────────────────────────────────┘
      ↓
Successful persistence result
      ↓
Runtime-store mutation and hydration
```

Validation must remain before resolution.

Runtime mutation must occur only after persistence succeeds.

---

## Workspace Ownership

`ImportPersistenceMapper` remains the single owner of the configured persistence workspace ID.

Expose that value as an internal read-only property.

The coordinator must use the mapper-owned workspace ID for:

- resolver lookup
- workspace retrieval
- account validation
- payload mapping
- identifier attachment

Do not introduce another independently defaulted workspace ID.

---

## Account-ID Selection

### Existing account

For:

```swift
.resolved(accountId: existingAccountId)
```

the coordinator must:

- Fetch the account using `accountRepo.account(id:)`.
- Confirm the account exists.
- Confirm it belongs to the mapper-owned workspace.
- Use its immutable repository ID.
- Skip `upsertAccount`.
- Preserve the stored `AccountDTO` exactly.
- Map every new transaction to the existing account ID.
- Perform no identifier attachment during Sprint 36.

A resolved import must not overwrite:

- account name
- institution
- account type
- currency
- description
- creation timestamp
- existing identifiers

### New account

For:

```swift
.noMatch
```

create one opaque import-scoped account ID.

The ID may use the import-session UUID because it is unique and unrelated to presentation metadata.

The ID must not contain or derive from:

- filename
- institution name
- display account name
- document description
- masked account values
- account suffixes
- source-context text

The account display name and description may continue to use institution and filename information because those remain presentation/source metadata rather than identity.

---

## Mapper Contract

Update `ImportPersistenceMapper` so payload mapping receives the selected account ID explicitly.

Conceptually:

```swift
payload(
    financialDocument: financialDocument,
    importSession: importSession,
    validation: validation,
    accountId: selectedAccountId
)
```

The mapper must:

- construct `AccountDTO.id` using the supplied ID
- pass that same ID to every `TransactionDTO`
- preserve current DTO metadata mapping
- preserve currency, dates, amounts, balances, direction and trust metadata
- expose its configured workspace ID read-only

The mapper must not:

- invoke repositories
- invoke the resolver
- decide whether an account matches
- inspect identifier strength or verification state
- derive identity from the filename

The coordinator selects identity.  
The mapper constructs DTOs.  
Apparently separation of responsibilities remains useful even after humans discover dependency injection.

---

## Resolver Outcome Handling

### Resolved

```text
resolved(existingAccountId)
```

Required behaviour:

- Validate the existing account and workspace relationship.
- Map the payload using `existingAccountId`.
- Do not upsert the workspace if it already exists.
- Do not upsert the account.
- Do not attach identifiers.
- Persist the import session and transactions against the existing account.

### No match

```text
noMatch
```

Required behaviour:

1. Generate a new opaque account ID.
2. Map the payload using that ID.
3. Read the workspace.
4. Create/upsert the workspace only when absent.
5. Create the new account.
6. Attach eligible parser identifiers.
7. Create the import session.
8. Replace transactions.
9. Complete the import session.

Eligible identifiers are only:

```text
strength == strong
verificationState == verified
```

Weak and unverified identifiers must neither resolve nor attach.

### Ambiguous

```text
ambiguous(candidates:)
```

Required behaviour:

- Throw a concise coordination error.
- Perform zero repository writes.
- Perform zero runtime-store mutation.
- Do not expose candidate identifiers.
- Do not select an account.

### Conflict

```text
conflict(candidates:)
```

Required behaviour:

- Throw a concise coordination error.
- Perform zero repository writes.
- Perform zero runtime-store mutation.
- Preserve every existing relationship.
- Do not guess between accounts.

---

## Workspace and Account Preservation

The coordinator must use read-before-create behaviour.

### Workspace

```text
workspaceRepo.workspace(id: workspaceId)
```

- Existing workspace: do not upsert.
- Missing workspace: create using the mapped candidate workspace.

### Account

- Resolved account: do not upsert.
- New no-match account: upsert once using its new opaque ID.

Sprint 36 must not call replacement-style upserts for existing workspace or account records.

---

## Identifier Attachment

Identifier attachment occurs only for a newly created `noMatch` account.

Order:

```text
new account creation
      ↓
verified strong identifier attachment
      ↓
import-session creation
      ↓
transaction persistence
```

Attachment must:

- preserve the parser-produced normalized value
- preserve kind
- preserve strength
- preserve verification state
- preserve provenance
- remain workspace-scoped
- use the existing repository conflict enforcement
- remain idempotent
- never log the unredacted value

Sprint 36 does not attach additional identifiers to an already resolved account.

That behaviour is deferred because it introduces identifier-backfill policy rather than basic account resolution.

---

## Runtime Commit Gating

Update `ImportEngine.commitPreparedImport` so runtime state changes only when persistence succeeds.

Required rule:

```text
persistenceResult.persisted == true
      ↓
DocumentStore / TransactionStore / AccountStore updates permitted
```

If persistence:

- throws
- returns `.skipped`
- is rejected because identity is ambiguous
- is rejected because identity conflicts

then runtime financial stores must remain unchanged.

The import must report failure through the existing result and diagnostics path.

No runtime-store type change is required.

---

## Partial-Write Contract

Sprint 36 accepts the repository’s existing sequential persistence model.

It does not introduce a cross-repository unit of work or global transaction.

Guaranteed zero-write cases:

- failed validation
- resolver ambiguity
- resolver conflict
- invalid resolved account or workspace relationship
- payload mapping failure

Later failures may retain repository records created by earlier successful operations according to existing behaviour.

Sprint 36 does not promise rollback across:

- workspace creation
- account creation
- identifier attachment
- import-session creation
- transaction persistence
- completion update

Cross-repository atomic persistence is separate future architecture work.

---

## Production Scope

Modify only:

```text
Services/ImportPersistenceCoordinator.swift
Services/ImportPersistenceMapper.swift
Services/ImportEngine.swift
```

No production modification is expected in:

```text
Services/IdentityResolver.swift
Models/FinancialDocument.swift
Database/Repository.swift
Database/DTOs.swift
Database/InMemoryRepositoryProvider.swift
Database/SQLiteRepositoryProvider.swift
Database/Migrations.swift
Parsers/
Readers/
Normalizers/
Stores/
ViewModels/
Views/
LedgerForge.xcodeproj
```

---

## Test Scope

Modify:

```text
LedgerForgeTests/ImportRepositoryIntegrationTests.swift
LedgerForgeTests/ConfirmationGatedImportWorkflowTests.swift
```

Run unchanged regression suites including:

```text
LedgerForgeTests/IdentityResolverTests.swift
LedgerForgeTests/AccountIdentifierRepositoryTests.swift
LedgerForgeTests/RepositoryContractTests.swift
LedgerForgeTests/RepositoryStoreHydratorTests.swift
LedgerForgeTests/CSVImportRegressionTests.swift
```

Do not create a new test target.

Do not change project membership unless compilation proves it unavoidable. Stop and report if required.

---

## Required Tests

### First Verified Import

For both in-memory and SQLite-backed integration:

- Resolver returns `noMatch`.
- Exactly one new account is created.
- The account ID does not contain the filename, institution name or display name.
- Exactly one verified strong identifier is attached.
- Every transaction references the new account ID.
- The import session references the expected workspace.
- Persistence succeeds.

### Later Import With Different Filename

- Seed or perform a first import with a verified Axis identifier.
- Import a second financial document carrying the same identifier but a different filename.
- Resolver returns the existing account ID.
- No second account is created.
- No second identifier is created.
- Every second-import transaction references the original account ID.
- The existing `AccountDTO` remains exactly unchanged.

### Mapper Account-ID Propagation

- A supplied account ID becomes `payload.account.id`.
- Every mapped transaction uses the same ID.
- Filename changes do not alter the selected account ID.

### Missing Identifier

- Empty identifier input returns `noMatch`.
- A new unseeded account is created under current unsupported-parser behaviour.
- No identifier is attached.
- No identifier is derived from metadata.

### Weak and Unverified Identifiers

- Verified weak identifiers do not resolve.
- Unverified strong identifiers do not resolve.
- Neither category is attached automatically.

### Ambiguous Identity

- The coordinator throws before mapping writes.
- Workspace count remains unchanged.
- Account count remains unchanged.
- Identifier count remains unchanged.
- Import-session count remains unchanged.
- Transaction count remains unchanged.
- Runtime stores remain unchanged.

### Conflicting Identity

- The coordinator throws before repository writes.
- Existing account and identifier relationships remain unchanged.
- No import session or transaction is created.
- Runtime stores remain unchanged.

### Validation Failure

- Failed validation returns `.skipped`.
- No account-identifier repository lookup occurs.
- No repository write occurs.
- No runtime mutation occurs.

### Persistence Failure Gating

- A persistence error after confirmation does not append documents, transactions or accounts to runtime stores.
- Existing runtime contents remain unchanged.

### Privacy

- Diagnostics contain no normalized financial identifier.
- Diagnostics contain no bounded source-fragment text.
- Ambiguity and conflict errors describe only the outcome category.

---

## Financial Regression Requirements

The approved Axis fixture must preserve:

- Axis parser selection
- institution attribution
- 81 INR transactions
- transaction ordering
- debit total
- credit total
- opening balance
- closing balance
- validation result
- read-only preview
- explicit confirmation requirement
- cancellation without persistence
- existing dashboard presentation
- repository hydration after successful import

Sprint 36 changes account selection and identity persistence only.

---

## Manual Runtime Verification

Using the approved Axis NRE CSV:

1. Launch the newly built application.
2. Confirm preparation still produces the normal read-only preview.
3. Confirm the preview contains 81 transactions and unchanged financial values.
4. Cancel once and verify no persistence or runtime mutation.
5. Prepare again and explicitly confirm.
6. Verify successful persistence.
7. Verify the dashboard and transaction views hydrate normally.
8. Relaunch the application.
9. Verify the account and transactions restore from SQLite.
10. Confirm no raw account identifier appears in UI or diagnostics.

Different-filename account reuse may be verified through automated integration tests when duplicate detection makes an identical manual re-import unsuitable.

---

## Explicit Exclusions

Do not:

- modify parser identifier extraction
- modify parser source context
- modify readers or normalizers
- derive identifiers in persistence
- use filename-derived account identity
- use institution names or display names as identity
- match or attach weak identifiers
- match or attach unverified identifiers
- attach new identifiers to resolved accounts
- redesign repository protocols
- modify DTO definitions
- modify SQLite schema or migrations
- introduce a repository unit-of-work abstraction
- promise global rollback
- redesign duplicate detection
- add account merge behaviour
- add account-selection UI
- add identity-conflict UI
- modify runtime-store types
- modify ViewModels or Views
- change financial calculations
- implement identifier extraction for another parser
- log raw identifiers or source fragments
- edit `Project documents/ADR.md`
- edit `Project documents/Implementation.md` during Codex implementation

---

## Acceptance Criteria

Sprint 36 is accepted only when:

- Production persistence invokes `FinancialIdentityResolver`.
- The mapper-owned workspace ID is used consistently.
- Only parser-produced verified strong identifiers participate.
- Filename-derived account-ID construction is removed.
- New candidate IDs are opaque and import-scoped.
- A first verified import creates one account and attaches its identifier.
- A later differently named import reuses the original account ID.
- Resolved workspace and account records are not upserted.
- Existing `AccountDTO` metadata remains unchanged.
- Identifier attachment occurs only for new no-match accounts.
- Identifier attachment remains idempotent.
- Weak and unverified identifiers neither resolve nor attach.
- Ambiguous and conflicting outcomes cause zero repository writes.
- Failed validation causes zero resolver lookup and zero writes.
- Persistence failure causes no runtime-store mutation.
- Every persisted transaction uses the selected account ID.
- No repository protocol, DTO, schema or migration changes.
- No parser, reader, normalizer, UI or runtime-store type changes.
- Existing Axis financial values remain identical.
- Focused integration tests pass for in-memory and SQLite providers.
- Existing identity and repository regression suites pass.
- Complete Xcode-native test plan passes.
- Xcode diagnostics pass.
- Xcode static analysis passes.
- Xcode clean build passes.
- `git diff --check` passes.
- Manual runtime verification passes.
- No raw financial identifier or source-fragment text is logged.
- Planning documents remain untouched during implementation.

---

## Stop Conditions

Stop implementation and report without expanding scope if:

- Identity resolution requires identifier derivation outside a parser.
- A filename, institution name, display name, masked value or suffix is required for matching.
- An existing account must be upserted to reuse it.
- Ambiguous or conflicting outcomes cannot be handled before writes.
- Runtime mutation cannot be gated on successful persistence.
- Repository protocols, DTOs, SQLite schema or migrations must change.
- Full atomic rollback becomes required.
- Identifier backfill onto resolved accounts becomes required.
- Concurrent import guarantees become required.
- Duplicate-detection redesign becomes necessary.
- Parser, reader, normalizer, UI or runtime-store type changes become necessary.
- Production files outside the approved surface are required.
- Xcode project membership must change.
- Planning documents require modification.

---

## Implementation Handoff

After all validation passes:

1. Review the final diff.
2. Confirm only approved production and test files changed.
3. Commit with:

```text
Implement Sprint 36 verified account resolution
```

4. Push to `origin/main`.
5. Verify the remote `main` commit.
6. Update only:

```text
Project documents/PROJECT_STATE.md
Project documents/Codex response.md
```

7. Record:

- exact files changed
- opaque account-ID behaviour
- existing-account reuse behaviour
- existing metadata preservation
- identifier-attachment behaviour
- ambiguous and conflict zero-write evidence
- runtime failure-gating evidence
- partial-write limitation
- exact test totals
- build result
- static-analysis result
- manual runtime result
- implementation commit hash
- remote verification
- current phase: awaiting Sprint 37 planning

8. Commit and push the documentation handoff separately.

Do not modify `Project documents/Implementation.md` during implementation or handoff.
