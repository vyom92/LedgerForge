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
- Implementation commit: `abbef6f`

---

# Sprint 25

## Objective
Strengthen account identity foundations by persisting institution attribution, preserving stable repository account IDs, preventing duplicate accounts for the current stable identity path and preparing the import pipeline for future format processing.

## Status
Completed

## Outcome
- Known import institutions now persist through `AccountDTO.institutionId`.
- SQLite account upserts now ensure referenced institution rows exist before storing attributed accounts.
- Repository account IDs remain unchanged and continue to use the existing stable ID components.
- Account display names remain metadata-driven and do not participate in matching.
- Restart hydration now restores account institution and transaction source bank from repository data.
- Repeat imports using the same current stable identity do not create duplicate repository accounts.
- ImportEngine now separates current CSV format processing from orchestration while preserving CSV analyzer, normalizer, parser selection, validation and persistence behavior.
- No automatic account matching, verified-identifier matching service, PDF parsing, OCR, Import Wizard implementation, category engine, rules engine or database schema change was introduced.
- TransactionListViewModel now initializes from the current runtime-store snapshot, preserving search/filter behavior and stabilizing full-suite validation against shared-store timing.
- Xcode build passed.
- Active Xcode test plan passed: 86 tests, 0 failures.
- Implementation commit: `9424d5a`
- Git push to `origin/main` completed successfully.
- Local tracking ref note: remote push succeeded; sandbox could not update local `origin/main` ref lock under `.git`.

---

# Sprint 26

## Objective
Align repository documentation to the approved Context_Manifest.yaml bootstrap, fix stale references and ensure a clean, fast startup path for assistants without changing source code.

## Status
Completed

## Outcome
- Documentation bootstrap and workflow alignment completed.
- Root `AGENTS.md` confirmed as the authoritative AGENTS path.
- Active documentation aligned through ADR-025.
- Sprint 25 remains the verified implementation baseline.
- Build status remains the last verified Sprint 25 build status.
- Test status remains the last verified Sprint 25 result: 86 tests, 0 failures.
- No source code, tests, project files, database files or assets changed during Sprint 26.
- Documentation alignment commit: `70a8cc1`
- Git push to `origin/main` completed successfully.
- Local tracking ref note: remote push succeeded; sandbox could not update local `origin/main` ref lock under `.git`.
- Await the next ACTIVE sprint in `Project documents/Implementation.md`.

---

# Sprint 27

## Objective
Make import outcomes explicit in the existing import result panel by showing verified validation and persistence states without changing the import pipeline, financial behaviour or repository architecture.

## Status
Completed

## Outcome
- Import Outcome Visibility implemented in the existing import result panel.
- Successful imports show filename, transaction count, Validation Passed, Persistence Succeeded and View Transactions.
- Validation failures show filename, transaction count where available, Validation Failed, Not Persisted and the existing error message.
- Persistence failures show filename, transaction count, Validation Passed, Persistence Failed and the existing error message.
- View Transactions is available only after successful validation and persistence.
- Existing import execution, validation-before-persistence, repository boundaries and post-import hydration behaviour preserved.
- Focused import outcome presentation coverage added.
- Xcode build passed.
- Active Xcode test plan passed: 89 tests, 0 failures.
- Implementation commit: `152ad12`
- Git push to `origin/main` completed successfully.
- Local tracking ref note: remote push succeeded; sandbox could not update local `origin/main` ref lock under `.git`.

---

# Current Project State

## Repository

* Primary Branch: main
* Latest Implementation Commit: 152ad12
* Latest Tag: sprint-21
* Sprint 26 Documentation Alignment Commit: 70a8cc1
* Latest ADR: ADR-025 — Stable Financial Entity Identity
* Architecture Baseline: Sprint 27 / UI_UX v1.0 Frozen
* Current Milestone: M7 — Dashboard Experience
* Current Sprint: Sprint 27 — Import Outcome Visibility completed; awaiting review
* Current Phase: Sprint 27 implementation complete
* Build Status: Passing
* Validation Status: Sprint 27 active Xcode test plan passed (89 tests, 0 failures)

## Bootstrap

The authoritative bootstrap order is defined in:

Project documents/.github/Context_Manifest.yaml

Approved bootstrap order:

1. Project documents/.github/Context_Manifest.yaml
2. AGENTS.md
3. Project documents/Project_Guide.md
4. Project documents/PROJECT_STATE.md
5. Project documents/Implementation.md — ACTIVE sprint only

Additional documentation is loaded only when required by the Task Routing Guide.

## Current Pipeline

ImportCoordinator
↓
PasswordProvider
↓
ReaderRegistry
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
Fingerprinting & Duplicate Detection
↓
Repository Persistence Boundary
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


## Current Work

Active Work: Sprint 27 — Import Outcome Visibility completed; await review, archival and the next ACTIVE sprint in `Project documents/Implementation.md`.

Objective:

* Import result panel now exposes validation and persistence outcomes from `ImportEngineResult`.
* View Transactions is gated to successfully persisted imports.
* Existing import execution and post-import hydration behaviour preserved.

Scope:

* Sprint 27 was a UI presentation sprint.
* No parser, reader, validation, repository, runtime store, SQLite or financial logic changes were made.
* `Project documents/Implementation.md` is the Desktop ChatGPT-owned sprint planning and workflow document.
* Codex must never edit `Project documents/Implementation.md`.
* `Project documents/Codex response.md` records the latest planning or execution report produced by the executing assistant.
* `Project documents/PROJECT_STATE.md` records verified repository facts only.
* `Project documents/.github/Context_Manifest.yaml` is the bootstrap manifest and routing document, not a repository state database.
* Only the ACTIVE sprint block in `Project documents/Implementation.md` should be read during sprint execution.
* Archived sprint blocks in `Project documents/Implementation.md` are historical reference only.
* Preserve RepositoryStoreHydrator → Runtime Stores → ViewModels → Views.
* Preserve import, parser, validation and repository semantics.
* Preserve transaction search and credit/debit toggle behaviour.
* Preserve the approved UI/UX v1.0 appearance.
* Preserve durable SQLite startup persistence wiring.
* Preserve stable repository account identifiers.
* Preserve institution attribution through repository hydration.

Out of Scope:

* PDF support
* OCR
* Parser behaviour changes
* Validation redesign
* Repository redesign
* Database schema changes
* Automatic account matching
* Concrete verified-identifier matching service
* Import Wizard implementation
* Transaction extraction changes
* Analytics
* Budgets
* Insights
* Reports
* Multi-currency
* Investments

Next Major Milestone:

* Desktop ChatGPT review of Sprint 27, archival and preparation of the next ACTIVE sprint in `Project documents/Implementation.md`.
