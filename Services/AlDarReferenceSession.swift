import AppKit
import Combine
import Foundation

/// Rebuildable public cache, separate from appearance and saved financial plans.
@MainActor
struct AlDarReferenceCachePreferences {
    nonisolated private struct Record: Codable { let currency: AlDarCurrency; let raw: String; let fetched: String }
    nonisolated private struct Payload: Codable { let version: Int; let records: [Record] }
    static let key = "LedgerForge.alDarReference.lastSuccess.v1"
    let defaults: UserDefaults

    func load(now: Date) -> [AlDarCurrency: AlDarUnitReference] {
        guard let data = defaults.data(forKey: Self.key), data.count <= 4096,
              let payload = try? JSONDecoder().decode(Payload.self, from: data), payload.version == 1,
              payload.records.count <= 2,
              Set(payload.records.map(\.currency)).count == payload.records.count else { return [:] }
        var result: [AlDarCurrency: AlDarUnitReference] = [:]
        for row in payload.records {
            if let leg = try? AlDarUnitReference(currency: row.currency, rawToken: row.raw, fetchedAtISO: row.fetched), leg.fetchedAt <= now {
                result[row.currency] = leg
            }
        }
        return result
    }

    func save(_ legs: [AlDarCurrency: AlDarUnitReference]) {
        let records = AlDarCurrency.allCases.compactMap { legs[$0] }.map { Record(currency: $0.currency, raw: $0.returned.rawToken, fetched: $0.fetchedAtISO) }
        if let data = try? JSONEncoder().encode(Payload(version: 1, records: records)) { defaults.set(data, forKey: Self.key) }
    }
}

@MainActor
final class AlDarReferenceSession: ObservableObject {
    struct RefreshFeedback: Equatable {
        let message: String
        let isWarning: Bool
    }
    static let refreshInterval: TimeInterval = 6 * 60 * 60
    static let retryInterval: TimeInterval = 60
    static let staleInterval: TimeInterval = 24 * 60 * 60
    typealias Fetch = @Sendable (AlDarCurrency) async throws -> AlDarUnitReference
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void
    @Published private(set) var legs: [AlDarCurrency: AlDarUnitReference]
    @Published private(set) var failures: Set<AlDarCurrency> = []
    @Published private(set) var refreshing: Set<AlDarCurrency> = []
    @Published private(set) var requestCount = 0
    @Published private(set) var refreshFeedback: RefreshFeedback?
    private let cache: AlDarReferenceCachePreferences
    private let fetch: Fetch
    private let sleep: Sleep
    private let now: @Sendable () -> Date
    private let enabled: Bool
    private var requests: [AlDarCurrency: Task<Void, Never>] = [:]
    private var tokens: [AlDarCurrency: UUID] = [:]
    private var lastAttempt: [AlDarCurrency: Date] = [:]
    private var periodic: Task<Void, Never>?
    private var wakeObserver: AnyCancellable?
    private var feedbackExpiry: Task<Void, Never>?
    private var manualRefreshBaseline: [AlDarCurrency: AlDarUnitReference]?
    private var failureReasons: [AlDarCurrency: String] = [:]

    init(defaults: UserDefaults = .standard, enabled: Bool = true,
         now: @escaping @Sendable () -> Date = { Date() },
         sleep: @escaping Sleep = { try await Task.sleep(for: .seconds($0)) },
         fetch: @escaping Fetch = { try await AlDarCurrentReferenceProvider().fetchUnit(currency: $0) }) {
        cache = .init(defaults: defaults); legs = cache.load(now: now())
        self.enabled = enabled; self.now = now; self.sleep = sleep; self.fetch = fetch
        wakeObserver = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
    }

    func opened() {
        refresh()
        guard enabled, periodic == nil else { return }
        let sleep = sleep
        periodic = Task { @concurrent [weak self] in
            while !Task.isCancelled {
                do { try await sleep(6 * 60 * 60) } catch { return }
                guard !Task.isCancelled else { return }
                // The six-hour periodic trigger is independent of recent manual refreshes.
                // Existing requests are still joined by refresh's per-leg ownership guard.
                await self?.refresh(force: true)
            }
        }
    }

    func refresh(force: Bool = false) {
        guard enabled else { return }
        for currency in AlDarCurrency.allCases {
            guard requests[currency] == nil else { continue }
            if !force, let recent = lastAttempt[currency] ?? legs[currency]?.fetchedAt,
               now().timeIntervalSince(recent) < Self.refreshInterval { continue }
            let token = UUID(); tokens[currency] = token
            lastAttempt[currency] = now()
            let fetch = fetch, sleep = sleep, now = now
            refreshing.insert(currency)
            requests[currency] = Task { @concurrent [weak self] in
                for attempt in 0...1 {
                    guard !Task.isCancelled else { return }
                    await self?.recordAttempt(currency, token: token)
                    do {
                        let result = try await fetch(currency)
                        try Task.checkCancellation()
                        guard result.currency == currency, result.fetchedAt <= now() else { throw AlDarReferenceError.invalidBinding }
                        await self?.succeeded(result, expected: currency, token: token)
                        return
                    } catch is CancellationError {
                        await self?.cancelled(currency, token: token)
                        return
                    }
                    catch {
                        await self?.failed(currency, token: token, reason: Self.refreshFailureReason(error), final: attempt == 1)
                        if attempt == 0 {
                            do { try await sleep(60) } catch {
                                await self?.cancelled(currency, token: token)
                                return
                            }
                        }
                    }
                }
            }
        }
    }

    func refreshManually() {
        guard enabled else {
            showFeedback("Live refresh is turned off in this review session.", warning: true, temporary: true)
            return
        }
        if manualRefreshBaseline == nil { manualRefreshBaseline = legs }
        showFeedback(refreshing.isEmpty ? "Checking Al Dar…" : "Al Dar is already being checked…")
        refresh(force: true)
    }

    func stop() {
        periodic?.cancel(); periodic = nil
        requests.values.forEach { $0.cancel() }; requests = [:]; tokens = [:]; refreshing = []
        feedbackExpiry?.cancel(); feedbackExpiry = nil
        manualRefreshBaseline = nil; refreshFeedback = nil
    }

    func oldestFetch(for pair: AlDarPair) -> Date? {
        let dates = pair.dependencies.compactMap { legs[$0]?.fetchedAt }
        return dates.count == pair.dependencies.count ? dates.min() : nil
    }
    func isStale(_ pair: AlDarPair, at date: Date? = nil) -> Bool {
        guard let fetched = oldestFetch(for: pair) else { return true }
        return (date ?? now()).timeIntervalSince(fetched) > Self.staleInterval
    }
    private func recordAttempt(_ currency: AlDarCurrency, token: UUID) {
        guard tokens[currency] == token else { return }
        requestCount += 1
    }
    private func succeeded(_ value: AlDarUnitReference, expected: AlDarCurrency, token: UUID) {
        guard tokens[expected] == token else { return }
        guard value.currency == expected, value.fetchedAt <= now() else {
            failed(expected, token: token, reason: "Al Dar returned an unusable rate.", final: true); return
        }
        legs[expected] = value; failures.remove(expected); failureReasons[expected] = nil; cache.save(legs)
        requests[expected] = nil; tokens[expected] = nil; refreshing.remove(expected)
        finishManualRefreshIfNeeded()
    }
    private func failed(_ currency: AlDarCurrency, token: UUID, reason: String, final: Bool) {
        guard tokens[currency] == token else { return }
        failures.insert(currency); failureReasons[currency] = reason
        if final { requests[currency] = nil; tokens[currency] = nil; refreshing.remove(currency) }
        if manualRefreshBaseline != nil {
            showFeedback("\(currency.rawValue): \(reason)" + (final ? "" : " Retrying in 1 minute…"), warning: true)
            finishManualRefreshIfNeeded()
        }
    }
    private func cancelled(_ currency: AlDarCurrency, token: UUID) {
        guard tokens[currency] == token else { return }
        failures.insert(currency); failureReasons[currency] = "Refresh was interrupted."
        requests[currency] = nil; tokens[currency] = nil; refreshing.remove(currency)
        finishManualRefreshIfNeeded()
    }

    private func finishManualRefreshIfNeeded() {
        guard refreshing.isEmpty, let previous = manualRefreshBaseline else { return }
        manualRefreshBaseline = nil
        if failures.isEmpty {
            let unchanged = AlDarCurrency.allCases.allSatisfy { previous[$0]?.returned.decimal == legs[$0]?.returned.decimal }
            showFeedback(unchanged ? "Checked just now · rates are unchanged." : "Rates updated just now.", temporary: true)
        } else {
            let currencies = failures.map(\.rawValue).sorted().joined(separator: " and ")
            let reasons = Set(failures.compactMap { failureReasons[$0] }).sorted().joined(separator: " ")
            let retained = failures.contains { legs[$0] != nil } ? " Last fetched rates kept." : ""
            showFeedback("Couldn’t update \(currencies). \(reasons)\(retained)", warning: true, temporary: true)
        }
    }

    private func showFeedback(_ message: String, warning: Bool = false, temporary: Bool = false) {
        feedbackExpiry?.cancel(); feedbackExpiry = nil
        refreshFeedback = .init(message: message, isWarning: warning)
        guard temporary else { return }
        let sleep = sleep
        feedbackExpiry = Task { [weak self] in
            do { try await sleep(16) } catch { return }
            guard !Task.isCancelled else { return }
            self?.refreshFeedback = nil
        }
    }

    nonisolated private static func refreshFailureReason(_ error: any Error) -> String {
        if let error = error as? URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost: return "The internet connection is unavailable."
            case .timedOut: return "Al Dar took too long to respond."
            default: return "Couldn’t connect to Al Dar."
            }
        }
        if error as? AlDarReferenceError == .invalidResponse || error as? AlDarReferenceError == .invalidBinding {
            return "Al Dar returned an unusable rate."
        }
        return "Al Dar is unavailable right now."
    }
    deinit {
        periodic?.cancel()
        feedbackExpiry?.cancel()
        requests.values.forEach { $0.cancel() }
    }
}
