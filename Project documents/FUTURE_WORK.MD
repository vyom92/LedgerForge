# LedgerForge Future Work

## Purpose

This document is the canonical planning queue for LedgerForge work that is not part of the current ACTIVE sprint.

It records:

- product feature candidates;
- architectural follow-up work;
- verified bugs;
- maintenance work;
- technical debt;
- engineering-quality improvements;
- product ideas;
- research topics.

It exists so future work is selected from a recorded, evidence-based queue rather than reconstructed from conversations or inferred from incomplete project history.

Completed and verified work belongs in:

`Project documents/PROJECT_STATE.md`

Architectural decisions belong in:

`Project documents/ADR.md`

Only the approved ACTIVE sprint belongs in:

`Project documents/Implementation.md`

Temporary repository-discovery and implementation reports belong in:

`Project documents/Codex response.md`

Items promoted into the ACTIVE sprint must be removed from this document or narrowed to the portion that remains unscheduled.

---

## Authority

This document is a planning queue, not an implementation contract.

An item appearing here means only that the work has been recorded for future consideration.

It does not mean that the item:

- is approved for implementation;
- has been assigned a sprint number;
- will be selected next;
- has completed repository discovery;
- has an approved architecture;
- can be implemented independently of its dependencies.

No future sprint number may be assigned in this document.

A sprint becomes approved only when Chat defines it and records it as the sole ACTIVE sprint in `Project documents/Implementation.md`.

---

## Planning Principles

Future work is ordered by:

1. priority;
2. dependency readiness;
3. architectural safety;
4. product value;
5. scope coherence.

Priority and readiness are separate.

A high-priority candidate may remain blocked by unfinished dependencies, missing fixtures, unresolved architecture or insufficient repository evidence.

Several related candidates may be combined into one sprint when repository discovery shows that they:

- produce one coherent user or architectural outcome;
- share the same architectural boundary;
- depend on each other to be useful or safe;
- can be validated through one bounded acceptance plan.

Candidates should remain separate when combining them would:

- cross unrelated product outcomes;
- mix unrelated persistence, parser, UI and domain changes;
- require multiple unresolved architecture decisions;
- make implementation or validation unreasonably broad;
- prevent the result from being accepted independently.

The unit of sprint planning is one coherent outcome, not one backlog bullet.

---

## Priority Definitions

### P0 — Integrity and Safety

Work required to protect financial correctness, durable identity, privacy, persistence integrity or recoverability.

### P1 — Core Product Capability

Major work that expands supported accounts, institutions, formats, import workflows or essential product operations.

### P2 — Workflow and Experience

Important transaction, account, developer, usability and engineering-quality improvements.

### P3 — Later Product Expansion

Analytics, investments, multi-currency and ecosystem capabilities that depend on a mature core platform.

---

## Status Definitions

### Ready for discovery

Dependencies appear satisfied. Work may be considered during the next sprint-planning cycle, but repository discovery is still required.

### Candidate

Recorded and potentially valuable, but not necessarily the next planning target.

### Blocked

A named dependency, architecture decision, fixture or preceding capability is missing.

### Bug

Verified behaviour that is incorrect and should be corrected.

### Maintenance

Bounded engineering or developer-workflow upkeep.

### Research

The problem is recorded, but architecture or product direction is not yet approved.

### Idea

A possible future direction without planning commitment.

---

## Sprint Selection Procedure

After the current ACTIVE sprint is completed and approved:

1. Read `PROJECT_STATE.md` and establish the verified repository baseline.

2. Review this document from the highest priority downward.

3. Exclude candidates whose dependencies remain unsatisfied.

4. Identify the highest-priority dependency-ready problems.

5. Determine whether related candidates may form one coherent sprint outcome.

6. Send Work an evidence-only repository-discovery task.

7. Work records:

   - verified current behaviour;
   - relevant production and test surfaces;
   - architectural constraints;
   - missing decisions;
   - risks;
   - whether candidates should combine or split.

8. Chat reviews the discovery report and relevant architecture evidence.

9. Chat selects one bounded sprint outcome.

10. Create or update an ADR when the selected work requires a new architectural decision.

11. Replace `Implementation.md` with the approved ACTIVE sprint contract.

12. Remove promoted work from this document.

No candidate is selected merely because it appears first. Dependencies, evidence, risk and user value remain controlling factors.

---

## Upcoming-Work Reporting Rule

When reporting future work:

- identify the current ACTIVE sprint from `Implementation.md`;
- describe future work only using candidates recorded here;
- distinguish Ready for discovery, Candidate, Blocked, Bug, Maintenance, Research and Idea;
- do not assign future sprint numbers;
- do not describe a candidate as approved implementation;
- clearly label any new suggestion that has not yet been added to this document.

A valid statement is:

> Candidate `<ID>` is recorded as `<Status>` with the dependencies listed in this document.

An invalid statement is:

> The next sprint will implement `<candidate>`.

The second statement becomes valid only after Chat formally defines and records that sprint in `Implementation.md`.

---

# P0 — Financial Integrity and Persistence Safety

## FW-P0-02 — Historical Duplicate Review and Repair

**Status:** Blocked  
**Depends on:** Completed Sprint 40 evidence and Sprint 41 bounded transaction-event ownership, plus an approved reversible financial-mutation model. Reversible financial mutation remains the controlling blocker.

Provide safe review and correction for duplicate transactions already present in durable history.

Candidate outcomes include:

- duplicate-candidate review;
- explanation of matching evidence;
- import-session and source provenance;
- financial-impact preview;
- explicit user confirmation;
- rollback or undo protection.

Historical data must never be silently changed.

**May combine with:** `FW-P1-25` and `FW-P2-12` if discovery shows that review and repair form one bounded outcome.

---

## FW-P0-05 — Concurrent Import Guarantees

**Status:** Ready for discovery
**Depends on:** Successful completion and approval of Sprints 40 and 41; discovery of broader cross-process, external-writer and race guarantees

Define and enforce deterministic behaviour for:

- simultaneous confirmations in one process;
- multiple application processes;
- external database writers;
- identity-resolution races;
- identifier-attachment races;
- duplicate-fingerprint claims;
- transaction-overlap races after Sprint 40 establishes transaction identity and overlap semantics.

Do not claim cross-process safety until it is implemented and tested.

---

## FW-P0-07 — Durable Import Audit Trail

**Status:** Candidate  
**Depends on:** Existing import-session and provenance foundations

Expand the durable data required to represent:

- successful imports;
- validation outcomes;
- persistence failures;
- duplicate rejection;
- account decisions;
- transaction counts;
- bounded source provenance;
- completion state.

Do not persist raw statement content, passwords or unredacted financial identifiers for presentation convenience.

---

## FW-P0-08 — Data-Integrity Verification and Repair

**Status:** Blocked  
**Depends on:** Approved repair and reversible-mutation contracts

Provide privacy-safe verification for:

- broken account relationships;
- missing import sessions;
- orphaned documents or fingerprints;
- identifier conflicts;
- duplicated transactions;
- incomplete imports;
- inconsistent completion states.

Repair actions must be explicit, previewed and recoverable.

---

# P0 — Financial Identity Safety

## FW-P0-10 — Explain Account Match, No-Match and Conflict Outcomes

**Status:** Candidate  
**Depends on:** Existing verified financial-identity flow

Explain why an import:

- matched an existing account;
- produced no match;
- required explicit account choice;
- became ambiguous;
- conflicted with existing identifier ownership.

Presentation must remain bounded and privacy-safe.

No raw financial identifier may be exposed.

---

## FW-P0-11 — Manual Account Linking and Unlinking

**Status:** Blocked  
**Depends on:** `FW-P0-10` and an approved identifier-ownership mutation contract

Allow explicit manual linking and unlinking beyond the current bounded account-choice workflow.

Required protections include:

- immutable repository account identity;
- explicit confirmation;
- identifier conflict detection;
- impact preview;
- preservation of transactions and import provenance;
- no identity decisions based solely on filenames, labels or display metadata.

---

## FW-P0-12 — Identifier Backfill Policy

**Status:** Ready for discovery  
**Depends on:** Existing verified parser identifiers and account resolution

Define when newly discovered verified strong identifiers may be attached to an already resolved account.

The policy must address:

- identifier ownership;
- conflict handling;
- idempotency;
- provenance;
- automatic versus user-confirmed attachment;
- recovery from incorrect attachment.

---

## FW-P0-13 — Incorrect-Link Recovery and Account Split

**Status:** Blocked  
**Depends on:** `FW-P0-11` and reversible financial mutations

Recover when transactions, import sessions or identifiers were attached to the wrong account.

Candidate outcomes include:

- moving an import session;
- detaching an incorrect identifier;
- separating incorrectly combined history;
- restoring previous relationships;
- recalculating affected account presentation safely.

No automatic account split is permitted.

---

## FW-P0-14 — Duplicate-Account Review

**Status:** Blocked  
**Depends on:** `FW-P0-10` and `FW-P0-11`

Present accounts that may represent the same real financial account.

The review must distinguish:

- verified shared identity;
- weak similarity;
- overlapping transaction history;
- coincidental display metadata.

Weak evidence must never establish identity automatically.

---

## FW-P0-15 — Manual Account Merge

**Status:** Blocked  
**Depends on:** `FW-P0-14`, reversible mutations and conflict-safe identifier reassignment

Provide a previewed manual merge that preserves:

- one selected immutable account identity;
- valid transactions;
- import-session provenance;
- verified identifiers;
- account metadata;
- rollback protection.

All conflicts must be surfaced before any write.

---

# P0 — Additional Integrity Foundations

## FW-P0-16 — Reversible Financial-Mutation Foundation

**Status:** Ready for discovery  
**Depends on:** Stable repository identity, provenance and persistence boundaries

Define the shared architecture required for explicit, reviewable and reversible changes to trusted financial history.

Candidate outcomes include:

- mutation plans that identify every affected durable record;
- financial-impact previews before destructive action;
- explicit user confirmation;
- audit records describing what changed and why;
- compensation or restoration semantics;
- provider parity between In-Memory and SQLite implementations;
- canonical runtime reconciliation after successful mutation;
- failure behaviour that never leaves silently half-applied financial changes.

This foundation must not itself authorize any particular merge, split, deletion, reversal or repair workflow.

Those product operations remain governed by their own candidates.

---

## FW-P0-17 — Legacy Exact-Statement Fingerprint Backfill and Review

**Status:** Blocked  
**Depends on:** Successful completion and approval of Sprint 39, plus an approved historical-review policy

Address statement history imported before Sprint 39, where no durable exact-content fingerprint exists.

Candidate outcomes include:

- identifying legacy import sessions that lack fingerprints;
- explaining why an existing statement cannot be proven identical from legacy metadata alone;
- optional user-reviewed fingerprint registration when the original source document is re-presented;
- preserving prospective-only Sprint 39 semantics;
- avoiding heuristic reconstruction from filenames, paths, account names, dates, balances or transactions.

Legacy history must never be silently fingerprinted from reduced repository data.

**May combine with:** `FW-P1-25` if discovery shows that legacy exact-statement review belongs inside one bounded duplicate-management experience.

---

## FW-P0-18 — Workspace-Scoped Fingerprint Uniqueness

**Status:** Blocked  
**Depends on:** `FW-P3-40` and an approved schema decision

Define exact-statement fingerprint ownership when one LedgerForge database contains more than one independent workspace.

The design must determine:

- whether exact-content uniqueness is workspace-scoped or database-wide;
- schema and migration requirements;
- treatment of identical source content imported into independent workspaces;
- conflict and migration behaviour for existing database-wide fingerprints;
- privacy and diagnostic boundaries.

The source digest must remain derived from source evidence rather than being altered merely to encode workspace identity.

---

## FW-P0-19 — Cross-Format Statement Duplicate Identity

**Status:** Blocked  
**Depends on:** Successful completion and approval of Sprint 40, `FW-P1-16` and production support for at least two equivalent source formats

Determine when equivalent CSV, PDF, XLS, XLSX or TXT representations describe the same statement even though their exact source bytes differ.

The solution must distinguish:

- exact-content duplicates;
- cross-format representations of one statement;
- genuinely revised statements;
- overlapping statements;
- coincidentally equivalent transaction sets.

Cross-format identity must remain deterministic, explainable and backed by approved fixtures.

It must not rely on filename similarity or silently discard an import because two transaction collections merely look alike.

---

## FW-P0-20 — Additional Transaction-Event Evidence Families

**Status:** Research
**Depends on:** Approved overlapping fixtures and family-specific deterministic reference, subtype, reuse, conflict and privacy semantics

Investigate additional transaction-event evidence families without expanding the bounded Axis UPI authority prematurely. Possible families include:

- IMPS;
- NEFT;
- e-commerce or card events;
- unstructured references;
- reversal;
- refund.

Each family may require a separate ADR and implementation increment. No family may reuse the Axis UPI algorithm identifier. Stable-looking tokens alone are insufficient; date, amount, narration, balance, filename and row position remain weak evidence. Missing evidence does not prove novelty, and no historical backfill is implied.

# P1 — Institution and Parser Expansion

## FW-P1-01 — Axis Bank Parser Family Expansion

**Status:** Candidate  
**Depends on:** Approved fixtures for each layout

Expand deterministic Axis coverage in dependency and fixture-readiness order:

1. additional NRE layouts;
2. NRO account layouts;
3. savings and current-account layouts;
4. credit-card statements;
5. historical or changed layouts.

Each supported layout requires:

- an approved fixture;
- expected financial truth;
- deterministic institution and parser-selection evidence;
- verified identifier evidence where available;
- regression protection.

Do not generalize the existing parser without fixture-backed evidence.

---

## FW-P1-02 — HDFC Parser Family

**Status:** Blocked  
**Depends on:** Approved HDFC fixtures and supported source formats

Support approved HDFC account and card statement families through the unified import pipeline.

---

## FW-P1-03 — CBQ Parser Family

**Status:** Blocked  
**Depends on:** Approved CBQ fixtures and supported source formats

Potential document families include:

- bank accounts;
- credit cards;
- investment or mutual-fund statements.

Each family requires its own approved financial baseline.

---

## FW-P1-04 — Additional Credit-Card Parser Families

**Status:** Idea  
**Depends on:** Approved institution-specific fixtures

Add card issuers only through deterministic, fixture-backed parser families.

Named compatibility targets include American Express and other issuers supported by future approved fixtures.

---

## FW-P1-05 — Brokerage, Mutual-Fund, Salary, Insurance, Tax and Government Document Families

**Status:** Research  
**Depends on:** Domain-model and product-scope decisions

Investigate support for:

- brokerage statements;
- mutual-fund statements and consolidated account statements;
- salary slips;
- insurance documents;
- tax documents;
- AIS and Form 16;
- other government financial records.

Determine whether each document family fits existing account and transaction models or requires a dedicated financial domain.

Do not force materially different financial documents into the bank-statement model merely to avoid designing the correct one.

---

## FW-P1-06 — Parser Framework Expansion

**Status:** Ready for discovery  
**Depends on:** Existing reader, parser-selection and `FinancialDocument` boundaries

Expand the internal parser framework so additional institutions, statement families and layout versions can be added without creating parallel import pipelines.

The framework must implement the accepted Import Profile direction rather than scattering institution-specific assumptions across unrelated components.

Candidate outcomes include:

- reusable Import Profiles;
- Import Profile versioning;
- deterministic layout recognition;
- explicit support for historical and changed layouts;
- shared fixture and regression conventions;
- bounded source-evidence contracts;
- parser-family organization by institution and document type.

Readers remain responsible for source-format extraction.

Parsers remain responsible for financial interpretation.

This candidate concerns internal application architecture. External third-party plugins remain governed separately by `FW-P3-39`.

---

## FW-P1-07 — Statement Learning Mode and Profile Library

**Status:** Research  
**Depends on:** `FW-P1-06`, approved Import Profile semantics and privacy boundaries

Investigate an offline-first workflow that helps LedgerForge recognize new or changed statement layouts while preserving deterministic parsing.

Candidate outcomes include:

- a versioned local Import Profile library;
- explicit profile provenance and compatibility information;
- user-reviewed profile creation or refinement;
- fixture generation from approved, privacy-safe evidence;
- compatibility with historical layouts;
- rollback to an earlier profile version;
- clear separation between learned suggestions and production-approved parser behaviour.

Learning must never silently promote an unreviewed profile into trusted financial parsing.

---

## FW-P1-08 — AI-Assisted Column Detection

**Status:** Research  
**Depends on:** `FW-P1-06`, editable import provenance and deterministic validation boundaries

Investigate AI-assisted suggestions for identifying dates, descriptions, debit, credit, amount, currency and balance columns in unsupported tabular statements.

Any assistance must remain:

- advisory;
- reviewable;
- explainable;
- local or explicitly opt-in where external processing would be required;
- validated before persistence;
- unable to override approved deterministic parser behaviour.

The original source structure and every user-approved mapping must remain inspectable.

---

# P1 — Import Format Expansion

## FW-P1-10 — Production PDF Statement Support

**Status:** Ready for discovery  
**Depends on:** Approved PDF fixture and existing extraction foundation

Promote PDF from extraction foundation to a production-supported import source.

Required outcome:

- approved PDF content enters the unified pipeline;
- institution detection and classification remain deterministic;
- parser output matches approved financial truth;
- equivalent statements preserve equivalent financial results.

---

## FW-P1-11 — Password-Protected PDF Support

**Status:** Blocked  
**Depends on:** `FW-P1-10` and an approved password workflow

Support encrypted PDF statements through the existing password-provider boundary.

Readers must not access UI prompts, Keychain or institution-specific password policy directly.

---

## FW-P1-12 — Secure Institution Password Storage

**Status:** Blocked  
**Depends on:** `FW-P1-11` and a security review

Store institution-specific credentials using macOS Keychain.

Requirements include:

- offline-first operation;
- no passwords in SQLite;
- no passwords in diagnostics;
- explicit user control;
- secure update and deletion;
- privacy-focused tests.

---

## FW-P1-13 — Per-File Password Override and Entry

**Status:** Blocked  
**Depends on:** `FW-P1-11`

Allow manual password entry when no stored credential succeeds.

The user must control whether the password is used once, stored, replaced or discarded.

---

## FW-P1-14 — XLS and XLSX Support

**Status:** Blocked  
**Depends on:** Approved spreadsheet fixtures

Add spreadsheet readers that feed the existing universal import pipeline.

XLS and XLSX may become separate sprint candidates if discovery shows materially different implementation or validation boundaries.

---

## FW-P1-15 — TXT Statement Support

**Status:** Idea  
**Depends on:** Approved TXT fixtures

Support deterministic text statements through the existing pipeline.

---

## FW-P1-16 — Cross-Format Financial Equivalence

**Status:** Blocked  
**Depends on:** At least two production-supported formats for the same statement family

Verify equivalent statements produce equivalent:

- institution;
- account identity;
- transactions;
- transaction ordering;
- debit and credit totals;
- balances;
- validation outcomes.

Extraction differences must not change financial truth.

---

## FW-P1-17 — OCR Fallback

**Status:** Research  
**Depends on:** Production PDF support and approved human-review boundaries

Investigate scanned or image-only statements.

OCR output remains untrusted until deterministic parsing and validation succeed.

---

## FW-P1-18 — Binary-Document Fingerprint Semantics

**Status:** Research  
**Depends on:** Production support for at least one binary source path

Define deterministic fingerprint input for binary documents when reader-produced text is absent, incomplete or unsuitable as the exact-content authority.

The design must address:

- whether bytes, normalized container content or another stable representation is authoritative;
- encrypted and password-protected documents;
- metadata that may change without changing statement content;
- format-specific container differences;
- compatibility with versioned fingerprint algorithms;
- privacy-safe diagnostics;
- migration and coexistence with `ledgerforge.raw-text.sha256.v1`.

Binary fingerprinting must not be inferred from parsed transactions or presentation metadata.

---

# P1 — Import Workflow

## FW-P1-19 — Complete Multi-Step Import Wizard

**Status:** Candidate  
**Depends on:** Existing confirmation-gated Import Wizard foundation

Complete the Import Wizard as the primary user-facing workflow for preparing, reviewing, confirming and understanding imports.

The complete workflow may incorporate selected candidates from this section, including:

- batch import;
- multi-file drag and drop;
- editable preview;
- correction and revalidation;
- account-match review;
- duplicate review;
- progress, cancellation and retry;
- actionable validation guidance;
- completed import outcome and history navigation.

This is an umbrella product outcome, not permission to combine every listed capability into one sprint.

Repository discovery must determine which related candidates form each bounded implementation increment.

This candidate also provides the bounded foundation for the longer-term Import Studio direction without turning importing into the application’s primary experience.

---

## FW-P1-20 — Batch Import

**Status:** Blocked  
**Depends on:** Mature duplicate handling, cancellation boundaries and failure isolation

Import multiple files while preserving independent:

- validation;
- confirmation;
- account choice;
- duplicate outcome;
- persistence result;
- provenance.

A failure in one file must not silently affect another.

---

## FW-P1-21 — Multi-File Drag-and-Drop Import Centre

**Status:** Blocked  
**Depends on:** `FW-P1-20`

Provide queue visibility, progress, result states and navigation for multiple files.

---

## FW-P1-22 — Editable Import Preview

**Status:** Blocked  
**Depends on:** An approved correction and provenance model

Allow bounded correction before persistence without obscuring the distinction between:

- imported source values;
- normalized values;
- user corrections;
- derived financial values.

Every correction must remain explainable and auditable.

---

## FW-P1-23 — Import Correction Workflow

**Status:** Blocked  
**Depends on:** `FW-P1-22` and durable correction provenance

Provide deterministic correction and revalidation before persistence.

---

## FW-P1-24 — Account-Match Review and Manual Override

**Status:** Blocked  
**Depends on:** Identity explanation and manual linking policies

Extend account choice beyond the bounded no-match workflow while preserving verified identity ownership and explicit user control.

---

## FW-P1-25 — Duplicate-Import Review and Management

**Status:** Ready for discovery
**Depends on:** Successful completion and approval of Sprints 39, 40 and 41

Provide review for:

- exact duplicate rejection;
- overlap detection;
- ambiguous duplicate candidates;
- historical duplicate repair.

Review, management, historical repair, override and partial-import workflows remain unimplemented.

---

## FW-P1-26 — Global Import-Session History

**Status:** Candidate  
**Depends on:** Durable audit-trail support

Provide the user-facing global history and management experience backed by `FW-P0-07` for:

- successful imports;
- failed imports;
- duplicate outcomes;
- account-associated sessions;
- sessions without a durable account relationship.

---

## FW-P1-27 — Delete or Reverse an Import Session

**Status:** Blocked  
**Depends on:** Reversible financial mutations and impact preview

Safely reverse one import without damaging unrelated account history.

---

## FW-P1-28 — Import Progress, Cancellation and Retry

**Status:** Ready for discovery  
**Depends on:** Clearly defined persistence and cancellation boundaries

Provide accurate progress and safe cancellation without claiming rollback beyond supported persistence guarantees.

---

## FW-P1-29 — Better Validation Guidance

**Status:** Candidate  
**Depends on:** Existing validation pipeline

Present actionable, user-facing guidance while preserving detailed developer diagnostics separately.

---

## FW-P1-29A — Historical Backfill Import Workflow

**Status:** Blocked  
**Depends on:** Mature duplicate handling, statement continuity and reversible repair foundations

Support deliberate import of older financial history without corrupting current account continuity or duplicating already represented activity.

Candidate outcomes include:

- account-scoped historical import ranges;
- clear distinction between backfill and ordinary current-period importing;
- statement coverage previews;
- overlap and gap explanation;
- controlled handling of legacy un-fingerprinted history;
- impact preview before persistence;
- provenance identifying each backfill source;
- cancellation and failure isolation.

Historical backfill must not assume that older statements are complete or that import order determines final financial truth.

---

# P1 — Verified Bugs and Developer Maintenance

## BUG-P1-01 — Development Database Reset Does Not Persist Across Relaunch

**Status:** Bug  
**Depends on:** None

The development reset switches the running application to a temporary database, but startup bootstrap reconnects to the primary development database on relaunch.

The correction must preserve production-database safety.

---

## FW-P1-30 — Granular Development Database Reset

**Status:** Blocked  
**Depends on:** `BUG-P1-01`

Candidate reset operations include:

- transactions only;
- import sessions only;
- financial identity only;
- repository financial data;
- complete development factory reset.

Each operation must clearly state what is retained and removed.

---

## FW-P1-31 — Repository Inspector

**Status:** Candidate  
**Depends on:** Privacy-safe developer presentation

---

## FW-P1-32 — Development SQLite Browser

**Status:** Research  
**Depends on:** Development-only access and privacy controls

---

## FW-P1-33 — Import-Session Inspector

**Status:** Candidate  
**Depends on:** Durable import audit trail

---

## FW-P1-34 — Parser and Source-Evidence Inspector

**Status:** Research  
**Depends on:** Privacy-safe source-evidence redaction

Source inspection must never expose passwords or unredacted financial identifiers.

---

## FW-P1-35 — Duplicate and Identity-Conflict Inspector

**Status:** Blocked  
**Depends on:** Approved duplicate and conflict semantics

---

## FW-P1-36 — Diagnostic Export

**Status:** Candidate  
**Depends on:** Privacy filtering and explicit user action

---

## FW-P1-37 — Better Developer Diagnostics and Failure Summaries

**Status:** Candidate  
**Depends on:** Existing structured diagnostic system

---

## FW-P1-38 — Import Inspector and Validation Timeline

**Status:** Blocked  
**Depends on:** `FW-P0-07`

Provide development-only inspection of an import’s progression through:

- source reading;
- institution detection;
- statement classification;
- parser selection;
- financial parsing;
- validation;
- user confirmation;
- duplicate evaluation;
- account decision;
- persistence;
- hydration.

The inspector may include a validation timeline showing issues and outcomes in deterministic order.

It must not expose:

- passwords;
- raw financial identifiers;
- unrestricted source fragments;
- production-only sensitive information.

This candidate complements, but does not replace, the user-facing global import history in `FW-P1-26`.

---

## FW-P1-39 — Development Database Maintenance Utilities

**Status:** Research  
**Depends on:** Stable database lifecycle, backup and integrity-verification boundaries

Investigate safe development-only utilities for:

- opening the active database folder;
- exporting a SQLite snapshot;
- database vacuum or optimization;
- repository rebuild;
- balance recalculation;
- search reindexing.

Each operation requires an explicit safety contract, scope description and validation strategy.

No maintenance operation may silently alter trusted financial history or run against an active import without safe coordination.

Production user-facing repair remains governed by `FW-P0-08`.

---

## FW-P1-39A — Persistent Developer Diagnostic History

**Status:** Research  
**Depends on:** A new ADR replacing or extending ADR-026’s in-memory-only diagnostic constraint

Investigate an optional development-only diagnostic history that survives relaunch.

The design must define:

- explicit enablement and retention limits;
- privacy filtering;
- log rotation and deletion;
- separation from repository financial truth;
- protection from passwords, raw financial identifiers and unrestricted source fragments;
- export compatibility;
- deterministic ordering and schema evolution.

Persistent diagnostics must not become an application persistence mechanism or a substitute for import-session audit history.

---

# P2 — Transaction Experience and Reconciliation

## FW-P2-01 — Transaction Source and Provenance View

**Status:** Candidate  
**Depends on:** Trusted document and import-session relationships

Show the account, source document and import session from which a transaction originated.

---

## FW-P2-02 — Improved Transaction Detail Layout

**Status:** Candidate  
**Depends on:** None

Use the available detail space more effectively and remove developer-oriented terminology.

---

## FW-P2-03 — Advanced Transaction Search

**Status:** Candidate  
**Depends on:** Stable transaction fields

---

## FW-P2-04 — Saved Transaction Filters

**Status:** Blocked  
**Depends on:** `FW-P2-03`

---

## FW-P2-05 — Transaction Multi-Selection

**Status:** Candidate  
**Depends on:** Approved bulk-action boundaries

---

## FW-P2-06 — Bulk Transaction Actions

**Status:** Blocked  
**Depends on:** `FW-P2-05` and reversible mutation support

Potential actions include notes, categories, rules and safe deletion or exclusion.

---

## FW-P2-07 — Delete Transactions by Import Session

**Status:** Blocked  
**Depends on:** Safe import-session reversal

---

## FW-P2-08 — Undo Support

**Status:** Research  
**Depends on:** Reversible repository history

---

## FW-P2-09 — Transaction Notes

**Status:** Candidate  
**Depends on:** Targeted transaction metadata mutation

---

## FW-P2-10 — Transfer Matching Between Owned Accounts

**Status:** Blocked  
**Depends on:** Reliable multi-account identity and successful completion and approval of Sprint 40

Match both sides of owned-account transfers without counting them as income or expense.

Matching must be explainable and reversible.

---

## FW-P2-11 — Reconciliation Workflow

**Status:** Blocked  
**Depends on:** `FW-P2-10` and transaction provenance

---

## FW-P2-12 — Duplicate-Transaction Review

**Status:** Ready for discovery
**Depends on:** Completed Sprint 40 overlap evidence and Sprint 41 bounded transaction-event enforcement

Duplicate-transaction review remains unimplemented and is separate from Sprint 41 bounded enforcement.

---

# P2 — Categories, Rules and Automation

## FW-P2-20 — Category Model and Management

**Status:** Ready for discovery  
**Depends on:** Stable transaction model

Define:

- category identity;
- hierarchy;
- user-created categories;
- uncategorized state;
- deletion and reassignment behaviour.

This must precede automatic categorization.

---

## FW-P2-21 — Deterministic Categorization Rules

**Status:** Blocked  
**Depends on:** `FW-P2-20`

---

## FW-P2-22 — Explainable Rule Results

**Status:** Blocked  
**Depends on:** `FW-P2-21`

Every automatic categorization must explain the rule that produced it.

---

## FW-P2-23 — Rule Priority and Conflict Handling

**Status:** Blocked  
**Depends on:** `FW-P2-21`

---

## FW-P2-24 — User Corrections as Reusable Rules

**Status:** Blocked  
**Depends on:** `FW-P2-21` through `FW-P2-23`

---

## FW-P2-25 — Merchant and Payee Normalization

**Status:** Blocked  
**Depends on:** Stable correction and provenance rules

The original imported transaction description must remain preserved.

---

## FW-P2-26 — Recurring Transaction and Subscription Detection

**Status:** Blocked  
**Depends on:** Reliable duplicate handling and normalized payee evidence

---

## FW-P2-27 — Automatic Transaction Classification

**Status:** Blocked  
**Depends on:** Category, rule, normalization and explanation foundations

Deterministic rules take precedence over AI-assisted suggestions.

---

## FW-P2-28 — Smart Deterministic Alerts

**Status:** Blocked  
**Depends on:** Categorization, recurring detection or another approved rule source

---

## FW-P2-29 — Explainable Rules Engine v2

**Status:** Blocked  
**Depends on:** Stable category, transaction, account, provenance and reversible-action models

Define a general deterministic rules engine for explainable financial automation beyond categorization alone.

Candidate capabilities may include:

- multi-condition rules;
- explicit priority and conflict resolution;
- dry-run previews;
- account, transaction, merchant, amount, date and recurrence predicates;
- actions that never alter original imported financial truth;
- complete reasoning and provenance for every result;
- user-controlled enablement, disabling and rollback;
- testable rule versioning.

Rules must remain deterministic before any AI-assisted suggestion layer is considered.

---

# P2 — Account Lifecycle and Presentation

## FW-P2-30 — Broader Account Metadata Editing

**Status:** Candidate  
**Depends on:** Existing targeted display-name mutation

Define the targeted repository mutation, validation and hydration foundation required for editable account metadata beyond display name while preserving immutable account identity, identifiers, sessions and transactions.

Field-specific product work remains separately tracked in `FW-P2-31`, `FW-P2-32` and `FW-P2-36`.

---

## FW-P2-31 — Account Notes

**Status:** Blocked  
**Depends on:** `FW-P2-30`

---

## FW-P2-32 — Account Colour and Icon Customization

**Status:** Candidate  
**Depends on:** Stable account presentation model

---

## FW-P2-33 — Institution Logos

**Status:** Candidate  
**Depends on:** Approved asset and institution-mapping strategy

---

## FW-P2-34 — Archive and Restore Account

**Status:** Ready for discovery  
**Depends on:** Existing targeted account-mutation and repository-identity foundations

Discovery must define account lifecycle semantics, visibility effects and restoration behaviour.

Archiving must not delete financial history.

---

## FW-P2-35 — Hide Account Without Deleting History

**Status:** Candidate  
**Depends on:** Account visibility semantics

---

## FW-P2-36 — Close-Account Status and Closure Date

**Status:** Blocked  
**Depends on:** `FW-P2-30`

---

## FW-P2-37 — Account Grouping, Ordering and Favourites

**Status:** Candidate  
**Depends on:** Stable complete-account collection

Support user-defined or deterministic grouping while preserving immutable account identity and complete account visibility.

---

## FW-P2-38 — Full Account Transaction-History Navigation

**Status:** Candidate  
**Depends on:** Existing account-scoped activity foundation

---

# P2 — User Experience

## FW-P2-40 — Replace Developer Terminology in User-Facing Screens

**Status:** Candidate  
**Depends on:** None

---

## FW-P2-41 — Consistent Toolbar Composition

**Status:** Candidate  
**Depends on:** None

---

## FW-P2-42 — Remove Noisy Pending and Soon Placeholders

**Status:** Candidate  
**Depends on:** None

---

## FW-P2-43 — Better Account Icons

**Status:** Candidate  
**Depends on:** Account presentation strategy

Improve default account iconography. User customization remains governed by `FW-P2-32`, while institution logos remain governed by `FW-P2-33`.

---

## FW-P2-44 — Dashboard Customization

**Status:** Idea  
**Depends on:** Stable dashboard modules

---

## FW-P2-45 — Improved Global Search

**Status:** Candidate  
**Depends on:** Stable searchable domains

---

## FW-P2-46 — Interactive Dashboard Charts

**Status:** Candidate  
**Depends on:** Reliable analytical data sources

---

## FW-P2-47 — Better Empty States and Import Guidance

**Status:** Candidate  
**Depends on:** None

---

## FW-P2-48 — Hover, Spacing and Visual Polish

**Status:** Candidate  
**Depends on:** Stable primary layouts

---

## FW-P2-49 — Accessibility Review

**Status:** Candidate  
**Depends on:** Stable primary workflows

---

## FW-P2-50 — Keyboard Navigation and Shortcuts

**Status:** Candidate  
**Depends on:** Stable primary workflows

---

## FW-P2-51 — Startup, Runtime and Import Performance Optimization

**Status:** Research  
**Depends on:** Measured performance evidence and representative fixtures

Measure and improve:

- application startup;
- repository hydration;
- large account and transaction presentation;
- import preparation and confirmation;
- large-statement parsing;
- search and filtering.

A splash or launch-progress experience may be considered only when measured startup delay justifies one.

Do not optimize without benchmarks.

---

## FW-P2-52 — User and Workspace Preferences

**Status:** Ready for discovery  
**Depends on:** Existing settings presentation and `WorkspaceSettings` domain direction

Define durable, privacy-safe preferences for:

- date and time formatting;
- regional number formatting;
- base and secondary display currencies;
- default import behaviour;
- dashboard presentation choices;
- account and transaction display preferences;
- developer-mode separation from ordinary user settings.

Preference changes must not rewrite imported financial truth.

---

## FW-P2-53 — Contextual Date-Range and Filter Controls

**Status:** Candidate  
**Depends on:** Stable date semantics and searchable presentation domains

Implement the frozen contextual-toolbar direction for date range, filters and other page-specific controls.

The controls must:

- affect only the active presentation domain;
- make their scope visible;
- preserve deterministic results;
- remain keyboard accessible;
- avoid implying unsupported analytics or repository mutations.

---

## FW-P2-54 — Document Library and Source-Document Browsing

**Status:** Blocked  
**Depends on:** Durable document provenance, privacy-safe metadata and import-session history

Provide a user-facing place to inspect imported source-document records and their relationships to:

- accounts;
- import sessions;
- statement periods;
- transactions;
- validation and duplicate outcomes.

The library must not expose raw source content by default and must not treat a document record as the owner of account identity.

---

## FW-P2-55 — Light Mode Design Revision

**Status:** Idea  
**Depends on:** Approved design review, updated frozen UI specification and revised UI assets

Investigate a complete Light Mode visual system without weakening the current Deep Indigo dark-mode baseline.

Implementation may begin only after design tokens, contrast requirements, approved assets and acceptance criteria are updated.

---

## FW-P2-56 — Development Performance Profiling

**Status:** Research  
**Depends on:** Privacy-safe developer tooling and measured performance questions

Provide development-only profiling for:

- startup;
- repository hydration;
- parser and validation stages;
- persistence;
- import completion;
- large-view rendering;
- search and filtering.

Profiling output must remain separate from financial truth and must not retain sensitive source content.

---

# P2 — Engineering Quality

## FW-P2-61 — Institution, Layout and Format Regression Matrix

**Status:** Blocked  
**Depends on:** Additional supported fixtures

---

## FW-P2-62 — Direct Cancellation-Handler Tests

**Status:** Candidate  
**Depends on:** Existing confirmation workflow

---

## FW-P2-63 — Cross-Format Fixture-Parity Tests

**Status:** Blocked  
**Depends on:** Multiple production-supported formats

---

## FW-P2-64 — Large-Statement and Long-Running Import Tests

**Status:** Candidate  
**Depends on:** Representative large fixtures

---

## FW-P2-65 — Repository Corruption and Recovery Tests

**Status:** Research  
**Depends on:** Successful completion and approval of Sprint 41

---

## FW-P2-66 — Privacy Regression Tests

**Status:** Candidate  
**Depends on:** None

Protect against raw identifiers, passwords and source fragments entering presentation or diagnostics.

---

# P3 — Identity Enhancements

## FW-P3-01 — Identifier Confidence Scoring

**Status:** Research  
**Depends on:** Approved non-authoritative evidence policy

Confidence must never silently promote weak evidence into verified identity.

---

## FW-P3-02 — Identifier Aliases and Alternate Institution Identifiers

**Status:** Research  
**Depends on:** Identifier ownership and conflict semantics

---

## FW-P3-03 — User-Visible Identity History

**Status:** Idea  
**Depends on:** Durable identity provenance

---

## FW-P3-04 — Administrative Identifier Correction

**Status:** Research  
**Depends on:** Reversible identity mutations and audit history

---

## FW-P3-05 — Identity Provenance Timeline

**Status:** Idea  
**Depends on:** Durable identity history

---

# P3 — Financial Intelligence and Planning

## FW-P3-06 — Financial Intelligence Engine

**Status:** Research  
**Depends on:** Reliable financial truth, provenance, rules and explanation foundations

Define the architecture for deterministic, auditable financial conclusions that operate above imported source data.

The engine may coordinate:

- account and transaction relationships;
- recurring activity;
- transfers;
- salary;
- obligations;
- investments;
- multi-currency reporting;
- anomaly and change detection;
- planning and forecasting.

Every conclusion must identify its supporting evidence, deterministic rules and limitations.

The engine must not become a black-box source of financial truth.

---

## FW-P3-07 — Financial Replay, Timeline and Money-Journey Reconstruction

**Status:** Blocked  
**Depends on:** Reliable transaction identity, transfer matching, provenance and financial-intelligence foundations

Reconstruct how money moved through the user’s financial entities over time.

Candidate outcomes include:

- a Financial Timeline;
- replay of income, transfers, spending and investment funding;
- explanation of what changed net worth;
- chains showing movement between owned accounts;
- links back to supporting transactions, statements and import sessions;
- deterministic handling of corrected or reversed history.

Internal transfers must never be presented as new income or expense.

---

## FW-P3-08 — Salary and Planning Workspace

**Status:** Blocked  
**Depends on:** Salary-slip support, reliable transaction identity, account relationships and planning-domain decisions

Create the monthly Salary & Planning workspace described by Product Vision.

Candidate outcomes include:

- expected salary and actual salary comparison;
- salary-slip verification;
- configurable monthly allocation planning;
- planned transfers between accounts;
- credit-card funding plans;
- savings and investment contribution plans;
- explicit user review before any action;
- variance explanation after actual transactions arrive.

This module requires an approved UI revision because it is not part of the current frozen v1.0 screen inventory.

---

## FW-P3-09 — Upcoming Obligations and Cash-Flow Planning

**Status:** Blocked  
**Depends on:** Recurring-transaction detection, reliable categories, account balances and planning semantics

Present upcoming financial obligations such as:

- bills;
- subscriptions;
- expected credit-card payments;
- loan payments;
- recurring transfers;
- planned investments;
- other known commitments.

Cash-flow planning must distinguish confirmed obligations, deterministic projections and user-entered assumptions.

No prediction may be presented as a guaranteed future transaction.

---

# P3 — Analytics, Budgets and Reports

These candidates remain blocked until transaction integrity, account identity and source coverage are sufficiently mature.

## FW-P3-10 — Spending Analytics

**Status:** Blocked  
**Depends on:** Reliable duplicate handling and categorization

Includes:

- spending timelines;
- monthly and yearly trends;
- category breakdowns.

---

## FW-P3-11 — Budgets

**Status:** Blocked  
**Depends on:** Stable categorization and analytics

---

## FW-P3-12 — Financial Goals

**Status:** Blocked  
**Depends on:** Stable reporting model

---

## FW-P3-13 — Forecasting

**Status:** Research  
**Depends on:** Reliable historical data and approved explainability standards

---

## FW-P3-14 — Smart Alerts

**Status:** Blocked  
**Depends on:** Reliable categories, rules or forecasting inputs

---

## FW-P3-15 — Custom Reports

**Status:** Blocked  
**Depends on:** Stable analytics

---

## FW-P3-16 — Tax Views

**Status:** Research  
**Depends on:** Jurisdiction and supported-data decisions

---

## FW-P3-17 — CSV and Report Export

**Status:** Candidate  
**Depends on:** Export schema and privacy policy

Provide user-facing exports of reports and selected financial views. Full machine-readable domain export remains governed by `FW-P3-35`.

---

## FW-P3-18 — Net-Worth History

**Status:** Blocked  
**Depends on:** Multi-account, investment and multi-currency foundations

---

## FW-P3-19 — Salary-Slip Verification Against Imported Transactions

**Status:** Blocked  
**Depends on:** Salary-slip document support, reliable account identity and transaction reconciliation semantics

Use imported salary-slip data to help verify corresponding bank transactions.

Candidate outcomes include:

- identifying likely salary-credit transactions;
- comparing gross, net and deduction information where supported;
- explaining date or amount mismatches;
- preserving the original statement and salary-slip records independently;
- requiring explicit review for ambiguous matches.

A salary slip must not silently create, modify or replace a bank transaction.

---

## FW-P3-19A — Liabilities, Loans and Financial Health

**Status:** Research  
**Depends on:** Liability domain models, reliable account balances, obligations and multi-currency reporting

Support durable representation and understandable presentation of:

- loans;
- credit obligations;
- repayment schedules;
- outstanding principal;
- interest and fees;
- liquidity;
- debt burden;
- emergency-fund coverage;
- other explainable financial-health indicators.

Financial-health conclusions must show the underlying deterministic calculation and must not be presented as regulated financial advice.

---

# P3 — Investments and Wealth

## FW-P3-20 — Mutual-Fund Holdings

**Status:** Research  
**Depends on:** Investment domain model and approved fixtures

---

## FW-P3-21 — ETF and Stock Holdings

**Status:** Research  
**Depends on:** Investment domain model and approved fixtures

---

## FW-P3-22 — Brokerage Support Including IBKR

**Status:** Research  
**Depends on:** Brokerage parsing and account-identity decisions

---

## FW-P3-23 — Folio and Broker Identifier Support

**Status:** Research  
**Depends on:** Investment identity architecture

---

## FW-P3-24 — Portfolio Timeline and Performance

**Status:** Blocked  
**Depends on:** Reliable holdings and investment-transaction history

---

## FW-P3-25 — Asset Allocation

**Status:** Blocked  
**Depends on:** Reliable holdings

---

## FW-P3-26 — Net-Worth Integration

**Status:** Blocked  
**Depends on:** Investments and multi-currency reporting

---

## FW-P3-27 — Optional Market-Data Refresh

**Status:** Research  
**Depends on:** Investment model and offline-first cache policy

Support optional market-data refresh while preserving:

- offline access to existing portfolio history;
- versioned and dated valuation evidence;
- explicit failure and staleness states;
- user control over providers and refresh;
- manual price fallback for unsupported or unresolved holdings;
- custom-fund price entry where no automatic source is suitable.

Online market data remains optional. Core portfolio history must remain usable offline.

---

## FW-P3-28 — Manual Holdings and Custom-Fund Valuation

**Status:** Research  
**Depends on:** Investment domain model, valuation provenance and reversible editing

Support holdings that cannot be fully reconstructed from imported brokerage documents or market-data providers.

Candidate outcomes include:

- manual holding creation;
- units and contribution entries;
- dated manual valuations;
- custom fund or security definitions;
- correction history;
- clear separation between imported, fetched and user-entered evidence;
- explicit valuation staleness.

Manual entries must never overwrite imported source records.

---

## FW-P3-29 — Retirement and ISP Tracking

**Status:** Research  
**Depends on:** Investment, contribution, employer-benefit and planning-domain models

Support retirement and employer-sponsored investment plans, including ISP-style arrangements.

Candidate outcomes include:

- employee contributions;
- employer contributions;
- voluntary contributions;
- multiple plan portfolios;
- allocation history;
- contribution and vesting rules where supported;
- current value and performance;
- links to salary and planning workflows.

Rules must be explainable and configurable rather than inferred from institution labels alone.

---

# P3 — Multi-Currency and Ecosystem

## FW-P3-29A — Money Value Type and Multi-Currency Domain Foundation

**Status:** Ready for discovery  
**Depends on:** Existing native-currency preservation and ADR-008

Define the dedicated `Money` value type and supporting domain contracts required for reliable multi-currency behaviour.

The foundation must preserve:

- native amount and currency;
- deterministic arithmetic rules;
- prevention of accidental cross-currency arithmetic;
- locale-independent stored values;
- locale-aware presentation;
- derived rather than destructive conversion;
- provider and test compatibility;
- migration strategy for existing models where required.

This candidate establishes domain correctness. Exchange-rate storage and reporting remain separate candidates.

---

## FW-P3-30 — Multi-Currency Account and Transaction Presentation

**Status:** Blocked  
**Depends on:** `FW-P3-29A`

Present native and derived monetary values using locale-aware formatting, including:

- correct currency symbols and codes;
- regional decimal and grouping rules;
- Indian digit grouping where appropriate;
- international grouping where appropriate;
- simultaneous base and secondary display currencies where approved;
- visible distinction between native and converted amounts.

---

## FW-P3-31 — Exchange-Rate Storage

**Status:** Research  
**Depends on:** Approved rate-source and offline-cache policy

---

## FW-P3-32 — Historical FX Conversion

**Status:** Blocked  
**Depends on:** `FW-P3-31`

---

## FW-P3-33 — User-Selectable Reporting Currency

**Status:** Blocked  
**Depends on:** `FW-P3-31` and `FW-P3-32`

---

## FW-P3-34 — Currency-Aware Analytics and Net Worth

**Status:** Blocked  
**Depends on:** Analytics and reporting-currency foundations

---

## FW-P3-35 — Structured Data Export

**Status:** Candidate  
**Depends on:** Export schema and privacy policy

Provide a machine-readable export of supported LedgerForge domain data. User-facing report and selected-view exports remain governed by `FW-P3-17`.

---

## FW-P3-36 — Verified Backup, Restore and Disaster Recovery

**Status:** Candidate  
**Depends on:** Stable database lifecycle and integrity-verification foundations

Provide:

- explicit local backup creation;
- backup integrity verification;
- documented backup contents and exclusions;
- restore preview and confirmation;
- tested restoration into a safe target;
- version and schema compatibility checks;
- failure-safe recovery;
- disaster-recovery guidance;
- clear separation from optional synchronization.

A backup is not considered trustworthy merely because a file was copied.

---

## FW-P3-37 — Optional Encrypted Sync

**Status:** Research  
**Depends on:** Backup, encryption, conflict resolution and explicit opt-in architecture

LedgerForge must remain fully functional without synchronization.

---

## FW-P3-38 — Open API and External Integrations

**Status:** Research  
**Depends on:** Stable public data contracts and security policy

---

## FW-P3-39 — External Import Plugin Architecture

**Status:** Research  
**Depends on:** Stable parser, reader, fixture, security and public extension contracts

Investigate an optional plugin architecture for adding financial institutions, document families or import adapters without modifying LedgerForge’s core application.

The design must preserve:

- offline-first operation;
- privacy by default;
- deterministic parsing;
- validation before persistence;
- explicit plugin trust and installation controls;
- compatibility and versioning rules;
- isolation from repository and credential internals.

Internal parser-framework expansion remains governed separately by `FW-P1-06`.

No external plugin system is approved until its security, signing, compatibility and data-access boundaries are defined.

---

## FW-P3-40 — Multiple Workspaces and Independent Ledgers

**Status:** Research  
**Depends on:** Workspace-scoped identity, fingerprint, settings and repository-isolation decisions

Investigate support for more than one independent local financial workspace.

The design must define:

- strict data isolation;
- workspace-scoped account identity;
- workspace-scoped preferences;
- workspace selection and creation;
- import routing;
- fingerprint uniqueness;
- backup and restore boundaries;
- deletion and archival;
- migration from the current single-workspace product model.

No cross-workspace matching or aggregation may occur implicitly.

---

## FW-P3-41 — Portable Workspace Folder

**Status:** Research  
**Depends on:** `FW-P3-36`, workspace isolation and safe coordination of external file changes

Investigate storing or exporting a complete LedgerForge workspace in a user-selected local folder that may itself be synchronized by services such as iCloud Drive, OneDrive, Dropbox or Synology tools.

LedgerForge must remain offline-first and must not depend on any cloud provider.

The design must address:

- atomic local writes;
- conflict detection;
- concurrent external modifications;
- locking;
- backup and recovery;
- file permissions;
- sandbox access;
- explicit user control.

---

## FW-P3-42 — Cross-Platform Desktop Strategy

**Status:** Research  
**Depends on:** Stable public domain, persistence and presentation boundaries

Evaluate whether LedgerForge should eventually support Windows or Linux while preserving macOS as the primary product.

The research must distinguish:

- reusable domain and repository layers;
- Swift and SwiftUI platform constraints;
- storage and Keychain equivalents;
- native desktop interaction expectations;
- testing and release cost;
- whether a separate client or shared core is justified.

No portability claim may be made without an approved architecture and working evidence.

---

## FW-P3-43 — Local-Data Encryption at Rest

**Status:** Research  
**Depends on:** Database lifecycle, backup, credential and recovery architecture

Investigate encryption of LedgerForge financial data at rest.

The design must address:

- key ownership and storage;
- unlock and recovery;
- backup encryption;
- migration of existing databases;
- performance;
- development and testing workflows;
- loss-of-key consequences;
- interaction with portable workspaces and optional sync;
- explicit user understanding.

Encryption must not create a false promise of security while leaving exported backups or diagnostics unprotected.

---

# Research Queue

Items in this section are not implementation candidates until promoted into a priority section. Research already promoted into a numbered candidate is not repeated here.

## Import and Parsing Research

- semi-automated parser generation from approved fixtures;
- AI-assisted recovery for unsupported or ambiguous layouts beyond column detection;
- shared parser evidence across CSV, PDF, XLS, XLSX and TXT.

## Persistence Research

- long-term mutation-history compaction and archival after `FW-P0-16`.

## Financial Intelligence Research

- explainable recommendations;
- anomaly detection;
- tax and regulatory assistance.

Research findings must not be reported as planned product work until they are promoted into the prioritized queue.

---

## Maintenance Rules

When editing this document:

- preserve existing candidate IDs;
- add candidates in priority and dependency order;
- update status when dependencies change;
- use only the defined status labels and record unmet conditions under `Depends on` rather than inventing compound status labels;
- record verified bugs explicitly;
- remove completed work;
- remove work promoted into the ACTIVE sprint;
- do not record implementation progress;
- do not duplicate completed sprint history;
- do not place architectural decisions here;
- do not include raw financial identifiers, passwords or source fragments;
- keep candidates implementation-agnostic until repository discovery;
- distinguish candidate work from research and ideas;
- record every approved but unimplemented idea, verified bug, accepted architectural follow-up and deferred sprint exclusion;
- do not remove a candidate merely because its priority is low or its dependency is distant;
- preserve LedgerForge principles:
  - offline first;
  - privacy by default;
  - deterministic before intelligent;
  - single source of truth;
  - resilient parsing;
  - explicit user control;
  - explainable financial decisions;
  - explicit and reversible destructive actions.
