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
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = money.currency.code
        switch money.currency.code {
        case "USD": formatter.currencySymbol = "$"
        case "INR": formatter.currencySymbol = "₹"
        case "QAR": formatter.currencySymbol = "QR"
        default: break
        }
        if ["INR", "USD", "QAR"].contains(money.currency.code) {
            formatter.usesGroupingSeparator = true
            formatter.groupingSeparator = ","
            formatter.currencyGroupingSeparator = ","
            formatter.groupingSize = 3
            formatter.secondaryGroupingSize = money.currency.code == "INR" ? 2 : 3
        }
        formatter.minimumFractionDigits = displayFractionDigits
        formatter.maximumFractionDigits = displayFractionDigits
        formatter.roundingMode = .halfUp
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
