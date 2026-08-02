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
            return "The HDFC XLS workbook must contain the visible worksheet Sheet 1."
        case .unexpectedColumnCount:
            return "The HDFC XLS workbook must contain exactly seven logical columns."
        case .malformedPhysicalGrid(let sourceOrdinal):
            return "HDFC XLS row \(sourceOrdinal) has an invalid physical cell grid."
        case .missingHeader:
            return "The exact HDFC XLS header is missing."
        case .duplicateHeader:
            return "The HDFC XLS header is duplicated or ambiguous."
        case .changedHeader(let sourceOrdinal):
            return "HDFC XLS header row \(sourceOrdinal) does not match the approved column order."
        case .malformedPreamble(let sourceOrdinal):
            return "HDFC XLS preamble row \(sourceOrdinal) is outside the retained grammar."
        case .noTransactions:
            return "The HDFC XLS statement contains no supported transaction rows."
        case .malformedTransaction(let sourceOrdinal):
            return "HDFC XLS transaction row \(sourceOrdinal) is malformed."
        case .malformedSummary(let sourceOrdinal):
            return "HDFC XLS summary row \(sourceOrdinal) is malformed."
        case .unsupportedTrailingRow(let sourceOrdinal):
            return "HDFC XLS row \(sourceOrdinal) is outside the retained grammar."
        }
    }
}

struct HDFCBankAccountXLSNormalizationResult {
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow
    let sourceContext: NormalizedDocument.SourceContext
}

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

    private static let headerSourceRow = 21
    private static let firstTransactionSourceRow = 23
    private static let columnSeparatorLengths = [8, 34, 12, 8, 18, 18, 18]
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func normalize(rawDocument: RawDocument) throws -> HDFCBankAccountXLSNormalizationResult {
        guard case .tabular(let sheet) = rawDocument.content else {
            throw HDFCBankAccountXLSNormalizationError.unsupportedDocumentContent
        }
        guard sheet.visibility == .visible, sheet.name == "Sheet 1" else {
            throw HDFCBankAccountXLSNormalizationError.unsupportedWorksheet
        }
        guard sheet.columnCount == Self.logicalHeader.count else {
            throw HDFCBankAccountXLSNormalizationError.unexpectedColumnCount(sheet.columnCount)
        }
        for (index, row) in sheet.rows.enumerated() {
            guard row.sourceRow == index + 1,
                  row.cells.count == Self.logicalHeader.count,
                  row.cells.enumerated().allSatisfy({ offset, cell in
                      cell.sourceRow == row.sourceRow && cell.sourceColumn == offset + 1
                  }) else {
                throw HDFCBankAccountXLSNormalizationError.malformedPhysicalGrid(
                    sourceOrdinal: row.sourceRow
                )
            }
        }

        let exactHeaders = sheet.rows.filter { Self.isExactHeader($0) }
        guard exactHeaders.count == 1, let headerRow = exactHeaders.first else {
            if exactHeaders.count > 1 {
                throw HDFCBankAccountXLSNormalizationError.duplicateHeader
            }
            if let nearHeader = sheet.rows.first(where: { Self.looksLikeHeader($0) }) {
                throw HDFCBankAccountXLSNormalizationError.changedHeader(
                    sourceOrdinal: nearHeader.sourceRow
                )
            }
            throw HDFCBankAccountXLSNormalizationError.missingHeader
        }
        guard headerRow.sourceRow == Self.headerSourceRow else {
            throw HDFCBankAccountXLSNormalizationError.changedHeader(
                sourceOrdinal: headerRow.sourceRow
            )
        }

        try validatePreamble(in: sheet)
        let transactionRows = try normalizedTransactions(in: sheet)
        guard !transactionRows.isEmpty else {
            throw HDFCBankAccountXLSNormalizationError.noTransactions
        }
        let lastTransactionSourceRow = transactionRows[transactionRows.count - 1].rowNumber
        try validateTrailingGrammar(
            in: sheet,
            lastTransactionSourceRow: lastTransactionSourceRow
        )

        var document = Document(
            filename: rawDocument.fileName,
            url: rawDocument.sourceURL,
            fileType: FileFormat.xls.rawValue,
            importedAt: now()
        )
        document.rowCount = sheet.rows.count
        document.headerRow = headerRow.sourceRow
        document.firstTransactionRow = transactionRows.first?.rowNumber
        document.columnCount = sheet.columnCount
        document.encoding = "UTF-8"

        let preamble = sheet.rows
            .filter { $0.sourceRow < headerRow.sourceRow }
            .filter { !Self.isEmpty($0) && !Self.isFullSeparator($0, length: 188) }
            .map { Self.sourceFragment($0) }
        let postamble = sheet.rows
            .filter { $0.sourceRow > lastTransactionSourceRow }
            .filter { !Self.isEmpty($0) }
            .map { Self.sourceFragment($0) }

        return HDFCBankAccountXLSNormalizationResult(
            document: document,
            rows: transactionRows,
            header: NormalizedRow(
                rowNumber: headerRow.sourceRow,
                values: Self.logicalHeader
            ),
            sourceContext: NormalizedDocument.SourceContext(
                preTransactionFragments: preamble,
                postTransactionFragments: postamble
            )
        )
    }

    private func validatePreamble(in sheet: RawTabularSheet) throws {
        guard sheet.rows.count >= Self.firstTransactionSourceRow else {
            throw HDFCBankAccountXLSNormalizationError.malformedPreamble(sourceOrdinal: 1)
        }
        let exactOccupancy: [Int: [Int]] = [
            1: [1], 2: [], 3: [], 4: [], 5: [5], 6: [1, 5], 7: [1, 5],
            8: [1, 5], 9: [1, 5], 10: [1, 5], 11: [5], 12: [5],
            13: [1, 5], 14: [5], 15: [1, 5], 16: [1, 5], 17: [5],
            18: [5], 19: []
        ]
        for (sourceRow, expected) in exactOccupancy {
            let row = sheet.rows[sourceRow - 1]
            guard Self.occupiedColumns(row) == expected else {
                throw HDFCBankAccountXLSNormalizationError.malformedPreamble(
                    sourceOrdinal: sourceRow
                )
            }
        }

        let exactChecks: [(Int, Int, String)] = [
            (5, 5, #"^Account Branch\s*:.+$"#),
            (6, 5, #"^Address\s*:.*HDFC BANK.*$"#),
            (9, 5, #"^City\s*:.+$"#),
            (10, 5, #"^State\s*:.+$"#),
            (11, 5, #"^Phone no\.\s*:.+$"#),
            (12, 5, #"^Email\s*:.*$"#),
            (13, 1, #"^JOINT HOLDERS\s*:.*$"#),
            (13, 5, #"^OD Limit\s*:[0-9,.]+\s+Currency\s*:\s*INR$"#),
            (14, 5, #"^Cust ID\s*:\s*[0-9]{9}$"#),
            (15, 1, #"^Nomination\s*:\s*(?:Not )?Registered$"#),
            (15, 5, #"^Account No\s*:\s*[0-9]{14}\s+NR Others$"#),
            (16, 1, #"^Statement From\s*:\s*[0-9]{2}/[0-9]{2}/[0-9]{4}\s+To\s*:\s*[0-9]{2}/[0-9]{2}/[0-9]{4}$"#),
            (16, 5, #"^A/C Open Date\s*:\s*[0-9]{2}/[0-9]{2}/[0-9]{4}$"#),
            (17, 5, #"^Account Status\s*:.+$"#),
            (18, 5, #"^RTGS/NEFT IFSC\s*:\s*HDFC[0-9A-Z]+\s+MICR\s*:\s*[0-9]+$"#)
        ]
        let branding = Self.text(sheet.rows[0].cells[0].value)
        guard Self.matches(
            branding,
            #"^HDFC BANK Ltd\.\s+Page No \.\s*:\s*[0-9]+\s+Statement of accounts$"#
        ) else {
            throw HDFCBankAccountXLSNormalizationError.malformedPreamble(sourceOrdinal: 1)
        }
        for (sourceRow, sourceColumn, pattern) in exactChecks {
            let value = Self.text(sheet.rows[sourceRow - 1].cells[sourceColumn - 1].value)
            guard Self.matches(value, pattern) else {
                throw HDFCBankAccountXLSNormalizationError.malformedPreamble(
                    sourceOrdinal: sourceRow
                )
            }
        }
        guard Self.isFullSeparator(sheet.rows[19], length: 188),
              Self.isColumnSeparator(sheet.rows[21]) else {
            throw HDFCBankAccountXLSNormalizationError.malformedPreamble(sourceOrdinal: 20)
        }
    }

    private func normalizedTransactions(in sheet: RawTabularSheet) throws -> [NormalizedRow] {
        var result: [NormalizedRow] = []
        var sourceRow = Self.firstTransactionSourceRow
        while sourceRow <= sheet.rows.count {
            let row = sheet.rows[sourceRow - 1]
            if Self.isEmpty(row) { break }
            let values = row.cells.map { Self.text($0.value) }
            guard values.count == Self.logicalHeader.count,
                  Self.matches(values[0], #"^[0-9]{2}/[0-9]{2}/[0-9]{2}$"#),
                  !Self.boundedWhitespace(values[1]).isEmpty,
                  !values[3].isEmpty,
                  !values[6].isEmpty else {
                throw HDFCBankAccountXLSNormalizationError.malformedTransaction(
                    sourceOrdinal: sourceRow
                )
            }
            var normalizedValues = values
            normalizedValues[1] = Self.boundedWhitespace(values[1])
            result.append(NormalizedRow(rowNumber: sourceRow, values: normalizedValues))
            sourceRow += 1
        }
        return result
    }

    private func validateTrailingGrammar(
        in sheet: RawTabularSheet,
        lastTransactionSourceRow: Int
    ) throws {
        guard sheet.rows.count == lastTransactionSourceRow + 26 else {
            throw HDFCBankAccountXLSNormalizationError.unsupportedTrailingRow(
                sourceOrdinal: min(lastTransactionSourceRow + 1, sheet.rows.count)
            )
        }
        let row: (Int) -> RawTabularRow = { sheet.rows[lastTransactionSourceRow + $0 - 1] }
        guard Self.isEmpty(row(1)),
              Self.isColumnSeparator(row(2)),
              Self.isFullSeparator(row(3), length: 129),
              Self.isEmpty(row(4)) else {
            throw HDFCBankAccountXLSNormalizationError.malformedSummary(
                sourceOrdinal: lastTransactionSourceRow + 1
            )
        }

        let summaryStart = lastTransactionSourceRow + 5
        let expectedPublicRows: [(Int, [String])] = [
            (0, ["STATEMENT SUMMARY  :-", "", "", "", "", "", ""]),
            (1, ["Opening Balance", "", "", "", "Debits", "Credits", "Closing Bal"]),
            (4, ["", "", "", "", "Dr Count", "Cr Count", ""]),
            (13, ["This is a computer generated statement and does not require signature.", "", "", "", "", "", ""]),
            (14, ["HDFC BANK LIMITED.", "", "", "", "", "", ""]),
            (15, ["*Closing balance includes funds earmarked for hold and uncleared funds", "", "", "", "", "", ""]),
            (21, ["---  End Of Statement ---", "", "", "", "", "", ""])
        ]
        for (offset, expected) in expectedPublicRows {
            guard Self.values(row(offset + 5)) == expected else {
                throw HDFCBankAccountXLSNormalizationError.malformedSummary(
                    sourceOrdinal: summaryStart + offset
                )
            }
        }
        let emptyOffsets = [3, 6, 7, 9, 10, 11, 12, 17]
        for offset in emptyOffsets where !Self.isEmpty(row(offset + 5)) {
            throw HDFCBankAccountXLSNormalizationError.malformedSummary(
                sourceOrdinal: summaryStart + offset
            )
        }
        guard Self.occupiedColumns(row(7)) == [1, 5, 6, 7],
              Self.occupiedColumns(row(10)) == [5, 6],
              Self.occupiedColumns(row(13)) == [1, 2, 3, 4, 5, 6],
              Self.matches(Self.values(row(13))[0], #"^Generated On:$"#),
              Self.matches(Self.values(row(13))[2], #"^Generated By:$"#),
              Self.matches(Self.values(row(13))[4], #"^Requesting Branch Code:$"#),
              Self.values(row(13))[5] == "NET",
              Self.occupiedColumns(row(23)) == [1, 2],
              Self.text(row(23).cells[0].value) == "State account branch GSTN:",
              Self.occupiedColumns(row(24)) == [1],
              Self.text(row(24).cells[0].value).contains("HDFC Bank GSTIN number details"),
              Self.occupiedColumns(row(25)) == [1],
              Self.text(row(25).cells[0].value).hasPrefix("Registered Office Address: HDFC Bank House") else {
            throw HDFCBankAccountXLSNormalizationError.malformedSummary(
                sourceOrdinal: summaryStart
            )
        }
    }

    private static func isExactHeader(_ row: RawTabularRow) -> Bool {
        row.cells.map(\.value.canonicalText) == logicalHeader
    }

    private static func looksLikeHeader(_ row: RawTabularRow) -> Bool {
        let expected = Set(logicalHeader.map { $0.uppercased() })
        return values(row).map { $0.uppercased() }.filter(expected.contains).count >= 4
    }

    private static func values(_ row: RawTabularRow) -> [String] {
        row.cells.map { text($0.value) }
    }

    private static func text(_ value: RawTabularCellValue) -> String {
        value.canonicalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func boundedWhitespace(_ value: String) -> String {
        value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func isEmpty(_ row: RawTabularRow) -> Bool {
        values(row).allSatisfy(\.isEmpty)
    }

    private static func occupiedColumns(_ row: RawTabularRow) -> [Int] {
        row.cells.compactMap { text($0.value).isEmpty ? nil : $0.sourceColumn }
    }

    private static func isFullSeparator(_ row: RawTabularRow, length: Int) -> Bool {
        let rowValues = values(row)
        return rowValues[0] == String(repeating: "*", count: length)
            && rowValues.dropFirst().allSatisfy(\.isEmpty)
    }

    private static func isColumnSeparator(_ row: RawTabularRow) -> Bool {
        zip(values(row), columnSeparatorLengths).allSatisfy { value, length in
            value == String(repeating: "*", count: length)
        }
    }

    private static func sourceFragment(_ row: RawTabularRow) -> NormalizedDocument.SourceFragment {
        NormalizedDocument.SourceFragment(
            sourceOrdinal: row.sourceRow,
            text: values(row).joined(separator: "\t")
        )
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
}
