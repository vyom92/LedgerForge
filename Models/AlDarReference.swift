import Foundation

/// Al Dar's receive amount has more precision than ledger Money. Retain its
/// JSON token; neither Money nor a rounded display rate is its authority.

nonisolated enum AlDarCurrency: String, CaseIterable, Codable, Sendable { case inr = "INR", usd = "USD" }

/// Display age uses elapsed time between absolute instants. Local time zones
/// and calendar-day boundaries do not participate in rates or financial math.
nonisolated struct AlDarReferenceAge: Equatable, Sendable {
    let seconds: TimeInterval
    let freshnessSeconds: TimeInterval
    init(fetchedAt: Date, now: Date) {
        seconds = max(0, now.timeIntervalSince(fetchedAt))
        freshnessSeconds = WeekdayFreshness.seconds(from: fetchedAt, to: now)
    }

    var caption: String {
        if seconds < 60 { return "Fetched just now" }
        if seconds < 3_600 {
            let minutes = Int(seconds / 60)
            return "Fetched \(minutes) \(minutes == 1 ? "min" : "mins") ago"
        }
        if seconds < 86_400 {
            let hours = Int(seconds / 3_600)
            return "Fetched \(hours) \(hours == 1 ? "hour" : "hours") ago"
        }
        let days = Int(seconds / 86_400)
        return "Fetched \(days) \(days == 1 ? "day" : "days") ago"
    }

    /// Continuous scale: green=0, yellow=1 (24h), red=2 (four days).
    var colorPosition: Double {
        WeekdayFreshness.colorPosition(days: freshnessSeconds / 86_400)
    }
}

/// One direct QAR-1 public observation. Fetch time is never provider market time.
nonisolated struct AlDarUnitReference: Equatable, Sendable {
    let currency: AlDarCurrency
    let returned: AlDarReturnedINRDecimal
    let fetchedAtISO: String
    var fetchedAt: Date { ISO8601DateFormatter().date(from: fetchedAtISO)! }

    init(currency: AlDarCurrency, rawToken: String, fetchedAtISO: String) throws {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: fetchedAtISO), formatter.string(from: date) == fetchedAtISO else { throw AlDarReferenceError.invalidBinding }
        self.currency = currency; returned = try AlDarReturnedINRDecimal(rawToken: rawToken)
        self.fetchedAtISO = fetchedAtISO
    }

    func planningQuote() throws -> AlDarReferenceQuote {
        guard currency == .inr else { throw AlDarReferenceError.invalidBinding }
        return try AlDarReferenceQuote(submittedQAR: Money(canonicalDecimal: "1.00", currency: "QAR"), returnedINR: returned, fetchedAtISO: fetchedAtISO)
    }
}

nonisolated enum AlDarPair: String, CaseIterable, Sendable {
    case qarINR, inrQAR, qarUSD, usdQAR, usdINR, inrUSD
    var currencies: (String, String) {
        switch self {
        case .qarINR: ("QAR", "INR")
        case .inrQAR: ("INR", "QAR")
        case .qarUSD: ("QAR", "USD")
        case .usdQAR: ("USD", "QAR")
        case .usdINR: ("USD", "INR")
        case .inrUSD: ("INR", "USD")
        }
    }
    var inverse: Self {
        switch self {
        case .qarINR: .inrQAR; case .inrQAR: .qarINR
        case .qarUSD: .usdQAR; case .usdQAR: .qarUSD
        case .usdINR: .inrUSD; case .inrUSD: .usdINR
        }
    }
    var dependencies: [AlDarCurrency] {
        switch self { case .qarINR, .inrQAR: [.inr]; case .qarUSD, .usdQAR: [.usd]; case .usdINR, .inrUSD: [.inr, .usd] }
    }
    func displayedRate(_ legs: [AlDarCurrency: AlDarUnitReference]) -> String? {
        guard dependencies.allSatisfy({ legs[$0] != nil }) else { return nil }
        let i = legs[.inr]?.returned.decimal ?? 0, u = legs[.usd]?.returned.decimal ?? 0
        // Decimal precision is presentation only. Financial principal and
        // receive estimates use the raw integer-ratio methods above.
        var numerator: Decimal, denominator: Decimal
        switch self {
        case .qarINR: numerator = i; denominator = 1
        case .inrQAR: numerator = 1; denominator = i
        case .qarUSD: numerator = u; denominator = 1
        case .usdQAR: numerator = 1; denominator = u
        case .usdINR: numerator = i; denominator = u
        case .inrUSD: numerator = u; denominator = i
        }
        var ratio = Decimal(), rounded = Decimal()
        let error = NSDecimalDivide(&ratio, &numerator, &denominator, .plain)
        guard error == .noError || error == .lossOfPrecision, !ratio.isNaN else { return nil }
        NSDecimalRound(&rounded, &ratio, 2, .plain)
        return rounded.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never).precision(.fractionLength(2)))
    }
}
