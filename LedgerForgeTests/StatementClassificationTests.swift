// LedgerForgeTests/StatementClassificationTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct StatementClassificationTests {

    @Test func statementClassificationPreservesSourceCompatibleInitializer() async throws {
        let classification = StatementClassification(documentType: .bankStatement, confidence: 0.95)

        #expect(classification.documentType == .bankStatement)
        #expect(classification.confidence == 0.95)
        #expect(classification.reasons.isEmpty)
    }

    @Test func statementClassificationStoresExplainableReasons() async throws {
        let classification = StatementClassification(
            documentType: .bankStatement,
            confidence: 0.95,
            reasons: ["Matched account statement title."]
        )

        #expect(classification.reasons == ["Matched account statement title."])
    }

    @Test func classifierCanBeConstructed() async throws {
        let classifier = StatementClassificationDetector()
        let rawDocument = RawDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/unknown.txt"),
            fileName: "unknown.txt",
            fileExtension: "txt",
            content: .text("No supported document-family signatures.")
        )

        let classification = try await classifier.classify(document: rawDocument, institution: nil)

        #expect(classification.documentType == .unknown)
    }

    @Test func unknownTextClassifiesAsUnknownWithoutGuessing() async throws {
        let rawDocument = RawDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/notes.txt"),
            fileName: "notes.txt",
            fileExtension: "txt",
            content: .text("Personal notes without statement titles, transaction headers or payment due labels.")
        )

        let classification = try await StatementClassificationDetector().classify(
            document: rawDocument,
            institution: nil
        )

        #expect(classification.documentType == .unknown)
        #expect(classification.confidence == 0.0)
        #expect(classification.reasons == ["No statement classification signatures matched."])
    }

    @Test func nonTextRawDocumentClassifiesAsUnknownWithReason() async throws {
        let rawDocument = RawDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/document.bin"),
            fileName: "document.bin",
            fileExtension: "bin",
            content: .data(Data([0x00, 0x01]))
        )

        let classification = try await StatementClassificationDetector().classify(
            document: rawDocument,
            institution: nil
        )

        #expect(classification.documentType == .unknown)
        #expect(classification.confidence == 0.0)
        #expect(classification.reasons == ["RawDocument did not contain extracted text."])
    }

    @Test func axisCSVFixtureClassifiesAsBankStatement() async throws {
        let rawDocument = try axisCSVRawDocument()
        let institution = try await SignatureInstitutionDetector().detectInstitution(in: rawDocument)

        let classification = try await StatementClassificationDetector().classify(
            document: rawDocument,
            institution: institution
        )

        #expect(classification.documentType == .bankStatement)
        #expect(classification.confidence == 0.95)
        #expect(!classification.reasons.isEmpty)
        #expect(classification.reasons.contains("Matched Axis Bank institution context."))
    }

    @Test func axisPDFFixtureClassifiesAsBankStatement() async throws {
        let rawDocument = try await axisPDFRawDocument()
        let institution = try await SignatureInstitutionDetector().detectInstitution(in: rawDocument)

        let classification = try await StatementClassificationDetector().classify(
            document: rawDocument,
            institution: institution
        )

        #expect(classification.documentType == .bankStatement)
        #expect(classification.confidence == 0.95)
        #expect(!classification.reasons.isEmpty)
    }

    @Test func axisCSVAndPDFFixturesClassifyToSameDocumentType() async throws {
        let csvDocument = try axisCSVRawDocument()
        let pdfDocument = try await axisPDFRawDocument()
        let detector = SignatureInstitutionDetector()
        let classifier = StatementClassificationDetector()

        let csvClassification = try await classifier.classify(
            document: csvDocument,
            institution: detector.detect(from: try rawText(from: csvDocument)).importCandidate
        )
        let pdfClassification = try await classifier.classify(
            document: pdfDocument,
            institution: try await detector.detectInstitution(in: pdfDocument)
        )

        #expect(csvClassification.documentType == pdfClassification.documentType)
        #expect(csvClassification.documentType == .bankStatement)
    }

    @Test func frameworkDocumentTypesMapToLegacyDocumentTypes() async throws {
        #expect(StatementDocumentType.bankStatement.legacyDocumentType == .bankAccount)
        #expect(StatementDocumentType.creditCardStatement.legacyDocumentType == .creditCard)
        #expect(StatementDocumentType.brokerageStatement.legacyDocumentType == .investment)
        #expect(StatementDocumentType.salaryStatement.legacyDocumentType == .salarySlip)
        #expect(StatementDocumentType.taxDocument.legacyDocumentType == .tax)
        #expect(StatementDocumentType.insuranceStatement.legacyDocumentType == .unknown)
        #expect(StatementDocumentType.unknown.legacyDocumentType == .unknown)
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
}
