# LedgerForge Project Context

## Current Phase

Phase 3 — Financial Document Foundation

LedgerForge has completed its core CSV import architecture and foundational data pipeline. The current objective is to evolve into an offline-first financial document ingestion platform capable of importing documents from multiple financial institutions while preserving financial correctness.

---

## Current Architecture

Financial Document
↓
ImportCoordinator
↓
Reader (PDF / CSV / XLS / XLSX / TXT)
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
ImportSession
↓
TransactionStore
↓
AccountStore
↓
DashboardViewModel
↓
Views

All supported document formats must converge into this single deterministic pipeline.

---

## Completed Milestones

- CSV import framework
- Statement normalization
- Institution detection
- Direction resolution
- Validation framework
- Import sessions
- TransactionStore
- AccountStore
- Reactive dashboard foundation
- Financial Snapshot
- Product Vision
- Architecture documentation
- Engineering Standards
- Architecture Decision Records (ADRs)
- GitHub Copilot project instructions
- Xcode MCP integration

---

## Current Priorities

1. FinancialDocument domain model
2. Password management for encrypted financial documents
3. Generic document readers
4. Institution detection from extracted document content
5. Document classification (Bank, Credit Card, Brokerage, Insurance, Salary, etc.)
6. Parser integration with the existing pipeline
7. Regression suite expansion using real reference documents

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

Readers extract data.

Parsers interpret data.

Validation verifies data.

Stores own data.

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

1. Read Product Vision.
2. Read Architecture documentation.
3. Read Engineering Standards.
4. Read ADRs.
5. Read Copilot instructions.
6. Verify required reference documents exist.
7. Verify the filename in the first comment block before editing any file.
8. Produce an implementation plan.
9. Obtain approval.
10. Implement one sprint.
11. Build continuously.
12. Run regression tests where applicable.
13. Commit.

---

## Definition of Success

LedgerForge becomes the trusted offline financial operating system that ingests financial documents from multiple institutions, automatically identifies their origin and document type, securely unlocks encrypted statements, extracts accurate financial data, validates every result before persistence, and presents a trustworthy multi-currency financial dashboard.
