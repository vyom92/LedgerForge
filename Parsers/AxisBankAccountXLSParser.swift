import Foundation

enum AxisBankAccountXLSParserError: Error, Equatable, LocalizedError {
    case unsupportedDocumentFormat
    case missingHeader
    case changedHeader
    case noTransactions
    case missingTitleEvidence
    case conflictingTitleEvidence
    case malformedTitleEvidence(sourceOrdinal: Int)
    case malformedRow(sourceOrdinal: Int)
    case malformedDate(sourceOrdinal: Int)
    case dateOutsideDeclaredPeriod(sourceOrdinal: Int)
    case malformedMonetaryValue(sourceOrdinal: Int)
    case missingDirection(sourceOrdinal: Int)
    case ambiguousDirection(sourceOrdinal: Int)
    case missingBalance(sourceOrdinal: Int)
    case missingBranch(sourceOrdinal: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocumentFormat:
            return "The Axis XLS parser received a non-XLS normalized document."
        case .missingHeader:
            return "The Axis XLS normalized header is missing."
        case .changedHeader:
            return "The Axis XLS normalized header does not match the approved layout."
        case .noTransactions:
            return "The Axis XLS parser received no transaction rows."
        case .missingTitleEvidence:
            return "The Axis XLS account and statement-period evidence is missing."
        case .conflictingTitleEvidence:
            return "The Axis XLS account or statement-period evidence is duplicated."
        case .malformedTitleEvidence(let sourceOrdinal):
            return "Axis XLS title evidence on source row \(sourceOrdinal) is malformed."
        case .malformedRow(let sourceOrdinal):
            return "Axis XLS transaction row \(sourceOrdinal) is malformed."
        case .malformedDate(let sourceOrdinal):
            return "Axis XLS transaction row \(sourceOrdinal) contains an invalid date."
        case .dateOutsideDeclaredPeriod(let sourceOrdinal):
            return "Axis XLS transaction row \(sourceOrdinal) is outside the declared period."
        case .malformedMonetaryValue(let sourceOrdinal):
            return "Axis XLS transaction row \(sourceOrdinal) contains an invalid monetary value."
        case .missingDirection(let sourceOrdinal):
            return "Axis XLS transaction row \(sourceOrdinal) has no debit or credit evidence."
        case .ambiguousDirection(let sourceOrdinal):
            return "Axis XLS transaction row \(sourceOrdinal) has both debit and credit evidence."
        case .missingBalance(let sourceOrdinal):
            return "Axis XLS transaction row \(sourceOrdinal) has no running balance."
        case .missingBranch(let sourceOrdinal):
            return "Axis XLS transaction row \(sourceOrdinal) has no SOL evidence."
        }
    }
}

final class AxisBankAccountXLSParser: StatementParser {
    static let profileID = "axis.bank-account.xls"
    static let profileVersion = "1"

    var name: String { "Axis Bank Account XLS" }

    func canParse(document: Document, metadata: DocumentMetadata) -> Bool {
        metadata.institution == .axis
            && metadata.documentType == .bankAccount
            && metadata.fileFormat == .xls
            && document.fileType.caseInsensitiveCompare(FileFormat.xls.rawValue) == .orderedSame
    }

    func parse(document: NormalizedDocument) throws -> FinancialDocument {
        guard document.metadata.fileFormat == .xls,
              document.document.fileType.caseInsensitiveCompare(
                FileFormat.xls.rawValue
              ) == .orderedSame else {
            throw AxisBankAccountXLSParserError.unsupportedDocumentFormat
        }
        guard let header = document.header else {
            throw AxisBankAccountXLSParserError.missingHeader
        }
        guard header.values == AxisBankAccountXLSNormalizer.logicalHeader else {
            throw AxisBankAccountXLSParserError.changedHeader
        }
        guard !document.rows.isEmpty else {
            throw AxisBankAccountXLSParserError.noTransactions
        }

        let title = try titleEvidence(in: document.sourceContext.preTransactionFragments)
        let identifier: FinancialIdentifier
        let period: DeclaredStatementPeriod
        do {
            identifier = try AxisBankAccountSourceEvidence.verifiedAccountIdentifier(
                title.accountIdentifier
            )
            period = try AxisBankAccountSourceEvidence.declaredStatementPeriod(
                startText: title.startDate,
                endText: title.endDate
            )
        } catch {
            throw AxisBankAccountXLSParserError.malformedTitleEvidence(
                sourceOrdinal: title.sourceOrdinal
            )
        }

        let currency = try CurrencyCode("INR")
        var transactions: [Transaction] = []
        transactions.reserveCapacity(document.rows.count)
        for row in document.rows {
            guard row.values.count == 7 else {
                throw AxisBankAccountXLSParserError.malformedRow(
                    sourceOrdinal: row.rowNumber
                )
            }
            let statementDate: StatementDate
            do {
                statementDate = try StatementDate.axisNRE(row.values[0])
            } catch {
                throw AxisBankAccountXLSParserError.malformedDate(
                    sourceOrdinal: row.rowNumber
                )
            }
            guard statementDate >= period.start, statementDate <= period.end else {
                throw AxisBankAccountXLSParserError.dateOutsideDeclaredPeriod(
                    sourceOrdinal: row.rowNumber
                )
            }
            let description = row.values[2]
            guard !description.isEmpty else {
                throw AxisBankAccountXLSParserError.malformedRow(
                    sourceOrdinal: row.rowNumber
                )
            }
            let sourceDebit = try decimal(row.values[3], sourceOrdinal: row.rowNumber)
            let sourceCredit = try decimal(row.values[4], sourceOrdinal: row.rowNumber)
            guard let balance = try decimal(row.values[5], sourceOrdinal: row.rowNumber) else {
                throw AxisBankAccountXLSParserError.missingBalance(
                    sourceOrdinal: row.rowNumber
                )
            }
            let branch = row.values[6]
            guard !branch.isEmpty,
                  branch.allSatisfy({ $0.isASCII && $0.isNumber }) else {
                throw AxisBankAccountXLSParserError.missingBranch(
                    sourceOrdinal: row.rowNumber
                )
            }

            let direction: DirectionResult
            do {
                direction = try AxisBankAccountCSVProfileV2.resolve(
                    sourceDR: sourceDebit,
                    sourceCR: sourceCredit
                )
            } catch DirectionResolutionError.missingDebitAndCredit {
                throw AxisBankAccountXLSParserError.missingDirection(
                    sourceOrdinal: row.rowNumber
                )
            } catch DirectionResolutionError.populatedDebitAndCredit {
                throw AxisBankAccountXLSParserError.ambiguousDirection(
                    sourceOrdinal: row.rowNumber
                )
            }

            let postedAmount = direction.transactionType == .debit
                ? -(direction.debit ?? 0)
                : direction.credit ?? 0
            transactions.append(
                Transaction(
                    statementDate: statementDate,
                    description: description,
                    debitMoney: try direction.debit.map {
                        try Money(amount: $0, currency: currency)
                    },
                    creditMoney: try direction.credit.map {
                        try Money(amount: $0, currency: currency)
                    },
                    money: try Money(amount: postedAmount, currency: currency),
                    runningBalanceMoney: try Money(amount: balance, currency: currency),
                    account: document.metadata.institution.rawValue,
                    sourceBank: "Axis Bank",
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
                            parserProfileID: Self.profileID,
                            parserProfileVersion: Self.profileVersion
                        )
                    ],
                    verifiedAxisUPIEventEvidence:
                        AxisBankAccountSourceEvidence.transactionEventEvidence(
                            narration: description,
                            direction: direction.transactionType
                        )
                )
            )
        }

        return FinancialDocument(
            sourceDocument: document.document,
            metadata: document.metadata,
            parserName: name,
            bookedCurrency: currency,
            declaredStatementPeriod: period,
            transactions: transactions,
            financialIdentifiers: [identifier]
        )
    }

    private func decimal(_ text: String, sourceOrdinal: Int) throws -> Decimal? {
        guard !text.isEmpty else { return nil }
        guard let value = Decimal(
            string: text,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            throw AxisBankAccountXLSParserError.malformedMonetaryValue(
                sourceOrdinal: sourceOrdinal
            )
        }
        return value
    }

    private func titleEvidence(
        in fragments: [NormalizedDocument.SourceFragment]
    ) throws -> (
        sourceOrdinal: Int,
        accountIdentifier: String,
        startDate: String,
        endDate: String
    ) {
        let pattern = #"^.+\s-\s([0-9]{15})\s+.+\(\S+\s*:\s*(\d{2}-\d{2}-\d{4})\s+\S+\s*:\s*(\d{2}-\d{2}-\d{4})\)\s*$"#
        let matches = fragments.compactMap { fragment -> (Int, [String])? in
            guard let captures = captures(in: fragment.text, pattern: pattern) else {
                return nil
            }
            return (fragment.sourceOrdinal, captures)
        }
        guard !matches.isEmpty else {
            throw AxisBankAccountXLSParserError.missingTitleEvidence
        }
        guard matches.count == 1, let match = matches.first else {
            throw AxisBankAccountXLSParserError.conflictingTitleEvidence
        }
        guard match.1.count == 3 else {
            throw AxisBankAccountXLSParserError.malformedTitleEvidence(
                sourceOrdinal: match.0
            )
        }
        return (match.0, match.1[0], match.1[1], match.1[2])
    }

    private func captures(in text: String, pattern: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              match.range == NSRange(text.startIndex..., in: text) else {
            return nil
        }
        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }
}
