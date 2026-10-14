import Foundation

nonisolated enum FundingPlanValueProvenance: Equatable, Sendable, Codable {
    case manual
    case carried(sourcePlanID: String)
    case capturedAccountBalance(capturedAtISO: String)

    var persistenceCode: String {
        switch self {
        case .manual: return "manual"
        case .carried: return "carried"
        case .capturedAccountBalance: return "captured_account_balance"
        }
    }
}

nonisolated struct FundingPlanBalance: Identifiable, Equatable, Sendable, Codable {
    let id: String
    let accountID: String
    let nativeCurrency: CurrencyCode
    var included: Bool
    var money: Money?
    var provenance: FundingPlanValueProvenance
    var financialBalanceDate: StatementDate? = nil
}

nonisolated struct FundingPlanCommitment: Identifiable, Equatable, Sendable, Codable {
    let id: String
    var label: String
    var money: Money
    var included: Bool
    var fundingAccountID: String?
    var provenance: FundingPlanValueProvenance
    var recurs = true
    /// Present only for an explicit, temporary remaining-payment adjustment.
    var temporaryCarryBasis: Money? = nil
    var carriedSourceRowID: String? = nil
    var remark = ""
    var dueDate: StatementDate? = nil

    /// A saved funding override and the bill's related account both remain
    /// subject to the explicit account scope; neither saved link is rewritten.
    func isInAccountScope(excluding historyIDs: Set<String>, fundingOverrides: [String: String]? = nil) -> Bool {
        fundingAccountID.map(historyIDs.contains) != true
            && fundingOverrides?[id].map(historyIDs.contains) != true
    }

    /// Retain the selected recurring day; shorter months use their last day.
    /// Dates never change the row's explicit Include choice.
    nonisolated func dueDate(in month: SelectedStatementMonth) -> StatementDate? {
        guard let dueDate else { return nil }
        guard recurs, (dueDate.year, dueDate.month) <= (month.year, month.month) else { return dueDate }
        for day in stride(from: dueDate.day, through: 1, by: -1) {
            if let valid = try? StatementDate(year: month.year, month: month.month, day: day) { return valid }
        }
        return nil
    }
}

nonisolated enum FundingPlanCalculationVersion: String, Codable, Sendable { case legacy, budgetV1 }

nonisolated enum FundingPlanReferenceMode: String, Codable, Sendable { case alDar, manual }

nonisolated struct FundingPlanDeduction: Identifiable, Equatable, Sendable, Codable {
    let id: String
    var label: String
    var money: Money
    var recurs: Bool
    var carriedSourceRowID: String? = nil
}

nonisolated struct FundingPlanFX: Equatable, Sendable, Codable {
    let inrPerQAR: Decimal
    let observationDate: StatementDate

    enum ValidationError: Error, Equatable {
        case nonPositive
        case excessPrecision
    }

    init(inrPerQAR: Decimal, observationDate: StatementDate) throws {
        guard inrPerQAR > 0 else { throw ValidationError.nonPositive }
        let canonical = NSDecimalNumber(decimal: inrPerQAR).stringValue
        guard !canonical.lowercased().contains("e"), canonical.count <= 32 else {
            throw ValidationError.excessPrecision
        }
        self.inrPerQAR = inrPerQAR
        self.observationDate = observationDate
    }
}

nonisolated struct FundingPlan: Identifiable, Equatable, Sendable, Codable {
    let id: String
    let workspaceID: String
    let month: SelectedStatementMonth
    var rolloverSourcePlanID: String?
    var expectedFixedEarnings: Money
    var expectedFixedProvenance: FundingPlanValueProvenance
    var expectedVariableEarnings: Money
    var expectedVariableProvenance: FundingPlanValueProvenance
    var expectedDeductions: Money
    var expectedDeductionsProvenance: FundingPlanValueProvenance
    var balances: [FundingPlanBalance]
    var qatarCommitments: [FundingPlanCommitment]
    var indiaCommitments: [FundingPlanCommitment]
    var configuredTransferFee: Money
    var configuredTransferFeeProvenance: FundingPlanValueProvenance
    var planningFX: FundingPlanFX?
    var alDarReference: AlDarReferenceEvidence? = nil
    var plannedInvestment: Money
    var plannedInvestmentProvenance: FundingPlanValueProvenance
    var updatedAtISO: String
    var calculationVersion: FundingPlanCalculationVersion = .legacy
    var keepInCBQ: Money? = nil
    var deductions: [FundingPlanDeduction] = []
    var referenceMode: FundingPlanReferenceMode = .alDar
    var effectiveAlDarReference: AlDarReferenceQuote? = nil
    var assistance: PlanAssistance? = nil

    nonisolated var recurringStart: StatementDate { assistance?.salaryCycle?.recurringStart ?? (try! StatementDate(year: month.year, month: month.month, day: 1)) }
    nonisolated var recurringEnd: StatementDate { assistance?.salaryCycle?.recurringEnd ?? FinancialCalendar.lastDay(month)! }
    nonisolated func includesRecurring(_ date: StatementDate) -> Bool { date >= recurringStart && date <= recurringEnd }
    nonisolated func dueDate(for bill: FundingPlanCommitment) -> StatementDate? {
        if let date = assistance?.carriedBillDates?[bill.id] { return try? StatementDate(canonical: date) }
        return assistance?.salaryCycle == nil ? bill.dueDate(in: month) : bill.dueDate
    }
    /// Used only when explicitly carrying a template into a new draft. An
    /// existing dated bill never advances merely because payday changes.
    nonisolated func nextRecurringDate(for bill: FundingPlanCommitment) -> StatementDate? {
        guard assistance?.salaryCycle != nil, bill.recurs, let original = bill.dueDate else { return bill.dueDate(in: month) }
        let firstMonth = try! SelectedStatementMonth(year: recurringStart.year, month: recurringStart.month)
        if let date = bill.dueDate(in: firstMonth), date >= original, includesRecurring(date) { return date }
        let lastMonth = try! SelectedStatementMonth(year: recurringEnd.year, month: recurringEnd.month)
        if let date = bill.dueDate(in: lastMonth), date >= original, includesRecurring(date) { return date }
        return original
    }
}

extension FundingPlanFX {
    nonisolated private enum CodingKeys: String, CodingKey { case inrPerQAR, observationDate }
    nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(inrPerQAR: values.decode(Decimal.self, forKey: .inrPerQAR),
                      observationDate: values.decode(StatementDate.self, forKey: .observationDate))
    }
}

nonisolated struct MonthlyPlanScratchpad: Codable, Equatable, Sendable {
    var version = 1
    var plan: FundingPlan
    var canonical: FundingPlan?
    var rawText: [String: String]
    var fieldErrors: [String: String]
    var untouchedZeroFields: Set<String>
    var unavailableBalanceAccountIDs: Set<String>
    var preReductionBasis: [String: Money]
    var excludedRecurringOccurrenceIDs: Set<String>

    func hasIdentity(workspaceID: String, month: String) -> Bool {
        version == 1 && plan.workspaceID == workspaceID &&
            plan.month.canonical == month && !plan.id.isEmpty &&
            (canonical.map({ $0.workspaceID == workspaceID && $0.month == plan.month && $0.id == plan.id }) ?? true)
    }
}
