import Foundation

enum MoneyError: Error, Equatable, LocalizedError {
    case malformedCurrencyCode
    case unsupportedCurrency(String)
    case excessPrecision(currency: String)
    case minorUnitOverflow(currency: String)
    case malformedCanonicalDecimal(currency: String)
    case currencyMismatch(expected: String, actual: String)
    case emptyAggregation

    var errorDescription: String? {
        switch self {
        case .malformedCurrencyCode:
            return "Currency codes must contain exactly three ASCII letters."
        case .unsupportedCurrency:
            return "The currency is not supported by the local catalog."
        case .excessPrecision:
            return "The amount cannot be represented exactly at the catalog scale."
        case .minorUnitOverflow:
            return "The amount exceeds the supported minor-unit range."
        case .malformedCanonicalDecimal:
            return "The persisted decimal value is not canonical."
        case .currencyMismatch:
            return "Money values must use the same currency."
        case .emptyAggregation:
            return "Money aggregation requires at least one value."
        }
    }
}

struct CurrencyCode: RawRepresentable, Hashable, Codable, Sendable, Comparable {
    let rawValue: String

    init(_ rawValue: String) throws {
        let normalized = rawValue.uppercased()
        guard normalized.count == 3,
              normalized.unicodeScalars.allSatisfy({ (65...90).contains($0.value) }) else {
            throw MoneyError.malformedCurrencyCode
        }
        self.rawValue = normalized
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    var code: String { rawValue }

    static func < (lhs: CurrencyCode, rhs: CurrencyCode) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct CurrencyDefinition: Hashable, Sendable {
    let code: CurrencyCode
    let fractionDigits: Int
}

struct CurrencyCatalog: Sendable {
    static let version = "ledgerforge.currency-catalog.v1"
    static let shared = CurrencyCatalog()

    private let definitionsByCode: [CurrencyCode: CurrencyDefinition]

    init(definitions: [CurrencyDefinition] = CurrencyCatalog.defaultDefinitions) {
        definitionsByCode = Dictionary(uniqueKeysWithValues: definitions.map { ($0.code, $0) })
    }

    func definition(for rawCode: String) throws -> CurrencyDefinition {
        try definition(for: CurrencyCode(rawCode))
    }

    func definition(for code: CurrencyCode) throws -> CurrencyDefinition {
        guard let definition = definitionsByCode[code] else {
            throw MoneyError.unsupportedCurrency(code.code)
        }
        return definition
    }

    var definitions: [CurrencyDefinition] {
        definitionsByCode.values.sorted { $0.code < $1.code }
    }

    private static let defaultDefinitions: [CurrencyDefinition] = [
        definition("AED", 2), definition("BRL", 2), definition("IDR", 2),
        definition("INR", 2), definition("KRW", 0), definition("KWD", 3),
        definition("MYR", 2), definition("NZD", 2), definition("QAR", 2),
        definition("USD", 2)
    ]

    private static func definition(_ code: String, _ fractionDigits: Int) -> CurrencyDefinition {
        CurrencyDefinition(code: try! CurrencyCode(code), fractionDigits: fractionDigits)
    }
}

struct Money: Hashable, Sendable, Codable {
    let amount: Decimal
    let currency: CurrencyCode

    init(amount: Decimal, currency rawCurrency: String, catalog: CurrencyCatalog = .shared) throws {
        try self.init(amount: amount, currency: CurrencyCode(rawCurrency), catalog: catalog)
    }

    init(amount: Decimal, currency: CurrencyCode, catalog: CurrencyCatalog = .shared) throws {
        _ = try catalog.definition(for: currency)
        self.currency = currency
        self.amount = amount == .zero ? .zero : amount
        _ = try minorUnits(catalog: catalog)
    }

    init(canonicalDecimal: String, currency rawCurrency: String, catalog: CurrencyCatalog = .shared) throws {
        let currency = try CurrencyCode(rawCurrency)
        let definition = try catalog.definition(for: currency)
        guard Self.isCanonical(canonicalDecimal, fractionDigits: definition.fractionDigits),
              let amount = Decimal(string: canonicalDecimal, locale: Locale(identifier: "en_US_POSIX")),
              !(canonicalDecimal.hasPrefix("-") && amount == .zero) else {
            throw MoneyError.malformedCanonicalDecimal(currency: currency.code)
        }
        try self.init(amount: amount, currency: currency, catalog: catalog)
    }

    func canonicalDecimalString(catalog: CurrencyCatalog = .shared) throws -> String {
        let definition = try catalog.definition(for: currency)
        return try Self.canonicalDecimalString(minorUnits: minorUnits(catalog: catalog), fractionDigits: definition.fractionDigits)
    }

    func minorUnits(catalog: CurrencyCatalog = .shared) throws -> Int64 {
        let definition = try catalog.definition(for: currency)
        var multiplier = Decimal(1)
        for _ in 0..<definition.fractionDigits { multiplier *= 10 }
        let scaled = amount * multiplier
        var mutableScaled = scaled
        var rounded = Decimal()
        NSDecimalRound(&rounded, &mutableScaled, 0, .plain)
        guard rounded == scaled else {
            throw MoneyError.excessPrecision(currency: currency.code)
        }
        guard let value = Int64(NSDecimalNumber(decimal: rounded).stringValue) else {
            throw MoneyError.minorUnitOverflow(currency: currency.code)
        }
        return value
    }

    static func fromMinorUnits(_ minorUnits: Int64, currency rawCurrency: String, catalog: CurrencyCatalog = .shared) throws -> Money {
        let currency = try CurrencyCode(rawCurrency)
        let definition = try catalog.definition(for: currency)
        var divisor = Decimal(1)
        for _ in 0..<definition.fractionDigits { divisor *= 10 }
        return try Money(amount: Decimal(minorUnits) / divisor, currency: currency, catalog: catalog)
    }

    static func + (lhs: Money, rhs: Money) throws -> Money {
        guard lhs.currency == rhs.currency else {
            throw MoneyError.currencyMismatch(expected: lhs.currency.code, actual: rhs.currency.code)
        }
        return try Money(amount: lhs.amount + rhs.amount, currency: lhs.currency)
    }

    static func - (lhs: Money, rhs: Money) throws -> Money {
        guard lhs.currency == rhs.currency else {
            throw MoneyError.currencyMismatch(expected: lhs.currency.code, actual: rhs.currency.code)
        }
        return try Money(amount: lhs.amount - rhs.amount, currency: lhs.currency)
    }

    static prefix func - (value: Money) throws -> Money {
        try Money(amount: -value.amount, currency: value.currency)
    }

    func compared(to other: Money) throws -> ComparisonResult {
        guard currency == other.currency else {
            throw MoneyError.currencyMismatch(expected: currency.code, actual: other.currency.code)
        }
        if amount == other.amount { return .orderedSame }
        return amount < other.amount ? .orderedAscending : .orderedDescending
    }

    static func aggregate(_ values: [Money]) throws -> Money {
        guard let first = values.first else { throw MoneyError.emptyAggregation }
        return try values.dropFirst().reduce(first) { try $0 + $1 }
    }

    private enum CodingKeys: String, CodingKey { case amount, currency }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let amount = try container.decode(String.self, forKey: .amount)
        let currency = try container.decode(String.self, forKey: .currency)
        try self.init(canonicalDecimal: amount, currency: currency)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(canonicalDecimalString(), forKey: .amount)
        try container.encode(currency.code, forKey: .currency)
    }

    private static func isCanonical(_ value: String, fractionDigits: Int) -> Bool {
        let integer = "(?:0|[1-9][0-9]*)"
        let pattern: String
        if fractionDigits == 0 {
            pattern = "^-?\(integer)$"
        } else {
            pattern = "^-?\(integer)\\.[0-9]{\(fractionDigits)}$"
        }
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func canonicalDecimalString(minorUnits: Int64, fractionDigits: Int) throws -> String {
        let source = String(minorUnits)
        let isNegative = source.hasPrefix("-")
        let magnitude = isNegative ? String(source.dropFirst()) : source
        guard fractionDigits > 0 else { return source }
        let padded = String(repeating: "0", count: max(0, fractionDigits + 1 - magnitude.count)) + magnitude
        let splitIndex = padded.index(padded.endIndex, offsetBy: -fractionDigits)
        let sign = isNegative ? "-" : ""
        return sign + padded[..<splitIndex] + "." + padded[splitIndex...]
    }
}
