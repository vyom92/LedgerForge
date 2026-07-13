# LedgerForge Agent Bootstrap

This file is intentionally minimal.

Its only purpose is to direct planning and implementation assistants to the correct repository context while minimising unnecessary reading.

---

## Mandatory Entry Point

Before performing any planning, review, implementation, documentation synchronization or refactoring:

1. Read `Project documents/.github/Context_Manifest.yaml`.
2. Read this repository-root `AGENTS.md`.
3. Read `Project documents/Project_Guide.md`.
4. Read `Project documents/PROJECT_STATE.md` to establish verified repository state.
5. Read only the ACTIVE sprint in `Project documents/Implementation.md`.
6. For sprint planning or backlog work, read `Project documents/FUTURE_WORK.MD` after verified repository state; do not load it for routine implementation when the ACTIVE sprint is already defined.
7. Use the manifest and Project Guide to determine any additional documentation and source files required for the approved task.
8. Execute only the approved Planning Prompt, Implementation Prompt or Documentation Change Package.

---

## Operating Rules

- Read only the ACTIVE sprint in `Project documents/Implementation.md`.
- Archived sprint sections are historical records and must not be modified except for an explicitly approved factual correction.
- Work on one approved sprint or documentation task only.
- Stop exactly at the approved scope boundary.
- Do not load unrelated documentation or source files.
- Do not redesign approved product intent, financial rules, architecture, database design or UI/UX.
- Preserve existing user-visible behaviour unless the approved task explicitly changes it.
- Preserve financial truth. Any change that can affect imported values, balances, identifiers, classifications or calculations must be deterministic, explainable and validated.

#### Planning and Documentation

- Chat owns the content and approval of `Project documents/Implementation.md`.
- Chat plans sprints, reviews reports and approves documentation outcomes.
- Work performs repository-wide investigation and approved documentation synchronization.
- ChatGPT in Xcode may apply exact Chat-approved wording during a narrowly approved documentation task.
- Codex performs Swift implementation, builds, tests and implementation Git operations.
- Codex must never modify `Project documents/Implementation.md`.
- Documentation executors must apply approved wording faithfully and must not expand scope.
- `Project documents/Codex response.md` is the authoritative planning and implementation execution log maintained by the executing assistant.
- `Project documents/PROJECT_STATE.md` is the authoritative record of verified repository state and is updated only after successful validation, unless an approved documentation-only task explicitly requires a factual correction.
- If approved wording conflicts with verified repository state, stop and report the conflict instead of improvising.
- Present exact diffs before committing unless the approved task explicitly authorizes an immediate commit.

### Implementation

- Preserve the approved import pipeline:

  Reader → RawDocument → Institution Detection → Statement Classification → Parser Selection → Statement Parser → FinancialDocument → Validation → Fingerprinting & Duplicate Detection → Repositories → SQLite → RepositoryStoreHydrator → Runtime Stores → ViewModels → Views

- RepositoryStoreHydrator is the only approved persistence-to-runtime boundary.
- Never bypass repository abstractions.
- Never access SQLite directly from Views, ViewModels or Runtime Stores.
- Prefer extending existing architecture over creating parallel implementations.
- Reuse existing repository contracts where practical. Introduce new repository APIs only when existing contracts cannot express the approved behaviour cleanly.
- Add new source files to the Xcode navigator and ensure correct target membership.
- Prefer Xcode-safe project updates over manual `.pbxproj` edits whenever project tooling is available.

### Validation and Git

- Build continuously during implementation.
- Run all validation required by the ACTIVE sprint.
- If the build or required tests fail, do not commit or push.
- Record failed implementation results in `Project documents/Codex response.md` and stop.
- If command-line testing fails solely because of a verified Xcode tooling limitation after a successful build, run the equivalent test plan in Xcode and treat that result as authoritative.
- Before committing, verify:
  - `git status` contains only approved task files.
  - no unresolved merge conflict markers remain.
  - no unrelated source, test, asset or project-file changes are included.
- Commit and push only when the approved task permits it.
- Push a tag only when the approved release workflow explicitly requires one.

### Project Handoff Documents

- Keep `Project documents/Codex response.md` as the latest planning or implementation execution report produced by the assistant performing the approved task.
- Update `Project documents/PROJECT_STATE.md` only after successful implementation and validation, unless an approved documentation-only task explicitly requires a factual correction.
- Use `Project documents/PROJECT_STATE.md` as the authoritative verified repository handoff.

---

`Project documents/.github/Context_Manifest.yaml` is the canonical bootstrap manifest.

`Project documents/Project_Guide.md` remains the detailed source of truth for workflow, document precedence, task routing and sprint execution.

This bootstrap intentionally avoids duplicating the full workflow.
