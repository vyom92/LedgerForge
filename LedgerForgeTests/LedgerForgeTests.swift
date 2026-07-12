//
//  LedgerForgeTests.swift
//  LedgerForgeTests
//
//  Created by Vyom on 03/07/26.
//

import Testing
import Foundation
@testable import LedgerForge

@MainActor
struct LedgerForgeTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

    @Test func developmentDatabaseResetSwapsToFreshProviderAndHydratesEmptyRuntimeState() throws {
        resetSprint30RuntimeState()
        defer {
            resetSprint30RuntimeState()
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
            UserDefaults.standard.removeObject(forKey: "Sprint30PreferencePreservation")
        }

        let folder = try sprint30TemporaryFolder(named: "Reset")
        defer {
            try? FileManager.default.removeItem(at: folder)
        }

        let originalPath = folder.appendingPathComponent("original.sqlite").path
        let resetPath = folder.appendingPathComponent("reset.sqlite").path
        #expect(LedgerForgeApp.configurePersistence(path: originalPath))
        try seedSprint30Repository(DatabaseProvider.shared)

        let initialHydration = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
        #expect(initialHydration.accountCount == 1)
        #expect(initialHydration.transactionCount == 1)
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(TransactionStore.shared.transactions.count == 1)

        UserDefaults.standard.set("preserved", forKey: "Sprint30PreferencePreservation")
        let resetHydration = try LedgerForgeApp.resetDevelopmentDatabase(path: resetPath)

        #expect(resetHydration.didHydrate)
        #expect(resetHydration.accountCount == 0)
        #expect(resetHydration.transactionCount == 0)
        #expect(AccountStore.shared.accounts.isEmpty)
        #expect(TransactionStore.shared.transactions.isEmpty)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: sprint30WorkspaceId).isEmpty)
        #expect(try DatabaseProvider.shared.transactionRepo.trustedTransactions(workspaceId: sprint30WorkspaceId).isEmpty)
        #expect(LedgerForgeApp.currentSQLiteDatabasePath() == resetPath)
        #expect(FileManager.default.fileExists(atPath: originalPath))
        #expect(UserDefaults.standard.string(forKey: "Sprint30PreferencePreservation") == "preserved")

        let reloadAfterReset = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
        #expect(reloadAfterReset.accountCount == 0)
        #expect(reloadAfterReset.transactionCount == 0)
        #expect(AccountStore.shared.accounts.isEmpty)
        #expect(TransactionStore.shared.transactions.isEmpty)
    }

    @Test func canonicalReloadDataRefreshesRuntimeCountsFromRepositoryState() throws {
        resetSprint30RuntimeState()
        defer {
            resetSprint30RuntimeState()
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
        }

        let folder = try sprint30TemporaryFolder(named: "Reload")
        defer {
            try? FileManager.default.removeItem(at: folder)
        }

        #expect(LedgerForgeApp.configurePersistence(path: folder.appendingPathComponent("reload.sqlite").path))
        try seedSprint30Repository(DatabaseProvider.shared)

        let result = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)

        #expect(result.accountCount == 1)
        #expect(result.transactionCount == 1)
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(TransactionStore.shared.transactions.count == 1)
    }

    @Test func runtimeInspectorAndRepositorySummaryUseRuntimeStoreCounts() {
        resetSprint30RuntimeState()
        defer {
            resetSprint30RuntimeState()
        }

        AccountStore.shared.replaceAccounts([
            Account(
                institution: "Axis Bank",
                name: "Axis NRE",
                type: .bank,
                currencyCode: "INR",
                currentBalance: 100,
                includeInNetWorth: true
            )
        ])
        TransactionStore.shared.replaceTransactions([
            Transaction(
                date: Date(timeIntervalSince1970: 1_804_896_000),
                description: "Runtime credit",
                debit: nil,
                credit: 100,
                amount: 100,
                balance: 100,
                currency: "INR",
                account: "Axis NRE",
                sourceBank: "Axis Bank",
                sourceFile: "fixture.csv"
            )
        ])

        let snapshot = DeveloperConsole.runtimeSnapshot(
            providerState: "SQLite repository provider",
            databasePath: "/tmp/sprint30.sqlite",
            hydrationStatus: "Forced refresh completed",
            latestRefreshResult: "1 account(s), 1 transaction(s)"
        )

        #expect(snapshot.accountCount == 1)
        #expect(snapshot.transactionCount == 1)
        #expect(snapshot.providerState == "SQLite repository provider")
        #expect(snapshot.databasePath == "/tmp/sprint30.sqlite")
    }

    @Test func logSearchCopyAndClearUsePlainStoredMessages() async {
        let messages = [
            "Import completed",
            "Hydration failed",
            "Reload Data: 1 account(s), 1 transaction(s)"
        ]
        #expect(DeveloperConsole.filteredMessages(messages, matching: "hydration") == ["Hydration failed"])
        #expect(DeveloperConsole.filteredMessages(messages, matching: "data").count == 1)
        #expect(DeveloperConsole.logText(from: messages) == "Import completed\nHydration failed\nReload Data: 1 account(s), 1 transaction(s)")

        DeveloperConsole.shared.log("Sprint 30 clear check")
        DeveloperConsole.shared.clear()
        #expect(DeveloperConsole.shared.messages.isEmpty)
    }
}

private let sprint30WorkspaceId = "default-workspace"

private func resetSprint30RuntimeState() {
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
}

private func sprint30TemporaryFolder(named name: String) throws -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForgeSprint30Tests")
        .appendingPathComponent(name)
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

private func seedSprint30Repository(_ provider: DatabaseProvider) throws {
    let workspace = WorkspaceDTO(
        id: sprint30WorkspaceId,
        name: "Sprint 30 Workspace",
        createdAtISO: "2026-07-12T00:00:00Z"
    )
    let account = AccountDTO(
        id: "account-sprint-30",
        workspaceId: workspace.id,
        name: "Axis NRE",
        institutionId: "Axis Bank",
        accountType: "bank",
        nativeCurrency: "INR",
        description: "Sprint 30 account",
        createdAtISO: "2026-07-12T00:01:00Z"
    )
    let session = ImportSessionDTO(
        id: "import-sprint-30",
        workspaceId: workspace.id,
        userVisibleName: "Sprint 30 Import",
        startedAtISO: "2026-07-12T00:02:00Z",
        validationStatus: "passed",
        readerVersion: nil,
        parserVersion: "Axis Bank Account",
        layoutVersion: nil
    )
    let transaction = TransactionDTO(
        id: "transaction-sprint-30",
        workspaceId: workspace.id,
        accountId: account.id,
        importSessionId: session.id,
        postedDateISO: "2026-07-12",
        description: "Sprint 30 credit",
        nativeCurrency: "INR",
        amountMinor: 100_00,
        amountDecimal: "100",
        direction: "credit",
        runningBalanceMinor: 100_00,
        isTrusted: true,
        trustedAtISO: "2026-07-12T00:04:00Z",
        createdAtISO: "2026-07-12T00:03:00Z"
    )

    _ = try provider.workspaceRepo.upsertWorkspace(workspace)
    _ = try provider.accountRepo.upsertAccount(account)
    _ = try provider.importSessionRepo.createImportSession(session)
    try provider.transactionRepo.replaceTransactions(
        workspaceId: workspace.id,
        importSessionId: session.id,
        transactions: [transaction]
    )
}
