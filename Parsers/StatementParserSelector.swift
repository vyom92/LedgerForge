// LedgerForge
// StatementParserSelector.swift
// Version: 0.1.0

import Foundation

final class StatementParserSelector {

    private let registry: StatementParserRegistry

    init(registry: StatementParserRegistry = .shared) {
        self.registry = registry
    }

    func selectParser(
        for document: Document,
        institution: ImportInstitutionCandidate?,
        classification: StatementClassification
    ) -> ParserSelection {
        let metadata = legacyMetadata(
            from: institution,
            classification: classification,
            fileFormat: fileFormat(from: document.fileType)
        )
        var reasons = selectionReasons(
            institution: institution,
            classification: classification,
            metadata: metadata
        )

        guard metadata.institution != .unknown else {
            reasons.append("No parser selected because institution is unknown.")
            return noMatch(metadata: metadata, reasons: reasons)
        }

        guard metadata.documentType != .unknown else {
            reasons.append("No parser selected because statement type is unknown.")
            return noMatch(metadata: metadata, reasons: reasons)
        }

        guard let parser = registry.parser(for: document, metadata: metadata) else {
            reasons.append("No parser matched the detected institution and statement type.")
            return noMatch(metadata: metadata, reasons: reasons)
        }

        reasons.append("Selected parser: \(parser.name).")

        return ParserSelection(
            parser: parser,
            parserName: parser.name,
            matched: true,
            confidence: selectionConfidence(institution: institution, classification: classification),
            reasons: reasons,
            legacyMetadata: metadata
        )
    }

    private func noMatch(metadata: DocumentMetadata, reasons: [String]) -> ParserSelection {
        ParserSelection(
            parser: nil,
            parserName: nil,
            matched: false,
            confidence: 0.0,
            reasons: reasons,
            legacyMetadata: metadata
        )
    }

    private func legacyMetadata(
        from institution: ImportInstitutionCandidate?,
        classification: StatementClassification,
        fileFormat: FileFormat
    ) -> DocumentMetadata {
        DocumentMetadata(
            institution: legacyInstitution(from: institution),
            documentType: classification.documentType.legacyDocumentType,
            fileFormat: fileFormat,
            confidence: selectionConfidence(institution: institution, classification: classification)
        )
    }

    private func legacyInstitution(from candidate: ImportInstitutionCandidate?) -> Institution {
        guard let institutionCode = candidate?.institutionCode else {
            return .unknown
        }

        return Institution(rawValue: institutionCode) ?? .unknown
    }

    private func fileFormat(from fileType: String) -> FileFormat {
        FileFormat(rawValue: fileType.uppercased()) ?? .unknown
    }

    private func selectionConfidence(
        institution: ImportInstitutionCandidate?,
        classification: StatementClassification
    ) -> Double {
        min(institution?.confidence ?? 0.0, classification.confidence)
    }

    private func selectionReasons(
        institution: ImportInstitutionCandidate?,
        classification: StatementClassification,
        metadata: DocumentMetadata
    ) -> [String] {
        var reasons: [String] = []

        if let institutionCode = institution?.institutionCode {
            reasons.append("Detected institution: \(institutionCode).")
        } else {
            reasons.append("Institution detection did not identify a supported institution.")
        }

        reasons.append("Classified statement type: \(classification.documentType.rawValue).")
        reasons.append("Mapped legacy parser metadata: \(metadata.institution.rawValue) / \(metadata.documentType.rawValue).")

        return reasons
    }

}
