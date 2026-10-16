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

[Engineering Standards](Engineering%20Standards.md#authentic-source-and-oracle-invariants) owns source/Money/date/identity/persistence/recovery invariants. Production financial inputs and source-support claims remain grounded in authentic source evidence; production output cannot be its own sole oracle. Isolated fixtures are permitted by the [owner's testing decision](SCOPE_DECISIONS.md#testing-restrictions-retired-20261015). Preserve exact native semantics and exercise affected ambiguity, atomicity, provider and hydration boundaries proportionally. Historical test transport/corpus restrictions do not override that decision.

<a id="protected-adopted-ledger"></a>
## Protected adopted ledger

After personal adoption, the normal ledger is protected user data, not a disposable development database. Earlier recreation or disposable-data permissions do not apply to it; see the [owner's adoption decision](SCOPE_DECISIONS.md#personal-v1-adoption-and-protected-ledger-20261003). <!-- user-specified -->

Before development work that may alter live data, persistence or schema, create and verify a current native backup outside Git. Preserve the existing ledger and exact original sources, and exercise development/test operations in an isolated namespace where possible. For an authorized live migration or persistence change, retain the backup, prove record/identity/manual-choice/source-link preservation and verify canonical hydration and normal relaunch. Never reset, delete, reseed, replace or downgrade the adopted ledger as a development shortcut; any intentional removal or replacement requires a fresh explicit owner decision naming that effect. A backup is a recovery safeguard, not permission to discard current data. <!-- user-specified -->

<a id="parser--authentic-corpus-acceptance-policy"></a>
## Parser and source regression selection

The owner [retired the historical testing restrictions](SCOPE_DECISIONS.md#testing-restrictions-retired-20261015). The retained anchor above supports existing links; it no longer requires an automatically cumulative full private corpus.

1. Select cases from the changed behavior and risk. Use deterministic isolated fixtures for ordinary mechanics, edge cases and rejection paths; keep them separate from production input and support claims.
2. For parser/source changes, retain a compact set of relevant originals and previously observed regressions. Broaden to additional families or the full corpus only for a concrete shared-boundary risk, unexplained failure or explicit task requirement.
3. Establish independent expected meaning before production comparison. Preserve exact Money, multiplicity, source order, date roles, identity and provenance; do not use the implementation as its sole oracle.
4. Exercise affected prepare/validate/confirm, atomic persistence, provider, reopen and hydration boundaries. Scope follows the actual change, not every historical campaign gate.
5. Record candidate identity, selected cases, actual results and remaining coverage limits. Synthetic coverage is valid regression evidence but is not an authentic observation. A changed boundary invalidates only the affected earlier evidence.

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

Persistence/startup changes preserve the independent accepted migration identity lock, explicit task-owned schema experiment namespace and genuine adopted-data upgrade acceptance. Use the existing durable-startup gate for actual SQLite/provider publication, clean quit and same-database relaunch; memory Run is insufficient. Apply the [protected-ledger procedure](#protected-adopted-ledger); historical recreation permissions do not authorize resetting adopted data. Keep product build identity and dirty/unavailable provenance truthful.

Runtime checks are required where automation cannot establish launch, navigation, import review/confirmation, provider replacement/relaunch, process contention or actual native interaction. Label passed/pending/unavailable/explicitly accepted deferral separately. No guessed native pass or blanket formal accessibility campaign.

Documentation-only changes require full diff, status-claim, link/path/anchor, ordering, privacy and Git-state review. They need no executable suite when executable sources/tests/migrations/resources/project metadata are unchanged. Exact Xcode documentation membership changes require project parse and the smallest affected build/resource-containment check, not product-feature acceptance. Changed checkers require focused checks.

## Reports and cross-tool evidence

Report exact starting/ending refs, changed paths/fingerprints, scope/exclusions, migration/ADR impact, source/oracle authority, named build/test/run IDs and nonzero counts, results/failures/non-runs, native/provider/recovery proof, privacy/residue, publication and falsification/limitations. Classify material claims **verified**, **reported only**, **contradicted** or **missing**. Complete logs are not the default report. Chat verifies before acceptance.

Where reviewers cannot access native artifacts, provide an allowed compact operational acceptance manifest readable by the authorized review surfaces, with candidate/parent, paths/hashes, test/build results, run IDs/times and only permitted evidence. It supplements native artifacts, never replaces them. Keep private originals and credentials out of Git. Local test artifacts are permitted under the current testing decision; avoid collecting irrelevant private payloads merely to satisfy a historical report recipe.

## Corrective numbering and documentation close

Chat assigns N, NA, NB in sequence without shifting later numbers. A blocker within a correction does not create another correction; unrelated defects need their own classification.

After technical acceptance, update the current snapshot, owning roadmap outcome, necessary ADR alignment and queue remainder with accepted-history links. Detailed tests/non-runs/limitations belong in accepted outcome collections. If acceptance is incomplete, label active unaccepted WIP. Decisions/rejection reasons belong in SCOPE_DECISIONS; substantive unresolved evidence in shared Work notes. Update AGENTS/Guide/Harness together only for reusable routing/ownership changes. Publication alone is not acceptance or personal adoption.

## Stop conditions and exceptions

Stop for conflicting owner/source/architecture authority, unexplained ref/WIP divergence, another writer, possible unique-work loss, guessed migration/identity, absent independent financial proof, failed required validation/parity/residue/recovery, private Git leakage, unavailable required controls or scope expansion. Name the boundary, preserve evidence and return to Chat. A deviation must identify the exact rule, reason and safety consequence; obtain owner authorization where not already supplied. Silence is not approval.
