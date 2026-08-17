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
    let cardSnapshot: CardStoreSnapshot
    let hydrationResult: RepositoryStoreHydrationResult
    let providerGeneration: ProviderGenerationToken?

    fileprivate init(
        accounts: [Account],
        transactions: [Transaction],
        importSessions: [RepositoryImportSession],
        importAttempts: [RepositoryImportAttempt],
        categorySnapshot: CategorySnapshot,
        cardSnapshot: CardStoreSnapshot,
        providerGeneration: ProviderGenerationToken?
    ) {
        self.accounts = accounts
        self.transactions = transactions
        self.importSessions = importSessions
        self.importAttempts = importAttempts
        self.categorySnapshot = categorySnapshot
        self.cardSnapshot = cardSnapshot
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
    case invalidStatementEquivalence(String)
    case invalidCategoryState(String)
    case invalidCardState(String)

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
        }
    }
}

final class RepositoryStoreHydrator {

    private let accountRepo: AccountRepository
    private let importSessionRepo: ImportSessionRepository
    private let transactionRepo: TransactionRepository
    private let categoryRepo: CategoryRepository
    private let cardRepo: CardRepository
    private let accountStore: AccountStore
    private let importSessionStore: ImportSessionStore
    private let importAttemptStore: ImportAttemptStore
    private let transactionStore: TransactionStore
    private let categoryStore: CategoryStore
    private let cardStore: CardStore
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
            accountStore: accountStore,
            transactionStore: transactionStore,
            categoryStore: categoryStore,
            cardStore: .shared,
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
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared,
        categoryStore: CategoryStore = .shared,
        cardStore: CardStore = .shared,
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
        self.accountStore = accountStore
        self.transactionStore = transactionStore
        self.categoryStore = categoryStore
        self.cardStore = cardStore
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
        let cardDTOs = try cardRepo.snapshot(workspaceId: workspaceId)
        let identitiesByAccountID = Dictionary(
            uniqueKeysWithValues: try accountDTOs.map { accountDTO in
                (accountDTO.id, try Self.identitySummaries(from: accountRepo.identifiers(accountId: accountDTO.id, workspaceId: workspaceId)))
            }
        )
        let preferredSources = try importSessionRepo.preferredTransactionSources(workspaceId: workspaceId)
        let preferredSourcesByTransactionID = Dictionary(uniqueKeysWithValues: preferredSources.map { ($0.transactionId, $0) })
        var importedDocumentsByID = try referencedImportedDocuments(from: transactionDTOs)
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
            statementProjections: statementProjections
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

        return RepositoryRuntimeSnapshot(
            accounts: accounts,
            transactions: transactions,
            importSessions: importSessions,
            importAttempts: importAttempts,
            categorySnapshot: categorySnapshot,
            cardSnapshot: cardSnapshot,
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
        statementProjections: [StatementFinancialProjectionRecordDTO]
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
                  account.accountType == "credit_card", account.nativeCurrency == "QAR",
                  account.institutionId == Institution.amex.rawValue,
                  let lifecycle = CardInstrumentLifecycleState(rawValue: instrument.lifecycleStateCode) else {
                throw RepositoryStoreHydrationError.invalidCardState("instrument account relationship")
            }
            let legacyObservations = try snapshot.sourceObservations.filter {
                $0.subjectKind == CardSourceIdentitySubject.instrument.rawValue && $0.subjectId == instrument.id
            }.map { observation -> CardSourceIdentityObservation in
                guard observation.workspaceId == workspaceID,
                      let kind = CardSourceIdentityObservationKind(rawValue: observation.observationKind),
                      observation.parserProfileId == AmericanExpressCreditCardPDFParser.profileID,
                      observation.parserProfileVersion == AmericanExpressCreditCardPDFParser.profileVersion else {
                    throw RepositoryStoreHydrationError.invalidCardState("instrument source observation")
                }
                return try CardSourceIdentityObservation(kind: kind, subject: .instrument, value: observation.sourceValue)
            }
            let sectionScopedObservations = try snapshot.sectionObservations.filter {
                sectionByID[$0.cardStatementSectionId]?.instrumentId == instrument.id
            }.map { observation -> CardSourceIdentityObservation in
                guard observation.workspaceId == workspaceID,
                      observation.observationKind == CardSourceIdentityObservationKind.instrumentCardAccountNumber.rawValue,
                      observation.parserProfileId == AmericanExpressCreditCardPDFParser.profileID,
                      observation.parserProfileVersion == AmericanExpressCreditCardPDFParser.profileVersion else {
                    throw RepositoryStoreHydrationError.invalidCardState("section source observation")
                }
                return try CardSourceIdentityObservation(
                    kind: .instrumentCardAccountNumber,
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
            guard statement.workspaceId == workspaceID,
                  accountByID[statement.liabilityAccountId]?.accountType == "credit_card",
                  statement.parserProfileId == AmericanExpressCreditCardPDFParser.profileID,
                  statement.parserProfileVersion == AmericanExpressCreditCardPDFParser.profileVersion,
                  statement.statementCurrency == "QAR",
                  statement.reconciliationRuleCode == CardStatementEvidence.amexQARReconciliationRule,
                  statement.sourceRowCount > 0 else {
                throw RepositoryStoreHydrationError.invalidCardState("statement relationship")
            }
            let statementComponents = snapshot.summaryComponents.filter { $0.cardStatementId == statement.id }
            let requiredCodes = Set(["previous_balance", "new_credits", "new_debits", "new_balance", "due_date", "instrument_net_total"])
            guard Set(statementComponents.map(\.componentCode)) == requiredCodes else {
                throw RepositoryStoreHydrationError.invalidCardState("statement summary coverage")
            }
            let components: [CardStatementSummaryComponent] = try statementComponents.map { component in
                if component.componentCode == "due_date" {
                    guard let dateISO = component.dateISO, component.moneyCurrency == nil,
                          component.moneyMinor == nil, component.moneyDecimal == nil else {
                        throw RepositoryStoreHydrationError.invalidCardState("due-date component")
                    }
                    return .dueDate(try StatementDate(canonical: dateISO))
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
                case "new_balance": return .newBalance(decimalMoney)
                case "instrument_net_total": return .instrumentNetTotal(decimalMoney)
                default: throw RepositoryStoreHydrationError.invalidCardState("unknown summary component")
                }
            }
            let componentByCode = Dictionary(uniqueKeysWithValues: components.map { ($0.persistenceCode, $0) })
            guard let previous = componentByCode["previous_balance"]?.money,
                  let credits = componentByCode["new_credits"]?.money,
                  let debits = componentByCode["new_debits"]?.money,
                  let balance = componentByCode["new_balance"]?.money,
                  previous.amount - credits.amount + debits.amount == balance.amount else {
                throw RepositoryStoreHydrationError.invalidCardState("summary reconciliation")
            }
            let durableSections = snapshot.sections.filter { $0.cardStatementId == statement.id }
                .sorted { $0.sourceOrdinal < $1.sourceOrdinal }
            guard !durableSections.isEmpty,
                  durableSections.map(\.sourceOrdinal) == Array(1...durableSections.count),
                  Set(durableSections.map(\.documentScopedSectionId)).count == durableSections.count else {
                throw RepositoryStoreHydrationError.invalidCardState("statement section coverage")
            }
            let runtimeSections: [CardStatementSection] = try durableSections.map { section in
                guard let instrument = instrumentByID[section.instrumentId],
                      instrument.liabilityAccountId == statement.liabilityAccountId,
                      section.signedTotalCurrency == statement.statementCurrency,
                      section.reconciliationRuleCode == CardInstrumentSectionEvidence.amexSignedNetRule,
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
                          observation.observationKind == CardSourceIdentityObservationKind.instrumentCardAccountNumber.rawValue,
                          ["user_confirmed", "prior_user_confirmed_mapping", "parser_strong_evidence"]
                            .contains(observation.associationAuthority) else {
                        throw RepositoryStoreHydrationError.invalidCardState("section observation graph")
                    }
                    return try CardSourceIdentityObservation(
                        kind: .instrumentCardAccountNumber,
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
            if let projection = semanticProjection, let member = semanticMember,
               let group = groupByID[member.groupId] {
                guard try validCardSemanticProjection(
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
            } else if semanticProjection == nil && semanticMember == nil {
                isSupportingSource = false
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
                    guard evidence.instrumentId == nil, evidence.documentScopedSectionId == nil else {
                        throw RepositoryStoreHydrationError.invalidCardState("account-level scope")
                    }
                    scope = .accountLevel
                } else {
                    guard evidence.rowScopeCode == "instrument_level", let instrumentID = evidence.instrumentId,
                          instrumentByID[instrumentID]?.liabilityAccountId == statement.liabilityAccountId,
                          let sectionID = evidence.documentScopedSectionId, !sectionID.isEmpty else {
                        throw RepositoryStoreHydrationError.invalidCardState("instrument scope")
                    }
                    scope = .instrument(documentScopedSectionID: sectionID)
                    instrumentNet += transaction.amountMinor
                    sectionNetByID[sectionID, default: 0] += transaction.amountMinor
                }
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
                    statementID: statement.id, transactionID: evidence.transactionId, rowScope: scope,
                    instrumentID: evidence.instrumentId, liabilityEffect: effect,
                    sourceTransactionDate: transactionDate, originalMerchantMoney: originalMoney
                ))
            }
            if isSupportingSource, let semanticProjection {
                for event in semanticProjection.events {
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
            guard let debitsMinor = statementComponents.first(where: { $0.componentCode == "new_debits" })?.moneyMinor,
                  let creditsMinor = statementComponents.first(where: { $0.componentCode == "new_credits" })?.moneyMinor,
                  let instrumentMinor = statementComponents.first(where: { $0.componentCode == "instrument_net_total" })?.moneyMinor,
                  increase == debitsMinor,
                  decrease == creditsMinor,
                  instrumentNet == instrumentMinor,
                  durableSections.allSatisfy({
                      sectionNetByID[$0.documentScopedSectionId] == $0.signedTotalMinor
                  }) else {
                throw RepositoryStoreHydrationError.invalidCardState("transaction totals")
            }
            let start = try StatementDate(canonical: statement.statementStartDateISO)
            let end = try StatementDate(canonical: statement.statementEndDateISO)
            let statementDate = try StatementDate(canonical: statement.statementDateISO)
            guard start <= end else { throw RepositoryStoreHydrationError.invalidCardState("statement period") }
            let usedInstrumentIDs = durableSections.map(\.instrumentId)
            runtimeStatements.append(CardStatement(
                id: statement.id, liabilityAccountID: statement.liabilityAccountId,
                instrumentIDs: usedInstrumentIDs, sourceDocumentID: statement.documentId,
                importSessionID: statement.importSessionId, parserProfileID: statement.parserProfileId,
                parserProfileVersion: statement.parserProfileVersion, statementDate: statementDate,
                period: try DeclaredStatementPeriod(start: start, end: end),
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
                  statementByID.values.contains(where: {
                      $0.documentId == observation.documentId && $0.importSessionId == observation.importSessionId &&
                      $0.normalizedDocumentId == observation.normalizedDocumentId &&
                      $0.parserProfileId == observation.parserProfileId && $0.parserProfileVersion == observation.parserProfileVersion
                  }) else { throw RepositoryStoreHydrationError.invalidCardState("observation source graph") }
            if observation.subjectKind == CardSourceIdentitySubject.liabilityAccount.rawValue {
                guard accountByID[observation.subjectId]?.accountType == "credit_card" else {
                    throw RepositoryStoreHydrationError.invalidCardState("observation account subject")
                }
            } else if observation.subjectKind == CardSourceIdentitySubject.instrument.rawValue {
                guard instrumentByID[observation.subjectId] != nil else {
                    throw RepositoryStoreHydrationError.invalidCardState("observation instrument subject")
                }
            } else { throw RepositoryStoreHydrationError.invalidCardState("observation subject kind") }
        }
        let evidencedTransactionIDs = Set(snapshot.transactionEvidence.map(\.transactionId))
        guard transactions.allSatisfy({ transaction in
            let isCardDirection = CardLiabilityEffect(rawValue: transaction.direction) != nil
            return isCardDirection == evidencedTransactionIDs.contains(transaction.id)
        }) else { throw RepositoryStoreHydrationError.invalidCardState("transaction evidence coverage") }
        return CardStoreSnapshot(
            instruments: runtimeInstruments,
            relationships: runtimeRelationships.sorted { $0.id < $1.id },
            statements: runtimeStatements.sorted { ($0.period.end, $0.id) < ($1.period.end, $1.id) },
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
              group.statementStartDateISO == persisted.statementStartDateISO,
              group.statementEndDateISO == persisted.statementEndDateISO,
              group.nativeCurrency == persisted.nativeCurrency,
              group.projectionAlgorithm == persisted.algorithm,
              group.projectionDigest == persisted.digest else { return false }
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
                incomingTransactionId: event.canonicalTransactionId,
                normalizedRowId: event.normalizedRowId,
                sourceOrdinal: event.sourceOrdinal,
                postingDateISO: event.postingDateISO,
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
        guard persisted.events.allSatisfy({ event in
            guard event.projectionId == persisted.id,
                  !event.normalizedRowId.isEmpty,
                  let transaction = transactionsByID[event.canonicalTransactionId],
                  transaction.accountId == persisted.liabilityAccountId,
                  transaction.postedDateISO == event.postingDateISO,
                  transaction.direction == event.liabilityEffectCode,
                  transaction.nativeCurrency == event.postedCurrency,
                  transaction.amountMinor == event.postedAmountMinor,
                  transaction.amountDecimal == event.postedAmountDecimal,
                  transaction.reference == event.sourceReference else { return false }
            if event.rowScopeCode == CardTransactionScope.accountLevel.persistenceCode {
                return event.documentScopedSectionId == nil && event.documentSectionOrdinal == nil
            }
            guard event.rowScopeCode == "instrument_level",
                  let sectionID = event.documentScopedSectionId,
                  let ordinal = event.documentSectionOrdinal,
                  let section = durableSectionsByOrdinal[ordinal] else { return false }
            return section.documentScopedSectionId == sectionID
        }) else { return false }

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
                let latestStatement = cardSnapshot.statements
                    .filter { $0.liabilityAccountID == accountDTO.id }
                    .max { ($0.period.end, $0.statementDate, $0.id) < ($1.period.end, $1.statementDate, $1.id) }
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
