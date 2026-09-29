import Foundation

/// Calendar-only mechanics. The UTC conversion is used to count calendar days,
/// never to shift a printed financial date into another time zone.
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


/// Owner planning amounts use the same exact native Money rules as the ledger,
/// with a portable, versioned JSON representation in the existing V28 tables.
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

nonisolated public struct RecurringRevision: Codable, Equatable, Sendable {
    var effectiveFrom: String
    var dueDay: Int
    var amount: PlanningAmount
}

nonisolated public struct RecurringDefinition: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    var workspaceID: String
    var accountID: String
    var title: String
    var revisions: [RecurringRevision]
    var endsOn: String?
    var predicates: [CategoryTextPredicate]
    var isEnabled = true
    var note = ""
    func revision(on day: StatementDate) -> RecurringRevision? {
        revisions.filter { $0.effectiveFrom <= day.canonical }.max { $0.effectiveFrom < $1.effectiveFrom }
    }
}

nonisolated public struct RecurringOccurrence: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    var workspaceID: String
    var definitionID: String
    var dueDate: String
    var amountOverride: PlanningAmount?
    var isWaived = false
    var transactionIDs: [String] = []
    var note = ""
}

nonisolated public struct ReserveDesignation: Codable, Equatable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable { case accountCash, planningDeposit }
    public var id: String
    var workspaceID: String
    var accountID: String?
    var title: String
    var kind: Kind
    var target: PlanningAmount
    var planningBalance: PlanningAmount?
    var planningBalanceDate: String?
    var availableOn: String?
    var note = ""
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

/// A salary funds two different sets: bills issued since the previous payday,
/// and recurring payments due before the next payday. Source bill dates and
/// payment due dates never stand in for each other.
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

    func previousSavedPayday(in metadata: FinancialIntelligenceSnapshot?) -> String? {
        metadata?.plans.first { $0.month == String(previousPayday.prefix(7)) }?.salaryCycle?.payday
    }
    func needsPreviousBoundaryReview(in metadata: FinancialIntelligenceSnapshot?) -> Bool {
        previousSavedPayday(in: metadata).map { $0 != previousPayday } ?? false
    }
}

/// Saved with the ordinary monthly FundingPlan aggregate. An optional amount is
/// unset, not a zero target. Scenarios never enter this record implicitly.
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

nonisolated public struct SalaryAssistance: Codable, Equatable, Sendable, Identifiable {
    enum PlanningBasis: String, Codable, Sendable { case creditMonth }
    enum DraftState: String, Codable, Sendable { case proposed, reviewed, consumed, dismissed }
    enum ISPState: String, Codable, Sendable { case unverified, indeterminate, verified, dismissed }
    public var id: String { transactionID }
    var transactionID: String
    var workspaceID: String
    var financialDate: String
    var targetMonth: String
    /// Nil preserves the old following-calendar-month proposal contract.
    var planningBasis: PlanningBasis?
    var draftState: DraftState = .proposed
    var ispState: ISPState = .unverified
    var ispLastAttemptAt: String?
    var ispLastFetchAt: String?
    var ispBaselineAsOf: String?
    var ispBaseline: ZurichISPAccountSnapshot?
    var ispExplanation = "No suitable contribution evidence has been compared."
}

/// UTC clock and evidence rules for the existing ISP job. This does not infer
/// a payroll contribution from prices, units or a cumulative-total increase.
nonisolated enum SalaryISPVerification {
    static func creditDay(_ salary: SalaryAssistance) -> Date? {
        guard let day = try? StatementDate(canonical: salary.financialDate) else { return nil }
        return BackgroundSchedule.utcCalendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))
    }
    static func threshold(_ salary: SalaryAssistance) -> Date? {
        creditDay(salary).flatMap { BackgroundSchedule.utcCalendar.date(byAdding: .day, value: 10, to: $0) }
    }
    static func hasUnconsumedFetch(_ fetchedAt: Date, receipt: String?) -> Bool {
        guard let receipt, let recorded = ISO8601DateFormatter().date(from: receipt) else { return true }
        // V28 receipts use whole ISO seconds. Compare at that same precision;
        // the original source observation and its exact date remain unchanged.
        let receiptSecond = Date(timeIntervalSince1970: fetchedAt.timeIntervalSince1970.rounded(.down))
        return receiptSecond > recorded
    }
    static func nextCheck(_ salary: SalaryAssistance, preferences: IntelligencePreferences, now: Date, latestFetch: Date?) -> Date? {
        guard preferences.salaryISPEnabled, ![.verified, .dismissed].contains(salary.ispState),
              let credit = creditDay(salary), credit <= now else { return nil }
        let rule = BackgroundScheduleRule.selectedWeekdays(weekdays: BackgroundScheduleConfiguration.allWeekdays, timesUTC: [preferences.salaryISPMinuteUTC])
        guard let slot = BackgroundSchedule.latestOccurrence(of: rule, at: now), let next = BackgroundSchedule.nextOccurrence(of: rule, after: now) else { return nil }
        let lastAttempt = salary.ispLastAttemptAt.flatMap { ISO8601DateFormatter().date(from: $0) }
        // A qualifying manual/monthly observation is consumed without fetching again.
        if let latestFetch, latestFetch >= credit, latestFetch <= now,
           hasUnconsumedFetch(latestFetch, receipt: salary.ispLastFetchAt) { return now }
        if let latestFetch, latestFetch >= credit, latestFetch <= now,
           BackgroundSchedule.utcCalendar.isDate(latestFetch, inSameDayAs: now) { return next }
        if let lastAttempt, BackgroundSchedule.utcCalendar.isDate(lastAttempt, inSameDayAs: now) { return next }
        return slot >= credit ? now : next
    }
    static func observation(_ snapshot: ZurichISPAccountSnapshot, for salary: SalaryAssistance) -> SalaryAssistance {
        var result = salary
        let formatter = ISO8601DateFormatter()
        guard let credit = creditDay(salary), snapshot.fetchedAt >= credit else { return result }
        result.ispLastFetchAt = formatter.string(from: snapshot.fetchedAt)
        result.ispState = .indeterminate
        let settlement = snapshot.policies.contains { ($0.pendingAllocation ?? 0) > 0 }
            ? "Zurich has recorded contributions that are awaiting fund allocation. " : ""
        guard let baseline = salary.ispBaseline, baseline.fetchedAt < credit,
              baseline.policyIDs == snapshot.policyIDs else {
            result.ispExplanation = "Holdings updated. " + settlement + "No suitable observation from before this salary is available to establish its contribution."
            return result
        }
        let earlier = Dictionary(uniqueKeysWithValues: baseline.policies.map { ($0.policyID, $0) })
        let differences = snapshot.policies.compactMap { policy -> String? in
            guard let previous = earlier[policy.policyID], previous.currency == policy.currency else { return nil }
            let change = policy.contributions.amount.value - previous.contributions.amount.value
            return policy.displayName + ": " + NSDecimalNumber(decimal: change).stringValue + " " + policy.currency
        }
        result.ispExplanation = settlement + "Reported contribution-total changes: " + differences.joined(separator: "; ") + ". These cumulative totals do not identify a salary cycle. Prices, units and valuation changes are not contribution proof."
        return result
    }
}

nonisolated enum RecurringCandidateDecision: Codable, Equatable, Sendable {
    case dismissed
    case confirmed(definitionID: String)
}

nonisolated public struct IntelligencePreferences: Codable, Equatable, Sendable {
    var workspaceID: String
    var salaryRuleIDs: Set<String> = []
    var retentionAccountID: String?
    var salaryAssistanceEnabled = true
    var salaryISPEnabled = false
    var salaryISPMinuteUTC = 0
    var lastReviewedChangeKey: String?
    var lastReviewedSections: [String: String]?
    // Optional so existing V28 preferences decode without invented decisions.
    var recurringCandidateDecisions: [String: RecurringCandidateDecision]?
    /// Optional for older backups: all accounts remain available until the
    /// owner removes one from planning. Financial accounts are never deleted.
    var excludedPlanningAccountIDs: Set<String>?
}

/// Domain-specific edit cases keep the small V28 records in one existing write
/// lane. Monthly-plan metadata is saved by FundingPlanRepository, not here.
nonisolated public enum PlanningMetadataEdit: Sendable {
    case recurring(RecurringDefinition, replacing: RecurringDefinition?)
    case confirmRecurringCandidate(RecurringDefinition, key: String, replacingPreferences: IntelligencePreferences?)
    case occurrence(RecurringOccurrence, replacing: RecurringOccurrence?)
    case reserve(ReserveDesignation, replacing: ReserveDesignation?)
    case removeReserve(ReserveDesignation)
    case salary(SalaryAssistance, replacing: SalaryAssistance?)
    case preferences(IntelligencePreferences, replacing: IntelligencePreferences?)
    var workspaceID: String {
        switch self {
        case .recurring(let value, _): value.workspaceID
        case .confirmRecurringCandidate(let value, _, _): value.workspaceID
        case .occurrence(let value, _): value.workspaceID
        case .reserve(let value, _), .removeReserve(let value): value.workspaceID
        case .salary(let value, _): value.workspaceID
        case .preferences(let value, _): value.workspaceID
        }
    }
    func apply(to snapshot: inout FinancialIntelligenceSnapshot) throws {
        guard workspaceID == snapshot.workspaceID else { throw FinancialIntelligenceError.invalidRecord }
        switch self {
        case .recurring(let value, let expected):
            guard snapshot.recurring.first(where: { $0.id == value.id }) == expected else { throw FinancialIntelligenceError.staleReview }
            snapshot.recurring.removeAll { $0.id == value.id }; snapshot.recurring.append(value); snapshot.recurring.sort { $0.id < $1.id }
        case .confirmRecurringCandidate(let value, let key, let expected):
            guard snapshot.preferences == expected, !snapshot.recurring.contains(where: { $0.id == value.id }),
                  expected?.recurringCandidateDecisions?[key] == nil else { throw FinancialIntelligenceError.staleReview }
            var preferences = expected ?? .init(workspaceID: workspaceID)
            var decisions = preferences.recurringCandidateDecisions ?? [:]
            decisions[key] = .confirmed(definitionID: value.id)
            preferences.recurringCandidateDecisions = decisions
            snapshot.preferences = preferences
            snapshot.recurring.append(value); snapshot.recurring.sort { $0.id < $1.id }
        case .occurrence(let value, let expected):
            guard snapshot.occurrences.first(where: { $0.id == value.id }) == expected else { throw FinancialIntelligenceError.staleReview }
            snapshot.occurrences.removeAll { $0.id == value.id }; snapshot.occurrences.append(value); snapshot.occurrences.sort { $0.id < $1.id }
        case .reserve(let value, let expected):
            guard snapshot.reserves.first(where: { $0.id == value.id }) == expected else { throw FinancialIntelligenceError.staleReview }
            snapshot.reserves.removeAll { $0.id == value.id }; snapshot.reserves.append(value); snapshot.reserves.sort { $0.id < $1.id }
        case .removeReserve(let value):
            guard snapshot.reserves.first(where: { $0.id == value.id }) == value,
                  !snapshot.plans.contains(where: { $0.contributions.contains { $0.designationID == value.id } }) else { throw FinancialIntelligenceError.staleReview }
            snapshot.reserves.removeAll { $0.id == value.id }
        case .salary(let value, let expected):
            guard snapshot.salaries.first(where: { $0.id == value.id }) == expected else { throw FinancialIntelligenceError.staleReview }
            snapshot.salaries.removeAll { $0.id == value.id }; snapshot.salaries.append(value); snapshot.salaries.sort { $0.id < $1.id }
        case .preferences(let value, let expected):
            guard snapshot.preferences == expected else { throw FinancialIntelligenceError.staleReview }
            snapshot.preferences = value
        }
    }
}

nonisolated enum PlanningMetadataValidation {
    static func referencedTransactionIDs(_ snapshot: FinancialIntelligenceSnapshot) -> Set<String> {
        Set(snapshot.occurrences.flatMap(\.transactionIDs) + snapshot.salaries.map(\.transactionID) +
            snapshot.plans.flatMap { $0.datedAdjustments.flatMap { $0.transactionIDs ?? [] } + ($0.transfers ?? []).flatMap { $0.transactionIDs ?? [] } })
    }
    static func validateFunding(_ plan: FundingPlanDTO, accounts: [AccountDTO]) throws {
        for (billID, accountID) in plan.assistance?.billFundingAccounts ?? [:] {
            guard let bill = plan.commitments.first(where: { $0.id == billID }),
                  accounts.contains(where: { $0.id == accountID && $0.workspaceId == plan.workspaceId && $0.accountType == "bank" && $0.nativeCurrency == bill.amountCurrency }) else { throw FinancialIntelligenceError.invalidRecord }
        }
        let replacements = plan.assistance?.datedAdjustments.compactMap(\.replacesCommitmentID) ?? []
        guard Set(replacements).count == replacements.count else { throw FinancialIntelligenceError.invalidRecord }
        for adjustment in plan.assistance?.datedAdjustments ?? [] {
            if let id = adjustment.replacesCommitmentID {
                guard let bill = plan.commitments.first(where: { $0.id == id }), adjustment.cardAccountID != nil,
                      bill.fundingAccountId == adjustment.cardAccountID, bill.amountCurrency == adjustment.amount.currency else { throw FinancialIntelligenceError.invalidRecord }
            }
        }
    }
    static func validate(_ snapshot: FinancialIntelligenceSnapshot, accounts: [AccountDTO], facts: [MovementValidation.Fact], cardStatements: [String: (accountID: String, currency: String)], salaryStatements: [SalaryStatementDTO] = []) throws {
        let accountMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        let factsByID = Dictionary(uniqueKeysWithValues: facts.map { ($0.id, $0) })
        let workspace = snapshot.workspaceID
        func bank(_ id: String, currency: String) -> Bool {
            accountMap[id]?.workspaceId == workspace && accountMap[id]?.accountType == "bank" && accountMap[id]?.nativeCurrency == currency
        }
        func date(_ value: String?) -> Bool { value.map { (try? StatementDate(canonical: $0)) != nil } ?? true }
        func require(_ condition: Bool) throws { if !condition { throw FinancialIntelligenceError.invalidRecord } }
        for value in snapshot.recurring {
            try require(value.workspaceID == workspace && !value.id.isEmpty && !value.title.trimmingCharacters(in: .whitespaces).isEmpty && !value.revisions.isEmpty && date(value.endsOn))
            try require(Set(value.revisions.map(\.effectiveFrom)).count == value.revisions.count)
            for revision in value.revisions {
                try revision.amount.validated()
                try require(date(revision.effectiveFrom) && (1...31).contains(revision.dueDay) && bank(value.accountID, currency: revision.amount.currency))
                try require(value.endsOn.map { revision.effectiveFrom <= $0 } ?? true)
            }
            try require(value.predicates.allSatisfy { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        }
        let definitions = Dictionary(uniqueKeysWithValues: snapshot.recurring.map { ($0.id, $0) })
        var occurrenceLegs: Set<String> = []
        for value in snapshot.occurrences {
            guard let definition = definitions[value.definitionID], let day = try? StatementDate(canonical: value.dueDate), let revision = definition.revision(on: day) else { throw FinancialIntelligenceError.invalidRecord }
            try require(value.workspaceID == workspace && value.id == value.definitionID + ":" + value.dueDate && Set(value.transactionIDs).count == value.transactionIDs.count)
            try require(definition.endsOn.map { value.dueDate <= $0 } ?? true)
            if let amount = value.amountOverride { try amount.validated(); try require(amount.currency == revision.amount.currency) }
            for id in value.transactionIDs {
                guard let fact = factsByID[id] else { throw FinancialIntelligenceError.invalidRecord }
                try require(occurrenceLegs.insert(id).inserted && fact.isTrusted && fact.workspaceId == workspace && fact.accountId == definition.accountID && fact.nativeCurrency == revision.amount.currency && ["debit", "credit"].contains(fact.direction))
            }
        }
        var cashAccounts: Set<String> = []
        for value in snapshot.reserves {
            try value.target.validated()
            try require(value.workspaceID == workspace && !value.id.isEmpty && !value.title.trimmingCharacters(in: .whitespaces).isEmpty && date(value.planningBalanceDate) && date(value.availableOn))
            if value.kind == .accountCash {
                try require(value.accountID.map { bank($0, currency: value.target.currency) && cashAccounts.insert($0).inserted } == true && value.planningBalance == nil && value.planningBalanceDate == nil)
            } else {
                try require(value.accountID == nil)
                if let amount = value.planningBalance { try amount.validated(); try require(amount.currency == value.target.currency && value.planningBalanceDate != nil) }
                else { try require(value.planningBalanceDate == nil) }
            }
        }
        for value in snapshot.salaries {
            guard let fact = factsByID[value.transactionID], let day = try? StatementDate(canonical: value.financialDate), let month = try? SelectedStatementMonth(canonical: value.targetMonth) else { throw FinancialIntelligenceError.invalidRecord }
            let nextYear = day.month == 12 ? day.year + 1 : day.year, nextMonth = day.month == 12 ? 1 : day.month + 1
            let targetMatches = value.planningBasis == .creditMonth ? (month.year == day.year && month.month == day.month) : (month.year == nextYear && month.month == nextMonth)
            try require(value.workspaceID == workspace && fact.workspaceId == workspace && fact.isTrusted && fact.financialDate == value.financialDate && fact.direction == "credit" && fact.amountMinor > 0 && bank(fact.accountId, currency: fact.nativeCurrency) && targetMatches && date(value.ispBaselineAsOf))
            for iso in [value.ispLastAttemptAt, value.ispLastFetchAt].compactMap({ $0 }) { try require(ISO8601DateFormatter().date(from: iso) != nil) }
            if let baseline = value.ispBaseline {
                try baseline.validate(expectedPolicyIDs: baseline.policyIDs, now: Date())
                try require(SalaryISPVerification.creditDay(value).map { baseline.fetchedAt < $0 } == true)
            }
        }
        if let preferences = snapshot.preferences {
            try require(preferences.workspaceID == workspace && (0..<1440).contains(preferences.salaryISPMinuteUTC))
            for id in preferences.excludedPlanningAccountIDs ?? [] {
                try require(accountMap[id]?.workspaceId == workspace && ["bank", "credit_card"].contains(accountMap[id]?.accountType ?? ""))
            }
            if let account = preferences.retentionAccountID { try require(bank(account, currency: "QAR")) }
            for (key, decision) in preferences.recurringCandidateDecisions ?? [:] {
                try require(key.count == 64 && key.allSatisfy { "0123456789abcdef".contains($0) })
                if case .confirmed(let id) = decision { try require(snapshot.recurring.contains { $0.id == id && $0.workspaceID == workspace }) }
            }
        }
        var matchedPlanningLegs = occurrenceLegs
        for value in snapshot.plans {
            try require(value.workspaceID == workspace && (try? SelectedStatementMonth(canonical: value.month)) != nil && Set(value.appliedSalaryIDs).count == value.appliedSalaryIDs.count)
            if let link = value.payslipFunding {
                guard let source = salaryStatements.first(where: { $0.id == link.statementID }),
                      source.workspaceId == workspace, source.documentKindCode == "regular_salary", source.financialPeriodISO == value.month,
                      source.sourceFingerprintAlgorithm == link.fingerprintAlgorithm, source.sourceFingerprintDigest == link.fingerprintDigest,
                      source.nativeCurrency == "QAR", source.printedNetDecimal == link.net.decimal, link.net.currency == source.nativeCurrency,
                      bank(link.accountID, currency: "QAR") else { throw FinancialIntelligenceError.invalidRecord }
                try link.net.validated()
                if let acknowledgement = link.balanceAcknowledgement {
                    try acknowledgement.amount.validated(nonnegative: false)
                    try require(!acknowledgement.balanceID.isEmpty && acknowledgement.amount.currency == "QAR" && date(acknowledgement.financialDate))
                }
            }
            if let cycle = value.salaryCycle {
                try cycle.validated(month: value.month)
                if let salaryID = cycle.receivedSalaryID {
                    try require(value.appliedSalaryIDs.contains(salaryID) && snapshot.salaries.contains { $0.id == salaryID && $0.planningBasis == .creditMonth && $0.financialDate == cycle.payday })
                }
            }
            if let allowance = value.allowance {
                try allowance.validated()
                try require(value.allowanceAccountID.map { bank($0, currency: allowance.currency) } == true)
            } else { try require(value.allowanceAccountID == nil) }
            try require(Set(value.contributions.map(\.designationID)).count == value.contributions.count)
            for contribution in value.contributions {
                try contribution.amount.validated()
                guard let target = snapshot.reserves.first(where: { $0.id == contribution.designationID }) else { throw FinancialIntelligenceError.invalidRecord }
                try require(contribution.amount.currency == target.target.currency && bank(contribution.fundingAccountID, currency: contribution.amount.currency) && date(contribution.dueDate))
            }
            for adjustment in value.datedAdjustments {
                try adjustment.amount.validated(); try require(bank(adjustment.accountID, currency: adjustment.amount.currency) && date(adjustment.date) && !adjustment.title.isEmpty)
                if let card = adjustment.cardAccountID {
                    try require(accountMap[card]?.workspaceId == workspace && accountMap[card]?.accountType == "credit_card" && accountMap[card]?.nativeCurrency == adjustment.amount.currency && adjustment.kind == .irregularCost && adjustment.cardStatementID?.isEmpty == false)
                    guard let statementID = adjustment.cardStatementID, let statement = cardStatements[statementID] else { throw FinancialIntelligenceError.invalidRecord }
                    try require(statement.accountID == card && statement.currency == adjustment.amount.currency)
                } else { try require(adjustment.cardStatementID == nil) }
            }
            try require(Set(value.datedAdjustments.map(\.id)).count == value.datedAdjustments.count)
            let cardBills = value.datedAdjustments.compactMap(\.cardStatementID)
            try require(Set(cardBills).count == cardBills.count)
            let transfers = value.transfers ?? []
            try require(Set(transfers.map(\.id)).count == transfers.count && transfers.filter { $0.sent.currency != $0.received.currency }.count <= 1)
            for transfer in transfers {
                try transfer.sent.validated(); try transfer.received.validated()
                try require(transfer.fromAccountID != transfer.toAccountID && bank(transfer.fromAccountID, currency: transfer.sent.currency) && bank(transfer.toAccountID, currency: transfer.received.currency) && date(transfer.date))
                try require(transfer.sent.currency == transfer.received.currency ? transfer.sent.money() == transfer.received.money() : transfer.sent.currency == "QAR" && transfer.received.currency == "INR" && !transfer.conversionBasis.isEmpty)
            }
            for adjustment in value.datedAdjustments {
                for id in adjustment.transactionIDs ?? [] {
                    guard let fact = factsByID[id] else { throw FinancialIntelligenceError.invalidRecord }
                    try require(matchedPlanningLegs.insert(id).inserted)
                    try require(fact.workspaceId == workspace && fact.accountId == adjustment.accountID && fact.nativeCurrency == adjustment.amount.currency && fact.isTrusted)
                    try require(adjustment.kind == .expectedIncome ? fact.direction == "credit" : fact.direction == "debit")
                }
            }
            for transfer in transfers {
                for id in transfer.transactionIDs ?? [] {
                    guard let fact = factsByID[id] else { throw FinancialIntelligenceError.invalidRecord }
                    try require(matchedPlanningLegs.insert(id).inserted)
                    try require(fact.workspaceId == workspace && fact.isTrusted &&
                        (fact.accountId == transfer.fromAccountID && fact.nativeCurrency == transfer.sent.currency && fact.direction == "debit" ||
                         fact.accountId == transfer.toAccountID && fact.nativeCurrency == transfer.received.currency && fact.direction == "credit"))
                }
            }
            for id in value.appliedSalaryIDs { try require(snapshot.salaries.contains { $0.id == id && $0.targetMonth == value.month && $0.draftState == .consumed }) }
            for (id, day) in value.sourceBalanceAcknowledgements { try require(accountMap[id]?.workspaceId == workspace && date(day)) }
        }
    }
    static func replaceSavedPlan(_ plan: FundingPlanDTO, in snapshot: inout FinancialIntelligenceSnapshot) throws {
        guard plan.workspaceId == snapshot.workspaceID else { throw FinancialIntelligenceError.invalidRecord }
        snapshot.plans.removeAll { $0.month == plan.planMonthISO }
        if let value = plan.assistance {
            guard value.workspaceID == snapshot.workspaceID, value.month == plan.planMonthISO else { throw FinancialIntelligenceError.invalidRecord }
            snapshot.plans.append(value)
            for id in value.appliedSalaryIDs {
                guard let index = snapshot.salaries.firstIndex(where: { $0.id == id && $0.draftState != .dismissed }) else { throw FinancialIntelligenceError.invalidRecord }
                snapshot.salaries[index].draftState = .consumed
            }
        }
    }
    static func validatePlanLinks(_ plan: FundingPlanDTO, snapshot: FinancialIntelligenceSnapshot) throws {
        guard let assistance = plan.assistance else { return }
        guard assistance.workspaceID == plan.workspaceId, assistance.month == plan.planMonthISO,
              Set(assistance.appliedRecurringIDs.values).count == assistance.appliedRecurringIDs.count,
              Set(assistance.appliedRecurringPaid?.keys.map { $0 } ?? []) == Set(assistance.appliedRecurringIDs.keys) else { throw FinancialIntelligenceError.invalidRecord }
        if let link = assistance.payslipFunding, let acknowledgement = link.balanceAcknowledgement {
            guard let payday = assistance.salaryCycle?.recurringStart,
                  let acknowledgedDate = try? StatementDate(canonical: acknowledgement.financialDate),
                  acknowledgedDate >= payday,
                  let balance = plan.balances.first(where: { $0.id == acknowledgement.balanceID }),
                  balance.accountId == link.accountID, balance.included,
                  balance.provenanceCode == "captured_account_balance",
                  balance.nativeCurrency == acknowledgement.amount.currency,
                  balance.amountCurrency == acknowledgement.amount.currency,
                  balance.amountDecimal == acknowledgement.amount.decimal,
                  balance.financialBalanceDateISO == acknowledgement.financialDate else { throw FinancialIntelligenceError.invalidRecord }
        }
        for (billID, accountID) in assistance.billFundingAccounts ?? [:] {
            guard !accountID.isEmpty, plan.commitments.contains(where: { $0.id == billID }) else { throw FinancialIntelligenceError.invalidRecord }
        }
        for (id, date) in assistance.carriedBillDates ?? [:] {
            guard plan.commitments.contains(where: { $0.id == id }),
                  (try? StatementDate(canonical: date)) != nil else { throw FinancialIntelligenceError.invalidRecord }
        }
        for (occurrenceID, rowID) in assistance.appliedRecurringIDs {
            guard let row = plan.commitments.first(where: { $0.id == rowID }),
                  let definition = snapshot.recurring.first(where: { occurrenceID.hasPrefix($0.id + ":") }),
                  let date = try? StatementDate(canonical: String(occurrenceID.suffix(10))),
                  occurrenceID == definition.id + ":" + date.canonical,
                  assistance.includesRecurring(date),
                  let revision = definition.revision(on: date),
                  definition.endsOn.map({ date.canonical <= $0 }) ?? true,
                  row.fundingAccountId == definition.accountID, row.amountCurrency == revision.amount.currency,
                  row.dueDateISO.flatMap({ try? StatementDate(canonical: $0) }).map({ assistance.includesRecurring($0) }) == true else { throw FinancialIntelligenceError.invalidRecord }
            guard let paid = assistance.appliedRecurringPaid?[occurrenceID], paid.currency == row.amountCurrency else { throw FinancialIntelligenceError.invalidRecord }
            try paid.validated(nonnegative: false)
        }
    }

}
