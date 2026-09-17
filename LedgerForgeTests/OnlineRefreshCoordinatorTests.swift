import Foundation
import Synchronization
import Testing
@testable import LedgerForge

struct OnlineRefreshCoordinatorTests {
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    @Test func fixedUTCSlotsDoNotDependOnLaunchOrLocalCalendar() {
        for (input, expected) in [("2026-09-17T00:00:00Z", "2026-09-17T06:00:00Z"),
                                  ("2026-09-17T05:59:59Z", "2026-09-17T06:00:00Z"),
                                  ("2026-09-17T06:00:00Z", "2026-09-17T12:00:00Z"),
                                  ("2026-09-17T17:00:00Z", "2026-09-17T18:00:00Z"),
                                  ("2026-12-31T23:59:59Z", "2027-01-01T00:00:00Z")] {
            #expect(OnlineRefreshSchedule.nextSlot(after: date(input)) == date(expected))
        }
        let instant = date("2026-09-17T06:00:00Z")
        #expect(OnlineRefreshSchedule.latestSlot(at: instant) == instant)
        #expect(OnlineRefreshSchedule.retryInterval == 60)
    }

    @Test @MainActor func oneLaunchAndOneWakeCatchUpAcrossSeveralMissedSlots() async throws {
        let clock = UTCRefreshTestClock(date("2026-09-17T05:00:00Z")), sleep = UTCRefreshTestSleep()
        let owner = OnlineRefreshCoordinator(now: { clock.now() }, sleep: { try await sleep.wait($0) })
        var triggers = 0
        owner.start { triggers += 1 }; owner.start { triggers += 1 }
        #expect(triggers == 1)
        #expect(owner.nextScheduledAt == date("2026-09-17T06:00:00Z"))
        await Task.yield()
        clock.set(date("2026-09-17T19:00:00Z"))
        owner.woke(); owner.woke()
        #expect(triggers == 2)
        #expect(owner.nextScheduledAt == date("2026-09-18T00:00:00Z"))
        // A resumed obsolete sleeping timer cannot replay the missed 06/12/18 slots.
        await sleep.releaseAll()
        for _ in 0..<10 { await Task.yield() }
        #expect(triggers == 2)
        owner.stop(); await sleep.releaseAll()
    }

    @Test @MainActor func disabledTestHostCreatesNoTriggerOrTimer() {
        let owner = OnlineRefreshCoordinator(enabled: false)
        var calls = 0
        owner.start { calls += 1 }; owner.woke()
        #expect(calls == 0 && owner.nextScheduledAt == nil)
    }

    @Test func signedSharesAreNotClampedAndZeroDenominatorsStayUnavailable() throws {
        #expect(try InvestmentRatioFormatter.signedShare(20, of: 10) == "200.00%")
        #expect(try InvestmentRatioFormatter.signedShare(-10, of: 10) == "-100.00%")
        #expect(try InvestmentRatioFormatter.signedShare(20, of: -10) == "-200.00%")
        #expect(try InvestmentRatioFormatter.signedShare(-30, of: -10) == "300.00%")
        #expect(throws: InvestmentCalculationError.self) { try InvestmentRatioFormatter.signedShare(1, of: 0) }
        // Current FX conversion remains a fraction until final Money presentation.
        #expect(try InvestmentRatioFormatter.rounded(numerator: 100, denominator: 3, places: 2) == "33.33")
    }
}

private nonisolated final class UTCRefreshTestClock: Sendable {
    private let value: Mutex<Date>
    init(_ date: Date) { value = Mutex(date) }
    func now() -> Date { value.withLock { $0 } }
    func set(_ date: Date) { value.withLock { $0 = date } }
}
private actor UTCRefreshTestSleep {
    private var pending: [CheckedContinuation<Void, any Error>] = []
    func wait(_ seconds: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { pending.append($0) }
        try Task.checkCancellation()
    }
    func releaseAll() { let values = pending; pending = []; values.forEach { $0.resume() } }
}
