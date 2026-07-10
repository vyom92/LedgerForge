// LedgerForge
// RepositoryStoreHydrator.swift

import Foundation

struct RepositoryStoreHydrationResult: Equatable {
    let didHydrate: Bool
    let accountCount: Int
    let transactionCount: Int
}

enum RepositoryStoreHydrationError: Error, LocalizedError, Equatable {
    case unsupportedCurrency(String)
    case invalidPostedDate(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedCurrency(let currency):
            return "Currency \(currency) is not supported by dashboard hydration."
        case .invalidPostedDate(let value):
            return "Transaction posted date \(value) could not be read."
        }
    }
}

final class RepositoryStoreHydrator {

    private let accountRepo: AccountRepository
    private let transactionRepo: TransactionRepository
    private let accountStore: AccountStore
    private let transactionStore: TransactionStore
    private let workspaceId: String
    private var hasHydrated = false

    convenience init(
        databaseProvider: DatabaseProvider = .shared,
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared,
        workspaceId: String = "default-workspace"
    ) {
        self.init(
            accountRepo: databaseProvider.accountRepo,
            transactionRepo: databaseProvider.transactionRepo,
            accountStore: accountStore,
            transactionStore: transactionStore,
            workspaceId: workspaceId
        )
    }

    init(
        accountRepo: AccountRepository,
        transactionRepo: TransactionRepository,
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared,
        workspaceId: String = "default-workspace"
    ) {
        self.accountRepo = accountRepo
        self.transactionRepo = transactionRepo
        self.accountStore = accountStore
        self.transactionStore = transactionStore
        self.workspaceId = workspaceId
    }

    @discardableResult
    func hydrateIfNeeded(forceRefresh: Bool = false) throws -> RepositoryStoreHydrationResult {
        guard forceRefresh || !hasHydrated else {
            return RepositoryStoreHydrationResult(
                didHydrate: false,
                accountCount: accountStore.accounts.count,
                transactionCount: transactionStore.transactions.count
            )
        }

        let transactionDTOs = try transactionRepo.trustedTransactions(workspaceId: workspaceId)
        let accountDTOs = try accountRepo.accounts(workspaceId: workspaceId)
        let transactions = try transactionDTOs.map {
            try Self.transaction(from: $0, accounts: accountDTOs)
        }
        let accounts = try Self.accounts(from: accountDTOs, transactions: transactionDTOs)

        accountStore.replaceAccounts(accounts)
        transactionStore.replaceTransactions(transactions)
        hasHydrated = true

        return RepositoryStoreHydrationResult(
            didHydrate: true,
            accountCount: accounts.count,
            transactionCount: transactions.count
        )
    }

    private static func accounts(from accountDTOs: [AccountDTO], transactions: [TransactionDTO]) throws -> [Account] {
        try accountDTOs.map { accountDTO in
            let accountTransactions = transactions.filter { $0.accountId == accountDTO.id }
            let latestBalance = try latestRunningBalance(
                from: accountTransactions,
                currency: accountDTO.nativeCurrency
            )

            return Account(
                institution: accountDTO.institutionId ?? "Unknown",
                name: accountDTO.name,
                type: accountType(from: accountDTO.accountType),
                currencyCode: accountDTO.nativeCurrency,
                currentBalance: latestBalance ?? .zero,
                includeInNetWorth: true,
                lastImport: nil
            )
        }
    }

    private static func transaction(from dto: TransactionDTO, accounts: [AccountDTO]) throws -> Transaction {
        guard let postedDate = dayFormatter.date(from: dto.postedDateISO) else {
            throw RepositoryStoreHydrationError.invalidPostedDate(dto.postedDateISO)
        }

        let accountDTO = accounts.first { $0.id == dto.accountId }
        let amount = try decimal(fromMinorUnits: dto.amountMinor, currency: dto.nativeCurrency)
        let runningBalance = try dto.runningBalanceMinor.map {
            try decimal(fromMinorUnits: $0, currency: dto.nativeCurrency)
        }

        return Transaction(
            date: postedDate,
            description: dto.description ?? "",
            debit: dto.direction == "debit" ? abs(amount) : nil,
            credit: dto.direction == "credit" ? amount : nil,
            amount: amount,
            balance: runningBalance,
            currency: dto.nativeCurrency,
            account: accountDTO?.name ?? dto.accountId ?? "",
            sourceBank: accountDTO?.institutionId ?? "",
            sourceFile: dto.importSessionId ?? ""
        )
    }

    private static func accountType(from value: String?) -> AccountType {
        switch value {
        case "credit_card":
            return .creditCard
        case "investment":
            return .investment
        case "cash":
            return .cash
        case "loan":
            return .loan
        default:
            return .bank
        }
    }

    private static func decimal(fromMinorUnits value: Int64, currency: String) throws -> Decimal {
        guard let scale = minorUnitScale(for: currency) else {
            throw RepositoryStoreHydrationError.unsupportedCurrency(currency)
        }

        var divisor = Decimal(1)
        for _ in 0..<scale {
            divisor *= 10
        }

        return Decimal(value) / divisor
    }

    private static func minorUnitScale(for currency: String) -> Int? {
        switch currency.uppercased() {
        case "INR":
            return 2
        default:
            return nil
        }
    }

    private static func latestRunningBalance(from transactions: [TransactionDTO], currency: String) throws -> Decimal? {
        let latest = transactions
            .enumerated()
            .compactMap { offset, transaction -> (offset: Int, date: Date?, balanceMinor: Int64)? in
                guard let balanceMinor = transaction.runningBalanceMinor else { return nil }
                return (offset, dayFormatter.date(from: transaction.postedDateISO), balanceMinor)
            }
            .sorted { lhs, rhs in
                switch (lhs.date, rhs.date) {
                case let (left?, right?) where left != right:
                    return left > right
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                default:
                    return lhs.offset > rhs.offset
                }
            }
            .first

        guard let latest else { return nil }
        return try decimal(fromMinorUnits: latest.balanceMinor, currency: currency)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
