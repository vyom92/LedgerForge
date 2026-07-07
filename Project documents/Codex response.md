# Codex Response

# Sprint 12B - Implementation: Axis PDF Baseline Verification

## Summary

Implemented Sprint 12B as a test-only verification sprint.

The approved Axis Bank PDF fixture is now verified through `PDFDocumentReader` at the `RawDocument.text` boundary. The test asserts fixture presence, PDF reader extraction, statement identifiers, expected statement dates, opening balance, transaction totals and closing balance using deterministic text normalization.

No PDF parsing, production pipeline changes, repository changes, UI changes, institution detection framework, OCR, XLS/XLSX support, Keychain work, password prompt UI or Sprint 12C work was implemented.

## Files Modified

- `LedgerForgeTests/PDFDocumentReaderTests.swift`
  - Required to make the approved Axis PDF fixture mandatory instead of optional.
  - Added RawDocument text extraction verification for the approved Axis PDF.
  - Added normalized text assertions for statement identifiers, expected dates, opening balance, transaction totals and closing balance.
  - Kept encrypted PDF tests fixture-conditional because no approved encrypted fixture was part of Sprint 12B.

- `LedgerForgeTests/DefaultReaderRegistryTests.swift`
  - Required to preserve existing reader registry behavior after PDF became a supported format.
  - Fixed the PDF resolution test to use `.pdf`.
  - Fixed the unsupported-extension coordinator test to use `.ofx`.

- `Project documents/Codex response.md`
  - Updated with Sprint 12B implementation results.

## Files Created

- `LedgerForgeTests/TestSupport/AxisBaselineExpectation.swift`
  - Required so PDF baseline tests decode approved expected values from `axis_bank_nre_account_statement_baseline.expected.json` instead of duplicating financial constants in test code.

## Tests Added Or Updated

Updated `PDFDocumentReaderTests` to cover:

- Approved Axis PDF fixture exists.
- `PDFDocumentReader` returns `RawDocument` for the approved Axis PDF fixture.
- `RawDocument.content` is text and is non-empty after normalization.
- Extracted PDF text contains the expected Axis Bank identifier.
- Extracted PDF text contains the expected NRE savings account identifier.
- Extracted PDF text contains expected currency text.
- Extracted PDF text contains expected first and last transaction dates from the approved JSON baseline.
- Extracted PDF text contains expected opening balance from the approved JSON baseline.
- Extracted PDF text contains expected debit and credit transaction totals from the approved JSON baseline.
- Extracted PDF text contains expected closing balance from the approved JSON baseline, including PDFKit's observed leading-zero omission for `.16`.

Updated `DefaultReaderRegistryTests` to keep existing framework expectations aligned:

- `.pdf` resolves to `PDFDocumentReader`.
- `.ofx` remains unsupported and returns `ImportError.readerUnavailable(extension: "ofx")`.

## Build Result

A command-line build was run with workspace-local DerivedData:

```text
xcodebuild -project LedgerForge.xcodeproj -scheme LedgerForge -configuration Debug -derivedDataPath ./DerivedData-Local build
```

Result: failed before useful Sprint 12B validation due existing SwiftUI preview macro plugin errors in unrelated UI files:

```text
ContentView.swift:178:1: error: external macro implementation type 'PreviewsMacros.SwiftUIView' could not be found for macro 'Preview(_:body:)'; '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server' produced malformed response
DocumentPreviewView.swift:65:1: error: external macro implementation type 'PreviewsMacros.SwiftUIView' could not be found for macro 'Preview(_:body:)'; '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server' produced malformed response
DeveloperConsoleView.swift:42:1: error: external macro implementation type 'PreviewsMacros.SwiftUIView' could not be found for macro 'Preview(_:body:)'; '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server' produced malformed response
TransactionListView.swift:167:1: error: external macro implementation type 'PreviewsMacros.SwiftUIView' could not be found for macro 'Preview(_:body:)'; '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server' produced malformed response
```

The Xcode MCP `BuildProject` tool also reported a successful build result but still surfaced stale diagnostics for a root-level `PDFDocumentReader.swift` build input. A direct `xcodebuild` compile showed the actual source paths now compile from:

```text
Import/Readers/DefaultReaderRegistry.swift
Import/Readers/PDFDocumentReader.swift
Import/Readers/CSVDocumentReaderAdapter.swift
Import/Password/DefaultPasswordProvider.swift
```

## Test Result

The requested test selection was run with workspace-local DerivedData:

```text
xcodebuild test -project LedgerForge.xcodeproj -scheme LedgerForge -destination 'platform=macOS,arch=arm64' -derivedDataPath ./DerivedData-Local -only-testing:LedgerForgeTests/PDFDocumentReaderTests -only-testing:LedgerForgeTests/CSVImportRegressionTests -only-testing:LedgerForgeTests/CSVDocumentReaderAdapterTests -only-testing:LedgerForgeTests/DefaultReaderRegistryTests -only-testing:LedgerForgeTests/PasswordProviderTests -only-testing:LedgerForgeTests/ImportFrameworkTests
```

Result: failed before tests executed due the same existing SwiftUI preview macro plugin errors. No Sprint 12B test assertion failures were observed because the test runner did not reach test execution.

Manual PDFKit extraction verification was performed outside the project test runner using the approved PDF fixture. The extracted text contains the approved baseline values needed by the new assertions:

- Axis/NRE/currency identifiers are observable.
- Expected dates from the approved JSON baseline are observable.
- Opening balance is observable.
- Debit and credit transaction totals are observable.
- Closing balance is observable as `.16`, matching PDFKit's extracted text form for approved `0.16`.

## Behavioural Impact

No production financial behavior changed.

Sprint 12B changed only test coverage and test support. The PDF reader remains a reader-only component that extracts text into `RawDocument`. No parser, validator, repository, store, dashboard or UI behavior was changed.

## Architecture Decisions

- PDF baseline verification remains at the `RawDocument.text` boundary.
- Expected financial values are loaded from the approved JSON fixture through `AxisBaselineExpectation` instead of duplicated as constants in PDF tests.
- PDF text comparisons normalize whitespace and commas, but do not infer layout, parse transactions or alter financial meaning.
- Transaction count was not asserted from PDF text because it is not directly represented as a transaction-count field in the extracted PDF text.

## Remaining Technical Debt

- The command-line build and test runner are currently blocked in this environment by SwiftUI `#Preview` macro plugin failures in existing UI files.
- Xcode MCP `BuildProject` still reports stale diagnostics for a root-level `PDFDocumentReader.swift` input even though command-line build output shows the Import reader files compiling from their correct paths.
- Approved encrypted PDF fixture coverage remains deferred; existing encrypted PDF tests stay conditional.
- PDF parsing remains intentionally unimplemented.
- Institution Detection Framework remains intentionally unimplemented.

## Remaining Risks

- PDFKit text extraction can remain sensitive to Apple PDFKit behavior changes, especially whitespace and amount formatting.
- Future PDF fixtures may require additional normalization rules if text extraction differs materially.
- Since tests could not execute in this sandbox, final pass/fail confirmation should be performed in Xcode or a non-sandboxed `xcodebuild test` environment.

## Recommended Sprint 12C Objective

Sprint 12C should implement the Institution Detection Framework foundation only:

- Keep reader/parsing boundaries intact.
- Do not parse PDF transactions unless explicitly approved.
- Route detection through framework abstractions without changing existing financial behavior.
- Preserve the Axis CSV and PDF reference fixture baselines.
