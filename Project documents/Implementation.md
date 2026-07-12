# =======ACTIVE SPRINT==========

## Sprint 33 — Parser Financial Identifier Handoff

### Status

🟢 Ready for Implementation

---

## Objective

Implement the parser-owned `FinancialIdentifier` handoff defined by ADR-027.

This sprint introduces immutable `FinancialIdentifier` support into `FinancialDocument` while preserving identical runtime behaviour.

No identity resolution or repository integration is performed.

---

## Scope

Include only:

- Add immutable `financialIdentifiers: [FinancialIdentifier]` to `FinancialDocument`.
- Default the initializer parameter to `[]`.
- Keep `StatementParser` protocol signature unchanged.
- Update the production `AxisBankAccountParser` to explicitly return an empty identifier collection.
- Document parser ownership of verified identifiers.
- Add focused `FinancialDocument` and `ImportValidator` tests.
- Preserve identical parser output, validation behaviour and runtime behaviour.

---

## Explicit Exclusions

Do NOT:

- extract identifiers
- modify parser inputs
- modify `CSVNormalizer`
- modify `NormalizedDocument`
- modify readers
- modify `ImportEngine`
- modify `ImportPersistenceCoordinator`
- modify `ImportPersistenceMapper`
- call `FinancialIdentityResolver`
- perform repository lookup
- reuse accounts
- attach identifiers
- modify DTOs
- modify repositories
- modify SQLite
- modify `RepositoryStoreHydrator`
- modify runtime stores
- modify ViewModels
- modify Views
- modify UI
- change financial calculations

---

## Expected Files

Production:

- `Models/FinancialDocument.swift`
- `Parsers/StatementParser.swift` (documentation only)
- `Parsers/AxisBankAccountParser.swift`

Tests:

- `LedgerForgeTests/FinancialDocumentTests.swift`
- `LedgerForgeTests/ImportValidatorTests.swift`

No other implementation files.

---

## Architectural Contract

- Verified `FinancialIdentifier` objects originate exclusively inside `StatementParser` implementations.
- Statement parsers are the only components permitted to classify an identifier as verified.
- `FinancialDocument` carries an immutable collection of parser-produced `FinancialIdentifier` values.
- `ImportEngine` and `ImportPersistenceCoordinator` do not derive or extract identifiers.
- `FinancialIdentityResolver` is not integrated in this sprint.
- Weak parser-derived values, including display names, filenames, institution labels, account text, masked values and suffixes, are not promoted to verified identifiers.
- Existing repository contracts and the SQLite schema remain unchanged.

---

## Acceptance Criteria

- `FinancialDocument` exposes immutable `[FinancialIdentifier]` through a `let financialIdentifiers` property.
- The initializer parameter defaults to an empty collection.
- Every existing initializer call remains source-compatible.
- `StatementParser.parse(document:)` retains its current signature.
- The parser protocol documents parser ownership of identifier extraction and verification.
- Both Axis parser result branches explicitly produce an empty identifier collection.
- Current Axis parser transaction output, metadata, parser name and financial values remain unchanged.
- A non-empty synthetic parser-produced collection is preserved exactly by `FinancialDocument`.
- Current Axis parser output is verified to contain no identifiers until a parser-input/extraction sprint is approved.
- `ImportValidator` behavior is identical for documents with and without identifiers.
- Validation does not mutate identifiers or transactions.
- No resolver, repository lookup, account matching, account reuse or persistence integration is introduced.
- No DTO, repository, SQLite, schema or migration change is introduced.
- No runtime store, ViewModel or UI change is introduced.
- Focused FinancialDocument and validator tests pass.
- Existing CSV financial regression tests pass unchanged.
- Xcode diagnostics, Xcode build and the complete Xcode-native test plan pass.

---

## Validation

Run the required validation for the implementation:

- Xcode diagnostics
- Xcode build
- complete Xcode-native test plan
- existing CSV financial regression tests

Confirm that parser output, validation behaviour and runtime behaviour remain unchanged.

---

## Stop Conditions

Stop implementation and report if:

- Sprint 33 requires producing a non-empty verified Axis identifier from the current parser input
- extracting an identifier requires raw pre-header text, `NormalizedDocument`, `CSVNormalizer` or reader changes
- a weak or masked value would need to be promoted to verified
- `ImportEngine` or `ImportPersistenceCoordinator` would need to derive identifiers
- `FinancialIdentityResolver` would need to consume the collection
- repository lookup, account reuse, account matching or identifier attachment would be required
- any DTO, repository contract, SQLite schema or migration would need to change
- validator behavior would need to depend on identifiers
- `FinancialDocument` would need new `Codable`, `Equatable` or `Sendable` conformance
- runtime stores, `RepositoryStoreHydrator`, ViewModels or Views would need modification
- existing parser selection, transaction extraction or approved financial baselines cannot remain unchanged

Do not work around these boundaries.

---

## Completion

Sprint 33 is complete only when all acceptance criteria and required validation pass, the implementation remains within the expected files, and no excluded component or behaviour has been changed.
