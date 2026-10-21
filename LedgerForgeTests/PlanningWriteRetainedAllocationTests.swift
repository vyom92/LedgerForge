import Foundation
import XCTest
@testable import LedgerForge

@MainActor
final class PlanningWriteRetainedAllocationTests: XCTestCase {
    private let workspace = "planning-write-retained-test"
    private let month = "2026-10"

    private func money(_ value: String) throws -> Money {
        try Money(canonicalDecimal: value, currency: "QAR")
    }

    private func plan() throws -> FundingPlan {
        let zero = try money("0.00")
        return try FundingPlan(id: "existing-month", workspaceID: workspace,
            month: SelectedStatementMonth(canonical: month),
            expectedFixedEarnings: money("1000.00"), expectedFixedProvenance: .manual,
            expectedVariableEarnings: zero, expectedVariableProvenance: .manual,
            expectedDeductions: zero, expectedDeductionsProvenance: .manual,
            balances: [], qatarCommitments: [], indiaCommitments: [],
            configuredTransferFee: zero, configuredTransferFeeProvenance: .manual,
            planningFX: FundingPlanFX(inrPerQAR: 3, observationDate: StatementDate(canonical: "2026-10-18")),
            plannedInvestment: zero, plannedInvestmentProvenance: .manual,
            updatedAtISO: "2026-10-21T04:00:00Z", calculationVersion: .budgetV1,
            keepInCBQ: zero, referenceMode: .manual,
            assistance: .init(workspaceID: workspace, month: month))
    }

    func testChangedAllocationFieldsDiscardStaleRawButPreserveUntouchedFieldsAndIdentity() throws {
        var original = try plan()
        original.assistance?.transfers = [
            .init(id: "transfer-a", fromAccountID: "qar", toAccountID: "inr",
                  sent: .init(currency: "QAR", decimal: "10.00"),
                  received: .init(currency: "INR", decimal: "30.00"),
                  date: "2026-10-26", conversionBasis: "manual"),
            .init(id: "transfer-b", fromAccountID: "qar", toAccountID: "inr",
                  sent: .init(currency: "QAR", decimal: "20.00"),
                  received: .init(currency: "INR", decimal: "60.00"),
                  date: "2026-10-27", conversionBasis: "manual")
        ]
        original.assistance?.surplusAllocation = .init(id: "allocation-envelope")
        let changedKey = AllocationRowID.transfer("transfer-a").fieldKey(.received)
        let untouchedKey = AllocationRowID.transfer("transfer-a").fieldKey(.amount)
        let deletedKey = AllocationRowID.transfer("transfer-b").fieldKey(.received)
        let scratch = MonthlyPlanScratchpad(plan: original, canonical: original,
            rawText: [changedKey: "30,00", untouchedKey: "10,00", deletedKey: "60,00", "fixed": "1 000,00"],
            fieldErrors: [:], untouchedZeroFields: [], unavailableBalanceAccountIDs: [],
            preReductionBasis: [:], excludedRecurringOccurrenceIDs: [])
        var next = original
        next.assistance?.transfers?[0].received = .init(currency: "INR", decimal: "33.00")
        next.assistance?.transfers?.removeLast()

        let retained = try FinancialMCPPlanningWriteService.retained(next, replacing: scratch.dto(),
            inputLocale: Locale(identifier: "fr_FR"))
        XCTAssertNil(retained.rawText[changedKey])
        XCTAssertNil(retained.rawText[deletedKey])
        XCTAssertEqual(retained.rawText[untouchedKey], "10,00")
        XCTAssertEqual(retained.rawText["fixed"], "1 000,00")
        XCTAssertEqual(retained.plan.assistance?.surplusAllocation?.id, "allocation-envelope")
        XCTAssertEqual(retained.plan.assistance?.transfers?.map(\.id), ["transfer-a"])
    }

    func testCommaDecimalRetainedAmountReopensAndNativeSavePreservesPublishedValue() throws {
        let provider = DatabaseProvider(inMemory: true)
        let store = FundingPlanStore()
        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Retained input test",
            createdAtISO: "2026-10-21T04:00:00Z"))
        let original = try plan()
        var oldScratch = try FinancialMCPPlanningWriteService.retained(original, replacing: nil,
            inputLocale: Locale(identifier: "fr_FR"))
        oldScratch.rawText["fixed"] = "1000,00"
        _ = try provider.fundingPlanRepo.savePlan(original.persistenceDTO())
        let firstRevision = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision
        _ = try provider.fundingPlanRepo.saveScratchpad(oldScratch.dto(), expected: firstRevision)
        var changed = original
        changed.expectedFixedEarnings = try money("1250.50")
        let retained = try FinancialMCPPlanningWriteService.retained(changed, replacing: oldScratch.dto(),
            inputLocale: Locale(identifier: "fr_FR"))
        XCTAssertEqual(retained.rawText["fixed"], "1250,50")
        let revision = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision
        let changedRevision = try provider.fundingPlanRepo.savePlan(changed.persistenceDTO(), expected: revision, origin: .chatgpt)
        _ = try provider.fundingPlanRepo.saveScratchpad(retained.dto(), expected: changedRevision)

        func hydrate() throws {
            let plans = try provider.fundingPlanRepo.plans(workspaceId: workspace).map { try $0.allocationCalculationInput() }
            let drafts = try provider.fundingPlanRepo.scratchpads(workspaceId: workspace).map(MonthlyPlanScratchpad.decode)
            let revision = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision
            store.installWithoutObservation(plans, generation: provider.generationToken,
                scratchpads: drafts, monthRevisions: [revision])
            store.notifyInstalledValue()
        }
        try hydrate()
        let native = SalaryWorkspaceViewModel(month: try SelectedStatementMonth(canonical: month), workspaceID: workspace,
            provider: { provider }, accountStore: AccountStore(), salaryStore: SalaryStore(), fundingPlanStore: store,
            locale: Locale(identifier: "fr_FR"), refresh: { _ in try hydrate() })
        XCTAssertEqual(native.moneyText(.fixed), "1250,50")
        _ = native.updateMoney(.variable, text: "20,00")
        native.save()
        XCTAssertEqual(native.saveState, .saved, native.errorMessage ?? "")
        XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            .plan?.allocationCalculationInput().expectedFixedEarnings, try money("1250.50"))
    }
}
