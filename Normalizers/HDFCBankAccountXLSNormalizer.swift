import Foundation

enum HDFCBankAccountXLSNormalizationError: Error, Equatable, LocalizedError {
    case unsupportedDocumentContent
    case unsupportedWorksheet
    case unexpectedColumnCount(Int)
    case malformedPhysicalGrid(sourceOrdinal: Int)
    case missingHeader
    case duplicateHeader
    case changedHeader(sourceOrdinal: Int)
    case malformedPreamble(sourceOrdinal: Int)
    case noTransactions
    case malformedTransaction(sourceOrdinal: Int)
    case malformedSummary(sourceOrdinal: Int)
    case unsupportedTrailingRow(sourceOrdinal: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocumentContent:
            return "The HDFC XLS normalizer requires bounded tabular content."
        case .unsupportedWorksheet:
            return "The HDFC XLS workbook has no visible financial worksheet."
        case .unexpectedColumnCount:
            return "The HDFC XLS transaction table does not expose all required financial roles."
        case .malformedPhysicalGrid(let sourceOrdinal):
            return "HDFC XLS row \(sourceOrdinal) has an invalid physical cell grid."
        case .missingHeader:
            return "The HDFC XLS financial table header is missing."
        case .duplicateHeader:
            return "The HDFC XLS financial table header is duplicated or ambiguous."
        case .changedHeader(let sourceOrdinal):
            return "HDFC XLS header row \(sourceOrdinal) has ambiguous financial-column ownership."
        case .malformedPreamble(let sourceOrdinal):
            return "HDFC XLS preamble row \(sourceOrdinal) has incomplete or ambiguous source identity."
        case .noTransactions:
            return "The HDFC XLS statement contains no supported transaction rows."
        case .malformedTransaction(let sourceOrdinal):
            return "HDFC XLS transaction row \(sourceOrdinal) is financially malformed."
        case .malformedSummary(let sourceOrdinal):
            return "HDFC XLS summary row \(sourceOrdinal) is financially malformed."
        case .unsupportedTrailingRow(let sourceOrdinal):
            return "HDFC XLS row \(sourceOrdinal) contains unconsumed financial evidence."
        }
    }
}

struct HDFCBankAccountXLSNormalizationResult {
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow
    let sourceContext: NormalizedDocument.SourceContext
}

/// Source-family normalization for HDFC's recurring bank-account BIFF export.
///
/// Physical rows and columns remain provenance. Admission is instead based on
/// a unique semantic header, coherent HDFC/account-period evidence and the
/// printed financial summary. This intentionally has no row-21/row-23 or
/// fixed-trailer contract.
final class HDFCBankAccountXLSNormalizer {
    static let logicalHeader = [
        "Date",
        "Narration",
        "Chq./Ref.No.",
        "Value Dt",
        "Withdrawal Amt.",
        "Deposit Amt.",
        "Closing Balance"
    ]

    private struct HeaderMapping {
        let row: RawTabularRow
        /// Physical zero-based column for each logical role above.
        let physicalColumns: [Int]
    }

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func normalize(rawDocument: RawDocument) throws -> HDFCBankAccountXLSNormalizationResult {
        guard case .tabular(let sheet) = rawDocument.content else {
            throw HDFCBankAccountXLSNormalizationError.unsupportedDocumentContent
        }
        guard sheet.visibility == .visible else {
            throw HDFCBankAccountXLSNormalizationError.unsupportedWorksheet
        }
        guard sheet.columnCount >= Self.logicalHeader.count else {
            throw HDFCBankAccountXLSNormalizationError.unexpectedColumnCount(sheet.columnCount)
        }
        for (index, row) in sheet.rows.enumerated() {
            guard row.sourceRow == index + 1,
                  row.cells.count == sheet.columnCount,
                  row.cells.enumerated().allSatisfy({ offset, cell in
                      cell.sourceRow == row.sourceRow && cell.sourceColumn == offset + 1
                  }) else {
                throw HDFCBankAccountXLSNormalizationError.malformedPhysicalGrid(
                    sourceOrdinal: row.sourceRow
                )
            }
        }

        let header = try headerMapping(in: sheet)
        try validateSourceIdentity(before: header.row.sourceRow, in: sheet)

        let summaryRows = sheet.rows.filter {
            $0.sourceRow > header.row.sourceRow && Self.isSummaryTitle($0)
        }
        guard summaryRows.count == 1, let summaryRow = summaryRows.first else {
            throw HDFCBankAccountXLSNormalizationError.malformedSummary(
                sourceOrdinal: summaryRows.first?.sourceRow ?? header.row.sourceRow
            )
        }

        let transactionRows = try normalizedTransactions(
            between: header.row.sourceRow,
            and: summaryRow.sourceRow,
            mapping: header,
            in: sheet
        )
        try validateNoTrailingFinancialRows(
            after: summaryRow.sourceRow,
            mapping: header,
            in: sheet
        )

        var document = Document(
            filename: rawDocument.fileName,
            url: rawDocument.sourceURL,
            fileType: FileFormat.xls.rawValue,
            importedAt: now()
        )
        document.rowCount = sheet.rows.count
        document.headerRow = header.row.sourceRow
        document.firstTransactionRow = transactionRows.first?.rowNumber
        document.columnCount = Self.logicalHeader.count
        document.encoding = "UTF-8"

        let preamble = sheet.rows
            .filter { $0.sourceRow < header.row.sourceRow }
            .filter { !Self.isEmpty($0) && !Self.isSeparator($0) }
            .map { Self.sourceFragment($0) }
        let postamble = sheet.rows
            .filter { $0.sourceRow >= summaryRow.sourceRow }
            .filter { !Self.isEmpty($0) && !Self.isSeparator($0) }
            .map { Self.sourceFragment($0) }

        return HDFCBankAccountXLSNormalizationResult(
            document: document,
            rows: transactionRows,
            header: NormalizedRow(
                rowNumber: header.row.sourceRow,
                values: Self.logicalHeader
            ),
            sourceContext: NormalizedDocument.SourceContext(
                preTransactionFragments: preamble,
                postTransactionFragments: postamble
            )
        )
    }

    private func headerMapping(in sheet: RawTabularSheet) throws -> HeaderMapping {
        var complete: [HeaderMapping] = []
        var near: [RawTabularRow] = []
        for row in sheet.rows {
            let recognized = row.cells.enumerated().compactMap { column, cell -> (Int, Int)? in
                guard let role = Self.headerRole(Self.text(cell.value)) else { return nil }
                return (role, column)
            }
            if recognized.count >= 4 { near.append(row) }
            guard recognized.count == Self.logicalHeader.count,
                  Set(recognized.map(\.0)).count == Self.logicalHeader.count else { continue }
            var physicalColumns = Array(repeating: -1, count: Self.logicalHeader.count)
            for (role, column) in recognized { physicalColumns[role] = column }
            guard physicalColumns.allSatisfy({ $0 >= 0 }) else { continue }
            complete.append(HeaderMapping(row: row, physicalColumns: physicalColumns))
        }
        guard complete.count == 1, let result = complete.first else {
            if complete.count > 1 {
                throw HDFCBankAccountXLSNormalizationError.duplicateHeader
            }
            if let nearHeader = near.first {
                throw HDFCBankAccountXLSNormalizationError.changedHeader(
                    sourceOrdinal: nearHeader.sourceRow
                )
            }
            throw HDFCBankAccountXLSNormalizationError.missingHeader
        }
        return result
    }

    private func validateSourceIdentity(before headerRow: Int, in sheet: RawTabularSheet) throws {
        let fragments = sheet.rows
            .filter { $0.sourceRow < headerRow }
            .filter { !Self.isEmpty($0) && !Self.isSeparator($0) }
        let text = Self.boundedWhitespace(
            fragments.flatMap { Self.values($0) }.joined(separator: " ")
        )
        guard text.localizedCaseInsensitiveContains("HDFC BANK"),
              text.range(
                  of: #"\bStatement\s+of\s+accounts?\b"#,
                  options: [.regularExpression, .caseInsensitive]
              ) != nil,
              text.range(
                  of: #"\bAccount\s+No\s*:\s*[0-9]{14}\s+NR\s+Others\b"#,
                  options: [.regularExpression, .caseInsensitive]
              ) != nil,
              text.range(
                  of: #"\bCust\s+ID\s*:\s*[0-9]{9}\b"#,
                  options: [.regularExpression, .caseInsensitive]
              ) != nil,
              text.range(
                  of: #"\b(?:Statement(?:\s+of\s+accounts?)?\s+)?From\s*:\s*[0-9]{2}/[0-9]{2}/[0-9]{4}\s+To\s*:\s*[0-9]{2}/[0-9]{2}/[0-9]{4}\b"#,
                  options: [.regularExpression, .caseInsensitive]
              ) != nil,
              text.range(
                  of: #"\bCurrency\s*:\s*INR\b"#,
                  options: [.regularExpression, .caseInsensitive]
              ) != nil else {
            throw HDFCBankAccountXLSNormalizationError.malformedPreamble(
                sourceOrdinal: fragments.first?.sourceRow ?? 1
            )
        }
    }

    private func normalizedTransactions(
        between headerRow: Int,
        and summaryRow: Int,
        mapping: HeaderMapping,
        in sheet: RawTabularSheet
    ) throws -> [NormalizedRow] {
        var result: [NormalizedRow] = []
        for row in sheet.rows where row.sourceRow > headerRow && row.sourceRow < summaryRow {
            if Self.isEmpty(row) || Self.isSeparator(row) { continue }
            let values = mapping.physicalColumns.map { Self.text(row.cells[$0].value) }
            guard Self.matches(values[0], Self.shortDatePattern) else {
                if Self.containsFinancialEvidence(values) {
                    throw HDFCBankAccountXLSNormalizationError.malformedTransaction(
                        sourceOrdinal: row.sourceRow
                    )
                }
                // Benign print/export packaging between the semantic header and
                // summary is not statement identity. It remains represented in
                // the reader evidence but is not a financial row.
                continue
            }
            guard !Self.boundedWhitespace(values[1]).isEmpty,
                  Self.matches(values[3], Self.shortDatePattern),
                  (Self.isMoney(values[4]) != Self.isMoney(values[5])),
                  Self.isMoney(values[6]) else {
                throw HDFCBankAccountXLSNormalizationError.malformedTransaction(
                    sourceOrdinal: row.sourceRow
                )
            }
            var normalizedValues = values
            normalizedValues[1] = Self.boundedWhitespace(values[1])
            normalizedValues[2] = Self.boundedWhitespace(values[2])
            result.append(NormalizedRow(rowNumber: row.sourceRow, values: normalizedValues))
        }
        return result
    }

    private func validateNoTrailingFinancialRows(
        after summaryRow: Int,
        mapping: HeaderMapping,
        in sheet: RawTabularSheet
    ) throws {
        for row in sheet.rows where row.sourceRow > summaryRow {
            if Self.isEmpty(row) || Self.isSeparator(row) { continue }
            let values = mapping.physicalColumns.map { Self.text(row.cells[$0].value) }
            if Self.matches(values[0], Self.shortDatePattern) {
                throw HDFCBankAccountXLSNormalizationError.unsupportedTrailingRow(
                    sourceOrdinal: row.sourceRow
                )
            }
            if Self.headerRoleCount(in: row) >= 4 {
                throw HDFCBankAccountXLSNormalizationError.duplicateHeader
            }
        }
    }

    private static func headerRole(_ value: String) -> Int? {
        switch semanticKey(value) {
        case "date": return 0
        case "narration", "description", "transactiondetails": return 1
        case "chqrefno", "chequerefno", "referenceno", "reference": return 2
        case "valuedt", "valuedate": return 3
        case "withdrawalamt", "withdrawalamount", "debitamt", "debitamount": return 4
        case "depositamt", "depositamount", "creditamt", "creditamount": return 5
        case "closingbalance", "balance": return 6
        default: return nil
        }
    }

    private static func headerRoleCount(in row: RawTabularRow) -> Int {
        Set(values(row).compactMap { headerRole($0) }).count
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

    private static func isSummaryTitle(_ row: RawTabularRow) -> Bool {
        values(row).contains { semanticKey($0) == "statementsummary" }
    }

    private static func containsFinancialEvidence(_ values: [String]) -> Bool {
        Self.matches(values[3], #"^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4}$"#)
            || Self.isMoney(values[4])
            || Self.isMoney(values[5])
            || Self.isMoney(values[6])
    }

    private static func values(_ row: RawTabularRow) -> [String] {
        row.cells.map { text($0.value) }
    }

    private static func text(_ value: RawTabularCellValue) -> String {
        value.canonicalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func boundedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func isEmpty(_ row: RawTabularRow) -> Bool {
        values(row).allSatisfy(\.isEmpty)
    }

    private static func isSeparator(_ row: RawTabularRow) -> Bool {
        let populated = values(row).filter { !$0.isEmpty }
        guard !populated.isEmpty else { return false }
        return populated.allSatisfy { value in
            value.count >= 3 && value.allSatisfy { $0 == "*" || $0 == "-" }
        }
    }

    private static func sourceFragment(_ row: RawTabularRow) -> NormalizedDocument.SourceFragment {
        NormalizedDocument.SourceFragment(
            sourceOrdinal: row.sourceRow,
            text: values(row).joined(separator: "\t")
        )
    }

    private static func isMoney(_ value: String) -> Bool {
        matches(value, moneyPattern)
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: value,
                  range: NSRange(value.startIndex..., in: value)
              ) else {
            return false
        }
        return match.range == NSRange(value.startIndex..., in: value)
    }

    private static let shortDatePattern = #"^[0-9]{2}/[0-9]{2}/[0-9]{2}$"#
    private static let moneyPattern = #"^-?(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)(?:\.[0-9]{1,2})?$"#
}
