import Foundation
import PDFKit

enum HDFCBankAccountPDFNormalizationError: Error, Equatable, LocalizedError {
    case unsupportedDocumentContent
    case lockedDocument
    case unsupportedNativeText
    case missingTitle
    case missingHeader
    case changedHeader
    case malformedPreamble
    case noTransactions
    case incompleteTransaction(sourceOrdinal: Int)
    case missingOrAmbiguousAmount(sourceOrdinal: Int)
    case malformedSummary
    case unconsumedFinancialContent(sourceOrdinal: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocumentContent: return "The HDFC PDF normalizer requires immutable PDF source content."
        case .lockedDocument: return "Locked HDFC PDFs are outside the supported profile."
        case .unsupportedNativeText: return "The HDFC PDF must contain native selectable text."
        case .missingTitle: return "The exact HDFC statement title is missing."
        case .missingHeader: return "The exact HDFC PDF transaction header is missing."
        case .changedHeader: return "The HDFC PDF transaction columns do not match the retained order."
        case .malformedPreamble: return "The HDFC PDF pre-transaction evidence is incomplete or ambiguous."
        case .noTransactions: return "The HDFC PDF contains no supported transaction rows."
        case .incompleteTransaction(let ordinal): return "HDFC PDF transaction at source position \(ordinal) is incomplete."
        case .missingOrAmbiguousAmount(let ordinal): return "HDFC PDF transaction at source position \(ordinal) must have exactly one amount side."
        case .malformedSummary: return "The HDFC PDF printed statement summary is incomplete or ambiguous."
        case .unconsumedFinancialContent(let ordinal): return "HDFC PDF financial content at source position \(ordinal) was not consumed by the retained grammar."
        }
    }
}

struct HDFCBankAccountPDFNormalizationResult {
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow
    let sourceContext: NormalizedDocument.SourceContext
}

final class HDFCBankAccountPDFNormalizer {
    private struct VisualLine {
        let pageIndex: Int
        let lineIndex: Int
        let visualRow: Int
        let text: String
        let bounds: CGRect

        var sourceOrdinal: Int { pageIndex * 100_000 + lineIndex + 1 }
    }

    private struct PageEvidence {
        let pageIndex: Int
        let lines: [VisualLine]
        let columnBoundaries: [CGFloat]
        let headerY: CGFloat
        let summaryY: CGFloat?
        let pageFloorY: CGFloat
    }

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func normalize(
        text: String,
        sourceBytes: Data,
        fileURL: URL
    ) throws -> HDFCBankAccountPDFNormalizationResult {
        guard let pdf = PDFDocument(data: sourceBytes), pdf.pageCount > 0 else {
            throw HDFCBankAccountPDFNormalizationError.unsupportedNativeText
        }
        guard !pdf.isLocked else { throw HDFCBankAccountPDFNormalizationError.lockedDocument }
        let normalizedText = Self.boundedWhitespace(text)
        guard normalizedText.localizedCaseInsensitiveContains("HDFC BANK LIMITED"),
              normalizedText.localizedCaseInsensitiveContains("STATEMENT OF ACCOUNT") else {
            throw HDFCBankAccountPDFNormalizationError.missingTitle
        }

        let account = try Self.uniqueCapture(#"\bAccount No\s*:\s*([0-9]{14})\s+NR Others\b"#, in: normalizedText)
        let customer = try Self.uniqueCapture(#"\bCust ID\s*:\s*([0-9]{9})\b"#, in: normalizedText)
        let period = try Self.uniqueCaptures(#"\bStatement From\s*:\s*([0-9]{2}/[0-9]{2}/[0-9]{4})\s+To\s*:\s*([0-9]{2}/[0-9]{2}/[0-9]{4})\b"#, in: normalizedText)
        let currency = try Self.uniqueCapture(#"\bOD Limit\s*:\s*[0-9,.]+\s+Currency\s*:\s*([A-Z]{3})\b"#, in: normalizedText)
        guard !account.isEmpty, !customer.isEmpty, period.count == 2, currency == "INR" else {
            throw HDFCBankAccountPDFNormalizationError.malformedPreamble
        }

        var pages: [PageEvidence] = []
        var retainedColumnBoundaries: [CGFloat]?
        for pageIndex in 0..<pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else {
                throw HDFCBankAccountPDFNormalizationError.unsupportedNativeText
            }
            let lines = Self.visualTokens(page: page, pageIndex: pageIndex)
            guard !lines.isEmpty else {
                throw HDFCBankAccountPDFNormalizationError.unsupportedNativeText
            }
            let grouped = Dictionary(grouping: lines, by: \.visualRow)
            let exactHeaders = grouped.values.filter { group in
                let ordered = group.sorted { $0.bounds.minX < $1.bounds.minX }.map(\.text)
                return ordered == HDFCBankAccountXLSNormalizer.logicalHeader ||
                    ordered.joined(separator: " ") == HDFCBankAccountXLSNormalizer.logicalHeader.joined(separator: " ")
            }
            guard exactHeaders.count <= 1 else {
                throw HDFCBankAccountPDFNormalizationError.changedHeader
            }
            let headerY: CGFloat
            let columnBoundaries: [CGFloat]
            if let header = exactHeaders.first {
                headerY = header[0].bounds.minY
                let headerTokens = header.sorted { $0.bounds.minX < $1.bounds.minX }
                let starts = ["Date", "Narration", "Chq./Ref.No.", "Value", "Withdrawal", "Deposit", "Closing"].compactMap { label in
                    headerTokens.first(where: { $0.text == label })?.bounds.minX
                }
                guard starts.count == 7, starts == starts.sorted() else {
                    throw HDFCBankAccountPDFNormalizationError.changedHeader
                }
                columnBoundaries = [
                    (starts[0] + starts[1]) / 2,
                    starts[1] + (starts[2] - starts[1]) * 0.8,
                    starts[3] - 1,
                    starts[4] - 1,
                    starts[5] - 1,
                    starts[6] - 1
                ]
                if let retainedColumnBoundaries,
                   zip(retainedColumnBoundaries, columnBoundaries).contains(where: { abs($0.0 - $0.1) > 2 }) {
                    throw HDFCBankAccountPDFNormalizationError.changedHeader
                }
                retainedColumnBoundaries = columnBoundaries
            } else {
                let headerWords = Set(lines.flatMap { $0.text.split(separator: " ").map(String.init) })
                let retainedHeaderEvidence = ["Date", "Narration", "Chq./Ref.No.", "Value", "Withdrawal", "Deposit", "Closing"]
                    .filter(headerWords.contains)
                    .count
                if retainedHeaderEvidence >= 3 {
                    throw HDFCBankAccountPDFNormalizationError.changedHeader
                }
                guard pageIndex > 0 else {
                    throw HDFCBankAccountPDFNormalizationError.missingHeader
                }
                guard let retainedColumnBoundaries else {
                    throw HDFCBankAccountPDFNormalizationError.missingHeader
                }
                columnBoundaries = retainedColumnBoundaries
                headerY = page.bounds(for: .mediaBox).maxY
            }
            let summaryRows = grouped.values.filter {
                let value = Self.rowText($0)
                return value == "STATEMENT SUMMARY :-" || value == "STATEMENT SUMMARY  :-"
            }
            guard summaryRows.count <= 1 else { throw HDFCBankAccountPDFNormalizationError.malformedSummary }
            pages.append(PageEvidence(
                pageIndex: pageIndex,
                lines: lines,
                columnBoundaries: columnBoundaries,
                headerY: headerY,
                summaryY: summaryRows.first?.map(\.bounds.minY).min(),
                pageFloorY: page.bounds(for: .mediaBox).minY + 45
            ))
        }

        var rows: [NormalizedRow] = []
        var consumedFinancialOrdinals = Set<Int>()
        for page in pages {
            let boundaries = page.columnBoundaries
            let starts = page.lines.filter {
                $0.bounds.minX < boundaries[0] && Self.matches($0.text, #"^[0-9]{2}/[0-9]{2}/[0-9]{2}$"#) &&
                $0.bounds.minY < page.headerY - 4 &&
                $0.bounds.minY > (page.summaryY ?? page.pageFloorY)
            }.sorted { $0.bounds.minY > $1.bounds.minY }
            for (index, start) in starts.enumerated() {
                let lowerY = index + 1 < starts.count
                    ? starts[index + 1].bounds.minY + 1
                    : (page.summaryY ?? page.pageFloorY) + 1
                let block = page.lines.filter {
                    $0.bounds.minY <= start.bounds.minY + 1 && $0.bounds.minY >= lowerY
                }
                func column(_ range: Range<CGFloat>) -> [VisualLine] {
                    block.filter { range.contains($0.bounds.minX) }.sorted {
                        if $0.bounds.minY != $1.bounds.minY { return $0.bounds.minY > $1.bounds.minY }
                        return $0.bounds.minX < $1.bounds.minX
                    }
                }
                let leadingColumn = column(0..<boundaries[0])
                let dates = leadingColumn.filter { Self.matches($0.text, #"^[0-9]{2}/[0-9]{2}/[0-9]{2}$"#) }
                let leadingNarrations = leadingColumn.filter { !Self.matches($0.text, #"^[0-9]{2}/[0-9]{2}/[0-9]{2}$"#) }
                let narrations = (leadingNarrations + column(boundaries[0]..<boundaries[1])).sorted {
                    if $0.bounds.minY != $1.bounds.minY { return $0.bounds.minY > $1.bounds.minY }
                    return $0.bounds.minX < $1.bounds.minX
                }
                let references = column(boundaries[1]..<boundaries[2])
                let valueDates = column(boundaries[2]..<boundaries[3])
                let withdrawals = column(boundaries[3]..<boundaries[4])
                let deposits = column(boundaries[4]..<boundaries[5])
                let balances = column(boundaries[5]..<10_000)
                guard dates.count == 1, dates[0].sourceOrdinal == start.sourceOrdinal,
                      !narrations.isEmpty, references.count <= 1,
                      valueDates.count == 1, withdrawals.count <= 1,
                      deposits.count <= 1, balances.count == 1,
                      Self.matches(valueDates[0].text, #"^[0-9]{2}/[0-9]{2}/[0-9]{2}$"#),
                      Self.matches(balances[0].text, Self.moneyPattern) else {
                    throw HDFCBankAccountPDFNormalizationError.incompleteTransaction(sourceOrdinal: start.sourceOrdinal)
                }
                guard leadingNarrations.allSatisfy({
                    !Self.matches($0.text, #"^[0-9]{2}/[0-9]{2}/[0-9]{2}$"#) &&
                    !Self.matches($0.text, Self.moneyPattern)
                }) else {
                    throw HDFCBankAccountPDFNormalizationError.unconsumedFinancialContent(sourceOrdinal: start.sourceOrdinal)
                }
                guard (withdrawals.count == 1) != (deposits.count == 1),
                      (withdrawals + deposits).allSatisfy({ Self.matches($0.text, Self.moneyPattern) }) else {
                    throw HDFCBankAccountPDFNormalizationError.missingOrAmbiguousAmount(sourceOrdinal: start.sourceOrdinal)
                }
                let narration = Self.boundedWhitespace(narrations.map(\.text).joined(separator: " "))
                guard !narration.isEmpty else {
                    throw HDFCBankAccountPDFNormalizationError.incompleteTransaction(sourceOrdinal: start.sourceOrdinal)
                }
                let rowLines = dates + narrations + references + valueDates + withdrawals + deposits + balances
                consumedFinancialOrdinals.formUnion(rowLines.map(\.sourceOrdinal))
                rows.append(NormalizedRow(
                    rowNumber: start.sourceOrdinal,
                    values: [
                        start.text,
                        narration,
                        references.first?.text ?? "",
                        valueDates[0].text,
                        withdrawals.first?.text ?? "",
                        deposits.first?.text ?? "",
                        balances[0].text
                    ]
                ))
            }
        }
        guard !rows.isEmpty else { throw HDFCBankAccountPDFNormalizationError.noTransactions }

        let summary = try summaryEvidence(in: pages)
        for page in pages {
            let transactionUpperY = page.lines.filter {
                $0.bounds.minX < page.columnBoundaries[0] &&
                    Self.matches($0.text, #"^[0-9]{2}/[0-9]{2}/[0-9]{2}$"#) &&
                    $0.bounds.minY < page.headerY - 4 &&
                    $0.bounds.minY > (page.summaryY ?? page.pageFloorY)
            }.map(\.bounds.minY).max() ?? -.infinity
            for line in page.lines where line.bounds.minY <= transactionUpperY + 1 && line.bounds.minY > (page.summaryY ?? page.pageFloorY) {
                if (Self.matches(line.text, #"^[0-9]{2}/[0-9]{2}/[0-9]{2}$"#) || Self.matches(line.text, Self.moneyPattern)),
                   !consumedFinancialOrdinals.contains(line.sourceOrdinal) {
                    throw HDFCBankAccountPDFNormalizationError.unconsumedFinancialContent(sourceOrdinal: line.sourceOrdinal)
                }
            }
        }

        var document = Document(
            filename: fileURL.lastPathComponent,
            url: fileURL,
            fileType: FileFormat.pdf.rawValue,
            importedAt: now()
        )
        document.rowCount = pages.reduce(0) { $0 + $1.lines.count }
        document.headerRow = pages[0].pageIndex * 100_000 + 1
        document.firstTransactionRow = rows.first?.rowNumber
        document.columnCount = HDFCBankAccountXLSNormalizer.logicalHeader.count
        document.encoding = "UTF-8"

        let preamble = [
            NormalizedDocument.SourceFragment(sourceOrdinal: 13, text: "\t\t\t\tOD Limit : 0 Currency : \(currency)\t\t"),
            NormalizedDocument.SourceFragment(sourceOrdinal: 14, text: "\t\t\t\tCust ID : \(customer)\t\t"),
            NormalizedDocument.SourceFragment(sourceOrdinal: 15, text: "\t\t\t\tAccount No : \(account) NR Others\t\t"),
            NormalizedDocument.SourceFragment(sourceOrdinal: 16, text: "Statement From : \(period[0]) To : \(period[1])\t\t\t\t\t\t")
        ]
        return HDFCBankAccountPDFNormalizationResult(
            document: document,
            rows: rows,
            header: NormalizedRow(rowNumber: document.headerRow ?? 1, values: HDFCBankAccountXLSNormalizer.logicalHeader),
            sourceContext: NormalizedDocument.SourceContext(
                preTransactionFragments: preamble,
                postTransactionFragments: summary
            )
        )
    }

    private func summaryEvidence(in pages: [PageEvidence]) throws -> [NormalizedDocument.SourceFragment] {
        let summaryPages = pages.filter { $0.summaryY != nil }
        guard summaryPages.count == 1, let page = summaryPages.first, let summaryY = page.summaryY else {
            throw HDFCBankAccountPDFNormalizationError.malformedSummary
        }
        let grouped = Dictionary(grouping: page.lines, by: \.visualRow)
        let labelRows = grouped.values.filter {
            ($0.map(\.bounds.minY).min() ?? summaryY) < summaryY &&
            Self.rowText($0) == "Opening Balance Dr Count Cr Count Debits Credits Closing Bal"
        }
        guard labelRows.count == 1, let labelY = labelRows[0].map(\.bounds.minY).min() else {
            throw HDFCBankAccountPDFNormalizationError.malformedSummary
        }
        let valueRows = grouped.values.compactMap { row -> [String]? in
            let rowY = row.map(\.bounds.minY).min() ?? 0
            guard rowY < labelY && rowY > labelY - 20 else { return nil }
            let values = Self.rowText(row).split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard values.count == 6,
                  Self.matches(values[0], Self.moneyPattern),
                  Int(values[1]) != nil, Int(values[2]) != nil,
                  Self.matches(values[3], Self.moneyPattern),
                  Self.matches(values[4], Self.moneyPattern),
                  Self.matches(values[5], Self.moneyPattern) else { return nil }
            return values
        }
        guard valueRows.count == 1, let values = valueRows.first else {
            throw HDFCBankAccountPDFNormalizationError.malformedSummary
        }
        let ordinal = page.pageIndex * 100_000 + 90_000
        return [
            .init(sourceOrdinal: ordinal, text: "STATEMENT SUMMARY  :-\t\t\t\t\t\t"),
            .init(sourceOrdinal: ordinal + 1, text: "Opening Balance\t\t\t\tDebits\tCredits\tClosing Bal"),
            .init(sourceOrdinal: ordinal + 2, text: "\(values[0])\t\t\t\t\(values[3])\t\(values[4])\t\(values[5])"),
            .init(sourceOrdinal: ordinal + 3, text: "\t\t\t\t\t\t"),
            .init(sourceOrdinal: ordinal + 4, text: "\t\t\t\tDr Count\tCr Count\t"),
            .init(sourceOrdinal: ordinal + 5, text: "\t\t\t\t\(values[1])\t\(values[2])\t")
        ]
    }

    private static func visualTokens(page: PDFPage, pageIndex: Int) -> [VisualLine] {
        guard let pageString = page.string, !pageString.isEmpty else { return [] }
        let content = pageString as NSString
        let expression = try? NSRegularExpression(pattern: #"\S+"#)
        let matches = expression?.matches(
            in: pageString,
            range: NSRange(location: 0, length: content.length)
        ) ?? []
        let positioned = matches.compactMap { match -> (text: String, bounds: CGRect)? in
            guard let selection = page.selection(for: match.range) else { return nil }
            let bounds = selection.bounds(for: page)
            guard !bounds.isNull, !bounds.isInfinite, bounds.width > 0, bounds.height > 0 else {
                return nil
            }
            return (content.substring(with: match.range), bounds)
        }

        var rows: [(midY: CGFloat, tokens: [(text: String, bounds: CGRect)])] = []
        for token in positioned {
            if let rowIndex = rows.indices.min(by: {
                abs(rows[$0].midY - token.bounds.midY) < abs(rows[$1].midY - token.bounds.midY)
            }), abs(rows[rowIndex].midY - token.bounds.midY) <= 3 {
                rows[rowIndex].tokens.append(token)
                let count = CGFloat(rows[rowIndex].tokens.count)
                rows[rowIndex].midY = ((rows[rowIndex].midY * (count - 1)) + token.bounds.midY) / count
            } else {
                rows.append((midY: token.bounds.midY, tokens: [token]))
            }
        }

        var tokenIndex = 0
        return rows.sorted(by: { $0.midY > $1.midY }).enumerated().flatMap { visualRow, row in
            row.tokens.sorted(by: { $0.bounds.minX < $1.bounds.minX }).map { token in
                tokenIndex += 1
                return VisualLine(
                    pageIndex: pageIndex,
                    lineIndex: tokenIndex,
                    visualRow: visualRow,
                    text: token.text,
                    bounds: token.bounds
                )
            }
        }
    }

    private static func rowText(_ lines: [VisualLine]) -> String {
        lines.sorted { $0.bounds.minX < $1.bounds.minX }.map(\.text).joined(separator: " ")
    }

    private static func uniqueCapture(_ pattern: String, in text: String) throws -> String {
        let values = try uniqueCaptures(pattern, in: text)
        guard values.count == 1 else { throw HDFCBankAccountPDFNormalizationError.malformedPreamble }
        return values[0]
    }

    private static func uniqueCaptures(_ pattern: String, in text: String) throws -> [String] {
        let expression = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let captures = matches.map { match in
            (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
        }
        guard let first = captures.first, captures.allSatisfy({ $0 == first }) else {
            throw HDFCBankAccountPDFNormalizationError.malformedPreamble
        }
        return first
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else { return false }
        return match.range == NSRange(value.startIndex..., in: value)
    }

    private static func boundedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static let moneyPattern = #"^[0-9]+(?:,[0-9]{3})*\.[0-9]{2}$"#
}
