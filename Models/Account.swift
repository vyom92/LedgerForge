//
//  Account.swift
//  LedgerForge
//
//  Created by Vyom on 06/07/26.
//

import Foundation

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

    /// ISO-4217 currency code (e.g. INR, USD, QAR)
    var currencyCode: String

    /// Time zone associated with the account's institution.
    var timeZoneIdentifier: String

    /// Current balance in the account's native currency.
    var currentBalance: Decimal

    /// Indicates whether the balance should contribute to overall net worth.
    var includeInNetWorth: Bool

    /// Base currency equivalent. Nil until exchange rates are available.
    var baseCurrencyBalance: Decimal?

    /// Exchange rate used to derive the base currency balance.
    var exchangeRateToBaseCurrency: Decimal?

    var status: AccountStatus

    var lastImport: Date?
    var identitySummaries: [AccountIdentitySummary]

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
        includeInNetWorth: Bool = true,
        baseCurrencyBalance: Decimal? = nil,
        exchangeRateToBaseCurrency: Decimal? = nil,
        status: AccountStatus = .active,
        lastImport: Date? = nil,
        identitySummaries: [AccountIdentitySummary] = []
    ) {
        self.id = id
        self.repositoryAccountId = repositoryAccountId
        self.workspaceId = workspaceId
        self.institution = institution
        self.name = name
        self.nickname = nickname
        self.type = type
        self.currencyCode = currencyCode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.currentBalance = currentBalance
        self.includeInNetWorth = includeInNetWorth
        self.baseCurrencyBalance = baseCurrencyBalance
        self.exchangeRateToBaseCurrency = exchangeRateToBaseCurrency
        self.status = status
        self.lastImport = lastImport
        self.identitySummaries = identitySummaries
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
