import Foundation
import Testing
@testable import LedgerForge

@Suite("Durable Categories", .serialized)
@MainActor
struct CategoryRepositoryTests {

    @Test(.globalRuntimeStateIsolation)
    func coordinatorCreatesFirstCategoryBeforeAnyImportAndHydratesIt() throws {
        let provider = DatabaseProvider(inMemory: true)
        let categoryStore = CategoryStore()
        let coordinator = CategoryManagementCoordinator(
            provider: { provider },
            categoryStore: categoryStore
        )

        #expect(try coordinator.create(name: "Groceries"))
        #expect(try provider.workspaceRepo.workspace(id: "default-workspace")?.name == "Personal")
        #expect(try provider.categoryRepo.categories(workspaceId: "default-workspace").map(\.name) == ["Groceries"])
        #expect(categoryStore.categories.map(\.name) == ["Groceries"])
        #expect(try coordinator.retryCanonicalHydration() == .notRequired)
    }

#if DEBUG
    @Test(.globalRuntimeStateIsolation)
    func directCategoryCoordinatorCallCannotBypassAcknowledgement() throws {
        let provider = DatabaseProvider(inMemory: true)
        let state = DevelopmentProfileAcknowledgementState(
            providerGeneration: provider.generationToken,
            profileKind: .migrationSandbox
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })
        let categoryStore = CategoryStore()
        let coordinator = CategoryManagementCoordinator(
            provider: { provider },
            categoryStore: categoryStore,
            acknowledgementGate: gate
        )

        let challenge: DevelopmentProfileAcknowledgementChallenge
        do {
            _ = try coordinator.create(name: "Blocked")
            Issue.record("Expected acknowledgement requirement")
            return
        } catch CategoryManagementCoordinatorError.acknowledgementRequired(let value) {
            challenge = value
        }

        #expect(try provider.categoryRepo.categories(workspaceId: "default-workspace").isEmpty)
        #expect(categoryStore.categories.isEmpty)
        #expect(gate.acknowledge(challenge) == .granted)
        #expect(try coordinator.create(name: "Approved"))
        #expect(try provider.categoryRepo.categories(workspaceId: "default-workspace").map(\.name) == ["Approved"])
    }

    @Test(.globalRuntimeStateIsolation)
    func everyCategoryAndTransactionMutationEntryPointUsesAcknowledgementGate() {
        let provider = DatabaseProvider(inMemory: true)
        let state = DevelopmentProfileAcknowledgementState(
            providerGeneration: provider.generationToken,
            profileKind: .temporarySession
        )
        let gate = DevelopmentProfileAcknowledgementGate(stateProvider: { state })
        let coordinator = CategoryManagementCoordinator(
            provider: { provider },
            categoryStore: CategoryStore(),
            acknowledgementGate: gate
        )

        func expectAcknowledgement(_ operation: () throws -> Void) {
            do {
                try operation()
                Issue.record("Expected acknowledgement requirement")
            } catch CategoryManagementCoordinatorError.acknowledgementRequired {
                // Expected before repository access.
            } catch {
                Issue.record("Unexpected error: \(error.localizedDescription)")
            }
        }

        expectAcknowledgement { _ = try coordinator.create(name: "Create") }
        expectAcknowledgement { _ = try coordinator.rename(categoryID: "category", name: "Rename") }
        expectAcknowledgement { _ = try coordinator.setArchived(categoryID: "category", isArchived: true) }
        expectAcknowledgement { _ = try coordinator.setArchived(categoryID: "category", isArchived: false) }
        expectAcknowledgement { try coordinator.deleteUnused(categoryID: "category") }
        expectAcknowledgement { _ = try coordinator.setCategory(categoryID: "category", transactionID: "transaction") }
        expectAcknowledgement { _ = try coordinator.setCategory(categoryID: nil, transactionID: "transaction") }
    }
#endif

    @Test(.globalRuntimeStateIsolation)
    func lifecycleAndAssignmentBehaviorMatchesAcrossProvidersWithoutFinancialMutation() async throws {
        for kind in CategoryProviderKind.allCases {
            try await withCategoryProvider(kind) { provider in
                let seeded = try await seedTrustedTransaction(in: provider)
                let financialBefore = try provider.transactionRepo.trustedTransactions(workspaceId: seeded.workspaceID)
                let attemptsBefore = try provider.importSessionRepo.importAttempts(workspaceId: seeded.workspaceID)

                let groceries = try createCategory(
                    name: "  Groceries  ",
                    id: "category-groceries-\(kind.rawValue)",
                    workspaceID: seeded.workspaceID,
                    repository: provider.categoryRepo
                )
                let travel = try createCategory(
                    name: "Travel",
                    id: "category-travel-\(kind.rawValue)",
                    workspaceID: seeded.workspaceID,
                    repository: provider.categoryRepo
                )
                #expect(groceries.name == "Groceries")
                #expect(groceries.normalizedName == "groceries")
                #expect(try provider.categoryRepo.categories(workspaceId: seeded.workspaceID).map(\.id) == [
                    groceries.id,
                    travel.id
                ])

                #expect(throws: CategoryRepositoryError.duplicateName) {
                    try createCategory(
                        name: " groceries ",
                        id: "category-duplicate-\(kind.rawValue)",
                        workspaceID: seeded.workspaceID,
                        repository: provider.categoryRepo
                    )
                }

                #expect(try provider.categoryRepo.renameCategory(
                    id: groceries.id,
                    workspaceId: seeded.workspaceID,
                    name: "Food & Dining",
                    updatedAtISO: "2026-07-26T01:00:00Z"
                ))
                #expect(try provider.categoryRepo.categories(workspaceId: seeded.workspaceID).first {
                    $0.id == groceries.id
                }?.name == "Food & Dining")

                #expect(try provider.categoryRepo.setCategoryArchived(
                    id: travel.id,
                    workspaceId: seeded.workspaceID,
                    isArchived: true,
                    updatedAtISO: "2026-07-26T01:01:00Z"
                ))
                #expect(throws: CategoryRepositoryError.categoryArchived) {
                    try provider.categoryRepo.setCategory(
                        categoryId: travel.id,
                        transactionId: seeded.transactionID,
                        workspaceId: seeded.workspaceID
                    )
                }
                #expect(try provider.categoryRepo.setCategoryArchived(
                    id: travel.id,
                    workspaceId: seeded.workspaceID,
                    isArchived: false,
                    updatedAtISO: "2026-07-26T01:02:00Z"
                ))

                #expect(try provider.categoryRepo.setCategory(
                    categoryId: groceries.id,
                    transactionId: seeded.transactionID,
                    workspaceId: seeded.workspaceID
                ))
                #expect(try provider.categoryRepo.assignments(workspaceId: seeded.workspaceID).map(\.categoryId) == [groceries.id])

                #expect(try provider.categoryRepo.setCategory(
                    categoryId: travel.id,
                    transactionId: seeded.transactionID,
                    workspaceId: seeded.workspaceID
                ))
                #expect(try provider.categoryRepo.assignments(workspaceId: seeded.workspaceID).map(\.categoryId) == [travel.id])

                #expect(throws: CategoryRepositoryError.categoryInUse) {
                    try provider.categoryRepo.deleteUnusedCategory(id: travel.id, workspaceId: seeded.workspaceID)
                }
                #expect(try provider.categoryRepo.setCategory(
                    categoryId: nil,
                    transactionId: seeded.transactionID,
                    workspaceId: seeded.workspaceID
                ))
                #expect(try provider.categoryRepo.assignments(workspaceId: seeded.workspaceID).isEmpty)

                try provider.categoryRepo.deleteUnusedCategory(id: travel.id, workspaceId: seeded.workspaceID)
                #expect(try provider.categoryRepo.categories(workspaceId: seeded.workspaceID).map(\.id) == [groceries.id])

                #expect(try provider.transactionRepo.trustedTransactions(workspaceId: seeded.workspaceID) == financialBefore)
                #expect(try provider.importSessionRepo.importAttempts(workspaceId: seeded.workspaceID) == attemptsBefore)
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func exactNewWorkConflictManualClearAndVersionRacesHaveProviderParity() async throws {
        for kind in CategoryProviderKind.allCases {
            try await withCategoryProvider(kind) { provider in
                let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
                guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
                    Issue.record("Genuine source import failed"); return
                }
                let workspace = plan.workspace.id
                let facts = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
                let first = try #require(facts.first { !($0.description ?? "").isEmpty })
                let repository = provider.categoryRepo
                let initial = try #require(try repository.automationSnapshot(workspaceId: workspace))
                #expect(initial.pendingIDs == Set(facts.map(\.id)))
                #expect(initial.work.values.allSatisfy { $0.origin == .newImport })
                _ = provider.confirmedImportRepo.commitConfirmedImport(plan)
                #expect(try repository.automationSnapshot(workspaceId: workspace) == initial)
                let a = try createCategory(name: "Review A", id: "rule-category-a", workspaceID: workspace, repository: repository)
                let b = try createCategory(name: "Review B", id: "rule-category-b", workspaceID: workspace, repository: repository)
                var rule = CategoryRule(id: "mechanics-rule", workspaceID: workspace, name: "Exact original narration", version: 1,
                    isEnabled: true, categoryID: a.id, accountID: first.accountId, currency: first.nativeCurrency,
                    direction: first.direction, predicates: [.init(field: .narration, match: .exact, text: try #require(first.description))])
                try repository.saveRule(rule, previousVersion: nil)
                var other = rule; other.id = "conflicting-rule"; other.categoryID = b.id
                try repository.saveRule(other, previousVersion: nil)
                @MainActor func evaluate() throws -> CategoryEvaluation {
                    CategoryEvaluation.evaluate(inputs: [.init(transaction: first)],
                        snapshot: try #require(try repository.automationSnapshot(workspaceId: workspace)),
                        assignments: Dictionary(uniqueKeysWithValues: try repository.assignments(workspaceId: workspace).map { ($0.transactionId, $0.categoryId) }),
                        activeCategoryIDs: [a.id, b.id])
                }
                let conflict = try evaluate()
                #expect(conflict.decisions.first?.outcome == .conflict)
                #expect(try repository.applyCategoryEvaluation(conflict, workspaceId: workspace, historical: false) == 1)
                #expect(try repository.assignments(workspaceId: workspace).isEmpty)
                #expect(try repository.automationSnapshot(workspaceId: workspace)?.work[first.id]?.outcome == .conflict)
                try repository.deleteRule(id: other.id, workspaceId: workspace, version: 1)
                let proposed = try evaluate()
                #expect(proposed.decisions.first?.categoryID == a.id)
                // Clearing a never-assigned row is still an explicit protected choice.
                #expect(try repository.setCategory(categoryId: nil, transactionId: first.id, workspaceId: workspace))
                #expect(try repository.applyCategoryEvaluation(proposed, workspaceId: workspace, historical: true) == 1)
                #expect(try repository.assignments(workspaceId: workspace).isEmpty)
                #expect(try repository.automationSnapshot(workspaceId: workspace)?.intents[first.id]?.kind == .deliberatelyCleared)
                #expect(try !repository.setCategory(categoryId: nil, transactionId: first.id, workspaceId: workspace))
                #expect(try repository.setCategory(categoryId: b.id, transactionId: first.id, workspaceId: workspace))
                #expect(try evaluate().decisions.first?.outcome == .protected)
                let oldPreview = try evaluate()
                rule.version += 1; rule.categoryID = b.id
                try repository.saveRule(rule, previousVersion: 1)
                #expect(throws: CategoryAutomationError.stalePreview) {
                    try repository.applyCategoryEvaluation(oldPreview, workspaceId: workspace, historical: true)
                }
                #expect(try repository.assignments(workspaceId: workspace).first?.categoryId == b.id)
                #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspace) == facts)
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func automaticAssignmentIsIdempotentAndChoosingTheSameCategoryMakesItManual() async throws {
        for kind in CategoryProviderKind.allCases {
            try await withCategoryProvider(kind) { provider in
                let seeded = try await seedTrustedTransaction(in: provider)
                let repository = provider.categoryRepo, workspace = seeded.workspaceID
                let facts = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
                let first = try #require(facts.first { !($0.description ?? "").isEmpty })
                let category = try createCategory(name: "Rule mechanics", id: "automatic-category", workspaceID: workspace, repository: repository)
                let rule = CategoryRule(id: "automatic-rule", workspaceID: workspace, name: "Exact source text", version: 1,
                    isEnabled: true, categoryID: category.id, accountID: first.accountId, currency: first.nativeCurrency,
                    direction: first.direction, predicates: [.init(field: .narration, match: .exact, text: try #require(first.description))])
                try repository.saveRule(rule, previousVersion: nil)
                let evaluation = CategoryEvaluation.evaluate(inputs: [.init(transaction: first)],
                    snapshot: try #require(try repository.automationSnapshot(workspaceId: workspace)), assignments: [:], activeCategoryIDs: [category.id])
                #expect(try repository.applyCategoryEvaluation(evaluation, workspaceId: workspace, historical: false) == 1)
                #expect(try repository.applyCategoryEvaluation(evaluation, workspaceId: workspace, historical: false) == 0)
                #expect(try repository.automationSnapshot(workspaceId: workspace)?.intents[first.id]?.kind == .automatic)
                var disabled = rule; disabled.version = 2; disabled.isEnabled = false
                try repository.saveRule(disabled, previousVersion: 1)
                let noMatch = CategoryEvaluation.evaluate(inputs: [.init(transaction: first)],
                    snapshot: try #require(try repository.automationSnapshot(workspaceId: workspace)),
                    assignments: [first.id: category.id], activeCategoryIDs: [category.id])
                #expect(noMatch.decisions.first?.outcome == .noMatch)
                #expect(try repository.applyCategoryEvaluation(noMatch, workspaceId: workspace, historical: true) == 1)
                #expect(try repository.assignments(workspaceId: workspace).isEmpty)
                #expect(try repository.automationSnapshot(workspaceId: workspace)?.intents[first.id] == nil)
                disabled.version = 3; disabled.isEnabled = true
                try repository.saveRule(disabled, previousVersion: 2)
                let again = CategoryEvaluation.evaluate(inputs: [.init(transaction: first)],
                    snapshot: try #require(try repository.automationSnapshot(workspaceId: workspace)),
                    assignments: [:], activeCategoryIDs: [category.id])
                #expect(try repository.applyCategoryEvaluation(again, workspaceId: workspace, historical: true) == 1)
                #expect(try repository.setCategory(categoryId: category.id, transactionId: first.id, workspaceId: workspace))
                #expect(try repository.automationSnapshot(workspaceId: workspace)?.intents[first.id]?.kind == .manual)
                let stores = CategoryRuntimeStores()
                _ = try makeHydrator(provider: provider, stores: stores, workspaceID: workspace).hydrateIfNeeded(forceRefresh: true)
                #expect(stores.categories.snapshot.automation?.intents[first.id]?.kind == .manual)
                #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspace) == facts)
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func categoryWorkerResumesReplacementGenerationAfterOldEvaluationReturns() async throws {
        let first = DatabaseProvider(inMemory: true), second = DatabaseProvider(inMemory: true)
        let oldSeed = try await seedTrustedTransaction(in: first)
        let newSeed = try await seedTrustedTransaction(in: second)
        let stores = CategoryRuntimeStores()
        var current = first
        let gate = CategoryEvaluationPause()
        let oldFacts = try first.transactionRepo.trustedTransactions(workspaceId: oldSeed.workspaceID)
        let newFacts = try second.transactionRepo.trustedTransactions(workspaceId: newSeed.workspaceID)
        _ = try makeHydrator(provider: first, stores: stores, workspaceID: oldSeed.workspaceID).hydrateIfNeeded(forceRefresh: true)
        let session = CategoryAutomationSession(categories: stores.categories, transactions: stores.transactions,
            provider: { current }, coordinator: {
                CategoryManagementCoordinator(provider: { current }, workspaceID: newSeed.workspaceID, categoryStore: stores.categories,
                    forcedHydration: { provider, _, workspace in
                        try makeHydrator(provider: provider, stores: stores, workspaceID: workspace).hydrateIfNeeded(forceRefresh: true)
                    })
            }, enabled: true, evaluate: { inputs, snapshot, assignments, active in
                await gate.pauseFirst()
                return CategoryEvaluation.evaluate(inputs: inputs, snapshot: snapshot, assignments: assignments, activeCategoryIDs: active)
            })
        session.start()
        for _ in 0..<100 {
            if await gate.hasStarted { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await gate.hasStarted)
        current = second
        _ = try makeHydrator(provider: second, stores: stores, workspaceID: newSeed.workspaceID).hydrateIfNeeded(forceRefresh: true)
        await gate.release()
        for _ in 0..<150 {
            if !session.isWorking && stores.categories.snapshot.automation?.pendingIDs.isEmpty == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(!session.isWorking)
        #expect(try second.categoryRepo.automationSnapshot(workspaceId: newSeed.workspaceID)?.pendingIDs.isEmpty == true)
        #expect(try first.categoryRepo.automationSnapshot(workspaceId: oldSeed.workspaceID)?.pendingIDs == Set(oldFacts.map(\.id)))
        #expect(try first.transactionRepo.trustedTransactions(workspaceId: oldSeed.workspaceID) == oldFacts)
        #expect(try second.transactionRepo.trustedTransactions(workspaceId: newSeed.workspaceID) == newFacts)
    }

    @Test(.globalRuntimeStateIsolation)
    func hydrationPublishesDurableCategoriesAndAssignmentsAcrossProviderReconstruction() async throws {
        let concrete = InMemoryRepositoryProvider()
        let provider = DatabaseProvider(
            workspaceRepo: concrete.workspaceRepo,
            transactionRepo: concrete.transactionRepo,
            categoryRepo: concrete.categoryRepo,
            accountRepo: concrete.accountRepo,
            cardRepo: concrete.cardRepo,
            importSessionRepo: concrete.importSessionRepo,
            confirmedImportRepo: concrete.confirmedImportRepo,
            generationToken: concrete.generationToken
        )
        let seeded = try await seedTrustedTransaction(in: provider)
        let category = try createCategory(
            name: "Utilities",
            id: "category-utilities-memory",
            workspaceID: seeded.workspaceID,
            repository: provider.categoryRepo
        )
        _ = try provider.categoryRepo.setCategory(
            categoryId: category.id,
            transactionId: seeded.transactionID,
            workspaceId: seeded.workspaceID
        )

        let reconstructed = DatabaseProvider(
            workspaceRepo: concrete.workspaceRepo,
            transactionRepo: concrete.transactionRepo,
            categoryRepo: concrete.categoryRepo,
            accountRepo: concrete.accountRepo,
            cardRepo: concrete.cardRepo,
            importSessionRepo: concrete.importSessionRepo,
            confirmedImportRepo: concrete.confirmedImportRepo,
            generationToken: concrete.generationToken
        )
        let stores = CategoryRuntimeStores()
        let result = try makeHydrator(provider: reconstructed, stores: stores, workspaceID: seeded.workspaceID)
            .hydrateIfNeeded(forceRefresh: true)

        #expect(result.categoryCount == 1)
        #expect(result.categoryAssignmentCount == 1)
        #expect(stores.categories.category(forTransactionID: seeded.transactionID)?.name == "Utilities")
        #expect(stores.transactions.transactions.first?.repositoryTransactionId == seeded.transactionID)
    }

    @Test(.globalRuntimeStateIsolation)
    func sqliteCategoriesAndAssignmentsSurviveCloseReopenAndHydration() async throws {
        try await withTemporaryCategoryDatabase { path in
            var sqlite: SQLiteRepositoryProvider? = try SQLiteRepositoryProvider(path: path)
            let provider = DatabaseProvider.verifiedSQLite(try #require(sqlite), protectsGeneration: false)
            let seeded = try await seedTrustedTransaction(in: provider)
            let category = try createCategory(
                name: "Home",
                id: "category-home-sqlite",
                workspaceID: seeded.workspaceID,
                repository: provider.categoryRepo
            )
            _ = try provider.categoryRepo.setCategory(
                categoryId: category.id,
                transactionId: seeded.transactionID,
                workspaceId: seeded.workspaceID
            )
            sqlite?.database.close()
            sqlite = nil

            let reopened = try SQLiteRepositoryProvider(path: path)
            defer { reopened.database.close() }
            let reconstructed = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
            let stores = CategoryRuntimeStores()
            let result = try makeHydrator(
                provider: reconstructed,
                stores: stores,
                workspaceID: seeded.workspaceID
            ).hydrateIfNeeded(forceRefresh: true)

            #expect(try reopened.categoryRepo.categories(workspaceId: seeded.workspaceID).map(\.name) == ["Home"])
            #expect(try reopened.categoryRepo.assignments(workspaceId: seeded.workspaceID).map(\.transactionId) == [seeded.transactionID])
            #expect(result.categoryCount == 1)
            #expect(result.categoryAssignmentCount == 1)
            #expect(stores.categories.category(forTransactionID: seeded.transactionID)?.id == category.id)
            #expect(stores.transactions.transactions.first?.repositoryTransactionId == seeded.transactionID)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func committedMutationBlocksEveryLaterCategoryWriteUntilCanonicalRetry() async throws {
        let base = InMemoryRepositoryProvider()
        let countingRepository = CountingCategoryRepository(base.categoryRepo)
        let provider = DatabaseProvider(
            workspaceRepo: base.workspaceRepo,
            transactionRepo: base.transactionRepo,
            categoryRepo: countingRepository,
            accountRepo: base.accountRepo,
            cardRepo: base.cardRepo,
            importSessionRepo: base.importSessionRepo,
            confirmedImportRepo: base.confirmedImportRepo,
            generationToken: base.generationToken
        )
        let seeded = try await seedTrustedTransaction(in: provider)
        let existing = try createCategory(
            name: "Existing",
            id: "category-existing-reconciliation",
            workspaceID: seeded.workspaceID,
            repository: provider.categoryRepo
        )
        let archived = try createCategory(
            name: "Archived",
            id: "category-archived-reconciliation",
            workspaceID: seeded.workspaceID,
            repository: provider.categoryRepo
        )
        _ = try provider.categoryRepo.setCategoryArchived(
            id: archived.id,
            workspaceId: seeded.workspaceID,
            isArchived: true,
            updatedAtISO: "2026-07-26T02:00:00Z"
        )

        let stores = CategoryRuntimeStores()
        let gate = CategoryReconciliationGate()
        _ = try makeHydrator(
            provider: provider,
            stores: stores,
            workspaceID: seeded.workspaceID,
            reconciliationGate: gate
        ).hydrateIfNeeded(forceRefresh: true)
        let previousSnapshot = stores.categories.snapshot
        var hydrationShouldFail = true
        let coordinator = CategoryManagementCoordinator(
            provider: { provider },
            workspaceID: seeded.workspaceID,
            categoryStore: stores.categories,
            reconciliationGate: gate,
            forcedHydration: { provider, categoryStore, workspaceID in
                if hydrationShouldFail { throw CategoryHydrationTestError.failed }
                return try RepositoryStoreHydrator(
                    databaseProvider: provider,
                    categoryStore: categoryStore,
                    workspaceId: workspaceID,
                    categoryReconciliationGate: gate,
                    participatesInLifecycleGate: false
                ).hydrateIfNeeded(forceRefresh: true)
            }
        )

        #expect(throws: CategoryManagementCoordinatorError.savedButRefreshFailed) {
            _ = try coordinator.create(name: "Committed")
        }
        #expect(try provider.categoryRepo.categories(workspaceId: seeded.workspaceID).contains { $0.name == "Committed" })
        #expect(stores.categories.snapshot == previousSnapshot)
        #expect(gate.isBlocked(for: provider.generationToken))

        let writesBeforeBlockedAttempts = countingRepository.writeCount
        let blockedOperations: [() throws -> Void] = [
            { _ = try coordinator.create(name: "Blocked create") },
            { _ = try coordinator.rename(categoryID: existing.id, name: "Blocked rename") },
            { _ = try coordinator.setArchived(categoryID: existing.id, isArchived: true) },
            { _ = try coordinator.setArchived(categoryID: archived.id, isArchived: false) },
            { try coordinator.deleteUnused(categoryID: existing.id) },
            { _ = try coordinator.setCategory(categoryID: existing.id, transactionID: seeded.transactionID) },
            { _ = try coordinator.setCategory(categoryID: archived.id, transactionID: seeded.transactionID) },
            { _ = try coordinator.setCategory(categoryID: nil, transactionID: seeded.transactionID) }
        ]
        for operation in blockedOperations {
            #expect(throws: CategoryManagementCoordinatorError.reconciliationRequired, performing: operation)
        }
        #expect(countingRepository.writeCount == writesBeforeBlockedAttempts)
        #expect(stores.categories.snapshot == previousSnapshot)

        #expect(try coordinator.retryCanonicalHydration() == .failed)
        #expect(gate.isBlocked(for: provider.generationToken))
        #expect(stores.categories.snapshot == previousSnapshot)

        hydrationShouldFail = false
        #expect(try coordinator.retryCanonicalHydration() == .succeeded)
        #expect(!gate.isBlocked(for: provider.generationToken))
        #expect(stores.categories.categories.contains { $0.name == "Committed" })
        #expect(try coordinator.rename(categoryID: existing.id, name: "Renamed after retry"))
    }

    @Test(.globalRuntimeStateIsolation)
    func providerReplacementDoesNotInheritCategoryReconciliationBlock() throws {
        let first = DatabaseProvider(inMemory: true)
        let second = DatabaseProvider(inMemory: true)
        var current = first
        let categoryStore = CategoryStore()
        let gate = CategoryReconciliationGate()
        var hydrationShouldFail = true
        let coordinator = CategoryManagementCoordinator(
            provider: { current },
            categoryStore: categoryStore,
            reconciliationGate: gate,
            forcedHydration: { provider, categoryStore, workspaceID in
                if hydrationShouldFail { throw CategoryHydrationTestError.failed }
                return try RepositoryStoreHydrator(
                    databaseProvider: provider,
                    categoryStore: categoryStore,
                    workspaceId: workspaceID,
                    categoryReconciliationGate: gate,
                    participatesInLifecycleGate: false
                ).hydrateIfNeeded(forceRefresh: true)
            }
        )

        #expect(throws: CategoryManagementCoordinatorError.savedButRefreshFailed) {
            _ = try coordinator.create(name: "Old provider category")
        }
        #expect(gate.isBlocked(for: first.generationToken))
        current = second
        #expect(!gate.isBlocked(for: second.generationToken))

        let retry = try coordinator.retryCanonicalHydration()
        #expect(retry == .failed)
        #expect(gate.isBlocked(for: first.generationToken))
        #expect(!gate.isBlocked(for: second.generationToken))

        hydrationShouldFail = false
        #expect(try coordinator.retryCanonicalHydration() == .succeeded)
        #expect(!gate.hasPendingReconciliation)
        #expect(categoryStore.categories.isEmpty)
        #expect(try coordinator.create(name: "Replacement category"))
        #expect(categoryStore.categories.map(\.name) == ["Replacement category"])
    }

    @Test func categoryReconciliationStateIsProcessLocalPerGateAndDoesNotLeak() throws {
        let firstGate = CategoryReconciliationGate()
        let secondGate = CategoryReconciliationGate()
        let firstProvider = DatabaseProvider(inMemory: true)
        let secondProvider = DatabaseProvider(inMemory: true)

        firstGate.requireReconciliation(for: firstProvider.generationToken)

        #expect(firstGate.isBlocked(for: firstProvider.generationToken))
        #expect(!secondGate.hasPendingReconciliation)
        #expect(!secondGate.isBlocked(for: secondProvider.generationToken))
    }
}

private enum CategoryProviderKind: String, CaseIterable {
    case inMemory
    case sqlite
}

private struct SeededCategoryTransaction {
    let workspaceID: String
    let transactionID: String
}

@MainActor
private struct CategoryRuntimeStores {
    let accounts = AccountStore()
    let transactions = TransactionStore()
    let sessions = ImportSessionStore()
    let attempts = ImportAttemptStore()
    let categories = CategoryStore()
}

@MainActor
private func makeHydrator(
    provider: DatabaseProvider,
    stores: CategoryRuntimeStores,
    workspaceID: String,
    reconciliationGate: CategoryReconciliationGate? = nil
) -> RepositoryStoreHydrator {
    RepositoryStoreHydrator(
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo,
        categoryRepo: provider.categoryRepo,
        accountStore: stores.accounts,
        transactionStore: stores.transactions,
        categoryStore: stores.categories,
        importSessionStore: stores.sessions,
        importAttemptStore: stores.attempts,
        workspaceId: workspaceID,
        persistenceState: provider.persistenceState,
        providerGeneration: provider.generationToken,
        categoryReconciliationGate: reconciliationGate,
        participatesInLifecycleGate: false
    )
}

private enum CategoryHydrationTestError: Error {
    case failed
}

private final class CountingCategoryRepository: CategoryRepository {
    private let base: CategoryRepository
    private(set) var writeCount = 0

    init(_ base: CategoryRepository) {
        self.base = base
    }

    func categories(workspaceId: String) throws -> [CategoryDTO] {
        try base.categories(workspaceId: workspaceId)
    }

    func assignments(workspaceId: String) throws -> [TransactionCategoryAssignmentDTO] {
        try base.assignments(workspaceId: workspaceId)
    }

    func createCategory(_ category: CategoryDTO) throws -> CategoryDTO {
        writeCount += 1
        return try base.createCategory(category)
    }

    func renameCategory(id: String, workspaceId: String, name: String, updatedAtISO: String) throws -> Bool {
        writeCount += 1
        return try base.renameCategory(id: id, workspaceId: workspaceId, name: name, updatedAtISO: updatedAtISO)
    }

    func setCategoryArchived(id: String, workspaceId: String, isArchived: Bool, updatedAtISO: String) throws -> Bool {
        writeCount += 1
        return try base.setCategoryArchived(id: id, workspaceId: workspaceId, isArchived: isArchived, updatedAtISO: updatedAtISO)
    }

    func deleteUnusedCategory(id: String, workspaceId: String) throws {
        writeCount += 1
        try base.deleteUnusedCategory(id: id, workspaceId: workspaceId)
    }

    func setCategory(categoryId: String?, transactionId: String, workspaceId: String) throws -> Bool {
        writeCount += 1
        return try base.setCategory(categoryId: categoryId, transactionId: transactionId, workspaceId: workspaceId)
    }
}

@MainActor
private func createCategory(
    name: String,
    id: String,
    workspaceID: String,
    repository: CategoryRepository
) throws -> CategoryDTO {
    let validated = try CategoryName.validated(name)
    return try repository.createCategory(CategoryDTO(
        id: id,
        workspaceId: workspaceID,
        name: validated.display,
        normalizedName: validated.normalized,
        createdAtISO: "2026-07-26T00:00:00Z"
    ))
}

@MainActor
private func seedTrustedTransaction(
    in provider: DatabaseProvider
) async throws -> SeededCategoryTransaction {
    let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
    guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
        Issue.record("Authentic confirmed import did not commit.")
        throw CategoryRepositoryError.transactionNotFound
    }
    let durableTransaction = try #require(
        provider.transactionRepo.trustedTransactions(workspaceId: plan.workspace.id).first
    )
    return SeededCategoryTransaction(
        workspaceID: durableTransaction.workspaceId,
        transactionID: durableTransaction.id
    )
}

@MainActor
private func withCategoryProvider(
    _ kind: CategoryProviderKind,
    body: (DatabaseProvider) async throws -> Void
) async throws {
    switch kind {
    case .inMemory:
        try await body(DatabaseProvider(inMemory: true))
    case .sqlite:
        try await withTemporaryCategoryDatabase { path in
            let sqlite = try SQLiteRepositoryProvider(path: path)
            defer { sqlite.database.close() }
            try await body(DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false))
        }
    }
}

@MainActor
private func withTemporaryCategoryDatabase(_ body: (String) async throws -> Void) async throws {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForgeCategoryTests")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try await body(folder.appendingPathComponent("categories.sqlite").path)
}

private actor CategoryEvaluationPause {
    private(set) var hasStarted = false
    private var continuation: CheckedContinuation<Void, Never>?
    func pauseFirst() async {
        guard !hasStarted else { return }
        hasStarted = true
        await withCheckedContinuation { continuation = $0 }
    }
    func release() { continuation?.resume(); continuation = nil }
}
