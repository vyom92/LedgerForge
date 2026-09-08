// LedgerForgeTests/TransactionListViewModelTests.swift

import Foundation
import Testing
@testable import LedgerForge

@Suite("TransactionListViewModel", .serialized)
@MainActor
struct TransactionListViewModelTests {
    @Test(.globalRuntimeStateIsolation)
    func searchTrimsWhitespaceAndMatchesAuthenticTransactionText() async throws {
        let context = try await authenticTransactionListContext()
        let transaction = try #require(context.transactionStore.transactions.first)
        let query = try #require(transaction.description.split(whereSeparator: \.isWhitespace).first.map(String.init))
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore
        )

        viewModel.searchText = "  \(query.uppercased())  "

        #expect(!viewModel.filteredTransactions.isEmpty)
        #expect(viewModel.filteredTransactions.allSatisfy {
            [$0.description, $0.account, $0.sourceBank]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(query)
        })
    }

    @Test(.globalRuntimeStateIsolation)
    func creditAndDebitFiltersUseUnchangedAuthenticTransactions() async throws {
        let context = try await authenticTransactionListContext()
        let allTransactions = context.transactionStore.transactions
        let credits = allTransactions.filter { $0.credit != nil }
        let debits = allTransactions.filter { $0.debit != nil }
        _ = try #require(credits.first)
        _ = try #require(debits.first)
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore
        )

        viewModel.showOnlyCredits = true
        viewModel.showOnlyDebits = false
        #expect(Set(viewModel.filteredTransactions.map(\.id)) == Set(credits.map(\.id)))

        viewModel.showOnlyCredits = false
        viewModel.showOnlyDebits = true
        #expect(Set(viewModel.filteredTransactions.map(\.id)) == Set(debits.map(\.id)))

        viewModel.showOnlyCredits = true
        viewModel.showOnlyDebits = true
        #expect(Set(viewModel.filteredTransactions.map(\.id)) == Set(allTransactions.map(\.id)))
    }

    @Test(.globalRuntimeStateIsolation)
    func totalsUseAllUnchangedAuthenticTransactions() async throws {
        let context = try await authenticTransactionListContext()
        let transactions = context.transactionStore.transactions
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore
        )

        viewModel.searchText = try #require(transactions.first?.description)

        #expect(viewModel.totalCredits == transactions.compactMap(\.credit).reduce(.zero, +))
        #expect(viewModel.totalDebits == transactions.compactMap(\.debit).reduce(.zero, +))
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticDurableRelationshipsProduceTransactionDetail() async throws {
        let context = try await authenticTransactionListContext()
        let transaction = try #require(context.transactionStore.transactions.first)
        let viewModel = TransactionListViewModel(
            transactionStore: context.transactionStore,
            importSessionStore: context.importSessionStore
        )

        let presentation = viewModel.detailPresentation(for: transaction)

        #expect(presentation.sourceDocumentName == context.plan.historyTemplate.document.filename)
        #expect(presentation.accountDisplayName != "Unavailable")
        #expect(presentation.institution != "Unavailable")
        #expect(presentation.importedAt != nil)
        #expect(presentation.validation?.title == "Passed")
        #expect(presentation.provenanceAvailability == .complete)
        #expect(presentation.nativeCurrency == transaction.currency)

        let presentedText = presentation.accessibilityText
        for internalValue in [
            transaction.repositoryTransactionId,
            transaction.repositoryAccountId,
            transaction.repositoryDocumentId,
            transaction.repositoryImportSessionId,
            transaction.sourceProvenance.first?.normalizedDocumentID,
            transaction.sourceProvenance.first?.normalizedRowID,
            transaction.sourceProvenance.first?.normalizedRecordDigest,
            transaction.sourceProvenance.first?.parserProfileID
        ].compactMap({ $0 }) where !internalValue.isEmpty {
            #expect(!presentedText.contains(internalValue))
        }
    }
}

private struct AuthenticTransactionListContext {
    let provider: InMemoryRepositoryProvider
    let plan: ConfirmedImportPlanDTO
    let transactionStore: TransactionStore
    let importSessionStore: ImportSessionStore
}

@MainActor
private func authenticTransactionListContext() async throws -> AuthenticTransactionListContext {
    let provider = InMemoryRepositoryProvider()
    let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
    guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
        Issue.record("Authentic confirmed import did not commit before transaction-list hydration.")
        throw RepositoryError.persistenceUnavailable
    }

    let transactionStore = TransactionStore()
    let importSessionStore = ImportSessionStore()
    let hydrator = RepositoryStoreHydrator(
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo,
        categoryRepo: provider.categoryRepo,
        cardRepo: provider.cardRepo,
        salaryRepo: provider.salaryRepo,
        fundingPlanRepo: provider.fundingPlanRepo,
        accountStore: AccountStore(),
        transactionStore: transactionStore,
        categoryStore: CategoryStore(),
        cardStore: CardStore(),
        salaryStore: SalaryStore(),
        fundingPlanStore: FundingPlanStore(),
        importSessionStore: importSessionStore,
        importAttemptStore: ImportAttemptStore(),
        workspaceId: plan.workspace.id,
        persistenceState: .intentionalNonDurable(.testMemory),
        providerGeneration: provider.generationToken,
        participatesInLifecycleGate: false
    )
    _ = try hydrator.hydrateIfNeeded()
    return AuthenticTransactionListContext(
        provider: provider,
        plan: plan,
        transactionStore: transactionStore,
        importSessionStore: importSessionStore
    )
}
