# LedgerForge AI Workflow

This workflow applies to every AI-assisted implementation in LedgerForge.

`Project_Guide.md` is the mandatory first document. Use it to determine which additional documentation is required for the current task instead of reading every project document by default.

## Before Every Implementation

1. Confirm the requested sprint, scope and stop condition.
2. Read:
   - Project documents/Project_Guide.md
   - Project documents/PROJECT_STATE.md
   - Project documents/Codex response.md
3. Use the Task Routing Guide in `Project_Guide.md` to determine which additional documents are required. Depending on the task these may include:
   - .github/context.md
   - .github/ai-instructions.md
   - .github/prompts.md
   - Project documents/ADR.md
   - Project documents/Engineering Standards.md
   - Project documents/Product Vision.md
   - Project documents/Architecture_v1.0_Frozen.md
   - Project documents/Database_v1_Architecture.md
4. Produce an implementation plan.
5. Wait for approval before coding.

## During Implementation

Every implementation must:

- Work on one approved sprint only.
- Keep changes limited to the approved sprint.
- Preserve existing user-visible behaviour unless explicitly requested otherwise.
- Prefer extending existing architecture over creating parallel implementations.
- Prefer migration over duplication.
- Never redesign approved architecture.
- Never implement future sprint work.
- Build continuously.
- Run relevant tests where applicable.
- If the project builds successfully and all required tests for the approved sprint pass, automatically prepare a Git commit.
- Generate a concise commit message that accurately summarizes the completed work.
- Stage only files related to the approved sprint.
- Commit the changes.
- Push to the tracked branch (normally `origin/main`).
- If a sprint tag is created, push the tag after the branch push succeeds.
- Update `Project documents/PROJECT_STATE.md` only after a successful commit and push.
- Record the commit hash, tag (if created) and push result in `Project documents/Codex response.md`.
- If the build or required tests fail, do not commit or push. Record the failure in `Project documents/Codex response.md` and stop.
- Leave zero compile errors introduced by the sprint.
- Add every new file to the Xcode navigator.
- Add every new source file to the correct target membership.
- Use strongly typed models across architectural boundaries.
- Never bypass repository abstractions.
- Never access SQLite directly from Views, ViewModels or Stores.

## Before Stopping

Update `Project documents/Codex response.md` with:

- Summary
- Files Created
- Files Modified
- Build Result
- Validation Result
- Commit Hash (if committed)
- Tag (if created)
- Push Result
- Test Result
- Architecture Decisions
- Documentation Updated
- Remaining Technical Debt
- Deferred Items
- Next Recommended Sprint

If project status changed, update `Project documents/PROJECT_STATE.md`. Update `Project documents/Project_Guide.md` only if workflow, roadmap or guidance changed.

## Documentation Rules

- Never modify architecture without updating the relevant documentation.
- Architecture documentation overrides implementation assumptions.
- Engineering Standards define coding policy.
- If documentation conflicts with implementation, stop and report the conflict.

## Deferred Work Rules

- Never leave TODOs undocumented.
- Record all deferred work in `Project documents/Codex response.md`.
- Stop exactly at the approved sprint boundary.

## Completion Checklist

Before considering a sprint complete, confirm:

- Correct sprint implemented.
- Stop condition respected.
- Project builds successfully.
- Relevant tests pass or skipped tests are justified.
- Successful builds have been committed.
- Successful commits have been pushed to the tracked branch.
- Commit message accurately reflects the completed sprint work.
- Documentation updated.
- Codex response updated.
- No future sprint work included.
- Repository remains in a buildable state.
