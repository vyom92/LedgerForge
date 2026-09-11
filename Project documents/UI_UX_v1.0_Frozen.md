# LedgerForge UI/UX v1.0 Frozen

**Version:** 1.0  
**Status:** FROZEN  
**Status alignment reviewed:** 2026-09-11
**Repository ref reviewed:** `main@23f216a3d9cb8d432d177916e13febde23516b4a`
**Current implementation context:** Sprint 88 is the accepted numbered baseline; Sprint 89 is paused, unaccepted WIP. The private-personal scope reset changes documentation authority only. `LF-UI-2026-09-R1` is approved visual direction for its bounded scope and is not implemented merely by this alignment.

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

## Current design alignment — LF-UI-2026-09-R1 — 2026-09-11

The user explicitly approved `LF-UI-2026-09-R1`. For its defined scope, [`UI Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md`](UI%20Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md) is the current written presentation/interaction authority and [`MasterBoard_LF-UI-2026-09-R1.png`](UI%20Assets/LF-UI-2026-09-R1/MasterBoard_LF-UI-2026-09-R1.png) is the current visual authority. `DESIGN_TOKENS.json` and `ACCEPTANCE.md` define the shared-system and acceptance detail. The artwork label “LedgerForge v2.0” is design-board text, not an application version.

Design approval is independent from native implementation acceptance. SwiftUI implementation remains separate and incomplete. Details of untouched screens inherit legacy approved references only where they remain consistent with this handoff, accepted product behavior, current financial semantics and ordinary owner-usability requirements.

### Shared appearance and design-system direction

For covered scope, R1 supersedes the former fixed-theme requirement:

- **Follow System** is the default target; **Light** and **Dark** are explicit choices.
- **System Neutral** and **Deep Indigo** are preset concepts; Deep Indigo is optional, not mandatory.
- Shared semantic colour roles replace theme-specific semantic assumptions. Colour never establishes financial meaning by itself.
- Appearance is limited to simple local System/Light/Dark and an optional existing accent choice, with readable defaults and local persistence.
- Advanced foreground/background, font/text-scale, density, translucency, Preview/Apply/Cancel and portable-preference programmes are excluded by the private-personal scope gate.
- Preference persistence/storage ownership is not chosen by this design approval.
- The overall shell remains sidebar + contextual toolbar + primary content, while R1 responsive hierarchy supersedes any fixed 20/80 proportion as a hard requirement; narrow layouts close the inspector first, prefer an icon-only navigation rail, and hide navigation only when even the rail harms usable content width, retaining labelled navigation/details controls.

### Transactions direction

R1 approves a global Transactions proof surface with:

- period, account, currency, category, bank/card family, authoritative financial-effect/direction and bounded institution/amount filtering;
- AND across filter groups and OR within a multi-select group;
- visible active scope, clear-filters and truthful no-match states;
- sortable supported columns with repeated-heading reversal, deterministic stable ties and currency-safe amount sorting;
- resizable columns, stable selection and a collapsible inspector;
- scoped **native-currency** totals only, with no implicit mixed-currency conversion; and
- readable descriptions and responsive narrower-window behavior.

Presentation filtering/sorting never changes durable source order or balance semantics. **Debit is not automatically “spending” and credit is not automatically “income”** without supporting financial semantics.

### Dashboard direction

- Summaries remain grouped by native currency unless a separately approved conversion authority exists.
- Full amounts must remain readable and must not be broken into misleading wrapped fragments.
- Responsive grouping may adapt to available width without inventing consolidation.
- Bank balance and card liability remain distinct financial concepts.
- No fake trends, charts, percentages or unsupported analytics may appear as user truth.
- Repository hydration/startup events must not masquerade as import activity.
- Period/as-of context is shown where authoritative evidence exists.

### Appearance settings direction

The approved settings surface is simple local Follow System / Light / Dark with an optional existing system/Deep Indigo accent choice. A selected preference persists locally and invalid values fall back safely. [FW-P2-52](FUTURE_WORK.MD#fw-p2-52) owns this narrowed outcome; no advanced editor, portable preference contract or new preference architecture/ADR is a default requirement.

### Explicit exclusions retained

Do not reintroduce a static **Vyom / Personal** profile block, permanent **Truth classes** panel, inactive “Soon” navigation, fake Add Transaction, unsupported Export, illustrative analytics presented as data, raw identifiers, or generic clearing/reconciliation states without accepted financial semantics. Contextual provenance remains required even though the permanent Truth-classes panel is not.

R1 changes presentation authority only. It creates no Money rule, FX authority, spending/income inference, transfer matching, persistence semantic, migration or source authority.

---

## Status Alignment

The historical frozen visual baseline remains inherited only where it is not superseded by the 2026-09-09 R1 alignment or later accepted product behavior.

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

## Historical Alignment — Sprint 59 (superseded by later current alignments)

Sprint 54's durable import-outcome presentation remains operational. Sprint 57 and Sprint 57A provide durable manual categories, current transaction assignments and category-reconciliation-safe Settings and transaction-detail interactions through Migration V8. Sprint 58's import-verification workspace is DEBUG-only and follows the ordinary import preparation and confirmation path. The former ordinary Axis partial-import family is suspended, no production PDF workflow exists, automatic categorization remains unavailable, and unsupported analytics or reports must not be presented as financial truth.

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

1. `Project documents/UI_UX_v1.0_Frozen.md`, including its current R1 alignment and accepted financial/workflow semantics;
2. `Project documents/UI Assets/LF-UI-2026-09-R1/DESIGN_HANDOFF.md` for the scope it defines;
3. `Project documents/UI Assets/LF-UI-2026-09-R1/MasterBoard_LF-UI-2026-09-R1.png` as the current visual authority for that covered scope, with its tokens/acceptance files;
4. legacy approved screen/design assets for untouched details only where consistent with newer authority and accepted product behavior;
5. SwiftUI implementation.

When sources conflict, the newer/higher applicable authority controls. `DesignBoard_v2.0.png` remains byte-identical historical/inherited reference material but is superseded as master visual authority for scope covered by R1.

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

Historically, LedgerForge used a Deep Indigo desktop design language. For scope covered by `LF-UI-2026-09-R1`, the Current design alignment above supersedes fixed Deep Indigo with adaptive System/Light/Dark appearance and optional Indigo.

The following Deep-Indigo characteristics are legacy/historical references for inherited scope; R1-covered scope uses the adaptive design-system authority above:

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

Uncovered legacy details may inherit these tokens where consistent; R1-covered scope uses the newer shared tokens and appearance contract.

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

The historical default used an approximate 20/80 sidebar/content split. Under R1 this is a reference composition, not a fixed ratio: the responsive hierarchy adapts to content fit, text size and narrower-window behavior while preserving the sidebar/toolbar/content relationship.

Future modules extend this shell rather than replace it.

No feature should introduce a separate institution-specific application shell.

---

# Sidebar

The sidebar is persistent in the primary application window and contains navigation only.

## Current primary navigation

- Dashboard
- Accounts
- Transactions
- Imports
- Salary
- Settings

## Developer access

Developer tooling is hidden during normal operation.

When Developer Mode is enabled, an approved Developer Console or developer destination may become available without displacing normal financial navigation.

DEBUG-only destructive database controls must never appear in Release builds.

## Future navigation

Add a destination only for a named owner workflow that passes the private-personal scope gate. A catalogue of possible finance-app modules is not a requirement.

Future destinations must not appear as inactive navigation, “Soon” rows or unrelated placeholder screens.

A future module enters the sidebar only after:

1. its actual owner workflow passes the private-personal scope gate and its product scope is approved;
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

For Dashboard scope, `LF-UI-2026-09-R1` is the current master/written design authority. `Dashboard_v1.0.png` remains a byte-identical historical/inherited reference only where consistent with R1 and accepted product behavior.

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

For Transactions scope, `LF-UI-2026-09-R1` is the current written/visual authority. `Transactions_v1.0.png` remains historical/inherited reference material only where consistent with R1.

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

For Appearance settings, `LF-UI-2026-09-R1` supersedes the legacy Settings visual direction. `Settings_v1.0.png` remains historical/inherited reference material for untouched Settings details where consistent with current behavior.

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

# Startup reliability and monthly planner amendment — 2026-09-09

This bounded amendment records the Chat-accepted unnumbered startup/diagnostics/planner package, including the non-negative-transfer-fee correction. Loading and unavailable data must not look like an empty financial database. Retained values after a failed refresh are explicitly non-current and durable mutations are disabled. A failure banner may navigate directly to Diagnostics even when ordinary Developer Mode navigation is hidden; this is a diagnostic recovery entry, not permission for destructive operations.

Salary offers separate **This Month** and **Salary History** sections while retaining the same draft. Qatar QAR inputs and commitments sit alongside India INR inputs, commitments and dated offline FX when width permits; narrower layouts stack them. Contextual labels identify estimates, copied values, captured balances, payslip actuals and calculated results. Contextual provenance replaces the standalone Truth classes panel, not the underlying provenance requirement. The static personal avatar block is removed. Imported salary remains immutable.

The configured native-QAR transfer fee must be non-negative and permits zero. The existing effective-fee rule remains: the fee applies only when India funding shortfall is positive; otherwise effective fee is zero while the configured value is retained, editable and eligible for rollover.

Every visible edit updates one view-model draft immediately. Whole and fractional amounts retain natural editing text, with exact canonical Money used only at the domain/persistence boundary. One Save and Command-S validate all visible fields, including the focused field. Invalid or partial input remains visible with inline feedback and makes current calculations incomplete. Copy previous month requires a dirty-draft discard choice. An unknown write outcome blocks retry until reopening establishes canonical state. A committed save followed by failed canonical refresh offers reload without replaying the write; provider changes retain and block old drafts until explicit canonical reload.

Diagnostic entries retain at most 1,000 events. Copy All includes the entire retained history in sequence order, independent of filters, with UTC timestamps and sorted multiline safe metadata. Details wrap, are selectable and remain accessible. Typed migration/provider/hydration causes, effect, related failure reference and safe next action are authoritative only to the captured boundary. Raw source values, financial amounts, credentials, paths, SQL and arbitrary error descriptions are excluded; missing evidence stays unavailable. No diagnostic text authorizes automatic repair.

---

# Developer Console

`DeveloperConsole_v1.0.png` defines the visual target for approved developer tooling.

Developer Console is not part of normal user navigation.

It is available only through Developer Mode and appropriate build configuration.

## Purpose

- parser and source-evidence diagnostics;
- repository and persistence diagnostics;
- validation summaries;
- bounded evidence for an actual local failure;
- authentic-source validation through the ordinary import path;
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

Only permitted authentic statement evidence enters statement-dependent checks through the ordinary production URL-driven preparation seam; artwork and generated statement fixtures are not test inputs.

---

# Design System

`LF-UI-2026-09-R1/DESIGN_TOKENS.json` and `DESIGN_HANDOFF.md` define reusable shared tokens/components for R1-covered scope. `DesignSystem_v1.0.png` remains historical/inherited reference material for compatible untouched details.

## Foundations

- 8-point spacing grid;
- SF Pro typography;
- SF Symbols-style iconography;
- glass-like slate surfaces;
- Deep Indigo theme (legacy reference and optional R1 preset, not a mandatory appearance);
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
- purposeful.

Motion must not obscure changes in financial truth or workflow state.

## Component rule

No component introduces a new visual language independently.

New reusable components require alignment with the applicable R1 handoff/tokens and compatible inherited design references.

---

# Shared visual components

For components covered by R1, DESIGN_HANDOFF.md §2.2 and DESIGN_TOKENS.json are canonical. Redundant scratch component inventories are not authority. `ComponentLibrary_v1.0.png` remains historical/inherited component direction where compatible.

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

Components retain financial meaning, privacy, useful native names, focus and selection across screens.

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

# Ordinary owner usability

Keep readable Money and currency, no clipping, useful keyboard paths and native shortcuts, visible focus, distinct selection, usable resizing and meaningful icon names/tooltips. Consequential status cannot rely on colour alone. Verify actual owner workflows under the selected implementation scope.

Formal VoiceOver, Full Keyboard Access, reduced-motion/transparency campaigns, contrast certification and a separate accessibility release gate are **NOT REQUIRED — DO NOT CONSIDER**. Existing harmless native labels may remain. Follow System/Light/Dark stays the simple appearance target. The handoff's exact PNG-caption exceptions preserve valid design while superseding rejected acceptance captions.

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

A new screen requires a concrete owner workflow, durable eligible scope in FUTURE_WORK.MD, approved design and implementation authorization. It must be functional when exposed; no speculative module inventory or inert navigation is required.

---

# Approved UI Assets

The current R1 handoff is located under:

```text
Project documents/UI Assets/LF-UI-2026-09-R1/
```

The current approved R1 package is:

- `LF-UI-2026-09-R1/DESIGN_HANDOFF.md` — current written authority for its covered scope;
- `LF-UI-2026-09-R1/MasterBoard_LF-UI-2026-09-R1.png` — current master visual reference for its covered scope;
- `LF-UI-2026-09-R1/DESIGN_TOKENS.json`, `ACCEPTANCE.md`, `SOURCES.md`, `ASSET_MANIFEST.json` and `README.md` — supporting design/acceptance evidence.

Legacy assets are retained byte-identically as historical/inherited references under `Project documents/UI Assets/Archived/`, including:

- `Archived/DesignBoard_v2.0.png`;
- `Archived/Dashboard_v1.0.png`
- `Archived/Accounts_v1.0.png`
- `Archived/Transactions_v1.0.png`
- `Archived/ImportWizard_v1.0.png`
- `Archived/Settings_v1.0.png`
- `Archived/DeveloperConsole_v1.0.png`
- `Archived/DesignSystem_v1.0.png`
- `Archived/UserJourney_v1.0.png`
- `Archived/ComponentLibrary_v1.0.png`
- `Archived/AppIcon_v1.0.png` — approved application-icon reference

For scope covered by R1, the R1 handoff/master board control presentation direction. Legacy screen assets define inherited detail only where consistent with that newer authority and accepted product behavior.

Implementation must not infer business logic, persistence semantics or financial authority from visual assets alone.

---

# Acceptance Criteria

A UI implementation increment is acceptable only when its bounded scope satisfies the applicable criteria below.

## Shell and navigation

- Navigation matches the frozen shell.
- Navigation remains discoverable under the approved full-sidebar, icon-rail and last-resort hidden treatments.
- Only functional approved destinations appear.
- Developer tooling is hidden during normal use.
- Future modules do not appear as inert placeholders.

## Visual fidelity

- The screen matches the applicable approved authority.
- R1-covered scope remains consistent with `LF-UI-2026-09-R1`; untouched details may inherit legacy assets only where consistent.
- It introduces no unapproved visual language.
- Components use the applicable approved design system.

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

## Interaction and ordinary usability

- Primary actions are keyboard accessible.
- Focus, selection and scope remain visible.
- Native controls retain meaningful names and useful icon tooltips.
- Status is not color-only.
- Resizing preserves usable hierarchy.
- No control implies an unsupported outcome.

## Asset authority

- Applicable approved assets exist.
- `LF-UI-2026-09-R1` is the master visual authority for its covered scope; legacy master assets remain historical/inherited references.
- Any intentional visual change is approved before implementation.

A green test suite alone does not prove visual, financial-semantic or owner-usability acceptance.

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
