//
// LedgerForge
// AxisBankAccountParser.swift
// Version: 0.2.0
//

import Foundation

final class AxisBankAccountParser: StatementParser {

    var name: String {
        "Axis Bank Account"
    }

    func canParse(
        document: Document,
        metadata: DocumentMetadata
    ) -> Bool {

        return metadata.institution == .axis &&
               metadata.documentType == .bankAccount
    }

    func parse(
        document: NormalizedDocument
    ) throws -> [Transaction] {

        // Parsing logic will be implemented in the next sprint.
        return []
    }
}
