// LedgerForgeTests/DefaultReaderRegistryTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct DefaultReaderRegistryTests {

    @Test func registryResolvesCSVReaderAdapter() async throws {
        let registry = DefaultReaderRegistry()
        let request = ImportRequest(fileURL: approvedCSVFixtureURL())

        let reader = await registry.reader(for: request)

        #expect(reader is CSVDocumentReaderAdapter)
    }

    @Test func registryResolvesPDFDocumentReader() async throws {
        let registry = DefaultReaderRegistry()
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.ofx"))

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

    @Test func coordinatorUsesRegistryToReadApprovedCSVFixture() async throws {
        let registry = DefaultReaderRegistry()
        let coordinator = DefaultImportCoordinator(readerRegistry: registry)
        let fixtureURL = approvedCSVFixtureURL()
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

        #expect(text.contains("Statement of Account No"))
        #expect(text.contains("Tran Date,CHQNO,PARTICULARS,DR,CR,BAL,SOL"))
    }

    @Test func coordinatorReturnsTypedFailureForUnsupportedExtension() async throws {
        let registry = DefaultReaderRegistry()
        let coordinator = DefaultImportCoordinator(readerRegistry: registry)
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))

        let result = await coordinator.importDocument(request)

        #expect(result.status == .failed)
        #expect(result.rawDocument == nil)
        #expect(result.error == .readerUnavailable(extension: "ofx"))
    }

}

private func approvedCSVFixtureURL() -> URL {
    FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
}
