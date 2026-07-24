# LedgerForge — Product Vision

## Document Role

This document defines what LedgerForge should become.

It does not define:

- current production support;
- sprint order;
- implementation readiness;
- migration state;
- repository status;
- active execution scope.

Those belong respectively to:

- `Project documents/PROJECT_STATE.md`;
- `Project documents/FUTURE_WORK.MD`;
- accepted entries in `Project documents/ADR.md`;
- the complete Chat-approved execution prompt.

The Product Vision may remain ambitious, but it must not imply that planned capabilities already exist.

---

## Mission

LedgerForge is an offline-first personal financial operating system that consolidates a user's financial life into one trustworthy local workspace.

The primary product is financial understanding.

Document import, future OCR, profile assistance, rules and automation exist to maintain accurate repository-backed financial truth with as little manual effort as safely possible.

LedgerForge is designed for private personal use. It prioritizes:

1. financial correctness;
2. durable persistence;
3. deterministic behavior;
4. explicit user control;
5. privacy;
6. delivery speed.

LedgerForge is multi-currency by design. Every monetary value retains its native currency. Conversion, reporting currency and consolidated views are derived presentation concerns that must remain transparent and auditable.

---

## Product Vision

A user should eventually be able to open LedgerForge and understand:

- current financial position;
- cash available;
- account balances by native currency;
- net worth and its changes over time;
- investment allocation and performance;
- budget and category performance;
- upcoming obligations;
- internal movement between owned accounts;
- financial health;
- currency exposure;
- important changes requiring attention;
- the evidence supporting every conclusion.

LedgerForge should answer financial questions rather than merely store financial records.

The application should ultimately help answer:

- Where did my money come from?
- Where did it go?
- What merely moved between my own accounts?
- What changed my net worth?
- What requires attention?
- What should I consider doing next?

Recommendations and planning assistance must remain explainable and must not masquerade as guaranteed outcomes or regulated financial advice.

---

## Financial Identity

LedgerForge models financial entities rather than treating an institution name as sufficient identity.

A financial institution may contain multiple independent financial entities, including:

- bank accounts;
- credit-card accounts;
- card instruments subordinate to an account;
- loans;
- brokerage accounts;
- retirement accounts;
- investment folios;
- future financial products.

Repository identity remains immutable.

Display names, filenames, profile labels and institution branding are presentation or routing evidence only. They do not establish financial identity.

Supported imports should resolve to the authoritative owning financial entity using verified source evidence wherever available.

Potential verified identifiers include:

- institution account numbers;
- IBANs;
- card-account identifiers;
- card-instrument identifiers where the source distinguishes them;
- broker account IDs;
- investment identifiers such as folio numbers.

A document may also contain document-scoped relationships, such as multiple card instruments belonging to one account. Those relationships must not be flattened into separate financial entities without source and architecture authority.

Financial entities own durable financial history. Documents, import sessions, statements, transactions and source evidence describe activity associated with those entities.

Weak similarity must never silently establish identity.

---

## Product Principles

Every feature should advance at least one of these outcomes:

1. Reduce manual work.
2. Increase confidence.
3. Surface meaningful financial insight.
4. Preserve financial truth.
5. Improve recoverability or explainability.

LedgerForge must not sacrifice accuracy for convenience.

### Financial truth

- Original imported evidence remains immutable.
- Normalized and derived values remain distinguishable from source values.
- Every persisted imported transaction remains traceable to trusted document and source evidence.
- Import order must not change final financial truth.
- Unsupported, malformed, ambiguous or conflicting evidence must fail closed.
- Historical evidence must not be invented to make a migration or repair convenient.

### Determinism

- The same approved evidence should produce the same observable result.
- Approved fixtures and independent oracles define expected financial truth.
- Production parser output must not be the sole authority for its own correctness.
- Similar layouts do not imply support.
- Filename or display similarity does not imply institution, account or duplicate identity.

### Native currency

- Every monetary value retains native currency and scale.
- Conversion never overwrites imported values.
- Mixed currencies are not silently aggregated.
- Exchange rates, when implemented, retain provenance and effective time.
- Derived reporting values remain visibly distinct from source amounts.

### Owned-account transfers

Internal transfers between financial entities owned by the user must not be counted as new income, expense or net-worth change.

Transfer relationships must remain deterministic, explainable and correctable.

### Explicit control

- Financial mutation requires explicit user authorization.
- Destructive or corrective actions require impact preview.
- Reversible actions should provide family-specific reversal or compensation.
- Irreversible operations must state that boundary before execution.
- Automation must not silently promote weak evidence into trusted truth.

---

## Core Product Experience

LedgerForge should feel like a financial operating system rather than an import utility.

### Current foundational experiences

The current product foundation centers on:

- Dashboard;
- Accounts;
- Transactions;
- Imports;
- Settings.

These experiences are repository-backed and must present only authoritative persisted and hydrated state.

### Long-term product experiences

The broader product direction includes:

- Salary & Planning;
- Investments;
- Multi-Currency Reporting;
- Financial Timeline;
- Financial Intelligence;
- Rules & Automation;
- Budgets and Cash Flow;
- Financial Health;
- Goals;
- Documents and Provenance;
- Universal Search.

These are product directions, not claims of current implementation.

### Dashboard first

The Dashboard remains the primary destination.

It should answer:

- What is my financial position?
- What changed?
- What needs attention?
- What evidence supports this view?

Unsupported analytics must not be presented as real financial facts.

### Imports as supporting work

Imports remain an important supporting experience, not the reason the product exists.

The Import Centre should own:

- file selection and authorized access;
- preparation;
- validation;
- account and identity review;
- duplicate and overlap outcomes;
- explicit confirmation;
- progress and cancellation within safe boundaries;
- persistence outcomes;
- history and navigation.

macOS grants access to user-selected files and folders. LedgerForge must not claim unrestricted filesystem access.

All supported bank and card transactions belong to one global repository-backed Transactions experience. Institution-specific parsers must not create separate transaction applications, stores or financial truth.

---

## User Experience Philosophy

LedgerForge should feel like a native macOS financial application.

The current visual and interaction authority is:

1. `Project documents/UI_UX_v1.0_Frozen.md`;
2. `Project documents/UI Assets/Approved/DesignBoard_v2.0.png`;
3. remaining approved UI assets;
4. SwiftUI implementation.

The approved visual baseline is Deep Indigo and dark-mode-first.

Implementation translates approved design authority. It must not silently redesign the product.

The experience should emphasize:

- Dashboard-first navigation;
- persistent sidebar structure;
- contextual toolbars;
- dense but legible financial information;
- predictable keyboard and pointer behavior;
- clear empty and unavailable states;
- explicit scope for filters and actions;
- developer tooling separated from ordinary user workflows;
- privacy-safe presentation;
- temporary import workflows that return the user to financial understanding.

A future Light Mode or visual-system revision requires an approved design update rather than ad hoc implementation drift.

---

## Automation Philosophy

LedgerForge should not ask the user for information that can be determined reliably from approved evidence.

It should automate reasoning before automating mutation.

Small amounts of explicit user input are preferable to fragile or opaque inference.

Automation should focus on:

- reconciliation;
- financial understanding;
- relationship discovery;
- deterministic classification;
- recurring-activity recognition;
- planning support;
- explanation and review.

### Learning boundary

Future profile assistance or learning may help LedgerForge recognize:

- statement layouts;
- institution families;
- financial entities;
- categories;
- recurring activity;
- salary patterns;
- subscriptions;
- investments;
- user preferences.

Learning must remain:

- reviewable;
- versioned;
- privacy-safe;
- deterministic at the trusted boundary;
- subordinate to validation;
- unable to silently replace approved production parsing.

A successful import may contribute bounded evidence for future suggestions. It must not silently mutate trusted parser behavior or financial truth.

Automation should disappear into the background only after its authority, evidence and failure modes are understood.

---

## Intelligent Document Processing

LedgerForge treats an imported document as structured financial evidence, not merely as a file.

### Product compatibility direction

Initial institution and family priorities include:

- Axis bank-account statement families;
- HDFC bank-account statement families;
- CBQ bank-account and credit-card statement families;
- American Express credit-card statement families;
- fixture-backed Axis card families.

Every institution, document family, layout and source format is approved independently.

Support for one family never implies support for:

- all products from the institution;
- visually similar layouts;
- another source format;
- historical layouts;
- card semantics;
- another currency.

### Source-format direction

Target source formats include:

- CSV;
- PDF;
- XLS;
- XLSX;
- TXT where institutions provide deterministic text exports;
- future OCR only for sources that cannot provide trustworthy native text.

This is product direction, not current production coverage.

### Current support boundary

Verified production parsing currently supports the approved shared Axis bank-account CSV grammar represented by the approved NRE and supplied shared-layout NRO evidence.

New supported imports use the neutral forward profile:

```text
axis.bank-account.csv
version 1
```

Historical `axis.nre.csv` version `1` provenance remains readable.

The repository contains additional approved fixture evidence for Axis, HDFC, CBQ and American Express families across PDF and spreadsheet formats. Fixture availability enables discovery and regression work. It does not establish production support.

Production support does not currently include:

- broader Axis layouts;
- PDF statement import;
- XLS or XLSX import;
- TXT import;
- OCR;
- production password workflows;
- HDFC parsing;
- CBQ parsing;
- American Express parsing;
- production card parsing.

### Deterministic import pipeline

Every supported import converges into one production pipeline:

1. `ImportCoordinator` owns orchestration.
2. `PasswordProvider` supplies an optional credential when an approved workflow exists.
3. `ReaderRegistry` selects the source-format reader.
4. The reader extracts a `RawDocument`.
5. Institution Detection identifies the institution from approved extracted-content evidence.
6. Statement Classification identifies the document family.
7. Parser Selection chooses the approved parser/profile.
8. The Statement Parser creates an immutable `FinancialDocument`.
9. Validation evaluates structural and financial correctness.
10. Exact-content duplicate and supported transaction-event evidence are evaluated.
11. The user reviews account, identity, validation and import outcomes.
12. The user explicitly confirms the prepared import.
13. One provider-owned atomic persistence operation revalidates authoritative claims and commits the accepted financial graph.
14. `RepositoryStoreHydrator` publishes canonical persisted truth into runtime stores.
15. View models and views present repository-backed state.

Readers understand source formats only.

Parsers interpret financial meaning.

Validation does not depend on AI.

Persistence must not bypass validation, duplicate checks, explicit confirmation or provider-owned revalidation.

`RepositoryStoreHydrator` remains the sole persistence-to-runtime boundary.

### Detection and selection

Institution detection and statement classification must rely on approved extracted-content evidence.

They must not rely on filenames as authority.

Previous successful imports may inform future reviewed profile suggestions, but they must not silently become trusted detection or parser-selection evidence.

Unknown or unsupported documents remain unknown or unsupported rather than being guessed.

### Format independence

Once reader-specific extraction has produced approved evidence, downstream financial interpretation, validation, persistence and presentation remain independent of the transport format.

Equivalent source documents should preserve equivalent observable financial truth across formats.

Exact-content fingerprinting and cross-format financial equivalence are separate concerns:

- exact-content identity protects one exact source representation;
- cross-format equivalence proves that different representations describe the same financial statement.

Neither may be inferred from matching filenames, totals or transaction collections alone.

### Source fidelity

Supported imports preserve, where the source provides them:

- native currency;
- exact decimal meaning;
- debit, credit or source-specific direction;
- printed date meaning;
- source order;
- balances;
- verified identifiers;
- document and row provenance;
- parser profile identity and version.

Missing evidence must remain missing.

---

## Financial Intelligence

LedgerForge should evolve from document processing into deterministic financial understanding.

Future intelligence may include:

- statement continuity;
- historical backfill;
- overlap-aware importing;
- duplicate review;
- owned-account transfer recognition;
- money-journey reconstruction;
- salary verification;
- subscription and recurring-activity understanding;
- retirement tracking;
- investment understanding;
- obligations and cash-flow planning;
- financial forecasting;
- cross-account reconciliation;
- anomaly and change detection.

Financial intelligence builds on repository-backed truth. It must not operate directly on transient parser output.

Every conclusion must identify:

- supporting source and repository evidence;
- deterministic rules;
- relevant assumptions;
- limitations;
- native-currency and conversion treatment;
- whether the conclusion is confirmed, derived, suggested or unavailable.

---

## Explainable Intelligence

Every automated conclusion must be:

- explainable;
- inspectable;
- reproducible;
- auditable;
- bounded by its evidence.

Every automated mutation must additionally be:

- explicitly authorized;
- previewed;
- transactionally safe;
- reversible, compensatable or explicitly irreversible.

Users should be able to understand why LedgerForge reached a conclusion and what evidence would falsify it.

AI may assist with unsupported or ambiguous evidence only as a reviewable suggestion. It must never become the sole source of financial truth, validation, identity, persistence or mutation authority.

---

## Privacy and Offline Operation

LedgerForge remains fully functional for core financial use without an internet connection.

Core financial truth is stored locally.

Online services, when introduced, remain optional and explicitly controlled.

Passwords, raw financial identifiers and unrestricted source fragments must not appear in diagnostics, ordinary presentation or exports without an explicit approved boundary.

Backups, sync, external integrations and market-data services must preserve:

- explicit user control;
- provenance;
- encryption and credential boundaries where applicable;
- offline access to existing trusted data;
- truthful unavailable and stale states;
- recoverability.

User data must never be silently sent to an external service merely to improve convenience.

---

## Long-Term Goal

LedgerForge should become a trusted personal financial operating system that users open because it provides a clear, accurate and evidence-backed understanding of their financial life.

Importing documents should become a quiet maintenance activity.

Repository-backed financial views should evolve into a living model of:

- financial position;
- money movement;
- obligations;
- investments;
- plans;
- risks;
- changes requiring attention.

LedgerForge should progress from historical record keeping toward intelligent planning and decision support without weakening:

- offline-first operation;
- native-currency truth;
- deterministic processing;
- explainability;
- privacy;
- explicit user control;
- durable persistence;
- recoverability.

Every future capability should help the user understand, not merely record, their financial life.

LedgerForge should always favor deterministic financial understanding over opaque statistical inference or black-box automation.
