// LedgerForgeTests/RepositoryStoreHydratorTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct RepositoryStoreHydratorTests {

    @Test func hydratorLoadsTrustedRepositoryDataIntoRuntimeStores() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(provider: provider, stores: stores)

        let result = try hydrator.hydrateIfNeeded()

        #expect(result.didHydrate)
        #expect(result.accountCount == 1)
        #expect(result.transactionCount == 1)
        #expect(stores.accounts.accounts.count == 1)
        #expect(stores.transactions.transactions.count == 1)
        #expect(stores.accounts.accounts.first?.name == "Axis NRE")
        #expect(stores.accounts.accounts.first?.currentBalance == Decimal(1_050))
        #expect(stores.transactions.transactions.first?.description == "Trusted credit")
        #expect(stores.transactions.transactions.first?.credit == Decimal(100))
        #expect(stores.transactions.transactions.first?.account == "Axis NRE")
        #expect(stores.transactions.transactions.first?.sourceBank == "Axis")
        #expect(stores.accounts.accounts.first?.repositoryAccountId == "account-dashboard")
        #expect(stores.accounts.accounts.first?.workspaceId == "workspace-dashboard")
        #expect(stores.transactions.transactions.first?.repositoryAccountId == "account-dashboard")
        #expect(stores.transactions.transactions.first?.repositoryImportSessionId == "import-dashboard")
        #expect(stores.transactions.transactions.first?.repositoryTransactionId == "transaction-trusted")
        #expect(stores.importSessions.importSessions.map(\.id) == ["import-dashboard"])

        let viewModel = TransactionListViewModel(
            transactionStore: stores.transactions,
            importSessionStore: stores.importSessions
        )
        let transaction = try #require(stores.transactions.transactions.first)
        #expect(viewModel.validationPresentation(for: transaction)?.title == "Passed")
    }

    @Test func hydratorRedactsOnlyVerifiedStrongIdentifiersBeforeRuntimePresentation() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let verifiedIdentifier = "AXIS-ACCOUNT-12345678"
        _ = try provider.accountRepo.attachIdentifier(AccountIdentifierDTO(
            id: "identifier-verified",
            accountId: "account-dashboard",
            workspaceId: "workspace-dashboard",
            scheme: FinancialIdentifierKind.institutionAccountId.rawValue,
            identifier: verifiedIdentifier,
            strength: FinancialIdentifierStrength.strong.rawValue,
            verificationState: FinancialIdentifierVerificationState.verified.rawValue,
            provenance: FinancialIdentifierProvenance.institutionStructuredField.rawValue,
            createdAtISO: "2026-07-08T00:05:00Z"
        ))
        _ = try provider.accountRepo.attachIdentifier(AccountIdentifierDTO(
            id: "identifier-weak",
            accountId: "account-dashboard",
            workspaceId: "workspace-dashboard",
            scheme: FinancialIdentifierKind.accountSuffix.rawValue,
            identifier: "5678",
            strength: FinancialIdentifierStrength.weak.rawValue,
            verificationState: FinancialIdentifierVerificationState.verified.rawValue,
            provenance: FinancialIdentifierProvenance.parserDerivedText.rawValue,
            createdAtISO: "2026-07-08T00:05:00Z"
        ))
        let hydrator = makeHydrator(provider: provider, stores: stores)

        _ = try hydrator.hydrateIfNeeded()

        let summaries = try #require(stores.accounts.accounts.first?.identitySummaries)
        #expect(summaries.count == 1)
        #expect(summaries.first?.redactedValue == FinancialIdentifier.redacted(verifiedIdentifier))
        #expect(summaries.first?.redactedValue != verifiedIdentifier)
    }

    @Test func hydratorRunsOnlyOnceUnlessForced() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(provider: provider, stores: stores)

        let firstResult = try hydrator.hydrateIfNeeded()
        let secondResult = try hydrator.hydrateIfNeeded()

        #expect(firstResult.didHydrate)
        #expect(!secondResult.didHydrate)
        #expect(stores.accounts.accounts.count == 1)
        #expect(stores.transactions.transactions.count == 1)
    }

    @Test func hydrationUsesStableRuntimeIdentityWithoutReplacingOpaqueRepositoryIdentity() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(provider: provider, stores: stores)

        _ = try hydrator.hydrateIfNeeded()
        let initial = try #require(stores.transactions.transactions.first)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        let refreshed = try #require(stores.transactions.transactions.first)

        #expect(initial.repositoryTransactionId == "transaction-trusted")
        #expect(refreshed.repositoryTransactionId == "transaction-trusted")
        #expect(initial.id == refreshed.id)
    }

    @Test func forcedHydrationRefreshesRuntimeStoresWithoutDuplicatingState() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(provider: provider, stores: stores)

        _ = try hydrator.hydrateIfNeeded()
        try provider.transactionRepo.replaceTransactions(
            workspaceId: "workspace-dashboard",
            importSessionId: "import-dashboard",
            transactions: [trustedTransaction(amountMinor: 25_00, runningBalanceMinor: 1_075_00)]
        )

        let refreshResult = try hydrator.hydrateIfNeeded(forceRefresh: true)

        #expect(refreshResult.didHydrate)
        #expect(refreshResult.transactionCount == 1)
        #expect(stores.transactions.transactions.count == 1)
        #expect(stores.transactions.transactions.first?.description == "Trusted credit")
        #expect(stores.transactions.transactions.first?.credit == Decimal(25))
        #expect(stores.transactions.transactions.first?.account == "Axis NRE")
    }
    @Test func hydratorUsesLatestDatedRunningBalanceForAccountBalance() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(provider: provider, stores: stores)

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
        #expect(stores.accounts.accounts.first?.currentBalance == Decimal(1_075))
        #expect(stores.transactions.transactions.first?.description == "Trusted credit")
        #expect(stores.transactions.transactions.last?.balance == Decimal(1_075))
    }

    @Test func hydratorRejectsNoncanonicalPersistedINRTextWithoutMutatingStores() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(provider: provider, stores: stores)
        var malformed = trustedTransaction()
        malformed = TransactionDTO(
            id: malformed.id,
            workspaceId: malformed.workspaceId,
            accountId: malformed.accountId,
            importSessionId: malformed.importSessionId,
            postedDateISO: malformed.postedDateISO,
            description: malformed.description,
            nativeCurrency: malformed.nativeCurrency,
            amountMinor: malformed.amountMinor,
            amountDecimal: "100",
            direction: malformed.direction,
            runningBalanceMinor: malformed.runningBalanceMinor,
            isTrusted: malformed.isTrusted,
            trustedAtISO: malformed.trustedAtISO,
            createdAtISO: malformed.createdAtISO
        )
        try provider.transactionRepo.replaceTransactions(
            workspaceId: "workspace-dashboard",
            importSessionId: "import-dashboard",
            transactions: [malformed]
        )

        #expect(throws: RepositoryStoreHydrationError.self) {
            try hydrator.hydrateIfNeeded()
        }
        #expect(stores.accounts.accounts.isEmpty)
        #expect(stores.transactions.transactions.isEmpty)
    }

    @Test func hydratorRejectsDecimalMinorDisagreementWithoutMutatingStores() throws {
        let provider = try seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(provider: provider, stores: stores)
        var mismatched = trustedTransaction()
        mismatched = TransactionDTO(
            id: mismatched.id,
            workspaceId: mismatched.workspaceId,
            accountId: mismatched.accountId,
            importSessionId: mismatched.importSessionId,
            postedDateISO: mismatched.postedDateISO,
            description: mismatched.description,
            nativeCurrency: mismatched.nativeCurrency,
            amountMinor: mismatched.amountMinor,
            amountDecimal: "99.99",
            direction: mismatched.direction,
            runningBalanceMinor: mismatched.runningBalanceMinor,
            isTrusted: mismatched.isTrusted,
            trustedAtISO: mismatched.trustedAtISO,
            createdAtISO: mismatched.createdAtISO
        )
        try provider.transactionRepo.replaceTransactions(
            workspaceId: "workspace-dashboard",
            importSessionId: "import-dashboard",
            transactions: [mismatched]
        )

        #expect(throws: RepositoryStoreHydrationError.self) {
            try hydrator.hydrateIfNeeded()
        }
        #expect(stores.accounts.accounts.isEmpty)
        #expect(stores.transactions.transactions.isEmpty)
    }
}

private struct RuntimeStores {
    let accounts = AccountStore()
    let transactions = TransactionStore()
    let importSessions = ImportSessionStore()
}

private func makeHydrator(provider: InMemoryRepositoryProvider, stores: RuntimeStores) -> RepositoryStoreHydrator {
    RepositoryStoreHydrator(
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo,
        accountStore: stores.accounts,
        transactionStore: stores.transactions,
        importSessionStore: stores.importSessions,
        workspaceId: "workspace-dashboard"
    )
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
        amountDecimal: "-50.00",
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
        amountDecimal: try! Money.fromMinorUnits(amountMinor, currency: "INR").canonicalDecimalString(),
        direction: "credit",
        runningBalanceMinor: runningBalanceMinor,
        isTrusted: true,
        trustedAtISO: "2026-07-08T00:04:00Z",
        createdAtISO: "2026-07-08T00:03:00Z"
    )
}
