# LedgerForge Project Guide

This is the concise human-readable map for the LedgerForge repository. Begin with the repository-root `AGENTS.md`; it is the sole mandatory bootstrap entry point. This guide routes readers to subject authorities without duplicating their complete rules.

## Repository map

| Area | Purpose |
|---|---|
| `Project documents/PROJECT_STATE.md` | Verified current repository state |
| `Project documents/FUTURE_WORK.MD` | Canonical unscheduled queue |
| `Project documents/ADR.md` | Accepted architectural decisions |
| `Project documents/Architecture_v1.0_Frozen.md` | Frozen system architecture and compatibility boundary |
| `Project documents/Database_v1_Architecture.md` | Database design and migration alignment |
| `Project documents/Product Vision.md` | Product direction |
| `Project documents/UI_UX_v1.0_Frozen.md` | Frozen UI/UX and approved visual boundary |
| `Project documents/Engineering Standards.md` | Engineering, privacy, fixture and verification policy |
| `Project documents/BUILD_AND_PROJECT_CONVENTIONS.md` | Xcode, build and repository mechanics |

## Subject authority

| Question | Authority |
|---|---|
| What is verified now? | Repository evidence and `PROJECT_STATE.md` |
| What may be executed now? | The complete Chat-approved prompt in the current conversation |
| What remains unscheduled? | `FUTURE_WORK.MD` |
| What architecture is permitted? | Accepted ADRs and frozen Architecture |
| What is product direction? | Product Vision |
| What is database design? | Database Architecture and verified migrations |
| What UI is approved? | Frozen UI/UX and approved assets |
| What engineering and verification rules apply? | `AGENTS.md`, this guide, Engineering Standards and Build Conventions |

## Current import pipeline

```text
ImportCoordinator → PasswordProvider → ReaderRegistry → Reader → RawDocument
→ Institution Detection → Statement Classification → Parser Selection
→ Statement Parser → FinancialDocument → Validation
→ Fingerprinting & Duplicate Detection → Repository Persistence Boundary
→ Repositories → SQLite → RepositoryStoreHydrator → Runtime Stores
→ ViewModels → Views
```

Validation precedes persistence. RepositoryStoreHydrator is the only persistence-to-runtime boundary. The production support boundary is recorded in `PROJECT_STATE.md`.

## Task routing

| Task | Read next |
|---|---|
| Planning or backlog review | `PROJECT_STATE.md`, `FUTURE_WORK.MD`, then relevant Product Vision, Architecture, ADRs, standards and fixtures |
| Swift implementation | `PROJECT_STATE.md`, then relevant Architecture, ADRs, standards, source and tests named by the prompt |
| Database work | Database Architecture, ADRs, migrations and Engineering Standards |
| Import/parser work | Architecture, ADRs, Engineering Standards and approved fixtures |
| UI work | Frozen UI/UX, Architecture, approved assets and Engineering Standards |
| Documentation alignment | This guide, affected subject authorities and the complete prompt |

Use only the documents required by the task. Do not invent a sprint, architecture decision, production-support claim or fixture baseline.

## Roles and lifecycle

Chat selects and scopes work. Work performs read-only discovery and reports directly in chat. Codex performs authorised edits, validation, documentation execution and Git operations, then reports directly in chat. The user may also edit files; legitimate work is preserved and reconciled.

The lifecycle is:

```text
Verified state + queue → optional read-only discovery → complete Chat prompt
→ full-repository reconciliation → edit/build/test/validate
→ authorised durable documentation → commit all legitimate work
→ push all local commits → verify clean main == origin/main → direct report
```

There is no repository-stored active work contract. The direct Chat-approved prompt is the sole execution contract.

## Reference fixtures

Approved sanitized fixtures and their expected financial truth define production claims. A reader, parser, protocol or fixture alone does not establish support. Private statements, credentials and unrestricted source evidence never enter Git.

## Documentation-only cycles

Documentation-only work may skip full tests when executable, source, tests, schemas, migrations, fixtures, build settings and assets are unchanged. Project metadata changes require project-integrity validation and a clean Debug build. All cycles require complete diff, privacy, reference, conflict-marker and Git checks.
