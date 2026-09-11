# Project Guide

<a id="pg-00"></a>
## PG-00 — Reading contract

This is the documentation entry map. Read the task index, choose one primary task, then read only its named sections and evidence. Name any necessary secondary task. The complete current prompt remains execution authority; if classification or authority conflicts, clarify with Chat. Do not read the whole folder by default. Exit the chosen playbook at its END marker.

<a id="pg-01"></a>
## PG-01 — Task index

Order is natural PG-ID order. Terminals describe the task boundary, not automatic publication or product adoption.

| Task | Playbook | Terminal |
| --- | --- | --- |
| Plan/next sprint | [PG-10](#pg-10) | PLAN_READY |
| Targeted discovery | [PG-20](#pg-20) | DISCOVERY_RESOLVED or REJECTED_BY_PRIVATE_PERSONAL_SCOPE |
| Approved implementation | [PG-30](#pg-30) | IMPLEMENTATION_CANDIDATE |
| Bounded correction | [PG-35](#pg-35) | IMPLEMENTATION_CANDIDATE |
| Technical review/acceptance | [PG-40](#pg-40) | TECHNICALLY_ACCEPTED, REJECTED_WITH_BOUNDARY or BLOCKED_BY_NAMED_EVIDENCE |
| Documentation reconciliation | [PG-50](#pg-50) | DOCS_RECONCILED |
| Architecture decision | [PG-60](#pg-60) | ARCHITECTURE_DECIDED |
| Repository recovery | [PG-70](#pg-70) | RECOVERY_CLEAN |
| MCP infrastructure | [PG-80](#pg-80) | MCP_ACCEPTED |
| Exact pushed-repository question | [PG-90](#pg-90) | Verified answer |
| Guide maintenance | [PG-99](#pg-99) | Guide-specific completion |

<a id="pg-02"></a>
## PG-02 — Documentation ownership

Each fact has one primary home. Short safety reminders may link to it; do not reproduce independent full policies or current-status headers.

| Owner | Primary responsibility |
| --- | --- |
| [AGENTS](../AGENTS.md) | Mandatory bootstrap, critical constraints and routing |
| Project_Guide.md | Task/section routing, this ownership map and ordering contract |
| [Product Vision](Product%20Vision.md) | Private-app purpose and actual owner goals |
| [SCOPE_DECISIONS](SCOPE_DECISIONS.md) | Settled product choices, rejections, supersession/aliases and intake clarification |
| [PROJECT_STATE](PROJECT_STATE.md) | Current accepted product snapshot, limits and active unaccepted WIP |
| [FUTURE_WORK](FUTURE_WORK.MD) | One prioritized row per open item, practical readiness/blocker and basis |
| [Standing Harness](LedgerForge_Standing_Execution_Harness_Guide.md) | Writer/execution/review mechanics, proportional validation and evidence reports |
| [Build conventions](BUILD_AND_PROJECT_CONVENTIONS.md) | Repository/Xcode membership and actual local command interfaces |
| [Engineering Standards](Engineering%20Standards.md) | Financial/source/Money/identity/persistence/recovery invariants |
| [Architecture](Architecture_v1.0_Frozen.md) / [Database](Database_v1_Architecture.md) | Cross-layer / persistence boundaries; historical baseline separated from later accepted alignments |
| [ADR](ADR.md) | Accepted architecture, numeric index, original decision bodies and applicability updates |
| [UI/UX](UI_UX_v1.0_Frozen.md) | Shared UI architecture and routing to canonical contracts |
| [Current cycle](Sprint%20roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md) | Current sprint numbering, outcome, entry/exclusions and status |
| [Upcoming cycles](Sprint%20roadmap/Upcoming) | Prepared sequence only, activated explicitly by Chat |
| [R1 README](UI%20Assets/LF-UI-2026-09-R1/README.md) | Package map and canonical/supporting/draft distinction |
| R1 DESIGN_HANDOFF / screen contracts | Shared design requirements / canonical screen-specific requirements |
| R1 ACCEPTANCE / DESIGN_TOKENS / SOURCES / ASSET_MANIFEST | Required checks / numeric roles / provenance / deterministic payload inventory |
| [Work notes](Work%20notes) | Substantial unresolved evidence shared across related IDs; no duplicate backlog |
| [Accepted outcomes](Archive/Accepted%20outcomes) | Cycle-grouped original acceptance evidence, dates, failures, limits and non-runs |
| [Implementation reports](Archive/Implementation%20Reports), [archived roadmaps](Sprint%20roadmap/Archived), Git | Historical record bodies, not current authorization |

Exact local state comes from the selected local environment; exact pushed state comes from Git at the inspected ref. Neither a report nor an old upload proves current acceptance. Source support requires ADR-046, current state and the Harness corpus gate. When facts conflict, identify the precise ref and accepted-versus-WIP boundary, apply explicit owner decisions and source truth, and stop rather than guess.

<a id="documentation-order"></a>
## Maintained documentation order

A. **Open work:** P0 → P3; preserve explicit accepted relative ranking, otherwise natural FW-ID ascending including suffixes. Readiness and modification date do not establish priority.

B. **Parked work:** priority ascending, then natural ID; retain real deferral/revisit condition. No automatic each-sprint reevaluation.

C. **Scope decisions/rejections:** decision date descending; within a date use recorded sequence, otherwise natural ID as a declared display tie-break. Undated records last. Never use file mtime/copy dates as decisions.

D. **Aliases/consolidation:** former ID natural ascending, each pointing to its surviving/current destination. Never recycle IDs.

E. **Roadmaps:** sprint ascending in intended execution order, including corrective suffixes (89, 89A, 89B). Do not move numbers by readiness.

F. **Accepted outcomes/indexes:** acceptance date descending; same-date recorded acceptance sequence where known, otherwise natural sprint/correction ID descending as display order. Undated evidence stays explicitly undated.

G. **ADR:** numeric ADR index/records ascending; current alignment first, dated alignment updates newest first, original accepted text intact.

H. **UI inventory:** revision sequence, then natural SC number and A/B/C suffix. File manifests use deterministic relative-path order compatible with their schema; preserve semantic arrays.

I. **Work notes/file inventories:** natural owning ID or topic/path order. Dated observations follow the current conclusion, newest first.

J. **Procedures:** actual execution/dependency sequence with consecutive numbering. Never sort source rows, semantic arrays, code examples, original quotations or historical record interiors as administrative lists.

Historical roadmap/report interiors are immutable exceptions: retain their append order and old claims as history, with current collections/indexes clearly labelled. New collections order records, not their evidence interiors. Top-level document listing follows the owner-approved responsibility order above, not arbitrary filename prefixes.

<a id="pg-03"></a>
## PG-03 — Execution topology

The prompt specifies task, reasoning owner, model/effort, read/write roles, any authorized subagents/parallelism, exact writer ownership, environment/tool role, escalation and terminal. [Harness](LedgerForge_Standing_Execution_Harness_Guide.md#task-capsule) owns the mechanics. Model capability does not grant authorization. Use one writer by default; exceptions need explicit ownership. This documentation restructure is explicitly sequential with no subagents. Do not silently replace its topology.

<a id="pg-10"></a>
## PG-10 — Prepare roadmap / select next sprint

**Read:** Scope decisions, current state, queue in P0 → P3 order, current roadmap; relevant accepted ADR/evidence only for serious contenders.

Apply any one concrete personal relevance ground; check existing rejections. Separate priority from readiness, identify actual blockers and explicit deferrals, inspect only missing evidence, select one coherent outcome and define scope/exclusions/acceptance. Keep in-progress IDs until accepted. Chat chooses numbering and supplies a complete execution prompt; planning executes nothing.

**Terminal:** `PLAN_READY`.

**END PG-10**

<a id="pg-20"></a>
## PG-20 — Targeted discovery / diagnosis

**Read:** Owning FW/subject section, current state and precise relevant code/test/source evidence under the permitted task boundary.

Resolve the named question read-only unless the prompt explicitly authorizes writes. Distinguish verified, reported, inference and missing evidence; retain negative findings and falsifiers. Record an eligible finding in its owner, or a meaningful rejection in SCOPE_DECISIONS. An existing rejected category returns REJECTED_BY_PRIVATE_PERSONAL_SCOPE with its reference, not a new packet.

**Terminal:** `DISCOVERY_RESOLVED`.

**END PG-20**

<a id="pg-30"></a>
## PG-30 — Implement approved sprint

**Read:** Complete approved prompt, current roadmap section, current state, relevant engineering/ADR/UI authority and Harness validation method.

Verify writer ownership and exact preflight; implement only the selected boundary. Use focused falsification then required broader gates. Preserve source/oracle, atomicity, migration and hydration semantics. Report candidate evidence and limitations; do not self-accept or silently expand scope.

**Terminal:** `IMPLEMENTATION_CANDIDATE`.

**END PG-30**

<a id="pg-35"></a>
## PG-35 — Corrective sprint / bounded repair

**Read:** Named defect/attribution, affected accepted outcome and current correction contract, relevant ADR and validation authority.

Chat determines whether the defect is attributable to Sprint N and assigns NA/NB. Reproduce or preserve explicit missing reproduction evidence, fix the causal boundary and verify the correction plus affected acceptance. Unrelated defects do not become corrections by convenience.

**Terminal:** `IMPLEMENTATION_CANDIDATE`.

**END PG-35**

<a id="pg-40"></a>
## PG-40 — Technical acceptance / report review

**Read:** Exact candidate/ref/diff, approved scope, original source/oracle and native validation artifacts where relevant, current state/ADR.

Chat verifies material claims and boundaries, distinguishing report-only claims, contradictions and missing evidence. A local second pass is not independent review. Accept only exact proven scope; otherwise name the rejected boundary or missing proof. Synchronize durable accepted state only after acceptance.

**Terminal:** `TECHNICALLY_ACCEPTED / REJECTED_WITH_BOUNDARY / BLOCKED_BY_NAMED_EVIDENCE`.

**END PG-40**

<a id="pg-50"></a>
## PG-50 — Documentation reconciliation

**Read:** Changed subject authorities, relevant current state/roadmap, ownership/order contract and Harness documentation validation.

Preserve requirements, owner decisions, evidence, uncertainty and history while removing duplication. Update links and exact source consumers, preserve unrelated WIP, distinguish candidate from accepted product. Use one writer unless a prompt explicitly assigns safely disjoint writers; this authorized restructure requires one writer/no subagents. Return for Chat semantic review.

**Terminal:** `DOCS_RECONCILED`.

**END PG-50**

<a id="pg-60"></a>
## PG-60 — Architecture / ADR decision

**Read:** Exact problem/source evidence, current architecture/database boundaries, relevant accepted ADRs and scoped queue note.

Chat compares the smallest sufficient options against financial/source/persistence invariants, records chosen decision, consequences, exclusions and failure/validation boundaries. Preserve original accepted ADR bodies and numbered identity. Architecture acceptance does not authorize implementation.

**Terminal:** `ARCHITECTURE_DECIDED`.

**END PG-60**

<a id="pg-70"></a>
## PG-70 — Repository recovery / Git-state repair

**Read:** Mechanical current refs/index/worktrees/operations/writers, exact incident evidence, Harness writer/publication rules and Build membership rules where relevant.

Preserve unique work and distinguish accepted history from unaccepted WIP. No guessed reset/restore/clean/stash/rebase or overwrite. Clarify necessary destructive steps and required authorization; prove exact repaired Git/index/residue state. Do not terminate another writer to obtain ownership.

**Terminal:** `RECOVERY_CLEAN`.

**END PG-70**

<a id="pg-80"></a>
## PG-80 — MCP infrastructure engineering

**Read:** The separately authorized MCP repository/task contract and relevant cross-tool evidence requirements.

MCP infrastructure is separate from LedgerForge product implementation. Do not edit the product checkout merely to fix MCP tooling. Use the actual execution surface controls and preserve exact acceptance/release evidence. A product Codex task does not require MCP executor/admin; obey explicit tool restrictions.

**Terminal:** `MCP_ACCEPTED`.

**END PG-80**

<a id="pg-90"></a>
## PG-90 — Simple pushed-repository question

**Read:** Exact pushed ref and only the relevant source/document sections.

Answer the precise question using exact-ref evidence. Do not write, select a sprint, infer local WIP from remote state or trigger broad discovery/validation. State any missing evidence plainly.

**Terminal:** `Verified answer`.

**END PG-90**

<a id="pg-99"></a>
## PG-99 — Guide maintenance

**Read:** Affected routing, owner document and this ordering contract; AGENTS/Harness if reusable routing changes.

Keep PG identities and terminal meanings stable. Update actual callers, keep the Guide as the sole entry map and preserve one owner per fact. A routing change is not a new orchestration framework or product authorization.

**Terminal:** `Guide-specific completion`.

**END PG-99**
