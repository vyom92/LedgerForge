# LedgerForge – AI Instructions

`Project documents/Project_Guide.md` is the canonical entry point for every AI assistant (Copilot, Codex, ChatGPT or future agents).

Do not begin implementation until it has been read.

## Mandatory Workflow

Before writing code:

1. Read `Project documents/Project_Guide.md`.
2. Confirm the requested sprint and stop condition.
3. Read `Project documents/Codex response.md`.
4. Use the Task Routing Guide in `Project_Guide.md` to determine which additional documentation is required.
5. Produce an implementation plan before making code changes.

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
- Parsers understand financial institutions.
- Stores own runtime state.
- Dashboard observes stores.

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
- Run relevant tests.
- Preserve parser behaviour.
- Preserve repository behaviour.
- Do not introduce regressions.

## Documentation

At the end of every implementation:

- Update `Project documents/Codex response.md`.
- Update `Project documents/Project_Guide.md` if project status changed.
- Record deferred work.
- Stop exactly at the approved sprint boundary.

When documentation conflicts with implementation, documentation is authoritative until explicitly updated.
