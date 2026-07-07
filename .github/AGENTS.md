# LedgerForge Agent Bootstrap

This file is intentionally minimal to reduce context usage for autonomous coding agents.

## Mandatory Entry Point

Before performing any planning, review, implementation or refactoring:

1. Read `Project documents/Project_Guide.md`.
2. Follow the **Task Routing Guide** to determine which additional documents are required.
3. Read **only** the documents required for the requested task.
4. Read `Project documents/PROJECT_STATE.md` to establish the verified repository state.
5. Read `Project documents/Codex response.md` only for the current sprint context.

## Operating Rules

- Work on one approved sprint only.
- Stop exactly at the approved sprint boundary.
- If the project builds successfully and required sprint tests pass, automatically prepare a Git commit.
- Verify `git status` contains only sprint-related files before committing.
- Verify there are no unresolved merge conflict markers before committing.
- Generate a concise commit message based on the completed sprint work.
- Commit and push to `origin/main`.
- Maintain `Project documents/Codex response.md` throughout implementation.
- After a successful build, required tests, commit and push, update `Project documents/PROJECT_STATE.md` with the verified repository state.
- If the build or required tests fail, do not commit or push. Record the failure and stop.
- If command-line `xcodebuild test` fails solely because of a verified Xcode/SwiftUI Preview tooling issue after a successful build, execute the equivalent regression suite from Xcode and treat that result as authoritative.
- Do not load unnecessary documentation.
- Do not redesign approved architecture.
- Preserve existing user-visible behaviour unless explicitly requested.
- Prefer extending existing architecture over creating parallel implementations.
- Never bypass repository abstractions.
- Never access SQLite directly from Views, ViewModels or Stores.
- Add new source files to the Xcode navigator and correct target membership.

- Keep `Project documents/Codex response.md` as the current sprint working log.
- Keep `Project documents/PROJECT_STATE.md` as the permanent verified handoff.
- Update `Project documents/Project_Guide.md` if project status changes.

These rules intentionally summarize the autonomous Git workflow. Detailed implementation workflow, validation rules and documentation precedence remain defined in `Project documents/Project_Guide.md`.

`Project_Guide.md` is the single source of truth for project workflow, architecture routing, documentation precedence and sprint execution. Avoid duplicating those rules here.
