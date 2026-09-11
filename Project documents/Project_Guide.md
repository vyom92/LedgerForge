# LedgerForge Project Guide

**Status:** Active task-routing authority

## PG-00 — Machine Reading Contract

This file is a routing guide, not a general project briefing.

For every task:

1. Read **PG-01 Task Index**.
2. Classify the task as exactly one primary task type.
3. Jump directly to that task's `PG-*` section.
4. Read only that task section, authorities explicitly named by that section, and source/tests/evidence required by the task.
5. Do not read other playbooks merely because they exist.
6. If a task genuinely spans multiple types, the Coordinator must name the primary type and explicitly authorize any secondary playbook.
7. Exit this guide at the `END PG-*` marker for the selected section.

Do not load the whole document into working context by default.

The complete Chat-approved execution prompt remains the execution contract. This guide routes work; it does not authorize implementation.

---

## PG-01 — Task Index

| Task type | Jump to | Terminal state |
|---|---|---|
| Prepare roadmap / select next sprint | `PG-10` | `PLAN_READY` |
| Targeted discovery / diagnosis | `PG-20` | `DISCOVERY_RESOLVED` or `REJECTED_BY_PRIVATE_PERSONAL_SCOPE` |
| Implement an approved sprint | `PG-30` | `IMPLEMENTATION_CANDIDATE` |
| Corrective sprint / bounded repair | `PG-35` | `IMPLEMENTATION_CANDIDATE` |
| Technical acceptance / report review | `PG-40` | `TECHNICALLY_ACCEPTED`, `REJECTED_WITH_BOUNDARY`, or `BLOCKED_BY_NAMED_EVIDENCE` |
| Documentation sync | `PG-50` | `DOCS_RECONCILED` |
| Architecture / ADR decision | `PG-60` | `ARCHITECTURE_DECIDED` |
| Repository recovery / Git-state repair | `PG-70` | `RECOVERY_CLEAN` |
| MCP infrastructure engineering | `PG-80` | `MCP_ACCEPTED` |
| Simple pushed-repository question | `PG-90` | Verified answer |
| Maintain this guide | `PG-99` | Guide-specific completion |

If no row clearly matches, return to Chat for task classification. Do not invent a new workflow casually.

---

## PG-02 — Minimal Authority Map

Read an authority only when the selected playbook requires it.

| Need | Authority |
|---|---|
| Current accepted repository state | `PROJECT_STATE.md` |
| Unscheduled work / canonical queue | `FUTURE_WORK.MD` |
| Accepted architecture | `ADR.md` + relevant architecture document |
| Financial-source ingestion / parser support | ADR-046 + Standing Harness **Parser / Authentic-Corpus Acceptance Policy** + current `PROJECT_STATE.md` parser-reliability alignment |
| Persistence / migrations | `Database_v1_Architecture.md` + registered migrations |
| Financial engineering invariants | `Engineering Standards.md` |
| Build, Xcode, Git and validation mechanics | `BUILD_AND_PROJECT_CONVENTIONS.md` |
| Approved UI | `UI_UX_v1.0_Frozen.md` + approved assets |
| Actual pushed implementation | GitHub exact ref |
| Actual local / unstaged implementation | MCP Executor / direct local evidence |
| Execution authorization | Complete current Chat-approved prompt |

Memory, old conversations, uploads and reports are context, not repository authority. Reports are claims until independently verified.

**Private Personal App Scope Gate:** apply [AGENTS.md](../AGENTS.md#private-personal-app-scope-gate) before planning, discovery, implementation or acceptance. LedgerForge serves the owner's own finances on the owner's Mac. Require a real requested owner workflow, actual data correctness/persistence/privacy/recovery need, supplied/selected authentic source or concrete day-to-day usability benefit. Otherwise: **NOT REQUIRED-DO NOT CONSIDER**. Exclude rejected work from priority triage and dependency chains; discovery cannot reopen it without a new explicit owner decision naming the personal need. <!-- user-specified -->

**Material-finding routing:** Only scope-eligible material findings require a durable disposition in their subject authority or `FUTURE_WORK.MD`. Generalized commercial/platform speculation may return `REJECTED_BY_PRIVATE_PERSONAL_SCOPE` without a new card or packet. A recorded eligible proposal remains a proposal until separately accepted.

The user-settled all-stages authentic-input rule in ADR-046 and the Standing Harness applies before development or debugging as well as during acceptance: no generated, reconstructed, sanitized, representative, reduced, mutated or hand-authored financial statement may be created or used. Only authentic corpus inputs (including operational exact/decrypted copies or actual attachments) may exercise statement-dependent behaviour. Nonfinancial mechanics remain permitted; absent authentic cases remain source-uncertified. <!-- user-specified -->

---

## PG-03 — Coordinator Execution-Topology Requirement

Whenever the Coordinator prepares an execution prompt, the prompt MUST explicitly determine:

- primary task type;
- reasoning owner;
- parent model;
- reasoning level;
- model justification;
- subagent count, model, and reasoning;
- read/write role;
- parallelism;
- write ownership;
- MCP role;
- escalation condition;
- required terminal state.

Required prompt block:

```text
EXECUTION TOPOLOGY

Primary task type:
<PG section>

Reasoning owner:
<Chat / execution model>

Parent execution model:
<model or none>

Parent reasoning level:
<low / medium / high / max>

Why this model/reasoning level:
<bounded justification>

Subagents:
<none / count + model + reasoning>

Subagent mode:
<read-only / writer / specialist>

Parallelism:
<none / parallel / sequential>

Write ownership:
<one writer / exact disjoint ownership>

MCP role:
<read evidence / mutation gate / validation / final verification / publish>

Escalation condition:
<exact condition requiring return to Chat>

Required terminal state:
<defined PG end state>
```

Use the least costly model/reasoning level that can safely complete the bounded work. Prefer Chat Sol High for sprint selection, architecture, financial-source-truth reasoning, acceptance, and cross-authority semantic reconciliation; Luna High for tightly bounded implementation, one-file edits, mechanical transformations, and focused evidence work; Luna Max for broad integration/orchestration and final cross-file consistency reasoning.

Use subagents only when decomposition reduces context or increases independent verification. For production code prefer one writer plus read-only specialists. Multiple writers require explicit disjoint ownership. Documentation sync is the canonical one-file-per-writer exception. The execution model must not silently redesign its model/subagent topology unless the approved prompt delegates that decision.

---

# PG-10 — Prepare Roadmap / Select Next Sprint

## Purpose
Choose the next bounded product outcome without authorizing implementation.

## Reasoning owner
Chat / Coordinator. Default reasoning: **Sol High**.

## Read
GitHub exact pushed ref; `PROJECT_STATE.md`; `FUTURE_WORK.MD`; relevant ADR/code/tests only for serious contenders; MCP only when local/unpushed evidence materially affects selection.

## Method
0. **STEP 0 — PRIVATE PERSONAL APP ELIGIBILITY.** Before P0 → P3 triage, answer all four AGENTS.md eligibility questions: the real owner workflow; the actual owner data/source/safety issue; why the smallest direct solution is insufficient; and whether generalized commercial convention is the only justification. If either of the first two has no concrete answer, mark **NOT REQUIRED-DO NOT CONSIDER** and exclude it from candidate comparison. Rejected work cannot block eligible work.
1. Establish exact inspected ref.
2. Read current state and canonical queue in P0 → P1 → P2 → P3 order.
3. Separate priority from readiness.
4. Classify serious higher-priority candidates as implementation-ready, ready for targeted discovery, blocked by named dependency, completed/no longer applicable, or explicitly deferred.
5. Inspect only evidence needed to distinguish serious contenders.
6. Decide combine/split boundary and select one outcome.
7. Define included scope, exclusions, acceptance boundary, stop conditions, migration impact, and ADR impact.
8. Prepare execution topology under `PG-03`.

Default subagents: none. Read-only Luna High agents are allowed only for independent bounded evidence gaps. No writers.

## Required end state: `PLAN_READY`
Planning is complete and implementation has not begun.

**END PG-10**

---

# PG-20 — Targeted Discovery / Diagnosis

## Purpose
Resolve one decision-critical unknown.

## Reasoning owner
Chat defines the question and decision boundary. Use Luna High for bounded diagnosis; Luna Max only when causal tracing spans several tightly coupled layers.

## Tools
Use the least invasive proving source: GitHub for pushed truth; MCP/direct local evidence for current local/unstaged truth; specialist macOS tooling for Xcode/SwiftUI/runtime questions; Browser only for current official external documentation.

## Method
1. Apply the Private Personal App Scope Gate; state the exact eligible unknown and why it affects the owner's actual outcome. Do not widen a real problem into a generalized product program.
2. Inspect the smallest plausible causal boundary; widen only when evidence requires it.
3. Separate verified fact, reported fact, inference, and unresolved gap.
4. Identify the first causal ownership layer.
5. Return cause, evidence, affected scope, candidate repair boundary, and remaining uncertainty.

Read-only parallel Luna High agents are allowed only for independent causal boundaries. No parallel writers.

## Required end state: `DISCOVERY_RESOLVED`
The unknown is resolved sufficiently for Chat to decide, or one named blocker and its required evidence are established. Ineligible discovery returns `REJECTED_BY_PRIVATE_PERSONAL_SCOPE` without creating a future-work card. No opportunistic implementation. Scope-eligible material out-of-scope findings receive a durable disposition; generalized speculation does not enter the queue.

**END PG-20**

---

# PG-30 — Implement Approved Sprint

## Purpose
Implement exactly the Chat-approved sprint outcome.

## Reasoning owner
Chat owns scope, architecture, source truth, and acceptance boundary. Codex owns bounded implementation under the approved prompt.

## Default topology
Narrow work: Luna High parent, High reasoning, no subagents or bounded read-only specialists. Broad/cross-layer work: Luna Max parent, High reasoning, Luna High read-only specialists, normally one production writer.

## Method
1. Consume the approved execution contract and verify live-state evidence. For any financial-source ingestion/support work, read ADR-046, the Standing Harness parser/authentic-corpus policy and the current `PROJECT_STATE.md` parser-reliability alignment before implementation.
2. Stop on material contradiction.
3. Acquire mutation authority only immediately before mutation.
4. Edit only approved scope; reject speculative scope expansion under the Private Personal App Scope Gate.
5. Run the smallest meaningful validation first, then widen only as acceptance/risk requires.
6. Test falsification paths, not only success paths.
7. Leave the candidate unstaged unless publication is explicitly included.
8. Return exact MCP candidate-state evidence.
9. Durably disposition scope-eligible material out-of-scope findings before close. Reject hypothetical generalized work without adding cards or packets.

## Required end state: `IMPLEMENTATION_CANDIDATE`
A bounded local candidate appears to satisfy acceptance. It remains pending Chat acceptance.

**END PG-30**

---

# PG-35 — Corrective Sprint / Bounded Repair

## Purpose
Repair a defect attributable to an existing sprint without silently widening scope.

## Reasoning owner
Chat determines attribution, corrective suffix, and minimum repair boundary.

Use `PG-30` execution mechanics.

## Method
1. Establish the failed acceptance condition and attribution to Sprint N.
2. Preserve the original intended outcome.
3. Repair only the first causal boundary plus required consequences.
4. Add regression/falsification evidence. Parser/source repairs must use the complete affected authentic corpus; synthetic financial-source fixtures or partial authentic sampling cannot establish corrected source support.
5. Do not absorb unrelated work or renumber later planned sprints.

## Required end state: `IMPLEMENTATION_CANDIDATE`
The corrected original outcome is ready for Chat acceptance.

**END PG-35**

---

# PG-40 — Technical Acceptance / Report Review

## Purpose
Determine whether a candidate actually satisfies the approved outcome.

## Reasoning owner
Chat / Coordinator. Default reasoning: **Sol High**.

## Method
Verify candidate identity, branch/worktree handling, changed files, scope/exclusions, architecture/migration impact, independent-oracle boundary, test boundary, source truth where relevant, provider parity where relevant, persistence/hydration/relaunch/presentation where relevant, privacy/residue, falsification evidence, and final local state. For reader/parser/source-support claims, ADR-046 requires the complete affected authentic corpus through the ordinary production path; synthetic financial-source fixtures, partial authentic sampling and a green TestPlan alone cannot authorize support.

Treat execution reports as claims. Classify material claims as verified, reported only, contradicted, or missing.

Judge the actual approved private-app outcome and its financial/safety proof, not hypothetical commercial completeness. Formal accessibility, public distribution or platform readiness is not an acceptance requirement unless a new explicit owner decision establishes the exact personal need.

Before acceptance closes, scope-eligible material out-of-scope findings need a durable disposition; generalized speculation returns `REJECTED_BY_PRIVATE_PERSONAL_SCOPE`. Acceptance does not turn a proposal into approved scope.

Optional Luna High subagents are read-only evidence audits. No writers.

## Required end state
Exactly one:
- `TECHNICALLY_ACCEPTED`
- `REJECTED_WITH_BOUNDARY`
- `BLOCKED_BY_NAMED_EVIDENCE`

Acceptance does not automatically imply publication.

**END PG-40**

---

# PG-50 — Documentation Sync

## Purpose
Reconcile accepted implementation, architecture, roadmap, and workflow truth without creating another duplicated policy layer.

## Reasoning owner
**Chat / Coordinator performs semantic reasoning file-by-file.** Default reasoning: **Sol High**. The execution model implements already-settled semantic specifications.

## Canonical topology

```text
Chat semantic reasoning
→ MCP live unstaged evidence
→ file-by-file specifications
→ MCP mutation gate
→ Luna Max coordinator
→ one Luna High writer per file
→ Luna Max read-only cross-file verification
→ Chat rereads actual files via MCP
→ semantic acceptance
→ publication gate
```

## Rules
1. Chat freezes accepted product truth before writers edit dependent facts.
2. MCP provides live local/unstaged truth; GitHub is not used to infer local state.
3. Chat specifies each target file independently: preserve, remove, add, move, structural requirements, and cross-file invariants.
4. Each Luna High writer owns exactly one file and may not edit another.
5. Cross-file problems are reported as `CROSS_FILE_NOTE`, not edited outside ownership.
6. Luna Max coordinates writers, then performs read-only cross-file verification after subagents finish.
7. Luna Max does not integration-edit after subagents finish.
8. Chat rereads the actual resulting files through MCP and performs semantic acceptance.
9. Documentation-only work does not trigger application-wide tests unless executable material changed.
10. The current repository-owned roadmap and Standing Execution Harness are durable repository authorities. Older dated copies remain historical/context only and do not override the repository-owned current copies.
11. When parser/source-support documentation changes, reconcile it against ADR-046, the Standing Harness parser/authentic-corpus policy and the current `PROJECT_STATE.md` parser-reliability alignment; preserve historical records but remove contradictory current authority.
12. Give scope-eligible material out-of-scope findings a durable disposition. Reject generalized speculation without creating queue cards or packets, and remove stale dependencies on rejected work from retained cards, roadmaps and design acceptance.

## Required end state: `DOCS_RECONCILED`
Current authorities agree; obsolete current-state claims are removed or narrowed; historical claims remain historically accurate; policy has one durable home where practical; routing points to subject authorities instead of duplicating them; scope-eligible material findings have durable dispositions and rejected work is absent from active candidates/dependencies; no private originals or unsanitized private-source material leaked into published artifacts; only approved sanitized, clean-room or privacy-safe derived artifacts are eligible for publication; final diff is ready for publication review.

**END PG-50**

---

# PG-60 — Architecture / ADR Decision

## Purpose
Resolve an architectural question before implementation.

## Reasoning owner
Chat. Default: **Sol High**.

## Method
1. Define the architectural question and existing accepted constraints.
2. Gather only decision-relevant ADR, architecture, source/test, local, and official external evidence.
3. Compare serious alternatives against correctness, persistence, determinism, migration, privacy, and operability.
4. Decide or name the blocker.
5. Record an ADR only after the decision is accepted.

Read-only Luna High specialists may investigate independent alternatives/layers. They do not decide architecture.

## Required end state: `ARCHITECTURE_DECIDED`
An explicit architecture decision or named unresolved blocker exists. Implementation remains separately authorized.

**END PG-60**

---

# PG-70 — Repository Recovery / Git-State Repair

## Purpose
Make repository state understood and safe without losing unique work.

## Decision owner
Chat.

## Primary tool
MCP Executor / direct local repository evidence. Do not infer local state from GitHub.

## Method
Inventory primary worktree, branch/HEAD, main/origin-main relation, staged/unstaged/untracked paths, linked worktrees, local/remote branches, stashes, active operations, leases/processes, and unique commits. Classify every unexplained state; preserve all unique work; consolidate only proven compatible work; remove only proven redundant state with explicit authorization; verify final state.

Normally use no subagents. Repository destruction is never delegated to autonomous agents.

## Required end state: `RECOVERY_CLEAN`
One understood safe primary worktree, with no unique or unexplained work lost.

**END PG-70**

---

# PG-80 — MCP Infrastructure Engineering

## Purpose
Develop or maintain LedgerForge MCP infrastructure without conflating it with LedgerForge product implementation.

## Ownership
MCP Developer workflow. Product sprint Coordinator retains authority over product-repository impact.

## Method
1. Define the MCP infrastructure change and baseline.
2. Implement in the LedgerForge-MCP repository/scratch.
3. Static/unit qualify; deploy/qualify the live executor as required; verify recovery/rollback.
4. Perform only bounded product-repository compatibility checks unless product mutation is separately authorized.
5. Report exact executor/tool/schema state.

Coordinator chooses model/reasoning under `PG-03`. MCP infrastructure-admin authority never implies product-writing authority.

## Required end state: `MCP_ACCEPTED`
Qualified MCP infrastructure with product-repository isolation preserved.

**END PG-80**

---

# PG-90 — Simple Pushed-Repository Question

## Purpose
Answer a bounded factual question about pushed repository state.

## Tools
GitHub exact ref. Read only the smallest relevant file/code/test.

## Method
1. Identify exact ref.
2. Inspect the smallest authoritative source.
3. Answer and state uncertainty if the source cannot establish the claim.

Do not load roadmap, complete project state, recovery rules, unrelated ADRs, or local-state evidence.

## Required end state
Verified answer with exact pushed-repository evidence.

**END PG-90**

---

## PG-99 — Guide Maintenance

Change this guide only when task classifications, authority routing, model/tool ownership, execution-topology rules, or terminal-state definitions materially change.

Do not add sprint history, support matrices, migration history, parser architecture detail, financial-rule detail, build commands, Git recipes, or duplicated subject-authority content.

When this guide conflicts with a subject authority, repair the guide. Keep section IDs stable so agents can jump directly to known `PG-*` sections.

**END PG-99**

## End of Project Guide
