import Foundation
import Testing
@testable import LedgerForge

/// Repository atomicity checks use a small deterministic statement plan.
/// Injected failures alter repository mechanics only, never financial content.
@MainActor
struct ConfirmedImportAtomicityTests {
    @Test(.globalRuntimeStateIsolation)
    func sqliteConfirmedImportReusesExistingInstitutionAndMatchesInMemoryOutcome() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("institutions.sqlite").path,
            migrations: allMigrations
        )
        defer { sqlite.database.close() }
        let sqlitePlan = try await confirmedImportPlan(generationToken: sqlite.generationToken)
        let institutionID = try #require(sqlitePlan.proposedAccount.institutionId)
        _ = try sqlite.workspaceRepo.upsertWorkspace(sqlitePlan.workspace)
        _ = try sqlite.accountRepo.upsertAccount(AccountDTO(
            id: "existing-institution-account",
            workspaceId: sqlitePlan.workspace.id,
            name: "Existing",
            institutionId: institutionID,
            accountType: sqlitePlan.proposedAccount.accountType,
            nativeCurrency: sqlitePlan.proposedAccount.nativeCurrency,
            createdAtISO: sqlitePlan.workspace.createdAtISO
        ))
        #expect(institutionCount(sqlite, id: institutionID) == 1)

        let memory = InMemoryRepositoryProvider()
        let memoryPlan = try await confirmedImportPlan(generationToken: memory.generationToken)

        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .committed(receipt(for: sqlitePlan)))
        #expect(memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .committed(receipt(for: memoryPlan)))
        #expect(institutionCount(sqlite, id: institutionID) == 1)
    }

    @Test(.globalRuntimeStateIsolation, arguments: ConfirmedImportFailureInjectionPoint.allCases)
    func injectedInMemoryFailurePublishesNoAcceptedGraph(
        _ point: ConfirmedImportFailureInjectionPoint
    ) async throws {
        let provider = InMemoryRepositoryProvider()
        let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
        provider.injectConfirmedImportFailure(after: point)

        #expect(provider.confirmedImportRepo.commitConfirmedImport(plan) == .repositoryIntegrityConflict)
        #expect(try provider.workspaceRepo.workspace(id: plan.workspace.id) == nil)
        #expect(try provider.accountRepo.account(id: plan.proposedAccount.id) == nil)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: plan.workspace.id).isEmpty)
        #expect(try provider.categoryRepo.automationSnapshot(workspaceId: plan.workspace.id)?.work.isEmpty == true)
        #expect(try provider.importSessionRepo.priorImportedStatement(
            algorithm: plan.historyTemplate.fingerprint.algorithm,
            fingerprint: plan.historyTemplate.fingerprint.fingerprint
        ) == nil)
    }

    @Test(.globalRuntimeStateIsolation)
    func sqliteAndInMemoryAgreeForAcceptedThenExactReplay() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("confirmed.sqlite").path,
            migrations: allMigrations
        )
        defer { sqlite.database.close() }
        let memory = InMemoryRepositoryProvider()
        let sqlitePlan = try await confirmedImportPlan(generationToken: sqlite.generationToken)
        let memoryPlan = try await confirmedImportPlan(generationToken: memory.generationToken)

        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .committed(receipt(for: sqlitePlan)))
        #expect(memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .committed(receipt(for: memoryPlan)))
        #expect(try sqlite.workspaceRepo.workspace(id: sqlitePlan.workspace.id) == sqlitePlan.workspace)
        #expect(try memory.workspaceRepo.workspace(id: memoryPlan.workspace.id) == memoryPlan.workspace)
        #expect(try sqlite.accountRepo.account(id: sqlitePlan.proposedAccount.id) != nil)
        #expect(try memory.accountRepo.account(id: memoryPlan.proposedAccount.id) != nil)
        #expect(try sqlite.importSessionRepo.importSession(id: sqlitePlan.historyTemplate.importSession.id) != nil)
        #expect(try memory.importSessionRepo.importSession(id: memoryPlan.historyTemplate.importSession.id) != nil)
        #expect(try sqlite.importSessionRepo.importedDocument(id: sqlitePlan.historyTemplate.document.id) == sqlitePlan.historyTemplate.document)
        #expect(try memory.importSessionRepo.importedDocument(id: memoryPlan.historyTemplate.document.id) == memoryPlan.historyTemplate.document)
        #expect(try sqlite.importSessionRepo.importAttempts(workspaceId: sqlitePlan.workspace.id).count == 1)
        #expect(try memory.importSessionRepo.importAttempts(workspaceId: memoryPlan.workspace.id).count == 1)
        let institutionID = try #require(sqlitePlan.proposedAccount.institutionId)
        #expect(institutionCount(sqlite, id: institutionID) == 1)

        let sqliteWork = try sqlite.categoryRepo.automationSnapshot(workspaceId: sqlitePlan.workspace.id)
        let memoryWork = try memory.categoryRepo.automationSnapshot(workspaceId: memoryPlan.workspace.id)
        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .exactDuplicate)
        #expect(memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .exactDuplicate)
        #expect(try sqlite.categoryRepo.automationSnapshot(workspaceId: sqlitePlan.workspace.id) == sqliteWork)
        #expect(try memory.categoryRepo.automationSnapshot(workspaceId: memoryPlan.workspace.id) == memoryWork)
        #expect(try sqlite.transactionRepo.trustedTransactions(workspaceId: sqlitePlan.workspace.id).count == sqlitePlan.transactionTemplates.count)
        #expect(try memory.transactionRepo.trustedTransactions(workspaceId: memoryPlan.workspace.id).count == memoryPlan.transactionTemplates.count)
    }

    private func receipt(for plan: ConfirmedImportPlanDTO) -> ConfirmedImportReceiptDTO {
        ConfirmedImportReceiptDTO(
            workspaceId: plan.workspace.id,
            accountId: plan.proposedAccount.id,
            importSessionId: plan.historyTemplate.importSession.id,
            documentId: plan.historyTemplate.document.id
        )
    }

    private func institutionCount(_ provider: SQLiteRepositoryProvider, id: String) -> Int {
        Int(try! provider.database.query(
            sql: "SELECT COUNT(*) FROM institutions WHERE id = ?;",
            params: [id]
        ) { $0.int64(at: 0) ?? 0 }.first ?? 0)
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-InstitutionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
