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
- Add new files to the Xcode navigator  
- Add new files to target membership  
- Update `Project documents/Codex response.md`  
- Update `Project documents/Project_Guide.md` if project status changes  
- Stop exactly at the sprint boundary  

At completion provide:  
- Files changed  
- Architectural decisions  
- Risks  
- Remaining technical debt  
- Recommended next sprint  
- Suggested commit message  

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
- Dashboard unchanged unless expected  
- No parser regressions  

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
- Commit message  

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
