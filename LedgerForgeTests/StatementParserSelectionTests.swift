// LedgerForgeTests/StatementParserSelectionTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct StatementParserSelectionTests {

    @Test func unknownInstitutionDoesNotSelectParser() async throws {
        let rawDocument = RawDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/unknown.csv"),
            fileName: "unknown.csv",
            fileExtension: "csv",
            content: .text("")
        )
        let document = documentShell(for: rawDocument)
        let classification = StatementClassification(
            documentType: .bankStatement,
            confidence: 0.95,
            reasons: ["Explicit type value for selector dispatch."]
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

    @Test func axisCreditCardPDFAndXLSXSelectTheirExactParsers() {
        let institution = ImportInstitutionCandidate(
            institutionCode: Institution.axis.rawValue,
            confidence: 0.995,
            reasons: ["Explicit institution value for selector dispatch."]
        )
        let classification = StatementClassification(
            documentType: .creditCardStatement,
            confidence: 0.90,
            reasons: ["Explicit document type for selector dispatch."]
        )

        for (fileExtension, expectedType) in [
            ("pdf", "AxisCreditCardPDFParser"),
            ("xlsx", "AxisCreditCardXLSXParser")
        ] {
            let raw = RawDocument(
                sourceURL: URL(fileURLWithPath: "/tmp/fictional-axis-card.\(fileExtension)"),
                fileName: "fictional-axis-card.\(fileExtension)",
                fileExtension: fileExtension,
                content: .text("fictional")
            )
            let selection = StatementParserSelector().selectParser(
                for: documentShell(for: raw),
                institution: institution,
                classification: classification
            )

            #expect(selection.matched)
            #expect(selection.parser.map { String(describing: type(of: $0)) } == expectedType)
            #expect(selection.legacyMetadata.documentType == .creditCard)
        }
    }

    @Test func unknownStatementTypeDoesNotSelectParser() async throws {
        let rawDocument = RawDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/selector.csv"),
            fileName: "selector.csv", fileExtension: "csv", content: .text("")
        )
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
            content: .text("")
        )
        let document = documentShell(for: rawDocument)
        let institution = ImportInstitutionCandidate(
            institutionCode: "Unsupported Bank",
            confidence: 0.99,
            reasons: ["Explicit unknown institution for selector dispatch."]
        )
        let classification = StatementClassification(
            documentType: .bankStatement,
            confidence: 0.95,
            reasons: ["Explicit type value for selector dispatch."]
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

    private func documentShell(for rawDocument: RawDocument) -> Document {
        Document(
            filename: rawDocument.fileName,
            url: rawDocument.sourceURL,
            fileType: rawDocument.fileExtension.uppercased(),
            importedAt: rawDocument.extractedAt
        )
    }

}
