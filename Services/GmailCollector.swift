import Foundation
import Synchronization

nonisolated struct GmailCollectionProgress: Equatable, Sendable {
    var discoveredMessages = 0
    var accountedMessages = 0
    var downloadedOriginals = 0
    var reusedOriginals = 0
    var unavailableOriginals = 0
    var downloadedBytes = 0
    var peakDecodedBytes = 0
    var downloadSeconds = 0.0
    var elapsedSeconds = 0.0
    var isComplete = false
}

/// One acquisition owner; at most two bounded attachment requests overlap.
/// This actor does not create preparations or grant financial-import consent.
actor GmailCollector {
    private var running = false

    func collect(client: GmailClient, inbox: any GmailInboxRepository,
                 interval: GmailCollectionInterval?, replaceIncomplete: Bool = false,
                 progress: @escaping @Sendable (GmailCollectionProgress) async -> Void = { _ in }) async throws -> GmailCollectionProgress {
        guard !running else { throw GmailIntakeError.busy }
        running = true
        defer { running = false }
        let started = ContinuousClock.now
        var stats = GmailCollectionProgress()
        try await client.verifyAccount()
        var state = try inbox.load(account: client.expectedAccount)
        if replaceIncomplete, let interval {
            // Explicitly starting another collection replaces only unfinished
            // traversal state. It grants no coverage and removes no originals,
            // receipts, holds, dismissals or completed intervals.
            state.activeScan = .init(interval: interval)
            state = try inbox.save(state, originals: [:], expectedRevision: state.revision)
        } else if let existing = state.activeScan {
            guard interval == nil || interval == existing.interval else { throw GmailIntakeError.busy }
        } else {
            guard let interval else { throw GmailIntakeError.invalidInterval }
            state.activeScan = .init(interval: interval)
            state = try inbox.save(state, originals: [:], expectedRevision: state.revision)
        }

        while var scan = state.activeScan {
            try Task.checkCancellation()
            if !scan.pageLoaded {
                let page = try await client.page(interval: scan.interval, cursor: scan.pageCursor)
                try Task.checkCancellation()
                if let cursor = page.nextPageToken {
                    guard !cursor.isEmpty, cursor != scan.pageCursor,
                          !scan.seenPageCursors.contains(cursor) else { throw GmailIntakeError.repeatedPage }
                }
                let ids = page.messages?.map(\.id) ?? []
                for id in ids { try GmailClient.validateMessageID(id) }
                // Every listed message remains durable until explicitly accounted.
                // Repeated page members are handled once without losing provenance.
                var seen = scan.accountedMessageIDs
                scan.pendingMessageIDs = ids.filter { seen.insert($0).inserted }
                scan.nextPageCursor = page.nextPageToken
                scan.pageLoaded = true
                state.activeScan = scan
                state = try inbox.save(state, originals: [:], expectedRevision: state.revision)
            }
            guard let loaded = state.activeScan else { throw GmailIntakeError.integrity }
            stats.discoveredMessages = loaded.accountedMessageIDs.count + loaded.pendingMessageIDs.count
            stats.accountedMessages = loaded.accountedMessageIDs.count
            await progress(stats)

            for id in loaded.pendingMessageIDs {
                try Task.checkCancellation()
                do {
                    let message = try await client.message(id: id)
                    guard let milliseconds = Int64(message.internalDate) else { throw GmailIntakeError.invalidResponse }
                    if loaded.interval.contains(milliseconds: milliseconds) {
                        state = try await retainOriginals(message: message, milliseconds: milliseconds, client: client,
                                                  inbox: inbox, state: state, selectedSenders: loaded.interval.senders, stats: &stats)
                    } else if state.messages[id] == nil {
                        state.messages[id] = .init(messageID: id, outcome: .outsideInterval,
                                                   receivedMilliseconds: milliseconds, sourceIDs: [])
                    }
                } catch GmailIntakeError.unavailable {
                    // A listed message which was subsequently deleted has a
                    // truthful unavailable outcome; existing cached originals stay.
                    if state.messages[id] == nil {
                        state.messages[id] = .init(messageID: id, outcome: .unavailable,
                                                   receivedMilliseconds: nil, sourceIDs: [])
                    }
                }
                try Task.checkCancellation()
                state.activeScan?.pendingMessageIDs.removeAll { $0 == id }
                state.activeScan?.accountedMessageIDs.insert(id)
                state = try inbox.save(state, originals: [:], expectedRevision: state.revision)
                stats.accountedMessages = state.activeScan?.accountedMessageIDs.count ?? stats.accountedMessages
                stats.elapsedSeconds = Self.seconds(started.duration(to: .now))
                await progress(stats)
            }

            guard var finished = state.activeScan, finished.pendingMessageIDs.isEmpty else { throw GmailIntakeError.integrity }
            try Task.checkCancellation()
            if let next = finished.nextPageCursor {
                finished.seenPageCursors.append(next)
                finished.pageCursor = next
                finished.nextPageCursor = nil
                finished.pageLoaded = false
                state.activeScan = finished
            } else {
                if !state.completedIntervals.contains(finished.interval) { state.completedIntervals.append(finished.interval) }
                state.activeScan = nil
                stats.isComplete = true
            }
            state = try inbox.save(state, originals: [:], expectedRevision: state.revision)
        }
        stats.elapsedSeconds = Self.seconds(started.duration(to: .now))
        await progress(stats)
        return stats
    }

    private struct Download: Sendable {
        let sourceID: String
        let body: GmailPartBody
    }
    private struct DownloadResult: Sendable {
        let sourceID: String
        let original: GmailDecodedOriginal?
        let elapsedSeconds: Double
    }

    func retainOriginals(message: GmailMessage, milliseconds: Int64, client: GmailClient,
                         inbox: any GmailInboxRepository, state initial: GmailInboxState,
                         selectedSenders: Set<String>,
                         stats: inout GmailCollectionProgress) async throws -> GmailInboxState {
        var state = initial
        guard let senderHeader = message.header("From"), let subject = message.header("Subject"),
              let sender = GmailNomination.address(senderHeader),
              let family = GmailNomination.family(sender: sender, subject: subject, selectedSenders: selectedSenders) else {
            state.messages[message.id] = .init(messageID: message.id, outcome: .excluded,
                                              receivedMilliseconds: milliseconds, sourceIDs: [])
            return state
        }
        var candidates: [Download] = []
        var sourceIDs: [String] = []
        var hasUnsupportedCarrier = false
        var partIDs: Set<String> = []
        for part in try message.payload.flattened() {
            guard let ext = GmailNomination.supportedCarrier(filename: part.filename ?? "", mimeType: part.mimeType ?? "") else {
                if !(part.filename ?? "").isEmpty { hasUnsupportedCarrier = true }
                continue
            }
            guard let partID = part.partId, partIDs.insert(partID).inserted else { throw GmailIntakeError.integrity }
            let id = GmailInboxSource.deliveryID(account: state.account, messageID: message.id, partID: partID)
            let size = part.body?.size ?? 0
            let existing = state.sources[id]
            if let existing {
                guard existing.messageID == message.id, existing.partID == partID,
                      existing.expectedByteCount == size, existing.receivedMilliseconds == milliseconds else {
                    throw GmailIntakeError.integrity
                }
            }
            var source = existing ?? GmailInboxSource(id: id, account: state.account, messageID: message.id, partID: partID,
                originalFilename: part.filename ?? "", fileExtension: ext, mimeType: part.mimeType ?? "",
                sender: sender, family: family, receivedMilliseconds: milliseconds, expectedByteCount: size,
                retrievedAt: nil, sha256: nil, attention: .pending, dismissed: false)
            sourceIDs.append(id)
            if let sha = source.sha256, (try? inbox.original(sha256: sha, byteCount: size)) != nil {
                stats.reusedOriginals += 1
                source.acquisition = .available
                state.sources[id] = source
                continue
            }
            source.acquisition = .unavailable
            state.sources[id] = source
            guard let body = part.body, body.size > 0, body.size <= GmailClient.maximumOriginalBytes else {
                if size > GmailClient.maximumOriginalBytes { state.sources[id]?.acquisition = .sizeLimit }
                stats.unavailableOriginals += 1
                continue
            }
            candidates.append(.init(sourceID: id, body: body))
        }
        state.messages[message.id] = .init(messageID: message.id,
            outcome: sourceIDs.isEmpty ? (hasUnsupportedCarrier ? .unsupportedCarrier : .attachmentFree) : .attachments,
            receivedMilliseconds: milliseconds, sourceIDs: sourceIDs)
        // Preserve descriptors before any network request so an interruption can
        // resume every part, including repeated names and inline bodies.
        state = try inbox.save(state, originals: [:], expectedRevision: state.revision)
        let decodedMeter = GmailDecodedByteMeter()
        try await withThrowingTaskGroup(of: DownloadResult.self) { group in
            var next = 0
            func enqueue(_ download: Download) {
                group.addTask {
                    let start = ContinuousClock.now
                    do {
                        let bytes = try await client.original(messageID: message.id, body: download.body)
                        return .init(sourceID: download.sourceID, original: GmailDecodedOriginal(bytes: bytes, meter: decodedMeter),
                                     elapsedSeconds: Self.seconds(start.duration(to: .now)))
                    } catch GmailIntakeError.unavailable {
                        return .init(sourceID: download.sourceID, original: nil, elapsedSeconds: Self.seconds(start.duration(to: .now)))
                    }
                }
            }
            while next < min(2, candidates.count) { enqueue(candidates[next]); next += 1 }
            while let result = try await group.next() {
                try Task.checkCancellation()
                stats.downloadSeconds += result.elapsedSeconds
                if let bytes = result.original?.bytes {
                    guard var source = state.sources[result.sourceID] else { throw GmailIntakeError.integrity }
                    let digest = GmailInboxSource.digest(bytes)
                    if let known = source.sha256, known != digest { throw GmailIntakeError.integrity }
                    source.sha256 = digest; source.retrievedAt = Date()
                    source.acquisition = .available
                    state.sources[source.id] = source
                    state = try inbox.save(state, originals: [digest: bytes], expectedRevision: state.revision)
                    stats.downloadedOriginals += 1; stats.downloadedBytes += bytes.count
                    stats.peakDecodedBytes = max(stats.peakDecodedBytes, decodedMeter.peak)
                } else { stats.unavailableOriginals += 1 }
                if next < candidates.count { enqueue(candidates[next]); next += 1 }
            }
        }
        return state
    }

    nonisolated private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}

/// Measures lifetime of decoded originals waiting for or passing through the
/// atomic inbox write, including results completed out of task-group order.
nonisolated private final class GmailDecodedByteMeter: Sendable {
    private struct Counts { var current = 0; var peak = 0 }
    private let counts = Mutex(Counts())
    var peak: Int { counts.withLock { $0.peak } }
    func retain(_ size: Int) { counts.withLock { $0.current += size; $0.peak = max($0.peak, $0.current) } }
    func release(_ size: Int) { counts.withLock { $0.current -= size } }
}

nonisolated private final class GmailDecodedOriginal: Sendable {
    let bytes: Data
    private let meter: GmailDecodedByteMeter
    init(bytes: Data, meter: GmailDecodedByteMeter) {
        self.bytes = bytes; self.meter = meter; meter.retain(bytes.count)
    }
    deinit { meter.release(bytes.count) }
}
