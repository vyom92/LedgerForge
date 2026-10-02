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


/// One current editor state per month. Incomplete text is intentionally separate
/// from the validated plan used by financial projections; there is no edit log.
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

    func dto() throws -> MonthlyPlanScratchpadDTO {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try .init(workspaceID: plan.workspaceID, month: plan.month.canonical,
                         stateJSON: String(decoding: encoder.encode(self), as: UTF8.self))
    }

    static func decode(_ dto: MonthlyPlanScratchpadDTO) throws -> Self {
        let value = try JSONDecoder().decode(Self.self, from: Data(dto.stateJSON.utf8))
        guard value.version == 1, value.plan.workspaceID == dto.workspaceID,
              value.plan.month.canonical == dto.month, !value.plan.id.isEmpty,
              value.canonical.map({ $0.workspaceID == dto.workspaceID && $0.month == value.plan.month && $0.id == value.plan.id }) ?? true else {
            throw RepositoryError.relationshipViolation("Monthly scratchpad identity is invalid.")
        }
        return value
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


extension FundingPlan {
    nonisolated func persistenceDTO() throws -> FundingPlanDTO {
        let plan = self
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
                                         provenanceCode: p.code, carriedSourcePlanId: p.carried, capturedAtISO: p.captured, financialBalanceDateISO: value.financialBalanceDate?.canonical)
        }
        func commitmentDTOs(_ values: [FundingPlanCommitment], region: String) throws -> [FundingPlanCommitmentDTO] {
            try values.enumerated().map { index, value in
                let p = provenance(value.provenance), money = try amount(value.money)
                return FundingPlanCommitmentDTO(id: value.id, planId: plan.id, regionCode: region, sourceOrdinal: index + 1, label: value.label,
                                                amountCurrency: value.money.currency.code, amountMinor: money.0, amountDecimal: money.1,
                                                included: value.included, fundingAccountId: value.fundingAccountID,
                                                provenanceCode: p.code, carriedSourcePlanId: p.carried,
                                                recurs: value.recurs, temporaryCarryBasisMinor: try value.temporaryCarryBasis?.minorUnits(),
                                                temporaryCarryBasisDecimal: try value.temporaryCarryBasis?.canonicalDecimalString(),
                                                carriedSourceRowId: value.carriedSourceRowID, remark: value.remark, dueDateISO: value.dueDate?.canonical)
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
            commitments: try commitmentDTOs(plan.qatarCommitments, region: "qatar") + commitmentDTOs(plan.indiaCommitments, region: "india"),
            alDarReference: try plan.alDarReference.map { try FundingPlanAlDarReferenceDTO(planID: plan.id, evidence: $0) },
            calculationVersion: plan.calculationVersion.rawValue,
            keepInCBQMinor: try plan.keepInCBQ?.minorUnits(), keepInCBQDecimal: try plan.keepInCBQ?.canonicalDecimalString(),
            referenceMode: plan.calculationVersion == .budgetV1 ? plan.referenceMode.rawValue : nil,
            deductions: try plan.deductions.enumerated().map { index, row in
                FundingPlanDeductionDTO(id: row.id, planId: plan.id, sourceOrdinal: index + 1, label: row.label,
                    amountMinor: try row.money.minorUnits(), amountDecimal: try row.money.canonicalDecimalString(),
                    recurs: row.recurs, carriedSourceRowId: row.carriedSourceRowID)
            },
            effectiveReference: try plan.effectiveAlDarReference.map {
                guard $0.submittedQAR.currency.code == "QAR", $0.submittedQAR.amount == 1 else { throw AlDarReferenceError.invalidBinding }
                return FundingPlanEffectiveReferenceDTO(planId: plan.id, rawINR: $0.returnedINR.rawToken, fetchedAtISO: $0.fetchedAtISO)
            },
            assistance: plan.assistance
        )
    }
}
