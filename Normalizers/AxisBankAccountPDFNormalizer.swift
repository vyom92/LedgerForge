//
// LedgerForge
// AxisBankAccountPDFNormalizer.swift
// Version: 0.1.0
//

import Foundation

enum AxisBankAccountPDFColumn: Int, CaseIterable {
    case date
    case chequeReference
    case particulars
    case sourceDebit
    case sourceCredit
    case collapsedAmount
    case balance
    case branchCode

    static let normalizedHeader = [
        "Tran Date",
        "Chq No",
        "Particulars",
        "Debit",
        "Credit",
        "Posted Amount",
        "Balance",
        "Init. Br"
    ]
}

enum AxisBankAccountPDFTitleEvidenceError: Error, Equatable {
    case notTitle
    case malformedAccountIdentifier
    case malformedDeclaredPeriod
    case unconsumedFinancialPrefix
}

struct AxisBankAccountPDFTitleEvidence: Equatable {
    let accountIdentifier: String
    let periodStartText: String
    let periodEndText: String
    let recognizedSourceText: String

    static let marker = "Statement of Axis Account No"

    static func parse(
        _ sourceText: String
    ) throws -> AxisBankAccountPDFTitleEvidence {
        let text = sourceText.collapsingWhitespace
        guard let markerRange = text.range(of: marker) else {
            throw AxisBankAccountPDFTitleEvidenceError.notTitle
        }
        let discardedPrefix = String(text[..<markerRange.lowerBound])
            .collapsingWhitespace
        guard !AxisBankAccountPDFNormalizer.looksFinancial(discardedPrefix) else {
            throw AxisBankAccountPDFTitleEvidenceError.unconsumedFinancialPrefix
        }
        let recognizedSourceText = String(text[markerRange.lowerBound...])

        let pattern =
            #"^Statement of Axis Account No\s*:\s*(\S+)\s+for the period\s*\(From\s*:\s*(\S+)\s+To\s*:\s*(\S+)\)\s*$"#
        guard let captures = recognizedSourceText.captures(matching: pattern),
              captures.count == 3 else {
            throw AxisBankAccountPDFTitleEvidenceError.malformedDeclaredPeriod
        }

        let accountIdentifier = captures[0]
        guard accountIdentifier.count == 15,
              accountIdentifier.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw AxisBankAccountPDFTitleEvidenceError.malformedAccountIdentifier
        }

        do {
            _ = try AxisBankAccountSourceEvidence.declaredStatementPeriod(
                startText: captures[1],
                endText: captures[2]
            )
        } catch {
            throw AxisBankAccountPDFTitleEvidenceError.malformedDeclaredPeriod
        }

        return AxisBankAccountPDFTitleEvidence(
            accountIdentifier: accountIdentifier,
            periodStartText: captures[1],
            periodEndText: captures[2],
            recognizedSourceText: recognizedSourceText
        )
    }
}

enum AxisBankAccountPDFNormalizationError: Error, Equatable, LocalizedError {
    case missingTitle
    case malformedAccountIdentifier(sourceOrdinal: Int)
    case malformedDeclaredPeriod(sourceOrdinal: Int)
    case conflictingTitleEvidence
    case missingTableHeader
    case changedColumnOrder(sourceOrdinal: Int)
    case duplicateInitialHeader
    case missingOpeningBalance
    case missingTransactionTotal
    case missingClosingBalance
    case malformedTerminalValue(sourceOrdinal: Int)
    case duplicateTerminalSection
    case invalidSectionOrder
    case noTransactions
    case malformedDate(sourceOrdinal: Int)
    case incompleteTransaction(sourceOrdinal: Int)
    case missingBalance(sourceOrdinal: Int)
    case missingBranch(sourceOrdinal: Int)
    case malformedDecimal(sourceOrdinal: Int)
    case unconsumedFinancialContent(sourceOrdinal: Int)

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            return "The exact Axis bank-account PDF title is missing."
        case .malformedAccountIdentifier(let sourceOrdinal):
            return "Axis PDF account evidence on source line \(sourceOrdinal) is malformed."
        case .malformedDeclaredPeriod(let sourceOrdinal):
            return "Axis PDF statement-period evidence on source line \(sourceOrdinal) is malformed."
        case .conflictingTitleEvidence:
            return "Axis PDF title, account, or period evidence is duplicated or conflicting."
        case .missingTableHeader:
            return "The exact Axis PDF transaction-table header is missing."
        case .changedColumnOrder(let sourceOrdinal):
            return "Axis PDF table columns on source line \(sourceOrdinal) do not match the approved order."
        case .duplicateInitialHeader:
            return "Axis PDF contains more than one initial table header."
        case .missingOpeningBalance:
            return "Axis PDF is missing OPENING BALANCE."
        case .missingTransactionTotal:
            return "Axis PDF is missing TRANSACTION TOTAL."
        case .missingClosingBalance:
            return "Axis PDF is missing CLOSING BALANCE."
        case .malformedTerminalValue(let sourceOrdinal):
            return "Axis PDF terminal evidence on source line \(sourceOrdinal) is malformed."
        case .duplicateTerminalSection:
            return "Axis PDF contains a repeated or conflicting terminal section."
        case .invalidSectionOrder:
            return "Axis PDF financial sections are not in the approved order."
        case .noTransactions:
            return "Axis PDF contains no supported transaction rows."
        case .malformedDate(let sourceOrdinal):
            return "Axis PDF transaction on source line \(sourceOrdinal) has a malformed date."
        case .incompleteTransaction(let sourceOrdinal):
            return "Axis PDF transaction beginning on source line \(sourceOrdinal) is incomplete."
        case .missingBalance(let sourceOrdinal):
            return "Axis PDF transaction beginning on source line \(sourceOrdinal) has no running balance."
        case .missingBranch(let sourceOrdinal):
            return "Axis PDF transaction beginning on source line \(sourceOrdinal) has no Init. Br evidence."
        case .malformedDecimal(let sourceOrdinal):
            return "Axis PDF financial value on source line \(sourceOrdinal) is malformed."
        case .unconsumedFinancialContent(let sourceOrdinal):
            return "Axis PDF has unconsumed financial-looking content on source line \(sourceOrdinal)."
        }
    }
}

struct AxisBankAccountPDFNormalizationResult {
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow?
    let sourceContext: NormalizedDocument.SourceContext
}

final class AxisBankAccountPDFNormalizer {

    private struct PhysicalLine {
        let index: Int
        let text: String

        var sourceOrdinal: Int { index + 1 }
        var normalizedText: String { text.collapsingWhitespace }
    }

    private struct HeaderOccurrence {
        let startIndex: Int
        let consumedIndices: Set<Int>
    }

    private struct TerminalEvidence {
        let index: Int
        let values: [String]
    }

    private struct ParsedTransaction {
        let sourceOrdinal: Int
        let sourcePage: Int?
        let date: String
        let chequeReference: String
        let particulars: String
        let sourceDebit: String
        let sourceCredit: String
        let collapsedAmount: String
        let balance: String
        let branchCode: String
    }

    /// Geometry-backed source rows are only used when PDFKit has compressed
    /// one or more physical rows into a shared text line. The row's ordinal is
    /// a reconstructed physical ordinal: the page's global joined-text base
    /// line plus the row's zero-based anchor order. It is not a native table
    /// row number. Ordinary row-major pages retain the existing PDFKit
    /// physical-line ordinal.
    private struct GeometryPage {
        let pageNumber: Int
        let evidence: RawPDFPageEvidence
        let fragmentTokenIndices: [Int]
        let pageStartLine: Int
        let pageEndLine: Int
        let dateAnchorIndices: [Int]
        let compressed: Bool
    }

    private struct GeometryAmountCluster {
        let center: Double
        let minCenter: Double
        let maxCenter: Double
        let count: Int
    }

    private struct GeometryHeaderLayout {
        let dateCenter: Double
        let debitCenter: Double
        let creditCenter: Double
        let balanceCenter: Double
        let branchCenter: Double
    }

    private struct GeometryColumnLayout {
        let dateCenter: Double
        let dateHalfWidth: Double
        let chequeUpper: Double
        let debit: GeometryAmountCluster
        let credit: GeometryAmountCluster
        let balance: GeometryAmountCluster
        let branchCenter: Double
        let branchHalfWidth: Double

        var debitLower: Double { debit.center - 40 }
        var debitUpper: Double { (debit.center + credit.center) / 2 }
        var creditLower: Double { debitUpper }
        var creditUpper: Double { (credit.center + balance.center) / 2 }
        var balanceLower: Double { creditUpper }
        var balanceUpper: Double { (balance.center + branchCenter) / 2 }
        var branchLower: Double { balanceUpper }
        var narrativeLower: Double { chequeUpper }
        var narrativeUpper: Double { debitLower }
    }

    private struct GeometryPageSourceMap {
        let tokens: [String]
        let tokenLines: [Int]
        let pages: [GeometryPage]
    }

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func normalize(
        text: String,
        pageEvidence: [RawPDFPageEvidence]? = nil,
        fileURL: URL
    ) throws -> AxisBankAccountPDFNormalizationResult {
        let lines = text.components(separatedBy: .newlines)
            .enumerated()
            .map { PhysicalLine(index: $0.offset, text: $0.element) }

        let title = try titleEvidence(in: lines)
        let headers = try headerOccurrences(in: lines)
        guard !headers.isEmpty else {
            throw AxisBankAccountPDFNormalizationError.missingTableHeader
        }

        let opening = try terminalEvidence(
            prefix: Self.openingPrefix,
            pattern: #"^OPENING BALANCE\s+("# + Self.moneyPattern + #")\s*$"#,
            missing: .missingOpeningBalance,
            in: lines
        )
        let transactionTotal = try terminalEvidence(
            prefix: Self.totalPrefix,
            pattern: #"^TRANSACTION TOTAL\s+("# + Self.moneyPattern + #")\s+("# + Self.moneyPattern + #")\s*$"#,
            missing: .missingTransactionTotal,
            in: lines
        )
        let closing = try terminalEvidence(
            prefix: Self.closingPrefix,
            pattern: #"^CLOSING BALANCE\s+("# + Self.moneyPattern + #")\s*$"#,
            missing: .missingClosingBalance,
            in: lines
        )

        guard let initialHeader = headers.first(where: {
            $0.startIndex > title.line.index && $0.startIndex < opening.index
        }) else {
            throw AxisBankAccountPDFNormalizationError.invalidSectionOrder
        }
        let initialHeaderCount = headers.filter {
            $0.startIndex > title.line.index && $0.startIndex < opening.index
        }.count
        guard initialHeaderCount == 1 else {
            throw AxisBankAccountPDFNormalizationError.duplicateInitialHeader
        }
        guard title.line.index < initialHeader.startIndex,
              initialHeader.startIndex < opening.index,
              opening.index < transactionTotal.index,
              transactionTotal.index < closing.index else {
            throw AxisBankAccountPDFNormalizationError.invalidSectionOrder
        }

        try rejectFinancialContent(
            in: lines,
            from: lines.startIndex,
            to: title.line.index
        )
        try rejectFinancialContent(
            in: lines,
            from: title.line.index + 1,
            to: initialHeader.startIndex
        )
        let initialHeaderEnd =
            (initialHeader.consumedIndices.max() ?? initialHeader.startIndex) + 1
        try rejectFinancialContent(
            in: lines,
            from: initialHeaderEnd,
            to: opening.index
        )
        try rejectFinancialContent(
            in: lines,
            from: transactionTotal.index + 1,
            to: closing.index
        )

        let repeatedHeaders = headers.filter {
            $0.startIndex > opening.index && $0.startIndex < transactionTotal.index
        }
        let allowedHeaderStarts = Set(
            [initialHeader.startIndex] + repeatedHeaders.map(\.startIndex)
        )
        guard headers.allSatisfy({
            allowedHeaderStarts.contains($0.startIndex)
        }) else {
            throw AxisBankAccountPDFNormalizationError.invalidSectionOrder
        }
        let repeatedHeaderIndices = repeatedHeaders.reduce(into: Set<Int>()) {
            $0.formUnion($1.consumedIndices)
        }

        let parsedTransactions = try transactions(
            in: lines,
            from: opening.index + 1,
            to: transactionTotal.index,
            repeatedHeaderIndices: repeatedHeaderIndices,
            pageEvidence: pageEvidence,
            sourceText: text,
            headerSourceLines: initialHeader.consumedIndices
        )
        for line in lines where line.index > closing.index {
            if Self.looksFinancial(line.normalizedText) {
                throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                    sourceOrdinal: line.sourceOrdinal
                )
            }
        }

        let openingBalance = Self.canonicalMoneyText(opening.values[0])
        let printedDebitTotal = Self.canonicalMoneyText(transactionTotal.values[0])
        let printedCreditTotal = Self.canonicalMoneyText(transactionTotal.values[1])
        let closingBalance = Self.canonicalMoneyText(closing.values[0])

        let currency = try CurrencyCode("INR")
        let printedControls = try NormalizedDocument.PrintedBankStatementControls(
            profileID: "axis.bank-account.pdf",
            profileVersion: "1",
            sourceFormatCode: "pdf",
            openingBalance: try Money(canonicalDecimal: openingBalance, currency: currency.code),
            debitTotal: try Money(canonicalDecimal: printedDebitTotal, currency: currency.code),
            creditTotal: try Money(canonicalDecimal: printedCreditTotal, currency: currency.code),
            closingBalance: try Money(canonicalDecimal: closingBalance, currency: currency.code),
            openingSourceOrdinal: opening.index + 1,
            totalsSourceOrdinal: transactionTotal.index + 1,
            closingSourceOrdinal: closing.index + 1
        )
        let financialRegion = try NormalizedDocument.ExhaustedFinancialRegionEvidence(
            descriptor: "Axis PDF table from initial header through closing balance",
            sourceUnit: .line,
            startOrdinal: initialHeader.startIndex + 1,
            endOrdinal: closing.index + 1,
            recognizedFinancialRowCount: parsedTransactions.count,
            sourceRecords: lines[initialHeader.startIndex...closing.index].map(\.text)
        )

        let rows = parsedTransactions.map { transaction in
            let values = [
                transaction.date,
                transaction.chequeReference,
                transaction.particulars,
                transaction.sourceDebit,
                transaction.sourceCredit,
                transaction.collapsedAmount,
                transaction.balance,
                transaction.branchCode
            ]

            return NormalizedRow(
                rowNumber: transaction.sourceOrdinal,
                values: values,
                sourcePage: transaction.sourcePage
            )
        }

        var document = Document(
            filename: fileURL.lastPathComponent,
            url: fileURL,
            fileType: FileFormat.pdf.rawValue,
            importedAt: now()
        )
        document.rowCount = lines.count
        document.headerRow = initialHeader.startIndex + 1
        document.firstTransactionRow = parsedTransactions.first?.sourceOrdinal
        document.columnCount = AxisBankAccountPDFColumn.allCases.count
        document.encoding = "PDFKit selectable text"

        return AxisBankAccountPDFNormalizationResult(
            document: document,
            rows: rows,
            header: NormalizedRow(
                rowNumber: initialHeader.startIndex + 1,
                values: AxisBankAccountPDFColumn.normalizedHeader
            ),
            sourceContext: NormalizedDocument.SourceContext(
                preTransactionFragments: [
                    NormalizedDocument.SourceFragment(
                        sourceOrdinal: title.line.sourceOrdinal,
                        text: title.evidence.recognizedSourceText
                    )
                ],
                exhaustedFinancialRegion: financialRegion,
                printedBankStatementControls: printedControls
            )
        )
    }

    private func titleEvidence(
        in lines: [PhysicalLine]
    ) throws -> (line: PhysicalLine, evidence: AxisBankAccountPDFTitleEvidence) {
        var matches: [(PhysicalLine, AxisBankAccountPDFTitleEvidence)] = []

        for line in lines {
            do {
                matches.append((line, try AxisBankAccountPDFTitleEvidence.parse(line.text)))
            } catch AxisBankAccountPDFTitleEvidenceError.notTitle {
                continue
            } catch AxisBankAccountPDFTitleEvidenceError.malformedAccountIdentifier {
                throw AxisBankAccountPDFNormalizationError.malformedAccountIdentifier(
                    sourceOrdinal: line.sourceOrdinal
                )
            } catch AxisBankAccountPDFTitleEvidenceError.malformedDeclaredPeriod {
                throw AxisBankAccountPDFNormalizationError.malformedDeclaredPeriod(
                    sourceOrdinal: line.sourceOrdinal
                )
            } catch AxisBankAccountPDFTitleEvidenceError.unconsumedFinancialPrefix {
                throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                    sourceOrdinal: line.sourceOrdinal
                )
            }
        }

        guard !matches.isEmpty else {
            throw AxisBankAccountPDFNormalizationError.missingTitle
        }
        guard matches.count == 1, let match = matches.first else {
            throw AxisBankAccountPDFNormalizationError.conflictingTitleEvidence
        }
        return (line: match.0, evidence: match.1)
    }

    private func headerOccurrences(
        in lines: [PhysicalLine]
    ) throws -> [HeaderOccurrence] {
        var occurrences: [HeaderOccurrence] = []
        var index = 0

        while index < lines.count {
            let text = lines[index].normalizedText
            if text == Self.completeHeader {
                occurrences.append(
                    HeaderOccurrence(
                        startIndex: index,
                        consumedIndices: [index]
                    )
                )
                index += 1
                continue
            }
            if text == Self.splitHeader {
                guard lines.indices.contains(index + 1),
                      lines[index + 1].normalizedText == "Br" else {
                    throw AxisBankAccountPDFNormalizationError.changedColumnOrder(
                        sourceOrdinal: lines[index].sourceOrdinal
                    )
                }
                occurrences.append(
                    HeaderOccurrence(
                        startIndex: index,
                        consumedIndices: [index, index + 1]
                    )
                )
                index += 2
                continue
            }
            if Self.looksLikeTableHeader(text) {
                throw AxisBankAccountPDFNormalizationError.changedColumnOrder(
                    sourceOrdinal: lines[index].sourceOrdinal
                )
            }
            index += 1
        }

        return occurrences
    }

    private func terminalEvidence(
        prefix: String,
        pattern: String,
        missing: AxisBankAccountPDFNormalizationError,
        in lines: [PhysicalLine]
    ) throws -> TerminalEvidence {
        let candidates = lines.filter {
            $0.normalizedText.hasPrefix(prefix)
        }
        guard !candidates.isEmpty else {
            throw missing
        }
        guard candidates.count == 1, let candidate = candidates.first else {
            throw AxisBankAccountPDFNormalizationError.duplicateTerminalSection
        }
        guard let values = candidate.normalizedText.captures(matching: pattern) else {
            throw AxisBankAccountPDFNormalizationError.malformedTerminalValue(
                sourceOrdinal: candidate.sourceOrdinal
            )
        }
        return TerminalEvidence(index: candidate.index, values: values)
    }

    private func transactions(
        in lines: [PhysicalLine],
        from startIndex: Int,
        to endIndex: Int,
        repeatedHeaderIndices: Set<Int>,
        pageEvidence: [RawPDFPageEvidence]?,
        sourceText: String,
        headerSourceLines: Set<Int>
    ) throws -> [ParsedTransaction] {
        if let pageEvidence, !pageEvidence.isEmpty,
           let geometryRows = try geometryTransactions(
               in: lines,
               from: startIndex,
               to: endIndex,
               pageEvidence: pageEvidence,
               sourceText: sourceText,
               headerSourceLines: headerSourceLines
           ) {
            return geometryRows
        }

        var groups: [[PhysicalLine]] = []
        var current: [PhysicalLine] = []
        var ignoringBoundedNonFinancialBlock = false

        for index in startIndex..<endIndex {
            guard lines.indices.contains(index) else { continue }
            let line = lines[index]
            let text = line.normalizedText
            if repeatedHeaderIndices.contains(index) {
                ignoringBoundedNonFinancialBlock = false
                continue
            }
            if text.isEmpty {
                continue
            }

            if Self.startsWithDate(text) {
                ignoringBoundedNonFinancialBlock = false
                if !current.isEmpty {
                    groups.append(current)
                }
                current = [line]
            } else if Self.startsWithDateLikeToken(text) {
                throw AxisBankAccountPDFNormalizationError
                    .unconsumedFinancialContent(
                        sourceOrdinal: line.sourceOrdinal
                    )
            } else if Self.startsIgnorableNonFinancialBlock(text) {
                ignoringBoundedNonFinancialBlock = true
            } else if text.hasPrefix("Legend:") && Self.looksFinancial(text) {
                throw AxisBankAccountPDFNormalizationError
                    .unconsumedFinancialContent(
                        sourceOrdinal: line.sourceOrdinal
                    )
            } else if ignoringBoundedNonFinancialBlock {
                if Self.looksFinancial(text) {
                    throw AxisBankAccountPDFNormalizationError
                        .unconsumedFinancialContent(
                            sourceOrdinal: line.sourceOrdinal
                        )
                }
                continue
            } else {
                guard !current.isEmpty else {
                    throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                        sourceOrdinal: line.sourceOrdinal
                    )
                }
                current.append(line)
            }
        }

        if !current.isEmpty {
            groups.append(current)
        }

        let sourceMap: GeometryPageSourceMap?
        if let pageEvidence, !pageEvidence.isEmpty {
            sourceMap = geometrySourceMap(
                lines: lines,
                sourceText: sourceText,
                pageEvidence: pageEvidence,
                from: startIndex,
                to: endIndex
            )
        } else {
            sourceMap = nil
        }
        return try groups.map { group in
            let sourceOrdinal = group.first?.sourceOrdinal
            let pageNumber = sourceOrdinal.flatMap { ordinal in
                sourceMap?.pages.first {
                    ordinal >= $0.pageStartLine && ordinal <= $0.pageEndLine
                }?.pageNumber
            }
            return try parseTransaction(group, sourcePage: pageNumber)
        }
    }

    /// Uses rectangle evidence only for a page whose native text stream has
    /// demonstrably compressed multiple date anchors into fewer source lines.
    /// The geometry path remains deliberately narrow: columns are inferred
    /// from the repeated financial rectangles, every assigned fragment is
    /// checked, and no fallback is permitted after a compressed page is
    /// detected.
    private func geometryTransactions(
        in lines: [PhysicalLine],
        from startIndex: Int,
        to endIndex: Int,
        pageEvidence: [RawPDFPageEvidence],
        sourceText: String,
        headerSourceLines: Set<Int>
    ) throws -> [ParsedTransaction]? {
        guard !pageEvidence.isEmpty else { return nil }
        guard let sourceMap = geometrySourceMap(
               lines: lines,
               sourceText: sourceText,
               pageEvidence: pageEvidence,
               from: startIndex,
               to: endIndex
           ) else {
            throw AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: startIndex + 1)
        }

        let transactionPages = sourceMap.pages.compactMap { page -> (
            page: GeometryPage,
            anchors: [Int]
        )? in
            let anchors = page.dateAnchorIndices.filter { index in
                guard page.fragmentTokenIndices.indices.contains(index) else {
                    return false
                }
                let tokenIndex = page.fragmentTokenIndices[index]
                guard sourceMap.tokenLines.indices.contains(tokenIndex) else {
                    return false
                }
                let lineIndex = sourceMap.tokenLines[tokenIndex]
                return lineIndex >= startIndex && lineIndex < endIndex
            }
            return anchors.isEmpty ? nil : (page, anchors)
        }
        guard !transactionPages.isEmpty else { return nil }

        // Geometry is activated only by the exact page-edge compression shape:
        // at least one transaction page has multiple date anchors but fewer
        // date-bearing source lines (or multiple dates on one source line).
        guard transactionPages.contains(where: { $0.page.compressed }) else {
            return nil
        }

        let ignoredSourceLines = try geometryIgnoredSourceLines(
            lines: lines,
            from: startIndex,
            to: endIndex
        )
        let coveredTokenIndices = Set(
            transactionPages.flatMap { $0.page.fragmentTokenIndices }
        )
        for page in sourceMap.pages {
            for (index, fragment) in page.evidence.fragments.enumerated() {
                guard page.fragmentTokenIndices.indices.contains(index) else {
                    continue
                }
                let tokenIndex = page.fragmentTokenIndices[index]
                guard sourceMap.tokenLines.indices.contains(tokenIndex) else {
                    continue
                }
                let sourceLine = sourceMap.tokenLines[tokenIndex]
                guard sourceLine >= startIndex && sourceLine < endIndex,
                      !coveredTokenIndices.contains(tokenIndex),
                      !ignoredSourceLines.contains(sourceLine) else {
                    continue
                }
                let text = fragment.text.collapsingWhitespace
                if Self.looksFinancial(text) ||
                    Self.isBranchText(text) ||
                    Self.startsWithDateLikeToken(text) {
                    throw AxisBankAccountPDFNormalizationError
                        .unconsumedFinancialContent(sourceOrdinal: sourceLine + 1)
                }
            }
        }
        let layout = try geometryColumnLayout(
            pages: transactionPages,
            sourceMap: sourceMap,
            from: startIndex,
            to: endIndex,
            headerSourceLines: headerSourceLines
        )

        var parsed: [ParsedTransaction] = []
        for transactionPage in transactionPages {
            let rows = try geometryRows(
                page: transactionPage.page,
                anchors: transactionPage.anchors,
                layout: layout,
                sourceMap: sourceMap,
                from: startIndex,
                to: endIndex,
                ignoredSourceLines: ignoredSourceLines
            )
            parsed.append(contentsOf: rows)
        }

        guard !parsed.isEmpty else {
            throw AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: startIndex + 1)
        }
        let ordered = parsed.sorted { lhs, rhs in
            if lhs.sourceOrdinal != rhs.sourceOrdinal {
                return lhs.sourceOrdinal < rhs.sourceOrdinal
            }
            return lhs.date < rhs.date
        }
        guard zip(ordered, ordered.dropFirst()).allSatisfy({ lhs, rhs in
            lhs.sourceOrdinal < rhs.sourceOrdinal
        }) else {
            throw AxisBankAccountPDFNormalizationError
                .unconsumedFinancialContent(sourceOrdinal: ordered[0].sourceOrdinal)
        }
        return ordered
    }

    private func geometrySourceMap(
        lines: [PhysicalLine],
        sourceText: String,
        pageEvidence: [RawPDFPageEvidence],
        from startIndex: Int,
        to endIndex: Int
    ) -> GeometryPageSourceMap? {
        let tokenPattern = #"\S+"#
        guard let expression = try? NSRegularExpression(pattern: tokenPattern) else {
            return nil
        }
        var tokens: [String] = []
        var tokenLines: [Int] = []
        for line in lines {
            let range = NSRange(line.text.startIndex..., in: line.text)
            for match in expression.matches(in: line.text, range: range) {
                guard let tokenRange = Range(match.range, in: line.text) else {
                    return nil
                }
                tokens.append(String(line.text[tokenRange]))
                tokenLines.append(line.index)
            }
        }

        var tokenCursor = 0
        var pages: [GeometryPage] = []
        pages.reserveCapacity(pageEvidence.count)
        for (pageIndex, evidence) in pageEvidence.enumerated() {
            guard !evidence.fragments.isEmpty else { return nil }
            let pageTokens = evidence.fragments.map(\.text)
            guard tokenCursor + pageTokens.count <= tokens.count,
                  Array(tokens[tokenCursor..<(tokenCursor + pageTokens.count)]) == pageTokens else {
                return nil
            }
            let pageTokenRange = tokenCursor..<(tokenCursor + pageTokens.count)
            let pageLines = pageTokenRange.compactMap { tokenLines[$0] }
            guard let pageStartLine = pageLines.min(),
                  let pageEndLine = pageLines.max() else {
                return nil
            }

            let exactDateIndices = evidence.fragments.indices.filter { index in
                Self.isAxisDateText(evidence.fragments[index].text)
            }
            let dateGroups = Self.geometryXGroups(
                indices: exactDateIndices,
                fragments: evidence.fragments,
                maximumGap: 3
            )
            let rankedDateGroups = dateGroups.sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return ($0.first ?? 0) < ($1.first ?? 0)
            }
            let dateAnchorIndices: [Int]
            if let first = rankedDateGroups.first, first.count >= 1 {
                // A second repeated date band is not a competing fallback;
                // leave the page unqualified so the strict text path can
                // reject it using its ordinary grammar.
                if rankedDateGroups.dropFirst().contains(where: { $0.count >= 2 }) {
                    dateAnchorIndices = []
                } else {
                    dateAnchorIndices = first.sorted {
                        let left = evidence.fragments[$0].geometry?.baselineY ?? evidence.fragments[$0].y
                        let right = evidence.fragments[$1].geometry?.baselineY ?? evidence.fragments[$1].y
                        if abs(left - right) > 1.5 { return left > right }
                        return $0 < $1
                    }
                }
            } else {
                dateAnchorIndices = []
            }

            let pageTextLines = lines.filter {
                $0.index >= pageStartLine && $0.index <= pageEndLine
            }
            let dateBearingLineCounts = pageTextLines.map { line in
                guard line.index >= startIndex && line.index < endIndex else {
                    return 0
                }
                return expression.matches(
                    in: line.text,
                    range: NSRange(line.text.startIndex..., in: line.text)
                ).filter { match in
                    guard let range = Range(match.range, in: line.text) else {
                        return false
                    }
                    return Self.isAxisDateText(String(line.text[range]))
                }.count
            }
            let dateTokenCount = dateBearingLineCounts.reduce(0, +)
            let compressed = dateAnchorIndices.count >= 2 && (
                dateTokenCount != dateAnchorIndices.count ||
                    dateBearingLineCounts.contains(where: { $0 > 1 }) ||
                    dateBearingLineCounts.filter({ $0 == 1 }).count != dateAnchorIndices.count
            )

            pages.append(
                GeometryPage(
                    pageNumber: pageIndex + 1,
                    evidence: evidence,
                    fragmentTokenIndices: Array(pageTokenRange),
                    pageStartLine: pageStartLine + 1,
                    pageEndLine: pageEndLine + 1,
                    dateAnchorIndices: dateAnchorIndices,
                    compressed: compressed
                )
            )
            tokenCursor += pageTokens.count
        }

        guard tokenCursor == tokens.count else {
            return nil
        }

        return GeometryPageSourceMap(tokens: tokens, tokenLines: tokenLines, pages: pages)
    }

    private func geometryIgnoredSourceLines(
        lines: [PhysicalLine],
        from startIndex: Int,
        to endIndex: Int
    ) throws -> Set<Int> {
        var ignored: Set<Int> = []
        var inLegend = false
        for line in lines where line.index >= startIndex && line.index < endIndex {
            let text = line.normalizedText
            if text.isEmpty { continue }
            if Self.startsIgnorableNonFinancialBlock(text) {
                if Self.looksFinancial(text) && text != "Legend" && text != "Legend:" {
                    throw AxisBankAccountPDFNormalizationError
                        .unconsumedFinancialContent(sourceOrdinal: line.sourceOrdinal)
                }
                ignored.insert(line.index)
                inLegend = text == "Legend" || text == "Legend:"
                continue
            }
            if inLegend {
                if Self.startsWithDate(text) || Self.startsWithDateLikeToken(text) {
                    inLegend = false
                } else {
                    if Self.looksFinancial(text) {
                        throw AxisBankAccountPDFNormalizationError
                            .unconsumedFinancialContent(sourceOrdinal: line.sourceOrdinal)
                    }
                    ignored.insert(line.index)
                }
            }
        }
        return ignored
    }

    private func geometryColumnLayout(
        pages: [(page: GeometryPage, anchors: [Int])],
        sourceMap: GeometryPageSourceMap,
        from startIndex: Int,
        to endIndex: Int,
        headerSourceLines: Set<Int>
    ) throws -> GeometryColumnLayout {
        var dateCenters: [Double] = []
        var amountCenters: [Double] = []
        var branchCenters: [Double] = []
        for pair in pages {
            let anchorYs = pair.anchors.map {
                pair.page.evidence.fragments[$0].geometry?.baselineY ??
                    pair.page.evidence.fragments[$0].y
            }
            guard Self.geometryAnchorsAreUnique(anchorYs) else {
                throw AxisBankAccountPDFNormalizationError
                    .unconsumedFinancialContent(sourceOrdinal: pair.page.pageStartLine)
            }
            for index in pair.anchors {
                let fragment = pair.page.evidence.fragments[index]
                guard let geometry = fragment.geometry, geometry.isCanonical else {
                    throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                        sourceOrdinal: pair.page.pageStartLine
                    )
                }
                dateCenters.append((geometry.minX + geometry.maxX) / 2)
            }

            for (index, fragment) in pair.page.evidence.fragments.enumerated() {
                guard pair.page.fragmentTokenIndices.indices.contains(index) else { continue }
                let tokenIndex = pair.page.fragmentTokenIndices[index]
                guard sourceMap.tokenLines.indices.contains(tokenIndex) else { continue }
                let sourceLine = sourceMap.tokenLines[tokenIndex]
                guard sourceLine >= startIndex && sourceLine < endIndex,
                      let geometry = fragment.geometry,
                      geometry.isCanonical else {
                    continue
                }
                if Self.geometryRowBoundaryIsAmbiguous(
                    baselineY: geometry.baselineY,
                    anchors: anchorYs
                ) {
                    throw AxisBankAccountPDFNormalizationError
                        .unconsumedFinancialContent(sourceOrdinal: sourceLine + 1)
                }
                guard let rowIndex = Self.geometryRowIndex(
                    baselineY: geometry.baselineY,
                    anchors: anchorYs
                ),
                !pair.anchors.indices.contains(rowIndex) ||
                    index != pair.anchors[rowIndex] else {
                    continue
                }
                let center = (geometry.minX + geometry.maxX) / 2
                let cleaned = fragment.text.collapsingWhitespace
                if Self.isMoneyText(cleaned) {
                    amountCenters.append(center)
                } else if Self.isBranchText(cleaned) {
                    branchCenters.append(center)
                }
            }
        }

        guard let dateCenter = Self.geometryMedian(dateCenters),
              dateCenters.allSatisfy({ abs($0 - dateCenter) <= 3 }) else {
            throw AxisBankAccountPDFNormalizationError.changedColumnOrder(
                sourceOrdinal: pages.first?.page.pageStartLine ?? 0
            )
        }
        let amountClusters = Self.geometryCenterClusters(
            amountCenters,
            maximumGap: 24
        )
        guard amountClusters.count == 3,
              let first = amountClusters.first,
              let second = amountClusters.dropFirst().first,
              let third = amountClusters.dropFirst(2).first else {
            throw AxisBankAccountPDFNormalizationError.changedColumnOrder(
                sourceOrdinal: pages.first?.page.pageStartLine ?? 0
            )
        }
        let branchClusters = Self.geometryCenterClusters(
            branchCenters,
            maximumGap: 24
        )
        guard let branch = branchClusters.last,
              branch.center > third.center,
              branch.count >= 2 else {
            throw AxisBankAccountPDFNormalizationError.changedColumnOrder(
                sourceOrdinal: pages.first?.page.pageStartLine ?? 0
            )
        }

        let dateHalfWidth = max(
            20,
            dateCenters.map { abs($0 - dateCenter) }.max() ?? 0 + 5
        )
        let chequeUpper = min(first.center - 40, dateCenter + 75)
        guard chequeUpper > dateCenter + dateHalfWidth else {
            throw AxisBankAccountPDFNormalizationError.changedColumnOrder(
                sourceOrdinal: pages.first?.page.pageStartLine ?? 0
            )
        }
        guard let header = geometryHeaderLayout(
            sourceMap: sourceMap,
            sourceLines: headerSourceLines
        ) else {
            throw AxisBankAccountPDFNormalizationError.changedColumnOrder(
                sourceOrdinal: pages.first?.page.pageStartLine ?? 0
            )
        }
        let headerCenters = [
            header.dateCenter,
            header.debitCenter,
            header.creditCenter,
            header.balanceCenter,
            header.branchCenter
        ]
        guard zip(headerCenters, headerCenters.dropFirst()).allSatisfy({
            $0 + 3 < $1
        }) else {
            throw AxisBankAccountPDFNormalizationError.changedColumnOrder(
                sourceOrdinal: pages.first?.page.pageStartLine ?? 0
            )
        }
        let inferredCenters = [
            dateCenter,
            first.center,
            second.center,
            third.center,
            branch.center
        ]
        let headerTolerance: [Double] = [32, 48, 48, 48, 32]
        guard zip(zip(inferredCenters, headerCenters), headerTolerance)
            .allSatisfy({ pair in
                abs(pair.0.0 - pair.0.1) <= pair.1
            }) else {
            throw AxisBankAccountPDFNormalizationError.changedColumnOrder(
                sourceOrdinal: pages.first?.page.pageStartLine ?? 0
            )
        }
        return GeometryColumnLayout(
            dateCenter: dateCenter,
            dateHalfWidth: dateHalfWidth,
            chequeUpper: chequeUpper,
            debit: first,
            credit: second,
            balance: third,
            branchCenter: branch.center,
            branchHalfWidth: max(12, branch.maxCenter - branch.minCenter + 8)
        )
    }

    private func geometryHeaderLayout(
        sourceMap: GeometryPageSourceMap,
        sourceLines: Set<Int>
    ) -> GeometryHeaderLayout? {
        var centers: [String: [Double]] = [:]
        for page in sourceMap.pages {
            for (index, fragment) in page.evidence.fragments.enumerated() {
                guard page.fragmentTokenIndices.indices.contains(index) else {
                    continue
                }
                let tokenIndex = page.fragmentTokenIndices[index]
                guard sourceMap.tokenLines.indices.contains(tokenIndex),
                      sourceLines.contains(sourceMap.tokenLines[tokenIndex]),
                      let geometry = fragment.geometry,
                      geometry.isCanonical else {
                    continue
                }
                let text = fragment.text.collapsingWhitespace
                guard ["Tran", "Date", "Debit", "Credit", "Balance", "Init.", "Br"]
                    .contains(text) else {
                    continue
                }
                centers[text, default: []].append((geometry.minX + geometry.maxX) / 2)
            }
        }
        guard let tran = centers["Tran"], tran.count == 1,
              let date = centers["Date"], date.count == 1,
              let debit = centers["Debit"], debit.count == 1,
              let credit = centers["Credit"], credit.count == 1,
              let balance = centers["Balance"], balance.count == 1,
              let initBranch = centers["Init."], initBranch.count == 1,
              let branch = centers["Br"], branch.count == 1 else {
            return nil
        }
        return GeometryHeaderLayout(
            dateCenter: (tran[0] + date[0]) / 2,
            debitCenter: debit[0],
            creditCenter: credit[0],
            balanceCenter: balance[0],
            branchCenter: (initBranch[0] + branch[0]) / 2
        )
    }

    private func geometryRows(
        page: GeometryPage,
        anchors: [Int],
        layout: GeometryColumnLayout,
        sourceMap: GeometryPageSourceMap,
        from startIndex: Int,
        to endIndex: Int,
        ignoredSourceLines: Set<Int>
    ) throws -> [ParsedTransaction] {
        guard anchors.count >= 1 else { return [] }
        let anchorYs = anchors.map {
            page.evidence.fragments[$0].geometry?.baselineY ?? page.evidence.fragments[$0].y
        }
        guard Self.geometryAnchorsAreUnique(anchorYs) else {
            throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                sourceOrdinal: page.pageStartLine
            )
        }

        var rowFragments = Array(repeating: [Int](), count: anchors.count)
        var assigned: Set<Int> = []
        for (index, fragment) in page.evidence.fragments.enumerated() {
            guard page.fragmentTokenIndices.indices.contains(index) else { continue }
            let tokenIndex = page.fragmentTokenIndices[index]
            guard sourceMap.tokenLines.indices.contains(tokenIndex) else { continue }
            let sourceLine = sourceMap.tokenLines[tokenIndex]
            guard sourceLine >= startIndex && sourceLine < endIndex else { continue }
            if ignoredSourceLines.contains(sourceLine) { continue }
            guard let geometry = fragment.geometry, geometry.isCanonical else {
                throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                    sourceOrdinal: sourceLine + 1
                )
            }
            if Self.geometryRowBoundaryIsAmbiguous(
                baselineY: geometry.baselineY,
                anchors: anchorYs
            ) {
                throw AxisBankAccountPDFNormalizationError
                    .unconsumedFinancialContent(sourceOrdinal: sourceLine + 1)
            }
            guard let rowIndex = Self.geometryRowIndex(
                baselineY: geometry.baselineY,
                anchors: anchorYs
            ) else {
                if Self.looksFinancial(fragment.text.collapsingWhitespace) ||
                    Self.isBranchText(fragment.text.collapsingWhitespace) {
                    throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                        sourceOrdinal: sourceLine + 1
                    )
                }
                continue
            }
            rowFragments[rowIndex].append(index)
            assigned.insert(index)
        }

        var result: [ParsedTransaction] = []
        result.reserveCapacity(anchors.count)
        for (rowIndex, anchorIndex) in anchors.enumerated() {
            let sourceTokenIndex = page.fragmentTokenIndices[anchorIndex]
            let sourceOrdinal = page.compressed
                ? page.pageStartLine + rowIndex
                : sourceMap.tokenLines[sourceTokenIndex] + 1
            result.append(try geometryRow(
                page: page,
                anchorIndex: anchorIndex,
                sourceOrdinal: sourceOrdinal,
                fragmentIndices: rowFragments[rowIndex],
                layout: layout
            ))
        }

        for (index, fragment) in page.evidence.fragments.enumerated() {
            guard page.fragmentTokenIndices.indices.contains(index) else { continue }
            let tokenIndex = page.fragmentTokenIndices[index]
            guard sourceMap.tokenLines.indices.contains(tokenIndex) else { continue }
            let sourceLine = sourceMap.tokenLines[tokenIndex]
            guard sourceLine >= startIndex && sourceLine < endIndex else { continue }
            if ignoredSourceLines.contains(sourceLine) || assigned.contains(index) {
                continue
            }
            let text = fragment.text.collapsingWhitespace
            if Self.looksFinancial(text) || Self.isBranchText(text) || Self.startsWithDateLikeToken(text) {
                throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                    sourceOrdinal: sourceLine + 1
                )
            }
        }
        return result
    }

    private func geometryRow(
        page: GeometryPage,
        anchorIndex: Int,
        sourceOrdinal: Int,
        fragmentIndices: [Int],
        layout: GeometryColumnLayout
    ) throws -> ParsedTransaction {
        let anchor = page.evidence.fragments[anchorIndex]
        let dateText = anchor.text.collapsingWhitespace
        guard Self.isAxisDateText(dateText) else {
            throw AxisBankAccountPDFNormalizationError.malformedDate(
                sourceOrdinal: sourceOrdinal
            )
        }
        do {
            _ = try StatementDate.axisNRE(dateText)
        } catch {
            throw AxisBankAccountPDFNormalizationError.malformedDate(
                sourceOrdinal: sourceOrdinal
            )
        }

        var chequeReferences: [String] = []
        var particulars: [(fragment: RawPDFTextFragment, index: Int)] = []
        var debits: [String] = []
        var credits: [String] = []
        var balances: [String] = []
        var branches: [String] = []

        for index in fragmentIndices {
            guard page.evidence.fragments.indices.contains(index),
                  let geometry = page.evidence.fragments[index].geometry,
                  geometry.isCanonical else {
                throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                    sourceOrdinal: sourceOrdinal
                )
            }
            if index == anchorIndex { continue }
            let fragment = page.evidence.fragments[index]
            let text = fragment.text.collapsingWhitespace
            let center = (geometry.minX + geometry.maxX) / 2
            if abs(center - layout.dateCenter) <= layout.dateHalfWidth {
                if Self.startsWithDateLikeToken(text) || Self.isAxisDateText(text) {
                    throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                        sourceOrdinal: sourceOrdinal
                    )
                }
                throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                    sourceOrdinal: sourceOrdinal
                )
            }
            if center >= layout.branchLower {
                guard abs(center - layout.branchCenter) <= layout.branchHalfWidth,
                      Self.isBranchText(text) else {
                    throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                        sourceOrdinal: sourceOrdinal
                    )
                }
                branches.append(text)
            } else if center >= layout.balanceLower {
                guard center < layout.balanceUpper,
                      Self.isMoneyText(text) else {
                    throw AxisBankAccountPDFNormalizationError.malformedDecimal(
                        sourceOrdinal: sourceOrdinal
                    )
                }
                balances.append(Self.canonicalMoneyText(text))
            } else if center >= layout.creditLower {
                guard center < layout.creditUpper,
                      Self.isMoneyText(text) else {
                    throw AxisBankAccountPDFNormalizationError.malformedDecimal(
                        sourceOrdinal: sourceOrdinal
                    )
                }
                credits.append(Self.canonicalMoneyText(text))
            } else if center >= layout.debitLower {
                guard center < layout.debitUpper,
                      Self.isMoneyText(text) else {
                    throw AxisBankAccountPDFNormalizationError.malformedDecimal(
                        sourceOrdinal: sourceOrdinal
                    )
                }
                debits.append(Self.canonicalMoneyText(text))
            } else if center < layout.chequeUpper {
                guard center > layout.dateCenter + layout.dateHalfWidth,
                      Self.isChequeReference(text) else {
                    throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                        sourceOrdinal: sourceOrdinal
                    )
                }
                chequeReferences.append(text)
            } else if center < layout.narrativeUpper {
                guard !Self.isMoneyText(text),
                      !Self.startsWithDateLikeToken(text) else {
                    throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                        sourceOrdinal: sourceOrdinal
                    )
                }
                particulars.append((fragment: fragment, index: index))
            } else {
                throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                    sourceOrdinal: sourceOrdinal
                )
            }
        }

        guard chequeReferences.count <= 1,
              balances.count == 1,
              branches.count == 1 else {
            if balances.isEmpty {
                throw AxisBankAccountPDFNormalizationError.missingBalance(
                    sourceOrdinal: sourceOrdinal
                )
            }
            if branches.isEmpty {
                throw AxisBankAccountPDFNormalizationError.missingBranch(
                    sourceOrdinal: sourceOrdinal
                )
            }
            throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                sourceOrdinal: sourceOrdinal
            )
        }
        guard debits.count <= 1, credits.count <= 1,
              !(debits.isEmpty && credits.isEmpty) else {
            throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                sourceOrdinal: sourceOrdinal
            )
        }

        // Geometry establishes strict row ownership, but PDFKit's page-string
        // token order is the source authority for narration within that row.
        // Re-sorting tokens by subtly different baselines can scramble a
        // single printed line, while top-to-bottom sorting can place an
        // upward wrapped continuation before its anchor-line text.
        let orderedParticulars = particulars.sorted { $0.index < $1.index }
        let narrative = orderedParticulars.map(\.fragment.text).joined(separator: " ")
            .collapsingWhitespace
        guard !narrative.isEmpty else {
            throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                sourceOrdinal: sourceOrdinal
            )
        }

        return ParsedTransaction(
            sourceOrdinal: sourceOrdinal,
            sourcePage: page.pageNumber,
            date: dateText,
            chequeReference: chequeReferences.first ?? "",
            particulars: narrative,
            sourceDebit: debits.first ?? "",
            sourceCredit: credits.first ?? "",
            collapsedAmount: "",
            balance: balances[0],
            branchCode: branches[0]
        )
    }

    private static func isAxisDateText(_ text: String) -> Bool {
        text.collapsingWhitespace.range(
            of: #"^\d{2}-\d{2}-\d{4}$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isBranchText(_ text: String) -> Bool {
        text.collapsingWhitespace.range(
            of: #"^\d{3,6}$"#,
            options: .regularExpression
        ) != nil
    }

    private static func geometryMedian(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let ordered = values.sorted()
        let middle = ordered.count / 2
        if ordered.count.isMultiple(of: 2) {
            return (ordered[middle - 1] + ordered[middle]) / 2
        }
        return ordered[middle]
    }

    private static func geometryCenterClusters(
        _ centers: [Double],
        maximumGap: Double
    ) -> [GeometryAmountCluster] {
        guard !centers.isEmpty else { return [] }
        let ordered = centers.sorted()
        var groups: [[Double]] = []
        for center in ordered {
            if let last = groups.indices.last,
               let previous = groups[last].last,
               center - previous <= maximumGap {
                groups[last].append(center)
            } else {
                groups.append([center])
            }
        }
        return groups.compactMap { values in
            guard let min = values.min(), let max = values.max(),
                  let center = geometryMedian(values) else { return nil }
            return GeometryAmountCluster(
                center: center,
                minCenter: min,
                maxCenter: max,
                count: values.count
            )
        }
    }

    private static func geometryXGroups(
        indices: [Int],
        fragments: [RawPDFTextFragment],
        maximumGap: Double
    ) -> [[Int]] {
        let ordered = indices.sorted {
            let left = fragments[$0].geometry?.minX ?? fragments[$0].x
            let right = fragments[$1].geometry?.minX ?? fragments[$1].x
            if abs(left - right) > 0.1 { return left < right }
            return $0 < $1
        }
        var groups: [[Int]] = []
        for index in ordered {
            let x = fragments[index].geometry?.minX ?? fragments[index].x
            if let last = groups.indices.last,
               let previousIndex = groups[last].last {
                let previousX = fragments[previousIndex].geometry?.minX ?? fragments[previousIndex].x
                if x - previousX <= maximumGap {
                    groups[last].append(index)
                    continue
                }
            }
            groups.append([index])
        }
        return groups
    }

    private static func geometryRowIndex(
        baselineY: Double,
        anchors: [Double]
    ) -> Int? {
        guard baselineY.isFinite,
              !anchors.isEmpty,
              geometryAnchorsAreUnique(anchors) else {
            return nil
        }
        for index in anchors.indices {
            let upperBoundary = index == anchors.startIndex
                ? anchors[index] + geometryTopOuterBand(anchors: anchors)
                : anchors[index - 1] - geometryOwnershipTolerance
            let lowerBoundary = anchors[index] - geometryOwnershipTolerance
            // PDFKit's page-space baseline increases upwards. A row owns the
            // source-proven interval at/above its date anchor and strictly
            // below the preceding date anchor. This intentionally differs
            // from nearest-anchor ownership: wrapped Particulars can be
            // closer to the preceding date while still belonging to the
            // later row. The tolerance keeps same-baseline amount, balance,
            // and branch fragments with their date anchor.
            guard baselineY < upperBoundary,
                  baselineY > lowerBoundary else { continue }
            return index
        }
        return nil
    }

    private static let geometryOwnershipTolerance = 1.5
    private static let geometryOuterBand = 3.0
    private static let geometryBoundaryEpsilon = 0.1

    private static func geometryTopOuterBand(
        anchors: [Double]
    ) -> Double {
        guard anchors.count > 1 else { return geometryOuterBand }
        let adjacentSpacing = anchors[0] - anchors[1]
        return max(
            geometryOuterBand,
            adjacentSpacing - geometryOwnershipTolerance
        )
    }

    private static func geometryAnchorsAreUnique(
        _ anchors: [Double]
    ) -> Bool {
        anchors.allSatisfy(\.isFinite) &&
            zip(anchors, anchors.dropFirst()).allSatisfy {
                $0 > $1 + (2 * geometryOwnershipTolerance)
            }
    }

    private static func geometryRowBoundaryIsAmbiguous(
        baselineY: Double,
        anchors: [Double]
    ) -> Bool {
        guard baselineY.isFinite,
              geometryAnchorsAreUnique(anchors) else {
            return false
        }
        return anchors.dropLast().contains { upperAnchor in
            abs(
                baselineY -
                    (upperAnchor - geometryOwnershipTolerance)
            ) <= geometryBoundaryEpsilon
        }
    }

    private func parseTransaction(
        _ group: [PhysicalLine],
        sourcePage: Int?
    ) throws -> ParsedTransaction {
        guard let first = group.first,
              let dateCapture = first.normalizedText.captures(
                  matching: #"^(\d{2}-\d{2}-\d{4})(?:\s+(.*))?$"#
              ),
              dateCapture.count == 2 else {
            throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                sourceOrdinal: group.first?.sourceOrdinal ?? 0
            )
        }

        let dateText = dateCapture[0]
        do {
            _ = try StatementDate.axisNRE(dateText)
        } catch {
            throw AxisBankAccountPDFNormalizationError.malformedDate(
                sourceOrdinal: first.sourceOrdinal
            )
        }

        let content = ([dateCapture[1]] + group.dropFirst().map(\.normalizedText))
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let tokens = content.split(whereSeparator: \.isWhitespace).map(String.init)
        guard tokens.count >= 3 else {
            throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                sourceOrdinal: first.sourceOrdinal
            )
        }

        guard let branch = tokens.last,
              branch.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw AxisBankAccountPDFNormalizationError.missingBranch(
                sourceOrdinal: first.sourceOrdinal
            )
        }
        let branchIndex = tokens.index(before: tokens.endIndex)
        guard branchIndex > tokens.startIndex else {
            throw AxisBankAccountPDFNormalizationError.missingBalance(
                sourceOrdinal: first.sourceOrdinal
            )
        }
        let balanceIndex = tokens.index(before: branchIndex)
        guard Self.isMoneyText(tokens[balanceIndex]) else {
            throw AxisBankAccountPDFNormalizationError.missingBalance(
                sourceOrdinal: first.sourceOrdinal
            )
        }

        var selectedIndices: Set<Int> = [branchIndex, balanceIndex]
        var sourceDebit = ""
        var sourceCredit = ""
        var collapsedAmount = ""

        let beforeBalance = tokens[..<balanceIndex]
        guard !beforeBalance.isEmpty else {
            throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                sourceOrdinal: first.sourceOrdinal
            )
        }

        let immediatelyBeforeBalance = beforeBalance.index(before: beforeBalance.endIndex)
        if tokens[immediatelyBeforeBalance] == "-",
           immediatelyBeforeBalance > beforeBalance.startIndex {
            let debitIndex = beforeBalance.index(before: immediatelyBeforeBalance)
            if Self.isMoneyText(tokens[debitIndex]) {
                sourceDebit = Self.canonicalMoneyText(tokens[debitIndex])
                selectedIndices.formUnion([debitIndex, immediatelyBeforeBalance])
            }
        } else if Self.isMoneyText(tokens[immediatelyBeforeBalance]) {
            if immediatelyBeforeBalance > beforeBalance.startIndex {
                let secondBeforeBalance = beforeBalance.index(before: immediatelyBeforeBalance)
                if tokens[secondBeforeBalance] == "-" {
                    sourceCredit = Self.canonicalMoneyText(tokens[immediatelyBeforeBalance])
                    selectedIndices.formUnion([secondBeforeBalance, immediatelyBeforeBalance])
                } else if Self.isMoneyText(tokens[secondBeforeBalance]) {
                    sourceDebit = Self.canonicalMoneyText(tokens[secondBeforeBalance])
                    sourceCredit = Self.canonicalMoneyText(tokens[immediatelyBeforeBalance])
                    selectedIndices.formUnion([secondBeforeBalance, immediatelyBeforeBalance])
                } else {
                    collapsedAmount = Self.canonicalMoneyText(tokens[immediatelyBeforeBalance])
                    selectedIndices.insert(immediatelyBeforeBalance)
                }
            } else {
                collapsedAmount = Self.canonicalMoneyText(tokens[immediatelyBeforeBalance])
                selectedIndices.insert(immediatelyBeforeBalance)
            }
        }

        if sourceDebit.isEmpty && sourceCredit.isEmpty && collapsedAmount.isEmpty {
            guard let amountIndex = beforeBalance.indices.reversed().first(where: {
                Self.isMoneyText(tokens[$0])
            }) else {
                throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                    sourceOrdinal: first.sourceOrdinal
                )
            }
            collapsedAmount = Self.canonicalMoneyText(tokens[amountIndex])
            selectedIndices.insert(amountIndex)
        }

        var narrativeTokens = tokens.indices.compactMap {
            selectedIndices.contains($0) ? nil : tokens[$0]
        }
        guard !narrativeTokens.contains(where: { Self.isMoneyText($0) }) else {
            throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                sourceOrdinal: first.sourceOrdinal
            )
        }
        var chequeReference = ""
        if let firstNarrativeToken = narrativeTokens.first,
           Self.isChequeReference(firstNarrativeToken) {
            chequeReference = firstNarrativeToken
            narrativeTokens.removeFirst()
        }
        let particulars = narrativeTokens.joined(separator: " ")
        guard !particulars.isEmpty else {
            throw AxisBankAccountPDFNormalizationError.incompleteTransaction(
                sourceOrdinal: first.sourceOrdinal
            )
        }

        return ParsedTransaction(
            sourceOrdinal: first.sourceOrdinal,
            sourcePage: sourcePage,
            date: dateText,
            chequeReference: chequeReference,
            particulars: particulars,
            sourceDebit: sourceDebit,
            sourceCredit: sourceCredit,
            collapsedAmount: collapsedAmount,
            balance: Self.canonicalMoneyText(tokens[balanceIndex]),
            branchCode: branch
        )
    }

    private func rejectFinancialContent(
        in lines: [PhysicalLine],
        from startIndex: Int,
        to endIndex: Int
    ) throws {
        guard startIndex < endIndex else { return }

        for index in startIndex..<endIndex where lines.indices.contains(index) {
            let line = lines[index]
            if Self.looksFinancial(line.normalizedText) {
                throw AxisBankAccountPDFNormalizationError.unconsumedFinancialContent(
                    sourceOrdinal: line.sourceOrdinal
                )
            }
        }
    }

    private static func startsWithDate(
        _ text: String
    ) -> Bool {
        text.range(
            of: #"^\d{2}-\d{2}-\d{4}(?:\s|$)"#,
            options: .regularExpression
        ) != nil
    }

    private static func startsWithDateLikeToken(
        _ text: String
    ) -> Bool {
        text.range(
            of: #"^(?:\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}|\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}(?:[-/.][A-Z]{3,9}[-/.]|\s+[A-Z]{3,9},?\s+)\d{2,4}|[A-Z]{3,9}\s+\d{1,2},?\s+\d{2,4})(?:\s|$|[,;:])"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func isChequeReference(
        _ token: String
    ) -> Bool {
        if token == "-" {
            return true
        }
        return (4...20).contains(token.count) &&
            token.allSatisfy({ $0.isASCII && $0.isNumber })
    }

    private static func isMoneyText(
        _ text: String
    ) -> Bool {
        text.range(
            of: #"^"# + moneyPattern + #"$"#,
            options: .regularExpression
        ) != nil
    }

    private static func canonicalMoneyText(
        _ text: String
    ) -> String {
        var value = text.replacingOccurrences(of: ",", with: "")
        if value.hasPrefix("-.") {
            value.insert("0", at: value.index(after: value.startIndex))
        } else if value.hasPrefix(".") {
            value.insert("0", at: value.startIndex)
        }
        return value
    }

    private static func looksLikeTableHeader(
        _ text: String
    ) -> Bool {
        let labels = [
            "Tran Date", "Chq No", "Particulars",
            "Debit", "Credit", "Balance", "Init."
        ]
        return labels.filter { text.contains($0) }.count >= 4
    }

    private static func startsIgnorableNonFinancialBlock(
        _ text: String
    ) -> Bool {
        text == "Legend" ||
            text == "Legend:" ||
            text == "++++ End of Statement ++++" ||
            text.range(
                of: #"^Page\s+[0-9]+\s+of\s+[0-9]+$"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
    }

    static func looksFinancial(
        _ text: String
    ) -> Bool {
        guard !text.isEmpty else { return false }
        if text.hasPrefix(openingPrefix) ||
            text.hasPrefix(totalPrefix) ||
            text.hasPrefix(closingPrefix) ||
            looksLikeTableHeader(text) {
            return true
        }
        if startsWithDateLikeToken(text) {
            return true
        }

        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        for token in tokens where looksLikeMoneyToken(token) {
            return true
        }
        return false
    }

    private static func looksLikeMoneyToken(
        _ token: String
    ) -> Bool {
        let decorations = CharacterSet(charactersIn: ",;:()[]{}₹$€£")
        let undecorated = token.trimmingCharacters(in: decorations)
        return !undecorated.isEmpty && isMoneyText(undecorated)
    }

    private static let splitHeader =
        "Tran Date Chq No Particulars Debit Credit Balance Init."
    private static let completeHeader =
        "Tran Date Chq No Particulars Debit Credit Balance Init. Br"
    private static let openingPrefix = "OPENING BALANCE"
    private static let totalPrefix = "TRANSACTION TOTAL"
    private static let closingPrefix = "CLOSING BALANCE"
    private static let moneyPattern =
        #"-?(?:(?:[0-9]{1,3}(?:,[0-9]{3})+)|[0-9]+)?\.[0-9]{2}"#
}

private extension String {
    var collapsingWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    func captures(
        matching pattern: String
    ) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: self,
                  range: NSRange(startIndex..., in: self)
              ),
              match.range == NSRange(startIndex..., in: self) else {
            return nil
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: self) else {
                return ""
            }
            return String(self[range])
        }
    }
}
