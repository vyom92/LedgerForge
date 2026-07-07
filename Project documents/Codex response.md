# Codex Response

## Sprint 12C Summary

Sprint 12C implementation added a deterministic, framework-compatible Institution Detection foundation scoped to approved Axis CSV/PDF fixtures.

Implemented:

- Added a signature/rule-based detector for institution detection.
- Preserved the existing legacy `InstitutionDetector().detect(from:)` API and observable Axis/unknown behavior.
- Added framework-compatible detection through `ImportFramework.InstitutionDetector` using `RawDocument`.
- Added explainable detection reasons through `ImportInstitutionCandidate.reasons` without breaking existing initializer call sites.
- Added focused tests for Axis CSV detection, Axis PDF detection, unknown documents, detection reasons, confidence behavior and non-text `RawDocument` handling.

Not implemented:

- No parser rewrites.
- No transaction extraction changes.
- No validation changes.
- No repository changes.
- No UI changes.
- No OCR.
- No AI inference.
- No Keychain changes.
- No XLS/XLSX support.
- No Sprint 13 work.
- No PDF transaction parsing.
- No fixture movement or fixture content changes.
- No production `ImportEngine` routing change to the new detector.

## Files Created

- `Detectors/SignatureInstitutionDetector.swift`
  - Adds `SignatureInstitutionDetector`, `InstitutionDetectionRule`, `InstitutionSignature` and `InstitutionDetectionResult`.
  - Provides deterministic Axis Bank detection from extracted text.
  - Conforms to `ImportFramework.InstitutionDetector` and detects from `RawDocument`.

- `LedgerForgeTests/InstitutionDetectionTests.swift`
  - Adds Axis CSV detection coverage.
  - Adds Axis PDF detection coverage.
  - Adds unknown document coverage.
  - Adds detection reason and confidence checks.
  - Adds legacy detector parity checks.
  - Adds non-text `RawDocument` handling coverage.

## Files Modified

- `Detectors/DocumentMetadata.swift`
  - Added `Equatable` and `Sendable` conformance to metadata enums and `DocumentMetadata` so detector results can be compared safely in tests and used by sendable framework-facing detection code.

- `Detectors/InstitutionDetector.swift`
  - Preserved the legacy detector API.
  - Delegates matching to `SignatureInstitutionDetector` so legacy and framework detection use the same deterministic signature rules.
  - Added `detectWithReasons(from:)` for explainable detection without changing existing call sites.

- `Import/Protocols/ImportInstitutionDetector.swift`
  - Extended `ImportInstitutionCandidate` with `reasons: [String]`.
  - Kept the existing initializer source-compatible by defaulting `reasons` to an empty array.

- `LedgerForge.xcodeproj/project.pbxproj`
  - Updated automatically by Xcode tooling when adding new Sprint 12C files to the navigator and target membership.
  - This file was not manually edited.

- `Project documents/Codex response.md`
  - Updated with this Sprint 12C implementation status and validation result.

## Build Result

- Xcode MCP `BuildProject`: Passed.
- Result: `The project built successfully.`
- Errors: none reported by `BuildProject` after Sprint 12C changes.

## Test Result

Required test command attempted:

```text
xcodebuild -project LedgerForge.xcodeproj -scheme LedgerForge -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/LedgerForgeDerivedData test -only-testing:LedgerForgeTests/InstitutionDetectionTests -only-testing:LedgerForgeTests/CSVImportRegressionTests -only-testing:LedgerForgeTests/PDFDocumentReaderTests -only-testing:LedgerForgeTests/ImportFrameworkTests -only-testing:LedgerForgeTests/DefaultReaderRegistryTests -only-testing:LedgerForgeTests/PasswordProviderTests
```

Result: Failed before tests completed.

Failure:

```text
External macro implementation type 'PreviewsMacros.SwiftUIView' could not be found for macro 'Preview(_:body:)'; '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server' produced malformed response
```

Additional note:

- An earlier test attempt without an isolated DerivedData path failed because `xcodebuild` could not write to the default DerivedData/log folders under the sandbox.
- Retrying with `/tmp/LedgerForgeDerivedData` progressed further but failed at Swift module emission due to the SwiftUI preview macro plugin error above.
- Because required tests did not pass, no commit or push was performed.

## Behavioural Impact

- Existing production `ImportEngine` still calls `InstitutionDetector().detect(from:)`.
- The legacy detector still returns Axis Bank / Bank Account / confidence `0.98` when text contains Axis signatures.
- Unknown text still returns unknown institution, unknown document type and confidence `0.0`.
- CSV, PDF, parser, validation, repository and UI behavior were not intentionally changed.

## Architecture Decisions

- Institution detection now has a framework-compatible `RawDocument` entry point while preserving the legacy synchronous text detector.
- Detection remains deterministic and rule/signature-based.
- Detection reasons are included as lightweight strings on `ImportInstitutionCandidate` so automated detection remains explainable.
- Axis signatures currently include:
  - `AXIS BANK`
  - `UTIB`
  - `STATEMENT OF AXIS ACCOUNT`
- PDF and CSV are treated identically after reader extraction because detection operates on normalized text, not file layout or parser output.

## Merge Marker Check

- Strict conflict-marker scan completed.
- No unresolved conflict markers were found.

## Commit Result

- Not committed.
- Not pushed.
- Reason: required tests failed during Swift module emission because the SwiftUI preview macro plugin failed.

## Remaining Technical Debt

- Production `ImportEngine` still performs institution detection after `RawDocument` extraction and before CSV analysis/parser selection.
- `FinancialDocument` convergence remains future architecture work.
- Detection currently has only Axis rules; future institutions require approved fixtures and deterministic signatures.
- The test runner is currently blocked by the SwiftUI preview macro plugin failure when using command-line `xcodebuild test`.

## Remaining Risks

- The new detector has not been validated by a successful required test run because `xcodebuild test` failed before tests completed.
- Future PDF extraction text changes may affect signature matching if Axis identifiers change or disappear from extracted text.
- Adding more institutions will require careful rule ordering and confidence policy to avoid false positives.

## Next Recommended Sprint

Do not begin Sprint 13 until Sprint 12C test validation is unblocked.

Recommended next action:

- Resolve the command-line SwiftUI preview macro plugin test failure or run the required tests successfully inside Xcode.
- After tests pass, commit and push the Sprint 12C changes per the project workflow.
