
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

# Current Project State

## Repository
- Primary Branch: `main`
- Latest Commit: `e3c557c`
- Latest Tag: `sprint-12c-complete`
- Architecture Baseline: Sprint 12C
- Latest Milestone: Institution Detection Framework
- Build: Passing
- Tests: 37 passing across 9 suites

## Session Startup Order
1. AGENTS.md
2. Project_Guide.md
3. PROJECT_STATE.md
4. ADR-020 — Deterministic Institution Detection
5. Project documents/Codex response.md

## Current Pipeline
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

## Current Work

Active Sprint: Sprint 13

Objective:
- Statement Classification Framework.

Scope:
- Deterministic statement classification.
- Preserve institution detection behaviour.
- Maintain parser selection independence.

Out of Scope:
- Parser rewrites
- OCR
- AI inference
- UI changes
- Repository changes
