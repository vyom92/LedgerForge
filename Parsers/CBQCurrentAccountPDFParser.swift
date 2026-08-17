import CryptoKit
import Foundation

enum CBQCurrentAccountPDFParserError: Error, Equatable, LocalizedError {
    case unsupportedDocumentFormat
    case changedHeader
    case malformedSourceEvidence
    case malformedRow(sourceOrdinal: Int)
    case ascendingHistory(sourceOrdinal: Int)
    case balanceMismatch(sourceOrdinal: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocumentFormat: return "The CBQ PDF parser received a document outside the retained current-account profiles."
        case .changedHeader: return "The normalized CBQ PDF columns changed."
        case .malformedSourceEvidence: return "The CBQ PDF source identity or statement evidence is malformed or contradictory."
        case .malformedRow(let ordinal): return "CBQ PDF row \(ordinal) is malformed."
        case .ascendingHistory(let ordinal): return "CBQ history PDF row \(ordinal) violates descending source order."
        case .balanceMismatch(let ordinal): return "CBQ PDF row \(ordinal) does not reconcile to its printed balance."
        }
    }
}

final class CBQCurrentAccountPDFParser: StatementParser {
    static let historyProfileID = "cbq.current-account.history.pdf"
    static let monthlyProfileID = "cbq.current-account.monthly.pdf"
    static let profileVersion = "1"

    var name: String { "CBQ Current Account PDF" }

    func canParse(document: Document, metadata: DocumentMetadata) -> Bool {
        metadata.institution == .cbq && metadata.documentType == .bankAccount &&
            metadata.fileFormat == .pdf && document.fileType.caseInsensitiveCompare(FileFormat.pdf.rawValue) == .orderedSame
    }

    func parse(document: NormalizedDocument) throws -> FinancialDocument {
        guard canParse(document: document.document, metadata: document.metadata) else {
            throw CBQCurrentAccountPDFParserError.unsupportedDocumentFormat
        }
        guard document.header?.values == CBQCurrentAccountPDFNormalizer.logicalHeader,
              !document.rows.isEmpty else { throw CBQCurrentAccountPDFParserError.changedHeader }
        let fragments = Dictionary(uniqueKeysWithValues: document.sourceContext.preTransactionFragments.compactMap { fragment -> (String, String)? in
            let fields = fragment.text.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return (String(fields[0]), String(fields[1]))
        })
        let family: CBQCurrentAccountPDFFamily
        if fragments["ACCOUNT"] != nil { family = .history }
        else if fragments["MASKED_ACCOUNT"] != nil { family = .monthly }
        else { throw CBQCurrentAccountPDFParserError.malformedSourceEvidence }

        let currency = try CurrencyCode("QAR")
        let identifiers: [FinancialIdentifier]
        let partialIdentities: [CBQSourceIdentityObservation]
        let statementEvidence: SourceStatementEvidence?
        if family == .history {
            guard let rawAccount = fragments["ACCOUNT"] else { throw CBQCurrentAccountPDFParserError.malformedSourceEvidence }
            do {
                identifiers = [try FinancialIdentifier(kind: .institutionAccountId, rawValue: rawAccount, verificationState: .verified, provenance: .institutionStructuredField)]
            } catch { throw CBQCurrentAccountPDFParserError.malformedSourceEvidence }
            partialIdentities = []
            statementEvidence = SourceStatementEvidence(sourceFormatCode: "history-pdf", statementBoundaryDate: nil, period: nil, openingBalance: nil, closingBalance: nil)
        } else {
            guard let rawAccount = fragments["MASKED_ACCOUNT"], let rawIBAN = fragments["MASKED_IBAN"],
                  let boundaryText = fragments["STATEMENT_BOUNDARY"], let startText = fragments["PERIOD_START"],
                  let openingText = fragments["OPENING_BALANCE"], let closingText = fragments["CLOSING_BALANCE"] else {
                throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
            }
            do {
                partialIdentities = [
                    try CBQSourceIdentityObservation(kind: .maskedAccountNumber, rawPattern: rawAccount),
                    try CBQSourceIdentityObservation(kind: .maskedIBAN, rawPattern: rawIBAN)
                ]
                guard CBQSourceIdentityObservation.validatePair(partialIdentities) else {
                    throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
                }
                let boundary = try Self.monthlyBoundaryDate(boundaryText)
                let start = try Self.monthlyDate(startText)
                let period = try DeclaredStatementPeriod(start: start, end: boundary)
                statementEvidence = SourceStatementEvidence(
                    sourceFormatCode: "monthly-pdf",
                    statementBoundaryDate: boundary,
                    period: period,
                    openingBalance: try Money(amount: Self.decimal(openingText), currency: currency),
                    closingBalance: try Money(amount: Self.decimal(closingText), currency: currency)
                )
            } catch { throw CBQCurrentAccountPDFParserError.malformedSourceEvidence }
            identifiers = []
        }

        let profileID = family.profileID
        var transactions: [Transaction] = []
        var previousDate: StatementDate?
        for row in document.rows {
            guard row.values.count == CBQCurrentAccountPDFNormalizer.logicalHeader.count,
                  !row.values[1].isEmpty else { throw CBQCurrentAccountPDFParserError.malformedRow(sourceOrdinal: row.rowNumber) }
            do {
                let postingDate = family == .history ? try Self.historyDate(row.values[0]) : try Self.monthlyDate(row.values[0])
                if family == .history, let previousDate, postingDate > previousDate {
                    throw CBQCurrentAccountPDFParserError.ascendingHistory(sourceOrdinal: row.rowNumber)
                }
                previousDate = postingDate
                let sourceTransactionDate = row.values[2].isEmpty ? nil : try Self.monthlyDate(row.values[2])
                let signedAmount = try Self.decimal(row.values[3])
                guard signedAmount != .zero else { throw CBQCurrentAccountPDFParserError.malformedRow(sourceOrdinal: row.rowNumber) }
                let balance = try Self.decimal(row.values[4])
                let debit = signedAmount < .zero ? -signedAmount : nil
                let credit = signedAmount > .zero ? signedAmount : nil
                let structuredDigest = Self.structuredReferenceDigest(in: row.values[1])
                transactions.append(Transaction(
                    statementDate: postingDate,
                    valueDate: nil,
                    description: row.values[1],
                    reference: nil,
                    debitMoney: try debit.map { try Money(amount: $0, currency: currency) },
                    creditMoney: try credit.map { try Money(amount: $0, currency: currency) },
                    money: try Money(amount: signedAmount, currency: currency),
                    runningBalanceMoney: try Money(amount: balance, currency: currency),
                    account: document.metadata.institution.rawValue,
                    sourceBank: document.metadata.institution.rawValue,
                    sourceFile: document.document.filename,
                    financialDateRole: .postingDate,
                    statementTimezoneEvidence: .iana("Asia/Qatar"),
                    sourceProvenance: [TransactionSourceProvenance(
                        normalizedDocumentID: document.document.id.uuidString,
                        normalizedRowID: row.id.uuidString,
                        sourceOrdinal: row.rowNumber,
                        normalizedRecordDigest: String.normalizedRecordDigest(values: row.values),
                        parserProfileID: profileID,
                        parserProfileVersion: Self.profileVersion,
                        sourceTransactionDate: sourceTransactionDate,
                        structuredReferenceDigest: structuredDigest
                    )]
                ))
            } catch let error as CBQCurrentAccountPDFParserError { throw error }
            catch { throw CBQCurrentAccountPDFParserError.malformedRow(sourceOrdinal: row.rowNumber) }
        }
        if family == .monthly, let expected = statementEvidence?.closingBalance,
           transactions.last?.runningBalanceMoney != expected {
            throw CBQCurrentAccountPDFParserError.balanceMismatch(sourceOrdinal: document.rows.last?.rowNumber ?? 0)
        }
        return FinancialDocument(
            sourceDocument: document.document,
            metadata: document.metadata,
            parserName: family == .history ? "CBQ Current Account History PDF" : "CBQ Current Account Monthly PDF",
            bookedCurrency: currency,
            declaredStatementPeriod: statementEvidence?.period,
            transactions: transactions,
            financialIdentifiers: identifiers,
            cbqSourceIdentityObservations: partialIdentities,
            sourceStatementEvidence: statementEvidence
        )
    }

    private static func decimal(_ source: String) throws -> Decimal {
        let normalized = source.replacingOccurrences(of: ",", with: "")
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
        }
        return value
    }

    private static func historyDate(_ source: String) throws -> StatementDate {
        let values = source.split(separator: "/")
        guard values.count == 3, let day = Int(values[0]), let month = Int(values[1]), let year = Int(values[2]) else {
            throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
        }
        return try StatementDate(year: year, month: month, day: day)
    }

    private static func monthlyDate(_ source: String) throws -> StatementDate {
        let values = source.split(separator: "-")
        guard values.count == 3, let day = Int(values[0]), let month = month(String(values[1])), let year = Int(values[2]) else {
            throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
        }
        return try StatementDate(year: 2000 + year, month: month, day: day)
    }

    private static func monthlyBoundaryDate(_ source: String) throws -> StatementDate {
        let values = source.split(separator: " ")
        guard values.count == 3, let day = Int(values[0]), let month = month(String(values[1])), let year = Int(values[2]) else {
            throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
        }
        return try StatementDate(year: 2000 + year, month: month, day: day)
    }

    private static func month(_ source: String) -> Int? {
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            .firstIndex(where: { $0.caseInsensitiveCompare(source) == .orderedSame }).map { $0 + 1 }
    }

    private static func structuredReferenceDigest(in narration: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: #"\b[0-9]{6,}[A-Z0-9]*\b"#),
              let match = expression.firstMatch(in: narration, range: NSRange(narration.startIndex..., in: narration)),
              let range = Range(match.range, in: narration) else { return nil }
        let value = String(narration[range]).uppercased()
        return SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
