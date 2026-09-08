import Foundation
import Testing
@testable import LedgerForge

/// Shared repository behavior is qualified with source-independent workspace
/// values and complete plans derived from an unchanged authentic statement.
/// Historical hand-authored transaction/document graphs were deliberately
/// retired under the authentic-source rule.
@MainActor
struct RepositoryContractTests {
    @Test(arguments: RepositoryProviderKind.allCases)
    func workspaceUpsertRoundTripsWithoutFinancialContent(
        _ kind: RepositoryProviderKind
    ) throws {
        try withProvider(kind) { provider in
            let first = WorkspaceDTO(
                id: "workspace-contract",
                name: "First Name",
                createdAtISO: "2026-09-07T00:00:00Z"
            )
            let renamed = WorkspaceDTO(
                id: first.id,
                name: "Renamed Workspace",
                createdAtISO: first.createdAtISO
            )

            let firstID = try provider.workspaceRepo.upsertWorkspace(first)
            let firstRead = try provider.workspaceRepo.workspace(id: first.id)
            let renamedID = try provider.workspaceRepo.upsertWorkspace(renamed)
            let renamedRead = try provider.workspaceRepo.workspace(id: first.id)
            #expect(firstID == first.id)
            #expect(firstRead == first)
            #expect(renamedID == first.id)
            #expect(renamedRead == renamed)
        }
    }

    @Test(.globalRuntimeStateIsolation, arguments: RepositoryProviderKind.allCases)
    func authenticConfirmedImportRoundTripsAndExactReplayMatchesAcrossProviders(
        _ kind: RepositoryProviderKind
    ) async throws {
        try await withProvider(kind) { provider in
            let plan = try await confirmedImportPlan(generationToken: provider.generationToken)

            #expect(provider.confirmedImportRepo.commitConfirmedImport(plan) == .committed(receipt(for: plan)))
            #expect(try provider.workspaceRepo.workspace(id: plan.workspace.id) == plan.workspace)
            #expect(try provider.accountRepo.account(id: plan.proposedAccount.id) != nil)
            #expect(try provider.importSessionRepo.importSession(id: plan.historyTemplate.importSession.id) != nil)
            #expect(try provider.importSessionRepo.importedDocument(id: plan.historyTemplate.document.id) == plan.historyTemplate.document)
            #expect(try provider.transactionRepo.trustedTransactions(workspaceId: plan.workspace.id).count == plan.transactionTemplates.count)
            #expect(provider.confirmedImportRepo.commitConfirmedImport(plan) == .exactDuplicate)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func sqliteAuthenticImportSurvivesCloseAndReopen() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("reopen.sqlite").path
        var sqlite: SQLiteRepositoryProvider? = try SQLiteRepositoryProvider(
            path: path,
            migrations: allMigrations
        )
        let installed = try #require(sqlite)
        let plan = try await confirmedImportPlan(generationToken: installed.generationToken)
        #expect(installed.confirmedImportRepo.commitConfirmedImport(plan) == .committed(receipt(for: plan)))
        try installed.database.checkpointAndClose()
        sqlite = nil

        let reopened = try SQLiteRepositoryProvider(path: path, migrations: allMigrations)
        defer { reopened.database.close() }

        #expect(try reopened.workspaceRepo.workspace(id: plan.workspace.id) == plan.workspace)
        #expect(try reopened.accountRepo.account(id: plan.proposedAccount.id) != nil)
        #expect(try reopened.importSessionRepo.importSession(id: plan.historyTemplate.importSession.id) != nil)
        #expect(try reopened.importSessionRepo.importedDocument(id: plan.historyTemplate.document.id) == plan.historyTemplate.document)
        #expect(try reopened.transactionRepo.trustedTransactions(workspaceId: plan.workspace.id).count == plan.transactionTemplates.count)
        #expect(try reopened.database.validatedMigrationHistory(
            against: allMigrations,
            requiresCompleteChain: true
        ).compactMap(\.version) == Array(1...allMigrations.count))
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

enum RepositoryProviderKind: String, CaseIterable, CustomTestStringConvertible {
    case inMemory
    case sqlite

    var testDescription: String { rawValue }
}

@MainActor
private func withProvider(
    _ kind: RepositoryProviderKind,
    body: (DatabaseProvider) throws -> Void
) throws {
    switch kind {
    case .inMemory:
        try body(DatabaseProvider(inMemory: true))
    case .sqlite:
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("contract.sqlite").path,
            migrations: allMigrations
        )
        defer { sqlite.database.close() }
        try body(DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false))
    }
}

@MainActor
private func withProvider(
    _ kind: RepositoryProviderKind,
    body: (DatabaseProvider) async throws -> Void
) async throws {
    switch kind {
    case .inMemory:
        try await body(DatabaseProvider(inMemory: true))
    case .sqlite:
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("contract.sqlite").path,
            migrations: allMigrations
        )
        defer { sqlite.database.close() }
        try await body(DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false))
    }
}

private func temporaryFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForge-RepositoryContract-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}
