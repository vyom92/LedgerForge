# LedgerForge Project Context

## Current Phase

M7 — Dashboard Experience (Sprint 19)

LedgerForge has completed its foundational multi-format import architecture, deterministic document ingestion pipeline and repository integration cleanup. The current objective is Dashboard Foundation while preserving validated import, persistence and repository boundaries from Sprint 18.

---

## Current Architecture

ImportCoordinator
↓
Reader (PDF / CSV / XLS / XLSX / TXT)
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
Repositories
↓
SQLite
↓
TransactionStore
↓
AccountStore
↓
DashboardViewModel
↓
Views

All supported document formats converge into this single deterministic pipeline.
This pipeline is the canonical production architecture defined by the current ADRs and PROJECT_STATE.md.

---

## Completed Milestones

- Multi-format import framework
- RawDocument extraction
- Institution Detection
- Statement Classification
- Parser Selection
- FinancialDocument-native parsing
- Validation framework
- Repository integration cleanup
- Import sessions
- TransactionStore
- AccountStore
- Reactive dashboard foundation
- Financial Snapshot
- Product Vision
- Architecture documentation
- Engineering Standards
- Architecture Decision Records (ADRs)
- AI workflow documentation
- Xcode MCP integration

---

## Current Priorities

1. Dashboard foundation.
2. Expand regression fixtures.
3. Generic PDF reader improvements.
4. Password handling for encrypted financial documents.
5. Insights and analytics.

---

## Financial Principles

- Preserve imported financial truth.
- Native currency is never modified.
- Currency conversion is presentation only.
- Support multiple currencies simultaneously.
- Every financial calculation must remain deterministic, explainable and auditable.

---

## Product Principles

LedgerForge is not a CSV importer.

LedgerForge is a financial document ingestion platform.

Readers extract RawDocument.

Institution Detection identifies the source.

Statement Classification identifies the statement type.

Parser Selection chooses the appropriate parser.

Statement Parsers produce FinancialDocument.

Validation verifies financial correctness.

Stores own validated runtime state.

ViewModels present data.

Views display data.

---

## Reference Assets

Always prefer approved project references over assumptions.

Current references include:

- Dashboard reference workbook
- Approved dashboard sketches
- Axis Bank statements
- Axis Credit Card statements
- CBQ Bank statements
- CBQ Credit Card statements
- Amex statements
- HDFC statements
- IBKR statements
- Zurich ISP statements

If an implementation requires a reference that is unavailable, stop and request the appropriate document before continuing.

---

## Development Workflow

1. Read `Project_Guide.md`.
2. Read `PROJECT_STATE.md`.
3. Confirm the approved sprint and stop condition.
4. Read `Codex response.md`.
5. Use the Task Routing Guide to determine which additional documentation is required.
6. Produce an implementation plan.
7. Obtain approval.
8. Implement one approved sprint.
9. Build continuously.
10. Run the required sprint validation.
11. Commit.
12. Push the tracked branch.
13. Push the sprint tag (if applicable).
14. Update PROJECT_STATE.md after the successful commit, push and tag (if applicable).
15. Update Project_Guide.md only if workflow, roadmap or engineering guidance changed.

---

## Definition of Success

LedgerForge becomes the trusted offline financial operating system that ingests financial documents from multiple institutions, automatically identifies their origin and statement type, securely unlocks encrypted financial documents, extracts accurate financial data, validates every result before persistence, and presents a trustworthy multi-currency financial dashboard. Every supported input format must preserve identical financial truth through the deterministic import pipeline.
