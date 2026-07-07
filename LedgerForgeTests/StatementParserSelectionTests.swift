// LedgerForgeTests/StatementParserSelectionTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct StatementParserSelectionTests {

    @Test func axisCSVFixtureSelectsAxisBankAccountParser() async throws {
        let rawDocument = try axisCSVRawDocument()
        let text = try rawText(from: rawDocument)
        let document = CSVAnalyzer().analyze(text: text, fileURL: rawDocument.sourceURL)
        let institution = try await SignatureInstitutionDetector().detectInstitution(in: rawDocument)
        let classification = try await StatementClassificationDetector().classify(
            document: rawDocument,
            institution: institution
        )
        let expected = try AxisBaselineExpectation.axisBankNREBaseline()

        let selection = StatementParserSelector().selectParser(
            for: document,
            institution: institution,
            classification: classification
        )

        #expect(selection.matched)
        #expect(selection.parserName == "Axis Bank Account")
        #expect(selection.parser.map { String(describing: type(of: $0)) } == expected.expectedParser)
        #expect(selection.legacyMetadata.institution == .axis)
        #expect(selection.legacyMetadata.documentType == .bankAccount)
        #expect(selection.legacyMetadata.fileFormat == .csv)
        #expect(selection.confidence == 0.95)
        #expect(!selection.reasons.isEmpty)
    }

    @Test func axisPDFFixtureContextSelectsAxisBankAccountParser() async throws {
        let rawDocument = try await axisPDFRawDocument()
        let document = documentShell(for: rawDocument)
        let institution = try await SignatureInstitutionDetector().detectInstitution(in: rawDocument)
        let classification = try await StatementClassificationDetector().classify(
            document: rawDocument,
            institution: institution
        )

        let selection = StatementParserSelector().selectParser(
            for: document,
            institution: institution,
            classification: classification
        )

        #expect(selection.matched)
        #expect(selection.parserName == "Axis Bank Account")
        #expect(selection.parser is AxisBankAccountParser)
        #expect(selection.legacyMetadata.institution == .axis)
        #expect(selection.legacyMetadata.documentType == .bankAccount)
        #expect(selection.legacyMetadata.fileFormat == .pdf)
        #expect(selection.reasons.contains { $0.contains("Selected parser") })
    }

    @Test func unknownInstitutionDoesNotSelectParser() async throws {
        let rawDocument = RawDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/unknown.csv"),
            fileName: "unknown.csv",
            fileExtension: "csv",
            content: .text("Opening Balance Closing Balance Tran Date Particulars")
        )
        let document = documentShell(for: rawDocument)
        let classification = StatementClassification(
            documentType: .bankStatement,
            confidence: 0.95,
            reasons: ["Synthetic bank statement classification for selector boundary."]
        )

        let selection = StatementParserSelector().selectParser(
            for: document,
            institution: nil,
            classification: classification
        )

        #expect(!selection.matched)
        #expect(selection.parser == nil)
        #expect(selection.parserName == nil)
        #expect(selection.legacyMetadata.institution == .unknown)
        #expect(selection.legacyMetadata.documentType == .bankAccount)
        #expect(selection.confidence == 0.0)
        #expect(selection.reasons.contains("No parser selected because institution is unknown."))
    }

    @Test func unknownStatementTypeDoesNotSelectParser() async throws {
        let rawDocument = try axisCSVRawDocument()
        let document = documentShell(for: rawDocument)
        let institution = ImportInstitutionCandidate(
            institutionCode: Institution.axis.rawValue,
            confidence: 0.98,
            reasons: ["Detected Axis Bank for selector boundary."]
        )
        let classification = StatementClassification(
            documentType: .unknown,
            confidence: 0.0,
            reasons: ["No statement classification signatures matched."]
        )

        let selection = StatementParserSelector().selectParser(
            for: document,
            institution: institution,
            classification: classification
        )

        #expect(!selection.matched)
        #expect(selection.parser == nil)
        #expect(selection.parserName == nil)
        #expect(selection.legacyMetadata.institution == .axis)
        #expect(selection.legacyMetadata.documentType == .unknown)
        #expect(selection.reasons.contains("No parser selected because statement type is unknown."))
    }

    @Test func unsupportedInstitutionCodeDoesNotInventParser() async throws {
        let rawDocument = RawDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/unknown.csv"),
            fileName: "unknown.csv",
            fileExtension: "csv",
            content: .text("Statement of Account Opening Balance Closing Balance")
        )
        let document = documentShell(for: rawDocument)
        let institution = ImportInstitutionCandidate(
            institutionCode: "Unsupported Bank",
            confidence: 0.99,
            reasons: ["Synthetic unsupported institution for selector boundary."]
        )
        let classification = StatementClassification(
            documentType: .bankStatement,
            confidence: 0.95,
            reasons: ["Synthetic bank statement classification for selector boundary."]
        )

        let selection = StatementParserSelector().selectParser(
            for: document,
            institution: institution,
            classification: classification
        )

        #expect(!selection.matched)
        #expect(selection.parser == nil)
        #expect(selection.legacyMetadata.institution == .unknown)
        #expect(selection.legacyMetadata.documentType == .bankAccount)
    }

    private func axisCSVRawDocument() throws -> RawDocument {
        let csvURL = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        let text = try CSVReader().read(from: csvURL)

        return RawDocument(
            sourceURL: csvURL,
            fileName: csvURL.lastPathComponent,
            fileExtension: csvURL.pathExtension,
            content: .text(text)
        )
    }

    private func axisPDFRawDocument() async throws -> RawDocument {
        let pdfURL = FixtureLocator.axisPDF("axis_bank_nre_account_statement_baseline.pdf")
        try #require(FixtureLocator.fileExists(at: pdfURL))

        return try await PDFDocumentReader().read(
            request: ImportRequest(fileURL: pdfURL),
            password: nil
        )
    }

    private func rawText(from rawDocument: RawDocument) throws -> String {
        guard case .text(let text) = rawDocument.content else {
            Issue.record("Expected text RawDocument content.")
            return ""
        }

        return text
    }

    private func documentShell(for rawDocument: RawDocument) -> Document {
        Document(
            filename: rawDocument.fileName,
            url: rawDocument.sourceURL,
            fileType: rawDocument.fileExtension.uppercased(),
            importedAt: rawDocument.extractedAt
        )
    }

}
