import Foundation

/// Display-only shares of the current snapshot. Stored money and quantities
/// remain exact; only the bar width crosses into floating-point geometry.
nonisolated struct InvestmentAllocationShare {
    let fraction: Double
    let label: String

    init?(numerator: InvestmentArithmetic.Exact, denominator: InvestmentArithmetic.Exact) {
        guard numerator.sign >= 0, denominator.sign > 0,
              let percentage = try? InvestmentRatioFormatter.rounded(numerator: numerator, denominator: denominator, places: 1, decimalShift: 2),
              let token = try? InvestmentRatioFormatter.rounded(numerator: numerator, denominator: denominator, places: 6),
              let fraction = Double(token), fraction.isFinite, (0...1).contains(fraction) else { return nil }
        self.fraction = fraction
        self.label = "≈" + percentage + "%"
    }

    static func value(_ part: InvestmentOverviewScope, of total: InvestmentOverviewScope) -> Self? {
        guard let amount = part.usd?.value?.covering(part.holdingCount),
              let whole = total.usd?.value?.covering(total.holdingCount),
              let numerator = try? InvestmentArithmetic.product(amount.numerator, whole.denominator),
              let denominator = try? InvestmentArithmetic.product(amount.denominator, whole.numerator) else { return nil }
        return Self(numerator: numerator, denominator: denominator)
    }

    static func units(_ part: Decimal, of total: Decimal) -> Self? {
        guard let numerator = try? InvestmentArithmetic.Exact(part),
              let denominator = try? InvestmentArithmetic.Exact(total) else { return nil }
        return Self(numerator: numerator, denominator: denominator)
    }

    static func policyUnits(_ positions: [InvestmentHolding], fund: InvestmentFundSummary) -> [String: InvestmentAllocationShare] {
        guard let total = fund.units, total > 0,
              !positions.isEmpty, Set(positions.map(\.id)) == Set(fund.holdingIDs),
              positions.allSatisfy({ $0.units.value >= 0 }),
              let sum = try? positions.reduce(Decimal.zero, { try InvestmentArithmetic.add($0, $1.units.value) }),
              sum == total else { return [:] }
        let shares = positions.compactMap { holding -> (String, InvestmentAllocationShare)? in
            InvestmentAllocationShare.units(holding.units.value, of: total).map { (holding.id, $0) }
        }
        guard shares.count == positions.count else { return [:] }
        return Dictionary(uniqueKeysWithValues: shares)
    }

}
