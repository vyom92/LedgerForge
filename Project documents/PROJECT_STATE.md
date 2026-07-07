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

# Sprint 14

## Objective
Introduce the deterministic Parser Selection Framework while preserving Statement Classification behaviour and preparing for FinancialDocument Integration.

## Status
Completed

## Outcome
- Deterministic Parser Selection Framework implemented.
- Legacy `StatementParserRegistry` compatibility preserved.
- Axis CSV and PDF parser-selection context validated.
- Unknown institution and unknown statement type handling validated.
- 42 required Sprint 14 regression tests passed through Xcode.
- Build passed.
- Commit: `da117422d47ef9fe6f09fdfe110f88f54182b590`

---

# Current Project State

## Repository
- Primary Branch: `main`
- Latest Commit: `da117422d47ef9fe6f09fdfe110f88f54182b590`
- Latest Tag: `sprint-13-complete`
- Architecture Baseline: Sprint 14
- Latest Milestone: Parser Selection Framework
- Build: Passing
- Tests: 42 required Sprint 14 regression tests passing

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

Active Sprint: Sprint 15

Objective:
- FinancialDocument Integration.

Scope:
- Integrate deterministic import stages into a FinancialDocument handoff.
- Preserve parser extraction rules.
- Preserve validation, repository persistence and UI behaviour.

Out of Scope:
- Transaction extraction changes
- Validation changes
- Repository changes
- UI changes
- OCR
- AI inference
