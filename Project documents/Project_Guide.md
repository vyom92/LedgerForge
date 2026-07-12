# LedgerForge Project Guide

This is the canonical project operating manual. Read `Project documents/.github/Context_Manifest.yaml` first, then `AGENTS.md`, then this document. Use the Task Routing Guide to load only the documents required for the current task. Avoid loading unnecessary documentation.

## Current Project Snapshot

This document intentionally avoids duplicating volatile repository state.

The authoritative sources are:

- **Current ACTIVE Sprint:** `Project documents/Implementation.md`
- **Verified Repository State:** `Project documents/PROJECT_STATE.md`
- **Latest Implementation Report:** `Project documents/Codex response.md`

Project Baseline:

- **Workflow:** Workflow v2.1 (Frozen)
- **Architecture:** Architecture v1.0 (Frozen)
- **Development Model:** Documentation → Planning → Implementation → Validation → Handoff

## Current Architecture Status

| Component | Status/Notes |
|-----------|--------------|
| Product Vision | Current and authoritative |
| Architecture | Frozen v1.0 baseline active |
| ADRs | Current through ADR-025 |
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
| Dashboard | Deep Indigo UI foundation implemented. Repository-backed dashboard active. Continued refinement under M7. |
| Validation | Build passing. Sprint 25 validation complete. |
| Documentation | `Project documents/.github/Context_Manifest.yaml` and `Project documents/Project_Guide.md` provide the canonical bootstrap and routing. |
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
RepositoryStoreHydrator
↓
Runtime Stores
↓
ViewModels
↓
Views
```


## Documentation Index

| Document | Purpose | Read When | Priority |
|----------|---------|-----------|----------|
| Project documents/.github/Context_Manifest.yaml | Machine-readable bootstrap manifest defining document precedence, assistant responsibilities and workflow entrypoint | Every AI session | Highest |
| Project documents/Project_Guide.md | Repository navigation guide and task routing | Every AI session | Highest |
| Project documents/PROJECT_STATE.md | Verified repository state and implementation history | Every implementation session | Highest |
| Project documents/Implementation.md | ACTIVE sprint planning document | Every planning and implementation session | Highest |
| Architecture_v1.0_Frozen.md | Definitive system architecture and constraints | Architecture work | High |
| ADR.md | Architecture Decision Records | Architecture work | High |
| Database_v1_Architecture.md | Database architecture and schema | Database work | High |
| Product Vision.md | Product direction and long-term goals | Feature planning | High |
| Engineering Standards.md | Coding standards and engineering policy | Engineering tasks | Medium |
| AI_WORKFLOW.md | Operational workflow for AI assistants | AI-assisted work | Medium |
| Project documents/.github/Project_Context.md | Bootstrap summary and project snapshot | AI onboarding | Medium |
| Project documents/.github/ai-instructions.md | AI interaction rules | AI onboarding | Medium |
| Project documents/.github/prompts.md | Reusable planning and implementation prompts | AI onboarding | Medium |
| Project documents/Codex response.md | Current planning and implementation execution log | Planning and implementation review | Medium |

Only consult the documents required by the Task Routing Guide. Avoid loading the complete documentation set unless performing a full architecture or repository review.

## Documentation Precedence

The precedence for documentation is as follows:

1. Project documents/.github/Context_Manifest.yaml
2. AGENTS.md
3. Project documents/Project_Guide.md
4. Architecture_v1.0_Frozen.md
5. ADR.md
6. Project documents/PROJECT_STATE.md
7. Project documents/Implementation.md
8. Engineering Standards.md
9. Database_v1_Architecture.md
10. Product Vision.md
11. AI_WORKFLOW.md
12. Project documents/Codex response.md

Approved documentation always overrides any implicit or assumed implementation details.

`Project documents/Project_Guide.md` is the navigation document. It routes readers to the authoritative source rather than duplicating detailed guidance.

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

| Task | Documents to Consult |
|------|----------------------|
| New Feature | Product Vision.md, Architecture_v1.0_Frozen.md, ADR.md |
| Architecture Review | Architecture_v1.0_Frozen.md, ADR.md |
| Database Work | Database_v1_Architecture.md, ADR.md, Engineering Standards.md |
| Repository Changes | Project documents/PROJECT_STATE.md, Project documents/Implementation.md, Project documents/Codex response.md |
| Import Framework | Architecture_v1.0_Frozen.md, ADR.md, Engineering Standards.md |
| Reader Implementation | Architecture_v1.0_Frozen.md, ADR.md |
| Parser Implementation | Architecture_v1.0_Frozen.md, ADR.md |
| Institution Detection | Architecture_v1.0_Frozen.md, ADR.md |
| Statement Classification | Architecture_v1.0_Frozen.md, ADR.md |
| Password Handling | Architecture_v1.0_Frozen.md, ADR.md |
| PDF Reader | Architecture_v1.0_Frozen.md, ADR.md, Engineering Standards.md |
| UI Work | UI_UX_v1.0_Frozen.md, Architecture_v1.0_Frozen.md, Engineering Standards.md |
| Testing | Project documents/PROJECT_STATE.md, Project documents/Codex response.md, Engineering Standards.md |
| Bug Fixes | Project documents/PROJECT_STATE.md, Project documents/Codex response.md, Engineering Standards.md |
| Documentation Updates | Project documents/Project_Guide.md, AI_WORKFLOW.md, Engineering Standards.md |
| Reference Fixtures | Project documents/PROJECT_STATE.md, Project documents/Codex response.md |


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
- **Project documents/.github:** Canonical bootstrap, AI instructions and prompts.  
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

- Read `Project documents/.github/Context_Manifest.yaml` first.
- Read `AGENTS.md`.
- Then read `Project documents/Project_Guide.md`.
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

- Read only the ACTIVE sprint in `Project documents/Implementation.md`.
- Implement only the approved sprint scope.
- Preserve approved architecture and existing behaviour unless the sprint explicitly changes it.
- Build continuously during implementation.
- Run Xcode diagnostics.
- Run Xcode BuildProject.
- Run Xcode-native `RunAllTests`.
- Stop before commit if automated validation fails.
- Stop before commit if required manual runtime verification has not yet been completed.
- Verify only sprint-related files are modified.
- Verify `Project documents/Implementation.md` remains unchanged.
- Verify no unresolved merge conflict markers remain.
- Create the implementation commit.
- Push to `origin/main`.
- Verify the remote branch directly.
- Update `Project documents/Codex response.md` with verified implementation facts.
- Update `Project documents/PROJECT_STATE.md` only after successful validation, verified push and required manual runtime verification.

### Phase 4 — Completion

Completion is permitted only after all required validation has succeeded.

Required completion sequence:

1. Confirm Xcode diagnostics pass.
2. Confirm Xcode build passes.
3. Confirm Xcode-native RunAllTests passes.
4. Complete required manual runtime verification.
5. Verify only sprint-related files are staged.
6. Verify `Project documents/Implementation.md` remains unchanged.
7. Verify no unresolved merge conflict markers remain.
8. Create the implementation commit.
9. Push to `origin/main`.
10. Verify the remote branch using `git ls-remote origin refs/heads/main`.
11. Update `Project documents/Codex response.md` with verified implementation, validation, commit, push and remote verification facts.
12. Update `Project documents/PROJECT_STATE.md` with verified repository state only.
13. Create and push a documentation handoff commit when required.
14. Desktop ChatGPT reviews the completed sprint.
15. If approved, Desktop ChatGPT records the completed sprint in `PROJECT_STATE.md` and prepares the next ACTIVE sprint in `Project documents/Implementation.md`.

Never claim a sprint is complete until both automated validation and required manual runtime verification have been successfully performed.

## Sprint Roadmap

Development is managed exclusively through `Project documents/Implementation.md`.

Rules:

- Only one ACTIVE sprint exists at any time.
- Codex reads only the ACTIVE sprint.
- Desktop ChatGPT owns sprint planning.
- Desktop ChatGPT owns sprint approval.
- Desktop ChatGPT prepares the next ACTIVE sprint only after the current sprint has been successfully completed and approved.

Completed sprint history is maintained in:

`Project documents/PROJECT_STATE.md`

`Project documents/Implementation.md` is not a historical archive.

Future sprint planning begins only after the current sprint has completed.

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

### Context Optimisation

To minimise token consumption:

- Read `Project documents/.github/Context_Manifest.yaml` first.
- Read `AGENTS.md`.
- Then read `Project documents/Project_Guide.md`.
- Use the Task Routing Guide.
- Open only the documentation required for the requested task.
- Do not reread unchanged reference documents.
- Read only the ACTIVE sprint in `Project documents/Implementation.md`.
- Use `Project documents/PROJECT_STATE.md` for completed sprint history.
- Prefer referencing documentation over repeating it.

This layered bootstrap minimizes context loading while preserving deterministic behaviour.

## Instructions for AI Assistants

- Bootstrap through `Project documents/.github/Context_Manifest.yaml`.
- Read `AGENTS.md`.
- Then read `Project documents/Project_Guide.md`.
- Load only the documentation required by the Task Routing Guide.
- Read only the ACTIVE sprint in `Project documents/Implementation.md`.
- Treat `Project documents/PROJECT_STATE.md` as the authoritative completed sprint history.
- Never modify `Project documents/Implementation.md` unless acting under the Desktop ChatGPT planning workflow.
- Never make changes outside the approved ACTIVE sprint.
- Never redesign approved architecture without an approved ADR.
- Maintain `Project documents/Codex response.md` during planning and implementation.
- Update `Project documents/PROJECT_STATE.md` only after successful validation, required manual runtime verification, verified implementation commit and verified push.
- Leave the repository in a buildable state.
- Never bypass repository abstractions.
- Never access SQLite directly from Views, ViewModels or Runtime Stores.
- Never invent financial rules or statement layouts.
- Never silently change financial behaviour.
- Never commit if the project does not build successfully.
- Never push if required validation fails.
- Verify only sprint-related files are staged before committing.
- Verify no unresolved merge conflict markers exist before committing.
- Generate commit messages from completed work.
- Prefer document references over duplicated instructions.
- Avoid loading unrelated documentation.
- Treat `Project documents/Project_Guide.md` as the repository navigation index.
- If documentation and implementation conflict, stop and report the conflict instead of guessing.
  
## Project Philosophy

LedgerForge evolves through small, fully reviewed, production-quality sprints.

Architecture guides implementation.
Implementation validates architecture.
Documentation records the verified repository state.

Every completed sprint should leave the project in a healthier state than it was found.

Documentation should evolve only when approved architecture, workflow or verified repository state changes.
