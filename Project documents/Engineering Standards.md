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
- Application workflows.
- Legacy application workflows.
- Legacy import orchestration during migration to the Unified Import Framework.

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

Normalizers/
- Convert RawDocument into the FinancialDocument domain model.
- Ensure every supported file format converges into the same ingestion pipeline.

Parsers/
- Convert normalized data into LedgerForge models.

Database/
- Persistence only.

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

Before implementation:

1. Read Project_Guide.md.
2. Use the Task Routing Guide.
3. Open only the required reference documents.
4. Verify required reference documents exist.
5. Produce an implementation plan.
6. Wait for approval.

Implementation:

1. Select exactly one file.
2. Verify the filename in the header comment matches the intended file.
3. Implement one logical change.
4. Build.
5. Run the required sprint tests.
6. Verify `git status` contains only sprint-related changes.
7. Verify there are no unresolved merge conflict markers.
8. Generate a concise commit message describing the completed work.
9. Commit.
10. Push to `origin/main`.
11. Move to the next file.

# Definition of Done

A task is complete only when:

- The project builds successfully.
- Required sprint tests pass.
- No unresolved merge conflict markers exist.
- The completed sprint has been committed.
- The completed sprint has been pushed to `origin/main`.
- Existing functionality still works.
- The feature has been manually verified.
- Approved reference fixtures continue producing identical financial truth.
- Documentation is updated if architecture changed.
- The implementation follows Product Vision and Architecture.

---

# Architecture Rules

Readers extract data.
FinancialDocument is the common ingestion model.
Institution Detection identifies the source.
Document Classification determines the document family.
Parser Selection chooses the correct parser.
Statement Parsers create business objects.
Validation verifies financial correctness.
TransactionStore owns transactions.
AccountStore owns accounts.
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
- Never invent financial rules.
- Verify the filename in the header comment before editing.
- Build after every significant change.
- Never commit if the build or required tests fail.
- Verify only sprint-related files are staged before committing.
- Generate commit messages from completed work rather than generic templates.
- Report the commit hash after every successful automated commit.
- Resolve compile errors before continuing.
- Run regression tests whenever parser or import code changes.
- Verify approved CSV/PDF reference fixtures before merging reader or parser changes.
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
