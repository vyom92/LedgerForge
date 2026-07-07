// LedgerForge
// FinancialDocument.swift
// Version: 0.1.0

import Foundation

struct FinancialDocument: Identifiable {

    let id: UUID
    let sourceDocument: Document
    let metadata: DocumentMetadata
    let parserName: String
    let transactions: [Transaction]
    let selectionReasons: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sourceDocument: Document,
        metadata: DocumentMetadata,
        parserName: String,
        transactions: [Transaction],
        selectionReasons: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceDocument = sourceDocument
        self.metadata = metadata
        self.parserName = parserName
        self.transactions = transactions
        self.selectionReasons = selectionReasons
        self.createdAt = createdAt
    }

}
