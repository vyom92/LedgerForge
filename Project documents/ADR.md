# LedgerForge – Architecture Decision Records (ADR)

This document records significant architectural decisions made during the development of LedgerForge.

Each ADR captures:
- The problem.
- The decision.
- The reasoning.
- The long-term consequences.

These records explain *why* the architecture evolved the way it did.

---

# ADR-001 — Offline-First Architecture

## Status
Accepted

## Decision
LedgerForge is designed as an offline-first application. All core functionality must work without an internet connection. Online services are optional enhancements rather than dependencies.

## Rationale
- Privacy.
- Reliability.
- Fast local performance.
- Suitable for travel and limited-connectivity environments.

## Consequences
- SQLite is the primary data store.
- Import, categorization and reporting remain fully functional offline.
- Cloud synchronization can be added later without changing the core architecture.

---

# ADR-002 — Dashboard-First Product

## Status
Accepted

## Decision
The dashboard is the primary product experience. Document import, OCR and parsing are supporting services that keep financial information accurate.

## Rationale
Users open LedgerForge to understand their finances, not to import files.

## Consequences
All new features should improve the dashboard, reduce manual work or increase confidence.

---

# ADR-003 — Generic Import Engine

## Status
Accepted

## Decision
The import pipeline should rely on reusable architectural components (ImportCoordinator, Document Reader, Institution Detection, Statement Classification, Parser Selection, Statement Parser and Validation) instead of institution-specific workflows.

## Rationale
Supporting new financial institutions should primarily require new parser profiles and document mappings rather than new import pipelines.

## Consequences
The codebase remains scalable as supported institutions grow.

---

# ADR-004 — Explainable Automation

## Status
Accepted

## Decision
Every automatic classification, categorization or recommendation must be explainable, inspectable and reversible.

## Rationale
Financial software depends on user trust.

## Consequences
Rules, AI assistance and automation must expose the reasoning behind every decision.

---

# ADR-005 — Import Profiles

## Status
Accepted

## Decision
Statement formats are represented by reusable Import Profiles instead of embedding institution-specific assumptions throughout the codebase.

## Rationale
Financial institutions evolve their exports over time. Profiles allow LedgerForge to adapt without continually rewriting parsers.

## Consequences
- New institutions primarily require profile creation.
- Existing profiles can evolve independently.
- Future profile learning becomes possible.

---

# ADR-006 — Financial Dashboard as Single Source of Truth

## Status
Accepted

## Decision
Users interact primarily with the financial dashboard. Imports, OCR, parsing and automation exist solely to maintain an accurate financial model behind the dashboard.

## Rationale
The product's value is understanding finances, not importing documents.

## Consequences
Development priorities should favour insights, automation and confidence over import-specific functionality.

---

# ADR-007 — Explain Before Automating

## Status
Accepted

## Decision
Every automated action, categorisation or recommendation should expose its reasoning before asking users to trust it.

## Rationale
Trust is earned through transparency, especially in financial software.

## Consequences
Rules, AI assistance and future learning systems must provide an audit trail explaining why decisions were made.

---

# ADR-008 — Multi-Currency Domain Model

## Status
Accepted

## Decision
Every monetary value in LedgerForge retains its native currency. Currency conversion is a derived presentation concern rather than a storage concern.

## Rationale
LedgerForge is designed to manage financial data across multiple countries, institutions and currencies. Preserving imported values prevents loss of financial accuracy and enables transparent historical reporting.

## Consequences
- Monetary values should ultimately be represented by a dedicated Money value type.
- Exchange rates are stored separately from imported financial data.
- Dashboards and reports may present multiple display currencies simultaneously.
- Imported financial values are never overwritten after conversion.

---

# ADR-009 — Reactive Store Architecture

## Status
Accepted

## Decision
Application state is owned by stores. ViewModels observe stores and prepare presentation data. Views display state and do not coordinate business workflows.

## Rationale
Separating ownership, business logic and presentation improves maintainability and keeps SwiftUI views simple.

## Consequences
- TransactionStore owns imported transactions.
- AccountStore owns accounts.
- ViewModels observe published state.
- Views contain presentation only.

---


# ADR-010 — Validation Before Persistence

## Status
Accepted

## Decision
Imported financial data must successfully pass structural and financial validation before becoming trusted application data.

## Rationale
Incorrect financial data is more damaging than delayed imports. Validation should detect inconsistencies as early as possible.

## Consequences
- Validation is a mandatory stage of the import pipeline.
- Import sessions record validation outcomes.
- Dashboard metrics should only be derived from validated financial data.

---

# ADR-011 — Unified FinancialDocument Pipeline

## Status
Accepted

## Decision
All supported import formats (PDF, CSV, XLS, XLSX and TXT) must converge into a common deterministic import pipeline. The precise ordering of downstream architectural stages is defined by ADR-016 and subsequent ADRs.

## Rationale
Keeping downstream components independent of file formats dramatically simplifies parser development, testing and long-term maintenance.

## Consequences
- Readers understand file formats only.
- Downstream processing remains independent of the original file format.
- New import formats require only a new Reader implementation.
- Validation and stores remain format-independent.

---

# ADR-012 — Separation of Readers and Parsers

## Status
Accepted

## Decision
Readers extract document content. Parsers interpret financial meaning. These responsibilities must never overlap.

## Rationale
Extraction and interpretation change for different reasons. Separating them reduces coupling and allows new document formats without rewriting financial parsers.

## Consequences
- Readers contain no business logic.
- Parsers never perform file I/O.
- Institution Detection and Statement Classification operate on extracted content.

---

# ADR-013 — Store Ownership

## Status
Accepted

## Decision
Application state is owned exclusively by dedicated stores.

## Rationale
Single ownership prevents duplicated state and inconsistent dashboard calculations.

## Consequences
- TransactionStore owns transactions.
- AccountStore owns accounts.
- Future stores (InvestmentStore, ExchangeRateStore, etc.) own their respective domains.
- Views and ViewModels never duplicate store state.

---

# ADR-014 — Document-First Architecture

## Status
Accepted

## Decision
LedgerForge is a financial document ingestion platform rather than a CSV import application.

## Rationale
Every supported institution provides financial documents in one or more formats. The product should treat all supported formats as equivalent entry points into the same import pipeline.

## Consequences
- PDF becomes a first-class import source.
- CSV, XLS, XLSX and TXT follow the same pipeline.
- Institution-specific behaviour belongs in parsers rather than readers.

---

# ADR-015 — Automatic Password Management

## Status
Accepted

## Decision
Encrypted financial documents should be unlocked automatically using institution-specific credentials stored securely on the device whenever possible.

## Rationale
Most financial institutions consistently use the same password pattern for monthly statements. Requiring manual password entry for every import unnecessarily interrupts the workflow.

## Consequences
- Password management belongs to the import coordination layer.
- Passwords are stored securely using the operating system's secure credential storage.
- Readers receive an optional password supplied by the import coordination layer and never access Keychain, UI prompts or password policy directly.
- Users are prompted only when no stored credential succeeds.

---

# ADR-016 — Universal Import Pipeline

## Status
Accepted

## Decision

Every imported financial document must follow the same deterministic processing pipeline regardless of its original file format.

The canonical import flow is:

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
User Review & Explicit Confirmation
↓
Fingerprinting & Duplicate Detection
↓
Repository Persistence Boundary
↓
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

## Rationale

A single deterministic pipeline keeps business logic independent of file formats while allowing new document types to be supported with minimal architectural change.

Readers are responsible only for extracting document content.

Everything after `RawDocument` is format-independent.

## Consequences

- CSV, PDF, XLS, XLSX and TXT share the same downstream pipeline.
- Password resolution is coordinated before document extraction and supplied to readers through the import framework.
- Duplicate detection works across different file formats representing the same financial statement.
- Validation remains centralized.
- Stores receive only validated domain objects.

This ADR extends ADR-011 by defining the complete document ingestion workflow.
ADR-011 introduced the concept of a unified downstream pipeline. ADR-016 defines the canonical ordering of that pipeline and supersedes any earlier ordering assumptions.
---

# ADR-017 — Deterministic Before Intelligent

## Status
Accepted

## Decision

LedgerForge always prefers deterministic processing over AI-assisted inference whenever sufficient structured information is available.

Artificial intelligence may enhance the import pipeline but never replaces deterministic parsing or financial validation.

## Rationale

Financial software must remain reproducible, explainable and auditable.

Structured documents should be processed using deterministic rules. AI should only assist with:

- OCR recovery
- Ambiguous layouts
- Unsupported document formats
- Future parser generation
- User-assisted categorisation

## Consequences

- Validation never depends on AI.
- AI suggestions must remain explainable.
- Existing parsers always take precedence over inference.
- OCR integrates before parser selection rather than replacing parsers.
- AI outputs remain advisory until validated by deterministic business rules.
- AI never becomes the financial source of truth.
---

# ADR-018 — Unified Import Framework Operational

## Status

Accepted

## Implemented In

Sprint 11C

## Decision

Production CSV imports now execute through the Unified Import Framework.

The canonical production import flow is:

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
User Review & Explicit Confirmation
↓
Fingerprinting & Duplicate Detection
↓
Repository Persistence Boundary
↓
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

The migration preserved existing CSV business logic. Only orchestration changed.

## Rationale

The Unified Import Framework was introduced incrementally across earlier sprints to minimise migration risk.

Sprint 11C completed the production migration by routing CSV imports through the framework while preserving identical observable behaviour, verified by regression tests.

This establishes a single extensible architecture for every supported import format.

## Consequences

- CSV becomes the reference implementation for the Unified Import Framework.
- Future readers (PDF, XLS, XLSX and TXT) integrate through `ReaderRegistry` without changing downstream business logic.
- `ImportCoordinator` owns orchestration responsibilities.
- Readers remain responsible only for document extraction.
- Parsers remain responsible only for financial interpretation.
- Existing regression fixtures define the approved observable financial behaviour across future import formats.
- Future architectural work should extend the framework rather than introduce parallel import pipelines.

## Related ADRs

- ADR-003 — Generic Import Engine
- ADR-011 — Unified FinancialDocument Pipeline
- ADR-012 — Separation of Readers and Parsers
- ADR-015 — Automatic Password Management
- ADR-016 — Universal Import Pipeline
- ADR-017 — Deterministic Before Intelligent

---

# ADR-019 — Reference Fixtures Define Financial Truth

## Status

Accepted

## Implemented In

Sprint 12A

## Decision

Approved regression fixtures define LedgerForge's observable financial truth.

The Axis Bank NRE CSV fixture, matching Axis Bank NRE PDF fixture and shared expected JSON baseline represent the same financial statement and must remain financially equivalent.

Future readers, parsers and import pipelines must produce equivalent observable results from equivalent source documents unless an intentional behavioural change is explicitly approved.

## Rationale

LedgerForge supports multiple document formats for the same financial data. CSV, PDF and future XLS/XLSX inputs may represent the same statement, but extraction details differ by format.

Using approved reference fixtures creates a deterministic financial baseline that protects against silent parser, reader or validation regressions.

## Consequences

- The statement, not the file format, is the unit of financial truth.
- Equivalent CSV and PDF fixtures should share the same expected financial baseline when they represent the same statement.
- Reader implementations must not introduce financial interpretation differences.
- Parser and validation changes must be checked against approved fixtures.
- New institutions should add approved source documents and expected outputs before parser behaviour is treated as stable.
- Test fixtures are part of the architecture, not disposable test data.

## Related ADRs

- ADR-010 — Validation Before Persistence
- ADR-011 — Unified FinancialDocument Pipeline
- ADR-012 — Separation of Readers and Parsers
- ADR-017 — Deterministic Before Intelligent
- ADR-018 — Unified Import Framework Operational

---

# ADR-020 — Deterministic Institution Detection

## Status

Accepted

## Implemented In

Sprint 12C

## Decision

Institution Detection is a dedicated architectural stage within the import pipeline.

Detection operates exclusively on extracted document content and is independent of the original file format.

Institution Detection executes after document extraction and before Statement Classification.

Parser Selection consumes the results of both Institution Detection and Statement Classification.

Unknown documents must remain unknown unless deterministic evidence is sufficient to identify an institution.

Institution Detection must remain:

- Deterministic
- Explainable
- Repeatable
- Format-independent

Artificial intelligence must not participate in institution identification.

## Rationale

The same financial institution may provide statements in multiple formats, including CSV, PDF and future XLS/XLSX documents. Identifying the institution should therefore depend on document content rather than the transport format.

Separating Institution Detection from parser selection keeps responsibilities independent, allows new readers without architectural changes, and prevents parser-specific assumptions from leaking into document extraction.

Deterministic rules preserve reproducibility, simplify regression testing and ensure users can understand why a document was attributed to a particular institution.

## Consequences

- Institution Detection becomes a permanent architectural stage.
- Readers remain responsible only for document extraction.
- Statement Classification and Parser Selection remain downstream consumers of the detected institution.
- Unknown documents remain explicitly unknown rather than guessed.
- Detection decisions should expose sufficient reasoning for debugging and future inspection.
- Approved CSV and PDF reference fixtures verify identical institution detection behaviour across supported formats.
- Legacy institution detection behaviour must be preserved during framework evolution.

## Related ADRs

- ADR-003 — Generic Import Engine
- ADR-011 — Unified FinancialDocument Pipeline
- ADR-012 — Separation of Readers and Parsers
- ADR-016 — Universal Import Pipeline
- ADR-017 — Deterministic Before Intelligent
- ADR-018 — Unified Import Framework Operational
- ADR-019 — Reference Fixtures Define Financial Truth
---

# ADR-021 — Deterministic Statement Classification

## Status

Accepted

## Implemented In

Sprint 13

## Decision

Statement Classification is a dedicated architectural stage that executes after Institution Detection and before Parser Selection.

Statement Classification determines the document type (for example, bank statement, credit card statement or unknown) using deterministic rules derived from extracted document content.

Classification must remain:

- Deterministic
- Explainable
- Repeatable
- Independent of file format

Unknown documents must remain classified as unknown until sufficient deterministic evidence exists.

Artificial intelligence must not participate in statement classification.

## Rationale

Institution Detection identifies who produced the document.

Statement Classification identifies what type of financial document it is.

Separating these responsibilities keeps parser selection deterministic while allowing future document types to be introduced without changing reader implementations.

## Consequences

- Statement Classification becomes a permanent architectural stage.
- Parser Selection consumes both Institution Detection and Statement Classification.
- Readers remain responsible only for document extraction.
- Institution Detection remains independent from document type.
- Unknown classifications remain explicit rather than inferred.
- Approved regression fixtures verify identical classification behaviour across supported formats.
- Existing production behaviour remains unchanged until downstream pipeline stages explicitly adopt Statement Classification.
- Statement Classification provides a stable architectural input to Parser Selection without changing parser behaviour.

## Related ADRs

- ADR-003 — Generic Import Engine
- ADR-011 — Unified FinancialDocument Pipeline
- ADR-012 — Separation of Readers and Parsers
- ADR-016 — Universal Import Pipeline
- ADR-017 — Deterministic Before Intelligent
- ADR-018 — Unified Import Framework Operational
- ADR-019 — Reference Fixtures Define Financial Truth
- ADR-020 — Deterministic Institution Detection
---

# ADR-022 — Preview Compatibility During Test Builds

## Status

Accepted

## Implemented In

Sprint 18

## Decision

LedgerForge may use legacy SwiftUI `PreviewProvider` declarations instead of the newer `#Preview` macro when the macro prevents command-line or automated test builds from compiling.

This is a preview-only compatibility decision. It must not alter runtime UI behaviour, repository architecture, import behaviour, validation behaviour, persistence behaviour or test expectations.

This decision is intentionally conservative and exists solely to preserve deterministic automated validation while the current Xcode toolchain exhibits Preview macro compilation issues.

The preferred preview declaration for affected files is:

```swift
struct ExampleView_Previews: PreviewProvider {
    static var previews: some View {
        ExampleView()
    }
}
```

The `#Preview` macro may be reconsidered in a future sprint only after the active Xcode toolchain reliably supports command-line and automated test compilation without triggering `PreviewsMacros.SwiftUIView` failures.

## Rationale

Sprint 18 validation was blocked because `xcodebuild test` compiled production SwiftUI view files and failed while expanding the external `#Preview` macro before any Sprint 18 test assertions could run.

Investigation showed that scheme-only, test-target-only and build-setting-only workarounds did not prevent preview macro expansion. A controlled single-file experiment converted `ContentView.swift` from `#Preview` to `PreviewProvider`; the failure moved to the remaining preview files, confirming the root cause.

Using `PreviewProvider` preserves Xcode preview functionality while avoiding the failing macro expansion path during test builds.

## Consequences

- Preview compatibility is allowed as a production-source-affecting but runtime-neutral change.
- This decision must not be used to justify UI, repository, import, validation or persistence changes.
- Future use of `#Preview` should be avoided until the toolchain issue is verified as resolved.
- Once the toolchain issue is resolved, `#Preview` may be reintroduced through a dedicated architectural review and regression validation.
- If `#Preview` is reintroduced, required regression validation must pass through the standard project workflow.
- The decision exists to unblock validation, not to change user-visible behaviour.

## Related ADRs

- ADR-010 — Validation Before Persistence
- ADR-016 — Universal Import Pipeline
- ADR-017 — Deterministic Before Intelligent
- ADR-018 — Unified Import Framework Operational
- ADR-019 — Reference Fixtures Define Financial Truth
- ADR-021 — Deterministic Statement Classification

---

# ADR-023 — Frozen UI/UX Architecture

## Status

Accepted

## Implemented In

Sprint 20, refined through Sprint 22 UI/UX asset freeze

## Decision

LedgerForge adopts a frozen UI/UX architecture in the same manner as the frozen backend architecture.

Visual structure, navigation, interaction patterns and primary layouts are defined by `UI_UX_v1.0_Frozen.md` together with approved assets stored under `Project documents/UI Assets/Approved/`.

`DesignBoard_v2.0.png` is the master UI reference. Individual approved assets define screen-level implementation details.

Implementation sprints must implement the approved UI specification rather than redesigning the application during development.

## Rationale

Repeated visual redesign during implementation creates inconsistent navigation, duplicated components and architectural drift.

Separating visual design from implementation allows UI decisions to be reviewed, approved and versioned independently from SwiftUI implementation.

This mirrors the successful approach used for `Architecture_v1.0_Frozen.md`.

## Consequences

- UI/UX becomes an architectural concern rather than an implementation concern.
- Approved UI assets become part of the project's architectural documentation.
- `Project documents/UI Assets/Approved/DesignBoard_v2.0.png` is the authoritative visual reference for future UI implementation.
- Future UI work must translate approved assets into SwiftUI rather than reinterpret layout, spacing, theme or navigation during implementation.
- Implementation sprints focus on translating approved designs into SwiftUI components.
- Significant UI changes require design review before implementation.
- New screens extend the approved application shell rather than replacing it.

## Related ADRs

- ADR-002 — Dashboard-First Product
- ADR-009 — Reactive Store Architecture
- ADR-013 — Store Ownership
- ADR-016 — Universal Import Pipeline
- ADR-022 — Preview Compatibility During Test Builds

---

# ADR-024 — Repository Hydration Boundary

## Status

Accepted

## Implemented In

Sprint 19, stabilised through Sprint 24

## Decision

RepositoryStoreHydrator is the only approved boundary for transferring persisted repository state into observable runtime stores.

The following is an abbreviated downstream summary of the canonical import pipeline:

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

Views, ViewModels and Runtime Stores must never read from or write to SQLite directly.

Runtime Stores may expose and transform hydrated state for presentation, but repositories remain the durable source of truth.

## Rationale

A single persistence-to-runtime boundary prevents duplicated hydration logic, inconsistent startup state and accidental bypassing of repository contracts.

It also keeps SwiftUI presentation code independent of persistence implementation details and makes restart behaviour deterministic and testable.

## Consequences

- RepositoryStoreHydrator owns startup and refresh hydration into Runtime Stores.
- Runtime Stores remain observable in-memory state, not persistence authorities.
- Repository implementations remain the only components permitted to access SQLite.
- New persisted domains must integrate through repositories and RepositoryStoreHydrator rather than creating parallel loading paths.
- Dashboard, account and transaction state restored after relaunch must originate from repository-backed hydration.
- ADR-016 and ADR-018 remain valid for the import pipeline, but their downstream `SQLite → Stores` shorthand is refined to `SQLite → RepositoryStoreHydrator → Runtime Stores`.

## Related ADRs

- ADR-009 — Reactive Store Architecture
- ADR-010 — Validation Before Persistence
- ADR-013 — Store Ownership
- ADR-016 — Universal Import Pipeline
- ADR-018 — Unified Import Framework Operational

---

# ADR-025 — Stable Financial Entity Identity

## Status

Accepted

## Implemented In

Sprint 25 stable-identity foundation; Sprints 32–35 verified-identifier foundation and parser extraction; Sprint 36 deterministic confirmed-import resolution

## Decision

LedgerForge models specific financial entities rather than treating a financial institution as the account identity.

Examples of separate financial entities include:

- Axis NRE account
- Axis NRO account
- HDFC NRE account
- HDFC NRO account
- CBQ current account
- CBQ investment or mutual-fund account
- Credit-card accounts
- Brokerage accounts
- Retirement accounts

Repository identifiers for financial entities are immutable.

Display names, institution labels and imported filenames are presentation or source metadata only and must never define durable identity or participate in account matching.

Future matching must rely on verified financial identifiers where available, including account numbers, IBANs, card identifiers, broker account IDs and future investment identifiers such as folio numbers.

## Rationale

A single institution may contain multiple unrelated accounts and product types. Institution-level or display-name matching can silently merge distinct financial histories or create duplicate accounts when names or filenames change.

Stable repository identity and verified identifiers provide a deterministic foundation for historical imports, overlap handling, duplicate prevention and cross-document reconciliation.

## Consequences

- Institution attribution remains metadata associated with a financial entity.
- Display names may evolve without changing repository identity.
- Filenames, institution names and display names must not be used as account-matching keys.
- Duplicate-prevention and historical-import work must preserve existing repository IDs.
- Verified strong identifiers are canonicalised and stored separately from presentation metadata; deterministic confirmed-import resolution uses only parser-produced verified strong identifiers.
- Documents and transactions attach to a financial entity rather than merely to an institution.
- Ambiguous identity must remain unresolved instead of being guessed.

## Related ADRs

- ADR-003 — Generic Import Engine
- ADR-004 — Explainable Automation
- ADR-008 — Multi-Currency Domain Model
- ADR-010 — Validation Before Persistence
- ADR-014 — Document-First Architecture
- ADR-017 — Deterministic Before Intelligent
- ADR-019 — Reference Fixtures Define Financial Truth
- ADR-020 — Deterministic Institution Detection
- ADR-021 — Deterministic Statement Classification
- ADR-024 — Repository Hydration Boundary

---

# ADR-026 — Structured Developer Diagnostics

## Status

Accepted

---

## Implemented In

Sprint 31 — Developer Diagnostics & Logging

---

## Context

Prior to Sprint 31, the Developer Console stored diagnostics as unstructured plain strings.

This made it difficult to:

- distinguish operational lifecycle events from implementation details
- classify diagnostics by subsystem
- filter meaningful information
- perform deterministic automated testing
- evolve developer tooling without affecting financial behaviour

The console had gradually become a mixture of informational messages, parser internals and debugging output without consistent semantics.

---

## Decision

LedgerForge shall use structured, in-memory diagnostic entries instead of plain string messages.

Every diagnostic entry shall contain:

- Stable identity
- Monotonic sequence number
- Timestamp
- Diagnostic level
- Diagnostic category
- Concise human-readable message
- Optional structured metadata

The initial diagnostic levels are:

- Debug
- Info
- Warning
- Error

The initial diagnostic categories are:

- Application
- Import
- Parser
- Validation
- Database
- Runtime

Levels describe severity.

Categories describe the subsystem responsible for the event.

These concepts must remain independent.

---

## Presentation

Stored diagnostic history remains chronological.

Presentation may display entries newest-first without modifying stored order or sequence numbers.

Debug diagnostics remain hidden by default.

The default Developer Console should present concise operational lifecycle events.

Low-level implementation details belong in Debug diagnostics.

---

## Architectural Constraints

Developer diagnostics shall remain:

- in-memory only
- presentation focused
- deterministic
- independent of repositories
- independent of runtime stores
- independent of SQLite

Developer diagnostics must never become:

- a persistence mechanism
- a financial source of truth
- a replacement for RepositoryStoreHydrator
- a replacement for repository history

---

## Rationale

Separating diagnostic severity from subsystem classification produces significantly clearer operational information.

Structured diagnostics enable:

- deterministic filtering
- deterministic testing
- concise lifecycle reporting
- richer future developer tooling

without affecting LedgerForge's financial architecture.

Keeping diagnostics ephemeral prevents accidental architectural coupling between developer tooling and business data.

---

## Consequences

Positive:

- deterministic filtering
- deterministic searching
- concise import lifecycle
- parser internals isolated to Debug
- improved automated testing
- easier future tooling
- consistent Copy All formatting

Negative:

- slightly more complex diagnostic model
- migration of existing logging call sites
- additional UI filtering logic

Accepted trade-off:

The increase in implementation complexity is justified by substantially improved developer usability and maintainability.

---

## Non-Goals

This ADR does **not** introduce:

- persistent log storage
- log export
- analytics
- performance profiling
- repository inspection
- SQL browsing
- parser debugging
- duplicate inspection

Those capabilities require future ADRs.

---

## Related ADRs

- ADR-004 — Explainable Automation
- ADR-007 — Explain Before Automating
- ADR-009 — Reactive Store Architecture
- ADR-013 — Store Ownership
- ADR-017 — Deterministic Before Intelligent
- ADR-023 — Frozen UI/UX Architecture
- ADR-024 — Repository Hydration Boundary

---

## Acceptance Evidence

ADR-026 was accepted after:

- Sprint 31 implementation was completed.
- Automated validation passed.
- Manual runtime verification passed.
- Sprint 31 was recorded in `PROJECT_STATE.md`.

---

# ADR-027 — Parser-Owned Financial Identifier Extraction

## Status

Accepted

---

## Implemented In

Sprint 33 FinancialDocument identifier handoff; Sprint 35 approved Axis identifier extraction; Sprint 36 resolver integration

---

## Context

Sprint 32 introduced the canonical `FinancialIdentifier` domain model, workspace-scoped repository APIs and deterministic `FinancialIdentityResolver`.

The completed Financial Identifier Architecture Discovery confirmed that production imports do not currently produce verified `FinancialIdentifier` values. `FinancialDocument` carries parsed transactions and document metadata, but it does not carry structured financial identifiers, verification state or identifier provenance.

The architecture discovery evaluated four candidate architectures for identifier extraction:

- extraction inside `StatementParser` implementations
- a downstream `IdentifierExtractor` operating after `FinancialDocument` creation
- extraction inside `ImportEngine`
- extraction inside `ImportPersistenceCoordinator`

Financial identifier extraction must remain deterministic, explainable and specific to the statement structure understood by the selected parser. Duplicate parsing systems and heuristic reconstruction from filenames, display names, institution labels, account text or other weak values must be avoided.

---

## Decision

1. Verified `FinancialIdentifier` objects SHALL originate exclusively inside `StatementParser` implementations.

2. Statement parsers are the only components permitted to classify an identifier as verified.

3. `FinancialDocument` SHALL carry an immutable collection of `FinancialIdentifier` values produced by the parser.

4. `ImportEngine` SHALL NOT derive identifiers.

5. `ImportPersistenceCoordinator` SHALL NOT extract identifiers.

6. `FinancialIdentityResolver` SHALL consume parser-produced identifiers only.

7. Weak parser-derived values, including display names, filenames, institution labels, account text, masked values and suffixes, SHALL NOT be promoted to verified identifiers.

---

## Consequences

Positive consequences:

- A single source of truth owns financial identifier extraction and verification.
- No duplicated parsing system is introduced.
- Identifier generation remains deterministic and explainable.
- Parser-level tests can validate identifier extraction alongside financial interpretation.
- The architecture scales naturally to brokers, investment accounts and other institution-specific financial entities.
- Existing repository contracts remain unchanged.
- The SQLite schema remains unchanged.

Trade-offs:

- `FinancialDocument` must be extended before parser-produced identifiers can flow through the import pipeline.
- Existing parsers require incremental updates to produce supported identifiers.
- Financial Identity integration can occur only after the relevant parser supports identifier extraction.

---

## Alternatives Considered

### Parser → FinancialDocument → IdentifierExtractor

Rejected.

This creates a second parsing system after the statement parser has already interpreted the source document. It duplicates institution-specific knowledge and risks inconsistent financial and identity interpretation.

### ImportEngine Extraction

Rejected.

`ImportEngine` owns orchestration. Identifier extraction would introduce institution-specific parsing responsibility into the orchestration layer.

### ImportPersistenceCoordinator Extraction

Rejected.

The persistence coordinator operates after parsing and validation. Extracting identifiers there would encourage heuristic reconstruction from already-reduced metadata and would mix persistence coordination with document interpretation.

---

## Non-Goals

This ADR does not:

- integrate `FinancialIdentityResolver`
- change repository behaviour
- modify parser behaviour
- introduce UI
- introduce schema migrations
- implement account reuse

Those changes belong to future implementation sprints.

---

## Related ADRs

- ADR-025 — Stable Financial Entity Identity
- ADR-026 — Structured Developer Diagnostics

---

# ADR-028 — Bounded Parser Source Evidence

## Status

Accepted

## Implemented In

Sprint 34

---

⸻

Context

LedgerForge separates document extraction from financial interpretation.

Under ADR-012, readers extract source content and parsers interpret its financial meaning. Parsers must not perform file I/O.

Under ADR-027, verified FinancialIdentifier values originate exclusively inside StatementParser implementations. Generic orchestration, normalization and persistence components must not derive or verify identifiers.

The current CSV import path retains the complete extracted text while preparing an import. CSVAnalyzer identifies the structural location of the first transaction, and CSVNormalizer creates normalized transaction rows beginning at that boundary.

However, the existing NormalizedDocument parser input contains only:

* the analyzed Document
* DocumentMetadata
* normalized transaction rows

Source evidence appearing before the first transaction is therefore omitted from the parser handoff.

The evidence has not been destroyed. It remains available during generic format processing but is not represented in the parser input.

A parser requires bounded access to this evidence to deterministically interpret institution-specific values such as full account identifiers. Moving that interpretation into generic processing would violate the existing reader, parser and identifier-ownership boundaries.

⸻

## Decision

Parser source evidence

Format-processing components may transport bounded, uninterpreted source evidence into NormalizedDocument.

NormalizedDocument shall expose an immutable sourceContext.

The context shall contain ordered source fragments that appeared structurally before the first transaction.

For line-oriented extracted text, every fragment shall contain:

* the exact textual content of one extracted source line, excluding its newline delimiter
* its one-based ordinal within the extracted source text

The context shall preserve:

* empty lines
* original source ordering
* exact extracted line content
* one-based source ordinals

The first transaction and every later source line shall be excluded.

A transaction header appearing before the first transaction may be included because the boundary is structural rather than semantic.

Interpretation ownership

Source context is evidence only.

Generic readers, analyzers, normalizers and orchestration components shall not:

* assign financial meaning to source fragments
* search for institution-specific account labels
* construct FinancialIdentifier values
* classify identifier verification
* promote weak or masked values
* embed institution-specific source-context fields

Only the selected StatementParser may interpret the transported evidence.

Only the parser may produce or verify a FinancialIdentifier, as required by ADR-027.

Lifetime and privacy

Source context shall remain transient parser-input data.

It shall not be stored in:

* Document
* PreparedImport
* FinancialDocument
* import sessions
* repositories
* SQLite
* runtime stores
* diagnostics
* analytics

Source-fragment text shall not be logged.

The context is bounded by the first-transaction structural boundary. The complete source document and post-boundary transaction content shall not be duplicated into the context.

## Compatibility

Existing NormalizedDocument construction shall remain source-compatible by defaulting sourceContext to an empty value.

CSV normalization shall expose a result containing both normalized rows and source context.

The existing row-only normalization method shall remain available as a compatibility wrapper.

Production CSV import shall obtain rows and context from one normalization operation.

Conformance restraint

New source-context and normalization-result types shall receive only the protocol conformances required by production behaviour.

Equatable, Codable, Sendable, or other conformances shall not be added automatically for test convenience.

Tests shall inspect stored fields directly.

⸻

Rationale

This decision transports existing source evidence without moving financial interpretation into the generic import pipeline.

It preserves the established boundaries:

* readers extract
* format processing identifies structure
* parsers interpret financial meaning
* parsers alone verify financial identifiers
* persistence stores only approved downstream domain data

A bounded context avoids storing the complete document in long-lived models while still providing parsers with deterministic evidence.

The design remains format-neutral. Future PDF, XLS, XLSX, or TXT processing may provide equivalent bounded source fragments without introducing institution-specific meaning into format-processing components.

Retaining the row-only normalization API avoids unnecessary migration across existing callers and tests.

⸻

## Consequences

Positive consequences

* Parsers can receive source evidence without reopening files.
* ADR-012 remains intact.
* ADR-027 identifier ownership remains intact.
* No duplicate institution-specific parsing system is introduced.
* Existing normalized transaction rows remain unchanged.
* Existing NormalizedDocument construction remains source-compatible.
* Existing row-only normalization callers remain source-compatible.
* Source evidence has an explicit and testable lifetime.
* Future formats can use the same parser-input principle.
* Source-fragment preservation can be tested deterministically.

Trade-offs

* NormalizedDocument gains a small transient source-context model.
* CSV normalization gains a composite result type.
* ImportEngine must transport one additional uninterpreted value.
* Pre-transaction source content temporarily occupies additional memory.
* Future format implementations must define an equivalent structural boundary before populating source context.

ADR-028 establishes the permanent contract for transporting parser source evidence. Future formats shall implement equivalent structural evidence while preserving parser ownership of financial interpretation.

⸻

Alternatives Considered

Store the complete extracted text in Document

Rejected.

Document describes analyzed source structure and currently survives beyond the immediate normalization operation. Attaching complete source text would broaden its responsibility, lengthen sensitive-data lifetime, and duplicate content already held during import preparation.

Store source context in PreparedImport

Rejected.

The parser requires evidence before PreparedImport is created. Retaining the context afterward would unnecessarily extend its lifetime beyond parsing.

Allow parsers to reopen Document.url

Rejected.

Parser file I/O violates ADR-012, duplicates reader behaviour, complicates password handling, and makes parser execution dependent on external file availability.

Extract identifiers in ImportEngine

Rejected.

ImportEngine owns orchestration and must remain institution-neutral. Identifier interpretation there would violate ADR-027.

Extract identifiers in persistence coordination

Rejected.

Persistence operates after parsing and validation. It lacks the complete source meaning and must not reconstruct identity from reduced metadata.

Replace the existing normalization API

Rejected.

Replacing the row-only return type would force an unnecessary migration across existing callers and tests. A new composite-result operation with a compatibility wrapper provides the required production path without breaking established call sites.

Add institution-specific fields to source context

Rejected.

Fields such as accountNumber, iban, customerId, verifiedIdentifier, or institution-specific labels would move interpretation outside the parser and violate ADR-027.

⸻

## Non-Goals

This ADR does not:

* extract any financial identifier
* modify StatementParser protocol
* integrate FinancialIdentityResolver
* perform account matching or account reuse
* attach identifiers to repositories
* change persistence
* change SQLite
* change readers
* implement PDF source context
* change financial calculations
* introduce user-facing behaviour
* add source-fragment logging
* establish a maximum arbitrary line or character count beyond the structural first-transaction boundary

Those changes require separate implementation decisions and sprints.

⸻

## Related ADRs

* ADR-003 — Generic Import Engine
* ADR-011 — Unified FinancialDocument Pipeline
* ADR-012 — Separation of Readers and Parsers
* ADR-016 — Universal Import Pipeline
* ADR-017 — Deterministic Before Intelligent
* ADR-019 — Reference Fixtures Define Financial Truth
* ADR-025 — Stable Financial Entity Identity
* ADR-026 — Structured Developer Diagnostics
* ADR-027 — Parser-Owned Financial Identifier Extraction

# ADR-029 — User-Confirmed Financial Identifier Attachment

## Status

Accepted

## Implemented In

Sprint 38

## Context

ADR-025 establishes immutable repository account identity and prohibits matching by display name, institution label or filename. ADR-027 establishes that verified financial identifiers originate exclusively inside the selected `StatementParser`. ADR-028 establishes the bounded source-evidence path that permits parsers to interpret institution-specific account fields without moving interpretation into generic import processing.

Sprint 36 integrates deterministic confirmed-import resolution. A parser-produced verified strong identifier can resolve an account that already owns that identifier. A `noMatch` outcome creates a new opaque account and seeds its identity. An existing account that has no identifier cannot be selected by the resolver because no verified repository relationship connects the new identifier to that account.

The missing capability is a narrowly bounded user decision for a validated, still-uncommitted import: the user may choose whether one eligible parser-produced verified strong identifier should be attached to one existing unseeded account or whether the current create-new-account path should remain in effect.

This decision must not become heuristic account matching, an account merge, a transaction movement operation or a general identity-conflict workflow.

## Decision

1. Statement parsers remain the only components permitted to produce or verify `FinancialIdentifier` values.

2. `FinancialIdentityResolver` remains deterministic and continues to return `resolved`, `noMatch`, `ambiguous` or `conflict` based only on parser-produced verified strong identifiers and workspace-scoped repository lookup.

3. User confirmation is permitted only for the narrowly defined `noMatch` path after validation has passed.

4. Sprint 38 applies only when exactly one parser-produced identifier is eligible, its strength is `.strong`, its verification state is `.verified`, and it originated from the selected parser under ADR-027.

5. The user must choose exactly one outcome: **Use Existing Account** or **Create New Account**. No account may be selected automatically, including when only one eligible account is available.

6. Pre-confirmation eligibility is advisory presentation state only. It must not attach identifiers, create accounts, persist import sessions or transactions, mutate repositories, mutate runtime stores or act as confirmation-time authority.

7. Immediately before repository writes, the existing confirmed import-persistence boundary must re-run identity resolution and revalidate the identifier set, the explicit user outcome, workspace ownership, selected-account existence and selected-account eligibility.

8. **Use Existing Account** requires an immutable repository account ID. The selected account must belong to the configured workspace and remain unseeded, meaning it has no stored identifier of any strength, verification state or provenance. The identifier must not already be owned by another account.

9. For **Use Existing Account**, the existing account record and financial relationships must be preserved. Replacement-style account upsert must not be used for the selected account. Imported transactions must use the selected immutable account ID.

10. The one eligible parser-produced verified strong identifier is attached inside the existing confirmed import-persistence boundary. Parser provenance remains unchanged; user confirmation authorizes the account association and does not re-verify or reclassify the identifier.

11. **Create New Account** retains the existing opaque account-ID policy, current no-match revalidation and current account, identifier, import-session and transaction persistence workflow.

12. Runtime state changes only after the complete persistence outcome succeeds. One canonical forced hydration through `RepositoryStoreHydrator` follows successful persistence. No second persistence-to-runtime path is introduced.

13. The successful result may present the selected or newly created account, a safely redacted identifier, persisted transaction count, import-session result and a **View Account** action. The action selects the account by immutable repository account ID.

14. Raw identifiers, raw parser source evidence, repository IDs as financial identity and unredacted identifier values in diagnostics remain prohibited.

15. The existing non-atomic persistence limitation remains accepted. This ADR does not introduce rollback, compensation, cross-repository atomicity, identifier removal, account merge, account split or historical transaction movement.

## Rationale

The resolver cannot safely infer which unseeded account owns a newly observed identifier. User confirmation is the only additional authority permitted for this narrow case, and it is explicit, reviewable and bounded by parser verification, workspace ownership, an unseeded target and final repository revalidation.

Keeping the operation inside confirmed import persistence preserves validation-before-persistence, prevents cancellation from writing identity or financial data, reuses the existing account-ID mapper path and keeps identity attachment adjacent to the import it authorizes.

Using immutable repository account IDs prevents display metadata or runtime presentation identity from becoming durable account identity. Preserving parser provenance keeps identifier verification ownership unambiguous.

## Consequences

Positive consequences:

- A user can prevent a new duplicate account when a verified import has no existing identifier match.
- Existing accounts, identifiers, transactions and import-session relationships remain attached to their immutable repository identities.
- Existing resolver, mapper, repository and hydration boundaries remain reusable.
- Weak evidence cannot silently create an identity association.
- Ambiguous and conflicting identity remains unresolved.
- The successful account can be verified through the existing hydrated Accounts experience.

Trade-offs:

- A user can make an incorrect association; this ADR therefore limits the target to an unseeded account and requires explicit confirmation.
- The current repository sequence remains non-atomic. An early successful identifier write may survive a later import-session or transaction failure.
- Durable confirmation audit, unlinking and incorrect-link recovery are not provided by this decision.
- The workflow prevents future duplicate accounts but does not detect or repair duplicate financial history.

## Rejected Alternatives

### Automatically choose the first eligible account

Rejected. Eligibility does not prove ownership, and deterministic ordering is not identity evidence.

### Match through display name or institution

Rejected. ADR-025 reserves those values for presentation and metadata; they are not durable identity keys.

### Attach before explicit confirmation

Rejected. Preparation and cancellation must remain write-free, and advisory review must not become an implicit repository mutation.

### Trust stale pre-confirmation eligibility

Rejected. Repository state may change between review and confirmation. Current resolver and account eligibility must be authoritative immediately before writes.

### Move identifier verification outside parsers

Rejected. ADR-027 assigns identifier production and verification exclusively to `StatementParser` implementations.

### Perform repository writes from a View or ViewModel

Rejected. Repository writes remain inside the import-persistence boundary, and persistence-to-runtime updates remain behind `RepositoryStoreHydrator`.

### Repair duplicate history through this workflow

Rejected. Duplicate transaction detection, account merge, transaction movement, deletion and rollback require separate architecture and explicit recovery safeguards.

## Non-Goals

This ADR does not:

- change parser inputs or parser verification rules;
- derive identifiers from filenames, names, institutions, balances, suffixes, masked values or transactions;
- override resolved, ambiguous or conflicting resolver outcomes;
- implement identifier removal or editing;
- implement manual account linking or unlinking beyond this narrow attachment;
- implement account merge, split or incorrect-link recovery;
- move or deduplicate historical transactions;
- introduce duplicate-transaction detection;
- introduce schema migrations or DTO redesign;
- introduce cross-repository atomic persistence or rollback;
- change validation, financial calculations or runtime-store ownership;
- store source fragments in long-lived state, repositories, SQLite or diagnostics;
- expose raw identifiers in presentation state.

## Related ADRs

- ADR-024 — Repository Hydration Boundary
- ADR-025 — Stable Financial Entity Identity
- ADR-026 — Structured Developer Diagnostics
- ADR-027 — Parser-Owned Financial Identifier Extraction
- ADR-028 — Bounded Parser Source Evidence

# ADR-030 — Versioned Exact-Content Fingerprints and Atomic Import-History Commit

## Status

Accepted

Implemented in Sprint 39

## Context

LedgerForge currently permits a validated and explicitly confirmed statement to be imported again, even when the exact reader-produced text has already completed a successful import. Sprint 39 requires deterministic exact-content protection without introducing transaction-level heuristics, historical repair or a general import-history subsystem.

## Decision

### Exact duplicate semantics

For Sprint 39, an exact duplicate is the same fingerprint algorithm identifier paired with the same deterministic digest of reader-produced source content.

The initial algorithm identifier is `ledgerforge.raw-text.sha256.v1`. Its input is the exact UTF-8 byte sequence of `RawDocumentContent.text`, after successful document reading and before parsing, normalization or financial interpretation changes the content. Renaming or moving identical content must not change its fingerprint. Any change to decoded text, including line endings or whitespace, may produce a different fingerprint under version 1.

The fingerprint excludes filenames, source paths, file dates, import dates, institution labels, financial identifiers, account identity, parser selection, normalized rows, parsed transactions, balances, display metadata and generated UUIDs. Sprint 39 supports the production text-import path only; binary-data fingerprint semantics remain future work.

### Prospective-only compatibility

Sprint 39 exact-import protection is prospective. Import sessions completed before Sprint 39 contain no durable Sprint 39 fingerprint. Existing documents, sessions, accounts, identifiers and transactions are not backfilled or heuristically fingerprinted.

The first post-Sprint 39 import of content that exists only in legacy un-fingerprinted history may be treated as a new import and register the fingerprint. Subsequent imports of that exact content are blocked. Filename, path, institution, account identity, balances, transaction sets, transaction counts, dates and existing import-session metadata must not be used to reconstruct a legacy fingerprint. Historical detection and repair remain future work.

### Database-wide fingerprint scope

Under the existing schema, exact-content fingerprint uniqueness is database-wide. Sprint 39 operates under the current single-workspace product model and must not claim workspace-scoped fingerprint uniqueness. Independent import of identical content into multiple workspaces is not defined by Sprint 39.

Supporting workspace-scoped behaviour requires a separately approved workspace-scoped schema decision and migration. No migration is authorized in Sprint 39. The digest remains solely a function of exact source text and must not be salted with workspace identity.

### Ownership and lifecycle

Fingerprint generation belongs to generic import orchestration over reader-produced content. It does not belong to readers, statement parsers, normalizers, identity resolution, Views, ViewModels or transaction heuristics. The fingerprint is immutable and is carried by `PreparedImport` through explicit confirmation.

After validation passes, preparation may perform a read-only advisory duplicate lookup. Advisory state performs no writes, does not claim the fingerprint, is not confirmation-time authority and may display bounded prior-import information.

Immediately before supported import-persistence writes, the confirmed persistence boundary must enter the same-process serialized import-confirmation boundary, recompute or verify the immutable prepared fingerprint contract, perform an authoritative durable duplicate lookup and reject an existing successful fingerprint before account, identifier, import-session or transaction writes begin.

The same-process serialized confirmation boundary begins before the authoritative duplicate lookup and remains held until duplicate rejection completes, or until account and identifier persistence plus the atomic import-history commit complete or fail. It must not be released after lookup and reacquired for persistence. Account and identifier persistence remains outside the narrower atomic import-history transaction while remaining inside the same-process serialized confirmation execution; this ADR does not claim rollback of workspace, account or identifier writes.

Two identical confirmations within the running LedgerForge process must not both persist financial history. Cross-process, distributed and external-writer concurrency guarantees remain future work.

### Atomic import-history commit

A provider-owned operation must atomically commit the integrity-bearing import-history records: document, document fingerprint, import session, imported transactions and successful import-session completion state. SQLite writes these records in one database transaction. The in-memory provider supplies equivalent serialized all-or-nothing behaviour.

A failure inside this atomic operation leaves none of those records durable. The fingerprint becomes durable only as part of a successful import-history commit. Validation failure, cancellation and failed import-history commit leave no durable fingerprint.

This ADR does not create a general unit-of-work across every repository operation. Existing workspace, account and identifier persistence remains governed by prior ADRs. Full atomicity covering workspace, account, identifier, document, session and transactions remains future work.

### Durable duplicate result and presentation

A durable fingerprint lookup may return bounded prior-import provenance: prior import-session ID internally, prior successful completion date, prior persisted transaction count, prior account ID internally and prior account display name when recoverable. The fingerprint match remains authoritative even if optional presentation metadata cannot be reconstructed; missing account presentation must not permit re-import.

A duplicate is a distinct, non-error integrity outcome presented as “Previously imported” or equivalent, with prior date, transaction count and account display name when available, plus the existing View Account action when the account remains available. No new screen, import-history browser or duplicate-management workflow is authorized.

Duplicate rejection performs no runtime-store mutation and no forced hydration. A genuinely new successful import continues to trigger exactly one canonical forced hydration through `RepositoryStoreHydrator`.

### Privacy and diagnostics

User-visible presentation and diagnostics must not contain raw source content, full fingerprint values, raw financial identifiers or parser source evidence. Diagnostics may record only bounded facts such as the fingerprint algorithm version, duplicate found, import blocked and commit succeeded or failed.

## Rejected Alternatives

- Filename or path matching.
- Institution, account-name or identifier matching.
- Transaction-level heuristics or normalized-transaction fingerprints.
- Persisting a fingerprint reservation before the import without an atomic lifecycle.
- Recording the fingerprint after otherwise independent successful writes.
- Trusting advisory preparation results.
- Historical duplicate repair.
- Duplicate-management UI.
- Full Candidate E cross-repository unit-of-work expansion.

## Non-Goals

Sprint 39 does not include transaction-level duplicate detection, overlapping-statement detection, historical duplicate repair, account merge or split, transaction movement or reversal, import-session deletion, general import-history UI, parser, reader or normalizer changes, financial-calculation changes, runtime-store or hydrator redesign, binary-document equivalence, cross-format semantic equivalence, cross-process concurrency guarantees or a schema migration unless separately approved.

## Related ADRs

- ADR-003 — Generic Import Engine
- ADR-011 — Unified FinancialDocument Pipeline
- ADR-012 — Separation of Readers and Parsers
- ADR-016 — Universal Import Pipeline
- ADR-024 — Repository Hydration Boundary
- ADR-025 — Stable Financial Entity Identity
- ADR-026 — Structured Developer Diagnostics
- ADR-027 — Parser-Owned Financial Identifier Extraction
- ADR-029 — User-Confirmed Financial Identifier Attachment

---

# ADR-031 — Verified Transaction-Event Evidence and Pre-Write Duplicate Blocking

## Status

Accepted

Architecture prepared in Sprint 40; implemented in Sprint 41

## Context

ADR-030 prevents exact reader-produced text from being imported twice, but intentionally does not identify the same ledger event across independently generated overlapping statements. Sprint 40 compared two original Axis Bank CSV exports directly before sanitization.

The exports had the same privately verified structured full account identifier, different declared periods, a genuine overlap, 30 identical complete transaction rows and one later-only event. Shared rows retained exact source values and ledger order. Fifteen shared UPI rows retained the same structured 12-digit UPI reference without formatting changes. Recurring transaction patterns used distinct references.

The baseline contained 50 UPI rows and 49 unique UPI references. One reference was reused by two distinct ledger rows: a posting and a later credit adjustment with the same amount in the opposite direction. The token alone is therefore not a transaction-event identity. Deterministic source subtype is required.

IMPS references were stable in seven shared rows, and NEFT references were stable in two, but the supplied evidence did not establish sufficient subtype, reuse and format semantics to approve those families. E-commerce and unstructured rows did not expose an eligible strong reference. No genuine reversal or refund example was present.

The approved sanitized baseline remains byte-for-byte unchanged. Its earlier anonymization did not preserve the original posting/credit-adjustment token equality, so Sprint 40 records that privately verified relationship symbolically in the new expected specification rather than altering historical fixture truth.

## Decision

### Accepted evidence family

The only accepted Sprint 40 transaction-event evidence family is an Axis UPI reference produced by the Axis statement parser.

The proposed versioned algorithm identifier is:

`ledgerforge.transaction-event.axis-upi-reference.v1`

This identifier names the canonical contract. Sprint 40 does not implement it.

### Ownership

Only the selected Axis `StatementParser` may classify source fields as verified Axis UPI transaction-event evidence. Readers and normalizers may preserve exact source values but must not classify event identity. `ImportEngine`, persistence coordinators, repositories, runtime stores, ViewModels and Views must not reconstruct an event reference from narration.

### Required source evidence

A verified version 1 event requires all of:

1. a resolver-selected immutable repository account ID;
2. parser classification of the source row as Axis UPI;
3. an exact parser-supported UPI operation component, such as the observed person-to-account or person-to-merchant operation;
4. exactly 12 ASCII decimal digits in the observed Axis UPI reference component;
5. a deterministic parser-owned ledger subtype of `posting` or `credit-adjustment`.

Date, amount, direction, narration, running balance, cheque field, SOL, source row, filename and path are excluded from identity. They may remain bounded provenance or corroboration only.

### Scope

Version 1 is scoped to the resolver-selected immutable repository account. No institution-wide, payment-network-wide or cross-account uniqueness is claimed. Account display name, institution label and raw financial identifier are not canonical scope.

### Normalization and canonical serialization

- The family is the lowercase ASCII literal `axis-upi`.
- The parser-supported operation is converted to its exact lowercase ASCII enum value without fuzzy correction.
- The reference is preserved as exactly 12 ASCII digits. Whitespace, punctuation, digit insertion, digit removal and Unicode digit conversion are not permitted.
- The subtype is the lowercase ASCII literal `posting` or `credit-adjustment`.
- The immutable repository account ID is preserved exactly as its UTF-8 representation.

Canonical serialization is an ordered UTF-8 length-prefixed sequence of:

1. algorithm identifier;
2. immutable repository account ID;
3. family;
4. UPI operation;
5. 12-digit reference;
6. ledger subtype.

Each component is encoded as its decimal UTF-8 byte count, one ASCII colon, then the exact component bytes. Components are concatenated without optional fields. The privacy-safe durable representation is the lowercase hexadecimal SHA-256 digest of that canonical byte sequence paired with the algorithm identifier. Raw account identifiers, UPI references and canonical payloads must not be persisted for event-identity lookup, presentation or diagnostics.

### Missing and malformed evidence

A non-UPI row, a UPI row missing any required component, an unsupported operation, an unclassified subtype or a malformed reference produces no verified version 1 event evidence. Weak fields must not fill the gap, and hashing them does not strengthen them.

Absence of verified event evidence is not proof that an event is new. A later implementation must report the bounded coverage accurately and must not claim universal overlapping-statement safety.

### Reused-reference and related-event behavior

- The same account, operation, reference and subtype denotes the same version 1 event candidate.
- Posting and credit-adjustment rows sharing a reference are distinct events because subtype participates in canonical identity.
- If two distinct legitimate rows produce the same complete version 1 canonical identity, the result is a conflict. Date, amount, balance, narration or row order must not break the tie. The whole import must be blocked before writes and the family contract must return to architecture review.
- No reversal or refund subtype is approved in version 1 because the source evidence contained no genuine example. Such rows remain ineligible until a separately verified fixture and ADR amendment define their semantics.
- IMPS, NEFT, e-commerce, card and unstructured references are not aliases for Axis UPI evidence.

### Future authoritative flow

A later production sprint may implement this bounded flow:

```text
Axis StatementParser
        ↓
Verified Axis UPI event evidence
        ↓
Existing validation and explicit confirmation
        ↓
Resolver-selected immutable account ID
        ↓
Same-process serialized authoritative event lookup
        ↓
Whole-import duplicate or conflict decision before mutation
        ↓
Atomic import-history commit for accepted event provenance and transactions
```

The authoritative lookup must occur after deterministic account resolution supplies account scope and before account, identifier, document, session or transaction writes. An incoming batch must also be checked for repeated canonical identities. A duplicate or conflict blocks the whole import; no transaction rows are silently omitted.

Accepted event evidence and its privacy-safe digest must eventually participate in the provider-owned atomic import-history commit established by ADR-030. The same-process serialized confirmation boundary may provide same-process safety only. Cross-process and external-writer guarantees remain future work.

### Compatibility

ADR-019 remains authoritative: the approved baseline financial values and byte-frozen fixture remain unchanged. The new overlapping fixture adds evidence without redefining the original statement's financial truth.

ADR-030 remains authoritative for exact-content fingerprints. Transaction-event evidence neither replaces nor reconstructs `ledgerforge.raw-text.sha256.v1`, does not backfill legacy history and does not use exact-statement metadata as event identity.

Version 1 is prospective only. Existing transactions are not backfilled or heuristically fingerprinted.

## Consequences

Positive consequences:

- Genuine independent source exports support one strong, deterministic family.
- Parser ownership prevents a second narration-parsing system.
- Account scope and subtype prevent the observed UPI token reuse from collapsing related but distinct ledger events.
- Canonical serialization is exact, versioned and privacy-safe to represent durably as a digest.
- Legitimate recurring patterns remain distinct through distinct source references.
- No schema, repository or production-code change is required for architecture preparation.

Trade-offs and limitations:

- Version 1 covers only parser-verified Axis UPI rows.
- Missing or malformed evidence cannot establish novelty.
- IMPS, NEFT, e-commerce, unstructured, reversal and refund behavior remains unapproved.
- The frozen baseline fixture does not itself encode the original posting/credit-adjustment reference equality; the expected specification records that verified relationship symbolically.
- A later implementation needs repository contracts and persistence reviewed against this ADR, but Sprint 40 authorizes none.

## Rejected Alternatives

- Date, amount, direction, narration, running balance or row-position identity.
- A token-only UPI identity that collapses posting and credit adjustment.
- Institution-wide or global scope unsupported by the evidence.
- Generic narration extraction outside the parser.
- Treating all 12-digit substrings as financial identity.
- Promoting IMPS or NEFT based only on the small stable overlap.
- Hashing weak or ambiguous fields and presenting the digest as strong identity.
- Partial import that silently omits matching rows.
- Historical transaction backfill.

## Non-Goals

This ADR does not implement parser extraction, domain models, repository lookup, persistence, schema changes, duplicate blocking, partial import, review UI, override, historical repair, statement continuity, global history, transaction mutation, account repair, broader atomicity, cross-process guarantees, PDF identity or cross-format identity.

## Related ADRs

- ADR-017 — Deterministic Before Intelligent
- ADR-019 — Reference Fixtures Define Financial Truth
- ADR-025 — Stable Financial Entity Identity
- ADR-027 — Parser-Owned Financial Identifier Extraction
- ADR-029 — User-Confirmed Financial Identifier Attachment
- ADR-030 — Versioned Exact-Content Fingerprints and Atomic Import-History Commit

---

# ADR-032 — Durable Import Attempt History and Rejected-Outcome Semantics

## Status

Accepted

## Implemented In

Sprint 42

## Decision

LedgerForge will maintain a separate durable `import_attempts` ledger. An attempt records that processing was attempted; a successful import session records accepted financial history. Rejected and failed attempts must never be represented as successful imported financial history.

The ledger uses bounded, versionable and privacy-safe outcome, coverage, account-decision and guidance codes. Initial supported outcome families are successful import, validation failure, persistence failure, exact-statement duplicate, existing eligible Axis UPI transaction event, repeated eligible incoming evidence, transaction-event ownership conflict, and repository-integrity conflict only where an authoritative production path detects it. Unsupported or unevaluated coverage is explicit; missing Axis UPI evidence never proves novelty.

ADR-031 remains limited to parser-verified Axis UPI P2A/P2M evidence. It does not generalize to IMPS, NEFT, cards or e-commerce, unstructured references, refunds, reversals or other institutions.

## Privacy boundary

Attempt history must not store or expose raw statement content, unrestricted source fragments, passwords, raw financial identifiers, UPI references, exact fingerprints, transaction-event digests, canonical identity payloads, unrestricted narrations, source paths, unrestricted localized errors or free-form financial validation messages. Presentation uses enumerated codes and trusted repository relationships only.

## Atomicity

Successful attempt persistence participates in the same provider-owned atomic operation as successful import history. Once implemented, a successful financial commit must not exist without its successful attempt record. Rejected-attempt recording cannot weaken or override the original rejection, and failure to record a rejected attempt must never convert rejection into success. An audit write may itself fail when persistence is unavailable, and that limitation must be reported truthfully.

Earlier workspace, account or identifier side effects may occur before the atomic import-history operation. This ADR does not claim complete rollback or redesign broader cross-repository atomicity.

## Migration and provider parity

Sprint 42 may add an additive V4 migration for `import_attempts`. Existing completed successful import sessions may be backfilled only where repository evidence is authoritative. Historical rejected attempts, duplicates, validation failures and persistence failures must not be invented. The migration must not alter financial transactions, fingerprints, identifiers, event ownership, accounts, documents or import-session relationships. SQLite and In-Memory providers must enforce equivalent domain behaviour.

## Presentation scope

The bounded read-only experience may show immediate Import Wizard outcome status, global Imports history, selected attempt detail and trusted navigation to prior successful account/session/document relationships where available. It does not authorize duplicate override, partial import, omission, repair, deletion, reversal, account merge/split or manual identity reassignment. Development diagnostic history and a full validation timeline remain outside this decision.

Sprint 42 implemented Migration V4, durable bounded attempts, SQLite/In-Memory provider parity, atomic successful-attempt persistence, bounded rejected-attempt recording, attempt-history hydration and read-only Imports history/detail. It did not generalize event authority, add repair or mutation, broaden atomicity, add cross-process safety or expand unsupported families.

## Consequences

Users gain durable, privacy-safe explanation of supported import outcomes without conflating rejected content with accepted financial history. The model requires additive persistence, provider parity, migration/backfill rules and bounded presentation. Unsupported families, historical reconstruction, cross-process safety and external-writer safety remain outside authority.

## Related ADRs

- ADR-019 — Reference Fixtures Define Financial Truth
- ADR-029 — User-Confirmed Financial Identifier Attachment
- ADR-030 — Versioned Exact-Content Fingerprints and Atomic Import-History Commit
- ADR-031 — Verified Transaction-Event Evidence and Pre-Write Duplicate Blocking

---

# ADR-033 — Deterministic Money and Native-Currency Integrity

## Status

Accepted

## Context

ADR-008 requires every monetary value to retain its native currency, treats conversion as derived presentation and prohibits destructive replacement of imported values. The current production path preserves one native amount/currency pair but represents amounts and currency through separate primitives. Persistence stores both `amount_decimal` and `amount_minor`, while import mapping and hydration independently implement an INR-only fraction-scale rule. Dashboard, Accounts and Transactions also contain currencyless aggregate paths that are unsafe once more than one native currency becomes production-supported.

Approved INR and QAR fixture evidence, the completed American Express, CBQ and Axis card cross-family review and the Money architecture discovery establish the required compatibility boundary. They do not establish production non-INR, PDF, XLS/XLSX, card or institution-parser support.

ADR-033 extends ADR-008. It does not replace or weaken ADR-008's native-value, derived-conversion or non-destructive-conversion principles.

## Decision

### Money authority

A domain `Money` value consists of an exact `Decimal` amount and one canonical native currency code. The imported exact numeric amount plus native currency is the authoritative financial value.

An implementation may cache or derive minor units, but minor units are not independent financial truth.

### Currency identity and normalization

Currency codes use exactly three ASCII letters. Valid ingestion input is normalized to uppercase. Persisted and exposed codes are uppercase. Malformed codes fail.

Persisted historical lowercase or otherwise noncanonical codes are compatibility-audit findings and are not silently rewritten.

Currency membership comes from one reviewed, versioned, offline catalog. Catalog membership does not imply production parser or institution support.

### Currency catalog

The compiled, versioned offline catalog is the sole semantic authority for supported currency membership and currency fraction digits. Callers cannot override fraction scale.

The existing database `currencies` table remains inactive schema capacity in this increment and must not override or compete with the compiled catalog.

The initial implementation catalog must cover currencies required by approved evidence and tests, including representative zero-, two- and three-fraction-digit behaviour. Exact membership is implementation-reviewed and does not establish import support.

### Canonical decimal representation

For trusted persisted transactions, `amount_decimal` stores a canonical, locale-independent, non-exponent decimal representation. It represents the exact numeric value, not the original lexical source token, and uses the currency's catalog fraction scale. Negative zero is normalized to zero.

For a two-decimal currency:

```text
120   -> 120.00
120.5 -> 120.50
-0.00 -> 0.00
```

Source lexical text remains in raw or normalized source evidence where available. ADR-033 does not authorize rewriting historical rows.

### Minor-unit encoding

Minor units are a mandatory exact persistence and query encoding for trusted transaction amounts. Scale comes only from the catalog.

Decimal-to-minor conversion must be exact. Excess precision and `Int64` overflow fail. Values are never clamped or truncated.

Persisted decimal and minor transaction representations must agree. New disagreement blocks persistence. Historical disagreement blocks affected hydration and Money rollout pending explicit review. Neither representation is silently selected over the other.

### Rounding

No implicit rounding is allowed for Money construction, imported values, persistence, hydration or same-currency arithmetic.

Future derived calculations requiring rounding need a separately approved explicit policy. Scalar multiplication and division are outside the first Money increment.

### Running balances

A transaction running balance is optional `Money` evidence governed by the transaction and account native currency. Domain validation treats it as an exact value.

Existing persistence may continue storing `running_balance_minor` as its exact trusted encoding. ADR-033 requires no `running_balance_decimal` column. Original lexical running-balance evidence remains in raw or normalized source evidence where available.

Exact representability and account-currency consistency are mandatory. Any future dual representation requires a separate schema decision.

### Equality, hashing and encoding

Equality and hashing use canonical currency plus exact canonical value. For catalog-supported representable values, canonical minor units may implement equality and hashing.

`Money` must not conform to an unconditional cross-currency `Comparable`. Checked comparison is allowed only for matching currencies.

`Codable` uses a keyed canonical currency code and canonical decimal string. Decoding reconstructs and validates `Money`.

### Arithmetic

The initial Money contract permits negation, equality, checked comparison, addition, subtraction and aggregation. All arithmetic requires matching currencies.

Cross-currency arithmetic or comparison fails explicitly. No conversion operation belongs to `Money`.

### Account, transaction and statement currency

The initial foundation requires:

- one native currency per account;
- trusted transaction booked currency matching its account;
- running-balance currency matching its account;
- parser output establishing an explicit statement or booked currency, or deterministic uniform booked-row currency;
- no first-row-only currency inference.

Secondary original merchant currency remains distinct evidence. A statement with mixed booked or native transaction currencies for one account is blocked from initial trusted persistence.

### Persistence and provider parity

Mapping and hydration use the same catalog and exact conversion contract. SQLite and In-Memory providers expose equivalent successful values and equivalent failures.

Invalid Money or currency relationships fail atomically. Failed mapping or hydration must not partially mutate trusted repository or runtime state.

Existing INR financial behaviour remains unchanged. QAR exact round trips may be tested without enabling QAR production import.

### Existing-data compatibility gate

Before Money implementation may alter trusted persistence or hydration behaviour, a separate explicit read-only compatibility audit must check:

- schema and migration versions;
- account and transaction currencies;
- canonical code form;
- catalog membership;
- deterministic decimal parsing;
- scale and excess precision;
- exact decimal and minor agreement;
- overflow;
- running-balance representability;
- account and transaction currency consistency;
- account-balance snapshot consistency where relevant.

The audit performs no mutation, emits privacy-safe aggregate diagnostics only and never reports raw amounts, descriptions, references, account identifiers or database rows. It blocks rollout when any financial value requires guessing, automatic repair or reinterpretation.

ADR-033 does not authorize a repair or migration.

### Sprint 44 implementation clarification

The audit's variable-scale decimal strings belonged solely to disposable development and test databases. They are not shipped user data, production history or a permanent compatibility contract. Sprint 44 therefore requires canonical catalog-scale decimal text for all new writes and hydration, with exact decimal/minor/currency agreement. Development fixtures and databases may be recreated or reseeded to the canonical contract; no production-data migration is introduced.

### Presentation

Until a separately approved FX domain exists, ViewModels expose one total per native currency, deterministically ordered by canonical code. Dashboard, Accounts and Transactions must not expose one currencyless aggregate across currencies. Mixed-currency net worth is unsupported as one native total.

Formatting uses `Money`, locale and catalog metadata. Locale affects presentation only. Accessibility output includes an unambiguous currency name or code. Direction or financial effect must not depend only on symbol, colour or sign.

### No-FX boundary

ADR-033 does not read or write exchange rates, activate the `exchange_rates` table, fetch rates, convert values, calculate card FX, compute reporting-currency totals, perform historical or current valuation or overwrite native `Money`.

Future converted values require a separate provenance-bearing derived-value model and a future ADR.

### Release boundary

The smallest coherent production release boundary is:

```text
Money domain
+ exact persistence and hydration
+ currency relationship validation
+ grouped native-currency presentation
```

Internal checkpoints may be implemented separately, but production non-INR support remains closed until the complete boundary passes.

### Schema and migration decision

ADR-033 authorizes no schema migration. The existing transaction decimal, minor-unit and running-balance columns are provisionally sufficient for the accepted contract, subject to the compatibility audit and implementation validation.

Any new constraint, catalog-table activation, metadata seed, decimal column, repair, backfill or durable audit marker requires a separately reviewed migration decision.

## Consequences

Positive consequences:

- Native monetary truth has one deterministic domain authority.
- Persistence retains exact financial values and a checked query encoding.
- Currency mismatches and unsafe arithmetic fail explicitly.
- SQLite and In-Memory behaviour must remain equivalent.
- Native-currency grouping prevents false cross-currency totals.
- The compiled catalog preserves deterministic offline-first operation.

Costs and constraints:

- The smallest coherent implementation spans domain, persistence, hydration, validation and presentation.
- A passing compatibility audit is required before trusted persistence or hydration changes.
- Production non-INR rollout remains blocked until every layer passes.
- The offline catalog requires explicit versioned maintenance.
- Previously tolerated malformed or inconsistent data will fail more strictly.

## Rejected Alternatives

- Treating minor units as independent financial truth.
- Allowing the database `currencies` table to compete with the compiled catalog.
- Caller-supplied fraction scales.
- Implicit rounding, clamping or truncation.
- Silently preferring decimal or minor representation when they disagree.
- First-row-only statement-currency inference.
- Automatic historical normalization, repair or reinterpretation.
- Unconditional cross-currency comparison or arithmetic.
- Currencyless aggregation across native currencies.
- Embedding conversion or exchange-rate access in `Money`.
- Shipping persistence and hydration without validation and grouped presentation.

## Non-Goals

ADR-033 does not establish QAR production support, PDF or XLS/XLSX support, card semantics, card persistence, institution parser support, FX conversion, investment valuation or reporting-currency analytics. It does not implement `Money`, run the compatibility audit, change schemas, migrate data or repair historical records.

## Related ADRs

- ADR-008 — Multi-Currency Domain Model
- ADR-009 — Reactive Store Architecture
- ADR-010 — Validation Before Persistence
- ADR-016 — Universal Import Pipeline
- ADR-019 — Reference Fixtures Define Financial Truth
- ADR-024 — Repository Hydration Boundary
- ADR-025 — Stable Financial Entity Identity

---

# ADR-034 — Document-Scoped Card Statement Evidence

## Status

Accepted

## Context

American Express, CBQ and Axis card fixture evidence is integrated, and the final cross-family review is complete. The families share authoritative posted amount and booked/statement currency but differ in source classification, row scope, instrument sections, original-currency evidence, fees, summaries, layouts, rewards, reconciliation and cross-format behaviour.

Generic bank debit/credit semantics cannot safely represent card-liability effects. Fixture integration does not establish production parsing or persistence support. ADR-034 remains subordinate to ADR-033 for monetary representation, currency validation, persistence, hydration and presentation.

## Decision

### Document-owned evidence envelope

`FinancialDocument` may optionally carry parser-owned document-scoped card evidence:

```text
FinancialDocument
└── optional CardStatementEvidence
    ├── statement-level evidence
    ├── document-scoped instrument sections
    ├── transaction annotations keyed by canonical transaction ID
    ├── summary components
    ├── reconciliation evidence
    └── optional non-cash metadata
```

This accepts the boundary, not an implementation.

### Posted Money and parser ownership

The canonical posted amount and booked/statement currency remain authoritative. Card evidence references the canonical transaction and never duplicates or replaces its posted Money. Separately printed monetary evidence remains distinct.

Only the selected Statement Parser may create source classification, source marker, row scope, instrument-section assignment, amount-owed effect, original merchant evidence, printed FX evidence, fee, markup or tax evidence, summary components, reconciliation evidence, rewards and other non-cash source evidence. Readers extract; orchestration, persistence, hydration and UI do not invent omissions.

### Classification, markers and amount-owed effect

Source classification is one stable parser-owned code with an optional display label; arbitrary printed text is not durable identity. Institution-specific or unknown classifications may remain unnormalized. No universal card taxonomy is required.

Observed markers such as Axis Debit/Credit remain exact source evidence and do not imply card effect, bank direction, income, expense or amount owed. The only initial optional source-proven effect values are `increasesAmountOwed` and `decreasesAmountOwed`. Absence means no effect was source-proven. No `noAmountOwedEffect`, `unknownOrUnproven`, debit/credit aliases or inferred effects are added. Classification and effect remain independent.

### Row scope and instruments

Rows may be `accountLevel` or `instrument(documentScopedSectionID)`. Section IDs are opaque, deterministic within the document, parser-owned and independent of labels, narration, masked values, suffixes and filenames. Primary/supplementary roles are preserved only when source-proven. A document-scoped section is not an account.

No durable card-instrument entity or cross-statement identity is created. Fixture continuity remains evidence only. Durable identity requires a separate decision with strong verified identifiers and persistence requirements.

### Original, FX, fee, markup and tax evidence

Original merchant amount and currency are an optional complete Money pair; both must be present together, never replace posted Money, and are never derived. Persistence remains blocked until Money is implemented.

Printed FX evidence is independently optional and preserves exact source value, numerator/denominator currency identities, source/layout provenance and required lexical representation. Layout context may establish currency identity. It causes no conversion, does not activate exchange-rate storage and missing rates are never calculated.

Fee, markup and tax are independently optional. Each component carries a complete Money value or an identity reference to the authoritative posted transaction when the source proves the entire row represents that component. Missing components are never inferred.

### Summaries, reconciliation and continuity

Summaries use a hybrid typed component model: bounded shared keys for genuinely recurring concepts and namespaced source/layout components for irreducible evidence. Shared concepts may include previous/opening balance, closing/statement balance, full or minimum payment due, due date, credit limit and available credit. Evidence state is `observed(value)`, `explicitlyAbsent`, `notApplicable` or no entry; `notApplicable` requires explicit source/layout proof, and observed zero remains observed zero.

Parsers provide a closed, versioned reconciliation-rule identifier, typed operand references and provenance. Validators evaluate deterministically. Parsers do not provide executable formulas or open-ended expressions; one universal card formula is rejected.

Inter-document balance continuity is separate optional evidence, not per-document reconciliation and not mandatory for every family. Axis's explicit absence of a continuity claim remains preserved.

### Payments, refunds, reversals, rewards and duplicate identity

Payment classification does not allocate payments to instruments. Refund and reversal classification does not automatically match or mutate earlier transactions. Matching and allocation require future authority and decisions. Rewards remain document-scoped non-cash metadata, not Money, transactions, income or accounting value.

ADR-031 card-event identity is not established. No card duplicate identity is derived from date, amount, narration, classification, instrument section or layout position. Existing exact-content authority remains separate; new card-event identity requires strong source evidence and a future ADR.

### Validation ownership

A future card-aware validator must verify without inference: transaction references; statement currency; account/instrument row scope; section references; original Money pair completeness; printed-rate currency completeness; fee/markup/tax completeness; evidence-state validity; typed reconciliation inputs; and Money representability and currency relationships after Money implementation.

### Persistence and production boundary

ADR-034 authorizes no persistence implementation, schema migration, JSON persistence decision, durable instrument table, card summary table or transaction schema change. Persistence waits for the complete ADR-033 Money boundary, concrete card domain and validation requirements, known query/hydration needs and SQLite/In-Memory parity.

American Express, CBQ and Axis production support remain independently gated. ADR-034 does not enable PDF, XLS/XLSX, QAR, card parsing, card persistence, institution support or UI presentation.

## Consequences

- Source-faithful card evidence is preserved without universal false semantics.
- Statement context remains available while posted Money retains one authority.
- Instruments remain distinct from accounts and missing evidence remains missing.
- Institution/layout differences remain preservable and production support remains gated.
- The FinancialDocument handoff and future validation/component governance become larger.
- Persistence and institution-specific parser work remain future work after Money.

## Rejected Alternatives

- Adding card fields directly to every generic transaction initially.
- Treating bank debit/credit as card effect.
- Mandatory universal taxonomy or one fixed summary formula.
- Representing missing evidence as zero.
- Durable instrument identity from weak labels or suffixes.
- Calculated FX, markup, tax or fees.
- Automatic payment allocation or refund/reversal matching.
- Weak card duplicate identity.
- Production support inferred from fixtures or schema presence.

## Non-Goals

ADR-034 does not implement card evidence models, parsers, persistence, migrations, Money, FX conversion, payment allocation, rewards accounting, reversal matching, durable instrument identity, card duplicate identity, UI or production format/institution support.

## Related ADRs

- ADR-008 — Multi-Currency Domain Model
- ADR-010 — Validation Before Persistence
- ADR-016 — Universal Import Pipeline
- ADR-019 — Reference Fixtures Define Financial Truth
- ADR-024 — Repository Hydration Boundary
- ADR-025 — Stable Financial Entity Identity
- ADR-031 — Verified Transaction-Event Evidence and Pre-Write Duplicate Blocking
- ADR-033 — Deterministic Money and Native-Currency Integrity

---

# ADR-035 — Development Database Lifecycle and Recoverable Reset

## Status

Accepted

## Date

2026-07-17

## Related Work

- BUG-P1-01 — Development Database Reset Does Not Persist Across Relaunch
- Sprint 45

## Context

The existing Developer Console reset installs a UUID-named temporary SQLite provider while leaving the canonical database intact. Runtime hydration therefore appears empty only for the current process, and the next launch reconnects to the unchanged canonical data. The operation also lacks one owner for database identity, provider quiescence, SQLite sidecars, recoverable backup, provider publication, hydration and failure recovery.

Debug and Release previously resolved the same canonical filename. Runtime hiding alone cannot prove that a destructive development action is unable to affect non-development data. Replacing `DatabaseProvider.shared` also cannot invalidate repository objects already captured by an active import, hydration or repository operation.

## Decision

### Dedicated lifecycle ownership

One dedicated `DevelopmentDatabaseLifecycleCoordinator` owns the development database lifecycle. It owns canonical and temporary development database identities, lifecycle-owned backup identity, lifecycle-operation serialization, active-operation exclusion, provider quiescence, SQLite checkpoint and checked close, backup creation and verification, canonical database-set replacement, provider recreation and publication, canonical hydration, automatic recovery and lifecycle-unavailable state.

`LedgerForgeApp` may bootstrap this coordinator but does not own destructive reset logic. The Developer Console may request lifecycle operations but does not manipulate providers, repositories or database paths directly.

### Development database identity

The canonical development database uses one centrally defined, application-owned, stable path selected only in DEBUG builds. Its identity is distinct from the non-development/Release database. Authorization for destructive work requires equality with the standardized, symlink-resolved canonical development URL. Path-prefix containment is insufficient and arbitrary caller-provided paths are never authorized.

This decision introduces no schema migration solely for database identity. The registered migration chain remains the schema authority.

### Build safety

Permanent reset, restore and approved-fixture-launcher APIs, UI and resources are absent from Release builds. Runtime hiding is not a safety boundary. DEBUG code must still verify the exact canonical development identity before destructive work.

### Three lifecycle meanings

1. `Start Temporary Empty Session` creates a UUID-named temporary SQLite database for the current process. It leaves the canonical development database unchanged, and relaunch reconnects to canonical data.
2. `Reset Development Database` creates and verifies a lifecycle-owned backup, replaces only the canonical development database set, recreates the same canonical identity through the registered migration chain and canonically hydrates empty runtime stores. The empty state survives relaunch.
3. `Restore Previous Development Database`, when presented, may use only a lifecycle-owned verified backup. No arbitrary file picker or database path is accepted. Automatic recovery from failed reset is mandatory even when visible restore is omitted.

### Exclusive lifecycle and repository activity gate

One centralized gate coordinates provider-backed activity and exclusive lifecycle operations. Reset rejects or safely waits while import preparation, prepared confirmation, confirmed persistence, repository writes, hydration, Developer Console reload, temporary-session creation, reset, restore or provider replacement is active. View-local flags and the existing confirmation lock are not lifecycle authority.

Provider-backed work obtains a generation-bound operation lease before capturing repositories. Exclusive lifecycle work stops new leases and waits for existing leases to finish. A provider generation change invalidates later use of repositories captured from the previous generation.

### Provider quiescence and SQLite database set

Before canonical replacement, the coordinator stops new provider operations, waits for active leases, checkpoints WAL, closes the active SQLite provider and checks the SQLite close result. Replacing `DatabaseProvider.shared` alone is insufficient.

The database main file, `-wal` file and `-shm` file form one coordinated lifecycle set. No member is destructively replaced while the provider is live or while unmanaged committed WAL data may remain.

### Verified backup

Before destructive replacement, the coordinator creates a lifecycle-owned recoverable backup. Verification opens the backup, confirms a valid LedgerForge schema, confirms a supported migration state from the registered migration chain and proves that committed WAL data is represented. Backup failure or verification failure prevents canonical replacement.

Backup identity and diagnostics are bounded and contain no financial content, identifiers, source fragments or unrestricted filesystem paths.

### Canonical recreation and runtime reconciliation

After backup verification, only the exact canonical development database set may be isolated or removed. `SQLiteRepositoryProvider` recreates the database at the same canonical identity and runs the registered migration chain. The coordinator publishes the provider only after construction and migrations succeed.

`RepositoryStoreHydrator` remains the sole repository-to-runtime authority. Reset success requires one forced canonical hydration of accounts, transactions, successful import sessions and import attempts. Stores are never manually cleared to simulate success.

### Recovery and unavailable state

A failure before canonical replacement leaves the original provider and database untouched. After replacement begins, failure in recreation, migration, provider installation or hydration closes the incomplete provider, isolates the incomplete database set, restores the verified backup, reopens and republishes the restored provider, forces canonical hydration and reports reset failure.

If recovery fails, the coordinator enters an explicit lifecycle-unavailable state. Imports, repository mutations and further lifecycle operations are disabled except for an explicitly safe recovery path. Runtime state is not presented as synchronized, and only a bounded privacy-safe error is exposed. Partial reset is never reported as success.

### Structured results and diagnostics

Lifecycle operations return structured deterministic results that distinguish temporary-session success, permanent-reset success, restored backup, activity rejection, unsafe identity, quiescence failure, backup failure, recreation or migration failure, hydration failure with successful recovery, recovery failure and lifecycle-unavailable state.

Diagnostics remain governed by ADR-026: structured, deterministic, in-memory and privacy-safe, using only approved operation, phase, result and count metadata. Persistent diagnostics and general export are not introduced.

## Consequences

- Development database mutation has one owner and one testable safety boundary.
- Temporary emptiness and persistent reset are no longer conflated.
- Debug and non-development database identities are distinct.
- Provider-backed work must participate in the lifecycle activity gate.
- Reset becomes more complex because backup, sidecars, provider generations, hydration and recovery are one atomic operational contract.
- Failure may make the lifecycle explicitly unavailable rather than preserving a misleading partially synchronized UI.

## Non-Goals

ADR-035 does not authorize Release or production reset, arbitrary database deletion or restore, account or transaction deletion, import-session reversal, historical or duplicate repair, account merge or split, record-level undo, SQL browsing or editing, general repository inspection, persistent diagnostic history, general database maintenance, performance profiling or cloud backup.

## Related ADRs

- ADR-013 — Store Ownership
- ADR-024 — Repository Hydration Boundary
- ADR-026 — Structured Developer Diagnostics

---

# ADR-036 — Category Identity, Assignment, and Mutable Transaction Metadata

## Status

Proposed

## Date

2026-07-17

## Decision Owners

LedgerForge architecture

## Related Work

- `FW-P2-20 — Category Model and Management`

## Extends

- ADR-009 — Reactive Store Architecture
- ADR-013 — Store Ownership
- ADR-024 — Repository Hydration Boundary
- ADR-025 — Stable Financial Entity Identity
- ADR-026 — Structured Developer Diagnostics
- ADR-033 — Deterministic Money and Native-Currency Integrity

## Supersedes

None

## Context

LedgerForge persists trusted financial transactions imported from source documents.

A trusted transaction contains durable financial and provenance data, including:

- repository transaction identity;
- Money amount;
- native currency;
- debit or credit direction;
- posting and value dates;
- source description;
- account relationship;
- source-document relationship;
- import-session relationship;
- trust state;
- transaction-event and duplicate-detection evidence.

These values represent imported financial truth. They must not be rewritten merely because a user wants to organize transactions for presentation, search, budgeting, or later analytics.

LedgerForge does not currently have a production category domain.

Current transaction presentation includes category placeholders, but no durable category identity, category repository, assignment relationship, category store, or category-management workflow exists.

The persisted transaction identity already exists as the repository transaction ID. However, the current runtime transaction model regenerates its presentation identity during hydration and does not expose the durable repository transaction ID.

Using that transient runtime UUID for category assignment would make assignments unreliable across hydration, relaunch, provider replacement, or database recreation.

`FW-P2-20` requires a deterministic foundation for:

- user-created categories;
- category hierarchy;
- manual transaction assignment;
- Uncategorized semantics;
- category archival;
- safe deletion;
- future deterministic categorization rules.

This ADR defines the minimum architecture for categories while preserving immutable imported truth.

## Decision Drivers

The architecture must:

- preserve imported transaction truth;
- preserve exact Money and native-currency integrity;
- preserve source and import-session provenance;
- use durable repository transaction identity;
- remain offline-first;
- maintain SQLite and In-Memory provider parity;
- preserve repository ownership of persisted state;
- preserve store ownership of runtime state;
- preserve `RepositoryStoreHydrator` as the repository-to-runtime boundary;
- support deterministic behavior across hydration and relaunch;
- avoid speculative rules, analytics, AI, tags, or bulk-mutation architecture;
- provide safe category deletion and archival semantics;
- remain compatible with future explainable categorization rules;
- avoid requiring reversible financial-mutation architecture for ordinary single-transaction metadata assignment.

## Decision

LedgerForge will introduce a workspace-owned category domain and a separate current transaction-category assignment relationship.

Category metadata will remain separate from imported transaction rows.

### 1. Imported truth and mutable metadata are separate domains

Imported transaction truth remains immutable after successful persistence.

Category definitions and category assignments are user-authored metadata.

Category operations must not modify:

- Money amount;
- currency;
- transaction direction;
- posting date;
- value date;
- source description;
- payee or reference evidence;
- running balance;
- account identity;
- source-document identity;
- import-session identity;
- original-row identity;
- exact-statement fingerprint;
- transaction-event identity;
- duplicate-detection authority;
- parser or validation results.

Category persistence must not rewrite the trusted transaction row merely to change its classification.

The transaction repository remains responsible for trusted transaction records.

Category persistence will use a separate category repository boundary.

### 2. Durable repository transaction identity

Every hydrated trusted transaction must expose its immutable persisted repository transaction ID.

This identity must:

- originate exclusively from the persisted transaction DTO or repository record;
- remain stable across forced hydration;
- remain stable across application relaunch;
- remain stable across provider reconstruction;
- never be generated by UI code;
- never be generated by category-management code;
- never be inferred from transaction description, date, Money, account, or source evidence.

The runtime presentation UUID must not be used as a persistence target.

Category assignment must stop or fail closed when a durable repository transaction ID is unavailable.

The repository transaction ID identifies the persisted transaction record. It does not replace transaction-event identity, duplicate-detection identity, account identity, or source provenance.

### 3. Category identity and ownership

A category is a workspace-owned durable entity.

The minimum category domain contains:

- immutable category ID;
- workspace ID;
- user-visible display name;
- deterministic normalized name;
- optional parent category ID;
- archived state.

The immutable category ID is the durable target for:

- transaction assignments;
- future deterministic rules;
- future filtering;
- future analytics;
- future budgeting.

Renaming, moving, archiving, or restoring a category must not change its identity.

Category identity must not be derived from its display name.

### 4. User-created categories only

The initial category foundation will not seed a built-in taxonomy.

All initial categories are user-created.

Future system-defined categories require a separate approved decision covering stable identities, localization, editing, migration, and deletion policy.

### 5. Uncategorized is absence

“Uncategorized” is not a persisted category.

It is the presentation state produced when a transaction has no current category assignment.

Therefore:

- no reserved Uncategorized row is created;
- no magic UUID is used;
- no localized category name is persisted;
- clearing an assignment returns the transaction to Uncategorized;
- existing transactions require no category backfill;
- future rules may assign a category without replacing a pseudo-category;
- analytics can distinguish no classification from an explicit category.

### 6. Separate current assignment relationship

Transaction-category assignment will be stored separately from trusted transaction records.

The logical assignment contains:

- workspace ID;
- durable repository transaction ID;
- category ID.

The relationship enforces:

- zero or one current category per transaction;
- one assignment row maximum per transaction;
- transaction and category workspace equality;
- existence of a trusted persisted transaction;
- category existence;
- rejection of new assignments to archived categories;
- idempotent assignment of the already-current category;
- explicit relationship deletion when assignment is cleared.

Initial assignment records do not require:

- assignment timestamp;
- confidence;
- reason;
- rule ID;
- rule version;
- suggestion state;
- assignment history;
- actor history.

Until deterministic rules exist, every assignment is manual by definition.

### 7. One category per transaction

The initial model supports one current category per transaction.

It does not support:

- multiple simultaneous categories;
- tags;
- transaction splits;
- weighted classifications;
- hierarchical allocation;
- separate tax classifications;
- investment classifications.

### 8. Category hierarchy

The initial supported hierarchy is:

- root categories;
- one child level beneath a root.

The system must reject:

- self-parenting;
- cycles;
- grandchildren;
- unsupported movement of a root with children;
- cross-workspace parents;
- missing parents;
- invalid archived-parent relationships.

The persistence shape may use a self-referencing parent identity so deeper hierarchy can be introduced later without replacing category identity.

Current repository and service boundaries must enforce the two-level limit.

### 9. Category naming and ordering

Category names must be:

- trimmed;
- non-empty after normalization;
- deterministically normalized;
- subject to an implementation-defined bounded maximum length.

Sibling names must be unique under deterministic normalization.

Root categories share one sibling scope.

Children of one parent share one sibling scope.

Initial ordering is deterministic alphabetical ordering by normalized name, followed by immutable category ID.

Custom ordering is deferred.

Normalization must not depend on nondeterministic locale or operating-system behavior.

### 10. Initial category operations

The initial architecture supports:

- create;
- rename;
- move within the supported hierarchy;
- archive;
- restore;
- delete an unused, childless category;
- assign one category to one transaction;
- change one transaction assignment;
- clear one transaction assignment.

Deferred operations include:

- custom ordering;
- bulk assignment;
- bulk reassignment;
- delete with replacement;
- category merge;
- assignment history;
- multi-operation undo.

### 11. Archive and deletion semantics

A category with current assignments must not be hard-deleted.

It may be archived.

Archiving:

- preserves category identity;
- preserves existing assignments;
- preserves historical display;
- prevents new assignments;
- keeps referenced categories available during hydration.

An archived category may be restored.

Hard deletion is allowed only when:

- the category has no assignments;
- it has no children;
- it belongs to the active workspace;
- the repository verifies these conditions atomically with deletion.

Deletion must fail rather than silently:

- clear assignments;
- cascade assignments away;
- delete descendants;
- move transactions to Uncategorized;
- reassign transactions.

Bulk replacement and delete-with-reassignment require separately approved preview, atomicity, recovery, and restoration semantics.

### 12. Targeted metadata mutation boundary

Single category CRUD operations and single-transaction assignment changes are targeted metadata mutations.

They do not modify imported financial truth and do not require the complete `FW-P0-16` reversible financial-mutation foundation.

They must still provide:

- workspace validation;
- durable identity validation;
- repository-owned persistence;
- deterministic failure semantics;
- SQLite and In-Memory parity;
- canonical hydration after success;
- no partial runtime mutation after failure.

Bulk reassignment, category merge, delete-with-replacement, and global undo remain outside this boundary.

### 13. Repository ownership

A dedicated category repository contract will own category and assignment persistence.

It will govern:

- category persistence;
- hierarchy validation;
- workspace validation;
- uniqueness;
- archive state;
- current assignments;
- assignment clearing;
- atomic delete-unused checks;
- deterministic reads.

Exact Swift protocol and method names are implementation decisions.

`TransactionRepository` must not own category definitions.

Trusted transaction DTOs and import persistence must remain unchanged apart from narrowly exposing persisted transaction identity during runtime hydration.

### 14. Provider parity

SQLite and In-Memory providers must expose equivalent observable behavior for:

- creation;
- name validation;
- sibling uniqueness;
- hierarchy validation;
- archive and restore;
- delete-unused;
- delete rejection;
- assignment;
- assignment replacement;
- assignment clearing;
- workspace isolation;
- archived-category assignment rejection;
- deterministic ordering;
- idempotence;
- failure classification.

SQLite-specific failures must map to domain-level failures reproducible by the In-Memory provider.

### 15. Persistence schema

Implementation requires an additive migration after the current migration version.

The migration will introduce:

- a category table;
- a separate current assignment table;
- workspace-aware constraints;
- hierarchy constraints where appropriate;
- sibling-name uniqueness indexes;
- assignment and lookup indexes.

The migration must not:

- rewrite trusted transaction values;
- seed categories;
- assign existing transactions;
- change Money;
- change currency;
- change transaction identity;
- change duplicate-detection evidence;
- change source or import-session provenance.

Existing transactions remain Uncategorized.

The expected migration is V5 only if no earlier accepted work consumes that version.

### 16. Runtime category state

A dedicated category store will own:

- active categories;
- archived categories required by current assignments;
- current transaction-to-category assignments.

`TransactionStore` remains the owner of imported transactions.

View models may join category and transaction snapshots but must not become canonical owners.

Assignment counts are derived, not initially persisted.

### 17. Repository-to-runtime hydration

`RepositoryStoreHydrator` remains the sole repository-to-runtime authority.

Hydration must:

- preserve durable repository transaction identity;
- read category definitions;
- read assignments;
- validate relationships;
- include referenced archived categories;
- map all required values;
- replace relevant stores only after all reads and mapping succeed.

Hydration must not leave partial transaction/category/assignment combinations.

Assignments must never target transient runtime UUIDs.

### 18. Category mutation coordination

A category-management coordinator or equivalent service boundary owns:

```text
validate command
    ↓
perform repository mutation
    ↓
force canonical hydration
    ↓
return structured result
```

The coordinator must not manually mutate stores.

Persistence success followed by hydration failure must be reported as an unreconciled state, not full success.

### 19. UI boundary

The minimum usable increment includes:

- category management under the approved Settings surface;
- create;
- rename;
- parent selection;
- archive and restore;
- delete-unused confirmation;
- assigned-category deletion rejection;
- category display in transaction presentation;
- transaction-detail category picker;
- assign, change, and clear;
- no-category empty-state guidance.

The initial increment excludes:

- category filtering;
- context-menu assignment;
- inline editing;
- bulk selection;
- bulk assignment;
- drag-and-drop;
- custom ordering;
- analytics;
- budgets;
- rules.

A UI behavior supplement must be approved before implementation.

### 20. Diagnostics and privacy

Diagnostics remain governed by ADR-026.

Diagnostic logs must not expose:

- category names;
- transaction descriptions;
- transaction references;
- account identifiers;
- financial identifiers;
- source names;
- raw rows;
- SQL;
- paths;
- unrestricted repository errors.

Bounded operation and failure classifications are allowed.

### 21. Concurrency and stale state

Repository operations must revalidate current state.

A stale caller must not:

- assign an archived category;
- delete a newly assigned category;
- violate sibling uniqueness;
- create unsupported depth;
- assign across workspaces.

The initial architecture may rely on same-process coordination plus database constraints.

Broader cross-process coordination remains separately governed.

### 22. Failure semantics

Domain failures must distinguish at least:

- invalid name;
- duplicate sibling name;
- category not found;
- transaction not found;
- transaction not trusted or not persisted;
- cross-workspace relationship;
- parent not found;
- unsupported depth;
- hierarchy cycle;
- archived assignment target;
- category has assignments;
- category has children;
- repository write failure;
- hydration failure.

Raw SQLite strings must not become the public contract.

Failed operations must leave no partial relationship state.

## Consequences

### Positive

- Imported financial truth remains untouched.
- Categories gain stable identity.
- Assignments survive hydration and relaunch.
- Uncategorized needs no synthetic row.
- Existing transactions need no backfill.
- Assigned categories cannot disappear silently.
- Archived categories preserve historical display.
- Future rules gain stable category targets.
- SQLite and In-Memory can share one contract suite.

### Negative

- A new migration, repository, store, coordinator, and hydration scope are required.
- Runtime transactions must expose durable repository identity.
- Two-level hierarchy validation is required.
- Bulk reassignment and merging remain deferred.
- UI interaction states require approval.

## Rejected Alternatives

- Category ID directly on the trusted transaction row.
- Transient runtime UUID as assignment identity.
- Persisted Uncategorized row.
- Unlimited hierarchy initially.
- Flat-only persistence.
- Seeded default taxonomy.
- Assignment history initially.
- Multiple categories.
- Automatic clearing or replacement on deletion.
- Generic annotation storage.
- View-model-owned canonical assignment state.

## Non-Goals

This ADR does not authorize:

- automatic categorization;
- rules;
- AI classification;
- merchant normalization;
- recurring detection;
- analytics;
- budgets;
- tags;
- split transactions;
- custom ordering;
- built-in taxonomy;
- bulk assignment;
- bulk reassignment;
- category merge;
- delete-with-replacement;
- assignment history;
- global undo;
- financial-history repair;
- changes to Money, parsers, provenance, or duplicate detection;
- cloud synchronization.

## Implementation Prerequisites

Implementation must not begin until:

1. this ADR is Accepted;
2. Sprint 45 has completed or its final repository state is known;
3. provider and hydration ownership are revalidated against the post-Sprint-45 HEAD;
4. durable persisted transaction identity can be exposed during hydration;
5. category UI behavior is approved;
6. provider parity can be tested;
7. the next migration number is confirmed.

Exact stop condition:

> Stop if a trusted hydrated transaction cannot expose and preserve its immutable persisted repository transaction ID across forced hydration, provider reconstruction, and relaunch.

Never fall back to a generated runtime UUID.

## Verification Requirements

Future implementation must verify:

- immutable category identity;
- deterministic normalization and ordering;
- sibling uniqueness;
- root/child creation;
- rejection of self-parenting, cycles, and grandchildren;
- workspace isolation;
- archive/restore;
- archived-category historical visibility;
- Uncategorized as absence;
- assign/change/clear/idempotence;
- trusted persisted transaction requirement;
- delete-unused success;
- assigned/parent-category deletion rejection;
- SQLite/In-Memory parity;
- additive migration with unchanged existing transactions;
- Money, currency, source, provenance, fingerprint, and event-identity invariance;
- stable repository transaction identity across hydration and relaunch;
- all-or-nothing hydration;
- privacy-safe diagnostics;
- approved UI and accessibility behavior.

## Documentation Impact

After verified implementation:

- remove or narrow completed `FW-P2-20` scope;
- record the final migration number;
- record durable runtime transaction identity;
- record category store and hydration ownership;
- record archive and deletion semantics;
- retain rules, history, bulk mutation, analytics, budgets, and AI as separate future work;
- update `PROJECT_STATE.md` only with verified results.

This ADR must be marked **Accepted** before category implementation begins.

---

# ADR-037 — Financial Mutation Planning, Authorization, Atomic Execution, and Family-Specific Reversal

## Status

Proposed

## Date

2026-07-17

## Decision Owners

LedgerForge architecture

## Related Work

- `FW-P0-16 — Reversible Financial-Mutation Foundation`

## Extends

- ADR-013 — Store Ownership
- ADR-024 — Repository Hydration Boundary
- ADR-025 — Stable Financial Entity Identity
- ADR-027 — Parser-Owned Financial Identifier Extraction
- ADR-029 — User-Confirmed Financial Identifier Attachment
- ADR-030 — Versioned Exact-Content Fingerprints and Atomic Import-History Commit
- ADR-031 — Verified Transaction-Event Evidence and Pre-Write Duplicate Blocking
- ADR-032 — Durable Import Attempt History and Rejected-Outcome Semantics
- ADR-033 — Deterministic Money and Native-Currency Integrity

## Supersedes

None

## Context

LedgerForge persists trusted financial history through repository-owned storage.

Current production mutations include:

- workspace creation;
- account creation;
- verified identifier attachment;
- successful import-session persistence;
- trusted transaction insertion;
- exact-statement fingerprint registration;
- transaction-event identity claims;
- import-attempt recording;
- account display-name updates.

The current architecture provides narrow atomicity for successful import history. It does not provide a general-purpose financial-mutation transaction.

During a confirmed import, workspace, account, institution, and identifier writes may occur before the atomic import-history transaction begins. Those earlier side effects may survive a later import-history failure.

Existing repository protocols also expose partial mutation capabilities such as workspace upsert, account upsert, identifier attachment, session creation and update, attempt recording, and transaction replacement.

These APIs are not a safe cross-domain correction or reversal mechanism.

LedgerForge currently has no approved architecture for:

- correcting trusted financial history;
- reversing a completed import;
- moving transactions between accounts;
- detaching or reassigning financial identifiers;
- merging or splitting accounts;
- deleting trusted transactions;
- repairing historical duplicate decisions;
- undoing completed financial mutations;
- recording mutation-specific successful audit evidence;
- proving that a completed mutation can be reversed or compensated.

Ordinary database transaction rollback protects against failure before commit. It does not reverse a completed mutation.

Database backup and restore may recover an entire database lifecycle failure. They do not provide record-level authorization, review, audit, or selective reversal.

`FW-P0-16` exists to establish the shared architecture required by future mutation families.

This ADR defines that shared architecture.

It does not authorize any concrete financial mutation.

## Decision drivers

The architecture must:

- preserve immutable financial identity;
- preserve parser-owned identifier provenance;
- preserve source-document and import-session provenance;
- preserve exact-statement fingerprint authority;
- preserve transaction-event identity authority;
- preserve exact `Money` and native-currency integrity;
- derive plans from authoritative repository state;
- make review read-only;
- reject stale plans;
- bind authorization to the exact reviewed plan;
- execute all family-specific writes atomically;
- commit successful audit evidence with financial writes;
- preserve SQLite and In-Memory provider parity;
- reconcile runtime state only through `RepositoryStoreHydrator`;
- distinguish rollback, reversal, compensation, and backup restoration;
- avoid claiming universal undo;
- avoid creating a speculative generic mutation schema;
- keep every concrete operation family independently governed.

## Decision

LedgerForge will adopt an eight-stage financial-mutation lifecycle:

```text
authoritative snapshot
    ↓
deterministic mutation plan
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
family-specific reversal, compensation, or explicit irreversibility
```

The shared architecture defines the lifecycle and generic envelope.

Each concrete mutation family owns its financial meaning, affected-record rules, conflict policy, write set, audit requirements, and reversal or compensation semantics.

### 1. Architecture-only initial strategy

`FW-P0-16` will initially establish architecture contracts only.

The initial increment will not introduce:

- an executable financial mutation;
- a generic mutation repository implementation;
- a mutation database table;
- a generic audit ledger;
- a schema migration;
- mutation UI;
- account merge;
- account split;
- import reversal;
- transaction deletion;
- identifier detachment;
- historical repair;
- application-wide undo.

Source-level protocols and persistence schemas must wait until one independently approved mutation family provides concrete requirements.

### 2. Generic lifecycle versus family ownership

The shared financial-mutation architecture owns:

- lifecycle states;
- immutable plan-envelope requirements;
- deterministic encoding;
- plan-digest binding;
- scoped-precondition binding;
- provider-generation binding;
- review and authorization separation;
- single-use authorization;
- provider-owned atomic execution;
- successful-audit atomicity;
- runtime-reconciliation outcomes;
- privacy boundaries;
- provider-parity requirements;
- reversal classification.

A concrete mutation family owns:

- eligible source records;
- affected durable record types;
- before and after relationships;
- financial-impact calculation;
- identifier impact;
- import-session impact;
- transaction impact;
- conflicts;
- warnings;
- validation;
- durable writes;
- successful audit payload;
- inverse operation;
- compensation behavior;
- irreversibility conditions;
- family-specific UI;
- family-specific migration requirements.

The generic layer must not infer family behavior.

### 3. Authoritative planning state

Mutation planning must read authoritative durable state through a dedicated repository boundary.

Planning must not use runtime stores as mutation authority.

Runtime stores may support presentation, but a mutation plan must be generated from repository state.

The planning read must include every record and query set relevant to the family, including records whose later insertion could create a conflict.

A plan generated from incomplete authoritative scope is not executable.

### 4. Immutable deterministic plan

Every proposed mutation must be represented by an immutable typed plan.

The minimum generic plan envelope must contain:

- opaque plan identity;
- closed operation-family code;
- operation-family version;
- planning-algorithm version;
- bounded reason code;
- actor classification;
- provider generation;
- scoped precondition token;
- deterministically ordered affected durable-record identities;
- typed before relationships;
- typed proposed after relationships;
- exact financial impact grouped by native currency;
- identifier-impact summary;
- import and provenance-impact summary;
- transaction-impact summary;
- expected runtime-store impact;
- typed preconditions;
- typed blocking conflicts;
- typed non-blocking warnings;
- reversibility classification;
- canonical plan digest.

The plan must be:

- immutable;
- equatable;
- sendable where applicable;
- canonically encodable;
- independent of dictionary iteration;
- independent of repository query ordering;
- independent of locale;
- independent of display-name changes;
- independent of filenames;
- independent of presentation-only runtime identity.

The plan digest must bind every execution-relevant field.

A digest is a staleness and authorization mechanism. It is not financial-identity evidence.

### 5. Durable record identities

Affected records must be addressed only through durable repository identities.

The architecture must not establish or infer identity using:

- display name;
- filename;
- institution label;
- masked account number;
- last four digits;
- suffix;
- narration;
- amount;
- transaction date;
- transaction similarity;
- runtime presentation UUID;
- other weak evidence.

Repository account identity remains immutable.

Parser-produced verified financial identifiers remain parser-owned evidence.

Transaction-event identity, exact-statement fingerprints, import sessions, import attempts, and source-document relationships remain distinct authorities.

The generic mutation envelope must not collapse these concepts into one generic history ID.

### 6. Exact financial impact

Every mutation family affecting financial records must calculate impact using exact `Money`.

Financial impact must be:

- grouped by canonical native currency;
- deterministically ordered;
- scale-consistent;
- free from binary floating-point reconstruction;
- explicit when no financial-value change occurs.

Cross-currency totals must not be silently combined.

A plan requiring unsupported currency conversion remains non-executable until a separately approved reporting-currency or FX architecture exists.

Unknown financial impact is a blocking condition.

### 7. Read-only preview

Mutation review is read-only.

Preview generation must not:

- modify durable records;
- reserve identities;
- reserve fingerprints;
- reserve transaction-event claims;
- create audit rows;
- change runtime stores;
- create an executable mutation merely by displaying it.

The preview must present:

- affected record types and counts;
- relevant before and proposed after relationships;
- exact native-currency impact;
- provenance impact;
- identifier impact;
- blocking conflicts;
- warnings;
- reversibility or compensation classification;
- unsupported or unknown effects.

Unknown or unsupported execution-critical impact blocks authorization.

### 8. Authorization

Planning, reviewing, authorizing, and executing are distinct states.

The minimum lifecycle is:

```text
planned
    ↓
reviewed
    ↓
confirmed
    ↓
executing
    ↓
committed
```

Alternative terminal states include:

- withdrawn;
- stale;
- conflicted;
- rejected;
- failed;
- committed but unreconciled.

Confirmation produces a single-use typed authorization.

Authorization must bind:

- plan identity;
- exact plan digest;
- provider generation;
- scoped precondition token;
- operation-family code and version;
- confirming actor classification;
- confirmation time.

Authorization must not be reusable.

Authorization must not execute another plan.

Authorization must not survive provider replacement.

Authorization must not bypass transaction-time revalidation.

Withdrawing authorization prevents future execution but does not reverse a committed mutation.

### 9. Scoped precondition token

Every plan must include a versioned scoped precondition token.

The token must represent all authoritative state relevant to execution, including:

- expected record existence;
- expected record ownership;
- expected relationships;
- expected family-specific state;
- relevant conflict-query membership;
- relevant uniqueness claims;
- relevant identifier ownership;
- relevant fingerprint or transaction-event relationships;
- expected native currencies;
- expected provider generation.

The token may use a canonical snapshot digest.

The initial architecture does not require a global database revision column.

Execution must re-read the same authoritative scope inside the durable transaction and recompute the token.

A relevant inserted, deleted, or changed record must make the plan stale or conflicted.

### 10. Provider generation

Every mutation plan and authorization must be bound to the installed provider generation.

Provider replacement, database reset, database restore, or another lifecycle transition must invalidate all outstanding plans and authorizations from the previous generation.

The exact provider-generation mechanism must be revalidated after Sprint 45.

No mutation may execute when:

- provider generation is unknown;
- provider identity changed;
- repositories belong to another provider generation;
- lifecycle quiescence is incomplete;
- the mutation coordinator holds stale repository references.

### 11. Provider-owned execution boundary

A future executable implementation must introduce one provider-owned financial-mutation boundary.

The exact Swift protocol and method names remain implementation decisions.

The boundary must own:

- authoritative mutation snapshots;
- transaction-time precondition revalidation;
- conflict recalculation;
- financial-impact recalculation;
- family-specific writes;
- successful audit insertion;
- affected-record verification;
- commit or rollback.

The UI, view models, runtime stores, and mutation coordinator must not coordinate several existing repository APIs to simulate one mutation transaction.

### 12. Atomic execution

For SQLite, execution must occur in one provider-owned database transaction.

The required logical sequence is:

1. acquire provider-scoped serialization;
2. begin an immediate write transaction or approved equivalent;
3. verify provider generation;
4. re-read authoritative scoped state;
5. recompute the precondition token;
6. recompute conflicts;
7. recompute exact impact;
8. verify reversal or compensation eligibility;
9. reject stale or changed plans before writes;
10. apply the complete family-specific write set;
11. insert successful audit evidence;
12. verify affected-record counts and constraints;
13. commit.

Any failure before commit must roll back all family writes, successful audit evidence, and mutation-state changes.

For the In-Memory provider, equivalent behavior requires:

1. one mutation-state lock;
2. copying every affected collection;
3. identical revalidation;
4. identical conflict calculation;
5. identical writes to the copies;
6. identical successful-audit creation;
7. publishing all copies together.

SQLite and In-Memory must return equivalent observable outcomes.

### 13. Successful audit atomicity

A successful financial mutation must not commit without successful audit evidence.

The audit and family-specific writes must commit in the same provider-owned transaction.

The minimum successful audit evidence must include:

- mutation identity;
- operation-family code and version;
- planning-algorithm version;
- committed time;
- bounded reason code;
- bounded actor classification;
- confirmed plan digest;
- precondition-token version;
- deterministically ordered affected record types and durable IDs;
- typed before and after relationship summaries;
- exact native-currency impact;
- identifier, import, and transaction-impact summaries;
- reversal or compensation classification;
- original mutation reference when applicable;
- schema or payload version needed to interpret the record;
- successful outcome classification.

A committed financial mutation without its required successful audit is prohibited.

### 14. Audit privacy

Generic audit evidence must not contain:

- passwords;
- credentials;
- raw financial identifier values;
- unrestricted source-document content;
- source fragments;
- unrestricted transaction narration;
- unrestricted payee or reference text;
- filenames;
- filesystem paths;
- raw exact-statement fingerprints;
- raw transaction-event digests;
- unrestricted database rows;
- arbitrary serialized domain objects;
- arbitrary JSON payloads;
- unrestricted localized errors.

A concrete family may request additional restoration material only through its own approved ADR and privacy review.

The generic architecture must not presume that an audit row can recreate a deleted record.

### 15. Failure attempts

A failed execution attempt is not a successful mutation audit.

A family may record a bounded failure attempt separately when infrastructure permits.

Failure-attempt recording must not:

- convert failure into success;
- prevent rollback;
- expose prohibited sensitive values;
- become a substitute for successful-audit atomicity.

If the database is unavailable, recording the failed attempt may itself be impossible.

The original mutation failure remains authoritative.

### 16. Rollback, reversal, compensation, and restoration

The architecture distinguishes four concepts.

#### Rollback before commit

A provider transaction fails before commit.

No completed mutation exists.

All family writes and successful audit evidence are rolled back.

#### Reversal after commit

A reversal is a new mutation.

It must:

- have its own plan;
- have its own review;
- have its own authorization;
- revalidate current state;
- reference the original mutation;
- use family-specific inverse semantics;
- create its own successful audit.

The original mutation remains part of history.

#### Compensation

Compensation creates a new provenance-bearing effect that offsets a prior result without pretending the original result never occurred.

Compensation semantics are family-specific.

#### Database restoration

Database backup restore is a database-lifecycle recovery operation.

It is not selective financial reversal, mutation preview, record-level audit, authorization, or family-specific compensation.

### 17. No universal undo

LedgerForge will not provide generic application-wide undo for trusted financial mutations through this foundation.

Each mutation family must classify itself as:

- reversible;
- compensatable;
- irreversible;
- unsupported.

A reversible family must prove:

- what is restored;
- what remains preserved;
- what new audit evidence is created;
- which later changes can block reversal;
- how conflicts are reported;
- how the original mutation remains represented.

A family that cannot prove its inverse must not be labelled reversible.

### 18. Family-specific execution requirement

No operation family may become executable based only on this ADR.

Before implementation, each family requires an independently approved decision defining:

- operation meaning;
- eligible records;
- affected-record discovery;
- conflict policy;
- impact calculation;
- immutable records;
- permitted new records;
- exact durable write set;
- successful audit payload;
- reversal or compensation behavior;
- privacy requirements;
- schema requirements;
- hydration impact;
- UI and confirmation behavior;
- provider-parity tests;
- migration and rollback tests.

Examples include account merge, account split, identifier detachment, import-session reversal, transaction deletion, duplicate repair, and historical correction.

### 19. Runtime reconciliation

After a durable mutation commits, LedgerForge must perform one forced canonical reconciliation through `RepositoryStoreHydrator`.

The acceptable sequence is:

```text
provider-owned durable commit
    ↓
forced RepositoryStoreHydrator reconciliation
    ↓
canonical runtime stores
    ↓
view models
    ↓
views
```

Runtime stores must not be manually patched to simulate mutation completion.

The repository and successful audit prove durable completion.

Required generic results include:

- committed and reconciled;
- committed but reconciliation failed;
- not committed;
- stale;
- conflicted;
- provider mismatch;
- unauthorized;
- unsupported.

### 20. Reconciliation failure after commit

Hydration failure after a durable commit must not be reported as an uncommitted mutation.

The system must report:

- the mutation committed;
- runtime reconciliation failed;
- the durable mutation identity;
- a bounded recovery action.

The system must:

- prevent stale runtime state from authorizing another mutation;
- retry canonical hydration;
- avoid manually editing stores;
- preserve the committed mutation and successful audit.

Automatic financial rollback solely because runtime hydration failed is prohibited.

### 21. Provider parity

A future executable mutation boundary must provide equivalent SQLite and In-Memory behavior for:

- canonical plan contents;
- affected-record ordering;
- precondition tokens;
- provider-generation checks;
- conflict sets;
- warning sets;
- exact impact summaries;
- stale-plan outcomes;
- authorization outcomes;
- execution results;
- audit results;
- reversal eligibility;
- failure classifications;
- atomic failure residue.

Provider-specific implementation errors must map into shared domain-level outcomes.

### 22. Concurrency boundary

The minimum architecture requires:

- same-process provider-scoped serialization;
- provider-generation validation;
- transaction-time scoped-state revalidation;
- database constraints as final integrity guards;
- deterministic stale and conflict outcomes.

This ADR does not claim to solve:

- all existing writes from multiple application processes;
- arbitrary external SQLite writers;
- malicious file modification;
- lock-bypassing code;
- global serialization across every legacy write path.

A concrete family must stop if its correctness depends on guarantees beyond the implemented concurrency boundary.

### 23. Source truth and provenance preservation

A generic mutation must not rewrite immutable imported source truth merely to simplify reversal.

Normally preserved records include:

- repository account identity;
- parser-produced identifier provenance;
- imported documents;
- exact fingerprints;
- successful import sessions;
- import attempts;
- transaction-event identity claims;
- trusted transaction/source relationships.

A family may introduce typed relationship history, tombstones, supersession records, exclusion records, compensating entries, or other immutable history only through family-specific approval.

### 24. Planning and execution errors

The shared architecture must distinguish typed failures such as:

- unsupported family;
- planning-read failure;
- incomplete affected-record scope;
- unknown impact;
- invalid native-currency impact;
- blocking conflict;
- stale plan;
- provider mismatch;
- authorization withdrawn;
- authorization already consumed;
- plan-digest mismatch;
- precondition-token mismatch;
- family validation failure;
- family write failure;
- successful-audit failure;
- commit failure;
- committed reconciliation failure;
- reversal unavailable;
- compensation unavailable.

Raw SQLite errors and unrestricted localized messages must not become the public mutation contract.

### 25. Determinism

For the same authoritative state and request, both providers must produce the same canonical plan.

Plan contents must not vary because of:

- dictionary order;
- repository query order;
- locale;
- timezone formatting;
- display-name ordering;
- filenames;
- view sort order;
- transient runtime UUIDs;
- diagnostic timestamps;
- memory addresses.

Affected records, conflicts, warnings, and currency impacts must be deterministically ordered.

### 26. Schema strategy

This ADR adopts a contract-first schema strategy.

No generic financial-mutation schema is introduced by `FW-P0-16`.

No generic audit ledger is introduced.

No migration is required for the architecture-only foundation.

A later operation family may require a migration after proving:

- exact audit fields;
- inverse or compensation material;
- privacy-safe payload;
- retention requirements;
- query requirements;
- hydration requirements;
- provider parity;
- migration safety.

A generic arbitrary JSON mutation payload is rejected.

### 27. UI boundary

This ADR does not approve a generic mutation UI.

Every mutation family must define its own review and confirmation surface.

No financial mutation may execute directly from a context menu, table action, or developer tool without the family’s approved review and authorization contract.

### 28. Diagnostics

Financial-mutation diagnostics remain governed by ADR-026.

Diagnostics must remain structured, deterministic, bounded, privacy-safe, and in memory unless another ADR explicitly permits persistence.

Generic diagnostics may contain family code, lifecycle state, result classification, provider-generation classification, affected-record counts, conflict counts, and approved bounded impact summaries.

Diagnostics must not contain prohibited audit or source values.

### 29. Development database lifecycle relationship

Sprint 45 may introduce reusable low-level infrastructure for:

- provider quiescence;
- provider generation;
- provider replacement;
- migration recreation;
- verified backup;
- forced hydration.

That infrastructure remains outside the financial-mutation contract.

Provider reset or restore must invalidate all outstanding mutation plans and authorizations.

Database backup must not become the reversal implementation for a financial mutation.

### 30. Implementation stop conditions

No financial mutation may become executable when any of the following is true:

- affected durable records cannot be enumerated deterministically;
- before and after relationships are incomplete;
- exact financial impact is unknown;
- native-currency effects cannot be represented safely;
- relevant state changes cannot invalidate the plan;
- provider generation cannot be verified;
- transaction-time revalidation cannot occur;
- family writes and successful audit cannot share one provider transaction;
- SQLite and In-Memory outcomes cannot be made equivalent;
- reversal or compensation semantics are undefined;
- required restoration material would violate privacy;
- immutable identity or provenance would need to be rewritten;
- canonical hydration cannot reconstruct runtime state;
- the family depends on unsupported concurrency guarantees.

At any stop condition, the operation remains non-executable.

Best-effort financial mutation is prohibited.

## Consequences

### Positive consequences

- Mutation planning is separated from execution.
- User review is bound to the exact executable plan.
- Stale previews cannot silently execute.
- Cross-domain writes cannot be coordinated through UI or partial repositories.
- Successful financial changes cannot commit without successful audit evidence.
- Runtime state remains subordinate to durable repository state.
- Reversal is explicit and family-specific.
- Compensation and irreversibility remain honest outcomes.
- Exact native-currency impact is preserved.
- Weak identity evidence remains excluded.
- Future mutation families can share one lifecycle without sharing incorrect semantics.
- No speculative mutation schema is introduced.

### Negative consequences

- No financial mutation becomes immediately executable.
- Every family still requires its own discovery and ADR.
- Plan and authorization models require substantial deterministic testing.
- Provider generation and transaction-time stale checks become mandatory.
- SQLite and In-Memory parity requirements become stricter.
- Successful audit must participate in the same durable transaction.
- Hydration failure after commit requires a distinct recovery state.
- Generic undo remains unavailable.
- A later concrete family is still required to prove completed reversal end to end.

## Rejected alternatives

Reject:

- using existing partial repository APIs as a mutation coordinator;
- treating ordinary rollback as completed reversal;
- treating database restore as selective undo;
- adding a generic mutation ledger immediately;
- storing arbitrary JSON before/after snapshots;
- pairing the foundation with an arbitrary demonstration operation;
- allowing a coordinator to call multiple repositories to simulate atomicity;
- using runtime stores as mutation authority;
- implementing universal undo;
- requiring a global revision counter before concrete evidence requires it.

## Non-goals

This ADR does not authorize:

- account merge;
- account split;
- account deletion;
- identifier detachment;
- identifier reassignment;
- transaction deletion;
- transaction movement;
- import-session deletion;
- import-session reversal;
- duplicate repair;
- historical correction;
- bulk transaction actions;
- application-wide undo;
- persistent mutation diagnostics;
- cloud synchronization;
- backup-based financial undo;
- automatic repair;
- AI-selected financial mutation;
- Developer Console mutation execution;
- a generic mutation schema;
- a schema migration.

## Implementation prerequisites

Before source-level mutation contracts or an operation family are implemented:

1. this ADR must be Accepted;
2. Sprint 45 provider-lifecycle changes must be known;
3. provider generation and quiescence must be revalidated;
4. provider replacement must invalidate old plans and authorizations;
5. a concrete mutation family must be selected independently;
6. that family must define affected records, conflicts, write set, audit, and inverse or compensation;
7. SQLite and In-Memory parity must be demonstrable;
8. exact Money impact must be defined;
9. privacy-safe audit evidence must be defined;
10. family schema and migration requirements must be approved;
11. family UI review and authorization behavior must be approved.

## Verification requirements

A future implementation must verify at minimum:

- identical plans under SQLite and In-Memory;
- canonical encoding and stable digest;
- deterministic affected-record ordering;
- relevant changes and inserted conflicts invalidate plans;
- provider replacement invalidates plans;
- withdrawn and consumed authorizations cannot execute;
- authorization cannot execute another digest;
- transaction-time precondition revalidation;
- write failures roll back family writes and successful audit;
- successful-audit failure rolls back family writes;
- write and successful audit cannot commit separately;
- irreversible families cannot claim reversal;
- reversal is a new linked mutation;
- reversal failure preserves the original mutation;
- exact native-currency impact;
- cross-currency aggregation rejection;
- immutable account identity;
- parser-owned identifier provenance;
- fingerprint and event-identity preservation;
- import-session and attempt provenance;
- committed reconciliation failure remains distinct from non-commit;
- deterministic hydration retry;
- stale runtime state cannot authorize another mutation;
- provider-equivalent typed failures and failure injection;
- privacy checks for plans, audits, diagnostics, and errors;
- same-process serialization;
- bounded two-connection SQLite stale-state testing without claiming complete external-writer safety.

## Documentation impact

After this architecture decision is accepted:

- update `FW-P0-16` to record discovery complete and planning approved;
- record Strategy A as contract-first;
- record that no migration or executable mutation is authorized;
- record post-Sprint-45 provider-lifecycle revalidation;
- retain every concrete mutation family as separate work;
- use the current import-session reversal candidate ID, `FW-P1-27`;
- do not mark downstream mutation candidates implementation-ready;
- update `PROJECT_STATE.md` only after a verified implementation increment.

This ADR must be marked **Accepted** before source-level financial-mutation contracts or an executable mutation family are implemented.
