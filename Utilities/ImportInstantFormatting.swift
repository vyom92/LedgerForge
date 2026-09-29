import Foundation

/// Owner-selected import-event policy: this Mac's localized date/time with the
/// instant's explicit UTC offset. Financial civil dates never enter this helper.
nonisolated enum ImportInstantFormatting {
    static func display(_ value: String?) -> String {
        AppDateDisplay.isoTimestamp(value)
    }
}

/// Display only. Canonical storage and source-owned civil dates stay unchanged.
nonisolated enum AppDateDisplay {
    static func civil(_ value: String?) -> String {
        value.flatMap { try? StatementDate(canonical: $0) }?.presentation ?? "Date unavailable"
    }

    static func month(_ value: String?) -> String {
        guard let value, let month = try? SelectedStatementMonth(canonical: value) else { return "Month unavailable" }
        return String((try! StatementDate(year: month.year, month: month.month, day: 1)).presentation.dropFirst(3))
    }

    static func date(_ value: Date, zone: TimeZone = .current) -> String {
        formatter(zone: zone, includeTime: false).string(from: value)
    }

    static func isoTimestamp(_ value: String?, zone: TimeZone = .current) -> String {
        guard let value else { return "Time unavailable" }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let instant = fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value) else {
            return "Time unavailable"
        }
        return timestamp(instant, zone: zone)
    }

    static func timestamp(_ instant: Date, zone: TimeZone = .current) -> String {
        let offset = zone.secondsFromGMT(for: instant)
        let hours = abs(offset) / 3600
        let minutes = abs(offset) % 3600 / 60
        let offsetLabel = String(format: "UTC%@%02d:%02d", offset < 0 ? "−" : "+", hours, minutes)
        return "\(formatter(zone: zone, includeTime: true).string(from: instant)) · \(offsetLabel)"
    }

    private static func formatter(zone: TimeZone, includeTime: Bool) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = zone
        formatter.dateFormat = includeTime ? "dd MMM yy, HH:mm" : "dd MMM yy"
        return formatter
    }
}
