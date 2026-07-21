import Foundation
import Testing
@testable import LedgerForge

struct ConfirmedImportAtomicityTests {
    @Test func sqliteConfirmedImportReusesExistingInstitutionAndMatchesInMemoryOutcome() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("institutions.sqlite").path, migrations: allMigrations)
        defer { sqlite.database.close() }
        let sqlitePlan = confirmedImportPlan(generationToken: sqlite.generationToken, suffix: "existing-institution", institutionID: "Axis Bank")
        _ = try sqlite.workspaceRepo.upsertWorkspace(sqlitePlan.workspace)
        _ = try sqlite.accountRepo.upsertAccount(AccountDTO(id: "existing-institution-account", workspaceId: sqlitePlan.workspace.id, name: "Existing", institutionId: "Axis Bank", nativeCurrency: "INR", createdAtISO: sqlitePlan.workspace.createdAtISO))
        #expect(institutionCount(sqlite, id: "Axis Bank") == 1)

        let memory = InMemoryRepositoryProvider()
        let memoryPlan = confirmedImportPlan(generationToken: memory.generationToken, suffix: "existing-institution", institutionID: "Axis Bank")

        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .committed(receipt(for: sqlitePlan)))
        #expect(memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .committed(receipt(for: memoryPlan)))
        #expect(institutionCount(sqlite, id: "Axis Bank") == 1)
    }

    @Test func sqliteConfirmedImportCreatesInstitutionInsideAcceptedGraph() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("institutions.sqlite").path, migrations: allMigrations)
        defer { provider.database.close() }
        let plan = confirmedImportPlan(generationToken: provider.generationToken, suffix: "new-institution", institutionID: "Axis Bank")

        #expect(provider.confirmedImportRepo.commitConfirmedImport(plan) == .committed(receipt(for: plan)))
        #expect(institutionCount(provider, id: "Axis Bank") == 1)
        #expect(try provider.database.query(sql: "SELECT code FROM institutions WHERE id = ?;", params: ["Axis Bank"]) { $0.string(at: 0) }.first == "axis-bank")
    }

    @Test func sqliteLaterProviderRejectionRollsBackNewInstitutionAndAcceptedGraph() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("institutions.sqlite").path, migrations: allMigrations)
        defer { provider.database.close() }
        let base = confirmedImportPlan(generationToken: provider.generationToken, suffix: "rollback-institution", institutionID: "Axis Bank")
        let repeatedTransaction = TransactionDTO(id: UUID().uuidString, workspaceId: base.workspace.id, postedDateISO: base.transactionTemplates[0].transaction.postedDateISO, nativeCurrency: "INR", amountMinor: 200, amountDecimal: "2.00", direction: "debit", createdAtISO: base.transactionTemplates[0].transaction.createdAtISO)
        let rejected = ConfirmedImportPlanDTO(providerGeneration: base.providerGeneration, workspace: base.workspace, proposedAccount: base.proposedAccount, accountChoice: base.accountChoice, advisoryIdentity: base.advisoryIdentity, identifiers: base.identifiers, historyTemplate: base.historyTemplate, transactionTemplates: [base.transactionTemplates[0], ConfirmedImportTransactionTemplateDTO(transaction: repeatedTransaction, eventEvidence: base.transactionTemplates[0].eventEvidence)])

        #expect(provider.confirmedImportRepo.commitConfirmedImport(rejected) == .repeatedIncomingEventEvidence)
        #expect(institutionCount(provider, id: "Axis Bank") == 0)
        #expect(try provider.workspaceRepo.workspace(id: base.workspace.id) == nil)
        #expect(try provider.accountRepo.accounts(workspaceId: base.workspace.id).isEmpty)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: base.workspace.id).isEmpty)
    }

    @Test func sqliteIdentifierConflictDoesNotCreateContenderInstitution() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("institutions.sqlite").path, migrations: allMigrations)
        defer { provider.database.close() }
        let accepted = confirmedImportPlan(generationToken: provider.generationToken, identifier: "institution-conflict", fingerprint: "institution-conflict-first", suffix: "institution-first", institutionID: "Existing Bank")
        let contender = confirmedImportPlan(generationToken: provider.generationToken, identifier: "institution-conflict", fingerprint: "institution-conflict-second", suffix: "institution-second", institutionID: "Contender Bank")

        #expect(provider.confirmedImportRepo.commitConfirmedImport(accepted) == .committed(receipt(for: accepted)))
        #expect(provider.confirmedImportRepo.commitConfirmedImport(contender) == .identifierOwnershipConflict)
        #expect(institutionCount(provider, id: "Existing Bank") == 1)
        #expect(institutionCount(provider, id: "Contender Bank") == 0)
    }

    @Test func sqliteExactDuplicateDoesNotCreateSecondInstitution() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("institutions.sqlite").path, migrations: allMigrations)
        defer { provider.database.close() }
        let accepted = confirmedImportPlan(generationToken: provider.generationToken, identifier: "institution-duplicate", fingerprint: "institution-duplicate", suffix: "institution-duplicate-first", institutionID: "Existing Bank")
        let duplicate = confirmedImportPlan(generationToken: provider.generationToken, identifier: "institution-duplicate-second", fingerprint: "institution-duplicate", suffix: "institution-duplicate-second", institutionID: "Unexpected Bank")

        #expect(provider.confirmedImportRepo.commitConfirmedImport(accepted) == .committed(receipt(for: accepted)))
        #expect(provider.confirmedImportRepo.commitConfirmedImport(duplicate) == .exactDuplicate)
        #expect(institutionCount(provider, id: "Existing Bank") == 1)
        #expect(institutionCount(provider, id: "Unexpected Bank") == 0)
    }

    @Test func independentSQLiteProvidersDoNotDuplicateSharedInstitution() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("institutions.sqlite").path
        let first = try SQLiteRepositoryProvider(path: path, migrations: allMigrations)
        let second = try SQLiteRepositoryProvider(path: path, migrations: allMigrations)
        defer { first.database.close(); second.database.close() }
        let firstPlan = confirmedImportPlan(generationToken: first.generationToken, identifier: "institution-concurrent-first", fingerprint: "institution-concurrent-first", suffix: "institution-concurrent-first", institutionID: "Shared Bank")
        let secondPlan = confirmedImportPlan(generationToken: second.generationToken, identifier: "institution-concurrent-second", fingerprint: "institution-concurrent-second", suffix: "institution-concurrent-second", institutionID: "Shared Bank")
        let lock = NSLock()
        var results = [ConfirmedImportRepositoryResult]()
        let group = DispatchGroup()

        for (repository, plan) in [(first.confirmedImportRepo, firstPlan), (second.confirmedImportRepo, secondPlan)] {
            group.enter()
            DispatchQueue.global().async {
                let result = repository.commitConfirmedImport(plan)
                lock.lock(); results.append(result); lock.unlock()
                group.leave()
            }
        }

        #expect(group.wait(timeout: .now() + 5) == .success)
        #expect(results.allSatisfy { if case .committed = $0 { true } else { false } })
        #expect(institutionCount(first, id: "Shared Bank") == 1)
    }

    @Test func staleNoMatchIdentifierOwnershipIsClassifiedConsistentlyAcrossProviders() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("ownership.sqlite").path, migrations: allMigrations)
        let memory = InMemoryRepositoryProvider()
        defer { sqlite.database.close() }

        let sqliteFirst = confirmedImportPlan(generationToken: sqlite.generationToken, identifier: "ownership-race", fingerprint: "ownership-first", suffix: "sqlite-first")
        let sqliteSecond = confirmedImportPlan(generationToken: sqlite.generationToken, identifier: "ownership-race", fingerprint: "ownership-second", suffix: "sqlite-second")
        let memoryFirst = confirmedImportPlan(generationToken: memory.generationToken, identifier: "ownership-race", fingerprint: "ownership-first", suffix: "memory-first")
        let memorySecond = confirmedImportPlan(generationToken: memory.generationToken, identifier: "ownership-race", fingerprint: "ownership-second", suffix: "memory-second")

        let sqliteFirstResult = sqlite.confirmedImportRepo.commitConfirmedImport(sqliteFirst)
        let memoryFirstResult = memory.confirmedImportRepo.commitConfirmedImport(memoryFirst)
        #expect({ if case .committed = sqliteFirstResult { true } else { false } }())
        #expect({ if case .committed = memoryFirstResult { true } else { false } }())
        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqliteSecond) == .identifierOwnershipConflict)
        #expect(memory.confirmedImportRepo.commitConfirmedImport(memorySecond) == .identifierOwnershipConflict)
        #expect(try sqlite.accountRepo.accounts(workspaceId: sqliteFirst.workspace.id).count == 1)
        #expect(try memory.accountRepo.accounts(workspaceId: memoryFirst.workspace.id).count == 1)
    }

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
        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("confirmed.sqlite").path, migrations: allMigrations)
        let memory = InMemoryRepositoryProvider()
        let sqlitePlan = confirmedImportPlan(generationToken: sqlite.generationToken)
        let memoryPlan = confirmedImportPlan(generationToken: memory.generationToken)

        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .committed(ConfirmedImportReceiptDTO(workspaceId: sqlitePlan.workspace.id, accountId: sqlitePlan.proposedAccount.id, importSessionId: sqlitePlan.historyTemplate.importSession.id, documentId: sqlitePlan.historyTemplate.document.id)))
        #expect(memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .committed(ConfirmedImportReceiptDTO(workspaceId: memoryPlan.workspace.id, accountId: memoryPlan.proposedAccount.id, importSessionId: memoryPlan.historyTemplate.importSession.id, documentId: memoryPlan.historyTemplate.document.id)))
        #expect(sqlite.confirmedImportRepo.commitConfirmedImport(sqlitePlan) == .exactDuplicate)
        #expect(memory.confirmedImportRepo.commitConfirmedImport(memoryPlan) == .exactDuplicate)
        sqlite.database.close()
    }

    private func receipt(for plan: ConfirmedImportPlanDTO) -> ConfirmedImportReceiptDTO {
        ConfirmedImportReceiptDTO(workspaceId: plan.workspace.id, accountId: plan.proposedAccount.id, importSessionId: plan.historyTemplate.importSession.id, documentId: plan.historyTemplate.document.id)
    }

    private func institutionCount(_ provider: SQLiteRepositoryProvider, id: String) -> Int {
        Int(try! provider.database.query(sql: "SELECT COUNT(*) FROM institutions WHERE id = ?;", params: [id]) { $0.int64(at: 0) ?? 0 }.first ?? 0)
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-InstitutionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
