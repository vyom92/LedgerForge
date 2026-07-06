

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
