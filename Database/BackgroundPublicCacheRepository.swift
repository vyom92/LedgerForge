import Foundation

/// The durable public observations shared by foreground and helper work. These
/// rows are caches only: they never replace holdings, transactions, or native
/// Gmail receipts.
nonisolated struct BackgroundPublicCacheSnapshot: Equatable, Sendable {
    let alDarLegs: [AlDarCurrency: AlDarUnitReference]
    let investmentQuotes: [String: InvestmentQuote]

    static let empty = Self(alDarLegs: [:], investmentQuotes: [:])
}

nonisolated protocol BackgroundPublicCacheRepository: Sendable {
    func snapshot(now: Date) throws -> BackgroundPublicCacheSnapshot
    func mergeSeed(alDarLegs: [AlDarCurrency: AlDarUnitReference], investmentQuotes: [String: InvestmentQuote], now: Date) throws
}

nonisolated struct UnavailableBackgroundPublicCacheRepository: BackgroundPublicCacheRepository {
    func snapshot(now: Date) throws -> BackgroundPublicCacheSnapshot { throw LedgerAccessError.unavailable }
    func mergeSeed(alDarLegs: [AlDarCurrency: AlDarUnitReference], investmentQuotes: [String: InvestmentQuote], now: Date) throws { throw LedgerAccessError.unavailable }
}

nonisolated final class SQLiteBackgroundPublicCacheRepository: BackgroundPublicCacheRepository {
    private let database: SQLiteDatabase
    init(database: SQLiteDatabase) { self.database = database }

    func snapshot(now: Date) throws -> BackgroundPublicCacheSnapshot {
        try database.withExclusiveAccess {
            let legs = try database.query(sql: "SELECT currency,raw_token,fetched_at FROM background_al_dar_reference_cache;") { row -> (AlDarCurrency, AlDarUnitReference)? in
                guard let currency = row.string(at: 0).flatMap(AlDarCurrency.init(rawValue:)),
                      let raw = row.string(at: 1), let fetched = row.string(at: 2),
                      let reference = try? AlDarUnitReference(currency: currency, rawToken: raw, fetchedAtISO: fetched),
                      reference.fetchedAt <= now else { return nil }
                return (currency, reference)
            }
            let quotes = try database.query(sql: "SELECT identity,quote_json FROM background_investment_quote_cache;") { row -> (String, InvestmentQuote)? in
                guard let identity = row.string(at: 0), let data = row.data(at: 1),
                      let quote = try? JSONDecoder().decode(InvestmentQuote.self, from: data),
                      quote.mapping.identity == identity,
                      InvestmentPriceRegistry.definition(for: quote.mapping) != nil,
                      (try? quote.validated()) != nil,
                      quote.fetchedAt <= now else { return nil }
                return (identity, quote)
            }
            return BackgroundPublicCacheSnapshot(alDarLegs: Dictionary(uniqueKeysWithValues: legs.compactMap { $0 }),
                                                 investmentQuotes: Dictionary(uniqueKeysWithValues: quotes.compactMap { $0 }))
        }
    }

    /// Explicit foreground binding may carry the legacy in-process cache into
    /// an empty V25 database. It never moves a shared observation backwards.
    func mergeSeed(alDarLegs: [AlDarCurrency: AlDarUnitReference], investmentQuotes: [String: InvestmentQuote], now: Date) throws {
        try merge(alDarLegs: alDarLegs, investmentQuotes: investmentQuotes, progress: nil, now: now)
    }

    func merge(alDarLegs: [AlDarCurrency: AlDarUnitReference], investmentQuotes: [String: InvestmentQuote],
               progress: BackgroundPublicLegProgress?, now: Date) throws {
        try database.withExclusiveAccess {
            try database.execute(sql: "BEGIN IMMEDIATE;")
            do {
                let current = try snapshot(now: now)
                for (currency, incoming) in alDarLegs where incoming.currency == currency && incoming.fetchedAt <= now {
                    guard current.alDarLegs[currency].map({ incoming.fetchedAt > $0.fetchedAt }) ?? true else { continue }
                    try database.executePrepared(sql: "INSERT INTO background_al_dar_reference_cache(currency,raw_token,fetched_at) VALUES(?,?,?) ON CONFLICT(currency) DO UPDATE SET raw_token=excluded.raw_token,fetched_at=excluded.fetched_at;", params: [currency.rawValue, incoming.returned.rawToken, incoming.fetchedAtISO])
                }
                for (identity, rawIncoming) in investmentQuotes {
                    let incoming = rawIncoming.retainingUndatedObservation(current.investmentQuotes[identity])
                    guard incoming.mapping.identity == identity,
                          InvestmentPriceRegistry.definition(for: incoming.mapping) != nil,
                          (try? incoming.validated()) != nil,
                          incoming.fetchedAt <= now,
                          incoming.canReplace(current.investmentQuotes[identity]) else { continue }
                    let payload = try JSONEncoder().encode(incoming)
                    try database.executePrepared(sql: "INSERT INTO background_investment_quote_cache(identity,quote_json) VALUES(?,?) ON CONFLICT(identity) DO UPDATE SET quote_json=excluded.quote_json;", params: [identity, payload])
                }
                if let progress { try BackgroundPublicProgressStore.write(progress, database: database) }
                try database.execute(sql: "COMMIT;")
            } catch { try? database.execute(sql: "ROLLBACK;"); throw error }
        }
    }
}
