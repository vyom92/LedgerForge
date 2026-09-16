import Foundation

/// Al Dar's receive amount has more precision than ledger Money. Retain its
/// JSON token; neither Money nor a rounded display rate is its authority.
nonisolated struct AlDarReturnedINRDecimal: Equatable, Sendable {
    let rawToken: String
    let coefficient: UInt128
    let scale: Int
    let decimal: Decimal

    init(rawToken: String) throws {
        try self.init(rawToken: rawToken, maximumScale: 28)
    }

    /// Preserve the existing manual-rate limit (32 canonical characters),
    /// without relaxing the public response grammar or inventing quote evidence.
    static func planningRate(_ decimal: Decimal) throws -> Self {
        let raw = NSDecimalNumber(decimal: decimal).stringValue
        guard raw.count <= 32 else { throw AlDarReferenceError.invalidResponse }
        return try Self(rawToken: raw, maximumScale: 30)
    }

    private init(rawToken: String, maximumScale: Int) throws {
        let parts = rawToken.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), !parts[0].isEmpty,
              parts[0] == "0" || parts[0].first != "0",
              parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else {
            throw AlDarReferenceError.invalidResponse
        }
        let digits = parts.joined()
        let scale = parts.count == 2 ? parts[1].count : 0
        guard digits.count <= 32, scale <= maximumScale,
              let coefficient = UInt128(digits), coefficient > 0,
              let decimal = Decimal(string: rawToken, locale: Locale(identifier: "en_US_POSIX")),
              !decimal.isNaN, decimal > 0 else { throw AlDarReferenceError.invalidResponse }
        self.rawToken = rawToken
        self.coefficient = coefficient
        self.scale = scale
        self.decimal = decimal
    }

    static func parseResponse(_ data: Data) throws -> Self {
        guard data.count <= 128, let text = String(data: data, encoding: .utf8) else {
            throw AlDarReferenceError.invalidResponse
        }
        return try Self(rawToken: text.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n")))
    }

    /// Positive receive estimate: exact integer ratio, rounded half up only at
    /// the final INR cent (Money's .plain presentation convention).
    func receiveEstimate(forQAR principal: Money) throws -> Money {
        guard principal.currency.code == "QAR", principal.amount >= 0 else { throw AlDarReferenceError.invalidBinding }
        var power: UInt128 = 1
        for _ in 0..<scale { power *= 10 }
        let numerator = UInt128(try principal.minorUnits()).multipliedFullWidth(by: coefficient)
        guard numerator.high < power else { throw AlDarReferenceError.amountOutOfRange }
        let result = power.dividingFullWidth(numerator)
        let increment: UInt128 = result.remainder >= (power + 1) / 2 ? 1 : 0
        guard result.quotient <= UInt128(Int64.max) - increment else { throw AlDarReferenceError.amountOutOfRange }
        let rounded = result.quotient + increment
        return try Money.fromMinorUnits(Int64(rounded), currency: "INR")
    }

    func principal(for shortfall: Money, submittedQAR: Money) throws -> Money {
        guard shortfall.currency.code == "INR", shortfall.amount >= 0,
              submittedQAR.currency.code == "QAR", submittedQAR.amount > 0 else { throw AlDarReferenceError.invalidBinding }
        let s = UInt128(try shortfall.minorUnits()), q = UInt128(try submittedQAR.minorUnits())
        var power: UInt128 = 1
        for _ in 0..<scale { power *= 10 }
        let numerator = (s * q).multipliedFullWidth(by: power)
        let denominator = coefficient * 100
        guard numerator.high < denominator else { throw AlDarReferenceError.amountOutOfRange }
        let result = denominator.dividingFullWidth(numerator)
        let limit = UInt128(Int64.max)
        guard result.quotient <= limit, result.remainder == 0 || result.quotient < limit else { throw AlDarReferenceError.amountOutOfRange }
        return try Money.fromMinorUnits(Int64(result.quotient + (result.remainder == 0 ? 0 : 1)), currency: "QAR")
    }
}

nonisolated enum AlDarReferenceError: Error, Equatable {
    case invalidResponse, unavailable, invalidBinding, amountOutOfRange
}

nonisolated struct AlDarReferenceQuote: Equatable, Sendable {
    let submittedQAR: Money
    let returnedINR: AlDarReturnedINRDecimal
    let fetchedAtISO: String

    init(submittedQAR: Money, returnedINR: AlDarReturnedINRDecimal, fetchedAtISO: String) throws {
        let formatter = ISO8601DateFormatter()
        guard submittedQAR.currency.code == "QAR", submittedQAR.amount > 0,
              let instant = formatter.date(from: fetchedAtISO), formatter.string(from: instant) == fetchedAtISO else {
            throw AlDarReferenceError.invalidBinding
        }
        self.submittedQAR = submittedQAR
        self.returnedINR = returnedINR
        self.fetchedAtISO = fetchedAtISO
    }

    /// Exact ratio, rounded upward only at the final QAR cent. The bounded
    /// raw decimal and Int64 Money make a UInt256 numerator sufficient.
    func principal(for shortfall: Money) throws -> Money {
        try returnedINR.principal(for: shortfall, submittedQAR: submittedQAR)
    }

    /// Presentation only. Calculations always use principal(for:).
    var displayRate: String {
        var rate = returnedINR.decimal / submittedQAR.amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &rate, 2, .plain)
        return rounded.formatted(.number.locale(Locale(identifier: "en_US_POSIX"))
            .grouping(.never).precision(.fractionLength(2)))
    }

    var fetchedAt: Date { ISO8601DateFormatter().date(from: fetchedAtISO)! }
}

nonisolated struct AlDarReferenceEvidence: Equatable, Sendable {
    let quote: AlDarReferenceQuote
    let boundShortfallINR: Money

    init(quote: AlDarReferenceQuote, boundShortfallINR: Money) throws {
        guard boundShortfallINR.currency.code == "INR", boundShortfallINR.amount > 0 else {
            throw AlDarReferenceError.invalidBinding
        }
        _ = try quote.principal(for: boundShortfallINR)
        self.quote = quote
        self.boundShortfallINR = boundShortfallINR
    }
}

nonisolated enum AlDarCurrency: String, CaseIterable, Codable, Sendable { case inr = "INR", usd = "USD" }

/// Display age uses elapsed time between absolute instants. Local time zones
/// and calendar-day boundaries do not participate in rates or financial math.
nonisolated struct AlDarReferenceAge: Equatable, Sendable {
    let seconds: TimeInterval
    init(fetchedAt: Date, now: Date) { seconds = max(0, now.timeIntervalSince(fetchedAt)) }

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
        if seconds <= 86_400 { return seconds / 86_400 }
        return min(2, 1 + (seconds - 86_400) / (3 * 86_400))
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
