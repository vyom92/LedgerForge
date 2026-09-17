import AppKit
import Combine
import Foundation

nonisolated enum OnlineRefreshSchedule {
    static let slotInterval: TimeInterval = 21_600
    static let retryInterval: TimeInterval = 60
    static func latestSlot(at date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / slotInterval) * slotInterval)
    }
    static func nextSlot(after date: Date) -> Date { latestSlot(at: date).addingTimeInterval(slotInterval) }
}

/// The sole app-lifetime clock for public prices and currency rates. Authenticated
/// ISP holdings follow their separate monthly calendar. Settings only sends commands.
@MainActor
final class OnlineRefreshCoordinator: ObservableObject {
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void
    private let enabled: Bool
    private let now: @Sendable () -> Date
    private let sleep: Sleep
    private var refresh: (@MainActor () -> Void)?
    private var timer: Task<Void, Never>?
    private var wakeObserver: AnyCancellable?
    private var lastCoveredSlot: Date?
    private var timerEpoch = UUID()
    private(set) var nextScheduledAt: Date?
    private(set) var triggerCount = 0

    init(enabled: Bool = true, now: @escaping @Sendable () -> Date = { Date() },
         sleep: @escaping Sleep = { try await Task.sleep(for: .seconds($0)) }) {
        self.enabled = enabled; self.now = now; self.sleep = sleep
    }

    func start(rates: AlDarReferenceSession, prices: InvestmentPriceSession) {
        start { LiveFXRefreshService(currencyRates: rates, investmentPrices: prices).refreshAll(manual: false) }
    }

    /// Closure injection lets clock/coalescing tests exercise the real owner without financial fixtures.
    func start(refresh: @escaping @MainActor () -> Void) {
        guard enabled, self.refresh == nil else { return }
        self.refresh = refresh
        lastCoveredSlot = OnlineRefreshSchedule.latestSlot(at: now())
        trigger()
        scheduleNextSlot()
        wakeObserver = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.woke() }
            }
    }

    func woke() {
        guard refresh != nil else { return }
        let latest = OnlineRefreshSchedule.latestSlot(at: now())
        if lastCoveredSlot.map({ latest > $0 }) ?? true { lastCoveredSlot = latest; trigger() }
        scheduleNextSlot()
    }

    private func trigger() { triggerCount += 1; refresh?() }

    private func scheduleNextSlot() {
        timer?.cancel()
        timerEpoch = UUID()
        let epoch = timerEpoch, deadline = OnlineRefreshSchedule.nextSlot(after: now()), sleep = sleep
        nextScheduledAt = deadline
        let delay = max(0, deadline.timeIntervalSince(now()))
        timer = Task { @concurrent [weak self] in
            do { try await sleep(delay) } catch { return }
            guard !Task.isCancelled else { return }
            await self?.slotReached(epoch: epoch)
        }
    }

    private func slotReached(epoch: UUID) {
        guard timerEpoch == epoch else { return }
        // Wake and a resumed sleeping timer race through this same slot watermark.
        woke()
    }

    func stop() {
        timerEpoch = UUID(); timer?.cancel(); timer = nil
        wakeObserver = nil; refresh = nil; nextScheduledAt = nil
    }
    deinit { timer?.cancel() }
}
