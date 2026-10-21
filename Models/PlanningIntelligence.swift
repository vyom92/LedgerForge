import Foundation

/// Calendar-only mechanics. The UTC conversion is used to count calendar days,
/// never to shift a printed financial date into another time zone.

/// Owner planning amounts use the same exact native Money rules as the ledger,
/// with a portable, versioned JSON representation in the existing V28 tables.

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

/// A salary funds two different sets: bills issued since the previous payday,
/// and recurring payments due before the next payday. Source bill dates and
/// payment due dates never stand in for each other.

/// Saved with the ordinary monthly FundingPlan aggregate. An optional amount is
/// unset, not a zero target. Scenarios never enter this record implicitly.

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
    static func routeType(account: AccountDTO, productLabels: [String]) -> String? {
        guard account.accountType == "bank", ["Axis Bank", "HDFC Bank"].contains(account.institutionId ?? "") else { return nil }
        let roles = Set(productLabels.flatMap { $0.uppercased().split(whereSeparator: { !$0.isLetter }) }
            .map(String.init).filter { ["NRE", "NRO"].contains($0) })
        return roles.count == 1 ? roles.first : nil
    }

    static func permitsPlanningRoute(fromID: String, fromCurrency: String, fromDomain: String, fromRoute: String?,
                                    toID: String, toCurrency: String, toDomain: String, toRoute: String?, retentionAccountID: String?) -> Bool {
        guard fromID != toID, fromDomain == "bank", toDomain == "bank" else { return false }
        if fromCurrency == "QAR", fromID == retentionAccountID { return toCurrency == "INR" && toRoute == "NRE" }
        guard fromCurrency == "INR", toCurrency == "INR" else { return false }
        return fromRoute == "NRE" && ["NRE", "NRO"].contains(toRoute ?? "") || fromRoute == "NRO" && toRoute == "NRO"
    }

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
            // Old plans retain their previous meaning. New funding links must
            // belong to an explicit allocation contract, never an implicit edit.
            if let allocation = value.surplusAllocation {
                try require(allocation.version == 1 && !allocation.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                try require(Set(allocation.investments.map(\.id)).count == allocation.investments.count)
                func receipt(_ id: String, accountID: String, currency: String, on day: String) throws -> PlanTransfer {
                    guard let transfer = transfers.first(where: { $0.id == id }), transfer.toAccountID == accountID,
                          transfer.received.currency == currency, transfer.date <= day else { throw SurplusAllocationError.invalidFundingLink }
                    return transfer
                }
                for transfer in transfers {
                    try require(!transfer.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let mandatory = transfer.requiredIndiaFunding {
                        try mandatory.validated()
                        try require(mandatory.currency == "INR" && transfer.sent.currency == "INR" && transfer.received.currency == "INR" && mandatory.money().amount <= transfer.sent.money().amount)
                    }
                    var visited: Set<String> = [transfer.id], current = transfer
                    while let parentID = current.fundingTransferID {
                        guard visited.insert(parentID).inserted else { throw SurplusAllocationError.invalidFundingLink }
                        current = try receipt(parentID, accountID: current.fromAccountID, currency: current.sent.currency, on: current.date)
                    }
                }
                if let id = allocation.requiredIndiaTransferID {
                    try require(transfers.contains { $0.id == id && $0.sent.currency == "QAR" && $0.received.currency == "INR" && $0.fundingTransferID == nil })
                }
                if let id = allocation.keepInCBQDesignationID {
                    try require(value.contributions.contains { $0.designationID == id && $0.amount.currency == "QAR" && $0.fundingTransferID == nil })
                    try require(snapshot.reserves.contains { $0.id == id && $0.kind == .accountCash && $0.accountID == value.contributions.first(where: { $0.id == id })?.fundingAccountID })
                }
                for contribution in value.contributions {
                    if let id = contribution.fundingTransferID {
                        let transfer = try receipt(id, accountID: contribution.fundingAccountID, currency: contribution.amount.currency, on: contribution.dueDate)
                        let reserve = snapshot.reserves.first { $0.id == contribution.designationID }
                        try require(reserve?.kind == .planningDeposit || reserve?.accountID == transfer.toAccountID)
                    }
                }
                for investment in allocation.investments {
                    try investment.amount.validated(); try investment.instrument.validated(fundingCurrency: investment.amount.currency)
                    try require(!investment.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && bank(investment.fundingAccountID, currency: investment.amount.currency) && date(investment.date))
                    if let id = investment.fundingTransferID { _ = try receipt(id, accountID: investment.fundingAccountID, currency: investment.amount.currency, on: investment.date) }
                }
            } else {
                try require(value.contributions.allSatisfy { $0.fundingTransferID == nil } && transfers.allSatisfy { $0.fundingTransferID == nil && $0.requiredIndiaFunding == nil })
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

extension SalaryFundingCycle {
    nonisolated func previousSavedPayday(in metadata: FinancialIntelligenceSnapshot?) -> String? {
        metadata?.plans.first { $0.month == String(previousPayday.prefix(7)) }?.salaryCycle?.payday
    }
    nonisolated func needsPreviousBoundaryReview(in metadata: FinancialIntelligenceSnapshot?) -> Bool {
        previousSavedPayday(in: metadata).map { $0 != previousPayday } ?? false
    }
}

extension PlanAssistance {
    nonisolated func excludingHistoryAccounts(_ ids: Set<String>, reserves: [ReserveDesignation]) -> Self {
        var value = self
        value.datedAdjustments.removeAll { ids.contains($0.accountID) || $0.cardAccountID.map(ids.contains) == true }
        value.transfers?.removeAll { ids.contains($0.fromAccountID) || ids.contains($0.toAccountID) }
        value.contributions.removeAll { contribution in
            ids.contains(contribution.fundingAccountID) || reserves.first(where: { $0.id == contribution.designationID })?.accountID.map(ids.contains) == true
        }
        if value.payslipFunding.map({ ids.contains($0.accountID) }) == true { value.payslipFunding = nil }
        if value.allowanceAccountID.map(ids.contains) == true { value.allowance = nil; value.allowanceAccountID = nil }
        return value
    }
}

/// A reservation calculation over one monthly plan, never a ledger or proof of
/// funding. Each transfer owns a temporary receipt capacity. Linked intentions
/// consume that receipt instead of charging the original surplus again.
nonisolated struct SurplusAllocationCalculation: Equatable, Sendable {
    let monthlySurplus: Money
    let retainedInCBQ: Money
    /// Signed capacity still available in the selected retention account after
    /// Keep and other funded uses. Other Qatar banks cannot supply this pool.
    let remainingRetentionCapacity: Money
    let remainingByFundingSource: [String: Money]
    let requiredIndiaFundingByTransfer: [String: Money]
    let unallocated: [Money]
    /// Final native uses of surplus, including retention and existing planned
    /// costs. Moving the same cash between accounts is not another use.
    let plannedUsesByCurrency: [Money]
    /// Ordinary and optional remittance fees actually charged by this plan,
    /// reported separately from principal and final destination allocations.
    let transferCostsByCurrency: [Money]
}

nonisolated enum SurplusAllocationCalculator {
    /// Apply the retention-bank publication rule to an ordinary budget-v1
    /// worksheet without adopting an allocation envelope. A zero Keep may
    /// retain a signed deficit for the native review flow.
    static func validateUnallocatedKeep(plan: FundingPlan, accounts: [AccountDTO],
                                        preferences: IntelligencePreferences?,
                                        salaryReceipt: PayslipReceiptState? = nil) throws {
        guard plan.calculationVersion == .budgetV1, let keep = plan.keepInCBQ,
              keep.currency.code == "QAR", keep.amount >= 0 else { throw SurplusAllocationError.invalidRecord }
        guard keep.amount > 0 else { return }
        let history = Set(accounts.filter { $0.closedAtISO != nil }.map(\.id))
        let excluded = (preferences?.excludedPlanningAccountIDs ?? []).union(history)
        guard let retentionID = preferences?.retentionAccountID,
              !excluded.contains(retentionID),
              accounts.contains(where: {
                  $0.id == retentionID && $0.workspaceId == plan.workspaceID && $0.accountType == "bank"
                      && $0.nativeCurrency == "QAR" && $0.closedAtISO == nil
              }) else { throw SurplusAllocationError.invalidFundingLink }
        let otherQAR = try plan.balances.filter { $0.included && $0.nativeCurrency.code == "QAR" && $0.accountID != retentionID }
            .compactMap(\.money).reduce(Money(amount: 0, currency: "QAR")) { try $0 + $1 }
        guard plan.balances.filter(\.included).allSatisfy({ row in
            !excluded.contains(row.accountID) && accounts.contains {
                $0.id == row.accountID && $0.workspaceId == plan.workspaceID && $0.accountType == "bank"
                    && $0.nativeCurrency == row.nativeCurrency.code
            }
        }) else { throw SurplusAllocationError.incompletePlan }
        let monthly = FundingPlanCalculator.calculate(plan, excludingAccounts: excluded,
            historyOnlyAccountIDs: history, salaryReceipt: salaryReceipt)
        guard let surplus = monthly.surplusAfterObligations else { throw SurplusAllocationError.incompletePlan }
        let capacity = try surplus - keep - Money(amount: max(0, otherQAR.amount), currency: "QAR")
        guard capacity.amount >= 0 else { throw SurplusAllocationError.exceedsCapacity }
    }

    /// Publishing a positive Keep instruction requires its exact eligible bank
    /// and bank-local capacity. Calculation alone retains signed deficits for
    /// review; every canonical writer applies this same publication boundary.
    static func validatePublication(_ result: SurplusAllocationCalculation, plan: FundingPlan,
                                    accounts: [AccountDTO], preferences: IntelligencePreferences?) throws {
        guard result.retainedInCBQ.amount > 0 else { return }
        guard let retentionID = preferences?.retentionAccountID,
              preferences?.excludedPlanningAccountIDs?.contains(retentionID) != true,
              accounts.contains(where: {
                  $0.id == retentionID && $0.workspaceId == plan.workspaceID && $0.accountType == "bank"
                      && $0.nativeCurrency == "QAR" && $0.closedAtISO == nil
              }) else { throw SurplusAllocationError.invalidFundingLink }
        guard result.remainingRetentionCapacity.amount >= 0 else { throw SurplusAllocationError.exceedsCapacity }
    }

    static func calculate(plan: FundingPlan, reserves: [ReserveDesignation], accounts: [AccountDTO],
                          productLabels: [String: [String]] = [:], preferences: IntelligencePreferences?,
                          salaryReceipt: PayslipReceiptState? = nil) throws -> SurplusAllocationCalculation {
        guard let assistance = plan.assistance, let allocation = assistance.surplusAllocation,
              assistance.workspaceID == plan.workspaceID, assistance.month == plan.month.canonical,
              allocation.version == 1, !allocation.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              plan.calculationVersion == .budgetV1 else { throw SurplusAllocationError.invalidRecord }
        let history = Set(accounts.filter { $0.closedAtISO != nil }.map(\.id))
        let excluded = (preferences?.excludedPlanningAccountIDs ?? []).union(history)
        // Preserve unavailable saved inputs for review instead of silently
        // assigning their cash to another bank or using a different scope from
        // the current monthly worksheet. History-scope editing remains explicit.
        guard plan.balances.filter(\.included).allSatisfy({ row in
            !excluded.contains(row.accountID) && accounts.contains { $0.id == row.accountID && $0.workspaceId == plan.workspaceID && $0.accountType == "bank" && $0.nativeCurrency == row.nativeCurrency.code }
        }),
              (plan.qatarCommitments + plan.indiaCommitments).filter(\.included).allSatisfy({ $0.isInAccountScope(excluding: history, fundingOverrides: assistance.billFundingAccounts) }),
              assistance.payslipFunding.map({ !excluded.contains($0.accountID) }) ?? true else { throw SurplusAllocationError.incompletePlan }
        guard let obligations = try? FundingPlanCalculator.effectiveIncludedObligations(plan, excludingAccounts: excluded,
            historyOnlyAccountIDs: history) else { throw SurplusAllocationError.incompletePlan }
        let staleReviewIDs = FundingPlanCalculator.staleReviewedObligationIDs(in: plan)
        // An out-of-cycle statement review cannot replace the upcoming bill
        // or fall through as a second surplus cost. Keep both saved records
        // and require review of a remaining nonzero amount.
        guard assistance.datedAdjustments.filter({ staleReviewIDs.contains($0.id) })
            .allSatisfy({ (try? $0.amount.money().amount) == 0 }) else { throw SurplusAllocationError.incompletePlan }
        let monthly = FundingPlanCalculator.calculate(plan, excludingAccounts: excluded, historyOnlyAccountIDs: history, salaryReceipt: salaryReceipt)
        guard let surplus = monthly.surplusAfterObligations, let inr = monthly.inrAfterObligations,
              let keep = plan.keepInCBQ, let required = monthly.requiredQARPrincipal,
              let indiaNeed = monthly.indiaFundingShortfall, monthly.incompleteReasons.isEmpty else {
            throw SurplusAllocationError.incompletePlan
        }
        let transfers = assistance.transfers ?? []
        guard Set(transfers.map(\.id)).count == transfers.count,
              transfers.allSatisfy({ !$0.id.isEmpty }),
              transfers.filter({ $0.sent.currency != $0.received.currency }).count <= 1,
              Set(assistance.contributions.map(\.id)).count == assistance.contributions.count,
              Set(allocation.investments.map(\.id)).count == allocation.investments.count,
              Set(plan.balances.map(\.accountID)).count == plan.balances.count else { throw SurplusAllocationError.invalidRecord }
        var pools = ["cash:QAR": try surplus - keep, "cash:INR": inr]
        var mandatoryPools: [String: Money] = [:]
        var plannedUses = [keep.currency.code: keep]
        var transferCosts: [String: Money] = [:]
        if let fee = monthly.effectiveTransferFee, fee.amount > 0 { transferCosts[fee.currency.code] = fee }
        func recordUse(_ amount: Money) throws {
            plannedUses[amount.currency.code] = try (plannedUses[amount.currency.code] ?? Money(amount: 0, currency: amount.currency)) + amount
        }
        // The worksheet can include several Qatar balances. Supported routes
        // cannot silently move another bank's cash into the selected CBQ bank.
        let otherQAR = try plan.balances.filter { $0.included && $0.nativeCurrency.code == "QAR" && $0.accountID != preferences?.retentionAccountID }
            .compactMap(\.money).reduce(Money(amount: 0, currency: "QAR")) { try $0 + $1 }
        var retentionCapacity = try surplus - keep - Money(amount: max(0, otherQAR.amount), currency: "QAR")
        func bank(_ id: String, currency: String) throws -> AccountDTO {
            guard let account = accounts.first(where: { $0.id == id && $0.workspaceId == plan.workspaceID && $0.accountType == "bank" && $0.nativeCurrency == currency }),
                  !excluded.contains(id) else { throw SurplusAllocationError.invalidFundingLink }
            return account
        }
        // Even a zero remaining payment requires its exact reviewed paying
        // bank to remain available; an invalid link must not release capacity.
        for obligation in obligations where obligation.replacementAdjustmentID != nil {
            guard let accountID = obligation.fundingAccountID else { throw SurplusAllocationError.invalidFundingLink }
            _ = try bank(accountID, currency: obligation.money.currency.code)
        }
        var accountCapacity = Dictionary(uniqueKeysWithValues: plan.balances.filter { $0.included && $0.nativeCurrency.code == "INR" }
            .compactMap { row in row.money.map { (row.accountID, $0) } })
        var locallyReservedINR: Decimal = 0
        // Account-local known bills also constrain a native-cash source. The
        // worksheet already subtracts them from the total native capacity.
        for obligation in obligations where obligation.money.currency.code == "INR" {
            if let id = obligation.fundingAccountID, let available = accountCapacity[id] {
                accountCapacity[id] = try available - obligation.money
                locallyReservedINR += min(max(0, available.amount), obligation.money.amount)
            }
        }
        var nativeMandatoryINR = max(0, (monthly.selectedINRLiquidity?.amount ?? 0) - inr.amount - locallyReservedINR)
        func consume(_ amount: Money, accountID: String, transferID: String?, date: String) throws {
            _ = try bank(accountID, currency: amount.currency.code)
            guard amount.amount >= 0, (try? StatementDate(canonical: date)) != nil else { throw SurplusAllocationError.invalidRecord }
            let key: String
            if let transferID {
                guard let source = transfers.first(where: { $0.id == transferID }), source.toAccountID == accountID,
                      source.received.currency == amount.currency.code, source.date <= date else { throw SurplusAllocationError.invalidFundingLink }
                key = "transfer:" + transferID
            } else {
                key = "cash:" + amount.currency.code
                if amount.currency.code == "QAR" {
                    guard accountID == preferences?.retentionAccountID else { throw SurplusAllocationError.invalidFundingLink }
                    if amount.amount > 0 && retentionCapacity.amount < amount.amount { throw SurplusAllocationError.exceedsCapacity }
                    retentionCapacity = try retentionCapacity - amount
                } else if amount.currency.code == "INR" {
                    guard let available = accountCapacity[accountID] else { throw SurplusAllocationError.incompletePlan }
                    if amount.amount > 0 && available.amount < amount.amount { throw SurplusAllocationError.exceedsCapacity }
                    accountCapacity[accountID] = try available - amount
                } else { throw SurplusAllocationError.invalidFundingLink }
            }
            guard let available = pools[key], available.currency == amount.currency else { throw SurplusAllocationError.invalidFundingLink }
            if amount.amount > 0 && available.amount < amount.amount { throw SurplusAllocationError.exceedsCapacity }
            pools[key] = try available - amount
        }
        var visited: Set<String> = [], visiting: Set<String> = []
        func process(_ transfer: PlanTransfer) throws {
            if visited.contains(transfer.id) { return }
            guard visiting.insert(transfer.id).inserted else { throw SurplusAllocationError.invalidFundingLink }
            if let parentID = transfer.fundingTransferID {
                guard let parent = transfers.first(where: { $0.id == parentID }) else { throw SurplusAllocationError.invalidFundingLink }
                try process(parent)
            }
            let sent = try transfer.sent.money(), received = try transfer.received.money()
            guard sent.amount >= 0, received.amount >= 0, (try? StatementDate(canonical: transfer.date)) != nil else { throw SurplusAllocationError.invalidRecord }
            // An intention cannot replay cash already observed in its dated
            // starting balance. Actual reconciliation needs a fresh review;
            // never manufacture a second destination receipt while it is open.
            guard transfer.transactionIDs?.isEmpty ?? true,
                  plan.balances.filter({ $0.included && [transfer.fromAccountID, transfer.toAccountID].contains($0.accountID) })
                    .allSatisfy({ $0.financialBalanceDate.map { $0.canonical < transfer.date } ?? true }) else { throw SurplusAllocationError.incompletePlan }
            let from = try bank(transfer.fromAccountID, currency: sent.currency.code), to = try bank(transfer.toAccountID, currency: received.currency.code)
            guard PlanningMetadataValidation.permitsPlanningRoute(fromID: from.id, fromCurrency: from.nativeCurrency, fromDomain: from.accountType ?? "",
                fromRoute: PlanningMetadataValidation.routeType(account: from, productLabels: productLabels[from.id] ?? []),
                toID: to.id, toCurrency: to.nativeCurrency, toDomain: to.accountType ?? "",
                toRoute: PlanningMetadataValidation.routeType(account: to, productLabels: productLabels[to.id] ?? []),
                retentionAccountID: preferences?.retentionAccountID) else { throw SurplusAllocationError.unsupportedRoute }
            guard FundingPlanCalculator.transferPrincipal(received: received, fromCurrency: sent.currency.code, plan: plan) == sent else {
                throw SurplusAllocationError.invalidFundingLink
            }
            var debit = sent, receipt = received
            var mandatoryReceipt = try Money(amount: 0, currency: "INR")
            if sent.currency != received.currency {
                guard !transfer.conversionBasis.isEmpty else { throw SurplusAllocationError.invalidRecord }
                if required.amount > 0 {
                    guard allocation.requiredIndiaTransferID == transfer.id, transfer.fundingTransferID == nil,
                          sent.amount >= required.amount, received.amount >= indiaNeed.amount else { throw SurplusAllocationError.invalidFundingLink }
                    debit = try sent - required; receipt = try received - indiaNeed
                    mandatoryReceipt = indiaNeed
                } else {
                    guard allocation.requiredIndiaTransferID == nil else { throw SurplusAllocationError.invalidFundingLink }
                    if sent.amount > 0 {
                        debit = try debit + plan.configuredTransferFee
                        let fee = plan.configuredTransferFee
                        transferCosts[fee.currency.code] = try (transferCosts[fee.currency.code] ?? Money(amount: 0, currency: fee.currency)) + fee
                    }
                }
            } else if allocation.requiredIndiaTransferID == transfer.id { throw SurplusAllocationError.invalidFundingLink }
            if let value = transfer.requiredIndiaFunding {
                let amount = try value.money()
                guard amount.currency.code == "INR", sent.currency.code == "INR", received.currency.code == "INR",
                      amount.amount >= 0, amount.amount <= sent.amount else { throw SurplusAllocationError.invalidFundingLink }
                if let parent = transfer.fundingTransferID {
                    guard let available = mandatoryPools[parent], available.amount >= amount.amount else { throw SurplusAllocationError.invalidFundingLink }
                    mandatoryPools[parent] = try available - amount
                } else {
                    guard let available = accountCapacity[from.id], nativeMandatoryINR >= amount.amount,
                          available.amount >= amount.amount else { throw SurplusAllocationError.exceedsCapacity }
                    accountCapacity[from.id] = try available - amount
                    nativeMandatoryINR -= amount.amount
                }
                mandatoryReceipt = amount
                debit = try debit - amount; receipt = try receipt - amount
            }
            try consume(debit, accountID: from.id, transferID: transfer.fundingTransferID, date: transfer.date)
            pools["transfer:" + transfer.id] = receipt
            mandatoryPools[transfer.id] = mandatoryReceipt
            visiting.remove(transfer.id); visited.insert(transfer.id)
        }
        if let id = allocation.requiredIndiaTransferID, !transfers.contains(where: { $0.id == id }) { throw SurplusAllocationError.invalidFundingLink }
        for transfer in transfers { try process(transfer) }
        if let id = allocation.keepInCBQDesignationID {
            guard let reserve = reserves.first(where: { $0.id == id && $0.workspaceID == plan.workspaceID }),
                  reserve.kind == .accountCash, reserve.accountID == preferences?.retentionAccountID,
                  let contribution = assistance.contributions.first(where: { $0.id == id }),
                  contribution.fundingAccountID == reserve.accountID, contribution.amount.currency == "QAR",
                  contribution.fundingTransferID == nil else { throw SurplusAllocationError.invalidFundingLink }
        }
        for contribution in assistance.contributions {
            guard let reserve = reserves.first(where: { $0.id == contribution.designationID && $0.workspaceID == plan.workspaceID }),
                  reserve.target.currency == contribution.amount.currency else { throw SurplusAllocationError.invalidFundingLink }
            var debit = try contribution.amount.money()
            guard debit.amount >= 0 else { throw SurplusAllocationError.invalidRecord }
            var fundingID = contribution.fundingAccountID
            if let transferID = contribution.fundingTransferID {
                guard let transfer = transfers.first(where: { $0.id == transferID }),
                      fundingID == transfer.toAccountID,
                      reserve.kind == .planningDeposit ? fundingID == transfer.toAccountID : reserve.accountID == transfer.toAccountID else {
                    throw SurplusAllocationError.invalidFundingLink
                }
                fundingID = transfer.toAccountID
            } else if reserve.kind == .accountCash && reserve.accountID != fundingID {
                // A different bank needs an explicit supported movement.
                throw SurplusAllocationError.invalidFundingLink
            }
            if allocation.keepInCBQDesignationID == contribution.designationID {
                debit = try Money(amount: max(0, debit.amount - keep.amount), currency: debit.currency)
            }
            try consume(debit, accountID: fundingID, transferID: contribution.fundingTransferID, date: contribution.dueDate)
            try recordUse(debit)
        }
        for investment in allocation.investments {
            guard !investment.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SurplusAllocationError.invalidRecord }
            try investment.instrument.validated(fundingCurrency: investment.amount.currency)
            let amount = try investment.amount.money()
            try consume(amount, accountID: investment.fundingAccountID, transferID: investment.fundingTransferID, date: investment.date)
            try recordUse(amount)
        }
        // Existing discretionary choices cannot become spendable a second time.
        if let allowance = assistance.allowance {
            guard let accountID = assistance.allowanceAccountID else { throw SurplusAllocationError.invalidFundingLink }
            let amount = try allowance.money()
            try consume(amount, accountID: accountID, transferID: nil, date: plan.recurringEnd.canonical)
            try recordUse(amount)
        }
        let consumedReplacements = Set(obligations.compactMap(\.replacementAdjustmentID))
        for cost in assistance.datedAdjustments where cost.kind != .expectedIncome {
            guard cost.transactionIDs?.isEmpty ?? true else { throw SurplusAllocationError.incompletePlan }
            if consumedReplacements.contains(cost.id) || staleReviewIDs.contains(cost.id) { continue }
            let amount = try cost.amount.money()
            if amount.amount == 0 {
                // A deliberately reviewed zero separate cash need reserves no
                // opening cash; it must not require an included zero balance.
                _ = try bank(cost.accountID, currency: amount.currency.code)
                guard (try? StatementDate(canonical: cost.date)) != nil else { throw SurplusAllocationError.invalidRecord }
                continue
            }
            try consume(amount, accountID: cost.accountID, transferID: nil, date: cost.date)
            try recordUse(amount)
        }
        var totals: [String: Money] = [:]
        for amount in pools.values {
            totals[amount.currency.code] = try (totals[amount.currency.code] ?? Money(amount: 0, currency: amount.currency)) + amount
        }
        return .init(monthlySurplus: surplus, retainedInCBQ: keep, remainingRetentionCapacity: retentionCapacity,
                     remainingByFundingSource: pools,
                     requiredIndiaFundingByTransfer: mandatoryPools,
                     unallocated: totals.keys.sorted().compactMap { totals[$0] },
                     plannedUsesByCurrency: plannedUses.keys.sorted().compactMap { plannedUses[$0] },
                     transferCostsByCurrency: transferCosts.keys.sorted().compactMap { transferCosts[$0] })
    }
}
