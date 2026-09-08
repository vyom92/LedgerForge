import Foundation
import Testing
@testable import LedgerForge

/// Isolated domain-value checks. These do not impersonate a statement or
/// establish support for a financial source family.
@MainActor
struct CardStatementEvidenceValueTests {
    /// Contract metadata only: no statement, financial graph or source
    /// substitute is constructed to test historical/current admission.
    @Test
    func historicalCBQSummaryContractsAreHydrationOnly() throws {
        let revisions: [(CardStatementProfileContract, String, String)] = [
            (.cbqV1, "cbq.qar.v1.previous-plus-billed-minus-payment.v1",
             CardStatementEvidence.cbqV1QARReconciliationRule),
            (.cbqV2, "cbq.qar.v2.previous-minus-payment-minus-credit-plus-components.v1",
             CardStatementEvidence.cbqV2QARReconciliationRule)
        ]
        for (contract, historical, current) in revisions {
            #expect(CardStatementProfileContract(reconciliationRuleIdentifier: historical) == contract)
            #expect(CardStatementProfileContract(reconciliationRuleIdentifier: current) == contract)
            #expect(!contract.acceptsCurrentReconciliationRule(historical))
            #expect(contract.acceptsCurrentReconciliationRule(current))
            #expect(!contract.acceptsCurrentReconciliationRule(current + ".unknown"))
            #expect(contract.requiredSummaryCodes.contains("minimum_amount_due"))
            #expect(contract.hydrationRequiredSummaryCodes(
                reconciliationRuleIdentifier: historical, sourceFormatCode: "pdf"
            ) == contract.requiredSummaryCodes.subtracting(["minimum_amount_due"]))
            #expect(contract.hydrationRequiredSummaryCodes(
                reconciliationRuleIdentifier: current, sourceFormatCode: "pdf"
            ) == contract.requiredSummaryCodes)
        }
    }

    @Test
    func accountAndIBANMasksMustBeMutuallyConsistent() throws {
        let account = try CBQSourceIdentityObservation(kind: .maskedAccountNumber, rawPattern: "4700-1XXXX6-001")
        let incompatibleIBAN = try CBQSourceIdentityObservation(kind: .maskedIBAN, rawPattern: "QA62CBQA0000000047009XXXX6001")
        #expect(!CBQSourceIdentityObservation.validatePair([account, incompatibleIBAN]))
    }
}
