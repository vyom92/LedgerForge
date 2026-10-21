import Foundation
import XCTest
@testable import LedgerForge

/// Isolated owner-entered planning values; these are not imported source facts.
@MainActor
final class PlanningChangeApplicatorTests: XCTestCase {
    private let workspace = "planning-change-mechanics"
    private let timestamp = "2026-10-21T04:00:00Z"

    private func money(_ value: String, _ currency: String = "QAR") throws -> Money {
        try Money(canonicalDecimal: value, currency: currency)
    }
    private func requested(_ value: String, _ currency: String = "QAR") throws -> PlanningMoney {
        .init(money: try money(value, currency), decimal: value)
    }
    private func account(_ id: String, _ currency: String, institution: String? = nil) -> AccountDTO {
        .init(id: id, workspaceId: workspace, name: id, institutionId: institution,
              accountType: "bank", nativeCurrency: currency, createdAtISO: timestamp)
    }
    private var accounts: [AccountDTO] {
        [account("qatar", "QAR"), account("india-nre", "INR", institution: "Axis Bank")]
    }
    private func snapshot() -> FinancialIntelligenceSnapshot {
        var value = FinancialIntelligenceSnapshot(workspaceID: workspace)
        value.preferences = .init(workspaceID: workspace, retentionAccountID: "qatar")
        return value
    }
    private func plan(envelope: Bool = false) throws -> FundingPlan {
        let zero = try money("0.00")
        return try FundingPlan(id: "monthly-plan", workspaceID: workspace,
            month: SelectedStatementMonth(canonical: "2026-10"),
            expectedFixedEarnings: money("1000.00"), expectedFixedProvenance: .manual,
            expectedVariableEarnings: zero, expectedVariableProvenance: .manual,
            expectedDeductions: zero, expectedDeductionsProvenance: .manual,
            balances: [.init(id: "balance-qatar", accountID: "qatar", nativeCurrency: CurrencyCode("QAR"),
                included: true, money: money("100.00"),
                provenance: .capturedAccountBalance(capturedAtISO: timestamp),
                financialBalanceDate: StatementDate(canonical: "2026-10-20"))],
            qatarCommitments: [.init(id: "qatar-bill", label: "Upcoming bill", money: money("200.00"),
                included: true, fundingAccountID: "qatar", provenance: .manual)],
            indiaCommitments: [.init(id: "india-bill", label: "Upcoming bill", money: money("600.00", "INR"),
                included: true, fundingAccountID: "india-nre", provenance: .manual)],
            configuredTransferFee: money("10.00"), configuredTransferFeeProvenance: .manual,
            planningFX: FundingPlanFX(inrPerQAR: 3, observationDate: StatementDate(canonical: "2026-10-18")),
            plannedInvestment: zero, plannedInvestmentProvenance: .manual, updatedAtISO: timestamp,
            calculationVersion: .budgetV1, keepInCBQ: money("100.00"), referenceMode: .manual,
            assistance: .init(workspaceID: workspace, month: "2026-10",
                surplusAllocation: envelope ? .init(id: "allocation-october") : nil))
    }

    func testOrdinaryWorksheetPreservesAbsentEnvelopeAndBalanceProvenanceSemantics() throws {
        let original = try plan()
        let inclusion = PlanningChange.planningBalance(balanceID: "balance-qatar", accountID: "qatar",
            fields: .init(amount: .omitted, included: .value(true)))
        let unchanged = try PlanningChangeApplicator.apply([inclusion], to: original, snapshot: snapshot(), accounts: accounts)
        XCTAssertNil(unchanged.assistance?.surplusAllocation)
        XCTAssertEqual(unchanged.balances[0].provenance, original.balances[0].provenance)
        XCTAssertEqual(unchanged.balances[0].financialBalanceDate, original.balances[0].financialBalanceDate)

        let amount = PlanningChange.planningBalance(balanceID: "balance-qatar", accountID: "qatar",
            fields: .init(amount: .value(try requested("120.00")), included: .omitted))
        let edited = try PlanningChangeApplicator.apply([amount], to: original, snapshot: snapshot(), accounts: accounts)
        XCTAssertNil(edited.assistance?.surplusAllocation)
        XCTAssertEqual(edited.balances[0].money, try money("120.00"))
        XCTAssertEqual(edited.balances[0].provenance, .manual)
        XCTAssertNil(edited.balances[0].financialBalanceDate)
        XCTAssertEqual(original.balances[0].money, try money("100.00"))
    }

    func testEnvelopeFreePositiveKeepRejectsOtherBankCapacityAndKeepsZeroDeficitMeaning() throws {
        var value = try plan()
        value.keepInCBQ = try money("900.01")
        XCTAssertThrowsError(try SurplusAllocationCalculator.validateUnallocatedKeep(plan: value, accounts: accounts,
            preferences: snapshot().preferences)) { XCTAssertEqual($0 as? SurplusAllocationError, .exceedsCapacity) }
        value.keepInCBQ = try money("0.00")
        value.expectedFixedEarnings = try money("0.00")
        XCTAssertNoThrow(try SurplusAllocationCalculator.validateUnallocatedKeep(plan: value, accounts: accounts,
            preferences: nil))
        XCTAssertNil(value.assistance?.surplusAllocation)
    }

    func testManualFXEditRequiresExplicitCrossCurrencyTransferRepricing() throws {
        var original = try plan(envelope: true)
        original.assistance?.transfers = [.init(id: "planned-remittance", fromAccountID: "qatar", toAccountID: "india-nre",
            sent: try PlanningAmount(money("200.00")), received: try PlanningAmount(money("600.00", "INR")),
            date: "2026-10-20", conversionBasis: "Month-local manual rate")]
        let changes = [PlanningChange.manualFX(inrPerQAR: 4,
            observationDate: try StatementDate(canonical: "2026-10-21"))]
        XCTAssertThrowsError(try PlanningChangeApplicator.apply(changes, to: original, snapshot: snapshot(),
            accounts: accounts, productLabels: ["india-nre": ["NRE"]]))
        XCTAssertEqual(original.assistance?.transfers?[0].sent, try PlanningAmount(money("200.00")))
        XCTAssertEqual(original.planningFX?.inrPerQAR, 3)
    }

    func testActualLinkedTransferCannotBeChangedOrRemoved() throws {
        var original = try plan(envelope: true)
        original.assistance?.transfers = [.init(id: "observed-remittance", fromAccountID: "qatar", toAccountID: "india-nre",
            sent: try PlanningAmount(money("200.00")), received: try PlanningAmount(money("600.00", "INR")),
            date: "2026-10-20", conversionBasis: "Month-local manual rate", transactionIDs: ["actual-transaction"])]
        let remove = PlanningChange.removeAllocation(kind: .transfer, recordID: "observed-remittance")
        XCTAssertThrowsError(try PlanningChangeApplicator.apply([remove], to: original, snapshot: snapshot(),
            accounts: accounts, productLabels: ["india-nre": ["NRE"]]))
        let update = PlanningChange.transfer(action: .update, transferID: "observed-remittance",
            fields: .init(fromAccountID: .omitted, toAccountID: .omitted, received: .omitted,
                date: .value(try StatementDate(canonical: "2026-10-21")), fundingTransferID: .omitted,
                requiredIndiaFunding: .omitted))
        XCTAssertThrowsError(try PlanningChangeApplicator.apply([update], to: original, snapshot: snapshot(),
            accounts: accounts, productLabels: ["india-nre": ["NRE"]]))
        XCTAssertEqual(original.assistance?.transfers?.first?.transactionIDs, ["actual-transaction"])
    }

    func testForwardInvestmentFundingLinkResolvesAgainstFinalBatch() throws {
        let transferID = "00D26464-26B5-4D88-AD22-EB107E32650C"
        let investmentID = "7EE759D2-8185-488C-990A-8216613CBC6E"
        let invest = PlanningChange.investment(action: .create, investmentID: investmentID,
            fields: .init(instrument: .value(.indianMutualFund(schemeCode: "123456", title: "Selected scheme")),
                fundingAccountID: .value("india-nre"), amount: .value(try requested("100.00", "INR")),
                date: .value(try StatementDate(canonical: "2026-10-22")), fundingTransferID: .value(transferID)))
        let transfer = PlanningChange.transfer(action: .create, transferID: transferID,
            fields: .init(fromAccountID: .value("qatar"), toAccountID: .value("india-nre"),
                received: .value(try requested("900.00", "INR")),
                date: .value(try StatementDate(canonical: "2026-10-21")), fundingTransferID: .null,
                requiredIndiaFunding: .null))
        let link = PlanningChange.allocationLinks(fields: .init(requiredIndiaTransferID: .value(transferID),
            keepInCBQDesignationID: .omitted))
        let result = try PlanningChangeApplicator.apply([invest, transfer, link], to: plan(), snapshot: snapshot(),
            accounts: accounts, productLabels: ["india-nre": ["NRE"]])
        XCTAssertEqual(result.assistance?.surplusAllocation?.investments.first?.fundingTransferID, transferID)
        XCTAssertEqual(result.assistance?.transfers?.first?.sent, try PlanningAmount(money("300.00")))
        XCTAssertEqual(result.assistance?.surplusAllocation?.investments.first?.id, investmentID)
    }

    func testDueDateEditClearsCarriedOverrideWhileOlderReviewedPaymentRemainsSeparate() throws {
        var original = try plan()
        original.assistance?.salaryCycle = SalaryFundingCycle.expected(month: original.month)
        original.indiaCommitments[0].fundingAccountID = "existing-card"
        original.indiaCommitments[0].dueDate = try StatementDate(canonical: "2026-09-20")
        original.assistance?.billFundingAccounts = ["india-bill": "india-nre"]
        original.assistance?.carriedBillDates = ["india-bill": "2026-11-01"]
        let older = PlanDatedAdjustment(id: "reviewed-older-statement", accountID: "india-nre",
            kind: .irregularCost, title: "Reviewed older statement payment",
            amount: try PlanningAmount(money("240.00", "INR")), date: "2026-10-20",
            cardAccountID: "existing-card", cardStatementID: "older-statement",
            replacesCommitmentID: "india-bill")
        original.assistance?.datedAdjustments = [older]
        XCTAssertEqual(FundingPlanCalculator.staleReviewedObligationIDs(in: original), Set([older.id]))
        var sourceAccounts = accounts
        sourceAccounts.append(.init(id: "existing-card", workspaceId: workspace, name: "Existing card",
            institutionId: nil, accountType: "credit_card", nativeCurrency: "INR", createdAtISO: timestamp))

        let change = PlanningChange.obligation(region: .india, obligationID: "india-bill",
            fields: .init(amount: .omitted, dueDate: .value(try StatementDate(canonical: "2026-11-03")),
                included: .omitted, payingAccountID: .omitted))
        let saved = try PlanningChangeApplicator.apply([change], to: original,
            snapshot: snapshot(), accounts: sourceAccounts)
        XCTAssertEqual(saved.indiaCommitments[0].dueDate?.canonical, "2026-11-03")
        XCTAssertNil(saved.assistance?.carriedBillDates?["india-bill"])
        XCTAssertEqual(saved.assistance?.datedAdjustments, [older])
        XCTAssertEqual(saved.indiaCommitments[0].money, try money("600.00", "INR"))
        XCTAssertEqual(saved.indiaCommitments[0].fundingAccountID, "existing-card")
        XCTAssertEqual(saved.assistance?.billFundingAccounts?["india-bill"], "india-nre")
        XCTAssertEqual(FundingPlanCalculator.staleReviewedObligationIDs(in: saved), Set([older.id]))
        let effective = try XCTUnwrap(FundingPlanCalculator.effectiveIncludedObligations(saved)
            .first { $0.billID == "india-bill" })
        XCTAssertEqual(effective.money, try money("600.00", "INR"))
        XCTAssertEqual(effective.staleReplacementAdjustmentID, older.id)
        XCTAssertEqual(original.assistance?.carriedBillDates?["india-bill"], "2026-11-01")
    }

    func testReferencedParentRemovalAndDuplicateStableIDCreationReject() throws {
        let transferID = "53727308-722A-4B08-8F62-633153918E5C"
        var original = try plan(envelope: true)
        original.assistance?.transfers = [.init(id: transferID, fromAccountID: "qatar", toAccountID: "india-nre",
            sent: try PlanningAmount(money("300.00")), received: try PlanningAmount(money("900.00", "INR")),
            date: "2026-10-21", conversionBasis: "Month-local manual rate")]
        original.assistance?.surplusAllocation?.requiredIndiaTransferID = transferID
        original.assistance?.surplusAllocation?.investments = [.init(id: "existing-investment",
            instrument: .indianMutualFund(schemeCode: "123456", title: "Selected scheme"),
            fundingAccountID: "india-nre", amount: try PlanningAmount(money("100.00", "INR")),
            date: "2026-10-22", fundingTransferID: transferID)]
        let before = original
        let remove = PlanningChange.removeAllocation(kind: .transfer, recordID: transferID)
        XCTAssertThrowsError(try PlanningChangeApplicator.apply([remove], to: original, snapshot: snapshot(),
            accounts: accounts, productLabels: ["india-nre": ["NRE"]])) {
            XCTAssertEqual($0 as? SurplusAllocationError, .invalidFundingLink)
        }
        let duplicate = PlanningChange.transfer(action: .create, transferID: transferID,
            fields: .init(fromAccountID: .value("qatar"), toAccountID: .value("india-nre"),
                received: .value(try requested("900.00", "INR")),
                date: .value(try StatementDate(canonical: "2026-10-21")), fundingTransferID: .null,
                requiredIndiaFunding: .null))
        XCTAssertThrowsError(try PlanningChangeApplicator.apply([duplicate], to: original, snapshot: snapshot(),
            accounts: accounts, productLabels: ["india-nre": ["NRE"]])) {
            XCTAssertEqual($0 as? PlanningChangeError, .invalid("transfer_id"))
        }
        XCTAssertEqual(original, before)
    }
}
