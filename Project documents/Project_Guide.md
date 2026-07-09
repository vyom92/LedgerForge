# LedgerForge Project Guide

This is the canonical project operating manual. Read this document first, then use the Task Routing Guide to load only the documents required for the current task. Avoid loading unnecessary documentation.

## Current Project Snapshot

- **Workflow:** Workflow v2.1 (Frozen)
- **Current Milestone:** M7 – Dashboard Experience
- **Current Sprint:** Workflow v2.1 documentation audit and repository housekeeping
- **Current Phase:** Workflow v2.1 Freeze
- **Build Status:** Passing
- **Validation Status:** Build passing; full active validation passing. Sprint 22 validation complete.
- **Last Architecture Review:** 2026-07-08
- **Current Development Baseline:** Sprint 22 (UI Foundation)

## Current Architecture Status

| Component | Status/Notes |
|-----------|--------------|
| Product Vision | Current and authoritative |
| Architecture | Frozen v1.0 baseline active |
| ADRs | Current through ADR-023 |
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
| Workflow | Workflow v2.1 active. `Project documents/Implementation.md` is the canonical sprint planning document. |
| Dashboard | Approved Deep Indigo UI translated into SwiftUI foundation screens. Reusable presentation components established. |
| Validation | Build passing; full active validation passing. Sprint 22 validation complete |
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
Runtime Stores
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

| Project documents/Implementation.md | Active sprint planning and workflow | Every implementation session | Highest |

| Database_v1_Architecture.md       | Database schema and component design                  | Database changes, design tasks    | High        |
| Product Vision.md               | High-level goals, target users, and product impact    | New feature planning              | High        |
| Engineering Standards.md        | Coding standards and engineering guidelines           | All engineering tasks             | Medium      |
| AI_WORKFLOW.md                 | Workflow instructions for AI assistants                | All AI-related tasks              | Medium      |
| Project documents/.github/Project_Context.md      | AI bootstrap context and current project state summary | AI onboarding | Medium |
| Project documents/.github/ai-instructions.md     | AI behavior and interaction policies                   | AI onboarding                    | Medium      |
| Project documents/.github/prompts.md             | Prompt templates and examples for AI responses         | AI onboarding                    | Medium      |
| Project documents/Codex response.md | Project documents/Codex response.md | Latest Codex planning or execution output | Planning review and implementation review | High |

Only consult the documents required by the Task Routing Guide. Do not load the complete documentation set unless performing a full architecture or repository review.

## Documentation Precedence

The precedence for documentation is as follows:

1. Architecture_v1.0_Frozen.md
2. ADR.md
3. Project documents/PROJECT_STATE.md
4. Project documents/Implementation.md
5. Engineering Standards.md
6. Database_v1_Architecture.md
7. Product Vision.md
8. AI_WORKFLOW.md
9. Project documents/Codex response.md

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
- Statement Classification identifies the document family.
- Parser Selection chooses the appropriate parser.
- Statement Parsers produce FinancialDocument.
- FinancialDocument is validated before persistence.
- Runtime Stores own observable application state.
- The dashboard observes stores rather than querying persistence.
- Repository-backed startup hydration executes once per application launch unless an explicit user refresh is requested.

## Task Routing Guide

| Task                  | Documents to Consult                                               |
|-----------------------|-------------------------------------------------------------------|
| New Feature           | Product Vision.md, Architecture_v1.0_Frozen.md, ADR.md            |
| Database Work         | Database_v1_Architecture.md, ADR.md, Engineering Standards.md     |
| Repository Changes    | PROJECT_STATE, Implementation.md, Codex response  |
| Import Framework      | Architecture_v1.0_Frozen.md, ADR.md, Engineering Standards.md     |
| Reader Implementation | Architecture_v1.0_Frozen.md, ADR.md                               |
| Parser Implementation | Architecture_v1.0_Frozen.md, ADR.md                               |
| Institution Detection | Architecture_v1.0_Frozen.md, ADR.md                               |
| Password Handling     | Architecture_v1.0_Frozen.md, ADR.md                               |
| PDF Reader | Architecture_v1.0_Frozen.md, ADR.md, Engineering Standards.md |
| Reference Fixtures | Project documents/PROJECT_STATE.md, Project documents/Codex response.md |
| UI Work               | UI_UX_v1.0_Frozen.md, Architecture_v1.0_Frozen.md, Engineering Standards.md |
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
- **Project documents/.github:** Canonical AI instructions, prompts, and context. Root-level `.github` documentation files were intentionally moved here.  
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

If future work is discovered, create a proposed future sprint inside `Project documents/Implementation.md`. Do not implement it.

Additionally:

- Verify the target file before editing.
- Add new files to the correct Xcode target.
- Add new files to the Xcode navigator.
- Preserve existing behaviour unless the sprint explicitly changes it.
- Preserve the approved presentation pipeline:
  Repository Persistence → RepositoryStoreHydrator → Runtime Stores → ViewModels → Views.
- If an architectural conflict is discovered, stop implementation and document it in Project documents/Codex response.md.

## Standard AI Workflow

### Phase 1 — Planning

- Read Project_Guide.md first.
- Use the Task Routing Guide.
- Review `Project documents/PROJECT_STATE.md`.
- Read only the ACTIVE sprint in `Project documents/Implementation.md`.
- Execute the Planning Prompt.
- Output findings only to `Project documents/Codex response.md`.
- Do not modify source code.

### Phase 2 — Review

- ChatGPT reviews `Codex response.md`.
- ChatGPT updates the ACTIVE sprint in `Implementation.md`.
- Replace the Planning Prompt with the approved Implementation Prompt.

### Phase 3 — Implementation

- Read only the ACTIVE sprint.
- Implement only the approved scope.
- Build continuously.
- Execute required validation.
- Verify only sprint-related files are staged.
- Commit.
- Push.
- Update `Project documents/Codex response.md`.
- Update `Project documents/PROJECT_STATE.md`.

### Phase 4 — Completion

- Confirm build passes.
- Confirm validation passes.
- Confirm push completed.
- ChatGPT archives the completed sprint in `Implementation.md`.
- ChatGPT creates the next ACTIVE sprint.

## Sprint Roadmap

The ACTIVE sprint is the only sprint read by Codex.

Development is managed exclusively through `Project documents/Implementation.md`.

Only one ACTIVE sprint exists at any time.

Completed sprints are archived inside the same document.

Future sprint planning is created only after the current sprint completes.

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

### M4 – FinancialDocument-native Parsing ✅
- StatementParser returns FinancialDocument
- Immutable parser output
- Zero behavioural change

### M5 – Validation Pipeline Refinement ✅
- Dedicated ImportValidator tests
- Stable FinancialDocument validation boundary
- Regression protection for validation behaviour

### M6 – Repository & Data Platform ✅
- Unified persistence
- Deduplication
- Audit trail

### M7 – Dashboard Experience 🚧
- Repository-backed startup hydration ✅
- Accounts overview ✅
- Recent transaction summaries ✅
- Application Shell ✅
- Sidebar navigation ✅
- Approved UI asset freeze ✅
- Dashboard implementation from frozen UI ✅
- Import workflow integration ⏳

### M8 – Insights & Analytics
- Spending analytics
- Budgets
- Smart alerts

### M9 – Financial Ecosystem
- Multi-currency
- Investments
- Public API
- Plugin architecture

## Known Technical Debt

Maintain a concise list of active architectural and implementation debt.

Current items:

- ImportEngine still owns orchestration responsibilities that will gradually move into dedicated pipeline components as later milestones are completed.
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
- Insights
- Charts & Analytics
- Budgets
- Advanced Transaction Browsing
- Multi-Currency Dashboard
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
- Read only the ACTIVE sprint in `Implementation.md`. Archived sprints are historical reference only.
- Prefer referencing documentation over repeating it.

This layered documentation approach keeps AI context small while preserving deterministic behaviour.

## Instructions for AI Assistants

- Read this guide first.  
- Never skip required documentation.  
- Never make changes outside the approved sprint.  
- Never continue into the next sprint unless explicitly instructed.  
- Never redesign approved architecture.  
- If documentation and implementation conflict,stop and report the conflict.  
- Maintain `Project documents/Codex response.md` during planning and implementation.
- Update `Project documents/PROJECT_STATE.md` after successful validation and push.
- Never modify archived sprint sections in `Project documents/Implementation.md`.
- Read only the ACTIVE sprint in `Project documents/Implementation.md`.
- Leave the repository in a buildable state.  
- Never bypass repository abstractions.  
- Never access SQLite directly from Views, ViewModels or Stores.  
- Never invent financial rules or statement layouts.  
- Never silently change financial behaviour.  
- If uncertain, stop and explain rather than guessing.
- Never commit if the project does not build successfully.
- Never push if required sprint validation fails.
- Verify only sprint-related files are staged before every commit.
- Verify no unresolved merge conflict markers exist before every commit.
- Generate commit messages from completed work rather than generic templates.
- Prefer document references over duplicated instructions.
- Avoid loading unrelated architecture documents.
- Treat Project_Guide.md as the repository index.
  
## Project Philosophy

LedgerForge evolves through small, fully reviewed, production-quality sprints.

Architecture guides implementation.
Implementation validates architecture.
Documentation records the verified repository state.

Every completed sprint should leave the project in a healthier state than it was found.

Documentation should evolve only when architecture, workflow or verified repository state changes.
