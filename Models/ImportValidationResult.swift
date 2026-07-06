//
//  ImportValidationResult.swift
//  LedgerForge
//
//  Created by Vyom on 06/07/26.
//

import Foundation

enum ValidationSeverity {
    case info
    case warning
    case error
}

/// Represents a validation issue discovered during import.
struct ValidationIssue: Identifiable {
    let id = UUID()
    let severity: ValidationSeverity
    let rowNumber: Int?
    let message: String
}

/// Represents the overall outcome of validating an imported statement.
struct ImportValidationResult {

    let rowsRead: Int
    let transactionsParsed: Int

    let debitTotal: Decimal
    let creditTotal: Decimal

    let openingBalance: Decimal?
    let closingBalance: Decimal?

    let passed: Bool

    let issues: [ValidationIssue]

    static let empty = ImportValidationResult(
        rowsRead: 0,
        transactionsParsed: 0,
        debitTotal: 0,
        creditTotal: 0,
        openingBalance: nil,
        closingBalance: nil,
        passed: true,
        issues: []
    )
}
