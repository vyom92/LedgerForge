# Database architecture — persistence boundaries

## Current applicability and exact authority

This file describes durable contracts and the historical v1 persistence design. Current accepted migration and implementation/support limits live only in [PROJECT_STATE](PROJECT_STATE.md). The exact schema is [Database/Migrations.swift](../Database/Migrations.swift) and its registered migration sources; repository/DTO mappings and accepted ADRs control their implementation boundary. Do not infer features from dormant schema, older source-support text or migration capacity.

The original database baseline was reviewed 2026-07-26 at `b661472a58fc24144361322f1853b8001437a3eb`. Earlier V1–V6 explanations below are historical migration semantics, not a current migration inventory. Original migrations/identity locks are not edited by documentation alignment.

Later accepted boundaries include exact source-byte authority, source-specific equivalence/lineage, categories, card evidence, Salary and the authentic-source reset; see their numeric [ADRs](ADR.md) and accepted outcomes via current state. The owner’s [current processing decision](SCOPE_DECISIONS.md#source-processing-decision) preserves the normal app database but prohibits derived financial evidence files; old on-disk fixture/oracle recipes are superseded. Product backup/restore remains required but unimplemented until its own architecture and proof are accepted. Encryption, sync and multiple workspaces are not prerequisites.

## Database Principles

### Durable financial truth

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

### Validation before accepted persistence

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

### One durable authority

SQLite is the production durable authority.

Runtime stores are projections.

Views, ViewModels, coordinators and stores must not become persistence authority.

### Canonical hydration

`RepositoryStoreHydrator` is the only persistence-to-runtime boundary.

Successful writes are followed by canonical hydration.

Runtime stores are never patched manually to simulate a durable outcome.

### Native currency

Every trusted monetary value retains its native currency and canonical scale.

Conversion is derived and never replaces imported values.

Mixed currencies are not silently aggregated.

### Immutable identity

Repository IDs are opaque and immutable.

Display names, filenames, institution labels, masked identifiers, suffixes, transaction similarity and runtime presentation IDs are not durable identity.

### Privacy-minimal persistence

Persist only evidence required for:

- financial truth;
- identity;
- duplicate protection;
- source provenance;
- validation and attempt semantics;
- deterministic hydration;
- approved audit.

Do not persist unrestricted source text, raw canonical fingerprint payloads or diagnostics merely because storage is available.

### Fail closed

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

## Persistence Topology

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

### DatabaseProvider

`DatabaseProvider` owns:

- the installed repository set;
- typed persistence state;
- provider generation;
- SQLite or intentional In-Memory selection;
- persistence-unavailable state;
- provider-owned confirmed-import execution;
- provider-equivalent domain outcomes.

Repositories captured from an earlier provider generation become stale after provider replacement.

### Repository protocols

Repositories define domain-specific read and write boundaries.

They do not expose a general transaction closure for arbitrary cross-domain writes.

A coordinator must not simulate one atomic financial operation by calling several narrow repositories.

### SQLite provider

SQLite remains an implementation detail behind repositories.

Production publishes the provider only after:

1. open succeeds;
2. complete applied migration history validates;
3. pending registered migrations execute;
4. the final chain revalidates;
5. repository construction succeeds.

### In-Memory provider

The In-Memory provider is authoritative only within approved test or explicit Debug boundaries.

Where parity is required, it must expose the same observable domain outcomes as SQLite, including atomic publication and rejection residue.

### Persistence unavailable

Open, initialization, migration-integrity or migration-execution failure installs centrally rejecting unavailable repositories.

Persistence unavailable is not an empty database.

The application must not silently substitute a temporary In-Memory provider for failed production persistence.

---

## Authoritative Schema Ownership

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

### Logical production graph

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

## Import Persistence Lifecycle

### Preparation is read-only

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

### Explicit confirmation

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

### Provider-owned atomic confirmed import

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

### Rejected attempts

Rejected attempts remain distinct from accepted import sessions.

A bounded rejected attempt may be written after rejection or financial rollback.

That audit write is best effort.

Failure to record a rejected attempt must not:

- create accepted data;
- convert rejection to success;
- conceal persistence unavailability.

### Post-commit hydration

After successful durable commit, the workflow performs one forced canonical hydration.

A committed graph followed by hydration failure remains durably committed.

It must not be reported as an uncommitted import.

Further work may be blocked until canonical reconciliation succeeds.

---

## Durable Domain Contracts

### Workspace

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

### Account

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

### Financial identifier ownership

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

### Identifier observations

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

### Imported document

The imported-document record owns bounded durable document provenance.

It is not automatically an archive of the original file.

The current architecture does not require durable storage of:

- original file bytes;
- security-scoped bookmark data;
- arbitrary source paths;
- extracted text snippets;
- document thumbnails.

Any future source-document archive must first pass the private-personal scope gate and requires separate decisions for:

- retention;
- access;
- backup;
- deletion;
- privacy;
- fingerprint ownership.

Filename or path metadata, when retained, is never identity or duplicate authority.

### Document fingerprint

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

ADR-041 owns the accepted immutable source-snapshot and `ledgerforge.source-bytes.sha256.v1` contract; [PROJECT_STATE](PROJECT_STATE.md) owns current implementation. Processing is in memory under the current owner rule. Existing `ledgerforge.raw-text.sha256.v1` history remains untouched.

Legacy `documents.sha256`, multiple fingerprint ownership, compatibility, snapshot/security-scope lifetime, cleanup, concurrent preparation and confirmation-time revalidation follow the exact accepted ADR-041 implementation and later source-specific equivalence contracts. Historical migration identities remain unchanged; this document does not invent a migration.

### Import session

An import session represents accepted import history.

It is not the durable row for every file-selection or preparation attempt.

Preparation failure and cancellation do not create an accepted session.

Accepted session relationships are part of the provider-owned atomic graph.

Session metadata remains bounded and privacy-safe.

Parser profile authority is held by the normalized-document provenance relationship, not inferred from a session label.

### Import attempt

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

### Transaction

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

### Money

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

### Statement date

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

### Normalized document

For accepted trusted imports, the normalized document owns:

- relationship to the accepted document;
- relationship to the accepted session;
- parser profile ID;
- parser profile version.

The trusted V6 contract does not depend on persisting unrestricted `RawDocument` JSON.

A dormant legacy JSON column, if present, is not authority and must not be populated with unrestricted source evidence without a separately approved contract.

### Normalized row

A normalized row owns privacy-minimal source provenance:

- immutable row ID;
- normalized-document relationship;
- one-based document-scoped source ordinal;
- normalized-record digest.

It does not persist unrestricted original row JSON or source text merely for future convenience.

The digest proves bounded normalized-record identity within the accepted provenance graph.

It is not a transaction-event identifier or document fingerprint.

### Transaction/source relationship

One transaction may relate to one or more normalized source rows.

The relationship preserves:

- transaction identity;
- normalized-row identity;
- bounded contribution semantics where implemented.

The relationship must be complete and consistent before the accepted graph commits.

Missing, duplicate, conflicting or cross-document source relationships fail closed.

### Transaction-event identity

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

### Migration history

Migration history is part of database integrity.

Each registered migration has a stable:

- version;
- identity/name;
- checksum;
- application order.

Applied migration definitions are immutable.

Startup validates the complete chain, not merely the highest version number.

---

## Historical V1–V6 migration semantics

The migration registry and migration tests are the exact authority.

This section records only the accepted semantic increments.

### V1 and V2

V1 and V2 establish the earlier repository and identity foundations.

Their exact DDL remains defined by the registered migrations.

This document does not duplicate their column-level SQL.

Later migrations and accepted ADRs control current semantics where the original design baseline differs.

### V3 — Transaction-event ownership

V3 adds bounded `transaction_event_identities`.

The accepted contract includes:

- unique ownership by `(algorithm, digest)`;
- one identity per transaction and algorithm;
- restrictive relationships to transaction, account, document and accepted session;
- account/session lookup support;
- no historical backfill;
- no raw event evidence.

Accepted ownership commits atomically with accepted import history.

### V4 — Durable import attempts

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

### V5 — Atomic confirmed import and identifier ownership

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

### V6 — Trusted statement dates and source provenance

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

### Migration safety policy

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

## Migration-Chain Integrity

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

## Parent-Write Safety

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

## Currency and Exchange-Rate Capacity

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

## Card Evidence Capacity

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

1. the complete registered authentic corpus for the selected family, with independent source truth;
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

## Category Architecture

ADR-036 governs the implemented category domain added by Migration V8.

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

Migration V8 implements workspace-owned category definitions and one separate optional current assignment for each trusted transaction. Settings and transaction-detail UI provide the bounded manual operations recorded in `PROJECT_STATE.md`; automatic classification, hierarchy, rules and bulk behavior remain outside the implemented boundary. Category mutations hold one repository-write lifecycle exclusion across provider resolution, durable mutation and forced hydration. A committed-but-refresh-failed result preserves the last complete category snapshot and process-local generation-bound reconciliation state blocks later category writes until canonical hydration succeeds. Provider replacement and lifecycle transitions clear stale category state only after successful replacement hydration; no generic financial-mutation gate is introduced.

---

## Financial Mutation and Corrections

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

## Validation Persistence

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

## Search, Analytics and Derived Storage

### Full-text search

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

### Balance snapshots

Balance snapshots are not current financial authority.

A future snapshot table may be introduced only when:

- source balance semantics are defined;
- snapshot time is unambiguous;
- recomputation is deterministic;
- stale/incomplete state is visible;
- native currencies remain separate.

Snapshots must never replace trusted transactions or source balances.

### Materialized analytics

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

## Import Profiles

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

Current support requires ordinary production against the complete authentic corpus and independent source truth under ADR-046; historical fixtures are not authority.

---

## Rules and Enrichment

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

## Source Files, Attachments and Retention

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

## Database Backup and Restore

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

**Private-personal scope alignment — 2026-09-11:** Verified owner backup/restore remains required. App-level encryption has no current owner concern and is excluded by the canonical FUTURE_WORK.MD rejection register; it is not a backup dependency. This changes no accepted SQLite, migration, privacy or recovery behavior.

Production backup and restore require separate architecture for:

- consistent snapshot;
- version compatibility;
- migration;
- identity;
- partial failure;
- restore preview;
- validation;
- user control;
- privacy.

---

## SQLite Operational Contract

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

## Indexing and Query Design

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

## Deletion and Foreign-Key Policy

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

## Security and Privacy

### Local database

Core financial truth is stored locally.

No internet service is required for current repository operation.

### Sensitive values

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

### Encryption

Database encryption, SQLCipher and encrypted source-file storage are not current production capabilities.

The owner identifies no current encryption concern; no app-level encryption candidate or backup dependency remains. Only a new explicit owner decision naming a concrete disclosure concern may reopen a bounded security decision. Existing privacy, credential and recovery guarantees remain binding.

A design recommendation must not be described as implemented security.

### Credentials

Passwords do not belong in SQLite under the current architecture.

Credentials belong behind the accepted exact Keychain/credential ownership boundary; current supported families are recorded in PROJECT_STATE.

Readers receive a supplied credential and never retrieve one from the database.

---

## Determinism

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

## Concurrency

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

## Failure Semantics

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

## Testing and Verification

### Migration tests

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

### Provider parity

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

### Atomicity

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

### Financial truth

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

### Hydration and relaunch

Verify:

- provider reconstruction;
- canonical hydration;
- application relaunch;
- stable repository IDs;
- source relationships;
- parser profile;
- date semantics;
- presentation.

### Privacy

Tests and reviews must reject:

- raw identifiers in UI or diagnostics;
- raw event references;
- full fingerprint values;
- source rows;
- database paths;
- raw SQL errors.

A green suite is acceptance evidence only for the boundary it exercises.

---

## Change policy

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
