# =======ACTIVE SPRINT==========

## Sprint 30 — Developer Console Foundation

### Status

🟢 Ready for Implementation

### Objective

Expand the existing Developer Console into a safe internal testing and diagnosis surface for database reset, runtime inspection, repository summary, log management and canonical data reload.

Sprint 30 is Developer Mode only. It must not introduce new end-user financial features or alter parser, validation, import, repository, schema or financial semantics.

## User Outcome

During development, the user can reset LedgerForge to a clean financial state, inspect the current runtime state, reload repository-backed data and manage diagnostic logs without using Terminal, Finder or a separate SQLite browser.

## Scope

### 1. Development Database Reset

Add a visibly destructive `Reset Development Database` control inside the Developer Console.

Requirements:

- visible only when Developer Mode is enabled
- styled as destructive/red
- protected by an explicit confirmation dialog
- confirmation explains that all imported financial data and import history will be permanently removed
- action preserves application preferences, appearance, Developer Mode and other non-financial settings
- action completes without an application restart

Approved reset strategy:

- create a fresh SQLite repository provider at a new development database path
- replace `DatabaseProvider.shared` with the fresh provider
- force canonical repository hydration using `RepositoryStoreHydrator.hydrateIfNeeded(forceRefresh: true)`
- clear repository-backed runtime state through the hydration path
- refresh Dashboard presentation into the empty state
- do not delete the active SQLite file while connections may still be open
- do not introduce direct SQL table deletion from Views or ViewModels

After reset, verify:

- accounts = 0
- transactions = 0
- Dashboard shows the empty state
- Transactions screen shows the empty state
- Developer Console runtime counts show 0
- no restart is required

### 2. Runtime Inspector

Add a read-only Developer Console panel showing only verified existing state:

- repository/provider type or state
- hydration status
- account count
- transaction count
- latest refresh result or equivalent available hydration result
- current SQLite database path, if safely available from existing provider configuration

Do not create duplicate mutable state solely for the inspector.

### 3. Repository Summary

Show read-only counts for currently supported repository-backed entities:

- Accounts
- Transactions

Do not add document, import-session, category, rule, investment or other counts unless existing repository APIs already expose them safely.

### 4. Log Console Improvements

Improve the existing plain-string log console with:

- text-only substring search
- `Copy All`
- `Clear`

 Rules:

- search must be clearly presented as plain text search
- do not add fake severity or category filters
- `Clear` must use the existing `DeveloperConsole.clear()` behaviour
- `Copy All` must copy the intended complete log text without mutating stored messages

### 5. Runtime Refresh

Add one canonical `Reload Data` action.

Requirements:

- invokes `RepositoryStoreHydrator.hydrateIfNeeded(forceRefresh: true)`
- updates runtime account and transaction state through the existing hydrator path
- updates Runtime Inspector counts and hydration status
- does not create separate per-entity refresh operations

## Expected Files

Likely implementation files:

- `DeveloperConsoleView.swift`
- `DeveloperConsole.swift` only if narrowly required
- current application/provider bootstrap or composition-root file only where provider replacement must be coordinated
- existing SQLite provider file only if a narrow read-only path exposure is required
- focused tests

Documentation after successful implementation:

- `Project documents/PROJECT_STATE.md`
- `Project documents/Codex response.md`

Codex must not modify:

- `Project documents/Implementation.md`

Do not create speculative abstractions or placeholder tools.

## Architecture Constraints

Preserve:

```text
Repository Provider
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

Rules:

- no direct SQLite access from Views or ViewModels
- no repository contract redesign
- no schema changes
- no parser changes
- no validation changes
- no import workflow changes
- no financial calculation changes
- reset must be unavailable outside Developer Mode
- destructive actions must require confirmation
- runtime and repository inspectors are read-only

If safe provider replacement cannot be achieved with the current lifecycle, stop and report the blocker instead of deleting an active database file.

## Acceptance Criteria

### Database Reset

- destructive control is visible only in Developer Mode
- entire visible button rectangle is clickable
- confirmation is required
- confirmation clearly states irreversibility and affected data
- fresh SQLite provider is created safely
- canonical forced hydration runs after provider replacement
- accounts become 0
- transactions become 0
- Dashboard becomes empty
- Transactions screen becomes empty
- Developer Console runtime counts become 0
- application preferences and Developer Mode remain unchanged
- no application restart is required

### Runtime Inspector

- account count is visible and accurate
- transaction count is visible and accurate
- hydration state or result is visible and accurate
- provider/database path is shown only when safely available
- inspector updates after Reset and Reload Data
- inspector is read-only

### Repository Summary

- account and transaction counts reflect repository-backed runtime state
- no unsupported entity counts are shown

### Log Console

- substring search filters displayed messages without changing stored logs
- `Copy All` copies log text
- `Clear` removes stored messages through `DeveloperConsole.clear()`
- no fake severity or category system is introduced

### Reload Data

- uses the existing forced hydration path
- updates account and transaction runtime state
- updates inspector state
- does not duplicate refresh logic

### Integrity

- existing import behaviour remains unchanged
- existing confirmation-gated workflow remains unchanged
- existing Dashboard calculations remain unchanged
- existing repository boundaries remain unchanged
- no schema changes
- no preferences are erased during financial-data reset

---

## Automated Test Requirements

Add focused deterministic tests for:

- reset swaps to a fresh provider and produces zero account and transaction counts
- reset preserves non-financial preferences where testable
- forced hydration after reset reports empty state
- `Reload Data` refreshes runtime counts from repository state
- Runtime Inspector and Repository Summary reflect current store counts
- substring search filters plain-string logs
- `Clear` empties log messages
- `Copy All` produces expected text where logic can be tested without fragile UI automation
- destructive reset cannot be triggered without confirmed action at the presentation or state layer where practical

Use temporary SQLite paths and existing repository-test patterns.

Do not delete or alter the developer's real database during tests.

---

## Manual Validation

Verify in the running application:

1. Enable Developer Mode and open Developer Console.
2. Confirm Runtime Inspector shows current account and transaction counts.
3. Confirm the current SQLite path or provider state is displayed when supported.
4. Use log search, `Copy All` and `Clear`.
5. Import a test statement and confirm counts increase.
6. Select `Reset Development Database`.
7. Confirm the first click only opens the warning dialog.
8. Cancel once and verify nothing changes.
9. Confirm reset on the second attempt.
10. Verify accounts = 0 and transactions = 0.
11. Verify Dashboard and Transactions show empty states.
12. Verify Developer Mode and preferences remain enabled and preserved.
13. Verify no application restart is required.
14. Use `Reload Data` and confirm counts and state remain accurate.

---

## Deferred

- Import Inspector
- Validation Timeline
- structured log categories or severity
- recent import-session browser
- Open Database Folder
- Export SQLite
- database vacuum
- repository rebuild
- balance recalculation
- search reindexing
- Duplicate Inspector

---

## Explicitly Out of Scope

- Feature Flags Viewer
- SQL editor or browser
- performance profiler
- memory or thread inspector
- parser changes
- new institutions or formats
- duplicate-management UI
- password UI
- import workflow redesign
- Dashboard redesign
- analytics
- budgets
- insights
- investments
- database schema changes
- production user-facing reset controls

---

## Validation

Before completion:

- Xcode diagnostics pass for modified files
- Xcode project build passes
- Xcode-native `RunAllTests` is used as the authoritative full test validation
- all existing tests continue passing
- focused Sprint 30 tests pass
- manual runtime verification is recorded honestly
- `Project documents/Implementation.md` remains unchanged
- complete diff is reviewed
- only approved Sprint 30 files are committed
- no merge markers or whitespace damage remain

Do not run CLI `xcodebuild test` first when Xcode-native validation is available.

---

## Stop Conditions

Stop and report without committing if:

- reset requires deleting an actively open SQLite database
- provider replacement cannot be coordinated safely
- schema or repository-contract changes become necessary
- non-financial preferences cannot be preserved
- reset races with an active import or hydration operation and cannot be safely gated
- scope must expand into deferred modules
- deterministic validation cannot be completed

---

## Completion Criteria

Sprint 30 is complete only when:

- Developer Mode exposes the completed Developer Console foundation
- safe database reset works without Terminal or application restart
- reset produces zero accounts and zero transactions
- Dashboard and Transactions return to empty state
- preferences and Developer Mode remain preserved
- Runtime Inspector and Repository Summary display accurate state
- `Reload Data` uses canonical forced hydration
- log search, `Copy All` and `Clear` work
- architecture and financial behaviour remain unchanged
- diagnostics and build pass
- full active test plan passes
- `PROJECT_STATE.md` is updated with verified facts
- `Codex response.md` contains the Sprint 30 implementation report
- approved changes are committed and pushed

Do not archive Sprint 30.

Do not create Sprint 31.

Desktop ChatGPT will review the implementation, approve or reject Sprint 30, archive it and prepare the next ACTIVE sprint.

---

# =======ARCHIVED SPRINTS==========

