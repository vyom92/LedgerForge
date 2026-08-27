// Import/Password/DefaultPasswordProvider.swift
// Production statement-password workflow for the Unified Import Framework.

import Combine
import Foundation
import Security

struct StatementPasswordStoredCredential: Sendable, Equatable {
    let value: String
    let origin: ImportFramework.StatementPasswordCandidateOrigin
}

protocol StatementPasswordCredentialStore: Sendable {
    /// Returns only explicitly known canonical accounts and registered legacy
    /// compatibility labels for this institution. Implementations must never
    /// perform an unbounded Keychain scan.
    func credentials(institutionCode: String) async throws -> [StatementPasswordStoredCredential]
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
    nonisolated static let productionService = "com.ledgerforge.statement-password"
    nonisolated static let axisInstitutionScope = "axis-bank"
    nonisolated static let axisAppPDFScope = "axis-bank.credit-card.app-pdf"
    nonisolated static let axisTraditionalPDFScope = "axis-bank.credit-card.traditional-pdf"
    nonisolated static let productionLegacyLabelsByInstitutionCode = [
        axisInstitutionScope: ["com.ledgerforge.Axis CC statement"]
    ]

    private let service: String
    private let legacyLabelsByInstitutionCode: [String: [String]]

    init(
        service: String = productionService,
        legacyLabelsByInstitutionCode: [String: [String]]? = nil
    ) {
        self.service = service
        self.legacyLabelsByInstitutionCode = legacyLabelsByInstitutionCode
            ?? (service == Self.productionService ? Self.productionLegacyLabelsByInstitutionCode : [:])
    }

    func credentials(institutionCode: String) async throws -> [StatementPasswordStoredCredential] {
        var credentials = [StatementPasswordStoredCredential]()
        for scope in canonicalScopes(for: institutionCode) {
            var query = baseQuery(institutionCode: scope)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            guard let password = try password(matching: query) else { continue }
            let origin: ImportFramework.StatementPasswordCandidateOrigin
            if institutionCode == Self.axisInstitutionScope,
               scope == Self.axisInstitutionScope {
                origin = .compatibility(scope: scope)
            } else {
                origin = .canonical(scope: scope)
            }
            credentials.append(.init(value: password, origin: origin))
        }

        // Legacy lookup is intentionally label-bounded. Never enumerate all
        // generic-password items, and never use a filename or source path.
        if institutionCode == Self.axisInstitutionScope {
            for label in legacyLabelsByInstitutionCode[institutionCode] ?? [] {
                let legacyQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrLabel as String: label,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitAll
                ]
                if let password = try password(matching: legacyQuery, requireUniqueMatch: true) {
                    credentials.append(.init(value: password, origin: .legacy(label: label)))
                }
            }
        }
        return credentials
    }

    func password(institutionCode: String) async throws -> String? {
        var query = baseQuery(institutionCode: institutionCode)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        if let password = try password(matching: query) {
            return password
        }
        guard institutionCode == Self.axisInstitutionScope else { return nil }
        for label in legacyLabelsByInstitutionCode[institutionCode] ?? [] {
            let legacyQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrLabel as String: label,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitAll
            ]
            if let password = try password(matching: legacyQuery, requireUniqueMatch: true) {
                return password
            }
        }
        return nil
    }

    private func password(
        matching query: [String: Any],
        requireUniqueMatch: Bool = false
    ) throws -> String? {
        if requireUniqueMatch {
            // A label-bounded `match-all + return-data` generic-password query
            // is rejected by the signed macOS test host with errSecParam.
            // Establish uniqueness from non-secret attributes first, then read
            // data only when exactly one registered legacy item exists.
            var uniquenessQuery = query
            uniquenessQuery.removeValue(forKey: kSecReturnData as String)
            uniquenessQuery[kSecReturnAttributes as String] = true
            uniquenessQuery[kSecMatchLimit as String] = kSecMatchLimitAll

            var uniquenessResult: CFTypeRef?
            let uniquenessStatus = SecItemCopyMatching(
                uniquenessQuery as CFDictionary,
                &uniquenessResult
            )
            if uniquenessStatus == errSecItemNotFound { return nil }
            guard uniquenessStatus == errSecSuccess else {
                throw StatementPasswordCredentialStoreError.keychainFailure(uniquenessStatus)
            }

            let matches: [Any]
            if let array = uniquenessResult as? [Any] {
                matches = array
            } else if let array = uniquenessResult as? NSArray {
                matches = array.map { $0 }
            } else if let uniquenessResult {
                matches = [uniquenessResult]
            } else {
                return nil
            }
            // More than one item under a registered legacy label is
            // ambiguous. Omit that compatibility candidate instead of
            // silently choosing one Keychain item.
            guard matches.count == 1 else { return nil }

            var dataQuery = query
            dataQuery.removeValue(forKey: kSecReturnAttributes as String)
            dataQuery[kSecReturnData as String] = true
            dataQuery[kSecMatchLimit as String] = kSecMatchLimitOne
            return try password(matching: dataQuery)
        }

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

    private func canonicalScopes(for institutionCode: String) -> [String] {
        guard institutionCode == Self.axisInstitutionScope else { return [institutionCode] }
        return [Self.axisAppPDFScope, Self.axisTraditionalPDFScope, Self.axisInstitutionScope]
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

    func credentials(institutionCode: String) async -> [StatementPasswordStoredCredential] {
        let scopes: [String]
        if institutionCode == KeychainStatementPasswordCredentialStore.axisInstitutionScope {
            scopes = [
                KeychainStatementPasswordCredentialStore.axisAppPDFScope,
                KeychainStatementPasswordCredentialStore.axisTraditionalPDFScope,
                KeychainStatementPasswordCredentialStore.axisInstitutionScope
            ]
        } else {
            scopes = [institutionCode]
        }
        var result = scopes.compactMap { scope -> StatementPasswordStoredCredential? in
            guard let password = passwords[scope] else { return nil }
            let origin: ImportFramework.StatementPasswordCandidateOrigin
            if institutionCode == KeychainStatementPasswordCredentialStore.axisInstitutionScope,
               scope == KeychainStatementPasswordCredentialStore.axisInstitutionScope {
                origin = .compatibility(scope: scope)
            } else {
                origin = .canonical(scope: scope)
            }
            return .init(value: password, origin: origin)
        }
        // In-memory tests model registered legacy records using a stable
        // sentinel key. This keeps the production order and provenance
        // behavior testable without touching a user's Keychain.
        if institutionCode == KeychainStatementPasswordCredentialStore.axisInstitutionScope,
           let legacy = passwords[Self.legacyStorageKey] {
            result.append(.init(
                value: legacy,
                origin: .legacy(label: Self.legacyStorageKey)
            ))
        }
        return result
    }

    func password(institutionCode: String) async -> String? {
        if let password = passwords[institutionCode] {
            return password
        }
        if institutionCode == KeychainStatementPasswordCredentialStore.axisInstitutionScope {
            return passwords[Self.legacyStorageKey]
        }
        return nil
    }

    func save(_ password: String, institutionCode: String) async {
        passwords[institutionCode] = password
    }

    func delete(institutionCode: String) async {
        passwords.removeValue(forKey: institutionCode)
    }

    nonisolated private static let legacyStorageKey = "__legacy_axis_statement_password__"
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
    private var stagedByRequestID = [UUID: ImportFramework.StatementPasswordCandidate]()

    func stage(_ candidate: ImportFramework.StatementPasswordCandidate, requestID: UUID) {
        stagedByRequestID[requestID] = candidate
    }

    func take(requestID: UUID) -> ImportFramework.StatementPasswordCandidate? {
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

    func rememberedPasswordCandidates(
        for request: ImportRequest
    ) async throws -> [ImportFramework.StatementPasswordCandidate] {
        var candidates = [ImportFramework.StatementPasswordCandidate]()
        var candidateIndexByValue = [String: Int]()
        for code in supportedInstitutionCodes {
            for stored in try await credentialStore.credentials(institutionCode: code) {
                guard !stored.value.isEmpty else { continue }
                if let index = candidateIndexByValue[stored.value] {
                    let existing = candidates[index]
                    candidates[index] = .init(
                        value: existing.value,
                        origins: existing.origins + [stored.origin]
                    )
                } else {
                    candidateIndexByValue[stored.value] = candidates.count
                    candidates.append(.init(value: stored.value, origin: stored.origin))
                }
            }
        }
        return candidates
    }

    func rememberedPasswords(for request: ImportRequest) async throws -> [String] {
        (try await rememberedPasswordCandidates(for: request)).map { $0.value }
    }

    func stageSuccessfulPassword(
        _ candidate: ImportFramework.StatementPasswordCandidate,
        for request: ImportRequest
    ) async {
        guard !candidate.value.isEmpty else { return }
        await sessionVault.stage(candidate, requestID: request.id)
    }

    func stageSuccessfulPassword(_ password: String, for request: ImportRequest) async {
        guard !password.isEmpty else { return }
        await stageSuccessfulPassword(
            .init(value: password, origin: .challenge),
            for: request
        )
    }

    func confirmSuccessfulPassword(for request: ImportRequest, institutionCode: String) async throws {
        try await confirmSuccessfulPassword(
            for: request,
            target: .init(institutionCode: institutionCode)
        )
    }

    func confirmSuccessfulPassword(
        for request: ImportRequest,
        target: ImportFramework.StatementPasswordCredentialTarget
    ) async throws {
        guard supportedInstitutionCodes.contains(target.institutionCode)
                || supportedInstitutionCodes.contains(target.scope),
              let candidate = await sessionVault.take(requestID: request.id) else { return }

        // A canonical candidate that exactly matches the validated target is
        // already durable. Do not churn its Keychain item on every import.
        let isExactCanonical = candidate.origins.contains { origin in
            guard case .canonical(let scope) = origin else { return false }
            return scope == target.scope
        }
        guard !isExactCanonical else { return }

        // Compatibility and challenge credentials are written only to the
        // exact post-validation family target. The old canonical/legacy item
        // is never erased here.
        try await credentialStore.save(candidate.value, institutionCode: target.scope)
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
