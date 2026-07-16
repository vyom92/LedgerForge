//
//  TransactionListViewModel.swift
//  LedgerForge
//
//  Created by Copilot on 06/07/26.
//

import Foundation
import Combine

struct TransactionCurrencySummary: Identifiable, Equatable {
    let currency: CurrencyCode
    let inflow: Money
    let outflow: Money

    var id: String { currency.code }
    var net: Money { try! inflow - outflow }
}

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

    var currencySummaries: [TransactionCurrencySummary] {
        let grouped = Dictionary(grouping: transactions, by: { $0.money.currency })
        return grouped.keys.sorted().map { currency in
            let values = grouped[currency] ?? []
            let inflow = try! Money.aggregate(values.compactMap(\.creditMoney) + [try! Money(amount: .zero, currency: currency)])
            let outflow = try! Money.aggregate(values.compactMap(\.debitMoney) + [try! Money(amount: .zero, currency: currency)])
            return TransactionCurrencySummary(currency: currency, inflow: inflow, outflow: outflow)
        }
    }

    /// Compatibility accessors for single-currency consumers. Mixed values never combine.
    var totalDebits: Decimal { currencySummaries.count == 1 ? currencySummaries[0].outflow.amount : .zero }
    var totalCredits: Decimal { currencySummaries.count == 1 ? currencySummaries[0].inflow.amount : .zero }
    var closingBalance: Decimal? {
        guard Set(transactions.map(\.money.currency)).count <= 1 else { return nil }
        return transactions.last?.runningBalanceMoney?.amount
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
