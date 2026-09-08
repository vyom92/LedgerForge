import Foundation

enum CardInstrumentLifecycleState: String, CaseIterable, Equatable, Sendable, Codable {
    case unknown
    case active
    case retired
    case replaced
}

enum CardInstrumentRelationshipKind: String, CaseIterable, Equatable, Sendable, Codable {
    case additionalConcurrent = "additional_concurrent"
    case replacement
    case renewal
    case upgrade
    case unspecified
}

struct CardInstrument: Identifiable, Equatable, Sendable {
    let id: String
    let workspaceID: String
    let liabilityAccountID: String
    let lifecycleState: CardInstrumentLifecycleState
    let createdAtISO: String
    let sourceObservations: [CardSourceIdentityObservation]
}

struct CardInstrumentRelationship: Identifiable, Equatable, Sendable {
    let id: String
    let liabilityAccountID: String
    let predecessorInstrumentID: String
    let successorInstrumentID: String
    let kind: CardInstrumentRelationshipKind
    let authority: String
    let effectiveDate: StatementDate?
    let createdAtISO: String
}

struct CardStatement: Identifiable, Equatable, Sendable {
    let id: String
    let liabilityAccountID: String
    let instrumentIDs: [String]
    let sourceDocumentID: String
    let importSessionID: String
    let parserProfileID: String
    let parserProfileVersion: String
    let statementDate: StatementDate?
    let period: DeclaredStatementPeriod?
    let selectedStatementMonth: SelectedStatementMonth?
    let semanticGroupID: String?
    let currency: CurrencyCode
    let sourceRowCount: Int
    let reconciliationRuleCode: String
    let summaryComponents: [CardStatementSummaryComponent]
    let sections: [CardStatementSection]

    var newBalance: Money? {
        summaryComponents.first { $0.persistenceCode == "new_balance" }?.money
            ?? summaryComponents.first { $0.persistenceCode == "axis_total_payment_due" }?.money
    }
    var minimumAmountDue: Money? {
        summaryComponents.first { $0.persistenceCode == "minimum_amount_due" }?.money
    }
    var dueDate: StatementDate? { summaryComponents.first { $0.persistenceCode == "due_date" }?.date }
}

struct CardStatementSection: Identifiable, Equatable, Sendable {
    let id: String
    let documentScopedSectionID: String
    let sourceOrdinal: Int
    let instrumentID: String
    let holderLabel: String?
    let signedTotal: Money
    let reconciliationRuleCode: String
    let sourceObservations: [CardSourceIdentityObservation]
}

struct DurableCardTransactionEvidence: Equatable, Sendable {
    let statementID: String
    let transactionID: String
    let financialScope: CardTransactionScope
    let documentScopedSectionID: String?
    let instrumentID: String?
    let liabilityEffect: CardLiabilityEffect
    let sourceTransactionDate: StatementDate
    let originalMerchantMoney: Money?
    let summaryMembership: CardTransactionSummaryMembership?
}

struct CardStoreSnapshot: Equatable, Sendable {
    let instruments: [CardInstrument]
    /// Liability-account identity observations are retained alongside the
    /// runtime card projection so provider and hydrated digests can verify
    /// membership authority survives close/reopen.
    let sourceObservations: [CardSourceIdentityObservation]
    let relationships: [CardInstrumentRelationship]
    let statements: [CardStatement]
    let transactionEvidence: [DurableCardTransactionEvidence]

    init(
        instruments: [CardInstrument],
        sourceObservations: [CardSourceIdentityObservation] = [],
        relationships: [CardInstrumentRelationship],
        statements: [CardStatement],
        transactionEvidence: [DurableCardTransactionEvidence]
    ) {
        self.instruments = instruments
        self.sourceObservations = sourceObservations
        self.relationships = relationships
        self.statements = statements
        self.transactionEvidence = transactionEvidence
    }

    static let empty = CardStoreSnapshot(instruments: [], sourceObservations: [], relationships: [], statements: [], transactionEvidence: [])
}
