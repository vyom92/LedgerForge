# PROJECT STATE

This document is the permanent, authoritative handoff between development sessions.

It records only verified project state. Temporary planning, implementation notes, build logs and reasoning belong in `Project documents/Codex response.md`.

Principles:
- Facts only.
- Repository-verifiable information only.
- Minimal manual editing.
- Updated only after successful build, required validation, commit, push and tag when applicable.

---

# Sprint 12B

## Objective
Establish approved PDF regression fixtures and verify reader behaviour against deterministic financial baselines.

## Status
Completed

## Outcome
- Approved Axis PDF fixture established.
- Shared financial baseline introduced.
- PDF reader regression suite implemented.
- Build passed.
- Regression tests passed.
- Git tag: `sprint-12b-complete`

---

# Sprint 12C

## Objective
Introduce the deterministic Institution Detection Framework while preserving legacy behaviour.

## Status
Completed

## Outcome
- Institution Detection Framework implemented.
- Legacy detector compatibility preserved.
- Axis CSV and PDF detection validated.
- Unknown document handling validated.
- 37 tests passed across 9 suites.
- Build passed.
- Git tag: `sprint-12c-complete`

---

# Sprint 13

## Objective
Introduce the deterministic Statement Classification Framework while preserving Institution Detection behaviour and preparing for Parser Selection.

## Status
Completed

## Outcome
- Deterministic Statement Classification Framework implemented.
- Legacy-compatible statement classification mapping preserved.
- Explainable classification reasons added.
- Unknown and non-text document classification validated.
- Statement Classification regression suite added.
- 46 tests passed across 10 suites.
- Build passed.
- Git tag: `sprint-13-complete`

---

# Sprint 14

## Objective
Introduce the deterministic Parser Selection Framework while preserving Statement Classification behaviour and preparing for FinancialDocument Integration.

## Status
Completed

## Outcome
- Deterministic Parser Selection Framework implemented.
- Legacy `StatementParserRegistry` compatibility preserved.
- Axis CSV and PDF parser-selection context validated.
- Unknown institution and unknown statement type handling validated.
- 42 required Sprint 14 regression tests passed through Xcode.
- Build passed.
- Commit: `da117422d47ef9fe6f09fdfe110f88f54182b590`
- Git push to `origin/main` completed successfully.

---

# Sprint 15

## Objective
Introduce FinancialDocument as the canonical immutable handoff after Statement Parser and before Validation.

## Status
Completed

## Outcome
- Immutable FinancialDocument model implemented.
- FinancialDocumentBuilder implemented without financial recalculation.
- ImportValidator gained a FinancialDocument validation entry point that delegates to transaction validation.
- ImportEngine now validates through FinancialDocument after parser execution.
- Existing parser extraction, validation, repository, store and UI behaviour preserved.
- 46 required Sprint 15 regression tests passed through Xcode.
- Build passed.
- Commit: `29c50a9970e74396a7d9be4391efea59b77df4c9`
- Git push to `origin/main` completed successfully.
- Git tag: `sprint-15-complete`

---

# Sprint 16

## Objective
Migrate StatementParser so every production parser returns FinancialDocument directly instead of [Transaction].

## Status
Completed

## Outcome
- StatementParser now returns FinancialDocument directly.
- AxisBankAccountParser now returns FinancialDocument while preserving existing transaction extraction behaviour.
- ImportEngine now consumes parser-produced FinancialDocument directly.
- FinancialDocumentBuilder was removed after all production and test references were migrated.
- Approved Axis CSV financial truth remains unchanged.
- Existing validation, repository, store and UI behaviour preserved.
- 46 required Sprint 16 regression tests passed through Xcode.
- Build passed.
- Commit: `7013d99e55a5cdcf750cf5ad783a71168d59ee3e`
- Git push to `origin/main` completed successfully.
- Git tag: `sprint-16-complete`

---

# Sprint 17

## Objective
Refine the validation pipeline while preserving the parser-produced FinancialDocument boundary introduced in Sprint 16.

## Status
Completed

## Outcome
- Dedicated ImportValidator regression tests added.
- Empty import validation behaviour verified.
- FinancialDocument validation equivalence to transaction validation verified.
- Valid FinancialDocument validation verified.
- Validation immutability verified.
- ImportValidator production implementation left unchanged because tests exposed no real implementation issue.
- Approved Axis CSV financial truth remains unchanged.
- Existing parser, repository, store and UI behaviour preserved.
- 53 required Sprint 17 regression tests passed through Xcode.
- Build passed.
- Commit: `dcac92a0d8e5078a3014e7ef52af8917f130940d`
- Git push to `origin/main` completed successfully.
- Git tag: `sprint-17-complete`

---

# Sprint 18

## Objective
Clean up repository integration while preserving the parser -> FinancialDocument -> ImportValidator pipeline.

## Status
Completed

## Outcome
- Repository integration cleanup implemented.
- `ImportPersistenceCoordinator` added.
- `ImportPersistenceMapper` added.
- `ImportRepositoryIntegrationTests` added.
- Validation-before-persistence preserved.
- Repository persistence now flows through the approved repository boundary before updating runtime stores.
- Parser, validation, repository semantics, UI behaviour, financial truth and transaction extraction preserved.
- SwiftUI Preview macro blocker resolved using `PreviewProvider` compatibility.
- ADR-022 documents preview compatibility during test builds.
- 60 required Sprint 18 regression tests passed through Xcode.
- Build passed.
- Commit: `9773b72`
- Git push to `origin/main` completed successfully.
- Git tag: `sprint-18`

---

# Sprint 19

## Objective
Build the dashboard foundation using repository-backed runtime store hydration.

## Status
Completed

## Outcome
- Repository-backed runtime store hydration implemented.
- `RepositoryStoreHydrator` added.
- Repository read capabilities extended to support dashboard hydration while preserving existing repository semantics.
- Dashboard startup hydrates runtime stores once per application launch unless explicitly refreshed.
- Existing dashboard panel now shows repository-backed account overview and hydration status.
- `RepositoryStoreHydratorTests` added.
- Repository contract coverage expanded for dashboard reads.
- Parser, validation, repository write semantics, UI flow, financial truth and transaction extraction preserved.
- 65 required Sprint 19 regression tests passed through Xcode.
- Build passed.
- Commit: `65b18f7`
- Git push to `origin/main` completed successfully.
- Git tag: `sprint-19`

---

# Sprint 20

## Objective
Refine the repository-backed dashboard foundation built in Sprint 19 without changing import, parser, validation or repository semantics.

## Status
Completed

## Outcome
- Dashboard presentation state refined for loading, empty, loaded and failed hydration outcomes.
- `DashboardViewModel` now exposes store-derived account summaries and recent transaction summaries.
- `ContentView` now consumes dashboard presentation state from `DashboardViewModel` while remaining the startup hydration trigger.
- `DashboardViewModelTests` added.
- Existing transaction search and credit/debit toggle behaviour preserved.
- Import, parser, validation, repository semantics, financial truth and transaction extraction preserved.
- 77 active tests passed through Xcode.
- Build passed.
- Commit: `d327576`
- Git push to `origin/main` completed successfully.
- Git tag: `sprint-20`

---

# Sprint 21

## Objective
Implement the frozen Application Shell defined in `UI_UX_v1.0_Frozen.md`.

## Status
Completed

## Outcome
- Tab-based layout replaced with the approved permanent sidebar and top toolbar shell.
- Dashboard remains the default content view.
- Preview moved out of normal navigation and reserved for the future Import Wizard.
- Developer Console moved out of primary navigation and into the Developer section.
- Existing CSV import, repository hydration, runtime stores, dashboard data and transaction viewer behaviour preserved.
- Import, parser, validation, repository write semantics, financial truth and transaction extraction preserved.
- 77 active tests passed through Xcode.
- Build passed.
- Implementation commit: `539e4a5`
- Documentation report commit: `7430224`
- Git push to `origin/main` completed successfully.

---

# Sprint 22

## Objective
Translate the approved UI/UX v1.0 assets into SwiftUI presentation while preserving the existing LedgerForge architecture and data flows.

## Status
Completed

## Outcome
- Deep Indigo application shell translated into SwiftUI.
- Dashboard, Accounts, Transactions, Import Wizard shell, Settings and Developer Console foundation screens implemented from approved assets.
- Reusable UI presentation helpers introduced, including `LFTheme`, `LFPanel` and `LFSearchField`.
- `TransactionListView` restyled while preserving `TransactionListViewModel` search and credit/debit toggle behaviour.
- `DeveloperConsoleView` restyled while preserving `DeveloperConsole.shared` as the read-only message source.
- Import Wizard remains a shell; full multi-step import workflow remains future work.
- Settings and Developer Console controls remain non-mutating unless behaviour already existed.
- No repository, database, validation, parser, import pipeline, CSV import, hydration, financial truth or transaction extraction changes were made.
- Baseline build passed.
- Post-implementation build passed.
- Focused dashboard/hydrator validation passed: 7 tests, 0 failures.
- Full active validation passed: 77 tests, 0 failures.
- Checkpoint commit: `b7013c6`
- Implementation commit: `eb5e5ee`
- Git push to `origin/main` completed successfully.

---

# Sprint 23

## Objective
Extract reusable SwiftUI presentation components from the Sprint 22 interface while preserving the approved UI/UX v1.0 appearance, existing behavior and architecture.

## Status
Completed

## Outcome
- Shared SwiftUI presentation primitives extracted under `Views/Common`.
- `LFTheme`, `LFPanel`, `LFSearchField`, `LFStatusBadge`, `LFFilterChip`, `LFInfoRow`, `LFEmptyState`, `LFCompactEmptyState`, `LFIconTile`, `LFActionRow` and `LFInlineBadge` introduced as reusable components.
- Generic reusable component definitions removed from `ContentView.swift`.
- Duplicated filter, status badge, info row and empty-state helpers removed from `TransactionListView.swift` and `DeveloperConsoleView.swift` where exact visual equivalence was safe.
- `ContentView` remains the application composition root and startup hydration coordinator.
- Developer Console default visibility corrected so it is hidden until Developer Mode is enabled.
- Existing transaction search and credit/debit toggle behavior preserved.
- Import, parser, validation, repository, database, runtime store, ViewModel, financial truth and transaction extraction behavior preserved.
- Xcode-safe project tooling used for new Swift file target membership.
- Focused dashboard/hydrator validation passed: 7 tests, 0 failures.
- Full active validation passed: 77 tests, 0 failures.
- Build passed.
- Implementation commit: `8090de4`
- Git push to `origin/main` completed successfully.
---

# Sprint 24

## Objective
Stabilise LedgerForge after Sprint 23 by resolving verified persistence and user-interface behaviour defects without introducing unrelated functionality.

## Status
Completed

## Outcome
- Production startup now configures durable SQLite persistence through `DatabaseProvider.shared`.
- In-memory repository providers remain available for tests.
- Import persistence still writes through `DefaultImportPersistenceCoordinator`.
- Startup and post-import runtime restoration still flow through `RepositoryStoreHydrator`.
- Import completion now displays success/failure state, imported filename, transaction count and `View Transactions`.
- Sidebar rows and Credit/Debit controls now use full visible hit targets.
- Duplicate fake macOS traffic-light controls were removed.
- Placeholder controls now display pending state instead of active menu/action affordances where functionality is not implemented.
- Account display names no longer use raw `.csv` filenames when institution/currency metadata is available.
- Stable repository account identity was preserved.
- No parser, validation, financial calculation, database schema, PDF, OCR or navigation architecture changes were made.
- Xcode build passed.
- Active Xcode test plan passed: 84 tests, 0 failures.
- Implementation commit: `37918c9`

---

# Current Project State

## Repository
- Primary Branch: `main`
- Latest Commit: `37918c9`
- Latest Implementation Commit: `37918c9`
- Latest Tag: `sprint-21`
- Latest ADR: ADR-023 — Frozen UI/UX Architecture
- Architecture Baseline: Sprint 24 plus UI/UX v1.0 Frozen
- Latest Milestone: Persistence and UI Behaviour Stabilisation
- Build: Passing
- Validation: Build passing; full active validation passing. Sprint 24 validation complete.

## Session Startup Order
1. Project documents/.github/AGENTS.md
2. Project_Guide.md
3. PROJECT_STATE.md
4. Latest ADR (currently ADR-023 — Frozen UI/UX Architecture)
5. Project documents/Codex response.md

## Current Pipeline
Import Pipeline:

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
Repositories
↓
SQLite
↓
RepositoryStoreHydrator
↓
Runtime Stores
↓
Dashboard


## Current Work

Active Work: Sprint 24 complete; next work must be taken from the ACTIVE sprint in `Project documents/Implementation.md`.

Objective:
- Stop at the approved Sprint 24 boundary after persistence and UI behaviour stabilisation.

Scope:
- `Implementation.md` is the ChatGPT-owned sprint planning and workflow document.
- `Codex response.md` is the Codex-owned latest planning/execution output.
- `PROJECT_STATE.md` is the Codex-owned current repository truth.
- Only the ACTIVE sprint block in `Implementation.md` should be read by Codex.
- Archived sprint blocks in `Implementation.md` are historical reference only.
- Approved UI assets live under `Project documents/UI Assets/Approved/`.
- `DesignBoard_v2.0.png` is the master UI reference.
- Individual approved assets define screen-level implementation details.
- `AppIcon_v1.0.png` is the approved app icon reference.
- `Project documents/.github/` is the canonical location for AI workflow prompt and context files.
- Preserve RepositoryStoreHydrator → Runtime Stores → ViewModels → Views.
- Preserve import, parser, validation and repository semantics.
- Preserve transaction search and credit/debit toggle behaviour.
- Preserve the approved UI/UX v1.0 appearance.
- Preserve durable SQLite startup persistence wiring.

Out of Scope:
- PDF support
- OCR
- Parser changes
- Validation redesign
- Repository redesign
- Database schema changes
- Transaction extraction changes
- Analytics
- Budgets
- Insights
- Reports
- Multi-currency
- Investments

Next Major Milestone:
- Next ACTIVE sprint in `Project documents/Implementation.md`.
