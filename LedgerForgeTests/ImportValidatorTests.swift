// LedgerForgeTests/ImportValidatorTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct ImportValidatorTests {

    @Test func emptyImportFailsValidation() {
        let validation = ImportValidator.validate(transactions: [])

        #expect(!validation.passed)
        #expect(validation.rowsRead == 0)
        #expect(validation.transactionsParsed == 0)
        #expect(validation.debitTotal == 0)
        #expect(validation.creditTotal == 0)
        #expect(validation.openingBalance == nil)
        #expect(validation.closingBalance == nil)
        #expect(validation.issues.count == 1)
        #expect(validation.issues.first?.severity == .error)
        #expect(validation.issues.first?.message == "No transactions were imported.")
    }

    @Test func transactionWithoutDebitOrCreditFailsValidation() {
        let transaction = makeTransaction(
            description: "Missing amount",
            debit: nil,
            credit: nil,
            amount: 0,
            balance: 100
        )

        let validation = ImportValidator.validate(transactions: [transaction])

        #expect(!validation.passed)
        #expect(validation.issues.contains {
            $0.message == "Transaction 'Missing amount' has neither a debit nor a credit amount."
        })
    }

    @Test func transactionWithoutRunningBalanceFailsValidation() {
        let transaction = makeTransaction(
            description: "Missing balance",
            debit: 25,
            credit: nil,
            amount: -25,
            balance: nil
        )

        let validation = ImportValidator.validate(transactions: [transaction])

        #expect(!validation.passed)
        #expect(validation.issues.contains {
            $0.message == "Transaction 'Missing balance' is missing a running balance."
        })
    }

    @Test func runningBalanceMismatchFailsValidation() {
        let transactions = [
            makeTransaction(
                description: "Opening credit",
                debit: nil,
                credit: 100,
                amount: 100,
                balance: 1_100
            ),
            makeTransaction(
                description: "Incorrect debit balance",
                debit: 50,
                credit: nil,
                amount: -50,
                balance: 1_025
            )
        ]

        let validation = ImportValidator.validate(transactions: transactions)

        #expect(!validation.passed)
        #expect(validation.issues.contains {
            $0.rowNumber == 2 &&
            $0.message == "Balance reconciliation failed on Incorrect debit balance. Expected 1050, found 1025."
        })
    }

    @Test func validFinancialDocumentRemainsValid() {
        let transactions = [
            makeTransaction(
                description: "Opening credit",
                debit: nil,
                credit: 100,
                amount: 100,
                balance: 1_100
            ),
            makeTransaction(
                description: "Card payment",
                debit: 50,
                credit: nil,
                amount: -50,
                balance: 1_050
            )
        ]
        let financialDocument = makeFinancialDocument(transactions: transactions)

        let validation = ImportValidator.validate(financialDocument: financialDocument)

        #expect(validation.passed)
        #expect(validation.rowsRead == 2)
        #expect(validation.transactionsParsed == 2)
        #expect(validation.debitTotal == 50)
        #expect(validation.creditTotal == 100)
        #expect(validation.openingBalance == 1_000)
        #expect(validation.closingBalance == 1_050)
        #expect(validation.issues.isEmpty)
    }

    @Test func financialDocumentValidationMatchesTransactionValidation() {
        let transactions = [
            makeTransaction(
                description: "Opening credit",
                debit: nil,
                credit: 100,
                amount: 100,
                balance: 1_100
            ),
            makeTransaction(
                description: "Card payment",
                debit: 50,
                credit: nil,
                amount: -50,
                balance: 1_050
            )
        ]
        let financialDocument = makeFinancialDocument(transactions: transactions)

        let documentValidation = ImportValidator.validate(financialDocument: financialDocument)
        let transactionValidation = ImportValidator.validate(transactions: transactions)

        assertEquivalent(documentValidation, transactionValidation)
    }

    @Test func validationDoesNotMutateFinancialDocumentOrTransactions() {
        let createdAt = Date(timeIntervalSince1970: 1_804_896_000)
        let transactions = [
            makeTransaction(
                description: "Opening credit",
                debit: nil,
                credit: 100,
                amount: 100,
                balance: 1_100
            ),
            makeTransaction(
                description: "Card payment",
                debit: 50,
                credit: nil,
                amount: -50,
                balance: 1_050
            )
        ]
        let financialDocument = makeFinancialDocument(
            transactions: transactions,
            selectionReasons: ["Selected parser for validation test."],
            createdAt: createdAt
        )

        let originalTransactionIDs = financialDocument.transactions.map(\.id)
        let originalDescriptions = financialDocument.transactions.map(\.description)
        let originalBalances = financialDocument.transactions.map(\.balance)

        _ = ImportValidator.validate(financialDocument: financialDocument)

        #expect(financialDocument.parserName == "Validation Test Parser")
        #expect(financialDocument.transactions.map(\.id) == originalTransactionIDs)
        #expect(financialDocument.transactions.map(\.description) == originalDescriptions)
        #expect(financialDocument.transactions.map(\.balance) == originalBalances)
        #expect(financialDocument.selectionReasons == ["Selected parser for validation test."])
        #expect(financialDocument.createdAt == createdAt)
    }

    private func makeFinancialDocument(
        transactions: [Transaction],
        selectionReasons: [String] = [],
        createdAt: Date = Date(timeIntervalSince1970: 1_804_896_000)
    ) -> FinancialDocument {
        FinancialDocument(
            sourceDocument: Document(
                filename: "validation-test.csv",
                url: URL(fileURLWithPath: "/tmp/validation-test.csv"),
                fileType: "CSV",
                importedAt: createdAt
            ),
            metadata: DocumentMetadata(
                institution: .axis,
                documentType: .bankAccount,
                fileFormat: .csv,
                confidence: 1.0
            ),
            parserName: "Validation Test Parser",
            transactions: transactions,
            selectionReasons: selectionReasons,
            createdAt: createdAt
        )
    }

    private func makeTransaction(
        description: String,
        debit: Decimal?,
        credit: Decimal?,
        amount: Decimal,
        balance: Decimal?
    ) -> Transaction {
        Transaction(
            date: Date(timeIntervalSince1970: 1_804_896_000),
            description: description,
            debit: debit,
            credit: credit,
            amount: amount,
            balance: balance,
            currency: "INR",
            account: "Axis",
            sourceBank: "Axis Bank",
            sourceFile: "validation-test.csv"
        )
    }

    private func assertEquivalent(
        _ lhs: ImportValidationResult,
        _ rhs: ImportValidationResult
    ) {
        #expect(lhs.rowsRead == rhs.rowsRead)
        #expect(lhs.transactionsParsed == rhs.transactionsParsed)
        #expect(lhs.debitTotal == rhs.debitTotal)
        #expect(lhs.creditTotal == rhs.creditTotal)
        #expect(lhs.openingBalance == rhs.openingBalance)
        #expect(lhs.closingBalance == rhs.closingBalance)
        #expect(lhs.passed == rhs.passed)
        #expect(lhs.issues.count == rhs.issues.count)
        #expect(lhs.issues.map(\.severity) == rhs.issues.map(\.severity))
        #expect(lhs.issues.map(\.rowNumber) == rhs.issues.map(\.rowNumber))
        #expect(lhs.issues.map(\.message) == rhs.issues.map(\.message))
    }

}
