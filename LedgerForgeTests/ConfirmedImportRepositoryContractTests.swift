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

    private func receipt(for plan: ConfirmedImportPlanDTO) -> ConfirmedImportReceiptDTO {
        ConfirmedImportReceiptDTO(
            workspaceId: plan.workspace.id,
            accountId: plan.proposedAccount.id,
            importSessionId: plan.historyTemplate.importSession.id,
            documentId: plan.historyTemplate.document.id
        )
    }
}
