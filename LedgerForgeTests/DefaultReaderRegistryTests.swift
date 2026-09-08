// LedgerForgeTests/DefaultReaderRegistryTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct DefaultReaderRegistryTests {

    @Test func registryResolvesCSVReaderAdapter() async throws {
        let registry = DefaultReaderRegistry()
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/generic.csv"))

        let reader = await registry.reader(for: request)

        #expect(reader is CSVDocumentReaderAdapter)
    }

    @Test func registryResolvesPDFDocumentReader() async throws {
        let registry = DefaultReaderRegistry()
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))

        let reader = await registry.reader(for: request)

        #expect(reader is PDFDocumentReader)
    }

    @Test func registryRejectsUnsupportedExtensionsWithTypedError() async throws {
        let registry = DefaultReaderRegistry()
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.ofx"))

        do {
            _ = try await registry.requiredReader(for: request)
            Issue.record("Expected DefaultReaderRegistry to reject unsupported file types.")
        } catch let error as ImportError {
            #expect(error == .readerUnavailable(extension: "ofx"))
        } catch {
            Issue.record("Expected ImportError.readerUnavailable, got \(error).")
        }
    }

    @Test func coordinatorUsesRegistryToReadGenericCSV() async throws {
        let registry = DefaultReaderRegistry()
        let coordinator = DefaultImportCoordinator(readerRegistry: registry)
        let fixtureURL = try genericCSVFixtureURL()
        defer { try? FileManager.default.removeItem(at: fixtureURL.deletingLastPathComponent()) }
        let request = ImportRequest(fileURL: fixtureURL)

        let result = await coordinator.importDocument(request)

        #expect(result.status == .succeeded)
        #expect(result.error == nil)
        let rawDocument = try #require(result.rawDocument)
        #expect(rawDocument.sourceURL == fixtureURL)
        #expect(rawDocument.fileName == fixtureURL.lastPathComponent)
        #expect(rawDocument.fileExtension == "csv")

        guard case .text(let text) = rawDocument.content else {
            Issue.record("Expected DefaultImportCoordinator and DefaultReaderRegistry to produce text RawDocument content.")
            return
        }

        #expect(text == "Name,Value\nAlpha,1\nBeta,2\n")
    }

    @Test func coordinatorReturnsTypedFailureForUnsupportedExtension() async throws {
        let registry = DefaultReaderRegistry()
        let coordinator = DefaultImportCoordinator(readerRegistry: registry)
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.ofx"))

        let result = await coordinator.importDocument(request)

        #expect(result.status == .failed)
        #expect(result.rawDocument == nil)
        #expect(result.error == .readerUnavailable(extension: "ofx"))
    }

}

private func genericCSVFixtureURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("generic.csv")
    try Data("Name,Value\nAlpha,1\nBeta,2\n".utf8).write(to: url)
    return url
}
