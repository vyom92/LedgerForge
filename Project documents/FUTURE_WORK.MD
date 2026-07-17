# LedgerForge Future Work

## Purpose

This document is the canonical planning queue for LedgerForge work that is not yet authorized for execution.

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

Execution is authorized only by the complete Chat-approved prompt supplied directly in the current conversation. Reports are returned directly in chat; verified durable facts belong in their subject authorities and Git history.

Items selected for execution must be removed from this document or narrowed to the portion that remains unscheduled.

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

A work item becomes executable only when Chat supplies one complete approved prompt directly to Codex.

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

Dependencies appear satisfied and the candidate may be considered during planning. Targeted Work discovery is used when current repository evidence is insufficient, stale or unable to establish a safe implementation boundary.

### Candidate

Recorded and potentially valuable, but not necessarily the next planning target.

### Blocked

A named dependency, architecture decision, fixture or preceding capability is missing.

### Ready for planning

The named dependencies and architecture are accepted, and the candidate may be prepared for a future implementation prompt after any explicit break or sequencing boundary. This status does not authorize implementation or assign a sprint.

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

After a completed increment is verified and accepted:

1. Read `PROJECT_STATE.md` and establish the verified repository baseline.

2. Review this document from the highest priority downward.

3. Exclude candidates whose dependencies remain unsatisfied.

4. Identify the highest-priority dependency-ready problems.

5. Determine whether related candidates may form one coherent sprint outcome.

6. When repository evidence is insufficient or the candidate’s implementation boundary is uncertain, send Work a read-only evidence-discovery task.

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

11. Chat supplies one complete execution prompt directly to Codex.

12. Remove promoted work from this document.

No candidate is selected merely because it appears first. Dependencies, evidence, risk and user value remain controlling factors.

---

## Upcoming-Work Reporting Rule

When reporting future work:

- identify the latest verified state from `PROJECT_STATE.md`;
- describe future work only using candidates recorded here;
- distinguish Ready for discovery, Candidate, Blocked, Bug, Maintenance, Research and Idea;
- do not assign future sprint numbers;
- do not describe a candidate as approved implementation;
- clearly label any new suggestion that has not yet been added to this document.

A valid statement is:

> Candidate `<ID>` is recorded as `<Status>` with the dependencies listed in this document.

An invalid statement is:

> The next sprint will implement `<candidate>`.

The second statement becomes valid only after Chat supplies a complete execution prompt directly to Codex.

---

# P0 — Financial Integrity and Persistence Safety

## FW-P0-02 — Historical Duplicate Review and Repair

**Status:** Blocked
**Depends on:** Completed Sprint 40 evidence and Sprint 41 bounded transaction-event ownership, Accepted ADR-037, post-Sprint-45 revalidation, and an independently approved duplicate-repair family contract

Provide safe review and correction for duplicate transactions already present in durable history.

Candidate outcomes include:

- duplicate-candidate review;
- explanation of matching evidence;
- import-session and source provenance;
- financial-impact preview;
- explicit user confirmation;
- rollback or undo protection.

Historical data must never be silently changed.

ADR-037 acceptance would reduce the shared architecture blocker. Duplicate-repair discovery, family-specific policy and a separate ADR would still be required before implementation.

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

ADR-037 requires same-process provider-scoped serialization and transaction-time stale-state checks, but does not complete this broader cross-process and external-writer candidate.

---

## FW-P0-08 — Data-Integrity Verification and Repair

**Status:** Blocked
**Depends on:** Accepted ADR-037, post-Sprint-45 revalidation, and an independently approved data-integrity repair-family contract

Provide privacy-safe verification for:

- broken account relationships;
- missing import sessions;
- orphaned documents or fingerprints;
- identifier conflicts;
- duplicated transactions;
- incomplete imports;
- inconsistent completion states.

Repair actions must be explicit, previewed and recoverable.

After ADR-037 acceptance and lifecycle revalidation, this candidate may proceed to narrower repair-family discovery. It is not implementation-ready.

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

The approved durable-attempt-history increment promotes only account-decision provenance required inside import-attempt history. Broader identity explanation, manual linking and unlinking remain future work.

---

## FW-P0-11 — Manual Account Linking and Unlinking

**Status:** Blocked  
**Depends on:** `FW-P0-10`, Accepted ADR-037, and independently approved linking, unlinking and identifier-detachment semantics

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
**Depends on:** `FW-P0-11`, Accepted ADR-037, and independently approved split and relationship-movement rules

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
**Depends on:** `FW-P0-14`, Accepted ADR-037, and independently approved survivor-identity, conflict and merge policy

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

**Status:** Candidate
**Discovery:** Complete
**ADR-037:** Accepted
**Post-Sprint-45 lifecycle revalidation:** Complete
**Planning state:** Architecture accepted
**Implementation state:** Gated
**Selected strategy:** Strategy A — contract-first architecture
**Schema state:** No migration authorized
**Depends on:** Independent selection of a concrete mutation family before source-level contracts

Discovery completed against commit `fe1f109bb8a1b9d425187869e91eefe98f4e5bb8` with a clean worktree and no repository changes. General architecture discovery is complete. Focused provider-lifecycle revalidation against the final Sprint 45 design is complete, and ADR-037 is Accepted. No executable mutation is authorized.

### Executive planning verdict

- GO for architecture planning.
- NO-GO for financial-mutation implementation.
- Strategy A is selected: architecture and domain contracts first.
- No executable mutation is authorized.
- No generic audit ledger is authorized.
- No schema migration is authorized.
- No source-level placeholder protocol is required merely to record the architecture.

### Approved shared architecture direction

1. authoritative repository snapshot;
2. immutable deterministic typed mutation plan;
3. read-only review;
4. single-use authorization bound to plan digest, scoped precondition token and provider generation;
5. transaction-time authoritative revalidation;
6. one provider-owned atomic execution boundary;
7. family writes and successful audit committed together;
8. one forced canonical `RepositoryStoreHydrator` reconciliation;
9. reversal as a new family-specific authorized mutation, compensation, or explicit irreversibility.

The shared foundation owns lifecycle, plan envelope, determinism, digest and precondition binding, provider-generation binding, authorization lifecycle, the atomic-execution requirement, successful-audit atomicity, reconciliation outcomes, privacy boundaries, provider parity and reversal classification.

Each concrete mutation family still owns affected records, financial meaning, conflict policy, write set, exact impact, audit payload, inverse or compensation, schema, UI and family-specific tests. The shared architecture does not authorize any family.

### Mandatory implementation prerequisites

1. A production-capable opaque provider generation must exist.
2. Planning/read activity leasing must exist.
3. A process-local authorization lifecycle must be approved.
4. One provider-owned atomic financial-mutation executor must exist.
5. A concrete mutation family must be independently selected.
6. The family must define exact affected state and conflict scope.
7. Exact native-currency impact must be computable.
8. Family writes and successful audit must share one provider transaction.
9. `reconciliation-blocked` behavior and a hydration-retry path must exist.
10. SQLite and In-Memory parity must be provable.
11. Family-specific reversal, compensation or irreversibility must be explicit.
12. Privacy-safe family audit and restoration material must be approved.
13. Family schema, migration and UI contracts must be independently approved.

### Stop conditions

> No financial mutation may become executable unless one provider-owned transaction can revalidate the exact reviewed plan, apply every family-specific write, atomically record successful audit evidence, return provider-equivalent outcomes, and support a proven family-specific inverse, compensation contract, or explicit irreversibility.

> If affected records, exact impact, precondition scope, identity provenance, provider generation, privacy-safe audit evidence, or canonical reconciliation cannot be proven, the operation remains non-executable. Best-effort financial mutation is prohibited.

### Explicit exclusions

`FW-P0-16` does not implement or authorize:

- account merge or split;
- identifier detachment or reassignment;
- transaction deletion or movement;
- import-session reversal;
- duplicate or historical repair;
- bulk transaction mutation;
- generic or backup-based undo;
- mutation UI;
- a generic mutation ledger or arbitrary JSON audit;
- persistent mutation diagnostics;
- a migration;
- an executable repository protocol.

### Sprint 45 relationship

Sprint 45 delivered Debug-only activity exclusion, provider-wrapper invalidation, provider replacement, backup, migration recreation, recovery and forced-hydration infrastructure. Focused revalidation is complete. That infrastructure informs but remains outside production financial-mutation semantics. Database reset or restore invalidates outstanding plans and authorizations; backup and restore are not record-level reversal.

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
4. broader bank-account layouts; Axis cards remain separate future card-family work subject to card semantics and fixtures;
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

Near-term HDFC direction is bank-account statements only through the unified import pipeline. Card support remains separate future work.

---

## FW-P1-03 — CBQ Parser Family

**Status:** Blocked  
**Depends on:** Approved CBQ fixtures and supported source formats

Keep independent CBQ families:

- CBQ bank-account statements;
- CBQ credit-card statements.

Each family requires independent approved fixtures and a financial baseline. QAR support depends on native multi-currency safety; card support also depends on credit-card financial semantics.


---

## FW-P1-04 — Additional Credit-Card Parser Families

**Status:** Blocked
**Depends on:** Approved institution-specific fixtures, the credit-card financial-semantics foundation and the Money foundation where multi-currency evidence requires it

Add card issuers only through deterministic, fixture-backed parser families.

American Express is the priority independent credit-card issuer. Additional issuers may be added only through deterministic, fixture-backed parser families.

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

## FW-P1-09 — Credit-Card Financial Semantics Foundation

**Status:** Blocked
**Depends on:** `FW-P3-29A` and later card implementation and persistence planning

Define the smallest document-scoped evidence contract required before production card parsing.

The American Express, CBQ and Axis card fixture integrations and final cross-family evidence review are complete. ADR-034 accepts a future-implementation boundary in which `FinancialDocument` may carry a parser-owned card-statement evidence envelope capable of preserving, only where source-supported:

- authoritative posted statement amount and statement currency;
- optional source-proven effect on the amount owed;
- source classification without claiming a universal accounting taxonomy;
- account-level versus instrument-level row scope;
- document-scoped instrument-section identity;
- optional original merchant amount and currency;
- independently optional printed FX-rate, fee, markup and tax evidence;
- source-specific statement-summary components and reconciliation evidence.

ADR-034 requires card-liability effects to remain separate from bank-account debit/credit semantics. A card instrument must not become an independent financial account merely because the statement presents a separate instrument section. Original merchant evidence must not replace the posted statement amount or currency.

Missing FX rates, fees, markup, tax, statement aggregates or other financial evidence must not be calculated merely to populate a common model.

Payment allocation, rewards accounting, reversal matching, universal card taxonomy and institution-independent balance formulas remain outside this candidate unless separately approved.

Card persistence remains blocked until the Money foundation and later card implementation and persistence planning establish the required domain, validation and persistence contracts. Institution-specific production parsers remain independently gated after the shared foundation is accepted.

The integrated evidence and completed review satisfy the discovery dependency. Final vocabulary, persistence fields and migration shape remain blocked on the Money implementation, concrete card validation requirements and later persistence planning.

Do not claim production card support from fixture integration, schema capacity, statement classification or parser candidates.

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

## FW-P1-19 — LedgerForge Import Centre

**Status:** Candidate  
**Depends on:** Existing confirmation-gated Import Wizard foundation

Complete the Import Wizard as the LedgerForge Import Centre for preparing, reviewing, confirming and understanding imports.

LedgerForge owns the queue, per-file state, preparation, validation, account choice, duplicate outcomes, confirmation, retry, cancellation and result navigation. macOS owns authorization for arbitrary file and folder access; LedgerForge must not claim unrestricted filesystem access.

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

This candidate provides the bounded foundation for the longer-term Import Studio direction without turning importing into the application’s primary experience.

---

## FW-P1-20 — Batch Import

**Status:** Blocked  
**Depends on:** Mature duplicate handling, cancellation boundaries and failure isolation

Import multiple files as independent jobs while preserving independent:

- validation;
- confirmation;
- account choice;
- duplicate outcome;
- persistence result;
- provenance.

A failure in one file must not silently affect another. Authoritative shared-state rechecks are required; serial versus bounded parallel execution remains unresolved.

---

## FW-P1-21 — Multi-File Drag-and-Drop Import Centre

**Status:** Blocked  
**Depends on:** `FW-P1-20`

Provide drag-and-drop queue visibility, per-file progress and outcomes, and result navigation for multiple files.

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
**Depends on:** Approved durable-attempt-history supported outcomes plus broader duplicate-management semantics

Retain future work for duplicate override, partial import, broader duplicate management, ambiguous or speculative duplicate candidates and historical duplicate repair. The approved durable-attempt-history increment covers read-only review of currently supported exact-statement and Axis UPI outcomes only.

---

## FW-P1-27 — Delete or Reverse an Import Session

**Status:** Blocked  
**Depends on:** Accepted ADR-037, post-Sprint-45 revalidation, and an independently approved import-session reversal family contract and impact preview

Safely reverse one import without damaging unrelated account history.

ADR-037 acceptance may make this candidate eligible for separate discovery. It does not authorize reversal implementation.

---

## FW-P1-28 — Confirmed-Persistence Recovery and Unsupported Retry

**Status:** Candidate
**Depends on:** Typed authoritative persistence-failure outcomes and repository-safe retry semantics

Preparation now has truthful named stages, one owned cancellable operation, and bounded fresh retry for typed source-reading failures. Retain only the unscheduled recovery boundary:

- determine whether any confirmed persistence failure can safely start a wholly fresh preparation without weakening authoritative repository checks;
- retain unsupported retry families as unavailable until their typed outcome and safety evidence exist;
- do not add persistence rollback, resumable jobs, batch queues or cancellation after confirmed persistence.

---

## FW-P1-29 — Better Validation Guidance

**Status:** Candidate  
**Depends on:** Existing validation pipeline

Present actionable, user-facing guidance while preserving detailed developer diagnostics separately.

The approved durable-attempt-history increment promotes only bounded enumerated guidance for supported attempt outcomes. Broader validation education and unsupported-result guidance remain future work.

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

## FW-P1-30 — Granular Development Database Reset

**Status:** Blocked  
**Depends on:** Separate approved selective-mutation semantics built on ADR-035

Candidate reset operations include:

- transactions only;
- import sessions only;
- financial identity only;
- repository financial data;

Each operation must clearly state what is retained and removed.

ADR-035 and Sprint 45 Phase A provide the reusable canonical lifecycle, activity-gate, provider-generation, backup and recovery boundary. This candidate covers only selective data-domain mutations, which remain unapproved and must not be inferred from whole-database reset.

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
**Depends on:** Implemented durable import-attempt-history foundation and an approved developer-inspection privacy boundary

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
**Depends on:** A separate approved diagnostic-history and timeline architecture

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

This candidate remains separate from the user-facing durable import-attempt history and is not promoted by the approved sprint.

---

## FW-P1-39 — Development Database Maintenance Utilities

**Status:** Research  
**Depends on:** Separate safety, mutation and validation contracts for each maintenance operation

Investigate safe development-only utilities for:

- opening the active database folder;
- exporting a SQLite snapshot;
- database vacuum or optimization;
- repository rebuild;
- balance recalculation;
- search reindexing.

Each operation requires an explicit safety contract, scope description and validation strategy.

ADR-035 and Sprint 45 Phase A already own canonical Debug identity, exclusive lifecycle activity, provider generations, checked close, coordinated SQLite/WAL/SHM handling, verified lifecycle backup and automatic recovery. Those delivered lifecycle responsibilities are not part of this research item; no snapshot export, vacuum, optimization, repository rebuild, recalculation, reindexing or repair utility was implemented.

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

## FW-P1-40 — Deterministic Approved-Fixture Launcher

**Status:** Ready for discovery
**Depends on:** Existing production preparation seam and approved sanitized fixtures

Provide a DEBUG-only launcher for repository-approved sanitized fixtures. It must enter the ordinary production URL-driven preparation path and preserve reader, detection, classification, parser, validation, account choice, duplicate evaluation, explicit confirmation, persistence, hydration and presentation.

The launcher must not auto-confirm, inject expected results, use private statements, or create an alternate parser, import engine, repository or persistence path. It must be absent from Release builds.

---

# P2 — Transaction Experience and Reconciliation

## FW-P2-01 — Transaction Source and Provenance View

**Status:** Candidate  
**Depends on:** Trusted document and import-session relationships

Show the account, source document and import session from which a transaction originated.

The approved durable-attempt-history increment exposes trusted provenance only within import-attempt history and detail. Dedicated transaction-detail provenance and broader source-document presentation remain future work.

---

## FW-P2-02 — Improved Transaction Detail Layout

**Status:** Candidate  
**Depends on:** None

Use the available detail space more effectively and remove developer-oriented terminology.

---

## FW-P2-03 — Advanced Transaction Search

**Status:** Candidate  
**Depends on:** Stable transaction fields

Expand future global Transactions filters for institution, account, bank/card family, currency, date and financial direction. Preserve one global repository-backed Transactions store and experience; do not claim these filters are currently implemented.

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
**Depends on:** `FW-P2-05`, Accepted ADR-037, and an independently approved contract for each concrete bulk-action family

Potential actions include notes, categories, rules and safe deletion or exclusion.

---

## FW-P2-07 — Delete Transactions by Import Session

**Status:** Blocked  
**Depends on:** Approved `FW-P1-27` import-session reversal

---

## FW-P2-08 — Undo Support

**Status:** Research  
**Depends on:** Family-specific reversible repository history; ADR-037 rejects universal application undo

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

Retain future work for speculative duplicate-transaction candidates, unsupported transaction-event families, historical duplicate review and repair, and workflows requiring reversible mutation. The approved durable-attempt-history increment explains supported Axis UPI transaction-event blocking only.

---

# P2 — Categories, Rules and Automation

## FW-P2-20 — Category Model and Management

**Status:** Candidate
**Discovery:** Complete
**ADR-036:** Accepted
**Post-Sprint-45 lifecycle revalidation:** Complete
**Planning state:** Ready for Chat planning
**Implementation state:** Gated
**Depends on:** Stable transaction model, durable repository transaction identity and approved category UI behavior

Discovery completed against commit `fe1f109bb8a1b9d425187869e91eefe98f4e5bb8` with a clean worktree and no implementation. Provider, migration and hydration assumptions were revalidated after Sprint 45, and ADR-036 is Accepted. Source implementation remains gated.

### Planning direction

- workspace-owned durable categories;
- a separate current transaction-category assignment relationship;
- Uncategorized represented by no assignment;
- one current category per transaction;
- user-created categories only;
- root categories plus one child level;
- deterministic alphabetical ordering by normalized name and immutable category ID;
- manual single-transaction assignment, change and clearing;
- archival for assigned categories;
- hard deletion only for unused, childless categories;
- durable repository transaction identity exposed during hydration;
- a dedicated category repository with SQLite and In-Memory parity;
- a dedicated category store;
- repository mutation followed by canonical `RepositoryStoreHydrator` refresh;
- an additive migration after the then-current migration version.

### Implementation prerequisites

1. Hydrated transactions must expose stable persisted repository transaction identity.
2. The category UI behavior supplement must be approved.
3. `CategoryRepository` must participate in installed-provider generation protection.
4. One repository-write activity lease must cover provider resolution, persistence and canonical reconciliation.
5. SQLite and In-Memory provider parity must be demonstrable.
6. Category hydration must publish one observer-consistent runtime snapshot.
7. The migration number must be selected from the then-current migration chain.
8. Lifecycle backup verification must cover the category schema.
9. Focused category lifecycle and recovery tests must be approved.

### Stop condition

> Never implement category assignment using regenerated runtime `Transaction.id`. Stop unless the immutable persisted transaction ID survives forced hydration, provider reconstruction, and relaunch.

### Bounded first implementation scope

- category domain;
- durable transaction identity exposure;
- category and assignment persistence;
- category repository;
- SQLite/In-Memory parity;
- category store;
- category-management coordinator;
- canonical hydration;
- Settings category management;
- transaction category display;
- transaction-detail assign, change and clear;
- archive and restore;
- delete-unused only;
- two-level hierarchy;
- deterministic ordering.

### Explicit exclusions

The first increment excludes:

- automatic categorization;
- deterministic categorization rules;
- AI categorization;
- merchant or payee normalization;
- recurring detection;
- analytics;
- budgets;
- multiple categories;
- tags;
- transaction splits;
- category filtering;
- custom ordering;
- bulk assignment;
- bulk reassignment;
- delete-with-replacement;
- category merge;
- assignment history;
- global undo.

### Mutation boundary and downstream effects

Individual category CRUD and single-transaction assignment are targeted metadata mutations. They do not depend on the complete `FW-P0-16` reversible financial-mutation foundation. Bulk reassignment, merge, delete-with-replacement and multi-operation undo remain dependent on `FW-P0-16` or an equivalent separately approved reversible metadata-mutation contract.

`FW-P2-21` does not become implementation-ready from discovery alone. After `FW-P2-20` is implemented and verified, `FW-P2-21` becomes eligible for its own discovery. `FW-P2-22` through `FW-P2-29` retain their existing dependencies. Spending analytics, budgets and Transaction Notes remain independently gated future work.

This work must precede automatic categorization.

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

Normal regional formatting may be discovered independently. Reporting-currency preferences depend on `FW-P3-33`.

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

Expand currency regression coverage once a second production currency exists; do not create a separate mixed-currency regression candidate.

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

## FW-P3-30 — Multi-Currency Account and Transaction Presentation

**Status:** Blocked  
**Depends on:** Sprint 44 Money boundary and a separately approved display or conversion scope

Present native and derived monetary values using locale-aware formatting, including:

- correct currency symbols and codes;
- regional decimal and grouping rules;
- Indian digit grouping where appropriate;
- international grouping where appropriate;
- simultaneous base and secondary display currencies where approved;
- visible distinction between native and converted amounts.

Before QAR production support, every row must retain native currency, summaries and Dashboard balances must be grouped by currency, and no combined amount may appear without an approved conversion.

Sprint 44 supplies the minimum safe grouped native-currency presentation. Converted, base-currency, reporting-currency and secondary-display totals remain outside this increment.

---

## FW-P3-31 — Exchange-Rate Storage

**Status:** Research  
**Depends on:** Approved rate-source and offline-cache policy

Rates must be versioned and immutable, carry provider provenance and validity time, support offline cache and expose stale or missing states.

The presence of an `exchange_rates` table in the database design does not activate production exchange-rate storage. This candidate remains separate from the Money increment and requires an approved source, provenance, validity, offline-cache, stale-state and missing-rate contract before any production write or conversion path is enabled.

---

## FW-P3-32 — Historical FX Conversion

**Status:** Blocked  
**Depends on:** `FW-P3-31`

Provide derived historical conversion without overwriting native values.

---

## FW-P3-33 — User-Selectable Reporting Currency

**Status:** Blocked  
**Depends on:** `FW-P3-31` and `FW-P3-32`

Provide selectable reporting currency while preserving native imported amounts.

---

## FW-P3-34 — Currency-Aware Analytics and Net Worth

**Status:** Blocked  
**Depends on:** Analytics and reporting-currency foundations

Provide current valuation conversion and consolidated reporting only from auditable derived values; native values remain authoritative.

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

- long-term mutation-history compaction and archival after `FW-P0-16` and a concrete durable mutation history exist; compaction cannot precede family-specific retention, privacy and reversibility policy.

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
- remove work selected for execution;
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
