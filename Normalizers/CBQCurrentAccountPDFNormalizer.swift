import Foundation
import PDFKit

enum CBQCurrentAccountPDFFamily: String, Equatable, Sendable {
    case history
    case monthly

    var profileID: String {
        switch self {
        case .history: return "cbq.current-account.history.pdf"
        case .monthly: return "cbq.current-account.monthly.pdf"
        }
    }
}

enum CBQCurrentAccountPDFNormalizationError: Error, Equatable, LocalizedError {
    case unsupportedNativeText
    case lockedDocument
    case ambiguousFamily
    case malformedPreamble
    case missingHeader
    case changedHeader
    case noTransactions
    case malformedTransaction(sourceOrdinal: Int)
    case unconsumedFinancialPage(page: Int)

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
        }
    }
}

struct CBQCurrentAccountPDFNormalizationResult {
    let family: CBQCurrentAccountPDFFamily
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow
    let sourceContext: NormalizedDocument.SourceContext
}

final class CBQCurrentAccountPDFNormalizer {
    static let logicalHeader = ["Posting Date", "Description", "Source Transaction Date", "Signed Amount", "Balance"]
    private static let historyDatePattern = #"^[0-9]{2}/[0-9]{2}/[0-9]{4}$"#
    private static let monthlyDatePattern = #"^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$"#
    private static let moneyPattern = #"^-?[0-9]+(?:,[0-9]{3})*\.[0-9]{2}$"#

    private struct Token {
        let pageIndex: Int
        let tokenIndex: Int
        let visualRow: Int
        let text: String
        let bounds: CGRect
        var sourceOrdinal: Int { pageIndex * 100_000 + tokenIndex }
    }

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) { self.now = now }

    func normalize(text: String, sourceBytes: Data, fileURL: URL) throws -> CBQCurrentAccountPDFNormalizationResult {
        guard let pdf = PDFDocument(data: sourceBytes), pdf.pageCount > 0 else {
            throw CBQCurrentAccountPDFNormalizationError.unsupportedNativeText
        }
        guard !pdf.isLocked else { throw CBQCurrentAccountPDFNormalizationError.lockedDocument }
        let bounded = Self.boundedWhitespace(text)
        let isHistory = bounded.contains("Transaction History") && bounded.contains("CURRENT ACCOUNT-RETAIL")
        let isMonthly = bounded.contains("ACCOUNT STATEMENT") && bounded.contains("Account Type: Current Account-Retail")
        guard isHistory != isMonthly else { throw CBQCurrentAccountPDFNormalizationError.ambiguousFamily }
        return try isHistory
            ? normalizeHistory(pdf: pdf, fileURL: fileURL, boundedText: bounded)
            : normalizeMonthly(pdf: pdf, fileURL: fileURL, boundedText: bounded)
    }

    private func normalizeHistory(pdf: PDFDocument, fileURL: URL, boundedText: String) throws -> CBQCurrentAccountPDFNormalizationResult {
        guard let account = Self.uniqueCapture(#"\b([0-9]{13})\s+CURRENT ACCOUNT-RETAIL\b"#, in: boundedText) else {
            throw CBQCurrentAccountPDFNormalizationError.malformedPreamble
        }
        var rows: [NormalizedRow] = []
        var retainedStarts: [CGFloat]?
        var totalTokens = 0
        for pageIndex in 0..<pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else { throw CBQCurrentAccountPDFNormalizationError.unsupportedNativeText }
            let tokens = Self.tokens(on: page, pageIndex: pageIndex)
            totalTokens += tokens.count
            guard !tokens.isEmpty else { throw CBQCurrentAccountPDFNormalizationError.unsupportedNativeText }
            let grouped = Dictionary(grouping: tokens, by: \.visualRow)
            let headers = grouped.values.filter { Self.rowText($0) == "Date Details Amount Balance" }
            let starts: [CGFloat]
            let headerY: CGFloat
            if headers.count == 1, let header = headers.first {
                let headerTokens = header.sorted { $0.bounds.minX < $1.bounds.minX }
                guard headerTokens.count == 4 else { throw CBQCurrentAccountPDFNormalizationError.changedHeader }
                starts = headerTokens.map(\.bounds.minX)
                if let retainedStarts, zip(retainedStarts, starts).contains(where: { abs($0 - $1) > 3 }) {
                    throw CBQCurrentAccountPDFNormalizationError.changedHeader
                }
                retainedStarts = starts
                headerY = headerTokens.map(\.bounds.midY).reduce(0, +) / CGFloat(headerTokens.count)
            } else if headers.isEmpty, pageIndex > 0, let retainedStarts {
                starts = retainedStarts
                headerY = page.bounds(for: .mediaBox).maxY + 1
            } else {
                let words = Set(tokens.map(\.text))
                if ["Date", "Details", "Amount", "Balance"].filter(words.contains).count >= 2 {
                    throw CBQCurrentAccountPDFNormalizationError.changedHeader
                }
                throw CBQCurrentAccountPDFNormalizationError.missingHeader
            }
            let boundaries = [(starts[0] + starts[1]) / 2, (starts[1] + starts[2]) / 2, (starts[2] + starts[3]) / 2]
            let startsOfRows = tokens.filter {
                $0.bounds.minX < boundaries[0] && $0.bounds.midY < headerY - 3 && Self.matches($0.text, Self.historyDatePattern)
            }.sorted { $0.bounds.midY > $1.bounds.midY }
            for (offset, start) in startsOfRows.enumerated() {
                let bottom = offset + 1 < startsOfRows.count ? startsOfRows[offset + 1].bounds.midY + 1 : page.bounds(for: .mediaBox).minY + 35
                let block = tokens.filter { $0.bounds.midY <= start.bounds.midY + 1 && $0.bounds.midY >= bottom }
                let dates = block.filter { $0.bounds.minX < boundaries[0] && Self.matches($0.text, Self.historyDatePattern) }
                let details = block.filter { $0.bounds.minX >= boundaries[0] && $0.bounds.minX < boundaries[1] }
                let amounts = block.filter {
                    $0.bounds.minX >= boundaries[1] && $0.bounds.minX < boundaries[2] && Self.matches($0.text, Self.moneyPattern)
                }
                let balances = block.filter {
                    $0.bounds.minX >= boundaries[2] && Self.matches($0.text, Self.moneyPattern)
                }
                guard dates.count == 1, dates[0].sourceOrdinal == start.sourceOrdinal,
                      !details.isEmpty, amounts.count == 1, balances.count == 1,
                      Self.matches(amounts[0].text, Self.moneyPattern),
                      Self.matches(balances[0].text, Self.moneyPattern) else {
                    throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: start.sourceOrdinal)
                }
                let narration = Self.readingOrder(details).map(\.text).joined(separator: " ")
                guard !narration.isEmpty else { throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: start.sourceOrdinal) }
                rows.append(NormalizedRow(rowNumber: start.sourceOrdinal, values: [start.text, narration, "", amounts[0].text, balances[0].text]))
            }
        }
        guard !rows.isEmpty else { throw CBQCurrentAccountPDFNormalizationError.noTransactions }
        return result(
            family: .history, fileURL: fileURL, rows: rows, totalTokens: totalTokens,
            preamble: [.init(sourceOrdinal: 1, text: "ACCOUNT\t\(account)")]
        )
    }

    private func normalizeMonthly(pdf: PDFDocument, fileURL: URL, boundedText: String) throws -> CBQCurrentAccountPDFNormalizationResult {
        guard let account = Self.uniqueCapture(#"\bAccount No\.:\s*([0-9Xx* -]+)\s+Statement Date:"#, in: boundedText),
              let iban = Self.uniqueCapture(#"\bIBAN:\s*([A-Za-z0-9Xx* -]+)\s+Account No\."#, in: boundedText),
              let boundary = Self.uniqueCapture(#"\bStatement Date:\s*([0-9]{2} [A-Za-z]{3} [0-9]{2})\b"#, in: boundedText),
              boundedText.contains("Currency: QATARI RIYAL") else {
            throw CBQCurrentAccountPDFNormalizationError.malformedPreamble
        }
        guard let page = pdf.page(at: 0) else { throw CBQCurrentAccountPDFNormalizationError.unsupportedNativeText }
        let tokens = Self.tokens(on: page, pageIndex: 0)
        let grouped = Dictionary(grouping: tokens, by: \.visualRow)
        let headers = grouped.values.filter { Self.rowText($0) == "Posting Date Transaction Description Transaction Date Debit Credit Balance" }
        guard headers.count == 1, let header = headers.first else {
            throw CBQCurrentAccountPDFNormalizationError.missingHeader
        }
        let headerTokens = header.sorted { $0.bounds.minX < $1.bounds.minX }
        func start(_ text: String, afterX: CGFloat = -.infinity) -> CGFloat? {
            headerTokens.first(where: { $0.text == text && $0.bounds.minX > afterX })?.bounds.minX
        }
        guard let postingX = start("Posting"), let descriptionX = start("Transaction"),
              let transactionDateX = start("Transaction", afterX: descriptionX + 1),
              let debitX = start("Debit"), let creditX = start("Credit"), let balanceX = start("Balance"),
              postingX < descriptionX, descriptionX < transactionDateX,
              transactionDateX < debitX, debitX < creditX, creditX < balanceX else {
            throw CBQCurrentAccountPDFNormalizationError.changedHeader
        }
        let boundaries = [(postingX + descriptionX) / 2, (descriptionX + transactionDateX) / 2,
                          (transactionDateX + debitX) / 2, (debitX + creditX) / 2,
                          (creditX + balanceX) / 2]
        let headerY = headerTokens.map(\.bounds.midY).reduce(0, +) / CGFloat(headerTokens.count)
        let closingRows = grouped.values.filter { Self.rowText($0).hasPrefix("* CREDIT BALANCE ") }
        guard closingRows.count == 1, let footerY = closingRows.first?.map(\.bounds.midY).max() else {
            throw CBQCurrentAccountPDFNormalizationError.malformedPreamble
        }
        let postingStarts = tokens.filter {
            $0.bounds.minX < boundaries[0] && $0.bounds.midY < headerY - 3 && Self.matches($0.text, Self.monthlyDatePattern)
        }.sorted { $0.bounds.midY > $1.bounds.midY }
        guard let broughtForward = postingStarts.first else { throw CBQCurrentAccountPDFNormalizationError.noTransactions }
        var rows: [NormalizedRow] = []
        var openingBalance: String?
        for (offset, startToken) in postingStarts.enumerated() {
            let bottom = offset + 1 < postingStarts.count ? postingStarts[offset + 1].bounds.midY + 1 : footerY + 1
            let block = tokens.filter { $0.bounds.midY <= startToken.bounds.midY + 1 && $0.bounds.midY >= bottom }
            let descriptions = Self.readingOrder(block.filter { $0.bounds.minX >= boundaries[0] && $0.bounds.minX < boundaries[1] })
            let description = descriptions.map(\.text).joined(separator: " ")
            let transactionDates = block.filter { $0.bounds.minX >= boundaries[1] && $0.bounds.minX < boundaries[2] && Self.matches($0.text, Self.monthlyDatePattern) }
            let debits = block.filter { $0.bounds.minX >= boundaries[2] && $0.bounds.minX < boundaries[3] && Self.matches($0.text, Self.moneyPattern) }
            let credits = block.filter { $0.bounds.minX >= boundaries[3] && $0.bounds.minX < boundaries[4] && Self.matches($0.text, Self.moneyPattern) }
            let balances = block.filter { $0.bounds.minX >= boundaries[4] && Self.matches($0.text, Self.moneyPattern) }
            if startToken.sourceOrdinal == broughtForward.sourceOrdinal {
                guard description == "BROUGHT FORWARD", transactionDates.isEmpty, debits.isEmpty, credits.isEmpty, balances.count == 1 else {
                    throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: startToken.sourceOrdinal)
                }
                openingBalance = balances[0].text
                continue
            }
            guard !description.isEmpty, transactionDates.count == 1,
                  (debits.count == 1) != (credits.count == 1), balances.count == 1 else {
                throw CBQCurrentAccountPDFNormalizationError.malformedTransaction(sourceOrdinal: startToken.sourceOrdinal)
            }
            let signed = debits.first.map { "-\($0.text)" } ?? credits[0].text
            rows.append(NormalizedRow(rowNumber: startToken.sourceOrdinal, values: [startToken.text, description, transactionDates[0].text, signed, balances[0].text]))
        }
        guard let openingBalance, let closingBalance = rows.last?.values[4], !rows.isEmpty else {
            throw CBQCurrentAccountPDFNormalizationError.noTransactions
        }
        for pageIndex in 1..<pdf.pageCount {
            guard let trailingPage = pdf.page(at: pageIndex), let pageText = trailingPage.string else {
                throw CBQCurrentAccountPDFNormalizationError.unsupportedNativeText
            }
            let normalized = Self.boundedWhitespace(pageText)
            if normalized.contains("Posting Date Transaction Description Transaction Date Debit Credit Balance") ||
                normalized.range(of: #"\b[0-9]{2}-[A-Za-z]{3}-[0-9]{2}\b.+\b[0-9]+(?:,[0-9]{3})*\.[0-9]{2}\b"#, options: .regularExpression) != nil {
                throw CBQCurrentAccountPDFNormalizationError.unconsumedFinancialPage(page: pageIndex + 1)
            }
        }
        return result(
            family: .monthly, fileURL: fileURL, rows: rows, totalTokens: tokens.count,
            preamble: [
                .init(sourceOrdinal: 1, text: "MASKED_ACCOUNT\t\(account)"),
                .init(sourceOrdinal: 2, text: "MASKED_IBAN\t\(iban)"),
                .init(sourceOrdinal: 3, text: "STATEMENT_BOUNDARY\t\(boundary)"),
                .init(sourceOrdinal: 4, text: "PERIOD_START\t\(broughtForward.text)"),
                .init(sourceOrdinal: 5, text: "OPENING_BALANCE\t\(openingBalance)"),
                .init(sourceOrdinal: 6, text: "CLOSING_BALANCE\t\(closingBalance)")
            ]
        )
    }

    private func result(family: CBQCurrentAccountPDFFamily, fileURL: URL, rows: [NormalizedRow], totalTokens: Int, preamble: [NormalizedDocument.SourceFragment]) -> CBQCurrentAccountPDFNormalizationResult {
        var document = Document(filename: fileURL.lastPathComponent, url: fileURL, fileType: FileFormat.pdf.rawValue, importedAt: now())
        document.rowCount = totalTokens
        document.headerRow = 1
        document.firstTransactionRow = rows.first?.rowNumber
        document.columnCount = Self.logicalHeader.count
        document.encoding = "UTF-8"
        return CBQCurrentAccountPDFNormalizationResult(
            family: family,
            document: document,
            rows: rows,
            header: NormalizedRow(rowNumber: 1, values: Self.logicalHeader),
            sourceContext: .init(preTransactionFragments: preamble, postTransactionFragments: [])
        )
    }

    private static func tokens(on page: PDFPage, pageIndex: Int) -> [Token] {
        guard let string = page.string, !string.isEmpty,
              let expression = try? NSRegularExpression(pattern: #"\S+"#) else { return [] }
        let source = string as NSString
        let positioned = expression.matches(in: string, range: NSRange(location: 0, length: source.length)).compactMap { match -> (String, CGRect)? in
            guard let selection = page.selection(for: match.range) else { return nil }
            let bounds = selection.bounds(for: page)
            guard !bounds.isNull, !bounds.isInfinite, bounds.width > 0, bounds.height > 0 else { return nil }
            return (source.substring(with: match.range), bounds)
        }
        var visualRows: [(midY: CGFloat, values: [(String, CGRect)])] = []
        for value in positioned {
            if let index = visualRows.indices.min(by: { abs(visualRows[$0].midY - value.1.midY) < abs(visualRows[$1].midY - value.1.midY) }),
               abs(visualRows[index].midY - value.1.midY) <= 3 {
                visualRows[index].values.append(value)
            } else {
                visualRows.append((value.1.midY, [value]))
            }
        }
        var ordinal = 0
        return visualRows.sorted { $0.midY > $1.midY }.enumerated().flatMap { visualRow, row in
            row.values.sorted { $0.1.minX < $1.1.minX }.map {
                ordinal += 1
                return Token(pageIndex: pageIndex, tokenIndex: ordinal, visualRow: visualRow, text: $0.0, bounds: $0.1)
            }
        }
    }

    private static func readingOrder(_ tokens: [Token]) -> [Token] {
        tokens.sorted {
            if abs($0.bounds.midY - $1.bounds.midY) > 2 { return $0.bounds.midY > $1.bounds.midY }
            return $0.bounds.minX < $1.bounds.minX
        }
    }

    private static func rowText(_ tokens: [Token]) -> String {
        tokens.sorted { $0.bounds.minX < $1.bounds.minX }.map(\.text).joined(separator: " ")
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
