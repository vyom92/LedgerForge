# LedgerForge — Engineering Standards

**Status:** Active engineering and verification policy  
**Status alignment reviewed:** 2026-07-26
**Repository ref reviewed:** `main@b661472a58fc24144361322f1853b8001437a3eb`
**Latest verified production implementation:** Sprint 58 — Deterministic Import Verification Workspace; Sprint 59 ADR-041 architecture-only

## Document Role

This document defines LedgerForge engineering quality, financial-correctness, privacy, evidence and verification standards.

It does not define:

- current production support;
- sprint priority;
- implementation scope;
- active execution authority;
- exact build commands;
- exact migration DDL;
- product direction;
- UI design authority.

Those belong respectively to:

- `Project documents/PROJECT_STATE.md`;
- `Project documents/FUTURE_WORK.MD`;
- the complete Chat-approved execution prompt;
- `AGENTS.md` and `Project documents/BUILD_AND_PROJECT_CONVENTIONS.md`;
- registered migrations;
- `Project documents/Product Vision.md`;
- `Project documents/UI_UX_v1.0_Frozen.md` and approved assets.

`AGENTS.md` is the sole mandatory bootstrap entry point.

The complete Chat-approved prompt supplied directly in the current conversation is the sole execution contract.

No repository document creates an active task by itself.

---

# 1. Priority Order

When engineering concerns conflict, apply this order:

1. Financial correctness
2. Durable persistence
3. Deterministic behavior
4. Explicit user control
5. Privacy
6. Recoverability
7. Explainability
8. Maintainability
9. Delivery speed

A faster implementation is not preferable when it weakens a higher-priority property.

---

# 2. Decision Framework

Before implementing a capability, establish:

1. What user outcome it produces.
2. What durable authority owns the result.
3. What source evidence supports the result.
4. What can fail.
5. What must fail closed.
6. What the user must explicitly control.
7. What privacy boundary applies.
8. What verification proves acceptance.
9. What evidence would falsify the implementation claim.
10. Whether an accepted ADR or migration is required.

A feature should materially:

- reduce manual work;
- increase confidence;
- surface meaningful financial insight;
- preserve or improve financial truth;
- improve recoverability;
- improve explainability.

A feature that does none of these should not be built merely because the interface has room for it.

---

# 3. Mode Ownership

## Chat

Chat owns:

- sprint planning;
- prioritization;
- architecture discussion;
- prompt preparation;
- review of Work and Codex reports;
- final acceptance decisions.

Planning does not authorize implementation.

## Work

Work is limited to bounded, read-only investigation when GitHub cannot efficiently establish the required evidence.

Work may investigate:

- local or unpushed state;
- worktrees;
- filesystem and Xcode configuration;
- build, test or runtime evidence;
- broad cross-file tracing;
- one unresolved architecture boundary.

Work does not:

- edit files;
- commit;
- push;
- select a sprint;
- define architecture;
- authorize implementation.

Before escalation, Chat identifies:

1. the exact unknown;
2. why it affects the decision;
3. the bounded evidence Work must return.

## Codex

Codex performs only the edits, builds, tests, documentation updates and Git operations authorized by the complete Chat-approved execution prompt.

Codex reports evidence and limitations directly in chat.

## User edits

The user may edit repository files directly.

Legitimate compatible user work must be preserved and reconciled.

Unexplained, ambiguous, private, incompatible or unsafe work triggers a stop condition.

---

# 4. Repository Authority

Inspect repository evidence in this order:

1. exact ref or commit under review;
2. `Project documents/PROJECT_STATE.md`;
3. `Project documents/FUTURE_WORK.MD`;
4. relevant accepted ADRs;
5. frozen Architecture and Database Architecture;
6. production code and tests when documentation is insufficient;
7. approved fixtures and independent expected evidence.

Memory, uploads and earlier conversations are context only.

They do not override current repository evidence.

GitHub establishes pushed state only.

It does not establish:

- local worktree cleanliness;
- staged or unstaged changes;
- untracked files;
- local branches;
- linked worktrees;
- stashes;
- unpushed commits.

When local state matters, use local evidence.

---

# 5. Repository and Git Safety

## Pre-execution gate

Before an editing task, verify:

- current branch;
- current HEAD;
- `main`;
- `origin/main`;
- divergence;
- staged files;
- unstaged files;
- untracked files;
- linked worktrees;
- local branches;
- remote branches;
- stashes.

Default workflow is one `main` branch and one primary worktree.

Do not create a branch, worktree or pull request unless:

1. the user explicitly approves it;
2. a repository-specific reason is stated;
3. the complete execution prompt requires it.

Generic branching habit is not a repository-specific reason.

## Existing work

A dirty worktree is not automatically a failure.

Preserve and reconcile legitimate compatible work.

Stop when existing material is:

- unrelated;
- ambiguous;
- private;
- sensitive;
- broken;
- incompatible;
- unexplained;
- unsafe to combine;
- uniquely owned by an unverified branch, worktree or stash.

Never silently:

- discard;
- reset;
- overwrite;
- delete;
- drop;
- prune;
- abandon;
- force-push;
- rewrite published history.

## Commit gate

Commit only after:

- the authorized change is complete;
- required validation passes;
- the complete diff is reviewed;
- conflict markers are absent;
- privacy boundaries are verified;
- documentation claims match evidence;
- the staged set is legitimate and compatible;
- `origin` has been fetched again;
- unexpected remote advancement has been ruled out.

Prefer one coherent commit for one approved task unless the prompt requires independently validated commits.

## Push gate

Push only after the commit and final repository reconciliation succeed.

Finish with:

- `HEAD == origin/main`;
- clean primary worktree;
- no legitimate uncommitted changes;
- no unpushed commits;
- no leftover task branch;
- no additional task worktree;
- no unexplained stash.

A failed validation result must not be committed or pushed as completed work.

---

# 6. Core Architecture Standards

Preserve the approved production flow:

```text
ImportCoordinator
    ↓
PasswordProvider
    ↓
ReaderRegistry
    ↓
Reader
    ↓
RawDocument
    ↓
Institution Detection
    ↓
Statement Classification
    ↓
Parser Selection
    ↓
Statement Parser
    ↓
FinancialDocument
    ↓
Validation
    ↓
Exact-Content and Supported Transaction-Event Evaluation
    ↓
Account / Identity Review
    ↓
Explicit User Confirmation
    ↓
DatabaseProvider Confirmed-Import Operation
    ↓
Provider-Owned Atomic Persistence
    ↓
RepositoryStoreHydrator
    ↓
Runtime Stores
    ↓
ViewModels
    ↓
Views
```

## Required boundaries

- Readers understand source formats.
- Readers perform file access and extraction only.
- Readers receive optional credentials from coordination.
- Readers never access Keychain directly.
- Readers do not interpret financial meaning.
- Institution Detection identifies the source from approved extracted-content evidence.
- Statement Classification identifies the document family.
- Parser Selection chooses only an approved parser/profile.
- Statement Parsers own institution- and layout-specific financial interpretation.
- Statement Parsers alone produce verified financial identifiers.
- `FinancialDocument` is the canonical parser output.
- Validation is mandatory before accepted persistence.
- Preparation and review are read-only.
- Explicit confirmation is required for accepted persistence.
- `DatabaseProvider` owns the accepted atomic import boundary.
- Repositories are the only SQLite boundary.
- `RepositoryStoreHydrator` is the only persistence-to-runtime boundary.
- Runtime stores own observable projections, not durable truth.
- ViewModels prepare presentation state.
- Views present state and collect user intent.

## Prohibited bypasses

Never:

- access SQLite from Views, ViewModels or runtime stores;
- coordinate a financial transaction through several UI-owned repository calls;
- derive verified identifiers outside parsers;
- infer institution, account or format support from filenames;
- patch runtime stores to simulate persistence;
- use parser output as its own sole validation oracle;
- silently omit rejected transactions;
- infer missing financial evidence;
- represent unsupported behavior as available.

---

# 7. Folder Responsibilities

The repository structure may evolve, but responsibility boundaries remain stable.

## Views

- SwiftUI presentation.
- User intent collection.
- Accessibility behavior.
- No parsing.
- No financial calculation authority.
- No repository coordination.
- No SQLite access.

## ViewModels

- Presentation transformation.
- UI state derived from stores and typed workflow results.
- No durable ownership.
- No parsing.
- No direct persistence.
- No financial identity inference.

## Core

- Shared runtime infrastructure.
- Observable application state where appropriate.
- Cross-cutting values that do not belong to one feature module.
- No institution-specific financial interpretation.

## Models

- Domain values.
- Immutable financial evidence.
- Typed outcomes.
- No UI code.
- No persistence implementation.
- No source-format I/O.

## Services and Coordinators

- Application workflow orchestration.
- Domain-specific coordination.
- Activity and lifecycle ownership.
- No institution-specific source interpretation unless the service is explicitly the approved parser.
- No direct SQLite access.
- No alternate persistence-to-runtime path.

## Readers

- Authorized source access.
- Format-specific extraction.
- `RawDocument` production.
- Optional supplied-password handling.
- No Keychain access.
- No UI prompting.
- No financial interpretation.

## Analyzers and Normalizers

- Format structure.
- Deterministic extraction support.
- Ordered, uninterpreted evidence transport.
- No financial identifier verification.
- No institution-specific financial meaning unless explicitly assigned by an accepted ADR.

## Detectors

- Deterministic institution detection.
- Deterministic document-family classification.
- Parser-selection evidence.
- Unknown remains a valid result.
- No filename authority.

## Parsers

- Financial interpretation.
- `FinancialDocument` production.
- Parser profile identity/version.
- Verified financial identifiers.
- Approved transaction-event evidence.
- No file I/O.
- No persistence.
- No runtime-store mutation.
- No validation authority over their own output.

## Database

- Repository contracts.
- DTOs.
- SQLite provider.
- In-Memory provider.
- Registered migrations.
- Provider-owned atomic operations.
- No UI logic.
- No parser logic.

## Tests and Fixtures

- Independent financial truth.
- Provider parity.
- Migration integrity.
- Hydration and relaunch evidence.
- Privacy and falsification cases.
- No private source material.

---

# 8. Financial Truth Standards

## Source semantics

Source semantics outrank:

- parser output;
- expected JSON;
- snapshots;
- fixtures derived from production output;
- presentation;
- test convenience.

Expected evidence must be independently established.

## Required preservation

Where source-supported, preserve:

- native currency;
- exact amount;
- canonical scale;
- debit, credit or source-specific direction;
- printed date meaning;
- source order;
- balances;
- identifiers;
- account ownership;
- document relationships;
- parser profile;
- source provenance.

## Missing evidence

Missing evidence remains missing.

Never invent:

- currency;
- FX rate;
- fee;
- tax;
- markup;
- identifier;
- date;
- sequence;
- source relationship;
- historical observation;
- original merchant amount;
- card effect;
- reconciliation value.

## Ambiguous evidence

Malformed, ambiguous, conflicting or unsupported evidence fails closed.

A structural resemblance to a supported layout is not support.

An institution name is not account identity.

A matching transaction set is not exact-content identity.

A digest of weak evidence does not make the evidence strong.

## Accepted residue

When an accepted import is rejected or fails before commit, verify zero accepted durable residue.

Where the accepted graph includes new identity, zero residue includes:

- account;
- identifier ownership;
- identifier observation;
- document;
- fingerprint;
- session;
- normalized document;
- normalized row;
- transaction;
- source relationship;
- transaction-event identity;
- successful attempt.

---

# 9. Money and Currency Standards

## Money authority

Authoritative domain money is:

- one exact numeric value;
- one canonical native currency code.

Use `Money`, not an unpaired primitive amount and currency string, at trusted domain boundaries.

## Currency identity

- Accept exactly three ASCII letters.
- Normalize valid ingestion input to uppercase.
- Reject malformed codes.
- Use the reviewed compiled offline catalog as currency membership and scale authority.
- Do not let callers override fraction scale.
- Do not let dormant database catalog tables compete with the compiled catalog.

## Exact persistence

Trusted persistence uses:

- canonical locale-independent decimal text;
- exact integer minor-unit encoding;
- canonical currency.

Decimal and minor representations must agree.

Reject:

- implicit rounding;
- clamping;
- truncation;
- excess precision;
- overflow;
- negative-zero ambiguity;
- decimal/minor disagreement;
- currency disagreement.

## Arithmetic

Permit only same-currency:

- equality;
- checked comparison;
- addition;
- subtraction;
- aggregation;
- negation.

Cross-currency arithmetic fails explicitly unless an approved conversion domain supplies a derived value.

## Presentation

- Preserve native currency.
- Present one deterministically ordered total per native currency.
- Do not expose a currencyless aggregate across currencies.
- Apply locale only to presentation.
- Use tabular figures where appropriate.
- Include unambiguous currency information in accessibility output.
- Do not encode financial meaning through color or sign alone.

## FX boundary

Exchange rates remain separate from imported money.

Do not:

- overwrite native values;
- activate dormant exchange-rate capacity without approved architecture;
- derive card FX from amount pairs;
- present reporting-currency totals without provenance-bearing conversion.

Grouped native-currency presentation is implemented.

Production FX storage and conversion are not.

---

# 10. Financial Identity Standards

## Durable identity

Use immutable repository IDs for durable financial entities.

Never use as identity authority:

- display name;
- filename;
- institution label;
- masked value;
- last four digits;
- suffix;
- account type label;
- balance;
- transaction similarity;
- runtime presentation UUID.

## Identifier production

Only the selected approved Statement Parser may produce and verify a `FinancialIdentifier`.

Generic orchestration, persistence and presentation must not reconstruct identifiers from reduced metadata.

## No-match control

For eligible no-match cases, the user explicitly selects:

- one eligible unseeded existing account; or
- creation of a new account.

Eligibility does not prove identity.

The provider revalidates the selection at confirmation time.

## Ownership

Identifier ownership is singular within its approved workspace scope.

A conflicting owner rejects the complete accepted import.

Identifier observation provenance is distinct from ownership.

Historical observations are never invented.

## Future repair

Unlinking, reassignment, merge, split, incorrect-link recovery and historical backfill require separately approved mutation families.

Do not implement them through generic repository calls.

---

# 11. Duplicate and Event-Evidence Standards

## Exact-content duplicate identity

The current production text algorithm is:

```text
ledgerforge.raw-text.sha256.v1
```

Its authority is exact reader-produced UTF-8 text before parsing or normalization.

Filename, path and financial interpretation are excluded.

`ledgerforge.raw-text.sha256.v1` is implemented for the current reader-text boundary. Binary exact-content fingerprinting remains prospective under ADR-041.

Do not reconstruct legacy fingerprints from reduced repository evidence.

## Binary source snapshots under ADR-041

Future binary-capable imports must use exact source bytes under `ledgerforge.source-bytes.sha256.v1`. Fingerprinting and extraction must consume one immutable app-owned `SourceContentSnapshot` through confirmation, and confirmation must revalidate that snapshot. Source bytes must not enter diagnostics or durable history merely for fingerprinting. Existing raw-text fingerprints remain valid and untouched. This is a prospective standard: the snapshot and source-byte foundation do not exist in production today.

## Binary documents

Binary exact-content authority is accepted by ADR-041 for prospective implementation; the source snapshot and source-byte foundation are not implemented.

Do not represent parsed PDF text, normalized transactions or fixture equivalence as binary identity.

## Cross-format equivalence

Cross-format financial equivalence and exact-content identity are separate.

Equivalent financial statements in CSV and PDF may share expected financial truth.

They do not share one exact-content fingerprint merely because the transactions match.

## Transaction-event evidence

The current approved event family is limited to parser-verified account-scoped Axis UPI evidence.

Do not generalize it to:

- IMPS;
- NEFT;
- card transactions;
- e-commerce tokens;
- refunds;
- reversals;
- unstructured references;
- other institutions.

Unsupported evidence means unevaluated coverage, not novelty.

A supported overlap blocks the whole incoming statement.

Do not silently import a subset.

---

# 12. Date, Order and Provenance Standards

## StatementDate

A trusted imported financial date is a calendar date printed by the institution.

It is not:

- an instant;
- local midnight;
- `Foundation.Date`;
- a timezone-converted value.

Persist canonically as `YYYY-MM-DD`.

Preserve financial date role and bounded timezone evidence separately.

## Source order

Source ordinal is one-based physical normalized-record order within one reader-produced document.

Within one document:

```text
StatementDate + source ordinal
```

may establish approved sequence.

Across documents, equal dates do not establish intraday chronology.

## Durable provenance

Trusted imported transactions require:

- durable transaction ID;
- accepted document;
- accepted session;
- normalized document;
- parser profile ID/version;
- normalized source row;
- source ordinal;
- privacy-minimal normalized-record digest;
- complete transaction/source relationship.

Unrestricted source-row text is not durable provenance under the current contract.

## Hydration

Hydration rejects:

- unsupported date roles;
- malformed timezone evidence;
- missing profile provenance;
- conflicting source relationships;
- malformed normalized evidence.

Rejection occurs before runtime-store mutation.

---

# 13. Persistence and Migration Standards

## Exact authority

Registered migrations are exact schema authority.

Documentation must not become a second copy of DDL.

When exact schema details matter, inspect:

- registered migration definitions;
- DTOs;
- repository mappings;
- provider tests.

## Append-only chain

Applied migrations are immutable.

Never edit an applied migration to make current tests pass.

Add a new migration.

## Migration design

Every migration defines:

- accepted starting state;
- deterministic transformation;
- compatibility preflight;
- stop conditions;
- final invariants;
- provider impact;
- privacy impact;
- rollback or recovery behavior;
- reopen and relaunch verification.

## Historical evidence

Do not backfill values that require guessing.

Stop when required evidence is absent.

A reset requirement is more honest than invented financial provenance.

## Chain integrity

Verify:

- unique versions;
- complete order;
- stored checksum;
- no gaps;
- no unsupported future migration;
- successful pending execution;
- final chain revalidation.

Migration failure installs persistence-unavailable state.

Do not silently substitute an empty or In-Memory repository.

---

# 14. Provider Parity

Where SQLite and In-Memory providers both matter, they must expose equivalent domain behavior.

Verify parity for applicable:

- successful values;
- rejection;
- typed errors;
- uniqueness;
- ordering;
- atomic rollback;
- contention;
- stale state;
- provider generation;
- hydration evidence;
- zero residue.

Parity does not require identical internal code.

It requires equivalent observable truth.

In-Memory must publish affected collections together for atomic operations.

---

# 15. Concurrency Standards

Correctness relies on:

- provider-owned transactions;
- transaction-time revalidation;
- database constraints;
- provider generation;
- bounded serialization;
- typed contention outcomes.

A process-local lock may improve user experience.

It is not durable correctness authority.

For accepted confirmed imports, verify applicable competition through:

- same process;
- independent providers;
- separate processes;
- exact fingerprint claims;
- event claims;
- identifier ownership claims;
- stale account choice;
- stale identity resolution.

Do not claim protection from:

- disabled constraints;
- altered schema;
- arbitrary external writers;
- malicious file modification;
- database corruption.

State the proven concurrency boundary precisely.

---

# 16. Mutation and Correction Standards

Imported financial truth is not edited casually.

Ordinary metadata operations may use a targeted repository-owned mutation boundary when an accepted ADR defines them.

Financial repair, reversal and correction require family-specific architecture.

Never implement trusted financial mutation through:

- View or ViewModel coordination;
- sequential narrow repository calls presented as atomic;
- runtime-store patching;
- generic JSON before/after blobs;
- unexplained compensating transactions;
- database backup restore;
- Developer Console actions;
- AI-selected writes.

A financial-mutation family must define:

- eligible records;
- authoritative planning scope;
- immutable plan;
- exact native-currency impact;
- conflicts;
- warnings;
- review;
- single-use authorization;
- transaction-time revalidation;
- provider-owned atomic write set;
- successful audit;
- hydration;
- reversal, compensation or irreversibility;
- provider parity;
- privacy.

Generic “undo” is not an architectural substitute for family semantics.

---

# 17. Card Evidence Standards

Card evidence is parser-owned and document-scoped.

The canonical posted `Money` remains authoritative.

Card evidence may preserve only source-supported:

- classification;
- source marker;
- amount-owed effect;
- row scope;
- instrument section;
- original merchant money;
- printed FX evidence;
- fee;
- markup;
- tax;
- summaries;
- reconciliation;
- rewards or non-cash metadata.

Do not infer missing card evidence.

A document-scoped instrument section is not automatically a durable account.

Generic bank debit/credit semantics do not define card-liability effect.

No production card support is established by:

- fixtures;
- statement classification;
- schema capacity;
- protocol presence;
- one parser candidate.

Production card support requires an approved family, source format, validation, persistence, migration, hydration, relaunch, presentation and provider parity.

---

# 18. Fixture Evidence Standards

## Repository eligibility

Private-statement-derived evidence may enter Git only as an approved sanitized or clean-room package.

Never commit private originals.

## Clean-room restrictions

For clean-room reconstructions, do not reuse private:

- PDF objects;
- content streams;
- images;
- XObjects;
- fonts;
- metadata;
- annotations;
- forms;
- attachments;
- rasterized backgrounds.

## Financial preservation

Preserve source-supported:

- exact amounts;
- native currencies;
- direction;
- dates;
- source order;
- balances;
- identifiers;
- statement summaries;
- structural relationships;
- cross-period continuity where verified.

## Independent truth

Expected results must not be generated solely by the production parser under test.

Use:

- manual enumeration;
- source arithmetic;
- independent scripts;
- cross-format reconciliation;
- approved manifest evidence.

Distinguish source truth from implementation behavior.

## Geometry and extraction

- State native-text versus OCR boundaries.
- Do not use OCR when reliable native extraction exists.
- Use measured tolerances for geometry claims.
- Do not let visual review override numeric failure.
- Preserve source relationships without preserving private source objects.

## Fictional identity

Fictional identity continuity must be deterministic.

Do not expose:

- original identifiers;
- suffixes;
- merchants;
- references;
- filenames;
- paths;
- private mapping tables.

## Metadata compatibility

Use current repository-approved metadata for new packages.

Do not rewrite older approved fixtures solely for cosmetic uniformity.

## Support claim

A fixture proves only what its tests and metadata establish.

It does not automatically prove:

- production reader support;
- production parser support;
- institution-wide support;
- layout-family support;
- persistence;
- hydration;
- UI;
- exact-content identity.

---

# 19. Error Handling Standards

## Typed outcomes

Use typed domain outcomes at architectural boundaries.

Raw implementation errors are not public contracts.

Distinguish applicable:

- unsupported source;
- malformed source;
- validation failure;
- duplicate;
- event conflict;
- identity ambiguity;
- identity conflict;
- stale preparation;
- provider mismatch;
- contention;
- persistence unavailable;
- repository integrity conflict;
- migration failure;
- atomic write failure;
- committed but reconciliation failed.

## Failure behavior

- Fail early when the failure boundary is known.
- Fail closed when financial truth is uncertain.
- Never silently discard financial evidence.
- Never continue with a partial accepted graph.
- Never reclassify failure as success because audit recording failed.
- Never reclassify committed persistence as uncommitted because hydration failed.

## User-facing errors

User-facing errors should explain:

- what operation failed;
- whether durable state changed;
- what bounded next action exists.

Do not expose:

- raw SQL;
- database path;
- unrestricted source content;
- full identifier;
- full fingerprint;
- internal stack trace;
- arbitrary localized implementation error.

---

# 20. Diagnostic Standards

Diagnostics are governed by ADR-026.

They remain:

- structured;
- deterministic;
- bounded;
- privacy-safe;
- in memory unless another ADR approves persistence.

Diagnostic metadata may contain approved:

- subsystem;
- phase;
- result;
- count;
- algorithm version;
- operation family;
- duration bucket.

Do not log:

- passwords;
- raw identifiers;
- raw source rows;
- unrestricted narration;
- transaction references;
- full fingerprints;
- event digests;
- SQL;
- database paths;
- private fixture paths;
- credentials.

“Log unexpected conditions” never overrides privacy.

---

# 21. Privacy and Repository Safety

Never commit:

- private financial statements;
- credentials;
- passwords;
- API keys;
- private keys;
- tokens;
- local databases;
- SQLite sidecars;
- DerivedData;
- build products;
- sensitive logs;
- temporary files;
- unsanitized identifiers;
- private transaction evidence;
- unexplained generated output;
- user-specific Xcode state.

Before commit, inspect for:

- private filenames;
- source paths;
- account suffixes;
- merchant names;
- references;
- embedded document metadata;
- attachment content;
- fixture-generation residue.

Privacy failure is a stop condition.

---

# 22. Swift Coding Standards

## Design

- Prefer composition over duplication.
- Keep functions focused on one responsibility.
- Use descriptive names.
- Avoid abbreviations that hide financial meaning.
- Prefer domain value types over primitive pairs.
- Keep ownership explicit.
- Keep presentation formatting outside trusted financial logic.
- Avoid parallel implementations when an approved component can be extended safely.

## Safety

- Minimize force unwraps.
- Avoid unchecked casts.
- Validate external and persisted evidence.
- Preserve actor and Sendable correctness.
- Do not add protocol conformances merely for test convenience.
- Do not suppress compiler warnings without explaining the safety boundary.
- Do not catch and ignore repository or financial errors.

## Determinism

Avoid behavior based on:

- dictionary iteration;
- set iteration;
- implicit query order;
- locale-sensitive normalization;
- timezone-sensitive parsing of date-only evidence;
- runtime UUID generation;
- memory address;
- current clock unless time is part of the approved contract.

Use explicit stable ordering and versioned algorithms.

## Comments

Comments should explain:

- authority;
- invariant;
- failure reason;
- non-obvious trade-off.

Comments should not narrate obvious syntax or preserve obsolete behavior as folklore.

---

# 23. SwiftUI and Presentation Standards

- Views present state and emit user intent.
- ViewModels prepare presentation state.
- Runtime stores own observable projections.
- Repository IDs remain internal unless required as stable navigation identity.
- Financial identifiers are redacted.
- Unknown and unavailable states remain neutral.
- Empty is distinct from unavailable.
- Current workflow takes precedence over stale history.
- Mixed currencies remain separated.
- Unsupported actions remain absent or explicitly unavailable.
- Controls must perform the stated outcome.
- Do not add placeholder navigation to future modules.
- Preserve the frozen UI hierarchy and approved assets.
- Accessibility is part of acceptance.

Status must not be communicated by color alone.

Numeric values should use consistent alignment and tabular figures where appropriate.

---

# 24. Implementation Rhythm

Use small, coherent, verifiable changes.

A coherent change may require several files.

Do not force an architectural increment into “one file at a time” when the boundary requires:

- domain;
- provider;
- migration;
- hydration;
- tests;
- UI;
- documentation.

Prefer checkpoints that leave the repository buildable and explainable.

A reasonable rhythm is:

```text
inspect authority
    ↓
implement one coherent boundary
    ↓
build or type-check
    ↓
run focused tests
    ↓
review result
    ↓
continue
```

Do not implement an entire high-risk sprint before the first compilation.

Do not create tiny commits that split one atomic architectural outcome into misleading fragments.

---

# 25. Validation Planning

Every execution prompt should identify:

- baseline ref;
- included scope;
- exclusions;
- acceptance boundary;
- stop conditions;
- migration impact;
- ADR impact;
- fixture/oracle authority;
- focused tests;
- regression tests;
- build requirements;
- runtime verification;
- documentation updates;
- Git requirements.

Validation should test the claimed boundary, not merely nearby code.

A test suite is not acceptance evidence until its oracle and exercised boundary are understood.

---

# 26. Automated Verification

## Focused tests

Run focused tests early for the changed boundary.

Focused tests should include:

- success;
- malformed input;
- unsupported evidence;
- conflict;
- privacy;
- deterministic order;
- provider parity where relevant;
- injected failure where atomicity matters.

## Canonical suite

Run the approved canonical TestPlan when required by the execution prompt or when the change can affect shared behavior.

## Builds

Use approved Debug and Release build requirements from the execution prompt and Build Conventions.

A clean Debug build is the minimum for executable source changes unless a more specific boundary is approved.

Release and static analysis are required when the prompt, risk or changed boundary requires them.

## Migration tests

Migration changes require:

- fresh creation;
- supported predecessor upgrade;
- chain validation;
- checksum failure;
- gap failure;
- unsupported future state;
- preflight stop;
- injected failure;
- reopen;
- no partial publication.

## Runtime verification

Runtime verification is required when automated evidence cannot establish the user-visible or process-level boundary.

Examples include:

- app launch;
- navigation;
- import review;
- confirmation;
- provider replacement;
- relaunch hydration;
- multiple process contention;
- accessibility or visual behavior.

Manual verification must distinguish:

- passed;
- pending;
- unavailable;
- explicitly accepted deferral.

Do not claim runtime verification that was not performed.

---

# 27. Manual Import Verification

A DEBUG-only approved-fixture launcher may verify deterministic runtime presentation and navigation.

The launcher:

- enters the ordinary production preparation seam;
- preserves validation;
- preserves account/identity review;
- preserves explicit confirmation;
- preserves provider-owned persistence;
- does not inject expected results;
- does not bypass readers, parsers or repositories;
- is compile-time absent from Release.

Native macOS file selection receives a bounded smoke test where required.

Repeated fixture scenarios should not depend on fragile accessibility traversal of `NSOpenPanel`.

Private fixtures and alternate trusted import paths are prohibited.

---

# 28. Documentation-Only Cycles

A documentation-only cycle may skip full build and test execution only when all of the following remain unchanged:

- Swift source;
- tests;
- schemas;
- migrations;
- fixtures;
- executable build settings;
- Xcode project metadata;
- assets;
- generated production resources.

Every documentation-only cycle still requires:

- current-ref verification;
- authority review;
- complete diff review;
- conflict-marker scan;
- link and path validation;
- privacy review;
- status-claim verification;
- Git-state verification.

A `project.pbxproj`, scheme, test-plan or build-setting change is not ordinary documentation-only work.

It requires project-integrity validation and an appropriate clean build.

---

# 29. Xcode Project Standards

- Prefer Xcode-safe project operations.
- Avoid manual `.pbxproj` edits when safer tooling exists.
- Verify target membership.
- Verify synchronized-group behavior.
- Verify shared-scheme and TestPlan integrity.
- Keep user-specific Xcode state untracked.
- Do not commit DerivedData or local scheme-management state.
- Validate project-file changes before continuing.
- Do not infer target membership from folder location alone.

---

# 30. Definition of Done

An implementation task is complete only when all applicable conditions are satisfied.

## Scope

- Included work is complete.
- Excluded work remains excluded.
- No unauthorized opportunistic refactor is present.
- Stop conditions were not crossed.

## Correctness

- Financial invariants are preserved.
- Unsupported evidence fails closed.
- No accepted losing-path residue exists.
- SQLite and In-Memory parity is verified where required.
- Source truth and independent oracle evidence agree.

## Persistence

- Migration impact is correct.
- Provider behavior is verified.
- Hydration succeeds.
- Relaunch or provider reconstruction is verified where relevant.
- Presentation reflects canonical state.

## Quality

- Required focused tests pass.
- Required regression tests pass.
- Required builds pass.
- Required analysis passes.
- Applicable runtime verification passes or is explicitly accepted as deferred.
- No unresolved conflict markers exist.
- Privacy checks pass.

## Documentation

- Accepted ADRs are updated only when architecture changed.
- `PROJECT_STATE.md` records only verified durable facts.
- `FUTURE_WORK.MD` is changed only when the prompt authorizes queue reconciliation.
- Detailed implementation history remains in Git.
- Production support is not overstated.

## Git

- Complete diff reviewed.
- Authorized files staged.
- Commit created.
- Tag created only when required.
- Push completed.
- `HEAD == origin/main`.
- Primary worktree clean.
- No unpushed commits or unexplained residue remain.

Documentation-only tasks use their applicable validation boundary rather than pretending a Swift build proves prose correctness.

---

# 31. Report Standards

Execution reports are claims requiring evidence.

A report should state:

- starting ref;
- ending ref;
- branch and worktree state;
- changed files;
- included scope;
- excluded scope;
- migration impact;
- ADR impact;
- validation commands and results;
- runtime evidence;
- fixture/oracle evidence;
- documentation changes;
- staged, unstaged and untracked residue;
- commit;
- tag where applicable;
- push result;
- limitations;
- falsification analysis.

Classify material claims as:

- verified;
- reported only;
- contradicted;
- missing.

Do not treat “tests passed” as sufficient without explaining what the tests prove.

---

# 32. AI-Assisted Development Standards

- Chat owns planning and approval.
- Work owns bounded read-only discovery.
- Codex owns authorized repository execution.
- The direct Chat-approved prompt is the sole execution contract.
- Never infer production support from a fixture, protocol or similar layout.
- Never invent financial rules.
- Never use model confidence as evidence.
- Never permit AI output to become the sole validation oracle.
- Never permit AI to choose a trusted financial mutation.
- Never place private source material into prompts, logs or repository artifacts without an approved sanitized boundary.
- Verify filenames and target paths before editing.
- Verify repository state before and after execution.
- Build and test according to the approved boundary.
- Report exact evidence and uncertainty.

AI assistance may propose:

- parser candidates;
- test cases;
- documentation;
- bounded explanations;
- unsupported-layout suggestions.

Trusted acceptance still requires deterministic evidence and approved human-controlled boundaries.

---

# 33. Technical Debt Policy

Technical debt must be explicit.

A temporary compromise records:

- reason;
- exact scope;
- risk;
- affected invariant;
- expected lifetime;
- stop condition;
- intended replacement;
- canonical future-work candidate where follow-up is required.

Do not create a vague “cleanup later” note.

Do not let a workaround become architectural authority because it survived several sprints.

A temporary compatibility path should include:

- ownership;
- deletion condition;
- tests proving the boundary;
- documentation distinguishing it from the desired architecture.

---

# 34. Long-Term Engineering Philosophy

Optimize for durable correctness and maintainability over cleverness.

Prefer versioned, evidence-backed generalization over accumulating institution-specific special cases.

Make the next supported institution easier by improving:

- reader contracts;
- parser boundaries;
- fixture quality;
- independent oracles;
- provider parity;
- provenance;
- validation;
- failure behavior.

Do not broaden trusted behavior through automatic learning.

Future learning may produce reviewable suggestions.

It must not silently mutate parser authority, financial truth or persistence behavior.

Build systems that become easier to verify, not merely easier to extend.

---

# 35. Change Policy

Update this document when repeated verified experience establishes a durable engineering standard.

Do not update it for:

- one-off failures;
- temporary tool outages;
- a single sprint's implementation detail;
- speculative future behavior;
- personal preference.

A change to this document should identify:

- the repeated evidence;
- affected authority;
- compatibility impact;
- whether AGENTS, Project Guide or Build Conventions also require alignment.

Implementation remains separately authorized.

---

## End of Engineering Standards
