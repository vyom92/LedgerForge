//
//  Untitled.swift
//  LedgerForge
//
//  Created by Vyom on 07/07/26.
//


# Sprint History

This document is the authoritative handoff record between development sessions. It provides a deterministic snapshot of the project state for both humans and AI assistants.

---

# How to Use

At the completion of every sprint:

1. Add a new sprint entry.
2. Update the AI Handoff section.
3. Commit the document with the sprint.
4. Never rewrite previous sprint history except to correct factual errors.

---

# Sprint 12B

## Objective
Establish approved PDF regression fixtures and verify reader behaviour against deterministic financial baselines.

## Status
Completed

## Outcome
- Approved Axis PDF fixture established.
- Shared financial baseline introduced.
- PDF reader regression suite implemented.
- Build passed.
- Regression tests passed.
- Git tag: `sprint-12b-complete`

---

# Sprint 12C

## Objective
Introduce the deterministic Institution Detection Framework while preserving legacy behaviour.

## Status
Completed

## Outcome
- Institution Detection Framework implemented.
- Legacy detector compatibility preserved.
- Axis CSV and PDF detection validated.
- Unknown document handling validated.
- 37 tests passed across 9 suites.
- Build passed.
- Git tag: `sprint-12c-complete`

---

# AI Handoff

## Repository State
- Branch: `main`
- Latest Architecture Baseline: Sprint 12C
- Build Status: Passing
- Test Status: 37 tests passing

## Required Reading
1. AGENTS.md
2. Project_Guide.md
3. Latest ADR
4. Project documents/Codex response.md
5. Sprint History.md

## Current Architecture
Import Pipeline:

Reader
↓
RawDocument
↓
Institution Detection
↓
Statement Classification (planned)
↓
Parser Selection
↓
FinancialDocument
↓
Validation
↓
Repositories
↓
Dashboard

## Active Technical Debt
- ImportEngine still owns too many responsibilities.
- Additional approved fixtures required for future institutions.
- Swift 6 concurrency warnings remain in RepositoryContractTests.

## Next Sprint
Sprint 13 — Statement Classification Framework.

Scope:
- Introduce deterministic statement classification.
- Preserve institution detection behaviour.
- Keep parser selection independent from file format.

Out of Scope:
- Parser rewrites
- OCR
- AI inference
- UI changes
- Repository changes
