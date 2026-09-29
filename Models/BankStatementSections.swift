import Foundation

/// The legacy CBQ Current Book Balance column uses a trailing minus for an
/// overdraft. This interpretation belongs only to that registered source role;
/// persisted observations retain the original literal.
nonisolated enum CBQLegacyBookBalanceLiteral {
    static func canonicalText(_ literal: String, profileID: String, version: String) -> String? {
        guard version == "1", ["cbq.current-account.legacy.pdf", "cbq.savings-account.legacy.pdf"].contains(profileID) else { return nil }
        if literal.range(of: #"^-?[0-9]+(?:,[0-9]{3})*\.[0-9]{2}$"#, options: .regularExpression) != nil {
            return literal
        }
        guard profileID == "cbq.current-account.legacy.pdf",
              literal.range(of: #"^[0-9]+(?:,[0-9]{3})*\.[0-9]{2}-$"#, options: .regularExpression) != nil else { return nil }
        return "-" + literal.dropLast()
    }
}

/// Literal controls belong to their printed account section. They never imply
/// a financial relationship between sibling accounts in one original.
nonisolated enum BankSectionControlKind: String, Codable, Sendable {
    case openingBalance, closingBalance, debitTotal, creditTotal
    case debitCount, creditCount, withdrawableBalance, limit, sweep, hold
}

nonisolated struct NormalizedBankSectionControl: Sendable {
    let kind: BankSectionControlKind
    let label: String
    let literal: String
    let sourceOrdinal: Int
    let sourcePage: Int
}

/// Source-owned account boundaries before financial interpretation. All rows
/// still belong to the same immutable parent original and normalized document.
nonisolated struct NormalizedBankAccountSection: Sendable {
    let id: String
    let ordinal: Int
    let accountLiteral: String
    let productLiteral: String
    let currencyLiteral: String
    let periodStartLiteral: String
    let periodEndLiteral: String
    let firstSourceOrdinal: Int
    let lastSourceOrdinal: Int
    let firstPage: Int
    let lastPage: Int
    let rows: [NormalizedRow]
    let controls: [NormalizedBankSectionControl]
    let exhaustedRegion: NormalizedDocument.ExhaustedFinancialRegionEvidence
}

nonisolated enum BankAccountSourceIdentity: Equatable, Sendable {
    case fullAccountNumber(String)
    case maskedAccountNumber(String)

    var literal: String {
        switch self {
        case .fullAccountNumber(let value), .maskedAccountNumber(let value): return value
        }
    }
}

nonisolated struct BankSectionControlObservation: Equatable, Sendable {
    let kind: BankSectionControlKind
    let label: String
    let literal: String
    let money: Money?
    let count: Int?
    let sourceOrdinal: Int
    let sourcePage: Int
}

nonisolated struct BankAccountSectionEvidence: Equatable, Sendable {
    let id: String
    let ordinal: Int
    let sourceIdentity: BankAccountSourceIdentity
    let financialIdentifiers: [FinancialIdentifier]
    let productLabel: String
    let nativeCurrency: CurrencyCode
    let period: DeclaredStatementPeriod
    let firstSourceOrdinal: Int
    let lastSourceOrdinal: Int
    let firstPage: Int
    let lastPage: Int
    let transactionIDs: [UUID]
    let controls: [BankSectionControlObservation]
    let exhaustedRegion: NormalizedDocument.ExhaustedFinancialRegionEvidence
}

nonisolated struct BankStatementEvidence: Equatable, Sendable {
    let isAccountRelationshipStatement: Bool
    let sections: [BankAccountSectionEvidence]
}
