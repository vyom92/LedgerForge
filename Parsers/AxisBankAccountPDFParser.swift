//
// LedgerForge
// AxisBankAccountPDFParser.swift
// Version: 0.1.0
//

import Foundation

enum AxisBankAccountPDFParserError: Error, Equatable, LocalizedError {
    case unsupportedDocumentFormat
    case missingNormalizedHeader
    case changedNormalizedLayout
    case noTransactions
    case malformedAccountIdentifier(sourceOrdinal: Int)
    case malformedDeclaredPeriod(sourceOrdinal: Int)
    case conflictingTitleEvidence
    case malformedRow(sourceOrdinal: Int)
    case malformedDate(sourceOrdinal: Int)
    case dateOutsideDeclaredPeriod(sourceOrdinal: Int)
    case malformedDecimal(sourceOrdinal: Int)
    case missingOpeningBalance
    case repeatedOpeningBalance(sourceOrdinal: Int)
    case missingPrintedTotals
    case repeatedPrintedTotals(sourceOrdinal: Int)
    case missingClosingBalance
    case repeatedClosingBalance(sourceOrdinal: Int)
    case missingDirection(sourceOrdinal: Int)
    case ambiguousDirection(sourceOrdinal: Int)
    case nonPositiveAmount(sourceOrdinal: Int)
    case missingBalance(sourceOrdinal: Int)
    case missingBranch(sourceOrdinal: Int)
    case impossibleBalanceTransition(sourceOrdinal: Int)
    case sourceDirectionContradictsBalance(sourceOrdinal: Int)
    case printedDebitTotalMismatch
    case printedCreditTotalMismatch
    case closingBalanceMismatch

    var errorDescription: String? {
        switch self {
        case .unsupportedDocumentFormat:
            return "The Axis PDF parser received a non-PDF normalized document."
        case .missingNormalizedHeader:
            return "The Axis PDF normalized header is missing."
        case .changedNormalizedLayout:
            return "The Axis PDF normalized layout is unsupported."
        case .noTransactions:
            return "The Axis PDF parser received no transaction rows."
        case .malformedAccountIdentifier(let sourceOrdinal):
            return "Axis PDF account evidence on source line \(sourceOrdinal) is malformed."
        case .malformedDeclaredPeriod(let sourceOrdinal):
            return "Axis PDF statement-period evidence on source line \(sourceOrdinal) is malformed."
        case .conflictingTitleEvidence:
            return "Axis PDF title, account, or period evidence is duplicated or conflicting."
        case .malformedRow(let sourceOrdinal):
            return "Axis PDF normalized row for source line \(sourceOrdinal) is malformed."
        case .malformedDate(let sourceOrdinal):
            return "Axis PDF transaction on source line \(sourceOrdinal) has a malformed date."
        case .dateOutsideDeclaredPeriod(let sourceOrdinal):
            return "Axis PDF transaction on source line \(sourceOrdinal) is outside the declared period."
        case .malformedDecimal(let sourceOrdinal):
            return "Axis PDF financial value on source line \(sourceOrdinal) is malformed."
        case .missingOpeningBalance:
            return "Axis PDF parser did not receive one opening balance."
        case .repeatedOpeningBalance(let sourceOrdinal):
            return "Axis PDF opening balance is repeated on source line \(sourceOrdinal)."
        case .missingPrintedTotals:
            return "Axis PDF parser did not receive one printed transaction total."
        case .repeatedPrintedTotals(let sourceOrdinal):
            return "Axis PDF printed transaction totals are repeated on source line \(sourceOrdinal)."
        case .missingClosingBalance:
            return "Axis PDF parser did not receive one printed closing balance."
        case .repeatedClosingBalance(let sourceOrdinal):
            return "Axis PDF closing balance is repeated on source line \(sourceOrdinal)."
        case .missingDirection(let sourceOrdinal):
            return "Axis PDF transaction on source line \(sourceOrdinal) has no amount-side evidence."
        case .ambiguousDirection(let sourceOrdinal):
            return "Axis PDF transaction on source line \(sourceOrdinal) has ambiguous amount-side evidence."
        case .nonPositiveAmount(let sourceOrdinal):
            return "Axis PDF transaction on source line \(sourceOrdinal) has a non-positive posted amount."
        case .missingBalance(let sourceOrdinal):
            return "Axis PDF transaction on source line \(sourceOrdinal) has no running balance."
        case .missingBranch(let sourceOrdinal):
            return "Axis PDF transaction on source line \(sourceOrdinal) has no Init. Br evidence."
        case .impossibleBalanceTransition(let sourceOrdinal):
            return "Axis PDF transaction on source line \(sourceOrdinal) matches no exact balance transition."
        case .sourceDirectionContradictsBalance(let sourceOrdinal):
            return "Axis PDF source amount side contradicts the exact balance transition on source line \(sourceOrdinal)."
        case .printedDebitTotalMismatch:
            return "Parsed Axis PDF debits do not equal the printed debit total."
        case .printedCreditTotalMismatch:
            return "Parsed Axis PDF credits do not equal the printed credit total."
        case .closingBalanceMismatch:
            return "The final Axis PDF running balance does not equal the printed closing balance."
        }
    }
}

final class AxisBankAccountPDFParser: StatementParser {

    static let profileID = "axis.bank-account.pdf"
    static let profileVersion = "1"

    var name: String {
        "Axis Bank Account PDF"
    }

    func canParse(
        document: Document,
        metadata: DocumentMetadata
    ) -> Bool {
        metadata.institution == .axis &&
            metadata.documentType == .bankAccount &&
            metadata.fileFormat == .pdf &&
            document.fileType.caseInsensitiveCompare(FileFormat.pdf.rawValue) == .orderedSame
    }

    func parse(
        document: NormalizedDocument
    ) throws -> FinancialDocument {
        guard document.metadata.fileFormat == .pdf,
              document.document.fileType.caseInsensitiveCompare(
                  FileFormat.pdf.rawValue
              ) == .orderedSame else {
            throw AxisBankAccountPDFParserError.unsupportedDocumentFormat
        }
        guard let header = document.header else {
            throw AxisBankAccountPDFParserError.missingNormalizedHeader
        }
        guard header.values == AxisBankAccountPDFColumn.normalizedHeader else {
            throw AxisBankAccountPDFParserError.changedNormalizedLayout
        }
        guard !document.rows.isEmpty else {
            throw AxisBankAccountPDFParserError.noTransactions
        }

        let title = try titleEvidence(
            in: document.sourceContext.preTransactionFragments
        )
        let identifier: FinancialIdentifier
        do {
            identifier = try AxisBankAccountSourceEvidence
                .verifiedAccountIdentifier(title.evidence.accountIdentifier)
        } catch {
            throw AxisBankAccountPDFParserError.malformedAccountIdentifier(
                sourceOrdinal: title.sourceOrdinal
            )
        }
        let period: DeclaredStatementPeriod
        do {
            period = try AxisBankAccountSourceEvidence.declaredStatementPeriod(
                startText: title.evidence.periodStartText,
                endText: title.evidence.periodEndText
            )
        } catch {
            throw AxisBankAccountPDFParserError.malformedDeclaredPeriod(
                sourceOrdinal: title.sourceOrdinal
            )
        }

        let currency = try CurrencyCode("INR")
        let openingBalance = try requiredOpeningBalance(in: document.rows)
        let printed = try requiredPrintedTerminals(in: document.rows)
        var priorBalance = openingBalance
        var debitTotal = Decimal.zero
        var creditTotal = Decimal.zero
        var transactions: [Transaction] = []

        for row in document.rows {
            guard row.values.count == AxisBankAccountPDFColumn.allCases.count else {
                throw AxisBankAccountPDFParserError.malformedRow(
                    sourceOrdinal: row.rowNumber
                )
            }

            let statementDate: StatementDate
            do {
                statementDate = try StatementDate.axisNRE(
                    value(.date, in: row)
                )
            } catch {
                throw AxisBankAccountPDFParserError.malformedDate(
                    sourceOrdinal: row.rowNumber
                )
            }
            guard statementDate >= period.start, statementDate <= period.end else {
                throw AxisBankAccountPDFParserError.dateOutsideDeclaredPeriod(
                    sourceOrdinal: row.rowNumber
                )
            }

            let branch = value(.branchCode, in: row)
            guard !branch.isEmpty,
                  branch.allSatisfy({ $0.isASCII && $0.isNumber }) else {
                throw AxisBankAccountPDFParserError.missingBranch(
                    sourceOrdinal: row.rowNumber
                )
            }
            let particulars = value(.particulars, in: row)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !particulars.isEmpty else {
                throw AxisBankAccountPDFParserError.malformedRow(
                    sourceOrdinal: row.rowNumber
                )
            }

            let sourceDebit = try optionalDecimal(
                value(.sourceDebit, in: row),
                sourceOrdinal: row.rowNumber
            )
            let sourceCredit = try optionalDecimal(
                value(.sourceCredit, in: row),
                sourceOrdinal: row.rowNumber
            )
            let collapsedAmount = try optionalDecimal(
                value(.collapsedAmount, in: row),
                sourceOrdinal: row.rowNumber
            )
            guard let currentBalance = try optionalDecimal(
                value(.balance, in: row),
                sourceOrdinal: row.rowNumber
            ) else {
                throw AxisBankAccountPDFParserError.missingBalance(
                    sourceOrdinal: row.rowNumber
                )
            }

            let resolved = try resolveDirection(
                sourceDebit: sourceDebit,
                sourceCredit: sourceCredit,
                collapsedAmount: collapsedAmount,
                priorBalance: priorBalance,
                currentBalance: currentBalance,
                sourceOrdinal: row.rowNumber
            )
            let amount = resolved.type == .debit
                ? -(resolved.amount)
                : resolved.amount

            if resolved.type == .debit {
                debitTotal += resolved.amount
            } else {
                creditTotal += resolved.amount
            }

            transactions.append(
                Transaction(
                    statementDate: statementDate,
                    description: particulars,
                    debitMoney: try resolved.type == .debit
                        ? Money(amount: resolved.amount, currency: currency)
                        : nil,
                    creditMoney: try resolved.type == .credit
                        ? Money(amount: resolved.amount, currency: currency)
                        : nil,
                    money: try Money(amount: amount, currency: currency),
                    runningBalanceMoney: try Money(
                        amount: currentBalance,
                        currency: currency
                    ),
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
                            narration: particulars,
                            direction: resolved.type
                        )
                )
            )
            priorBalance = currentBalance
        }

        guard debitTotal == printed.debit else {
            throw AxisBankAccountPDFParserError.printedDebitTotalMismatch
        }
        guard creditTotal == printed.credit else {
            throw AxisBankAccountPDFParserError.printedCreditTotalMismatch
        }
        guard priorBalance == printed.closing else {
            throw AxisBankAccountPDFParserError.closingBalanceMismatch
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

    private func titleEvidence(
        in fragments: [NormalizedDocument.SourceFragment]
    ) throws -> (
        sourceOrdinal: Int,
        evidence: AxisBankAccountPDFTitleEvidence
    ) {
        var matches: [
            (
                sourceOrdinal: Int,
                evidence: AxisBankAccountPDFTitleEvidence
            )
        ] = []

        for fragment in fragments {
            do {
                matches.append(
                    (
                        fragment.sourceOrdinal,
                        try AxisBankAccountPDFTitleEvidence.parse(fragment.text)
                    )
                )
            } catch AxisBankAccountPDFTitleEvidenceError.notTitle {
                continue
            } catch AxisBankAccountPDFTitleEvidenceError.malformedAccountIdentifier {
                throw AxisBankAccountPDFParserError.malformedAccountIdentifier(
                    sourceOrdinal: fragment.sourceOrdinal
                )
            } catch AxisBankAccountPDFTitleEvidenceError.malformedDeclaredPeriod {
                throw AxisBankAccountPDFParserError.malformedDeclaredPeriod(
                    sourceOrdinal: fragment.sourceOrdinal
                )
            }
        }

        guard matches.count == 1, let match = matches.first else {
            throw AxisBankAccountPDFParserError.conflictingTitleEvidence
        }
        return match
    }

    private func requiredOpeningBalance(
        in rows: [NormalizedRow]
    ) throws -> Decimal {
        let evidence = try rows.compactMap { row -> (Int, Decimal)? in
            guard let amount = try optionalDecimal(
                value(.openingBalance, in: row),
                sourceOrdinal: row.rowNumber
            ) else {
                return nil
            }
            return (row.rowNumber, amount)
        }
        guard let first = evidence.first else {
            throw AxisBankAccountPDFParserError.missingOpeningBalance
        }
        guard evidence.count == 1, rows.first?.rowNumber == first.0 else {
            throw AxisBankAccountPDFParserError.repeatedOpeningBalance(
                sourceOrdinal: evidence.dropFirst().first?.0 ?? first.0
            )
        }
        return first.1
    }

    private func requiredPrintedTerminals(
        in rows: [NormalizedRow]
    ) throws -> (debit: Decimal, credit: Decimal, closing: Decimal) {
        let totalRows = rows.filter {
            !value(.printedDebitTotal, in: $0).isEmpty ||
                !value(.printedCreditTotal, in: $0).isEmpty
        }
        guard let totalRow = totalRows.first else {
            throw AxisBankAccountPDFParserError.missingPrintedTotals
        }
        guard totalRows.count == 1, totalRow.rowNumber == rows.last?.rowNumber else {
            throw AxisBankAccountPDFParserError.repeatedPrintedTotals(
                sourceOrdinal: totalRows.dropFirst().first?.rowNumber ??
                    totalRow.rowNumber
            )
        }
        guard let debit = try optionalDecimal(
            value(.printedDebitTotal, in: totalRow),
            sourceOrdinal: totalRow.rowNumber
        ), let credit = try optionalDecimal(
            value(.printedCreditTotal, in: totalRow),
            sourceOrdinal: totalRow.rowNumber
        ) else {
            throw AxisBankAccountPDFParserError.missingPrintedTotals
        }

        let closingRows = rows.filter {
            !value(.closingBalance, in: $0).isEmpty
        }
        guard let closingRow = closingRows.first else {
            throw AxisBankAccountPDFParserError.missingClosingBalance
        }
        guard closingRows.count == 1,
              closingRow.rowNumber == rows.last?.rowNumber else {
            throw AxisBankAccountPDFParserError.repeatedClosingBalance(
                sourceOrdinal: closingRows.dropFirst().first?.rowNumber ??
                    closingRow.rowNumber
            )
        }
        guard let closing = try optionalDecimal(
            value(.closingBalance, in: closingRow),
            sourceOrdinal: closingRow.rowNumber
        ) else {
            throw AxisBankAccountPDFParserError.missingClosingBalance
        }

        return (debit, credit, closing)
    }

    private func resolveDirection(
        sourceDebit: Decimal?,
        sourceCredit: Decimal?,
        collapsedAmount: Decimal?,
        priorBalance: Decimal,
        currentBalance: Decimal,
        sourceOrdinal: Int
    ) throws -> (type: TransactionType, amount: Decimal) {
        if sourceDebit != nil && sourceCredit != nil {
            throw AxisBankAccountPDFParserError.ambiguousDirection(
                sourceOrdinal: sourceOrdinal
            )
        }
        if collapsedAmount != nil && (sourceDebit != nil || sourceCredit != nil) {
            throw AxisBankAccountPDFParserError.ambiguousDirection(
                sourceOrdinal: sourceOrdinal
            )
        }

        if let sourceDebit {
            guard sourceDebit > .zero else {
                throw AxisBankAccountPDFParserError.nonPositiveAmount(
                    sourceOrdinal: sourceOrdinal
                )
            }
            guard currentBalance == priorBalance - sourceDebit else {
                throw AxisBankAccountPDFParserError.sourceDirectionContradictsBalance(
                    sourceOrdinal: sourceOrdinal
                )
            }
            return (.debit, sourceDebit)
        }
        if let sourceCredit {
            guard sourceCredit > .zero else {
                throw AxisBankAccountPDFParserError.nonPositiveAmount(
                    sourceOrdinal: sourceOrdinal
                )
            }
            guard currentBalance == priorBalance + sourceCredit else {
                throw AxisBankAccountPDFParserError.sourceDirectionContradictsBalance(
                    sourceOrdinal: sourceOrdinal
                )
            }
            return (.credit, sourceCredit)
        }
        guard let collapsedAmount else {
            throw AxisBankAccountPDFParserError.missingDirection(
                sourceOrdinal: sourceOrdinal
            )
        }
        guard collapsedAmount >= .zero else {
            throw AxisBankAccountPDFParserError.nonPositiveAmount(
                sourceOrdinal: sourceOrdinal
            )
        }

        let matchesDebit = currentBalance == priorBalance - collapsedAmount
        let matchesCredit = currentBalance == priorBalance + collapsedAmount
        switch (matchesDebit, matchesCredit) {
        case (true, false):
            return (.debit, collapsedAmount)
        case (false, true):
            return (.credit, collapsedAmount)
        case (false, false):
            throw AxisBankAccountPDFParserError.impossibleBalanceTransition(
                sourceOrdinal: sourceOrdinal
            )
        case (true, true):
            throw AxisBankAccountPDFParserError.ambiguousDirection(
                sourceOrdinal: sourceOrdinal
            )
        }
    }

    private func optionalDecimal(
        _ source: String,
        sourceOrdinal: Int
    ) throws -> Decimal? {
        guard !source.isEmpty else { return nil }
        guard source.range(
            of: #"^-?(?:[0-9]+)\.[0-9]{2}$"#,
            options: .regularExpression
        ) != nil,
        let value = Decimal(
            string: source,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            throw AxisBankAccountPDFParserError.malformedDecimal(
                sourceOrdinal: sourceOrdinal
            )
        }
        return value
    }

    private func value(
        _ column: AxisBankAccountPDFColumn,
        in row: NormalizedRow
    ) -> String {
        guard row.values.indices.contains(column.rawValue) else {
            return ""
        }
        return row.values[column.rawValue]
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
