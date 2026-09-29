import Foundation

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

    var pendingManualRetry: Bool {
        manuallyRequested == true && !succeeded && attempts < 2 && retryAt != nil
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
