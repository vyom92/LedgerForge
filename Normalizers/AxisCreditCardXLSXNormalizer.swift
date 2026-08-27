import Foundation

enum AxisCreditCardXLSXNormalizationError: Error, Equatable, LocalizedError {
    case unsupportedDocumentContent
    case multipleVisibleSheets
    case missingHeader
    case changedHeader(sourceOrdinal: Int)
    case duplicateHeader
    case malformedTransaction(sourceOrdinal: Int)
    case noTransactions
    case malformedPreamble

    var errorDescription: String? {
        switch self {
        case .unsupportedDocumentContent: return "The Axis card XLSX normalizer requires a visible OOXML worksheet."
        case .multipleVisibleSheets: return "The Axis card XLSX workbook has more than one visible worksheet."
        case .missingHeader: return "The exact Axis card XLSX header is missing."
        case .changedHeader(let ordinal): return "Axis card XLSX header row \(ordinal) changed."
        case .duplicateHeader: return "The Axis card XLSX header is duplicated."
        case .malformedTransaction(let ordinal): return "Axis card XLSX row \(ordinal) is malformed."
        case .noTransactions: return "The Axis card XLSX statement contains no financial rows."
        case .malformedPreamble: return "The Axis card XLSX source preamble is malformed or ambiguous."
        }
    }
}

struct AxisCreditCardXLSXNormalizationResult {
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow
    let sourceContext: NormalizedDocument.SourceContext
}

final class AxisCreditCardXLSXNormalizer {
    static let logicalHeader = [
        "Transaction Date", "Transaction Details", "Amount (INR)",
        "Liability Effect", "Scope", "Section ID", "Reference",
        "Original Amount", "Original Currency"
    ]

    private let now: () -> Date
    init(now: @escaping () -> Date = Date.init) { self.now = now }

    func normalize(rawDocument: RawDocument) throws -> AxisCreditCardXLSXNormalizationResult {
        guard case .tabular(let sheet) = rawDocument.content,
              sheet.visibility == .visible else {
            throw AxisCreditCardXLSXNormalizationError.unsupportedDocumentContent
        }
        let exact = sheet.rows.filter(Self.isExactHeader)
        guard exact.count == 1, let header = exact.first else {
            if exact.count > 1 { throw AxisCreditCardXLSXNormalizationError.duplicateHeader }
            if let near = sheet.rows.first(where: Self.looksLikeHeader) {
                throw AxisCreditCardXLSXNormalizationError.changedHeader(sourceOrdinal: near.sourceRow)
            }
            throw AxisCreditCardXLSXNormalizationError.missingHeader
        }

        let preambleRows = sheet.rows.filter { $0.sourceRow < header.sourceRow }
        let preamble = try preambleRows.compactMap { row -> NormalizedDocument.SourceFragment? in
            guard let cells = Self.physicalValues(row) else {
                throw AxisCreditCardXLSXNormalizationError.malformedPreamble
            }
            let text = cells.keys.sorted().compactMap { column -> String? in
                let value = cells[column] ?? ""
                return value.isEmpty ? nil : value
            }.joined(separator: " ")
            return text.isEmpty ? nil : .init(sourceOrdinal: row.sourceRow, text: text)
        }
        let joinedPreamble = preamble.map(\.text).joined(separator: "\n")
        var fragments = AxisCreditCardPDFNormalizer.sourceFragments(from: joinedPreamble)
        fragments.append(.init(sourceOrdinal: 0, text: "FORMAT\txlsx"))

        var rows: [NormalizedRow] = []
        var ended = false
        for row in sheet.rows where row.sourceRow > header.sourceRow {
            guard let physical = Self.physicalValues(row) else {
                throw AxisCreditCardXLSXNormalizationError.malformedTransaction(sourceOrdinal: row.sourceRow)
            }
            if physical.contains(where: { $0.key > 6 && !$0.value.isEmpty }) {
                throw AxisCreditCardXLSXNormalizationError.malformedTransaction(sourceOrdinal: row.sourceRow)
            }
            let values = (1...6).map { physical[$0] ?? "" }

            // The approved Axis XLSX family terminates its financial ledger
            // with one non-financial row merged across the full A:F transaction
            // width. The literal footer text is presentation-only and is not
            // part of the production grammar.
            if Self.isExactEndOfStatement(
                row: row,
                values: values,
                mergedRanges: sheet.mergedRanges
            ) {
                guard !rows.isEmpty else {
                    throw AxisCreditCardXLSXNormalizationError.malformedTransaction(
                        sourceOrdinal: row.sourceRow
                    )
                }
                ended = true
                continue
            }

            if values.allSatisfy(\.isEmpty) {
                if !rows.isEmpty { ended = true }
                continue
            }
            if ended {
                throw AxisCreditCardXLSXNormalizationError.malformedTransaction(sourceOrdinal: row.sourceRow)
            }
            guard values[2].isEmpty, values[5].isEmpty,
                  let date = Self.date(values[0]),
                  !values[1].isEmpty,
                  let amount = Self.money(values[3]),
                  let direction = Self.effect(values[4]) else {
                throw AxisCreditCardXLSXNormalizationError.malformedTransaction(sourceOrdinal: row.sourceRow)
            }
            let details = values[1]
            rows.append(NormalizedRow(rowNumber: row.sourceRow, values: [
                date, details, amount, direction, "account_level",
                "", "", "", ""
            ]))
        }
        guard !rows.isEmpty else { throw AxisCreditCardXLSXNormalizationError.noTransactions }

        var document = Document(filename: rawDocument.fileName, url: rawDocument.sourceURL,
                                fileType: FileFormat.xlsx.rawValue, importedAt: now())
        document.rowCount = sheet.rows.count
        document.headerRow = header.sourceRow
        document.firstTransactionRow = rows.first?.rowNumber
        document.columnCount = sheet.columnCount
        document.encoding = "UTF-8"
        return AxisCreditCardXLSXNormalizationResult(
            document: document,
            rows: rows,
            header: NormalizedRow(rowNumber: header.sourceRow, values: Self.logicalHeader),
            sourceContext: .init(preTransactionFragments: fragments)
        )
    }

    nonisolated private static func trimmed(_ value: RawTabularCellValue) -> String {
        value.canonicalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func physicalValues(_ row: RawTabularRow) -> [Int: String]? {
        var result: [Int: String] = [:]
        var previousColumn = 0
        for cell in row.cells {
            guard cell.sourceRow == row.sourceRow,
                  cell.sourceColumn > previousColumn,
                  cell.sourceColumn > 0,
                  result[cell.sourceColumn] == nil else { return nil }
            previousColumn = cell.sourceColumn
            result[cell.sourceColumn] = trimmed(cell.value)
        }
        return result
    }

    nonisolated private static func isExactHeader(_ row: RawTabularRow) -> Bool {
        guard let cells = physicalValues(row),
              !cells.contains(where: { $0.key > 6 && !$0.value.isEmpty }) else { return false }
        let value: (Int) -> String = { cells[$0] ?? "" }
        return value(1).caseInsensitiveCompare("Date") == .orderedSame &&
            value(2).caseInsensitiveCompare("Transaction Details") == .orderedSame &&
            value(3).isEmpty &&
            value(4).caseInsensitiveCompare("Amount (INR)") == .orderedSame &&
            value(5).caseInsensitiveCompare("Debit/Credit") == .orderedSame &&
            value(6).isEmpty
    }

    nonisolated private static func looksLikeHeader(_ row: RawTabularRow) -> Bool {
        let values = row.cells.map { trimmed($0.value).uppercased() }
        return values.filter { ["DATE", "TRANSACTION DETAILS", "AMOUNT (INR)", "DEBIT/CREDIT"].contains($0) }.count >= 2
    }

    private static func isExactEndOfStatement(
        row: RawTabularRow,
        values: [String],
        mergedRanges: [RawTabularMergedRange]
    ) -> Bool {
        guard values.count >= 6,
              !values[0].isEmpty,
              values.dropFirst().allSatisfy(\.isEmpty) else {
            return false
        }

        let matchingMerges = mergedRanges.filter {
            $0.startRow == row.sourceRow &&
            $0.endRow == row.sourceRow
        }

        guard matchingMerges.count == 1,
              let merge = matchingMerges.first else {
            return false
        }

        return merge.startColumn == 1 &&
            merge.endColumn == 6 &&
            merge.reference.uppercased() ==
                "A\(row.sourceRow):F\(row.sourceRow)"
    }

    fileprivate static func date(_ value: String) -> String? {
        let clean = value.replacingOccurrences(of: "’", with: "'")
        if let parsed = try? axisDate(clean) { return parsed.canonical }
        if let parsed = try? numericDate(clean) { return parsed.canonical }
        return nil
    }

    private static func axisDate(_ value: String) throws -> StatementDate {
        let parts = value.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 3, let day = Int(parts[0]), let yearRaw = Int(parts[2].replacingOccurrences(of: "'", with: "")),
              let month = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"].firstIndex(where: { $0.caseInsensitiveCompare(String(parts[1])) == .orderedSame }) else {
            throw StatementDate.Error.malformedAxisDate(value)
        }
        return try StatementDate(year: yearRaw < 100 ? 2000 + yearRaw : yearRaw, month: month + 1, day: day)
    }

    private static func numericDate(_ value: String) throws -> StatementDate {
        let parts = value.split(whereSeparator: { $0 == "/" || $0 == "-" })
        guard parts.count == 3, let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]) else {
            throw StatementDate.Error.malformedAxisDate(value)
        }
        return try StatementDate(year: year < 100 ? 2000 + year : year, month: month, day: day)
    }

    private static func money(_ value: String) -> String? {
        let stripped = value.replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: "INR", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.range(of: #"^[0-9]+\.[0-9]{2}$"#, options: .regularExpression) != nil else { return nil }
        return stripped
    }

    private static func effect(_ value: String) -> String? {
        switch value.lowercased() {
        case "debit", "dr": return CardLiabilityEffect.increasesAmountOwed.rawValue
        case "credit", "cr": return CardLiabilityEffect.decreasesAmountOwed.rawValue
        default: return nil
        }
    }
}
