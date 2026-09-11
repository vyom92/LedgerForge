# LedgerForge — Product Vision

## Document Role

This document defines the owner's intended personal-finance outcomes. It does not establish current production support, sprint order, architecture, migration state or execution authorization.

[PROJECT_STATE.md](PROJECT_STATE.md) records accepted production reality; the current roadmap owns sprint numbering; [FUTURE_WORK.MD](FUTURE_WORK.MD) owns eligible unscheduled work; accepted [ADRs](ADR.md) own architecture; exact Git/local evidence establishes repository state. Only a complete Chat-approved prompt authorizes execution.

## Mission

LedgerForge is a private personal finance application for the owner's own financial life. It is single-user, macOS-native, offline-first and run primarily on the owner's Mac. It is not intended to become a general-purpose commercial platform.

The owner should be able to understand financial position, review actual activity, plan current commitments and trace every financial conclusion to trustworthy evidence. Imports support that outcome by preserving accurate local financial records from the owner's actual sources.

The priority order remains financial correctness, durable persistence, deterministic behavior, explicit owner control, privacy, recoverability, explainability, maintainability and delivery speed. A private app still requires rigorous protection of the owner's real money and data.

## Private Personal App Scope

Before adding, selecting, researching or preserving a capability, identify an actual requested owner workflow, an owner-data correctness/persistence/privacy/recovery need, a real authentic source supplied or selected by the owner, or a direct day-to-day usability benefit. Without one, the disposition is **NOT REQUIRED-DO NOT CONSIDER**.

Rejected work is excluded from priority triage, dependencies, roadmaps and discovery packets. It is not deferred or a post-v1 candidate. Reopening requires a new explicit owner decision naming the real personal need. Commercial best practice, hypothetical users and possible future usefulness do not establish scope.

## Personal Financial Outcomes

The core experience centers on Dashboard, Accounts, Transactions, Imports, Salary and Settings, with categories and contextual source evidence. These surfaces present authoritative persisted and hydrated state, including truthful empty, unavailable and incomplete states.

The owner-selected personal-adoption outcomes include:

- accurate imports from the owner's actual supported financial sources;
- a readable Dashboard with native-currency position and authoritative time/coverage context;
- Accounts with trustworthy identity, balances and history;
- Transactions with useful search, filters, deterministic sorting, stable selection and complete native-currency totals;
- accepted Qatar Airways Salary actuals, Salary History and This Month planning, with the selected bounded current Al Dar reference and manual-rate override;
- current holdings and valuation for the owner's adopted investments;
- selected current market FX and net-worth estimates with explicit incomplete/stale states;
- verified backup creation, restore, canonical hydration and same-database relaunch; and
- a small private supported-source matrix naming each actual institution/product, accepted format/family, exact boundary and known limitation.

These are intended outcomes, not claims that every boundary is implemented. **PERSONAL-V1: NOT YET ADOPTED.** The prepared roadmap retains Sprint 100 — LedgerForge 1.0 Personal Adoption Verification as the final owner adoption gate.

Transfers, reconciliation, categorization rules, recurrence, investment history and personally useful analytics remain eligible only when selected for an actual owner workflow or required by a verified financial-correctness need. Their existence in a financial-software category does not make them requirements.

## Financial Truth and Identity

Original imported evidence remains immutable. Normalized values, owner-entered planning assumptions and derived estimates remain distinguishable from source facts. Missing dates, identifiers, quantities, balances and provenance remain missing.

Financial entities have immutable repository identity. Institution names, filenames, display labels and structural similarity do not establish ownership or identity. Bank accounts, card-liability accounts and subordinate card instruments retain their accepted distinctions. New adopted investment entities require their own source-backed identity contract; current prices cannot establish ownership or units.

Every Money value retains native currency, scale and source-specific direction or liability meaning. Mixed currencies are not silently aggregated. Bank cash movement and card-liability effects are not combined into misleading income or spending totals. Any adopted conversion is derived, with explicit rate orientation, provenance, effective time and deterministic rounding; it never overwrites source values.

If owner-selected transfer or reconciliation work is implemented, internal movement between owned accounts must not invent income, expense or net-worth change. Similar dates and amounts are not sufficient relationship evidence.

## Authentic Sources and Deterministic Imports

ADR-046 and the complete registered authentic corpus govern every statement-dependent behavior. No synthetic, generated, reconstructed, sanitized, representative, reduced, mutated or hand-authored financial statement may be created or used for development, debugging, tests, source oracles, persistence or acceptance. Exact operational/decrypted copies and actual extracted attachments remain permitted with original-byte provenance. Pure nonfinancial mechanics may use nonfinancial values; missing authentic cases remain source-uncertified.

Each supplied recurring source extends its registered corpus unless the owner explicitly excludes or archives it. Independent source oracles establish source truth; production parser output is never its own sole oracle. Exact support does not generalize across institutions, products, formats, credential families or materially different source contracts. The private supported-source matrix under FW-P2-79 records the actual accepted boundary.

Readers extract and preserve evidence. Source-family parsers interpret financial meaning deterministically, tolerating inert packaging changes while failing closed on ambiguous, contradictory, malformed or unsupported financial evidence. Page count, transaction count, harmless whitespace and benign page breaks do not define support. Any minimum shared parser change must be demonstrated by a real selected owner source, not a standing framework-expansion program.

Single-file and multi-file intake use the accepted serial Import Centre. The ordinary path preserves authorized file access, optional exact-family unlock, extraction, detection/classification, source-family parsing, normalization, validation, duplicate/equivalence checks, explicit per-statement review and confirmation, provider-owned atomic persistence and canonical hydration through `RepositoryStoreHydrator`.

Rejection leaves zero accepted durable residue. Accepted writes cannot bypass validation, duplicate/identity checks or provider revalidation. Preserve SQLite/In-Memory parity where both matter, accepted migration identities, SQLite integrity, hydration and same-database relaunch. Private originals remain isolated read-only evidence and never enter published artifacts.

## Native Owner Experience

The approved R1 handoff and [UI_UX_v1.0_Frozen.md](UI_UX_v1.0_Frozen.md), as narrowed by the 2026-09-11 scope reset, govern actual screens. Design approval remains distinct from native implementation.

The interface should keep financial text and complete Money readable, avoid clipping and overlap, resize sensibly, show focus separately from selection, provide useful ordinary keyboard interaction and name ambiguous icon controls with labels/tooltips. Financial meaning never depends on decorative colour alone. Existing harmless native SwiftUI semantics remain useful.

Appearance is one bounded device-local choice: Follow System, Light or Dark, with optional already-approved Deep Indigo/accent direction. Simple nonfinancial local persistence is sufficient; no theme engine, preference portability or speculative architecture program follows from it.

Keep contextual toolbars, useful Transactions search/filtering, truthful states and explicit action scope. Do not display unsupported controls, fake analytics, inactive destinations or unproven financial status. Existing useful Developer Console and immediate validation/recovery guidance remain available through their accepted boundaries.

## Privacy, Offline Use and Recovery

Core financial use remains local and functional offline. External network access is limited to an explicitly selected personal-finance workflow, such as current investment valuation, current market FX or current Al Dar planning evidence. Each selected source retains its own identity, permission, freshness, cache and unavailable-state boundary. This does not create a general integration, API or sync platform.

Passwords and raw financial identifiers must not leak through ordinary presentation, diagnostics, exports or published artifacts. Exact accepted Keychain behavior, sandboxing and build/signing requirements needed to run safely on the owner's Mac remain intact. No financial data is silently sent to an external service.

Verified backup/restore remains required. The owner may save or copy a verified backup package to a personally chosen destination. A backup package is not a live/shared workspace, sync protocol, multiwriter system or cloud-provider integration. Restore must preserve the accepted integrity, compatibility, confirmation, rollback, hydration and relaunch boundaries. Complete structured export remains optional unless separately selected.

## Explicit Non-Goals

**NOT REQUIRED-DO NOT CONSIDER** applies to hypothetical public/commercial products, teams or organizations, generalized parser/profile-learning/AI-column-detection programs, generic credential products, validation education/support organizations, generalized developer inspector/export platforms beyond accepted useful diagnostics, global cross-domain search, formal accessibility/compliance campaigns, standing performance/profiling programs, public distribution/notarization/App Store programs, sync, public APIs/integrations, plugin ecosystems, multiple workspaces, live portable workspaces, cross-platform clients and advanced theme editors.

The single compact [rejected-scope register](FUTURE_WORK.MD#rejected-private-personal-scope) owns rejected IDs and exact boundaries. This does not remove accepted production behavior or weaken financial correctness, persistence, privacy or recoverability. A newly experienced measurable performance defect or actual new authentic source is handled as that exact owner problem after it exists.

Any app-level encryption decision requires a concrete owner disclosure concern; it is never an automatic backup dependency or normal sprint candidate. No hypothetical capability is required to call the private app complete enough for the owner.
