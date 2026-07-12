# ACTIVE SPRINT

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

## Runtime Inspector

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

## Rules

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

Rules:

* no direct SQLite access from Views or ViewModels
* no repository contract redesign
* no schema changes
* no parser changes
* no validation changes
* no import workflow changes
* no financial calculation changes
* reset must be unavailable outside Developer Mode
* destructive actions must require confirmation
* runtime and repository inspectors are read-only

If safe provider replacement cannot be achieved with the current lifecycle, stop and report the blocker instead of deleting an active database file.
