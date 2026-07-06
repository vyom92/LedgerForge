# Repository Housekeeping (Post Sprint 11B Architecture Audit)

The six-phase architecture audit identified several repository housekeeping improvements that are intentionally outside Sprint 11B implementation scope.

## Completed

- Added `.gitignore` to prevent generated Xcode build artifacts from being committed.
- Removed tracked build artifacts from Git history going forward.
- Updated `Project_Guide.md` to become the canonical project operating manual.
- Updated AI workflow documentation to use `Project_Guide.md` as the primary routing document.
- Simplified AI onboarding documentation (`AI_WORKFLOW.md`, `AGENTS.md`, `PROJECT.md`, `.github/ai-instructions.md`, `.github/prompts.md`) so they reference `Project_Guide.md` instead of duplicating project policy.
- Completed a six-phase architecture audit covering Repository, UI, Parser, Database, Testing and Documentation.
- Optimised repository documentation for layered AI instructions to reduce context usage.
- Simplified `AGENTS.md` into a lightweight bootstrap document.
- Updated `Project_Guide.md` to become the canonical navigation and routing document.
- Updated prompt templates to use the Task Routing Guide instead of loading all documentation.

## Outstanding Repository Cleanup

- Verify no `build/` directory remains inside the repository.
- Verify no `DerivedData` artifacts remain inside the repository.
- Verify no accidental editor backup directories remain (for example `ContentView.swift~refs`).
- Verify there are no duplicate or malformed documentation filenames.
- Consolidate historical implementation reports under `Project documents/Implementation Reports/`.
- Remove obsolete or duplicated documentation where appropriate.
- Keep `Project_Guide.md` synchronized with sprint completion after every approved sprint.
- Move completed sprint reports into `Project documents/Implementation Reports/` if duplicates still exist.
- Verify `Architecture_v1.0_Frozen.md` has no malformed or duplicate filename.
- Continue reducing duplicated guidance across documentation so each document has a single responsibility.

These items are repository maintenance only and do not change application behaviour.

---

# Architecture Audit Summary (Phase 1–6)

An independent architecture review was completed after Sprint 11B.

## Overall Assessment

| Area | Result |
|-------|--------|
| Repository Structure | ✅ Healthy |
| Import Architecture | 🟢 Strong Foundation |
| Database Layer | 🟢 Production Ready |
| Repository Layer | 🟢 Stable |
| UI Architecture | 🟡 Minor Orchestration Debt |
| Parser Architecture | 🟡 Legacy Migration Pending |
| Documentation | 🟢 Excellent |
| Testing | 🟡 Good Foundation |

## Highest Priority

The next architectural milestone remains Sprint 11C.

Primary objective:

```text
Existing CSV Import

↓

ImportCoordinator

↓

Reader

↓

FinancialDocument

↓

Existing Parser

↓

Validation

↓

Repositories

↓

Stores
```

without changing any user-visible behaviour.

## Recommended Additional Tests

Before or during Sprint 11C:

- Add CSV baseline regression tests.
- Add repository rollback contract tests.
- Add end-to-end import integration tests after CSV migration.
- Execute the three Project Guide Verification Tests before beginning Sprint 11C.
- Verify AI assistants load only the documents identified by the Task Routing Guide.

## Deferred Architectural Improvements

Future improvements identified during the audit include:

- Import progress reporting.
- Import context object.
- Repository mapper separation.
- Multi-currency dashboard refinement.
- Password provider implementation.
- Institution detection framework.
- PDF/XLS/XLSX import support.
- Introduce `ImportViewModel` when the unified import flow reaches the UI.
- Gradually retire legacy import orchestration after successful migration to `ImportCoordinator`.
- Consider archiving historical sprint handoff reports into per-sprint files once the project grows further.

No architectural blockers were identified for Sprint 11C.

---

# Project Guide Verification Tests

These tests validate that AI assistants correctly follow `Project_Guide.md` before implementation.

## Test 1 – Task Routing

Expected behaviour:

- Read `Project_Guide.md`.
- Determine only the documentation required for Sprint 11C.
- Explain why each document is required.
- List documents intentionally skipped.
- Do not generate code.

## Test 2 – Sprint Boundary

Expected behaviour:

- Read `Project_Guide.md`.
- Describe exactly what Sprint 11C is allowed to change.
- List five things Sprint 11C must not change.
- Reference the relevant sections of `Project_Guide.md`.
- Do not generate code.

## Test 3 – Workflow Compliance

Expected behaviour:

- Read `Project_Guide.md`.
- Assume Sprint 11C has been requested.
- Follow the Standard AI Workflow.
- Produce only:
  - Documents to read.
  - Implementation plan.
  - Risks.
  - Files likely to change.
  - Stop condition.
- Do not generate code.

---

# Readiness Assessment

## Repository

✅ Ready for Sprint 11C.

## Architecture

No architectural blockers identified.

## Documentation

Layered documentation structure is established with `Project_Guide.md` as the canonical entry point.

## Remaining Risk

The primary implementation risk is preserving existing CSV import behaviour during migration into the unified import framework. Regression testing should remain the highest priority throughout Sprint 11C.
