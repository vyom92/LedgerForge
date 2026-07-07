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

final class DefaultImportPersistenceCoordinator: ImportPersistenceCoordinating {

    private let workspaceRepo: WorkspaceRepository
    private let accountRepo: AccountRepository
    private let importSessionRepo: ImportSessionRepository
    private let transactionRepo: TransactionRepository
    private let mapper: ImportPersistenceMapper

    init(
        workspaceRepo: WorkspaceRepository,
        accountRepo: AccountRepository,
        importSessionRepo: ImportSessionRepository,
        transactionRepo: TransactionRepository,
        mapper: ImportPersistenceMapper = ImportPersistenceMapper()
    ) {
        self.workspaceRepo = workspaceRepo
        self.accountRepo = accountRepo
        self.importSessionRepo = importSessionRepo
        self.transactionRepo = transactionRepo
        self.mapper = mapper
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

        let payload = try mapper.payload(
            financialDocument: financialDocument,
            importSession: importSession,
            validation: validation
        )

        _ = try workspaceRepo.upsertWorkspace(payload.workspace)
        _ = try accountRepo.upsertAccount(payload.account)
        _ = try importSessionRepo.createImportSession(payload.importSession)

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

        return ImportPersistenceResult(
            persisted: true,
            workspaceId: payload.workspace.id,
            accountId: payload.account.id,
            importSessionId: payload.importSession.id,
            transactionCount: payload.transactions.count
        )
    }
}
