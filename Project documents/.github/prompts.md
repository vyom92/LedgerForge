# LedgerForge Prompt Template Library

This document contains reusable prompt templates.

Workflow, architecture and engineering rules are defined elsewhere.

Always begin with:

1. `Project documents/Project_Guide.md`
2. `Project documents/PROJECT_STATE.md`
3. `Project documents/Implementation.md`

Read only the ACTIVE sprint.

---

# Planning Prompt

## Objective

<Describe sprint objective>

## Instructions

- Read the required documentation using the Task Routing Guide.
- Analyse only.
- Produce an implementation plan.
- Identify:
  - files to modify
  - files to create
  - risks
  - dependencies
  - validation required
- Output only to:

`Project documents/Codex response.md`

Do not modify source code.

Do not commit.

---

# Implementation Prompt

## Objective

Implement the approved sprint only.

## Instructions

- Read only the ACTIVE sprint.
- Execute only the approved Implementation Prompt.
- Preserve approved architecture.
- Preserve financial truth.
- Build continuously.
- Run required validation.
- Commit.
- Push.
- Update:
  - `Project documents/Codex response.md`
  - `Project documents/PROJECT_STATE.md`

Do not modify `Implementation.md`.

---

# Documentation Sync Prompt

Documentation only.

- No source changes.
- Update only approved documentation.
- Do not modify `Implementation.md`.
- Update `Codex response.md`.
- Update `PROJECT_STATE.md` only if project state changes.

---

# Bug Fix Prompt

Objective:

<Describe bug>

Requirements:

- Smallest possible change.
- Preserve behaviour.
- Build.
- Validate.
- Commit.
- Push.

---

# Refactor Prompt

Objective:

<Describe refactor>

Requirements:

- Preserve behaviour.
- Reduce duplication.
- Improve maintainability.
- No functional changes.

---

# New Institution Prompt

Institution:

<Name>

Requirements:

- Use supplied fixtures only.
- Do not infer layouts.
- Preserve parser behaviour.
- Validate against approved fixtures.

---

# Architecture Review Prompt

Review against:

- Product Vision
- Architecture
- Engineering Standards
- ADRs

Confirm:

- Import pipeline preserved.
- Repository boundaries preserved.
- RepositoryStoreHydrator remains the only persistence-to-runtime boundary.
- No duplicated financial logic.
- No unnecessary coupling.

No code changes.

---

# Regression Prompt

Validate:

- Institution Detection
- Statement Classification
- Parser Selection
- Financial truth
- Validation
- Repository behaviour
- Dashboard behaviour

Output:

PASS / FAIL

---

# Project Guide Verification Prompt

Read:

- `Project_Guide.md`
- `PROJECT_STATE.md`
- ACTIVE sprint only

Produce:

- Documents required
- Files likely to change
- Risks
- Stop condition

No code changes.
