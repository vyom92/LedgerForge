//
//  Transaction.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//

import Foundation

struct AxisUPITransactionEventEvidence: Equatable, Sendable {
    enum Operation: String, Equatable, Sendable {
        case p2a
        case p2m
    }

    enum LedgerSubtype: String, Equatable, Sendable {
        case posting
        case creditAdjustment = "credit-adjustment"
    }

    let operation: Operation
    let reference: String
    let subtype: LedgerSubtype
}

struct Transaction: Identifiable {

    let id = UUID()

    var date: Date?

    var description: String

    let debitMoney: Money?
    let creditMoney: Money?
    let money: Money
    let runningBalanceMoney: Money?

    /// Transitional presentation accessors. Money remains the sole authority.
    var debit: Decimal? { debitMoney?.amount }
    var credit: Decimal? { creditMoney?.amount }
    var amount: Decimal { money.amount }
    var balance: Decimal? { runningBalanceMoney?.amount }
    var currency: String { money.currency.code }

    var account: String

    var sourceBank: String

    var sourceFile: String

    /// Immutable persistence references retained exclusively through repository hydration.
    var repositoryAccountId: String? = nil
    var repositoryImportSessionId: String? = nil
    var verifiedAxisUPIEventEvidence: AxisUPITransactionEventEvidence? = nil

    init(
        date: Date?,
        description: String,
        debitMoney: Money?,
        creditMoney: Money?,
        money: Money,
        runningBalanceMoney: Money?,
        account: String,
        sourceBank: String,
        sourceFile: String,
        repositoryAccountId: String? = nil,
        repositoryImportSessionId: String? = nil,
        verifiedAxisUPIEventEvidence: AxisUPITransactionEventEvidence? = nil
    ) {
        self.date = date
        self.description = description
        self.debitMoney = debitMoney
        self.creditMoney = creditMoney
        self.money = money
        self.runningBalanceMoney = runningBalanceMoney
        self.account = account
        self.sourceBank = sourceBank
        self.sourceFile = sourceFile
        self.repositoryAccountId = repositoryAccountId
        self.repositoryImportSessionId = repositoryImportSessionId
        self.verifiedAxisUPIEventEvidence = verifiedAxisUPIEventEvidence
    }

    init(
        date: Date?,
        description: String,
        debit: Decimal?,
        credit: Decimal?,
        amount: Decimal,
        balance: Decimal?,
        currency: String,
        account: String,
        sourceBank: String,
        sourceFile: String,
        repositoryAccountId: String? = nil,
        repositoryImportSessionId: String? = nil,
        verifiedAxisUPIEventEvidence: AxisUPITransactionEventEvidence? = nil
    ) {
        let postedMoney = try! Money(amount: amount, currency: currency)
        self.init(
            date: date,
            description: description,
            debitMoney: try! debit.map { try Money(amount: $0, currency: currency) },
            creditMoney: try! credit.map { try Money(amount: $0, currency: currency) },
            money: postedMoney,
            runningBalanceMoney: try! balance.map { try Money(amount: $0, currency: currency) },
            account: account,
            sourceBank: sourceBank,
            sourceFile: sourceFile,
            repositoryAccountId: repositoryAccountId,
            repositoryImportSessionId: repositoryImportSessionId,
            verifiedAxisUPIEventEvidence: verifiedAxisUPIEventEvidence
        )
    }
}
