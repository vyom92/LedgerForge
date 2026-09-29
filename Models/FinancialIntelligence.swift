import Foundation

nonisolated public enum MovementKind: String, Codable, CaseIterable, Sendable {
    case ownTransfer, cardPayment, refund, reversal, borrowing, expense, income, emiConversion
    // Legacy cases stay decodable for existing backups, but are no longer
    // available as analysis or planning workflows.
    public var isInScope: Bool { self != .borrowing && self != .emiConversion }
    public var title: String {
        switch self {
        case .ownTransfer: "Own transfer"
        case .cardPayment: "Card payment"
        case .refund: "Refund"
        case .reversal: "Reversal"
        case .borrowing: "Borrowed cash"
        case .expense: "Spending"
        case .income: "Income"
        case .emiConversion: "EMI conversion"
        }
    }
}

/// Owner interpretation over immutable canonical legs. Rejected suggestions
/// retain their identities but never reserve a leg or affect a report.
nonisolated public struct MovementEvent: Codable, Equatable, Sendable, Identifiable {
    public enum Decision: String, Codable, Sendable { case confirmed, rejected }
    public var id: String
    public var workspaceID: String
    public var kind: MovementKind
    public var decision: Decision
    public var transactionIDs: [String]
    public var explanation: String
    public var reviewedAtISO: String
    /// Retained legacy EMI interpretation for lossless backup compatibility.
    /// Current reports count the original purchase, not these financing legs.
    public var consumptionTransactionIDs: [String] = []
}

nonisolated public struct FinancialIntelligenceSnapshot: Equatable, Sendable {
    public let workspaceID: String
    public var movements: [MovementEvent] = []
    public var recurring: [RecurringDefinition] = []
    public var occurrences: [RecurringOccurrence] = []
    public var reserves: [ReserveDesignation] = []
    public var plans: [PlanAssistance] = []
    public var salaries: [SalaryAssistance] = []
    public var preferences: IntelligencePreferences?
    public var confirmedByTransaction: [String: MovementEvent] {
        var result: [String: MovementEvent] = [:]
        for event in movements where event.decision == .confirmed {
            for id in event.transactionIDs { result[id] = event }
        }
        return result
    }
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

/// Shared repository validation uses the real persisted transaction/account
/// records. Presentation and text matching never create canonical ownership.
nonisolated enum MovementValidation {
    struct Fact: Sendable {
        let id: String, workspaceId: String, accountId: String, nativeCurrency: String, direction: String
        let amountMinor: Int64
        let isTrusted: Bool
        let financialDate: String?
        init(_ value: TransactionDTO) {
            id = value.id; workspaceId = value.workspaceId; accountId = value.accountId ?? ""
            nativeCurrency = value.nativeCurrency; direction = value.direction
            amountMinor = value.amountMinor; isTrusted = value.isTrusted
            financialDate = String(value.postedDateISO.prefix(10))
        }
        init(id: String, workspaceID: String, accountID: String, currency: String, direction: String, amountMinor: Int64, trusted: Bool, financialDate: String? = nil) {
            self.id = id; workspaceId = workspaceID; accountId = accountID; nativeCurrency = currency
            self.direction = direction; self.amountMinor = amountMinor; isTrusted = trusted
            self.financialDate = financialDate
        }
    }
    static func validate(_ event: MovementEvent, facts: [Fact], accounts: [AccountDTO]) throws {
        guard !event.id.isEmpty, !event.workspaceID.isEmpty, !event.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              ISO8601DateFormatter().date(from: event.reviewedAtISO) != nil,
              (1...96).contains(event.transactionIDs.count), Set(event.transactionIDs).count == event.transactionIDs.count,
              Set(event.consumptionTransactionIDs).count == event.consumptionTransactionIDs.count,
              Set(event.consumptionTransactionIDs).isSubset(of: Set(event.transactionIDs)),
              event.kind == .emiConversion || event.consumptionTransactionIDs.isEmpty,
              facts.count == event.transactionIDs.count, Set(facts.map(\.id)) == Set(event.transactionIDs),
              facts.allSatisfy({ $0.workspaceId == event.workspaceID && $0.isTrusted }) else {
            throw FinancialIntelligenceError.invalidRecord
        }
        let accountMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        guard facts.allSatisfy({ accountMap[$0.accountId]?.workspaceId == event.workspaceID }) else {
            throw FinancialIntelligenceError.invalidRecord
        }
        guard event.decision == .confirmed else { return }
        let bankOut = facts.filter { accountMap[$0.accountId]?.accountType == "bank" && $0.direction == "debit" && $0.amountMinor < 0 }
        let bankIn = facts.filter { accountMap[$0.accountId]?.accountType == "bank" && $0.direction == "credit" && $0.amountMinor > 0 }
        let cardOut = facts.filter { accountMap[$0.accountId]?.accountType == "credit_card" && $0.direction == "card_increase_owed" && $0.amountMinor > 0 }
        let cardIn = facts.filter { accountMap[$0.accountId]?.accountType == "credit_card" && $0.direction == "card_decrease_owed" && $0.amountMinor < 0 }
        let sameCurrency = Set(facts.map(\.nativeCurrency)).count == 1
        func oppositeAmounts() -> Bool {
            facts.count == 2 && Decimal(facts[0].amountMinor) + Decimal(facts[1].amountMinor) == 0
        }
        let valid: Bool
        switch event.kind {
        case .ownTransfer:
            valid = facts.count == 2 && bankOut.count == 1 && bankIn.count == 1 &&
                bankOut[0].accountId != bankIn[0].accountId && (!sameCurrency || oppositeAmounts())
        case .cardPayment:
            valid = facts.count == 2 && bankOut.count == 1 && cardIn.count == 1 &&
                sameCurrency && bankOut[0].amountMinor == cardIn[0].amountMinor
        case .refund:
            let credits = bankIn + cardIn, debits = bankOut + cardOut
            valid = sameCurrency && credits.count == 1 && (facts.count == 1 ||
                (facts.count == 2 && debits.count == 1 && credits[0].accountId == debits[0].accountId &&
                 abs(Decimal(credits[0].amountMinor)) <= abs(Decimal(debits[0].amountMinor))))
        case .reversal:
            valid = sameCurrency && Set(facts.map(\.accountId)).count == 1 && oppositeAmounts()
        case .borrowing:
            valid = (facts.count == 1 && bankIn.count == 1) ||
                (facts.count == 2 && bankIn.count == 1 && cardOut.count == 1 && sameCurrency && bankIn[0].amountMinor == cardOut[0].amountMinor)
        case .expense: valid = facts.count == 1 && bankOut.count + cardOut.count == 1
        case .income: valid = facts.count == 1 && bankIn.count == 1
        case .emiConversion:
            let consuming = Set(event.consumptionTransactionIDs)
            let converted = facts.filter { !consuming.contains($0.id) }
            let instalments = facts.filter { consuming.contains($0.id) }
            valid = sameCurrency && Set(facts.map(\.accountId)).count == 1 &&
                cardOut.count + cardIn.count == facts.count && converted.count == 2 &&
                converted[0].amountMinor != 0 && Decimal(converted[0].amountMinor) + Decimal(converted[1].amountMinor) == 0 &&
                instalments.allSatisfy { $0.direction == "card_increase_owed" && $0.amountMinor > 0 }
        }
        guard valid else { throw FinancialIntelligenceError.invalidLegs }
    }
}
