// LedgerForge
// FinancialDocument.swift
// Version: 0.1.0

import Foundation

struct FinancialDocument: Identifiable {

    let id: UUID
    let sourceDocument: Document
    let metadata: DocumentMetadata
    let parserName: String
    /// Parser-owned booked currency; never inferred from only one transaction.
    let bookedCurrency: CurrencyCode?
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
        self.transactions = transactions
        self.financialIdentifiers = financialIdentifiers
        self.selectionReasons = selectionReasons
        self.createdAt = createdAt
    }

}
