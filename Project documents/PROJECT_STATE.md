# Current project state

## Accepted product baseline

**Latest accepted numbered implementation: Sprint 88 — App Shell and Workflow Decomposition**, `4f5eeb7b11c0f5879204a06ae9f08045304342b5` (parent documentation closure `4973d2d2507ae5891bfa593b359af2b9393e5fa1`). Native targets use Swift 6. The current accepted migration is **V17**; V1–V16 remain immutable. No V18 is authorized. Exact DDL is owned by the [registered migrations](../Database/Migrations.swift), architecture by [ADRs](ADR.md), and persistence boundaries by [Database architecture](Database_v1_Architecture.md).

Documentation commits do not change that product baseline. This snapshot summarizes accepted evidence; this documentation restructure ran no application TestPlan, source-corpus campaign or native product acceptance. **PERSONAL-V1: NOT YET ADOPTED.** The owner-required outcome and exclusions live in [SCOPE_DECISIONS](SCOPE_DECISIONS.md), with the prepared [Sprint 100 personal-adoption gate](Sprint%20roadmap/Upcoming/LedgerForge_Roadmap_Sprints_100-109_Planned.md).

## Active task and WIP

[Sprints 80–89](Sprint%20roadmap/LedgerForge_Roadmap_Sprints_80-89_Current.md) is the current cycle. **Sprint 89 is PAUSED / UNACCEPTED WIP**, covering FW-P2-03/53 and only necessary Transactions portions of FW-P2-48/50. Its existing code, tests and project changes have not been accepted by this documentation task. Continuation requires a fresh exact-ref/worktree preflight and the corrected approved contract; nothing here resumes it.

The owner-authorized PG-50/PG-99 documentation restructure is a review candidate. [FW-P2-77](FUTURE_WORK.MD#fw-p2-77) retains the broader source-organization remainder, which is not authorized by the documentation task. The prepared 90–99 and 100–109 roadmaps remain non-current until Chat explicitly activates them. Local uncommitted/untracked state must always be established mechanically, not inferred from this file.

## Current capabilities

| Area | Accepted behavior and material boundary |
| --- | --- |
| Application shell | Sprint 88 separates shell presentation, destination construction, Import Centre footer rendering and hydration workflow while preserving provider/activity/hydrator/import ownership. R1 implementation is not implied. |
| Import workflow | Sprint 82 Unified Import Centre plus Sprint 83 serial multi-file intake and drag-and-drop; queue length one uses the same path. Unlock/extraction/classification/family interpretation, validation, exact duplicate/equivalence checks, account review and explicit confirmation precede one provider-owned atomic accepted graph. Serial batch intake is not batch-wide atomicity. |
| Persistence | SQLite production behind provider/repository boundaries, exact Money, immutable identity/provenance, durable attempts, migration identity lock, canonical hydration, generation-safe publication and fail-closed unavailable states. A committed graph followed by hydration failure remains committed; retry must not duplicate it. |
| Identity and duplicates | Exact original-byte fingerprints; parser-owned verified identifiers and explicit no-match account choice; supported source-specific equivalence only. HDFC PDF/XLS (ADR-042), CBQ bank lineage (ADR-043) and Axis-card equivalence (ADR-044) retain exact boundaries. Axis-bank engineering parity is not durable equivalence. |
| Transactions and categories | Repository-backed transactions, native-currency presentation, trusted source dates/order/document binding, manual category assignment and category reconciliation. Rules, broad historical repair, transfer matching and arbitrary financial mutation are not accepted by their backlog presence. |
| Salary | Qatar Airways source actuals and Salary History; current This Month planner with coherent draft/Save, natural Money entry, contextual provenance and non-negative configured QAR fee validation. Zero fee is valid; effective fee is zero when no India funding is required. Salary evidence never creates bank transactions. Current Al Dar integration remains future work. |
| Development and local validation | Accepted gated Developer Console and DEBUG database-profile/lifecycle tools; exact supported Keychain behavior; repository-owned build/test/isolated Run and durable-startup gates. Disposable data does not authorize a reset. |
| UI direction | [R1 package](UI%20Assets/LF-UI-2026-09-R1/README.md) owns the approved written visual direction. Native implementation/acceptance, local draft SC documents and supporting PNGs have distinct status. |

## Parser reliability and exact source limits

[ADR-046](ADR.md#adr-046) governs all statement-dependent work. The accepted unnumbered reset, technically accepted 2026-09-09, recertified the complete registered corpus supplied through 2026-09-08: **127 authentic carriers, 103 logical statements**, across Axis bank, Axis card, HDFC bank, CBQ bank, CBQ card, American Express and Qatar Airways salary. It included 5,286 representation transaction rows, 3,165 canonical bank/card transactions and 258 salary components from 20 salary statements. Salary components are not bank transactions. The CBQ EML is container provenance; only its actual PDF attachment entered the PDF path, not a general email importer.

Ordinary prepare/validate/confirm, renamed replay, source ownership, In-Memory/SQLite parity, chronological/reverse/deterministic-mixed orders, checkpoint/close/reopen and canonical hydration passed against independently derived source truth. The [accepted reset record](Archive/Accepted%20outcomes/Unnumbered_2026-09.md#authentic-parser-reliability-reset) preserves exact results, artifact identities, corrections, failed/interrupted history and non-runs. Later accepted implementation evidence is linked below, not represented as a fresh corpus run here.

Certification is only for that exact registered corpus/profile boundary. Genuine zero-activity statements and absent source formats, including CBQ transaction-history XLS, remain **source-uncertified**. Historical CBQ minimum-due absence remains absent; current-write and historical-read rules are distinct. No generated statement or hand-built statement/domain/DTO substitute may fill a missing case. New recurring authentic statements extend the complete corpus unless the owner explicitly excludes or archives them; affected shared ingestion changes require the complete corpus of every affected family. See [source and verification invariants](Engineering%20Standards.md#authentic-source-and-oracle-invariants) and the [Harness acceptance policy](LedgerForge_Standing_Execution_Harness_Guide.md#parser--authentic-corpus-acceptance-policy).

## Material limits and adoption gates

- Support does not generalize by institution, format, similar layout or historical fixture acceptance. Original source truth and an independent architecture-aware projection outrank generated expected values and production output used as its own oracle.
- Broad repair/reversal/merge/split/unlink behavior remains family-specific unaccepted work under ADR-037. New provenance-less mixed overlap remains unsupported; historical V7 readback does not authorize arbitrary partial imports.
- Current holdings/valuation, qualified provider use, current market FX/net worth and verified user backup/restore remain required open outcomes. Complete export is optional; historical FX/performance and rejected platforms do not become prerequisites.
- Native currency, dates, financial effects, source order/multiplicity and provenance remain authoritative. No hidden FX, debit-equals-spending inference, missing-value-as-zero or inferred source identity is accepted.
- Sprint 88's physical resize was not separately completed; transient loading relied on preserved-source/focused tests, native selection needed owner assistance and a fresh independent Sol review was unavailable. These accepted limitations remain in its record. Earlier native/source limitations are preserved in their own records rather than silently counted as passes.

## Accepted evidence index

Order inherits [Guide rule F](Project_Guide.md#documentation-order). Collections are by cycle; inside each, known acceptance dates descend and undated records remain labelled. Dates of review or file publication are not acceptance dates.

| Collection | Latest dated evidence / purpose |
| --- | --- |
| [Sprints 80–89](Archive/Accepted%20outcomes/Sprints_80-89.md) | Sprint 88, 2026-09-11; Sprints 81–87, 2026-09-10; historical Sprint 80 discovery |
| [Unnumbered September 2026](Archive/Accepted%20outcomes/Unnumbered_2026-09.md) | 2026-09-09 startup/monthly planner, after authentic-parser reset |
| [Sprints 70–79](Archive/Accepted%20outcomes/Sprints_70-79.md) | Earlier acceptance and source/credential boundaries; acceptance dates not invented from review headings |
| [Sprints 60–69](Archive/Accepted%20outcomes/Sprints_60-69.md) | Earlier local validation, source/document, developer-tooling and historical fixture evidence |
| [Sprints 50–59](Archive/Accepted%20outcomes/Sprints_50-59.md) | Atomic import, dates/provenance, categories and source-snapshot foundations |
| [Existing implementation reports](Archive/Implementation%20Reports) and [historical roadmaps](Sprint%20roadmap/Archived) | Original historical bodies; their old planning status cannot authorize current work |
