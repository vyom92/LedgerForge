import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct SalaryParserAndPlannerTests {
    @Test func plannerArithmeticCompletenessRoundingFeeAndNegativeBuffers() throws {
        let qar = try CurrencyCode("QAR"), inr = try CurrencyCode("INR")
        var plan = Self.plan(
            fixed: try Money(amount: 100, currency: qar),
            variable: try Money(amount: 20, currency: qar),
            deductions: try Money(amount: 10, currency: qar)
        )
        plan.balances = [
            FundingPlanBalance(id: "q", accountID: "cbq", nativeCurrency: qar, included: true, money: try Money(amount: 50, currency: qar), provenance: .manual),
            FundingPlanBalance(id: "i", accountID: "axis", nativeCurrency: inr, included: true, money: try Money(amount: 50, currency: inr), provenance: .manual)
        ]
        plan.qatarCommitments = [FundingPlanCommitment(id: "qc", label: "Rent", money: try Money(amount: 10, currency: qar), included: true, fundingAccountID: nil, provenance: .manual)]
        plan.indiaCommitments = [FundingPlanCommitment(id: "ic", label: "India", money: try Money(amount: 100, currency: inr), included: true, fundingAccountID: "axis", provenance: .manual)]
        plan.planningFX = try FundingPlanFX(inrPerQAR: 3, observationDate: StatementDate(year: 2026, month: 8, day: 28))
        plan.plannedInvestment = try Money(amount: 120, currency: qar)
        let result = FundingPlanCalculator.calculate(plan)
        #expect(result.expectedNet?.amount == 110)
        #expect(result.indiaFundingShortfall?.amount == 50)
        #expect(try result.requiredQARPrincipal?.canonicalDecimalString() == "16.67")
        #expect(result.effectiveTransferFee?.amount == 25)
        #expect(result.availableForInvestment?.amount == 108.33)
        #expect(result.finalQARBuffer?.amount == -11.67)
    }

    @Test func missingIncludedBalanceAndMissingRequiredFXAreIncompleteButNoShortfallNeedsNoFX() throws {
        let qar = try CurrencyCode("QAR"), inr = try CurrencyCode("INR")
        var plan = Self.plan()
        plan.balances = [FundingPlanBalance(id: "missing", accountID: "cbq", nativeCurrency: qar, included: true, money: nil, provenance: .manual)]
        #expect(FundingPlanCalculator.calculate(plan).incompleteReasons.contains(.includedQARBalanceMissing))
        plan.balances = [
            FundingPlanBalance(id: "q", accountID: "cbq", nativeCurrency: qar, included: true, money: try Money(amount: 100, currency: qar), provenance: .manual),
            FundingPlanBalance(id: "i", accountID: "axis", nativeCurrency: inr, included: true, money: try Money(amount: 0, currency: inr), provenance: .manual)
        ]
        plan.indiaCommitments = [FundingPlanCommitment(id: "i", label: "India", money: try Money(amount: 1, currency: inr), included: true, fundingAccountID: nil, provenance: .manual)]
        #expect(FundingPlanCalculator.calculate(plan).incompleteReasons.contains(.missingPlanningFX))
        plan.indiaCommitments = []
        let noShortfall = FundingPlanCalculator.calculate(plan)
        #expect(noShortfall.requiredQARPrincipal?.amount == 0)
        #expect(noShortfall.effectiveTransferFee?.amount == 0)
        #expect(plan.configuredTransferFee.amount == 25)
    }

    @Test func selectedLiquiditySumsNativelyAndZeroShortfallSuppressesOnlyEffectiveFee() throws {
        let qar = try CurrencyCode("QAR"), inr = try CurrencyCode("INR")
        var plan = Self.plan()
        plan.balances = [
            FundingPlanBalance(id: "q1", accountID: "cbq-1", nativeCurrency: qar, included: true, money: try Money(amount: 10, currency: qar), provenance: .manual),
            FundingPlanBalance(id: "q2", accountID: "cbq-2", nativeCurrency: qar, included: true, money: try Money(amount: 15, currency: qar), provenance: .manual),
            FundingPlanBalance(id: "i1", accountID: "axis", nativeCurrency: inr, included: true, money: try Money(amount: 100, currency: inr), provenance: .manual),
            FundingPlanBalance(id: "i2", accountID: "hdfc", nativeCurrency: inr, included: true, money: try Money(amount: 50, currency: inr), provenance: .manual)
        ]
        plan.indiaCommitments = [FundingPlanCommitment(id: "i", label: "India", money: try Money(amount: 150, currency: inr), included: true, fundingAccountID: nil, provenance: .manual)]
        let equal = FundingPlanCalculator.calculate(plan)
        #expect(equal.selectedQARLiquidity?.amount == 25)
        #expect(equal.selectedINRLiquidity?.amount == 150)
        #expect(equal.indiaFundingShortfall?.amount == 0)
        #expect(equal.effectiveTransferFee?.amount == 0)
        #expect(plan.configuredTransferFee.amount == 25)
        plan.balances[2].money = try Money(amount: 200, currency: inr)
        #expect(FundingPlanCalculator.calculate(plan).indiaFundingShortfall?.amount == 0)
        #expect(throws: FundingPlanFX.ValidationError.nonPositive) {
            try FundingPlanFX(inrPerQAR: 0, observationDate: StatementDate(year: 2026, month: 8, day: 28))
        }
    }

    @Test func noBalanceIsAutoSelectedAndCaptureIsNotLiveLinked() throws {
        let plan = Self.plan()
        #expect(plan.balances.isEmpty)
        let qar = try CurrencyCode("QAR")
        let captured = FundingPlanBalance(id: "x", accountID: "cbq", nativeCurrency: qar, included: false, money: try Money(amount: 80, currency: qar), provenance: .capturedAccountBalance(capturedAtISO: "2026-08-28T00:00:00Z"))
        var changedAccountValue = try Money(amount: 100, currency: qar)
        #expect(captured.money?.amount == 80)
        changedAccountValue = try Money(amount: 120, currency: qar)
        #expect(changedAccountValue.amount == 120)
        #expect(captured.money?.amount == 80)
    }

    @Test func salaryNavigationEligibilityAndExplicitRolloverRemainUserControlled() throws {
        #expect(AppShellSection.ordinaryNavigation == [.dashboard, .accounts, .transactions, .imports, .salary, .settings])
        let accounts = AccountStore()
        accounts.installAccountsWithoutObservation([
            Account(repositoryAccountId: "cbq", workspaceId: "w", institution: Institution.cbq.rawValue, name: "Current", type: .bank, currencyCode: "QAR", currentBalance: 100),
            Account(repositoryAccountId: "axis-nre", workspaceId: "w", institution: Institution.axis.rawValue, name: "Axis NRE", type: .bank, currencyCode: "INR", currentBalance: 200),
            Account(repositoryAccountId: "axis-other", workspaceId: "w", institution: Institution.axis.rawValue, name: "Axis Savings", type: .bank, currencyCode: "INR", currentBalance: 300),
            Account(repositoryAccountId: "card", workspaceId: "w", institution: Institution.cbq.rawValue, name: "Card", type: .creditCard, currencyCode: "QAR", currentBalance: 400)
        ])
        let plans = FundingPlanStore()
        let previous = Self.plan(month: try SelectedStatementMonth(year: 2026, month: 7), id: "previous")
        plans.installWithoutObservation([previous], generation: DatabaseProvider.shared.generationToken)
        let viewModel = SalaryWorkspaceViewModel(month: try SelectedStatementMonth(year: 2026, month: 8), workspaceID: "default-workspace", accountStore: accounts, salaryStore: SalaryStore(), fundingPlanStore: plans)
        #expect(viewModel.eligibleAccounts.compactMap(\.repositoryAccountId) == ["axis-nre", "cbq"])
        #expect(viewModel.plan.balances.isEmpty)
        viewModel.rolloverFromPreviousPlan()
        #expect(viewModel.plan.rolloverSourcePlanID == "previous")
        #expect(viewModel.plan.expectedFixedProvenance == .carried(sourcePlanID: "previous"))
        #expect(viewModel.updateMoney(.fixed, text: "123.00"))
        #expect(viewModel.plan.expectedFixedProvenance == .manual)
        #expect(previous.expectedFixedEarnings.amount == 0)
    }

    private static func plan(fixed: Money? = nil, variable: Money? = nil, deductions: Money? = nil,
                             month: SelectedStatementMonth? = nil,
                             id: String = "plan") -> FundingPlan {
        let zero = try! Money(canonicalDecimal: "0.00", currency: "QAR")
        let resolvedMonth = month ?? (try! SelectedStatementMonth(year: 2026, month: 8))
        return FundingPlan(id: id, workspaceID: "default-workspace", month: resolvedMonth, rolloverSourcePlanID: nil,
                           expectedFixedEarnings: fixed ?? zero, expectedFixedProvenance: .manual,
                           expectedVariableEarnings: variable ?? zero, expectedVariableProvenance: .manual,
                           expectedDeductions: deductions ?? zero, expectedDeductionsProvenance: .manual,
                           balances: [], qatarCommitments: [], indiaCommitments: [],
                           configuredTransferFee: try! Money(canonicalDecimal: "25.00", currency: "QAR"), configuredTransferFeeProvenance: .manual,
                           planningFX: nil, plannedInvestment: zero, plannedInvestmentProvenance: .manual, updatedAtISO: "2026-08-28T00:00:00Z")
    }

}
