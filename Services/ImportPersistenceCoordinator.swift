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

    init(
        persisted: Bool,
        workspaceId: String?,
        accountId: String?,
        importSessionId: String?,
        transactionCount: Int,
        previousImport: PreviouslyImportedStatement? = nil,
        transactionEventBlock: TransactionEventBlock? = nil,
        importAttemptId: String? = nil
    ) {
        self.persisted = persisted
        self.workspaceId = workspaceId
        self.accountId = accountId
        self.importSessionId = importSessionId
        self.transactionCount = transactionCount
        self.previousImport = previousImport
        self.transactionEventBlock = transactionEventBlock
        self.importAttemptId = importAttemptId
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

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        accountChoice: ImportAccountChoice?
    ) throws -> ImportPersistenceResult

    func priorImportedStatement(fingerprint: ExactStatementFingerprint) throws -> PreviouslyImportedStatement?
    func recordValidationFailure(fileName: String, transactionCount: Int) -> String?

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
}

enum ImportAccountChoice: Equatable {
    case useExistingAccount(accountId: String)
    case createNewAccount
}

struct ImportIdentityReview: Equatable {
    let isAvailable: Bool
    let eligibleAccountIds: [String]

    static let unavailable = ImportIdentityReview(isAvailable: false, eligibleAccountIds: [])
}

extension ImportPersistenceCoordinating {
    func recordValidationFailure(fileName: String, transactionCount: Int) -> String? { nil }
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
    case retryableContention
    case persistenceUnavailable
    case repositoryIntegrityConflict

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
        case .retryableContention:
            return "Persistence is busy. Retry confirmation."
        case .persistenceUnavailable:
            return "Persistence is unavailable. No financial history was written."
        case .repositoryIntegrityConflict:
            return "Repository integrity prevented confirmation. No financial history was written."
        }
    }
}

struct ImportPersistenceCommitFailure: Error, LocalizedError {
    let originalError: Error
    let importAttemptId: String?

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
        guard case .noMatch = resolution,
              eligibleIdentifier(in: financialDocument) != nil else {
            return .unavailable
        }

        let eligibleAccountIds = try provider.accountRepo.accounts(workspaceId: workspaceId)
            .filter { try provider.accountRepo.identifiers(accountId: $0.id, workspaceId: workspaceId).isEmpty }
            .map(\.id)
            .sorted()
        developerConsole?.info(.import, "Identity review available", metadata: ["eligibleAccounts": "\(eligibleAccountIds.count)"])
        return ImportIdentityReview(isAvailable: true, eligibleAccountIds: eligibleAccountIds)
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
        guard validation.passed else {
            return .skipped
        }

        try validate(fingerprint: fingerprint)
        let provider = databaseProviderProvider()
        guard provider.persistenceState.isUsable else {
            throw ImportPersistenceCoordinationError.persistenceUnavailable
        }
        let workspaceId = mapper.workspaceId
        let resolution = try resolver(accountRepo: provider.accountRepo).resolve(
            workspaceId: workspaceId,
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
            fingerprint: fingerprint,
            providerGeneration: providerGeneration,
            advisoryIdentity: advisoryIdentity,
            accountChoice: confirmedChoice,
            selectedAccountId: selectedAccountId
        )
        let repositoryResult = provider.confirmedImportRepo.commitConfirmedImport(plan)
        return try map(
            repositoryResult,
            provider: provider,
            plan: plan,
            fingerprint: fingerprint
        )
    }

    private func validate(fingerprint: ExactStatementFingerprint) throws {
        guard fingerprint.algorithm == ExactStatementFingerprint.algorithm,
              fingerprint.digest.count == 64,
              fingerprint.digest.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
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
        case .committed(let receipt):
            developerConsole?.info(.database, "Provider-owned confirmed import committed", metadata: ["transactions": "\(count)"])
            return ImportPersistenceResult(persisted: true, workspaceId: receipt.workspaceId, accountId: receipt.accountId, importSessionId: receipt.importSessionId, transactionCount: count, importAttemptId: plan.historyTemplate.successfulAttempt.id)
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
            throw ImportPersistenceCommitFailure(originalError: coordinationError(for: result), importAttemptId: attemptID)
        }
    }

    private func coordinationError(for result: ConfirmedImportRepositoryResult) -> ImportPersistenceCoordinationError {
        switch result {
        case .identityAmbiguous: return .ambiguousIdentity
        case .identityConflict: return .conflictingIdentity
        case .explicitAccountChoiceRequired: return .explicitChoiceRequired
        case .selectedAccountUnavailable: return .selectedAccountUnavailable
        case .selectedAccountIneligible: return .selectedAccountAlreadyIdentified
        case .selectedAccountWorkspaceMismatch: return .selectedAccountWorkspaceMismatch
        case .identifierOwnershipConflict: return .identifierOwnershipConflict
        case .staleIdentityDecision: return .staleIdentityDecision
        case .staleProviderGeneration: return .staleProviderGeneration
        case .retryableContention: return .retryableContention
        case .persistenceUnavailable: return .persistenceUnavailable
        default: return .repositoryIntegrityConflict
        }
    }

    private func rejectedAttempt(provider: DatabaseProvider, result: ConfirmedImportRepositoryResult, count: Int, accountId: String?) -> String? {
        let outcome: ImportAttemptOutcome
        let guidance: ImportAttemptGuidance
        switch result {
        case .repeatedIncomingEventEvidence: outcome = .repeatedEligibleIncomingEvidence; guidance = .supportedEventBlocked
        case .existingEventDuplicate: outcome = .existingEligibleAxisUPIEvent; guidance = .supportedEventBlocked
        case .eventOwnershipConflict: outcome = .transactionEventOwnershipConflict; guidance = .integrityReviewRequired
        case .identityAmbiguous: outcome = .identityAmbiguity; guidance = .integrityReviewRequired
        case .identityConflict, .identifierOwnershipConflict: outcome = .identityConflict; guidance = .integrityReviewRequired
        case .selectedAccountUnavailable, .selectedAccountIneligible, .selectedAccountWorkspaceMismatch, .staleIdentityDecision: outcome = .staleAccountChoice; guidance = .integrityReviewRequired
        case .staleProviderGeneration: outcome = .staleProviderGeneration; guidance = .prepareAgain
        case .retryableContention: outcome = .sqliteContention; guidance = .retryConfirmation
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
