import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct NetWorthMechanicsTests {
    @Test func displayPreferenceRejectsInvalidValuesAndPreservesOneStableSelection() throws {
        let name = "LedgerForge-s99-preferences-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        for raw: Any in [[], ["EUR"], ["USD", "USD"], ["USD", 1], "USD"] {
            defaults.set(raw, forKey: ReportingCurrencyPreferences.key)
            #expect(ReportingCurrencyPreferences(defaults: defaults).currencies == [.usd, .inr])
        }
        defaults.set(["QAR", "INR", "USD"], forKey: ReportingCurrencyPreferences.key)
        let preferences = ReportingCurrencyPreferences(defaults: defaults)
        #expect(preferences.currencies == [.usd, .inr, .qar])
        preferences.setVisible(false, currency: .usd)
        preferences.setVisible(false, currency: .inr)
        preferences.setVisible(false, currency: .qar)
        #expect(preferences.currencies == [.qar])
        #expect(ReportingCurrencyPreferences(defaults: defaults).currencies == [.qar])
    }

    @Test func exactConversionPreservesAllSixDirectionsAndSignedCancellation() throws {
        // Numbers only: these are arithmetic operands, not financial fixtures.
        let rates: [AlDarCurrency: Decimal] = [.inr: 3, .usd: 2]
        let expected: [(ReportingCurrency, ReportingCurrency, String)] = [
            (.qar, .usd, "12"), (.qar, .inr, "18"), (.usd, .qar, "3"),
            (.inr, .qar, "2"), (.usd, .inr, "9"), (.inr, .usd, "4")]
        for (from, to, answer) in expected {
            let value = try NetWorthArithmetic.convert(6, from: from, to: to, rates: rates)
            #expect(try InvestmentRatioFormatter.rounded(numerator: value.numerator, denominator: value.denominator, places: 0) == answer)
        }
        let third = try NetWorthArithmetic.convert(1, from: .inr, to: .qar, rates: rates)
        let sum = try NetWorthArithmetic.sum(Array(repeating: third, count: 300))
        #expect(try InvestmentRatioFormatter.rounded(numerator: sum.numerator, denominator: sum.denominator, places: 0) == "100")
        let negative = try NetWorthArithmetic.convert(-1, from: .inr, to: .qar, rates: rates)
        #expect(try NetWorthArithmetic.sum([third, negative]).numerator.isZero)
        #expect(NetWorthArithmetic.dependencies(from: .inr, to: .usd, isProvenZero: false) == [.inr, .usd])
    }

    @Test func missingRatesNeverBecomeZeroAndIrrelevantLegsAreNotRequired() throws {
        #expect(throws: InvestmentCalculationError.self) { try NetWorthArithmetic.convert(1, from: .inr, to: .usd, rates: [.usd: 2]) }
        #expect(throws: InvestmentCalculationError.self) { try NetWorthArithmetic.convert(1, from: .usd, to: .qar, rates: [.usd: 0]) }
        #expect(throws: InvestmentCalculationError.self) { try NetWorthArithmetic.convert(1, from: .usd, to: .qar, rates: [.usd: -1]) }
        #expect(try NetWorthArithmetic.convert(0, from: .inr, to: .usd, rates: [:]).numerator.isZero)
        #expect(try NetWorthArithmetic.convert(7, from: .usd, to: .usd, rates: [:]).denominator == .one)
        #expect(NetWorthArithmetic.dependencies(from: .usd, to: .inr, isProvenZero: true).isEmpty)
        #expect(NetWorthArithmetic.dependencies(from: .qar, to: .usd, isProvenZero: false) == [.usd])
    }

    @Test func rangeFailuresRemainExplicitAndOnlyFinalDisplayRounds() throws {
        let huge = InvestmentArithmetic.Exact(digits: Array(repeating: 9, count: 512), scale: 0, negative: false)
        #expect(throws: InvestmentCalculationError.self) { try NetWorthArithmetic.sum([.init(numerator: huge, denominator: .one)]) }
        let first = try NetWorthArithmetic.convert(1, from: .inr, to: .qar, rates: [.inr: 3])
        let total = try NetWorthArithmetic.sum([first, first])
        #expect(try InvestmentRatioFormatter.rounded(numerator: total.numerator, denominator: total.denominator, places: 0) == "1")
        #expect(try InvestmentRatioFormatter.rounded(numerator: first.numerator, denominator: first.denominator, places: 0) == "0")
    }
}
