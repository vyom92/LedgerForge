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

    @Test func approvedAxisPDFFixtureExists() async throws {
        let fixtureURL = approvedAxisPDFFixtureURL()

        #expect(FixtureLocator.fileExists(at: fixtureURL))
    }

    @Test func readerExtractsTextFromApprovedAxisPDFFixture() async throws {
        let fixtureURL = approvedAxisPDFFixtureURL()
        try #require(FixtureLocator.fileExists(at: fixtureURL))

        let rawDocument = try await readApprovedAxisPDF()

        #expect(rawDocument.sourceURL == fixtureURL)
        #expect(rawDocument.fileName == fixtureURL.lastPathComponent)
        #expect(rawDocument.fileExtension == "pdf")

        let text = try rawText(from: rawDocument)
        #expect(!PDFTextExpectation(text).normalized.isEmpty)
    }

    @Test func approvedAxisPDFTextContainsExpectedStatementIdentifiersAndPeriod() async throws {
        let baseline = try AxisBaselineExpectation.axisBankNREBaseline()
        let rawDocument = try await readApprovedAxisPDF()
        let text = PDFTextExpectation(try rawText(from: rawDocument))

        #expect(text.containsWords(from: baseline.institution))
        #expect(text.containsWords(from: baseline.accountType))
        #expect(text.containsWords(from: baseline.currency))
        #expect(text.contains(baseline.firstTransactionDate))
        #expect(text.contains(baseline.lastTransactionDate))
    }

    @Test func approvedAxisPDFTextContainsExpectedBalancesAndTotals() async throws {
        let baseline = try AxisBaselineExpectation.axisBankNREBaseline()
        let rawDocument = try await readApprovedAxisPDF()
        let text = PDFTextExpectation(try rawText(from: rawDocument))

        #expect(text.containsLabeledAmount(label: "OPENING BALANCE", amount: baseline.openingBalance))
        #expect(text.containsTransactionTotals(debit: baseline.debitTotal, credit: baseline.creditTotal))
        #expect(text.containsLabeledAmount(label: "CLOSING BALANCE", amount: baseline.closingBalance))
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

    private func approvedAxisPDFFixtureURL() -> URL {
        FixtureLocator.axisPDF("axis_bank_nre_account_statement_baseline.pdf")
    }

    private func readApprovedAxisPDF() async throws -> RawDocument {
        let fixtureURL = approvedAxisPDFFixtureURL()
        try #require(FixtureLocator.fileExists(at: fixtureURL))

        let reader = PDFDocumentReader()
        let request = ImportRequest(fileURL: fixtureURL)
        return try await reader.read(request: request, password: nil)
    }

    private func rawText(from rawDocument: RawDocument) throws -> String {
        guard case .text(let text) = rawDocument.content else {
            Issue.record("Expected PDF reader to produce text RawDocument content.")
            return ""
        }

        return text
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

private struct PDFTextExpectation {
    let normalized: String
    private let amountComparable: String

    init(_ text: String) {
        normalized = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        amountComparable = normalized.replacingOccurrences(of: ",", with: "")
    }

    func contains(_ value: String) -> Bool {
        normalized.localizedCaseInsensitiveContains(value)
    }

    func containsWords(from phrase: String) -> Bool {
        phrase
            .split(separator: " ")
            .allSatisfy { normalized.localizedCaseInsensitiveContains(String($0)) }
    }

    func containsLabeledAmount(label: String, amount: String) -> Bool {
        normalized.localizedCaseInsensitiveContains(label)
            && containsAmount(amount)
    }

    func containsTransactionTotals(debit: String, credit: String) -> Bool {
        normalized.localizedCaseInsensitiveContains("TRANSACTION TOTAL")
            && containsAmount(debit)
            && containsAmount(credit)
    }

    private func containsAmount(_ amount: String) -> Bool {
        amountVariants(for: amount).contains { variant in
            amountComparable.localizedCaseInsensitiveContains(variant)
        }
    }

    private func amountVariants(for amount: String) -> [String] {
        var variants = [amount]

        if amount.hasPrefix("0.") {
            variants.append(String(amount.dropFirst()))
        }

        return variants
    }
}
