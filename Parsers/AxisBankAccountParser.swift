//
// LedgerForge
// AxisBankAccountParser.swift
// Version: 0.2.0
//

import CryptoKit
import Foundation

enum AxisBankCSVColumnRole: String, CaseIterable, Hashable {
    case date
    case chequeReference
    case description
    case sourceDR = "source DR"
    case sourceCR = "source CR"
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
    let sourceDR: Int
    let sourceCR: Int
    let balance: Int
    let sol: Int

    var maximumIndex: Int {
        [date, chequeReference, description, sourceDR, sourceCR, balance, sol].max()!
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
            sourceDR: indices[.sourceDR]!,
            sourceCR: indices[.sourceCR]!,
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
        "dr": [.sourceDR],
        "debit": [.sourceDR],
        "cr": [.sourceCR],
        "credit": [.sourceCR],
        "bal": [.balance],
        "balance": [.balance],
        "sol": [.sol],
        "dr/cr": [.sourceDR, .sourceCR],
        "debit/credit": [.sourceDR, .sourceCR]
    ]
}

/// The source-faithful physical-column contract for `axis.bank-account.csv@2`.
///
/// Available immutable Axis bank-account evidence uses conventional semantics:
/// a populated physical DR cell is a debit/outflow and a populated physical CR
/// cell is a credit/inflow. Header resolution remains position-independent.
enum AxisBankAccountCSVProfileV2 {
    static func resolve(
        sourceDR: Decimal?,
        sourceCR: Decimal?
    ) throws -> DirectionResult {
        try DirectionResolver.resolve(
            strategy: .debitCreditColumns,
            debit: sourceDR,
            credit: sourceCR,
            amount: nil,
            direction: nil
        )
    }
}

/// The source-faithful physical-column contract for `axis.bank-account.csv@3`.
///
/// The authentic Axis CSV account corpus uses the physical `DR` column for
/// account increases and the physical `CR` column for account decreases.  The
/// canonical model intentionally keeps debit/credit terminology independent of
/// those physical source labels, so the two source columns are reversed when
/// resolving direction.  This profile is CSV-only; the Axis XLS parser keeps
/// using `AxisBankAccountCSVProfileV2` for its conventionally labelled sheet.
enum AxisBankAccountCSVProfileV3 {
    static func resolve(
        sourceDR: Decimal?,
        sourceCR: Decimal?
    ) throws -> DirectionResult {
        try DirectionResolver.resolve(
            strategy: .debitCreditColumns,
            debit: sourceCR,
            credit: sourceDR,
            amount: nil,
            direction: nil
        )
    }
}

enum AxisBankAccountParserError: Error, Equatable, LocalizedError {
    case missingHeader
    case malformedTransactionRow(rowNumber: Int)
    case invalidDate(rowNumber: Int)
    case invalidMonetaryValue(role: AxisBankCSVColumnRole, rowNumber: Int)
    case missingDirection(rowNumber: Int)
    case ambiguousDirection(rowNumber: Int)
    case nonPositiveAmount(rowNumber: Int)
    case missingBalance(rowNumber: Int)
    case unresolvedFinancialDirectionMapping
    case malformedReference(rowNumber: Int)
    case malformedAccountIdentifierEvidence(sourceOrdinal: Int)
    case invalidAccountIdentifier(sourceOrdinal: Int)
    case conflictingAccountIdentifiers
    case missingDeclaredStatementPeriod
    case malformedDeclaredStatementPeriod(sourceOrdinal: Int)
    case conflictingDeclaredStatementPeriods
    case missingFinancialRegionEvidence

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
        case .nonPositiveAmount(let rowNumber):
            return "Axis CSV transaction row \(rowNumber) contains a non-positive movement."
        case .missingBalance(let rowNumber):
            return "Axis CSV transaction row \(rowNumber) has no running balance."
        case .unresolvedFinancialDirectionMapping:
            return "Axis CSV debit and credit column meaning is not uniquely established by the statement balance transitions."
        case .malformedReference(let rowNumber):
            return "Axis CSV transaction row \(rowNumber) contains a malformed cheque/reference value."
        case .malformedAccountIdentifierEvidence(let sourceOrdinal):
            return "Axis account identifier evidence on source row \(sourceOrdinal) is malformed."
        case .invalidAccountIdentifier(let sourceOrdinal):
            return "Axis account identifier evidence on source row \(sourceOrdinal) cannot form a verified identifier."
        case .conflictingAccountIdentifiers:
            return "Axis account identifier evidence contains conflicting recognized values."
        case .missingDeclaredStatementPeriod:
            return "The supported Axis statement is missing its declared statement period."
        case .malformedDeclaredStatementPeriod(let sourceOrdinal):
            return "Axis declared statement-period evidence on source row \(sourceOrdinal) is malformed."
        case .conflictingDeclaredStatementPeriods:
            return "Axis declared statement-period evidence is duplicated or conflicting."
        case .missingFinancialRegionEvidence:
            return "The Axis CSV parser did not receive a completely scanned source table."
        }
    }
}

final class AxisBankAccountParser: StatementParser {

    private enum FinancialDirectionMapping: CaseIterable {
        case conventional
        case reversed
    }

    private struct ParsedSourceRow {
        let row: NormalizedRow
        let date: StatementDate
        let description: String
        let reference: (value: String?, digest: String?)
        let sourceDR: Decimal?
        let sourceCR: Decimal?
        let balance: Decimal
    }

    static let profileID = "axis.bank-account.csv"
    static let profileVersion = "3"

    var name: String {
        "Axis Bank Account"
    }

    func canParse(
        document: Document,
        metadata: DocumentMetadata
    ) -> Bool {

        return metadata.institution == .axis &&
               metadata.documentType == .bankAccount &&
               (metadata.fileFormat == .csv ||
                   metadata.fileFormat == .unknown) &&
               document.fileType.caseInsensitiveCompare(
                   FileFormat.csv.rawValue
               ) == .orderedSame
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
        let declaredStatementPeriod = try Self.declaredStatementPeriod(
            from: document.sourceContext.preTransactionFragments
        )
        guard let region = document.sourceContext.exhaustedFinancialRegion,
              region.sourceUnit == .line,
              region.matches(normalizedFinancialRowCount: document.rows.count),
              document.sourceContext.printedBankStatementControls == nil else {
            throw AxisBankAccountParserError.missingFinancialRegionEvidence
        }
        let sourceStatementEvidence = SourceStatementEvidence(
            sourceFormatCode: "csv",
            statementBoundaryDate: nil,
            period: declaredStatementPeriod,
            openingBalance: nil,
            closingBalance: nil
        )

        guard !document.rows.isEmpty else {
            let zeroEvidence = try ZeroActivityStatementEvidence(
                profileID: Self.profileID,
                profileVersion: Self.profileVersion,
                sourceFormatCode: "csv",
                evidenceKind: .exhaustedFinancialRegion,
                financialRegionDescriptor: region.descriptor,
                financialRegionSourceUnit: region.sourceUnit,
                financialRegionStartOrdinal: region.startOrdinal,
                financialRegionEndOrdinal: region.endOrdinal,
                financialRegionSignature: region.signature,
                statementPeriod: declaredStatementPeriod,
                nativeCurrency: currency
            )
            return FinancialDocument(
                sourceDocument: document.document,
                metadata: document.metadata,
                parserName: name,
                parserProfileID: Self.profileID,
                parserProfileVersion: Self.profileVersion,
                bookedCurrency: currency,
                declaredStatementPeriod: declaredStatementPeriod,
                transactions: [],
                financialIdentifiers: financialIdentifiers,
                sourceStatementEvidence: sourceStatementEvidence,
                zeroActivityEvidence: zeroEvidence
            )
        }

        var parsedRows: [ParsedSourceRow] = []

        for row in document.rows {
            let parsedDate: StatementDate? = row.values.indices.contains(mapping.date)
                ? try? StatementDate.axisNRE(row.values[mapping.date])
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
            guard row.hasConsistentRawValues else {
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
            let reference = try Self.referenceEvidence(
                in: row,
                index: mapping.chequeReference
            )
            let sourceDR = try Self.decimal(
                row.values[mapping.sourceDR],
                role: .sourceDR,
                rowNumber: row.rowNumber
            )
            let sourceCR = try Self.decimal(
                row.values[mapping.sourceCR],
                role: .sourceCR,
                rowNumber: row.rowNumber
            )
            guard let balance = try Self.decimal(
                row.values[mapping.balance],
                role: .balance,
                rowNumber: row.rowNumber
            ) else {
                throw AxisBankAccountParserError.missingBalance(rowNumber: row.rowNumber)
            }
            _ = try Self.sourceAmount(
                sourceDR: sourceDR,
                sourceCR: sourceCR,
                rowNumber: row.rowNumber
            )
            parsedRows.append(
                ParsedSourceRow(
                    row: row,
                    date: parsedDate,
                    description: description,
                    reference: reference,
                    sourceDR: sourceDR,
                    sourceCR: sourceCR,
                    balance: balance
                )
            )
        }

        let financialDirectionMapping = try Self.financialDirectionMapping(
            for: parsedRows
        )
        var transactions: [Transaction] = []
        transactions.reserveCapacity(parsedRows.count)

        for parsed in parsedRows {
            let direction: DirectionResult
            do {
                switch financialDirectionMapping {
                case .conventional:
                    direction = try AxisBankAccountCSVProfileV2.resolve(
                        sourceDR: parsed.sourceDR,
                        sourceCR: parsed.sourceCR
                    )
                case .reversed:
                    direction = try AxisBankAccountCSVProfileV3.resolve(
                        sourceDR: parsed.sourceDR,
                        sourceCR: parsed.sourceCR
                    )
                }
            } catch DirectionResolutionError.missingDebitAndCredit {
                throw AxisBankAccountParserError.missingDirection(
                    rowNumber: parsed.row.rowNumber
                )
            } catch DirectionResolutionError.populatedDebitAndCredit {
                throw AxisBankAccountParserError.ambiguousDirection(
                    rowNumber: parsed.row.rowNumber
                )
            }

            let amount = direction.transactionType == .debit
                ? -(direction.debit ?? 0)
                : direction.credit ?? 0

            let postedMoney = try Money(amount: amount, currency: currency)
            let transaction = Transaction(
                statementDate: parsed.date,
                description: parsed.description,
                reference: parsed.reference.value,
                debitMoney: try direction.debit.map { try Money(amount: $0, currency: currency) },
                creditMoney: try direction.credit.map { try Money(amount: $0, currency: currency) },
                money: postedMoney,
                runningBalanceMoney: try Money(amount: parsed.balance, currency: currency),
                account: document.metadata.institution.rawValue,
                sourceBank: "Axis Bank",
                sourceFile: document.document.filename,
                financialDateRole: .transactionDate,
                statementTimezoneEvidence: .iana("Asia/Kolkata"),
                sourceProvenance: [
                    TransactionSourceProvenance(
                        normalizedDocumentID: document.document.id.uuidString,
                        normalizedRowID: parsed.row.id.uuidString,
                        sourceOrdinal: parsed.row.rowNumber,
                        normalizedRecordDigest: String.normalizedRecordDigest(values: parsed.row.values),
                        parserProfileID: Self.profileID,
                        parserProfileVersion: Self.profileVersion,
                        structuredReferenceDigest: parsed.reference.digest
                    )
                ],
                verifiedAxisUPIEventEvidence:
                    AxisBankAccountSourceEvidence.transactionEventEvidence(
                    narration: parsed.description,
                    direction: direction.transactionType
                )
            )

            transactions.append(transaction)
        }

        return FinancialDocument(
            sourceDocument: document.document,
            metadata: document.metadata,
            parserName: name,
            parserProfileID: Self.profileID,
            parserProfileVersion: Self.profileVersion,
            bookedCurrency: currency,
            declaredStatementPeriod: declaredStatementPeriod,
            transactions: transactions,
            financialIdentifiers: financialIdentifiers,
            sourceStatementEvidence: sourceStatementEvidence
        )
    }

    private static func decimal(
        _ value: String,
        role: AxisBankCSVColumnRole,
        rowNumber: Int
    ) throws -> Decimal? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Decimal(string:) accepts a valid numeric prefix (for example,
        // "100.00X" becomes 100).  Validate the entire source token before
        // parsing so malformed Money cannot be silently truncated.  Grouped
        // commas are accepted only in standard three-digit groups and are
        // removed before Foundation Decimal conversion.
        guard Self.looksLikeStrictDecimal(trimmed),
              let decimal = Decimal(
                  string: trimmed.replacingOccurrences(of: ",", with: ""),
                  locale: Locale(identifier: "en_US_POSIX")
              ) else {
            throw AxisBankAccountParserError.invalidMonetaryValue(
                role: role,
                rowNumber: rowNumber
            )
        }
        return decimal
    }

    private static func referenceEvidence(
        in row: NormalizedRow,
        index: Int
    ) throws -> (value: String?, digest: String?) {
        guard row.values.indices.contains(index) else {
            throw AxisBankAccountParserError.malformedTransactionRow(
                rowNumber: row.rowNumber
            )
        }

        let source = row.rawValues.flatMap { rawValues in
            rawValues.indices.contains(index) ? rawValues[index] : nil
        } ?? row.values[index]
        do {
            return try AxisBankAccountSourceEvidence.numericReference(source)
        } catch {
            throw AxisBankAccountParserError.malformedReference(
                rowNumber: row.rowNumber
            )
        }
    }

    private static func sourceAmount(
        sourceDR: Decimal?,
        sourceCR: Decimal?,
        rowNumber: Int
    ) throws -> (role: AxisBankCSVColumnRole, amount: Decimal) {
        switch (sourceDR, sourceCR) {
        case (.some(let amount), nil):
            guard amount > 0 else {
                throw AxisBankAccountParserError.nonPositiveAmount(rowNumber: rowNumber)
            }
            return (.sourceDR, amount)
        case (nil, .some(let amount)):
            guard amount > 0 else {
                throw AxisBankAccountParserError.nonPositiveAmount(rowNumber: rowNumber)
            }
            return (.sourceCR, amount)
        case (nil, nil):
            throw AxisBankAccountParserError.missingDirection(rowNumber: rowNumber)
        case (.some, .some):
            throw AxisBankAccountParserError.ambiguousDirection(rowNumber: rowNumber)
        }
    }

    /// Resolves the physical DR/CR meaning from the statement itself. The
    /// first row cannot establish an opening transition, so every subsequent
    /// exact running-balance transition is evaluated under both possible
    /// interpretations and exactly one interpretation must survive.
    private static func financialDirectionMapping(
        for rows: [ParsedSourceRow]
    ) throws -> FinancialDirectionMapping {
        var candidates = FinancialDirectionMapping.allCases
        for (previous, current) in zip(rows, rows.dropFirst()) {
            let source = try sourceAmount(
                sourceDR: current.sourceDR,
                sourceCR: current.sourceCR,
                rowNumber: current.row.rowNumber
            )
            let delta = current.balance - previous.balance
            candidates.removeAll { mapping in
                let signedAmount: Decimal
                switch (mapping, source.role) {
                case (.conventional, .sourceDR), (.reversed, .sourceCR):
                    signedAmount = -source.amount
                case (.conventional, .sourceCR), (.reversed, .sourceDR):
                    signedAmount = source.amount
                default:
                    return true
                }
                return delta != signedAmount
            }
        }
        guard candidates.count == 1, let resolved = candidates.first else {
            throw AxisBankAccountParserError.unresolvedFinancialDirectionMapping
        }
        return resolved
    }

    private static func containsTransactionEvidence(
        _ row: NormalizedRow,
        mapping: AxisBankCSVColumnMapping,
        hasValidDate: Bool
    ) -> Bool {
        if hasValidDate {
            return true
        }

        // Keep nonfinancial footer/preamble fragments ignorable, but do not
        // silently discard a row that carries date-shaped or monetary
        // transaction evidence merely because its column count is malformed.
        // The caller will then produce the typed malformed-row/invalid-date
        // error instead of accepting a partial record.
        let rawDate = row.values.indices.contains(mapping.date)
            ? row.values[mapping.date]
            : ""
        let hasNonemptyDateCell = !rawDate.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
        let hasDateEvidence = Self.looksLikeDateEvidence(rawDate)
        // A balance-only footer/control line is not transaction evidence.
        // Direction-bearing DR/CR cells are: if either is amount-shaped, the
        // row must reach the parser and fail closed when its date/layout is
        // malformed.
        let hasMonetaryEvidence = [
            mapping.sourceDR,
            mapping.sourceCR
        ].contains { index in
            guard row.values.indices.contains(index) else { return false }
            return Self.looksLikeMonetaryEvidence(row.values[index])
        }
        let hasBalanceEvidence = row.values.indices.contains(mapping.balance) &&
            Self.looksLikeMonetaryEvidence(row.values[mapping.balance])

        return hasDateEvidence ||
            hasMonetaryEvidence ||
            (hasNonemptyDateCell && hasBalanceEvidence)
    }

    private static func looksLikeDateEvidence(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Axis account CSV dates are day-month-year.  Keep this lexical gate
        // deliberately broad enough to route malformed date tokens to the
        // parser's typed invalid-date error, while excluding prose such as
        // footer text from transaction evidence.
        let pattern = #"^\d{1,4}[-/]\d{1,2}[-/]\d{1,4}$"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return expression.firstMatch(in: trimmed, range: range) != nil
    }

    private static func looksLikeMonetaryEvidence(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // A source monetary cell is amount-shaped when it starts with an
        // optional sign followed by a digit/decimal punctuation, contains at
        // least one ASCII digit, and has no whitespace.  The lexical check is
        // intentionally independent of Decimal parsing: malformed numeric
        // forms (for example, "12.3.4" or "100.00X") still route through the
        // parser's fail-closed monetary validation, while prose fragments such
        // as comma-split footer text remain ignorable.
        let scalars = Array(trimmed.unicodeScalars)
        var bodyStart = 0
        if let first = scalars.first, first == "+" || first == "-" {
            bodyStart = 1
        }
        guard bodyStart < scalars.count else { return false }

        let body = scalars[bodyStart...]
        guard let firstBodyScalar = body.first,
              Self.isAmountLeadingScalar(firstBodyScalar),
              body.contains(where: Self.isASCIIDigit),
              body.allSatisfy(Self.isAmountScalar) else {
            return false
        }

        return true
    }

    private static func looksLikeStrictDecimal(_ value: String) -> Bool {
        let pattern = #"^[+-]?(?:(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?|\.\d+)$"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(value.startIndex..., in: value)
        return expression.firstMatch(in: value, range: range) != nil
    }

    private nonisolated static func isASCIIDigit(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 48 && scalar.value <= 57
    }

    private nonisolated static func isAmountLeadingScalar(_ scalar: Unicode.Scalar) -> Bool {
        isASCIIDigit(scalar) || scalar == "." || scalar == ","
    }

    private nonisolated static func isAmountScalar(_ scalar: Unicode.Scalar) -> Bool {
        isASCIIDigit(scalar) || scalar == "." || scalar == "," ||
            (scalar.value >= 65 && scalar.value <= 90) ||
            (scalar.value >= 97 && scalar.value <= 122)
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
                    identifier = try AxisBankAccountSourceEvidence
                        .verifiedAccountIdentifier(value)
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

    private static func declaredStatementPeriod(
        from fragments: [NormalizedDocument.SourceFragment]
    ) throws -> DeclaredStatementPeriod {
        let matching = fragments.filter {
            let text = $0.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.hasPrefix(statementAccountPrefix) &&
                text.contains(statementPeriodMarker)
        }
        guard !matching.isEmpty else {
            throw AxisBankAccountParserError.missingDeclaredStatementPeriod
        }
        guard matching.count == 1, let fragment = matching.first else {
            throw AxisBankAccountParserError.conflictingDeclaredStatementPeriods
        }

        let text = fragment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let markerRange = text.range(of: statementPeriodMarker) else {
            throw AxisBankAccountParserError.malformedDeclaredStatementPeriod(
                sourceOrdinal: fragment.sourceOrdinal
            )
        }
        let periodText = String(text[markerRange.upperBound...])
        let pattern = #"^From\s*:\s*(\d{2}-\d{2}-\d{4})\s+To\s*:\s*(\d{2}-\d{2}-\d{4})\)\s*$"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: periodText,
                range: NSRange(periodText.startIndex..., in: periodText)
              ),
              match.numberOfRanges == 3,
              let startRange = Range(match.range(at: 1), in: periodText),
              let endRange = Range(match.range(at: 2), in: periodText),
              let period = try? AxisBankAccountSourceEvidence.declaredStatementPeriod(
                  startText: String(periodText[startRange]),
                  endText: String(periodText[endRange])
              ) else {
            throw AxisBankAccountParserError.malformedDeclaredStatementPeriod(
                sourceOrdinal: fragment.sourceOrdinal
            )
        }
        return period
    }

    private enum StatementAccountEvidence {
        case unsupported
        case malformed
        case candidate(String)
    }
}
