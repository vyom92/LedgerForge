import Foundation
import Testing
@testable import LedgerForge

/// Opaque nonfinancial byte-storage mechanics. No financial source, parser,
/// amount, transaction, holding or synthetic statement is constructed here.
@Suite(.serialized)
@MainActor
struct GmailInboxTests {
    @Test(.globalRuntimeStateIsolation)
    func noUpdateNeededReceiptsSurviveReloadAndReturnOnlyAfterExplicitRevisit() async throws {
        let provider = DatabaseProvider(inMemory: true)
        let previous = DatabaseProvider.shared
        DatabaseProvider.shared = provider
        defer { DatabaseProvider.shared = previous }
        var retained = source(attention: .skipped)
        retained.retainedNewerHoldings = true
        let digest = try #require(retained.sha256)
        _ = try provider.gmailInboxRepo.save(state(source: retained), originals: [digest: bytes], expectedRevision: 0)
        let suite = "LedgerForge.S100.Queue.\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let session = GmailIntakeSession(preferences: preferences)
        #expect(session.batchSources.isEmpty)
        await session.reloadInbox()
        #expect(session.isReconciled)
        #expect(session.batchSources.isEmpty)
        #expect(session.status(for: retained) == "Current holdings kept · No update needed")
        session.selectedSourceID = retained.id
        session.revisitSelected()
        #expect(session.batchSources.map(\.id) == [retained.id])
        #expect(session.selectedSource?.retainedNewerHoldings == nil)
        #expect(try provider.gmailInboxRepo.original(sha256: digest, byteCount: bytes.count) == bytes)
        let replacement = DatabaseProvider(inMemory: true)
        DatabaseProvider.shared = replacement
        #expect(!session.isReconciled)
        #expect(session.batchSources.isEmpty)
    }

    @Test func senderEditsSurviveReopenAndCannotAdvanceAnotherSendersCoverage() throws {
        let database = try database(); defer { database.close() }
        let repository = SQLiteGmailInboxRepository(database: database)
        var state = GmailInboxState(account: account)
        #expect(state.configuredSenders.count == 15)
        state.senderRules = [.init(address: "first@example.invalid", isSelected: true),
                             .init(address: "second@example.invalid", isSelected: false)]
        let interval = try GmailCollectionInterval(from: nil, until: Date(timeIntervalSince1970: 100),
                                                   timeZoneIdentifier: "UTC", senders: ["first@example.invalid"])
        state.completedIntervals = [interval]
        state.activeScan = .init(interval: interval)
        state = try repository.save(state, originals: [:], expectedRevision: 0)
        state.senderRules?.removeFirst()
        state.senderRules?[0].address = "edited@example.invalid"
        state.senderRules?[0].isSelected = true
        _ = try repository.save(state, originals: [:], expectedRevision: state.revision)
        let restored = try SQLiteGmailInboxRepository(database: database).load(account: account)
        #expect(restored.configuredSenders == [.init(address: "edited@example.invalid", isSelected: true)])
        #expect(restored.activeScan?.interval.senders == ["first@example.invalid"])
        #expect(restored.completedThrough(senders: ["first@example.invalid"]) == interval.until)
        #expect(restored.completedThrough(senders: ["edited@example.invalid"]) == nil)
    }

    private let account = "mechanics@example.invalid"
    private let bytes = Data([0, 255, 32, 13, 10, 17, 0, 88])

    private func source(message: String = "one", attention: GmailInboxSource.Attention = .pending) -> GmailInboxSource {
        .init(id: GmailInboxSource.deliveryID(account: account, messageID: message, partID: "0"),
              account: account, messageID: message, partID: "0", originalFilename: "../../same.pdf",
              fileExtension: "pdf", mimeType: "application/octet-stream", sender: "transport@example.invalid",
              family: .consolidatedFunds, receivedMilliseconds: 1_000,
              expectedByteCount: bytes.count, acquisition: .available, retrievedAt: Date(timeIntervalSince1970: 2),
              sha256: GmailInboxSource.digest(bytes), attention: attention, dismissed: false)
    }

    private func state(source: GmailInboxSource) -> GmailInboxState {
        var state = GmailInboxState(account: account)
        state.sources[source.id] = source
        state.messages[source.messageID] = .init(messageID: source.messageID, outcome: .attachments,
                                                receivedMilliseconds: 1_000, sourceIDs: [source.id])
        return state
    }

    private func database() throws -> SQLiteDatabase {
        let database = SQLiteDatabase(path: ":memory:")
        try database.open(); try database.runMigrations(allMigrations)
        return database
    }

    @Test func memoryAndSQLitePreserveExactOriginalAndDeliveryState() throws {
        let database = try database(); defer { database.close() }
        let repositories: [any GmailInboxRepository] = [InMemoryGmailInboxRepository(), SQLiteGmailInboxRepository(database: database)]
        let source = source()
        let digest = try #require(source.sha256)
        for repository in repositories {
            let saved = try repository.save(state(source: source), originals: [digest: bytes], expectedRevision: 0)
            #expect(saved.revision == 1)
            #expect(try repository.load(account: account) == saved)
            #expect(try repository.original(sha256: digest, byteCount: bytes.count) == bytes)
            #expect(saved.sources[source.id]?.originalFilename == "../../same.pdf")
            #expect(source.importURL?.isFileURL == false)
        }
    }

    @Test func duplicateDeliverySharesBytesButKeepsBothProvenances() throws {
        let database = try database(); defer { database.close() }
        let repository = SQLiteGmailInboxRepository(database: database)
        let first = source(); let second = source(message: "two")
        var state = state(source: first)
        state.sources[second.id] = second
        let digest = try #require(first.sha256)
        _ = try repository.save(state, originals: [digest: bytes], expectedRevision: 0)
        #expect(try database.queryInt("SELECT count(*) FROM gmail_originals;") == 1)
        #expect(try repository.load(account: account).sources.count == 2)
    }

    @Test func staleReceiptCannotOverwriteExplicitDismissal() throws {
        let database = try database(); defer { database.close() }
        let repositories: [any GmailInboxRepository] = [InMemoryGmailInboxRepository(), SQLiteGmailInboxRepository(database: database)]
        let source = source(); let digest = try #require(source.sha256)
        for repository in repositories {
            let stale = try repository.save(state(source: source), originals: [digest: bytes], expectedRevision: 0)
            var current = stale; current.sources[source.id]?.dismissed = true
            let saved = try repository.save(current, originals: [:], expectedRevision: current.revision)
            #expect(throws: GmailIntakeError.staleProvider) {
                try repository.save(stale, originals: [:], expectedRevision: stale.revision)
            }
            #expect(try repository.load(account: account) == saved)
        }
    }

    @Test func badOriginalAndMissingOriginalDoNotPublishReceipts() throws {
        let database = try database(); defer { database.close() }
        let repositories: [any GmailInboxRepository] = [InMemoryGmailInboxRepository(), SQLiteGmailInboxRepository(database: database)]
        let source = source(); let digest = try #require(source.sha256)
        for repository in repositories {
            #expect(throws: GmailIntakeError.integrity) {
                try repository.save(state(source: source), originals: [digest: Data([1])], expectedRevision: 0)
            }
            #expect(throws: GmailIntakeError.integrity) {
                try repository.save(state(source: source), originals: [:], expectedRevision: 0)
            }
            #expect(try repository.load(account: account).sources.isEmpty)
        }
        #expect(try database.queryInt("SELECT count(*) FROM gmail_originals;") == 0)
    }

    @Test func corruptCacheIsRejectedThenExactReacquisitionCanRepairIt() throws {
        let database = try database(); defer { database.close() }
        let repository = SQLiteGmailInboxRepository(database: database)
        let source = source(); let digest = try #require(source.sha256)
        let saved = try repository.save(state(source: source), originals: [digest: bytes], expectedRevision: 0)
        try database.executePrepared(sql: "UPDATE gmail_originals SET original_bytes=? WHERE sha256=?;", params: [Data(repeating: 3, count: bytes.count), digest])
        #expect(throws: GmailIntakeError.integrity) { try repository.original(sha256: digest, byteCount: bytes.count) }
        #expect(throws: (any Error).self) { try SQLiteGmailInboxRepository.verifyBackupContents(database) }
        _ = try repository.save(saved, originals: [digest: bytes], expectedRevision: saved.revision)
        #expect(try repository.original(sha256: digest, byteCount: bytes.count) == bytes)
        try SQLiteGmailInboxRepository.verifyBackupContents(database)
    }

    @Test func restartRetainsHoldsDismissalAndIncompleteCoverage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s98-restart-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("inbox.sqlite").path
        let database = SQLiteDatabase(path: path)
        try database.open(); try database.runMigrations(allMigrations)
        let repository = SQLiteGmailInboxRepository(database: database)
        var source = source(attention: .unsupported); source.dismissed = true
        var state = state(source: source)
        state.activeScan = .init(interval: try .init(from: nil, until: Date(timeIntervalSince1970: 5), timeZoneIdentifier: "UTC"))
        state.activeScan?.pendingMessageIDs = ["unfinished"]
        let digest = try #require(source.sha256)
        let saved = try repository.save(state, originals: [digest: bytes], expectedRevision: 0)
        try database.checkpointAndClose()
        let reopened = SQLiteDatabase(path: path); try reopened.open(access: .existing); defer { reopened.close() }
        let fresh = SQLiteGmailInboxRepository(database: reopened)
        #expect(try fresh.load(account: account) == saved)
        #expect(try fresh.load(account: account).completedThrough == nil)
        #expect(try fresh.original(sha256: digest, byteCount: bytes.count) == bytes)
    }

    @Test func inboxAndReceiptsTravelInTheSameBackupSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s98-backup-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try database(); defer { database.close() }
        let repository = SQLiteGmailInboxRepository(database: database)
        var source = source(attention: .password); source.dismissed = true
        let digest = try #require(source.sha256)
        let saved = try repository.save(state(source: source), originals: [digest: bytes], expectedRevision: 0)
        let payload = directory.appendingPathComponent("ledger.sqlite")
        try database.createBackup(at: payload.path)
        let copy = SQLiteDatabase(path: payload.path); try copy.open(access: .existing); defer { copy.close() }
        try BackupCompatibility.verifyDatabase(copy)
        let restored = SQLiteGmailInboxRepository(database: copy)
        #expect(try restored.load(account: account) == saved)
        #expect(try restored.original(sha256: digest, byteCount: bytes.count) == bytes)
    }

    @Test func providerReplacementInvalidatesCapturedInbox() throws {
        let provider = DatabaseProvider(inMemory: true)
        let captured = provider.gmailInboxRepo
        _ = try captured.load(account: account)
        provider.invalidateGeneration()
        #expect(throws: RepositoryError.self) { try captured.storedAccounts() }
        #expect(throws: RepositoryError.self) { try captured.load(account: account) }
        #expect(throws: RepositoryError.self) {
            try captured.save(GmailInboxState(account: account), originals: [:], expectedRevision: 0)
        }
        let fresh = DatabaseProvider(inMemory: true)
        #expect(try fresh.gmailInboxRepo.load(account: account).sources.isEmpty)
    }

    @Test func successfulImportEvidenceIncludesExactSecondaryFingerprint() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s98-fingerprint-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let provider = try SQLiteRepositoryProvider(path: directory.appendingPathComponent("ledger.sqlite").path)
        defer { provider.database.close() }
        let rawDigest = String(repeating: "1", count: 64)
        let sourceDigest = String(repeating: "2", count: 64)
        try provider.database.executePrepared(
            sql: "INSERT INTO workspaces(id,name,created_at) VALUES(?,?,?);",
            params: ["workspace", "Fingerprint mechanics", "2026-09-17T00:00:00Z"]
        )
        try provider.database.executePrepared(
            sql: "INSERT INTO import_sessions(id,workspace_id,started_at,completed_at,validation_status,created_at) VALUES(?,?,?,?,?,?);",
            params: ["session", "workspace", "2026-09-17T00:00:00Z", "2026-09-17T00:00:01Z", "passed", "2026-09-17T00:00:00Z"]
        )
        try provider.database.executePrepared(
            sql: "INSERT INTO documents(id,workspace_id,import_session_id,filename,sha256,created_at) VALUES(?,?,?,?,?,?);",
            params: ["document", "workspace", "session", "opaque.csv", rawDigest, "2026-09-17T00:00:00Z"]
        )
        try provider.database.executePrepared(
            sql: "INSERT INTO document_fingerprints(id,document_id,import_session_id,algorithm,fingerprint,created_at,is_duplicate_authority) VALUES(?,?,?,?,?,?,?);",
            params: ["raw", "document", "session", DocumentFingerprintDTO.rawTextSHA256Algorithm,
                     rawDigest, "2026-09-17T00:00:00Z", 1]
        )
        try provider.database.executePrepared(
            sql: "INSERT INTO document_fingerprints(id,document_id,import_session_id,algorithm,fingerprint,created_at,is_duplicate_authority) VALUES(?,?,?,?,?,?,?);",
            params: ["source", "document", "session", DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
                     sourceDigest, "2026-09-17T00:00:00Z", 0]
        )

        #expect(try provider.importSessionRepo.priorImportedStatement(
            algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm, fingerprint: sourceDigest) == nil)
        #expect(try provider.importSessionRepo.successfulImportContainsFingerprint(
            algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm, fingerprint: sourceDigest))
    }
}
