import Foundation

/// Owner metadata only. Rules read the original canonical text; they never edit it.
nonisolated public struct CategoryRule: Identifiable, Codable, Equatable, Sendable {
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

    public func validate() throws {
        guard !id.isEmpty, !workspaceID.isEmpty, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              version > 0, !categoryID.isEmpty, !predicates.isEmpty, predicates.count <= 12,
              predicates.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
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
            }
        }
    }
}

nonisolated public struct CategoryTextPredicate: Codable, Equatable, Sendable {
    public enum Field: String, Codable, CaseIterable, Sendable { case narration, reference }
    public enum Match: String, Codable, CaseIterable, Sendable { case exact, contains }
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

    public init(transaction: TransactionDTO) {
        transactionID = transaction.id; accountID = transaction.accountId
        currency = transaction.nativeCurrency; direction = transaction.direction
        narration = transaction.description ?? ""; reference = transaction.reference ?? ""
    }

    init(transactionID: String, accountID: String?, currency: String, direction: String, narration: String, reference: String) {
        self.transactionID = transactionID; self.accountID = accountID; self.currency = currency
        self.direction = direction; self.narration = narration; self.reference = reference
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
    public var pendingIDs: Set<String> {
        Set(work.values.filter { $0.outcome == .pending || $0.outcome == .retryable }.map(\.transactionID))
    }
}

nonisolated public enum CategoryAutomationError: Error, Equatable, LocalizedError {
    case unavailable, invalidRule, invalidState, stalePreview, ruleInUse
    public var errorDescription: String? {
        switch self {
        case .unavailable: return "Category automation is unavailable for this ledger."
        case .invalidRule: return "Give the rule a name, a category and at least one complete text condition."
        case .invalidState: return "Category metadata could not be reconciled with this ledger."
        case .stalePreview: return "Rules or categories changed. Review a fresh preview before applying."
        case .ruleInUse: return "A saved rule still uses this category. Edit or delete the rule first."
        }
    }
}

nonisolated public struct CategoryEvaluation: Equatable, Sendable {
    public struct Decision: Equatable, Sendable {
        public let transactionID: String
        public let categoryID: String?
        public let outcome: CategoryImportWork.Outcome
        public let matches: [CategoryRuleMatch]
        public let explanation: String
    }
    public let rules: [CategoryRule]
    public let activeCategoryIDs: Set<String>
    public let decisions: [Decision]

    public static func evaluate(inputs: [CategoryRuleInput], snapshot: CategoryAutomationSnapshot,
                                assignments: [String: String], activeCategoryIDs: Set<String>) -> Self {
        let rules = snapshot.rules.sorted { $0.id < $1.id }
        return Self(rules: rules, activeCategoryIDs: activeCategoryIDs, decisions: inputs.map { input in
            let intent = snapshot.intents[input.transactionID]
            if intent?.protectsManualChoice == true || (intent == nil && assignments[input.transactionID] != nil) {
                return Decision(transactionID: input.transactionID, categoryID: nil, outcome: .protected, matches: [], explanation: intent?.kind == .deliberatelyCleared ? "You deliberately cleared this category." : "Your existing category is protected.")
            }
            let matches = rules.filter { activeCategoryIDs.contains($0.categoryID) && $0.matches(input) }
            let categories = Set(matches.map(\.categoryID))
            let evidence = matches.map { CategoryRuleMatch(ruleID: $0.id, version: $0.version) }
            if categories.count > 1 {
                return Decision(transactionID: input.transactionID, categoryID: nil, outcome: .conflict, matches: evidence, explanation: "Matching rules disagree: " + matches.map(\.name).joined(separator: ", "))
            }
            guard let categoryID = categories.first else {
                return Decision(transactionID: input.transactionID, categoryID: nil, outcome: .noMatch, matches: [], explanation: "No enabled rule matches these source fields.")
            }
            return Decision(transactionID: input.transactionID, categoryID: categoryID, outcome: .assigned, matches: evidence, explanation: matches.map { "\($0.name) · v\($0.version) · " + $0.predicates.map { "\($0.field.rawValue) \($0.match.rawValue) \($0.text)" }.joined(separator: "; ") }.joined(separator: " · "))
        })
    }
}

/// Frozen owner metadata for an explicit history review. A no-match result can
/// remove an automatic category, so its effect differs from an unchanged row.
nonisolated struct CategoryHistoricalPreview: Equatable, Sendable {
    let evaluation: CategoryEvaluation
    let assignments: [String: String]
    let intents: [String: CategoryIntent]

    var decisions: [CategoryEvaluation.Decision] { evaluation.decisions }
    var removalCount: Int { decisions.filter(removesCategory).count }
    var unchangedCount: Int { decisions.filter(isUnchanged).count }

    func removesCategory(_ decision: CategoryEvaluation.Decision) -> Bool {
        assignments[decision.transactionID] != nil && intents[decision.transactionID]?.kind == .automatic &&
            (decision.outcome == .noMatch || decision.outcome == .conflict)
    }

    func isUnchanged(_ decision: CategoryEvaluation.Decision) -> Bool {
        decision.outcome == .protected || (decision.outcome == .noMatch && !removesCategory(decision))
    }

    func matches(assignments: [String: String], intents: [String: CategoryIntent]) -> Bool {
        self.assignments == assignments && self.intents == intents
    }
}
