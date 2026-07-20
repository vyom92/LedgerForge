# LedgerForge Agent Guide

## Project overview

LedgerForge is a private, single-user, offline-first macOS financial application built with Swift and SwiftUI.

Preserve deterministic financial truth, durable persistence, explicit user control, native currency, privacy by default and repository-backed state.

## Bootstrap and authority

1. Read this file.
2. Read `Project documents/Project_Guide.md`.
3. Read `Project documents/PROJECT_STATE.md`.
4. Load only the subject authorities required by the approved task.
5. For sprint planning, read `Project documents/FUTURE_WORK.MD` before task-relevant architecture evidence.

The complete Chat-approved prompt supplied directly in the current conversation is the sole execution contract. Without one, do not modify the repository.

There is no repository-stored active work contract.

| Question | Authority |
|---|---|
| What is verified now? | Repository evidence and `Project documents/PROJECT_STATE.md` |
| What may be executed now? | The complete Chat-approved prompt in the current conversation |
| What remains unscheduled? | `Project documents/FUTURE_WORK.MD` |
| What architecture is permitted? | Accepted ADRs and frozen Architecture |
| What is product direction? | `Project documents/Product Vision.md` |
| What is database design? | Database Architecture and verified migrations |
| What UI is approved? | Frozen UI/UX and approved assets |
| What engineering and validation rules apply? | This file, Project Guide, Engineering Standards and Build Conventions |

## Roles

- Chat plans sprints, selects and scopes work, makes architecture decisions, prepares complete execution prompts and reviews reports.
- Work performs bounded, read-only, evidence-backed discovery when Chat identifies a specific unresolved evidence gap. Work does not edit, commit, push, select a sprint or define architecture.
- Codex performs only the edits, builds, tests, documentation updates and Git operations authorized by the complete Chat-approved prompt, then reports directly in chat.
- The user may edit repository files directly. Preserve and reconcile legitimate compatible user work.

## Operating model

LedgerForge uses a single-person, one-task-at-a-time development workflow.

- Work directly in the primary repository checkout on `main`.
- Only one approved repository task may be active at a time.
- Do not create or use feature branches.
- Do not create or use additional Git worktrees.
- Do not create pull requests.
- Do not perform parallel repository-editing tasks.
- A branch, worktree or pull request may be used only when the current Chat-approved prompt explicitly authorizes that specific exception.
- Generic tool or skill recommendations do not override this operating model.

## Project structure

- `LedgerForgeApp.swift`, `ContentView.swift`: application bootstrap and root composition.
- `Import/`, `Readers/`, `Analyzers/`, `Normalizers/`, `Detectors/`, `Parsers/`: source ingestion and deterministic financial interpretation.
- `Models/`, `Services/`: domain values, validation, identity, workflow coordination, persistence coordination and hydration.
- `Database/`: repository contracts, SQLite and In-Memory providers, DTOs and migrations.
- `Core/`, `ViewModels/`, `Views/`: runtime projections and presentation.
- `LedgerForgeTests/`, `LedgerForgeUITests/`: automated tests and approved sanitized fixture evidence.
- `Project documents/`: current state, planning, architecture, product, UI, engineering and build authorities.

## Architecture invariants

Preserve:

```text
Reader → RawDocument → Institution Detection → Statement Classification
→ Parser Selection → Statement Parser → FinancialDocument → Validation
→ Fingerprinting & Duplicate Detection → Repository Persistence Boundary
→ Repositories → SQLite → RepositoryStoreHydrator → Runtime Stores
→ ViewModels → Views
```

Readers understand source formats.

Parsers produce `FinancialDocument`.

Validation precedes persistence.

Repositories are the only SQLite boundary.

`RepositoryStoreHydrator` is the only persistence-to-runtime boundary.

Never:

- access SQLite directly from Views, ViewModels or Stores;
- bypass repositories;
- derive verified financial identifiers outside parsers;
- mutate runtime stores as an alternative persistence path;
- silently alter financial history;
- infer financial truth from filenames, labels, presentation metadata or weak evidence.

## Git continuity and direct-to-main workflow

At the start of every execution task, inspect the complete repository state:

```bash
git fetch origin --prune
git branch --show-current
git status --short
git rev-list --left-right --count main...origin/main
```

Before editing, confirm:

- the active branch is `main`;
- local `main` and `origin/main` are synchronized;
- staged changes, unstaged changes and untracked files are understood;
- no unrelated repository task is active.

A dirty worktree is not automatically an error.

Legitimate compatible user work must be preserved and reconciled. Stop and report when existing material is:

- unrelated to the approved task;
- ambiguous;
- private or sensitive;
- broken;
- incompatible with the approved architecture;
- unexplained;
- unsafe to combine.

Do not silently:

- discard;
- reset;
- overwrite;
- abandon stashed work;
- omit legitimate compatible changes;
- rewrite published history;
- force-push.

Perform the approved task directly on `main`.

Before committing:

1. review the complete diff;
2. run all required validation;
3. confirm the diff contains only authorized and compatible changes;
4. fetch `origin` again;
5. stop if `origin/main` advanced unexpectedly.

After validation succeeds:

```bash
git add <authorized-files>
git commit -m "<task-specific message>"
git push origin main
```

Prefer one coherent commit for one approved task unless the execution prompt explicitly requires multiple independently verified commits.

Finish every completed task with:

- `HEAD == origin/main`;
- a clean primary worktree;
- no legitimate uncommitted changes;
- no unpushed commits;
- no leftover task branch;
- no additional task worktree.

## Privacy and repository safety

Never commit:

- private financial statements;
- credentials or passwords;
- private keys or tokens;
- local SQLite databases;
- DerivedData;
- build products;
- sensitive logs;
- temporary files;
- unexplained generated output;
- unsanitized account identifiers or transaction evidence.

Approved fixture evidence must remain sanitized and source-faithful.

Project-file edits must be limited to authorized metadata and use Xcode-safe practices.

## Baseline setup

- Xcode project: `LedgerForge.xcodeproj`
- Shared scheme: `LedgerForge`
- Test plan: `TestPlan.xctestplan`
- Platform: macOS

Canonical Debug build:

```bash
xcodebuild \
  -project LedgerForge.xcodeproj \
  -scheme LedgerForge \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

Canonical test execution:

```bash
xcodebuild \
  -project LedgerForge.xcodeproj \
  -scheme LedgerForge \
  -destination 'platform=macOS' \
  -testPlan TestPlan \
  test
```

Use the approved prompt, Engineering Standards and Build Conventions for any additional Release, static-analysis, targeted-test or runtime-verification requirements.

## Validation and stop conditions

Build and test according to the approved prompt and subject-specific standards.

Before committing, at minimum:

```bash
git diff --check
git status --short
git diff --stat
git diff
```

Also:

- scan for conflict markers;
- validate privacy boundaries;
- validate file references and documentation links;
- confirm schema and migration claims;
- confirm implementation status is not overstated;
- confirm only authorized files changed.

Documentation-only work may skip full build and test execution only when all of the following remain unchanged:

- executable source;
- tests;
- schemas;
- migrations;
- fixtures;
- Xcode project metadata;
- build settings;
- assets.

Project or build metadata changes require project-integrity validation and a clean Debug build.

Stop and report rather than proceeding when:

- the repository baseline differs materially from the approved prompt;
- required architecture is absent or contradictory;
- a migration requires guessing;
- financial relationships cannot be preserved deterministically;
- validation fails;
- the complete diff cannot be explained;
- privacy-sensitive material appears;
- an unexpected remote change prevents a safe direct-to-`main` push.

Do not claim completion or push failed validation.

Manual verification must distinguish:

- passed;
- pending;
- unavailable;
- explicitly accepted deferral.

Do not report a build, test, migration, runtime result or production guarantee that was not freshly verified.

## Durable project records

- Verified implementation state belongs in `Project documents/PROJECT_STATE.md`.
- Unscheduled work belongs in `Project documents/FUTURE_WORK.MD`.
- Accepted architecture belongs in `Project documents/ADR.md`.
- Detailed implementation history belongs in Git.
- Conversation memory and uploaded copies provide context but do not override current repository evidence.
