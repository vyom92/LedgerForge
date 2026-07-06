# Codex Response

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

## Deferred Items

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
