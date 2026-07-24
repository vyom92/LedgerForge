# BUILD_AND_PROJECT_CONVENTIONS

**Status:** Active build, Xcode, validation and repository-mechanics policy  
**Status alignment reviewed:** 2026-07-25  
**Repository ref reviewed:** `main@686e3b91bfbf9459a38e9137abee6a2588ecec7f`  
**Latest verified implementation baseline:** `11035461ce3de0f11ae5262bbc8a38b9639607b2` — Sprint 53

## Purpose

This document defines LedgerForge conventions for:

- repository mechanics;
- direct-to-`main` execution;
- Xcode project maintenance;
- build commands;
- test execution;
- static analysis;
- runtime verification;
- documentation reconciliation;
- commit, push and final-state verification.

It complements:

- `AGENTS.md`;
- `Project documents/Project_Guide.md`;
- `Project documents/Engineering Standards.md`;
- `Project documents/Architecture_v1.0_Frozen.md`;
- `Project documents/Database_v1_Architecture.md`;
- `Project documents/ADR.md`;
- `Project documents/UI_UX_v1.0_Frozen.md`;
- `Project documents/PROJECT_STATE.md`;
- `Project documents/FUTURE_WORK.MD`.

This document governs mechanics.

It does not:

- authorize a task;
- select a sprint;
- define product direction;
- define financial truth;
- approve architecture;
- establish production support;
- replace the complete Chat-approved execution prompt.

`AGENTS.md` is the sole mandatory bootstrap entry point.

The complete Chat-approved prompt supplied directly in the current conversation is the sole execution contract.

---

# 1. Authority and Conflict Resolution

Apply authorities in this order for repository execution:

1. the complete Chat-approved prompt;
2. `AGENTS.md`;
3. `Project documents/Project_Guide.md`;
4. `Project documents/PROJECT_STATE.md`;
5. relevant accepted ADRs and frozen architecture;
6. `Project documents/Engineering Standards.md`;
7. this document;
8. exact source, tests, migrations and project metadata.

This ordering does not permit a prompt to waive financial correctness, privacy or accepted architecture without an explicit approved decision.

When documents disagree:

- stop;
- identify the exact conflict;
- inspect current repository evidence;
- do not choose the most convenient interpretation;
- return the conflict to Chat unless the approved prompt already resolves it.

---

# 2. Mode Ownership

## Chat

Chat owns:

- planning;
- prioritization;
- architecture decisions;
- execution-prompt preparation;
- Work and Codex report review;
- acceptance or rejection.

## Work

Work performs bounded, read-only investigation only when Chat identifies an evidence gap that GitHub cannot efficiently resolve.

Work does not:

- edit;
- commit;
- push;
- select work;
- define architecture;
- authorize implementation.

## Codex

Codex performs authorized edits, builds, tests, analysis, runtime verification, documentation execution and Git operations only within the complete approved prompt.

## User changes

The user may modify repository files directly.

Legitimate compatible user changes must be preserved.

They are not automatically in scope for the current task.

Stop when combining them would change the approved outcome, acceptance boundary or commit meaning.

---

# 3. Operating Model

LedgerForge uses a single-person, one-task-at-a-time repository workflow.

Default operating model:

- one `main` branch;
- one primary worktree;
- no pull request;
- no feature branch;
- no parallel editing task;
- direct commit and push to `origin/main` after approval and validation.

A branch, worktree or pull request may be used only when:

1. the user explicitly approves it;
2. a repository-specific reason is recorded;
3. the approved prompt requires that exception.

Generic Git habit is not a repository-specific reason.

---

# 4. Mandatory Pre-Execution Repository Gate

Before any repository edit, collect and inspect the complete local state.

Recommended commands:

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
- in-progress merge;
- rebase;
- cherry-pick;
- revert;
- bisect;
- lock files;
- unmerged entries.

Useful checks:

```bash
git status
git symbolic-ref --quiet --short HEAD
git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'
git diff --name-only --diff-filter=U
```

Before editing, verify:

- active branch is `main`;
- `main` and `origin/main` are synchronized unless the prompt explicitly addresses divergence;
- every staged file is understood;
- every unstaged file is understood;
- every untracked file is understood;
- every linked worktree is understood;
- every local branch is understood;
- every stash is understood;
- no unrelated repository task is active.

A dirty worktree is not automatically an error.

An unexplained dirty worktree is a stop condition.

---

# 5. Recovery Gate

Before further Work or Codex execution, resolve repository recovery state.

The acceptable target is:

- approved completed work consolidated onto `main`;
- local and remote `main` synchronized;
- only safe, proven-redundant branches or worktrees removed;
- one clean primary worktree;
- no unexplained stash;
- no unique unpushed commit outside the approved outcome.

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
- stash containing unexplained work;
- staged content outside scope;
- private or sensitive content;
- untracked files whose purpose is unclear;
- local and remote divergence that the prompt does not resolve.

---

# 6. Existing-Work Reconciliation

Classify every pre-existing change as:

- authorized and part of the current task;
- legitimate and compatible but outside current scope;
- unrelated;
- ambiguous;
- private or sensitive;
- broken;
- incompatible;
- generated residue;
- disposable and proven safe;
- unique work requiring preservation.

Do not stage unrelated legitimate work merely to obtain a clean status.

Do not omit compatible in-scope user work merely because Codex did not create it.

The final commit must remain one coherent approved outcome.

When existing work cannot be included without changing that outcome, stop and return the scope decision to Chat.

---

# 7. Canonical Import and Presentation Pipeline

The current approved pipeline is:

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

No component may bypass the approved ownership boundaries.

Important consequences:

- preparation remains read-only;
- advisory duplicate and identity results are not persistence authority;
- accepted persistence revalidates authoritative claims;
- the provider transaction owns the complete accepted graph;
- runtime state changes only through canonical hydration;
- a committed graph followed by hydration failure remains committed;
- supported event overlap blocks the complete incoming statement;
- exact-content identity and cross-format equivalence remain separate.

---

# 8. Repository-First Implementation

Before adding a repository API:

1. inspect existing protocols;
2. inspect SQLite behavior;
3. inspect In-Memory behavior;
4. inspect DTO ownership;
5. inspect provider-level operations;
6. inspect hydration;
7. inspect tests;
8. identify why existing contracts cannot express the required operation.

A new repository API must have:

- one bounded responsibility;
- typed result;
- deterministic ordering;
- SQLite behavior;
- In-Memory behavior where parity applies;
- provider-generation behavior where relevant;
- failure semantics;
- tests;
- hydration impact.

Do not add a generic transaction closure merely to combine unrelated writes.

Do not coordinate cross-domain atomicity from a View, ViewModel or ordinary service.

---

# 9. Xcode Project Baseline

Current project baseline:

```text
Project: LedgerForge.xcodeproj
Shared scheme: LedgerForge
Canonical test plan: TestPlan.xctestplan
Platform: macOS
Primary application target: LedgerForge
Primary test target: LedgerForgeTests
Generic UI-test target: LedgerForgeUITests
```

`LedgerForgeUITests` remains intentionally disabled unless an approved prompt changes that state.

Never infer current scheme, target or test-plan behavior from memory.

Verify it from the exact repository.

---

# 10. Xcode Project File Safety

When adding or moving files:

1. prefer filesystem-synchronized group behavior where the project already uses it;
2. prefer Xcode-safe project operations;
3. use supported project tooling where available;
4. edit `project.pbxproj` manually only when necessary and authorized;
5. keep the diff minimal;
6. verify target membership;
7. validate project integrity immediately.

Do not:

- reformat the whole project file;
- reorder unrelated objects;
- regenerate identifiers without need;
- change build settings outside scope;
- change target membership by assumption;
- add duplicate file references;
- add duplicate build phases;
- commit user-specific scheme state;
- commit breakpoint state;
- commit Finder or IDE residue.

Do not commit:

- `xcuserdata`;
- user breakpoints;
- Find Navigator state;
- personal scheme-management state;
- per-user workspace settings.

---

# 11. Adding Source Files and Target Membership

Before adding a file:

- confirm it is required;
- choose the correct repository directory;
- verify naming;
- verify its header comment where used;
- verify target membership;
- verify build-phase membership;
- verify test-target membership for tests;
- verify no duplicate reference exists.

After adding:

```bash
xcodebuild -list -project LedgerForge.xcodeproj
```

Then run an appropriate build.

Typical intent:

| File family | Expected target |
|---|---|
| App source | LedgerForge |
| Runtime stores | LedgerForge |
| Services and coordinators | LedgerForge |
| Readers, parsers and detectors | LedgerForge |
| Unit and integration tests | LedgerForgeTests |
| Generic UI tests | LedgerForgeUITests, only when explicitly enabled |
| Fixtures | Test resources or repository evidence according to current structure |

Always inspect actual membership.

A file existing on disk does not prove it is compiled.

---

# 12. Project-Integrity Validation

A change to any of the following requires project-integrity validation:

- `project.pbxproj`;
- shared scheme;
- test plan;
- target membership;
- build setting;
- entitlement;
- asset catalog;
- resource phase;
- package dependency;
- signing configuration.

Minimum checks:

```bash
git diff --check
xcodebuild -list -project LedgerForge.xcodeproj
xcodebuild \
  -project LedgerForge.xcodeproj \
  -scheme LedgerForge \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

A project-file change is not documentation-only work.

---

# 13. Canonical Build Commands

## Debug build

```bash
xcodebuild \
  -project LedgerForge.xcodeproj \
  -scheme LedgerForge \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

## Release build

When required:

```bash
xcodebuild \
  -project LedgerForge.xcodeproj \
  -scheme LedgerForge \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

Use the exact Release optimization or whole-module settings required by the approved prompt.

Do not claim optimized Release verification when only a default build ran.

## Isolated DerivedData

Prefer an isolated DerivedData path when reproducibility matters or stale build products are suspected.

Example:

```bash
DERIVED_DATA="$(mktemp -d "${TMPDIR:-/tmp}/LedgerForge-DD.XXXXXX")"

xcodebuild \
  -project LedgerForge.xcodeproj \
  -scheme LedgerForge \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build
```

Remove only the task-owned temporary path.

---

# 14. Canonical Test Execution

## Full TestPlan

```bash
xcodebuild \
  -project LedgerForge.xcodeproj \
  -scheme LedgerForge \
  -destination 'platform=macOS' \
  -testPlan TestPlan \
  test
```

## Focused tests

Use `-only-testing:` for the smallest meaningful boundary.

Example shape:

```bash
xcodebuild \
  -project LedgerForge.xcodeproj \
  -scheme LedgerForge \
  -destination 'platform=macOS' \
  -testPlan TestPlan \
  -only-testing:LedgerForgeTests/<SuiteOrTest> \
  test
```

Do not guess test identifiers.

Report:

- command;
- configuration;
- destination;
- test plan;
- focused selectors;
- number of tests or suites where available;
- failures;
- unexpected skips.

Do not report “all tests passed” when only focused tests ran.

---

# 15. Static Analysis

Run static analysis when required by the approved prompt, risk or acceptance boundary.

Example:

```bash
xcodebuild \
  -project LedgerForge.xcodeproj \
  -scheme LedgerForge \
  -configuration Debug \
  -destination 'platform=macOS' \
  analyze
```

Repeat for Release when required.

Report analyzer findings separately from compiler warnings.

---

# 16. Validation Order

Default rhythm:

```text
inspect authority and repository state
    ↓
implement one coherent boundary
    ↓
compile or build
    ↓
run focused tests
    ↓
review diff and behavior
    ↓
continue
    ↓
run required regression validation
    ↓
run required Release and analysis
    ↓
run required runtime verification
    ↓
reconcile documentation
    ↓
perform Git gate
```

A coherent boundary may span several files.

Do not impose “one file at a time” when the approved outcome requires coordinated domain, provider, migration, hydration, test and UI changes.

Do not implement an entire high-risk sprint before the first compile.

---

# 17. Validation Matrix

## Documentation-only change

Required:

- current-ref verification;
- authority review;
- complete diff review;
- `git diff --check`;
- conflict-marker scan;
- link and path review;
- privacy review;
- status-claim verification;
- Git-state verification.

May omit full build and tests only when unchanged:

- executable source;
- tests;
- schema;
- migrations;
- fixtures;
- Xcode project metadata;
- schemes;
- test plan;
- build settings;
- assets;
- executable resources.

## Swift source change

Required at minimum:

- Debug build;
- focused tests;
- relevant regression tests;
- complete diff review.

Add Release, full TestPlan, analysis and runtime verification according to risk and prompt.

## Parser or import change

Required:

- approved source evidence;
- independent oracle;
- malformed evidence;
- unsupported evidence;
- financial invariants;
- duplicate behavior;
- identity behavior;
- zero accepted residue on rejection;
- provider parity where persistence changes;
- hydration and relaunch where durable behavior changes;
- production-support claim review.

## Migration or database change

Required:

- migration preflight;
- fresh database;
- every supported predecessor;
- checksum and chain validation;
- failure injection;
- no partial schema publication;
- SQLite behavior;
- In-Memory behavior where applicable;
- provider reconstruction;
- hydration;
- relaunch;
- privacy review.

## UI change

Required:

- approved asset/specification review;
- Debug build;
- focused tests;
- accessibility review;
- runtime verification where appearance or interaction matters;
- repository-backed truth review;
- unavailable and empty-state review.

## Xcode project or build-setting change

Required:

- project-integrity validation;
- target membership;
- scheme and TestPlan review;
- clean Debug build;
- applicable tests;
- Release verification when configuration-sensitive.

## Concurrency or lifecycle change

Required:

- same-process evidence;
- independent-provider evidence where relevant;
- separate-process evidence where claimed;
- contention outcomes;
- failure residue;
- provider generation;
- stale-reference behavior;
- shutdown or cleanup evidence;
- no leftover task-owned process.

---

# 18. Runtime Verification

Runtime verification is required when automated evidence cannot establish the user-visible or process-level boundary.

Examples:

- application launch;
- sidebar navigation;
- import preview;
- identity review;
- explicit confirmation;
- durable result presentation;
- provider replacement;
- reset and recovery;
- hydration after relaunch;
- multiple-process contention;
- accessibility behavior;
- approved visual fidelity.

Before runtime verification:

- identify existing LedgerForge processes;
- stop only processes proven safe to stop;
- verify the binary being launched;
- avoid attaching to a stale DerivedData build;
- use a task-owned runtime environment where required.

After runtime verification:

- terminate task-owned LedgerForge processes;
- verify no task-owned helper remains;
- preserve unrelated processes;
- report process cleanup.

No permanent repository-owned singleton launch script currently exists.

---

# 19. Approved-Fixture Runtime Verification

A DEBUG-only approved-fixture launcher may be used when authorized.

It must enter the ordinary production path and preserve:

- reading;
- detection;
- classification;
- parser selection;
- validation;
- duplicate/event evaluation;
- account/identity review;
- explicit confirmation;
- provider-owned persistence;
- canonical hydration.

It must not:

- inject expected results;
- bypass readers or parsers;
- auto-confirm;
- write directly to repositories;
- use private statements;
- exist in optimized Release builds.

Native macOS file selection should receive a bounded smoke test when required.

---

# 20. Hydration Conventions

`RepositoryStoreHydrator` is the sole persistence-to-runtime boundary.

Hydration occurs:

- at startup;
- after successful accepted import;
- after approved repository mutation;
- after provider replacement;
- after development reset;
- after recovery;
- after explicit reload where approved;
- after future mutation families commit.

Hydration must:

- use one authoritative provider generation;
- map complete required state;
- fail before publication when trusted evidence is malformed;
- publish observer-consistent state;
- avoid duplicate runtime records;
- preserve durable repository IDs;
- avoid manual store patching.

A hydration failure after durable commit does not erase the commit.

Report it as committed but reconciliation failed.

---

# 21. Documentation Workflow

Update only the documents whose authority changed.

| Change | Primary authority |
|---|---|
| Verified current state | `PROJECT_STATE.md` |
| Unscheduled work | `FUTURE_WORK.MD` |
| Architecture decision | `ADR.md` |
| Frozen architecture | `Architecture_v1.0_Frozen.md` |
| Database design | `Database_v1_Architecture.md` |
| Product direction | `Product Vision.md` |
| UI authority | `UI_UX_v1.0_Frozen.md` |
| Engineering policy | `Engineering Standards.md` |
| Build and repository mechanics | This document |
| Detailed implementation history | Git |

The approved flow is:

```text
Chat supplies complete prompt
    ↓
Codex reconciles current repository evidence
    ↓
Codex edits authorized documents
    ↓
Codex validates references, privacy and consistency
    ↓
Codex commits and pushes
    ↓
Codex reports directly in chat
    ↓
Chat verifies and returns acceptance classification
```

Documentation-only verification includes:

- exact current ref;
- title and path;
- links;
- candidate IDs;
- ADR numbering;
- migration numbers;
- implementation status;
- production support;
- duplicated authority;
- private data;
- unsupported claims.

---

# 22. Diff and Residue Review

Before staging:

```bash
git diff --check
git diff --stat
git diff
git status --short
```

Review for:

- accidental deletion;
- broad formatting churn;
- generated identifiers;
- project-file noise;
- private data;
- debug code;
- temporary flags;
- dead code;
- stale comments;
- unsupported documentation claims;
- unexpected fixture changes;
- changed migration checksums;
- altered expected data without source authority.

Conflict and residue checks:

```bash
git diff --name-only --diff-filter=U
git grep -n -E '^(<<<<<<<|=======|>>>>>>>)' -- .
git status --short
```

Inspect for:

- `.DS_Store`;
- local SQLite files;
- `-wal`;
- `-shm`;
- DerivedData;
- `.xcuserstate`;
- temporary screenshots;
- logs;
- editor swap files;
- untracked reports;
- private documents.

An unexplained diff is a failure.

---

# 23. Privacy Gate

Never commit:

- private financial statements;
- credentials;
- passwords;
- API tokens;
- private keys;
- unsanitized identifiers;
- private transaction evidence;
- local databases;
- SQLite sidecars;
- unrestricted logs;
- source paths;
- private fixture mappings;
- temporary files;
- user-specific Xcode state.

Before staging fixtures or documents, inspect:

- metadata;
- filenames;
- embedded paths;
- PDF objects;
- attachments;
- comments;
- image layers;
- account suffixes;
- merchant names;
- transaction references.

Privacy uncertainty is a stop condition.

---

# 24. Staging Conventions

Stage explicit authorized paths.

Prefer:

```bash
git add -- <authorized-path-1> <authorized-path-2>
```

Review:

```bash
git diff --cached --stat
git diff --cached
```

The staged set must:

- match approved scope;
- include required compatible in-scope user work;
- exclude unrelated work;
- exclude generated residue;
- preserve privacy;
- form one coherent commit.

Do not rely on `git add -A` as a substitute for understanding the repository.

---

# 25. Commit Conventions

Commit messages describe completed work.

Preferred shape:

```text
<type>: <specific completed outcome>
```

Examples:

```text
fix: reject malformed trusted provenance
feat: share Axis bank-account CSV profile
docs: reconcile database architecture
test: cover atomic identifier contention
```

Do not overstate:

- production support;
- migration completion;
- runtime verification;
- institution coverage;
- concurrency guarantees.

One approved task usually produces one coherent commit.

Use multiple commits only when the prompt requires separately validated outcomes.

---

# 26. Remote Revalidation and Push

Before committing:

```bash
git fetch origin --prune
git rev-list --left-right --count main...origin/main
```

Stop if `origin/main` advanced unexpectedly.

After commit and before push:

```bash
git status --short
git log -1 --oneline
git rev-list --left-right --count main...origin/main
```

Push:

```bash
git push origin main
```

Do not force-push.

Do not push an unauthorized branch.

---

# 27. Tags

Create a tag only when:

- the approved prompt requires it;
- repository convention supports it;
- the target commit is final;
- validation is complete;
- the tag name is approved.

A sprint number does not automatically require a tag.

Do not move a published tag without explicit authorization.

---

# 28. Final Repository Gate

After push:

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

Required final state:

- branch is `main`;
- `HEAD == origin/main`;
- divergence is `0 0`;
- primary worktree is clean;
- no legitimate uncommitted change remains;
- no unpushed commit remains;
- no task branch remains;
- no task worktree remains;
- no unexplained stash remains;
- no task-owned process remains where runtime work occurred.

Do not report completion until the final gate passes.

---

# 29. Reporting Conventions

Execution reports include:

- starting ref;
- ending ref;
- branch;
- worktree state;
- local/remote divergence;
- pre-existing changes;
- changed files;
- included scope;
- excluded scope;
- migration impact;
- ADR impact;
- fixture/oracle authority;
- validation commands;
- validation results;
- runtime evidence;
- documentation updates;
- staged residue;
- unstaged residue;
- untracked residue;
- commit SHA;
- tag where applicable;
- push result;
- final `HEAD == origin/main`;
- final worktree status;
- limitations;
- falsification analysis.

Classify material claims as:

- verified;
- reported only;
- contradicted;
- missing.

Do not report “tests passed” without the exercised boundary.

---

# 30. Stop Conditions

Stop and report when:

- current baseline differs materially from the prompt;
- branch or worktree state is ambiguous;
- unique work may be lost;
- remote divergence is unresolved;
- architecture is contradictory;
- required ADR is absent;
- migration requires guessing;
- source truth is unavailable;
- financial relationships cannot be preserved;
- independent oracle is missing where required;
- privacy-sensitive material appears;
- project file cannot be safely modified;
- required validation fails;
- runtime process ownership is unclear;
- complete diff cannot be explained;
- provider parity cannot be established;
- zero-residue behavior cannot be proven;
- accepted scope expands during implementation;
- required output would overstate production support.

At a stop condition:

- do not improvise around it;
- do not reduce validation silently;
- do not commit partial failed work as completed;
- do not push;
- report the exact unknown and required evidence.

---

# 31. Common Failure Patterns

Avoid:

- obsolete pipeline diagrams;
- stale preparation treated as confirmation authority;
- independent account or identifier writes outside the accepted import transaction;
- runtime-store patching;
- SQLite access from presentation code;
- repository APIs created without parity requirements;
- parser output used as its own oracle;
- fixture presence treated as production support;
- branch creation by habit;
- worktree creation by tool default;
- broad staging without review;
- committing all dirty files merely to obtain cleanliness;
- editing applied migrations;
- project-file churn;
- user-specific Xcode state;
- expected data regenerated from production output;
- manual verification reported as automated;
- documentation claims copied from an older sprint;
- ceremonial tags.

---

# 32. Definition of Successful Execution

An executable task is successful only when all applicable conditions hold.

## Repository

- correct starting baseline verified;
- no unexplained local state;
- one approved task active;
- authorized scope only;
- complete diff understood.

## Implementation

- approved outcome complete;
- exclusions preserved;
- architecture followed;
- no unsupported behavior introduced;
- no opportunistic unrelated refactor.

## Validation

- required builds pass;
- focused tests pass;
- required regression suites pass;
- required Release verification passes;
- required static analysis passes;
- required runtime checks pass or are explicitly accepted as deferred;
- migration and provider evidence pass where relevant;
- privacy checks pass.

## Documentation

- verified durable facts recorded in subject authorities;
- architecture updated only when changed;
- queue updated only when authorized;
- production support described precisely;
- implementation history preserved in Git.

## Git

- staged set reviewed;
- coherent commit created;
- push succeeds;
- tag handled only when required;
- final `HEAD == origin/main`;
- clean primary worktree;
- no task residue.

A documentation-only task uses its applicable documentation boundary.

It does not need a ceremonial Swift build when executable state is provably unchanged.

---

# 33. Living-Document Policy

Update this document only when repeated repository experience establishes a durable mechanics rule.

Do not update it for:

- one transient Xcode failure;
- one local machine preference;
- one temporary tool outage;
- one sprint-specific command;
- one-off workaround;
- speculative future workflow.

Promote a convention only when it is:

- repeatable;
- repository-specific;
- evidence-backed;
- compatible with `AGENTS.md`;
- compatible with Engineering Standards;
- useful across multiple tasks.

When this document changes, review duplication with:

- `AGENTS.md`;
- `Project_Guide.md`;
- `Engineering Standards.md`.

Keep one primary authority and cross-reference it.

---

## End of Build and Project Conventions
