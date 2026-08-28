import Foundation

enum SalarySourceAuthority: String, CaseIterable, Equatable, Sendable, Codable {
    case qatarAirways = "qatar_airways"

    var displayName: String {
        switch self {
        case .qatarAirways: return "Qatar Airways"
        }
    }
}

enum SalaryDocumentKind: String, CaseIterable, Equatable, Sendable, Codable {
    case regularSalary = "regular_salary"
    case adhocPayment = "adhoc_payment"
    case annualDiscretionaryBonus = "annual_discretionary_bonus"

    var displayName: String {
        switch self {
        case .regularSalary: return "Salary"
        case .adhocPayment: return "Adhoc Payment"
        case .annualDiscretionaryBonus: return "Annual Discretionary Bonus"
        }
    }
}

enum SalaryComponentSide: String, CaseIterable, Equatable, Sendable, Codable {
    case earning
    case deduction
}

struct SalaryComponent: Equatable, Sendable, Codable {
    let side: SalaryComponentSide
    let sourceOrdinal: Int
    let sourceLabel: String
    let money: Money

    enum ValidationError: Error, Equatable {
        case invalidOrdinal
        case invalidLabel
        case nonPositiveMoney
    }

    init(side: SalaryComponentSide, sourceOrdinal: Int, sourceLabel: String, money: Money) throws {
        let label = sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sourceOrdinal > 0 else { throw ValidationError.invalidOrdinal }
        guard !label.isEmpty, label.count <= 240 else { throw ValidationError.invalidLabel }
        guard money.amount > 0 else { throw ValidationError.nonPositiveMoney }
        self.side = side
        self.sourceOrdinal = sourceOrdinal
        self.sourceLabel = label
        self.money = money
    }
}

struct SalaryStatementEvidence: Equatable, Sendable {
    static let profileID = "qatar-airways.salary.pdf"
    static let profileVersion = "1"

    let sourceAuthority: SalarySourceAuthority
    let profileID: String
    let profileVersion: String
    let financialPeriod: SelectedStatementMonth
    let printDate: StatementDate?
    let kind: SalaryDocumentKind
    let nativeCurrency: CurrencyCode
    let earnings: [SalaryComponent]
    let deductions: [SalaryComponent]
    let printedEarningsTotal: Money
    /// Nil means the source did not print a deduction section/total.
    let printedDeductionsTotal: Money?
    let printedNet: Money
    let printedPaymentTotal: Money

    enum ValidationError: Error, Equatable, LocalizedError {
        case unsupportedProfile
        case unsupportedCurrency
        case missingEarnings
        case invalidComponentOrder
        case componentSideMismatch
        case currencyMismatch
        case earningsDoNotReconcile
        case deductionsDoNotReconcile
        case netDoesNotReconcile
        case paymentDoesNotReconcile

        var errorDescription: String? {
            switch self {
            case .unsupportedProfile: return "The salary parser profile is unsupported."
            case .unsupportedCurrency: return "The salary statement currency is unsupported."
            case .missingEarnings: return "The salary statement contains no earnings."
            case .invalidComponentOrder: return "Salary component source order is incomplete."
            case .componentSideMismatch: return "Salary component source-side evidence is contradictory."
            case .currencyMismatch: return "Salary Money values do not share the source currency."
            case .earningsDoNotReconcile: return "Salary earnings do not equal the printed total."
            case .deductionsDoNotReconcile: return "Salary deductions do not equal the printed total."
            case .netDoesNotReconcile: return "Salary net pay does not reconcile."
            case .paymentDoesNotReconcile: return "Salary payment total does not equal printed net pay."
            }
        }
    }

    init(
        sourceAuthority: SalarySourceAuthority,
        profileID: String = Self.profileID,
        profileVersion: String = Self.profileVersion,
        financialPeriod: SelectedStatementMonth,
        printDate: StatementDate?,
        kind: SalaryDocumentKind,
        nativeCurrency: CurrencyCode,
        earnings: [SalaryComponent],
        deductions: [SalaryComponent],
        printedEarningsTotal: Money,
        printedDeductionsTotal: Money?,
        printedNet: Money,
        printedPaymentTotal: Money
    ) throws {
        guard profileID == Self.profileID, profileVersion == Self.profileVersion else {
            throw ValidationError.unsupportedProfile
        }
        guard nativeCurrency.code == "QAR" else { throw ValidationError.unsupportedCurrency }
        guard !earnings.isEmpty else { throw ValidationError.missingEarnings }
        guard earnings.map(\.sourceOrdinal) == earnings.indices.map({ $0 + 1 }),
              deductions.map(\.sourceOrdinal) == deductions.indices.map({ $0 + 1 }) else {
            throw ValidationError.invalidComponentOrder
        }
        guard earnings.allSatisfy({ $0.side == .earning }),
              deductions.allSatisfy({ $0.side == .deduction }) else {
            throw ValidationError.componentSideMismatch
        }
        let values = earnings.map(\.money) + deductions.map(\.money) +
            [printedEarningsTotal, printedNet, printedPaymentTotal] + [printedDeductionsTotal].compactMap { $0 }
        guard values.allSatisfy({ $0.currency == nativeCurrency }) else {
            throw ValidationError.currencyMismatch
        }
        guard try Money.aggregate(earnings.map(\.money)) == printedEarningsTotal else {
            throw ValidationError.earningsDoNotReconcile
        }
        if let printedDeductionsTotal {
            guard !deductions.isEmpty,
                  try Money.aggregate(deductions.map(\.money)) == printedDeductionsTotal else {
                throw ValidationError.deductionsDoNotReconcile
            }
        } else if !deductions.isEmpty {
            throw ValidationError.deductionsDoNotReconcile
        }
        let deductionValue = try printedDeductionsTotal ?? Money(amount: .zero, currency: nativeCurrency)
        guard try printedEarningsTotal - deductionValue == printedNet else {
            throw ValidationError.netDoesNotReconcile
        }
        guard printedPaymentTotal == printedNet else { throw ValidationError.paymentDoesNotReconcile }

        self.sourceAuthority = sourceAuthority
        self.profileID = profileID
        self.profileVersion = profileVersion
        self.financialPeriod = financialPeriod
        self.printDate = printDate
        self.kind = kind
        self.nativeCurrency = nativeCurrency
        self.earnings = earnings
        self.deductions = deductions
        self.printedEarningsTotal = printedEarningsTotal
        self.printedDeductionsTotal = printedDeductionsTotal
        self.printedNet = printedNet
        self.printedPaymentTotal = printedPaymentTotal
    }
}

struct SalaryStatement: Identifiable, Equatable, Sendable {
    let id: String
    let workspaceID: String
    let documentID: String
    let importSessionID: String
    let fingerprintAlgorithm: String
    let fingerprintDigest: String
    let evidence: SalaryStatementEvidence
    let importedAtISO: String
}

enum FundingPlanValueProvenance: Equatable, Sendable, Codable {
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

struct FundingPlanBalance: Identifiable, Equatable, Sendable {
    let id: String
    let accountID: String
    let nativeCurrency: CurrencyCode
    var included: Bool
    var money: Money?
    var provenance: FundingPlanValueProvenance
}

struct FundingPlanCommitment: Identifiable, Equatable, Sendable {
    let id: String
    var label: String
    var money: Money
    var included: Bool
    var fundingAccountID: String?
    var provenance: FundingPlanValueProvenance
}

struct FundingPlanFX: Equatable, Sendable {
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

struct FundingPlan: Identifiable, Equatable, Sendable {
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
    var plannedInvestment: Money
    var plannedInvestmentProvenance: FundingPlanValueProvenance
    var updatedAtISO: String
}

enum FundingPlanIncompleteReason: String, Equatable, Sendable {
    case includedQARBalanceMissing
    case includedINRBalanceMissing
    case invalidCurrency
    case missingPlanningFX
}

struct FundingPlanCalculation: Equatable, Sendable {
    let expectedNet: Money?
    let selectedQARLiquidity: Money?
    let selectedINRLiquidity: Money?
    let indiaCommitments: Money?
    let indiaFundingShortfall: Money?
    let requiredQARPrincipal: Money?
    let effectiveTransferFee: Money?
    let qarBeforeInvestment: Money?
    let availableForInvestment: Money?
    let finalQARBuffer: Money?
    let incompleteReasons: Set<FundingPlanIncompleteReason>
}

enum FundingPlanCalculator {
    static func calculate(_ plan: FundingPlan) -> FundingPlanCalculation {
        var reasons = Set<FundingPlanIncompleteReason>()
        guard let qar = try? CurrencyCode("QAR"), let inr = try? CurrencyCode("INR") else {
            return unavailable(.invalidCurrency)
        }
        let qarInputs = [plan.expectedFixedEarnings, plan.expectedVariableEarnings, plan.expectedDeductions,
                         plan.configuredTransferFee, plan.plannedInvestment]
        guard qarInputs.allSatisfy({ $0.currency == qar }),
              plan.qatarCommitments.allSatisfy({ $0.money.currency == qar }),
              plan.indiaCommitments.allSatisfy({ $0.money.currency == inr }) else {
            return unavailable(.invalidCurrency)
        }

        let expectedNet = try? (plan.expectedFixedEarnings + plan.expectedVariableEarnings) - plan.expectedDeductions
        let includedQAR = plan.balances.filter { $0.included && $0.nativeCurrency == qar }
        let includedINR = plan.balances.filter { $0.included && $0.nativeCurrency == inr }
        if includedQAR.contains(where: { $0.money == nil }) { reasons.insert(.includedQARBalanceMissing) }
        if includedINR.contains(where: { $0.money == nil }) { reasons.insert(.includedINRBalanceMissing) }

        let selectedQAR = reasons.contains(.includedQARBalanceMissing)
            ? nil : sum(includedQAR.compactMap(\.money), currency: qar)
        let selectedINR = reasons.contains(.includedINRBalanceMissing)
            ? nil : sum(includedINR.compactMap(\.money), currency: inr)
        let qatarCommitments = sum(plan.qatarCommitments.filter(\.included).map(\.money), currency: qar)
        let indiaCommitments = sum(plan.indiaCommitments.filter(\.included).map(\.money), currency: inr)

        let shortfall: Money?
        if let selectedINR, let indiaCommitments,
           let difference = try? indiaCommitments - selectedINR {
            shortfall = try? Money(amount: max(.zero, difference.amount), currency: inr)
        } else {
            shortfall = nil
        }

        var principal: Money?
        var effectiveFee: Money?
        if let shortfall {
            if shortfall.amount == .zero {
                principal = try? Money(amount: .zero, currency: qar)
                effectiveFee = try? Money(amount: .zero, currency: qar)
            } else if let fx = plan.planningFX {
                var exact = shortfall.amount / fx.inrPerQAR
                var rounded = Decimal()
                NSDecimalRound(&rounded, &exact, 2, .up)
                principal = try? Money(amount: rounded, currency: qar)
                effectiveFee = plan.configuredTransferFee
            } else {
                reasons.insert(.missingPlanningFX)
            }
        }

        let beforeInvestment: Money?
        if let selectedQAR, let expectedNet, let qatarCommitments, let principal, let effectiveFee,
           let expectedAvailable = try? selectedQAR + expectedNet,
           let afterQatar = try? expectedAvailable - qatarCommitments,
           let afterIndia = try? afterQatar - principal {
            beforeInvestment = try? afterIndia - effectiveFee
        } else {
            beforeInvestment = nil
        }
        let finalBuffer = beforeInvestment.flatMap { try? $0 - plan.plannedInvestment }
        return FundingPlanCalculation(
            expectedNet: expectedNet,
            selectedQARLiquidity: selectedQAR,
            selectedINRLiquidity: selectedINR,
            indiaCommitments: indiaCommitments,
            indiaFundingShortfall: shortfall,
            requiredQARPrincipal: principal,
            effectiveTransferFee: effectiveFee,
            qarBeforeInvestment: beforeInvestment,
            availableForInvestment: beforeInvestment,
            finalQARBuffer: finalBuffer,
            incompleteReasons: reasons
        )
    }

    private static func sum(_ values: [Money], currency: CurrencyCode) -> Money? {
        if values.isEmpty { return try? Money(amount: .zero, currency: currency) }
        return try? Money.aggregate(values)
    }

    private static func unavailable(_ reason: FundingPlanIncompleteReason) -> FundingPlanCalculation {
        FundingPlanCalculation(
            expectedNet: nil,
            selectedQARLiquidity: nil,
            selectedINRLiquidity: nil,
            indiaCommitments: nil,
            indiaFundingShortfall: nil,
            requiredQARPrincipal: nil,
            effectiveTransferFee: nil,
            qarBeforeInvestment: nil,
            availableForInvestment: nil,
            finalQARBuffer: nil,
            incompleteReasons: [reason]
        )
    }
}
