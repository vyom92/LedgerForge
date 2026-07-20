// Services/IdentityResolver.swift
// Deterministic financial identity infrastructure for repository-owned account identity.

import Foundation

public enum FinancialIdentifierStrength: String, Equatable {
    case strong
    case weak
}

public enum FinancialIdentifierVerificationState: String, Equatable {
    case verified
    case unverified
}

public enum FinancialIdentifierProvenance: String, Equatable {
    case userConfirmed = "user_confirmed"
    case institutionStructuredField = "institution_structured_field"
    case importedMetadata = "imported_metadata"
    case parserDerivedText = "parser_derived_text"
    case migration = "migration"
    case administrative = "administrative"
}

public enum FinancialIdentifierKind: String, CaseIterable, Equatable {
    case iban
    case institutionAccountId = "institution_account_id"
    case brokerAccountId = "broker_account_id"
    case institutionIssuedIdentifier = "institution_issued_identifier"
    case maskedPAN = "masked_pan"
    case cardLastFour = "card_last_four"
    case accountSuffix = "account_suffix"
    case displayName = "display_name"
    case filename
    case institutionLabel = "institution_label"

    public var strength: FinancialIdentifierStrength {
        switch self {
        case .iban, .institutionAccountId, .brokerAccountId, .institutionIssuedIdentifier:
            return .strong
        case .maskedPAN, .cardLastFour, .accountSuffix, .displayName, .filename, .institutionLabel:
            return .weak
        }
    }
}

public enum FinancialIdentifierNormalizationError: Error, Equatable, LocalizedError {
    case emptyValue(kind: FinancialIdentifierKind)
    case invalidValue(kind: FinancialIdentifierKind, value: String)

    public var errorDescription: String? {
        switch self {
        case .emptyValue(let kind):
            return "Identifier value for \(kind.rawValue) is empty after normalization."
        case .invalidValue(let kind, _):
            return "Identifier value for \(kind.rawValue) is invalid after normalization."
        }
    }
}

public struct FinancialIdentifier: Equatable {
    public let kind: FinancialIdentifierKind
    public let normalizedValue: String
    public let strength: FinancialIdentifierStrength
    public let verificationState: FinancialIdentifierVerificationState
    public let provenance: FinancialIdentifierProvenance

    public init(kind: FinancialIdentifierKind,
                rawValue: String,
                verificationState: FinancialIdentifierVerificationState,
                provenance: FinancialIdentifierProvenance) throws {
        self.kind = kind
        self.normalizedValue = try Self.normalize(kind: kind, rawValue: rawValue)
        self.strength = kind.strength
        self.verificationState = verificationState
        self.provenance = provenance
    }

    public func repositoryDTO(accountId: String, workspaceId: String, createdAtISO: String, id: String = UUID().uuidString) -> AccountIdentifierDTO {
        AccountIdentifierDTO(
            id: id,
            accountId: accountId,
            workspaceId: workspaceId,
            scheme: kind.rawValue,
            identifier: normalizedValue,
            strength: strength.rawValue,
            verificationState: verificationState.rawValue,
            provenance: provenance.rawValue,
            createdAtISO: createdAtISO
        )
    }

    public static func normalize(kind: FinancialIdentifierKind, rawValue: String) throws -> String {
        switch kind {
        case .iban:
            return try normalizeIBAN(rawValue, kind: kind)
        case .institutionAccountId, .brokerAccountId, .institutionIssuedIdentifier:
            return try normalizeFullInstitutionIdentifier(rawValue, kind: kind)
        case .cardLastFour:
            return try normalizeCardLastFour(rawValue, kind: kind)
        case .maskedPAN:
            return try normalizeMaskedPAN(rawValue, kind: kind)
        case .accountSuffix:
            return try normalizeAccountSuffix(rawValue, kind: kind)
        case .displayName, .filename, .institutionLabel:
            return try normalizeWeakLabel(rawValue, kind: kind)
        }
    }

    public static func redacted(_ normalizedValue: String) -> String {
        let characters = Array(normalizedValue)
        guard characters.count > 4 else {
            return String(repeating: "*", count: max(characters.count, 1))
        }
        return String(repeating: "*", count: characters.count - 4) + String(characters.suffix(4))
    }

    private static func normalizeIBAN(_ rawValue: String, kind: FinancialIdentifierKind) throws -> String {
        let normalized = asciiUppercase(rawValue).filter { $0 != " " && $0 != "-" }
        try requireNonEmpty(normalized, kind: kind)
        guard normalized.count >= 5, normalized.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
            throw FinancialIdentifierNormalizationError.invalidValue(kind: kind, value: normalized)
        }
        return normalized
    }

    private static func normalizeFullInstitutionIdentifier(_ rawValue: String, kind: FinancialIdentifierKind) throws -> String {
        let normalized = asciiUppercase(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)).filter { $0 != " " }
        try requireNonEmpty(normalized, kind: kind)
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-")
        guard normalized.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw FinancialIdentifierNormalizationError.invalidValue(kind: kind, value: normalized)
        }
        return normalized
    }

    private static func normalizeCardLastFour(_ rawValue: String, kind: FinancialIdentifierKind) throws -> String {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        try requireNonEmpty(normalized, kind: kind)
        guard normalized.count == 4, normalized.allSatisfy(\.isNumber) else {
            throw FinancialIdentifierNormalizationError.invalidValue(kind: kind, value: normalized)
        }
        return normalized
    }

    private static func normalizeMaskedPAN(_ rawValue: String, kind: FinancialIdentifierKind) throws -> String {
        let normalized = asciiUppercase(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)).filter { $0 != " " && $0 != "-" }
        try requireNonEmpty(normalized, kind: kind)
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789*X")
        guard normalized.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              normalized.contains("*") || normalized.contains("X") else {
            throw FinancialIdentifierNormalizationError.invalidValue(kind: kind, value: normalized)
        }
        return normalized
    }

    private static func normalizeAccountSuffix(_ rawValue: String, kind: FinancialIdentifierKind) throws -> String {
        let normalized = asciiUppercase(rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
        try requireNonEmpty(normalized, kind: kind)
        guard normalized.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
            throw FinancialIdentifierNormalizationError.invalidValue(kind: kind, value: normalized)
        }
        return normalized
    }

    private static func normalizeWeakLabel(_ rawValue: String, kind: FinancialIdentifierKind) throws -> String {
        let normalized = asciiLowercase(rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" })
            .joined(separator: " ")
        try requireNonEmpty(normalized, kind: kind)
        return normalized
    }

    private static func requireNonEmpty(_ value: String, kind: FinancialIdentifierKind) throws {
        if value.isEmpty {
            throw FinancialIdentifierNormalizationError.emptyValue(kind: kind)
        }
    }

    private static func asciiUppercase(_ value: String) -> String {
        String(value.map { character in
            guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
                return character
            }
            if scalar.value >= 97 && scalar.value <= 122 {
                return Character(UnicodeScalar(scalar.value - 32)!)
            }
            return character
        })
    }

    private static func asciiLowercase(_ value: String) -> String {
        String(value.map { character in
            guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
                return character
            }
            if scalar.value >= 65 && scalar.value <= 90 {
                return Character(UnicodeScalar(scalar.value + 32)!)
            }
            return character
        })
    }
}

enum IdentityResolutionOutcome: Equatable {
    case resolved(accountId: String)
    case noMatch
    case ambiguous(candidates: [String])
    case conflict(candidates: [String])
}

struct FinancialIdentityResolver {
    private let accountRepository: AccountRepository
    private let developerConsole: DeveloperConsole?

    init(accountRepository: AccountRepository, developerConsole: DeveloperConsole? = DeveloperConsole.shared) {
        self.accountRepository = accountRepository
        self.developerConsole = developerConsole
    }

    func resolve(workspaceId: String, identifiers: [FinancialIdentifier]) throws -> IdentityResolutionOutcome {
        let strongVerifiedIdentifiers = Self.strongVerifiedIdentifiers(from: identifiers)

        guard !strongVerifiedIdentifiers.isEmpty else {
            logOutcome(.noMatch)
            return .noMatch
        }

        var candidatesByIdentifier: [[String]] = []
        for identifier in strongVerifiedIdentifiers {
            let candidates = try accountRepository.accountIds(
                workspaceId: workspaceId,
                scheme: identifier.kind.rawValue,
                identifier: identifier.normalizedValue
            )
            candidatesByIdentifier.append(candidates)
        }

        let outcome = Self.decision(for: candidatesByIdentifier)
        logOutcome(outcome)
        return outcome
    }

    static func strongVerifiedIdentifiers(from identifiers: [FinancialIdentifier]) -> [FinancialIdentifier] {
        identifiers.filter { $0.strength == .strong && $0.verificationState == .verified }
            .sorted { ($0.kind.rawValue, $0.normalizedValue) < ($1.kind.rawValue, $1.normalizedValue) }
    }

    static func decision(for candidatesByIdentifier: [[String]]) -> IdentityResolutionOutcome {
        if let ambiguous = candidatesByIdentifier.first(where: { $0.count > 1 }) {
            return .ambiguous(candidates: ambiguous.sorted())
        }
        let matchedAccountIds = candidatesByIdentifier.flatMap { $0 }.sorted()
        let uniqueAccountIds = Array(Set(matchedAccountIds)).sorted()

        if uniqueAccountIds.count > 1 {
            return .conflict(candidates: uniqueAccountIds)
        }

        if let accountId = uniqueAccountIds.first {
            return .resolved(accountId: accountId)
        }
        return .noMatch
    }

    private func logOutcome(_ outcome: IdentityResolutionOutcome) {
        switch outcome {
        case .resolved(let accountId):
            developerConsole?.info(.database, "Identity resolver returned Resolved", metadata: ["accountId": accountId])
        case .noMatch:
            developerConsole?.info(.database, "Identity resolver returned No Match")
        case .ambiguous(let candidates):
            developerConsole?.warning(.database, "Identity resolver returned Ambiguous", metadata: ["candidates": "\(candidates.count)"])
        case .conflict(let candidates):
            developerConsole?.warning(.database, "Identity resolver returned Conflict", metadata: ["candidates": "\(candidates.count)"])
        }
    }
}
