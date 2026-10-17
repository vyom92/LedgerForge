import Foundation

/// Only loss of connectivity is eligible for lifecycle recovery. HTTP errors,
/// timeouts, authentication failures and untyped errors retain their policy.
nonisolated enum ConnectivityInterruption {
    static func matches(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }
        return error.code == .notConnectedToInternet || error.code == .networkConnectionLost
    }
}

nonisolated struct BackgroundPublicLegProgress: Codable, Equatable, Sendable {
    let identity: String
    let slot: Date
    var attempts: Int = 0
    var succeeded: Bool = false
    var retryAt: Date? = nil
    var failure: String? = nil
    // An explicit manual request may target a disabled automatic scope. Its
    // single retry must survive helper exit without enabling future slots.
    // Optional preserves decoding of the earlier operational JSON shape.
    var manuallyRequested: Bool? = nil
    // Actual completion of this leg's check, independent of the scheduled slot
    // and the last successful observation. Older receipts have no check time.
    var checkedAt: Date? = nil
    // No timer while disconnected. Missing in older records means no proven
    // interruption; generic historical failures must never be reclassified.
    var waitingForConnectivity: Bool? = nil

    var pendingManualRetry: Bool {
        manuallyRequested == true && !succeeded && attempts < 2 && (retryAt != nil || waitingForConnectivity == true)
    }

    mutating func recordFailure(_ message: String, interrupted: Bool, at now: Date) {
        succeeded = false; failure = message; checkedAt = now
        waitingForConnectivity = interrupted
        if interrupted {
            // The check is retained above; only its provider-error allowance
            // is restored. A new connectivity event, not a timer, releases it.
            attempts = max(0, attempts - 1)
            retryAt = nil
        } else {
            retryAt = attempts < 2 ? now.addingTimeInterval(60) : nil
        }
    }
}

nonisolated enum PublicObservationPresentation {
    static func cacheStatus(networkAvailable: Bool?, identities: Set<String>,
                            progress: [String: BackgroundPublicLegProgress]) -> String {
        cacheStatus(networkAvailable: networkAvailable,
                    failed: identities.contains { progress[$0]?.failure != nil })
    }

    static func cacheStatus(networkAvailable: Bool?, failed: Bool) -> String {
        if networkAvailable == false { return "Offline · cached" }
        return failed ? "Refresh failed · cached" : "Cached observation"
    }
}

nonisolated struct BackgroundPublicProgressStore: Sendable {
    let database: SQLiteDatabase
    func load() throws -> [String: BackgroundPublicLegProgress] {
        let values = try database.query(sql: "SELECT leg_id,record_json FROM background_public_progress;") { row in
            guard let key = row.string(at: 0), let data = row.data(at: 1),
                  let value = try? JSONDecoder().decode(BackgroundPublicLegProgress.self, from: data),
                  value.identity == key, (0...2).contains(value.attempts) else { throw LedgerAccessError.unavailable }
            return (key, value)
        }
        return Dictionary(uniqueKeysWithValues: values)
    }
    func save(_ value: BackgroundPublicLegProgress) throws {
        try database.withExclusiveAccess { try Self.write(value, database: database) }
    }
    static func write(_ value: BackgroundPublicLegProgress, database: SQLiteDatabase) throws {
        try database.executePrepared(sql: "INSERT INTO background_public_progress(leg_id,record_json) VALUES(?,?) ON CONFLICT(leg_id) DO UPDATE SET record_json=excluded.record_json;",
            params: [value.identity, try JSONEncoder().encode(value)])
    }
}
