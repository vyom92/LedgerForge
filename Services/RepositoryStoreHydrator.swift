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
    let salaryStatementCount: Int
    let fundingPlanCount: Int

    init(
        didHydrate: Bool,
        accountCount: Int,
        transactionCount: Int,
        importSessionCount: Int = 0,
        importAttemptCount: Int = 0,
        categoryCount: Int = 0,
        categoryAssignmentCount: Int = 0,
        salaryStatementCount: Int = 0,
        fundingPlanCount: Int = 0
    ) {
        self.didHydrate = didHydrate
        self.accountCount = accountCount
        self.transactionCount = transactionCount
        self.importSessionCount = importSessionCount
        self.importAttemptCount = importAttemptCount
        self.categoryCount = categoryCount
        self.categoryAssignmentCount = categoryAssignmentCount
        self.salaryStatementCount = salaryStatementCount
        self.fundingPlanCount = fundingPlanCount
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
    let cardSnapshot: CardStoreSnapshot
    let salaryStatements: [SalaryStatement]
    let fundingPlans: [FundingPlan]
    let hydrationResult: RepositoryStoreHydrationResult
    let providerGeneration: ProviderGenerationToken?

    fileprivate init(
        accounts: [Account],
        transactions: [Transaction],
        importSessions: [RepositoryImportSession],
        importAttempts: [RepositoryImportAttempt],
        categorySnapshot: CategorySnapshot,
        cardSnapshot: CardStoreSnapshot,
        salaryStatements: [SalaryStatement],
        fundingPlans: [FundingPlan],
        providerGeneration: ProviderGenerationToken?
    ) {
        self.accounts = accounts
        self.transactions = transactions
        self.importSessions = importSessions
        self.importAttempts = importAttempts
        self.categorySnapshot = categorySnapshot
        self.cardSnapshot = cardSnapshot
        self.salaryStatements = salaryStatements
        self.fundingPlans = fundingPlans
        self.providerGeneration = providerGeneration
        self.hydrationResult = RepositoryStoreHydrationResult(
            didHydrate: true,
            accountCount: accounts.count,
            transactionCount: transactions.count,
            importSessionCount: importSessions.count,
            importAttemptCount: importAttempts.count,
            categoryCount: categorySnapshot.categories.count,
            categoryAssignmentCount: categorySnapshot.assignments.count,
            salaryStatementCount: salaryStatements.count,
            fundingPlanCount: fundingPlans.count
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
    case invalidStatementEquivalence(String)
    case invalidCategoryState(String)
    case invalidCardState(String)
    case invalidSalaryState(String)
    case invalidFundingPlanState(String)

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
        case .invalidStatementEquivalence:
            return "Persisted statement-equivalence evidence is invalid. Runtime data was not replaced."
        case .invalidCategoryState:
            return "Persisted category metadata is invalid. Runtime data was not replaced."
        case .invalidCardState:
            return "Persisted credit-card evidence is invalid. Runtime data was not replaced."
        case .invalidSalaryState:
            return "Persisted salary evidence is invalid. Runtime data was not replaced."
        case .invalidFundingPlanState:
            return "Persisted funding-plan state is invalid. Runtime data was not replaced."
        }
    }
}

final class RepositoryStoreHydrator {

    private let accountRepo: AccountRepository
    private let importSessionRepo: ImportSessionRepository
    private let transactionRepo: TransactionRepository
    private let categoryRepo: CategoryRepository
    private let cardRepo: CardRepository
    private let salaryRepo: SalaryRepository
    private let fundingPlanRepo: FundingPlanRepository
    private let accountStore: AccountStore
    private let importSessionStore: ImportSessionStore
    private let importAttemptStore: ImportAttemptStore
    private let transactionStore: TransactionStore
    private let categoryStore: CategoryStore
    private let cardStore: CardStore
    private let salaryStore: SalaryStore
    private let fundingPlanStore: FundingPlanStore
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
            cardRepo: databaseProvider.cardRepo,
            salaryRepo: databaseProvider.salaryRepo,
            fundingPlanRepo: databaseProvider.fundingPlanRepo,
            accountStore: accountStore,
            transactionStore: transactionStore,
            categoryStore: categoryStore,
            cardStore: .shared,
            salaryStore: .shared,
            fundingPlanStore: .shared,
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
        cardRepo: CardRepository = EmptyCardRepo(),
        salaryRepo: SalaryRepository = EmptySalaryRepo(),
        fundingPlanRepo: FundingPlanRepository = EmptyFundingPlanRepo(),
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared,
        categoryStore: CategoryStore = .shared,
        cardStore: CardStore = .shared,
        salaryStore: SalaryStore = .shared,
        fundingPlanStore: FundingPlanStore = .shared,
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
        self.cardRepo = cardRepo
        self.salaryRepo = salaryRepo
        self.fundingPlanRepo = fundingPlanRepo
        self.accountStore = accountStore
        self.transactionStore = transactionStore
        self.categoryStore = categoryStore
        self.cardStore = cardStore
        self.salaryStore = salaryStore
        self.fundingPlanStore = fundingPlanStore
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
                categoryAssignmentCount: categoryStore.snapshot.assignments.count,
                salaryStatementCount: salaryStore.statements.count,
                fundingPlanCount: fundingPlanStore.plans.count
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
        let cardDTOs = try cardRepo.snapshot(workspaceId: workspaceId)
        let salaryDTOs = try salaryRepo.snapshot(workspaceId: workspaceId)
        let fundingPlanDTOs = try fundingPlanRepo.plans(workspaceId: workspaceId)
        let identitiesByAccountID = Dictionary(
            uniqueKeysWithValues: try accountDTOs.map { accountDTO in
                (accountDTO.id, try Self.identitySummaries(from: accountRepo.identifiers(accountId: accountDTO.id, workspaceId: workspaceId)))
            }
        )
        let preferredSources = try importSessionRepo.preferredTransactionSources(workspaceId: workspaceId)
        let preferredSourcesByTransactionID = Dictionary(uniqueKeysWithValues: preferredSources.map { ($0.transactionId, $0) })
        var importedDocumentsByID = try referencedImportedDocuments(from: transactionDTOs)
        for documentID in Set(salaryDTOs.statements.map(\.documentId)) where importedDocumentsByID[documentID] == nil {
            if let document = try importSessionRepo.importedDocument(id: documentID) {
                importedDocumentsByID[documentID] = document
            }
        }
        for documentID in Set(preferredSources.map(\.documentId)) where importedDocumentsByID[documentID] == nil {
            if let document = try importSessionRepo.importedDocument(id: documentID) {
                importedDocumentsByID[documentID] = document
            }
        }
        let importAttempts = try importSessionRepo.importAttempts(workspaceId: workspaceId).map(RepositoryImportAttempt.init)
        let statementProjections = try importSessionRepo.statementFinancialProjections(workspaceId: workspaceId)
        let statementGroups = try importSessionRepo.statementEquivalenceGroups(workspaceId: workspaceId)
        let statementMembers = try importSessionRepo.statementEquivalenceMembers(workspaceId: workspaceId)
        let importSessions = try referencedImportSessions(
            from: transactionDTOs,
            statementProjections: statementProjections,
            salaryStatements: salaryDTOs.statements
        )
        try Self.validatePartialAttemptConsistency(
            sessions: importSessions,
            attempts: importAttempts
        )
        try validateStatementEquivalenceConsistency(
            projections: statementProjections,
            groups: statementGroups,
            members: statementMembers,
            accounts: accountDTOs,
            transactions: transactionDTOs,
            attempts: importAttempts
        )
        let cardEvidenceByTransactionID = Dictionary(uniqueKeysWithValues: cardDTOs.transactionEvidence.map { ($0.transactionId, $0) })
        let transactions = try transactionDTOs.map {
            try Self.transaction(
                from: $0,
                accounts: accountDTOs,
                importedDocumentsByID: importedDocumentsByID,
                preferredSource: preferredSourcesByTransactionID[$0.id],
                workspaceID: workspaceId,
                cardEvidence: cardEvidenceByTransactionID[$0.id]
            )
        }
        let cardSnapshot = try Self.cardSnapshot(
            from: cardDTOs,
            accounts: accountDTOs,
            transactions: transactionDTOs,
            workspaceID: workspaceId
        )
        let accounts = try Self.accounts(
            from: accountDTOs,
            transactions: transactions,
            identitiesByAccountID: identitiesByAccountID,
            cardSnapshot: cardSnapshot
        )
        let categorySnapshot = try Self.categorySnapshot(
            categories: categoryDTOs,
            assignments: categoryAssignmentDTOs,
            trustedTransactions: transactionDTOs,
            workspaceID: workspaceId
        )
        let salaryStatements = try Self.salaryStatements(from: salaryDTOs, workspaceID: workspaceId)
        let fundingPlans = try Self.fundingPlans(from: fundingPlanDTOs, accounts: accountDTOs, workspaceID: workspaceId)

        return RepositoryRuntimeSnapshot(
            accounts: accounts,
            transactions: transactions,
            importSessions: importSessions,
            importAttempts: importAttempts,
            categorySnapshot: categorySnapshot,
            cardSnapshot: cardSnapshot,
            salaryStatements: salaryStatements,
            fundingPlans: fundingPlans,
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
        cardStore.installSnapshotWithoutObservation(snapshot.cardSnapshot)
        salaryStore.installWithoutObservation(snapshot.salaryStatements)
        fundingPlanStore.installWithoutObservation(snapshot.fundingPlans)
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
        cardStore.notifySnapshotOfInstalledValue()
        salaryStore.notifyInstalledValue()
        fundingPlanStore.notifyInstalledValue()
    }

    private static func salaryStatements(
        from snapshot: SalaryRepositorySnapshotDTO,
        workspaceID: String
    ) throws -> [SalaryStatement] {
        guard Set(snapshot.statements.map(\.id)).count == snapshot.statements.count,
              snapshot.statements.allSatisfy({ $0.workspaceId == workspaceID }) else {
            throw RepositoryStoreHydrationError.invalidSalaryState("statement identity or workspace mismatch")
        }
        return try snapshot.statements.map { dto in
            guard dto.sourceAuthorityCode == SalarySourceAuthority.qatarAirways.rawValue,
                  dto.parserProfileId == SalaryStatementEvidence.profileID,
                  dto.parserProfileVersion == SalaryStatementEvidence.profileVersion,
                  let authority = SalarySourceAuthority(rawValue: dto.sourceAuthorityCode),
                  let kind = SalaryDocumentKind(rawValue: dto.documentKindCode),
                  let period = try? SelectedStatementMonth(canonical: dto.financialPeriodISO),
                  let currency = try? CurrencyCode(dto.nativeCurrency),
                  dto.sourceFingerprintDigest.count == 64 else {
                throw RepositoryStoreHydrationError.invalidSalaryState("unsupported source identity")
            }
            let printDate: StatementDate?
            if let value = dto.printDateISO {
                guard let parsed = try? StatementDate(canonical: value) else {
                    throw RepositoryStoreHydrationError.invalidSalaryState("invalid print date")
                }
                printDate = parsed
            } else { printDate = nil }
            let earningsDTOs = dto.components.filter { $0.sideCode == SalaryComponentSide.earning.rawValue }
                .sorted { $0.sourceOrdinal < $1.sourceOrdinal }
            let deductionsDTOs = dto.components.filter { $0.sideCode == SalaryComponentSide.deduction.rawValue }
                .sorted { $0.sourceOrdinal < $1.sourceOrdinal }
            guard earningsDTOs.count + deductionsDTOs.count == dto.components.count,
                  Set(dto.components.map(\.id)).count == dto.components.count else {
                throw RepositoryStoreHydrationError.invalidSalaryState("invalid component side or identity")
            }
            func component(_ value: SalaryComponentDTO, side: SalaryComponentSide) throws -> SalaryComponent {
                let money = try persistedMoney(currency: value.amountCurrency, minor: value.amountMinor, decimal: value.amountDecimal)
                do { return try SalaryComponent(side: side, sourceOrdinal: value.sourceOrdinal, sourceLabel: value.sourceLabel, money: money) }
                catch { throw RepositoryStoreHydrationError.invalidSalaryState("invalid component") }
            }
            let earnings = try earningsDTOs.map { try component($0, side: .earning) }
            let deductions = try deductionsDTOs.map { try component($0, side: .deduction) }
            let printedEarnings = try persistedMoney(currency: dto.nativeCurrency, minor: dto.printedEarningsMinor, decimal: dto.printedEarningsDecimal)
            let printedDeductions: Money?
            switch (dto.printedDeductionsMinor, dto.printedDeductionsDecimal) {
            case let (minor?, decimal?):
                printedDeductions = try persistedMoney(currency: dto.nativeCurrency, minor: minor, decimal: decimal)
            case (nil, nil):
                printedDeductions = nil
            default:
                throw RepositoryStoreHydrationError.invalidSalaryState("partial optional deduction total")
            }
            let evidence: SalaryStatementEvidence
            do {
                evidence = try SalaryStatementEvidence(
                    sourceAuthority: authority,
                    profileID: dto.parserProfileId,
                    profileVersion: dto.parserProfileVersion,
                    financialPeriod: period,
                    printDate: printDate,
                    kind: kind,
                    nativeCurrency: currency,
                    earnings: earnings,
                    deductions: deductions,
                    printedEarningsTotal: printedEarnings,
                    printedDeductionsTotal: printedDeductions,
                    printedNet: try persistedMoney(currency: dto.nativeCurrency, minor: dto.printedNetMinor, decimal: dto.printedNetDecimal),
                    printedPaymentTotal: try persistedMoney(currency: dto.nativeCurrency, minor: dto.printedPaymentMinor, decimal: dto.printedPaymentDecimal)
                )
            } catch {
                throw RepositoryStoreHydrationError.invalidSalaryState("salary arithmetic or source evidence mismatch")
            }
            return SalaryStatement(
                id: dto.id,
                workspaceID: dto.workspaceId,
                documentID: dto.documentId,
                importSessionID: dto.importSessionId,
                fingerprintAlgorithm: dto.sourceFingerprintAlgorithm,
                fingerprintDigest: dto.sourceFingerprintDigest,
                evidence: evidence,
                importedAtISO: dto.createdAtISO
            )
        }
    }

    private static func fundingPlans(
        from dtos: [FundingPlanDTO],
        accounts: [AccountDTO],
        workspaceID: String
    ) throws -> [FundingPlan] {
        guard Set(dtos.map(\.id)).count == dtos.count,
              Set(dtos.map(\.planMonthISO)).count == dtos.count,
              dtos.allSatisfy({ $0.workspaceId == workspaceID }) else {
            throw RepositoryStoreHydrationError.invalidFundingPlanState("plan identity or workspace mismatch")
        }
        let accountIDs = Set(accounts.filter { $0.workspaceId == workspaceID }.map(\.id))
        let planIDs = Set(dtos.map(\.id))
        return try dtos.map { dto in
            guard let month = try? SelectedStatementMonth(canonical: dto.planMonthISO),
                  dto.rolloverSourcePlanId.map(planIDs.contains) ?? true else {
                throw RepositoryStoreHydrationError.invalidFundingPlanState("invalid month or rollover")
            }
            func inputProvenance(_ code: String) throws -> FundingPlanValueProvenance {
                switch code {
                case "manual": return .manual
                case "carried":
                    guard let source = dto.rolloverSourcePlanId else {
                        throw RepositoryStoreHydrationError.invalidFundingPlanState("carried input without rollover source")
                    }
                    return .carried(sourcePlanID: source)
                default: throw RepositoryStoreHydrationError.invalidFundingPlanState("invalid input provenance")
                }
            }
            let expectedBalanceOrdinals = dto.balances.isEmpty ? [] : Array(1...dto.balances.count)
            guard dto.balances.map(\.sourceOrdinal) == expectedBalanceOrdinals,
                  Set(dto.balances.map(\.id)).count == dto.balances.count,
                  Set(dto.balances.map(\.accountId)).count == dto.balances.count else {
                throw RepositoryStoreHydrationError.invalidFundingPlanState("invalid balance identity or order")
            }
            let balances = try dto.balances.map { value -> FundingPlanBalance in
                guard value.planId == dto.id, accountIDs.contains(value.accountId),
                      let nativeCurrency = try? CurrencyCode(value.nativeCurrency),
                      ["QAR", "INR"].contains(nativeCurrency.code) else {
                    throw RepositoryStoreHydrationError.invalidFundingPlanState("invalid balance relationship")
                }
                let money: Money?
                switch (value.amountCurrency, value.amountMinor, value.amountDecimal) {
                case let (currency?, minor?, decimal?):
                    money = try persistedMoney(currency: currency, minor: minor, decimal: decimal)
                    guard money?.currency == nativeCurrency else {
                        throw RepositoryStoreHydrationError.invalidFundingPlanState("balance currency mismatch")
                    }
                case (nil, nil, nil): money = nil
                default: throw RepositoryStoreHydrationError.invalidFundingPlanState("partial planning balance")
                }
                let provenance: FundingPlanValueProvenance
                switch value.provenanceCode {
                case "manual" where value.carriedSourcePlanId == nil && value.capturedAtISO == nil:
                    provenance = .manual
                case "carried" where value.capturedAtISO == nil:
                    guard let source = value.carriedSourcePlanId, planIDs.contains(source) else {
                        throw RepositoryStoreHydrationError.invalidFundingPlanState("invalid carried balance")
                    }
                    provenance = .carried(sourcePlanID: source)
                case "captured_account_balance" where value.carriedSourcePlanId == nil:
                    guard let captured = value.capturedAtISO, !captured.isEmpty else {
                        throw RepositoryStoreHydrationError.invalidFundingPlanState("invalid captured balance")
                    }
                    provenance = .capturedAccountBalance(capturedAtISO: captured)
                default: throw RepositoryStoreHydrationError.invalidFundingPlanState("invalid balance provenance")
                }
                return FundingPlanBalance(id: value.id, accountID: value.accountId, nativeCurrency: nativeCurrency, included: value.included, money: money, provenance: provenance)
            }
            func commitments(region: String, currency: String) throws -> [FundingPlanCommitment] {
                let values = dto.commitments.filter { $0.regionCode == region }.sorted { $0.sourceOrdinal < $1.sourceOrdinal }
                let expectedOrdinals = values.isEmpty ? [] : Array(1...values.count)
                guard values.map(\.sourceOrdinal) == expectedOrdinals else {
                    throw RepositoryStoreHydrationError.invalidFundingPlanState("invalid commitment order")
                }
                return try values.map { value in
                    guard value.planId == dto.id,
                          value.fundingAccountId.map(accountIDs.contains) ?? true else {
                        throw RepositoryStoreHydrationError.invalidFundingPlanState("invalid commitment relationship")
                    }
                    let provenance: FundingPlanValueProvenance
                    if value.provenanceCode == "manual", value.carriedSourcePlanId == nil { provenance = .manual }
                    else if value.provenanceCode == "carried", let source = value.carriedSourcePlanId, planIDs.contains(source) { provenance = .carried(sourcePlanID: source) }
                    else { throw RepositoryStoreHydrationError.invalidFundingPlanState("invalid commitment provenance") }
                    return FundingPlanCommitment(
                        id: value.id,
                        label: value.label,
                        money: try persistedMoney(currency: currency, minor: value.amountMinor, decimal: value.amountDecimal),
                        included: value.included,
                        fundingAccountID: value.fundingAccountId,
                        provenance: provenance
                    )
                }
            }
            let fx: FundingPlanFX?
            switch (dto.fxINRPerQARDecimal, dto.fxObservationDateISO) {
            case let (decimal?, date?):
                guard let value = Decimal(string: decimal, locale: Locale(identifier: "en_US_POSIX")),
                      let observed = try? StatementDate(canonical: date) else {
                    throw RepositoryStoreHydrationError.invalidFundingPlanState("invalid planning FX")
                }
                fx = try FundingPlanFX(inrPerQAR: value, observationDate: observed)
            case (nil, nil): fx = nil
            default: throw RepositoryStoreHydrationError.invalidFundingPlanState("partial planning FX")
            }
            return FundingPlan(
                id: dto.id,
                workspaceID: dto.workspaceId,
                month: month,
                rolloverSourcePlanID: dto.rolloverSourcePlanId,
                expectedFixedEarnings: try persistedMoney(currency: "QAR", minor: dto.expectedFixedMinor, decimal: dto.expectedFixedDecimal),
                expectedFixedProvenance: try inputProvenance(dto.expectedFixedProvenance),
                expectedVariableEarnings: try persistedMoney(currency: "QAR", minor: dto.expectedVariableMinor, decimal: dto.expectedVariableDecimal),
                expectedVariableProvenance: try inputProvenance(dto.expectedVariableProvenance),
                expectedDeductions: try persistedMoney(currency: "QAR", minor: dto.expectedDeductionsMinor, decimal: dto.expectedDeductionsDecimal),
                expectedDeductionsProvenance: try inputProvenance(dto.expectedDeductionsProvenance),
                balances: balances,
                qatarCommitments: try commitments(region: "qatar", currency: "QAR"),
                indiaCommitments: try commitments(region: "india", currency: "INR"),
                configuredTransferFee: try persistedMoney(currency: "QAR", minor: dto.configuredFeeMinor, decimal: dto.configuredFeeDecimal),
                configuredTransferFeeProvenance: try inputProvenance(dto.configuredFeeProvenance),
                planningFX: fx,
                plannedInvestment: try persistedMoney(currency: "QAR", minor: dto.plannedInvestmentMinor, decimal: dto.plannedInvestmentDecimal),
                plannedInvestmentProvenance: try inputProvenance(dto.plannedInvestmentProvenance),
                updatedAtISO: dto.updatedAtISO
            )
        }
    }

    private static func persistedMoney(currency: String, minor: Int64, decimal: String) throws -> Money {
        do {
            let byMinor = try Money.fromMinorUnits(minor, currency: currency)
            let byDecimal = try Money(canonicalDecimal: decimal, currency: currency)
            guard byMinor == byDecimal else { throw RepositoryStoreHydrationError.decimalMinorMismatch }
            return byMinor
        } catch let error as RepositoryStoreHydrationError { throw error }
        catch { throw RepositoryStoreHydrationError.malformedMoney }
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

    private func validateStatementEquivalenceConsistency(
        projections: [StatementFinancialProjectionRecordDTO],
        groups: [StatementEquivalenceGroupDTO],
        members: [StatementEquivalenceMemberDTO],
        accounts: [AccountDTO],
        transactions: [TransactionDTO],
        attempts: [RepositoryImportAttempt]
    ) throws {
        guard Set(projections.map(\.projection.id)).count == projections.count,
              Set(groups.map(\.id)).count == groups.count,
              Set(members.map(\.id)).count == members.count,
              Set(members.map(\.projectionID)).count == members.count else {
            throw RepositoryStoreHydrationError.invalidStatementEquivalence("duplicate identity")
        }
        let accountIDs = Set(accounts.map(\.id))
        let projectionByID = Dictionary(uniqueKeysWithValues: projections.map { ($0.projection.id, $0) })
        for record in projections {
            guard record.workspaceID == workspaceId,
                  accountIDs.contains(record.accountID),
                  record.projection.isValid(),
                  let session = try importSessionRepo.importSession(id: record.importSessionID),
                  session.workspaceId == workspaceId,
                  let document = try importSessionRepo.importedDocument(id: record.documentID),
                  document.workspaceId == workspaceId,
                  document.importSessionId == record.importSessionID else {
                throw RepositoryStoreHydrationError.invalidStatementEquivalence("projection relationship")
            }
        }
        for group in groups {
            let groupMembers = members.filter { $0.groupID == group.id }
            guard group.workspaceID == workspaceId,
                  accountIDs.contains(group.accountID),
                  groupMembers.count >= 1,
                  groupMembers.count <= 2,
                  Set(groupMembers.map(\.sourceFormatCode)).count == groupMembers.count,
                  groupMembers.filter({ $0.role == .authoritative }).count == 1,
                  let authoritative = projectionByID[group.authoritativeProjectionID],
                  authoritative.accountID == group.accountID,
                  authoritative.projection.algorithmIdentifier == group.projectionAlgorithm,
                  authoritative.projection.digest == group.projectionDigest,
                  groupMembers.contains(where: {
                      $0.role == .authoritative && $0.projectionID == group.authoritativeProjectionID
                  }) else {
                throw RepositoryStoreHydrationError.invalidStatementEquivalence("group relationship")
            }
            for member in groupMembers {
                guard let record = projectionByID[member.projectionID],
                      record.accountID == group.accountID,
                      record.projection.institutionCode == group.institutionCode,
                      record.projection.statementFamilyCode == group.statementFamilyCode,
                      record.projection.statementStartDateISO == group.statementStartDateISO,
                      record.projection.statementEndDateISO == group.statementEndDateISO,
                      record.projection.nativeCurrency == group.nativeCurrency,
                      record.projection.algorithmIdentifier == group.projectionAlgorithm,
                      record.projection.digest == group.projectionDigest,
                      record.projection.sourceFormatCode == member.sourceFormatCode else {
                    throw RepositoryStoreHydrationError.invalidStatementEquivalence("member relationship")
                }
                let ownedTransactions = transactions.filter {
                    $0.importSessionId == record.importSessionID || $0.documentId == record.documentID
                }
                switch member.role {
                case .authoritative:
                    guard ownedTransactions.count == record.projection.eventCount else {
                        throw RepositoryStoreHydrationError.invalidStatementEquivalence("authoritative transaction ownership")
                    }
                case .supporting:
                    guard ownedTransactions.isEmpty,
                          attempts.contains(where: {
                              $0.importSessionId == record.importSessionID &&
                              $0.outcomeCode == ImportAttemptOutcome.equivalentSourceRecorded.rawValue &&
                              $0.transactionCount == 0
                          }) else {
                        throw RepositoryStoreHydrationError.invalidStatementEquivalence("supporting transaction ownership")
                    }
                }
            }
        }
        guard Set(members.map(\.projectionID)) == Set(projections.map(\.projection.id)) else {
            throw RepositoryStoreHydrationError.invalidStatementEquivalence("orphan projection")
        }
    }

    private func referencedImportSessions(
        from transactions: [TransactionDTO],
        statementProjections: [StatementFinancialProjectionRecordDTO],
        salaryStatements: [SalaryStatementDTO]
    ) throws -> [RepositoryImportSession] {
        var referencedSessionIDs = Set(
            transactions.compactMap { transaction -> String? in
                guard transaction.accountId != nil, let importSessionId = transaction.importSessionId else {
                    return nil
                }
                return importSessionId
            }
        )
        referencedSessionIDs.formUnion(statementProjections.map(\.importSessionID))
        referencedSessionIDs.formUnion(salaryStatements.map(\.importSessionId))

        let transactionsByID = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        return try referencedSessionIDs.sorted().compactMap { sessionID in
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

    private static func cardSnapshot(
        from snapshot: CardRepositorySnapshotDTO,
        accounts: [AccountDTO],
        transactions: [TransactionDTO],
        workspaceID: String
    ) throws -> CardStoreSnapshot {
        let accountByID = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        let transactionByID = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        guard Set(snapshot.instruments.map(\.id)).count == snapshot.instruments.count,
              Set(snapshot.sourceObservations.map(\.id)).count == snapshot.sourceObservations.count,
              Set(snapshot.relationships.map(\.id)).count == snapshot.relationships.count,
              Set(snapshot.statements.map(\.id)).count == snapshot.statements.count,
              Set(snapshot.summaryComponents.map(\.id)).count == snapshot.summaryComponents.count,
              Set(snapshot.transactionEvidence.map(\.id)).count == snapshot.transactionEvidence.count,
              Set(snapshot.transactionEvidence.map(\.transactionId)).count == snapshot.transactionEvidence.count,
              Set(snapshot.sections.map(\.id)).count == snapshot.sections.count,
              Set(snapshot.sectionObservations.map(\.id)).count == snapshot.sectionObservations.count,
              Set(snapshot.semanticProjections.map(\.id)).count == snapshot.semanticProjections.count,
              Set(snapshot.semanticGroups.map(\.id)).count == snapshot.semanticGroups.count,
              Set(snapshot.semanticMembers.map(\.id)).count == snapshot.semanticMembers.count else {
            throw RepositoryStoreHydrationError.invalidCardState("duplicate durable identity")
        }

        let instrumentByID = Dictionary(uniqueKeysWithValues: snapshot.instruments.map { ($0.id, $0) })
        let statementByID = Dictionary(uniqueKeysWithValues: snapshot.statements.map { ($0.id, $0) })
        let sectionByID = Dictionary(uniqueKeysWithValues: snapshot.sections.map { ($0.id, $0) })
        let projectionByID = Dictionary(uniqueKeysWithValues: snapshot.semanticProjections.map { ($0.id, $0) })
        let groupByID = Dictionary(uniqueKeysWithValues: snapshot.semanticGroups.map { ($0.id, $0) })
        let instrumentIDs = Set(snapshot.instruments.map(\.id))
        guard snapshot.instrumentIdentifiers.allSatisfy({
            $0.workspaceId == workspaceID && instrumentIDs.contains($0.instrumentId)
        }), Set(snapshot.instrumentIdentifiers.map { "\($0.workspaceId)|\($0.scheme)|\($0.identifier)" }).count == snapshot.instrumentIdentifiers.count else {
            throw RepositoryStoreHydrationError.invalidCardState("instrument identifier ownership")
        }

        let runtimeInstruments = try snapshot.instruments.map { instrument -> CardInstrument in
            guard instrument.workspaceId == workspaceID,
                  let account = accountByID[instrument.liabilityAccountId],
                  account.workspaceId == workspaceID,
                  account.accountType == "credit_card",
                  let lifecycle = CardInstrumentLifecycleState(rawValue: instrument.lifecycleStateCode) else {
                throw RepositoryStoreHydrationError.invalidCardState("instrument account relationship")
            }
            let contract: CardStatementProfileContract
            let expectedObservationKind: CardSourceIdentityObservationKind
            switch account.institutionId {
            case Institution.amex.rawValue where account.nativeCurrency == "QAR":
                contract = .amex
                expectedObservationKind = .instrumentCardAccountNumber
            case Institution.cbq.rawValue where account.nativeCurrency == "QAR":
                contract = .cbqV1
                expectedObservationKind = .cbqInstrumentMaskedCardNumber
            default:
                throw RepositoryStoreHydrationError.invalidCardState("instrument account relationship")
            }
            let legacyObservations = try snapshot.sourceObservations.filter {
                $0.subjectKind == CardSourceIdentitySubject.instrument.rawValue && $0.subjectId == instrument.id
            }.map { observation -> CardSourceIdentityObservation in
                guard observation.workspaceId == workspaceID,
                      let kind = CardSourceIdentityObservationKind(rawValue: observation.observationKind),
                      kind == expectedObservationKind,
                      contract.accepts(profileID: observation.parserProfileId),
                      observation.parserProfileVersion == contract.profileVersion else {
                    throw RepositoryStoreHydrationError.invalidCardState("instrument source observation")
                }
                return try CardSourceIdentityObservation(kind: kind, subject: .instrument, value: observation.sourceValue)
            }
            let sectionScopedObservations = try snapshot.sectionObservations.filter {
                sectionByID[$0.cardStatementSectionId]?.instrumentId == instrument.id
            }.map { observation -> CardSourceIdentityObservation in
                guard observation.workspaceId == workspaceID,
                      observation.observationKind == expectedObservationKind.rawValue,
                      contract.accepts(profileID: observation.parserProfileId),
                      observation.parserProfileVersion == contract.profileVersion else {
                    throw RepositoryStoreHydrationError.invalidCardState("section source observation")
                }
                return try CardSourceIdentityObservation(
                    kind: expectedObservationKind,
                    subject: .instrument,
                    value: observation.sourceValue
                )
            }
            return CardInstrument(
                id: instrument.id,
                workspaceID: instrument.workspaceId,
                liabilityAccountID: instrument.liabilityAccountId,
                lifecycleState: lifecycle,
                createdAtISO: instrument.createdAtISO,
                sourceObservations: legacyObservations + sectionScopedObservations
            )
        }.sorted { $0.id < $1.id }

        let runtimeRelationships = try snapshot.relationships.map { relationship -> CardInstrumentRelationship in
            guard relationship.workspaceId == workspaceID,
                  relationship.predecessorInstrumentId != relationship.successorInstrumentId,
                  instrumentByID[relationship.predecessorInstrumentId]?.liabilityAccountId == relationship.liabilityAccountId,
                  instrumentByID[relationship.successorInstrumentId]?.liabilityAccountId == relationship.liabilityAccountId,
                  let kind = CardInstrumentRelationshipKind(rawValue: relationship.relationshipKind),
                  ["user_confirmed", "source_proven"].contains(relationship.authority) else {
                throw RepositoryStoreHydrationError.invalidCardState("instrument relationship")
            }
            let effectiveDate: StatementDate?
            if let value = relationship.effectiveDateISO {
                effectiveDate = try StatementDate(canonical: value)
            } else {
                effectiveDate = nil
            }
            return CardInstrumentRelationship(
                id: relationship.id,
                liabilityAccountID: relationship.liabilityAccountId,
                predecessorInstrumentID: relationship.predecessorInstrumentId,
                successorInstrumentID: relationship.successorInstrumentId,
                kind: kind,
                authority: relationship.authority,
                effectiveDate: effectiveDate,
                createdAtISO: relationship.createdAtISO
            )
        }

        var runtimeStatements = [CardStatement]()
        var runtimeEvidence = [DurableCardTransactionEvidence]()
        for statement in snapshot.statements {
            guard let contract = CardStatementProfileContract(
                    reconciliationRuleIdentifier: statement.reconciliationRuleCode
                  ),
                  statement.workspaceId == workspaceID,
                  let statementAccount = accountByID[statement.liabilityAccountId],
                  statementAccount.accountType == "credit_card",
                  statementAccount.institutionId == contract.institutionCode,
                  contract.accepts(profileID: statement.parserProfileId),
                  statement.parserProfileVersion == contract.profileVersion,
                  statement.statementCurrency == (contract == .axis ? "INR" : "QAR"),
                  statement.sourceRowCount > 0 else {
                throw RepositoryStoreHydrationError.invalidCardState("statement relationship")
            }
            let statementComponents = snapshot.summaryComponents.filter { $0.cardStatementId == statement.id }
            let sourceFormat = statement.parserProfileId.hasSuffix(".xlsx") ? "xlsx" : "pdf"
            let summaryCodes = Set(statementComponents.map(\.componentCode))
            let summaryCoverageIsValid = contract == .axis
                ? summaryCodes.isSubset(of: contract.allowedSummaryCodes)
                : summaryCodes == contract.requiredSummaryCodes(
                    reconciliationRuleIdentifier: statement.reconciliationRuleCode,
                    sourceFormatCode: sourceFormat
                )
            guard summaryCoverageIsValid, summaryCodes.count == statementComponents.count else {
                throw RepositoryStoreHydrationError.invalidCardState("statement summary coverage")
            }
            let components: [CardStatementSummaryComponent] = try statementComponents.map { component in
                if component.componentCode == "due_date" {
                    guard let dateISO = component.dateISO, component.moneyCurrency == nil,
                          component.moneyMinor == nil, component.moneyDecimal == nil else {
                        throw RepositoryStoreHydrationError.invalidCardState("due-date component")
                    }
                    let date = try StatementDate(canonical: dateISO)
                    return .dueDate(date)
                }
                guard component.dateISO == nil, let currency = component.moneyCurrency,
                      let minor = component.moneyMinor, let decimal = component.moneyDecimal,
                      let decimalMoney = try? Money(canonicalDecimal: decimal, currency: currency),
                      let minorMoney = try? Money.fromMinorUnits(minor, currency: currency),
                      decimalMoney == minorMoney, currency == statement.statementCurrency else {
                    throw RepositoryStoreHydrationError.invalidCardState("money summary component")
                }
                switch component.componentCode {
                case "previous_balance": return .previousBalance(decimalMoney)
                case "new_credits": return .newCredits(decimalMoney)
                case "new_debits": return .newDebits(decimalMoney)
                case "amount_billed": return .amountBilled(decimalMoney)
                case "payment_received": return .paymentReceived(decimalMoney)
                case "total_payment": return .totalPayment(decimalMoney)
                case "credit_reversal": return .creditReversal(decimalMoney)
                case "purchases": return .purchases(decimalMoney)
                case "billed_installment": return .billedInstallment(decimalMoney)
                case "fees_charges": return .feesCharges(decimalMoney)
                case "new_balance": return .newBalance(decimalMoney)
                case "instrument_net_total": return .instrumentNetTotal(decimalMoney)
                case "source_section_net_total": return .sourceSectionNetTotal(decimalMoney)
                case "axis_total_payment_due": return .axisTotalPaymentDue(decimalMoney)
                default: throw RepositoryStoreHydrationError.invalidCardState("unknown summary component")
                }
            }
            let componentByCode = Dictionary(uniqueKeysWithValues: components.map { ($0.persistenceCode, $0) })
            let previous = componentByCode["previous_balance"]?.money
            let balance = componentByCode[contract == .axis ? "axis_total_payment_due" : "new_balance"]?.money
            guard contract == .axis || (previous != nil && balance != nil) else {
                throw RepositoryStoreHydrationError.invalidCardState("summary balance coverage")
            }
            let durableSections = snapshot.sections.filter { $0.cardStatementId == statement.id }
                .sorted { $0.sourceOrdinal < $1.sourceOrdinal }
            guard (contract == .axis ? durableSections.isEmpty : !durableSections.isEmpty),
                  durableSections.map(\.sourceOrdinal) == durableSections.indices.map({ $0 + 1 }),
                  Set(durableSections.map(\.documentScopedSectionId)).count == durableSections.count else {
                throw RepositoryStoreHydrationError.invalidCardState("statement section coverage")
            }
            let runtimeSections: [CardStatementSection] = try durableSections.map { section in
                guard let sectionRule = contract.sectionRule,
                      let instrumentObservationKindCode = contract.instrumentObservationKindCode,
                      let instrument = instrumentByID[section.instrumentId],
                      instrument.liabilityAccountId == statement.liabilityAccountId,
                      section.signedTotalCurrency == statement.statementCurrency,
                      section.reconciliationRuleCode == sectionRule,
                      let byDecimal = try? Money(
                        canonicalDecimal: section.signedTotalDecimal,
                        currency: section.signedTotalCurrency
                      ), let byMinor = try? Money.fromMinorUnits(
                        section.signedTotalMinor,
                        currency: section.signedTotalCurrency
                      ), byDecimal == byMinor else {
                    throw RepositoryStoreHydrationError.invalidCardState("statement section relationship")
                }
                let observations = try snapshot.sectionObservations.filter {
                    $0.cardStatementSectionId == section.id
                }.map { observation -> CardSourceIdentityObservation in
                    guard observation.workspaceId == workspaceID,
                          observation.documentId == statement.documentId,
                          observation.importSessionId == statement.importSessionId,
                          observation.normalizedDocumentId == statement.normalizedDocumentId,
                          observation.parserProfileId == statement.parserProfileId,
                          observation.parserProfileVersion == statement.parserProfileVersion,
                          observation.observationKind == instrumentObservationKindCode,
                          ["user_confirmed", "prior_user_confirmed_mapping", "parser_strong_evidence"]
                            .contains(observation.associationAuthority) else {
                        throw RepositoryStoreHydrationError.invalidCardState("section observation graph")
                    }
                    guard let observationKind = CardSourceIdentityObservationKind(
                        rawValue: instrumentObservationKindCode
                    ) else {
                        throw RepositoryStoreHydrationError.invalidCardState("section observation kind")
                    }
                    return try CardSourceIdentityObservation(
                        kind: observationKind,
                        subject: .instrument,
                        value: observation.sourceValue
                    )
                }
                guard !observations.isEmpty else {
                    throw RepositoryStoreHydrationError.invalidCardState("section observation coverage")
                }
                return CardStatementSection(
                    id: section.id,
                    documentScopedSectionID: section.documentScopedSectionId,
                    sourceOrdinal: section.sourceOrdinal,
                    instrumentID: section.instrumentId,
                    holderLabel: section.holderLabel,
                    signedTotal: byDecimal,
                    reconciliationRuleCode: section.reconciliationRuleCode,
                    sourceObservations: observations
                )
            }

            let semanticProjection = snapshot.semanticProjections.first { $0.cardStatementId == statement.id }
            let semanticMember = semanticProjection.flatMap { projection in
                snapshot.semanticMembers.first { $0.projectionId == projection.id }
            }
            let isSupportingSource: Bool
            let semanticGroupID: String?
            if let projection = semanticProjection, let member = semanticMember,
               let group = groupByID[member.groupId] {
                guard contract.supportsSemanticSourceGrouping,
                      try validCardSemanticProjection(
                    projection,
                    statement: statement,
                    summaryComponents: statementComponents,
                    durableSections: durableSections,
                    transactionsByID: transactionByID,
                    member: member,
                    group: group
                ) else {
                    throw RepositoryStoreHydrationError.invalidCardState("semantic projection graph")
                }
                isSupportingSource = member.role == .supporting
                semanticGroupID = group.id
            } else if semanticProjection == nil && semanticMember == nil {
                // Historical V13 Amex rows may predate a semantic projection;
                // source-byte CBQ statements never create one. In either case,
                // the authoritative statement graph remains hydratable.
                isSupportingSource = false
                semanticGroupID = nil
            } else {
                throw RepositoryStoreHydrationError.invalidCardState("semantic membership coverage")
            }
            let evidenceRows = snapshot.transactionEvidence.filter { $0.cardStatementId == statement.id }
            guard evidenceRows.count == (isSupportingSource ? 0 : statement.sourceRowCount) else {
                throw RepositoryStoreHydrationError.invalidCardState("statement row count")
            }
            var increase: Int64 = 0
            var decrease: Int64 = 0
            var instrumentNet: Int64 = 0
            var allRowsNet: Int64 = 0
            var membershipTotals: [CardTransactionSummaryMembership: Int64] = [:]
            var sectionNetByID = Dictionary(uniqueKeysWithValues: durableSections.map {
                ($0.documentScopedSectionId, Int64(0))
            })
            for evidence in evidenceRows {
                guard let transaction = transactionByID[evidence.transactionId],
                      transaction.accountId == statement.liabilityAccountId,
                      transaction.documentId == statement.documentId,
                      transaction.importSessionId == statement.importSessionId,
                      transaction.direction == evidence.liabilityEffectCode,
                      let effect = CardLiabilityEffect(rawValue: evidence.liabilityEffectCode),
                      let transactionDate = try? StatementDate(canonical: evidence.sourceTransactionDateISO) else {
                    throw RepositoryStoreHydrationError.invalidCardState("transaction relationship")
                }
                let scope: CardTransactionScope
                if evidence.rowScopeCode == CardTransactionScope.accountLevel.persistenceCode {
                    guard evidence.instrumentId == nil,
                          (contract != .axis || evidence.documentScopedSectionId == nil),
                          evidence.documentScopedSectionId.map(sectionNetByID.keys.contains) ?? true else {
                        throw RepositoryStoreHydrationError.invalidCardState("account-level scope")
                    }
                    scope = .accountLevel
                } else {
                    guard evidence.rowScopeCode == "instrument_level", let instrumentID = evidence.instrumentId,
                          instrumentByID[instrumentID]?.liabilityAccountId == statement.liabilityAccountId,
                          let sectionID = evidence.documentScopedSectionId, !sectionID.isEmpty else {
                        throw RepositoryStoreHydrationError.invalidCardState("instrument scope")
                    }
                    scope = .instrument
                    instrumentNet += transaction.amountMinor
                }
                let membership: CardTransactionSummaryMembership?
                if let code = evidence.summaryMembershipCode {
                    guard let decoded = CardTransactionSummaryMembership(rawValue: code) else {
                        throw RepositoryStoreHydrationError.invalidCardState("summary membership")
                    }
                    membership = decoded
                } else {
                    membership = nil
                }
                if contract.requiresCBQSummaryMembership {
                    let allowed = scope == .accountLevel
                        ? contract.accountLevelMemberships
                        : contract.instrumentMemberships
                    guard membership.map(allowed.contains) == true else {
                        throw RepositoryStoreHydrationError.invalidCardState("summary membership scope")
                    }
                } else if membership != nil {
                    throw RepositoryStoreHydrationError.invalidCardState("unexpected summary membership")
                }
                if let sectionID = evidence.documentScopedSectionId {
                    sectionNetByID[sectionID, default: 0] += transaction.amountMinor
                } else if contract != .amex && contract != .axis {
                    throw RepositoryStoreHydrationError.invalidCardState("CBQ structural section coverage")
                }
                allRowsNet += transaction.amountMinor
                if let membership { membershipTotals[membership, default: 0] += transaction.amountMinor }
                switch effect {
                case .increasesAmountOwed: increase += transaction.amountMinor
                case .decreasesAmountOwed: decrease += -transaction.amountMinor
                }
                let originalMoney: Money?
                if let currency = evidence.originalCurrency, let minor = evidence.originalAmountMinor,
                   let decimal = evidence.originalAmountDecimal,
                   let byDecimal = try? Money(canonicalDecimal: decimal, currency: currency),
                   let byMinor = try? Money.fromMinorUnits(minor, currency: currency), byDecimal == byMinor {
                    originalMoney = byDecimal
                } else if evidence.originalCurrency == nil && evidence.originalAmountMinor == nil && evidence.originalAmountDecimal == nil {
                    originalMoney = nil
                } else {
                    throw RepositoryStoreHydrationError.invalidCardState("original merchant money")
                }
                runtimeEvidence.append(DurableCardTransactionEvidence(
                    statementID: statement.id, transactionID: evidence.transactionId,
                    financialScope: scope, documentScopedSectionID: evidence.documentScopedSectionId,
                    instrumentID: evidence.instrumentId, liabilityEffect: effect,
                    sourceTransactionDate: transactionDate, originalMerchantMoney: originalMoney,
                    summaryMembership: membership
                ))
            }
            if isSupportingSource, let semanticProjection {
                for event in semanticProjection.events {
                    allRowsNet += event.postedAmountMinor
                    switch CardLiabilityEffect(rawValue: event.liabilityEffectCode) {
                    case .increasesAmountOwed: increase += event.postedAmountMinor
                    case .decreasesAmountOwed: decrease += -event.postedAmountMinor
                    case nil: throw RepositoryStoreHydrationError.invalidCardState("semantic event effect")
                    }
                    if let sectionID = event.documentScopedSectionId {
                        instrumentNet += event.postedAmountMinor
                        sectionNetByID[sectionID, default: 0] += event.postedAmountMinor
                    }
                }
            }
            let previousMinor = try previous.map { try $0.minorUnits() }
            let balanceMinor = try balance.map { try $0.minorUnits() }
            let sectionNet = durableSections.reduce(Int64(0)) { $0 + $1.signedTotalMinor }
            let summaryValid: Bool
            switch contract {
            case .amex:
                summaryValid = previousMinor != nil && balanceMinor != nil &&
                    componentByCode["new_debits"]?.money.flatMap { try? $0.minorUnits() } == increase &&
                    componentByCode["new_credits"]?.money.flatMap { try? $0.minorUnits() } == decrease &&
                    componentByCode["instrument_net_total"]?.money.flatMap { try? $0.minorUnits() } == instrumentNet &&
                    previousMinor! - decrease + increase == balanceMinor! && sectionNet == instrumentNet
            case .cbqV1:
                let billed = componentByCode["amount_billed"]?.money.flatMap { try? $0.minorUnits() }
                let payment = componentByCode["payment_received"]?.money.flatMap { try? $0.minorUnits() }
                summaryValid = billed == membershipTotals[.cbqV1AmountBilled, default: 0] &&
                    payment == -membershipTotals[.cbqV1PaymentReceived, default: 0] &&
                    componentByCode["source_section_net_total"]?.money.flatMap { try? $0.minorUnits() } == allRowsNet &&
                    billed.flatMap { billed in payment.flatMap { paid in previousMinor.flatMap { opening in balanceMinor.map { opening + billed - paid == $0 } } } } == true &&
                    sectionNet == allRowsNet
            case .cbqV2:
                let payment = componentByCode["total_payment"]?.money.flatMap { try? $0.minorUnits() }
                let credit = componentByCode["credit_reversal"]?.money.flatMap { try? $0.minorUnits() }
                let purchases = componentByCode["purchases"]?.money.flatMap { try? $0.minorUnits() }
                let installment = componentByCode["billed_installment"]?.money.flatMap { try? $0.minorUnits() }
                let fees = componentByCode["fees_charges"]?.money.flatMap { try? $0.minorUnits() }
                let equationValid = payment.flatMap { paid in
                    credit.flatMap { credited in
                        purchases.flatMap { bought in
                            installment.flatMap { billed in
                                fees.flatMap { fee in
                                    previousMinor.flatMap { opening in
                                        balanceMinor.map {
                                            opening - paid - credited + bought + billed + fee == $0
                                        }
                                    }
                                }
                            }
                        }
                    }
                } ?? false
                summaryValid = payment == -membershipTotals[.cbqV2TotalPayment, default: 0] &&
                    credit == -membershipTotals[.cbqV2CreditReversal, default: 0] &&
                    purchases == membershipTotals[.cbqV2Purchases, default: 0] &&
                    installment == membershipTotals[.cbqV2BilledInstallment, default: 0] &&
                    fees == membershipTotals[.cbqV2FeesCharges, default: 0] &&
                    componentByCode["source_section_net_total"]?.money.flatMap { try? $0.minorUnits() } == allRowsNet &&
                    equationValid && previousMinor != nil && balanceMinor != nil && sectionNet == allRowsNet
            case .axis:
                summaryValid = true
            }
            guard summaryValid, durableSections.allSatisfy({
                      sectionNetByID[$0.documentScopedSectionId] == $0.signedTotalMinor
                  }) else {
                throw RepositoryStoreHydrationError.invalidCardState("transaction totals")
            }
            // `Optional.map` invokes its transform in a synchronous
            // nonisolated closure under the target's default MainActor
            // isolation. Parse each optional in this actor-owned context so
            // the immutable date initializer is not incorrectly crossed from
            // that closure. The explicit branches preserve the prior nil and
            // throwing behavior exactly.
            let statementDate: StatementDate?
            if let canonical = statement.statementDateISO {
                statementDate = try StatementDate(canonical: canonical)
            } else {
                statementDate = nil
            }
            let start: StatementDate?
            if let canonical = statement.statementStartDateISO {
                start = try StatementDate(canonical: canonical)
            } else {
                start = nil
            }
            let end: StatementDate?
            if let canonical = statement.statementEndDateISO {
                end = try StatementDate(canonical: canonical)
            } else {
                end = nil
            }
            guard (start == nil) == (end == nil) else {
                throw RepositoryStoreHydrationError.invalidCardState("statement period")
            }
            let period: DeclaredStatementPeriod?
            if let start, let end {
                guard start <= end else { throw RepositoryStoreHydrationError.invalidCardState("statement period") }
                period = try DeclaredStatementPeriod(start: start, end: end)
            } else {
                period = nil
            }
            let selectedMonth: SelectedStatementMonth?
            if let canonical = statement.selectedStatementMonthISO {
                selectedMonth = try SelectedStatementMonth(canonical: canonical)
            } else {
                selectedMonth = nil
            }
            guard contract == .axis || statementDate != nil || period != nil || selectedMonth != nil else {
                throw RepositoryStoreHydrationError.invalidCardState("statement chronology evidence")
            }
            let usedInstrumentIDs = durableSections.map(\.instrumentId)
            runtimeStatements.append(CardStatement(
                id: statement.id, liabilityAccountID: statement.liabilityAccountId,
                instrumentIDs: usedInstrumentIDs, sourceDocumentID: statement.documentId,
                importSessionID: statement.importSessionId, parserProfileID: statement.parserProfileId,
                parserProfileVersion: statement.parserProfileVersion, statementDate: statementDate,
                period: period, selectedStatementMonth: selectedMonth, semanticGroupID: semanticGroupID,
                currency: try CurrencyCode(statement.statementCurrency), sourceRowCount: statement.sourceRowCount,
                reconciliationRuleCode: statement.reconciliationRuleCode,
                summaryComponents: components,
                sections: runtimeSections
            ))
        }
        guard Set(snapshot.summaryComponents.map(\.cardStatementId)).isSubset(of: Set(statementByID.keys)),
              Set(snapshot.transactionEvidence.map(\.cardStatementId)).isSubset(of: Set(statementByID.keys)),
              Set(snapshot.sections.map(\.cardStatementId)).isSubset(of: Set(statementByID.keys)),
              snapshot.sectionObservations.allSatisfy({ sectionByID[$0.cardStatementSectionId] != nil }),
              snapshot.semanticProjections.allSatisfy({ statementByID[$0.cardStatementId] != nil }),
              snapshot.semanticMembers.allSatisfy({
                  projectionByID[$0.projectionId] != nil && groupByID[$0.groupId] != nil
              }) else {
            throw RepositoryStoreHydrationError.invalidCardState("orphan statement evidence")
        }
        for observation in snapshot.sourceObservations {
            guard observation.workspaceId == workspaceID,
                  let sourceStatement = statementByID.values.first(where: {
                      $0.documentId == observation.documentId && $0.importSessionId == observation.importSessionId &&
                      $0.normalizedDocumentId == observation.normalizedDocumentId &&
                      $0.parserProfileId == observation.parserProfileId && $0.parserProfileVersion == observation.parserProfileVersion
                  }),
                  let contract = CardStatementProfileContract(
                    reconciliationRuleIdentifier: sourceStatement.reconciliationRuleCode
                  ),
                  let observationKind = CardSourceIdentityObservationKind(rawValue: observation.observationKind) else {
                throw RepositoryStoreHydrationError.invalidCardState("observation source graph")
            }
            if observation.subjectKind == CardSourceIdentitySubject.liabilityAccount.rawValue {
                guard accountByID[observation.subjectId]?.accountType == "credit_card",
                      observationKind.rawValue == contract.accountObservationKindCode,
                      (try? CardSourceIdentityObservation(
                        kind: observationKind, subject: .liabilityAccount, value: observation.sourceValue
                      )) != nil else {
                    throw RepositoryStoreHydrationError.invalidCardState("observation account subject")
                }
            } else if observation.subjectKind == CardSourceIdentitySubject.instrument.rawValue {
                guard instrumentByID[observation.subjectId] != nil,
                      observationKind.rawValue == contract.instrumentObservationKindCode,
                      (try? CardSourceIdentityObservation(
                        kind: observationKind, subject: .instrument, value: observation.sourceValue
                      )) != nil else {
                    throw RepositoryStoreHydrationError.invalidCardState("observation instrument subject")
                }
            } else { throw RepositoryStoreHydrationError.invalidCardState("observation subject kind") }
        }
        let evidencedTransactionIDs = Set(snapshot.transactionEvidence.map(\.transactionId))
        guard transactions.allSatisfy({ transaction in
            let isCardDirection = CardLiabilityEffect(rawValue: transaction.direction) != nil
            return isCardDirection == evidencedTransactionIDs.contains(transaction.id)
        }) else { throw RepositoryStoreHydrationError.invalidCardState("transaction evidence coverage") }
        let sortedStatements = runtimeStatements.sorted { lhs, rhs in
            let lhsMonth = lhs.selectedStatementMonth?.canonical ?? lhs.statementDate.map { String(format: "%04d-%02d", $0.year, $0.month) } ?? lhs.period.map { String(format: "%04d-%02d", $0.end.year, $0.end.month) } ?? ""
            let rhsMonth = rhs.selectedStatementMonth?.canonical ?? rhs.statementDate.map { String(format: "%04d-%02d", $0.year, $0.month) } ?? rhs.period.map { String(format: "%04d-%02d", $0.end.year, $0.end.month) } ?? ""
            if lhsMonth != rhsMonth { return lhsMonth < rhsMonth }
            let lhsExact = lhs.statementDate?.canonical ?? ""
            let rhsExact = rhs.statementDate?.canonical ?? ""
            if lhsExact != rhsExact { return lhsExact < rhsExact }
            return lhs.id < rhs.id
        }
        return CardStoreSnapshot(
            instruments: runtimeInstruments,
            relationships: runtimeRelationships.sorted { $0.id < $1.id },
            statements: sortedStatements,
            transactionEvidence: runtimeEvidence.sorted { ($0.statementID, $0.transactionID) < ($1.statementID, $1.transactionID) }
        )
    }

    private static func validCardSemanticProjection(
        _ persisted: CardStatementSemanticProjectionRecordDTO,
        statement: CardStatementDTO,
        summaryComponents: [CardStatementSummaryComponentDTO],
        durableSections: [CardStatementSectionDTO],
        transactionsByID: [String: TransactionDTO],
        member: CardStatementSemanticMemberDTO,
        group: CardStatementSemanticGroupDTO
    ) throws -> Bool {
        guard persisted.workspaceId == statement.workspaceId,
              persisted.liabilityAccountId == statement.liabilityAccountId,
              persisted.cardStatementId == statement.id,
              persisted.documentId == statement.documentId,
              persisted.importSessionId == statement.importSessionId,
              persisted.parserProfileId == statement.parserProfileId,
              persisted.parserProfileVersion == statement.parserProfileVersion,
              persisted.statementDateISO == statement.statementDateISO,
              persisted.statementStartDateISO == statement.statementStartDateISO,
              persisted.statementEndDateISO == statement.statementEndDateISO,
              persisted.selectedStatementMonthISO == statement.selectedStatementMonthISO,
              persisted.nativeCurrency == statement.statementCurrency,
              persisted.reconciliationRuleCode == statement.reconciliationRuleCode,
              persisted.eventCount == persisted.events.count,
              persisted.sectionCount == persisted.sections.count,
              persisted.eventCount == statement.sourceRowCount,
              persisted.sectionCount == durableSections.count,
              member.projectionId == persisted.id,
              group.id == member.groupId,
              group.workspaceId == persisted.workspaceId,
              group.liabilityAccountId == persisted.liabilityAccountId,
              group.institutionCode == persisted.institutionCode,
              group.statementFamilyCode == persisted.statementFamilyCode,
              group.nativeCurrency == persisted.nativeCurrency,
              group.projectionAlgorithm == persisted.algorithm,
              group.projectionDigest == persisted.digest else { return false }
        if persisted.algorithm == CardStatementSemanticProjectionDTO.axisMultisetAlgorithm {
            guard group.cycleMonthISO == nil,
                  group.statementStartDateISO == nil,
                  group.statementEndDateISO == nil else { return false }
        } else {
            guard persisted.cycleMonthISO == nil,
                  group.cycleMonthISO == nil,
                  group.statementStartDateISO == persisted.statementStartDateISO,
                  group.statementEndDateISO == persisted.statementEndDateISO else { return false }
        }
        switch member.role {
        case .authoritative:
            guard group.authoritativeProjectionId == persisted.id else { return false }
        case .supporting:
            guard group.authoritativeProjectionId != persisted.id else { return false }
        }

        let durableSectionsByOrdinal = Dictionary(uniqueKeysWithValues: durableSections.map {
            ($0.sourceOrdinal, $0)
        })
        guard persisted.sections.allSatisfy({ projected in
            guard projected.projectionId == persisted.id,
                  let durable = durableSectionsByOrdinal[projected.sourceOrdinal] else { return false }
            return projected.documentScopedSectionId == durable.documentScopedSectionId &&
                projected.signedTotalCurrency == durable.signedTotalCurrency &&
                projected.signedTotalMinor == durable.signedTotalMinor &&
                projected.signedTotalDecimal == durable.signedTotalDecimal &&
                projected.reconciliationRuleCode == durable.reconciliationRuleCode
        }) else { return false }

        let eventPlans = persisted.events.map { event in
            CardStatementSemanticProjectionEventPlanDTO(
                incomingTransactionId: event.canonicalTransactionId ?? event.id,
                normalizedRowId: event.normalizedRowId,
                sourceOrdinal: event.sourceOrdinal,
                financialDateISO: event.financialDateISO,
                financialDateRoleCode: event.financialDateRoleCode,
                sourceTransactionDateISO: event.sourceTransactionDateISO,
                liabilityEffectCode: event.liabilityEffectCode,
                postedCurrency: event.postedCurrency,
                postedAmountMinor: event.postedAmountMinor,
                postedAmountDecimal: event.postedAmountDecimal,
                originalCurrency: event.originalCurrency,
                originalAmountMinor: event.originalAmountMinor,
                originalAmountDecimal: event.originalAmountDecimal,
                sourceReference: event.sourceReference,
                rowScopeCode: event.rowScopeCode,
                documentScopedSectionId: event.documentScopedSectionId,
                documentSectionOrdinal: event.documentSectionOrdinal
            )
        }
        func axisEventKey(_ event: CardStatementSemanticProjectionEventDTO) -> String {
            [event.financialDateISO, event.liabilityEffectCode, event.postedCurrency, event.postedAmountDecimal]
                .map { "\($0.utf8.count):\($0)" }.joined()
        }
        let axisKeyCounts = Dictionary(grouping: persisted.events, by: axisEventKey).mapValues(\.count)
        guard persisted.events.allSatisfy({ event in
            guard event.projectionId == persisted.id, !event.normalizedRowId.isEmpty else { return false }
            if let canonicalID = event.canonicalTransactionId {
                guard let transaction = transactionsByID[canonicalID],
                      transaction.accountId == persisted.liabilityAccountId,
                      transaction.postedDateISO == event.financialDateISO,
                      transaction.financialDateRole == event.financialDateRoleCode,
                      transaction.direction == event.liabilityEffectCode,
                      transaction.nativeCurrency == event.postedCurrency,
                      transaction.amountMinor == event.postedAmountMinor,
                      transaction.amountDecimal == event.postedAmountDecimal,
                      (persisted.algorithm == CardStatementSemanticProjectionDTO.axisMultisetAlgorithm ||
                       transaction.reference == event.sourceReference) else { return false }
            } else {
                guard persisted.algorithm == CardStatementSemanticProjectionDTO.axisMultisetAlgorithm,
                      member.role == .supporting,
                      axisKeyCounts[axisEventKey(event), default: 0] > 1 else { return false }
            }
            if event.rowScopeCode == CardTransactionScope.accountLevel.persistenceCode {
                return event.documentScopedSectionId == nil && event.documentSectionOrdinal == nil
            }
            guard event.rowScopeCode == "instrument_level",
                  let sectionID = event.documentScopedSectionId,
                  let ordinal = event.documentSectionOrdinal,
                  let section = durableSectionsByOrdinal[ordinal] else { return false }
            return section.documentScopedSectionId == sectionID
        }) else { return false }
        if member.role == .authoritative && persisted.events.contains(where: { $0.canonicalTransactionId == nil }) {
            return false
        }

        let projection = CardStatementSemanticProjectionDTO(
            id: persisted.id,
            algorithmIdentifier: persisted.algorithm,
            digest: persisted.digest,
            institutionCode: persisted.institutionCode,
            statementFamilyCode: persisted.statementFamilyCode,
            parserProfileId: persisted.parserProfileId,
            parserProfileVersion: persisted.parserProfileVersion,
            statementDateISO: persisted.statementDateISO,
            statementStartDateISO: persisted.statementStartDateISO,
            statementEndDateISO: persisted.statementEndDateISO,
            selectedStatementMonthISO: persisted.selectedStatementMonthISO,
            cycleMonthISO: persisted.cycleMonthISO,
            nativeCurrency: persisted.nativeCurrency,
            reconciliationRuleCode: persisted.reconciliationRuleCode,
            summaryComponents: summaryComponents,
            sections: persisted.sections.sorted { $0.sourceOrdinal < $1.sourceOrdinal },
            events: eventPlans.sorted { $0.sourceOrdinal < $1.sourceOrdinal }
        )
        return projection.isValid()
    }

    private static func accounts(
        from accountDTOs: [AccountDTO],
        transactions: [Transaction],
        identitiesByAccountID: [String: [AccountIdentitySummary]],
        cardSnapshot: CardStoreSnapshot
    ) throws -> [Account] {
        try accountDTOs.map { accountDTO in
            let accountTransactions = transactions.filter { $0.repositoryAccountId == accountDTO.id }
            let latestBalance: Money?
            if accountDTO.accountType == "credit_card" {
                let accountStatements = cardSnapshot.statements.filter { $0.liabilityAccountID == accountDTO.id }
                let latestStatement: CardStatement?
                if accountStatements.allSatisfy({ !$0.parserProfileID.hasPrefix("axis.credit-card.") }) {
                    // Preserve accepted Amex/CBQ exact-date chronology semantics.
                    latestStatement = accountStatements.max {
                        (($0.statementDate?.canonical ?? ""), ($0.period?.end.canonical ?? ""), $0.id) <
                        (($1.statementDate?.canonical ?? ""), ($1.period?.end.canonical ?? ""), $1.id)
                    }
                } else {
                    func cycleMonth(_ statement: CardStatement) -> String? {
                        if let month = statement.selectedStatementMonth { return month.canonical }
                        if let date = statement.statementDate { return String(format: "%04d-%02d", date.year, date.month) }
                        if let end = statement.period?.end { return String(format: "%04d-%02d", end.year, end.month) }
                        return nil
                    }
                    let keyed = accountStatements.compactMap { statement in cycleMonth(statement).map { ($0, statement) } }
                    if let latestMonth = keyed.map(\.0).max() {
                        let cycle = keyed.filter { $0.0 == latestMonth }.map(\.1)
                        if let exactDate = cycle.compactMap(\.statementDate).max() {
                            let exact = cycle.filter { $0.statementDate == exactDate }
                            let groupIDs = Set(exact.compactMap(\.semanticGroupID))
                            latestStatement = exact.count == 1 || (groupIDs.count == 1 && exact.allSatisfy({ $0.semanticGroupID != nil })) ? exact.first : nil
                        } else {
                            let groupIDs = Set(cycle.compactMap(\.semanticGroupID))
                            latestStatement = cycle.count == 1 || (groupIDs.count == 1 && cycle.allSatisfy({ $0.semanticGroupID != nil })) ? cycle.first : nil
                        }
                    } else {
                        latestStatement = nil
                    }
                }
                if let newBalance = latestStatement?.newBalance {
                    guard newBalance.currency.code == accountDTO.nativeCurrency else {
                        throw RepositoryStoreHydrationError.accountCurrencyMismatch
                    }
                    latestBalance = try Money(amount: -newBalance.amount, currency: newBalance.currency)
                } else {
                    latestBalance = nil
                }
            } else {
                latestBalance = try latestRunningBalance(from: accountTransactions, currency: accountDTO.nativeCurrency)
            }

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
        preferredSource: PreferredTransactionSourceDTO?,
        workspaceID: String,
        cardEvidence: CardTransactionEvidenceDTO?
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
        let preferredSourceDocumentName: String? = preferredSource.flatMap { source in
            guard let document = importedDocumentsByID[source.documentId],
                  document.workspaceId == workspaceID,
                  document.importSessionId == source.importSessionId else { return nil }
            let value = document.filename.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        let preferredSourceTransactionDate: StatementDate?
        if let sourceTransactionDateISO = preferredSource?.sourceTransactionDateISO {
            preferredSourceTransactionDate = try StatementDate(canonical: sourceTransactionDateISO)
        } else {
            preferredSourceTransactionDate = nil
        }

        let cardEffect = cardEvidence.flatMap { CardLiabilityEffect(rawValue: $0.liabilityEffectCode) }
        if cardEvidence != nil, cardEffect == nil {
            throw RepositoryStoreHydrationError.invalidCardState("invalid transaction effect")
        }
        if cardEvidence == nil, !["debit", "credit"].contains(dto.direction) {
            throw RepositoryStoreHydrationError.invalidCardState("card direction without evidence")
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
            cardLiabilityEffect: cardEffect,
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
            repositorySourceDocumentName: repositorySourceDocumentName,
            repositoryPreferredSourceDocumentName: preferredSourceDocumentName,
            repositoryPreferredSourceFormatCode: preferredSource?.sourceFormatCode,
            repositoryPreferredSourceTransactionDate: preferredSourceTransactionDate,
            repositoryPreferredStructuredReferenceDigest: preferredSource?.structuredReferenceDigest
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
