# Engineering Standards

Financial and correctness invariants for the private personal app. [Scope decisions](SCOPE_DECISIONS.md) owns product choices; [Harness](LedgerForge_Standing_Execution_Harness_Guide.md) owns execution/validation/reporting; [Build conventions](BUILD_AND_PROJECT_CONVENTIONS.md) owns Xcode/commands; [Architecture](Architecture_v1.0_Frozen.md), [Database](Database_v1_Architecture.md) and accepted [ADRs](ADR.md) own their technical boundaries. Current support/migration/WIP belongs only in [PROJECT_STATE](PROJECT_STATE.md).

Procedures inherit [Guide rule J](Project_Guide.md#documentation-order). The invariant sections below have no priority/sprint meaning.

## Priority Order

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

## Decision Framework

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

## Layer ownership constraints

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

## Financial Truth Standards

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

## Money and Currency Standards

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

## Financial Identity Standards

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

## Duplicate and Event-Evidence Standards

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

Under ADR-041, exact source bytes use `ledgerforge.source-bytes.sha256.v1`. Fingerprinting and extraction consume one immutable app-owned `SourceContentSnapshot` through confirmation, which revalidates that snapshot. Keep processing in memory under the current owner rule. Source bytes must not enter diagnostics or durable history merely for fingerprinting. Existing raw-text fingerprints remain valid and untouched; [PROJECT_STATE](PROJECT_STATE.md) owns accepted implementation.

## Binary documents

ADR-041 owns binary exact-content authority; current implementation is recorded in [PROJECT_STATE](PROJECT_STATE.md).

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

## Date, Order and Provenance Standards

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

## Persistence and Migration Standards

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

## Provider Parity

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

## Concurrency Standards

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

## Mutation and Correction Standards

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

## Card Evidence Standards

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

<a id="authentic-source-and-oracle-invariants"></a>
## Authentic source and oracle invariants

Only authentic original statements in `/Users/vyom/Documents/Ledger Forge` are input authority. Original bytes remain provenance/fingerprint authority and originals remain read-only. The [owner's current processing decision](SCOPE_DECISIONS.md#source-processing-decision) allows in-memory processing only, prohibits copied/decrypted/extracted/reconstructed statement files and all derived financial evidence files on disk, and preserves the app's normal database. No saved financial source-oracle or validation-output file is permitted. Older artifact recipes are historical, not exceptions. <!-- user-specified -->

No synthetic, generated, recreated, sanitized, reconstructed, representative, reduced, mutated, hand-authored or model-created financial statement may be created or used at any stage: development/debugging, extraction, normalizers/detectors/classifiers/parsers, tests/expected outputs/oracles, migrations/persistence/batch acceptance, developer UI or review. Statement factories/catalogs and hand-built statement/domain/DTO graphs cannot substitute for authentic sources. Pure source-independent nonfinancial values/files may test mechanics but must not impersonate financial statements. Missing genuine zero-activity/malformed/other cases remain source-uncertified. <!-- user-specified -->

The complete registered authentic corpus for every affected supported family is cumulative regression authority; each new recurring statement extends it unless explicitly excluded or archived. No representative month or sample certifies a family. Independent source facts must be established before production comparison, in memory under the current rule; production output cannot be its own sole oracle. Compare authentic truth through an explicit architecture-aware semantic projection, preserving exact ordered evidence or multiset/multiplicity as appropriate. Raw Oracle JSON need not equal production JSON where representations intentionally differ. Never invent occurrence identity, source ordering, dates or financial values.

Readers extract/preserve source evidence and physical boundaries. A PDF page with no extractable text is not alone financial invalidity; downstream interpretation determines nonfinancial, alternative-extraction or ambiguous content. Reader failures include corrupt/unreadable material, unresolved encryption and real resource failure. Technical limits must not masquerade as financial profiles.

One adaptive deterministic parser should own a recurring family unless materially different financial/source semantics justify a profile. Infer meaning from coherent labels, column roles, shapes, dates, Money, direction/liability effect, running balances, statement/section controls, continuity, multiplicity, order and surrounding evidence. Page/transaction count, absolute positions, inert whitespace/typography, benign breaks and nonfinancial pages do not define support. Zero-activity and variable-page sources are valid when coherent controls establish them. Fail closed on financial ambiguity, contradiction, malformation or unsupported semantics, not inert packaging changes.

A shared ingestion change that can affect a supported family requires its complete authentic corpus through ordinary production, provider persistence, reopen and hydration with independent projections. Green shared tests or a full TestPlan supplement, never replace, that gate. Historical profile acceptance is separate from current authentic-corpus reliability. Prefer native/deterministic extraction for structured formats; model interpretation is not ordinary financial authority. [ADR-046](ADR.md#adr-046) retains original accepted architecture; its current alignment records the processing clarification.

Required verification remains binding even where an old fixture/artifact recipe is now prohibited. Inspect current tool output behavior before financial execution; stop if in-memory independent proof and allowed persistence/output cannot be established. This documentation refactor does not change validation code or delete existing artifacts.

## Error Handling Standards

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

## Diagnostic Standards

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

## Privacy and Repository Safety

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

## Swift Coding Standards

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

## SwiftUI and Presentation Standards

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
- Ordinary owner usability is part of bounded acceptance: readable Money, no clipping, useful keyboard actions, focus, selection and resizing. No formal accessibility campaign or certification is a release gate.

Status must not be communicated by color alone.

Numeric values should use consistent alignment and tabular figures where appropriate.

---

## AI-Assisted Development Standards

- Chat owns planning and approval.
- Work owns bounded read-only discovery.
- Codex owns authorized repository execution.
- The direct Chat-approved prompt is the sole execution contract.
- Never infer production support from a fixture, protocol or similar layout.
- Never invent financial rules.
- Never use model confidence as evidence.
- Never permit AI output to become the sole validation oracle.
- Never permit AI to choose a trusted financial mutation.
- Legitimate task-scoped local/ChatGPT inspection of originals is permitted. Never put originals, credentials or private source/financial content in Git; preserve ordinary diagnostic protections and the current prohibition on derived financial evidence files on disk.
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

## Technical Debt Policy

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

## Change Policy

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

## Local inspection and publication

Legitimate local/ChatGPT inspection is permitted within the authorized task. Do not add blanket privacy gates for that inspection. Keep originals, credentials, private source/financial content, local databases/sidecars and sensitive output out of Git; accepted ordinary diagnostic/password-minimization behavior remains binding. The current source-processing rule separately prohibits derived financial evidence files on disk. Git publication is not permission to sanitize/reconstruct statements for development.

## Verification principles

Test the changed causal boundary: success, malformed/ambiguous/unsupported evidence, conflict, deterministic order, privacy, failure atomicity and provider parity where applicable. Migration tests include fresh creation, supported predecessor upgrade, checksum/gap/future-state rejection, preflight, injected failure, reopen and no partial publication; accepted migration identities stay append-only and independently locked. Preserve exact Money and provenance through provider reconstruction, hydration, presentation and same-database relaunch. A memory launch is not durable startup proof.

Manual import checks must use ordinary production preparation, validation/account review, explicit confirmation and provider persistence; no injected expected outcomes or alternate trusted financial path. Any debug launcher remains absent from Release. Native checks report their actual boundary and non-runs. [Harness proportional validation](LedgerForge_Standing_Execution_Harness_Guide.md#proportional-validation) controls test selection and reports.
