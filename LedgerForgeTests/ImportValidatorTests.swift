import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct ImportValidatorTests {
    @Test func emptyUnprovenInputFailsValidation() {
        let validation = ImportValidator.validate(transactions: [])
        #expect(!validation.passed)
        #expect(validation.transactionsParsed == 0)
        #expect(validation.issues.contains { $0.severity == .error })
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticValidationPreservesSourceControlsAndOccurrenceAccounting() async throws {
        let preparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { preparedOwner.cancel() }
        let prepared = preparedOwner.preparedImport
        let document = prepared.financialDocument
        let documentValidation = ImportValidator.validate(financialDocument: document)
        let transactionValidation = ImportValidator.validate(transactions: document.transactions)
        #expect(documentValidation.passed)
        #expect(documentValidation.transactionsParsed == document.transactions.count)
        #expect(documentValidation.passed == transactionValidation.passed)
        #expect(documentValidation.debitTotalMoney == transactionValidation.debitTotalMoney)
        #expect(documentValidation.creditTotalMoney == transactionValidation.creditTotalMoney)
        let source = try #require(document.sourceStatementEvidence)
        #expect(documentValidation.openingBalanceMoney == source.openingBalance)
        #expect(documentValidation.closingBalanceMoney == source.closingBalance)
        // This authentic CSV has row-associated balances and no printed
        // opening/closing controls. Do not derive substitutes from row order.
        #expect(source.openingBalance == nil)
        #expect(source.closingBalance == nil)
        #expect(transactionValidation.openingBalanceMoney == nil)
        #expect(transactionValidation.closingBalanceMoney == nil)
        let ordinals = document.transactions.flatMap(\.sourceProvenance).map(\.sourceOrdinal)
        #expect(ordinals.count == document.transactions.count)
        #expect(Set(ordinals).count == ordinals.count)
        #expect(documentValidation.rowsRead == document.transactions.count)
    }

    @Test(.globalRuntimeStateIsolation)
    func validationDoesNotMutateAuthenticFinancialEvidence() async throws {
        let preparedOwner = try await AuthenticSourceTestSupport.preparedAxisBankCSV()
        defer { preparedOwner.cancel() }
        let prepared = preparedOwner.preparedImport
        let document = prepared.financialDocument
        let ids = document.transactions.map(\.id)
        let money = document.transactions.map(\.money)
        let balances = document.transactions.map(\.runningBalanceMoney)
        let dates = document.transactions.map(\.statementDate)
        let references = document.transactions.map(\.reference)
        let descriptions = document.transactions.map(\.description)
        let identifiers = document.financialIdentifiers
        let sourceEvidence = document.sourceStatementEvidence
        let provenance = document.transactions.map(\.sourceProvenance)
        let debit = document.transactions.map(\.debitMoney)
        let credit = document.transactions.map(\.creditMoney)
        let profile = document.parserName
        let created = document.createdAt
        let reasons = document.selectionReasons
        #expect(ImportValidator.validate(financialDocument: document).passed)
        #expect(document.transactions.map(\.id) == ids)
        #expect(document.transactions.map(\.money) == money)
        #expect(document.transactions.map(\.runningBalanceMoney) == balances)
        #expect(document.transactions.map(\.statementDate) == dates)
        #expect(document.transactions.map(\.reference) == references)
        #expect(document.transactions.map(\.description) == descriptions)
        #expect(document.financialIdentifiers == identifiers)
        #expect(document.sourceStatementEvidence == sourceEvidence)
        #expect(document.transactions.map(\.sourceProvenance) == provenance)
        #expect(document.transactions.map(\.debitMoney) == debit)
        #expect(document.transactions.map(\.creditMoney) == credit)
        #expect(document.parserName == profile)
        #expect(document.createdAt == created)
        #expect(document.selectionReasons == reasons)
    }
}
