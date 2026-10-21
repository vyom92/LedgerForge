import Foundation
import XCTest
@testable import LedgerForge

/// Small owner-entered planning mechanics, without statements, transactions,
/// holdings, or claims about an actual account's balance or product.
@MainActor
final class SurplusAllocationTests: XCTestCase {
    private let workspace = "allocation-mechanics"
    private let timestamp = "2026-10-20T04:00:00Z"

    private func money(_ amount: String, _ currency: String = "QAR") throws -> Money {
        try Money(amount: XCTUnwrap(Decimal(string: amount, locale: Locale(identifier: "en_US_POSIX"))), currency: currency)
    }

    private func amount(_ value: String, _ currency: String = "QAR") throws -> PlanningAmount {
        try PlanningAmount(money(value, currency))
    }

    private func account(_ id: String, _ currency: String, institution: String? = nil) -> AccountDTO {
        .init(id: id, workspaceId: workspace, name: "Manual planning account \(id)", institutionId: institution,
              accountType: "bank", nativeCurrency: currency, createdAtISO: timestamp)
    }

    private var accounts: [AccountDTO] {
        [account("qatar", "QAR"), account("india-nre", "INR", institution: "Axis Bank"),
         account("india-nro", "INR", institution: "HDFC Bank")]
    }

    private var labels: [String: [String]] {
        ["india-nre": ["NRE"], "india-nro": ["NRO"]]
    }

    private var preferences: IntelligencePreferences {
        .init(workspaceID: workspace, retentionAccountID: "qatar")
    }

    private func plan() throws -> FundingPlan {
        let zero = try money("0")
        return try FundingPlan(id: "manual-plan", workspaceID: workspace, month: SelectedStatementMonth(canonical: "2026-10"),
            expectedFixedEarnings: money("1000"), expectedFixedProvenance: .manual,
            expectedVariableEarnings: zero, expectedVariableProvenance: .manual,
            expectedDeductions: zero, expectedDeductionsProvenance: .manual,
            balances: [.init(id: "qatar-balance", accountID: "qatar", nativeCurrency: CurrencyCode("QAR"), included: true,
                             money: money("100"), provenance: .manual)],
            qatarCommitments: [.init(id: "qatar-bill", label: "Owner estimate", money: money("200"), included: true,
                                    fundingAccountID: "qatar", provenance: .manual)],
            indiaCommitments: [.init(id: "india-bill", label: "Owner estimate", money: money("600", "INR"), included: true,
                                    fundingAccountID: "india-nre", provenance: .manual)],
            configuredTransferFee: money("10"), configuredTransferFeeProvenance: .manual,
            planningFX: FundingPlanFX(inrPerQAR: 3, observationDate: StatementDate(canonical: "2026-10-18")),
            plannedInvestment: zero, plannedInvestmentProvenance: .manual, updatedAtISO: timestamp,
            calculationVersion: .budgetV1, keepInCBQ: money("100"), referenceMode: .manual,
            assistance: .init(workspaceID: workspace, month: "2026-10", surplusAllocation: .init(id: "allocation-october")))
    }

    private func reserve(_ id: String = "cash-reserve", accountID: String? = "qatar", kind: ReserveDesignation.Kind = .accountCash,
                         currency: String = "QAR") throws -> ReserveDesignation {
        .init(id: id, workspaceID: workspace, accountID: accountID, title: "Owner reserve", kind: kind,
              target: try amount("1000", currency))
    }

    private func investment(_ id: String = "investment", value: String, currency: String = "QAR", accountID: String = "qatar",
                            transferID: String? = nil, instrument: PlannedInvestmentInstrument? = nil) throws -> PlanInvestmentIntention {
        .init(id: id, instrument: instrument ?? .ibkr(conid: "12345", title: "Selected instrument", quoteCurrency: "USD"),
              fundingAccountID: accountID, amount: try amount(value, currency), date: "2026-10-20", fundingTransferID: transferID)
    }

    private func transfer(_ id: String, from: String = "qatar", to: String = "india-nre", sent: String,
                          sentCurrency: String = "QAR", received: String, receivedCurrency: String = "INR",
                          parent: String? = nil, date: String = "2026-10-18") throws -> PlanTransfer {
        .init(id: id, fromAccountID: from, toAccountID: to, sent: try amount(sent, sentCurrency),
              received: try amount(received, receivedCurrency), date: date, conversionBasis: "Owner-entered planning rate",
              fundingTransferID: parent)
    }

    private func calculate(_ value: FundingPlan, reserves: [ReserveDesignation] = [],
                           productLabels: [String: [String]]? = nil) throws -> SurplusAllocationCalculation {
        try SurplusAllocationCalculator.calculate(plan: value, reserves: reserves, accounts: accounts,
                                                   productLabels: productLabels ?? labels, preferences: preferences)
    }

    private func assertError(_ expected: SurplusAllocationError, file: StaticString = #filePath, line: UInt = #line,
                             _ body: () throws -> Void) {
        XCTAssertThrowsError(try body(), file: file, line: line) {
            XCTAssertEqual($0 as? SurplusAllocationError, expected, file: file, line: line)
        }
    }

    func testAllocationsUseSurplusWithoutChangingSalaryBillsOrMonthlyCalculation() throws {
        var value = try plan()
        let before = value
        value.assistance?.surplusAllocation?.investments = [try investment(value: "200")]
        let calculation = try calculate(value)
        XCTAssertEqual(calculation.monthlySurplus, try money("690"))
        XCTAssertEqual(calculation.retainedInCBQ, try money("100"))
        XCTAssertEqual(calculation.remainingByFundingSource["cash:QAR"], try money("390"))
        XCTAssertEqual(FundingPlanCalculator.calculate(value), FundingPlanCalculator.calculate(before))
        XCTAssertEqual(value.expectedFixedEarnings, before.expectedFixedEarnings)
        XCTAssertEqual(value.qatarCommitments, before.qatarCommitments)
        XCTAssertEqual(value.indiaCommitments, before.indiaCommitments)
        XCTAssertEqual(value.balances, before.balances)
    }

    func testKeepInCBQOverlapRequiresExactReserveIdentityAndCountsOnce() throws {
        var value = try plan()
        let destination = try reserve()
        value.assistance?.contributions = [.init(designationID: destination.id, fundingAccountID: "qatar",
                                                amount: try amount("180"), dueDate: "2026-10-20")]
        XCTAssertEqual(try calculate(value, reserves: [destination]).remainingByFundingSource["cash:QAR"], try money("410"))
        value.assistance?.surplusAllocation?.keepInCBQDesignationID = destination.id
        XCTAssertEqual(try calculate(value, reserves: [destination]).remainingByFundingSource["cash:QAR"], try money("510"))
        XCTAssertEqual(value.keepInCBQ, try money("100"))
        value.assistance?.contributions[0].amount = try amount("80")
        XCTAssertEqual(try calculate(value, reserves: [destination]).remainingByFundingSource["cash:QAR"], try money("590"))
        XCTAssertEqual(value.keepInCBQ, try money("100"), "A smaller overlapping earmark cannot release the saved retention.")
        value.assistance?.surplusAllocation?.keepInCBQDesignationID = "deleted-reserve"
        assertError(.invalidFundingLink) { _ = try calculate(value, reserves: [destination]) }
    }

    func testRequiredIndiaRemittanceAndLinkedIntentionsConsumeOnePrincipalAndOneFee() throws {
        var value = try plan()
        let destination = try reserve("india-cash", accountID: "india-nre", currency: "INR")
        value.assistance?.transfers = [try transfer("remittance", sent: "300", received: "900")]
        value.assistance?.surplusAllocation?.requiredIndiaTransferID = "remittance"
        value.assistance?.contributions = [.init(designationID: destination.id, fundingAccountID: "india-nre",
            amount: try amount("200", "INR"), dueDate: "2026-10-20", fundingTransferID: "remittance")]
        value.assistance?.surplusAllocation?.investments = [try investment(value: "100", currency: "INR", accountID: "india-nre",
            transferID: "remittance", instrument: .indianMutualFund(schemeCode: "456789", title: "Selected scheme"))]
        let calculation = try calculate(value, reserves: [destination])
        XCTAssertEqual(calculation.monthlySurplus, try money("690"))
        XCTAssertEqual(calculation.remainingByFundingSource["cash:QAR"], try money("490"))
        XCTAssertEqual(calculation.remainingByFundingSource["transfer:remittance"], try money("0", "INR"))
        XCTAssertEqual(FundingPlanCalculator.calculate(value).effectiveTransferFee, try money("10"))
        XCTAssertEqual(value.balances.first?.money, try money("100"), "A plan does not post the transfer into account balances.")
    }

    func testTransferChainAndSameAccountEarmarkKeepEachReceiptAvailableOnlyOnce() throws {
        var value = try plan()
        value.expectedFixedEarnings = try money("1000"); value.balances = []
        value.qatarCommitments = []; value.indiaCommitments = []; value.keepInCBQ = try money("0")
        value.assistance?.transfers = [try transfer("native-hop", from: "india-nre", to: "india-nro", sent: "600",
            sentCurrency: "INR", received: "600", parent: "remittance", date: "2026-10-19"),
            try transfer("remittance", sent: "400", received: "1200")]
        let destination = try reserve("nre-cash", accountID: "india-nre", currency: "INR")
        value.assistance?.contributions = [.init(designationID: destination.id, fundingAccountID: "india-nre",
            amount: try amount("200", "INR"), dueDate: "2026-10-20", fundingTransferID: "remittance")]
        value.assistance?.surplusAllocation?.investments = [try investment(value: "600", currency: "INR", accountID: "india-nro",
            transferID: "native-hop", instrument: .indianMutualFund(schemeCode: "456789", title: "Selected scheme"))]
        let calculation = try calculate(value, reserves: [destination])
        XCTAssertEqual(calculation.monthlySurplus, try money("1000"))
        XCTAssertEqual(calculation.remainingByFundingSource["cash:QAR"], try money("590"))
        XCTAssertEqual(calculation.remainingByFundingSource["transfer:remittance"], try money("400", "INR"))
        XCTAssertEqual(calculation.remainingByFundingSource["transfer:native-hop"], try money("0", "INR"))
        XCTAssertEqual(calculation.unallocated, [try money("400", "INR"), try money("590")])
    }

    func testRequiredIndiaFundingCanReachNROWithoutBecomingInvestableCash() throws {
        var value = try plan()
        value.indiaCommitments[0].fundingAccountID = "india-nro"
        var hop = try transfer("india-bills", from: "india-nre", to: "india-nro", sent: "600", sentCurrency: "INR",
                               received: "600", parent: "remittance", date: "2026-10-19")
        hop.requiredIndiaFunding = try amount("600", "INR")
        value.assistance?.transfers = [hop, try transfer("remittance", sent: "200", received: "600")]
        value.assistance?.surplusAllocation?.requiredIndiaTransferID = "remittance"
        let calculation = try calculate(value)
        XCTAssertEqual(calculation.monthlySurplus, try money("690"))
        XCTAssertEqual(calculation.remainingByFundingSource["cash:QAR"], try money("590"))
        XCTAssertEqual(calculation.remainingByFundingSource["transfer:remittance"], try money("0", "INR"))
        XCTAssertEqual(calculation.remainingByFundingSource["transfer:india-bills"], try money("0", "INR"))
        XCTAssertEqual(calculation.requiredIndiaFundingByTransfer["remittance"], try money("0", "INR"))
        XCTAssertEqual(calculation.requiredIndiaFundingByTransfer["india-bills"], try money("600", "INR"))
        value.assistance?.surplusAllocation?.investments = [try investment(value: "0.01", currency: "INR", accountID: "india-nro",
            transferID: "india-bills", instrument: .indianMutualFund(schemeCode: "456789", title: "Selected scheme"))]
        assertError(.exceedsCapacity) { _ = try calculate(value) }
    }

    func testExistingIndiaCashReservedForNROBillRoutesWithoutCreatingSurplus() throws {
        var value = try plan()
        value.indiaCommitments[0].money = try money("100", "INR")
        value.indiaCommitments[0].fundingAccountID = "india-nro"
        value.balances.append(.init(id: "inr-balance", accountID: "india-nre", nativeCurrency: try CurrencyCode("INR"),
                                    included: true, money: try money("100", "INR"), provenance: .manual))
        var movement = try transfer("india-bills", from: "india-nre", to: "india-nro", sent: "100", sentCurrency: "INR", received: "100")
        movement.requiredIndiaFunding = try amount("100", "INR")
        value.assistance?.transfers = [movement]
        let calculation = try calculate(value)
        XCTAssertEqual(calculation.monthlySurplus, try money("900"))
        XCTAssertEqual(calculation.remainingByFundingSource["cash:QAR"], try money("800"))
        XCTAssertEqual(calculation.remainingByFundingSource["cash:INR"], try money("0", "INR"))
        XCTAssertEqual(calculation.remainingByFundingSource["transfer:india-bills"], try money("0", "INR"))
        XCTAssertEqual(calculation.requiredIndiaFundingByTransfer["india-bills"], try money("100", "INR"))
        value.assistance?.surplusAllocation?.investments = [try investment(value: "0.01", currency: "INR", accountID: "india-nro",
            transferID: "india-bills", instrument: .indianMutualFund(schemeCode: "456789", title: "Selected scheme"))]
        assertError(.exceedsCapacity) { _ = try calculate(value) }
    }

    func testOtherQatarBankCashRemainsUnallocatedAndCannotFundCBQIntention() throws {
        var value = try plan()
        value.balances.append(.init(id: "other-bank-balance", accountID: "other-qatar", nativeCurrency: try CurrencyCode("QAR"),
                                    included: true, money: try money("1000"), provenance: .manual))
        value.assistance?.surplusAllocation?.investments = [try investment(value: "590")]
        let result = try SurplusAllocationCalculator.calculate(plan: value, reserves: [],
            accounts: accounts + [account("other-qatar", "QAR")], productLabels: labels, preferences: preferences)
        XCTAssertEqual(result.monthlySurplus, try money("1690"))
        XCTAssertEqual(result.remainingByFundingSource["cash:QAR"], try money("1000"))
        value.assistance?.surplusAllocation?.investments[0].amount = try amount("590.01")
        assertError(.exceedsCapacity) {
            _ = try SurplusAllocationCalculator.calculate(plan: value, reserves: [],
                accounts: accounts + [account("other-qatar", "QAR")], productLabels: labels, preferences: preferences)
        }
    }

    func testPlanningDepositAndInvestmentCompeteForOneNativeCashCapacity() throws {
        var value = try plan()
        value.balances.append(.init(id: "inr-balance", accountID: "india-nre", nativeCurrency: try CurrencyCode("INR"),
                                    included: true, money: try money("900", "INR"), provenance: .manual))
        let destination = try reserve("deposit", accountID: nil, kind: .planningDeposit, currency: "INR")
        value.assistance?.contributions = [.init(designationID: destination.id, fundingAccountID: "india-nre",
                                                amount: try amount("200", "INR"), dueDate: "2026-10-20")]
        value.assistance?.surplusAllocation?.investments = [try investment(value: "100", currency: "INR", accountID: "india-nre",
            instrument: .indianMutualFund(schemeCode: "456789", title: "Selected scheme"))]
        let calculation = try calculate(value, reserves: [destination])
        XCTAssertEqual(calculation.monthlySurplus, try money("900"))
        XCTAssertEqual(calculation.remainingByFundingSource["cash:QAR"], try money("800"))
        XCTAssertEqual(calculation.remainingByFundingSource["cash:INR"], try money("0", "INR"))
        XCTAssertNil(destination.planningBalance, "A proposed deposit does not become funded evidence.")
        value.assistance?.surplusAllocation?.investments[0].amount = try amount("100.01", "INR")
        assertError(.exceedsCapacity) { _ = try calculate(value, reserves: [destination]) }
    }

    func testUnknownNativeCashAndIncompleteIncludedBalancesFailClosed() throws {
        var value = try plan()
        value.assistance?.surplusAllocation?.investments = [try investment(value: "1", currency: "INR", accountID: "india-nre",
            instrument: .indianMutualFund(schemeCode: "456789", title: "Selected scheme"))]
        assertError(.incompletePlan) { _ = try calculate(value) }
        value.assistance?.surplusAllocation?.investments = []
        value.balances[0].money = nil
        assertError(.incompletePlan) { _ = try calculate(value) }
        value = try plan()
        value.balances.append(.init(id: "duplicate-account-balance", accountID: "qatar", nativeCurrency: try CurrencyCode("QAR"),
                                    included: true, money: try money("100"), provenance: .manual))
        assertError(.invalidRecord) { _ = try calculate(value) }
    }

    func testInsufficientSurplusAndExpectedIncomeDoNotManufactureFunding() throws {
        var value = try plan()
        value.assistance?.datedAdjustments = [.init(id: "hopeful-income", accountID: "qatar", kind: .expectedIncome,
            title: "Separate possible income", amount: try amount("500"), date: "2026-10-20")]
        value.assistance?.surplusAllocation?.investments = [try investment(value: "590.01")]
        assertError(.exceedsCapacity) { _ = try calculate(value) }
        XCTAssertEqual(FundingPlanCalculator.calculate(value).surplusAfterObligations, try money("690"))
        value.assistance?.surplusAllocation?.investments = []
        value.expectedFixedEarnings = try money("0")
        let calculation = try calculate(value)
        XCTAssertEqual(calculation.monthlySurplus, try money("-310"))
        XCTAssertEqual(calculation.remainingByFundingSource["cash:QAR"], try money("-410"))
        value.assistance?.surplusAllocation?.investments = [try investment(value: "0.01")]
        assertError(.exceedsCapacity) { _ = try calculate(value) }
    }

    func testNativeMinorUnitRoundingAndTransferFeeAreChargedOnce() throws {
        var value = try plan()
        value.balances = []; value.expectedFixedEarnings = try money("100")
        value.qatarCommitments = []; value.indiaCommitments = []; value.keepInCBQ = try money("0")
        value.configuredTransferFee = try money("0.03")
        value.assistance?.transfers = [try transfer("small-remittance", sent: "0.34", received: "1")]
        value.assistance?.surplusAllocation?.investments = [try investment(value: "1", currency: "INR", accountID: "india-nre",
            transferID: "small-remittance", instrument: .indianMutualFund(schemeCode: "456789", title: "Selected scheme"))]
        let calculation = try calculate(value)
        XCTAssertEqual(calculation.monthlySurplus, try money("100"))
        XCTAssertEqual(calculation.remainingByFundingSource["cash:QAR"], try money("99.63"))
        XCTAssertEqual(calculation.remainingByFundingSource["transfer:small-remittance"], try money("0", "INR"))
        value.assistance?.transfers?[0].sent = try amount("0.33")
        assertError(.invalidFundingLink) { _ = try calculate(value) }
    }

    func testZeroOptionalTransferDoesNotChargeAnUnusedFee() throws {
        var value = try plan()
        value.balances = []; value.expectedFixedEarnings = try money("100")
        value.qatarCommitments = []; value.indiaCommitments = []; value.keepInCBQ = try money("0")
        value.assistance?.transfers = [try transfer("zero", sent: "0", received: "0")]
        let calculation = try calculate(value)
        XCTAssertEqual(calculation.monthlySurplus, try money("100"))
        XCTAssertEqual(calculation.remainingByFundingSource["cash:QAR"], try money("100"))
        XCTAssertEqual(calculation.remainingByFundingSource["transfer:zero"], try money("0", "INR"))
    }

    func testOnlyOneCrossCurrencyTransferAndExplicitSupportedRoutesAreAccepted() throws {
        var value = try plan()
        value.assistance?.transfers = [try transfer("one", sent: "300", received: "900"),
                                      try transfer("two", sent: "100", received: "300")]
        assertError(.invalidRecord) { _ = try calculate(value) }
        value.assistance?.transfers = [try transfer("one", sent: "300", received: "900")]
        value.assistance?.surplusAllocation?.requiredIndiaTransferID = "one"
        assertError(.unsupportedRoute) { _ = try calculate(value, productLabels: [:]) }
        assertError(.unsupportedRoute) { _ = try calculate(value, productLabels: ["india-nre": ["NRE", "NRO"]]) }
        value.assistance?.transfers = [try transfer("wrong-direction", from: "india-nro", to: "india-nre", sent: "1",
            sentCurrency: "INR", received: "1")]
        value.assistance?.surplusAllocation?.requiredIndiaTransferID = nil
        assertError(.unsupportedRoute) { _ = try calculate(value) }
    }

    func testMissingCyclicAndFutureFundingReferencesAreRejected() throws {
        var value = try plan()
        value.assistance?.surplusAllocation?.requiredIndiaTransferID = "removed-transfer"
        assertError(.invalidFundingLink) { _ = try calculate(value) }
        value.assistance?.surplusAllocation?.requiredIndiaTransferID = nil
        value.assistance?.transfers = [try transfer("a", from: "india-nre", to: "india-nro", sent: "1", sentCurrency: "INR", received: "1", parent: "b"),
                                      try transfer("b", from: "india-nro", to: "india-nre", sent: "1", sentCurrency: "INR", received: "1", parent: "a")]
        assertError(.invalidFundingLink) { _ = try calculate(value) }
        value.assistance?.transfers = [try transfer("one", sent: "300", received: "900", date: "2026-10-21")]
        value.assistance?.surplusAllocation?.requiredIndiaTransferID = "one"
        value.assistance?.surplusAllocation?.investments = [try investment(value: "1", currency: "INR", accountID: "india-nre",
            transferID: "one", instrument: .indianMutualFund(schemeCode: "456789", title: "Selected scheme"))]
        assertError(.invalidFundingLink) { _ = try calculate(value) }
    }

    func testObservedOrAlreadyAnchoredTransferCannotReplayItsReceipt() throws {
        var value = try plan()
        value.assistance?.transfers = [try transfer("one", sent: "300", received: "900")]
        value.assistance?.surplusAllocation?.requiredIndiaTransferID = "one"
        value.assistance?.transfers?[0].transactionIDs = ["unreconciled-record-reference"]
        assertError(.incompletePlan) { _ = try calculate(value) }
        value.assistance?.transfers?[0].transactionIDs = nil
        value.balances[0].financialBalanceDate = try StatementDate(canonical: "2026-10-18")
        assertError(.incompletePlan) { _ = try calculate(value) }
        value.balances[0].financialBalanceDate = try StatementDate(canonical: "2026-10-19")
        assertError(.incompletePlan) { _ = try calculate(value) }
        value.balances[0].financialBalanceDate = nil
        value.balances.append(.init(id: "inr-balance", accountID: "india-nre", nativeCurrency: try CurrencyCode("INR"),
                                    included: true, money: try money("0", "INR"), provenance: .manual,
                                    financialBalanceDate: try StatementDate(canonical: "2026-10-18")))
        assertError(.incompletePlan) { _ = try calculate(value) }
    }

    func testExcludedOrHistoryOnlyIncludedCashRequiresExplicitReview() throws {
        let value = try plan()
        var excluded = preferences
        excluded.excludedPlanningAccountIDs = ["qatar"]
        assertError(.incompletePlan) {
            _ = try SurplusAllocationCalculator.calculate(plan: value, reserves: [], accounts: accounts,
                productLabels: labels, preferences: excluded)
        }
        let historyAccount = AccountDTO(id: "qatar", workspaceId: workspace, name: "Owner history-only account", accountType: "bank",
            nativeCurrency: "QAR", createdAtISO: timestamp, closedAtISO: "2026-10-19T04:00:00Z")
        assertError(.incompletePlan) {
            _ = try SurplusAllocationCalculator.calculate(plan: value, reserves: [],
                accounts: [historyAccount] + accounts.filter { $0.id != "qatar" }, productLabels: labels, preferences: preferences)
        }
        XCTAssertEqual(value.balances.first?.included, true, "Unavailable saved cash remains an explicit owner input to review.")
        XCTAssertEqual(value.balances.first?.money, try money("100"))
    }

    func testDTOCalculationInputPreservesINRCarryBasisAndBalanceProvenanceExactly() throws {
        var value = try plan()
        value.rolloverSourcePlanID = "previous-owner-plan"
        value.expectedVariableProvenance = .carried(sourcePlanID: "previous-owner-plan")
        value.balances[0].provenance = .capturedAccountBalance(capturedAtISO: timestamp)
        value.balances[0].financialBalanceDate = try StatementDate(canonical: "2026-10-26")
        value.indiaCommitments[0].provenance = .carried(sourcePlanID: "previous-owner-plan")
        value.indiaCommitments[0].temporaryCarryBasis = try money("1200", "INR")
        value.indiaCommitments[0].carriedSourceRowID = "previous-india-bill"
        value.indiaCommitments[0].remark = "Owner entered remaining payment"
        value.indiaCommitments[0].dueDate = try StatementDate(canonical: "2026-10-27")
        value.deductions = [.init(id: "manual-deduction", label: "Owner deduction", money: try money("5"), recurs: false,
                                  carriedSourceRowID: "previous-deduction")]
        let recovered = try value.persistenceDTO().allocationCalculationInput()
        XCTAssertEqual(recovered, value)
        XCTAssertEqual(recovered.indiaCommitments.first?.temporaryCarryBasis, try money("1200", "INR"))
        XCTAssertEqual(recovered.indiaCommitments.first?.money, try money("600", "INR"))
        XCTAssertEqual(recovered.indiaCommitments.first?.carriedSourceRowID, "previous-india-bill")
        XCTAssertEqual(recovered.balances.first?.provenance, .capturedAccountBalance(capturedAtISO: timestamp))
        XCTAssertEqual(recovered.balances.first?.financialBalanceDate?.canonical, "2026-10-26")
        XCTAssertEqual(FundingPlanCalculator.calculate(recovered), FundingPlanCalculator.calculate(value))
    }

    func testSharedReceiptResolverKeepsAcknowledgedPendingAndMalformedEvidenceDistinct() throws {
        var value = try plan()
        value.assistance?.salaryCycle = SalaryFundingCycle.expected(month: value.month, day: 25)
        value.balances[0].provenance = .capturedAccountBalance(capturedAtISO: timestamp)
        value.balances[0].financialBalanceDate = try StatementDate(canonical: "2026-10-26")
        // Domain links exercise receipt decisions; no source document or credit
        // is created, and the empty evidence cannot assert a recorded payment.
        value.assistance?.payslipFunding = .init(statementID: "mechanics-link", fingerprintAlgorithm: "mechanics-only",
            fingerprintDigest: "mechanics-identity", accountID: "qatar", net: try amount("1000"),
            balanceAcknowledgement: .init(balanceID: "qatar-balance", amount: try amount("100"), financialDate: "2026-10-26"))
        let recovered = try value.persistenceDTO().allocationCalculationInput()
        XCTAssertEqual(PayslipReceiptState.resolve(plan: recovered, evidence: []), .acknowledgedBalance)
        value.assistance?.payslipFunding?.balanceAcknowledgement = nil
        value.balances[0].financialBalanceDate = try StatementDate(canonical: "2026-10-24")
        XCTAssertEqual(PayslipReceiptState.resolve(plan: value, evidence: []), .pending)
        XCTAssertEqual(PayslipReceiptState.resolve(plan: value, evidence: [], excludedAccounts: ["qatar"]), .needsReview)
        let malformed = TransactionDTO(id: "mechanics-dto", workspaceId: workspace, accountId: "qatar", postedDateISO: "2026-10-25",
            description: "Mechanics DTO", nativeCurrency: "QAR", amountMinor: 100_000, amountDecimal: "1000.00", direction: "credit",
            isTrusted: true, createdAtISO: timestamp, rawRows: [])
        XCTAssertThrowsError(try PayslipReceiptState.resolve(plan: value, receiptDTOs: [malformed])) {
            XCTAssertEqual($0 as? FinancialIntelligenceError, .invalidRecord)
        }
    }

    func testExactInstrumentIdentityAndNativeFundingAreRequired() throws {
        var value = try plan()
        for instrument in [PlannedInvestmentInstrument.ibkr(conid: "", title: "Name alone", quoteCurrency: "USD"),
                           .ibkr(conid: "ticker", title: "Ticker alone", quoteCurrency: "USD"),
                           .ibkr(conid: "000", title: "Invalid conid", quoteCurrency: "USD"),
                           .ibkr(conid: "12345", title: "", quoteCurrency: "USD"),
                           .ibkr(conid: "12345", title: "Selected instrument", quoteCurrency: "usd"),
                           .indianMutualFund(schemeCode: "456789", title: "QAR cannot fund this scheme"),
                           .indianMutualFund(schemeCode: "Fund Name", title: "Name alone")] {
            value.assistance?.surplusAllocation?.investments = [try investment(value: "1", instrument: instrument)]
            assertError(.invalidInstrument) { _ = try calculate(value) }
        }
        value.assistance?.surplusAllocation?.investments = [try investment(value: "-1")]
        assertError(.invalidRecord) { _ = try calculate(value) }
    }

    func testStableIDsExactInstrumentAndRevisionSurviveCodableRoundTrip() throws {
        var value = try plan()
        value.assistance?.surplusAllocation?.investments = [try investment("stable-investment", value: "123.45")]
        let revision = try value.planningRevision()
        let recovered = try JSONDecoder().decode(FundingPlan.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(recovered, value)
        XCTAssertEqual(recovered.assistance?.surplusAllocation?.investments.first?.id, "stable-investment")
        XCTAssertEqual(recovered.assistance?.surplusAllocation?.investments.first?.instrument,
                       .ibkr(conid: "12345", title: "Selected instrument", quoteCurrency: "USD"))
        XCTAssertEqual(try recovered.planningRevision(), revision)
        value.assistance?.surplusAllocation?.investments[0].amount = try amount("123.46")
        XCTAssertNotEqual(try value.planningRevision(), revision)
    }

    func testAbsentAllocationEnvelopePreservesOldKeepAndDraftMeaning() throws {
        var value = try plan()
        value.keepInCBQ = try money("2800")
        value.assistance?.surplusAllocation = nil
        let data = try JSONEncoder().encode(value)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("surplusAllocation"))
        let recovered = try JSONDecoder().decode(FundingPlan.self, from: data)
        XCTAssertEqual(recovered, value)
        XCTAssertNil(recovered.assistance?.surplusAllocation)
        XCTAssertEqual(recovered.keepInCBQ, try money("2800"))
        XCTAssertEqual(recovered.assistance?.contributions, [])
        XCTAssertNil(recovered.assistance?.transfers)
    }

    func testBothProvidersRejectUnfundedKeepAtomicallyAcrossDirectSavePathsAndAllowZeroKeepDeficit() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-keep-publication-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let sqlite = try SQLiteRepositoryProvider(path: root.appendingPathComponent("planning.sqlite").path)
        defer { sqlite.database.close() }
        let otherAccount = account("other-qatar", "QAR")
        var approved = try plan()
        approved.indiaCommitments = []
        let approvedDTO = try approved.persistenceDTO()
        var tooMuchKeep = approved
        tooMuchKeep.keepInCBQ = try money("900.01")
        var otherBankOnly = approved
        otherBankOnly.expectedFixedEarnings = try money("0")
        otherBankOnly.balances[0].money = try money("0")
        otherBankOnly.balances.append(.init(id: "other-bank-balance", accountID: otherAccount.id,
            nativeCurrency: try CurrencyCode("QAR"), included: true, money: try money("1000"), provenance: .manual))
        otherBankOnly.qatarCommitments = []
        otherBankOnly.keepInCBQ = try money("500")
        var noRetentionSource = preferences
        noRetentionSource.retentionAccountID = nil
        let scenarios: [(label: String, plan: FundingPlan, preferences: IntelligencePreferences, error: SurplusAllocationError)] = [
            ("Keep exceeds total surplus", tooMuchKeep, preferences, .exceedsCapacity),
            ("Other QAR cash cannot fund Keep", otherBankOnly, preferences, .exceedsCapacity),
            ("Positive Keep has no saved retention source", approved, noRetentionSource, .invalidFundingLink)
        ]

        for (providerName, provider) in [("in-memory", DatabaseProvider(inMemory: true)), ("SQLite", .verifiedSQLite(sqlite))] {
            _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Manual Keep publication mechanics", createdAtISO: timestamp))
            for value in accounts + [otherAccount] { _ = try provider.accountRepo.upsertAccount(value) }
            try provider.intelligenceRepo.applyPlanning(.preferences(preferences, replacing: nil))
            _ = try provider.fundingPlanRepo.savePlan(approvedDTO)
            let retained = MonthlyPlanScratchpad(plan: approved, canonical: approved,
                rawText: ["fixed": "1000", "reserve": "100."], fieldErrors: ["reserve": "Finish entering the amount."],
                untouchedZeroFields: [], unavailableBalanceAccountIDs: [], preReductionBasis: [:], excludedRecurringOccurrenceIDs: [])
            let retainedBaseline = try provider.fundingPlanRepo.planningWriteSnapshot(
                workspaceID: workspace, month: approved.month.canonical).monthRevision
            _ = try provider.fundingPlanRepo.saveScratchpad(retained.dto(), expected: retainedBaseline)

            for scenario in scenarios {
                let current = try provider.intelligenceRepo.snapshot(workspaceID: workspace)?.preferences
                if current != scenario.preferences {
                    try provider.intelligenceRepo.applyPlanning(.preferences(scenario.preferences, replacing: current))
                }
                let originalPlans = try provider.fundingPlanRepo.plans(workspaceId: workspace)
                let originalDrafts = try provider.fundingPlanRepo.scratchpads(workspaceId: workspace)
                let originalMetadata = try provider.intelligenceRepo.snapshot(workspaceID: workspace)
                let originalAccounts = try provider.accountRepo.accounts(workspaceId: workspace)
                let proposedDTO = try scenario.plan.persistenceDTO()
                var replacement = retained
                replacement.plan = scenario.plan
                replacement.canonical = scenario.plan
                replacement.rawText = ["fixed": try scenario.plan.expectedFixedEarnings.canonicalDecimalString(),
                                       "reserve": try XCTUnwrap(scenario.plan.keepInCBQ).canonicalDecimalString()]
                replacement.fieldErrors = [:]
                let replacementDTO = try replacement.dto()
                let scenarioBaseline = try provider.fundingPlanRepo.planningWriteSnapshot(
                    workspaceID: workspace, month: approved.month.canonical).monthRevision
                for retaining in [false, true] {
                    let context = providerName + ": " + scenario.label + (retaining ? " with scratchpad" : " ordinary save")
                    let publish = { () throws -> Void in
                        if retaining {
                            _ = try provider.fundingPlanRepo.savePlan(proposedDTO, retaining: replacementDTO,
                                expected: scenarioBaseline, origin: .manual)
                        } else {
                            _ = try provider.fundingPlanRepo.savePlan(proposedDTO,
                                expected: scenarioBaseline, origin: .manual)
                        }
                    }
                    XCTAssertThrowsError(try publish(), context) { error in
                        XCTAssertEqual(error as? SurplusAllocationError, scenario.error, context)
                    }
                    XCTAssertEqual(try provider.fundingPlanRepo.plans(workspaceId: workspace), originalPlans, context)
                    XCTAssertEqual(try provider.fundingPlanRepo.scratchpads(workspaceId: workspace), originalDrafts, context)
                    XCTAssertEqual(try provider.intelligenceRepo.snapshot(workspaceID: workspace), originalMetadata, context)
                    XCTAssertEqual(try provider.accountRepo.accounts(workspaceId: workspace), originalAccounts, context)
                }
            }

            var zeroKeepDeficit = approved
            zeroKeepDeficit.expectedFixedEarnings = try money("0")
            zeroKeepDeficit.balances[0].money = try money("0")
            zeroKeepDeficit.keepInCBQ = try money("0")
            let zeroDTO = try zeroKeepDeficit.persistenceDTO()
            let signedResult = try SurplusAllocationCalculator.calculate(plan: zeroKeepDeficit, reserves: [], accounts: accounts + [otherAccount],
                preferences: noRetentionSource)
            XCTAssertEqual(signedResult.monthlySurplus, try money("-200"), providerName)
            XCTAssertEqual(signedResult.remainingRetentionCapacity, try money("-200"), providerName)
            let zeroBaseline = try provider.fundingPlanRepo.planningWriteSnapshot(
                workspaceID: workspace, month: approved.month.canonical).monthRevision
            _ = try provider.fundingPlanRepo.savePlan(zeroDTO, expected: zeroBaseline, origin: .manual)
            XCTAssertEqual(try provider.fundingPlanRepo.plans(workspaceId: workspace), [zeroDTO], providerName)
            XCTAssertEqual(try provider.fundingPlanRepo.scratchpads(workspaceId: workspace), [try retained.dto()], providerName)
            var publishedZero = retained
            publishedZero.plan = zeroKeepDeficit
            publishedZero.canonical = zeroKeepDeficit
            publishedZero.rawText = ["fixed": "0", "reserve": "0"]
            publishedZero.fieldErrors = [:]
            let publishedBaseline = try provider.fundingPlanRepo.planningWriteSnapshot(
                workspaceID: workspace, month: approved.month.canonical).monthRevision
            _ = try provider.fundingPlanRepo.savePlan(zeroDTO, retaining: publishedZero.dto(),
                expected: publishedBaseline, origin: .manual)
            XCTAssertEqual(try provider.fundingPlanRepo.plans(workspaceId: workspace), [zeroDTO], providerName)
            XCTAssertEqual(try provider.fundingPlanRepo.scratchpads(workspaceId: workspace), [try publishedZero.dto()], providerName)
            XCTAssertEqual(zeroKeepDeficit.assistance?.surplusAllocation?.id, approved.assistance?.surplusAllocation?.id)
        }
    }

    func testPairedProvidersRetainIncompleteAndOvercapacityAllocationWithoutPublishingCanonical() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-allocation-paired-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let sqlite = try SQLiteRepositoryProvider(path: root.appendingPathComponent("planning.sqlite").path)
        defer { sqlite.database.close() }
        var approved = try plan()
        approved.indiaCommitments = []
        approved.assistance?.surplusAllocation?.investments = [try investment(value: "200")]
        let approvedDTO = try approved.persistenceDTO()
        let field = "allocation.investment.investment.amount"
        let initialEditor = MonthlyPlanScratchpad(plan: approved, canonical: approved,
            rawText: ["fixed": "1000", "reserve": "100", field: "200"], fieldErrors: [:],
            untouchedZeroFields: [], unavailableBalanceAccountIDs: [], preReductionBasis: [:], excludedRecurringOccurrenceIDs: [])

        for (providerName, provider) in [("in-memory", DatabaseProvider(inMemory: true)), ("SQLite", .verifiedSQLite(sqlite))] {
            _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Manual paired allocation mechanics", createdAtISO: timestamp))
            _ = try provider.accountRepo.upsertAccount(account("qatar", "QAR"))
            try provider.intelligenceRepo.applyPlanning(.preferences(preferences, replacing: nil))
            _ = try provider.fundingPlanRepo.savePlan(approvedDTO, retaining: initialEditor.dto())
            let session = CompanionSyncSessionDTO(sessionID: UUID().uuidString, workspaceID: workspace,
                activationEpoch: try provider.fundingPlanRepo.companionActivationEpoch(), phoneID: UUID().uuidString,
                protocolVersion: 1, disposition: "active")
            try provider.fundingPlanRepo.createCompanionSession(session)
            let scope = session.scope(month: approved.month.canonical)
            var currentAnchor = try allocationCompanionAnchor(initialEditor, scope: scope)
            var binding = try currentAnchor.binding(for: scope)
            let initialMonthRevision = try provider.fundingPlanRepo.planningWriteSnapshot(
                workspaceID: workspace, month: approved.month.canonical).monthRevision
            var committed = try provider.fundingPlanRepo.commitCompanionMonth(.init(sessionID: session.sessionID,
                workspaceID: workspace, month: approved.month.canonical, expectedActivationEpoch: session.activationEpoch,
                expectedStateRevision: nil, expectedMonthRevision: initialMonthRevision,
                expectedScratchpad: initialEditor.dto(), editor: initialEditor.dto(), canonical: nil,
                binding: binding, metadata: currentAnchor.metadata,
                operation: .initialize(binding.baselineDocument), currentAnchor: currentAnchor))
            XCTAssertEqual(committed.disposition, .initialized, providerName)

            for (raw, value, incomplete) in [("200.", "200", true), ("1000", "1000", false)] {
                var retained = initialEditor
                retained.plan.assistance?.surplusAllocation?.investments[0].amount = try amount(value)
                retained.rawText[field] = raw
                if incomplete { retained.fieldErrors[field] = "Finish entering the amount." }
                let nextAnchor = try allocationCompanionAnchor(retained, scope: scope, previous: currentAnchor)
                let nextBinding = try nextAnchor.binding(for: scope)
                let previousRevision = committed.stored.stateRevision
                let previousMonthRevision = try XCTUnwrap(committed.monthRevision)
                committed = try provider.fundingPlanRepo.commitCompanionMonth(.init(sessionID: session.sessionID,
                    workspaceID: workspace, month: approved.month.canonical, expectedActivationEpoch: session.activationEpoch,
                    expectedStateRevision: previousRevision, expectedMonthRevision: previousMonthRevision,
                    expectedScratchpad: currentAnchor.scratchpad.dto(),
                    editor: retained.dto(), canonical: nil, binding: binding, metadata: nextAnchor.metadata,
                    operation: .localEdit(nextBinding.baselineDocument), currentAnchor: nextAnchor))
                XCTAssertEqual(committed.disposition, .localEdit, providerName)
                XCTAssertEqual(committed.stored.stateRevision, previousRevision + 1, providerName)
                XCTAssertEqual(try provider.fundingPlanRepo.plans(workspaceId: workspace), [approvedDTO], providerName)
                XCTAssertEqual(try provider.fundingPlanRepo.scratchpads(workspaceId: workspace), [try retained.dto()], providerName)
                XCTAssertEqual(try provider.fundingPlanRepo.companionMonth(sessionID: session.sessionID,
                    workspaceID: workspace, month: approved.month.canonical), committed.stored, providerName)
                currentAnchor = nextAnchor
                binding = nextBinding
            }

            var publishing = currentAnchor.scratchpad
            publishing.canonical = publishing.plan
            let publishingAnchor = try allocationCompanionAnchor(publishing, scope: scope, previous: currentAnchor)
            let publishingBinding = try publishingAnchor.binding(for: scope)
            let previousDrafts = try provider.fundingPlanRepo.scratchpads(workspaceId: workspace)
            let previousReceipt = committed.stored
            let previousMonthRevision = try XCTUnwrap(committed.monthRevision)
            assertError(.exceedsCapacity) {
                _ = try provider.fundingPlanRepo.commitCompanionMonth(.init(sessionID: session.sessionID,
                    workspaceID: workspace, month: approved.month.canonical, expectedActivationEpoch: session.activationEpoch,
                    expectedStateRevision: previousReceipt.stateRevision, expectedMonthRevision: previousMonthRevision,
                    expectedScratchpad: currentAnchor.scratchpad.dto(),
                    editor: publishing.dto(), canonical: publishing.plan.persistenceDTO(), binding: binding,
                    metadata: publishingAnchor.metadata, operation: .localEdit(publishingBinding.baselineDocument),
                    currentAnchor: publishingAnchor))
            }
            XCTAssertEqual(try provider.fundingPlanRepo.plans(workspaceId: workspace), [approvedDTO], providerName)
            XCTAssertEqual(try provider.fundingPlanRepo.scratchpads(workspaceId: workspace), previousDrafts, providerName)
            XCTAssertEqual(try provider.fundingPlanRepo.companionMonth(sessionID: session.sessionID,
                workspaceID: workspace, month: approved.month.canonical), previousReceipt, providerName)
        }
    }

    private func allocationCompanionAnchor(_ scratchpad: MonthlyPlanScratchpad, scope: CompanionMerge.SyncScope,
                                           previous: CompanionMonthAnchor? = nil) throws -> CompanionMonthAnchor {
        let metadata = MonthlyPlanSyncAdapter.metadata(for: scratchpad,
            lexicalContext: .init(defaultLocaleIdentifier: "en_US_POSIX", localeIdentifiersByField: [:]),
            retaining: previous?.metadata ?? .init(), previousScratchpad: previous?.scratchpad)
        let draft = try CompanionMacMonthContext.make(scratchpad: scratchpad, metadata: metadata,
            accounts: [.init(repositoryAccountId: "qatar", workspaceId: workspace, name: "Manual planning account qatar",
                type: .bank, nativeCurrency: CurrencyCode("QAR"), status: .active,
                preferredDisplayName: "Owner planning bank", selectionContext: "Manual planning mechanics")],
            manuallyExcludedPlanningAccountIDs: [], receiptTransactions: [], latestAlDarQuote: nil, selectedHistoryAccountIDs: [])
        return try .init(scratchpad: scratchpad, metadata: draft.binding(for: scope).baselineMetadata,
            bankCurrencies: draft.bankCurrencies, fundingAccountIDs: draft.fundingAccountIDs,
            excludedHistoryAccountIDs: draft.excludedHistoryAccountIDs, context: draft.context)
    }

    func testProvidersSaveAtomicallyRetainIncompleteDraftAndReopenExactAllocation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-allocation-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("planning.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: path)
        defer { sqlite.database.close() }
        let destination = try reserve()
        var value = try plan()
        value.indiaCommitments = []
        value.assistance?.surplusAllocation?.investments = [try investment(value: "200")]
        value.assistance?.contributions = [.init(designationID: destination.id, fundingAccountID: "qatar",
                                                amount: try amount("150"), dueDate: "2026-10-20")]
        value.assistance?.surplusAllocation?.keepInCBQDesignationID = destination.id
        let saved = try value.persistenceDTO()
        var expectedDraft: MonthlyPlanScratchpad?
        for provider in [DatabaseProvider(inMemory: true), .verifiedSQLite(sqlite)] {
            _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Manual planning mechanics", createdAtISO: timestamp))
            _ = try provider.accountRepo.upsertAccount(account("qatar", "QAR"))
            try provider.intelligenceRepo.applyPlanning(.preferences(preferences, replacing: nil))
            try provider.intelligenceRepo.applyPlanning(.reserve(destination, replacing: nil))
            let state = MonthlyPlanScratchpad(plan: value, canonical: value, rawText: ["fixed": "1000"], fieldErrors: [:],
                untouchedZeroFields: [], unavailableBalanceAccountIDs: [], preReductionBasis: [:], excludedRecurringOccurrenceIDs: [])
            _ = try provider.fundingPlanRepo.savePlan(saved, retaining: state.dto())
            let originalPlans = try provider.fundingPlanRepo.plans(workspaceId: workspace)
            let originalDrafts = try provider.fundingPlanRepo.scratchpads(workspaceId: workspace)
            let originalAccounts = try provider.accountRepo.accounts(workspaceId: workspace)
            var invalid = value
            invalid.assistance?.surplusAllocation?.investments[0].amount = try amount("1000")
            var invalidState = state; invalidState.plan = invalid; invalidState.canonical = invalid
            XCTAssertThrowsError(try provider.fundingPlanRepo.savePlan(invalid.persistenceDTO(), retaining: invalidState.dto()))
            XCTAssertEqual(try provider.fundingPlanRepo.plans(workspaceId: workspace), originalPlans)
            XCTAssertEqual(try provider.fundingPlanRepo.scratchpads(workspaceId: workspace), originalDrafts)
            XCTAssertEqual(try provider.accountRepo.accounts(workspaceId: workspace), originalAccounts)
            XCTAssertEqual(try provider.intelligenceRepo.snapshot(workspaceID: workspace)?.reserves, [destination])
            XCTAssertTrue(try provider.transactionRepo.trustedTransactions(workspaceId: workspace).isEmpty)
            invalidState.canonical = value
            invalidState.rawText["allocation.investment"] = "1000."
            invalidState.fieldErrors["allocation.investment"] = "Finish entering the amount."
            let invalidRawBaseline = try provider.fundingPlanRepo.planningWriteSnapshot(
                workspaceID: workspace, month: value.month.canonical).monthRevision
            _ = try provider.fundingPlanRepo.saveScratchpad(invalidState.dto(), expected: invalidRawBaseline)
            XCTAssertEqual(try provider.fundingPlanRepo.plans(workspaceId: workspace), [saved])
            XCTAssertEqual(try MonthlyPlanScratchpad.decode(XCTUnwrap(provider.fundingPlanRepo.scratchpads(workspaceId: workspace).first)), invalidState)
            let hydrated = try RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
            XCTAssertEqual(hydrated.fundingPlans, [value])
            expectedDraft = invalidState
        }
        try sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        XCTAssertEqual(try reopened.fundingPlanRepo.plans(workspaceId: workspace), [saved])
        let retained = try MonthlyPlanScratchpad.decode(XCTUnwrap(reopened.fundingPlanRepo.scratchpads(workspaceId: workspace).first))
        XCTAssertEqual(retained, expectedDraft)
        XCTAssertEqual(retained.canonical?.assistance?.surplusAllocation, value.assistance?.surplusAllocation)
        XCTAssertEqual(retained.rawText["allocation.investment"], "1000.")
        XCTAssertEqual(try reopened.accountRepo.accounts(workspaceId: workspace).count, 1)
        XCTAssertTrue(try reopened.transactionRepo.trustedTransactions(workspaceId: workspace).isEmpty)
    }
}
