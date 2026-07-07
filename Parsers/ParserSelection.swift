// LedgerForge
// ParserSelection.swift
// Version: 0.1.0

import Foundation

struct ParserSelection {

    let parser: StatementParser?
    let parserName: String?
    let matched: Bool
    let confidence: Double
    let reasons: [String]
    let legacyMetadata: DocumentMetadata

}
