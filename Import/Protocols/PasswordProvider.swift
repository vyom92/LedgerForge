// Import/Protocols/PasswordProvider.swift
// Password resolution contract for encrypted financial documents

import Foundation

public extension ImportFramework {
    /// The non-secret source of a password candidate. A candidate can have
    /// more than one origin when two Keychain records contain the same value;
    /// retaining all origins is required so compatibility migration is not
    /// lost during in-memory de-duplication.
    enum StatementPasswordCandidateOrigin: Sendable, Hashable, Equatable {
        case canonical(scope: String)
        case compatibility(scope: String)
        case legacy(label: String)
        case challenge
    }

    /// A transient credential candidate. The value exists only for the
    /// reader attempt and the provider's session vault; it is never part of a
    /// persisted document or source-evidence record.
    struct StatementPasswordCandidate: Sendable, Equatable {
        public let value: String
        public let origins: [StatementPasswordCandidateOrigin]

        public init(
            value: String,
            origin: StatementPasswordCandidateOrigin
        ) {
            self.init(value: value, origins: [origin])
        }

        public init(
            value: String,
            origins: [StatementPasswordCandidateOrigin]
        ) {
            self.value = value
            var seen = Set<StatementPasswordCandidateOrigin>()
            self.origins = origins.filter { seen.insert($0).inserted }
        }
    }

    /// The exact canonical Keychain target selected only after the source has
    /// been decrypted, classified, parsed, and validated.
    struct StatementPasswordCredentialTarget: Sendable, Equatable, Hashable {
        public let institutionCode: String
        public let scope: String

        public init(institutionCode: String, scope: String? = nil) {
            self.institutionCode = institutionCode
            self.scope = scope ?? institutionCode
        }
    }

    protocol PasswordProvider: Sendable {
        func password(for request: ImportRequest) async throws -> String?
        func rememberedPasswords(for request: ImportRequest) async throws -> [String]
        func rememberedPasswordCandidates(for request: ImportRequest) async throws -> [StatementPasswordCandidate]
        func stageSuccessfulPassword(_ password: String, for request: ImportRequest) async
        func stageSuccessfulPassword(_ candidate: StatementPasswordCandidate, for request: ImportRequest) async
        func confirmSuccessfulPassword(for request: ImportRequest, institutionCode: String) async throws
        func confirmSuccessfulPassword(
            for request: ImportRequest,
            target: StatementPasswordCredentialTarget
        ) async throws
        func discardStagedPassword(for request: ImportRequest) async
    }
}

public extension ImportFramework.PasswordProvider {
    func rememberedPasswords(for request: ImportRequest) async throws -> [String] { [] }
    func rememberedPasswordCandidates(
        for request: ImportRequest
    ) async throws -> [ImportFramework.StatementPasswordCandidate] {
        try await rememberedPasswords(for: request).compactMap { password in
            guard !password.isEmpty else { return nil }
            return ImportFramework.StatementPasswordCandidate(
                value: password,
                origin: .compatibility(scope: "")
            )
        }
    }

    func stageSuccessfulPassword(_ password: String, for request: ImportRequest) async {}
    func stageSuccessfulPassword(
        _ candidate: ImportFramework.StatementPasswordCandidate,
        for request: ImportRequest
    ) async {
        await stageSuccessfulPassword(candidate.value, for: request)
    }

    func confirmSuccessfulPassword(for request: ImportRequest, institutionCode: String) async throws {}
    func confirmSuccessfulPassword(
        for request: ImportRequest,
        target: ImportFramework.StatementPasswordCredentialTarget
    ) async throws {
        try await confirmSuccessfulPassword(
            for: request,
            institutionCode: target.institutionCode
        )
    }

    func discardStagedPassword(for request: ImportRequest) async {}
}
