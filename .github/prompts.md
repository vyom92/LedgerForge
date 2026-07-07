# Prompt Template Library

**Mandatory first document for every prompt**

`Project documents/Project_Guide.md`

---

# Sprint Planning

## Objective

<Describe the sprint objective>

## Confirm

- Approved sprint
- Sprint scope
- Stop condition

## Before Doing Anything

- Read `Project documents/Project_Guide.md`
- Read `Project documents/PROJECT_STATE.md`
- Read `Project documents/Codex response.md` for the current sprint context.
- Use the Task Routing Guide in `Project documents/Project_Guide.md` to determine any additional documents required.

## Produce

- Architecture review
- Files to modify
- Files to create
- Risks
- Dependencies
- Complexity
- Build impact

Produce the implementation plan in
`Project documents/Codex response.md`.

Stop and wait for approval before implementation.

---

# Sprint Implementation

## Mandatory Rules

- Implement only the approved sprint.
- Preserve user-visible behaviour.
- Preserve approved financial truth.
- Build continuously.
- Run the required sprint validation after significant changes.
- If command-line tests fail solely because of the known SwiftUI Preview tooling issue after a successful build, execute the equivalent Xcode regression suite and treat that result as authoritative.
- Verify `git status` contains only sprint-related files.
- Verify there are no unresolved merge conflict markers.
- Generate a concise commit message from completed work.
- Commit.
- Push to the tracked branch (normally `origin/main`).
- Push the sprint tag (if created).
- Record build result, validation result, commit hash, tag and push result in `Project documents/Codex response.md`.
- Update `Project documents/PROJECT_STATE.md` only after a successful build, required validation, commit, push and tag (if applicable).
- Update `Project documents/Project_Guide.md` only if workflow, roadmap or engineering guidance changed.
- If validation fails, do not commit or push. Record the failure and stop.
- Add new files to the Xcode navigator.
- Add new files to target membership.
- Stop exactly at the approved sprint boundary.

### Completion Report

Provide:

- Files changed
- Files created
- Files removed
- Build status
- Validation status
- Commit hash
- Tag (if created)
- Push result
- Architectural decisions
- Risks
- Remaining technical debt
- Deferred work
- Recommended next sprint

---

# Bug Fix

## Problem

<Describe the observed behaviour>

## Expected Behaviour

<Describe the correct behaviour>

## Requirements

- Make the smallest possible change.
- Preserve existing behaviour.
- Build continuously.
- Run the required validation.
- Remove temporary diagnostics before completion.

---

# Refactor

## Goal

Improve maintainability without changing behaviour.

## Requirements

- Preserve behaviour.
- Reduce duplication.
- Improve naming.
- Preserve architecture.
- Do not change financial logic.

---

# New Financial Institution

## Institution

<Name>

## Requirements

- Use only supplied reference documents.
- Never infer statement layouts.
- Institution Detection before Statement Classification.
- Parser Selection before Statement Parser.
- Produce FinancialDocument.
- Preserve parser behaviour.
- Validate using approved reference fixtures.

---

# Architecture Review

## Review against

- Product Vision
- Project_Guide.md
- Engineering Standards
- ADRs

## Verify

- Readers only extract RawDocument.
- Institution Detection identifies the source.
- Statement Classification identifies the statement type.
- Parser Selection chooses the parser.
- Statement Parsers produce FinancialDocument.
- Validation remains centralized.
- Stores own runtime state.
- Views contain no business logic.
- No duplicated financial calculations.
- No unnecessary coupling.

Do not modify code during review.

---

# Regression Review

Validate against every approved reference fixture.

Confirm:

- Correct parser selected.
- Institution detected correctly.
- Statement type detected correctly.
- Transaction count preserved.
- Financial truth preserved.
- Validation behaviour unchanged.
- Validation results unchanged unless explicitly expected.
- Parser-to-FinancialDocument boundary preserved.
- Dashboard unchanged unless expected.
- No parser regressions.

Produce PASS / FAIL.

---

# Sprint Completion Report

Provide:

- Build status
- Validation status
- Commit hash
- Tag (if created)
- Push result
- Files modified
- Files created
- Files removed
- Architectural decisions
- Technical debt
- Known issues
- Risks
- Deferred work
- Recommended next sprint

---

# Project Guide Verification

## Test 1

- Read `Project documents/Project_Guide.md`.
- List only the documents required for the requested sprint.
- Explain why each document is required.
- List intentionally skipped documents.
- Do not write code.

## Test 2

- Read `Project documents/Project_Guide.md`.
- Describe exactly what the requested sprint may change.
- List five things it must not change.
- Quote the relevant sections.
- Do not write code.

## Test 3

- Read `Project documents/Project_Guide.md`.
- Read `Project documents/PROJECT_STATE.md`.
- Follow the Standard AI Workflow.
- Produce only:
  - Documents to read
  - Implementation plan
  - Risks
  - Files likely to change
  - Stop condition
- Do not write code.
