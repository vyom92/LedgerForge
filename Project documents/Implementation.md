# LedgerForge Implementation Workflow (v2.1)

## Purpose

This document is the single source of truth for LedgerForge sprint planning and execution.

Only the ACTIVE sprint may be read by Codex.
Archived sprints are historical record only.

---

## Rules

1. Only the ACTIVE sprint is read by Codex.
2. ChatGPT owns and maintains this document.
3. Codex never edits this document.
4. Codex updates only:
   - `Codex response.md`
   - `PROJECT_STATE.md`
5. Codex never updates planning documentation.
6. Archived sprints are read-only.
7. Replace prompts rather than appending during planning or implementation iterations.
8. Every sprint follows:
   **Planning → Review → Implementation → Documentation (Optional)**
9. When a sprint completes, ChatGPT archives it and creates the next ACTIVE sprint above it.

══════════════════════════════════════════════════════════════

# =======ACTIVE SPRINT==========

## Sprint 25 — Account Identity & Import Foundation

### Status

🟢 Ready for Implementation

### Objective

Strengthen LedgerForge's account identity architecture by improving institution attribution, account display naming, duplicate-account prevention and import foundations while preserving the repository architecture, Runtime Store architecture and durable SQLite persistence introduced in Sprint 24.

---

## Context

Sprint 24 successfully stabilised the application.

Verified outcomes include:

- Durable SQLite persistence.
- Repository hydration after application restart.
- Runtime Store synchronisation.
- Stable build.
- 84 enabled tests passing.
- Sidebar hit-target improvements.
- Credit/Debit hit-target improvements.
- Removal of duplicate macOS traffic-light controls.
- Improved import completion state.

The remaining architectural weakness is account identity.

Repository persistence is now reliable.

The next objective is to improve how accounts are represented without changing their stable repository identity.

---

## Required Files

### Project Documentation

- `Project documents/Project_Guide.md`
- `Project documents/PROJECT_STATE.md`
- `Project documents/Architecture_v1.0_Frozen.md`
- `Project documents/Database_v1_Architecture.md`
- `Project documents/Engineering Standards.md`
- `Project documents/UI_UX_v1.0_Frozen.md`
- `Project documents/Codex response.md`
- 'Services/ImportPersistenceMapper.swift'

### Backend

- `Services/ImportEngine.swift`
- `Services/ImportPersistenceCoordinator.swift`
- `Services/RepositoryStoreHydrator.swift`
- `Database/Repository.swift`
- `Database/SQLiteRepositoryProvider.swift`
- `Core/AccountStore.swift`
- `Core/TransactionStore.swift`

### Models

- Account
- Workspace
- Institution
- ImportSession
- FinancialDocument

---

## Required Reports

- Sprint 25 Planning Report
- PROJECT_STATE.md
- Sprint 24 Completion Report

---

## Constraints

### Preserve

- Repository architecture.
- Runtime Store architecture.
- SQLite persistence.
- RepositoryStoreHydrator as the only persistence-to-runtime boundary.
- Stable repository identifiers.
- Financial calculations.
- Parser behaviour.
- Existing import validation.
- Existing test suite.

### Do Not Implement

- PDF parsing.
- OCR.
- Import Wizard implementation.
- Category engine.
- Rules engine.
- Investment features.
- Database schema changes unless proven strictly necessary.

---

## Planning Review (ChatGPT)

### Status

✅ Approved

The planning report has been reviewed.

Implementation is approved with the following clarifications.

### Approved Scope

#### Phase 1 — Institution Attribution

Persist institution metadata through the existing repository path.

Target flow:

Parser

↓

ImportPersistenceMapper

↓

Repository

↓

SQLite

↓

RepositoryStoreHydrator

↓

Runtime Store

No schema redesign.

No heuristic inference.

---

#### Phase 2 — Account Display

Improve repository account display names.

Rules:

- Display names may change.
- Repository IDs must never change.
- Display names must never participate in matching.
- Preserve existing persisted account identity.

---

#### Phase 3 — Duplicate Prevention Foundation

Prepare the architecture required for future duplicate prevention.

Do not implement automatic matching.

Do not compare:

- filenames
- account names
- institution names
- display names

Future matching must rely only on verified account identifiers.

Do not introduce a concrete identity service or type during this sprint.

---

#### Phase 4 — Import Foundation

Document and prepare the future import pipeline.

Target architecture:

Reader

↓

Format Processor

↓

FinancialDocument

↓

Validation

↓

Persistence

↓

RepositoryStoreHydrator

↓

Runtime Stores

No PDF implementation.

No OCR.

---

## Implementation Prompt (Codex)

Read only the ACTIVE sprint.

Implement only the approved Sprint 25 scope.

Do not read archived sprint sections.

### Validation Requirements

Implementation is complete only when:

- Build succeeds.
- All enabled tests pass.
- Repository persistence remains unchanged.
- SQLite persistence remains unchanged.
- Restart persistence remains verified.
- Repository IDs remain stable.
- Institution attribution survives restart.
- Display names improve without affecting identity.
- No duplicate accounts are created by verified identifiers.
- No new compiler warnings appear.
- Existing CSV import behaviour remains unchanged.

### Completion

When implementation is complete:

1. Commit.
2. Push.
3. Update `Project documents/Codex response.md`.
4. Update `Project documents/PROJECT_STATE.md`.
5. Do not modify `Implementation.md`.
6. Stop at Sprint 25 scope.

---

## Documentation Sync (Optional)

Documentation-only work.

May update documentation after implementation has been approved.

Must never be combined with implementation work.

══════════════════════════════════════════════════════════════

# ********ARCHIVE****************

Completed sprints are archived by ChatGPT only.

New sprints are always inserted above this section.

Archived sprints must never be modified.

══════════════════════════════════════════════════════════════

## Sprint 24 — Persistence and UI Behaviour Stabilisation

**Status**

✅ Complete

**Completed**

2026-07-10

**Outcome**

- Durable SQLite persistence implemented.
- Repository hydration restored application state after restart.
- Runtime Store hydration stabilised.
- Sidebar rows use full-width hit targets.
- Credit/Debit filters use full rectangular hit targets.
- Duplicate in-app macOS traffic-light controls removed.
- Import completion feedback improved.
- Placeholder controls clearly distinguished.
- Repository account persistence verified.
- Restart persistence verified.
- Manual regression completed.
- Build succeeds.
- All enabled tests pass.

**Validation**

- Clean build
- All enabled unit tests passed
- CSV import verified
- Repository persistence verified
- Restart verified
- Dashboard totals verified
- Transactions verified
- Accounts verified
- Sidebar behaviour verified
- Credit/Debit filters verified

**Deferred Work**

- Account identity improvements
- Institution attribution
- PDF import pipeline
- Import Wizard implementation
- Category engine
- Rules engine
- Investment modules


## Sprint 23 — UI Component Extraction

**Status**

✅ Complete

**Completed**

2026-07-09

**Objective**

Extract the reusable SwiftUI components introduced during Sprint 22 into dedicated files while preserving behaviour, appearance and architecture.

**Related Commit(s)**

Implementation: `8090de4`

Project-state update: `a3d39c1`

Stabilisation follow-up: recorded in subsequent repository history

**Outcome**

Reusable UI primitives were extracted into `Views/Common/`.

`ContentView.swift` remained the application composition root.

The Deep Indigo design language, existing runtime-store data flow and application behaviour were preserved.

Developer Console visibility was corrected.

The UI and backend were subsequently audited, resulting in:

- transaction scrolling repair
- improved search and filter behaviour
- more honest placeholder controls
- improved dashboard runtime refresh
- safer account and balance hydration
- strengthened repository and CSV regression coverage
- restored passing build and test suite

**Validation**

- Clean build
- All enabled unit tests passed
- Repository contract tests passed
- Import integration tests passed
- CSV regression tests passed
- UI tests passed when run normally

**Deferred Work**

- Durable SQLite persistence in the live application
- Startup restoration after application relaunch
- Full-width navigation hit targets
- Removal of duplicate fake macOS traffic-light controls
- Import completion feedback
- Full Import Wizard
- Account identity improvements

══════════════════════════════════════════════════════════════

## Sprint 22 — Translate Frozen UI Assets into SwiftUI

**Status**

✅ Complete

**Completed**

2026-07-07

**Objective**

Translate the approved Deep Indigo UI assets into reusable SwiftUI presentation while preserving the existing architecture.

**Related Commit(s)**

Checkpoint: `b7013c6`

Final: `eb5e5ee`

**Outcome**

Deep Indigo application shell, dashboard, accounts, transactions, import wizard shell, settings and developer console successfully translated into SwiftUI.

══════════════════════════════════════════════════════════════

## Sprint 21 — Application Shell

**Status**

✅ Complete

**Completed**

2026-07-06

**Objective**

Implement the permanent sidebar, contextual toolbar and application shell.

**Related Commit(s)**

Final: `539e4a5`

**Outcome**

Application shell established and ready for UI translation.

══════════════════════════════════════════════════════════════

## Sprint 20 — Documentation & Repository Foundation

**Status**

✅ Complete

**Completed**

2026-07-05

**Objective**

Stabilise project documentation, repository structure and engineering workflow.

**Related Commit(s)**

N/A

**Outcome**

Repository conventions established and documentation reorganised in preparation for UI implementation.
