// LedgerForgeTests/DashboardViewModelTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct DashboardViewModelTests {

    @Test func emptyHydrationProducesEmptyDashboardState() {
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

    @Test func accountSummaryUsesRuntimeStoreAccounts() {
        resetDashboardStores()
        let firstAccountId = UUID()
        AccountStore.shared.replaceAccounts([
            Account(
                id: firstAccountId,
                institution: "Axis Bank",
                name: "Axis NRE",
                nickname: "NRE Savings",
                type: .bank,
                currencyCode: "INR",
                currentBalance: Decimal(1_050)
            ),
            Account(
                institution: "CBQ",
                name: "Current Account",
                type: .bank,
                currencyCode: "QAR",
                currentBalance: Decimal(200)
            ),
            Account(
                institution: "HDFC",
                name: "Salary Account",
                type: .bank,
                currencyCode: "INR",
                currentBalance: Decimal(300)
            ),
            Account(
                institution: "Amex",
                name: "Credit Card",
                type: .creditCard,
                currencyCode: "USD",
                currentBalance: Decimal(-50)
            )
        ])

        let viewModel = DashboardViewModel()

        #expect(viewModel.accounts.count == 4)
        #expect(viewModel.accountSummaries.count == 3)
        #expect(viewModel.accountSummaries.first?.id == firstAccountId)
        #expect(viewModel.accountSummaries.first?.displayName == "NRE Savings")
        #expect(viewModel.accountSummaries.first?.institution == "Axis Bank")
        #expect(viewModel.accountSummaries.first?.currencyCode == "INR")
        #expect(viewModel.accountSummaries.first?.currentBalance == Decimal(1_050))
    }

    @Test func transactionSummaryAndSnapshotUseRuntimeStoreTransactions() throws {
        resetDashboardStores()
        let older = makeTransaction(
            date: makeDate(year: 2026, month: 7, day: 1),
            description: "Debit purchase",
            debit: Decimal(20),
            credit: nil,
            amount: Decimal(-20),
            balance: Decimal(980)
        )
        let newer = makeTransaction(
            date: makeDate(year: 2026, month: 7, day: 8),
            description: "Salary credit",
            debit: nil,
            credit: Decimal(100),
            amount: Decimal(100),
            balance: Decimal(1_080)
        )
        TransactionStore.shared.replaceTransactions([older, newer])

        let viewModel = DashboardViewModel()

        #expect(viewModel.transactionCount == 2)
        #expect(viewModel.snapshot.income == Decimal(100))
        #expect(viewModel.snapshot.expenses == Decimal(20))
        #expect(viewModel.snapshot.cashFlow == Decimal(80))
        #expect(viewModel.snapshot.netWorth == Decimal(1_080))
        #expect(viewModel.recentTransactionSummaries.count == 2)
        #expect(viewModel.recentTransactionSummaries.first?.description == "Salary credit")
        let expectedMoney = try Money(amount: Decimal(100), currency: "INR")
        #expect(viewModel.recentTransactionSummaries.first?.amount == expectedMoney)
        #expect(viewModel.recentTransactionSummaries.first?.isCredit == true)
    }

    @Test func recentTransactionSummaryPreservesNativeMoneyForDisplay() throws {
        resetDashboardStores()
        TransactionStore.shared.replaceTransactions([
            Transaction(
                date: makeDate(year: 2026, month: 7, day: 8),
                description: "Qatari salary",
                debit: nil,
                credit: Decimal(123.45),
                amount: Decimal(123.45),
                balance: Decimal(123.45),
                currency: "QAR",
                account: "CBQ",
                sourceBank: "CBQ",
                sourceFile: "repository"
            )
        ])

        let viewModel = DashboardViewModel()

        let expectedMoney = try Money(amount: Decimal(string: "123.45")!, currency: "QAR")
        #expect(viewModel.recentTransactionSummaries.first?.amount == expectedMoney)
    }

    @Test func hydrationPresentationStateRecordsLoadedAndFailedResults() {
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

private func resetDashboardStores() {
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
}

private func makeTransaction(
    date: Date,
    description: String,
    debit: Decimal?,
    credit: Decimal?,
    amount: Decimal,
    balance: Decimal
) -> Transaction {
    Transaction(
        date: date,
        description: description,
        debit: debit,
        credit: credit,
        amount: amount,
        balance: balance,
        currency: "INR",
        account: "Axis NRE",
        sourceBank: "Axis Bank",
        sourceFile: "repository"
    )
}

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(secondsFromGMT: 0),
        year: year,
        month: month,
        day: day
    ).date!
}
