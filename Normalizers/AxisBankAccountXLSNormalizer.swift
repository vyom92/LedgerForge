import Foundation

enum AxisBankAccountXLSNormalizationError: Error, Equatable, LocalizedError {
    case unsupportedDocumentContent
    case missingHeader
    case duplicateHeader
    case changedHeader(sourceOrdinal: Int)
    case noTransactions
    case malformedTransaction(sourceOrdinal: Int)
    case unsupportedTrailingRow(sourceOrdinal: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocumentContent:
            return "The Axis XLS normalizer requires bounded tabular content."
        case .missingHeader:
            return "The exact Axis XLS header is missing."
        case .duplicateHeader:
            return "The Axis XLS header is duplicated or ambiguous."
        case .changedHeader(let sourceOrdinal):
            return "Axis XLS header row \(sourceOrdinal) does not match the approved column order."
        case .noTransactions:
            return "The Axis XLS statement contains no supported transaction rows."
        case .malformedTransaction(let sourceOrdinal):
            return "Axis XLS transaction row \(sourceOrdinal) is malformed."
        case .unsupportedTrailingRow(let sourceOrdinal):
            return "Axis XLS row \(sourceOrdinal) is outside the supported layout."
        }
    }
}

struct AxisBankAccountXLSNormalizationResult {
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow
    let sourceContext: NormalizedDocument.SourceContext
}

final class AxisBankAccountXLSNormalizer {
    static let logicalHeader = [
        "Tran Date", "CHQNO", "PARTICULARS", "DR", "CR", "BAL", "SOL"
    ]

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func normalize(
        rawDocument: RawDocument
    ) throws -> AxisBankAccountXLSNormalizationResult {
        guard case .tabular(let sheet) = rawDocument.content,
              sheet.visibility == .visible else {
            throw AxisBankAccountXLSNormalizationError.unsupportedDocumentContent
        }

        let exactHeaders = sheet.rows.filter { Self.isExactHeader($0) }
        guard exactHeaders.count == 1, let headerRow = exactHeaders.first else {
            if exactHeaders.count > 1 {
                throw AxisBankAccountXLSNormalizationError.duplicateHeader
            }
            if let nearHeader = sheet.rows.first(where: { Self.looksLikeHeader($0) }) {
                throw AxisBankAccountXLSNormalizationError.changedHeader(
                    sourceOrdinal: nearHeader.sourceRow
                )
            }
            throw AxisBankAccountXLSNormalizationError.missingHeader
        }

        let logicalHeader = NormalizedRow(
            rowNumber: headerRow.sourceRow,
            values: Self.logicalHeader
        )
        let preTransactionFragments = sheet.rows
            .filter { $0.sourceRow < headerRow.sourceRow }
            .compactMap { row -> NormalizedDocument.SourceFragment? in
                let text = row.cells
                    .map { $0.value.canonicalText.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                guard !text.isEmpty else { return nil }
                return NormalizedDocument.SourceFragment(
                    sourceOrdinal: row.sourceRow,
                    text: text
                )
            }

        var normalizedRows: [NormalizedRow] = []
        var endedTransactions = false
        for row in sheet.rows where row.sourceRow > headerRow.sourceRow {
            let nonblank = row.cells.filter {
                !$0.value.canonicalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            if nonblank.isEmpty {
                if !normalizedRows.isEmpty { endedTransactions = true }
                continue
            }

            if endedTransactions {
                guard nonblank.allSatisfy({ $0.sourceColumn == 1 }) else {
                    throw AxisBankAccountXLSNormalizationError.unsupportedTrailingRow(
                        sourceOrdinal: row.sourceRow
                    )
                }
                continue
            }

            guard row.cells.count == 8,
                  Self.isSerial(row.cells[0].value),
                  Self.isDate(row.cells[1].value),
                  !Self.trimmed(row.cells[3].value).isEmpty else {
                throw AxisBankAccountXLSNormalizationError.malformedTransaction(
                    sourceOrdinal: row.sourceRow
                )
            }
            normalizedRows.append(
                NormalizedRow(
                    rowNumber: row.sourceRow,
                    values: row.cells.dropFirst().map { Self.trimmed($0.value) }
                )
            )
        }

        guard !normalizedRows.isEmpty else {
            throw AxisBankAccountXLSNormalizationError.noTransactions
        }

        var document = Document(
            filename: rawDocument.fileName,
            url: rawDocument.sourceURL,
            fileType: FileFormat.xls.rawValue,
            importedAt: now()
        )
        document.rowCount = sheet.rows.count
        document.headerRow = headerRow.sourceRow
        document.firstTransactionRow = normalizedRows.first?.rowNumber
        document.columnCount = sheet.columnCount
        document.encoding = "UTF-8"

        return AxisBankAccountXLSNormalizationResult(
            document: document,
            rows: normalizedRows,
            header: logicalHeader,
            sourceContext: NormalizedDocument.SourceContext(
                preTransactionFragments: preTransactionFragments
            )
        )
    }

    private static func isExactHeader(_ row: RawTabularRow) -> Bool {
        guard row.cells.count == 8,
              trimmed(row.cells[0].value).caseInsensitiveCompare("SRL NO") == .orderedSame else {
            return false
        }
        return Array(row.cells.dropFirst().map { trimmed($0.value) }) == logicalHeader
    }

    private static func looksLikeHeader(_ row: RawTabularRow) -> Bool {
        let tokens = row.cells.map { trimmed($0.value).uppercased() }
        let expected = Set(logicalHeader.map { $0.uppercased() })
        return tokens.filter { expected.contains($0) }.count >= 4
    }

    private static func isSerial(_ value: RawTabularCellValue) -> Bool {
        let text = trimmed(value)
        guard let serial = Int(text), serial > 0 else { return false }
        return String(serial) == text
    }

    private static func isDate(_ value: RawTabularCellValue) -> Bool {
        (try? StatementDate.axisNRE(trimmed(value))) != nil
    }

    private static func trimmed(_ value: RawTabularCellValue) -> String {
        value.canonicalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
