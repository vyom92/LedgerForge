# Codex Response

## Sprint 19 Planning Report — Dashboard Foundation

This is a planning-only report. No source code, tests or project settings were modified.

## Documents Loaded

- `.github/AGENTS.md`: required sprint workflow and boundary rules.
- `Project documents/Project_Guide.md`: canonical routing, current Sprint 19 state and architecture rules.
- `Project documents/PROJECT_STATE.md`: verified Sprint 18 repository state and active Sprint 19 scope.
- `Project documents/Codex response.md`: current sprint baseline before replacing it with this plan.
- `Project documents/Product Vision.md`: dashboard-first product goals and repository-backed dashboard requirement.
- `Project documents/Architecture_v1.0_Frozen.md`: approved pipeline and M7 Dashboard Experience boundary.
- `Project documents/ADR.md`: dashboard-first, store ownership, validation-before-persistence and repository-boundary decisions.
- `Project documents/Engineering Standards.md`: UI/view model/store responsibilities and implementation workflow.

## Current Architecture Review

Approved pipeline:

```text
ImportCoordinator
↓
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
Repository Persistence
↓
Runtime Stores
↓
ViewModels
↓
Dashboard
```

Sprint 18 established repository persistence after validation. Runtime stores are still updated after validated imports, and the dashboard currently observes those stores.

Sprint 19 should add repository-backed startup hydration so the dashboard can show previously persisted trusted data after app launch. This should not alter import parsing, validation, repository semantics or persistence writes.

No architecture conflict was found. The planned work fits ADR-009 store ownership, ADR-010 validation-before-persistence and the Sprint 18 repository boundary.

## Existing Dashboard, ViewModels And Stores

Existing dashboard/UI surfaces:

- `ContentView.swift`
  - Owns the current app layout.
  - Shows a left-panel `Financial Snapshot`.
  - Owns file import UI.
  - Hosts tabs for preview, transactions and developer console.
- `Views/TransactionListView.swift`
  - Displays transactions from `TransactionListViewModel`.
  - Provides search and credit/debit filtering.
- `Views/DocumentPreviewView.swift`
  - Displays `DocumentStore` rows.
- `Views/DeveloperConsoleView.swift`
  - Displays developer log messages.

Existing view models:

- `ViewModels/DashboardViewModel.swift`
  - Observes `TransactionStore.shared` and `AccountStore.shared`.
  - Computes net worth, income, expenses and cash flow from runtime transactions.
  - Publishes accounts from `AccountStore`.
- `ViewModels/TransactionListViewModel.swift`
  - Observes `TransactionStore.shared`.
  - Publishes transactions, validation state and validation issues.
  - Handles table search/filter state.

Existing runtime stores:

- `Core/TransactionStore.swift`
  - Owns observable runtime transactions.
  - Can replace all transactions after successful import.
  - Stores last validation result.
- `Core/AccountStore.swift`
  - Owns observable runtime accounts.
  - Can create/update accounts from import sessions.
  - Lacks a direct repository-hydration replacement API.
- `Core/DocumentStore.swift`
  - Owns current document preview rows and parsed transaction preview state.

## Repository API Review

Existing repository protocols:

- `WorkspaceRepository`
  - `upsertWorkspace(_:)`
  - `workspace(id:)`
- `AccountRepository`
  - `upsertAccount(_:)`
  - `account(id:)`
- `TransactionRepository`
  - `replaceTransactions(workspaceId:importSessionId:transactions:)`
  - `transactions(workspaceId:importSessionId:)`
- `ImportSessionRepository`
  - create/update/read individual import sessions.

Dashboard startup needs:

- Read all dashboard accounts for a workspace.
- Read trusted dashboard transactions for a workspace.
- Convert repository DTOs into runtime `Account` and `Transaction` models.
- Hydrate runtime stores without recalculating financial truth.

Missing or ambiguous repository APIs:

- `AccountRepository` lacks `accounts(workspaceId:)`.
- `TransactionRepository.transactions(workspaceId: importSessionId: nil)` can return workspace transactions, but its trusted-dashboard semantics are implicit. Sprint 19 should prefer reusing existing repository contracts where practical. A new API should only be introduced if the existing workspace query cannot express the required behaviour cleanly.

## Proposed Repository Flow

```text
App launch / ContentView task
↓
RepositoryStoreHydrator
↓
DatabaseProvider.shared
↓
AccountRepository.accounts(workspaceId:)
TransactionRepository.trustedTransactions(workspaceId:)
↓
DTO → runtime model mapping
↓
AccountStore.replaceAccounts(...)
TransactionStore.replaceTransactions(...)
↓
DashboardViewModel observes refreshed stores
↓
Dashboard renders persisted trusted state
```

Repository reads must remain read-only. No dashboard code should access SQLite directly.

## Runtime Store Flow

Current runtime flow:

```text
Successful import
↓
Repository persistence
↓
TransactionStore.replaceTransactions(...)
AccountStore.integrateImport(...)
↓
DashboardViewModel / TransactionListViewModel
```

Sprint 19 startup flow:

```text
App startup
↓
Repository-backed dashboard loader
  (hydration should occur exactly once during startup unless the user explicitly refreshes persisted data)
↓
AccountStore.replaceAccounts(...)
TransactionStore.replaceTransactions(...)
↓
Existing view models update through published store state
```

Store additions should be minimal:

- Add `AccountStore.replaceAccounts(_:)` for repository hydration.
- Reuse `TransactionStore.replaceTransactions(_:)` for hydrated trusted transactions.
- Do not make views or view models call SQLite.

## UI Flow

Sprint 19 UI should be a foundation pass, not a dashboard redesign.

Allowed UI changes:

- Add a dashboard startup loading/error state if repository hydration is asynchronous.
- Show repository-backed accounts in the existing dashboard area or a small account summary section.
- Keep existing import button, preview tab, transaction tab and console tab behaviour.
- Keep current transaction list behaviour.

Out of Sprint 19 UI scope:

- Full dashboard redesign.
- Analytics charts.
- Budget views.
- Multi-currency conversion.
- Investment panels.
- Search/filter overhaul beyond existing transaction list behaviour.

## Files Expected To Change

Likely source files:

- `Database/Repository.swift`
  - Add read-only dashboard retrieval protocol methods if chosen.
- `Database/InMemoryRepositoryProvider.swift`
  - Implement new read-only repository methods.
- `Database/SQLiteRepositoryProvider.swift`
  - Implement matching SQLite read queries.
- `Core/AccountStore.swift`
  - Add repository hydration replacement method.
- `Services/RepositoryStoreHydrator.swift`
  - New service to read repository DTOs and hydrate runtime stores.
- `ViewModels/DashboardViewModel.swift`
  - Add loading/error state only if needed for dashboard startup.
- `ContentView.swift`
  - Trigger startup hydration and display foundation dashboard state.

Likely test files:

- `LedgerForgeTests/RepositoryContractTests.swift`
  - Cover account list and trusted transaction read parity across InMemory and SQLite providers if new repository APIs are added.
- New `LedgerForgeTests/DashboardRepositoryLoaderTests.swift`
  - Verify repository DTOs hydrate runtime stores and trusted filtering is respected.
- Existing regression suites should remain green:
  - `ImportRepositoryIntegrationTests`
  - `RepositoryContractTests`
  - `ImportValidatorTests`
  - `CSVImportRegressionTests`
  - parser/classification/institution/PDF/import framework suites.

Project settings:

- Add any new Swift/test files to Xcode navigator and correct target membership.

## Recommended Implementation Order

1. Add repository read coverage first.
   - Objective: make existing repository state queryable for dashboard startup.
   - Completion: repository-backed startup can retrieve the approved dashboard data while preserving existing repository semantics.

2. Add DTO-to-runtime mapping in a dedicated service.
   - Objective: keep mapping out of Views and ViewModels.
   - Completion: persisted `AccountDTO` and trusted `TransactionDTO` map deterministically to `Account` and `Transaction`.

3. Add runtime store hydration.
   - Objective: allow repository-backed startup state to replace in-memory empty state.
   - Completion: `AccountStore` and `TransactionStore` can be populated from repository reads without changing import behaviour.

4. Wire startup hydration.
   - Objective: app launch refreshes stores from repositories before or during dashboard display.
   - Completion: `ContentView` or app-level startup calls the loader once and view models update through stores.

5. Add minimal dashboard UI foundation.
   - Objective: expose repository-backed account/snapshot state without redesign.
   - Completion: dashboard shows persisted trusted state after restart/hydration and existing import workflows remain observable.

6. Run validation.
   - Build.
   - Dashboard loader tests.
   - Repository contract tests.
   - Sprint 18 regression baseline.

## Regression Risks

- Accidentally showing untrusted transactions on the dashboard.
- Introducing SQLite access into Views or ViewModels.
- Duplicating runtime store ownership in a dashboard-specific model.
- Changing import-time store updates while adding startup hydration.
- Expanding repository APIs beyond read-only dashboard needs.
- Mapping minor-unit `TransactionDTO` values back to `Decimal` incorrectly.
- Losing account identity or account balances when hydrating from repository DTOs.
- Startup hydration running multiple times and duplicating runtime state.

## Architecture Guardrails

Sprint 19 must not redesign:

- parser behaviour
- validation behaviour
- repository write semantics
- persistence schema
- `FinancialDocument`
- import pipeline
- transaction extraction

Dashboard data must come from repository-backed runtime stores, not direct parser output or direct SQLite queries.

## Acceptance Criteria

Sprint 19 implementation is complete when:

- Dashboard startup can hydrate runtime stores from repository-backed data.
- Only trusted validated transactions are visible to dashboard calculations.
- Existing import flow still persists validated imports before runtime store updates.
- Views and ViewModels do not access SQLite directly.
- Repository changes, if any, are read-only and covered for both InMemory and SQLite providers.
- Existing Sprint 18 validation baseline remains green.
- No parser, validation, persistence-write, financial truth or transaction extraction behaviour changes are introduced.
- Startup hydration executes exactly once per application launch unless an explicit user refresh is requested.
