# Standing execution harness

Reusable execution/review method; no independent scope or architecture authorization. [Project Guide](Project_Guide.md) routes the task and owns documentation ordering. Numbered procedures follow Guide rule J.

## Authority and intake

Use exact current refs and the selected task's relevant state, scope, queue, roadmap and accepted ADR sections. Reports/memory guide inspection, never override evidence. The owner decides product scope; Chat owns sprint/correction selection, architecture/financial semantics, prompts and technical acceptance. The approved prompt determines publication authority.

Record eligible ideas, features, defects and maintenance under the [scope/intake decision](SCOPE_DECISIONS.md). Distinguish owner request, verified finding, reported defect and contributor proposal. A meaningful new rejection gets a short durable reason; an existing rejected capability gets a reference. No rejected work blocks a retained item. Capture is not approval/readiness/scheduling/execution. Close material findings as EXISTING_ENTRY_UPDATED, NEW_CANDIDATE_RECORDED, ALREADY_COMPLETED, DUPLICATE, DEFERRED_WITH_REASON, REJECTED_WITH_REASON or REJECTED_BY_PRIVATE_PERSONAL_SCOPE. Do not strand a material finding only in a report or expand implementation to absorb it.

## Environments and reasoning ownership

Chat, Codex and MCP executor are distinct. Codex receives a self-contained prompt and relevant local authorities; it does not inherit unseen Chat attachments. MCP executor is a Chat plugin with leases and exact repository checks, not a model or authorization source. MCP leases cannot fence independent Codex/local writers. Use actual available controls and the selected execution route; never invent a missing tool or bypass a required gate.

The repository's reasoning hierarchy remains Sol, Terra, Luna: Sol for architecture-sensitive financial/migration/credential reasoning, Terra for strong bounded or adversarial review, Luna for mechanical work after causal ownership is settled. The user-selected model/prompt controls a task. Escalate unresolved reasoning, not merely verbosity; no model may silently reopen architecture or change its authorized topology.

<a id="one-writer-and-publication"></a>
## One writer and publication

Default: existing main, primary worktree, one active writer. A dirty understood worktree is permitted; unexplained work or overlapping ownership is a stop condition.

1. Verify branch/exact HEAD, recorded and fresh origin/main relationship, index/conflicts, unstaged/untracked paths, worktrees/branches/stashes, active Git operations, validations, writers and relevant leases.
2. Freeze the initial changed-file inventory and diffs/hashes. Establish exact write ownership and preserve unrelated work byte-for-byte. Do not stop another writer/validation to make room.
3. Perform only authorized edits. Never reset, restore, clean, stash, prune, overwrite/delete unique work, rewrite history or force-push as an assumed repair.
4. Review complete candidate diff, paths/links, privacy, executable/resource boundaries and required validation. Preserve failed/non-run evidence. A changing foreign fingerprint is a stop condition.
5. Commit/push only when explicitly authorized. Stage exact paths/hunks; never `git add .`. Inspect the staged diff separately from unstaged WIP and include all new linked dependencies. Preserve actual multiline commit/report text.
6. Recheck remote before normal push; unexplained divergence stops publication. Tags need explicit authorization. Verify ending local/remote refs and staged/unstaged/untracked residue; release only task-owned resources/leases and hand off writer ownership.

No task requires an unrelated dirty worktree to become clean. “Clean” means the promised exact boundary, with protected residue explicitly reported. A new branch, PR or worktree is not implicit in a docs task.

<a id="task-capsule"></a>
## Task capsule and execution rhythm

A complete prompt states primary PG type; reasoning owner/model/effort and justification; any subagents/parallelism with read/write roles and exact ownership; selected environment/tool role; required terminal; exact baseline and accepted/WIP distinction; one outcome; relevant evidence/authority; included files/boundaries and exclusions; falsifiable acceptance; named focused tests and full-suite trigger; migration/ADR impact; stop conditions and report/publication expectations. Use the smallest sufficient context, not a pasted transcript. Topology changes require the prompt's delegated authority; one writer plus read-only reviewers is the safe default when parallel review is authorized.

Implement a coherent boundary, compile/type-check, run focused falsification, inspect and continue. Do not wait until a high-risk cross-layer change is complete before compiling, or split an atomic architectural outcome into misleading tiny commits.

## Financial correctness and source ownership

[Engineering Standards](Engineering%20Standards.md#authentic-source-and-oracle-invariants) owns source/Money/date/identity/persistence/recovery invariants. Financial proof outranks time/token efficiency. No generated statement or production-derived sole oracle; preserve exact native semantics, fail closed on financial ambiguity and prove zero accepted losing-path residue, provider parity and canonical hydration/reopen where relevant. The [owner's current source-processing decision](SCOPE_DECISIONS.md#source-processing-decision) supersedes older on-disk copy/oracle-artifact permissions; historical evidence is not current permission.

<a id="parser--authentic-corpus-acceptance-policy"></a>
## Parser / Authentic-Corpus Acceptance Policy

1. Inventory every original authentic carrier in the approved root and its logical representation separately. Newly supplied recurring statements extend the cumulative corpus unless explicitly excluded/archived; never substitute a sample or representative month.
2. Apply the all-stages authentic-input and in-memory processing rule before development/debugging, tests, oracles, persistence/migration acceptance, batch/developer UI or review. Missing genuine shapes remain uncertified, not manufactured.
3. Derive independent source meaning before comparing ordinary production. Compare through an explicit architecture-aware semantic projection; raw oracle JSON need not equal production JSON. Preserve exact multiplicity and source order where authoritative, with no invented occurrence identity.
4. Exercise ordinary prepare/validate/confirm and every affected accepted persistence/provider/reopen/hydration boundary. Generic extraction preserves physical/source evidence; family parsers interpret coherent financial controls flexibly across inert packaging and fail closed on ambiguous financial meaning.
5. For shared readers, unlock orchestration, snapshots, detection/classification/routing, normalizers, Money, validation, duplicate/equivalence or persistence mapping, rerun the complete corpus of every affected supported family. Shared tests/full TestPlan supplement this proof; they do not replace it.
6. Tie acceptance to the exact candidate and independent input freeze. Material corrections invalidate affected old green evidence. Distinguish historical profile acceptance from current complete-corpus certification and record real unobserved cases.

The canonical ownership is intake (queue length one or many), unlock/extract, identify/classify/route, family semantic interpretation, normalize/validate/reconcile, duplicate/equivalence, explicit review/confirmation, provider-owned atomic persistence, canonical database/hydration and presentation. Institution parsers are ingestion modules, not separate analytical stores. Prefer deterministic/native structured extraction; model adjudication is not ordinary financial authority.

## Credential correctness

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

## Proportional validation

Start with the smallest check that can falsify the changed boundary. Compile affected targets and execute real nonzero focused selectors before broadening for a named risk or failure. Use [Build conventions](BUILD_AND_PROJECT_CONVENTIONS.md) and actual [script interfaces](../script/README.md).

One complete TestPlan per stable implementation state is authoritative when a recorded trigger applies: material cross-cutting final acceptance; migrations/provider transactions; canonical hydration/shared orchestration; shared duplicate/credential/reader routing effects; global test infrastructure/concurrency; a named unexplained cross-area failure; or explicitly required cycle close. A second full pass needs a material change or named diagnostic hypothesis. Do not rerun suites to compensate for missing financial or runtime evidence.

Persistence/startup changes preserve the independent accepted migration identity lock, explicit task-owned schema experiment namespace and genuine adopted-data upgrade acceptance. Use the existing durable-startup gate for actual SQLite/provider publication, clean quit and same-database relaunch; memory Run is insufficient. One-time disposable database recreation is not future reset authority. Keep product build identity and dirty/unavailable provenance truthful.

Runtime checks are required where automation cannot establish launch, navigation, import review/confirmation, provider replacement/relaunch, process contention or actual native interaction. Label passed/pending/unavailable/explicitly accepted deferral separately. No guessed native pass or blanket formal accessibility campaign.

Documentation-only changes require full diff, status-claim, link/path/anchor, ordering, privacy and Git-state review. They need no executable suite when executable sources/tests/migrations/resources/project metadata are unchanged. Exact Xcode documentation membership changes require project parse and the smallest affected build/resource-containment check, not product-feature acceptance. Changed checkers require focused checks.

## Reports and cross-tool evidence

Report exact starting/ending refs, changed paths/fingerprints, scope/exclusions, migration/ADR impact, source/oracle authority, named build/test/run IDs and nonzero counts, results/failures/non-runs, native/provider/recovery proof, privacy/residue, publication and falsification/limitations. Classify material claims **verified**, **reported only**, **contradicted** or **missing**. Complete logs are not the default report. Chat verifies before acceptance.

Where reviewers cannot access native artifacts, provide an allowed compact operational acceptance manifest readable by the authorized review surfaces, with candidate/parent, paths/hashes, test/build results, run IDs/times and only permitted evidence. It supplements native artifacts, never replaces them. It must not contain originals, credentials or derived financial evidence prohibited by the current owner processing rule. Do not persist source-oracle records merely to satisfy a historical cross-tool recipe; resolve any incompatible evidence requirement before execution.

## Corrective numbering and documentation close

Chat assigns N, NA, NB in sequence without shifting later numbers. A blocker within a correction does not create another correction; unrelated defects need their own classification.

After technical acceptance, update the current snapshot, owning roadmap outcome, necessary ADR alignment and queue remainder with accepted-history links. Detailed tests/non-runs/limitations belong in accepted outcome collections. If acceptance is incomplete, label active unaccepted WIP. Decisions/rejection reasons belong in SCOPE_DECISIONS; substantive unresolved evidence in shared Work notes. Update AGENTS/Guide/Harness together only for reusable routing/ownership changes. Publication alone is not acceptance or personal adoption.

## Stop conditions and exceptions

Stop for conflicting owner/source/architecture authority, unexplained ref/WIP divergence, another writer, possible unique-work loss, guessed migration/identity, absent independent financial proof, failed required validation/parity/residue/recovery, private Git leakage, unavailable required controls or scope expansion. Name the boundary, preserve evidence and return to Chat. A deviation must identify the exact rule, reason and safety consequence; obtain owner authorization where not already supplied. Silence is not approval.
