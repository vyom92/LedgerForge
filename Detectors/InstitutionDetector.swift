import Foundation

final class InstitutionDetector {

    func detect(from text: String) -> DocumentMetadata {

        let upper = text.uppercased()

        if upper.contains("UTIB") || upper.contains("AXIS BANK") {
            return DocumentMetadata(
                institution: .axis,
                documentType: .bankAccount,
                fileFormat: .unknown,
                confidence: 0.98
            )
        }

        return DocumentMetadata(
            institution: .unknown,
            documentType: .unknown,
            fileFormat: .unknown,
            confidence: 0.0
        )
    }
}
