//
//  Transaction.swift
//  LedgerForge
//
//  Created by Vyom on 03/07/26.
//

import CryptoKit
import Foundation

/// A calendar date printed by a financial institution. It is deliberately not
/// an instant: it contains no time-of-day or timezone and never converts to
/// `Foundation.Date`.
struct StatementDate: Comparable, Equatable, Sendable, Hashable {
    let year: Int
    let month: Int
    let day: Int

    enum Error: Swift.Error, Equatable {
        case invalidComponents(year: Int, month: Int, day: Int)
        case malformedCanonical(String)
        case malformedAxisDate(String)
    }

    init(year: Int, month: Int, day: Int) throws {
        let leapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        let monthLengths = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard year >= 1, (1...12).contains(month), (1...monthLengths[month - 1]).contains(day) else {
            throw Error.invalidComponents(year: year, month: month, day: day)
        }
        self.year = year
        self.month = month
        self.day = day
    }

    init(canonical: String) throws {
        let parts = canonical.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            throw Error.malformedCanonical(canonical)
        }
        try self.init(year: year, month: month, day: day)
        guard self.canonical == canonical else { throw Error.malformedCanonical(canonical) }
    }

    static func axisNRE(_ source: String) throws -> StatementDate {
        let parts = source.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 2, parts[1].count == 2, parts[2].count == 4,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]) else {
            throw Error.malformedAxisDate(source)
        }
        do { return try StatementDate(year: year, month: month, day: day) }
        catch { throw Error.malformedAxisDate(source) }
    }

    var canonical: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var presentation: String {
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(day) \(names[month - 1]) \(String(format: "%02d", year % 100))"
    }

    static func < (lhs: StatementDate, rhs: StatementDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

enum FinancialDateRole: String, CaseIterable, Equatable, Sendable {
    case transactionDate = "transaction_date"
    case postingDate = "posting_date"
    case valueDate = "value_date"
    case settlementDate = "settlement_date"
    case tradeDate = "trade_date"
    case statementDate = "statement_date"
}

enum StatementTimezoneEvidence: Equatable, Sendable {
    enum PersistenceError: Error, Equatable {
        case malformedCode(String)
        case invalidIANAIdentifier(String)
    }
    case iana(String)
    case utc
    case unknown

    var persistenceCode: String {
        switch self { case .iana(let value): return "iana:\(value)"; case .utc: return "utc"; case .unknown: return "unknown" }
    }

    init(validatingPersistenceCode persistenceCode: String) throws {
        if persistenceCode == "utc" { self = .utc }
        else if persistenceCode == "unknown" { self = .unknown }
        else if persistenceCode.hasPrefix("iana:") {
            let identifier = String(persistenceCode.dropFirst(5))
            guard !identifier.isEmpty else { throw PersistenceError.malformedCode(persistenceCode) }
            guard TimeZone(identifier: identifier) != nil else { throw PersistenceError.invalidIANAIdentifier(identifier) }
            self = .iana(identifier)
        } else { throw PersistenceError.malformedCode(persistenceCode) }
    }
}

/// Privacy-minimal link between a transaction and one normalized source record.
struct TransactionSourceProvenance: Equatable, Sendable {
    let normalizedDocumentID: String
    let normalizedRowID: String
    let sourceOrdinal: Int
    let normalizedRecordDigest: String
    let parserProfileID: String
    let parserProfileVersion: String
}

extension String {
    static func normalizedRecordDigest(values: [String]) -> String {
        let payload = values.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
        return SHA256.hash(data: Data(payload.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

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

    /// Runtime identity is stable for persisted transactions. New parser output
    /// receives an ephemeral UUID until the provider persists its durable ID.
    let id: UUID
    let repositoryTransactionId: String?

    let statementDate: StatementDate?
    let financialDateRole: FinancialDateRole
    let statementTimezoneEvidence: StatementTimezoneEvidence
    let sourceProvenance: [TransactionSourceProvenance]

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
    var signedAmountDisplay: String {
        MoneyFormatting.signedDisplay(money, isCredit: creditMoney != nil)
    }

    /// Source sequence is meaningful only within one durable normalized document.
    nonisolated var documentScopedSourceOrder: (documentID: String, ordinal: Int)? {
        guard let first = sourceProvenance.first,
              first.sourceOrdinal > 0,
              sourceProvenance.allSatisfy({ $0.normalizedDocumentID == first.normalizedDocumentID }) else {
            return nil
        }
        return (first.normalizedDocumentID, first.sourceOrdinal)
    }

    var account: String

    var sourceBank: String

    var sourceFile: String

    /// Immutable persistence references retained exclusively through repository hydration.
    var repositoryAccountId: String? = nil
    var repositoryImportSessionId: String? = nil
    var verifiedAxisUPIEventEvidence: AxisUPITransactionEventEvidence? = nil

    init(
        statementDate: StatementDate?,
        description: String,
        debitMoney: Money?,
        creditMoney: Money?,
        money: Money,
        runningBalanceMoney: Money?,
        account: String,
        sourceBank: String,
        sourceFile: String,
        id: UUID = UUID(),
        repositoryTransactionId: String? = nil,
        financialDateRole: FinancialDateRole = .transactionDate,
        statementTimezoneEvidence: StatementTimezoneEvidence = .unknown,
        sourceProvenance: [TransactionSourceProvenance] = [],
        repositoryAccountId: String? = nil,
        repositoryImportSessionId: String? = nil,
        verifiedAxisUPIEventEvidence: AxisUPITransactionEventEvidence? = nil
    ) {
        self.id = id
        self.repositoryTransactionId = repositoryTransactionId
        self.statementDate = statementDate
        self.financialDateRole = financialDateRole
        self.statementTimezoneEvidence = statementTimezoneEvidence
        self.sourceProvenance = sourceProvenance
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
        statementDate: StatementDate?,
        description: String,
        debit: Decimal?,
        credit: Decimal?,
        amount: Decimal,
        balance: Decimal?,
        currency: String,
        account: String,
        sourceBank: String,
        sourceFile: String,
        id: UUID = UUID(),
        repositoryTransactionId: String? = nil,
        financialDateRole: FinancialDateRole = .transactionDate,
        statementTimezoneEvidence: StatementTimezoneEvidence = .unknown,
        sourceProvenance: [TransactionSourceProvenance] = [],
        repositoryAccountId: String? = nil,
        repositoryImportSessionId: String? = nil,
        verifiedAxisUPIEventEvidence: AxisUPITransactionEventEvidence? = nil
    ) {
        let postedMoney = try! Money(amount: amount, currency: currency)
        self.init(
            statementDate: statementDate,
            description: description,
            debitMoney: try! debit.map { try Money(amount: $0, currency: currency) },
            creditMoney: try! credit.map { try Money(amount: $0, currency: currency) },
            money: postedMoney,
            runningBalanceMoney: try! balance.map { try Money(amount: $0, currency: currency) },
            account: account,
            sourceBank: sourceBank,
            sourceFile: sourceFile,
            id: id,
            repositoryTransactionId: repositoryTransactionId,
            financialDateRole: financialDateRole,
            statementTimezoneEvidence: statementTimezoneEvidence,
            sourceProvenance: sourceProvenance,
            repositoryAccountId: repositoryAccountId,
            repositoryImportSessionId: repositoryImportSessionId,
            verifiedAxisUPIEventEvidence: verifiedAxisUPIEventEvidence
        )
    }
}
