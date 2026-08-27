# LedgerForge Agent Bootstrap

## Purpose

This file is the mandatory repository entry point for LedgerForge agents and execution sessions.

LedgerForge is a private, single-user, offline-first macOS personal-finance application built with Swift and SwiftUI.

Apply this priority order:

1. financial correctness;
2. durable persistence;
3. deterministic behaviour;
4. explicit user control;
5. privacy;
6. recoverability;
7. explainability;
8. maintainability;
9. delivery speed.

A faster implementation never outranks a higher-priority invariant.

---

## Mandatory bootstrap

For every LedgerForge planning, implementation, review, recovery or documentation task:

1. Read this file.
2. Read the complete Chat-approved task prompt, if one exists.
3. Establish the exact repository ref and local worktree state mechanically.
6. Read the relevant current sections of `Project documents/PROJECT_STATE.md`.
7. Read `Project documents/FUTURE_WORK.MD` when selecting, comparing, deferring or reconciling unscheduled work.
8. Read relevant accepted entries in `Project documents/ADR.md` before changing architecture, persistence, identity, import semantics, credential ownership or domain ownership.
9. Inspect production code, tests, private-source evidence or local build/runtime evidence only where the documents are insufficient.

Do not infer current sprint status, accepted support, migration version, architecture or local Git state from memory or an older report.

The complete Chat-approved prompt is the execution contract for the current task. Repository documents provide durable context and constraints; they do not independently authorize implementation.

---

## Authority map

| Question | Primary authority |
|---|---|
| What is accepted production reality? | Exact repository evidence + `PROJECT_STATE.md` |
| What sprint/correction is current? | Current cycle roadmap |
| What may execute now? | Complete Chat-approved prompt |
| What reusable execution method applies? | Standing execution harness |
| What remains unscheduled? | `FUTURE_WORK.MD` |
| What architecture is accepted? | Accepted ADR entries |
| What is product direction? | `Product Vision.md` |
| What UI is approved? | Frozen UI/UX documents and approved assets |
| What build/Xcode/Git rules apply? | `BUILD_AND_PROJECT_CONVENTIONS.md` |
| What is true only on the local Mac? | Direct local evidence through MCP executor or the selected local execution environment |
| What happened historically? | Git history and historical ADR text |

When authorities conflict:

1. identify the exact conflict;
2. inspect the exact current ref;
3. distinguish accepted production state from active unaccepted WIP;
4. prefer authentic source truth and current production evidence over derived fixtures;
5. apply explicit user decisions until superseded;
6. stop rather than select the most convenient interpretation.

---

## Chat, MCP executor, Codex and model tiers

These are different concepts. Do not conflate them.

### ChatGPT Chat

Chat is the LedgerForge coordinator and decision owner.

Chat owns:

- sprint selection, numbering and corrective classification;
- architecture and financial-semantics decisions;
- task/prompt preparation;
- reconciliation of roadmap, state and ADR implications;
- review of implementation reports and evidence;
- final technical acceptance;
- authorization of publication, commit and push.

Planning does not authorize implementation.

### MCP executor

`MCP executor` is a ChatGPT plugin/tool that gives a regular Chat session guarded access to the local Mac LedgerForge repository, Xcode/build/test environment and approved local evidence roots.

It is:

- not a model;
- not Codex;
- not a source of project authorization;
- mechanically fenced by exact HEAD/worktree/index checks and an execution lease for writes.

Chat may use MCP executor read-only for local evidence at any time. Chat may use it for implementation only when the user or a Chat-approved execution contract authorizes that route.

The MCP writer lease fences MCP writes only. It cannot prevent an independent Codex/local process from editing the same worktree. Concurrent external writers are therefore a stop condition.

### Codex

Codex is a separate execution environment/session.

Codex does not automatically inherit:

- this Chat conversation;
- Chat-only attachments;
- unstated user decisions;
- private context that exists only in another session.

A Codex task must therefore receive a self-contained Chat-approved execution prompt and must read the repository-local bootstrap, roadmap, harness, state and relevant ADRs.

Codex must not redesign the sprint, widen support claims, reinterpret source truth or continue past a stop condition.

### Model hierarchy

Model capability is orthogonal to execution environment.

LedgerForge model order is:

1. **Sol** — highest reasoning tier; use for architecture-sensitive implementation, financial-correctness work, migrations, credential semantics and difficult cross-layer debugging.
2. **Terra** — second tier; use for strong independent/adversarial review, bounded implementation with settled architecture, and broad evidence analysis.
3. **Luna** — third tier; use for bounded mechanical cleanup, straightforward test maintenance and narrow tasks after causal ownership is established.

Model choice never grants authority or changes repository safety rules.

---

## One-writer rule

Default repository workflow is one `main` branch, one primary worktree and one active writer.

Before any write:

- verify branch and exact HEAD;
- verify `main`/`origin/main` divergence;
- inspect staged, unstaged and untracked paths;
- inspect linked worktrees, branches and stashes;
- inspect active Git operations;
- identify active Codex/local/MCP writers or validations;
- preserve unexplained work.

Never run MCP writes while an independent Codex/local writer is actively changing the same worktree.

Never reset, restore, clean, stash, prune, overwrite or delete unique/unexplained work.

A dirty worktree is not automatically a failure. An unexplained dirty worktree is a stop condition.

---

## Financial truth

For financial imports, persistence, identity, balances, cards, salary, investments or valuation:

- authentic source semantics outrank fixtures and generated expected data;
- production parser output must not be its own sole oracle;
- preserve native currency, scale, liability/direction semantics, date meaning, source order, balances, identifiers, multiplicity and provenance;
- fail closed on malformed, ambiguous, conflicting or unsupported evidence;
- verify zero accepted durable residue on rejection;
- require SQLite/In-Memory parity where both matter;
- verify persistence, provider reconstruction, close/reopen, hydration and presentation;
- never infer institution, format, layout, account identity or credential family from structural similarity alone;
- never invent dates, ordering, identifiers, balances or provenance;
- keep private originals isolated and read-only;
- keep only sanitized, source-faithful fixtures in Git.

A green suite proves only the boundary and oracle it exercised.

---

## Validation policy

Start with the smallest validation that can falsify the changed boundary.

Run the complete `TestPlan.xctestplan` only when a recorded trigger applies, including:

- final integrated acceptance after material cross-cutting changes;
- migrations or provider-transaction changes;
- hydration or shared orchestration changes;
- global test-infrastructure/concurrency changes;
- a named unexplained cross-area failure;
- cycle-close verification required by the current roadmap/prompt.

Run at most one authoritative full-suite pass per stable implementation state. A second pass requires a material code change or named diagnostic hypothesis.

Documentation-only work does not require executable validation when source, tests, migrations, fixtures, project metadata, schemes, TestPlan, build settings and executable resources remain unchanged. It still requires complete diff, link/path, privacy and Git-state review.

---

## Reports and acceptance

Implementation and review reports are claims, not acceptance.

Classify material claims as:

- **verified**;
- **reported only**;
- **contradicted**;
- **missing**.

Verify, where relevant:

- starting/ending refs;
- changed files;
- branch/worktree handling;
- source and oracle authority;
- migration/ADR impact;
- test selection and nonzero execution;
- persistence/hydration/relaunch;
- privacy and residue;
- staged/unstaged/untracked state;
- commit/push result;
- limitations and falsification analysis.

Chat alone accepts the implementation outcome.

---

## Durable records

- `PROJECT_STATE.md`: accepted production baseline plus explicitly labelled active unaccepted WIP.
- Current cycle roadmap: sprint numbering, corrective status, cycle outcomes and next gates.
- `FUTURE_WORK.MD`: unscheduled queue, bugs, debt and research.
- `ADR.md`: accepted architectural decisions.
- Standing execution harness: reusable Chat/MCP/Codex execution method.
- Git history: detailed implementation history.

Do not duplicate every fact everywhere. Cross-link instead.

---

## Stop conditions

Stop and report when:

- repository state materially differs from the approved task;
- another writer is active or worktree ownership is ambiguous;
- unique work may be lost;
- architecture or source truth is contradictory;
- a migration would require guessing;
- an independent financial oracle is unavailable;
- provider parity or zero-residue behaviour cannot be established;
- private data or credentials would leak;
- required validation fails;
- scope must expand beyond the approved outcome;
- the result would overstate accepted production support.

Do not silently weaken validation or manufacture a green result.

---

## Maintenance rule

Keep this bootstrap stable. Do not embed current commit hashes, current sprint test counts or detailed sprint history here.

When workflow ownership or authority routing changes, update this file, the Project Guide and Standing Execution Harness together.
