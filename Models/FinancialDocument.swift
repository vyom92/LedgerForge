// LedgerForge
// FinancialDocument.swift
// Version: 0.1.0

import CryptoKit
import Foundation

struct DeclaredStatementPeriod: Equatable, Sendable {
    let start: StatementDate
    let end: StatementDate

    enum Error: Swift.Error, Equatable {
        case reversed
    }

    init(start: StatementDate, end: StatementDate) throws {
        guard start <= end else { throw Error.reversed }
        self.start = start
        self.end = end
    }
}

struct FinancialDocument: Identifiable {

    let id: UUID
    let sourceDocument: Document
    let metadata: DocumentMetadata
    let parserName: String
    /// Parser-owned booked currency; never inferred from only one transaction.
    let bookedCurrency: CurrencyCode?
    /// Exact parser-owned source period. It is never reconstructed from the
    /// first and last transaction dates.
    let declaredStatementPeriod: DeclaredStatementPeriod?
    let transactions: [Transaction]
    let financialIdentifiers: [FinancialIdentifier]
    let selectionReasons: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sourceDocument: Document,
        metadata: DocumentMetadata,
        parserName: String,
        bookedCurrency: CurrencyCode? = nil,
        declaredStatementPeriod: DeclaredStatementPeriod? = nil,
        transactions: [Transaction],
        financialIdentifiers: [FinancialIdentifier] = [],
        selectionReasons: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceDocument = sourceDocument
        self.metadata = metadata
        self.parserName = parserName
        self.bookedCurrency = bookedCurrency
        self.declaredStatementPeriod = declaredStatementPeriod
        self.transactions = transactions
        self.financialIdentifiers = financialIdentifiers
        self.selectionReasons = selectionReasons
        self.createdAt = createdAt
    }

}

enum StatementFinancialProjectionError: Error, Equatable, LocalizedError {
    case unsupportedDocument
    case missingStatementPeriod
    case missingCurrency
    case noEvents
    case missingStatementDate(ordinal: Int)
    case missingValueDate(ordinal: Int)
    case missingDirection(ordinal: Int)
    case ambiguousDirection(ordinal: Int)
    case missingRunningBalance(ordinal: Int)
    case currencyMismatch(ordinal: Int)
    case nonPositiveAmount(ordinal: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedDocument:
            return "The statement family does not support an exact financial projection."
        case .missingStatementPeriod:
            return "An exact statement projection requires a declared statement period."
        case .missingCurrency:
            return "An exact statement projection requires a native currency."
        case .noEvents:
            return "An exact statement projection requires at least one event."
        case .missingStatementDate:
            return "An exact statement projection event is missing its statement date."
        case .missingValueDate:
            return "An exact statement projection event is missing its value date."
        case .missingDirection:
            return "An exact statement projection event is missing its direction."
        case .ambiguousDirection:
            return "An exact statement projection event has two amount directions."
        case .missingRunningBalance:
            return "An exact statement projection event is missing its running balance."
        case .currencyMismatch:
            return "An exact statement projection event has conflicting currency evidence."
        case .nonPositiveAmount:
            return "An exact statement projection event has a non-positive movement."
        }
    }
}

/// Format-neutral, account-independent financial truth for one explicitly
/// supported whole statement. The digest excludes presentation and source
/// container evidence by construction.
struct StatementFinancialProjection: Equatable, Sendable {
    static let algorithm = "ledgerforge.statement-financial-projection.sha256.v1"
    static let hdfcInstitutionCode = "hdfc"
    static let hdfcBankAccountFamilyCode = "hdfc.bank-account"

    enum Direction: String, Equatable, Sendable {
        case debit
        case credit
    }

    struct Event: Equatable, Sendable {
        let ordinal: Int
        let statementDate: StatementDate
        let valueDate: StatementDate
        let direction: Direction
        let signedAmount: Money
        let runningBalance: Money
        let reference: String?
    }

    let algorithmIdentifier: String
    let institutionCode: String
    let statementFamilyCode: String
    let statementPeriod: DeclaredStatementPeriod
    let nativeCurrency: CurrencyCode
    let eventCount: Int
    let openingBalance: Money
    let debitCount: Int
    let creditCount: Int
    let debitTotal: Money
    let creditTotal: Money
    let closingBalance: Money
    let events: [Event]
    let digest: String

    static func make(from document: FinancialDocument) throws -> StatementFinancialProjection {
        guard document.metadata.institution == .hdfc,
              document.metadata.documentType == .bankAccount,
              [.pdf, .xls].contains(document.metadata.fileFormat) else {
            throw StatementFinancialProjectionError.unsupportedDocument
        }
        guard let period = document.declaredStatementPeriod else {
            throw StatementFinancialProjectionError.missingStatementPeriod
        }
        guard let currency = document.bookedCurrency else {
            throw StatementFinancialProjectionError.missingCurrency
        }
        guard !document.transactions.isEmpty else {
            throw StatementFinancialProjectionError.noEvents
        }

        var events: [Event] = []
        var debitCount = 0
        var creditCount = 0
        var debitMinor: Int64 = 0
        var creditMinor: Int64 = 0

        for (index, transaction) in document.transactions.enumerated() {
            let ordinal = index + 1
            guard let statementDate = transaction.statementDate else {
                throw StatementFinancialProjectionError.missingStatementDate(ordinal: ordinal)
            }
            guard let valueDate = transaction.valueDate else {
                throw StatementFinancialProjectionError.missingValueDate(ordinal: ordinal)
            }
            guard let runningBalance = transaction.runningBalanceMoney else {
                throw StatementFinancialProjectionError.missingRunningBalance(ordinal: ordinal)
            }
            guard transaction.money.currency == currency,
                  runningBalance.currency == currency,
                  transaction.debitMoney.map({ $0.currency == currency }) ?? true,
                  transaction.creditMoney.map({ $0.currency == currency }) ?? true else {
                throw StatementFinancialProjectionError.currencyMismatch(ordinal: ordinal)
            }

            let direction: Direction
            let magnitude: Money
            switch (transaction.debitMoney, transaction.creditMoney) {
            case (.some(let debit), nil):
                direction = .debit
                magnitude = debit
                debitCount += 1
            case (nil, .some(let credit)):
                direction = .credit
                magnitude = credit
                creditCount += 1
            case (nil, nil):
                throw StatementFinancialProjectionError.missingDirection(ordinal: ordinal)
            case (.some, .some):
                throw StatementFinancialProjectionError.ambiguousDirection(ordinal: ordinal)
            }
            let magnitudeMinor = try magnitude.minorUnits()
            let signedMinor = try transaction.money.minorUnits()
            guard magnitudeMinor > 0 else {
                throw StatementFinancialProjectionError.nonPositiveAmount(ordinal: ordinal)
            }
            guard (direction == .debit && signedMinor == -magnitudeMinor) ||
                    (direction == .credit && signedMinor == magnitudeMinor) else {
                throw StatementFinancialProjectionError.ambiguousDirection(ordinal: ordinal)
            }
            if direction == .debit {
                let addition = debitMinor.addingReportingOverflow(magnitudeMinor)
                guard !addition.overflow else { throw MoneyError.minorUnitOverflow(currency: currency.code) }
                debitMinor = addition.partialValue
            } else {
                let addition = creditMinor.addingReportingOverflow(magnitudeMinor)
                guard !addition.overflow else { throw MoneyError.minorUnitOverflow(currency: currency.code) }
                creditMinor = addition.partialValue
            }
            events.append(
                Event(
                    ordinal: ordinal,
                    statementDate: statementDate,
                    valueDate: valueDate,
                    direction: direction,
                    signedAmount: transaction.money,
                    runningBalance: runningBalance,
                    reference: transaction.reference
                )
            )
        }

        guard let first = events.first, let last = events.last else {
            throw StatementFinancialProjectionError.noEvents
        }
        let openingBalance = try first.runningBalance - first.signedAmount
        let debitTotal = try Money.fromMinorUnits(debitMinor, currency: currency.code)
        let creditTotal = try Money.fromMinorUnits(creditMinor, currency: currency.code)
        let digest = try makeDigest(
            institutionCode: hdfcInstitutionCode,
            statementFamilyCode: hdfcBankAccountFamilyCode,
            statementPeriod: period,
            nativeCurrency: currency,
            eventCount: events.count,
            openingBalance: openingBalance,
            debitCount: debitCount,
            creditCount: creditCount,
            debitTotal: debitTotal,
            creditTotal: creditTotal,
            closingBalance: last.runningBalance,
            events: events
        )
        return StatementFinancialProjection(
            algorithmIdentifier: algorithm,
            institutionCode: hdfcInstitutionCode,
            statementFamilyCode: hdfcBankAccountFamilyCode,
            statementPeriod: period,
            nativeCurrency: currency,
            eventCount: events.count,
            openingBalance: openingBalance,
            debitCount: debitCount,
            creditCount: creditCount,
            debitTotal: debitTotal,
            creditTotal: creditTotal,
            closingBalance: last.runningBalance,
            events: events,
            digest: digest
        )
    }

    func hasValidDigest() -> Bool {
        guard algorithmIdentifier == Self.algorithm,
              eventCount == events.count,
              eventCount == debitCount + creditCount else { return false }
        return (try? Self.makeDigest(
            institutionCode: institutionCode,
            statementFamilyCode: statementFamilyCode,
            statementPeriod: statementPeriod,
            nativeCurrency: nativeCurrency,
            eventCount: eventCount,
            openingBalance: openingBalance,
            debitCount: debitCount,
            creditCount: creditCount,
            debitTotal: debitTotal,
            creditTotal: creditTotal,
            closingBalance: closingBalance,
            events: events
        )) == digest
    }

    private static func makeDigest(
        institutionCode: String,
        statementFamilyCode: String,
        statementPeriod: DeclaredStatementPeriod,
        nativeCurrency: CurrencyCode,
        eventCount: Int,
        openingBalance: Money,
        debitCount: Int,
        creditCount: Int,
        debitTotal: Money,
        creditTotal: Money,
        closingBalance: Money,
        events: [Event]
    ) throws -> String {
        var fields = [
            algorithm,
            institutionCode,
            statementFamilyCode,
            statementPeriod.start.canonical,
            statementPeriod.end.canonical,
            nativeCurrency.code,
            String(eventCount),
            try openingBalance.canonicalDecimalString(),
            String(debitCount),
            String(creditCount),
            try debitTotal.canonicalDecimalString(),
            try creditTotal.canonicalDecimalString(),
            try closingBalance.canonicalDecimalString()
        ]
        for event in events {
            fields.append(contentsOf: [
                String(event.ordinal),
                event.statementDate.canonical,
                event.valueDate.canonical,
                event.direction.rawValue,
                event.signedAmount.currency.code,
                try event.signedAmount.canonicalDecimalString(),
                event.runningBalance.currency.code,
                try event.runningBalance.canonicalDecimalString(),
                event.reference == nil ? "0" : "1",
                event.reference ?? ""
            ])
        }
        let payload = fields.map { "\($0.utf8.count):\($0)" }.joined()
        return SHA256.hash(data: Data(payload.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
