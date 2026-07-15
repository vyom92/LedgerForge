# LedgerForge AI Workflow

This workflow applies to every AI-assisted implementation in LedgerForge.

`Project documents/.github/Context_Manifest.yaml` is the mandatory bootstrap document.

Read it first to determine document precedence, bootstrap order, assistant responsibilities, routing guidance, and protected files.

Then follow the complete bootstrap order defined in the manifest.

---

# Workflow v2.1

The development workflow is based on a single ACTIVE sprint.

`Project documents/Implementation.md` is the canonical sprint planning document.

Rules:

- Read only the ACTIVE sprint.
- Archived sprints are historical reference only.
- Chat owns sprint planning, report review, documentation outcome approval and the content of `Project documents/Implementation.md`.
- Work performs repository-wide investigation and explicitly approved documentation synchronization.
- ChatGPT in Xcode may apply exact Chat-approved wording for a narrowly scoped documentation task.
- Codex performs Swift implementation, builds, tests and implementation Git operations for the approved ACTIVE sprint.
- During repository discovery, Work records evidence-backed findings in `Project documents/Codex response.md`.
- During implementation, Codex records implementation execution output in `Project documents/Codex response.md`.
- Codex may update `Project documents/PROJECT_STATE.md` only after successful validation.
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

4. When selecting the next sprint, read `Project documents/FUTURE_WORK.MD` after verified repository state. Check that completed or promoted work is not duplicated there.

5. Use the Task Routing Guide in `Project documents/Project_Guide.md` to determine which additional documentation is required for the approved sprint.

6. Read only the documents required for that sprint. These may include:

   - `Project documents/.github/Project_Context.md`
   - `Project documents/.github/prompts.md`
   - `Project documents/ADR.md`
   - `Project documents/Engineering Standards.md`
   - `Project documents/Product Vision.md`
   - `Project documents/Architecture_v1.0_Frozen.md`
   - `Project documents/Database_v1_Architecture.md`
   - `Project documents/UI_UX_v1.0_Frozen.md`
   - `Project documents/BUILD_AND_PROJECT_CONVENTIONS.md`

7. Work executes approved repository discovery and reports verified evidence. Chat defines or revises the ACTIVE sprint.

8. Work records repository-discovery findings only to:

   `Project documents/Codex response.md`

9. Do not modify source code.

10. Do not modify `Project documents/Implementation.md`.

11. Do not commit or push unless the approved task is an explicitly authorised documentation synchronization.

---

# Before Every Implementation

Implementation begins only after Chat has reviewed the repository-discovery output and installed the approved Implementation Prompt.

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
- Codex updates `Project documents/Codex response.md` with implementation results.
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

- Never modify approved architecture without updating the relevant documentation.
- Architecture documentation overrides implementation assumptions.
- Engineering Standards define coding policy.
- `Project documents/.github/Context_Manifest.yaml` defines bootstrap order and document routing only. It must not duplicate verified repository state.
- `Project documents/PROJECT_STATE.md` remains the single source of truth for verified repository status.
- `Project documents/Implementation.md` remains the only ACTIVE sprint planning document.
- `Project documents/FUTURE_WORK.MD` remains the single backlog for unscheduled work and research; it is not an implementation contract or progress log.
- Repository-wide documentation synchronization is performed by Work only when explicitly approved.
- If documentation precedence conflicts with the manifest, stop and report the conflict instead of guessing.
- If documentation conflicts with implementation, stop and report the conflict.

Documentation synchronization review cycle:

Chat approves documentation scope
↓
Work performs the approved synchronization
↓
Work validates consistency and pushes the commit
↓
Work returns the exact commit SHA
↓
Chat reviews the pushed commit
↓
Result: `PASS`, `PASS WITH CORRECTIONS` or `REJECT`

Corrections return to Work. No implementation agent is involved in this documentation-only cycle.

### Manual Verification Status

Distinguish these states in all reports:

- repository implementation complete;
- automated verification complete;
- manual runtime verification pending;
- fully runtime verified.

A repository implementation may be committed, pushed and handed off with manual runtime verification pending only when the ACTIVE contract permits accurate deferral, the pending status is explicitly disclosed, Chat accepts the limitation and no manual result is falsely claimed. Required manual gates remain blocking unless explicitly deferred and accepted.

---

# Deferred Work Rules

- Never leave TODOs undocumented.
- During implementation, record discovered deferred work in `Project documents/Codex response.md` and stop at the approved boundary.
- Chat decides whether a discovered item should be added to or reprioritised in `Project documents/FUTURE_WORK.MD`.
- Remove backlog items only when verified evidence confirms they entered the ACTIVE sprint or were completed.
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
- `Project documents/PROJECT_STATE.md` updated if required.
- `Project documents/Codex response.md` updated.
- No future sprint work included.
- Repository remains buildable.
- Bootstrap order remains consistent with `Project documents/.github/Context_Manifest.yaml`.
- No protected documentation was modified outside its assigned ownership.
- No workflow drift was introduced.
