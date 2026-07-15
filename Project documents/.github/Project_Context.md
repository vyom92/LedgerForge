# LedgerForge Project Context

> Purpose: Provide a concise bootstrap snapshot of the project for AI assistants and developers.
>
> This document is intentionally lightweight. Authoritative workflow, architecture, planning and repository state live in the canonical project documentation.

---

# Current State Routing

This document does not duplicate sprint numbers, priorities, build results or completed-work history.

- Verified implementation state and completed sprint history: `Project documents/PROJECT_STATE.md`
- ACTIVE sprint contract: `Project documents/Implementation.md` (ACTIVE section only)
- Unscheduled backlog and research: `Project documents/FUTURE_WORK.MD`
- Latest planning or implementation execution report: `Project documents/Codex response.md`

---

# Project Summary

LedgerForge is an offline-first macOS personal financial operating system.

It is designed to import financial documents from multiple institutions, extract validated financial data through a deterministic import pipeline, store trusted financial truth in a repository-backed database, and present that information through a modern SwiftUI interface. Current production import remains limited to the verified capability boundary below.

Artificial intelligence assists the user but never replaces deterministic financial truth.

---

# Current Architecture (Summary)

Approved production pipeline:

ImportCoordinator

↓

PasswordProvider

↓

ReaderRegistry

↓

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

Statement Parser

↓

FinancialDocument

↓

Validation

↓

User Review & Explicit Confirmation

↓

Fingerprinting & Duplicate Detection

↓

Repository Persistence Boundary

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

RepositoryStoreHydrator is the only approved persistence-to-runtime boundary.

---

# Capability Boundary

- Production import support is verified only for the approved Axis Bank NRE CSV layout.
- CSV is the production reader path. PDF text extraction, institution detection, statement classification and parser selection are implemented foundations, not production PDF statement support.
- The password-provider interface and locked-PDF reader contract exist, but the default provider supplies no credential and there is no production password-entry or Keychain workflow.
- XLS, XLSX, TXT and OCR remain planned.
- The parser registry contains the verified Axis bank-account parser used by the approved CSV fixture. Broader Axis layouts and account types, HDFC and CBQ remain planned.
- Parser-owned verified identifier extraction and deterministic confirmed-import account resolution are implemented for the approved Axis path. This does not establish complete arbitrary multi-account, multi-format or multi-institution support.
- Exact reader-text duplicate prevention and bounded parser-verified Axis UPI event-overlap blocking are production-integrated. Unsupported event families, cross-format identity, historical backfill and cross-process safety remain outside production support.

Consult `Project documents/PROJECT_STATE.md` for the complete verified implementation record and `Project documents/FUTURE_WORK.MD` for unscheduled work.

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
3. `Project documents/Project_Guide.md`
4. `Project documents/PROJECT_STATE.md`
5. `Project documents/Implementation.md` (ACTIVE sprint only)

Then use the Task Routing Guide in `Project documents/Project_Guide.md` to determine any additional documentation required.

For sprint planning, consult `Project documents/FUTURE_WORK.MD` after verified repository state and before task-relevant architecture, ADRs, product vision, standards and fixtures. Do not load the backlog for routine implementation when the ACTIVE sprint is already defined.

---

# Definition of Success

LedgerForge becomes the trusted personal financial operating system that allows users to import financial documents from multiple institutions, preserve financial truth through a deterministic validation pipeline, and present accurate, explainable financial insight through a repository-backed SwiftUI application.

Every sprint should reduce manual work, preserve architectural integrity, improve user confidence, and maintain a single source of truth across code and documentation.
