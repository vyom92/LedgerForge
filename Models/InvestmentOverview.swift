import Foundation

nonisolated struct InvestmentConvertedAmount: Equatable, Sendable {
    let numerator: InvestmentArithmetic.Exact
    let denominator: InvestmentArithmetic.Exact
    let currency: String
    let coverage: Int
    let display: String

    init(numerator: InvestmentArithmetic.Exact, denominator: InvestmentArithmetic.Exact, currency: String, coverage: Int) {
        self.numerator = numerator; self.denominator = denominator; self.currency = currency; self.coverage = coverage
        guard let token = try? InvestmentRatioFormatter.rounded(numerator: numerator, denominator: denominator,
                                                               places: MoneyFormatting.displayFractionDigits),
              let rounded = Decimal(string: token, locale: Locale(identifier: "en_US_POSIX")),
              let money = try? Money(amount: rounded, currency: currency) else { self.display = "Out of range"; return }
        self.display = MoneyFormatting.display(money)
    }

    func percent(of other: Self, positiveDenominator: Bool) -> String? {
        guard currency == other.currency, !other.numerator.isZero,
              !positiveDenominator || other.numerator.sign > 0 else { return nil }
        guard let numerator = try? InvestmentArithmetic.product(numerator, other.denominator),
              let denominator = try? InvestmentArithmetic.product(denominator, other.numerator),
              let percentage = try? InvestmentRatioFormatter.rounded(numerator: numerator, denominator: denominator, places: 2, decimalShift: 2) else { return nil }
        return percentage + "%"
    }

    /// A native-currency subtotal must not be presented as a converted total
    /// when missing FX prevented some eligible positions from contributing.
    func covering(_ expectedCount: Int) -> Self? {
        expectedCount > 0 && coverage == expectedCount ? self : nil
    }
}

nonisolated struct InvestmentOverviewLine: Identifiable, Equatable, Sendable {
    var id: String { currency }
    let currency: String
    let cost: InvestmentConvertedAmount?
    let value: InvestmentConvertedAmount?
    let gain: InvestmentConvertedAmount?
    /// Cost for precisely those priced positions contributing to gain.
    let gainCost: InvestmentConvertedAmount?
    let returnPercent: String?
    init(currency: String, cost: InvestmentConvertedAmount?, value: InvestmentConvertedAmount?,
         gain: InvestmentConvertedAmount?, gainCost: InvestmentConvertedAmount?) {
        self.currency = currency; self.cost = cost; self.value = value; self.gain = gain; self.gainCost = gainCost
        self.returnPercent = if let gain, let gainCost { gain.percent(of: gainCost, positiveDenominator: true) } else { nil }
    }
}

nonisolated enum InvestmentPortfolioGroup: String, CaseIterable, Identifiable, Sendable {
    case isp = "ISP", ibkr = "IBKR", indianMF = "Indian MF", cbq = "CBQ Investments"
    var id: String { rawValue }
    static func group(for holding: InvestmentHolding) -> Self? {
        guard let mapping = InvestmentPriceRegistry.confirmedMapping(for: holding) else { return nil }
        switch mapping.provider {
        case "fe": return .isp
        case "nasdaq": return .ibkr
        case "amfi": return .indianMF
        case "fidelity", "blackrock", "franklin": return .cbq
        default: return nil
        }
    }
}

nonisolated struct InvestmentOverviewScope: Equatable, Sendable {
    let holdingCount: Int
    let priceCount: Int
    let costCount: Int
    let gainCount: Int
    let lines: [InvestmentOverviewLine]
    let quotes: [InvestmentQuote]
    let fxDates: [Date]
    let fxMissing: Bool
    var usd: InvestmentOverviewLine? { lines.first { $0.currency == "USD" } }
    var hasCompleteCost: Bool { holdingCount > 0 && costCount == holdingCount }
    var hasCompleteGain: Bool { holdingCount > 0 && gainCount == holdingCount }
    var returnPercent: String? {
        lines.first { $0.gain?.coverage == gainCount && $0.gainCost?.coverage == gainCount }?.returnPercent
    }
    func oldestAge(at now: Date) -> Int {
        max(quotes.map { $0.age(at: now) }.max() ?? 0,
            fxDates.map { max(0, Int(now.timeIntervalSince($0) / 86_400)) }.max() ?? 0)
    }
}

nonisolated struct InvestmentPortfolioSummary: Identifiable, Equatable, Sendable {
    let group: InvestmentPortfolioGroup
    var id: String { group.id }
    let scope: InvestmentOverviewScope
    let capitalShare: String?
    let profitShare: String?
    let funds: [InvestmentFundSummary]
}

nonisolated struct InvestmentISPReportedSummary: Equatable, Sendable {
    let contributions: [InvestmentConvertedAmount]
    let growth: [InvestmentConvertedAmount]
    let vested: [InvestmentConvertedAmount]
    let vestedLabel: String
    let valuationDays: [String]
    let fetchedAt: Date
}

nonisolated struct InvestmentFundSummary: Identifiable, Equatable, Sendable {
    let id: String
    let code: String
    let displayIdentifier: String
    let name: String
    let units: Decimal?
    let quote: InvestmentQuote?
    let holdingDates: [String]
    let holdingIDs: [String]
    let scope: InvestmentOverviewScope
    let capitalShareWithinPortfolio: String?
    let profitShareWithinPortfolio: String?
    var unitsText: String { units.map(InvestmentArithmetic.text) ?? "Unavailable" }
    /// Owner-confirmed contribution instructions; never used as acquisition cost or current weights.
    var contributionStrategy: String? {
        switch code {
        case "N0USD": "Mandatory & AVC · 70% · effective 03 Mar 2026"
        case "USDL3": "Mandatory & AVC · 20% · effective 03 Mar 2026"
        case "3UUSD": "Mandatory & AVC · 10% · effective 03 Mar 2026"
        case "B0280": "Employer · 100% · effective 20 Mar 2026"
        default: nil
        }
    }
}

/// One consistent holdings/price/FX input snapshot. USD and INR are two presentations of it.
nonisolated struct InvestmentOverview: Equatable, Sendable {
    let total: InvestmentOverviewScope
    let portfolios: [InvestmentPortfolioSummary]
    var ispFunds: [InvestmentFundSummary] { portfolios.first { $0.group == .isp }?.funds ?? [] }
    var allFunds: [InvestmentFundSummary] { portfolios.flatMap(\.funds) }
    let fxLegs: [AlDarCurrency: AlDarUnitReference]
    let ispReported: InvestmentISPReportedSummary?
    static let empty = build(holdings: [], valuations: [:], legs: [:])

    var capitalShareLabel: String { total.hasCompleteCost ? "Invested-capital share" : "Share of known invested cost" }
    var profitShareLabel: String {
        let loss = (total.usd?.gain?.numerator.sign ?? 0) < 0
        return total.hasCompleteGain ? (loss ? "Share of net loss" : "Share of net P/L") : (loss ? "Share of known net loss" : "Share of known net P/L")
    }

    static func build(holdings: [InvestmentHolding], valuations: [String: InvestmentValuation],
                      legs: [AlDarCurrency: AlDarUnitReference],
                      ispAccount: ZurichISPAccountSnapshot? = nil) -> Self {
        let total = scope(holdings, valuations: valuations, legs: legs)
        let grouped = Dictionary(grouping: holdings, by: { InvestmentPortfolioGroup.group(for: $0) })
        let portfolios = InvestmentPortfolioGroup.allCases.map { group in
            let members = grouped[group] ?? []
            let part = scope(members, valuations: valuations, legs: legs,
                             currencies: group == .cbq ? ["USD", "QAR"] : ["USD", "INR"])
            return InvestmentPortfolioSummary(group: group, scope: part,
                capitalShare: share(part.usd?.cost, total.usd?.cost, partCount: part.costCount, totalCount: total.costCount, positive: true),
                profitShare: share(part.usd?.gain, total.usd?.gain, partCount: part.gainCount, totalCount: total.gainCount, positive: false),
                funds: funds(members, portfolio: group, parent: part, valuations: valuations, legs: legs))
        }
        return .init(total: total, portfolios: portfolios, fxLegs: legs,
                     ispReported: reportedSummary(ispAccount, legs: legs))
    }

    private static func reportedSummary(_ account: ZurichISPAccountSnapshot?,
                                        legs: [AlDarCurrency: AlDarUnitReference]) -> InvestmentISPReportedSummary? {
        guard let account else { return nil }
        func amounts(_ values: [ZurichISPReportedAmount]) -> [InvestmentConvertedAmount] {
            var native = NativeAmounts()
            for value in values { native.add(value.amount.value, currency: value.currency) }
            return ["USD", "INR"].compactMap { currency in
                guard let amount = native.converted(to: currency, legs: legs),
                      amount.coverage == values.count else { return nil }
                return amount
            }
        }
        let vestedPolicies = account.policies.filter { $0.vestedValue != nil }
        let vestedLabel: String
        if vestedPolicies.count == account.policies.count { vestedLabel = "Vested value" }
        else if vestedPolicies.count == 1, vestedPolicies.first?.label == "(Employer Mandatory)" {
            vestedLabel = "Employer vested value"
        } else { vestedLabel = "Vested value (\(vestedPolicies.count) of \(account.policies.count) policies)" }
        return .init(contributions: amounts(account.policies.map(\.contributions)),
                     growth: amounts(account.policies.map(\.growth)),
                     vested: amounts(vestedPolicies.compactMap(\.vestedValue)), vestedLabel: vestedLabel,
                     valuationDays: Array(Set(account.policies.map(\.valuationDay))).sorted(),
                     fetchedAt: account.fetchedAt)
    }

    private static func funds(_ holdings: [InvestmentHolding], portfolio: InvestmentPortfolioGroup,
                              parent: InvestmentOverviewScope, valuations: [String: InvestmentValuation],
                              legs: [AlDarCurrency: AlDarUnitReference]) -> [InvestmentFundSummary] {
        let groups = Dictionary(grouping: holdings, by: { InvestmentPriceRegistry.confirmedMapping(for: $0)!.identity })
        let names = ["N0USD": "iShares North America Index", "USDL3": "L&G WTW Global Equity Diversified Index",
                     "3UUSD": "iShares Emerging Markets Index USD", "B0280": "Qatar Airways ISP Conventional Blend"]
        return groups.keys.sorted().compactMap { key -> InvestmentFundSummary? in
            guard let rows = groups[key], let first = rows.first,
                  let mapping = InvestmentPriceRegistry.confirmedMapping(for: first) else { return nil }
            let part = scope(rows, valuations: valuations, legs: legs, currencies: parent.lines.map(\.currency))
            let units = try? rows.map { $0.units.value }.reduce(Decimal.zero, InvestmentArithmetic.add)
            let identifier = mapping.provider == "fe" || mapping.provider == "nasdaq" ? mapping.code
                : InvestmentPriceRegistry.definition(for: mapping)?.isin ?? mapping.code
            return .init(id: portfolio.id + "|" + key, code: mapping.code, displayIdentifier: identifier,
                name: mapping.provider == "fe" ? names[mapping.code] ?? first.displayName : first.displayName,
                units: units, quote: valuations[first.id]?.quote,
                holdingDates: Array(Set(rows.map(\.holdingsDate))).sorted(), holdingIDs: rows.map(\.id), scope: part,
                capitalShareWithinPortfolio: share(part.usd?.cost, parent.usd?.cost, partCount: part.costCount, totalCount: parent.costCount, positive: true),
                profitShareWithinPortfolio: share(part.usd?.gain, parent.usd?.gain, partCount: part.gainCount, totalCount: parent.gainCount, positive: false))
        }
    }

    private static func share(_ part: InvestmentConvertedAmount?, _ total: InvestmentConvertedAmount?, partCount: Int, totalCount: Int, positive: Bool) -> String? {
        guard let part, let total, part.coverage == partCount, total.coverage == totalCount else { return nil }
        return part.percent(of: total, positiveDenominator: positive)
    }

    private struct NativeAmounts {
        var amounts: [String: Decimal] = [:]
        var counts: [String: Int] = [:]
        var invalid: Set<String> = []
        mutating func add(_ value: Decimal, currency: String) {
            counts[currency, default: 0] += 1
            do { amounts[currency] = try InvestmentArithmetic.add(amounts[currency] ?? 0, value) }
            catch { invalid.insert(currency); amounts[currency] = nil }
        }
        func converted(to target: String, legs: [AlDarCurrency: AlDarUnitReference]) -> InvestmentConvertedAmount? {
            if target == "QAR" { return qar(legs: legs) }
            let other = target == "USD" ? "INR" : "USD"
            guard !invalid.contains(target), !invalid.contains(other) else { return nil }
            let local = amounts[target], foreign = amounts[other]
            guard local != nil || foreign != nil else { return nil }
            guard let foreign else { return local.flatMap { native($0, currency: target) } }
            guard let inr = legs[.inr]?.returned.decimal, let usd = legs[.usd]?.returned.decimal else {
                return local.flatMap { native($0, currency: target) }
            }
            do {
                // The shared Al Dar cross/inverse authority: INR per QAR / USD per QAR.
                let numeratorRate = try InvestmentArithmetic.Exact(target == "USD" ? usd : inr)
                let denominator = try InvestmentArithmetic.Exact(target == "USD" ? inr : usd)
                let numerator = try InvestmentArithmetic.combine(
                    InvestmentArithmetic.product(InvestmentArithmetic.Exact(local ?? 0), denominator),
                    InvestmentArithmetic.product(InvestmentArithmetic.Exact(foreign), numeratorRate))
                return .init(numerator: numerator, denominator: denominator, currency: target,
                    coverage: (counts[target] ?? 0) + (counts[other] ?? 0))
            } catch { return nil }
        }
        private func native(_ value: Decimal, currency: String) -> InvestmentConvertedAmount? {
            guard let coefficient = try? InvestmentArithmetic.Exact(value) else { return nil }
            return .init(numerator: coefficient, denominator: .one, currency: currency, coverage: counts[currency] ?? 0)
        }
        private func qar(legs: [AlDarCurrency: AlDarUnitReference]) -> InvestmentConvertedAmount? {
            guard invalid.isEmpty else { return nil }
            do {
                var numerator = try InvestmentArithmetic.Exact(amounts["QAR"] ?? 0)
                var denominator = InvestmentArithmetic.Exact.one
                var coverage = counts["QAR"] ?? 0
                for currency in AlDarCurrency.allCases {
                    guard let amount = amounts[currency.rawValue], let rate = legs[currency]?.returned.decimal else { continue }
                    let factor = try InvestmentArithmetic.Exact(rate)
                    numerator = try InvestmentArithmetic.combine(
                        InvestmentArithmetic.product(numerator, factor),
                        InvestmentArithmetic.product(InvestmentArithmetic.Exact(amount), denominator))
                    denominator = try InvestmentArithmetic.product(denominator, factor)
                    coverage += counts[currency.rawValue] ?? 0
                }
                guard coverage > 0 else { return nil }
                return .init(numerator: numerator, denominator: denominator, currency: "QAR", coverage: coverage)
            } catch { return nil }
        }
    }

    private static func scope(_ holdings: [InvestmentHolding], valuations: [String: InvestmentValuation],
                              legs: [AlDarCurrency: AlDarUnitReference], currencies: [String] = ["USD", "INR"]) -> InvestmentOverviewScope {
        var values = NativeAmounts(), costs = NativeAmounts(), gains = NativeAmounts(), gainCosts = NativeAmounts()
        var priceCount = 0, costCount = 0, gainCount = 0, quotes: [InvestmentQuote] = []
        for holding in holdings {
            let valuation = valuations[holding.id] ?? InvestmentValuation(holding: holding, quote: nil)
            if let value = valuation.currentValue { values.add(value, currency: holding.currency); priceCount += 1 }
            if let cost = valuation.supportedCost { costs.add(cost, currency: holding.currency); costCount += 1 }
            if let gain = valuation.gain, let cost = valuation.supportedCost {
                gains.add(gain, currency: holding.currency); gainCosts.add(cost, currency: holding.currency); gainCount += 1
            }
            if let quote = valuation.quote { quotes.append(quote) }
        }
        let lines = currencies.map { currency in
            InvestmentOverviewLine(currency: currency, cost: costs.converted(to: currency, legs: legs),
                value: values.converted(to: currency, legs: legs), gain: gains.converted(to: currency, legs: legs),
                gainCost: gainCosts.converted(to: currency, legs: legs))
        }
        var dependencies: Set<AlDarCurrency> = []
        for native in Set(holdings.map(\.currency)) {
            for target in currencies where native != target {
                if native == "USD" || target == "USD" { dependencies.insert(.usd) }
                if native == "INR" || target == "INR" { dependencies.insert(.inr) }
            }
        }
        return .init(holdingCount: holdings.count, priceCount: priceCount, costCount: costCount, gainCount: gainCount,
            lines: lines, quotes: quotes, fxDates: dependencies.compactMap { legs[$0]?.fetchedAt },
            fxMissing: dependencies.contains { legs[$0] == nil })
    }
}
