import Foundation
import Testing
@testable import LedgerForge

struct ConfirmedImportAtomicityTests {
    @Test(arguments: ConfirmedImportFailureInjectionPoint.allCases)
    func injectedInMemoryFailurePublishesNoAcceptedGraph(_ point: ConfirmedImportFailureInjectionPoint) throws {
        let provider = InMemoryRepositoryProvider()
        provider.injectConfirmedImportFailure(after: point)
        let plan = confirmedImportPlan(generationToken: provider.generationToken)

        #expect(provider.confirmedImportRepo.commitConfirmedImport(plan) == .repositoryIntegrityConflict)
        #expect(try provider.workspaceRepo.workspace(id: plan.workspace.id) == nil)
        #expect(try provider.accountRepo.account(id: plan.proposedAccount.id) == nil)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: plan.workspace.id).isEmpty)
        #expect(try provider.importSessionRepo.priorImportedStatement(algorithm: plan.historyTemplate.fingerprint.algorithm, fingerprint: plan.historyTemplate.fingerprint.fingerprint) == nil)
    }

    @Test func inMemoryProviderPublishesFinalAccountScopedEventOnlyOnSuccess() throws {
        let provider = InMemoryRepositoryProvider()
        let plan = confirmedImportPlan(generationToken: provider.generationToken)

        #expect(provider.confirmedImportRepo.commitConfirmedImport(plan) == .committed(ConfirmedImportReceiptDTO(workspaceId: plan.workspace.id, accountId: plan.proposedAccount.id, importSessionId: plan.historyTemplate.importSession.id, documentId: plan.historyTemplate.document.id)))
        #expect(try provider.accountRepo.account(id: plan.proposedAccount.id) != nil)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: plan.workspace.id).count == 1)
    }

    @Test func sqliteAndInMemoryAgreeForAcceptedThenExactDuplicate() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("confirmed.sqlite").path, migrations: allMigrations + [migrationV5])
        let memory = InMemoryRepositoryProvider()
        let sqlitePlan = confirmedImportPlan(generationToken: sqlite.generationToken)
        let memoryPlan = confirmedImportPlan(generationToken: memory.generationToken)

        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .committed(ConfirmedImportReceiptDTO(workspaceId: sqlitePlan.workspace.id, accountId: sqlitePlan.proposedAccount.id, importSessionId: sqlitePlan.historyTemplate.importSession.id, documentId: sqlitePlan.historyTemplate.document.id)))
        #expect(memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .committed(ConfirmedImportReceiptDTO(workspaceId: memoryPlan.workspace.id, accountId: memoryPlan.proposedAccount.id, importSessionId: memoryPlan.historyTemplate.importSession.id, documentId: memoryPlan.historyTemplate.document.id)))
        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .exactDuplicate)
        #expect(memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .exactDuplicate)
        sqlite.database.close()
    }
}
