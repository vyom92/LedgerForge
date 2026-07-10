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

# ACTIVE SPRINT

## Sprint 24 — Persistence and UI Behaviour Stabilisation

### Status

🟢 Ready for Implementation

### Objective

Stabilise LedgerForge after the Sprint 23 UI extraction by resolving verified persistence and user-interface behaviour defects without introducing unrelated functionality.

### Context

#### Required Files

- `Project documents/Project_Guide.md`
- `Project documents/PROJECT_STATE.md`
- `Project documents/Architecture_v1.0_Frozen.md`
- `Project documents/Database_v1_Architecture.md`
- `Project documents/Engineering Standards.md`
- `Project documents/UI_UX_v1.0_Frozen.md`
- `Project documents/Codex response.md`
- `LedgerForgeApp.swift`
- `ContentView.swift`
- `Views/TransactionListView.swift`
- `Views/Common/LFTheme.swift`
- `Services/ImportEngine.swift`
- `Services/ImportPersistenceCoordinator.swift`
- `Services/RepositoryStoreHydrator.swift`
- `Database/Repository.swift`
- `Database/SQLiteRepositoryProvider.swift`
- `Core/TransactionStore.swift`
- `Core/AccountStore.swift`
- `ViewModels/DashboardViewModel.swift`
- `ViewModels/TransactionListViewModel.swift`

#### Required Assets

- `Project documents/UI Assets/Approved/DesignBoard_v2.0.png`
- `Project documents/UI Assets/Approved/ComponentLibrary_v1.0.png`
- `Project documents/UI Assets/Approved/Dashboard_v1.0.png`
- `Project documents/UI Assets/Approved/Transactions_v1.0.png`
- `Project documents/UI Assets/Approved/ImportWizard_v1.0.png`
- `Project documents/UI Assets/Approved/Settings_v1.0.png`

#### Required Reports

- `Project documents/Codex response.md`
- Sprint 23 implementation report and validation result
- Current manual UI/UX audit findings

#### Constraints

- Behaviour stabilisation only.
- No new product modules.
- No PDF implementation.
- No OCR implementation.
- No full Import Wizard implementation.
- Preserve repository architecture.
- Preserve Runtime Store architecture.
- Preserve financial calculations.
- Preserve parser behaviour.
- Preserve import validation logic.
- Preserve the approved visual design.
- Preserve existing ViewModel contracts unless a verified defect requires a narrow correction.
- Do not redesign the navigation architecture.
- Do not modify the database schema unless planning proves it is strictly required for persistence.
- All implemented fixes must receive regression coverage where practical.
- Prefer the smallest complete fix over broad refactoring.

#### Previous Sprint References

- Sprint 23 — UI Component Extraction
- Sprint 22 — Translate Frozen UI Assets into SwiftUI

---


## Planning Review (ChatGPT)

### Status

✅ Planning Approved

### Review Outcome

The Sprint 24 planning report has been reviewed and approved.

The proposed implementation sequence correctly prioritises:

1. Production persistence bootstrap.
2. Startup hydration.
3. Persistence regression validation.
4. Sidebar hit-target corrections.
5. Credit/Debit hit-target corrections.
6. Removal of duplicate fake macOS traffic-light controls.
7. Import completion feedback.
8. Placeholder-control honesty.
9. Account display naming improvements.

### Mandatory Clarifications

Implementation must additionally observe the following:

#### Persistence

- Do **not** assume a `DatabaseProvider(sqlite:)` initializer exists.
- Determine the supported production bootstrap API.
- If the architecture lacks a production bootstrap, introduce the smallest supported factory or initializer necessary.
- Preserve the existing in-memory provider for unit and integration tests.

#### Account Naming

- Improve **display names only**.
- Never modify repository identifiers.
- Never change stable account identity.
- Never introduce automatic account matching.

#### Import Completion

Implement only:

- Success state
- Failure state
- Imported filename
- Imported transaction count
- View Transactions action

Do **not** implement:

- Preview
- Validation UI
- Remaining Import Wizard stages

#### Placeholder Controls

Differentiate between:

- Functional controls (remain enabled)
- Future functionality (clearly disabled or labelled pending)

Do not disable working controls.

#### Sidebar Validation

Implementation must manually verify:

- Full-width hover state
- Full-width click target
- Selected state
- Keyboard focus
- Accessibility focus

#### Repository Architecture

RepositoryStoreHydrator remains the **only** persistence-to-runtime boundary.

Do not bypass it.

---

## Implementation Prompt (Codex)

Read only the ACTIVE sprint.

This is an implementation task.

Update only the files required to complete the approved Sprint 24 scope.

### Approved Scope

#### Phase 1 — Critical Backend

1. Resolve production persistence across application restart.
2. Restore runtime state from persistent storage during application launch.
3. Preserve the existing repository architecture.
4. Preserve in-memory repositories for testing.
5. Add regression coverage for persistence and restart behaviour.

#### Phase 2 — Critical UI Behaviour

6. Make sidebar navigation rows fully clickable.
7. Make Credit/Debit controls use full rectangular hit targets.
8. Remove duplicate fake macOS traffic-light controls.

#### Phase 3 — UX Polish

9. Improve import completion feedback.
10. Clearly distinguish placeholder controls from functional controls.
11. Improve account display naming without changing account identity.

### Do Not Modify

- Parser architecture
- Statement parsing behaviour
- Financial calculations
- Import validation logic
- Approved UI styling
- Navigation architecture
- PDF import
- OCR
- Category analytics
- Investment modules
- Database schema unless strictly required

### Validation

Implementation is complete only when:

- Build succeeds.
- All enabled tests pass.
- CSV import verified.
- Dashboard totals verified.
- Transaction search verified.
- Credit/Debit filters verified.
- Sidebar hit targets verified.
- Import completion verified.
- Application restart preserves imported data.

### Completion

When implementation is complete:

1. Commit changes.
2. Push to the current branch.
3. Update `Project documents/Codex response.md`.
4. Update `Project documents/PROJECT_STATE.md`.
5. Do **not** modify `Implementation.md`.
6. Stop after Sprint 24 scope.

---

## Documentation Sync (Optional)

Documentation-only work.

May update documentation files only when explicitly approved after implementation.

Must not modify source code.

Must not be combined with implementation work in the same execution unless explicitly approved.

══════════════════════════════════════════════════════════════

# ARCHIVE

Completed sprints are archived by ChatGPT only.

New sprints are always inserted above this section.

Archived sprints must never be modified.

══════════════════════════════════════════════════════════════

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
