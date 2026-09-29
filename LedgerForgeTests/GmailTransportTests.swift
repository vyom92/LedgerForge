import Foundation
import Testing
@testable import LedgerForge

/// Protocol/clock mechanics only. None of these bytes impersonates a statement
/// or enters a reader, parser, financial domain or financial repository.
@Suite(.serialized)
struct GmailTransportTests {
    @Test func selectedSendersAreExactFrozenAndCannotInjectSearchSyntax() throws {
        let selected: Set<String> = ["owner-added@example.invalid", "estatements@cbq.qa"]
        let interval = try GmailCollectionInterval(from: nil, until: Date(timeIntervalSince1970: 100),
                                                   timeZoneIdentifier: "UTC", senders: selected)
        #expect(interval.query == "before:100 {from:estatements@cbq.qa from:owner-added@example.invalid}")
        #expect(GmailNomination.family(sender: "owner-added@example.invalid", subject: "Attached file", selectedSenders: selected) == .other)
        #expect(GmailNomination.family(sender: "cc.statements@axisbank.com", subject: "Statement", selectedSenders: selected) == nil)
        #expect(try GmailSenderRule.validatedAddress(" OWNER-ADDED@EXAMPLE.INVALID ") == "owner-added@example.invalid")
        for invalid in ["", "Bank <bank@example.invalid>", "a@example.invalid} OR has:attachment", "a@b", "a@b.invalid\nfrom:*"] {
            #expect(throws: GmailIntakeError.invalidSender) { try GmailSenderRule.validatedAddress(invalid) }
        }
        #expect(throws: GmailIntakeError.invalidSender) {
            try GmailCollectionInterval(from: nil, until: Date(), timeZoneIdentifier: "UTC", senders: [])
        }
    }

    @Test func inclusiveCalendarDaysUseExactLocalInstants() throws {
        let zone = try #require(TimeZone(identifier: "Asia/Qatar"))
        let formatter = ISO8601DateFormatter()
        let day = try #require(formatter.date(from: "2026-08-01T12:00:00Z"))
        let now = try #require(formatter.date(from: "2026-09-17T11:13:18Z"))
        let interval = try GmailCollectionInterval.calendarDays(from: day, through: day, timeZone: zone, now: now)
        #expect(interval.from == formatter.date(from: "2026-07-31T21:00:00Z"))
        #expect(interval.until == formatter.date(from: "2026-08-01T21:00:00Z"))
        let lower = try #require(interval.from).timeIntervalSince1970 * 1_000
        #expect(interval.contains(milliseconds: Int64(lower)))
        #expect(!interval.contains(milliseconds: Int64(lower) - 1))
        #expect(!interval.contains(milliseconds: Int64(interval.until.timeIntervalSince1970 * 1_000)))
        #expect(interval.query.contains("after:"))
        #expect(!interval.query.contains("has:attachment"))
    }

    @Test func daylightSavingAndFrozenUpperBound() throws {
        let zone = try #require(TimeZone(identifier: "America/New_York"))
        let formatter = ISO8601DateFormatter()
        let day = try #require(formatter.date(from: "2026-03-08T12:00:00Z"))
        let next = try #require(formatter.date(from: "2026-03-10T00:00:00Z"))
        let interval = try GmailCollectionInterval.calendarDays(from: day, through: day, timeZone: zone, now: next)
        #expect(interval.until.timeIntervalSince(try #require(interval.from)) == 23 * 3_600)
        let active = try GmailCollectionInterval.calendarDays(from: day, through: next, timeZone: zone, now: day)
        #expect(active.until == day)
    }

    @Test func allHistoryIsExplicitAndStillHasAFixedEnd() throws {
        let end = Date(timeIntervalSince1970: 1_000)
        let interval = try GmailCollectionInterval(from: nil, until: end, timeZoneIdentifier: "UTC")
        #expect(!interval.query.contains("after:"))
        #expect(interval.query.contains("before:1000"))
        #expect(interval.contains(milliseconds: 0))
        #expect(!interval.contains(milliseconds: 1_000_000))
        #expect(throws: GmailIntakeError.invalidInterval) {
            try GmailCollectionInterval(from: end, until: end, timeZoneIdentifier: "UTC")
        }
    }

    @Test func exactOwnerNominationAndExclusions() {
        #expect(GmailNomination.approvedSenders.count == 15)
        #expect(GmailNomination.excludedSenders.count == 5)
        #expect(GmailNomination.family(sender: "Bank <ESTATEMENTS@CBQ.QA>", subject: "Credit Card Statement") == .cbqCard)
        #expect(GmailNomination.family(sender: "hdfcbanksmartstatement@hdfcbank.net", subject: "Combined Email Statement") == .hdfcBank)
        #expect(GmailNomination.family(sender: "cbadmin@cbq.com.qa", subject: "Statement") == nil)
        #expect(GmailNomination.family(sender: "peoplexnotification@qatarairways.com.qa", subject: "Roster Report") == nil)
        #expect(GmailNomination.family(sender: "peoplexnotification@qatarairways.com.qa", subject: "Adhoc Payment") == .salary)
        #expect(GmailNomination.family(sender: "forwarder@example.invalid", subject: "Bank Statement") == nil)
        #expect(GmailNomination.address("a@example.invalid,b@example.invalid") == nil)
    }

    @Test func octetStreamAndUnsupportedContainers() {
        #expect(GmailNomination.supportedCarrier(filename: "opaque  .pdf ", mimeType: "application/octet-stream") == "pdf")
        #expect(GmailNomination.supportedCarrier(filename: "", mimeType: "application/pdf") == "pdf")
        #expect(GmailNomination.supportedCarrier(filename: "opaque.zip", mimeType: "application/zip") == nil)
        #expect(GmailNomination.supportedCarrier(filename: "opaque.eml", mimeType: "message/rfc822") == nil)
        #expect(GmailNomination.supportedCarrier(filename: "smime.p7s", mimeType: "application/pkcs7-signature") == nil)
    }

    @Test func nestedMIMEPreservesRepeatedNamesAndDistinctParts() throws {
        let json = #"{"partId":"","mimeType":"multipart/mixed","parts":[{"partId":"0","mimeType":"multipart/related","parts":[{"partId":"0.0","filename":"same.pdf","body":{"size":3,"data":"YWJj"}}]},{"partId":"1","filename":"same.pdf","body":{"size":3,"attachmentId":"opaque"}}]}"#
        let root = try JSONDecoder().decode(GmailMessagePart.self, from: Data(json.utf8))
        let parts = try root.flattened()
        #expect(parts.map(\.partId) == ["", "0", "0.0", "1"])
        #expect(parts.filter { $0.filename == "same.pdf" }.count == 2)
    }

    @Test func exactDecodedBytesAndSizeAreRequired() throws {
        let bytes = Data([0, 0xff, 0xef, 17])
        let base64 = bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        #expect(try GmailClient.decodeOriginal(.init(attachmentId: nil, size: bytes.count, data: base64), expectedSize: bytes.count) == bytes)
        #expect(throws: GmailIntakeError.integrity) {
            try GmailClient.decodeOriginal(.init(attachmentId: nil, size: 3, data: base64), expectedSize: 3)
        }
        #expect(throws: GmailIntakeError.integrity) {
            try GmailClient.decodeOriginal(.init(attachmentId: nil, size: 3, data: "YW Jj"), expectedSize: 3)
        }
    }

    @Test func paginationRequestsIncludeSpamTrashAndCarryCursor() async throws {
        let transport = GmailTransportProbe(responses: [reply(#"{"messages":[{"id":"first"}],"nextPageToken":"second-page"}"#)])
        let client = GmailClient(expectedAccount: "owner@example.invalid", tokens: GmailTokenProbe(), transport: transport)
        let interval = try GmailCollectionInterval(from: nil, until: Date(timeIntervalSince1970: 1_000), timeZoneIdentifier: "UTC")
        let page = try await client.page(interval: interval, cursor: "first-page")
        #expect(page.messages?.map(\.id) == ["first"])
        #expect(page.nextPageToken == "second-page")
        let request = try #require(await transport.requests.first)
        let url = try #require(request.url)
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(query.contains(URLQueryItem(name: "includeSpamTrash", value: "true")))
        #expect(query.contains(URLQueryItem(name: "pageToken", value: "first-page")))
        #expect(request.httpMethod == "GET")
        #expect(request.url?.host == "gmail.googleapis.com")
    }

    @Test func expiredAccessTokenRefreshesOnceWithoutAnAutomaticRetrySchedule() async throws {
        let tokens = GmailTokenProbe()
        let transport = GmailTransportProbe(responses: [reply("", status: 401), reply(#"{"emailAddress":"owner@example.invalid"}"#)])
        try await GmailClient(expectedAccount: "owner@example.invalid", tokens: tokens, transport: transport).verifyAccount()
        #expect(await tokens.refreshRequests == [false, true])
        #expect(await transport.requests.count == 2)
    }

    @Test func exhaustedRateLimitRetriesRemainBoundedWithoutRefreshingCredentials() async throws {
        let limited = GmailTransportProbe(responses: Array(repeating:
            reply(#"{"error":{"errors":[{"reason":"userRateLimitExceeded"}]}}"#, status: 403), count: 7))
        let pauses = GmailPauseProbe()
        let tokens = GmailTokenProbe()
        await #expect(throws: GmailIntakeError.rateLimited) {
            try await GmailClient(expectedAccount: "owner@example.invalid", tokens: tokens, transport: limited,
                                  pause: { await pauses.record($0) }).verifyAccount()
        }
        #expect(await limited.requests.count == 7)
        #expect(await tokens.refreshRequests == Array(repeating: false, count: 7))
        let delays = await pauses.delays
        #expect(delays.count == 6)
        for (index, delay) in delays.enumerated() {
            let base = pow(2, Double(index))
            #expect((base...(base + 1)).contains(delay))
        }
    }

    @Test func transientRetryRetainsExactPageAndHonorsServerDelay() async throws {
        let transport = GmailTransportProbe(responses: [
            .init(statusCode: 429, data: Data(), retryAfter: "12"),
            reply("", status: 503), reply(#"{"messages":[{"id":"retained"}]}"#)
        ])
        let pauses = GmailPauseProbe()
        let interval = try GmailCollectionInterval(from: nil, until: Date(timeIntervalSince1970: 100), timeZoneIdentifier: "UTC")
        let client = GmailClient(expectedAccount: "owner@example.invalid", tokens: GmailTokenProbe(), transport: transport,
                                 pause: { await pauses.record($0) })
        let page = try await client.page(interval: interval, cursor: "retained-page")
        #expect(page.messages?.map(\.id) == ["retained"])
        let requests = await transport.requests
        #expect(requests.count == 3)
        #expect(Set(requests.compactMap(\.url)).count == 1)
        #expect(await pauses.delays.first == 12)
    }

    @Test func longServerHoldAndDailyQuotaStopWithoutEarlyRetry() async throws {
        for response in [GmailHTTPResponse(statusCode: 429, data: Data(), retryAfter: "61"),
                         reply(#"{"error":{"errors":[{"reason":"dailyLimitExceeded"}]}}"#, status: 403)] {
            let transport = GmailTransportProbe(responses: [response])
            let pauses = GmailPauseProbe()
            let client = GmailClient(expectedAccount: "owner@example.invalid", tokens: GmailTokenProbe(), transport: transport,
                                     pause: { await pauses.record($0) })
            await #expect(throws: GmailIntakeError.rateLimited) { try await client.verifyAccount() }
            #expect(await transport.requests.count == 1)
            #expect(await pauses.delays.isEmpty)
        }
        let now = Date(timeIntervalSince1970: 0)
        #expect(GmailClient.retryDelay(retries: 0, retryAfter: "Thu, 01 Jan 1970 00:00:30 GMT", now: now, jitter: 0) == 30)
        #expect(GmailClient.retryDelay(retries: 0, retryAfter: "Thu, 01 Jan 1970 00:02:00 GMT", now: now, jitter: 0) == nil)
    }

    @Test func cancellationDuringBackoffDoesNotIssueAnotherRequest() async throws {
        let transport = GmailTransportProbe(responses: [reply("", status: 429)])
        let client = GmailClient(expectedAccount: "owner@example.invalid", tokens: GmailTokenProbe(), transport: transport,
                                 pause: { _ in throw CancellationError() })
        await #expect(throws: CancellationError.self) { try await client.verifyAccount() }
        #expect(await transport.requests.count == 1)
    }

    @Test func revokedWrongAccountAndPermanentHTTPFailuresDoNotRetry() async throws {
        for (status, error) in [(401, GmailIntakeError.unauthorized), (403, .unauthorized), (404, .unavailable), (302, .invalidResponse)] {
            let transport = GmailTransportProbe(responses: [reply("", status: status), reply("", status: status)])
            let client = GmailClient(expectedAccount: "owner@example.invalid", tokens: GmailTokenProbe(), transport: transport)
            await #expect(throws: error) { try await client.verifyAccount() }
            #expect(await transport.requests.count == (status == 401 ? 2 : 1))
        }
        let transport = GmailTransportProbe(responses: [reply(#"{"emailAddress":"different@example.invalid"}"#)])
        let client = GmailClient(expectedAccount: "owner@example.invalid", tokens: GmailTokenProbe(), transport: transport)
        await #expect(throws: GmailIntakeError.accountMismatch) { try await client.verifyAccount() }
    }

    @Test func separateAndInlineBodiesYieldIdenticalOriginalBytes() async throws {
        let transport = GmailTransportProbe(responses: [reply(#"{"size":3,"data":"YWJj"}"#)])
        let client = GmailClient(expectedAccount: "owner@example.invalid", tokens: GmailTokenProbe(), transport: transport)
        let remote = try await client.original(messageID: "message", body: .init(attachmentId: "part/id", size: 3, data: nil))
        let inline = try await client.original(messageID: "message", body: .init(attachmentId: nil, size: 3, data: "YWJj"))
        #expect(remote == inline)
        #expect(await transport.requests.count == 1)
        #expect(await transport.requests.first?.url?.absoluteString.contains("part%2Fid") == true)
    }

    @Test func unavailableAndInterruptedOriginalNeverBecomesEmptyInput() async throws {
        let unavailable = GmailTransportProbe(responses: [reply("", status: 404)])
        let client = GmailClient(expectedAccount: "owner@example.invalid", tokens: GmailTokenProbe(), transport: unavailable)
        await #expect(throws: GmailIntakeError.unavailable) {
            try await client.original(messageID: "message", body: .init(attachmentId: "part", size: 3, data: nil))
        }
        let interrupted = GmailTransportProbe(responses: [], failure: .timedOut)
        let failedClient = GmailClient(expectedAccount: "owner@example.invalid", tokens: GmailTokenProbe(), transport: interrupted)
        await #expect(throws: GmailIntakeError.timedOut) { try await failedClient.verifyAccount() }
        await #expect(throws: GmailIntakeError.invalidLocator) {
            try await failedClient.message(id: "../unexpected")
        }
        #expect(await interrupted.requests.count == 1)
    }

    private func reply(_ json: String, status: Int = 200) -> GmailHTTPResponse {
        .init(statusCode: status, data: Data(json.utf8))
    }
}

private actor GmailPauseProbe {
    var delays: [TimeInterval] = []
    func record(_ delay: TimeInterval) { delays.append(delay) }
}

private actor GmailTokenProbe: GmailAccessTokenProvider {
    var refreshRequests: [Bool] = []
    func accessToken(refresh: Bool) -> String { refreshRequests.append(refresh); return "noncredential-mechanics-value" }
}

private actor GmailTransportProbe: GmailHTTPTransport {
    var requests: [URLRequest] = []
    var responses: [GmailHTTPResponse]
    let failure: GmailIntakeError?
    init(responses: [GmailHTTPResponse], failure: GmailIntakeError? = nil) { self.responses = responses; self.failure = failure }
    func send(_ request: URLRequest, maximumBytes: Int) throws -> GmailHTTPResponse {
        requests.append(request)
        if let failure { throw failure }
        guard !responses.isEmpty else { throw GmailIntakeError.invalidResponse }
        return responses.removeFirst()
    }
}
