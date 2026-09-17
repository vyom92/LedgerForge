import Foundation

/// Geometry is used only to recover printed cell relationships. Financial values
/// always enter InvestmentDecimal from the original token, never from coordinates.
private enum InvestmentPDFLayout {
    struct Token { let text: String; let x: Double; let y: Double; let ordinal: Int }
    struct Line { let text: String; let ordinal: Int; let tokens: [Token] }
    static func compact(_ text: String) -> String { text.split(whereSeparator: \.isWhitespace).joined(separator: " ") }

    static func tokens(_ source: RawDocument) throws -> [[Token]] {
        guard let texts = source.pdfPageTexts, let pages = source.pdfPageEvidence,
              !pages.isEmpty, texts.count == pages.count else { throw InvestmentError.invalidEvidence }
        var ordinal = 0
        return try pages.enumerated().map { pageIndex, page in
            guard texts[pageIndex].split(whereSeparator: \.isWhitespace).map(String.init) == page.fragments.map(\.text) else {
                throw InvestmentError.invalidEvidence
            }
            return try page.fragments.map { fragment in
                guard let geometry = fragment.geometry, geometry.isCanonical else { throw InvestmentError.invalidEvidence }
                ordinal += 1
                return Token(text: fragment.text, x: geometry.minX, y: geometry.baselineY, ordinal: ordinal)
            }
        }
    }

    static func lines(_ tokens: [Token]) -> [Line] {
        var groups: [[Token]] = []
        for token in tokens.sorted(by: { $0.y > $1.y }) {
            if let index = groups.indices.last, abs(groups[index][0].y - token.y) <= 3 {
                groups[index].append(token)
            } else { groups.append([token]) }
        }
        return groups.map { group in
            Line(text: compact(group.sorted { $0.x < $1.x }.map(\.text).joined(separator: " ")),
                 ordinal: group.map(\.ordinal).min()!, tokens: group)
        }
    }

    static func isin(_ text: String) -> Bool {
        text.range(of: #"^[A-Z]{2}[A-Z0-9]{10}$"#, options: .regularExpression) != nil
    }
}

struct CASCurrentHoldingsParser {
    func parse(_ source: RawDocument) throws -> InvestmentStatementEvidence {
        let text = InvestmentPDFLayout.compact(source.searchableText)
        if text.localizedCaseInsensitiveContains("Consolidated Account Summary") {
            return try summary(source)
        }
        let period = try InvestmentSourceText.one(#"(?i)[0-9]{2}-[A-Za-z]{3}-[0-9]{4}\s+To\s+([0-9]{2}-[A-Za-z]{3}-[0-9]{4})"#, in: text)
        let date = try InvestmentSourceText.date(period)
        let pages = try InvestmentPDFLayout.tokens(source)
        var institution: String?, activeFolio: String?, block: [InvestmentPDFLayout.Line] = []
        var scopes: [InvestmentScopeEvidence] = []

        func finish() throws {
            guard let folio = activeFolio else { return }
            guard let institution else { throw InvestmentError.invalidEvidence }
            // Use native source order inside a bounded position. A transaction date
            // can share a visual baseline with a closing label, without belonging
            // between the words of that label in the source text.
            let sourceTokens = block.flatMap(\.tokens).sorted { $0.ordinal < $1.ordinal }
            let joined = sourceTokens.map(\.text).joined(separator: " ")
            guard let markerIndex = sourceTokens.firstIndex(where: { $0.text.uppercased().hasPrefix("ISIN:") }),
                  let nameIndex = sourceTokens[..<markerIndex].firstIndex(where: {
                      $0.text.range(of: #"^[A-Z0-9]+-.+"#, options: .regularExpression) != nil
                  }),
                  let closing = sourceTokens.first(where: { $0.text == "Closing" }) else {
                throw InvestmentError.invalidEvidence
            }
            let isin = try InvestmentSourceText.one(#"(?i)\bISIN:\s*([A-Z]{2}[A-Z0-9]{10})\b"#, in: joined)
            // The structured scheme code bounds the source name. Wrapping can put
            // ISIN on its own visual line; preceding PAN/owner metadata is excluded.
            let prefix = sourceTokens[nameIndex..<markerIndex].map(\.text).joined(separator: " ")
                .replacingOccurrences(of: #"\s*\(Advisor:[^)]*\)"#, with: "", options: .regularExpression)
            let name = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "- "))
            let units = try InvestmentDecimal(InvestmentSourceText.one(#"(?i)Closing Unit Balance:\s*([0-9][0-9,]*(?:\.[0-9]+)?)"#, in: joined))
            let nav = InvestmentSourceText.captures(#"(?i)NAV on\s+([0-9]{2}-[A-Za-z]{3}-[0-9]{4})\s*:\s*([A-Z]{3})\s+([0-9][0-9,]*(?:\.[0-9]+)?)"#, in: joined)
            guard nav.count == 1, !name.isEmpty else { throw InvestmentError.invalidEvidence }
            _ = try InvestmentDecimal(nav[0][2])
            let costs = InvestmentSourceText.captures(#"(?i)Total Cost Value\s*:\s*(?:INR\s+)?([0-9][0-9,]*(?:\.[0-9]+)?)"#, in: joined)
            guard costs.count <= 1, !joined.localizedCaseInsensitiveContains("Total Cost Value") || costs.count == 1 else {
                throw InvestmentError.invalidEvidence
            }
            let total = try costs.first.map { try InvestmentDecimal($0[0]) }
            let currency = nav[0][1].uppercased()
            let position = InvestmentPositionEvidence(instrumentIdentity: "isin:" + isin.uppercased(), sourceAliases: [name, isin],
                displayName: name, units: units, currency: currency, averageCost: nil, totalCost: total,
                averageCostLabel: nil, totalCostLabel: total == nil ? nil : "Total Cost Value", costCurrency: total == nil ? nil : currency,
                sourceOrdinal: closing.ordinal, valuationDate: try InvestmentSourceText.date(nav[0][0]))
            if let index = scopes.firstIndex(where: { $0.identity == folio && $0.institution == institution.uppercased() }) {
                let old = scopes[index]
                scopes[index] = .init(institution: old.institution, identityKind: old.identityKind, identity: old.identity,
                    aliases: old.aliases, displayName: old.displayName, holdingsDate: date, isComplete: true, positions: old.positions + [position])
            } else {
                scopes.append(.init(institution: institution.uppercased(), identityKind: "folio", identity: folio,
                    aliases: [folio], displayName: institution, holdingsDate: date, isComplete: true, positions: [position]))
            }
            activeFolio = nil; block = []
        }

        for page in pages {
            for line in InvestmentPDFLayout.lines(page) {
                let lower = line.text.lowercased()
                // CAMS can print the next fund-house heading beside its version
                // footer. The footer is not part of the institution identity;
                // summary rows with trailing balances are not headings.
                if let heading = InvestmentSourceText.captures(#"(?i)^(.+?mutual fund)(?:\s+Version:\S+)?$"#, in: line.text).first?.first,
                   !lower.contains("consolidated"), !lower.contains("portfolio") {
                    try finish()
                    institution = heading
                } else if lower.range(of: #"^folio no\s*:"#, options: .regularExpression) != nil {
                    try finish()
                    activeFolio = try InvestmentSourceText.one(#"(?i)^Folio No\s*:\s*(.+?)(?:\s+PAN\s*:|\s+KYC\s*:|$)"#, in: line.text)
                    block = [line]
                } else if activeFolio != nil, !lower.hasPrefix("page "), !lower.hasPrefix("camscasws-"),
                          lower != "consolidated account statement", !lower.hasPrefix("version:"), !lower.hasPrefix("kfincasws-") {
                    block.append(line)
                }
            }
        }
        try finish()
        guard !scopes.isEmpty else { throw InvestmentError.invalidEvidence }
        let zeros = scopes.flatMap(\.positions).filter { $0.units.value == 0 }.count
        let result = InvestmentStatementEvidence(parserProfile: "indian-mutual-funds.cas.pdf", issueDate: nil, scopes: scopes,
            excludedSectionDescription: "Transactions and historical activity are outside current holdings. \(zeros) zero-unit closing rows are excluded unless they remove an existing holding. Omitted folios are unchanged.")
        try result.validate()
        return result
    }

    private func summary(_ source: RawDocument) throws -> InvestmentStatementEvidence {
        let date = try InvestmentSourceText.date(InvestmentSourceText.one(
            #"(?i)As on\s+([0-9]{2}-[A-Za-z]{3}-[0-9]{4})"#, in: source.searchableText))
        let pages = try InvestmentPDFLayout.tokens(source)
        let number = #"([0-9][0-9,]*(?:\.[0-9]+)?)"#
        let pattern = #"^([0-9]+(?:\s*/\s*[0-9]+)?)\s+([A-Z]{2}[A-Z0-9]{10})\s+(.+?)\s+"#
            + number + #"\s+"# + number + #"\s+([0-9]{2}-[A-Za-z]{3}-[0-9]{4})\s+"#
            + number + #"\s+"# + number + #"\s+(CAMS|KFINTECH)$"#
        var scopes: [InvestmentScopeEvidence] = []
        var costs: [InvestmentDecimal] = [], control: InvestmentDecimal?
        for page in pages {
            let lines = InvestmentPDFLayout.lines(page)
            guard let headerIndex = lines.firstIndex(where: {
                $0.text.contains("Folio No.") && $0.text.contains("Closing Unit") && $0.text.contains("NAV Date")
            }) else { continue }
            let header = lines[headerIndex]
            guard header.text.range(of: #"Folio No\. Cost Value Closing Unit NAV Date Price Market Value Registrar"#,
                                    options: .regularExpression) != nil,
                  lines[(headerIndex + 1)...].prefix(3).contains(where: { $0.text.contains("(INR)") }),
                  let schemeToken = page.first(where: { $0.text == "Scheme" }),
                  let costToken = header.tokens.first(where: { $0.text == "Cost" }) else {
                throw InvestmentError.invalidEvidence
            }
            var rowIndexes: [Int] = []
            for index in lines.indices where index > headerIndex {
                if !InvestmentSourceText.captures(pattern, in: lines[index].text).isEmpty { rowIndexes.append(index) }
            }
            guard !rowIndexes.isEmpty,
                  let totalIndex = lines.indices.first(where: { $0 > rowIndexes.last! && lines[$0].text.hasPrefix("Total ") }),
                  control == nil else { throw InvestmentError.invalidEvidence }
            let totals = InvestmentSourceText.captures(#"^Total\s+"# + number + #"\s+"# + number + #"$"#, in: lines[totalIndex].text)
            guard totals.count == 1 else { throw InvestmentError.invalidEvidence }
            control = try InvestmentDecimal(totals[0][0])
            let sectionTokens = lines[(headerIndex + 1)..<totalIndex].flatMap(\.tokens)
            guard sectionTokens.filter({ InvestmentPDFLayout.isin($0.text) }).count == rowIndexes.count else {
                throw InvestmentError.invalidEvidence
            }
            for (offset, index) in rowIndexes.enumerated() {
                let row = InvestmentSourceText.captures(pattern, in: lines[index].text)[0]
                let next = offset + 1 < rowIndexes.count ? rowIndexes[offset + 1] : totalIndex
                let followingTokens: [InvestmentPDFLayout.Token] = lines[(index + 1)..<next].flatMap { $0.tokens }
                let nameTokens = followingTokens.filter { $0.x >= schemeToken.x - 2 && $0.x < costToken.x - 4 }
                let continuation = nameTokens.sorted { $0.ordinal < $1.ordinal }.map { $0.text }.joined(separator: " ")
                let name = row[2] + (continuation.isEmpty ? "" : " " + continuation)
                let total = try InvestmentDecimal(row[3])
                costs.append(total)
                _ = try InvestmentDecimal(row[6]); _ = try InvestmentDecimal(row[7])
                let position = InvestmentPositionEvidence(instrumentIdentity: "isin:" + row[1], sourceAliases: [row[1], name],
                    displayName: name, units: try InvestmentDecimal(row[4]), currency: "INR", averageCost: nil,
                    totalCost: total, averageCostLabel: nil, totalCostLabel: "Cost Value", costCurrency: "INR",
                    sourceOrdinal: lines[index].ordinal, valuationDate: try InvestmentSourceText.date(row[5]))
                if let existing = scopes.firstIndex(where: { $0.identity == row[0] }) {
                    let old = scopes[existing]
                    scopes[existing] = .init(institution: old.institution, identityKind: old.identityKind, identity: old.identity,
                        aliases: old.aliases, displayName: old.displayName, holdingsDate: date, isComplete: true,
                        positions: old.positions + [position])
                } else {
                    scopes.append(.init(institution: "CAMS / KFin CAS", identityKind: "folio", identity: row[0], aliases: [row[0]],
                        displayName: "Mutual funds", holdingsDate: date, isComplete: true, positions: [position]))
                }
            }
        }
        guard let control, !scopes.isEmpty, try InvestmentSourceText.sum(costs) == control.value else {
            throw InvestmentError.invalidEvidence
        }
        let result = InvestmentStatementEvidence(parserProfile: "indian-mutual-funds.cas-summary.pdf", issueDate: nil,
            scopes: scopes, excludedSectionDescription: "Loads, fees and omitted folios are outside this holdings update.")
        try result.validate()
        return result
    }
}

struct CBQCurrentHoldingsParser {
    func parse(_ source: RawDocument) throws -> InvestmentStatementEvidence {
        guard let pages = source.pdfPageTexts, let cover = pages.first else { throw InvestmentError.invalidEvidence }
        let text = InvestmentPDFLayout.compact(source.searchableText)
        guard text.localizedCaseInsensitiveContains("Client Investment Statement") else { throw InvestmentError.unsupportedSource }
        let cif = try InvestmentSourceText.one(#"(?i)\bCIF:\s*([0-9]+)"#, in: cover)
        guard try InvestmentSourceText.one(#"(?i)Client ID\s+([0-9]+)"#, in: text) == cif else { throw InvestmentError.identityChoiceRequired }
        let date = try InvestmentSourceText.date(InvestmentSourceText.one(#"(?i)Report date\s+([0-9]{2}/[0-9]{2}/[0-9]{4})"#, in: text))
        let issued = try InvestmentSourceText.one(#"\b([0-9]{1,2}\s+[A-Za-z]+),\s+([0-9]{4})\b"#, in: cover)
        let issueParts = InvestmentSourceText.captures(#"\b([0-9]{1,2}\s+[A-Za-z]+),\s+([0-9]{4})\b"#, in: cover)
        guard issueParts.count == 1 else { throw InvestmentError.invalidEvidence }
        let issueDate = try InvestmentSourceText.date(issued + " " + issueParts[0][1])
        let tokens = try InvestmentPDFLayout.tokens(source)
        let detailPages = pages.indices.filter {
            let page = InvestmentPDFLayout.compact(pages[$0]).lowercased()
            return page.contains("mutual funds") && page.contains("average purchase")
                && page.contains("total invested") && page.contains("current nav")
                && tokens[$0].contains(where: { $0.text == "Holding" })
        }
        guard !detailPages.isEmpty else { throw InvestmentError.invalidEvidence }
        var positions: [InvestmentPositionEvidence] = []
        for pageIndex in detailPages { positions += try rows(tokens[pageIndex]) }
        let result = InvestmentStatementEvidence(parserProfile: "cbq.investment-portfolio.pdf", issueDate: issueDate,
            scopes: [.init(institution: "CBQ", identityKind: "fund-portfolio", identity: cif, aliases: [cif],
                displayName: "CBQ Investment Portfolio", holdingsDate: date, isComplete: true, positions: positions)],
            excludedSectionDescription: "Cash, aggregate portfolio values and transaction history are outside current fund holdings.")
        try result.validate()
        return result
    }

    private func rows(_ tokens: [InvestmentPDFLayout.Token]) throws -> [InvestmentPositionEvidence] {
        guard let header = tokens.first(where: { $0.text == "Holding" }) else { throw InvestmentError.invalidEvidence }
        let headers = tokens.filter { abs($0.x - header.x) <= 20 }
        func ys(_ word: String) -> [Double] { headers.filter { $0.text.caseInsensitiveCompare(word) == .orderedSame }.map(\.y) }
        func first(_ word: String) throws -> Double {
            guard let value = ys(word).first else { throw InvestmentError.invalidEvidence }; return value
        }
        let purchaseY = try first("Purchase"), currencyY = try first("Currency"), unitsY = try first("units")
        let averageY = try first("price"), totalY = try first("amount")
        guard let navDateY = ys("date").max(), let navY = ys("NAV").min(), let valueY = ys("value").max() else {
            throw InvestmentError.invalidEvidence
        }
        let currencyTokens = tokens.filter {
            $0.x > header.x + 20 && abs($0.y - currencyY) <= 22 && (try? CurrencyCatalog.shared.definition(for: $0.text)) != nil
        }.sorted { $0.x < $1.x }
        let anchors = currencyTokens.map(\.x)
        guard !anchors.isEmpty, Set(anchors).count == anchors.count else { throw InvestmentError.invalidEvidence }
        var result: [InvestmentPositionEvidence] = []
        for (index, anchor) in anchors.enumerated() {
            // Rotated table rows run from their first baseline towards increasing
            // x. Wrapped fund names and the ISIN occupy the remainder of that row,
            // not the midpoint around its numeric baseline.
            let lower = anchor - 4
            let upper = index + 1 == anchors.count ? anchor + 35 : anchors[index + 1] - 4
            let nameTokens = tokens.filter { $0.x > lower && $0.x <= upper && $0.y < purchaseY - 10 }
            let identifiers = nameTokens.filter { InvestmentPDFLayout.isin($0.text) }
            if identifiers.isEmpty, nameTokens.contains(where: { $0.text == "Total" }) { continue }
            guard identifiers.count == 1, let isin = identifiers.first else { throw InvestmentError.invalidEvidence }
            func field(_ y: Double, isDate: Bool = false) throws -> InvestmentPDFLayout.Token {
                let found = tokens.filter {
                    abs($0.x - anchor) <= 4 && abs($0.y - y) <= 22
                        && (isDate ? (try? InvestmentSourceText.date($0.text)) != nil : (try? InvestmentDecimal($0.text)) != nil)
                }
                guard found.count == 1, let value = found.first else { throw InvestmentError.invalidEvidence }
                return value
            }
            _ = try field(purchaseY, isDate: true)
            _ = try field(navY)
            _ = try field(valueY)
            let name = nameTokens.filter { $0.ordinal != isin.ordinal }.sorted { $0.ordinal < $1.ordinal }.map(\.text).joined(separator: " ")
            let currency = currencyTokens[index].text
            result.append(.init(instrumentIdentity: "isin:" + isin.text, sourceAliases: [name, isin.text], displayName: name,
                units: try InvestmentDecimal(field(unitsY).text), currency: currency,
                averageCost: try InvestmentDecimal(field(averageY).text), totalCost: try InvestmentDecimal(field(totalY).text),
                averageCostLabel: "Average purchase price", totalCostLabel: "Total invested amount", costCurrency: currency,
                sourceOrdinal: nameTokens.map(\.ordinal).min() ?? isin.ordinal,
                valuationDate: try InvestmentSourceText.date(field(navDateY, isDate: true).text)))
        }
        guard !result.isEmpty else { throw InvestmentError.invalidEvidence }
        return result
    }
}

struct CBQLegacyPortfolioHoldingsParser {
    func parse(_ source: RawDocument) throws -> InvestmentStatementEvidence {
        guard source.pdfPageTexts?.count == 1,
              source.searchableText.localizedCaseInsensitiveContains("Investment Portfolio Holding Statement") else {
            throw InvestmentError.unsupportedSource
        }
        let pages = try InvestmentPDFLayout.tokens(source)
        guard pages.count == 1, let tokens = pages.first else { throw InvestmentError.invalidEvidence }
        let lines = InvestmentPDFLayout.lines(tokens)
        func words(_ line: InvestmentPDFLayout.Line) -> Set<String> {
            Set(line.tokens.map { $0.text.lowercased().trimmingCharacters(in: .punctuationCharacters) })
        }
        func line(containing required: Set<String>) throws -> InvestmentPDFLayout.Line {
            let matches = lines.filter { required.isSubset(of: words($0)) }
            guard matches.count == 1, let match = matches.first else { throw InvestmentError.missingSourceField("legacy labelled line") }
            return match
        }
        let report = try line(containing: ["report", "date"])
        let date = try InvestmentSourceText.date(InvestmentSourceText.one(
            #"\b([0-9]{2}-[A-Za-z]{3}-[0-9]{4})\b"#, in: report.text))
        let holderLine = try line(containing: ["unit", "holder"])
        let holder = try InvestmentSourceText.one(#"\b([0-9]+)\b"#, in: holderLine.text)
        let currencyLine = try line(containing: ["fund", "currency"])
        let currency = try InvestmentSourceText.one(#"\b([A-Z]{3})\b"#, in: currencyLine.text)
        _ = try CurrencyCatalog.shared.definition(for: currency)
        let header = try line(containing: ["fund", "name", "units"])
        let headerY = header.tokens.map(\.y).reduce(0, +) / Double(header.tokens.count)
        let headerTokens = tokens.filter { abs($0.y - headerY) <= 22 }
        func headerX(_ word: String) throws -> Double {
            let matches = headerTokens.filter { $0.text.lowercased().trimmingCharacters(in: .punctuationCharacters) == word }
            guard matches.count == 1, let token = matches.first else { throw InvestmentError.missingSourceField("legacy header anchor") }
            return token.x
        }
        // Every role comes from its printed header; values remain original text.
        let columns = try [headerX("units"), headerX("avg"), headerX(currency.lowercased()),
                           headerX("curr"), headerX("value"), headerX("unrealized")]
        guard zip(columns, columns.dropFirst()).allSatisfy({ $0 < $1 }) else { throw InvestmentError.invalidEvidence }
        let nameLimit = try headerX("no") - 4
        guard let footer = tokens.first(where: { $0.text == "*Unrealized" && $0.y < headerY }) else {
            throw InvestmentError.invalidEvidence
        }
        let currentLines = lines.filter {
            let y = $0.tokens.map(\.y).reduce(0, +) / Double($0.tokens.count)
            return y < headerY - 20 && y > footer.y + 20
        }
        var rows: [(line: InvestmentPDFLayout.Line, values: [InvestmentPDFLayout.Token])] = []
        for candidate in currentLines {
            let values = candidate.tokens.filter {
                if (try? InvestmentDecimal($0.text)) != nil { return true }
                // The excluded P/L column prints losses in parentheses. Retain
                // its cell for alignment without treating it as acquisition cost.
                return $0.x > (columns[4] + columns[5]) / 2
                    && $0.text.range(of: #"^\([0-9][0-9,]*(?:\.[0-9]+)?\)$"#, options: .regularExpression) != nil
            }.sorted { $0.x < $1.x }
            guard values.isEmpty || values.count == columns.count else {
                throw InvestmentError.missingSourceField("legacy current row cells (\(values.count) at ordinal \(candidate.ordinal))")
            }
            if !values.isEmpty { rows.append((candidate, values)) }
        }
        guard !rows.isEmpty else { throw InvestmentError.missingSourceField("legacy current rows") }
        var positions: [InvestmentPositionEvidence] = [], totals: [InvestmentDecimal] = []
        for (index, row) in rows.enumerated() {
            for (column, value) in row.values.enumerated() {
                let lower = column == 0 ? nameLimit : (columns[column - 1] + columns[column]) / 2
                let upper = column + 1 == columns.count ? Double.greatestFiniteMagnitude : (columns[column] + columns[column + 1]) / 2
                guard value.x > lower && value.x < upper else { throw InvestmentError.missingSourceField("legacy cell alignment") }
            }
            let y = row.values[0].y
            let nextY = index + 1 == rows.count ? footer.y + 20 : rows[index + 1].values[0].y + 3
            let nameTokens = tokens.filter { $0.x < nameLimit && $0.y <= y + 3 && $0.y > nextY }
            let name = nameTokens.sorted { $0.ordinal < $1.ordinal }.map(\.text).joined(separator: " ")
            guard !name.isEmpty, !nameTokens.contains(where: { InvestmentPDFLayout.isin($0.text) }) else {
                throw InvestmentError.invalidEvidence
            }
            let total = try InvestmentDecimal(row.values[2].text)
            totals.append(total)
            positions.append(.init(instrumentIdentity: "cbq-fund-name:" + name, sourceAliases: [name], displayName: name,
                units: try InvestmentDecimal(row.values[0].text), currency: currency,
                averageCost: try InvestmentDecimal(row.values[1].text), totalCost: total,
                averageCostLabel: "Avg. Cost", totalCostLabel: "Total Cost in " + currency, costCurrency: currency,
                sourceOrdinal: row.line.ordinal, valuationDate: nil))
        }
        let controlLine = try line(containing: ["total", "cost", "holdings"])
        let control = try InvestmentDecimal(InvestmentSourceText.one(#"([0-9][0-9,]*\.[0-9]+)"#, in: controlLine.text))
        guard try InvestmentSourceText.sum(totals) == control.value else { throw InvestmentError.missingSourceField("legacy total cost control") }
        let result = InvestmentStatementEvidence(parserProfile: "cbq.investment-portfolio-holding.pdf", issueDate: nil,
            scopes: [.init(institution: "CBQ", identityKind: "fund-portfolio", identity: holder, aliases: [holder],
                displayName: "CBQ Investment Portfolio", holdingsDate: date, isComplete: true, positions: positions)],
            excludedSectionDescription: "Market-price/value columns, unrealized P/L and transaction information are outside current holdings and acquisition cost.")
        try result.validate()
        return result
    }
}
