import Foundation
import Testing
@testable import LedgerForge

/// Scalar arithmetic, public response/cache and clock mechanics, never statement or holdings fixtures.
struct InvestmentValuationMechanicsTests {
    private func decimal(_ value: String) throws -> Decimal { try InvestmentDecimal(value).value }
    private func instant(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    @Test func exactProductsAndGainKeepFractionalPrecision() throws {
        #expect(try InvestmentArithmetic.multiply(decimal("1.25"), decimal("2.40")) == decimal("3.000"))
        #expect(try InvestmentArithmetic.multiply(decimal("0.000001"), decimal("0.00000001")) == decimal("0.00000000000001"))
        let gain = try InvestmentArithmetic.subtract(decimal("3.015"), decimal("2.000"))
        #expect(try gain == decimal("1.015"))
        #expect(InvestmentSimpleReturn(gain: gain, cost: try decimal("2.000")).display == "50.75%")
    }

    @Test func financialIntermediatesRejectPrecisionLossAndUnderflow() throws {
        let wide = try decimal("99999999999999999999999999999999")
        #expect(throws: InvestmentCalculationError.self) { try InvestmentArithmetic.multiply(wide, wide) }
        let tiny = Decimal(sign: .plus, exponent: -100, significand: 1)
        #expect(throws: InvestmentCalculationError.self) { try InvestmentArithmetic.multiply(tiny, tiny) }
        #expect(try InvestmentArithmetic.subtract(decimal("1.000"), decimal("1.0")) == .zero)
    }

    @Test func exactFXProductsMayExceedDecimalBeforeFinalRounding() throws {
        let amount = try InvestmentArithmetic.Exact(decimal("1234567.123456789012345678"))
        let rate = try InvestmentArithmetic.Exact(decimal("0.273972602739726027397260274"))
        let product = try InvestmentArithmetic.product(amount, rate)
        #expect(product.digits.count > 38)
        #expect(try InvestmentRatioFormatter.rounded(numerator: product, denominator: rate, places: 2) == "1234567.12")
        var negative = product; negative.negative = true
        let zero = try InvestmentArithmetic.combine(product, negative)
        #expect(zero.isZero && zero.sign == 0)
        let negativeAmount = InvestmentConvertedAmount(numerator: negative, denominator: rate, currency: "USD", coverage: 1)
        let positiveAmount = InvestmentConvertedAmount(numerator: product, denominator: rate, currency: "USD", coverage: 1)
        #expect(negativeAmount.percent(of: positiveAmount, positiveDenominator: false) == "-100.00%")
        #expect(positiveAmount.percent(of: positiveAmount, positiveDenominator: true) == "100.00%")
        // Whole-unit display rounds the exact ratio once, not a previously rounded cent.
        let belowHalf = InvestmentConvertedAmount(numerator: try InvestmentArithmetic.Exact(decimal("0.4999")),
            denominator: .one, currency: "USD", coverage: 1)
        let zeroMoney = try Money(amount: 0, currency: "USD")
        #expect(belowHalf.display == MoneyFormatting.display(zeroMoney))
    }

    @Test func percentageRoundsTheExactFractionOnlyOnce() throws {
        for (gain, cost, expected) in [("1", "3", "33.33%"), ("-1", "6", "-16.67%"),
                                       ("0", "3", "0.00%"), ("0.000001", "1000", "0.00%"),
                                       ("-0.000001", "1000", "0.00%"), ("0.00005", "1", "0.01%"),
                                       ("-0.00005", "1", "-0.01%"), ("99999999999999999999999999", "3", "3333333333333333333333333300.00%") ] {
            #expect(try InvestmentRatioFormatter.percent(gain: decimal(gain), cost: decimal(cost)) == expected)
        }
        #expect(InvestmentSimpleReturn(gain: 1, cost: 0).display == "Unavailable")
        #expect(throws: InvestmentCalculationError.self) { try InvestmentRatioFormatter.percent(gain: 1, cost: -1) }
    }

    @Test func incompleteCurrencySubtotalsCannotBePresentedAsCompleteTotals() throws {
        let subtotal = InvestmentConvertedAmount(numerator: .one, denominator: .one,
                                                 currency: "USD", coverage: 2)
        #expect(subtotal.covering(2) == subtotal)
        #expect(subtotal.covering(3) == nil)
        #expect(subtotal.covering(1) == nil)
        #expect(subtotal.covering(0) == nil)
        let empty = InvestmentConvertedAmount(numerator: .one, denominator: .one,
                                              currency: "INR", coverage: 0)
        #expect(empty.covering(0) == nil)
    }

    @Test func priorWeekdayAndCalendarYearAreUTCStable() {
        for (now, expected) in [("2026-09-18T23:59:59Z", "2026-09-17"), ("2026-09-19T00:00:00Z", "2026-09-18"),
                                ("2026-09-20T23:59:59Z", "2026-09-18"), ("2026-09-21T00:00:00Z", "2026-09-18"),
                                ("2027-01-01T00:00:00Z", "2026-12-31")] {
            #expect(InvestmentPriceDates.priorWeekday(instant(now)) == expected)
        }
        #expect(InvestmentPriceDates.display("2026-12-31") == "31 Dec 2026")
        #expect(InvestmentPriceDates.isWeekend(instant("2026-09-20T12:00:00Z")))
    }

    @Test func civilAgeAndInstantAgeHaveDifferentDeclaredBases() {
        let now = instant("2026-09-18T01:00:00Z"), observed = instant("2026-09-17T02:00:00Z")
        #expect(InvestmentPriceDates.age(day: "2026-09-17", instant: observed, zone: "Asia/Qatar", now: now) == 0)
        #expect(InvestmentPriceDates.age(day: "2026-09-17", instant: observed, zone: "Pacific/Honolulu", now: now) == 0)
        #expect(InvestmentPriceDates.age(day: "2026-09-17", instant: nil, zone: "Asia/Kolkata", now: now) == 1)
        #expect(InvestmentPriceDates.age(day: "2026-09-17", instant: nil, zone: "America/New_York", now: now) == 0)
    }

    @Test func publicJSONPreservesLexemesAndRejectsAmbiguousSyntax() throws {
        let json = try InvestmentPriceJSON.read(Data(#"{"value":0.000000123400,"text":"quote: \"ok\"","ok":true}"#.utf8))
        #expect(json["value"]?.text == "0.000000123400")
        #expect(json["text"]?.text == "quote: \"ok\"")
        #expect(json["ok"]?.boolean == true)
        for invalid in [#"{"value":1,"value":2}"#, #"{"value":01}"#, #"{"value":1,}"#, #"[1,]"#, #"{"value":NaN}"#, #"{} trailing"#] {
            #expect(throws: (any Error).self) { try InvestmentPriceJSON.read(Data(invalid.utf8)) }
        }
    }

    @Test func requestsReuseSelectedContractsWithoutFixedDiscoveryTimestamps() throws {
        let first = try InvestmentPriceClient.request(provider: "fidelity", code: nil, now: instant("2026-09-17T00:00:00Z"))
        let second = try InvestmentPriceClient.request(provider: "fidelity", code: nil, now: instant("2026-09-18T00:00:00Z"))
        #expect(first.url != second.url)
        #expect(first.value(forHTTPHeaderField: "Cookie") == nil)
        let fe = try InvestmentPriceClient.request(provider: "fe", code: nil, now: .now)
        let model = URLComponents(url: fe.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "jsonString" }!.value!
        let json = try InvestmentPriceJSON.read(Data(model.utf8))
        #expect(json["FilteringOptions"]?["CategoryId"]?.text == "126")
        #expect(json["PrefetchPages"]?.text == "80")
        #expect(json["ProjectName"]?.text == "zilpricingtable")
        #expect(json["PerformanceCurrency"] == nil)
    }

    @Test @MainActor func sameUndatedValueWeekendAndOlderResponsesRetainTheQuoteDate() throws {
        let mapping = InvestmentPriceRegistry.definitions.first { $0.mapping.provider == "fe" }!.mapping
        func quote(_ price: String, _ day: String, _ fetched: String) throws -> InvestmentQuote {
            .init(mapping: mapping, price: try InvestmentDecimal(price), valuationDay: day, valuationText: nil,
                valuationInstant: nil, dateBasis: .ownerPriorWeekdayUTC, calendarTimeZone: "UTC", fetchedAt: instant(fetched),
                sourceURL: "https://digital.feprecisionplus.com/zilpricingtable", qualification: "Public cache mechanics")
        }
        let old = try quote("0.012300", "2026-09-16", "2026-09-17T12:00:00Z")
        let same = try quote("0.0123", "2026-09-17", "2026-09-18T12:00:00Z").retainingUndatedObservation(old)
        #expect(same.price.sourceText == "0.0123" && same.valuationDay == old.valuationDay)
        #expect(same.fetchedAt > old.fetchedAt)
        let weekend = try quote("0.02", "2026-09-18", "2026-09-20T12:00:00Z").retainingUndatedObservation(old)
        #expect(weekend.price == old.price && weekend.valuationDay == old.valuationDay)
        #expect(!old.canReplace(same))
        #expect(try !quote("0.02", "2026-09-15", "2026-09-18T12:00:00Z").canReplace(old))
        let name = "LedgerForge.s97-public-cache.\(UUID())", defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let cache = InvestmentQuoteCache(defaults: defaults)
        cache.save([mapping.identity: same])
        #expect(cache.load(now: instant("2026-09-18T13:00:00Z"))[mapping.identity] == same)
        #expect(cache.load(now: instant("2026-09-16T00:00:00Z")).isEmpty)
    }
}
