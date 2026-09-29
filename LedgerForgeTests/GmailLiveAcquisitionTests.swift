import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

/// Separately selected live acquisition check. It writes only exact originals,
/// normal isolated app database state and technical manifest metadata. It never
/// prepares, commits or exports financial projections.
@Suite(.serialized)
@MainActor
struct GmailLiveAcquisitionTests {
    private struct Manifest: Decodable {
        let schema: Int
        let objects: [Nomination]
    }
    private struct Nomination: Decodable {
        let messageID: String
        let partID: String
        let byteCount: Int
        let sourceSHA256: String
        let nominatedFamily: String
    }
    private enum CampaignError: Error { case missingEnvironment, unsafeDestination, changedOriginal, missingReceipt }

    @Test func ownerSelectedHistoryUsesFrozenSendersAndRetainsEveryOriginal() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let destination = environment["LEDGERFORGE_GMAIL_HISTORY_DIRECTORY"],
              let expectedAccount = environment["LEDGERFORGE_GMAIL_EXPECTED_ACCOUNT"],
              let untilText = environment["LEDGERFORGE_GMAIL_HISTORY_UNTIL"],
              let until = ISO8601DateFormatter().date(from: untilText) else { throw CampaignError.missingEnvironment }
        let root = URL(fileURLWithPath: destination, isDirectory: true).standardizedFileURL
        guard root.path.contains("/LedgerForge/Development/Namespaces/s98-gmail-qualification-") else {
            throw CampaignError.unsafeDestination
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let path = root.appendingPathComponent("acquisition.sqlite").path
        let provider = try SQLiteRepositoryProvider(path: path)
        defer { provider.database.close() }
        guard try provider.database.queryInt("SELECT count(*) FROM import_sessions;") == 0,
              try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace").isEmpty else {
            throw CampaignError.unsafeDestination
        }
        let broker = GmailTokenBroker()
        let account = try await broker.savedAccount()
        guard account == expectedAccount else { throw CampaignError.unsafeDestination }
        let interval = try GmailCollectionInterval(from: nil, until: until, timeZoneIdentifier: "UTC",
                                                   senders: GmailNomination.approvedSenders)
        let initial = try provider.gmailInboxRepo.load(account: account)
        guard initial.activeScan.map({ $0.interval == interval }) ?? true,
              initial.completedIntervals.allSatisfy({ $0 == interval }) else { throw CampaignError.unsafeDestination }
        let client = GmailClient(expectedAccount: account, tokens: broker, transport: GmailAcquisitionObservedTransport())
        let progress = try await GmailCollector().collect(client: client, inbox: provider.gmailInboxRepo,
            interval: initial.activeScan == nil ? interval : nil) { progress in
                if progress.accountedMessages > 0, progress.accountedMessages.isMultiple(of: 100) {
                    print("Gmail history accounted messages: \(progress.accountedMessages)")
                }
            }
        let state = try provider.gmailInboxRepo.load(account: account)
        #expect(progress.isComplete && state.activeScan == nil && state.completedIntervals == [interval])
        var bytes = 0
        for source in state.sources.values where source.acquisition == .available {
            let sha = try #require(source.sha256)
            let original = try provider.gmailInboxRepo.original(sha256: sha, byteCount: source.expectedByteCount)
            #expect(GmailInboxSource.digest(original) == sha)
            bytes += original.count
        }
        #expect(try provider.database.queryInt("SELECT count(*) FROM import_sessions;") == 0)
        let report: [String: Any] = [
            "schema": 1, "from": NSNull(), "until": untilText, "timeZone": "UTC",
            "senders": interval.senders.sorted(), "completed": progress.isComplete,
            "messagesAccounted": state.messages.count, "deliveryOriginals": state.sources.count,
            "uniqueByteIdentities": Set(state.sources.values.compactMap(\.sha256)).count,
            "availableDeliveryBytes": bytes,
            "messageOutcomes": Dictionary(grouping: state.messages.values, by: { $0.outcome.rawValue }).mapValues(\.count),
            "nominatedFamilies": Dictionary(grouping: state.sources.values, by: { $0.family.rawValue }).mapValues(\.count),
            "acquisitionOutcomes": Dictionary(grouping: state.sources.values, by: { $0.acquisition.rawValue }).mapValues(\.count),
            "thisInvocationElapsedSeconds": progress.elapsedSeconds,
            "thisInvocationDownloadRequestSeconds": progress.downloadSeconds,
            "thisInvocationDownloadedBytes": progress.downloadedBytes,
            "thisInvocationPeakDecodedQueuedBytes": progress.peakDecodedBytes
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: root.appendingPathComponent("history-acquisition-manifest.json"), options: .atomic)
        // The normal inbox is the exact per-original manifest: locator, sender,
        // received/retrieved instants, carrier, hash, size and receipt disposition.
        // Reopening it exercises the same restart ownership as the product.
        try provider.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path)
        defer { reopened.database.close() }
        #expect(try reopened.gmailInboxRepo.load(account: account) == state)
        try BackupCompatibility.verifyDatabase(reopened.database)
    }

    @Test func initialIntervalAndRetainedNominationsUseNativeAcquisition() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let destination = environment["LEDGERFORGE_GMAIL_CAMPAIGN_DIRECTORY"],
              let expectedAccount = environment["LEDGERFORGE_GMAIL_EXPECTED_ACCOUNT"],
              let nominationPath = environment["LEDGERFORGE_GMAIL_NOMINATION_MANIFEST"] else { throw CampaignError.missingEnvironment }
        let root = URL(fileURLWithPath: destination, isDirectory: true).standardizedFileURL
        guard root.path.contains("/LedgerForge/Development/Namespaces/s98-gmail-qualification-"),
              !FileManager.default.fileExists(atPath: root.appendingPathComponent("acquisition.sqlite").path) else {
            throw CampaignError.unsafeDestination
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let manifestBytes = try Data(contentsOf: URL(fileURLWithPath: nominationPath))
        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestBytes)
        try #require(manifest.schema == 1 && !manifest.objects.isEmpty)
        let provider = try SQLiteRepositoryProvider(path: root.appendingPathComponent("acquisition.sqlite").path)
        defer { provider.database.close() }
        let inbox = provider.gmailInboxRepo
        let broker = GmailTokenBroker()
        let account = try await broker.savedAccount()
        guard account == expectedAccount else { throw CampaignError.unsafeDestination }
        let client = GmailClient(expectedAccount: account, tokens: broker)
        let formatter = ISO8601DateFormatter()
        let initialFrom: Date = try #require(formatter.date(from: "2026-08-01T00:00:00Z"))
        let interval = try GmailCollectionInterval(
            from: initialFrom,
            until: try #require(formatter.date(from: "2026-09-17T11:13:18Z")), timeZoneIdentifier: "UTC",
            senders: GmailNomination.approvedSenders)
        let collector = GmailCollector()
        let progress = try await collector.collect(client: client, inbox: inbox, interval: interval)
        #expect(progress.isComplete)
        var state = try inbox.load(account: account)
        #expect(state.completedIntervals == [interval])
        var supplemental = GmailCollectionProgress()
        var unavailable = Set<String>()
        // These explicitly retained locators add type coverage only. Calling the
        // same acquisition implementation does not award a fabricated scan
        // boundary for the unsearched dates between them.
        for id in Set(manifest.objects.map(\.messageID)).sorted() {
            do {
                let message = try await client.message(id: id)
                let milliseconds = try #require(Int64(message.internalDate))
                state = try await collector.retainOriginals(message: message, milliseconds: milliseconds, client: client,
                    inbox: inbox, state: state, selectedSenders: GmailNomination.approvedSenders, stats: &supplemental)
                state = try inbox.save(state, originals: [:], expectedRevision: state.revision)
            } catch GmailIntakeError.unavailable { unavailable.insert(id) }
        }
        var dispositions: [[String: Any]] = []
        for nominated in manifest.objects {
            let id = GmailInboxSource.deliveryID(account: account, messageID: nominated.messageID, partID: nominated.partID)
            if unavailable.contains(nominated.messageID) {
                dispositions.append(["sha256": nominated.sourceSHA256, "family": nominated.nominatedFamily, "disposition": "message-unavailable"])
                continue
            }
            guard let source = state.sources[id] else { throw CampaignError.missingReceipt }
            if source.acquisition == .available {
                guard source.sha256 == nominated.sourceSHA256, source.expectedByteCount == nominated.byteCount else {
                    throw CampaignError.changedOriginal
                }
                let bytes = try inbox.original(sha256: nominated.sourceSHA256, byteCount: nominated.byteCount)
                #expect(GmailInboxSource.digest(bytes) == nominated.sourceSHA256)
            }
            dispositions.append(["sha256": nominated.sourceSHA256, "family": nominated.nominatedFamily,
                                 "sourceID": id, "disposition": source.acquisition.rawValue])
        }
        #expect(state.completedIntervals == [interval])
        #expect(state.activeScan == nil)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace").isEmpty)
        #expect(try provider.database.queryInt("SELECT count(*) FROM import_sessions;") == 0)
        let report: [String: Any] = ["schema": 1, "nominationManifestSHA256": GmailInboxSource.digest(manifestBytes),
            "fixedIntervalFrom": "2026-08-01T00:00:00Z", "fixedIntervalUntil": "2026-09-17T11:13:18Z",
            "completed": progress.isComplete, "messagesAccounted": progress.accountedMessages,
            "retainedOriginals": state.sources.count, "downloadedBytes": progress.downloadedBytes + supplemental.downloadedBytes,
            "fixedIntervalElapsedSeconds": progress.elapsedSeconds,
            "fixedIntervalDownloadRequestSeconds": progress.downloadSeconds,
            "peakDecodedQueuedBytes": max(progress.peakDecodedBytes, supplemental.peakDecodedBytes),
            "nominations": dispositions]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: root.appendingPathComponent("acquisition-manifest.json"), options: .atomic)
        try provider.database.checkpointAndClose()
    }
}

/// Operational statuses only; no endpoint, payload, token or source text is logged.
private struct GmailAcquisitionObservedTransport: GmailHTTPTransport {
    let transport = GmailURLSessionTransport()
    func send(_ request: URLRequest, maximumBytes: Int) async throws -> GmailHTTPResponse {
        let response = try await transport.send(request, maximumBytes: maximumBytes)
        if response.statusCode != 200 {
            let envelope = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            let body = envelope?["error"] as? [String: Any]
            let errors = body?["errors"] as? [[String: Any]] ?? []
            let allowed = Set(["rateLimitExceeded", "userRateLimitExceeded", "dailyLimitExceeded", "backendError", "authError"])
            let reasons = errors.compactMap { $0["reason"] as? String }.filter { allowed.contains($0) }.joined(separator: ",")
            let withinBound = GmailClient.retryDelay(retries: 0, retryAfter: response.retryAfter, now: Date(), jitter: 0) != nil
            print("Gmail acquisition HTTP \(response.statusCode), known reasons=\(reasons), server retry delay within 60-second bound=\(withinBound).")
        }
        return response
    }
}
