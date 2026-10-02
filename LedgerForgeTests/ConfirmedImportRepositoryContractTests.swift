import Foundation
import Testing
import SQLite3
@testable import LedgerForge

/// Shared confirmed-import contract checks use either repository error values or
/// one unchanged authentic source prepared through the ordinary engine. They do
/// not author statement graphs or mutate financial facts to manufacture rejects.
@MainActor
struct ConfirmedImportRepositoryContractTests {
    @Test
    func sqliteBusyAndLockedErrorsAreRecognizedWithoutDiagnosticLeakage() {
        let busy = SQLiteExecutionError(
            primaryCode: SQLITE_BUSY,
            extendedCode: SQLITE_BUSY,
            operation: .transaction
        )
        let locked = SQLiteExecutionError(
            primaryCode: SQLITE_LOCKED,
            extendedCode: SQLITE_LOCKED,
            operation: .statement
        )

        #expect(busy.isRetryableContention)
        #expect(locked.isRetryableContention)
        #expect(!busy.description.contains("SELECT"))
    }

    @Test
    func sqliteUniqueConstraintIsRecognizedWithoutSQLInDescription() {
        let error = SQLiteExecutionError(
            primaryCode: SQLITE_CONSTRAINT,
            extendedCode: 2067,
            operation: .statement
        )

        #expect(error.isUniqueConstraint)
        #expect(!error.description.contains("identifier"))
        #expect(!error.description.contains("SELECT"))
    }

    @Test
    func confirmedImportResultsUsePrivacySafeDescriptions() {
        let results: [ConfirmedImportRepositoryResult] = [
            .exactDuplicate,
            .identifierOwnershipConflict,
            .retryableContention,
            .persistenceUnavailable
        ]

        for result in results {
            #expect(!result.description.lowercased().contains("sql"))
            #expect(!result.description.lowercased().contains("fingerprint"))
            #expect(!result.description.lowercased().contains("identifier"))
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func unchangedAuthenticPlanCommitsAndReplaysEquallyAcrossProviders() async throws {
        let memory = InMemoryRepositoryProvider()
        let memoryPlan = try await confirmedImportPlan(generationToken: memory.generationToken)

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-ConfirmedContract-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("contract.sqlite").path,
            migrations: allMigrations
        )
        defer { sqlite.database.close() }
        let sqlitePlan = try await confirmedImportPlan(generationToken: sqlite.generationToken)

        #expect(memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .committed(receipt(for: memoryPlan)))
        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .committed(receipt(for: sqlitePlan)))
        #expect(memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .exactDuplicate)
        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .exactDuplicate)
        #expect(try memory.transactionRepo.trustedTransactions(workspaceId: memoryPlan.workspace.id).count == memoryPlan.transactionTemplates.count)
        #expect(try sqlite.transactionRepo.trustedTransactions(workspaceId: sqlitePlan.workspace.id).count == sqlitePlan.transactionTemplates.count)
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticConfirmedImportNamespaceContentionIsRetryableWithoutAcceptedResidue() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-ConfirmedNamespace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let databasePath = folder.appendingPathComponent("contention.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: databasePath)
        defer { sqlite.database.close() }
        let plan = try await confirmedImportPlan(generationToken: sqlite.generationToken)
        let before = try SQLiteNamespaceContentionSnapshot(database: sqlite.database)

        let result = try withHeldNamespaceLock(databasePath: databasePath) {
            sqlite.confirmedImportRepo.commitConfirmedImport(plan)
        }
        #expect(result == .retryableContention)
        let unchanged = try SQLiteNamespaceContentionSnapshot(database: sqlite.database) == before
        #expect(unchanged, "Namespace contention changed durable tables, connection writes or activation.")
        #expect(try sqlite.importSessionRepo.importSession(id: plan.historyTemplate.importSession.id) == nil)
        #expect(try sqlite.transactionRepo.trustedTransactions(workspaceId: plan.workspace.id).isEmpty)

        // The unchanged authentic plan is valid and remains usable after the
        // external lock leaves; contention must not consume or corrupt it.
        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(plan) == .committed(receipt(for: plan)))
        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(plan) == .exactDuplicate)
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticStandaloneBankNamespaceContentionIsRetryableWithoutAcceptedResidue() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-BankNamespace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let databasePath = folder.appendingPathComponent("contention.sqlite").path
        let sqlite = try SQLiteRepositoryProvider(path: databasePath)
        defer { sqlite.database.close() }
        // Establish the account from the first unchanged registered original.
        // The incoming plan comes from the other registered original period.
        let accepted = try await confirmedImportPlan(generationToken: sqlite.generationToken)
        try #require(sqlite.confirmedImportRepo.commitConfirmedImport(accepted) == .committed(receipt(for: accepted)))
        let account = try #require(try sqlite.accountRepo.account(id: accepted.proposedAccount.id))
        let owner = try await AuthenticSourceTestSupport.preparedAxisBankCSV(providerGeneration: sqlite.generationToken, alternatePeriod: true)
        defer { owner.cancel() }
        let prepared = owner.preparedImport
        let plan = try ImportPersistenceMapper().standaloneBankImportPlan(
            financialDocument: prepared.financialDocument, importSession: prepared.importSession,
            validation: prepared.validation, fingerprintSet: prepared.fingerprintSet,
            providerGeneration: sqlite.generationToken, account: account)
        guard case .ready(let reviewed) = sqlite.confirmedImportRepo.reviewBankImport(plan) else {
            Issue.record("The unchanged alternate original did not produce a ready bank plan.")
            return
        }
        let before = try SQLiteNamespaceContentionSnapshot(database: sqlite.database)

        let result = try withHeldNamespaceLock(databasePath: databasePath) {
            sqlite.confirmedImportRepo.commitBankImport(reviewed)
        }
        #expect(result == .retryableContention)
        let unchanged = try SQLiteNamespaceContentionSnapshot(database: sqlite.database) == before
        #expect(unchanged, "Namespace contention changed the earlier accepted ledger.")
        #expect(try sqlite.importSessionRepo.importSession(id: plan.history.importSession.id) == nil)

        guard case .committed = sqlite.confirmedImportRepo.commitBankImport(reviewed) else {
            Issue.record("The unchanged reviewed bank plan did not commit after namespace contention ended.")
            return
        }
        #expect(sqlite.confirmedImportRepo.commitBankImport(reviewed) == .exactDuplicate)
    }

    private func receipt(for plan: ConfirmedImportPlanDTO) -> ConfirmedImportReceiptDTO {
        ConfirmedImportReceiptDTO(
            workspaceId: plan.workspace.id,
            accountId: plan.proposedAccount.id,
            importSessionId: plan.historyTemplate.importSession.id,
            documentId: plan.historyTemplate.document.id
        )
    }
}
