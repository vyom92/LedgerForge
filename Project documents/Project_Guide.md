# LedgerForge Project Guide

**Status:** Active repository routing guide  
**Alignment reviewed:** 2026-07-25

## Purpose

This is the concise human-readable map for the LedgerForge repository.

Begin with the repository-root `AGENTS.md`. It is the sole mandatory bootstrap entry point.

This guide routes a task to the correct subject authorities. It does not duplicate their complete rules and does not authorize work.

The complete Chat-approved prompt supplied directly in the current conversation is the sole execution contract.

There is no repository-stored active work contract.

---

## Authority Model

Use the least broad authoritative source that can answer the question.

| Question | Primary authority |
|---|---|
| What is verified in the current repository? | Exact repository evidence and `Project documents/PROJECT_STATE.md` |
| What may be executed now? | The complete Chat-approved prompt in the current conversation |
| What remains unscheduled? | `Project documents/FUTURE_WORK.MD` |
| What architecture is accepted? | `Project documents/ADR.md` and `Project documents/Architecture_v1.0_Frozen.md` |
| What is the database design? | `Project documents/Database_v1_Architecture.md`, accepted ADRs and registered migrations |
| What is product direction? | `Project documents/Product Vision.md` |
| What UI is approved? | `Project documents/UI_UX_v1.0_Frozen.md` and approved assets |
| What engineering, privacy and verification standards apply? | `AGENTS.md` and `Project documents/Engineering Standards.md` |
| What build, Xcode and Git mechanics apply? | `Project documents/BUILD_AND_PROJECT_CONVENTIONS.md` |
| What happened historically? | Git history and historical ADR text |
| What is true only in the local checkout? | Direct local evidence, normally through bounded Work investigation |

When authorities conflict:

1. identify the exact conflict;
2. inspect the current exact ref;
3. apply accepted ADRs over older frozen baseline text where they supersede it;
4. do not choose the most convenient interpretation;
5. stop and return the unresolved decision to Chat.

Memory, uploaded copies and earlier conversations provide context only. They do not override current repository evidence.

---

## Repository Map

| Path | Purpose |
|---|---|
| `AGENTS.md` | Mandatory bootstrap, role ownership, repository workflow and core invariants |
| `Project documents/Project_Guide.md` | This routing map |
| `Project documents/PROJECT_STATE.md` | Verified current repository reality |
| `Project documents/FUTURE_WORK.MD` | Canonical unscheduled queue |
| `Project documents/ADR.md` | Accepted architectural decisions and historical decision record |
| `Project documents/Architecture_v1.0_Frozen.md` | Frozen system architecture and compatibility boundary |
| `Project documents/Database_v1_Architecture.md` | Persistence, migration and database-design boundary |
| `Project documents/Product Vision.md` | Long-term product direction |
| `Project documents/UI_UX_v1.0_Frozen.md` | Frozen UI/UX authority |
| `Project documents/UI Assets/Approved/` | Approved visual references |
| `Project documents/Engineering Standards.md` | Financial correctness, privacy, evidence and verification policy |
| `Project documents/BUILD_AND_PROJECT_CONVENTIONS.md` | Build, Xcode, validation and Git mechanics |
| `LedgerForgeTests/` | Automated tests and approved fixture evidence |
| Registered migrations | Exact executable schema authority |
| Production source | Verified implementation behavior when documentation is insufficient |

Do not treat a document list as an instruction to read everything.

Load only the authorities required by the task.

---

## Current Import Architecture

The approved production flow is:

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

Key boundaries:

- readers understand source formats;
- parsers own financial interpretation and verified financial identifiers;
- validation precedes accepted persistence;
- preparation and review are read-only;
- advisory duplicate and identity results are not confirmation-time authority;
- the provider revalidates the accepted plan inside one atomic operation;
- rejected or losing accepted operations leave zero accepted financial residue;
- `RepositoryStoreHydrator` is the sole persistence-to-runtime boundary;
- runtime stores are projections, not durable truth.

The current production-support boundary belongs only in `PROJECT_STATE.md`.

A reader, parser, protocol, fixture, schema table or visually similar layout does not establish support.

---

## Role Ownership

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

Work performs bounded, read-only investigation only when GitHub cannot efficiently establish a decision-critical fact.

Before escalation, Chat states:

1. the exact unknown;
2. why it affects the decision;
3. the bounded evidence Work must return.

Work may investigate:

- local or unpushed state;
- linked worktrees;
- filesystem or Xcode configuration;
- build, test or runtime evidence;
- broad cross-file tracing;
- one unresolved architecture boundary.

Work does not:

- edit files;
- select a sprint;
- define architecture;
- commit;
- push;
- create branches or pull requests.

### Codex

Codex performs only the edits, builds, tests, documentation updates and Git operations authorized by the complete Chat-approved prompt.

Codex reports evidence and limitations directly in chat.

### User edits

The user may edit repository files directly.

Legitimate compatible user work must be preserved and reconciled.

Unrelated, ambiguous, private, incompatible or unsafe work is a stop condition, not permission to discard it.

---

## Tool Routing

Use the least invasive authoritative tool.

| Need | Preferred route |
|---|---|
| Pushed files, refs, commits, issues, PRs or CI | GitHub |
| Local branch, dirty worktree, stashes, linked worktrees or unpushed commits | Work or direct local evidence |
| SwiftUI, AppKit, Xcode, signing, packaging or macOS runtime expertise | Build macOS Apps guidance, subordinate to accepted ADRs |
| Current official external documentation | Browser |
| Approved visual comparison | Figma and approved assets |
| Explicitly relevant supporting material outside GitHub | Google Drive |
| Artifact creation or conversion | Only when explicitly requested |

Do not inspect GitHub through Browser or Computer Use when the GitHub connector can answer.

Do not infer local state from pushed GitHub state.

---

## Task Routing

| Task | Read next |
|---|---|
| Sprint planning or backlog review | `PROJECT_STATE.md` → `FUTURE_WORK.MD` → relevant ADRs, architecture, code/tests and fixtures |
| Report review | Exact starting/ending refs → changed files → relevant authorities → tests, oracles, documentation and Git residue |
| Swift implementation | `PROJECT_STATE.md` → approved prompt → relevant ADRs/architecture → Engineering Standards → source/tests |
| Database or migration work | Database Architecture → relevant ADRs → registered migrations → providers/DTOs/tests |
| Import, reader or parser work | Architecture → relevant ADRs → Engineering Standards → approved fixtures and independent expected evidence |
| Identity or duplicate work | ADR-027 through ADR-031 and ADR-038/039 as relevant → providers/tests/fixtures |
| Money or currency work | ADR-033 → Engineering Standards → providers/hydration/presentation tests |
| Category work | ADR-036 → current transaction identity and hydration → UI authority → migration/provider tests |
| Financial mutation or repair | ADR-037 → one concrete family → provider/migration/hydration and audit boundary |
| UI implementation | Frozen UI/UX → approved assets → Architecture → Engineering Standards → repository-backed state |
| Build or Xcode project work | Build Conventions → `AGENTS.md` → exact project/scheme/TestPlan state |
| Documentation alignment | Affected subject authorities → current exact ref → complete prompt → cross-document consistency |
| Local repository recovery | `AGENTS.md` and Build Conventions → bounded local evidence before any edit |
| External technical dependency | Current official documentation, then reconcile with accepted repository architecture |

Use only the documents required by the task.

Do not invent:

- a sprint;
- a production-support claim;
- an architecture decision;
- a migration;
- a fixture baseline;
- local repository state.

---

## Planning Route

For sprint planning:

1. identify the exact inspected ref;
2. establish the verified baseline from `PROJECT_STATE.md`;
3. review `FUTURE_WORK.MD` in P0, P1, P2, P3 order;
4. distinguish priority from readiness;
5. classify every serious higher-priority candidate;
6. inspect focused code, tests and fixtures only where documentation is insufficient;
7. compare the strongest plausible candidates;
8. define included scope, exclusions, acceptance boundary and stop conditions;
9. state migration and ADR impact;
10. identify remaining evidence gaps;
11. use Work only for a named bounded gap that GitHub cannot resolve.

A lower-priority item is not selected merely because it is easier.

Candidates are combined only when they produce one outcome, share one architectural boundary and can be validated by one bounded acceptance plan.

Sprint selection does not authorize implementation.

---

## Execution Lifecycle

The default lifecycle is:

```text
Verified repository state
    ↓
Approved scope and execution prompt
    ↓
Complete local repository preflight
    ↓
Recovery gate, if needed
    ↓
Full-repository reconciliation
    ↓
Authorized edit
    ↓
Focused build/test feedback
    ↓
Required regression, Release, analysis and runtime verification
    ↓
Authorized documentation reconciliation
    ↓
Complete diff, privacy and Git review
    ↓
Commit
    ↓
Push to origin/main
    ↓
Verify clean main == origin/main
    ↓
Direct evidence report
```

Default repository model:

- one `main` branch;
- one primary worktree;
- one active repository task;
- no pull request;
- no feature branch;
- no extra worktree.

A branch, worktree or pull request requires explicit user approval, a repository-specific reason and an approved prompt requiring the exception.

---

## Local Repository Gate

Before Codex execution, verify:

- current branch and HEAD;
- `main`;
- `origin/main`;
- divergence;
- staged changes;
- unstaged changes;
- untracked files;
- linked worktrees;
- local and remote branches;
- stashes;
- in-progress Git operations.

Never delete, reset, drop, prune, overwrite or force-push unique or unexplained work.

The required recovery target is:

- approved completed work consolidated onto `main`;
- local and remote `main` synchronized;
- only proven-safe redundant branches/worktrees removed;
- one clean primary worktree;
- no unexplained stash;
- no unique unpushed commit elsewhere.

Stop on ambiguity.

---

## Financial Evidence Route

For financial-correctness work:

- source semantics outrank parser-derived expected output;
- production parser output cannot be its own sole oracle;
- preserve native currency, scale, direction, date meaning, source order, balances, identifiers and provenance;
- fail closed on malformed, ambiguous, conflicting or unsupported evidence;
- verify zero accepted durable residue on rejection;
- require SQLite/In-Memory parity where both matter;
- verify persistence, hydration, provider reconstruction, relaunch and presentation;
- do not infer support from structural similarity;
- do not invent historical evidence;
- keep sanitized fixtures in Git and private originals outside it.

Distinguish:

- source truth;
- implementation behavior;
- test evidence;
- inference.

A green suite proves only the boundary and oracle it actually exercises.

---

## Report Review Route

Treat Work and Codex reports as claims requiring verification.

Classify material claims as:

- verified;
- reported only;
- contradicted;
- missing.

Verify at minimum:

- starting and ending refs;
- branch and worktree handling;
- changed files;
- included and excluded scope;
- migration impact;
- ADR impact;
- fixture and oracle authority;
- what tests actually exercise;
- persistence, hydration and relaunch where relevant;
- documentation changes;
- staged, unstaged and untracked residue;
- commit and push result;
- final `main == origin/main`;
- limitations;
- falsification analysis.

A green suite is not acceptance evidence until its boundary and oracle independence are checked.

---

## Reference Fixtures

Approved sanitized or clean-room fixtures and their independent expected evidence define only the claims covered by their tests and metadata.

Fixture presence does not establish:

- production reader support;
- production parser support;
- institution-wide support;
- another source format;
- durable persistence;
- hydration;
- UI support;
- exact-content identity.

Private statements, credentials and unrestricted source evidence never enter Git.

Use OCR only when reliable native extraction is unavailable and the approved evidence boundary requires it.

---

## Documentation Rules

Verified durable facts belong only in their subject authorities.

| Fact | Authority |
|---|---|
| Current implementation state | `PROJECT_STATE.md` |
| Unscheduled work | `FUTURE_WORK.MD` |
| Accepted architecture | `ADR.md` |
| Frozen architecture alignment | Architecture documents |
| Product direction | Product Vision |
| Approved UI | Frozen UI/UX and assets |
| Engineering policy | Engineering Standards |
| Build and Git mechanics | Build Conventions |
| Detailed implementation history | Git |

Do not turn every document into a duplicate project-state ledger.

When architecture changes, review:

- ADR;
- frozen Architecture;
- Database Architecture where relevant;
- Engineering Standards;
- UI/UX where relevant;
- `PROJECT_STATE.md`;
- `FUTURE_WORK.MD` only when queue reconciliation is explicitly authorized.

---

## Documentation-Only Cycles

Documentation-only work may skip full executable validation only when all of the following remain unchanged:

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

Every documentation-only cycle still requires:

- exact-ref verification;
- authority review;
- complete diff review;
- conflict-marker scan;
- link and path validation;
- privacy review;
- status-claim verification;
- Git-state verification.

A `project.pbxproj`, scheme, TestPlan or build-setting change is not documentation-only work.

---

## Stop Conditions

Stop rather than improvise when:

- the repository baseline differs materially from the approved prompt;
- local state is ambiguous;
- unique work may be lost;
- remote divergence is unresolved;
- required architecture is absent or contradictory;
- a migration requires guessing;
- source truth is unavailable;
- financial relationships cannot be preserved;
- the independent oracle is missing;
- privacy-sensitive material appears;
- required validation fails;
- the complete diff cannot be explained;
- provider parity cannot be established;
- zero-residue behavior cannot be proven;
- requested work would overstate production support.

Report the exact unknown and the bounded evidence required to continue.

---

## Guide Maintenance

This guide should remain concise.

Update it only when:

- a subject authority changes;
- role ownership changes;
- task routing changes;
- the canonical pipeline changes;
- the repository lifecycle changes.

Do not copy detailed rules from Engineering Standards or Build Conventions into this guide unless the routing decision itself depends on them.

When this guide conflicts with a subject authority, repair the guide rather than broadening its authority.

---

## End of Project Guide
