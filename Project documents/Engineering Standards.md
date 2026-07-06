# LedgerForge – Engineering Standards

## Purpose

This document defines the engineering principles used throughout LedgerForge. It exists to keep the codebase consistent, maintainable and scalable as the application grows.

---

# Core Rules

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

---

# Development Workflow

1. Select one file.
2. Implement one logical change.
3. Build.
4. Test.
5. Commit.
6. Move to the next file.

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
