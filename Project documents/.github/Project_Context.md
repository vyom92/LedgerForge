# LedgerForge Project Context

> Purpose: Provide a concise snapshot of the project for AI agents and developers.
>
> Detailed workflow, architecture and engineering guidance live in the canonical project documentation.

---

# Current Phase

**Current Milestone**

Milestone M7 — Dashboard Experience

**Current Sprint**

Sprint 23 (Planning)

Current work is focused on:

- Workflow v2.1 freeze
- Documentation consolidation
- Repository housekeeping
- UI component extraction

---

# Project Summary

LedgerForge is an offline-first macOS personal financial operating system.

It imports financial documents from multiple institutions, extracts validated financial data through a deterministic import pipeline, stores trusted financial truth in a repository-backed database, and presents that information through a modern SwiftUI interface.

The approved UI/UX visual language is frozen and implementation now focuses on translating approved assets into production SwiftUI.

---

# Current Architecture (Summary)

The approved production pipeline is:

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

- Multi-format document import framework
- RawDocument pipeline
- Institution Detection
- Statement Classification
- Parser Selection
- FinancialDocument model
- Validation framework
- Repository architecture
- RepositoryStoreHydrator
- Runtime Stores
- Dashboard foundation
- Application shell
- Sprint 22 SwiftUI UI Foundation
- Approved UI/UX asset freeze
- Workflow v2.1

---

# Current Priorities

1. Complete Workflow v2.1 repository freeze.
2. Sprint 23 — UI Component Extraction.
3. Expand regression fixtures.
4. Password-protected document support.
5. PDF import.
6. Insights & Analytics.

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

Every implementation begins with:

1. `Project_Guide.md`
2. `PROJECT_STATE.md`
3. `Implementation.md`

Use the Task Routing Guide in `Project_Guide.md` to determine any additional documents required for the current task.

---

# Definition of Success

LedgerForge becomes the trusted personal financial operating system that allows users to import financial documents from multiple institutions, preserve financial truth through a deterministic validation pipeline, and present accurate, explainable financial insight through a repository-backed SwiftUI application.

Every future sprint should reduce manual work, preserve architectural integrity and improve user confidence without compromising financial accuracy.
