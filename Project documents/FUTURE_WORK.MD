# LedgerForge Future Work

## Purpose

This document stores unscheduled ideas, enhancements and future feature candidates.

Completed work belongs in PROJECT_STATE.md.

Architecture decisions belong in ADR.md.

Only the ACTIVE sprint belongs in Implementation.md.

---

## Backlog

### High Priority

#### Identity

- [ ] Production import integration using the Financial Identity Foundation
- [ ] Automatic account reuse during imports
- [ ] Identity conflict handling workflow
- [ ] Manual identity conflict resolution
- [ ] Duplicate account review tools

#### Developer Tools

- [ ] Fix Reset Development Database persistence across application restart
- [ ] Granular database reset
- [ ] Reset transactions only
- [ ] Reset import sessions
- [ ] Reset financial identity
- [ ] Reset repository
- [ ] Factory reset
- [ ] Better developer diagnostics

---

### Medium Priority

#### Transactions

- [ ] Multi-selection
- [ ] Bulk action toolbar
- [ ] Delete selected transactions
- [ ] Delete import session
- [ ] Undo support

#### Accounts

- [ ] Friendly account naming
  - Axis NRE
  - Axis NRO
  - Axis Savings
  - CBQ Current
- [ ] Manual account merge
- [ ] Archive account
- [ ] Account notes

#### User Experience

- [ ] Better account icons
- [ ] Saved transaction filters
- [ ] Dashboard customization
- [ ] Improved search experience

---

### Low Priority

#### Identity

- [ ] Identifier confidence scoring
- [ ] Alias support

#### Analytics

Future analytics work will be added after the Financial Identity platform and import pipeline are fully complete.

---

### Research / Ideas

Ideas that may become future architecture work but are not currently approved for implementation.

---

## Workflow

- This document is the permanent repository backlog.
- Items here are approved ideas but are **not** scheduled work.
- Desktop ChatGPT decides when an item becomes an ACTIVE sprint.
- When an item becomes part of `Implementation.md`, remove it from this document.
- Completed work belongs in `PROJECT_STATE.md`.
- Architecture decisions belong in `ADR.md`.
- Temporary planning and execution reports belong in `Codex response.md`.

---

## Verification

When updating this document:

- Only add or remove backlog items.
- Do not record implementation progress here.
- Do not record completed sprint history here.
- Do not convert backlog items into ACTIVE sprint plans.
- Keep this document implementation-agnostic.

