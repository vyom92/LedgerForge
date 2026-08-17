import Foundation
import PDFKit

enum AmericanExpressCreditCardPDFNormalizationError: Error, Equatable, LocalizedError {
    case unsupportedNativeText
    case unsupportedFamily
    case changedHeader
    case malformedSummary
    case malformedTransaction(sourceOrdinal: Int)
    case malformedInstrumentSection
    case unconsumedFinancialPage(page: Int)
    case malformedNonFinancialPage(page: Int)

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
        "Liability Effect", "Scope", "Section ID"
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

    func normalize(text: String, sourceBytes: Data, fileURL: URL) throws -> AmericanExpressCreditCardPDFNormalizationResult {
        guard let pdf = PDFDocument(data: sourceBytes), pdf.pageCount >= 3 else {
            throw AmericanExpressCreditCardPDFNormalizationError.unsupportedNativeText
        }
        let pages = try (0..<pdf.pageCount).map { index -> String in
            guard let value = pdf.page(at: index)?.string,
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AmericanExpressCreditCardPDFNormalizationError.unsupportedNativeText
            }
            return value
        }
        return try normalize(text: text, pageTexts: pages, fileURL: fileURL)
    }

    func normalize(text: String, pageTexts pages: [String], fileURL: URL) throws -> AmericanExpressCreditCardPDFNormalizationResult {
        guard pages.count >= 3,
              pages.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw AmericanExpressCreditCardPDFNormalizationError.unsupportedNativeText
        }
        let joined = pages.joined(separator: "\n")
        guard joined == text || Self.boundedWhitespace(joined) == Self.boundedWhitespace(text) else {
            throw AmericanExpressCreditCardPDFNormalizationError.unsupportedNativeText
        }
        guard pages.allSatisfy({ page in
            page.contains("The Platinum Card (QAR)") &&
            page.contains("Statement of Account") &&
            page.contains("AMEX (MIDDLE EAST) B.S.C. (C)") &&
            page.contains("Membership Number") &&
            page.contains("Statement date") &&
            page.contains("Statement Period")
        }) else {
            throw AmericanExpressCreditCardPDFNormalizationError.unsupportedFamily
        }

        let membership = try Self.uniqueCapture(#"Membership Number\s+Statement date\s+Statement Period\s+([0-9X-]+)\s+\d{2}/\d{2}/\d{2}\s+\d{2}/\d{2}/\d{2} to \d{2}/\d{2}/\d{2}"#, in: joined)
        let statementDate = try Self.uniqueCapture(#"Membership Number\s+Statement date\s+Statement Period\s+[0-9X-]+\s+(\d{2}/\d{2}/\d{2})\s+\d{2}/\d{2}/\d{2} to \d{2}/\d{2}/\d{2}"#, in: joined)
        let period = try Self.uniqueCapture(#"Membership Number\s+Statement date\s+Statement Period\s+[0-9X-]+\s+\d{2}/\d{2}/\d{2}\s+(\d{2}/\d{2}/\d{2} to \d{2}/\d{2}/\d{2})"#, in: joined)
        let summaryPattern = #"Previous Balance\s+New Credits\s+New Debits\s+New Balance\s+Due Date\s+- \(QAR\) \+ \(QAR\) = \(QAR\)\s+(?:\(QAR\)\s+)?([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+([0-9,.]+)\s+(\d{2}/\d{2}/\d{2})"#
        guard let summary = Self.captures(summaryPattern, in: pages[0]), summary.count == 5 else {
            throw AmericanExpressCreditCardPDFNormalizationError.malformedSummary
        }
        let sectionPattern = #"^New Transactions For (.+?) Card Account Number: ([0-9X-]+)$"#
        let totalPattern = #"^Total of New Transactions For (.+?) ([0-9]+(?:,[0-9]{3})*\.\d{2})(?: ?(CR|DR))?$"#
        let sectionMatches = Self.allCaptures(sectionPattern, in: joined)
        let totalMatches = Self.allCaptures(totalPattern, in: joined)
        guard !sectionMatches.isEmpty, !totalMatches.isEmpty,
              sectionMatches.count >= totalMatches.count else {
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
        var sawRewards = false
        var sawInformation = false
        for (pageIndex, page) in pages.enumerated() {
            let hasFinancialRow = page.range(of: Self.rowStartPattern, options: [.regularExpression, .anchored], range: nil, locale: nil) != nil ||
                page.range(of: #"(?m)^\d{2}-[A-Za-z]{3}-\d{4} \d{2}-[A-Za-z]{3}-\d{4} "#, options: .regularExpression) != nil
            let hasFinancialStructure = hasFinancialRow ||
                page.contains("Transaction Date Posting Date Details Non QAR Spending Amount in QAR") ||
                page.contains("New Transactions For ") || page.contains("Total of New Transactions For ")
            if page.contains("Membership Rewards Period") {
                guard !hasFinancialRow,
                      page.contains("Membership Rewards Account Number"),
                      page.contains("New Points Card Type Account Number No. of Points"),
                      page.contains("Total New Paid Points"),
                      page.contains("Total Adjustments") else {
                    throw AmericanExpressCreditCardPDFNormalizationError.malformedNonFinancialPage(page: pageIndex + 1)
                }
                sawRewards = true
                continue
            }
            if !hasFinancialStructure {
                guard pageIndex == pages.count - 1,
                      page.contains("This Card is issued by AMEX (Middle East) B.S.C. (c)"),
                      !page.contains("New Transactions For"),
                      !page.contains("Total of New Transactions For") else {
                    throw AmericanExpressCreditCardPDFNormalizationError.malformedNonFinancialPage(page: pageIndex + 1)
                }
                sawInformation = true
                continue
            }
            if sawRewards || sawInformation {
                throw AmericanExpressCreditCardPDFNormalizationError.unconsumedFinancialPage(page: pageIndex + 1)
            }
            let lines = page.components(separatedBy: .newlines)
            var index = 0
            while index < lines.count {
                let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
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
                index += 1
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    if Self.captures(Self.rowStartPattern, in: candidate) != nil ||
                        candidate.hasPrefix("Total of New Transactions For ") ||
                        candidate.hasPrefix("New Transactions For ") ||
                        candidate.hasPrefix("This Card is issued by AMEX") {
                        break
                    }
                    if !candidate.isEmpty { block.append(candidate) }
                    index += 1
                }
                rows.append(try Self.normalizedRow(
                    sourceOrdinal: sourceOrdinal,
                    transactionDate: start[0],
                    postingDate: start[1],
                    block: block,
                    sectionID: currentSectionID
                ))
            }
        }
        guard !rows.isEmpty, currentSectionID == nil, sawRewards, sawInformation,
              rows.first?.values[8] == "account_level",
              rows.dropFirst().allSatisfy({ $0.values[8] == "instrument_level" || $0.values[8] == "account_level" }),
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

    private static func normalizedRow(sourceOrdinal: Int, transactionDate: String, postingDate: String, block: [String], sectionID: String?) throws -> NormalizedRow {
        let amountOnly = #"^(\#(postedMoney))(?: (CR))?$"#
        let foreign = #"^(\#(originalMoney)) ([A-Z]{3})(?: (CR))? (\#(postedMoney))(?: (CR))?$"#
        var amountMatch: (original: String, currency: String, posted: String, credit: Bool)?
        var details: [String] = []
        var reference: String?
        for line in block {
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
            } else if line.hasPrefix("Reference: ") {
                guard reference == nil else {
                    throw AmericanExpressCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: sourceOrdinal)
                }
                reference = String(line.dropFirst("Reference: ".count))
            } else {
                details.append(line)
            }
        }
        guard let amountMatch, let reference, !reference.isEmpty, !details.isEmpty else {
            throw AmericanExpressCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: sourceOrdinal)
        }
        let effect = amountMatch.credit ? CardLiabilityEffect.decreasesAmountOwed.rawValue : CardLiabilityEffect.increasesAmountOwed.rawValue
        let scope = sectionID == nil ? "account_level" : "instrument_level"
        return NormalizedRow(rowNumber: sourceOrdinal, values: [
            transactionDate, postingDate, details.joined(separator: "\n"), reference,
            amountMatch.original, amountMatch.currency, amountMatch.posted, effect,
            scope, sectionID ?? ""
        ])
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
