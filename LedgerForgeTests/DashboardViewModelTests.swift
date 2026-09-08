// LedgerForgeTests/DashboardViewModelTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct DashboardViewModelTests {
    @Test(.globalRuntimeStateIsolation)
    func emptyHydrationProducesEmptyDashboardState() {
        resetDashboardStores()
        let viewModel = DashboardViewModel()

        viewModel.markHydrationCompleted(
            RepositoryStoreHydrationResult(
                didHydrate: true,
                accountCount: 0,
                transactionCount: 0
            )
        )

        #expect(viewModel.presentationState == .empty("No persisted dashboard data"))
        #expect(viewModel.accountSummaries.isEmpty)
        #expect(viewModel.recentTransactionSummaries.isEmpty)
        #expect(viewModel.transactionCount == 0)
        #expect(viewModel.snapshot.netWorth == .zero)
        #expect(viewModel.snapshot.income == .zero)
        #expect(viewModel.snapshot.expenses == .zero)
        #expect(viewModel.snapshot.cashFlow == .zero)
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticRepositoryHydrationPopulatesDashboardWithoutAuthoredFinancialRows() async throws {
        resetDashboardStores()
        defer { resetDashboardStores() }
        let seeded = try await hydrateAuthenticDashboardStores()
        let viewModel = DashboardViewModel()
        let transactions = TransactionStore.shared.transactions

        #expect(viewModel.accounts.count == 1)
        #expect(viewModel.accounts.first?.repositoryAccountId == seeded.plan.proposedAccount.id)
        #expect(viewModel.transactionCount == seeded.plan.transactionTemplates.count)
        #expect(Set(transactions.compactMap(\.repositoryTransactionId)) == Set(seeded.plan.transactionTemplates.map(\.transaction.id)))
        #expect(!viewModel.accountSummaries.isEmpty)
        #expect(!viewModel.recentTransactionSummaries.isEmpty)
        #expect(viewModel.snapshot.income == transactions.compactMap(\.credit).reduce(.zero, +))
        #expect(viewModel.snapshot.expenses == transactions.compactMap(\.debit).reduce(.zero, +))
    }

    @Test
    func nativeCurrencyNetTransactionFlowUsesMoney() throws {
        let balance = try Money(amount: Decimal(800), currency: "INR")
        let credits = try Money(amount: Decimal(125), currency: "INR")
        let debits = try Money(amount: Decimal(45), currency: "INR")
        let summary = DashboardCurrencySummary(
            currency: balance.currency,
            balance: balance,
            income: credits,
            expenses: debits
        )

        let expectedNetTransactionFlow = try Money(amount: Decimal(80), currency: "INR")
        #expect(summary.cashFlow == expectedNetTransactionFlow)
        #expect(summary.cashFlow.currency == balance.currency)
    }

    @Test(.globalRuntimeStateIsolation)
    func hydrationPresentationStateRecordsLoadedAndFailedResults() {
        resetDashboardStores()
        let viewModel = DashboardViewModel()

        viewModel.markHydrationStarted()
        #expect(viewModel.presentationState == .loading("Loading persisted dashboard..."))

        viewModel.markHydrationCompleted(
            RepositoryStoreHydrationResult(
                didHydrate: true,
                accountCount: 1,
                transactionCount: 3
            )
        )
        #expect(viewModel.presentationState == .loaded("Loaded 1 account(s), 3 transaction(s)"))

        viewModel.markHydrationFailed(RepositoryStoreHydrationError.invalidPostedDate("bad-date"))
        #expect(viewModel.presentationState == .failed("Dashboard load failed"))
    }
}

private struct AuthenticDashboardSeed {
    let provider: InMemoryRepositoryProvider
    let plan: ConfirmedImportPlanDTO
}

@MainActor
private func hydrateAuthenticDashboardStores() async throws -> AuthenticDashboardSeed {
    let provider = InMemoryRepositoryProvider()
    let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
    guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
        Issue.record("Authentic confirmed import did not commit before dashboard hydration.")
        throw RepositoryError.persistenceUnavailable
    }
    let hydrator = RepositoryStoreHydrator(
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo,
        categoryRepo: provider.categoryRepo,
        cardRepo: provider.cardRepo,
        salaryRepo: provider.salaryRepo,
        fundingPlanRepo: provider.fundingPlanRepo,
        accountStore: .shared,
        transactionStore: .shared,
        categoryStore: CategoryStore(),
        cardStore: CardStore(),
        salaryStore: SalaryStore(),
        fundingPlanStore: FundingPlanStore(),
        importSessionStore: ImportSessionStore(),
        importAttemptStore: ImportAttemptStore(),
        workspaceId: plan.workspace.id,
        persistenceState: .intentionalNonDurable(.testMemory),
        providerGeneration: provider.generationToken,
        participatesInLifecycleGate: false
    )
    _ = try hydrator.hydrateIfNeeded()
    return AuthenticDashboardSeed(provider: provider, plan: plan)
}

@MainActor
private func resetDashboardStores() {
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
}
