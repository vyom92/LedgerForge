//
//  PROJECT.md
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//


# LedgerForge

This file provides a very high-level overview of the project.

The authoritative project documentation is located under `Project documents/`.

## Start Here

Every developer and AI assistant must begin with:

1. `Project documents/Project_Guide.md`
2. `Project documents/Codex response.md`

`Project_Guide.md` determines which additional documentation is required for a given task.

## Project Summary

LedgerForge is an offline-first macOS personal finance application designed around a layered, protocol-oriented architecture.

Core principles:

- Offline First
- Privacy First
- Validation Before Persistence
- Repository-Only Persistence
- Deterministic Financial Behaviour
- Small, Production-Quality Sprints

## Repository Layout

- `Project documents/` — Architecture, ADRs, workflow and project documentation.
- `Database/` — Persistence layer.
- `Import/` — Unified import framework.
- `Models/` — Domain models.
- `Core/` — Runtime stores.
- `Views/` and `ViewModels/` — User interface.
- `Services/` — Shared services and legacy components during migration.
- `LedgerForgeTests/` — Unit and contract tests.

For implementation guidance, architecture decisions and sprint workflow, always refer to `Project documents/Project_Guide.md` rather than duplicating documentation here.
