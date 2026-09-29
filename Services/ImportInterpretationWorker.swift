import Foundation

/// Only value-owned source interpretation crosses the worker boundary. Snapshot
/// leases, credentials, review/mapping and PreparedImport remain on MainActor.
/// Each invocation creates its own normalizers and parser registry. No parser
/// object, PDFDocument, provider or mutable import session is shared by workers.
nonisolated enum ImportInterpretationWorker {
    typealias Progress = @MainActor @Sendable (ImportProgressPhase) throws -> Void

    struct Result: Sendable {
        let financialDocument: FinancialDocument
        let validation: ImportValidationResult
    }

    struct BankCardResult: Sendable {
        let document: Document
        let metadata: DocumentMetadata
        let financialDocument: FinancialDocument
        let validation: ImportValidationResult
        let parserName: String
        let normalizedRowCount: Int
        let credentialInstitution: Institution
        let axisCreditCardPDFPresentation: AxisCreditCardPDFPresentation?
    }

    @concurrent
    static func investment(_ source: RawDocument, progress: Progress) async throws -> Result {
        try Task.checkCancellation()
        try await progress(.classifyingStatement)
        let financialDocument = try parseInvestment(source)
        try Task.checkCancellation()
        try await progress(.validatingPreparedContent)
        let validation = validate(financialDocument)
        try Task.checkCancellation()
        return Result(financialDocument: financialDocument, validation: validation)
    }

    @concurrent
    static func salary(_ source: RawDocument, progress: Progress) async throws -> Result {
        try Task.checkCancellation()
        try await progress(.classifyingStatement)
        let financialDocument = try parseSalary(source)
        try Task.checkCancellation()
        try await progress(.validatingPreparedContent)
        let validation = validate(financialDocument)
        try Task.checkCancellation()
        return Result(financialDocument: financialDocument, validation: validation)
    }

    @concurrent
    static func bankOrCard(
        _ rawDocument: RawDocument, sourceFormat: FileFormat,
        sourceURL url: URL, progress: Progress
    ) async throws -> BankCardResult {
        try Task.checkCancellation()
        try await progress(.detectingInstitution)
        let detection = InstitutionDetector().detectWithReasons(in: rawDocument)
        let institutionCandidate = detection.importCandidate

        try await progress(.classifyingStatement)
        let classification = try await StatementClassificationDetector().classify(
            document: rawDocument,
            institution: institutionCandidate
        )
        let normalized = try normalize(rawDocument, sourceFormat: sourceFormat, sourceURL: url,
            institutionCandidate: institutionCandidate, classification: classification)
        let document = normalized.document
        let normalizedRows = normalized.rows
        let normalizedHeader = normalized.header
        let sourceContext = normalized.sourceContext
        let axisCreditCardPDFPresentation = normalized.axisCreditCardPDFPresentation

        try await progress(.selectingParser)
        let selection = StatementParserSelector(registry: StatementParserRegistry()).selectParser(
            for: document,
            institution: institutionCandidate,
            classification: classification
        )
        let parser = selection.parser
        let metadata = selection.legacyMetadata

        guard let parser else {
            throw ImportError.invalidDocument(message: "No suitable parser found.")
        }
        let normalizedDocument = NormalizedDocument(
            document: document,
            metadata: metadata,
            rows: normalizedRows,
            header: normalizedHeader,
            sourceContext: sourceContext
        )

        try await progress(.parsingFinancialContent)
        let financialDocument = try parseBankOrCard(parser, document: normalizedDocument)
        try Task.checkCancellation()

        try await progress(.validatingPreparedContent)
        let validation = validate(financialDocument)
        try Task.checkCancellation()
        return BankCardResult(document: document, metadata: metadata,
            financialDocument: financialDocument, validation: validation, parserName: financialDocument.parserName,
            normalizedRowCount: normalizedRows.count, credentialInstitution: detection.metadata.institution,
            axisCreditCardPDFPresentation: axisCreditCardPDFPresentation)
    }

    private struct Normalization {
        let document: Document
        let rows: [NormalizedRow]
        let header: NormalizedRow?
        let sourceContext: NormalizedDocument.SourceContext
        let axisCreditCardPDFPresentation: AxisCreditCardPDFPresentation?
    }

    private static func normalize(
        _ rawDocument: RawDocument, sourceFormat: FileFormat, sourceURL url: URL,
        institutionCandidate: ImportInstitutionCandidate, classification: StatementClassification
    ) throws -> Normalization {
#if DEBUG
        let started = GmailQualificationTiming.begin(.sourceNormalization)
        defer { GmailQualificationTiming.end(.sourceNormalization, started: started) }
#endif
        try Task.checkCancellation()
        let contents = rawDocument.searchableText
        let document: Document
        let normalizedRows: [NormalizedRow]
        let normalizedHeader: NormalizedRow?
        let sourceContext: NormalizedDocument.SourceContext
        var axisCreditCardPDFPresentation: AxisCreditCardPDFPresentation?
        switch sourceFormat {
        case .csv:
            let csvDocument = CSVAnalyzer().analyze(text: contents, fileURL: url)
            let normalization = CSVNormalizer().normalizeWithSourceContext(
                text: contents,
                document: csvDocument
            )
            document = csvDocument
            normalizedRows = normalization.rows
            normalizedHeader = normalization.header
            sourceContext = normalization.sourceContext
        case .pdf:
            guard let readerPageTexts = rawDocument.pdfPageTexts else {
                throw ImportError.invalidDocument(message: "PDF reader did not retain page evidence.")
            }
            switch institutionCandidate.institutionCode {
            case Institution.axis.rawValue:
                let normalization: (document: Document, rows: [NormalizedRow], header: NormalizedRow?, sourceContext: NormalizedDocument.SourceContext)
                if BankRelationshipPDFNormalizer.recognizes(contents, family: .axis) {
                    let bank = try BankRelationshipPDFNormalizer().normalize(text: contents,
                        pageEvidence: rawDocument.pdfPageEvidence, fileURL: url, family: .axis)
                    normalization = (bank.document, bank.rows, bank.header, bank.sourceContext)
                } else if classification.documentType == .creditCardStatement {
                    let card = try AxisCreditCardPDFNormalizer().normalize(
                            text: contents,
                            pageTexts: readerPageTexts,
                            pageEvidence: rawDocument.pdfPageEvidence,
                            taggedTables: rawDocument.pdfTaggedTables,
                            fileURL: url
                        )
                    normalization = (card.document, card.rows, card.header, card.sourceContext)
                    axisCreditCardPDFPresentation = card.presentation
                } else {
                    let bank = try AxisBankAccountPDFNormalizer().normalize(
                        text: contents,
                        pageEvidence: rawDocument.pdfPageEvidence,
                        fileURL: url
                    )
                    normalization = (bank.document, bank.rows, bank.header, bank.sourceContext)
                }
                document = normalization.document
                normalizedRows = normalization.rows
                normalizedHeader = normalization.header
                sourceContext = normalization.sourceContext
            case Institution.hdfc.rawValue:
                if BankRelationshipPDFNormalizer.recognizes(contents, family: .hdfc) {
                    let bank = try BankRelationshipPDFNormalizer().normalize(text: contents,
                        pageEvidence: rawDocument.pdfPageEvidence, fileURL: url, family: .hdfc)
                    document = bank.document; normalizedRows = bank.rows
                    normalizedHeader = bank.header; sourceContext = bank.sourceContext
                } else {
                    let bank = try HDFCBankAccountPDFNormalizer().normalize(
                        text: contents, pageEvidence: rawDocument.pdfPageEvidence, fileURL: url)
                    document = bank.document; normalizedRows = bank.rows
                    normalizedHeader = bank.header; sourceContext = bank.sourceContext
                }
            case Institution.cbq.rawValue:
                let normalization: (document: Document, rows: [NormalizedRow], header: NormalizedRow?, sourceContext: NormalizedDocument.SourceContext)
                if classification.documentType == .creditCardStatement {
                    let card = try CBQCreditCardPDFNormalizer().normalize(
                        text: contents, pageTexts: readerPageTexts, fileURL: url
                    )
                    normalization = (card.document, card.rows, card.header, card.sourceContext)
                } else {
                    let bank = try CBQCurrentAccountPDFNormalizer().normalize(
                            text: contents,
                            pageTexts: readerPageTexts,
                            pageEvidence: rawDocument.pdfPageEvidence,
                            fileURL: url
                        )
                    normalization = (bank.document, bank.rows, bank.header, bank.sourceContext)
                }
                document = normalization.document
                normalizedRows = normalization.rows
                normalizedHeader = normalization.header
                sourceContext = normalization.sourceContext
            case Institution.amex.rawValue:
                let normalization = try AmericanExpressCreditCardPDFNormalizer().normalize(
                        text: contents,
                        pageTexts: readerPageTexts,
                        pageEvidence: rawDocument.pdfPageEvidence,
                        fileURL: url
                    )
                document = normalization.document
                normalizedRows = normalization.rows
                normalizedHeader = normalization.header
                sourceContext = normalization.sourceContext
            default:
                throw ImportError.invalidDocument(message: "No suitable PDF normalizer found.")
            }
        case .xls:
            switch institutionCandidate.institutionCode {
            case Institution.axis.rawValue:
                let normalization = try AxisBankAccountXLSNormalizer().normalize(
                    rawDocument: rawDocument
                )
                document = normalization.document
                normalizedRows = normalization.rows
                normalizedHeader = normalization.header
                sourceContext = normalization.sourceContext
            case Institution.hdfc.rawValue:
                let normalization = try HDFCBankAccountXLSNormalizer().normalize(
                    rawDocument: rawDocument
                )
                document = normalization.document
                normalizedRows = normalization.rows
                normalizedHeader = normalization.header
                sourceContext = normalization.sourceContext
            case Institution.cbq.rawValue:
                let normalization = try CBQCurrentAccountXLSNormalizer().normalize(
                    rawDocument: rawDocument
                )
                document = normalization.document
                normalizedRows = normalization.rows
                normalizedHeader = normalization.header
                sourceContext = normalization.sourceContext
            default:
                throw ImportError.invalidDocument(
                    message: "No suitable XLS normalizer found."
                )
            }
        case .xlsx:
            switch institutionCandidate.institutionCode {
            case Institution.axis.rawValue:
                guard classification.documentType == .creditCardStatement else {
                    throw ImportError.invalidDocument(message: "No suitable XLSX normalizer found.")
                }
                let normalization = try AxisCreditCardXLSXNormalizer().normalize(
                    rawDocument: rawDocument
                )
                document = normalization.document
                normalizedRows = normalization.rows
                normalizedHeader = normalization.header
                sourceContext = normalization.sourceContext
            default:
                throw ImportError.invalidDocument(
                    message: "No suitable XLSX normalizer found."
                )
            }
        case .unknown:
            throw ImportError.unsupportedFile(extension: rawDocument.fileExtension)
        }

        try Task.checkCancellation()
        return Normalization(document: document, rows: normalizedRows, header: normalizedHeader,
            sourceContext: sourceContext, axisCreditCardPDFPresentation: axisCreditCardPDFPresentation)
    }

    private static func parseBankOrCard(_ parser: StatementParser, document: NormalizedDocument) throws -> FinancialDocument {
#if DEBUG
        let started = GmailQualificationTiming.begin(.sourceParsing)
        defer { GmailQualificationTiming.end(.sourceParsing, started: started) }
#endif
        return try parser.parse(document: document)
    }

    private static func parseInvestment(_ source: RawDocument) throws -> FinancialDocument {
#if DEBUG
        let started = GmailQualificationTiming.begin(.sourceParsing)
        defer { GmailQualificationTiming.end(.sourceParsing, started: started) }
#endif
        return try InvestmentStatementParser().parse(source)
    }

    private static func parseSalary(_ source: RawDocument) throws -> FinancialDocument {
#if DEBUG
        let started = GmailQualificationTiming.begin(.sourceParsing)
        defer { GmailQualificationTiming.end(.sourceParsing, started: started) }
#endif
        return try QatarAirwaysSalaryPDFParser().parse(source)
    }

    private static func validate(_ document: FinancialDocument) -> ImportValidationResult {
#if DEBUG
        let started = GmailQualificationTiming.begin(.sourceValidation)
        defer { GmailQualificationTiming.end(.sourceValidation, started: started) }
#endif
        return ImportValidator.validate(financialDocument: document)
    }
}
