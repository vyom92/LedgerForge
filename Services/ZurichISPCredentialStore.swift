import CryptoKit
import Foundation
import Security

nonisolated struct ZurichISPCredentialStore: Sendable {
    static let service = KeychainStatementPasswordCredentialStore.productionService
    static let account = "zurich-isp.account-authentication"
    static let defaultLabel = "LedgerForge · ISP Account"
    private let service: String
    private let account: String

    init(service: String = Self.service, account: String = Self.account) {
        self.service = service; self.account = account
    }

    func load() throws -> ZurichISPCredentials? { try Self.read(service: service, account: account) }

    /// Called only by the explicit migration action. Copy precedes verification;
    /// the pilot item is removed only after the saved app credential succeeds.
    func loadPilot() throws -> ZurichISPCredentials? {
        try Self.read(service: "com.ledgerforge.ZIOFeasibility", account: "Zurich ZIO pilot")
    }

    struct PilotMoveToken: Sendable {
        let persistentReference: Data
        let valueHash: Data
        let label: String?
        let modifiedAt: Date?
    }

    func preparePilotMove() throws -> (ZurichISPCredentials, PilotMoveToken)? {
        var query = Self.identity(service: "com.ledgerforge.ZIOFeasibility", account: "Zurich ZIO pilot")
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnData] = true; query[kSecReturnAttributes] = true; query[kSecReturnPersistentRef] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let record = result as? [CFString: Any],
              let data = record[kSecValueData] as? Data, let reference = record[kSecValuePersistentRef] as? Data,
              let credentials = try? JSONDecoder().decode(ZurichISPCredentials.self, from: data) else {
            throw ZurichISPCredentialError.unavailable
        }
        return (credentials, .init(persistentReference: reference, valueHash: Data(SHA256.hash(data: data)),
            label: record[kSecAttrLabel] as? String, modifiedAt: record[kSecAttrModificationDate] as? Date))
    }

    func save(_ credentials: ZurichISPCredentials) throws {
        guard !credentials.username.isEmpty, !credentials.password.isEmpty,
              credentials.memorablePIN.count >= 3 else { throw ZurichISPCredentialError.invalid }
        let data = try JSONEncoder().encode(credentials)
        let identity = Self.identity(service: service, account: account)
        let attributes: [CFString: Any] = [kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let result = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if result == errSecSuccess { return }
        guard result == errSecItemNotFound else { throw ZurichISPCredentialError.unavailable }
        var item = identity; item.merge(attributes) { _, new in new }; item[kSecAttrLabel] = Self.defaultLabel
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw ZurichISPCredentialError.unavailable }
    }

    func disconnect() throws {
        let result = SecItemDelete(Self.identity(service: service, account: account) as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else { throw ZurichISPCredentialError.unavailable }
    }

    func label() throws -> String? {
        var query = Self.identity(service: service, account: account)
        query[kSecMatchLimit] = kSecMatchLimitOne; query[kSecReturnAttributes] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let attributes = result as? [CFString: Any] else { throw ZurichISPCredentialError.unavailable }
        return attributes[kSecAttrLabel] as? String ?? Self.defaultLabel
    }

    func rename(to label: String) throws {
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 100 else { throw ZurichISPCredentialError.invalidLabel }
        guard SecItemUpdate(Self.identity(service: service, account: account) as CFDictionary,
                            [kSecAttrLabel: name] as CFDictionary) == errSecSuccess else { throw ZurichISPCredentialError.unavailable }
    }

    /// Exact-item removal only, after a complete native fetch using a reloaded
    /// production credential. Never removes a different or changed pilot entry.
    func finishPilotMove(verified credentials: ZurichISPCredentials, token: PilotMoveToken) throws {
        guard try load() == credentials else { throw ZurichISPCredentialError.unavailable }
        let identity: [CFString: Any] = [kSecValuePersistentRef: token.persistentReference]
        var query = identity; query[kSecReturnData] = true; query[kSecReturnAttributes] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let record = result as? [CFString: Any], let data = record[kSecValueData] as? Data,
              Data(SHA256.hash(data: data)) == token.valueHash,
              record[kSecAttrService] as? String == "com.ledgerforge.ZIOFeasibility",
              record[kSecAttrAccount] as? String == "Zurich ZIO pilot",
              record[kSecAttrLabel] as? String == token.label,
              record[kSecAttrModificationDate] as? Date == token.modifiedAt else { throw ZurichISPCredentialError.unavailable }
        guard SecItemDelete(identity as CFDictionary) == errSecSuccess else { throw ZurichISPCredentialError.unavailable }
    }

    private static func read(service: String, account: String) throws -> ZurichISPCredentials? {
        var query = identity(service: service, account: account)
        query[kSecMatchLimit] = kSecMatchLimitOne; query[kSecReturnData] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let value = try? JSONDecoder().decode(ZurichISPCredentials.self, from: data),
              !value.username.isEmpty, !value.password.isEmpty, value.memorablePIN.count >= 3 else {
            throw ZurichISPCredentialError.unavailable
        }
        return value
    }

    private static func identity(service: String, account: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
         kSecAttrAccount: account, kSecAttrSynchronizable: false]
    }
}

nonisolated enum ZurichISPCredentialError: Error, LocalizedError {
    case unavailable, invalid, noPilot, invalidLabel
    var errorDescription: String? {
        switch self {
        case .unavailable: "The saved ISP connection could not be read or updated in Keychain."
        case .invalid: "Enter your username, password and memorable PIN."
        case .noPilot: "The saved pilot connection was not found. Enter your credentials to connect."
        case .invalidLabel: "Use a name between 1 and 100 characters."
        }
    }
}
