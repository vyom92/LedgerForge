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
3. New features should integrate with the existing architecture rather than bypass it.
4. Avoid duplicate business logic.
5. Offline-first is the default.
6. Every automatic decision must be explainable.
7. Every imported value must be traceable back to its source.

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
- Import orchestration.

Readers/
- Read file formats only.

Analyzers/
- Detect document structure.

Detectors/
- Detect institutions, columns and document characteristics.

Normalizers/
- Convert raw data into a consistent intermediate representation.

Parsers/
- Convert normalized data into LedgerForge models.

Database/
- Persistence only.

Core/
- Shared application state and infrastructure.

---

# Coding Principles

- Prefer composition over duplication.
- Keep functions focused on a single responsibility.
- Avoid hardcoded institution-specific logic when a generic solution exists.
- Use descriptive names rather than abbreviations.
- Minimize force unwrapping.
- Keep UI and business logic separated.

# Error Handling Standards

- Fail early with meaningful errors.
- Never silently discard financial data.
- Prefer validation over assumptions.
- Log unexpected conditions for later diagnosis.
- Every parsing failure should explain what failed and why.

---

# Development Workflow

1. Select one file.
2. Implement one logical change.
3. Build.
4. Test.
5. Commit.
6. Move to the next file.

# Definition of Done

A task is complete only when:

- The project builds successfully.
- Existing functionality still works.
- The feature has been manually verified.
- Documentation is updated if architecture changed.
- The implementation follows Product Vision and Architecture.

---

# Architecture Rules

Readers know files.
Analyzers know structure.
Detectors know meaning.
Normalizers create consistency.
Parsers create business objects.
Rules create intelligence.
The Dashboard presents information.

---

# Quality Standards

Every feature should:
- Reduce manual work, or
- Increase confidence, or
- Surface meaningful financial insight.

If it satisfies none of these goals, reconsider whether it belongs in LedgerForge.

---

# Long-Term Philosophy

Optimize for maintainability over cleverness.

Build systems that learn instead of accumulating special cases.

The code should make adding the next financial institution easier than adding the previous one.

---

# Technical Debt Policy

Technical debt should be documented, not ignored.

When shortcuts are necessary:

- Record the reason.
- Record the intended solution.
- Record the expected impact.
- Create a follow-up milestone.

Temporary code should never become permanent architecture.
