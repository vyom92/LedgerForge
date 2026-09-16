import Foundation

/// Editor-only lexical adapter. Money's canonical persistence contract is unchanged.
enum PlannerInputCodec {
    enum InputError: Error { case invalid }

    private static func normalized(_ text: String, locale: Locale, fractionLimit: Int) throws -> String {
        let separator = locale.decimalSeparator ?? "."
        guard [".", ",", "٫"].contains(separator), text.utf8.count <= 80 else { throw InputError.invalid }
        let escaped = NSRegularExpression.escapedPattern(for: separator)
        guard text.range(of: "^-?[0-9]+(?:" + escaped + "[0-9]{1," + String(fractionLimit) + "})?\\z", options: .regularExpression) != nil else { throw InputError.invalid }
        return text.replacingOccurrences(of: separator, with: ".")
    }

    static func money(_ text: String, currency: String, locale: Locale) throws -> Money {
        guard ["QAR", "INR"].contains(currency) else { throw InputError.invalid }
        let normalized = try normalized(text, locale: locale, fractionLimit: 2)
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        return try Money(canonicalDecimal: String(parts[0]) + "." + fraction.padding(toLength: 2, withPad: "0", startingAt: 0), currency: currency)
    }

    static func rate(_ text: String, locale: Locale) throws -> Decimal {
        let normalized = try normalized(text, locale: locale, fractionLimit: 28)
        // Decimal supports at least 38 significant digits. Bound before parsing so no rounding can occur.
        guard normalized.count <= 32, let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), value > 0 else { throw InputError.invalid }
        return value
    }

    /// Exact entry feedback, using Indian number names without a Double bridge.
    /// Invalid/unfinished text has no spoken value; it never reuses an older edit.
    static func amountInWords(_ text: String, currency: String, locale: Locale) -> String? {
        guard let amount = try? money(text, currency: currency, locale: locale),
              let minor = try? amount.minorUnits() else { return nil }
        let small = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
        let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
        let scales: [(UInt64, String)] = [(10_000_000, "crore"), (100_000, "lakh"), (1_000, "thousand"), (100, "hundred")]
        func words(_ value: UInt64) -> String {
            for (unit, name) in scales {
                if value >= unit { return words(value / unit) + " " + name + (value % unit == 0 ? "" : " " + words(value % unit)) }
            }
            if value < 20 { return small[Int(value)] }
            return tens[Int(value / 10)] + (value % 10 == 0 ? "" : "-" + small[Int(value % 10)])
        }
        let magnitude = minor.magnitude
        var result = (minor < 0 ? "minus " : "") + words(magnitude / 100)
        if magnitude % 100 != 0 {
            result += " point " + small[Int(magnitude % 100 / 10)] + " " + small[Int(magnitude % 10)]
        }
        return result.prefix(1).uppercased() + result.dropFirst()
    }
}
