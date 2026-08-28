import Combine
import Foundation

@MainActor
final class SalaryWorkspaceViewModel: ObservableObject {
    enum MoneyField { case fixed, variable, deductions, fee, investment }

    @Published private(set) var plan: FundingPlan
    @Published private(set) var calculation: FundingPlanCalculation
    @Published private(set) var errorMessage: String?

    private let month: SelectedStatementMonth
    private let workspaceID: String
    private let provider: () -> DatabaseProvider
    private let accountStore: AccountStore
    private let salaryStore: SalaryStore
    private let fundingPlanStore: FundingPlanStore

    init(
        month: SelectedStatementMonth? = nil,
        workspaceID: String = "default-workspace",
        provider: (() -> DatabaseProvider)? = nil,
        accountStore: AccountStore? = nil,
        salaryStore: SalaryStore? = nil,
        fundingPlanStore: FundingPlanStore? = nil
    ) {
        let resolvedMonth = month ?? Self.currentMonth()
        let resolvedAccountStore = accountStore ?? .shared
        let resolvedSalaryStore = salaryStore ?? .shared
        let resolvedFundingPlanStore = fundingPlanStore ?? .shared
        self.month = resolvedMonth
        self.workspaceID = workspaceID
        self.provider = provider ?? { DatabaseProvider.shared }
        self.accountStore = resolvedAccountStore
        self.salaryStore = resolvedSalaryStore
        self.fundingPlanStore = resolvedFundingPlanStore
        let initial = resolvedFundingPlanStore.plan(for: resolvedMonth, workspaceID: workspaceID) ?? Self.emptyPlan(month: resolvedMonth, workspaceID: workspaceID)
        self.plan = initial
        self.calculation = FundingPlanCalculator.calculate(initial)
    }

    var statements: [SalaryStatement] { salaryStore.statements }
    var eligibleAccounts: [Account] {
        accountStore.accounts.filter(Self.isEligibleAccount).sorted { ($0.nativeCurrency.code, $0.name, $0.repositoryAccountId ?? "") < ($1.nativeCurrency.code, $1.name, $1.repositoryAccountId ?? "") }
    }

    var currentMonthActual: Money? {
        let values = statements.filter { $0.workspaceID == workspaceID && $0.evidence.financialPeriod == month }.map { $0.evidence.printedPaymentTotal }
        guard !values.isEmpty else { return nil }
        return try? Money.aggregate(values)
    }

    var historyGroups: [(month: SelectedStatementMonth, statements: [SalaryStatement], actual: Money)] {
        Dictionary(grouping: statements.filter { $0.workspaceID == workspaceID }, by: { $0.evidence.financialPeriod })
            .compactMap { period, values in
                guard let total = try? Money.aggregate(values.map { $0.evidence.printedPaymentTotal }) else { return nil }
                return (period, values.sorted { ($0.importedAtISO, $0.id) < ($1.importedAtISO, $1.id) }, total)
            }
            .sorted { $0.month > $1.month }
    }

    func moneyText(_ field: MoneyField) -> String {
        let money: Money
        switch field {
        case .fixed: money = plan.expectedFixedEarnings
        case .variable: money = plan.expectedVariableEarnings
        case .deductions: money = plan.expectedDeductions
        case .fee: money = plan.configuredTransferFee
        case .investment: money = plan.plannedInvestment
        }
        return (try? money.canonicalDecimalString()) ?? ""
    }

    @discardableResult
    func updateMoney(_ field: MoneyField, text: String) -> Bool {
        guard let value = try? Money(canonicalDecimal: text, currency: "QAR") else {
            errorMessage = "Enter an exact QAR amount with no more than two decimal places."
            return false
        }
        switch field {
        case .fixed: plan.expectedFixedEarnings = value; plan.expectedFixedProvenance = .manual
        case .variable: plan.expectedVariableEarnings = value; plan.expectedVariableProvenance = .manual
        case .deductions: plan.expectedDeductions = value; plan.expectedDeductionsProvenance = .manual
        case .fee: plan.configuredTransferFee = value; plan.configuredTransferFeeProvenance = .manual
        case .investment: plan.plannedInvestment = value; plan.plannedInvestmentProvenance = .manual
        }
        recalculate()
        return true
    }

    func setFX(rateText: String, dateText: String) {
        if rateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && dateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            plan.planningFX = nil
            recalculate()
            return
        }
        guard let rate = Decimal(string: rateText, locale: Locale(identifier: "en_US_POSIX")),
              let date = try? StatementDate(canonical: dateText),
              let fx = try? FundingPlanFX(inrPerQAR: rate, observationDate: date) else {
            errorMessage = "Enter a positive INR-per-QAR rate and an observation date as YYYY-MM-DD."
            return
        }
        plan.planningFX = fx
        recalculate()
    }

    func setAccountIncluded(_ account: Account, included: Bool) {
        guard let id = account.repositoryAccountId else { return }
        if let index = plan.balances.firstIndex(where: { $0.accountID == id }) {
            plan.balances[index].included = included
        } else {
            plan.balances.append(FundingPlanBalance(id: UUID().uuidString, accountID: id, nativeCurrency: account.nativeCurrency, included: included, money: nil, provenance: .manual))
        }
        recalculate()
    }

    func captureAccountBalance(_ account: Account) {
        guard let id = account.repositoryAccountId else { return }
        let capturedAt = ISO8601DateFormatter().string(from: Date())
        if let index = plan.balances.firstIndex(where: { $0.accountID == id }) {
            plan.balances[index].money = account.currentBalanceMoney
            plan.balances[index].provenance = .capturedAccountBalance(capturedAtISO: capturedAt)
        } else {
            plan.balances.append(FundingPlanBalance(id: UUID().uuidString, accountID: id, nativeCurrency: account.nativeCurrency, included: false, money: account.currentBalanceMoney, provenance: .capturedAccountBalance(capturedAtISO: capturedAt)))
        }
        recalculate()
    }

    func setManualBalance(_ account: Account, text: String) {
        guard let id = account.repositoryAccountId,
              let money = try? Money(canonicalDecimal: text, currency: account.nativeCurrency.code) else {
            errorMessage = "Enter an exact amount in the account's native currency."
            return
        }
        if let index = plan.balances.firstIndex(where: { $0.accountID == id }) {
            plan.balances[index].money = money
            plan.balances[index].provenance = .manual
        } else {
            plan.balances.append(FundingPlanBalance(id: UUID().uuidString, accountID: id, nativeCurrency: account.nativeCurrency, included: false, money: money, provenance: .manual))
        }
        recalculate()
    }

    func addCommitment(region: String) {
        let currency = region == "qatar" ? "QAR" : "INR"
        guard let zero = try? Money(canonicalDecimal: "0.00", currency: currency) else { return }
        let value = FundingPlanCommitment(id: UUID().uuidString, label: "New commitment", money: zero, included: true, fundingAccountID: nil, provenance: .manual)
        if region == "qatar" { plan.qatarCommitments.append(value) }
        else { plan.indiaCommitments.append(value) }
        recalculate()
    }

    func updateCommitment(region: String, id: String, label: String, amountText: String, included: Bool, fundingAccountID: String?) {
        let currency = region == "qatar" ? "QAR" : "INR"
        guard let money = try? Money(canonicalDecimal: amountText, currency: currency) else {
            errorMessage = "Enter an exact \(currency) commitment amount."
            return
        }
        var values = region == "qatar" ? plan.qatarCommitments : plan.indiaCommitments
        guard let index = values.firstIndex(where: { $0.id == id }) else { return }
        values[index].label = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Commitment" : label
        values[index].money = money
        values[index].included = included
        values[index].fundingAccountID = fundingAccountID
        values[index].provenance = .manual
        if region == "qatar" { plan.qatarCommitments = values } else { plan.indiaCommitments = values }
        recalculate()
    }

    func removeCommitment(region: String, id: String) {
        if region == "qatar" { plan.qatarCommitments.removeAll { $0.id == id } }
        else { plan.indiaCommitments.removeAll { $0.id == id } }
        recalculate()
    }

    func rolloverFromPreviousPlan() {
        guard fundingPlanStore.plan(for: month, workspaceID: workspaceID) == nil,
              let previous = fundingPlanStore.plans.filter({ $0.workspaceID == workspaceID && $0.month < month }).max(by: { $0.month < $1.month }) else {
            errorMessage = "No earlier editable plan is available to roll forward, or this month already exists."
            return
        }
        let source = previous.id
        plan = FundingPlan(
            id: UUID().uuidString,
            workspaceID: workspaceID,
            month: month,
            rolloverSourcePlanID: source,
            expectedFixedEarnings: previous.expectedFixedEarnings,
            expectedFixedProvenance: .carried(sourcePlanID: source),
            expectedVariableEarnings: previous.expectedVariableEarnings,
            expectedVariableProvenance: .carried(sourcePlanID: source),
            expectedDeductions: previous.expectedDeductions,
            expectedDeductionsProvenance: .carried(sourcePlanID: source),
            balances: previous.balances.map { FundingPlanBalance(id: UUID().uuidString, accountID: $0.accountID, nativeCurrency: $0.nativeCurrency, included: $0.included, money: $0.money, provenance: .carried(sourcePlanID: source)) },
            qatarCommitments: previous.qatarCommitments.map { FundingPlanCommitment(id: UUID().uuidString, label: $0.label, money: $0.money, included: $0.included, fundingAccountID: $0.fundingAccountID, provenance: .carried(sourcePlanID: source)) },
            indiaCommitments: previous.indiaCommitments.map { FundingPlanCommitment(id: UUID().uuidString, label: $0.label, money: $0.money, included: $0.included, fundingAccountID: $0.fundingAccountID, provenance: .carried(sourcePlanID: source)) },
            configuredTransferFee: previous.configuredTransferFee,
            configuredTransferFeeProvenance: .carried(sourcePlanID: source),
            planningFX: previous.planningFX,
            plannedInvestment: previous.plannedInvestment,
            plannedInvestmentProvenance: .carried(sourcePlanID: source),
            updatedAtISO: ISO8601DateFormatter().string(from: Date())
        )
        recalculate()
    }

    func save() {
        do {
            let activeProvider = provider()
            plan.updatedAtISO = ISO8601DateFormatter().string(from: Date())
            _ = try activeProvider.fundingPlanRepo.savePlan(try Self.dto(from: plan))
            _ = try RepositoryStoreHydrator(databaseProvider: activeProvider).hydrateIfNeeded(forceRefresh: true)
            if let canonical = fundingPlanStore.plan(for: month, workspaceID: workspaceID) { plan = canonical }
            recalculate()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() { errorMessage = nil }

    private func recalculate() { calculation = FundingPlanCalculator.calculate(plan) }

    private static func currentMonth(now: Date = Date()) -> SelectedStatementMonth {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: now)
        return try! SelectedStatementMonth(year: parts.year!, month: parts.month!)
    }

    private static func emptyPlan(month: SelectedStatementMonth, workspaceID: String) -> FundingPlan {
        let zero = try! Money(canonicalDecimal: "0.00", currency: "QAR")
        let fee = try! Money(canonicalDecimal: "25.00", currency: "QAR")
        return FundingPlan(id: UUID().uuidString, workspaceID: workspaceID, month: month, rolloverSourcePlanID: nil,
                           expectedFixedEarnings: zero, expectedFixedProvenance: .manual,
                           expectedVariableEarnings: zero, expectedVariableProvenance: .manual,
                           expectedDeductions: zero, expectedDeductionsProvenance: .manual,
                           balances: [], qatarCommitments: [], indiaCommitments: [],
                           configuredTransferFee: fee, configuredTransferFeeProvenance: .manual,
                           planningFX: nil, plannedInvestment: zero, plannedInvestmentProvenance: .manual,
                           updatedAtISO: ISO8601DateFormatter().string(from: Date()))
    }

    private static func isEligibleAccount(_ account: Account) -> Bool {
        guard account.status == .active, account.type == .bank, account.repositoryAccountId != nil else { return false }
        if account.nativeCurrency.code == "QAR" { return account.institution == Institution.cbq.rawValue }
        guard account.nativeCurrency.code == "INR", [Institution.axis.rawValue, Institution.hdfc.rawValue].contains(account.institution) else { return false }
        let name = "\(account.name) \(account.nickname ?? "")".uppercased()
        return name.contains("NRE") || name.contains("NRO")
    }

    private static func dto(from plan: FundingPlan) throws -> FundingPlanDTO {
        func provenance(_ value: FundingPlanValueProvenance) -> (code: String, carried: String?, captured: String?) {
            switch value {
            case .manual: return ("manual", nil, nil)
            case .carried(let source): return ("carried", source, nil)
            case .capturedAccountBalance(let time): return ("captured_account_balance", nil, time)
            }
        }
        func amount(_ money: Money) throws -> (Int64, String) { (try money.minorUnits(), try money.canonicalDecimalString()) }
        let fixed = try amount(plan.expectedFixedEarnings), variable = try amount(plan.expectedVariableEarnings)
        let deductions = try amount(plan.expectedDeductions), fee = try amount(plan.configuredTransferFee)
        let investment = try amount(plan.plannedInvestment)
        let balances = try plan.balances.enumerated().map { index, value -> FundingPlanBalanceDTO in
            let p = provenance(value.provenance)
            return FundingPlanBalanceDTO(id: value.id, planId: plan.id, sourceOrdinal: index + 1, accountId: value.accountID, nativeCurrency: value.nativeCurrency.code, included: value.included,
                                         amountCurrency: value.money?.currency.code, amountMinor: try value.money?.minorUnits(), amountDecimal: try value.money?.canonicalDecimalString(),
                                         provenanceCode: p.code, carriedSourcePlanId: p.carried, capturedAtISO: p.captured)
        }
        func commitmentDTOs(_ values: [FundingPlanCommitment], region: String) throws -> [FundingPlanCommitmentDTO] {
            try values.enumerated().map { index, value in
                let p = provenance(value.provenance), money = try amount(value.money)
                return FundingPlanCommitmentDTO(id: value.id, planId: plan.id, regionCode: region, sourceOrdinal: index + 1, label: value.label,
                                                amountCurrency: value.money.currency.code, amountMinor: money.0, amountDecimal: money.1,
                                                included: value.included, fundingAccountId: value.fundingAccountID,
                                                provenanceCode: p.code, carriedSourcePlanId: p.carried)
            }
        }
        return FundingPlanDTO(
            id: plan.id, workspaceId: plan.workspaceID, planMonthISO: plan.month.canonical, rolloverSourcePlanId: plan.rolloverSourcePlanID,
            expectedFixedMinor: fixed.0, expectedFixedDecimal: fixed.1, expectedFixedProvenance: provenance(plan.expectedFixedProvenance).code,
            expectedVariableMinor: variable.0, expectedVariableDecimal: variable.1, expectedVariableProvenance: provenance(plan.expectedVariableProvenance).code,
            expectedDeductionsMinor: deductions.0, expectedDeductionsDecimal: deductions.1, expectedDeductionsProvenance: provenance(plan.expectedDeductionsProvenance).code,
            configuredFeeMinor: fee.0, configuredFeeDecimal: fee.1, configuredFeeProvenance: provenance(plan.configuredTransferFeeProvenance).code,
            fxINRPerQARDecimal: plan.planningFX.map { NSDecimalNumber(decimal: $0.inrPerQAR).stringValue }, fxObservationDateISO: plan.planningFX?.observationDate.canonical,
            plannedInvestmentMinor: investment.0, plannedInvestmentDecimal: investment.1, plannedInvestmentProvenance: provenance(plan.plannedInvestmentProvenance).code,
            updatedAtISO: plan.updatedAtISO, balances: balances,
            commitments: try commitmentDTOs(plan.qatarCommitments, region: "qatar") + commitmentDTOs(plan.indiaCommitments, region: "india")
        )
    }
}
