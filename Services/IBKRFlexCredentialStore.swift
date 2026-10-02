import Foundation
import Security

/// The ordinary app/helper credential store. Only an explicit foreground action
/// may read the proof item. Scheduled work loads only the production item.
nonisolated struct IBKRFlexCredentialStore: Sendable {
    static let service = LedgerCredentialIdentity.statementPasswords
    static let account = "ibkr-flex.account-authentication"
    static let defaultLabel = "LedgerForge · IBKR Flex"
    private static let proofService = "com.ledgerforge.ibkr-native-proof.20260930"
    private static let proofAccount = "flex-report"
    private let service: String
    private let account: String
    private let interaction: CredentialInteractionPolicy

    init(service: String = Self.service, account: String = Self.account,
         interaction: CredentialInteractionPolicy = .foreground) {
        self.service = service; self.account = account; self.interaction = interaction
    }

    func forbiddingInteraction() -> Self { .init(service: service, account: account, interaction: .forbidden) }

    func load() throws -> IBKRFlexCredentials? {
        guard let data = try readData(service: service, account: account) else { return nil }
        guard let credentials = try? JSONDecoder().decode(IBKRFlexCredentials.self, from: data),
              let checked = try? credentials.validated() else { throw IBKRFlexCredentialError.unavailable }
        return checked
    }

    /// The caller verifies a replacement token/query by fetching before saving;
    /// a failed connection attempt must not overwrite a working saved token.
    func save(_ credentials: IBKRFlexCredentials) throws {
        let credentials = try credentials.validated()
        let data = try JSONEncoder().encode(credentials)
        let identity = interaction.applying(to: Self.identity(service: service, account: account))
        let attributes: [CFString: Any] = [kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let result = try interaction.perform { SecItemUpdate(identity as CFDictionary, attributes as CFDictionary) }
        if result == errSecSuccess { return }
        guard result == errSecItemNotFound else { throw IBKRFlexCredentialError.unavailable }
        var item = identity
        item.merge(attributes) { _, new in new }
        item[kSecAttrLabel] = Self.defaultLabel
        guard try interaction.perform({ SecItemAdd(item as CFDictionary, nil) }) == errSecSuccess else {
            throw IBKRFlexCredentialError.unavailable
        }
    }

    func disconnect() throws {
        let identity = interaction.applying(to: Self.identity(service: service, account: account))
        let result = try interaction.perform { SecItemDelete(identity as CFDictionary) }
        guard result == errSecSuccess || result == errSecItemNotFound else { throw IBKRFlexCredentialError.unavailable }
    }

    /// Exact owned proof item only. This returns a candidate for the caller's
    /// normal native fetch; it does not save a token or claim a valid connection.
    func loadSavedProofToken() throws -> IBKRFlexCredentials? {
        guard interaction == .foreground else { throw IBKRFlexCredentialError.foregroundRequired }
        guard let data = try readData(service: Self.proofService, account: Self.proofAccount) else { return nil }
        guard let record = try? JSONDecoder().decode(ProofRecord.self, from: data),
              record.pilotOwner == Self.proofService, record.summaryUnfilteredOwnerConfirmed else {
            throw IBKRFlexCredentialError.invalidProofItem
        }
        do {
            return try IBKRFlexCredentials(token: record.token, queryID: record.queryID,
                                          expectedAccountID: record.expectedAccountID,
                                          ownerReportedExpiry: record.ownerReportedExpiry,
                                          summaryUnfilteredOwnerConfirmed: true).validated()
        } catch { throw IBKRFlexCredentialError.invalidProofItem }
    }

    /// Call after a complete native fetch using this candidate. Verify that the
    /// proof item still matches, copy to the app's item, then verify the copy.
    /// The original proof item is retained; no ACL or other item is changed.
    @discardableResult
    func copySavedProofToken(verified credentials: IBKRFlexCredentials) throws -> IBKRFlexCredentials {
        guard interaction == .foreground else { throw IBKRFlexCredentialError.foregroundRequired }
        guard let current = try loadSavedProofToken(), current == credentials else { throw IBKRFlexCredentialError.proofItemChanged }
        try save(credentials)
        guard let reloaded = try load(), reloaded == credentials else { throw IBKRFlexCredentialError.unavailable }
        return reloaded
    }

    private func readData(service: String, account: String) throws -> Data? {
        var query = interaction.applying(to: Self.identity(service: service, account: account))
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnData] = true
        var result: CFTypeRef?
        let status = try interaction.perform { SecItemCopyMatching(query as CFDictionary, &result) }
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, data.count <= 16_384 else {
            throw IBKRFlexCredentialError.unavailable
        }
        return data
    }

    private static func identity(service: String, account: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
         kSecAttrAccount: account, kSecAttrSynchronizable: false]
    }

    nonisolated private struct ProofRecord: Decodable, Sendable {
        let pilotOwner: String
        let token: String
        let queryID: String
        let expectedAccountID: String
        let ownerReportedExpiry: String
        let summaryUnfilteredOwnerConfirmed: Bool
        enum CodingKeys: String, CodingKey {
            case pilotOwner = "pilot_owner", token
            case queryID = "query_id"
            case expectedAccountID = "expected_account"
            case ownerReportedExpiry = "owner_reported_expiry"
            case summaryUnfilteredOwnerConfirmed = "summary_unfiltered_owner_confirmed"
        }
    }
}

nonisolated enum IBKRFlexCredentialError: Error, LocalizedError, Equatable, Sendable {
    case unavailable, foregroundRequired, invalidProofItem, proofItemChanged
    var errorDescription: String? {
        switch self {
        case .unavailable: "The saved IBKR connection could not be read or updated in Keychain."
        case .foregroundRequired: "Use saved proof token is available only from the IBKR Settings action."
        case .invalidProofItem: "The saved IBKR proof connection is incomplete. Enter the token and query details in Settings."
        case .proofItemChanged: "The saved IBKR proof connection changed during verification. Try the connection action again."
        }
    }
}
