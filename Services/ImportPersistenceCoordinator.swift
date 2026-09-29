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
    let isEquivalentSupportingSource: Bool
    let isSalaryImport: Bool
    let isInvestmentImport: Bool
    let accountOutcome: ImportAccountOutcome
    let bankSections: [BankImportReceiptDTO.Section]

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
        isEquivalentSupportingSource: Bool = false,
        isSalaryImport: Bool = false,
        isInvestmentImport: Bool = false,
        accountOutcome: ImportAccountOutcome = .unavailable,
        bankSections: [BankImportReceiptDTO.Section] = []
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
        self.isEquivalentSupportingSource = isEquivalentSupportingSource
        self.isSalaryImport = isSalaryImport
        self.isInvestmentImport = isInvestmentImport
        self.accountOutcome = accountOutcome
        self.bankSections = bankSections
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
    func prepareInvestmentImport(financialDocument: FinancialDocument, importSession: ImportSession,
        fingerprintSet: PreparedDocumentFingerprintSet, providerGeneration: ProviderGenerationToken) throws -> InvestmentImportPlan
    func persistValidatedInvestmentImport(_ plan: InvestmentImportPlan) throws -> ImportPersistenceResult
    func persistValidatedSalaryImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult
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

    func reviewStatementEquivalence(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> StatementEquivalenceReviewResult
}

extension ImportPersistenceCoordinating {
    func prepareInvestmentImport(financialDocument: FinancialDocument, importSession: ImportSession,
        fingerprintSet: PreparedDocumentFingerprintSet, providerGeneration: ProviderGenerationToken) throws -> InvestmentImportPlan {
        throw ImportPersistenceCoordinationError.unclassified
    }
    func persistValidatedInvestmentImport(_ plan: InvestmentImportPlan) throws -> ImportPersistenceResult {
        throw ImportPersistenceCoordinationError.unclassified
    }
    func persistValidatedSalaryImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        throw ImportPersistenceCoordinationError.unclassified
    }
}

enum ImportCardInstrumentChoice: Equatable {
    case reuseExistingInstrument(instrumentId: String)
    case createNewInstrument(
        relationship: CardInstrumentRelationshipKind? = nil,
        relatedInstrumentId: String? = nil
    )

    var isComplete: Bool {
        switch self {
        case .reuseExistingInstrument(let id):
            return !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .createNewInstrument(let relationship, let relatedID):
            if relationship == nil { return relatedID == nil }
            return relatedID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }
}

/// A document-owned bank section can either reuse one eligible bank account or
/// propose a distinct account. It deliberately carries no transaction or
/// overlap decision: parent occurrence publication remains a separate atomic
/// operation.
enum ImportBankSectionChoice: Equatable {
    case useExistingAccount(accountId: String)
    case createNewAccount(displayName: String)

    var isComplete: Bool {
        switch self {
        case .useExistingAccount(let accountID):
            return !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .createNewAccount(let displayName):
            return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

enum ImportAccountChoice: Equatable {
    case useExistingAccount(accountId: String)
    case createNewAccount(displayName: String)
    case createNewCardLiabilityAccountAndInstrument(displayName: String)
    case useExistingCardLiabilityAccount(
        accountId: String,
        instrumentChoice: ImportCardInstrumentChoice
    )
    case useExistingCardLiabilityAccountSections(
        accountId: String,
        sectionChoices: [String: ImportCardInstrumentChoice]
    )
    /// Choices are keyed by a source-document-scoped bank section identifier.
    /// A missing key represents a matched section or an unresolved user choice;
    /// the review determines which before any future parent confirmation.
    case bankSections([String: ImportBankSectionChoice])

    var proposedAccountDisplayName: String? {
        switch self {
        case .createNewAccount(let name), .createNewCardLiabilityAccountAndInstrument(let name):
            return name
        case .bankSections:
            return nil
        default:
            return nil
        }
    }
}

struct BankSectionIdentityReview: Equatable, Sendable {
    let sectionID: String
    let product: String
    let sourceAccountLabel: String
    let period: DeclaredStatementPeriod?
    let transactionCount: Int
    let identityReview: ImportIdentityReview
}

indirect enum ImportIdentityReview: Equatable, Sendable {
    case unavailable
    case matchedExisting(accountId: String)
    case choiceRequired(eligibleAccountIds: [String])
    /// Axis credit-card statements carry account-level financial rows but no
    /// source-proven instrument sections. Keep that review boundary typed
    /// separately from the instrument-aware card choices used by Amex/CBQ.
    case liabilityAccountChoiceRequired(eligibleLiabilityAccountIds: [String])
    case ambiguous
    case conflict
    case cardChoiceRequired(eligibleLiabilityAccountIds: [String], matchedLiabilityAccountId: String? = nil)
    /// Relationship statements retain each source section's identity review.
    /// The array breaks the recursive value graph; a section review itself must
    /// never contain another bank-section aggregate.
    case bankSections([BankSectionIdentityReview])

    var eligibleAccountIds: [String] {
        switch self {
        case .choiceRequired(let values),
                .liabilityAccountChoiceRequired(let values),
                .cardChoiceRequired(let values, _):
            return values
        case .bankSections:
            return []
        default: return []
        }
    }

    var matchedCardLiabilityAccountId: String? {
        if case .cardChoiceRequired(_, let accountID) = self { return accountID }
        return nil
    }

    var requiresExplicitChoice: Bool {
        switch self {
        case .choiceRequired, .liabilityAccountChoiceRequired, .cardChoiceRequired: return true
        case .bankSections(let sections):
            return sections.contains { $0.identityReview.requiresExplicitChoice }
        default: return false
        }
    }

    var blocksConfirmation: Bool {
        switch self {
        case .choiceRequired, .liabilityAccountChoiceRequired, .cardChoiceRequired,
                .ambiguous, .conflict:
            return true
        case .bankSections(let sections):
            return sections.contains { $0.identityReview.blocksConfirmation }
        case .unavailable, .matchedExisting:
            return false
        }
    }

    var isBankSectionParent: Bool {
        if case .bankSections = self { return true }
        return false
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

    func reviewStatementEquivalence(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> StatementEquivalenceReviewResult {
        .notApplicable
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
    case bankSourceHeld(BankImportHoldDTO)
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
    case statementEquivalenceConflict
    case statementEquivalenceEvidenceUnavailable
    case equivalentFormatAlreadyRecorded
    case retryableContention
    case persistenceUnavailable
    case repositoryIntegrityConflict
    case transactionEventBlock
    case unclassified

    var errorDescription: String? {
        switch self {
        case .bankSourceHeld(let hold):
            let position = hold.sourceOrdinal.map { " at source row \($0)" } ?? ""
            return "The whole bank statement is held\(position): \(hold.reason.replacingOccurrences(of: "_", with: " ")). No account section was imported."
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
        case .statementEquivalenceConflict:
            return "The other-format statement covers the same period but its financial projection differs. No financial history was written."
        case .statementEquivalenceEvidenceUnavailable:
            return "Existing history overlaps this statement, but exact cross-format equivalence evidence is unavailable. No financial history was written."
        case .equivalentFormatAlreadyRecorded:
            return "This statement format is already represented in the equivalence group. No financial history was written."
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
        "Confirmed import persistence failed."
    }
}

final class DefaultImportPersistenceCoordinator: ImportPersistenceCoordinating {

    private let databaseProviderProvider: @MainActor () -> DatabaseProvider
    private let mapper: ImportPersistenceMapper
    private let developerConsole: DeveloperConsole?

    func prepareInvestmentImport(financialDocument: FinancialDocument, importSession: ImportSession,
        fingerprintSet: PreparedDocumentFingerprintSet, providerGeneration: ProviderGenerationToken) throws -> InvestmentImportPlan {
        let provider = databaseProviderProvider()
        guard provider.persistenceState.isUsable, provider.generationToken == providerGeneration,
              let evidence = financialDocument.investmentStatementEvidence,
              financialDocument.transactions.isEmpty, fingerprintSet.isValid,
              let bytes = fingerprintSet.fingerprints.first(where: { $0.algorithm == DocumentFingerprintDTO.sourceBytesSHA256Algorithm }),
              let raw = fingerprintSet.fingerprints.first(where: { $0.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm }) else {
            throw InvestmentError.invalidEvidence
        }
        let instant = ISO8601DateFormatter().string(from: importSession.importedAt)
        let sessionID = importSession.id.uuidString
        let suffix = sessionID.lowercased()
        let documentID = "document-\(suffix)", normalizedID = "normalized-document-\(suffix)"
        let fingerprints = fingerprintSet.fingerprints.enumerated().map { index, fingerprint in
            DocumentFingerprintDTO(id: "fingerprint-\(suffix)-\(index)", documentId: documentID,
                importSessionId: sessionID, algorithm: fingerprint.algorithm, fingerprint: fingerprint.digest,
                fingerprintData: nil, isDuplicateAuthority: fingerprint.isDuplicateAuthority, createdAtISO: instant)
        }
        let history = ConfirmedImportHistoryTemplateDTO(
            document: .init(id: documentID, workspaceId: mapper.workspaceId, importSessionId: sessionID,
                filename: importSession.fileName, mimeType: financialDocument.metadata.fileFormat == .pdf ? "application/pdf" : "text/csv",
                sizeBytes: bytes.byteCount, legacyRawTextSHA256: raw.digest, createdAtISO: instant),
            fingerprints: fingerprints,
            importSession: .init(id: sessionID, workspaceId: mapper.workspaceId, userVisibleName: importSession.fileName,
                startedAtISO: instant, validationStatus: "pending", readerVersion: nil,
                parserVersion: evidence.parserProfile + "@1", layoutVersion: nil),
            completedAtISO: instant,
            successfulAttempt: .init(workspaceId: mapper.workspaceId, createdAtISO: instant,
                outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
                coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
                accountDecisionCode: ImportAttemptAccountDecision.noFinancialMutation.rawValue,
                guidanceCode: ImportAttemptGuidance.importCompleted.rawValue,
                persistenceCode: ImportAttemptPersistence.committed.rawValue, transactionCount: 0,
                importSessionId: sessionID, documentId: documentID,
                sourceRowCount: evidence.scopes.reduce(0) { $0 + $1.positions.count }, importedTransactionCount: 0,
                recognizedExistingRowCount: 0, blockedRowCount: 0),
            normalizedDocument: .init(id: normalizedID, importSessionId: sessionID, documentId: documentID,
                profileId: evidence.parserProfile, profileVersion: "1"))
        let plan = InvestmentImportPlan(providerGeneration: providerGeneration,
            workspace: mapper.workspace(createdAt: importSession.importedAt), history: history, evidence: evidence,
            baseline: try provider.investmentRepo.snapshot(workspaceID: mapper.workspaceId), choices: .init())
        try plan.validate()
        return plan
    }

    func persistValidatedInvestmentImport(_ plan: InvestmentImportPlan) throws -> ImportPersistenceResult {
        let provider = databaseProviderProvider()
        guard provider.persistenceState.isUsable else { throw ImportPersistenceCoordinationError.persistenceUnavailable }
        switch provider.investmentRepo.commitCurrentHoldings(plan) {
        case .committed(let sessionID):
            return .init(persisted: true, workspaceId: mapper.workspaceId, accountId: nil,
                importSessionId: sessionID, transactionCount: 0,
                importAttemptId: plan.history.successfulAttempt.id,
                sourceRowCount: plan.evidence.scopes.reduce(0) { $0 + $1.positions.count }, isInvestmentImport: true)
        case .exactSourceDuplicate(let previous):
            let attemptID = recordAttempt(provider: provider, outcome: .exactStatementDuplicate,
                coverage: .evaluatedSupportedOnly, decision: .noFinancialMutation,
                guidance: .reviewPriorImport, persistence: .rejectedRecorded,
                transactionCount: 0, relatedImportSessionId: previous.importSessionId)
            return .init(persisted: false, workspaceId: mapper.workspaceId, accountId: nil,
                importSessionId: previous.importSessionId, transactionCount: 0,
                previousImport: Self.previousImport(from: previous), importAttemptId: attemptID, isInvestmentImport: true)
        case .rejected(let error): throw error
        case .staleProviderGeneration: throw ImportPersistenceCoordinationError.staleProviderGeneration
        case .retryableContention: throw ImportPersistenceCoordinationError.retryableContention
        case .persistenceUnavailable: throw ImportPersistenceCoordinationError.persistenceUnavailable
        case .repositoryIntegrityConflict: throw ImportPersistenceCoordinationError.unclassified
        }
    }

    init(
        databaseProviderProvider: @escaping @MainActor () -> DatabaseProvider = { DatabaseProvider.shared },
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
        cardRepo: CardRepository = PlaceholderCardRepo(),
        confirmedImportRepo: ConfirmedImportRepository = PlaceholderConfirmedImportRepo(),
        generationToken: ProviderGenerationToken = ProviderGenerationToken(),
        mapper: ImportPersistenceMapper = ImportPersistenceMapper(),
        developerConsole: DeveloperConsole? = .shared
    ) {
        let provider = DatabaseProvider(
            workspaceRepo: workspaceRepo,
            transactionRepo: transactionRepo,
            accountRepo: accountRepo,
            cardRepo: cardRepo,
            importSessionRepo: importSessionRepo,
            confirmedImportRepo: confirmedImportRepo,
            generationToken: generationToken
        )
        self.init(databaseProviderProvider: { provider }, mapper: mapper, developerConsole: developerConsole)
    }

    func persistValidatedSalaryImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        let provider = databaseProviderProvider()
        guard provider.persistenceState.isUsable,
              validation.passed,
              let evidence = financialDocument.salaryStatementEvidence,
              financialDocument.transactions.isEmpty,
              financialDocument.financialIdentifiers.isEmpty,
              fingerprintSet.isValid,
              let authority = fingerprintSet.duplicateAuthority,
              authority.algorithm == DocumentFingerprintDTO.sourceBytesSHA256Algorithm,
              let rawText = fingerprintSet.fingerprints.first(where: {
                  $0.algorithm == DocumentFingerprintDTO.rawTextSHA256Algorithm
              }) else {
            throw ImportPersistenceCoordinationError.unclassified
        }
        let importedAt = ISO8601DateFormatter().string(from: importSession.importedAt)
        let suffix = importSession.id.uuidString.lowercased()
        let sessionID = importSession.id.uuidString
        let documentID = "document-\(suffix)"
        let normalizedID = "normalized-document-\(suffix)"
        let statementID = "salary-statement-\(suffix)"
        let fingerprints = fingerprintSet.fingerprints.enumerated().map { index, fingerprint in
            DocumentFingerprintDTO(
                id: "fingerprint-\(suffix)-\(index)",
                documentId: documentID,
                importSessionId: sessionID,
                algorithm: fingerprint.algorithm,
                fingerprint: fingerprint.digest,
                fingerprintData: nil,
                isDuplicateAuthority: fingerprint.isDuplicateAuthority,
                createdAtISO: importedAt
            )
        }
        func componentDTO(_ component: SalaryComponent) throws -> SalaryComponentDTO {
            SalaryComponentDTO(
                id: "salary-component-\(suffix)-\(component.side.rawValue)-\(component.sourceOrdinal)",
                salaryStatementId: statementID,
                sideCode: component.side.rawValue,
                sourceOrdinal: component.sourceOrdinal,
                sourceLabel: component.sourceLabel,
                amountCurrency: component.money.currency.code,
                amountMinor: try component.money.minorUnits(),
                amountDecimal: try component.money.canonicalDecimalString()
            )
        }
        let statement = SalaryStatementDTO(
            id: statementID,
            workspaceId: mapper.workspaceId,
            documentId: documentID,
            importSessionId: sessionID,
            normalizedDocumentId: normalizedID,
            sourceFingerprintAlgorithm: authority.algorithm,
            sourceFingerprintDigest: authority.digest,
            sourceAuthorityCode: evidence.sourceAuthority.rawValue,
            parserProfileId: evidence.profileID,
            parserProfileVersion: evidence.profileVersion,
            financialPeriodISO: evidence.financialPeriod.canonical,
            printDateISO: evidence.printDate?.canonical,
            documentKindCode: evidence.kind.rawValue,
            nativeCurrency: evidence.nativeCurrency.code,
            printedEarningsMinor: try evidence.printedEarningsTotal.minorUnits(),
            printedEarningsDecimal: try evidence.printedEarningsTotal.canonicalDecimalString(),
            printedDeductionsMinor: try evidence.printedDeductionsTotal?.minorUnits(),
            printedDeductionsDecimal: try evidence.printedDeductionsTotal?.canonicalDecimalString(),
            printedNetMinor: try evidence.printedNet.minorUnits(),
            printedNetDecimal: try evidence.printedNet.canonicalDecimalString(),
            printedPaymentMinor: try evidence.printedPaymentTotal.minorUnits(),
            printedPaymentDecimal: try evidence.printedPaymentTotal.canonicalDecimalString(),
            createdAtISO: importedAt,
            components: try (evidence.earnings + evidence.deductions).map(componentDTO)
        )
        let document = ImportedDocumentDTO(
            id: documentID,
            workspaceId: mapper.workspaceId,
            importSessionId: sessionID,
            filename: importSession.fileName,
            mimeType: "application/pdf",
            sizeBytes: authority.byteCount,
            legacyRawTextSHA256: rawText.digest,
            createdAtISO: importedAt
        )
        let session = ImportSessionDTO(
            id: sessionID,
            workspaceId: mapper.workspaceId,
            userVisibleName: importSession.fileName,
            startedAtISO: importedAt,
            validationStatus: "pending",
            readerVersion: nil,
            parserVersion: "\(evidence.profileID)@\(evidence.profileVersion)",
            layoutVersion: nil
        )
        let attempt = ImportAttemptDTO(
            workspaceId: mapper.workspaceId,
            createdAtISO: importedAt,
            outcomeCode: ImportAttemptOutcome.successfulImport.rawValue,
            coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
            accountDecisionCode: ImportAttemptAccountDecision.noFinancialMutation.rawValue,
            guidanceCode: ImportAttemptGuidance.importCompleted.rawValue,
            persistenceCode: ImportAttemptPersistence.committed.rawValue,
            transactionCount: 0,
            importSessionId: sessionID,
            documentId: documentID,
            sourceRowCount: evidence.earnings.count + evidence.deductions.count,
            importedTransactionCount: 0,
            recognizedExistingRowCount: 0,
            blockedRowCount: 0
        )
        let plan = SalaryImportPlanDTO(
            providerGeneration: providerGeneration,
            workspace: mapper.workspace(createdAt: importSession.importedAt),
            history: ConfirmedImportHistoryTemplateDTO(
                document: document,
                fingerprints: fingerprints,
                importSession: session,
                completedAtISO: importedAt,
                successfulAttempt: attempt,
                normalizedDocument: NormalizedDocumentDTO(
                    id: normalizedID,
                    importSessionId: sessionID,
                    documentId: documentID,
                    profileId: evidence.profileID,
                    profileVersion: evidence.profileVersion
                )
            ),
            statement: statement
        )
        switch provider.salaryRepo.commitImportedSalary(plan) {
        case .committed(_, let persistedSessionID, _):
            return ImportPersistenceResult(
                persisted: true,
                workspaceId: mapper.workspaceId,
                accountId: nil,
                importSessionId: persistedSessionID,
                transactionCount: 0,
                importAttemptId: attempt.id,
                sourceRowCount: evidence.earnings.count + evidence.deductions.count,
                recognizedExistingRowCount: 0,
                isSalaryImport: true,
                accountOutcome: .unavailable
            )
        case .exactSourceDuplicate(let previous):
            let attemptID = recordAttempt(
                provider: provider,
                outcome: .exactStatementDuplicate,
                coverage: .evaluatedSupportedOnly,
                decision: .noFinancialMutation,
                guidance: .reviewPriorImport,
                persistence: .rejectedRecorded,
                transactionCount: 0,
                relatedImportSessionId: previous.importSessionId
            )
            return ImportPersistenceResult(
                persisted: false,
                workspaceId: mapper.workspaceId,
                accountId: nil,
                importSessionId: previous.importSessionId,
                transactionCount: 0,
                previousImport: Self.previousImport(from: previous),
                importAttemptId: attemptID,
                isSalaryImport: true,
                accountOutcome: .unavailable
            )
        case .staleProviderGeneration:
            throw ImportPersistenceCoordinationError.staleProviderGeneration
        case .retryableContention:
            throw ImportPersistenceCoordinationError.retryableContention
        case .repositoryIntegrityConflict, .persistenceUnavailable:
            throw ImportPersistenceCoordinationError.unclassified
        }
    }

    private func persistBankImport(provider: DatabaseProvider, financialDocument: FinancialDocument,
                                   importSession: ImportSession, validation: ImportValidationResult,
                                   fingerprintSet: PreparedDocumentFingerprintSet, accountChoice: ImportAccountChoice?,
                                   providerGeneration: ProviderGenerationToken,
                                   fingerprint: ExactStatementFingerprint) throws -> ImportPersistenceResult {
        let review = try reviewValidatedImport(financialDocument: financialDocument, validation: validation)
        let plan: BankImportPlanDTO
        if financialDocument.bankStatementEvidence != nil {
            plan = try mapper.bankImportPlan(financialDocument: financialDocument, importSession: importSession,
                validation: validation, fingerprintSet: fingerprintSet, providerGeneration: providerGeneration,
                review: review, accountChoice: accountChoice)
        } else if let account = try standaloneBankOccurrenceAccount(financialDocument, validation: validation,
                    accountChoice: accountChoice, provider: provider) {
            plan = try mapper.standaloneBankImportPlan(financialDocument: financialDocument, importSession: importSession,
                validation: validation, fingerprintSet: fingerprintSet, providerGeneration: providerGeneration, account: account)
        } else {
            throw ImportPersistenceCoordinationError.explicitChoiceRequired
        }
        let result: BankImportRepositoryResult
        switch provider.confirmedImportRepo.reviewBankImport(plan) {
        case .ready(let reviewed): result = provider.confirmedImportRepo.commitBankImport(reviewed)
        case .exactDuplicate: result = .exactDuplicate
        case .held(let hold): result = .held(hold)
        case .staleProviderGeneration: result = .staleProviderGeneration
        case .persistenceUnavailable: result = .persistenceUnavailable
        }
        switch result {
        case .committed(let receipt):
            return .init(persisted: true, workspaceId: mapper.workspaceId, accountId: nil,
                importSessionId: receipt.importSessionID, transactionCount: receipt.importedCount,
                importAttemptId: plan.history.successfulAttempt.id, sourceRowCount: receipt.sourceCount,
                recognizedExistingRowCount: receipt.sourceCount-receipt.importedCount,
                isEquivalentSupportingSource: receipt.importedCount == 0 && receipt.sourceCount > 0,
                bankSections: receipt.sections)
        case .exactDuplicate:
            guard let previous = try provider.importSessionRepo.priorImportedStatement(algorithm: fingerprint.algorithm, fingerprint: fingerprint.digest) else {
                throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
            }
            let attemptID = recordAttempt(provider: provider, outcome: .exactStatementDuplicate,
                coverage: .evaluatedSupportedOnly, decision: .noFinancialMutation, guidance: .reviewPriorImport,
                persistence: .rejectedRecorded, transactionCount: 0, relatedImportSessionId: previous.importSessionId)
            return .init(persisted: false, workspaceId: mapper.workspaceId, accountId: nil,
                importSessionId: previous.importSessionId, transactionCount: 0,
                previousImport: Self.previousImport(from: previous), importAttemptId: attemptID)
        case .held(let hold):
            let attemptID = recordAttempt(provider: provider, outcome: .bankSourceOverlapHeld,
                coverage: .evaluatedSupportedOnly, decision: .noFinancialMutation, guidance: .integrityReviewRequired,
                persistence: .rejectedRecorded, transactionCount: 0)
            throw ImportPersistenceCommitFailure(originalError: ImportPersistenceCoordinationError.bankSourceHeld(hold), importAttemptId: attemptID)
        case .staleProviderGeneration: throw ImportPersistenceCoordinationError.staleProviderGeneration
        case .retryableContention: throw ImportPersistenceCoordinationError.retryableContention
        case .persistenceUnavailable: throw ImportPersistenceCoordinationError.persistenceUnavailable
        }
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
        // A parent with several bank accounts must never enter the legacy
        // single-account publication operation. The bank parent operation
        // owns its later atomic confirmation boundary.
        guard financialDocument.bankStatementEvidence == nil else {
            throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
        }
        if financialDocument.cardStatementEvidence != nil {
            return try makeCardConfirmedPlan(
                provider: provider,
                financialDocument: financialDocument,
                importSession: importSession,
                validation: validation,
                fingerprintSet: fingerprintSet,
                accountChoice: accountChoice,
                providerGeneration: providerGeneration
            )
        }
        if isCBQSourceObservationImport(financialDocument) {
            let candidates = try cbqCompatibleAccountIDs(provider: provider, financialDocument: financialDocument)
            let proposedID = "account-\(importSession.id.uuidString.lowercased())"
            let advisoryIdentity: ConfirmedImportAdvisoryIdentityDTO
            let confirmedChoice: ConfirmedImportAccountChoiceDTO
            let selectedAccountId: String
            switch candidates.count {
            case 0:
                advisoryIdentity = .noMatch
                if case .useExistingAccount(let selected)? = accountChoice {
                    confirmedChoice = .useExistingAccount(accountId: selected)
                    selectedAccountId = selected
                } else {
                    confirmedChoice = .createProposedAccount
                    selectedAccountId = proposedID
                }
            case 1:
                advisoryIdentity = .noMatch
                switch accountChoice {
                case .useExistingAccount(let selected):
                    confirmedChoice = .useExistingAccount(accountId: selected)
                    selectedAccountId = selected
                case .createNewAccount:
                    confirmedChoice = .createProposedAccount
                    selectedAccountId = proposedID
                case .createNewCardLiabilityAccountAndInstrument,
                     .useExistingCardLiabilityAccount,
                     .useExistingCardLiabilityAccountSections,
                     .bankSections:
                    confirmedChoice = .unspecified
                    selectedAccountId = proposedID
                case nil:
                    confirmedChoice = .useExistingAccount(accountId: candidates[0])
                    selectedAccountId = candidates[0]
                }
            default:
                advisoryIdentity = .ambiguous
                if case .useExistingAccount(let selected)? = accountChoice {
                    confirmedChoice = .useExistingAccount(accountId: selected)
                    selectedAccountId = selected
                } else if case .createNewAccount? = accountChoice {
                    confirmedChoice = .createProposedAccount
                    selectedAccountId = proposedID
                } else {
                    confirmedChoice = .unspecified
                    selectedAccountId = proposedID
                }
            }
            let plan = try mapper.confirmedImportPlan(
                financialDocument: financialDocument,
                importSession: importSession,
                validation: validation,
                fingerprintSet: fingerprintSet,
                providerGeneration: providerGeneration,
                advisoryIdentity: advisoryIdentity,
                accountChoice: confirmedChoice,
                selectedAccountId: selectedAccountId,
                proposedAccountDisplayName: accountChoice?.proposedAccountDisplayName
            )
            try validate(confirmedPlan: plan)
            return plan
        }
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
                case .createNewCardLiabilityAccountAndInstrument,
                     .useExistingCardLiabilityAccount,
                     .useExistingCardLiabilityAccountSections,
                     .bankSections:
                    confirmedChoice = .unspecified
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
            selectedAccountId: selectedAccountId,
            proposedAccountDisplayName: accountChoice?.proposedAccountDisplayName
        )
        try validate(confirmedPlan: plan)
        return plan
    }

    private func makeCardConfirmedPlan(
        provider: DatabaseProvider,
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ConfirmedImportPlanDTO {
        guard let evidence = financialDocument.cardStatementEvidence,
              let contract = CardStatementProfileContract(
                reconciliationRuleIdentifier: evidence.reconciliationRuleIdentifier
              ) else {
            throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
        }

        if contract == .axis {
            guard evidence.accountSourceIdentityObservations.isEmpty,
                  evidence.instrumentSections.isEmpty,
                  evidence.transactionAnnotations.allSatisfy({
                      $0.financialScope == .accountLevel && $0.documentScopedSectionID == nil
                  }) else {
                throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
            }
            let proposedAccountID = "account-\(importSession.id.uuidString.lowercased())"
            let selectedAccountID: String
            let confirmedAccountChoice: ConfirmedImportAccountChoiceDTO
            switch accountChoice {
            case .createNewAccount:
                selectedAccountID = proposedAccountID
                confirmedAccountChoice = .createProposedAccount
            case .useExistingAccount(let accountID):
                selectedAccountID = accountID
                confirmedAccountChoice = .useExistingAccount(accountId: accountID)
            case .createNewCardLiabilityAccountAndInstrument,
                 .useExistingCardLiabilityAccount,
                 .useExistingCardLiabilityAccountSections,
                 .bankSections:
                // Axis zero-section evidence has no instrument boundary. An
                // instrument-oriented choice is invalid rather than being
                // silently coerced into an account decision.
                throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
            case nil:
                selectedAccountID = proposedAccountID
                confirmedAccountChoice = .unspecified
            }
            let plan = try mapper.confirmedImportPlan(
                financialDocument: financialDocument,
                importSession: importSession,
                validation: validation,
                fingerprintSet: fingerprintSet,
                providerGeneration: providerGeneration,
                advisoryIdentity: .noMatch,
                accountChoice: confirmedAccountChoice,
                selectedAccountId: selectedAccountID,
                proposedAccountDisplayName: accountChoice?.proposedAccountDisplayName,
                cardAssociationAuthority: "user_confirmed",
                cardSectionChoices: [:],
                cardSectionAuthorities: [:],
                cardSectionRelationships: [:]
            )
            try validate(confirmedPlan: plan)
            return plan
        }

        let isAccountOnlyAmexZero = contract.isAmex &&
            financialDocument.transactions.isEmpty &&
            financialDocument.zeroActivityEvidence != nil &&
            evidence.instrumentSections.isEmpty
        guard evidence.accountSourceIdentityObservations.count == 1,
              (isAccountOnlyAmexZero || !evidence.instrumentSections.isEmpty),
              evidence.instrumentSections.allSatisfy({ $0.sourceIdentityObservations.count == 1 }) else {
            throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
        }
        let identityResolution = try resolver(accountRepo: provider.accountRepo).resolve(
            workspaceId: mapper.workspaceId,
            identifiers: financialDocument.financialIdentifiers
        )
        let advisoryIdentity: ConfirmedImportAdvisoryIdentityDTO
        switch identityResolution {
        case .resolved(let accountID): advisoryIdentity = .resolved(accountId: accountID)
        case .noMatch: advisoryIdentity = .noMatch
        case .ambiguous: advisoryIdentity = .ambiguous
        case .conflict: advisoryIdentity = .conflict
        }
        let snapshot = try provider.cardRepo.snapshot(workspaceId: mapper.workspaceId)
        let accountObservation = evidence.accountSourceIdentityObservations[0]
        let eligibleAccountIDs = Set(try provider.accountRepo.accounts(workspaceId: mapper.workspaceId)
            .filter {
                $0.accountType == "credit_card" &&
                    $0.nativeCurrency == evidence.nativeCurrency.code &&
                    $0.institutionId == financialDocument.metadata.institution.rawValue
            }.map(\.id))
        let accountCandidates = Set(snapshot.sourceObservations.filter {
            eligibleAccountIDs.contains($0.subjectId) &&
            $0.subjectKind == CardSourceIdentitySubject.liabilityAccount.rawValue &&
            $0.associationAuthority == "user_confirmed" &&
            $0.observationKind == accountObservation.kind.rawValue &&
            $0.sourceValue == accountObservation.value
        }.map(\.subjectId))
        var mappingsByAccount = [String: [String: [String]]]()
        for accountID in accountCandidates.sorted() {
            // Preserve the account candidate even when a source-proven Amex
            // zero statement truthfully has no instrument sections to map.
            mappingsByAccount[accountID] = [:]
            for section in evidence.instrumentSections {
                let incoming = section.sourceIdentityObservations[0]
                let instruments = Set(snapshot.sectionObservations.compactMap { observation -> String? in
                    guard observation.associationAuthority == "user_confirmed",
                          observation.observationKind == incoming.kind.rawValue,
                          observation.sourceValue == incoming.value,
                          let durableSection = snapshot.sections.first(where: {
                              $0.id == observation.cardStatementSectionId
                          }),
                          snapshot.instruments.contains(where: {
                              $0.id == durableSection.instrumentId && $0.liabilityAccountId == accountID
                          }) else { return nil }
                    return durableSection.instrumentId
                }).sorted()
                mappingsByAccount[accountID, default: [:]][section.documentScopedSectionID] = instruments
            }
        }

        let proposedAccountID = "account-\(importSession.id.uuidString.lowercased())"
        let selectedAccountID: String
        let confirmedAccountChoice: ConfirmedImportAccountChoiceDTO
        var accountAssociationAuthority = "user_confirmed"
        var sectionChoices = [String: ConfirmedCardInstrumentChoiceDTO]()
        var sectionAuthorities = [String: String]()
        var sectionRelationships = [String: (kind: CardInstrumentRelationshipKind, relatedInstrumentId: String)]()
        switch accountChoice {
        case .createNewCardLiabilityAccountAndInstrument:
            selectedAccountID = proposedAccountID
            confirmedAccountChoice = .createProposedAccount
            for section in evidence.instrumentSections {
                sectionChoices[section.documentScopedSectionID] = .createProposedInstrument
                sectionAuthorities[section.documentScopedSectionID] = "user_confirmed"
            }
        case .useExistingCardLiabilityAccount(let accountID, let choice):
            guard evidence.instrumentSections.count == 1, choice.isComplete else {
                throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
            }
            selectedAccountID = accountID
            confirmedAccountChoice = .useExistingAccount(accountId: accountID)
            let sectionID = evidence.instrumentSections[0].documentScopedSectionID
            sectionAuthorities[sectionID] = "user_confirmed"
            switch choice {
            case .reuseExistingInstrument(let instrumentID):
                sectionChoices[sectionID] = .useExistingInstrument(instrumentId: instrumentID)
            case .createNewInstrument(let relationship, let related):
                sectionChoices[sectionID] = .createProposedInstrument
                if let relationship, let related {
                    sectionRelationships[sectionID] = (relationship, related)
                }
            }
        case .useExistingCardLiabilityAccountSections(let accountID, let choices):
            guard Set(choices.keys) == Set(evidence.instrumentSections.map(\.documentScopedSectionID)),
                  choices.values.allSatisfy(\.isComplete) else {
                throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
            }
            selectedAccountID = accountID
            confirmedAccountChoice = .useExistingAccount(accountId: accountID)
            for section in evidence.instrumentSections {
                let sectionID = section.documentScopedSectionID
                guard let choice = choices[sectionID] else {
                    throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
                }
                sectionAuthorities[sectionID] = "user_confirmed"
                switch choice {
                case .reuseExistingInstrument(let instrumentID):
                    sectionChoices[sectionID] = .useExistingInstrument(instrumentId: instrumentID)
                case .createNewInstrument(let relationship, let related):
                    sectionChoices[sectionID] = .createProposedInstrument
                    if let relationship, let related {
                        sectionRelationships[sectionID] = (relationship, related)
                    }
                }
            }
        case .bankSections:
            throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
        case nil where mappingsByAccount.filter({ _, mapping in
            let resolved = evidence.instrumentSections.compactMap {
                mapping[$0.documentScopedSectionID]?.count == 1
                    ? mapping[$0.documentScopedSectionID]?.first
                    : nil
            }
            return resolved.count == evidence.instrumentSections.count &&
                Set(resolved).count == evidence.instrumentSections.count
        }).count == 1:
            guard let resolved = mappingsByAccount.first(where: { _, mapping in
                let instruments = evidence.instrumentSections.compactMap {
                    mapping[$0.documentScopedSectionID]?.count == 1
                        ? mapping[$0.documentScopedSectionID]?.first
                        : nil
                }
                return instruments.count == evidence.instrumentSections.count &&
                    Set(instruments).count == evidence.instrumentSections.count
            }) else {
                throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
            }
            selectedAccountID = resolved.key
            confirmedAccountChoice = .useExistingAccount(accountId: resolved.key)
            accountAssociationAuthority = "prior_user_confirmed_mapping"
            for section in evidence.instrumentSections {
                let sectionID = section.documentScopedSectionID
                guard let resolvedInstrumentIDs = resolved.value[sectionID],
                      resolvedInstrumentIDs.count == 1,
                      let resolvedInstrumentID = resolvedInstrumentIDs.first else {
                    throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
                }
                sectionChoices[sectionID] = .useExistingInstrument(
                    instrumentId: resolvedInstrumentID
                )
                sectionAuthorities[sectionID] = "prior_user_confirmed_mapping"
            }
        default:
            selectedAccountID = proposedAccountID
            confirmedAccountChoice = .unspecified
            for section in evidence.instrumentSections {
                sectionChoices[section.documentScopedSectionID] = .unspecified
                sectionAuthorities[section.documentScopedSectionID] = "user_confirmed"
            }
        }
        let plan = try mapper.confirmedImportPlan(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            fingerprintSet: fingerprintSet,
            providerGeneration: providerGeneration,
            advisoryIdentity: advisoryIdentity,
            accountChoice: confirmedAccountChoice,
            selectedAccountId: selectedAccountID,
            proposedAccountDisplayName: accountChoice?.proposedAccountDisplayName,
            cardAssociationAuthority: accountAssociationAuthority,
            cardSectionChoices: sectionChoices,
            cardSectionAuthorities: sectionAuthorities,
            cardSectionRelationships: sectionRelationships
        )
        try validate(confirmedPlan: plan)
        return plan
    }

    private func isCBQSourceObservationImport(_ document: FinancialDocument) -> Bool {
        guard document.metadata.institution == .cbq,
              document.metadata.documentType == .bankAccount,
              ["QAR", "USD"].contains(document.bookedCurrency?.code),
              document.parserProfileVersion == "1",
              let profile = document.parserProfileID else { return false }
        return ([CBQCurrentAccountXLSParser.profileID] + CBQCurrentAccountPDFParser.bankProfileIDs).contains(profile)
    }

    private func cbqCompatibleAccountIDs(provider: DatabaseProvider, financialDocument: FinancialDocument) throws -> [String] {
        guard isCBQSourceObservationImport(financialDocument) else { return [] }
        let incomingMasks = financialDocument.cbqSourceIdentityObservations
        let incomingFull = FinancialIdentityResolver.strongVerifiedIdentifiers(from: financialDocument.financialIdentifiers)
            .first(where: { $0.kind == .institutionAccountId && $0.normalizedValue.count == 13 })?.normalizedValue
        guard (!incomingMasks.isEmpty && CBQSourceIdentityObservation.validatePair(incomingMasks)) || incomingFull != nil else { return [] }
        let records = try provider.accountRepo.cbqSourceIdentityRecords(workspaceId: mapper.workspaceId)
        let recordsByAccount = Dictionary(grouping: records, by: \.accountId)
        var compatible = [String]()
        for account in try provider.accountRepo.accounts(workspaceId: mapper.workspaceId) {
            guard account.institutionId == Institution.cbq.rawValue,
                  account.nativeCurrency == financialDocument.bookedCurrency?.code,
                  account.accountType == "bank" else { continue }
            let strongAccounts = try provider.accountRepo.identifiers(accountId: account.id, workspaceId: mapper.workspaceId)
                .filter { $0.scheme == FinancialIdentifierKind.institutionAccountId.rawValue && $0.identifier.count == 13 }
                .map(\.identifier)
            let durableMasks = try (recordsByAccount[account.id] ?? []).map {
                guard let kind = CBQSourceIdentityObservationKind(rawValue: $0.kind) else {
                    throw ImportPersistenceCoordinationError.repositoryIntegrityConflict
                }
                return try CBQSourceIdentityObservation(
                    kind: kind,
                    rawPattern: $0.pattern
                )
            }
            let matches: Bool
            if !incomingMasks.isEmpty {
                let fullMatch = strongAccounts.contains { candidate in incomingMasks.allSatisfy { $0.isCompatible(withFullAccountNumber: candidate) } }
                let maskMatch = Self.maskSetsCompatible(incomingMasks, durableMasks)
                matches = strongAccounts.isEmpty ? maskMatch :
                    (fullMatch && strongAccounts.allSatisfy { candidate in incomingMasks.allSatisfy { $0.isCompatible(withFullAccountNumber: candidate) } })
            } else if let incomingFull {
                let exactFull = strongAccounts.contains(incomingFull)
                let maskedMatch = durableMasks.count >= 2 && durableMasks.allSatisfy { $0.isCompatible(withFullAccountNumber: incomingFull) }
                matches = strongAccounts.isEmpty ? maskedMatch :
                    (exactFull && strongAccounts.allSatisfy { $0 == incomingFull })
            } else { matches = false }
            if matches { compatible.append(account.id) }
        }
        return compatible.sorted()
    }

    private static func maskSetsCompatible(_ lhs: [CBQSourceIdentityObservation], _ rhs: [CBQSourceIdentityObservation]) -> Bool {
        guard !rhs.isEmpty else { return false }
        return lhs.allSatisfy { incoming in
            rhs.filter { $0.kind == incoming.kind }.contains { durable in
                zip(incoming.pattern, durable.pattern).allSatisfy { left, right in left == "X" || right == "X" || left == right }
            }
        }
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
        if let evidence = financialDocument.bankStatementEvidence,
           evidence.isAccountRelationshipStatement {
            return try reviewBankStatementSections(
                evidence,
                financialDocument: financialDocument,
                provider: provider
            )
        }
        if isCBQSourceObservationImport(financialDocument) {
            let candidates = try cbqCompatibleAccountIDs(provider: provider, financialDocument: financialDocument)
            switch candidates.count {
            case 0: return .unavailable
            case 1: return .matchedExisting(accountId: candidates[0])
            default: return .choiceRequired(eligibleAccountIds: candidates)
            }
        }
        if let evidence = financialDocument.cardStatementEvidence {
            let snapshot = try provider.cardRepo.snapshot(workspaceId: mapper.workspaceId)
            if CardStatementProfileContract(
                reconciliationRuleIdentifier: evidence.reconciliationRuleIdentifier
            ) == .axis {
                guard financialDocument.metadata.institution == .axis,
                      financialDocument.metadata.documentType == .creditCard,
                      [.pdf, .xlsx].contains(financialDocument.metadata.fileFormat),
                      evidence.nativeCurrency.code == "INR",
                      evidence.accountSourceIdentityObservations.isEmpty,
                      evidence.instrumentSections.isEmpty else {
                    return .conflict
                }
                let eligible = try provider.accountRepo.accounts(workspaceId: mapper.workspaceId)
                    .filter {
                        $0.accountType == "credit_card" &&
                            $0.nativeCurrency == evidence.nativeCurrency.code &&
                            $0.institutionId == Institution.axis.rawValue
                    }
                    .map(\.id).sorted()
                // Institution/family similarity never auto-selects an Axis
                // liability account; the user must review this choice.
                return .liabilityAccountChoiceRequired(eligibleLiabilityAccountIds: eligible)
            }
            guard let accountObservation = evidence.accountSourceIdentityObservations.first,
                  evidence.instrumentSections.allSatisfy({ $0.sourceIdentityObservations.count == 1 }) else {
                return .unavailable
            }
            let eligible = try provider.accountRepo.accounts(workspaceId: mapper.workspaceId)
                .filter {
                    $0.accountType == "credit_card" &&
                        $0.nativeCurrency == evidence.nativeCurrency.code &&
                        $0.institutionId == financialDocument.metadata.institution.rawValue
                }
                .map(\.id).sorted()
            let eligibleAccountIDs = Set(eligible)
            let accountIDs = Set(snapshot.sourceObservations.filter {
                eligibleAccountIDs.contains($0.subjectId) &&
                $0.subjectKind == CardSourceIdentitySubject.liabilityAccount.rawValue &&
                $0.associationAuthority == "user_confirmed" &&
                $0.observationKind == accountObservation.kind.rawValue &&
                $0.sourceValue == accountObservation.value
            }.map(\.subjectId))
            guard accountIDs.count <= 1 else { return .conflict }
            let exactlyMappedAccounts = accountIDs.filter { accountID in
                let resolvedInstruments = evidence.instrumentSections.compactMap { incomingSection -> String? in
                    let incoming = incomingSection.sourceIdentityObservations[0]
                    let mapped = Set(snapshot.sectionObservations.compactMap { observation -> String? in
                        guard observation.associationAuthority == "user_confirmed",
                              observation.observationKind == incoming.kind.rawValue,
                              observation.sourceValue == incoming.value,
                              let section = snapshot.sections.first(where: {
                                  $0.id == observation.cardStatementSectionId
                              }),
                              snapshot.instruments.contains(where: {
                                  $0.id == section.instrumentId && $0.liabilityAccountId == accountID
                              }) else { return nil }
                        return section.instrumentId
                    })
                    return mapped.count == 1 ? mapped.first : nil
                }
                return resolvedInstruments.count == evidence.instrumentSections.count &&
                    Set(resolvedInstruments).count == evidence.instrumentSections.count
            }
            if exactlyMappedAccounts.count == 1, let accountID = exactlyMappedAccounts.first {
                return .matchedExisting(accountId: accountID)
            }
            if let accountID = accountIDs.first {
                // An unresolved card section cannot erase the already confirmed
                // liability owner and offer contradictory account destinations.
                return .cardChoiceRequired(eligibleLiabilityAccountIds: [accountID],
                    matchedLiabilityAccountId: accountID)
            }
            return .cardChoiceRequired(eligibleLiabilityAccountIds: eligible)
        }
        if financialDocument.metadata.institution == .axis,
           BankImportDecision.standaloneProfiles.contains(financialDocument.parserProfileID ?? ""),
           financialDocument.parserProfileVersion == BankImportDecision.supportedVersion(for: financialDocument.parserProfileID ?? "") {
            let identifiers = FinancialIdentityResolver.strongVerifiedIdentifiers(from: financialDocument.financialIdentifiers)
            let retained = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: mapper.workspaceId).sections
            if identifiers.count == 1, identifiers[0].kind == .institutionAccountId,
               identifiers[0].normalizedValue.range(of: #"^[0-9]{15}$"#, options: .regularExpression) != nil,
               retained.contains(where: { $0.parserProfileId == "axis.relationship-bank.pdf" }) {
                let eligible = try provider.accountRepo.accounts(workspaceId: mapper.workspaceId).filter {
                    $0.accountType == "bank" && $0.institutionId == Institution.axis.rawValue &&
                        $0.nativeCurrency == financialDocument.bookedCurrency?.code
                }
                return try reviewAxisMaskedBankAccount(mask: identifiers[0].normalizedValue, eligibleAccounts: eligible,
                    provider: provider, workspaceID: mapper.workspaceId, requiresMask: false)
            }
        }
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

        let sourceAccountType: String?
        switch financialDocument.metadata.documentType {
        case .bankAccount: sourceAccountType = "bank"
        case .creditCard: sourceAccountType = "credit_card"
        default: sourceAccountType = nil
        }
        guard let sourceAccountType, let sourceCurrency = financialDocument.bookedCurrency?.code else {
            return .unavailable
        }
        let sourceInstitution = financialDocument.metadata.institution == .unknown
            ? nil : financialDocument.metadata.institution.rawValue
        let eligibleAccountIds = try provider.accountRepo.accounts(workspaceId: workspaceId)
            .filter {
                guard $0.accountType == sourceAccountType, $0.nativeCurrency == sourceCurrency,
                      $0.institutionId == sourceInstitution else { return false }
                return try provider.accountRepo.identifiers(accountId: $0.id, workspaceId: workspaceId).isEmpty
            }
            .map(\.id)
            .sorted()
        developerConsole?.info(.import, "Identity review available", metadata: ["eligibleAccounts": "\(eligibleAccountIds.count)"])
        return .choiceRequired(eligibleAccountIds: eligibleAccountIds)
    }

    private func reviewBankStatementSections(
        _ evidence: BankStatementEvidence,
        financialDocument: FinancialDocument,
        provider: DatabaseProvider
    ) throws -> ImportIdentityReview {
        guard financialDocument.metadata.documentType == .bankAccount,
              let currency = financialDocument.bookedCurrency,
              financialDocument.metadata.institution == .axis || financialDocument.metadata.institution == .hdfc,
              !evidence.sections.isEmpty else {
            return .conflict
        }

        let workspaceID = mapper.workspaceId
        let eligibleAccounts = try provider.accountRepo.accounts(workspaceId: workspaceID)
            .filter {
                $0.accountType == "bank" &&
                    $0.nativeCurrency == currency.code &&
                    $0.institutionId == financialDocument.metadata.institution.rawValue
            }
        let eligibleByID = Dictionary(uniqueKeysWithValues: eligibleAccounts.map { ($0.id, $0) })
        let sectionReviews = try evidence.sections.sorted { $0.ordinal < $1.ordinal }.map { section in
            let review: ImportIdentityReview
            switch section.sourceIdentity {
            case .fullAccountNumber:
                let resolution = try resolver(accountRepo: provider.accountRepo).resolve(
                    workspaceId: workspaceID,
                    identifiers: section.financialIdentifiers
                )
                switch resolution {
                case .resolved(let accountID):
                    review = eligibleByID[accountID] == nil ? .conflict : .matchedExisting(accountId: accountID)
                case .ambiguous:
                    review = .ambiguous
                case .conflict:
                    review = .conflict
                case .noMatch:
                    review = .choiceRequired(eligibleAccountIds: try eligibleUnidentifiedBankAccountIDs(
                        eligibleAccounts,
                        provider: provider,
                        workspaceID: workspaceID
                    ))
                }
            case .maskedAccountNumber(let mask):
                review = try reviewAxisMaskedBankAccount(
                    mask: mask,
                    eligibleAccounts: eligibleAccounts,
                    provider: provider,
                    workspaceID: workspaceID
                )
            }
            return BankSectionIdentityReview(
                sectionID: section.id,
                product: section.productLabel,
                sourceAccountLabel: section.sourceIdentity.literal,
                period: section.period,
                transactionCount: section.transactionIDs.count,
                identityReview: review
            )
        }

        let matchedIDs = sectionReviews.compactMap { section -> String? in
            guard case .matchedExisting(let accountID) = section.identityReview else { return nil }
            return accountID
        }
        // Separate source accounts must retain separate destination ownership.
        // A future parent commit repeats this against explicit choices.
        guard Set(matchedIDs).count == matchedIDs.count else { return .conflict }
        return .bankSections(sectionReviews)
    }

    private func eligibleUnidentifiedBankAccountIDs(
        _ accounts: [AccountDTO],
        provider: DatabaseProvider,
        workspaceID: String
    ) throws -> [String] {
        try accounts.filter {
            try provider.accountRepo.identifiers(accountId: $0.id, workspaceId: workspaceID).isEmpty
        }.map(\.id).sorted()
    }

    private func reviewAxisMaskedBankAccount(
        mask: String,
        eligibleAccounts: [AccountDTO],
        provider: DatabaseProvider,
        workspaceID: String,
        requiresMask: Bool = true
    ) throws -> ImportIdentityReview {
        guard mask.count == 15,
              mask.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "X") }),
              !requiresMask || mask.contains("X") else {
            return .conflict
        }
        let retained = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: workspaceID).sections
        var matches = [String]()
        for account in eligibleAccounts {
            let identifiers = try provider.accountRepo.identifiers(accountId: account.id, workspaceId: workspaceID)
            let strongNumbers = identifiers.filter {
                $0.scheme == FinancialIdentifierKind.institutionAccountId.rawValue &&
                    $0.strength == FinancialIdentifierStrength.strong.rawValue &&
                    $0.verificationState == FinancialIdentifierVerificationState.verified.rawValue
            }.map(\.identifier)
            let observed = retained.filter { $0.accountId == account.id }.flatMap(\.identityPatterns)
                .filter { $0.kind == "axis_masked_account_number" }
            guard observed.allSatisfy({ BankImportDecision.mask(mask, matches: $0.pattern) }) else { continue }
            if !strongNumbers.isEmpty {
                // Contradictory strong identities cannot be overruled by an
                // older compatible mask.
                if strongNumbers.allSatisfy({ Self.axisMask(mask, isCompatibleWith: $0) }) { matches.append(account.id) }
                continue
            }
            if !observed.isEmpty && observed.allSatisfy({ BankImportDecision.mask(mask, matches: $0.pattern) }) {
                matches.append(account.id)
            }
        }
        let sortedMatches = matches.sorted()
        switch sortedMatches.count {
        case 0:
            return .choiceRequired(eligibleAccountIds: try eligibleUnidentifiedBankAccountIDs(
                eligibleAccounts.filter { account in
                    !retained.contains { $0.accountId == account.id && $0.identityPatterns.contains { $0.kind == "axis_masked_account_number" } }
                },
                provider: provider,
                workspaceID: workspaceID
            ))
        case 1:
            return .matchedExisting(accountId: sortedMatches[0])
        default:
            return .ambiguous
        }
    }

    private static func axisMask(_ mask: String, isCompatibleWith candidate: String) -> Bool {
        let normalized = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count == 15, normalized.allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
        return zip(mask, normalized).allSatisfy { printed, full in printed == "X" || printed == full }
    }

    /// Select the occurrence path from durable same-account relationship
    /// evidence, never from a loose date/amount resemblance. A held occurrence
    /// decision cannot fall back to ordinary transaction creation.
    private func standaloneBankOccurrenceAccount(_ document: FinancialDocument,
            validation: ImportValidationResult, accountChoice: ImportAccountChoice?,
            provider: DatabaseProvider) throws -> AccountDTO? {
        guard BankImportDecision.standaloneProfiles.contains(document.parserProfileID ?? ""),
              document.parserProfileVersion == BankImportDecision.supportedVersion(for: document.parserProfileID ?? "") else { return nil }
        let review = try reviewValidatedImport(financialDocument: document, validation: validation)
        let accountID: String
        switch review {
        case .matchedExisting(let id): accountID = id
        case .choiceRequired(let eligible):
            guard case .useExistingAccount(let id) = accountChoice, eligible.contains(id) else { return nil }
            accountID = id
        default: return nil
        }
        let sections = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: mapper.workspaceId).sections
        guard sections.contains(where: { $0.accountId == accountID && BankImportDecision.relationshipProfiles.contains($0.parserProfileId) }) else { return nil }
        guard let account = try provider.accountRepo.accounts(workspaceId: mapper.workspaceId).first(where: { $0.id == accountID }) else {
            throw ImportPersistenceCoordinationError.selectedAccountUnavailable
        }
        return account
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
        let standaloneOccurrenceAccount = try standaloneBankOccurrenceAccount(financialDocument,
            validation: validation, accountChoice: accountChoice, provider: provider)
        if financialDocument.bankStatementEvidence != nil || standaloneOccurrenceAccount != nil {
            return try persistBankImport(provider: provider, financialDocument: financialDocument,
                importSession: importSession, validation: validation, fingerprintSet: fingerprintSet,
                accountChoice: accountChoice, providerGeneration: providerGeneration, fingerprint: fingerprint)
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
        let repositoryResult: ConfirmedImportRepositoryResult
        if plan.bankStatementSectionPlan == nil, !plan.cbqSourceRows.isEmpty {
            switch provider.confirmedImportRepo.reviewCBQSourceOverlap(plan) {
            case .eligible(let reviewed):
                repositoryResult = provider.confirmedImportRepo.commitReviewedCBQSourceOverlap(reviewed)
            case .accountChoiceRequired:
                repositoryResult = .explicitAccountChoiceRequired
            case .identityConflict:
                repositoryResult = .identityConflict
            case .staleProviderGeneration:
                repositoryResult = .staleProviderGeneration
            case .blockedOrAmbiguousRows, .repositoryIntegrityConflict, .notApplicable:
                repositoryResult = .repositoryIntegrityConflict
            }
        } else {
            repositoryResult = provider.confirmedImportRepo.commitConfirmedImport(plan)
        }
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
        // Parent sections need their own atomic occurrence operation. Do not
        // construct a legacy single-account plan merely to ask about overlap.
        if financialDocument.bankStatementEvidence != nil { return .ordinaryFullImport }
        try validate(fingerprintSet: fingerprintSet)
        let provider = databaseProviderProvider()
        guard provider.persistenceState.isUsable else {
            throw ImportPersistenceCoordinationError.persistenceUnavailable
        }
        if try standaloneBankOccurrenceAccount(financialDocument, validation: validation, accountChoice: accountChoice, provider: provider) != nil {
            return .ordinaryFullImport
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

    func reviewStatementEquivalence(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> StatementEquivalenceReviewResult {
        guard validation.passed else { return .notApplicable }
        if financialDocument.bankStatementEvidence != nil { return .notApplicable }
        try validate(fingerprintSet: fingerprintSet)
        let provider = databaseProviderProvider()
        guard provider.persistenceState.isUsable else {
            throw ImportPersistenceCoordinationError.persistenceUnavailable
        }
        if try standaloneBankOccurrenceAccount(financialDocument, validation: validation, accountChoice: accountChoice, provider: provider) != nil {
            return .notApplicable
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
        return provider.confirmedImportRepo.reviewStatementEquivalence(plan)
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
        case .sourceOverlapCommitted(let receipt, let newTransactionCount):
            let accountOutcome = ImportAccountOutcome.confirmed(
                advisoryIdentity: plan.advisoryIdentity,
                accountChoice: plan.accountChoice,
                eligibleIdentifierCount: plan.identifiers.count
            )
            return ImportPersistenceResult(
                persisted: true, workspaceId: receipt.workspaceId, accountId: receipt.accountId,
                importSessionId: receipt.importSessionId, transactionCount: newTransactionCount,
                importAttemptId: plan.historyTemplate.successfulAttempt.id,
                sourceRowCount: plan.cbqSourceRows.count,
                recognizedExistingRowCount: plan.cbqSourceRows.count - newTransactionCount,
                accountOutcome: accountOutcome
            )
        case .equivalentSourceRecorded(let receipt):
            developerConsole?.info(.database, "Equivalent supporting statement source recorded", metadata: ["transactions": "0"])
            return ImportPersistenceResult(
                persisted: true,
                workspaceId: receipt.workspaceId,
                accountId: receipt.accountId,
                importSessionId: receipt.importSessionId,
                transactionCount: 0,
                importAttemptId: plan.historyTemplate.successfulAttempt.id,
                isEquivalentSupportingSource: true,
                accountOutcome: .matchedExisting
            )
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
        case .committed, .equivalentSourceRecorded, .partialCommitted, .sourceOverlapCommitted, .exactDuplicate:
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
        case .statementEquivalenceConflict: return .statementEquivalenceConflict
        case .statementEquivalenceEvidenceUnavailable: return .statementEquivalenceEvidenceUnavailable
        case .equivalentFormatAlreadyRecorded: return .equivalentFormatAlreadyRecorded
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
        case .statementEquivalenceConflict: outcome = .statementEquivalenceConflict; guidance = .integrityReviewRequired
        case .statementEquivalenceEvidenceUnavailable: outcome = .statementEquivalenceEvidenceUnavailable; guidance = .integrityReviewRequired
        case .equivalentFormatAlreadyRecorded: outcome = .equivalentFormatAlreadyRecorded; guidance = .reviewPriorImport
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
