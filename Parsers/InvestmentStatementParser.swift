import Foundation

/// Families interpret current holdings from the existing immutable reader output.
/// This path never creates bank transactions from investment history.
struct InvestmentStatementParser {
    static let name = "Current holdings"

    func canRecognize(_ source: RawDocument) -> Bool {
        let text = source.searchableText.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if source.fileExtension == "csv" {
            return text.contains("FundName2") && text.contains("PolicyType") && text.contains("Units1")
                || text.contains("Open Positions,Header,") && text.contains("Interactive Brokers")
        }
        guard source.fileExtension == "pdf" else { return false }
        return text.contains("Interactive Brokers") && text.contains("Open Positions")
            || ((text.localizedCaseInsensitiveContains("Consolidated Account Statement")
                    || text.localizedCaseInsensitiveContains("Consolidated Account Summary"))
                && text.contains("ISIN") && text.localizedCaseInsensitiveContains("Folio"))
            || text.localizedCaseInsensitiveContains("Client Investment Statement") && text.contains("CIF")
            || text.localizedCaseInsensitiveContains("Investment Portfolio Holding Statement") && text.contains("Unit Holder")
    }

    func parse(_ source: RawDocument) throws -> FinancialDocument {
        guard canRecognize(source) else { throw InvestmentError.unsupportedSource }
        let text = source.searchableText.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let evidence: InvestmentStatementEvidence
        if source.fileExtension == "csv", text.contains("FundName2") {
            evidence = try ZurichClosingHoldingsParser().parse(source)
        } else if source.fileExtension == "csv" {
            evidence = try IBKRCurrentHoldingsParser().parseCSV(source)
        } else if text.contains("Interactive Brokers") {
            evidence = try IBKRCurrentHoldingsParser().parsePDF(source)
        } else if text.localizedCaseInsensitiveContains("Consolidated Account Statement")
                    || text.localizedCaseInsensitiveContains("Consolidated Account Summary") {
            evidence = try CASCurrentHoldingsParser().parse(source)
        } else if text.localizedCaseInsensitiveContains("Investment Portfolio Holding Statement") {
            evidence = try CBQLegacyPortfolioHoldingsParser().parse(source)
        } else {
            evidence = try CBQCurrentHoldingsParser().parse(source)
        }
        try evidence.validate()
        var document = Document(filename: source.fileName, url: source.sourceURL, fileType: source.fileExtension.uppercased(), importedAt: source.extractedAt)
        document.rowCount = evidence.scopes.reduce(0) { $0 + $1.positions.count }
        document.parserVersion = "1"
        document.confidence = 1.0
        return FinancialDocument(sourceDocument: document,
            metadata: .init(institution: .unknown, documentType: .investment,
                fileFormat: source.fileExtension == "csv" ? .csv : .pdf, confidence: 1.0),
            parserName: Self.name, parserProfileID: evidence.parserProfile, parserProfileVersion: "1",
            transactions: [], investmentStatementEvidence: evidence,
            selectionReasons: ["Current closing holdings; other statement activity is outside this projection."])
    }
}

/// CSV quoting is structural syntax. Financial column meaning remains family-owned.
enum InvestmentSourceText {
    static func csv(_ text: String) throws -> [[String]] {
        let text = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let chars = Array(text)
        var rows: [[String]] = [], row: [String] = [], cell = ""
        var quoted = false, closed = false, index = 0
        while index < chars.count {
            let char = chars[index]
            if quoted {
                if char == "\"" {
                    if index + 1 < chars.count && chars[index + 1] == "\"" { cell.append("\""); index += 1 }
                    else { quoted = false; closed = true }
                } else { cell.append(char) }
            } else if char == "," {
                row.append(cell); cell = ""; closed = false
            } else if char == "\n" || char == "\r" || char == "\r\n" {
                row.append(cell)
                if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { rows.append(row) }
                row = []; cell = ""; closed = false
                if char == "\r", index + 1 < chars.count, chars[index + 1] == "\n" { index += 1 }
            } else if char == "\"" && cell.isEmpty && !closed {
                quoted = true
            } else {
                guard !closed, char != "\"" else { throw InvestmentError.invalidEvidence }
                cell.append(char)
            }
            index += 1
        }
        guard !quoted else { throw InvestmentError.invalidEvidence }
        row.append(cell)
        if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { rows.append(row) }
        return rows
    }

    static func captures(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (1..<match.numberOfRanges).map { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
            }
        }
    }

    static func one(_ pattern: String, in text: String) throws -> String {
        let values = Set(captures(pattern, in: text).compactMap(\.first))
        guard values.count == 1, let value = values.first else { throw InvestmentError.missingSourceField(pattern) }
        return value
    }

    static func date(_ text: String) throws -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = try? StatementDate(canonical: clean) { return date.canonical }
        let formats = ["d MMM yyyy", "d MMMM yyyy", "MMMM d, yyyy", "MMM d, yyyy", "dd/MM/yyyy", "dd-MMM-yyyy", "dd-MM-yyyy"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.isLenient = false
            formatter.dateFormat = format
            if let date = formatter.date(from: clean) {
                let parts = formatter.calendar.dateComponents(in: formatter.timeZone, from: date)
                if let year = parts.year, let month = parts.month, let day = parts.day {
                    return try StatementDate(year: year, month: month, day: day).canonical
                }
            }
        }
        throw InvestmentError.invalidEvidence
    }

    static func sum(_ values: [InvestmentDecimal]) throws -> Decimal {
        var total = Decimal.zero
        for number in values {
            var value = number.value, next = Decimal()
            guard NSDecimalAdd(&next, &total, &value, .plain) == .noError else { throw InvestmentError.invalidNumber }
            total = next
        }
        return total
    }
}

struct ZurichClosingHoldingsParser {
    func parse(_ source: RawDocument) throws -> InvestmentStatementEvidence {
        let rows = try InvestmentSourceText.csv(source.searchableText)
        guard let header = rows.first, Set(header).count == header.count,
              ["PolicyType", "Textbox42", "SchemeNumber", "TransactionGroupDescription2", "FundName2", "Units1", "Textbox3464"].allSatisfy(header.contains),
              rows.dropFirst().allSatisfy({ $0.count == header.count }) else { throw InvestmentError.invalidEvidence }
        let data = rows.dropFirst().map { Dictionary(uniqueKeysWithValues: zip(header, $0)) }
        func unique(_ field: String) throws -> String {
            let values = Set(data.compactMap { $0[field] }.filter { !$0.isEmpty })
            guard values.count == 1, let value = values.first else { throw InvestmentError.invalidEvidence }
            return value
        }
        guard try unique("SchemeName") == "Qatar Airways International Savings Plan" else { throw InvestmentError.unsupportedSource }
        let policy = try unique("Textbox42"), type = try unique("PolicyType")
        let scheme = try unique("SchemeNumber")
        let currency = try unique("ReportingCurrency")
        guard !policy.isEmpty, !scheme.isEmpty else { throw InvestmentError.invalidEvidence }
        let label: String
        switch type {
        case "EMPLOYEE": label = "Employee mandatory"
        case "EMPLOYEE A": label = "Employee AVC"
        case "EMPLOYER": label = "Employer"
        default: throw InvestmentError.identityChoiceRequired
        }
        let title = try unique("Textbox10")
        let end = try InvestmentSourceText.one(#"^Statement\s*-\s*.+\s+to\s+(.+)$"#, in: title)
        let holdingsDate = try InvestmentSourceText.date(end)
        guard let first = data.firstIndex(where: { $0["TransactionGroupDescription2"] == "Closing balance" }) else {
            throw InvestmentError.invalidEvidence
        }
        let closing = Array(data[first...])
        guard !closing.isEmpty, closing.allSatisfy({ $0["TransactionGroupDescription2"] == "Closing balance" && $0["TransactionDescription"] == "Closing balance" }) else {
            throw InvestmentError.invalidEvidence
        }
        var values: [InvestmentDecimal] = [], controls: [InvestmentDecimal] = [], positions: [InvestmentPositionEvidence] = []
        for (offset, row) in closing.enumerated() {
            func field(_ key: String) throws -> String {
                guard let value = row[key], !value.isEmpty else { throw InvestmentError.invalidEvidence }
                return value
            }
            guard try InvestmentSourceText.date(field("TransactionDate3")) == holdingsDate,
                  try field("ValuationCurrency1") == currency, try field("ValuationCurrency3") == currency,
                  try field("ValuationCurrency6") == currency, try field("Textbox342") == "Total closing balance" else {
                throw InvestmentError.invalidEvidence
            }
            let units = try InvestmentDecimal(field("Units1"))
            let value = try InvestmentDecimal(field("Valuation1"))
            let control = try InvestmentDecimal(field("Textbox3464"))
            guard try InvestmentDecimal(field("Textbox3467")).value == control.value,
                  try InvestmentDecimal(field("UnitPrice1")).value >= 0,
                  try InvestmentDecimal(field("ExchangeRate1")).value > 0,
                  units.value != 0 || value.value == 0 else { throw InvestmentError.invalidEvidence }
            values.append(value); controls.append(control)
            let name = try field("FundName2"), fundCurrency = try field("FundCurrency1")
            positions.append(.init(instrumentIdentity: "zurich-fund-name:" + name, sourceAliases: [name],
                displayName: name, units: units, currency: fundCurrency, averageCost: nil, totalCost: nil,
                averageCostLabel: nil, totalCostLabel: nil, costCurrency: nil,
                sourceOrdinal: first + offset + 2, valuationDate: try InvestmentSourceText.date(field("Textbox9"))))
        }
        guard let total = controls.first, controls.allSatisfy({ $0.value == total.value }),
              try InvestmentSourceText.sum(values) == total.value else { throw InvestmentError.invalidEvidence }
        let scope = InvestmentScopeEvidence(institution: "Zurich ISP", identityKind: "policy", identity: policy,
            aliases: [policy], displayName: "ISP · " + label, holdingsDate: holdingsDate,
            isComplete: true, positions: positions)
        return InvestmentStatementEvidence(parserProfile: "zurich.isp.closing.csv", issueDate: nil, scopes: [scope],
            excludedSectionDescription: "Transactions, switches and contributions are outside current holdings. Policy totals are controls.")
    }
}
