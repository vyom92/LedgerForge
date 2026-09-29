//
//  Account.swift
//  LedgerForge
//
//  Created by Vyom on 06/07/26.
//

import Foundation

/// Presentation only; source and repository institution identities stay exact.
nonisolated enum AccountDisplayText {
    static func shortened(_ value: String) -> String {
        value.replacingOccurrences(of: "Commercial Bank of Qatar", with: "CBQ", options: .caseInsensitive)
    }

    /// Display only. An unknown trailing digit stays unknown; this never
    /// establishes account identity or removes masking to fill missing digits.
    static func maskedNumber(_ value: String) -> String? {
        let compact = value.filter { !$0.isWhitespace && $0 != "-" }
        let suffix = compact.suffix(4)
        guard suffix.count == 4, suffix.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return "xxx" + suffix
    }
}

enum AccountType: String, Codable {
    case bank
    case creditCard
    case investment
    case cash
    case loan
}

enum AccountStatus: String, Codable {
    case active
    case archived
    case closed
}

struct Account: Identifiable, Codable {

    let id: UUID

    /// Immutable persistence references retained exclusively through repository hydration.
    let repositoryAccountId: String?
    let workspaceId: String?

    var institution: String
    var name: String

    /// User-defined nickname shown throughout the app.
    var nickname: String?

    var type: AccountType

    /// Canonical native account currency.
    var nativeCurrency: CurrencyCode

    /// Time zone associated with the account's institution.
    var timeZoneIdentifier: String

    /// Current balance in the account's native currency.
    var currentBalanceMoney: Money

    /// For bank accounts, a nonnil canonical date means hydration selected a
    /// source-backed balance. Nil preserves unavailable/ambiguous authority;
    /// the legacy zero display fallback is not itself a balance observation.
    var currentBalanceAsOfISO: String?

    /// Transitional display accessors. Money remains the source of truth.
    var currencyCode: String { nativeCurrency.code }
    var currentBalance: Decimal { currentBalanceMoney.amount }

    /// Indicates whether the balance should contribute to overall net worth.
    var includeInNetWorth: Bool

    /// Base currency equivalent. Nil until exchange rates are available.
    var baseCurrencyBalance: Decimal?

    /// Exchange rate used to derive the base currency balance.
    var exchangeRateToBaseCurrency: Decimal?

    var status: AccountStatus
    /// Owner-confirmed closed and settled; financial records remain historical.
    var isHistoryOnly: Bool { type == .creditCard && status == .closed }

    var lastImport: Date?
    var identitySummaries: [AccountIdentitySummary]
    /// A presentation label derived from coherent, source-owned product labels.
    /// It never changes the canonical account identity or a saved owner name.
    var sourceProductName: String?
    var sourceAccountLabel: String?
    /// Last-four display derived from retained account-scoped source evidence.
    var sourceAccountNumberLabel: String?

    nonisolated var institutionDisplayName: String { AccountDisplayText.shortened(institution) }

    nonisolated var preferredDisplayName: String {
        if let nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return AccountDisplayText.shortened(nickname) }
        let identifierCharacters = CharacterSet(charactersIn: "0123456789Xx* -")
        if !name.isEmpty, name.unicodeScalars.allSatisfy(identifierCharacters.contains) {
            return AccountDisplayText.shortened(sourceProductName ?? institution + " account")
        }
        return AccountDisplayText.shortened(name)
    }

    nonisolated var selectionTitle: String {
        let identity = sourceAccountLabel ?? identitySummaries.first?.redactedValue
        return ([preferredDisplayName, identity, nativeCurrency.code].compactMap { $0 }).joined(separator: " · ")
    }

    init(
        id: UUID = UUID(),
        repositoryAccountId: String? = nil,
        workspaceId: String? = nil,
        institution: String,
        name: String,
        nickname: String? = nil,
        type: AccountType,
        currencyCode: String,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        currentBalance: Decimal = .zero,
        currentBalanceAsOfISO: String? = nil,
        includeInNetWorth: Bool = true,
        baseCurrencyBalance: Decimal? = nil,
        exchangeRateToBaseCurrency: Decimal? = nil,
        status: AccountStatus = .active,
        lastImport: Date? = nil,
        identitySummaries: [AccountIdentitySummary] = [],
        sourceProductName: String? = nil,
        sourceAccountLabel: String? = nil,
        sourceAccountNumberLabel: String? = nil
    ) {
        self.id = id
        self.repositoryAccountId = repositoryAccountId
        self.workspaceId = workspaceId
        self.institution = institution
        self.name = name
        self.nickname = nickname
        self.type = type
        self.nativeCurrency = try! CurrencyCode(currencyCode)
        self.timeZoneIdentifier = timeZoneIdentifier
        self.currentBalanceMoney = try! Money(amount: currentBalance, currency: self.nativeCurrency)
        self.currentBalanceAsOfISO = currentBalanceAsOfISO
        self.includeInNetWorth = includeInNetWorth
        self.baseCurrencyBalance = baseCurrencyBalance
        self.exchangeRateToBaseCurrency = exchangeRateToBaseCurrency
        self.status = status
        self.lastImport = lastImport
        self.identitySummaries = identitySummaries
        self.sourceProductName = sourceProductName
        self.sourceAccountLabel = sourceAccountLabel
        self.sourceAccountNumberLabel = sourceAccountNumberLabel
    }
}

/// Presentation-safe financial identity derived during repository hydration.
/// It intentionally contains no normalized identifier value.
struct AccountIdentitySummary: Identifiable, Codable, Equatable {
    let id: String
    let kind: String
    let redactedValue: String
    let strength: String
    let verificationState: String
    let provenance: String
}
