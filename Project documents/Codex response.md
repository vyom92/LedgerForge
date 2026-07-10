# Codex Response

## Sprint 26 Implementation Plan - Documentation Alignment & Bootstrap Manifest Adoption

Planning only. No source files were modified, `Project documents/Implementation.md` was not modified, and no commit or push was performed.

## Inputs Reviewed

- `Project documents/.github/Context_Manifest.yaml`
- `Project documents/Project_Guide.md`
- `Project documents/PROJECT_STATE.md`
- `Project documents/Implementation.md` active Sprint 26 block
- `AGENTS.md`
- `Project documents/AI_WORKFLOW.md`
- `Project documents/.github/Project_Context.md`
- `Project documents/Database_v1_Architecture.md`
- `Project documents/Architecture_v1.0_Frozen.md`
- `Project documents/.github/prompts.md`

Note: `Project documents/.github/AGENTS.md` is referenced by the prompt, but the repository path present in this checkout is root `AGENTS.md`. Do not create a new `.github/AGENTS.md` file during Sprint 26 unless ChatGPT explicitly changes the sprint scope.

## Files To Modify

1. `AGENTS.md`
2. `Project documents/AI_WORKFLOW.md`
3. `Project documents/Project_Guide.md`
4. `Project documents/.github/Project_Context.md`
5. `Project documents/Database_v1_Architecture.md`
6. `Project documents/.github/Context_Manifest.yaml`

## Files To Review But Not Modify

- `Project documents/.github/prompts.md`
  - Already includes `Project documents/.github/Context_Manifest.yaml` as item 1 in the “Always begin with” list.
  - Already includes `Project documents/Implementation.md` with the ACTIVE sprint note.
  - No change required unless reviewer wants wording only.
- `Project documents/Architecture_v1.0_Frozen.md`
  - Line 3 is already aligned to Sprint 25: `architecture aligned through Sprint 25 (Account Identity & Import Foundation)`.
  - No change required.
- `Project documents/Implementation.md`
  - Must not be modified.
- Source code and tests
  - Must not be modified.

## Proposed Diffs

### `AGENTS.md`

Replace lines 9-14:

```diff
-1. Read `Project documents/Project_Guide.md`.
-2. Use the **Task Routing Guide** to determine which additional documents are required.
-3. Read only the documents required for the requested task.
-4. Read `Project documents/PROJECT_STATE.md` to establish the verified repository state.
-5. Read `Project documents/Implementation.md` and only the ACTIVE sprint.
-6. Execute the Planning Prompt or Implementation Prompt as appropriate.
+1. Read `Project documents/.github/Context_Manifest.yaml`.
+2. Read `Project documents/Project_Guide.md`.
+3. Use the **Task Routing Guide** to determine which additional documents are required.
+4. Read only the documents required for the requested task.
+5. Read `Project documents/PROJECT_STATE.md` to establish the verified repository state.
+6. Read `Project documents/Implementation.md` and only the ACTIVE sprint.
+7. Execute the Planning Prompt or Implementation Prompt as appropriate.
```

Replace lines 61-67:

```diff
-1. Read `Project documents/Project_Guide.md`.
-2. Use the **Task Routing Guide** to determine which additional documents are required.
-3. Read only the documents required for the requested task.
-4. Read `Project documents/PROJECT_STATE.md` to establish the verified repository state.
-5. Read `Project documents/Implementation.md`.
-6. Read only the ACTIVE sprint.
-7. Execute either the Planning Prompt or the approved Implementation Prompt.
+1. Read `Project documents/.github/Context_Manifest.yaml`.
+2. Read `Project documents/Project_Guide.md`.
+3. Use the **Task Routing Guide** to determine which additional documents are required.
+4. Read only the documents required for the requested task.
+5. Read `Project documents/PROJECT_STATE.md` to establish the verified repository state.
+6. Read `Project documents/Implementation.md`.
+7. Read only the ACTIVE sprint.
+8. Execute either the Planning Prompt or the approved Implementation Prompt.
```

### `Project documents/AI_WORKFLOW.md`

Replace line 5:

```diff
-`Project_Guide.md` is the mandatory first document. Use it to determine which additional documentation is required for the current task instead of reading every project document by default.
+`Project documents/.github/Context_Manifest.yaml` is the mandatory first bootstrap document. Then read `Project_Guide.md` to determine which additional documentation is required for the current task instead of reading every project document by default.
```

Replace lines 29-34:

```diff
-1. Confirm the requested sprint, scope and stop condition.
-2. Read:
-   - `Project documents/Project_Guide.md`
-   - `Project documents/PROJECT_STATE.md`
-   - `Project documents/Implementation.md`
-3. Read only the ACTIVE sprint.
+1. Confirm the requested sprint, scope and stop condition.
+2. Read:
+   - `Project documents/.github/Context_Manifest.yaml`
+   - `Project documents/Project_Guide.md`
+   - `Project documents/PROJECT_STATE.md`
+   - `Project documents/Implementation.md`
+3. Read only the ACTIVE sprint.
```

Replace lines 55-61:

```diff
-Read:
-
-- `Project documents/Project_Guide.md`
-- `Project documents/PROJECT_STATE.md`
-- `Project documents/Implementation.md`
-
-Read only the ACTIVE sprint.
+Read:
+
+- `Project documents/.github/Context_Manifest.yaml`
+- `Project documents/Project_Guide.md`
+- `Project documents/PROJECT_STATE.md`
+- `Project documents/Implementation.md`
+
+Read only the ACTIVE sprint.
```

### `Project documents/Project_Guide.md`

Replace line 3:

```diff
-This is the canonical project operating manual. Read this document first, then use the Task Routing Guide to load only the documents required for the current task. Avoid loading unnecessary documentation.
+This is the canonical project operating manual. Read `Project documents/.github/Context_Manifest.yaml` first, then this document, then use the Task Routing Guide to load only the documents required for the current task. Avoid loading unnecessary documentation.
```

Replace lines 9, 12 and 14:

```diff
-- **Current Sprint:** Workflow v2.1 documentation audit and repository housekeeping
+- **Current Sprint:** Sprint 26 — Documentation Alignment & Bootstrap Manifest Adoption (ACTIVE)
```

```diff
-- **Validation Status:** Build passing; full active validation passing. Sprint 22 validation complete.
+- **Validation Status:** Build passing; full active validation passing. Sprint 25 validation complete.
```

```diff
-- **Current Development Baseline:** Sprint 22 (UI Foundation)
+- **Current Development Baseline:** Sprint 25 (Account Identity & Import Foundation)
```

Replace line 35:

```diff
-| Validation | Build passing; full active validation passing. Sprint 22 validation complete |
+| Validation | Build passing; full active validation passing. Sprint 25 validation complete |
```

Add a documentation-index row after line 82:

```diff
+| Project documents/.github/Context_Manifest.yaml | Bootstrap manifest and minimal startup order | Every AI-assisted session | Highest |
```

Replace lines 225-229:

```diff
-- Read Project_Guide.md first.
-- Use the Task Routing Guide.
-- Review `Project documents/PROJECT_STATE.md`.
-- Read only the ACTIVE sprint in `Project documents/Implementation.md`.
-- Execute the Planning Prompt.
+- Read `Project documents/.github/Context_Manifest.yaml` first.
+- Read Project_Guide.md next.
+- Use the Task Routing Guide.
+- Review `Project documents/PROJECT_STATE.md`.
+- Read only the ACTIVE sprint in `Project documents/Implementation.md`.
+- Execute the Planning Prompt.
```

Replace lines 395-399:

```diff
-- Read Project_Guide.md first.
-- Use the Task Routing Guide.
-- Open only the documents required for the requested task.
-- Do not reread unchanged reference documents.
-- Read only the ACTIVE sprint in `Implementation.md`. Archived sprints are historical reference only.
+- Read `Project documents/.github/Context_Manifest.yaml` first.
+- Read Project_Guide.md next.
+- Use the Task Routing Guide.
+- Open only the documents required for the requested task.
+- Do not reread unchanged reference documents.
+- Read only the ACTIVE sprint in `Implementation.md`. Archived sprints are historical reference only.
```

Replace line 406:

```diff
-- Read this guide first.  
+- Read `Project documents/.github/Context_Manifest.yaml` first, then this guide.  
```

### `Project documents/.github/Project_Context.md`

Replace line 17:

```diff
-Sprint 23 (Planning)
+Sprint 26 — Documentation Alignment & Bootstrap Manifest Adoption (ACTIVE)
```

Replace lines 19-24:

```diff
-Current work is focused on:
-
-- Workflow v2.1 freeze
-- Documentation consolidation
-- Repository housekeeping
-- UI component extraction
+Current work is focused on:
+
+- Context_Manifest.yaml bootstrap adoption
+- Documentation alignment after Sprint 25 completion
+- Stale status-line cleanup
+- Documentation-only Sprint 26 planning and review
```

Replace line 34:

```diff
-The approved UI/UX visual language is frozen and implementation now focuses on translating approved assets into production SwiftUI.
+The approved UI/UX visual language remains frozen. Current work is documentation alignment; source code and UI implementation are out of scope for Sprint 26.
```

Add after line 108:

```diff
+- Sprint 23 UI Component Extraction
+- Sprint 24 Persistence and UI Behaviour Stabilisation
+- Sprint 25 Account Identity & Import Foundation
```

Replace lines 114-119:

```diff
-1. Complete Workflow v2.1 repository freeze.
-2. Sprint 23 — UI Component Extraction.
-3. Expand regression fixtures.
-4. Password-protected document support.
-5. PDF import.
-6. Insights & Analytics.
+1. Complete Sprint 26 documentation alignment.
+2. Adopt `Project documents/.github/Context_Manifest.yaml` as the first bootstrap file.
+3. Keep Sprint 25 repository state and documentation status lines aligned.
+4. Preserve architecture, UI/UX and ADR decisions.
+5. Defer fixtures, PDF import, OCR, insights and analytics to future approved sprints.
```

Replace lines 141-145:

```diff
-Every implementation begins with:
-
-1. `Project_Guide.md`
-2. `PROJECT_STATE.md`
-3. `Implementation.md`
+Every implementation begins with:
+
+1. `Project documents/.github/Context_Manifest.yaml`
+2. `Project_Guide.md`
+3. `PROJECT_STATE.md`
+4. `Implementation.md` (ACTIVE sprint only)
```

### `Project documents/Database_v1_Architecture.md`

Replace line 5:

```diff
-Status: Database v1 design baseline, architecture aligned through Sprint 22 / Milestone M7 UI Foundation
+Status: Database v1 design baseline, architecture aligned through Sprint 25 (Account Identity & Import Foundation)
```

Replace line 687:

```diff
-Created for Sprint 10 Phase 2A (architecture-only). Status-aligned through Sprint 22 / Milestone M7 UI Foundation. This document references ADR.md, Architecture_v1.0_Frozen.md, Engineering Standards.md, PROJECT_STATE.md and Product Vision.md as the authoritative design inputs.
+Created for Sprint 10 Phase 2A (architecture-only). Status-aligned through Sprint 25 (Account Identity & Import Foundation). This document references ADR.md, Architecture_v1.0_Frozen.md, Engineering Standards.md, PROJECT_STATE.md and Product Vision.md as the authoritative design inputs.
```

### `Project documents/.github/Context_Manifest.yaml`

Replace line 32 only if the manifest is intended to track latest repository commit rather than latest implementation commit:

```diff
-  latest_commit: "9424d5a"
+  latest_commit: "f86e87c"
```

If `latest_commit` is intentionally the latest implementation commit, leave line 32 unchanged and add no other manifest edits. The manifest already lists itself first in `bootstrap.read_order`.

## Reference Confirmation

After the approved edits:

- `AGENTS.md` will reference `Project documents/.github/Context_Manifest.yaml` as the first bootstrap file in both duplicated mandatory-entry sections.
- `Project documents/AI_WORKFLOW.md` will reference the manifest as the first bootstrap file before planning and implementation.
- `Project documents/Project_Guide.md` will reference the manifest as the first bootstrap file in the opening guidance, documentation index, planning workflow, context optimization and assistant instructions.
- `Project documents/.github/Project_Context.md` will reference the manifest as item 1 in canonical startup docs and report Sprint 26 as ACTIVE.
- `Project documents/.github/prompts.md` already satisfies the manifest and ACTIVE sprint acceptance criteria.
- `Project documents/Architecture_v1.0_Frozen.md` already satisfies Sprint 25 status alignment.
- `Project documents/Database_v1_Architecture.md` requires status-line updates at lines 5 and 687.

## Risks And Mitigations

- Risk: Creating `Project documents/.github/AGENTS.md` would exceed the “do not create new documents” boundary.
  - Mitigation: edit root `AGENTS.md` only; note the missing `.github/AGENTS.md` path for reviewer confirmation.
- Risk: Treating `Context_Manifest.yaml` as a documentation-precedence document could redesign workflow.
  - Mitigation: describe it only as the first bootstrap/read-order file, not as a replacement for architecture or ADR precedence.
- Risk: Updating frozen architecture/database docs could imply architecture changes.
  - Mitigation: status-line updates only; do not alter architecture, schema or ADR content.
- Risk: `latest_commit` in the manifest may be ambiguous.
  - Mitigation: reviewer should decide whether it means latest repository commit (`f86e87c`) or latest implementation commit (`9424d5a`) before implementation.

## Validation Steps

Run these after approved documentation edits:

```sh
rg -n "Context_Manifest.yaml" AGENTS.md "Project documents/AI_WORKFLOW.md" "Project documents/Project_Guide.md" "Project documents/.github/Project_Context.md" "Project documents/.github/prompts.md"
rg -n "Sprint 22|Sprint 23|Workflow v2.1 documentation audit|UI Component Extraction" "Project documents/Project_Guide.md" "Project documents/.github/Project_Context.md" "Project documents/Database_v1_Architecture.md"
rg -n "Sprint 26|ACTIVE|Sprint 25" "Project documents/Project_Guide.md" "Project documents/.github/Project_Context.md" "Project documents/Database_v1_Architecture.md" "Project documents/Architecture_v1.0_Frozen.md"
git status --short
```

Expected validation:

- Only approved documentation files are modified.
- No Swift/source/test/project files are modified.
- `Project documents/Implementation.md` is not modified.
- Manifest references appear in all required bootstrap documents.
- Sprint 22/Sprint 23 stale status lines are removed from the targeted current-status sections.
- Sprint 26 appears as ACTIVE in `Project_Context.md`.

## Stop Condition

Stop after presenting these diffs for review. Do not modify source code, do not modify `Project documents/Implementation.md`, do not commit and do not push until the Sprint 26 implementation prompt is approved.
