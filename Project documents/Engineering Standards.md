# LedgerForge – Engineering Standards

## Purpose

This document defines the engineering principles used throughout LedgerForge. It exists to keep the codebase consistent, maintainable and scalable as the application grows.

---

# Core Rules

## Decision Framework

Before implementing any feature, ask:

1. Does it reduce manual work?
2. Does it increase confidence?
3. Does it surface meaningful financial insight?
4. Does it align with the Product Vision?
5. Can it be explained to the user?

If the answer to all five is "No", do not build it.

1. The project must build successfully after every completed sprint.
2. Prefer small, verifiable commits over large refactors.
2a. Only commit after the project builds successfully and required sprint tests pass.
2b. Before committing, verify there are no unresolved merge conflict markers and only sprint-related files are staged.
2c. Successful sprint work should be pushed to `origin/main` immediately after the commit.
3. New features should integrate with the existing architecture rather than bypass it.
4. Avoid duplicate business logic.
5. Offline-first is the default.
6. Every automatic decision must be explainable.
7. Every imported value must be traceable back to its source.
8. Every monetary value must retain its native currency.
9. Currency conversion is a presentation concern, never a storage concern.
10. Financial calculations must be deterministic and reproducible.
11. Monetary values must be formatted using the correct regional numbering system.

---

# Folder Responsibilities

Views/
- User interface only.
- No parsing or business logic.

Models/
- Domain models.
- No UI code.

Services/
- Application workflow orchestration.
- Import coordination, validation and repository persistence.
- Legacy import orchestration only where migration is still in progress.

Readers/
- Read file formats only.
- Receive optional passwords from the ImportCoordinator.
- Produce RawDocument.
- Extract document contents.
- Never access Keychain.
- Never perform business logic.
- Never interpret financial meaning.

Detectors/
- Detect financial institutions.
- Classify document types.
- Identify parser candidates.

Parsers/
- Produce FinancialDocument.
- Own institution- and layout-specific financial interpretation, including verification of parser-supported financial identifiers.
- Never perform validation.
- Never persist data.

Database/
- Repository implementations and persistence only.

Core/
- Shared application state and infrastructure.

ViewModels/
- Presentation logic only.
- No persistence.
- No parsing.
- Observe application state and prepare data for Views.

---

# Coding Principles

- Prefer composition over duplication.
- Keep functions focused on a single responsibility.
- Avoid hardcoded institution-specific logic when a generic solution exists.
- Use descriptive names rather than abbreviations.
- Minimize force unwrapping.
- Keep UI and business logic separated.
- Prefer domain value types (for example, Money) over primitive values when representing financial concepts.
- Every object should have a single owner.
- Avoid mixing presentation formatting with business logic.

# Error Handling Standards

- Fail early with meaningful errors.
- Never silently discard financial data.
- Prefer validation over assumptions.
- Log unexpected conditions for later diagnosis.
- Every parsing failure should explain what failed and why.

---

# Development Workflow

## Planning

Before implementation:

1. Bootstrap using:
   - `Project documents/.github/Context_Manifest.yaml`
   - `AGENTS.md`
   - `Project documents/Project_Guide.md`
   - `Project documents/PROJECT_STATE.md`
   - `Project documents/Implementation.md` (ACTIVE sprint only)
2. Use the Task Routing Guide to identify any additional documentation required.
3. When selecting the next sprint, review `Project documents/FUTURE_WORK.MD` after verified repository state.
4. Work produces an evidence-backed repository-discovery report in `Project documents/Codex response.md`.
5. Wait for Chat approval and an approved ACTIVE sprint before implementation.
6. Do not modify source code during the planning phase.

## Implementation

1. Read only the approved Implementation Prompt from the ACTIVE sprint.
2. Work only within the approved sprint scope.
3. Select exactly one file at a time.
4. Verify the filename before editing.
5. Implement one logical change.
6. Build.
7. Run the required sprint tests.
8. Verify `git status` contains only sprint-related changes.
9. Verify there are no unresolved merge conflict markers.
10. Generate a concise commit message describing the completed work.
11. Commit.
12. Push to the tracked branch (normally `origin/main`).
13. Push the sprint tag if one was created.
14. Update `Project documents/PROJECT_STATE.md` only after successful validation.
15. Update `Project documents/Codex response.md`.
16. Continue to the next file only after successful validation.
# Definition of Done

A task is complete only when:

- The project builds successfully.
- Required sprint tests pass.
- No unresolved merge conflict markers exist.
- The completed sprint has been committed.
- The completed sprint has been pushed to the tracked branch.
- Sprint tag has been created and pushed (if applicable).
- Existing functionality still works.
- The feature has been manually verified.
- Approved reference fixtures continue producing identical financial truth.
- Documentation is updated if architecture changed.
- `Project documents/PROJECT_STATE.md` reflects the current repository state.
- `Project documents/Codex response.md` records the completed planning or implementation cycle.
- The implementation follows Product Vision and Architecture.

---

# Architecture Rules

Readers extract data.
Institution Detection identifies the source.
Statement Classification determines the document family.
Parser Selection chooses the correct parser.
Statement Parsers produce FinancialDocument.
FinancialDocument is the canonical parser output.
Validation verifies financial correctness.
Repositories persist validated financial data.
Runtime Stores own observable application state.
ViewModels observe stores.
Views never coordinate business workflows.

---

# Quality Standards

Every feature should:
- Reduce manual work, or
- Increase confidence, or
- Surface meaningful financial insight.
- Preserve financial truth.
- Support future financial institutions without architectural changes.
- Remain explainable to the end user.

If it satisfies none of these goals, reconsider whether it belongs in LedgerForge.

---

# Long-Term Philosophy

Optimize for maintainability over cleverness.

Build systems that learn instead of accumulating special cases.

The code should make adding the next financial institution easier than adding the previous one.

---

# Currency Standards

- Preserve native currency.
- Store exchange rates separately from monetary values.
- Never overwrite imported financial values after conversion.
- Support multiple simultaneous display currencies.
- Respect regional formatting conventions for each currency.

---

# AI Development Standards

- Never assume statement layouts.
- Always request reference documents when required.
- Chat owns sprint planning and approval; Work owns explicitly approved repository-wide documentation synchronization; Codex owns approved Swift implementation and implementation Git operations.
- Read only the ACTIVE sprint in `Project documents/Implementation.md`.
- Never modify `Project documents/Implementation.md`.
- Archived sprint sections are historical reference only.
- Never invent financial rules.
- Verify the filename in the header comment before editing.
- Build after every significant change.
- Never commit if the build or required tests fail.
- Verify only sprint-related files are staged before committing.
- Generate commit messages from completed work rather than generic templates.
- Report the commit hash, tag (if created) and push result after every successful automated commit.
- Resolve compile errors before continuing.
- Run regression tests whenever parser or import code changes.
- Verify production-supported fixtures for production claims. Foundation-only fixtures, including the current Axis PDF fixture, validate only the layers explicitly covered by their tests and do not establish end-to-end format support.
- Summarize architectural decisions after every sprint.

---

# Technical Debt Policy

Technical debt should be documented, not ignored.

When shortcuts are necessary:

- Record the reason.
- Record the intended solution.
- Record the expected impact.
- Create a follow-up milestone.

Temporary code should never become permanent architecture.
