# LedgerForge AI Workflow

This workflow applies to every AI-assisted implementation in LedgerForge.

`Project_Guide.md` is the mandatory first document. Use it to determine which additional documentation is required for the current task instead of reading every project document by default.

---

# Workflow v2.1

The development workflow is based on a single active sprint.

`Project documents/Implementation.md` is the canonical sprint planning document.

Rules:

- Read only the ACTIVE sprint.
- Archived sprints are historical reference only.
- ChatGPT owns and maintains `Implementation.md`.
- Codex never edits `Implementation.md`.
- Codex updates only:
  - `Project documents/Codex response.md`
  - `Project documents/PROJECT_STATE.md`

---

# Before Every Planning Cycle

1. Confirm the requested sprint, scope and stop condition.
2. Read:
   - `Project documents/Project_Guide.md`
   - `Project documents/PROJECT_STATE.md`
   - `Project documents/Implementation.md`
3. Read only the ACTIVE sprint.
4. Use the Task Routing Guide in `Project_Guide.md` to determine which additional documents are required. Depending on the task these may include:
   - `Project documents/.github/Project_Context.md`
   - `Project documents/.github/ai-instructions.md`
   - `Project documents/.github/prompts.md`
   - `Project documents/ADR.md`
   - `Project documents/Engineering Standards.md`
   - `Project documents/Product Vision.md`
   - `Project documents/Architecture_v1.0_Frozen.md`
   - `Project documents/Database_v1_Architecture.md`
5. Execute the **Planning Prompt** from the ACTIVE sprint.
6. Output planning findings only to `Project documents/Codex response.md`.
7. Do not modify source code.
8. Do not commit or push.

---

# Before Every Implementation

Implementation begins only after ChatGPT has reviewed the planning output and replaced the Planning Prompt with the approved Implementation Prompt.

Read:

- `Project documents/Project_Guide.md`
- `Project documents/PROJECT_STATE.md`
- `Project documents/Implementation.md`

Read only the ACTIVE sprint.

Execute only the approved Implementation Prompt.

---

# During Implementation

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
- If the project builds successfully and all required tests for the approved sprint pass, automatically prepare a Git commit only after verifying that staged files belong exclusively to the approved sprint.
- Generate a concise commit message that accurately summarizes the completed work.
- Stage only files related to the approved sprint.
- Commit the changes.
- Push to the tracked branch (normally `origin/main`).
- If a sprint tag is created, push the tag after the branch push succeeds.
- Update `Project documents/PROJECT_STATE.md` only after a successful commit and push.
- Update `Project documents/Codex response.md` with implementation results.
- Never modify `Project documents/Implementation.md`.
- If the build or required tests fail, do not commit or push. Record the failure in `Project documents/Codex response.md` and stop.
- Leave zero compile errors introduced by the sprint.
- Add every new file to the Xcode navigator.
- Add every new source file to the correct target membership.
- Use strongly typed models across architectural boundaries.
- Never bypass repository abstractions.
- Never access SQLite directly from Views, ViewModels or Stores.
- Repository-backed runtime store hydration is the only approved path from persistence into observable application state.

---

# Before Stopping

Update `Project documents/Codex response.md` with:

- Summary
- Files Created
- Files Modified
- Build Result
- Validation Result
- Commit Hash
- Tag (if created)
- Push Result
- Test Result
- Documentation Updated
- Remaining Technical Debt
- Deferred Items
- Recommended Next Sprint

If project status changed, update:

- `Project documents/PROJECT_STATE.md`

Do not modify `Project documents/Implementation.md`.

---

# Documentation Rules

- Never modify architecture without updating the relevant documentation.
- Architecture documentation overrides implementation assumptions.
- Engineering Standards define coding policy.
- If documentation conflicts with implementation, stop and report the conflict.

---

# Deferred Work Rules

- Never leave TODOs undocumented.
- Record all deferred work in `Project documents/Codex response.md`.
- Do not begin future sprint work.
- Stop exactly at the approved sprint boundary.

---

# Completion Checklist

Before considering a sprint complete, confirm:

- Correct sprint implemented.
- Stop condition respected.
- Project builds successfully.
- Relevant tests passed (or skipped tests justified).
- Successful builds committed.
- Successful commits pushed.
- Commit message accurately reflects the completed sprint.
- `PROJECT_STATE.md` updated if required.
- `Codex response.md` updated.
- No future sprint work included.
- Repository remains buildable.
