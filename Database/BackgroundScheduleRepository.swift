import Foundation

/// Configuration is durable and backup-compatible, but operational service
/// enrollment is deliberately outside the database and is never restored.
nonisolated protocol BackgroundScheduleRepository: Sendable {
    func configuration() throws -> BackgroundScheduleConfiguration
    func saveConfiguration(_ value: BackgroundScheduleConfiguration) throws
}

nonisolated struct UnavailableBackgroundScheduleRepository: BackgroundScheduleRepository {
    func configuration() throws -> BackgroundScheduleConfiguration { throw LedgerAccessError.unavailable }
    func saveConfiguration(_ value: BackgroundScheduleConfiguration) throws { throw LedgerAccessError.unavailable }
}

nonisolated final class SQLiteBackgroundScheduleRepository: BackgroundScheduleRepository {
    private let database: SQLiteDatabase
    init(database: SQLiteDatabase) { self.database = database }

    func configuration() throws -> BackgroundScheduleConfiguration {
        try database.withExclusiveAccess {
            guard let value = try database.query(sql: "SELECT configuration_json FROM background_schedule_configuration WHERE singleton=1;", map: { row -> BackgroundScheduleConfiguration? in
                guard let data = row.data(at: 0) else { return try? BackgroundScheduleConfiguration().validated() }
                guard let value = try? JSONDecoder().decode(BackgroundScheduleConfiguration.self, from: data) else { return nil }
                return try? value.validated()
            }).compactMap({ $0 }).first else { throw LedgerAccessError.unavailable }
            return value
        }
    }

    func saveConfiguration(_ value: BackgroundScheduleConfiguration) throws {
        let value = try value.validated()
        try database.withExclusiveAccess {
            try database.execute(sql: "BEGIN IMMEDIATE;")
            do {
                try database.executePrepared(sql: "UPDATE background_schedule_configuration SET configuration_json=? WHERE singleton=1;", params: [try JSONEncoder().encode(value)])
                try database.execute(sql: "COMMIT;")
            } catch { try? database.execute(sql: "ROLLBACK;"); throw error }
        }
    }
}
