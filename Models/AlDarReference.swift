import Foundation

/// Al Dar's receive amount has more precision than ledger Money. Retain its
/// JSON token; neither Money nor a rounded display rate is its authority.
nonisolated struct AlDarReturnedINRDecimal: Equatable, Sendable {
    let rawToken: String
    let coefficient: UInt128
    let scale: Int
    let decimal: Decimal

    init(rawToken: String) throws {
        let parts = rawToken.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), !parts[0].isEmpty,
              parts[0] == "0" || parts[0].first != "0",
              parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else {
            throw AlDarReferenceError.invalidResponse
        }
        let digits = parts.joined()
        let scale = parts.count == 2 ? parts[1].count : 0
        guard digits.count <= 32, scale <= 28,
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
        guard shortfall.currency.code == "INR", shortfall.amount >= 0 else {
            throw AlDarReferenceError.invalidBinding
        }
        let s = UInt128(try shortfall.minorUnits())
        let q = UInt128(try submittedQAR.minorUnits())
        var power: UInt128 = 1
        for _ in 0..<returnedINR.scale { power *= 10 }
        let numerator = (s * q).multipliedFullWidth(by: power)
        let denominator = returnedINR.coefficient * 100
        // dividingFullWidth traps when the quotient cannot fit its type.
        guard numerator.high < denominator else { throw AlDarReferenceError.amountOutOfRange }
        let result = denominator.dividingFullWidth(numerator)
        let limit = UInt128(Int64.max)
        guard result.quotient <= limit,
              result.remainder == 0 || result.quotient < limit else { throw AlDarReferenceError.amountOutOfRange }
        let cents = result.quotient + (result.remainder == 0 ? 0 : 1)
        return try Money.fromMinorUnits(Int64(cents), currency: "QAR")
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
