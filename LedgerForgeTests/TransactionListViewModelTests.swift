//
//  TransactionListViewModelTests.swift
//  LedgerForgeTests
//

import Foundation
import Testing
@testable import LedgerForge

@Suite("TransactionListViewModel", .serialized)
struct TransactionListViewModelTests {

    @MainActor
    @Test
    func searchTrimsWhitespaceAndMatchesDescriptionAccountAndBank() async throws {
        TransactionStore.shared.replaceTransactions([])

        let viewModel = TransactionListViewModel()

        TransactionStore.shared.replaceTransactions(Self.sampleTransactions)
        await waitForViewModelUpdate()

        viewModel.searchText = "  axis  "
        #expect(
            viewModel.filteredTransactions.map { $0.description }
                == ["Salary credit"]
        )

        viewModel.searchText = "savings"
        #expect(
            viewModel.filteredTransactions.map { $0.description }
                == ["Salary credit"]
        )

        viewModel.searchText = "CBQ"
        #expect(
            viewModel.filteredTransactions.map { $0.description }
                == ["Rent debit"]
        )

        TransactionStore.shared.replaceTransactions([])
        await waitForViewModelUpdate()
    }

    @MainActor
    @Test
    func creditAndDebitFiltersAreMutuallySafe() async throws {
        TransactionStore.shared.replaceTransactions([])

        let viewModel = TransactionListViewModel()

        TransactionStore.shared.replaceTransactions(Self.sampleTransactions)
        await waitForViewModelUpdate()

        viewModel.showOnlyCredits = true
        viewModel.showOnlyDebits = false

        #expect(
            viewModel.filteredTransactions.map { $0.description }
                == ["Salary credit"]
        )

        viewModel.showOnlyCredits = false
        viewModel.showOnlyDebits = true

        #expect(
            viewModel.filteredTransactions.map { $0.description }
                == ["Rent debit"]
        )

        viewModel.showOnlyCredits = true
        viewModel.showOnlyDebits = true

        #expect(
            viewModel.filteredTransactions.map { $0.description }
                == Self.sampleTransactions.map { $0.description }
        )

        TransactionStore.shared.replaceTransactions([])
        await waitForViewModelUpdate()
    }

    @MainActor
    @Test
    func totalsUseAllRuntimeTransactions() async throws {
        TransactionStore.shared.replaceTransactions([])

        let viewModel = TransactionListViewModel()

        TransactionStore.shared.replaceTransactions(Self.sampleTransactions)
        await waitForViewModelUpdate()

        viewModel.searchText = "salary"

        #expect(viewModel.filteredTransactions.count == 1)
        #expect(viewModel.totalCredits == Decimal(100_000))
        #expect(viewModel.totalDebits == Decimal(25_000))
        #expect(viewModel.closingBalance == Decimal(75_000))

        TransactionStore.shared.replaceTransactions([])
        await waitForViewModelUpdate()
    }

    @MainActor
    private func waitForViewModelUpdate() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }

    private static let sampleTransactions: [Transaction] = [
        Transaction(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            description: "Salary credit",
            debit: nil,
            credit: Decimal(100_000),
            amount: Decimal(100_000),
            balance: Decimal(100_000),
            currency: "INR",
            account: "Axis Savings",
            sourceBank: "Axis",
            sourceFile: "salary.csv"
        ),
        Transaction(
            date: Date(timeIntervalSince1970: 1_700_100_000),
            description: "Rent debit",
            debit: Decimal(25_000),
            credit: nil,
            amount: Decimal(-25_000),
            balance: Decimal(75_000),
            currency: "INR",
            account: "Home Account",
            sourceBank: "CBQ",
            sourceFile: "rent.csv"
        )
    ]
}
