//
//  TransactionListViewModel.swift
//  LedgerForge
//
//  Created by Copilot on 06/07/26.
//

import Foundation
import Combine

final class TransactionListViewModel: ObservableObject {

    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var validationPassed: Bool = false
    @Published private(set) var validationIssues: [ValidationIssue] = []

    @Published var searchText: String = ""
    @Published var showOnlyCredits: Bool = false
    @Published var showOnlyDebits: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        transactions = TransactionStore.shared.transactions
        validationPassed = TransactionStore.shared.lastValidation?.passed ?? false
        validationIssues = TransactionStore.shared.lastValidation?.issues ?? []

        TransactionStore.shared.$transactions
            .receive(on: RunLoop.main)
            .sink { [weak self] tx in
                self?.transactions = tx
            }
            .store(in: &cancellables)

        TransactionStore.shared.$lastValidation
            .receive(on: RunLoop.main)
            .sink { [weak self] validation in
                self?.validationPassed = validation?.passed ?? false
                self?.validationIssues = validation?.issues ?? []
            }
            .store(in: &cancellables)
    }

    var totalDebits: Decimal {
        transactions.compactMap(\.debit).reduce(0, +)
    }

    var totalCredits: Decimal {
        transactions.compactMap(\.credit).reduce(0, +)
    }

    var closingBalance: Decimal? {
        transactions.last?.balance
    }

    var filteredTransactions: [Transaction] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filterCredits = showOnlyCredits && !showOnlyDebits
        let filterDebits = showOnlyDebits && !showOnlyCredits

        return transactions.filter { transaction in
            let matchesSearch = trimmedSearch.isEmpty ||
                transaction.description.localizedCaseInsensitiveContains(trimmedSearch) ||
                transaction.account.localizedCaseInsensitiveContains(trimmedSearch) ||
                transaction.sourceBank.localizedCaseInsensitiveContains(trimmedSearch)

            let matchesType: Bool
            if filterCredits {
                matchesType = transaction.credit != nil
            } else if filterDebits {
                matchesType = transaction.debit != nil
            } else {
                matchesType = true
            }

            return matchesSearch && matchesType
        }
    }
}
