//
//  ImportValidator.swift
//  LedgerForge
//
//  Created by Vyom on 06/07/26.
//

import Foundation

/// Performs validation on imported transactions before they are trusted by the application.
final class ImportValidator {

    static func validate(transactions: [Transaction]) -> ImportValidationResult {

        var issues: [ValidationIssue] = []

        if transactions.isEmpty {
            issues.append(
                ValidationIssue(
                    severity: .error,
                    rowNumber: nil,
                    message: "No transactions were imported."
                )
            )
        }

        for transaction in transactions {
            if transaction.debit == nil && transaction.credit == nil {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        rowNumber: nil,
                        message: "Transaction '\(transaction.description)' has neither a debit nor a credit amount."
                    )
                )
            }

            if transaction.balance == nil {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        rowNumber: nil,
                        message: "Transaction '\(transaction.description)' is missing a running balance."
                    )
                )
            }
        }

        let debitTotal = transactions.reduce(.zero) { $0 + ($1.debit ?? .zero) }
        let creditTotal = transactions.reduce(.zero) { $0 + ($1.credit ?? .zero) }

        let firstTransaction = transactions.first
        let openingBalance: Decimal? = {
            guard let first = firstTransaction,
                  let firstBalance = first.balance else {
                return nil
            }

            return firstBalance + (first.debit ?? .zero) - (first.credit ?? .zero)
        }()

        let closingBalance = transactions.last?.balance

        if transactions.count > 1 {
            for index in 1..<transactions.count {
                let previous = transactions[index - 1]
                let current = transactions[index]

                guard let previousBalance = previous.balance,
                      let currentBalance = current.balance else {
                    continue
                }

                var expectedBalance = previousBalance
                if let debit = current.debit { expectedBalance -= debit }
                if let credit = current.credit { expectedBalance += credit }

                if expectedBalance != currentBalance {
                    issues.append(
                        ValidationIssue(
                            severity: .error,
                            rowNumber: index + 1,
                            message: "Balance reconciliation failed on \(current.description). Expected \(expectedBalance), found \(currentBalance)."
                        )
                    )
                }
            }
        }

        if let openingBalance, let closingBalance {
            let expectedClosingBalance = openingBalance + creditTotal - debitTotal
            if expectedClosingBalance != closingBalance {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        rowNumber: nil,
                        message: "Statement totals do not reconcile. Expected closing balance \(expectedClosingBalance), found \(closingBalance)."
                    )
                )
            }
        }

        return ImportValidationResult(
            rowsRead: transactions.count,
            transactionsParsed: transactions.count,
            debitTotal: debitTotal,
            creditTotal: creditTotal,
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            passed: issues.isEmpty,
            issues: issues
        )
    }
}
