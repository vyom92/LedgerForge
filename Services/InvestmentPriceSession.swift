import Combine
import Foundation

@MainActor
struct InvestmentQuoteCache {
    static let key = "LedgerForge.investmentPrices.latest.v1"
    let defaults: UserDefaults
    func load(now: Date) -> [String: InvestmentQuote] {
        guard let data = defaults.data(forKey: Self.key), data.count <= 256_000,
              let records = try? JSONDecoder().decode([InvestmentQuote].self, from: data),
              records.count <= InvestmentPriceRegistry.definitions.count,
              Set(records.map { $0.mapping.identity }).count == records.count else { return [:] }
        return Dictionary(uniqueKeysWithValues: records.compactMap { quote in
            guard InvestmentPriceRegistry.definition(for: quote.mapping) != nil,
                  (try? quote.validated()) != nil, quote.fetchedAt <= now else { return nil }
            return (quote.mapping.identity, quote)
        })
    }
    func save(_ quotes: [String: InvestmentQuote]) {
        if let data = try? JSONEncoder().encode(quotes.values.sorted { $0.mapping.identity < $1.mapping.identity }) {
            defaults.set(data, forKey: Self.key)
        }
    }
}

struct InvestmentSubtotal: Identifiable {
    let id: String
    let title: String
    let currency: String
    let value: Decimal?
    let gain: Decimal?
    let totalCount: Int
    let pricedCount: Int
    let costCount: Int
    let quotes: [InvestmentQuote]
    let valueText: String
    let gainText: String
}

/// App-owned request/cache state, independent of Settings. The shared coordinator owns UTC timing.
@MainActor
final class InvestmentPriceSession: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private(set) var valuations: [String: InvestmentValuation] = [:]
    private(set) var valueText: [String: String] = [:]
    private(set) var gainText: [String: String] = [:]
    private(set) var returnText: [String: String] = [:]
    private(set) var rows: [InvestmentHolding] = []
    private(set) var portfolioNames: [String: String] = [:]
    private(set) var currencyTotals: [InvestmentSubtotal] = []
    private(set) var portfolioTotals: [InvestmentSubtotal] = []
    private(set) var overview: InvestmentOverview = .empty
    private(set) var quotes: [String: InvestmentQuote]
    private(set) var refreshing: Set<String> = []
    private(set) var failures: [String: InvestmentPriceError] = [:]
    private(set) var feedback: [String: String] = [:]
    private(set) var mappingMessage: String?
    private(set) var revision = 0
    private(set) var requestCount = 0
    private var snapshot: InvestmentSnapshot = .empty
    private var generation: ProviderGenerationToken?
    private var epoch = UUID()
    private var requests: [String: Task<Void, Never>] = [:]
    private var mappingTask: Task<Void, Never>?
    private var mappingPersistenceNeeded = false
    private var refreshRequested = false
    private weak var store: InvestmentStore?
    private let cache: InvestmentQuoteCache
    private let client: InvestmentPriceClient
    private let now: @Sendable () -> Date
    private let enabled: Bool
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private var fxLegs: [AlDarCurrency: AlDarUnitReference] = [:]
    private var rateObservation: AnyCancellable?
    private var gateObservation: AnyCancellable?
    private weak var rates: AlDarReferenceSession?

    init(defaults: UserDefaults = .standard, enabled: Bool = true,
         now: @escaping @Sendable () -> Date = { Date() }, client: InvestmentPriceClient = .init(),
         sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) {
        self.cache = .init(defaults: defaults); self.quotes = cache.load(now: now())
        self.now = now; self.client = client; self.enabled = enabled; self.sleep = sleep
        gateObservation = DatabaseActivityGate.shared.didBecomeAvailable.sink { [weak self] in
            self?.notifyInstalledValue()
        }
    }

    var configuredMappings: [InvestmentPriceMapping] {
        let mappings = snapshot.holdings.compactMap { holding -> InvestmentPriceMapping? in
            guard let mapping = holding.priceMapping,
                  InvestmentPriceRegistry.confirmedMapping(for: holding) == mapping else { return nil }
            return mapping
        }
        return Array(Set(mappings)).sorted { $0.identity < $1.identity }
    }
    var configuredProviders: [String] {
        let providers = Set(configuredMappings.map(\.provider))
        return InvestmentPriceRegistry.providerOrder.filter { providers.contains($0) }
    }
    var unmappedCount: Int { snapshot.holdings.filter { InvestmentPriceRegistry.confirmedMapping(for: $0) != $0.priceMapping || $0.priceMapping == nil }.count }

    func activate(store: InvestmentStore = .shared) {
        guard self.store !== store else { return }
        self.store = store; store.priceSession = self
        installWithoutObservation(store.snapshot, generation: store.generation)
        notifyInstalledValue()
    }

    func observeRates(_ rates: AlDarReferenceSession) {
        guard self.rates !== rates else { return }
        self.rates = rates
        rateObservation = rates.$legs.sink { [weak self] legs in
            guard let self, self.fxLegs != legs else { return }
            self.fxLegs = legs
            self.overview = .build(holdings: self.rows, valuations: self.valuations, legs: legs,
                                   ispAccount: self.snapshot.latestZioAccount)
            self.objectWillChange.send()
        }
    }

    /// Invoked during the hydrator's install phase, before any store publishes.
    func installWithoutObservation(_ snapshot: InvestmentSnapshot, generation: ProviderGenerationToken?) {
        let oldMappings = configuredMappings
        let oldGeneration = self.generation
        self.snapshot = snapshot; self.generation = generation
        if oldGeneration != generation || oldMappings != configuredMappings {
            epoch = UUID()
            for request in requests.values { request.cancel() }
            requests.removeAll(); refreshing.removeAll(); failures.removeAll(); feedback.removeAll()
        }
        rebuild()
        mappingPersistenceNeeded = snapshot.holdings.contains { $0.priceMapping == nil && InvestmentPriceRegistry.confirmedMapping(for: $0) != nil }
    }

    func notifyInstalledValue() {
        objectWillChange.send()
        // Canonical availability has been published before this notification. No write is scheduled in install phase.
        guard enabled, mappingPersistenceNeeded || refreshRequested, mappingTask == nil else { return }
        mappingTask = Task { [weak self] in
            await Task.yield()
            guard let self else { return }
            defer { self.mappingTask = nil }
            guard !Task.isCancelled else { return }
            self.persistConfirmedMappings()
            self.startRequestedRefreshIfReady()
        }
    }

    private func persistConfirmedMappings() {
        guard let generation, generation == DatabaseProvider.shared.generationToken,
              generation == store?.generation, ApplicationAvailability.shared.permitsMutation,
              let workspaceID = snapshot.containers.first?.workspaceID else { return }
        let assignments = Dictionary(uniqueKeysWithValues: snapshot.holdings.compactMap { holding -> (String, InvestmentPriceMapping)? in
            guard let mapping = InvestmentPriceRegistry.confirmedMapping(for: holding), holding.priceMapping != mapping else { return nil }
            // Never replace a conflicting existing mapping without its own explicit decision.
            guard holding.priceMapping == nil else { return nil }
            return (holding.id, mapping)
        })
        guard !assignments.isEmpty else { return }
        guard let lease = try? DatabaseActivityGate.shared.begin(.repositoryWrite) else { return }
        defer { lease.finish() }
        let result = DatabaseProvider.shared.investmentRepo.savePriceMappings(.init(providerGeneration: generation,
            workspaceID: workspaceID, baseline: snapshot, assignments: assignments))
        if result == .saved {
            mappingMessage = nil
            do { _ = try RepositoryStoreHydrator(workspaceId: workspaceID).hydrateIfNeeded(forceRefresh: true) }
            catch { mappingMessage = "Price mappings were saved; reload the current holdings to use them."; objectWillChange.send() }
        } else {
            mappingMessage = "Price mappings could not be saved. Refresh all can try again."
            objectWillChange.send()
        }
    }

    func refreshManually() {
        guard enabled else { return }
        refreshRequested = true
        startRequestedRefreshIfReady()
    }

    private func startRequestedRefreshIfReady() {
        guard refreshRequested, ApplicationAvailability.shared.permitsMutation else { return }
        guard requests.isEmpty else { refreshRequested = false; return }
        persistConfirmedMappings()
        guard refreshRequested else { return }
        guard let generation, generation == DatabaseProvider.shared.generationToken, generation == store?.generation else { return }
        refreshRequested = false
        let all = configuredMappings.compactMap { InvestmentPriceRegistry.definition(for: $0) }
        let groups = Dictionary(grouping: all, by: { $0.mapping.provider })
        for provider in InvestmentPriceRegistry.providerOrder {
            guard let definitions = groups[provider], requests[provider] == nil else { continue }
            refreshing.insert(provider); feedback[provider] = "Refreshing…"
            let epoch = epoch, client = client, sleep = sleep
            requests[provider] = Task { @concurrent [weak self] in
                var pending = definitions
                for attempt in 0...1 {
                let batches = provider == "nasdaq" ? pending.map { [$0] } : [pending]
                // Four concurrent Nasdaq requests; catalogue families use one request each.
                let results = await withTaskGroup(of: [String: Result<InvestmentQuote, InvestmentPriceError>].self,
                                                   returning: [String: Result<InvestmentQuote, InvestmentPriceError>].self) { group in
                    var iterator = batches.makeIterator(), combined: [String: Result<InvestmentQuote, InvestmentPriceError>] = [:]
                    for _ in 0..<min(4, batches.count) {
                        if let batch = iterator.next() {
                            await self?.recordRequest(epoch: epoch, count: provider == "franklin" ? 2 : 1)
                            group.addTask { await client.fetch(batch) }
                        }
                    }
                    for await result in group {
                        combined.merge(result) { _, new in new }
                        if !Task.isCancelled, let batch = iterator.next() {
                            await self?.recordRequest(epoch: epoch, count: provider == "franklin" ? 2 : 1)
                            group.addTask { await client.fetch(batch) }
                        }
                    }
                    return combined
                }
                guard !Task.isCancelled else { return }
                let failedIDs = Set(results.compactMap { key, result in if case .failure = result { key } else { nil } })
                let complete = attempt == 1 || failedIDs.isEmpty
                await self?.finish(provider: provider, results: results, generation: generation, epoch: epoch, complete: complete)
                guard !complete else { return }
                pending = pending.filter { failedIDs.contains($0.mapping.identity) }
                do { try await sleep(OnlineRefreshSchedule.retryInterval) } catch { return }
                guard !Task.isCancelled else { return }
                }
            }
        }
        objectWillChange.send()
    }

    private func recordRequest(epoch: UUID, count: Int) { if self.epoch == epoch { requestCount += count } }

    private func finish(provider: String, results: [String: Result<InvestmentQuote, InvestmentPriceError>],
                        generation: ProviderGenerationToken, epoch: UUID, complete: Bool) {
        guard self.epoch == epoch, self.generation == generation, store?.generation == generation,
              DatabaseProvider.shared.generationToken == generation else { return }
        let current = Dictionary(uniqueKeysWithValues: configuredMappings.map { ($0.identity, $0) })
        var updated = 0, unchanged = 0, failed = 0
        for (identity, result) in results {
            guard let mapping = current[identity] else { continue }
            switch result {
            case .success(let incoming):
                let previous = quotes[identity]
                let quote = incoming.retainingUndatedObservation(previous)
                guard quote.mapping == mapping, quote.fetchedAt <= now(), quote.canReplace(previous) else {
                    failures[identity] = .olderResponse; failed += 1; continue
                }
                if previous?.price.value == quote.price.value && previous?.valuationDay == quote.valuationDay { unchanged += 1 }
                else { updated += 1 }
                quotes[identity] = quote; failures.removeValue(forKey: identity)
            case .failure(let error): failures[identity] = error; failed += 1
            }
        }
        feedback[provider] = [updated > 0 ? "\(updated) updated" : nil, unchanged > 0 ? "\(unchanged) unchanged" : nil,
                              failed > 0 ? "\(failed) unavailable" : nil].compactMap { $0 }.joined(separator: " · ")
        if complete { requests.removeValue(forKey: provider); refreshing.remove(provider) }
        else { feedback[provider, default: ""] += " · Retrying failed prices in 60 seconds" }
        cache.save(quotes); rebuild(); objectWillChange.send()
    }

    private func rebuild() {
        portfolioNames = Dictionary(uniqueKeysWithValues: snapshot.containers.map { container in
            let name = container.institution == "Zurich ISP" ? container.displayName.replacingOccurrences(of: "Zurich · ", with: "ISP · ") : container.displayName
            return (container.id, name.contains(container.identity) ? name : name + " · " + container.identity)
        })
        rows = snapshot.holdings.sorted {
            let left = portfolioNames[$0.containerID] ?? "", right = portfolioNames[$1.containerID] ?? ""
            if left != right { return left.localizedStandardCompare(right) == .orderedAscending }
            return $0.sourceOrdinal != $1.sourceOrdinal ? $0.sourceOrdinal < $1.sourceOrdinal : $0.id < $1.id
        }
        valuations = Dictionary(uniqueKeysWithValues: rows.map { holding in
            let mapping = holding.priceMapping
            let quote = mapping.flatMap { InvestmentPriceRegistry.confirmedMapping(for: holding) == $0 ? quotes[$0.identity] : nil }
            return (holding.id, InvestmentValuation(holding: holding, quote: quote))
        })
        valueText = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, InvestmentArithmetic.displayedMoney(valuations[$0.id]?.currentValue, currency: $0.currency)) })
        gainText = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, InvestmentArithmetic.displayedMoney(valuations[$0.id]?.gain, currency: $0.currency)) })
        returnText = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, valuations[$0.id]?.simpleReturn?.display ?? "Unavailable") })
        currencyTotals = Dictionary(grouping: rows, by: \.currency).keys.sorted().map { currency in
            subtotal(id: currency, title: currency, rows: rows.filter { $0.currency == currency })
        }
        let groups = Dictionary(grouping: rows, by: { $0.containerID + "|" + $0.currency })
        portfolioTotals = groups.keys.sorted().compactMap { key in
            guard let rows = groups[key], let first = rows.first else { return nil }
            return subtotal(id: key, title: portfolioNames[first.containerID] ?? "Portfolio", rows: rows)
        }
        overview = .build(holdings: rows, valuations: valuations, legs: fxLegs,
                          ispAccount: snapshot.latestZioAccount)
        revision += 1
    }

    private func subtotal(id: String, title: String, rows: [InvestmentHolding]) -> InvestmentSubtotal {
        let values = rows.compactMap { valuations[$0.id] }
        let priced = values.compactMap(\.currentValue), gains = values.compactMap(\.gain)
        let value = priced.isEmpty ? nil : try? priced.reduce(Decimal.zero, InvestmentArithmetic.add)
        let gain = gains.isEmpty ? nil : try? gains.reduce(Decimal.zero, InvestmentArithmetic.add)
        return .init(id: id, title: title, currency: rows.first?.currency ?? "", value: value, gain: gain,
            totalCount: rows.count, pricedCount: priced.count, costCount: gains.count, quotes: values.compactMap(\.quote),
            valueText: InvestmentArithmetic.displayedMoney(value, currency: rows.first?.currency ?? ""),
            gainText: InvestmentArithmetic.displayedMoney(gain, currency: rows.first?.currency ?? ""))
    }
}

/// A command boundary over the existing app-owned services, with no timer or duplicate session.
@MainActor
struct LiveFXRefreshService {
    let currencyRates: AlDarReferenceSession
    let investmentPrices: InvestmentPriceSession
    func refreshAll(manual: Bool = true) {
        guard currencyRates.refreshing.isEmpty, investmentPrices.refreshing.isEmpty else { return }
        if manual { currencyRates.refreshManually() } else { currencyRates.refresh(force: true) }
        investmentPrices.refreshManually()
    }
}
