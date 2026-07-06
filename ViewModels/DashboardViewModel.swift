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

final class DashboardViewModel: ObservableObject {

    @Published private(set) var snapshot: DashboardSnapshot = .empty
    @Published private(set) var accounts: [Account] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Observe transactions for income/expense/balance calculations
        TransactionStore.shared.$transactions
            .receive(on: RunLoop.main)
            .sink { [weak self] transactions in
                self?.refresh(from: transactions)
            }
            .store(in: &cancellables)

        // Observe accounts for future multi-currency and per-account metrics
        AccountStore.shared.$accounts
            .receive(on: RunLoop.main)
            .sink { [weak self] accounts in
                self?.accounts = accounts
            }
            .store(in: &cancellables)
    }

    func refresh(from transactions: [Transaction]) {

        let income = transactions.reduce(Decimal.zero) {
            $0 + ($1.credit ?? .zero)
        }

        let expenses = transactions.reduce(Decimal.zero) {
            $0 + ($1.debit ?? .zero)
        }

        let netWorth = transactions.last?.balance ?? .zero

        snapshot = DashboardSnapshot(
            netWorth: netWorth,
            income: income,
            expenses: expenses,
            cashFlow: income - expenses
        )
    }
}
