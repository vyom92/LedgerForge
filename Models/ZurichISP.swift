import CryptoKit
import Foundation

/// Source facts from a complete authenticated account read. This is current
/// holdings provenance, separate from statement history and public FE quotes.
nonisolated public struct ZurichISPFundPosition: Codable, Equatable, Sendable {
    let code: String
    let name: String
    let currency: String
    let fxRate: InvestmentDecimal
    let allocation: InvestmentDecimal
    let price: InvestmentDecimal
    let units: InvestmentDecimal
    let value: InvestmentDecimal
    let vestedValue: InvestmentDecimal?
    let ordinal: Int
}

nonisolated public struct ZurichISPRegularStrategy: Codable, Equatable, Sendable {
    let strategyType: String
    let effectiveDateText: String
    let effectiveDay: String
    let sequence: InvestmentDecimal
    let code: String
    let name: String
    let percentage: InvestmentDecimal
}

nonisolated public struct ZurichISPReportedAmount: Codable, Equatable, Sendable {
    let sourceText: String
    let currency: String
    let amount: InvestmentDecimal

    init(_ text: String, currency: String) throws {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        sourceText = text
        self.currency = currency
        // The proven portal tables mix USD-prefixed and unprefixed values.
        // Currency is independently established by the complete policy funds.
        guard currency == "USD" else { throw ZurichISPSnapshotError.invalidSource }
        let prefixes = ["USD", "US$", "$"]
        let prefix = prefixes.first { cleaned.hasPrefix($0) }
        let token = prefix.map { String(cleaned.dropFirst($0.count)) } ?? cleaned
        amount = try InvestmentDecimal(token.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

nonisolated public struct ZurichISPPolicyObservation: Codable, Equatable, Sendable {
    var observationID: String
    var fetchedAt: Date
    let policyID: String
    let label: String
    let currency: String
    let valuationDateText: String
    let valuationDay: String
    let funds: [ZurichISPFundPosition]
    let regularStrategy: [ZurichISPRegularStrategy]
    let contributions: ZurichISPReportedAmount
    let value: ZurichISPReportedAmount
    let growth: ZurichISPReportedAmount
    let vestedValue: ZurichISPReportedAmount?
    let summaryFields: [String: String]

    var displayName: String {
        switch label {
        case "(Employee Mandatory)": "ISP · Employee mandatory"
        case "(Employee AVC)": "ISP · Employee AVC"
        case "(Employer Mandatory)": "ISP · Employer"
        default: "ISP"
        }
    }

    func validate() throws {
        _ = try StatementDate(canonical: valuationDay)
        guard !policyID.isEmpty, Self.labels.contains(label), currency == "USD",
              !funds.isEmpty, funds.count <= 32, regularStrategy.count <= 32,
              Set(funds.map(\.code)).count == funds.count,
              Set(regularStrategy.map(\.code)).count == regularStrategy.count,
              !regularStrategy.isEmpty else { throw ZurichISPSnapshotError.invalidSource }
        let known = Set(InvestmentPriceRegistry.definitions.filter { $0.mapping.provider == "fe" }.map { $0.mapping.code })
        var total = Decimal.zero, vested = Decimal.zero, strategyTotal = Decimal.zero, allocationTotal = Decimal.zero
        for (index, fund) in funds.enumerated() {
            guard known.contains(fund.code), !fund.name.isEmpty, fund.currency == currency,
                  fund.ordinal == index + 1, fund.units.value >= 0, fund.price.value > 0,
                  fund.fxRate.value == 1, fund.value.value >= 0,
                  fund.vestedValue.map({ $0.value >= 0 }) ?? true else { throw ZurichISPSnapshotError.invalidSource }
            total = try InvestmentArithmetic.add(total, fund.value.value)
            allocationTotal = try InvestmentArithmetic.add(allocationTotal, fund.allocation.value)
            // The qualified portal table shows allocation to two decimal places;
            // its JSON retains floating residue, including slightly above 100.
            let displayedAllocation = Self.cents(fund.allocation.value)
            guard (0...100).contains(displayedAllocation),
                  value.amount.value > 0,
                  let ratio = Decimal(string: try InvestmentRatioFormatter.rounded(numerator: fund.value.value,
                    denominator: value.amount.value, places: 2, decimalShift: 2), locale: Locale(identifier: "en_US_POSIX")),
                  displayedAllocation == ratio else { throw ZurichISPSnapshotError.invalidSource }
            if let value = fund.vestedValue { vested = try InvestmentArithmetic.add(vested, value.value) }
        }
        for strategy in regularStrategy {
            guard strategy.strategyType == "R", known.contains(strategy.code), !strategy.name.isEmpty,
                  strategy.percentage.value >= 0, strategy.percentage.value <= 100 else { throw ZurichISPSnapshotError.invalidSource }
            _ = try StatementDate(canonical: strategy.effectiveDay)
            strategyTotal = try InvestmentArithmetic.add(strategyTotal, strategy.percentage.value)
        }
        guard strategyTotal == 100, Self.cents(allocationTotal) == 100, contributions.amount.value >= 0,
              Self.cents(total) == Self.cents(value.amount.value),
              Self.cents(try InvestmentArithmetic.subtract(value.amount.value, contributions.amount.value)) == Self.cents(growth.amount.value),
              [contributions.currency, value.currency, growth.currency].allSatisfy({ $0 == currency }) else {
            throw ZurichISPSnapshotError.invalidSource
        }
        if let vestedValue {
            guard funds.allSatisfy({ $0.vestedValue != nil }), vestedValue.currency == currency,
                  Self.cents(vested) == Self.cents(vestedValue.amount.value) else { throw ZurichISPSnapshotError.invalidSource }
        }
        if label == "(Employer Mandatory)", vestedValue == nil { throw ZurichISPSnapshotError.invalidSource }
    }

    static let labels: Set<String> = ["(Employee Mandatory)", "(Employee AVC)", "(Employer Mandatory)"]
    static func cents(_ value: Decimal) -> Decimal {
        var value = value, result = Decimal.zero
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }
}

nonisolated public struct ZurichISPAccountSnapshot: Codable, Equatable, Sendable {
    let policies: [ZurichISPPolicyObservation]
    var fetchedAt: Date { policies.map(\.fetchedAt).max() ?? .distantPast }
    var policyIDs: Set<String> { Set(policies.map(\.policyID)) }
    var positionCount: Int { policies.reduce(0) { $0 + $1.funds.filter { $0.units.value > 0 }.count } }

    func validate(expectedPolicyIDs: Set<String>, now: Date) throws {
        guard policies.count == 3, policyIDs.count == 3,
              expectedPolicyIDs.isEmpty || policyIDs == expectedPolicyIDs,
              Set(policies.map(\.label)) == ZurichISPPolicyObservation.labels,
              policies.allSatisfy({ $0.fetchedAt <= now && !$0.observationID.isEmpty }),
              Set(policies.map(\.observationID)).count == 1 else { throw ZurichISPSnapshotError.invalidSource }
        for policy in policies { try policy.validate() }
    }

    static func parse(_ source: ZurichISPSourceAccount, expectedPolicyIDs: Set<String>, now: Date) throws -> Self {
        var policies = try source.policies.map { policy -> ZurichISPPolicyObservation in
            let dateParts = policy.valuationDateDisplay.split(separator: "/")
            guard dateParts.count == 3 else { throw ZurichISPSnapshotError.invalidSource }
            let day = "\(dateParts[2])-\(dateParts[1])-\(dateParts[0])"
            guard let values = try InvestmentPriceJSON.read(Data(policy.fundLiteral.utf8)).array,
                  let strategies = try InvestmentPriceJSON.read(Data(policy.regularLiteral.utf8)).array else {
                throw ZurichISPSnapshotError.invalidSource
            }
            let funds = try values.enumerated().map { index, row in
                ZurichISPFundPosition(code: try text(row, "FundCode"), name: try text(row, "FundName"),
                    currency: try text(row, "FundCurrency"), fxRate: try number(row, "FXRate"),
                    allocation: try number(row, "Percentage"), price: try number(row, "Price"),
                    units: try number(row, "Units"), value: try number(row, "Value"),
                    vestedValue: try optionalNumber(row, "VestedValue"), ordinal: index + 1)
            }
            let regular = try strategies.map { row in
                let rawDate = try text(row, "EffectiveDate")
                guard rawDate.range(of: #"^/[dD]ate\(-?[0-9]+\)/$"#, options: .regularExpression) != nil,
                      let milliseconds = Int64(rawDate.dropFirst(6).dropLast(2)) else { throw ZurichISPSnapshotError.invalidSource }
                let date = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
                var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let c = calendar.dateComponents([.year, .month, .day], from: date)
                let effectiveDay = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
                return ZurichISPRegularStrategy(strategyType: try text(row, "StrategyType"), effectiveDateText: rawDate,
                    effectiveDay: effectiveDay, sequence: try number(row, "StrategySequence"), code: try text(row, "FundCode"),
                    name: try text(row, "FundDescription"), percentage: try number(row, "FundPercentage"))
            }
            let summary = try fields(policy.summaryRows, names: ["Policy type", "Status", "Start date", "Maturity date", "Plan currency", "Total contributions", "Value", "Growth", "Vested value"])
            let contributions = try fields(policy.contributionRows, names: ["Contributions", "Value", "Growth", "Vested value"])
            let currency = "USD"
            func amount(_ key: String, in fields: [String: String]) throws -> ZurichISPReportedAmount {
                guard let raw = fields[key] else { throw ZurichISPSnapshotError.invalidSource }
                return try .init(raw, currency: currency)
            }
            let contribution = try amount("Contributions", in: contributions)
            let value = try amount("Value", in: contributions), growth = try amount("Growth", in: contributions)
            let vested = try contributions["Vested value"].map { try ZurichISPReportedAmount($0, currency: currency) }
            guard try amount("Total contributions", in: summary).amount.value == contribution.amount.value,
                  try amount("Value", in: summary).amount.value == value.amount.value,
                  try amount("Growth", in: summary).amount.value == growth.amount.value,
                  try summary["Vested value"].map({ try ZurichISPReportedAmount($0, currency: currency).amount.value }) == vested?.amount.value else {
                throw ZurichISPSnapshotError.invalidSource
            }
            return .init(observationID: "", fetchedAt: source.fetchedAt, policyID: policy.policyID, label: policy.label,
                currency: currency, valuationDateText: policy.valuationDateDisplay, valuationDay: day,
                funds: funds, regularStrategy: regular, contributions: contribution, value: value, growth: growth,
                vestedValue: vested, summaryFields: summary)
        }.sorted { $0.policyID < $1.policyID }
        // Content identity ignores transport time, so a replay keeps the same source identity.
        var content = policies
        for index in content.indices { content[index].fetchedAt = Date(timeIntervalSince1970: 0) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let identity = SHA256.hash(data: try encoder.encode(content)).map { String(format: "%02x", $0) }.joined()
        for index in policies.indices { policies[index].observationID = identity }
        let result = Self(policies: policies)
        try result.validate(expectedPolicyIDs: expectedPolicyIDs, now: now)
        return result
    }

    private static func text(_ row: InvestmentPriceJSON, _ key: String) throws -> String {
        guard let value = row[key]?.text, !value.isEmpty else { throw ZurichISPSnapshotError.invalidSource }
        return value
    }
    private static func number(_ row: InvestmentPriceJSON, _ key: String) throws -> InvestmentDecimal {
        try InvestmentDecimal(text(row, key))
    }
    private static func optionalNumber(_ row: InvestmentPriceJSON, _ key: String) throws -> InvestmentDecimal? {
        guard let value = row[key] else { return nil }
        if case .null = value { return nil }
        return try InvestmentDecimal(value.requiredText())
    }
    private static func fields(_ rows: [[String]], names: Set<String>) throws -> [String: String] {
        var fields: [String: String] = [:]
        for row in rows where row.count == 2 && names.contains(row[0]) {
            guard fields[row[0]] == nil else { throw ZurichISPSnapshotError.invalidSource }
            fields[row[0]] = row[1]
        }
        return fields
    }
}

nonisolated enum ZurichISPSnapshotError: Error, LocalizedError {
    case invalidSource, stale, unavailable
    var errorDescription: String? {
        switch self {
        case .invalidSource: "The ISP response could not be verified. Previous holdings are retained."
        case .stale: "ISP holdings changed during this request, or the source is older. Previous holdings are retained."
        case .unavailable: "The ledger is unavailable. ISP holdings were not changed."
        }
    }
}
