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
9. For any task touching a reader, detector, classifier, parser, normalizer, import validation, duplicate/equivalence semantics or source-support acceptance, read ADR-046, the Standing Execution Harness **Parser / Authentic-Corpus Acceptance Policy**, and the current `PROJECT_STATE.md` parser-reliability alignment before treating support as established.
10. Inspect production code, tests, private-source evidence or local build/runtime evidence only where the documents are insufficient.

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

## Current parser / import authority — 2026-09-01

ADR-046 is the current parser/source-support authority. For every supported financial source family:

- no synthetic, generated, recreated, sanitized, reconstructed, representative, reduced, mutated, hand-authored or model-created financial statement may be created or used at any stage, including development, debugging, tests, oracles, persistence, batch acceptance, developer UI or adversarial review; remove statement fixture factories/catalogs and do not replace them with hand-built statement/domain/DTO graphs; <!-- user-specified -->
- only authentic corpus statements may exercise statement-dependent behaviour. Exact working copies, necessary decrypted copies and actual extracted attachment bytes are permitted; original bytes remain provenance/fingerprint authority. Pure source-independent nonfinancial values/files may test isolated mechanics, but must not impersonate financial statements. Missing authentic cases remain source-uncertified, not manufactured; <!-- user-specified -->
- the **complete registered authentic corpus** supplied by the user is the cumulative parser regression authority; sampling or a representative month is insufficient;
- each newly supplied recurring authentic statement extends that corpus unless the user explicitly excludes or archives it;
- generic readers extract and preserve source evidence; institution/source-family financial interpretation belongs downstream;
- parsers must be tolerant about inert packaging and strict about financial meaning: page count, transaction count, absolute row/line positions, harmless whitespace/typography, benign page breaks and nonfinancial pages do not define support;
- zero-transaction statements and variable page counts are valid when coherent source controls establish them; technical resource limits must not masquerade as financial-profile rules;
- one adaptive deterministic runtime parser should own one recurring financial source family unless a materially different source/financial semantic contract justifies a separate profile; deterministic means reproducible and explainable, not hard-coded physical coordinates;
- financial meaning is established from coherent source evidence such as semantic labels, column roles, data shapes, dates, Money, direction, balance transitions, statement/section controls, continuity, ordering and surrounding structure; fail closed when financial meaning is ambiguous, contradictory, malformed or unsupported, not merely because inert presentation changed;
- any shared ingestion change that can affect source interpretation must rerun the complete authentic corpus of every affected supported family; a green unit suite or full TestPlan alone does not certify parser reliability;
- historical sprint/profile acceptance remains historical fact, but it is distinct from **current authentic-corpus production reliability certification**; personal-v1 parser reliability remains uncertified until the complete-corpus gate is satisfied; and
- independent source oracles record source facts. Acceptance compares authentic source truth through an explicit architecture-aware semantic projection with ordinary production output; raw Oracle JSON need not equal raw production JSON when the representations intentionally differ.

Private authentic originals remain outside Git and read-only. AI/model interpretation is not required for ordinary recurring structured parsing and is never financial authority unless separately approved.

---

## Financial truth

For financial imports, persistence, identity, balances, cards, salary, investments or valuation:

- complete authentic source semantics and independently derived source oracles outrank generated expected data;
- production parser output must not be its own sole oracle;
- preserve native currency, scale, liability/direction semantics, date meaning, source order, balances, identifiers, multiplicity and provenance;
- fail closed on malformed, ambiguous, conflicting or unsupported evidence;
- verify zero accepted durable residue on rejection;
- require SQLite/In-Memory parity where both matter;
- verify persistence, provider reconstruction, close/reopen, hydration and presentation;
- never infer institution, format, layout, account identity or credential family from structural similarity alone;
- never invent dates, ordering, identifiers, balances or provenance;
- keep private originals isolated and read-only;
- do not place private originals in Git; the all-stages authentic-input rule above applies to every statement-dependent operation.

A green suite proves only the boundary and oracle it exercised.

---

## Startup and accepted migration prevention

Accepted migration identities are append-only: retain the independent baseline lock in `MigrationIdentityLockTests`; never refresh its expected identities from candidate source merely to make a test pass. Run deliberate schema experiments only on task-owned isolated targets through the namespace-checked `script/validate.sh schema-experiment` path. Ordinary Xcode Run remains Current Database. A memory Run check cannot establish durable startup: use `script/validate.sh durable-startup` for provider verification, canonical hydration, clean quit and same-database relaunch. An adopted database requires upgrade-copy acceptance; recreating the disposable database in the 2026-09-09 continuation was a one-time explicit authorization, not a general recovery rule. See `script/README.md` for the exact commands and evidence boundaries.

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
