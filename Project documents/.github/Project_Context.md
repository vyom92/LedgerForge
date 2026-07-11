# LedgerForge Project Context

> Purpose: Provide a concise bootstrap snapshot of the project for AI assistants and developers.
>
> This document is intentionally lightweight. Authoritative workflow, architecture, planning and repository state live in the canonical project documentation.

---

# Current Phase

**Current Milestone**

Milestone M7 — Dashboard Experience

**Current Sprint**

Sprint 26 — Documentation Alignment & Bootstrap Manifest Adoption

**Current Focus**

- Documentation baseline freeze
- Bootstrap alignment
- Workflow v2.1 consolidation
- Repository documentation consistency

For verified implementation status, always refer to:

- `Project documents/PROJECT_STATE.md`

For the ACTIVE sprint plan, always refer to:

- `Project documents/Implementation.md`

---

# Project Summary

LedgerForge is an offline-first macOS personal financial operating system.

It imports financial documents from multiple institutions, extracts validated financial data through a deterministic import pipeline, stores trusted financial truth in a repository-backed database, and presents that information through a modern SwiftUI interface.

Artificial intelligence assists the user but never replaces deterministic financial truth.

---

# Current Architecture (Summary)

Approved production pipeline:

Reader

↓

RawDocument

↓

Institution Detection

↓

Statement Classification

↓

Parser Selection

↓

FinancialDocument

↓

Validation

↓

Fingerprinting & Duplicate Detection

↓

Repository Persistence

↓

RepositoryStoreHydrator

↓

Runtime Stores

↓

ViewModels

↓

Views

RepositoryStoreHydrator is the only approved persistence-to-runtime boundary.

---

# Completed Milestones

- Multi-format import foundation
- RawDocument pipeline
- Institution Detection
- Statement Classification
- Parser Selection
- FinancialDocument model
- Validation framework
- Repository architecture
- SQLite persistence
- RepositoryStoreHydrator
- Runtime Stores
- Dashboard foundation
- Application shell
- SwiftUI UI foundation
- Approved UI/UX baseline
- Workflow v2.1
- Sprint 25 repository identity and import foundation

---

# Current Priorities

1. Complete Sprint 26 documentation alignment.
2. Freeze bootstrap documentation.
3. Prepare Sprint 27.
4. Password-protected document support.
5. PDF import.
6. Statement Intelligence foundation.

---

# Design Authority

Master UI reference:

`Project documents/UI Assets/Approved/DesignBoard_v2.0.png`

Approved screen assets:

`Project documents/UI Assets/Approved/`

App icon:

`Project documents/UI Assets/Approved/AppIcon_v1.0.png`

---

# Canonical Documentation

Bootstrap every session using:

1. `Project documents/.github/Context_Manifest.yaml`
2. `AGENTS.md`
3. `Project_Guide.md`
4. `Project documents/PROJECT_STATE.md`
5. `Project documents/Implementation.md` (ACTIVE sprint only)

Then use the Task Routing Guide in `Project_Guide.md` to determine any additional documentation required.

---

# Definition of Success

LedgerForge becomes the trusted personal financial operating system that allows users to import financial documents from multiple institutions, preserve financial truth through a deterministic validation pipeline, and present accurate, explainable financial insight through a repository-backed SwiftUI application.

Every sprint should reduce manual work, preserve architectural integrity, improve user confidence, and maintain a single source of truth across code and documentation.
