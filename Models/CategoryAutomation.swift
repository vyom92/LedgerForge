import Foundation

/// Owner metadata only. Rules read the original canonical text; they never edit it.
nonisolated public struct CategoryRule: Identifiable, Codable, Equatable, Sendable {
    public enum BankExpenseAction: String, Codable, Sendable { case expense }
    public var id: String
    public var workspaceID: String
    public var name: String
    public var version: Int
    public var isEnabled: Bool
    public var categoryID: String
    public var accountID: String?
    public var currency: String?
    public var direction: String?
    public var predicates: [CategoryTextPredicate]
    /// Absent in earlier payloads. Category-only rules retain their meaning.
    public var bankExpenseAction: BankExpenseAction? = nil

    public func validate() throws {
        guard !id.isEmpty, !workspaceID.isEmpty, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              version > 0, !categoryID.isEmpty, !predicates.isEmpty, predicates.count <= 12,
              predicates.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              predicates.contains(where: { $0.match != .doesNotContain }),
              predicates.allSatisfy({ $0.match != .doesNotContain || $0.field == .narration }),
              direction == nil || ["debit", "credit", "card_increase_owed", "card_decrease_owed"].contains(direction!),
              currency == nil || (currency!.count == 3 && currency == currency?.uppercased()) else {
            throw CategoryAutomationError.invalidRule
        }
    }

    public func matches(_ input: CategoryRuleInput) -> Bool {
        guard isEnabled, accountID == nil || accountID == input.accountID,
              currency == nil || currency == input.currency,
              direction == nil || direction == input.direction else { return false }
        return predicates.allSatisfy { predicate in
            let value = predicate.field == .narration ? input.narration : input.reference
            switch predicate.match {
            case .exact: return value.compare(predicate.text, options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) == .orderedSame
            case .contains: return value.range(of: predicate.text, options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) != nil
            case .doesNotContain: return value.range(of: predicate.text, options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) == nil
            }
        }
    }
}

nonisolated public struct CategoryTextPredicate: Codable, Equatable, Sendable {
    public enum Field: String, Codable, CaseIterable, Sendable { case narration, reference }
    public enum Match: String, Codable, CaseIterable, Sendable { case exact, contains, doesNotContain }
    public var field: Field
    public var match: Match
    public var text: String
}

nonisolated public struct CategoryRuleInput: Equatable, Sendable {
    public let transactionID: String
    public let accountID: String?
    public let currency: String
    public let direction: String
    public let narration: String
    public let reference: String
    public let importSessionID: String?

    public init(transaction: TransactionDTO) {
        transactionID = transaction.id; accountID = transaction.accountId
        currency = transaction.nativeCurrency; direction = transaction.direction
        narration = transaction.description ?? ""; reference = transaction.reference ?? ""
        importSessionID = transaction.importSessionId
    }

    init(transactionID: String, accountID: String?, currency: String, direction: String, narration: String, reference: String,
         importSessionID: String? = nil) {
        self.transactionID = transactionID; self.accountID = accountID; self.currency = currency
        self.direction = direction; self.narration = narration; self.reference = reference
        self.importSessionID = importSessionID
    }
}

nonisolated public struct CategoryRuleMatch: Codable, Equatable, Sendable {
    public let ruleID: String
    public let version: Int
}

nonisolated public struct CategoryIntent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case automatic, manual, deliberatelyCleared }
    public let kind: Kind
    public let categoryID: String?
    public let matches: [CategoryRuleMatch]
    public var protectsManualChoice: Bool { kind != .automatic }
}

/// Historical financial treatment is independent of the current category and
/// of future edits to the rules that originally supplied this provenance.
nonisolated public struct TransactionSpendingIntent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case automaticExpense, deliberatelySuppressed }
    public let kind: Kind
    public let matches: [CategoryRuleMatch]

    public func validate() throws {
        guard Set(matches.map(\.ruleID)).count == matches.count,
              matches.allSatisfy({ !$0.ruleID.isEmpty && $0.version > 0 }),
              kind == .automaticExpense ? !matches.isEmpty : matches.isEmpty else {
            throw CategoryAutomationError.invalidState
        }
    }
}

/// Transient canonical facts, staged with automation metadata. They are never
/// persisted separately, nor supplied by editable category or display text.
nonisolated public struct CategorySpendingContext: Equatable, Sendable {
    public let sourceEligible: Bool
    public let interpretations: [MovementEvent]
    public var protectsInterpretation: Bool {
        interpretations.contains { $0.decision == .confirmed || ($0.decision == .rejected && $0.kind == .expense) }
    }
}

nonisolated public struct CategoryImportWork: Codable, Equatable, Sendable {
    public enum Origin: String, Codable, Sendable { case newImport, historical }
    public enum Outcome: String, Codable, Sendable { case pending, assigned, noMatch, conflict, protected, retryable }
    public let transactionID: String
    public let importSessionID: String
    public let outcome: Outcome
    public let explanation: String
    public var origin: Origin = .newImport
}

nonisolated public struct CategoryAutomationSnapshot: Equatable, Sendable {
    public var rules: [CategoryRule] = []
    public var intents: [String: CategoryIntent] = [:]
    public var work: [String: CategoryImportWork] = [:]
    public var supportsSpendingIntent = false
    public var spendingIntents: [String: TransactionSpendingIntent] = [:]
    public var spendingContexts: [String: CategorySpendingContext] = [:]
    public var pendingIDs: Set<String> {
        Set(work.values.filter { $0.outcome == .pending || $0.outcome == .retryable }.map(\.transactionID))
    }
}

nonisolated public enum CategoryAutomationError: Error, Equatable, LocalizedError {
    case unavailable, invalidRule, invalidState, stalePreview, ruleInUse
    public var errorDescription: String? {
        switch self {
        case .unavailable: return "Category automation is unavailable for this ledger."
        case .invalidRule: return "Give the rule a name, a category and a positive text condition. Exclusions must use narration."
        case .invalidState: return "Category metadata could not be reconciled with this ledger."
        case .stalePreview: return "Rules, categories or financial treatment changed. Review a fresh preview before applying."
        case .ruleInUse: return "A saved rule still uses this category. Edit or delete the rule first."
        }
    }
}

nonisolated public struct CategoryEvaluation: Equatable, Sendable {
    public struct SpendingDecision: Equatable, Sendable {
        public let expected: TransactionSpendingIntent?
        public let proposed: TransactionSpendingIntent?
        public let context: CategorySpendingContext?
        public let explanation: String
        public var changesIntent: Bool { expected != proposed }
        public var removesIntent: Bool { expected?.kind == .automaticExpense && proposed == nil }
    }
    public struct Decision: Equatable, Sendable {
        public let transactionID: String
        public let categoryID: String?
        public let outcome: CategoryImportWork.Outcome
        public let matches: [CategoryRuleMatch]
        public let explanation: String
        public var spending: SpendingDecision? = nil

        /// A concurrent manual category choice wins, but may not authorize a
        /// different financial action from the one that was actually reviewed.
        public func accepts(_ reviewed: Self) -> Bool {
            spending == reviewed.spending && (outcome == .protected || self == reviewed)
        }
    }
    public let rules: [CategoryRule]
    public let activeCategoryIDs: Set<String>
    public let decisions: [Decision]
    private let witnessesByID: [String: Witness]

    /// Only the pure evaluator can mint this binding. It is ephemeral process
    /// state, never persisted, decoded, or supplied by a caller-built decision.
    private struct Witness: Sendable {
        let input: CategoryRuleInput
        let assignedCategoryID: String?
        let categoryIntent: CategoryIntent?
        let spendingIntent: TransactionSpendingIntent?
        let spendingContext: CategorySpendingContext?
        let supportsSpendingIntent: Bool
        let decision: Decision

        func matches(_ currentInput: CategoryRuleInput, snapshot: CategoryAutomationSnapshot,
                     assignedCategoryID: String?) -> Bool {
            input == currentInput && self.assignedCategoryID == assignedCategoryID &&
                categoryIntent == snapshot.intents[input.transactionID] &&
                spendingIntent == snapshot.spendingIntents[input.transactionID] &&
                spendingContext == snapshot.spendingContexts[input.transactionID] &&
                supportsSpendingIntent == snapshot.supportsSpendingIntent
        }
    }

    /// Explicit construction remains available for presentation and tests, but
    /// cannot confer authority to skip the repository's fresh evaluation.
    init(rules: [CategoryRule], activeCategoryIDs: Set<String>, decisions: [Decision]) {
        self.rules = rules
        self.activeCategoryIDs = activeCategoryIDs
        self.decisions = decisions
        witnessesByID = [:]
    }

    private init(rules: [CategoryRule], activeCategoryIDs: Set<String>, decisions: [Decision],
                 witnessesByID: [String: Witness]) {
        self.rules = rules
        self.activeCategoryIDs = activeCategoryIDs
        self.decisions = decisions
        self.witnessesByID = witnessesByID
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rules == rhs.rules && lhs.activeCategoryIDs == rhs.activeCategoryIDs && lhs.decisions == rhs.decisions
    }

    /// The durable caller first establishes these global preconditions within
    /// its write transaction, then supplies each freshly read canonical input
    /// and metadata value. A missing or changed witness takes the normal matcher
    /// path; the existing accepts check still decides whether Apply may proceed.
    func validatedDecisionLookup(rules currentRules: [CategoryRule], activeCategoryIDs currentActiveIDs: Set<String>) throws
        -> @Sendable (CategoryRuleInput, CategoryAutomationSnapshot, String?) -> Decision? {
        guard rules == currentRules, activeCategoryIDs == currentActiveIDs,
              Set(decisions.map(\.transactionID)).count == decisions.count else { throw CategoryAutomationError.stalePreview }
        return { [witnessesByID] input, snapshot, assignedCategoryID in
            guard let witness = witnessesByID[input.transactionID],
                  witness.matches(input, snapshot: snapshot, assignedCategoryID: assignedCategoryID) else { return nil }
            return witness.decision
        }
    }

    public static func evaluate(inputs: [CategoryRuleInput], snapshot: CategoryAutomationSnapshot,
                                assignments: [String: String], activeCategoryIDs: Set<String>) -> Self {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.categoryEvaluation, count: inputs.count)
        defer { GmailQualificationTiming.end(.categoryEvaluation, started: timing, count: inputs.count) }
#endif
        let rules = snapshot.rules.sorted { $0.id < $1.id }
        let decisions = inputs.map { input in
            let spending = spendingDecision(input: input, snapshot: snapshot, rules: rules)
            let intent = snapshot.intents[input.transactionID]
            if intent?.protectsManualChoice == true || (intent == nil && assignments[input.transactionID] != nil) {
                return Decision(transactionID: input.transactionID, categoryID: nil, outcome: .protected, matches: [], explanation: intent?.kind == .deliberatelyCleared ? "You deliberately cleared this category." : "Your existing category is protected.", spending: spending)
            }
            let matches = rules.filter { activeCategoryIDs.contains($0.categoryID) && $0.matches(input) }
            let categories = Set(matches.map(\.categoryID))
            let evidence = matches.map { CategoryRuleMatch(ruleID: $0.id, version: $0.version) }
            if categories.count > 1 {
                return Decision(transactionID: input.transactionID, categoryID: nil, outcome: .conflict, matches: evidence, explanation: "Matching rules disagree: " + matches.map(\.name).joined(separator: ", "), spending: spending)
            }
            guard let categoryID = categories.first else {
                return Decision(transactionID: input.transactionID, categoryID: nil, outcome: .noMatch, matches: [], explanation: "No enabled rule matches these source fields.", spending: spending)
            }
            return Decision(transactionID: input.transactionID, categoryID: categoryID, outcome: .assigned, matches: evidence, explanation: matches.map { "\($0.name) · v\($0.version) · " + $0.predicates.map { "\($0.field.rawValue) \($0.match.rawValue) \($0.text)" }.joined(separator: "; ") }.joined(separator: " · "), spending: spending)
        }
        // Pure callers may present duplicate IDs. Preserve their result without
        // minting ambiguous witnesses; the durable boundary rejects the batch.
        guard Set(inputs.map(\.transactionID)).count == inputs.count else {
            return Self(rules: rules, activeCategoryIDs: activeCategoryIDs, decisions: decisions)
        }
        let witnesses = Dictionary(uniqueKeysWithValues: zip(inputs, decisions).map { input, decision in
            (input.transactionID, Witness(input: input, assignedCategoryID: assignments[input.transactionID],
                categoryIntent: snapshot.intents[input.transactionID], spendingIntent: snapshot.spendingIntents[input.transactionID],
                spendingContext: snapshot.spendingContexts[input.transactionID], supportsSpendingIntent: snapshot.supportsSpendingIntent,
                decision: decision))
        })
        return Self(rules: rules, activeCategoryIDs: activeCategoryIDs, decisions: decisions, witnessesByID: witnesses)
    }

    private static func spendingDecision(input: CategoryRuleInput, snapshot: CategoryAutomationSnapshot, rules: [CategoryRule]) -> SpendingDecision? {
        guard snapshot.supportsSpendingIntent else { return nil }
        let current = snapshot.spendingIntents[input.transactionID]
        let context = snapshot.spendingContexts[input.transactionID]
        func kept(_ explanation: String) -> SpendingDecision {
            .init(expected: current, proposed: current, context: context, explanation: explanation)
        }
        if current?.kind == .deliberatelySuppressed { return kept("You disabled automatic spending treatment for this transaction.") }
        guard context?.sourceEligible == true else { return kept("This source does not qualify for automatic bank spending.") }
        if context?.protectsInterpretation == true { return kept("Your reviewed financial interpretation takes precedence.") }
        // Category assignment, archival and conflicts do not control this action.
        let matching = rules.filter { $0.bankExpenseAction == .expense && $0.matches(input) }
        let proposed: TransactionSpendingIntent? = matching.isEmpty ? nil : .init(kind: .automaticExpense,
            matches: matching.map { .init(ruleID: $0.id, version: $0.version) })
        let explanation: String
        if proposed != nil { explanation = "Count this bank outflow as spending: " + matching.map { "\($0.name) · v\($0.version)" }.joined(separator: ", ") }
        else if current != nil { explanation = "Remove the automatic spending treatment; no enabled expense action matches." }
        else { explanation = "No automatic spending action matches." }
        return .init(expected: current, proposed: proposed, context: context, explanation: explanation)
    }
}

/// Frozen owner metadata for an explicit history review. A no-match result can
/// remove an automatic category, so its effect differs from an unchanged row.
nonisolated public struct CategoryHistoricalPreview: Equatable, Sendable {
    let evaluation: CategoryEvaluation
    let assignments: [String: String]
    let intents: [String: CategoryIntent]
    var spendingIntents: [String: TransactionSpendingIntent] = [:]
    var spendingContexts: [String: CategorySpendingContext] = [:]
    var work: [String: CategoryImportWork] = [:]
    var importSessionIDs: [String: String] = [:]

    var receipt: CategoryApplyReceipt {
        var value = CategoryApplyReceipt()
        for decision in decisions {
            value.record(decision, assigned: assignments[decision.transactionID],
                intent: intents[decision.transactionID], work: work[decision.transactionID],
                importSessionID: importSessionIDs[decision.transactionID], historical: true)
        }
        return value
    }

    var decisions: [CategoryEvaluation.Decision] { evaluation.decisions }
    func requireCurrent(_ snapshot: CategoryAutomationSnapshot, assignments: [String: String]) throws {
        for id in decisions.map(\.transactionID) {
            guard self.assignments[id] == assignments[id], intents[id] == snapshot.intents[id],
                  spendingIntents[id] == snapshot.spendingIntents[id], spendingContexts[id] == snapshot.spendingContexts[id],
                  work[id] == snapshot.work[id] else { throw CategoryAutomationError.stalePreview }
        }
    }
    var removalCount: Int { decisions.filter(removesCategory).count }
    var unchangedCount: Int { decisions.filter(isUnchanged).count }
    var spendingChangeCount: Int { decisions.filter { $0.spending?.changesIntent == true }.count }
    var spendingRemovalCount: Int { decisions.filter { $0.spending?.removesIntent == true }.count }

    func removesCategory(_ decision: CategoryEvaluation.Decision) -> Bool {
        assignments[decision.transactionID] != nil && intents[decision.transactionID]?.kind == .automatic &&
            (decision.outcome == .noMatch || decision.outcome == .conflict)
    }

    func isUnchanged(_ decision: CategoryEvaluation.Decision) -> Bool {
        let categoryUnchanged = decision.outcome == .protected || (decision.outcome == .noMatch && !removesCategory(decision)) ||
            (decision.outcome == .assigned && assignments[decision.transactionID] == decision.categoryID &&
             intents[decision.transactionID] == CategoryIntent(kind: .automatic, categoryID: decision.categoryID, matches: decision.matches))
        var effect = CategoryApplyReceipt()
        effect.record(decision, assigned: assignments[decision.transactionID], intent: intents[decision.transactionID],
            work: work[decision.transactionID], importSessionID: importSessionIDs[decision.transactionID], historical: true)
        return categoryUnchanged && decision.spending?.changesIntent != true && effect.reviewMetadataChangedIDs.isEmpty
    }

    func matches(assignments: [String: String], intents: [String: CategoryIntent],
                 spendingIntents: [String: TransactionSpendingIntent] = [:],
                 spendingContexts: [String: CategorySpendingContext] = [:]) -> Bool {
        self.assignments == assignments && self.intents == intents &&
            self.spendingIntents == spendingIntents && self.spendingContexts == spendingContexts
    }
}

/// Exact sets of effects, not a count of matching rules. Sets may overlap;
/// changedIDs is the union and therefore never double-counts a transaction.
nonisolated public struct CategoryApplyReceipt: Equatable, Sendable {
    var reviewedIDs: Set<String> = []
    var categoryChangedIDs: Set<String> = []
    var categoryRemovedIDs: Set<String> = []
    var intentChangedIDs: Set<String> = []
    var spendingChangedIDs: Set<String> = []
    var reviewMetadataChangedIDs: Set<String> = []
    var protectedIDs: Set<String> = []
    var conflictIDs: Set<String> = []
    var changedIDs: Set<String> {
        categoryChangedIDs.union(categoryRemovedIDs).union(intentChangedIDs)
            .union(spendingChangedIDs).union(reviewMetadataChangedIDs)
    }
    var unchangedIDs: Set<String> { reviewedIDs.subtracting(changedIDs) }
    var summary: String {
        "\(changedIDs.count) records changed · \(unchangedIDs.count) unchanged · \(protectedIDs.count) manual or cleared choices protected"
    }
    var categorySummary: String {
        "Categories: \(categoryChangedIDs.count) assignments or changes · \(categoryRemovedIDs.count) removals · \(conflictIDs.count) conflicts"
    }
    var metadataSummary: String {
        "Rule ownership: \(intentChangedIDs.count) updates · Spending treatment: \(spendingChangedIDs.count) changes · Review status: \(reviewMetadataChangedIDs.count) updates"
    }

    mutating func record(_ decision: CategoryEvaluation.Decision, assigned: String?, intent: CategoryIntent?,
                         work: CategoryImportWork?, importSessionID: String?, historical: Bool) {
        let id = decision.transactionID
        reviewedIDs.insert(id)
        if decision.outcome == .protected { protectedIDs.insert(id) }
        if decision.outcome == .conflict { conflictIDs.insert(id) }
        if decision.outcome == .assigned, let category = decision.categoryID {
            if assigned != category { categoryChangedIDs.insert(id) }
            if intent != CategoryIntent(kind: .automatic, categoryID: category, matches: decision.matches) {
                intentChangedIDs.insert(id)
            }
        } else if historical && [.noMatch, .conflict].contains(decision.outcome), intent?.kind == .automatic {
            if assigned != nil { categoryRemovedIDs.insert(id) }
            intentChangedIDs.insert(id)
        }
        if let spending = decision.spending, spending.changesIntent, historical || !spending.removesIntent {
            spendingChangedIDs.insert(id)
        }
        let explanation = [decision.explanation, decision.spending?.explanation].compactMap { $0 }.joined(separator: " ")
        if let work {
            if work.outcome != decision.outcome || work.explanation != explanation { reviewMetadataChangedIDs.insert(id) }
        } else if historical && importSessionID != nil { reviewMetadataChangedIDs.insert(id) }
    }
}

/// A frozen explicit manual choice. It contains owner metadata and canonical
/// identities only; no financial facts or movement decisions are editable here.
nonisolated public struct CategoryBatchReview: Equatable, Sendable {
    struct Item: Equatable, Sendable {
        let transactionID: String
        let accountID: String
        let categoryID: String?
        let intent: CategoryIntent?
        var isProtected: Bool { intent?.protectsManualChoice == true || (intent == nil && categoryID != nil) }
    }
    let workspaceID: String
    let categoryID: String?
    let items: [Item]
    let replaceProtectedChoices: Bool
    var transactionIDs: Set<String> { Set(items.map(\.transactionID)) }
    var protectedIDs: Set<String> { Set(items.filter { $0.isProtected && !replaceProtectedChoices }.map(\.transactionID)) }
    var proposedIntent: CategoryIntent {
        .init(kind: categoryID == nil ? .deliberatelyCleared : .manual, categoryID: categoryID, matches: [])
    }
    var changedIDs: Set<String> {
        Set(items.filter { (!($0.isProtected) || replaceProtectedChoices) &&
            ($0.categoryID != categoryID || $0.intent != proposedIntent) }.map(\.transactionID))
    }
    func validate() throws {
        guard !workspaceID.isEmpty, !items.isEmpty, transactionIDs.count == items.count,
              items.allSatisfy({ !$0.transactionID.isEmpty && !$0.accountID.isEmpty }) else {
            throw CategoryAutomationError.invalidState
        }
    }
}

nonisolated public struct CategoryBatchReceipt: Equatable, Sendable {
    let reviewedIDs: Set<String>
    let changedIDs: Set<String>
    let protectedIDs: Set<String>
    var unchangedIDs: Set<String> { reviewedIDs.subtracting(changedIDs).subtracting(protectedIDs) }
}
