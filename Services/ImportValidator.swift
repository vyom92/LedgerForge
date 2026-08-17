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
        if let cardEvidence = financialDocument.cardStatementEvidence {
            return validateCardStatement(
                financialDocument: financialDocument,
                evidence: cardEvidence
            )
        }
        let usesRowAssociatedBalancesWithoutSourceOrderRecurrence =
            financialDocument.metadata.institution == .cbq
                && financialDocument.metadata.documentType == .bankAccount
                && !financialDocument.transactions.isEmpty
                && financialDocument.transactions.allSatisfy { transaction in
                    !transaction.sourceProvenance.isEmpty
                        && transaction.sourceProvenance.allSatisfy {
                            [CBQCurrentAccountXLSParser.profileID, CBQCurrentAccountPDFParser.historyProfileID]
                                .contains($0.parserProfileID)
                                && $0.parserProfileVersion == "1"
                        }
                }
        return validate(
            transactions: financialDocument.transactions,
            statementCurrency: financialDocument.bookedCurrency,
            reconcileSourceOrderBalances: !usesRowAssociatedBalancesWithoutSourceOrderRecurrence
        )
    }

    private static func validateCardStatement(
        financialDocument: FinancialDocument,
        evidence: CardStatementEvidence
    ) -> ImportValidationResult {
        let transactions = financialDocument.transactions
        var issues: [ValidationIssue] = []
        let currency = evidence.nativeCurrency
        let sectionIDs = Set(evidence.instrumentSections.map(\.documentScopedSectionID))
        let annotationsByID = Dictionary(
            uniqueKeysWithValues: evidence.transactionAnnotations.map { ($0.parserTransactionID, $0) }
        )

        if financialDocument.metadata.documentType != .creditCard ||
            financialDocument.bookedCurrency != currency ||
            financialDocument.declaredStatementPeriod != evidence.declaredStatementPeriod {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Card statement metadata conflicts with parser evidence."))
        }
        if transactions.isEmpty || annotationsByID.count != transactions.count ||
            Set(transactions.map(\.id)) != Set(annotationsByID.keys) {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Every card financial row requires exactly one transaction annotation."))
        }

        var increaseValues: [Money] = []
        var decreaseValues: [Money] = []
        var instrumentIncreaseValues: [Money] = []
        var instrumentDecreaseValues: [Money] = []
        var sectionValues = Dictionary(uniqueKeysWithValues: sectionIDs.map { ($0, [Money]()) })

        for (index, transaction) in transactions.enumerated() {
            let row = transaction.sourceProvenance.first?.sourceOrdinal ?? index + 1
            guard let postingDate = transaction.statementDate,
                  let annotation = annotationsByID[transaction.id] else {
                issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "Card row is missing posting-date or annotation evidence."))
                continue
            }
            if postingDate < evidence.declaredStatementPeriod.start || postingDate > evidence.declaredStatementPeriod.end {
                issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "Card posting date is outside the declared statement period."))
            }
            if transaction.financialDateRole != .postingDate ||
                transaction.money.currency != currency ||
                transaction.debitMoney != nil || transaction.creditMoney != nil ||
                transaction.runningBalanceMoney != nil ||
                transaction.cardLiabilityEffect != annotation.liabilityEffect ||
                transaction.sourceProvenance.count != 1 ||
                transaction.sourceProvenance[0].sourceTransactionDate != annotation.sourceTransactionDate ||
                transaction.sourceProvenance[0].parserProfileID != AmericanExpressCreditCardPDFParser.profileID ||
                transaction.sourceProvenance[0].parserProfileVersion != AmericanExpressCreditCardPDFParser.profileVersion {
                issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "Card row semantics or provenance are incomplete."))
            }
            if let original = annotation.originalMerchantMoney,
               original.currency == currency {
                issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "Original merchant Money must represent non-statement currency."))
            }
            let minor = try? transaction.money.minorUnits()
            switch annotation.liabilityEffect {
            case .increasesAmountOwed:
                if minor.map({ $0 <= 0 }) ?? true {
                    issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "A card charge must increase amount owed with positive signed Money."))
                }
                increaseValues.append(transaction.money)
            case .decreasesAmountOwed:
                if minor.map({ $0 >= 0 }) ?? true {
                    issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "A card payment or credit must decrease amount owed with negative signed Money."))
                }
                if let positive = try? Money(amount: -transaction.money.amount, currency: currency) {
                    decreaseValues.append(positive)
                }
            }
            switch annotation.rowScope {
            case .accountLevel:
                break
            case .instrument(let sectionID):
                if !sectionIDs.contains(sectionID) {
                    issues.append(ValidationIssue(severity: .error, rowNumber: row, message: "Card instrument row references an unknown document section."))
                } else {
                    sectionValues[sectionID, default: []].append(transaction.money)
                }
                if annotation.liabilityEffect == .increasesAmountOwed {
                    instrumentIncreaseValues.append(transaction.money)
                } else if let positive = try? Money(amount: -transaction.money.amount, currency: currency) {
                    instrumentDecreaseValues.append(positive)
                }
            }
        }

        let previous = evidence.summary(code: "previous_balance")?.money
        let credits = evidence.summary(code: "new_credits")?.money
        let debits = evidence.summary(code: "new_debits")?.money
        let newBalance = evidence.summary(code: "new_balance")?.money
        let dueDate = evidence.summary(code: "due_date")?.date
        let instrumentTotal = evidence.summary(code: "instrument_net_total")?.money
        let summaryMoney = [previous, credits, debits, newBalance, instrumentTotal]
        if dueDate == nil || summaryMoney.contains(where: { $0 == nil }) ||
            summaryMoney.compactMap({ $0 }).contains(where: { $0.currency != currency }) ||
            evidence.reconciliationRuleIdentifier != CardStatementEvidence.amexQARReconciliationRule {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Amex summary components are incomplete or contradictory."))
        }

        let increaseTotal = try? moneySum(increaseValues, currency: currency)
        let decreaseTotal = try? moneySum(decreaseValues, currency: currency)
        let instrumentIncreaseTotal = try? moneySum(instrumentIncreaseValues, currency: currency)
        let instrumentDecreaseTotal = try? moneySum(instrumentDecreaseValues, currency: currency)
        if let previous, let credits, let debits, let newBalance,
           let expected = try? (try previous - credits) + debits,
           expected != newBalance {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Amex statement summary does not reconcile."))
        }
        if let debits, increaseTotal != debits {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Card increases do not equal printed New Debits."))
        }
        if let credits, decreaseTotal != credits {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Card decreases do not equal printed New Credits."))
        }
        if let instrumentTotal,
           let instrumentIncreaseTotal,
           let instrumentDecreaseTotal,
           let calculated = try? instrumentIncreaseTotal - instrumentDecreaseTotal,
           calculated != instrumentTotal {
            issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Card instrument rows do not equal the printed instrument total."))
        }
        for section in evidence.instrumentSections {
            guard let values = sectionValues[section.documentScopedSectionID], !values.isEmpty,
                  let calculated = try? moneySum(values, currency: currency),
                  calculated == section.signedNetTotal else {
                issues.append(ValidationIssue(severity: .error, rowNumber: nil, message: "Card instrument section does not equal its printed signed total."))
                continue
            }
        }

        return ImportValidationResult(
            rowsRead: transactions.count,
            transactionsParsed: transactions.count,
            statementCurrency: currency,
            debitTotalMoney: increaseTotal,
            creditTotalMoney: decreaseTotal,
            openingBalanceMoney: previous,
            closingBalanceMoney: newBalance,
            passed: issues.isEmpty,
            issues: issues
        )
    }

    static func validate(transactions: [Transaction]) -> ImportValidationResult {
        let currencies = Set(transactions.map(\.money.currency))
        return validate(
            transactions: transactions,
            statementCurrency: currencies.count == 1 ? currencies.first : nil,
            reconcileSourceOrderBalances: true
        )
    }

    private static func validate(
        transactions: [Transaction],
        statementCurrency: CurrencyCode?,
        reconcileSourceOrderBalances: Bool
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
        let openingBalanceMoney: Money? = reconcileSourceOrderBalances ? {
            guard let first = firstTransaction,
                  let firstBalance = first.runningBalanceMoney else {
                return nil
            }
            var opening = firstBalance
            if let debit = first.debitMoney { opening = (try? opening + debit) ?? opening }
            if let credit = first.creditMoney { opening = (try? opening - credit) ?? opening }
            return opening
        }() : nil

        let closingBalanceMoney = reconcileSourceOrderBalances
            ? transactions.last?.runningBalanceMoney
            : nil

        if reconcileSourceOrderBalances, transactions.count > 1 {
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
