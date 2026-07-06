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
The import pipeline should rely on reusable components (reader, analyzer, detector, normalizer, parser) instead of institution-specific workflows.

## Rationale
Supporting new financial institutions should primarily require new profiles and mappings rather than new parser implementations.

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
- DocumentStore owns imported transactions.
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
