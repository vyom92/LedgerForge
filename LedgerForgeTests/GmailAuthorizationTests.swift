import Foundation
import Synchronization
import Testing
@testable import LedgerForge

@Suite(.serialized)
struct GmailAuthorizationTests {
    private func grant(expired: Bool = true, secret: String? = "mechanics-client") -> GmailSavedGrant {
        .init(account: "mechanics@example.invalid", clientID: "mechanics-client-id", clientSecret: secret,
              accessToken: "mechanics-old", refreshToken: "mechanics-refresh", scope: GmailClient.readOnlyScope,
              expiresAt: expired ? 1 : 10_000)
    }
    private func response(scope: String = GmailClient.readOnlyScope, status: Int = 200) throws -> GmailHTTPResponse {
        .init(statusCode: status, data: try JSONSerialization.data(withJSONObject: [
            "access_token": "mechanics-new", "expires_in": 3_600, "token_type": "Bearer", "scope": scope
        ]))
    }

    @Test func unexpiredGrantNeedsNoRefreshOrWrite() async throws {
        let store = AuthorizationStoreProbe(grant())
        let transport = AuthorizationHTTPProbe(try response())
        let broker = GmailTokenBroker(store: store, transport: transport, now: { Date(timeIntervalSince1970: 0) })
        // Explicitly make the saved grant valid for the full safety margin.
        try store.updateExisting(grant(expired: false))
        #expect(try await broker.accessToken(refresh: false) == "mechanics-old")
        #expect(await transport.requests.count == 0)
        #expect(store.updates == 1)
    }

    @Test func expiredGrantRefreshIsCoalescedAndRetainsExactScope() async throws {
        let store = AuthorizationStoreProbe(grant())
        let transport = AuthorizationHTTPProbe(try response())
        let broker = GmailTokenBroker(store: store, transport: transport, now: { Date(timeIntervalSince1970: 100) })
        async let first = broker.accessToken(refresh: false)
        async let second = broker.accessToken(refresh: false)
        let values = try await [first, second]
        #expect(values == ["mechanics-new", "mechanics-new"])
        #expect(await transport.requests.count == 1)
        #expect(store.updates == 1)
        #expect(try store.load().scope == GmailClient.readOnlyScope)
        #expect(try store.load().refreshToken == "mechanics-refresh")
        #expect(try store.load().expiresAt == 3_700)
    }

    @Test func scopeExpansionAndRevocationNeverUpdateSavedGrant() async throws {
        for response in [try response(scope: GmailClient.readOnlyScope + " https://mail.google.com/"), try response(status: 400)] {
            let store = AuthorizationStoreProbe(grant())
            let broker = GmailTokenBroker(store: store, transport: AuthorizationHTTPProbe(response))
            await #expect(throws: GmailIntakeError.self) { try await broker.accessToken(refresh: false) }
            #expect(store.updates == 0)
            #expect(try store.load().accessToken == "mechanics-old")
        }
    }

    @Test func existingDesktopClientMustMatchTheSavedGrant() async throws {
        let store = AuthorizationStoreProbe(grant(secret: nil))
        let broker = GmailTokenBroker(store: store, transport: AuthorizationHTTPProbe(try response()))
        await #expect(throws: GmailIntakeError.configurationRequired) { try await broker.accessToken(refresh: false) }
        let wrong = Data(#"{"installed":{"client_id":"wrong-client","client_secret":"mechanics-only"}}"#.utf8)
        await #expect(throws: GmailIntakeError.accountMismatch) { try await broker.configureExistingClient(wrong) }
        #expect(store.updates == 0)
        let matching = Data(#"{"installed":{"client_id":"mechanics-client-id","client_secret":"mechanics-only"}}"#.utf8)
        try await broker.configureExistingClient(matching)
        #expect(try store.load().clientSecret == "mechanics-only")
        #expect(store.updates == 1)
    }

    @Test func tokenFormEncodingPreservesReservedCharacters() throws {
        let request = try GmailTokenBroker.tokenRequest(["opaque": "a+b&c=d /é"])
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://oauth2.googleapis.com/token")
        #expect(String(data: try #require(request.httpBody), encoding: .utf8) == "opaque=a%2Bb%26c%3Dd%20%2F%C3%A9")
    }

    @Test func loopbackCallbackRequiresExactStateHostAndUniqueCode() {
        let redirect = "http://127.0.0.1:40123/oauth/callback"
        let valid = "GET /oauth/callback?state=opaque-state&code=opaque-code HTTP/1.1\r\nHost: 127.0.0.1:40123\r\n\r\n"
        #expect(GmailOAuthAuthorization.validateCallback(valid, expectedState: "opaque-state", redirectURI: redirect) == .code("opaque-code"))
        for invalid in [valid.replacingOccurrences(of: "opaque-state", with: "wrong"),
                        valid.replacingOccurrences(of: "Host: 127.0.0.1", with: "Host: remote.invalid"),
                        valid.replacingOccurrences(of: "&code=", with: "&state=opaque-state&code="),
                        valid.replacingOccurrences(of: " HTTP/1.1", with: "&code=second HTTP/1.1"),
                        valid.replacingOccurrences(of: "/oauth/callback", with: "/unexpected"),
                        valid.replacingOccurrences(of: "&code=", with: "&error=access_denied&code=")] {
            #expect(GmailOAuthAuthorization.validateCallback(invalid, expectedState: "opaque-state", redirectURI: redirect) == nil)
        }
    }

    @Test @MainActor func verifiedDenialDispatchFinishesOnceAndCleansUpPromptly() async {
        let flow = GmailOAuthAuthorization()
        let redirect = "http://127.0.0.1:40123/oauth/callback"
        let denial = "GET /oauth/callback?state=opaque-state&error=access_denied HTTP/1.1\r\nHost: 127.0.0.1:40123\r\n\r\n"
        var cleanups = 0
        var responses: [Bool] = []
        var firstDispatch = false
        var repeatedDispatch = true
        var cleanupsDuringResponse: Int?
        var cleanupsAfterDispatch: Int?
        await #expect(throws: GmailIntakeError.authorizationFailed) {
            try await flow.waitForCallback(timeoutDuration: .seconds(1), start: {
                firstDispatch = flow.dispatchCallback(denial, expectedState: "opaque-state", redirectURI: redirect) { accepted in
                    cleanupsDuringResponse = cleanups
                    responses.append(accepted)
                }
                cleanupsAfterDispatch = cleanups
                repeatedDispatch = flow.dispatchCallback(denial, expectedState: "opaque-state", redirectURI: redirect) { responses.append($0) }
            }, cleanup: { cleanups += 1 })
        }
        #expect(firstDispatch && !repeatedDispatch)
        #expect(cleanupsDuringResponse == 0)
        #expect(cleanupsAfterDispatch == 1)
        #expect(cleanups == 1)
        #expect(responses == [true])
    }

    @Test @MainActor func invalidCallbacksLeaveTheWaitOpenForAValidCode() async throws {
        let flow = GmailOAuthAuthorization()
        let redirect = "http://127.0.0.1:40123/oauth/callback"
        let denial = "GET /oauth/callback?state=opaque-state&error=access_denied HTTP/1.1\r\nHost: 127.0.0.1:40123\r\n\r\n"
        let valid = "GET /oauth/callback?state=opaque-state&code=opaque%2Bcode HTTP/1.1\r\nHost: 127.0.0.1:40123\r\n\r\n"
        let invalid = [
            denial.replacingOccurrences(of: "opaque-state", with: "wrong-state"),
            denial.replacingOccurrences(of: "state=opaque-state&", with: ""),
            denial.replacingOccurrences(of: "&error=", with: "&state=opaque-state&error="),
            denial.replacingOccurrences(of: "&error=", with: "&code=opaque-code&error="),
            denial.replacingOccurrences(of: "&error=", with: "&error=server_error&error="),
            denial.replacingOccurrences(of: "access_denied", with: ""),
            denial.replacingOccurrences(of: "access_denied", with: "%20"),
            denial.replacingOccurrences(of: "access_denied", with: "%GG"),
            denial.replacingOccurrences(of: "access_denied", with: "access_denied#fragment"),
            denial.replacingOccurrences(of: "GET ", with: "POST "),
            denial.replacingOccurrences(of: "/oauth/callback", with: "/unexpected"),
            denial.replacingOccurrences(of: "Host: 127.0.0.1", with: "Host: remote.invalid"),
            denial.replacingOccurrences(of: "40123\r\n", with: "40123\r\nHost: 127.0.0.1:40123\r\n"),
            denial.replacingOccurrences(of: "\r\nHost:", with: "\r\n\r\nHost:"),
            denial.replacingOccurrences(of: "\r\n\r\n", with: "\r\n"),
            denial.replacingOccurrences(of: "&error=access_denied", with: ""),
            valid.replacingOccurrences(of: "&code=", with: "&code=another&code=")
        ]
        var cleanups = 0
        var responses: [Bool] = []
        let code = try await flow.waitForCallback(timeoutDuration: .seconds(1), start: {
            for request in invalid {
                #expect(!flow.dispatchCallback(request, expectedState: "opaque-state", redirectURI: redirect) { responses.append($0) })
                #expect(cleanups == 0)
            }
            #expect(flow.dispatchCallback(valid, expectedState: "opaque-state", redirectURI: redirect) { responses.append($0) })
            #expect(!flow.dispatchCallback(denial, expectedState: "opaque-state", redirectURI: redirect))
        }, cleanup: { cleanups += 1 })
        #expect(code.code == "opaque+code")
        #expect(code.redirectURI == redirect)
        #expect(responses == Array(repeating: false, count: invalid.count) + [true])
        #expect(cleanups == 1)
    }

    @Test @MainActor func callbackTimeoutFinishesOnceAndRejectsLateSuccess() async {
        let flow = GmailOAuthAuthorization()
        var cleanups = 0
        await #expect(throws: GmailIntakeError.timedOut) {
            try await flow.waitForCallback(timeoutDuration: .milliseconds(1), start: {}, cleanup: { cleanups += 1 })
        }
        #expect(!flow.dispatchCallback(
            "GET /oauth/callback?state=opaque-state&code=late-code HTTP/1.1\r\nHost: 127.0.0.1:40123\r\n\r\n",
            expectedState: "opaque-state", redirectURI: "http://127.0.0.1:40123/oauth/callback"))
        #expect(cleanups == 1)
    }

    @Test @MainActor func callbackCancellationFinishesOnceAndRejectsLateDenial() async {
        let flow = GmailOAuthAuthorization()
        let started = AsyncStream<Void>.makeStream()
        defer { started.continuation.finish() }
        var cleanups = 0
        let pending = Task {
            try await flow.waitForCallback(start: { started.continuation.yield(()) }, cleanup: { cleanups += 1 })
        }
        var iterator = started.stream.makeAsyncIterator()
        _ = await iterator.next()
        pending.cancel()
        await #expect(throws: CancellationError.self) { try await pending.value }
        pending.cancel()
        #expect(!flow.dispatchCallback(
            "GET /oauth/callback?state=opaque-state&error=access_denied HTTP/1.1\r\nHost: 127.0.0.1:40123\r\n\r\n",
            expectedState: "opaque-state", redirectURI: "http://127.0.0.1:40123/oauth/callback"))
        #expect(cleanups == 1)
    }

    @Test @MainActor func deniedConnectionPreservesTheGrantAndAllowsAnotherAttempt() async throws {
        let original = grant()
        let store = AuthorizationStoreProbe(original)
        let transport = AuthorizationHTTPProbe(try response())
        let broker = GmailTokenBroker(store: store, transport: transport)
        let suite = "LedgerForge.OAuth.Callback.\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let session = GmailIntakeSession(tokens: broker, preferences: preferences)
        let flow = GmailOAuthAuthorization()
        var cleanups = 0
        let attempt = try #require(session.connect {
            try await broker.reauthorizeExistingConnection { current, _ in
                _ = try await flow.waitForCallback(timeoutDuration: .seconds(1), start: {
                    #expect(flow.dispatchCallback(
                        "GET /oauth/callback?state=opaque-state&error=access_denied HTTP/1.1\r\nHost: 127.0.0.1:40123\r\n\r\n",
                        expectedState: "opaque-state", redirectURI: "http://127.0.0.1:40123/oauth/callback"))
                }, cleanup: { cleanups += 1 })
                Issue.record("A denied callback continued authorization.")
                return current
            }
        })
        #expect(session.isChecking)
        await attempt.value
        #expect(!session.isChecking)
        #expect(!session.isConnected)
        #expect(session.needsAuthorization)
        #expect(!session.needsClientConfiguration)
        #expect(session.message == GmailIntakeError.authorizationFailed.localizedDescription)
        #expect(cleanups == 1)
        #expect(store.updates == 0)
        #expect(try store.load() == original)
        #expect(await transport.requests.isEmpty)

        var retried = false
        let retry = try #require(session.connect {
            retried = true
            throw GmailIntakeError.authorizationFailed
        })
        #expect(session.isChecking)
        await retry.value
        #expect(retried)
        #expect(!session.isChecking)
        #expect(session.needsAuthorization)
        #expect(store.updates == 0)
    }

    @Test func cancelledRefreshDoesNotWriteAnUnobservedGrant() async throws {
        let store = AuthorizationStoreProbe(grant())
        let transport = AuthorizationHTTPProbe(try response(), suspend: true)
        let broker = GmailTokenBroker(store: store, transport: transport)
        let task = Task { try await broker.accessToken(refresh: false) }
        for _ in 0..<1_000 {
            if await transport.requests.count > 0 { break }
            await Task.yield()
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(store.updates == 0)
    }
}

nonisolated private final class AuthorizationStoreProbe: GmailGrantStore, Sendable {
    private struct State: Sendable { var grant: GmailSavedGrant; var updates = 0 }
    private let state: Mutex<State>
    init(_ grant: GmailSavedGrant) { state = Mutex(State(grant: grant)) }
    var updates: Int { state.withLock { $0.updates } }
    func load() throws -> GmailSavedGrant { state.withLock { $0.grant } }
    func updateExisting(_ grant: GmailSavedGrant) throws { state.withLock { $0.grant = grant; $0.updates += 1 } }
}

private actor AuthorizationHTTPProbe: GmailHTTPTransport {
    let response: GmailHTTPResponse
    let suspend: Bool
    var requests: [URLRequest] = []
    init(_ response: GmailHTTPResponse, suspend: Bool = false) { self.response = response; self.suspend = suspend }
    func send(_ request: URLRequest, maximumBytes: Int) async throws -> GmailHTTPResponse {
        requests.append(request)
        if suspend { try await Task.sleep(for: .seconds(30)) }
        return response
    }
}
