import CryptoKit
import Foundation

nonisolated enum CBQCurrentAccountPDFParserError: Error, Equatable, LocalizedError {
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

nonisolated final class CBQCurrentAccountPDFParser: StatementParser {
    static let historyProfileID = "cbq.current-account.history.pdf"
    static let monthlyProfileID = "cbq.current-account.monthly.pdf"
    static let profileVersion = "1"
    static let bankProfileIDs = [historyProfileID, monthlyProfileID,
        CBQCurrentAccountPDFFamily.legacyCurrent.profileID,
        CBQCurrentAccountPDFFamily.usdMonthly.profileID,
        CBQCurrentAccountPDFFamily.savingsLegacy.profileID,
        CBQCurrentAccountPDFFamily.savingsMonthly.profileID,
        CBQCurrentAccountPDFFamily.eSavingsMonthly.profileID]

    var name: String { "CBQ Current Account PDF" }

    func canParse(document: Document, metadata: DocumentMetadata) -> Bool {
        metadata.institution == .cbq && metadata.documentType == .bankAccount &&
            metadata.fileFormat == .pdf && document.fileType.caseInsensitiveCompare(FileFormat.pdf.rawValue) == .orderedSame
    }

    func parse(document: NormalizedDocument) throws -> FinancialDocument {
        guard canParse(document: document.document, metadata: document.metadata) else {
            throw CBQCurrentAccountPDFParserError.unsupportedDocumentFormat
        }
        guard document.header?.values == CBQCurrentAccountPDFNormalizer.logicalHeader else {
            throw CBQCurrentAccountPDFParserError.changedHeader
        }
        let pairs = document.sourceContext.preTransactionFragments.compactMap { fragment -> (String, String)? in
            let fields = fragment.text.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return (String(fields[0]), String(fields[1]))
        }
        guard Set(pairs.map(\.0)).count == pairs.count else {
            throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
        }
        let fragments = Dictionary(uniqueKeysWithValues: pairs)
        let family: CBQCurrentAccountPDFFamily
        if fragments["ACCOUNT"] != nil { family = .history }
        else if let product = fragments["PRODUCT"] {
            switch product {
            case "Current Account-Retail":
                if fragments["SOURCE_SECOND_DATE_ROLE"] == "value_date" { family = .legacyCurrent }
                else if fragments["CURRENCY_CODE"] == "USD" { family = .usdMonthly }
                else { family = .monthly }
            case "Savings Account": family = fragments["SOURCE_SECOND_DATE_ROLE"] == "value_date" ? .savingsLegacy : .savingsMonthly
            case "E Savings Account": family = .eSavingsMonthly
            default: throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
            }
        } else if fragments["MASKED_ACCOUNT"] != nil { family = .monthly }
        else { throw CBQCurrentAccountPDFParserError.malformedSourceEvidence }

        let currency = try CurrencyCode(family == .usdMonthly ? "USD" : "QAR")
        let identifiers: [FinancialIdentifier]
        let partialIdentities: [CBQSourceIdentityObservation]
        var statementEvidence: SourceStatementEvidence?
        if family == .history {
            guard let rawAccount = fragments["ACCOUNT"] else { throw CBQCurrentAccountPDFParserError.malformedSourceEvidence }
            do {
                identifiers = [try FinancialIdentifier(kind: .institutionAccountId, rawValue: rawAccount, verificationState: .verified, provenance: .institutionStructuredField)]
            } catch { throw CBQCurrentAccountPDFParserError.malformedSourceEvidence }
            partialIdentities = []
            statementEvidence = SourceStatementEvidence(sourceFormatCode: "history-pdf", statementBoundaryDate: nil, period: nil, openingBalance: nil, closingBalance: nil)
        } else {
            guard let rawAccount = fragments["MASKED_ACCOUNT"], let rawIBAN = fragments["MASKED_IBAN"],
                  let boundaryText = fragments["STATEMENT_BOUNDARY"], let closingText = fragments["CLOSING_BALANCE"] else {
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
                if family == .savingsLegacy || family == .legacyCurrent {
                    let boundary = try Self.monthlyBoundaryDate(boundaryText)
                    let period = try fragments["PERIOD_START"].map {
                        try DeclaredStatementPeriod(start: Self.legacyDate($0), end: boundary)
                    }
                    guard let openingText = fragments["OPENING_BALANCE"] else {
                        throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
                    }
                    statementEvidence = SourceStatementEvidence(
                        sourceFormatCode: "legacy-pdf",
                        statementBoundaryDate: boundary, period: period,
                        openingBalance: try Money(amount: Self.decimal(openingText), currency: currency),
                        closingBalance: try Money(amount: Self.decimal(closingText), currency: currency)
                    )
                } else {
                    guard let openingText = fragments["OPENING_BALANCE"],
                          family != .monthly || fragments["PERIOD_START"] != nil else {
                        throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
                    }
                    let boundary = try Self.monthlyBoundaryDate(boundaryText)
                    let period = try fragments["PERIOD_START"].map {
                        try DeclaredStatementPeriod(start: Self.monthlyDate($0), end: boundary)
                    }
                    statementEvidence = SourceStatementEvidence(
                        sourceFormatCode: "monthly-pdf",
                        statementBoundaryDate: boundary,
                        period: period,
                        openingBalance: try Money(amount: Self.decimal(openingText), currency: currency),
                        closingBalance: try Money(amount: Self.decimal(closingText), currency: currency)
                    )
                }
            } catch { throw CBQCurrentAccountPDFParserError.malformedSourceEvidence }
            identifiers = []
        }

        let profileID = family.profileID
        var transactions: [Transaction] = []
        for row in document.rows {
            guard row.values.count == CBQCurrentAccountPDFNormalizer.logicalHeader.count,
                  !row.values[1].isEmpty else { throw CBQCurrentAccountPDFParserError.malformedRow(sourceOrdinal: row.rowNumber) }
            do {
                let postingDate = family == .history ? try Self.historyDate(row.values[0]) : [.savingsLegacy, .legacyCurrent].contains(family) ? try Self.legacyDate(row.values[0]) : try Self.monthlyDate(row.values[0])
                let sourceTransactionDate = [.savingsLegacy, .legacyCurrent].contains(family) || row.values[2].isEmpty ? nil : try Self.monthlyDate(row.values[2])
                let valueDate = [.savingsLegacy, .legacyCurrent].contains(family) ? try Self.legacyDate(row.values[2]) : nil
                let signedAmount = try Self.decimal(row.values[3])
                guard signedAmount != .zero else { throw CBQCurrentAccountPDFParserError.malformedRow(sourceOrdinal: row.rowNumber) }
                let balance = try Self.decimal(row.values[4])
                // Source order and balances remain provenance. The source
                // column's signed amount determines this occurrence's effect.
                let debit = signedAmount < .zero ? -signedAmount : nil
                let credit = signedAmount > .zero ? signedAmount : nil
                let structuredDigest = Self.structuredReferenceDigest(in: row.values[1])
                transactions.append(Transaction(
                    statementDate: postingDate,
                    valueDate: valueDate,
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
                        sourcePage: row.sourcePage,
                        normalizedRecordDigest: String.normalizedRecordDigest(values: row.values),
                        parserProfileID: profileID,
                        parserProfileVersion: Self.profileVersion,
                        sourceTransactionDate: sourceTransactionDate,
                        structuredReferenceDigest: structuredDigest,
                        literalRunningBalance: row.rawValues?[4] ?? row.values[4]
                    )]
                ))
            } catch let error as CBQCurrentAccountPDFParserError { throw error }
            catch { throw CBQCurrentAccountPDFParserError.malformedRow(sourceOrdinal: row.rowNumber) }
        }
        let zeroEvidence: ZeroActivityStatementEvidence?
        if transactions.isEmpty {
            if [.legacyCurrent, .savingsLegacy].contains(family), let source = statementEvidence {
                statementEvidence = SourceStatementEvidence(
                    sourceFormatCode: source.sourceFormatCode,
                    statementBoundaryDate: source.statementBoundaryDate,
                    period: nil,
                    openingBalance: source.openingBalance,
                    closingBalance: source.closingBalance
                )
            }
            guard family != .history, let statementEvidence,
                  (family == .legacyCurrent || family == .savingsLegacy || statementEvidence.period != nil),
                  let opening = statementEvidence.openingBalance,
                  let closing = statementEvidence.closingBalance,
                  let regionStart = fragments["FINANCIAL_REGION_START"].flatMap(Int.init),
                  let regionEnd = fragments["FINANCIAL_REGION_END"].flatMap(Int.init),
                  let signature = fragments["FINANCIAL_REGION_SIGNATURE"] else {
                throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
            }
            // CBQ prints balances, not debit/credit total controls. The
            // normalizer must exhaust the header-to-closing financial region;
            // do not label invented zero totals as printed source evidence.
            zeroEvidence = try ZeroActivityStatementEvidence(
                profileID: profileID, profileVersion: Self.profileVersion,
                sourceFormatCode: "pdf", evidenceKind: .exhaustedFinancialRegion,
                financialRegionDescriptor: "Monthly account table through closing balance",
                financialRegionStartOrdinal: regionStart,
                financialRegionEndOrdinal: regionEnd,
                financialRegionSignature: signature,
                statementDate: statementEvidence.statementBoundaryDate,
                statementPeriod: [.legacyCurrent, .savingsLegacy].contains(family) ? nil : statementEvidence.period,
                nativeCurrency: currency,
                openingBalance: opening, closingBalance: closing
            )
        } else {
            zeroEvidence = nil
        }
        return FinancialDocument(
            sourceDocument: document.document,
            metadata: document.metadata,
            parserName: Self.parserName(for: family),
            parserProfileID: profileID,
            parserProfileVersion: Self.profileVersion,
            bookedCurrency: currency,
            declaredStatementPeriod: transactions.isEmpty && [.legacyCurrent, .savingsLegacy].contains(family)
                ? nil : statementEvidence?.period,
            transactions: transactions,
            financialIdentifiers: identifiers,
            cbqSourceIdentityObservations: partialIdentities,
            sourceStatementEvidence: statementEvidence,
            zeroActivityEvidence: zeroEvidence
        )
    }

    private static func decimal(_ source: String) throws -> Decimal {
        guard source.range(of: #"^-?[0-9]+(?:,[0-9]{3})*\.[0-9]{2}$"#, options: .regularExpression) != nil else {
            throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
        }
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

    private static func legacyDate(_ source: String) throws -> StatementDate {
        guard source.range(of: #"^[0-9]{2}[A-Za-z]{3}[0-9]{2}$"#, options: .regularExpression) != nil else {
            throw CBQCurrentAccountPDFParserError.malformedSourceEvidence
        }
        return try monthlyDate("\(source.prefix(2))-\(source.dropFirst(2).prefix(3))-\(source.suffix(2))")
    }

    private static func parserName(for family: CBQCurrentAccountPDFFamily) -> String {
        switch family {
        case .history: return "CBQ Current Account History PDF"
        case .legacyCurrent: return "CBQ Current Account Legacy PDF"
        case .monthly: return "CBQ Current Account Monthly PDF"
        case .usdMonthly: return "CBQ Current Account USD Monthly PDF"
        case .savingsLegacy: return "CBQ Savings Account Legacy PDF"
        case .savingsMonthly: return "CBQ Savings Account Monthly PDF"
        case .eSavingsMonthly: return "CBQ E Savings Account Monthly PDF"
        }
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
