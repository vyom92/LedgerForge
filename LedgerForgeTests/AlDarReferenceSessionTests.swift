import Foundation
import Synchronization
import XCTest
@testable import LedgerForge

/// Public response/clock mechanics only; these tests never contact Al Dar.
@MainActor
final class AlDarReferenceSessionTests: XCTestCase {
    private func until(_ condition: () async -> Bool) async throws {
        for _ in 0..<400 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Controlled asynchronous operation did not settle")
    }
    private func preferences() -> (UserDefaults, String) {
        let name = "LedgerForge.s95-public-fx-test.\(UUID())"
        return (UserDefaults(suiteName: name)!, name)
    }

    func testOneAppOwnerSharesOpeningManualAndLocalDirectionWork() async throws {
        let (defaults, name) = preferences(); defer { defaults.removePersistentDomain(forName: name) }
        let clock = ReferenceTestClock(), sleep = ReferenceTestSleep(), transport = DeferredUnitTransport()
        let session = AlDarReferenceSession(defaults: defaults, now: { clock.now() }, sleep: { try await sleep.wait($0) }, fetch: { try await transport.fetch($0) })
        session.opened(); session.opened(); session.refresh(force: true)
        try await until { await transport.count == 2 }
        XCTAssertEqual(session.requestCount, 2)
        await transport.complete(at: clock.now())
        try await until { session.legs.count == 2 && session.refreshing.isEmpty }
        for pair in AlDarPair.allCases { XCTAssertNotNil(pair.displayedRate(session.legs)) }
        session.opened()
        XCTAssertEqual(session.requestCount, 2)
        session.stop(); await sleep.finish()
    }

    func testOnlyOneSixtySecondRetryUntilTheNextExplicitTrigger() async throws {
        let (defaults, name) = preferences(); defer { defaults.removePersistentDomain(forName: name) }
        let clock = ReferenceTestClock(), sleep = ReferenceTestSleep(), transport = ImmediateUnitTransport(failuresPerLeg: 2)
        let session = AlDarReferenceSession(defaults: defaults, now: { clock.now() }, sleep: { try await sleep.wait($0) }, fetch: { try await transport.fetch($0, at: clock.now()) })
        session.opened()
        try await until { await sleep.count(60) == 2 }
        XCTAssertEqual(session.requestCount, 2)
        clock.advance(60); await sleep.release(60)
        try await until { session.refreshing.isEmpty }
        XCTAssertEqual(session.requestCount, 4)
        XCTAssertEqual(session.failures.count, 2)
        let retries = await sleep.count(60)
        XCTAssertEqual(retries, 0)
        session.opened(); XCTAssertEqual(session.requestCount, 4)
        session.refresh(force: true)
        try await until { session.legs.count == 2 && session.refreshing.isEmpty }
        XCTAssertEqual(session.requestCount, 6)
        XCTAssertTrue(session.failures.isEmpty)
        session.stop(); await sleep.finish()
    }

    func testPartialFailurePreservesOlderDependencyAndSuccessTime() async throws {
        let (defaults, name) = preferences(); defer { defaults.removePersistentDomain(forName: name) }
        let clock = ReferenceTestClock(), sleep = ReferenceTestSleep()
        let old = try unit(.usd, at: clock.now().addingTimeInterval(-90_000))
        AlDarReferenceCachePreferences(defaults: defaults).save([.usd: old])
        let session = AlDarReferenceSession(defaults: defaults, now: { clock.now() }, sleep: { try await sleep.wait($0) }, fetch: { currency in
            if currency == .usd { throw AlDarReferenceError.unavailable }
            return try unit(currency, at: clock.now())
        })
        session.opened()
        try await until { session.legs[.inr] != nil && session.failures.contains(.usd) }
        // Joining after one leg succeeded must not start that successful leg again.
        let attempts = session.requestCount
        session.refreshManually(); session.refresh(force: true)
        XCTAssertEqual(session.requestCount, attempts)
        XCTAssertEqual(session.refreshing, [.usd])
        XCTAssertEqual(session.legs[.usd], old)
        XCTAssertEqual(session.oldestFetch(for: .usdINR), old.fetchedAt)
        XCTAssertTrue(session.isStale(.usdINR))
        XCTAssertFalse(session.isStale(.qarINR))
        XCTAssertEqual(AlDarReferenceCachePreferences(defaults: defaults).load(now: clock.now())[.usd], old)
        session.stop(); await sleep.finish()
    }

    func testManualRefreshDoesNotDeferTheNextFixedUTCSlot() async throws {
        let (defaults, name) = preferences(); defer { defaults.removePersistentDomain(forName: name) }
        let clock = ReferenceTestClock(), sleep = ReferenceTestSleep(), transport = ImmediateUnitTransport()
        let session = AlDarReferenceSession(defaults: defaults, now: { clock.now() }, sleep: { try await sleep.wait($0) }, fetch: { try await transport.fetch($0, at: clock.now()) })
        let coordinator = OnlineRefreshCoordinator(now: { clock.now() }, sleep: { try await sleep.wait($0) })
        coordinator.start { session.refresh(force: true) }
        try await until { session.requestCount == 2 && session.refreshing.isEmpty }
        try await until { await sleep.count(14_400) == 1 }
        let noon = coordinator.nextScheduledAt
        clock.advance(3_600); session.refreshManually()
        try await until { session.requestCount == 4 && session.refreshing.isEmpty }
        XCTAssertEqual(coordinator.nextScheduledAt, noon)
        clock.advance(10_800); await sleep.release(14_400)
        try await until { session.requestCount == 6 && session.refreshing.isEmpty }
        XCTAssertEqual(coordinator.nextScheduledAt, noon?.addingTimeInterval(21_600))
        coordinator.stop(); session.stop(); await sleep.finish()
    }

    func testLaunchRefreshesRecentCacheImmediatelyAndOnlyOnce() async throws {
        let (defaults, name) = preferences(); defer { defaults.removePersistentDomain(forName: name) }
        let clock = ReferenceTestClock(), sleep = ReferenceTestSleep(), transport = DeferredUnitTransport()
        let legs = try Dictionary(uniqueKeysWithValues: AlDarCurrency.allCases.map { ($0, try unit($0, at: clock.now())) })
        AlDarReferenceCachePreferences(defaults: defaults).save(legs)
        let session = AlDarReferenceSession(defaults: defaults, now: { clock.now() }, sleep: { try await sleep.wait($0) }, fetch: { try await transport.fetch($0) })
        XCTAssertEqual(session.legs, legs)
        session.opened(); session.opened()
        try await until { session.requestCount == 2 }
        XCTAssertEqual(session.legs, legs)
        clock.advance(1); await transport.complete(at: clock.now())
        try await until { session.refreshing.isEmpty }
        XCTAssertTrue(session.legs.values.allSatisfy { $0.fetchedAt == clock.now() })
        session.opened(); XCTAssertEqual(session.requestCount, 2)
        session.stop(); await sleep.finish()
    }

    func testSameValueSuccessAdvancesFetchTimeButFailureDoesNot() async throws {
        let (defaults, name) = preferences(); defer { defaults.removePersistentDomain(forName: name) }
        let clock = ReferenceTestClock(), sleep = ReferenceTestSleep(), transport = ImmediateUnitTransport()
        let old = try unit(.inr, at: clock.now().addingTimeInterval(-90_000))
        AlDarReferenceCachePreferences(defaults: defaults).save([.inr: old])
        let session = AlDarReferenceSession(defaults: defaults, now: { clock.now() }, sleep: { try await sleep.wait($0) }, fetch: { try await transport.fetch($0, at: clock.now()) })
        session.opened()
        try await until { session.legs.count == 2 && session.refreshing.isEmpty }
        XCTAssertEqual(session.legs[.inr]?.returned.rawToken, old.returned.rawToken)
        XCTAssertEqual(session.legs[.inr]?.fetchedAt, clock.now())
        XCTAssertFalse(session.isStale(.qarINR))
        session.stop(); await sleep.finish()
    }

    func testCancellationRejectsLateRepliesWithoutCachePublication() async throws {
        let (defaults, name) = preferences(); defer { defaults.removePersistentDomain(forName: name) }
        let clock = ReferenceTestClock(), sleep = ReferenceTestSleep(), transport = DeferredUnitTransport()
        let session = AlDarReferenceSession(defaults: defaults, now: { clock.now() }, sleep: { try await sleep.wait($0) }, fetch: { try await transport.fetch($0) })
        session.opened(); try await until { await transport.count == 2 }
        session.stop(); await transport.complete(at: clock.now()); await sleep.finish()
        try await until { await transport.finished == 2 }
        XCTAssertTrue(session.legs.isEmpty); XCTAssertTrue(session.refreshing.isEmpty)
        XCTAssertNil(defaults.data(forKey: AlDarReferenceCachePreferences.key))
    }

    func testMalformedCacheAndMissingLegsDoNotInventRates() throws {
        let (defaults, name) = preferences(); defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Data("not json".utf8), forKey: AlDarReferenceCachePreferences.key)
        let clock = ReferenceTestClock()
        let session = AlDarReferenceSession(defaults: defaults, enabled: false, now: { clock.now() })
        XCTAssertTrue(session.legs.isEmpty)
        XCTAssertNil(AlDarPair.usdINR.displayedRate(session.legs))
        XCTAssertNil(session.oldestFetch(for: .usdINR))
        XCTAssertEqual(session.requestCount, 0)
    }

    func testManualRefreshExplainsDisabledPreviewAndDismissesFeedback() async throws {
        let (defaults, name) = preferences(); defer { defaults.removePersistentDomain(forName: name) }
        let sleep = ReferenceTestSleep()
        let session = AlDarReferenceSession(defaults: defaults, enabled: false, sleep: { try await sleep.wait($0) })
        session.refreshManually()
        XCTAssertEqual(session.refreshFeedback?.message, "Live refresh is turned off in this review session.")
        XCTAssertEqual(session.refreshFeedback?.isWarning, true)
        XCTAssertEqual(session.requestCount, 0)
        try await until { await sleep.count(16) == 1 }
        await sleep.release(16)
        try await until { session.refreshFeedback == nil }
        session.stop(); await sleep.finish()
    }

    func testManualRefreshJoinsExistingWorkAndReportsUnchangedRates() async throws {
        let (defaults, name) = preferences(); defer { defaults.removePersistentDomain(forName: name) }
        let clock = ReferenceTestClock(), sleep = ReferenceTestSleep(), transport = DeferredUnitTransport()
        let old = try Dictionary(uniqueKeysWithValues: AlDarCurrency.allCases.map { ($0, try unit($0, at: clock.now().addingTimeInterval(-90_000))) })
        AlDarReferenceCachePreferences(defaults: defaults).save(old)
        let session = AlDarReferenceSession(defaults: defaults, now: { clock.now() }, sleep: { try await sleep.wait($0) }, fetch: { try await transport.fetch($0) })
        session.opened(); try await until { await transport.count == 2 }
        session.refreshManually()
        XCTAssertEqual(session.requestCount, 2)
        XCTAssertEqual(session.refreshFeedback?.message, "Al Dar is already being checked…")
        await transport.complete(at: clock.now())
        try await until { session.refreshing.isEmpty }
        XCTAssertEqual(session.refreshFeedback?.message, "Checked just now · rates are unchanged.")
        XCTAssertEqual(session.refreshFeedback?.isWarning, false)
        XCTAssertEqual(session.legs[.inr]?.fetchedAt, clock.now())
        session.stop(); await sleep.finish()
    }

    func testManualPartialFailureExplainsReasonAndKeepsLastSuccessfulLeg() async throws {
        let (defaults, name) = preferences(); defer { defaults.removePersistentDomain(forName: name) }
        let clock = ReferenceTestClock(), sleep = ReferenceTestSleep()
        let old = try unit(.usd, at: clock.now().addingTimeInterval(-90_000))
        AlDarReferenceCachePreferences(defaults: defaults).save([.usd: old])
        let session = AlDarReferenceSession(defaults: defaults, now: { clock.now() }, sleep: { try await sleep.wait($0) }, fetch: { currency in
            if currency == .usd { throw URLError(.timedOut) }
            return try unit(currency, at: clock.now())
        })
        session.refreshManually()
        try await until { await sleep.count(60) == 1 && session.legs[.inr] != nil }
        XCTAssertEqual(session.refreshFeedback?.message, "USD: Al Dar took too long to respond. Retrying in 1 minute…")
        await sleep.release(60)
        try await until { session.refreshing.isEmpty }
        XCTAssertEqual(session.requestCount, 3)
        XCTAssertEqual(session.refreshFeedback?.message, "Couldn’t update USD. Al Dar took too long to respond. Last fetched rates kept.")
        XCTAssertEqual(session.legs[.usd], old)
        session.stop(); await sleep.finish()
    }

    func testTwentyFourHourBoundaryAndAllSixDirectionsUseRawEvidence() throws {
        let clock = ReferenceTestClock()
        let i = try unit(.inr, at: clock.now()), u = try unit(.usd, at: clock.now().addingTimeInterval(-86_400))
        let (defaults, name) = preferences(); defer { defaults.removePersistentDomain(forName: name) }
        AlDarReferenceCachePreferences(defaults: defaults).save([.inr: i, .usd: u])
        let session = AlDarReferenceSession(defaults: defaults, enabled: false, now: { clock.now() })
        let expected: [AlDarPair: String] = [.qarINR: "26.25", .inrQAR: "0.04", .qarUSD: "0.27", .usdQAR: "3.65", .usdINR: "95.83", .inrUSD: "0.01"]
        for (pair, rate) in expected { XCTAssertEqual(pair.displayedRate(session.legs), rate) }
        XCTAssertFalse(session.isStale(.usdINR)); clock.advance(1); XCTAssertTrue(session.isStale(.usdINR))
        XCTAssertEqual(session.legs[.usd]?.returned.rawToken, "0.273972602739726027397260274")
    }

    func testRelativeAgeAndFreshnessAreIndependentOfTravelTimeZones() throws {
        let fetch = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-16T09:00:00Z"))
        for (elapsed, caption) in [(40.0 * 60, "Fetched 40 mins ago"), (3.0 * 3_600, "Fetched 3 hours ago"), (86_400.0, "Fetched 1 day ago"), (4.0 * 86_400, "Fetched 4 days ago")] {
            XCTAssertEqual(AlDarReferenceAge(fetchedAt: fetch, now: fetch.addingTimeInterval(elapsed)).caption, caption)
        }
        let sameInstantInQatar = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-16T12:00:00+03:00"))
        let nowInTokyo = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-16T21:00:00+09:00"))
        XCTAssertEqual(AlDarReferenceAge(fetchedAt: sameInstantInQatar, now: nowInTokyo).caption, "Fetched 3 hours ago")
        XCTAssertEqual(AlDarReferenceAge(fetchedAt: fetch, now: fetch).colorPosition, 0)
        XCTAssertEqual(AlDarReferenceAge(fetchedAt: fetch, now: fetch.addingTimeInterval(86_400)).colorPosition, 1)
        XCTAssertEqual(AlDarReferenceAge(fetchedAt: fetch, now: fetch.addingTimeInterval(4 * 86_400)).colorPosition, 2)
    }
}

private nonisolated func unit(_ currency: AlDarCurrency, at date: Date) throws -> AlDarUnitReference {
    try .init(currency: currency, rawToken: currency == .inr ? "26.254196" : "0.273972602739726027397260274", fetchedAtISO: ISO8601DateFormatter().string(from: date))
}

private nonisolated final class ReferenceTestClock: Sendable {
    private let instant = Mutex(ISO8601DateFormatter().date(from: "2026-09-16T08:00:00Z")!)
    func now() -> Date { instant.withLock { $0 } }
    func advance(_ seconds: TimeInterval) { instant.withLock { $0.addTimeInterval(seconds) } }
}

private actor ReferenceTestSleep {
    private var pending: [(TimeInterval, CheckedContinuation<Void, any Error>)] = []
    func wait(_ seconds: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { pending.append((seconds, $0)) }
        try Task.checkCancellation()
    }
    func count(_ seconds: TimeInterval) -> Int { pending.filter { $0.0 == seconds }.count }
    func release(_ seconds: TimeInterval) {
        let selected = pending.filter { $0.0 == seconds }; pending.removeAll { $0.0 == seconds }
        selected.forEach { $0.1.resume() }
    }
    func finish() { let all = pending; pending = []; all.forEach { $0.1.resume() } }
}

private actor ImmediateUnitTransport {
    private var remaining: [AlDarCurrency: Int]
    init(failuresPerLeg: Int = 0) { remaining = Dictionary(uniqueKeysWithValues: AlDarCurrency.allCases.map { ($0, failuresPerLeg) }) }
    func fetch(_ currency: AlDarCurrency, at date: Date) throws -> AlDarUnitReference {
        if remaining[currency, default: 0] > 0 { remaining[currency, default: 0] -= 1; throw AlDarReferenceError.unavailable }
        return try unit(currency, at: date)
    }
}

private actor DeferredUnitTransport {
    private var pending: [(AlDarCurrency, CheckedContinuation<AlDarUnitReference, any Error>)] = []
    private(set) var count = 0
    private(set) var finished = 0
    func fetch(_ currency: AlDarCurrency) async throws -> AlDarUnitReference {
        count += 1
        let result = try await withCheckedThrowingContinuation { pending.append((currency, $0)) }
        finished += 1
        return result
    }
    func complete(at date: Date) {
        let values = pending; pending = []
        values.forEach { entry in entry.1.resume(with: Result { try unit(entry.0, at: date) }) }
    }
}
