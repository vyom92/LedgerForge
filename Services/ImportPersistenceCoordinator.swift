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

    init(
        persisted: Bool,
        workspaceId: String?,
        accountId: String?,
        importSessionId: String?,
        transactionCount: Int,
        previousImport: PreviouslyImportedStatement? = nil,
        transactionEventBlock: TransactionEventBlock? = nil
    ) {
        self.persisted = persisted
        self.workspaceId = workspaceId
        self.accountId = accountId
        self.importSessionId = importSessionId
        self.transactionCount = transactionCount
        self.previousImport = previousImport
        self.transactionEventBlock = transactionEventBlock
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

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice?
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
        }
    }
}

final class DefaultImportPersistenceCoordinator: ImportPersistenceCoordinating {

    private static let confirmationSerializationLock = NSLock()

    private enum AccountSelection {
        case existing(AccountDTO)
        case new(accountId: String)

        var accountId: String {
            switch self {
            case .existing(let account):
                return account.id
            case .new(let accountId):
                return accountId
            }
        }
    }

    private let workspaceRepo: WorkspaceRepository
    private let accountRepo: AccountRepository
    private let importSessionRepo: ImportSessionRepository
    private let transactionRepo: TransactionRepository
    private let mapper: ImportPersistenceMapper
    private let developerConsole: DeveloperConsole?

    init(
        workspaceRepo: WorkspaceRepository,
        accountRepo: AccountRepository,
        importSessionRepo: ImportSessionRepository,
        transactionRepo: TransactionRepository,
        mapper: ImportPersistenceMapper = ImportPersistenceMapper(),
        developerConsole: DeveloperConsole? = .shared
    ) {
        self.workspaceRepo = workspaceRepo
        self.accountRepo = accountRepo
        self.importSessionRepo = importSessionRepo
        self.transactionRepo = transactionRepo
        self.mapper = mapper
        self.developerConsole = developerConsole
    }

    convenience init(
        databaseProvider: DatabaseProvider = .shared,
        mapper: ImportPersistenceMapper = ImportPersistenceMapper()
    ) {
        self.init(
            workspaceRepo: databaseProvider.workspaceRepo,
            accountRepo: databaseProvider.accountRepo,
            importSessionRepo: databaseProvider.importSessionRepo,
            transactionRepo: databaseProvider.transactionRepo,
            mapper: mapper
        )
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

        let workspaceId = mapper.workspaceId
        let resolution = try resolver().resolve(
            workspaceId: workspaceId,
            identifiers: financialDocument.financialIdentifiers
        )
        guard case .noMatch = resolution,
              eligibleIdentifier(in: financialDocument) != nil else {
            return .unavailable
        }

        let eligibleAccountIds = try accountRepo.accounts(workspaceId: workspaceId)
            .filter { try accountRepo.identifiers(accountId: $0.id, workspaceId: workspaceId).isEmpty }
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
        return try importSessionRepo.priorImportedStatement(
            algorithm: fingerprint.algorithm,
            fingerprint: fingerprint.digest
        ).map(Self.previousImport(from:))
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprint: ExactStatementFingerprint,
        accountChoice: ImportAccountChoice? = nil
    ) throws -> ImportPersistenceResult {
        guard validation.passed else {
            return .skipped
        }

        try validate(fingerprint: fingerprint)
        Self.confirmationSerializationLock.lock()
        defer { Self.confirmationSerializationLock.unlock() }

        if let previous = try importSessionRepo.priorImportedStatement(
            algorithm: fingerprint.algorithm,
            fingerprint: fingerprint.digest
        ) {
            developerConsole?.info(.import, "Previously imported statement blocked", metadata: [
                "algorithm": fingerprint.algorithm,
                "transactions": "\(previous.transactionCount)"
            ])
            return ImportPersistenceResult(
                persisted: false,
                workspaceId: mapper.workspaceId,
                accountId: previous.accountId,
                importSessionId: previous.importSessionId,
                transactionCount: previous.transactionCount,
                previousImport: Self.previousImport(from: previous)
            )
        }

        let workspaceId = mapper.workspaceId
        let resolution = try resolver().resolve(
            workspaceId: workspaceId,
            identifiers: financialDocument.financialIdentifiers
        )

        let selection: AccountSelection
        switch resolution {
        case .resolved(let accountId):
            guard let existingAccount = try accountRepo.account(id: accountId) else {
                throw ImportPersistenceCoordinationError.resolvedAccountUnavailable
            }
            guard existingAccount.workspaceId == workspaceId else {
                throw ImportPersistenceCoordinationError.resolvedAccountWorkspaceMismatch
            }
            guard try workspaceRepo.workspace(id: workspaceId) != nil else {
                throw ImportPersistenceCoordinationError.resolvedWorkspaceUnavailable
            }
            selection = .existing(existingAccount)

        case .noMatch:
            if let identifier = eligibleIdentifier(in: financialDocument) {
                guard let accountChoice else {
                    throw ImportPersistenceCoordinationError.explicitChoiceRequired
                }
                switch accountChoice {
                case .useExistingAccount(let accountId):
                    guard try workspaceRepo.workspace(id: workspaceId) != nil else {
                        throw ImportPersistenceCoordinationError.resolvedWorkspaceUnavailable
                    }
                    guard let account = try accountRepo.account(id: accountId) else {
                        throw ImportPersistenceCoordinationError.selectedAccountUnavailable
                    }
                    guard account.workspaceId == workspaceId else {
                        throw ImportPersistenceCoordinationError.selectedAccountWorkspaceMismatch
                    }
                    guard try accountRepo.identifiers(accountId: accountId, workspaceId: workspaceId).isEmpty else {
                        throw ImportPersistenceCoordinationError.selectedAccountAlreadyIdentified
                    }
                    let owners = try accountRepo.accountIds(
                        workspaceId: workspaceId,
                        scheme: identifier.kind.rawValue,
                        identifier: identifier.normalizedValue
                    )
                    guard owners.isEmpty else {
                        throw ImportPersistenceCoordinationError.ineligibleIdentifierSet
                    }
                    selection = .existing(account)
                    developerConsole?.info(.import, "Explicit existing-account choice requested")
                case .createNewAccount:
                    selection = .new(accountId: "account-\(importSession.id.uuidString.lowercased())")
                    developerConsole?.info(.import, "Explicit create-new-account choice requested")
                }
            } else {
                selection = .new(accountId: "account-\(importSession.id.uuidString.lowercased())")
            }

        case .ambiguous:
            throw ImportPersistenceCoordinationError.ambiguousIdentity

        case .conflict:
            throw ImportPersistenceCoordinationError.conflictingIdentity
        }

        let identities = try financialDocument.transactions.compactMap {
            try TransactionEventIdentity.make(transaction: $0, accountID: selection.accountId)
        }
        let incomingDuplicates = TransactionEventIdentity.incomingDuplicates(in: identities)
        if !incomingDuplicates.isEmpty {
            return ImportPersistenceResult(
                persisted: false, workspaceId: workspaceId, accountId: selection.accountId,
                importSessionId: nil, transactionCount: identities.count,
                transactionEventBlock: .repeatedIncoming(count: incomingDuplicates.count)
            )
        }
        let keys = Set(identities.map { TransactionEventIdentityKeyDTO(algorithm: $0.algorithmIdentifier, digest: $0.digest) })
        let owners = try importSessionRepo.transactionEventOwners(keys: keys)
        if !owners.isEmpty {
            if owners.values.contains(where: { $0.accountId != selection.accountId }) {
                return ImportPersistenceResult(persisted: false, workspaceId: workspaceId, accountId: selection.accountId, importSessionId: nil, transactionCount: identities.count, transactionEventBlock: .ownershipConflict)
            }
            return ImportPersistenceResult(persisted: false, workspaceId: workspaceId, accountId: selection.accountId, importSessionId: nil, transactionCount: identities.count, transactionEventBlock: .existing(count: owners.count))
        }

        let payload = try mapper.payload(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            accountId: selection.accountId,
            fingerprint: fingerprint
        )

        if case .new = selection {
            if try workspaceRepo.workspace(id: workspaceId) == nil {
                _ = try workspaceRepo.upsertWorkspace(payload.workspace)
            }
            _ = try accountRepo.upsertAccount(payload.account)

            for identifier in financialDocument.financialIdentifiers where
                identifier.strength == .strong && identifier.verificationState == .verified {
                _ = try accountRepo.attachIdentifier(
                    identifier.repositoryDTO(
                        accountId: selection.accountId,
                        workspaceId: workspaceId,
                        createdAtISO: payload.account.createdAtISO
                    )
                )
            }
        } else if let identifier = eligibleIdentifier(in: financialDocument) {
            _ = try accountRepo.attachIdentifier(
                identifier.repositoryDTO(
                    accountId: selection.accountId,
                    workspaceId: workspaceId,
                    createdAtISO: payload.account.createdAtISO
                )
            )
        }

        let historyResult = try importSessionRepo.commitImportHistory(
            AtomicImportHistoryDTO(
                document: payload.document,
                fingerprint: payload.fingerprint,
                importSession: payload.importSession,
                completedAtISO: payload.completedAtISO,
                transactions: payload.transactions,
                transactionEventIdentities: payload.transactionEventIdentities
            )
        )
        if case .duplicate(let previous) = historyResult {
            developerConsole?.info(.import, "Previously imported statement blocked", metadata: [
                "algorithm": fingerprint.algorithm,
                "transactions": "\(previous.transactionCount)"
            ])
            return ImportPersistenceResult(
                persisted: false,
                workspaceId: workspaceId,
                accountId: previous.accountId,
                importSessionId: previous.importSessionId,
                transactionCount: previous.transactionCount,
                previousImport: Self.previousImport(from: previous)
            )
        }

        developerConsole?.info(.database, "Atomic import-history commit completed", metadata: [
            "algorithm": fingerprint.algorithm,
            "transactions": "\(payload.transactions.count)"
        ])

        return ImportPersistenceResult(
            persisted: true,
            workspaceId: workspaceId,
            accountId: selection.accountId,
            importSessionId: payload.importSession.id,
            transactionCount: payload.transactions.count,
            previousImport: nil
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

    private func resolver() -> FinancialIdentityResolver {
        FinancialIdentityResolver(accountRepository: accountRepo, developerConsole: developerConsole)
    }

    private func eligibleIdentifier(in financialDocument: FinancialDocument) -> FinancialIdentifier? {
        let identifiers = financialDocument.financialIdentifiers.filter {
            $0.strength == .strong && $0.verificationState == .verified
        }
        guard identifiers.count == 1 else { return nil }
        return identifiers[0]
    }
}
