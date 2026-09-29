import Foundation
import CoreGraphics

nonisolated enum BankRelationshipPDFError: Error, Equatable, LocalizedError {
    case unsupportedSource, incompleteSection, ambiguousIdentity, missingCurrency, changedTable
    case malformedOccurrence(Int)
    case sourceBoundary(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSource: return "The relationship statement does not match a qualified bank layout."
        case .incompleteSection: return "An account section of the original is incomplete."
        case .ambiguousIdentity: return "An account section has missing or contradictory identity evidence."
        case .missingCurrency: return "An account section has no source-proven native currency."
        case .changedTable: return "A bank transaction table cannot be assigned to its printed columns."
        case .malformedOccurrence(let ordinal): return "The bank occurrence at source position \(ordinal) is incomplete or ambiguous."
        case .sourceBoundary: return "An account section of the original could not be completely identified."
        }
    }
}

nonisolated enum BankRelationshipFamily: String, Sendable {
    case axis, hdfc
    var institution: Institution { self == .axis ? .axis : .hdfc }
    var profileID: String { rawValue + ".relationship-bank.pdf" }
    var parserName: String { self == .axis ? "Axis Relationship Bank PDF" : "HDFC Relationship Bank PDF" }
}

nonisolated struct BankRelationshipPDFNormalizationResult {
    let document: Document
    let rows: [NormalizedRow]
    let header: NormalizedRow
    let sourceContext: NormalizedDocument.SourceContext
}

/// The original remains one document. Drawn column edges and explicit account
/// headings determine section and occurrence ownership; summary arithmetic
/// never changes a printed transaction or its literal balance.
nonisolated final class BankRelationshipPDFNormalizer {
    static let logicalHeader = ["Transaction Date", "Narration", "Value Date", "Reference", "Withdrawal", "Deposit", "Balance"]
    static let moneyPattern = #"-?(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3})\.[0-9]{2}"#

    private struct Line {
        let ordinal: Int
        let page: Int
        let words: [RawPDFTextFragment]
        var y: Double { words.map(\.y).reduce(0, +) / Double(words.count) }
        var text: String { words.map(\.text).joined(separator: " ") }
        var compact: String { text.filter { !$0.isWhitespace }.lowercased() }
    }

    private struct Page {
        let number: Int
        let evidence: RawPDFPageEvidence
        let lines: [Line]
    }

    private struct Row {
        let ordinal: Int
        let page: Int
        let date: String
        var narration: [String]
        var reference: [String]
        let debit: String
        let credit: String
        let balance: String
    }

    private final class Section {
        let account: String
        let start: String
        let end: String
        let firstOrdinal: Int
        let firstPage: Int
        var lastOrdinal: Int
        var lastPage: Int
        var product = ""
        var currency = ""
        var rows: [Row] = []
        var controls: [NormalizedBankSectionControl] = []
        var closed = false

        init(account: String, start: String, end: String, line: Line) {
            self.account = account; self.start = start; self.end = end
            firstOrdinal = line.ordinal; firstPage = line.page
            lastOrdinal = line.ordinal; lastPage = line.page
        }

        func observe(_ kind: BankSectionControlKind, label: String, literal: String, line: Line) {
            controls.append(.init(kind: kind, label: label, literal: literal,
                                  sourceOrdinal: line.ordinal, sourcePage: line.page))
            lastOrdinal = line.ordinal; lastPage = line.page
        }
    }

    static func recognizes(_ text: String, family: BankRelationshipFamily) -> Bool {
        let text = text.filter { !$0.isWhitespace }.lowercased()
        switch family {
        case .axis:
            return text.contains("relationshipstatementfortheperiodfrom:") &&
                text.contains("relationshipsummary") && text.contains("statementforaccountno.")
        case .hdfc:
            return text.contains("accountrelationshipsummary") && text.contains("accountnumber") &&
                text.contains("accounttype") && text.contains("statementfrom")
        }
    }

    func normalize(text: String, pageEvidence: [RawPDFPageEvidence]?, fileURL: URL,
                   family: BankRelationshipFamily) throws -> BankRelationshipPDFNormalizationResult {
        guard Self.recognizes(text, family: family), let pageEvidence, !pageEvidence.isEmpty else {
            throw BankRelationshipPDFError.unsupportedSource
        }
        let pages = try positionedPages(pageEvidence)
        let sections = try family == .axis ? axisSections(pages) : hdfcSections(pages)
        guard !sections.isEmpty else { throw BankRelationshipPDFError.incompleteSection }
        let normalizedSections = try sections.enumerated().map { offset, section in
            guard !section.product.isEmpty, section.currency == "INR", section.closed else {
                throw BankRelationshipPDFError.sourceBoundary("section-product-currency-close")
            }
            let rows = try section.rows.map { row -> NormalizedRow in
                let narration = row.narration.joined(separator: " ")
                guard !narration.isEmpty else { throw BankRelationshipPDFError.malformedOccurrence(row.ordinal) }
                let valueDate: String
                let reference: String
                if family == .hdfc {
                    let dates = Self.captures(#"Value\s*Dt\s*([0-9]{2}/[0-9]{2}/[0-9]{4})"#, in: narration)
                    guard dates.count == 1 else { throw BankRelationshipPDFError.malformedOccurrence(row.ordinal) }
                    valueDate = dates[0][0]
                    let references = Self.captures(#"\bRef\s+(.+)$"#, in: narration)
                    guard references.count <= 1 else { throw BankRelationshipPDFError.malformedOccurrence(row.ordinal) }
                    reference = references.first?.first ?? ""
                } else {
                    valueDate = ""; reference = row.reference.joined(separator: " ")
                }
                let values = [row.date, narration, valueDate, reference, row.debit, row.credit, row.balance]
                return NormalizedRow(rowNumber: row.ordinal, values: values, rawValues: values, sourcePage: row.page)
            }
            let records = [section.account, section.product, section.currency, section.start, section.end] +
                rows.map { $0.values.joined(separator: "\t") } +
                section.controls.map { "\($0.kind.rawValue)\t\($0.literal)\t\($0.sourceOrdinal)" }
            return try NormalizedBankAccountSection(id: "bank-section-\(offset + 1)", ordinal: offset + 1,
                accountLiteral: section.account, productLiteral: section.product, currencyLiteral: section.currency,
                periodStartLiteral: section.start, periodEndLiteral: section.end,
                firstSourceOrdinal: section.firstOrdinal, lastSourceOrdinal: section.lastOrdinal,
                firstPage: section.firstPage, lastPage: section.lastPage, rows: rows, controls: section.controls,
                exhaustedRegion: .init(descriptor: family.profileID + ".account-section.positioned-lines.v1", sourceUnit: .line,
                    startOrdinal: section.firstOrdinal, endOrdinal: section.lastOrdinal,
                    recognizedFinancialRowCount: rows.count, sourceRecords: records))
        }
        let rows = normalizedSections.flatMap(\.rows)
        guard Set(rows.map(\.rowNumber)).count == rows.count,
              rows.map(\.rowNumber) == rows.map(\.rowNumber).sorted() else { throw BankRelationshipPDFError.incompleteSection }
        var document = Document(filename: fileURL.lastPathComponent, url: fileURL, fileType: FileFormat.pdf.rawValue, importedAt: Date())
        document.rowCount = pages.reduce(0) { $0 + $1.lines.count }
        document.headerRow = normalizedSections[0].firstSourceOrdinal
        document.firstTransactionRow = rows.first?.rowNumber
        document.columnCount = Self.logicalHeader.count
        document.encoding = "UTF-8"
        return .init(document: document, rows: rows,
            header: NormalizedRow(rowNumber: document.headerRow ?? 1, values: Self.logicalHeader),
            sourceContext: .init(preTransactionFragments: [], bankAccountSections: normalizedSections))
    }

    private func positionedPages(_ evidence: [RawPDFPageEvidence]) throws -> [Page] {
        var ordinal = 0
        return try evidence.enumerated().map { offset, page in
            guard page.fragments.allSatisfy({ $0.geometry?.isCanonical == true && $0.bounds != nil }) else {
                throw BankRelationshipPDFError.unsupportedSource
            }
            let ordered = page.fragments.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y > $1.y }
            var groups: [[RawPDFTextFragment]] = []
            for word in ordered {
                if let first = groups.last?.first, abs(first.y - word.y) < 2 {
                    groups[groups.count - 1].append(word)
                } else { groups.append([word]) }
            }
            let lines = groups.map { words -> Line in
                ordinal += 1
                return Line(ordinal: ordinal, page: offset + 1, words: words.sorted { $0.x < $1.x })
            }
            return Page(number: offset + 1, evidence: page, lines: lines)
        }
    }

    private func columns(_ line: Line, page: Page, roles: [String]) throws -> [Double] {
        guard let drawings = page.evidence.drawings else { throw BankRelationshipPDFError.changedTable }
        let centers = try roles.map { role -> Double in
            guard let geometry = line.words.first(where: { $0.text.lowercased().hasPrefix(role) })?.geometry else {
                throw BankRelationshipPDFError.changedTable
            }
            return (geometry.minX + geometry.maxX) / 2
        }
        let positions = drawings.segments.filter {
            abs($0.start.x - $0.end.x) < 0.5 && min($0.start.y, $0.end.y) <= line.y &&
                max($0.start.y, $0.end.y) >= line.y
        }.map { Double($0.start.x) }.sorted()
        var groups: [[Double]] = []
        for position in positions {
            if let last = groups.last?.last, position - last <= 1.5 { groups[groups.count - 1].append(position) }
            else { groups.append([position]) }
        }
        let edges = groups.map { $0.reduce(0, +) / Double($0.count) }
        let slots = centers.compactMap { center in
            edges.indices.dropLast().first { edges[$0] < center && center < edges[$0 + 1] }
        }
        guard slots.count == roles.count, let first = slots.first,
              slots == Array(first..<(first + roles.count)) else { throw BankRelationshipPDFError.changedTable }
        return Array(edges[first...(first + roles.count)])
    }

    private func cells(_ line: Line, edges: [Double]) -> [[RawPDFTextFragment]] {
        edges.indices.dropLast().map { index in
            line.words.filter { word in
                guard let bounds = word.bounds else { return false }
                return edges[index] < bounds.midX && bounds.midX < edges[index + 1]
            }
        }
    }

    private func axisSections(_ pages: [Page]) throws -> [Section] {
        var sections: [Section] = [], active: Section?
        var retainedEdges: [Double]?
        var currencies: [String: Set<String>] = [:]
        for page in pages {
            var edges: [Double]?
            for line in page.lines {
                // The bank-account summary owns a branch IFSC and currency.
                // Term-deposit summaries can also print a 15-position mask
                // and INR, but are explicitly outside the selected scope.
                if Self.matches(#"\bINR\b"#, line.text), Self.matches(#"\bUTIB[0-9]{7}\b"#, line.text) {
                    for mask in Self.captures(#"\b([0-9X]{15})\b"#, in: line.text).compactMap(\.first) where mask.contains("X") {
                        currencies[mask, default: []].insert("INR")
                    }
                }
                let headings = Self.captures(#"Statement\s*for\s*Account\s*No\.\s*([0-9X]{15})\s*for\s*the\s*period\s*from\s*([0-9]{2}-[0-9]{2}-[0-9]{4})\s*to\s*([0-9]{2}-[0-9]{2}-[0-9]{4})"#, in: line.text)
                if let heading = headings.first {
                    guard headings.count == 1, heading[0].contains("X") else { throw BankRelationshipPDFError.ambiguousIdentity }
                    if let active {
                        guard active.account == heading[0], active.start == heading[1], active.end == heading[2] else {
                            throw BankRelationshipPDFError.incompleteSection
                        }
                    } else {
                        let section = Section(account: heading[0], start: heading[1], end: heading[2], line: line)
                        sections.append(section); active = section
                    }
                    edges = nil
                    continue
                }
                guard let section = active else { continue }
                if let product = Self.captures(#"Scheme\s*Name\s*:\s*(.+?)(?:\s*Joint\s*Holder\s*:|$)"#, in: line.text).first?.first {
                    let product = product.trimmingCharacters(in: .whitespaces)
                    guard section.product.isEmpty || Self.compact(section.product) == Self.compact(product) else {
                        throw BankRelationshipPDFError.ambiguousIdentity
                    }
                    section.product = product; continue
                }
                if line.compact.contains("withdrawal"), line.compact.contains("deposits"),
                   line.compact.contains("transaction"), line.compact.contains("date") {
                    edges = try columns(line, page: page, roles: ["date", "transaction", "chq", "withdrawal", "deposits", "balance"])
                    retainedEdges = edges; continue
                }
                // Three authentic continuation pages contain only Closing
                // Balance/Total before the next section and repeat no header.
                if edges == nil, line.compact.hasPrefix("closingbalance") { edges = retainedEdges }
                guard let edges else { continue }
                let columns = cells(line, edges: edges)
                if line.compact.hasPrefix("openingbalance") || line.compact.hasPrefix("closingbalance") {
                    let values = columns[5].map(\.text).filter { Self.matches("^" + Self.moneyPattern + "$", $0) }
                    guard values.count == 1 else { throw BankRelationshipPDFError.sourceBoundary("axis-opening-closing-cell") }
                    let kind: BankSectionControlKind = line.compact.hasPrefix("opening") ? .openingBalance : .closingBalance
                    section.observe(kind, label: kind == .openingBalance ? "Opening Balance" : "Closing Balance", literal: values[0], line: line)
                    if kind == .closingBalance { section.closed = true }
                    continue
                }
                if line.compact.hasPrefix("total"), section.closed {
                    for (column, kind) in [(3, BankSectionControlKind.debitTotal), (4, .creditTotal)] {
                        let values = columns[column].map(\.text).filter { Self.matches("^" + Self.moneyPattern + "$", $0) }
                        guard values.count == 1 else { throw BankRelationshipPDFError.sourceBoundary("axis-total-cell") }
                        section.observe(kind, label: "Total", literal: values[0], line: line)
                    }
                    active = nil; retainedEdges = nil; continue
                }
                guard !section.closed else { continue }
                if Self.matches(#"^Page\s+[0-9]+\s+of\s+[0-9]+$"#, line.text) { continue }
                let dates = columns[0].map(\.text).filter { Self.matches(#"^[0-9]{2}-[0-9]{2}-[0-9]{4}$"#, $0) }
                let amounts = columns[3...5].map { $0.map(\.text).filter { Self.matches("^" + Self.moneyPattern + "$", $0) } }
                if !dates.isEmpty {
                    guard dates.count == 1, amounts[0].count <= 1, amounts[1].count <= 1, amounts[2].count == 1 else {
                        throw BankRelationshipPDFError.malformedOccurrence(line.ordinal)
                    }
                    section.rows.append(.init(ordinal: line.ordinal, page: line.page, date: dates[0], narration: [], reference: [],
                        debit: amounts[0].first ?? "", credit: amounts[1].first ?? "", balance: amounts[2][0]))
                } else if amounts.contains(where: { !$0.isEmpty }) {
                    throw BankRelationshipPDFError.malformedOccurrence(line.ordinal)
                }
                if !section.rows.isEmpty {
                    let index = section.rows.count - 1
                    if !columns[1].isEmpty { section.rows[index].narration.append(columns[1].map(\.text).joined(separator: " ")) }
                    if !columns[2].isEmpty { section.rows[index].reference.append(columns[2].map(\.text).joined(separator: " ")) }
                    section.lastOrdinal = line.ordinal; section.lastPage = line.page
                }
            }
        }
        guard active == nil else { throw BankRelationshipPDFError.sourceBoundary("axis-unclosed-account") }
        guard Set(sections.map(\.account)) == Set(currencies.keys) else {
            let missing = Set(sections.map(\.account)).subtracting(currencies.keys).count
            let extra = Set(currencies.keys).subtracting(sections.map(\.account)).count
            throw BankRelationshipPDFError.sourceBoundary("axis-summary-account-set sections=\(sections.count) summary=\(currencies.count) missing=\(missing) extra=\(extra)")
        }
        for section in sections {
            guard currencies[section.account] == Set(["INR"]) else { throw BankRelationshipPDFError.missingCurrency }
            section.currency = "INR"
        }
        return sections
    }

    private func hdfcSections(_ pages: [Page]) throws -> [Section] {
        var sections: [Section] = []
        for page in pages {
            let text = page.lines.map(\.text).joined(separator: "\n")
            guard let identity = Self.captures(#"Account\s*Number\s*:\s*([0-9]{14})\b"#, in: text).first?.first else {
                guard page.number == 1, Self.compact(text).contains("accountrelationshipsummary") else {
                    throw BankRelationshipPDFError.incompleteSection
                }
                continue
            }
            guard let bounds = page.evidence.bounds else { throw BankRelationshipPDFError.unsupportedSource }
            let leftText = page.lines.map { $0.words.filter { $0.x < bounds.midX }.map(\.text).joined(separator: " ") }.joined(separator: "\n")
            guard let product = Self.captures(#"Account\s*Type\s*:\s*([^\r\n]+)"#, in: leftText).first?.first,
                  let period = Self.captures(#"Statement\s*From\s*:\s*([0-9]{2}/[0-9]{2}/[0-9]{4})\s*To\s*([0-9]{2}/[0-9]{2}/[0-9]{4})"#, in: leftText).first,
                  let currency = Self.captures(#"Currency\s*:\s*([A-Z]{3})"#, in: leftText).first?.first,
                  let identityLine = page.lines.first(where: { $0.compact.contains("accountnumber:") }),
                  let openingLine = page.lines.first(where: { $0.compact.hasPrefix("openingbalance:") }),
                  let opening = Self.captures("Opening\\s*Balance\\s*:\\s*(" + Self.moneyPattern + ")", in: openingLine.text).first?.first else {
                throw BankRelationshipPDFError.incompleteSection
            }
            let section: Section
            if let prior = sections.last, prior.account == identity {
                guard prior.start == period[0], prior.end == period[1], Self.compact(prior.product) == Self.compact(product),
                      prior.currency == currency,
                      prior.controls.first(where: { $0.kind == .openingBalance })?.literal == opening else {
                    throw BankRelationshipPDFError.ambiguousIdentity
                }
                section = prior
            } else {
                guard !sections.contains(where: { $0.account == identity }) else { throw BankRelationshipPDFError.ambiguousIdentity }
                section = Section(account: identity, start: period[0], end: period[1], line: identityLine)
                section.product = product.trimmingCharacters(in: .whitespaces); section.currency = currency
                sections.append(section)
            }
            section.observe(.openingBalance, label: "Opening Balance", literal: opening, line: openingLine)
            let headers = page.lines.filter { $0.compact == "txndatenarrationwithdrawalsdepositsclosingbalance" }
            guard headers.count <= 1 else { throw BankRelationshipPDFError.changedTable }
            let summary = page.lines.firstIndex { $0.compact == "openingbalancedebitamountcreditamountclosingbalance" }
            if let summary, page.lines.indices.contains(summary + 3) {
                let valuesLine = page.lines[summary + 1]
                let values = valuesLine.words.map(\.text).filter { Self.matches("^" + Self.moneyPattern + "$", $0) }
                if values.count == 4 {
                    for (kind, value) in zip([BankSectionControlKind.openingBalance, .debitTotal, .creditTotal, .closingBalance], values) {
                        section.observe(kind, label: kind.rawValue, literal: value, line: valuesLine)
                    }
                }
                if page.lines[summary + 2].compact == "debitcountcreditcount" {
                    let countsLine = page.lines[summary + 3]
                    let counts = countsLine.words.map(\.text).filter { Self.matches(#"^[0-9]+$"#, $0) }
                    if counts.count == 2 {
                        section.observe(.debitCount, label: "Debit Count", literal: counts[0], line: countsLine)
                        section.observe(.creditCount, label: "Credit Count", literal: counts[1], line: countsLine)
                    }
                }
            }
            for line in page.lines where line.compact.hasPrefix("totalwithdrawalbalance") {
                if let value = Self.captures(":\\s*(" + Self.moneyPattern + ")", in: line.text).first?.first {
                    section.observe(.withdrawableBalance, label: "Total Withdrawal Balance", literal: value, line: line)
                }
            }
            guard let header = headers.first else {
                guard section.rows.isEmpty,
                      section.controls.last(where: { $0.kind == .debitCount })?.literal == "0",
                      section.controls.last(where: { $0.kind == .creditCount })?.literal == "0" else {
                    throw BankRelationshipPDFError.incompleteSection
                }
                section.closed = true; continue
            }
            let edges = try columns(header, page: page, roles: ["txn", "narration", "withdrawals", "deposits", "closing"])
            let containers = page.evidence.drawings?.rectangles.filter {
                abs($0.minX - edges[0]) < 2 && abs($0.maxX - edges[5]) < 2 && $0.minY < header.y && header.y < $0.maxY
            } ?? []
            guard let floor = containers.map(\.minY).min() else { throw BankRelationshipPDFError.changedTable }
            for line in page.lines where line.y < header.y - 2 && line.y > floor {
                let columns = cells(line, edges: edges)
                let dates = columns[0].map(\.text).filter { Self.matches(#"^[0-9]{2}/[0-9]{2}/[0-9]{4}$"#, $0) }
                let amounts = columns[2...4].map { $0.map(\.text).filter { Self.matches("^" + Self.moneyPattern + "$", $0) } }
                if !dates.isEmpty {
                    guard dates.count == 1, amounts.allSatisfy({ $0.count == 1 }) else {
                        throw BankRelationshipPDFError.malformedOccurrence(line.ordinal)
                    }
                    section.rows.append(.init(ordinal: line.ordinal, page: line.page, date: dates[0], narration: [], reference: [],
                        debit: amounts[0][0], credit: amounts[1][0], balance: amounts[2][0]))
                } else if !columns[0].isEmpty || amounts.contains(where: { !$0.isEmpty }) {
                    throw BankRelationshipPDFError.malformedOccurrence(line.ordinal)
                }
                if !columns[1].isEmpty {
                    guard !section.rows.isEmpty else { throw BankRelationshipPDFError.malformedOccurrence(line.ordinal) }
                    section.rows[section.rows.count - 1].narration.append(columns[1].map(\.text).joined(separator: " "))
                }
                section.lastOrdinal = max(section.lastOrdinal, line.ordinal); section.lastPage = line.page
            }
            section.closed = true
        }
        guard sections.count == 2, Set(sections.map(\.account)).count == 2 else {
            throw BankRelationshipPDFError.incompleteSection
        }
        return sections
    }

    private static func compact(_ value: String) -> String { value.filter { !$0.isWhitespace }.lowercased() }
    private static func matches(_ pattern: String, _ value: String) -> Bool {
        value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    private static func captures(_ pattern: String, in text: String) -> [[String]] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return expression.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (1..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : ns.substring(with: match.range(at: $0)) }
        }
    }
}
