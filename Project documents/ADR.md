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
The import pipeline should rely on reusable architectural components (ImportCoordinator, Document Reader, Institution Detection, Document Classification, Parser Selection, Statement Parser and Validation) instead of institution-specific workflows.

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
All supported import formats (PDF, CSV, XLS, XLSX and TXT) must converge into a single `FinancialDocument` domain model before institution detection, parser selection or validation occurs.

## Rationale
Keeping downstream components independent of file formats dramatically simplifies parser development, testing and long-term maintenance.

## Consequences
- Readers understand file formats only.
- Parsers never know the original file format.
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
- Institution Detection and Document Classification operate on extracted content.

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
- Readers receive decrypted document content rather than handling passwords directly.
- Users are prompted only when no stored credential succeeds.

---

# ADR-016 — Universal Import Pipeline

## Status
Accepted

## Decision

Every imported financial document must follow the same deterministic processing pipeline regardless of its original file format.

The canonical import flow is:

Financial Document
↓
Initial Institution Detection (when possible)
↓
Password Resolution (if required)
↓
Document Reader
↓
FinancialDocument
↓
Institution Detection
↓
Document Classification
↓
Parser Selection
↓
Statement Parser
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

Everything after `FinancialDocument` is format-independent.

## Consequences

- CSV, PDF, XLS, XLSX and TXT share the same downstream pipeline.
- Password resolution occurs before document extraction when required.
- Duplicate detection works across different file formats representing the same financial statement.
- Validation remains centralized.
- Stores receive only validated domain objects.
This ADR extends ADR-011 by defining the complete document ingestion workflow.
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

## Decision

Production CSV imports now execute through the Unified Import Framework.

The canonical production import flow is:

Financial Document
↓
ImportCoordinator
↓
ReaderRegistry
↓
Document Reader
↓
FinancialDocument
↓
Institution Detection
↓
Document Classification
↓
Parser Selection
↓
Statement Parser
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
