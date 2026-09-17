import Foundation
import Testing
@testable import LedgerForge

/// Calendar-only proof for the authenticated ISP monthly check. These tests make
/// no network, Keychain, or repository call.
@Suite("Zurich ISP monthly schedule")
struct ZurichISPMonthlyScheduleTests {
    // The proposed Financial Intelligence credit-date-plus-ten/daily fallback
    // remains recorded future work. It has no production schedule to test here.
    private static func utc(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    @Test func fifthAtUTCBeginsTheFirstActiveOpportunity() {
        let before = Self.utc("2026-04-05T00:00:00Z").addingTimeInterval(-0.001)
        let due = Self.utc("2026-04-05T00:00:00Z")
        #expect(!ZurichISPMonthlySchedule.isDue(at: before, lastSuccess: nil))
        #expect(ZurichISPMonthlySchedule.isDue(at: due, lastSuccess: nil))
        #expect(ZurichISPMonthlySchedule.nextDate(after: before) == due)
    }

    @Test func successBeforeTheFifthDoesNotSatisfyTheNewMonthlyDueCheck() {
        let before = Self.utc("2026-04-04T23:59:59Z")
        let after = Self.utc("2026-04-05T12:00:00Z")
        #expect(ZurichISPMonthlySchedule.isDue(at: after, lastSuccess: before))
    }

    @Test func successAfterTheFifthPreventsAnotherAutomaticReadThatMonth() {
        let success = Self.utc("2026-04-05T00:00:01Z")
        #expect(!ZurichISPMonthlySchedule.isDue(at: Self.utc("2026-04-05T23:59:59Z"), lastSuccess: success))
        #expect(!ZurichISPMonthlySchedule.isDue(at: Self.utc("2026-04-30T23:59:59Z"), lastSuccess: success))
        #expect(ZurichISPMonthlySchedule.isDue(at: Self.utc("2026-05-05T00:00:00Z"), lastSuccess: success))
    }

    @Test func monthEndLeapYearAndLocalTimezoneDoNotChangeTheUTCDecision() {
        let success = Self.utc("2028-02-05T00:00:00Z")
        #expect(ZurichISPMonthlySchedule.nextDate(after: Self.utc("2028-02-29T23:59:59Z")) == Self.utc("2028-03-05T00:00:00Z"))
        #expect(ZurichISPMonthlySchedule.isDue(at: Self.utc("2028-03-05T00:00:00Z"), lastSuccess: success))

        // The input is an absolute instant. The fixed UTC schedule therefore has
        // the same answer regardless of the process's local display timezone.
        let instant = Self.utc("2028-03-05T00:00:00Z")
        let qatar = TimeZone(identifier: "Asia/Qatar")!
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        #expect(Calendar(identifier: .gregorian).dateComponents(in: qatar, from: instant).day !=
                Calendar(identifier: .gregorian).dateComponents(in: losAngeles, from: instant).day)
        #expect(ZurichISPMonthlySchedule.isDue(at: instant, lastSuccess: success))
    }
}
