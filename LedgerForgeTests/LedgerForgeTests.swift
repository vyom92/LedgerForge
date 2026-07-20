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
        #expect(LedgerForgeApp.configurePersistence(path: originalPath))
        try seedSprint30Repository(DatabaseProvider.shared)

        let initialHydration = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
        #expect(initialHydration.accountCount == 1)
        #expect(initialHydration.transactionCount == 1)
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(TransactionStore.shared.transactions.count == 1)

        UserDefaults.standard.set("preserved", forKey: "Sprint30PreferencePreservation")
        let lifecycleResult = LedgerForgeApp.startTemporaryEmptySession()
        guard case .temporarySessionStarted(let resetHydration) = lifecycleResult else {
            Issue.record("Expected a temporary empty session, received \(lifecycleResult)")
            return
        }

        #expect(resetHydration.didHydrate)
        #expect(resetHydration.accountCount == 0)
        #expect(resetHydration.transactionCount == 0)
        #expect(AccountStore.shared.accounts.isEmpty)
        #expect(TransactionStore.shared.transactions.isEmpty)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: sprint30WorkspaceId).isEmpty)
        #expect(try DatabaseProvider.shared.transactionRepo.trustedTransactions(workspaceId: sprint30WorkspaceId).isEmpty)
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
            persistenceState: .verifiedSQLite,
            hydrationStatus: "Forced refresh completed",
            latestRefreshResult: "1 account(s), 1 transaction(s)"
        )

        #expect(snapshot.accountCount == 1)
        #expect(snapshot.transactionCount == 1)
        #expect(snapshot.persistenceState == .verifiedSQLite)
        #expect(snapshot.persistenceState.displayName == "Verified SQLite")
        #expect(snapshot.persistenceState.recoveryGuidance == nil)
    }

    @Test func logSearchCopyAndClearUseStructuredDiagnosticEntries() async {
        let baseDate = Date(timeIntervalSince1970: 1_804_896_000)
        let entries = [
            DeveloperLogEntry(
                id: 1,
                sequence: 1,
                timestamp: baseDate,
                level: .info,
                category: .`import`,
                message: "Import completed",
                metadata: nil
            ),
            DeveloperLogEntry(
                id: 2,
                sequence: 2,
                timestamp: baseDate.addingTimeInterval(1),
                level: .error,
                category: .runtime,
                message: "Hydration failed",
                metadata: nil
            ),
            DeveloperLogEntry(
                id: 3,
                sequence: 3,
                timestamp: baseDate.addingTimeInterval(2),
                level: .info,
                category: .runtime,
                message: "Reload Data",
                metadata: ["result": "1 account(s), 1 transaction(s)"]
            )
        ]

        var filters = DeveloperConsole.Filters()
        filters.searchText = "hydration"
        #expect(DeveloperConsole.filteredEntries(entries, using: filters).map(\.message) == ["Hydration failed"])

        filters.searchText = "data"
        #expect(DeveloperConsole.filteredEntries(entries, using: filters).count == 1)

        let text = DeveloperConsole.logText(from: entries)
        #expect(text.contains("[Info] [Import] Import completed"))
        #expect(text.contains("[Error] [Runtime] Hydration failed"))
        #expect(text.contains("[Info] [Runtime] Reload Data"))

        let console = DeveloperConsole()
        console.log("Sprint 30 clear check")
        console.clear()
        #expect(console.entries.isEmpty)
    }
}

private let sprint30WorkspaceId = "default-workspace"

@MainActor
private func resetSprint30RuntimeState() {
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
    DevelopmentDatabaseActivityGate.shared.resetForTesting()
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
        amountDecimal: "100.00",
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
