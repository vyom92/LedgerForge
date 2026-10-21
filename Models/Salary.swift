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

/// A presentation-only contribution with every original source still available.
/// In the accepted single-owner Qatar Airways profile, an exact regular-payslip
/// reprint contributes once. This is not a persisted payroll/payment identity.
struct SalaryPaymentGroup: Equatable, Sendable {
    let representative: SalaryStatement
    private(set) var statements: [SalaryStatement]

    static func grouped(_ statements: [SalaryStatement]) -> [Self] {
        var groups: [Self] = []
        for statement in statements.sorted(by: { ($0.importedAtISO, $0.id) < ($1.importedAtISO, $1.id) }) {
            if let index = groups.firstIndex(where: { $0.representative.isRegularSalaryReprint(of: statement) }) {
                groups[index].statements.append(statement)
            } else {
                groups.append(Self(representative: statement, statements: [statement]))
            }
        }
        return groups
    }
}

private extension SalaryStatement {
    func isRegularSalaryReprint(of other: Self) -> Bool {
        let lhs = evidence, rhs = other.evidence
        return workspaceID == other.workspaceID &&
            lhs.kind == .regularSalary && rhs.kind == .regularSalary &&
            lhs.sourceAuthority == rhs.sourceAuthority &&
            lhs.profileID == rhs.profileID && lhs.profileVersion == rhs.profileVersion &&
            lhs.financialPeriod == rhs.financialPeriod && lhs.nativeCurrency == rhs.nativeCurrency &&
            lhs.earnings == rhs.earnings && lhs.deductions == rhs.deductions &&
            lhs.printedEarningsTotal == rhs.printedEarningsTotal &&
            lhs.printedDeductionsTotal == rhs.printedDeductionsTotal &&
            lhs.printedNet == rhs.printedNet && lhs.printedPaymentTotal == rhs.printedPaymentTotal
    }
}

extension PayslipReceiptState {
    nonisolated static func resolve(plan: FundingPlan, transactions: [Transaction], excludedAccounts: Set<String> = []) -> Self? {
        // Source-established employer payroll does not stop being received if
        // an editable category rule is later disabled. No relationship is saved.
        return resolve(plan: plan, evidence: transactions.map {
            .init(id: $0.repositoryTransactionId, accountID: $0.repositoryAccountId, date: $0.statementDate, money: $0.money,
                  isCredit: $0.creditMoney != nil, narration: $0.description,
                  hasCBQSource: $0.sourceProvenance.contains { $0.parserProfileID.hasPrefix("cbq.") })
        }, excludedAccounts: excludedAccounts)
    }
}
