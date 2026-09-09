// LedgerForgeTests/RepositoryStoreHydratorTests.swift

import Combine
import Foundation
import Testing
@testable import LedgerForge

/// Hydration mechanics are exercised with one untouched authentic statement
/// committed through the ordinary confirmed-import repository. The suite does
/// not author or mutate financial DTOs to manufacture hydration states.
@MainActor
struct RepositoryStoreHydratorTests {
    @Test(.globalRuntimeStateIsolation)
    func stagedHydrationIsPureUntilOneCompleteSnapshotIsPublished() async throws {
        let seeded = try await seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(seeded: seeded, stores: stores)

        let snapshot = try hydrator.stageHydration()

        #expect(stores.accounts.accounts.isEmpty)
        #expect(stores.transactions.transactions.isEmpty)
        #expect(stores.importSessions.importSessions.isEmpty)
        #expect(stores.importAttempts.attempts.isEmpty)
        #expect(stores.categories.snapshot == .empty)
        #expect(stores.cards.snapshot == .empty)
        #expect(stores.salary.statements.isEmpty)
        #expect(stores.fundingPlans.plans.isEmpty)
        #expect(Set(snapshot.accounts.compactMap(\.repositoryAccountId)) == [seeded.plan.proposedAccount.id])
        #expect(Set(snapshot.transactions.compactMap(\.repositoryTransactionId)) == Set(seeded.plan.transactionTemplates.map(\.transaction.id)))
        #expect(snapshot.importSessions.map(\.id) == [seeded.plan.historyTemplate.importSession.id])

        hydrator.publish(snapshot)

        #expect(stores.accounts.accounts.map(\.id) == snapshot.accounts.map(\.id))
        #expect(stores.transactions.transactions.map(\.id) == snapshot.transactions.map(\.id))
        #expect(stores.importSessions.importSessions == snapshot.importSessions)
        #expect(stores.importAttempts.attempts == snapshot.importAttempts)
        #expect(stores.categories.snapshot == snapshot.categorySnapshot)
        #expect(stores.cards.snapshot == snapshot.cardSnapshot)
        #expect(stores.salary.statements == snapshot.salaryStatements)
        #expect(stores.fundingPlans.plans == snapshot.fundingPlans)
        #expect(snapshot.hydrationResult.accountCount == 1)
        #expect(snapshot.hydrationResult.transactionCount == seeded.plan.transactionTemplates.count)
    }

    @Test(.globalRuntimeStateIsolation)
    func firstPublicationObserverSeesCompleteInstalledSnapshotInCanonicalOrder() async throws {
        let seeded = try await seededProvider()
        try seedCategoryMetadata(in: seeded)
        let stores = RuntimeStores()
        let reconciliationGate = CategoryReconciliationGate()
        reconciliationGate.requireReconciliation(for: seeded.provider.generationToken)
        let hydrator = makeHydrator(
            seeded: seeded,
            stores: stores,
            categoryReconciliationGate: reconciliationGate
        )
        let recorder = HydrationPublicationRecorder(
            stores: stores,
            reconciliationGate: reconciliationGate,
            providerGeneration: seeded.provider.generationToken
        )
        let subscriptions = hydrationPublicationSubscriptions(stores: stores, recorder: recorder)

        let snapshot = try hydrator.stageHydration()

        #expect(recorder.events.isEmpty)
        #expect(recorder.firstObservation == nil)
        #expect(reconciliationGate.isBlocked(for: seeded.provider.generationToken))

        let expected = CompleteHydrationObservation.expected(
            RuntimeStoresSnapshot(snapshot)
        )
        #expect(expected.encodedAccounts != nil)

        hydrator.publish(snapshot)

        #expect(recorder.firstObservation?.matches(expected) == true)
        #expect(recorder.events == HydrationPublicationEvent.canonicalOrder)
        #expect(stores.transactions.lastValidation == nil)
        #expect(stores.fundingPlans.generation == seeded.provider.generationToken)
        #expect(!reconciliationGate.isBlocked(for: seeded.provider.generationToken))
        withExtendedLifetime(subscriptions) {}
    }

    @Test(.globalRuntimeStateIsolation)
    func sharedCanonicalPublicationSignalsAvailabilityBeforeStoresForMatchingGeneration() throws {
        let provider = DatabaseProvider(inMemory: true)
        DatabaseProvider.shared = provider
        ApplicationAvailability.shared.begin()
        CategoryReconciliationGate.shared.requireReconciliation(for: provider.generationToken)
        let stores = RuntimeStores(
            accounts: .shared,
            transactions: .shared,
            importSessions: .shared,
            importAttempts: .shared,
            categories: .shared,
            cards: .shared,
            salary: .shared,
            fundingPlans: .shared
        )
        defer {
            CardStore.shared.installSnapshotWithoutObservation(.empty)
            SalaryStore.shared.installWithoutObservation([])
            FundingPlanStore.shared.installWithoutObservation([], generation: nil)
            CategoryReconciliationGate.shared.resetForTesting()
            ApplicationAvailability.shared.begin()
        }
        let hydrator = RepositoryStoreHydrator(
            databaseProvider: provider,
            accountStore: .shared,
            transactionStore: .shared,
            categoryStore: .shared,
            importSessionStore: .shared,
            importAttemptStore: .shared,
            categoryReconciliationGate: .shared,
            participatesInLifecycleGate: false
        )
        let recorder = HydrationPublicationRecorder(
            stores: stores,
            reconciliationGate: .shared,
            providerGeneration: provider.generationToken
        )
        var subscriptions = [
            ApplicationAvailability.shared.$state.dropFirst().sink { _ in
                recorder.record(.applicationAvailability)
            }
        ]
        subscriptions.append(contentsOf: hydrationPublicationSubscriptions(stores: stores, recorder: recorder))

        let snapshot = try hydrator.stageHydration()

        #expect(recorder.events.isEmpty)
        #expect(CategoryReconciliationGate.shared.isBlocked(for: provider.generationToken))

        hydrator.publish(snapshot)

        #expect(
            recorder.firstObservation?.matches(CompleteHydrationObservation.expected(
                RuntimeStoresSnapshot(snapshot)
            )) == true
        )
        #expect(recorder.events == HydrationPublicationEvent.canonicalOrderWithAvailability)
        #expect(ApplicationAvailability.shared.state == .empty)
        #expect(ApplicationAvailability.shared.generation == provider.generationToken)
        #expect(!CategoryReconciliationGate.shared.isBlocked(for: provider.generationToken))
        withExtendedLifetime(subscriptions) {}
    }

    @Test(.globalRuntimeStateIsolation)
    func hydratorLoadsCommittedAuthenticRepositoryDataIntoRuntimeStores() async throws {
        let seeded = try await seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(seeded: seeded, stores: stores)

        let result = try hydrator.hydrateIfNeeded()

        #expect(result.didHydrate)
        #expect(result.accountCount == 1)
        #expect(result.transactionCount == seeded.plan.transactionTemplates.count)
        #expect(Set(stores.accounts.accounts.compactMap(\.repositoryAccountId)) == [seeded.plan.proposedAccount.id])
        #expect(Set(stores.transactions.transactions.compactMap(\.repositoryTransactionId)) == Set(seeded.plan.transactionTemplates.map(\.transaction.id)))
        #expect(Set(stores.transactions.transactions.compactMap(\.repositoryDocumentId)) == [seeded.plan.historyTemplate.document.id])
        #expect(Set(stores.transactions.transactions.compactMap(\.repositorySourceDocumentName)) == [seeded.plan.historyTemplate.document.filename])
        #expect(stores.importSessions.importSessions.map(\.id) == [seeded.plan.historyTemplate.importSession.id])
    }

    @Test(.globalRuntimeStateIsolation)
    func hydratorRedactsVerifiedStrongIdentifiersFromAuthenticSource() async throws {
        let seeded = try await seededProvider()
        // The mapper admits only strong, verified identifiers to this plan.
        // Keep the assertion tied to the untouched source-derived candidate
        // instead of manufacturing an AccountIdentifierDTO for hydration.
        let strongIdentifier = try #require(seeded.plan.identifiers.first)
        let stores = RuntimeStores()
        let hydrator = makeHydrator(seeded: seeded, stores: stores)

        _ = try hydrator.hydrateIfNeeded()

        let summaries = try #require(stores.accounts.accounts.first?.identitySummaries)
        let summary = try #require(summaries.first {
            $0.redactedValue == FinancialIdentifier.redacted(strongIdentifier.normalizedValue)
                && $0.provenance == strongIdentifier.provenanceCode
        })
        #expect(summary.strength == FinancialIdentifierStrength.strong.rawValue)
        #expect(summary.verificationState == FinancialIdentifierVerificationState.verified.rawValue)
        #expect(summary.redactedValue != strongIdentifier.normalizedValue)
    }

    @Test(.globalRuntimeStateIsolation)
    func hydratorRunsOnlyOnceUnlessForced() async throws {
        let seeded = try await seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(seeded: seeded, stores: stores)

        let firstResult = try hydrator.hydrateIfNeeded()
        let secondResult = try hydrator.hydrateIfNeeded()

        #expect(firstResult.didHydrate)
        #expect(!secondResult.didHydrate)
        #expect(stores.accounts.accounts.count == 1)
        #expect(stores.transactions.transactions.count == seeded.plan.transactionTemplates.count)
    }

    @Test(.globalRuntimeStateIsolation)
    func forcedHydrationPreservesRuntimeIdentityWithoutDuplicatingState() async throws {
        let seeded = try await seededProvider()
        let stores = RuntimeStores()
        let hydrator = makeHydrator(seeded: seeded, stores: stores)

        _ = try hydrator.hydrateIfNeeded()
        let firstIDs: [String: UUID] = Dictionary(uniqueKeysWithValues: stores.transactions.transactions.compactMap { transaction -> (String, UUID)? in
            guard let repositoryID = transaction.repositoryTransactionId else { return nil }
            return (repositoryID, transaction.id)
        })
        let refreshed = try hydrator.hydrateIfNeeded(forceRefresh: true)
        let refreshedIDs: [String: UUID] = Dictionary(uniqueKeysWithValues: stores.transactions.transactions.compactMap { transaction -> (String, UUID)? in
            guard let repositoryID = transaction.repositoryTransactionId else { return nil }
            return (repositoryID, transaction.id)
        })

        #expect(refreshed.didHydrate)
        #expect(refreshed.transactionCount == seeded.plan.transactionTemplates.count)
        #expect(stores.transactions.transactions.count == seeded.plan.transactionTemplates.count)
        #expect(refreshedIDs == firstIDs)
    }

    @Test(.globalRuntimeStateIsolation)
    func stageHydrationReadsEachAuthenticReferencedDocumentOnce() async throws {
        let seeded = try await seededProvider()
        let stores = RuntimeStores()
        let repository = ObservingImportSessionRepository(base: seeded.provider.importSessionRepo)
        let hydrator = makeHydrator(
            seeded: seeded,
            stores: stores,
            importSessionRepo: repository
        )

        _ = try hydrator.stageHydration()

        #expect(repository.documentReadIDs == [seeded.plan.historyTemplate.document.id])
    }

    @Test(.globalRuntimeStateIsolation)
    func documentReadFailurePreservesPreviouslyPublishedCompleteSnapshot() async throws {
        let seeded = try await seededProvider()
        let stores = RuntimeStores()
        let repository = ObservingImportSessionRepository(base: seeded.provider.importSessionRepo)
        let hydrator = makeHydrator(
            seeded: seeded,
            stores: stores,
            importSessionRepo: repository
        )
        _ = try hydrator.hydrateIfNeeded()
        let accountsBefore = stores.accounts.accounts.map(HydratedAccountObservation.init)
        let transactionsBefore = stores.transactions.transactions.map(HydratedTransactionObservation.init)
        let sessionsBefore = stores.importSessions.importSessions
        let attemptsBefore = stores.importAttempts.attempts
        repository.documentReadError = RepositoryError.persistenceUnavailable

        #expect(throws: RepositoryError.self) {
            _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        }

        #expect(stores.accounts.accounts.map(HydratedAccountObservation.init) == accountsBefore)
        #expect(HydratedTransactionObservation.matches(
            stores.transactions.transactions.map(HydratedTransactionObservation.init),
            transactionsBefore
        ))
        #expect(stores.importSessions.importSessions == sessionsBefore)
        #expect(stores.importAttempts.attempts == attemptsBefore)
    }
}

private struct SeededHydrationGraph {
    let provider: InMemoryRepositoryProvider
    let plan: ConfirmedImportPlanDTO
}

private struct RuntimeStores {
    let accounts: AccountStore
    let transactions: TransactionStore
    let importSessions: ImportSessionStore
    let importAttempts: ImportAttemptStore
    let categories: CategoryStore
    let cards: CardStore
    let salary: SalaryStore
    let fundingPlans: FundingPlanStore

    @MainActor
    init() {
        accounts = AccountStore()
        transactions = TransactionStore()
        importSessions = ImportSessionStore()
        importAttempts = ImportAttemptStore()
        categories = CategoryStore()
        cards = CardStore()
        salary = SalaryStore()
        fundingPlans = FundingPlanStore()
    }

    @MainActor
    init(
        accounts: AccountStore,
        transactions: TransactionStore,
        importSessions: ImportSessionStore,
        importAttempts: ImportAttemptStore,
        categories: CategoryStore,
        cards: CardStore,
        salary: SalaryStore,
        fundingPlans: FundingPlanStore
    ) {
        self.accounts = accounts
        self.transactions = transactions
        self.importSessions = importSessions
        self.importAttempts = importAttempts
        self.categories = categories
        self.cards = cards
        self.salary = salary
        self.fundingPlans = fundingPlans
    }
}

@MainActor
private func seededProvider() async throws -> SeededHydrationGraph {
    let provider = InMemoryRepositoryProvider()
    let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
    guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
        Issue.record("Authentic confirmed import did not commit before hydration.")
        throw RepositoryError.persistenceUnavailable
    }
    return SeededHydrationGraph(provider: provider, plan: plan)
}

@MainActor
private func makeHydrator(
    seeded: SeededHydrationGraph,
    stores: RuntimeStores,
    importSessionRepo: ImportSessionRepository? = nil,
    categoryReconciliationGate: CategoryReconciliationGate? = nil
) -> RepositoryStoreHydrator {
    RepositoryStoreHydrator(
        accountRepo: seeded.provider.accountRepo,
        importSessionRepo: importSessionRepo ?? seeded.provider.importSessionRepo,
        transactionRepo: seeded.provider.transactionRepo,
        categoryRepo: seeded.provider.categoryRepo,
        cardRepo: seeded.provider.cardRepo,
        salaryRepo: seeded.provider.salaryRepo,
        fundingPlanRepo: seeded.provider.fundingPlanRepo,
        accountStore: stores.accounts,
        transactionStore: stores.transactions,
        categoryStore: stores.categories,
        cardStore: stores.cards,
        salaryStore: stores.salary,
        fundingPlanStore: stores.fundingPlans,
        importSessionStore: stores.importSessions,
        importAttemptStore: stores.importAttempts,
        workspaceId: seeded.plan.workspace.id,
        persistenceState: .intentionalNonDurable(.testMemory),
        providerGeneration: seeded.provider.generationToken,
        categoryReconciliationGate: categoryReconciliationGate,
        participatesInLifecycleGate: false
    )
}

@MainActor
private func seedCategoryMetadata(in seeded: SeededHydrationGraph) throws {
    let categoryName = try CategoryName.validated("Observer Test")
    let category = try seeded.provider.categoryRepo.createCategory(CategoryDTO(
        id: "category-observer-test",
        workspaceId: seeded.plan.workspace.id,
        name: categoryName.display,
        normalizedName: categoryName.normalized,
        createdAtISO: "2026-09-10T00:00:00Z"
    ))
    let transactionID = try #require(seeded.plan.transactionTemplates.first?.transaction.id)
    #expect(try seeded.provider.categoryRepo.setCategory(
        categoryId: category.id,
        transactionId: transactionID,
        workspaceId: seeded.plan.workspace.id
    ))
}

private enum HydrationPublicationEvent: Equatable {
    case applicationAvailability
    case accountObjectWillChange
    case accounts
    case transactionObjectWillChange
    case transactions
    case transactionValidation
    case importSessionObjectWillChange
    case importSessions
    case importAttemptObjectWillChange
    case importAttempts
    case categoryObjectWillChange
    case categories
    case cardObjectWillChange
    case cards
    case salaryObjectWillChange
    case salaryStatements
    case fundingPlanObjectWillChange
    case fundingPlans

    static let canonicalOrder: [Self] = [
        .accountObjectWillChange, .accounts,
        .transactionObjectWillChange, .transactions, .transactionValidation,
        .importSessionObjectWillChange, .importSessions,
        .importAttemptObjectWillChange, .importAttempts,
        .categoryObjectWillChange, .categories,
        .cardObjectWillChange, .cards,
        .salaryObjectWillChange, .salaryStatements,
        .fundingPlanObjectWillChange, .fundingPlans
    ]

    static let canonicalOrderWithAvailability: [Self] = [
        .applicationAvailability
    ] + canonicalOrder
}

@MainActor
private final class HydrationPublicationRecorder {
    private let stores: RuntimeStores
    private let reconciliationGate: CategoryReconciliationGate
    private let providerGeneration: ProviderGenerationToken
    private(set) var events: [HydrationPublicationEvent] = []
    private(set) var firstObservation: CompleteHydrationObservation?

    init(
        stores: RuntimeStores,
        reconciliationGate: CategoryReconciliationGate,
        providerGeneration: ProviderGenerationToken
    ) {
        self.stores = stores
        self.reconciliationGate = reconciliationGate
        self.providerGeneration = providerGeneration
    }

    func record(_ event: HydrationPublicationEvent) {
        events.append(event)
        if firstObservation == nil {
            firstObservation = .capture(
                stores: RuntimeStoresSnapshot(stores),
                reconciliationGate: reconciliationGate,
                providerGeneration: providerGeneration
            )
        }
    }
}

@MainActor
private func hydrationPublicationSubscriptions(
    stores: RuntimeStores,
    recorder: HydrationPublicationRecorder
) -> [AnyCancellable] {
    [
        stores.accounts.objectWillChange.sink { recorder.record(.accountObjectWillChange) },
        stores.accounts.$accounts.dropFirst().sink { _ in recorder.record(.accounts) },
        stores.transactions.objectWillChange.sink { recorder.record(.transactionObjectWillChange) },
        stores.transactions.$transactions.dropFirst().sink { _ in recorder.record(.transactions) },
        stores.transactions.$lastValidation.dropFirst().sink { _ in recorder.record(.transactionValidation) },
        stores.importSessions.objectWillChange.sink { recorder.record(.importSessionObjectWillChange) },
        stores.importSessions.$importSessions.dropFirst().sink { _ in recorder.record(.importSessions) },
        stores.importAttempts.objectWillChange.sink { recorder.record(.importAttemptObjectWillChange) },
        stores.importAttempts.$attempts.dropFirst().sink { _ in recorder.record(.importAttempts) },
        stores.categories.objectWillChange.sink { recorder.record(.categoryObjectWillChange) },
        stores.categories.$snapshot.dropFirst().sink { _ in recorder.record(.categories) },
        stores.cards.objectWillChange.sink { recorder.record(.cardObjectWillChange) },
        stores.cards.$snapshot.dropFirst().sink { _ in recorder.record(.cards) },
        stores.salary.objectWillChange.sink { recorder.record(.salaryObjectWillChange) },
        stores.salary.$statements.dropFirst().sink { _ in recorder.record(.salaryStatements) },
        stores.fundingPlans.objectWillChange.sink { recorder.record(.fundingPlanObjectWillChange) },
        stores.fundingPlans.$plans.dropFirst().sink { _ in recorder.record(.fundingPlans) }
    ]
}

private struct RuntimeStoresSnapshot {
    let accounts: [Account]
    let transactions: [Transaction]
    let importSessions: [RepositoryImportSession]
    let importAttempts: [RepositoryImportAttempt]
    let categorySnapshot: CategorySnapshot
    let cardSnapshot: CardStoreSnapshot
    let salaryStatements: [SalaryStatement]
    let fundingPlans: [FundingPlan]
    let lastValidation: ImportValidationResult?
    let fundingPlanGeneration: ProviderGenerationToken?

    @MainActor
    init(_ stores: RuntimeStores) {
        accounts = stores.accounts.accounts
        transactions = stores.transactions.transactions
        importSessions = stores.importSessions.importSessions
        importAttempts = stores.importAttempts.attempts
        categorySnapshot = stores.categories.snapshot
        cardSnapshot = stores.cards.snapshot
        salaryStatements = stores.salary.statements
        fundingPlans = stores.fundingPlans.plans
        lastValidation = stores.transactions.lastValidation
        fundingPlanGeneration = stores.fundingPlans.generation
    }

    init(_ snapshot: RepositoryRuntimeSnapshot) {
        accounts = snapshot.accounts
        transactions = snapshot.transactions
        importSessions = snapshot.importSessions
        importAttempts = snapshot.importAttempts
        categorySnapshot = snapshot.categorySnapshot
        cardSnapshot = snapshot.cardSnapshot
        salaryStatements = snapshot.salaryStatements
        fundingPlans = snapshot.fundingPlans
        lastValidation = nil
        fundingPlanGeneration = snapshot.providerGeneration
    }
}

private struct CompleteHydrationObservation {
    let encodedAccounts: [Data]?
    let transactions: [HydratedTransactionObservation]
    let importSessions: [RepositoryImportSession]
    let importAttempts: [RepositoryImportAttempt]
    let categorySnapshot: CategorySnapshot
    let cardSnapshot: CardStoreSnapshot
    let salaryStatements: [SalaryStatement]
    let fundingPlans: [FundingPlan]
    let lastValidationIsNil: Bool
    let fundingPlanGeneration: ProviderGenerationToken?
    let reconciliationIsCleared: Bool

    @MainActor
    static func capture(
        stores: RuntimeStoresSnapshot,
        reconciliationGate: CategoryReconciliationGate,
        providerGeneration: ProviderGenerationToken
    ) -> Self {
        Self(
            encodedAccounts: encodeAccounts(stores.accounts),
            transactions: stores.transactions.map(HydratedTransactionObservation.init),
            importSessions: stores.importSessions,
            importAttempts: stores.importAttempts,
            categorySnapshot: stores.categorySnapshot,
            cardSnapshot: stores.cardSnapshot,
            salaryStatements: stores.salaryStatements,
            fundingPlans: stores.fundingPlans,
            lastValidationIsNil: stores.lastValidation == nil,
            fundingPlanGeneration: stores.fundingPlanGeneration,
            reconciliationIsCleared: !reconciliationGate.isBlocked(for: providerGeneration)
        )
    }

    @MainActor
    static func expected(_ stores: RuntimeStoresSnapshot) -> Self {
        Self(
            encodedAccounts: encodeAccounts(stores.accounts),
            transactions: stores.transactions.map(HydratedTransactionObservation.init),
            importSessions: stores.importSessions,
            importAttempts: stores.importAttempts,
            categorySnapshot: stores.categorySnapshot,
            cardSnapshot: stores.cardSnapshot,
            salaryStatements: stores.salaryStatements,
            fundingPlans: stores.fundingPlans,
            lastValidationIsNil: stores.lastValidation == nil,
            fundingPlanGeneration: stores.fundingPlanGeneration,
            reconciliationIsCleared: true
        )
    }

    @MainActor
    private static func encodeAccounts(_ accounts: [Account]) -> [Data]? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? accounts.map(encoder.encode)
    }

    @MainActor
    func matches(_ other: Self) -> Bool {
        encodedAccounts == other.encodedAccounts
            && HydratedTransactionObservation.matches(transactions, other.transactions)
            && importSessions == other.importSessions
            && importAttempts == other.importAttempts
            && categorySnapshot == other.categorySnapshot
            && cardSnapshot == other.cardSnapshot
            && salaryStatements == other.salaryStatements
            && fundingPlans == other.fundingPlans
            && lastValidationIsNil == other.lastValidationIsNil
            && fundingPlanGeneration == other.fundingPlanGeneration
            && reconciliationIsCleared == other.reconciliationIsCleared
    }
}

private struct HydratedTransactionObservation {
    let id: UUID
    let repositoryTransactionId: String?
    let statementDate: StatementDate?
    let valueDate: StatementDate?
    let financialDateRole: FinancialDateRole
    let statementTimezoneEvidence: StatementTimezoneEvidence
    let sourceProvenance: [TransactionSourceProvenance]
    let description: String
    let reference: String?
    let debitMoney: Money?
    let creditMoney: Money?
    let money: Money
    let runningBalanceMoney: Money?
    let cardLiabilityEffect: CardLiabilityEffect?
    let account: String
    let sourceBank: String
    let sourceFile: String
    let repositoryAccountId: String?
    let repositoryImportSessionId: String?
    let repositoryDocumentId: String?
    let repositorySourceDocumentName: String?
    let repositoryPreferredSourceDocumentName: String?
    let repositoryPreferredSourceFormatCode: String?
    let repositoryPreferredSourceTransactionDate: StatementDate?
    let repositoryPreferredStructuredReferenceDigest: String?
    let verifiedAxisUPIEventEvidence: AxisUPITransactionEventEvidence?

    init(_ transaction: Transaction) {
        id = transaction.id
        repositoryTransactionId = transaction.repositoryTransactionId
        statementDate = transaction.statementDate
        valueDate = transaction.valueDate
        financialDateRole = transaction.financialDateRole
        statementTimezoneEvidence = transaction.statementTimezoneEvidence
        sourceProvenance = transaction.sourceProvenance
        description = transaction.description
        reference = transaction.reference
        debitMoney = transaction.debitMoney
        creditMoney = transaction.creditMoney
        money = transaction.money
        runningBalanceMoney = transaction.runningBalanceMoney
        cardLiabilityEffect = transaction.cardLiabilityEffect
        account = transaction.account
        sourceBank = transaction.sourceBank
        sourceFile = transaction.sourceFile
        repositoryAccountId = transaction.repositoryAccountId
        repositoryImportSessionId = transaction.repositoryImportSessionId
        repositoryDocumentId = transaction.repositoryDocumentId
        repositorySourceDocumentName = transaction.repositorySourceDocumentName
        repositoryPreferredSourceDocumentName = transaction.repositoryPreferredSourceDocumentName
        repositoryPreferredSourceFormatCode = transaction.repositoryPreferredSourceFormatCode
        repositoryPreferredSourceTransactionDate = transaction.repositoryPreferredSourceTransactionDate
        repositoryPreferredStructuredReferenceDigest = transaction.repositoryPreferredStructuredReferenceDigest
        verifiedAxisUPIEventEvidence = transaction.verifiedAxisUPIEventEvidence
    }

    @MainActor
    func matches(_ other: Self) -> Bool {
        id == other.id
            && repositoryTransactionId == other.repositoryTransactionId
            && statementDate == other.statementDate
            && valueDate == other.valueDate
            && financialDateRole == other.financialDateRole
            && statementTimezoneEvidence == other.statementTimezoneEvidence
            && sourceProvenance == other.sourceProvenance
            && description == other.description
            && reference == other.reference
            && debitMoney == other.debitMoney
            && creditMoney == other.creditMoney
            && money == other.money
            && runningBalanceMoney == other.runningBalanceMoney
            && cardLiabilityEffect == other.cardLiabilityEffect
            && account == other.account
            && sourceBank == other.sourceBank
            && sourceFile == other.sourceFile
            && repositoryAccountId == other.repositoryAccountId
            && repositoryImportSessionId == other.repositoryImportSessionId
            && repositoryDocumentId == other.repositoryDocumentId
            && repositorySourceDocumentName == other.repositorySourceDocumentName
            && repositoryPreferredSourceDocumentName == other.repositoryPreferredSourceDocumentName
            && repositoryPreferredSourceFormatCode == other.repositoryPreferredSourceFormatCode
            && repositoryPreferredSourceTransactionDate == other.repositoryPreferredSourceTransactionDate
            && repositoryPreferredStructuredReferenceDigest == other.repositoryPreferredStructuredReferenceDigest
            && verifiedAxisUPIEventEvidence == other.verifiedAxisUPIEventEvidence
    }

    @MainActor
    static func matches(_ lhs: [Self], _ rhs: [Self]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (left, right) in zip(lhs, rhs) where !left.matches(right) {
            return false
        }
        return true
    }
}

private struct HydratedAccountObservation: Equatable {
    let id: UUID
    let repositoryAccountId: String?
    let workspaceId: String?
    let identitySummaries: [HydratedIdentityObservation]

    init(_ account: Account) {
        id = account.id
        repositoryAccountId = account.repositoryAccountId
        workspaceId = account.workspaceId
        identitySummaries = account.identitySummaries.map(HydratedIdentityObservation.init)
    }
}

private struct HydratedIdentityObservation: Equatable {
    let id: String
    let kind: String
    let redactedValue: String
    let strength: String
    let verificationState: String
    let provenance: String

    init(_ summary: AccountIdentitySummary) {
        id = summary.id
        kind = summary.kind
        redactedValue = summary.redactedValue
        strength = summary.strength
        verificationState = summary.verificationState
        provenance = summary.provenance
    }
}

/// Read-only observer around the repository that already owns the authentic
/// document. Its optional fault changes repository availability only.
private final class ObservingImportSessionRepository: ImportSessionRepository {
    private let base: ImportSessionRepository
    var documentReadError: Error?
    private(set) var documentReadIDs: [String] = []

    init(base: ImportSessionRepository) {
        self.base = base
    }

    func createImportSession(_ payload: ImportSessionDTO) throws -> String {
        try base.createImportSession(payload)
    }

    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws {
        try base.updateImportSession(id, updates: updates)
    }

    func importSession(id: String) throws -> ImportSessionRecordDTO? {
        try base.importSession(id: id)
    }

    func importedDocument(id: String) throws -> ImportedDocumentDTO? {
        documentReadIDs.append(id)
        if let documentReadError { throw documentReadError }
        return try base.importedDocument(id: id)
    }

    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO? {
        try base.priorImportedStatement(algorithm: algorithm, fingerprint: fingerprint)
    }

    func transactionEventOwners(
        keys: Set<TransactionEventIdentityKeyDTO>
    ) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] {
        try base.transactionEventOwners(keys: keys)
    }

    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String {
        try base.recordImportAttempt(payload)
    }

    func importAttempts(workspaceId: String) throws -> [ImportAttemptDTO] {
        try base.importAttempts(workspaceId: workspaceId)
    }

    func partialImportSummary(importSessionId: String) throws -> PartialImportSummaryDTO? {
        try base.partialImportSummary(importSessionId: importSessionId)
    }

    func incomingRowDispositions(importSessionId: String) throws -> [IncomingRowDispositionDTO] {
        try base.incomingRowDispositions(importSessionId: importSessionId)
    }

    func statementFinancialProjections(workspaceId: String) throws -> [StatementFinancialProjectionRecordDTO] {
        try base.statementFinancialProjections(workspaceId: workspaceId)
    }

    func statementZeroActivityControls(workspaceId: String) throws -> [StatementZeroActivityControlDTO] {
        try base.statementZeroActivityControls(workspaceId: workspaceId)
    }

    func statementEquivalenceGroups(workspaceId: String) throws -> [StatementEquivalenceGroupDTO] {
        try base.statementEquivalenceGroups(workspaceId: workspaceId)
    }

    func statementEquivalenceMembers(workspaceId: String) throws -> [StatementEquivalenceMemberDTO] {
        try base.statementEquivalenceMembers(workspaceId: workspaceId)
    }

    func preferredTransactionSources(workspaceId: String) throws -> [PreferredTransactionSourceDTO] {
        try base.preferredTransactionSources(workspaceId: workspaceId)
    }

    func cbqSourceObservationSummaries(workspaceId: String) throws -> [CBQSourceObservationSummaryDTO] {
        try base.cbqSourceObservationSummaries(workspaceId: workspaceId)
    }

    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult {
        try base.commitImportHistory(payload)
    }
}
