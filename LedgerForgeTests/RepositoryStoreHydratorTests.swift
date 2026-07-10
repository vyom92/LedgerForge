// LedgerForgeTests/RepositoryStoreHydratorTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct RepositoryStoreHydratorTests {

    @Test func hydratorLoadsTrustedRepositoryDataIntoRuntimeStores() throws {
        resetRuntimeStores()
        let provider = try seededProvider()
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            transactionRepo: provider.transactionRepo,
            workspaceId: "workspace-dashboard"
        )

        let result = try hydrator.hydrateIfNeeded()

        #expect(result.didHydrate)
        #expect(result.accountCount == 1)
        #expect(result.transactionCount == 1)
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(TransactionStore.shared.transactions.count == 1)
        #expect(AccountStore.shared.accounts.first?.name == "Axis NRE")
        #expect(AccountStore.shared.accounts.first?.currentBalance == Decimal(1_050))
        #expect(TransactionStore.shared.transactions.first?.description == "Trusted credit")
        #expect(TransactionStore.shared.transactions.first?.credit == Decimal(100))
        #expect(TransactionStore.shared.transactions.first?.account == "Axis NRE")
        #expect(TransactionStore.shared.transactions.first?.sourceBank == "Axis")
    }

    @Test func hydratorRunsOnlyOnceUnlessForced() throws {
        resetRuntimeStores()
        let provider = try seededProvider()
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            transactionRepo: provider.transactionRepo,
            workspaceId: "workspace-dashboard"
        )

        let firstResult = try hydrator.hydrateIfNeeded()
        let secondResult = try hydrator.hydrateIfNeeded()

        #expect(firstResult.didHydrate)
        #expect(!secondResult.didHydrate)
        #expect(AccountStore.shared.accounts.count == 1)
        #expect(TransactionStore.shared.transactions.count == 1)
    }

    @Test func forcedHydrationRefreshesRuntimeStoresWithoutDuplicatingState() throws {
        resetRuntimeStores()
        let provider = try seededProvider()
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            transactionRepo: provider.transactionRepo,
            workspaceId: "workspace-dashboard"
        )

        _ = try hydrator.hydrateIfNeeded()
        try provider.transactionRepo.replaceTransactions(
            workspaceId: "workspace-dashboard",
            importSessionId: "import-dashboard",
            transactions: [trustedTransaction(amountMinor: 25_00, runningBalanceMinor: 1_075_00)]
        )

        let refreshResult = try hydrator.hydrateIfNeeded(forceRefresh: true)

        #expect(refreshResult.didHydrate)
        #expect(refreshResult.transactionCount == 1)
        #expect(TransactionStore.shared.transactions.count == 1)
        #expect(TransactionStore.shared.transactions.first?.description == "Trusted credit")
        #expect(TransactionStore.shared.transactions.first?.credit == Decimal(25))
        #expect(TransactionStore.shared.transactions.first?.account == "Axis NRE")
    }
    @Test func hydratorUsesLatestDatedRunningBalanceForAccountBalance() throws {
        resetRuntimeStores()
        let provider = try seededProvider()
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            transactionRepo: provider.transactionRepo,
            workspaceId: "workspace-dashboard"
        )

        try provider.transactionRepo.replaceTransactions(
            workspaceId: "workspace-dashboard",
            importSessionId: "import-dashboard",
            transactions: [
                trustedTransaction(
                    id: "transaction-newer",
                    amountMinor: 25_00,
                    runningBalanceMinor: 1_075_00,
                    postedDateISO: "2026-07-09"
                ),
                trustedTransaction(
                    id: "transaction-older",
                    amountMinor: 100_00,
                    runningBalanceMinor: 1_050_00,
                    postedDateISO: "2026-07-08"
                )
            ]
        )

        let result = try hydrator.hydrateIfNeeded(forceRefresh: true)

        #expect(result.didHydrate)
        #expect(AccountStore.shared.accounts.first?.currentBalance == Decimal(1_075))
        #expect(TransactionStore.shared.transactions.first?.description == "Trusted credit")
        #expect(TransactionStore.shared.transactions.last?.balance == Decimal(1_075))
    }
}

private func resetRuntimeStores() {
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
}

private func seededProvider() throws -> InMemoryRepositoryProvider {
    let provider = InMemoryRepositoryProvider()
    let workspace = WorkspaceDTO(
        id: "workspace-dashboard",
        name: "Dashboard Workspace",
        createdAtISO: "2026-07-08T00:00:00Z"
    )
    let account = AccountDTO(
        id: "account-dashboard",
        workspaceId: workspace.id,
        name: "Axis NRE",
        institutionId: "Axis",
        accountType: "bank",
        nativeCurrency: "INR",
        description: "Dashboard account",
        createdAtISO: "2026-07-08T00:01:00Z"
    )
    let session = ImportSessionDTO(
        id: "import-dashboard",
        workspaceId: workspace.id,
        userVisibleName: "Dashboard Import",
        startedAtISO: "2026-07-08T00:02:00Z",
        validationStatus: "passed",
        readerVersion: nil,
        parserVersion: "Axis Bank Account",
        layoutVersion: nil
    )
    let untrusted = TransactionDTO(
        id: "transaction-untrusted",
        workspaceId: workspace.id,
        accountId: account.id,
        importSessionId: session.id,
        postedDateISO: "2026-07-08",
        description: "Untrusted debit",
        nativeCurrency: "INR",
        amountMinor: -50_00,
        amountDecimal: "-50",
        direction: "debit",
        runningBalanceMinor: 1_000_00,
        isTrusted: false,
        trustedAtISO: nil,
        createdAtISO: "2026-07-08T00:03:00Z"
    )

    _ = try provider.workspaceRepo.upsertWorkspace(workspace)
    _ = try provider.accountRepo.upsertAccount(account)
    _ = try provider.importSessionRepo.createImportSession(session)
    try provider.transactionRepo.replaceTransactions(
        workspaceId: workspace.id,
        importSessionId: session.id,
        transactions: [trustedTransaction(), untrusted]
    )

    return provider
}

private func trustedTransaction(
    id: String = "transaction-trusted",
    amountMinor: Int64 = 100_00,
    runningBalanceMinor: Int64 = 1_050_00,
    postedDateISO: String = "2026-07-08"
) -> TransactionDTO {
    TransactionDTO(
        id: id,
        workspaceId: "workspace-dashboard",
        accountId: "account-dashboard",
        importSessionId: "import-dashboard",
        postedDateISO: postedDateISO,
        description: "Trusted credit",
        nativeCurrency: "INR",
        amountMinor: amountMinor,
        amountDecimal: "\(Decimal(amountMinor) / Decimal(100))",
        direction: "credit",
        runningBalanceMinor: runningBalanceMinor,
        isTrusted: true,
        trustedAtISO: "2026-07-08T00:04:00Z",
        createdAtISO: "2026-07-08T00:03:00Z"
    )
}
