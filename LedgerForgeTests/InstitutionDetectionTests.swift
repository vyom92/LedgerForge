// LedgerForgeTests/InstitutionDetectionTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct InstitutionDetectionTests {

    @Test func axisCSVFixtureDetectsAxisBankThroughFrameworkDetector() async throws {
        let csvURL = FixtureLocator.axisCSV("axis_bank_nre_account_statement_baseline.csv")
        let text = try CSVReader().read(from: csvURL)
        let rawDocument = RawDocument(
            sourceURL: csvURL,
            fileName: csvURL.lastPathComponent,
            fileExtension: csvURL.pathExtension,
            content: .text(text)
        )

        let candidate = try await SignatureInstitutionDetector().detectInstitution(in: rawDocument)

        #expect(candidate.institutionCode == Institution.axis.rawValue)
        #expect(candidate.confidence == 0.98)
        #expect(!candidate.reasons.isEmpty)
        #expect(candidate.reasons.contains { $0.localizedCaseInsensitiveContains("Axis") || $0.localizedCaseInsensitiveContains("IFSC") })
    }

    @Test func axisPDFFixtureDetectsAxisBankThroughFrameworkDetector() async throws {
        let pdfURL = FixtureLocator.axisPDF("axis_bank_nre_account_statement_baseline.pdf")
        try #require(FixtureLocator.fileExists(at: pdfURL))

        let rawDocument = try await PDFDocumentReader().read(
            request: ImportRequest(fileURL: pdfURL),
            password: nil
        )

        let candidate = try await SignatureInstitutionDetector().detectInstitution(in: rawDocument)

        #expect(candidate.institutionCode == Institution.axis.rawValue)
        #expect(candidate.confidence == 0.98)
        #expect(!candidate.reasons.isEmpty)
    }

    @Test func unknownTextProducesUnknownDetectionWithoutInventingInstitution() async throws {
        let rawDocument = RawDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/notes.txt"),
            fileName: "notes.txt",
            fileExtension: "txt",
            content: .text("Personal notes without bank names, IFSC codes, statement titles or account details.")
        )

        let candidate = try await SignatureInstitutionDetector().detectInstitution(in: rawDocument)
        let legacyMetadata = InstitutionDetector().detect(from: "Personal notes without bank names.")

        #expect(candidate.institutionCode == nil)
        #expect(candidate.confidence == 0.0)
        #expect(candidate.reasons == ["No institution signatures matched."])
        #expect(legacyMetadata.institution == .unknown)
        #expect(legacyMetadata.documentType == .unknown)
        #expect(legacyMetadata.confidence == 0.0)
    }

    @Test func legacyDetectorPreservesAxisMetadataBehaviour() async throws {
        let text = "Statement of Axis Account with IFSC Code UTIB0000000"
        let metadata = InstitutionDetector().detect(from: text)
        let explainedResult = InstitutionDetector().detectWithReasons(from: text)

        #expect(metadata.institution == .axis)
        #expect(metadata.documentType == .bankAccount)
        #expect(metadata.fileFormat == .unknown)
        #expect(metadata.confidence == 0.98)
        #expect(explainedResult.metadata == metadata)
        #expect(!explainedResult.reasons.isEmpty)
    }

    @Test func nonTextRawDocumentReturnsUnknownCandidateWithReason() async throws {
        let rawDocument = RawDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/document.bin"),
            fileName: "document.bin",
            fileExtension: "bin",
            content: .data(Data([0x00, 0x01]))
        )

        let candidate = try await SignatureInstitutionDetector().detectInstitution(in: rawDocument)

        #expect(candidate.institutionCode == nil)
        #expect(candidate.confidence == 0.0)
        #expect(candidate.reasons == ["RawDocument did not contain extracted text."])
    }
}
