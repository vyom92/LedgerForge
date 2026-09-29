import XCTest
@testable import LedgerForge

final class BackgroundScheduleTests: XCTestCase {
    private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        BackgroundSchedule.utcCalendar.date(from: DateComponents(timeZone: TimeZone(secondsFromGMT: 0), year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testDefaultPublicTimesCoverAllWeekdays() throws {
        let rule = BackgroundScheduleConfiguration.defaultPublicRule
        XCTAssertEqual(BackgroundSchedule.nextOccurrence(of: rule, after: utc(2026, 9, 19, 5)), utc(2026, 9, 19, 6))
        XCTAssertEqual(BackgroundSchedule.latestOccurrence(of: rule, at: utc(2026, 9, 19, 5)), utc(2026, 9, 19, 0))
    }

    func testSelectedWeekdaysWrapsAcrossWeekend() throws {
        let rule = BackgroundScheduleRule.selectedWeekdays(weekdays: [2], timesUTC: [9 * 60 + 30])
        try rule.validated()
        XCTAssertEqual(BackgroundSchedule.nextOccurrence(of: rule, after: utc(2026, 9, 20, 12)), utc(2026, 9, 21, 9, 30))
    }

    func testMonthlyDayThirtyFirstClampsToMonthEnd() throws {
        let rule = BackgroundScheduleRule.monthly(daysUTC: [31], timesUTC: [0])
        try rule.validated()
        XCTAssertEqual(BackgroundSchedule.nextOccurrence(of: rule, after: utc(2026, 2, 1, 0)), utc(2026, 2, 28, 0))
        XCTAssertEqual(BackgroundSchedule.nextOccurrence(of: rule, after: utc(2026, 2, 28, 0)), utc(2026, 3, 31, 0))
    }

    func testEditablePublicTimesCanBeCloseWithoutDeferringAnExactSlot() throws {
        let configuration = BackgroundScheduleConfiguration(publicReferencesRule: .selectedWeekdays(weekdays: BackgroundScheduleConfiguration.allWeekdays, timesUTC: [0, 60]))
        _ = try configuration.validated()
        let exact = utc(2026, 9, 19, 0)
        XCTAssertEqual(BackgroundSchedule.publicOpportunity(now: exact, lastCovered: nil, rule: configuration.publicReferencesRule), exact)
        let callback = exact.addingTimeInterval(2)
        XCTAssertEqual(BackgroundSchedule.publicOpportunity(now: callback, lastCovered: nil, rule: configuration.publicReferencesRule, scheduledTarget: exact), callback)
    }

    func testCatchUpDefersAtInclusiveOneHourBoundary() throws {
        let rule = BackgroundScheduleRule.selectedWeekdays(weekdays: BackgroundScheduleConfiguration.allWeekdays, timesUTC: [0, 120])
        let now = utc(2026, 9, 19, 1)
        XCTAssertEqual(BackgroundSchedule.publicOpportunity(now: now, lastCovered: utc(2026, 9, 18, 23), rule: rule), utc(2026, 9, 19, 2))
    }

    func testMonthEndDoesNotDuplicateClampedDaysAndDefaultsRemainPopulated() throws {
        let rule = BackgroundScheduleRule.monthly(daysUTC: [28, 29, 30, 31], timesUTC: [0])
        let first = utc(2026, 2, 28, 0)
        XCTAssertEqual(BackgroundSchedule.nextOccurrence(of: rule, after: first), utc(2026, 3, 28, 0))
        let value = try BackgroundScheduleConfiguration().validated()
        XCTAssertFalse(value.enabled)
        XCTAssertEqual(value.publicReferencesRule, .selectedWeekdays(weekdays: Set(1...7), timesUTC: [0, 360, 720, 1080]))
        XCTAssertEqual(value.gmailRule, .selectedWeekdays(weekdays: Set(1...7), timesUTC: [0]))
        XCTAssertEqual(value.zurichISPRule, .monthly(daysUTC: [1], timesUTC: [0]))
    }

    func testInvalidEmptyWeekdaysAndDuplicateTimesRefused() {
        XCTAssertThrowsError(try BackgroundScheduleRule.selectedWeekdays(weekdays: [], timesUTC: [0]).validated())
        XCTAssertThrowsError(try BackgroundScheduleRule.selectedWeekdays(weekdays: [2], timesUTC: [0, 0]).validated())
        XCTAssertThrowsError(try BackgroundScheduleRule.monthly(daysUTC: [0], timesUTC: [0]).validated())
    }
}
