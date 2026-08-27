import Foundation
import PDFKit

enum AxisCreditCardPDFNormalizationError: Error, Equatable, LocalizedError {
    case unsupportedNativeText
    case unsupportedFamily
    case changedHeader
    case malformedSummary
    case malformedTaggedTable
    case malformedTransaction(sourceOrdinal: Int)
    case noTransactions
    case unconsumedFinancialEvidence

    var errorDescription: String? {
        switch self {
        case .unsupportedNativeText: return "The Axis card statement requires native selectable PDF text."
        case .unsupportedFamily: return "The PDF is not the exact supported Axis credit-card family."
        case .changedHeader: return "The Axis credit-card transaction header changed."
        case .malformedSummary: return "The Axis credit-card summary is malformed."
        case .malformedTaggedTable: return "The Axis bank-app credit-card tagged transaction table is malformed or ambiguous."
        case .malformedTransaction(let ordinal): return "Axis credit-card row \(ordinal) is malformed."
        case .noTransactions: return "The Axis credit-card statement contains no financial rows."
        case .unconsumedFinancialEvidence: return "The Axis credit-card PDF contains unconsumed financial evidence."
        }
    }
}

struct AxisCreditCardPDFNormalizationResult {
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow
    let sourceContext: NormalizedDocument.SourceContext
    /// Transient structural presentation evidence used to select the
    /// post-validation credential target. This is deliberately not part of
    /// `DocumentMetadata`, source evidence, or persisted financial state.
    let presentation: AxisCreditCardPDFPresentation
}

enum AxisCreditCardPDFPresentation: Sendable, Equatable {
    case appPDF
    case traditionalPDF
}

/// Normalizes the two proven Axis card PDF presentations into one small,
/// source-faithful row contract. It deliberately does not decrypt or write a
/// PDF; the reader supplies the native page text extracted from the immutable
/// source snapshot.
final class AxisCreditCardPDFNormalizer {
    static let logicalHeader = [
        "Transaction Date", "Transaction Details", "Amount (INR)",
        "Liability Effect", "Scope", "Section ID", "Reference",
        "Original Amount", "Original Currency"
    ]
    static let profileID = "axis.credit-card.pdf"
    static let profileVersion = "1"

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) { self.now = now }

    func normalize(text: String, sourceBytes: Data, fileURL: URL) throws -> AxisCreditCardPDFNormalizationResult {
        guard let pdf = PDFDocument(data: sourceBytes), pdf.pageCount > 0 else {
            throw AxisCreditCardPDFNormalizationError.unsupportedNativeText
        }
        let pages = try (0..<pdf.pageCount).map { index -> String in
            guard let value = pdf.page(at: index)?.string,
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AxisCreditCardPDFNormalizationError.unsupportedNativeText
            }
            return value
        }
        return try normalize(text: text, pageTexts: pages, fileURL: fileURL)
    }

    func normalize(
        text: String,
        pageTexts: [String],
        pageEvidence: [RawPDFPageEvidence]? = nil,
        taggedTables: [RawPDFTaggedTableEvidence]? = nil,
        fileURL: URL
    ) throws -> AxisCreditCardPDFNormalizationResult {
        guard !pageTexts.isEmpty,
              pageTexts.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw AxisCreditCardPDFNormalizationError.unsupportedNativeText
        }
        let joined = pageTexts.joined(separator: "\n")
        guard joined == text || Self.boundedWhitespace(joined) == Self.boundedWhitespace(text) else {
            throw AxisCreditCardPDFNormalizationError.unsupportedNativeText
        }
        let normalized = Self.boundedWhitespace(joined)
        guard Self.compactSourceLabel(normalized).contains("creditcard") else {
            throw AxisCreditCardPDFNormalizationError.unsupportedFamily
        }

        let headerMatches = pageTexts.flatMap { $0.components(separatedBy: .newlines) }
            .map(Self.clean)
            .filter(Self.isHeader)
        let taggedHeaderCandidates = Self.appTaggedTransactionTableCandidates(from: taggedTables)

        let appHeader = "DATE TRANSACTION DETAILS AMOUNT (INR) DEBIT/CREDIT"
        let traditionalHeader = "DATE TRANSACTION DETAILS MERCHANT CATEGORY AMOUNT (RS.)"
        let hasAppHeader = headerMatches.contains { $0.uppercased() == appHeader } ||
            !taggedHeaderCandidates.isEmpty
        let hasTraditionalHeader = headerMatches.contains { $0.uppercased() == traditionalHeader }
        guard hasAppHeader != hasTraditionalHeader else {
            throw AxisCreditCardPDFNormalizationError.changedHeader
        }
        let isAppLayout = hasAppHeader
        let positionedPages: [String]?
        if !isAppLayout {
            guard let pageEvidence, pageEvidence.count == pageTexts.count else {
                throw AxisCreditCardPDFNormalizationError.malformedSummary
            }
            positionedPages = try Self.traditionalPositionedPages(from: pageEvidence)
        } else {
            positionedPages = nil
        }

        let rows: [NormalizedRow]
        if isAppLayout {
            rows = try Self.appTaggedRows(from: taggedTables)
        } else {
            let transactionPages = positionedPages ?? pageTexts
            var traditionalRows: [NormalizedRow] = []
            var sawFinancialCandidate = false
            for page in transactionPages {
                let lines: [String]
                if positionedPages != nil {
                    lines = page.components(separatedBy: .newlines).map(Self.sourceVisibleText)
                } else {
                    lines = page.components(separatedBy: .newlines).map(Self.clean)
                }
                var index = 0
                while index < lines.count {
                    let line = lines[index]
                    guard !line.isEmpty else { index += 1; continue }
                    if Self.looksLikeFinancialLine(line) { sawFinancialCandidate = true }
                    var candidate = line
                    var fields = Self.rowFields(candidate)
                    if fields == nil && Self.looksLikeFinancialLine(line) {
                        var lookahead = index + 1
                        while lookahead < lines.count && lookahead <= index + 4 {
                            let continuation = lines[lookahead]
                            if Self.looksLikeFinancialLine(continuation) { break }
                            if !continuation.isEmpty {
                                candidate += " " + continuation
                                fields = Self.rowFields(candidate)
                                if fields != nil { index = lookahead; break }
                            }
                            lookahead += 1
                        }
                    }
                    guard let fields else {
                        if Self.looksLikeFinancialLine(line),
                           line.range(of: #"(?:INR|₹|Debit|Credit|\bDr\b|\bCr\b)"#, options: [.regularExpression, .caseInsensitive]) != nil {
                            throw AxisCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: traditionalRows.count + 1)
                        }
                        index += 1
                        continue
                    }
                    let ordinal = traditionalRows.count + 1
                    guard !fields.details.isEmpty else {
                        throw AxisCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: ordinal)
                    }
                    traditionalRows.append(NormalizedRow(
                        rowNumber: ordinal,
                        values: [fields.date, fields.details, fields.amount,
                                 fields.effect, "account_level", "",
                                 fields.reference ?? "", fields.originalAmount ?? "",
                                 fields.originalCurrency ?? ""]
                    ))
                    index += 1
                }
            }
            guard !traditionalRows.isEmpty else { throw AxisCreditCardPDFNormalizationError.noTransactions }
            guard sawFinancialCandidate else { throw AxisCreditCardPDFNormalizationError.unconsumedFinancialEvidence }
            rows = traditionalRows
        }

        var document = Document(filename: fileURL.lastPathComponent, url: fileURL,
                                fileType: FileFormat.pdf.rawValue, importedAt: now())
        document.rowCount = rows.count
        document.headerRow = 1
        document.firstTransactionRow = rows.first?.rowNumber
        document.columnCount = Self.logicalHeader.count
        document.encoding = "UTF-8"

        var sourceEvidenceText = joined
        if let positionedPages {
            sourceEvidenceText += "\n" + positionedPages.joined(separator: "\n")
        }
        var fragments = Self.sourceFragments(from: sourceEvidenceText)
        if !isAppLayout, let pageEvidence, pageEvidence.count == pageTexts.count {
            let geometryOwnedKeys: Set<String> = [
                "OPENING_BALANCE", "TOTAL_PAYMENT_DUE", "PERIOD",
                "PAYMENT_DUE_DATE"
            ]
            fragments.removeAll { fragment in
                guard let key = fragment.text.split(separator: "\t", maxSplits: 1).first else { return false }
                return geometryOwnedKeys.contains(String(key))
            }
            fragments.append(contentsOf: (try? Self.traditionalSummaryFragments(from: pageEvidence)) ?? [])
        }
        let activeSourceKeys: Set<String> = [
            "STATEMENT_DATE", "PERIOD", "SELECTED_STATEMENT_MONTH",
            "OPENING_BALANCE", "TOTAL_PAYMENT_DUE", "PAYMENT_DUE_DATE"
        ]
        fragments.removeAll { fragment in
            guard let key = fragment.text.split(separator: "\t", maxSplits: 1).first else {
                return true
            }
            return !activeSourceKeys.contains(String(key))
        }
        fragments.append(.init(sourceOrdinal: 0, text: "FORMAT\tpdf"))
        return AxisCreditCardPDFNormalizationResult(
            document: document,
            rows: rows,
            header: NormalizedRow(rowNumber: 1, values: Self.logicalHeader),
            sourceContext: .init(preTransactionFragments: fragments),
            presentation: isAppLayout ? .appPDF : .traditionalPDF
        )
    }

    nonisolated private static let appTaggedHeaderTokens = [
        "Date", "TransactionDetails", "Amount(INR)", "Debit/Credit"
    ]

    nonisolated private static func appTaggedTransactionTableCandidates(
        from taggedTables: [RawPDFTaggedTableEvidence]?
    ) -> [RawPDFTaggedTableEvidence] {
        guard let taggedTables else { return [] }
        return taggedTables.filter { table in
            guard let header = table.rows.first,
                  header.cells.count == 4,
                  header.cells.allSatisfy({ $0.role == .header }) else { return false }
            let values = header.cells.compactMap(Self.appTaggedCellText)
            return values.count == 4 && zip(values, appTaggedHeaderTokens).allSatisfy {
                Self.compactWhitespace($0.0) == $0.1
            }
        }
    }

    private static func appTaggedRows(
        from taggedTables: [RawPDFTaggedTableEvidence]?
    ) throws -> [NormalizedRow] {
        guard let taggedTables, !taggedTables.isEmpty else {
            throw AxisCreditCardPDFNormalizationError.malformedTaggedTable
        }
        let candidates = Self.appTaggedTransactionTableCandidates(from: taggedTables)
        guard candidates.count == 1, let transactionTable = candidates.first else {
            throw AxisCreditCardPDFNormalizationError.malformedTaggedTable
        }
        guard transactionTable.rows.count > 1 else {
            throw AxisCreditCardPDFNormalizationError.noTransactions
        }

        var taggedRows: [AppTaggedRow] = []
        taggedRows.reserveCapacity(transactionTable.rows.count - 1)
        for (offset, row) in transactionTable.rows.dropFirst().enumerated() {
            let ordinal = offset + 1
            guard row.cells.count == 4,
                  row.cells.allSatisfy({ $0.role == .data }) else {
                throw AxisCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: ordinal)
            }
            let values = row.cells.compactMap(Self.appTaggedCellText)
            guard values.count == 4,
                  let date = Self.appTaggedDate(values[0]),
                  let amount = Self.appTaggedAmount(values[2]) else {
                throw AxisCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: ordinal)
            }
            let direction = Self.compactWhitespace(values[3]).lowercased()
            let effect: String
            switch direction {
            case "debit": effect = CardLiabilityEffect.increasesAmountOwed.rawValue
            case "credit": effect = CardLiabilityEffect.decreasesAmountOwed.rawValue
            default:
                throw AxisCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: ordinal)
            }
            let details = Self.clean(values[1])
            guard !details.isEmpty else {
                throw AxisCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: ordinal)
            }
            taggedRows.append(.init(date: date, amount: amount, effect: effect, details: details))
        }

        // The tagged logical table owns App financial rows, narration, and
        // source order. Visual geometry is not a competing parser or a
        // rejection condition for this representation.
        return taggedRows.enumerated().map { offset, row in
            NormalizedRow(
                rowNumber: offset + 1,
                values: [
                    row.date, row.details, row.amount, row.effect,
                    "account_level", "", "", "", ""
                ]
            )
        }
    }

    nonisolated private static func appTaggedCellText(_ cell: RawPDFTaggedCellEvidence) -> String? {
        guard cell.children.count == 2,
              case .markedContent(let direct) = cell.children[0],
              case .structure(let nested) = cell.children[1],
              nested.role == "NonStruct",
              nested.markedContent.count == 1,
              let textEvidence = nested.markedContent.first,
              direct.pageNumber == textEvidence.pageNumber,
              direct.mcid != textEvidence.mcid,
              direct.rectangleCount > 0,
              direct.textBlocks.isEmpty,
              textEvidence.rectangleCount == 0,
              !textEvidence.textBlocks.isEmpty else { return nil }
        let blocks = textEvidence.textBlocks.map(Self.clean).filter { !$0.isEmpty }
        guard blocks.count == textEvidence.textBlocks.count, !blocks.isEmpty else { return nil }
        return blocks.joined(separator: " ")
    }

    nonisolated private static func compactWhitespace(_ value: String) -> String {
        Self.clean(value).replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
    }

    private static func appTaggedDate(_ value: String) -> String? {
        let cleaned = Self.clean(value).replacingOccurrences(of: "’", with: "'")
        if let date = try? StatementDate(canonical: cleaned) { return date.canonical }
        let parts = cleaned.split(separator: " ", omittingEmptySubsequences: true)
        if parts.count == 3,
           let day = Int(parts[0]),
           let month = Self.monthIndex(String(parts[1])),
           let yearRaw = Int(parts[2].replacingOccurrences(of: "'", with: "")),
           let date = try? StatementDate(year: yearRaw < 100 ? 2000 + yearRaw : yearRaw, month: month, day: day) {
            return date.canonical
        }
        let compact = cleaned.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
        let pattern = #"^(\d{1,2})([A-Za-z]{3})'?(\d{2,4})$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: compact, range: NSRange(compact.startIndex..., in: compact)),
           let dayRange = Range(match.range(at: 1), in: compact),
           let monthRange = Range(match.range(at: 2), in: compact),
           let yearRange = Range(match.range(at: 3), in: compact),
           let day = Int(compact[dayRange]),
           let month = Self.monthIndex(String(compact[monthRange])),
           let yearRaw = Int(compact[yearRange]),
           let date = try? StatementDate(year: yearRaw < 100 ? 2000 + yearRaw : yearRaw, month: month, day: day) {
            return date.canonical
        }
        let numeric = compact.split(whereSeparator: { $0 == "/" || $0 == "-" })
        guard numeric.count == 3,
              let day = Int(numeric[0]),
              let month = Int(numeric[1]),
              let yearRaw = Int(numeric[2]),
              let date = try? StatementDate(year: yearRaw < 100 ? 2000 + yearRaw : yearRaw, month: month, day: day) else {
            return nil
        }
        return date.canonical
    }

    nonisolated private static func monthIndex(_ value: String) -> Int? {
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            .firstIndex(where: { $0.caseInsensitiveCompare(value) == .orderedSame })
            .map { $0 + 1 }
    }

    private static func appTaggedAmount(_ value: String) -> String? {
        let numeric = Self.compactWhitespace(value)
            .replacingOccurrences(of: "INR", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard let amount = Decimal(string: numeric, locale: Locale(identifier: "en_US_POSIX")),
              amount > .zero,
              let money = try? Money(amount: amount, currency: "INR"),
              (try? money.minorUnits()) != nil else { return nil }
        return numeric
    }

    nonisolated fileprivate static func clean(_ line: String) -> String {
        var value = line.replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        for (pattern, replacement) in [
            (#"(?i)\bC\s*r\s*e\s*d\s*i\s*t\s*C\s*a\s*r\s*d\s*N\s*u\s*m\s*b\s*e\s*r\b"#, "Credit Card Number"),
            (#"(?i)\bC\s*a\s*r\s*d\s*A\s*c\s*c\s*o\s*u\s*n\s*t\s*N\s*u\s*m\s*b\s*e\s*r\b"#, "Card Account Number"),
            (#"(?i)\bD\s*e\s*b\s*i\s*t\b"#, "Debit"),
            (#"(?i)\bC\s*r\s*e\s*d\s*i\s*t\b"#, "Credit")
        ] {
            value = value.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return value.replacingOccurrences(of: #"\s*/\s*"#, with: "/", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated fileprivate static func sourceVisibleText(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct AppTaggedRow {
        let date: String
        let amount: String
        let effect: String
        let details: String
    }

    nonisolated private static func positionedFragmentRows(from evidence: RawPDFPageEvidence) -> [[RawPDFTextFragment]] {
        let ordered = evidence.fragments.enumerated().sorted { lhs, rhs in
            if abs(lhs.element.y - rhs.element.y) > 1.5 { return lhs.element.y > rhs.element.y }
            if abs(lhs.element.x - rhs.element.x) > 0.1 { return lhs.element.x < rhs.element.x }
            return lhs.offset < rhs.offset
        }
        var rows: [[(offset: Int, element: RawPDFTextFragment)]] = []
        for item in ordered {
            if let last = rows.indices.last,
               let anchor = rows[last].first?.element,
               abs(anchor.y - item.element.y) <= 1.5 {
                rows[last].append((item.offset, item.element))
            } else {
                rows.append([(item.offset, item.element)])
            }
        }
        return rows.map { row in
            row.sorted { lhs, rhs in
                if abs(lhs.element.x - rhs.element.x) > 0.1 { return lhs.element.x < rhs.element.x }
                return lhs.offset < rhs.offset
            }.map(\.element)
        }
    }

    nonisolated fileprivate static func positionedLines(from evidence: RawPDFPageEvidence) -> [String] {
        positionedFragmentRows(from: evidence).map { row in
            clean(row.map(\.text).joined(separator: " "))
        }.filter { !$0.isEmpty }
    }

    nonisolated private static func traditionalPositionedPages(from pageEvidence: [RawPDFPageEvidence]) throws -> [String] {
        let rowPages = pageEvidence.map(positionedFragmentRows)
        guard let globalBounds = traditionalDescriptionBounds(in: rowPages.flatMap { $0 }) else {
            throw AxisCreditCardPDFNormalizationError.changedHeader
        }
        var activeLoansBoundaryReached = false
        var transactionOrdinal = 0
        var result: [String] = []
        for rows in rowPages {
            let bounds = traditionalDescriptionBounds(in: rows) ?? globalBounds
            var pageLines: [String] = []
            for row in rows {
                let ordered = row.sorted { lhs, rhs in
                    if abs(lhs.x - rhs.x) > 0.1 { return lhs.x < rhs.x }
                    return lhs.y > rhs.y
                }
                let rowText = sourceVisibleText(ordered.map(\.text).joined(separator: " "))
                let dates = ordered.filter {
                    $0.x < bounds.start && traditionalDateFragment($0.text)
                }
                let directedAmounts = traditionalDirectedAmountCandidates(
                    in: ordered,
                    minimumX: bounds.end
                )
                let isActiveLoansBoundary =
                    rowText.localizedCaseInsensitiveContains("Active Loans") &&
                    dates.isEmpty && directedAmounts.isEmpty
                if isActiveLoansBoundary {
                    activeLoansBoundaryReached = true
                    continue
                }
                if activeLoansBoundaryReached { continue }
                let detailsFragments = ordered.filter {
                    $0.x >= bounds.start && $0.x < bounds.end &&
                        !traditionalDateFragment($0.text)
                }
                let amountEvidence = ordered.filter {
                    $0.x >= bounds.end &&
                        (traditionalAmountFragment($0.text) ||
                         traditionalDirectionFragment($0.text) ||
                         traditionalDirectedAmountFragment($0.text))
                }
                let hasFinancialMarker = rowText.range(
                    of: #"(?:INR|₹|Debit|Credit|\bDr\b|\bCr\b)"#,
                    options: [.regularExpression, .caseInsensitive]
                ) != nil
                let looksLikeTransaction = !dates.isEmpty && !amountEvidence.isEmpty
                guard looksLikeTransaction else {
                    if !dates.isEmpty, !detailsFragments.isEmpty, hasFinancialMarker {
                        throw AxisCreditCardPDFNormalizationError.malformedTransaction(
                            sourceOrdinal: transactionOrdinal + 1
                        )
                    }
                    if !rowText.isEmpty { pageLines.append(rowText) }
                    continue
                }
                guard dates.count == 1,
                      directedAmounts.count == 1,
                      let date = dates.first,
                      let amount = directedAmounts.first,
                      amount.terminalIndex == ordered.indices.last else {
                    throw AxisCreditCardPDFNormalizationError.malformedTransaction(
                        sourceOrdinal: transactionOrdinal + 1
                    )
                }
                let details = sourceVisibleText(detailsFragments.map(\.text).joined(separator: " "))
                guard !details.isEmpty else {
                    throw AxisCreditCardPDFNormalizationError.malformedTransaction(
                        sourceOrdinal: transactionOrdinal + 1
                    )
                }
                transactionOrdinal += 1
                pageLines.append(sourceVisibleText("\(date.text) \(details) \(amount.text)"))
            }
            result.append(pageLines.joined(separator: "\n"))
        }
        return result
    }

    private struct TraditionalHeaderPhrase {
        let startIndex: Int
        let endIndex: Int
        let minX: Double
        let maxX: Double
        let centerX: Double
    }

    nonisolated private static func traditionalHeaderPhrases(
        _ label: String,
        in row: [RawPDFTextFragment]
    ) -> [TraditionalHeaderPhrase] {
        let ordered = row.enumerated().sorted { lhs, rhs in
            if abs(lhs.element.x - rhs.element.x) > 0.1 { return lhs.element.x < rhs.element.x }
            return lhs.offset < rhs.offset
        }.map(\.element)
        let target = compactSourceLabel(label)
        guard !target.isEmpty else { return [] }
        var matches = [TraditionalHeaderPhrase]()
        for startIndex in ordered.indices {
            let firstPart = compactSourceLabel(ordered[startIndex].text)
            guard !firstPart.isEmpty, target.hasPrefix(firstPart) else { continue }
            var accumulated = ""
            for endIndex in startIndex..<ordered.count {
                let part = compactSourceLabel(ordered[endIndex].text)
                if !part.isEmpty {
                    let next = accumulated + part
                    guard target.hasPrefix(next) else { break }
                    accumulated = next
                }
                guard accumulated == target else { continue }
                let minX = ordered[startIndex].geometry?.minX ?? ordered[startIndex].x
                let maxX = ordered[endIndex].geometry?.maxX ?? ordered[endIndex].x
                matches.append(.init(
                    startIndex: startIndex,
                    endIndex: endIndex,
                    minX: minX,
                    maxX: maxX,
                    centerX: (minX + maxX) / 2
                ))
                break
            }
        }
        return matches
    }

    nonisolated private static func traditionalDescriptionBounds(
        in rows: [[RawPDFTextFragment]]
    ) -> (start: Double, end: Double)? {
        var candidates = [(start: Double, end: Double)]()
        for row in rows {
            let dates = traditionalHeaderPhrases("Date", in: row)
            let transactionDetails = traditionalHeaderPhrases("Transaction Details", in: row)
            let descriptions = transactionDetails.isEmpty
                ? traditionalHeaderPhrases("Description", in: row)
                : transactionDetails
            let merchantCategories = traditionalHeaderPhrases("Merchant Category", in: row)
            var rowCandidates = [(start: Double, end: Double)]()
            for date in dates {
                for description in descriptions where date.endIndex < description.startIndex {
                    for merchant in merchantCategories
                    where description.endIndex < merchant.startIndex &&
                        date.centerX < description.centerX &&
                        description.centerX < merchant.centerX {
                        guard date.maxX <= description.minX,
                              description.maxX <= merchant.minX,
                              date.maxX < merchant.minX else { continue }
                        rowCandidates.append((
                            start: date.maxX,
                            end: merchant.minX
                        ))
                    }
                }
            }
            if rowCandidates.count == 1, let candidate = rowCandidates.first {
                candidates.append(candidate)
            }
        }
        guard let reference = candidates.first,
              candidates.allSatisfy({
                  abs($0.start - reference.start) <= 2 &&
                    abs($0.end - reference.end) <= 2
              }) else { return nil }
        return reference.start < reference.end ? reference : nil
    }

    nonisolated private static func traditionalDateFragment(_ value: String) -> Bool {
        clean(value).range(of: #"^\d{1,2}[/-]\d{1,2}[/-]\d{4}$"#, options: .regularExpression) != nil
    }

    nonisolated private static func traditionalDirectedAmountFragment(_ value: String) -> Bool {
        clean(value).range(
            of: #"^(?:INR|₹)?\s*[0-9][0-9,]*\.\d{2}\s*(?:Debit|Credit|Dr|Cr)$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    nonisolated private static func traditionalAmountFragment(_ value: String) -> Bool {
        clean(value).range(
            of: #"^(?:INR|₹)?\s*[0-9][0-9,]*\.\d{2}$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    nonisolated private static func traditionalDirectionFragment(_ value: String) -> Bool {
        clean(value).range(
            of: #"^(?:Debit|Credit|Dr|Cr)$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private struct TraditionalDirectedAmountCandidate {
        let text: String
        let terminalIndex: Int
    }

    nonisolated private static func traditionalDirectedAmountCandidates(
        in ordered: [RawPDFTextFragment],
        minimumX: Double
    ) -> [TraditionalDirectedAmountCandidate] {
        var result: [TraditionalDirectedAmountCandidate] = []
        for index in ordered.indices where ordered[index].x >= minimumX {
            if traditionalDirectedAmountFragment(ordered[index].text) {
                result.append(.init(
                    text: sourceVisibleText(ordered[index].text),
                    terminalIndex: index
                ))
                continue
            }
            guard traditionalDirectionFragment(ordered[index].text),
                  index > ordered.startIndex else { continue }
            let amountIndex = ordered.index(before: index)
            guard ordered[amountIndex].x >= minimumX,
                  traditionalAmountFragment(ordered[amountIndex].text) else { continue }
            result.append(.init(
                text: sourceVisibleText("\(ordered[amountIndex].text) \(ordered[index].text)"),
                terminalIndex: index
            ))
        }
        return result
    }

    private struct PositionedSummaryColumn {
        let x: Double
        let text: String
    }

    nonisolated private static func positionedSummaryColumns(
        in row: [RawPDFTextFragment]
    ) -> [PositionedSummaryColumn] {
        let ordered = row.enumerated().sorted { lhs, rhs in
            if abs(lhs.element.x - rhs.element.x) > 0.1 { return lhs.element.x < rhs.element.x }
            return lhs.offset < rhs.offset
        }
        var groups: [[RawPDFTextFragment]] = []
        for item in ordered {
            if let last = groups.indices.last,
               let previous = groups[last].last,
               item.element.x - previous.x < 30 {
                groups[last].append(item.element)
            } else {
                groups.append([item.element])
            }
        }
        return groups.compactMap { group in
            guard let first = group.first else { return nil }
            // Native app-PDF fragments may split one lexical value at glyph
            // boundaries (for example, before the decimal suffix). Preserve
            // the source column's native concatenation; inserting a space here
            // changes a valid Money token into different text.
            let text = sourceVisibleText(group.map(\.text).joined())
            guard !text.isEmpty else { return nil }
            return PositionedSummaryColumn(x: first.x, text: text)
        }
    }

    nonisolated private static func compactSourceLabel(_ value: String) -> String {
        clean(value).lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }

    nonisolated private static func headerX(
        _ label: String,
        in columns: [PositionedSummaryColumn]
    ) -> Double? {
        let target = compactSourceLabel(label)
        let matches = columns.filter { compactSourceLabel($0.text) == target }
        guard matches.count == 1 else { return nil }
        return matches[0].x
    }

    nonisolated private static func headerColumns(
        _ labels: [String],
        in row: [RawPDFTextFragment]
    ) -> [String: Double]? {
        let columns = positionedSummaryColumns(in: row)
        var result: [String: Double] = [:]
        for label in labels {
            guard let x = headerX(label, in: columns) else { return nil }
            result[label] = x
        }
        guard Set(result.values).count == labels.count else { return nil }
        return result
    }

    nonisolated private static func uniqueHeaderRow(
        labels: [String],
        in rows: [[RawPDFTextFragment]]
    ) -> (index: Int, columns: [String: Double])? {
        let matches = rows.enumerated().compactMap { index, row -> (Int, [String: Double])? in
            guard let columns = headerColumns(labels, in: row) else { return nil }
            return (index, columns)
        }
        guard matches.count == 1, let match = matches.first else { return nil }
        return (match.0, match.1)
    }

    nonisolated private static func ownedSummaryValue(
        headerX: Double,
        in row: [RawPDFTextFragment]
    ) -> String? {
        let aligned = positionedSummaryColumns(in: row).filter { abs($0.x - headerX) <= 20 }
        guard aligned.count == 1 else { return nil }
        return aligned[0].text
    }

    private struct RectangularSummaryPhrase {
        let startIndex: Int
        let endIndex: Int
        let minX: Double
        let maxX: Double
        let text: String

        nonisolated var centerX: Double { (minX + maxX) / 2 }
    }

    private struct RectangularHeaderOccurrence {
        let rows: [[RawPDFTextFragment]]
        let rowIndex: Int
        let columns: [String: RectangularSummaryPhrase]
    }

    private struct HorizontalBand {
        let lower: Double?
        let upper: Double?
    }

    /// Finds every exact contiguous source-token span for one approved label.
    /// PDFKit decides token rectangles; this normalizer owns only the exact
    /// Axis label vocabulary and never infers phrase boundaries from a
    /// document-specific point-gap threshold.
    nonisolated private static func rectangularLabelSpans(
        for label: String,
        in row: [RawPDFTextFragment]
    ) -> [RectangularSummaryPhrase]? {
        guard !row.isEmpty,
              row.allSatisfy(Self.hasCanonicalGeometry) else { return nil }
        let ordered = row.enumerated().sorted { lhs, rhs in
            let left = lhs.element.geometry!
            let right = rhs.element.geometry!
            if abs(left.minX - right.minX) > 0.1 { return left.minX < right.minX }
            return lhs.offset < rhs.offset
        }.map(\.element)

        let target = compactSourceLabel(label)
        guard !target.isEmpty else { return nil }
        var matches: [RectangularSummaryPhrase] = []
        for startIndex in ordered.indices {
            let firstPart = compactSourceLabel(ordered[startIndex].text)
            guard !firstPart.isEmpty, target.hasPrefix(firstPart) else { continue }
            var accumulated = ""
            for endIndex in startIndex..<ordered.count {
                let part = compactSourceLabel(ordered[endIndex].text)
                if !part.isEmpty {
                    let next = accumulated + part
                    guard target.hasPrefix(next) else { break }
                    accumulated = next
                }
                guard accumulated == target else { continue }
                guard let first = ordered[startIndex].geometry,
                      let last = ordered[endIndex].geometry else { return nil }
                matches.append(.init(
                    startIndex: startIndex,
                    endIndex: endIndex,
                    minX: first.minX,
                    maxX: last.maxX,
                    text: sourceVisibleText(
                        ordered[startIndex...endIndex].map(\.text).joined(separator: " ")
                    )
                ))
                break
            }
        }
        return matches
    }

    nonisolated private static func rectangularHeaderColumns(
        labels: [String],
        in row: [RawPDFTextFragment]
    ) -> [String: RectangularSummaryPhrase]? {
        var candidates: [[RectangularSummaryPhrase]] = []
        for label in labels {
            guard let spans = rectangularLabelSpans(for: label, in: row), !spans.isEmpty else {
                return nil
            }
            candidates.append(spans)
        }

        var solutions: [[RectangularSummaryPhrase]] = []
        func appendSolutions(
            labelIndex: Int,
            previousEndIndex: Int?,
            selected: [RectangularSummaryPhrase]
        ) {
            guard solutions.count < 2 else { return }
            guard labelIndex < candidates.count else {
                solutions.append(selected)
                return
            }
            for candidate in candidates[labelIndex] {
                if let previousEndIndex, candidate.startIndex <= previousEndIndex { continue }
                if let previous = selected.last, candidate.centerX <= previous.centerX { continue }
                appendSolutions(
                    labelIndex: labelIndex + 1,
                    previousEndIndex: candidate.endIndex,
                    selected: selected + [candidate]
                )
            }
        }

        appendSolutions(labelIndex: 0, previousEndIndex: nil, selected: [])
        guard solutions.count == 1, let ordered = solutions.first else { return nil }
        var result: [String: RectangularSummaryPhrase] = [:]
        for (label, phrase) in zip(labels, ordered) { result[label] = phrase }
        return result
    }

    nonisolated private static func uniqueRectangularHeaderOccurrence(
        labels: [String],
        in pages: [RawPDFPageEvidence]
    ) -> RectangularHeaderOccurrence? {
        var matches: [RectangularHeaderOccurrence] = []
        for page in pages {
            let rows = positionedFragmentRows(from: page)
            for (rowIndex, row) in rows.enumerated() {
                guard let columns = rectangularHeaderColumns(labels: labels, in: row) else { continue }
                matches.append(.init(rows: rows, rowIndex: rowIndex, columns: columns))
            }
        }
        guard matches.count == 1 else { return nil }
        return matches[0]
    }

    nonisolated private static func horizontalBand(
        for label: String,
        orderedLabels: [String],
        columns: [String: RectangularSummaryPhrase]
    ) -> HorizontalBand? {
        guard let index = orderedLabels.firstIndex(of: label),
              let current = columns[label] else { return nil }
        let lower: Double?
        if index > 0, let previous = columns[orderedLabels[index - 1]] {
            lower = (previous.centerX + current.centerX) / 2
        } else {
            // The first source column owns the complete outer half-plane. An
            // extrapolated edge from header centres can cut off a legitimate
            // left-aligned value when its header phrase is wider than Money.
            lower = nil
        }
        let upper: Double?
        if index + 1 < orderedLabels.count, let next = columns[orderedLabels[index + 1]] {
            upper = (current.centerX + next.centerX) / 2
        } else if index > 0, let previous = columns[orderedLabels[index - 1]] {
            // Unlike the left edge of the first column, the final approved
            // field can have a distinct adjacent source field to its right
            // (for example the printed total beside the six-field balance
            // equation). Preserve the symmetric header-derived outer bound so
            // that adjacent Money is not absorbed into the final field.
            upper = current.centerX + ((current.centerX - previous.centerX) / 2)
        } else {
            upper = current.maxX
        }
        if let lower, !lower.isFinite { return nil }
        if let upper, !upper.isFinite { return nil }
        if let lower, let upper, lower >= upper { return nil }
        return .init(lower: lower, upper: upper)
    }

    nonisolated private static func rectangularOwnedText(
        label: String,
        orderedLabels: [String],
        columns: [String: RectangularSummaryPhrase],
        in row: [RawPDFTextFragment]
    ) -> String? {
        guard let band = horizontalBand(for: label, orderedLabels: orderedLabels, columns: columns),
              row.allSatisfy(Self.hasCanonicalGeometry) else { return nil }
        let owned = row.enumerated().filter { _, fragment in
            guard let geometry = fragment.geometry else { return false }
            let center = (geometry.minX + geometry.maxX) / 2
            if let lower = band.lower, center < lower { return false }
            if let upper = band.upper, center >= upper { return false }
            return true
        }.sorted { lhs, rhs in
            let left = lhs.element.geometry!
            let right = rhs.element.geometry!
            if abs(left.minX - right.minX) > 0.1 { return left.minX < right.minX }
            return lhs.offset < rhs.offset
        }.map(\.element.text)
        let text = sourceVisibleText(owned.joined(separator: " "))
        return text.isEmpty ? nil : text
    }

    nonisolated private static func hasCanonicalGeometry(_ fragment: RawPDFTextFragment) -> Bool {
        guard let geometry = fragment.geometry else { return false }
        return geometry.minX.isFinite
            && geometry.maxX.isFinite
            && geometry.baselineY.isFinite
            && geometry.maxX >= geometry.minX
    }

    /// PDFKit may retain a decorative/operator baseline between one exact
    /// rectangular header and its values. Search only the caller's proven
    /// bounded offsets and return rows that own every approved column. Callers
    /// then validate the complete field group; zero or competing complete
    /// groups fail closed instead of assigning values by broad source order.
    nonisolated private static func rectangularOwnedCandidateRows(
        labels: [String],
        header: RectangularHeaderOccurrence,
        offsets: ClosedRange<Int>
    ) -> [[String: String]] {
        offsets.compactMap { offset -> [String: String]? in
            let index = header.rowIndex + offset
            guard header.rows.indices.contains(index) else { return nil }
            var values: [String: String] = [:]
            for label in labels {
                guard let value = rectangularOwnedText(
                    label: label,
                    orderedLabels: labels,
                    columns: header.columns,
                    in: header.rows[index]
                ) else { return nil }
                values[label] = value
            }
            return values
        }
    }

    nonisolated private static func summaryMoney(
        _ value: String
    ) -> (magnitude: String, direction: String?)? {
        let pattern = #"^\s*(?:INR|₹)?\s*([0-9][0-9,]*\.\d{2})(?:\s*(Dr|Cr))?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              match.range.location == 0,
              match.range.length == value.utf16.count,
              let amountRange = Range(match.range(at: 1), in: value) else { return nil }
        let direction: String?
        if match.range(at: 2).location != NSNotFound,
           let directionRange = Range(match.range(at: 2), in: value) {
            direction = String(value[directionRange]).lowercased()
        } else {
            direction = nil
        }
        return (
            String(value[amountRange]).replacingOccurrences(of: ",", with: ""),
            direction
        )
    }

    nonisolated private static func summaryMoneyCandidates(
        _ value: String
    ) -> [(magnitude: String, direction: String?)] {
        let pattern = #"(?:INR|₹)?\s*([0-9][0-9,]*\.\d{2})(?:\s*(Dr|Cr))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        return regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).compactMap { match in
            guard let amountRange = Range(match.range(at: 1), in: value) else { return nil }
            let direction: String?
            if match.range(at: 2).location != NSNotFound,
               let directionRange = Range(match.range(at: 2), in: value) {
                direction = String(value[directionRange]).lowercased()
            } else {
                direction = nil
            }
            return (
                String(value[amountRange]).replacingOccurrences(of: ",", with: ""),
                direction
            )
        }
    }

    nonisolated private static func summaryDates(_ value: String) -> [String] {
        let pattern = #"\b\d{2}[/-]\d{2}[/-]\d{4}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).compactMap { match in
            guard let range = Range(match.range, in: value) else { return nil }
            return String(value[range])
        }
    }

    nonisolated fileprivate static func traditionalSummaryFragments(
        from pageEvidence: [RawPDFPageEvidence]
    ) throws -> [NormalizedDocument.SourceFragment] {
        guard !pageEvidence.isEmpty else {
            throw AxisCreditCardPDFNormalizationError.malformedSummary
        }
        var result: [NormalizedDocument.SourceFragment] = []
        func add(_ key: String, _ value: String) {
            result.append(.init(sourceOrdinal: 0, text: "\(key)\t\(value)"))
        }

        let balanceLabels = [
            "Previous Balance", "Payments", "Credits", "Purchase",
            "Cash Advance", "Other Debit/Charges"
        ]
        guard let balanceHeader = uniqueRectangularHeaderOccurrence(
            labels: balanceLabels,
            in: pageEvidence
        ) else {
            throw AxisCreditCardPDFNormalizationError.malformedSummary
        }
        let balanceOwnedRows = rectangularOwnedCandidateRows(
            labels: balanceLabels,
            header: balanceHeader,
            offsets: 1...2
        )
        guard !balanceOwnedRows.isEmpty else {
            throw AxisCreditCardPDFNormalizationError.malformedSummary
        }
        let balanceValueRows = balanceOwnedRows.compactMap { row -> [String: String]? in
            var values: [String: String] = [:]
            for label in balanceLabels {
                guard let raw = row[label] else { return nil }
                let candidates = summaryMoneyCandidates(raw)
                guard candidates.count == 1, let money = candidates.first else { return nil }
                values[label] = money.magnitude
            }
            return values
        }
        guard balanceValueRows.count == 1, let balanceValues = balanceValueRows.first else {
            throw AxisCreditCardPDFNormalizationError.malformedSummary
        }
        guard let openingBalance = balanceValues["Previous Balance"] else {
            throw AxisCreditCardPDFNormalizationError.malformedSummary
        }
        add("OPENING_BALANCE", openingBalance)

        let dueLabels = [
            "Total Payment Due", "Minimum Payment Due", "Statement Period",
            "Payment Due Date", "Statement Generation Date"
        ]
        guard let dueHeader = uniqueRectangularHeaderOccurrence(
            labels: dueLabels,
            in: pageEvidence
        ) else {
            throw AxisCreditCardPDFNormalizationError.malformedSummary
        }
        let dueOwnedRows = rectangularOwnedCandidateRows(
            labels: dueLabels,
            header: dueHeader,
            offsets: 1...1
        )
        guard !dueOwnedRows.isEmpty else {
            throw AxisCreditCardPDFNormalizationError.malformedSummary
        }
        let dueMoneyRows = dueOwnedRows.filter { row in
            guard let totalRaw = row["Total Payment Due"],
                  let minimumRaw = row["Minimum Payment Due"] else { return false }
            return summaryMoneyCandidates(totalRaw).count == 1 &&
                summaryMoneyCandidates(minimumRaw).count == 1
        }
        guard !dueMoneyRows.isEmpty else {
            throw AxisCreditCardPDFNormalizationError.malformedSummary
        }
        let dueValueRows = dueMoneyRows.filter { row in
            guard let periodRaw = row["Statement Period"],
                  let dueDateRaw = row["Payment Due Date"],
                  let generationRaw = row["Statement Generation Date"] else { return false }
            return summaryDates(periodRaw).count == 2 &&
                summaryDates(dueDateRaw).count == 1 &&
                summaryDates(generationRaw).count == 1
        }
        guard dueValueRows.count == 1, let dueValues = dueValueRows.first,
              let totalRaw = dueValues["Total Payment Due"],
              let periodRaw = dueValues["Statement Period"],
              let dueDateRaw = dueValues["Payment Due Date"],
              dueValues["Minimum Payment Due"] != nil,
              dueValues["Statement Generation Date"] != nil else {
            throw AxisCreditCardPDFNormalizationError.malformedSummary
        }
        let totalCandidates = summaryMoneyCandidates(totalRaw)
        guard totalCandidates.count == 1, let total = totalCandidates.first else {
            throw AxisCreditCardPDFNormalizationError.malformedSummary
        }
        let periodDates = summaryDates(periodRaw)
        let dueDates = summaryDates(dueDateRaw)
        add("TOTAL_PAYMENT_DUE", total.magnitude)
        add("PERIOD", "\(periodDates[0])\t\(periodDates[1])")
        add("PAYMENT_DUE_DATE", dueDates[0])
        return result
    }

    nonisolated fileprivate static func boundedWhitespace(_ value: String) -> String {
        clean(value).replacingOccurrences(of: "\\n+", with: "\\n", options: .regularExpression)
    }

    nonisolated fileprivate static func isHeader(_ line: String) -> Bool {
        let upper = line.uppercased()
        return upper == "DATE TRANSACTION DETAILS MERCHANT CATEGORY AMOUNT (RS.)" ||
            upper == "DATE TRANSACTION DETAILS AMOUNT (INR) DEBIT/CREDIT"
    }

    fileprivate struct RowFields {
        let date: String
        let details: String
        let amount: String
        let effect: String
        let reference: String?
        let originalAmount: String?
        let originalCurrency: String?
    }

    nonisolated fileprivate static func rowFields(_ line: String) -> RowFields? {
        // The last amount and direction are authoritative. Keeping the
        // description greedy permits source narrations containing INR tokens.
        let date = #"(?:\d{1,2}\s+[A-Za-z]{3}\s+'?\d{2,4}|\d{2}[/-]\d{2}[/-]\d{2,4})"#
        let amount = #"(?:INR\s*|₹\s*)?([0-9]{1,3}(?:,[0-9]{3})*|[0-9]+)\.([0-9]{2})"#
        let actual = "^(" + date + ")\\s+(.+?)\\s+" + amount + "\\s+(Debit|Credit|Dr|Cr)$"
        guard let regex = try? NSRegularExpression(pattern: actual, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.range.location == 0, match.range.length == line.utf16.count,
              let dateRange = Range(match.range(at: 1), in: line),
              let detailsRange = Range(match.range(at: 2), in: line),
              let integerRange = Range(match.range(at: 3), in: line),
              let fractionRange = Range(match.range(at: 4), in: line),
              let directionRange = Range(match.range(at: 5), in: line) else { return nil }
        let rawAmount = String(line[integerRange]).replacingOccurrences(of: ",", with: "") + "." + line[fractionRange]
        let direction = String(line[directionRange]).lowercased()
        let effect = (direction == "credit" || direction == "cr")
            ? CardLiabilityEffect.decreasesAmountOwed.rawValue
            : CardLiabilityEffect.increasesAmountOwed.rawValue
        return RowFields(date: String(line[dateRange]), details: String(line[detailsRange]).trimmingCharacters(in: .whitespaces), amount: rawAmount, effect: effect, reference: nil, originalAmount: nil, originalCurrency: nil)
    }

    nonisolated fileprivate static func looksLikeFinancialLine(_ line: String) -> Bool {
        line.range(of: #"^\d{1,2}\s+[A-Za-z]{3}\s+'?\d{2,4}\b"#, options: .regularExpression) != nil ||
            line.range(of: #"^\d{2}[/-]\d{2}[/-]\d{2,4}\b"#, options: .regularExpression) != nil
    }

    nonisolated static func sourceFragments(from text: String) -> [NormalizedDocument.SourceFragment] {
        var fragments: [NormalizedDocument.SourceFragment] = []
        let lines = text.components(separatedBy: .newlines).map(clean)
        func add(_ key: String, _ value: String) {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            fragments.append(.init(sourceOrdinal: fragments.count + 1, text: "\(key)\t\(value)"))
        }
        let all = lines.joined(separator: " ")
        if let value = captureDate(after: "Statement Date", in: all) {
            add("STATEMENT_DATE", value)
        }
        if let value = capturePeriod(in: all) { add("PERIOD", value) }
        if let value = selectedStatementMonth(in: all) {
            add("SELECTED_STATEMENT_MONTH", value)
        }
        if let value = captureMoney(after: "Opening Balance", in: all)
            ?? captureMoney(after: "Previous Balance", in: all) {
            add("OPENING_BALANCE", value)
        }
        if let value = captureMoney(after: "Total Payment Due", in: all) { add("TOTAL_PAYMENT_DUE", value) }
        if let value = captureDate(after: "Payment Due Date", in: all) { add("PAYMENT_DUE_DATE", value) }
        return fragments
    }

    nonisolated fileprivate static func selectedStatementMonth(in text: String) -> String? {
        let directPattern = #"Selected Statement Month\s*:?\s*((?:\d{4}[-/]\d{1,2})|(?:\d{1,2}[-/]\d{4})|(?:[A-Za-z]{3,9}\s+\d{4}))"#
        if let direct = capture(directPattern, in: text),
           let canonical = canonicalSelectedStatementMonth(direct) {
            return canonical
        }

        // Authentic Axis App PDFs are source-tagged correctly, but PDFKit can
        // emit the two letter "a" glyphs in "Statement" and Jan/May after
        // their surrounding text. Restrict this repair to the exact source
        // label and a short value window; never infer chronology from rows,
        // filenames, payment dates, or any other nearby date.
        let fragmentedLabel = #"Selected\s+St\s+tement\s+Month\s+a\b"#
        guard let regex = try? NSRegularExpression(pattern: fragmentedLabel, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let labelRange = Range(match.range, in: text) else {
            return nil
        }
        let suffix = String(text[labelRange.upperBound...].prefix(40))
        guard let raw = capture(
            #"^\s*([A-Za-z]{1,3}(?:\s+[A-Za-z]{1,3}){0,2}\s+\d{4}(?:\s+[A-Za-z])?)"#,
            in: suffix
        ) else {
            return nil
        }
        return canonicalSelectedStatementMonth(raw, allowDisplacedLetter: true)
    }

    nonisolated fileprivate static func canonicalSelectedStatementMonth(
        _ raw: String,
        allowDisplacedLetter: Bool = false
    ) -> String? {
        let pieces = raw.split(whereSeparator: { $0 == "-" || $0 == "/" || $0.isWhitespace }).map(String.init)
        if pieces.count == 2 {
            if let month = Int(pieces[0]), let year = Int(pieces[1]), (1...12).contains(month) {
                return String(format: "%04d-%02d", year, month)
            }
            if let year = Int(pieces[0]), let month = Int(pieces[1]), (1...12).contains(month) {
                return String(format: "%04d-%02d", year, month)
            }
            if let month = selectedMonthNumber(pieces[0]), let year = Int(pieces[1]) {
                return String(format: "%04d-%02d", year, month)
            }
        }

        guard allowDisplacedLetter,
              let yearIndex = pieces.firstIndex(where: { $0.count == 4 && Int($0) != nil }),
              let year = Int(pieces[yearIndex]), yearIndex > 0 else {
            return nil
        }
        let base = pieces[..<yearIndex].joined()
        if let month = selectedMonthNumber(base) {
            return String(format: "%04d-%02d", year, month)
        }
        guard yearIndex + 1 < pieces.count, pieces[yearIndex + 1].count == 1 else {
            return nil
        }
        let displaced = pieces[yearIndex + 1]
        for offset in 0...base.count {
            var repaired = base
            let index = repaired.index(repaired.startIndex, offsetBy: offset)
            repaired.insert(contentsOf: displaced, at: index)
            if let month = selectedMonthNumber(repaired) {
                return String(format: "%04d-%02d", year, month)
            }
        }
        return nil
    }

    nonisolated fileprivate static func selectedMonthNumber(_ raw: String) -> Int? {
        let abbreviations = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        if let index = abbreviations.firstIndex(where: { $0.caseInsensitiveCompare(raw) == .orderedSame }) {
            return index + 1
        }
        let full = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        return full.firstIndex(where: { $0.caseInsensitiveCompare(raw) == .orderedSame }).map { $0 + 1 }
    }

    nonisolated fileprivate static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated fileprivate static func captureMoney(after label: String, in text: String) -> String? {
        let pattern = NSRegularExpression.escapedPattern(for: label) + #"[^0-9]{0,80}(?:INR|₹)?\s*([0-9][0-9,]*\.\d{2})"#
        return capture(pattern, in: text)?.replacingOccurrences(of: ",", with: "")
    }

    nonisolated fileprivate static func captureDate(after label: String, in text: String) -> String? {
        let pattern = NSRegularExpression.escapedPattern(for: label) + #"[^0-9]{0,80}((?:\d{1,2}\s+[A-Za-z]{3}\s+'?\d{2,4}|\d{2}[/-]\d{2}[/-]\d{2,4}))"#
        return capture(pattern, in: text)
    }

    nonisolated fileprivate static func capturePeriod(in text: String) -> String? {
        let date = #"(?:\d{1,2}\s+[A-Za-z]{3}\s+'?\d{2,4}|\d{2}[/-]\d{2}[/-]\d{2,4})"#

        // Alternate/native linear representation: the period value follows its
        // label directly.
        let directPattern =
            #"Statement\s+Period[^0-9]{0,40}("# + date +
            #")\s+(?:to|-)\s+("# + date + #")"#

        // Traditional Axis statement: PDFKit extracts the five summary labels
        // first, followed by their five values. Therefore Total/Minimum Payment
        // Due precede the printed Statement Period in text order even though the
        // period is visually under its own column.
        let traditionalPattern =
            #"Total\s+Payment\s+Due\s+Minimum\s+Payment\s+Due\s+Statement\s+Period\s+Payment\s+Due\s+Date\s+Statement\s+Generation\s+Date\s+"# +
            #"[0-9][0-9,]*\.\d{2}\s+(?:Dr|Cr)\s+"# +
            #"[0-9][0-9,]*\.\d{2}\s+(?:Dr|Cr)\s+("# +
            date + #")\s*-\s*("# + date + #")"#

        for pattern in [directPattern, traditionalPattern] {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }

            guard let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            ),
            let first = Range(match.range(at: 1), in: text),
            let second = Range(match.range(at: 2), in: text) else {
                continue
            }

            return "\(text[first])\t\(text[second])"
        }

        return nil
    }
}
