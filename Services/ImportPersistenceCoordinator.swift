// LedgerForge
// ImportPersistenceCoordinator.swift

import Foundation

struct ImportPersistenceResult: Equatable {
    let persisted: Bool
    let workspaceId: String?
    let accountId: String?
    let importSessionId: String?
    let transactionCount: Int

    static let skipped = ImportPersistenceResult(
        persisted: false,
        workspaceId: nil,
        accountId: nil,
        importSessionId: nil,
        transactionCount: 0
    )
}

protocol ImportPersistenceCoordinating {
    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult
}

enum ImportPersistenceCoordinationError: Error, LocalizedError, Equatable {
    case resolvedAccountUnavailable
    case resolvedAccountWorkspaceMismatch
    case resolvedWorkspaceUnavailable
    case ambiguousIdentity
    case conflictingIdentity

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
        }
    }
}

final class DefaultImportPersistenceCoordinator: ImportPersistenceCoordinating {

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
        guard validation.passed else {
            return .skipped
        }

        let workspaceId = mapper.workspaceId
        let resolution = try FinancialIdentityResolver(
            accountRepository: accountRepo,
            developerConsole: developerConsole
        ).resolve(
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
            selection = .new(
                accountId: "account-\(importSession.id.uuidString.lowercased())"
            )

        case .ambiguous:
            throw ImportPersistenceCoordinationError.ambiguousIdentity

        case .conflict:
            throw ImportPersistenceCoordinationError.conflictingIdentity
        }

        let payload = try mapper.payload(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation,
            accountId: selection.accountId
        )

        if case .new = selection {
            if try workspaceRepo.workspace(id: workspaceId) == nil {
                _ = try workspaceRepo.upsertWorkspace(payload.workspace)
            }
            _ = try accountRepo.upsertAccount(payload.account)

            for identifier in financialDocument.financialIdentifiers where
                identifier.strength == .strong
                && identifier.verificationState == .verified {
                _ = try accountRepo.attachIdentifier(
                    identifier.repositoryDTO(
                        accountId: selection.accountId,
                        workspaceId: workspaceId,
                        createdAtISO: payload.account.createdAtISO
                    )
                )
            }
        }

        _ = try importSessionRepo.createImportSession(payload.importSession)

        do {
            try transactionRepo.replaceTransactions(
                workspaceId: payload.workspace.id,
                importSessionId: payload.importSession.id,
                transactions: payload.transactions
            )

            try importSessionRepo.updateImportSession(
                payload.importSession.id,
                updates: PartialImportSessionUpdate(
                    validationStatus: "passed",
                    completedAtISO: payload.completedAtISO
                )
            )
        } catch {
            try? importSessionRepo.updateImportSession(
                payload.importSession.id,
                updates: PartialImportSessionUpdate(
                    validationStatus: "failed",
                    completedAtISO: payload.completedAtISO
                )
            )
            throw error
        }

        return ImportPersistenceResult(
            persisted: true,
            workspaceId: workspaceId,
            accountId: selection.accountId,
            importSessionId: payload.importSession.id,
            transactionCount: payload.transactions.count
        )
    }
}
