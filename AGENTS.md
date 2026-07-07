# LedgerForge Agent Bootstrap

This file is intentionally minimal to reduce context usage for autonomous coding agents.

## Mandatory Entry Point

Before performing any planning, review, implementation or refactoring:

1. Read `Project documents/Project_Guide.md`.
2. Follow the **Task Routing Guide** to determine which additional documents are required.
3. Read **only** the documents required for the requested task.
4. Read `Project documents/Codex response.md` for the current sprint baseline.

## Operating Rules

- Work on one approved sprint only.
- Stop exactly at the approved sprint boundary.
- Do not load unnecessary documentation.
- Do not redesign approved architecture.
- Preserve existing user-visible behaviour unless explicitly requested.
- Prefer extending existing architecture over creating parallel implementations.
- Never bypass repository abstractions.
- Never access SQLite directly from Views, ViewModels or Stores.
- Add new source files to the Xcode navigator and correct target membership.
- Update `Project documents/Codex response.md` after implementation.
- Update `Project documents/Project_Guide.md` if project status changes.

`Project_Guide.md` is the single source of truth for project workflow, architecture routing, documentation precedence and sprint execution. Avoid duplicating those rules here.
