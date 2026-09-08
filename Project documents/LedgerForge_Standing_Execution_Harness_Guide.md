# LedgerForge Standing Execution Harness Guide

**Status:** Active repository process authority  
**Refreshed:** 2026-09-01
**Execution authority:** None by itself  
**Architecture authority:** None by itself  
**Purpose:** Reusable Chat/MCP/Codex planning, execution, validation and review method

This repository-local guide supersedes the older private dated copy as the standing execution-method authority.

It does not authorize implementation. A complete Chat-approved prompt still authorizes each concrete task.

---

## 1. Core principle

Retain context within one coherent task. Reset or compact between different outcomes.

Every executor/reviewer should receive:

- exact current repository state;
- current sprint/corrective status;
- only the durable decisions relevant to the task;
- the smallest sufficient code/test/source boundary;
- explicit stop conditions;
- no stale transcript archaeology masquerading as authority.

---

## 2. Mandatory authority gate

Before sprint selection, naming, roadmap change, execution prompt, implementation review or acceptance, Chat inspects in this order:

1. exact ref/worktree under review;
2. `LedgerForge_Roadmap_Sprints_80-89_Current.md`;
3. this standing harness;
4. `PROJECT_STATE.md`;
5. `FUTURE_WORK.MD`;
6. relevant accepted ADR entries;
7. production code/tests when documentation is insufficient;
8. bounded local/private evidence when source truth or local state requires it.

Material claims are classified as:

- **Verified repository/local evidence**
- **Explicit user decision**
- **Reported only**
- **Inference**

Memory and old reports may guide a search but never override current authorities.

---

## 3. Execution environments and model tiers

### Chat

Chat owns:

- sprint/corrective selection;
- architecture and financial semantics;
- prompt generation;
- acceptance;
- durable documentation reconciliation.

### MCP executor

MCP executor is a Chat plugin for local Mac repository/Xcode access.

It may perform:

- read-only inspection;
- builds/tests/runtime inspection;
- private-evidence work under the approved privacy boundary;
- Chat-authorized writes under one exact execution lease.

The lease is mechanical fencing for MCP, not project authorization.

### Codex

Codex is a separate execution environment. It does not inherit Chat-only conversation or attachments.

Every Codex task must be self-contained and must read the repository-local bootstrap, current roadmap, harness, state and relevant ADRs.

### Model tiers

Model capability order is:

**Sol > Terra > Luna**

Recommended use:

- **Sol:** architecture-sensitive/high-risk implementation or reasoning;
- **Terra:** independent adversarial review or bounded strong implementation;
- **Luna:** mechanical cleanup/narrow implementation after architecture is settled.

Model tier and environment are orthogonal.

---

## 4. One-writer rule

One primary worktree, one active writer.

Before mutation verify:

- exact HEAD;
- branch;
- local/fetched remote relationship;
- staged/unstaged/untracked state;
- worktrees/branches/stashes;
- active Git operation;
- active validation/build;
- active MCP lease;
- independent Codex/local writers.

MCP's lease cannot fence an independent Codex/local process. A changing fingerprint while an MCP lease is held is a stop condition.

Do not reset, restore, clean, stash, prune, force-push or overwrite unexplained work.

---

## 5. Compact task capsule

Every execution prompt contains the task-relevant form of:

### Baseline
Exact ref, worktree expectations, accepted baseline, active correction, migration/ADR baseline.

### Outcome
One sentence describing the required result.

### Evidence
Only source/repository/local facts needed for this task.

### Authority
Relevant roadmap rules, ADRs and explicit user decisions.

### Scope
Expected files/types/protocols/migrations/tests.

### Exclusions
What must not change or be inferred.

### Acceptance
Falsifiable functional, financial, persistence, hydration, privacy and presentation conditions.

### Validation
Named focused tests, adjacent tests, full-suite trigger.

### Stop conditions
Conditions that require returning to Chat.

### Report
Exact ending state, diff, tests/artifacts, oracle, residue, limitations and falsification.

Do not paste whole chat histories into execution prompts.

---

## 6. Financial-correctness override

Token or schedule efficiency never weakens financial proof.

For financial work:

- no synthetic, generated, reconstructed, sanitized, representative, reduced, mutated or hand-authored financial statement may be created or used at any stage; only authentic corpus statements may exercise statement-dependent behaviour;
- parser output is not the sole oracle;
- preserve Money currency/scale exactly;
- preserve financial direction/liability effect;
- preserve source date semantics;
- preserve multiplicity;
- preserve source order where authoritative;
- preserve source-proven identifiers and provenance;
- fail closed on malformed, financially ambiguous, contradictory or unsupported evidence; harmless presentation variation alone is not a fail-closed reason;
- rejection leaves zero accepted durable residue;
- SQLite/In-Memory parity is required where both matter;
- reopen/hydration are acceptance boundaries;
- support never generalizes from visual/structural similarity.

Private originals remain read-only and outside Git.

---

## Parser / Authentic-Corpus Acceptance Policy

ADR-046 governs current reader/parser/source-support acceptance. The reusable rules are:

1. **Authentic corpus only.** The complete registered authentic source corpus for every affected supported family is the parser regression and reliability authority. No sampling, representative month or synthetic/sanitized/reconstructed financial statement substitutes for it. Newly supplied recurring statements extend the corpus unless explicitly excluded or archived by the user.
2. **All-stages authentic-input rule.** No synthetic, generated, recreated, reconstructed, sanitized, representative, reduced, mutated, hand-authored or model-created financial statement may be created or used for development, debugging, reader/normalizer semantics, detector/classifier/parser tests, oracles/expected outputs, edge cases, migration/persistence, import/batch acceptance, developer/debug UI or adversarial review. Remove generated-statement catalogs, reconstructed resources, mutation variants and financial statement factories; hand-built statement/domain/DTO graphs are not substitutes. Exact working copies, necessary decrypted copies and actual extracted PDF attachment bytes are permitted authentic carriers; retain original source-byte provenance/fingerprint authority. Pure source-independent mechanics may use nonfinancial values/files, never content shaped to impersonate a financial statement. If no authentic zero-activity, malformed or other edge case exists, record it as source-uncertified rather than manufacturing coverage. <!-- user-specified -->
3. **Flexible packaging; strict financial semantics.** Parser support is not defined by incidental page count, transaction count, absolute source row/line number, harmless whitespace/Unicode variation, blank rows, benign page breaks, nonfinancial preambles/footers/pages or statement length. Zero-transaction and variable-page statements must remain supportable when source controls coherently establish their meaning.
4. **Adaptive deterministic interpretation.** One recurring source-family parser dynamically identifies financial regions, roles and continuity from coherent deterministic evidence: semantic labels, column roles, data shapes, dates, Money, liability/debit-credit direction, running balances, statement/section controls, source order and surrounding structure. Determinism means reproducible/explainable semantics, not rigid physical coordinates. Separate profiles require materially different financial/source semantics.
5. **Reader boundary.** Generic readers preserve source evidence and physical boundaries. A PDF page with no extractable text does not by itself invalidate the document; downstream family analysis decides whether it is nonfinancial, needs another extraction mode or is genuinely ambiguous. Reader-level rejection is reserved for reader failures such as corrupt/unreadable source material, unresolved encryption or resource failure.
6. **Financial ambiguity is the stop condition.** Fail closed when financial meaning is ambiguous, contradictory, malformed or unsupported. Do not fail merely because inert packaging differs from a prior month.
7. **Shared-infrastructure regression.** Any change to generic readers, unlock/password orchestration, source snapshots, detection, classification, routing, normalizer infrastructure, Money, common validation, duplicate/equivalence semantics or persistence mapping must rerun the complete authentic corpus for every affected supported family. Shared unit tests and a full TestPlan are supplementary, not substitutes.
8. **Historical acceptance is not current reliability certification.** Historical sprint/profile acceptance remains a factual record. Present-day parser reliability is certified only by the complete authentic-corpus ordinary-production-path gate under ADR-046.
9. **Oracle projection.** Independent oracles record source facts without importing production assumptions. Comparison is `authentic source truth -> explicit architecture-aware semantic projection -> expected LedgerForge financial meaning` versus ordinary production output. Raw Oracle JSON equality with raw production JSON is not an acceptance rule when architectures differ.
10. **AI boundary.** Prefer deterministic/native extraction, especially for structured XLS/XLSX. Model analysis is reserved for genuinely ambiguous interpretation or independent adjudication and is not ordinary recurring-parser authority.

The canonical user import direction is batch intake (including queue length one) -> unlock as required -> generic extraction -> identify/segregate -> route each statement -> source-family semantic parser -> source-owned financial events -> normalize -> validate/reconcile -> duplicate/equivalence evaluation -> explicit review/confirmation where required -> atomic persistence -> one canonical database -> canonical financial rows -> query/extraction/presentation/viewer layers. Institution-specific parsers are ingestion modules, not separate analytical silos.

Private authentic originals remain read-only and outside Git.

---

## 7. Credential-correctness rules

For password-protected financial sources:

- the generic reader remains credential-agnostic;
- candidate planning/storage belongs to the credential/coordinator layer;
- uncredentialed read occurs first;
- remembered candidates are deterministic and bounded;
- secure challenge follows remembered-candidate exhaustion;
- post-decryption structural evidence may select a persistence target only after exact supported-family proof;
- persistence occurs only after parse + validation;
- credentials never enter financial persistence, fixtures or diagnostics;
- multiple legitimate credential families require explicit durable scopes;
- legacy Keychain state is compatibility evidence, not permanent architecture;
- private automated acceptance must not expose or bootstrap real credentials.

---

## 8. Selective-test policy

Default:

1. compile the smallest affected target;
2. run the named focused suites;
3. broaden only when the ownership boundary or a failure requires it.

A full `TestPlan.xctestplan` pass is required when the prompt records a trigger, including:

- migration;
- provider transaction semantics;
- canonical hydration;
- shared duplicate/equivalence semantics;
- shared credential orchestration;
- reader/registry routing with broad effect;
- global test infrastructure/concurrency;
- final cycle-close where explicitly required.

At most one authoritative full pass per stable implementation state.

A second full pass requires a material code change or named diagnostic hypothesis.

Every selector must discover and execute nonzero tests.

---

## 9. Source/oracle discipline

For private-source acceptance:

- define physical source inventory independently;
- define logical representations separately from duplicate physical copies;
- do not use filenames to infer financial meaning when source evidence can prove it;
- do not let production parser output become the independent oracle;
- compare source truth to production through an explicit architecture-aware semantic projection rather than requiring raw oracle JSON to equal raw production JSON;
- use exact multiset/multiplicity where order is not source-equivalent;
- use exact ordered comparison where source order is authoritative;
- preserve duplicate occurrences without invented occurrence identity;
- retain only aggregate/private-safe acceptance results in durable docs.

---

## 10. Report compression

Reports preserve:

- exact refs/fingerprints;
- changed files;
- source/oracle;
- test/build commands or run IDs;
- result;
- failure classification;
- remaining unknowns;
- residue/privacy state;
- falsification analysis.

Do not paste complete logs by default.

Classify claims as:

- verified;
- reported only;
- contradicted;
- missing.

Chat verifies material claims before acceptance.

---

## 11. Model escalation

Escalate reasoning/model, not merely verbosity.

Use **Sol** when:

- architecture ownership is unresolved;
- financial correctness spans several layers;
- migration/credential/persistence semantics are changing;
- repeated lower-tier attempts disagree with source truth.

Use **Terra** when:

- architecture is frozen but an independent adversarial review is needed;
- a strong second opinion can falsify a near-final candidate;
- implementation is bounded but still nontrivial.

Use **Luna** when:

- causal ownership is settled;
- work is mechanical;
- test/source expectations are already authoritative.

A lower model must not reopen settled architecture without new evidence.

---

## 12. Corrective-sprint rule

The current roadmap governs sprint numbering.

For Sprint `N`:

- `NA` is the first bounded correction attributable to `N`;
- `NB` is another separately bounded correction attributable to `N`;
- later numbered sprints do not move;
- a blocker inside a correction does not create another correction;
- an unrelated P0 defect is not disguised as the previous sprint's correction.

Only Chat assigns or accepts corrective numbering.

---

## 13. Documentation synchronization

At technical acceptance:

- update `PROJECT_STATE.md`;
- update the current roadmap;
- publish required ADR alignment/amendment;
- reconcile `FUTURE_WORK.MD`;
- update AGENTS/Project Guide/Harness only when reusable process changed.

If acceptance is not complete, record the work as **active unaccepted WIP**, not production support.

Repository-local current roadmap/harness are preferred over private dated copies to prevent authority drift.

---

## 14. Durable task close

Preserve:

- accepted ref/outcome;
- migration/ADR consequence;
- support and exclusion boundary;
- focused/full validation;
- runtime/private-source evidence at aggregate level;
- rejected alternatives that constrain future work;
- remaining future work.

Detailed implementation history stays in Git.

---

## 15. Exceptions

A deviation from this harness requires Chat to record:

- exact rule overridden;
- reason;
- evidence/safety consequence;
- user approval when the deviation broadens scope, privacy, testing or Git operations.

Silence is not an exception.
