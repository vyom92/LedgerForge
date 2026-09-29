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
        #expect(GmailOAuthAuthorization.validateCallback(valid, expectedState: "opaque-state", redirectURI: redirect) == "opaque-code")
        for invalid in [valid.replacingOccurrences(of: "opaque-state", with: "wrong"),
                        valid.replacingOccurrences(of: "Host: 127.0.0.1", with: "Host: remote.invalid"),
                        valid.replacingOccurrences(of: "&code=", with: "&state=opaque-state&code="),
                        valid.replacingOccurrences(of: " HTTP/1.1", with: "&code=second HTTP/1.1"),
                        valid.replacingOccurrences(of: "/oauth/callback", with: "/unexpected"),
                        valid.replacingOccurrences(of: "&code=", with: "&error=access_denied&code=")] {
            #expect(GmailOAuthAuthorization.validateCallback(invalid, expectedState: "opaque-state", redirectURI: redirect) == nil)
        }
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
