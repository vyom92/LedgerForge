# LedgerForge UI/UX v1.0 Frozen

**Version:** 1.0  
**Status:** FROZEN  
**Status alignment reviewed:** 2026-07-24  
**Repository ref reviewed:** `main@686e3b91bfbf9459a38e9137abee6a2588ecec7f`  
**Latest verified implementation baseline:** `11035461ce3de0f11ae5262bbc8a38b9639607b2` — Sprint 53

## Purpose

This document defines LedgerForge's frozen visual architecture, interaction model and design language.

It defines how LedgerForge should look and behave.

It does not define:

- current production parser support;
- backlog readiness;
- sprint sequencing;
- migration state;
- implementation authorization.

Those belong to `PROJECT_STATE.md`, `FUTURE_WORK.MD`, accepted ADRs and the current Chat-approved execution prompt.

Implementation sprints translate this specification and its approved assets into SwiftUI. They must not redesign the visual language merely because implementation makes improvisation convenient.

---

## Status Alignment

The frozen visual baseline remains active.

Verified implementation through Sprint 53 adds or clarifies the following behavior within the existing v1 shell:

- repository-backed Dashboard, Accounts, Transactions, Imports and Settings experiences;
- repository-ID account selection;
- inline account display-name editing;
- trusted account and import provenance;
- native-currency financial presentation;
- durable import-attempt history;
- explicit account creation or eligible-account choice during supported import review;
- deterministic duplicate and supported transaction-event outcomes;
- explicit confirmation before accepted persistence;
- provider-owned atomic confirmed import;
- canonical post-write refresh through `RepositoryStoreHydrator`;
- truthful persistence-unavailable presentation;
- functional Developer Mode and DEBUG-only database lifecycle tools;
- bundle-derived version and build presentation;
- removal of inactive Settings navigation, unbacked preferences and unsupported destructive controls.

These are status clarifications, not a redesign.

The UI must not display:

- a lifecycle status that lacks repository authority;
- unsupported analytics as user financial facts;
- inactive controls that imply a working outcome;
- fake search or drag-and-drop affordances;
- raw persistence codes, file paths, SQL errors or unredacted identifiers;
- future modules merely to make the interface appear more complete.

---

## Relationship to Other Documents

- **Product Vision** defines what LedgerForge should become.
- **Architecture v1.0 Frozen and accepted ADRs** define how LedgerForge is engineered.
- **This document** defines the frozen visual and interaction baseline.
- **Approved UI assets** define screen-level visual detail.
- **PROJECT_STATE.md** records verified implementation reality.
- **FUTURE_WORK.MD** records unscheduled work.

Repository implementation is not design authority.

---

## Design Authority

The UI specification is governed by this hierarchy:

1. `Project documents/UI_UX_v1.0_Frozen.md`
2. `Project documents/UI Assets/Approved/DesignBoard_v2.0.png`
3. Remaining approved UI assets
4. SwiftUI implementation

When sources conflict, the higher authority controls unless a newer approved frozen revision explicitly supersedes it.

`DesignBoard_v2.0.png` is the master visual reference.

Individual screen assets inherit its:

- application shell;
- visual language;
- spacing;
- navigation;
- information hierarchy;
- component relationships.

---

# Core Principles

LedgerForge is a desktop financial application.

It is not:

- a spreadsheet;
- a developer tool;
- a database browser;
- an institution-specific transaction viewer;
- an importer pretending to be a financial product.

The interface prioritizes:

1. Clarity
2. Financial truth
3. Information density
4. Speed
5. Predictability
6. Consistency
7. Privacy
8. Accessibility

Every screen should answer a user question.

Examples:

- What is my financial position?
- What changed recently?
- Where did my money go?
- What imported successfully?
- Which account owns this activity?
- Why is this information unavailable?

---

# Approved Visual Direction

LedgerForge uses a Deep Indigo desktop design language.

Visual characteristics:

- dark-mode-first;
- deep indigo gradient workspace;
- slate glass-style cards;
- purple and blue primary accents;
- high-contrast typography;
- dense financial dashboards;
- native macOS interaction patterns;
- thin separators;
- restrained elevation;
- compact financial tables;
- minimal decorative motion.

Semantic colors must reinforce meaning but never carry meaning alone.

- Green may indicate favorable or additive values where financially appropriate.
- Red may indicate destructive, adverse or subtractive values where appropriate.
- Amber indicates warning or attention.
- Neutral colors represent unavailable, unknown or unsupported states.

Debit, credit, income, expense, transfer and liability meaning must come from authoritative financial semantics, not color convention.

All future screens inherit these visual tokens unless a newer frozen specification supersedes them.

Visual changes require design authority updates before implementation.

---

# Application Shell

## Frozen layout

```text
┌──────────────────┬───────────────────────────────────────────┐
│                  │ Toolbar                                   │
│ Sidebar          ├───────────────────────────────────────────┤
│                  │                                           │
│                  │ Main Content                              │
│                  │                                           │
│                  │                                           │
└──────────────────┴───────────────────────────────────────────┘
```

The sidebar occupies approximately 20% of the default window width.

Main content occupies approximately 80%.

The exact divider position may respond to approved native resizing behavior, but the structural relationship remains frozen.

Future modules extend this shell rather than replace it.

No feature should introduce a separate institution-specific application shell.

---

# Sidebar

The sidebar is persistent in the primary application window and contains navigation only.

## v1 navigation

- Dashboard
- Accounts
- Transactions
- Imports
- Settings

## Developer access

Developer tooling is hidden during normal operation.

When Developer Mode is enabled, an approved Developer Console or developer destination may become available without displacing normal financial navigation.

DEBUG-only destructive database controls must never appear in Release builds.

## Future navigation

Future modules may include:

- Insights
- Budgets
- Reports
- Investments
- Financial Timeline
- Financial Intelligence
- Rules & Automation

Future destinations must not appear as inactive navigation, “Soon” rows or unrelated placeholder screens.

A future module enters the sidebar only after:

1. its product scope is approved;
2. its repository-backed data authority exists;
3. an approved screen asset or frozen UI update exists;
4. its navigation outcome is functional.

---

# Toolbar

The toolbar contains contextual controls for the active destination.

Possible controls include:

- date range;
- filters;
- search;
- workspace selection when supported;
- Import Statement;
- destination-specific actions.

Rules:

- controls affect only the visible domain;
- scope must be obvious;
- controls must be functional;
- unsupported controls remain absent;
- filters must preserve deterministic results;
- keyboard access is required;
- toolbar actions must not conceal financial mutation.

Global structural navigation does not belong in the contextual toolbar.

---

# Shared Truthfulness Rules

Every screen must derive visible financial and workflow state from its authoritative owner.

## Required behavior

- Financial values use authoritative `Money`.
- Native currency remains visible.
- Mixed currencies are not silently combined.
- Unknown or malformed persisted values use neutral bounded presentation.
- Unsupported features appear absent or explicitly unavailable.
- Repository-unavailable state is distinct from empty state.
- Current workflow state takes precedence over stale historical activity.
- Imported source values remain distinguishable from future corrections or derived values.
- Missing provenance is omitted or marked unavailable rather than inferred.
- Privacy-safe summaries replace raw identifiers.

## Prohibited behavior

- hardcoded financial totals presented as user data;
- transformed raw persistence codes shown directly;
- filename-based identity claims;
- global validation state applied to unrelated transactions;
- fake counts derived from transient file selection;
- enabled controls with no complete outcome;
- navigation to unrelated placeholders;
- path, SQL or unrestricted source-fragment disclosure.

---

# Dashboard

`Project documents/UI Assets/Approved/DesignBoard_v2.0.png` is the master visual reference.

`Dashboard_v1.0.png` defines the approved dashboard target within that system.

## Primary question

> What is my financial position, and what changed?

## Major sections

- Financial Snapshot
- Accounts
- Recent Transactions
- Import Activity
- Quick Actions

## Rules

- Dashboard values must be repository-backed.
- Mixed-currency values remain grouped unless approved conversion exists.
- Recent Transactions is a bounded summary, not the full transaction browser.
- Import Activity reflects current workflow or durable attempt truth.
- Unknown import outcomes remain neutral.
- Unsupported spending percentages, trends, forecasts or cash-flow analytics must not appear as real financial facts.
- Quick Actions must perform or navigate to the stated outcome.
- Future cards may be added without changing the shell, but only after their financial authority and visual design are approved.

---

# Accounts

`Accounts_v1.0.png` defines the approved Accounts target.

## Primary question

> What financial entities do I own, and what activity belongs to each?

## Page structure

- account list;
- selected-account inspector;
- account balance and native currency;
- institution and account-family presentation;
- recent account activity;
- trusted import provenance where approved.

## Current interaction clarifications

- Account selection uses immutable repository identity.
- Display-name editing changes presentation only.
- Editing must not replace the account or its dependent financial graph.
- The account inspector must not present lifecycle status until backed by approved repository semantics.
- Financial identifiers are redacted.
- Shared customer context or profile labels do not merge accounts.
- Account activity remains part of the global repository-backed Transactions truth.

## Future extensions

- archive and restore;
- notes;
- icon and color customization;
- institution logos;
- grouping and favorites;
- full account transaction-history navigation;
- closure status.

Future extensions must preserve immutable account identity and financial history.

---

# Transactions

`Transactions_v1.0.png` defines the approved Transactions target.

## Primary question

> What financial activity occurred across my accounts?

## Page structure

- global transaction table;
- functional search;
- contextual filters;
- bounded summary;
- selection;
- future detail inspector.

## Rules

- All supported bank and card transactions share one global repository-backed experience.
- Institution-specific parsers do not create separate transaction stores or screens.
- Dashboard recent activity is a subset of this domain.
- Amount, currency, date and direction use authoritative transaction semantics.
- Transaction validation presentation comes from the transaction's trusted import-session relationship.
- Missing or unknown validation provenance is not inferred from another import.
- Search and filters appear only when functional.
- Future categories, notes, transfer relationships and provenance views remain visibly distinct from immutable imported truth.
- Bulk or destructive actions require separately approved mutation boundaries.

---

# Imports

`ImportWizard_v1.0.png` defines the approved temporary import workflow.

The Imports destination provides durable history and result navigation.

## Primary questions

> What happened during import?  
> What succeeded, failed, was rejected or was blocked?  
> What evidence and guidance are available?

## Imports destination

May present:

- durable import-attempt history;
- bounded outcome;
- coverage;
- account-decision provenance;
- validation result;
- privacy-safe guidance;
- related imported document and session where available;
- detail navigation.

## Rules

- Successful sessions remain distinct from rejected attempts.
- Duplicate, failed, rejected and cancelled attempts do not masquerade as successful imports.
- Known outcome, coverage and guidance values require explicit typed presentation.
- Unknown or future values remain neutral and bounded.
- Raw codes and unrestricted source fragments remain hidden.
- Imports is a user-facing history and understanding experience, not a developer log viewer.

---

# Import Workflow

Import is a temporary workflow, not a permanent page hierarchy.

## Frozen interaction sequence

```text
Import Statement
      ↓
Choose Authorized File
      ↓
Prepare and Read Source
      ↓
Preview and Validate
      ↓
Review Account / Identity Decision
      ↓
Review Duplicate or Supported Event Outcome
      ↓
Explicit Confirmation
      ↓
Provider-Owned Atomic Persistence
      ↓
Canonical Repository Hydration
      ↓
Result and Financial View Refresh
```

## Workflow rules

- macOS owns authorization to user-selected files and folders.
- LedgerForge does not claim unrestricted filesystem access.
- Reader, institution, classification and parser progress may be shown through bounded named stages.
- Preview shows prepared evidence before accepted persistence.
- Validation must complete before confirmation.
- Account creation or eligible-account choice is explicit where required.
- Duplicate and supported event-overlap outcomes must be explained before accepted persistence.
- The user explicitly confirms the prepared import.
- Confirmation does not authorize a best-effort write.
- The provider transaction revalidates authoritative repository claims.
- Accepted writes publish the complete financial graph or no accepted financial residue.
- Runtime stores refresh only through `RepositoryStoreHydrator`.
- Safe cancellation is available only before confirmed persistence begins.
- Confirmed persistence is non-cancellable.
- Unsupported retry states remain unavailable rather than guessed.

---

# Preview

Preview is not a permanent application destination.

It exists only inside the import workflow.

Preview may show:

- source and statement summary;
- account or identity decision;
- transactions;
- native currency;
- date and direction;
- validation;
- duplicate or overlap outcome;
- confirmation controls.

Preview must not:

- display parser output as already persisted truth;
- imply that confirmation succeeded before provider acceptance;
- silently omit blocked transactions;
- expose raw identifiers or unrestricted source evidence;
- allow unapproved correction workflows.

After completion, the user returns to an appropriate financial or import-history destination.

---

# Settings

`Settings_v1.0.png` defines the approved Settings target.

## Primary question

> How is LedgerForge configured, and what trusted runtime state is active?

## Current approved content

- functional Developer Mode control;
- authoritative persistence state;
- repository/runtime information;
- durable Completed Imports count;
- bundle-derived version and build.

## Rules

- Non-durable or unavailable persistence displays `Unavailable` where durable truth cannot be claimed.
- Completed Imports counts accepted durable imports, not selected files.
- Database paths, raw SQL and unrestricted SQLite errors remain hidden.
- Unimplemented preferences remain absent.
- Future destructive actions remain absent.
- DEBUG-only lifecycle controls remain separated from ordinary user settings.
- User preferences may be added only after durable preference semantics and approved UI behavior exist.

---

# Developer Console

`DeveloperConsole_v1.0.png` defines the visual target for approved developer tooling.

Developer Console is not part of normal user navigation.

It is available only through Developer Mode and appropriate build configuration.

## Purpose

- parser and source-evidence diagnostics;
- repository and persistence diagnostics;
- validation summaries;
- performance evidence;
- controlled fixture launching;
- DEBUG-only lifecycle operations where approved.

## Privacy and authority

Developer tooling must not expose:

- passwords;
- unredacted financial identifiers;
- unrestricted source fragments;
- raw database paths in ordinary presentation;
- production-only destructive controls in Release.

Developer tools must not:

- create alternate financial logic;
- auto-confirm imports;
- inject expected results into production processing;
- bypass validation, duplicate handling, identity review or persistence;
- become the source of financial truth.

Approved fixtures enter the ordinary production URL-driven preparation seam.

---

# Design System

`Project documents/UI Assets/Approved/DesignSystem_v1.0.png` defines reusable visual tokens.

## Foundations

- 8-point spacing grid;
- SF Pro typography;
- SF Symbols-style iconography;
- glass-like slate surfaces;
- Deep Indigo theme;
- consistent elevation;
- native macOS controls;
- thin separators;
- rounded corners;
- minimal shadows;
- financial-first hierarchy;
- tabular figures for financial values;
- right-aligned numeric columns.

## Motion

Animation is:

- fast;
- subtle;
- purposeful;
- reducible through accessibility settings.

Motion must not obscure changes in financial truth or workflow state.

## Component rule

No component introduces a new visual language independently.

New reusable components require alignment with the master Design Board and Design System.

---

# Component Library

`ComponentLibrary_v1.0.png` defines the approved component direction.

## Navigation

- Navigation Sidebar
- Contextual Toolbar

## Financial components

- Financial KPI Card
- Account Card
- Transaction Table
- Import Activity Card
- Native-Currency Amount
- Bounded Financial Summary

## Input components

- Search Field
- Filter Controls
- Import Wizard
- Confirmation Controls

## Status components

- Status Badge
- Validation Banner
- Unavailable State
- Warning State
- Progress Stage

## Developer components

- Developer Console
- Privacy-Safe Diagnostic Summary
- DEBUG-Only Lifecycle Controls

Components must retain semantic, privacy and accessibility behavior across screens.

---

# Visual Rules

- Comfortable but information-dense spacing.
- Readable financial tables.
- Cards aligned to a consistent grid.
- No floating utility windows for primary workflows.
- Avoid nested scrolling.
- Primary content has one obvious scroll owner.
- Empty, unavailable, loading and failed states are visually distinct.
- Selection remains visible.
- Focus remains visible.
- Numeric alignment is consistent.
- Status is never communicated by color alone.
- Long identifiers are redacted or summarized.
- User-facing terminology avoids internal implementation names.
- Copy actions must preserve privacy-safe bounded presentation.

---

# Accessibility

Accessibility is a release requirement.

## Required behavior

- keyboard-first navigation;
- native macOS shortcuts where appropriate;
- complete keyboard access to primary interactions;
- visible focus;
- VoiceOver-compatible labels and grouping;
- resizable layouts;
- support for reduced motion;
- sufficient contrast;
- semantic status beyond color;
- tabular figures without harming spoken accessibility;
- predictable traversal order.

Dark Mode is the current primary target.

Light Mode requires a separately approved design revision and updated assets.

---

# Screen Inventory

## v1 approved implementation targets

- Dashboard
- Accounts
- Transactions
- Imports
- Settings

## Conditional developer target

- Developer Console, hidden by default and governed by Developer Mode and build configuration

## Future screens

- Insights
- Budgets
- Reports
- Investments
- Financial Timeline
- Financial Intelligence
- Rules & Automation
- Financial Health
- Goals
- Documents and Provenance
- Multi-Currency Reporting

Future screens extend the frozen shell.

They must not appear as inert v1 navigation.

---

# Approved UI Assets

The approved assets are located under:

```text
Project documents/UI Assets/Approved/
```

The specification includes:

- `DesignBoard_v2.0.png` — master reference
- `Dashboard_v1.0.png`
- `Accounts_v1.0.png`
- `Transactions_v1.0.png`
- `ImportWizard_v1.0.png`
- `Settings_v1.0.png`
- `DeveloperConsole_v1.0.png`
- `DesignSystem_v1.0.png`
- `UserJourney_v1.0.png`
- `ComponentLibrary_v1.0.png`
- `AppIcon_v1.0.png` — approved application-icon reference

The master Design Board controls overall structure and visual language.

Screen assets define approved screen detail within that system.

Implementation must not infer business logic, persistence semantics or financial authority from visual assets alone.

---

# Acceptance Criteria

A UI implementation increment is acceptable only when its bounded scope satisfies the applicable criteria below.

## Shell and navigation

- Navigation matches the frozen shell.
- The sidebar remains persistent.
- Only functional approved destinations appear.
- Developer tooling is hidden during normal use.
- Future modules do not appear as inert placeholders.

## Visual fidelity

- The screen matches its approved asset.
- It remains consistent with `DesignBoard_v2.0.png`.
- It introduces no unapproved visual language.
- Components use the approved design system.

## Financial truth

- Financial values use authoritative repository-backed state.
- Native currency remains visible.
- Mixed currencies are not silently aggregated.
- Unsupported analytics do not appear as facts.
- Unknown and unavailable states remain neutral.
- Privacy-safe summaries replace raw identifiers and codes.

## Workflow truth

- Preview remains temporary.
- Confirmation is explicit.
- Accepted persistence is not implied before provider success.
- Cancellation and retry controls match actual safety boundaries.
- Dashboard and Imports distinguish current workflow from durable history.
- Repository-unavailable is distinct from empty.

## Interaction and accessibility

- Primary actions are keyboard accessible.
- Focus, selection and scope remain visible.
- VoiceOver labels are meaningful.
- Status is not color-only.
- Resizing preserves usable hierarchy.
- No control implies an unsupported outcome.

## Asset authority

- Applicable approved assets exist.
- The master Design Board remains the visual authority.
- Any intentional visual change is approved before implementation.

A green test suite alone does not prove visual, semantic or accessibility acceptance.

---

# Change Policy

Major UI changes require:

1. Proposal
2. Design review
3. Master Design Board update when shell or visual language changes
4. Affected screen-asset updates
5. Approval
6. Frozen-document revision
7. Visual and interaction acceptance criteria
8. Implementation authorization

Minor refinements may update individual screen assets without a new master Design Board only when:

- the shell is unchanged;
- the visual language is unchanged;
- financial and workflow semantics are unchanged;
- the refinement is explicitly approved.

Implementation must not become the source of truth for design.

When implementation and approved assets differ, the approved hierarchy controls unless a newer frozen revision has been approved.

Architecture, Product Vision, this frozen specification and approved assets together define the UI implementation boundary. Repository state and the current execution prompt determine which bounded portion may actually be implemented.
