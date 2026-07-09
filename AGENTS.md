# LedgerForge Agent Bootstrap

This file is intentionally minimal to minimise context usage for autonomous coding agents.

## Mandatory Entry Point

Before performing any planning, review, implementation or refactoring:

1. Read `Project documents/Project_Guide.md`.
2. Use the **Task Routing Guide** to determine which additional documents are required.
3. Read only the documents required for the requested task.
4. Read `Project documents/PROJECT_STATE.md` to establish the verified repository state.
5. Read `Project documents/Implementation.md` and only the ACTIVE sprint.
6. Execute the Planning Prompt or Implementation Prompt as appropriate.

## Operating Rules

- Read only the ACTIVE sprint in `Project documents/Implementation.md`.
- Never modify `Project documents/Implementation.md`.
- Archived sprint sections are historical reference only.
- Work on one approved sprint only.
- Stop exactly at the approved sprint boundary.
- If the project builds successfully and required sprint tests pass, automatically prepare a Git commit after confirming only sprint-related files are included.
- Verify `git status` contains only sprint-related files before committing.
- Verify there are no unresolved merge conflict markers before committing.
- Generate a concise commit message based on the completed sprint work.
- Commit and push to the tracked branch (normally `origin/main`).
- If a sprint tag is created, push the tag after the branch push succeeds.
- Update only `Project documents/Codex response.md` and `Project documents/PROJECT_STATE.md`.
- Never update planning documentation.
- If the build or required tests fail, do not commit or push. Record the failure in `Project documents/Codex response.md` and stop.
- If command-line `xcodebuild test` fails solely because of a verified Xcode/SwiftUI Preview tooling issue after a successful build, execute the equivalent regression suite from Xcode and treat that result as authoritative.
- Do not load unnecessary documentation.
- Do not redesign approved architecture.
- Preserve existing user-visible behaviour unless explicitly requested.
- Preserve the approved import pipeline: Reader → RawDocument → Institution Detection → Statement Classification → Parser Selection → FinancialDocument → Validation → Repository Persistence → RepositoryStoreHydrator → Runtime Stores → ViewModels → Views.
- Prefer extending existing architecture over creating parallel implementations.
- Reuse existing repository contracts where practical. Introduce new repository APIs only when existing contracts cannot express the required behaviour cleanly.
- Never bypass repository abstractions.
- RepositoryStoreHydrator is the only approved persistence-to-runtime boundary.
- Never access SQLite directly from Views, ViewModels or Runtime Stores.
- Add new source files to the Xcode navigator and correct target membership.
- Prefer Xcode-safe project updates over manual `.pbxproj` edits whenever project tooling is available.
- Keep `Project documents/Codex response.md` as the latest planning or implementation output.
- Keep `Project documents/PROJECT_STATE.md` as the permanent verified repository handoff.

`Project_Guide.md` remains the single source of truth for workflow, documentation precedence, architecture routing and sprint execution. Avoid duplicating detailed workflow rules in this bootstrap file.

# LedgerForge Agent Bootstrap

This file is intentionally minimal.

Its only purpose is to direct autonomous coding agents to the correct project documentation while minimising context usage.

---

## Mandatory Entry Point

Before performing any planning, review, implementation or refactoring:

1. Read `Project documents/Project_Guide.md`.
2. Use the **Task Routing Guide** to determine which additional documents are required.
3. Read only the documents required for the requested task.
4. Read `Project documents/PROJECT_STATE.md` to establish the verified repository state.
5. Read `Project documents/Implementation.md`.
6. Read only the ACTIVE sprint.
7. Execute either the Planning Prompt or the approved Implementation Prompt.

---

## Operating Rules

- Read only the ACTIVE sprint in `Project documents/Implementation.md`.
- Never modify `Project documents/Implementation.md`.
- Archived sprint sections are historical reference only.
- Work on one approved sprint only.
- Stop exactly at the approved sprint boundary.
- Build continuously.
- Run the required sprint validation.
- If the project builds successfully and required sprint tests pass, automatically prepare a Git commit after confirming only sprint-related files are included.
- Verify `git status` contains only sprint-related files before committing.
- Verify there are no unresolved merge conflict markers before committing.
- Generate a concise commit message describing the completed sprint.
- Commit and push to the tracked branch (normally `origin/main`).
- Push the sprint tag if one was created.
- Update only:
  - `Project documents/Codex response.md`
  - `Project documents/PROJECT_STATE.md`
- Never update planning documentation.
- If the build or required tests fail, do not commit or push. Record the failure in `Project documents/Codex response.md` and stop.
- Preserve the approved import pipeline:
  Reader → RawDocument → Institution Detection → Statement Classification → Parser Selection → FinancialDocument → Validation → Repository Persistence → RepositoryStoreHydrator → Runtime Stores → ViewModels → Views.
- RepositoryStoreHydrator is the only approved persistence-to-runtime boundary.
- Never bypass repository abstractions.
- Never access SQLite directly from Views, ViewModels or Runtime Stores.
- Add every new source file to the Xcode navigator and correct target membership.
- Prefer Xcode-safe project updates over manual `.pbxproj` edits whenever tooling is available.
- Do not redesign approved architecture.
- Preserve existing user-visible behaviour unless explicitly requested.
- Do not load unnecessary documentation.

---

`Project_Guide.md` remains the single source of truth for workflow, documentation precedence, architecture routing and sprint execution.

This bootstrap intentionally avoids duplicating those rules.
