# =======ACTIVE SPRINT==========

## Sprint 29 — Import Wizard Usability Stabilization

### Status

🟢 Ready for Implementation

### Objective

Fix the verified Import Wizard usability regression by keeping the review content scrollable within the available workspace while keeping `Cancel` and `Confirm Import` continuously visible.

This sprint is limited to layout and interaction stabilization of the existing Sprint 28 confirmation-gated import workflow.

---

## User Outcome

While reviewing a prepared import, the user can scroll through preview and validation content without losing access to the primary actions.

The Import Wizard must remain usable at normal desktop window sizes without requiring the user to hunt for confirmation controls below an oversized page.

---

## Verified Problem

The current Import Wizard progresses correctly through preparation, preview and validation review, but the full page can grow beyond the visible workspace.

As a result:

- review content and action controls compete for vertical space
- `Cancel` and `Confirm Import` may move outside the visible viewport
- the user must scroll the entire wizard page to complete the workflow
- the confirmation boundary is functionally correct but less predictable and harder to use

---

## Scope

### 1. Stable Wizard Layout

Refactor the existing Import Wizard layout so that:

- the wizard fits within the available content area
- the review content occupies the flexible central region
- long preview and validation content scrolls within that region
- the primary action area remains fixed and continuously visible

### 2. Pinned Action Footer

Keep the following actions visible while review content scrolls:

- `Cancel`
- `Confirm Import`

The footer must preserve the existing validation gating:

- `Confirm Import` is enabled only for a valid prepared import
- failed validation must not expose a persistence path
- repeated confirmation remains guarded

### 3. Existing Workflow Preservation

Preserve the complete Sprint 28 workflow:

Choose File
↓
Prepare
↓
Read-Only Preview
↓
Validation Review
↓
Explicit Confirmation
↓
Persist
↓
Dashboard Refresh
↓
Sprint 27 Import Outcome

No import, parser, validation, persistence, repository, runtime-store or hydration behaviour may change.

---

## Expected Files

Primary implementation:

- `ContentView.swift`

Tests may be added or updated only where required to verify layout-state or action-availability behaviour.

Documentation after successful implementation:

- `Project documents/PROJECT_STATE.md`
- `Project documents/Codex response.md`

Codex must not modify:

- `Project documents/Implementation.md`

---

## Acceptance Criteria

### Layout

- The Import Wizard does not require the entire page to scroll solely because preview or validation content is long.
- Preview and validation content scroll within the available central workspace.
- The action footer remains visible at normal supported desktop window sizes.
- No content is clipped or rendered inaccessible.

### Actions

- `Cancel` remains visible throughout preview and validation review.
- `Confirm Import` remains visible throughout preview and validation review.
- `Confirm Import` remains disabled or unavailable after failed validation.
- Repeated confirmation remains prevented.
- Cancellation still performs no writes, runtime-store updates or dashboard refresh.

### Visual Consistency

- Existing Deep Indigo styling is preserved.
- Existing shared LedgerForge components are reused where practical.
- No unrelated screen is redesigned.
- Toolbar, sidebar and wizard-step styling remain unchanged unless directly required for the layout fix.

### Architecture

- No parser changes.
- No validation changes.
- No persistence changes.
- No repository changes.
- No runtime-store changes.
- No hydrator changes.
- No SQLite or schema changes.
- No financial behaviour changes.

---

## Out of Scope

- Account chevron removal
- Toolbar standardization across screens
- Developer terminology cleanup
- `Pending` or `Soon` badge cleanup
- Transaction detail redesign
- Developer Console database-reset control
- Editable import preview
- Duplicate-management UI
- Password UI
- Batch import
- Drag and drop
- Dashboard redesign
- New parsers or file formats

These remain verified product-review items for later focused sprints.

---

## Validation

Before completion:

- Xcode diagnostics pass for modified files.
- Xcode project build passes.
- Full active Xcode test plan passes using Xcode-native validation tools.
- Existing Sprint 28 workflow tests continue passing.
- Manual verification confirms the action footer remains visible while preview content scrolls.
- Manual verification confirms validation failure still blocks confirmation.
- Manual verification confirms cancellation still performs no writes.
- `Project documents/Implementation.md` remains unchanged.
- Complete diff is reviewed.
- Only approved Sprint 29 files are included in the implementation commit.

---

## Stop Conditions

Stop and report without expanding scope if:

- the layout fix requires import workflow redesign
- persistence or state contracts must change
- the frozen UI/UX architecture must change
- unrelated screens require modification
- deterministic validation cannot be completed

---

## Completion Criteria

Sprint 29 is complete only when:

- review content scrolls within the Import Wizard workspace
- `Cancel` and `Confirm Import` remain continuously visible
- validation gating remains correct
- cancellation remains write-free
- the confirmation-gated workflow remains unchanged
- the application builds successfully
- the full active test plan passes
- `PROJECT_STATE.md` is updated with verified facts
- `Codex response.md` contains the Sprint 29 implementation report
- approved changes are committed and pushed

Do not archive Sprint 29.

Do not create Sprint 30.

Desktop ChatGPT will review the implementation, approve or reject Sprint 29, archive it and prepare the next ACTIVE sprint.

---

# =======ARCHIVED SPRINTS==========

## Sprint 28 — Confirmation-Gated Import Workflow

### Status

✅ Completed

### Objective

Introduce a read-only preview and validation review between successful parsing and repository persistence, requiring explicit user confirmation before any financial data is written.

### Outcome

Completed successfully.

Achievements:

- Prepared import model introduced as the in-memory bridge between preparation, review and commit.
- Import preparation performs reading, detection, classification, parser selection, parsing and validation without persistence.
- Read-only transaction preview implemented.
- Validation review implemented before persistence.
- Explicit confirmation is required before persistence.
- Validation failure cannot be persisted.
- Cancellation discards prepared state without repository writes, runtime-store mutation or dashboard refresh.
- Commit uses the prepared `FinancialDocument` and existing persistence coordinator.
- Existing post-import hydration and Sprint 27 outcome presentation preserved.
- Xcode build passed.
- Active Xcode test plan passed: 94 tests, 0 failures.
- Implementation commit: `262a07d`.
- Documentation handoff commit: `0170b44`.

### Validation

Verified:

- Preparation performs no writes.
- Preview is read-only.
- Validation is visible before persistence.
- Confirmation is required before persistence.
- Cancellation performs no writes.
- Existing parser, validation, repository, runtime-store, hydration and financial semantics remain unchanged.
- Architecture v1.0 preserved.
- UI/UX v1.0 Frozen preserved.

---

## Sprint 27 — Import Outcome Visibility

### Status

✅ Completed

### Objective

Make import outcomes explicit in the existing import result panel by showing verified validation and persistence states without changing the import pipeline, financial behaviour or repository architecture.

### Outcome

Completed successfully.

Achievements:

- Import outcome presentation enhanced using existing `ImportEngineResult` data.
- Validation and persistence outcomes are presented independently.
- Existing `LFStatusBadge` components are used for status presentation.
- `View Transactions` is available only after successful validation and persistence.
- Existing import execution behaviour was preserved.
- Existing repository boundaries were preserved.
- Existing post-import runtime hydration behaviour was preserved.
- Focused automated tests were added for import outcome presentation.
- Application built successfully.
- Full automated test suite passed (89 tests).
- Implementation committed and pushed successfully.

### Validation

Verified:

- Import outcome panel distinguishes:
  - Successful import
  - Validation failure
  - Persistence failure
- Existing import pipeline behaviour is unchanged.
- Validation-before-persistence behaviour is unchanged.
- Repository architecture is unchanged.
- No repository APIs changed.
- No runtime store contracts changed.
- No database schema changes were introduced.
- Architecture v1.0 preserved.
- UI/UX v1.0 Frozen preserved.

---

## Sprint 26 — Documentation Alignment & Bootstrap Manifest Adoption

### Status

✅ Completed

### Objective

Align repository documentation to the new Context_Manifest.yaml bootstrap, eliminate stale references, establish a deterministic bootstrap sequence and freeze the project documentation workflow before resuming feature development.

### Outcome

Completed successfully.

Achievements:

- Context_Manifest bootstrap adopted.
- Repository bootstrap order standardized.
- Documentation precedence synchronized.
- Assistant responsibilities aligned.
- PROJECT_STATE ownership clarified.
- Implementation ownership clarified.
- Repository-wide documentation consistency validated.
- Sprint 26 implementation report completed.
- Documentation changes committed and pushed.
- No source code, tests, project files or assets modified.

### Validation

Verified:

- Bootstrap order is consistent.
- Latest ADR is ADR-025.
- Sprint 25 remains the verified implementation baseline.
- Sprint 26 completed as a documentation-only sprint.
- Root `AGENTS.md` is authoritative.
- `PROJECT_STATE.md` remains the verified repository state document.
- `Implementation.md` remained unchanged throughout implementation.
