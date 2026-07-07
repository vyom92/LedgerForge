# PROJECT STATE

This document is the permanent, authoritative handoff between development sessions.

It records only verified project state. Temporary planning, implementation notes, build logs and reasoning belong in `Project documents/Codex response.md`.

Principles:
- Facts only.
- Repository-verifiable information only.
- Minimal manual editing.
- Updated only after successful build, required tests, commit and push.

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

# Sprint 13

## Objective
Introduce the deterministic Statement Classification Framework while preserving Institution Detection behaviour and preparing for Parser Selection.

## Status
Completed

## Outcome
- Deterministic Statement Classification Framework implemented.
- Legacy-compatible statement classification mapping preserved.
- Explainable classification reasons added.
- Unknown and non-text document classification validated.
- Statement Classification regression suite added.
- 46 tests passed across 10 suites.
- Build passed.
- Git tag: `sprint-13-complete`

---

# Current Project State

## Repository
- Primary Branch: `main`
- Latest Commit: (update after each sprint)
- Latest Tag: `sprint-13-complete`
- Architecture Baseline: Sprint 13
- Latest Milestone: Statement Classification Framework
- Build: Passing
- Tests: 46 passing across 10 suites

## Session Startup Order
1. AGENTS.md
2. Project_Guide.md
3. PROJECT_STATE.md
4. Latest ADR (currently ADR-021 — Deterministic Statement Classification)
5. Project documents/Codex response.md

## Current Pipeline
Import Pipeline:

Reader
↓
RawDocument
↓
Institution Detection
↓
Statement Classification
↓
Parser Selection
↓
Statement Parser
↓
FinancialDocument
↓
Validation
↓
Repositories
↓
Dashboard

## Current Work

Active Sprint: Sprint 14

Objective:
- Parser Selection Framework.

Scope:
- Deterministic parser selection.
- Preserve Statement Classification behaviour.
- Keep parser selection independent from readers.

Out of Scope:
- Transaction extraction changes
- Validation changes
- Repository changes
- UI changes
- OCR
- AI inference
