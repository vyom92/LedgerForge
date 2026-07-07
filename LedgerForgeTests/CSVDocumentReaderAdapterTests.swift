// LedgerForgeTests/CSVDocumentReaderAdapterTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct CSVDocumentReaderAdapterTests {

    @Test func adapterAcceptsCSVInput() async throws {
        let adapter = CSVDocumentReaderAdapter()
        let request = ImportRequest(fileURL: approvedCSVFixtureURL())

        #expect(adapter.supportedFileExtensions == ["csv"])
        #expect(adapter.supportedFileExtensions.contains(request.fileExtension))
    }

    @Test func adapterRejectsUnsupportedFileTypes() async throws {
        let adapter = CSVDocumentReaderAdapter()
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))

        do {
            _ = try await adapter.read(request: request, password: nil)
            Issue.record("Expected CSVDocumentReaderAdapter to reject non-CSV input.")
        } catch let error as ImportError {
            #expect(error == .unsupportedFile(extension: "pdf"))
        } catch {
            Issue.record("Expected ImportError.unsupportedFile, got \(error).")
        }
    }

    @Test func adapterProducesRawTextDocumentForApprovedCSVFixture() async throws {
        let adapter = CSVDocumentReaderAdapter()
        let fixtureURL = approvedCSVFixtureURL()
        let request = ImportRequest(fileURL: fixtureURL)

        let rawDocument = try await adapter.read(request: request, password: nil)

        #expect(rawDocument.sourceURL == fixtureURL)
        #expect(rawDocument.fileName == fixtureURL.lastPathComponent)
        #expect(rawDocument.fileExtension == "csv")

        guard case .text(let text) = rawDocument.content else {
            Issue.record("Expected CSV adapter to produce text RawDocument content.")
            return
        }

        #expect(text.contains("Statement of Account No"))
        #expect(text.contains("Tran Date,CHQNO,PARTICULARS,DR,CR,BAL,SOL"))
    }

    @Test func adapterOutputMatchesLegacyCSVReaderForApprovedFixture() async throws {
        let adapter = CSVDocumentReaderAdapter()
        let fixtureURL = approvedCSVFixtureURL()
        let request = ImportRequest(fileURL: fixtureURL)
        let legacyText = try CSVReader().read(from: fixtureURL)

        let rawDocument = try await adapter.read(request: request, password: nil)

        guard case .text(let adapterText) = rawDocument.content else {
            Issue.record("Expected CSV adapter to produce text RawDocument content.")
            return
        }

        #expect(adapterText == legacyText)
    }

}

private func approvedCSVFixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent("CSV")
        .appendingPathComponent("axis_bank_nre_account_statement_baseline.csv")
}
