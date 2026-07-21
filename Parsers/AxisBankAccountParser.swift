//
// LedgerForge
// AxisBankAccountParser.swift
// Version: 0.2.0
//

import Foundation

enum AxisBankCSVColumnRole: String, CaseIterable, Hashable {
    case date
    case chequeReference
    case description
    case debit
    case credit
    case balance
    case sol
}

enum AxisBankCSVColumnMappingError: Error, Equatable, LocalizedError {
    case missingRole(AxisBankCSVColumnRole)
    case duplicateRole(AxisBankCSVColumnRole)
    case ambiguousHeader(index: Int)
    case unsupportedHeader(index: Int)

    var errorDescription: String? {
        switch self {
        case .missingRole(let role):
            return "The supported Axis CSV layout is missing the required \(role.rawValue) column."
        case .duplicateRole(let role):
            return "The supported Axis CSV layout contains more than one \(role.rawValue) column."
        case .ambiguousHeader(let index):
            return "Axis CSV header column \(index + 1) is ambiguous."
        case .unsupportedHeader(let index):
            return "Axis CSV header column \(index + 1) is not part of the supported layout."
        }
    }
}

struct AxisBankCSVColumnMapping {
    let date: Int
    let chequeReference: Int
    let description: Int
    let debit: Int
    let credit: Int
    let balance: Int
    let sol: Int

    var maximumIndex: Int {
        [date, chequeReference, description, debit, credit, balance, sol].max()!
    }

    static func resolve(
        headerCells: [String]
    ) throws -> AxisBankCSVColumnMapping {
        var indices: [AxisBankCSVColumnRole: Int] = [:]

        for (index, cell) in headerCells.enumerated() {
            let normalized = normalize(cell)
            guard let roles = aliases[normalized] else {
                throw AxisBankCSVColumnMappingError.unsupportedHeader(index: index)
            }
            guard roles.count == 1, let role = roles.first else {
                throw AxisBankCSVColumnMappingError.ambiguousHeader(index: index)
            }
            guard indices[role] == nil else {
                throw AxisBankCSVColumnMappingError.duplicateRole(role)
            }
            indices[role] = index
        }

        for role in AxisBankCSVColumnRole.allCases where indices[role] == nil {
            throw AxisBankCSVColumnMappingError.missingRole(role)
        }

        return AxisBankCSVColumnMapping(
            date: indices[.date]!,
            chequeReference: indices[.chequeReference]!,
            description: indices[.description]!,
            debit: indices[.debit]!,
            credit: indices[.credit]!,
            balance: indices[.balance]!,
            sol: indices[.sol]!
        )
    }

    private static func normalize(_ value: String) -> String {
        value
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private static let aliases: [String: Set<AxisBankCSVColumnRole>] = [
        "tran date": [.date],
        "transaction date": [.date],
        "chqno": [.chequeReference],
        "particulars": [.description],
        "dr": [.debit],
        "debit": [.debit],
        "cr": [.credit],
        "credit": [.credit],
        "bal": [.balance],
        "balance": [.balance],
        "sol": [.sol],
        "dr/cr": [.debit, .credit],
        "debit/credit": [.debit, .credit]
    ]
}

enum AxisBankAccountParserError: Error, Equatable, LocalizedError {
    case missingHeader
    case malformedTransactionRow(rowNumber: Int)
    case invalidDate(rowNumber: Int)
    case invalidMonetaryValue(role: AxisBankCSVColumnRole, rowNumber: Int)
    case missingDirection(rowNumber: Int)
    case ambiguousDirection(rowNumber: Int)
    case malformedAccountIdentifierEvidence(sourceOrdinal: Int)
    case invalidAccountIdentifier(sourceOrdinal: Int)
    case conflictingAccountIdentifiers

    var errorDescription: String? {
        switch self {
        case .missingHeader:
            return "The supported Axis CSV header is missing."
        case .malformedTransactionRow(let rowNumber):
            return "Axis CSV transaction row \(rowNumber) does not match the resolved layout."
        case .invalidDate(let rowNumber):
            return "Axis CSV transaction row \(rowNumber) contains an invalid date."
        case .invalidMonetaryValue(let role, let rowNumber):
            return "Axis CSV transaction row \(rowNumber) contains an invalid \(role.rawValue) value."
        case .missingDirection(let rowNumber):
            return "Axis CSV transaction row \(rowNumber) contains neither debit nor credit evidence."
        case .ambiguousDirection(let rowNumber):
            return "Axis CSV transaction row \(rowNumber) contains both debit and credit evidence."
        case .malformedAccountIdentifierEvidence(let sourceOrdinal):
            return "Axis account identifier evidence on source row \(sourceOrdinal) is malformed."
        case .invalidAccountIdentifier(let sourceOrdinal):
            return "Axis account identifier evidence on source row \(sourceOrdinal) cannot form a verified identifier."
        case .conflictingAccountIdentifiers:
            return "Axis account identifier evidence contains conflicting recognized values."
        }
    }
}

final class AxisBankAccountParser: StatementParser {

    var name: String {
        "Axis Bank Account"
    }

    func canParse(
        document: Document,
        metadata: DocumentMetadata
    ) -> Bool {

        return metadata.institution == .axis &&
               metadata.documentType == .bankAccount
    }

    func parse(
        document: NormalizedDocument
    ) throws -> FinancialDocument {

        let currency = try CurrencyCode("INR")

        let financialIdentifiers = try Self.financialIdentifiers(
            from: document.sourceContext.preTransactionFragments
        )

        guard let header = document.header else {
            throw AxisBankAccountParserError.missingHeader
        }
        let mapping = try AxisBankCSVColumnMapping.resolve(
            headerCells: header.values
        )

        guard !document.rows.isEmpty else {
            return FinancialDocument(
                sourceDocument: document.document,
                metadata: document.metadata,
                parserName: name,
                bookedCurrency: currency,
                transactions: [],
                financialIdentifiers: financialIdentifiers
            )
        }

        var transactions: [Transaction] = []

        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.isLenient = false

        for row in document.rows {
            let parsedDate = row.values.indices.contains(mapping.date)
                ? formatter.date(from: row.values[mapping.date])
                : nil
            guard Self.containsTransactionEvidence(
                row,
                mapping: mapping,
                hasValidDate: parsedDate != nil
            ) else {
                continue
            }

            guard row.values.count > mapping.maximumIndex else {
                throw AxisBankAccountParserError.malformedTransactionRow(
                    rowNumber: row.rowNumber
                )
            }
            guard let parsedDate else {
                throw AxisBankAccountParserError.invalidDate(
                    rowNumber: row.rowNumber
                )
            }

            let description = row.values[mapping.description]
            let debit = try Self.decimal(
                row.values[mapping.debit],
                role: .debit,
                rowNumber: row.rowNumber
            )
            let credit = try Self.decimal(
                row.values[mapping.credit],
                role: .credit,
                rowNumber: row.rowNumber
            )
            let balance = try Self.decimal(
                row.values[mapping.balance],
                role: .balance,
                rowNumber: row.rowNumber
            )
            let direction: DirectionResult
            do {
                direction = try DirectionResolver.resolve(
                    strategy: .debitCreditColumns,
                    debit: debit,
                    credit: credit,
                    amount: nil,
                    direction: nil
                )
            } catch DirectionResolutionError.missingDebitAndCredit {
                throw AxisBankAccountParserError.missingDirection(
                    rowNumber: row.rowNumber
                )
            } catch DirectionResolutionError.populatedDebitAndCredit {
                throw AxisBankAccountParserError.ambiguousDirection(
                    rowNumber: row.rowNumber
                )
            }

            let amount = direction.transactionType == .debit
                ? -(direction.debit ?? 0)
                : direction.credit ?? 0

            let postedMoney = try Money(amount: amount, currency: currency)
            let transaction = Transaction(
                date: parsedDate,
                description: description,
                debitMoney: try direction.debit.map { try Money(amount: $0, currency: currency) },
                creditMoney: try direction.credit.map { try Money(amount: $0, currency: currency) },
                money: postedMoney,
                runningBalanceMoney: try balance.map { try Money(amount: $0, currency: currency) },
                account: document.metadata.institution.rawValue,
                sourceBank: "Axis Bank",
                sourceFile: document.document.filename,
                verifiedAxisUPIEventEvidence: Self.eventEvidence(
                    narration: description,
                    direction: direction.transactionType
                )
            )

            transactions.append(transaction)
        }

        return FinancialDocument(
            sourceDocument: document.document,
            metadata: document.metadata,
            parserName: name,
            bookedCurrency: currency,
            transactions: transactions,
            financialIdentifiers: financialIdentifiers
        )
    }

    private static func decimal(
        _ value: String,
        role: AxisBankCSVColumnRole,
        rowNumber: Int
    ) throws -> Decimal? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let decimal = Decimal(
            string: trimmed,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            throw AxisBankAccountParserError.invalidMonetaryValue(
                role: role,
                rowNumber: rowNumber
            )
        }
        return decimal
    }

    private static func containsTransactionEvidence(
        _ row: NormalizedRow,
        mapping: AxisBankCSVColumnMapping,
        hasValidDate: Bool
    ) -> Bool {
        if hasValidDate {
            return true
        }

        guard row.values.count == mapping.maximumIndex + 1 else {
            return false
        }

        return [mapping.debit, mapping.credit].contains { index in
            guard row.values.indices.contains(index) else { return false }
            return !row.values[index]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }
    }

    private static func financialIdentifiers(
        from fragments: [NormalizedDocument.SourceFragment]
    ) throws -> [FinancialIdentifier] {
        var uniqueIdentifiers: [String: FinancialIdentifier] = [:]

        for fragment in fragments {
            switch statementAccountEvidence(in: fragment.text) {
            case .unsupported:
                continue
            case .malformed:
                throw AxisBankAccountParserError.malformedAccountIdentifierEvidence(
                    sourceOrdinal: fragment.sourceOrdinal
                )
            case .candidate(let value):
                let identifier: FinancialIdentifier
                do {
                    identifier = try FinancialIdentifier(
                        kind: .institutionAccountId,
                        rawValue: value,
                        verificationState: .verified,
                        provenance: .institutionStructuredField
                    )
                } catch {
                    throw AxisBankAccountParserError.invalidAccountIdentifier(
                        sourceOrdinal: fragment.sourceOrdinal
                    )
                }
                uniqueIdentifiers[identifier.normalizedValue] = identifier
            }
        }

        guard uniqueIdentifiers.count <= 1 else {
            throw AxisBankAccountParserError.conflictingAccountIdentifiers
        }
        guard let identifier = uniqueIdentifiers.values.first else {
            return []
        }

        return [identifier]
    }

    private static func statementAccountEvidence(
        in sourceText: String
    ) -> StatementAccountEvidence {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard text.hasPrefix(statementAccountPrefix) else {
            return .unsupported
        }

        let remainder = text.dropFirst(statementAccountPrefix.count)

        guard let periodRange = remainder.range(of: statementPeriodMarker) else {
            return .malformed
        }

        let value = String(remainder[..<periodRange.lowerBound])

        if !value.isEmpty,
           !value.allSatisfy({ $0.isASCII && $0.isNumber }) {
            return .malformed
        }

        return .candidate(value)
    }

    private static let statementAccountPrefix = "Statement of Account No - "
    private static let statementPeriodMarker = " for the period ("

    private static func eventEvidence(
        narration: String,
        direction: TransactionType
    ) -> AxisUPITransactionEventEvidence? {
        let components = narration.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count >= 4, components[0] == "UPI" else { return nil }
        let operation: AxisUPITransactionEventEvidence.Operation
        switch components[1] {
        case "P2A": operation = .p2a
        case "P2M": operation = .p2m
        default: return nil
        }
        let reference = String(components[2])
        guard reference.count == 12,
              reference.unicodeScalars.allSatisfy({ $0.value >= 48 && $0.value <= 57 }) else {
            return nil
        }
        let subtype: AxisUPITransactionEventEvidence.LedgerSubtype
        switch direction {
        case .debit: subtype = .posting
        case .credit: subtype = .creditAdjustment
        }
        return AxisUPITransactionEventEvidence(operation: operation, reference: reference, subtype: subtype)
    }

    private enum StatementAccountEvidence {
        case unsupported
        case malformed
        case candidate(String)
    }
}
