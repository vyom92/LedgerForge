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

/// An owner-reviewed use of part or all of one actual refund credit. Native
/// Money remains exact; source dates and transaction values are never moved.
nonisolated struct MovementRefundAllocation: Codable, Equatable, Sendable {
    let purchaseTransactionID: String
    let creditTransactionID: String
    let amount: Money
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
    /// Nil means the older payload has no reviewed allocation. It must not be
    /// interpreted as permission to deduct a credit in its receipt month.
    var refundAllocations: [MovementRefundAllocation]? = nil

    init(id: String, workspaceID: String, kind: MovementKind, decision: Decision,
         transactionIDs: [String], explanation: String, reviewedAtISO: String,
         consumptionTransactionIDs: [String] = [], refundAllocations: [MovementRefundAllocation]? = nil) {
        self.id = id; self.workspaceID = workspaceID; self.kind = kind; self.decision = decision
        self.transactionIDs = transactionIDs; self.explanation = explanation; self.reviewedAtISO = reviewedAtISO
        self.consumptionTransactionIDs = consumptionTransactionIDs; self.refundAllocations = refundAllocations
    }

    private enum CodingKeys: String, CodingKey {
        case id, workspaceID, kind, decision, transactionIDs, explanation, reviewedAtISO
        case consumptionTransactionIDs, refundAllocations
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        workspaceID = try values.decode(String.self, forKey: .workspaceID)
        kind = try values.decode(MovementKind.self, forKey: .kind)
        decision = try values.decode(Decision.self, forKey: .decision)
        transactionIDs = try values.decode([String].self, forKey: .transactionIDs)
        explanation = try values.decode(String.self, forKey: .explanation)
        reviewedAtISO = try values.decode(String.self, forKey: .reviewedAtISO)
        consumptionTransactionIDs = try values.decodeIfPresent([String].self, forKey: .consumptionTransactionIDs) ?? []
        refundAllocations = try values.decodeIfPresent([MovementRefundAllocation].self, forKey: .refundAllocations)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id); try values.encode(workspaceID, forKey: .workspaceID)
        try values.encode(kind, forKey: .kind); try values.encode(decision, forKey: .decision)
        try values.encode(transactionIDs, forKey: .transactionIDs)
        try values.encode(explanation, forKey: .explanation); try values.encode(reviewedAtISO, forKey: .reviewedAtISO)
        try values.encode(consumptionTransactionIDs, forKey: .consumptionTransactionIDs)
        try values.encodeIfPresent(refundAllocations, forKey: .refundAllocations)
    }
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



/// Shared repository validation uses the real persisted transaction/account
/// records. Presentation and text matching never create canonical ownership.
nonisolated enum MovementValidation {
    struct Fact: Sendable {
        let id: String, workspaceId: String, accountId: String, nativeCurrency: String, direction: String
        let amountMinor: Int64
        let amountDecimal: String?
        let isTrusted: Bool
        let financialDate: String?
        init(_ value: TransactionDTO) {
            id = value.id; workspaceId = value.workspaceId; accountId = value.accountId ?? ""
            nativeCurrency = value.nativeCurrency; direction = value.direction
            amountMinor = value.amountMinor; isTrusted = value.isTrusted
            amountDecimal = value.amountDecimal
            financialDate = String(value.postedDateISO.prefix(10))
        }
        init(id: String, workspaceID: String, accountID: String, currency: String, direction: String, amountMinor: Int64, trusted: Bool, financialDate: String? = nil, amountDecimal: String? = nil) {
            self.id = id; workspaceId = workspaceID; accountId = accountID; nativeCurrency = currency
            self.direction = direction; self.amountMinor = amountMinor; isTrusted = trusted
            self.financialDate = financialDate
            self.amountDecimal = amountDecimal
        }

        func money() throws -> Money {
            guard let amountDecimal else { throw FinancialIntelligenceError.invalidRecord }
            let value = try Money(canonicalDecimal: amountDecimal, currency: nativeCurrency)
            guard try value.minorUnits() == amountMinor else { throw FinancialIntelligenceError.invalidRecord }
            return value
        }
    }
    static func validate(_ event: MovementEvent, facts: [Fact], accounts: [AccountDTO]) throws {
        guard !event.id.isEmpty, !event.workspaceID.isEmpty, !event.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              ISO8601DateFormatter().date(from: event.reviewedAtISO) != nil,
              (1...96).contains(event.transactionIDs.count), Set(event.transactionIDs).count == event.transactionIDs.count,
              Set(event.consumptionTransactionIDs).count == event.consumptionTransactionIDs.count,
              Set(event.consumptionTransactionIDs).isSubset(of: Set(event.transactionIDs)),
              event.kind == .emiConversion || event.consumptionTransactionIDs.isEmpty,
              event.kind == .refund || event.refundAllocations == nil,
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
            if event.refundAllocations != nil {
                let legs = try facts.map { fact -> MovementRefundValidation.Leg in
                    guard let account = accountMap[fact.accountId], account.nativeCurrency == fact.nativeCurrency,
                          let domain = account.accountType else { throw FinancialIntelligenceError.invalidLegs }
                    return .init(transactionID: fact.id, accountID: fact.accountId, domain: domain,
                                 direction: fact.direction, money: try fact.money())
                }
                _ = try MovementRefundValidation.resolve(event, legs: legs)
                valid = true
            } else {
                // Preserve the historical payload. Reporting leaves its credit
                // unresolved until an owner records actual allocation amounts.
                let credits = bankIn + cardIn, debits = bankOut + cardOut
                valid = sameCurrency && credits.count == 1 && (facts.count == 1 ||
                    (facts.count == 2 && debits.count == 1 && credits[0].accountId == debits[0].accountId &&
                     abs(Decimal(credits[0].amountMinor)) <= abs(Decimal(debits[0].amountMinor))))
            }
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

/// One exact validator serves repository writes and the full-history report.
/// Its legs are adapters over real canonical facts, never inferred matches.
nonisolated enum MovementRefundValidation {
    struct Leg: Sendable {
        let transactionID: String
        let accountID: String
        let domain: String
        let direction: String
        let money: Money

        var isPurchase: Bool {
            (domain == "bank" && direction == "debit" && money.amount < 0) ||
            (domain == "credit_card" && direction == "card_increase_owed" && money.amount > 0)
        }
        var isCredit: Bool {
            (domain == "bank" && direction == "credit" && money.amount > 0) ||
            (domain == "credit_card" && direction == "card_decrease_owed" && money.amount < 0)
        }
        func magnitude() throws -> Money { try Money(amount: abs(money.amount), currency: money.currency) }
    }

    struct Result: Sendable {
        let purchaseTransactionID: String
        let gross: Money
        let allocated: Money
        let net: Money
        let allocatedByCredit: [String: Money]
        let residualByCredit: [String: Money]
    }

    static func resolve(_ event: MovementEvent, legs: [Leg]) throws -> Result {
        guard event.kind == .refund, let allocations = event.refundAllocations,
              !allocations.isEmpty, allocations.count < 96,
              Set(allocations.map(\.purchaseTransactionID)).count == 1,
              Set(allocations.map(\.creditTransactionID)).count == allocations.count,
              Set(legs.map(\.transactionID)).count == legs.count,
              Set(event.transactionIDs).count == event.transactionIDs.count,
              Set(legs.map(\.transactionID)) == Set(event.transactionIDs),
              let purchaseID = allocations.first?.purchaseTransactionID,
              !purchaseID.isEmpty, !allocations.contains(where: { $0.creditTransactionID.isEmpty || $0.creditTransactionID == purchaseID }),
              Set(event.transactionIDs) == Set([purchaseID] + allocations.map(\.creditTransactionID)) else {
            throw FinancialIntelligenceError.invalidLegs
        }
        let byID = Dictionary(uniqueKeysWithValues: legs.map { ($0.transactionID, $0) })
        guard let purchase = byID[purchaseID], purchase.isPurchase, !purchase.accountID.isEmpty else {
            throw FinancialIntelligenceError.invalidLegs
        }
        let gross = try purchase.magnitude()
        var allocated = try Money(amount: 0, currency: gross.currency)
        var allocatedByCredit: [String: Money] = [:], residualByCredit: [String: Money] = [:]
        for allocation in allocations {
            guard let credit = byID[allocation.creditTransactionID], credit.isCredit,
                  credit.accountID == purchase.accountID, credit.domain == purchase.domain,
                  credit.money.currency == gross.currency, allocation.amount.currency == gross.currency,
                  allocation.amount.amount > 0 else { throw FinancialIntelligenceError.invalidLegs }
            // Revalidate the native catalog scale at this trusted boundary.
            _ = try allocation.amount.minorUnits()
            let available = try credit.magnitude()
            guard try allocation.amount.compared(to: available) != .orderedDescending else {
                throw FinancialIntelligenceError.invalidLegs
            }
            allocated = try allocated + allocation.amount
            guard try allocated.compared(to: gross) != .orderedDescending else {
                throw FinancialIntelligenceError.invalidLegs
            }
            allocatedByCredit[credit.transactionID] = allocation.amount
            residualByCredit[credit.transactionID] = try available - allocation.amount
        }
        return .init(purchaseTransactionID: purchaseID, gross: gross, allocated: allocated,
                     net: try gross - allocated, allocatedByCredit: allocatedByCredit, residualByCredit: residualByCredit)
    }
}

/// Source exclusions are shared by materialised automatic intent and reports.
/// Editing a category cannot erase a source-established loan or EMI role.
nonisolated enum SpendingSourcePolicy {
    static func isLoanOrEMI(domain: String, narration: String, parserProfileIDs: Set<String>,
                           summaryMembership: CardTransactionSummaryMembership? = nil) -> Bool {
        if domain == "loan" { return true }
        let text = narration.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if domain == "credit_card", parserProfileIDs.contains(where: { $0.hasPrefix("axis.") }) {
            return ["EMI PRINCIPAL - ", "EMI INTEREST - ", "EMI PROCESSING FEE, REF# ",
                    "TRANSACTION CONVERSION INTO EMI "].contains(where: text.hasPrefix)
        }
        if domain == "credit_card", parserProfileIDs.contains(where: { $0.hasPrefix("cbq.") }) {
            return summaryMembership == .cbqV2BilledInstallment ||
                text.hasPrefix("STANDING ORDER FOR INSTALMENT # ") || text == "CREDIT FOR TRANSACTION INSTALMENT"
        }
        if domain == "bank", parserProfileIDs.contains(where: { $0.hasPrefix("cbq.") }) {
            return ["LOAN REPAYMENT - PRINC ", "LOAN REPAYMENT - INTER ", "NEW LOAN "].contains(where: text.hasPrefix) ||
                (text.hasPrefix("INSURANCE - PERSONAL L ") && text.hasSuffix("PERSONAL LOAN INSURANCE"))
        }
        return false
    }

    static func isCashAdvanceFee(domain: String, direction: String, narration: String,
                                 parserProfileIDs: Set<String>) -> Bool {
        domain == "credit_card" && direction == "card_increase_owed" &&
            parserProfileIDs.contains("cbq.credit-card.pdf") &&
            narration.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "CASH ADVANCE FEE"
    }
}
