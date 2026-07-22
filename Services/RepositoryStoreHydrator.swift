// LedgerForge
// RepositoryStoreHydrator.swift

import CryptoKit
import Foundation

struct RepositoryStoreHydrationResult: Equatable {
    let didHydrate: Bool
    let accountCount: Int
    let transactionCount: Int
    let importSessionCount: Int
    let importAttemptCount: Int

    init(
        didHydrate: Bool,
        accountCount: Int,
        transactionCount: Int,
        importSessionCount: Int = 0,
        importAttemptCount: Int = 0
    ) {
        self.didHydrate = didHydrate
        self.accountCount = accountCount
        self.transactionCount = transactionCount
        self.importSessionCount = importSessionCount
        self.importAttemptCount = importAttemptCount
    }
}

enum RepositoryStoreHydrationError: Error, LocalizedError, Equatable {
    case persistenceUnavailable
    case unsupportedCurrency(String)
    case invalidPostedDate(String)
    case invalidFinancialDateRole(String)
    case invalidStatementTimezoneEvidence(String)
    case invalidSourceProvenance(String)
    case malformedMoney
    case decimalMinorMismatch
    case accountCurrencyMismatch
    case runningBalanceCurrencyMismatch

    var errorDescription: String? {
        switch self {
        case .persistenceUnavailable:
            return "Persistence is unavailable. Runtime data was not replaced."
        case .unsupportedCurrency(let currency):
            return "Currency \(currency) is not supported by dashboard hydration."
        case .invalidPostedDate(let value):
            return "Transaction posted date \(value) could not be read."
        case .invalidFinancialDateRole:
            return "Transaction financial date role could not be read."
        case .invalidStatementTimezoneEvidence:
            return "Transaction timezone evidence could not be read."
        case .invalidSourceProvenance:
            return "Transaction source provenance could not be read."
        case .malformedMoney:
            return "A persisted monetary value is malformed."
        case .decimalMinorMismatch:
            return "Persisted decimal and minor monetary values disagree."
        case .accountCurrencyMismatch:
            return "A transaction currency does not match its account."
        case .runningBalanceCurrencyMismatch:
            return "A running-balance currency does not match its account."
        }
    }
}

final class RepositoryStoreHydrator {

    private let accountRepo: AccountRepository
    private let importSessionRepo: ImportSessionRepository
    private let transactionRepo: TransactionRepository
    private let accountStore: AccountStore
    private let importSessionStore: ImportSessionStore
    private let importAttemptStore: ImportAttemptStore
    private let transactionStore: TransactionStore
    private let workspaceId: String
    private let persistenceState: PersistenceState
    private var hasHydrated = false
#if DEBUG
    private let participatesInLifecycleGate: Bool
#endif

    convenience init(
        databaseProvider: DatabaseProvider = .shared,
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared,
        importSessionStore: ImportSessionStore = .shared,
        importAttemptStore: ImportAttemptStore = .shared,
        workspaceId: String = "default-workspace",
        participatesInLifecycleGate: Bool = true
    ) {
        self.init(
            accountRepo: databaseProvider.accountRepo,
            importSessionRepo: databaseProvider.importSessionRepo,
            transactionRepo: databaseProvider.transactionRepo,
            accountStore: accountStore,
            transactionStore: transactionStore,
            importSessionStore: importSessionStore,
            importAttemptStore: importAttemptStore,
            workspaceId: workspaceId,
            persistenceState: databaseProvider.persistenceState,
            participatesInLifecycleGate: participatesInLifecycleGate
        )
    }

    init(
        accountRepo: AccountRepository,
        importSessionRepo: ImportSessionRepository,
        transactionRepo: TransactionRepository,
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared,
        importSessionStore: ImportSessionStore = .shared,
        importAttemptStore: ImportAttemptStore = .shared,
        workspaceId: String = "default-workspace",
        persistenceState: PersistenceState = .intentionalNonDurable(.testMemory),
        participatesInLifecycleGate: Bool = true
    ) {
        self.accountRepo = accountRepo
        self.importSessionRepo = importSessionRepo
        self.transactionRepo = transactionRepo
        self.accountStore = accountStore
        self.transactionStore = transactionStore
        self.importSessionStore = importSessionStore
        self.importAttemptStore = importAttemptStore
        self.workspaceId = workspaceId
        self.persistenceState = persistenceState
#if DEBUG
        self.participatesInLifecycleGate = participatesInLifecycleGate
#endif
    }

    @discardableResult
    func hydrateIfNeeded(forceRefresh: Bool = false) throws -> RepositoryStoreHydrationResult {
        guard persistenceState.isUsable else {
            throw RepositoryStoreHydrationError.persistenceUnavailable
        }
#if DEBUG
        let lifecycleLease: DevelopmentDatabaseActivityLease?
        if participatesInLifecycleGate {
            lifecycleLease = try DevelopmentDatabaseActivityGate.shared.begin(.hydration)
        } else {
            lifecycleLease = nil
        }
        defer { lifecycleLease?.finish() }
#endif
        guard forceRefresh || !hasHydrated else {
            return RepositoryStoreHydrationResult(
                didHydrate: false,
                accountCount: accountStore.accounts.count,
                transactionCount: transactionStore.transactions.count,
                importSessionCount: importSessionStore.importSessions.count,
                importAttemptCount: importAttemptStore.attempts.count
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
        let importAttempts = try importSessionRepo.importAttempts(workspaceId: workspaceId).map(RepositoryImportAttempt.init)
        let transactions = try transactionDTOs.map {
            try Self.transaction(from: $0, accounts: accountDTOs)
        }
        let accounts = try Self.accounts(
            from: accountDTOs,
            transactions: transactions,
            identitiesByAccountID: identitiesByAccountID
        )

        // All repository reads and mappings complete before any runtime store changes.
        accountStore.replaceAccounts(accounts)
        transactionStore.replaceTransactions(transactions)
        importSessionStore.replaceImportSessions(importSessions)
        importAttemptStore.replaceAttempts(importAttempts)
        hasHydrated = true

        return RepositoryStoreHydrationResult(
            didHydrate: true,
            accountCount: accounts.count,
            transactionCount: transactions.count,
            importSessionCount: importSessions.count,
            importAttemptCount: importAttempts.count
        )
    }

    /// Refreshes only privacy-safe attempt presentation after a rejected outcome.
    /// Financial runtime stores remain untouched.
    func hydrateImportAttempts() throws {
        guard persistenceState.isUsable else {
            throw RepositoryStoreHydrationError.persistenceUnavailable
        }
        let attempts = try importSessionRepo.importAttempts(workspaceId: workspaceId).map(RepositoryImportAttempt.init)
        importAttemptStore.replaceAttempts(attempts)
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
        transactions: [Transaction],
        identitiesByAccountID: [String: [AccountIdentitySummary]]
    ) throws -> [Account] {
        try accountDTOs.map { accountDTO in
            let accountTransactions = transactions.filter { $0.repositoryAccountId == accountDTO.id }
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
                currentBalance: latestBalance?.amount ?? .zero,
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
        guard let postedDate = try? StatementDate(canonical: dto.postedDateISO) else {
            throw RepositoryStoreHydrationError.invalidPostedDate(dto.postedDateISO)
        }

        guard let accountDTO = accounts.first(where: { $0.id == dto.accountId }) else {
            throw RepositoryStoreHydrationError.accountCurrencyMismatch
        }
        let decimalMoney: Money
        let minorMoney: Money
        do {
            decimalMoney = try Money(canonicalDecimal: dto.amountDecimal, currency: dto.nativeCurrency)
            minorMoney = try Money.fromMinorUnits(dto.amountMinor, currency: dto.nativeCurrency)
        } catch {
            throw RepositoryStoreHydrationError.malformedMoney
        }
        guard decimalMoney == minorMoney else {
            throw RepositoryStoreHydrationError.decimalMinorMismatch
        }
        guard decimalMoney.currency.code == accountDTO.nativeCurrency else {
            throw RepositoryStoreHydrationError.accountCurrencyMismatch
        }
        let runningBalanceMoney = try dto.runningBalanceMinor.map { minor in
            do {
                let money = try Money.fromMinorUnits(minor, currency: dto.nativeCurrency)
                guard money.currency.code == accountDTO.nativeCurrency else {
                    throw RepositoryStoreHydrationError.runningBalanceCurrencyMismatch
                }
                return money
            } catch let error as RepositoryStoreHydrationError {
                throw error
            } catch {
                throw RepositoryStoreHydrationError.malformedMoney
            }
        }
        let absoluteAmount = try Money(amount: abs(decimalMoney.amount), currency: decimalMoney.currency)
        guard let financialDateRole = FinancialDateRole(rawValue: dto.financialDateRole) else {
            throw RepositoryStoreHydrationError.invalidFinancialDateRole(dto.financialDateRole)
        }
        let timezoneEvidence: StatementTimezoneEvidence
        do { timezoneEvidence = try StatementTimezoneEvidence(validatingPersistenceCode: dto.statementTimezoneEvidence) }
        catch { throw RepositoryStoreHydrationError.invalidStatementTimezoneEvidence(dto.statementTimezoneEvidence) }
        let provenance = try dto.rawRows.map { raw -> TransactionSourceProvenance in
            guard !(raw.normalizedDocumentId ?? "").isEmpty,
                  !raw.normalizedRowId.isEmpty,
                  let ordinal = raw.sourceOrdinal, ordinal > 0,
                  !(raw.normalizedRecordDigest ?? "").isEmpty,
                  !(raw.parserProfileId ?? "").isEmpty,
                  !(raw.parserProfileVersion ?? "").isEmpty else {
                throw RepositoryStoreHydrationError.invalidSourceProvenance(dto.id)
            }
            return TransactionSourceProvenance(normalizedDocumentID: raw.normalizedDocumentId!, normalizedRowID: raw.normalizedRowId, sourceOrdinal: ordinal, normalizedRecordDigest: raw.normalizedRecordDigest!, parserProfileID: raw.parserProfileId!, parserProfileVersion: raw.parserProfileVersion!)
        }
        guard !provenance.isEmpty,
              Set(provenance.map(\.normalizedRowID)).count == provenance.count else {
            throw RepositoryStoreHydrationError.invalidSourceProvenance(dto.id)
        }
        let ordinalsByDocument = Dictionary(grouping: provenance, by: \.normalizedDocumentID)
        guard ordinalsByDocument.values.allSatisfy({ Set($0.map(\.sourceOrdinal)).count == $0.count }),
              ordinalsByDocument.values.allSatisfy({ Set($0.map { "\($0.parserProfileID)|\($0.parserProfileVersion)" }).count == 1 }) else {
            throw RepositoryStoreHydrationError.invalidSourceProvenance(dto.id)
        }

        return Transaction(
            statementDate: postedDate,
            description: dto.description ?? "",
            debitMoney: dto.direction == "debit" ? absoluteAmount : nil,
            creditMoney: dto.direction == "credit" ? absoluteAmount : nil,
            money: decimalMoney,
            runningBalanceMoney: runningBalanceMoney,
            account: accountDTO.name,
            sourceBank: accountDTO.institutionId ?? "",
            sourceFile: dto.importSessionId ?? "",
            id: runtimeIdentity(for: dto.id),
            repositoryTransactionId: dto.id,
            financialDateRole: financialDateRole,
            statementTimezoneEvidence: timezoneEvidence,
            sourceProvenance: provenance,
            repositoryAccountId: dto.accountId,
            repositoryImportSessionId: dto.importSessionId
        )
    }

    /// Runtime selection needs a `UUID`, while repository IDs remain opaque immutable strings.
    /// UUID-shaped persisted IDs retain their exact identity. Legacy/test repository IDs receive
    /// only a deterministic UI surrogate; the original durable identity is always exposed by
    /// `repositoryTransactionId` and is never replaced by a newly generated UUID.
    private static func runtimeIdentity(for persistedID: String) -> UUID {
        if let persistedUUID = UUID(uuidString: persistedID) {
            return persistedUUID
        }
        let digest = SHA256.hash(data: Data(persistedID.utf8)).map { String(format: "%02x", $0) }.joined()
        let canonical = "\(digest.prefix(8))-\(digest.dropFirst(8).prefix(4))-\(digest.dropFirst(12).prefix(4))-\(digest.dropFirst(16).prefix(4))-\(digest.dropFirst(20).prefix(12))"
        // A SHA-256 digest always produces a syntactically valid UUID-shaped string here.
        return UUID(uuidString: canonical)!
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

    private static func latestRunningBalance(from transactions: [Transaction], currency: String) throws -> Money? {
        let dated = transactions.compactMap { transaction -> (Transaction, Money)? in
            guard transaction.statementDate != nil, let balance = transaction.runningBalanceMoney else { return nil }
            return (transaction, balance)
        }
        guard let latestDate = dated.compactMap({ $0.0.statementDate }).max() else { return nil }
        let candidates = dated.filter { $0.0.statementDate == latestDate }
        let latest: (Transaction, Money)?
        if let documentID = candidates.first?.0.documentScopedSourceOrder?.documentID,
           candidates.allSatisfy({ $0.0.documentScopedSourceOrder?.documentID == documentID }) {
            latest = candidates.max(by: { ($0.0.documentScopedSourceOrder?.ordinal ?? 0) < ($1.0.documentScopedSourceOrder?.ordinal ?? 0) })
        } else {
            latest = candidates.count == 1 ? candidates.first : nil
        }

        guard let latest else { return nil }
        guard latest.1.currency.code == currency else {
            throw RepositoryStoreHydrationError.runningBalanceCurrencyMismatch
        }
        return latest.1
    }

}
