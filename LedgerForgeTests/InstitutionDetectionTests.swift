// LedgerForgeTests/InstitutionDetectionTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct InstitutionDetectionTests {

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
