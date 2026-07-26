// LedgerForge
// FinancialDocument.swift
// Version: 0.1.0

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
