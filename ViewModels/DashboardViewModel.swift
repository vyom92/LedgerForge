//
//  DashboardViewModel.swift
//  LedgerForge
//
//  Created by Vyom on 06/07/26.
//

import Foundation
import Combine

struct DashboardSnapshot {
    let netWorth: Decimal
    let income: Decimal
    let expenses: Decimal
    let cashFlow: Decimal

    static let empty = DashboardSnapshot(
        netWorth: .zero,
        income: .zero,
        expenses: .zero,
        cashFlow: .zero
    )
}

enum DashboardPresentationState: Equatable {
    case loading(String)
    case empty(String)
    case loaded(String)
    case failed(String)

    var message: String {
        switch self {
        case .loading(let message), .empty(let message), .loaded(let message), .failed(let message):
            return message
        }
    }
}

struct DashboardAccountSummary: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let institution: String
    let currencyCode: String
    let currentBalance: Decimal
}

struct DashboardTransactionSummary: Identifiable, Equatable {
    let id: UUID
    let statementDate: StatementDate?
    let description: String
    let amount: Money
    let currency: String
    let isCredit: Bool
}

struct DashboardCurrencySummary: Identifiable, Equatable {
    let currency: CurrencyCode
    let balance: Money
    let income: Money
    let expenses: Money

    var id: String { currency.code }
    var cashFlow: Money { try! income - expenses }
}

final class DashboardViewModel: ObservableObject {

    @Published private(set) var snapshot: DashboardSnapshot = .empty
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var presentationState: DashboardPresentationState = .loading("Loading persisted dashboard...")
    @Published private(set) var accountSummaries: [DashboardAccountSummary] = []
    @Published private(set) var recentTransactionSummaries: [DashboardTransactionSummary] = []
    @Published private(set) var transactionCount: Int = 0
    @Published private(set) var nativeCurrencySummaries: [DashboardCurrencySummary] = []

    private var cancellables = Set<AnyCancellable>()
    private var latestTransactions: [Transaction] = []
    private let accountLimit = 3
    private let recentTransactionLimit = 3

    init(
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared
    ) {
        refresh(accounts: accountStore.accounts)
        refresh(from: transactionStore.transactions)

        // Observe transactions for income/expense/balance calculations
        transactionStore.$transactions
            .receive(on: RunLoop.main)
            .sink { [weak self] transactions in
                self?.refresh(from: transactions)
            }
            .store(in: &cancellables)

        // Observe accounts for future multi-currency and per-account metrics
        accountStore.$accounts
            .receive(on: RunLoop.main)
            .sink { [weak self] accounts in
                self?.refresh(accounts: accounts)
            }
            .store(in: &cancellables)
    }

    func markHydrationStarted() {
        presentationState = .loading("Loading persisted dashboard...")
    }

    func markHydrationCompleted(_ result: RepositoryStoreHydrationResult) {
        if result.accountCount == 0 && result.transactionCount == 0 {
            presentationState = .empty("No persisted dashboard data")
        } else {
            presentationState = .loaded("Loaded \(result.accountCount) account(s), \(result.transactionCount) transaction(s)")
        }
    }

    func markHydrationFailed(_ error: Error) {
        presentationState = .failed("Dashboard load failed")
    }

    func refresh(from transactions: [Transaction]) {

        latestTransactions = transactions
        transactionCount = transactions.count
        recentTransactionSummaries = Self.recentTransactionSummaries(
            from: transactions,
            limit: recentTransactionLimit
        )

        let transactionCurrencies = Set(transactions.map(\.money.currency))
        guard transactionCurrencies.count <= 1 else {
            snapshot = .empty
            refreshPresentationStateIfRuntimeDataAvailable()
            refreshNativeCurrencySummaries()
            return
        }

        let income = transactions.reduce(Decimal.zero) {
            $0 + ($1.credit ?? .zero)
        }

        let expenses = transactions.reduce(Decimal.zero) {
            $0 + ($1.debit ?? .zero)
        }

        let netWorth = Self.latestKnownBalance(from: transactions)

        snapshot = DashboardSnapshot(
            netWorth: netWorth,
            income: income,
            expenses: expenses,
            cashFlow: income - expenses
        )

        refreshPresentationStateIfRuntimeDataAvailable()
        refreshNativeCurrencySummaries()
    }

    private func refresh(accounts: [Account]) {
        self.accounts = accounts
        accountSummaries = accounts.prefix(accountLimit).map {
            DashboardAccountSummary(
                id: $0.id,
                displayName: $0.nickname ?? $0.name,
                institution: $0.institution,
                currencyCode: $0.currencyCode,
                currentBalance: $0.currentBalance
            )
        }

        refreshPresentationStateIfRuntimeDataAvailable()
        refreshNativeCurrencySummaries()
    }

    private func refreshNativeCurrencySummaries() {
        let currencies = Set(accounts.map(\.nativeCurrency)).union(transactionsCurrencyCodes())
        nativeCurrencySummaries = currencies.sorted().map { currency in
            let balanceValues = accounts.filter { $0.nativeCurrency == currency }.map(\.currentBalanceMoney)
            let incomeValues = latestTransactions.filter { $0.money.currency == currency }.compactMap(\.creditMoney)
            let expenseValues = latestTransactions.filter { $0.money.currency == currency }.compactMap(\.debitMoney)
            let zero = try! Money(amount: .zero, currency: currency)
            return DashboardCurrencySummary(
                currency: currency,
                balance: try! Money.aggregate(balanceValues + [zero]),
                income: try! Money.aggregate(incomeValues + [zero]),
                expenses: try! Money.aggregate(expenseValues + [zero])
            )
        }
    }

    private func transactionsCurrencyCodes() -> Set<CurrencyCode> {
        Set(latestTransactions.map(\.money.currency))
    }
    private func refreshPresentationStateIfRuntimeDataAvailable() {
        guard case .failed = presentationState else {
            if !accounts.isEmpty || transactionCount > 0 {
                presentationState = .loaded("Loaded \(accounts.count) account(s), \(transactionCount) transaction(s)")
            } else {
                presentationState = .empty("No persisted dashboard data")
            }
            return
        }
    }

    private static func latestKnownBalance(from transactions: [Transaction]) -> Decimal {
        let dated = transactions.compactMap { transaction -> (Transaction, Decimal)? in
            guard transaction.statementDate != nil, let balance = transaction.balance else { return nil }
            return (transaction, balance)
        }
        guard let latestDate = dated.compactMap({ $0.0.statementDate }).max() else { return .zero }
        let latest = dated.filter { $0.0.statementDate == latestDate }
        guard let documentID = latest.first?.0.documentScopedSourceOrder?.documentID,
              latest.allSatisfy({ $0.0.documentScopedSourceOrder?.documentID == documentID }),
              let result = latest.max(by: { ($0.0.documentScopedSourceOrder?.ordinal ?? 0) < ($1.0.documentScopedSourceOrder?.ordinal ?? 0) }) else {
            return latest.count == 1 ? latest.first?.1 ?? .zero : .zero
        }
        return result.1
    }

    private static func recentTransactionSummaries(
        from transactions: [Transaction],
        limit: Int
    ) -> [DashboardTransactionSummary] {
        transactions
            .enumerated()
            .sorted { lhs, rhs in
                switch (lhs.element.statementDate, rhs.element.statementDate) {
                case let (left?, right?) where left != right:
                    return left > right
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                default:
                    return displayOrder(lhs.element, rhs.element)
                }
            }
            .prefix(limit)
            .map { _, transaction in
                DashboardTransactionSummary(
                    id: transaction.id,
                    statementDate: transaction.statementDate,
                    description: transaction.description,
                    amount: transaction.money,
                    currency: transaction.currency,
                    isCredit: transaction.credit != nil
                )
            }
    }

    private static func displayOrder(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        if lhs.documentScopedSourceOrder?.documentID == rhs.documentScopedSourceOrder?.documentID,
           let left = lhs.documentScopedSourceOrder?.ordinal,
           let right = rhs.documentScopedSourceOrder?.ordinal,
           left != right {
            return left > right
        }
        return (lhs.repositoryTransactionId ?? lhs.id.uuidString) > (rhs.repositoryTransactionId ?? rhs.id.uuidString)
    }
}
