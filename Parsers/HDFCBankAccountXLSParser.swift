import Foundation

enum HDFCBankAccountXLSParserError: Error, Equatable, LocalizedError {
    case unsupportedDocumentFormat
    case missingHeader
    case changedHeader
    case noTransactions
    case missingPreambleEvidence
    case malformedStatementPeriod(sourceOrdinal: Int)
    case malformedCurrency(sourceOrdinal: Int)
    case missingAccountNumber(sourceOrdinal: Int)
    case malformedAccountNumber(sourceOrdinal: Int)
    case malformedCustomerIdentifier(sourceOrdinal: Int)
    case malformedRow(sourceOrdinal: Int)
    case malformedDate(sourceOrdinal: Int)
    case malformedValueDate(sourceOrdinal: Int)
    case malformedMonetaryValue(sourceOrdinal: Int)
    case missingDirection(sourceOrdinal: Int)
    case ambiguousDirection(sourceOrdinal: Int)
    case nonPositiveAmount(sourceOrdinal: Int)
    case missingBalance(sourceOrdinal: Int)
    case missingSummary
    case malformedSummary(sourceOrdinal: Int)
    case openingBalanceMismatch(sourceOrdinal: Int)
    case runningBalanceMismatch(sourceOrdinal: Int)
    case debitCountMismatch
    case creditCountMismatch
    case debitTotalMismatch
    case creditTotalMismatch
    case closingBalanceMismatch

    var errorDescription: String? {
        switch self {
        case .unsupportedDocumentFormat:
            return "The HDFC XLS parser received a non-XLS normalized document."
        case .missingHeader:
            return "The HDFC XLS normalized header is missing."
        case .changedHeader:
            return "The HDFC XLS normalized header does not match the retained layout."
        case .noTransactions:
            return "The HDFC XLS parser received no transaction rows."
        case .missingPreambleEvidence:
            return "The HDFC XLS preamble evidence is incomplete."
        case .malformedStatementPeriod(let sourceOrdinal):
            return "HDFC XLS statement-period evidence on row \(sourceOrdinal) is malformed."
        case .malformedCurrency(let sourceOrdinal):
            return "HDFC XLS currency evidence on row \(sourceOrdinal) is malformed."
        case .missingAccountNumber(let sourceOrdinal):
            return "HDFC XLS account-number evidence is missing on row \(sourceOrdinal)."
        case .malformedAccountNumber(let sourceOrdinal):
            return "HDFC XLS account-number evidence on row \(sourceOrdinal) is malformed."
        case .malformedCustomerIdentifier(let sourceOrdinal):
            return "HDFC XLS customer evidence on row \(sourceOrdinal) is malformed."
        case .malformedRow(let sourceOrdinal):
            return "HDFC XLS transaction row \(sourceOrdinal) is malformed."
        case .malformedDate(let sourceOrdinal):
            return "HDFC XLS transaction row \(sourceOrdinal) contains a malformed date."
        case .malformedValueDate(let sourceOrdinal):
            return "HDFC XLS transaction row \(sourceOrdinal) contains a malformed value date."
        case .malformedMonetaryValue(let sourceOrdinal):
            return "HDFC XLS financial value on row \(sourceOrdinal) is malformed."
        case .missingDirection(let sourceOrdinal):
            return "HDFC XLS transaction row \(sourceOrdinal) has neither amount side populated."
        case .ambiguousDirection(let sourceOrdinal):
            return "HDFC XLS transaction row \(sourceOrdinal) has both amount sides populated."
        case .nonPositiveAmount(let sourceOrdinal):
            return "HDFC XLS transaction row \(sourceOrdinal) has a non-positive amount."
        case .missingBalance(let sourceOrdinal):
            return "HDFC XLS transaction row \(sourceOrdinal) has no closing-balance evidence."
        case .missingSummary:
            return "The HDFC XLS printed statement summary is missing."
        case .malformedSummary(let sourceOrdinal):
            return "HDFC XLS printed summary row \(sourceOrdinal) is malformed."
        case .openingBalanceMismatch(let sourceOrdinal):
            return "HDFC XLS opening balance does not reconcile with row \(sourceOrdinal)."
        case .runningBalanceMismatch(let sourceOrdinal):
            return "HDFC XLS running balance does not reconcile on row \(sourceOrdinal)."
        case .debitCountMismatch:
            return "HDFC XLS debit count does not equal the printed summary."
        case .creditCountMismatch:
            return "HDFC XLS credit count does not equal the printed summary."
        case .debitTotalMismatch:
            return "HDFC XLS debit total does not equal the printed summary."
        case .creditTotalMismatch:
            return "HDFC XLS credit total does not equal the printed summary."
        case .closingBalanceMismatch:
            return "HDFC XLS closing balance does not equal the printed summary."
        }
    }
}

final class HDFCBankAccountXLSParser: StatementParser {
    static let profileID = "hdfc.bank-account.xls"
    static let profileVersion = "1"

    var name: String { "HDFC Bank Account XLS" }

    func canParse(document: Document, metadata: DocumentMetadata) -> Bool {
        metadata.institution == .hdfc
            && metadata.documentType == .bankAccount
            && metadata.fileFormat == .xls
            && document.fileType.caseInsensitiveCompare(FileFormat.xls.rawValue) == .orderedSame
    }

    func parse(document: NormalizedDocument) throws -> FinancialDocument {
        try parse(
            document: document,
            fileFormat: .xls,
            parserProfileID: Self.profileID,
            parserProfileVersion: Self.profileVersion,
            parserName: name
        )
    }

    func parse(
        document: NormalizedDocument,
        fileFormat: FileFormat,
        parserProfileID: String,
        parserProfileVersion: String,
        parserName: String
    ) throws -> FinancialDocument {
        guard document.metadata.institution == .hdfc,
              document.metadata.documentType == .bankAccount,
              document.metadata.fileFormat == fileFormat,
              document.document.fileType.caseInsensitiveCompare(
                  fileFormat.rawValue
              ) == .orderedSame else {
            throw HDFCBankAccountXLSParserError.unsupportedDocumentFormat
        }
        guard let header = document.header else {
            throw HDFCBankAccountXLSParserError.missingHeader
        }
        guard header.values == HDFCBankAccountXLSNormalizer.logicalHeader else {
            throw HDFCBankAccountXLSParserError.changedHeader
        }
        guard !document.rows.isEmpty else {
            throw HDFCBankAccountXLSParserError.noTransactions
        }

        let preamble = try preambleEvidence(
            in: document.sourceContext.preTransactionFragments
        )
        let period = try declaredPeriod(
            preamble.period,
            sourceOrdinal: preamble.periodOrdinal
        )
        guard preamble.currency == "INR" else {
            throw HDFCBankAccountXLSParserError.malformedCurrency(
                sourceOrdinal: preamble.currencyOrdinal
            )
        }
        guard Self.matches(preamble.customerIdentifier, #"^[0-9]{9}$"#) else {
            throw HDFCBankAccountXLSParserError.malformedCustomerIdentifier(
                sourceOrdinal: preamble.customerOrdinal
            )
        }
        guard !preamble.accountNumber.isEmpty else {
            throw HDFCBankAccountXLSParserError.missingAccountNumber(
                sourceOrdinal: preamble.accountOrdinal
            )
        }
        guard Self.matches(preamble.accountNumber, #"^[0-9]{14}$"#) else {
            throw HDFCBankAccountXLSParserError.malformedAccountNumber(
                sourceOrdinal: preamble.accountOrdinal
            )
        }
        let identifier: FinancialIdentifier
        do {
            identifier = try FinancialIdentifier(
                kind: .institutionAccountId,
                rawValue: preamble.accountNumber,
                verificationState: .verified,
                provenance: .institutionStructuredField
            )
        } catch {
            throw HDFCBankAccountXLSParserError.malformedAccountNumber(
                sourceOrdinal: preamble.accountOrdinal
            )
        }

        let summary = try summaryEvidence(
            in: document.sourceContext.postTransactionFragments
        )
        let currency = try CurrencyCode("INR")
        var transactions: [Transaction] = []
        var runningBalance = summary.openingBalance
        var debitCount = 0
        var creditCount = 0
        var debitTotal = Decimal.zero
        var creditTotal = Decimal.zero

        for row in document.rows {
            guard row.values.count == HDFCBankAccountXLSNormalizer.logicalHeader.count else {
                throw HDFCBankAccountXLSParserError.malformedRow(
                    sourceOrdinal: row.rowNumber
                )
            }
            let statementDate: StatementDate
            do {
                statementDate = try date(
                    row.values[0],
                    within: period
                )
            } catch {
                throw HDFCBankAccountXLSParserError.malformedDate(
                    sourceOrdinal: row.rowNumber
                )
            }
            let valueDate: StatementDate
            do {
                valueDate = try date(
                    row.values[3],
                    within: period
                )
            } catch {
                throw HDFCBankAccountXLSParserError.malformedValueDate(
                    sourceOrdinal: row.rowNumber
                )
            }

            let narration = Self.boundedWhitespace(row.values[1])
            guard !narration.isEmpty else {
                throw HDFCBankAccountXLSParserError.malformedRow(
                    sourceOrdinal: row.rowNumber
                )
            }
            let withdrawal = try optionalMoney(
                row.values[4],
                sourceOrdinal: row.rowNumber
            )
            let deposit = try optionalMoney(
                row.values[5],
                sourceOrdinal: row.rowNumber
            )
            guard let closingBalance = try optionalMoney(
                row.values[6],
                sourceOrdinal: row.rowNumber
            ) else {
                throw HDFCBankAccountXLSParserError.missingBalance(
                    sourceOrdinal: row.rowNumber
                )
            }
            switch (withdrawal, deposit) {
            case (nil, nil):
                throw HDFCBankAccountXLSParserError.missingDirection(
                    sourceOrdinal: row.rowNumber
                )
            case (.some, .some):
                throw HDFCBankAccountXLSParserError.ambiguousDirection(
                    sourceOrdinal: row.rowNumber
                )
            default:
                break
            }
            let posted = withdrawal ?? deposit ?? .zero
            guard posted > .zero else {
                throw HDFCBankAccountXLSParserError.nonPositiveAmount(
                    sourceOrdinal: row.rowNumber
                )
            }

            if let withdrawal {
                runningBalance -= withdrawal
                debitCount += 1
                debitTotal += withdrawal
            } else if let deposit {
                runningBalance += deposit
                creditCount += 1
                creditTotal += deposit
            }
            guard runningBalance == closingBalance else {
                if transactions.isEmpty {
                    throw HDFCBankAccountXLSParserError.openingBalanceMismatch(
                        sourceOrdinal: row.rowNumber
                    )
                }
                throw HDFCBankAccountXLSParserError.runningBalanceMismatch(
                    sourceOrdinal: row.rowNumber
                )
            }

            let signedAmount = withdrawal.map { -$0 } ?? deposit ?? .zero
            transactions.append(
                Transaction(
                    statementDate: statementDate,
                    valueDate: valueDate,
                    description: narration,
                    reference: row.values[2].isEmpty ? nil : row.values[2],
                    debitMoney: try withdrawal.map {
                        try Money(amount: $0, currency: currency)
                    },
                    creditMoney: try deposit.map {
                        try Money(amount: $0, currency: currency)
                    },
                    money: try Money(amount: signedAmount, currency: currency),
                    runningBalanceMoney: try Money(
                        amount: closingBalance,
                        currency: currency
                    ),
                    account: document.metadata.institution.rawValue,
                    sourceBank: "HDFC Bank",
                    sourceFile: document.document.filename,
                    financialDateRole: .transactionDate,
                    statementTimezoneEvidence: .iana("Asia/Kolkata"),
                    sourceProvenance: [
                        TransactionSourceProvenance(
                            normalizedDocumentID: document.document.id.uuidString,
                            normalizedRowID: row.id.uuidString,
                            sourceOrdinal: row.rowNumber,
                            normalizedRecordDigest: String.normalizedRecordDigest(
                                values: row.values
                            ),
                            parserProfileID: parserProfileID,
                            parserProfileVersion: parserProfileVersion
                        )
                    ]
                )
            )
        }

        guard debitCount == summary.debitCount else {
            throw HDFCBankAccountXLSParserError.debitCountMismatch
        }
        guard creditCount == summary.creditCount else {
            throw HDFCBankAccountXLSParserError.creditCountMismatch
        }
        guard debitTotal == summary.debitTotal else {
            throw HDFCBankAccountXLSParserError.debitTotalMismatch
        }
        guard creditTotal == summary.creditTotal else {
            throw HDFCBankAccountXLSParserError.creditTotalMismatch
        }
        guard runningBalance == summary.closingBalance,
              transactions.last?.balance == summary.closingBalance,
              summary.openingBalance + summary.creditTotal - summary.debitTotal
                  == summary.closingBalance else {
            throw HDFCBankAccountXLSParserError.closingBalanceMismatch
        }

        return FinancialDocument(
            sourceDocument: document.document,
            metadata: document.metadata,
            parserName: parserName,
            bookedCurrency: currency,
            declaredStatementPeriod: period,
            transactions: transactions,
            financialIdentifiers: [identifier]
        )
    }

    private func preambleEvidence(
        in fragments: [NormalizedDocument.SourceFragment]
    ) throws -> (
        accountOrdinal: Int,
        accountNumber: String,
        customerOrdinal: Int,
        customerIdentifier: String,
        periodOrdinal: Int,
        period: (String, String),
        currencyOrdinal: Int,
        currency: String
    ) {
        guard let account = fragment(sourceOrdinal: 15, in: fragments),
              let customer = fragment(sourceOrdinal: 14, in: fragments),
              let period = fragment(sourceOrdinal: 16, in: fragments),
              let currency = fragment(sourceOrdinal: 13, in: fragments) else {
            throw HDFCBankAccountXLSParserError.missingPreambleEvidence
        }
        let accountValues = Self.values(account)
        let customerValues = Self.values(customer)
        let periodValues = Self.values(period)
        let currencyValues = Self.values(currency)

        guard let accountCaptures = Self.captures(
            accountValues[4],
            #"^Account No\s*:\s*([0-9]*)\s+NR Others$"#
        ) else {
            if accountValues[4].localizedCaseInsensitiveContains("Account No") {
                throw HDFCBankAccountXLSParserError.malformedAccountNumber(
                    sourceOrdinal: account.sourceOrdinal
                )
            }
            throw HDFCBankAccountXLSParserError.missingAccountNumber(
                sourceOrdinal: account.sourceOrdinal
            )
        }
        guard let customerCaptures = Self.captures(
            customerValues[4],
            #"^Cust ID\s*:\s*([0-9]+)$"#
        ) else {
            throw HDFCBankAccountXLSParserError.malformedCustomerIdentifier(
                sourceOrdinal: customer.sourceOrdinal
            )
        }
        guard let periodCaptures = Self.captures(
            periodValues[0],
            #"^Statement From\s*:\s*([0-9]{2}/[0-9]{2}/[0-9]{4})\s+To\s*:\s*([0-9]{2}/[0-9]{2}/[0-9]{4})$"#
        ) else {
            throw HDFCBankAccountXLSParserError.malformedStatementPeriod(
                sourceOrdinal: period.sourceOrdinal
            )
        }
        guard let currencyCaptures = Self.captures(
            currencyValues[4],
            #"^OD Limit\s*:\s*[0-9,.]+\s+Currency\s*:\s*([A-Z]{3})$"#
        ) else {
            throw HDFCBankAccountXLSParserError.malformedCurrency(
                sourceOrdinal: currency.sourceOrdinal
            )
        }
        return (
            account.sourceOrdinal,
            accountCaptures[0],
            customer.sourceOrdinal,
            customerCaptures[0],
            period.sourceOrdinal,
            (periodCaptures[0], periodCaptures[1]),
            currency.sourceOrdinal,
            currencyCaptures[0]
        )
    }

    private func summaryEvidence(
        in fragments: [NormalizedDocument.SourceFragment]
    ) throws -> (
        openingBalance: Decimal,
        debitCount: Int,
        creditCount: Int,
        debitTotal: Decimal,
        creditTotal: Decimal,
        closingBalance: Decimal
    ) {
        let titles = fragments.filter { Self.values($0)[0] == "STATEMENT SUMMARY  :-" }
        guard titles.count == 1, let title = titles.first else {
            throw HDFCBankAccountXLSParserError.missingSummary
        }
        guard let labels = fragment(sourceOrdinal: title.sourceOrdinal + 1, in: fragments),
              let amounts = fragment(sourceOrdinal: title.sourceOrdinal + 2, in: fragments),
              let countLabels = fragment(sourceOrdinal: title.sourceOrdinal + 4, in: fragments),
              let counts = fragment(sourceOrdinal: title.sourceOrdinal + 5, in: fragments),
              Self.values(labels) == [
                  "Opening Balance", "", "", "", "Debits", "Credits", "Closing Bal"
              ],
              Self.values(countLabels) == ["", "", "", "", "Dr Count", "Cr Count", ""] else {
            throw HDFCBankAccountXLSParserError.malformedSummary(
                sourceOrdinal: title.sourceOrdinal
            )
        }
        let amountValues = Self.values(amounts)
        let countValues = Self.values(counts)
        guard let opening = try optionalMoney(
            amountValues[0],
            sourceOrdinal: amounts.sourceOrdinal
        ),
              let debits = try optionalMoney(
                  amountValues[4],
                  sourceOrdinal: amounts.sourceOrdinal
              ),
              let credits = try optionalMoney(
                  amountValues[5],
                  sourceOrdinal: amounts.sourceOrdinal
              ),
              let closing = try optionalMoney(
                  amountValues[6],
                  sourceOrdinal: amounts.sourceOrdinal
              ),
              let debitCount = Int(countValues[4]), debitCount >= 0,
              let creditCount = Int(countValues[5]), creditCount >= 0 else {
            throw HDFCBankAccountXLSParserError.malformedSummary(
                sourceOrdinal: amounts.sourceOrdinal
            )
        }
        return (opening, debitCount, creditCount, debits, credits, closing)
    }

    private func declaredPeriod(
        _ values: (String, String),
        sourceOrdinal: Int
    ) throws -> DeclaredStatementPeriod {
        do {
            return try DeclaredStatementPeriod(
                start: Self.fullDate(values.0),
                end: Self.fullDate(values.1)
            )
        } catch {
            throw HDFCBankAccountXLSParserError.malformedStatementPeriod(
                sourceOrdinal: sourceOrdinal
            )
        }
    }

    private func date(
        _ source: String,
        within period: DeclaredStatementPeriod
    ) throws -> StatementDate {
        let parts = source.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 2,
              parts[1].count == 2,
              parts[2].count == 2,
              let day = Int(parts[0]),
              let month = Int(parts[1]),
              let shortYear = Int(parts[2]) else {
            throw HDFCBankAccountXLSParserError.malformedDate(sourceOrdinal: 0)
        }
        let candidates = (period.start.year...period.end.year).compactMap { year -> StatementDate? in
            guard year % 100 == shortYear else { return nil }
            return try? StatementDate(year: year, month: month, day: day)
        }
        guard candidates.count == 1, let result = candidates.first else {
            throw HDFCBankAccountXLSParserError.malformedDate(sourceOrdinal: 0)
        }
        return result
    }

    private func optionalMoney(_ source: String, sourceOrdinal: Int) throws -> Decimal? {
        guard !source.isEmpty else { return nil }
        guard Self.matches(
            source,
            #"^-?(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)(?:\.[0-9]{1,2})?$"#
        ),
              let value = Decimal(
                  string: source.replacingOccurrences(of: ",", with: ""),
                  locale: Locale(identifier: "en_US_POSIX")
              ) else {
            throw HDFCBankAccountXLSParserError.malformedMonetaryValue(
                sourceOrdinal: sourceOrdinal
            )
        }
        return value
    }

    private func fragment(
        sourceOrdinal: Int,
        in fragments: [NormalizedDocument.SourceFragment]
    ) -> NormalizedDocument.SourceFragment? {
        let matches = fragments.filter { $0.sourceOrdinal == sourceOrdinal }
        return matches.count == 1 ? matches[0] : nil
    }

    private static func values(_ fragment: NormalizedDocument.SourceFragment) -> [String] {
        let values = fragment.text.split(
            separator: "\t",
            omittingEmptySubsequences: false
        ).map(String.init)
        if values.count == logicalColumnCount { return values }
        return Array(repeating: "", count: logicalColumnCount)
    }

    private static let logicalColumnCount = 7

    private static func fullDate(_ source: String) throws -> StatementDate {
        let parts = source.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 2,
              parts[1].count == 2,
              parts[2].count == 4,
              let day = Int(parts[0]),
              let month = Int(parts[1]),
              let year = Int(parts[2]) else {
            throw HDFCBankAccountXLSParserError.malformedStatementPeriod(sourceOrdinal: 0)
        }
        return try StatementDate(year: year, month: month, day: day)
    }

    private static func boundedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func captures(_ value: String, _ pattern: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: value,
                  range: NSRange(value.startIndex..., in: value)
              ),
              match.range == NSRange(value.startIndex..., in: value) else {
            return nil
        }
        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: value) else {
                return nil
            }
            return String(value[range])
        }
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        captures(value, "(\(pattern))") != nil
    }
}
