// LedgerForge
// RepositoryStoreHydrator.swift

import CryptoKit
import Combine
import Foundation

/// A small observable backing wrapper that supports installing a value without
/// notifying synchronous subscribers. Publication is released explicitly only
/// after every value participating in a repository runtime snapshot is coherent.
@propertyWrapper
final class ObserverAtomicPublished<Value> {
    private var value: Value
    private let updates = PassthroughSubject<Value, Never>()

    init(wrappedValue: Value) {
        value = wrappedValue
    }

    var wrappedValue: Value {
        get { value }
        set {
            value = newValue
            updates.send(newValue)
        }
    }

    var projectedValue: AnyPublisher<Value, Never> {
        Deferred { [weak self] () -> AnyPublisher<Value, Never> in
            guard let self else {
                return Empty<Value, Never>(completeImmediately: true).eraseToAnyPublisher()
            }
            return self.updates
                .prepend(self.value)
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func installWithoutObservation(_ value: Value) {
        self.value = value
    }

    func publishInstalledValue() {
        updates.send(value)
    }
}

struct RepositoryStoreHydrationResult: Equatable {
    let didHydrate: Bool
    let accountCount: Int
    let transactionCount: Int
    let importSessionCount: Int
    let importAttemptCount: Int
    let categoryCount: Int
    let categoryAssignmentCount: Int

    init(
        didHydrate: Bool,
        accountCount: Int,
        transactionCount: Int,
        importSessionCount: Int = 0,
        importAttemptCount: Int = 0,
        categoryCount: Int = 0,
        categoryAssignmentCount: Int = 0
    ) {
        self.didHydrate = didHydrate
        self.accountCount = accountCount
        self.transactionCount = transactionCount
        self.importSessionCount = importSessionCount
        self.importAttemptCount = importAttemptCount
        self.categoryCount = categoryCount
        self.categoryAssignmentCount = categoryAssignmentCount
    }
}

/// Complete immutable repository projection prepared before any observer-visible
/// runtime store changes. Only `RepositoryStoreHydrator` can construct it.
struct RepositoryRuntimeSnapshot {
    let accounts: [Account]
    let transactions: [Transaction]
    let importSessions: [RepositoryImportSession]
    let importAttempts: [RepositoryImportAttempt]
    let categorySnapshot: CategorySnapshot
    let hydrationResult: RepositoryStoreHydrationResult
    let providerGeneration: ProviderGenerationToken?

    fileprivate init(
        accounts: [Account],
        transactions: [Transaction],
        importSessions: [RepositoryImportSession],
        importAttempts: [RepositoryImportAttempt],
        categorySnapshot: CategorySnapshot,
        providerGeneration: ProviderGenerationToken?
    ) {
        self.accounts = accounts
        self.transactions = transactions
        self.importSessions = importSessions
        self.importAttempts = importAttempts
        self.categorySnapshot = categorySnapshot
        self.providerGeneration = providerGeneration
        self.hydrationResult = RepositoryStoreHydrationResult(
            didHydrate: true,
            accountCount: accounts.count,
            transactionCount: transactions.count,
            importSessionCount: importSessions.count,
            importAttemptCount: importAttempts.count,
            categoryCount: categorySnapshot.categories.count,
            categoryAssignmentCount: categorySnapshot.assignments.count
        )
    }
}

enum RepositoryStoreHydrationError: Error, LocalizedError, Equatable {
    case persistenceUnavailable
    case unsupportedCurrency(String)
    case invalidPostedDate(String)
    case invalidValueDate(String)
    case invalidFinancialDateRole(String)
    case invalidStatementTimezoneEvidence(String)
    case invalidSourceProvenance(String)
    case malformedMoney
    case decimalMinorMismatch
    case accountCurrencyMismatch
    case runningBalanceCurrencyMismatch
    case invalidPartialImport(String)
    case invalidCategoryState(String)

    var errorDescription: String? {
        switch self {
        case .persistenceUnavailable:
            return "Persistence is unavailable. Runtime data was not replaced."
        case .unsupportedCurrency(let currency):
            return "Currency \(currency) is not supported by dashboard hydration."
        case .invalidPostedDate(let value):
            return "Transaction posted date \(value) could not be read."
        case .invalidValueDate(let value):
            return "Transaction value date \(value) could not be read."
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
        case .invalidPartialImport:
            return "Persisted partial-import provenance is invalid. Runtime data was not replaced."
        case .invalidCategoryState:
            return "Persisted category metadata is invalid. Runtime data was not replaced."
        }
    }
}

final class RepositoryStoreHydrator {

    private let accountRepo: AccountRepository
    private let importSessionRepo: ImportSessionRepository
    private let transactionRepo: TransactionRepository
    private let categoryRepo: CategoryRepository
    private let accountStore: AccountStore
    private let importSessionStore: ImportSessionStore
    private let importAttemptStore: ImportAttemptStore
    private let transactionStore: TransactionStore
    private let categoryStore: CategoryStore
    private let workspaceId: String
    private let persistenceState: PersistenceState
    private let providerGeneration: ProviderGenerationToken?
    private let categoryReconciliationGate: CategoryReconciliationGate?
    private var hasHydrated = false
#if DEBUG
    private let participatesInLifecycleGate: Bool
#endif

    convenience init(
        databaseProvider: DatabaseProvider = .shared,
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared,
        categoryStore: CategoryStore = .shared,
        importSessionStore: ImportSessionStore = .shared,
        importAttemptStore: ImportAttemptStore = .shared,
        workspaceId: String = "default-workspace",
        categoryReconciliationGate: CategoryReconciliationGate? = .shared,
        participatesInLifecycleGate: Bool = true
    ) {
        self.init(
            accountRepo: databaseProvider.accountRepo,
            importSessionRepo: databaseProvider.importSessionRepo,
            transactionRepo: databaseProvider.transactionRepo,
            categoryRepo: databaseProvider.categoryRepo,
            accountStore: accountStore,
            transactionStore: transactionStore,
            categoryStore: categoryStore,
            importSessionStore: importSessionStore,
            importAttemptStore: importAttemptStore,
            workspaceId: workspaceId,
            persistenceState: databaseProvider.persistenceState,
            providerGeneration: databaseProvider.generationToken,
            categoryReconciliationGate: categoryReconciliationGate,
            participatesInLifecycleGate: participatesInLifecycleGate
        )
    }

    init(
        accountRepo: AccountRepository,
        importSessionRepo: ImportSessionRepository,
        transactionRepo: TransactionRepository,
        categoryRepo: CategoryRepository = EmptyCategoryRepo(),
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared,
        categoryStore: CategoryStore = .shared,
        importSessionStore: ImportSessionStore = .shared,
        importAttemptStore: ImportAttemptStore = .shared,
        workspaceId: String = "default-workspace",
        persistenceState: PersistenceState = .intentionalNonDurable(.testMemory),
        providerGeneration: ProviderGenerationToken? = nil,
        categoryReconciliationGate: CategoryReconciliationGate? = nil,
        participatesInLifecycleGate: Bool = true
    ) {
        self.accountRepo = accountRepo
        self.importSessionRepo = importSessionRepo
        self.transactionRepo = transactionRepo
        self.categoryRepo = categoryRepo
        self.accountStore = accountStore
        self.transactionStore = transactionStore
        self.categoryStore = categoryStore
        self.importSessionStore = importSessionStore
        self.importAttemptStore = importAttemptStore
        self.workspaceId = workspaceId
        self.persistenceState = persistenceState
        self.providerGeneration = providerGeneration
        self.categoryReconciliationGate = categoryReconciliationGate
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
                importAttemptCount: importAttemptStore.attempts.count,
                categoryCount: categoryStore.categories.count,
                categoryAssignmentCount: categoryStore.snapshot.assignments.count
            )
        }

        let snapshot = try stageHydration()
        publish(snapshot)
        return snapshot.hydrationResult
    }

    /// Reads and validates one explicit provider generation without changing any
    /// global or injected runtime store.
    func stageHydration() throws -> RepositoryRuntimeSnapshot {
        guard persistenceState.isUsable else {
            throw RepositoryStoreHydrationError.persistenceUnavailable
        }
        let transactionDTOs = try transactionRepo.trustedTransactions(workspaceId: workspaceId)
        let accountDTOs = try accountRepo.accounts(workspaceId: workspaceId)
        let categoryDTOs = try categoryRepo.categories(workspaceId: workspaceId)
        let categoryAssignmentDTOs = try categoryRepo.assignments(workspaceId: workspaceId)
        let identitiesByAccountID = Dictionary(
            uniqueKeysWithValues: try accountDTOs.map { accountDTO in
                (accountDTO.id, try Self.identitySummaries(from: accountRepo.identifiers(accountId: accountDTO.id, workspaceId: workspaceId)))
            }
        )
        let importSessions = try referencedImportSessions(from: transactionDTOs)
        let importedDocumentsByID = try referencedImportedDocuments(from: transactionDTOs)
        let importAttempts = try importSessionRepo.importAttempts(workspaceId: workspaceId).map(RepositoryImportAttempt.init)
        try Self.validatePartialAttemptConsistency(
            sessions: importSessions,
            attempts: importAttempts
        )
        let transactions = try transactionDTOs.map {
            try Self.transaction(
                from: $0,
                accounts: accountDTOs,
                importedDocumentsByID: importedDocumentsByID,
                workspaceID: workspaceId
            )
        }
        let accounts = try Self.accounts(
            from: accountDTOs,
            transactions: transactions,
            identitiesByAccountID: identitiesByAccountID
        )
        let categorySnapshot = try Self.categorySnapshot(
            categories: categoryDTOs,
            assignments: categoryAssignmentDTOs,
            trustedTransactions: transactionDTOs,
            workspaceID: workspaceId
        )

        return RepositoryRuntimeSnapshot(
            accounts: accounts,
            transactions: transactions,
            importSessions: importSessions,
            importAttempts: importAttempts,
            categorySnapshot: categorySnapshot,
            providerGeneration: providerGeneration
        )
    }

    /// Synchronously publishes a previously validated complete snapshot. This
    /// method performs no repository work and acquires no lifecycle lease.
    @MainActor
    func publish(_ snapshot: RepositoryRuntimeSnapshot) {
        installSnapshotWithoutObservation(snapshot)
        notifyObserversOfInstalledSnapshot()
    }

    /// Installs every runtime-store backing value without emitting an
    /// `ObservableObject` or property-publisher notification.
    @MainActor
    func installSnapshotWithoutObservation(_ snapshot: RepositoryRuntimeSnapshot) {
        accountStore.installAccountsWithoutObservation(snapshot.accounts)
        transactionStore.installTransactionsWithoutObservation(
            snapshot.transactions,
            validation: nil
        )
        importSessionStore.installImportSessionsWithoutObservation(snapshot.importSessions)
        importAttemptStore.installAttemptsWithoutObservation(snapshot.importAttempts)
        categoryStore.installSnapshotWithoutObservation(snapshot.categorySnapshot)
        if let providerGeneration = snapshot.providerGeneration {
            categoryReconciliationGate?.clearAfterCanonicalHydration(for: providerGeneration)
        }
        hasHydrated = true
    }

    /// Releases legacy store notifications only after the complete snapshot has
    /// already been installed. Every synchronous callback therefore reads the
    /// same complete backing state, even though legacy notifications are sent
    /// sequentially for compatibility.
    @MainActor
    func notifyObserversOfInstalledSnapshot() {
        accountStore.notifyAccountsOfInstalledValue()
        transactionStore.notifyTransactionsOfInstalledValues()
        importSessionStore.notifyImportSessionsOfInstalledValue()
        importAttemptStore.notifyAttemptsOfInstalledValue()
        categoryStore.notifySnapshotOfInstalledValue()
    }

    private static func categorySnapshot(
        categories: [CategoryDTO],
        assignments: [TransactionCategoryAssignmentDTO],
        trustedTransactions: [TransactionDTO],
        workspaceID: String
    ) throws -> CategorySnapshot {
        guard Set(categories.map(\.id)).count == categories.count,
              categories.allSatisfy({ $0.workspaceId == workspaceID }),
              Set(categories.map(\.normalizedName)).count == categories.count else {
            throw RepositoryStoreHydrationError.invalidCategoryState("category identity or workspace mismatch")
        }

        let runtimeCategories = try categories.map { dto -> Category in
            guard let validated = try? CategoryName.validated(dto.name),
                  dto.normalizedName == validated.normalized,
                  dto.name == validated.display else {
                throw RepositoryStoreHydrationError.invalidCategoryState("invalid category name")
            }
            return Category(
                id: dto.id,
                workspaceID: dto.workspaceId,
                name: dto.name,
                normalizedName: dto.normalizedName,
                isArchived: dto.isArchived
            )
        }.sorted {
            if $0.normalizedName != $1.normalizedName { return $0.normalizedName < $1.normalizedName }
            return $0.id < $1.id
        }

        let categoryIDs = Set(runtimeCategories.map(\.id))
        let trustedTransactionIDs = Set(trustedTransactions.map(\.id))
        guard Set(assignments.map(\.transactionId)).count == assignments.count,
              assignments.allSatisfy({
                  $0.workspaceId == workspaceID &&
                  trustedTransactionIDs.contains($0.transactionId) &&
                  categoryIDs.contains($0.categoryId)
              }) else {
            throw RepositoryStoreHydrationError.invalidCategoryState("invalid assignment relationship")
        }

        return CategorySnapshot(
            categories: runtimeCategories,
            assignments: Dictionary(uniqueKeysWithValues: assignments.map { ($0.transactionId, $0.categoryId) })
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

    private static func validatePartialAttemptConsistency(
        sessions: [RepositoryImportSession],
        attempts: [RepositoryImportAttempt]
    ) throws {
        let partialSessions = sessions.filter { $0.partialImportSummary != nil }
        let partialAttempts = attempts.filter {
            $0.outcomeCode == ImportAttemptOutcome.partialImportCommitted.rawValue &&
            $0.persistenceCode == ImportAttemptPersistence.committed.rawValue
        }
        guard partialAttempts.count == partialSessions.count else {
            throw RepositoryStoreHydrationError.invalidPartialImport("attempt counts disagree")
        }
        for session in partialSessions {
            guard let summary = session.partialImportSummary else { continue }
            let matching = partialAttempts.filter { $0.importSessionId == session.id }
            guard matching.count == 1,
                  let attempt = matching.first,
                  attempt.documentId == summary.documentId,
                  attempt.transactionCount == summary.importedTransactionCount,
                  attempt.sourceRowCount == summary.sourceRowCount,
                  attempt.importedTransactionCount == summary.importedTransactionCount,
                  attempt.recognizedExistingRowCount == summary.recognizedExistingRowCount,
                  attempt.blockedRowCount == summary.blockedRowCount else {
                throw RepositoryStoreHydrationError.invalidPartialImport("attempt counts disagree")
            }
        }
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

        let transactionsByID = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        return try referencedSessionIDs.compactMap { sessionID in
            guard let session = try importSessionRepo.importSession(id: sessionID),
                  session.workspaceId == workspaceId else {
                return nil
            }
            let summaryDTO = try importSessionRepo.partialImportSummary(importSessionId: sessionID)
            let dispositionDTOs = try importSessionRepo.incomingRowDispositions(importSessionId: sessionID)
            let partial = try Self.partialImportRuntime(
                sessionID: sessionID,
                summary: summaryDTO,
                dispositions: dispositionDTOs,
                transactionsByID: transactionsByID
            )
            return RepositoryImportSession(
                id: session.id,
                workspaceId: session.workspaceId,
                sourceDocumentName: session.userVisibleName,
                startedAtISO: session.startedAtISO,
                completedAtISO: session.completedAtISO,
                validationStatus: session.validationStatus,
                parserVersion: session.parserVersion,
                partialImportSummary: partial.summary,
                incomingRowDispositions: partial.dispositions
            )
        }
    }

    private func referencedImportedDocuments(from transactions: [TransactionDTO]) throws -> [String: ImportedDocumentDTO] {
        let referencedDocumentIDs = Set(transactions.compactMap(\.documentId)).sorted()
        var documentsByID: [String: ImportedDocumentDTO] = [:]
        for documentID in referencedDocumentIDs {
            if let document = try importSessionRepo.importedDocument(id: documentID) {
                documentsByID[documentID] = document
            }
        }
        return documentsByID
    }

    private static func partialImportRuntime(
        sessionID: String,
        summary: PartialImportSummaryDTO?,
        dispositions: [IncomingRowDispositionDTO],
        transactionsByID: [String: TransactionDTO]
    ) throws -> (summary: RepositoryPartialImportSummary?, dispositions: [RepositoryIncomingRowDisposition]) {
        guard let summary else {
            guard dispositions.isEmpty else {
                throw RepositoryStoreHydrationError.invalidPartialImport("dispositions without summary")
            }
            return (nil, [])
        }
        guard summary.importSessionId == sessionID,
              summary.planDigestAlgorithm == ReviewedPartialImportPlanDTO.digestAlgorithm,
              !summary.planDigest.isEmpty,
              summary.sourceRowCount > 0,
              summary.importedTransactionCount > 0,
              summary.recognizedExistingRowCount > 0,
              summary.blockedRowCount == 0,
              summary.importedTransactionCount + summary.recognizedExistingRowCount == summary.sourceRowCount,
              dispositions.count == summary.sourceRowCount,
              Set(dispositions.map(\.id)).count == dispositions.count,
              Set(dispositions.map(\.normalizedRowId)).count == dispositions.count,
              Set(dispositions.map(\.sourceOrdinal)).count == dispositions.count,
              let start = try? StatementDate(canonical: summary.statementStartDateISO),
              let end = try? StatementDate(canonical: summary.statementEndDateISO),
              start <= end,
              let opening = try? Money(canonicalDecimal: summary.openingBalanceDecimal, currency: summary.nativeCurrency),
              let closing = try? Money(canonicalDecimal: summary.closingBalanceDecimal, currency: summary.nativeCurrency),
              (try? opening.minorUnits()) == summary.openingBalanceMinor,
              (try? closing.minorUnits()) == summary.closingBalanceMinor else {
            throw RepositoryStoreHydrationError.invalidPartialImport("invalid summary")
        }

        let runtimeRows: [RepositoryIncomingRowDisposition] = try dispositions.sorted { $0.sourceOrdinal < $1.sourceOrdinal }.map { row in
            guard row.importSessionId == sessionID,
                  row.documentId == summary.documentId,
                  row.sourceOrdinal > 0,
                  let code = RepositoryIncomingRowDispositionCode(rawValue: row.dispositionCode),
                  !row.transactionEventIdentityId.isEmpty,
                  row.eventTransactionId == row.transactionId,
                  let transaction = transactionsByID[row.transactionId],
                  transaction.rawRows.contains(where: {
                      $0.normalizedRowId == row.normalizedRowId &&
                      $0.sourceOrdinal == row.sourceOrdinal
                  }),
                  let date = try? StatementDate(canonical: row.statementDateISO),
                  start <= date, date <= end,
                  row.nativeCurrency == summary.nativeCurrency,
                  let amount = try? Money(canonicalDecimal: row.amountDecimal, currency: row.nativeCurrency),
                  let runningBalance = try? Money(
                      amount: Decimal(row.runningBalanceMinor) / Decimal(100),
                      currency: row.nativeCurrency
                  ),
                  (try? amount.minorUnits()) == row.amountMinor,
                  ["debit", "credit"].contains(row.direction),
                  transaction.postedDateISO == row.statementDateISO,
                  transaction.financialDateRole == row.financialDateRole,
                  transaction.statementTimezoneEvidence == row.statementTimezoneEvidence,
                  transaction.nativeCurrency == row.nativeCurrency,
                  transaction.amountMinor == row.amountMinor,
                  transaction.amountDecimal == row.amountDecimal,
                  transaction.direction == row.direction,
                  transaction.runningBalanceMinor == row.runningBalanceMinor else {
                throw RepositoryStoreHydrationError.invalidPartialImport("invalid row disposition")
            }
            return RepositoryIncomingRowDisposition(
                id: row.id,
                documentId: row.documentId,
                normalizedRowId: row.normalizedRowId,
                sourceOrdinal: row.sourceOrdinal,
                code: code,
                transactionId: row.transactionId,
                transactionEventIdentityId: row.transactionEventIdentityId,
                statementDate: date,
                financialDateRole: row.financialDateRole,
                timezoneEvidence: row.statementTimezoneEvidence,
                nativeCurrency: row.nativeCurrency,
                amount: amount,
                direction: row.direction,
                runningBalance: runningBalance
            )
        }
        guard runtimeRows.filter({ $0.code == .importedUnique }).count == summary.importedTransactionCount,
              runtimeRows.filter({ $0.code == .recognizedExisting }).count == summary.recognizedExistingRowCount else {
            throw RepositoryStoreHydrationError.invalidPartialImport("disposition counts disagree")
        }
        return (
            RepositoryPartialImportSummary(
                documentId: summary.documentId,
                statementStartDate: start,
                statementEndDate: end,
                nativeCurrency: summary.nativeCurrency,
                sourceRowCount: summary.sourceRowCount,
                importedTransactionCount: summary.importedTransactionCount,
                recognizedExistingRowCount: summary.recognizedExistingRowCount,
                blockedRowCount: summary.blockedRowCount,
                openingBalance: opening,
                closingBalance: closing
            ),
            runtimeRows
        )
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

    private static func transaction(
        from dto: TransactionDTO,
        accounts: [AccountDTO],
        importedDocumentsByID: [String: ImportedDocumentDTO],
        workspaceID: String
    ) throws -> Transaction {
        guard let postedDate = try? StatementDate(canonical: dto.postedDateISO) else {
            throw RepositoryStoreHydrationError.invalidPostedDate(dto.postedDateISO)
        }
        let valueDate: StatementDate?
        if let value = dto.valueDateISO {
            guard let parsed = try? StatementDate(canonical: value) else {
                throw RepositoryStoreHydrationError.invalidValueDate(value)
            }
            valueDate = parsed
        } else {
            valueDate = nil
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

        let repositorySourceDocumentName: String?
        if let documentID = dto.documentId,
           let document = importedDocumentsByID[documentID],
           document.id == documentID,
           document.workspaceId == workspaceID,
           document.importSessionId == dto.importSessionId {
            let trimmedFilename = document.filename.trimmingCharacters(in: .whitespacesAndNewlines)
            repositorySourceDocumentName = trimmedFilename.isEmpty ? nil : trimmedFilename
        } else {
            repositorySourceDocumentName = nil
        }

        return Transaction(
            statementDate: postedDate,
            valueDate: valueDate,
            description: dto.description ?? "",
            reference: dto.reference,
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
            repositoryImportSessionId: dto.importSessionId,
            repositoryDocumentId: dto.documentId,
            repositorySourceDocumentName: repositorySourceDocumentName
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
