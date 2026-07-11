# LedgerForge AI Workflow

This workflow applies to every AI-assisted implementation in LedgerForge.

`Project documents/.github/Context_Manifest.yaml` is the mandatory bootstrap document.

Read it first to determine the current project state, document precedence, bootstrap order, assistant responsibilities, and protected files.

Then follow the complete bootstrap order defined in the manifest.

---

# Workflow v2.1

The development workflow is based on a single active sprint.

`Project documents/Implementation.md` is the canonical sprint planning document.

Rules:

- Read only the ACTIVE sprint.
- Archived sprints are historical reference only.
- Desktop ChatGPT owns the content and approval of `Project documents/Implementation.md`.
- ChatGPT in Xcode may apply exact Desktop ChatGPT-approved wording.
- During implementation, Codex may modify only files required by the approved ACTIVE sprint.
- Codex may update:
  - `Project documents/Codex response.md` as the execution report.
  - `Project documents/PROJECT_STATE.md` only after successful validation.
- Codex never edits `Project documents/Implementation.md`.

---

# Before Every Planning Cycle

1. Confirm the requested sprint, scope and stop condition.

2. Bootstrap in this exact order:

   - `Project documents/.github/Context_Manifest.yaml`
   - `AGENTS.md`
   - `Project documents/Project_Guide.md`
   - `Project documents/PROJECT_STATE.md`
   - `Project documents/Implementation.md`

3. Read only the ACTIVE sprint.

4. Use the Task Routing Guide in `Project_Guide.md` to determine which additional documentation is required for the approved sprint.

5. Read only the documents required for that sprint. These may include:

   - `Project documents/.github/Project_Context.md`
   - `Project documents/.github/prompts.md`
   - `Project documents/ADR.md`
   - `Project documents/Engineering Standards.md`
   - `Project documents/Product Vision.md`
   - `Project documents/Architecture_v1.0_Frozen.md`
   - `Project documents/Database_v1_Architecture.md`
   - `Project documents/UI_UX_v1.0_Frozen.md`
   - `Project documents/BUILD_AND_PROJECT_CONVENTIONS.md`

6. Execute only the Planning Prompt contained in the ACTIVE sprint.

7. Output planning findings only to:

   `Project documents/Codex response.md`

8. Do not modify source code.

9. Do not modify `Implementation.md`.

10. Do not commit or push.

---

# Before Every Implementation

Implementation begins only after ChatGPT has reviewed the planning output and replaced the Planning Prompt with the approved Implementation Prompt.

Read in this order:

- `Project documents/.github/Context_Manifest.yaml`
- `AGENTS.md`
- `Project documents/Project_Guide.md`
- `Project documents/PROJECT_STATE.md`
- `Project documents/Implementation.md`

Read only the ACTIVE sprint.

Then read only the additional documentation required for that sprint.

Execute only the approved Implementation Prompt.

---

# During Implementation

Every implementation must:

- Work on one approved sprint only.
- Keep changes limited to the approved sprint.
- Never expand the sprint scope without an approved planning update.
- Never implement future milestones because related code appears straightforward.
- Prefer minimal, reversible changes over broad refactors.
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
- Treat `Project documents/Codex response.md` as the authoritative implementation log for the current sprint.
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
- `Context_Manifest.yaml` defines bootstrap order only; it must not duplicate volatile repository state.
- `PROJECT_STATE.md` remains the single source of truth for verified repository status.
- `Implementation.md` remains the only active sprint planning document.
- If documentation precedence conflicts with the manifest, stop and report the conflict instead of guessing.
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
- Bootstrap order remains consistent with `Context_Manifest.yaml`.
- No protected documentation was modified outside its assigned ownership.
- No workflow drift was introduced.
