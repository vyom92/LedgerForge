# =======ACTIVE SPRINT==========

## Sprint 32 — Financial Identity Foundation

### Status

🟢 Ready for Implementation

---

## Objective

Establish LedgerForge's deterministic Financial Identity Foundation.

This sprint establishes the repository and domain foundations required for stable financial account identity without changing existing financial behaviour, parser behaviour, runtime hydration or import workflows.

The Financial Identity Engine will allow LedgerForge to recognise the same real-world financial account across repeated imports using verified identifiers rather than relying solely on generated account IDs.

Sprint 32 deliberately focuses only on deterministic identity infrastructure.

It does not introduce automatic account merging, fuzzy matching, duplicate resolution, financial analytics or user-facing identity management.

---

## Verified Baseline

The following repository state is considered verified before Sprint 32 begins.

Completed work includes:

- Sprint 31 — Developer Diagnostics & Logging
- Structured Developer Diagnostics (ADR-026 Accepted)
- DTO concurrency isolation maintenance
- Explicit nonisolated Equatable on:
  - WorkspaceDTO
  - TransactionRawRowDTO
  - TransactionDTO
  - AccountDTO
  - ImportSessionRecordDTO
- App target default actor isolation remains MainActor
- Repository architecture remains unchanged
- Runtime hydration remains owned by RepositoryStoreHydrator
- SQLite schema version remains unchanged
- Xcode diagnostics pass
- Xcode BuildProject passes
- Xcode-native RunAllTests passes
- Manual runtime verification completed for Sprint 31

Sprint 32 begins from this verified baseline only.

No architectural rollback is permitted.

---

## User Outcome

After Sprint 32, LedgerForge will possess a deterministic financial identity infrastructure capable of storing, normalizing and resolving verified financial account identifiers.

This capability remains internal.

Users will not observe any behavioural changes during imports.

Existing imports, accounts, transactions, dashboards and runtime stores must continue to behave exactly as before.

This sprint prepares the repository layer for future account reuse while intentionally leaving production import behaviour unchanged.

---

## Scope

Sprint 32 establishes only the identity foundation.

### Included

- canonical financial identifier model
- identifier normalization
- identifier strength classification
- identifier verification state
- identifier provenance
- workspace-scoped repository persistence
- workspace-scoped repository lookup
- deterministic identity resolver
- SQLite implementation
- In-Memory implementation
- repository parity
- comprehensive automated testing
- concise developer diagnostics where appropriate

### Explicitly Excluded

Sprint 32 must **not** introduce:

- production import integration
- parser modifications
- `FinancialDocument` modifications
- account-ID generation changes
- automatic account reuse
- duplicate account merging
- fuzzy matching
- AI-assisted matching
- filename-based matching
- display-name matching
- institution-label matching
- user-facing identity management
- new UI
- schema migration
- account identifier backfill
- financial calculations
- analytics
- budgeting
- investment functionality

The objective is to build deterministic infrastructure only.

---

## Architectural Principles

The following principles are mandatory throughout Sprint 32.

### Deterministic

Every identity decision must always produce the same result for identical inputs.

No randomness, heuristics or probabilistic matching is permitted.

---

### Explainable

Every identity decision must be understandable from repository state alone.

Every successful or unsuccessful resolution must have a deterministic explanation.

---

### Repository Owned

Identity belongs to the repository layer.

Runtime stores, ViewModels and Views must never become owners of identity resolution.

---

### Provider Parity

The In-Memory repository and SQLite repository must behave identically.

A repository test that passes against one provider must pass unchanged against the other.

---

### Backwards Compatible

Existing account IDs remain unchanged.

Existing transaction relationships remain unchanged.

Existing import behaviour remains unchanged.

Existing SQLite databases remain valid.

No migration is introduced during Sprint 32.

---

## Canonical Financial Identifier Model

Sprint 32 introduces a canonical identifier model that represents real-world financial account identifiers independently of account names, filenames or generated repository IDs.

The model must remain lightweight, deterministic and suitable for repository persistence.

Each identifier shall record:

- identifier kind
- normalized value
- identifier strength
- verification state
- provenance
- creation timestamp where required by persistence

No external libraries may be introduced.

---

## Identifier Strength

Exactly two strength categories are supported.

### Strong

A strong identifier may independently establish exact account identity when it is verified and resolves unambiguously.

Examples include:

- full normalized IBAN
- verified institution-issued account ID
- verified broker account ID
- another full institution-issued identifier whose uniqueness has been established

---

### Weak

Weak identifiers may support diagnostics or future workflows but must never independently establish exact account identity.

Examples include:

- card last four digits
- partially masked PAN
- account suffix
- account nickname
- display name
- filename
- institution label

Rules:

- weak identifiers must never produce an exact match
- weak identifiers must never override a strong match
- weak identifiers must never broaden a strong match into another account
- partially masked values remain weak unless a future approved sprint explicitly proves uniqueness

---

## Identifier Normalization

Every supported identifier kind must define deterministic normalization rules.

Requirements:

- normalization must be explicit and fully testable
- normalization must not depend on locale-sensitive behaviour
- normalization must never silently infer missing characters
- normalized values are used for repository persistence and lookup
- invalid normalized values must be rejected
- empty normalized values must be rejected

Original imported values may be retained only as provenance metadata.

Institution-specific heuristics are explicitly out of scope.

---

## Verification and Provenance

Every identifier records both verification state and provenance.

Verification must never be assumed simply because text was extracted from an imported document.

Examples of provenance include:

- user confirmed
- institution-issued structured field
- imported metadata
- parser-derived text
- migration or administrative source

Rules:

- only verified strong identifiers may independently establish account identity
- parser-derived text remains unverified unless explicitly promoted by a future approved sprint
- provenance must remain deterministic and inspectable
- AI inference is not permitted

---

## Repository Contract Extension

Extend the repository layer with workspace-scoped financial identifier operations.

The repository remains the single persistence boundary for all identifier storage and lookup.

Required capabilities include:

- attach a normalized identifier to an account
- retrieve all identifiers associated with an account
- locate candidate account IDs using a normalized identifier within one workspace
- detect conflicting identifier ownership
- preserve idempotent writes

Rules:

- every lookup must be explicitly scoped by workspace ID
- repository APIs must never use filenames, display names or institution labels as identity keys
- repository APIs must never silently choose one account when multiple candidates exist
- ambiguity must always be surfaced explicitly
- all repository behaviour must remain deterministic

Existing repository contracts unrelated to account identity must remain unchanged.

---

## In-Memory Repository Implementation

The In-Memory repository must fully implement the new repository contract.

Requirements:

- behaviour must match the SQLite implementation
- attaching the same identifier to the same account is idempotent
- attaching an identifier already owned by another account in the same workspace fails deterministically
- candidate lookup returns every matching account ID
- workspace isolation is always enforced
- failed writes must not modify repository state
- deterministic ordering must be preserved where applicable

Provider parity with SQLite is mandatory.

---

## SQLite Repository Implementation

Implement repository support using the existing `account_identifiers` table.

Requirements:

- preserve schema version 2
- do not modify database migrations
- reuse the existing `account_identifiers` table
- perform all identifier lookups within the owning workspace
- preserve every existing account, transaction and import-session relationship
- existing account IDs must never change

Repository conflict detection must occur transactionally.

SQLite implementation requirements:

1. begin an immediate write transaction
2. query existing mappings within the requested workspace
3. reuse an identical existing mapping
4. reject conflicting ownership
5. insert only when no mapping exists
6. commit only after successful validation
7. roll back every failed transaction

Because SQLite does not currently enforce uniqueness for account identifiers, repository logic must provide deterministic conflict prevention.

Duplicate mappings discovered during lookup must always be reported as ambiguity.

Repository enforcement must not be described as database-level uniqueness.

---

## Deterministic Identity Resolver

Introduce a dedicated Financial Identity Resolver.

The resolver operates entirely independently from the production import pipeline.

Its responsibility is to evaluate verified financial identifiers and determine a deterministic resolution outcome.

Supported outcomes:

- **Resolved**
- **No Match**
- **Ambiguous**
- **Conflict**

Definitions:

### Resolved

All verified strong identifiers converge on exactly one account.

### No Match

No verified strong identifier resolves to an existing account.

This includes:

- no identifiers supplied
- only weak identifiers supplied
- verified identifiers that have no repository match

### Ambiguous

One or more verified identifiers resolve to multiple candidate accounts.

### Conflict

Different verified strong identifiers resolve to different accounts.

Resolver rules:

1. all matching strong identifiers converging on one account produce **Resolved**
2. conflicting strong identifiers produce **Conflict**
3. one verified match plus one non-matching verified identifier still produces **Resolved**
4. multiple candidate matches produce **Ambiguous**
5. weak identifiers alone always produce **No Match**
6. absence of identifiers produces **No Match**
7. weak identifiers never override, weaken or broaden a strong match
8. silent account selection is never permitted

Resolver behaviour must remain deterministic regardless of identifier ordering.

---

## Developer Diagnostics

Extend the existing Developer Diagnostics framework with concise identity-related events.

Diagnostics may report:

- identifier attached
- existing identifier reused
- conflicting identifier rejected
- resolver returned Resolved
- resolver returned No Match
- resolver returned Ambiguous
- resolver returned Conflict

Requirements:

- diagnostics remain in-memory only
- sensitive identifiers must never be logged in full
- identifiers should be safely redacted where appropriate
- diagnostics are informational only
- diagnostics must never become a financial source of truth
- no new Developer Console UI is introduced
- no persistent logging is added

---

## Execution Phases

Implementation should proceed in the following order.

### Phase 1 — Domain Model

Establish the financial identifier domain.

Tasks:

- introduce canonical financial identifier types
- implement identifier strength classification
- implement verification state
- implement provenance representation
- implement deterministic normalization
- ensure all domain types remain immutable where appropriate

No repository behaviour changes occur during this phase.

---

### Phase 2 — Repository Contracts

Extend repository protocols to support financial identifiers.

Tasks:

- introduce workspace-scoped identifier operations
- define deterministic repository errors
- preserve all existing repository APIs
- preserve backwards compatibility

Repository contracts should remain persistence-focused and must not contain business logic.

---

### Phase 3 — Repository Implementations

Implement the new repository behaviour.

Tasks:

- implement In-Memory repository support
- implement SQLite repository support
- ensure behavioural parity
- implement transactional conflict prevention
- preserve schema version 2

No schema migration is permitted.

---

### Phase 4 — Identity Resolver

Implement the Financial Identity Resolver.

Tasks:

- deterministic account resolution
- ambiguity detection
- conflict detection
- exact-match resolution
- workspace-scoped repository lookup interaction

The resolver must remain completely independent from the production import pipeline.

The resolver may query repository identifier APIs but must not be connected to:

- `ImportPersistenceMapper`
- `ImportPersistenceCoordinator`
- `ImportEngine`
- parser implementations
- `FinancialDocument`

The resolver is infrastructure only and must not alter production import behaviour during Sprint 32.

---

### Phase 5 — Developer Diagnostics

Add concise identity diagnostics.

Diagnostics should assist developers without exposing sensitive financial information.

No new UI components are required.

---

### Phase 6 — Automated Testing

Complete comprehensive repository and resolver testing.

Every new repository behaviour must be validated against both providers.

Regression testing must demonstrate that existing LedgerForge functionality remains unchanged.

---

## Expected Files

The following files are expected to change during Sprint 32.

### Repository Layer

- `Database/Repository.swift`
- `Database/InMemoryRepositoryProvider.swift`
- `Database/SQLiteRepositoryProvider.swift`
- `Database/DTOs.swift` (only if required for identifier persistence)

### Services

- `LedgerForge/Services/IdentityResolver.swift`

### Tests

- `LedgerForgeTests/AccountIdentifierRepositoryTests.swift`
- `LedgerForgeTests/IdentityResolverTests.swift`
- focused additions to existing repository contract tests

### Documentation

Upon successful completion only:

- `Project documents/PROJECT_STATE.md`
- `Project documents/Codex response.md`

`Project documents/Implementation.md` must never be modified by Codex.

Additional source files may be modified only when directly required to satisfy the approved Sprint 32 scope.

---

## Architecture Constraints

The approved architecture remains:

Repositories

↓

SQLite

↓

RepositoryStoreHydrator

↓

Runtime Stores

↓

ViewModels

↓

Views

Requirements:

- repository protocols remain the persistence boundary
- SQLite remains accessible only through repository implementations
- RepositoryStoreHydrator must not become an identity engine
- runtime stores remain presentation models
- ViewModels remain orchestration only
- Views remain presentation only

The following behaviour must remain unchanged:

- account ID generation
- transaction ownership
- import-session ownership
- runtime hydration
- dashboard presentation
- account presentation
- parser behaviour
- import behaviour
- SQLite schema version

No external dependencies may be introduced.

AI, fuzzy matching, probabilistic matching and heuristic matching are explicitly prohibited during Sprint 32.

---

## Acceptance Criteria

Sprint 32 is complete only when all of the following are satisfied.

### Domain Model

- canonical financial identifier model exists
- identifier kinds are explicitly defined
- strong and weak identifier categories exist
- verification state is represented
- provenance is represented
- normalization is deterministic
- invalid normalized values are rejected

---

### Repository Contracts

- repository identifier APIs are workspace-scoped
- attaching a new identifier succeeds
- attaching the same mapping is idempotent
- conflicting ownership is rejected
- listing identifiers for an account succeeds
- candidate lookup returns every matching account ID
- ambiguous candidates are never silently collapsed

---

### In-Memory Repository

- behaviour matches the documented repository contract
- workspace isolation is enforced
- idempotent writes create no duplicate mappings
- conflicting writes leave repository state unchanged

---

### SQLite Repository

- schema version remains 2
- existing `account_identifiers` table is reused
- lookup remains workspace-scoped
- conflict detection and insertion occur atomically
- failed writes roll back cleanly
- idempotent writes create no duplicate mappings
- duplicate stored mappings are surfaced as ambiguity
- existing account IDs remain unchanged

---

### Identity Resolver

- converging strong identifiers produce **Resolved**
- conflicting strong identifiers produce **Conflict**
- one verified match plus one verified no-match produces **Resolved**
- multiple candidate matches produce **Ambiguous**
- weak identifiers alone produce **No Match**
- absence of identifiers produces **No Match**
- weak identifiers never override a strong match
- resolver behaviour is deterministic regardless of input ordering
- resolver may query workspace-scoped repository identifier APIs
- resolver remains disconnected from production import workflows
- no path silently selects among multiple accounts

---

### Developer Diagnostics

- identity diagnostics integrate with the existing Developer Console
- sensitive identifiers are never logged in full
- diagnostics remain concise
- diagnostics remain in-memory only
- no new persistent diagnostic storage is introduced

---

### Compatibility

The following behaviour must remain unchanged:

- production import behaviour
- parser behaviour
- `FinancialDocument`
- account ID generation
- transaction ownership
- import-session ownership
- RepositoryStoreHydrator behaviour
- runtime stores
- dashboard presentation
- account presentation
- existing SQLite databases

---

## Automated Validation

Before Sprint 32 may be considered complete:

### Xcode Diagnostics

- diagnostics pass for every modified Swift file that Xcode can resolve

### Build

- Xcode BuildProject passes

### Tests

- Xcode-native RunAllTests passes
- all new repository tests pass
- all new resolver tests pass
- no existing regression tests fail

Repository behaviour must be validated against both:

- In-Memory provider
- SQLite provider

---

## Manual Validation

Manual runtime regression verification is required after automated validation.

The user will perform runtime verification in Xcode.

Codex must not claim runtime verification unless evidence is explicitly supplied.

Because Sprint 32 is infrastructure-only, manual validation is limited to regression safety.

Verify:

- application launches successfully
- existing SQLite databases open successfully
- Dashboard behaviour is unchanged
- Accounts behaviour is unchanged
- Transactions behaviour is unchanged
- existing imports behave exactly as before
- Developer Console continues functioning normally
- no user-facing identity UI exists
- existing account IDs remain unchanged
- existing relationships remain unchanged

No manual identity-resolution workflow is required during this sprint.

---

## Explicitly Out of Scope

Sprint 32 must not introduce:

- production import integration
- ImportPersistenceMapper modifications
- ImportPersistenceCoordinator modifications
- parser modifications
- FinancialDocument modifications
- account-ID generation changes
- automatic account reuse
- duplicate account merging
- identity-management UI
- duplicate-management UI
- schema migration
- account identifier backfill
- fuzzy matching
- AI-assisted matching
- filename-based identity
- display-name identity
- institution-label identity
- masked PAN as an exact identifier
- card last four as an exact identifier
- new financial calculations
- budgeting
- investments
- analytics

---

## Stop Conditions

Stop implementation immediately and report without committing if:

- the verified `account_identifiers` schema differs materially from the inspected schema
- workspace-scoped lookup cannot be implemented safely
- transaction-safe conflict prevention cannot be guaranteed
- implementation requires changing existing account IDs
- implementation requires changing transaction ownership
- implementation requires changing import-session ownership
- implementation requires parser modifications
- implementation requires `FinancialDocument` modifications
- implementation requires production import integration
- implementation requires schema migration
- implementation expands into UI
- deterministic behaviour cannot be guaranteed
- provider parity cannot be maintained
- implementation expands into fuzzy or AI matching

Do not work around these boundaries.

Do not begin Sprint 33.

---

## Completion

Sprint 32 is complete only when:

- canonical financial identifier infrastructure is implemented
- repository contracts are complete
- In-Memory and SQLite providers behave identically
- deterministic resolver behaviour is implemented
- all new automated tests pass
- the existing test suite passes
- manual regression verification passes
- production import behaviour remains unchanged
- existing account IDs remain unchanged
- schema version remains 2
- `PROJECT_STATE.md` is updated with verified facts
- `Codex response.md` is replaced with the Sprint 32 implementation report
- implementation commit is created and pushed
- remote `main` is verified
- documentation handoff is completed

Desktop ChatGPT will review Sprint 32 before defining the next ACTIVE sprint.


