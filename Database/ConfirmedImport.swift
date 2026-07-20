// Bounded provider-owned contract for one accepted confirmed import.

import Foundation

/// Opaque provider identity captured with a prepared import. It has no display
/// representation and is compared only for equality.
public struct ProviderGenerationToken: Equatable, Hashable, Sendable {
    fileprivate let value: UUID
    public init() { value = UUID() }
}

public enum ConfirmedImportAccountChoiceDTO: Equatable, Sendable {
    case createProposedAccount
    case useExistingAccount(accountId: String)
}

public enum ConfirmedImportAdvisoryIdentityDTO: Equatable, Sendable {
    case resolved(accountId: String)
    case noMatch
    case ambiguous
    case conflict
}

public struct ConfirmedImportIdentifierCandidateDTO: Equatable, Sendable {
    public let scheme: String
    public let normalizedValue: String
    public let provenanceCode: String

    public init(scheme: String, normalizedValue: String, provenanceCode: String) {
        self.scheme = scheme
        self.normalizedValue = normalizedValue
        self.provenanceCode = provenanceCode
    }
}

/// Parser-produced, transient evidence transported only until the confirmed
/// provider has selected the final durable account. It is deliberately not a
/// persistence DTO and must never be serialized into history or diagnostics.
public enum ConfirmedImportTransactionEventEvidenceDTO: Equatable, Sendable {
    case axisUPI(ConfirmedImportAxisUPIEventEvidenceDTO)
}

public struct ConfirmedImportAxisUPIEventEvidenceDTO: Equatable, Sendable {
    public enum Operation: String, Equatable, Sendable {
        case p2a
        case p2m
    }

    public enum LedgerSubtype: String, Equatable, Sendable {
        case posting
        case creditAdjustment = "credit-adjustment"
    }

    public let operation: Operation
    public let reference: String
    public let subtype: LedgerSubtype

    public init(operation: Operation, reference: String, subtype: LedgerSubtype) {
        self.operation = operation
        self.reference = reference
        self.subtype = subtype
    }
}

/// Account-independent input. The provider assigns the final account before it
/// derives any event identity.
public struct ConfirmedImportTransactionTemplateDTO: Equatable, Sendable {
    public let transaction: TransactionDTO
    public let eventEvidence: ConfirmedImportTransactionEventEvidenceDTO?

    public init(
        transaction: TransactionDTO,
        eventEvidence: ConfirmedImportTransactionEventEvidenceDTO? = nil
    ) {
        self.transaction = transaction
        self.eventEvidence = eventEvidence
    }

    /// Providers reject preassigned transactions instead of accepting a
    /// caller-supplied durable account or an already-derived event identity.
    public var isAccountIndependent: Bool { transaction.accountId == nil }
}

public struct IdentifierObservationDTO: Equatable, Sendable {
    public let ownershipId: String
    public let importSessionId: String
    public let documentId: String
    public let parserProvenanceCode: String
    public let associationAuthorityCode: String
    public let createdAtISO: String

    public init(ownershipId: String, importSessionId: String, documentId: String, parserProvenanceCode: String, associationAuthorityCode: String, createdAtISO: String) {
        self.ownershipId = ownershipId
        self.importSessionId = importSessionId
        self.documentId = documentId
        self.parserProvenanceCode = parserProvenanceCode
        self.associationAuthorityCode = associationAuthorityCode
        self.createdAtISO = createdAtISO
    }
}

/// Account-independent history inputs. The provider composes the final
/// `AtomicImportHistoryDTO` only after it has resolved an account and derived
/// final transaction-event identities.
public struct ConfirmedImportHistoryTemplateDTO: Equatable, Sendable {
    public let document: ImportedDocumentDTO
    public let fingerprint: DocumentFingerprintDTO
    public let importSession: ImportSessionDTO
    public let completedAtISO: String
    public let successfulAttempt: ImportAttemptDTO

    public init(
        document: ImportedDocumentDTO,
        fingerprint: DocumentFingerprintDTO,
        importSession: ImportSessionDTO,
        completedAtISO: String,
        successfulAttempt: ImportAttemptDTO
    ) {
        self.document = document
        self.fingerprint = fingerprint
        self.importSession = importSession
        self.completedAtISO = completedAtISO
        self.successfulAttempt = successfulAttempt
    }
}

public struct ConfirmedImportPlanDTO: Equatable, Sendable {
    public let providerGeneration: ProviderGenerationToken
    public let workspace: WorkspaceDTO
    public let proposedAccount: AccountDTO
    public let accountChoice: ConfirmedImportAccountChoiceDTO
    public let advisoryIdentity: ConfirmedImportAdvisoryIdentityDTO
    public let identifiers: [ConfirmedImportIdentifierCandidateDTO]
    public let historyTemplate: ConfirmedImportHistoryTemplateDTO
    public let transactionTemplates: [ConfirmedImportTransactionTemplateDTO]

    public init(providerGeneration: ProviderGenerationToken, workspace: WorkspaceDTO, proposedAccount: AccountDTO, accountChoice: ConfirmedImportAccountChoiceDTO, advisoryIdentity: ConfirmedImportAdvisoryIdentityDTO, identifiers: [ConfirmedImportIdentifierCandidateDTO], historyTemplate: ConfirmedImportHistoryTemplateDTO, transactionTemplates: [ConfirmedImportTransactionTemplateDTO]) {
        self.providerGeneration = providerGeneration
        self.workspace = workspace
        self.proposedAccount = proposedAccount
        self.accountChoice = accountChoice
        self.advisoryIdentity = advisoryIdentity
        self.identifiers = identifiers
        self.historyTemplate = historyTemplate
        self.transactionTemplates = transactionTemplates
    }
}

public struct ConfirmedImportReceiptDTO: Equatable, Sendable {
    public let workspaceId: String
    public let accountId: String
    public let importSessionId: String
    public let documentId: String

    public init(workspaceId: String, accountId: String, importSessionId: String, documentId: String) {
        self.workspaceId = workspaceId
        self.accountId = accountId
        self.importSessionId = importSessionId
        self.documentId = documentId
    }
}

public enum ConfirmedImportRepositoryResult: Equatable, Sendable, CustomStringConvertible {
    case committed(ConfirmedImportReceiptDTO)
    case exactDuplicate
    case repeatedIncomingEventEvidence
    case existingEventDuplicate
    case eventOwnershipConflict
    case identityAmbiguous
    case identityConflict
    case explicitAccountChoiceRequired
    case selectedAccountUnavailable
    case selectedAccountIneligible
    case selectedAccountWorkspaceMismatch
    case identifierOwnershipConflict
    case staleIdentityDecision
    case staleProviderGeneration
    case repositoryIntegrityConflict
    case retryableContention
    case persistenceUnavailable

    public var description: String {
        switch self {
        case .committed: return "Confirmed import committed."
        case .exactDuplicate: return "The statement was already imported."
        case .repeatedIncomingEventEvidence: return "Incoming transaction evidence conflicts within this import."
        case .existingEventDuplicate: return "A supported transaction event already exists."
        case .eventOwnershipConflict: return "Supported transaction event ownership conflicts."
        case .identityAmbiguous: return "Account identity is ambiguous."
        case .identityConflict: return "Account identity conflicts."
        case .explicitAccountChoiceRequired: return "An explicit account choice is required."
        case .selectedAccountUnavailable: return "The selected account is unavailable."
        case .selectedAccountIneligible: return "The selected account is not eligible."
        case .selectedAccountWorkspaceMismatch: return "The selected account does not belong to this workspace."
        case .identifierOwnershipConflict: return "Account ownership conflicts."
        case .staleIdentityDecision: return "The prepared account decision is no longer current."
        case .staleProviderGeneration: return "The persistence provider changed before confirmation."
        case .repositoryIntegrityConflict: return "Repository integrity prevented confirmation."
        case .retryableContention: return "Persistence is busy; retry confirmation."
        case .persistenceUnavailable: return "Persistence is unavailable."
        }
    }
}
