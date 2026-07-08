

# BUILD_AND_PROJECT_CONVENTIONS

## Purpose

This document defines the project conventions that are not architectural decisions, but are essential for maintaining a stable LedgerForge development workflow.

It complements:

- Product Vision.md
- Architecture_v1.0_Frozen.md
- ADR.md
- Engineering Standards.md
- Project_Guide.md
- AGENTS.md
- AI_WORKFLOW.md

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

## Presentation Pipeline

The approved presentation pipeline is:

Reader
→ RawDocument
→ Institution Detection
→ Statement Classification
→ Parser Selection
→ FinancialDocument
→ Validation
→ Repository Persistence
→ RepositoryStoreHydrator
→ Runtime Stores
→ ViewModels
→ Views

No component may bypass this pipeline.

---

## UI Asset References

Approved UI references live under `Project documents/UI Assets/Approved/`.

- `DesignBoard_v2.0.png` is the master UI reference.
- Individual approved assets define screen-level implementation details.
- `AppIcon_v1.0.png` is the approved app icon reference.
- Implementation sprints must translate approved assets into SwiftUI rather than redesigning the UI.

---

## AI Workflow Document Location

AI workflow prompt and context files live under `Project documents/.github/`.

Root-level `.github` documentation files were intentionally moved under `Project documents/.github/` so project workflow documentation remains with the rest of the project documents.

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
- record the reason in Codex response.md

---

# Runtime Store Rules

Runtime Stores own observable application state.

RepositoryStoreHydrator is the only approved persistence → runtime boundary.

Hydration should:

- execute once during startup
- remain deterministic
- avoid duplicate runtime state
- support explicit refresh only when requested

---

# Git Workflow

Before committing:

- verify git status
- verify staged files belong only to the approved sprint
- verify documentation consistency
- verify required validation completed

Standard verification:

- git status
- git diff --stat
- git diff --cached --stat

---

# Documentation Workflow

Before closing every sprint verify consistency between:

- Project_Guide.md
- PROJECT_STATE.md
- Codex response.md

If architecture changed:

- ADR.md
- Architecture_v1.0_Frozen.md
- Engineering Standards.md

must also be reviewed.

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

- implementation is complete
- build passes
- required validation passes
- documentation is synchronized
- repository is clean
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
