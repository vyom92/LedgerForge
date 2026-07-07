# LedgerForge – AI Instructions

`Project documents/Project_Guide.md` is the canonical entry point for every AI assistant (Copilot, Codex, ChatGPT or future agents).

Do not begin implementation until it has been read.

## Mandatory Workflow

Before writing code:

1. Read `Project documents/Project_Guide.md`.
2. Read `Project documents/PROJECT_STATE.md`.
3. Confirm the approved sprint and stop condition.
4. Read `Project documents/Codex response.md`.
5. Use the Task Routing Guide in `Project_Guide.md` to determine which additional documentation is required.
6. Produce an implementation plan in `Project documents/Codex response.md` before making code changes.

## Scope Rules

- Work on one approved sprint only.
- Do not implement future sprint work.
- Do not redesign approved architecture.
- Preserve existing user-visible behaviour unless explicitly requested.
- If an architectural conflict is discovered, stop and document it in `Project documents/Codex response.md`.

## Architecture Rules

- Validation always precedes persistence.
- Repository protocols are the only abstraction permitted to access persistence.
- Repository implementations are the only components permitted to communicate with SQLite.
- Views never access SQLite.
- ViewModels never access SQLite.
- Stores never access SQLite.
- ImportCoordinator owns orchestration.
- Readers understand file formats.
- Institution Detection identifies the financial institution.
- Statement Classification determines the statement type.
- Parser Selection chooses the appropriate parser.
- Statement Parsers produce FinancialDocument.
- FinancialDocument is validated before persistence.
- Repository persistence completes before runtime stores are refreshed.
- Runtime Stores own observable application state.
- Dashboard and ViewModels observe runtime stores.

## Implementation Rules

Every new source file must:

- Be added to the Xcode navigator.
- Be added to the correct target membership.
- Compile successfully.

Prefer extending existing architecture over creating parallel implementations.

Prefer migration over duplication.

## Financial Rules

- Never invent financial rules.
- Never invent statement layouts.
- Never invent document formats.
- Never silently change financial behaviour.
- Preserve imported financial truth.
- Validation occurs before persistence.

## Testing

Before completion:

- Build successfully.
- Run the required sprint validation. If command-line tests fail solely because of the known SwiftUI Preview tooling issue after a successful build, run the equivalent Xcode regression suite and treat that result as authoritative.
- Record the authoritative validation path used if the command-line and Xcode validation paths differ.
- Preserve parser behaviour.
- Preserve repository behaviour.
- Do not introduce regressions.

## Documentation

At the end of every implementation:

- Update `Project documents/Codex response.md`.
- Record build result, validation result, commit hash, tag (if created) and push result.
- Update `Project documents/PROJECT_STATE.md` after a successful commit, push and tag (if applicable).
- Update `Project documents/Project_Guide.md` only if workflow, roadmap or engineering guidance changed.
- Ensure Project_Guide.md, PROJECT_STATE.md and Codex response.md are mutually consistent before beginning the next sprint.
- Record deferred work.
- Stop exactly at the approved sprint boundary.

If implementation exposes a genuine architectural inconsistency, stop, document it in Project documents/Codex response.md, and resolve the documentation before continuing implementation.
