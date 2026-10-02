import Foundation

enum MoneyFormatting {
    nonisolated static let displayFractionDigits = 0
    /// NAV/unit prices retain the provider token's full precision. Whole-unit
    /// money display must never turn a small per-unit price into zero.
    nonisolated static func unitPrice(_ token: String, currency: String) -> String {
        switch currency {
        case "USD": "$" + token
        case "INR": "₹" + token
        case "QAR": "QR\u{00a0}" + token
        default: currency + " " + token
        }
    }
    nonisolated static func display(_ money: Money, locale: Locale = .current) -> String {
        display(money, formatter: formatter(for: money.currency, locale: locale))
    }

    /// For a total whose surrounding label already names its currency.
    nonisolated static func number(_ money: Money, locale: Locale = .current) -> String {
        let numberFormatter = formatter(for: money.currency, locale: locale)
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = displayFractionDigits
        numberFormatter.maximumFractionDigits = displayFractionDigits
        numberFormatter.groupingSeparator = ","
        numberFormatter.groupingSize = 3
        numberFormatter.secondaryGroupingSize = money.currency.code == "INR" ? 2 : 3
        return display(money, formatter: numberFormatter)
    }

    /// Spoken presentation of the same decimal rounding used by the visible
    /// amount. No localized-string parsing or floating-point conversion.
    nonisolated static func amountInWords(_ money: Money, fractionDigits: Int = displayFractionDigits) -> String? {
        guard ["INR", "QAR", "USD"].contains(money.currency.code), (0...2).contains(fractionDigits) else { return nil }
        var amount = money.amount, rounded = Decimal()
        NSDecimalRound(&rounded, &amount, fractionDigits, .plain)
        let token = NSDecimalNumber(decimal: abs(rounded)).stringValue
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard let first = parts.first, let whole = UInt64(first) else { return nil }
        let small = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
        let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
        let scales: [(UInt64, String)] = money.currency.code == "INR"
            ? [(10_000_000, "crore"), (100_000, "lakh"), (1_000, "thousand"), (100, "hundred")]
            : [(1_000_000_000_000_000_000, "quintillion"), (1_000_000_000_000_000, "quadrillion"),
               (1_000_000_000_000, "trillion"), (1_000_000_000, "billion"), (1_000_000, "million"),
               (1_000, "thousand"), (100, "hundred")]
        func words(_ value: UInt64) -> String {
            for (unit, name) in scales where value >= unit {
                return words(value / unit) + " " + name + (value % unit == 0 ? "" : " " + words(value % unit))
            }
            if value < 20 { return small[Int(value)] }
            return tens[Int(value / 10)] + (value % 10 == 0 ? "" : "-" + small[Int(value % 10)])
        }
        var result = (rounded < 0 ? "minus " : "") + words(whole)
        if fractionDigits > 0, parts.count == 2, parts[1].contains(where: { $0 != "0" }) {
            let fraction = String(parts[1]).padding(toLength: fractionDigits, withPad: "0", startingAt: 0)
            guard fraction.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            result += " point " + fraction.compactMap(\.wholeNumberValue).map { small[$0] }.joined(separator: " ")
        }
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    /// One call owns its formatters; none are shared across tasks or actors.
    /// Used for native column measurement over a canonical row snapshot.
    nonisolated static func display(_ values: [Money], locale: Locale = .current) -> [String] {
        var formatters: [CurrencyCode: NumberFormatter] = [:]
        return values.map { money in
            let numberFormatter = formatters[money.currency] ?? formatter(for: money.currency, locale: locale)
            formatters[money.currency] = numberFormatter
            return display(money, formatter: numberFormatter)
        }
    }

    nonisolated private static func formatter(for currency: CurrencyCode, locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        switch currency.code {
        case "USD": formatter.currencySymbol = "$"
        case "INR": formatter.currencySymbol = "₹"
        case "QAR": formatter.currencySymbol = "QR"
        default: break
        }
        if ["INR", "USD", "QAR"].contains(currency.code) {
            formatter.usesGroupingSeparator = true
            formatter.groupingSeparator = ","
            formatter.currencyGroupingSeparator = ","
            formatter.groupingSize = 3
            formatter.secondaryGroupingSize = currency.code == "INR" ? 2 : 3
        }
        formatter.minimumFractionDigits = displayFractionDigits
        formatter.maximumFractionDigits = displayFractionDigits
        formatter.roundingMode = .halfUp
        return formatter
    }

    nonisolated private static func display(_ money: Money, formatter: NumberFormatter) -> String {
        var source = money.amount, rounded = Decimal()
        NSDecimalRound(&rounded, &source, displayFractionDigits, .plain)
        if rounded == 0 { rounded = .zero }
        return formatter.string(from: NSDecimalNumber(decimal: rounded)) ?? "\(money.currency.code) \(rounded)"
    }

    static func accessibility(_ money: Money, locale: Locale = .current) -> String {
        display(money, locale: locale)
    }

    static func signedDisplay(_ money: Money, isCredit: Bool, locale: Locale = .current) -> String {
        let prefix = isCredit ? "+" : "-"
        let magnitude = try! Money(amount: abs(money.amount), currency: money.currency)
        return prefix + display(magnitude, locale: locale)
    }
}
