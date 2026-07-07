# LedgerForge Project Guide

This is the canonical project operating manual. Read this document first, then use the Task Routing Guide to load only the documents required for the current task. Avoid loading unnecessary documentation.

## Current Project Snapshot

- **Current Milestone:** M4 – StatementParser returns FinancialDocument
- **Current Sprint:** Sprint 16
- **Current Phase:** FinancialDocument Integration Complete
- **Build Status:** Passing
- **Validation Status:** Build passing; full regression baseline passing. Sprint 15 validation complete.
- **Last Architecture Review:** 2026-07-07
- **Current Codex Baseline:** Sprint 15


## Current Architecture Status

| Component | Status/Notes |
|-----------|--------------|
| Product Vision | Current and authoritative |
| Architecture | Frozen v1.0 baseline active |
| ADRs | Current through ADR-021 |
| Database | Production-ready foundation |
| Repository Layer | Stable with contract tests |
| Persistence | SQLite repository layer active |
| Import Framework | Operational; CSV and PDF reader foundation active |
| Readers | CSV and PDF readers integrated into Unified Import Framework |
| Institution Detection | Framework implemented; legacy behaviour preserved |
| Statement Classification | Framework implemented; deterministic classification active |
| Parser Selection | Framework implemented; deterministic selector active |
| FinancialDocument | Immutable handoff model integrated after Statement Parser and before Validation |
| Password Management | Operational; DefaultPasswordProvider integrated |
| Dashboard | Existing dashboard unchanged |
| Investments | Future module |
| Validation | Build passing; full regression baseline passing. Sprint 15 validation complete |
| Documentation | Project_Guide.md is canonical routing document |
| Import Pipeline | Production CSV routed through ImportCoordinator |
| Repository Contract Tests | Active for InMemory and SQLite providers |


## Canonical Import Pipeline

```text
ImportCoordinator
↓
PasswordProvider
↓
ReaderRegistry
↓
Reader (CSV/PDF)
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
```


## Documentation Index

| Document                          | Purpose                                             | Read When                          | Priority    |
|----------------------------------|-----------------------------------------------------|-----------------------------------|-------------|
| Architecture_v1.0_Frozen.md       | Definitive system design and constraints             | Architecture review, design tasks | Highest     |
| ADR.md                          | Architecture Decision Records documenting key decisions | Architecture review, design tasks | High        |
| Project documents/PROJECT_STATE.md | Permanent verified repository state and AI handoff | Every implementation session | Highest |
| Database_v1_Architecture.md       | Database schema and component design                  | Database changes, design tasks    | High        |
| Product Vision.md               | High-level goals, target users, and product impact    | New feature planning              | High        |
| Engineering Standards.md        | Coding standards and engineering guidelines           | All engineering tasks             | Medium      |
| AI_WORKFLOW.md                 | Workflow instructions for AI assistants                | All AI-related tasks              | Medium      |
.github/Project_Context.md
| .github/ai-instructions.md     | AI behavior and interaction policies                   | AI onboarding                    | Medium      |
| .github/prompts.md             | Prompt templates and examples for AI responses         | AI onboarding                    | Medium      |
| Project documents/Codex response.md | Current sprint working log, implementation notes, build/test progress | Sprint reviews, bug fixes, testing | High        |

Only consult the documents required by the Task Routing Guide. Do not load the complete documentation set unless performing a full architecture or repository review.

## Documentation Precedence

The precedence for documentation is as follows:

1. Architecture_v1.0_Frozen.md  
2. ADR.md  
3. Project documents/PROJECT_STATE.md  
4. Engineering Standards.md  
5. Database_v1_Architecture.md  
6. Product Vision.md  
7. AI_WORKFLOW.md  
8. Project documents/Codex response.md  

Approved documentation always overrides any implicit or assumed implementation details.

Project_Guide.md is the navigation document. It routes readers to the authoritative source rather than duplicating detailed guidance.

## Project Principles

- Offline First
- Validation Before Persistence
- Repository-Only Persistence
- Protocol-Oriented Architecture
- Deterministic Before Intelligent
- Financial Truth Never Changes
- Reference Fixtures Define Financial Truth
- One Sprint Per Implementation
- Documentation Before Implementation

## Non-Negotiable Architecture Rules

- Validation always precedes persistence.
- Repository protocols are the only abstraction permitted to access persistence.
- Repository implementations are the only components permitted to communicate with SQLite.
- Views, ViewModels and Stores never access SQLite directly.
- ImportCoordinator owns orchestration only.
- Readers understand file formats.
- Institution Detection identifies the financial institution.
Statement Classification identifies the document family.
Parser Selection chooses the appropriate parser.
Statement Parsers produce FinancialDocument.
FinancialDocument is validated before persistence.
- Stores own runtime state.
- The dashboard observes stores rather than querying persistence.

## Task Routing Guide

| Task                  | Documents to Consult                                               |
|-----------------------|-------------------------------------------------------------------|
| New Feature           | Product Vision.md, Architecture_v1.0_Frozen.md, ADR.md            |
| Database Work         | Database_v1_Architecture.md, ADR.md, Engineering Standards.md     |
| Repository Changes    | Project documents/PROJECT_STATE.md, Project documents/Codex response.md  |
| Import Framework      | Architecture_v1.0_Frozen.md, ADR.md, Engineering Standards.md     |
| Reader Implementation | Architecture_v1.0_Frozen.md, ADR.md                               |
| Parser Implementation | Architecture_v1.0_Frozen.md, ADR.md                               |
| Institution Detection | Architecture_v1.0_Frozen.md, ADR.md                               |
| Password Handling     | Architecture_v1.0_Frozen.md, ADR.md                               |
| PDF Reader | Architecture_v1.0_Frozen.md, ADR.md, Engineering Standards.md |
| Reference Fixtures | Project documents/PROJECT_STATE.md, Project documents/Codex response.md |
| UI Work               | Architecture_v1.0_Frozen.md, Engineering Standards.md             |
| Testing               | Project documents/PROJECT_STATE.md, Project documents/Codex response.md, Engineering Standards.md     |
| Bug Fixes             | Project documents/PROJECT_STATE.md, Project documents/Codex response.md, Engineering Standards.md     |
| Documentation Updates | Project_Guide.md, Engineering Standards.md                        |
| Architecture Review   | Architecture_v1.0_Frozen.md, ADR.md                               |
| Statement Classification | Architecture_v1.0_Frozen.md, ADR.md |


## Repository Structure

- **Database:** Contains database schema definitions and migration scripts.  
- **Import:** Unified Import Framework including coordinators, registries, readers, password handling protocols and import models.  
- **Models:** Domain models and business logic entities.  
- **Core:** Runtime stores and shared application state.  
- **ViewModels:** Presentation logic for UI components.  
- **Views:** UI components, screens, and layouts.  
- **Services:** Business services and legacy import support during migration.  
- **LedgerForgeTests:** Unit, integration, fixture and contract tests.  
- **LedgerForgeUITests:** UI automation tests.  
- **Project documents:** Documentation, architecture records, sprint reports.  
- **.github:** GitHub-specific configuration, AI instructions, prompts, and context.  
- **Tests:** Automated tests including unit, integration, and UI tests.  

## Folder Ownership

| Folder | Primary Responsibility | May Depend On |
|--------|------------------------|---------------|
| Views | User Interface | ViewModels |
| ViewModels | Presentation Logic | Stores |
| Stores | Runtime State | Repository Protocols |
| Repository Implementations | Persistence | SQLite |
| Database | SQLite Layer | None |
| Import | Import Orchestration | Repository Protocols |
| Services | Business Services | Repository Protocols |
| Tests | Verification | Entire Project |

## Sprint Scope Contract

Every implementation must remain inside the approved sprint.

Do NOT:

- Implement future sprints.
- Refactor unrelated code.
- Redesign approved architecture.
- Introduce optional future work.
- Modify unrelated documentation.

If future work is discovered, document it in `Project documents/Codex response.md` and stop.

Additionally:

- Verify the target file before editing.
- Add new files to the correct Xcode target.
- Add new files to the Xcode navigator.
- Preserve existing behaviour unless the sprint explicitly changes it.
- If an architectural conflict is discovered, stop implementation and document it in Project documents/Codex response.md.

## Standard AI Workflow

### 1. Before every implementation

- Confirm the requested sprint and stop condition.
- Read Project_Guide.md first.  
- Use the Task Routing Guide before opening any other document.
- Read only the documents identified by the Task Routing Guide.  
- Review Project documents/PROJECT_STATE.md.
- Review Project documents/Codex response.md for the current sprint context.
- Produce an implementation plan.  
- Wait for approval before coding.  

### 2. During implementation

- Work on one sprint only.  
- Do not implement future sprints.  
- Do not redesign approved architecture.  
- Build continuously.  
- Run the required sprint validation.
If command-line tests fail solely because of the known SwiftUI Preview tooling issue after a successful build, execute the equivalent Xcode regression suite and treat that result as authoritative.  
- If the project builds successfully and required sprint tests pass, prepare an automated Git commit.
- Verify `git status` contains only sprint-related files.
- Verify there are no unresolved merge conflict markers.
- Generate a concise commit message describing the completed sprint work.
- Commit the sprint changes.
- Push to the tracked branch (normally `origin/main`).Push the sprint tag if one was created.
- Maintain Project documents/Codex response.md during implementation.
- After a successful build, required tests, commit and push, update Project documents/PROJECT_STATE.md with the verified repository state.
- Record the commit hash, tag and push result in Project documents/Codex response.md.
- If the build or required tests fail, do not commit or push. Record the failure and stop.
- Keep changes limited to the approved sprint.  
- Keep commits logically grouped.
- Prefer extending existing architecture over introducing parallel implementations.

### 3. Before stopping

- Update Project documents/Codex response.md throughout the sprint.
- After a successful build, required validation, commit, push and tag (if applicable), update Project documents/PROJECT_STATE.md...
- Include summary, files created, files modified, build result, validation result, commit hash (if committed), tag (if created), push result, documentation updated, remaining technical debt, deferred items and next recommended sprint.  
- Stop exactly at the approved sprint boundary.  
- Confirm the repository builds successfully before considering the sprint complete.

## Sprint Roadmap

- **Completed Sprints:** Sprint 10 cleanup, Sprint 11A, Sprint 11B, Sprint 11C, Sprint 11D, Sprint 12A, Sprint 12B, Sprint 12C, Sprint 13, Sprint 14, Sprint 15
- **Current Sprint:** Sprint 16 – StatementParser returns FinancialDocument
- **Upcoming Sprints:**
  - Sprint 17 – Validation Pipeline Refinement
  - Sprint 18 – Repository Integration Cleanup
  - Sprint 19–21 – Dashboard Foundation
  - Sprint 22–24 – Insights & Analytics
  - Sprint 25+ – Multi-Currency, Investments & Ecosystem

## Product Milestones

### M1 – Robust Statement Import ✅
- CSV/PDF readers
- Password handling
- Raw document extraction
- Unified import framework

### M2 – Statement Understanding ✅
- Institution Detection
- Statement Classification
- Parser Selection

### M3 – Canonical Financial Handoff ✅
- FinancialDocument
- Validation bridge
- Regression safety

### M4 – FinancialDocument-native Parsing 🚧
- StatementParser returns FinancialDocument
- Immutable parser output
- Zero behavioural change

### M5 – Validation Intelligence
- Rule engine
- Error categorisation
- Confidence scoring

### M6 – Repository & Data Platform
- Unified persistence
- Deduplication
- Audit trail

### M7 – Dashboard Experience
- Accounts
- Net Worth
- Cash Flow
- Search
- Filters
- Trends

### M8 – Insights
- Spending analytics
- Budgets
- Smart alerts

### M9 – Ecosystem
- Multi-currency
- Investments
- Public API
- Plugin architecture

## Known Technical Debt

Maintain a concise list of active architectural and implementation debt.

Current items:

- ImportEngine still owns orchestration responsibilities that will gradually move into dedicated pipeline components as later milestones are completed.
- StatementParser still returns [Transaction]; FinancialDocumentBuilder provides the temporary compatibility bridge until Sprint 16 completes.
- Additional approved regression fixtures should be added for future institutions (CBQ, HDFC, SBI, etc.).
- Additional import fixtures should compare equivalent financial truth across CSV and PDF where available.

Remove items as they are completed.

## Reference Fixtures

The following fixtures define the approved financial baseline used throughout LedgerForge development.

### Approved Baseline

- Axis Bank NRE CSV
- Axis Bank NRE PDF (same statement period)

Both fixtures represent identical financial truth.

Future readers, parsers and import pipelines must produce equivalent observable financial results unless an intentional behavioural change is explicitly approved.

### Future Fixtures

As new institutions are supported, each approved fixture should include:

- Original source document
- Expected financial results
- Expected parser
- Validation outcome

Every supported import format should be validated against an approved baseline fixture whenever an equivalent statement exists.

## Future Modules

### Import
- XLS/XLSX Reader
- OCR

### Intelligence
- Rules Engine

### Dashboard
- Search (FTS5)
- Multi-Currency Dashboard
- Accounts Overview
- Net Worth
- Cash Flow

### Wealth
- Investments
- Insurance
- Salary Reconciliation

### Ecosystem
- Public API
- Backup & Restore
- Plugin Architecture

Mark completed items as appropriate over time.

## Context Optimisation

To minimise token consumption:

- Read Project_Guide.md first.
- Use the Task Routing Guide.
- Open only the documents required for the requested task.
- Do not reread unchanged reference documents.
- Treat sprint reports as historical unless the current task requires them.
- Prefer referencing documentation over repeating it.

This layered documentation approach keeps AI context small while preserving deterministic behaviour.

## Instructions for AI Assistants

- Read this guide first.  
- Never skip required documentation.  
- Never make changes outside the approved sprint.  
- Never continue into the next sprint unless explicitly instructed.  
- Never redesign approved architecture.  
- If documentation and implementation conflict, stop and report the conflict.  
- Maintain Project documents/Codex response.md during implementation.
- Update Project documents/PROJECT_STATE.md only after the sprint has been successfully validated, committed and pushed.
- Leave the repository in a buildable state.  
- Never bypass repository abstractions.  
- Never access SQLite directly from Views, ViewModels or Stores.  
- Never invent financial rules or statement layouts.  
- Never silently change financial behaviour.  
- If uncertain, stop and explain rather than guessing.
- Never commit if the project does not build successfully.
- Never push if required sprint tests fail.
- Verify only sprint-related files are staged before every commit.
- Verify no unresolved merge conflict markers exist before every commit.
- Generate commit messages from completed work rather than generic templates.
- Prefer document references over duplicated instructions.
- Avoid loading unrelated architecture documents.
- Treat Project_Guide.md as the repository index.
  
## Project Philosophy

LedgerForge evolves through small, fully reviewed, production-quality sprints.

Architecture is designed first.
Implementation follows architecture.
Documentation follows implementation.

Every completed sprint should leave the project in a healthier state than it was found.

Documentation should evolve only when architecture, workflow or verified repository state changes.
