# LedgerForge Prompt Template Library

This document contains reusable prompt templates.

Workflow, architecture, document authority and engineering rules are defined by the project documentation.

---

# Mandatory Bootstrap

Always begin with:

1. `Project documents/.github/Context_Manifest.yaml`
2. `AGENTS.md`
3. `Project documents/Project_Guide.md`
4. `Project documents/PROJECT_STATE.md`
5. `Project documents/Implementation.md` (ACTIVE sprint only)

Then read only the additional documentation required by the Task Routing Guide.

Never read archived sprint sections unless explicitly requested.

---

# Planning Prompt

## Objective

<Describe the ACTIVE sprint objective exactly as defined in `Project documents/Implementation.md`.>

## Bootstrap

Always read in this order:

1. `Project documents/.github/Context_Manifest.yaml`
2. `AGENTS.md`
3. `Project documents/Project_Guide.md`
4. `Project documents/PROJECT_STATE.md`
5. `Project documents/Implementation.md` (ACTIVE sprint only)

Then load only the additional documentation required by the Task Routing Guide.

## Instructions

- Analyse only.
- Do not modify source code.
- Do not modify tests.
- Do not modify `Project documents/Implementation.md`.
- Do not commit.
- Do not push.
- Keep planning strictly within the ACTIVE sprint.
- Preserve approved architecture, ADRs, database design and workflow.
- Identify only the files required for the approved sprint.

## Deliverables

Output only to:

`Project documents/Codex response.md`

Include:

- Files to modify
- Files to create (if any)
- Risks
- Dependencies
- Validation required
- Files that must remain untouched
- Stop condition

---

# Implementation Prompt

## Objective

Implement the approved ACTIVE sprint only.

## Instructions

- Read only the ACTIVE sprint.
- Execute only the approved Implementation Prompt.
- Preserve approved architecture.
- Preserve financial truth.
- Keep changes inside the approved sprint boundary.
- Build continuously.
- Run required validation.
- Commit only after successful validation.
- Push only after a successful commit.
- Update:
  - `Project documents/Codex response.md`
  - `Project documents/PROJECT_STATE.md` (only after successful validation)

Never modify `Project documents/Implementation.md`.

---

# Documentation Sync Prompt

Documentation only.

Requirements:

- No source changes.
- No test changes.
- Update only approved documentation.
- Never modify `Project documents/Implementation.md`.
- Update `Project documents/Codex response.md`.
- Update `Project documents/PROJECT_STATE.md` only when verified repository facts change.
- Present documentation changes for review before committing unless explicitly instructed otherwise.

---

# Bug Fix Prompt

## Objective

<Describe bug>

## Requirements

- Smallest possible change.
- Preserve behaviour.
- Build.
- Validate.
- Commit.
- Push.

---

# Refactor Prompt

## Objective

<Describe refactor>

## Requirements

- Preserve behaviour.
- Reduce duplication.
- Improve maintainability.
- No functional changes.
- Maintain architectural boundaries.

---

# New Institution Prompt

## Institution

<Name>

## Requirements

- Use supplied fixtures only.
- Do not infer layouts.
- Preserve parser behaviour.
- Validate against approved fixtures.
- Do not affect existing institution behaviour.

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
- No workflow drift.

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

- `Project documents/.github/Context_Manifest.yaml`
- `Project_Guide.md`
- `PROJECT_STATE.md`
- `Implementation.md` (ACTIVE sprint only)

Produce:

- Documents required
- Files likely to change
- Risks
- Validation required
- Stop condition

No code changes.
