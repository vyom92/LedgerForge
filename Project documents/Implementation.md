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

## Sprint 23 — UI Component Extraction

### Status

        🟢 Ready for Implementation

### Objective

Extract the reusable SwiftUI components introduced during Sprint 22 into dedicated files while preserving all behaviour, appearance and architecture.

### Context

#### Required Files

- Project documents/Project_Guide.md
- Project documents/PROJECT_STATE.md
- Project documents/Architecture_v1.0_Frozen.md
- Project documents/Engineering Standards.md
- Project documents/UI_UX_v1.0_Frozen.md
- ContentView.swift
- Views/TransactionListView.swift
- Views/DeveloperConsoleView.swift

#### Required Assets

- Project documents/UI Assets/Approved/DesignBoard_v2.0.png
- Project documents/UI Assets/Approved/ComponentLibrary_v1.0.png
- Project documents/UI Assets/Approved/Dashboard_v1.0.png
- Project documents/UI Assets/Approved/Transactions_v1.0.png
- Project documents/UI Assets/Approved/DeveloperConsole_v1.0.png

#### Required Reports (Optional)

- Project documents/Codex response.md (Sprint 23 Planning Report)

#### Constraints

- Presentation refactor only.
- Preserve approved UI/UX.
- Preserve import pipeline.
- Preserve repository architecture.
- Preserve Runtime Store architecture.
- Preserve ViewModel contracts.
- Preserve financial behaviour.
- Build and regression validation required.
- ContentView remains the application composition root.
- Extract only reusable or clearly reusable presentation components.
- Do not extract one-off views purely to reduce file size.

#### Previous Sprint References (Optional)

- Sprint 22 — Translate Frozen UI Assets into SwiftUI


---

## Planning Review (ChatGPT)

### Review Summary

Planning approved with the following implementation decisions:

- Extract only reusable or clearly reusable presentation components.
- ContentView remains the application composition root.
- Prefer `Views/Common/` over `Views/Components/`.
- Do not create shared components where duplication is not yet justified.
- Do not introduce shared formatting APIs unless formatting already exists in multiple files.
- Minor usability fixes are permitted only where they are local presentation fixes.

### Approved Optional Fixes

- Fix Developer Console visibility default if confirmed.
- Fix TransactionList scrolling regression if encountered during extraction.

### Implementation Decision

Planning approved.

Planning complete.

Implementation approved.

---

## Implementation Prompt (Codex)

Read only the ACTIVE sprint.

This is an implementation task.

Execute only the approved scope.

---

## Objective

Extract reusable SwiftUI presentation components from the Sprint 22 implementation while preserving behaviour, appearance, architecture and existing data flow.

---

## Read Only

- Project documents/Project_Guide.md
- Project documents/PROJECT_STATE.md
- ACTIVE Sprint 23 in Project documents/Implementation.md
- Project documents/Architecture_v1.0_Frozen.md
- Project documents/Engineering Standards.md
- Project documents/UI_UX_v1.0_Frozen.md
- Project documents/Codex response.md (Sprint 23 Planning Report)

---

## Approved Scope

Extract only reusable or clearly reusable presentation components.

ContentView remains the application composition root.

Do not extract one-off views simply to reduce file size.

Prefer reusable components under:

Views/Common/

Review the planning report for the approved extraction order.

---

## Permitted Minor Fixes

If encountered naturally during extraction:

- Fix Developer Console default visibility.
- Fix TransactionList scrolling regression.

Do not introduce new functionality.

---

## Do Not Modify

- Import pipeline
- Repository layer
- Database
- Validation
- Financial calculations
- Parser behaviour
- Runtime Stores
- ViewModels
- Approved UI design
- Navigation flow

---

## Validation

- Build successfully.
- Run required sprint validation.
- Run regression tests.
- Verify dashboard hydration.
- Verify transaction search/filter behaviour.
- Verify CSV import behaviour.
- Verify Developer Console behaviour.

---

## Completion

- Commit.
- Push.
- Update Project documents/Codex response.md.
- Update Project documents/PROJECT_STATE.md.

Do not modify Implementation.md.

Stop exactly at the approved sprint boundary.

---

## Documentation Sync (Optional)

Documentation-only work.

May update documentation files.

Must not modify source code.

Must not be combined with implementation work in the same execution unless explicitly approved.

Update only the documentation explicitly listed in this sprint.

══════════════════════════════════════════════════════════════

# ARCHIVE

Completed sprints are archived by ChatGPT only.

New sprints are always inserted above this section.

Archived sprints must never be modified.

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
