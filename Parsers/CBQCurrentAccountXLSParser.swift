import Foundation

enum CBQCurrentAccountXLSParserError: Error, Equatable, LocalizedError {
    case unsupportedDocumentFormat
    case missingHeader
    case changedHeader
    case noTransactions
    case missingAccountNumber(sourceOrdinal: Int)
    case malformedAccountNumber(sourceOrdinal: Int)
    case malformedProductEvidence(sourceOrdinal: Int)
    case malformedRow(sourceOrdinal: Int)
    case malformedDate(sourceOrdinal: Int)
    case ascendingDateOrder(sourceOrdinal: Int)
    case malformedMonetaryValue(sourceOrdinal: Int)
    case zeroAmount(sourceOrdinal: Int)
    case missingBalance(sourceOrdinal: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocumentFormat:
            return "The CBQ current-account XLS parser received an unsupported document."
        case .missingHeader:
            return "The CBQ current-account XLS normalized header is missing."
        case .changedHeader:
            return "The CBQ current-account XLS normalized header does not match the retained layout."
        case .noTransactions:
            return "The CBQ current-account XLS parser received no transaction rows."
        case .missingAccountNumber(let sourceOrdinal):
            return "CBQ current-account XLS account-number evidence is missing on row \(sourceOrdinal)."
        case .malformedAccountNumber(let sourceOrdinal):
            return "CBQ current-account XLS account-number evidence on row \(sourceOrdinal) is malformed."
        case .malformedProductEvidence(let sourceOrdinal):
            return "CBQ current-account XLS product evidence on row \(sourceOrdinal) is malformed."
        case .malformedRow(let sourceOrdinal):
            return "CBQ current-account XLS transaction row \(sourceOrdinal) is malformed."
        case .malformedDate(let sourceOrdinal):
            return "CBQ current-account XLS transaction row \(sourceOrdinal) contains a malformed date."
        case .ascendingDateOrder(let sourceOrdinal):
            return "CBQ current-account XLS transaction row \(sourceOrdinal) violates descending source-date order."
        case .malformedMonetaryValue(let sourceOrdinal):
            return "CBQ current-account XLS financial value on row \(sourceOrdinal) is malformed."
        case .zeroAmount(let sourceOrdinal):
            return "CBQ current-account XLS transaction row \(sourceOrdinal) contains an unsupported zero amount."
        case .missingBalance(let sourceOrdinal):
            return "CBQ current-account XLS transaction row \(sourceOrdinal) has no printed balance."
        }
    }
}

final class CBQCurrentAccountXLSParser: StatementParser {
    static let profileID = "cbq.current-account.xls"
    static let profileVersion = "1"

    var name: String { "CBQ Current Account XLS" }

    func canParse(document: Document, metadata: DocumentMetadata) -> Bool {
        metadata.institution == .cbq
            && metadata.documentType == .bankAccount
            && metadata.fileFormat == .xls
            && document.fileType.caseInsensitiveCompare(FileFormat.xls.rawValue) == .orderedSame
    }

    func parse(document: NormalizedDocument) throws -> FinancialDocument {
        guard document.metadata.institution == .cbq,
              document.metadata.documentType == .bankAccount,
              document.metadata.fileFormat == .xls,
              document.document.fileType.caseInsensitiveCompare(
                  FileFormat.xls.rawValue
              ) == .orderedSame else {
            throw CBQCurrentAccountXLSParserError.unsupportedDocumentFormat
        }
        guard let header = document.header else {
            throw CBQCurrentAccountXLSParserError.missingHeader
        }
        guard header.values == CBQCurrentAccountXLSNormalizer.logicalHeader else {
            throw CBQCurrentAccountXLSParserError.changedHeader
        }
        guard !document.rows.isEmpty else {
            throw CBQCurrentAccountXLSParserError.noTransactions
        }

        let accountNumber = try accountEvidence(
            in: document.sourceContext.preTransactionFragments
        )
        let identifier: FinancialIdentifier
        do {
            identifier = try FinancialIdentifier(
                kind: .institutionAccountId,
                rawValue: accountNumber,
                verificationState: .verified,
                provenance: .institutionStructuredField
            )
        } catch {
            throw CBQCurrentAccountXLSParserError.malformedAccountNumber(sourceOrdinal: 4)
        }

        let currency = try CurrencyCode("QAR")
        var transactions: [Transaction] = []
        transactions.reserveCapacity(document.rows.count)
        var previousDate: StatementDate?

        for row in document.rows {
            guard row.values.count == CBQCurrentAccountXLSNormalizer.logicalHeader.count,
                  row.values[3...5].allSatisfy({ $0.isEmpty }),
                  !row.values[1].isEmpty else {
                throw CBQCurrentAccountXLSParserError.malformedRow(
                    sourceOrdinal: row.rowNumber
                )
            }
            let statementDate: StatementDate
            do {
                statementDate = try Self.date(row.values[0])
            } catch {
                throw CBQCurrentAccountXLSParserError.malformedDate(
                    sourceOrdinal: row.rowNumber
                )
            }
            if let previousDate, statementDate > previousDate {
                throw CBQCurrentAccountXLSParserError.ascendingDateOrder(
                    sourceOrdinal: row.rowNumber
                )
            }
            previousDate = statementDate

            let signedAmount = try decimal(
                row.values[2],
                sourceOrdinal: row.rowNumber
            )
            guard signedAmount != .zero else {
                throw CBQCurrentAccountXLSParserError.zeroAmount(
                    sourceOrdinal: row.rowNumber
                )
            }
            guard !row.values[6].isEmpty else {
                throw CBQCurrentAccountXLSParserError.missingBalance(
                    sourceOrdinal: row.rowNumber
                )
            }
            let balance = try decimal(
                row.values[6],
                sourceOrdinal: row.rowNumber
            )
            let debit = signedAmount < .zero ? -signedAmount : nil
            let credit = signedAmount > .zero ? signedAmount : nil

            do {
                transactions.append(
                    Transaction(
                        statementDate: statementDate,
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
                        sourceProvenance: [
                            TransactionSourceProvenance(
                                normalizedDocumentID: document.document.id.uuidString,
                                normalizedRowID: row.id.uuidString,
                                sourceOrdinal: row.rowNumber,
                                normalizedRecordDigest: String.normalizedRecordDigest(
                                    values: row.values
                                ),
                                parserProfileID: Self.profileID,
                                parserProfileVersion: Self.profileVersion
                            )
                        ]
                    )
                )
            } catch {
                throw CBQCurrentAccountXLSParserError.malformedMonetaryValue(
                    sourceOrdinal: row.rowNumber
                )
            }
        }

        return FinancialDocument(
            sourceDocument: document.document,
            metadata: document.metadata,
            parserName: name,
            bookedCurrency: currency,
            declaredStatementPeriod: nil,
            transactions: transactions,
            financialIdentifiers: [identifier],
            sourceStatementEvidence: SourceStatementEvidence(
                sourceFormatCode: "history-xls",
                statementBoundaryDate: nil,
                period: nil,
                openingBalance: nil,
                closingBalance: nil
            )
        )
    }

    private func accountEvidence(
        in fragments: [NormalizedDocument.SourceFragment]
    ) throws -> String {
        guard let account = fragments.first(where: { $0.sourceOrdinal == 4 }) else {
            throw CBQCurrentAccountXLSParserError.missingAccountNumber(sourceOrdinal: 4)
        }
        let value = account.text
            .split(separator: "\t", omittingEmptySubsequences: false)
            .first.map(String.init) ?? ""
        guard !value.isEmpty else {
            throw CBQCurrentAccountXLSParserError.missingAccountNumber(sourceOrdinal: 4)
        }
        guard Self.matches(value, #"^[0-9]{13}$"#) else {
            throw CBQCurrentAccountXLSParserError.malformedAccountNumber(sourceOrdinal: 4)
        }
        guard let product = fragments.first(where: { $0.sourceOrdinal == 5 }) else {
            throw CBQCurrentAccountXLSParserError.malformedProductEvidence(sourceOrdinal: 5)
        }
        let productValue = product.text
            .split(separator: "\t", omittingEmptySubsequences: false)
            .first.map { Self.boundedWhitespace(String($0)) } ?? ""
        guard Self.matches(productValue, #"^CURRENT ACCOUNT-RETAIL\s+\S.*$"#) else {
            throw CBQCurrentAccountXLSParserError.malformedProductEvidence(sourceOrdinal: 5)
        }
        return value
    }

    private func decimal(_ text: String, sourceOrdinal: Int) throws -> Decimal {
        guard let value = Decimal(
            string: text,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            throw CBQCurrentAccountXLSParserError.malformedMonetaryValue(
                sourceOrdinal: sourceOrdinal
            )
        }
        return value
    }

    private static func date(_ source: String) throws -> StatementDate {
        let parts = source.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 2,
              parts[1].count == 2,
              parts[2].count == 4,
              let day = Int(parts[0]),
              let month = Int(parts[1]),
              let year = Int(parts[2]) else {
            throw CBQCurrentAccountXLSParserError.malformedDate(sourceOrdinal: 0)
        }
        return try StatementDate(year: year, month: month, day: day)
    }

    private static func boundedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) == value.startIndex..<value.endIndex
    }
}
