import Foundation

/// The small JSON reader retains number lexemes (FE publishes the bid as a JSON number).
/// Duplicate object keys fail closed instead of allowing an arbitrary last value to win.
nonisolated indirect enum InvestmentPriceJSON: Sendable {
    case object([String: Self]), array([Self]), string(String), number(String), bool(Bool), null
    subscript(_ key: String) -> Self? { if case .object(let value) = self { value[key] } else { nil } }
    var text: String? {
        switch self { case .string(let text), .number(let text): text; default: nil }
    }
    var array: [Self]? { if case .array(let values) = self { values } else { nil } }
    var boolean: Bool? { if case .bool(let value) = self { value } else { nil } }
    func requiredText() throws -> String { guard let text else { throw InvestmentPriceError.invalidResponse }; return text }

    static func read(_ data: Data) throws -> Self {
        var reader = Reader(bytes: Array(data))
        let value = try reader.value(depth: 0)
        reader.whitespace()
        guard reader.index == reader.bytes.count else { throw InvestmentPriceError.invalidResponse }
        return value
    }

    private struct Reader {
        let bytes: [UInt8]
        var index = 0
        mutating func whitespace() { while index < bytes.count && [9, 10, 13, 32].contains(bytes[index]) { index += 1 } }
        mutating func take(_ byte: UInt8) -> Bool {
            whitespace()
            guard index < bytes.count, bytes[index] == byte else { return false }
            index += 1; return true
        }
        mutating func string() throws -> String {
            whitespace(); let start = index
            guard take(34) else { throw InvestmentPriceError.invalidResponse }
            var escaped = false
            while index < bytes.count {
                let byte = bytes[index]; index += 1
                if byte == 34 && !escaped {
                    return try JSONDecoder().decode(String.self, from: Data(bytes[start..<index]))
                }
                if byte == 92 && !escaped { escaped = true } else { escaped = false }
            }
            throw InvestmentPriceError.invalidResponse
        }
        mutating func value(depth: Int) throws -> InvestmentPriceJSON {
            whitespace()
            guard depth < 64, index < bytes.count else { throw InvestmentPriceError.invalidResponse }
            if bytes[index] == 34 { return .string(try string()) }
            if take(123) {
                var result: [String: InvestmentPriceJSON] = [:]
                if take(125) { return .object(result) }
                repeat {
                    let key = try string()
                    guard result[key] == nil, take(58) else { throw InvestmentPriceError.invalidResponse }
                    result[key] = try value(depth: depth + 1)
                    if take(125) { return .object(result) }
                } while take(44)
                throw InvestmentPriceError.invalidResponse
            }
            if take(91) {
                var result: [InvestmentPriceJSON] = []
                if take(93) { return .array(result) }
                repeat {
                    result.append(try value(depth: depth + 1))
                    if take(93) { return .array(result) }
                } while take(44)
                throw InvestmentPriceError.invalidResponse
            }
            let start = index
            while index < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[index]) { index += 1 }
            let token = String(decoding: bytes[start..<index], as: UTF8.self)
            switch token {
            case "null": return .null
            case "true": return .bool(true)
            case "false": return .bool(false)
            default:
                guard token.range(of: #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil else {
                    throw InvestmentPriceError.invalidResponse
                }
                return .number(token)
            }
        }
    }
}

nonisolated struct InvestmentPriceClient: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    let transport: Transport
    let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date() }, transport: Transport? = nil) {
        self.now = now
        self.transport = transport ?? { request in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 45
            configuration.httpMaximumConnectionsPerHost = 4
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw InvestmentPriceError.invalidResponse }
            return (data, http)
        }
    }

    static func request(provider: String, code: String?, now: Date) throws -> URLRequest {
        let url: URL
        switch provider {
        case "amfi": url = URL(string: "https://portal.amfiindia.com/spages/NAVAll.txt")!
        case "nasdaq":
            guard let code, code.range(of: "^[A-Z]{1,6}$", options: .regularExpression) != nil else { throw InvestmentPriceError.wrongIdentity }
            url = URL(string: "https://api.nasdaq.com/api/quote/\(code)/info?assetclass=etf")!
        case "fidelity":
            var components = URLComponents(string: "https://www.fidelity.com.sg/xapi/fund/list/sg")!
            components.queryItems = [("countries", "sg"), ("country", "sg"), ("languages", "en"), ("language", "en"),
                ("channels", "ce.private-investor"), ("channel", "ce.private-investor"),
                ("r", String(Int64(now.timeIntervalSince1970 * 1000)))].map { URLQueryItem(name: $0.0, value: $0.1) }
            url = components.url!
        case "fe":
            // Exact productive request recovered from September 9; types and spelling are intentional.
            let json = #"{"FilteringOptions":{"undefined":0,"OngoingCharge":{},"RangeId":null,"RangeName":"","CategoryId":"126","Category2Id":null,"PriipProductCode":null,"DefaultCategoryId":null,"DefaultCategory2Id":null,"ForSaleIn":null,"ShowMainUnits":false,"MPCategoryCode":"126"},"ProjectName":"zilpricingtable","LanguageCode":"en-gb","UserType":"","Region":"","LanguageId":"1","LocaleId":"1","Theme":"zilipp","SortingStyle":"1","PageNo":1,"PageSize":25,"OrderBy":"UnitName:init","IsAscOrder":true,"OverrideDocumentCountryCode":null,"ToolId":"1","PrefetchPages":80,"PrefetchPageStart":1,"OverridenThemeName":"zilipp","ForSaleIn":"","ValidateFeResearchAccess":false,"HasFeResearchFullAccess":false,"EnableSedolSearch":"false","GrsProjectId":"95400119","ShowMainUnitExpansion":false,"UseCombinedOngoingChargeTER":false}"#
            var components = URLComponents(string: "https://digitalfundservice.feprecisionplus.com/FundDataService.svc/GetRowIdList")!
            components.queryItems = [.init(name: "jsonString", value: json)]
            url = components.url!
        case "blackrock": url = URL(string: "https://www.blackrock.com/uk/individual/products/229918/")!
        case "franklin": url = URL(string: "https://www.franklintempleton.lu/our-funds/price-and-performance/products/4916/Z/franklin-technology-fund/LU0109392836")!
        default: throw InvestmentPriceError.wrongIdentity
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        if provider == "nasdaq" {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("https://www.nasdaq.com", forHTTPHeaderField: "Origin")
            request.setValue("https://www.nasdaq.com/market-activity/etf/\(code!.lowercased())", forHTTPHeaderField: "Referer")
            request.setValue("LedgerForge/97 (personal portfolio)", forHTTPHeaderField: "User-Agent")
        }
        return request
    }

    /// Called off the UI actor; a family response is parsed once and reused for its mappings.
    @concurrent func fetch(_ definitions: [InvestmentPriceDefinition]) async -> [String: Result<InvestmentQuote, InvestmentPriceError>] {
        guard let first = definitions.first else { return [:] }
        let provider = first.mapping.provider
        do {
            guard definitions.allSatisfy({ $0.mapping.provider == provider }),
                  provider != "nasdaq" || definitions.count == 1 else { throw InvestmentPriceError.wrongIdentity }
            if provider == "franklin" {
                guard definitions.count == 1 else { throw InvestmentPriceError.ambiguous }
                return [first.mapping.identity: .success(try await fetchFranklin(first).validated())]
            }
            let request = try Self.request(provider: provider, code: first.mapping.code, now: now())
            let (data, response) = try await transport(request)
            try Task.checkCancellation()
            guard response.statusCode == 200, data.count > 0, data.count <= 12_000_000 else { throw InvestmentPriceError.unavailable }
            let fetchedAt = now()
            let json: InvestmentPriceJSON? = ["nasdaq", "fidelity", "fe"].contains(provider) ? try .read(data) : nil
            let text = json == nil ? String(data: data, encoding: .utf8) : nil
            let fe: InvestmentPriceJSON? = if provider == "fe", let encoded = json?["Units"]?.text { try .read(Data(encoded.utf8)) } else { nil }
            var results: [String: Result<InvestmentQuote, InvestmentPriceError>] = [:]
            for definition in definitions {
                do {
                    results[definition.mapping.identity] = .success(try Self.parse(definition, json: json, fe: fe,
                        text: text, fetchedAt: fetchedAt, sourceURL: request.url!.absoluteString).validated())
                } catch { results[definition.mapping.identity] = .failure(error as? InvestmentPriceError ?? .invalidResponse) }
            }
            return results
        } catch {
            let failure: InvestmentPriceError = error is CancellationError ? .cancelled : (error as? InvestmentPriceError ?? (error is InvestmentError ? .invalidResponse : .unavailable))
            return Dictionary(uniqueKeysWithValues: definitions.map { ($0.mapping.identity, .failure(failure)) })
        }
    }

    private func fetchFranklin(_ definition: InvestmentPriceDefinition) async throws -> InvestmentQuote {
        // The same two operations and runtime variables sent by the retained product page.
        let operations = [
            ("FundTitle", #"query FundTitle($fundid: String!, $countrycode: String!, $languagecode: String!) { ProductDetails(fundid: $fundid, countrycode: $countrycode, languagecode: $languagecode) { shareclass { shclname shclcurr identifiers { fundid shclcode isin } } } }"#),
            ("FundHeaderOverview", #"query FundHeaderOverview($fundid: String!, $shareclasscode: String!, $countrycode: String!, $languagecode: String!) { Overview(fundid: $fundid, shareclasscode: $shareclasscode, countrycode: $countrycode, languagecode: $languagecode) { shareclass { identifiers { fundid shclcode } nav { navdate navvalue } } } }"#)
        ]
        var responses: [InvestmentPriceJSON] = []
        for (counter, operation) in operations.enumerated() {
            var request = URLRequest(url: URL(string: "https://www.franklintempleton.lu/api/pds/price-and-performance?op=\(operation.0)&id=\(counter)")!,
                                     cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var variables = ["fundid": definition.mapping.code, "countrycode": "LU", "languagecode": "en_GB"]
            if counter == 1 { variables["shareclasscode"] = "Z" }
            request.httpBody = try JSONSerialization.data(withJSONObject: ["operationName": operation.0, "variables": variables, "query": operation.1])
            let (data, response) = try await transport(request)
            try Task.checkCancellation()
            guard response.statusCode == 200, data.count <= 2_000_000 else { throw InvestmentPriceError.unavailable }
            responses.append(try .read(data))
        }
        guard let classes = responses[0]["data"]?["ProductDetails"]?["shareclass"]?.array,
              let prices = responses[1]["data"]?["Overview"]?["shareclass"]?.array else { throw InvestmentPriceError.invalidResponse }
        let identities = classes.filter { $0["identifiers"]?["shclcode"]?.text == "Z" }
        let quotes = prices.filter { $0["identifiers"]?["shclcode"]?.text == "Z" }
        guard identities.count == 1, quotes.count == 1 else { throw InvestmentPriceError.ambiguous }
        let identity = identities[0], quote = quotes[0]
        guard identity["identifiers"]?["fundid"]?.text == definition.mapping.code,
              quote["identifiers"]?["fundid"]?.text == definition.mapping.code,
              identity["identifiers"]?["isin"]?.text == definition.isin,
              identity["shclname"]?.text == "A (acc) USD" else { throw InvestmentPriceError.wrongIdentity }
        guard identity["shclcurr"]?.text == definition.mapping.currency else { throw InvestmentPriceError.wrongCurrency }
        guard let token = quote["nav"]?["navvalue"]?.text, let date = quote["nav"]?["navdate"]?.text else { throw InvestmentPriceError.invalidResponse }
        let day = try Self.civilDate(date, formats: ["yyyy-MM-dd", "dd/MM/yyyy"])
        let fetchedAt = now()
        guard day <= InvestmentPriceDates.day(fetchedAt, zone: "Europe/Luxembourg") else { throw InvestmentPriceError.invalidResponse }
        let decimalToken = token.hasPrefix("$") ? String(token.dropFirst()) : token
        return .init(mapping: definition.mapping, price: try InvestmentDecimal(decimalToken), valuationDay: day, valuationText: date,
            valuationInstant: nil, dateBasis: .providerCalendarDate, calendarTimeZone: "Europe/Luxembourg", fetchedAt: fetchedAt,
            sourceURL: "https://www.franklintempleton.lu/our-funds/price-and-performance/products/4916/Z/franklin-technology-fund/LU0109392836",
            qualification: "Issuer NAV is unconfirmed unless explicitly stated otherwise; exact class checked through FundTitle")
    }

    static func parse(_ definition: InvestmentPriceDefinition, json: InvestmentPriceJSON?, fe: InvestmentPriceJSON?,
                      text: String?, fetchedAt: Date, sourceURL: String) throws -> InvestmentQuote {
        let mapping = definition.mapping
        var token: String, day: String, valuationText: String?, instant: Date?
        var basis = InvestmentPriceDateBasis.providerCalendarDate
        var zone = "UTC", qualification = "Provider NAV; no finality flag supplied"
        switch mapping.provider {
        case "amfi":
            guard let text else { throw InvestmentPriceError.invalidResponse }
            let rows = text.components(separatedBy: .newlines).map { $0.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
                .filter { $0.first == mapping.code }
            guard rows.count == 1 else { throw rows.isEmpty ? InvestmentPriceError.wrongIdentity : .ambiguous }
            let row = rows[0]
            guard row.count == 8, [row[1], row[2]].contains(definition.isin ?? "") else { throw InvestmentPriceError.wrongIdentity }
            guard row[4].caseInsensitiveCompare(definition.expectedPlan ?? "") == .orderedSame,
                  row[5].caseInsensitiveCompare(definition.expectedOption ?? "") == .orderedSame else { throw InvestmentPriceError.wrongIdentity }
            token = row[6]; day = try civilDate(row[7], formats: ["dd-MMM-yyyy"]); zone = "Asia/Kolkata"
            qualification = "INR denomination confirmed by scheme evidence; feed has no currency field"
        case "fidelity":
            guard json?["success"]?.boolean == true, json?["code"]?.text == "BS-200-01-010",
                  let row = json?["data"]?[mapping.code], let facts = row["shareClassFacts"],
                  facts["id"]?.text == mapping.code, facts["isin"]?.text == definition.isin,
                  facts["shareType"]?.text == "A", facts["distributionType"]?.text == "Reinvested dividend",
                  facts["hedged"]?.boolean == false,
                  facts["fundRangeCode"]?.text == (mapping.code == "FAGAU/G" ? "FAST" : "FF") else { throw InvestmentPriceError.wrongIdentity }
            guard facts["currencyName"]?.text == mapping.currency, facts["fundCurrency"]?.text == mapping.currency else { throw InvestmentPriceError.wrongCurrency }
            guard case .string(let value) = row["priceData"]?["nav"]?["value"],
                  let date = row["priceData"]?["nav"]?["date"]?.text else { throw InvestmentPriceError.invalidResponse }
            token = value; day = date; zone = "Asia/Singapore"
        case "fe":
            guard fe?["IsSuccessful"]?.boolean == true, let rows = fe?["DataList"]?.array else { throw InvestmentPriceError.invalidResponse }
            let matches = rows.filter { $0["Common"]?["FundCode_Customtable"]?.text == mapping.code }
            guard matches.count == 1 else { throw matches.isEmpty ? InvestmentPriceError.wrongIdentity : .ambiguous }
            let row = matches[0]
            guard row["Common"]?["TypeCode"]?.text == mapping.instrumentReference,
                  "FDD:" + (row["Common"]?["CitiCode"]?.text ?? "") == mapping.instrumentReference else { throw InvestmentPriceError.wrongIdentity }
            guard row["Price"]?["Bid"]?["Currency"]?.text == mapping.currency,
                  row["Price"]?["Currency_UnitLevel"]?.text == mapping.currency else { throw InvestmentPriceError.wrongCurrency }
            guard let value = row["Price"]?["Bid"]?["Amount"]?.text else { throw InvestmentPriceError.invalidResponse }
            token = value; day = InvestmentPriceDates.priorWeekday(fetchedAt); basis = .ownerPriorWeekdayUTC
            qualification = "Direct table bid; FE supplies no price timestamp. Unchanged quotes retain their associated date."
        case "nasdaq":
            guard let row = json?["data"], row["symbol"]?.text == mapping.code,
                  row["assetClass"]?.text?.lowercased() == "etf",
                  let exchange = row["exchange"]?.text,
                  exchange == (mapping.listing == "ARCA" ? "PSE" : "NASDAQ-GM") else { throw InvestmentPriceError.wrongIdentity }
            if let currency = row["currency"]?.text, currency != mapping.currency { throw InvestmentPriceError.wrongCurrency }
            guard let price = row["primaryData"]?["lastSalePrice"]?.text, price.hasPrefix("$"),
                  let timestamp = row["primaryData"]?["lastTradeTimestamp"]?.text else { throw InvestmentPriceError.invalidResponse }
            token = String(price.dropFirst()); valuationText = timestamp; zone = "America/New_York"
            let prefix = firstMatch(#"([A-Za-z]{3} [0-9]{1,2}, [0-9]{4})"#, in: timestamp)
            guard let prefix else { throw InvestmentPriceError.invalidResponse }
            day = try civilDate(prefix, formats: ["MMM d, yyyy"])
            if timestamp != prefix {
                guard timestamp.hasSuffix(" ET") else { throw InvestmentPriceError.invalidResponse }
                let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(identifier: zone); formatter.isLenient = false
                for format in ["MMM d, yyyy h:mm a", "MMM d, yyyy, h:mm a", "MMM d, yyyy h:mm:ss a", "MMM d, yyyy, h:mm:ss a"] {
                    formatter.dateFormat = format
                    if let parsed = formatter.date(from: String(timestamp.dropLast(3))) { instant = parsed; break }
                }
                guard instant != nil else { throw InvestmentPriceError.invalidResponse }
                basis = .providerInstant
            }
            qualification = "Dated last-sale observation; no official-close or real-time guarantee. USD independently confirmed."
        case "blackrock", "franklin":
            let parsed = try InvestmentIssuerPriceParser.parse(provider: mapping.provider, html: text ?? "", isin: definition.isin ?? "")
            token = parsed.price; day = parsed.day; zone = "Europe/Luxembourg"
            qualification = mapping.provider == "franklin" ? "Issuer NAV is unconfirmed unless explicitly stated otherwise" : "Class A2 USD accumulating NAV; no finality flag supplied"
        default: throw InvestmentPriceError.wrongIdentity
        }
        let price = try InvestmentDecimal(token)
        guard price.value > 0, day <= InvestmentPriceDates.day(fetchedAt, zone: zone) else { throw InvestmentPriceError.invalidResponse }
        return .init(mapping: mapping, price: price, valuationDay: day, valuationText: valuationText,
            valuationInstant: instant, dateBasis: basis, calendarTimeZone: zone, fetchedAt: fetchedAt,
            sourceURL: sourceURL.components(separatedBy: "?r=").first ?? sourceURL, qualification: qualification)
    }

    static func civilDate(_ text: String, formats: [String]) throws -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = InvestmentPriceDates.calendar(); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return InvestmentPriceDates.day(date) }
        }
        throw InvestmentPriceError.invalidResponse
    }

    static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}

nonisolated enum InvestmentIssuerPriceParser {
    static func parse(provider: String, html: String, isin: String) throws -> (price: String, day: String) {
        guard provider == "blackrock" else { throw InvestmentPriceError.unavailable }
        guard let table = InvestmentPriceClient.firstMatch(#"<table\b[^>]*\bid=["']pricingAndExchangeTable["'][^>]*>(.*?)</table>"#, in: html),
              let regex = try? NSRegularExpression(pattern: #"<tr\b[^>]*>(.*?)</tr>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            throw InvestmentPriceError.invalidResponse
        }
        let rows = regex.matches(in: table, range: NSRange(table.startIndex..., in: table)).compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: table) else { return nil }; return String(table[range])
        }
        func cell(_ name: String, row: String) -> String? {
            InvestmentPriceClient.firstMatch("<td\\b[^>]*class=[\"'][^\"']*\\b" + name + "\\b[^\"']*[\"'][^>]*>(.*?)</td>", in: row)
                .map { $0.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&nbsp;", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        let matches = rows.filter { cell("colIsin", row: $0) == isin }
        guard matches.count == 1 else { throw matches.isEmpty ? InvestmentPriceError.wrongIdentity : .ambiguous }
        let row = matches[0]
        guard cell("colCurrencyCode", row: row) == "USD" else { throw InvestmentPriceError.wrongCurrency }
        guard row.contains("aria-label=\"Class A2 USD Accumulating\""),
              let price = cell("colNavAmount", row: row), let date = cell("colNavAsOfDate", row: row) else {
            throw InvestmentPriceError.wrongIdentity
        }
        return (price, try InvestmentPriceClient.civilDate(date.replacingOccurrences(of: "/Sept/", with: "/Sep/"), formats: ["dd/MMM/yyyy"]))
    }
}
