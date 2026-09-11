# Roadmap: Sprints 80–89

**80–89 COMPLETE / ACCEPTED.** All Sprints 80–89 are accepted. [PROJECT_STATE](../PROJECT_STATE.md) owns the accepted product ref and current limits. The prepared [90–99](Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md) roadmap remains **PREPARED / NOT YET CHAT-AUTHORIZED**; this completed-cycle record neither activates it nor selects a new sprint. [Scope decisions](../SCOPE_DECISIONS.md), [queue](../FUTURE_WORK.MD) and a future complete approved prompt control eligible scope, readiness and execution.

Order inherits [Guide rule E](../Project_Guide.md#documentation-order): sprint number ascending with corrective suffixes. Prepared [90–99](Upcoming/LedgerForge_Roadmap_Sprints_90-99_Planned.md) and [100–109](Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md) require explicit Chat activation. Higher-priority real correctness work is reconsidered before selection; blocked items do not shift numbering. Detailed historical results, limitations, non-runs and refs are in [accepted outcomes](../Archive/Accepted%20outcomes/Sprints_80-89.md).

## Cycle sequence

| Sprint / outcome | Selected IDs | Status and real boundary |
| --- | --- | --- |
| [80 — Swift 6 and macOS readiness closure](#sprint-80) | Accepted discovery; no implementation ID | Accepted. Read-only Swift 6/macOS readiness discovery; no repairs or migration. |
| [81 — PR-1 Staging and Runtime Publication Ownership Seam](#sprint-81) | Completed FW-P2-72 | Accepted. PR-1 staging/runtime publication seam; behavior-preserving, no new import/source semantics. |
| [82 — Serial Unified Import Centre Foundation](#sprint-82) | Completed FW-P1-19 | Accepted. Serial Import Centre, queue length one and Sprint 83 entry evidence; no batch-wide atomicity. |
| [83 — Serial Batch Import and Multi-File Drag-and-Drop](#sprint-83) | Completed FW-P1-20/21 | Accepted. Serial queue length N, picker/drop and independent item review/confirmation/outcomes; no parallel imports. |
| [84 — PR-2 SQLite / Provider / Migration Ownership](#sprint-84) | Completed FW-P2-73 | Accepted. PR-2 SQLite/provider/migration ownership; no schema migration. |
| [85 — PR-3 Dependency Concurrency Boundary](#sprint-85) | Completed FW-P2-74 | Accepted. Local ZIPFoundation correction and process-local libxls serialization; bounded dependency ownership. |
| [86 — TEST-PR Strict-Concurrency Test Correction](#sprint-86) | Completed FW-P2-75 | Accepted. Strict-concurrency test/support correction; production bytes frozen. |
| [87 — Coordinated Swift-6 Migration](#sprint-87) | Completed FW-P2-76 | Accepted. Coordinated native Swift 6; migration/ADR semantics unchanged. |
| [88 — App Shell and Workflow Decomposition](#sprint-88) | Completed FW-P2-67 | Accepted. App shell/workflow decomposition; no R1 behavior or broad source organization. |
| [89 — R1 Transactions reference implementation](#sprint-89) | Completed FW-P2-03/53; necessary Transactions portions of FW-P2-48/50 | **Accepted**, `038af8d9ebebe66b3f17925416821941cfa33d3d`, `SPRINT_89_TRANSACTIONS_REFERENCE_ACCEPTED`. Detailed evidence is in [accepted outcomes](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-89). |

<a id="sprint-80"></a>
## Sprint 80 — Accepted outcome

Accepted discovery; no implementation ID. Read-only Swift 6/macOS readiness discovery; no repairs or migration. Entry conditions, original acceptance scope, exact evidence and historical limitations remain in [Sprint 80 record](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-80). Acceptance is historical fact; old “next” statements in records are not current authorization.

<a id="sprint-81"></a>
## Sprint 81 — Accepted outcome

Completed FW-P2-72. PR-1 staging/runtime publication seam; behavior-preserving, no new import/source semantics. Entry conditions, original acceptance scope, exact evidence and historical limitations remain in [Sprint 81 record](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-81). Acceptance is historical fact; old “next” statements in records are not current authorization.

<a id="sprint-82"></a>
## Sprint 82 — Accepted outcome

Completed FW-P1-19. Serial Import Centre, queue length one and Sprint 83 entry evidence; no batch-wide atomicity. Entry conditions, original acceptance scope, exact evidence and historical limitations remain in [Sprint 82 record](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-82). Acceptance is historical fact; old “next” statements in records are not current authorization.

<a id="sprint-83"></a>
## Sprint 83 — Accepted outcome

Completed FW-P1-20/21. Serial queue length N, picker/drop and independent item review/confirmation/outcomes; no parallel imports. Entry conditions, original acceptance scope, exact evidence and historical limitations remain in [Sprint 83 record](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-83). Acceptance is historical fact; old “next” statements in records are not current authorization.

<a id="sprint-84"></a>
## Sprint 84 — Accepted outcome

Completed FW-P2-73. PR-2 SQLite/provider/migration ownership; no schema migration. Entry conditions, original acceptance scope, exact evidence and historical limitations remain in [Sprint 84 record](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-84). Acceptance is historical fact; old “next” statements in records are not current authorization.

<a id="sprint-85"></a>
## Sprint 85 — Accepted outcome

Completed FW-P2-74. Local ZIPFoundation correction and process-local libxls serialization; bounded dependency ownership. Entry conditions, original acceptance scope, exact evidence and historical limitations remain in [Sprint 85 record](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-85). Acceptance is historical fact; old “next” statements in records are not current authorization.

<a id="sprint-86"></a>
## Sprint 86 — Accepted outcome

Completed FW-P2-75. Strict-concurrency test/support correction; production bytes frozen. Entry conditions, original acceptance scope, exact evidence and historical limitations remain in [Sprint 86 record](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-86). Acceptance is historical fact; old “next” statements in records are not current authorization.

<a id="sprint-87"></a>
## Sprint 87 — Accepted outcome

Completed FW-P2-76. Coordinated native Swift 6; migration/ADR semantics unchanged. Entry conditions, original acceptance scope, exact evidence and historical limitations remain in [Sprint 87 record](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-87). Acceptance is historical fact; old “next” statements in records are not current authorization.

<a id="sprint-88"></a>
## Sprint 88 — Accepted outcome

Completed FW-P2-67. App shell/workflow decomposition; no R1 behavior or broad source organization. Entry conditions, original acceptance scope, exact evidence and historical limitations remain in [Sprint 88 record](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-88). Acceptance is historical fact; old “next” statements in records are not current authorization.

<a id="sprint-89"></a>
## Sprint 89 — LF-UI-2026-09-R1 Transactions Reference Implementation

**ACCEPTED on 2026-09-11** at implementation commit `038af8d9ebebe66b3f17925416821941cfa33d3d` under `SPRINT_89_TRANSACTIONS_REFERENCE_ACCEPTED`.

Completed queue: `FW-P2-03` and `FW-P2-53`; only the necessary Transactions portions of `FW-P2-48` and `FW-P2-50` were consumed.

The accepted outcome supplies literal multi-term Transactions search; explicit period/account/currency/category/family/effect/institution/amount filtering; AND-across/OR-within selection semantics; deterministic Date, Description, Account, Category and Amount sorting; native-currency-safe ordering; matching-scope totals; separated bank cash and card-liability effects; stable explicit selection; collapsible details; complete native Money; constrained icon rail; ordinary keyboard interaction; focus distinct from selection; useful icon names/tooltips; and no financial meaning inferred from decorative colour.

Chat accepted 22 focused definitions/executions with zero failures, Debug and optimized Release under Swift 6, an independent in-memory presentation oracle, zero changed tables across 53 comparisons, native 1440 × 900 and 1024 × 768 checks, the bounded Transactions-to-Settings size transition, and bundle containment without UI design-reference resources. A complete TestPlan, parser/source corpus campaign and formal accessibility qualification were not run for this corrected Transactions-local boundary.

Accepted limitations: genuine presentation data contained no mixed-native-currency or unavailable-source-date case; native category assignment/clear was unavailable because the current database had no categories; and 768/640 widths were not separately qualified. No migration was made, no V18 or new ADR was introduced, and Personal-v1 remains **NOT YET ADOPTED**. `FW-P2-49` remains **NOT REQUIRED-DO NOT CONSIDER**. The [accepted Sprint 89 record](../Archive/Accepted%20outcomes/Sprints_80-89.md#sprint-89) retains the detailed evidence and design/publication separation.

## Completion and future activation

The full priority/readiness queue remains [FUTURE_WORK](../FUTURE_WORK.MD); this roadmap is not a competing candidate table. A rejected category cannot block retained work. The accepted SHELL88 blueprint is [historical evidence](../Archive/Accepted%20outcomes/Sprints_80-89.md#historical-shell88-blueprint), including its excluded source-organization phase. [Transactions/R1 work notes](../Work%20notes/Transaction_and_R1_workflows.md) retain unresolved Import Preview alternatives and remaining cross-screen R1 questions, not a second Sprint-89 report.

Sprint 90 remains **PREPARED / NOT YET CHAT-AUTHORIZED**. Before any future financial run, apply the owner's [current in-memory source/evidence processing rule](../SCOPE_DECISIONS.md#source-processing-decision); previous artifact-producing recipes are not automatically compliant. This documentation closure does not change the executable validation pipeline.
