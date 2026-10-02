import CryptoKit
import Foundation

/// Credential values belong only in Keychain and transient request memory.
nonisolated struct IBKRFlexCredentials: Codable, Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let token: String
    let queryID: String
    let expectedAccountID: String
    let ownerReportedExpiry: String?
    let summaryUnfilteredOwnerConfirmed: Bool

    init(token: String, queryID: String, expectedAccountID: String,
         ownerReportedExpiry: String? = nil, summaryUnfilteredOwnerConfirmed: Bool) {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.queryID = queryID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.expectedAccountID = expectedAccountID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ownerReportedExpiry = ownerReportedExpiry?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.summaryUnfilteredOwnerConfirmed = summaryUnfilteredOwnerConfirmed
    }

    func validated() throws -> Self {
        guard Self.asciiDigits(token), token.count <= 128,
              Self.asciiDigits(queryID), queryID.count <= 32,
              !expectedAccountID.isEmpty, expectedAccountID.count <= 64,
              expectedAccountID.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }),
              summaryUnfilteredOwnerConfirmed,
              ownerReportedExpiry.map({ !$0.isEmpty && $0.count <= 160 }) ?? true else {
            throw IBKRFlexSourceError.invalidConfiguration
        }
        return self
    }

    static func asciiDigits(_ text: String) -> Bool {
        !text.isEmpty && text.utf8.allSatisfy { (48...57).contains($0) }
    }

    var description: String { "IBKRFlexCredentials(<redacted>)" }
    var debugDescription: String { description }
}

/// Exact source fields from the qualified long, unit-multiplier ETF Summary grammar.
/// This type stores no credential and does not infer values from price or P/L.
nonisolated public struct IBKRFlexPosition: Codable, Equatable, Sendable {
    let conid: String
    let symbol: String
    let isin: String
    let listing: String
    let name: String
    let currency: String
    let units: InvestmentDecimal
    let averageCost: InvestmentDecimal
    let totalCost: InvestmentDecimal
    let markPrice: InvestmentDecimal
    let reportedValue: InvestmentDecimal
    let unrealizedPnL: InvestmentDecimal
    let sourceOrdinal: Int
    let sourceAttributes: [String: String]

    var instrumentIdentity: String { "ibkr-conid:" + conid }
    var sourceAliases: [String] { ["isin:" + isin, "symbol:" + symbol] }
    var displayName: String { symbol + " · " + name }

    static func parse(_ attributes: [String: String], ordinal: Int,
                      expectedAccountID: String, reportDateText: String) throws -> Self {
        func required(_ key: String) throws -> String {
            guard let value = attributes[key], !value.isEmpty else { throw IBKRFlexSourceError.incompletePosition }
            return value
        }
        func number(_ key: String) throws -> InvestmentDecimal {
            let text = try required(key)
            // Flex supplied ordinary base-10 attribute strings. Do not pass them
            // through Double, currency rounding, exponent expansion or Int units.
            let unsigned = text.first == "-" || text.first == "+" ? String(text.dropFirst()) : text
            let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)
            guard (1...2).contains(parts.count), parts.allSatisfy({ IBKRFlexCredentials.asciiDigits(String($0)) }) else {
                throw IBKRFlexSourceError.invalidNumber
            }
            do { return try InvestmentDecimal(text) }
            catch { throw IBKRFlexSourceError.invalidNumber }
        }
        guard ordinal > 0, attributes["accountId"] == expectedAccountID,
              attributes["reportDate"] == reportDateText, attributes["levelOfDetail"] == "SUMMARY",
              attributes["assetCategory"] == "STK", attributes["subCategory"] == "ETF",
              attributes["side"] == "Long", attributes["securityIDType"] == "ISIN" else {
            throw IBKRFlexSourceError.unsupportedPosition
        }
        let conid = try required("conid"), isin = try required("isin"), currency = try required("currency")
        guard IBKRFlexCredentials.asciiDigits(conid), conid.utf8.contains(where: { $0 != 48 }),
              isin.count == 12, isin.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) }),
              attributes["securityID"] == isin,
              currency.count == 3, currency.utf8.allSatisfy({ (65...90).contains($0) }) else {
            throw IBKRFlexSourceError.incompletePosition
        }
        do { _ = try CurrencyCatalog.shared.definition(for: currency) }
        catch { throw IBKRFlexSourceError.unsupportedPosition }
        let multiplier = try number("multiplier"), units = try number("position")
        let average = try number("costBasisPrice"), total = try number("costBasisMoney")
        let mark = try number("markPrice"), value = try number("positionValue"), pnl = try number("fifoPnlUnrealized")
        guard multiplier.value == 1, units.value > 0, average.value >= 0,
              total.value >= 0, mark.value > 0, value.value >= 0 else {
            throw IBKRFlexSourceError.unsupportedPosition
        }
        return .init(conid: conid, symbol: try required("symbol"), isin: isin,
                     listing: try required("listingExchange"), name: try required("description"), currency: currency,
                     units: units, averageCost: average, totalCost: total, markPrice: mark,
                     reportedValue: value, unrealizedPnL: pnl, sourceOrdinal: ordinal, sourceAttributes: attributes)
    }
}

/// Durable current-source facts, with original XML confined to parse/request RAM.
/// queryID is the requested query bound to referenceCode by the client; the broker
/// report itself echoes queryName, not a query ID. fetchedAt is not a valuation time.
nonisolated public struct IBKRFlexAccountSnapshot: Codable, Equatable, Sendable {
    static let fingerprintAlgorithm = "ledgerforge.source-bytes.sha256.v1"
    let observationID: String
    let accountID: String
    let queryID: String
    let referenceCode: String
    let reportDate: String
    let reportDateText: String
    let generatedAtSourceText: String
    let fetchedAt: Date
    let sourceFingerprintAlgorithm: String
    let sourceSHA256: String
    let sourceByteCount: Int
    let queryAttributes: [String: String]
    let statementAttributes: [String: String]
    let positions: [IBKRFlexPosition]

    var positionCount: Int { positions.count }

    static func parse(originalBytes: Data, credentials: IBKRFlexCredentials,
                      referenceCode: String, fetchedAt: Date) throws -> Self {
        _ = try credentials.validated()
        let document = try IBKRFlexXML.decode(originalBytes)
        guard document.rootName == "FlexQueryResponse", document.rootAttributes["type"] == "AF",
              !(document.rootAttributes["queryName"] ?? "").isEmpty,
              document.declaredStatementCount == "1", document.statements.count == 1,
              document.openPositionsSections == 1, !document.positions.isEmpty,
              let statement = document.statements.first else { throw IBKRFlexSourceError.incompleteAccount }
        let dateText = statement["toDate"] ?? ""
        let canonical = try canonicalDate(dateText)
        let positions = try document.positions.enumerated().map {
            try IBKRFlexPosition.parse($0.element, ordinal: $0.offset + 1,
                                       expectedAccountID: credentials.expectedAccountID, reportDateText: dateText)
        }
        let digest = SHA256.hash(data: originalBytes).map { String(format: "%02x", $0) }.joined()
        let snapshot = Self(observationID: "ibkr-flex-" + digest,
                            accountID: credentials.expectedAccountID, queryID: credentials.queryID,
                            referenceCode: referenceCode, reportDate: canonical, reportDateText: dateText,
                            generatedAtSourceText: statement["whenGenerated"] ?? "", fetchedAt: fetchedAt,
                            sourceFingerprintAlgorithm: fingerprintAlgorithm, sourceSHA256: digest,
                            sourceByteCount: originalBytes.count, queryAttributes: document.rootAttributes,
                            statementAttributes: statement, positions: positions)
        return try snapshot.validated(expectedAccountID: credentials.expectedAccountID,
                                      expectedQueryID: credentials.queryID, now: fetchedAt)
    }

    func quote(for position: IBKRFlexPosition) -> InvestmentQuote {
        let mapping = InvestmentPriceMapping(provider: "ibkr-flex", code: position.conid, currency: position.currency,
            priceKind: "Reported mark price", instrumentReference: position.instrumentIdentity,
            listing: position.listing, evidence: "Authenticated Flex Open Positions Summary")
        return .init(mapping: mapping, price: position.markPrice, valuationDay: reportDate,
            valuationText: reportDateText, valuationInstant: nil, dateBasis: .providerCalendarDate,
            calendarTimeZone: "UTC", fetchedAt: fetchedAt,
            sourceURL: "https://www.interactivebrokers.com/", qualification: "IBKR Flex report mark; not a live quote")
    }

    /// Re-run at the transaction boundary and after decoding persisted JSON.
    func validated(expectedAccountID: String, expectedQueryID: String? = nil, now: Date) throws -> Self {
        guard accountID == expectedAccountID, !accountID.isEmpty,
              expectedQueryID.map({ queryID == $0 }) ?? true,
              IBKRFlexCredentials.asciiDigits(queryID), IBKRFlexCredentials.asciiDigits(referenceCode),
              queryAttributes["type"] == "AF", !(queryAttributes["queryName"] ?? "").isEmpty,
              statementAttributes["accountId"] == accountID,
              statementAttributes["period"] == "LastBusinessDay",
              statementAttributes["fromDate"] == reportDateText, statementAttributes["toDate"] == reportDateText,
              statementAttributes["whenGenerated"] == generatedAtSourceText, !generatedAtSourceText.isEmpty,
              fetchedAt.timeIntervalSince1970.isFinite, now.timeIntervalSince1970.isFinite, fetchedAt <= now,
              sourceByteCount > 0, sourceByteCount <= IBKRFlexXML.maximumResponseBytes,
              sourceFingerprintAlgorithm == Self.fingerprintAlgorithm,
              sourceSHA256.count == 64, sourceSHA256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              observationID == "ibkr-flex-" + sourceSHA256,
              !positions.isEmpty, Set(positions.map(\.conid)).count == positions.count else {
            throw IBKRFlexSourceError.incompleteAccount
        }
        guard try Self.canonicalDate(reportDateText) == reportDate else { throw IBKRFlexSourceError.invalidDate }
        // Calendar validation does not invent a timezone for whenGenerated.
        _ = try StatementDate(canonical: reportDate)
        guard reportDate <= InvestmentPriceDates.day(fetchedAt) else { throw IBKRFlexSourceError.invalidDate }
        for (offset, position) in positions.enumerated() {
            guard try IBKRFlexPosition.parse(position.sourceAttributes, ordinal: offset + 1,
                                            expectedAccountID: accountID, reportDateText: reportDateText) == position else {
                throw IBKRFlexSourceError.incompletePosition
            }
        }
        return self
    }

    private static func canonicalDate(_ text: String) throws -> String {
        guard text.count == 8, IBKRFlexCredentials.asciiDigits(text) else { throw IBKRFlexSourceError.invalidDate }
        let bytes = Array(text.utf8)
        let canonical = String(decoding: bytes[0..<4], as: UTF8.self) + "-"
            + String(decoding: bytes[4..<6], as: UTF8.self) + "-" + String(decoding: bytes[6..<8], as: UTF8.self)
        do { return try StatementDate(canonical: canonical).canonical }
        catch { throw IBKRFlexSourceError.invalidDate }
    }
}

nonisolated enum IBKRFlexSourceError: Error, LocalizedError, Equatable, Sendable {
    case invalidConfiguration, invalidXML, incompleteAccount, incompletePosition, unsupportedPosition, invalidDate, invalidNumber
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "Enter the Flex token, query ID and expected account for the confirmed unfiltered Summary query."
        case .invalidXML: "The IBKR report could not be read completely. Previous holdings are retained."
        case .incompleteAccount: "The IBKR report did not establish the expected complete account and dated query. Previous holdings are retained."
        case .incompletePosition: "An IBKR position is missing or contradicts its source fields. Previous holdings are retained."
        case .unsupportedPosition: "The IBKR report contains a position outside the qualified ETF Summary format. Previous holdings are retained."
        case .invalidDate: "The IBKR report does not provide a valid consistent holdings date. Previous holdings are retained."
        case .invalidNumber: "An IBKR quantity or amount cannot be preserved exactly. Previous holdings are retained."
        }
    }
}

/// Synchronous parser, created and consumed inside one client operation. This
/// mutable delegate never crosses an actor boundary; only value snapshots do.
nonisolated final class IBKRFlexXML: NSObject, XMLParserDelegate {
    static let maximumResponseBytes = 32 * 1_024 * 1_024
    private(set) var rootName = ""
    private(set) var rootAttributes: [String: String] = [:]
    private(set) var control: [String: String] = [:]
    private(set) var declaredStatementCount: String?
    private(set) var statements: [[String: String]] = []
    private(set) var positions: [[String: String]] = []
    private(set) var openPositionsSections = 0
    private var stack: [String] = []
    private var text = ""
    private var rejected = false
    private var ended = false
    private var controlElements = Set<String>()

    static func decode(_ data: Data) throws -> IBKRFlexXML {
        guard !data.isEmpty, data.count <= maximumResponseBytes else { throw IBKRFlexSourceError.invalidXML }
        let delegate = IBKRFlexXML(), parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.ended, !delegate.rejected, delegate.stack.isEmpty else {
            throw IBKRFlexSourceError.invalidXML
        }
        return delegate
    }

    private func reject(_ parser: XMLParser) { rejected = true; parser.abortParsing() }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String]) {
        let path = stack + [elementName]
        if stack.isEmpty {
            guard rootName.isEmpty, ["FlexQueryResponse", "FlexStatementResponse"].contains(elementName) else { reject(parser); return }
            rootName = elementName; rootAttributes = attributes
        } else if rootName == "FlexStatementResponse" {
            guard path.count == 2, ["Status", "ReferenceCode", "Url", "ErrorCode", "ErrorMessage"].contains(elementName),
                  controlElements.insert(elementName).inserted else { reject(parser); return }
        } else {
            switch path {
            case ["FlexQueryResponse", "FlexStatements"]:
                guard declaredStatementCount == nil else { reject(parser); return }
                declaredStatementCount = attributes["count"]
            case ["FlexQueryResponse", "FlexStatements", "FlexStatement"]:
                statements.append(attributes)
            case ["FlexQueryResponse", "FlexStatements", "FlexStatement", "OpenPositions"]:
                openPositionsSections += 1
            case ["FlexQueryResponse", "FlexStatements", "FlexStatement", "OpenPositions", "OpenPosition"]:
                positions.append(attributes)
            default: reject(parser); return
            }
        }
        stack = path; text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if rootName == "FlexStatementResponse", stack.count == 2 { text += string }
        else if !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { reject(parser) }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard stack.last == elementName else { reject(parser); return }
        if rootName == "FlexStatementResponse", ["Status", "ReferenceCode", "ErrorCode"].contains(elementName) {
            control[elementName] = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        stack.removeLast(); text = ""
    }

    func parserDidEndDocument(_ parser: XMLParser) { ended = stack.isEmpty && !rootName.isEmpty }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { reject(parser) }
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) { reject(parser) }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) { reject(parser) }
}
