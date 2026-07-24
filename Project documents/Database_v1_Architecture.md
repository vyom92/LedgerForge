<!-- Project documents/Database_v1_Architecture.md -->

# LedgerForge — Database v1 Architecture

**Status:** Frozen database-design baseline, status-aligned through ADR-039 and verified Sprint 53 implementation  
**Status alignment reviewed:** 2026-07-24  
**Repository ref reviewed:** `main@686e3b91bfbf9459a38e9137abee6a2588ecec7f`  
**Latest verified implementation:** `11035461ce3de0f11ae5262bbc8a38b9639607b2` — Sprint 53  
**Current registered migration:** V6  
**Production database:** SQLite behind repository and provider boundaries

## Document Role

This document defines the approved LedgerForge database architecture and its current production-aligned persistence contracts.

It is not:

- the executable DDL authority;
- an inventory of every dormant table or column;
- a claim of production parser or source-format support;
- a backlog;
- a migration script;
- an implementation authorization.

The exact schema authority is the registered migration chain and the repository/DTO mapping implemented at the exact ref under review.

When this document conflicts with:

1. an accepted ADR;
2. a registered migration;
3. verified repository/provider behavior;

the accepted ADR, migration and verified behavior control in that order.

Current implementation state belongs in `PROJECT_STATE.md`. Unscheduled work belongs in `FUTURE_WORK.MD`.

---

# 1. Current Status Boundary

## 1.1 Verified production import

Production import support is limited to the approved shared Axis bank-account CSV grammar represented by:

- the approved Axis Bank NRE CSV evidence;
- the supplied shared-layout Axis Bank NRO CSV evidence.

Both use one production `AxisBankAccountParser`.

New supported imports emit:

```text
axis.bank-account.csv
version 1
```

Historical durable provenance using:

```text
axis.nre.csv
version 1
```

remains readable and is not rewritten merely to adopt the neutral forward profile.

No broader Axis, PDF, XLS, XLSX, card, HDFC, CBQ, American Express or other institution support is established by this database design.

## 1.2 Current migration and accepted architecture

The active registered migration chain ends at V6.

The current database architecture includes verified implementation of:

- versioned exact-content document fingerprints;
- bounded transaction-event identity;
- durable import-attempt history;
- provider-owned atomic confirmed import;
- workspace-scoped financial-identifier ownership;
- accepted-import identifier observations;
- exact `Money` persistence and hydration;
- strict statement-date semantics;
- durable document-scoped source order and provenance;
- parser-profile provenance;
- fail-closed migration-chain verification;
- canonical repository-to-runtime hydration;
- SQLite and In-Memory parity within accepted boundaries.

Accepted but unimplemented database architecture includes:

- document-scoped card-statement evidence under ADR-034;
- categories and current transaction-category assignment under ADR-036;
- financial-mutation planning, authorization and family-specific audit under ADR-037.

Acceptance does not create tables, migrations or production behavior.

## 1.3 Current source-format boundary

The repository contains fixture and extraction foundations for PDF and spreadsheet families.

Those foundations do not activate:

- production PDF persistence;
- binary-document fingerprint authority;
- production XLS or XLSX readers;
- production source-file archival;
- OCR;
- password storage;
- production card persistence;
- cross-format duplicate suppression.

Schema capacity, protocols and fixtures are not support.

---

# 2. Database Principles

## 2.1 Durable financial truth

Accepted imported financial truth is durable and immutable.

Trusted persisted values include, where source-supported:

- owning account;
- exact native-currency amount;
- direction;
- printed statement date;
- bounded date-role and timezone evidence;
- source-supported running balance;
- accepted import session;
- source document;
- document-scoped source ordinal;
- normalized-record digest;
- parser profile ID and version;
- transaction-event evidence;
- exact-content fingerprint relationship.

User-authored metadata remains separate from imported financial truth.

## 2.2 Validation before accepted persistence

Preview transactions are transient domain values.

They are not inserted as durable transactions and later promoted merely by changing a trust flag.

Accepted transaction rows are published only after:

1. source reading;
2. institution detection;
3. statement classification;
4. parser selection;
5. immutable `FinancialDocument` construction;
6. validation;
7. duplicate and supported event evaluation;
8. account and identity review;
9. explicit confirmation;
10. provider-owned transaction-time revalidation.

Malformed, ambiguous, conflicting or unsupported trusted evidence fails closed.

## 2.3 One durable authority

SQLite is the production durable authority.

Runtime stores are projections.

Views, ViewModels, coordinators and stores must not become persistence authority.

## 2.4 Canonical hydration

`RepositoryStoreHydrator` is the only persistence-to-runtime boundary.

Successful writes are followed by canonical hydration.

Runtime stores are never patched manually to simulate a durable outcome.

## 2.5 Native currency

Every trusted monetary value retains its native currency and canonical scale.

Conversion is derived and never replaces imported values.

Mixed currencies are not silently aggregated.

## 2.6 Immutable identity

Repository IDs are opaque and immutable.

Display names, filenames, institution labels, masked identifiers, suffixes, transaction similarity and runtime presentation IDs are not durable identity.

## 2.7 Privacy-minimal persistence

Persist only evidence required for:

- financial truth;
- identity;
- duplicate protection;
- source provenance;
- validation and attempt semantics;
- deterministic hydration;
- approved audit.

Do not persist unrestricted source text, raw canonical fingerprint payloads or diagnostics merely because storage is available.

## 2.8 Fail closed

The database layer does not invent:

- historical fingerprints;
- financial dates;
- source order;
- identifier observations;
- parser provenance;
- exchange rates;
- category assignments;
- card semantics;
- repair history.

---

# 3. Persistence Topology

```text
Views
    ↓
ViewModels
    ↓
Runtime Stores
    ↑
RepositoryStoreHydrator
    ↑
Repository Protocols
    ↑
DatabaseProvider
    ↑
SQLite / approved In-Memory provider
```

Import persistence enters through a provider-owned confirmed-import operation rather than through a View or ViewModel composing independent repository writes.

## 3.1 DatabaseProvider

`DatabaseProvider` owns:

- the installed repository set;
- typed persistence state;
- provider generation;
- SQLite or intentional In-Memory selection;
- persistence-unavailable state;
- provider-owned confirmed-import execution;
- provider-equivalent domain outcomes.

Repositories captured from an earlier provider generation become stale after provider replacement.

## 3.2 Repository protocols

Repositories define domain-specific read and write boundaries.

They do not expose a general transaction closure for arbitrary cross-domain writes.

A coordinator must not simulate one atomic financial operation by calling several narrow repositories.

## 3.3 SQLite provider

SQLite remains an implementation detail behind repositories.

Production publishes the provider only after:

1. open succeeds;
2. complete applied migration history validates;
3. pending registered migrations execute;
4. the final chain revalidates;
5. repository construction succeeds.

## 3.4 In-Memory provider

The In-Memory provider is authoritative only within approved test or explicit Debug boundaries.

Where parity is required, it must expose the same observable domain outcomes as SQLite, including atomic publication and rejection residue.

## 3.5 Persistence unavailable

Open, initialization, migration-integrity or migration-execution failure installs centrally rejecting unavailable repositories.

Persistence unavailable is not an empty database.

The application must not silently substitute a temporary In-Memory provider for failed production persistence.

---

# 4. Authoritative Schema Ownership

The registered migrations are the exact DDL authority.

This document records semantic contracts, not a second copy of SQL.

A copied table definition in documentation becomes stale as soon as a migration changes:

- a foreign-key action;
- a uniqueness constraint;
- an index;
- a required column;
- a check constraint;
- a compatibility gate.

Maintainers must inspect the exact migration chain and DTO mappers when exact columns or constraints matter.

## 4.1 Logical production graph

The current durable graph contains the following logical areas.

| Area | Verified purpose |
|---|---|
| Migration history | Proves the complete registered schema chain and applied checksums |
| Workspace | Scopes financial entities, attempts and identifier ownership |
| Institution metadata | Supports bounded presentation and parser-related metadata |
| Account | Immutable durable owner of financial history |
| Financial identifier ownership | Stores parser-produced verified identifier ownership |
| Identifier observation | Records accepted-import evidence for identifier ownership |
| Imported document | Owns bounded durable document provenance |
| Document fingerprint | Owns versioned exact-content identity |
| Import session | Represents an accepted import session |
| Import attempt | Represents bounded successful or rejected workflow outcome |
| Transaction | Stores accepted trusted financial activity |
| Transaction event identity | Owns approved cross-statement event evidence |
| Normalized document | Owns parser profile provenance for one accepted document |
| Normalized row | Owns document-scoped ordinal and privacy-minimal record digest |
| Transaction/source relationship | Links a transaction to one or more normalized source records |
| Currency and exchange-rate capacity | Dormant schema capacity, not active semantic authority |

The current database contract does not require all original Sprint 10 design tables to be active or populated.

---

# 5. Import Persistence Lifecycle

## 5.1 Preparation is read-only

Preparation may:

- read the authorized source;
- detect institution;
- classify statement family;
- select parser/profile;
- parse;
- validate;
- calculate exact-content fingerprint;
- perform advisory duplicate lookup;
- resolve advisory account identity;
- prepare explicit account choice;
- prepare supported event claims.

Preparation must not:

- create an accepted import session;
- create an account;
- attach an identifier;
- reserve a fingerprint;
- reserve a transaction-event identity;
- insert trusted transactions;
- mutate runtime stores.

Cancellation before confirmed persistence creates no accepted financial graph.

## 5.2 Explicit confirmation

The user confirms one immutable prepared import.

Confirmation binds the reviewed:

- source fingerprint contract;
- parser profile;
- account decision;
- identifier set;
- transaction set;
- validation result;
- supported event claims.

A stale preparation is not authority.

## 5.3 Provider-owned atomic confirmed import

The provider-owned transaction begins before authoritative confirmation-time claims are accepted.

It revalidates:

- provider generation;
- workspace and account relationships;
- current financial-identity resolution;
- explicit no-match account choice;
- identifier ownership;
- exact fingerprint ownership;
- supported transaction-event ownership;
- parser profile provenance;
- normalized source relationships;
- complete accepted graph integrity.

The accepted graph commits together or none of it commits.

The graph may contain:

- workspace creation or preservation;
- account creation or preservation;
- identifier ownership;
- identifier observations;
- imported document;
- fingerprint;
- import session;
- normalized document;
- normalized rows;
- trusted transactions;
- transaction/source relationships;
- event identities;
- successful import attempt.

A losing or failed accepted operation leaves zero accepted account, identifier or financial residue.

## 5.4 Rejected attempts

Rejected attempts remain distinct from accepted import sessions.

A bounded rejected attempt may be written after rejection or financial rollback.

That audit write is best effort.

Failure to record a rejected attempt must not:

- create accepted data;
- convert rejection to success;
- conceal persistence unavailability.

## 5.5 Post-commit hydration

After successful durable commit, the workflow performs one forced canonical hydration.

A committed graph followed by hydration failure remains durably committed.

It must not be reported as an uncommitted import.

Further work may be blocked until canonical reconciliation succeeds.

---

# 6. Durable Domain Contracts

## 6.1 Workspace

The workspace is the durable scope for:

- accounts;
- identifier ownership;
- import attempts;
- future categories;
- future preferences.

The current product may operate through one configured workspace, but persistence contracts remain workspace-scoped where approved.

A workspace ID is immutable.

Updating an existing workspace changes only DTO-owned metadata in place.

It must not delete and recreate the parent.

## 6.2 Account

An account is the durable owner of imported financial history.

Its repository identity is immutable.

Account metadata may include bounded presentation values such as:

- display name;
- institution relationship;
- account-family metadata;
- native-currency metadata;
- lifecycle fields where implemented.

Updating an account with an existing ID changes only fields owned by the account DTO.

It must preserve:

- transactions;
- documents;
- import sessions;
- identifiers;
- identifier observations;
- event identities;
- provenance;
- lifecycle fields outside the update contract.

SQLite and In-Memory providers must expose equivalent parent-update behavior.

## 6.3 Financial identifier ownership

Only approved statement parsers may produce verified financial identifiers.

Durable ownership is workspace-scoped.

The accepted contract distinguishes:

- ownership;
- observation provenance;
- presentation.

A stored identifier may be:

- already owned by the resolved account;
- unowned and eligible for attachment;
- owned by another account.

Ownership by another account rejects the complete accepted import.

Weak values are not promoted to strong identifiers.

## 6.4 Identifier observations

An accepted-import observation records bounded evidence that one accepted import supplied a trusted identifier for an account.

Observation does not create another owner.

Observation does not replace parser verification provenance.

Historical observations are not reconstructed from:

- account creation dates;
- existing import sessions;
- filenames;
- masked values;
- transaction history;
- display metadata.

## 6.5 Imported document

The imported-document record owns bounded durable document provenance.

It is not automatically an archive of the original file.

The current architecture does not require durable storage of:

- original file bytes;
- security-scoped bookmark data;
- arbitrary source paths;
- extracted text snippets;
- document thumbnails.

Any future source-document archive requires separate decisions for:

- encryption;
- retention;
- access;
- backup;
- deletion;
- privacy;
- fingerprint ownership.

Filename or path metadata, when retained, is never identity or duplicate authority.

## 6.6 Document fingerprint

ADR-030 defines the current production exact-content algorithm:

```text
ledgerforge.raw-text.sha256.v1
```

Authority is the exact UTF-8 byte sequence of reader-produced text after reading and before parsing or normalization.

The fingerprint excludes:

- filename;
- path;
- file timestamps;
- import timestamps;
- institution labels;
- account identity;
- parser selection;
- normalized rows;
- parsed transactions;
- totals;
- balances;
- presentation metadata;
- generated IDs.

The durable fingerprint stores the versioned algorithm and digest plus required relationships.

It does not persist:

- raw source text;
- the canonical payload;
- unrestricted fingerprint input;
- financial identifiers.

Uniqueness is database-wide under the current ADR-030 contract.

Binary-document authority remains unapproved.

## 6.7 Import session

An import session represents accepted import history.

It is not the durable row for every file-selection or preparation attempt.

Preparation failure and cancellation do not create an accepted session.

Accepted session relationships are part of the provider-owned atomic graph.

Session metadata remains bounded and privacy-safe.

Parser profile authority is held by the normalized-document provenance relationship, not inferred from a session label.

## 6.8 Import attempt

An import attempt records bounded workflow history.

It may carry closed, versionable codes for:

- outcome;
- coverage;
- account decision;
- guidance;
- persistence result.

It may relate to:

- workspace;
- account;
- accepted session;
- accepted document;

only where those durable records truthfully exist.

Attempt history excludes:

- raw source content;
- full identifiers;
- payment references;
- full fingerprints;
- event digests;
- unrestricted narration;
- file paths;
- raw localized errors.

The attempt model and presentation must remain forward-compatible with unknown future codes.

## 6.9 Transaction

A persisted trusted transaction is accepted financial truth.

Trusted production transactions are created only by the provider-owned confirmed-import graph.

The architecture does not rely on inserting preview candidates and later setting `is_trusted`.

A trusted transaction preserves:

- immutable repository transaction ID;
- workspace and account relationship;
- accepted session and document relationship;
- strict statement date;
- date role;
- bounded timezone evidence;
- exact `Money`;
- direction;
- bounded description/payee/reference fields where supported;
- optional source-supported running balance;
- normalized source relationships;
- creation metadata required by the implemented DTO contract.

A persisted transaction ID survives:

- hydration;
- relaunch;
- provider reconstruction.

Runtime-generated presentation IDs are not persistence targets.

## 6.10 Money

Trusted transaction persistence uses two agreeing representations:

- canonical locale-independent decimal text;
- exact integer minor-unit encoding.

Both use the canonical scale defined by the compiled offline currency catalog.

Trusted persistence and hydration reject:

- malformed decimal text;
- exponent notation where prohibited;
- unsupported currency;
- excess precision;
- integer overflow;
- decimal/minor disagreement;
- account/transaction currency inconsistency;
- invalid running-balance representation.

The integer representation is a checked query encoding, not independent financial truth.

The database `currencies` table does not override the compiled catalog.

## 6.11 Statement date

ADR-039 defines `StatementDate`.

It is:

- the Gregorian year, month and day printed by the institution;
- persisted canonically as `YYYY-MM-DD`;
- not an instant;
- not local midnight;
- not `Foundation.Date`;
- not converted through timezone arithmetic.

Separate fields preserve:

- financial date role;
- bounded statement-timezone evidence.

The supported Axis profile carries `Asia/Kolkata` evidence without transforming the printed date.

## 6.12 Normalized document

For accepted trusted imports, the normalized document owns:

- relationship to the accepted document;
- relationship to the accepted session;
- parser profile ID;
- parser profile version.

The trusted V6 contract does not depend on persisting unrestricted `RawDocument` JSON.

A dormant legacy JSON column, if present, is not authority and must not be populated with unrestricted source evidence without a separately approved contract.

## 6.13 Normalized row

A normalized row owns privacy-minimal source provenance:

- immutable row ID;
- normalized-document relationship;
- one-based document-scoped source ordinal;
- normalized-record digest.

It does not persist unrestricted original row JSON or source text merely for future convenience.

The digest proves bounded normalized-record identity within the accepted provenance graph.

It is not a transaction-event identifier or document fingerprint.

## 6.14 Transaction/source relationship

One transaction may relate to one or more normalized source rows.

The relationship preserves:

- transaction identity;
- normalized-row identity;
- bounded contribution semantics where implemented.

The relationship must be complete and consistent before the accepted graph commits.

Missing, duplicate, conflicting or cross-document source relationships fail closed.

## 6.15 Transaction-event identity

ADR-031 defines the current supported event family:

```text
ledgerforge.transaction-event.axis-upi-reference.v1
```

The durable record owns:

- versioned algorithm;
- privacy-safe digest;
- transaction;
- account;
- document;
- import session.

The database does not persist:

- raw UPI reference;
- canonical event payload;
- raw account identifier;
- parser source fragment.

The current family is limited to approved Axis UPI semantics.

It does not generalize to IMPS, NEFT, card transactions, refunds, reversals or unstructured references.

## 6.16 Migration history

Migration history is part of database integrity.

Each registered migration has a stable:

- version;
- identity/name;
- checksum;
- application order.

Applied migration definitions are immutable.

Startup validates the complete chain, not merely the highest version number.

---

# 7. Registered Migration Semantics

The migration registry and migration tests are the exact authority.

This section records only the accepted semantic increments.

## 7.1 V1 and V2

V1 and V2 establish the earlier repository and identity foundations.

Their exact DDL remains defined by the registered migrations.

This document does not duplicate their column-level SQL.

Later migrations and accepted ADRs control current semantics where the original design baseline differs.

## 7.2 V3 — Transaction-event ownership

V3 adds bounded `transaction_event_identities`.

The accepted contract includes:

- unique ownership by `(algorithm, digest)`;
- one identity per transaction and algorithm;
- restrictive relationships to transaction, account, document and accepted session;
- account/session lookup support;
- no historical backfill;
- no raw event evidence.

Accepted ownership commits atomically with accepted import history.

## 7.3 V4 — Durable import attempts

V4 adds `import_attempts`.

It establishes:

- workspace-scoped attempt history;
- closed versionable codes;
- optional relationships only when durable records exist;
- newest-first deterministic reading;
- authoritative successful-session backfill only;
- no invented rejected history;
- privacy-safe payload;
- SQLite/In-Memory parity.

## 7.4 V5 — Atomic confirmed import and identifier ownership

V5 implements the ADR-038 persistence direction.

It establishes:

- workspace-scoped identifier ownership;
- durable uniqueness for the approved ownership key;
- same-account idempotency;
- accepted-import identifier observations;
- compatibility validation before schema transition;
- one provider-owned accepted-import transaction;
- complete accepted-graph rollback on failure;
- equivalent SQLite and In-Memory outcomes.

V5 does not invent historical observations.

Identifier correction, detachment and reassignment remain future mutation families.

## 7.5 V6 — Trusted statement dates and source provenance

V6 establishes:

- strict date-only transaction persistence;
- financial-date role;
- bounded timezone evidence;
- normalized-document parser profile provenance;
- normalized-row record digest;
- document-scoped source ordinal;
- trusted transaction/source relationships;
- durable repository transaction identity through hydration;
- provider-atomic graph publication.

V6 rejects a nonempty V5 financial graph with an explicit pre-production reset requirement.

It does not reconstruct:

- dates;
- ordinals;
- record digests;
- profile provenance;
- transaction/source links.

## 7.6 Migration safety policy

Migrations must not use generic “best effort” backfill merely because a value can be approximated.

Every migration defines:

- accepted source state;
- exact transformation;
- compatibility preflight;
- stop conditions;
- SQLite/In-Memory impact;
- test fixtures;
- relaunch/reopen verification;
- privacy impact.

When required evidence is absent, migration stops.

A database backup is not a substitute for a correct migration contract.

---

# 8. Migration-Chain Integrity

The provider validates:

- registered versions are unique;
- versions form the expected chain;
- applied history contains no gaps;
- applied checksums match registered definitions;
- no unsupported future migration is present;
- pending migrations run in order;
- final history matches the complete registered chain.

A malformed chain fails before repositories are published.

Migration execution failure leaves persistence unavailable.

The application does not:

- continue on a partially migrated provider;
- silently edit applied migration history;
- skip failed versions;
- substitute an empty database;
- guess a compatible schema.

---

# 9. Parent-Write Safety

Existing workspace and account writes update DTO-owned columns in place.

They must not emulate an update through delete and insert.

Delete-and-recreate behavior can destroy or detach:

- transactions;
- import sessions;
- documents;
- identifiers;
- observations;
- event identities;
- future category assignments;
- lifecycle or provenance fields.

SQLite and In-Memory providers must preserve equivalent observable relationships.

A new parent ID represents a new durable entity, not a rename.

---

# 10. Currency and Exchange-Rate Capacity

The compiled offline currency catalog is the current semantic authority for:

- supported currency membership;
- canonical code;
- fraction digits;
- scale validation.

The database `currencies` and `exchange_rates` areas are inactive capacity.

They do not currently establish:

- an exchange-rate repository;
- rate retrieval;
- historical conversion;
- base currency;
- secondary display currencies;
- consolidated mixed-currency totals;
- stale-rate behavior.

Activation requires a separately approved domain covering:

- source/provider provenance;
- valid time;
- retrieval time;
- inversion and triangulation;
- precision;
- cache behavior;
- offline availability;
- missing/stale state;
- migration;
- hydration;
- presentation.

Imported native values remain unchanged.

---

# 11. Card Evidence Capacity

ADR-034 accepts a document-scoped card evidence direction.

The current database has no approved production persistence contract for:

- card instrument sections;
- statement summaries;
- original merchant `Money`;
- printed FX rate;
- fee;
- markup;
- tax;
- amount-owed effect;
- card-specific reconciliation.

No generic JSON column is approved as a substitute for a concrete card schema.

A production card family requires:

1. one selected fixture-backed family;
2. one supported source format;
3. exact card validation semantics;
4. durable query requirements;
5. SQLite/In-Memory parity;
6. migration;
7. hydration;
8. relaunch;
9. presentation.

Fixture integration alone does not authorize database change.

---

# 12. Category Architecture

ADR-036 accepts a future category domain.

The initial accepted direction requires:

- workspace-owned category identity;
- immutable category ID;
- display name and normalized name;
- optional one-level parent;
- archived state;
- separate current transaction/category assignment;
- zero or one category per transaction;
- Uncategorized represented by no assignment;
- assignment by durable repository transaction ID.

Category operations must not modify trusted transaction rows.

No category table, assignment table, V7 migration or production UI is implemented by the current V6 state.

The expected migration number may be V7, but implementation remains separately authorized.

---

# 13. Financial Mutation and Corrections

ADR-037 rejects a generic corrections table or arbitrary JSON before/after ledger as the initial architecture.

No financial correction may be implemented by:

- overwriting trusted transaction rows;
- manually patching runtime stores;
- composing independent repository writes;
- inserting an unexplained compensating transaction;
- restoring a whole database as record-level undo;
- using Developer Console;
- allowing AI to choose the mutation.

Each concrete family must define:

- eligible records;
- authoritative planning scope;
- immutable plan;
- exact native-currency impact;
- conflicts;
- review;
- single-use authorization;
- provider-owned atomic writes;
- successful audit;
- hydration;
- reversal, compensation or irreversibility;
- migration and privacy.

Current database v1 contains no generic mutation schema or audit ledger.

---

# 14. Validation Persistence

Validation occurs before accepted persistence.

The current production contract persists bounded accepted/rejected workflow evidence through:

- accepted sessions;
- import attempts;
- trusted transaction/session relationships;
- parser/source provenance.

No current production capability depends on a general durable per-row validation-issue ledger.

If dormant validation tables or JSON columns exist from the early design baseline, their presence does not authorize:

- unrestricted messages;
- raw source fragments;
- localized error persistence;
- parser output as validation authority.

A future durable validation-detail domain requires closed codes, retention rules, privacy review and hydration/query requirements.

---

# 15. Search, Analytics and Derived Storage

## 15.1 Full-text search

A transaction FTS table is not a current production contract merely because the original design recommended one.

Production search requires:

- approved searchable fields;
- privacy behavior;
- deterministic tokenization;
- update lifecycle;
- rebuild behavior;
- corruption recovery;
- query tests;
- provider parity or an explicitly SQLite-only read projection.

## 15.2 Balance snapshots

Balance snapshots are not current financial authority.

A future snapshot table may be introduced only when:

- source balance semantics are defined;
- snapshot time is unambiguous;
- recomputation is deterministic;
- stale/incomplete state is visible;
- native currencies remain separate.

Snapshots must never replace trusted transactions or source balances.

## 15.3 Materialized analytics

Derived tables or materialized views require:

- explicit source query;
- algorithm version;
- rebuild path;
- invalidation;
- native-currency handling;
- migration;
- independent correctness tests.

No analytical cache may become unrecoverable financial truth.

---

# 16. Import Profiles

The current production path persists parser profile ID/version with the accepted normalized document.

That provenance is not a reusable user-managed Import Profile domain.

The database does not currently claim a production repository for:

- learned column mappings;
- user-authored parser profiles;
- automatic profile promotion;
- profile confidence;
- profile sharing;
- profile rollback.

A reusable Import Profile domain requires separate identity, versioning, review and conflict semantics.

Parser code and approved fixture truth remain authoritative for current support.

---

# 17. Rules and Enrichment

Rules are future user-authored enrichment.

Rules must not rewrite imported financial truth.

A durable rule domain requires:

- immutable rule identity;
- version;
- condition vocabulary;
- action vocabulary;
- scope;
- priority;
- conflict handling;
- explanation;
- dry run;
- deterministic evaluation;
- assignment provenance;
- migration;
- hydration.

A generic `rule_json` column is not an approved production contract by itself.

---

# 18. Source Files, Attachments and Retention

The current architecture does not require permanent storage of original imported file bytes.

It also does not establish:

- source-file archive;
- document thumbnails;
- OCR image storage;
- attachment BLOB storage;
- arbitrary filesystem paths;
- automatic retention or purge;
- source-document export.

These capabilities require separate decisions because source deletion can affect:

- reprocessing;
- audit;
- privacy;
- exact fingerprint verification;
- backup;
- user expectations.

Trusted V6 provenance must not be purged casually.

A retention policy must prove which durable evidence remains sufficient after deletion.

---

# 19. Database Backup and Restore

Sprint 45 implements a DEBUG-only development database lifecycle.

Its lifecycle-owned backup:

- protects permanent Debug reset;
- is verified before replacement;
- includes committed SQLite/WAL state;
- is restored automatically on reset failure;
- is not arbitrary user backup.

It is not:

- production backup;
- export;
- cloud sync;
- record-level undo;
- financial-mutation reversal;
- arbitrary database file import.

Production backup and restore require separate architecture for:

- consistent snapshot;
- encryption;
- version compatibility;
- migration;
- identity;
- partial failure;
- restore preview;
- validation;
- user control;
- privacy.

---

# 20. SQLite Operational Contract

The production provider must configure and verify the SQLite behavior required by its implementation.

Relevant concerns include:

- foreign-key enforcement;
- transaction boundaries;
- write contention;
- busy handling;
- WAL checkpoint and close behavior;
- prepared/parameterized statements;
- connection ownership;
- migration transactionality;
- provider shutdown;
- subprocess competition.

This document does not freeze a generic “background write queue” as correctness authority.

Correctness comes from:

- provider ownership;
- database transactions;
- constraints;
- revalidation;
- typed results.

---

# 21. Indexing and Query Design

Indexes are introduced to support verified query and uniqueness requirements.

Current important categories include:

- primary and foreign-key access;
- workspace-scoped account and attempt queries;
- account/date transaction browsing;
- exact fingerprint uniqueness;
- transaction-event uniqueness;
- identifier ownership lookup;
- normalized-document/source relationships;
- migration history verification.

Do not add speculative indexes merely because a future screen may exist.

Every index should have:

- a named query or constraint;
- migration ownership;
- provider tests where relevant;
- write-cost review;
- query-plan verification when performance is the reason.

Indexes do not define financial identity unless an accepted ADR explicitly makes the constrained key authoritative.

---

# 22. Deletion and Foreign-Key Policy

Deletion semantics are domain-specific.

The database must not use broad cascade behavior to simulate correction.

Restrictive relationships are required where deleting a parent would erase trusted provenance or ownership.

Any future delete, archive, merge, split or reversal operation requires:

- explicit eligible state;
- impact preview;
- immutable identity policy;
- exact write set;
- audit;
- reversal or irreversibility;
- provider parity;
- migration tests.

Parent metadata updates remain in place and must not trigger cascades.

---

# 23. Security and Privacy

## 23.1 Local database

Core financial truth is stored locally.

No internet service is required for current repository operation.

## 23.2 Sensitive values

The database may contain trusted financial identifiers and financial history required for correct operation.

Presentation and diagnostics must redact them.

Do not expose:

- raw identifiers;
- UPI references;
- full fingerprints;
- unrestricted source rows;
- raw SQL errors;
- database paths;
- arbitrary source fragments.

## 23.3 Encryption

Database encryption, SQLCipher and encrypted source-file storage are not current production capabilities.

They require separate platform, recovery and migration design.

A design recommendation must not be described as implemented security.

## 23.4 Credentials

Passwords do not belong in SQLite under the current architecture.

Future credentials belong behind an approved Keychain boundary.

Readers receive a supplied credential and never retrieve one from the database.

---

# 24. Determinism

Database behavior must not vary because of:

- dictionary iteration;
- repository query order;
- locale;
- display-name ordering;
- filename;
- path;
- runtime UUID;
- memory address;
- diagnostic timestamp.

Where order matters, queries and DTO mappers use an explicit deterministic order.

Financial ordering uses source-owned evidence where approved.

A generated stable display tiebreaker must not be represented as financial chronology.

---

# 25. Concurrency

Confirmed-import correctness uses:

- provider-owned transaction;
- transaction-time authoritative revalidation;
- schema constraints;
- provider generation;
- same-process serialization where useful;
- SQLite contention handling;
- equivalent In-Memory serialization.

The accepted guarantee covers approved writers using the registered schema and enabled constraints.

It does not cover:

- arbitrary external SQLite writers;
- disabled constraints;
- schema modification;
- malicious corruption;
- lock-bypassing code.

A losing confirmed import must leave zero accepted financial residue.

---

# 26. Failure Semantics

Database failures map to typed domain outcomes.

Raw SQLite errors are not public API.

The persistence layer distinguishes, where applicable:

- unavailable provider;
- migration-integrity failure;
- migration-execution failure;
- duplicate;
- event conflict;
- identity conflict;
- stale account choice;
- stale prepared import;
- provider mismatch;
- contention;
- repository integrity conflict;
- atomic write failure;
- committed but hydration failed.

A committed graph is not reported as uncommitted because hydration failed.

An audit-write failure is not reported as financial success.

---

# 27. Testing and Verification

## 27.1 Migration tests

Every migration requires tests for:

- fresh database;
- upgrade from every supported predecessor;
- applied history validation;
- checksum mismatch;
- missing migration;
- duplicate version;
- unsupported future version;
- preflight stop conditions;
- execution failure;
- reopen after success;
- no partial schema publication.

## 27.2 Provider parity

Where both providers matter, verify equivalent:

- accepted graph;
- rejection;
- identifier ownership;
- observations;
- duplicate outcomes;
- event outcomes;
- failure residue;
- ordering;
- hydration evidence;
- typed errors.

## 27.3 Atomicity

Inject failure at every accepted-write stage.

Verify that no losing path leaves accepted:

- workspace or account residue where newly created;
- identifier ownership;
- observation;
- document;
- fingerprint;
- session;
- normalized source evidence;
- transaction;
- event identity;
- successful attempt.

## 27.4 Financial truth

Production parser output is not the sole oracle.

Use independent expected evidence for:

- count;
- exact amount;
- currency;
- direction;
- date;
- source order;
- balances;
- identifiers;
- provenance.

## 27.5 Hydration and relaunch

Verify:

- provider reconstruction;
- canonical hydration;
- application relaunch;
- stable repository IDs;
- source relationships;
- parser profile;
- date semantics;
- presentation.

## 27.6 Privacy

Tests and reviews must reject:

- raw identifiers in UI or diagnostics;
- raw event references;
- full fingerprint values;
- source rows;
- database paths;
- raw SQL errors.

A green suite is acceptance evidence only for the boundary it exercises.

---

# 28. Future Database Gates

## 28.1 Production PDF

Before PDF persistence becomes production-supported, approve:

- binary exact-content authority;
- source-content ownership through confirmation;
- one fixture-backed PDF family;
- deterministic extraction and source order;
- malformed/encrypted/image-only outcomes;
- provider parity;
- independent financial oracle.

## 28.2 XLS and XLSX

Before spreadsheet support, approve:

- reader/extraction authority;
- sheet selection;
- cell-type and date semantics;
- formula-result policy;
- source row ordering;
- binary/container fingerprint authority;
- malformed workbook behavior;
- licensing and Release implications.

## 28.3 Categories

Before V7, approve the final bounded implementation plan for:

- category table;
- assignment table;
- constraints;
- migration;
- repository parity;
- hydration;
- UI behavior.

## 28.4 Card persistence

Before card migration, select one concrete family and define:

- card account/instrument identity;
- posted amount and currency;
- original merchant evidence;
- summaries;
- reconciliation;
- queries;
- hydration;
- privacy.

## 28.5 Search

Before FTS, define:

- searchable source fields;
- tokenization;
- privacy;
- rebuild;
- index lifecycle;
- provider behavior.

## 28.6 Backup and restore

Before production backup, define:

- consistent snapshot;
- encryption;
- version and migration compatibility;
- restore validation;
- failure recovery;
- user control.

## 28.7 Financial mutation

Before any correction or reversal schema, approve one concrete operation family under ADR-037.

---

# 29. Maintainer Checklist

Before changing persistence:

- [ ] Inspect the exact current ref.
- [ ] Read `PROJECT_STATE.md`.
- [ ] Read the relevant `FUTURE_WORK.MD` candidate.
- [ ] Read accepted ADRs.
- [ ] Inspect the registered migration chain.
- [ ] Inspect repository DTOs and provider mappings.
- [ ] Identify the exact durable authority.
- [ ] Define SQLite and In-Memory behavior.
- [ ] Define migration and compatibility impact.
- [ ] Define failure and zero-residue behavior.
- [ ] Define hydration and relaunch acceptance.
- [ ] Define privacy boundaries.
- [ ] Use independent financial truth where money or provenance changes.
- [ ] Stop rather than infer missing historical evidence.
- [ ] Do not expose a partial repository workflow as one atomic operation.
- [ ] Do not represent dormant schema capacity as production support.
- [ ] Do not copy speculative SQL into this baseline as though it were active DDL.

---

# 30. Change Policy

This database baseline may be status-aligned without reopening its core architecture when:

- a verified sprint implements an accepted ADR;
- a registered migration advances;
- current support changes;
- a stale claim is corrected.

A database architecture change requires an accepted ADR when it changes:

- durable financial truth;
- identity;
- source provenance;
- atomicity;
- mutation authority;
- migration compatibility;
- currency semantics;
- duplicate/event identity;
- repository/hydration ownership;
- security or retention.

Implementation remains separately authorized by a complete Chat-approved execution prompt.

---

## End of Database v1 Architecture

Originally created for Sprint 10 Phase 2A.

Status aligned through:

- ADR-030 exact-content fingerprints;
- ADR-031 transaction-event identity;
- ADR-032 durable attempts;
- ADR-033 Money;
- ADR-034 card evidence;
- ADR-035 development database lifecycle;
- ADR-036 category architecture;
- ADR-037 financial mutation architecture;
- ADR-038 atomic confirmed import and identifier ownership;
- ADR-039 trusted statement dates and source provenance;
- verified Sprint 53 production state;
- registered migration V6.

Detailed DDL and migration behavior remain authoritative in the repository implementation.
