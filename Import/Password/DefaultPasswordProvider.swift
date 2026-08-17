// Import/Password/DefaultPasswordProvider.swift
// Production statement-password workflow for the Unified Import Framework.

import Combine
import Foundation
import Security

protocol StatementPasswordCredentialStore: Sendable {
    func password(institutionCode: String) async throws -> String?
    func save(_ password: String, institutionCode: String) async throws
    func delete(institutionCode: String) async throws
}

enum StatementPasswordCredentialStoreError: Error, LocalizedError, Equatable {
    case invalidCredentialEncoding
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidCredentialEncoding:
            return "The statement credential could not be encoded."
        case .keychainFailure(let status):
            return "The statement credential store is unavailable (status \(status))."
        }
    }
}

final class KeychainStatementPasswordCredentialStore: StatementPasswordCredentialStore, @unchecked Sendable {
    static let productionService = "com.ledgerforge.statement-password"

    private let service: String

    init(service: String = productionService) {
        self.service = service
    }

    func password(institutionCode: String) async throws -> String? {
        var query = baseQuery(institutionCode: institutionCode)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw StatementPasswordCredentialStoreError.keychainFailure(status)
        }
        guard let data = result as? Data, let password = String(data: data, encoding: .utf8) else {
            throw StatementPasswordCredentialStoreError.invalidCredentialEncoding
        }
        return password
    }

    func save(_ password: String, institutionCode: String) async throws {
        guard !password.isEmpty, let data = password.data(using: .utf8) else {
            throw StatementPasswordCredentialStoreError.invalidCredentialEncoding
        }
        let query = baseQuery(institutionCode: institutionCode)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw StatementPasswordCredentialStoreError.keychainFailure(updateStatus)
        }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw StatementPasswordCredentialStoreError.keychainFailure(addStatus)
        }
    }

    func delete(institutionCode: String) async throws {
        let status = SecItemDelete(baseQuery(institutionCode: institutionCode) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StatementPasswordCredentialStoreError.keychainFailure(status)
        }
    }

    private func baseQuery(institutionCode: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: institutionCode,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }
}

actor InMemoryStatementPasswordCredentialStore: StatementPasswordCredentialStore {
    private var passwords: [String: String]

    init(passwords: [String: String] = [:]) {
        self.passwords = passwords
    }

    func password(institutionCode: String) -> String? {
        passwords[institutionCode]
    }

    func save(_ password: String, institutionCode: String) {
        passwords[institutionCode] = password
    }

    func delete(institutionCode: String) {
        passwords.removeValue(forKey: institutionCode)
    }
}

struct StatementPasswordChallenge: Identifiable, Equatable {
    let id: UUID
    let fileName: String
}

@MainActor
final class StatementPasswordChallengeController: ObservableObject {
    static let shared = StatementPasswordChallengeController()

    @Published private(set) var challenge: StatementPasswordChallenge?
    private var continuation: CheckedContinuation<String?, Error>?

    func requestPassword(for request: ImportRequest) async throws -> String? {
        guard continuation == nil, challenge == nil else {
            throw ImportError.readerFailure(message: "Another secure statement-password challenge is active.")
        }
        challenge = StatementPasswordChallenge(id: request.id, fileName: request.fileName)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func submit(_ password: String, challengeID: UUID) {
        guard challenge?.id == challengeID, !password.isEmpty, let continuation else { return }
        challenge = nil
        self.continuation = nil
        continuation.resume(returning: password)
    }

    func cancel(challengeID: UUID? = nil) {
        guard challengeID == nil || challenge?.id == challengeID else { return }
        let continuation = self.continuation
        challenge = nil
        self.continuation = nil
        continuation?.resume(throwing: ImportError.cancelled)
    }
}

private actor StatementPasswordSessionVault {
    private var stagedByRequestID = [UUID: String]()

    func stage(_ password: String, requestID: UUID) {
        stagedByRequestID[requestID] = password
    }

    func take(requestID: UUID) -> String? {
        stagedByRequestID.removeValue(forKey: requestID)
    }

    func discard(requestID: UUID) {
        stagedByRequestID.removeValue(forKey: requestID)
    }
}

struct DefaultPasswordProvider: ImportFramework.PasswordProvider {
    typealias Challenge = @Sendable (ImportRequest) async throws -> String?

    private let credentialStore: any StatementPasswordCredentialStore
    private let supportedInstitutionCodes: [String]
    private let challenge: Challenge
    private let sessionVault: StatementPasswordSessionVault

    init(
        credentialStore: any StatementPasswordCredentialStore = KeychainStatementPasswordCredentialStore(),
        supportedInstitutionCodes: [String] = Institution.allCases
            .filter { $0 != .unknown }
            .map(\.statementPasswordCredentialScope),
        challenge: @escaping Challenge = { request in
            try await StatementPasswordChallengeController.shared.requestPassword(for: request)
        }
    ) {
        self.credentialStore = credentialStore
        self.supportedInstitutionCodes = supportedInstitutionCodes
        self.challenge = challenge
        self.sessionVault = StatementPasswordSessionVault()
    }

    func password(for request: ImportRequest) async throws -> String? {
        try await challenge(request)
    }

    func rememberedPasswords(for request: ImportRequest) async throws -> [String] {
        var seen = Set<String>()
        var candidates = [String]()
        for code in supportedInstitutionCodes {
            if let password = try await credentialStore.password(institutionCode: code),
               !password.isEmpty,
               seen.insert(password).inserted {
                candidates.append(password)
            }
        }
        return candidates
    }

    func stageSuccessfulPassword(_ password: String, for request: ImportRequest) async {
        guard !password.isEmpty else { return }
        await sessionVault.stage(password, requestID: request.id)
    }

    func confirmSuccessfulPassword(for request: ImportRequest, institutionCode: String) async throws {
        guard supportedInstitutionCodes.contains(institutionCode),
              let password = await sessionVault.take(requestID: request.id) else { return }
        try await credentialStore.save(password, institutionCode: institutionCode)
    }

    func discardStagedPassword(for request: ImportRequest) async {
        await sessionVault.discard(requestID: request.id)
    }
}

extension Institution {
    var statementPasswordCredentialScope: String {
        switch self {
        case .axis: return "axis-bank"
        case .hdfc: return "hdfc-bank"
        case .cbq: return "commercial-bank-of-qatar"
        case .amex: return "american-express"
        case .unknown: return "unknown"
        }
    }
}
