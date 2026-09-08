// LedgerForgeTests/CSVDocumentReaderAdapterTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct CSVDocumentReaderAdapterTests {

    @Test func adapterAcceptsCSVInput() async throws {
        let adapter = CSVDocumentReaderAdapter()
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/generic.csv"))

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

    @Test func adapterProducesRawTextDocumentForGenericCSV() async throws {
        let adapter = CSVDocumentReaderAdapter()
        let fixtureURL = try genericCSVFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixtureURL.deletingLastPathComponent()) }
        let request = ImportRequest(fileURL: fixtureURL)

        let rawDocument = try await adapter.read(request: request, password: nil)

        #expect(rawDocument.sourceURL == fixtureURL)
        #expect(rawDocument.fileName == fixtureURL.lastPathComponent)
        #expect(rawDocument.fileExtension == "csv")

        guard case .text(let text) = rawDocument.content else {
            Issue.record("Expected CSV adapter to produce text RawDocument content.")
            return
        }

        #expect(text == "Name,Value\nAlpha,1\nBeta,2\n")
    }

    @Test func adapterOutputMatchesLegacyCSVReaderForGenericInput() async throws {
        let adapter = CSVDocumentReaderAdapter()
        let fixtureURL = try genericCSVFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixtureURL.deletingLastPathComponent()) }
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

private func genericCSVFixtureURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("generic.csv")
    try Data("Name,Value\nAlpha,1\nBeta,2\n".utf8).write(to: url)
    return url
}
