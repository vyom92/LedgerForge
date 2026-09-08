// LedgerForgeTests/RepositoryStoreHydratorTests.swift

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
        #expect(stores.transactions.transactions.map(HydratedTransactionObservation.init) == transactionsBefore)
        #expect(stores.importSessions.importSessions == sessionsBefore)
        #expect(stores.importAttempts.attempts == attemptsBefore)
    }
}

private struct SeededHydrationGraph {
    let provider: InMemoryRepositoryProvider
    let plan: ConfirmedImportPlanDTO
}

private struct RuntimeStores {
    let accounts = AccountStore()
    let transactions = TransactionStore()
    let importSessions = ImportSessionStore()
    let importAttempts = ImportAttemptStore()
    let categories = CategoryStore()
    let cards = CardStore()
    let salary = SalaryStore()
    let fundingPlans = FundingPlanStore()
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
    importSessionRepo: ImportSessionRepository? = nil
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
        participatesInLifecycleGate: false
    )
}

private struct HydratedTransactionObservation: Equatable {
    let id: UUID
    let repositoryTransactionId: String?
    let repositoryAccountId: String?
    let repositoryImportSessionId: String?
    let repositoryDocumentId: String?
    let repositorySourceDocumentName: String?

    init(_ transaction: Transaction) {
        id = transaction.id
        repositoryTransactionId = transaction.repositoryTransactionId
        repositoryAccountId = transaction.repositoryAccountId
        repositoryImportSessionId = transaction.repositoryImportSessionId
        repositoryDocumentId = transaction.repositoryDocumentId
        repositorySourceDocumentName = transaction.repositorySourceDocumentName
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
