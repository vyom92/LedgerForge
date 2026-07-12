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

Sprint 25 foundation; future matching capabilities remain deferred

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
- Verified identifiers must be canonicalised and stored separately from presentation metadata before automatic cross-file account matching is enabled.
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

## Intended Implementation

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

## Acceptance

Change the status from **Proposed** to **Accepted** only after:

- Sprint 31 implementation is complete
- automated validation passes
- manual runtime verification passes
- Sprint 31 is recorded in `PROJECT_STATE.md`
