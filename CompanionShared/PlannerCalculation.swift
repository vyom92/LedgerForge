import Foundation

nonisolated enum FundingPlanIncompleteReason: String, Equatable, Sendable {
    case includedQARBalanceMissing
    case includedINRBalanceMissing
    case invalidCurrency
    case missingPlanningFX
    case invalidPlanningReference
    case salaryReceiptNeedsReview
    case reviewedObligationNeedsReview
}

nonisolated struct FundingPlanCalculation: Equatable, Sendable {
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
    /// Signed native surplus after mandatory obligations and ordinary
    /// remittance costs, before retention or other surplus allocations.
    var surplusAfterObligations: Money? = nil
    var inrAfterObligations: Money? = nil
    /// The worksheet retains its upcoming manual amount when an older or
    /// later-cycle review still names the recurring bill's stable identity.
    var staleReviewedObligationIDs: Set<String> = []
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

    static func resolve(plan: FundingPlan, evidence: [PayslipReceiptEvidence], excludedAccounts: Set<String> = []) -> Self? {
        guard let link = plan.assistance?.payslipFunding else { return nil }
        guard !excludedAccounts.contains(link.accountID),
              let balance = plan.balances.first(where: { $0.accountID == link.accountID && $0.included }),
              let amount = balance.money else { return .needsReview }
        let candidates = evidence.filter {
            $0.accountID == link.accountID && $0.isCredit && $0.money.currency.code == link.net.currency &&
                $0.date.map { String($0.canonical.prefix(7)) == plan.month.canonical } == true && $0.hasCBQSource &&
                $0.narration.uppercased().hasPrefix("SALARY TRANSFER") && $0.narration.uppercased().contains("QATAR AIRWAYS")
        }
        guard !candidates.isEmpty else {
            if let acknowledgement = link.balanceAcknowledgement {
                guard case .capturedAccountBalance = balance.provenance,
                      let payday = plan.assistance?.salaryCycle?.recurringStart,
                      let acknowledgedDate = try? StatementDate(canonical: acknowledgement.financialDate),
                      acknowledgedDate >= payday else { return .needsReview }
                return acknowledgement.balanceID == balance.id && acknowledgement.amount == (try? PlanningAmount(amount)) &&
                    acknowledgement.financialDate == balance.financialBalanceDate?.canonical ? .acknowledgedBalance : .needsReview
            }
            if let date = balance.financialBalanceDate, let payday = plan.assistance?.salaryCycle?.recurringStart, date >= payday {
                return .needsReview
            }
            return .pending
        }
        guard candidates.count == 1, let credit = candidates.first, let date = credit.date,
              let id = credit.id, let net = try? link.net.money(), credit.money == net else { return .needsReview }
        return .bankCredit(id: id, date: date, includedInBalance: balance.financialBalanceDate.map { $0 >= date } ?? false)
    }
}

/// Exact inputs consulted by the existing salary-receipt resolver. Adapters
/// supply canonical facts; this value is neither a transaction nor an estimate.
nonisolated struct PayslipReceiptEvidence {
    let id: String?
    let accountID: String?
    let date: StatementDate?
    let money: Money
    let isCredit: Bool
    let narration: String
    let hasCBQSource: Bool
}

/// One included worksheet obligation after an exact, owner-reviewed card
/// replacement. The original bill and its source/date/identity stay unchanged.
nonisolated struct FundingPlanObligation: Equatable, Sendable {
    let billID: String
    let money: Money
    let fundingAccountID: String?
    let replacementAdjustmentID: String?
    var staleReplacementAdjustmentID: String? = nil
}

nonisolated enum FundingPlanCalculator {
    /// Stable recurring bill IDs can outlive an individual statement review.
    /// Only this definite cycle mismatch makes a link stale; early payments
    /// within the same cycle and explicitly overdue manual bills retain their
    /// existing interpretation. No settlement is inferred from either date.
    static func reviewedObligationIsStale(_ review: PlanDatedAdjustment, for bill: FundingPlanCommitment,
                                          in plan: FundingPlan) -> Bool {
        guard plan.calculationVersion == .budgetV1, let cycle = plan.assistance?.salaryCycle,
              let billDate = plan.dueDate(for: bill), let reviewDate = try? StatementDate(canonical: review.date) else { return false }
        return cycle.includesRecurring(dueOn: billDate) && !cycle.includesRecurring(dueOn: reviewDate)
    }

    static func staleReviewedObligationIDs(in plan: FundingPlan) -> Set<String> {
        let bills = plan.qatarCommitments + plan.indiaCommitments
        return Set((plan.assistance?.datedAdjustments ?? []).compactMap { review in
            guard let billID = review.replacesCommitmentID, let bill = bills.first(where: { $0.id == billID }),
                  reviewedObligationIsStale(review, for: bill, in: plan) else { return nil }
            return review.id
        })
    }

    /// Resolve only explicit card/statement/bill links. A review of another
    /// statement on the same card never changes an independent manual estimate.
    /// Dates describe funding intent; they do not remove an included salary-
    /// cycle obligation merely because it falls in the next calendar month.
    static func effectiveIncludedObligations(_ plan: FundingPlan, excludingAccounts: Set<String> = [],
                                             historyOnlyAccountIDs: Set<String> = []) throws -> [FundingPlanObligation] {
        let bills = plan.qatarCommitments + plan.indiaCommitments
        let adjustments = plan.assistance?.datedAdjustments ?? []
        let replacements = plan.calculationVersion == .budgetV1 ? adjustments.filter { $0.replacesCommitmentID != nil } : []
        var byBill: [String: PlanDatedAdjustment] = [:]
        if !replacements.isEmpty {
            guard Set(bills.map(\.id)).count == bills.count,
                  Set(adjustments.map(\.id)).count == adjustments.count else { throw FinancialIntelligenceError.invalidRecord }
            for review in replacements {
                guard let billID = review.replacesCommitmentID,
                      let bill = bills.first(where: { $0.id == billID }), byBill[billID] == nil,
                      review.kind == .irregularCost,
                      !review.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let cardID = review.cardAccountID, !cardID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      bill.fundingAccountID == cardID,
                      let statementID = review.cardStatementID, !statementID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      adjustments.filter({ $0.cardStatementID == statementID }).count == 1,
                      !review.accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      review.accountID != cardID,
                      let money = try? review.amount.money(), money.currency == bill.money.currency, money.amount >= 0,
                      (try? StatementDate(canonical: review.date)) != nil else { throw FinancialIntelligenceError.invalidRecord }
                byBill[billID] = review
            }
        }
        let unavailableAccounts = excludingAccounts.union(historyOnlyAccountIDs)
        return try bills.filter { $0.included && $0.isInAccountScope(excluding: historyOnlyAccountIDs,
            fundingOverrides: plan.assistance?.billFundingAccounts) }.map { bill in
            if let review = byBill[bill.id] {
                if reviewedObligationIsStale(review, for: bill, in: plan) {
                    return .init(billID: bill.id, money: bill.money,
                        fundingAccountID: plan.assistance?.billFundingAccounts?[bill.id] ?? bill.fundingAccountID,
                        replacementAdjustmentID: nil, staleReplacementAdjustmentID: review.id)
                }
                guard !unavailableAccounts.contains(review.accountID) else { throw FinancialIntelligenceError.invalidRecord }
                return try .init(billID: bill.id, money: review.amount.money(), fundingAccountID: review.accountID,
                                 replacementAdjustmentID: review.id)
            }
            return .init(billID: bill.id, money: bill.money,
                         fundingAccountID: plan.assistance?.billFundingAccounts?[bill.id] ?? bill.fundingAccountID,
                         replacementAdjustmentID: nil)
        }
    }

    /// The same plan-local quote and upward principal rounding used by the
    /// worksheet. Investment quote currencies do not create another FX source.
    static func transferPrincipal(received: Money, fromCurrency: String, plan: FundingPlan) -> Money? {
        if fromCurrency == received.currency.code { return received }
        guard fromCurrency == "QAR", received.currency.code == "INR" else { return nil }
        let rate: AlDarReturnedINRDecimal?
        if plan.referenceMode == .manual { rate = plan.planningFX.flatMap { try? AlDarReturnedINRDecimal.planningRate($0.inrPerQAR) } }
        else { rate = plan.effectiveAlDarReference.flatMap { $0.submittedQAR.amount == 1 ? $0.returnedINR : nil } }
        return try? rate?.principal(for: received, submittedQAR: Money(amount: 1, currency: "QAR"))
    }

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
        if plan.calculationVersion == .budgetV1 {
            guard let obligations = try? effectiveIncludedObligations(savedPlan, excludingAccounts: excludingAccounts,
                historyOnlyAccountIDs: historyOnlyAccountIDs) else { return unavailable(.reviewedObligationNeedsReview) }
            return calculateBudget(plan, obligations: obligations)
        }
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
        let inrSurplus: Money? = if let selectedINR, let indiaCommitments {
            try? Money(amount: max(0, selectedINR.amount - indiaCommitments.amount), currency: inr)
        } else { nil }
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
            incompleteReasons: reasons,
            surplusAfterObligations: beforeInvestment,
            inrAfterObligations: inrSurplus
        )
    }

    private static func calculateBudget(_ plan: FundingPlan, obligations: [FundingPlanObligation]) -> FundingPlanCalculation {
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
        let cq = sum(obligations.filter { $0.money.currency == qar }.map(\.money), currency: qar)
        let ci = sum(obligations.filter { $0.money.currency == inr }.map(\.money), currency: inr)
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
        let inrSurplus: Money? = if let e, let ci { try? Money(amount: max(0, e.amount - ci.amount), currency: inr) } else { nil }
        return FundingPlanCalculation(expectedNet: net, selectedQARLiquidity: b, selectedINRLiquidity: e,
            indiaCommitments: ci, indiaFundingShortfall: h, requiredQARPrincipal: principal,
            effectiveTransferFee: fee, qarBeforeInvestment: margin, availableForInvestment: nil,
            finalQARBuffer: margin, incompleteReasons: reasons, totalDeductions: deductions,
            qatarCommitments: cq, positionBeforeTransfer: p, signedPotentialCapacity: a,
            transferablePrincipal: t, estimatedINR: estimate,
            qatarObligationShortfall: obligationGap, qatarReserveGap: reserveGap,
            surplusAfterObligations: margin.flatMap { try? $0 + reserve },
            inrAfterObligations: inrSurplus,
            staleReviewedObligationIDs: Set(obligations.compactMap(\.staleReplacementAdjustmentID)))
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
