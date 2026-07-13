# =======ACTIVE SPRINT==========

## Sprint 34 — Bounded Parser Source Context

### ### Status

🟢 Ready for Implementation

---

## Objective

Carry ordered, bounded and uninterpreted pre-transaction source evidence into the existing `NormalizedDocument` parser input.

Sprint 34 changes parser-input plumbing only.

It must preserve all current:

- normalized transaction rows
- parser selection
- parser behaviour
- `FinancialDocument` output
- financial calculations
- validation behaviour
- persistence behaviour
- runtime behaviour
- user-facing behaviour

No financial identifier extraction or interpretation is performed.

---

## Governing Architecture

Sprint 34 implements ADR-028 — Bounded Parser Source Evidence.

It must also preserve:

- ADR-012 — Separation of Readers and Parsers
- ADR-016 — Universal Import Pipeline
- ADR-019 — Reference Fixtures Define Financial Truth
- ADR-027 — Parser-Owned Financial Identifier Extraction

The approved responsibility flow is:

```text
Extracted CSV text
        ↓
CSVAnalyzer identifies first transaction boundary
        ↓
CSVNormalizer
├─ normalized transaction rows
└─ bounded pre-transaction source context
        ↓
NormalizedDocument
├─ document
├─ metadata
├─ rows
└─ sourceContext
        ↓
StatementParser
```

Generic processing transports evidence.

The selected parser remains the only component permitted to interpret that evidence as financial identity.

---

## Scope

Include only:

- Add bounded source-context types to `NormalizedDocument`.
- Preserve existing `NormalizedDocument` construction through a default empty context.
- Add `CSVNormalizationResult`.
- Add a context-aware CSV normalization operation.
- Retain the existing row-only normalization API as a compatibility wrapper.
- Preserve exact existing normalized transaction-row behaviour.
- Update `ImportEngine` to obtain rows and context from one normalization operation.
- Pass the context unchanged into `NormalizedDocument`.
- Add focused tests for source preservation, boundaries, compatibility and financial regression.
- Preserve empty `financialIdentifiers` from the Axis parser.

---

## Approved Type Contract

### `NormalizedDocument.SourceFragment`

Add a nested immutable type:

```swift
struct SourceFragment {
    let sourceOrdinal: Int
    let text: String
}
```

Contract:

- `sourceOrdinal` is one-based.
- `text` contains the exact extracted source-line content.
- The newline delimiter is not included.
- Text is not trimmed or otherwise normalized.
- Empty text is valid and represents an empty extracted line.
- No protocol conformance is added unless production compilation requires it.

### `NormalizedDocument.SourceContext`

Add a nested immutable type:

```swift
struct SourceContext {
    let preTransactionFragments: [SourceFragment]

    static let empty: SourceContext
}
```

Contract:

- `preTransactionFragments` remains in original source order.
- The collection contains only lines appearing before the first transaction.
- The collection may contain the transaction header when that header precedes the first transaction.
- The first transaction is excluded.
- All later source lines are excluded.
- No institution-specific fields are permitted.
- No protocol conformance is added unless production compilation requires it.

### `NormalizedDocument`

Add:

```swift
let sourceContext: SourceContext
```

Provide an explicit initializer equivalent to:

```swift
init(
    document: Document,
    metadata: DocumentMetadata,
    rows: [NormalizedRow],
    sourceContext: SourceContext = .empty
)
```

Existing construction that supplies only `document`, `metadata`, and `rows` must continue compiling unchanged.

---

## Approved CSV Normalization Contract

### `CSVNormalizationResult`

Define an immutable result type in `Normalizers/CSVNormalizer.swift`:

```swift
struct CSVNormalizationResult {
    let rows: [NormalizedRow]
    let sourceContext: NormalizedDocument.SourceContext
}
```

Do not add `Equatable`, `Codable`, `Sendable`, or unrelated conformances.

### Context-aware operation

Add:

```swift
func normalizeWithSourceContext(
    text: String,
    document: Document
) -> CSVNormalizationResult
```

This operation is the canonical production normalization path.

It must split the extracted text into source lines once and derive both:

- normalized transaction rows
- bounded pre-transaction source context

from that same line collection.

### Compatibility operation

Retain:

```swift
func normalize(
    text: String,
    document: Document
) -> [NormalizedRow]
```

The existing method must become a compatibility wrapper equivalent to:

```swift
normalizeWithSourceContext(
    text: text,
    document: document
).rows
```

It must not contain a second independent normalization implementation.

---

## Source-Context Boundary Rules

Given a valid one-based `firstTransactionRow`:

- Context begins at source ordinal `1`.
- Context ends at source ordinal `firstTransactionRow - 1`.
- The source line at `firstTransactionRow` is excluded.
- Every later source line is excluded.

For each included source line:

- preserve exact textual content
- preserve empty lines
- preserve ordering
- assign the original one-based source ordinal
- exclude only the newline delimiter

Do not:

- trim whitespace
- parse delimiters
- split fields
- remove empty lines
- classify labels
- identify account numbers
- identify IBAN values
- identify customer identifiers
- infer institution-specific meaning

If the existing normalization preconditions fail because the delimiter or first-transaction boundary is missing or invalid:

- return an empty `rows` collection
- return `SourceContext.empty`

Do not invent a fallback boundary.

---

## Normalized-Row Compatibility

The `rows` produced by `normalizeWithSourceContext` must remain exactly equivalent to the rows produced by the current `normalize` implementation.

Preserve the current transaction-area behaviour:

- begin at the first transaction
- skip lines that are empty after whitespace trimming
- split using the analyzed delimiter
- preserve empty delimited fields
- trim whitespace and newline characters from normalized values
- retain the existing one-based normalized row number

Source-context preservation must not alter transaction normalization.

---

## ImportEngine Wiring

Update the private CSV processing path to use:

```swift
let normalization = CSVNormalizer().normalizeWithSourceContext(
    text: contents,
    document: document
)
```

`ImportFormatProcessingResult` shall carry the coherent `CSVNormalizationResult` rather than independently produced rows and context.

Construct `NormalizedDocument` using:

- `normalization.rows`
- `normalization.sourceContext`

`ImportEngine` must transport the context without examining its fragment text.

It must not:

- search for labels
- identify account values
- construct identifiers
- verify identifiers
- log fragment content
- store context in `PreparedImport`
- store context in `FinancialDocument`
- pass context to persistence
- retain context after parser execution

Existing institution detection and parser-registry behaviour remain unchanged.

---

## Explicit Exclusions

Do NOT:

- modify `StatementParser`
- modify `AxisBankAccountParser`
- modify any other parser
- extract financial identifiers
- produce non-empty Axis `financialIdentifiers`
- add institution-specific source matching
- modify readers
- modify `Document`
- modify `DocumentMetadata`
- modify `FinancialDocument`
- modify validation
- modify `PreparedImport`
- modify `ImportPersistenceCoordinator`
- modify `ImportPersistenceMapper`
- call `FinancialIdentityResolver`
- perform repository lookup
- perform account matching
- reuse accounts
- attach identifiers
- modify DTOs
- modify repositories
- modify SQLite
- add migrations
- modify runtime stores
- modify ViewModels
- modify Views
- modify UI
- modify approved financial calculations
- log source-fragment text
- add automatic `Equatable`, `Codable`, or `Sendable` conformances
- implement source context for PDF, XLS, XLSX, or TXT

---

## Expected Files

### Production

- `Models/NormalizedDocument.swift`
- `Normalizers/CSVNormalizer.swift`
- `Services/ImportEngine.swift`

No other production files.

### Tests

- `LedgerForgeTests/CSVImportRegressionTests.swift`

Focused Sprint 34 tests should be added to the existing test file to avoid creating an unrelated project-membership change.

### Planning Documents

The following Chat-owned planning documents are frozen before Codex implementation:

- `Project documents/ADR.md`
- `Project documents/Implementation.md`

Codex must not modify either document.

No Xcode project-file change is expected.

---

## Required Focused Tests

Add focused tests proving:

### Source preservation

- pre-transaction fragments preserve exact source-line text
- leading and trailing spaces remain intact
- empty pre-transaction lines are retained
- fragments remain in original order
- source ordinals are one-based
- source ordinals correspond to their original extracted line positions

### Boundary correctness

- the transaction header is included when it precedes the first transaction
- the first transaction is excluded
- every later transaction line is excluded
- invalid or absent boundaries return empty context
- invalid or absent normalizer prerequisites preserve the current empty-row behaviour

### Compatibility

- `normalize(...)` rows equal `normalizeWithSourceContext(...).rows`
- existing `NormalizedDocument` construction defaults to empty source context
- explicitly supplied source context is preserved without mutation
- no protocol conformance is required for field inspection

### Financial regression

Update the approved Axis CSV fixture path to construct `NormalizedDocument` with the new normalization result.

Verify that all approved baseline values remain unchanged, including:

- parser identity
- institution
- transaction count
- currency
- debit total
- credit total
- opening balance
- closing balance
- validation result

Verify that Axis continues returning:

```swift
financialIdentifiers: []
```

---

## Acceptance Criteria

Sprint 34 is accepted only when all of the following are true:

- `NormalizedDocument` exposes immutable `sourceContext`.
- Existing three-argument construction remains source-compatible.
- Source context defaults to empty.
- `SourceFragment` contains only `sourceOrdinal` and `text`.
- `SourceContext` contains only ordered pre-transaction fragments.
- Source ordinals are one-based.
- Exact extracted line content is preserved, excluding newline delimiters.
- Empty pre-transaction lines are preserved.
- The first transaction is excluded.
- Post-boundary content is excluded.
- Generic code performs no institution-specific interpretation.
- `CSVNormalizationResult` contains rows and source context.
- `normalizeWithSourceContext` performs one coherent line-splitting and normalization operation.
- Existing `normalize` remains as a compatibility wrapper.
- Existing normalized rows remain identical.
- `ImportEngine` passes context into `NormalizedDocument` without interpreting it.
- Context is not retained in `PreparedImport`.
- Source-fragment text is not logged.
- The parser protocol remains unchanged.
- Parser implementations remain unchanged.
- Axis continues returning an empty identifier collection.
- No resolver, repository, persistence, database, runtime-store, ViewModel, or UI integration is introduced.
- No unnecessary protocol conformances are added.
- Focused tests pass.
- Existing CSV financial regression passes unchanged.
- Xcode diagnostics pass.
- Xcode build passes.
- The complete Xcode-native test plan passes.
- Manual runtime verification confirms unchanged Axis import-preview behaviour.

---

## Validation

Run:

- Xcode diagnostics for every modified Swift file
- Xcode clean build
- focused `CSVImportRegressionTests`
- complete Xcode-native test plan
- existing Axis CSV financial regression
- `git diff --check`

Inspect the final diff and confirm:

- only expected production and test files changed
- normalized transaction logic is unchanged
- no parser changed
- no identifier extraction exists
- no source-fragment content appears in diagnostics
- no planning document was modified by Codex
- no project file changed

### Manual Runtime Verification

Using the approved Axis Bank NRE CSV fixture:

- launch the newly built application
- prepare the import
- confirm the existing parser is selected
- confirm the read-only preview appears
- confirm approved financial values remain unchanged
- confirm validation behaviour remains unchanged
- cancel without persistence
- confirm the application returns to its previous state normally
- confirm no new financial-identity UI or runtime behaviour appears

---

## Stop Conditions

Stop implementation and report without working around the boundary if:

- parser changes are required
- identifier extraction is required
- institution-specific label matching is required
- the first transaction cannot remain excluded from context
- normalized transaction rows would change
- the complete source document or post-transaction content must be retained
- source context must be stored in `Document`, `PreparedImport`, or `FinancialDocument`
- source-fragment content must be logged
- reader contracts must change
- parser protocol signatures must change
- a second independent normalization implementation would be required
- `ImportEngine` must interpret source fragments
- any new `Equatable`, `Codable`, or `Sendable` conformance becomes necessary
- resolver, repository, account matching, account reuse, attachment, persistence, SQLite, runtime-store, ViewModel, or UI changes become necessary
- approved Axis financial regression values cannot remain identical
- implementation requires production files outside the approved surface

Do not work around these conditions.

---

## Completion

Sprint 34 is complete only when:

- the implementation remains inside the approved boundary
- every acceptance criterion passes
- automated validation passes
- manual runtime verification passes
- the implementation report identifies the exact files changed
- repository state is clean after the approved documentation handoff process

Sprint 35 may begin only after Sprint 34 proves that the Axis parser receives the required bounded evidence while continuing to produce no financial identifiers.
