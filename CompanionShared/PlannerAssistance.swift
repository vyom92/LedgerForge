import Foundation

nonisolated enum FinancialCalendar {
    static var calendar: Calendar { var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value }
    static func instant(_ date: StatementDate) -> Date? { calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)) }
    static func statement(_ date: Date) -> StatementDate? {
        let value = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = value.year, let m = value.month, let d = value.day else { return nil }
        return try? .init(year: y, month: m, day: d)
    }
    static func addDays(_ days: Int, to date: StatementDate) -> StatementDate? {
        guard let start = instant(date), let next = calendar.date(byAdding: .day, value: days, to: start) else { return nil }
        return statement(next)
    }
    static func distance(_ a: StatementDate, _ b: StatementDate) -> Int? {
        guard let start = instant(a), let end = instant(b) else { return nil }
        return calendar.dateComponents([.day], from: start, to: end).day
    }
    static func lastDay(_ month: SelectedStatementMonth) -> StatementDate? {
        for day in stride(from: 31, through: 28, by: -1) {
            if let date = try? StatementDate(year: month.year, month: month.month, day: day) { return date }
        }
        return nil
    }
}

nonisolated public struct PlanningAmount: Codable, Equatable, Sendable {
    var currency: String
    var decimal: String
    init(_ money: Money) throws { currency = money.currency.code; decimal = try money.canonicalDecimalString() }
    init(currency: String, decimal: String) { self.currency = currency; self.decimal = decimal }
    func money() throws -> Money { try Money(canonicalDecimal: decimal, currency: currency) }
    func validated(nonnegative: Bool = true) throws {
        let value = try money()
        guard !nonnegative || value.amount >= 0 else { throw FinancialIntelligenceError.invalidRecord }
    }
}

nonisolated public struct PlanContribution: Codable, Equatable, Sendable, Identifiable {
    public var id: String { designationID }
    var designationID: String
    var fundingAccountID: String
    var amount: PlanningAmount
    var dueDate: String
}

nonisolated public struct PlanDatedAdjustment: Codable, Equatable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable { case expectedIncome, irregularCost, discretionary }
    public var id: String
    var accountID: String
    var kind: Kind
    var title: String
    var amount: PlanningAmount
    var date: String
    var transactionIDs: [String]?
    var cardAccountID: String?
    var cardStatementID: String?
    var replacesCommitmentID: String?
}

nonisolated public struct PlanTransfer: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    var fromAccountID: String
    var toAccountID: String
    var sent: PlanningAmount
    var received: PlanningAmount
    var date: String
    var conversionBasis: String
    var transactionIDs: [String]?
}

nonisolated public struct SalaryFundingCycle: Codable, Equatable, Sendable {
    var expectedDay: Int
    var previousPayday: String
    var payday: String
    var nextPayday: String
    var receivedSalaryID: String?

    static func expected(month: SelectedStatementMonth, day: Int = 25) -> Self? {
        guard (1...31).contains(day) else { return nil }
        func date(offset: Int) -> String? {
            let total = month.year * 12 + month.month - 1 + offset
            guard let month = try? SelectedStatementMonth(year: total / 12, month: total % 12 + 1),
                  let last = FinancialCalendar.lastDay(month),
                  let date = try? StatementDate(year: month.year, month: month.month, day: min(day, last.day)) else { return nil }
            return date.canonical
        }
        guard let previous = date(offset: -1), let current = date(offset: 0), let next = date(offset: 1) else { return nil }
        return .init(expectedDay: day, previousPayday: previous, payday: current, nextPayday: next)
    }
    func validated(month: String) throws {
        guard (1...31).contains(expectedDay), String(payday.prefix(7)) == month,
              [previousPayday, payday, nextPayday].allSatisfy({ (try? StatementDate(canonical: $0)) != nil }),
              previousPayday < payday, payday < nextPayday,
              let selected = try? SelectedStatementMonth(canonical: month),
              let expected = Self.expected(month: selected, day: expectedDay),
              String(previousPayday.prefix(7)) == String(expected.previousPayday.prefix(7)), nextPayday == expected.nextPayday,
              receivedSalaryID != nil || payday == expected.payday else { throw FinancialIntelligenceError.invalidRecord }
    }
    func includesBill(issuedOn date: StatementDate) -> Bool { date.canonical > previousPayday && date.canonical <= payday }
    func includesRecurring(dueOn date: StatementDate) -> Bool { date.canonical >= payday && date.canonical < nextPayday }
    var recurringStart: StatementDate { try! StatementDate(canonical: payday) }
    var recurringEnd: StatementDate { FinancialCalendar.addDays(-1, to: try! StatementDate(canonical: nextPayday))! }
    var billStart: StatementDate { FinancialCalendar.addDays(1, to: try! StatementDate(canonical: previousPayday))! }
    var recurringRange: String { recurringStart.presentation + "–" + recurringEnd.presentation }
    var billRange: String { billStart.presentation + "–" + recurringStart.presentation }

}

nonisolated public struct PlanAssistance: Codable, Equatable, Sendable {
    var workspaceID: String
    var month: String
    var appliedSalaryIDs: [String] = []
    var contributions: [PlanContribution] = []
    var datedAdjustments: [PlanDatedAdjustment] = []
    var allowance: PlanningAmount?
    var allowanceAccountID: String?
    var allowanceOverrideReason = ""
    var sourceBalanceAcknowledgements: [String: String] = [:]
    var appliedRecurringIDs: [String: String] = [:]
    var appliedRecurringPaid: [String: PlanningAmount]?
    var billFundingAccounts: [String: String]?
    var transfers: [PlanTransfer]?
    var reserveAllocationReviewed: Bool?
    /// Missing means the previously saved calendar-month contract, not an
    /// implicit migration to salary dates.
    var salaryCycle: SalaryFundingCycle?
    /// Reviewed payment dates for carried templates. The original recurring
    /// day remains on the row, so February clamping does not change March.
    var carriedBillDates: [String: String]?
    /// A regular payslip is expected income, never a fabricated bank credit.
    /// This source link is saved only with the reviewed monthly plan.
    var payslipFunding: PayslipFunding?

    /// Filters presentation and forecast assumptions only; the saved plan is retained intact.

    func includesRecurring(_ date: StatementDate) -> Bool {
        salaryCycle?.includesRecurring(dueOn: date) ?? (String(date.canonical.prefix(7)) == month)
    }
}

nonisolated public struct PayslipFunding: Codable, Equatable, Sendable {
    var statementID: String
    var fingerprintAlgorithm: String
    var fingerprintDigest: String
    var accountID: String
    var net: PlanningAmount
    var balanceAcknowledgement: PayslipBalanceAcknowledgement?
}

nonisolated public struct PayslipBalanceAcknowledgement: Codable, Equatable, Sendable {
    var balanceID: String
    var amount: PlanningAmount
    var financialDate: String
}

nonisolated public enum FinancialIntelligenceError: Error, Equatable, LocalizedError {
    case unavailable, invalidRecord, invalidLegs, occupiedLeg, staleReview, refreshRequired, outsideScope
    public var errorDescription: String? {
        switch self {
        case .unavailable: "Financial context is unavailable for this ledger."
        case .invalidRecord: "The saved financial context could not be verified."
        case .invalidLegs: "These transactions do not have the account, currency or direction required for this relationship."
        case .occupiedLeg: "A transaction already belongs to a confirmed movement. Unlink that movement before changing its relationship."
        case .staleReview: "The saved interpretation changed. Refresh this review before saving."
        case .refreshRequired: "The interpretation was saved, but the ledger needs to refresh before another change."
        case .outsideScope: "Loan and EMI analysis is outside LedgerForge's selected scope. Original statement entries remain in Transactions."
        }
    }
}
