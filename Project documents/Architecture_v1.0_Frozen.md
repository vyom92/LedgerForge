# Architecture v1.0 — boundaries and accepted alignments

## Current applicability

This file owns cross-layer contracts, not current support, migration inventory or a feature roadmap. [PROJECT_STATE](PROJECT_STATE.md) owns current accepted implementation and active WIP. [ADR](ADR.md) owns accepted architectural decisions, especially ADR-046 for adaptive authentic-source interpretation and its current processing alignment. [Database architecture](Database_v1_Architecture.md) owns persistence boundaries; registered source/migrations are exact DDL authority. [Scope decisions](SCOPE_DECISIONS.md) constrains future proposals.

The original v1 architecture was reviewed at `b661472a58fc24144361322f1853b8001437a3eb` on 2026-07-26. The retained contracts below explain that architecture with later accepted constraints; original implementation-status/support inventories are historical and have been replaced by a current-state link. A dormant protocol/table or future domain name is not an implemented capability. Later accepted alignments control applicability; no architecture is created by this refactor.

Accepted later ownership includes provider-owned atomic imports and canonical hydration, immutable original-byte source snapshots/provenance, exact source-specific equivalence, current Salary planning and the ADR-046 authentic-corpus reset. Accepted Swift 6, staging/provider publication and Sprint 88 shell ownership are recorded in current state and accepted outcomes. Physical layers may change only under an approved boundary; institution parsers remain ingestion modules, not analytical silos.

# Core Principles

## Offline first

Core financial use must work without internet access.

Online services are optional enhancements.

The repository remains usable when external services are unavailable.

## One durable source of truth

SQLite is the production durable authority.

Runtime stores are projections of repository state.

Views and ViewModels never become financial truth.

## Deterministic before intelligent

Structured financial evidence is handled deterministically.

AI may later assist with unsupported or ambiguous evidence, but it must never become the sole authority for:

- institution identity;
- statement classification;
- parser selection;
- financial validation;
- account identity;
- duplicate identity;
- persistence;
- financial mutation.

## Validation before persistence

Imported financial data must pass structural and financial validation before accepted persistence.

Malformed, ambiguous, conflicting or unsupported trusted evidence fails closed.

## Native currency preservation

Every monetary value retains:

- exact decimal meaning;
- canonical scale;
- native currency.

Conversion is derived and never destructive.

Mixed currencies are not silently aggregated.

## Immutable imported truth

Imported financial values and trusted source relationships are immutable after accepted persistence.

User-authored metadata remains separate.

Future categories, notes, tags, rules and corrections must not rewrite source-owned financial truth merely to simplify presentation.

## Durable identity

Repository identities are immutable.

Display names, filenames, institution labels, masked values, suffixes and runtime UUIDs are not identity authority.

## Explainability and provenance

Every trusted imported transaction remains traceable to:

- its owning account;
- accepted import session;
- source document;
- normalized source record relationships;
- parser profile;
- validation and duplicate boundaries.

## Explicit control

Preparation and review are read-only.

Accepted persistence requires explicit confirmation.

Financial mutation requires family-specific review, authorization and atomic execution.

## Provider parity

SQLite and In-Memory providers must expose equivalent domain behavior where both are authoritative for an accepted boundary.

Equivalent behavior does not require identical implementation internals.

## Fail closed

LedgerForge prefers unavailable or rejected state over invented financial truth.

No architecture component may guess:

- account identity;
- historical provenance;
- source order;
- currency conversion;
- duplicate identity;
- unsupported parser compatibility;
- mutation impact.

---

# Architectural Layers

LedgerForge uses the following conceptual layers:

```text
SwiftUI Views
    ↓
ViewModels and Coordinators
    ↓
Runtime Stores
    ↑
RepositoryStoreHydrator
    ↑
Repository Protocols
    ↑
DatabaseProvider
    ↑
SQLite or approved In-Memory provider
```

Import enters through a separate orchestration path and converges on the same repositories and hydrator.

Rules, future analytics and financial intelligence consume trusted repository-backed state. They do not bypass repositories by consuming transient parser output as truth.

---

# Import Architecture

## Canonical production pipeline

Every supported import follows one deterministic architecture:

```text
ImportCoordinator
    ↓
PasswordProvider
    ↓
ReaderRegistry
    ↓
Reader
    ↓
RawDocument
    ↓
Institution Detection
    ↓
Statement Classification
    ↓
Parser Selection
    ↓
Statement Parser
    ↓
FinancialDocument
    ↓
Validation
    ↓
Exact-Content and Supported Event Evaluation
    ↓
Account / Identity Review
    ↓
Explicit User Confirmation
    ↓
DatabaseProvider Confirmed-Import Operation
    ↓
Provider-Owned Atomic Persistence
    ↓
RepositoryStoreHydrator
    ↓
Runtime Stores
    ↓
ViewModels
    ↓
Views
```

Preparation, review and confirmation are distinct phases.

The pipeline must not collapse advisory preparation into durable authority.

## ImportCoordinator

`ImportCoordinator` owns import orchestration.

It coordinates:

- source authorization;
- optional password resolution;
- reader selection;
- preparation;
- named progress stages;
- cancellation before confirmed persistence;
- review state;
- confirmation handoff;
- result classification;
- canonical hydration.

It does not perform financial parsing.

It does not write directly to repositories by composing partial write calls.

## PasswordProvider

`PasswordProvider` resolves an optional password before reader execution.

Readers receive a supplied credential.

Readers never:

- access Keychain directly;
- show UI prompts;
- decide institution-specific password policy;
- persist credentials.

No production credential source or Keychain workflow currently exists.

## ReaderRegistry and Readers

`ReaderRegistry` selects a reader by supported source format.

Readers:

- understand source formats;
- open authorized source content;
- produce `RawDocument`;
- preserve source order;
- perform no financial interpretation.

Current exact reader/source support and unobserved formats are maintained in [PROJECT_STATE](PROJECT_STATE.md). Do not infer support from this original baseline, extraction capacity or institution/layout similarity. [SCOPE_DECISIONS](SCOPE_DECISIONS.md) owns rejected hypothetical source expansion.

## RawDocument

`RawDocument` is the reader-owned extracted representation.

It is not trusted financial truth.

It supplies deterministic evidence to:

- institution detection;
- statement classification;
- parser selection;
- exact-content fingerprinting where the algorithm supports that representation.

Reader-produced text and original binary bytes are distinct fingerprint authorities. Accepted ADR-041 defines the immutable source snapshot and exact source-byte contract; current implementation applicability is in [PROJECT_STATE](PROJECT_STATE.md). Processing remains in memory under the current owner rule.

## Institution Detection

Institution Detection operates on approved extracted-content evidence.

It must be:

- deterministic;
- explainable;
- format-aware only through extracted evidence;
- independent of filenames as authority;
- able to return unknown.

It must not infer support from:

- visual similarity alone;
- previous filenames;
- account display names;
- user expectations;
- a fixture from another layout.

## Statement Classification

Statement Classification identifies the financial document family.

Examples include:

- bank account;
- credit card;
- brokerage;
- salary;
- insurance;
- tax;
- unknown.

Classification is deterministic and independent from parser execution.

Unknown remains a valid result.

## Parser Selection

Parser Selection consumes the detected institution and statement classification.

It selects only an approved parser/profile for the supported evidence boundary.

Parser selection must not broaden one fixture-backed family into:

- all layouts;
- all source formats;
- all institution products;
- historical layouts;
- another currency;
- card semantics.

## Statement Parsers

Statement parsers own financial interpretation.

They construct immutable `FinancialDocument` values.

Parsers own:

- supported layout semantics;
- source column or field meaning;
- financial direction;
- source date interpretation;
- parser profile identity and version;
- strong verified financial identifiers;
- approved transaction-event evidence;
- document-scoped card evidence where later implemented.

Parsers do not perform file I/O.

They do not persist.

They do not access runtime stores.

## FinancialDocument

`FinancialDocument` is the canonical parser output.

It carries immutable parsed financial evidence required for:

- validation;
- identity resolution;
- duplicate and transaction-event evaluation;
- explicit review;
- persistence mapping.

It must preserve source-supported meaning without inventing absent values.

## Validation

Validation is mandatory before accepted persistence.

Validation owns structural and financial checks.

Production parser output cannot serve as the sole oracle for validation acceptance.

Approved fixtures and independent calculations must verify:

- transaction count;
- native currency;
- exact values;
- financial direction;
- dates;
- source order;
- balances;
- identifiers;
- provenance;
- statement summaries where applicable.

## Preparation

Preparation is read-only.

It may perform:

- reading;
- detection;
- classification;
- parser selection;
- parsing;
- validation;
- advisory duplicate lookup;
- advisory identity resolution;
- account-choice preparation;
- immutable plan construction.

Preparation must not:

- create accounts;
- attach identifiers;
- reserve fingerprints;
- reserve event identities;
- persist transactions;
- record a successful import;
- mutate runtime stores.

## Cancellation

Cancellation is supported only before confirmed persistence begins.

A cancelled preparation:

- creates no trusted financial graph;
- is not a successful import session;
- is not durable attempt history under the current accepted boundary;
- performs no account or identifier mutation.

Confirmed persistence is non-cancellable.

## Review and explicit confirmation

The user reviews:

- source and statement summary;
- validation;
- account or identity decision;
- duplicate or supported event outcome;
- accepted transaction scope;
- persistence meaning.

Confirmation authorizes only the immutable prepared import being reviewed.

It does not authorize stale or altered repository assumptions.

## Confirmed-import persistence

The confirmed-import operation is owned by `DatabaseProvider`.

It begins authoritative transaction-time evaluation before accepted writes.

It revalidates:

- provider generation;
- prepared fingerprint contract;
- exact-content ownership;
- current financial-identity resolution;
- explicit no-match account choice;
- workspace/account relationships;
- identifier ownership;
- supported transaction-event ownership;
- complete accepted source provenance;
- accepted graph validity.

The operation atomically commits the complete accepted financial graph or commits none of it.

The graph may include:

- workspace;
- account;
- identifier ownership;
- identifier observations;
- document;
- exact fingerprint;
- import session;
- trusted transactions;
- normalized source evidence;
- transaction/source relationships;
- transaction-event claims;
- successful durable attempt.

A losing or failed accepted operation leaves zero accepted account, identifier or financial residue.

## Rejected-attempt history

Rejected attempts remain distinct from successful import sessions.

Rejected-attempt recording is bounded and best effort after rejection or financial rollback.

Failure to record a rejected attempt must never convert rejection into success.

Persistence unavailability must remain truthful.

## Canonical hydration

After durable commit, one forced canonical reconciliation occurs through `RepositoryStoreHydrator`.

Stores are not patched manually to simulate completion.

A durable commit followed by hydration failure remains a committed durable result with failed runtime reconciliation. It must not be reported as uncommitted.

---

# Repository and Persistence Architecture

## DatabaseProvider

`DatabaseProvider` owns the active repository set and provider-level operations.

It is the authority for:

- verified SQLite installation;
- intentional In-Memory installation in approved test or Debug contexts;
- unavailable persistence;
- provider generation;
- confirmed-import atomicity;
- provider-equivalent domain results.

Captured repositories are generation-bound.

Provider replacement invalidates stale repository wrappers.

## Repository protocols

Repositories define domain persistence boundaries.

They do not permit Views or ViewModels to coordinate cross-domain writes as pseudo-transactions.

Existing narrow repositories must not be used as a generic financial-mutation engine.

## SQLite production provider

SQLite is the production durable store.

It remains behind repository abstractions.

The active database is accepted only after:

1. open succeeds;
2. migration history is validated;
3. pending registered migrations execute;
4. final chain integrity is revalidated;
5. repositories are installed together.

## Registered migration chain

Current implementation, migration and material limits are maintained in [PROJECT_STATE](PROJECT_STATE.md); the relevant accepted ADR owns its exact contract. This section does not promote schema/protocol capacity into behavior.

## Persistence unavailable state

Open, initialization, migration-integrity or migration-execution failure installs centrally rejecting unavailable repositories.

The application must distinguish:

- durable SQLite;
- intentional non-durable provider;
- unavailable persistence.

Unavailable is not empty.

UI and diagnostics must not expose raw SQLite errors or paths as the public contract.

## SQLite and In-Memory parity

Approved domain operations expose equivalent results across providers.

Parity includes, where applicable:

- accepted writes;
- rejection;
- duplicate outcomes;
- identity conflicts;
- contention;
- atomic rollback;
- hydration evidence;
- deterministic ordering;
- typed errors.

The In-Memory provider must publish accepted collections together rather than leaking partial mutation.

---

# RepositoryStoreHydrator

`RepositoryStoreHydrator` is the only repository-to-runtime boundary.

It reconstructs canonical runtime state from durable repositories.

It owns hydration of:

- accounts;
- transactions;
- accepted import sessions;
- import attempts;
- trusted provenance;
- future category state after implementation.

Hydration is fail-closed for malformed trusted evidence.

Runtime stores are not repaired manually when hydration rejects durable state.

Hydration must preserve durable repository transaction identity where downstream approved features require it.

---

# Runtime Store Architecture

Stores own runtime state.

Current store responsibilities include account and transaction presentation state.

Views observe stores.

ViewModels transform state for presentation.

Views and ViewModels do not:

- own durable identity;
- perform financial persistence;
- reconstruct identifiers;
- infer transaction provenance;
- coordinate atomic writes;
- become mutation authority.

A runtime UUID used for presentation must never replace a persisted repository ID.

---

# Financial Identity Architecture

## Stable account identity

A repository account ID is immutable.

Display name, institution label and account type are metadata.

Renaming an account does not replace it.

Financial history remains attached to the same durable account.

## Parser-owned verified identifiers

Strong financial identifiers originate exclusively from approved `StatementParser` evidence.

Import orchestration, repositories, Views and ViewModels do not derive identifiers from:

- filenames;
- display names;
- institution names;
- masked values;
- last four digits;
- balances;
- transaction similarity;
- customer context.

## Identity resolution

Verified identifiers may produce:

- unique match;
- no match;
- ambiguity;
- conflict.

Unique match resolves to the durable account.

Ambiguity or conflict rejects accepted persistence.

## Explicit no-match choice

For an eligible no-match case, the user explicitly chooses:

- creation of a new account; or
- one eligible unseeded existing account.

Eligibility is not identity evidence.

The provider transaction revalidates the choice before accepted writes.

## Identifier ownership

Identifier ownership is workspace-scoped and singular.

Migration V5 introduced durable ownership constraints.

An identifier is:

- unowned;
- owned by the resolved account;
- owned by another account.

Ownership by another account rejects the complete import.

## Identifier observations

Ownership and accepted-import observation are distinct.

An observation records bounded provenance connecting:

- identifier ownership;
- accepted import session;
- accepted document;
- parser provenance;
- account-association authority.

Historical observations are not invented.

## Unimplemented identity operations

Current implementation, migration and material limits are maintained in [PROJECT_STATE](PROJECT_STATE.md); the relevant accepted ADR owns its exact contract. This section does not promote schema/protocol capacity into behavior.

# Duplicate and Transaction-Event Architecture

## Exact-content fingerprints

ADR-030 defines versioned exact-content duplicate identity.

The implemented text algorithm is:

```text
ledgerforge.raw-text.sha256.v1
```

Its authority is exact reader-produced UTF-8 text before parsing or normalization.

It excludes:

- filename;
- path;
- file dates;
- import dates;
- institution labels;
- account identity;
- parsed transactions;
- financial totals;
- display metadata.

Fingerprints are prospective.

Legacy fingerprints are not reconstructed from reduced history.

## Binary-document fingerprints

ADR-041 owns `ledgerforge.source-bytes.sha256.v1` and immutable source-snapshot authority. Accepted implementation is linked from [PROJECT_STATE](PROJECT_STATE.md); older raw-text provenance remains unchanged.

Production PDF support remains blocked until that foundation is implemented and accepted, and one approved PDF family is selected and revalidated through the ordinary production path.

Binary identity must not be inferred from parsed financial output.

## Exact duplicate versus cross-format equivalence

Exact-content duplicate identity and cross-format financial equivalence are separate concepts.

- Exact duplicate means the same versioned algorithm and source digest.
- Cross-format equivalence means distinct source representations are independently proven to describe the same financial statement.

Matching transaction sets or totals alone do not prove cross-format identity.

## Transaction-event evidence

ADR-031 defines bounded parser-owned Axis UPI event evidence.

The supported algorithm is scoped to:

- the resolved immutable account;
- parser-classified Axis UPI operation;
- exact supported reference;
- parser-owned ledger subtype.

Date, amount, narration, balance, filename and row position are not event identity.

## Overlap behavior

A supported event overlap blocks the complete incoming statement.

The system does not silently omit blocked transactions.

Explicit partial-overlap import requires separate review and persistence semantics.

## Unsupported event families

Current implementation, migration and material limits are maintained in [PROJECT_STATE](PROJECT_STATE.md); the relevant accepted ADR owns its exact contract. This section does not promote schema/protocol capacity into behavior.

# Import Attempt Architecture

Import attempts and accepted import sessions are separate durable concepts.

An attempt may record a bounded outcome even when no accepted financial graph exists.

Attempt history may include bounded:

- outcome;
- coverage;
- account-decision provenance;
- guidance;
- accepted session/document relationships where they exist.

The public contract uses closed typed values.

Raw persistence strings are not user-facing authority.

Unknown future or malformed codes remain neutral and bounded.

A current verified presentation defect in exhaustive handling is tracked outside this architecture as `FW-P0-24`.

---

# Money and Currency Architecture

## Money

ADR-033 defines exact `Money`.

A monetary value includes:

- exact decimal meaning;
- canonical scale;
- canonical currency code.

Persistence must reject:

- malformed decimal text;
- scale mismatch;
- minor-unit disagreement;
- unsupported currency evidence;
- currency disagreement.

Binary floating-point reconstruction is prohibited for trusted persisted money.

## Native currency

Native currency is authoritative.

Presentation groups amounts by native currency.

No combined mixed-currency total appears without approved conversion.

## Exchange rates

Exchange-rate architecture remains future work.

When implemented, rates must retain:

- provider provenance;
- validity time;
- version;
- stale or missing state;
- offline cache semantics.

Conversion remains derived.

## Regional formatting

Display formatting follows locale and currency conventions.

Formatting never changes persisted financial truth.

---

# Trusted Statement Date Architecture

ADR-039 defines `StatementDate`.

`StatementDate` is:

- the Gregorian date printed and assigned by the institution;
- year, month and day only;
- persisted as `YYYY-MM-DD`;
- not an instant;
- not `Foundation.Date`;
- not local midnight;
- not timezone conversion.

The supported Axis profile retains separate `Asia/Kolkata` evidence without transforming the printed date.

Presentation renders the date directly from its components.

---

# Source Order and Provenance Architecture

## Source ordinal

Source ordinal is the one-based physical normalized-record position within one reader-produced document.

Within one document:

```text
StatementDate + source ordinal
```

is authoritative sequence.

Across documents, equal dates do not establish intraday chronology.

## Normalized source evidence

Durable provenance includes:

- normalized document;
- normalized row;
- privacy-minimal normalized-record digest;
- parser profile ID/version;
- transaction-to-source relationships.

Unrestricted raw source text is not retained merely for convenience.

## Profile provenance

The parser produces the profile ID/version.

Persistence requires exactly one valid profile pair for trusted imported transactions.

Hydration reads actual durable profile provenance.

It does not:

- default;
- reconstruct;
- hardcode;
- rewrite historical profile identity.

## Historical migration

Migration V6 never invents dates, ordinal or provenance.

A nonempty V5 financial graph fails closed for explicit pre-production reset rather than receiving fabricated evidence.

---

# Credit-Card Architecture

ADR-034 accepts a document-scoped card-statement evidence direction.

The architectural decision alone does not establish a particular source family. Later accepted card implementations and their exact limits are in [PROJECT_STATE](PROJECT_STATE.md) and ADR-044.

The card evidence contract may preserve, only when source-supported:

- posted statement amount;
- statement currency;
- source-proven effect on amount owed;
- account-level versus instrument-level scope;
- document-scoped instrument identity;
- original merchant amount and currency;
- printed FX rate;
- fee;
- markup;
- tax;
- source-specific statement-summary evidence.

Card-liability effects remain separate from bank-account debit/credit semantics.

A card instrument does not automatically become a separate financial account.

Missing FX, fee, tax or summary evidence must not be calculated merely to populate a common model.

Each exact card support claim requires its complete authentic family corpus and independent source proof plus approved:

- validation;
- persistence;
- migration;
- hydration;
- presentation;
- provider parity.

---

# Category Architecture

ADR-036 owns category identity and current assignment architecture. Its accepted implementation and remaining limits are linked from [PROJECT_STATE](PROJECT_STATE.md).

## Separation from imported truth

Categories and assignments are user-authored metadata.

They must not modify imported:

- amount;
- currency;
- direction;
- date;
- source description;
- balance;
- account;
- document;
- import session;
- row identity;
- fingerprint;
- event identity;
- parser or validation result.

## Category identity

A category is workspace-owned and has an immutable repository identity.

Renaming, moving, archiving or restoring does not change identity.

## Assignment

The initial accepted architecture supports:

- zero or one current category per transaction;
- a separate assignment relationship;
- Uncategorized as absence of assignment;
- manual assignment, change and clear;
- user-created categories;
- root plus one child level;
- archive and restore;
- delete only when unused and childless.

Assignment requires durable repository transaction identity.

Runtime-generated transaction IDs are not persistence targets.

## Current state

Current implementation, migration and material limits are maintained in [PROJECT_STATE](PROJECT_STATE.md); the relevant accepted ADR owns its exact contract. This section does not promote schema/protocol capacity into behavior.

# Financial-Mutation Architecture

ADR-037 accepts a contract-first financial-mutation lifecycle.

It does not authorize an executable generic mutation.

The accepted lifecycle is:

```text
authoritative repository snapshot
    ↓
immutable deterministic mutation plan
    ↓
read-only review
    ↓
single-use authorization
    ↓
transaction-time revalidation
    ↓
provider-owned atomic execution and successful audit
    ↓
canonical runtime reconciliation
    ↓
family-specific reversal, compensation or explicit irreversibility
```

## Generic architecture owns

- lifecycle states;
- immutable plan envelope;
- canonical encoding;
- digest binding;
- provider-generation binding;
- scoped preconditions;
- single-use authorization;
- atomic execution requirement;
- successful-audit atomicity;
- provider parity;
- reconciliation outcomes;
- privacy;
- reversal classification.

## Concrete mutation family owns

- eligible records;
- affected-record scope;
- financial meaning;
- conflict policy;
- impact calculation;
- write set;
- successful audit payload;
- reversal or compensation;
- migration;
- hydration impact;
- UI;
- family-specific verification.

## Prohibited shortcuts

Financial mutation must not be simulated by:

- Views calling several repositories;
- ViewModels coordinating partial writes;
- runtime-store patching;
- database backup restoration;
- arbitrary JSON before/after snapshots;
- application-wide generic undo;
- Developer Console actions;
- AI-selected write behavior.

## Current state

Current implementation, migration and material limits are maintained in [PROJECT_STATE](PROJECT_STATE.md); the relevant accepted ADR owns its exact contract. This section does not promote schema/protocol capacity into behavior.

# Development Diagnostics Architecture

ADR-026 governs structured diagnostics.

Diagnostics are:

- deterministic;
- typed;
- bounded;
- privacy-safe;
- in memory unless another ADR approves persistence.

Diagnostics must not contain:

- passwords;
- raw identifiers;
- unrestricted source fragments;
- full fingerprints;
- arbitrary database paths;
- raw SQL errors as public contract.

Developer tooling remains separate from financial truth.

A diagnostic export or persistent history requires separate architecture.

---

# Development Database Lifecycle Architecture

ADR-035 governs the DEBUG-only development database lifecycle.

One `DevelopmentDatabaseLifecycleCoordinator` owns:

- canonical development identity;
- temporary session identities;
- lifecycle backup identity;
- operation serialization;
- activity exclusion;
- provider quiescence;
- checkpoint and checked close;
- backup creation and verification;
- SQLite/WAL/SHM coordination;
- provider recreation;
- canonical hydration;
- recovery;
- lifecycle-unavailable state.

## Build safety

Permanent reset, restore and approved-fixture controls are absent from Release builds.

Runtime hiding is not a security boundary.

## Lifecycle activity gate

Provider-backed work obtains a generation-bound lease.

Exclusive lifecycle work blocks new leases and waits for active operations.

Lifecycle transitions invalidate stale repositories, plans and authorizations.

## Backup meaning

The lifecycle-owned backup protects Debug database replacement.

It is not:

- production backup;
- record-level undo;
- financial mutation reversal;
- arbitrary file restore.

## Runtime reconciliation

Reset and restore succeed only after canonical hydration.

Stores are not manually cleared to fake an empty database.

---

# Security and Privacy Architecture

## Local-first data

Core financial truth is stored locally.

No online dependency may be required for core operation.

## File access

macOS grants access to user-selected files and folders.

LedgerForge does not claim unrestricted filesystem access.

Security-scoped access begins and ends within the approved source-reading boundary.

## Credentials

Passwords remain outside SQLite and diagnostics.

Keychain integration requires separate production implementation and security review.

## Presentation

Ordinary presentation must not expose:

- raw financial identifiers;
- repository IDs as financial identity;
- file paths;
- raw source fragments;
- SQL;
- unrestricted internal errors.

## Fixtures

Apply [authentic source/oracle invariants](Engineering%20Standards.md#authentic-source-and-oracle-invariants), the owner’s [in-memory processing decision](SCOPE_DECISIONS.md#source-processing-decision) and ADR-046. Historical fixture/copy permissions are not current development authority.

# Concurrency Architecture

Correctness relies on:

- provider-owned transactions;
- database constraints;
- transaction-time revalidation;
- provider-generation checks;
- same-process serialization where required;
- equivalent In-Memory serialization.

A process-local lock may improve user experience but is not durable correctness authority.

Approved concurrent-import guarantees cover approved writers using the registered schema and enabled constraints.

They do not cover:

- arbitrary external SQLite writers;
- disabled constraints;
- altered schema;
- malicious file modification;
- corrupting access.

Future mutation families must stop when they require guarantees beyond the implemented concurrency boundary.

---

# Failure Architecture

Failures use typed domain outcomes.

Raw implementation errors do not define public behavior.

The architecture distinguishes:

- unsupported;
- invalid source;
- validation failure;
- duplicate;
- event conflict;
- identity ambiguity;
- identity conflict;
- stale preparation;
- provider mismatch;
- persistence unavailable;
- contention;
- atomic write failure;
- committed but runtime reconciliation failed;
- lifecycle unavailable.

Unknown or future values remain neutral.

No failure may be reclassified as success because audit recording failed.

No committed result may be reclassified as uncommitted merely because hydration failed.

---

# Testing and Verification Architecture

## Source truth

Apply [authentic source/oracle invariants](Engineering%20Standards.md#authentic-source-and-oracle-invariants), the owner’s [in-memory processing decision](SCOPE_DECISIONS.md#source-processing-decision) and ADR-046. Historical fixture/copy permissions are not current development authority.

## Fixture requirements

Apply [authentic source/oracle invariants](Engineering%20Standards.md#authentic-source-and-oracle-invariants), the owner’s [in-memory processing decision](SCOPE_DECISIONS.md#source-processing-decision) and ADR-046. Historical fixture/copy permissions are not current development authority.

## Financial invariants

Tests must preserve:

- transaction count;
- native currency;
- exact amount and scale;
- direction;
- date meaning;
- source order;
- balance relationships;
- identifiers;
- document and row provenance.

## Provider parity

Where both providers matter, tests cover equivalent:

- success;
- rejection;
- atomic failure;
- contention;
- stale state;
- hydration;
- relaunch;
- ordering;
- privacy-safe errors.

## Lifecycle verification

Trusted behavior must be verified through:

- persistence;
- hydration;
- provider reconstruction;
- application relaunch;
- presentation.

Parser output alone is insufficient.

## Build verification

Every accepted implementation should pass the approved:

- focused tests;
- canonical TestPlan;
- Debug build;
- optimized Release build;
- static analysis;
- runtime boundary where required.

A green suite proves only the boundary it actually exercises.

---

# Architecture Freeze and Change Policy

The v1.0 baseline may change only when:

1. real source or production evidence exposes a fundamental flaw;
2. the change benefits a coherent architectural boundary rather than one accidental fixture;
3. financial truth and durable identity remain preserved;
4. SQLite and In-Memory implications are understood;
5. migration and compatibility impact are explicit;
6. privacy and failure behavior are defined;
7. an ADR records the decision;
8. implementation remains separately authorized.

A status-alignment update may record verified implementation without reopening the architecture decision.

Future enhancements are tracked through accepted ADRs and future architecture revisions.

Implementation must never silently become the architecture authority.
