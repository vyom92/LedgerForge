import Foundation
import PDFKit

enum CBQCreditCardPDFNormalizationError: Error, Equatable, LocalizedError {
    case unsupportedNativeText
    case unsupportedFamily
    case changedHeader
    case malformedPreamble
    case malformedSummary
    case malformedTransaction(sourceOrdinal: Int)
    case malformedInstrumentSection
    case unconsumedFinancialPage(page: Int)
    case malformedNonFinancialPage(page: Int)
    case missingTermination

    var errorDescription: String? {
        switch self {
        case .unsupportedNativeText: return "The CBQ credit-card PDF must contain three pages of native selectable text."
        case .unsupportedFamily: return "The PDF is not the exact CBQ credit-card statement family."
        case .changedHeader: return "The CBQ credit-card statement header changed."
        case .malformedPreamble: return "The CBQ credit-card statement preamble is malformed."
        case .malformedSummary: return "The CBQ credit-card statement summary is malformed."
        case .malformedTransaction(let ordinal): return "CBQ credit-card row " + String(ordinal) + " is malformed."
        case .malformedInstrumentSection: return "A CBQ credit-card instrument section is malformed."
        case .unconsumedFinancialPage(let page): return "CBQ credit-card page " + String(page) + " contains unconsumed financial evidence."
        case .malformedNonFinancialPage(let page): return "CBQ credit-card page " + String(page) + " does not match its exact non-financial signature."
        case .missingTermination: return "The CBQ credit-card statement has no exact End of Statement marker."
        }
    }
}

struct CBQCreditCardPDFNormalizationResult {
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow
    let sourceContext: NormalizedDocument.SourceContext
}

/// Normalizes only the native selectable-text CBQ card grammar. It deliberately
/// does not create decrypted files and does not interpret transactions beyond
/// the source facts required by the parser (dates, money tail, section and
/// exact reference line).
final class CBQCreditCardPDFNormalizer {
    static let logicalHeader = [
        "Posting Date", "Purchase Date", "Description", "Reference",
        "Original Amount", "Original Currency", "Posted Amount",
        "Liability Effect", "Scope", "Section ID", "Source Page", "Internal Version"
    ]
    static let profileID = "cbq.credit-card.pdf"
    static let profileVersion = "1"

    private enum InternalVersion: String { case v1, v2 }
    private struct Section {
        let id: String
        let label: String
        let holder: String?
        let card: String
        let subtotal: String
        let subtotalIsCredit: Bool
    }
    private struct Tail {
        let description: String
        let original: String?
        let originalCurrency: String?
        let posted: String
        let isCredit: Bool
    }

    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) { self.now = now }

    func normalize(text: String, sourceBytes: Data, fileURL: URL) throws -> CBQCreditCardPDFNormalizationResult {
        guard let pdf = PDFDocument(data: sourceBytes), pdf.pageCount == 3, !pdf.isLocked else {
            throw CBQCreditCardPDFNormalizationError.unsupportedNativeText
        }
        let pages = try (0..<pdf.pageCount).map { index -> String in
            guard let pageText = pdf.page(at: index)?.string,
                  !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CBQCreditCardPDFNormalizationError.unsupportedNativeText
            }
            return pageText
        }
        return try normalize(text: text, pageTexts: pages, fileURL: fileURL)
    }

    /// This overload is intentionally useful for deterministic tests and for
    /// the reader handoff, which already owns page extraction.
    func normalize(text: String, pageTexts pages: [String], fileURL: URL) throws -> CBQCreditCardPDFNormalizationResult {
        guard pages.count == 3,
              pages.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw CBQCreditCardPDFNormalizationError.unsupportedNativeText
        }
        let joined = pages.joined(separator: "\n")
        guard joined == text || Self.boundedWhitespace(joined) == Self.boundedWhitespace(text) else {
            throw CBQCreditCardPDFNormalizationError.unsupportedNativeText
        }

        let flattened = Self.boundedWhitespace(joined)
        guard flattened.contains("Card Account Reference"),
              flattened.contains("Card Number Card Holder Name Product Card Limit"),
              flattened.contains("Post Date Purchase Date Description & Referance Foreign Currency Amount in QAR") else {
            throw CBQCreditCardPDFNormalizationError.unsupportedFamily
        }

        let version: InternalVersion
        if flattened.contains("Previous Outstanding Balance") &&
            flattened.contains("Amount Billed") &&
            flattened.contains("Payment Received") &&
            flattened.contains("Current Outstanding Balance") {
            version = .v1
        } else if flattened.contains("Reversal Purchases Billed Installment Fees/") ||
                    (flattened.contains("Purchases") &&
                     flattened.contains("Billed Installment") &&
                     flattened.contains("Fees and Charges") &&
                     flattened.contains("Total Payment") &&
                     flattened.contains("Credit Reversal") &&
                     flattened.contains("Current Outstanding Balance")) {
            version = .v2
        } else {
            throw CBQCreditCardPDFNormalizationError.malformedSummary
        }

        let accountReference = try Self.requiredValue(
            labels: ["Card Account Reference"], in: joined, error: .malformedPreamble
        )
        let statementDate = try Self.requiredDate(
            labels: ["Statement Date", "Statement date"], in: joined, error: .malformedPreamble
        )
        let dueDate = try Self.requiredDate(
            labels: ["Payment Due Date", "Due Date", "Due date"], in: joined, error: .malformedPreamble
        )
        let period = try Self.requiredPeriod(in: joined)

        let summary = try Self.summaryFragments(version: version, in: joined)

        let sections = try Self.parseSections(pages: pages)
        guard sections.count == 2,
              Set(sections.map(\.label)) == Set(["Diners Club", "Mastercard Platinum"]) else {
            throw CBQCreditCardPDFNormalizationError.malformedInstrumentSection
        }

        var rows: [NormalizedRow] = []
        var currentSectionID: String?
        var sawTermination = false
        var postTerminationLines: [String] = []
        var sourceOrdinal = 0
        for (pageIndex, page) in pages.enumerated() {
            let lines = page.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            var index = 0
            var sawContinuation = false
            while index < lines.count {
                let line = lines[index]
                if line.isEmpty { index += 1; continue }
                if sawTermination {
                    postTerminationLines.append(line)
                    index += 1
                    continue
                }
                if Self.isEndOfStatement(line) {
                    guard currentSectionID == nil else { throw CBQCreditCardPDFNormalizationError.malformedInstrumentSection }
                    sawTermination = true
                    postTerminationLines.append(line)
                    index += 1
                    continue
                }
                if line == "Continued on next page..." {
                    guard currentSectionID != nil else { throw CBQCreditCardPDFNormalizationError.malformedInstrumentSection }
                    sawContinuation = true
                    index += 1
                    continue
                }
                if let opening = Self.sectionDescriptor(line: line) {
                    guard let expected = sections.first(where: { $0.label == opening.label }),
                          expected.card == opening.card else {
                        throw CBQCreditCardPDFNormalizationError.malformedInstrumentSection
                    }
                    if let currentSectionID {
                        guard let existing = sections.first(where: { $0.id == currentSectionID }),
                              existing.label == expected.label && existing.card == expected.card else {
                            throw CBQCreditCardPDFNormalizationError.malformedInstrumentSection
                        }
                    } else {
                        currentSectionID = expected.id
                    }
                    index += 1
                    continue
                }
                if let total = Self.subtotal(line: line) {
                    guard let sectionID = currentSectionID,
                          let expected = sections.first(where: { $0.id == sectionID }),
                          expected.subtotal == total.amount,
                          expected.subtotalIsCredit == total.isCredit else {
                        throw CBQCreditCardPDFNormalizationError.malformedInstrumentSection
                    }
                    currentSectionID = nil
                    index += 1
                    continue
                }
                if Self.isStructuralHeader(line) || Self.isPreambleLine(line) {
                    index += 1
                    continue
                }
                if let start = Self.rowStart(line) {
                    guard currentSectionID != nil else {
                        throw CBQCreditCardPDFNormalizationError.malformedInstrumentSection
                    }
                    guard let tail = Self.moneyTail(start.description) else {
                        if rows.isEmpty { throw CBQCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: sourceOrdinal + 1) }
                        var continuation = line
                        var next = index + 1
                        while next < lines.count {
                            let candidate = lines[next]
                            if candidate.isEmpty { next += 1; continue }
                            if let candidateStart = Self.rowStart(candidate), Self.moneyTail(candidateStart.description) != nil { break }
                            if Self.sectionDescriptor(line: candidate) != nil || Self.subtotal(line: candidate) != nil ||
                                Self.isEndOfStatement(candidate) || candidate == "Continued on next page..." { break }
                            continuation += "\n" + candidate
                            next += 1
                        }
                        rows[rows.count - 1] = try Self.appendNarration(continuation, to: rows[rows.count - 1])
                        index = next
                        continue
                    }
                    sourceOrdinal += 1
                    var description = tail.description
                    var reference: String?
                    var next = index + 1
                    while next < lines.count {
                        let candidate = lines[next]
                        if candidate.isEmpty { next += 1; continue }
                        if Self.rowStart(candidate) != nil || Self.sectionDescriptor(line: candidate) != nil ||
                            Self.subtotal(line: candidate) != nil || Self.isEndOfStatement(candidate) ||
                            candidate == "Continued on next page..." { break }
                        if candidate.hasPrefix("Reference:") {
                            guard reference == nil else { throw CBQCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: sourceOrdinal) }
                            let value = String(candidate.dropFirst("Reference:".count)).trimmingCharacters(in: .whitespaces)
                            guard !value.isEmpty else { throw CBQCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: sourceOrdinal) }
                            reference = value
                        } else {
                            description += "\n" + candidate
                        }
                        next += 1
                    }
                    let effect = tail.isCredit ? CardLiabilityEffect.decreasesAmountOwed.rawValue : CardLiabilityEffect.increasesAmountOwed.rawValue
                    let scope = description.hasPrefix("Paid using bankDirect") ? "account_level" : "instrument_level"
                    rows.append(NormalizedRow(rowNumber: sourceOrdinal, values: [
                        start.postingDate, start.purchaseDate, description, reference ?? "",
                        tail.original ?? "", tail.originalCurrency ?? "", tail.posted, effect,
                        scope, currentSectionID ?? "", String(pageIndex + 1), version.rawValue
                    ]))
                    index = next
                    continue
                }
                if Self.looksFinancial(line) {
                    throw CBQCreditCardPDFNormalizationError.unconsumedFinancialPage(page: pageIndex + 1)
                }
                index += 1
            }
            if sawContinuation {
                guard pageIndex + 1 < pages.count, let open = currentSectionID,
                      let section = sections.first(where: { $0.id == open }),
                      pages[pageIndex + 1].contains(section.label),
                      pages[pageIndex + 1].contains("Card Number Card Holder Name Product Card Limit") else {
                    throw CBQCreditCardPDFNormalizationError.malformedInstrumentSection
                }
            } else if currentSectionID != nil && pageIndex + 1 < pages.count {
                throw CBQCreditCardPDFNormalizationError.malformedInstrumentSection
            }
        }
        guard sawTermination, currentSectionID == nil, !rows.isEmpty else {
            throw CBQCreditCardPDFNormalizationError.missingTermination
        }
        guard Self.matchesPostTerminationTail(postTerminationLines, version: version) else {
            throw CBQCreditCardPDFNormalizationError.malformedNonFinancialPage(page: pages.count)
        }

        var document = Document(filename: fileURL.lastPathComponent, url: fileURL, fileType: FileFormat.pdf.rawValue, importedAt: now())
        document.rowCount = rows.count
        document.headerRow = 1
        document.firstTransactionRow = rows.first?.rowNumber
        document.columnCount = Self.logicalHeader.count
        document.encoding = "UTF-8"
        var fragments: [NormalizedDocument.SourceFragment] = [
            .init(sourceOrdinal: 1, text: "PROFILE_VERSION\t\(version.rawValue)"),
            .init(sourceOrdinal: 2, text: "CARD_ACCOUNT_REFERENCE\t\(accountReference)"),
            .init(sourceOrdinal: 3, text: "STATEMENT_DATE\t\(statementDate)"),
            .init(sourceOrdinal: 4, text: "PERIOD\t\(period.start)\t\(period.end)"),
            .init(sourceOrdinal: 5, text: "DUE_DATE\t\(dueDate)")
        ]
        for (offset, item) in summary.enumerated() {
            fragments.append(.init(sourceOrdinal: 6 + offset, text: "SUMMARY\t\(item.0)\t\(item.1)"))
        }
        for section in sections {
            fragments.append(.init(sourceOrdinal: fragments.count + 1, text: "INSTRUMENT_SECTION\t\(section.id)\t\(section.label)\t\(section.card)\t\(section.holder ?? "")\t\(section.subtotal)\t\(section.subtotalIsCredit ? "CR" : "")"))
        }
        return CBQCreditCardPDFNormalizationResult(
            document: document,
            rows: rows,
            header: NormalizedRow(rowNumber: 1, values: Self.logicalHeader),
            sourceContext: .init(preTransactionFragments: fragments)
        )
    }

    private static func parseSections(pages: [String]) throws -> [Section] {
        var result: [Section] = []
        var nextID = 1
        let lines = pages.flatMap {
            $0.components(separatedBy: .newlines).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        for (index, line) in lines.enumerated() {
            guard let opening = sectionDescriptor(line: line),
                  !result.contains(where: { $0.label == opening.label }) else { continue }
            var parsedSubtotal: (amount: String, isCredit: Bool)?
            var cursor = index + 1
            while cursor < lines.count {
                let candidate = lines[cursor]
                if let nextOpening = sectionDescriptor(line: candidate),
                   nextOpening.label != opening.label {
                    break
                }
                if let total = subtotal(line: candidate) {
                    parsedSubtotal = total
                    break
                }
                cursor += 1
            }
            guard let parsedSubtotal else {
                throw CBQCreditCardPDFNormalizationError.malformedInstrumentSection
            }
            result.append(Section(
                id: "instrument-section-\(nextID)",
                label: opening.label,
                holder: opening.holder,
                card: opening.card,
                subtotal: parsedSubtotal.amount,
                subtotalIsCredit: parsedSubtotal.isCredit
            ))
            nextID += 1
        }
        return result
    }

    private struct Descriptor {
        let label: String
        let holder: String?
        let card: String
    }

    private static func sectionDescriptor(line: String) -> Descriptor? {
        let label: String
        if line.range(of: "Diners Club", options: .caseInsensitive) != nil {
            label = "Diners Club"
        } else if line.range(of: "Mastercard Platinum", options: .caseInsensitive) != nil {
            label = "Mastercard Platinum"
        } else {
            return nil
        }
        guard let card = maskedCard(in: line), let cardRange = line.range(of: card, options: .caseInsensitive),
              let labelRange = line.range(of: label, options: .caseInsensitive),
              cardRange.upperBound <= labelRange.lowerBound else {
            return nil
        }
        let holder = line[cardRange.upperBound..<labelRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Descriptor(label: label, holder: holder.isEmpty ? nil : holder, card: card)
    }

    private static func maskedCard(in line: String) -> String? {
        let candidates = line.split(whereSeparator: { $0 == "\t" || $0 == " " || $0 == "|" })
        for candidate in candidates {
            let normalized = candidate.uppercased().replacingOccurrences(of: "*", with: "X")
            if normalized.count >= 8, normalized.contains("X"), normalized.contains(where: \.isNumber),
               normalized.allSatisfy({ $0.isNumber || $0 == "X" }) { return normalized }
        }
        return nil
    }

    private static func subtotal(line: String) -> (amount: String, isCredit: Bool)? {
        let pattern = #"(?i)^(?:Total(?: of)?(?: [^0-9]+)?|[A-Z0-9]+-Total)\s+(CR\s+)?([0-9]+(?:,[0-9]{3})*\.[0-9]{2})$"#
        guard let values = captures(pattern, in: line), values.count == 2 else { return nil }
        return (values[1], !values[0].isEmpty)
    }

    private static func rowStart(_ line: String) -> (postingDate: String, purchaseDate: String, description: String)? {
        guard let values = captures(#"^(\d{2}/\d{2}/\d{2})\s+(\d{2}/\d{2}/\d{2})\s+(.+)$"#, in: line), values.count == 3 else { return nil }
        return (values[0], values[1], values[2])
    }

    private static func moneyTail(_ description: String) -> Tail? {
        let money = #"[0-9]+(?:,[0-9]{3})*\.[0-9]{2}"#
        if let values = captures(#"^(.+?)\s+(CR\s+)?([A-Z]{3})\s+(\#(money))\s+(CR\s+)?(\#(money))$"#, in: description), values.count == 6 {
            return Tail(
                description: values[0],
                original: values[3],
                originalCurrency: values[2],
                posted: values[5],
                isCredit: !values[1].isEmpty || !values[4].isEmpty
            )
        }
        if let values = captures(#"^(.+?)\s+(CR\s+)?(\#(money))$"#, in: description), values.count == 3 {
            return Tail(
                description: values[0],
                original: nil,
                originalCurrency: nil,
                posted: values[2],
                isCredit: !values[1].isEmpty
            )
        }
        return nil
    }

    private static func appendNarration(_ line: String, to row: NormalizedRow) throws -> NormalizedRow {
        guard row.values.count == logicalHeader.count else { throw CBQCreditCardPDFNormalizationError.malformedTransaction(sourceOrdinal: row.rowNumber) }
        var values = row.values
        values[2] += "\n" + line
        return NormalizedRow(rowNumber: row.rowNumber, values: values)
    }

    private static func isStructuralHeader(_ line: String) -> Bool {
        line == "Card Account Reference" || line == "Card Number Card Holder Name Product Card Limit" ||
        line == "Post Date Purchase Date" || line == "Date Description & Referance Foreign Currency Amount in QAR" ||
        line == "Post Date Purchase Date Description & Referance Foreign Currency Amount in QAR"
    }

    private static func isEndOfStatement(_ line: String) -> Bool {
        line.range(
            of: #"^(?:X+|\*+|<+|>+|-+|=+|\s+)*End of Statement(?:X+|\*+|<+|>+|-+|=+|\s+)*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func isPreambleLine(_ line: String) -> Bool {
        ["Statement Date", "Statement Period", "Payment Due Date", "Previous Outstanding Balance", "Amount Billed", "Payment Received", "Current Outstanding Balance", "Purchases", "Billed Installment", "Fees and Charges", "Total Payment", "Credit Reversal"].contains(line)
    }

    private static func looksFinancial(_ line: String) -> Bool {
        line.range(of: #"\d{2}/\d{2}/\d{2}.*[0-9]+(?:,[0-9]{3})*\.[0-9]{2}"#, options: .regularExpression) != nil
    }

    private struct PostTerminationSignature {
        let version: InternalVersion
        let tokenCount: Int
        let keywordPositions: [KeywordPosition]
        let numericPositions: [[Int]]
        let urlPositions: [Int]
    }

    private struct KeywordPosition: Equatable {
        let index: Int
        let categories: [String]
    }

    private static let postTerminationSignatures: [PostTerminationSignature] = [
        PostTerminationSignature(
            version: .v1,
            tokenCount: 255,
            keywordPositions: [
                .init(index: 3, categories: ["statement"]), .init(index: 5, categories: ["visit"]),
                .init(index: 6, categories: ["www"]), .init(index: 10, categories: ["card"]),
                .init(index: 15, categories: ["customer"]), .init(index: 30, categories: ["customer"]),
                .init(index: 194, categories: ["commercial"]), .init(index: 195, categories: ["bank"]),
                .init(index: 200, categories: ["card"]), .init(index: 201, categories: ["commercial"]),
                .init(index: 202, categories: ["bank"]), .init(index: 207, categories: ["card"])
            ],
            numericPositions: [
                [17, 32, 35, 77, 149, 150, 158, 159, 228, 230, 235, 237, 254],
                [17, 32, 75, 77, 149, 150, 158, 159, 228, 230, 235, 237, 254]
            ],
            urlPositions: [6]
        ),
        PostTerminationSignature(
            version: .v2,
            tokenCount: 624,
            keywordPositions: [
                .init(index: 3, categories: ["statement"]), .init(index: 5, categories: ["visit"]),
                .init(index: 6, categories: ["www"]), .init(index: 10, categories: ["card"]),
                .init(index: 15, categories: ["customer"]), .init(index: 30, categories: ["customer"]),
                .init(index: 78, categories: ["important"]), .init(index: 84, categories: ["card"]),
                .init(index: 85, categories: ["statement"]), .init(index: 137, categories: ["statement"]),
                .init(index: 140, categories: ["mobile"]), .init(index: 141, categories: ["bank"]),
                .init(index: 148, categories: ["card"]), .init(index: 154, categories: ["commercial"]),
                .init(index: 155, categories: ["bank"]), .init(index: 156, categories: ["reward"]),
                .init(index: 158, categories: ["please"]), .init(index: 163, categories: ["mobile"]),
                .init(index: 164, categories: ["bank"]), .init(index: 181, categories: ["statement"]),
                .init(index: 191, categories: ["statement"]), .init(index: 209, categories: ["statement"]),
                .init(index: 244, categories: ["statement"]), .init(index: 275, categories: ["statement"]),
                .init(index: 293, categories: ["app"]), .init(index: 321, categories: ["statement"]),
                .init(index: 329, categories: ["app"]), .init(index: 333, categories: ["card"]),
                .init(index: 358, categories: ["card", "www"]), .init(index: 366, categories: ["please"]),
                .init(index: 367, categories: ["visit"]), .init(index: 369, categories: ["website"]),
                .init(index: 374, categories: ["visit"]), .init(index: 375, categories: ["www"]),
                .init(index: 379, categories: ["card"]), .init(index: 384, categories: ["customer"]),
                .init(index: 399, categories: ["customer"]), .init(index: 563, categories: ["commercial"]),
                .init(index: 564, categories: ["bank"]), .init(index: 569, categories: ["card"]),
                .init(index: 570, categories: ["commercial"]), .init(index: 571, categories: ["bank"]),
                .init(index: 576, categories: ["card"])
            ],
            numericPositions: [[17, 32, 75, 77, 102, 115, 200, 238, 240, 291, 323, 386, 401, 444, 446, 518, 519, 527, 528, 597, 599, 604, 606, 623]],
            urlPositions: [6, 358, 375]
        ),
        PostTerminationSignature(
            version: .v2,
            tokenCount: 551,
            keywordPositions: [
                .init(index: 3, categories: ["statement"]), .init(index: 5, categories: ["important"]),
                .init(index: 11, categories: ["card"]), .init(index: 12, categories: ["statement"]),
                .init(index: 64, categories: ["statement"]), .init(index: 67, categories: ["mobile"]),
                .init(index: 68, categories: ["bank"]), .init(index: 75, categories: ["card"]),
                .init(index: 81, categories: ["commercial"]), .init(index: 82, categories: ["bank"]),
                .init(index: 83, categories: ["reward"]), .init(index: 85, categories: ["please"]),
                .init(index: 90, categories: ["mobile"]), .init(index: 91, categories: ["bank"]),
                .init(index: 108, categories: ["statement"]), .init(index: 118, categories: ["statement"]),
                .init(index: 136, categories: ["statement"]), .init(index: 171, categories: ["statement"]),
                .init(index: 202, categories: ["statement"]), .init(index: 220, categories: ["app"]),
                .init(index: 248, categories: ["statement"]), .init(index: 256, categories: ["app"]),
                .init(index: 260, categories: ["card"]), .init(index: 285, categories: ["card", "www"]),
                .init(index: 293, categories: ["please"]), .init(index: 294, categories: ["visit"]),
                .init(index: 296, categories: ["website"]), .init(index: 301, categories: ["visit"]),
                .init(index: 302, categories: ["www"]), .init(index: 306, categories: ["card"]),
                .init(index: 311, categories: ["customer"]), .init(index: 326, categories: ["customer"]),
                .init(index: 490, categories: ["commercial"]), .init(index: 491, categories: ["bank"]),
                .init(index: 496, categories: ["card"]), .init(index: 497, categories: ["commercial"]),
                .init(index: 498, categories: ["bank"]), .init(index: 503, categories: ["card"])
            ],
            numericPositions: [[29, 42, 127, 165, 167, 218, 250, 313, 328, 371, 373, 445, 446, 454, 455, 524, 526, 531, 533, 550]],
            urlPositions: [285, 302]
        )
    ]

    private static func matchesPostTerminationTail(_ lines: [String], version: InternalVersion) -> Bool {
        guard let marker = lines.firstIndex(where: isEndOfStatement), marker == 0 else { return false }
        let tail = lines.joined(separator: " ")
        let normalized = boundedWhitespace(tail)
        let tokens = normalized.split(separator: " ").map(String.init)
        guard !tokens.contains(where: { isEndOfStatement($0) }),
              !tokens.contains(where: { $0 == "Continued" || $0 == "next" }) else { return false }
        guard !lines.dropFirst().contains(where: hasFinancialEvidence) else { return false }
        let keywordPositions = tokens.enumerated().compactMap { index, token -> KeywordPosition? in
            let lower = token.lowercased()
            let categories = [
                "commercial", "bank", "customer", "card", "statement", "visit", "www", "reward",
                "important", "please", "website", "mobile", "app"
            ].filter { lower.contains($0) }
            return categories.isEmpty ? nil : KeywordPosition(index: index, categories: categories)
        }
        let numericPositions = tokens.enumerated().compactMap { index, token in
            token.range(of: #"\d"#, options: .regularExpression) == nil ? nil : index
        }
        let urlPositions = tokens.enumerated().compactMap { index, token in
            matches(#"(?i)\b(?:https?://|www\.)\S+"#, in: token).isEmpty ? nil : index
        }
        return postTerminationSignatures.contains { signature in
            signature.version == version &&
            signature.tokenCount == tokens.count &&
            signature.keywordPositions == keywordPositions &&
            signature.numericPositions.contains(numericPositions) &&
            signature.urlPositions == urlPositions
        }
    }

    private static func hasFinancialEvidence(_ line: String) -> Bool {
        if isEndOfStatement(line) { return true }
        if rowStart(line).flatMap({ moneyTail($0.description) }) != nil || looksFinancial(line) { return true }
        if sectionDescriptor(line: line) != nil || subtotal(line: line) != nil { return true }
        if isStructuralHeader(line) || line.contains("Card Account Reference") { return true }
        let compact = boundedWhitespace(line)
        return compact.contains("=") && compact.filter({ $0 == "+" }).count == 3 && compact.filter({ $0 == "-" }).count == 2
    }

    private static func requiredValue(labels: [String], in text: String, error: CBQCreditCardPDFNormalizationError) throws -> String {
        let alternatives = labels
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let matches = allCaptures(#"(?:"# + alternatives + #")\s*:?\s*(\S+)"#, in: boundedWhitespace(text))
        guard matches.count == 1, matches[0].count == 1, !matches[0][0].isEmpty else { throw error }
        return matches[0][0]
    }

    private static func requiredDate(labels: [String], in text: String, error: CBQCreditCardPDFNormalizationError) throws -> String {
        let alternatives = labels
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let bounded = boundedWhitespace(text)
        let short = allCaptures(#"(?:"# + alternatives + #")\s*[:\-]?\s*(\d{2}/\d{2}/\d{2})"#, in: bounded)
        let long = allCaptures(
            #"(?:"# + alternatives + #")\s*[:\-]?\s*(\d{1,2})\s+([A-Za-z]{3}),\s*(\d{4})"#,
            in: bounded
        )
        guard short.count + long.count == 1 else { throw error }
        if let value = short.first?.first { return value }
        guard let values = long.first, values.count == 3,
              let day = Int(values[0]), let year = Int(values[2]),
              let month = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
                .firstIndex(of: values[1].lowercased()) else { throw error }
        return String(format: "%02d/%02d/%02d", day, month + 1, year % 100)
    }

    private static func requiredPeriod(in text: String) throws -> (start: String, end: String) {
        let matches = allCaptures(#"(?:Statement Period)\s*[:\-]?\s*(\d{2}/\d{2}/\d{2})\s*(?:to|-)\s*(\d{2}/\d{2}/\d{2})"#, in: text)
        guard matches.count == 1, matches[0].count == 2 else {
            throw CBQCreditCardPDFNormalizationError.malformedPreamble
        }
        return (matches[0][0], matches[0][1])
    }

    private static func requiredMoneyToken(label: String, in text: String) throws -> String {
        guard allCaptures(NSRegularExpression.escapedPattern(for: label), in: text).count == 1 else {
            throw CBQCreditCardPDFNormalizationError.malformedSummary
        }
        let tokens = tokensAfter(label: label, in: text)
        for (index, token) in tokens.enumerated() {
            if token.uppercased() == "CR", index + 1 < tokens.count,
               isSummaryMoney(tokens[index + 1]) {
                return "CR " + tokens[index + 1]
            }
            if isSummaryMoney(token) { return token }
        }
        throw CBQCreditCardPDFNormalizationError.malformedSummary
    }

    private static func summaryFragments(version: InternalVersion, in text: String) throws -> [(String, String)] {
        let summarySource = text.components(separatedBy: "Diners Club").first ?? text
        switch version {
        case .v1:
            return [
                ("PREVIOUS_BALANCE", try requiredMoneyToken(label: "Previous Outstanding Balance", in: summarySource)),
                ("AMOUNT_BILLED", try requiredMoneyToken(label: "Amount Billed", in: summarySource)),
                ("PAYMENT_RECEIVED", try requiredMoneyToken(label: "Payment Received", in: summarySource)),
                ("NEW_BALANCE", try requiredMoneyToken(label: "Current Outstanding Balance", in: summarySource))
            ]
        case .v2:
            // PDFKit's native text order is the equation order:
            // total, purchases, billed installment, fees, previous, payment, credit.
            let equationValues: [String]
            if summarySource.contains("=") {
                equationValues = try summaryEquationValues(in: summarySource)
            } else {
                equationValues = [
                    try requiredMoneyToken(label: "Current Outstanding Balance", in: summarySource),
                    try requiredMoneyToken(label: "Purchases", in: summarySource),
                    try requiredMoneyToken(label: "Billed Installment", in: summarySource),
                    try requiredMoneyToken(label: "Fees and Charges", in: summarySource),
                    try requiredMoneyToken(label: "Previous Outstanding Balance", in: summarySource),
                    try requiredMoneyToken(label: "Total Payment", in: summarySource),
                    try requiredMoneyToken(label: "Credit Reversal", in: summarySource)
                ]
            }
            guard equationValues.count == 7 else { throw CBQCreditCardPDFNormalizationError.malformedSummary }
            return [
                ("PURCHASES", equationValues[1]),
                ("BILLED_INSTALLMENT", equationValues[2]),
                ("FEES_CHARGES", equationValues[3]),
                ("PREVIOUS_BALANCE", equationValues[4]),
                ("TOTAL_PAYMENT", equationValues[5]),
                ("CREDIT_REVERSAL", equationValues[6]),
                ("NEW_BALANCE", equationValues[0])
            ]
        }
    }

    private static func summaryEquationValues(in text: String) throws -> [String] {
        let candidates = text.components(separatedBy: .newlines).filter {
            $0.contains("=") && $0.filter { $0 == "+" }.count == 3 &&
                $0.filter { $0 == "-" }.count == 2
        }
        guard candidates.count == 1, let line = candidates.first else {
            throw CBQCreditCardPDFNormalizationError.malformedSummary
        }
        let money = #"[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?"#
        guard let expression = try? NSRegularExpression(pattern: #"\)?"# + money + #"\(?"#) else {
            throw CBQCreditCardPDFNormalizationError.malformedSummary
        }
        let range = NSRange(line.startIndex..., in: line)
        let matches = expression.matches(in: line, range: range)
        let values = matches.compactMap { match -> String? in
            guard let tokenRange = Range(match.range, in: line) else { return nil }
            let token = String(line[tokenRange])
            let opens = token.hasSuffix("(")
            let closes = token.hasPrefix(")")
            guard opens == closes else { return nil }
            return token
        }
        var skeleton = expression.stringByReplacingMatches(in: line, range: range, withTemplate: "#")
        skeleton = skeleton.filter { !$0.isWhitespace }
        guard skeleton == "#=#+#+#+#-#-#" else {
            throw CBQCreditCardPDFNormalizationError.malformedSummary
        }
        return values
    }

    private static func summaryMoneyTokens(in text: String) -> [String] {
        let tokens = boundedWhitespace(text).split(separator: " ").map(String.init)
        var result: [String] = []
        var index = 0
        while index < tokens.count {
            if tokens[index].uppercased() == "CR", index + 1 < tokens.count, isSummaryMoney(tokens[index + 1]) {
                result.append("CR " + tokens[index + 1])
                index += 2
                continue
            }
            if isSummaryMoney(tokens[index]) { result.append(tokens[index]) }
            index += 1
        }
        return result
    }

    private static func isSummaryMoney(_ value: String) -> Bool {
        captures(#"^[0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?$"#, in: value) != nil ||
            captures(#"^[)][0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?[(]$"#, in: value) != nil
    }

    private static func tokensAfter(label: String, in text: String) -> [String] {
        let bounded = boundedWhitespace(text)
        guard let range = bounded.range(of: label) else { return [] }
        return bounded[range.upperBound...].split(separator: " ").map(String.init)
    }

    private static func captures(_ pattern: String, in text: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        guard let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: text) else { return "" }
            return String(text[range])
        }
    }

    private static func matches(_ pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func allCaptures(_ pattern: String, in text: String) -> [[String]] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (1..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: text) else { return "" }
                return String(text[range])
            }
        }
    }

    private static func boundedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
