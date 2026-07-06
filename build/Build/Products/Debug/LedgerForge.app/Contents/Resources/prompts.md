

# LedgerForge Prompt Templates

These templates are intended for GitHub Copilot Agent. Copy the appropriate template into Copilot Chat, fill in the placeholders, and execute.

---

# New Sprint

## Objective

<Describe the feature or milestone>

## References

Read before coding:
- ADR.md
- Architecture.md
- Engineering Standards.md
- Product Vision.md

Use any previously approved UI sketches, dashboard screenshots, Excel workbooks or financial statement samples. If a required reference is unavailable, stop and request it.

## Files Expected

- <file>
- <file>
- <file>

## Acceptance Criteria

- Project builds successfully.
- Existing functionality remains intact.
- No parser regressions.
- Architecture rules are followed.
- No warnings introduced unless unavoidable.

## Do Not

- Invent financial workflows.
- Invent statement layouts.
- Modify unrelated files.
- Bypass validation.

---

# Bug Fix

## Problem

<Describe the observed behaviour>

## Expected Behaviour

<Describe the correct behaviour>

## Constraints

- Change the smallest number of files.
- Preserve existing behaviour.
- Add temporary diagnostics only if required.
- Remove temporary diagnostics before completion.

---

# Refactor

## Goal

Improve maintainability without changing behaviour.

Requirements:

- Preserve public behaviour.
- Reduce duplication.
- Improve naming where appropriate.
- Keep build green throughout.

---

# New Financial Institution

## Institution

<Name>

## Reference Documents

Use only supplied statement samples.
Do not infer layouts.

## Requirements

- Add institution-specific parser.
- Reuse generic infrastructure.
- Preserve existing parser behaviour.
- Validate using supplied reference statements.

---

# Code Review

Review the implementation against:

- ADR.md
- Architecture.md
- Engineering Standards.md
- Product Vision.md

Confirm:

- Correct architecture.
- Financial correctness.
- No duplicated logic.
- Appropriate ownership.
- UI contains no business logic.
- No unnecessary complexity.

# LedgerForge Prompt Templates

These templates are intended for GitHub Copilot Agent.

Every implementation begins with a planning phase.

Never implement before producing an implementation plan and receiving approval.

---

# Sprint Planning

## Objective

<Describe the sprint objective>

## Before Doing Anything

Read:

- Product Vision.md
- Architecture.md (or current Architecture document)
- Engineering Standards.md
- ADR.md
- context.md
- copilot-instructions.md

Use previously approved dashboard references, financial statement samples, Excel workbooks and UI references.

If any required reference is unavailable, stop and request it.

Verify the filename in the first comment block before editing any file.

## Produce

- Architecture review
- Files to modify
- Files to create
- Risks
- Dependencies
- Estimated complexity
- Build impact

Stop and wait for approval.

---

# Sprint Implementation

## Approved Plan

Implement only the approved plan.

Requirements:

- Edit only approved files.
- Build after every significant change.
- Resolve compile errors before continuing.
- Run regression tests whenever parser or import code changes.
- Do not modify unrelated files.
- Preserve existing parser behaviour.
- Preserve financial correctness.

At completion provide:

- Files changed
- Architectural decisions
- Risks
- Remaining technical debt
- Recommended next sprint
- Suggested Git commit message

---

# Bug Fix

## Problem

<Describe the observed behaviour>

## Expected Behaviour

<Describe the correct behaviour>

Requirements:

- Smallest possible change.
- Preserve existing behaviour.
- Build continuously.
- Remove temporary diagnostics before completion.

---

# Refactor

Goal:

Improve maintainability without changing behaviour.

Requirements:

- Preserve behaviour.
- Reduce duplication.
- Improve naming.
- Preserve architecture.
- Do not change financial logic.

---

# New Financial Institution

Institution:

<Name>

Requirements:

- Use only supplied reference documents.
- Never infer statement layouts.
- Detect institution before parser selection.
- Detect document type.
- Reuse FinancialDocument pipeline.
- Preserve existing parser behaviour.
- Validate using supplied reference documents.

---

# Architecture Review

Review against:

- Product Vision
- Architecture
- Engineering Standards
- ADRs

Verify:

- Readers only extract.
- Parsers never know file format.
- Validation remains centralized.
- TransactionStore owns transactions.
- AccountStore owns accounts.
- Views contain no business logic.
- No duplicated financial calculations.
- No unnecessary coupling.

Do not modify code.

---

# Regression Review

Validate against all available reference documents.

Confirm:

- Correct parser selected.
- Institution detected correctly.
- Document type detected correctly.
- Transaction count preserved.
- Validation behaviour unchanged.
- Dashboard unchanged unless expected.
- No parser regressions.

Produce a PASS / FAIL summary.

---

# Sprint Completion Report

Provide:

- Build status
- Test status
- Files modified
- Files created
- Files removed
- Architectural decisions
- Technical debt
- Known issues
- Risks
- Next sprint recommendation
- Git commit message
