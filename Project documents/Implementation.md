# =======ACTIVE SPRINT==========

## Sprint 31 — Developer Diagnostics & Logging

### Status

🟢 Ready for Implementation

### Objective

Transform the existing Developer Console into a cohesive developer diagnostics workspace that provides clear, structured insight into LedgerForge's internal behaviour while preserving the existing architecture and keeping all financial behaviour unchanged.

Sprint 31 focuses exclusively on developer diagnostics, logging quality and reusable diagnostic UI components.

It must not introduce new financial features or alter parser behaviour, validation behaviour, repository contracts, runtime hydration, database schema or financial calculations.

---

## User Outcome

During development, the user can clearly understand what LedgerForge is doing, why it is doing it and whether operations completed successfully without being overwhelmed by low-level parser diagnostics or implementation details.

The Developer Console becomes the central workspace for monitoring application activity, viewing structured diagnostic information and understanding the lifecycle of major operations while remaining lightweight and easy to read.

---

## Scope

### 1. Structured Diagnostic Log

Replace the existing plain-string log implementation with a structured logging model.

Each log entry shall contain only verified diagnostic information.

Each entry should support:

- sequence number
- timestamp
- log level
- category
- concise message
- optional structured metadata where appropriate

The logging model must remain lightweight and deterministic.

Do not introduce a general-purpose logging framework or external dependency.

---

### 2. Diagnostic Levels

Introduce meaningful diagnostic levels.

Supported levels:

- Debug
- Info
- Warning
- Error

Rules:

- every log entry belongs to exactly one level
- Debug is intended for implementation details
- Info represents normal successful application activity
- Warning represents recoverable conditions
- Error represents operations that failed or could not complete
- do not invent artificial severity values
- do not duplicate levels with categories

---

### 3. Diagnostic Categories

Introduce structured categories.

Supported categories:

- Application
- Import
- Parser
- Validation
- Database
- Runtime

Rules:

- every log entry belongs to one category
- categories describe the subsystem
- levels describe importance
- future categories may be added without redesigning the logging model

---

### 4. Import Lifecycle Presentation

Replace verbose import logging with concise lifecycle events.

The primary console should present events such as:

- Import started
- Institution detected
- Parser selected
- Validation completed
- Repository persistence completed
- Runtime refresh completed
- Import completed
- Import failed

Parser-specific diagnostics such as:

- detected delimiter
- encoding
- row counts
- header detection
- normalization details
- parser internals

must no longer appear in the default log view.

Those details belong to Debug entries only.

The console should answer:

"What is LedgerForge doing?"

rather than

"How is LedgerForge implemented?"

---

### 5. Log Presentation

Improve readability of the Developer Console.

Requirements:

- newest log entries appear first
- original sequence numbers remain unchanged
- timestamps remain visible
- long messages wrap correctly
- log presentation remains performant with large histories
- visual hierarchy should clearly distinguish lifecycle events from warnings and errors

Do not renumber historical entries after reversing display order.

Preserve chronological integrity.

---

### 6. Diagnostic Filtering

Provide lightweight filtering without changing stored log data.

Supported filters:

- All Levels
- Debug
- Info
- Warning
- Error

Supported category filters:

- All Categories
- Application
- Import
- Parser
- Validation
- Database
- Runtime

Rules:

- filtering affects presentation only
- filtering must never modify stored log entries
- multiple filters may be combined
- clearing filters restores the complete log history
- search operates on the currently filtered view
- filtering must remain responsive for large log histories

---

### 7. Search, Copy and Clear

Preserve the existing Developer Console utilities while improving usability.

Search

- plain-text substring search
- case-insensitive
- searches message and visible metadata only
- does not mutate stored logs

Copy All

- copies the complete stored diagnostic history
- preserves chronological order of the underlying log
- includes timestamps, level and category
- remains available regardless of active filters

Clear

- removes all stored log entries
- resets search and filter state
- does not affect runtime stores
- does not affect repositories
- does not affect application state

No additional export functionality is included in this sprint.

---

### 8. Runtime Inspector Refinement

Refine presentation of the existing Runtime Inspector.

The Runtime Inspector should present concise runtime information including, where available:

- repository provider
- active database path
- hydration status
- account count
- transaction count
- latest refresh result

Rules:

- presentation only
- no new runtime state
- no duplicate ownership of existing data
- continue using RepositoryStoreHydrator as the canonical runtime source

No additional runtime controls are introduced.

---

### 9. Reusable Diagnostic UI Components

Eliminate recurring Developer Console interaction inconsistencies.

Introduce reusable LedgerForge diagnostic controls where appropriate.

These should include consistent behaviour for:

- Primary buttons
- Secondary buttons
- Destructive buttons
- Toolbar buttons

Requirements:

- entire visible control is clickable
- consistent padding
- consistent corner radius
- consistent hover behaviour
- consistent keyboard focus
- consistent accessibility behaviour
- consistent disabled appearance
- no control may respond only when clicking directly on its text or icon

The goal is to establish reusable interaction behaviour rather than repeatedly correcting individual screens.

---

### 10. Developer Diagnostics Philosophy

The Developer Console should present operational information rather than implementation details.

Default presentation should answer questions such as:

- What operation is running?
- Did it complete successfully?
- What subsystem produced this event?
- Does the developer need to take action?

Implementation details belong in Debug entries.

The default experience should remain concise, readable and focused on application behaviour.

Developer Console is not intended to become:

- a SQL browser
- a parser debugger
- a repository explorer
- a runtime object inspector

Those remain future capabilities if ever required.

---

## Expected Files

Expected implementation files may include:

- `Core/DeveloperConsole.swift`
- `Views/DeveloperConsoleView.swift`
- Shared diagnostic UI component files where appropriate
- Focused Developer Console tests
- `Project documents/PROJECT_STATE.md`
- `Project documents/Codex response.md`

Additional files may be modified only where directly required by Sprint 31.

`Project documents/Implementation.md` must not be modified by Codex.

---

## Architecture Constraints

Preserve the existing architecture:

Developer Console
↓
Developer Diagnostics
↓
RepositoryStoreHydrator
↓
Runtime Stores
↓
Repositories
↓
SQLite

Requirements:

- no parser changes
- no validation changes
- no repository contract changes
- no database schema changes
- no financial calculation changes
- no runtime-store duplication
- no direct SQLite access from UI
- no additional persistence mechanisms
- no external logging frameworks
- no replacement of RepositoryStoreHydrator
- no architectural changes outside the Developer Console

Structured logging must remain a presentation and diagnostics improvement only.

Financial behaviour must remain completely unchanged.

---

## Acceptance Criteria

Sprint 31 is complete only when all of the following are satisfied.

### Structured Diagnostic Log

- Plain string logging has been replaced by structured diagnostic entries.
- Every log entry contains:
  - sequence number
  - timestamp
  - level
  - category
  - message
- Optional metadata is supported without becoming mandatory.
- Existing logging behaviour remains deterministic.

---

### Diagnostic Levels

Supported levels:

- Debug
- Info
- Warning
- Error

Requirements:

- every entry belongs to exactly one level
- levels remain semantically meaningful
- Debug is hidden by default
- levels are visually distinguishable

---

### Diagnostic Categories

Supported categories:

- Application
- Import
- Parser
- Validation
- Database
- Runtime

Requirements:

- every entry belongs to exactly one category
- categories remain extensible
- category filtering operates correctly

---

### Import Lifecycle

Default import presentation shows concise lifecycle events.

Examples include:

- Import Started
- Institution Detected
- Parser Selected
- Validation Completed
- Repository Updated
- Runtime Refreshed
- Import Completed
- Import Failed

Parser implementation details no longer appear in the default console.

Parser diagnostics remain accessible through Debug entries.

---

### Log Presentation

Requirements:

- newest entries displayed first
- historical sequence numbers preserved
- timestamps visible
- long messages wrap correctly
- scrolling remains smooth with large histories
- newest entries appear without requiring manual scrolling

---

### Filtering

Users can filter by:

- Level
- Category

Requirements:

- filtering affects presentation only
- stored logs remain unchanged
- multiple filters work together
- clearing filters restores the complete log
- filter changes occur without rebuilding log history

---

### Search

Requirements:

- plain-text substring search
- case-insensitive
- searches visible message content and metadata
- works together with active filters
- clearing search restores the filtered view

---

### Copy All

Requirements:

- copies the complete stored diagnostic history
- preserves chronological sequence
- includes:
  - timestamp
  - level
  - category
  - message
- independent of current filters

---

### Clear

Requirements:

- removes all stored diagnostic entries
- clears search state
- clears filter state
- affects only diagnostic history
- does not alter repositories
- does not alter runtime stores
- does not alter application state

---

### Runtime Inspector

Requirements:

Runtime Inspector continues to display verified runtime information including:

- provider
- database path
- hydration status
- account count
- transaction count
- latest refresh result

No duplicate runtime state is introduced.

---

### Reusable Diagnostic Controls

Developer Console controls use shared behaviour.

Requirements:

- entire visible control is clickable
- hover behaviour consistent
- focus behaviour consistent
- accessibility behaviour consistent
- disabled appearance consistent
- padding consistent
- corner radius consistent

No Developer Console control responds only to clicks directly on text or icons.

---

### Architecture Integrity

The following remain unchanged:

- parser behaviour
- validation behaviour
- repository contracts
- RepositoryStoreHydrator
- runtime-store ownership
- SQLite schema
- financial calculations
- import workflow
- persistence behaviour

Sprint 31 must remain entirely within the Developer Console and diagnostics experience.

---

## Automated Test Requirements

Add focused deterministic tests covering only Sprint 31 functionality.

Tests shall verify:

### Structured Diagnostic Log

- structured log entries replace plain string storage
- sequence numbers remain unique
- timestamps are assigned
- level is correctly assigned
- category is correctly assigned
- optional metadata remains optional
- existing log ordering remains deterministic

---

### Diagnostic Levels

Verify:

- Debug entries are created correctly
- Info entries are created correctly
- Warning entries are created correctly
- Error entries are created correctly

Verify Debug entries are hidden by default.

Verify enabling Debug immediately reveals existing Debug entries.

---

### Diagnostic Categories

Verify category assignment for:

- Application
- Import
- Parser
- Validation
- Database
- Runtime

Verify category filtering returns only matching entries.

Verify removing category filters restores the complete history.

---

### Import Lifecycle

Verify successful imports produce concise lifecycle events.

Verify default logging contains lifecycle milestones only.

Verify parser implementation details appear only when Debug logging is enabled.

Verify lifecycle ordering remains correct.

---

### Log Presentation

Verify:

- newest entries appear first
- sequence numbers remain unchanged
- timestamps remain visible
- long messages remain readable
- presentation order does not modify stored history

---

### Filtering

Verify:

- Level filters operate correctly
- Category filters operate correctly
- combined filters operate correctly
- clearing filters restores all entries
- filtering never mutates stored logs

---

### Search

Verify:

- substring search
- case-insensitive matching
- search operates only on visible filtered entries
- clearing search restores the filtered view
- search never alters stored logs

---

### Copy All

Verify:

- complete diagnostic history is copied
- timestamps included
- levels included
- categories included
- messages included
- copied history preserves chronological sequence regardless of display order

---

### Clear

Verify:

- all diagnostic entries removed
- search reset
- filter reset
- runtime stores unchanged
- repositories unchanged
- application state unchanged

---

### Runtime Inspector

Verify Runtime Inspector continues to display verified runtime information only.

Verify displayed values remain consistent with RepositoryStoreHydrator and runtime stores.

No duplicate runtime state may be introduced.

---

### Reusable Diagnostic Controls

Verify reusable controls provide:

- full visible hit target
- consistent hover state
- consistent disabled appearance
- consistent keyboard focus
- identical accessibility behaviour

Where practical, focused tests should verify shared diagnostic control configuration and action wiring. Full visible hit-target behaviour must be confirmed through manual runtime verification.

---

## Manual Validation

Desktop ChatGPT will perform manual runtime verification.

Verify the following:

### Developer Console

- opens only when Developer Mode is enabled
- layout remains visually consistent
- Runtime Inspector remains accurate
- Repository Summary remains accurate

---

### Structured Logging

Verify:

- lifecycle events are concise
- parser implementation details are hidden by default
- Debug logging reveals parser diagnostics
- timestamps remain readable
- newest events appear at the top
- sequence numbers remain unchanged

---

### Filtering

Verify:

- Level filters
- Category filters
- combined filters
- filter clearing
- search while filters are active

---

### Search

Verify:

- case-insensitive matching
- partial substring matching
- clearing search restores current filtered view

---

### Copy All

Verify copied output includes:

- timestamps
- levels
- categories
- messages

Verify copied output contains the complete stored diagnostic history.

---

### Clear

Verify:

- log history removed
- filters reset
- search reset
- Runtime Inspector unchanged
- Repository Summary unchanged

---

### Import Diagnostics

Import a known statement.

Verify only concise lifecycle events appear in the default log.

Enable Debug.

Verify parser diagnostics become visible.

Disable Debug.

Verify parser diagnostics disappear while lifecycle events remain visible.

---

### Runtime Behaviour

Verify:

- Reload Data continues working
- Database Reset continues working
- Dashboard behaviour unchanged
- Accounts behaviour unchanged
- Transactions behaviour unchanged
- financial calculations unchanged

---

### UI Consistency

Verify all reusable diagnostic controls:

- use the full visible control as the hit target
- maintain consistent hover behaviour
- maintain consistent keyboard focus
- maintain consistent disabled appearance
- remain visually consistent throughout the Developer Console

Desktop ChatGPT will approve Sprint 31 only after successful manual verification.

---

## Deferred

The following diagnostic capabilities are explicitly deferred:

- Import Inspector
- Validation Timeline
- structured per-operation performance metrics
- individual log-entry export
- diagnostic session export
- persistent diagnostic history across launches
- advanced log retention policies
- database browser
- SQL console
- repository explorer
- parser debugger
- duplicate inspector
- memory inspector
- thread inspector
- network inspector

These capabilities are intentionally deferred because they require either additional repository contracts, richer runtime instrumentation or broader architectural decisions beyond Sprint 31.

---

## Explicitly Out of Scope

Sprint 31 must not introduce:

- parser behaviour changes
- validation behaviour changes
- repository contract changes
- database schema changes
- new persistence mechanisms
- financial calculation changes
- import workflow redesign
- account identity changes
- duplicate-detection changes
- new institutions
- new import formats
- Dashboard redesign
- Accounts redesign
- Transactions redesign
- analytics
- budgets
- insights
- salary planning
- investments
- production user-facing diagnostic controls
- third-party logging frameworks

Sprint 31 is strictly a Developer Console diagnostics sprint.

---

## Validation

Before Sprint 31 may be completed, the following must be satisfied:

### Automated Validation

- Xcode diagnostics pass for every modified Swift file that Xcode can resolve.
- Xcode project build passes.
- Xcode-native `RunAllTests` is the authoritative validation.
- Existing test suite continues passing.
- All Sprint 31 focused tests pass.

Do not use CLI `xcodebuild test` as the primary validation path when Xcode-native validation is available.

### Code Review

Before committing:

- inspect the complete Git diff
- verify only approved Sprint 31 files changed
- verify `Project documents/Implementation.md` remains unchanged
- verify no merge markers remain
- verify no whitespace damage remains
- verify no unrelated UI changes were introduced
- verify no architecture drift occurred

### Runtime Validation

Manual runtime verification remains mandatory.

If Codex cannot launch or inspect the running application, it must:

- complete diagnostics
- complete build
- complete automated tests
- clearly report the limitation
- stop before final completion until manual runtime verification is supplied

Runtime evidence must never be fabricated from static inspection.

---

## Stop Conditions

Stop immediately and report without committing if:

- structured logging requires repository contract changes
- structured logging requires schema changes
- parser behaviour must change
- validation behaviour must change
- financial calculations must change
- import workflow semantics must change
- Runtime Inspector behaviour cannot be preserved
- Database Reset behaviour cannot be preserved
- reusable controls require application-wide UI redesign outside Sprint 31
- deterministic testing cannot be achieved
- manual runtime verification exposes incorrect filtering
- manual runtime verification exposes incorrect severity assignment
- manual runtime verification exposes inaccessible controls
- scope expands into deferred capabilities
- scope expands into excluded capabilities

Do not work around architectural boundaries.

Do not begin Sprint 32.

---

## Completion Criteria

Sprint 31 is complete only when all of the following are true.

### Structured Logging

- plain-string logging has been replaced by structured diagnostic entries
- every entry contains:
  - sequence number
  - timestamp
  - level
  - category
  - message
- optional metadata remains supported

---

### Diagnostic Levels

- Debug behaves correctly
- Info behaves correctly
- Warning behaves correctly
- Error behaves correctly
- Debug is hidden by default

---

### Categories

Application

Import

Parser

Validation

Database

Runtime

All categories operate correctly and filtering behaves as expected.

---

### Presentation

- newest entries appear first
- stored sequence numbers remain unchanged
- timestamps remain visible
- lifecycle events are concise
- parser implementation details appear only when Debug is enabled

---

### Filtering

- Level filtering works
- Category filtering works
- combined filtering works
- search works together with filters
- filtering never mutates stored history

---

### Search

- substring search works
- case-insensitive search works
- clearing search restores the filtered view

---

### Copy All

- copies the complete diagnostic history
- includes timestamp
- includes level
- includes category
- includes message
- preserves chronological sequence

---

### Clear

- removes diagnostic history only
- resets filters
- resets search
- leaves runtime state unchanged
- leaves repositories unchanged

---

### Runtime Inspector

- remains accurate
- Repository Summary remains accurate
- Database Reset remains functional
- Reload Data remains functional

---

### Reusable Diagnostic Controls

Developer Console controls:

- use full visible hit targets
- use consistent hover behaviour
- use consistent focus behaviour
- use consistent accessibility behaviour
- use consistent disabled appearance

---

### Architecture Integrity

The following remain unchanged:

- parser
- validation
- repositories
- RepositoryStoreHydrator
- runtime-store ownership
- persistence
- SQLite schema
- financial behaviour

---

### Final Validation

- Xcode diagnostics pass
- Xcode build passes
- Xcode-native RunAllTests passes
- manual runtime verification passes

---

### Documentation

- `PROJECT_STATE.md` updated with verified facts only
- `Codex response.md` replaced with the completed Sprint 31 implementation report

---

### Git

- approved implementation committed
- pushed to `origin/main`
- remote `main` verified using:

```bash
git ls-remote origin refs/heads/main
```

---

Do not archive Sprint 31.

Do not create Sprint 32.

Desktop ChatGPT will review the implementation, approve or reject Sprint 31, record its completed state in `PROJECT_STATE.md`, and prepare Sprint 32 — Financial Identity Engine as the next ACTIVE sprint.
