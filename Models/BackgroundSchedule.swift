import Foundation

/// Durable, non-financial background work identity. A value names one of the
/// owner-approved update paths; it is not a generic task framework.
nonisolated enum BackgroundJobKind: String, Codable, CaseIterable, Sendable {
    case publicReferences = "public_references"
    case gmailCollection = "gmail_collection"
    case zurichISP = "zurich_isp"
    case ibkrFlex = "ibkr_flex"
}

nonisolated struct BackgroundScheduleConfiguration: Codable, Equatable, Sendable {
    static let allWeekdays = Set(1...7)
    static let defaultPublicRule = BackgroundScheduleRule.selectedWeekdays(weekdays: allWeekdays, timesUTC: [0, 6 * 60, 12 * 60, 18 * 60])
    static let defaultGmailRule = BackgroundScheduleRule.selectedWeekdays(weekdays: allWeekdays, timesUTC: [0])
    static let defaultISPRule = BackgroundScheduleRule.monthly(daysUTC: [1], timesUTC: [0])
    static let defaultIBKRRule = BackgroundScheduleRule.selectedWeekdays(weekdays: [2], timesUTC: [6 * 60])
    var ibkrFlexHoldingsEnabled = false
    var ibkrFlexRule: BackgroundScheduleRule = Self.defaultIBKRRule
    var enabled: Bool
    var alDarCurrencyRatesEnabled: Bool
    var investmentPublicPricesEnabled: Bool
    var gmailCollectionEnabled: Bool
    var zurichISPHoldingsEnabled: Bool
    var publicReferencesRule: BackgroundScheduleRule
    var gmailRule: BackgroundScheduleRule
    var zurichISPRule: BackgroundScheduleRule

    init(enabled: Bool = false, alDarCurrencyRatesEnabled: Bool = true, investmentPublicPricesEnabled: Bool = true,
         gmailCollectionEnabled: Bool = true, zurichISPHoldingsEnabled: Bool = true,
         publicReferencesRule: BackgroundScheduleRule = Self.defaultPublicRule,
         gmailRule: BackgroundScheduleRule = Self.defaultGmailRule,
         zurichISPRule: BackgroundScheduleRule = Self.defaultISPRule) {
        self.enabled = enabled
        self.alDarCurrencyRatesEnabled = alDarCurrencyRatesEnabled
        self.investmentPublicPricesEnabled = investmentPublicPricesEnabled
        self.gmailCollectionEnabled = gmailCollectionEnabled
        self.zurichISPHoldingsEnabled = zurichISPHoldingsEnabled
        self.publicReferencesRule = publicReferencesRule
        self.gmailRule = gmailRule
        self.zurichISPRule = zurichISPRule
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, alDarCurrencyRatesEnabled, investmentPublicPricesEnabled, gmailCollectionEnabled,
             zurichISPHoldingsEnabled, publicReferencesRule, gmailRule, zurichISPRule,
             ibkrFlexHoldingsEnabled, ibkrFlexRule
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decode(Bool.self, forKey: .enabled)
        alDarCurrencyRatesEnabled = try values.decode(Bool.self, forKey: .alDarCurrencyRatesEnabled)
        investmentPublicPricesEnabled = try values.decode(Bool.self, forKey: .investmentPublicPricesEnabled)
        gmailCollectionEnabled = try values.decode(Bool.self, forKey: .gmailCollectionEnabled)
        zurichISPHoldingsEnabled = try values.decode(Bool.self, forKey: .zurichISPHoldingsEnabled)
        publicReferencesRule = try values.decode(BackgroundScheduleRule.self, forKey: .publicReferencesRule)
        gmailRule = try values.decode(BackgroundScheduleRule.self, forKey: .gmailRule)
        zurichISPRule = try values.decode(BackgroundScheduleRule.self, forKey: .zurichISPRule)
        ibkrFlexHoldingsEnabled = try values.decodeIfPresent(Bool.self, forKey: .ibkrFlexHoldingsEnabled) ?? false
        ibkrFlexRule = try values.decodeIfPresent(BackgroundScheduleRule.self, forKey: .ibkrFlexRule) ?? Self.defaultIBKRRule
    }

    func validated() throws -> Self {
        try publicReferencesRule.validated()
        try gmailRule.validated()
        try zurichISPRule.validated()
        try ibkrFlexRule.validated()
        return self
    }
}

/// Settings choose one UTC cadence per clock group. Monthly selection does not
/// have a hidden weekday filter; short months clamp day 29–31 to their end.
nonisolated enum BackgroundScheduleRule: Codable, Equatable, Sendable {
    case selectedWeekdays(weekdays: Set<Int>, timesUTC: [Int])
    case monthly(daysUTC: [Int], timesUTC: [Int])

    func validated() throws {
        let times: [Int]
        switch self {
        case let .selectedWeekdays(weekdays, values):
            guard !weekdays.isEmpty, weekdays.allSatisfy({ (1...7).contains($0) }) else { throw BackgroundScheduleError.invalidConfiguration }
            times = values
        case let .monthly(days, values):
            guard !days.isEmpty, days == days.sorted(), Set(days).count == days.count,
                  days.allSatisfy({ (1...31).contains($0) }) else { throw BackgroundScheduleError.invalidConfiguration }
            times = values
        }
        guard !times.isEmpty, times == times.sorted(), Set(times).count == times.count,
              times.allSatisfy({ (0..<24 * 60).contains($0) }) else { throw BackgroundScheduleError.invalidConfiguration }
    }
}

nonisolated enum BackgroundScheduleError: Error, Equatable, Sendable {
    case invalidConfiguration
    case invalidInterval
}

/// Sanitized durable completion state. It intentionally carries neither
/// financial data nor provider response detail; the cache, Gmail receipt, or
/// holdings transaction remains the source of truth for a completed job.
nonisolated enum BackgroundJobCompletion: String, Codable, Equatable, Sendable {
    case installedCache
    case collectedNativeReceipts
    case committedCurrentHoldings
    case retryPending
    case failedFinal
    case refusedNoCoverage
    case refusedCredentialInteraction
}

/// Pure UTC slot arithmetic shared by launch, manual, and helper callers.
/// It intentionally has no timer, persistence, or foreground-session state.
nonisolated enum BackgroundSchedule {
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func publicSlot(at date: Date) -> Date {
        latestOccurrence(of: BackgroundScheduleConfiguration.defaultPublicRule, at: date)!
    }

    static func publicSlot(at date: Date, minutesUTC: [Int]) -> Date {
        latestOccurrence(of: .selectedWeekdays(weekdays: BackgroundScheduleConfiguration.allWeekdays, timesUTC: minutesUTC), at: date) ?? publicSlot(at: date)
    }

    static func nextPublicSlot(after date: Date) -> Date {
        nextOccurrence(of: BackgroundScheduleConfiguration.defaultPublicRule, after: date)!
    }

    static func nextPublicSlot(after date: Date, minutesUTC: [Int]) -> Date {
        nextOccurrence(of: .selectedWeekdays(weekdays: BackgroundScheduleConfiguration.allWeekdays, timesUTC: minutesUTC), after: date) ?? nextPublicSlot(after: date)
    }

    /// A missed public slot becomes one current catch-up unless the next exact
    /// slot is within the settled inclusive one-hour deferral window.
    static func publicOpportunity(now: Date, lastCovered: Date?) -> Date? {
        publicOpportunity(now: now, lastCovered: lastCovered, rule: BackgroundScheduleConfiguration.defaultPublicRule)
    }

    static func publicOpportunity(now: Date, lastCovered: Date?, minutesUTC: [Int]) -> Date? {
        publicOpportunity(now: now, lastCovered: lastCovered, rule: .selectedWeekdays(weekdays: BackgroundScheduleConfiguration.allWeekdays, timesUTC: minutesUTC))
    }

    static func publicOpportunity(now: Date, lastCovered: Date?, rule: BackgroundScheduleRule, scheduledTarget: Date? = nil) -> Date? {
        guard (try? rule.validated()) != nil,
              let current = latestOccurrence(of: rule, at: now), let next = nextOccurrence(of: rule, after: now) else { return nil }
        guard lastCovered.map({ $0 < current }) ?? true else { return nil }
        // A configured slot is a real opportunity even when adjacent slots are
        // close together. Timers carry their absolute target so normal callback
        // latency cannot turn every dense schedule into another deferral.
        if now == current || scheduledTarget == current { return now }
        return next.timeIntervalSince(now) <= 60 * 60 ? next : now
    }

    static func daily(hourUTC: Int, minuteUTC: Int = 0, after date: Date) throws -> Date {
        guard (0...23).contains(hourUTC), (0...59).contains(minuteUTC) else { throw BackgroundScheduleError.invalidConfiguration }
        let day = utcCalendar.startOfDay(for: date)
        let candidate = utcCalendar.date(byAdding: .minute, value: hourUTC * 60 + minuteUTC, to: day)!
        return candidate > date ? candidate : utcCalendar.date(byAdding: .day, value: 1, to: candidate)!
    }

    /// Day 29–31 clamps to the final UTC day of short months, as selected in
    /// Settings. This is explicit monthly scheduling, never a history replay.
    static func monthly(dayUTC: Int, hourUTC: Int, minuteUTC: Int = 0, after date: Date) throws -> Date {
        guard (1...31).contains(dayUTC), (0...23).contains(hourUTC), (0...59).contains(minuteUTC) else { throw BackgroundScheduleError.invalidConfiguration }
        let parts = utcCalendar.dateComponents([.year, .month], from: date)
        let candidate = monthlyCandidate(year: parts.year!, month: parts.month!, day: dayUTC, hour: hourUTC, minute: minuteUTC)
        guard candidate <= date else { return candidate }
        let next = utcCalendar.date(byAdding: .month, value: 1, to: candidate)!
        let nextParts = utcCalendar.dateComponents([.year, .month], from: next)
        return monthlyCandidate(year: nextParts.year!, month: nextParts.month!, day: dayUTC, hour: hourUTC, minute: minuteUTC)
    }

    private static func monthlyCandidate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        let first = utcCalendar.date(from: DateComponents(timeZone: utcCalendar.timeZone, year: year, month: month, day: 1))!
        let days = utcCalendar.range(of: .day, in: .month, for: first)!.count
        return utcCalendar.date(from: DateComponents(timeZone: utcCalendar.timeZone, year: year, month: month,
                                                       day: min(day, days), hour: hour, minute: minute))!
    }

    static func nextOccurrence(of rule: BackgroundScheduleRule, after date: Date) -> Date? {
        (0...400).lazy.compactMap { offset in
            let day = utcCalendar.date(byAdding: .day, value: offset, to: utcCalendar.startOfDay(for: date))!
            return occurrences(of: rule, on: day).first { $0 > date }
        }.first
    }

    static func latestOccurrence(of rule: BackgroundScheduleRule, at date: Date) -> Date? {
        (0...400).lazy.compactMap { offset in
            let day = utcCalendar.date(byAdding: .day, value: -offset, to: utcCalendar.startOfDay(for: date))!
            return occurrences(of: rule, on: day).last { $0 <= date }
        }.first
    }

    private static func occurrences(of rule: BackgroundScheduleRule, on day: Date) -> [Date] {
        let parts = utcCalendar.dateComponents([.year, .month, .day, .weekday], from: day)
        let times: [Int]
        switch rule {
        case let .selectedWeekdays(weekdays, values):
            guard weekdays.contains(parts.weekday!) else { return [] }; times = values
        case let .monthly(days, values):
            let last = utcCalendar.range(of: .day, in: .month, for: day)!.count
            guard days.contains(parts.day!) || (parts.day == last && days.contains(where: { $0 > last })) else { return [] }
            times = values
        }
        return times.map { utcCalendar.date(byAdding: .minute, value: $0, to: utcCalendar.startOfDay(for: day))! }
    }
}
