# ======= ACTIVE SPRINT =======

## Sprint 37 — Account Detail, Display Name & Import Provenance

### Status

🟢 Ready for Implementation

---

## Objective

Turn the existing Accounts page into a functional repository-backed master-detail experience.

The approved layout remains:

    Accounts page
    ├── complete account list
    └── existing right-side account inspector

Sprint 37 must:

1. Add deterministic account selection using immutable repository account IDs.
2. Preserve repository account and workspace references through hydration.
3. Add safe display-name editing without replacing account rows.
4. Present verified strong financial identifiers using deterministic redaction.
5. Present account-scoped recent activity and transaction counts.
6. Present trusted-transaction-backed import history.
7. Present read-only import-session detail inline within the existing inspector.
8. Preserve all identifiers, transactions, import-session relationships, balances, financial calculations and existing import behaviour.
9. Keep all persistence-to-runtime updates behind RepositoryStoreHydrator.

Do not add another account-detail destination, full-screen account page, or chevron to dedicated Accounts rows.

---

## Governing Architecture

Sprint 37 implements existing decisions from:

- ADR-024 — Repository Hydration Boundary
- ADR-025 — Stable Financial Entity Identity
- ADR-026 — Structured Developer Diagnostics
- ADR-027 — Parser-Owned Financial Identifier Extraction
- ADR-028 — Bounded Parser Source Evidence

No new ADR is required.

The canonical flow remains:

    Repositories
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

## Current Verified Gaps

The current repository and UI have these verified gaps:

- Dedicated Accounts rows are not selectable.
- The current inspector always displays the first Dashboard account summary.
- DashboardViewModel.accountSummaries is limited to three accounts and is also consumed by the Accounts page.
- Inspector recent activity is workspace-global rather than account-scoped.
- The visible star control is decorative and has no implemented behaviour.
- The inspector hardcodes Account Type as Repository account.
- The inspector hardcodes Status as Active.
- RepositoryStoreHydrator loses immutable repository references when creating runtime Account and Transaction values.
- TransactionStore contains a display-name-based account filter, which is unsuitable after account renaming.
- AccountRepository exposes replacement-style account upsert semantics but no targeted display-name mutation.
- SQLite account upsert uses INSERT OR REPLACE and must not be used for display-name editing.
- AccountDTO.description contains imported source metadata such as Imported from <filename> and must not be reused for notes.
- Import sessions can be associated with an account only through trusted transactions carrying both accountId and importSessionId.
- ImportSessionRepository reads one session by immutable ID and has no account-history query.
- FinancialIdentifier.redacted is the existing deterministic masking utility.

---

## Approved Production Flow

### Initial and forced hydration

    Repositories
          ↓
    RepositoryStoreHydrator
          ↓
    AccountStore
    TransactionStore
    ImportSessionStore or equivalent runtime aggregate
          ↓
    AccountsViewModel
          ↓
    Accounts page and inspector

The hydrator must:

- Load repository accounts.
- Preserve repository account ID and workspace ID in runtime account state.
- Load trusted transactions.
- Preserve repository account ID and import-session ID in runtime transaction state.
- Load each referenced import session once.
- Compose account-scoped history from trusted transaction relationships.
- Redact verified identifiers before they reach ViewModel or View presentation state.
- Replace runtime stores only after the complete hydration mapping succeeds.

### Display-name save flow

    Validate draft
          ↓
    Targeted repository display-name update
          ↓
    Repository write succeeds
          ↓
    RepositoryStoreHydrator(forceRefresh: true)
          ↓
    Runtime stores replaced
          ↓
    AccountsViewModel preserves selection by repository account ID

Do not mutate runtime stores optimistically.

---

## Repository Display-Name Mutation Contract

Add one targeted AccountRepository operation equivalent in responsibility to:

    updateAccountDisplayName(accountId, workspaceId, displayName)

Required semantics:

- Update only the persisted account name.
- Verify that the account exists.
- Verify workspace ownership.
- Reject empty values.
- Reject whitespace-only values.
- Preserve account ID.
- Preserve workspace ID.
- Preserve institution.
- Preserve account type.
- Preserve native currency.
- Preserve source description.
- Preserve creation timestamp.
- Preserve closure metadata.
- Preserve created-from-import-session provenance.
- Preserve verified identifiers.
- Preserve identifier provenance.
- Preserve transactions.
- Preserve import-session relationships.
- Do not use replacement-style upsert.
- Allow duplicate display names.
- Allow case-only changes.
- Treat unchanged trimmed input as a no-op.

The in-memory and SQLite providers must have equivalent observable behaviour.

No user-editable immutable account field may be included in the mutation contract.

---

## Runtime Repository-Reference Contract

Runtime Account must retain:

- immutable repository account ID
- workspace ID

Runtime Transaction must retain:

- repository account ID
- repository import-session ID

Existing runtime UUID presentation identities may remain where required for SwiftUI compatibility, but they must not be used for:

- repository selection
- account filtering
- mutation
- selection restoration
- identity matching

Display name, institution, currency and runtime UUID must never replace repository account ID for these operations.

---

## Runtime Import-Session State

RepositoryStoreHydrator must load the import-session records referenced by trusted transactions.

The approved runtime destination is:

    RepositoryStoreHydrator
          ↓
    ImportSessionStore
          ↓
    AccountsViewModel

A bounded equivalent runtime aggregate is permitted only when:

- it remains clearly owned by runtime state,
- it is populated only by RepositoryStoreHydrator,
- raw repository DTOs are not exposed directly to Views,
- it does not create a second persistence-to-runtime path.

For each distinct trusted transaction importSessionId associated with an account:

- load the persisted session once,
- retain only sessions whose account association is proven,
- preserve deterministic ordering,
- do not synthesize missing provenance.

Sessions without a proven account relationship must not appear in account history.

---

## AccountsViewModel Ownership

Create a dedicated AccountsViewModel.

Do not place Accounts-page selection, editing, history, or import-session detail behaviour into DashboardViewModel.

AccountsViewModel owns:

- the complete Accounts-page account collection,
- selected repository account ID,
- selected account presentation,
- account-scoped recent activity,
- account-scoped transaction count,
- account-scoped import history,
- selected import-session detail,
- display-name draft,
- edit state,
- input validation,
- Save,
- Cancel,
- repository failure presentation,
- post-save hydration,
- hydration-refresh failure presentation,
- deterministic empty states.

DashboardViewModel remains responsible for Dashboard presentation and retains its existing three-account summary limit.

---

## Account-Selection Contract

Selection must:

- use immutable repository account ID,
- default deterministically after hydration,
- preserve selection through forced hydration when the account remains available,
- fall back deterministically if the selected account disappears,
- never use display name,
- never use institution,
- never use currency,
- never use runtime UUID,
- never silently retarget an active edit draft.

The implementation must choose and test one deterministic policy:

- block account selection while editing, or
- require explicit Save or Cancel before selection changes.

The chosen policy must be visible to the user and must not discard a draft silently.

---

## Inspector Presentation Contract

Evolve the existing right-side inspector.

The inspector must display the selected account only.

Repository-backed or safely derived fields:

- display name,
- institution,
- account type,
- currency,
- current balance,
- transaction count,
- recent account activity,
- verified financial identity summaries,
- account-scoped import history.

Do not continue showing the hardcoded Repository account account type.

Do not continue showing hardcoded Active as repository truth.

Remove the Status row from the inspector.

Do not display Active, Unavailable, Not modelled, or another substitute until repository-backed account lifecycle semantics are implemented.

Map persisted account-type values to user-facing labels such as Bank Account or Credit Card. Do not expose raw repository enum strings.

Do not add closure semantics to Sprint 37.

The star control remains outside Sprint 37 scope.

Dedicated Accounts rows must remain without a chevron.

---

## Display-Name Editing Workflow

Use inline editing within the existing inspector.

Required behaviour:

- Edit enters draft mode.
- Save validates and persists the draft.
- Cancel discards the draft.
- Surrounding whitespace is trimmed.
- Empty input is rejected.
- Whitespace-only input is rejected.
- Duplicate names are allowed.
- Case-only changes are allowed.
- Unchanged trimmed input performs no repository write.
- Failed persistence leaves runtime state unchanged.
- Cancel performs no repository write.
- Draft values are never installed optimistically into runtime stores.
- Selection cannot silently change the edit target.

No maximum length may be invented without an existing repository convention.

Notes are excluded from this workflow.

---

## Save and Hydration Workflow

Required flow:

    AccountsViewModel validates draft
          ↓
    AccountMetadataCoordinator or equivalent Service invokes targeted repository mutation
          ↓
    Repository write succeeds
          ↓
    RepositoryStoreHydrator(forceRefresh: true)
          ↓
    AccountStore, TransactionStore and ImportSessionStore are replaced
          ↓
    AccountsViewModel restores selection by repository account ID

Reject:

- direct AccountStore mutation after save,
- optimistic runtime rename,
- ViewModel access to SQLite,
- ViewModel ownership of repositories,
- View access to repositories,
- any parallel persistence-to-presentation path.

Failure behaviour:

### Repository failure

- Do not hydrate.
- Runtime state remains unchanged.
- Present an actionable save failure.

### Repository success followed by hydration failure

- The persisted name remains durable.
- Runtime state remains at the previous complete hydrated state.
- Report a distinct saved, refresh failed condition.
- Allow deterministic retry or relaunch recovery.
- Do not claim rollback occurred.
- Do not install the draft into runtime state.

---

## Identity Presentation and Redaction

Show only verified strong identifiers.

Permitted fields:

- user-friendly identifier kind,
- redacted identifier value,
- strength,
- verification state,
- provenance category.

Redaction must use FinancialIdentifier.redacted before the value reaches ViewModel or View presentation state.

Do not expose:

- complete normalized identifiers,
- complete account numbers,
- complete IBANs,
- raw source fragments,
- repository IDs as financial identity,
- identifier values in diagnostics.

Weak and unverified identifiers must not appear as verified identity summaries.

---

## Account-Scoped Import-History Contract

Build read-only account history only from trusted transactions that contain both:

- repository account ID,
- repository import-session ID.

For each distinct referenced session, load the persisted ImportSessionRecordDTO once.

History may show:

- source document name,
- started date,
- completed date when available,
- persisted import/validation status,
- parser version when available,
- transaction count,
- transaction date range,
- currency where deterministically available.

History ordering must be deterministic:

1. newest persisted session date first,
2. immutable session ID as stable tie-breaker.

Do not include sessions whose account association cannot be proven.

Do not invent:

- separate persistence outcome,
- failure summary,
- validation-issue detail,
- document hash,
- document type,
- page count,
- unavailable document provenance.

No global import-history query or repository redesign is approved.

---

## Inline Import-Session Detail

Use an inline read-only drill-in within the existing account inspector.

Do not add:

- a new full-screen destination,
- a global import-session management view,
- import editing,
- retry,
- reversal,
- deletion.

The detail state may show only persisted or deterministically derived values already approved for account history.

---

## Privacy-Safe Diagnostics

Permitted events:

- account display-name update requested,
- account display-name update succeeded,
- account display-name update failed,
- account-detail hydration failed,
- import-history composition failed.

Do not log:

- old display name,
- new display name,
- raw identifier,
- source filename,
- source fragment,
- account number,
- IBAN,
- account notes,
- repository account ID unless existing diagnostic policy explicitly permits opaque internal IDs.

Diagnostics remain structured, concise, in memory, and non-authoritative.

---

## Production Scope

Modify only approved production files or justified new files:

    Database/Repository.swift
    Database/InMemoryRepositoryProvider.swift
    Database/SQLiteRepositoryProvider.swift
    Models/Account.swift
    Models/Transaction.swift
    Models/ImportSession.swift        # only if required for runtime representation
    Core/AccountStore.swift           # only if required for bounded runtime identity access
    Core/TransactionStore.swift       # only if repository-ID filtering is required
    Core/ImportSessionStore.swift     # if the dedicated runtime store design is used
    Services/RepositoryStoreHydrator.swift
    Services/AccountMetadataCoordinator.swift
    ViewModels/AccountsViewModel.swift
    ContentView.swift

DashboardViewModel.swift must remain unchanged except for unavoidable compilation compatibility caused by approved runtime-model changes. Its Dashboard-specific behaviour and three-account limit must remain unchanged.

New production files must:

- be added through Xcode,
- appear in the Xcode navigator,
- have correct target membership,
- avoid unrelated project-file modifications.

No DTO change is expected.

If DTO changes become necessary, stop and report before broadening scope.

---

## Test Scope

Modify or add only approved test files:

    LedgerForgeTests/RepositoryContractTests.swift
    LedgerForgeTests/AccountIdentifierRepositoryTests.swift
    LedgerForgeTests/IdentityResolverTests.swift
    LedgerForgeTests/RepositoryStoreHydratorTests.swift
    LedgerForgeTests/ImportRepositoryIntegrationTests.swift
    LedgerForgeTests/DeveloperDiagnosticsTests.swift
    LedgerForgeTests/AccountsViewModelTests.swift
    LedgerForgeTests/AccountMetadataCoordinatorTests.swift
    LedgerForgeTests/ImportSessionStoreTests.swift

Create only the new test files required by the selected production design.

Do not place Accounts-page behaviour tests into DashboardViewModelTests.swift.

DashboardViewModelTests.swift remains Dashboard-specific regression coverage.

Run unchanged regression suites including:

    LedgerForgeTests/CSVImportRegressionTests.swift
    LedgerForgeTests/ConfirmationGatedImportWorkflowTests.swift
    LedgerForgeTests/TransactionListViewModelTests.swift

Do not create a new test target.

---

## Required Automated Tests

### Repository mutation

1. Name update changes only AccountDTO.name.
2. Account ID remains unchanged.
3. Workspace remains unchanged.
4. Institution remains unchanged.
5. Account type remains unchanged.
6. Currency remains unchanged.
7. Description remains unchanged.
8. Creation timestamp remains unchanged.
9. SQLite name-only update leaves `closed_at` and `created_from_import_session_id` unchanged.
10. Missing account is rejected.
11. Workspace mismatch is rejected.
12. Empty input is rejected.
13. Whitespace-only input is rejected.
14. Duplicate names are accepted.
15. Case-only changes are accepted.
16. In-memory and SQLite providers behave equivalently.
17. Unrelated accounts remain unchanged.

### Identity and relationships

18. Identifier rows remain unchanged.
19. Identifier provenance remains unchanged.
20. Resolver returns the same account after rename.
21. Transactions retain repository account ID.
22. Transactions retain import-session ID.
23. Import sessions remain retrievable.
24. Later differently named imports reuse the renamed account.
25. No duplicate account is created.
26. No duplicate identifier is created.
27. SQLite relaunch restores the edited name and relationships.

### Hydration

28. Runtime accounts retain repository account and workspace IDs.
29. Runtime transactions retain account and import-session IDs.
30. Verified identifier summaries are redacted before presentation state.
31. Referenced import sessions hydrate deterministically.
32. Sessions are not duplicated.
33. History is scoped by repository account ID.
34. History counts use trusted transactions only.
35. History date ranges are correct.
36. History ordering is deterministic.
37. Forced hydration updates the display name.
38. Forced hydration does not duplicate accounts or transactions.

### AccountsViewModel

39. Accounts page exposes every account, not only three.
40. Dashboard summary remains limited to three.
41. Initial account selection is deterministic.
42. Selecting another account updates the inspector.
43. Selection survives forced hydration by repository account ID.
44. Recent activity excludes transactions belonging to other accounts.
45. Rename does not break activity association.
46. Empty account state is deterministic.
47. Empty identity state is deterministic.
48. Empty history state is deterministic.
49. Save trims outer whitespace.
50. Empty or whitespace-only draft performs no write.
51. Unchanged draft performs no write.
52. Cancel performs no write.
53. Failed repository write leaves stores unchanged.
54. Saved-but-refresh-failed produces a distinct state.
55. Draft cannot silently retarget another account.
56. Selected session drives the correct inline detail.

### Privacy

57. No raw identifier reaches ViewModel or View presentation state.
58. Diagnostics contain no raw identifier.
59. Diagnostics contain no edited display name.
60. Diagnostics contain no new source filename or source fragment.

### Regression

61. Sprint 36 account resolution remains unchanged.
62. Axis financial fixture remains 81 INR transactions with unchanged totals, ordering, balances and validation.
63. Existing import confirmation and cancellation remain unchanged.
64. Existing transaction search remains unchanged.
65. Existing credit/debit filtering remains unchanged.
66. Existing Dashboard calculations remain unchanged.
67. Complete Xcode-native test plan passes.

---

## Financial Regression Requirements

The approved Axis fixture must preserve:

- Axis parser selection,
- institution attribution,
- 81 INR transactions,
- transaction ordering,
- debit total,
- credit total,
- opening balance,
- closing balance,
- validation result,
- read-only preview,
- explicit confirmation requirement,
- cancellation without persistence,
- existing Dashboard presentation,
- repository hydration after successful import.

No financial calculation or approved baseline may change.

---

## Manual Runtime Verification

Using the approved Axis NRE CSV and an existing Sprint 36 SQLite database:

1. Launch the newly built application.
2. Open Accounts.
3. Confirm every persisted account appears.
4. Confirm dedicated Accounts rows contain no chevron.
5. If multiple accounts are present, select each account and verify the inspector changes. If only one account is present, verify deterministic initial selection and rely on automated multi-account selection coverage.
6. Verify account type is repository-backed.
7. Verify the Status row is absent.
8. Verify recent activity belongs only to the selected account.
9. Verify identifier values are redacted.
10. Begin editing and Cancel.
11. Verify no repository or runtime change.
12. Reject empty and whitespace-only values.
13. Save a value containing surrounding whitespace and verify trimming.
14. Attempt selection change during editing and verify the approved deterministic policy.
15. Save a valid display name.
16. Verify runtime changes only after repository persistence and hydration.
17. Verify institution, type, currency, balance, identifiers, transactions and sessions remain unchanged.
18. Open account import history.
19. Verify history ordering, source summary, status, counts and covered dates.
20. Open one inline read-only session detail.
21. Relaunch and verify the renamed account and history restore.
22. Import a later statement carrying the same verified identifier under a different filename.
23. Verify the existing renamed account is reused.
24. Verify no duplicate account or identifier appears.
25. Verify the new session appears under the same account.
26. Confirm Dashboard and Transactions behaviour remains unchanged.
27. Confirm Developer Console contains no raw identifiers, display-name values or newly logged source filenames.
28. Run the Axis CSV baseline and verify financial truth is unchanged.

---

## Explicit Exclusions

Do not implement:

- account notes,
- AccountDTO.description editing,
- schema changes,
- migrations,
- account closure or lifecycle editing,
- favourites or star behaviour,
- account ordering,
- colour or icon customization,
- institution editing,
- account-type editing,
- currency editing,
- verified-identifier editing,
- identifier attachment,
- identifier backfill,
- identity-conflict UI,
- account linking or unlinking,
- account merge or split,
- account archive,
- account deletion,
- global import history,
- import retry,
- import editing,
- import correction,
- import deletion,
- import reversal,
- validation redesign,
- persistence-outcome redesign,
- source-document persistence expansion,
- transaction multi-selection,
- transaction bulk actions,
- transaction deletion,
- transaction provenance UI,
- full account transaction-history drill-down,
- parser changes,
- reader changes,
- normalizer changes,
- new import formats,
- duplicate-detection redesign,
- financial calculation changes,
- general Dashboard redesign,
- general Accounts redesign,
- another account-detail destination.

---

## Acceptance Criteria

Sprint 37 is accepted only when:

- Dedicated Accounts rows are selectable.
- Selection uses immutable repository account ID.
- The Accounts page exposes the complete account collection.
- Dashboard presentation retains its existing three-account summary limit.
- The selected inspector displays only the selected account.
- Account type is no longer hardcoded as Repository account.
- The hardcoded Status row is removed.
- Runtime accounts retain repository account and workspace IDs.
- Runtime transactions retain repository account and import-session IDs.
- Display-name mutation updates only the persisted account name.
- Replacement-style account upsert is not used for rename.
- Duplicate names and case-only changes are supported.
- Empty and whitespace-only names are rejected.
- Unchanged trimmed input performs no write.
- Cancel performs no write.
- Failed repository persistence leaves runtime state unchanged.
- Successful persistence is followed by canonical forced hydration.
- Hydration failure is reported distinctly and does not install optimistic state.
- Existing identifiers and provenance remain unchanged.
- Existing transactions remain associated with the same account.
- Existing import sessions remain retrievable.
- Resolver behaviour remains unchanged after rename.
- Verified identity summaries are redacted before presentation state.
- Account history uses only proven trusted transaction relationships.
- Import history ordering is deterministic.
- No invented persistence outcome, failure summary or unavailable provenance is shown.
- No Sprint 37 diagnostic contains a raw identifier, old or new display name, source filename, or source fragment.
- In-memory and SQLite providers behave equivalently.
- SQLite relaunch restores renamed account metadata and relationships.
- Existing Axis financial values remain identical.
- Existing import confirmation and cancellation remain unchanged.
- Existing transaction search and credit/debit filtering remain unchanged.
- Existing Dashboard calculations remain unchanged.
- Focused tests pass.
- Complete Xcode-native test plan passes.
- Xcode diagnostics pass.
- Xcode static analysis passes.
- Xcode clean build passes.
- git diff --check passes.
- Manual runtime verification passes.
- No unapproved production, test, asset, schema, project or documentation changes are present.

---

## Stop Conditions

Stop implementation and report without expanding scope if:

- A rename requires replacement-style account upsert.
- Any immutable account property must be supplied by the UI.
- Selection or filtering must use display name.
- Repository references cannot survive hydration.
- Runtime refresh would bypass RepositoryStoreHydrator.
- Notes or reliable closure status become required for acceptance.
- Raw identifier values must enter presentation state.
- Import history requires speculative account association.
- History requires a schema migration or broad repository-query redesign.
- Parser, import, validation, duplicate-detection or financial-calculation changes become necessary.
- A View or ViewModel must access repositories or SQLite directly.
- The existing Accounts list-plus-inspector layout cannot be retained.
- Safe Xcode target membership cannot be achieved for justified new files.
- Files outside the approved production and test surface become necessary without explicit review.
- Existing financial regression values change.
- Required tests, build, diagnostics or manual verification fail.

---

## Implementation Handoff

After all implementation validation passes:

1. Review the final diff.
2. Confirm only approved production, test and justified Xcode membership changes are present.
3. Run Xcode diagnostics.
4. Run Xcode static analysis.
5. Run a clean build.
6. Run focused Sprint 37 tests.
7. Run the complete Xcode-native test plan.
8. Run git diff --check.
9. Complete manual runtime verification.
10. Commit with:

        Implement Sprint 37 account detail and provenance

11. Push to origin/main.
12. Verify the remote main commit.
13. Update only after successful implementation and validation:

        Project documents/PROJECT_STATE.md
        Project documents/Codex response.md

14. Record:

- exact files changed,
- repository-ID selection behaviour,
- targeted display-name mutation evidence,
- metadata-preservation evidence,
- identity and relationship-preservation evidence,
- hydration and refresh evidence,
- import-history composition evidence,
- privacy/redaction evidence,
- failure-gating evidence,
- exact test totals,
- build result,
- diagnostics result,
- static-analysis result,
- manual runtime result,
- implementation commit SHA,
- remote verification,
- current phase.

15. Create and push a separate documentation handoff commit where required.

Codex must not edit Project documents/Implementation.md during implementation.
