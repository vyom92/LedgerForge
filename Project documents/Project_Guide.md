# LedgerForge Project Guide

This is the mandatory first document every AI assistant and engineer must read before planning or implementation because it minimizes context loading and routes the reader to the correct documentation.

## Current Project Snapshot

<<<<<<< Updated upstream
- **Current Milestone:** Milestone B
- **Current Sprint:** <Update after every sprint>
- **Current Phase:** <Update after every sprint>
- **Build Status:** <Passing / Failing>
- **Test Status:** <Summary>
- **Last Architecture Review:** <YYYY-MM-DD>
- **Current Codex Baseline:** <Sprint tag>
=======
- **Current Milestone:** Milestone C
- **Current Sprint:** Sprint 12B
- **Current Phase:** PDF Reader Foundation Complete
- **Build Status:** Passing
- **Test Status:** 17 tests passing
- **Last Architecture Review:** 2026-07-07
- **Current Codex Baseline:** Sprint 12A
>>>>>>> Stashed changes

## Current Architecture Status

Update this table at the completion of every sprint. It provides the authoritative high-level status of each subsystem.

| Component             | Status/Notes                      |
|-----------------------|---------------------------------|
<<<<<<< Updated upstream
| Product Vision        |                                 |
| Architecture         |                                 |
| ADRs                 |                                 |
| Database             |                                 |
| Repository Layer     |                                 |
| Persistence          |                                 |
| Import Framework     |                                 |
| Readers              |                                 |
| Institution Detection|                                 |
| Password Management  |                                 |
| Dashboard            |                                 |
| Investments          |                                 |
| Testing              |                                 |
| Documentation        |                                 |
| Import Pipeline      |                                 |
| Repository Contract Tests |                             |
=======
| Product Vision | Current and authoritative |
| Architecture | Frozen v1.0 baseline active |
| ADRs | Current through ADR-018 |
| Database | Production-ready foundation |
| Repository Layer | Stable with contract tests |
| Persistence | SQLite repository layer active |
| Import Framework | Operational; CSV and PDF reader foundation active |
| Readers | CSV and PDF readers integrated into Unified Import Framework |
| Testing | 17 active tests passing |
| Institution Detection | Legacy detector active; framework planned |
| Password Management | Operational; DefaultPasswordProvider integrated |
| Dashboard | Existing dashboard unchanged |
| Investments | Future module |
| Documentation | Project_Guide.md is canonical routing document |
| Import Pipeline | Production CSV routed through ImportCoordinator |
| Repository Contract Tests | Active for InMemory and SQLite providers |
>>>>>>> Stashed changes

## Architecture Map

```text
<<<<<<< Updated upstream
User
 │
 ▼
Views
 │
 ▼
=======
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
>>>>>>> Stashed changes
ViewModels
 │
 ▼
Stores
 │
 ▼
Repository Protocols
 │
 ▼
Repository Implementations
 │
 ▼
SQLite

────────────────────────────

Import Request
 │
 ▼
ImportCoordinator
 │
 ▼
Reader
 │
 ▼
FinancialDocument
 │
 ▼
Institution Detection
 │
 ▼
Document Classification
 │
 ▼
Parser Selection
 │
 ▼
Statement Parser
 │
 ▼
Validation
 │
 ▼
Repository Protocols
 │
 ▼
Repository Implementations
 │
 ▼
SQLite
 │
 ▼
Stores
```

## Documentation Index

| Document                          | Purpose                                             | Read When                          | Priority    |
|----------------------------------|-----------------------------------------------------|-----------------------------------|-------------|
| Architecture_v1.0_Frozen.md       | Definitive system design and constraints             | Architecture review, design tasks | Highest     |
| ADR.md                          | Architecture Decision Records documenting key decisions | Architecture review, design tasks | High        |
| Database_v1_Architecture.md       | Database schema and component design                  | Database changes, design tasks    | High        |
| Product Vision.md               | High-level goals, target users, and product impact    | New feature planning              | High        |
| Engineering Standards.md        | Coding standards and engineering guidelines           | All engineering tasks             | Medium      |
| AI_WORKFLOW.md                 | Workflow instructions for AI assistants                | All AI-related tasks              | Medium      |
| .github/context.md             | Project environment and constraints for AI assistants | AI onboarding and context refresh | Medium      |
| .github/ai-instructions.md     | AI behavior and interaction policies                   | AI onboarding                    | Medium      |
| .github/prompts.md             | Prompt templates and examples for AI responses         | AI onboarding                    | Medium      |
| Project documents/Codex response.md | Latest sprint summary, build/test results, decisions | Sprint reviews, bug fixes, testing | High        |

## Documentation Precedence

The precedence for documentation is as follows:

1. Architecture_v1.0_Frozen.md  
2. ADR.md  
3. Engineering Standards.md  
4. Database_v1_Architecture.md  
5. Product Vision.md  
6. AI_WORKFLOW.md  
7. Codex response.md  

Approved documentation always overrides any implicit or assumed implementation details.

## Project Principles

- Offline First
- Validation Before Persistence
- Repository-Only Persistence
- Protocol-Oriented Architecture
- Deterministic Before Intelligent
- Financial Truth Never Changes
- One Sprint Per Implementation
- Documentation Before Implementation

## Non-Negotiable Architecture Rules

- Validation always precedes persistence.
- Repository protocols are the only abstraction permitted to access persistence.
- Repository implementations are the only components permitted to communicate with SQLite.
- Views, ViewModels and Stores never access SQLite directly.
- ImportCoordinator owns orchestration only.
- Readers understand file formats.
- Parsers understand financial institutions and document families.
- Stores own runtime state.
- The dashboard observes stores rather than querying persistence.

## Task Routing Guide

| Task                  | Documents to Consult                                               |
|-----------------------|-------------------------------------------------------------------|
| New Feature           | Product Vision.md, Architecture_v1.0_Frozen.md, ADR.md            |
| Database Work         | Database_v1_Architecture.md, ADR.md, Engineering Standards.md     |
| Repository Changes    | Database_v1_Architecture.md, Project documents/Codex response.md  |
| Import Framework      | Architecture_v1.0_Frozen.md, ADR.md, Engineering Standards.md     |
| Reader Implementation | Architecture_v1.0_Frozen.md, ADR.md                               |
| Parser Implementation | Architecture_v1.0_Frozen.md, ADR.md                               |
| Institution Detection | Architecture_v1.0_Frozen.md, ADR.md                               |
| Password Handling     | Architecture_v1.0_Frozen.md, ADR.md                               |
| UI Work               | Architecture_v1.0_Frozen.md, Engineering Standards.md             |
| Testing               | Project documents/Codex response.md, Engineering Standards.md     |
| Bug Fixes             | Project documents/Codex response.md, Engineering Standards.md     |
| Documentation Updates | Project_Guide.md, Engineering Standards.md                        |
| Architecture Review   | Architecture_v1.0_Frozen.md, ADR.md                               |

## Repository Structure

- **Database:** Contains database schema definitions and migration scripts.  
- **Import:** Modules and code for import pipeline and data ingestion.  
- **Models:** Domain models and business logic entities.  
- **Stores:** Data persistence and repository layer implementations.  
- **ViewModels:** Presentation logic for UI components.  
- **Views:** UI components, screens, and layouts.  
- **Services:** Background services, helpers, and utilities.  
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
- Read only the documents required by the Task Routing Guide.  
- Review Project documents/Codex response.md.  
- Produce an implementation plan.  
- Wait for approval before coding.  

### 2. During implementation

- Work on one sprint only.  
- Do not implement future sprints.  
- Do not redesign approved architecture.  
- Build continuously.  
- Run tests where applicable.  
- Keep changes limited to the approved sprint.  
- Keep commits logically grouped.
- Prefer extending existing architecture over introducing parallel implementations.

### 3. Before stopping

- Update Project documents/Codex response.md.  
- Include summary, files created, files modified, build result, test result, documentation updated, remaining technical debt, deferred items and next recommended sprint.  
- Stop exactly at the approved sprint boundary.  
- Confirm the repository builds successfully before considering the sprint complete.

## Sprint Roadmap

<<<<<<< Updated upstream
- **Completed Sprints:**  
- **Current Sprint:**  
- **Upcoming Sprints:**  

=======
- **Completed Sprints:** Sprint 10 cleanup, Sprint 11A, Sprint 11B, Sprint 11C, Sprint 11D, Sprint 12A
- **Current Sprint:** Sprint 12B – Axis PDF Baseline Verification
- **Upcoming Sprints:**
  - Sprint 12C – Institution Detection Framework
  - Sprint 13 – ImportViewModel & Import Diagnostics
  
>>>>>>> Stashed changes
## Known Technical Debt

Maintain a concise list of active architectural and implementation debt.

Typical entries include:

<<<<<<< Updated upstream
- Repository improvements.
- Import framework work in progress.
- Deferred parser support.
- Testing gaps.
- Performance improvements.
=======
- ImportEngine still owns analysis, normalization, parser selection, validation and store updates.
- Axis PDF regression fixture still required for cross-format verification.
- Institution Detection Framework not yet implemented.
- Additional approved regression fixtures should be added for future institutions (CBQ, HDFC, SBI, etc.).
- Additional import fixtures should compare equivalent financial truth across CSV and PDF where available.
>>>>>>> Stashed changes

Remove items as they are completed.

## Future Modules

<<<<<<< Updated upstream
- Universal Import Framework
- PDF Reader
=======
- Institution Detection Framework
>>>>>>> Stashed changes
- XLS/XLSX Reader
- OCR
- Institution Detection
- Rules Engine
- Multi-Currency Dashboard
- Investments
- Insurance
- Salary Reconciliation
- Search (FTS5)
Mark completed items as appropriate over time.

## Instructions for AI Assistants

- Read this guide first.  
- Never skip required documentation.  
- Never make changes outside the approved sprint.  
- Never continue into the next sprint unless explicitly instructed.  
- Never redesign approved architecture.  
- If documentation and implementation conflict, stop and report the conflict.  
- Update Project documents/Codex response.md after every implementation.  
- Leave the repository in a buildable state.  
- Never bypass repository abstractions.  
- Never access SQLite directly from Views, ViewModels or Stores.  
- Never invent financial rules or statement layouts.  
- Never silently change financial behaviour.  
- If uncertain, stop and explain rather than guessing.

## Project Philosophy

LedgerForge evolves through small, fully reviewed, production-quality sprints.

Architecture is designed first.
Implementation follows architecture.
Documentation follows implementation.

Every completed sprint should leave the project in a healthier state than it was found.
