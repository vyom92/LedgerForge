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

struct TransactionValidationPresentation: Equatable {
    let validationStatus: String

    var title: String { validationStatus.localizedCapitalized }
    var isPassed: Bool { validationStatus == "passed" }
    var detail: String { "Persisted import-session validation status: \(title)." }

    init?(validationStatus: String) {
        guard ["pending", "passed", "warning", "failed"].contains(validationStatus) else {
            return nil
        }
        self.validationStatus = validationStatus
    }
}

final class TransactionListViewModel: ObservableObject {

    @Published private(set) var transactions: [Transaction] = []

    @Published var searchText: String = ""
    @Published var showOnlyCredits: Bool = false
    @Published var showOnlyDebits: Bool = false

    private let transactionStore: TransactionStore
    private let importSessionStore: ImportSessionStore
    private var importSessions: [RepositoryImportSession] = []
    private var cancellables = Set<AnyCancellable>()

    init(
        transactionStore: TransactionStore = .shared,
        importSessionStore: ImportSessionStore = .shared
    ) {
        self.transactionStore = transactionStore
        self.importSessionStore = importSessionStore
        transactions = transactionStore.transactions
        importSessions = importSessionStore.importSessions

        transactionStore.$transactions
            .receive(on: RunLoop.main)
            .sink { [weak self] tx in
                self?.transactions = tx
            }
            .store(in: &cancellables)

        importSessionStore.$importSessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                self?.importSessions = sessions
            }
            .store(in: &cancellables)
    }

    func validationPresentation(for transaction: Transaction) -> TransactionValidationPresentation? {
        guard let sessionID = transaction.repositoryImportSessionId,
              let session = importSessions.first(where: { $0.id == sessionID }) else {
            return nil
        }
        return TransactionValidationPresentation(validationStatus: session.validationStatus)
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
        let dated = transactions.compactMap { transaction -> (transaction: Transaction, date: StatementDate, balance: Decimal)? in
            guard let date = transaction.statementDate,
                  let balance = transaction.runningBalanceMoney?.amount else { return nil }
            return (transaction, date, balance)
        }
        guard let latestDate = dated.map(\.date).max() else { return nil }
        let candidates = dated.filter { $0.date == latestDate }
        guard let documentID = candidates.first?.transaction.documentScopedSourceOrder?.documentID,
              candidates.allSatisfy({ $0.transaction.documentScopedSourceOrder?.documentID == documentID }) else {
            return candidates.count == 1 ? candidates.first?.balance : nil
        }
        return candidates.max(by: {
            ($0.transaction.documentScopedSourceOrder?.ordinal ?? 0) <
            ($1.transaction.documentScopedSourceOrder?.ordinal ?? 0)
        })?.balance
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
