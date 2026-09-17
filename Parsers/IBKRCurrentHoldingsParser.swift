import Foundation

struct IBKRCurrentHoldingsParser {
    private struct Instrument {
        let identity: String
        let name: String
        let aliases: [String]
    }

    func parseCSV(_ source: RawDocument) throws -> InvestmentStatementEvidence {
        let rows = try InvestmentSourceText.csv(source.searchableText)
        func metadata(_ section: String, _ name: String) throws -> String {
            let matches = rows.filter { $0.count == 4 && $0[0] == section && $0[1] == "Data" && $0[2] == name }
            guard matches.count == 1 else { throw InvestmentError.invalidEvidence }
            return matches[0][3]
        }
        guard try metadata("Statement", "BrokerName").hasPrefix("Interactive Brokers"),
              try metadata("Statement", "Title") == "Activity Statement" else { throw InvestmentError.unsupportedSource }
        let account = try metadata("Account Information", "Account")
        let period = try metadata("Statement", "Period")
        let end = try InvestmentSourceText.one(#"^.+ - (.+)$"#, in: period)
        let date = try InvestmentSourceText.date(end)
        let generated = try metadata("Statement", "WhenGenerated")
        let issueDate = try InvestmentSourceText.date(String(generated.prefix(10)))
        func table(_ name: String) throws -> [(ordinal: Int, values: [String: String])] {
            let headers = rows.filter { $0.count > 2 && $0[0] == name && $0[1] == "Header" }
            guard headers.count == 1, let header = headers.first, Set(header.dropFirst(2)).count == header.count - 2 else {
                throw InvestmentError.invalidEvidence
            }
            return try rows.enumerated().filter { $0.element.first == name && $0.element[safe: 1] != "Header" }.map { index, row in
                guard row.count == header.count else { throw InvestmentError.invalidEvidence }
                var values = Dictionary(uniqueKeysWithValues: zip(header.dropFirst(2), row.dropFirst(2)))
                values["row-kind"] = row[1]
                return (index + 1, values)
            }
        }
        var instruments: [String: Instrument] = [:]
        for (_, row) in try table("Financial Instrument Information") {
            guard row["row-kind"] == "Data", row["Asset Category"] == "Stocks",
                  let symbol = row["Symbol"], let conid = row["Conid"], !conid.isEmpty,
                  let name = row["Description"], !name.isEmpty, row["Multiplier"] == "1",
                  let security = row["Security ID"], !security.isEmpty, instruments[symbol] == nil else {
                throw InvestmentError.invalidEvidence
            }
            instruments[symbol] = .init(identity: "ibkr-conid:" + conid, name: name,
                aliases: ["isin:" + security, "symbol:" + symbol])
        }
        var positions: [InvestmentPositionEvidence] = [], costsByCurrency: [String: [InvestmentDecimal]] = [:]
        var controls: [String: InvestmentDecimal] = [:]
        for (ordinal, row) in try table("Open Positions") {
            guard row["Asset Category"] == "Stocks", let currency = row["Currency"] else { throw InvestmentError.invalidEvidence }
            if row["row-kind"] == "Total" {
                guard controls[currency] == nil, let cost = row["Cost Basis"] else { throw InvestmentError.invalidEvidence }
                controls[currency] = try InvestmentDecimal(cost)
                continue
            }
            guard row["row-kind"] == "Data", row["DataDiscriminator"] == "Summary", row["Mult"] == "1",
                  let symbol = row["Symbol"], let instrument = instruments[symbol],
                  let quantity = row["Quantity"], let costPrice = row["Cost Price"], let costBasis = row["Cost Basis"] else {
                throw InvestmentError.invalidEvidence
            }
            let total = try InvestmentDecimal(costBasis)
            costsByCurrency[currency, default: []].append(total)
            positions.append(.init(instrumentIdentity: instrument.identity, sourceAliases: instrument.aliases,
                displayName: symbol + " · " + instrument.name, units: try InvestmentDecimal(quantity), currency: currency,
                averageCost: try InvestmentDecimal(costPrice), totalCost: total,
                averageCostLabel: "Cost Price", totalCostLabel: "Cost Basis", costCurrency: currency,
                sourceOrdinal: ordinal, valuationDate: date))
        }
        guard !positions.isEmpty, Set(costsByCurrency.keys) == Set(controls.keys) else { throw InvestmentError.invalidEvidence }
        for (currency, costs) in costsByCurrency {
            guard let control = controls[currency], try printedTotalAgrees(costs, control) else { throw InvestmentError.invalidEvidence }
        }
        return statement(account: account, date: date, issueDate: issueDate, positions: positions, profile: "ibkr.open-positions.csv")
    }

    func parsePDF(_ source: RawDocument) throws -> InvestmentStatementEvidence {
        guard source.pdfPageTexts?.isEmpty == false else { throw InvestmentError.invalidEvidence }
        let text = source.searchableText
        let account = try InvestmentSourceText.one(#"(?m)^Account\s+([A-Z][0-9]+)\s*$"#, in: text)
        let end = try InvestmentSourceText.one(#"Activity Statement\s*(?:-\s*)?[A-Za-z]+\s+[0-9]+,\s+[0-9]{4}\s*-\s*([A-Za-z]+\s+[0-9]+,\s+[0-9]{4})"#, in: text)
        let date = try InvestmentSourceText.date(end)
        let issued = try InvestmentSourceText.one(#"Generated:\s*([0-9]{4}-[0-9]{2}-[0-9]{2})"#, in: text)
        let info = try InvestmentSourceText.one(#"(?s)Financial Instrument Information\s+(.*?)\s+Codes\s+Code"#, in: text)
        guard let stockStart = info.range(of: "Stocks") else { throw InvestmentError.invalidEvidence }
        let instrumentRows = String(info[stockStart.upperBound...])
        let flatInfo = instrumentRows.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let securityRows = InvestmentSourceText.captures(#"(?:^|\s)([A-Z][A-Z0-9.]+)\s+(.+?)\s+([0-9]+)\s+([A-Z]{2}[A-Z0-9]{10})\s+([A-Z][A-Z0-9.]+)\s+([A-Z0-9]+)\s+1\s+(ETF|STK)(?=\s|$)"#, in: flatInfo)
        var instruments: [String: Instrument] = [:]
        for row in securityRows {
            guard row[0] == row[4], instruments[row[0]] == nil else { throw InvestmentError.invalidEvidence }
            instruments[row[0]] = .init(identity: "ibkr-conid:" + row[2], name: row[1], aliases: ["isin:" + row[3], "symbol:" + row[0]])
        }
        let block = try InvestmentSourceText.one(#"(?s)Open Positions\s+(.*?)\s+Net Stock Position Summary"#, in: text)
        let cleaned = block.replacingOccurrences(of: #"(?m)^Activity Statement[^\n]*Page:\s*[0-9]+\s*$"#, with: "", options: .regularExpression)
        let currency = try InvestmentSourceText.one(#"Stocks\s+([A-Z]{3})\s"#, in: cleaned)
        let flat = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let number = #"([-+]?[0-9][0-9,]*(?:\.[0-9]+)?)"#
        let pattern = #"(?:^|\s)([A-Z][A-Z0-9.]+)\s+"# + Array(repeating: number, count: 7).joined(separator: #"\s+"#) + #"(?=\s|$)"#
        let matches = InvestmentSourceText.captures(pattern, in: flat)
        guard !matches.isEmpty else { throw InvestmentError.invalidEvidence }
        var positions: [InvestmentPositionEvidence] = [], costs: [InvestmentDecimal] = []
        for (offset, row) in matches.enumerated() {
            guard let instrument = instruments[row[0]], try InvestmentDecimal(row[2]).value == 1 else { throw InvestmentError.invalidEvidence }
            let cost = try InvestmentDecimal(row[4])
            costs.append(cost)
            positions.append(.init(instrumentIdentity: instrument.identity, sourceAliases: instrument.aliases,
                displayName: row[0] + " · " + instrument.name, units: try InvestmentDecimal(row[1]), currency: currency,
                averageCost: try InvestmentDecimal(row[3]), totalCost: cost, averageCostLabel: "Cost Price",
                totalCostLabel: "Cost Basis", costCurrency: currency, sourceOrdinal: offset + 1, valuationDate: date))
        }
        let totals = InvestmentSourceText.captures(#"\bTotal\s+"# + number + #"\s+"# + number + #"\s+"# + number + #"\s*$"#, in: flat)
        guard totals.count == 1, try printedTotalAgrees(costs, InvestmentDecimal(totals[0][0])) else { throw InvestmentError.invalidEvidence }
        // Prove all position-table content was classified, not just matching rows.
        var remainder = flat.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        remainder = remainder.replacingOccurrences(of: #"Symbol Quantity Mult Cost Price Cost Basis Close Price Value Unrealized P/L Code"#, with: "")
        remainder = remainder.replacingOccurrences(of: "Stocks " + currency, with: "")
        remainder = remainder.replacingOccurrences(of: #"\bTotal\s+"# + number + #"\s+"# + number + #"\s+"# + number, with: "", options: .regularExpression)
        guard remainder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw InvestmentError.invalidEvidence }
        return statement(account: account, date: date, issueDate: issued, positions: positions, profile: "ibkr.open-positions.pdf")
    }

    private func statement(account: String, date: String, issueDate: String?, positions: [InvestmentPositionEvidence], profile: String) -> InvestmentStatementEvidence {
        .init(parserProfile: profile, issueDate: issueDate,
            scopes: [.init(institution: "Interactive Brokers", identityKind: "account", identity: account, aliases: [account],
                displayName: "IBKR · " + account, holdingsDate: date, isComplete: true, positions: positions)],
            excludedSectionDescription: "Trades, cash, dividends, lending and collateral are outside current holdings.")
    }

    private func printedTotalAgrees(_ values: [InvestmentDecimal], _ control: InvestmentDecimal) throws -> Bool {
        let sum = try InvestmentSourceText.sum(values)
        // Independently rounded printed rows and total need only have overlapping
        // precision intervals. No cost field is replaced by this control arithmetic.
        func halfUnit(_ scale: Int) -> Decimal { Decimal(sign: .plus, exponent: -scale, significand: 1) / 2 }
        var tolerance = halfUnit(control.scale)
        for value in values { tolerance += halfUnit(value.scale) }
        return abs(sum - control.value) <= tolerance
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
