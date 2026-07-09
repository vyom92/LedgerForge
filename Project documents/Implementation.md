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

🟡 Planning

### Objective

Extract the reusable SwiftUI components introduced during Sprint 22 into dedicated files while preserving all behaviour, appearance and architecture.

### Context

#### Required Files

List only the project documents, source files or reports required for this sprint.

#### Required Assets

List only the approved UI assets or branding assets required for implementation.

#### Required Reports (Optional)

List previous implementation reports or `Codex response.md` only when they are genuinely required.

#### Constraints

List architectural, engineering or sprint boundaries that must not be violated.

#### Previous Sprint References (Optional)

Reference completed sprints only when they are directly relevant to the current work.

---

## Planning Prompt (Codex)

Analyse the repository and produce an implementation plan only.

- Repository analysis only.
- No source changes.
- No documentation changes.
- No commits.
- No implementation.
- Read only the ACTIVE sprint.
- Ignore archived sprint sections.

Output findings to `Codex response.md`.

---

## Planning Review (ChatGPT)

Review Codex findings.

Refine scope.

Approve implementation approach.

Record any planning decisions required before implementation.

Replace the Planning Prompt with the approved Implementation Prompt after review.

---

## Implementation Prompt (Codex)

Read only the ACTIVE sprint.

Implement only the approved scope.

Build.

Test.

Commit.

Push.

Update `Codex response.md`.

Update `PROJECT_STATE.md`.

Do not modify archived sprint sections.

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
