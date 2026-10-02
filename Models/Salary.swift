import Foundation

nonisolated enum SalarySourceAuthority: String, CaseIterable, Equatable, Sendable, Codable {
    case qatarAirways = "qatar_airways"

    var displayName: String {
        switch self {
        case .qatarAirways: return "Qatar Airways"
        }
    }
}

nonisolated enum SalaryDocumentKind: String, CaseIterable, Equatable, Sendable, Codable {
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

nonisolated enum SalaryComponentSide: String, CaseIterable, Equatable, Sendable, Codable {
    case earning
    case deduction
}

nonisolated struct SalaryComponent: Equatable, Sendable, Codable {
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

nonisolated struct SalaryStatementEvidence: Equatable, Sendable {
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

    static func resolve(plan: FundingPlan, transactions: [Transaction], excludedAccounts: Set<String> = []) -> Self? {
        guard let link = plan.assistance?.payslipFunding else { return nil }
        guard !excludedAccounts.contains(link.accountID),
              let balance = plan.balances.first(where: { $0.accountID == link.accountID && $0.included }),
              let amount = balance.money else { return .needsReview }
        // Source-established employer payroll does not stop being received if
        // an editable category rule is later disabled. No relationship is saved.
        let candidates = transactions.filter {
            $0.repositoryAccountId == link.accountID && $0.creditMoney != nil && $0.currency == link.net.currency &&
                $0.statementDate.map { String($0.canonical.prefix(7)) == plan.month.canonical } == true &&
                $0.sourceProvenance.contains { $0.parserProfileID.hasPrefix("cbq.") } &&
                $0.description.uppercased().hasPrefix("SALARY TRANSFER") && $0.description.uppercased().contains("QATAR AIRWAYS")
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
        guard candidates.count == 1, let credit = candidates.first, let date = credit.statementDate,
              let id = credit.repositoryTransactionId, let net = try? link.net.money(), credit.money == net else { return .needsReview }
        // A later imported credit outranks a prior balance acknowledgment. A
        // balance preceding the real credit cannot already include that money.
        return .bankCredit(id: id, date: date, includedInBalance: balance.financialBalanceDate.map { $0 >= date } ?? false)
    }

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
