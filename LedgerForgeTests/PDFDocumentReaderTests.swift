// LedgerForgeTests/PDFDocumentReaderTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct PDFDocumentReaderTests {

    @Test func readerCanBeConstructedAndSupportsOnlyPDF() async throws {
        let reader = PDFDocumentReader()
        let request = ImportRequest(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"))

        #expect(reader.supportedFileExtensions == ["pdf"])
        #expect(reader.supportedFileExtensions.contains(request.fileExtension))
    }

    @Test func readerRejectsUnsupportedFileTypes() async throws {
        let reader = PDFDocumentReader()
        let request = ImportRequest(fileURL: FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv"))

        do {
            _ = try await reader.read(request: request, password: nil)
            Issue.record("Expected PDFDocumentReader to reject non-PDF input.")
        } catch let error as ImportError {
            #expect(error == .unsupportedFile(extension: "csv"))
        } catch {
            Issue.record("Expected ImportError.unsupportedFile, got \(error).")
        }
    }

    @Test func readerReturnsTypedInvalidDocumentForUnreadablePDF() async throws {
        let reader = PDFDocumentReader()
        let fileURL = try temporaryFileURL(extension: "pdf", contents: Data("not a pdf".utf8))
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let request = ImportRequest(fileURL: fileURL)

        do {
            _ = try await reader.read(request: request, password: nil)
            Issue.record("Expected PDFDocumentReader to reject unreadable PDF data.")
        } catch let error as ImportError {
            guard case .invalidDocument = error else {
                Issue.record("Expected ImportError.invalidDocument, got \(error).")
                return
            }
        } catch {
            Issue.record("Expected ImportError.invalidDocument, got \(error).")
        }
    }

    @Test func readerExtractsTextFromApprovedAxisPDFWhenFixtureExists() async throws {
        let fixtureURL = FixtureLocator.axisPDF("axis_bank_nre_account_statement_baseline.pdf")

        guard FixtureLocator.fileExists(at: fixtureURL) else {
            return
        }

        let reader = PDFDocumentReader()
        let request = ImportRequest(fileURL: fixtureURL)
        let rawDocument = try await reader.read(request: request, password: nil)

        #expect(rawDocument.sourceURL == fixtureURL)
        #expect(rawDocument.fileName == fixtureURL.lastPathComponent)
        #expect(rawDocument.fileExtension == "pdf")

        guard case .text(let text) = rawDocument.content else {
            Issue.record("Expected PDF reader to produce text RawDocument content.")
            return
        }

        #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test func readerReportsPasswordRequiredWhenApprovedEncryptedFixtureExists() async throws {
        let fixtureURL = FixtureLocator.axisPDF("axis_bank_nre_account_statement_encrypted.pdf")

        guard FixtureLocator.fileExists(at: fixtureURL) else {
            return
        }

        let reader = PDFDocumentReader()
        let request = ImportRequest(fileURL: fixtureURL)

        do {
            _ = try await reader.read(request: request, password: nil)
            Issue.record("Expected encrypted PDF fixture to require a password.")
        } catch let error as ImportError {
            #expect(error == .passwordRequired)
        } catch {
            Issue.record("Expected ImportError.passwordRequired, got \(error).")
        }
    }

    @Test func readerReportsIncorrectPasswordWhenApprovedEncryptedFixtureExists() async throws {
        let fixtureURL = FixtureLocator.axisPDF("axis_bank_nre_account_statement_encrypted.pdf")

        guard FixtureLocator.fileExists(at: fixtureURL) else {
            return
        }

        let reader = PDFDocumentReader()
        let request = ImportRequest(fileURL: fixtureURL)

        do {
            _ = try await reader.read(request: request, password: "incorrect-password")
            Issue.record("Expected encrypted PDF fixture to reject an incorrect password.")
        } catch let error as ImportError {
            #expect(error == .incorrectPassword)
        } catch {
            Issue.record("Expected ImportError.incorrectPassword, got \(error).")
        }
    }

    private func temporaryFileURL(extension fileExtension: String, contents: Data) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent("fixture.\(fileExtension)")
        try contents.write(to: fileURL)
        return fileURL
    }
}
