# LedgerForge agent bootstrap

LedgerForge is a private, personal, single-user, offline-first Swift/SwiftUI macOS app for the owner's MacBook. Its purpose is to replace the Budget Analysis sheet with truthful unified bank, card and investment data for personal use. Do not overengineer it or invent public/commercial workflows. Clarify unresolved owner choices; do not infer approval. <!-- user-specified -->

## Mandatory bootstrap

1. Read this file and the complete current Chat-approved prompt.
2. Establish the exact ref and local worktree state mechanically; preserve unexplained work.
3. Use the [Project Guide task index](Project%20documents/Project_Guide.md#pg-01) to select the relevant playbook and sections. Do not load the whole folder for ordinary tasks.
4. Read [current state](Project%20documents/PROJECT_STATE.md) for accepted product facts and active WIP. Read scope/queue only for relevant planning or findings; inspect code/tests/local evidence where documents are insufficient.
5. Before source/import/duplicate-support work, read [ADR-046](Project%20documents/ADR.md#adr-046), [authentic-source invariants](Project%20documents/Engineering%20Standards.md#authentic-source-and-oracle-invariants) and the [Harness corpus policy](Project%20documents/LedgerForge_Standing_Execution_Harness_Guide.md#parser--authentic-corpus-acceptance-policy). Before architecture, persistence, identity or credentials, read the relevant accepted ADRs.

## Private personal app scope gate

Check [SCOPE_DECISIONS](Project%20documents/SCOPE_DECISIONS.md) before new scope proposals. Any one concrete personal workflow, real correctness/persistence/privacy/recovery need, authentic selected source, or day-to-day convenience/appearance improvement establishes relevance. A convenience idea need not solve a financial safety problem. Record useful ideas, features, defects and maintenance distinctly as owner requests, verified findings, reported problems or proposals. <!-- user-specified -->

**Capture ≠ approval ≠ readiness ≠ scheduling ≠ execution.** Record eligible work in the [queue](Project%20documents/FUTURE_WORK.MD) or its subject authority. Preserve meaningful rejection reasons in SCOPE_DECISIONS. Rejected work is **NOT REQUIRED-DO NOT CONSIDER**, cannot block retained work and can reopen only through a new explicit owner decision naming the real need. Parked ideas retain their recorded revisit condition. Do not create research packets for already rejected categories. <!-- user-specified -->

## Critical financial and source rules

Priority: financial correctness → durable persistence → deterministic behavior → explicit control → privacy → recoverability → explainability → maintainability → speed. Preserve exact native Money/currency/scale, date meaning, direction/liability effect, source order, multiplicity, identifiers and provenance. Independent source oracles outrank production-derived expectations; financial ambiguity fails closed with zero accepted durable residue. Verify provider parity, migration integrity, canonical hydration and relaunch where the boundary requires them.

Only authentic originals in `/Users/vyom/Documents/Ledger Forge` are financial statement inputs. No synthetic, generated, sanitized, reconstructed, representative, reduced, mutated or hand-authored statements or statement/domain/DTO substitutes may be created or used at any stage. The owner's current processing rule allows in-memory processing only and prohibits derivative statement files and derived financial evidence files on disk; the normal app database remains permitted; see the exact [scope decision](Project%20documents/SCOPE_DECISIONS.md#source-processing-decision). Nonfinancial source-independent mechanics remain permitted. Missing authentic cases stay uncertified. <!-- user-specified -->

Keep private originals, credentials and financial source content out of Git. Legitimate local/ChatGPT inspection is permitted within the task; do not add blanket local-inspection bans. Accepted ordinary app diagnostic/password protections remain. Data being disposable does not authorize deleting a database or changing migration history. <!-- user-specified -->

## Execution and Git safety

The complete approved prompt authorizes execution; roadmaps and proposals do not. Chat owns scope/architecture decisions and final technical acceptance. Codex needs self-contained instructions; MCP executor/admin are Chat tooling, not required Codex tooling. Use the selected local execution environment and obey the prompt's tool restrictions.

One writer in the primary worktree by default. Before writes, inspect exact HEAD/branch/remote relationship, staged/unstaged/untracked files, worktrees/branches/stashes, Git operations, active writers/leases and validations. Never reset, restore, clean, stash, prune, overwrite or delete unexplained work. MCP leases do not fence an external writer. Stop on overlapping ownership, unexplained divergence, source/architecture conflict, failed required proof, private Git leakage or scope expansion. Follow [Harness execution and publication](Project%20documents/LedgerForge_Standing_Execution_Harness_Guide.md#one-writer-and-publication); stage exact authorized paths only.

## Subject routing

| Task boundary | Read the selected sections |
| --- | --- |
| Execution/review, writer coordination, validation and reporting | [Standing Harness](Project%20documents/LedgerForge_Standing_Execution_Harness_Guide.md) |
| Xcode, local build/test/Run commands and resources | [Build conventions](Project%20documents/BUILD_AND_PROJECT_CONVENTIONS.md) and [script guide](script/README.md) |
| Financial, Money, source, identity, persistence and recovery invariants | [Engineering Standards](Project%20documents/Engineering%20Standards.md) |
| Cross-layer or database boundaries | [Architecture](Project%20documents/Architecture_v1.0_Frozen.md), [Database](Project%20documents/Database_v1_Architecture.md), relevant [ADRs](Project%20documents/ADR.md) |
| UI changes and canonical/draft distinction | [UI routing](Project%20documents/UI_UX_v1.0_Frozen.md), [R1 package](Project%20documents/UI%20Assets/LF-UI-2026-09-R1/README.md) |

Do not infer current support, migration or sprint acceptance from memory, old reports or a green suite outside its exercised oracle. Reports distinguish verified, reported only, contradicted and missing evidence. Keep current facts in PROJECT_STATE, accepted architecture in ADR, decisions in SCOPE_DECISIONS, open work in FUTURE_WORK and history in linked outcome collections. Update this bootstrap, Guide and Harness together only when reusable routing/ownership changes.
