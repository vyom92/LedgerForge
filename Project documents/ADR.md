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
Document Reader
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
Fingerprinting & Duplicate Detection
↓
Repositories
↓
SQLite
↓
Stores
↓
ViewModels
↓
Dashboard

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
Document Reader
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
Fingerprinting & Duplicate Detection
↓
Repositories
↓
SQLite
↓
Stores
↓
ViewModels
↓
Dashboard

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

The approved downstream application flow is:

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

- Sprint 31 implementation is complete
- automated validation passes
- manual runtime verification passes
- Sprint 31 is recorded in `PROJECT_STATE.md`

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

Sprint 38 — planned; implementation pending

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
