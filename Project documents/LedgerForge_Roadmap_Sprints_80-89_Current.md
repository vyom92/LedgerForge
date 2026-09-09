# LedgerForge Roadmap: Sprints 80–89

**Status:** Current repository cycle roadmap
**Refreshed:** 2026-09-09
**Supersedes:** `Project documents/LedgerForge_Roadmap_Sprints_70-79_Current.md` as the current-cycle authority; that file remains historical prior-cycle record

## Control

- **Planning authority:** This file is the repository authority for Sprint 80 and any later 80–89 numbering, corrective suffixes, cycle status and next gates.
- **Execution authority:** None. A complete Chat-approved prompt authorizes each task.
- **Accepted production baseline:** Sprint 79 remains the highest-numbered accepted implementation. The unnumbered Authentic-Corpus Parser / Import Reliability Reset and startup reliability/monthly-planner package are technically accepted and published; current pushed `main` is `d8124ef5a1f38a1e7547f4f8905c91f25b2f1194`, V17 remains current, and the later obsolete-plugin-artifact cleanup changed no product behavior.
- **Latest accepted numbered sprint:** Sprint 79 — Qatar Airways Salary Domain and Current-Month Funding Planner.
- **Latest accepted discovery outcome:** Sprint 80 — Swift 6 and macOS readiness closure, `SWIFT6_READINESS_COMPLETE`.
- **Current migration baseline:** additive V17 accepted with the unnumbered reliability reset; V1–V16 remain immutable.
- **Latest accepted ADR:** ADR-046 — Authentic-Corpus-Only Parser Authority and Adaptive Financial Source Interpretation, accepted by explicit user decision; ADR-045 remains the historical Sprint 79 architecture baseline.
- **Completed campaign:** the unnumbered P0 Authentic-Corpus Parser / Import Reliability Reset was technically accepted by Chat on 2026-09-09. No sprint number or corrective suffix is assigned.
- **Standing method:** `LedgerForge_Standing_Execution_Harness_Guide.md`.
- **Personal-v1 adoption:** undeclared; certification remains a later gate.

Repository/source evidence overrides stale wording in this roadmap. Explicit
user decisions remain binding until superseded. Do not treat active WIP as
accepted production support.

## Accepted unnumbered startup reliability and monthly planner package

Chat accepted the complete reviewed 35-path candidate, including the non-negative-transfer-fee correction, on 2026-09-09. The accepted startup, diagnostics, planner, recurrence-prevention and validation boundaries are recorded in [PROJECT_STATE.md](PROJECT_STATE.md). The final canonical TestPlan passed 465 definitions / 75 suites / 523 expanded executions, with zero failures/skips/expected failures; the earlier parser reset retains its separate historical result below. V17 definitions and financial formulas remain unchanged.

Implementation review is closed for that exact candidate. Publication completed at implementation/package commit `6455f662dd0ea8896d19af3e67be51546badb3ae`; the later user-authorized obsolete-plugin-artifact cleanup advanced `main` to `d8124ef5a1f38a1e7547f4f8905c91f25b2f1194` without changing the accepted product boundary. This package allocates no sprint number or corrective suffix, introduces no migration or architecture decision, and does not complete PR-1, the Unified Import Centre, Swift-6 migration or personal-v1 adoption.

## Accepted unnumbered parser reliability reset

Chat technically accepted the complete cross-institution repair and authentic-corpus recertification on 2026-09-09. Publication is recorded separately by Git history. The strengthened user rule continues to prohibit creating or using synthetic, reconstructed, sanitized, reduced, mutated or hand-authored financial statements at any stage. Only authentic corpus carriers and exact operational copies/actual attachments may exercise statement-dependent behavior; absent real cases remain uncertified.

The accepted implementation retains the authoritative complete TestPlan result from 2026-09-08: 443 tests in 72 suites, 500 parameter-expanded executions, zero failures/skips and zero Swift source diagnostics. All seven complete-family gates and the 127-carrier global gate passed in both providers and all three orders, covering 103 logical statements, 3,165 canonical bank/card transactions and 258 separate salary components, including matching semantic digests, final source-byte integrity and mandatory report export. Authentic populated V16-schema migration, genuine historical-production CBQ V16 upgrade, exact durable/hydrated-value preservation, Debug/Release builds and independent review also passed. Historical CBQ minimum-due absence remains preserved without invented backfill; current CBQ imports enforce the authentic minimum-due contract. The Axis zero-activity producer/validation/hydration findings are repaired, while genuine zero-activity source certification remains unavailable because the corpus contains no such statement. Additive V17 is the current accepted migration and V1–V16 remain immutable. Native authentic preparation, preview, cancellation and account-choice gating are verified; manual final confirmation clicking remains unverified but is explicitly nonblocking. No sprint number, personal-v1 adoption, new multi-file UI or batch-wide atomicity is inferred.

The CBQ email envelope is certification provenance only, not a new email-import feature. A serial acceptance queue exercises ordinary statement intake without claiming that the future Unified Import Centre UI/queue has been implemented. The accepted implementation boundary is recorded once in [PROJECT_STATE.md](PROJECT_STATE.md).

Chat exercised final technical acceptance for this exact unnumbered campaign. Publication remains a separate Git action under Chat authority. Future sprint attribution and publication authority remain with Chat. This campaign does not allocate Sprint 81 or a corrective suffix.

## Authority and anti-drift gate

Before selecting, naming, prompting, reviewing or accepting a sprint:

1. exact current ref/worktree;
2. this roadmap;
3. standing execution harness;
4. `PROJECT_STATE.md`;
5. `FUTURE_WORK.MD`;
6. relevant accepted ADRs;
7. production code/tests where documents are insufficient; and
8. local/private source evidence where required.

Classify material claims as verified, explicit user decision, reported only or
inference.

### Corrective numbering

- `NA` = first bounded correction attributable to Sprint `N`;
- `NB` = another separately bounded correction attributable to Sprint `N`;
- later numbered sprints do not move;
- a blocker inside `NB` does not create `NC`;
- `NC` is justified only if `NB` itself ultimately fails the Sprint `N`
  outcome; and
- unrelated P0 defects are not disguised as corrections to the preceding
  sprint.

## Cycle overview

| Sprint | Outcome | Current status |
|---|---|---|
| 80 | Swift 6 and macOS readiness closure | **Accepted / discovery complete** |

No ordinary Sprint 81–89 feature sequence is assigned by this documentation
sync. Future work remains in `FUTURE_WORK.MD` until Chat selects a bounded
outcome and supplies a complete execution prompt.

## Recorded planning inputs / candidate readiness

This table is a view of the canonical `FUTURE_WORK.MD` queue. It is **not** sprint allocation, priority promotion or implementation authorization. Before any roadmap assignment, included work must already have a durable queue/authority trace.

| Canonical queue ID | Outcome | Current status | Dependency | Personal-v1 relevance | Notes / unresolved decision |
|---|---|---|---|---|---|
| `FW-P2-72` | PR-1 staging/publication ownership seam | Candidate | Sprint 80 readiness; current store/hydrator contracts | Required sequencing prerequisite | Swift-5 ownership correction; no parallel-preparation or Swift-6 switch |
| `FW-P1-19` | Serial LedgerForge Import Centre | Candidate | PR-1; existing confirmation-gated Import Wizard | High | Single file = queue length one; future multi-file uses same intake/review/result model |
| `FW-P1-20` | Batch-import boundary | Blocked | Duplicate handling, cancellation, failure isolation, PR-1 | High | Serial-first boundary retained; bounded parallel preparation remains unresolved |
| `FW-P2-03` | Transactions filtering/search | Ready for planning | Stable transaction fields | Medium/high usability proof | R1-approved direction; screenshot colour observation remains an evidence gap, not a verified defect |
| `FW-P2-53` | Contextual filtering/sorting/table controls | Ready for planning | Stable date semantics/searchable domains | Medium/high usability proof | Currency-safe sorting, resizable columns, collapsible inspector; source order never rewritten |
| `FW-P2-52` | User/appearance preferences | Ready for discovery | Existing settings + `WorkspaceSettings` direction | Medium | R1 visual direction approved; preference storage/ownership unresolved |
| `FW-P2-55` | Adaptive appearance design direction | Idea | Approved design review/spec/assets | Medium | R1 approves System/Light/Dark + optional Indigo, but design approval does not select implementation |
| `FW-P2-77` | Source-tree/documentation organization discovery | Ready for discovery | None | Maintenance, not an adoption gate | Discovery required before moves; no target folder tree is accepted architecture |
| `FW-P3-36` | Verified backup/restore/disaster recovery | Ready for discovery | User-facing backup/restore contract | Serious adoption-gate candidate | Must be considered explicitly before personal-v1 certification; no priority promotion implied |

`LF-UI-2026-09-R1` is approved design authority once this documentation sync is published. UI design approval does not select a sprint; future UI implementation must be selected from the canonical queue. **Transactions is Designer-1's strongest representative proof surface recommendation, but this is a planning input, not Sprint 81 selection.** Appearance storage architecture remains unresolved, and repository organization requires discovery before any physical moves.

No Sprint 81–89 feature assignment follows from this matrix.

## Sprint 80 — Swift 6 and macOS readiness closure

### Status

**Accepted / discovery complete on 2026-08-28.** Sprint 80 is an accepted
technical-evidence outcome, not a production implementation.

### Accepted result

The compiler was reached with Xcode 26.6 (build 17F113), Apple Swift 6.3.3 and
the macOS 26.5 SDK. All current native targets remain Swift 5. The current app
configuration enables approachable concurrency, default MainActor isolation and
member-import visibility, with no explicit project `SWIFT_STRICT_CONCURRENCY`
setting. Strict readiness is materially non-clean and is no longer an
infrastructure-only unknown. Cluster-level diagnostics, the 45-location unit-
test probe, the zero-source-error/zero-source-warning UI-test probe and the
macOS metadata findings are recorded in `PROJECT_STATE.md`; raw compiler-log
noise is not governance evidence.

The accepted strategy is to make behavior-preserving ownership corrections
under Swift 5, implement the first Unified Import Centre serially with explicit
ownership, defer bounded parallel preparation until transferable ownership and
dependency thread-safety are proven, then complete the remaining prerequisite
families and perform a coordinated Swift-6 migration. Swift 6 is not required
before the serial Import Centre, but it is required before personal-v1
certification.

The four bounded prerequisite families are separately recorded as `FW-P2-72`
(PR-1 staging/publication ownership seam), `FW-P2-73` (PR-2
SQLite/provider/migration ownership), `FW-P2-74` (PR-3 dependency boundary) and
`FW-P2-75` (TEST-PR unit-test strict-concurrency correction). The coordinated
migration gate is `FW-P2-76`. None is complete or authorized by Sprint 80.

The current product artifact is macOS-native, uses the macOS 26.5 SDK, App
Sandbox and selected-file import. Stale platform/bundle metadata and the
remaining minimum-version, entitlement, capability, hardened-runtime,
distribution and UI-test policy decisions remain future work under `FW-P2-70`.

The accepted `cbq.credit-card.pdf@1` July-2026 `malformedPreamble` defect was
`PRE_EXISTING_OR_EXTERNAL` relative to Sprint 79. Sprint 80 did not repair or
investigate its source grammar. The later accepted unnumbered reset corrected
the exact registered CBQ boundary while preserving historical minimum-due
absence and enforcing the current authentic minimum-due contract. Personal-v1
adoption remains a separate later gate.

## Post-Sprint-80 dependency ordering

The accepted immediate ordering is:

1. Sprint 80 documentation sync and the unnumbered authentic-parser reset / CBQ corrective closure are complete;
2. PR-1 ownership seam (`FW-P2-72`);
3. serial Unified Import Centre (`FW-P1-19`, with `FW-P1-20` batch-import
   boundaries);
4. PR-2 / PR-3 / TEST-PR (`FW-P2-73`, `FW-P2-74`, `FW-P2-75`);
5. coordinated Swift-6 migration (`FW-P2-76`); and
6. personal-v1 certification remains later.

Parallel preparation is an open architecture decision and is not approved.

## Maintenance

When this roadmap changes:

- preserve accepted sprint numbering and prior-cycle history;
- distinguish accepted state from active WIP;
- record corrective suffixes explicitly;
- remove superseded source assumptions instead of leaving contradictory live
  claims;
- link detailed implementation truth to `PROJECT_STATE.md` and ADRs;
- keep private source filenames, credentials and transaction listings out of
  roadmap content; and
- reconcile this file at every sprint or corrective acceptance.
