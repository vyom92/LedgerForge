// LedgerForgeTests/RepositoryContractTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct RepositoryContractTests {

    @Test func accountRepositoryCanUpsertAndRetrieveAccountData() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspace(provider)
            let original = account(id: "account-contract", workspaceId: fixture.workspaceId, name: "Primary Account", currency: "INR")
            let updated = account(id: "account-contract", workspaceId: fixture.workspaceId, name: "Updated Account", currency: "QAR")

            #expect(try provider.accountRepo.upsertAccount(original) == original.id)
            #expect(try provider.accountRepo.upsertAccount(updated) == updated.id)
            #expect(try provider.accountRepo.account(id: updated.id) == updated)
        }
    }

    @Test func accountRepositoryCanListAccountsForWorkspace() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspace(provider)
            let first = account(id: "account-b", workspaceId: fixture.workspaceId, name: "Beta Account", currency: "INR")
            let second = account(id: "account-a", workspaceId: fixture.workspaceId, name: "Alpha Account", currency: "INR")
            let otherWorkspace = WorkspaceDTO(id: "workspace-other", name: "Other Workspace", createdAtISO: "2026-07-06T12:00:00Z")
            let other = account(id: "account-other", workspaceId: otherWorkspace.id, name: "Other Account", currency: "INR")

            #expect(try provider.accountRepo.upsertAccount(first) == first.id)
            #expect(try provider.accountRepo.upsertAccount(second) == second.id)
            #expect(try provider.workspaceRepo.upsertWorkspace(otherWorkspace) == otherWorkspace.id)
            #expect(try provider.accountRepo.upsertAccount(other) == other.id)

            #expect(try provider.accountRepo.accounts(workspaceId: fixture.workspaceId) == [second, first])
        }
    }

    @Test func importSessionRepositoryCanCreateUpdateAndRetrieveSessionData() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspace(provider)
            let session = importSession(id: "session-contract", workspaceId: fixture.workspaceId)

            #expect(try provider.importSessionRepo.createImportSession(session) == session.id)
            try provider.importSessionRepo.updateImportSession(
                session.id,
                updates: PartialImportSessionUpdate(validationStatus: "passed", completedAtISO: "2026-07-06T12:05:00Z")
            )

            let stored = try provider.importSessionRepo.importSession(id: session.id)
            #expect(stored?.id == session.id)
            #expect(stored?.workspaceId == fixture.workspaceId)
            #expect(stored?.userVisibleName == session.userVisibleName)
            #expect(stored?.startedAtISO == session.startedAtISO)
            #expect(stored?.completedAtISO == "2026-07-06T12:05:00Z")
            #expect(stored?.validationStatus == "passed")
            #expect(stored?.readerVersion == session.readerVersion)
            #expect(stored?.parserVersion == session.parserVersion)
            #expect(stored?.layoutVersion == session.layoutVersion)
        }
    }

    @Test func transactionRepositoryCanReplaceTransactionsAtomicallyAndPreserveRelationships() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspaceAccountAndSession(provider)

            let firstTransaction = transaction(
                id: "transaction-1",
                workspaceId: fixture.workspaceId,
                accountId: fixture.accountId,
                importSessionId: fixture.importSessionId,
                documentId: "document-1",
                amountMinor: 1250,
                amountDecimal: "12.50",
                direction: "credit"
            )

            let secondTransaction = transaction(
                id: "transaction-2",
                workspaceId: fixture.workspaceId,
                accountId: fixture.accountId,
                importSessionId: fixture.importSessionId,
                documentId: "document-1",
                amountMinor: -500,
                amountDecimal: "-5.00",
                direction: "debit"
            )

            try provider.transactionRepo.replaceTransactions(
                workspaceId: fixture.workspaceId,
                importSessionId: fixture.importSessionId,
                transactions: [firstTransaction, secondTransaction]
            )

            let originalStored = try provider.transactionRepo.transactions(
                workspaceId: fixture.workspaceId,
                importSessionId: fixture.importSessionId
            )
            #expect(originalStored == [firstTransaction, secondTransaction])

            let replacement = transaction(
                id: "transaction-3",
                workspaceId: fixture.workspaceId,
                accountId: fixture.accountId,
                importSessionId: fixture.importSessionId,
                documentId: "document-2",
                amountMinor: 999,
                amountDecimal: "9.99",
                direction: "credit"
            )

            try provider.transactionRepo.replaceTransactions(
                workspaceId: fixture.workspaceId,
                importSessionId: fixture.importSessionId,
                transactions: [replacement]
            )

            let replacedStored = try provider.transactionRepo.transactions(
                workspaceId: fixture.workspaceId,
                importSessionId: fixture.importSessionId
            )
            #expect(replacedStored == [replacement])
            #expect(replacedStored.first?.workspaceId == fixture.workspaceId)
            #expect(replacedStored.first?.accountId == fixture.accountId)
            #expect(replacedStored.first?.importSessionId == fixture.importSessionId)
            #expect(replacedStored.first?.documentId == "document-2")

            let invalidTransaction = transaction(
                id: "transaction-invalid",
                workspaceId: "missing-workspace",
                accountId: fixture.accountId,
                importSessionId: fixture.importSessionId,
                documentId: "document-3",
                amountMinor: 1,
                amountDecimal: "0.01",
                direction: "credit"
            )

            do {
                try provider.transactionRepo.replaceTransactions(
                    workspaceId: fixture.workspaceId,
                    importSessionId: fixture.importSessionId,
                    transactions: [replacement, invalidTransaction]
                )
                Issue.record("Expected atomic replacement to fail for an invalid workspace relationship.")
            } catch {
                let afterFailedReplace = try provider.transactionRepo.transactions(
                    workspaceId: fixture.workspaceId,
                    importSessionId: fixture.importSessionId
                )
                #expect(afterFailedReplace == [replacement])
            }
        }
    }

    @Test func transactionRepositoryCanListTrustedTransactionsForDashboard() async throws {
        try runForEachProvider { provider in
            let fixture = try seedWorkspaceAccountAndSession(provider)
            let trusted = transaction(
                id: "transaction-trusted",
                workspaceId: fixture.workspaceId,
                accountId: fixture.accountId,
                importSessionId: fixture.importSessionId,
                documentId: "document-1",
                amountMinor: 1250,
                amountDecimal: "12.50",
                direction: "credit",
                isTrusted: true
            )
            let untrusted = transaction(
                id: "transaction-untrusted",
                workspaceId: fixture.workspaceId,
                accountId: fixture.accountId,
                importSessionId: fixture.importSessionId,
                documentId: "document-1",
                amountMinor: -500,
                amountDecimal: "-5.00",
                direction: "debit",
                isTrusted: false
            )

            try provider.transactionRepo.replaceTransactions(
                workspaceId: fixture.workspaceId,
                importSessionId: fixture.importSessionId,
                transactions: [trusted, untrusted]
            )

            #expect(try provider.transactionRepo.trustedTransactions(workspaceId: fixture.workspaceId) == [trusted])
        }
    }

    @Test func providersProduceSameObservableResults() async throws {
        let inMemorySnapshot = try runScenario(provider: makeInMemoryProvider())
        let sqliteSnapshot = try withTemporarySQLiteProvider { provider in
            try runScenario(provider: provider)
        }

        #expect(inMemorySnapshot == sqliteSnapshot)
    }

}

private struct RepositoryHandles {
    let name: String
    let workspaceRepo: WorkspaceRepository
    let accountRepo: AccountRepository
    let importSessionRepo: ImportSessionRepository
    let transactionRepo: TransactionRepository
}

private struct RepositoryFixture {
    let workspaceId: String
    let accountId: String?
    let importSessionId: String?
}

private struct RepositorySnapshot: Equatable {
    let workspace: WorkspaceDTO?
    let account: AccountDTO?
    let importSession: ImportSessionRecordDTO?
    let transactions: [TransactionDTO]
}

private func runForEachProvider(_ body: (RepositoryHandles) throws -> Void) throws {
    try body(makeInMemoryProvider())
    try withTemporarySQLiteProvider(body)
}

private func makeInMemoryProvider() -> RepositoryHandles {
    let provider = InMemoryRepositoryProvider()
    return RepositoryHandles(
        name: "InMemoryRepositoryProvider",
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo
    )
}

private func withTemporarySQLiteProvider<T>(_ body: (RepositoryHandles) throws -> T) throws -> T {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForgeRepositoryContractTests")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: folder)
    }

    let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("contract.sqlite").path)
    let handles = RepositoryHandles(
        name: "SQLiteRepositoryProvider",
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo
    )
    return try body(handles)
}

private func seedWorkspace(_ provider: RepositoryHandles) throws -> RepositoryFixture {
    let workspace = WorkspaceDTO(id: "workspace-contract", name: "Contract Workspace", createdAtISO: "2026-07-06T12:00:00Z")
    #expect(try provider.workspaceRepo.upsertWorkspace(workspace) == workspace.id)
    #expect(try provider.workspaceRepo.workspace(id: workspace.id) == workspace)
    return RepositoryFixture(workspaceId: workspace.id, accountId: nil, importSessionId: nil)
}

private func seedWorkspaceAccountAndSession(_ provider: RepositoryHandles) throws -> RepositoryFixture {
    let workspaceFixture = try seedWorkspace(provider)
    let account = account(id: "account-contract", workspaceId: workspaceFixture.workspaceId, name: "Primary Account", currency: "INR")
    let session = importSession(id: "session-contract", workspaceId: workspaceFixture.workspaceId)

    #expect(try provider.accountRepo.upsertAccount(account) == account.id)
    #expect(try provider.importSessionRepo.createImportSession(session) == session.id)

    return RepositoryFixture(workspaceId: workspaceFixture.workspaceId, accountId: account.id, importSessionId: session.id)
}

private func runScenario(provider: RepositoryHandles) throws -> RepositorySnapshot {
    let fixture = try seedWorkspaceAccountAndSession(provider)
    let updatedSessionCompletedAt = "2026-07-06T12:10:00Z"
    try provider.importSessionRepo.updateImportSession(
        fixture.importSessionId ?? "",
        updates: PartialImportSessionUpdate(validationStatus: "warning", completedAtISO: updatedSessionCompletedAt)
    )

    let storedTransaction = transaction(
        id: "transaction-contract",
        workspaceId: fixture.workspaceId,
        accountId: fixture.accountId,
        importSessionId: fixture.importSessionId,
        documentId: "document-contract",
        amountMinor: 4200,
        amountDecimal: "42.00",
        direction: "credit"
    )

    try provider.transactionRepo.replaceTransactions(
        workspaceId: fixture.workspaceId,
        importSessionId: fixture.importSessionId,
        transactions: [storedTransaction]
    )

    return RepositorySnapshot(
        workspace: try provider.workspaceRepo.workspace(id: fixture.workspaceId),
        account: try provider.accountRepo.account(id: fixture.accountId ?? ""),
        importSession: try provider.importSessionRepo.importSession(id: fixture.importSessionId ?? ""),
        transactions: try provider.transactionRepo.transactions(workspaceId: fixture.workspaceId, importSessionId: fixture.importSessionId)
    )
}

private func account(id: String, workspaceId: String, name: String, currency: String) -> AccountDTO {
    AccountDTO(
        id: id,
        workspaceId: workspaceId,
        name: name,
        institutionId: nil,
        accountType: "bank",
        nativeCurrency: currency,
        description: "Contract test account",
        createdAtISO: "2026-07-06T12:01:00Z"
    )
}

private func importSession(id: String, workspaceId: String) -> ImportSessionDTO {
    ImportSessionDTO(
        id: id,
        workspaceId: workspaceId,
        userVisibleName: "Contract Import",
        startedAtISO: "2026-07-06T12:02:00Z",
        validationStatus: "pending",
        readerVersion: "reader-contract",
        parserVersion: "parser-contract",
        layoutVersion: "layout-contract"
    )
}

private func transaction(id: String,
                         workspaceId: String,
                         accountId: String?,
                         importSessionId: String?,
                         documentId: String,
                         amountMinor: Int64,
                         amountDecimal: String,
                         direction: String,
                         isTrusted: Bool = false) -> TransactionDTO {
    TransactionDTO(
        id: id,
        workspaceId: workspaceId,
        accountId: accountId,
        importSessionId: importSessionId,
        documentId: documentId,
        originalRowId: nil,
        postedDateISO: "2026-07-06",
        valueDateISO: nil,
        description: "Contract transaction \(id)",
        payee: "Contract Payee",
        reference: "REF-\(id)",
        nativeCurrency: "INR",
        amountMinor: amountMinor,
        amountDecimal: amountDecimal,
        direction: direction,
        runningBalanceMinor: nil,
        isReconciled: false,
        isTrusted: isTrusted,
        trustedAtISO: isTrusted ? "2026-07-06T12:04:00Z" : nil,
        createdAtISO: "2026-07-06T12:03:00Z",
        updatedAtISO: nil,
        rawRows: []
    )
}
