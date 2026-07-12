# LedgerForge Project Guide

This is the canonical project operating manual. Read `Project documents/.github/Context_Manifest.yaml` first, then `AGENTS.md`, then this document. Use the Task Routing Guide to load only the documents required for the current task. Avoid loading unnecessary documentation.

## Current Project Snapshot

This document intentionally avoids duplicating volatile repository state.

The authoritative sources are:

- **Current ACTIVE Sprint:** `Project documents/Implementation.md`
- **Verified Repository State:** `Project documents/PROJECT_STATE.md`
- **Latest Implementation Report:** `Project documents/Codex response.md`

Project Baseline:

- **Workflow:** Workflow v2.1 (Frozen)
- **Architecture:** Architecture v1.0 (Frozen)
- **Development Model:** Documentation → Planning → Implementation → Validation → Handoff

## Current Architecture Status

| Component | Status/Notes |
|-----------|--------------|
| Product Vision | Current and authoritative |
| Architecture | Frozen v1.0 baseline active |
| ADRs | Current through ADR-026 |
| Database | Production-ready foundation |
| Repository Layer | Stable with contract tests |
| Persistence | SQLite repository layer active |
| Import Framework | Operational; CSV and PDF reader foundation active |
| Readers | CSV and PDF readers integrated into Unified Import Framework |
| Institution Detection | Framework implemented; legacy behaviour preserved |
| Statement Classification | Framework implemented; deterministic classification active |
| Parser Selection | Framework implemented; deterministic selector active |
| FinancialDocument | Immutable handoff model integrated after Statement Parser and before Validation |
| Password Management | Operational; DefaultPasswordProvider integrated |
| Workflow | Workflow v2.1 active. `Project documents/Implementation.md` is the current ACTIVE sprint implementation contract. |
| Dashboard | Deep Indigo UI foundation implemented. Repository-backed dashboard active. Continued refinement under M7. |
| Validation | Latest verified build and validation state is recorded in Project documents/PROJECT_STATE.md. |
| Documentation | `Project documents/.github/Context_Manifest.yaml` and `Project documents/Project_Guide.md` provide the canonical bootstrap and routing. |
| Import Pipeline | Production CSV routed through ImportCoordinator |
| Repository Contract Tests | Active for InMemory and SQLite providers |

## Canonical Import Pipeline

```text
ImportCoordinator
↓
PasswordProvider
↓
ReaderRegistry
↓
Reader (CSV/PDF)
↓
RawDocument
↓
Institution Detection
↓
Statement Classification
↓
Parser Selection
↓
Statement Parser
↓
FinancialDocument
↓
Validation
↓
Fingerprinting & Duplicate Detection
↓
Repositories
↓
SQLite
↓
RepositoryStoreHydrator
↓
Runtime Stores
↓
ViewModels
↓
Views
