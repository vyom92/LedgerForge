import Foundation
@testable import LedgerForge

// Genuine saved-plan consumer checks; interpretation comparisons remain in RAM.
@MainActor
enum PlanningConsumerAuthenticAssertions {
    enum Failure: Error { case assertion(String) }

    enum Shape: String, CaseIterable {
        case savedCalendarPlan, savedSalaryCyclePlan
        case automaticBankExpenseIntent, originalPurchaseNet
        case creditOutsidePurchaseWindow, creditWindowNoSecondDeduction
        case sourceDateDiffersFromPostingWindow, salaryCycleChangesExpenseWindow
        case sourceLoanEMIExcluded, ownTransferExcluded, cardPaymentExcluded, salaryReceiptExcluded
        case historyAccountExcluded, explicitlySelectedHistoryAccount
        case recordedCashFacts, plannedCommitmentsStable, recurringCashNeedsStable
        case cardFundingNeedsStable, forecastFundingStable, allowanceEffectsReconciled, reserveFundingReconciled
    }

    struct AllocationApproval {
        let creditID: String
        let minor: Int64
        let purchaseDate: String?, creditDate: String?
    }
    struct RefundApproval {
        let purchaseID: String, currency: String
        let purchaseMinor: Int64
        let allocations: [AllocationApproval]
    }
    private struct BoundRefund {
        let approval: RefundApproval
        let eventID: String
        let purchase: SpendingSourceRow
        let credits: [SpendingSourceRow]
        let allocated: Money
    }
    private struct Window {
        let first: StatementDate
        let afterLast: StatementDate
        func contains(_ date: StatementDate?) -> Bool {
            date.map { $0 >= first && $0 < afterLast } ?? false
        }
    }

    static func check(snapshot: RepositoryRuntimeSnapshot, rows: [SpendingSourceRow],
                      metadata: FinancialIntelligenceSnapshot,
                      spendingIntents: [String: TransactionSpendingIntent],
                      approvedAutomaticBankExpenseIDs: Set<String>,
                      approvedRefunds: [RefundApproval], approvedSalaryIDs: Set<String>, independentlyExcludedLoanIDs: Set<String>,
                      sourcePostedDates: [String: String], today: StatementDate) throws -> Set<Shape> {
        try require(Set(rows.map(\.id)).count == rows.count && Set(rows.map(\.id)) == Set(sourcePostedDates.keys),
                    "Monthly Plan qualification requires the complete genuine frozen runtime cohort")
        let rowByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        let plans = snapshot.fundingPlans.filter { $0.workspaceID == metadata.workspaceID }
            .sorted { ($0.month.canonical, $0.id) < ($1.month.canonical, $1.id) }
        // A missing saved shape remains unobserved; no invented plan or balance
        // is substituted merely to make coverage appear complete.
        guard !plans.isEmpty else { return [] }

        let anchors = snapshot.accounts.compactMap { account -> PlanningAccountAnchor? in
            guard let id = account.repositoryAccountId else { return nil }
            let date = account.currentBalanceAsOfISO.flatMap { try? StatementDate(canonical: String($0.prefix(10))) }
            return .init(id: id, title: account.preferredDisplayName, currency: account.currencyCode,
                domain: account.type == .bank ? "bank" : "credit_card", amount: date == nil ? nil : account.currentBalance,
                date: date, historyOnly: account.isHistoryOnly)
        }
        let historyIDs = Set(snapshot.accounts.filter(\.isHistoryOnly).compactMap(\.repositoryAccountId))
            .union(snapshot.financialSources.accounts.filter(\.isHistoryOnly).map(\.id))
        let confirmed = metadata.confirmedByTransaction
        let recurringIDs = Set(metadata.occurrences.flatMap(\.transactionIDs))
        let rejectedExpenseIDs = Set(metadata.movements.filter {
            $0.decision == .rejected && $0.kind == .expense && $0.transactionIDs.count == 1
        }.flatMap(\.transactionIDs))

        // These are the owner's already approved genuine bank outgoings. A
        // preexisting reviewed event, recurring match or source fee already has
        // its independent spending meaning and cannot contribute to this delta.
        var intentControls: [SpendingSourceRow] = []
        var withoutApprovedIntents = spendingIntents
        for id in approvedAutomaticBankExpenseIDs.sorted() {
            guard let row = rowByID[id] else { throw Failure.assertion("Approved bank expense is missing from genuine history") }
            try require(spendingIntents[id]?.kind == .automaticExpense && row.isBankOut && row.transaction.money.amount < 0 && !row.isLoanOrEMI,
                        "Approved bank spending action is not the saved genuine source-eligible intent")
            withoutApprovedIntents.removeValue(forKey: id)
            if confirmed[id] == nil && !recurringIDs.contains(id) && !rejectedExpenseIDs.contains(id) && !row.isCharge {
                intentControls.append(row)
            }
        }
        let refunds = try bindRefunds(approvedRefunds, rows: rowByID, metadata: metadata)
        let approvedRefundEventIDs = Set(refunds.map(\.eventID))
        var grossMetadata = metadata
        for index in grossMetadata.movements.indices where approvedRefundEventIDs.contains(grossMetadata.movements[index].id) {
            grossMetadata.movements[index].refundAllocations = nil
        }
        for id in independentlyExcludedLoanIDs {
            try require(rowByID[id]?.isLoanOrEMI == true, "An independently source-qualified loan or EMI lost its exclusion")
        }
        let loanIDs = Set(rows.filter(\.isLoanOrEMI).map(\.id)).union(independentlyExcludedLoanIDs)
        let transferIDs = Set(metadata.movements.filter { $0.decision == .confirmed && $0.kind == .ownTransfer }.flatMap(\.transactionIDs))
        let cardPaymentIDs = Set(metadata.movements.filter { $0.decision == .confirmed && $0.kind == .cardPayment }.flatMap(\.transactionIDs))
        var coverage: Set<Shape> = []

        for plan in plans {
            let window = try independentWindow(plan)
            let calendarWindow = try calendarWindow(plan.month)
            if plan.assistance?.salaryCycle == nil { coverage.insert(.savedCalendarPlan) }
            else { coverage.insert(.savedSalaryCyclePlan) }
            try require(plan.recurringStart == window.first && plan.recurringEnd < window.afterLast &&
                        nextDay(plan.recurringEnd) == window.afterLast,
                        "Saved Monthly Plan date policy changed its inclusive start or exclusive next-payday boundary")

            // Exercise the saved default and the existing explicit inclusion of
            // history accounts. This changes report scope, never account facts.
            let selections: [Set<String>] = historyIDs.isEmpty ? [[]] : [[], historyIDs]
            for selectedHistory in selections {
                func available(_ row: SpendingSourceRow) -> Bool {
                    !historyIDs.contains(row.accountID) || selectedHistory.contains(row.accountID)
                }
                func selected(_ row: SpendingSourceRow) -> Bool { available(row) && window.contains(row.date) }
                func project(_ owner: FinancialIntelligenceSnapshot, intents: [String: TransactionSpendingIntent]) throws -> PlanningProjection {
                    try PlanningIntelligence.project(plan: plan, anchors: anchors, rows: rows,
                        metadata: owner, sources: snapshot.financialSources, cards: snapshot.cardSnapshot,
                        today: today, selectedHistoryAccountIDs: selectedHistory, spendingIntents: intents)
                }
                let actual = try project(metadata, intents: spendingIntents)
                let noIntents = try project(metadata, intents: withoutApprovedIntents)
                let gross = try project(grossMetadata, intents: spendingIntents)
                let members = Set(actual.actualTransactionIDs.values.flatMap { $0 })
                coverage.formUnion(try requireFundingMeaning(actual, comparedWith: noIntents, plan: plan,
                    rows: rows, metadata: metadata, today: today))
                coverage.formUnion(try requireFundingMeaning(actual, comparedWith: gross, plan: plan,
                    rows: rows, metadata: metadata, today: today))
                let expectedIntentIncrease = try sum(intentControls.filter(selected).map { try Money(amount: $0.amount, currency: $0.currency) })
                let expectedAllocationDecrease = try sum(refunds.filter { selected($0.purchase) }.map(\.allocated))
                try requireDifference(actual, minus: noIntents, equals: expectedIntentIncrease,
                                      reason: "Monthly Plan did not consume exactly the approved native bank-expense actions in its stored date/account window")
                try requireDifference(gross, minus: actual, equals: expectedAllocationDecrease,
                                      reason: "Monthly Plan refund reduction differs from exact approved original-purchase allocations")

                for row in intentControls {
                    try require(members.contains(row.id) == selected(row),
                                "Monthly Plan bank-expense membership differs from the genuine source date and selected account scope")
                    try require(actual.actualSpendingByTransaction[row.id] == (selected(row) ? row.amount : nil),
                                "Monthly Plan did not retain the exact genuine native amount of an approved bank expense")
                    if selected(row) { coverage.insert(.automaticBankExpenseIntent) }
                    if available(row), window.contains(row.date) != calendarWindow.contains(row.date), plan.assistance?.salaryCycle != nil {
                        coverage.insert(.salaryCycleChangesExpenseWindow)
                    }
                }
                for refund in refunds {
                    try require(members.contains(refund.purchase.id) == selected(refund.purchase),
                                "Monthly Plan lost an approved purchase or moved it to a refund credit's date")
                    let net = try Money(amount: refund.purchase.amount, currency: refund.approval.currency) - refund.allocated
                    try require(actual.actualSpendingByTransaction[refund.purchase.id] == (selected(refund.purchase) ? net.amount : nil),
                                "Monthly Plan original-purchase value differs from independently approved gross less exact allocations")
                    for credit in refund.credits {
                        try require(actual.actualSpendingByTransaction[credit.id] == (selected(credit) ? Decimal.zero : nil),
                                    "Monthly Plan counted an approved refund credit as a second spending deduction")
                    }
                    if selected(refund.purchase) { coverage.insert(.originalPurchaseNet) }
                }
                for (ids, shape) in [(loanIDs, Shape.sourceLoanEMIExcluded), (transferIDs, .ownTransferExcluded),
                                     (cardPaymentIDs, .cardPaymentExcluded), (approvedSalaryIDs, .salaryReceiptExcluded)] {
                    let visible = ids.compactMap { rowByID[$0] }.filter(selected)
                    try require(members.isDisjoint(with: visible.map(\.id)), "Monthly Plan counted a protected loan, transfer, card-payment or salary leg as spending")
                    try require(visible.allSatisfy { actual.actualSpendingByTransaction[$0.id] == nil },
                                "Monthly Plan per-record spending retained a protected non-spending leg")
                    if shape == .sourceLoanEMIExcluded {
                        if visible.contains(where: { independentlyExcludedLoanIDs.contains($0.id) }) { coverage.insert(shape) }
                    } else if !visible.isEmpty { coverage.insert(shape) }
                }

                let positiveControls = intentControls + refunds.map(\.purchase)
                for row in positiveControls where window.contains(row.date) && historyIDs.contains(row.accountID) {
                    if selectedHistory.contains(row.accountID) {
                        try require(members.contains(row.id), "Explicit history-account selection did not restore a genuine approved expense")
                        coverage.insert(.explicitlySelectedHistoryAccount)
                    } else {
                        try require(!members.contains(row.id), "Default Monthly Plan scope included a history-only account")
                        coverage.insert(.historyAccountExcluded)
                    }
                }
                for row in positiveControls where available(row) {
                    guard let token = sourcePostedDates[row.id], let posted = try? StatementDate(canonical: String(token.prefix(10))) else { continue }
                    if window.contains(row.date) != window.contains(posted) {
                        try require(members.contains(row.id) == window.contains(row.date),
                                    "Monthly Plan substituted the canonical posted date for the genuine source transaction date")
                        coverage.insert(.sourceDateDiffersFromPostingWindow)
                    }
                }

                // At most one genuine example per native currency and direction
                // of boundary crossing. Individual controls prevent unrelated
                // refunds from hiding a purchase-month/credit-month mistake.
                var checkedBoundaries: Set<String> = []
                for refund in refunds where available(refund.purchase) {
                    let purchaseInside = window.contains(refund.purchase.date)
                    let creditInside = refund.credits.contains { window.contains($0.date) }
                    let creditOutside = refund.credits.contains { !window.contains($0.date) }
                    guard purchaseInside && creditOutside || !purchaseInside && creditInside else { continue }
                    let key = refund.approval.currency + (purchaseInside ? ":purchase" : ":credit")
                    guard checkedBoundaries.insert(key).inserted else { continue }
                    var oneLegacy = metadata
                    guard let index = oneLegacy.movements.firstIndex(where: { $0.id == refund.eventID }) else {
                        throw Failure.assertion("Approved refund comparison lost its exact saved event")
                    }
                    oneLegacy.movements[index].refundAllocations = nil
                    let beforeAllocation = try project(oneLegacy, intents: spendingIntents)
                    let expected = purchaseInside ? [refund.approval.currency: refund.allocated] : [:]
                    try requireDifference(beforeAllocation, minus: actual, equals: expected,
                                          reason: "Monthly Plan attributed a refund to the credit window or failed to see an out-of-window supporting credit")
                    coverage.insert(purchaseInside ? .creditOutsidePurchaseWindow : .creditWindowNoSecondDeduction)
                }
            }
        }
        return coverage
    }

    private static func bindRefunds(_ approvals: [RefundApproval], rows: [String: SpendingSourceRow],
                                    metadata: FinancialIntelligenceSnapshot) throws -> [BoundRefund] {
        let confirmed = metadata.confirmedByTransaction
        return try approvals.sorted { $0.purchaseID < $1.purchaseID }.map { approval in
            guard let purchase = rows[approval.purchaseID], let event = confirmed[approval.purchaseID],
                  event.kind == .refund, let saved = event.refundAllocations else {
                throw Failure.assertion("Approved refund is not saved on its genuine original purchase")
            }
            try require(purchase.currency == approval.currency && !purchase.isLoanOrEMI && purchase.date != nil &&
                        approval.purchaseMinor != .min && purchase.amount == (try Money.fromMinorUnits(abs(approval.purchaseMinor), currency: approval.currency)).amount,
                        "Planning refund control does not match the independently approved genuine purchase")
            let savedByCredit = Dictionary(grouping: saved, by: \.creditTransactionID)
            var credits: [SpendingSourceRow] = []
            var amounts: [Money] = []
            for allocation in approval.allocations {
                guard let credit = rows[allocation.creditID], let entries = savedByCredit[allocation.creditID], entries.count == 1 else {
                    throw Failure.assertion("Planning refund control lost its genuine approved credit allocation")
                }
                let amount = try Money.fromMinorUnits(allocation.minor, currency: approval.currency)
                try require(allocation.minor > 0 && entries[0].purchaseTransactionID == purchase.id && entries[0].amount == amount &&
                            credit.currency == purchase.currency && credit.accountID == purchase.accountID &&
                            !credit.isLoanOrEMI && credit.date?.canonical == allocation.creditDate && purchase.date?.canonical == allocation.purchaseDate &&
                            (credit.isBankIn || credit.isCardDecrease),
                            "Planning refund comparison differs from the independent allocation or its original source dates")
                credits.append(credit); amounts.append(amount)
            }
            try require(Set(savedByCredit.keys) == Set(approval.allocations.map(\.creditID)),
                        "Planning refund event has unreviewed extra credit allocations")
            let allocated = try amounts.reduce(Money.fromMinorUnits(0, currency: approval.currency)) { try $0 + $1 }
            try require(allocated.amount <= purchase.amount, "Planning allocation exceeds the real original purchase")
            return BoundRefund(approval: approval, eventID: event.id, purchase: purchase, credits: credits, allocated: allocated)
        }
    }

    private struct CashMeaning: Equatable {
        let id: String, accountID: String, title: String, kind: String
        let date: StatementDate
        let change: Decimal
        let transactionIDs: Set<String>
        init(_ event: PlanningCashEvent) {
            id = event.id; accountID = event.accountID; title = event.title; kind = event.kind.rawValue
            date = event.date; change = event.change; transactionIDs = event.transactionIDs
        }
        init(actual row: SpendingSourceRow, date: StatementDate) {
            id = "actual:" + row.id; accountID = row.accountID; title = row.transaction.description
            kind = PlanningCashEvent.Kind.actual.rawValue; self.date = date
            change = row.transaction.money.amount; transactionIDs = [row.id]
        }
    }

    /// Spending interpretation can change the unused allowance provision; it
    /// cannot rewrite cash already recorded by a bank or a saved payment need.
    /// These comparisons ignore timing telemetry and deliberately reconciled
    /// allowance effects, rather than demanding a false blanket forecast match.
    private static func requireFundingMeaning(_ actual: PlanningProjection, comparedWith other: PlanningProjection,
                                             plan: FundingPlan, rows: [SpendingSourceRow],
                                             metadata: FinancialIntelligenceSnapshot, today: StatementDate) throws -> Set<Shape> {
        try require(actual.month == other.month && actual.start == other.start && actual.end == other.end &&
                    actual.scenarioIsActive == other.scenarioIsActive && actual.plannedCommitments == other.plannedCommitments &&
                    actual.cardNeeds == other.cardNeeds,
                    "Spending interpretation changed a saved planning window, commitment or card payment need")
        var coverage: Set<Shape> = []
        if !actual.plannedCommitments.isEmpty { coverage.insert(.plannedCommitmentsStable) }
        if !actual.cardNeeds.isEmpty { coverage.insert(.cardFundingNeedsStable) }
        let payments = actual.recurring.sorted { $0.id < $1.id }
        let otherPayments = other.recurring.sorted { $0.id < $1.id }
        try require(payments.count == otherPayments.count, "Spending interpretation changed recurring cash-need coverage")
        for (left, right) in zip(payments, otherPayments) {
            try require(left.id == right.id && left.definition == right.definition && left.date == right.date &&
                        left.expected == right.expected && left.paid == right.paid && left.currency == right.currency &&
                        left.actualIDs == right.actualIDs && Set(left.suggestionIDs) == Set(right.suggestionIDs) &&
                        left.isWaived == right.isWaived && left.hasCoverage == right.hasCoverage &&
                        left.plannedDueDate == right.plannedDueDate && left.isExcludedFromPlan == right.isExcludedFromPlan,
                        "Spending interpretation changed a recurring payment's amount, evidence or due-date meaning")
        }
        if !payments.isEmpty { coverage.insert(.recurringCashNeedsStable) }

        let rowByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        let knownRecurring = Set(metadata.occurrences.flatMap(\.transactionIDs))
        let leftRunways = Dictionary(uniqueKeysWithValues: actual.runways.map { ($0.id, $0) })
        let rightRunways = Dictionary(uniqueKeysWithValues: other.runways.map { ($0.id, $0) })
        try require(Set(leftRunways.keys) == Set(rightRunways.keys), "Spending interpretation changed planning funding accounts")
        let allowanceWarning = "Recorded discretionary spending exceeds this allowance by "
        var allowanceChangedAccounts: Set<String> = []
        for id in leftRunways.keys.sorted() {
            let left = leftRunways[id]!, right = rightRunways[id]!
            try require(left.anchor.id == right.anchor.id && left.anchor.title == right.anchor.title &&
                        left.anchor.currency == right.anchor.currency && left.anchor.domain == right.anchor.domain &&
                        left.anchor.amount == right.anchor.amount && left.anchor.date == right.anchor.date &&
                        left.anchor.historyOnly == right.anchor.historyOnly && left.reserveFloor == right.reserveFloor,
                        "Spending interpretation changed a genuine dated balance or owner reserve floor")
            let unchangedLeft = left.events.filter { $0.kind != .allowance }.map(CashMeaning.init).sorted { $0.id < $1.id }
            let unchangedRight = right.events.filter { $0.kind != .allowance }.map(CashMeaning.init).sorted { $0.id < $1.id }
            try require(unchangedLeft == unchangedRight, "Spending interpretation changed a recorded or planned non-allowance cash event")
            if left.events.contains(where: { $0.kind != .actual && $0.kind != .allowance }) { coverage.insert(.forecastFundingStable) }
            let actualCash = left.events.filter { $0.kind == .actual }.map(CashMeaning.init).sorted { $0.id < $1.id }
            let expectedCash: [CashMeaning]
            if let anchorDate = left.anchor.date, left.anchor.amount != nil {
                expectedCash = rows.compactMap { row in
                    // Balance replay uses its existing canonical date policy,
                    // independently of the source transaction date for spending.
                    guard row.accountID == id, let date = row.transaction.statementDate,
                          date > anchorDate, date <= actual.end else { return nil }
                    return CashMeaning(actual: row, date: date)
                }.sorted { $0.id < $1.id }
            } else { expectedCash = [] }
            try require(actualCash == expectedCash,
                        "Monthly Plan changed genuine signed cash, replayed a balance-date transaction, or substituted an analytical spending date")
            if !actualCash.isEmpty { coverage.insert(.recordedCashFacts) }

            let allowanceLeft = left.events.filter { $0.kind == .allowance }
            let allowanceRight = right.events.filter { $0.kind == .allowance }
            try require(allowanceLeft.count == allowanceRight.count && allowanceLeft.count <= 1,
                        "Spending interpretation changed the presence of the saved allowance provision")
            if let a = allowanceLeft.first, let b = allowanceRight.first {
                try require(a.id == b.id && a.accountID == b.accountID && a.date == b.date && a.title == b.title && a.transactionIDs == b.transactionIDs,
                            "Spending interpretation changed allowance funding identity or date")
                guard plan.assistance?.allowanceAccountID == id, let amount = try plan.assistance?.allowance?.money() else {
                    throw Failure.assertion("Projected allowance has no saved owner amount and account")
                }
                try require(amount.currency.code == left.anchor.currency, "Allowance comparison crossed native currencies")
                func spent(_ projection: PlanningProjection) -> Decimal {
                    projection.actualSpendingByTransaction.reduce(Decimal.zero) { total, entry in
                        rowByID[entry.key]?.accountID == id && !knownRecurring.contains(entry.key) ? total + entry.value : total
                    }
                }
                let leftSpent = spent(actual), rightSpent = spent(other)
                try require(a.change == -max(0, amount.amount - leftSpent) && b.change == -max(0, amount.amount - rightSpent),
                            "Allowance provision did not reconcile the saved native budget with original-purchase net spending")
                try require(left.limitations.contains(where: { $0.hasPrefix(allowanceWarning) }) == (leftSpent > amount.amount) &&
                            right.limitations.contains(where: { $0.hasPrefix(allowanceWarning) }) == (rightSpent > amount.amount),
                            "Allowance review state does not agree with its saved budget and genuine recognized spending")
                if a.change != b.change {
                    allowanceChangedAccounts.insert(id); coverage.insert(.allowanceEffectsReconciled)
                }
            }
            try require(left.limitations.filter { !$0.hasPrefix(allowanceWarning) } == right.limitations.filter { !$0.hasPrefix(allowanceWarning) },
                        "Spending interpretation changed an unrelated funding limitation")

            // All event identities and ordering remain identical. Reconcile every
            // projected balance using only the independently bounded allowance
            // difference; no other forecast movement is permitted to drift.
            try require(left.events.map(\.id) == right.events.map(\.id) && left.points.count == right.points.count,
                        "Spending interpretation changed the forecast's cash-event or balance-point topology")
            var prefixDifference: [String: Decimal] = [:]
            var allDifference = Decimal.zero
            var beforeHorizon = Decimal.zero
            for (a, b) in zip(left.events, right.events) {
                let difference = a.change - b.change
                try require(difference == 0 || a.kind == .allowance, "A non-allowance event changed the forecast balance")
                allDifference += difference
                prefixDifference[a.id] = allDifference
                if a.date < actual.start { beforeHorizon += difference }
            }
            for (a, b) in zip(left.points, right.points) {
                try require(a.id == b.id && a.date == b.date && a.isForecast == b.isForecast && a.title == b.title && a.transactionIDs == b.transactionIDs,
                            "Spending interpretation changed a recorded or forecast point's date or evidence")
                let expectedDifference: Decimal
                if a.id == "anchor:" + id { expectedDifference = 0 }
                else if a.id == "end:" + id { expectedDifference = allDifference }
                else if a.id == "carried:" + id { expectedDifference = beforeHorizon }
                else if let difference = prefixDifference[a.id] { expectedDifference = difference }
                else { throw Failure.assertion("Forecast point has no preserved source, cash event or horizon identity") }
                try require(a.balance - b.balance == expectedDifference,
                            "Monthly Plan projected balances changed beyond the reconciled allowance effect")
            }
        }
        let reserves = Dictionary(uniqueKeysWithValues: actual.reserves.map { ($0.id, $0) })
        let otherReserves = Dictionary(uniqueKeysWithValues: other.reserves.map { ($0.id, $0) })
        try require(Set(reserves.keys) == Set(otherReserves.keys), "Spending interpretation changed owner reserve designations")
        for id in reserves.keys.sorted() {
            let left = reserves[id]!, right = otherReserves[id]!
            try require(left.designation == right.designation && left.proposedContribution == right.proposedContribution && left.basis == right.basis,
                        "Spending interpretation changed reserve ownership, target, contribution or evidence")
            if let accountID = left.designation.accountID, allowanceChangedAccounts.contains(accountID),
               let leftRunway = leftRunways[accountID], let rightRunway = rightRunways[accountID], left.designation.kind == .accountCash {
                func remaining(_ runway: AccountRunway) -> Decimal? {
                    guard let opening = runway.anchor.amount else { return nil }
                    // Recorded events were independently bound to real bank
                    // facts above; unchanged future needs retain saved meaning.
                    let recorded = runway.events.filter { $0.kind == .actual && $0.date <= today }.reduce(Decimal.zero) { $0 + $1.change }
                    let needs = runway.events.filter { $0.kind != .actual && $0.kind != .income }.reduce(Decimal.zero) { $0 - min(0, $1.change) }
                    return max(0, opening + recorded - needs)
                }
                try require(left.fundedAfterBills == remaining(leftRunway) && right.fundedAfterBills == remaining(rightRunway),
                            "Reserve funding changed beyond genuine cash and reconciled remaining allowance")
            } else {
                try require(left.fundedAfterBills == right.fundedAfterBills, "Spending interpretation changed reserve funding without an allowance effect")
            }
        }
        if !reserves.isEmpty { coverage.insert(.reserveFundingReconciled) }
        return coverage
    }

    private static func independentWindow(_ plan: FundingPlan) throws -> Window {
        guard let cycle = plan.assistance?.salaryCycle else { return try calendarWindow(plan.month) }
        let first = try StatementDate(canonical: cycle.payday)
        let afterLast = try StatementDate(canonical: cycle.nextPayday)
        try require(first < afterLast && String(cycle.payday.prefix(7)) == plan.month.canonical,
                    "Saved salary-cycle planning metadata has an invalid genuine boundary")
        return Window(first: first, afterLast: afterLast)
    }
    private static func calendarWindow(_ month: SelectedStatementMonth) throws -> Window {
        let nextMonth = month.month == 12 ? 1 : month.month + 1
        let nextYear = month.month == 12 ? month.year + 1 : month.year
        return Window(first: try StatementDate(year: month.year, month: month.month, day: 1),
                      afterLast: try StatementDate(year: nextYear, month: nextMonth, day: 1))
    }
    private static func nextDay(_ date: StatementDate) -> StatementDate? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let instant = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: instant) else { return nil }
        let parts = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return try? StatementDate(year: year, month: month, day: day)
    }
    private static func sum(_ values: [Money]) throws -> [String: Money] {
        var result: [String: Money] = [:]
        for value in values {
            let currency = value.currency.code
            result[currency] = try (result[currency] ?? Money.fromMinorUnits(0, currency: currency)) + value
        }
        return result
    }
    private static func requireDifference(_ left: PlanningProjection, minus right: PlanningProjection,
                                          equals expected: [String: Money], reason: String) throws {
        let currencies = Set(left.actualSpending.keys).union(right.actualSpending.keys).union(expected.keys)
        for currency in currencies {
            let high = try Money(amount: left.actualSpending[currency, default: 0], currency: currency)
            let low = try Money(amount: right.actualSpending[currency, default: 0], currency: currency)
            let value = try high - low
            try require(value == (try expected[currency] ?? Money.fromMinorUnits(0, currency: currency)), reason)
        }
    }
    private static func require(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try value() else { throw Failure.assertion(message) }
    }
}
