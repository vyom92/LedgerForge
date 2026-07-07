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

- Xcode Build: Passed.
- Production target builds successfully.
- No Sprint 12C build errors remain.

## Test Result

All required Sprint 12C validation completed successfully inside Xcode.

Summary:

- 37 tests executed.
- 37 tests passed.
- 0 failures.
- 9 test suites passed.

Validated suites:

- InstitutionDetectionTests
- CSVImportRegressionTests
- PDFDocumentReaderTests
- ImportFrameworkTests
- DefaultReaderRegistryTests
- PasswordProviderTests
- RepositoryContractTests
- CSVDocumentReaderAdapterTests
- LedgerForgeTests

Notes:

- Command-line `xcodebuild test` remained affected by a SwiftUI Preview macro tooling issue.
- Xcode successfully executed the required regression suite.
- Sprint 12C validation is therefore considered complete.

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

- Sprint 12C committed.
- Changes pushed to `origin/main`.
- `sprint-12c-complete` Git tag created and pushed.

## Remaining Technical Debt

- Production `ImportEngine` still performs institution detection after `RawDocument` extraction and before CSV analysis/parser selection.
- `FinancialDocument` convergence remains future architecture work.
- Detection currently has only Axis rules; future institutions require approved fixtures and deterministic signatures.

## Remaining Risks

- Institution detection currently contains only approved Axis signatures.
- Future institutions should be added only alongside approved reference fixtures.
- PDF text extraction may evolve across macOS releases and should continue to be protected by regression fixtures.

## Next Recommended Sprint

Sprint 13 — Statement Classification Framework.

Objectives:

- Introduce deterministic statement classification.
- Preserve institution detection behaviour.
- Keep parser selection independent of file format.
- Continue extending the unified import pipeline without modifying validated reader behaviour.
