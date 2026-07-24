# LedgerForge Agent Guide

**Status:** Mandatory repository bootstrap and execution-policy entry point  
**Alignment reviewed:** 2026-07-25  
**Repository ref reviewed:** `main@a64c2d8d67e93631d8b0c32620ded72f389f252f`  
**Latest verified implementation baseline:** `11035461ce3de0f11ae5262bbc8a38b9639607b2` - Sprint 53

## Project Overview

LedgerForge is a private, single-user, offline-first macOS financial application built with Swift and SwiftUI.

Apply this priority order:

1. financial correctness;
2. durable persistence;
3. deterministic behavior;
4. explicit user control;
5. privacy;
6. recoverability;
7. explainability;
8. maintainability;
9. delivery speed.

A faster implementation never outranks a higher-priority invariant.

---

## Mandatory Bootstrap

For every repository task:

1. Read this file.
2. Read `Project documents/Project_Guide.md`.
3. Read `Project documents/PROJECT_STATE.md`.
4. Read the complete Chat-approved prompt in the current conversation.
5. Load only the subject authorities required by that task.
6. For sprint planning, read `Project documents/FUTURE_WORK.MD` before task-specific architecture evidence.

The complete Chat-approved prompt supplied directly in the current conversation is the sole execution contract.

Without one:

- do not edit repository files;
- do not build an implementation branch;
- do not commit;
- do not push;
- do not create a pull request;
- do not infer an active sprint from repository documents.

There is no repository-stored active work contract.

---

## Authority Map

| Question | Primary authority |
|---|---|
| What is verified now? | Exact repository evidence and `Project documents/PROJECT_STATE.md` |
| What may be executed now? | The complete Chat-approved prompt in the current conversation |
| What remains unscheduled? | `Project documents/FUTURE_WORK.MD` |
| What architecture is accepted? | Accepted entries in `Project documents/ADR.md` and frozen Architecture |
| What is the database design? | Database Architecture, accepted ADRs and registered migrations |
| What is product direction? | `Project documents/Product Vision.md` |
| What UI is approved? | Frozen UI/UX and approved assets |
| What engineering, privacy and verification rules apply? | `Project documents/Engineering Standards.md` |
| What build, Xcode and Git mechanics apply? | `Project documents/BUILD_AND_PROJECT_CONVENTIONS.md` |
| What happened historically? | Git history and preserved historical ADR text |
| What is true only in the local checkout? | Direct local evidence, normally through bounded Work investigation |

When authorities conflict:

1. identify the exact conflict;
2. inspect the current exact ref;
3. apply accepted ADRs where they supersede older frozen text;
4. do not choose the most convenient interpretation;
5. stop and return the unresolved decision to Chat.

Memory, uploaded copies and earlier conversations provide context only.

They never override current repository evidence.

---

## Mode Ownership

### Chat

Chat owns:

- sprint planning;
- prioritization;
- architecture discussion and decisions;
- execution-prompt preparation;
- review of Work and Codex reports;
- final acceptance.

Planning does not authorize implementation.

### Work

Work is limited to bounded, read-only investigation when GitHub cannot efficiently establish a decision-critical fact.

Before escalating, Chat states:

1. the exact unknown;
2. why it affects the decision;
3. the bounded evidence Work must return.

Work may investigate:

- local or unpushed state;
- linked worktrees;
- filesystem and Xcode configuration;
- build, test or runtime evidence;
- broad cross-file tracing;
- one unresolved architecture boundary.

Work does not:

- edit files;
- select a sprint;
- define architecture;
- commit;
- push;
- create branches;
- create worktrees;
- create pull requests.

### Codex

Codex performs only the edits, builds, tests, documentation updates and Git operations authorized by the complete Chat-approved prompt.

Codex reports evidence, limitations and residue directly in chat.

### User Changes

The user may edit repository files directly.

Preserve legitimate compatible user work.

Stop rather than discard, overwrite or absorb work that is:

- unrelated;
- ambiguous;
- private or sensitive;
- broken;
- incompatible;
- unexplained;
- unsafe to combine;
- uniquely owned by another branch, worktree or stash.

---

## Operating Model

LedgerForge uses a single-person, one-task-at-a-time repository workflow.

Default model:

- one `main` branch;
- one primary worktree;
- one active repository-editing task;
- no feature branch;
- no extra worktree;
- no pull request;
- direct commit and push to `origin/main` after validation.

A branch, worktree or pull request may be used only when:

1. the user explicitly approves it;
2. a repository-specific reason is recorded;
3. the complete approved prompt requires the exception.

Generic tool advice or Git habit does not override this model.

---

## Project Structure

- `LedgerForgeApp.swift`, `ContentView.swift`: application bootstrap and root composition.
- `Import/`: import workflow and orchestration seams.
- `Readers/`: source-format access and extraction.
- `Analyzers/`, `Normalizers/`: deterministic structural extraction support.
- `Detectors/`: institution and document-family detection.
- `Parsers/`: institution- and layout-specific financial interpretation.
- `Models/`: domain values and typed outcomes.
- `Services/`: validation, identity, workflow coordination, lifecycle and hydration support.
- `Database/`: repositories, DTOs, SQLite and In-Memory providers, registered migrations.
- `Core/`: shared runtime infrastructure.
- `ViewModels/`, `Views/`: presentation projections and SwiftUI.
- `LedgerForgeTests/`: automated tests and approved sanitized fixture evidence.
- `LedgerForgeUITests/`: generic UI-test target, intentionally disabled unless separately authorized.
- `Project documents/`: current state, planning, architecture, product, UI, engineering and build authorities.

Folder location does not override the responsibility boundaries below.

---

## Canonical Import Architecture

Preserve this approved flow:

```text
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
Exact-Content and Supported Transaction-Event Evaluation
    ↓
Account / Identity Review
    ↓
Explicit User Confirmation
    ↓
DatabaseProvider Confirmed-Import Operation
    ↓
Provider-Owned Atomic Persistence
    ↓
RepositoryStoreHydrator
    ↓
Runtime Stores
    ↓
ViewModels
    ↓
Views
```

### Ownership Rules

- Readers understand source formats.
- Readers perform authorized file access and extraction only.
- Readers receive optional credentials from coordination.
- Readers never access Keychain directly.
- Readers do not interpret financial meaning.
- Institution Detection uses approved extracted-content evidence.
- Statement Classification identifies the document family.
- Parser Selection chooses only an approved parser/profile.
- Statement Parsers own financial interpretation.
- Statement Parsers alone produce verified financial identifiers.
- `FinancialDocument` is canonical parser output.
- Validation is mandatory before accepted persistence.
- Preparation and review are read-only.
- Duplicate, event and identity results prepared before confirmation are advisory.
- Explicit confirmation is required.
- `DatabaseProvider` owns confirmation-time revalidation and the accepted atomic graph.
- Repositories are the only SQLite boundary.
- `RepositoryStoreHydrator` is the sole persistence-to-runtime boundary.
- Runtime stores are projections, not durable truth.
- ViewModels prepare presentation state.
- Views present state and collect user intent.

### Prohibited Bypasses

Never:

- access SQLite from Views, ViewModels or runtime stores;
- bypass repositories;
- coordinate one financial transaction through several UI-owned writes;
- derive verified identifiers outside parsers;
- use filenames, labels or weak presentation evidence as financial identity;
- patch runtime stores to simulate persistence;
- use parser output as its own sole validation oracle;
- silently omit rejected transactions;
- infer unsupported institution, layout or format support;
- invent missing financial evidence;
- treat fixture or schema presence as production support.

---

## Financial Truth Invariants

For financial-correctness work:

- source semantics outrank derived fixtures and expected JSON;
- production parser output must not be the sole oracle;
- preserve native currency, scale, direction, printed date meaning, source order, balances, identifiers and provenance;
- fail closed on malformed, ambiguous, conflicting or unsupported evidence;
- verify zero accepted durable residue on rejection;
- require SQLite and In-Memory parity where both matter;
- verify persistence, hydration, provider reconstruction, relaunch and presentation;
- never infer institution, layout or format support from structural similarity;
- never invent historical dates, order, identifiers, observations or provenance;
- keep sanitized fixtures in Git;
- keep private originals isolated and read-only;
- distinguish source truth, implementation behavior, test evidence and inference.

A green suite proves only the boundary and oracle it exercises.

---

## Mandatory Local Repository Gate

Before every editing task, inspect the complete local state.

At minimum:

```bash
git fetch origin --prune

git branch --show-current
git rev-parse HEAD
git rev-parse main
git rev-parse origin/main
git rev-list --left-right --count main...origin/main

git status --short
git diff --stat
git diff
git diff --cached --stat
git diff --cached

git worktree list --porcelain
git branch --all --verbose --no-abbrev
git stash list
```

Also identify:

- configured upstream;
- detached HEAD;
- merge in progress;
- rebase in progress;
- cherry-pick in progress;
- revert in progress;
- bisect in progress;
- unmerged entries;
- unexplained lock files.

Before editing, confirm:

- active branch is `main`;
- local `main` and `origin/main` are synchronized unless the prompt explicitly resolves divergence;
- staged files are understood;
- unstaged files are understood;
- untracked files are understood;
- linked worktrees are understood;
- local and remote branches are understood;
- stashes are understood;
- no unrelated repository task is active.

A dirty worktree is not automatically a failure.

An unexplained dirty worktree is a stop condition.

---

## Recovery Gate

Before further Work or Codex execution, the repository recovery target is:

- approved completed work consolidated onto `main`;
- local and remote `main` synchronized;
- only proven-safe redundant branches or worktrees removed;
- one clean primary worktree;
- no unexplained stash;
- no unique unpushed commit elsewhere.

Never:

- reset unique work;
- delete an unexplained branch;
- prune an unexplained worktree;
- drop an unexplained stash;
- overwrite a dirty file;
- force-push;
- rewrite published history.

Stop on:

- ambiguous branch;
- dirty linked worktree;
- unique commit;
- unexplained stash;
- staged content outside scope;
- private or sensitive material;
- untracked files with unclear purpose;
- unresolved local and remote divergence.

Tidiness is not proof that deletion is safe.

---

## Direct-to-Main Execution

Perform the approved task directly on `main`.

Before committing:

1. review the complete diff;
2. run all required validation;
3. confirm only authorized and compatible changes are included;
4. verify privacy boundaries;
5. verify documentation claims;
6. fetch `origin` again;
7. stop if `origin/main` advanced unexpectedly.

Stage explicit authorized paths:

```bash
git add -- <authorized-paths>
git diff --cached --stat
git diff --cached
```

After validation:

```bash
git commit -m "<task-specific completed outcome>"
git push origin main
```

Prefer one coherent commit for one approved task unless the prompt requires independently validated commits.

Do not force-push.

Do not create or move a tag unless the prompt explicitly requires it.

---

## Required Final State

After push, verify:

```bash
git fetch origin --prune

git branch --show-current
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main

git status --short
git worktree list --porcelain
git branch --all --verbose --no-abbrev
git stash list
```

A completed task ends with:

- branch `main`;
- `HEAD == origin/main`;
- divergence `0 0`;
- clean primary worktree;
- no legitimate uncommitted change;
- no unpushed commit;
- no leftover task branch;
- no leftover task worktree;
- no unexplained stash;
- no task-owned process where runtime verification occurred.

Do not claim completion before the final gate passes.

---

## Privacy and Repository Safety

Never commit:

- private financial statements;
- credentials or passwords;
- API tokens;
- private keys;
- unsanitized account identifiers;
- private transaction evidence;
- local SQLite databases;
- SQLite `-wal` or `-shm` files;
- DerivedData;
- build products;
- sensitive logs;
- temporary files;
- unexplained generated output;
- source paths;
- private fixture mappings;
- user-specific Xcode state.

Approved fixture evidence must remain sanitized, source-faithful and independently verified.

Project-file edits must be authorized, minimal and Xcode-safe.

Privacy uncertainty is a stop condition.

---

## Baseline Build Configuration

- Xcode project: `LedgerForge.xcodeproj`
- Shared scheme: `LedgerForge`
- Canonical test plan: `TestPlan.xctestplan`
- Platform: macOS
- Primary app target: `LedgerForge`
- Primary test target: `LedgerForgeTests`
- Generic UI-test target: `LedgerForgeUITests`, intentionally disabled unless separately authorized

Canonical Debug build:

```bash
xcodebuild \
  -project LedgerForge.xcodeproj \
  -scheme LedgerForge \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

Canonical TestPlan execution:

```bash
xcodebuild \
  -project LedgerForge.xcodeproj \
  -scheme LedgerForge \
  -destination 'platform=macOS' \
  -testPlan TestPlan \
  test
```

Use the approved prompt, Engineering Standards and Build Conventions for:

- focused tests;
- regression suites;
- Release builds;
- whole-module optimization;
- static analysis;
- migration tests;
- runtime verification;
- subprocess contention;
- Xcode project-integrity checks.

Do not claim a validation boundary that was not freshly executed.

---

## Validation and Stop Conditions

Before commit, at minimum:

```bash
git diff --check
git status --short
git diff --stat
git diff
git diff --cached --stat
git diff --cached
```

Also:

- scan for conflict markers;
- verify privacy;
- validate file references and links;
- confirm migration and schema claims;
- confirm implementation status is not overstated;
- confirm production support is not overstated;
- confirm only authorized files changed;
- inspect fixture and expected-data changes against source authority.

Documentation-only work may skip full executable validation only when unchanged:

- Swift source;
- tests;
- schemas;
- migrations;
- fixtures;
- Xcode project metadata;
- schemes;
- TestPlan;
- build settings;
- assets;
- executable resources.

A project, scheme, TestPlan or build-setting change requires project-integrity validation and an appropriate clean build.

Stop and report when:

- repository baseline differs materially from the prompt;
- local state is ambiguous;
- unique work may be lost;
- remote divergence is unresolved;
- required architecture is absent or contradictory;
- a migration requires guessing;
- source truth is unavailable;
- financial relationships cannot be preserved;
- independent oracle is missing where required;
- provider parity cannot be established;
- zero-residue behavior cannot be proven;
- privacy-sensitive material appears;
- required validation fails;
- runtime process ownership is unclear;
- complete diff cannot be explained;
- scope expands beyond the approved outcome;
- requested output would overstate support.

At a stop condition:

- do not improvise around it;
- do not reduce validation silently;
- do not commit partial failed work as completed;
- do not push;
- report the exact unknown and bounded evidence required.

Manual verification must distinguish:

- passed;
- pending;
- unavailable;
- explicitly accepted deferral.

---

## Durable Project Records

- Verified implementation state belongs in `Project documents/PROJECT_STATE.md`.
- Unscheduled work belongs in `Project documents/FUTURE_WORK.MD`.
- Accepted architecture belongs in `Project documents/ADR.md`.
- Frozen architecture alignment belongs in the Architecture documents.
- Product direction belongs in `Project documents/Product Vision.md`.
- UI authority belongs in Frozen UI/UX and approved assets.
- Engineering policy belongs in `Project documents/Engineering Standards.md`.
- Build, Xcode and Git mechanics belong in `Project documents/BUILD_AND_PROJECT_CONVENTIONS.md`.
- Detailed implementation history belongs in Git.

Do not copy every durable fact into every document.

Conversation memory and uploaded copies remain context only.

---

## Execution Report Minimum

A Codex execution report includes:

- starting ref;
- ending ref;
- branch and worktree state;
- pre-existing changes;
- changed files;
- included scope;
- excluded scope;
- migration impact;
- ADR impact;
- fixture and oracle authority;
- validation commands and results;
- runtime evidence;
- documentation changes;
- staged, unstaged and untracked residue;
- commit SHA;
- tag where applicable;
- push result;
- final `HEAD == origin/main`;
- final worktree state;
- limitations;
- falsification analysis.

Classify material claims as:

- verified;
- reported only;
- contradicted;
- missing.

A green suite is not acceptance evidence until its boundary and oracle independence are checked.

---

## Guide Maintenance

Keep this file compact.

Update it only when:

- bootstrap order changes;
- authority changes;
- role ownership changes;
- the canonical pipeline changes;
- repository safety policy changes;
- baseline build entry points change.

Detailed standards belong in their subject documents.

This file routes and enforces.

It should not become a duplicate of the entire repository handbook.

---

## End of LedgerForge Agent Guide
