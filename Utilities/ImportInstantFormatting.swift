import Foundation

/// Owner-selected import-event policy: this Mac's localized date/time with the
/// instant's explicit UTC offset. Financial civil dates never enter this helper.
nonisolated enum ImportInstantFormatting {
    static func display(_ value: String?) -> String {
        guard let value else { return "Time unavailable" }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let instant = fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value) else {
            return "Time unavailable"
        }
        let zone = TimeZone.current
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = zone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let offset = zone.secondsFromGMT(for: instant)
        let hours = abs(offset) / 3600
        let minutes = abs(offset) % 3600 / 60
        let offsetLabel = String(format: "UTC%@%02d:%02d", offset < 0 ? "−" : "+", hours, minutes)
        return "\(formatter.string(from: instant)) · \(offsetLabel)"
    }
}
