import Foundation
import CryptoKit

nonisolated struct IntelligenceAccountContext: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let sourceLabel: String?
    let currency: String
    let domain: String
    let routeType: String?
    let verifiedIdentifiers: Set<String>
    var selectionDetail: String? = nil
    var isHistoryOnly = false

    var selectionContext: String {
        let suffix = verifiedIdentifiers.sorted { ($0.count, $0) < ($1.count, $1) }.first.map { "…" + $0.suffix(4) }
        return [suffix, currency, suffix == nil ? selectionDetail : nil, isHistoryOnly ? "History only" : nil].compactMap { $0 }.joined(separator: " · ")
    }
    var selectionTitle: String { title + " · " + selectionContext }
}

nonisolated struct FinancialCoveragePeriod: Equatable, Sendable {
    let accountID: String
    let start: StatementDate
    let end: StatementDate
}

nonisolated struct FinancialSourceContext: Equatable, Sendable {
    var accounts: [IntelligenceAccountContext] = []
    var periods: [FinancialCoveragePeriod] = []
    static let empty = Self()

    func accountScope(selectedAccountIDs: Set<String> = []) -> AccountPresentationScope {
        .init(selectedAccountIDs: selectedAccountIDs,
              historyOnlyAccountIDs: Set(accounts.filter(\.isHistoryOnly).map(\.id)))
    }

    func hasCompleteCoverage(accountID: String, start: StatementDate, end: StatementDate) -> Bool {
        let periods = periods.filter { $0.accountID == accountID }.sorted { $0.start < $1.start }
        var cursor = start
        for period in periods where period.end >= cursor {
            guard period.start <= cursor else { return false }
            if period.end >= end { return true }
            guard let next = FinancialCalendar.addDays(1, to: period.end) else { return false }
            cursor = next
        }
        return false
    }
}

nonisolated enum SpendingTreatment: String, Sendable, CaseIterable {
    case income = "Income", expense = "Spending", refund = "Refund", ownTransfer = "Own transfer"
    case cardPayment = "Card payment", reversal = "Reversal", outsideScope = "Outside analysis scope", unresolved = "Needs review"
}

nonisolated struct SpendingSourceRow: Identifiable, Sendable {
    let transaction: Transaction
    let id: String
    let accountID: String
    let accountTitle: String
    let domain: String
    let date: StatementDate?
    let dateRole: String
    let summaryMembership: CardTransactionSummaryMembership?
    let categoryID: String?
    let categoryName: String
    let categoryConflict: Bool
    let isRegularSalary: Bool
    var amount: Decimal { abs(transaction.money.amount) }
    var currency: String { transaction.currency }
    var isBankOut: Bool { domain == "bank" && transaction.debitMoney != nil }
    var isBankIn: Bool { domain == "bank" && transaction.creditMoney != nil }
    var isCardIncrease: Bool { transaction.cardLiabilityEffect == .increasesAmountOwed }
    var isCardDecrease: Bool { transaction.cardLiabilityEffect == .decreasesAmountOwed }
    var text: String { (transaction.description + " " + (transaction.reference ?? "")).uppercased() }
    var exactAmount: String { currency + " " + transaction.money.amount.formatted(.number.precision(.fractionLength(2...8)).locale(Locale(identifier: currency == "INR" ? "en_IN" : "en_US"))) }

    // Source roles constrain movement eligibility independently of editable
    // categories and salary-assistance setup. They do not assign a category.
    var isEmployerSalaryReceipt: Bool {
        isBankIn && hasProfile(prefix: "cbq.") &&
        transaction.description.uppercased().hasPrefix("SALARY TRANSFER") && text.contains("QATAR AIRWAYS")
    }
    var isExchangeRemittanceOut: Bool {
        isBankOut && hasProfile(prefix: "cbq.") && text.contains("NAPS PURCHASE") && text.contains("AL DAR EXCHANGE")
    }
    var isInwardRemittance: Bool {
        isBankIn && hasProfile(prefix: "axis.") && text.contains("IMPS/P2A/") && text.contains("RDAMASTE")
    }
    var isReferenceReversal: Bool { text.contains("REV-IMPS-") || text.contains("REVERSAL") }
    var isCharge: Bool {
        isCashAdvanceFee || ((isBankOut || isCardIncrease) &&
            ["INTEREST", "PROCESSING FEE", "BOUNCE CHARGES", "SERVICE CHARGE", "TRANSFER FEE"].contains(where: text.contains))
    }
    var isCashAdvanceFee: Bool {
        isCardIncrease && transaction.money.amount > 0 && SpendingSourcePolicy.isCashAdvanceFee(domain: domain,
            direction: "card_increase_owed", narration: transaction.description,
            parserProfileIDs: Set(transaction.sourceProvenance.map(\.parserProfileID)))
    }
    var isLoanOrEMI: Bool {
        SpendingSourcePolicy.isLoanOrEMI(domain: domain, narration: transaction.description,
            parserProfileIDs: Set(transaction.sourceProvenance.map(\.parserProfileID)), summaryMembership: summaryMembership)
    }
    private func hasProfile(prefix: String) -> Bool { transaction.sourceProvenance.contains { $0.parserProfileID.hasPrefix(prefix) } }

    var movementReferences: Set<String> {
        // Preserve the complete scheme token, including leading zeros. A
        // padded repository field is not silently normalized into a new ID.
        let pattern = #"(?<![A-Z0-9])(?:REV-)?IMPS(?:-|/P2A/)([0-9]{12})(?![0-9])"#
        let narration = transaction.description.uppercased()
        let regex = try! NSRegularExpression(pattern: pattern)
        let tokens = regex.matches(in: narration, range: NSRange(narration.startIndex..., in: narration)).compactMap { match in
            Range(match.range(at: 1), in: narration).map { "IMPS:" + narration[$0] }
        }
        if !tokens.isEmpty { return Set(tokens) }
        let reference = transaction.reference?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return reference.isEmpty || reference.allSatisfy({ $0 == "0" }) ? [] : ["REFERENCE:" + reference]
    }
}

nonisolated struct SpendingAmounts: Equatable, Sendable {
    let gross: Money
    let allocatedRefund: Money
    let net: Money

    static func zero(currency: String) throws -> Self {
        let zero = try Money(amount: 0, currency: currency)
        return .init(gross: zero, allocatedRefund: zero, net: zero)
    }

    func adding(_ other: Self) throws -> Self {
        .init(gross: try gross + other.gross, allocatedRefund: try allocatedRefund + other.allocatedRefund,
              net: try net + other.net)
    }
}

nonisolated struct SpendingRefundDetail: Identifiable, Sendable {
    let eventID: String
    let purchaseTransactionID: String
    let creditTransactionID: String
    let purchaseDate: StatementDate?
    let creditDate: StatementDate?
    let allocated: Money
    let creditAmount: Money
    let residual: Money
    var id: String { eventID + ":" + creditTransactionID }
}

nonisolated struct SpendingReviewRow: Identifiable, Sendable {
    let source: SpendingSourceRow
    let treatment: SpendingTreatment
    var explanation: String
    var amounts: SpendingAmounts? = nil
    var refundDetails: [SpendingRefundDetail] = []
    var refundResidual: Money? = nil
    var refundNeedsReview = false
    var id: String { source.id }
    // Credits never independently deduct spending on their receipt date.
    var spending: Decimal { treatment == .expense ? (amounts?.net.amount ?? source.amount) : 0 }
    var income: Decimal { treatment == .income ? source.amount : 0 }
    var supportingTransactionIDs: Set<String> { Set(refundDetails.map(\.creditTransactionID)).subtracting([id]) }
}

nonisolated struct MovementSuggestion: Identifiable, Equatable, Sendable {
    let id: String
    let kind: MovementKind
    let transactionIDs: [String]
    let explanation: String
    var ambiguityCount = 0
    var routeWarning: String?
    var tentativeTitle: String { kind == .ownTransfer ? "Possible transfer" : "Possible " + kind.title.lowercased() }
    static func identity(_ kind: MovementKind, ids: [String]) -> String {
        let value = kind.rawValue + ":" + ids.sorted().joined(separator: ":")
        return "movement-" + SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated struct MovementSuggestionGroup: Identifiable, Sendable {
    let suggestions: [MovementSuggestion]
    var id: String { suggestions.map(\.id).sorted().joined(separator: ":") }
    var transactionIDs: Set<String> { Set(suggestions.flatMap(\.transactionIDs)) }
}

nonisolated struct SpendingPeriodValue: Identifiable, Sendable {
    let id: String
    let title: String
    let income: Decimal
    let spending: Decimal
    let transactionIDs: Set<String>
    let unresolvedIDs: Set<String>
    let incompleteAccounts: [String]
    let amounts: SpendingAmounts
    let supportingTransactionIDs: Set<String>
}

nonisolated struct SpendingCategoryValue: Identifiable, Sendable {
    let id: String
    let title: String
    let amount: Decimal
    let transactionIDs: Set<String>
    let amounts: SpendingAmounts
    let supportingTransactionIDs: Set<String>
}

nonisolated struct SpendingProjection: Sendable {
    let rows: [SpendingReviewRow]
    let periods: [SpendingPeriodValue]
    let categories: [SpendingCategoryValue]
    let suggestions: [MovementSuggestion]
    let selectedCurrency: String
    let income: Decimal
    let spending: Decimal
    let unresolvedCount: Int
    let missingDateCount: Int
    let amounts: SpendingAmounts
    let supportingTransactionIDs: Set<String>
}

nonisolated struct SpendingComparisonPeriod: Sendable {
    let start: StatementDate
    let end: StatementDate
    let report: SpendingProjection
    let coverage: [Coverage]
    let purchaseIDs: Set<String>
    let purchaseAmount: Decimal
    let chargeIDs: Set<String>
    let chargeAmount: Decimal
    struct Coverage: Identifiable, Sendable {
        let id: String, title: String
        let recordedThrough: StatementDate?
        let complete: Bool
    }
    var title: String { start.presentation + "–" + end.presentation }
    var averagePurchase: Decimal? { purchaseIDs.isEmpty ? nil : purchaseAmount / Decimal(purchaseIDs.count) }
    var isPartialCalendarMonth: Bool {
        guard let month = try? SelectedStatementMonth(year: end.year, month: end.month) else { return true }
        return start.year == end.year && start.month == end.month && (start.day != 1 || FinancialCalendar.lastDay(month) != end)
    }
}

nonisolated struct SpendingDifference: Identifiable, Sendable {
    let id: String, title: String
    let analysis: Decimal, baseline: Decimal
    let analysisIDs: Set<String>, baselineIDs: Set<String>
    var change: Decimal { analysis - baseline }
}

nonisolated struct SpendingComparison: Sendable {
    let analysis: SpendingComparisonPeriod
    let baseline: SpendingComparisonPeriod
    let contributors: [SpendingDifference]
    var spendingChange: Decimal { analysis.report.spending - baseline.report.spending }
    var incomeChange: Decimal { analysis.report.income - baseline.report.income }
    static func percentage(change: Decimal, baseline: Decimal) -> Decimal? { baseline > 0 ? change / baseline * 100 : nil }
}

nonisolated enum SpendingIntelligence {
    static func eligibleSalaryRules(categories: CategorySnapshot, sources: FinancialSourceContext) -> [CategoryRule] {
        let active = Set(categories.categories.filter { !$0.isArchived }.map(\.id))
        return categories.automation?.rules.filter { rule in
            rule.isEnabled && rule.direction == "credit" && active.contains(rule.categoryID) &&
                sources.accounts.contains { $0.id == rule.accountID && $0.domain == "bank" && (rule.currency == nil || rule.currency == $0.currency) }
        } ?? []
    }

    static func salarySetupIssue(preferences: IntelligencePreferences?, categories: CategorySnapshot, sources: FinancialSourceContext) -> String? {
        guard preferences?.salaryAssistanceEnabled == true else { return nil }
        let selected = preferences!.salaryRuleIDs
        let eligible = Set(eligibleSalaryRules(categories: categories, sources: sources).map(\.id))
        guard !selected.isEmpty, selected.isSubset(of: eligible) else {
            return "Setup incomplete: select an enabled salary rule for an available bank account and active category. Review Salary assistance; rules are managed in Transactions → Category rules."
        }
        return nil
    }

    static func compare(analysis: SpendingProjection, rows: [SpendingSourceRow], metadata: FinancialIntelligenceSnapshot,
                        sources: FinancialSourceContext, currency: String, accountIDs: Set<String>,
                        start: StatementDate, end: StatementDate, baselineStart: StatementDate, baselineEnd: StatementDate,
                        spendingIntents: [String: TransactionSpendingIntent] = [:]) throws -> SpendingComparison {
        let baseline = try project(rows: rows, metadata: metadata, sources: sources, currency: currency, accountIDs: accountIDs,
            start: baselineStart, end: baselineEnd, allSuggestions: [], spendingIntents: spendingIntents)
        func period(_ report: SpendingProjection, _ lower: StatementDate, _ upper: StatementDate) -> SpendingComparisonPeriod {
            let expenses = report.rows.filter { $0.treatment == .expense }
            let purchases = expenses.filter { !$0.source.isCharge }
            let charges = expenses.filter { $0.source.isCharge }
            let scope = sources.accountScope(selectedAccountIDs: accountIDs)
            let coverage = sources.accounts.filter { $0.currency == currency && scope.includes($0.id) }.map { account in
                SpendingComparisonPeriod.Coverage(id: account.id, title: account.title,
                    recordedThrough: sources.periods.filter { $0.accountID == account.id && $0.start <= upper }.map(\.end).max(),
                    complete: sources.hasCompleteCoverage(accountID: account.id, start: lower, end: upper))
            }
            return .init(start: lower, end: upper, report: report, coverage: coverage,
                purchaseIDs: Set(purchases.map(\.id)), purchaseAmount: purchases.reduce(0) { $0 + $1.spending },
                chargeIDs: Set(charges.map(\.id)), chargeAmount: charges.reduce(0) { $0 + $1.spending })
        }
        let current = Dictionary(uniqueKeysWithValues: analysis.categories.map { ($0.id, $0) })
        let previous = Dictionary(uniqueKeysWithValues: baseline.categories.map { ($0.id, $0) })
        let differences = Set(current.keys).union(previous.keys).map { id in
            SpendingDifference(id: id, title: (current[id] ?? previous[id])!.title,
                analysis: current[id]?.amount ?? 0, baseline: previous[id]?.amount ?? 0,
                analysisIDs: current[id]?.transactionIDs ?? [], baselineIDs: previous[id]?.transactionIDs ?? [])
        }.sorted { (abs($0.change), $0.id) > (abs($1.change), $1.id) }
        var leading = Array(differences.filter { $0.id != "uncategorized" }.prefix(5))
        if let unknown = differences.first(where: { $0.id == "uncategorized" }) { leading.append(unknown) }
        let leadingIDs = Set(leading.map(\.id)), remaining = differences.filter { !leadingIDs.contains($0.id) }
        if !remaining.isEmpty {
            leading.append(.init(id: "comparison-remainder", title: "Other categories (\(remaining.count))",
                analysis: remaining.reduce(0) { $0 + $1.analysis }, baseline: remaining.reduce(0) { $0 + $1.baseline },
                analysisIDs: Set(remaining.flatMap(\.analysisIDs)), baselineIDs: Set(remaining.flatMap(\.baselineIDs))))
        }
        return .init(analysis: period(analysis, start, end), baseline: period(baseline, baselineStart, baselineEnd), contributors: leading)
    }

    static func rows(transactions: [Transaction], sources: FinancialSourceContext, cards: CardStoreSnapshot,
                     categories: CategorySnapshot, salaryRuleIDs: Set<String> = []) throws -> [SpendingSourceRow] {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.spendingRows, count: transactions.count)
        defer { GmailQualificationTiming.end(.spendingRows, started: timing, count: transactions.count) }
#endif
        try Task.checkCancellation()
        let accounts = Dictionary(uniqueKeysWithValues: sources.accounts.map { ($0.id, $0) })
        let evidence = Dictionary(uniqueKeysWithValues: cards.transactionEvidence.map { ($0.transactionID, $0) })
        let names = Dictionary(uniqueKeysWithValues: categories.categories.map { ($0.id, $0.name) })
        let activeCategoryIDs = Set(categories.categories.filter { !$0.isArchived }.map(\.id))
        let activeRules = categories.automation?.rules.filter { activeCategoryIDs.contains($0.categoryID) } ?? []
        let eligibleSalaryIDs = salaryRuleIDs.intersection(eligibleSalaryRules(categories: categories, sources: sources).map(\.id))
        return try transactions.compactMap { transaction in
            try Task.checkCancellation()
            guard let id = transaction.repositoryTransactionId, let accountID = transaction.repositoryAccountId,
                  let account = accounts[accountID] else { return nil }
            let card = evidence[id]
            let explicit = card?.sourceTransactionDate ?? transaction.repositoryPreferredSourceTransactionDate ?? transaction.sourceProvenance.first?.sourceTransactionDate
            let categoryID = categories.assignments[id]
            var salary = false
            if transaction.creditMoney != nil, account.domain == "bank", !eligibleSalaryIDs.isEmpty {
                let narration = transaction.description.uppercased()
                if !narration.contains("BONUS"), !narration.contains("AD HOC") {
                    let input = CategoryAutomationSession.inputs(transactions: [transaction], selectedIDs: [id]).first
                    // Every active rule still participates in category conflict
                    // detection for a possible salary receipt.
                    let matches = activeRules.filter { rule in input.map(rule.matches) == true }
                    salary = Set(matches.map(\.categoryID)).count == 1 &&
                        matches.contains { eligibleSalaryIDs.contains($0.id) }
                }
            }
            return SpendingSourceRow(transaction: transaction, id: id, accountID: accountID, accountTitle: account.title,
                domain: account.domain, date: explicit ?? transaction.statementDate,
                dateRole: explicit != nil ? "Source transaction date" : transaction.financialDateRole.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                summaryMembership: card?.summaryMembership, categoryID: categoryID,
                categoryName: categoryID.flatMap { names[$0] } ?? "Uncategorized",
                categoryConflict: categories.automation?.work[id]?.outcome == .conflict, isRegularSalary: salary)
        }
    }

    static func interpretation(_ row: SpendingSourceRow, confirmed: MovementEvent?,
                               spendingIntent: TransactionSpendingIntent? = nil, rejectedExpense: Bool = false) -> SpendingReviewRow {
        if row.isLoanOrEMI {
            return .init(source: row, treatment: .outsideScope,
                explanation: "Source-identified loan or EMI entry. Excluded from analysis; the original entry and card balance remain unchanged.")
        }
        if let event = confirmed {
            let treatment: SpendingTreatment
            switch event.kind {
            case .ownTransfer: treatment = .ownTransfer
            case .cardPayment: treatment = .cardPayment
            case .reversal: treatment = .reversal
            case .borrowing: treatment = .outsideScope
            case .expense: treatment = .expense
            case .income: treatment = .income
            case .refund:
                treatment = row.isBankIn || row.isCardDecrease ? (event.refundAllocations == nil ? .unresolved : .refund) : .expense
            case .emiConversion:
                // Preserve legacy relationship metadata without continuing its
                // superseded instalment-date recognition policy.
                treatment = row.isCardIncrease && !event.consumptionTransactionIDs.contains(row.id) ? .expense : .outsideScope
            }
            let explanation = event.kind == .refund && event.refundAllocations == nil
                ? "Saved refund has no reviewed amount allocation. The original purchase stays gross; the credit needs allocation review and is not income or a receipt-month spending deduction. " + event.explanation
                : event.kind.isInScope ? "Confirmed \(event.kind.title.lowercased()). " + event.explanation
                : (treatment == .expense ? "Original purchase counted once on its source date. Related EMI entries are excluded from analysis."
                   : "Loan or EMI entry excluded from analysis. Its original facts and saved historical interpretation are retained.")
            return .init(source: row, treatment: treatment, explanation: explanation,
                         refundNeedsReview: event.kind == .refund && event.refundAllocations == nil)
        }
        if row.isBankOut, spendingIntent?.kind == .deliberatelySuppressed || rejectedExpense {
            return .init(source: row, treatment: .unresolved,
                explanation: "Your saved choice suppresses automatic spending treatment. Category and source facts remain separate.")
        }
        if row.isBankOut, row.transaction.money.amount < 0, spendingIntent?.kind == .automaticExpense {
            return .init(source: row, treatment: .expense,
                explanation: "An explicitly applied spending rule recognises this bank outgoing. Its saved rule version is retained independently of the category.")
        }
        if row.isRegularSalary { return .init(source: row, treatment: .income, explanation: "Matches your enabled regular-salary rule on a real bank credit.") }
        if row.isEmployerSalaryReceipt {
            return .init(source: row, treatment: .unresolved, explanation: "The source identifies employer salary. Choose its salary rule or review as income; it cannot be a self-transfer counterpart.")
        }
        if row.isReferenceReversal {
            return .init(source: row, treatment: .unresolved, explanation: "The source labels a reversal. Review the equal opposite entry and complete reference before cancelling their spending effect.")
        }
        let text = row.text
        if row.isCashAdvanceFee {
            return .init(source: row, treatment: .expense,
                explanation: "The CBQ card source identifies this exact charge as a cash-advance fee. Cash principal and settlements keep their separate meaning.")
        }
        if row.isCharge {
            return .init(source: row, treatment: .expense, explanation: "The source identifies a fee or interest charge. Principal and settlements remain separate.")
        }
        let settlement = ["TRANSFER", "NEFT", "IMPS", "RDA ", "REMITT", "AL DAR", "LOAN", "CASH ADVANCE", "INSTALMENT", "INSTALLMENT", "REVERSAL", "REFUND", "PAYMENT RECEIVED", "PAID BY", "CARD BILL", "AUTOPAY", "AUTO DEBIT"].contains(where: text.contains)
        let heldSummaries: Set<CardTransactionSummaryMembership> = [.cbqV1PaymentReceived, .cbqV2TotalPayment, .cbqV2CreditReversal, .cbqV2BilledInstallment]
        let summaryHeld = row.summaryMembership.map { heldSummaries.contains($0) } ?? false
        if settlement || summaryHeld || row.isBankIn || row.isCardDecrease {
            return .init(source: row, treatment: .unresolved, explanation: "Possible settlement, financing, transfer or credit. Review its meaning before counting it as income or spending.")
        }
        if row.isCardIncrease { return .init(source: row, treatment: .expense, explanation: "Recorded card purchase or cost; no settlement relationship is confirmed. Category remains independently editable.") }
        return .init(source: row, treatment: .unresolved, explanation: "The bank debit does not establish whether this is spending, a transfer or debt repayment. Review the original narration and receiving account.")
    }

    static func suggestions(rows: [SpendingSourceRow], metadata: FinancialIntelligenceSnapshot, sources: FinancialSourceContext) throws -> [MovementSuggestion] {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.movementSuggestions, count: rows.count)
        defer { GmailQualificationTiming.end(.movementSuggestions, started: timing, count: rows.count) }
#endif
        try Task.checkCancellation()
        let occupied = metadata.confirmedByTransaction
        let dismissed = Set(metadata.movements.filter { $0.decision == .rejected }.map(\.id))
        let candidates = rows.filter { !($0.isLoanOrEMI) && occupied[$0.id] == nil && $0.date != nil }.sorted { ($0.date!, $0.id) < ($1.date!, $1.id) }
        let accounts = Dictionary(uniqueKeysWithValues: sources.accounts.map { ($0.id, $0) })
        let references = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0.movementReferences) })
        let texts = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0.text) })
        let days = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, Int(FinancialCalendar.instant($0.date!)!.timeIntervalSince1970 / 86_400)) })
        var exact: [MovementSuggestion] = [], possible: [MovementSuggestion] = []
        var lower = 0
        for (index, left) in candidates.enumerated() {
            try Task.checkCancellation()
            while lower < index, days[left.id]! - days[candidates[lower].id]! > 7 { lower += 1 }
            for right in candidates[lower..<index] {
                try Task.checkCancellation()
                let sameCurrency = left.currency == right.currency, equal = left.amount == right.amount
                let leftRefs = references[left.id]!, rightRefs = references[right.id]!
                let shared = leftRefs.count == 1 && leftRefs == rightRefs
                let conflictingScheme = !leftRefs.isEmpty && !rightRefs.isEmpty && leftRefs.isDisjoint(with: rightRefs) &&
                    (sameCurrency || (leftRefs.allSatisfy { $0.hasPrefix("IMPS:") } && rightRefs.allSatisfy { $0.hasPrefix("IMPS:") }))
                let reciprocal = accounts[right.accountID]?.verifiedIdentifiers.contains(where: texts[left.id]!.contains) == true &&
                    accounts[left.accountID]?.verifiedIdentifiers.contains(where: texts[right.id]!.contains) == true
                let reversal = sameCurrency && equal && left.accountID == right.accountID &&
                    left.transaction.money.amount + right.transaction.money.amount == 0 &&
                    (left.isReferenceReversal || right.isReferenceReversal) && shared
                let bank = left.isBankOut ? left : right
                let incoming = left.isBankIn ? left : right
                let card = left.isCardDecrease ? left : right
                let cardPayment = sameCurrency && equal && bank.isBankOut && card.isCardDecrease &&
                    ["PAYMENT", "PAID BY", "CARD BILL"].contains(where: card.text.contains) &&
                    (shared || reciprocal || accounts[card.accountID]?.verifiedIdentifiers.contains(where: bank.text.contains) == true) && !conflictingScheme
                let allowedRoute = !(accounts[bank.accountID]?.routeType == "NRO" && accounts[incoming.accountID]?.routeType == "NRE")
                let complementaryRemittance = !sameCurrency && bank.isExchangeRemittanceOut && incoming.isInwardRemittance
                let transfer = left.accountID != right.accountID && bank.isBankOut && incoming.isBankIn &&
                    (!sameCurrency || equal) && allowedRoute && !conflictingScheme &&
                    !left.isRegularSalary && !right.isRegularSalary && !left.isEmployerSalaryReceipt && !right.isEmployerSalaryReceipt &&
                    !left.isReferenceReversal && !right.isReferenceReversal &&
                    (shared || reciprocal || complementaryRemittance)
                guard reversal || cardPayment || transfer else { continue }
                let kind: MovementKind = reversal ? .reversal : (cardPayment ? .cardPayment : .ownTransfer)
                let ids = [left.id, right.id].sorted()
                var reasons: [String] = []
                if shared { reasons.append("Complete matching reference " + leftRefs.first!.components(separatedBy: ":").dropFirst().joined(separator: ":")) }
                if reciprocal { reasons.append("each source names the other verified account") }
                if reversal { reasons.append("source reversal, same account, equal opposite native values") }
                if cardPayment { reasons.append("bank debit and source card-payment credit reduce the same card liability") }
                if complementaryRemittance {
                    reasons.append("source exchange purchase and inward-remittance channel")
                    if !shared && !reciprocal { reasons.append("different references; exact linkage still needs your review") }
                }
                reasons.append("\(abs(days[left.id]! - days[right.id]!)) days apart")
                reasons.append(sameCurrency ? "equal native \(left.currency) amounts" : "both native currencies retained; no historical rate assumed")
                let suggestion = MovementSuggestion(id: MovementSuggestion.identity(kind, ids: ids), kind: kind,
                    transactionIDs: ids, explanation: reasons.joined(separator: " · "))
                if reversal || (cardPayment && shared) || (transfer && shared) { exact.append(suggestion) }
                else { possible.append(suggestion) }
            }
        }
        // A specific source-linked event outranks weaker alternatives sharing
        // its legs, but it still needs review. Multiple exact candidates remain.
        let specificallyLinked = Set(exact.flatMap(\.transactionIDs))
        let result = (exact + possible.filter { specificallyLinked.isDisjoint(with: $0.transactionIDs) })
            .filter { !dismissed.contains($0.id) }
        let counts = Dictionary(result.flatMap(\.transactionIDs).map { ($0, 1) }, uniquingKeysWith: +)
        return result.map { item in var value = item; value.ambiguityCount = item.transactionIDs.map { counts[$0, default: 0] }.max() ?? 0; return value }
    }

    static func suggestionGroups(_ suggestions: [MovementSuggestion]) -> [MovementSuggestionGroup] {
        var groups: [MovementSuggestionGroup] = []
        for suggestion in suggestions {
            var ids = Set(suggestion.transactionIDs), values = [suggestion]
            var index = 0
            while index < groups.count {
                if !ids.isDisjoint(with: groups[index].transactionIDs) {
                    let group = groups.remove(at: index)
                    ids.formUnion(group.transactionIDs); values += group.suggestions
                    index = 0
                } else { index += 1 }
            }
            groups.append(.init(suggestions: values.sorted { $0.id < $1.id }))
        }
        return groups
    }

    static func contradiction(_ event: MovementEvent, rows: [SpendingSourceRow], sources: FinancialSourceContext) -> String? {
        guard event.decision == .confirmed, event.kind == .ownTransfer else { return nil }
        let legs = rows.filter { event.transactionIDs.contains($0.id) }
        if legs.contains(where: \.isEmployerSalaryReceipt) { return "This confirmed transfer includes a source-established employer salary receipt. Review its meaning; your saved choice remains in effect." }
        if legs.contains(where: \.isReferenceReversal) { return "This confirmed transfer includes a source-labelled reversal. Review the original reference; your saved choice remains in effect." }
        let types = Dictionary(uniqueKeysWithValues: sources.accounts.map { ($0.id, $0.routeType) })
        if legs.contains(where: { $0.isBankOut && types[$0.accountID] == "NRO" }) && legs.contains(where: { $0.isBankIn && types[$0.accountID] == "NRE" }) {
            return "This confirmed NRO-to-NRE transfer conflicts with your allowed routes. Review it; your saved choice remains in effect."
        }
        return nil
    }

    /// Interpret the complete available history once, before any reporting
    /// period, account or category filter can hide a supporting credit.
    static func resolvedRows(rows: [SpendingSourceRow], metadata: FinancialIntelligenceSnapshot,
                             spendingIntents: [String: TransactionSpendingIntent] = [:]) throws -> [SpendingReviewRow] {
        try Task.checkCancellation()
        guard Set(rows.map(\.id)).count == rows.count else { throw FinancialIntelligenceError.invalidRecord }
        var confirmed: [String: MovementEvent] = [:]
        for event in metadata.movements where event.decision == .confirmed {
            guard event.workspaceID == metadata.workspaceID,
                  Set(event.transactionIDs).count == event.transactionIDs.count else { throw FinancialIntelligenceError.invalidRecord }
            for id in event.transactionIDs {
                guard confirmed.updateValue(event, forKey: id) == nil else { throw FinancialIntelligenceError.occupiedLeg }
            }
        }
        let rejectedExpenseIDs = Set(metadata.movements.filter {
            $0.decision == .rejected && $0.kind == .expense && $0.transactionIDs.count == 1
        }.flatMap(\.transactionIDs))
        var review = try rows.map { row -> SpendingReviewRow in
            try Task.checkCancellation()
            var value = interpretation(row, confirmed: confirmed[row.id], spendingIntent: spendingIntents[row.id],
                                       rejectedExpense: rejectedExpenseIDs.contains(row.id))
            if value.treatment == .expense {
                let gross = try Money(amount: row.amount, currency: row.currency)
                value.amounts = .init(gross: gross, allocatedRefund: try Money(amount: 0, currency: row.currency), net: gross)
            }
            return value
        }
        let indexByID = Dictionary(uniqueKeysWithValues: review.indices.map { (review[$0].id, $0) })
        for event in metadata.movements where event.decision == .confirmed && event.kind == .refund {
            try Task.checkCancellation()
            guard event.refundAllocations != nil else {
                for id in event.transactionIDs {
                    guard let index = indexByID[id] else { continue }
                    let row = review[index].source
                    if row.isBankIn || row.isCardDecrease {
                        review[index].refundResidual = try Money(amount: row.amount, currency: row.currency)
                        review[index].refundNeedsReview = true
                    }
                }
                continue
            }
            let legs = try event.transactionIDs.map { id -> MovementRefundValidation.Leg in
                guard let index = indexByID[id] else { throw FinancialIntelligenceError.invalidRecord }
                let row = review[index].source
                let direction = row.isBankOut ? "debit" : row.isBankIn ? "credit" :
                    row.isCardIncrease ? "card_increase_owed" : row.isCardDecrease ? "card_decrease_owed" : ""
                return .init(transactionID: id, accountID: row.accountID, domain: row.domain,
                             direction: direction, money: row.transaction.money)
            }
            let resolved = try MovementRefundValidation.resolve(event, legs: legs)
            guard let purchaseIndex = indexByID[resolved.purchaseTransactionID] else { throw FinancialIntelligenceError.invalidRecord }
            let purchase = review[purchaseIndex].source
            let details = try resolved.allocatedByCredit.keys.sorted().map { id -> SpendingRefundDetail in
                guard let index = indexByID[id], let allocated = resolved.allocatedByCredit[id],
                      let residual = resolved.residualByCredit[id] else { throw FinancialIntelligenceError.invalidRecord }
                let credit = review[index].source
                return .init(eventID: event.id, purchaseTransactionID: purchase.id, creditTransactionID: id,
                             purchaseDate: purchase.date, creditDate: credit.date, allocated: allocated,
                             creditAmount: try Money(amount: credit.amount, currency: credit.currency), residual: residual)
            }
            // Source exclusions and missing/contradictory analytical dates stay
            // visible. They cannot produce a subtraction from zero spending.
            let canAttribute = review[purchaseIndex].treatment == .expense && purchase.date != nil &&
                details.allSatisfy { detail in
                    guard let creditDate = detail.creditDate, let purchaseDate = purchase.date,
                          let index = indexByID[detail.creditTransactionID] else { return false }
                    return creditDate >= purchaseDate && !review[index].source.isLoanOrEMI
                }
            review[purchaseIndex].refundDetails = details
            review[purchaseIndex].refundNeedsReview = !canAttribute
            if canAttribute {
                review[purchaseIndex].amounts = .init(gross: resolved.gross, allocatedRefund: resolved.allocated, net: resolved.net)
                review[purchaseIndex].explanation += " Allocated refunds reduce this purchase on its source date and current category. Credit receipt dates stay unchanged."
            } else {
                review[purchaseIndex].explanation += " Refund attribution needs review because the purchase is outside spending scope or its source dates are unavailable or contradictory."
            }
            for detail in details {
                guard let index = indexByID[detail.creditTransactionID] else { throw FinancialIntelligenceError.invalidRecord }
                review[index].refundDetails = [detail]
                review[index].refundResidual = detail.residual
                review[index].refundNeedsReview = !canAttribute || detail.residual.amount > 0
                review[index].explanation += " The allocation belongs to the original purchase; this credit adds no receipt-month spending deduction or income."
                if detail.residual.amount > 0 {
                    review[index].explanation += " The remaining credit amount is unresolved."
                }
            }
        }
        return review
    }

    private static func totalAmounts(_ rows: [SpendingReviewRow], currency: String) throws -> SpendingAmounts {
        try rows.compactMap(\.amounts).reduce(SpendingAmounts.zero(currency: currency)) { try $0.adding($1) }
    }

    static func project(rows: [SpendingSourceRow], metadata: FinancialIntelligenceSnapshot, sources: FinancialSourceContext,
                        currency: String, accountIDs: Set<String>, start: StatementDate?, end: StatementDate?, allSuggestions: [MovementSuggestion]? = nil,
                        spendingIntents: [String: TransactionSpendingIntent] = [:]) throws -> SpendingProjection {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.spendingProjection, count: rows.count)
        defer { GmailQualificationTiming.end(.spendingProjection, started: timing, count: rows.count) }
#endif
        try Task.checkCancellation()
        let resolved = try resolvedRows(rows: rows, metadata: metadata, spendingIntents: spendingIntents)
        let scope = sources.accountScope(selectedAccountIDs: accountIDs)
        let selectedAccounts = sources.accounts.filter { $0.currency == currency && scope.includes($0.id) }
        let selectedIDs = Set(selectedAccounts.map(\.id))
        let accountRows = rows.filter { $0.currency == currency && selectedIDs.contains($0.accountID) }
        let selected = accountRows.filter {
            ($0.date.map { date in (start == nil || date >= start!) && (end == nil || date <= end!) } ?? (start == nil && end == nil)) }
        let visibleIDs = Set(selected.map(\.id))
        let review = resolved.filter { visibleIDs.contains($0.id) }
        let grouped = Dictionary(grouping: review.compactMap { row in row.source.date.map { (String($0.canonical.prefix(7)), row) } }, by: \.0)
        var months = Set(grouped.keys)
        if let first = start ?? selected.compactMap(\.date).min(), let last = end ?? selected.compactMap(\.date).max() {
            var year = first.year, month = first.month
            while (year, month) <= (last.year, last.month) {
                months.insert(String(format: "%04d-%02d", year, month))
                month += 1; if month == 13 { month = 1; year += 1 }
            }
        }
        let periods = try months.sorted().compactMap { key -> SpendingPeriodValue? in
            try Task.checkCancellation()
            guard let month = try? SelectedStatementMonth(canonical: key), let first = try? StatementDate(year: month.year, month: month.month, day: 1), let last = FinancialCalendar.lastDay(month) else { return nil }
            let values = grouped[key, default: []].map(\.1)
            let lower = max(first, start ?? first), upper = min(last, end ?? last)
            let incomplete = selectedAccounts.filter { !sources.hasCompleteCoverage(accountID: $0.id, start: lower, end: upper) }.map(\.title)
            let amounts = try totalAmounts(values, currency: currency)
            return .init(id: key, title: key, income: values.reduce(0) { $0 + $1.income }, spending: amounts.net.amount,
                transactionIDs: Set(values.map(\.id)), unresolvedIDs: Set(values.filter { $0.treatment == .unresolved || $0.refundNeedsReview }.map(\.id)),
                incompleteAccounts: incomplete, amounts: amounts, supportingTransactionIDs: Set(values.flatMap(\.supportingTransactionIDs)))
        }
        let categoryGroups = Dictionary(grouping: review.filter { $0.treatment == .expense }) {
            $0.source.categoryConflict ? "conflict" : ($0.source.categoryID ?? "uncategorized")
        }
        let categories = try categoryGroups.map { key, values in
            let amounts = try totalAmounts(values, currency: currency)
            return SpendingCategoryValue(id: key, title: key == "conflict" ? "Category conflict" : values[0].source.categoryName,
                amount: amounts.net.amount, transactionIDs: Set(values.map(\.id)), amounts: amounts,
                supportingTransactionIDs: Set(values.flatMap(\.supportingTransactionIDs)))
        }.sorted { ($0.amount, $0.id) > ($1.amount, $1.id) }
        let selectedTransactionIDs = Set(selected.map(\.id))
        // Keep the complete relationship for interpretation, but do not expose
        // a partial pair when one of its accounts is outside the history scope.
        let excludedHistory = Set(sources.accounts.filter(\.isHistoryOnly).map(\.id)).subtracting(accountIDs)
        let hiddenHistoryRows = Set(rows.filter { excludedHistory.contains($0.accountID) }.map(\.id))
        let amounts = try totalAmounts(review, currency: currency)
        return .init(rows: review, periods: periods, categories: categories,
            suggestions: try (allSuggestions ?? suggestions(rows: rows, metadata: metadata, sources: sources)).filter {
                !$0.transactionIDs.allSatisfy { !selectedTransactionIDs.contains($0) }
                    && $0.transactionIDs.allSatisfy { !hiddenHistoryRows.contains($0) }
            },
            selectedCurrency: currency, income: review.reduce(0) { $0 + $1.income }, spending: amounts.net.amount,
            unresolvedCount: review.filter { $0.treatment == .unresolved || $0.refundNeedsReview }.count,
            missingDateCount: accountRows.filter { $0.date == nil }.count, amounts: amounts,
            supportingTransactionIDs: Set(review.flatMap(\.supportingTransactionIDs)))
    }
}
