# Roadmap: Sprints 80–89

**CURRENT cycle.** Sprints 80–88 are accepted; Sprint 89 is paused/unaccepted. [PROJECT_STATE](../PROJECT_STATE.md) owns the accepted product ref and current limits. The documentation restructure selects or resumes no sprint. [Scope decisions](../SCOPE_DECISIONS.md), [queue](../FUTURE_WORK.MD) and the complete approved prompt control eligible scope, readiness and execution respectively.

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
| [89 — R1 Transactions reference implementation](#sprint-89) | FW-P2-03/53; necessary Transactions portions of FW-P2-48/50 | **PAUSED / UNACCEPTED WIP**. Refreshed exact-ref/writer preflight and corrected approved contract required. |

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

**PAUSED / UNACCEPTED WIP.** Existing Sprint-89 product changes remain separate and unaccepted. The explicit 2026-09-11 scope correction removes the formal accessibility work before acceptance. This documentation task does not accept Sprint 89 or implement product changes; continuation uses the corrected approved contract after a fresh exact-ref preflight.

Queue: `FW-P2-03` + `FW-P2-53`, with only necessary bounded portions of `FW-P2-48` and `FW-P2-50`.

Required boundary:

- AND across filter groups and OR within a multi-select group;
- native-currency presentation and totals only;
- exact source-date semantics without timezone invention;
- deterministic sorting with stable tie behavior;
- stable selection and collapsible inspector;
- totals over the full matching scope, not merely visible rows;
- bank cash movement and card-liability effects remain distinct;
- no hidden FX conversion;
- no debit = spending or credit = income inference;
- targeted source/runtime verification of the existing INR colour observation **before** any financial-colour semantic change.

**Owner usability acceptance:** no clipping/overlap; usable target widths and full readable Money/currency; deterministic filters, sorting and matching-scope totals; stable selection and inspector behavior; useful ordinary keyboard interaction; focus distinct from selection; useful names/tooltips for icon-rail controls. No formal accessibility campaign is part of this sprint.

The [data algebra](../Work%20notes/Transaction_and_R1_workflows.md#packet-sprint89-data-algebra) retains the independent membership/order/native-currency-total oracle. The [native procedure](../Work%20notes/Transaction_and_R1_workflows.md#packet-sprint89-native-acceptance-procedure) tests the actual Transactions workflow. Targeted source/runtime evidence remains required before changing the observed INR colour semantics; a screenshot alone cannot establish a financial defect.

`FW-P2-77` remains explicitly deferred, not forgotten. Its maintenance value does not outrank the P1/P2 user outcomes above, and broad physical moves must not be mixed with app-shell or R1 behavioral work.

## Selection and continuation

The full priority/readiness queue remains [FUTURE_WORK](../FUTURE_WORK.MD); this roadmap is not a competing candidate table. A rejected category cannot block retained work. The accepted SHELL88 blueprint is [historical evidence](../Archive/Accepted%20outcomes/Sprints_80-89.md#historical-shell88-blueprint), including its excluded source-organization phase. The exact Sprint-89 algorithm/native procedure and unaccepted Import Preview feedback are in [Transactions/R1 work notes](../Work%20notes/Transaction_and_R1_workflows.md).

Before a future financial run, apply the owner's [current in-memory source/evidence processing rule](../SCOPE_DECISIONS.md#source-processing-decision); previous artifact-producing recipes are not automatically compliant. This documentation task does not change the executable validation pipeline.
