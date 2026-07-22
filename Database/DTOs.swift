// Database/DTOs.swift
// Strongly typed DTOs for repository APIs

import Foundation

nonisolated enum ImportAttemptOutcome: String, CaseIterable { case successfulImport = "successful_import", validationFailure = "validation_failure", persistenceFailure = "persistence_failure", exactStatementDuplicate = "exact_statement_duplicate", existingEligibleAxisUPIEvent = "existing_eligible_axis_upi_event", repeatedEligibleIncomingEvidence = "repeated_eligible_incoming_evidence", transactionEventOwnershipConflict = "transaction_event_ownership_conflict", repositoryIntegrityConflict = "repository_integrity_conflict", identityAmbiguity = "identity_ambiguity", identityConflict = "identity_conflict", staleAccountChoice = "stale_account_choice", staleProviderGeneration = "stale_provider_generation", sqliteContention = "sqlite_contention" }
nonisolated enum ImportAttemptCoverage: String { case evaluatedSupportedOnly = "evaluated_supported_only", unsupportedOrUnevaluated = "unsupported_or_unevaluated" }
nonisolated enum ImportAttemptAccountDecision: String { case resolvedOrCreated = "resolved_or_created", selectedExisting = "selected_existing", noFinancialMutation = "no_financial_mutation", sideEffectsMayExist = "side_effects_may_exist" }
nonisolated enum ImportAttemptGuidance: String { case importCompleted = "import_completed", reviewPriorImport = "review_prior_import", supportedEventBlocked = "supported_event_blocked", correctValidationAndRetry = "correct_validation_and_retry", persistenceUnavailable = "persistence_unavailable", integrityReviewRequired = "integrity_review_required", prepareAgain = "prepare_again", retryConfirmation = "retry_confirmation" }
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

public struct TransactionRawRowDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let normalizedRowId: String
    public let contributionType: String?
    public let sourceOrdinal: Int?
    public let normalizedRecordDigest: String?
    public let normalizedDocumentId: String?

    public init(id: String = UUID().uuidString, normalizedRowId: String, contributionType: String? = nil, sourceOrdinal: Int? = nil, normalizedRecordDigest: String? = nil, normalizedDocumentId: String? = nil) {
        self.id = id
        self.normalizedRowId = normalizedRowId
        self.contributionType = contributionType
        self.sourceOrdinal = sourceOrdinal
        self.normalizedRecordDigest = normalizedRecordDigest
        self.normalizedDocumentId = normalizedDocumentId
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
    public let sha256: String
    public let createdAtISO: String

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
        self.id = id
        self.workspaceId = workspaceId
        self.importSessionId = importSessionId
        self.filename = filename
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.createdAtISO = createdAtISO
    }
}

public struct DocumentFingerprintDTO: nonisolated Equatable, Sendable {
    public let id: String
    public let documentId: String
    public let importSessionId: String
    public let algorithm: String
    public let fingerprint: String
    public let fingerprintData: String?
    public let createdAtISO: String

    public init(
        id: String,
        documentId: String,
        importSessionId: String,
        algorithm: String,
        fingerprint: String,
        fingerprintData: String?,
        createdAtISO: String
    ) {
        self.id = id
        self.documentId = documentId
        self.importSessionId = importSessionId
        self.algorithm = algorithm
        self.fingerprint = fingerprint
        self.fingerprintData = fingerprintData
        self.createdAtISO = createdAtISO
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
    public let accountId: String
    public let transactionId: String
    public let documentId: String
    public let importSessionId: String
    public init(accountId: String, transactionId: String, documentId: String, importSessionId: String) {
        self.accountId = accountId; self.transactionId = transactionId; self.documentId = documentId; self.importSessionId = importSessionId
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

    public init(id: String = UUID().uuidString, workspaceId: String, createdAtISO: String,
                outcomeCode: String, coverageCode: String, accountDecisionCode: String,
                guidanceCode: String, persistenceCode: String, transactionCount: Int,
                accountId: String? = nil, importSessionId: String? = nil,
                documentId: String? = nil, relatedImportSessionId: String? = nil) {
        self.id = id; self.workspaceId = workspaceId; self.createdAtISO = createdAtISO
        self.outcomeCode = outcomeCode; self.coverageCode = coverageCode
        self.accountDecisionCode = accountDecisionCode; self.guidanceCode = guidanceCode
        self.persistenceCode = persistenceCode; self.transactionCount = transactionCount
        self.accountId = accountId; self.importSessionId = importSessionId
        self.documentId = documentId; self.relatedImportSessionId = relatedImportSessionId
    }
}

struct RepositoryImportAttempt: nonisolated Identifiable, Equatable {
    let id: String; let createdAtISO: String; let outcomeCode: String; let coverageCode: String
    let accountDecisionCode: String; let guidanceCode: String; let persistenceCode: String
    let transactionCount: Int; let accountId: String?; let importSessionId: String?
    let documentId: String?; let relatedImportSessionId: String?
    nonisolated init(_ dto: ImportAttemptDTO) {
        id = dto.id; createdAtISO = dto.createdAtISO; outcomeCode = dto.outcomeCode; coverageCode = dto.coverageCode
        accountDecisionCode = dto.accountDecisionCode; guidanceCode = dto.guidanceCode; persistenceCode = dto.persistenceCode
        transactionCount = dto.transactionCount; accountId = dto.accountId; importSessionId = dto.importSessionId; documentId = dto.documentId; relatedImportSessionId = dto.relatedImportSessionId
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
