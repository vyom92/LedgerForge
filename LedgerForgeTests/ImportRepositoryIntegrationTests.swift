import Foundation
import Testing
@testable import LedgerForge

/// Authentic-source replay/cancellation plus source-independent database bootstrap.
/// Fabricated FinancialDocument factories were retired under the hard corpus rule.
@MainActor
struct ImportRepositoryIntegrationTests {
    @Test(.globalRuntimeStateIsolation)
    func appPersistenceBootstrapConfiguresDurableSQLiteProvider() async throws {
        let folder = try temporaryFolder(named: "LedgerForgePersistenceBootstrapTests")
        defer {
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
            try? FileManager.default.removeItem(at: folder)
        }

        let dbPath = folder.appendingPathComponent("bootstrap.sqlite").path
        #expect(LedgerForgeApp.configurePersistence(path: dbPath))

        let workspace = WorkspaceDTO(
            id: "workspace-bootstrap",
            name: "Bootstrap Workspace",
            createdAtISO: "2026-07-10T00:00:00Z"
        )
        #expect(try DatabaseProvider.shared.workspaceRepo.upsertWorkspace(workspace) == workspace.id)

        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        #expect(LedgerForgeApp.configurePersistence(path: dbPath))

        let restoredWorkspace = try DatabaseProvider.shared.workspaceRepo.workspace(id: workspace.id)
        #expect(restoredWorkspace == workspace)
    }

    @Test(.globalRuntimeStateIsolation)
    func exactAxisReimportIsBlockedDurablyWithBoundedProvenance() async throws {
        let folder = try temporaryFolder(named: "LedgerForgeExactReimportTests")
        defer { try? FileManager.default.removeItem(at: folder) }
        let databaseURL = folder.appendingPathComponent("exact-reimport.sqlite")
        // Byte-exact registered authentic source; these assertions cover replay transport, not a source oracle.
        let originalURL = try AuthenticSourceTestSupport.axisBankCSV()
        let renamedURL = folder.appendingPathComponent("renamed-axis-statement.csv")
        try FileManager.default.copyItem(at: originalURL, to: renamedURL)

        let firstProvider = try SQLiteRepositoryProvider(path: databaseURL.path)
        defer { firstProvider.database.close() }
        let firstCoordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: firstProvider.workspaceRepo,
            accountRepo: firstProvider.accountRepo,
            importSessionRepo: firstProvider.importSessionRepo,
            transactionRepo: firstProvider.transactionRepo,
            confirmedImportRepo: firstProvider.confirmedImportRepo,
            generationToken: firstProvider.generationToken,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-import-integration",
                workspaceName: "Import Integration Workspace"
            )
        )
        let firstEngine = ImportEngine(
            importPersistenceCoordinator: firstCoordinator,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { firstProvider.generationToken },
            forcedHydration: { integrationHydrationResult() }
        )
        let firstPrepared = try await firstEngine.prepareImport(from: originalURL)
        #expect(firstPrepared.transactionCount > 0)
        let first = await firstEngine.commitPreparedImport(firstPrepared, accountChoice: .createNewAccount)
        #expect(first.persisted)
        #expect(first.transactionCount == firstPrepared.transactionCount)
        #expect(!first.requiresHydration)
        #expect(first.hydrationOutcome == .committedAndHydrated)
        let firstAccountId = try #require(first.accountId)
        let firstSessionId = try #require(first.importSessionId)
        let firstAccount = try #require(try firstProvider.accountRepo.account(id: firstAccountId))
        let firstIdentifiers = try firstProvider.accountRepo.identifiers(
            accountId: firstAccountId,
            workspaceId: "workspace-import-integration"
        )
        let countsBeforeDuplicate = try sqliteImportHistoryCounts(firstProvider)

        let sameNamePrepared = try await firstEngine.prepareImport(from: originalURL)
        let sameNameDuplicate = await firstEngine.commitPreparedImport(sameNamePrepared)
        #expect(!sameNameDuplicate.persisted)
        #expect(sameNameDuplicate.previousImport?.importSessionId == firstSessionId)
        #expect(try sqliteImportHistoryCounts(firstProvider) == countsBeforeDuplicate)

        firstProvider.database.close()
        let relaunchedProvider = try SQLiteRepositoryProvider(path: databaseURL.path)
        defer { relaunchedProvider.database.close() }
        let relaunchedCoordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: relaunchedProvider.workspaceRepo,
            accountRepo: relaunchedProvider.accountRepo,
            importSessionRepo: relaunchedProvider.importSessionRepo,
            transactionRepo: relaunchedProvider.transactionRepo,
            confirmedImportRepo: relaunchedProvider.confirmedImportRepo,
            generationToken: relaunchedProvider.generationToken,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-import-integration",
                workspaceName: "Import Integration Workspace"
            )
        )
        let relaunchedEngine = ImportEngine(
            importPersistenceCoordinator: relaunchedCoordinator,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { relaunchedProvider.generationToken },
            forcedHydration: { integrationHydrationResult() }
        )
        let duplicatePrepared = try await relaunchedEngine.prepareImport(from: renamedURL)
        #expect(duplicatePrepared.fingerprint == firstPrepared.fingerprint)
        #expect(duplicatePrepared.advisoryPreviousImport?.importSessionId == firstSessionId)
        #expect(duplicatePrepared.advisoryPreviousImport?.transactionCount == firstPrepared.transactionCount)
        #expect(duplicatePrepared.advisoryPreviousImport?.accountId == firstAccountId)
        #expect(duplicatePrepared.advisoryPreviousImport?.accountDisplayName == firstAccount.name)
        #expect(duplicatePrepared.advisoryPreviousImport?.completedAtISO != nil)

        let duplicate = await relaunchedEngine.commitPreparedImport(duplicatePrepared)
        #expect(!duplicate.persisted)
        #expect(duplicate.errorMessage == nil)
        #expect(duplicate.previousImport?.importSessionId == firstSessionId)
        #expect(duplicate.previousImport?.transactionCount == firstPrepared.transactionCount)
        #expect(duplicate.previousImport?.accountDisplayName == firstAccount.name)
        #expect(!duplicate.requiresHydration)
        #expect(try sqliteImportHistoryCounts(relaunchedProvider) == countsBeforeDuplicate)
        #expect(try relaunchedProvider.accountRepo.account(id: firstAccountId) == firstAccount)
        #expect(try relaunchedProvider.accountRepo.identifiers(
            accountId: firstAccountId,
            workspaceId: "workspace-import-integration"
        ) == firstIdentifiers)
    }

    @Test(.globalRuntimeStateIsolation)
    func preparationWithoutConfirmationLeavesNoDurableFingerprint() async throws {
        let folder = try temporaryFolder(named: "LedgerForgeCancelledPreparationTests")
        defer { try? FileManager.default.removeItem(at: folder) }
        let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("cancelled.sqlite").path)
        let coordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: provider.workspaceRepo,
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            confirmedImportRepo: provider.confirmedImportRepo,
            generationToken: provider.generationToken
        )
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) },
            providerGenerationProvider: { provider.generationToken }
        )

        let prepared = try await engine.prepareImport(
            from: try AuthenticSourceTestSupport.axisBankCSV()
        )
        defer { engine.cancelPreparedImport(prepared) }

        #expect(prepared.validation.passed)
        #expect(try provider.importSessionRepo.priorImportedStatement(
            algorithm: prepared.fingerprint.algorithm,
            fingerprint: prepared.fingerprint.digest
        ) == nil)
        #expect(try sqliteImportHistoryCounts(provider) == SQLiteImportHistoryCounts(
            documents: 0,
            fingerprints: 0,
            sessions: 0,
            transactions: 0
        ))
    }

}

private struct SQLiteImportHistoryCounts: Equatable {
    let documents: Int
    let fingerprints: Int
    let sessions: Int
    let transactions: Int
}

@MainActor
private func integrationHydrationResult() -> RepositoryStoreHydrationResult {
    RepositoryStoreHydrationResult(
        didHydrate: true,
        accountCount: 0,
        transactionCount: 0,
        importSessionCount: 0,
        importAttemptCount: 0
    )
}

@MainActor
private func sqliteImportHistoryCounts(_ provider: SQLiteRepositoryProvider) throws -> SQLiteImportHistoryCounts {
    SQLiteImportHistoryCounts(
        documents: try provider.database.queryInt("SELECT COUNT(*) FROM documents;"),
        fingerprints: try provider.database.queryInt("SELECT COUNT(*) FROM document_fingerprints;"),
        sessions: try provider.database.queryInt("SELECT COUNT(*) FROM import_sessions;"),
        transactions: try provider.database.queryInt("SELECT COUNT(*) FROM transactions;")
    )
}

private func temporaryFolder(named name: String) throws -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent(name)
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}
