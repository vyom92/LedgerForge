import Foundation
import CoreGraphics
import CryptoKit

nonisolated enum CBQCurrentAccountPDFFamily: String, Equatable, Sendable {
    case history
    case legacyCurrent
    case monthly
    case usdMonthly
    case savingsLegacy
    case savingsMonthly
    case eSavingsMonthly

    var profileID: String {
        switch self {
        case .history: return "cbq.current-account.history.pdf"
        case .legacyCurrent: return "cbq.current-account.legacy.pdf"
        case .monthly: return "cbq.current-account.monthly.pdf"
        case .usdMonthly: return "cbq.current-account.usd-monthly.pdf"
        case .savingsLegacy: return "cbq.savings-account.legacy.pdf"
        case .savingsMonthly: return "cbq.savings-account.monthly.pdf"
        case .eSavingsMonthly: return "cbq.e-savings-account.monthly.pdf"
        }
    }
}

nonisolated enum CBQCurrentAccountPDFNormalizationError: Error, Equatable, LocalizedError {
    case unsupportedNativeText
    case lockedDocument
    case ambiguousFamily
    case malformedPreamble
    case missingHeader
    case changedHeader
    case noTransactions
    case malformedTransaction(sourceOrdinal: Int)
    case unconsumedFinancialPage(page: Int)
    case unresolvedNarrationRegion(page: Int, sourceOrdinal: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedNativeText: return "The CBQ PDF must contain native selectable text."
        case .lockedDocument: return "Locked CBQ PDFs are outside the supported profiles."
        case .ambiguousFamily: return "The CBQ PDF does not identify exactly one retained current-account family."
        case .malformedPreamble: return "The CBQ current-account PDF preamble is incomplete or contradictory."
        case .missingHeader: return "The exact CBQ current-account PDF transaction header is missing."
        case .changedHeader: return "The CBQ current-account PDF transaction columns changed."
        case .noTransactions: return "The CBQ current-account PDF contains no accepted transaction rows."
        case .malformedTransaction(let ordinal): return "CBQ PDF transaction at source position \(ordinal) is incomplete or ambiguous."
        case .unconsumedFinancialPage(let page): return "CBQ PDF page \(page) contains unconsumed financial-table evidence."
        case .unresolvedNarrationRegion(let page, let ordinal):
            return "CBQ PDF page \(page), source position \(ordinal), has text whose transaction ownership is unresolved."
        }
    }
}

nonisolated struct CBQCurrentAccountPDFNormalizationResult {
    let family: CBQCurrentAccountPDFFamily
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow
    let sourceContext: NormalizedDocument.SourceContext
}

/// Normalizes the two retained CBQ current-account PDF families.
///
/// Password handling remains at `PDFDocumentReader`.  The monthly profile
/// consumes native page text and positioned fragments from that reader instead
/// of reopening encrypted source bytes.
nonisolated final class CBQCurrentAccountPDFNormalizer {
    static let logicalHeader = ["Posting Date", "Description", "Source Transaction Date", "Signed Amount", "Balance"]
    private static let historyDatePattern = #"^[0-9]{2}/[0-9]{2}/[0-9]{4}$"#
    private static let monthlyDatePattern = #"^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$"#
    private static let legacyDatePattern = #"^[0-9]{2}[A-Za-z]{3}[0-9]{2}$"#
    private static let moneyPattern = #"^-?[0-9]+(?:,[0-9]{3})*\.[0-9]{2}$"#
    private static let monthlyHeader = "Posting Date Transaction Description Transaction Date Debit Credit Balance"

    private struct Token {
        let pageIndex: Int
        let tokenIndex: Int
        let visualRow: Int
        let text: String
        let bounds: CGRect
        var sourceOrdinal: Int { pageIndex * 100_000 + tokenIndex }
    }

    private struct VisualLine {
        let pageIndex: Int
        let visualRow: Int
        let tokens: [Token]
        let midY: CGFloat
        var text: String { tokens.map(\.text).joined(separator: " ") }
    }

    private struct MonthlyLayout {
        let postingX: CGFloat
        let descriptionX: CGFloat
        let transactionDateX: CGFloat
        let debitX: CGFloat
        let creditX: CGFloat
        let balanceX: CGFloat

        var postingBoundary: CGFloat { (postingX + descriptionX) / 2 }
        var descriptionBoundary: CGFloat { transactionDateX - 1 }
        var transactionBoundary: CGFloat { (transactionDateX + debitX) / 2 }
        var debitBoundary: CGFloat { (debitX + creditX) / 2 }
        var creditBoundary: CGFloat { (creditX + balanceX) / 2 }

    }

    private struct MonthlyBlock {
        let pageIndex: Int
        let start: Token
        let layout: MonthlyLayout
        var lines: [VisualLine]
    }

    private struct LegacyLayout {
        let postX: CGFloat
        let narrativeX: CGFloat
        let valueX: CGFloat
        let debitX: CGFloat
        let creditX: CGFloat
        let balanceX: CGFloat

        var postBoundary: CGFloat { (postX + narrativeX) / 2 }
        var narrativeBoundary: CGFloat { valueX - 1 }
        var valueBoundary: CGFloat { (valueX + debitX) / 2 }
        var debitBoundary: CGFloat { (debitX + creditX) / 2 }
        var creditBoundary: CGFloat { (creditX + balanceX) / 2 }
    }

    private struct LegacyBlock {
        let pageIndex: Int
        let start: Token
        let layout: LegacyLayout
        var lines: [VisualLine]
    }

    /// Transient, statement-owned geometry learned from prose after its final
    /// closing control. It is neither a fixed page margin nor a sentence list.
    private struct MonthlyFurnitureBand {
        let lowerY: CGFloat
        let upperY: CGFloat
    }

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) { self.now = now }

    /// Legacy/source-bytes entry point retained for unlocked non-product tests.
    /// Product password-protected imports use the page/evidence overload below.
    func normalize(
        text: String,
        pageTexts pages: [String],
        pageEvidence: [RawPDFPageEvidence]? = nil,
        fileURL: URL
    ) throws -> CBQCurrentAccountPDFNormalizationResult {
        guard !pages.isEmpty else {
            throw CBQCurrentAccountPDFNormalizationError.unsupportedNativeText
        }
        let joined = pages.joined(separator: "\n")
        guard joined == text || Self.boundedWhitespace(joined) == Self.boundedWhitespace(text) else {
            throw CBQCurrentAccountPDFNormalizationError.unsupportedNativeText
        }
        let bounded = Self.boundedWhitespace(joined)
        let isHistory = bounded.range(of: #"\bTRANSACTION HISTORY\b"#, options: [.caseInsensitive, .regularExpression]) != nil
            && bounded.range(of: #"\bCURRENT ACCOUNT-RETAIL\b"#, options: [.caseInsensitive, .regularExpression]) != nil
        let isMonthly = bounded.range(of: #"\bACCOUNT STATEMENT\b"#, options: [.caseInsensitive, .regularExpression]) != nil
            && bounded.range(of: #"\bAccount Type:\s*Current Account-Retail\b"#, options: [.caseInsensitive, .regularExpression]) != nil
        let isSavingsMonthly = bounded.range(of: #"\bACCOUNT STATEMENT\b"#, options: [.caseInsensitive, .regularExpression]) != nil
            && bounded.range(of: #"\bAccount Type:\s*Savings Account\b"#, options: [.caseInsensitive, .regularExpression]) != nil
        let isESavingsMonthly = bounded.range(of: #"\bACCOUNT STATEMENT\b"#, options: [.caseInsensitive, .regularExpression]) != nil
            && bounded.range(of: #"\bAccount Type:\s*E Savings Account\b"#, options: [.caseInsensitive, .regularExpression]) != nil
        let isLegacyCurrent = bounded.range(of: #"\bYOUR BANK STATEMENT\b"#, options: [.caseInsensitive, .regularExpression]) != nil
            && bounded.range(of: #"\bCURRENT ACCOUNT-RETAIL\b"#, options: [.caseInsensitive, .regularExpression]) != nil
            && bounded.range(of: #"\bPOST DATE\s+NARRATIVE\s+VALUE DATE\s+DEBIT\s+CREDIT\s+BOOK BALANCE\b"#, options: [.caseInsensitive, .regularExpression]) != nil
        let isSavingsLegacy = bounded.range(of: #"\bYOUR BANK STATEMENT\b"#, options: [.caseInsensitive, .regularExpression]) != nil
            && bounded.range(of: #"\bSAVINGS ACCOUNT\b"#, options: [.caseInsensitive, .regularExpression]) != nil
            && bounded.range(of: #"\bPOST DATE\s+NARRATIVE\s+VALUE DATE\s+DEBIT\s+CREDIT\s+BOOK BALANCE\b"#, options: [.caseInsensitive, .regularExpression]) != nil
        let isUSDMonthly = isMonthly &&
            bounded.range(of: #"\bCurrency:\s*US DOLLARS\b"#, options: [.caseInsensitive, .regularExpression]) != nil
        let isQARMonthly = isMonthly && !isUSDMonthly
        guard [isHistory, isQARMonthly, isUSDMonthly, isSavingsMonthly, isESavingsMonthly, isLegacyCurrent, isSavingsLegacy].filter({ $0 }).count == 1 else {
            throw CBQCurrentAccountPDFNormalizationError.ambiguousFamily
        }
        guard let pageEvidence, pageEvidence.count == pages.count else {
            throw CBQCurrentAccountPDFNormalizationError.unsupportedNativeText
        }
        if isHistory {
            return try normalizeHistory(pages: pages, evidence: pageEvidence, fileURL: fileURL, boundedText: bounded)
        }
        if isLegacyCurrent || isSavingsLegacy {
            return try normalizeLegacy(pages: pages, evidence: pageEvidence, fileURL: fileURL, boundedText: bounded,
                                       family: isLegacyCurrent ? .legacyCurrent : .savingsLegacy,
                                       product: isLegacyCurrent ? "Current Account-Retail" : "Savings Account")
        }
        let family: CBQCurrentAccountPDFFamily = isUSDMonthly ? .usdMonthly : isQARMonthly ? .monthly : isSavingsMonthly ? .savingsMonthly : .eSavingsMonthly
        let product = (isQARMonthly || isUSDMonthly) ? "Current Account-Retail" : isSavingsMonthly ? "Savings Account" : "E Savings Account"
        return try normalizeMonthly(pages: pages, evidence: pageEvidence, fileURL: fileURL, boundedText: bounded,
                                    family: family, product: product,
                                    currencyLiteral: isUSDMonthly ? "US DOLLARS" : "QATARI RIYAL",
                                    currencyCode: isUSDMonthly ? "USD" : "QAR")
    }

    // MARK: History profile

    private func normalizeHistory(
        pages: [String],
        evidence: [RawPDFPageEvidence],
        fileURL: URL,
        boundedText: String
    ) throws -> CBQCurrentAccountPDFNormalizationResult {
        guard let account = Self.uniqueCapture(#"\b([0-9]{13})\s+CURRENT ACCOUNT-RETAIL\b"#, in: boundedText) else {
            throw CBQCurrentAccountPDFNormalizationError.malformedPreamble
        }
        var rows: [NormalizedRow] = []
        var retainedStarts: [CGFloat]?
        var totalTokens = 0
        for pageIndex in pages.indices {
            let tokens = Self.tokens(from: evidence[pageIndex], pageIndex: pageIndex)
            totalTokens += tokens.count
            guard !tokens.isEmpty else { throw CBQCurrentAccountPDFNormalizationError.unsupportedNativeText }
            let lines = Self.lines(from: tokens)
            let headers = lines.filter { $0.text == "Date Details Amount Balance" }
            let starts: [CGFloat]
            let headerY: CGFloat
            if headers.count == 1, let header = headers.first {
                let headerTokens = header.tokens.sorted { $0.bounds.minX < $1.bounds.minX }
                guard headerTokens.count == 4 else { throw CBQCurrentAccountPDFNormalizationError.changedHeader }
                starts = headerTokens.map(\.bounds.minX)
                if let retainedStarts, zip(retainedStarts, starts).contains(where: { abs($0 - $1) > 8 }) {
                    throw CBQCurrentAccountPDFNormalizationError.changedHeader
                }
                retainedStarts = starts
                headerY = header.midY
            } else if headers.isEmpty, let retainedStarts {
                starts = retainedStarts
                headerY = .greatestFiniteMagnitude
            } else {
                throw CBQCurrentAccountPDFNormalizationError.missingHeader
            }
            let boundaries = [(starts[0] + starts[1]) / 2, (starts[1] + starts[2]) / 2,
                              (starts[2] + starts[3]) / 2]
            let startsOfRows = tokens.filter {
                $0.bounds.minX < boundaries[0]
                    && $0.bounds.midY < headerY - 3
                    && Self.matches($0.text, Self.historyDatePattern)
            }.sorted { $0.bounds.midY > $1.bounds.midY }
            for (offset, start) in startsOfRows.enumerated() {
                let bottom = offset + 1 < startsOfRows.count
                    ? startsOfRows[offset + 1].bounds.midY + 1
                    : -.greatestFiniteMagnitude
                let block = tokens.filter {
                    $0.bounds.midY <= start.bounds.midY + 1 && $0.bounds.midY >= bottom
                }
                let dates = block.filter { $0.bounds.minX < boundaries[0] && Self.matches($0.text, Self.historyDatePattern) }
                let details = block.filter { $0.bounds.minX >= boundaries[0] && $0.bounds.minX < boundaries[1] }
                let amounts = block.filter {
                    $0.bounds.minX >= boundaries[1] && $0.bounds.minX < boundaries[2] && Self.matches($0.text, Self.moneyPattern)
                }
                let balances = block.filter {
                    $0.bounds.minX >= boundaries[2] && Self.matches($0.text, Self.moneyPattern)
                }
                guard dates.count == 1, dates[0].sourceOrdinal == start.sourceOrdinal,
                      !details.isEmpty, amounts.count == 1, balances.count == 1 else {
                    throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: start.sourceOrdinal)
                }
                let narration = Self.readingOrder(details).map(\.text).joined(separator: " ")
                guard !narration.isEmpty else {
                    throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: start.sourceOrdinal)
                }
                rows.append(NormalizedRow(
                    rowNumber: start.sourceOrdinal,
                    values: [start.text, narration, "", amounts[0].text, balances[0].text],
                    rawValues: [start.text, narration, "", amounts[0].text, balances[0].text],
                    sourcePage: pageIndex + 1
                ))
            }
        }
        guard !rows.isEmpty else { throw CBQCurrentAccountPDFNormalizationError.noTransactions }
        return result(
            family: .history,
            fileURL: fileURL,
            rows: rows,
            totalTokens: totalTokens,
            preamble: [.init(sourceOrdinal: 1, text: "ACCOUNT\t\(account)")]
        )
    }

    // MARK: Monthly profile

    private func normalizeLegacy(
        pages: [String], evidence: [RawPDFPageEvidence], fileURL: URL, boundedText: String,
        family: CBQCurrentAccountPDFFamily, product: String
    ) throws -> CBQCurrentAccountPDFNormalizationResult {
        guard let account = Self.uniqueCapture(#"\bAccount No\.?\s*:\s*([0-9Xx*-]+)"#, in: boundedText),
              let iban = Self.uniqueCapture(#"\bIBAN\s*:\s*([A-Za-z0-9Xx*]+)"#, in: boundedText),
              let boundary = Self.uniqueCapture(#"\bStmt\.\s*Date\s*:\s*([0-9]{2} [A-Za-z]{3} [0-9]{2})\b"#, in: boundedText),
              boundedText.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: product) + #"\b"#, options: [.caseInsensitive, .regularExpression]) != nil,
              boundedText.range(of: #"\bCurrency\s*:\s*QATARI RIYAL\b"#, options: [.caseInsensitive, .regularExpression]) != nil else {
            throw CBQCurrentAccountPDFNormalizationError.malformedPreamble
        }
        let pageTokens = evidence.enumerated().map {
            Self.tokens(from: $0.element, pageIndex: $0.offset, usesPositionOrderedText: true)
        }
        let totalTokens = pageTokens.reduce(0) { $0 + $1.count }
        guard totalTokens > 0 else { throw CBQCurrentAccountPDFNormalizationError.unsupportedNativeText }
        let pageLines = pageTokens.map(Self.lines)
        var layouts: [Int: LegacyLayout] = [:]
        var headers: [Int: VisualLine] = [:]
        var canonicalLayout: LegacyLayout?
        for (pageIndex, lines) in pageLines.enumerated() {
            let matches = lines.filter { Self.normalizedHeaderText($0.text) == "Post Date Narrative Value Date Debit Credit Book Balance" }
            guard matches.count <= 1 else { throw CBQCurrentAccountPDFNormalizationError.changedHeader }
            if let header = matches.first {
                let layout = try Self.legacyLayout(from: header)
                canonicalLayout = canonicalLayout ?? layout
                layouts[pageIndex] = layout
                headers[pageIndex] = header
            }
        }
        guard let canonicalLayout else { throw CBQCurrentAccountPDFNormalizationError.missingHeader }

        var blocks: [LegacyBlock] = []
        var current: LegacyBlock?
        var closingBalance: String?
        var closingOrdinal: Int?
        var closingRegionEnd: Int?
        var sawClosing = false
        var openingBalance: String?
        var openingOrdinal: Int?
        var periodStart: String?
        for (pageIndex, lines) in pageLines.enumerated() {
            let layout = layouts[pageIndex] ?? canonicalLayout
            for line in lines {
                if let header = headers[pageIndex], line.midY > header.midY + 3 { continue }
                if Self.normalizedHeaderText(line.text) == "Post Date Narrative Value Date Debit Credit Book Balance" { continue }
                if Self.isLegacyPageMarker(line, layout: layout) { continue }
                let narrative = Self.boundedWhitespace(line.tokens.filter {
                    $0.bounds.minX >= layout.postBoundary && $0.bounds.minX < layout.narrativeBoundary
                }.map(\.text).joined(separator: " "))
                // Position-ordered PDF fragments may retain the two literal
                // words as adjacent fragments. Treat only this exact source
                // label equivalently; no transaction narration is inferred.
                let normalizedNarrative = narrative.replacingOccurrences(of: " ", with: "").uppercased()
                let sourceLineLabel = line.text.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression).uppercased()
                if normalizedNarrative == "BROUGHTFORWARD" || sourceLineLabel.contains("BROUGHTFORWARD") {
                    let balances = line.tokens.filter {
                        $0.bounds.minX >= layout.creditBoundary && Self.matches($0.text, Self.moneyPattern)
                    }
                    guard openingBalance == nil, current == nil, blocks.isEmpty,
                          !sawClosing, balances.count == 1,
                          !line.tokens.contains(where: {
                              $0.bounds.minX >= layout.narrativeBoundary && $0.bounds.minX < layout.creditBoundary &&
                                  (Self.matches($0.text, Self.moneyPattern) || Self.matches($0.text, Self.legacyDatePattern))
                          }) else { throw CBQCurrentAccountPDFNormalizationError.malformedPreamble }
                    openingBalance = balances[0].text
                    openingOrdinal = line.tokens.first?.sourceOrdinal
                    // Five retained older originals print this opening date;
                    // the earliest source leaves it absent. Preserve both shapes.
                    periodStart = Self.legacyPostingDate(in: line, layout: layout)?.text
                    continue
                }
                if let footer = Self.legacyClosingBalance(in: line, layout: layout) {
                    if let current { blocks.append(current) }
                    current = nil
                    guard !sawClosing, !footer.isNeutral || Self.decimal(footer.money) == .zero else {
                        throw CBQCurrentAccountPDFNormalizationError.malformedPreamble
                    }
                    closingBalance = footer.money
                    closingOrdinal = line.tokens.first?.sourceOrdinal
                    closingRegionEnd = line.tokens.map(\.sourceOrdinal).max()
                    sawClosing = true
                    continue
                }
                if let posting = Self.legacyPostingDate(in: line, layout: layout) {
                    guard openingBalance != nil, !sawClosing else { throw CBQCurrentAccountPDFNormalizationError.unconsumedFinancialPage(page: pageIndex + 1) }
                    if let current { blocks.append(current) }
                    current = .init(pageIndex: pageIndex, start: posting, layout: layout, lines: [line])
                } else if current != nil, Self.isLegacyContinuation(line, layout: layout) {
                    current!.lines.append(line)
                } else if current != nil, Self.containsLegacyFinancialValue(line, layout: layout) {
                    throw CBQCurrentAccountPDFNormalizationError.unconsumedFinancialPage(page: pageIndex + 1)
                }
            }
        }
        if let current { blocks.append(current) }
        guard sawClosing, let closingBalance, let openingBalance, let openingOrdinal else {
            throw CBQCurrentAccountPDFNormalizationError.noTransactions
        }

        var rows: [NormalizedRow] = []
        var previousBalance = Self.decimal(openingBalance)
        var previousPosting = periodStart
        for block in blocks {
            let tokens = block.lines.flatMap(\.tokens)
            let layout = block.layout
            let narration = Self.boundedWhitespace(Self.readingOrder(tokens.filter {
                $0.bounds.minX >= layout.postBoundary && $0.bounds.minX < layout.narrativeBoundary
            }).map(\.text).joined(separator: " "))
            let valueDates = tokens.filter {
                $0.bounds.minX >= layout.narrativeBoundary && $0.bounds.minX < layout.valueBoundary && Self.matches($0.text, Self.legacyDatePattern)
            }
            let debits = tokens.filter {
                $0.bounds.minX >= layout.valueBoundary && $0.bounds.minX < layout.debitBoundary && Self.matches($0.text, Self.moneyPattern)
            }
            let credits = tokens.filter {
                $0.bounds.minX >= layout.debitBoundary && $0.bounds.minX < layout.creditBoundary && Self.matches($0.text, Self.moneyPattern)
            }
            let balances = tokens.filter { $0.bounds.minX >= layout.creditBoundary && Self.legacyBalanceText($0.text, family: family) != nil }
            guard !narration.isEmpty, valueDates.count == 1, (debits.count == 1) != (credits.count == 1), balances.count == 1,
                  let amount = Self.decimal(debits.first?.text ?? credits.first!.text), amount > .zero,
                  let balanceText = Self.legacyBalanceText(balances[0].text, family: family),
                  let balance = Self.decimal(balanceText) else {
                throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: block.start.sourceOrdinal)
            }
            let signed = debits.count == 1 ? -abs(amount) : abs(amount)
            if let previousBalance, previousBalance + signed != balance {
                throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: block.start.sourceOrdinal)
            }
            if let previousPosting, let previous = Self.legacyDateKey(previousPosting), let current = Self.legacyDateKey(block.start.text), current < previous {
                throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: block.start.sourceOrdinal)
            }
            previousBalance = balance
            previousPosting = block.start.text
            rows.append(.init(rowNumber: block.start.sourceOrdinal,
                              values: [block.start.text, narration, valueDates[0].text,
                                       debits.count == 1 ? "-\(debits[0].text)" : credits[0].text, balanceText],
                              rawValues: [block.start.text, narration, valueDates[0].text,
                                          debits.count == 1 ? "-\(debits[0].text)" : credits[0].text, balances[0].text],
                              sourcePage: block.pageIndex + 1))
        }
        let terminalBalance = rows.last.flatMap { Self.decimal($0.values.last ?? "") } ?? Self.decimal(openingBalance)
        guard let closingOrdinal, let closingRegionEnd,
              terminalBalance == Self.decimal(closingBalance),
              let headerPage = headers.keys.min(), let headerOrdinal = headers[headerPage]?.tokens.first?.sourceOrdinal else {
            throw CBQCurrentAccountPDFNormalizationError.malformedPreamble
        }
        func fieldOrdinal(_ label: String) -> Int? {
            pageLines.flatMap { $0 }.first(where: { $0.text.range(of: label, options: .caseInsensitive) != nil })?.tokens.first?.sourceOrdinal
        }
        guard let accountOrdinal = fieldOrdinal("Account No"), let ibanOrdinal = fieldOrdinal("IBAN"), let boundaryOrdinal = fieldOrdinal("Stmt.") else {
            throw CBQCurrentAccountPDFNormalizationError.malformedPreamble
        }
        return result(family: family, fileURL: fileURL, rows: rows, totalTokens: totalTokens, headerSourceOrdinal: headerOrdinal,
                      preamble: [.init(sourceOrdinal: accountOrdinal, text: "MASKED_ACCOUNT\t\(account)"),
                                 .init(sourceOrdinal: ibanOrdinal, text: "MASKED_IBAN\t\(iban)"),
                                 .init(sourceOrdinal: boundaryOrdinal, text: "STATEMENT_BOUNDARY\t\(boundary)"),
                                 .init(sourceOrdinal: boundaryOrdinal, text: "PRODUCT\t\(product)"),
                                 .init(sourceOrdinal: openingOrdinal, text: "OPENING_BALANCE\t\(openingBalance)"),
                                 .init(sourceOrdinal: closingOrdinal, text: "CLOSING_BALANCE\t\(closingBalance)"),
                                 .init(sourceOrdinal: headerOrdinal, text: "FINANCIAL_REGION_START\t\(headerOrdinal)"),
                                 .init(sourceOrdinal: closingOrdinal, text: "FINANCIAL_REGION_END\t\(closingRegionEnd)"),
                                 .init(sourceOrdinal: headerOrdinal, text: "FINANCIAL_REGION_SIGNATURE\t\(Self.financialRegionSignature(pageTokens, start: headerOrdinal, end: closingRegionEnd))")]
                        + (periodStart.map { [.init(sourceOrdinal: openingOrdinal, text: "PERIOD_START\t\($0)")] } ?? []))
    }

    private func normalizeMonthly(
        pages: [String],
        evidence: [RawPDFPageEvidence],
        fileURL: URL,
        boundedText: String,
        family: CBQCurrentAccountPDFFamily,
        product: String,
        currencyLiteral: String,
        currencyCode: String
    ) throws -> CBQCurrentAccountPDFNormalizationResult {
        let productPattern = #"\bAccount Type:\s*"# + NSRegularExpression.escapedPattern(for: product) + #"\b"#
        guard let account = Self.uniqueCapture(#"\bAccount No\.:\s*([0-9Xx* -]+)\s+Statement Date:"#, in: boundedText),
              let iban = Self.uniqueCapture(#"\bIBAN:\s*([A-Za-z0-9Xx* -]+)\s+Account No\."#, in: boundedText),
              let boundary = Self.uniqueCapture(#"\bStatement Date:\s*([0-9]{2} [A-Za-z]{3} [0-9]{2})\b"#, in: boundedText),
              boundedText.range(of: productPattern, options: [.caseInsensitive, .regularExpression]) != nil,
              boundedText.range(of: #"\bCurrency:\s*"# + NSRegularExpression.escapedPattern(for: currencyLiteral) + #"\b"#, options: [.caseInsensitive, .regularExpression]) != nil else {
            throw CBQCurrentAccountPDFNormalizationError.malformedPreamble
        }
        let pageTokens = evidence.enumerated().map { Self.tokens(from: $0.element, pageIndex: $0.offset) }
        let totalTokens = pageTokens.reduce(0) { $0 + $1.count }
        guard totalTokens > 0 else { throw CBQCurrentAccountPDFNormalizationError.unsupportedNativeText }
        let pageLines = pageTokens.map { Self.lines(from: $0) }
        var layouts: [Int: MonthlyLayout] = [:]
        var headersByPage: [Int: VisualLine] = [:]
        var canonicalLayout: MonthlyLayout?
        for (pageIndex, lines) in pageLines.enumerated() {
            let headers = lines.filter { Self.normalizedHeaderText($0.text) == Self.monthlyHeader }
            guard headers.count <= 1 else { throw CBQCurrentAccountPDFNormalizationError.changedHeader }
            if let header = headers.first {
                let layout = try Self.layout(from: header)
                canonicalLayout = canonicalLayout ?? layout
                layouts[pageIndex] = layout
                headersByPage[pageIndex] = header
            }
        }
        guard let canonicalLayout else { throw CBQCurrentAccountPDFNormalizationError.missingHeader }
        let furnitureBand = Self.monthlyFurnitureBand(
            pageLines: pageLines, evidence: evidence, layouts: layouts, headers: headersByPage
        )

        var blocks: [MonthlyBlock] = []
        var current: MonthlyBlock?
        var closingBalance: String?
        var closingSourceOrdinal: Int?
        var closingRegionEndOrdinal: Int?
        var sawClosingFooter = false
        var sawTable = false
        var undatedOpening: (balance: String, ordinal: Int)?
        for (pageIndex, lines) in pageLines.enumerated() {
            let layout = layouts[pageIndex] ?? canonicalLayout
            for line in lines {
                if let header = headersByPage[pageIndex], line.midY > header.midY + 3 {
                    continue
                }
                let rowText = Self.boundedWhitespace(line.text)
                if Self.normalizedHeaderText(rowText) == Self.monthlyHeader {
                    guard !sawClosingFooter else {
                        throw CBQCurrentAccountPDFNormalizationError.unconsumedFinancialPage(page: pageIndex + 1)
                    }
                    sawTable = true
                    continue
                }
                if Self.isPageMarker(line, layout: layout) {
                    continue
                }
                if let furnitureBand, headersByPage[pageIndex] != nil,
                   Self.isMonthlyPageFurniture(line, layout: layout, band: furnitureBand,
                                               pageBounds: evidence[pageIndex].bounds) {
                    // A page-local footer does not finish the transaction or
                    // the statement. A verified next-page table may continue it.
                    continue
                }
                if let footer = Self.closingBalance(in: line, layout: layout) {
                    if let current { blocks.append(current) }
                    current = nil
                    guard !sawClosingFooter else { throw CBQCurrentAccountPDFNormalizationError.malformedPreamble }
                    guard !footer.isNeutral || Self.decimal(footer.money) == .zero else {
                        throw CBQCurrentAccountPDFNormalizationError.malformedPreamble
                    }
                    closingBalance = footer.money
                    closingSourceOrdinal = line.tokens.first?.sourceOrdinal
                    closingRegionEndOrdinal = line.tokens.map(\.sourceOrdinal).max()
                    sawClosingFooter = true
                    continue
                }
                if family != .monthly, Self.postingDateToken(in: line, layout: layout) == nil,
                   Self.boundedWhitespace(line.tokens.filter {
                       $0.bounds.minX >= layout.postingBoundary && $0.bounds.minX < layout.descriptionBoundary
                   }.map(\.text).joined(separator: " ")) == "BROUGHT FORWARD" {
                    let balances = line.tokens.filter {
                        $0.bounds.minX >= layout.creditBoundary && Self.matches($0.text, Self.moneyPattern)
                    }
                    guard sawTable, !sawClosingFooter, blocks.isEmpty, current == nil,
                          undatedOpening == nil, balances.count == 1,
                          let ordinal = line.tokens.first?.sourceOrdinal,
                          !line.tokens.contains(where: {
                              $0.bounds.minX >= layout.descriptionBoundary && $0.bounds.minX < layout.creditBoundary &&
                                  (Self.matches($0.text, Self.monthlyDatePattern) || Self.matches($0.text, Self.moneyPattern))
                          }) else { throw CBQCurrentAccountPDFNormalizationError.malformedPreamble }
                    undatedOpening = (balances[0].text, ordinal)
                    continue
                }
                if let posting = Self.postingDateToken(in: line, layout: layout) {
                    guard sawTable, !sawClosingFooter else {
                        throw CBQCurrentAccountPDFNormalizationError.unconsumedFinancialPage(page: pageIndex + 1)
                    }
                    if let current { blocks.append(current) }
                    current = MonthlyBlock(pageIndex: pageIndex, start: posting, layout: layout, lines: [line])
                } else if current != nil, Self.isContinuationLine(line, layout: layout) {
                    current!.lines.append(line)
                } else if current != nil, line.tokens.contains(where: {
                    $0.bounds.minX >= layout.postingBoundary && $0.bounds.minX < layout.descriptionBoundary
                }) {
                    // Horizontal overlap alone cannot assign cross-column
                    // prose to an otherwise complete transaction.
                    throw CBQCurrentAccountPDFNormalizationError.unresolvedNarrationRegion(
                        page: pageIndex + 1, sourceOrdinal: line.tokens.first?.sourceOrdinal ?? 0
                    )
                } else if sawTable, Self.containsFinancialColumnValue(line, layout: layout) {
                    throw CBQCurrentAccountPDFNormalizationError.unconsumedFinancialPage(page: pageIndex + 1)
                }
            }
        }
        if let current { blocks.append(current) }
        guard sawClosingFooter, let closingBalance, !blocks.isEmpty else {
            throw CBQCurrentAccountPDFNormalizationError.noTransactions
        }

        var normalizedRows: [NormalizedRow] = []
        var openingBalance = undatedOpening?.balance
        var previousBalance = undatedOpening.flatMap { Self.decimal($0.balance) }
        var previousPostingDate: String?
        var openingSourceOrdinal = undatedOpening?.ordinal
        for block in blocks {
            let layout = block.layout
            let blockTokens = block.lines.flatMap(\.tokens)
            let descriptionTokens = Self.readingOrder(blockTokens.filter {
                $0.bounds.minX >= layout.postingBoundary && $0.bounds.minX < layout.descriptionBoundary
            })
            let description = Self.boundedWhitespace(descriptionTokens.map(\.text).joined(separator: " "))
            let sourceDates = blockTokens.filter {
                $0.bounds.minX >= layout.descriptionBoundary
                    && $0.bounds.minX < layout.transactionBoundary
                    && Self.matches($0.text, Self.monthlyDatePattern)
            }
            let debits = blockTokens.filter {
                $0.bounds.minX >= layout.transactionBoundary
                    && $0.bounds.minX < layout.debitBoundary
                    && Self.matches($0.text, Self.moneyPattern)
            }
            let credits = blockTokens.filter {
                $0.bounds.minX >= layout.debitBoundary
                    && $0.bounds.minX < layout.creditBoundary
                    && Self.matches($0.text, Self.moneyPattern)
            }
            let balances = blockTokens.filter {
                $0.bounds.minX >= layout.creditBoundary && Self.matches($0.text, Self.moneyPattern)
            }
            if description.uppercased() == "BROUGHT FORWARD" {
                guard openingBalance == nil, sourceDates.isEmpty, debits.isEmpty, credits.isEmpty, balances.count == 1 else {
                    throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: block.start.sourceOrdinal)
                }
                openingBalance = balances[0].text
                openingSourceOrdinal = block.start.sourceOrdinal
                previousBalance = Self.decimal(openingBalance!)
                previousPostingDate = block.start.text
                continue
            }
            guard openingBalance != nil,
                  !description.isEmpty,
                  sourceDates.count == 1,
                  (debits.count == 1) != (credits.count == 1),
                  balances.count == 1,
                  let amount = Self.decimal(debits.first?.text ?? credits.first!.text),
                  amount > .zero,
                  let balance = Self.decimal(balances[0].text),
                  let prior = previousBalance else {
                throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: block.start.sourceOrdinal)
            }
            let signed = debits.count == 1 ? -abs(amount) : abs(amount)
            guard prior + signed == balance else {
                throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: block.start.sourceOrdinal)
            }
            if let previousPostingDate,
               let previous = Self.monthlyDateKey(previousPostingDate),
               let currentDate = Self.monthlyDateKey(block.start.text),
               currentDate < previous {
                throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: block.start.sourceOrdinal)
            }
            previousPostingDate = block.start.text
            previousBalance = balance
            let signedText = debits.count == 1
                ? "-\(debits[0].text.replacingOccurrences(of: "-", with: ""))"
                : credits[0].text
            normalizedRows.append(NormalizedRow(
                rowNumber: block.start.sourceOrdinal,
                values: [block.start.text, description, sourceDates[0].text, signedText, balances[0].text],
                rawValues: [block.start.text, description, sourceDates[0].text, signedText, balances[0].text],
                sourcePage: block.pageIndex + 1
            ))
        }
        guard let openingBalance, let openingSourceOrdinal,
              let closingSourceOrdinal, let closingRegionEndOrdinal,
              Self.decimal(normalizedRows.last?.values.last ?? openingBalance) == Self.decimal(closingBalance) else {
            throw CBQCurrentAccountPDFNormalizationError.malformedPreamble
        }

        func fieldOrdinal(_ label: String) -> Int? {
            guard let line = pageLines.flatMap({ $0 }).first(where: {
                $0.text.range(of: label, options: .caseInsensitive) != nil
            }) else { return nil }
            let firstWord = label.split(separator: " ")[0]
            return line.tokens.first(where: { $0.text.caseInsensitiveCompare(String(firstWord)) == .orderedSame })?.sourceOrdinal
        }
        guard let accountOrdinal = fieldOrdinal("Account No.:"),
              let ibanOrdinal = fieldOrdinal("IBAN:"),
              let boundaryOrdinal = fieldOrdinal("Statement Date:"),
              let headerPage = headersByPage.keys.min(),
              let headerOrdinal = headersByPage[headerPage]?.tokens.first?.sourceOrdinal else {
            throw CBQCurrentAccountPDFNormalizationError.malformedPreamble
        }
        let periodStart = Self.periodStart(for: openingSourceOrdinal, in: blocks)

        return result(
            family: family,
            fileURL: fileURL,
            rows: normalizedRows,
            totalTokens: totalTokens,
            headerSourceOrdinal: headerOrdinal,
            preamble: [
                .init(sourceOrdinal: accountOrdinal, text: "MASKED_ACCOUNT\t\(account)"),
                .init(sourceOrdinal: ibanOrdinal, text: "MASKED_IBAN\t\(iban)"),
                .init(sourceOrdinal: accountOrdinal, text: "PRODUCT\t\(product)"),
                .init(sourceOrdinal: accountOrdinal, text: "CURRENCY_CODE\t\(currencyCode)"),
                .init(sourceOrdinal: boundaryOrdinal, text: "STATEMENT_BOUNDARY\t\(boundary)"),
                .init(sourceOrdinal: openingSourceOrdinal, text: "OPENING_BALANCE\t\(openingBalance)"),
                .init(sourceOrdinal: closingSourceOrdinal, text: "CLOSING_BALANCE\t\(closingBalance)"),
                .init(sourceOrdinal: headerOrdinal, text: "FINANCIAL_REGION_START\t\(headerOrdinal)"),
                .init(sourceOrdinal: closingSourceOrdinal, text: "FINANCIAL_REGION_END\t\(closingRegionEndOrdinal)"),
                .init(sourceOrdinal: headerOrdinal, text: "FINANCIAL_REGION_SIGNATURE\t\(Self.financialRegionSignature(pageTokens, start: headerOrdinal, end: closingRegionEndOrdinal))")
            ] + (periodStart.map { [.init(sourceOrdinal: openingSourceOrdinal, text: "PERIOD_START\t\($0)")] } ?? [])
        )
    }

    // MARK: Evidence and geometry

    private static func financialRegionSignature(_ pages: [[Token]], start: Int, end: Int) -> String {
        let source = Self.readingOrder(pages.flatMap { $0 }.filter {
            $0.sourceOrdinal >= start && $0.sourceOrdinal <= end
        }).map { "\($0.sourceOrdinal)\t\($0.text)" }.joined(separator: "\n")
        return SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func tokens(from evidence: RawPDFPageEvidence, pageIndex: Int,
                               usesPositionOrderedText: Bool = false) -> [Token] {
        var values: [(text: String, bounds: CGRect)] = []
        for fragment in evidence.fragments {
            let geometry = fragment.geometry
            let minX = CGFloat(geometry?.minX ?? fragment.x)
            let maxX = CGFloat(geometry?.maxX ?? (fragment.x + max(1, Double(fragment.text.count))))
            let y = CGFloat(geometry?.baselineY ?? fragment.y)
            guard minX.isFinite, maxX.isFinite, y.isFinite, maxX >= minX else { continue }
            let bounds = CGRect(x: minX, y: y - 0.5, width: max(0.5, maxX - minX), height: 1)
            values.append((usesPositionOrderedText ? (fragment.positionOrderedText ?? fragment.text) : fragment.text, bounds))
        }
        var groups: [(midY: CGFloat, values: [(String, CGRect)])] = []
        for value in values {
            if let index = groups.indices.min(by: {
                abs(groups[$0].midY - value.1.midY) < abs(groups[$1].midY - value.1.midY)
            }), abs(groups[index].midY - value.1.midY) <= 3 {
                groups[index].values.append(value)
            } else {
                groups.append((value.1.midY, [value]))
            }
        }
        var ordinal = 0
        return groups.sorted { $0.midY > $1.midY }.enumerated().flatMap { visualRow, group in
            group.values.sorted { $0.1.minX < $1.1.minX }.map { value in
                ordinal += 1
                return Token(pageIndex: pageIndex, tokenIndex: ordinal, visualRow: visualRow, text: value.0, bounds: value.1)
            }
        }
    }

    private static func lines(from tokens: [Token]) -> [VisualLine] {
        let grouped = Dictionary(grouping: tokens, by: { $0.visualRow })
        var result: [VisualLine] = []
        result.reserveCapacity(grouped.count)
        for row in grouped.values {
            guard let first = row.first else { continue }
            let sorted = row.sorted { $0.bounds.minX < $1.bounds.minX }
            let midY = row.map { $0.bounds.midY }.reduce(0, +) / CGFloat(row.count)
            result.append(VisualLine(pageIndex: first.pageIndex, visualRow: first.visualRow, tokens: sorted, midY: midY))
        }
        return result.sorted { $0.midY > $1.midY }
    }

    private static func layout(from header: VisualLine) throws -> MonthlyLayout {
        let tokens = header.tokens.sorted { $0.bounds.minX < $1.bounds.minX }
        guard tokens.map({ $0.text.lowercased() }) ==
            ["posting", "date", "transaction", "description", "transaction", "date", "debit", "credit", "balance"] else {
            throw CBQCurrentAccountPDFNormalizationError.changedHeader
        }
        let starts = tokens.prefix(9).map { $0.bounds.minX }
        guard starts == starts.sorted() else { throw CBQCurrentAccountPDFNormalizationError.changedHeader }
        return MonthlyLayout(
            postingX: starts[0], descriptionX: starts[2], transactionDateX: starts[4],
            debitX: starts[6], creditX: starts[7], balanceX: starts[8]
        )
    }

    private static func legacyLayout(from header: VisualLine) throws -> LegacyLayout {
        let tokens = header.tokens.sorted { $0.bounds.minX < $1.bounds.minX }
        guard tokens.map({ $0.text.lowercased() }) ==
            ["post", "date", "narrative", "value", "date", "debit", "credit", "book", "balance"] else {
            throw CBQCurrentAccountPDFNormalizationError.changedHeader
        }
        let starts = tokens.map(\.bounds.minX)
        guard starts == starts.sorted() else { throw CBQCurrentAccountPDFNormalizationError.changedHeader }
        return .init(postX: starts[0], narrativeX: starts[2], valueX: starts[3],
                     debitX: starts[5], creditX: starts[6], balanceX: starts[7])
    }

    private static func postingDateToken(in line: VisualLine, layout: MonthlyLayout) -> Token? {
        line.tokens.first { $0.bounds.minX < layout.postingBoundary && matches($0.text, monthlyDatePattern) }
    }

    private static func legacyPostingDate(in line: VisualLine, layout: LegacyLayout) -> Token? {
        line.tokens.first { $0.bounds.minX < layout.postBoundary && matches($0.text, legacyDatePattern) }
    }

    private struct ClosingBalance {
        let money: String
        let isNeutral: Bool
    }

    private static func closingBalance(in line: VisualLine, layout: MonthlyLayout) -> ClosingBalance? {
        let label = boundedWhitespace(line.text).uppercased()
        let isCredit = label.hasPrefix("* CREDIT BALANCE")
        let isNeutral = label.hasPrefix("* BALANCE")
        guard isCredit || isNeutral else { return nil }
        let values = line.tokens.filter {
            $0.bounds.minX >= layout.creditBoundary && matches($0.text, moneyPattern)
        }
        guard values.count == 1 else { return nil }
        return .init(money: values[0].text, isNeutral: isNeutral)
    }

    private static func legacyClosingBalance(in line: VisualLine, layout: LegacyLayout) -> ClosingBalance? {
        let label = boundedWhitespace(line.text).uppercased()
        let isCredit = label.hasPrefix("* CREDIT BALANCE")
        let isNeutral = label.hasPrefix("* BALANCE")
        guard isCredit || isNeutral else { return nil }
        let values = line.tokens.filter { $0.bounds.minX >= layout.creditBoundary && matches($0.text, moneyPattern) }
        guard values.count == 1 else { return nil }
        return .init(money: values[0].text, isNeutral: isNeutral)
    }

    private static func isContinuationLine(_ line: VisualLine, layout: MonthlyLayout) -> Bool {
        guard !line.tokens.isEmpty else { return false }
        if isPageMarker(line, layout: layout) { return false }
        // A wrapped narration/reference may contain any words, digits or dates.
        // Its source tokens must belong to the narrative column, not merely
        // overlap it as one part of a page-wide prose line. A long unbroken
        // reference keeps its complete token even when its rectangle extends.
        return line.tokens.allSatisfy {
            $0.bounds.minX >= layout.postingBoundary && $0.bounds.minX < layout.descriptionBoundary
        }
    }

    private static func isLegacyContinuation(_ line: VisualLine, layout: LegacyLayout) -> Bool {
        guard !line.tokens.isEmpty, !isLegacyPageMarker(line, layout: layout) else { return false }
        return line.tokens.allSatisfy {
            $0.bounds.minX >= layout.postBoundary && $0.bounds.minX < layout.narrativeBoundary
        }
    }

    private static func monthlyFurnitureBand(
        pageLines: [[VisualLine]], evidence: [RawPDFPageEvidence],
        layouts: [Int: MonthlyLayout], headers: [Int: VisualLine]
    ) -> MonthlyFurnitureBand? {
        let closingControls = headers.keys.sorted().flatMap { page -> [(Int, VisualLine)] in
            guard let layout = layouts[page], let header = headers[page] else { return [] }
            return pageLines[page].filter {
                $0.midY < header.midY && closingBalance(in: $0, layout: layout) != nil
            }.map { (page, $0) }
        }
        guard closingControls.count == 1, let (page, closing) = closingControls.first,
              page == headers.keys.max(), let layout = layouts[page],
              let bounds = usablePageBounds(evidence[page].bounds) else { return nil }
        let prose = pageLines[page].filter {
            $0.midY < closing.midY - 3 && !isPageMarker($0, layout: layout)
        }
        guard !prose.isEmpty,
              prose.contains(where: { hasProseOutsideNarration($0, layout: layout) }),
              prose.allSatisfy({ !hasMonthlyFinancialSignature($0, layout: layout) }),
              let bottom = prose.map(\.midY).min(), let top = prose.map(\.midY).max() else { return nil }
        // The three-point allowance is the existing visual-line grouping
        // tolerance, relative to this source page; no bottom-of-page cutoff.
        // The unique control's amount and position still must pass the ordinary
        // complete running-balance/closing checks before any result is returned.
        return .init(lowerY: (bottom - bounds.minY - 3) / bounds.height,
                     upperY: (top - bounds.minY + 3) / bounds.height)
    }

    private static func isMonthlyPageFurniture(
        _ line: VisualLine, layout: MonthlyLayout, band: MonthlyFurnitureBand, pageBounds: CGRect?
    ) -> Bool {
        guard let bounds = usablePageBounds(pageBounds) else { return false }
        let y = (line.midY - bounds.minY) / bounds.height
        return y >= band.lowerY && y <= band.upperY
            && hasProseOutsideNarration(line, layout: layout)
            && !hasMonthlyFinancialSignature(line, layout: layout)
    }

    private static func hasProseOutsideNarration(_ line: VisualLine, layout: MonthlyLayout) -> Bool {
        line.tokens.contains {
            ($0.bounds.minX < layout.postingBoundary || $0.bounds.minX >= layout.descriptionBoundary)
                && $0.text.rangeOfCharacter(from: .letters) != nil
        }
    }

    private static func hasMonthlyFinancialSignature(_ line: VisualLine, layout: MonthlyLayout) -> Bool {
        normalizedHeaderText(line.text) == monthlyHeader
            || postingDateToken(in: line, layout: layout) != nil
            || closingBalance(in: line, layout: layout) != nil
            || containsFinancialColumnValue(line, layout: layout)
            || boundedWhitespace(line.text).contains("BROUGHT FORWARD")
    }

    private static func usablePageBounds(_ bounds: CGRect?) -> CGRect? {
        guard let bounds, bounds.minX.isFinite, bounds.minY.isFinite,
              bounds.width.isFinite, bounds.height.isFinite,
              bounds.width > 0, bounds.height > 0 else { return nil }
        return bounds
    }

    private static func containsFinancialColumnValue(_ line: VisualLine, layout: MonthlyLayout) -> Bool {
        line.tokens.contains {
            ($0.bounds.minX >= layout.descriptionBoundary && $0.bounds.minX < layout.transactionBoundary && matches($0.text, monthlyDatePattern))
                || ($0.bounds.minX >= layout.transactionBoundary && matches($0.text, moneyPattern))
        }
    }

    private static func containsLegacyFinancialValue(_ line: VisualLine, layout: LegacyLayout) -> Bool {
        line.tokens.contains {
            ($0.bounds.minX >= layout.narrativeBoundary && $0.bounds.minX < layout.valueBoundary && matches($0.text, legacyDatePattern)) ||
                ($0.bounds.minX >= layout.valueBoundary && matches($0.text, moneyPattern)) ||
                ($0.bounds.minX >= layout.creditBoundary && legacyBalanceText($0.text, family: .legacyCurrent) != nil)
        }
    }

    /// The retained legacy Book Balance column prints a trailing minus for an
    /// overdraft. Normalize only that numeric role; rawValues retain its literal.
    private static func legacyBalanceText(_ source: String, family: CBQCurrentAccountPDFFamily) -> String? {
        CBQLegacyBookBalanceLiteral.canonicalText(source, profileID: family.profileID, version: "1")
    }

    private static func isPageMarker(_ line: VisualLine, layout: MonthlyLayout) -> Bool {
        line.tokens.count == 1 && line.tokens[0].bounds.minX >= layout.creditBoundary &&
            line.text.range(of: #"^[0-9]+/[0-9]+$"#, options: .regularExpression) != nil
    }

    private static func isLegacyPageMarker(_ line: VisualLine, layout: LegacyLayout) -> Bool {
        line.tokens.count == 1 && line.tokens[0].bounds.minX >= layout.creditBoundary &&
            line.text.range(of: #"^[0-9]+/[0-9]+$"#, options: .regularExpression) != nil
    }

    private static func normalizedHeaderText(_ text: String) -> String {
        boundedWhitespace(text).capitalized
    }

    private static func periodStart(for sourceOrdinal: Int, in blocks: [MonthlyBlock]) -> String? {
        blocks.first(where: { $0.start.sourceOrdinal == sourceOrdinal })?.start.text
    }

    private static func monthlyDateKey(_ source: String) -> Int? {
        let values = source.split(separator: "-")
        guard values.count == 3,
              let day = Int(values[0]),
              let month = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"].firstIndex(where: { $0.caseInsensitiveCompare(String(values[1])) == .orderedSame }),
              let year = Int(values[2]) else { return nil }
        return (2000 + year) * 10_000 + (month + 1) * 100 + day
    }

    private static func legacyDateKey(_ source: String) -> Int? {
        guard matches(source, legacyDatePattern) else { return nil }
        return monthlyDateKey("\(source.prefix(2))-\(source.dropFirst(2).prefix(3))-\(source.suffix(2))")
    }

    private static func decimal(_ source: String) -> Decimal? {
        Decimal(string: source.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
    }

    private func result(
        family: CBQCurrentAccountPDFFamily,
        fileURL: URL,
        rows: [NormalizedRow],
        totalTokens: Int,
        headerSourceOrdinal: Int = 1,
        preamble: [NormalizedDocument.SourceFragment]
    ) -> CBQCurrentAccountPDFNormalizationResult {
        var document = Document(
            filename: fileURL.lastPathComponent,
            url: fileURL,
            fileType: FileFormat.pdf.rawValue,
            importedAt: now()
        )
        document.rowCount = totalTokens
        document.headerRow = headerSourceOrdinal
        document.firstTransactionRow = rows.first?.rowNumber
        document.columnCount = Self.logicalHeader.count
        document.encoding = "UTF-8"
        return CBQCurrentAccountPDFNormalizationResult(
            family: family,
            document: document,
            rows: rows,
            header: NormalizedRow(rowNumber: headerSourceOrdinal, values: Self.logicalHeader),
            sourceContext: .init(preTransactionFragments: preamble + ([.legacyCurrent, .savingsLegacy].contains(family)
                ? [.init(sourceOrdinal: headerSourceOrdinal, text: "SOURCE_SECOND_DATE_ROLE\tvalue_date")]
                : []), postTransactionFragments: [])
        )
    }

    private static func readingOrder(_ tokens: [Token]) -> [Token] {
        tokens.sorted {
            if $0.pageIndex != $1.pageIndex { return $0.pageIndex < $1.pageIndex }
            if abs($0.bounds.midY - $1.bounds.midY) > 2 { return $0.bounds.midY > $1.bounds.midY }
            return $0.bounds.minX < $1.bounds.minX
        }
    }

    private static func boundedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func uniqueCapture(_ pattern: String, in text: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let values = matches.compactMap { match -> String? in
            guard match.numberOfRanges == 2, let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
        guard let first = values.first, values.allSatisfy({ $0 == first }) else { return nil }
        return first
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else { return false }
        return match.range == NSRange(value.startIndex..., in: value)
    }
}
