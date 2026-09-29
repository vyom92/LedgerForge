import Foundation
import Synchronization

nonisolated public protocol GmailInboxRepository: Sendable {
    func storedAccounts() throws -> [String]
    func load(account: String) throws -> GmailInboxState
    /// Original-byte publication and its receipt are one atomic provider write.
    /// expectedRevision prevents a late scan/attention update replacing newer work.
    func save(_ state: GmailInboxState, originals: [String: Data], expectedRevision: Int64) throws -> GmailInboxState
    func original(sha256: String, byteCount: Int) throws -> Data
}

nonisolated struct UnavailableGmailInboxRepository: GmailInboxRepository {
    func storedAccounts() throws -> [String] { throw GmailIntakeError.storageUnavailable }
    func load(account: String) throws -> GmailInboxState { throw GmailIntakeError.storageUnavailable }
    func save(_ state: GmailInboxState, originals: [String: Data], expectedRevision: Int64) throws -> GmailInboxState {
        throw GmailIntakeError.storageUnavailable
    }
    func original(sha256: String, byteCount: Int) throws -> Data { throw GmailIntakeError.storageUnavailable }
}

nonisolated enum GmailInboxIntegrity {
    static func verify(_ data: Data, sha256: String, byteCount: Int) throws {
        guard byteCount > 0, data.count == byteCount, GmailInboxSource.isDigest(sha256),
              GmailInboxSource.digest(data) == sha256 else { throw GmailIntakeError.integrity }
    }
    static func validateSave(_ state: GmailInboxState, originals: [String: Data], expectedRevision: Int64) throws {
        try state.validate()
        guard state.revision == expectedRevision, expectedRevision < Int64.max else { throw GmailIntakeError.staleProvider }
        for (digest, data) in originals {
            try verify(data, sha256: digest, byteCount: data.count)
            guard state.sources.values.contains(where: { $0.sha256 == digest && $0.expectedByteCount == data.count }) else {
                throw GmailIntakeError.integrity
            }
        }
    }
}

nonisolated final class InMemoryGmailInboxRepository: GmailInboxRepository, Sendable {
    private struct Storage: Sendable {
        var states: [String: GmailInboxState] = [:]
        var originals: [String: Data] = [:]
    }
    private let storage = Mutex(Storage())

    func storedAccounts() throws -> [String] {
        storage.withLock { $0.states.keys.sorted() }
    }

    func load(account: String) throws -> GmailInboxState {
        try storage.withLock { storage in
            let state = storage.states[account.lowercased()] ?? GmailInboxState(account: account)
            try state.validate()
            return state
        }
    }
    func save(_ state: GmailInboxState, originals: [String: Data] = [:], expectedRevision: Int64) throws -> GmailInboxState {
        try GmailInboxIntegrity.validateSave(state, originals: originals, expectedRevision: expectedRevision)
        return try storage.withLock { storage in
            guard (storage.states[state.account]?.revision ?? 0) == expectedRevision else { throw GmailIntakeError.staleProvider }
            var next = storage
            for (sha, bytes) in originals {
                // A freshly fetched, independently hash-verified original may
                // repair unavailable cache bytes under the same byte identity.
                next.originals[sha] = bytes
            }
            for source in state.sources.values {
                if let sha = source.sha256 {
                    guard next.originals[sha]?.count == source.expectedByteCount || source.acquisition != .available else {
                        throw GmailIntakeError.integrity
                    }
                }
            }
            var saved = state; saved.revision += 1
            next.states[state.account] = saved
            storage = next
            return saved
        }
    }
    func original(sha256: String, byteCount: Int) throws -> Data {
        try storage.withLock { storage in
            guard let bytes = storage.originals[sha256] else { throw GmailIntakeError.unavailable }
            try GmailInboxIntegrity.verify(bytes, sha256: sha256, byteCount: byteCount)
            return bytes
        }
    }
}

nonisolated struct SQLiteGmailInboxRepository: GmailInboxRepository {
    let database: SQLiteDatabase

    func storedAccounts() throws -> [String] {
        let values = try database.query(sql: "SELECT account FROM gmail_inbox_state ORDER BY account;") { $0.string(at: 0) }
        guard values.allSatisfy({ $0?.isEmpty == false }) else { throw GmailIntakeError.integrity }
        return values.compactMap { $0 }
    }

    func load(account: String) throws -> GmailInboxState {
        let rows = try database.query(sql: "SELECT revision,state_json FROM gmail_inbox_state WHERE account = ?;", params: [account.lowercased()]) { row in
            (row.int64(at: 0), row.string(at: 1))
        }
        guard let row = rows.first else { return GmailInboxState(account: account) }
        guard let revision = row.0, let text = row.1, let data = text.data(using: .utf8),
              let state = try? JSONDecoder().decode(GmailInboxState.self, from: data),
              state.account == account.lowercased(), state.revision == revision else { throw GmailIntakeError.integrity }
        try state.validate()
        return state
    }

    func save(_ state: GmailInboxState, originals: [String: Data] = [:], expectedRevision: Int64) throws -> GmailInboxState {
        try GmailInboxIntegrity.validateSave(state, originals: originals, expectedRevision: expectedRevision)
        return try database.withExclusiveAccess {
            try database.execute(sql: "BEGIN IMMEDIATE;")
            do {
                guard try load(account: state.account).revision == expectedRevision else { throw GmailIntakeError.staleProvider }
                for (sha, bytes) in originals {
                    try database.executePrepared(sql: "INSERT INTO gmail_originals(sha256,byte_count,original_bytes) VALUES(?,?,?) ON CONFLICT(sha256) DO UPDATE SET byte_count=excluded.byte_count,original_bytes=excluded.original_bytes;", params: [sha, bytes.count, bytes])
                }
                let stored = try database.query(sql: "SELECT sha256,byte_count FROM gmail_originals;") { ($0.string(at: 0), $0.int64(at: 1)) }
                var sizes: [String: Int64] = [:]
                for (sha, count) in stored { if let sha, let count { sizes[sha] = count } }
                for source in state.sources.values {
                    if let sha = source.sha256 {
                        guard sizes[sha] == Int64(source.expectedByteCount) || source.acquisition != .available else {
                            throw GmailIntakeError.integrity
                        }
                    }
                }
                var saved = state; saved.revision += 1
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                guard let json = String(data: try encoder.encode(saved), encoding: .utf8) else { throw GmailIntakeError.integrity }
                try database.executePrepared(sql: "INSERT INTO gmail_inbox_state(account,revision,state_json) VALUES(?,?,?) ON CONFLICT(account) DO UPDATE SET revision=excluded.revision,state_json=excluded.state_json;",
                    params: [saved.account, saved.revision, json])
                try database.execute(sql: "COMMIT;")
                return saved
            } catch {
                try? database.execute(sql: "ROLLBACK;")
                throw error
            }
        }
    }

    func original(sha256: String, byteCount: Int) throws -> Data {
        guard GmailInboxSource.isDigest(sha256), byteCount > 0 else { throw GmailIntakeError.integrity }
        let row = try database.query(sql: "SELECT byte_count,original_bytes FROM gmail_originals WHERE sha256=?;", params: [sha256]) {
            ($0.int64(at: 0), $0.data(at: 1))
        }.first
        guard let row else { throw GmailIntakeError.unavailable }
        guard row.0 == Int64(byteCount), let bytes = row.1 else { throw GmailIntakeError.integrity }
        try GmailInboxIntegrity.verify(bytes, sha256: sha256, byteCount: byteCount)
        return bytes
    }

    static func verifyBackupContents(_ database: SQLiteDatabase) throws {
        let repository = Self(database: database)
        let objects = try database.query(sql: "SELECT sha256,byte_count FROM gmail_originals ORDER BY sha256;") { ($0.string(at: 0), $0.int64(at: 1)) }
        // Validate one original at a time; backup verification never materializes
        // the complete corpus or extracts any source financial content.
        for (sha, size) in objects {
            guard let sha, let size, size > 0, size <= GmailClient.maximumOriginalBytes else { throw GmailIntakeError.integrity }
            _ = try repository.original(sha256: sha, byteCount: Int(size))
        }
        let accounts = try database.query(sql: "SELECT account FROM gmail_inbox_state ORDER BY account;") { $0.string(at: 0) }
        for account in accounts {
            guard let account else { throw GmailIntakeError.integrity }
            let state = try repository.load(account: account)
            for source in state.sources.values {
                if let sha = source.sha256, source.acquisition == .available {
                    _ = try repository.original(sha256: sha, byteCount: source.expectedByteCount)
                }
            }
        }
    }
}
