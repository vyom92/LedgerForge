# Inherited screen contracts

Canonical inherited written behavior for Accounts, Import/Preview, Salary, Settings and Developer Console, relocated from the frozen UI authority. R1 shared requirements apply; later accepted implementation is tracked in [current state](../../PROJECT_STATE.md). This file creates no new workflow, reopens no rejected work and asserts no new native acceptance. Original task-specific statements are interpreted with current scope/source rules.

## 5. Simple local appearance

Offer **Follow System**, **Light** and **Dark** using native controls. An optional choice using the existing system/Deep Indigo accent direction may remain. Keep the chosen local preference across relaunch; missing or malformed values fall back to a readable default without blocking financial hydration. Monetary columns retain tabular digits and complete amounts.

[FW-P2-52](../../FUTURE_WORK.MD#fw-p2-52) owns this bounded work. It does not require an advanced theme editor, custom foreground/background controls, font-style or text-scale system, density preferences, translucency controls, Preview/Apply/Cancel transaction, appearance portability or a new preference architecture/ADR by default. Appearance changes do not mutate financial data. Implementation and storage choices require the separately approved bounded task.


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

# Imports

`ImportWizard_v1.0.png` defines the approved temporary import workflow.

The Imports destination provides durable history and result navigation.

## Primary questions

> What happened during import?
>
> What succeeded, failed, was rejected or was blocked?
>
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
