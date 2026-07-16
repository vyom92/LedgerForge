# LedgerForge Agent Rules

LedgerForge is a private, single-user, offline-first macOS financial application. Preserve deterministic financial truth, explicit user control, native currency, privacy by default and repository-backed state.

## Bootstrap and authority

This file is the sole mandatory bootstrap entry point. Then read `Project documents/Project_Guide.md`, `Project documents/PROJECT_STATE.md`, and only the subject authorities required by the approved task. For planning, consult `Project documents/FUTURE_WORK.MD` before task-relevant architecture evidence.

The complete prompt approved by Chat and supplied directly in the current conversation is the sole execution contract. Without such a prompt, Codex must not modify the repository. There is no repository-stored active work contract.

| Question | Authority |
|---|---|
| What is verified now? | Repository evidence and `Project documents/PROJECT_STATE.md` |
| What may be executed now? | The complete Chat-approved prompt in the current conversation |
| What remains unscheduled? | `Project documents/FUTURE_WORK.MD` |
| What architecture is permitted? | Accepted ADRs and frozen Architecture |
| What is product direction? | `Project documents/Product Vision.md` |
| What is database design? | Database Architecture and verified migrations |
| What UI is approved? | Frozen UI/UX and approved assets |
| What engineering and verification rules apply? | This file, Project Guide, Engineering Standards and Build Conventions |

## Roles

- Chat plans, selects work, makes architecture decisions, supplies complete prompts and reviews direct reports.
- Work performs read-only, evidence-backed discovery and reports directly in chat. Work does not edit, commit, push, plan or define architecture.
- Codex performs authorised edits, builds, tests, documentation execution, durable-state updates and Git operations, then reports directly in chat.
- The user may edit repository files directly; legitimate user work is preserved and reconciled.

## Architecture invariants

Preserve:

```text
Reader → RawDocument → Institution Detection → Statement Classification
→ Parser Selection → Statement Parser → FinancialDocument → Validation
→ Fingerprinting & Duplicate Detection → Repository Persistence Boundary
→ Repositories → SQLite → RepositoryStoreHydrator → Runtime Stores
→ ViewModels → Views
```

Readers understand formats, parsers produce `FinancialDocument`, validation precedes persistence, repositories are the only SQLite boundary, and `RepositoryStoreHydrator` is the only persistence-to-runtime boundary. Never access SQLite from Views, ViewModels or Stores, bypass repositories, or silently alter financial history.

## Git continuity and safety

At the start of every execution cycle inspect branch, local commits, remote divergence, staged and unstaged changes, untracked files and the complete worktree. A dirty worktree is not automatically an error. Understand, preserve, validate and commit every legitimate compatible project change, then push every local commit and finish with `HEAD == origin/main`, no legitimate uncommitted changes and a clean worktree.

Never silently discard, reset, overwrite, stash-abandon, selectively push by authorship or strand legitimate work. Stop and report ambiguous, private, broken, incompatible, unexplained or unsafe material.

Never commit private financial statements, credentials, passwords, local SQLite databases, DerivedData, build products, sensitive logs, temporary files or unexplained generated output. Project-file edits must be limited to authorised metadata and use Xcode-safe practices.

## Validation and stop conditions

Build and test according to the approved prompt and subject-specific standards. Review the complete diff, run `git diff --check`, scan conflict markers, validate privacy and references, and confirm scope before committing. Documentation-only work may skip full tests only when executable, source, tests, schemas, migrations, fixtures, build settings and assets are unchanged; project metadata changes require project-integrity validation and a clean Debug build.

Do not claim completion or push failed validation. Record durable facts only in their subject authority. Manual verification must distinguish passed, pending, unavailable and explicitly accepted deferral.

Verified state is in `Project documents/PROJECT_STATE.md`; unscheduled work is in `Project documents/FUTURE_WORK.MD`; accepted architectural decisions are in `Project documents/ADR.md`.
