# Sprint 32 Repository Planning Report

## Bootstrap Completed

- This report is code-verified against production sources and is not an approved sprint plan yet.
- Documents consulted for navigation and schema reference only (no assertions taken from them):
  - `Project documents/Project_Guide.md`
  - `Project documents/Database_v1_Architecture.md`

## Files Inspected

Exact repository paths inspected to establish the current identity baseline:

- `LedgerForge/Services/ImportPersistenceMapper.swift`
- `LedgerForge/Services/ImportPersistenceCoordinator.swift`
- `LedgerForge/ImportEngine.swift`
- `LedgerForge/Models/FinancialDocument.swift`
- `LedgerForge/RepositoryStoreHydrator.swift`
- `Database/Repository.swift`
- `Database/DTOs.swift`
- `Database/SQLiteRepositoryProvider.swift`
- `Database/Migrations.swift`
- Tests: `LedgerForgeTests/RepositoryContractTests.swift`

## Current Account Identity Flow

All statements in this section are directly supported by production source.

- Account persistence entry point
  - `DefaultImportPersistenceCoordinator.persistValidatedImport(financialDocument:importSession:validation:)` (file: `LedgerForge/Services/ImportPersistenceCoordinator.swift`) calls `ImportPersistenceMapper.payload(...)` and then performs repository writes via `WorkspaceRepository`, `AccountRepository`, `ImportSessionRepository`, and `TransactionRepository`.

- Where the durable account ID is created
  - `ImportPersistenceMapper.accountDTO(financialDocument:importSession:createdAtISO:)` (file: `LedgerForge/Services/ImportPersistenceMapper.swift`) constructs `AccountDTO` using:
    - Exact expression for `AccountDTO.id`:
      - `id: stableID(prefix: "account", components: [workspaceId, institutionName, importSession.fileName])`
    - `stableID(prefix:components:)` (private in `ImportPersistenceMapper`) lowercases, replaces non-alphanumerics with `-`, joins components with `-`, and prefixes with `account-`.

- What exact fields participate in the ID
  - `workspaceId` (mapper configuration),
  - `institutionName` (derived from `importSession.institution?.rawValue` or "Unknown"),
  - `importSession.fileName` (the imported filename string).

- Is the result deterministic?
  - Yes. For fixed `workspaceId`, `institutionName`, and `importSession.fileName`, `stableID` is deterministic.

- What happens on repeat imports?
  - If the same `workspaceId`, `institutionName` and the same `importSession.fileName` are used, the same `AccountDTO.id` is produced. `SQLiteAccountRepo.upsertAccount(_:)` (file: `Database/SQLiteRepositoryProvider.swift`) executes `INSERT OR REPLACE` into `accounts`, so the same ID reuses/updates the same row. If the filename changes for the same real-world account, the `AccountDTO.id` changes (because `importSession.fileName` participates in identity). There are no tests in the repository that currently verify these scenarios.

- Does `FinancialDocument` currently carry any reliable account identifier?
  - `LedgerForge/Models/FinancialDocument.swift` defines:
    - `struct FinancialDocument { let id: UUID; let sourceDocument: Document; let metadata: DocumentMetadata; let parserName: String; let transactions: [Transaction]; let selectionReasons: [String]; let createdAt: Date }`
  - It does not include any account identifier fields.

- Which current parsers populate those identifiers?
  - Production source shows `ImportEngine` selecting a parser via `StatementParserRegistry.shared.parser(...)` and calling `parser.parse(...)` to produce `FinancialDocument`, but no verified account identifiers flow into `FinancialDocument` in the provided code. Concrete parser implementations are not present in the inspected files; therefore, no claim is made about parser-populated verified identifiers.

- Are those values verified, partially masked, or merely parsed strings?
  - In the current persistence path, identity-related strings used for account creation are derived from `importSession` (institution label and filename) and display naming logic in `ImportPersistenceMapper.displayAccountName(...)`. No verified institutional identifiers (e.g., full IBAN, full institution-issued account ID) are present in `FinancialDocument` or used by the mapper.

### Explicit Answers (per required source verification)

- What exact expression creates `AccountDTO.id`?
  - `stableID(prefix: "account", components: [workspaceId, institutionName, importSession.fileName])` in `ImportPersistenceMapper.accountDTO(...)`.
- What exact fields participate?
  - `workspaceId`, `institutionName` (from `importSession.institution?.rawValue` or "Unknown"), `importSession.fileName`.
- Is the result deterministic?
  - Yes, for the same inputs.
- What happens on repeat imports?
  - Same inputs → same `AccountDTO.id` → `INSERT OR REPLACE` reuses the row; changed filename → different `id`.
- Does `FinancialDocument` currently carry any reliable account identifier?
  - No; the struct has no verified account identifier fields.
- Which current parsers populate those identifiers?
  - Not demonstrated by production source in inspected files.
- Are those values verified, partially masked, or merely parsed strings?
  - They are derived labels/strings (institution name, filename, display name), not verified identifiers.

## Existing Identity Models and Fields

- `AccountDTO` (file: `Database/DTOs.swift`)
  - Fields: `id`, `workspaceId`, `name`, `institutionId?`, `accountType?`, `nativeCurrency`, `description?`, `createdAtISO`.
  - No verified account identifier fields are present.

- `FinancialDocument` (file: `LedgerForge/Models/FinancialDocument.swift`)
  - Fields: `id`, `sourceDocument`, `metadata`, `parserName`, `transactions`, `selectionReasons`, `createdAt`.
  - No verified identifier fields.

- Runtime display strings related to identity
  - `RepositoryStoreHydrator.transaction(from:accounts:)` (file: `LedgerForge/RepositoryStoreHydrator.swift`) maps repository DTOs to runtime `Transaction` for presentation and uses `accountDTO.name` and `accountDTO.institutionId` to populate display strings (`account`, `sourceBank`, `sourceFile`). These are not verified institutional identifiers.

- Schema support (file: `Database/Migrations.swift`)
  - Table `account_identifiers` exists with columns: `id`, `account_id`, `scheme`, `identifier`, `provenance`, `created_at` and an index on `(scheme, identifier)`.
  - No repository APIs currently read or write this table.

## Repository and SQLite Findings

- `Database/Repository.swift` protocols do not include identifier persistence or lookup.
- `Database/SQLiteRepositoryProvider.swift` implements `AccountRepository` with `upsertAccount(_:)`, `account(id:)`, `accounts(workspaceId:)`. `upsertAccount(_:)` issues `INSERT OR REPLACE` and seeds `institutions` when `institutionId` is set; it stores the provided `AccountDTO.id` without identity matching.
- Schema version is 2 (`allMigrations` in `Database/Migrations.swift`). `account_identifiers` exists since v1 but is unused by code.

## Import Pipeline Identity Flow

- Orchestration: `ImportEngine.commitPreparedImport(_:)` calls `ImportPersistenceCoordinating.persistValidatedImport(...)` after validation passes.
- Coordinator: `DefaultImportPersistenceCoordinator.persistValidatedImport(...)` maps domain to DTOs via `ImportPersistenceMapper.payload(...)` and persists through repositories.
- Account creation vs reuse: Reuse occurs only when the mapper produces the same `AccountDTO.id`. There is no repository-level identity matching beyond the provided `id`.
- Verified identifier extraction: None is present in the inspected production source.

## Verified Identity Gaps

- Current `AccountDTO.id` composition includes `importSession.fileName`. This is deterministic but fragile: different filenames for the same real-world account will yield different repository account IDs.
- No verified identifiers flow through `FinancialDocument` or the mapper.
- `account_identifiers` table exists but is unused; repository APIs do not expose identifier persistence or lookup.
- No deterministic ambiguity handling contract exists in code.

## Proposed Sprint 32 Boundary

Narrow Sprint 32 to identity infrastructure only (no production import integration), because production source does not emit reliable verified identifiers through `FinancialDocument`.

Deliverables:
- Canonical identifier domain types with strong/weak classification.
- Deterministic, exact-match resolver (infrastructure only) that operates on repository data.
- Repository APIs to persist and lookup identifiers (workspace-scoped), implemented for both providers.
- Focused diagnostics (developer-level) and comprehensive tests.

Explicitly excluded in Sprint 32:
- Changes to `ImportPersistenceMapper` or `DefaultImportPersistenceCoordinator` wiring.
- Parser changes and `FinancialDocument` schema changes.
- Automatic account reuse during import.
- New import failure semantics, account-ID generation changes, or UI changes.

## Proposed Domain Types

- `enum FinancialIdentifierStrength { case strong, weak }`
- `enum FinancialIdentifierKind: String { case iban, institutionAccountId, brokerAccountId, maskedPAN, cardLastFour, accountSuffix, displayName, filename, institutionLabel }`
- `struct FinancialIdentifier { let kind: FinancialIdentifierKind; let normalized: String; let raw: String?; let strength: FinancialIdentifierStrength; let provenance: [String: String]? }`

### Identity safety corrections

Revise identifier kinds into two categories:

- Resolution-eligible strong identifiers (only identifiers that can safely establish exact account identity):
  - normalized full IBAN
  - verified institution account ID
  - verified broker account ID
  - another full institution-issued identifier proven by repository source

- Non-resolution weak identifiers (must never independently establish exact identity):
  - card last four
  - partially masked PAN
  - account suffix
  - display name
  - filename
  - institution label

Note: In the current supported data, masked PAN is not proven unique or verified; classify it as weak.

## Deterministic Resolution Contract

Provide a resolver that consumes a candidate set of identifiers and produces a deterministic outcome. No silent selection is permitted.

Proposed types:

enum IdentityResolutionOutcome: Equatable {
case resolved(accountId: String)

case noMatch

case ambiguous(candidates: [String])

}

enum IdentityResolutionError: Error, Equatable {
case conflictingStrongIdentifiers([String: String]) // scheme -> identifier mapping

}

func resolveAccount(workspaceId: String, identifiers: [FinancialIdentifier]) throws -> IdentityResolutionOutcome

### Rules (candidate-set behavior):

1) All strong identifiers converge on one account
- If two or more strong identifiers are provided and, when looked up, all map to the same single `accountId` in the workspace, return `.resolved(accountId:)`.

2) Different strong identifiers resolve to different accounts
- If strong identifiers map to different existing `accountId`s in the workspace, throw `IdentityResolutionError.conflictingStrongIdentifiers`.

3) One strong identifier matches and another has no match
- If at least one strong identifier maps to exactly one `accountId` and remaining strong identifiers have no match, return `.resolved(accountId:)` for the matched account.

4) Multiple accounts match one identifier
- If a lookup of a single (scheme, identifier) returns multiple `accountId`s in the same workspace, return `.ambiguous(candidates:)`.

5) Only weak identifiers are available
- If only weak identifiers are provided, do not resolve. Return `.noMatch`.

6) No identifiers are available
- Return `.noMatch`.

7) Weak identifiers conflict with a strong exact match
- If a strong exact match exists, ignore conflicting weak identifiers and return the strong match. Weak identifiers never override a strong exact match.


### Error and return behavior:

- `attachIdentifier(...)` throws `conflictingAssignment` if `(workspaceId, scheme, identifier)` already maps to a different `accountId`. If the mapping already exists for the same account, it should be idempotent and return the existing row ID.
- `accountIdentifiers(accountId:workspaceId:)` returns all identifiers attached to the account in that workspace.
- `findAccountIds(workspaceId:scheme:identifier:)` returns a list of candidate `accountId`s in that workspace; if the list has more than one element, resolution is ambiguous.

SQLite implementation to prevent conflicting assignments without a UNIQUE constraint:
- Use `BEGIN IMMEDIATE` to open a write transaction.
- Query `account_identifiers` joined with `accounts` to constrain by `accounts.workspace_id = ?`.
- If rows exist for `(scheme, identifier)` in the workspace:
  - If all rows reference the same `account_id` and it matches the attempted `accountId`, return the existing row ID (idempotent).
  - If any row references a different `account_id`, throw `conflictingAssignment`.
- If no rows exist, insert the new identifier row and `COMMIT`.
- This check-then-insert occurs atomically within the transaction to avoid races; we do not claim database-level uniqueness.

In-memory provider behavior mirrors the above semantics with an internal in-memory index keyed by `(workspaceId, scheme, identifier)`.

## Schema and Migration Decision

A no-migration Sprint 32 is acceptable as a limited foundation with the following explicit limitations:

- Preserve schema version 2; do not alter `account_identifiers` DDL.
- Scope identifier lookups by `accounts.workspace_id` via join logic in repository implementations.
- Treat multiple mappings for `(workspaceId, scheme, identifier)` as ambiguous at the repository layer.
- Perform the lookup-and-insert atomically inside one transaction (`BEGIN IMMEDIATE`), but do not claim database-level uniqueness.
- Limitation: Without a UNIQUE constraint including workspace, concurrent writers outside our transaction discipline could still create duplicates; our code treats these as ambiguous on subsequent reads.

## Proposed Repository Contract Changes

Add identifier-aware APIs. Every lookup and write is scoped by workspace. These are non-breaking additions to `Database/Repository.swift`.

public struct AccountIdentifierDTO: Equatable {
public let id: String // UUID

public let accountId: String

public let workspaceId: String // derived via join in SQLite provider

public let scheme: String // e.g., "iban", "institution_account_id"

public let identifier: String // normalized

public let provenanceJSON: String? // optional serialized provenance

public let createdAtISO: String

}

public enum AccountIdentifierError: Error, LocalizedError, Equatable {
case ambiguous(workspaceId: String, scheme: String, identifier: String, candidates: [String])

case conflictingAssignment(workspaceId: String, scheme: String, identifier: String, existingAccountId: String, attemptedAccountId: String)

}

public protocol AccountRepository {
// existing APIs ...


func attachIdentifier(accountId: String,

                      workspaceId: String,

                      scheme: String,

                      identifier: String,

                      provenanceJSON: String?,

                      createdAtISO: String) throws -> String // returns identifier row id


func accountIdentifiers(accountId: String, workspaceId: String) throws -> [AccountIdentifierDTO]


func findAccountIds(workspaceId: String,

                    scheme: String,

                    identifier: String) throws -> [String]

}

## Required Tests

Add tests using the Swift Testing framework (`import Testing`) covering both providers (InMemory, SQLite):

- Repository identifier persistence
  - Attaching a new identifier succeeds and is idempotent for the same `(workspaceId, scheme, identifier, accountId)`.
  - Attaching the same `(workspaceId, scheme, identifier)` to a different `accountId` throws `conflictingAssignment`.
  - `findAccountIds(workspaceId:scheme:identifier:)` returns exactly one candidate for a unique mapping and multiple candidates when ambiguous.
  - `accountIdentifiers(accountId:workspaceId:)` returns the attached identifiers.

- Resolver behavior (the seven rules)
  - 1) All strong identifiers converge on one account → `.resolved`.
  - 2) Different strong identifiers resolve to different accounts → `conflictingStrongIdentifiers`.
  - 3) One strong matches and another has no match → `.resolved`.
  - 4) Multiple accounts match one identifier → `.ambiguous`.
  - 5) Only weak identifiers → `.noMatch`.
  - 6) No identifiers → `.noMatch`.
  - 7) Weak identifiers conflict with a strong exact match → strong match prevails.

- SQLite atomicity (behavioral)
  - Simulate sequential check-then-insert to ensure `attachIdentifier` behaves atomically and leaves the database in a consistent state when a simulated conflict occurs.

## Stop Conditions

Stop implementation and report if any of the following are encountered:
- Production source begins emitting reliable verified identifiers through `FinancialDocument` (would change sprint scope).
- `account_identifiers` table is absent or materially different from the expected columns.
- Transactional guarantees (`BEGIN IMMEDIATE`) cannot be honored in the target environment.

## Exact Expected Files

Only the following source and test files are expected to change or be added for the final recommended scope:

- Modify: `Database/Repository.swift` (add `AccountIdentifierDTO`, `AccountIdentifierError`, and new `AccountRepository` methods)
- Modify: `Database/InMemoryRepositoryProvider.swift` (implement new identifier methods)
- Modify: `Database/SQLiteRepositoryProvider.swift` (implement new identifier methods with transactional guard)
- Add: `LedgerForge/Services/IdentityResolver.swift` (deterministic resolver implementing the seven rules)
- Add: `LedgerForgeTests/AccountIdentifierRepositoryTests.swift` (repository identifier tests for both providers)
- Add: `LedgerForgeTests/IdentityResolverTests.swift` (resolver rules tests)

No changes to `ImportPersistenceMapper`, `ImportPersistenceCoordinator`, or `FinancialDocument` are included in this sprint.

## Acceptance Criteria

- Repository layer exposes identifier-aware APIs scoped by workspace with documented error semantics.
- InMemory and SQLite providers pass new identifier repository tests.
- Deterministic resolver is implemented and passes all seven rule tests.
- No changes to production import wiring (`ImportPersistenceMapper`, coordinator) or UI.
- Schema version remains 2; identifier lookups are workspace-scoped via joins.
- Documentation of limitations (no DB-level uniqueness) is included in code comments and developer diagnostics.

## Recommendation

Proceed with an identity infrastructure-only Sprint 32:
- Introduce canonical identifier types and a deterministic resolver.
- Implement repository-level identifier persistence and lookups scoped by workspace.
- Ship comprehensive tests to lock down behavior.

Defer production import integration and parser/schema changes to a future sprint when verified strong identifiers are available from the parsing pipeline.

Do not commit or push.
