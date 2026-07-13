# LedgerForge Future Work

## Purpose

This document stores unscheduled ideas, enhancements, maintenance work and future feature candidates for LedgerForge.

Completed work belongs in `PROJECT_STATE.md`.

Architecture decisions belong in `ADR.md`.

Only the ACTIVE sprint belongs in `Implementation.md`.

Items already promoted into the ACTIVE sprint must not remain in this backlog.

---

## Backlog

### High Priority

#### Accounts & Financial Identity

- [ ] Broader account metadata editing beyond display names while preserving immutable identity and financial relationships
- [ ] Identity conflict handling workflow
- [ ] Manual identity conflict resolution
- [ ] Explain why an imported statement matched, failed to match or conflicted
- [ ] Manual account linking and unlinking with explicit confirmation
- [ ] Identifier backfill policy for adding newly discovered verified identifiers to an already resolved account
- [ ] Duplicate-account review tools
- [ ] Manual account merge with preview, validation and rollback protection
- [ ] Account split or incorrect-link recovery workflow

#### Persistence & Import Integrity

- [ ] Cross-repository atomic persistence for workspace, account, identifier, import-session and transaction writes
- [ ] Recovery and cleanup for partial or interrupted imports
- [ ] Targeted repository metadata mutations for fields other than display name, preserving identifiers, sessions and transactions
- [ ] Concurrent-import guarantees and deterministic serialization of identity resolution and identifier attachment
- [ ] Import failure recovery that reconciles repository state and runtime state
- [ ] Durable import audit trail with validation issues, failure outcomes and source-provenance inspection
- [ ] Data-integrity verification and repair tools

#### Import Formats & Parser Coverage

- [ ] Production PDF statement support
- [ ] Password-protected PDF support
- [ ] Secure institution-specific password storage using macOS Keychain
- [ ] Per-file password override and password-entry workflow
- [ ] XLS support
- [ ] XLSX support
- [ ] TXT statement support
- [ ] OCR fallback for scanned or image-only statements
- [ ] Cross-format financial equivalence for statements available in CSV and PDF
- [ ] Parser framework expansion for additional document layouts and institutions
- [ ] Axis Bank parser family expansion
  - NRE account variants
  - NRO account variants
  - Savings and current-account variants
  - Credit-card statements
  - Historical and changed layouts
- [ ] HDFC parser family
- [ ] CBQ parser family
  - Bank accounts
  - Credit cards
  - Investment or mutual-fund statements
- [ ] Additional credit-card parser families
- [ ] Brokerage, mutual-fund, salary-slip and tax-document parser families

#### Developer Tools

- [ ] Fix Reset Development Database persistence across application restart
- [ ] Granular database reset
- [ ] Reset transactions only
- [ ] Reset import sessions only
- [ ] Reset financial identity only
- [ ] Reset repository financial data
- [ ] Factory reset
- [ ] Repository inspector
- [ ] SQLite browser for development builds
- [ ] Import-session inspector
- [ ] Parser and source-evidence inspector with privacy-safe redaction
- [ ] Duplicate and identity-conflict inspector
- [ ] Diagnostic export
- [ ] Better developer diagnostics and failure summaries

---

### Medium Priority

#### Account Lifecycle & Presentation

- [ ] Account notes
- [ ] Account colour or icon customization
- [ ] Institution logos
- [ ] Archive and restore account
- [ ] Hide account without deleting financial history
- [ ] Close-account status and closure date
- [ ] Account ordering and favourites
- [ ] Full account transaction-history navigation, filtering and analysis

#### Import Workflow

- [ ] Batch import
- [ ] Multi-file drag-and-drop import center
- [ ] Editable import preview
- [ ] Import correction workflow before persistence
- [ ] Account-match review and optional manual override
- [ ] Duplicate-import review and management UI
- [ ] Global import-session history and management, including failed and account-unassociated sessions
- [ ] Delete or reverse an import session safely
- [ ] Import progress, cancellation and retry workflow
- [ ] Better validation guidance and actionable fix suggestions
- [ ] Full automated coverage for explicit cancellation paths

#### Transactions

- [ ] Multi-selection
- [ ] Bulk action toolbar
- [ ] Delete selected transactions
- [ ] Delete transactions by import session
- [ ] Undo support
- [ ] Transaction notes
- [ ] Improved transaction-detail layout
- [ ] Transaction source and provenance view
- [ ] Saved transaction filters
- [ ] Advanced transaction search
- [ ] Transfer matching between owned accounts
- [ ] Reconciliation workflow
- [ ] Duplicate-transaction review

#### Categories, Rules & Automation

- [ ] Category model and category management
- [ ] Deterministic categorization rules
- [ ] Automatic transaction classification
- [ ] Explainable rule results
- [ ] Rule priority and conflict handling
- [ ] User corrections that can become reusable rules
- [ ] Merchant and payee normalization
- [ ] Recurring transaction detection
- [ ] Smart alerts based on deterministic financial rules

#### User Experience

- [ ] Replace developer terminology in user-facing screens
- [ ] Consistent toolbar composition across major screens
- [ ] Remove noisy `Pending` and `Soon` placeholders from everyday views
- [ ] Better account icons
- [ ] Dashboard customization
- [ ] Improved global search experience
- [ ] Interactive dashboard charts
- [ ] Better empty states and import guidance
- [ ] Hover, spacing and visual polish
- [ ] Accessibility review
- [ ] Keyboard navigation and shortcuts
- [ ] Performance and import-speed optimization

#### Engineering Quality

- [ ] Failure-injection tests for persistence and runtime-store gating
- [ ] Regression matrix across institutions, layouts and file formats
- [ ] Direct automated tests for cancellation handlers
- [ ] Cross-format fixture parity tests
- [ ] Long-running import and large-statement performance tests
- [ ] Repository corruption and recovery tests
- [ ] Privacy tests preventing raw identifiers, passwords and source fragments from entering diagnostics

---

### Low Priority

#### Identity Enhancements

- [ ] Identifier confidence scoring for non-authoritative evidence
- [ ] Identifier aliases and alternate institution-issued identifiers
- [ ] User-visible identity history
- [ ] Administrative identifier correction tools
- [ ] Identity provenance timeline

#### Analytics, Budgets & Reports

- [ ] Spending analytics
- [ ] Spending timeline
- [ ] Monthly and yearly trends
- [ ] Category breakdowns
- [ ] Budgets
- [ ] Financial goals
- [ ] Forecasting
- [ ] Smart alerts
- [ ] Custom reports
- [ ] Tax views
- [ ] CSV export
- [ ] Report export
- [ ] Net-worth history

#### Investments & Wealth

- [ ] Mutual-fund holdings
- [ ] ETF holdings
- [ ] Stock holdings
- [ ] Brokerage account support, including IBKR
- [ ] Folio and broker identifier support
- [ ] Portfolio timeline
- [ ] Portfolio performance
- [ ] Asset allocation
- [ ] Net-worth integration
- [ ] Optional market-data refresh while preserving offline-first operation

#### Multi-Currency & Ecosystem

- [ ] Multi-currency account and transaction presentation
- [ ] Exchange-rate storage
- [ ] Historical FX conversion
- [ ] User-selectable reporting currency
- [ ] Currency-aware analytics and net worth
- [ ] Open API
- [ ] External integrations
- [ ] Structured data export
- [ ] Backup and restore
- [ ] Optional encrypted sync only when explicitly enabled

---

### Research / Ideas

Ideas in this section may become future architecture work but are not approved implementation plans.

#### Import & Parsing Research

- [ ] Resilient parser adaptation when institutions change layouts
- [ ] Institution-specific parser profiles and versioning
- [ ] Semi-automated parser generation from approved fixtures
- [ ] AI-assisted recovery for unsupported or ambiguous layouts
- [ ] OCR confidence and human-review boundaries
- [ ] Shared parser evidence model across CSV, PDF, XLS, XLSX and TXT

#### Persistence Research

- [ ] Cross-repository unit-of-work architecture
- [ ] Import rollback and compensation strategies
- [ ] Concurrent import locking and identity race prevention
- [ ] Repository history and reversible financial mutations
- [ ] Backup verification and disaster recovery

#### Financial Intelligence Research

- [ ] Explainable recommendations
- [ ] Anomaly detection
- [ ] Cash-flow forecasting
- [ ] Subscription and recurring-payment intelligence
- [ ] Cross-account transfer inference
- [ ] Tax and regulatory reporting assistance

---

## Workflow

- This document is the permanent repository backlog.
- Items here are approved ideas or recorded maintenance needs, but are **not** scheduled work.
- Chat decides when an item becomes an ACTIVE sprint.
- When an item becomes part of `Implementation.md`, remove it from this document.
- Completed work belongs in `PROJECT_STATE.md`.
- Architecture decisions belong in `ADR.md`.
- Temporary planning and execution reports belong in `Codex response.md`.
- Keep backlog entries independent of specific implementation details unless a verified architectural risk must be preserved.
- Do not use this document as a substitute for repository discovery before sprint planning.

---

## Verification

When updating this document:

- Only add, remove, rename or reprioritize backlog items.
- Do not record implementation progress here.
- Do not record completed sprint history here.
- Do not convert backlog items into ACTIVE sprint plans.
- Remove any item promoted into `Implementation.md`.
- Keep completed work out of the backlog.
- Keep architecture decisions in `ADR.md`.
- Keep the document implementation-agnostic.
- Preserve LedgerForge principles: offline first, privacy by default, deterministic before intelligent, single source of truth, resilient parsing and explicit user control.
