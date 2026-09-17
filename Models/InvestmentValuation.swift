import Foundation

nonisolated enum InvestmentCalculationError: Error { case range, invalidDenominator }

/// Bounded base-10 arithmetic. Do not rely on Foundation's error flags: some
/// exponent/precision overflows return .noError on the current runtime.
nonisolated enum InvestmentArithmetic {
    static func multiply(_ lhs: Decimal, _ rhs: Decimal) throws -> Decimal {
        try product(Exact(lhs), Exact(rhs)).decimal()
    }

    static func product(_ left: Exact, _ right: Exact) throws -> Exact {
        guard left.digits.count + right.digits.count <= 512 else { throw InvestmentCalculationError.range }
        var digits = Array(repeating: 0, count: left.digits.count + right.digits.count)
        for i in left.digits.indices.reversed() {
            var carry = 0
            for j in right.digits.indices.reversed() {
                let index = i + j + 1, value = left.digits[i] * right.digits[j] + digits[index] + carry
                digits[index] = value % 10; carry = value / 10
            }
            digits[i] += carry
        }
        return Exact(digits: digits, scale: left.scale + right.scale, negative: left.negative != right.negative)
    }

    static func subtract(_ lhs: Decimal, _ rhs: Decimal) throws -> Decimal {
        var right = try Exact(rhs); right.negative.toggle()
        return try combine(Exact(lhs), right).decimal()
    }

    static func add(_ lhs: Decimal, _ rhs: Decimal) throws -> Decimal {
        try combine(Exact(lhs), Exact(rhs)).decimal()
    }

    static func combine(_ left: Exact, _ right: Exact) throws -> Exact {
        let scale = max(left.scale, right.scale)
        var lhs = left.digits + Array(repeating: 0, count: scale - left.scale)
        var rhs = right.digits + Array(repeating: 0, count: scale - right.scale)
        let count = max(lhs.count, rhs.count)
        guard count <= 512 else { throw InvestmentCalculationError.range }
        lhs = Array(repeating: 0, count: count - lhs.count) + lhs
        rhs = Array(repeating: 0, count: count - rhs.count) + rhs
        var digits = lhs, negative = left.negative
        if left.negative == right.negative {
            var carry = 0
            for i in lhs.indices.reversed() { let value = lhs[i] + rhs[i] + carry; digits[i] = value % 10; carry = value / 10 }
            if carry > 0 { digits.insert(carry, at: 0) }
        } else {
            if lhs.lexicographicallyPrecedes(rhs) { swap(&lhs, &rhs); negative = right.negative }
            var borrow = 0
            for i in lhs.indices.reversed() {
                var value = lhs[i] - rhs[i] - borrow; borrow = value < 0 ? 1 : 0
                if value < 0 { value += 10 }; digits[i] = value
            }
        }
        return Exact(digits: digits, scale: scale, negative: negative)
    }

    struct Exact: Equatable, Sendable {
        var digits: [Int]
        var scale: Int
        var negative: Bool
        static let one = Self(digits: [1], scale: 0, negative: false)
        var isZero: Bool { digits == [0] }
        var sign: Int { isZero ? 0 : negative ? -1 : 1 }
        init(_ value: Decimal) throws {
            guard !value.isNaN else { throw InvestmentCalculationError.range }
            let raw = InvestmentArithmetic.text(value)
            let token = raw.first == "-" ? String(raw.dropFirst()) : raw
            let parts = token.split(separator: ".", omittingEmptySubsequences: false)
            let digits = token.filter { $0 != "." }.compactMap(\.wholeNumberValue)
            guard (1...2).contains(parts.count), !digits.isEmpty, digits.count <= 512,
                  digits.count == token.filter({ $0 != "." }).count else { throw InvestmentCalculationError.range }
            self.init(digits: digits, scale: parts.count == 2 ? parts[1].count : 0, negative: value < 0)
        }
        init(digits: [Int], scale: Int, negative: Bool) {
            self.digits = Array(digits.drop(while: { $0 == 0 })); self.scale = scale; self.negative = negative
            if self.digits.isEmpty { self.digits = [0]; self.scale = 0; self.negative = false }
            while self.scale > 0 && self.digits.last == 0 { self.digits.removeLast(); self.scale -= 1 }
        }
        func decimal() throws -> Decimal {
            // 38 significant decimal digits fit the mantissa. The round trip
            // additionally checks exponent bounds and Foundation conversion.
            guard digits.count <= 38, scale <= 128 else { throw InvestmentCalculationError.range }
            var text = digits.map(String.init).joined()
            if scale >= text.count { text = String(repeating: "0", count: scale - text.count + 1) + text }
            if scale > 0 { text.insert(".", at: text.index(text.endIndex, offsetBy: -scale)) }
            if negative { text = "-" + text }
            guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
                  let checked = try? Exact(value), checked == self else { throw InvestmentCalculationError.range }
            return value
        }
    }

    static func text(_ value: Decimal) -> String {
        var value = value
        return NSDecimalString(&value, Locale(identifier: "en_US_POSIX"))
    }

    @MainActor static func displayedMoney(_ value: Decimal?, currency: String) -> String {
        guard var value else { return "Unavailable" }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, MoneyFormatting.displayFractionDigits, .plain)
        guard let money = try? Money(amount: rounded, currency: currency) else { return "Out of range" }
        return MoneyFormatting.display(money)
    }
}

/// Keep the exact fraction until presentation; no rounded return participates in any total.
nonisolated struct InvestmentSimpleReturn: Equatable, Sendable {
    let gain: Decimal
    let cost: Decimal

    var display: String {
        guard cost > 0 else { return "Unavailable" }
        return (try? InvestmentRatioFormatter.percent(gain: gain, cost: cost)) ?? "Out of range"
    }
}

/// Decimal long division rounds the exact rational once, at the final two-place display.
/// Bounded digit arrays avoid both a repeating Decimal approximation and a new big-number dependency.
nonisolated enum InvestmentRatioFormatter {
    static func percent(gain: Decimal, cost: Decimal) throws -> String {
        guard cost > 0 else { throw InvestmentCalculationError.invalidDenominator }
        return try rounded(numerator: gain, denominator: cost, places: 2, decimalShift: 2) + "%"
    }

    static func signedShare(_ numerator: Decimal, of denominator: Decimal) throws -> String {
        try rounded(numerator: numerator, denominator: denominator, places: 2, decimalShift: 2) + "%"
    }

    static func rounded(numerator: Decimal, denominator: Decimal, places: Int, decimalShift: Int = 0) throws -> String {
        try rounded(numerator: InvestmentArithmetic.Exact(numerator), denominator: InvestmentArithmetic.Exact(denominator), places: places, decimalShift: decimalShift)
    }

    static func rounded(numerator: InvestmentArithmetic.Exact, denominator: InvestmentArithmetic.Exact, places: Int, decimalShift: Int = 0) throws -> String {
        guard !denominator.isZero, (0...6).contains(places), (0...6).contains(decimalShift) else { throw InvestmentCalculationError.invalidDenominator }
        let negativeResult = numerator.negative != denominator.negative
        let n = numerator.digits + Array(repeating: 0, count: denominator.scale + places + decimalShift)
        let d = trim(denominator.digits + Array(repeating: 0, count: numerator.scale))
        guard n.count <= 512, d.count <= 512, d != [0] else { throw InvestmentCalculationError.range }
        var remainder = [0], quotient: [Int] = []
        for digit in n {
            remainder = trim(remainder + [digit])
            var count = 0
            while compare(remainder, d) >= 0 { remainder = subtract(remainder, d); count += 1 }
            quotient.append(count)
        }
        var doubled = remainder, carry = 0
        for i in doubled.indices.reversed() { let sum = doubled[i] * 2 + carry; doubled[i] = sum % 10; carry = sum / 10 }
        if carry > 0 { doubled.insert(carry, at: 0) }
        quotient = trim(quotient)
        if compare(doubled, d) >= 0 {
            var carry = 1
            for i in quotient.indices.reversed() { let sum = quotient[i] + carry; quotient[i] = sum % 10; carry = sum / 10 }
            if carry > 0 { quotient.insert(carry, at: 0) }
        }
        while quotient.count < places + 1 { quotient.insert(0, at: 0) }
        let negative = negativeResult && quotient.contains(where: { $0 != 0 })
        return (negative ? "-" : "") + quotient.dropLast(places).map(String.init).joined()
            + (places > 0 ? "." + quotient.suffix(places).map(String.init).joined() : "")
    }
    private static func trim(_ digits: [Int]) -> [Int] {
        let result = Array(digits.drop(while: { $0 == 0 })); return result.isEmpty ? [0] : result
    }
    private static func compare(_ lhs: [Int], _ rhs: [Int]) -> Int {
        if lhs.count != rhs.count { return lhs.count < rhs.count ? -1 : 1 }
        for (l, r) in zip(lhs, rhs) where l != r { return l < r ? -1 : 1 }
        return 0
    }
    private static func subtract(_ lhs: [Int], _ rhs: [Int]) -> [Int] {
        var result = lhs, borrow = 0
        for i in result.indices.reversed() {
            let j = i - (lhs.count - rhs.count)
            var value = result[i] - (j >= 0 ? rhs[j] : 0) - borrow
            borrow = value < 0 ? 1 : 0; if value < 0 { value += 10 }; result[i] = value
        }
        return trim(result)
    }
}

nonisolated enum InvestmentPriceDateBasis: String, Codable, Sendable {
    case providerCalendarDate, providerInstant, ownerPriorWeekdayUTC

    var label: String {
        switch self {
        case .providerCalendarDate: "Provider calendar date"
        case .providerInstant: "Provider timestamp"
        case .ownerPriorWeekdayUTC: "Prior weekday end of day (UTC), owner-specified"
        }
    }
}

nonisolated enum InvestmentPriceDates {
    static func calendar(_ zone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func day(_ date: Date, zone: String = "UTC") -> String {
        let c = calendar(zone).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func date(_ day: String, zone: String = "UTC") -> Date? {
        guard (try? StatementDate(canonical: day)) != nil else { return nil }
        let parts = day.split(separator: "-").compactMap { Int($0) }
        return calendar(zone).date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func priorWeekday(_ now: Date) -> String {
        let calendar = calendar()
        var date = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        while [1, 7].contains(calendar.component(.weekday, from: date)) {
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }
        return day(date)
    }

    static func isWeekend(_ now: Date) -> Bool { [1, 7].contains(calendar().component(.weekday, from: now)) }

    static func display(_ day: String) -> String {
        guard let date = date(day) else { return "Unavailable" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.calendar = calendar()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: date)
    }

    static func age(day: String, instant: Date?, zone: String, now: Date) -> Int {
        if let instant { return max(0, Int(now.timeIntervalSince(instant) / 86_400)) }
        guard let date = date(day, zone: zone) else { return 4 }
        return max(0, calendar(zone).dateComponents([.day], from: date, to: calendar(zone).startOfDay(for: now)).day ?? 4)
    }
}

nonisolated struct InvestmentQuote: Equatable, Codable, Sendable {
    let mapping: InvestmentPriceMapping
    let price: InvestmentDecimal
    let valuationDay: String
    let valuationText: String?
    let valuationInstant: Date?
    let dateBasis: InvestmentPriceDateBasis
    let calendarTimeZone: String
    let fetchedAt: Date
    let sourceURL: String
    let qualification: String

    func validated() throws -> Self {
        guard price.value > 0, !mapping.identity.isEmpty, mapping.priceKind != nil,
              mapping.instrumentReference != nil, TimeZone(identifier: calendarTimeZone) != nil,
              fetchedAt.timeIntervalSince1970.isFinite,
              (dateBasis == .providerInstant) == (valuationInstant != nil) else { throw InvestmentPriceError.invalidResponse }
        _ = try StatementDate(canonical: valuationDay)
        guard valuationDay <= InvestmentPriceDates.day(fetchedAt, zone: calendarTimeZone),
              valuationInstant.map({ $0 <= fetchedAt && InvestmentPriceDates.day($0, zone: calendarTimeZone) == valuationDay }) ?? true,
              (mapping.provider == "fe") == (dateBasis == .ownerPriorWeekdayUTC) else { throw InvestmentPriceError.invalidResponse }
        return self
    }

    func age(at now: Date) -> Int {
        InvestmentPriceDates.age(day: valuationDay, instant: valuationInstant, zone: calendarTimeZone, now: now)
    }

    /// A successful identical FE response proves retrieval, not a new valuation date.
    func retainingUndatedObservation(_ previous: Self?) -> Self {
        guard dateBasis == .ownerPriorWeekdayUTC, let previous,
              previous.mapping == mapping,
              previous.price.value == price.value || InvestmentPriceDates.isWeekend(fetchedAt) else { return self }
        return .init(mapping: mapping, price: InvestmentPriceDates.isWeekend(fetchedAt) ? previous.price : price, valuationDay: previous.valuationDay,
                     valuationText: previous.valuationText, valuationInstant: previous.valuationInstant,
                     dateBasis: previous.dateBasis, calendarTimeZone: previous.calendarTimeZone,
                     fetchedAt: fetchedAt, sourceURL: sourceURL, qualification: qualification)
    }

    func canReplace(_ previous: Self?) -> Bool {
        guard let previous else { return true }
        guard previous.mapping == mapping, fetchedAt >= previous.fetchedAt,
              valuationDay >= previous.valuationDay else { return false }
        if let old = previous.valuationInstant, let new = valuationInstant { return new >= old }
        return true
    }
}

nonisolated struct InvestmentValuation: Equatable, Sendable {
    enum CostBasis: String, Sendable { case reportedTotal = "Reported total cost", reportedAverage = "Calculated from reported average cost" }
    let quote: InvestmentQuote?
    let currentValue: Decimal?
    let supportedCost: Decimal?
    let costBasis: CostBasis?
    let gain: Decimal?
    let simpleReturn: InvestmentSimpleReturn?
    let issue: String?

    init(holding: InvestmentHolding, quote: InvestmentQuote?) {
        self.quote = quote?.mapping == holding.priceMapping && quote?.mapping.currency == holding.currency ? quote : nil
        var value: Decimal?, cost: Decimal?, basis: CostBasis?, gain: Decimal?, issue: String?
        do {
            if let quote = self.quote { value = try InvestmentArithmetic.multiply(holding.units.value, quote.price.value) }
            else { issue = holding.priceMapping == nil ? "Price mapping required" : "No successful price yet" }
        } catch { issue = "Current value out of range" }
        do {
            if holding.costCurrency == holding.currency {
                if let total = holding.totalCost { cost = total.value; basis = .reportedTotal }
                else if let average = holding.averageCost {
                    cost = try InvestmentArithmetic.multiply(holding.units.value, average.value); basis = .reportedAverage
                }
            }
        } catch { issue = "Acquisition cost out of range" }
        do { if let value, let cost { gain = try InvestmentArithmetic.subtract(value, cost) } }
        catch { issue = "Gain / loss out of range" }
        self.currentValue = value
        self.supportedCost = cost
        self.costBasis = basis
        self.gain = gain
        self.simpleReturn = if let gain, let cost, cost > 0 { InvestmentSimpleReturn(gain: gain, cost: cost) } else { nil }
        self.issue = issue
    }
}

nonisolated enum InvestmentPriceError: String, Error, LocalizedError, Sendable {
    case invalidResponse, wrongIdentity, wrongCurrency, ambiguous, unavailable, cancelled, olderResponse
    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The source returned an invalid price or date."
        case .wrongIdentity: "The response did not match the confirmed instrument or share class."
        case .wrongCurrency: "The response denomination did not match the holding."
        case .ambiguous: "The source returned more than one matching price."
        case .unavailable: "The source could not be reached. Try Refresh all again."
        case .cancelled: "Refresh was cancelled after the active holdings changed."
        case .olderResponse: "An older response was ignored; the newer cached price is retained."
        }
    }
}
