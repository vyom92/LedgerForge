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
    func validationPreservesSourceControlsAndOccurrenceAccounting() async throws {
        let preparedOwner = try await MechanicsTestSupport.preparedAxisBankCSV()
        defer { preparedOwner.cancel() }
        let prepared = preparedOwner.preparedImport
        let document = prepared.financialDocument
        let documentValidation = ImportValidator.validate(financialDocument: document)
        let transactionValidation = ImportValidator.validate(transactions: document.transactions)
        #expect(documentValidation.passed)
        #expect(document.transactions.count == 4)
        #expect(documentValidation.debitTotalMoney == (try Money(canonicalDecimal: "100.00", currency: "INR")))
        #expect(documentValidation.creditTotalMoney == (try Money(canonicalDecimal: "1010.00", currency: "INR")))
        #expect(documentValidation.transactionsParsed == document.transactions.count)
        #expect(documentValidation.passed == transactionValidation.passed)
        #expect(documentValidation.debitTotalMoney == transactionValidation.debitTotalMoney)
        #expect(documentValidation.creditTotalMoney == transactionValidation.creditTotalMoney)
        let source = try #require(document.sourceStatementEvidence)
        #expect(documentValidation.openingBalanceMoney == source.openingBalance)
        #expect(documentValidation.closingBalanceMoney == source.closingBalance)
        // This fixture CSV has row-associated balances and no printed
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

}
