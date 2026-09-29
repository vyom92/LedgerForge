import Foundation
import CryptoKit

nonisolated struct PlanningAccountAnchor: Identifiable, Sendable {
    let id: String
    let title: String
    let currency: String
    let domain: String
    let amount: Decimal?
    let date: StatementDate?
    let historyOnly: Bool
}

nonisolated struct RecurringPaymentProjection: Identifiable, Sendable {
    let definition: RecurringDefinition
    let date: StatementDate
    let expected: Decimal
    let paid: Decimal
    let currency: String
    let actualIDs: Set<String>
    let suggestionIDs: [String]
    let isWaived: Bool
    let hasCoverage: Bool
    var plannedDueDate: StatementDate? = nil
    var forecastDate: StatementDate { plannedDueDate ?? date }
    var id: String { definition.id + ":" + date.canonical }
    var remaining: Decimal { isWaived ? 0 : max(0, expected - paid) }
    var status: String {
        if isWaived { return "Waived for this occurrence" }
        if paid > expected { return "Paid above the planned amount" }
        if paid == expected { return "Matched payment" }
        if paid > 0 { return "Partly matched" }
        if paid < 0 { return "Refund exceeds matched payment · review" }
        return hasCoverage ? "No matched payment in covered period" : "Not observed · coverage incomplete"
    }
}

nonisolated struct RecurringCandidate: Identifiable, Sendable {
    let id: String
    let accountID: String
    let narration: String
    let amount: Decimal
    let currency: String
    let dates: [StatementDate]
    let transactionIDs: [String]
    let decision: RecurringCandidateDecision?
}

nonisolated struct PlanningCashEvent: Identifiable, Sendable {
    enum Kind: String, Sendable { case actual = "Recorded", commitment = "Commitment", contribution = "Reserve contribution", income = "Planned income", provision = "Planned spending", allowance = "Allowance", transfer = "Planned own transfer" }
    let id: String
    let accountID: String
    let date: StatementDate
    let title: String
    let change: Decimal
    let kind: Kind
    let transactionIDs: Set<String>
}

nonisolated struct PlanningBalancePoint: Identifiable, Sendable {
    let id: String
    let date: StatementDate
    let balance: Decimal
    let isForecast: Bool
    let title: String
    let transactionIDs: Set<String>
}

nonisolated struct AccountRunway: Identifiable, Sendable {
    let anchor: PlanningAccountAnchor
    let points: [PlanningBalancePoint]
    let events: [PlanningCashEvent]
    let reserveFloor: Decimal
    let limitations: [String]
    var id: String { anchor.id }
    var lowestBalance: Decimal? { points.map(\.balance).min() }
    var endingBalance: Decimal? { points.last?.balance }
    var firstShortfall: PlanningBalancePoint? { points.first { $0.balance < 0 } }
    var reserveGap: Decimal? { lowestBalance.map { max(0, reserveFloor - $0) } }
    var conditionalHeadroom: Decimal? { lowestBalance.map { $0 - reserveFloor } }
}

nonisolated struct ReserveProgress: Identifiable, Sendable {
    let designation: ReserveDesignation
    let fundedAfterBills: Decimal?
    let proposedContribution: Decimal
    let basis: String
    var id: String { designation.id }
    var target: Decimal { (try? designation.target.money().amount) ?? 0 }
    var gap: Decimal? { fundedAfterBills.map { max(0, target - $0) } }
}

nonisolated struct PlanningScenario: Equatable, Sendable {
    var accountID = ""
    var extraIncome: Decimal = 0
    var extraCost: Decimal = 0
    var contributionChange: Decimal = 0
    var paymentDelayDays = 0
    var isActive: Bool { extraIncome != 0 || extraCost != 0 || contributionChange != 0 || paymentDelayDays != 0 }
}

nonisolated struct PlanningProjection: Sendable {
    let month: SelectedStatementMonth
    let start: StatementDate
    let end: StatementDate
    let recurring: [RecurringPaymentProjection]
    let candidates: [RecurringCandidate]
    let runways: [AccountRunway]
    let reserves: [ReserveProgress]
    let actualSpending: [String: Decimal]
    let actualTransactionIDs: [String: Set<String>]
    let plannedCommitments: [String: Decimal]
    let unmatchedSpendingCount: Int
    let cardNeeds: [String]
    let scenarioIsActive: Bool
    let calculationSeconds: Double
    var reservesComplete: Bool { !reserves.isEmpty && reserves.allSatisfy { $0.gap == 0 } }

    func investmentCapacity(accountID: String, assistance: PlanAssistance?) -> (Decimal?, [String]) {
        guard let runway = runways.first(where: { $0.id == accountID }) else { return (nil, ["Account balance unavailable."]) }
        var reasons = runway.limitations
        if !cardNeeds.isEmpty { reasons.append("Review remaining card cash needs.") }
        if !reservesComplete { reasons.append("Reserve targets are still unfunded or funding is unknown.") }
        if reserves.contains(where: { $0.designation.kind == .planningDeposit && ($0.designation.availableOn.map { $0 > start.canonical } ?? true) }) { reasons.append("Designated deposit availability is unknown or in the future.") }
        if assistance?.reserveAllocationReviewed != true { reasons.append("Choose this month’s reserve allocation, including an explicit zero if appropriate.") }
        if assistance?.allowance == nil { reasons.append("Choose a discretionary allowance.") }
        if unmatchedSpendingCount > 0 { reasons.append("Unresolved movements may change spending or upcoming needs.") }
        return reasons.isEmpty ? (runway.conditionalHeadroom, []) : (nil, Array(Set(reasons)).sorted())
    }
}

nonisolated enum PlanningIntelligence {
    /// Uses the same month-local reference and upward principal rounding as the
    /// accepted worksheet. The one configured fee stays a separate cash flow.
    static func transferPrincipal(received: Money, fromCurrency: String, plan: FundingPlan) -> Money? {
        if fromCurrency == received.currency.code { return received }
        guard fromCurrency == "QAR", received.currency.code == "INR" else { return nil }
        let rate: AlDarReturnedINRDecimal?
        if plan.referenceMode == .manual { rate = plan.planningFX.flatMap { try? AlDarReturnedINRDecimal.planningRate($0.inrPerQAR) } }
        else { rate = plan.effectiveAlDarReference.flatMap { $0.submittedQAR.amount == 1 ? $0.returnedINR : nil } }
        return try? rate?.principal(for: received, submittedQAR: Money(amount: 1, currency: "QAR"))
    }

    static func permitsPlanningRoute(from: IntelligenceAccountContext, to: IntelligenceAccountContext, retentionAccountID: String?) -> Bool {
        guard from.id != to.id, from.domain == "bank", to.domain == "bank" else { return false }
        if from.currency == "QAR", from.id == retentionAccountID { return to.currency == "INR" && to.routeType == "NRE" }
        guard from.currency == "INR", to.currency == "INR" else { return false }
        return from.routeType == "NRE" && ["NRE","NRO"].contains(to.routeType ?? "") || from.routeType == "NRO" && to.routeType == "NRO"
    }
    static func dueDate(definition: RecurringDefinition, month: SelectedStatementMonth) -> (StatementDate, RecurringRevision)? {
        // The latest revision which actually applies on its due date wins. A
        // revision effective after this month's due date first applies next month.
        for revision in definition.revisions.sorted(by: { $0.effectiveFrom > $1.effectiveFrom }) {
            guard let last = FinancialCalendar.lastDay(month), let date = try? StatementDate(year: month.year, month: month.month, day: min(revision.dueDay, last.day)),
                  revision.effectiveFrom <= date.canonical,
                  definition.endsOn.map({ date.canonical <= $0 }) ?? true else { continue }
            return (date, revision)
        }
        return nil
    }

    static func payments(metadata: FinancialIntelligenceSnapshot, rows: [SpendingSourceRow], sources: FinancialSourceContext,
                         start: StatementDate, end: StatementDate) throws -> [RecurringPaymentProjection] {
        try Task.checkCancellation()
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        let occurrenceMap = Dictionary(uniqueKeysWithValues: metadata.occurrences.map { ($0.id, $0) })
        let alreadyUsed = Set(metadata.occurrences.flatMap(\.transactionIDs))
        let accountRows = Dictionary(grouping: rows, by: \.accountID)
        var results: [RecurringPaymentProjection] = []
        var year = start.year, month = start.month
        while (year, month) <= (end.year, end.month) {
            guard let selected = try? SelectedStatementMonth(year: year, month: month) else { break }
            for definition in metadata.recurring where definition.isEnabled {
                try Task.checkCancellation()
                guard let (date, revision) = dueDate(definition: definition, month: selected), date >= start, date <= end,
                      let expectedMoney = try? revision.amount.money() else { continue }
                let saved = occurrenceMap[definition.id + ":" + date.canonical]
                let actual = (saved?.transactionIDs ?? []).compactMap { byID[$0] }
                let paid = actual.reduce(Decimal.zero) { $0 - $1.transaction.money.amount }
                let lower = FinancialCalendar.addDays(-10, to: date) ?? date, upper = FinancialCalendar.addDays(10, to: date) ?? date
                let suggestions = definition.predicates.isEmpty ? [] : try accountRows[definition.accountID, default: []].filter { row in
                    try Task.checkCancellation()
                    guard !row.isLoanOrEMI, !alreadyUsed.contains(row.id), row.isBankOut, row.currency == revision.amount.currency,
                          let day = row.date, day >= lower, day <= upper else { return false }
                    return definition.predicates.allSatisfy { predicate in
                        let text = predicate.field == .narration ? row.transaction.description : (row.transaction.reference ?? "")
                        return predicate.match == .exact ? text.caseInsensitiveCompare(predicate.text) == .orderedSame : text.range(of: predicate.text, options: .caseInsensitive) != nil
                    }
                }.map(\.id)
                results.append(.init(definition: definition, date: date, expected: (try? saved?.amountOverride?.money().amount) ?? expectedMoney.amount,
                    paid: paid, currency: revision.amount.currency, actualIDs: Set(actual.map(\.id)), suggestionIDs: suggestions,
                    isWaived: saved?.isWaived ?? false, hasCoverage: sources.hasCompleteCoverage(accountID: definition.accountID, start: lower, end: upper)))
            }
            month += 1; if month == 13 { month = 1; year += 1 }
        }
        return results.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }

    static func recurringCandidates(rows: [SpendingSourceRow], metadata: FinancialIntelligenceSnapshot) throws -> [RecurringCandidate] {
        try Task.checkCancellation()
        // Exact original narration and amount only nominate a review. They never
        // establish an obligation, a transfer role or a payment match.
        let occupied = Set(metadata.occurrences.flatMap(\.transactionIDs))
        let grouped = Dictionary(grouping: rows.filter { $0.isBankOut && !$0.isLoanOrEMI && $0.date != nil && !occupied.contains($0.id) }) {
            recurringCandidateKey(accountID: $0.accountID, currency: $0.currency, amount: $0.amount, narration: $0.transaction.description)
        }
        return try grouped.values.compactMap { values in
            try Task.checkCancellation()
            let sorted = values.sorted { $0.date! < $1.date! }, dates = sorted.compactMap(\.date)
            let months = Set(dates.map { String($0.canonical.prefix(7)) })
            guard dates.count >= 3, months.count == dates.count, dates.map(\.day).max()! - dates.map(\.day).min()! <= 5,
                  !sorted[0].transaction.description.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let first = sorted[0]
            let key = recurringCandidateKey(accountID: first.accountID, currency: first.currency, amount: first.amount, narration: first.transaction.description)
            return RecurringCandidate(id: key, accountID: first.accountID, narration: first.transaction.description,
                amount: first.amount, currency: first.currency, dates: dates, transactionIDs: sorted.map(\.id), decision: metadata.preferences?.recurringCandidateDecisions?[key])
        }.sorted { ($0.dates.count, $0.id) > ($1.dates.count, $1.id) }
    }

    static func recurringCandidateKey(accountID: String, currency: String, amount: Decimal, narration: String) -> String {
        // Length-prefix exact fields, so delimiters in source text cannot merge
        // different patterns. Earlier imports do not change a saved decision.
        let fields = [accountID, currency, NSDecimalNumber(decimal: amount).stringValue, narration]
        let encoded = fields.map { "\($0.utf8.count):\($0)" }.joined()
        return SHA256.hash(data: Data(encoded.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func project(plan: FundingPlan, anchors: [PlanningAccountAnchor], rows: [SpendingSourceRow],
                        metadata: FinancialIntelligenceSnapshot, sources: FinancialSourceContext, cards: CardStoreSnapshot,
                        today: StatementDate, scenario: PlanningScenario = .init()) throws -> PlanningProjection {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.planningProjection, count: rows.count)
        defer { GmailQualificationTiming.end(.planningProjection, started: timing, count: rows.count) }
#endif
        try Task.checkCancellation()
        let started = Date()
        let excluded = metadata.preferences?.excludedPlanningAccountIDs ?? []
        // Availability controls planning inputs, not whether an imported card
        // obligation still needs payment review.
        let cardAnchors = anchors.filter { $0.domain == "credit_card" && !$0.historyOnly }
        let anchors = anchors.filter { !excluded.contains($0.id) }
        let monthStart = plan.recurringStart
        let monthEnd = plan.recurringEnd
        let start = max(monthStart, today), end = FinancialCalendar.addDays(89, to: start)!
        let generated = try payments(metadata: metadata, rows: rows, sources: sources, start: monthStart, end: end)
        let payments = generated.map { payment -> RecurringPaymentProjection in
            guard let rowID = plan.assistance?.appliedRecurringIDs[payment.id],
                  let row = (plan.qatarCommitments + plan.indiaCommitments).first(where: { $0.id == rowID }),
                  let paidAtPrefill = try? plan.assistance?.appliedRecurringPaid?[payment.id]?.money() else { return payment }
            // The saved row was remaining cash at prefill, not a fresh obligation.
            // New actual payments reduce it; monthly edits do not change the template.
            return .init(definition: payment.definition, date: payment.date, expected: row.money.amount + paidAtPrefill.amount, paid: payment.paid,
                currency: payment.currency, actualIDs: payment.actualIDs, suggestionIDs: payment.suggestionIDs,
                isWaived: !row.included || payment.isWaived, hasCoverage: payment.hasCoverage, plannedDueDate: plan.dueDate(for: row))
        }
        let selectedPayments = payments.filter { $0.date <= monthEnd }
        let assistance = plan.assistance
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        let bankIDs = Set(anchors.filter { $0.domain == "bank" }.map(\.id))
        func funding(_ bill: FundingPlanCommitment) -> String? {
            let value = assistance?.billFundingAccounts?[bill.id] ?? bill.fundingAccountID
            return value.flatMap { bankIDs.contains($0) ? $0 : nil }
        }
        let confirmed = metadata.confirmedByTransaction
        let rowsByAccount = Dictionary(grouping: rows, by: \.accountID)
        let knownPaymentIDs = Set(metadata.occurrences.flatMap(\.transactionIDs))
        let monthRows = rows.filter { $0.date.map { $0 >= monthStart && $0 <= monthEnd } ?? false }
        let meanings = monthRows.map { row -> SpendingReviewRow in
            if confirmed[row.id] == nil, knownPaymentIDs.contains(row.id) {
                return .init(source: row, treatment: row.isBankOut ? .expense : .refund, explanation: "Owner-matched recurring payment or reversal.")
            }
            return SpendingIntelligence.interpretation(row, confirmed: confirmed[row.id])
        }
        var actual: [String: Decimal] = [:], actualIDs: [String: Set<String>] = [:]
        for value in meanings where [.expense,.refund].contains(value.treatment) {
            actual[value.source.currency, default: 0] += value.spending
            actualIDs[value.source.currency, default: []].insert(value.id)
        }
        var planned: [String: Decimal] = [:]
        for value in selectedPayments where !value.isWaived { planned[value.currency, default: 0] += value.expected }
        let representedRows = Set(payments.compactMap { assistance?.appliedRecurringIDs[$0.id] })
        let replacedBills = Set(assistance?.datedAdjustments.compactMap(\.replacesCommitmentID) ?? [])
        let genericBills = (plan.qatarCommitments + plan.indiaCommitments).filter { $0.included && !representedRows.contains($0.id) && !replacedBills.contains($0.id) }
        for value in genericBills { planned[value.money.currency.code, default: 0] += value.money.amount }
        var cardNeeds: [String] = []
        let boundaryNeedsReview = assistance?.salaryCycle?.needsPreviousBoundaryReview(in: metadata) == true
        if boundaryNeedsReview { cardNeeds.append("The previous salary date changed. Review salary funding dates before assigning bills; the stored bill window has not been silently moved.") }
        for anchor in cardAnchors {
            let statements = cards.statements.filter { $0.liabilityAccountID == anchor.id }
            let latest = statements.max { (($0.statementDate ?? $0.period?.end)?.canonical ?? "") < (($1.statementDate ?? $1.period?.end)?.canonical ?? "") }
            let selected: [CardStatement]
            if let cycle = assistance?.salaryCycle {
                // Only the source statement date establishes when a bill was
                // generated. Period ends and due dates are different evidence.
                selected = boundaryNeedsReview ? [] : statements.filter { $0.statementDate.map { cycle.includesBill(issuedOn: $0) } == true }
                let undated = statements.filter { $0.statementDate == nil && ($0.newBalance?.amount ?? 0) > 0 }
                if !undated.isEmpty {
                    cardNeeds.append("\(anchor.title): \(undated.count) statements have no bill generation date. Their salary funding and payment status need review; these balances are not added together.")
                }
                if selected.isEmpty, (latest?.newBalance?.amount ?? 0) > 0 {
                    cardNeeds.append("\(anchor.title): no bill is available for \(cycle.billRange). The earlier reported balance still needs payment-coverage review.")
                }
            } else { selected = [latest].compactMap { $0 } }
            for statement in selected {
                guard let owed = statement.newBalance, owed.amount > 0 else { continue }
                let reviewed = assistance?.datedAdjustments.contains { adjustment in
                    guard adjustment.cardAccountID == anchor.id && adjustment.cardStatementID == statement.id,
                          let amount = try? adjustment.amount.money().amount else { return false }
                    let paid = (adjustment.transactionIDs ?? []).compactMap { byID[$0] }.reduce(Decimal.zero) { $0 + $1.amount }
                    if paid >= amount { return true }
                    guard let date = try? StatementDate(canonical: adjustment.date), date >= start, date <= end,
                          let fundingAnchor = anchors.first(where: { $0.id == adjustment.accountID }), let anchorDate = fundingAnchor.date,
                          fundingAnchor.amount != nil, date > anchorDate else { return false }
                    return true
                } == true
                if !reviewed {
                    let timing = statement.dueDate.map { $0 < plan.recurringStart ? "Due before payday · review now" : "Due " + $0.presentation } ?? "Due date unknown"
                    cardNeeds.append("\(anchor.title): \(owed.currency.code) \(NSDecimalNumber(decimal: owed.amount).stringValue) on statement \(statement.statementDate?.presentation ?? "date unknown"). \(timing). Review payment coverage; statement balances may overlap and are not added together.")
                }
            }
            if statements.isEmpty { cardNeeds.append("\(anchor.title): statement balance unavailable; payment need has not been established.") }
        }
        let runways = try anchors.filter { $0.domain == "bank" }.map { anchor -> AccountRunway in
            try Task.checkCancellation()
            var notes: [String] = [], events: [PlanningCashEvent] = []
            let reserve = metadata.reserves.first { $0.kind == .accountCash && $0.accountID == anchor.id }
            var floor = (try? reserve?.target.money().amount) ?? 0
            if anchor.id == metadata.preferences?.retentionAccountID {
                floor = max(floor, plan.keepInCBQ?.amount ?? 0)
            }
            if anchor.currency == "QAR", (plan.keepInCBQ?.amount ?? 0) > 0, metadata.preferences?.retentionAccountID == nil {
                notes.append("Choose the canonical account for Keep in CBQ in Salary assistance; that floor is not yet assigned.")
            }
            guard let anchorDate = anchor.date, let opening = anchor.amount else {
                return .init(anchor: anchor, points: [], events: [], reserveFloor: floor, limitations: ["A source-owned balance and date are required."])
            }
            if anchorDate > start { notes.append("The latest balance is later than this forecast's start. Earlier cash positions are unavailable.") }
            let coverageStart = FinancialCalendar.addDays(1, to: anchorDate) ?? anchorDate
            if coverageStart < start, !sources.hasCompleteCoverage(accountID: anchor.id, start: coverageStart, end: FinancialCalendar.addDays(-1, to: start)!) {
                notes.append("Statement coverage between the balance and forecast is incomplete. Unrecorded activity is unknown.")
            }
            if !cardNeeds.isEmpty { notes.append("Card settlement needs remain subject to payment review; net worth is not available cash.") }
            for row in rowsByAccount[anchor.id, default: []] {
                try Task.checkCancellation()
                // A closing balance already includes its own date. Never replay it.
                guard let date = row.transaction.statementDate, date > anchorDate, date <= end else { continue }
                events.append(.init(id: "actual:" + row.id, accountID: anchor.id, date: date, title: row.transaction.description,
                    change: row.transaction.money.amount, kind: .actual, transactionIDs: [row.id]))
            }
            if let payslip = assistance?.payslipFunding, payslip.accountID == anchor.id {
                let receipt = PayslipReceiptState.resolve(plan: plan, transactions: rows.map(\.transaction), excludedAccounts: excluded)
                if case .bankCredit = receipt {
                    // The actual credit above is replayed only when later than
                    // the canonical balance. Never add an expected copy.
                } else if receipt == .pending, let payday = assistance?.salaryCycle?.recurringStart,
                          payday >= start, payday > anchorDate, payday <= end, let net = try? payslip.net.money() {
                    events.append(.init(id: "payslip:" + payslip.statementID, accountID: anchor.id, date: payday,
                        title: "Expected net salary from payslip", change: net.amount, kind: .income, transactionIDs: []))
                    notes.append("Payslip income is expected; bank receipt is not yet recorded.")
                } else {
                    notes.append("Payslip salary receipt needs current bank evidence. The worksheet's captured-balance acknowledgement does not update this source balance or add a forecast credit.")
                }
            }
            for payment in payments where payment.definition.accountID == anchor.id && payment.remaining > 0 {
                guard payment.forecastDate >= start else {
                    if !payment.isWaived { notes.append("\(payment.definition.title) on \(payment.date.presentation) needs payment review before carrying an amount forward.") }
                    continue
                }
                guard payment.forecastDate > anchorDate else {
                    notes.append("\(payment.definition.title) is on or before the balance date; its inclusion is uncertain until matched.")
                    continue
                }
                let delay = scenario.accountID == anchor.id ? scenario.paymentDelayDays : 0
                let date = FinancialCalendar.addDays(delay, to: payment.forecastDate) ?? payment.forecastDate
                if date <= end {
                    events.append(.init(id: payment.id, accountID: anchor.id, date: max(date, start), title: payment.definition.title,
                        change: -payment.remaining, kind: .commitment, transactionIDs: payment.actualIDs))
                }
            }
            for bill in genericBills where funding(bill) == anchor.id {
                guard let date = plan.dueDate(for: bill), date >= start, date > anchorDate, date <= end else {
                    notes.append("\(bill.label) needs a future due date and confirmation that its amount remains unpaid."); continue
                }
                events.append(.init(id: bill.id, accountID: anchor.id, date: date, title: bill.label, change: -bill.money.amount, kind: .commitment, transactionIDs: []))
            }
            for contribution in assistance?.contributions ?? [] {
                guard let destination = metadata.reserves.first(where: { $0.id == contribution.designationID }),
                      let date = try? StatementDate(canonical: contribution.dueDate), date >= start, date <= end, date > anchorDate,
                      let amount = try? contribution.amount.money().amount else { continue }
                if contribution.fundingAccountID == anchor.id && destination.accountID != anchor.id {
                    events.append(.init(id: "contribution-out:" + contribution.id, accountID: anchor.id, date: date, title: destination.title,
                        change: -amount, kind: .contribution, transactionIDs: []))
                }
                if destination.accountID == anchor.id && contribution.fundingAccountID != anchor.id {
                    events.append(.init(id: "contribution-in:" + contribution.id, accountID: anchor.id, date: date, title: destination.title,
                        change: amount, kind: .contribution, transactionIDs: []))
                }
            }
            for adjustment in assistance?.datedAdjustments ?? [] where adjustment.accountID == anchor.id {
                let matched = (adjustment.transactionIDs ?? []).compactMap { byID[$0] }
                let settled = matched.reduce(Decimal.zero) { $0 + $1.amount }
                guard let date = try? StatementDate(canonical: adjustment.date), date > anchorDate, date >= start, date <= end,
                      let money = try? adjustment.amount.money() else {
                    notes.append("\(adjustment.title) is not after the dated balance; it is not added again."); continue
                }
                events.append(.init(id: adjustment.id, accountID: anchor.id, date: date, title: adjustment.title,
                    change: (adjustment.kind == .expectedIncome ? 1 : -1) * max(0, money.amount - settled),
                    kind: adjustment.kind == .expectedIncome ? .income : .provision, transactionIDs: []))
            }
            for transfer in assistance?.transfers ?? [] {
                guard let date = try? StatementDate(canonical: transfer.date), date > anchorDate, date >= start, date <= end else { continue }
                let linked = (transfer.transactionIDs ?? []).compactMap { byID[$0] }
                if transfer.fromAccountID == anchor.id, let sent = try? transfer.sent.money() {
                    let paid = linked.filter { $0.accountID == anchor.id && $0.isBankOut }.reduce(Decimal.zero) { $0 + $1.amount }
                    let remaining = max(0, sent.amount - paid)
                    if remaining > 0 {
                        events.append(.init(id: "transfer-out:" + transfer.id, accountID: anchor.id, date: date, title: "Planned transfer to " + (sources.accounts.first { $0.id == transfer.toAccountID }?.title ?? "own account"), change: -remaining, kind: .transfer, transactionIDs: []))
                        if transfer.sent.currency != transfer.received.currency {
                            events.append(.init(id: "transfer-fee:" + transfer.id, accountID: anchor.id, date: date, title: "One planned remittance fee", change: -plan.configuredTransferFee.amount, kind: .provision, transactionIDs: []))
                        }
                    }
                }
                if transfer.toAccountID == anchor.id, let received = try? transfer.received.money() {
                    let paid = linked.filter { $0.accountID == anchor.id && $0.isBankIn }.reduce(Decimal.zero) { $0 + $1.amount }
                    events.append(.init(id: "transfer-in:" + transfer.id, accountID: anchor.id, date: date, title: "Planned own-account funding", change: max(0, received.amount - paid), kind: .transfer, transactionIDs: []))
                }
            }
            if assistance?.allowanceAccountID == anchor.id, let money = try? assistance?.allowance?.money(), monthEnd > anchorDate, monthEnd >= start {
                let spent = meanings.filter { $0.source.accountID == anchor.id && !knownPaymentIDs.contains($0.id) }.reduce(Decimal.zero) { $0 + $1.spending }
                events.append(.init(id: "allowance", accountID: anchor.id, date: monthEnd, title: "Unspent discretionary allowance",
                    change: -max(0, money.amount - spent), kind: .allowance, transactionIDs: []))
                if spent > money.amount { notes.append("Recorded discretionary spending exceeds this allowance by \(NSDecimalNumber(decimal: spent - money.amount).stringValue) \(anchor.currency).") }
            }
            if scenario.isActive && scenario.accountID == anchor.id {
                events.append(.init(id: "scenario", accountID: anchor.id, date: max(start, FinancialCalendar.addDays(1, to: anchorDate)!), title: "Unsaved what-if change",
                    change: scenario.extraIncome - scenario.extraCost - scenario.contributionChange, kind: .provision, transactionIDs: []))
            }
            if genericBills.contains(where: { funding($0) == nil && $0.money.currency.code == anchor.currency }) { notes.append("A commitment in this currency has no funding bank. A related card is not a funding account.") }
            if payments.contains(where: { excluded.contains($0.definition.accountID) && $0.currency == anchor.currency && $0.remaining > 0 }) {
                notes.append("A recurring payment uses an account removed from planning. Add the account back or reassign the commitment; its cost has not disappeared.")
            }
            if assistance?.contributions.contains(where: { excluded.contains($0.fundingAccountID) }) == true || assistance?.datedAdjustments.contains(where: { excluded.contains($0.accountID) }) == true || assistance?.transfers?.contains(where: { excluded.contains($0.fromAccountID) || excluded.contains($0.toAccountID) }) == true || assistance?.allowanceAccountID.map({ excluded.contains($0) }) == true {
                notes.append("Saved funding uses an account removed from planning. Review account funding before relying on this forecast.")
            }
            if assistance?.sourceBalanceAcknowledgements[anchor.id] == anchorDate.canonical { notes.append("You chose this dated balance as a planning assumption. It is not a live balance.") }
            if assistance?.reserveAllocationReviewed != true { notes.append("No monthly reserve allocation selected.") }
            events.sort { ($0.date, $0.kind == .actual ? 0 : 1, $0.id) < ($1.date, $1.kind == .actual ? 0 : 1, $1.id) }
            var balance = opening
            var points: [PlanningBalancePoint] = [.init(id: "anchor:" + anchor.id, date: anchorDate, balance: opening, isForecast: false, title: "Statement balance", transactionIDs: [])]
            for event in events {
                balance += event.change
                points.append(.init(id: event.id, date: event.date, balance: balance, isForecast: event.kind != .actual,
                    title: event.title, transactionIDs: event.transactionIDs))
            }
            points.append(.init(id: "end:" + anchor.id, date: max(end, anchorDate), balance: balance, isForecast: true, title: "Conditional end balance", transactionIDs: []))
            // Reconcile all later actuals from the source anchor, then show and
            // measure only this forecast's horizon, carrying its opening value.
            if let preceding = points.last(where: { $0.date < start }) {
                points.removeAll { $0.date < start }
                points.insert(.init(id: "carried:" + anchor.id, date: start, balance: preceding.balance,
                    isForecast: true, title: "Balance carried into forecast; subject to source coverage", transactionIDs: []), at: 0)
            }
            return .init(anchor: anchor, points: points, events: events, reserveFloor: floor, limitations: Array(Set(notes)).sorted())
        }
        let reserves = metadata.reserves.map { designation -> ReserveProgress in
            let contribution = assistance?.contributions.first { $0.designationID == designation.id }.flatMap { try? $0.amount.money().amount } ?? 0
            if designation.kind == .planningDeposit {
                return .init(designation: designation, fundedAfterBills: try? designation.planningBalance?.money().amount,
                    proposedContribution: contribution, basis: designation.planningBalance == nil ? "Funding unknown · no supported deposit balance" : "Owner-entered planning balance as of \(designation.planningBalanceDate ?? "unknown date"); liquidity \(designation.availableOn ?? "unknown")")
            }
            let runway = runways.first { $0.id == designation.accountID }
            // Proposed transfers are a separate forecast, not funded progress.
            let laterActual = runway?.events.filter { $0.kind == .actual && $0.date <= today }.reduce(Decimal.zero) { $0 + $1.change } ?? 0
            let actualAnchor = runway?.anchor.amount.map { $0 + laterActual }
            let bills = runway?.events.filter { $0.kind != .actual && $0.kind != .income }.reduce(Decimal.zero) { $0 - min(0, $1.change) } ?? 0
            return .init(designation: designation, fundedAfterBills: actualAnchor.map { max(0, $0 - bills) }, proposedContribution: contribution,
                basis: "Dated bank balance less known future bills; \(runway?.anchor.date?.presentation ?? "date unavailable"). Coverage and unreviewed payments remain conditional.")
        }
        return .init(month: plan.month, start: start, end: end, recurring: payments, candidates: try recurringCandidates(rows: rows, metadata: metadata),
            runways: runways, reserves: reserves, actualSpending: actual, actualTransactionIDs: actualIDs, plannedCommitments: planned,
            unmatchedSpendingCount: meanings.filter { $0.treatment == .unresolved }.count, cardNeeds: cardNeeds,
            scenarioIsActive: scenario.isActive, calculationSeconds: Date().timeIntervalSince(started))
    }
}
