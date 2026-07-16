import Foundation

enum MoneyFormatting {
    static func display(_ money: Money, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        let fractionDigits = (try? CurrencyCatalog.shared.definition(for: money.currency).fractionDigits) ?? 2
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        let number = formatter.string(from: NSDecimalNumber(decimal: money.amount)) ?? money.amount.description
        return "\(money.currency.code) \(number)"
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
