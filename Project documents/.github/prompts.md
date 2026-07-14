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

For sprint selection or backlog work, read `Project documents/FUTURE_WORK.MD` after verified repository state. Do not load it for routine implementation when the ACTIVE sprint is already defined.

---

# Planning Prompt

MODE: Work
MODEL: <Approved Work model>
REASONING: <Approved reasoning level>
PURPOSE: Perform evidence-backed repository discovery for Chat to use when planning the next ACTIVE sprint.

## Objective

<Describe the approved repository-discovery question. Chat, not Work, defines the ACTIVE sprint.>

## Bootstrap

Always read in this order:

1. `Project documents/.github/Context_Manifest.yaml`
2. `AGENTS.md`
3. `Project documents/Project_Guide.md`
4. `Project documents/PROJECT_STATE.md`
5. `Project documents/FUTURE_WORK.MD` when selecting or checking unscheduled work
6. `Project documents/Implementation.md` (ACTIVE sprint only, if defined)

Then load only the additional documentation required by the Task Routing Guide.

## Instructions

- Analyse only.
- Do not modify source code.
- Do not modify tests.
- Do not modify `Project documents/Implementation.md`.
- Do not commit.
- Do not push.
- Keep discovery strictly within the approved question and task boundary.
- Do not define or schedule the next sprint; report verified evidence for Chat.
- Preserve approved architecture, ADRs, database design and workflow.
- Identify only the files required by the approved discovery or sprint scope.

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

MODE: Codex
MODEL: <Approved Codex model>
REASONING: <Approved reasoning level>
PURPOSE: Implement and validate the approved ACTIVE sprint without expanding scope.

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

MODE: Work
MODEL: <Approved Work model>
REASONING: <Approved reasoning level>
PURPOSE: Investigate and execute an explicitly approved documentation-only synchronization.

Requirements:

- No source changes.
- No test changes.
- Update only approved documentation.
- Never modify `Project documents/Implementation.md`.
- Work records discovery or synchronization output in `Project documents/Codex response.md` only when that file is not excluded by the approved task.
- Update `Project documents/PROJECT_STATE.md` only when verified repository facts change.
- Present documentation changes for review before committing unless explicitly instructed otherwise.
- After push, Work returns the exact commit SHA to Chat for proofreading. Chat records `PASS`, `PASS WITH CORRECTIONS` or `REJECT`; corrections return to Work and do not involve an implementation agent.

---

# Bug Fix Prompt

MODE: Codex
MODEL: <Approved Codex model>
REASONING: <Approved reasoning level>
PURPOSE: Implement and validate one explicitly approved bug fix.

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

MODE: Codex
MODEL: <Approved Codex model>
REASONING: <Approved reasoning level>
PURPOSE: Perform one approved behaviour-preserving refactor.

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

MODE: Codex
MODEL: <Approved Codex model>
REASONING: <Approved reasoning level>
PURPOSE: Implement only the approved institution parser scope using supplied fixtures.

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

MODE: Work
MODEL: <Approved Work model>
REASONING: <Approved reasoning level>
PURPOSE: Review verified repository evidence against accepted architecture without making architectural decisions.

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

MODE: Codex
MODEL: <Approved Codex model>
REASONING: <Approved reasoning level>
PURPOSE: Run the approved regression scope and report evidence-backed results.

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

MODE: Work
MODEL: <Approved Work model>
REASONING: <Approved reasoning level>
PURPOSE: Verify bootstrap and task routing without changing source code.

Read:

- `Project documents/.github/Context_Manifest.yaml`
- `Project documents/Project_Guide.md`
- `Project documents/PROJECT_STATE.md`
- `Project documents/FUTURE_WORK.MD` when the requested verification includes sprint planning or backlog routing
- `Project documents/Implementation.md` (ACTIVE sprint only)

Produce:

- Documents required
- Files likely to change
- Risks
- Validation required
- Stop condition

No code changes.
