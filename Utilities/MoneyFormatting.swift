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
