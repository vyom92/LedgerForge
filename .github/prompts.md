# Prompt Template Library

**Note:**  
The mandatory first document for every prompt is always:  
`Project documents/Project_Guide.md`

---

# Sprint Planning

## Objective

<Describe the sprint objective>

## Confirm

- Sprint scope and stop condition

## Before Doing Anything

- Read `Project documents/Project_Guide.md`  
- Read `Project documents/Codex response.md`  
- Use the Task Routing Guide to determine any additional documents to read

## Produce

- Architecture review  
- Files to modify  
- Files to create  
- Risks  
- Dependencies  
- Complexity  
- Build impact  

Stop and wait for approval before implementation.

---

# Sprint Implementation

## Mandatory Rules

- Implement only the approved sprint  
- Preserve user-visible behaviour  
- Build continuously  
- Run relevant tests after every significant change  
- If the project builds successfully and required sprint tests pass, verify `git status` contains only sprint-related files.
- Verify there are no unresolved merge conflict markers.
- Generate a concise commit message based on the completed sprint work.
- Commit the sprint changes.
- Push to `origin/main`.
- Record the commit hash and push result in `Project documents/Codex response.md`.
- If the build or required tests fail, do not commit or push. Record the failure in `Project documents/Codex response.md` and stop.
- Add new files to the Xcode navigator  
- Add new files to target membership  
- Update `Project documents/Codex response.md`  
- Update `Project documents/Project_Guide.md` if project status changes  
- Stop exactly at the sprint boundary  

At completion provide:
- Files changed
- Files created
- Files removed
- Build status
- Test status
- Commit hash (if committed)
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

- Make the smallest possible change  
- Preserve existing behaviour  
- Build continuously  
- Remove temporary diagnostics before completion  

---

# Refactor

## Goal

Improve maintainability without changing behaviour.

## Requirements

- Preserve behaviour  
- Reduce duplication  
- Improve naming  
- Preserve architecture  
- Do not change financial logic  

---

# New Financial Institution

## Institution

<Name>

## Requirements

- Use only supplied reference documents  
- Never infer statement layouts  
- Detect institution before parser selection  
- Detect document type  
- Reuse FinancialDocument pipeline  
- Preserve existing parser behaviour  
- Validate using supplied reference documents  

---

# Architecture Review

## Review against

- Product Vision  
- Project_Guide.md  
- Engineering Standards  
- ADRs  

## Verify

- Readers only extract data  
- Parsers never know file format  
- Validation remains centralized  
- TransactionStore owns transactions  
- AccountStore owns accounts  
- Views contain no business logic  
- No duplicated financial calculations  
- No unnecessary coupling  

Do not modify code during review.

---

# Regression Review

## Validate against all available reference documents

Confirm:

- Correct parser selected  
- Institution detected correctly  
- Document type detected correctly  
- Transaction count preserved  
- Validation behaviour unchanged  
- Approved CSV/PDF reference fixtures preserve identical financial truth
- Dashboard unchanged unless expected  
- No parser regressions  

Produce a PASS / FAIL summary.

---

# Sprint Completion Report

Provide:
- Build status
- Test status
- Commit hash
- Push result
- Files modified
- Files created
- Files removed
- Architectural decisions
- Technical debt
- Known issues
- Risks
- Deferred work
- Next sprint recommendation

---

# Project Guide Verification

### Test 1

- Read `Project documents/Project_Guide.md`  
- List only the documents required for Sprint 11C  
- Explain why each document is required  
- List which documents are intentionally skipped  
- Do not write code  

### Test 2

- Read `Project documents/Project_Guide.md`  
- Describe exactly what Sprint 11C is allowed to change  
- List five things Sprint 11C must not change  
- Quote the relevant `Project documents/Project_Guide.md` sections  
- Do not write code  

### Test 3

- Read `Project documents/Project_Guide.md`  
- Assume Sprint 11C has been requested  
- Follow the Standard AI Workflow  
- Produce only:  
  - Documents to read  
  - Implementation plan  
  - Risks  
  - Files likely to change  
  - Stop condition  
- Do not write code
