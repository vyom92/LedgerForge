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
                            sourcePage: row.sourcePage,
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
        let terminalBalanceMatches = transactions.last.map {
            $0.balance == summary.closingBalance
        } ?? (summary.openingBalance == summary.closingBalance)
        guard runningBalance == summary.closingBalance,
              terminalBalanceMatches,
              summary.openingBalance + summary.creditTotal - summary.debitTotal
                  == summary.closingBalance else {
            throw HDFCBankAccountXLSParserError.closingBalanceMismatch
        }

        let openingMoney = try Money(amount: summary.openingBalance, currency: currency)
        let closingMoney = try Money(amount: summary.closingBalance, currency: currency)
        // Empty rows alone are not evidence of a zero-activity statement. The
        // complete printed summary has already reconciled counts, movement
        // totals, and opening/closing balances above.
        let zeroEvidence = transactions.isEmpty
            ? try ZeroActivityStatementEvidence(
                profileID: parserProfileID,
                profileVersion: parserProfileVersion,
                sourceFormatCode: fileFormat.rawValue,
                evidenceKind: .printedControls,
                statementDate: period.end,
                statementPeriod: period,
                nativeCurrency: currency,
                openingBalance: openingMoney,
                closingBalance: closingMoney,
                debitTotal: try Money(amount: summary.debitTotal, currency: currency),
                creditTotal: try Money(amount: summary.creditTotal, currency: currency)
            )
            : nil
        return FinancialDocument(
            sourceDocument: document.document,
            metadata: document.metadata,
            parserName: parserName,
            parserProfileID: parserProfileID,
            parserProfileVersion: parserProfileVersion,
            bookedCurrency: currency,
            declaredStatementPeriod: period,
            transactions: transactions,
            financialIdentifiers: [identifier],
            sourceStatementEvidence: SourceStatementEvidence(
                sourceFormatCode: fileFormat.rawValue,
                statementBoundaryDate: period.end,
                period: period,
                openingBalance: openingMoney,
                closingBalance: closingMoney
            ),
            zeroActivityEvidence: zeroEvidence
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
        let accountMatches = Self.fragmentCaptures(
            #"Account\s+No\s*:\s*([0-9]{14})(?:\s+NR\s+Others)?"#,
            in: fragments
        )
        guard let account = Self.uniqueFragmentCapture(accountMatches) else {
            let candidate = fragments.first {
                Self.sourceText($0).localizedCaseInsensitiveContains("Account No")
            }
            if let candidate {
                throw HDFCBankAccountXLSParserError.malformedAccountNumber(
                    sourceOrdinal: candidate.sourceOrdinal
                )
            }
            throw HDFCBankAccountXLSParserError.missingAccountNumber(
                sourceOrdinal: fragments.first?.sourceOrdinal ?? 0
            )
        }
        let customerMatches = Self.fragmentCaptures(
            #"\bCust\s+ID\s*:\s*([0-9]{9})\b"#,
            in: fragments
        )
        guard let customer = Self.uniqueFragmentCapture(customerMatches) else {
            throw HDFCBankAccountXLSParserError.malformedCustomerIdentifier(
                sourceOrdinal: customerMatches.first?.ordinal ?? fragments.first?.sourceOrdinal ?? 0
            )
        }
        let periodMatches = Self.fragmentCaptures(
            #"\b(?:Statement(?:\s+of\s+accounts?)?\s+)?From\s*:\s*([0-9]{2}/[0-9]{2}/[0-9]{4})\s+To\s*:\s*([0-9]{2}/[0-9]{2}/[0-9]{4})\b"#,
            in: fragments
        )
        guard let period = Self.uniqueFragmentCapture(periodMatches) else {
            throw HDFCBankAccountXLSParserError.malformedStatementPeriod(
                sourceOrdinal: periodMatches.first?.ordinal ?? fragments.first?.sourceOrdinal ?? 0
            )
        }
        let currencyMatches = Self.fragmentCaptures(
            #"\bCurrency\s*:\s*([A-Z]{3})\b"#,
            in: fragments
        )
        guard let currency = Self.uniqueFragmentCapture(currencyMatches) else {
            throw HDFCBankAccountXLSParserError.malformedCurrency(
                sourceOrdinal: currencyMatches.first?.ordinal ?? fragments.first?.sourceOrdinal ?? 0
            )
        }
        return (
            account.ordinal,
            account.values[0],
            customer.ordinal,
            customer.values[0],
            period.ordinal,
            (period.values[0], period.values[1]),
            currency.ordinal,
            currency.values[0]
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
        let titles = fragments.filter {
            Self.semanticKey(Self.sourceText($0)).contains("statementsummary")
        }
        guard titles.count == 1, let title = titles.first else {
            throw HDFCBankAccountXLSParserError.missingSummary
        }
        let eligible = fragments.filter { $0.sourceOrdinal >= title.sourceOrdinal }
        let labelEvidence = Self.boundedWhitespace(
            eligible.map { Self.sourceText($0) }.joined(separator: " ")
        )
        guard labelEvidence.localizedCaseInsensitiveContains("Opening Balance"),
              labelEvidence.localizedCaseInsensitiveContains("Debits"),
              labelEvidence.localizedCaseInsensitiveContains("Credits"),
              labelEvidence.localizedCaseInsensitiveContains("Closing Bal"),
              labelEvidence.localizedCaseInsensitiveContains("Dr Count"),
              labelEvidence.localizedCaseInsensitiveContains("Cr Count") else {
            throw HDFCBankAccountXLSParserError.malformedSummary(
                sourceOrdinal: title.sourceOrdinal
            )
        }

        var structuredAmounts: [(ordinal: Int, values: (Decimal, Decimal, Decimal, Decimal))] = []
        var structuredCounts: [(ordinal: Int, values: (Int, Int))] = []
        var compactValues: [(ordinal: Int, values: (Decimal, Int, Int, Decimal, Decimal, Decimal))] = []
        for fragment in eligible {
            if let cells = Self.structuredValues(fragment) {
                if Self.matches(cells[0], Self.moneyPattern),
                   Self.matches(cells[4], Self.moneyPattern),
                   Self.matches(cells[5], Self.moneyPattern),
                   Self.matches(cells[6], Self.moneyPattern),
                   let opening = try optionalMoney(cells[0], sourceOrdinal: fragment.sourceOrdinal),
                   let debits = try optionalMoney(cells[4], sourceOrdinal: fragment.sourceOrdinal),
                   let credits = try optionalMoney(cells[5], sourceOrdinal: fragment.sourceOrdinal),
                   let closing = try optionalMoney(cells[6], sourceOrdinal: fragment.sourceOrdinal) {
                    structuredAmounts.append((fragment.sourceOrdinal, (opening, debits, credits, closing)))
                }
                if let debitCount = Int(cells[4]), debitCount >= 0,
                   let creditCount = Int(cells[5]), creditCount >= 0,
                   cells[0].isEmpty, cells[6].isEmpty {
                    structuredCounts.append((fragment.sourceOrdinal, (debitCount, creditCount)))
                }
            }
            let tokens = Self.sourceText(fragment)
                .split(whereSeparator: { $0.isWhitespace })
                .map(String.init)
            if tokens.count == 6,
               Self.matches(tokens[0], Self.moneyPattern),
               Self.matches(tokens[3], Self.moneyPattern),
               Self.matches(tokens[4], Self.moneyPattern),
               Self.matches(tokens[5], Self.moneyPattern),
               let opening = try optionalMoney(tokens[0], sourceOrdinal: fragment.sourceOrdinal),
               let debitCount = Int(tokens[1]), debitCount >= 0,
               let creditCount = Int(tokens[2]), creditCount >= 0,
               let debits = try optionalMoney(tokens[3], sourceOrdinal: fragment.sourceOrdinal),
               let credits = try optionalMoney(tokens[4], sourceOrdinal: fragment.sourceOrdinal),
               let closing = try optionalMoney(tokens[5], sourceOrdinal: fragment.sourceOrdinal) {
                compactValues.append((fragment.sourceOrdinal, (opening, debitCount, creditCount, debits, credits, closing)))
            }
        }
        if compactValues.count == 1, let compact = compactValues.first {
            return compact.values
        }
        guard structuredAmounts.count == 1, let amounts = structuredAmounts.first,
              structuredCounts.count == 1, let counts = structuredCounts.first else {
            throw HDFCBankAccountXLSParserError.malformedSummary(
                sourceOrdinal: title.sourceOrdinal
            )
        }
        return (
            amounts.values.0,
            counts.values.0,
            counts.values.1,
            amounts.values.1,
            amounts.values.2,
            amounts.values.3
        )
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

    private static func fragmentCaptures(
        _ pattern: String,
        in fragments: [NormalizedDocument.SourceFragment]
    ) -> [(ordinal: Int, values: [String])] {
        fragments.compactMap { fragment in
            guard let values = substringCaptures(sourceText(fragment), pattern) else { return nil }
            return (fragment.sourceOrdinal, values)
        }
    }

    private static func uniqueFragmentCapture(
        _ matches: [(ordinal: Int, values: [String])]
    ) -> (ordinal: Int, values: [String])? {
        guard let first = matches.first,
              matches.allSatisfy({ $0.values == first.values }) else { return nil }
        return first
    }

    private static func sourceText(_ fragment: NormalizedDocument.SourceFragment) -> String {
        boundedWhitespace(fragment.text.replacingOccurrences(of: "\t", with: " "))
    }

    private static func structuredValues(
        _ fragment: NormalizedDocument.SourceFragment
    ) -> [String]? {
        let values = fragment.text.split(
            separator: "\t",
            omittingEmptySubsequences: false
        ).map(String.init)
        return values.count == logicalColumnCount ? values : nil
    }

    private static func values(_ fragment: NormalizedDocument.SourceFragment) -> [String] {
        structuredValues(fragment) ?? Array(repeating: "", count: logicalColumnCount)
    }

    private static let logicalColumnCount = 7
    private static let moneyPattern = #"^-?(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)(?:\.[0-9]{1,2})?$"#

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

    private static func semanticKey(_ value: String) -> String {
        boundedWhitespace(value)
            .precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func captures(_ value: String, _ pattern: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
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

    private static func substringCaptures(_ value: String, _ pattern: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(
                  in: value,
                  range: NSRange(value.startIndex..., in: value)
              ) else {
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
