import Foundation

/// The collector retains its ordinary atomic exact-original/receipt writer.
/// This adapter adds only enrollment authority at each publication, including
/// intermediate scan pages; a disabled or re-enrolled worker cannot continue.
nonisolated struct BackgroundGmailRepository: GmailInboxRepository {
    let base: any GmailInboxRepository
    let database: SQLiteDatabase
    let enrollment: BackgroundEnrollment
    let store: BackgroundEnrollmentStore
    func storedAccounts() throws -> [String] { try base.storedAccounts() }
    func load(account: String) throws -> GmailInboxState { try base.load(account: account) }
    func original(sha256: String, byteCount: Int) throws -> Data { try base.original(sha256: sha256, byteCount: byteCount) }
    func save(_ state: GmailInboxState, originals: [String: Data], expectedRevision: Int64) throws -> GmailInboxState {
        try database.withExclusiveAccess {
            try store.withValid(enrollment) { try base.save(state, originals: originals, expectedRevision: expectedRevision) }
        }
    }
}
