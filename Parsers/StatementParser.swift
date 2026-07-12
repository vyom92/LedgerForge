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

    /// Parses normalized statement content into the canonical financial handoff.
    ///
    /// Under ADR-027, statement parsers are the exclusive production origin of
    /// verified financial identifiers and return them through
    /// `FinancialDocument.financialIdentifiers`.
    func parse(
        document: NormalizedDocument
    ) throws -> FinancialDocument

}
