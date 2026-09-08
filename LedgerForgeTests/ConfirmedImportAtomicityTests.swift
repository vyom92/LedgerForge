import Foundation
import Testing
@testable import LedgerForge

/// Repository atomicity checks use an untouched authentic statement plan.
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

    @Test(.globalRuntimeStateIsolation)
    func sqliteConfirmedImportCreatesInstitutionInsideAcceptedGraph() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let provider = try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("institutions.sqlite").path,
            migrations: allMigrations
        )
        defer { provider.database.close() }
        let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
        let institutionID = try #require(plan.proposedAccount.institutionId)

        #expect(provider.confirmedImportRepo.commitConfirmedImport(plan) == .committed(receipt(for: plan)))
        #expect(institutionCount(provider, id: institutionID) == 1)
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
        #expect(try provider.importSessionRepo.priorImportedStatement(
            algorithm: plan.historyTemplate.fingerprint.algorithm,
            fingerprint: plan.historyTemplate.fingerprint.fingerprint
        ) == nil)
    }

    @Test(.globalRuntimeStateIsolation)
    func inMemoryProviderPublishesFinalAccountScopedGraphOnlyOnSuccess() async throws {
        let provider = InMemoryRepositoryProvider()
        let plan = try await confirmedImportPlan(generationToken: provider.generationToken)

        #expect(provider.confirmedImportRepo.commitConfirmedImport(plan) == .committed(receipt(for: plan)))
        #expect(try provider.accountRepo.account(id: plan.proposedAccount.id) != nil)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: plan.workspace.id).count == 1)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: plan.workspace.id).count == plan.transactionTemplates.count)
    }

    @Test(.globalRuntimeStateIsolation)
    func sqliteAndInMemoryAgreeForAuthenticAcceptedThenExactReplay() async throws {
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
        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .exactDuplicate)
        #expect(memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .exactDuplicate)
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
