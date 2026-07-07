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

# Current Project State

## Repository
- Primary Branch: `main`
- Latest Commit: `65b18f7`
- Latest Tag: `sprint-19`
- Latest ADR: ADR-022 — Preview Compatibility During Test Builds
- Architecture Baseline: Sprint 19
- Latest Milestone: Dashboard Foundation (Phase 1)
- Build: Passing
- Validation: Build passing; full regression baseline passing. Sprint 19 validation complete.

## Session Startup Order
1. AGENTS.md
2. Project_Guide.md
3. PROJECT_STATE.md
4. Latest ADR (currently ADR-022 — Preview Compatibility During Test Builds)
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
Runtime Stores
↓
Dashboard

## Current Work

Active Sprint: Sprint 20

Objective:
- Dashboard Foundation continuation.

Scope:
- Planning required before implementation.
- Preserve validated import, persistence and repository boundaries from Sprint 19.
- Dashboard work must consume repository-backed data rather than bypass repository boundaries.
- Startup hydration must remain deterministic and execute exactly once per application launch unless an explicit refresh is requested.

Out of Scope:
- Transaction extraction changes
- Import pipeline changes
- UI changes
- OCR
- AI inference
- Validation redesign
- Repository redesign
- Multi-currency
- Investments
