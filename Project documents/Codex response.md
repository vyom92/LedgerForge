# Codex Response

<<<<<<< Updated upstream
## Summary

Sprint 11B — Unified Import Framework Foundation is complete.

This sprint added the orchestration foundation only. It introduced typed import models, typed import errors, protocol contracts, and a coordinator skeleton that can select a reader, resolve a password provider, read a raw document, and return an `ImportResult`.

Existing import behaviour was not migrated or changed. `ImportEngine`, `ContentView`, stores, readers, parsers, validation, and repository writes were left untouched.

## Files Created

- `Import/ImportFramework.swift`
- `Import/Models/ImportRequest.swift`
- `Import/Models/ImportResult.swift`
- `Import/Models/ImportProgress.swift`
- `Import/Models/RawDocument.swift`
- `Import/Errors/ImportError.swift`
- `Import/Protocols/ImportDocumentReader.swift`
- `Import/Protocols/ReaderRegistry.swift`
- `Import/Protocols/PasswordProvider.swift`
- `Import/Protocols/ImportInstitutionDetector.swift`
- `Import/Protocols/StatementClassifier.swift`
- `Import/Protocols/ImportCoordinator.swift`
- `Import/Coordinator/DefaultImportCoordinator.swift`
- `LedgerForgeTests/ImportFrameworkTests.swift`

## Files Modified

- `Project documents/Codex response.md`
- `LedgerForge.xcodeproj/project.pbxproj` through Xcode-managed navigator and target membership updates

Existing Sprint 11A repository files remain modified in the working tree from the prior sprint; they were not part of the Sprint 11B import framework work.

## Build Result

Xcode build completed successfully.

Result: `The project built successfully.`

A command-line clean build was also attempted with:

`xcodebuild -project LedgerForge.xcodeproj -scheme LedgerForge -destination 'platform=macOS' -derivedDataPath /tmp/LedgerForgeDerived clean build`

The `clean` phase succeeded, and the command-line compile list confirmed the new `Import/` files are target-membered. The sandboxed command-line build then failed on the existing SwiftUI Preview macro toolchain issue:

`external macro implementation type 'PreviewsMacros.SwiftUIView' could not be found`

The project was rebuilt successfully through Xcode after that attempt.

## Test Result

All active scheme tests passed.

Result: `12 tests: 12 passed, 0 failed, 0 skipped, 0 expected failures, 0 not run`

Sprint 11B tests added:

- `ImportFrameworkTests/importRequestCreationPreservesTypedFileInformation()`
- `ImportFrameworkTests/importCoordinatorCanBeConstructed()`
- `ImportFrameworkTests/importCoordinatorWiresRegistryPasswordProviderAndReader()`
- `ImportFrameworkTests/importErrorProvidesTypedBehaviour()`

## Architecture Decisions

The new framework is isolated under `Import/` and does not alter the existing CSV import path.

`ImportFramework` was added as a namespace because the existing codebase already has top-level `DocumentReader` and `InstitutionDetector` types. The new protocol contracts are therefore expressed as:

- `ImportFramework.DocumentReader`
- `ImportFramework.ReaderRegistry`
- `ImportFramework.PasswordProvider`
- `ImportFramework.InstitutionDetector`
- `ImportFramework.StatementClassifier`
- `ImportFramework.ImportCoordinator`

The protocol filenames for document reading and institution detection use unique names, `ImportDocumentReader.swift` and `ImportInstitutionDetector.swift`, to avoid Swift build artifact collisions with existing files.

`DefaultImportCoordinator` is intentionally skeletal. It only accepts an `ImportRequest`, asks the `ReaderRegistry` for a reader, asks the optional `PasswordProvider` for a password, invokes the reader, and returns an `ImportResult`.

The coordinator does not perform parsing, validation, repository writes, institution detection, statement classification, UI updates, or migration of existing imports.

All new import framework data passed across boundaries is strongly typed. No `[String: Any]`, `NSDictionary`, or loose dictionary payloads were introduced.

## Documentation Updated

Updated this file only: `Project documents/Codex response.md`.

No frozen architecture document was changed because Sprint 11B implements the already documented Unified Import Framework foundation without changing the architecture, import pipeline order, or database design.

## Remaining Technical Debt

- The new framework is not yet connected to the existing `ImportEngine` or UI import flow.
- No concrete production readers exist in the new framework yet.
- `ReaderRegistry`, password resolution, institution detection, and statement classification currently have contracts only.
- The coordinator does not yet emit progress updates beyond the typed `ImportProgress` model.
- Existing import pipeline technical debt remains outside this sprint.
=======
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
>>>>>>> Stashed changes

## Deferred Items

<<<<<<< Updated upstream
Deferred by instruction:

- Sprint 11C
- Migrating existing CSV import flow
- Modifying `ImportEngine`
- Modifying `ContentView` import behaviour
- UI changes
- Store changes
- Parser pipeline changes
- Reader pipeline changes
- Institution detection implementation
- Statement parsing implementation
- Validation integration
- Repository write integration
- PDF reader
- CSV reader migration
- XLS reader
- XLSX reader
- TXT reader

## Next Recommended Sprint

Next recommended sprint: Sprint 11C.

Recommended focus: add a concrete reader registry and begin controlled integration planning without changing existing import behaviour until the adapter path is tested.
=======
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
>>>>>>> Stashed changes
