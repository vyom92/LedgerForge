// LedgerForge
// ImportPersistenceCoordinator.swift

import Foundation

struct ImportPersistenceResult: Equatable {
    let persisted: Bool
    let workspaceId: String?
    let accountId: String?
    let importSessionId: String?
    let transactionCount: Int
    let previousImport: PreviouslyImportedStatement?
    let transactionEventBlock: TransactionEventBlock?
    let importAttemptId: String?
    let sourceRowCount: Int?
    let recognizedExistingRowCount: Int?
    let isPartialImport: Bool
    let accountOutcome: ImportAccountOutcome

    init(
        persisted: Bool,
        workspaceId: String?,
        accountId: String?,
        importSessionId: String?,
        transactionCount: Int,
        previousImport: PreviouslyImportedStatement? = nil,
        transactionEventBlock: TransactionEventBlock? = nil,
        importAttemptId: String? = nil,
        sourceRowCount: Int? = nil,
        recognizedExistingRowCount: Int? = nil,
        isPartialImport: Bool = false,
        accountOutcome: ImportAccountOutcome = .unavailable
    ) {
        self.persisted = persisted
        self.workspaceId = workspaceId
        self.accountId = accountId
        self.importSessionId = importSessionId
        self.transactionCount = transactionCount
        self.previousImport = previousImport
        self.transactionEventBlock = transactionEventBlock
        self.importAttemptId = importAttemptId
        self.sourceRowCount = sourceRowCount
        self.recognizedExistingRowCount = recognizedExistingRowCount
        self.isPartialImport = isPartialImport
        self.accountOutcome = accountOutcome
    }

    static let skipped = ImportPersistenceResult(
        persisted: false,
        workspaceId: nil,
        accountId: nil,
        importSessionId: nil,
        transactionCount: 0,
        previousImport: nil
        , transactionEventBlock: nil
    )
}

enum TransactionEventBlock: Equatable {
    case existing(count: Int)
    case repeatedIncoming(count: Int)
    case ownershipConflict
    case repositoryIntegrityConflict
}

struct PreviouslyImportedStatement: Equatable {
    let importSessionId: String
    let completedAtISO: String?
    let transactionCount: Int
    let accountId: String?
    let accountDisplayName: String?
}

enum SourceSnapshotRejectionKind: Equatable, Sendable {
    case acquisitionFailed
    case integrityFailed
}

struct SourceSnapshotRejectionRecord: Equatable, Sendable {
    let importAttemptId: String?
    let persistence: ImportAttemptPersistence

    static let auditWriteUnavailable = SourceSnapshotRejectionRecord(
        importAttemptId: nil,
        persistence: .auditWriteUnavailable
    )
}

protocol ImportPersistenceCoordinating {
    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult

    func reviewValidatedImport(
        financialDocument: FinancialDocument,
        validation: ImportValidationResult
    ) throws -> ImportIdentityReview

    func reviewPartialImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> PartialImportReviewResult

    func persistReviewedPartialImport(
        _ plan: ReviewedPartialImportPlanDTO
    ) throws -> ImportPersistenceResult

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement?
    func recordValidationFailure(fileName: String, transactionCount: Int) -> String?
    func recordSourceSnapshotRejection(_ kind: SourceSnapshotRejectionKind) -> SourceSnapshotRejectionRecord

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult

    func reviewPartialImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> PartialImportReviewResult
}

enum ImportAccountChoice: Equatable {
    case useExistingAccount(accountId: String)
    case createNewAccount
}

enum ImportIdentityReview: Equatable, Sendable {
    case unavailable
    case matchedExisting(accountId: String)
    case choiceRequired(eligibleAccountIds: [String])
    case ambiguous
    case conflict

    var eligibleAccountIds: [String] {
        guard case .choiceRequired(let eligibleAccountIds) = self else { return [] }
        return eligibleAccountIds
    }

    var requiresExplicitChoice: Bool {
        if case .choiceRequired = self { return true }
        return false
    }

    var blocksConfirmation: Bool {
        switch self {
        case .choiceRequired, .ambiguous, .conflict:
            return true
        case .unavailable, .matchedExisting:
            return false
        }
    }

    /// Temporary Packet 1 compatibility for the existing SwiftUI account
    /// choice controls. Packet 2 owns typed presentation integration.
    var isAvailable: Bool { requiresExplicitChoice }
}

enum ImportAccountOutcome: CaseIterable, Equatable, Sendable {
    case matchedExisting
    case choiceRequired
    case userSelectedExisting
    case createdNew
    case identityAmbiguous
    case identityConflict
    case identifierOwnershipConflict
    case staleAccountChoice
    case staleProviderGeneration
    case unavailable

    static func confirmed(
        advisoryIdentity: ConfirmedImportAdvisoryIdentityDTO,
        accountChoice: ConfirmedImportAccountChoiceDTO,
        eligibleIdentifierCount: Int
    ) -> ImportAccountOutcome {
        guard eligibleIdentifierCount > 0 else { return .unavailable }

        switch (advisoryIdentity, accountChoice) {
        case let (.resolved(resolvedAccountID), .useExistingAccount(selectedAccountID))
            where resolvedAccountID == selectedAccountID:
            return .matchedExisting
        case (.noMatch, .useExistingAccount):
            return .userSelectedExisting
        case (.noMatch, .createProposedAccount):
            return .createdNew
        default:
            return .unavailable
        }
    }

    static func rejected(_ result: ConfirmedImportRepositoryResult) -> ImportAccountOutcome {
        switch result {
        case .explicitAccountChoiceRequired:
            return .choiceRequired
        case .identityAmbiguous:
            return .identityAmbiguous
        case .identityConflict:
            return .identityConflict
        case .identifierOwnershipConflict:
            return .identifierOwnershipConflict
        case .selectedAccountUnavailable, .selectedAccountIneligible,
                .selectedAccountWorkspaceMismatch, .staleIdentityDecision:
            return .staleAccountChoice
        case .staleProviderGeneration:
            return .staleProviderGeneration
        default:
            return .unavailable
        }
    }

    var successfulAttemptDecision: ImportAttemptAccountDecision {
        switch self {
        case .matchedExisting:
            return .matchedExisting
        case .userSelectedExisting:
            return .userSelectedExisting
        case .createdNew:
            return .createdNew
        case .unavailable:
            // Identifier-free historical behavior remains readable and new
            // identifier-free imports must not claim that identity created an account.
            return .resolvedOrCreated
        case .choiceRequired, .identityAmbiguous, .identityConflict,
                .identifierOwnershipConflict, .staleAccountChoice,
                .staleProviderGeneration:
            return .noFinancialMutation
        }
    }
}

struct ImportAccountOutcomePresentation: Equatable, Sendable {
    let label: String
    let explanation: String
}

enum ImportAccountOutcomePresentationMapper {
    static func presentation(
        for outcome: ImportAccountOutcome
    ) -> ImportAccountOutcomePresentation {
        switch outcome {
        case .matchedExisting:
            return ImportAccountOutcomePresentation(
                label: "Matched an existing account",
                explanation: "A verified account identifier is already owned by this account."
            )
        case .choiceRequired:
            return ImportAccountOutcomePresentation(
                label: "Choose an account",
                explanation: "No existing account owns this verified identifier. Choose an eligible account or create a new one."
            )
        case .userSelectedExisting:
            return ImportAccountOutcomePresentation(
                label: "Used your selected account",
                explanation: "You selected an eligible existing account for this verified identifier."
            )
        case .createdNew:
            return ImportAccountOutcomePresentation(
                label: "Created a new account",
                explanation: "The import created a new account for this verified identifier."
            )
        case .identityAmbiguous:
            return ImportAccountOutcomePresentation(
                label: "Account match ambiguous",
                explanation: "One verified identifier is associated with more than one account. No account was selected."
            )
        case .identityConflict:
            return ImportAccountOutcomePresentation(
                label: "Account identity conflict",
                explanation: "Verified identifiers point to different accounts. No account was selected."
            )
        case .identifierOwnershipConflict:
            return ImportAccountOutcomePresentation(
                label: "Identifier ownership conflict",
                explanation: "Verified identifier ownership changed or conflicted before confirmation. No financial history was written."
            )
        case .staleAccountChoice:
            return ImportAccountOutcomePresentation(
                label: "Account choice out of date",
                explanation: "The selected account is no longer available or eligible. Prepare or review the import again."
            )
        case .staleProviderGeneration:
            return ImportAccountOutcomePresentation(
                label: "Preparation out of date",
                explanation: "Persistence changed after preparation. Prepare the import again."
            )
        case .unavailable:
            return unavailable
        }
    }

    static func presentation(
        accountDecisionCode: String
    ) -> ImportAccountOutcomePresentation {
        guard let decision = ImportAttemptAccountDecision(rawValue: accountDecisionCode) else {
            return unavailable
        }
        switch decision {
        case .matchedExisting:
            return presentation(for: .matchedExisting)
        case .userSelectedExisting:
            return presentation(for: .userSelectedExisting)
        case .createdNew:
            return presentation(for: .createdNew)
        case .selectedExisting:
            return ImportAccountOutcomePresentation(
                label: "Existing account used",
                explanation: "This older record does not distinguish an automatic match from an explicit choice."
            )
        case .resolvedOrCreated:
            return ImportAccountOutcomePresentation(
                label: "Account association completed",
                explanation: "This older record does not distinguish account matching from account creation."
            )
        case .noFinancialMutation, .sideEffectsMayExist:
            return unavailable
        }
    }

    static func presentation(
        outcomeCode: String
    ) -> ImportAccountOutcomePresentation {
        guard let outcome = ImportAttemptOutcome(rawValue: outcomeCode) else {
            return unavailable
        }
        switch outcome {
        case .accountChoiceRequired:
            return presentation(for: .choiceRequired)
        case .identifierOwnershipConflict:
            return presentation(for: .identifierOwnershipConflict)
        case .identityAmbiguity:
            return presentation(for: .identityAmbiguous)
        case .identityConflict:
            return presentation(for: .identityConflict)
        case .staleAccountChoice:
            return presentation(for: .staleAccountChoice)
        case .staleProviderGeneration:
            return presentation(for: .staleProviderGeneration)
        default:
            return unavailable
        }
    }

    static func presentation(
        outcomeCode: String,
        accountDecisionCode: String
    ) -> ImportAccountOutcomePresentation {
        guard let outcome = ImportAttemptOutcome(rawValue: outcomeCode) else {
            return unavailable
        }
        switch outcome {
        case .successfulImport, .partialImportCommitted:
            return presentation(accountDecisionCode: accountDecisionCode)
        default:
            return presentation(outcomeCode: outcomeCode)
        }
    }

    private static let unavailable = ImportAccountOutcomePresentation(
        label: "Account outcome unavailable",
        explanation: "Detailed account-association information is unavailable."
    )
}

extension ImportPersistenceCoordinating {
    func recordValidationFailure(fileName: String, transactionCount: Int) -> String? { nil }
    func recordSourceSnapshotRejection(_ kind: SourceSnapshotRejectionKind) -> SourceSnapshotRejectionRecord {
        .auditWriteUnavailable
    }
    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? {
        throw ImportPersistenceCoordinationError.fingerprintRequired
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice? = nil
    ) throws -> ImportPersistenceResult {
        throw ImportPersistenceCoordinationError.fingerprintRequired
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        guard let authority = fingerprintSet.duplicateAuthority else {
            throw ImportPersistenceCoordinationError.invalidFingerprint
        }
        return try persistValidatedImport(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            fingerprint: ExactStatementFingerprint(
                algorithm: authority.algorithm,
                digest: authority.digest,
                byteCount: authority.byteCount
            ),
            accountChoice: accountChoice,
            providerGeneration: providerGeneration
        )
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        try persistValidatedImport(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            fingerprint: fingerprint,
            accountChoice: accountChoice
        )
    }

    func reviewValidatedImport(
        financialDocument: FinancialDocument,
        validation: ImportValidationResult
    ) throws -> ImportIdentityReview {
        .unavailable
    }

    func reviewPartialImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> PartialImportReviewResult {
        .unsupportedEvidence
    }

    func reviewPartialImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> PartialImportReviewResult {
        guard let authority = fingerprintSet.duplicateAuthority else {
            throw ImportPersistenceCoordinationError.invalidFingerprint
        }
        return try reviewPartialImport(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            fingerprint: ExactStatementFingerprint(
                algorithm: authority.algorithm,
                digest: authority.digest,
                byteCount: authority.byteCount
            ),
            accountChoice: accountChoice,
            providerGeneration: providerGeneration
        )
    }

    func persistReviewedPartialImport(
        _ plan: ReviewedPartialImportPlanDTO
    ) throws -> ImportPersistenceResult {
        .skipped
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult {
        try persistValidatedImport(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation
        )
    }
}

enum ImportPersistenceCoordinationError: Error, LocalizedError, Equatable {
    case resolvedAccountUnavailable
    case resolvedAccountWorkspaceMismatch
    case resolvedWorkspaceUnavailable
    case ambiguousIdentity
    case conflictingIdentity
    case explicitChoiceRequired
    case selectedAccountUnavailable
    case selectedAccountWorkspaceMismatch
    case selectedAccountAlreadyIdentified
    case ineligibleIdentifierSet
    case fingerprintRequired
    case invalidFingerprint
    case identifierOwnershipConflict
    case staleIdentityDecision
    case staleProviderGeneration
    case reviewedPartialPlanStale
    case retryableContention
    case persistenceUnavailable
    case repositoryIntegrityConflict
    case transactionEventBlock
    case unclassified

    var errorDescription: String? {
        switch self {
        case .resolvedAccountUnavailable:
            return "Resolved identity references an unavailable account."
        case .resolvedAccountWorkspaceMismatch:
            return "Resolved identity does not belong to the persistence workspace."
        case .resolvedWorkspaceUnavailable:
            return "Resolved identity references an unavailable workspace."
        case .ambiguousIdentity:
            return "Financial identity is ambiguous; import was not persisted."
        case .conflictingIdentity:
            return "Financial identity conflicts across accounts; import was not persisted."
        case .explicitChoiceRequired:
            return "An explicit import account choice is required."
        case .selectedAccountUnavailable:
            return "The selected account is no longer available."
        case .selectedAccountWorkspaceMismatch:
            return "The selected account does not belong to the persistence workspace."
        case .selectedAccountAlreadyIdentified:
            return "The selected account is no longer eligible for identifier attachment."
        case .ineligibleIdentifierSet:
            return "The import no longer has exactly one eligible verified identifier."
        case .fingerprintRequired:
            return "Confirmed import persistence requires an exact-content fingerprint."
        case .invalidFingerprint:
            return "The prepared exact-content fingerprint is invalid."
        case .identifierOwnershipConflict:
            return "Verified identifier ownership conflicts; no financial history was written."
        case .staleIdentityDecision:
            return "The prepared account decision is no longer current."
        case .staleProviderGeneration:
            return "Persistence changed after preparation; prepare the import again."
        case .reviewedPartialPlanStale:
            return "The reviewed partial-import plan is no longer current. Prepare the import again."
        case .retryableContention:
            return "Persistence is busy. Retry confirmation."
        case .persistenceUnavailable:
            return "Persistence is unavailable. No financial history was written."
        case .repositoryIntegrityConflict:
            return "Repository integrity prevented confirmation. No financial history was written."
        case .transactionEventBlock:
            return "Supported transaction-event evidence requires review."
        case .unclassified:
            return "The confirmed import outcome is unavailable."
        }
    }

}

struct ImportPersistenceCommitFailure: Error, LocalizedError {
    let originalError: Error
    let importAttemptId: String?
    let accountOutcome: ImportAccountOutcome

    init(
        originalError: Error,
        importAttemptId: String?,
        accountOutcome: ImportAccountOutcome = .unavailable
    ) {
        self.originalError = originalError
        self.importAttemptId = importAttemptId
        self.accountOutcome = accountOutcome
    }

    var errorDescription: String? {
        originalError.localizedDescription
    }
}

final class DefaultImportPersistenceCoordinator: ImportPersistenceCoordinating {

    private let databaseProviderProvider: () -> DatabaseProvider
    private let mapper: ImportPersistenceMapper
    private let developerConsole: DeveloperConsole?

    init(
        databaseProviderProvider: @escaping () -> DatabaseProvider = { DatabaseProvider.shared },
        mapper: ImportPersistenceMapper = ImportPersistenceMapper(),
        developerConsole: DeveloperConsole? = .shared
    ) {
        self.databaseProviderProvider = databaseProviderProvider
        self.mapper = mapper
        self.developerConsole = developerConsole
    }

    convenience init(
        databaseProvider: DatabaseProvider,
        mapper: ImportPersistenceMapper = ImportPersistenceMapper()
    ) {
        self.init(databaseProviderProvider: { databaseProvider }, mapper: mapper)
    }

    convenience init(
        workspaceRepo: WorkspaceRepository,
        accountRepo: AccountRepository,
        importSessionRepo: ImportSessionRepository,
        transactionRepo: TransactionRepository,
        confirmedImportRepo: ConfirmedImportRepository = PlaceholderConfirmedImportRepo(),
        generationToken: ProviderGenerationToken = ProviderGenerationToken(),
        mapper: ImportPersistenceMapper = ImportPersistenceMapper(),
        developerConsole: DeveloperConsole? = .shared
    ) {
        let provider = DatabaseProvider(
            workspaceRepo: workspaceRepo,
            transactionRepo: transactionRepo,
            accountRepo: accountRepo,
            importSessionRepo: importSessionRepo,
            confirmedImportRepo: confirmedImportRepo,
            generationToken: generationToken
        )
        self.init(databaseProviderProvider: { provider }, mapper: mapper, developerConsole: developerConsole)
    }

    private func makeConfirmedPlan(
        provider: DatabaseProvider,
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ConfirmedImportPlanDTO {
        let resolution = try resolver(accountRepo: provider.accountRepo).resolve(
            workspaceId: mapper.workspaceId,
            identifiers: financialDocument.financialIdentifiers
        )
        let advisoryIdentity: ConfirmedImportAdvisoryIdentityDTO
        let confirmedChoice: ConfirmedImportAccountChoiceDTO
        let selectedAccountId: String
        switch resolution {
        case .resolved(let accountId):
            advisoryIdentity = .resolved(accountId: accountId)
            confirmedChoice = .useExistingAccount(accountId: accountId)
            selectedAccountId = accountId
        case .noMatch:
            advisoryIdentity = .noMatch
            let proposedID = "account-\(importSession.id.uuidString.lowercased())"
            if !FinancialIdentityResolver.strongVerifiedIdentifiers(from: financialDocument.financialIdentifiers).isEmpty {
                switch accountChoice {
                case .useExistingAccount(let accountId):
                    confirmedChoice = .useExistingAccount(accountId: accountId)
                    selectedAccountId = accountId
                case .createNewAccount:
                    confirmedChoice = .createProposedAccount
                    selectedAccountId = proposedID
                case nil:
                    confirmedChoice = .unspecified
                    selectedAccountId = proposedID
                }
            } else {
                confirmedChoice = .createProposedAccount
                selectedAccountId = proposedID
            }
        case .ambiguous:
            advisoryIdentity = .ambiguous
            confirmedChoice = .unspecified
            selectedAccountId = "account-\(importSession.id.uuidString.lowercased())"
        case .conflict:
            advisoryIdentity = .conflict
            confirmedChoice = .unspecified
            selectedAccountId = "account-\(importSession.id.uuidString.lowercased())"
        }
        let plan = try mapper.confirmedImportPlan(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            fingerprintSet: fingerprintSet,
            providerGeneration: providerGeneration,
            advisoryIdentity: advisoryIdentity,
            accountChoice: confirmedChoice,
            selectedAccountId: selectedAccountId
        )
        try validate(confirmedPlan: plan)
        return plan
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        try persistValidatedImport(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            accountChoice: nil
        )
    }

    func reviewValidatedImport(
        financialDocument: FinancialDocument,
        validation: ImportValidationResult
    ) throws -> ImportIdentityReview {
        guard validation.passed else { return .unavailable }

        let provider = databaseProviderProvider()
        let workspaceId = mapper.workspaceId
        let resolution = try resolver(accountRepo: provider.accountRepo).resolve(
            workspaceId: workspaceId,
            identifiers: financialDocument.financialIdentifiers
        )
        switch resolution {
        case .resolved(let accountId):
            return .matchedExisting(accountId: accountId)
        case .ambiguous:
            return .ambiguous
        case .conflict:
            return .conflict
        case .noMatch:
            break
        }

        guard eligibleIdentifier(in: financialDocument) != nil else {
            return .unavailable
        }

        let eligibleAccountIds = try provider.accountRepo.accounts(workspaceId: workspaceId)
            .filter { try provider.accountRepo.identifiers(accountId: $0.id, workspaceId: workspaceId).isEmpty }
            .map(\.id)
            .sorted()
        developerConsole?.info(.import, "Identity review available", metadata: ["eligibleAccounts": "\(eligibleAccountIds.count)"])
        return .choiceRequired(eligibleAccountIds: eligibleAccountIds)
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult {
        guard !validation.passed else {
            throw ImportPersistenceCoordinationError.fingerprintRequired
        }
        return .skipped
    }

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement? {
        try validate(fingerprint: fingerprint)
        return try databaseProviderProvider().importSessionRepo.priorImportedStatement(
            algorithm: fingerprint.algorithm,
            fingerprint: fingerprint.digest
        ).map(Self.previousImport(from:))
    }

    func recordValidationFailure(fileName: String, transactionCount: Int) -> String? {
        do {
            let provider = databaseProviderProvider()
            guard try provider.workspaceRepo.workspace(id: mapper.workspaceId) != nil else { return nil }
            return recordAttempt(
                provider: provider,
                outcome: .validationFailure, coverage: .unsupportedOrUnevaluated,
                decision: .noFinancialMutation, guidance: .correctValidationAndRetry,
                persistence: .rejectedRecorded, transactionCount: transactionCount
            )
        } catch {
            return nil
        }
    }

    func recordSourceSnapshotRejection(_ kind: SourceSnapshotRejectionKind) -> SourceSnapshotRejectionRecord {
        let provider = databaseProviderProvider()
        let outcome: ImportAttemptOutcome = kind == .acquisitionFailed
            ? .sourceSnapshotAcquisitionFailed
            : .sourceSnapshotIntegrityFailed
        guard let attemptID = recordAttempt(
            provider: provider,
            outcome: outcome,
            coverage: .unsupportedOrUnevaluated,
            decision: .noFinancialMutation,
            guidance: .prepareAgain,
            persistence: .rejectedRecorded,
            transactionCount: 0
        ) else {
            return .auditWriteUnavailable
        }
        return SourceSnapshotRejectionRecord(
            importAttemptId: attemptID,
            persistence: .rejectedRecorded
        )
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice? = nil
    ) throws -> ImportPersistenceResult {
        try persistValidatedImport(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            fingerprint: fingerprint,
            accountChoice: accountChoice,
            providerGeneration: databaseProviderProvider().generationToken
        )
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice? = nil,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        try persistValidatedImport(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            fingerprintSet: PreparedDocumentFingerprintSet(fingerprints: [
                VersionedDocumentFingerprint(
                    algorithm: fingerprint.algorithm,
                    digest: fingerprint.digest,
                    byteCount: fingerprint.byteCount,
                    isDuplicateAuthority: true
                )
            ]),
            accountChoice: accountChoice,
            providerGeneration: providerGeneration
        )
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice? = nil,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        guard validation.passed else {
            return .skipped
        }

        try validate(fingerprintSet: fingerprintSet)
        guard let authority = fingerprintSet.duplicateAuthority else {
            throw ImportPersistenceCoordinationError.invalidFingerprint
        }
        let fingerprint = ExactStatementFingerprint(
            algorithm: authority.algorithm,
            digest: authority.digest,
            byteCount: authority.byteCount
        )
        let provider = databaseProviderProvider()
        guard provider.persistenceState.isUsable else {
            throw ImportPersistenceCoordinationError.persistenceUnavailable
        }
        let plan = try makeConfirmedPlan(
            provider: provider,
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            fingerprintSet: fingerprintSet,
            accountChoice: accountChoice,
            providerGeneration: providerGeneration,
        )
        let repositoryResult = provider.confirmedImportRepo.commitConfirmedImport(plan)
        return try map(
            repositoryResult,
            provider: provider,
            plan: plan,
            fingerprint: fingerprint
        )
    }

    func reviewPartialImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> PartialImportReviewResult {
        try reviewPartialImport(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            fingerprintSet: PreparedDocumentFingerprintSet(fingerprints: [
                VersionedDocumentFingerprint(
                    algorithm: fingerprint.algorithm,
                    digest: fingerprint.digest,
                    byteCount: fingerprint.byteCount,
                    isDuplicateAuthority: true
                )
            ]),
            accountChoice: accountChoice,
            providerGeneration: providerGeneration
        )
    }

    func reviewPartialImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> PartialImportReviewResult {
        guard validation.passed else { return .unsupportedEvidence }
        try validate(fingerprintSet: fingerprintSet)
        let provider = databaseProviderProvider()
        guard provider.persistenceState.isUsable else {
            throw ImportPersistenceCoordinationError.persistenceUnavailable
        }
        let plan = try makeConfirmedPlan(
            provider: provider,
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            fingerprintSet: fingerprintSet,
            accountChoice: accountChoice,
            providerGeneration: providerGeneration
        )
        return provider.confirmedImportRepo.reviewPartialImport(plan)
    }

    func persistReviewedPartialImport(
        _ plan: ReviewedPartialImportPlanDTO
    ) throws -> ImportPersistenceResult {
        try validate(confirmedPlan: plan.basePlan)
        let provider = databaseProviderProvider()
        guard provider.persistenceState.isUsable else {
            throw ImportPersistenceCoordinationError.persistenceUnavailable
        }
        let result = provider.confirmedImportRepo.commitReviewedPartialImport(plan)
        switch result {
        case .partialCommitted(let receipt):
            let accountOutcome = ImportAccountOutcome.confirmed(
                advisoryIdentity: plan.basePlan.advisoryIdentity,
                accountChoice: plan.basePlan.accountChoice,
                eligibleIdentifierCount: plan.basePlan.identifiers.count
            )
            return ImportPersistenceResult(
                persisted: true,
                workspaceId: receipt.workspaceId,
                accountId: receipt.accountId,
                importSessionId: receipt.importSessionId,
                transactionCount: plan.importedCount,
                importAttemptId: plan.basePlan.historyTemplate.successfulAttempt.id,
                sourceRowCount: plan.sourceRowCount,
                recognizedExistingRowCount: plan.recognizedCount,
                isPartialImport: true,
                accountOutcome: accountOutcome
            )
        case .exactDuplicate:
            return try map(
                result,
                provider: provider,
                plan: plan.basePlan,
                fingerprint: ExactStatementFingerprint(
                    algorithm: plan.basePlan.historyTemplate.fingerprint.algorithm,
                    digest: plan.basePlan.historyTemplate.fingerprint.fingerprint,
                    byteCount: plan.basePlan.historyTemplate.document.sizeBytes ?? 0
                )
            )
        default:
            let attemptID = rejectedAttempt(
                provider: provider,
                result: result,
                count: plan.sourceRowCount,
                accountId: plan.existingAccountId
            )
            throw ImportPersistenceCommitFailure(
                originalError: coordinationError(for: result),
                importAttemptId: attemptID,
                accountOutcome: ImportAccountOutcome.rejected(result)
            )
        }
    }

    private func validate(fingerprint: ExactStatementFingerprint) throws {
        guard DocumentFingerprintDTO.approvedAlgorithms.contains(fingerprint.algorithm),
              fingerprint.digest.count == 64,
              fingerprint.digest.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
            throw ImportPersistenceCoordinationError.invalidFingerprint
        }
    }

    private func validate(fingerprintSet: PreparedDocumentFingerprintSet) throws {
        guard fingerprintSet.isValid,
              fingerprintSet.fingerprints.allSatisfy({
                  DocumentFingerprintDTO.approvedAlgorithms.contains($0.algorithm)
              }) else {
            throw ImportPersistenceCoordinationError.invalidFingerprint
        }
    }

    private func validate(confirmedPlan plan: ConfirmedImportPlanDTO) throws {
        do {
            try plan.historyTemplate.validateFingerprints()
        } catch {
            throw ImportPersistenceCoordinationError.invalidFingerprint
        }

        let history = plan.historyTemplate
        guard let sourceFormat = ImportPersistenceSourceFormat(
            mimeType: history.document.mimeType
        ),
        let duplicateAuthority = history.duplicateAuthorityFingerprint,
        duplicateAuthority.algorithm == sourceFormat.duplicateAuthorityAlgorithm,
        let rawTextFingerprint = history.fingerprints.first(where: {
            $0.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm
        }),
        history.document.legacyRawTextSHA256 == rawTextFingerprint.fingerprint,
        let sourceSize = history.document.sizeBytes,
        sourceSize >= 0 else {
            throw ImportPersistenceCoordinationError.invalidFingerprint
        }
    }

    nonisolated private static func previousImport(from dto: PriorImportedStatementDTO) -> PreviouslyImportedStatement {
        PreviouslyImportedStatement(
            importSessionId: dto.importSessionId,
            completedAtISO: dto.completedAtISO,
            transactionCount: dto.transactionCount,
            accountId: dto.accountId,
            accountDisplayName: dto.accountDisplayName
        )
    }

    private func resolver(accountRepo: AccountRepository) -> FinancialIdentityResolver {
        FinancialIdentityResolver(accountRepository: accountRepo, developerConsole: developerConsole)
    }

    private func eligibleIdentifier(in financialDocument: FinancialDocument) -> FinancialIdentifier? {
        let identifiers = financialDocument.financialIdentifiers.filter {
            $0.strength == .strong && $0.verificationState == .verified
        }
        guard identifiers.count == 1 else { return nil }
        return identifiers[0]
    }

    private func map(
        _ result: ConfirmedImportRepositoryResult,
        provider: DatabaseProvider,
        plan: ConfirmedImportPlanDTO,
        fingerprint: ExactStatementFingerprint
    ) throws -> ImportPersistenceResult {
        let count = plan.transactionTemplates.count
        switch result {
        case .committed(let receipt), .partialCommitted(let receipt):
            let accountOutcome = ImportAccountOutcome.confirmed(
                advisoryIdentity: plan.advisoryIdentity,
                accountChoice: plan.accountChoice,
                eligibleIdentifierCount: plan.identifiers.count
            )
            developerConsole?.info(.database, "Provider-owned confirmed import committed", metadata: ["transactions": "\(count)"])
            return ImportPersistenceResult(persisted: true, workspaceId: receipt.workspaceId, accountId: receipt.accountId, importSessionId: receipt.importSessionId, transactionCount: count, importAttemptId: plan.historyTemplate.successfulAttempt.id, accountOutcome: accountOutcome)
        case .exactDuplicate:
            let previous = try provider.importSessionRepo.priorImportedStatement(algorithm: fingerprint.algorithm, fingerprint: fingerprint.digest)
            let attemptID = recordAttempt(provider: provider, outcome: .exactStatementDuplicate, coverage: .evaluatedSupportedOnly, decision: .noFinancialMutation, guidance: .reviewPriorImport, persistence: .rejectedRecorded, transactionCount: previous?.transactionCount ?? count, accountId: previous?.accountId, relatedImportSessionId: previous?.importSessionId)
            if let previous {
                return ImportPersistenceResult(persisted: false, workspaceId: mapper.workspaceId, accountId: previous.accountId, importSessionId: previous.importSessionId, transactionCount: previous.transactionCount, previousImport: Self.previousImport(from: previous), importAttemptId: attemptID)
            }
            throw ImportPersistenceCommitFailure(originalError: ImportPersistenceCoordinationError.repositoryIntegrityConflict, importAttemptId: attemptID)
        case .repeatedIncomingEventEvidence:
            let attemptID = rejectedAttempt(provider: provider, result: result, count: count, accountId: nil)
            return ImportPersistenceResult(persisted: false, workspaceId: mapper.workspaceId, accountId: nil, importSessionId: nil, transactionCount: count, transactionEventBlock: .repeatedIncoming(count: 1), importAttemptId: attemptID)
        case .existingEventDuplicate:
            let attemptID = rejectedAttempt(provider: provider, result: result, count: count, accountId: nil)
            let eventCount = plan.transactionTemplates.filter { $0.eventEvidence != nil }.count
            return ImportPersistenceResult(persisted: false, workspaceId: mapper.workspaceId, accountId: nil, importSessionId: nil, transactionCount: count, transactionEventBlock: .existing(count: max(eventCount, 1)), importAttemptId: attemptID)
        case .eventOwnershipConflict:
            let attemptID = rejectedAttempt(provider: provider, result: result, count: count, accountId: nil)
            return ImportPersistenceResult(persisted: false, workspaceId: mapper.workspaceId, accountId: nil, importSessionId: nil, transactionCount: count, transactionEventBlock: .ownershipConflict, importAttemptId: attemptID)
        default:
            let attemptID = rejectedAttempt(provider: provider, result: result, count: count, accountId: nil)
            throw ImportPersistenceCommitFailure(
                originalError: coordinationError(for: result),
                importAttemptId: attemptID,
                accountOutcome: ImportAccountOutcome.rejected(result)
            )
        }
    }

    private func coordinationError(for result: ConfirmedImportRepositoryResult) -> ImportPersistenceCoordinationError {
        switch result {
        case .committed, .partialCommitted, .exactDuplicate:
            return .unclassified
        case .repeatedIncomingEventEvidence, .existingEventDuplicate, .eventOwnershipConflict:
            return .transactionEventBlock
        case .identityAmbiguous: return .ambiguousIdentity
        case .identityConflict: return .conflictingIdentity
        case .explicitAccountChoiceRequired: return .explicitChoiceRequired
        case .selectedAccountUnavailable: return .selectedAccountUnavailable
        case .selectedAccountIneligible: return .selectedAccountAlreadyIdentified
        case .selectedAccountWorkspaceMismatch: return .selectedAccountWorkspaceMismatch
        case .identifierOwnershipConflict: return .identifierOwnershipConflict
        case .staleIdentityDecision: return .staleIdentityDecision
        case .staleProviderGeneration: return .staleProviderGeneration
        case .reviewedPartialPlanStale: return .reviewedPartialPlanStale
        case .retryableContention: return .retryableContention
        case .persistenceUnavailable: return .persistenceUnavailable
        case .repositoryIntegrityConflict: return .repositoryIntegrityConflict
        }
    }

    private func rejectedAttempt(provider: DatabaseProvider, result: ConfirmedImportRepositoryResult, count: Int, accountId: String?) -> String? {
        let outcome: ImportAttemptOutcome
        let guidance: ImportAttemptGuidance
        switch result {
        case .repeatedIncomingEventEvidence: outcome = .repeatedEligibleIncomingEvidence; guidance = .supportedEventBlocked
        case .existingEventDuplicate: outcome = .existingEligibleAxisUPIEvent; guidance = .supportedEventBlocked
        case .eventOwnershipConflict: outcome = .transactionEventOwnershipConflict; guidance = .integrityReviewRequired
        case .explicitAccountChoiceRequired: outcome = .accountChoiceRequired; guidance = .integrityReviewRequired
        case .identityAmbiguous: outcome = .identityAmbiguity; guidance = .integrityReviewRequired
        case .identityConflict: outcome = .identityConflict; guidance = .integrityReviewRequired
        case .identifierOwnershipConflict: outcome = .identifierOwnershipConflict; guidance = .integrityReviewRequired
        case .selectedAccountUnavailable, .selectedAccountIneligible, .selectedAccountWorkspaceMismatch, .staleIdentityDecision: outcome = .staleAccountChoice; guidance = .integrityReviewRequired
        case .staleProviderGeneration: outcome = .staleProviderGeneration; guidance = .prepareAgain
        case .reviewedPartialPlanStale: outcome = .reviewedPartialPlanStale; guidance = .prepareAgain
        case .retryableContention: outcome = .sqliteContention; guidance = .prepareAgain
        default: outcome = .repositoryIntegrityConflict; guidance = .integrityReviewRequired
        }
        return recordAttempt(provider: provider, outcome: outcome, coverage: .evaluatedSupportedOnly, decision: .noFinancialMutation, guidance: guidance, persistence: .rejectedRecorded, transactionCount: count, accountId: accountId)
    }

    @discardableResult
    private func recordAttempt(provider: DatabaseProvider, outcome: ImportAttemptOutcome, coverage: ImportAttemptCoverage,
                               decision: ImportAttemptAccountDecision, guidance: ImportAttemptGuidance,
                               persistence: ImportAttemptPersistence, transactionCount: Int,
                               accountId: String? = nil, relatedImportSessionId: String? = nil) -> String? {
        let payload = ImportAttemptDTO(workspaceId: mapper.workspaceId,
            createdAtISO: ISO8601DateFormatter().string(from: Date()), outcomeCode: outcome.rawValue,
            coverageCode: coverage.rawValue, accountDecisionCode: decision.rawValue,
            guidanceCode: guidance.rawValue, persistenceCode: persistence.rawValue,
            transactionCount: transactionCount, accountId: accountId,
            relatedImportSessionId: relatedImportSessionId)
        guard (try? provider.workspaceRepo.workspace(id: mapper.workspaceId)) != nil else { return nil }
        return try? provider.importSessionRepo.recordImportAttempt(payload)
    }
}
