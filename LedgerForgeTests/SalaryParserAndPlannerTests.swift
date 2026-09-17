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
        #expect(AppShellSection.ordinaryNavigation == [.dashboard, .accounts, .investments, .salary, .transactions, .imports, .settings])
        let accounts = AccountStore()
        accounts.installAccountsWithoutObservation([
            Account(repositoryAccountId: "cbq", workspaceId: "w", institution: Institution.cbq.rawValue, name: "Current", type: .bank, currencyCode: "QAR", currentBalance: 100),
            Account(repositoryAccountId: "axis-nre", workspaceId: "w", institution: Institution.axis.rawValue, name: "Axis NRE", type: .bank, currencyCode: "INR", currentBalance: 200),
            Account(repositoryAccountId: "axis-other", workspaceId: "w", institution: Institution.axis.rawValue, name: "Axis Savings", type: .bank, currencyCode: "INR", currentBalance: 300),
            Account(repositoryAccountId: "card", workspaceId: "w", institution: Institution.cbq.rawValue, name: "Card", type: .creditCard, currencyCode: "QAR", currentBalance: 400)
        ])
        let plans = FundingPlanStore()
        let previous = Self.plan(month: try SelectedStatementMonth(year: 2026, month: 9), id: "previous")
        plans.installWithoutObservation([previous], generation: DatabaseProvider.shared.generationToken)
        let viewModel = SalaryWorkspaceViewModel(month: try SelectedStatementMonth(year: 2026, month: 10), workspaceID: "default-workspace", accountStore: accounts, salaryStore: SalaryStore(), fundingPlanStore: plans)
        #expect(viewModel.eligibleAccounts.compactMap(\.repositoryAccountId) == ["axis-nre", "axis-other", "cbq"])
        #expect(viewModel.plan.balances.isEmpty)
        viewModel.rolloverFromPreviousPlan()
        #expect(viewModel.plan.rolloverSourcePlanID == "previous")
        #expect(viewModel.plan.expectedFixedProvenance == .carried(sourcePlanID: "previous"))
        #expect(viewModel.updateMoney(.fixed, text: "123.00"))
        #expect(viewModel.plan.expectedFixedProvenance == .manual)
        #expect(previous.expectedFixedEarnings.amount == 0)
    }

    @Test func plannerEligibilityIgnoresDisplayNameAndNickname() throws {
        // Source-independent account-metadata checks; no statement or balance evidence is asserted.
        let initial = [
            Account(repositoryAccountId: "axis", institution: Institution.axis.rawValue, name: "NRE", type: .bank, currencyCode: "INR"),
            Account(repositoryAccountId: "hdfc", institution: Institution.hdfc.rawValue, name: "NRO", type: .bank, currencyCode: "INR"),
            Account(repositoryAccountId: "cbq", institution: Institution.cbq.rawValue, name: "Current", type: .bank, currencyCode: "QAR"),
            Account(repositoryAccountId: "inr-card", institution: Institution.axis.rawValue, name: "Card", type: .creditCard, currencyCode: "INR"),
            Account(repositoryAccountId: "qar-card", institution: Institution.cbq.rawValue, name: "Card", type: .creditCard, currencyCode: "QAR")
        ]
        let accounts = AccountStore()
        accounts.installAccountsWithoutObservation(initial)
        let viewModel = SalaryWorkspaceViewModel(accountStore: accounts, salaryStore: SalaryStore(), fundingPlanStore: FundingPlanStore())
        let expectedIDs: Set<String> = ["axis", "hdfc", "cbq"]
        let expectedCardIDs: Set<String> = ["inr-card", "qar-card"]
        #expect(Set(viewModel.eligibleAccounts.compactMap(\.repositoryAccountId)) == expectedIDs)
        #expect(Set(viewModel.eligibleCommitmentAccounts.compactMap(\.repositoryAccountId)) == expectedCardIDs)

        for (name, nickname) in [("Everyday funds", nil), ("Travel USD card", "Reserve"), ("NRE", "NRO")] as [(String, String?)] {
            accounts.installAccountsWithoutObservation(initial.map { account in
                var renamed = account
                renamed.name = name
                renamed.nickname = nickname
                return renamed
            })
            #expect(Set(viewModel.eligibleAccounts.compactMap(\.repositoryAccountId)) == expectedIDs)
            #expect(Set(viewModel.eligibleCommitmentAccounts.compactMap(\.repositoryAccountId)) == expectedCardIDs)
            #expect(viewModel.plan.balances.isEmpty)
        }
    }

    @Test func plannerEligibilityUsesNativeCurrencyAndAccountRoleWithoutInstitutionRestrictions() throws {
        let accounts = AccountStore()
        var candidates = [
            Account(repositoryAccountId: "axis", institution: Institution.axis.rawValue, name: "Axis Bank INR", type: .bank, currencyCode: "INR"),
            Account(repositoryAccountId: "hdfc", institution: Institution.hdfc.rawValue, name: "HDFC Bank INR", type: .bank, currencyCode: "INR"),
            Account(repositoryAccountId: "cbq", institution: Institution.cbq.rawValue, name: "CBQ Bank QAR", type: .bank, currencyCode: "QAR"),
            Account(institution: Institution.axis.rawValue, name: "NRE", type: .bank, currencyCode: "INR"),
            Account(repositoryAccountId: "", institution: Institution.axis.rawValue, name: "NRE", type: .bank, currencyCode: "INR"),
            Account(repositoryAccountId: "archived", institution: Institution.axis.rawValue, name: "NRE", type: .bank, currencyCode: "INR", status: .archived),
            Account(repositoryAccountId: "closed", institution: Institution.cbq.rawValue, name: "Current", type: .bank, currencyCode: "QAR", status: .closed),
            Account(repositoryAccountId: "unsupported-currency", institution: Institution.axis.rawValue, name: "NRE INR", type: .bank, currencyCode: "USD"),
            Account(repositoryAccountId: "other-bank", institution: "Other institution", name: "Everyday", type: .bank, currencyCode: "QAR"),
            Account(repositoryAccountId: "other-card", institution: "Other institution", name: "Everyday", type: .creditCard, currencyCode: "INR"),
            Account(repositoryAccountId: "closed-card", institution: Institution.cbq.rawValue, name: "Current", type: .creditCard, currencyCode: "QAR", status: .closed),
            Account(repositoryAccountId: "usd-card", institution: Institution.cbq.rawValue, name: "QAR card", type: .creditCard, currencyCode: "USD"),
            Account(repositoryAccountId: "", institution: Institution.cbq.rawValue, name: "QAR card", type: .creditCard, currencyCode: "QAR"),
            Account(institution: Institution.cbq.rawValue, name: "QAR card", type: .creditCard, currencyCode: "QAR")
        ]
        for (institution, currency) in [(Institution.axis, "INR"), (.hdfc, "INR"), (.cbq, "QAR")] {
            for type in [AccountType.creditCard, .investment, .cash, .loan] {
                candidates.append(Account(repositoryAccountId: "\(institution.rawValue)-\(type.rawValue)", institution: institution.rawValue,
                                          name: "NRE NRO Bank", nickname: "Current", type: type, currencyCode: currency))
            }
        }
        accounts.installAccountsWithoutObservation(candidates)
        let viewModel = SalaryWorkspaceViewModel(accountStore: accounts, salaryStore: SalaryStore(), fundingPlanStore: FundingPlanStore())
        #expect(Set(viewModel.eligibleAccounts.compactMap(\.repositoryAccountId)) == ["axis", "hdfc", "cbq", "other-bank"])
        #expect(Set(viewModel.eligibleCommitmentAccounts.compactMap(\.repositoryAccountId)) == [
            "other-card", "\(Institution.axis.rawValue)-creditCard", "\(Institution.hdfc.rawValue)-creditCard", "\(Institution.cbq.rawValue)-creditCard"
        ])
        #expect(viewModel.plan.balances.isEmpty)
    }

    @Test func manualCardCommitmentLinkHydratesWithoutChangingAmountOrLegacyBankLink() throws {
        // Isolated metadata and ordinary manual planning input only; no imported financial graph.
        let sqlite = try SQLiteRepositoryProvider(path: ":memory:")
        defer { sqlite.database.close() }
        let active = DatabaseProvider(workspaceRepo: sqlite.workspaceRepo, transactionRepo: sqlite.transactionRepo,
            accountRepo: sqlite.accountRepo, importSessionRepo: sqlite.importSessionRepo, fundingPlanRepo: sqlite.fundingPlanRepo)
        let workspace = "default-workspace"
        _ = try sqlite.workspaceRepo.upsertWorkspace(WorkspaceDTO(id: workspace, name: "Planner input", createdAtISO: "2026-09-15T00:00:00Z"))
        for (id, type, currency) in [("bank", "bank", "QAR"), ("qar-card", "credit_card", "QAR"), ("inr-card", "credit_card", "INR")] {
            _ = try sqlite.accountRepo.upsertAccount(AccountDTO(id: id, workspaceId: workspace, name: id,
                institutionId: "Other institution", accountType: type, nativeCurrency: currency, createdAtISO: "2026-09-15T00:00:00Z"))
        }
        let accounts = AccountStore(), plans = FundingPlanStore()
        let hydrator = RepositoryStoreHydrator(accountRepo: active.accountRepo, importSessionRepo: active.importSessionRepo,
            transactionRepo: active.transactionRepo, fundingPlanRepo: active.fundingPlanRepo,
            accountStore: accounts, transactionStore: TransactionStore(), categoryStore: CategoryStore(), cardStore: CardStore(),
            salaryStore: SalaryStore(), fundingPlanStore: plans, importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
            providerGeneration: active.generationToken, participatesInLifecycleGate: false)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        let month = try SelectedStatementMonth(canonical: "2026-09")
        let viewModel = SalaryWorkspaceViewModel(month: month, provider: { active }, accountStore: accounts,
            salaryStore: SalaryStore(), fundingPlanStore: plans, locale: Locale(identifier: "en_US_POSIX"),
            refresh: { _ in _ = try hydrator.hydrateIfNeeded(forceRefresh: true) })
        #expect(viewModel.eligibleAccounts.compactMap(\.repositoryAccountId) == ["bank"])
        #expect(viewModel.eligibleCommitmentAccounts.filter { $0.nativeCurrency.code == "QAR" }.compactMap(\.repositoryAccountId) == ["qar-card"])
        #expect(viewModel.eligibleCommitmentAccounts.filter { $0.nativeCurrency.code == "INR" }.compactMap(\.repositoryAccountId) == ["inr-card"])

        viewModel.addCommitment(region: "qatar")
        let cardRow = try #require(viewModel.plan.qatarCommitments.first?.id)
        viewModel.updateCommitment(region: "qatar", id: cardRow, label: "Manual payment", amountText: "12.34", included: true, fundingAccountID: nil)
        let amount = try #require(viewModel.plan.qatarCommitments.first?.money)
        let calculation = viewModel.calculation
        viewModel.editCommitment(region: "qatar", id: cardRow, field: "account", text: "qar-card")
        #expect(viewModel.plan.qatarCommitments.first?.money == amount)
        #expect(viewModel.calculation == calculation)
        #expect(viewModel.plan.qatarCommitments.first?.provenance == .manual)

        viewModel.addCommitment(region: "qatar")
        let bankRow = try #require(viewModel.plan.qatarCommitments.last?.id)
        viewModel.updateCommitment(region: "qatar", id: bankRow, label: "Existing bank routing", amountText: "5", included: true, fundingAccountID: "bank")
        viewModel.save()
        #expect(viewModel.saveState == .saved)
        let reloaded = try #require(plans.plan(for: month, workspaceID: workspace))
        #expect(reloaded.qatarCommitments.first { $0.id == cardRow }?.fundingAccountID == "qar-card")
        #expect(reloaded.qatarCommitments.first { $0.id == cardRow }?.money == amount)
        #expect(reloaded.qatarCommitments.first { $0.id == bankRow }?.fundingAccountID == "bank")
        #expect(viewModel.retainedCommitmentAccountLabel(id: "bank") == "Saved funding bank · bank")
        #expect(viewModel.plan.balances.isEmpty)
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
