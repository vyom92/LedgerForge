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

    init(
        id: UUID = UUID(),
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
        lastImport: Date? = nil
    ) {
        self.id = id
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
    }
}
