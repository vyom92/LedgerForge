# LedgerForge Project Guide

This is the canonical project operating manual. Read this document first, then use the Task Routing Guide to determine which additional documents are required for the current task. Avoid loading unnecessary documentation.

## Current Project Snapshot

- **Current Milestone:** Milestone B
- **Current Sprint:** Sprint 11C Ready
- **Current Phase:** Post Sprint 11B Architecture Audit
- **Build Status:** Passing
- **Test Status:** 12 tests passed
- **Last Architecture Review:** 2026-07-07
- **Current Codex Baseline:** Sprint 11B

## Current Architecture Status

Update this table at the completion of every sprint. It provides the authoritative high-level status of each subsystem.

| Component             | Status/Notes                      |
|-----------------------|---------------------------------|
| Product Vision        | Current and authoritative |
| Architecture         | Frozen v1.0 baseline active |
| ADRs                 | Current through ADR-017 |
| Database             | Production-ready foundation |
| Repository Layer     | Stable with contract tests |
| Persistence          | SQLite repository layer active |
| Import Framework     | Sprint 11B foundation complete |
| Readers              | Legacy CSV reader active; unified readers deferred |
| Institution Detection| Legacy detector active; framework implementation deferred |
| Password Management  | Protocol foundation only |
| Dashboard            | Existing dashboard unchanged |
| Investments          | Future module |
| Testing              | 12 active tests passing |
| Documentation        | Project_Guide.md is canonical routing document |
| Import Pipeline      | Existing CSV flow active; Sprint 11C migration pending |
| Repository Contract Tests | Active for InMemory and SQLite providers |

## Architecture Map

```text
User
 │
 ▼
Views
 │
 ▼
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

Only consult the documents required by the Task Routing Guide. Do not load the complete documentation set unless performing a full architecture or repository review.

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

Project_Guide.md is the navigation document. It routes readers to the authoritative source rather than duplicating detailed guidance.

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
- Use the Task Routing Guide before opening any other document.
- Read only the minimum documentation required for the requested task.
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

- **Completed Sprints:** Sprint 10 cleanup, Sprint 11A, Sprint 11B
- **Current Sprint:** Sprint 11C Ready
- **Upcoming Sprints:** Sprint 11C, then follow-up import framework integration work

## Known Technical Debt

Maintain a concise list of active architectural and implementation debt.

Typical entries include:

- Repository improvements.
- Import framework work in progress.
- Deferred parser support.
- Testing gaps.
- Performance improvements.

Remove items as they are completed.

## Future Modules

- Universal Import Framework
- PDF Reader
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
- Update Project documents/Codex response.md after every implementation.  
- Leave the repository in a buildable state.  
- Never bypass repository abstractions.  
- Never access SQLite directly from Views, ViewModels or Stores.  
- Never invent financial rules or statement layouts.  
- Never silently change financial behaviour.  
- If uncertain, stop and explain rather than guessing.

- Prefer document references over duplicated instructions.
- Avoid loading unrelated architecture documents.
- Treat Project_Guide.md as the repository index.

## Project Philosophy

LedgerForge evolves through small, fully reviewed, production-quality sprints.

Architecture is designed first.
Implementation follows architecture.
Documentation follows implementation.

Every completed sprint should leave the project in a healthier state than it was found.
