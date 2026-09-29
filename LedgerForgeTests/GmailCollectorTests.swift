import Foundation
import Testing
@testable import LedgerForge

/// Only mail protocol envelopes and opaque transport bytes, never financial
/// source substitutes. No reader/parser or financial commit is invoked.
@Suite(.serialized)
struct GmailCollectorTests {
    @Test func returnedUnselectedSenderCannotEnterInboxAndNewScanRetainsPriorOriginals() async throws {
        let repository = InMemoryGmailInboxRepository()
        let transport = CollectorHTTPProbe(replies: [
            "profile": [json(["emailAddress": account]), json(["emailAddress": account])],
            "page": [json(["messages": [["id": "one"], ["id": "missing"]]]), json(["messages": [["id": "two"]]])],
            "one": [message(id: "one", attached: true)], "two": [message(id: "two", attached: true)]])
        await #expect(throws: GmailIntakeError.network) {
            try await GmailCollector().collect(client: client(transport), inbox: repository, interval: interval())
        }
        let narrowed = try GmailCollectionInterval(from: nil, until: Date(timeIntervalSince1970: 20),
                                                  timeZoneIdentifier: "UTC", senders: ["custom@example.invalid"])
        _ = try await GmailCollector().collect(client: client(transport), inbox: repository,
                                               interval: narrowed, replaceIncomplete: true)
        let state = try repository.load(account: account)
        #expect(state.sources.count == 1)
        #expect(state.messages["two"]?.outcome == .excluded)
        #expect(state.completedIntervals == [narrowed])
        #expect(state.activeScan == nil)
    }

    private let account = "mechanics@example.invalid"

    @Test func drainsEveryPageAndKeepsAttachmentFreeOutcomes() async throws {
        let transport = CollectorHTTPProbe(replies: [
            "profile": [json(["emailAddress": account])],
            "page": [json(["messages": [["id": "one"]], "nextPageToken": "next"]), json(["messages": [["id": "one"], ["id": "two"]]])],
            "one": [message(id: "one", attached: true)], "two": [message(id: "two", attached: false)]
        ])
        let repository = InMemoryGmailInboxRepository()
        let result = try await GmailCollector().collect(client: client(transport), inbox: repository, interval: interval())
        let state = try repository.load(account: account)
        #expect(result.isComplete && result.accountedMessages == 2)
        #expect(state.completedIntervals == [try interval()])
        #expect(state.activeScan == nil)
        #expect(state.sources.count == 1)
        #expect(state.messages["two"]?.outcome == .attachmentFree)
        #expect(await transport.count("page") == 2)
        #expect(await transport.count("one") == 1)
    }

    @Test func partialScanResumesWithoutLosingAlreadyFetchedOriginal() async throws {
        let repository = InMemoryGmailInboxRepository()
        let first = CollectorHTTPProbe(replies: ["profile": [json(["emailAddress": account])],
            "page": [json(["messages": [["id": "one"], ["id": "two"]]])],
            "one": [message(id: "one", attached: true)]])
        await #expect(throws: GmailIntakeError.network) {
            try await GmailCollector().collect(client: client(first), inbox: repository, interval: interval())
        }
        let partial = try repository.load(account: account)
        #expect(partial.completedThrough == nil)
        #expect(partial.activeScan?.pendingMessageIDs == ["two"])
        #expect(partial.sources.count == 1)
        let second = CollectorHTTPProbe(replies: ["profile": [json(["emailAddress": account])], "two": [message(id: "two", attached: true)]])
        let result = try await GmailCollector().collect(client: client(second), inbox: repository, interval: nil)
        #expect(result.isComplete)
        #expect(await second.count("page") == 0)
        #expect(await second.count("one") == 0)
        #expect(try repository.load(account: account).sources.count == 2)
    }

    @Test func repeatScanPreservesDismissalAndFinancialHoldWithCacheOnlyReuse() async throws {
        let repository = InMemoryGmailInboxRepository()
        let transport = CollectorHTTPProbe(replies: ["profile": [json(["emailAddress": account]), json(["emailAddress": account])],
            "page": [json(["messages": [["id": "one"]]]), json(["messages": [["id": "one"]]])],
            "one": [message(id: "one", attached: true), message(id: "one", attached: true)]])
        _ = try await GmailCollector().collect(client: client(transport), inbox: repository, interval: interval())
        var state = try repository.load(account: account)
        let id = try #require(state.sources.keys.first)
        state.sources[id]?.dismissed = true
        state.sources[id]?.attention = .unsupported
        _ = try repository.save(state, originals: [:], expectedRevision: state.revision)
        let replay = try await GmailCollector().collect(client: client(transport), inbox: repository, interval: interval())
        let after = try repository.load(account: account)
        #expect(replay.downloadedOriginals == 0 && replay.reusedOriginals == 1)
        #expect(after.sources[id]?.dismissed == true)
        #expect(after.sources[id]?.attention == .unsupported)
        #expect(after.completedIntervals.count == 1)
    }

    @Test func repeatedPageCursorCannotAdvanceCoverage() async throws {
        let repository = InMemoryGmailInboxRepository()
        let transport = CollectorHTTPProbe(replies: ["profile": [json(["emailAddress": account])],
            "page": [json(["messages": [["id": "one"]], "nextPageToken": "again"]), json(["nextPageToken": "again"])],
            "one": [message(id: "one", attached: true)]])
        await #expect(throws: GmailIntakeError.repeatedPage) {
            try await GmailCollector().collect(client: client(transport), inbox: repository, interval: interval())
        }
        #expect(try repository.load(account: account).completedThrough == nil)
        #expect(try repository.load(account: account).sources.count == 1)
    }

    @Test func actualDeliveryTimeOverridesSearchAndStatementSubject() async throws {
        let repository = InMemoryGmailInboxRepository()
        let transport = CollectorHTTPProbe(replies: ["profile": [json(["emailAddress": account])],
            "page": [json(["messages": [["id": "one"], ["id": "two"]]])],
            "one": [message(id: "one", attached: true, milliseconds: "999")],
            "two": [message(id: "two", attached: true, milliseconds: "2000")]])
        let bounds = try GmailCollectionInterval(from: Date(timeIntervalSince1970: 1), until: Date(timeIntervalSince1970: 2), timeZoneIdentifier: "UTC")
        _ = try await GmailCollector().collect(client: client(transport), inbox: repository, interval: bounds)
        let state = try repository.load(account: account)
        #expect(state.sources.isEmpty)
        #expect(state.messages.values.allSatisfy { $0.outcome == .outsideInterval })
    }

    @Test func unavailableAttachmentStaysHeldAndReachableAfterCompletedCoverage() async throws {
        let repository = InMemoryGmailInboxRepository()
        let transport = CollectorHTTPProbe(replies: ["profile": [json(["emailAddress": account])],
            "page": [json(["messages": [["id": "one"]]])],
            "one": [message(id: "one", attached: true, remote: true)],
            "attachment": [.init(statusCode: 404, data: Data())]])
        let result = try await GmailCollector().collect(client: client(transport), inbox: repository, interval: interval())
        let source = try #require(repository.load(account: account).sources.values.first)
        #expect(result.isComplete && result.unavailableOriginals == 1)
        #expect(source.acquisition == .unavailable && source.sha256 == nil)
        #expect(source.messageID == "one" && source.partID == "0")
    }

    @Test func cancellationRetainsTheFrozenIncompleteScan() async throws {
        let repository = InMemoryGmailInboxRepository()
        let transport = CollectorHTTPProbe(replies: ["profile": [json(["emailAddress": account])],
            "page": [json(["messages": [["id": "one"]]])],
            "one": [message(id: "one", attached: true, remote: true)]], suspendAttachment: true)
        let client = client(transport), interval = try interval()
        let task = Task { try await GmailCollector().collect(client: client, inbox: repository, interval: interval) }
        for _ in 0..<1_000 {
            if await transport.count("attachment") > 0 { break }
            await Task.yield()
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        let state = try repository.load(account: account)
        #expect(state.completedThrough == nil)
        #expect(state.activeScan?.interval == interval)
        #expect(state.sources.values.allSatisfy { $0.sha256 == nil })
    }

    private func interval() throws -> GmailCollectionInterval {
        try .init(from: nil, until: Date(timeIntervalSince1970: 10), timeZoneIdentifier: "UTC")
    }
    private func client(_ transport: CollectorHTTPProbe) -> GmailClient {
        .init(expectedAccount: account, tokens: CollectorTokenProbe(), transport: transport)
    }
    private func json(_ value: [String: Any]) -> GmailHTTPResponse {
        .init(statusCode: 200, data: try! JSONSerialization.data(withJSONObject: value))
    }
    private func message(id: String, attached: Bool, milliseconds: String = "1000", remote: Bool = false) -> GmailHTTPResponse {
        var payload: [String: Any] = ["partId": "", "mimeType": "multipart/mixed", "headers": [
            ["name": "From", "value": "estatements@cbq.qa"], ["name": "Subject", "value": "Statement transport mechanics"]]]
        if attached {
            var body: [String: Any] = ["size": 3]
            body[remote ? "attachmentId" : "data"] = remote ? "opaque" : "YWJj"
            payload["parts"] = [["partId": "0", "mimeType": "application/octet-stream", "filename": "opaque.pdf", "body": body]]
        }
        return json(["id": id, "internalDate": milliseconds, "payload": payload])
    }
}

private struct CollectorTokenProbe: GmailAccessTokenProvider {
    func accessToken(refresh: Bool) async throws -> String { "transport-mechanics-only" }
}
private actor CollectorHTTPProbe: GmailHTTPTransport {
    var replies: [String: [GmailHTTPResponse]]
    var counts: [String: Int] = [:]
    let suspendAttachment: Bool
    init(replies: [String: [GmailHTTPResponse]], suspendAttachment: Bool = false) {
        self.replies = replies; self.suspendAttachment = suspendAttachment
    }
    func count(_ key: String) -> Int { counts[key] ?? 0 }
    func send(_ request: URLRequest, maximumBytes: Int) async throws -> GmailHTTPResponse {
        let path = request.url?.path ?? ""
        let key = path.contains("/attachments/") ? "attachment" : path.hasSuffix("/messages") ? "page" : request.url?.lastPathComponent ?? ""
        counts[key, default: 0] += 1
        if key == "attachment", suspendAttachment { try await Task.sleep(for: .seconds(30)) }
        guard var responses = replies[key], !responses.isEmpty else { throw GmailIntakeError.network }
        let response = responses.removeFirst(); replies[key] = responses
        return response
    }
}
