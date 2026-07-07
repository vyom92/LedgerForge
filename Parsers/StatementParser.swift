//
// LedgerForge
// StatementParser.swift
// Version: 0.2.0
//

import Foundation

protocol StatementParser {

    var name: String { get }

    func canParse(
        document: Document,
        metadata: DocumentMetadata
    ) -> Bool

    func parse(
        document: NormalizedDocument
    ) throws -> FinancialDocument

}
