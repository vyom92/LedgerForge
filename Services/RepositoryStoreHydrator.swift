// LedgerForge
// RepositoryStoreHydrator.swift

import Foundation

struct RepositoryStoreHydrationResult: Equatable {
    let didHydrate: Bool
    let accountCount: Int
    let transactionCount: Int
    let importSessionCount: Int

    init(
        didHydrate: Bool,
        accountCount: Int,
        transactionCount: Int,
        importSessionCount: Int = 0
    ) {
        self.didHydrate = didHydrate
        self.accountCount = accountCount
        self.transactionCount = transactionCount
        self.importSessionCount = importSessionCount
    }
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
    private let importSessionRepo: ImportSessionRepository
    private let transactionRepo: TransactionRepository
    private let accountStore: AccountStore
    private let importSessionStore: ImportSessionStore
    private let transactionStore: TransactionStore
    private let workspaceId: String
    private var hasHydrated = false

    convenience init(
        databaseProvider: DatabaseProvider = .shared,
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared,
        importSessionStore: ImportSessionStore = .shared,
        workspaceId: String = "default-workspace"
    ) {
        self.init(
            accountRepo: databaseProvider.accountRepo,
            importSessionRepo: databaseProvider.importSessionRepo,
            transactionRepo: databaseProvider.transactionRepo,
            accountStore: accountStore,
            transactionStore: transactionStore,
            importSessionStore: importSessionStore,
            workspaceId: workspaceId
        )
    }

    init(
        accountRepo: AccountRepository,
        importSessionRepo: ImportSessionRepository,
        transactionRepo: TransactionRepository,
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared,
        importSessionStore: ImportSessionStore = .shared,
        workspaceId: String = "default-workspace"
    ) {
        self.accountRepo = accountRepo
        self.importSessionRepo = importSessionRepo
        self.transactionRepo = transactionRepo
        self.accountStore = accountStore
        self.transactionStore = transactionStore
        self.importSessionStore = importSessionStore
        self.workspaceId = workspaceId
    }

    @discardableResult
    func hydrateIfNeeded(forceRefresh: Bool = false) throws -> RepositoryStoreHydrationResult {
        guard forceRefresh || !hasHydrated else {
            return RepositoryStoreHydrationResult(
                didHydrate: false,
                accountCount: accountStore.accounts.count,
                transactionCount: transactionStore.transactions.count,
                importSessionCount: importSessionStore.importSessions.count
            )
        }

        let transactionDTOs = try transactionRepo.trustedTransactions(workspaceId: workspaceId)
        let accountDTOs = try accountRepo.accounts(workspaceId: workspaceId)
        let identitiesByAccountID = Dictionary(
            uniqueKeysWithValues: try accountDTOs.map { accountDTO in
                (accountDTO.id, try Self.identitySummaries(from: accountRepo.identifiers(accountId: accountDTO.id, workspaceId: workspaceId)))
            }
        )
        let importSessions = try referencedImportSessions(from: transactionDTOs)
        let transactions = try transactionDTOs.map {
            try Self.transaction(from: $0, accounts: accountDTOs)
        }
        let accounts = try Self.accounts(
            from: accountDTOs,
            transactions: transactionDTOs,
            identitiesByAccountID: identitiesByAccountID
        )

        // All repository reads and mappings complete before any runtime store changes.
        accountStore.replaceAccounts(accounts)
        transactionStore.replaceTransactions(transactions)
        importSessionStore.replaceImportSessions(importSessions)
        hasHydrated = true

        return RepositoryStoreHydrationResult(
            didHydrate: true,
            accountCount: accounts.count,
            transactionCount: transactions.count,
            importSessionCount: importSessions.count
        )
    }

    private func referencedImportSessions(from transactions: [TransactionDTO]) throws -> [RepositoryImportSession] {
        let referencedSessionIDs = Set(
            transactions.compactMap { transaction -> String? in
                guard transaction.accountId != nil, let importSessionId = transaction.importSessionId else {
                    return nil
                }
                return importSessionId
            }
        ).sorted()

        return try referencedSessionIDs.compactMap { sessionID in
            guard let session = try importSessionRepo.importSession(id: sessionID),
                  session.workspaceId == workspaceId else {
                return nil
            }
            return RepositoryImportSession(
                id: session.id,
                workspaceId: session.workspaceId,
                sourceDocumentName: session.userVisibleName,
                startedAtISO: session.startedAtISO,
                completedAtISO: session.completedAtISO,
                validationStatus: session.validationStatus,
                parserVersion: session.parserVersion
            )
        }
    }

    private static func accounts(
        from accountDTOs: [AccountDTO],
        transactions: [TransactionDTO],
        identitiesByAccountID: [String: [AccountIdentitySummary]]
    ) throws -> [Account] {
        try accountDTOs.map { accountDTO in
            let accountTransactions = transactions.filter { $0.accountId == accountDTO.id }
            let latestBalance = try latestRunningBalance(
                from: accountTransactions,
                currency: accountDTO.nativeCurrency
            )

            return Account(
                repositoryAccountId: accountDTO.id,
                workspaceId: accountDTO.workspaceId,
                institution: accountDTO.institutionId ?? "Unknown",
                name: accountDTO.name,
                type: accountType(from: accountDTO.accountType),
                currencyCode: accountDTO.nativeCurrency,
                currentBalance: latestBalance ?? .zero,
                includeInNetWorth: true,
                lastImport: nil,
                identitySummaries: identitiesByAccountID[accountDTO.id] ?? []
            )
        }
    }

    private static func identitySummaries(from identifiers: [AccountIdentifierDTO]) -> [AccountIdentitySummary] {
        identifiers.compactMap { identifier in
            guard identifier.strength == FinancialIdentifierStrength.strong.rawValue,
                  identifier.verificationState == FinancialIdentifierVerificationState.verified.rawValue else {
                return nil
            }

            return AccountIdentitySummary(
                id: identifier.id,
                kind: identifierKindLabel(identifier.scheme),
                redactedValue: FinancialIdentifier.redacted(identifier.identifier),
                strength: identifier.strength,
                verificationState: identifier.verificationState,
                provenance: identifier.provenance
            )
        }
    }

    private static func identifierKindLabel(_ scheme: String) -> String {
        switch scheme {
        case FinancialIdentifierKind.iban.rawValue:
            return "IBAN"
        case FinancialIdentifierKind.institutionAccountId.rawValue:
            return "Institution account ID"
        case FinancialIdentifierKind.brokerAccountId.rawValue:
            return "Broker account ID"
        case FinancialIdentifierKind.institutionIssuedIdentifier.rawValue:
            return "Institution-issued identifier"
        default:
            return "Verified identifier"
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
            sourceFile: dto.importSessionId ?? "",
            repositoryAccountId: dto.accountId,
            repositoryImportSessionId: dto.importSessionId
        )
    }

    private static func accountType(from value: String?) -> AccountType {
        switch value {
        case "credit_card", "creditCard":
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
