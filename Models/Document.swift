// LedgerForge
// Document.swift
// Version: 0.0.4

import Foundation

struct Document: Identifiable {

    let id = UUID()

    let filename: String
    let url: URL
    let fileType: String
    let importedAt: Date

    var rowCount: Int = 0

    var headerRow: Int?

    var firstTransactionRow: Int?

    var delimiter: Character?

    var columnCount: Int = 0

    var encoding: String?

    var institution: String?

    var parserVersion: String?

    var confidence: Double?
}
