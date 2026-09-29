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
    private var listener: NWListener?
    private var continuation: CheckedContinuation<(code: String, redirectURI: String), Error>?
    private var timeout: Task<Void, Never>?
    private var state = ""
    private var redirectURI = ""
    private var browserOpened = false

    static func authorize(current: GmailSavedGrant, transport: any GmailHTTPTransport) async throws -> GmailSavedGrant {
        try current.validate()
        guard let secret = current.clientSecret else { throw GmailIntakeError.configurationRequired }
        let verifier = try randomString()
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let flow = GmailOAuthAuthorization()
        let callback = try await withTaskCancellationHandler {
            try await flow.waitForCode(account: current.account, clientID: current.clientID, challenge: challenge)
        } onCancel: { Task { @MainActor in flow.finish(.failure(CancellationError())) } }
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
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            listener.start(queue: .global(qos: .userInitiated))
            timeout = Task { @concurrent [weak self] in
                do { try await Task.sleep(for: .seconds(180)) }
                catch { return }
                await self?.finish(.failure(GmailIntakeError.timedOut))
            }
        }
#else
        throw GmailIntakeError.configurationRequired
#endif
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
                let result = Self.validateCallback(text, expectedState: self.state, redirectURI: self.redirectURI)
                let body = "You can return to LedgerForge."
                let response = "HTTP/1.1 \(result == nil ? "400 Bad Request" : "200 OK")\r\nContent-Type: text/plain\r\nCache-Control: no-store\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
                if let result { self.finish(.success((result, self.redirectURI))) }
            }
        }
    }

    nonisolated static func validateCallback(_ request: String, expectedState: String, redirectURI: String) -> String? {
        guard let redirect = URLComponents(string: redirectURI), let port = redirect.port else { return nil }
        let lines = request.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let start = first.split(separator: " ")
        guard start.count == 3, start[0] == "GET", start[2] == "HTTP/1.1",
              let callback = URLComponents(string: String(start[1])), callback.scheme == nil,
              callback.host == nil, callback.path == "/oauth/callback",
              lines.filter({ $0.lowercased().hasPrefix("host:") }).map({ $0.dropFirst(5).trimmingCharacters(in: .whitespaces) }) == ["127.0.0.1:\(port)"] else { return nil }
        let states = callback.queryItems?.filter { $0.name == "state" } ?? []
        let codes = callback.queryItems?.filter { $0.name == "code" } ?? []
        guard states.count == 1, states[0].value == expectedState, !expectedState.isEmpty,
              codes.count == 1, let code = codes[0].value, !code.isEmpty,
              !(callback.queryItems?.contains(where: { $0.name == "error" }) ?? false) else { return nil }
        return code
    }

    private func finish(_ result: Result<(code: String, redirectURI: String), Error>) {
        let continuation = self.continuation
        self.continuation = nil
        timeout?.cancel(); timeout = nil
        listener?.cancel(); listener = nil
        state = ""; redirectURI = ""
        continuation?.resume(with: result)
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
    func reauthorizeExistingConnection() async throws {
        guard refreshTask == nil else { throw GmailIntakeError.busy }
        let current = try store.load()
        let renewed = try await GmailOAuthAuthorization.authorize(current: current, transport: transport)
        try Task.checkCancellation()
        try store.updateExisting(renewed)
        grant = renewed
    }

}
