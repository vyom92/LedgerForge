import Foundation

nonisolated enum BackgroundJobOrigin: String, Codable, Sendable { case foreground, helper }

/// A typed durable claim/outcome record. It intentionally contains no source,
/// credential, quote, holding, or parsed financial payload.
nonisolated struct BackgroundJobRecord: Codable, Equatable, Sendable {
    let kind: BackgroundJobKind
    let claimID: UUID
    let activationEpoch: UUID
    let origin: BackgroundJobOrigin
    let claimedAt: Date
    var completedAt: Date?
    var outcome: BackgroundJobCompletion?
}

nonisolated protocol BackgroundJobRepository: Sendable {
    func jobRecord(_ kind: BackgroundJobKind) throws -> BackgroundJobRecord?
    func claim(_ kind: BackgroundJobKind, activation: LedgerActivationStamp, origin: BackgroundJobOrigin, now: Date) throws -> BackgroundJobRecord?
    func finish(_ record: BackgroundJobRecord, outcome: BackgroundJobCompletion, now: Date) throws
}

nonisolated struct UnavailableBackgroundJobRepository: BackgroundJobRepository {
    func jobRecord(_ kind: BackgroundJobKind) throws -> BackgroundJobRecord? { throw LedgerAccessError.unavailable }
    func claim(_ kind: BackgroundJobKind, activation: LedgerActivationStamp, origin: BackgroundJobOrigin, now: Date) throws -> BackgroundJobRecord? { throw LedgerAccessError.unavailable }
    func finish(_ record: BackgroundJobRecord, outcome: BackgroundJobCompletion, now: Date) throws { throw LedgerAccessError.unavailable }
}

nonisolated final class SQLiteBackgroundJobRepository: BackgroundJobRepository {
    private let database: SQLiteDatabase
    init(database: SQLiteDatabase) { self.database = database }

    func jobRecord(_ kind: BackgroundJobKind) throws -> BackgroundJobRecord? {
        try database.withExclusiveAccess {
            try database.query(sql: "SELECT job_kind,claim_id,activation_epoch,claimed_at,completed_at,outcome,origin FROM background_update_receipts WHERE job_kind=?;", params: [kind.rawValue]) { row in
                guard let job = BackgroundJobKind(rawValue: row.string(at: 0) ?? ""),
                      let claim = row.string(at: 1).flatMap(UUID.init(uuidString:)),
                      let epoch = row.string(at: 2).flatMap(UUID.init(uuidString:)),
                      let claimed = Self.date(row.string(at: 3)),
                      let origin = row.string(at: 6).flatMap(BackgroundJobOrigin.init(rawValue:)) else { throw LedgerAccessError.unavailable }
                return BackgroundJobRecord(kind: job, claimID: claim, activationEpoch: epoch, origin: origin, claimedAt: claimed,
                                           completedAt: Self.date(row.string(at: 4)), outcome: row.string(at: 5).flatMap(BackgroundJobCompletion.init(rawValue:)))
            }.first
        }
    }

    func claim(_ kind: BackgroundJobKind, activation: LedgerActivationStamp, origin: BackgroundJobOrigin, now: Date) throws -> BackgroundJobRecord? {
        try database.withExclusiveAccess {
            try database.execute(sql: "BEGIN IMMEDIATE;")
            do {
                // Caller holds the per-job OS lease. An unfinished old claim
                // therefore belongs to an exited/interrupted owner, not live work.
                guard try database.validatedActivationStamp() == activation else { throw LedgerAccessError.staleActivation }
                let record = BackgroundJobRecord(kind: kind, claimID: UUID(), activationEpoch: activation.epoch, origin: origin, claimedAt: now,
                                                 completedAt: nil, outcome: nil)
                try database.executePrepared(sql: "INSERT INTO background_update_receipts(job_kind,claim_id,activation_epoch,claimed_at,completed_at,outcome,origin) VALUES(?,?,?,?,NULL,NULL,?) ON CONFLICT(job_kind) DO UPDATE SET claim_id=excluded.claim_id,activation_epoch=excluded.activation_epoch,claimed_at=excluded.claimed_at,completed_at=NULL,outcome=NULL,origin=excluded.origin;", params: [kind.rawValue, record.claimID.uuidString, record.activationEpoch.uuidString, Self.text(now), origin.rawValue])
                try database.execute(sql: "COMMIT;")
                return record
            } catch { try? database.execute(sql: "ROLLBACK;"); throw error }
        }
    }

    func finish(_ record: BackgroundJobRecord, outcome: BackgroundJobCompletion, now: Date) throws {
        try database.withExclusiveAccess {
            try database.execute(sql: "BEGIN IMMEDIATE;")
            do {
                try Self.finishWithinTransaction(database: database, record: record, outcome: outcome, now: now)
                try database.execute(sql: "COMMIT;")
            } catch { try? database.execute(sql: "ROLLBACK;"); throw error }
        }
    }

    /// Used only by the existing ISP holdings transaction, before its COMMIT.
    static func finishWithinTransaction(database: SQLiteDatabase, record: BackgroundJobRecord,
                                       outcome: BackgroundJobCompletion, now: Date) throws {
        guard try database.validatedActivationStamp().epoch == record.activationEpoch else { throw LedgerAccessError.staleActivation }
                try database.executePrepared(sql: "UPDATE background_update_receipts SET completed_at=?,outcome=? WHERE job_kind=? AND claim_id=? AND activation_epoch=? AND completed_at IS NULL;", params: [Self.text(now), outcome.rawValue, record.kind.rawValue, record.claimID.uuidString, record.activationEpoch.uuidString])
                guard let persisted = try SQLiteBackgroundJobRepository(database: database).jobRecord(record.kind),
                      persisted.claimID == record.claimID,
                      persisted.activationEpoch == record.activationEpoch,
                      persisted.completedAt != nil,
                      persisted.outcome == outcome else {
                    throw LedgerAccessError.staleActivation
                }
    }

    static func reconcileRestore(database: SQLiteDatabase) throws {
        // Caches/configuration survive. Native restored receipts establish future
        // coverage; attempt/claim suppression from another activation does not.
        try database.execute(sql: "DELETE FROM background_update_receipts; DELETE FROM background_public_progress;")
    }

    private static func text(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    private static func date(_ text: String?) -> Date? { text.flatMap { ISO8601DateFormatter().date(from: $0) } }
}
