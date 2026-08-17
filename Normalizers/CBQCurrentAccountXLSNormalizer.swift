import Foundation

enum CBQCurrentAccountXLSNormalizationError: Error, Equatable, LocalizedError {
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
    case malformedDate(sourceOrdinal: Int)
    case malformedAmount(sourceOrdinal: Int)
    case missingBalance(sourceOrdinal: Int)
    case malformedBalance(sourceOrdinal: Int)
    case unsupportedTrailingRow(sourceOrdinal: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocumentContent:
            return "The CBQ current-account XLS normalizer requires bounded tabular content."
        case .unsupportedWorksheet:
            return "The CBQ current-account XLS workbook must contain the visible worksheet Sheet1."
        case .unexpectedColumnCount:
            return "The CBQ current-account XLS workbook must contain exactly seven physical columns."
        case .malformedPhysicalGrid(let sourceOrdinal):
            return "CBQ current-account XLS row \(sourceOrdinal) has an invalid physical cell grid."
        case .missingHeader:
            return "The exact CBQ current-account XLS header is missing."
        case .duplicateHeader:
            return "The CBQ current-account XLS header is duplicated or ambiguous."
        case .changedHeader(let sourceOrdinal):
            return "CBQ current-account XLS header row \(sourceOrdinal) does not match the approved structure."
        case .malformedPreamble(let sourceOrdinal):
            return "CBQ current-account XLS preamble row \(sourceOrdinal) is outside the retained grammar."
        case .noTransactions:
            return "The CBQ current-account XLS statement contains no supported transaction rows."
        case .malformedTransaction(let sourceOrdinal):
            return "CBQ current-account XLS transaction row \(sourceOrdinal) is malformed."
        case .malformedDate(let sourceOrdinal):
            return "CBQ current-account XLS transaction row \(sourceOrdinal) contains a malformed date."
        case .malformedAmount(let sourceOrdinal):
            return "CBQ current-account XLS transaction row \(sourceOrdinal) contains a malformed signed amount."
        case .missingBalance(let sourceOrdinal):
            return "CBQ current-account XLS transaction row \(sourceOrdinal) has no printed balance."
        case .malformedBalance(let sourceOrdinal):
            return "CBQ current-account XLS transaction row \(sourceOrdinal) contains a malformed printed balance."
        case .unsupportedTrailingRow(let sourceOrdinal):
            return "CBQ current-account XLS row \(sourceOrdinal) is unsupported trailing content."
        }
    }
}

struct CBQCurrentAccountXLSNormalizationResult {
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow
    let sourceContext: NormalizedDocument.SourceContext
}

final class CBQCurrentAccountXLSNormalizer {
    static let logicalHeader = ["Date", "Details", "Amount", "", "", "", "Balance"]

    private static let headerSourceRow = 7
    private static let firstTransactionSourceRow = 8
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func normalize(rawDocument: RawDocument) throws -> CBQCurrentAccountXLSNormalizationResult {
        guard case .tabular(let sheet) = rawDocument.content else {
            throw CBQCurrentAccountXLSNormalizationError.unsupportedDocumentContent
        }
        guard sheet.visibility == .visible, sheet.name == "Sheet1" else {
            throw CBQCurrentAccountXLSNormalizationError.unsupportedWorksheet
        }
        guard sheet.columnCount == Self.logicalHeader.count else {
            throw CBQCurrentAccountXLSNormalizationError.unexpectedColumnCount(sheet.columnCount)
        }
        try validatePhysicalGrid(sheet)

        let exactHeaders = sheet.rows.filter { Self.isExactHeader($0) }
        guard exactHeaders.count == 1, let headerRow = exactHeaders.first else {
            if exactHeaders.count > 1 {
                throw CBQCurrentAccountXLSNormalizationError.duplicateHeader
            }
            if let nearHeader = sheet.rows.first(where: { Self.looksLikeHeader($0) }) {
                throw CBQCurrentAccountXLSNormalizationError.changedHeader(
                    sourceOrdinal: nearHeader.sourceRow
                )
            }
            throw CBQCurrentAccountXLSNormalizationError.missingHeader
        }
        guard headerRow.sourceRow == Self.headerSourceRow else {
            throw CBQCurrentAccountXLSNormalizationError.changedHeader(
                sourceOrdinal: headerRow.sourceRow
            )
        }

        try validatePreamble(sheet)
        let rows = try normalizedTransactions(sheet)
        guard !rows.isEmpty else {
            throw CBQCurrentAccountXLSNormalizationError.noTransactions
        }

        var document = Document(
            filename: rawDocument.fileName,
            url: rawDocument.sourceURL,
            fileType: FileFormat.xls.rawValue,
            importedAt: now()
        )
        document.rowCount = sheet.rows.count
        document.headerRow = headerRow.sourceRow
        document.firstTransactionRow = rows.first?.rowNumber
        document.columnCount = sheet.columnCount
        document.encoding = "UTF-8"

        let preamble = sheet.rows
            .filter { $0.sourceRow < headerRow.sourceRow && !Self.isEmpty($0) }
            .map { Self.sourceFragment($0) }

        return CBQCurrentAccountXLSNormalizationResult(
            document: document,
            rows: rows,
            header: NormalizedRow(rowNumber: headerRow.sourceRow, values: Self.logicalHeader),
            sourceContext: NormalizedDocument.SourceContext(
                preTransactionFragments: preamble,
                postTransactionFragments: []
            )
        )
    }

    private func validatePhysicalGrid(_ sheet: RawTabularSheet) throws {
        for (index, row) in sheet.rows.enumerated() {
            guard row.sourceRow == index + 1,
                  row.cells.count == Self.logicalHeader.count,
                  row.cells.enumerated().allSatisfy({ offset, cell in
                      cell.sourceRow == row.sourceRow && cell.sourceColumn == offset + 1
                  }) else {
                throw CBQCurrentAccountXLSNormalizationError.malformedPhysicalGrid(
                    sourceOrdinal: row.sourceRow
                )
            }
        }
    }

    private func validatePreamble(_ sheet: RawTabularSheet) throws {
        guard sheet.rows.count >= Self.firstTransactionSourceRow else {
            throw CBQCurrentAccountXLSNormalizationError.malformedPreamble(sourceOrdinal: 1)
        }
        let expectedOccupancy: [[Int]] = [[], [1], [], [1], [1], []]
        for (offset, expected) in expectedOccupancy.enumerated() {
            let row = sheet.rows[offset]
            guard Self.occupiedColumns(row) == expected else {
                throw CBQCurrentAccountXLSNormalizationError.malformedPreamble(
                    sourceOrdinal: row.sourceRow
                )
            }
        }
        guard Self.text(sheet.rows[1].cells[0].value) == "Transaction History" else {
            throw CBQCurrentAccountXLSNormalizationError.malformedPreamble(sourceOrdinal: 2)
        }
        let account = Self.text(sheet.rows[3].cells[0].value)
        guard Self.matches(account, #"^[0-9]{13}$"#) else {
            throw CBQCurrentAccountXLSNormalizationError.malformedPreamble(sourceOrdinal: 4)
        }
        let productAndHolder = Self.boundedWhitespace(
            Self.text(sheet.rows[4].cells[0].value)
        )
        guard Self.matches(productAndHolder, #"^CURRENT ACCOUNT-RETAIL\s+\S.*$"#) else {
            throw CBQCurrentAccountXLSNormalizationError.malformedPreamble(sourceOrdinal: 5)
        }
    }

    private func normalizedTransactions(_ sheet: RawTabularSheet) throws -> [NormalizedRow] {
        var result: [NormalizedRow] = []
        for sourceRow in Self.firstTransactionSourceRow...sheet.rows.count {
            let row = sheet.rows[sourceRow - 1]
            if Self.isEmpty(row) {
                throw CBQCurrentAccountXLSNormalizationError.unsupportedTrailingRow(
                    sourceOrdinal: sourceRow
                )
            }
            let values = row.cells.map { Self.text($0.value) }
            if !result.isEmpty,
               Self.occupiedColumns(row) == [1],
               !Self.matches(values[0], #"^[0-9]{2}/[0-9]{2}/[0-9]{4}$"#) {
                throw CBQCurrentAccountXLSNormalizationError.unsupportedTrailingRow(
                    sourceOrdinal: sourceRow
                )
            }
            guard values.count == Self.logicalHeader.count,
                  values[3...5].allSatisfy({ $0.isEmpty }),
                  !Self.boundedWhitespace(values[1]).isEmpty else {
                throw CBQCurrentAccountXLSNormalizationError.malformedTransaction(
                    sourceOrdinal: sourceRow
                )
            }
            guard Self.matches(values[0], #"^[0-9]{2}/[0-9]{2}/[0-9]{4}$"#) else {
                throw CBQCurrentAccountXLSNormalizationError.malformedDate(
                    sourceOrdinal: sourceRow
                )
            }
            guard Self.isDecimalLexeme(values[2]) else {
                throw CBQCurrentAccountXLSNormalizationError.malformedAmount(
                    sourceOrdinal: sourceRow
                )
            }
            guard !values[6].isEmpty else {
                throw CBQCurrentAccountXLSNormalizationError.missingBalance(
                    sourceOrdinal: sourceRow
                )
            }
            guard Self.isDecimalLexeme(values[6]) else {
                throw CBQCurrentAccountXLSNormalizationError.malformedBalance(
                    sourceOrdinal: sourceRow
                )
            }
            var normalized = values
            normalized[1] = Self.boundedWhitespace(values[1])
            result.append(NormalizedRow(rowNumber: sourceRow, values: normalized))
        }
        return result
    }

    private static func isExactHeader(_ row: RawTabularRow) -> Bool {
        row.cells.map { text($0.value) } == logicalHeader
    }

    private static func looksLikeHeader(_ row: RawTabularRow) -> Bool {
        let values = row.cells.map { text($0.value).lowercased() }
        return ["date", "details", "amount", "balance"].filter(values.contains).count >= 2
    }

    private static func isDecimalLexeme(_ value: String) -> Bool {
        matches(value, #"^-?(?:0|[1-9][0-9]*)(?:\.[0-9]{1,2})?$"#)
            && Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) != nil
    }

    private static func occupiedColumns(_ row: RawTabularRow) -> [Int] {
        row.cells.filter { !text($0.value).isEmpty }.map(\.sourceColumn)
    }

    private static func isEmpty(_ row: RawTabularRow) -> Bool {
        occupiedColumns(row).isEmpty
    }

    private static func sourceFragment(_ row: RawTabularRow) -> NormalizedDocument.SourceFragment {
        NormalizedDocument.SourceFragment(
            sourceOrdinal: row.sourceRow,
            text: row.cells.map { text($0.value) }.joined(separator: "\t")
        )
    }

    private static func text(_ value: RawTabularCellValue) -> String {
        value.canonicalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func boundedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) == value.startIndex..<value.endIndex
    }
}
