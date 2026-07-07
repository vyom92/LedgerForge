// LedgerForge
// FinancialDocumentBuilder.swift
// Version: 0.1.0

import Foundation

enum FinancialDocumentBuilderError: Error, Equatable {
    case parserNotSelected
}

struct FinancialDocumentBuilder {

    static func build(
        normalizedDocument: NormalizedDocument,
        parserName: String,
        transactions: [Transaction],
        selectionReasons: [String] = [],
        createdAt: Date = Date()
    ) -> FinancialDocument {
        FinancialDocument(
            sourceDocument: normalizedDocument.document,
            metadata: normalizedDocument.metadata,
            parserName: parserName,
            transactions: transactions,
            selectionReasons: selectionReasons,
            createdAt: createdAt
        )
    }

    static func build(
        normalizedDocument: NormalizedDocument,
        parserSelection: ParserSelection,
        transactions: [Transaction],
        createdAt: Date = Date()
    ) throws -> FinancialDocument {
        guard parserSelection.matched, let parserName = parserSelection.parserName else {
            throw FinancialDocumentBuilderError.parserNotSelected
        }

        return build(
            normalizedDocument: normalizedDocument,
            parserName: parserName,
            transactions: transactions,
            selectionReasons: parserSelection.reasons,
            createdAt: createdAt
        )
    }

}
