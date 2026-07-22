//
//  ImportValidator.swift
//  LedgerForge
//
//  Created by Vyom on 06/07/26.
//

import Foundation

/// Performs validation on imported transactions before they are trusted by the application.
final class ImportValidator {

    static func validate(financialDocument: FinancialDocument) -> ImportValidationResult {
        validate(transactions: financialDocument.transactions, statementCurrency: financialDocument.bookedCurrency)
    }

    static func validate(transactions: [Transaction]) -> ImportValidationResult {
        let currencies = Set(transactions.map(\.money.currency))
        return validate(transactions: transactions, statementCurrency: currencies.count == 1 ? currencies.first : nil)
    }

    private static func validate(
        transactions: [Transaction],
        statementCurrency: CurrencyCode?
    ) -> ImportValidationResult {

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

        if !transactions.isEmpty, statementCurrency == nil {
            issues.append(ValidationIssue(
                severity: .error,
                rowNumber: nil,
                message: "Statement currency is missing or transactions use mixed currencies."
            ))
        }

        for (index, transaction) in transactions.enumerated() {
            if transaction.statementDate == nil {
                issues.append(ValidationIssue(
                    severity: .error,
                    rowNumber: transaction.sourceProvenance.first?.sourceOrdinal ?? index + 1,
                    message: "Transaction is missing a statement date."
                ))
            }
            if let statementCurrency, transaction.money.currency != statementCurrency {
                issues.append(ValidationIssue(
                    severity: .error,
                    rowNumber: nil,
                    message: "Transaction currency does not match statement currency."
                ))
            }
            if transaction.debitMoney?.currency != nil && transaction.debitMoney?.currency != transaction.money.currency {
                issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Transaction debit currency does not match posted currency."))
            }
            if transaction.creditMoney?.currency != nil && transaction.creditMoney?.currency != transaction.money.currency {
                issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Transaction credit currency does not match posted currency."))
            }
            if transaction.runningBalanceMoney?.currency != nil && transaction.runningBalanceMoney?.currency != transaction.money.currency {
                issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Running-balance currency does not match posted currency."))
            }
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

        let debitTotalMoney = try? moneySum(transactions.compactMap(\.debitMoney), currency: statementCurrency)
        let creditTotalMoney = try? moneySum(transactions.compactMap(\.creditMoney), currency: statementCurrency)

        let firstTransaction = transactions.first
        let openingBalanceMoney: Money? = {
            guard let first = firstTransaction,
                  let firstBalance = first.runningBalanceMoney else {
                return nil
            }
            var opening = firstBalance
            if let debit = first.debitMoney { opening = (try? opening + debit) ?? opening }
            if let credit = first.creditMoney { opening = (try? opening - credit) ?? opening }
            return opening
        }()

        let closingBalanceMoney = transactions.last?.runningBalanceMoney

        if transactions.count > 1 {
            for index in 1..<transactions.count {
                let previous = transactions[index - 1]
                let current = transactions[index]

                guard let previousBalance = previous.runningBalanceMoney,
                      let currentBalance = current.runningBalanceMoney else {
                    continue
                }

                var expectedBalance = previousBalance
                if let debit = current.debitMoney { expectedBalance = (try? expectedBalance - debit) ?? expectedBalance }
                if let credit = current.creditMoney { expectedBalance = (try? expectedBalance + credit) ?? expectedBalance }

                if expectedBalance != currentBalance {
                    issues.append(
                        ValidationIssue(
                            severity: .error,
                            rowNumber: current.sourceProvenance.first?.sourceOrdinal ?? index + 1,
                            message: "Balance reconciliation failed on \(current.description). Expected \(expectedBalance.amount), found \(currentBalance.amount)."
                        )
                    )
                }
            }
        }

        if let openingBalanceMoney, let closingBalanceMoney,
           let debitTotalMoney, let creditTotalMoney,
           let expectedClosingBalance = try? (try openingBalanceMoney + creditTotalMoney) - debitTotalMoney {
            if expectedClosingBalance != closingBalanceMoney {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        rowNumber: nil,
                        message: "Statement totals do not reconcile. Expected closing balance \(expectedClosingBalance.amount), found \(closingBalanceMoney.amount)."
                    )
                )
            }
        }

        return ImportValidationResult(
            rowsRead: transactions.count,
            transactionsParsed: transactions.count,
            statementCurrency: statementCurrency,
            debitTotalMoney: debitTotalMoney,
            creditTotalMoney: creditTotalMoney,
            openingBalanceMoney: openingBalanceMoney,
            closingBalanceMoney: closingBalanceMoney,
            passed: issues.isEmpty,
            issues: issues
        )
    }

    private static func moneySum(_ values: [Money], currency: CurrencyCode?) throws -> Money? {
        guard let currency else { return nil }
        guard !values.isEmpty else { return try Money(amount: .zero, currency: currency) }
        return try Money.aggregate(values)
    }
}
