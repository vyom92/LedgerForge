import Foundation
import Security

nonisolated struct GmailSavedGrant: Codable, Equatable, Sendable {
    let account: String
    let clientID: String
    var clientSecret: String?
    var accessToken: String
    let refreshToken: String
    let scope: String
    var expiresAt: Double

    enum CodingKeys: String, CodingKey {
        case account, scope
        case clientID = "client_id", clientSecret = "client_secret"
        case accessToken = "access_token", refreshToken = "refresh_token", expiresAt = "expires_at"
    }

    func validate() throws {
        guard !account.isEmpty, !clientID.isEmpty, !refreshToken.isEmpty, expiresAt.isFinite else {
            throw GmailIntakeError.keychainUnavailable
        }
        guard Set(scope.split(whereSeparator: \.isWhitespace).map(String.init)) == [GmailClient.readOnlyScope] else {
            throw GmailIntakeError.scopeMismatch
        }
    }
}

nonisolated struct GmailDesktopClient: Decodable, Sendable {
    struct Installed: Decodable, Sendable {
        let client_id: String
        let client_secret: String
        let auth_uri: String?
        let token_uri: String?
    }
    let installed: Installed

    static func read(_ data: Data) throws -> Self {
        guard data.count <= 32_768,
              let client = try? JSONDecoder().decode(Self.self, from: data),
              !client.installed.client_id.isEmpty, !client.installed.client_secret.isEmpty,
              client.installed.token_uri.map({ $0 == "https://oauth2.googleapis.com/token" }) ?? true,
              client.installed.auth_uri.map({ ["https://accounts.google.com/o/oauth2/v2/auth", "https://accounts.google.com/o/oauth2/auth"].contains($0) }) ?? true else {
            throw GmailIntakeError.configurationRequired
        }
        return client
    }
}

nonisolated protocol GmailGrantStore: Sendable {
    func load() throws -> GmailSavedGrant
    func updateExisting(_ grant: GmailSavedGrant) throws
}

/// Reuses the owner-owned pilot grant in place. No service rename, additional
/// grant, scope expansion, credential export, or delete operation exists here.
nonisolated struct GmailKeychainGrantStore: GmailGrantStore {
    static let service = "com.vyom.LedgerForge.gmail-ram-pilot.20260916"
    let interaction: CredentialInteractionPolicy
    init(interaction: CredentialInteractionPolicy = .foreground) { self.interaction = interaction }

    private func identity(account: String? = nil) -> [CFString: Any] {
        var query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: Self.service,
                                    kSecAttrSynchronizable: false]
        if let account { query[kSecAttrAccount] = account }
        return interaction.applying(to: query)
    }

    func load() throws -> GmailSavedGrant {
        // Establish the exact selected account from this one registered service.
        // No unrelated Keychain entry or credential service is enumerated.
        var attributes = identity()
        attributes[kSecReturnAttributes] = true
        attributes[kSecMatchLimit] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = try interaction.perform { SecItemCopyMatching(attributes as CFDictionary, &result) }
        guard status == errSecSuccess, let items = result as? [[CFString: Any]], items.count == 1,
              let account = items[0][kSecAttrAccount] as? String else { throw GmailIntakeError.keychainUnavailable }
        var query = identity(account: account)
        query[kSecReturnData] = true; query[kSecMatchLimit] = kSecMatchLimitOne
        result = nil
        guard try interaction.perform({ SecItemCopyMatching(query as CFDictionary, &result) }) == errSecSuccess,
              let data = result as? Data, data.count <= 32_768,
              let grant = try? JSONDecoder().decode(GmailSavedGrant.self, from: data),
              grant.account.lowercased() == account.lowercased() else { throw GmailIntakeError.keychainUnavailable }
        try grant.validate()
        return grant
    }

    func updateExisting(_ grant: GmailSavedGrant) throws {
        try grant.validate()
        let existing = try load()
        guard existing.account == grant.account, existing.clientID == grant.clientID else { throw GmailIntakeError.accountMismatch }
        let bytes = try JSONEncoder().encode(grant)
        guard bytes.count <= 32_768,
              try interaction.perform({ SecItemUpdate(identity(account: grant.account) as CFDictionary,
                                                       [kSecValueData: bytes] as CFDictionary) }) == errSecSuccess else {
            throw GmailIntakeError.keychainUnavailable
        }
    }
}

actor GmailTokenBroker: GmailAccessTokenProvider {
    let store: any GmailGrantStore
    let transport: any GmailHTTPTransport
    private let now: @Sendable () -> Date
    var grant: GmailSavedGrant?
    var refreshTask: Task<GmailSavedGrant, Error>?

    init(store: any GmailGrantStore = GmailKeychainGrantStore(),
         transport: any GmailHTTPTransport = GmailURLSessionTransport(),
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store; self.transport = transport; self.now = now
    }

    func savedAccount() throws -> String {
        let value = try store.load(); try value.validate(); grant = value
        return value.account.lowercased()
    }

    func configureExistingClient(_ data: Data) throws {
        let configuration = try GmailDesktopClient.read(data)
        var value = try store.load()
        guard value.clientID == configuration.installed.client_id else { throw GmailIntakeError.accountMismatch }
        // The selected existing Desktop client is retained in the SAME Keychain
        // record. The shipped app never depends on its disposable source path.
        value.clientSecret = configuration.installed.client_secret
        try store.updateExisting(value)
        grant = value
    }


    func accessToken(refresh: Bool) async throws -> String {
        try Task.checkCancellation()
        if let refreshTask { return try await refreshTask.value.accessToken }
        let current: GmailSavedGrant
        if let grant { current = grant } else { current = try store.load() }
        try current.validate()
        if !refresh, current.expiresAt > now().timeIntervalSince1970 + 90, !current.accessToken.isEmpty {
            grant = current
            return current.accessToken
        }
        guard let clientSecret = current.clientSecret, !clientSecret.isEmpty else { throw GmailIntakeError.configurationRequired }
        let transport = self.transport, store = self.store, now = self.now
        let task = Task { @concurrent in
            let request = try Self.tokenRequest([
                "client_id": current.clientID, "client_secret": clientSecret,
                "refresh_token": current.refreshToken, "grant_type": "refresh_token"
            ])
            let response = try await transport.send(request, maximumBytes: 32_768)
            try Task.checkCancellation()
            if [429, 500, 502, 503, 504].contains(response.statusCode) { throw GmailIntakeError.rateLimited }
            guard response.statusCode == 200 else { throw GmailIntakeError.unauthorized }
            guard let token = try? JSONDecoder().decode(TokenResponse.self, from: response.data),
                  !token.access_token.isEmpty, token.expires_in > 0,
                  token.token_type.lowercased() == "bearer" else { throw GmailIntakeError.invalidResponse }
            if let scope = token.scope,
               Set(scope.split(whereSeparator: \.isWhitespace).map(String.init)) != [GmailClient.readOnlyScope] {
                throw GmailIntakeError.scopeMismatch
            }
            var updated = current
            updated.accessToken = token.access_token
            updated.expiresAt = now().timeIntervalSince1970 + Double(token.expires_in)
            try store.updateExisting(updated)
            return updated
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let refreshed = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            grant = refreshed
            return refreshed.accessToken
        } catch { grant = nil; throw error }
    }

    nonisolated struct TokenResponse: Decodable, Sendable {
        let access_token: String
        let expires_in: Int
        let token_type: String
        let scope: String?
        let refresh_token: String?
    }

    nonisolated static func tokenRequest(_ fields: [String: String]) throws -> URLRequest {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let form = try fields.sorted(by: { $0.key < $1.key }).map { key, value in
            guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed),
                  let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) else {
                throw GmailIntakeError.invalidResponse
            }
            return encodedKey + "=" + encodedValue
        }.joined(separator: "&")
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { throw GmailIntakeError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.httpBody = Data(form.utf8)
        return request
    }
}
