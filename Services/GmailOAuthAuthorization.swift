import CryptoKit
import Foundation
import Network
import Security
#if os(macOS)
import AppKit
#endif

/// The qualified Desktop OAuth flow expressed natively: loopback-only callback,
/// PKCE S256, exact state/account/scope, the owner's existing client and grant.
/// No server survives this explicit connection operation.
@MainActor
final class GmailOAuthAuthorization {
    nonisolated enum Callback: Equatable, Sendable {
        case code(String)
        case authorizationFailed
    }

    private var listener: NWListener?
    private var continuation: CheckedContinuation<(code: String, redirectURI: String), Error>?
    private var timeout: Task<Void, Never>?
    private var cleanup: (() -> Void)?
    private var state = ""
    private var redirectURI = ""
    private var browserOpened = false

    static func authorize(current: GmailSavedGrant, transport: any GmailHTTPTransport) async throws -> GmailSavedGrant {
        try current.validate()
        guard let secret = current.clientSecret else { throw GmailIntakeError.configurationRequired }
        let verifier = try randomString()
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let flow = GmailOAuthAuthorization()
        let callback = try await flow.waitForCode(account: current.account, clientID: current.clientID, challenge: challenge)
        try Task.checkCancellation()
        let request = try GmailTokenBroker.tokenRequest([
            "client_id": current.clientID, "client_secret": secret, "code": callback.code,
            "redirect_uri": callback.redirectURI, "grant_type": "authorization_code", "code_verifier": verifier
        ])
        let response = try await transport.send(request, maximumBytes: 32_768)
        guard response.statusCode == 200,
              let token = try? JSONDecoder().decode(GmailTokenBroker.TokenResponse.self, from: response.data),
              !token.access_token.isEmpty, token.expires_in > 0, token.token_type.lowercased() == "bearer",
              let scope = token.scope else { throw GmailIntakeError.unauthorized }
        guard Set(scope.split(whereSeparator: \.isWhitespace).map(String.init)) == [GmailClient.readOnlyScope] else {
            throw GmailIntakeError.scopeMismatch
        }
        let renewed = GmailSavedGrant(account: current.account, clientID: current.clientID, clientSecret: secret,
            accessToken: token.access_token, refreshToken: token.refresh_token ?? current.refreshToken,
            scope: scope, expiresAt: Date().timeIntervalSince1970 + Double(token.expires_in))
        try renewed.validate()
        try await GmailClient(expectedAccount: current.account,
                              tokens: AuthorizedToken(value: renewed.accessToken), transport: transport).verifyAccount()
        return renewed
    }

    private func waitForCode(account: String, clientID: String, challenge: String) async throws -> (code: String, redirectURI: String) {
#if os(macOS)
        try Task.checkCancellation()
        state = try Self.randomString()
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let listener = try NWListener(using: parameters, on: .any)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.receive(connection, data: Data()) }
        }
        listener.stateUpdateHandler = { [weak self] status in
            Task { @MainActor in
                guard let self, self.continuation != nil else { return }
                switch status {
                case .ready:
                    guard !self.browserOpened, let port = listener.port else { return }
                    self.redirectURI = "http://127.0.0.1:\(port.rawValue)/oauth/callback"
                    guard var url = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth") else {
                        self.finish(.failure(GmailIntakeError.invalidResponse)); return
                    }
                    url.queryItems = [
                        .init(name: "client_id", value: clientID), .init(name: "redirect_uri", value: self.redirectURI),
                        .init(name: "response_type", value: "code"), .init(name: "scope", value: GmailClient.readOnlyScope),
                        .init(name: "state", value: self.state), .init(name: "code_challenge", value: challenge),
                        .init(name: "code_challenge_method", value: "S256"), .init(name: "access_type", value: "offline"),
                        .init(name: "prompt", value: "consent"), .init(name: "login_hint", value: account)
                    ]
                    guard let destination = url.url, NSWorkspace.shared.open(destination) else {
                        self.finish(.failure(GmailIntakeError.network)); return
                    }
                    self.browserOpened = true
                case .failed: self.finish(.failure(GmailIntakeError.network))
                case .cancelled: self.finish(.failure(CancellationError()))
                default: break
                }
            }
        }
        return try await waitForCallback(start: {
            listener.start(queue: .global(qos: .userInitiated))
        }, cleanup: { [weak self] in
            self?.listener?.cancel(); self?.listener = nil
            self?.state = ""; self?.redirectURI = ""
        })
#else
        throw GmailIntakeError.configurationRequired
#endif
    }

    /// The listener and source-independent checks share the same pending wait,
    /// cancellation, timeout and single cleanup owner.
    func waitForCallback(timeoutDuration: Duration = .seconds(180), start: () -> Void,
                         cleanup: @escaping () -> Void) async throws -> (code: String, redirectURI: String) {
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.cleanup = cleanup
                timeout = Task { @concurrent [weak self] in
                    do { try await Task.sleep(for: timeoutDuration) }
                    catch { return }
                    await self?.finish(.failure(GmailIntakeError.timedOut))
                }
                guard !Task.isCancelled else { finish(.failure(CancellationError())); return }
                start()
            }
        } onCancel: { Task { @MainActor in self.finish(.failure(CancellationError())) } }
    }

    private func receive(_ connection: NWConnection, data initial: Data) {
        if initial.isEmpty { connection.start(queue: .global(qos: .userInitiated)) }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384 - initial.count) { [weak self] chunk, _, complete, error in
            Task { @MainActor in
                guard let self, self.continuation != nil else { connection.cancel(); return }
                var data = initial
                if let chunk { data.append(chunk) }
                guard error == nil, data.count < 16_384 else { connection.cancel(); return }
                guard let text = String(data: data, encoding: .utf8), text.contains("\r\n\r\n") else {
                    if complete { connection.cancel() } else { self.receive(connection, data: data) }
                    return
                }
                self.dispatchCallback(text, expectedState: self.state, redirectURI: self.redirectURI) { accepted in
                    let body = "You can return to LedgerForge."
                    let response = "HTTP/1.1 \(accepted ? "200 OK" : "400 Bad Request")\r\nContent-Type: text/plain\r\nCache-Control: no-store\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
                    connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
                }
            }
        }
    }

    @discardableResult
    func dispatchCallback(_ request: String, expectedState: String, redirectURI: String,
                          respond: (Bool) -> Void = { _ in }) -> Bool {
        guard continuation != nil else { return false }
        let callback = Self.validateCallback(request, expectedState: expectedState, redirectURI: redirectURI)
        respond(callback != nil)
        switch callback {
        case .code(let code): finish(.success((code, redirectURI)))
        case .authorizationFailed: finish(.failure(GmailIntakeError.authorizationFailed))
        case nil: return false
        }
        return true
    }

    nonisolated static func validateCallback(_ request: String, expectedState: String, redirectURI: String) -> Callback? {
        guard let redirect = URLComponents(string: redirectURI), let port = redirect.port else { return nil }
        guard let headerEnd = request.range(of: "\r\n\r\n") else { return nil }
        let lines = String(request[..<headerEnd.lowerBound]).components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let start = first.split(separator: " ")
        guard start.count == 3, start[0] == "GET", start[2] == "HTTP/1.1",
              String(start[1]).removingPercentEncoding != nil,
              let callback = URLComponents(string: String(start[1])), callback.scheme == nil,
              callback.host == nil, callback.fragment == nil, callback.path == "/oauth/callback",
              lines.filter({ $0.lowercased().hasPrefix("host:") }).map({ $0.dropFirst(5).trimmingCharacters(in: .whitespaces) }) == ["127.0.0.1:\(port)"] else { return nil }
        let states = callback.queryItems?.filter { $0.name == "state" } ?? []
        let codes = callback.queryItems?.filter { $0.name == "code" } ?? []
        let errors = callback.queryItems?.filter { $0.name == "error" } ?? []
        guard states.count == 1, states[0].value == expectedState, !expectedState.isEmpty else { return nil }
        if codes.count == 1, errors.isEmpty, let code = codes[0].value, !code.isEmpty { return .code(code) }
        guard codes.isEmpty, errors.count == 1, let error = errors[0].value, !error.isEmpty,
              error.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0)
                  || (48...57).contains($0) || [45, 46, 95].contains($0) }) else { return nil }
        return .authorizationFailed
    }

    private func finish(_ result: Result<(code: String, redirectURI: String), Error>) {
        guard let continuation = self.continuation else { return }
        self.continuation = nil
        timeout?.cancel(); timeout = nil
        let cleanup = self.cleanup
        self.cleanup = nil
        cleanup?()
        continuation.resume(with: result)
    }

    nonisolated private static func randomString() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 48)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw GmailIntakeError.unavailable }
        return base64URL(Data(bytes))
    }
    nonisolated private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    nonisolated private struct AuthorizedToken: GmailAccessTokenProvider {
        let value: String
        func accessToken(refresh: Bool) async throws -> String { value }
    }
}

// Foreground authorization stays out of the scheduled helper target.
extension GmailTokenBroker {
    func reauthorizeExistingConnection(
        authorize: @MainActor @Sendable (GmailSavedGrant, any GmailHTTPTransport) async throws -> GmailSavedGrant
            = GmailOAuthAuthorization.authorize
    ) async throws {
        guard refreshTask == nil else { throw GmailIntakeError.busy }
        let current = try store.load()
        let renewed = try await authorize(current, transport)
        try Task.checkCancellation()
        try store.updateExisting(renewed)
        grant = renewed
    }

}
