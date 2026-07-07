# Codex Response


## Sprint 12A Summary

Implemented the PDF Reader Foundation for the Unified Import Framework only.

Sprint 12A added a PDF reader that conforms to the existing import framework reader boundary, registered it with the default reader registry, reorganized approved Axis CSV fixtures into the standard fixture structure, and added test support for fixture lookup.

No PDF statement parsing, institution detection, transaction extraction, validation changes, persistence changes, UI changes, Keychain integration, password prompt flow, password retry flow, OCR, XLS/XLSX/TXT support, or Sprint 12B work was implemented.

## Files Created

- `Import/Readers/PDFDocumentReader.swift`
- `LedgerForgeTests/TestSupport/FixtureLocator.swift`
- `LedgerForgeTests/PDFDocumentReaderTests.swift`

## Files Modified

- `Import/Readers/DefaultReaderRegistry.swift`
- `LedgerForgeTests/CSVImportRegressionTests.swift`
- `LedgerForgeTests/CSVDocumentReaderAdapterTests.swift`
- `LedgerForgeTests/DefaultReaderRegistryTests.swift`
- `LedgerForge.xcodeproj/project.pbxproj`
- `Project documents/Codex response.md`

## Fixtures Moved

Moved without modifying fixture contents:

- From `LedgerForgeTests/Fixtures/CSV/axis_bank_nre_account_statement_baseline.csv`
- To `LedgerForgeTests/Fixtures/Axis/CSV/axis_bank_nre_account_statement_baseline.csv`

- From `LedgerForgeTests/Fixtures/CSV/axis_bank_nre_account_statement_baseline.expected.json`
- To `LedgerForgeTests/Fixtures/Axis/Expected/axis_bank_nre_account_statement_baseline.expected.json`

Created fixture structure:

- `LedgerForgeTests/Fixtures/Axis/CSV/`
- `LedgerForgeTests/Fixtures/Axis/PDF/`
- `LedgerForgeTests/Fixtures/Axis/Expected/`
- `LedgerForgeTests/Fixtures/Shared/`

## Build Result

Build checkpoints completed successfully:

- Pre-change Xcode build: passed.
- Build after fixture restructuring and fixture locator updates: passed.
- Build after adding `PDFDocumentReader`: passed.
- Build after registering PDF reader in `DefaultReaderRegistry`: passed.
- Build after adding `PDFDocumentReaderTests`: passed.
- Final Xcode build after cleanup: passed.

## Test Result

Requested tests were attempted with:

- `PDFDocumentReaderTests`
- `CSVImportRegressionTests`
- `CSVDocumentReaderAdapterTests`
- `DefaultReaderRegistryTests`
- `PasswordProviderTests`
- `ImportFrameworkTests`

The first `xcodebuild test` attempt failed before tests executed because Xcode attempted to write test artifacts under `~/Library/Developer/Xcode/DerivedData`, which is outside the sandbox.

The second attempt used a workspace-local `-derivedDataPath`, but `xcodebuild test` still failed before tests executed because Xcode's external preview macro plugin service failed under sandboxed execution:

```text
External macro implementation type 'PreviewsMacros.SwiftUIView' could not be found for macro 'Preview(_:body:)'; '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server' produced malformed response
```

No test assertion failures were observed because the test runner did not reach execution. The final Xcode build still passed after this failure.

## Behavioural Impact

Production CSV import behavior is intended to remain unchanged.

Changes are limited to:

- Fixture path lookup in tests.
- Reader registry adding PDF reader resolution for `.pdf` files.
- PDF reader foundation producing `RawDocument.text` only.

No UI flow was changed. No parser, validator, repository, store, or persistence behavior was changed.

## Architecture Decisions

- `PDFDocumentReader` lives in `Import/Readers/`, matching the reader layer used by `CSVDocumentReaderAdapter`.
- `PDFDocumentReader` conforms to `ImportFramework.DocumentReader`.
- `PDFDocumentReader` supports only `pdf`.
- Unsupported file extensions return `ImportError.unsupportedFile`.
- Locked PDFs use only the password supplied by `DefaultImportCoordinator` through the existing `PasswordProvider` path.
- Missing password returns `ImportError.passwordRequired`.
- Failed password unlock returns `ImportError.incorrectPassword`.
- PDF text extraction uses PDFKit and outputs `RawDocument(content: .text(...))`.
- `DefaultReaderRegistry` now registers `CSVDocumentReaderAdapter` and `PDFDocumentReader`.
- Tests now use `FixtureLocator` instead of fragile hardcoded fixture paths.

## Missing Fixtures

No approved Axis PDF fixture exists in the workspace at this time.

Because no approved PDF fixture is available, Sprint 12A did not add mandatory PDF text baseline assertions against real financial statement content. `PDFDocumentReaderTests` includes fixture-conditional tests that will exercise approved Axis PDF extraction and encrypted PDF password behavior only when those fixtures are added.

No synthetic PDF statement or placeholder PDF fixture was created.

## Remaining Technical Debt

- Approved Axis PDF fixture is still needed for real PDF text extraction regression coverage.
- Approved encrypted PDF fixture is still needed for password-required and incorrect-password regression coverage.
- `xcodebuild test` is currently blocked in this sandbox by Xcode preview macro plugin execution before tests run.
- The legacy empty `LedgerForgeTests/Fixtures/CSV/` directory still exists on disk only because it contains `.DS_Store`; no approved fixture remains there.


## Deferred Items


- PDFKit text extraction quality is unverified against an approved real bank PDF fixture.
- Encrypted PDF behavior is unverified against an approved encrypted fixture.
- CSV behavior compiles after fixture migration, but requested regression tests could not execute because of the sandboxed Xcode test runner failure.
- Registering `.pdf` changes framework reader resolution, but production PDF import still has no parser path by design for Sprint 12A.

## Next Recommended Sprint

Sprint 12B should proceed only after an approved Axis PDF fixture is added.

Recommended Sprint 12B focus:

- Add approved Axis PDF fixture coverage.
- Verify PDFKit extraction output against approved expected text-level assertions.
- Keep PDF parsing, institution detection, transaction extraction, validation, persistence, and UI changes out of scope unless explicitly approved for that sprint.

