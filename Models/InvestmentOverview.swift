import Foundation

nonisolated struct InvestmentConvertedAmount: Equatable, Sendable {
    let numerator: InvestmentArithmetic.Exact
    let denominator: InvestmentArithmetic.Exact
    let currency: String
    let coverage: Int
    let display: String
    private let roundedDisplayMoney: Money?
    var numberDisplay: String { roundedDisplayMoney.map { MoneyFormatting.number($0) } ?? "Out of range" }
    var amountInWords: String? { roundedDisplayMoney.flatMap { MoneyFormatting.amountInWords($0) } }

    init(numerator: InvestmentArithmetic.Exact, denominator: InvestmentArithmetic.Exact, currency: String, coverage: Int) {
        self.numerator = numerator; self.denominator = denominator; self.currency = currency; self.coverage = coverage
        guard let token = try? InvestmentRatioFormatter.rounded(numerator: numerator, denominator: denominator,
                                                               places: MoneyFormatting.displayFractionDigits),
              let rounded = Decimal(string: token, locale: Locale(identifier: "en_US_POSIX")),
              let money = try? Money(amount: rounded, currency: currency) else {
            self.display = "Out of range"; self.roundedDisplayMoney = nil; return
        }
        self.roundedDisplayMoney = money
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
    static func group(for holding: InvestmentHolding, container: InvestmentContainer? = nil) -> Self? {
        if let source = container?.ibkrSource, container?.id == holding.containerID,
           holding.ibkrObservationID == source.observationID { return .ibkr }
        // Container ownership does not depend on a qualified price mapping.
        // This supplies no price and makes no claim that two instruments are aliases.
        guard let mapping = InvestmentPriceRegistry.confirmedMapping(for: holding) else {
            return container?.id == holding.containerID && container?.institution == "CBQ"
                && container?.identityKind == "fund-portfolio" ? .cbq : nil
        }
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
    func oldestFreshnessAge(at now: Date) -> Int {
        max(quotes.map { $0.freshnessAge(at: now) }.max() ?? 0,
            fxDates.map { Int(WeekdayFreshness.seconds(from: $0, to: now) / 86_400) }.max() ?? 0)
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
    let allocatedContributions: [InvestmentConvertedAmount]
    let pendingAllocation: [InvestmentConvertedAmount]
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
    /// Policy contributions enter once at portfolio level. Fund acquisition
    /// costs and the original cost-backed scope remain unchanged.
    let capitalPerformance: InvestmentOverviewScope?
    let ispPerformance: InvestmentOverviewScope?
    static let empty = build(holdings: [], valuations: [:], legs: [:])

    var performance: InvestmentOverviewScope { capitalPerformance ?? total }
    var performanceBasis: String {
        if capitalPerformance != nil, let isp = portfolios.first(where: { $0.group == .isp }) {
            let pendingNote = ispReported?.pendingAllocation.isEmpty == false ? " Pending allocation is excluded from growth and current value." : ""
            return "Baseline: reported cost for \(total.costCount) holdings plus allocated Zurich contributions for \(isp.scope.holdingCount) ISP holdings, counted once across 3 policies. Growth uses \(performance.gainCount) of \(total.holdingCount) valued holdings." + pendingNote
        }
        return "Cost and growth use \(total.gainCount) of \(total.holdingCount) holdings with reported cost and a price."
    }

    var capitalShareLabel: String { performance.hasCompleteCost ? "Invested-capital share" : "Share of known invested capital" }
    var profitShareLabel: String {
        let loss = (performance.usd?.gain?.numerator.sign ?? 0) < 0
        return performance.hasCompleteGain ? (loss ? "Share of net loss" : "Share of net P/L") : (loss ? "Share of known net loss" : "Share of known net P/L")
    }

    static func build(holdings: [InvestmentHolding], valuations: [String: InvestmentValuation],
                      legs: [AlDarCurrency: AlDarUnitReference],
                      containers: [InvestmentContainer] = [],
                      ispAccount: ZurichISPAccountSnapshot? = nil) -> Self {
        let total = scope(holdings, valuations: valuations, legs: legs)
        let containersByID = Dictionary(uniqueKeysWithValues: containers.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: holdings, by: {
            InvestmentPortfolioGroup.group(for: $0, container: containersByID[$0.containerID])
        })
        let ispMembers = grouped[.isp] ?? []
        let capital = capitalScope(holdings, isp: ispMembers, valuations: valuations, containers: containersByID, account: ispAccount, legs: legs)
        let ispCapital = capitalScope(ispMembers, isp: ispMembers, valuations: valuations, containers: containersByID, account: ispAccount, legs: legs)
        let portfolios = InvestmentPortfolioGroup.allCases.map { group in
            let members = grouped[group] ?? []
            let part = scope(members, valuations: valuations, legs: legs,
                             currencies: group == .cbq ? ["USD", "QAR"] : ["USD", "INR"])
            let performancePart = group == .isp ? (ispCapital ?? part) : part
            let performanceTotal = capital ?? total
            return InvestmentPortfolioSummary(group: group, scope: part,
                capitalShare: share(performancePart.usd?.cost, performanceTotal.usd?.cost, partCount: performancePart.costCount, totalCount: performanceTotal.costCount, positive: true),
                profitShare: share(performancePart.usd?.gain, performanceTotal.usd?.gain, partCount: performancePart.gainCount, totalCount: performanceTotal.gainCount, positive: false),
                funds: funds(members, portfolio: group, parent: part, valuations: valuations, legs: legs))
        }
        return .init(total: total, portfolios: portfolios, fxLegs: legs,
                     ispReported: reportedSummary(ispAccount, legs: legs), capitalPerformance: capital, ispPerformance: ispCapital)
    }

    private static func capitalScope(_ holdings: [InvestmentHolding], isp: [InvestmentHolding],
                                     valuations: [String: InvestmentValuation], containers: [String: InvestmentContainer],
                                     account: ZurichISPAccountSnapshot?, legs: [AlDarCurrency: AlDarUnitReference]) -> InvestmentOverviewScope? {
        guard !isp.isEmpty, let account, account.policies.count == 3,
              Set(isp.compactMap { containers[$0.containerID]?.identity }) == account.policyIDs,
              account.policies.allSatisfy({ policy in
                  let members = isp.filter { containers[$0.containerID]?.identity == policy.policyID }
                  let funds = policy.funds.filter { $0.units.value > 0 }
                  return members.count == funds.count && members.allSatisfy { holding in
                      containers[holding.containerID]?.zioSource == policy && funds.contains {
                          $0.code == holding.zioFundCode && $0.currency == holding.currency && $0.units == holding.units
                      }
                  }
              }) else { return nil }
        let base = scope(holdings, valuations: valuations, legs: legs)
        let ispIDs = Set(isp.map(\.id))
        var costs = NativeAmounts(), gains = NativeAmounts(), gainCosts = NativeAmounts()
        var costCount = 0, gainCount = 0
        for holding in holdings where !ispIDs.contains(holding.id) {
            let valuation = valuations[holding.id] ?? InvestmentValuation(holding: holding, quote: nil)
            if let cost = valuation.supportedCost { costs.add(cost, currency: holding.currency); costCount += 1 }
            if let gain = valuation.gain, let cost = valuation.supportedCost {
                gains.add(gain, currency: holding.currency); gainCosts.add(cost, currency: holding.currency); gainCount += 1
            }
        }
        for policy in account.policies {
            let members = isp.filter { containers[$0.containerID]?.identity == policy.policyID }
            guard let allocated = policy.allocatedContributions?.amount.value else { return nil }
            costs.add(allocated, currency: policy.currency, count: members.count)
            costCount += members.count
            let values = members.compactMap { valuations[$0.id]?.currentValue }
            guard values.count == members.count,
                  let value = try? values.reduce(Decimal.zero, InvestmentArithmetic.add),
                  let gain = try? InvestmentArithmetic.subtract(value, allocated) else { continue }
            gains.add(gain, currency: policy.currency, count: members.count)
            gainCosts.add(allocated, currency: policy.currency, count: members.count)
            gainCount += members.count
        }
        let lines = base.lines.map { line in
            InvestmentOverviewLine(currency: line.currency, cost: costs.converted(to: line.currency, legs: legs),
                value: line.value, gain: gains.converted(to: line.currency, legs: legs),
                gainCost: gainCosts.converted(to: line.currency, legs: legs))
        }
        return .init(holdingCount: base.holdingCount, priceCount: base.priceCount, costCount: costCount, gainCount: gainCount,
            lines: lines, quotes: base.quotes, fxDates: base.fxDates, fxMissing: base.fxMissing)
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
        var pending = NativeAmounts()
        let pendingValues = account.policies.compactMap(\.pendingAllocation)
        let hasPending = pendingValues.contains { $0 > 0 }
        if hasPending, pendingValues.count == account.policies.count {
            for (policy, value) in zip(account.policies, pendingValues) {
                pending.add(value, currency: policy.currency)
            }
        }
        let vestedPolicies = account.policies.filter { $0.vestedValue != nil }
        let vestedLabel: String
        if vestedPolicies.count == account.policies.count { vestedLabel = "Vested value" }
        else if vestedPolicies.count == 1, vestedPolicies.first?.label == "(Employer Mandatory)" {
            vestedLabel = "Employer vested value"
        } else { vestedLabel = "Vested value (\(vestedPolicies.count) of \(account.policies.count) policies)" }
        return .init(contributions: amounts(account.policies.map(\.contributions)),
                     allocatedContributions: amounts(account.policies.compactMap(\.allocatedContributions)),
                     pendingAllocation: hasPending ? ["USD", "INR"].compactMap { currency in
                         pending.converted(to: currency, legs: legs)?.covering(account.policies.count)
                     } : [],
                     growth: amounts(account.policies.map(\.growth)),
                     vested: amounts(vestedPolicies.compactMap(\.vestedValue)), vestedLabel: vestedLabel,
                     valuationDays: Array(Set(account.policies.map(\.valuationDay))).sorted(),
                     fetchedAt: account.fetchedAt)
    }

    private static func funds(_ holdings: [InvestmentHolding], portfolio: InvestmentPortfolioGroup,
                              parent: InvestmentOverviewScope, valuations: [String: InvestmentValuation],
                              legs: [AlDarCurrency: AlDarUnitReference]) -> [InvestmentFundSummary] {
        // Unmapped positions stay separate. Their source identity is not a
        // license to merge positions across folios or assert a provider mapping.
        let groups = Dictionary(grouping: holdings, by: {
            InvestmentPriceRegistry.confirmedMapping(for: $0)?.identity ?? "holding:" + $0.id
        })
        let names = ["N0USD": "iShares North America Index", "USDL3": "L&G WTW Global Equity Diversified Index",
                     "3UUSD": "iShares Emerging Markets Index USD", "B0280": "Qatar Airways ISP Conventional Blend"]
        return groups.keys.sorted().compactMap { key -> InvestmentFundSummary? in
            guard let rows = groups[key], let first = rows.first else { return nil }
            let directMapping = valuations[first.id]?.quote.flatMap {
                $0.mapping.provider == "ibkr-flex" ? $0.mapping : nil
            }
            let mapping = directMapping ?? InvestmentPriceRegistry.confirmedMapping(for: first)
            let part = scope(rows, valuations: valuations, legs: legs, currencies: parent.lines.map(\.currency))
            let units = try? rows.map { $0.units.value }.reduce(Decimal.zero, InvestmentArithmetic.add)
            let identifier = mapping.map { mapping in
                mapping.provider == "fe" || mapping.provider == "nasdaq" ? mapping.code
                    : InvestmentPriceRegistry.definition(for: mapping)?.isin ?? mapping.code
            } ?? "Price mapping unavailable"
            let name = mapping.flatMap { $0.provider == "fe" ? names[$0.code] : nil } ?? first.displayName
            return .init(id: portfolio.id + "|" + key, code: mapping?.code ?? first.instrumentIdentity, displayIdentifier: identifier,
                name: name,
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
        mutating func add(_ value: Decimal, currency: String, count: Int = 1) {
            counts[currency, default: 0] += count
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
            lines: lines, quotes: quotes,
            fxDates: AlDarCurrency.allCases.filter { dependencies.contains($0) }.compactMap { legs[$0]?.fetchedAt },
            fxMissing: dependencies.contains { legs[$0] == nil })
    }
}
