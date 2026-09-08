import Foundation
import CoreGraphics

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
        let headerOrdinal: Int?
        let summaryY: CGFloat?
        let pageFloorY: CGFloat
    }

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func normalize(
        text: String,
        pageEvidence: [RawPDFPageEvidence]?,
        fileURL: URL
    ) throws -> HDFCBankAccountPDFNormalizationResult {
        guard let pageEvidence, !pageEvidence.isEmpty else {
            throw HDFCBankAccountPDFNormalizationError.unsupportedNativeText
        }
        let normalizedText = Self.boundedWhitespace(text)
        guard normalizedText.localizedCaseInsensitiveContains("HDFC BANK LIMITED"),
              normalizedText.localizedCaseInsensitiveContains("STATEMENT OF ACCOUNT") else {
            throw HDFCBankAccountPDFNormalizationError.missingTitle
        }

        let account = try Self.uniqueCapture(#"\bAccount No\s*:\s*([0-9]{14})\s+NR Others\b"#, in: normalizedText)
        let customer = try Self.uniqueCapture(#"\bCust ID\s*:\s*([0-9]{9})\b"#, in: normalizedText)
        let period = try Self.uniqueCaptures(#"\bFrom\s*:\s*([0-9]{2}/[0-9]{2}/[0-9]{4})\s+To\s*:\s*([0-9]{2}/[0-9]{2}/[0-9]{4})\b"#, in: normalizedText)
        let currency = try Self.uniqueCapture(#"\bOD Limit\s*:\s*[0-9,.]+\s+Currency\s*:\s*([A-Z]{3})\b"#, in: normalizedText)
        guard !account.isEmpty, !customer.isEmpty, period.count == 2, currency == "INR" else {
            throw HDFCBankAccountPDFNormalizationError.malformedPreamble
        }

        var pages: [PageEvidence] = []
        var retainedColumnBoundaries: [CGFloat]?
        for (pageIndex, page) in pageEvidence.enumerated() {
            guard let pageBounds = page.bounds else {
                throw HDFCBankAccountPDFNormalizationError.unsupportedNativeText
            }
            let lines = try Self.visualTokens(page: page, pageIndex: pageIndex)
            // The reader retains physical page positions. A blank page is
            // inert packaging, not a separate financial-profile condition.
            if lines.isEmpty { continue }
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
                // Repeated semantic headers own their page's column geometry;
                // coordinates need not agree with the previous physical page.
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
                headerY = pageBounds.maxY
            }
            let summaryRows = grouped.values.filter {
                let value = Self.rowText($0)
                return value == "STATEMENT SUMMARY :-" || value == "STATEMENT SUMMARY  :-"
            }
            guard summaryRows.count <= 1 else { throw HDFCBankAccountPDFNormalizationError.malformedSummary }
            // The source's labelled footer owns the lower ledger boundary.
            // A fixed bottom-page strip could discard legitimate rows merely
            // because the bank moved its footer or changed the page size.
            let footerY = grouped.values.filter {
                Self.rowText($0).uppercased() == "HDFC BANK LIMITED" &&
                    ($0.map(\.bounds.minY).min() ?? headerY) < headerY
            }.flatMap { $0.map(\.bounds.maxY) }.max()
            if let footerY {
                let footerFinancialRows = grouped.values.filter { group in
                    group.allSatisfy { $0.bounds.minY < footerY } &&
                        group.contains { $0.bounds.minX < columnBoundaries[0] &&
                            Self.matches($0.text, #"^[0-9]{2}/[0-9]{2}/[0-9]{2}$"#) } &&
                        group.contains { Self.matches($0.text, Self.moneyPattern) }
                }
                if let unconsumed = footerFinancialRows.flatMap({ $0 }).map(\.sourceOrdinal).min() {
                    throw HDFCBankAccountPDFNormalizationError.unconsumedFinancialContent(sourceOrdinal: unconsumed)
                }
            }
            pages.append(PageEvidence(
                pageIndex: pageIndex,
                lines: lines,
                columnBoundaries: columnBoundaries,
                headerY: headerY,
                headerOrdinal: exactHeaders.first?.map(\.sourceOrdinal).min(),
                summaryY: summaryRows.first?.map(\.bounds.minY).min(),
                pageFloorY: footerY ?? pageBounds.minY
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
            if page.pageIndex > 0,
               let firstStart = starts.first,
               let previous = rows.last {
                let leadingRegion = page.lines.filter {
                    $0.bounds.minY < page.headerY - 4 &&
                    $0.bounds.minY > firstStart.bounds.minY + 1
                }
                let leadingRows = Dictionary(grouping: leadingRegion, by: \.visualRow)
                    .sorted { $0.key < $1.key }
                    .map(\.value)
                var continuationRows: [[VisualLine]] = []
                for row in leadingRows.reversed() {
                    let retainedRow = Self.isRepeatedPagePackaging(row) ? [] : row
                    let narrationTokens = retainedRow.filter { $0.bounds.minX < boundaries[1] }
                    let foreignTokens = retainedRow.filter { $0.bounds.minX >= boundaries[1] }
                    let isContinuation = foreignTokens.isEmpty && !narrationTokens.isEmpty && narrationTokens.allSatisfy {
                            !Self.matches($0.text, #"^[0-9]{2}/[0-9]{2}/[0-9]{2}$"#) &&
                            !Self.matches($0.text, Self.moneyPattern)
                    }
                    guard isContinuation else { break }
                    continuationRows.append(narrationTokens)
                }
                continuationRows.reverse()
                let continuationNarration = continuationRows.flatMap {
                    $0.filter { $0.bounds.minX < boundaries[1] }
                }
                if !continuationNarration.isEmpty {
                    var values = previous.values
                    values[1] = Self.boundedWhitespace(
                        values[1] + Self.narrationText(continuationNarration)
                    )
                    rows[rows.count - 1] = NormalizedRow(
                        rowNumber: previous.rowNumber,
                        values: values,
                        rawValues: previous.rawValues,
                        sourcePage: previous.sourcePage
                    )
                    consumedFinancialOrdinals.formUnion(
                        continuationNarration.map(\.sourceOrdinal)
                    )
                }
            }
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
                let leadingNarrations = leadingColumn.filter {
                    !Self.matches($0.text, #"^[0-9]{2}/[0-9]{2}/[0-9]{2}$"#)
                }
                let narrationColumn = column(boundaries[0]..<boundaries[1])
                let narrations = Self.removingRepeatedPagePackaging(
                    from: leadingNarrations + narrationColumn
                ).sorted {
                    if $0.bounds.minY != $1.bounds.minY { return $0.bounds.minY > $1.bounds.minY }
                    return $0.bounds.minX < $1.bounds.minX
                }
                let references = column(boundaries[1]..<boundaries[2])
                let valueDates = column(boundaries[2]..<boundaries[3])
                let withdrawals = column(boundaries[3]..<boundaries[4])
                let deposits = column(boundaries[4]..<boundaries[5])
                let balances = column(boundaries[5]..<10_000)
                guard dates.count == 1, dates[0].sourceOrdinal == start.sourceOrdinal,
                      !narrations.isEmpty,
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
                let narration = Self.narrationText(narrations)
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
                        Self.boundedWhitespace(references.map(\.text).joined()),
                        valueDates[0].text,
                        withdrawals.first?.text ?? "",
                        deposits.first?.text ?? "",
                        balances[0].text
                    ],
                    sourcePage: page.pageIndex + 1
                ))
            }
        }
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
        document.headerRow = pages.compactMap(\.headerOrdinal).first
        document.firstTransactionRow = rows.first?.rowNumber
        document.columnCount = HDFCBankAccountXLSNormalizer.logicalHeader.count
        document.encoding = "UTF-8"

        let preamble = try preambleEvidence(
            in: pages,
            account: account,
            customer: customer,
            period: period,
            currency: currency
        )
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
        let generationBoundaryY = grouped.values.filter {
            Self.rowText($0).contains("Generated On:") &&
                ($0.map(\.bounds.minY).min() ?? labelY) < labelY
        }.flatMap { $0.map(\.bounds.maxY) }.max() ?? page.pageFloorY
        let valueRows = grouped.values.compactMap { row -> (lines: [VisualLine], values: [String])? in
            let rowY = row.map(\.bounds.minY).min() ?? 0
            guard rowY < labelY && rowY > generationBoundaryY else { return nil }
            let values = Self.rowText(row).split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard values.count == 6,
                  Self.matches(values[0], Self.moneyPattern),
                  Int(values[1]) != nil, Int(values[2]) != nil,
                  Self.matches(values[3], Self.moneyPattern),
                  Self.matches(values[4], Self.moneyPattern),
                  Self.matches(values[5], Self.moneyPattern) else { return nil }
            return (row, values)
        }
        guard valueRows.count == 1, let valueRow = valueRows.first,
              let titleRow = grouped.values.first(where: {
                  let value = Self.rowText($0)
                  return value == "STATEMENT SUMMARY :-" || value == "STATEMENT SUMMARY  :-"
              }) else {
            throw HDFCBankAccountPDFNormalizationError.malformedSummary
        }
        let titleOrdinal = titleRow.map(\.sourceOrdinal).min() ?? 0
        let labelOrdinal = labelRows[0].map(\.sourceOrdinal).min() ?? 0
        let valueOrdinal = valueRow.lines.map(\.sourceOrdinal).min() ?? 0
        guard titleOrdinal > 0, labelOrdinal > 0, valueOrdinal > 0 else {
            throw HDFCBankAccountPDFNormalizationError.malformedSummary
        }
        return [
            .init(sourceOrdinal: titleOrdinal, text: Self.rowText(titleRow)),
            .init(sourceOrdinal: labelOrdinal, text: Self.rowText(labelRows[0])),
            .init(sourceOrdinal: valueOrdinal, text: Self.rowText(valueRow.lines))
        ]
    }

    private func preambleEvidence(
        in pages: [PageEvidence],
        account: String,
        customer: String,
        period: [String],
        currency: String
    ) throws -> [NormalizedDocument.SourceFragment] {
        let rows = pages.flatMap { page in
            Dictionary(grouping: page.lines, by: \.visualRow).values.map { lines in
                (
                    ordinal: lines.map(\.sourceOrdinal).min() ?? 0,
                    text: Self.rowText(lines)
                )
            }
        }
        let evidence: [(requiredTerms: [String], normalizedText: String)] = [
            (["Currency"], "Currency : \(currency)"),
            (["Cust", "ID"], "Cust ID : \(customer)"),
            (["Account", "No"], "Account No : \(account) NR Others"),
            (["From", "To"], "From : \(period[0]) To : \(period[1])")
        ]
        var result: [NormalizedDocument.SourceFragment] = []
        for item in evidence {
            let matches = rows.filter { row in
                row.ordinal > 0 && item.requiredTerms.allSatisfy {
                    row.text.localizedCaseInsensitiveContains($0)
                }
            }
            guard let first = matches.first else {
                throw HDFCBankAccountPDFNormalizationError.malformedPreamble
            }
            result.append(.init(sourceOrdinal: first.ordinal, text: item.normalizedText))
        }
        return result
    }

    private static func visualTokens(page: RawPDFPageEvidence, pageIndex: Int) throws -> [VisualLine] {
        let positioned = try page.fragments.map { fragment -> (text: String, bounds: CGRect) in
            guard let bounds = fragment.bounds else {
                throw HDFCBankAccountPDFNormalizationError.unsupportedNativeText
            }
            guard !bounds.isNull, !bounds.isInfinite, bounds.width > 0, bounds.height > 0 else {
                throw HDFCBankAccountPDFNormalizationError.unsupportedNativeText
            }
            return (fragment.text, bounds)
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

    /// Whitespace within one printed visual row separates source tokens. A
    /// physical continuation row, including one carried onto the next page,
    /// continues the same bounded narration field and therefore contributes no
    /// invented separator of its own.
    private static func narrationText(_ lines: [VisualLine]) -> String {
        boundedWhitespace(
            Dictionary(grouping: lines, by: \.visualRow)
                .sorted { $0.key < $1.key }
                .map { _, row in
                    row.sorted { $0.bounds.minX < $1.bounds.minX }
                        .map(\.text)
                        .joined(separator: " ")
                }
                .joined()
        )
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

    private static func isRepeatedPagePackaging(_ lines: [VisualLine]) -> Bool {
        let normalized = boundedWhitespace(rowText(lines)).uppercased()
        return normalized.contains("HDFC BANK LIMITED") ||
            normalized.contains("STATEMENT OF ACCOUNT") ||
            normalized.hasPrefix("PAGE NO")
    }

    private static func removingRepeatedPagePackaging(from lines: [VisualLine]) -> [VisualLine] {
        Dictionary(grouping: lines, by: \.visualRow)
            .sorted { $0.key < $1.key }
            .flatMap { _, row in
                isRepeatedPagePackaging(row) ? [] : row
            }
    }

    private static let moneyPattern = #"^[0-9]+(?:,[0-9]{3})*\.[0-9]{2}$"#
}
