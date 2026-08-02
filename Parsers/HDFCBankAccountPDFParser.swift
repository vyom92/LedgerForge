import Foundation

enum HDFCBankAccountPDFParserError: Error, Equatable, LocalizedError {
    case unsupportedDocumentFormat
    case invalidSourceSemantics

    var errorDescription: String? {
        switch self {
        case .unsupportedDocumentFormat:
            return "The HDFC PDF parser received a document outside hdfc.bank-account.pdf@1."
        case .invalidSourceSemantics:
            return "The HDFC PDF financial evidence failed exact reconciliation."
        }
    }
}

final class HDFCBankAccountPDFParser: StatementParser {
    static let profileID = "hdfc.bank-account.pdf"
    static let profileVersion = "1"

    var name: String { "HDFC Bank Account PDF" }

    func canParse(document: Document, metadata: DocumentMetadata) -> Bool {
        metadata.institution == .hdfc &&
        metadata.documentType == .bankAccount &&
        metadata.fileFormat == .pdf &&
        document.fileType.caseInsensitiveCompare(FileFormat.pdf.rawValue) == .orderedSame
    }

    func parse(document: NormalizedDocument) throws -> FinancialDocument {
        guard canParse(document: document.document, metadata: document.metadata) else {
            throw HDFCBankAccountPDFParserError.unsupportedDocumentFormat
        }
        do {
            return try HDFCBankAccountXLSParser().parse(
                document: document,
                fileFormat: .pdf,
                parserProfileID: Self.profileID,
                parserProfileVersion: Self.profileVersion,
                parserName: name
            )
        } catch {
            throw HDFCBankAccountPDFParserError.invalidSourceSemantics
        }
    }
}
