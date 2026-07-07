# Codex Response

# Sprint 14 - Implementation: Parser Selection Framework

## Summary
Implemented the deterministic Parser Selection Framework for Sprint 14.

The new parser-selection layer sits after Institution Detection and Statement Classification and before Statement Parser execution. It wraps the existing `StatementParserRegistry` instead of replacing or duplicating parser logic.

Production import behaviour was not changed. Parser execution, transaction extraction, validation, repository persistence and UI behaviour remain unchanged.

## Files Created
- `Parsers/ParserSelection.swift`
  - Adds the typed parser-selection result used by the selector.
  - Captures the selected parser, parser name, match state, confidence, explainable reasons and legacy metadata.

- `Parsers/StatementParserSelector.swift`
  - Adds deterministic parser selection from `Document`, `ImportInstitutionCandidate` and `StatementClassification`.
  - Bridges framework institution/classification results into legacy `DocumentMetadata`.
  - Delegates parser lookup to `StatementParserRegistry`.
  - Does not execute parsers.

- `LedgerForgeTests/StatementParserSelectionTests.swift`
  - Adds parser-selection coverage for Axis CSV, Axis PDF, unknown institution, unknown statement type and unsupported institution code.

## Files Modified
- `LedgerForge.xcodeproj/project.pbxproj`
  - Updated by Xcode when adding the new Sprint 14 source and test files to the navigator and target membership.

- `Project documents/Codex response.md`
  - Replaced planning notes with this Sprint 14 implementation record.

## Build Result
Passed.

Validation performed:
- Xcode `BuildProject`: passed.

Command-line `xcodebuild test` with writable DerivedData reached compilation but failed on the known Xcode/SwiftUI `#Preview` macro tooling issue:

```text
External macro implementation type 'PreviewsMacros.SwiftUIView' could not be found for macro 'Preview(_:body:)'
```

Per project workflow, the equivalent Xcode regression suite was run and treated as authoritative after the successful build.

## Test Result
Passed.

Xcode `RunSomeTests` result:

```text
42 tests: 42 passed, 0 failed, 0 skipped, 0 expected failures, 0 not run
```

Suites covered:
- `StatementParserSelectionTests`
- `StatementClassificationTests`
- `InstitutionDetectionTests`
- `CSVImportRegressionTests`
- `PDFDocumentReaderTests`
- `ImportFrameworkTests`
- `DefaultReaderRegistryTests`
- `PasswordProviderTests`

Conflict-marker scan:

```text
rg -n "^(<<<<<<<|=======|>>>>>>>)" .
```

No unresolved merge conflict markers found.

## Behavioural Impact
No user-visible behaviour changed.

CSV import still uses the existing production path and existing parser execution. The new selector is framework-compatible infrastructure only.

## Architecture Decisions
- Parser Selection is deterministic and explainable.
- Parser Selection consumes Institution Detection and Statement Classification outputs.
- Parser Selection maps framework context into legacy `DocumentMetadata` only as a compatibility bridge.
- Parser Selection delegates to `StatementParserRegistry` so existing parser registration remains authoritative.
- Parser Selection does not parse statements, create transactions, validate data, persist data or update UI.

## Remaining Technical Debt
- Production `ImportEngine` still calls `StatementParserRegistry` directly. Migrating production parser selection through `StatementParserSelector` belongs to a later sprint.
- Parser selection currently has one registered production parser: Axis Bank account statements.
- Parser selection result is internal to the app target and not yet surfaced through `ImportCoordinator`.

## Remaining Risks
- Future parser support must avoid broad metadata matches that could create false positives.
- PDF parser selection currently verifies context selection only; PDF transaction parsing remains explicitly out of scope.
- Additional institutions will need deterministic signatures, classifications and parser-selection tests before parser registration.

## Next Recommended Sprint
Sprint 15 - FinancialDocument Integration.

Recommended objective:
- Integrate the deterministic import stages into a `FinancialDocument` handoff without changing parser extraction rules, validation behaviour, repository persistence or UI behaviour.
