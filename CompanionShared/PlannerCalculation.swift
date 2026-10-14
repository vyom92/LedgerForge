import Foundation

enum FundingPlanIncompleteReason: String, Equatable, Sendable {
    case includedQARBalanceMissing
    case includedINRBalanceMissing
    case invalidCurrency
    case missingPlanningFX
    case invalidPlanningReference
    case salaryReceiptNeedsReview
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
    var totalDeductions: Money? = nil
    var qatarCommitments: Money? = nil
    var positionBeforeTransfer: Money? = nil
    var signedPotentialCapacity: Money? = nil
    var transferablePrincipal: Money? = nil
    var estimatedINR: Money? = nil
    var qatarObligationShortfall: Money? = nil
    var qatarReserveGap: Money? = nil
}

nonisolated enum PayslipReceiptState: Equatable, Sendable {
    case pending
    case bankCredit(id: String, date: StatementDate, includedInBalance: Bool)
    case acknowledgedBalance
    case needsReview

    var explanation: String {
        switch self {
        case .pending: "Payslip received · bank payment not yet recorded"
        case .bankCredit(_, _, true): "Salary included in starting balance"
        case .bankCredit(_, _, false): "Salary received · update the balance to its payment date or later"
        case .acknowledgedBalance: "Salary included in starting balance"
        case .needsReview: "Check salary account and starting balance"
        }
    }
}

enum FundingPlanCalculator {
    // Monthly worksheet inputs are complete on their own. Saved reserve
    // targets belong to Plan insights and never reduce these selected balances.
    static func calculate(_ savedPlan: FundingPlan, excludingAccounts: Set<String> = [], historyOnlyAccountIDs: Set<String> = [], salaryReceipt: PayslipReceiptState? = nil) -> FundingPlanCalculation {
        var plan = savedPlan
        plan.balances.removeAll { excludingAccounts.contains($0.accountID) }
        let fundingOverrides = plan.assistance?.billFundingAccounts
        plan.qatarCommitments.removeAll { !$0.isInAccountScope(excluding: historyOnlyAccountIDs, fundingOverrides: fundingOverrides) }
        plan.indiaCommitments.removeAll { !$0.isInAccountScope(excluding: historyOnlyAccountIDs, fundingOverrides: fundingOverrides) }
        if plan.assistance?.payslipFunding.map({ historyOnlyAccountIDs.contains($0.accountID) }) == true {
            plan.assistance?.payslipFunding = nil
        }
        if let link = plan.assistance?.payslipFunding {
            switch salaryReceipt {
            case .pending:
                guard let net = try? link.net.money(), let total = try? plan.expectedFixedEarnings + net else { return unavailable(.invalidCurrency) }
                plan.expectedFixedEarnings = total
            case .bankCredit(_, _, true), .acknowledgedBalance: break
            case .bankCredit(_, _, false), .needsReview, nil: return unavailable(.salaryReceiptNeedsReview)
            }
        }
        if plan.calculationVersion == .budgetV1 { return calculateBudget(plan) }
        var reasons = Set<FundingPlanIncompleteReason>()
        guard plan.planningFX == nil || plan.alDarReference == nil else {
            return unavailable(.invalidPlanningReference)
        }
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
            } else if let reference = plan.alDarReference {
                if reference.boundShortfallINR == shortfall,
                   let amount = try? reference.quote.principal(for: shortfall) {
                    principal = amount
                    effectiveFee = plan.configuredTransferFee
                } else {
                    reasons.insert(.invalidPlanningReference)
                }
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
        let availableForInvestment = beforeInvestment.flatMap { try? Money(amount: max(.zero, $0.amount), currency: qar) }
        return FundingPlanCalculation(
            expectedNet: expectedNet,
            selectedQARLiquidity: selectedQAR,
            selectedINRLiquidity: selectedINR,
            indiaCommitments: indiaCommitments,
            indiaFundingShortfall: shortfall,
            requiredQARPrincipal: principal,
            effectiveTransferFee: effectiveFee,
            qarBeforeInvestment: beforeInvestment,
            availableForInvestment: availableForInvestment,
            finalQARBuffer: finalBuffer,
            incompleteReasons: reasons
        )
    }

    private static func calculateBudget(_ plan: FundingPlan) -> FundingPlanCalculation {
        guard let qar = try? CurrencyCode("QAR"), let inr = try? CurrencyCode("INR"),
              let reserve = plan.keepInCBQ,
              [plan.expectedFixedEarnings, plan.expectedVariableEarnings, plan.configuredTransferFee, reserve].allSatisfy({ $0.currency == qar }),
              reserve.amount >= 0, plan.configuredTransferFee.amount >= 0,
              plan.deductions.allSatisfy({ $0.money.currency == qar && $0.money.amount >= 0 }),
              plan.qatarCommitments.allSatisfy({ $0.money.currency == qar && $0.money.amount >= 0 }),
              plan.indiaCommitments.allSatisfy({ $0.money.currency == inr && $0.money.amount >= 0 }) else { return unavailable(.invalidCurrency) }
        var reasons = Set<FundingPlanIncompleteReason>()
        func liquidity(_ currency: CurrencyCode, missing: FundingPlanIncompleteReason) -> Money? {
            let rows = plan.balances.filter { $0.included && $0.nativeCurrency == currency }
            guard rows.allSatisfy({ $0.money?.currency == currency }) else { reasons.insert(missing); return nil }
            return sum(rows.compactMap(\.money), currency: currency)
        }
        let b = liquidity(qar, missing: .includedQARBalanceMissing)
        let e = liquidity(inr, missing: .includedINRBalanceMissing)
        let deductions = sum(plan.deductions.map(\.money), currency: qar)
        let net = deductions.flatMap { try? plan.expectedFixedEarnings + plan.expectedVariableEarnings - $0 }
        let cq = sum(plan.qatarCommitments.filter(\.included).map(\.money), currency: qar)
        let ci = sum(plan.indiaCommitments.filter(\.included).map(\.money), currency: inr)
        let p: Money? = if let b, let net, let cq { try? b + net - cq - reserve } else { nil }
        let a = p.flatMap { try? $0 - plan.configuredTransferFee }
        let t = a.flatMap { try? Money(amount: max(0, $0.amount), currency: qar) }
        let h: Money? = if let ci, let e, let difference = try? ci - e {
            try? Money(amount: max(0, difference.amount), currency: inr)
        } else { nil }
        let rate: AlDarReturnedINRDecimal?
        switch plan.referenceMode {
        case .alDar:
            rate = plan.effectiveAlDarReference.flatMap { $0.submittedQAR.amount == 1 ? $0.returnedINR : nil }
        case .manual:
            rate = plan.planningFX.flatMap { try? AlDarReturnedINRDecimal.planningRate($0.inrPerQAR) }
        }
        let principal: Money?
        if let h, h.amount == 0 { principal = try? Money(amount: 0, currency: qar) }
        else if let h, let rate {
            principal = try? rate.principal(for: h, submittedQAR: Money(amount: 1, currency: qar))
        } else { principal = nil }
        if rate == nil, let h, h.amount > 0 { reasons.insert(.missingPlanningFX) }
        let fee = principal.flatMap { try? Money(amount: $0.amount > 0 ? plan.configuredTransferFee.amount : 0, currency: qar) }
        let margin: Money? = if let p, let principal, let fee { try? p - principal - fee } else { nil }
        let estimate: Money? = if let t, let rate { try? rate.receiveEstimate(forQAR: t) } else { nil }
        let afterQatarBills: Money? = if let b, let net, let cq { try? b + net - cq } else { nil }
        let obligationGap = afterQatarBills.flatMap { try? Money(amount: max(0, -$0.amount), currency: qar) }
        let reserveGap = afterQatarBills.flatMap { try? Money(amount: max(0, reserve.amount - max(0, $0.amount)), currency: qar) }
        return FundingPlanCalculation(expectedNet: net, selectedQARLiquidity: b, selectedINRLiquidity: e,
            indiaCommitments: ci, indiaFundingShortfall: h, requiredQARPrincipal: principal,
            effectiveTransferFee: fee, qarBeforeInvestment: margin, availableForInvestment: nil,
            finalQARBuffer: margin, incompleteReasons: reasons, totalDeductions: deductions,
            qatarCommitments: cq, positionBeforeTransfer: p, signedPotentialCapacity: a,
            transferablePrincipal: t, estimatedINR: estimate,
            qatarObligationShortfall: obligationGap, qatarReserveGap: reserveGap)
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
