import Foundation

enum AmericanExpressCreditCardPDFNormalizationError: Error, Equatable, LocalizedError {
    case unsupportedNativeText
    case unsupportedFamily
    case changedHeader
    case malformedSummary
    case malformedTransaction(sourceOrdinal: Int)
    case malformedInstrumentSection
    case unconsumedFinancialPage(page: Int)
    case malformedNonFinancialPage(page: Int)
    case unknownPageContent(page: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedNativeText: return "The Amex statement requires native selectable PDF text."
        case .unsupportedFamily: return "The PDF is not the exact supported Amex Platinum QAR statement family."
        case .changedHeader: return "The Amex statement header or layout changed."
        case .malformedSummary: return "The Amex statement summary is malformed."
        case .malformedTransaction(let ordinal): return "Amex financial row \(ordinal) is malformed."
        case .malformedInstrumentSection: return "The Amex card-instrument section is malformed."
        case .unconsumedFinancialPage(let page): return "Amex page \(page) contains unconsumed financial evidence."
        case .malformedNonFinancialPage(let page): return "Amex page \(page) does not match an exact non-financial page signature."
        case .unknownPageContent(let page): return "Amex page \(page) has unknown content and cannot be accepted."
        }
    }
}

struct AmericanExpressCreditCardPDFNormalizationResult {
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow
    let sourceContext: NormalizedDocument.SourceContext
}

final class AmericanExpressCreditCardPDFNormalizer {
    static let logicalHeader = [
        "Transaction Date", "Posting Date", "Details", "Reference",
        "Original Amount", "Original Currency", "Posted Amount",
        "Liability Effect", "Scope", "Section ID", "Source Page"
    ]
    static let profileID = "amex.credit-card.pdf"
    static let profileVersion = "1"
    static func instrumentSectionID(ordinal: Int) -> String { "instrument-section-\(ordinal)" }

    private static let rowStartPattern = #"^(\d{2}-[A-Za-z]{3}-\d{4}) (\d{2}-[A-Za-z]{3}-\d{4}) (.+)$"#
    private static let postedMoney = #"[0-9]+(?:,[0-9]{3})*\.\d{2}"#
    private static let originalMoney = #"[0-9]+(?:,[0-9]{3})*(?:\.\d+)?"#

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func normalize(
        text: String,
        pageTexts pages: [String],
        pageEvidence: [RawPDFPageEvidence]? = nil,
        fileURL: URL
    ) throws -> AmericanExpressCreditCardPDFNormalizationResult {
        guard !pages.isEmpty,
              pages.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw AmericanExpressCreditCardPDFNormalizationError.unsupportedNativeText
        }
        let joined = pages.joined(separator: "\n")
        guard joined == text || Self.boundedWhitespace(joined) == Self.boundedWhitespace(text) else {
            throw AmericanExpressCreditCardPDFNormalizationError.unsupportedNativeText
        }
        guard joined.contains("The Platinum Card (QAR)"),
              joined.contains("Statement of Account"),
              joined.contains("AMEX (MIDDLE EAST) B.S.C. (C)"),
              joined.contains("Membership Number"),
              joined.contains("Statement date"),
              joined.contains("Statement Period") else {
            throw AmericanExpressCreditCardPDFNormalizationError.unsupportedFamily
        }

        let membership = try Self.uniqueCapture(#"Membership Number\s+Statement date\s+Statement Period\s+([0-9X-]+)\s+\d{2}/\d{2}/\d{2}\s+\d{2}/\d{2}/\d{2} to \d{2}/\d{2}/\d{2}"#, in: joined)
        let statementDate = try Self.uniqueCapture(#"Membership Number\s+Statement date\s+Statement Period\s+[0-9X-]+\s+(\d{2}/\d{2}/\d{2})\s+\d{2}/\d{2}/\d{2} to \d{2}/\d{2}/\d{2}"#, in: joined)
        let period = try Self.uniqueCapture(#"Membership Number\s+Statement date\s+Statement Period\s+[0-9X-]+\s+\d{2}/\d{2}/\d{2}\s+(\d{2}/\d{2}/\d{2} to \d{2}/\d{2}/\d{2})"#, in: joined)
        let summaryPattern = #"Previous Balance\s+New Credits\s+New Debits\s+New Balance\s+Due Date\s+- \(QAR\) \+ \(QAR\) = \(QAR\)\s+(?:\(QAR\)\s+)?([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+(\d{2}/\d{2}/\d{2})"#
        // Summary recognition is content-driven. It may be carried by any
        // financial page when pagination or a statement preamble changes;
        // requiring exactly one source equation prevents duplicate/conflicting
        // summaries from being silently accepted.
        let summaryMatches = pages.flatMap { Self.allCaptures(summaryPattern, in: $0) }
        guard summaryMatches.count == 1, summaryMatches[0].count == 5,
              let summary = summaryMatches.first else {
            throw AmericanExpressCreditCardPDFNormalizationError.malformedSummary
        }
        let sectionPattern = #"^New Transactions For (.+?) Card Account Number: ([0-9X-]+)$"#
        // The source-only corpus audit found plain totals plus two totals with
        // an explicit CR suffix; DR is not part of this Amex layout contract.
        let totalPattern = #"^Total of New Transactions For (.+?) ([0-9]+(?:,[0-9]{3})*\.\d{2})(?: ?(CR))?$"#
        let sectionMatches = Self.allCaptures(sectionPattern, in: joined)
        let totalMatches = Self.allCaptures(totalPattern, in: joined)
        guard sectionMatches.count >= totalMatches.count else {
            throw AmericanExpressCreditCardPDFNormalizationError.malformedInstrumentSection
        }

        struct ParsedSection {
            let id: String
            let holder: String
            let account: String
            let total: String
            let isCredit: Bool
        }

        var currentSectionID: String?
        var currentSectionHolder: String?
        var currentSectionAccount: String?
        var parsedSections: [ParsedSection] = []
        var rows: [NormalizedRow] = []
        for (pageIndex, page) in pages.enumerated() {
            let pageNumber = pageIndex + 1
            // Nonfinancial pages are packaging, not required profile members.
            // Inert inserts may precede, follow or interrupt financial pages;
            // malformed row/control evidence may never be skipped as an insert.
            if !Self.containsFinancialStructure(page, summaryPattern: summaryPattern) {
                guard !Self.containsUnresolvedFinancialStructure(page) else {
                    throw AmericanExpressCreditCardPDFNormalizationError.unconsumedFinancialPage(page: pageNumber)
                }
                continue
            }
            let lines = try Self.financialLines(
                page, evidence: pageEvidence.flatMap { $0.indices.contains(pageIndex) ? $0[pageIndex] : nil },
                pageNumber: pageNumber
            )
            // Account for every non-empty line on a financial page. A line is
            // consumed only by an exact source grammar (masthead/header,
            // summary/table marker, section marker, row band, or repeated
            // footer). Any residue is surfaced instead of being silently
            // skipped by the row scanner.
            var consumedLineIndices = Set<Int>()
            let mastheadBoundary = lines.firstIndex(where: { Self.startsTransactionRegion($0) }) ?? 0
            let footerBoundary = lines.firstIndex(where: { Self.isIssuerFooterStart($0) }) ?? lines.endIndex
            var summaryValuesRemaining = 0
            for lineIndex in lines.indices {
                let line = lines[lineIndex]
                if line.isEmpty {
                    consumedLineIndices.insert(lineIndex)
                    continue
                }
                if lineIndex >= footerBoundary {
                    guard !Self.containsUnresolvedFinancialStructure(line) else {
                        throw AmericanExpressCreditCardPDFNormalizationError.unconsumedFinancialPage(page: pageNumber)
                    }
                    consumedLineIndices.insert(lineIndex)
                    continue
                }
                if lineIndex < mastheadBoundary {
                    // Source identity/period values are checked coherently
                    // above. Address and contact typography do not define the
                    // financial body and are not matched by private hashes.
                    consumedLineIndices.insert(lineIndex)
                    continue
                }
                if Self.isAcceptedFinancialPreambleLine(line) {
                    consumedLineIndices.insert(lineIndex)
                }
                if Self.isAcceptedSummaryExpressionLine(line) {
                    let valueCount = Self.allCaptures(#"([0-9]+(?:,[0-9]{3})*\.\d{2})"#, in: line).count
                    summaryValuesRemaining = max(0, 5 - valueCount)
                    consumedLineIndices.insert(lineIndex)
                } else if summaryValuesRemaining > 0 {
                    if line.range(of: #"^[0-9]+(?:,[0-9]{3})*\.\d{2}$"#, options: .regularExpression) != nil ||
                        line.range(of: #"^\d{2}/\d{2}/\d{2}$"#, options: .regularExpression) != nil {
                        consumedLineIndices.insert(lineIndex)
                        summaryValuesRemaining -= 1
                    }
                }
            }
            var index = 0
            while index < lines.count {
                let line = lines[index]
                if index >= footerBoundary { break }
                if line.isEmpty {
                    consumedLineIndices.insert(index)
                    index += 1
                    continue
                }
                if let opening = Self.captures(sectionPattern, in: line), opening.count == 2 {
                    if currentSectionID != nil {
                        guard currentSectionHolder == opening[0],
                              currentSectionAccount == opening[1] else {
                            throw AmericanExpressCreditCardPDFNormalizationError.malformedInstrumentSection
                        }
                    } else {
                        currentSectionID = Self.instrumentSectionID(ordinal: parsedSections.count + 1)
                        currentSectionHolder = opening[0]
                        currentSectionAccount = opening[1]
                    }
                    consumedLineIndices.insert(index)
                    index += 1
                    continue
                }
                if let total = Self.captures(totalPattern, in: line), total.count == 3 {
                    guard let sectionID = currentSectionID,
                          let holder = currentSectionHolder,
                          let account = currentSectionAccount,
                          total[0] == holder else {
                        throw AmericanExpressCreditCardPDFNormalizationError.malformedInstrumentSection
                    }
                    parsedSections.append(ParsedSection(
                        id: sectionID,
                        holder: holder,
                        account: account,
                        total: total[1],
                        isCredit: total[2] == "CR"
                    ))
                    consumedLineIndices.insert(index)
                    currentSectionID = nil
                    currentSectionHolder = nil
                    currentSectionAccount = nil
                    index += 1
                    continue
                }
                guard let start = Self.captures(Self.rowStartPattern, in: line), start.count == 3 else {
                    index += 1
                    continue
                }
                let sourceOrdinal = rows.count + 1
                var block = [start[2]]
                consumedLineIndices.insert(index)
                index += 1
                while index < lines.count {
                    let candidate = lines[index]
                    if index >= footerBoundary || Self.captures(Self.rowStartPattern, in: candidate) != nil ||
                        candidate.hasPrefix("Total of New Transactions For ") ||
                        candidate.hasPrefix("New Transactions For ") {
                        break
                    }
                    consumedLineIndices.insert(index)
                    if !candidate.isEmpty { block.append(candidate) }
                    index += 1
                }
                rows.append(try Self.normalizedRow(
                    sourceOrdinal: sourceOrdinal,
                    transactionDate: start[0],
                    postingDate: start[1],
                    block: block,
                    sectionID: currentSectionID,
                    sourcePage: pageNumber
                ))
            }
            guard !lines.indices.contains(where: { index in
                !lines[index].isEmpty && !consumedLineIndices.contains(index)
            }) else {
                throw AmericanExpressCreditCardPDFNormalizationError.unconsumedFinancialPage(page: pageNumber)
            }
        }
        guard currentSectionID == nil,
              rows.allSatisfy({ $0.values[8] == "instrument_level" || $0.values[8] == "account_level" }),
              parsedSections.count == totalMatches.count,
              zip(parsedSections, totalMatches).allSatisfy({ section, capture in
                  capture.count == 3 && section.holder == capture[0] && section.total == capture[1] &&
                  section.isCredit == (capture[2] == "CR")
              }) else {
            throw AmericanExpressCreditCardPDFNormalizationError.malformedInstrumentSection
        }

        var document = Document(filename: fileURL.lastPathComponent, url: fileURL, fileType: FileFormat.pdf.rawValue, importedAt: now())
        document.rowCount = rows.count
        document.headerRow = 1
        document.firstTransactionRow = rows.first?.rowNumber
        document.columnCount = Self.logicalHeader.count
        document.encoding = "UTF-8"
        var fragments: [NormalizedDocument.SourceFragment] = [
            .init(sourceOrdinal: 1, text: "MEMBERSHIP_NUMBER\t\(membership)"),
            .init(sourceOrdinal: 2, text: "STATEMENT_DATE\t\(statementDate)"),
            .init(sourceOrdinal: 3, text: "PERIOD\t\(period)"),
            .init(sourceOrdinal: 4, text: "PREVIOUS_BALANCE\t\(summary[0])"),
            .init(sourceOrdinal: 5, text: "NEW_CREDITS\t\(summary[1])"),
            .init(sourceOrdinal: 6, text: "NEW_DEBITS\t\(summary[2])"),
            .init(sourceOrdinal: 7, text: "NEW_BALANCE\t\(summary[3])"),
            .init(sourceOrdinal: 8, text: "DUE_DATE\t\(summary[4])")
        ]
        for (index, section) in parsedSections.enumerated() {
            fragments.append(.init(
                sourceOrdinal: 9 + index,
                text: "INSTRUMENT_SECTION\t\(section.id)\t\(section.account)\t\(section.holder)\t\(section.total)\t\(section.isCredit ? "CR" : "")"
            ))
        }
        return AmericanExpressCreditCardPDFNormalizationResult(
            document: document,
            rows: rows,
            header: NormalizedRow(rowNumber: 1, values: Self.logicalHeader),
            sourceContext: .init(preTransactionFragments: fragments, postTransactionFragments: [])
        )
    }

    private static func normalizedRow(sourceOrdinal: Int, transactionDate: String, postingDate: String, block: [String], sectionID: String?, sourcePage: Int) throws -> NormalizedRow {
        let amountOnly = #"^(\#(postedMoney))(?: (CR))?$"#
        let foreign = #"^(\#(originalMoney)) ([A-Z]{3})(?: (CR))? (\#(postedMoney))(?: (CR))?$"#
        var amountMatch: (original: String, currency: String, posted: String, credit: Bool)?
        var details: [String] = []
        var reference: String?
        for (lineIndex, line) in block.enumerated() {
            if let values = captures(foreign, in: line), values.count == 5 {
                guard amountMatch == nil, (values[2].isEmpty == values[4].isEmpty) else {
                    throw AmericanExpressCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: sourceOrdinal)
                }
                amountMatch = (values[0], values[1], values[3], !values[4].isEmpty)
            } else if let values = captures(amountOnly, in: line), values.count == 2 {
                guard amountMatch == nil else {
                    throw AmericanExpressCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: sourceOrdinal)
                }
                amountMatch = ("", "", values[0], !values[1].isEmpty)
            } else if line == "Reference:" || line.hasPrefix("Reference: ") {
                // PDFKit may position the source Reference marker after the
                // amount line for a bounded subset of authentic rows. The
                // marker still belongs to the same row and remains source
                // authority; line order must not change its semantics. An
                // explicit empty marker or duplicate marker is malformed.
                let rawValue = line.hasPrefix("Reference: ")
                    ? String(line.dropFirst("Reference: ".count))
                    : ""
                let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else {
                    throw AmericanExpressCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: sourceOrdinal)
                }
                if amountMatch != nil {
                    guard reference == nil,
                          lineIndex == block.index(before: block.endIndex),
                          rawValue == value else {
                        throw AmericanExpressCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: sourceOrdinal)
                    }
                    reference = value
                } else {
                    guard reference == nil else {
                        throw AmericanExpressCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: sourceOrdinal)
                    }
                    reference = value
                }
            } else {
                // Detail continuations belong to the source-defined row band,
                // regardless of whether PDF extraction emitted its amount
                // first. Merchant names and wrapped text are not allowlists.
                // A new malformed row/control is never narration.
                if amountMatch != nil {
                    guard !Self.containsUnresolvedFinancialStructure(line) else {
                        throw AmericanExpressCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: sourceOrdinal)
                    }
                }
                details.append(line)
            }
        }
        // Amex may omit a printed Reference line for certain merchant rows;
        // preserve that source absence as an empty normalized field rather
        // than inventing or rejecting a reference.
        guard let amountMatch, !details.isEmpty else {
            throw AmericanExpressCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: sourceOrdinal)
        }
        let effect = amountMatch.credit ? CardLiabilityEffect.decreasesAmountOwed.rawValue : CardLiabilityEffect.increasesAmountOwed.rawValue
        let scope = sectionID == nil ? "account_level" : "instrument_level"
        return NormalizedRow(rowNumber: sourceOrdinal, values: [
            transactionDate, postingDate, details.joined(separator: "\n"), reference ?? "",
            amountMatch.original, amountMatch.currency, amountMatch.posted, effect,
            scope, sectionID ?? "", String(sourcePage)
        ], sourcePage: sourcePage)
    }


    private static func containsFinancialRow(_ page: String) -> Bool {
        page.components(separatedBy: .newlines).contains { line in
            captures(rowStartPattern, in: line.trimmingCharacters(in: .whitespacesAndNewlines))?.count == 3
        }
    }

    private static func startsTransactionRegion(_ line: String) -> Bool {
        line.hasPrefix("Transaction Date Posting Date") ||
            line.hasPrefix("New Transactions For") || line.hasPrefix("Total of New Transactions For") ||
            captures(rowStartPattern, in: line) != nil
    }

    private static func isIssuerFooterStart(_ line: String) -> Bool {
        line.hasPrefix("This Card is issued by AMEX (Middle East)")
    }

    /// PDF extraction order can interleave footer text before the final row's
    /// amount. Derive the footer boundary from its semantic label and reader
    /// geometry, not its extraction index or a fixed page coordinate.
    private static func financialLines(
        _ page: String, evidence: RawPDFPageEvidence?, pageNumber: Int
    ) throws -> [String] {
        let lines = page.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let footerIndex = lines.firstIndex(where: { isIssuerFooterStart($0) }) else { return lines }
        guard let evidence, !evidence.fragments.isEmpty else {
            throw AmericanExpressCreditCardPDFNormalizationError.unsupportedNativeText
        }
        var cursor = 0
        var lineFragments: [[RawPDFTextFragment]] = []
        for line in lines {
            let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard cursor + tokens.count <= evidence.fragments.count else {
                throw AmericanExpressCreditCardPDFNormalizationError.unsupportedNativeText
            }
            let fragments = Array(evidence.fragments[cursor..<(cursor + tokens.count)])
            guard fragments.map(\.text) == tokens, fragments.allSatisfy({ $0.geometry?.isCanonical == true }) else {
                throw AmericanExpressCreditCardPDFNormalizationError.unsupportedNativeText
            }
            lineFragments.append(fragments)
            cursor += tokens.count
        }
        guard cursor == evidence.fragments.count,
              let footerY = lineFragments[footerIndex].map(\.y).max() else {
            throw AmericanExpressCreditCardPDFNormalizationError.unsupportedNativeText
        }
        return try lines.indices.compactMap { index in
            let fragments = lineFragments[index]
            guard !fragments.isEmpty else { return lines[index] }
            if fragments.allSatisfy({ $0.y <= footerY + 0.5 }) {
                guard !containsUnresolvedFinancialStructure(lines[index]),
                      captures(#"^\#(postedMoney)(?: CR)?$"#, in: lines[index]) == nil else {
                    throw AmericanExpressCreditCardPDFNormalizationError.unconsumedFinancialPage(page: pageNumber)
                }
                return nil
            }
            return lines[index]
        }
    }

    private static func containsUnresolvedFinancialStructure(_ text: String) -> Bool {
        // Rewards may also print "Previous Balance" for points. Financial
        // summary reentry requires the monetary control-label relationship,
        // not a shared English word in isolation.
        if text.contains("New Credits") && (text.contains("New Debits") || text.contains("New Balance")) { return true }
        return text.components(separatedBy: .newlines).contains { raw in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("New Transactions For") || line.hasPrefix("Total of New Transactions For") ||
                line.hasPrefix("Transaction Date Posting Date") ||
                line.hasPrefix("- (QAR) + (QAR)") { return true }
            // Recognize malformed/variant row starts by two source-date
            // fields even when the exact row grammar cannot consume them.
            return line.range(of: #"^\d{1,2}[-/][A-Za-z0-9]{2,9}[-/]\d{2,4}\s+\d{1,2}[-/][A-Za-z0-9]{2,9}[-/]\d{2,4}\b"#,
                options: .regularExpression) != nil
        }
    }

    private static func containsFinancialStructure(_ page: String, summaryPattern: String) -> Bool {
        let lines = page.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let sectionPattern = "^New Transactions For (.+?) Card Account Number: ([0-9X-]+)$"
        let totalPattern = "^Total of New Transactions For (.+?) ([0-9,.]+)(?: ?(CR))?$"
        let hasExactSectionHeader = lines.contains {
            guard let captures = captures(sectionPattern, in: $0) else { return false }
            return captures.count == 2 && !captures[0].isEmpty && !captures[1].isEmpty
        }
        let hasExactSectionTotal = lines.contains {
            guard let captures = captures(totalPattern, in: $0) else { return false }
            return captures.count == 3 && !captures[0].isEmpty && !captures[1].isEmpty
        }
        let hasExactTableHeader = lines.contains {
            $0 == "Transaction Date Posting Date Details Non QAR Spending Amount in QAR"
        }
        // Every non-row financial marker must satisfy its complete source
        // grammar. A body containing only a partial section marker or total
        // marker remains unknown and fails closed instead of being skipped as
        // a financial page.
        return containsFinancialRow(page) ||
            hasExactTableHeader ||
            hasExactSectionHeader ||
            hasExactSectionTotal ||
            !allCaptures(summaryPattern, in: page).isEmpty
    }

    /// Financial labels and source controls remain explicit. Nonfinancial
    /// masthead/address/footer text is handled by its surrounding source region,
    /// never a statement-specific text or hash allowlist.
    private static func isAcceptedFinancialPreambleLine(_ line: String) -> Bool {
        if line == "Transaction Date Posting Date Details Non QAR Spending Amount in QAR" ||
            line == "Previous Balance" ||
            line == "New Credits" ||
            line == "New Debits" ||
            line == "New Balance" ||
            line == "Due Date" ||
            Self.isAcceptedSummaryExpressionLine(line) {
            return true
        }
        return false
    }

    /// Summary expression lines are accepted only in the complete source
    /// grammar: one to four posted amounts (the authentic PDF may place the
    /// remaining values on following lines) and an optional due date. A bare
    /// expression prefix with arbitrary suffix text is not evidence.
    private static func isAcceptedSummaryExpressionLine(_ line: String) -> Bool {
        line.range(of: #"^- \(QAR\) \+ \(QAR\) = \(QAR\)(?: \(QAR\))? [0-9]+(?:,[0-9]{3})*\.\d{2}(?: [0-9]+(?:,[0-9]{3})*\.\d{2}){0,3}(?: \d{2}/\d{2}/\d{2})?$"#, options: .regularExpression) != nil
    }



    private static func uniqueCapture(_ pattern: String, in text: String) throws -> String {
        let values = allCaptures(pattern, in: text).compactMap(\.first)
        guard let first = values.first, values.allSatisfy({ $0 == first }) else {
            throw AmericanExpressCreditCardPDFNormalizationError.changedHeader
        }
        return first
    }

    private static func allCaptures(_ pattern: String, in text: String) -> [[String]] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]) else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (1..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: text) else { return "" }
                return String(text[range])
            }
        }
    }

    private static func captures(_ pattern: String, in text: String) -> [String]? {
        allCaptures(pattern, in: text).first
    }

    private static func boundedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
