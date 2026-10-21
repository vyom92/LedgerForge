import Foundation
import XCTest
@testable import LedgerForge

/// Invented planning mechanics only. Card/statement IDs exercise explicit
/// links; they are not imported statements or evidence about the owner's cash.
@MainActor
final class ReviewedPlanningObligationTests: XCTestCase {
    private let workspace = "reviewed-obligation-mechanics"
    private let timestamp = "2026-10-20T04:00:00Z"

    private func money(_ amount: String, _ currency: String = "QAR") throws -> Money {
        try Money(canonicalDecimal: amount, currency: currency)
    }

    private func amount(_ value: String, _ currency: String = "INR") throws -> PlanningAmount {
        try PlanningAmount(money(value, currency))
    }

    private func account(_ id: String, _ currency: String, type: String = "bank", closedAt: String? = nil) -> AccountDTO {
        .init(id: id, workspaceId: workspace, name: "Mechanics account \(id)",
              institutionId: currency == "INR" ? "Axis Bank" : nil,
              accountType: type, nativeCurrency: currency, createdAtISO: timestamp, closedAtISO: closedAt)
    }

    private var accounts: [AccountDTO] {
        [account("qatar", "QAR"), account("india-a", "INR"), account("india-b", "INR"),
         account("card-a", "INR", type: "credit_card")]
    }

    private var preferences: IntelligencePreferences { .init(workspaceID: workspace, retentionAccountID: "qatar") }

    private func plan() throws -> FundingPlan {
        let zero = try money("0.00")
        return try FundingPlan(id: "reviewed-plan", workspaceID: workspace,
            month: SelectedStatementMonth(canonical: "2026-10"),
            expectedFixedEarnings: money("1000.00"), expectedFixedProvenance: .manual,
            expectedVariableEarnings: zero, expectedVariableProvenance: .manual,
            expectedDeductions: zero, expectedDeductionsProvenance: .manual,
            balances: [],
            qatarCommitments: [.init(id: "qatar-bill", label: "Manual local bill", money: money("100.00"),
                included: true, fundingAccountID: "qatar", provenance: .manual)],
            indiaCommitments: [.init(id: "card-estimate", label: "Manual upcoming card estimate", money: money("600.00", "INR"),
                included: true, fundingAccountID: "card-a", provenance: .manual,
                dueDate: StatementDate(canonical: "2026-11-01"))],
            configuredTransferFee: money("10.00"), configuredTransferFeeProvenance: .manual,
            planningFX: FundingPlanFX(inrPerQAR: 3, observationDate: StatementDate(canonical: "2026-10-18")),
            plannedInvestment: zero, plannedInvestmentProvenance: .manual, updatedAtISO: timestamp,
            calculationVersion: .budgetV1, keepInCBQ: zero, referenceMode: .manual,
            assistance: .init(workspaceID: workspace, month: "2026-10", billFundingAccounts: ["card-estimate": "india-a"],
                salaryCycle: SalaryFundingCycle.expected(month: SelectedStatementMonth(canonical: "2026-10")),
                surplusAllocation: .init(id: "allocation-october")))
    }

    private func review(_ value: String, bank: String = "india-a", replaces: String? = "card-estimate") throws -> PlanDatedAdjustment {
        .init(id: "reviewed-card-need", accountID: bank, kind: .irregularCost, title: "Explicit remaining card need",
              amount: try amount(value), date: "2026-11-01", cardAccountID: "card-a", cardStatementID: "statement-reviewed",
              replacesCommitmentID: replaces)
    }

    private func balance(_ value: String, accountID: String) throws -> FundingPlanBalance {
        .init(id: "balance-" + accountID, accountID: accountID, nativeCurrency: try CurrencyCode("INR"),
              included: true, money: try money(value, "INR"), provenance: .manual)
    }

    private func investment(_ value: String, accountID: String = "india-a", transferID: String? = nil) throws -> PlanInvestmentIntention {
        .init(id: "selected-scheme-intention", instrument: .indianMutualFund(schemeCode: "123456", title: "Selected mechanics scheme"),
              fundingAccountID: accountID, amount: try amount(value), date: "2026-11-02", fundingTransferID: transferID)
    }

    private func calculate(_ value: FundingPlan, reserves: [ReserveDesignation] = [], customAccounts: [AccountDTO]? = nil,
                           customPreferences: IntelligencePreferences? = nil) throws -> SurplusAllocationCalculation {
        try SurplusAllocationCalculator.calculate(plan: value, reserves: reserves, accounts: customAccounts ?? accounts,
            productLabels: ["india-a": ["NRE"], "india-b": ["NRE"]], preferences: customPreferences ?? preferences)
    }

    private func forecast(_ value: FundingPlan) throws -> PlanningProjection {
        let anchor = PlanningAccountAnchor(id: "india-a", title: "Mechanics INR bank", currency: "INR", domain: "bank",
            amount: 1000, date: try StatementDate(canonical: "2026-10-24"), historyOnly: false)
        let metadata = FinancialIntelligenceSnapshot(workspaceID: workspace, plans: value.assistance.map { [$0] } ?? [], preferences: preferences)
        return try PlanningIntelligence.project(plan: value, anchors: [anchor], rows: [], metadata: metadata,
            sources: .empty, cards: .empty, today: StatementDate(canonical: "2026-10-25"))
    }

    private func assertAllocationError(_ expected: SurplusAllocationError, _ value: FundingPlan,
                                       accounts: [AccountDTO]? = nil, preferences: IntelligencePreferences? = nil,
                                       file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try calculate(value, customAccounts: accounts, customPreferences: preferences), file: file, line: line) {
            XCTAssertEqual($0 as? SurplusAllocationError, expected, file: file, line: line)
        }
    }

    func testOctoberSalaryCycleIncludesNovemberObligationsWithoutFilteringManualRowsByCalendarMonth() throws {
        var value = try plan()
        let cycle = try XCTUnwrap(value.assistance?.salaryCycle)
        XCTAssertEqual(cycle.payday, "2026-10-25")
        XCTAssertEqual(cycle.nextPayday, "2026-11-25")
        XCTAssertTrue(cycle.includesRecurring(dueOn: try StatementDate(canonical: "2026-11-01")))
        XCTAssertTrue(cycle.includesRecurring(dueOn: try StatementDate(canonical: "2026-11-24")))
        XCTAssertFalse(cycle.includesRecurring(dueOn: try StatementDate(canonical: "2026-11-25")))
        value.qatarCommitments = []
        value.assistance?.billFundingAccounts = nil
        value.indiaCommitments = try [1, 24, 25].map { day in
            let date = try StatementDate(year: 2026, month: 11, day: day)
            return try .init(id: "november-\(day)", label: "Cycle bill \(day)", money: money("100.00", "INR"),
                included: cycle.includesRecurring(dueOn: date), fundingAccountID: "india-a", provenance: .manual,
                dueDate: date)
        }
        XCTAssertEqual(FundingPlanCalculator.calculate(value).indiaCommitments, try money("200.00", "INR"))
        XCTAssertEqual(value.indiaCommitments.map(\.dueDate?.canonical), ["2026-11-01", "2026-11-24", "2026-11-25"])
        value.indiaCommitments[2].included = true
        XCTAssertEqual(FundingPlanCalculator.calculate(value).indiaCommitments, try money("300.00", "INR"),
            "An explicit included manual row is never silently removed by its due date.")
    }

    func testSettledStatementReviewDoesNotChangeSeparateUpcomingManualEstimateOnSameCard() throws {
        var value = try plan()
        let original = value.indiaCommitments
        var historical = try review("0.00", replaces: nil)
        historical.date = "2026-10-21"
        historical.cardStatementID = "earlier-settled-statement"
        value.assistance?.datedAdjustments = [historical]
        let result = FundingPlanCalculator.calculate(value)
        XCTAssertEqual(result.indiaCommitments, try money("600.00", "INR"))
        XCTAssertEqual(result.requiredQARPrincipal, try money("200.00"))
        XCTAssertEqual(result.surplusAfterObligations, try money("690.00"))
        XCTAssertEqual(value.indiaCommitments, original)
        XCTAssertNil(try FundingPlanCalculator.effectiveIncludedObligations(value).first { $0.billID == "card-estimate" }?.replacementAdjustmentID)
    }

    func testExactZeroRemainingReviewReplacesOnlyNamedBillAndPreservesOriginal() throws {
        var value = try plan()
        value.indiaCommitments.append(.init(id: "other-estimate", label: "Independent upcoming amount", money: try money("120.00", "INR"),
            included: true, fundingAccountID: "card-a", provenance: .manual))
        let original = value.indiaCommitments
        value.assistance?.datedAdjustments = [try review("0.00")]
        let result = FundingPlanCalculator.calculate(value)
        XCTAssertEqual(result.indiaCommitments, try money("120.00", "INR"))
        XCTAssertEqual(result.requiredQARPrincipal, try money("40.00"))
        XCTAssertEqual(result.effectiveTransferFee, try money("10.00"))
        XCTAssertEqual(result.surplusAfterObligations, try money("850.00"))
        let obligation = try XCTUnwrap(FundingPlanCalculator.effectiveIncludedObligations(value).first { $0.billID == "card-estimate" })
        XCTAssertEqual(obligation.money, try money("0.00", "INR"))
        XCTAssertEqual(obligation.replacementAdjustmentID, "reviewed-card-need")
        XCTAssertEqual(value.indiaCommitments, original)
    }

    func testReviewedRemainingAmountDeterminesRemittanceAndIsChargedOnlyOnce() throws {
        var value = try plan()
        value.assistance?.datedAdjustments = [try review("300.00")]
        value.balances = [try balance("100.00", accountID: "india-a")]
        let monthly = FundingPlanCalculator.calculate(value)
        XCTAssertEqual(monthly.indiaCommitments, try money("300.00", "INR"))
        XCTAssertEqual(monthly.indiaFundingShortfall, try money("200.00", "INR"))
        XCTAssertEqual(monthly.requiredQARPrincipal, try money("66.67"))
        XCTAssertEqual(monthly.surplusAfterObligations, try money("823.33"))
        let allocation = try calculate(value)
        XCTAssertEqual(allocation.monthlySurplus, try money("823.33"))
        XCTAssertEqual(allocation.remainingByFundingSource["cash:INR"], try money("0.00", "INR"))
        XCTAssertEqual(allocation.remainingByFundingSource["cash:QAR"], try money("823.33"))
        XCTAssertEqual(allocation.plannedUsesByCurrency, [try money("0.00")], "The reviewed mandatory bill is not a second surplus use.")
        XCTAssertEqual(allocation.transferCostsByCurrency, [try money("10.00")])
    }

    func testReviewedAmountConstrainsExactINRAccountCapacity() throws {
        var value = try plan()
        value.assistance?.datedAdjustments = [try review("300.00")]
        value.balances = [try balance("450.00", accountID: "india-a")]
        value.assistance?.surplusAllocation?.investments = [try investment("150.00")]
        let result = try calculate(value)
        XCTAssertEqual(result.monthlySurplus, try money("900.00"))
        XCTAssertEqual(result.remainingByFundingSource["cash:INR"], try money("0.00", "INR"))
        XCTAssertEqual(result.plannedUsesByCurrency, [try money("150.00", "INR"), try money("0.00")])
        value.assistance?.surplusAllocation?.investments[0].amount = try amount("150.01")
        assertAllocationError(.exceedsCapacity, value)
    }

    func testReviewedBankChangeReservesOnlyEffectivePayingAccount() throws {
        var value = try plan()
        value.assistance?.datedAdjustments = [try review("300.00", bank: "india-b")]
        value.balances = [try balance("500.00", accountID: "india-a"), try balance("250.00", accountID: "india-b")]
        value.assistance?.surplusAllocation?.investments = [try investment("450.00")]
        XCTAssertEqual(try calculate(value).remainingByFundingSource["cash:INR"], try money("0.00", "INR"))
        XCTAssertEqual(value.assistance?.billFundingAccounts?["card-estimate"], "india-a")
        let resolved = try XCTUnwrap(FundingPlanCalculator.effectiveIncludedObligations(value).first { $0.billID == "card-estimate" })
        XCTAssertEqual(resolved.fundingAccountID, "india-b")
        value.assistance?.surplusAllocation?.investments = [try investment("0.01", accountID: "india-b")]
        assertAllocationError(.exceedsCapacity, value)
    }

    func testMalformedAndDuplicateReplacementLinksFailClosed() throws {
        let changes: [(String, (inout PlanDatedAdjustment) -> Void)] = [
            ("wrong card", { $0.cardAccountID = "another-card" }),
            ("blank statement", { $0.cardStatementID = "  " }),
            ("missing bill", { $0.replacesCommitmentID = "missing-bill" }),
            ("wrong kind", { $0.kind = .expectedIncome }),
            ("wrong currency", { $0.amount = .init(currency: "QAR", decimal: "1.00") }),
            ("negative amount", { $0.amount = .init(currency: "INR", decimal: "-1.00") }),
            ("malformed amount", { $0.amount = .init(currency: "INR", decimal: "unfinished") }),
            ("invalid date", { $0.date = "2026-11-31" }),
            ("blank paying bank", { $0.accountID = "" })
        ]
        for (label, change) in changes {
            var value = try plan(), adjustment = try review("0.00")
            change(&adjustment)
            value.assistance?.datedAdjustments = [adjustment]
            XCTAssertThrowsError(try FundingPlanCalculator.effectiveIncludedObligations(value), label)
            let result = FundingPlanCalculator.calculate(value)
            XCTAssertNil(result.surplusAfterObligations, label)
            XCTAssertTrue(result.incompleteReasons.contains(.reviewedObligationNeedsReview), label)
            assertAllocationError(.incompletePlan, value)
        }
        var value = try plan(), second = try review("0.00")
        second.id = "duplicate-review"; second.cardStatementID = "another-statement"
        value.assistance?.datedAdjustments = [try review("300.00"), second]
        XCTAssertThrowsError(try FundingPlanCalculator.effectiveIncludedObligations(value))
        second.replacesCommitmentID = nil; second.cardStatementID = "statement-reviewed"
        value.assistance?.datedAdjustments[1] = second
        XCTAssertThrowsError(try FundingPlanCalculator.effectiveIncludedObligations(value))
    }

    func testReplacementBankMustExistAndRemainInPlanningScopeEvenAtZero() throws {
        var value = try plan()
        value.assistance?.datedAdjustments = [try review("0.00", bank: "missing-bank")]
        assertAllocationError(.invalidFundingLink, value)
        value.assistance?.datedAdjustments = [try review("0.00", bank: "india-b")]
        var excluded = preferences; excluded.excludedPlanningAccountIDs = ["india-b"]
        assertAllocationError(.incompletePlan, value, preferences: excluded)
        XCTAssertTrue(FundingPlanCalculator.calculate(value, excludingAccounts: ["india-b"]).incompleteReasons.contains(.reviewedObligationNeedsReview))
        XCTAssertTrue(FundingPlanCalculator.calculate(value, historyOnlyAccountIDs: ["india-b"]).incompleteReasons.contains(.reviewedObligationNeedsReview))
        var closed = accounts
        closed[2] = account("india-b", "INR", closedAt: timestamp)
        assertAllocationError(.incompletePlan, value, accounts: closed)
        var wrongCurrency = accounts
        wrongCurrency[2] = account("india-b", "QAR")
        assertAllocationError(.invalidFundingLink, value, accounts: wrongCurrency)
    }

    func testReviewedReplacementDoesNotBypassUnresolvedActualEvidence() throws {
        var value = try plan(), adjustment = try review("0.00")
        adjustment.transactionIDs = ["exact-actual-link-needing-reconciliation"]
        value.assistance?.datedAdjustments = [adjustment]
        XCTAssertEqual(FundingPlanCalculator.calculate(value).indiaCommitments, try money("0.00", "INR"))
        assertAllocationError(.incompletePlan, value)
    }

    func testLegacyCalculationAndEncodedOriginalBillRemainUnchanged() throws {
        var value = try plan()
        value.assistance?.datedAdjustments = [try review("0.00")]
        let restored = try JSONDecoder().decode(FundingPlan.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored, value)
        XCTAssertEqual(restored.indiaCommitments.first?.money, try money("600.00", "INR"))
        XCTAssertEqual(restored.indiaCommitments.first?.dueDate?.canonical, "2026-11-01")
        XCTAssertEqual(try FundingPlanCalculator.effectiveIncludedObligations(restored), try FundingPlanCalculator.effectiveIncludedObligations(value))
        let dtoRestored = try value.persistenceDTO().allocationCalculationInput()
        XCTAssertEqual(dtoRestored.indiaCommitments, value.indiaCommitments)
        XCTAssertEqual(dtoRestored.assistance, value.assistance)
        value.calculationVersion = .legacy
        XCTAssertEqual(FundingPlanCalculator.calculate(value).indiaCommitments, try money("600.00", "INR"))
        XCTAssertEqual(FundingPlanCalculator.calculate(value).surplusAfterObligations, try money("690.00"))
        XCTAssertEqual(try FundingPlanCalculator.effectiveIncludedObligations(value).first { $0.billID == "card-estimate" }?.money,
                       try money("600.00", "INR"))
    }

    func testNativePlannedUsesDoNotCountTransferPrincipalOrKeepOverlapTwice() throws {
        var value = try plan()
        value.qatarCommitments = []; value.indiaCommitments = []
        value.assistance?.billFundingAccounts = nil
        value.keepInCBQ = try money("100.00")
        let qatarReserve = ReserveDesignation(id: "qatar-reserve", workspaceID: workspace, accountID: "qatar",
            title: "Mechanics cash reserve", kind: .accountCash, target: try amount("1000.00", "QAR"))
        let indiaReserve = ReserveDesignation(id: "india-reserve", workspaceID: workspace, accountID: "india-a",
            title: "Mechanics cash reserve", kind: .accountCash, target: try amount("1000.00"))
        value.assistance?.transfers = [.init(id: "optional-remittance", fromAccountID: "qatar", toAccountID: "india-a",
            sent: try amount("300.00", "QAR"), received: try amount("900.00"), date: "2026-10-26", conversionBasis: "Exact selected planning rate")]
        value.assistance?.surplusAllocation?.keepInCBQDesignationID = qatarReserve.id
        value.assistance?.contributions = [
            .init(designationID: qatarReserve.id, fundingAccountID: "qatar", amount: try amount("180.00", "QAR"), dueDate: "2026-11-01"),
            .init(designationID: indiaReserve.id, fundingAccountID: "india-a", amount: try amount("200.00"), dueDate: "2026-11-01", fundingTransferID: "optional-remittance")
        ]
        value.assistance?.surplusAllocation?.investments = [try investment("500.00", transferID: "optional-remittance")]
        let result = try calculate(value, reserves: [qatarReserve, indiaReserve])
        XCTAssertEqual(result.plannedUsesByCurrency, [try money("700.00", "INR"), try money("180.00")])
        XCTAssertEqual(result.transferCostsByCurrency, [try money("10.00")])
        XCTAssertEqual(result.unallocated, [try money("200.00", "INR"), try money("510.00")])
        XCTAssertEqual(value.keepInCBQ, try money("100.00"))
    }

    func testPlannedUseSummaryIncludesExistingAllowanceAndCostsWithoutPossibleIncome() throws {
        var value = try plan()
        value.qatarCommitments = []; value.indiaCommitments = []
        value.assistance?.billFundingAccounts = nil
        value.keepInCBQ = try money("20.00")
        value.assistance?.allowance = try amount("30.00", "QAR")
        value.assistance?.allowanceAccountID = "qatar"
        value.assistance?.datedAdjustments = [
            .init(id: "additional-cost", accountID: "qatar", kind: .irregularCost, title: "Separate planned cost",
                amount: try amount("40.00", "QAR"), date: "2026-10-27"),
            .init(id: "possible-income", accountID: "qatar", kind: .expectedIncome, title: "Possible separate income",
                amount: try amount("999.00", "QAR"), date: "2026-10-28")
        ]
        let result = try calculate(value)
        XCTAssertEqual(result.monthlySurplus, try money("1000.00"))
        XCTAssertEqual(result.plannedUsesByCurrency, [try money("90.00")])
        XCTAssertEqual(result.unallocated, [try money("0.00", "INR"), try money("910.00")])
        XCTAssertTrue(result.transferCostsByCurrency.isEmpty)
    }

    func testCarriedUpcomingBillRetainsManualAmountWhenLinkedReviewBelongsOutsideItsCycle() throws {
        for remaining in ["0.00", "900.00"] {
            var value = try plan(), older = try review(remaining, bank: "india-b")
            value.indiaCommitments[0].dueDate = try StatementDate(canonical: "2026-09-20")
            value.assistance?.carriedBillDates = ["card-estimate": "2026-11-20"]
            older.date = "2026-10-21"
            value.assistance?.datedAdjustments = [older]
            let original = value
            let obligation = try XCTUnwrap(FundingPlanCalculator.effectiveIncludedObligations(value).first { $0.billID == "card-estimate" })
            XCTAssertEqual(obligation.money, try money("600.00", "INR"))
            XCTAssertEqual(obligation.fundingAccountID, "india-a")
            XCTAssertNil(obligation.replacementAdjustmentID)
            XCTAssertEqual(obligation.staleReplacementAdjustmentID, older.id)
            XCTAssertEqual(FundingPlanCalculator.staleReviewedObligationIDs(in: value), [older.id])
            let monthly = FundingPlanCalculator.calculate(value)
            XCTAssertEqual(monthly.indiaCommitments, try money("600.00", "INR"))
            XCTAssertEqual(monthly.requiredQARPrincipal, try money("200.00"))
            XCTAssertEqual(monthly.surplusAfterObligations, try money("690.00"))
            XCTAssertEqual(monthly.staleReviewedObligationIDs, [older.id])
            if remaining == "0.00" {
                XCTAssertEqual(try calculate(value).monthlySurplus, try money("690.00"))
            } else {
                assertAllocationError(.incompletePlan, value)
            }
            XCTAssertEqual(value, original, "Neither the retained review nor the upcoming manual estimate is rewritten.")
            let restored = try JSONDecoder().decode(FundingPlan.self, from: JSONEncoder().encode(value))
            XCTAssertEqual(restored, original)
            XCTAssertEqual(FundingPlanCalculator.calculate(restored).staleReviewedObligationIDs, [older.id])
        }
    }

    func testCurrentCycleReviewCanPrecedeTheUpcomingBillsDueDate() throws {
        var value = try plan(), current = try review("240.00")
        value.indiaCommitments[0].dueDate = try StatementDate(canonical: "2026-09-20")
        value.assistance?.carriedBillDates = ["card-estimate": "2026-11-20"]
        for date in ["2026-10-25", "2026-11-18", "2026-11-24"] {
            current.date = date
            value.assistance?.datedAdjustments = [current]
            XCTAssertTrue(FundingPlanCalculator.staleReviewedObligationIDs(in: value).isEmpty)
            XCTAssertEqual(FundingPlanCalculator.calculate(value).indiaCommitments, try money("240.00", "INR"))
            XCTAssertEqual(try calculate(value).monthlySurplus, try money("810.00"))
        }
        current.date = "2026-11-25"
        value.assistance?.datedAdjustments = [current]
        XCTAssertEqual(FundingPlanCalculator.staleReviewedObligationIDs(in: value), [current.id])
        XCTAssertEqual(FundingPlanCalculator.calculate(value).indiaCommitments, try money("600.00", "INR"))
        assertAllocationError(.incompletePlan, value)
    }

    func testExplicitOverdueBillAndPlansWithoutSalaryCycleKeepTheirExistingReviewMeaning() throws {
        var value = try plan(), older = try review("240.00")
        value.indiaCommitments[0].dueDate = try StatementDate(canonical: "2026-10-21")
        older.date = "2026-10-21"
        value.assistance?.datedAdjustments = [older]
        XCTAssertTrue(FundingPlanCalculator.staleReviewedObligationIDs(in: value).isEmpty)
        XCTAssertEqual(FundingPlanCalculator.calculate(value).indiaCommitments, try money("240.00", "INR"))
        value.indiaCommitments[0].dueDate = try StatementDate(canonical: "2026-11-20")
        value.assistance?.salaryCycle = nil
        XCTAssertTrue(FundingPlanCalculator.staleReviewedObligationIDs(in: value).isEmpty)
        XCTAssertEqual(FundingPlanCalculator.calculate(value).indiaCommitments, try money("240.00", "INR"))
        value.assistance?.salaryCycle = SalaryFundingCycle.expected(month: value.month)
        value.calculationVersion = .legacy
        XCTAssertTrue(FundingPlanCalculator.staleReviewedObligationIDs(in: value).isEmpty)
        XCTAssertEqual(FundingPlanCalculator.calculate(value).indiaCommitments, try money("600.00", "INR"))
    }

    func testForecastKeepsUpcomingCarriedBillWhenOldReviewStillNamesItsStableID() throws {
        for remaining in ["0.00", "900.00"] {
            var value = try plan(), older = try review(remaining)
            value.indiaCommitments[0].dueDate = try StatementDate(canonical: "2026-09-20")
            value.assistance?.carriedBillDates = ["card-estimate": "2026-11-20"]
            older.date = "2026-10-21"
            value.assistance?.datedAdjustments = [older]
            let projected = try forecast(value)
            let runway = try XCTUnwrap(projected.runways.first { $0.id == "india-a" })
            let bill = try XCTUnwrap(runway.events.first { $0.id == "card-estimate" })
            XCTAssertEqual(bill.date.canonical, "2026-11-20")
            XCTAssertEqual(bill.change, -600)
            XCTAssertEqual(bill.kind, .commitment)
            XCTAssertFalse(runway.events.contains { $0.id == older.id })
            XCTAssertEqual(projected.plannedCommitments["INR"], 600)
            XCTAssertTrue(projected.cardNeeds.contains { $0.contains("outside this salary cycle") && $0.contains("worksheet amount is retained") })
            XCTAssertFalse(projected.cardNeeds.contains { $0.localizedCaseInsensitiveContains("paid") },
                "A mismatched review date does not establish settlement.")
        }
    }

    func testExplicitZeroSeparateCashNeedLeavesUpcomingBillAndAllocationCapacityIntact() throws {
        var value = try plan(), settled = try review("0.00", replaces: nil)
        value.indiaCommitments[0].dueDate = try StatementDate(canonical: "2026-09-20")
        value.assistance?.carriedBillDates = ["card-estimate": "2026-11-20"]
        settled.date = "2026-10-21"
        value.assistance?.datedAdjustments = [settled]
        let original = value
        XCTAssertTrue(FundingPlanCalculator.staleReviewedObligationIDs(in: value).isEmpty)
        XCTAssertEqual(FundingPlanCalculator.calculate(value).indiaCommitments, try money("600.00", "INR"))
        XCTAssertEqual(try calculate(value).monthlySurplus, try money("690.00"),
            "A zero separate cost does not need an included INR balance merely to consume zero.")
        let projected = try forecast(value)
        XCTAssertEqual(projected.runways.first?.events.first { $0.id == "card-estimate" }?.change, -600)
        XCTAssertFalse(projected.runways.flatMap(\.events).contains { $0.id == settled.id })
        XCTAssertTrue(projected.cardNeeds.isEmpty)
        XCTAssertEqual(value, original)
    }

    func testStaleZeroReviewDoesNotBypassUnresolvedActualEvidence() throws {
        var value = try plan(), older = try review("0.00")
        value.assistance?.carriedBillDates = ["card-estimate": "2026-11-20"]
        older.date = "2026-10-21"
        older.transactionIDs = ["actual-link-still-needing-review"]
        value.assistance?.datedAdjustments = [older]
        XCTAssertEqual(FundingPlanCalculator.calculate(value).indiaCommitments, try money("600.00", "INR"))
        assertAllocationError(.incompletePlan, value)
    }
}
