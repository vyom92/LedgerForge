# ======= ACTIVE SPRINT =======

## Sprint 38 — User-Confirmed Identifier Attachment & Import Verification

### Status

🟢 Ready for Implementation

---

## Objective

Allow a user to choose whether a validated import carrying one eligible parser-produced verified strong identifier should use an existing unseeded repository account or retain the current create-new-account path.

Sprint 38 must preserve parser ownership, deterministic resolver behaviour, immutable repository account identity, existing financial relationships, validation semantics, financial calculations and the RepositoryStoreHydrator boundary.

Sprint 38 is planned but not implemented by this contract.

---

## Governing Architecture

Sprint 38 implements and extends the accepted decisions from:

- ADR-024 — Repository Hydration Boundary
- ADR-025 — Stable Financial Entity Identity
- ADR-026 — Structured Developer Diagnostics
- ADR-027 — Parser-Owned Financial Identifier Extraction
- ADR-028 — Bounded Parser Source Evidence
- ADR-029 — User-Confirmed Financial Identifier Attachment

The canonical import and runtime flow remains:

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
    User Review & Explicit Confirmation
          ↓
    ImportPersistenceCoordinator
          ↓
    Repositories
          ↓
    SQLite
          ↓
    RepositoryStoreHydrator
          ↓
    Runtime Stores
          ↓
    ViewModels
          ↓
    Views

Views and ViewModels must not access SQLite or repository implementations directly.

Only repository implementations may communicate with SQLite.

RepositoryStoreHydrator remains the only approved persistence-to-runtime boundary.

---

## Current Verified Repository State

Sprint 37 is completed, validated, committed and pushed.

Verified Sprint 37 implementation state:

- `FinancialDocument.financialIdentifiers` carries parser-produced identifiers.
- `FinancialIdentityResolver` performs deterministic workspace-scoped lookup using only verified strong identifiers.
- `DefaultImportPersistenceCoordinator.persistValidatedImport` runs resolution only after validation passes.
- A resolved account is reused by immutable repository account ID and is not replaced by `upsertAccount`.
- A `noMatch` import currently creates an opaque import-scoped account and attaches eligible verified strong identifiers.
- Ambiguous and conflicting outcomes fail before repository writes.
- `ImportPersistenceMapper.payload(...accountId:)` applies the selected account ID to the account DTO and every transaction DTO.
- `RepositoryStoreHydrator` preserves repository references and presents only redacted verified-strong identity summaries.
- The existing Import Wizard owns `ImportPresentationState` and `PreparedImport` review/confirmation state in `ContentView`.
- The existing Accounts page selects accounts by immutable repository account ID through `AccountsViewModel`.
- The existing persistence sequence remains non-atomic across workspace, account, identifier, import-session and transaction repository operations.

Sprint 38 must not reinterpret or repair the already-observed duplicate financial history. Duplicate-transaction detection, account merge and historical transaction movement remain future architecture work.

---

## Approved User Journey

```text
Validated prepared import
        ↓
No verified identity match found
        ↓
Choose exactly one:
  Use Existing Account
  Create New Account
        ↓
Explicit confirmation
        ↓
Re-run authoritative identity and eligibility checks
        ↓
Attach verified identity and persist import
        ↓
Run one canonical forced hydration
        ↓
Show bounded verification result
        ↓
View Account by immutable repository account ID
```

No account may be selected automatically.

The existing create-new-account path remains available as an explicit user choice.

---

## Trigger and Eligibility Contract

The Sprint 38 choice is available only when all conditions are true:

- import validation has passed;
- `FinancialIdentityResolver` returns `.noMatch` using current repository state;
- exactly one parser-produced identifier is eligible for this sprint;
- the identifier has `.strong` strength;
- the identifier has `.verified` verification state;
- the identifier originated from the selected parser under ADR-027;
- the import is still the current prepared import and has not been committed.

The eligible identifier is the parser-produced `FinancialIdentifier` already carried by `FinancialDocument`.

Do not derive or promote an identifier from:

- filenames;
- account display names;
- institution labels;
- source descriptions;
- masked values;
- account-number suffixes;
- balances;
- transaction similarity;
- transaction counts or date ranges;
- import-session metadata;
- runtime UUIDs;
- other presentation metadata.

If these conditions are not satisfied, the Sprint 38 existing-account choice must not be offered.

Resolved, ambiguous and conflicting outcomes are not eligible for manual override under this sprint.

---

## Advisory Evaluation Contract

After validation succeeds and before confirmation, the application may perform a read-only advisory evaluation to:

- establish the current resolver result;
- determine whether exactly one eligible identifier exists;
- determine which same-workspace accounts are currently unseeded;
- populate the Import Wizard account-choice presentation.

The advisory evaluation is presentation state only.

It must not:

- attach identifiers;
- create accounts;
- persist import sessions;
- persist transactions;
- mutate repositories;
- mutate runtime stores;
- select an account automatically;
- treat the advisory snapshot as authoritative at confirmation.

The application must not promise that the displayed eligibility remains valid until confirmation.

---

## User-Choice State Ownership

The existing Import Wizard state in `ContentView` owns the transient user choice for the current `PreparedImport`.

The choice must be represented by the immutable repository account ID when the user selects **Use Existing Account**, plus an explicit **Create New Account** outcome.

The choice must:

- belong only to the current prepared import;
- be discarded on cancellation or replacement of the prepared import;
- never be inferred from the selected Accounts-page account;
- never use a display name, institution, currency or runtime UUID as identity;
- never silently change when repository hydration refreshes presentation state;
- require explicit user confirmation before any identifier or financial repository write.

Do not expose raw repository DTOs to Views or ViewModels.

Use the existing hydrated account presentation for user-readable account context and retain the immutable repository account ID only as an internal selection key.

---

## Confirmation-Time Revalidation

The existing confirmed import-persistence boundary is authoritative.

Immediately before repository writes:

1. Re-run `FinancialIdentityResolver` using current repository state.
2. Require the result to remain `.noMatch`.
3. Revalidate that exactly one parser-produced verified strong identifier remains eligible.
4. Revalidate the explicit user outcome.
5. For **Use Existing Account**, re-fetch the selected account by immutable repository account ID.
6. Verify the selected account belongs to the configured workspace.
7. Verify the selected account remains unseeded under the Sprint 38 contract.
8. Verify no account currently owns the identifier.
9. Reject safely before writes if any check changes.

The advisory evaluation must never substitute for these checks.

If a resolved, ambiguous or conflicting outcome appears at confirmation, reject without account, identifier, import-session or transaction writes.

---

## Existing-Account Eligibility

For **Use Existing Account**, the selected account must:

- exist at confirmation time;
- belong to the configured persistence workspace;
- have no stored identifiers of any strength, verification state or provenance;
- remain eligible after the authoritative recheck;
- not already own or conflict with the parser-produced identifier.

Existing account metadata and financial relationships must remain unchanged:

- account ID;
- workspace ID;
- display name;
- institution;
- account type;
- currency;
- source description;
- creation metadata;
- closure metadata;
- existing identifiers and provenance;
- existing transactions;
- existing import-session relationships.

Do not call replacement-style `upsertAccount` for the selected existing account.

Attach only the single eligible parser-produced verified strong identifier.

The parser provenance remains the identifier provenance. User confirmation authorizes the account association; it does not reclassify or re-verify the identifier.

---

## Create-New-Account Path

For **Create New Account**:

- retain the existing opaque account-ID policy;
- re-run identity resolution immediately before writes;
- require that no match has appeared since advisory evaluation;
- create the new account through the existing persistence path;
- attach the single eligible parser-produced verified strong identifier;
- persist every imported transaction against the new immutable account ID.

No filename, display name or institution label may participate in the new account ID.

---

## Identifier Attachment and Persistence Ordering

Identifier attachment must occur inside the existing confirmed import-persistence boundary.

For **Use Existing Account**:

1. Complete validation and explicit user confirmation.
2. Re-run resolver and eligibility checks.
3. Use the selected immutable repository account ID.
4. Attach the one eligible verified strong identifier.
5. Persist the import session using the existing repository workflow.
6. Map every imported transaction to the selected account ID.
7. Persist the transactions using the existing repository workflow.
8. Complete the existing import-session success update.

For **Create New Account**, retain the current account creation, identifier attachment, import-session and transaction workflow.

Do not move, rewrite, merge, delete or deduplicate existing transactions.

The existing documented non-atomic persistence limitation remains. Sprint 38 must not claim rollback, compensation or cross-repository atomicity.

If an identifier attachment succeeds and a later repository operation fails, preserve the existing partial-write semantics, report the partial outcome accurately and do not claim that rollback occurred.

---

## Runtime Mutation and Hydration Contract

Runtime stores must remain unchanged unless the complete import persistence outcome succeeds.

After successful persistence, perform exactly one canonical forced hydration through `RepositoryStoreHydrator`.

Do not add a second repository-to-runtime path.

The post-success hydration must:

- restore the selected or newly created account by immutable repository account ID;
- preserve all existing account and transaction relationships;
- expose the newly attached identity only through the existing redacted identity-summary path;
- make the account available to the existing Accounts page and inspector;
- remain correct after application relaunch.

The verified account must not be published through a direct View, ViewModel or Store repository read.

---

## Post-Import Verification Presentation

After a successful persistence and canonical hydration, present a bounded verification result containing:

- the selected existing or newly created account presentation;
- the safely redacted identifier;
- the persisted transaction count;
- the import-session result;
- a **View Account** action.

The **View Account** action must navigate to the existing Accounts page and select the verified account using its immutable repository account ID.

Do not present:

- the complete identifier;
- raw parser source evidence;
- repository IDs as financial identity;
- raw identifiers in diagnostics;
- speculative duplicate or reconciliation claims.

---

## Failure Behaviour

### Validation failure

- Do not perform identity evaluation or repository writes.
- Do not offer the Sprint 38 account choice.
- Preserve the existing validation-failure presentation.

### Cancellation before confirmation

- Discard the transient prepared import and user choice.
- Perform no identifier, account, import-session or transaction write.
- Do not mutate runtime stores.

### Advisory/authoritative mismatch

- Reject before repository writes.
- Do not fall back silently to the other account outcome.
- Preserve existing repository and runtime state.

### Attachment or persistence failure

- Do not claim success.
- Do not mutate runtime stores unless the complete persistence outcome succeeds.
- Preserve the existing non-atomic persistence limitation.
- If earlier repository writes remain durable, report that state accurately and do not claim rollback.

### Hydration failure after successful persistence

- Do not install an alternate runtime persistence path.
- Report the refresh failure distinctly.
- Preserve the durable repository result.
- Permit the existing canonical hydration/relaunch recovery path.

---

## Diagnostics and Privacy

Diagnostics may record concise lifecycle facts such as:

- identity review available;
- explicit existing-account choice requested;
- explicit create-new-account choice requested;
- authoritative revalidation rejected the choice;
- verified identity attachment succeeded or failed;
- import persistence succeeded or failed;
- canonical hydration completed or failed.

Diagnostics must not record:

- complete normalized identifiers;
- account numbers or IBANs;
- raw parser source evidence;
- source fragments;
- source filenames introduced by Sprint 38 diagnostics;
- account display names introduced by Sprint 38 diagnostics;
- transaction descriptions;
- repository IDs as financial identity.

When identifier context is required, use the existing deterministic redaction utility and bounded scheme/outcome metadata.

Raw identifier values must not enter View presentation state.

---

## Expected Production Scope

Inspect and modify only the existing implementation boundary required for this contract:

- `Services/ImportPersistenceCoordinator.swift`
- `Services/ImportPersistenceMapper.swift` only if the already-existing selected-account-ID mapping requires no other expression of the contract
- `Services/ImportEngine.swift` only if the existing prepared-import confirmation handoff requires it
- `ContentView.swift`

Reuse the existing `Database/Repository.swift`, repository providers, `FinancialIdentityResolver`, `RepositoryStoreHydrator`, `AccountsViewModel` and runtime stores.

No new repository API, DTO, schema, migration, parser, reader, normalizer, runtime-store or ViewModel type is approved by this contract.

If an existing repository operation cannot express the authoritative checks safely, stop and report before adding a new API.

No new implementation file is approved without explicit scope review and correct Xcode target membership.

---

## Expected Test Scope

Modify or add only focused coverage in the existing test target:

- `LedgerForgeTests/ImportRepositoryIntegrationTests.swift`
- `LedgerForgeTests/ConfirmationGatedImportWorkflowTests.swift`
- `LedgerForgeTests/AccountIdentifierRepositoryTests.swift` only if additional attachment-order coverage is required
- `LedgerForgeTests/IdentityResolverTests.swift` only if additional authoritative revalidation coverage is required
- `LedgerForgeTests/RepositoryStoreHydratorTests.swift` only if additional post-attachment hydration coverage is required
- `LedgerForgeTests/DeveloperDiagnosticsTests.swift` only if additional Sprint 38 privacy coverage is required

Do not create a new test target.

Run unchanged regression coverage including:

- `LedgerForgeTests/CSVImportRegressionTests.swift`
- `LedgerForgeTests/FinancialDocumentTests.swift`
- `LedgerForgeTests/AccountsViewModelTests.swift`
- the complete Xcode-native test plan.

---

## Automated Test Requirements

### Trigger and choice

1. Failed validation performs no identity evaluation or write.
2. Missing, weak and unverified identifiers do not offer the Sprint 38 choice.
3. Exactly one parser-produced verified strong identifier enables the choice only on `.noMatch`.
4. Resolved identity does not permit manual redirection.
5. Ambiguous identity blocks both choices before writes.
6. Conflicting identity blocks both choices before writes.
7. No account is selected automatically.
8. The user can choose **Use Existing Account**.
9. The user can choose **Create New Account**.
10. Cancellation before confirmation performs no writes and no runtime mutation.

### Authoritative revalidation

11. A resolver outcome changed after advisory evaluation blocks persistence.
12. A selected account deleted or changed before confirmation blocks persistence.
13. Workspace mismatch blocks persistence.
14. A target that gains any identifier before confirmation is no longer eligible.
15. An identifier owned by another account blocks persistence.
16. Stale advisory eligibility is never treated as authority.

### Existing-account persistence

17. Existing account ID is preserved.
18. Existing account metadata is unchanged.
19. Existing identifiers and provenance remain unchanged except for the one approved attachment.
20. Existing transactions and import-session relationships remain unchanged.
21. `upsertAccount` is not called for the selected existing account.
22. The attached identifier is parser-produced, strong and verified.
23. Every newly imported transaction uses the selected account ID.
24. No duplicate account or identifier is created.
25. Resolver returns the selected account after attachment.

### Create-new persistence

26. The opaque new-account ID policy remains unchanged.
27. The new account receives the one eligible verified strong identifier.
28. Every newly imported transaction uses the new account ID.
29. A match appearing after advisory evaluation prevents new-account creation.

### Runtime and presentation

30. Runtime stores remain unchanged until complete persistence succeeds.
31. Exactly one canonical forced hydration follows successful persistence.
32. Hydrated identity presentation is redacted.
33. View Account selects the verified account by immutable repository account ID.
34. SQLite relaunch restores the account, identifier, transactions and import session.
35. Partial repository failure is reported without a false rollback claim.

### Privacy and regression

36. Diagnostics contain no complete identifier, source fragment, source filename, account display name or transaction description.
37. The approved Axis CSV remains 81 INR transactions with unchanged ordering, totals, balances and validation.
38. Existing import confirmation and cancellation behaviour remains valid.
39. Existing Dashboard, Accounts and Transactions calculations remain unchanged.
40. Duplicate-transaction detection is not introduced.

---

## Manual Verification Requirements

Using the approved Axis NRE CSV and an existing Sprint 37/Sprint 36 SQLite database:

1. Launch the newly built application and allow canonical hydration to complete.
2. Prepare a valid import carrying exactly one parser-produced verified strong identifier.
3. Confirm no repository or runtime mutation occurs during preparation or advisory evaluation.
4. Confirm the Import Wizard presents exactly **Use Existing Account** and **Create New Account** when the current outcome is `noMatch` and eligible accounts exist.
5. Confirm no account is preselected automatically.
6. Confirm account choices use readable hydrated account context while internal selection uses immutable repository account ID.
7. Cancel before confirmation and verify no account, identifier, import-session, transaction or runtime change.
8. Re-prepare the import and choose **Use Existing Account**.
9. Confirm the final action performs authoritative revalidation before writes.
10. Verify the selected existing account metadata, identifiers, transactions and import-session relationships are preserved.
11. Verify no replacement-style account write occurs for the selected account.
12. Verify the one verified identifier attaches to the selected account.
13. Verify imported transactions persist against the selected account ID.
14. Verify exactly one canonical forced hydration occurs after successful persistence.
15. Verify the bounded result shows the selected account, redacted identifier, transaction count, import-session result and **View Account**.
16. Select **View Account** and verify the Accounts inspector selects the same account by immutable repository account ID.
17. Relaunch and verify the account, redacted identity, transaction relationships and import history restore through hydration.
18. Repeat with **Create New Account** and verify the existing opaque account-ID path remains intact.
19. Confirm resolver, ambiguous and conflict changes are rejected before writes where testable through controlled repository state.
20. Confirm no raw identifier, source fragment, new filename, account display name or transaction description appears in Developer Console diagnostics.
21. Confirm Dashboard and Transactions behaviour remains unchanged.
22. Run the Axis CSV financial baseline and verify 81 transactions, ordering, totals, balances and validation remain identical.

Do not use the current two-account duplicate database as evidence that Sprint 38 repairs duplicate history. That is explicitly excluded.

---

## Explicit Exclusions

Do not implement:

- duplicate-transaction detection;
- repair of the current two-account development database;
- account merge;
- account split;
- incorrect-link recovery;
- identifier removal;
- moving historical transactions;
- automatic or heuristic account matching;
- overriding resolved, ambiguous or conflicting outcomes;
- schema migration;
- DTO redesign;
- cross-repository atomic persistence redesign;
- import rollback;
- batch import;
- parser expansion;
- PDF support;
- account-match explanation UI;
- general identity-conflict management;
- broader account linking or unlinking;
- identifier backfill for already identified accounts;
- changes to parser, reader, normalizer, validation or financial calculations;
- direct repository or SQLite access from Views, ViewModels or Runtime Stores.

---

## Stop Conditions

Stop implementation and report without expanding scope if:

- the trigger requires any outcome other than `.noMatch`;
- more than one eligible parser-produced verified strong identifier must be attached;
- the identifier is not produced and verified by the selected parser;
- no account can be selected by immutable repository account ID;
- selected-account eligibility cannot be revalidated immediately before writes;
- existing-account metadata cannot be preserved without replacement upsert;
- a new repository API, DTO, schema, migration, parser, reader, normalizer or runtime path becomes necessary;
- a View or ViewModel must access a repository or SQLite directly;
- runtime state would change before complete persistence success;
- more than one canonical hydration is required after successful persistence;
- raw identifiers or source evidence must enter UI state or diagnostics;
- rollback, compensation, unlinking, merge, split or transaction movement is required;
- duplicate-transaction detection becomes necessary for acceptance;
- current duplicate-history repair becomes necessary for acceptance;
- existing financial baselines change;
- required tests, diagnostics, build, diff checks or manual verification fail;
- unapproved files are required.

---

## Completion Gate

Sprint 38 is complete only when:

- ADR-029 is accepted and the implementation matches it;
- only the approved production and test files changed;
- validation-gated advisory evaluation is read-only;
- exactly one explicit user outcome is required;
- confirmation-time identity and eligibility checks are authoritative;
- existing-account attachment preserves immutable identity and metadata;
- create-new-account behaviour remains intact;
- identifier attachment occurs inside confirmed import persistence;
- runtime stores change only after complete successful persistence;
- exactly one canonical forced hydration follows success;
- bounded verification and View Account navigation work by immutable account ID;
- SQLite relaunch restores the verified account and relationships;
- diagnostics and presentation contain only approved redacted information;
- duplicate history remains outside scope;
- focused tests pass;
- complete Xcode-native test plan passes;
- Xcode diagnostics pass;
- Xcode static analysis passes;
- Xcode clean build passes;
- `git diff --check` passes;
- manual verification passes;
- no unapproved source, test, schema, project or documentation changes are present.

---

## Implementation Handoff

After implementation validation passes, Codex must:

1. Review the complete diff.
2. Confirm only approved implementation files changed.
3. Run Xcode diagnostics.
4. Run Xcode static analysis.
5. Run a clean build.
6. Run focused Sprint 38 tests.
7. Run the complete Xcode-native test plan.
8. Run `git diff --check` and conflict-marker checks.
9. Complete manual verification.
10. Update only the verified implementation handoff documents.
11. Record exact test totals, validation results, manual result and commit state.

Do not claim Sprint 38 implementation completion before all completion-gate requirements pass.
