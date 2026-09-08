// Database/DTOs.swift
// Strongly typed DTOs for repository APIs

import Foundation

enum CardTransactionSummaryMembership: String, CaseIterable, Equatable, Sendable, Codable {
    case cbqV1AmountBilled = "cbq_v1_amount_billed"
    case cbqV1PaymentReceived = "cbq_v1_payment_received"
    case cbqV2TotalPayment = "cbq_v2_total_payment"
    case cbqV2CreditReversal = "cbq_v2_credit_reversal"
    case cbqV2Purchases = "cbq_v2_purchases"
    case cbqV2BilledInstallment = "cbq_v2_billed_installment"
    case cbqV2FeesCharges = "cbq_v2_fees_charges"
}

/// Persistence-safe exact contract descriptor shared by the main app and the
/// subprocess probe. It deliberately uses durable codes instead of depending
/// on parser or UI model types.
enum CardStatementProfileContract: Equatable, Sendable {
    case amex
    case cbqV1
    case cbqV2
    case axis

    init?(reconciliationRuleIdentifier rule: String) {
        switch rule {
        case "amex.qar.previous-minus-credits-plus-debits.v1": self = .amex
        case "cbq.qar.v1.previous-plus-billed-minus-payment.v1",
             "cbq.qar.v1.previous-plus-billed-minus-payment.v2": self = .cbqV1
        case "cbq.qar.v2.previous-minus-payment-minus-credit-plus-components.v1",
             "cbq.qar.v2.previous-minus-payment-minus-credit-plus-components.v2": self = .cbqV2
        case "axis.inr.previous-plus-row-ledger-equals-total-due.v1",
             "axis.inr.app.previous-plus-row-ledger-equals-total-due.v1": self = .axis
        default: return nil
        }
    }

    var institutionCode: String {
        switch self {
        case .amex: return "American Express"
        case .cbqV1, .cbqV2: return "Commercial Bank of Qatar"
        case .axis: return "Axis Bank"
        }
    }
    var profileID: String {
        switch self {
        case .amex: return "amex.credit-card.pdf"
        case .cbqV1, .cbqV2: return "cbq.credit-card.pdf"
        case .axis: return "axis.credit-card.pdf"
        }
    }
    func accepts(profileID: String) -> Bool {
        self == .axis
            ? ["axis.credit-card.pdf", "axis.credit-card.xlsx"].contains(profileID)
            : profileID == self.profileID
    }
    var profileVersion: String { "1" }
    var statementFamilyCode: String {
        switch self {
        case .axis: return "axis.credit-card@1"
        default: return "\(profileID)@\(profileVersion)"
        }
    }
    var supportsSemanticSourceGrouping: Bool { self == .amex || self == .axis }
    var requiresCBQSummaryMembership: Bool { self == .cbqV1 || self == .cbqV2 }
    var requiresPhysicalSections: Bool { self != .axis }
    var accountObservationKindCode: String? {
        switch self {
        case .amex: return "amex_membership_number"
        case .cbqV1, .cbqV2: return "cbq_card_account_reference"
        case .axis: return nil
        }
    }
    var instrumentObservationKindCode: String? {
        switch self {
        case .amex: return "amex_card_account_number"
        case .cbqV1, .cbqV2: return "cbq_masked_card_number"
        case .axis: return nil
        }
    }
    var sectionRule: String? {
        switch self {
        case .amex: return "amex.section.signed-increases-minus-decreases.v1"
        case .cbqV1, .cbqV2: return "cbq.section.signed-source-membership.v1"
        case .axis: return nil
        }
    }
    var requiredSummaryCodes: Set<String> {
        switch self {
        case .amex:
            return ["previous_balance", "new_credits", "new_debits", "new_balance", "due_date", "instrument_net_total"]
        case .cbqV1:
            return ["previous_balance", "amount_billed", "payment_received", "new_balance", "minimum_amount_due", "due_date", "source_section_net_total"]
        case .cbqV2:
            return ["previous_balance", "total_payment", "credit_reversal", "purchases", "billed_installment", "fees_charges", "new_balance", "minimum_amount_due", "due_date", "source_section_net_total"]
        case .axis:
            return []
        }
    }
    var allowedSummaryCodes: Set<String> {
        switch self {
        case .axis:
            return ["previous_balance", "axis_total_payment_due", "due_date"]
        default:
            return requiredSummaryCodes
        }
    }
    func requiredSummaryCodes(sourceFormatCode: String) -> Set<String> {
        requiredSummaryCodes
    }
    func usesAxisAppReconciliationRule(_ rule: String) -> Bool {
        self == .axis && rule == "axis.inr.app.previous-plus-row-ledger-equals-total-due.v1"
    }
    func requiredSummaryCodes(reconciliationRuleIdentifier rule: String, sourceFormatCode: String) -> Set<String> {
        return requiredSummaryCodes(sourceFormatCode: sourceFormatCode)
    }

    /// V16 could not persist minimum_amount_due. Its exact historical rule
    /// remains readable, but may never authorize a new import under V17.
    private func isHistoricalCBQReconciliationRule(_ rule: String) -> Bool {
        switch (self, rule) {
        case (.cbqV1, "cbq.qar.v1.previous-plus-billed-minus-payment.v1"),
             (.cbqV2, "cbq.qar.v2.previous-minus-payment-minus-credit-plus-components.v1"):
            return true
        default:
            return false
        }
    }

    func acceptsCurrentReconciliationRule(_ rule: String) -> Bool {
        Self(reconciliationRuleIdentifier: rule) == self &&
            !isHistoricalCBQReconciliationRule(rule)
    }

    /// Read compatibility only. New writes use the strict current coverage
    /// above; migration neither invents nor backfills a missing source value.
    func hydrationRequiredSummaryCodes(
        reconciliationRuleIdentifier rule: String,
        sourceFormatCode: String
    ) -> Set<String> {
        let codes = requiredSummaryCodes(
            reconciliationRuleIdentifier: rule,
            sourceFormatCode: sourceFormatCode
        )
        return isHistoricalCBQReconciliationRule(rule)
            ? codes.subtracting(["minimum_amount_due"])
            : codes
    }

    var accountLevelMemberships: Set<CardTransactionSummaryMembership> {
        switch self {
        case .amex: return []
        case .cbqV1: return [.cbqV1PaymentReceived]
        case .cbqV2: return [.cbqV2TotalPayment]
        case .axis: return []
        }
    }
    var instrumentMemberships: Set<CardTransactionSummaryMembership> {
        switch self {
        case .amex: return []
        case .cbqV1: return [.cbqV1AmountBilled]
        case .cbqV2: return [.cbqV2CreditReversal, .cbqV2Purchases, .cbqV2BilledInstallment, .cbqV2FeesCharges]
        case .axis: return []
        }
    }
}

nonisolated enum ImportAttemptOutcome: String, CaseIterable { case successfulImport = "successful_import", equivalentSourceRecorded = "equivalent_source_recorded", cbqSourceOverlapCommitted = "cbq_source_overlap_committed", statementEquivalenceConflict = "statement_equivalence_conflict", statementEquivalenceEvidenceUnavailable = "statement_equivalence_evidence_unavailable", equivalentFormatAlreadyRecorded = "equivalent_format_already_recorded", partialImportCommitted = "partial_import_committed", reviewedPartialPlanStale = "reviewed_partial_plan_stale", partialImportUnsupportedEvidence = "partial_import_unsupported_evidence", validationFailure = "validation_failure", persistenceFailure = "persistence_failure", exactStatementDuplicate = "exact_statement_duplicate", existingEligibleAxisUPIEvent = "existing_eligible_axis_upi_event", repeatedEligibleIncomingEvidence = "repeated_eligible_incoming_evidence", transactionEventOwnershipConflict = "transaction_event_ownership_conflict", repositoryIntegrityConflict = "repository_integrity_conflict", accountChoiceRequired = "account_choice_required", identifierOwnershipConflict = "identifier_ownership_conflict", identityAmbiguity = "identity_ambiguity", identityConflict = "identity_conflict", staleAccountChoice = "stale_account_choice", staleProviderGeneration = "stale_provider_generation", sqliteContention = "sqlite_contention", sourceSnapshotAcquisitionFailed = "source_snapshot_acquisition_failed", sourceSnapshotIntegrityFailed = "source_snapshot_integrity_failed" }
nonisolated enum ImportAttemptCoverage: String, CaseIterable { case evaluatedSupportedOnly = "evaluated_supported_only", allRowsSupportedAxisUPIReviewed = "all_rows_supported_axis_upi_reviewed", unsupportedOrUnevaluated = "unsupported_or_unevaluated" }
nonisolated enum ImportAttemptAccountDecision: String, CaseIterable { case matchedExisting = "matched_existing", userSelectedExisting = "user_selected_existing", createdNew = "created_new", resolvedOrCreated = "resolved_or_created", selectedExisting = "selected_existing", noFinancialMutation = "no_financial_mutation", sideEffectsMayExist = "side_effects_may_exist" }
nonisolated enum ImportAttemptGuidance: String, CaseIterable { case importCompleted = "import_completed", equivalentSourceRecorded = "equivalent_source_recorded", partialImportCompleted = "partial_import_completed", reviewPriorImport = "review_prior_import", supportedEventBlocked = "supported_event_blocked", correctValidationAndRetry = "correct_validation_and_retry", persistenceUnavailable = "persistence_unavailable", integrityReviewRequired = "integrity_review_required", prepareAgain = "prepare_again", retryConfirmation = "retry_confirmation" }
nonisolated enum ImportAttemptPersistence: String { case committed, rejectedRecorded = "rejected_recorded", rejectedNotRecorded = "rejected_not_recorded", auditWriteUnavailable = "audit_write_unavailable" }

public struct WorkspaceDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let name: String
    public let createdAtISO: String
    public let updatedAtISO: String?

    public init(id: String = UUID().uuidString,
                name: String,
                createdAtISO: String,
                updatedAtISO: String? = nil) {
        self.id = id
        self.name = name
        self.createdAtISO = createdAtISO
        self.updatedAtISO = updatedAtISO
    }
}

public struct CategoryDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let name: String
    public let normalizedName: String
    public let isArchived: Bool
    public let createdAtISO: String
    public let updatedAtISO: String?

    public init(
        id: String = UUID().uuidString,
        workspaceId: String,
        name: String,
        normalizedName: String,
        isArchived: Bool = false,
        createdAtISO: String,
        updatedAtISO: String? = nil
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.name = name
        self.normalizedName = normalizedName
        self.isArchived = isArchived
        self.createdAtISO = createdAtISO
        self.updatedAtISO = updatedAtISO
    }
}

public struct TransactionCategoryAssignmentDTO: nonisolated Equatable, Sendable {
    public let workspaceId: String
    public let transactionId: String
    public let categoryId: String

    public init(workspaceId: String, transactionId: String, categoryId: String) {
        self.workspaceId = workspaceId
        self.transactionId = transactionId
        self.categoryId = categoryId
    }
}

public struct TransactionRawRowDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let normalizedRowId: String
    public let contributionType: String?
    public let sourceOrdinal: Int?
    public let normalizedRecordDigest: String?
    public let normalizedDocumentId: String?
    public let parserProfileId: String?
    public let parserProfileVersion: String?

    public init(id: String = UUID().uuidString, normalizedRowId: String, contributionType: String? = nil, sourceOrdinal: Int? = nil, normalizedRecordDigest: String? = nil, normalizedDocumentId: String? = nil, parserProfileId: String? = nil, parserProfileVersion: String? = nil) {
        self.id = id
        self.normalizedRowId = normalizedRowId
        self.contributionType = contributionType
        self.sourceOrdinal = sourceOrdinal
        self.normalizedRecordDigest = normalizedRecordDigest
        self.normalizedDocumentId = normalizedDocumentId
        self.parserProfileId = parserProfileId
        self.parserProfileVersion = parserProfileVersion
    }
}

public struct NormalizedDocumentDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let importSessionId: String
    public let documentId: String
    public let profileId: String
    public let profileVersion: String
    public init(id: String, importSessionId: String, documentId: String, profileId: String, profileVersion: String) {
        self.id = id; self.importSessionId = importSessionId; self.documentId = documentId; self.profileId = profileId; self.profileVersion = profileVersion
    }
}

public struct NormalizedRowDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let normalizedDocumentId: String
    public let sourceOrdinal: Int
    public let digest: String
    public init(id: String, normalizedDocumentId: String, sourceOrdinal: Int, digest: String) {
        self.id = id; self.normalizedDocumentId = normalizedDocumentId; self.sourceOrdinal = sourceOrdinal; self.digest = digest
    }
}

public struct TransactionDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let accountId: String?
    public let importSessionId: String?
    public let documentId: String?
    public let originalRowId: String?
    public let postedDateISO: String
    public let financialDateRole: String
    public let statementTimezoneEvidence: String
    public let valueDateISO: String?
    public let description: String?
    public let payee: String?
    public let reference: String?
    public let nativeCurrency: String
    public let amountMinor: Int64
    public let amountDecimal: String
    public let direction: String
    public let runningBalanceMinor: Int64?
    public let isReconciled: Bool
    public let isTrusted: Bool
    public let trustedAtISO: String?
    public let createdAtISO: String
    public let updatedAtISO: String?
    public let rawRows: [TransactionRawRowDTO]

    public init(id: String = UUID().uuidString,
                workspaceId: String,
                accountId: String? = nil,
                importSessionId: String? = nil,
                documentId: String? = nil,
                originalRowId: String? = nil,
                postedDateISO: String,
                financialDateRole: String = "transaction_date",
                statementTimezoneEvidence: String = "unknown",
                valueDateISO: String? = nil,
                description: String? = nil,
                payee: String? = nil,
                reference: String? = nil,
                nativeCurrency: String,
                amountMinor: Int64,
                amountDecimal: String,
                direction: String,
                runningBalanceMinor: Int64? = nil,
                isReconciled: Bool = false,
                isTrusted: Bool = false,
                trustedAtISO: String? = nil,
                createdAtISO: String,
                updatedAtISO: String? = nil,
                rawRows: [TransactionRawRowDTO] = []) {
        self.id = id
        self.workspaceId = workspaceId
        self.accountId = accountId
        self.importSessionId = importSessionId
        self.documentId = documentId
        self.originalRowId = originalRowId
        self.postedDateISO = postedDateISO
        self.financialDateRole = financialDateRole
        self.statementTimezoneEvidence = statementTimezoneEvidence
        self.valueDateISO = valueDateISO
        self.description = description
        self.payee = payee
        self.reference = reference
        self.nativeCurrency = nativeCurrency
        self.amountMinor = amountMinor
        self.amountDecimal = amountDecimal
        self.direction = direction
        self.runningBalanceMinor = runningBalanceMinor
        self.isReconciled = isReconciled
        self.isTrusted = isTrusted
        self.trustedAtISO = trustedAtISO
        self.createdAtISO = createdAtISO
        self.updatedAtISO = updatedAtISO
        self.rawRows = rawRows
    }
}

public struct AccountDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let name: String
    public let institutionId: String?
    public let accountType: String?
    public let nativeCurrency: String
    public let description: String?
    public let createdAtISO: String

    public init(id: String = UUID().uuidString,
                workspaceId: String,
                name: String,
                institutionId: String? = nil,
                accountType: String? = nil,
                nativeCurrency: String,
                description: String? = nil,
                createdAtISO: String) {
        self.id = id
        self.workspaceId = workspaceId
        self.name = name
        self.institutionId = institutionId
        self.accountType = accountType
        self.nativeCurrency = nativeCurrency
        self.description = description
        self.createdAtISO = createdAtISO
    }
}

public struct AccountIdentifierDTO: nonisolated Equatable {
    public let id: String
    public let accountId: String
    public let workspaceId: String
    public let scheme: String
    public let identifier: String
    public let strength: String
    public let verificationState: String
    public let provenance: String
    public let createdAtISO: String

    public init(id: String = UUID().uuidString,
                accountId: String,
                workspaceId: String,
                scheme: String,
                identifier: String,
                strength: String,
                verificationState: String,
                provenance: String,
                createdAtISO: String) {
        self.id = id
        self.accountId = accountId
        self.workspaceId = workspaceId
        self.scheme = scheme
        self.identifier = identifier
        self.strength = strength
        self.verificationState = verificationState
        self.provenance = provenance
        self.createdAtISO = createdAtISO
    }
}

public struct CardInstrumentDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let liabilityAccountId: String
    public let lifecycleStateCode: String
    public let createdAtISO: String

    public init(id: String, workspaceId: String, liabilityAccountId: String, lifecycleStateCode: String, createdAtISO: String) {
        self.id = id
        self.workspaceId = workspaceId
        self.liabilityAccountId = liabilityAccountId
        self.lifecycleStateCode = lifecycleStateCode
        self.createdAtISO = createdAtISO
    }
}

public struct CardInstrumentIdentifierDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let instrumentId: String
    public let workspaceId: String
    public let scheme: String
    public let identifier: String
    public let parserProvenanceCode: String
    public let createdAtISO: String
}

public struct CardSourceIdentityObservationDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let documentId: String
    public let importSessionId: String
    public let normalizedDocumentId: String
    public let parserProfileId: String
    public let parserProfileVersion: String
    public let subjectKind: String
    public let subjectId: String
    public let observationKind: String
    public let sourceValue: String
    public let associationAuthority: String
    public let createdAtISO: String
}

public struct CardInstrumentRelationshipDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let liabilityAccountId: String
    public let predecessorInstrumentId: String
    public let successorInstrumentId: String
    public let relationshipKind: String
    public let authority: String
    public let effectiveDateISO: String?
    public let createdAtISO: String
}

public struct CardStatementDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let liabilityAccountId: String
    public let documentId: String
    public let importSessionId: String
    public let normalizedDocumentId: String
    public let parserProfileId: String
    public let parserProfileVersion: String
    public let statementDateISO: String?
    public let statementStartDateISO: String?
    public let statementEndDateISO: String?
    public let selectedStatementMonthISO: String?
    public let statementCurrency: String
    public let sourceRowCount: Int
    public let reconciliationRuleCode: String
    public let createdAtISO: String
}

public struct CardStatementSummaryComponentDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let cardStatementId: String
    public let componentCode: String
    public let moneyCurrency: String?
    public let moneyMinor: Int64?
    public let moneyDecimal: String?
    public let dateISO: String?
}

public struct CardTransactionEvidenceDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let cardStatementId: String
    public let transactionId: String
    public let rowScopeCode: String
    public let instrumentId: String?
    public let liabilityEffectCode: String
    public let sourceTransactionDateISO: String
    public let documentScopedSectionId: String?
    public let originalCurrency: String?
    public let originalAmountMinor: Int64?
    public let originalAmountDecimal: String?
    public let summaryMembershipCode: String?
}

public struct CardStatementSectionDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let cardStatementId: String
    public let documentScopedSectionId: String
    public let sourceOrdinal: Int
    public let instrumentId: String
    public let holderLabel: String?
    public let signedTotalCurrency: String
    public let signedTotalMinor: Int64
    public let signedTotalDecimal: String
    public let reconciliationRuleCode: String
}

public struct CardStatementSectionObservationDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let cardStatementSectionId: String
    public let workspaceId: String
    public let documentId: String
    public let importSessionId: String
    public let normalizedDocumentId: String
    public let parserProfileId: String
    public let parserProfileVersion: String
    public let observationKind: String
    public let sourceValue: String
    public let associationAuthority: String
    public let createdAtISO: String
}

public struct CardStatementSemanticProjectionSectionDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let projectionId: String
    public let sourceOrdinal: Int
    public let documentScopedSectionId: String
    public let signedTotalCurrency: String
    public let signedTotalMinor: Int64
    public let signedTotalDecimal: String
    public let reconciliationRuleCode: String
}

public struct CardStatementSemanticProjectionEventDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let projectionId: String
    public let canonicalTransactionId: String?
    public let normalizedRowId: String
    public let sourceOrdinal: Int
    public let financialDateISO: String
    public let financialDateRoleCode: String
    public let sourceTransactionDateISO: String?
    public let liabilityEffectCode: String
    public let postedCurrency: String
    public let postedAmountMinor: Int64
    public let postedAmountDecimal: String
    public let originalCurrency: String?
    public let originalAmountMinor: Int64?
    public let originalAmountDecimal: String?
    public let sourceReference: String?
    public let rowScopeCode: String
    public let documentScopedSectionId: String?
    public let documentSectionOrdinal: Int?
}

public struct CardStatementSemanticProjectionRecordDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let liabilityAccountId: String
    public let cardStatementId: String
    public let documentId: String
    public let importSessionId: String
    public let algorithm: String
    public let digest: String
    public let institutionCode: String
    public let statementFamilyCode: String
    public let parserProfileId: String
    public let parserProfileVersion: String
    public let statementDateISO: String?
    public let statementStartDateISO: String?
    public let statementEndDateISO: String?
    public let selectedStatementMonthISO: String?
    public let cycleMonthISO: String?
    public let nativeCurrency: String
    public let eventCount: Int
    public let sectionCount: Int
    public let reconciliationRuleCode: String
    public let createdAtISO: String
    public let sections: [CardStatementSemanticProjectionSectionDTO]
    public let events: [CardStatementSemanticProjectionEventDTO]
}

public struct CardStatementSemanticGroupDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let liabilityAccountId: String
    public let institutionCode: String
    public let statementFamilyCode: String
    public let statementStartDateISO: String?
    public let statementEndDateISO: String?
    public let cycleMonthISO: String?
    public let nativeCurrency: String
    public let projectionAlgorithm: String
    public let projectionDigest: String
    public let authoritativeProjectionId: String
    public let createdAtISO: String
}

public struct CardStatementSemanticMemberDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let groupId: String
    public let projectionId: String
    public let role: StatementEquivalenceMemberRole
    public let createdAtISO: String
}

public struct CardRepositorySnapshotDTO: nonisolated Equatable, Sendable {
    public let instruments: [CardInstrumentDTO]
    public let instrumentIdentifiers: [CardInstrumentIdentifierDTO]
    public let sourceObservations: [CardSourceIdentityObservationDTO]
    public let relationships: [CardInstrumentRelationshipDTO]
    public let statements: [CardStatementDTO]
    public let summaryComponents: [CardStatementSummaryComponentDTO]
    public let transactionEvidence: [CardTransactionEvidenceDTO]
    public let sections: [CardStatementSectionDTO]
    public let sectionObservations: [CardStatementSectionObservationDTO]
    public let semanticProjections: [CardStatementSemanticProjectionRecordDTO]
    public let semanticGroups: [CardStatementSemanticGroupDTO]
    public let semanticMembers: [CardStatementSemanticMemberDTO]

    public static let empty = CardRepositorySnapshotDTO(
        instruments: [], instrumentIdentifiers: [], sourceObservations: [], relationships: [],
        statements: [], summaryComponents: [], transactionEvidence: [], sections: [],
        sectionObservations: [], semanticProjections: [], semanticGroups: [], semanticMembers: []
    )

    public init(
        instruments: [CardInstrumentDTO],
        instrumentIdentifiers: [CardInstrumentIdentifierDTO],
        sourceObservations: [CardSourceIdentityObservationDTO],
        relationships: [CardInstrumentRelationshipDTO],
        statements: [CardStatementDTO],
        summaryComponents: [CardStatementSummaryComponentDTO],
        transactionEvidence: [CardTransactionEvidenceDTO],
        sections: [CardStatementSectionDTO] = [],
        sectionObservations: [CardStatementSectionObservationDTO] = [],
        semanticProjections: [CardStatementSemanticProjectionRecordDTO] = [],
        semanticGroups: [CardStatementSemanticGroupDTO] = [],
        semanticMembers: [CardStatementSemanticMemberDTO] = []
    ) {
        self.instruments = instruments
        self.instrumentIdentifiers = instrumentIdentifiers
        self.sourceObservations = sourceObservations
        self.relationships = relationships
        self.statements = statements
        self.summaryComponents = summaryComponents
        self.transactionEvidence = transactionEvidence
        self.sections = sections
        self.sectionObservations = sectionObservations
        self.semanticProjections = semanticProjections
        self.semanticGroups = semanticGroups
        self.semanticMembers = semanticMembers
    }
}

public struct ImportSessionDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let userVisibleName: String?
    public let startedAtISO: String
    public let validationStatus: String
    public let readerVersion: String?
    public let parserVersion: String?
    public let layoutVersion: String?

    public init(id: String = UUID().uuidString,
                workspaceId: String,
                userVisibleName: String? = nil,
                startedAtISO: String,
                validationStatus: String = "pending",
                readerVersion: String? = nil,
                parserVersion: String? = nil,
                layoutVersion: String? = nil) {
        self.id = id
        self.workspaceId = workspaceId
        self.userVisibleName = userVisibleName
        self.startedAtISO = startedAtISO
        self.validationStatus = validationStatus
        self.readerVersion = readerVersion
        self.parserVersion = parserVersion
        self.layoutVersion = layoutVersion
    }
}

public struct ImportSessionRecordDTO: nonisolated Equatable {
    public let id: String
    public let workspaceId: String
    public let userVisibleName: String?
    public let startedAtISO: String
    public let completedAtISO: String?
    public let validationStatus: String
    public let readerVersion: String?
    public let parserVersion: String?
    public let layoutVersion: String?

    public init(id: String,
                workspaceId: String,
                userVisibleName: String?,
                startedAtISO: String,
                completedAtISO: String?,
                validationStatus: String,
                readerVersion: String?,
                parserVersion: String?,
                layoutVersion: String?) {
        self.id = id
        self.workspaceId = workspaceId
        self.userVisibleName = userVisibleName
        self.startedAtISO = startedAtISO
        self.completedAtISO = completedAtISO
        self.validationStatus = validationStatus
        self.readerVersion = readerVersion
        self.parserVersion = parserVersion
        self.layoutVersion = layoutVersion
    }
}

public struct ImportedDocumentDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let workspaceId: String
    public let importSessionId: String
    public let filename: String
    public let mimeType: String?
    public let sizeBytes: Int64?
    public let legacyRawTextSHA256: String
    public var sha256: String { legacyRawTextSHA256 }
    public let createdAtISO: String

    public init(
        id: String,
        workspaceId: String,
        importSessionId: String,
        filename: String,
        mimeType: String?,
        sizeBytes: Int64?,
        legacyRawTextSHA256: String,
        createdAtISO: String
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.importSessionId = importSessionId
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.legacyRawTextSHA256 = legacyRawTextSHA256
        self.createdAtISO = createdAtISO
    }

    public init(
        id: String,
        workspaceId: String,
        importSessionId: String,
        filename: String,
        mimeType: String?,
        sizeBytes: Int64?,
        sha256: String,
        createdAtISO: String
    ) {
        self.init(
            id: id,
            workspaceId: workspaceId,
            importSessionId: importSessionId,
            filename: filename,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            legacyRawTextSHA256: sha256,
            createdAtISO: createdAtISO
        )
    }
}

public struct DocumentFingerprintDTO: nonisolated Equatable, Sendable {
    public static let rawTextSHA256Algorithm = "ledgerforge.raw-text.sha256.v1"
    public static let sourceBytesSHA256Algorithm = "ledgerforge.source-bytes.sha256.v1"
    public static let approvedAlgorithms = Set([rawTextSHA256Algorithm, sourceBytesSHA256Algorithm])

    public let id: String
    public let documentId: String
    public let importSessionId: String
    public let algorithm: String
    public let fingerprint: String
    public let fingerprintData: String?
    public let isDuplicateAuthority: Bool
    public let createdAtISO: String

    public init(
        id: String,
        documentId: String,
        importSessionId: String,
        algorithm: String,
        fingerprint: String,
        fingerprintData: String?,
        isDuplicateAuthority: Bool = true,
        createdAtISO: String
    ) {
        self.id = id
        self.documentId = documentId
        self.importSessionId = importSessionId
        self.algorithm = algorithm
        self.fingerprint = fingerprint
        self.fingerprintData = fingerprintData
        self.isDuplicateAuthority = isDuplicateAuthority
        self.createdAtISO = createdAtISO
    }
}

/// Durable, privacy-safe projection of parser-owned zero-activity evidence.
///
/// This DTO carries only semantic controls and digest provenance.  It never
/// carries source bytes, extracted text, file URLs, or a user-entered
/// explanation.  The provider uses `isValid()` before writing and the
/// hydrator recomputes the semantic digest after reopening the database.
public struct StatementZeroActivityControlDTO: nonisolated Equatable, Sendable {
    public static let semanticDigestAlgorithm = ZeroActivityStatementEvidence.semanticDigestAlgorithm

    public let id: String
    public let workspaceId: String
    public let accountId: String
    public let documentId: String
    public let importSessionId: String
    public let normalizedDocumentId: String
    public let parserProfileId: String
    public let parserProfileVersion: String
    public let sourceFormatCode: String
    public let institutionCode: String
    public let statementFamilyCode: String
    public let statementDateISO: String?
    public let statementStartDateISO: String?
    public let statementEndDateISO: String?
    public let selectedStatementMonthISO: String?
    public let semanticCycleKey: String
    public let nativeCurrency: String
    public let openingBalanceMinor: Int64?
    public let openingBalanceDecimal: String?
    public let closingBalanceMinor: Int64?
    public let closingBalanceDecimal: String?
    public let debitTotalMinor: Int64?
    public let debitTotalDecimal: String?
    public let creditTotalMinor: Int64?
    public let creditTotalDecimal: String?
    public let cardPreviousBalanceMinor: Int64?
    public let cardPreviousBalanceDecimal: String?
    public let cardTotalPaymentDueMinor: Int64?
    public let cardTotalPaymentDueDecimal: String?
    public let cardPaymentDueDateISO: String?
    public let evidenceKind: String
    public let financialRegionDescriptor: String?
    public let financialRegionSourceUnit: String?
    public let financialRegionStartOrdinal: Int?
    public let financialRegionEndOrdinal: Int?
    public let financialRegionSignature: String?
    public let semanticDigestAlgorithm: String
    public let semanticDigest: String
    public let sourceFingerprintAlgorithm: String
    public let sourceFingerprintDigest: String
    public let authorityRole: String
    public let createdAtISO: String

    public init(
        id: String,
        workspaceId: String,
        accountId: String,
        documentId: String,
        importSessionId: String,
        normalizedDocumentId: String,
        parserProfileId: String,
        parserProfileVersion: String,
        sourceFormatCode: String,
        institutionCode: String,
        statementFamilyCode: String,
        statementDateISO: String? = nil,
        statementStartDateISO: String? = nil,
        statementEndDateISO: String? = nil,
        selectedStatementMonthISO: String? = nil,
        semanticCycleKey: String,
        nativeCurrency: String,
        openingBalanceMinor: Int64? = nil,
        openingBalanceDecimal: String? = nil,
        closingBalanceMinor: Int64? = nil,
        closingBalanceDecimal: String? = nil,
        debitTotalMinor: Int64? = nil,
        debitTotalDecimal: String? = nil,
        creditTotalMinor: Int64? = nil,
        creditTotalDecimal: String? = nil,
        cardPreviousBalanceMinor: Int64? = nil,
        cardPreviousBalanceDecimal: String? = nil,
        cardTotalPaymentDueMinor: Int64? = nil,
        cardTotalPaymentDueDecimal: String? = nil,
        cardPaymentDueDateISO: String? = nil,
        evidenceKind: String,
        financialRegionDescriptor: String? = nil,
        financialRegionSourceUnit: String? = nil,
        financialRegionStartOrdinal: Int? = nil,
        financialRegionEndOrdinal: Int? = nil,
        financialRegionSignature: String? = nil,
        semanticDigestAlgorithm: String = StatementZeroActivityControlDTO.semanticDigestAlgorithm,
        semanticDigest: String,
        sourceFingerprintAlgorithm: String,
        sourceFingerprintDigest: String,
        authorityRole: String = "authoritative",
        createdAtISO: String
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.accountId = accountId
        self.documentId = documentId
        self.importSessionId = importSessionId
        self.normalizedDocumentId = normalizedDocumentId
        self.parserProfileId = parserProfileId
        self.parserProfileVersion = parserProfileVersion
        self.sourceFormatCode = sourceFormatCode
        self.institutionCode = institutionCode
        self.statementFamilyCode = statementFamilyCode
        self.statementDateISO = statementDateISO
        self.statementStartDateISO = statementStartDateISO
        self.statementEndDateISO = statementEndDateISO
        self.selectedStatementMonthISO = selectedStatementMonthISO
        self.semanticCycleKey = semanticCycleKey
        self.nativeCurrency = nativeCurrency
        self.openingBalanceMinor = openingBalanceMinor
        self.openingBalanceDecimal = openingBalanceDecimal
        self.closingBalanceMinor = closingBalanceMinor
        self.closingBalanceDecimal = closingBalanceDecimal
        self.debitTotalMinor = debitTotalMinor
        self.debitTotalDecimal = debitTotalDecimal
        self.creditTotalMinor = creditTotalMinor
        self.creditTotalDecimal = creditTotalDecimal
        self.cardPreviousBalanceMinor = cardPreviousBalanceMinor
        self.cardPreviousBalanceDecimal = cardPreviousBalanceDecimal
        self.cardTotalPaymentDueMinor = cardTotalPaymentDueMinor
        self.cardTotalPaymentDueDecimal = cardTotalPaymentDueDecimal
        self.cardPaymentDueDateISO = cardPaymentDueDateISO
        self.evidenceKind = evidenceKind
        self.financialRegionDescriptor = financialRegionDescriptor
        self.financialRegionSourceUnit = financialRegionSourceUnit
        self.financialRegionStartOrdinal = financialRegionStartOrdinal
        self.financialRegionEndOrdinal = financialRegionEndOrdinal
        self.financialRegionSignature = financialRegionSignature
        self.semanticDigestAlgorithm = semanticDigestAlgorithm
        self.semanticDigest = semanticDigest
        self.sourceFingerprintAlgorithm = sourceFingerprintAlgorithm
        self.sourceFingerprintDigest = sourceFingerprintDigest
        self.authorityRole = authorityRole
        self.createdAtISO = createdAtISO
    }

    /// Validates the value-semantic part of the control. Relationship checks
    /// against documents, accounts, sessions, and fingerprints belong to the
    /// provider because only it can observe durable state atomically.
    func isValid() -> Bool {
        guard !id.isEmpty, !workspaceId.isEmpty, !accountId.isEmpty,
              !documentId.isEmpty, !importSessionId.isEmpty,
              !normalizedDocumentId.isEmpty, !sourceFingerprintAlgorithm.isEmpty,
              sourceFingerprintDigest.count == 64,
              sourceFingerprintDigest.unicodeScalars.allSatisfy({ "0123456789abcdef".unicodeScalars.contains($0) }),
              authorityRole == "authoritative" || authorityRole == "supporting",
              semanticDigestAlgorithm == Self.semanticDigestAlgorithm,
              semanticDigest.count == 64,
              semanticDigest.unicodeScalars.allSatisfy({ "0123456789abcdef".unicodeScalars.contains($0) }),
              financialRegionSourceUnit == nil ||
                FinancialRegionSourceUnit(rawValue: financialRegionSourceUnit!) != nil,
              let rebuilt = try? evidence(), rebuilt.semanticDigest == semanticDigest,
              institutionCode == rebuilt.institutionCode,
              statementFamilyCode == rebuilt.statementFamilyCode,
              semanticCycleKey == rebuilt.semanticCycleKey else {
            return false
        }
        return true
    }

    /// The selected durable account is part of the zero-activity authority.
    /// Structural similarity or a caller-supplied account choice must never
    /// override the exact registered institution, family type, or currency.
    func matchesAccount(_ account: AccountDTO) -> Bool {
        guard isValid(),
              let binding = ZeroActivityProfileBinding.resolve(
                  profileID: parserProfileId,
                  profileVersion: parserProfileVersion,
                  sourceFormatCode: sourceFormatCode
              ) else { return false }
        return account.id == accountId &&
            account.workspaceId == workspaceId &&
            account.institutionId == binding.institutionPersistenceID &&
            account.accountType == binding.accountTypeCode &&
            account.nativeCurrency == nativeCurrency
    }

    /// Rehydrates the model-level source evidence and is intentionally kept
    /// internal; the DTO is the public provider boundary.
    func evidence() throws -> ZeroActivityStatementEvidence {
        guard let kind = ZeroActivityEvidenceKind(rawValue: evidenceKind),
              let currency = try? CurrencyCode(nativeCurrency) else {
            throw ZeroActivityStatementEvidenceError.invalidDigest
        }
        let statementDate = try statementDateISO.map { try StatementDate(canonical: $0) }
        let selectedStatementMonth = try selectedStatementMonthISO.map {
            try SelectedStatementMonth(canonical: $0)
        }
        let cardPaymentDueDate = try cardPaymentDueDateISO.map {
            try StatementDate(canonical: $0)
        }
        let period: DeclaredStatementPeriod?
        if let startISO = statementStartDateISO, let endISO = statementEndDateISO {
            period = try DeclaredStatementPeriod(
                start: StatementDate(canonical: startISO),
                end: StatementDate(canonical: endISO)
            )
        } else {
            guard statementStartDateISO == nil, statementEndDateISO == nil else {
                throw ZeroActivityStatementEvidenceError.reversedPeriod
            }
            period = nil
        }
        func money(minor: Int64?, decimal: String?) throws -> Money? {
            guard let minor, let decimal else {
                guard minor == nil, decimal == nil else { throw ZeroActivityStatementEvidenceError.currencyMismatch }
                return nil
            }
            let byDecimal = try Money(canonicalDecimal: decimal, currency: nativeCurrency)
            let byMinor = try Money.fromMinorUnits(minor, currency: nativeCurrency)
            guard byDecimal == byMinor else { throw ZeroActivityStatementEvidenceError.currencyMismatch }
            return byDecimal
        }
        return try ZeroActivityStatementEvidence(
            profileID: parserProfileId,
            profileVersion: parserProfileVersion,
            sourceFormatCode: sourceFormatCode,
            evidenceKind: kind,
            financialRegionDescriptor: financialRegionDescriptor,
            financialRegionSourceUnit: financialRegionSourceUnit.flatMap(
                FinancialRegionSourceUnit.init(rawValue:)
            ),
            financialRegionStartOrdinal: financialRegionStartOrdinal,
            financialRegionEndOrdinal: financialRegionEndOrdinal,
            financialRegionSignature: financialRegionSignature,
            statementDate: statementDate,
            statementPeriod: period,
            selectedStatementMonth: selectedStatementMonth,
            nativeCurrency: currency,
            openingBalance: try money(minor: openingBalanceMinor, decimal: openingBalanceDecimal),
            closingBalance: try money(minor: closingBalanceMinor, decimal: closingBalanceDecimal),
            debitTotal: try money(minor: debitTotalMinor, decimal: debitTotalDecimal),
            creditTotal: try money(minor: creditTotalMinor, decimal: creditTotalDecimal),
            cardPreviousBalance: try money(
                minor: cardPreviousBalanceMinor,
                decimal: cardPreviousBalanceDecimal
            ),
            cardTotalPaymentDue: try money(
                minor: cardTotalPaymentDueMinor,
                decimal: cardTotalPaymentDueDecimal
            ),
            cardPaymentDueDate: cardPaymentDueDate,
            semanticDigest: semanticDigest
        )
    }

    static func make(
        evidence: ZeroActivityStatementEvidence,
        id: String,
        workspaceId: String,
        accountId: String,
        documentId: String,
        importSessionId: String,
        normalizedDocumentId: String,
        sourceFingerprintAlgorithm: String,
        sourceFingerprintDigest: String,
        authorityRole: String = "authoritative",
        createdAtISO: String
    ) throws -> Self {
        Self(
            id: id,
            workspaceId: workspaceId,
            accountId: accountId,
            documentId: documentId,
            importSessionId: importSessionId,
            normalizedDocumentId: normalizedDocumentId,
            parserProfileId: evidence.profileID,
            parserProfileVersion: evidence.profileVersion,
            sourceFormatCode: evidence.sourceFormatCode,
            institutionCode: evidence.institutionCode,
            statementFamilyCode: evidence.statementFamilyCode,
            statementDateISO: evidence.statementDate?.canonical,
            statementStartDateISO: evidence.statementPeriod?.start.canonical,
            statementEndDateISO: evidence.statementPeriod?.end.canonical,
            selectedStatementMonthISO: evidence.selectedStatementMonth?.canonical,
            semanticCycleKey: evidence.semanticCycleKey,
            nativeCurrency: evidence.nativeCurrency.code,
            openingBalanceMinor: try evidence.openingBalance.map { try $0.minorUnits() },
            openingBalanceDecimal: try evidence.openingBalance.map { try $0.canonicalDecimalString() },
            closingBalanceMinor: try evidence.closingBalance.map { try $0.minorUnits() },
            closingBalanceDecimal: try evidence.closingBalance.map { try $0.canonicalDecimalString() },
            debitTotalMinor: try evidence.debitTotal.map { try $0.minorUnits() },
            debitTotalDecimal: try evidence.debitTotal.map { try $0.canonicalDecimalString() },
            creditTotalMinor: try evidence.creditTotal.map { try $0.minorUnits() },
            creditTotalDecimal: try evidence.creditTotal.map { try $0.canonicalDecimalString() },
            cardPreviousBalanceMinor: try evidence.cardPreviousBalance.map { try $0.minorUnits() },
            cardPreviousBalanceDecimal: try evidence.cardPreviousBalance.map { try $0.canonicalDecimalString() },
            cardTotalPaymentDueMinor: try evidence.cardTotalPaymentDue.map { try $0.minorUnits() },
            cardTotalPaymentDueDecimal: try evidence.cardTotalPaymentDue.map { try $0.canonicalDecimalString() },
            cardPaymentDueDateISO: evidence.cardPaymentDueDate?.canonical,
            evidenceKind: evidence.evidenceKind.rawValue,
            financialRegionDescriptor: evidence.financialRegionDescriptor,
            financialRegionSourceUnit: evidence.financialRegionSourceUnit?.rawValue,
            financialRegionStartOrdinal: evidence.financialRegionStartOrdinal,
            financialRegionEndOrdinal: evidence.financialRegionEndOrdinal,
            financialRegionSignature: evidence.financialRegionSignature,
            semanticDigestAlgorithm: Self.semanticDigestAlgorithm,
            semanticDigest: evidence.semanticDigest,
            sourceFingerprintAlgorithm: sourceFingerprintAlgorithm,
            sourceFingerprintDigest: sourceFingerprintDigest,
            authorityRole: authorityRole,
            createdAtISO: createdAtISO
        )
    }

    func withAuthorityRole(_ role: String) -> Self {
        Self(
            id: id,
            workspaceId: workspaceId,
            accountId: accountId,
            documentId: documentId,
            importSessionId: importSessionId,
            normalizedDocumentId: normalizedDocumentId,
            parserProfileId: parserProfileId,
            parserProfileVersion: parserProfileVersion,
            sourceFormatCode: sourceFormatCode,
            institutionCode: institutionCode,
            statementFamilyCode: statementFamilyCode,
            statementDateISO: statementDateISO,
            statementStartDateISO: statementStartDateISO,
            statementEndDateISO: statementEndDateISO,
            selectedStatementMonthISO: selectedStatementMonthISO,
            semanticCycleKey: semanticCycleKey,
            nativeCurrency: nativeCurrency,
            openingBalanceMinor: openingBalanceMinor,
            openingBalanceDecimal: openingBalanceDecimal,
            closingBalanceMinor: closingBalanceMinor,
            closingBalanceDecimal: closingBalanceDecimal,
            debitTotalMinor: debitTotalMinor,
            debitTotalDecimal: debitTotalDecimal,
            creditTotalMinor: creditTotalMinor,
            creditTotalDecimal: creditTotalDecimal,
            cardPreviousBalanceMinor: cardPreviousBalanceMinor,
            cardPreviousBalanceDecimal: cardPreviousBalanceDecimal,
            cardTotalPaymentDueMinor: cardTotalPaymentDueMinor,
            cardTotalPaymentDueDecimal: cardTotalPaymentDueDecimal,
            cardPaymentDueDateISO: cardPaymentDueDateISO,
            evidenceKind: evidenceKind,
            financialRegionDescriptor: financialRegionDescriptor,
            financialRegionSourceUnit: financialRegionSourceUnit,
            financialRegionStartOrdinal: financialRegionStartOrdinal,
            financialRegionEndOrdinal: financialRegionEndOrdinal,
            financialRegionSignature: financialRegionSignature,
            semanticDigestAlgorithm: semanticDigestAlgorithm,
            semanticDigest: semanticDigest,
            sourceFingerprintAlgorithm: sourceFingerprintAlgorithm,
            sourceFingerprintDigest: sourceFingerprintDigest,
            authorityRole: role,
            createdAtISO: createdAtISO
        )
    }
}

public struct PriorImportedStatementDTO: nonisolated Equatable {
    public let importSessionId: String
    public let completedAtISO: String?
    public let transactionCount: Int
    public let accountId: String?
    public let accountDisplayName: String?

    public init(
        importSessionId: String,
        completedAtISO: String?,
        transactionCount: Int,
        accountId: String?,
        accountDisplayName: String?
    ) {
        self.importSessionId = importSessionId
        self.completedAtISO = completedAtISO
        self.transactionCount = transactionCount
        self.accountId = accountId
        self.accountDisplayName = accountDisplayName
    }
}

public struct TransactionEventIdentityKeyDTO: nonisolated Hashable {
    public let algorithm: String
    public let digest: String
    public init(algorithm: String, digest: String) { self.algorithm = algorithm; self.digest = digest }
}

public struct TransactionEventIdentityDTO: nonisolated Equatable {
    public let id: String
    public let transactionId: String
    public let accountId: String
    public let documentId: String
    public let importSessionId: String
    public let algorithm: String
    public let digest: String
    public let createdAtISO: String
    public init(id: String, transactionId: String, accountId: String, documentId: String, importSessionId: String, algorithm: String, digest: String, createdAtISO: String) {
        self.id = id; self.transactionId = transactionId; self.accountId = accountId; self.documentId = documentId; self.importSessionId = importSessionId; self.algorithm = algorithm; self.digest = digest; self.createdAtISO = createdAtISO
    }
}

public struct TransactionEventIdentityOwnerDTO: nonisolated Equatable {
    public let eventIdentityId: String
    public let accountId: String
    public let transactionId: String
    public let documentId: String
    public let importSessionId: String
    public init(eventIdentityId: String = "", accountId: String, transactionId: String, documentId: String, importSessionId: String) {
        self.eventIdentityId = eventIdentityId; self.accountId = accountId; self.transactionId = transactionId; self.documentId = documentId; self.importSessionId = importSessionId
    }
}

/// Privacy-safe durable record of a processing attempt. These fields are intentionally
/// bounded codes and trusted repository relationships; source evidence never crosses
/// this boundary.
public struct ImportAttemptDTO: nonisolated Equatable, Identifiable, Sendable {
    public let id: String
    public let workspaceId: String
    public let createdAtISO: String
    public let outcomeCode: String
    public let coverageCode: String
    public let accountDecisionCode: String
    public let guidanceCode: String
    public let persistenceCode: String
    public let transactionCount: Int
    public let accountId: String?
    public let importSessionId: String?
    public let documentId: String?
    public let relatedImportSessionId: String?
    public let sourceRowCount: Int?
    public let importedTransactionCount: Int?
    public let recognizedExistingRowCount: Int?
    public let blockedRowCount: Int?

    public init(id: String = UUID().uuidString, workspaceId: String, createdAtISO: String,
                outcomeCode: String, coverageCode: String, accountDecisionCode: String,
                guidanceCode: String, persistenceCode: String, transactionCount: Int,
                accountId: String? = nil, importSessionId: String? = nil,
                documentId: String? = nil, relatedImportSessionId: String? = nil,
                sourceRowCount: Int? = nil, importedTransactionCount: Int? = nil,
                recognizedExistingRowCount: Int? = nil, blockedRowCount: Int? = nil) {
        self.id = id; self.workspaceId = workspaceId; self.createdAtISO = createdAtISO
        self.outcomeCode = outcomeCode; self.coverageCode = coverageCode
        self.accountDecisionCode = accountDecisionCode; self.guidanceCode = guidanceCode
        self.persistenceCode = persistenceCode; self.transactionCount = transactionCount
        self.accountId = accountId; self.importSessionId = importSessionId
        self.documentId = documentId; self.relatedImportSessionId = relatedImportSessionId
        self.sourceRowCount = sourceRowCount
        self.importedTransactionCount = importedTransactionCount
        self.recognizedExistingRowCount = recognizedExistingRowCount
        self.blockedRowCount = blockedRowCount
    }
}

public struct PreferredTransactionSourceDTO: nonisolated Equatable, Sendable {
    public let transactionId: String
    public let documentId: String
    public let importSessionId: String
    public let sourceFormatCode: String
    public let sourceTransactionDateISO: String?
    public let structuredReferenceDigest: String?

    public init(transactionId: String, documentId: String, importSessionId: String, sourceFormatCode: String, sourceTransactionDateISO: String? = nil, structuredReferenceDigest: String? = nil) {
        self.transactionId = transactionId
        self.documentId = documentId
        self.importSessionId = importSessionId
        self.sourceFormatCode = sourceFormatCode
        self.sourceTransactionDateISO = sourceTransactionDateISO
        self.structuredReferenceDigest = structuredReferenceDigest
    }
}

public struct CBQSourceObservationSummaryDTO: nonisolated Equatable, Sendable {
    public let documentId: String
    public let importSessionId: String
    public let sourceFormatCode: String
    public let sourceRowCount: Int
    public let importedTransactionCount: Int
    public let representedTransactionCount: Int
    public let transactionObservationCount: Int

    public init(documentId: String, importSessionId: String, sourceFormatCode: String, sourceRowCount: Int, importedTransactionCount: Int, representedTransactionCount: Int, transactionObservationCount: Int) {
        self.documentId = documentId
        self.importSessionId = importSessionId
        self.sourceFormatCode = sourceFormatCode
        self.sourceRowCount = sourceRowCount
        self.importedTransactionCount = importedTransactionCount
        self.representedTransactionCount = representedTransactionCount
        self.transactionObservationCount = transactionObservationCount
    }
}

struct RepositoryImportAttempt: nonisolated Identifiable, Equatable {
    let id: String; let createdAtISO: String; let outcomeCode: String; let coverageCode: String
    let accountDecisionCode: String; let guidanceCode: String; let persistenceCode: String
    let transactionCount: Int; let accountId: String?; let importSessionId: String?
    let documentId: String?; let relatedImportSessionId: String?
    let sourceRowCount: Int?; let importedTransactionCount: Int?
    let recognizedExistingRowCount: Int?; let blockedRowCount: Int?
    nonisolated init(_ dto: ImportAttemptDTO) {
        id = dto.id; createdAtISO = dto.createdAtISO; outcomeCode = dto.outcomeCode; coverageCode = dto.coverageCode
        accountDecisionCode = dto.accountDecisionCode; guidanceCode = dto.guidanceCode; persistenceCode = dto.persistenceCode
        transactionCount = dto.transactionCount; accountId = dto.accountId; importSessionId = dto.importSessionId; documentId = dto.documentId; relatedImportSessionId = dto.relatedImportSessionId
        sourceRowCount = dto.sourceRowCount; importedTransactionCount = dto.importedTransactionCount
        recognizedExistingRowCount = dto.recognizedExistingRowCount; blockedRowCount = dto.blockedRowCount
    }
}

public struct PartialImportSummaryDTO: nonisolated Equatable, Sendable {
    public let importSessionId: String
    public let documentId: String
    public let planDigestAlgorithm: String
    public let planDigest: String
    public let statementStartDateISO: String
    public let statementEndDateISO: String
    public let nativeCurrency: String
    public let sourceRowCount: Int
    public let importedTransactionCount: Int
    public let recognizedExistingRowCount: Int
    public let blockedRowCount: Int
    public let openingBalanceMinor: Int64
    public let openingBalanceDecimal: String
    public let closingBalanceMinor: Int64
    public let closingBalanceDecimal: String
    public let createdAtISO: String

    public init(importSessionId: String, documentId: String, planDigestAlgorithm: String, planDigest: String, statementStartDateISO: String, statementEndDateISO: String, nativeCurrency: String, sourceRowCount: Int, importedTransactionCount: Int, recognizedExistingRowCount: Int, blockedRowCount: Int, openingBalanceMinor: Int64, openingBalanceDecimal: String, closingBalanceMinor: Int64, closingBalanceDecimal: String, createdAtISO: String) {
        self.importSessionId = importSessionId; self.documentId = documentId
        self.planDigestAlgorithm = planDigestAlgorithm; self.planDigest = planDigest
        self.statementStartDateISO = statementStartDateISO; self.statementEndDateISO = statementEndDateISO
        self.nativeCurrency = nativeCurrency; self.sourceRowCount = sourceRowCount
        self.importedTransactionCount = importedTransactionCount
        self.recognizedExistingRowCount = recognizedExistingRowCount; self.blockedRowCount = blockedRowCount
        self.openingBalanceMinor = openingBalanceMinor; self.openingBalanceDecimal = openingBalanceDecimal
        self.closingBalanceMinor = closingBalanceMinor; self.closingBalanceDecimal = closingBalanceDecimal
        self.createdAtISO = createdAtISO
    }
}

public struct IncomingRowDispositionDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let importSessionId: String
    public let documentId: String
    public let normalizedRowId: String
    public let sourceOrdinal: Int
    public let dispositionCode: String
    public let transactionId: String
    public let transactionEventIdentityId: String
    public let statementDateISO: String
    public let financialDateRole: String
    public let statementTimezoneEvidence: String
    public let nativeCurrency: String
    public let amountMinor: Int64
    public let amountDecimal: String
    public let direction: String
    public let runningBalanceMinor: Int64
    public let createdAtISO: String
    public let eventTransactionId: String?

    public init(id: String, importSessionId: String, documentId: String, normalizedRowId: String, sourceOrdinal: Int, dispositionCode: String, transactionId: String, transactionEventIdentityId: String, statementDateISO: String, financialDateRole: String, statementTimezoneEvidence: String, nativeCurrency: String, amountMinor: Int64, amountDecimal: String, direction: String, runningBalanceMinor: Int64, createdAtISO: String, eventTransactionId: String? = nil) {
        self.id = id; self.importSessionId = importSessionId; self.documentId = documentId
        self.normalizedRowId = normalizedRowId; self.sourceOrdinal = sourceOrdinal
        self.dispositionCode = dispositionCode; self.transactionId = transactionId
        self.transactionEventIdentityId = transactionEventIdentityId; self.statementDateISO = statementDateISO
        self.financialDateRole = financialDateRole; self.statementTimezoneEvidence = statementTimezoneEvidence
        self.nativeCurrency = nativeCurrency; self.amountMinor = amountMinor; self.amountDecimal = amountDecimal
        self.direction = direction; self.runningBalanceMinor = runningBalanceMinor; self.createdAtISO = createdAtISO
        self.eventTransactionId = eventTransactionId
    }
}

public struct AtomicImportHistoryDTO: nonisolated Equatable {
    public let document: ImportedDocumentDTO
    public let fingerprint: DocumentFingerprintDTO
    public let importSession: ImportSessionDTO
    public let completedAtISO: String
    public let transactions: [TransactionDTO]
    public let transactionEventIdentities: [TransactionEventIdentityDTO]
    public let successfulAttempt: ImportAttemptDTO

    public init(
        document: ImportedDocumentDTO,
        fingerprint: DocumentFingerprintDTO,
        importSession: ImportSessionDTO,
        completedAtISO: String,
        transactions: [TransactionDTO],
        transactionEventIdentities: [TransactionEventIdentityDTO] = [],
        successfulAttempt: ImportAttemptDTO
    ) {
        self.document = document
        self.fingerprint = fingerprint
        self.importSession = importSession
        self.completedAtISO = completedAtISO
        self.transactions = transactions
        self.transactionEventIdentities = transactionEventIdentities
        self.successfulAttempt = successfulAttempt
    }
}

public enum AtomicImportHistoryResult: nonisolated Equatable {
    case committed
    case duplicate(PriorImportedStatementDTO)
}
