# LedgerForge Agent Bootstrap

## Purpose

This file is the mandatory repository entry point for LedgerForge agents.

Keep it short and stable. It is a map to repository authorities, not a copy of
the architecture, roadmap, build manual or sprint history.

LedgerForge is a private, single-user, offline-first macOS finance application
built with Swift and SwiftUI.

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

## Mandatory Bootstrap

For every repository task:

1. Read this file.
2. Read the complete Chat-approved prompt supplied for the current task.
3. Establish the exact repository ref being inspected or edited.
4. Read the relevant sections of `Project documents/PROJECT_STATE.md`.
5. Load only the additional authorities, code and tests required by the task.
6. Read `Project documents/FUTURE_WORK.MD` only for sprint selection,
   prioritisation or candidate-status work.
7. Read relevant accepted entries in `Project documents/ADR.md` before changing
   architecture, persistence, identity, import semantics or domain ownership.

Do not load every repository document by default.

`Project documents/Project_Guide.md` is not a mandatory bootstrap document.
Read it only when the approved task requires workflow detail not covered here.

The following files are retired and are not repository authorities:

- `Project documents/Implementation.md`
- `Project documents/Codex response.md`

Do not read, update, recreate or infer an active sprint from either file.

The complete Chat-approved prompt is the sole execution contract.

Without an approved implementation prompt:

- do not edit repository files;
- do not create branches or worktrees;
- do not commit or push;
- do not infer implementation authority from `FUTURE_WORK.MD`;
- do not infer an active sprint from repository documents.

---

## Authority Map

| Question | Authority |
|---|---|
| What is verified now? | Exact repository evidence and `PROJECT_STATE.md` |
| What may be executed? | Complete Chat-approved prompt |
| What remains unscheduled? | `FUTURE_WORK.MD` |
| What architecture is accepted? | Accepted entries in `ADR.md` |
| What is product direction? | `Product Vision.md` |
| What UI is approved? | Frozen UI/UX documents and approved assets |
| What engineering and privacy rules apply? | `Engineering Standards.md` |
| What build, Xcode, test and Git rules apply? | `BUILD_AND_PROJECT_CONVENTIONS.md` |
| What happened historically? | Git history |
| What exists only locally? | Direct local evidence, normally through bounded Work investigation |

When authorities conflict:

1. identify the exact conflict;
2. inspect the exact current ref;
3. prefer current production evidence and accepted ADRs;
4. do not select the most convenient interpretation;
5. stop and return the unresolved decision to Chat.

Memory, uploaded copies, reports and earlier conversations are context only.
They never override current repository evidence or explicit user decisions.

---

## Mode Ownership

### Chat

Chat owns:

- sprint planning and prioritisation;
- GitHub repository discovery;
- architecture and financial-semantics decisions;
- Work and Codex prompt preparation;
- report verification;
- implementation acceptance;
- roadmap and authority reconciliation.

Planning does not authorize implementation.

### Work

Work is read-only with respect to repository source and documentation.

Use Work only when GitHub cannot efficiently establish a named fact, including:

- local or unpushed state;
- worktrees, branches and stashes;
- private-source or fixture lineage;
- filesystem, Xcode, sandbox or toolchain configuration;
- build, test, runtime or `.xcresult` evidence;
- broad local tracing required to resolve one bounded unknown.

Before Work is used, Chat must state:

1. the exact unresolved unknown;
2. why it affects the decision;
3. why GitHub cannot answer it;
4. the bounded evidence Work must return.

Work may create task-owned build, test and disposable runtime artifacts.
Work does not edit repository files, choose sprint scope or perform Git writes.

### Codex

Codex performs only the source, test, documentation and Git operations explicitly
authorized by the complete Chat-approved prompt.

Codex must not:

- redesign the sprint;
- widen support claims;
- choose new architecture;
- reinterpret source truth;
- absorb unrelated local changes;
- continue past a recorded stop condition.

---

## Task Context Discipline

One prompt or session should pursue one coherent outcome.

Every Work or Codex prompt should identify:

- exact baseline ref;
- required branch and worktree state;
- one outcome;
- verified evidence;
- relevant authorities;
- included scope;
- exclusions;
- acceptance boundary;
- named focused tests;
- full-suite trigger, if any;
- stop conditions;
- required report fields.

Do not paste complete roadmaps, full chat transcripts, unrelated ADR history,
raw build logs or the complete repository handbook into ordinary task prompts.

Inspect the smallest code and test boundary capable of completing or falsifying
the approved outcome. Widen only when concrete evidence requires it, and report
the widening.

---

## Financial Truth

For financial imports, persistence, identity, balances, cards, salary,
investments or valuation:

- source semantics outrank fixtures and generated expected data;
- production parser output must not be its own sole oracle;
- preserve native currency, scale, direction, date meaning, source order,
  balances, identifiers and provenance;
- fail closed on malformed, ambiguous, conflicting or unsupported evidence;
- verify zero accepted durable residue on rejection;
- verify SQLite and In-Memory parity where both matter;
- verify persistence, hydration, provider reconstruction, relaunch and
  presentation;
- never infer institution, format or layout support from similarity;
- never invent dates, ordering, identifiers, balances or provenance;
- keep sanitized fixtures in Git;
- keep private originals isolated and read-only;
- distinguish source truth, implementation behaviour, test evidence and
  inference.

A green test suite proves only the boundary and oracle it exercised.

Preserve accepted architecture boundaries. Read the relevant ADR before changing
readers, parsers, financial identifiers, validation, duplicate handling,
persistence, hydration or presentation ownership.

---

## Git and Worktree Safety

Default repository workflow:

- one `main` branch;
- one primary worktree;
- one active editing task;
- no feature branch;
- no pull request;
- direct validated commit and push to `origin/main`.

A branch, worktree or pull request requires:

1. explicit user approval;
2. a repository-specific reason;
3. an approved prompt requiring it.

Before editing, verify:

- active branch and exact HEAD;
- `main` and `origin/main` divergence;
- staged, unstaged and untracked files;
- linked worktrees;
- local and remote branches;
- stashes;
- in-progress Git operations;
- unexplained locks or task-owned processes.

A dirty worktree is not automatically a failure.
An unexplained dirty worktree is a stop condition.

Never:

- reset or overwrite unique work;
- delete an unexplained branch or worktree;
- drop an unexplained stash;
- force-push;
- rewrite published history;
- stage unrelated paths;
- commit private or generated residue.

Before push, fetch again and stop if `origin/main` advanced unexpectedly.

---

## Validation Policy

Use focused validation by default.

During implementation, Codex should:

- compile the smallest affected target;
- run the explicitly named focused tests;
- run adjacent suites only when the changed ownership boundary justifies them;
- avoid rerunning an unchanged full suite.

Work owns authoritative broader acceptance testing when the approved prompt
requires it.

Run the complete `TestPlan.xctestplan` only when a recorded trigger applies,
including:

- final integrated acceptance after material cross-cutting changes;
- migration, provider transaction, hydration, shared orchestration, concurrency
  or global test-infrastructure changes;
- an unexplained failure outside the changed area;
- integration of several sequential implementation packets;
- dedicated regression or cycle-close verification;
- another concrete cross-area risk recorded by Chat.

Run at most one authoritative full-suite pass per stable implementation state.
Another pass requires a material code change or named diagnostic hypothesis.

Documentation-only work does not require executable validation unless it changes:

- project or target metadata;
- schemes or TestPlan;
- build settings;
- fixtures or executable resources;
- source, tests, schemas or migrations.

Do not claim validation that was not executed.

---

## Privacy

Never commit:

- private financial statements or private source mappings;
- credentials, passwords, tokens or keys;
- unsanitized financial identifiers;
- private transaction evidence;
- local SQLite databases, WAL or SHM files;
- DerivedData or build products;
- sensitive logs;
- temporary files;
- user-specific Xcode state;
- unexplained generated output.

Approved fixtures must remain sanitized, source-faithful and independently
verified.

Privacy uncertainty is a stop condition.

---

## Stop Conditions

Stop and report when:

- the repository baseline materially differs from the approved prompt;
- local state is ambiguous;
- unique work may be lost;
- architecture is missing or contradictory;
- a migration would require guessing;
- source truth or an independent oracle is unavailable;
- financial relationships cannot be preserved;
- provider parity or zero-residue behaviour cannot be established;
- privacy-sensitive material appears;
- required validation fails;
- process or artifact ownership is unclear;
- the complete diff cannot be explained;
- scope must expand beyond the approved outcome;
- the result would overstate production support.

Do not silently weaken validation, invent a workaround or commit partial failed
work as completed.

---

## Durable Records

- Verified implementation state belongs in `PROJECT_STATE.md`.
- Unscheduled work belongs in `FUTURE_WORK.MD`.
- Accepted architecture belongs in `ADR.md`.
- Product direction belongs in `Product Vision.md`.
- UI authority belongs in frozen UI/UX documents and approved assets.
- Engineering policy belongs in `Engineering Standards.md`.
- Build, test, Xcode and Git mechanics belong in
  `BUILD_AND_PROJECT_CONVENTIONS.md`.
- Detailed implementation history belongs in Git.

Do not duplicate every durable fact across documents.

---

## Execution Report

A Codex or Work report must include, where applicable:

- starting and ending refs;
- branch and worktree state;
- pre-existing changes;
- inspected or changed files;
- included and excluded scope;
- migration and ADR impact;
- fixture and oracle authority;
- commands and validation results;
- runtime evidence;
- residue and cleanup;
- commit and push result;
- limitations;
- unresolved evidence;
- falsification analysis.

Classify material claims as:

- verified;
- reported only;
- contradicted;
- missing.

---

## Guide Maintenance

Keep this file compact and stable.

Do not add:

- current sprint numbers;
- current commit SHAs;
- current migration versions;
- current test counts;
- institution support matrices;
- full architecture diagrams;
- complete command transcripts;
- roadmap content;
- historical sprint summaries.

Update this file only when bootstrap, authority, role ownership, repository safety
or validation policy materially changes.

Detailed and mutable rules belong in their subject authorities.
