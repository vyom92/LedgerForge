import Foundation
import XCTest
@testable import LedgerForge

/// Native-editor lifecycle with small manual planning estimates. No statement,
/// bank credit, imported balance, holding, or instrument recommendation is made.
@MainActor
final class PlanningAllocationEditorTests: XCTestCase {
    func testOpeningAndBrowsingDoesNotCreateAllocationEnvelopeOrPublishInstructions() throws {
        let setup = try harness()
        let before = try setup.provider.fundingPlanRepo.plans(workspaceId: AllocationEditorMechanics.workspace)
        let drafts = try setup.provider.fundingPlanRepo.scratchpads(workspaceId: AllocationEditorMechanics.workspace)
        let vm = setup.makeEditor()
        vm.destinationSection = "Allocation & Reserves"
        vm.plannerOpened()
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-11"))
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        vm.flushPendingEntries()
        XCTAssertNil(vm.plan.assistance?.surplusAllocation)
        XCTAssertEqual(try setup.provider.fundingPlanRepo.plans(workspaceId: AllocationEditorMechanics.workspace), before)
        XCTAssertEqual(try setup.provider.fundingPlanRepo.scratchpads(workspaceId: AllocationEditorMechanics.workspace), drafts)
        XCTAssertEqual(setup.spy.canonicalWrites, 0)
        XCTAssertEqual(setup.spy.draftWrites, 0)
    }

    func testAssistanceGatewayAdoptsOnlyDeliberateAllocationsAndKeepsTheirEnvelopeIdentity() throws {
        let setup = try harness(), vm = setup.makeEditor()
        var assistance = PlanAssistance(workspaceID: AllocationEditorMechanics.workspace, month: "2026-10")
        vm.updateAssistance(assistance)
        vm.flushPendingEntries()
        XCTAssertNil(try canonical(setup.provider).assistance?.surplusAllocation,
                     "An unchanged empty allocation collection is not an allocation decision.")
        assistance.billFundingAccounts = ["owner-qatar-bill": "manual-qatar"]
        vm.updateAssistance(assistance)
        vm.flushPendingEntries()
        XCTAssertNil(vm.plan.assistance?.surplusAllocation)
        XCTAssertNil(try canonical(setup.provider).assistance?.surplusAllocation,
                     "A bill funding choice must not approve a surplus allocation.")
        assistance.contributions = [.init(designationID: "owner-cash-reserve", fundingAccountID: "manual-qatar",
            amount: try AllocationEditorMechanics.amount("200"), dueDate: "2026-10-26")]
        vm.updateAssistance(assistance)
        vm.flushPendingEntries()
        let approved = try canonical(setup.provider)
        let envelopeID = try XCTUnwrap(approved.assistance?.surplusAllocation?.id)
        XCTAssertEqual(approved.assistance?.contributions.first?.amount, try AllocationEditorMechanics.amount("200"))
        XCTAssertEqual(vm.allocationStatus(for: .contribution("owner-cash-reserve")), .approvedInPlan)
        assistance.contributions[0].amount = try AllocationEditorMechanics.amount("240")
        // Existing callers need not manufacture a new envelope to edit their
        // same contribution through the ordinary assistance gateway.
        vm.updateAssistance(assistance)
        vm.flushPendingEntries()
        XCTAssertEqual(try canonical(setup.provider).assistance?.surplusAllocation?.id, envelopeID)
        XCTAssertEqual(try canonical(setup.provider).assistance?.contributions.first?.id, "owner-cash-reserve")
        XCTAssertEqual(try canonical(setup.provider).assistance?.contributions.first?.amount, try AllocationEditorMechanics.amount("240"))

        let transferSetup = try harness(), transferVM = transferSetup.makeEditor()
        var transferAssistance = PlanAssistance(workspaceID: AllocationEditorMechanics.workspace, month: "2026-10")
        transferAssistance.transfers = [.init(id: "owner-transfer", fromAccountID: "manual-qatar", toAccountID: "manual-india",
            sent: try AllocationEditorMechanics.amount("10"), received: try AllocationEditorMechanics.amount("30", "INR"),
            date: "2026-10-26", conversionBasis: "Manual planning mechanics")]
        transferVM.updateAssistance(transferAssistance)
        let transferEnvelopeID = try XCTUnwrap(transferVM.plan.assistance?.surplusAllocation?.id)
        transferVM.flushPendingEntries()
        XCTAssertEqual(try scratchpad(transferSetup.provider).plan.assistance?.surplusAllocation?.id, transferEnvelopeID)
        XCTAssertEqual(transferVM.allocationStatus(for: .transfer("owner-transfer")), .needsReview)
        XCTAssertNil(try canonical(transferSetup.provider).assistance?.surplusAllocation,
                     "Adoption retains the explicit intention; missing eligible route evidence cannot approve it.")
        transferAssistance.transfers?[0].sent = try AllocationEditorMechanics.amount("20")
        transferVM.updateAssistance(transferAssistance)
        XCTAssertEqual(transferVM.plan.assistance?.surplusAllocation?.id, transferEnvelopeID)
    }

    func testValidManualInvestmentPublishesAutomaticallyWithoutSecondApproval() async throws {
        let setup = try harness(), vm = setup.makeEditor()
        let before = try setup.provider.investmentRepo.snapshot(workspaceID: AllocationEditorMechanics.workspace)
        let row = try addIBKR(vm, amount: "200")
        for _ in 0..<40 {
            if vm.allocationStatus(for: row) == .approvedInPlan { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let saved = try canonical(setup.provider)
        let instruction = try XCTUnwrap(saved.assistance?.surplusAllocation?.investments.first)
        XCTAssertEqual(instruction.id, investmentID(row))
        XCTAssertEqual(instruction.amount, try AllocationEditorMechanics.amount("200"))
        XCTAssertEqual(instruction.instrument, .ibkr(conid: "12345", title: "Owner selected instrument", quoteCurrency: "USD"))
        XCTAssertEqual(vm.allocationStatus(for: row), .approvedInPlan)
        XCTAssertEqual(vm.saveState, .saved)
        XCTAssertEqual(vm.calculation.surplusAfterObligations, try AllocationEditorMechanics.money("900"))
        if case .success(let result)? = vm.allocationResult {
            XCTAssertEqual(result.remainingByFundingSource["cash:QAR"], try AllocationEditorMechanics.money("600"))
        } else { XCTFail("A successfully published instruction needs a complete allocation result.") }
        XCTAssertEqual(try setup.provider.investmentRepo.snapshot(workspaceID: AllocationEditorMechanics.workspace), before)
        XCTAssertTrue(try setup.provider.transactionRepo.trustedTransactions(workspaceId: AllocationEditorMechanics.workspace).isEmpty)
    }

    func testIncompleteAllocationIsRetainedAcrossHydrationAndReopenWithOldCanonicalIntact() throws {
        let setup = try harness(), vm = setup.makeEditor()
        let row = try addIBKR(vm, amount: "200")
        vm.flushPendingEntries()
        let approved = try canonical(setup.provider)
        vm.setAllocationText(.amount, row: row, text: "200.")
        vm.flushPendingEntries()
        XCTAssertEqual(vm.allocationStatus(for: row), .incompleteEntry)
        XCTAssertEqual(try canonical(setup.provider), approved)
        let retained = try scratchpad(setup.provider)
        XCTAssertEqual(retained.rawText[row.fieldKey(.amount)], "200.")
        XCTAssertNotNil(retained.fieldErrors[row.fieldKey(.amount)])
        XCTAssertEqual(retained.canonical, approved)
        try setup.hydrate(setup.provider)
        let recovered = setup.makeEditor()
        XCTAssertEqual(recovered.rawText[row.fieldKey(.amount)], "200.")
        XCTAssertEqual(recovered.allocationStatus(for: row), .incompleteEntry)
        XCTAssertEqual(recovered.plan.assistance?.surplusAllocation?.investments.first?.id, investmentID(row))
        XCTAssertEqual(try canonical(setup.provider), approved)
        XCTAssertEqual(setup.spy.canonicalWrites, 1)
    }

    func testOverAllocationRetainsRequestedAmountAndPreservesApprovedCanonical() throws {
        let setup = try harness(), vm = setup.makeEditor()
        let row = try addIBKR(vm, amount: "200")
        vm.flushPendingEntries()
        let approved = try canonical(setup.provider)
        vm.setAllocationText(.amount, row: row, text: "800.01")
        vm.flushPendingEntries()
        XCTAssertEqual(vm.allocationStatus(for: row), .needsReview)
        XCTAssertNotNil(vm.allocationReviewMessage)
        XCTAssertEqual(try canonical(setup.provider), approved)
        let retained = try scratchpad(setup.provider)
        XCTAssertEqual(retained.rawText[row.fieldKey(.amount)], "800.01")
        XCTAssertEqual(retained.plan.assistance?.surplusAllocation?.investments.first?.amount, try AllocationEditorMechanics.amount("800.01"))
        XCTAssertEqual(retained.canonical, approved)
        XCTAssertEqual(vm.saveState, .ready, "An affordability review must leave the retained editor usable.")
    }

    func testKeepAloneAboveSurplusRetainsExactRequestUntilCorrectionPublishes() throws {
        let setup = try harness(), vm = setup.makeEditor()
        let before = try canonical(setup.provider)
        vm.setAllocationText(.amount, row: .retention, text: "900.01")
        let envelopeID = try XCTUnwrap(vm.plan.assistance?.surplusAllocation?.id)
        vm.flushPendingEntries()
        XCTAssertEqual(vm.calculation.surplusAfterObligations, try AllocationEditorMechanics.money("900"))
        XCTAssertTrue(vm.hasValidCalculation, "A complete worksheet still exposes its honest pre-allocation surplus.")
        XCTAssertEqual(vm.allocationStatus(for: .retention), .needsReview)
        XCTAssertFalse(vm.canSave)
        XCTAssertEqual(try canonical(setup.provider), before)
        let retained = try scratchpad(setup.provider)
        XCTAssertEqual(retained.rawText["reserve"], "900.01")
        XCTAssertEqual(retained.plan.keepInCBQ, try AllocationEditorMechanics.money("900.01"))
        XCTAssertEqual(retained.plan.assistance?.surplusAllocation?.id, envelopeID)
        XCTAssertTrue(retained.plan.assistance?.surplusAllocation?.investments.isEmpty ?? false)
        XCTAssertTrue(retained.plan.assistance?.contributions.isEmpty ?? false)
        XCTAssertEqual(retained.canonical, before)
        XCTAssertEqual(setup.spy.canonicalWrites, 0)

        vm.setAllocationText(.amount, row: .retention, text: "500")
        vm.flushPendingEntries()
        let repaired = try canonical(setup.provider)
        XCTAssertEqual(repaired.keepInCBQ, try AllocationEditorMechanics.money("500"))
        XCTAssertEqual(repaired.assistance?.surplusAllocation?.id, envelopeID)
        XCTAssertEqual(repaired.id, before.id)
        XCTAssertEqual(repaired.balances, before.balances)
        XCTAssertEqual(repaired.qatarCommitments, before.qatarCommitments)
        XCTAssertEqual(vm.allocationStatus(for: .retention), .approvedInPlan)
        XCTAssertEqual(vm.saveState, .saved)
        if case .success(let result)? = vm.allocationResult {
            XCTAssertEqual(result.monthlySurplus, try AllocationEditorMechanics.money("900"))
            XCTAssertEqual(result.retainedInCBQ, try AllocationEditorMechanics.money("500"))
            XCTAssertEqual(result.remainingByFundingSource["cash:QAR"], try AllocationEditorMechanics.money("400"))
        } else { XCTFail("The corrected Keep intention should publish with exact remaining capacity.") }
        XCTAssertEqual(setup.spy.canonicalWrites, 1)
    }

    func testSalaryReductionBelowApprovedKeepRetainsWorksheetAndStableIdentityAcrossReopen() throws {
        let setup = try harness(), vm = setup.makeEditor()
        vm.setAllocationText(.amount, row: .retention, text: "500")
        vm.flushPendingEntries()
        let approved = try canonical(setup.provider)
        let envelopeID = try XCTUnwrap(approved.assistance?.surplusAllocation?.id)
        XCTAssertEqual(vm.allocationStatus(for: .retention), .approvedInPlan)
        XCTAssertTrue(vm.updateMoney(.fixed, text: "100"))
        vm.flushPendingEntries()
        XCTAssertEqual(vm.calculation.surplusAfterObligations, try AllocationEditorMechanics.money("0"))
        XCTAssertEqual(vm.plan.keepInCBQ, try AllocationEditorMechanics.money("500"))
        XCTAssertEqual(vm.allocationStatus(for: .retention), .needsReview)
        XCTAssertNotNil(vm.allocationReviewMessage)
        XCTAssertEqual(try canonical(setup.provider), approved)
        let retained = try scratchpad(setup.provider)
        XCTAssertEqual(retained.rawText["fixed"], "100")
        XCTAssertEqual(retained.plan.expectedFixedEarnings, try AllocationEditorMechanics.money("100"))
        XCTAssertEqual(retained.plan.keepInCBQ, approved.keepInCBQ)
        XCTAssertEqual(retained.plan.assistance?.surplusAllocation?.id, envelopeID)
        XCTAssertEqual(retained.plan.id, approved.id)
        XCTAssertEqual(retained.plan.balances, approved.balances)
        XCTAssertEqual(retained.plan.qatarCommitments, approved.qatarCommitments)
        XCTAssertEqual(retained.canonical, approved)

        try setup.hydrate(setup.provider)
        let recovered = setup.makeEditor()
        XCTAssertEqual(recovered.moneyText(.fixed), "100")
        XCTAssertEqual(recovered.plan.keepInCBQ, approved.keepInCBQ)
        XCTAssertEqual(recovered.plan.assistance?.surplusAllocation?.id, envelopeID)
        XCTAssertEqual(recovered.allocationStatus(for: .retention), .needsReview)
        XCTAssertEqual(try canonical(setup.provider), approved)
        XCTAssertTrue(recovered.updateMoney(.fixed, text: "1200"))
        recovered.flushPendingEntries()
        let repaired = try canonical(setup.provider)
        XCTAssertEqual(repaired.expectedFixedEarnings, try AllocationEditorMechanics.money("1200"))
        XCTAssertEqual(repaired.keepInCBQ, approved.keepInCBQ)
        XCTAssertEqual(repaired.assistance?.surplusAllocation?.id, envelopeID)
        XCTAssertEqual(repaired.id, approved.id)
        XCTAssertEqual(repaired.balances, approved.balances)
        XCTAssertEqual(repaired.qatarCommitments, approved.qatarCommitments)
        XCTAssertEqual(recovered.allocationStatus(for: .retention), .approvedInPlan)
        if case .success(let result)? = recovered.allocationResult {
            XCTAssertEqual(result.monthlySurplus, try AllocationEditorMechanics.money("1100"))
            XCTAssertEqual(result.remainingByFundingSource["cash:QAR"], try AllocationEditorMechanics.money("600"))
        } else { XCTFail("Restored salary capacity should republish the same Keep intention.") }
        XCTAssertEqual(setup.spy.canonicalWrites, 2)
    }

    func testOtherQARCashCannotFundKeepButExactRetentionAccountCapacityCanPublish() throws {
        let setup = try harness()
        _ = try setup.base.accountRepo.upsertAccount(.init(id: "manual-other-qatar", workspaceId: AllocationEditorMechanics.workspace,
            name: "Owner other QAR bank", accountType: "bank", nativeCurrency: "QAR", createdAtISO: AllocationEditorMechanics.timestamp))
        var worksheet = try canonical(setup.provider)
        worksheet.expectedFixedEarnings = try AllocationEditorMechanics.money("0")
        worksheet.balances[0].money = try AllocationEditorMechanics.money("0")
        worksheet.balances.append(.init(id: "owner-other-qatar-balance", accountID: "manual-other-qatar",
            nativeCurrency: try CurrencyCode("QAR"), included: true, money: try AllocationEditorMechanics.money("1000"), provenance: .manual))
        worksheet.qatarCommitments = []
        worksheet.keepInCBQ = try AllocationEditorMechanics.money("0")
        let originalRevision = try setup.base.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: AllocationEditorMechanics.workspace, month: worksheet.month.canonical).monthRevision
        _ = try setup.base.fundingPlanRepo.savePlan(worksheet.persistenceDTO(),
            expected: originalRevision, origin: .manual)
        try setup.hydrate(setup.provider)
        let vm = setup.makeEditor(), before = try canonical(setup.provider)
        vm.setAllocationText(.amount, row: .retention, text: "500")
        let envelopeID = try XCTUnwrap(vm.plan.assistance?.surplusAllocation?.id)
        vm.flushPendingEntries()
        XCTAssertEqual(vm.calculation.surplusAfterObligations, try AllocationEditorMechanics.money("1000"))
        XCTAssertEqual(vm.plan.balances.first { $0.accountID == "manual-qatar" }?.money, try AllocationEditorMechanics.money("0"))
        XCTAssertEqual(vm.allocationStatus(for: .retention), .needsReview,
                       "Cash held at a different QAR bank cannot approve a Keep instruction at the retention bank.")
        XCTAssertNotNil(vm.allocationReviewMessage)
        XCTAssertFalse(vm.canSave)
        XCTAssertEqual(try canonical(setup.provider), before)
        let retained = try scratchpad(setup.provider)
        XCTAssertEqual(retained.plan.keepInCBQ, try AllocationEditorMechanics.money("500"))
        XCTAssertEqual(retained.rawText["reserve"], "500")
        XCTAssertEqual(retained.plan.assistance?.surplusAllocation?.id, envelopeID)
        XCTAssertEqual(retained.canonical, before)
        XCTAssertEqual(setup.spy.canonicalWrites, 0)

        // The same requested Keep becomes affordable at the exact boundary
        // when the worksheet adds salary capacity to its retention source.
        XCTAssertTrue(vm.updateMoney(.fixed, text: "500"))
        vm.flushPendingEntries()
        let approved = try canonical(setup.provider)
        XCTAssertEqual(approved.keepInCBQ, try AllocationEditorMechanics.money("500"))
        XCTAssertEqual(approved.assistance?.surplusAllocation?.id, envelopeID)
        XCTAssertEqual(approved.balances, before.balances)
        XCTAssertEqual(vm.allocationStatus(for: .retention), .approvedInPlan)
        if case .success(let result)? = vm.allocationResult {
            XCTAssertEqual(result.monthlySurplus, try AllocationEditorMechanics.money("1500"))
            XCTAssertEqual(result.remainingRetentionCapacity, try AllocationEditorMechanics.money("0"))
            XCTAssertEqual(result.remainingByFundingSource["cash:QAR"], try AllocationEditorMechanics.money("1000"))
        } else { XCTFail("The exact source-specific Keep boundary should publish.") }

        vm.setAllocationText(.amount, row: .retention, text: "500.01")
        vm.flushPendingEntries()
        XCTAssertEqual(vm.allocationStatus(for: .retention), .needsReview)
        XCTAssertEqual(try canonical(setup.provider), approved)
        XCTAssertEqual(try scratchpad(setup.provider).rawText["reserve"], "500.01")
        XCTAssertEqual(try scratchpad(setup.provider).plan.assistance?.surplusAllocation?.id, envelopeID)
        XCTAssertEqual(setup.spy.canonicalWrites, 1)

        XCTAssertTrue(vm.updateMoney(.fixed, text: "0"))
        vm.setAllocationText(.amount, row: .retention, text: "0")
        vm.flushPendingEntries()
        XCTAssertEqual(try canonical(setup.provider).keepInCBQ, try AllocationEditorMechanics.money("0"))
        XCTAssertEqual(try canonical(setup.provider).assistance?.surplusAllocation?.id, envelopeID)
        XCTAssertEqual(vm.allocationStatus(for: .retention), .approvedInPlan)
        XCTAssertEqual(setup.spy.canonicalWrites, 2)
    }

    func testZeroKeepPreservesPublishableDeficitWithAndWithoutAllocationEnvelopeOrRetentionSource() throws {
        let setup = try harness()
        let oldPreferences = try XCTUnwrap(setup.intelligence.snapshot?.preferences)
        var preferences = oldPreferences
        preferences.retentionAccountID = nil
        try setup.base.intelligenceRepo.applyPlanning(.preferences(preferences, replacing: oldPreferences))
        try setup.hydrate(setup.provider)
        let vm = setup.makeEditor()
        XCTAssertTrue(vm.updateMoney(.reserve, text: "0"))
        XCTAssertTrue(vm.updateMoney(.fixed, text: "0"))
        vm.flushPendingEntries()
        let ordinaryWorksheet = try canonical(setup.provider)
        XCTAssertEqual(ordinaryWorksheet.keepInCBQ, try AllocationEditorMechanics.money("0"))
        XCTAssertEqual(ordinaryWorksheet.expectedFixedEarnings, try AllocationEditorMechanics.money("0"))
        XCTAssertNil(ordinaryWorksheet.assistance?.surplusAllocation)
        XCTAssertEqual(vm.calculation.surplusAfterObligations, try AllocationEditorMechanics.money("-100"))
        XCTAssertEqual(vm.allocationStatus(for: .retention), .existingChoice)
        XCTAssertNil(vm.allocationResult)
        XCTAssertEqual(vm.saveState, .saved)

        vm.setAllocationText(.amount, row: .retention, text: "0")
        vm.flushPendingEntries()
        let explicitZeroKeep = try canonical(setup.provider)
        XCTAssertNotNil(explicitZeroKeep.assistance?.surplusAllocation)
        XCTAssertEqual(explicitZeroKeep.keepInCBQ, ordinaryWorksheet.keepInCBQ)
        XCTAssertEqual(explicitZeroKeep.expectedFixedEarnings, ordinaryWorksheet.expectedFixedEarnings)
        XCTAssertTrue(explicitZeroKeep.assistance?.surplusAllocation?.investments.isEmpty ?? false)
        XCTAssertTrue(explicitZeroKeep.assistance?.contributions.isEmpty ?? false)
        XCTAssertTrue(explicitZeroKeep.assistance?.transfers?.isEmpty ?? true)
        XCTAssertEqual(vm.allocationStatus(for: .retention), .approvedInPlan)
        XCTAssertTrue(vm.canSave)
        XCTAssertEqual(vm.saveState, .saved)
        if case .success(let result)? = vm.allocationResult {
            XCTAssertEqual(result.monthlySurplus, try AllocationEditorMechanics.money("-100"))
            XCTAssertEqual(result.retainedInCBQ, try AllocationEditorMechanics.money("0"))
            XCTAssertEqual(result.remainingByFundingSource["cash:QAR"], try AllocationEditorMechanics.money("-100"))
        } else { XCTFail("An honest deficit with zero discretionary use remains a publishable worksheet.") }
    }

    func testPositiveKeepRequiresCurrentEligibleNativeQARRetentionSource() throws {
        let scenarios: [(label: String, retentionID: String?, excluded: Bool, historyOnly: Bool)] = [
            ("no saved retention source", nil, false, false),
            ("unavailable saved source", "unavailable-owner-bank", false, false),
            ("saved source has another native currency", "manual-india", false, false),
            ("owner excluded saved source", "manual-qatar", true, false),
            ("saved source is history only", "manual-qatar", false, true)
        ]
        for scenario in scenarios {
            let setup = try harness()
            let before = try canonical(setup.provider)
            var metadata = try XCTUnwrap(setup.intelligence.snapshot)
            var preferences = try XCTUnwrap(metadata.preferences)
            preferences.retentionAccountID = scenario.retentionID
            preferences.excludedPlanningAccountIDs = scenario.excluded ? ["manual-qatar"] : []
            metadata.preferences = preferences
            // Exercise unavailable retained metadata directly in an isolated
            // hydrated store. Do not save an invalid preferences record merely
            // to manufacture an account/source mismatch for this editor check.
            setup.intelligence.installWithoutObservation(metadata, generation: setup.provider.generationToken,
                                                         sources: setup.intelligence.sources)
            if scenario.historyOnly {
                setup.accounts.installAccountsWithoutObservation(setup.accounts.accounts.map { original in
                    var account = original
                    if account.repositoryAccountId == "manual-qatar" { account.status = .closed }
                    return account
                })
            }
            let vm = setup.makeEditor()
            vm.setAllocationText(.amount, row: .retention, text: "200")
            vm.flushPendingEntries()
            XCTAssertEqual(vm.allocationStatus(for: .retention), .needsReview, scenario.label)
            XCTAssertNotNil(vm.allocationReviewMessage, scenario.label)
            XCTAssertFalse(vm.canSave, scenario.label)
            XCTAssertEqual(try canonical(setup.provider), before, scenario.label)
            let retained = try scratchpad(setup.provider)
            XCTAssertEqual(retained.plan.keepInCBQ, try AllocationEditorMechanics.money("200"), scenario.label)
            XCTAssertEqual(retained.rawText["reserve"], "200", scenario.label)
            XCTAssertEqual(retained.canonical, before, scenario.label)
            XCTAssertEqual(setup.spy.canonicalWrites, 0, scenario.label)
        }
    }

    func testSameAccountReserveEarmarkPublishesWithoutPhantomTransferOrFundedEvidence() throws {
        let setup = try harness(), vm = setup.makeEditor()
        let reserve = try XCTUnwrap(setup.intelligence.snapshot?.reserves.first)
        let row = try XCTUnwrap(vm.addAllocationContribution(designationID: reserve.id))
        vm.setAllocationFundingAccount("manual-qatar", row: row)
        vm.setAllocationText(.amount, row: row, text: "200")
        vm.setAllocationText(.date, row: row, text: "2026-10-26")
        vm.setAllocationIncludesRetention(true, designationID: reserve.id)
        vm.flushPendingEntries()
        let saved = try canonical(setup.provider)
        XCTAssertEqual(saved.assistance?.contributions.first?.designationID, reserve.id)
        XCTAssertEqual(saved.assistance?.contributions.first?.amount, try AllocationEditorMechanics.amount("200"))
        XCTAssertEqual(saved.assistance?.surplusAllocation?.keepInCBQDesignationID, reserve.id)
        XCTAssertEqual(saved.keepInCBQ, try AllocationEditorMechanics.money("100"))
        XCTAssertTrue(saved.assistance?.transfers?.isEmpty ?? true)
        XCTAssertEqual(vm.allocationStatus(for: row), .approvedInPlan)
        if case .success(let result)? = vm.allocationResult {
            XCTAssertEqual(result.remainingByFundingSource["cash:QAR"], try AllocationEditorMechanics.money("700"))
        } else { XCTFail("The exact same-account earmark should have a complete capacity result.") }
        XCTAssertEqual(try setup.provider.intelligenceRepo.snapshot(workspaceID: AllocationEditorMechanics.workspace)?.reserves, [reserve])
        XCTAssertNil(reserve.planningBalance)
        XCTAssertTrue(try setup.provider.transactionRepo.trustedTransactions(workspaceId: AllocationEditorMechanics.workspace).isEmpty)
    }

    func testSalaryReductionKeepsApprovedAmountsAndNewWorksheetDraftUntilCapacityIsRepaired() throws {
        let setup = try harness(), vm = setup.makeEditor()
        let row = try addIBKR(vm, amount: "200")
        vm.flushPendingEntries()
        let approved = try canonical(setup.provider)
        let approvedInvestment = try XCTUnwrap(approved.assistance?.surplusAllocation?.investments.first)
        XCTAssertTrue(vm.updateMoney(.fixed, text: "100"))
        vm.flushPendingEntries()
        XCTAssertEqual(vm.calculation.surplusAfterObligations, try AllocationEditorMechanics.money("0"))
        XCTAssertEqual(vm.plan.assistance?.surplusAllocation?.investments.first, approvedInvestment)
        XCTAssertEqual(vm.allocationStatus(for: row), .needsReview)
        XCTAssertNotNil(vm.allocationReviewMessage)
        XCTAssertEqual(try canonical(setup.provider), approved)
        let retained = try scratchpad(setup.provider)
        XCTAssertEqual(retained.plan.expectedFixedEarnings, try AllocationEditorMechanics.money("100"))
        XCTAssertEqual(retained.plan.assistance?.surplusAllocation?.investments.first, approvedInvestment)
        XCTAssertEqual(retained.canonical, approved)
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-11"))
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        XCTAssertEqual(vm.moneyText(.fixed), "100")
        XCTAssertEqual(vm.allocationStatus(for: row), .needsReview)
        XCTAssertTrue(vm.updateMoney(.fixed, text: "1200"))
        vm.flushPendingEntries()
        let repaired = try canonical(setup.provider)
        XCTAssertEqual(repaired.expectedFixedEarnings, try AllocationEditorMechanics.money("1200"))
        XCTAssertEqual(repaired.assistance?.surplusAllocation?.investments.first, approvedInvestment)
        XCTAssertEqual(vm.allocationStatus(for: row), .approvedInPlan)
    }

    func testHigherObligationRetainsApprovedIdentityWithoutReducingOrCancellingIt() throws {
        let setup = try harness(), vm = setup.makeEditor()
        let row = try addIBKR(vm, amount: "200")
        vm.flushPendingEntries()
        let approved = try canonical(setup.provider)
        let billID = try XCTUnwrap(vm.plan.qatarCommitments.first?.id)
        vm.editCommitment(region: "qatar", id: billID, field: "amount", text: "1000")
        vm.flushPendingEntries()
        XCTAssertEqual(vm.plan.qatarCommitments.first?.money, try AllocationEditorMechanics.money("1000"))
        XCTAssertEqual(vm.plan.assistance?.surplusAllocation?.investments, approved.assistance?.surplusAllocation?.investments)
        XCTAssertEqual(vm.allocationStatus(for: row), .needsReview)
        XCTAssertEqual(try canonical(setup.provider), approved)
        let retained = try scratchpad(setup.provider)
        XCTAssertEqual(retained.rawText["amount." + billID], "1000")
        XCTAssertEqual(retained.plan.qatarCommitments.first?.id, billID)
        XCTAssertEqual(retained.canonical, approved)
    }

    func testCanonicalWriteFailureDoesNotShowApprovalOrReplacePreviousInstructions() throws {
        let setup = try harness(), vm = setup.makeEditor()
        let before = try canonical(setup.provider)
        let row = try addIBKR(vm, amount: "200")
        setup.spy.rejectCanonical = true
        vm.flushPendingEntries()
        XCTAssertEqual(vm.saveState, .failed)
        XCTAssertEqual(vm.allocationStatus(for: row), .couldNotSave)
        XCTAssertEqual(try canonical(setup.provider), before)
        XCTAssertEqual(try scratchpad(setup.provider).rawText[row.fieldKey(.amount)], "200")
        XCTAssertNil(try canonical(setup.provider).assistance?.surplusAllocation)
        let attempts = setup.spy.canonicalWrites
        vm.flushPendingEntries()
        XCTAssertEqual(setup.spy.canonicalWrites, attempts, "An uncertain write must not enter a blind approval retry.")
    }

    func testCommittedInstructionWaitsForCanonicalHydrationBeforeApproval() throws {
        let setup = try harness(), vm = setup.makeEditor()
        setup.rejectRefresh = true
        let row = try addIBKR(vm, amount: "200")
        vm.flushPendingEntries()
        XCTAssertEqual(vm.saveState, .committedNeedsRefresh)
        XCTAssertNotEqual(vm.allocationStatus(for: row), .approvedInPlan)
        XCTAssertEqual(try canonical(setup.provider).assistance?.surplusAllocation?.investments.first?.amount,
                       try AllocationEditorMechanics.amount("200"))
        let attempts = setup.spy.canonicalWrites
        setup.rejectRefresh = false
        vm.retryCanonicalRefresh()
        XCTAssertEqual(vm.allocationStatus(for: row), .approvedInPlan)
        XCTAssertEqual(setup.spy.canonicalWrites, attempts, "Refreshing an existing receipt must not publish the instruction twice.")
    }

    func testConcurrentCanonicalPublicationPreservesIncomingStateAndUnapprovedEditor() throws {
        let setup = try harness(), vm = setup.makeEditor()
        let originalRevision = try setup.base.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: AllocationEditorMechanics.workspace, month: vm.month.canonical).monthRevision
        let row = try addIBKR(vm, amount: "200")
        var incoming = try canonical(setup.provider)
        incoming.expectedFixedEarnings = try AllocationEditorMechanics.money("1100")
        incoming.updatedAtISO = "2026-10-20T04:01:00Z"
        _ = try setup.base.fundingPlanRepo.savePlan(incoming.persistenceDTO(),
            expected: originalRevision, origin: .manual)
        try setup.hydrate(setup.provider)
        vm.flushPendingEntries()
        XCTAssertEqual(vm.saveState, .canonicalChanged)
        XCTAssertNotEqual(vm.allocationStatus(for: row), .approvedInPlan)
        XCTAssertEqual(vm.rawText[row.fieldKey(.amount)], "200")
        XCTAssertEqual(try canonical(setup.provider), incoming)
        XCTAssertNil(try canonical(setup.provider).assistance?.surplusAllocation)
        XCTAssertEqual(setup.spy.canonicalWrites, 0)
    }

    func testExactMutualFundSchemeAndIBKRIdentityStayPlanningOnly() throws {
        let setup = try harness(includeINRCash: true), vm = setup.makeEditor()
        let portfolio = try setup.provider.investmentRepo.snapshot(workspaceID: AllocationEditorMechanics.workspace)
        let ibkr = try addIBKR(vm, amount: "200")
        let fund = try XCTUnwrap(vm.addAllocationInvestment(kind: .indianMutualFund))
        vm.setAllocationFundingAccount("manual-india", row: fund)
        vm.setAllocationText(.instrumentID, row: fund, text: "456789")
        vm.setAllocationText(.instrumentTitle, row: fund, text: "Owner selected scheme")
        vm.setAllocationText(.amount, row: fund, text: "100")
        vm.setAllocationText(.date, row: fund, text: "2026-10-26")
        vm.flushPendingEntries()
        let saved = try canonical(setup.provider)
        let investments = try XCTUnwrap(saved.assistance?.surplusAllocation?.investments)
        XCTAssertEqual(investments.count, 2)
        XCTAssertEqual(investments.first { $0.id == investmentID(ibkr) }?.instrument,
                       .ibkr(conid: "12345", title: "Owner selected instrument", quoteCurrency: "USD"))
        XCTAssertEqual(investments.first { $0.id == investmentID(fund) }?.instrument,
                       .indianMutualFund(schemeCode: "456789", title: "Owner selected scheme"))
        XCTAssertEqual(investments.first { $0.id == investmentID(fund) }?.amount, try AllocationEditorMechanics.amount("100", "INR"))
        XCTAssertEqual(vm.allocationStatus(for: ibkr), .approvedInPlan)
        XCTAssertEqual(vm.allocationStatus(for: fund), .approvedInPlan)
        XCTAssertEqual(try setup.provider.investmentRepo.snapshot(workspaceID: AllocationEditorMechanics.workspace), portfolio)
        XCTAssertTrue(portfolio.holdings.isEmpty)
        XCTAssertTrue(try setup.provider.transactionRepo.trustedTransactions(workspaceId: AllocationEditorMechanics.workspace).isEmpty)
        vm.setAllocationText(.instrumentID, row: ibkr, text: "AAPL")
        vm.flushPendingEntries()
        XCTAssertEqual(vm.allocationStatus(for: ibkr), .incompleteEntry)
        XCTAssertEqual(vm.allocationStatus(for: fund), .approvedInPlan)
        XCTAssertEqual(vm.rawText[ibkr.fieldKey(.instrumentID)], "AAPL")
        XCTAssertEqual(try canonical(setup.provider), saved, "A ticker is not an exact IBKR conid and cannot replace the selected instrument.")
    }

    func testSQLiteReopenRecoversApprovedIdentityAndIncompleteNativeDraftWithoutCrossMonthCopy() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-allocation-editor-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("manual-planning.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: path)
        defer { sqlite.database.close() }
        let setup = try harness(base: .verifiedSQLite(sqlite)), vm = setup.makeEditor()
        let row = try addIBKR(vm, amount: "200")
        vm.flushPendingEntries()
        let approved = try canonical(setup.provider)
        vm.setAllocationText(.amount, row: row, text: "201.")
        vm.flushPendingEntries()
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-11"))
        XCTAssertNil(vm.plan.assistance?.surplusAllocation)
        vm.switchMonth(to: try SelectedStatementMonth(canonical: "2026-10"))
        XCTAssertEqual(vm.rawText[row.fieldKey(.amount)], "201.")
        let retained = try scratchpad(setup.provider)
        try sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        let recovered = AllocationEditorHarness(base: .verifiedSQLite(reopened))
        try recovered.hydrate(recovered.provider)
        let reopenedVM = recovered.makeEditor()
        XCTAssertEqual(try canonical(recovered.provider), approved)
        XCTAssertEqual(try scratchpad(recovered.provider), retained)
        XCTAssertEqual(reopenedVM.rawText[row.fieldKey(.amount)], "201.")
        XCTAssertEqual(reopenedVM.allocationStatus(for: row), .incompleteEntry)
        XCTAssertEqual(reopenedVM.plan.assistance?.surplusAllocation?.investments.first?.id, investmentID(row))
        XCTAssertEqual(try recovered.provider.fundingPlanRepo.plans(workspaceId: AllocationEditorMechanics.workspace).count, 1)
        XCTAssertTrue(try recovered.provider.investmentRepo.snapshot(workspaceID: AllocationEditorMechanics.workspace).holdings.isEmpty)
    }

    func testCompanionCodecPreservesAllocationAnchorAndUnsupportedLexicalDraft() throws {
        let setup = try harness(), vm = setup.makeEditor()
        let row = try addIBKR(vm, amount: "200")
        vm.flushPendingEntries()
        vm.setAllocationText(.amount, row: row, text: "200.")
        vm.flushPendingEntries()
        let retained = try scratchpad(setup.provider)
        let lexical = PlannerLexicalContext(defaultLocaleIdentifier: "en_US_POSIX", localeIdentifiersByField: [:])
        let metadata = MonthlyPlanSyncAdapter.metadata(for: retained, lexicalContext: lexical, retaining: .init())
        let binding = try MonthlyPlanSyncAdapter.makeBinding(
            scope: .init(lineage: "mechanics", session: "mechanics-session", phone: "mechanics-phone", month: "2026-10"),
            scratchpad: retained, metadata: metadata, bankCurrencies: ["manual-qatar": try CurrencyCode("QAR"), "manual-india": try CurrencyCode("INR")],
            fundingAccountIDs: ["manual-qatar", "manual-india"], excludedHistoryAccountIDs: [])
        var phone = retained
        phone.plan.expectedFixedEarnings = try AllocationEditorMechanics.money("1100")
        phone.rawText["fixed"] = "1100"
        let phoneMetadata = MonthlyPlanSyncAdapter.metadata(for: phone, lexicalContext: lexical,
            retaining: binding.baselineMetadata, previousScratchpad: retained)
        let encoded = try MonthlyPlanSyncAdapter.encode(phone, metadata: phoneMetadata, against: binding)
        let decoded = try MonthlyPlanSyncAdapter.decode(document: encoded.document, against: binding)
        XCTAssertEqual(decoded.scratchpad.plan.expectedFixedEarnings, try AllocationEditorMechanics.money("1100"))
        XCTAssertEqual(decoded.scratchpad.plan.assistance, retained.plan.assistance)
        XCTAssertEqual(decoded.scratchpad.rawText[row.fieldKey(.amount)], "200.")
        XCTAssertEqual(decoded.scratchpad.fieldErrors[row.fieldKey(.amount)], retained.fieldErrors[row.fieldKey(.amount)])
        phone.plan.assistance?.surplusAllocation?.investments[0].amount = try AllocationEditorMechanics.amount("201")
        XCTAssertThrowsError(try MonthlyPlanSyncAdapter.encode(phone, metadata: phoneMetadata, against: binding))
        XCTAssertEqual(try scratchpad(setup.provider), retained, "The codec cannot publish through this read-only adapter exercise.")
    }

    private func harness(base: DatabaseProvider? = nil, includeINRCash: Bool = false) throws -> AllocationEditorHarness {
        let setup = AllocationEditorHarness(base: base ?? DatabaseProvider(inMemory: true))
        try setup.seed(includeINRCash: includeINRCash)
        try setup.hydrate(setup.provider)
        return setup
    }

    private func addIBKR(_ vm: SalaryWorkspaceViewModel, amount: String) throws -> AllocationRowID {
        let row = try XCTUnwrap(vm.addAllocationInvestment(kind: .ibkr))
        vm.setAllocationFundingAccount("manual-qatar", row: row)
        vm.setAllocationText(.instrumentID, row: row, text: "12345")
        vm.setAllocationText(.instrumentTitle, row: row, text: "Owner selected instrument")
        vm.setAllocationText(.quoteCurrency, row: row, text: "USD")
        vm.setAllocationText(.amount, row: row, text: amount)
        vm.setAllocationText(.date, row: row, text: "2026-10-26")
        return row
    }

    private func investmentID(_ row: AllocationRowID) -> String {
        guard case .investment(let id) = row else { XCTFail("Expected an investment row"); return "" }
        return id
    }

    private func canonical(_ provider: DatabaseProvider) throws -> FundingPlan {
        try XCTUnwrap(provider.fundingPlanRepo.plans(workspaceId: AllocationEditorMechanics.workspace).first).allocationCalculationInput()
    }

    private func scratchpad(_ provider: DatabaseProvider) throws -> MonthlyPlanScratchpad {
        try MonthlyPlanScratchpad.decode(XCTUnwrap(provider.fundingPlanRepo.scratchpads(workspaceId: AllocationEditorMechanics.workspace).first))
    }
}

private enum AllocationEditorMechanics {
    static let workspace = "allocation-editor-mechanics"
    static let timestamp = "2026-10-20T04:00:00Z"

    static func money(_ value: String, _ currency: String = "QAR") throws -> Money {
        try Money(amount: XCTUnwrap(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))), currency: currency)
    }
    static func amount(_ value: String, _ currency: String = "QAR") throws -> PlanningAmount { try PlanningAmount(money(value, currency)) }
    static func plan(includeINRCash: Bool) throws -> FundingPlan {
        let zero = try money("0")
        var result = try FundingPlan(id: "manual-editor-october", workspaceID: workspace, month: SelectedStatementMonth(canonical: "2026-10"),
            expectedFixedEarnings: money("1000"), expectedFixedProvenance: .manual,
            expectedVariableEarnings: zero, expectedVariableProvenance: .manual,
            expectedDeductions: zero, expectedDeductionsProvenance: .manual,
            balances: [.init(id: "owner-qatar-balance", accountID: "manual-qatar", nativeCurrency: CurrencyCode("QAR"), included: true,
                             money: money("100"), provenance: .manual)],
            qatarCommitments: [.init(id: "owner-qatar-bill", label: "Owner monthly estimate", money: money("200"), included: true,
                                    fundingAccountID: "manual-qatar", provenance: .manual)], indiaCommitments: [],
            configuredTransferFee: zero, configuredTransferFeeProvenance: .manual, planningFX: nil,
            plannedInvestment: zero, plannedInvestmentProvenance: .manual, updatedAtISO: timestamp,
            calculationVersion: .budgetV1, keepInCBQ: money("100"))
        if includeINRCash {
            result.balances.append(.init(id: "owner-inr-balance", accountID: "manual-india", nativeCurrency: try CurrencyCode("INR"),
                                        included: true, money: try money("300", "INR"), provenance: .manual))
        }
        return result
    }
}

@MainActor
private final class AllocationEditorHarness {
    let base: DatabaseProvider
    let provider: DatabaseProvider
    let spy: AllocationPlanWriteSpy
    let accounts = AccountStore()
    let transactions = TransactionStore()
    let categories = CategoryStore()
    let cards = CardStore()
    let salaries = SalaryStore()
    let plans = FundingPlanStore()
    let investments = InvestmentStore()
    let membership = NetWorthMembershipStore()
    let intelligence = FinancialIntelligenceStore()
    let tags = TransactionTagStore()
    let sessions = ImportSessionStore()
    let attempts = ImportAttemptStore()
    var rejectRefresh = false

    init(base: DatabaseProvider) {
        self.base = base
        let spy = AllocationPlanWriteSpy(base.fundingPlanRepo)
        self.spy = spy
        self.provider = DatabaseProvider(workspaceRepo: base.workspaceRepo, transactionRepo: base.transactionRepo,
            categoryRepo: base.categoryRepo, accountRepo: base.accountRepo, cardRepo: base.cardRepo, importSessionRepo: base.importSessionRepo,
            salaryRepo: base.salaryRepo, fundingPlanRepo: spy, investmentRepo: base.investmentRepo,
            netWorthMembershipRepo: base.netWorthMembershipRepo, intelligenceRepo: base.intelligenceRepo, tagRepo: base.tagRepo,
            generationToken: base.generationToken, persistenceState: base.persistenceState)
    }

    func seed(includeINRCash: Bool) throws {
        let workspace = AllocationEditorMechanics.workspace, timestamp = AllocationEditorMechanics.timestamp
        _ = try base.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Manual allocation editor mechanics", createdAtISO: timestamp))
        for (id, currency) in [("manual-qatar", "QAR"), ("manual-india", "INR")] {
            _ = try base.accountRepo.upsertAccount(.init(id: id, workspaceId: workspace, name: "Owner planning account \(id)",
                accountType: "bank", nativeCurrency: currency, createdAtISO: timestamp))
        }
        try base.intelligenceRepo.applyPlanning(.preferences(.init(workspaceID: workspace, retentionAccountID: "manual-qatar"), replacing: nil))
        let reserve = ReserveDesignation(id: "owner-cash-reserve", workspaceID: workspace, accountID: "manual-qatar", title: "Owner reserve",
            kind: .accountCash, target: try AllocationEditorMechanics.amount("1000"))
        try base.intelligenceRepo.applyPlanning(.reserve(reserve, replacing: nil))
        _ = try base.fundingPlanRepo.savePlan(AllocationEditorMechanics.plan(includeINRCash: includeINRCash).persistenceDTO())
    }

    func hydrate(_ active: DatabaseProvider) throws {
        if rejectRefresh { throw RepositoryStoreHydrationError.invalidFundingPlanState("injected allocation-editor refresh failure") }
        let hydrator = RepositoryStoreHydrator(accountRepo: active.accountRepo, importSessionRepo: active.importSessionRepo,
            transactionRepo: active.transactionRepo, categoryRepo: active.categoryRepo, cardRepo: active.cardRepo,
            salaryRepo: active.salaryRepo, fundingPlanRepo: active.fundingPlanRepo, investmentRepo: active.investmentRepo,
            netWorthMembershipRepo: active.netWorthMembershipRepo, intelligenceRepo: active.intelligenceRepo, tagRepo: active.tagRepo,
            accountStore: accounts, transactionStore: transactions, categoryStore: categories, cardStore: cards,
            salaryStore: salaries, fundingPlanStore: plans, investmentStore: investments, netWorthMembershipStore: membership,
            intelligenceStore: intelligence, tagStore: tags, importSessionStore: sessions, importAttemptStore: attempts,
            workspaceId: AllocationEditorMechanics.workspace, persistenceState: active.persistenceState,
            providerGeneration: active.generationToken, participatesInLifecycleGate: false)
        hydrator.publish(try hydrator.stageHydration())
    }

    func makeEditor() -> SalaryWorkspaceViewModel {
        let vm = SalaryWorkspaceViewModel(month: try! SelectedStatementMonth(canonical: "2026-10"), workspaceID: AllocationEditorMechanics.workspace,
            provider: { self.provider }, accountStore: accounts, transactionStore: transactions, salaryStore: salaries,
            fundingPlanStore: plans, intelligenceStore: intelligence, locale: Locale(identifier: "en_US_POSIX"),
            now: { Date(timeIntervalSince1970: 1_792_468_800) }, refresh: { active in try self.hydrate(active) })
        vm.plannerOpened()
        return vm
    }
}

private final class AllocationPlanWriteSpy: FundingPlanRepository {
    let base: FundingPlanRepository
    var canonicalWrites = 0
    var draftWrites = 0
    var rejectCanonical = false

    init(_ base: FundingPlanRepository) { self.base = base }
    func plans(workspaceId: String) throws -> [FundingPlanDTO] { try base.plans(workspaceId: workspaceId) }
    func scratchpads(workspaceId: String) throws -> [MonthlyPlanScratchpadDTO] { try base.scratchpads(workspaceId: workspaceId) }
    func planningMonthRevisions(workspaceID: String) throws -> [PlanningMonthRevision] {
        try base.planningMonthRevisions(workspaceID: workspaceID)
    }
    func planningWriteSnapshot(workspaceID: String, month: String) throws -> PlanningWriteSnapshot {
        try base.planningWriteSnapshot(workspaceID: workspaceID, month: month)
    }
    func savePlan(_ plan: FundingPlanDTO) throws -> FundingPlanDTO {
        canonicalWrites += 1
        if rejectCanonical { throw RepositoryError.relationshipViolation("injected allocation publication failure") }
        return try base.savePlan(plan)
    }
    func savePlan(_ plan: FundingPlanDTO, expected: PlanningMonthRevision,
                  origin: PlanningSaveOrigin) throws -> PlanningMonthRevision {
        canonicalWrites += 1
        if rejectCanonical { throw RepositoryError.relationshipViolation("injected allocation publication failure") }
        return try base.savePlan(plan, expected: expected, origin: origin)
    }
    func savePlan(_ plan: FundingPlanDTO, retaining scratchpad: MonthlyPlanScratchpadDTO) throws -> FundingPlanDTO {
        canonicalWrites += 1
        if rejectCanonical { throw RepositoryError.relationshipViolation("injected allocation publication failure") }
        return try base.savePlan(plan, retaining: scratchpad)
    }
    func savePlan(_ plan: FundingPlanDTO, retaining scratchpad: MonthlyPlanScratchpadDTO,
                  expected: PlanningMonthRevision, origin: PlanningSaveOrigin) throws -> PlanningMonthRevision {
        canonicalWrites += 1
        if rejectCanonical { throw RepositoryError.relationshipViolation("injected allocation publication failure") }
        return try base.savePlan(plan, retaining: scratchpad, expected: expected, origin: origin)
    }
    func saveScratchpad(_ value: MonthlyPlanScratchpadDTO) throws {
        draftWrites += 1
        try base.saveScratchpad(value)
    }
    func saveScratchpad(_ value: MonthlyPlanScratchpadDTO,
                        expected: PlanningMonthRevision) throws -> PlanningMonthRevision {
        draftWrites += 1
        return try base.saveScratchpad(value, expected: expected)
    }
    func removeScratchpad(workspaceId: String, month: String) throws { try base.removeScratchpad(workspaceId: workspaceId, month: month) }
    func removeScratchpad(workspaceId: String, month: String,
                          expected: PlanningMonthRevision) throws -> PlanningMonthRevision {
        try base.removeScratchpad(workspaceId: workspaceId, month: month, expected: expected)
    }
}
