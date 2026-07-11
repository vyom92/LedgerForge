# =======ACTIVE SPRINT==========

## Sprint 28 — Confirmation-Gated Import Workflow

### Status

🟢 Ready for Implementation

---

## Objective

Introduce a read-only preview and validation review between successful parsing and repository persistence, requiring explicit user confirmation before any financial data is written.

Sprint 28 transforms the current immediate-import workflow into a deterministic:

**Prepare → Review → Confirm → Persist**

workflow while preserving the existing parsing, validation, repository architecture, runtime-store synchronization and post-import dashboard refresh.

This sprint changes the **user workflow**, not the financial architecture.

---

## User Outcome

After selecting a supported financial statement, the user must be able to:

- inspect detected document information
- inspect parsed financial data
- review validation status
- review validation issues
- cancel without writing data
- explicitly confirm the import
- receive the existing Sprint 27 import result presentation after persistence completes

The user should never be uncertain whether the statement has merely been analysed or has actually been imported.

---

## Problem Statement

Today the workflow is:

```text
Choose File
      ↓
Read
      ↓
Parse
      ↓
Validate
      ↓
Persist
      ↓
Runtime Stores
      ↓
Dashboard Refresh
```

This means selecting a file immediately commits financial data after validation succeeds.

The frozen UI/UX specifies a confirmation-gated Import Wizard.

The current implementation therefore skips the most important trust boundary in the application.

---

## Target Workflow

Sprint 28 must implement:

```text
Choose File
      ↓
Read
      ↓
Institution Detection
      ↓
Statement Classification
      ↓
Parser Selection
      ↓
Statement Parsing
      ↓
FinancialDocument
      ↓
Validation
      ↓
Read-Only Preview
      ↓
Validation Review
      ↓
Confirm Import
      ↓
Persistence
      ↓
Repository Hydration
      ↓
Runtime Stores
      ↓
Dashboard Refresh
      ↓
Sprint 27 Import Outcome
```

Persistence must occur **only** after explicit confirmation.

---

# Core Behaviour

The import lifecycle must be divided into two independent stages.

## Stage 1 — Prepare

The Prepare stage performs:

- file reading
- institution detection
- statement classification
- parser selection
- parsing
- FinancialDocument creation
- validation

The Prepare stage must produce everything required for review.

The Prepare stage must **never**:

- persist repositories
- modify SQLite
- update runtime stores
- refresh dashboard data
- create durable financial records

---

## Stage 2 — Commit

The Commit stage begins only after the user selects:

**Confirm Import**

The Commit stage performs:

- persistence using the existing coordinator
- the existing approved post-persistence state update
- return of the existing Sprint 27-compatible import result

After successful commit, the existing UI composition-root flow performs:

- the existing forced repository hydration
- Dashboard presentation refresh
- Sprint 27 import outcome presentation

The Commit stage must use the prepared import.

It must **not**:

- reread the file
- rerun parser selection
- parse again
- regenerate FinancialDocument
- rerun validation unless absolutely required by existing architecture

---

# Design Principles

Sprint 28 must preserve:

- Offline-first behaviour
- Deterministic financial truth
- Explainable workflow
- Existing repository architecture
- Existing validation semantics
- Existing persistence logic

No financial behaviour may change.

Only the workflow changes.

---

# Implementation Scope

Sprint 28 implementation scope contains the following five structural components.

---

## Deliverable 1

### Prepared Import Model

Introduce one explicit model representing a prepared import.

This model becomes the bridge between:

Prepare

↓

User Review

↓

Commit

The prepared model should reuse existing models wherever possible.

Expected contents include:

- filename
- source URL or approved source reference, retained only as metadata and never reread during commit
- detected institution
- detected document type
- parser identity
- FinancialDocument
- ImportValidationResult
- transaction count
- detected currency
- statement period
- account metadata
- any existing metadata required for persistence

Do not introduce duplicate financial models.

FinancialDocument remains the financial truth.

---

## Deliverable 2

### Prepare Import API

Separate preparation from persistence.

Conceptually:

```swift
prepareImport(from:)
```

The exact API name may differ.

Responsibilities:

- execute the current reader
- execute institution detection
- execute parser selection
- execute parsing
- execute validation
- produce Prepared Import

Must not:

- persist
- update stores
- hydrate dashboard

Reuse existing implementation wherever possible.

Avoid duplicated pipeline logic.

---

## Deliverable 3

### Commit Prepared Import

Conceptually:

```swift
commitPreparedImport(_:)
```

Responsibilities:

- verify the prepared import
- reject invalid prepared imports
- execute the existing persistence coordinator
- preserve the existing post-persistence runtime-store behaviour
- return an `ImportEngineResult` compatible with the Sprint 27 outcome presentation

The commit API must not access `DashboardViewModel` or own dashboard presentation.

After a successful commit, the existing UI composition-root flow must perform the existing forced `RepositoryStoreHydrator` refresh and update the Dashboard presentation state.

Do not relocate existing post-persistence responsibilities between `ImportEngine`, runtime stores, `RepositoryStoreHydrator` and `ContentView` during Sprint 28. If the current implementation conflicts with the frozen architecture, stop and report the conflict instead of redesigning it.

Must not:

- reread file
- reparse document
- alter FinancialDocument
- change validation result

---

## Deliverable 4

### Import Wizard

The existing Import Wizard shell becomes functional.

Workflow:

Choose File

↓

Preparing

↓

Preview

↓

Validation Review

↓

Confirm

↓

Import

↓

Outcome

Existing shell styling should be preserved.

Do not redesign the Imports screen.

---

## Deliverable 5

### Cancellation

Cancellation must:

- discard prepared import
- perform no persistence
- perform no runtime-store updates
- perform no dashboard refresh

Prepared data remains memory-only.

---

# Wizard State Machine

Implement an explicit wizard state.

Minimum states:

```text
idle

fileSelected

preparing

previewReady

validationFailed

committing

completed

failed
```

Equivalent naming is acceptable.

The state machine must reject invalid transitions.

---

## Valid Flow

```text
idle

↓

fileSelected

↓

preparing

↓

previewReady

↓

committing

↓

completed
```

Validation failure:

```text
preparing

↓

validationFailed
```

Errors:

```text
preparing

↓

failed
```

or

```text
committing

↓

failed
```

Cancellation returns to:

```text
idle
```

---

# Wizard Step Requirements

## Step 1

### Choose File

Preserve existing:

- file importer
- supported formats

Selecting a file must begin:

Preparation

Selecting a file must not begin:

Persistence

---

## Step 2

### Preparing

Display:

- loading state
- progress indicator (where practical)

Disable:

- repeated preparation

Keep UI responsive.

Parser executes exactly once.

---

## Step 3

### Read-Only Preview

Display when available:

- filename
- institution
- document type
- account
- statement period
- currency
- transaction count
- opening balance
- closing balance

Display a representative subset of parsed transactions.

Suggested:

10–20 rows.

Each row should reuse existing transaction presentation where practical.

Fields:

- date
- description
- amount
- balance
- currency

Preview must remain read-only.

Editing is prohibited.

---

## Step 4

### Validation Review

Display:

- validation status
- issue count
- warning count, where represented by the existing validation model
- validation messages

Display a clear statement that:

No data has been written.

Validation presentation must reuse existing validation semantics.

Do not invent new validation categories.

---

## Step 5

### Confirmation

Successful validation displays:

- Cancel
- Confirm Import

Failed validation displays:

- Cancel

Confirmation must not be available after failed validation.

No persistence path may bypass confirmation.

---

## Step 6

### Commit

While committing:

- disable repeated confirmation
- show progress
- preserve prepared FinancialDocument

On success:

- existing persistence path
- runtime-store update
- dashboard refresh
- Sprint 27 import result

On failure:

- existing failure presentation
- accurate persistence state
- preserve error information

---

## Cancellation Behaviour

Cancellation before confirmation must:

- discard the prepared import
- perform no repository writes
- perform no SQLite writes
- perform no runtime-store updates
- perform no dashboard refresh

Prepared data must remain in memory only for the lifetime of the Import Wizard session.

No draft import state may be persisted.

---

# Preview Data Rules

The preview is informational only.

Do not implement:

- transaction editing
- account editing
- amount editing
- balance editing
- date editing
- merchant editing
- category editing
- institution override
- parser override
- currency override
- row insertion
- row deletion

Future correction workflows require a dedicated sprint.

---

# Validation Rules

Preserve all existing validation behaviour.

Sprint 28 may expose validation information but must not:

- introduce new validation rules
- weaken validation
- reinterpret validation severity
- alter transaction values
- bypass failed validation
- permit persistence after failed validation

Validation remains the authoritative gate before persistence.

---

# Persistence Rules

Persistence must continue to use the existing:

- ImportPersistenceCoordinator
- Repository layer
- Repository implementations
- Duplicate detection
- Fingerprinting
- Runtime-store integration
- RepositoryStoreHydrator

Do not introduce an alternative persistence path.

Views and ViewModels must never access SQLite directly.

---

# Architecture Constraints

Preserve the canonical import pipeline.

```text
Reader
↓
RawDocument
↓
Institution Detection
↓
Statement Classification
↓
Parser Selection
↓
Statement Parser
↓
FinancialDocument
↓
Validation
↓
User Review
↓
Explicit Confirmation
↓
Persistence
↓
Repositories
↓
SQLite
↓
RepositoryStoreHydrator
↓
Runtime Stores
↓
ViewModels
↓
Views
```

The only approved workflow change is the insertion of the review and confirmation boundary after validation and before persistence.

No redesign of repositories, runtime stores or persistence is authorised.

---

# UI / UX Requirements

Preserve:

- Deep Indigo theme
- Current application shell
- Sidebar
- Contextual toolbar
- Existing Imports screen layout where practical
- Desktop-first presentation
- Dense information layout

Reuse shared components wherever possible, including:

- LFPanel
- LFStatusBadge
- LFInfoRow
- LFActionRow
- LFEmptyState

Create new shared components only when they are genuinely reusable.

Do not redesign unrelated screens.

---

# Expected Files

Primary implementation will likely involve:

- ContentView.swift
- ImportEngine.swift

Potential supporting files:

- Import models
- Import state models
- Import Wizard views
- Existing validation models (read-only integration only)

Likely test files:

- ImportEngine tests
- Import Wizard workflow tests
- Presentation-state tests

Documentation updates after successful validation:

- Project documents/PROJECT_STATE.md
- Project documents/Codex response.md

Codex must not modify:

- Project documents/Implementation.md

---

# Deliverables

## Deliverable 1

Prepare without persistence.

The application can:

- read
- parse
- validate

without:

- persistence
- runtime-store updates
- dashboard refresh

---

## Deliverable 2

Read-only preview.

Display:

- document metadata
- transaction count
- representative transactions
- balances
- currencies (where available)

---

## Deliverable 3

Validation review.

Display:

- validation status
- validation issues
- warning count (where applicable)
- clear indication that no data has yet been written

---

## Deliverable 4

Explicit confirmation.

Persistence begins only after:

Confirm Import

---

## Deliverable 5

Safe cancellation.

Cancel performs:

- no writes
- no hydration
- no runtime-store updates

---

## Deliverable 6

Existing behaviour preserved.

After confirmation:

- existing persistence path
- existing runtime-store update
- existing dashboard refresh
- existing Sprint 27 import outcome presentation

must all remain unchanged.

---

# Acceptance Criteria

## Preparation

- Selecting a file begins preparation only.
- Parsing occurs exactly once.
- Validation completes before preview.
- No repository writes occur.
- Runtime stores remain unchanged.
- Dashboard remains unchanged.

---

## Preview

Display when available:

- filename
- institution
- document type
- transaction count
- statement period
- balances
- currency
- read-only transaction sample

Nothing is editable.

---

## Validation Review

Display:

- validation status
- existing validation issues

Failed validation disables confirmation.

Successful validation enables confirmation.

The interface must clearly indicate that no data has yet been written.

---

## Confirmation

Confirm Import:

- persists exactly once
- cannot be double-triggered
- uses the prepared FinancialDocument
- does not reread the file
- does not reparse the statement

Cancel performs no writes.

---

## Successful Commit

Preserve:

- existing persistence coordinator
- duplicate detection
- runtime-store updates
- dashboard refresh
- Sprint 27 success presentation

---

## Failed Commit

Display:

- persistence failure
- validation status
- existing failure information

Do not show View Transactions.

---

## Architecture

No:

- SQLite access from UI
- repository bypass
- parser redesign
- validation redesign
- financial value changes
- schema changes

---

# Automated Test Requirements

Add focused automated tests for:

## Prepare

- successful prepare
- no persistence
- no runtime-store mutation
- FinancialDocument preserved

---

## Validation Failure

- failed validation blocks commit
- validation issues exposed
- no persistence

---

## Confirmation

- valid prepared import commits
- commit uses prepared data
- duplicate confirmation prevented

---

## Cancellation

- cancel discards prepared state
- cancel performs no writes
- cancel performs no runtime-store updates

---

## Existing Behaviour

Verify:

- Sprint 27 outcome presentation remains correct
- dashboard refresh still occurs
- existing import tests continue passing

Use deterministic tests wherever possible.

---

# Manual Validation

Verify:

## Successful Import

1. Choose valid statement.
2. Preparation completes.
3. Preview displayed.
4. Validation displayed.
5. Confirm Import.
6. Persistence succeeds.
7. Dashboard refreshes.
8. Existing Sprint 27 outcome displayed.

---

## Cancel

1. Choose statement.
2. Reach preview.
3. Cancel.
4. Verify no transactions imported.
5. Verify dashboard unchanged.

---

## Validation Failure

1. Prepare invalid statement.
2. Validation issues displayed.
3. Confirm unavailable.
4. No persistence occurs.

---

## Persistence Failure

Using an existing deterministic failure path where available:

1. Prepare valid statement.
2. Trigger persistence failure.
3. Validation remains Passed.
4. Persistence displays Failed.
5. View Transactions not shown.

---

# Regression Requirements

The following must remain unchanged:

- startup hydration
- dashboard cards
- account summaries
- transaction search
- transaction filters
- Developer Console logging
- parser selection
- institution detection
- statement classification
- validation rules
- persistence mapping
- repository contracts
- runtime-store contracts
- database schema
- Sprint 27 import outcome presentation

Run the complete active test plan.

---

# Explicitly Out of Scope

- editable preview
- transaction correction
- account correction
- duplicate-management UI
- password UI
- drag and drop
- batch import
- parser selection UI
- institution override
- analytics
- investments
- OCR
- new parsers
- new institutions
- new file formats
- schema changes
- repository redesign
- dashboard redesign
- global search

---

# Implementation Rules

- Inspect current implementation before editing.
- Reuse the existing pipeline.
- Extract clean responsibilities instead of duplicating logic.
- Keep prepared imports in memory only.
- Avoid unrelated refactoring.
- Do not rename unrelated symbols.
- Do not modify frozen documents.
- Do not modify archived sprint records.
- Do not modify Project documents/Implementation.md during implementation.

If a clean prepare/commit separation cannot be achieved without architectural change:

Stop.

Report the conflict.

Do not improvise.

---

# Validation

Before completion:

- Xcode build passes.
- Full active test plan passes.
- New Sprint 28 tests pass.
- Existing tests continue passing.
- Diff reviewed.
- No merge markers remain.
- Only approved files changed.

---

# PROJECT_STATE.md

After successful implementation update only verified facts.

Record:

- Sprint 28 completed
- confirmation-gated workflow implemented
- preview implemented
- validation review implemented
- confirmation required before persistence
- cancellation performs no writes
- dashboard refresh preserved
- build result
- test result
- implementation commit
- push result

Do not record assumptions.

---

# Codex response.md

Replace the document with:
```md
# Sprint 28 Implementation Report

## Summary

## Bootstrap Documents Reviewed

## Additional Files Reviewed

## Sprint Objective

## Files Modified

## Prepare / Commit Separation

## Wizard State Flow

## Preview Implementation

## Validation Review

## Confirmation Behaviour

## Cancellation Behaviour

## Existing Behaviour Preservation

## Automated Validation

### Build

### Tests

### Sprint 28 Tests

## Manual Validation

## Architecture Verification

## Git Diff Verification

## Commit

## Push Result

## Remaining Required Issues

## Recommended Follow-up

## Sprint 28 Completion Status
```
Record verified facts only.
---

# Git Requirements

Before committing:

- review git status
- review full diff
- verify only approved files changed
- verify Implementation.md unchanged
- verify build succeeded
- verify tests passed

After validation:

Commit:

Implement Sprint 28 confirmation-gated import workflow

Push.

Record:

- implementation commit
- push result

inside:

- PROJECT_STATE.md
- Codex response.md

---

# Stop Conditions

Stop and report if:

- schema changes become necessary
- repository redesign becomes necessary
- parser must execute twice
- validation semantics must change
- financial values change
- repository contracts must change
- scope expands beyond Sprint 28
- deterministic tests cannot be achieved

Do not work around architectural conflicts.

---

# Completion Criteria

Sprint 28 is complete only when:

- preparation occurs without persistence
- preview is read-only
- validation is visible before persistence
- confirmation is required
- cancellation performs no writes
- validation failure cannot be persisted
- successful confirmation uses the existing persistence path
- dashboard refresh still occurs
- Sprint 27 outcome presentation remains intact
- application builds successfully
- full active test plan passes
- PROJECT_STATE.md updated
- Codex response.md updated
- approved changes committed and pushed

Do not archive Sprint 28.

Do not create Sprint 29.

Desktop ChatGPT will review the implementation, approve or reject Sprint 28, archive it, and prepare the next ACTIVE sprint.


# =======ARCHIVED SPRINTS==========

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
