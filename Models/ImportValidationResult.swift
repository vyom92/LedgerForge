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

    let statementCurrency: CurrencyCode?
    let debitTotalMoney: Money?
    let creditTotalMoney: Money?
    let openingBalanceMoney: Money?
    let closingBalanceMoney: Money?

    var debitTotal: Decimal { debitTotalMoney?.amount ?? .zero }
    var creditTotal: Decimal { creditTotalMoney?.amount ?? .zero }
    var openingBalance: Decimal? {
        switch openingBalanceMoney {
        case .some(let money):
            return money.amount
        case .none:
            return nil
        }
    }

    var closingBalance: Decimal? {
        switch closingBalanceMoney {
        case .some(let money):
            return money.amount
        case .none:
            return nil
        }
    }

    let passed: Bool

    let issues: [ValidationIssue]

    static let empty = ImportValidationResult(
        rowsRead: 0,
        transactionsParsed: 0,
        statementCurrency: nil,
        debitTotalMoney: nil,
        creditTotalMoney: nil,
        openingBalanceMoney: nil,
        closingBalanceMoney: nil,
        passed: true,
        issues: []
    )
}
