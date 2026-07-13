# =======ACTIVE SPRINT==========

## Sprint 35 — Verified Axis Account Identifier Extraction

### Status

🟢 Ready for Implementation

---

## Objective

Update `AxisBankAccountParser` so it deterministically produces one verified, strong `FinancialIdentifier` when `NormalizedDocument.sourceContext` contains one unambiguous full Axis account-number field.

The approved flow is:

```text
NormalizedDocument.sourceContext
            ↓
AxisBankAccountParser
            ↓
FinancialIdentifier
├─ kind: institutionAccountId
├─ strength: strong
├─ verificationState: verified
└─ provenance: institutionStructuredField
            ↓
FinancialDocument.financialIdentifiers
```

Sprint 35 changes Axis parser identifier output only.

It must preserve all current:

- parser selection
- institution
- transaction output and ordering
- currency
- debit and credit totals
- opening and closing balances
- financial calculations
- validation behaviour
- persistence behaviour
- runtime behaviour
- user-facing behaviour

---

## Governing Architecture

Sprint 35 implements the existing decisions in:

- ADR-012 — Separation of Readers and Parsers
- ADR-019 — Reference Fixtures Define Financial Truth
- ADR-025 — Stable Financial Entity Identity
- ADR-027 — Parser-Owned Financial Identifier Extraction
- ADR-028 — Bounded Parser Source Evidence

Only the selected statement parser may interpret source context and classify an identifier as verified.

Generic normalization, orchestration, validation and persistence components must not interpret financial identity.

Source context remains transient. Source-fragment text and unredacted identifiers must not be stored or logged.

---

## Approved Evidence

The approved Axis CSV fixture contains a structured pre-transaction source line equivalent to:

```text
Statement of Account No - <full numeric account identifier> for the period (...)
```

Use the exact fixture content present in the repository as the authoritative source.

Do not hard-code the fixture's account number.

---

## Production Scope

Modify only:

```text
Parsers/AxisBankAccountParser.swift
```

Permitted production changes:

- Add private Axis-specific extraction helpers.
- Inspect only:

```swift
document.sourceContext.preTransactionFragments
```

- Recognise the supported full Axis statement-account-number field.
- Extract the complete unmasked numeric account value.
- Construct:

```swift
FinancialIdentifier(
    kind: .institutionAccountId,
    rawValue: extractedValue,
    verificationState: .verified,
    provenance: .institutionStructuredField
)
```

- Deduplicate repeated identical matches.
- Reject conflicting, malformed, masked or weak evidence.
- Return the resulting identifier collection from both parser result paths, including the empty-transaction path.

Do not make identifier extraction dependent on successful transaction parsing or transaction-loop execution.

---

## Deterministic Extraction Rules

Accept evidence only when:

- The source field represents the full statement account number.
- The extracted value contains only decimal digits.
- At least one digit is present.
- The value is unmasked.
- Exactly one unique valid full value exists.

Required outcomes:

| Evidence | Output |
|---|---|
| One valid full account value | One verified identifier |
| Same valid value repeated | One deduplicated identifier |
| No supported field | Empty collection |
| Empty source context | Empty collection |
| Masked or suffix-only value | Empty collection |
| Malformed value | Empty collection |
| Two different valid full values | Empty collection |
| Customer ID, IFSC, MICR, PAN, mobile, email or unrelated fields | Ignore |

Identity extraction must be fail-soft.

Missing, unsupported or ambiguous identity evidence must never cause an otherwise valid statement import to fail.

Do not throw solely because identifier extraction failed.

Do not print or log source fragments or unredacted identifier values.

---

## Test Scope

Modify only the necessary existing test files:

```text
LedgerForgeTests/FinancialDocumentTests.swift
LedgerForgeTests/CSVImportRegressionTests.swift
```

Do not create a new test target or change Xcode project membership unless compilation proves it unavoidable. Stop and report if that becomes necessary.

No fixture or expected-JSON changes are required unless implementation discovers a genuine testing need.

### Fixture-Path Correction

`FinancialDocumentTests` currently uses the row-only normalization compatibility path.

Update its approved Axis fixture helper to use:

```swift
let normalization = CSVNormalizer().normalizeWithSourceContext(
    text: text,
    document: document
)
```

Construct `NormalizedDocument` with:

```swift
rows: normalization.rows,
sourceContext: normalization.sourceContext
```

This is required so parser-level tests exercise the actual Sprint 35 evidence path.

---

## Required Focused Tests

Add focused tests proving:

### Approved Axis Fixture

- Exactly one identifier is produced.
- Its kind is `.institutionAccountId`.
- Its strength is `.strong`.
- Its verification state is `.verified`.
- Its provenance is `.institutionStructuredField`.
- Its normalized value exactly matches the full structured account field from the fixture.
- The full fixture account number is not printed in test names, failure messages, diagnostics or logs.

Direct value assertions are permitted.

### Missing Context

- Existing transaction output remains unchanged.
- The identifier collection remains empty.

### Masked or Suffix-Only Evidence

- A masked or suffix-only account field produces no verified identifier.

### Unrelated Structured Fields

- Customer ID, IFSC, MICR and other unrelated header values are not emitted.

### Duplicate Evidence

- Duplicate identical full account fields produce exactly one identifier.

### Conflicting Evidence

- Two different valid full account values produce no identifier.
- Financial parsing continues normally.

### Malformed Evidence

- Malformed account evidence produces no identifier.
- No parser error occurs solely because identity extraction failed.

### Financial Parsing Independence

- Financial transactions still parse when identifier extraction returns no result.
- Identifier interpretation is exercised for both parser result paths, including the empty-transaction path.

---

## Financial Regression Requirements

The approved Axis fixture must preserve:

- parser selection
- institution
- 81 transactions
- currency
- debit total
- credit total
- opening balance
- closing balance
- transaction ordering
- validation result
- existing import-preview behaviour

Sprint 35 changes identifier output only.

---

## Explicit Exclusions

Do NOT:

- modify `StatementParser`
- modify `NormalizedDocument`
- modify `CSVNormalizer`
- modify `ImportEngine`
- modify readers
- modify `Document` or `DocumentMetadata`
- modify `FinancialDocument`
- integrate `FinancialIdentityResolver`
- perform repository lookup
- perform account matching or reuse
- attach identifiers to repository records
- modify persistence coordination
- modify DTOs or repository protocols
- modify SQLite or migrations
- modify runtime stores
- modify ViewModels
- modify Views or UI
- implement PDF, XLS, XLSX or TXT identifier extraction
- emit customer IDs, IFSC, MICR, PAN, mobile numbers or email addresses
- emit masked identifiers, account suffixes or weak identifiers
- log source-fragment text
- log unredacted identifiers
- change transaction parsing
- change financial calculations
- edit `Project documents/ADR.md`
- edit `Project documents/Implementation.md`

The planning documents are Chat-owned and frozen before Codex implementation.

---

## Expected Files

### Production

- `Parsers/AxisBankAccountParser.swift`

No other production file.

### Tests

- `LedgerForgeTests/FinancialDocumentTests.swift`
- `LedgerForgeTests/CSVImportRegressionTests.swift`

No new test target or Xcode project-file change is expected.

### Planning Documents

The following Chat-owned planning documents are frozen before Codex implementation:

- `Project documents/ADR.md`
- `Project documents/Implementation.md`

Codex must not modify either document during implementation.

---

## Acceptance Criteria

Sprint 35 is accepted only when all of the following are true:

- The approved Axis fixture produces exactly one verified strong account identifier.
- The identifier kind is `.institutionAccountId`.
- The identifier strength is `.strong`.
- The verification state is `.verified`.
- The provenance is `.institutionStructuredField`.
- The normalized value equals the full structured account value from the fixture.
- Weak, masked, suffix-only, malformed and ambiguous evidence produces no identifier.
- Duplicate identical full values produce one deduplicated identifier.
- Unrelated structured fields are ignored.
- Missing or empty context produces no identifier.
- No financial import fails solely because identifier extraction fails.
- Both parser return paths use the extracted identifier collection.
- Existing financial values remain identical.
- Parser selection and validation remain unchanged.
- Focused tests pass.
- The complete Xcode-native test plan passes.
- Xcode diagnostics pass.
- Xcode static analysis passes.
- Xcode clean build passes.
- `git diff --check` passes.
- Manual import preview remains unchanged.
- No raw identifier or source-fragment text is logged.
- No resolver, persistence, account-matching or UI behaviour appears.
- No production file outside `Parsers/AxisBankAccountParser.swift` changes.
- No project-file change occurs.
- Planning documents remain untouched during implementation.

---

## Validation

Run:

1. Xcode diagnostics for every modified Swift file.
2. Xcode static analysis.
3. Xcode clean build.
4. Focused `FinancialDocumentTests`.
5. Focused `CSVImportRegressionTests`.
6. Complete Xcode-native test plan.
7. Existing Axis CSV financial regression.
8. `git diff --check`.

Inspect the final diff and confirm:

- Only approved production and test files changed.
- Identifier extraction exists only inside `AxisBankAccountParser`.
- No generic component interprets source evidence.
- No raw account identifier is logged.
- Transaction parsing remains unchanged.
- No resolver or persistence integration was introduced.
- Planning documents remain untouched.
- No project-file change occurred.

### Manual Runtime Verification

Using the approved Axis Bank NRE CSV fixture:

- Launch the newly built application using the Xcode integration.
- Prepare the import.
- Confirm the Axis parser remains selected.
- Confirm the read-only preview appears normally.
- Confirm the transaction count and approved financial values remain unchanged.
- Confirm no new financial-identity UI appears.
- Cancel without persistence.
- Confirm normal return to the previous application state.

Do not expose the account identifier in UI or diagnostics.

---

## Stop Conditions

Stop implementation and report without working around the boundary if:

- Reliable extraction requires modifying `CSVNormalizer`, `ImportEngine`, readers or `NormalizedDocument`.
- The source field does not contain a complete unmasked account identifier.
- Verification requires inference from filenames, institution labels, display names, suffixes or masked values.
- Identifier extraction would need to throw and fail an otherwise valid import.
- Repository lookup, resolver integration or persistence is required.
- Transaction parsing or approved financial results would change.
- Source-fragment content must be logged.
- Production files outside the approved surface are required.
- An Xcode project-file change becomes necessary.
- Planning documents would need modification.

Do not work around these conditions.

---

## Implementation Handoff

After all validation and manual runtime verification pass:

1. Review the final diff.
2. Confirm the working tree contains only approved Sprint 35 changes.
3. Commit the implementation with:

```text
Implement Sprint 35 verified Axis account identifier extraction
```

4. Push to `origin/main`.
5. Verify the remote `main` commit.
6. Update only:

```text
Project documents/PROJECT_STATE.md
Project documents/Codex response.md
```

7. Record:
   - files changed
   - extraction behaviour
   - exact test totals
   - build result
   - static-analysis result
   - manual runtime result
   - commit hash
   - push verification
   - deferred resolver and persistence work
   - current phase: awaiting Sprint 36 planning
8. Commit and push the documentation handoff separately.

Do not modify `Project documents/Implementation.md` during handoff.

---

## Completion

Sprint 35 is complete only when:

- the implementation remains inside the approved parser-only boundary
- every acceptance criterion passes
- automated validation passes
- manual runtime verification passes
- the implementation report identifies the exact files changed and exact validation evidence
- the implementation commit and documentation handoff are pushed and verified
- repository handoff records the implementation and awaits Sprint 36 planning

Sprint 36 remains the earliest appropriate point for `FinancialIdentityResolver` integration.
