# BUILD_AND_PROJECT_CONVENTIONS

## Purpose

This document defines the project conventions that are not architectural decisions, but are essential for maintaining a stable LedgerForge development workflow.

It complements:

- Project documents/Product Vision.md
- Project documents/Architecture_v1.0_Frozen.md
- Project documents/ADR.md
- Project documents/Engineering Standards.md
- Project documents/Project_Guide.md
- AGENTS.md

This document focuses on build mechanics, Xcode project management, validation workflow and repository hygiene.

---

# Project Principles

## Preserve Existing Architecture

Always extend the approved architecture.

Do not create parallel implementations when an existing component can be extended safely.

Prefer migration over duplication.

---

## Repository First

Before introducing a new repository API:

- verify existing contracts
- reuse existing queries whenever practical
- introduce a new API only when existing contracts cannot express the required behaviour cleanly

Every new repository API should have a narrowly defined responsibility.

---

## Canonical Import and Presentation Pipeline

The approved canonical pipeline is:

ImportCoordinator

↓

PasswordProvider

↓

ReaderRegistry

↓

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

User Review & Explicit Confirmation

↓

Fingerprinting & Duplicate Detection

↓

Repository Persistence Boundary

↓

Repositories

↓

SQLite

↓

RepositoryStoreHydrator

↓

Runtime Stores

↓

ViewModels

↓

Views

No component may bypass this pipeline.

Every implementation must preserve this sequence unless an approved ADR explicitly changes the architecture.

---

## UI Asset References

Approved UI references live under:

`Project documents/UI Assets/Approved/`

- `DesignBoard_v2.0.png` is the master UI reference.
- Individual approved assets define screen-level implementation details.
- `AppIcon_v1.0.png` is the approved application icon.
- Implementation sprints translate approved assets into SwiftUI. They must not redesign the approved UI language.

---

# Workflow Authority

`AGENTS.md` is the sole mandatory bootstrap entry point. The complete Chat-approved prompt supplied directly in the current conversation is the sole execution contract. `Project_Guide.md` routes to subject authorities; `PROJECT_STATE.md` records verified state; `FUTURE_WORK.MD` records unscheduled work; this document governs build, Xcode and repository mechanics.

Work discovery is read-only and reported directly in chat. Codex owns authorised edits, validation, documentation execution and Git operations.

---

# Xcode Project Conventions

## Adding Source Files

When adding new source files:

1. Prefer Xcode-safe project operations.
2. Avoid manual `.pbxproj` editing whenever project tooling is available.
3. Verify target membership.
4. Verify filesystem-synchronised groups remain correct.
5. Confirm successful compilation before continuing.

---

## Target Membership

Every new file must belong to the correct target.

Typical examples:

- Services → App target
- Runtime Stores → App target
- ViewModels → App target
- Tests → Test target

Never assume target membership.

Always verify.

---

# Build Workflow

Preferred implementation rhythm:

Implementation

↓

Build

↓

Focused Tests

↓

Next Change

Avoid implementing an entire sprint before compiling.

---

## Validation Order

1. Build.
2. Focused sprint tests.
3. Required regression suites.
4. Repository check.
5. Documentation review.
6. Git review.

---

## Validation Authority

Preferred:

Command-line validation.

If blocked solely by a known toolchain issue:

- run the equivalent Xcode validation
- record that Xcode became authoritative
- report the reason directly in chat

---

# Runtime Store Rules

Runtime Stores own observable application state.

`RepositoryStoreHydrator` is the only approved persistence → runtime boundary.

Hydration should:

- execute once during startup
- remain deterministic
- avoid duplicate runtime state
- support explicit refresh only when requested

---

# Git Workflow

At the start of every cycle inspect the branch, local commits, remote divergence, staged and unstaged changes, untracked files and complete worktree. A dirty worktree is not automatically a failure. Understand and preserve every legitimate compatible change, validate the combined state, commit all legitimate pending project work, push all local commits and finish with `HEAD == origin/main`, no legitimate uncommitted changes and a clean worktree.

Never reset, discard, overwrite, stash-abandon or selectively push legitimate work. Stop for ambiguous, private, broken, incompatible, unexplained or unsafe material. Never commit private financial statements, credentials, passwords, local databases, DerivedData, build products, sensitive logs, temporary files or unexplained generated output.

Standard verification:

- `git status`
- `git diff --stat`
- `git diff --cached --stat`

---

# Documentation Workflow

Verify consistency between Project Guide, PROJECT_STATE, FUTURE_WORK and the affected subject authorities. Reports return directly in chat; verified durable facts are recorded only in their subject authorities.

If architecture changed, also review:

- Project documents/ADR.md
- Project documents/Architecture_v1.0_Frozen.md
- Project documents/Engineering Standards.md

When selecting or reprioritising future work, review `Project documents/FUTURE_WORK.MD`. Do not update the backlog unless the approved prompt explicitly requires it.

Documentation execution: Chat supplies the complete prompt → Codex reconciles, edits and validates → Codex commits and pushes → Codex reports directly in chat → Chat returns `PASS`, `PASS WITH CORRECTIONS` or `REJECT`.

---

# Common Pitfalls

Avoid:

- duplicate runtime state
- duplicate repository APIs
- bypassing repository abstractions
- SQLite access from Views, ViewModels or Runtime Stores
- implementation that skips validation
- manual project edits when safer tooling exists
- documenting future work as completed work

---

# Definition of Success

A sprint is considered complete only when:

- implementation complete
- build passes
- required validation passes
- documentation synchronized
- `Project documents/PROJECT_STATE.md` updated if required
- Direct chat report returned
- commit created
- push completed
- tag created when applicable
- working tree clean after push

---

# Living Document

This document captures project mechanics learned during implementation.

It should evolve only when repeated experience demonstrates a better workflow.

Do not update it for one-off events.

Only promote practices that have proven stable across multiple sprints.
