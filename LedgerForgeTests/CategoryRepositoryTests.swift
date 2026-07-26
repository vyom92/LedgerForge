import Foundation
import Testing
@testable import LedgerForge

@Suite("Durable Categories", .serialized)
@MainActor
struct CategoryRepositoryTests {

    @Test func coordinatorCreatesFirstCategoryBeforeAnyImportAndHydratesIt() throws {
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

    @Test func lifecycleAndAssignmentBehaviorMatchesAcrossProvidersWithoutFinancialMutation() throws {
        for kind in CategoryProviderKind.allCases {
            try withCategoryProvider(kind) { provider in
                let seeded = try seedTrustedTransaction(in: provider, suffix: "category-\(kind.rawValue)")
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

    @Test func hydrationPublishesDurableCategoriesAndAssignmentsAcrossProviderReconstruction() throws {
        let concrete = InMemoryRepositoryProvider()
        let provider = DatabaseProvider(
            workspaceRepo: concrete.workspaceRepo,
            transactionRepo: concrete.transactionRepo,
            categoryRepo: concrete.categoryRepo,
            accountRepo: concrete.accountRepo,
            importSessionRepo: concrete.importSessionRepo,
            confirmedImportRepo: concrete.confirmedImportRepo,
            generationToken: concrete.generationToken
        )
        let seeded = try seedTrustedTransaction(in: provider, suffix: "category-memory-relaunch")
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

    @Test func sqliteCategoriesAndAssignmentsSurviveCloseReopenAndHydration() throws {
        try withTemporaryCategoryDatabase { path in
            var sqlite: SQLiteRepositoryProvider? = try SQLiteRepositoryProvider(path: path)
            let provider = DatabaseProvider.verifiedSQLite(try #require(sqlite), protectsGeneration: false)
            let seeded = try seedTrustedTransaction(in: provider, suffix: "category-sqlite-relaunch")
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

    @Test func populatedV7UpgradesToV8WithoutChangingExistingImportTruth() throws {
        try withTemporaryCategoryDatabase { path in
            let v7 = try SQLiteRepositoryProvider(path: path, migrations: Array(allMigrations.prefix(7)))
            let v7Provider = DatabaseProvider(
                workspaceRepo: v7.workspaceRepo,
                transactionRepo: v7.transactionRepo,
                accountRepo: v7.accountRepo,
                importSessionRepo: v7.importSessionRepo,
                confirmedImportRepo: v7.confirmedImportRepo,
                generationToken: v7.generationToken,
                persistenceState: .verifiedSQLite
            )
            let seeded = try seedTrustedTransaction(in: v7Provider, suffix: "category-v7-upgrade")
            let transactionBefore = try v7Provider.transactionRepo.trustedTransactions(workspaceId: seeded.workspaceID)
            let attemptsBefore = try v7Provider.importSessionRepo.importAttempts(workspaceId: seeded.workspaceID)
            v7.database.close()

            let v8 = try SQLiteRepositoryProvider(path: path)
            defer { v8.database.close() }
            #expect(try v8.database.queryInt("SELECT MAX(version) FROM schema_migrations;") == 8)
            #expect(try v8.categoryRepo.categories(workspaceId: seeded.workspaceID).isEmpty)
            #expect(try v8.categoryRepo.assignments(workspaceId: seeded.workspaceID).isEmpty)
            #expect(try v8.transactionRepo.trustedTransactions(workspaceId: seeded.workspaceID) == transactionBefore)
            #expect(try v8.importSessionRepo.importAttempts(workspaceId: seeded.workspaceID) == attemptsBefore)
        }
    }

    @Test func committedMutationBlocksEveryLaterCategoryWriteUntilCanonicalRetry() throws {
        let base = InMemoryRepositoryProvider()
        let countingRepository = CountingCategoryRepository(base.categoryRepo)
        let provider = DatabaseProvider(
            workspaceRepo: base.workspaceRepo,
            transactionRepo: base.transactionRepo,
            categoryRepo: countingRepository,
            accountRepo: base.accountRepo,
            importSessionRepo: base.importSessionRepo,
            confirmedImportRepo: base.confirmedImportRepo,
            generationToken: base.generationToken
        )
        let seeded = try seedTrustedTransaction(in: provider, suffix: "category-reconciliation")
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

    @Test func providerReplacementDoesNotInheritCategoryReconciliationBlock() throws {
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

private func seedTrustedTransaction(
    in provider: DatabaseProvider,
    suffix: String
) throws -> SeededCategoryTransaction {
    let base = confirmedImportPlan(
        generationToken: provider.generationToken,
        fingerprint: "category-fingerprint-\(suffix)",
        suffix: suffix
    )
    let template = base.transactionTemplates[0]
    let source = template.transaction
    let trustedTransaction = TransactionDTO(
        id: source.id,
        workspaceId: source.workspaceId,
        accountId: source.accountId,
        importSessionId: source.importSessionId,
        documentId: source.documentId,
        originalRowId: source.originalRowId,
        postedDateISO: source.postedDateISO,
        financialDateRole: source.financialDateRole,
        statementTimezoneEvidence: source.statementTimezoneEvidence,
        valueDateISO: source.valueDateISO,
        description: source.description,
        payee: source.payee,
        reference: source.reference,
        nativeCurrency: source.nativeCurrency,
        amountMinor: source.amountMinor,
        amountDecimal: source.amountDecimal,
        direction: source.direction,
        runningBalanceMinor: source.runningBalanceMinor,
        isReconciled: source.isReconciled,
        isTrusted: true,
        trustedAtISO: base.historyTemplate.completedAtISO,
        createdAtISO: source.createdAtISO,
        updatedAtISO: source.updatedAtISO,
        rawRows: source.rawRows
    )
    let plan = ConfirmedImportPlanDTO(
        providerGeneration: base.providerGeneration,
        workspace: base.workspace,
        proposedAccount: base.proposedAccount,
        accountChoice: base.accountChoice,
        advisoryIdentity: base.advisoryIdentity,
        identifiers: base.identifiers,
        historyTemplate: base.historyTemplate,
        transactionTemplates: [
            ConfirmedImportTransactionTemplateDTO(
                transaction: trustedTransaction,
                eventEvidence: template.eventEvidence
            )
        ],
        declaredStatementStartISO: base.declaredStatementStartISO,
        declaredStatementEndISO: base.declaredStatementEndISO,
        openingBalanceMinor: base.openingBalanceMinor,
        openingBalanceDecimal: base.openingBalanceDecimal,
        closingBalanceMinor: base.closingBalanceMinor,
        closingBalanceDecimal: base.closingBalanceDecimal
    )
    guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
        Issue.record("Confirmed import fixture did not commit.")
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

private func withCategoryProvider(
    _ kind: CategoryProviderKind,
    body: (DatabaseProvider) throws -> Void
) throws {
    switch kind {
    case .inMemory:
        try body(DatabaseProvider(inMemory: true))
    case .sqlite:
        try withTemporaryCategoryDatabase { path in
            let sqlite = try SQLiteRepositoryProvider(path: path)
            defer { sqlite.database.close() }
            try body(DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false))
        }
    }
}

private func withTemporaryCategoryDatabase(_ body: (String) throws -> Void) throws {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForgeCategoryTests")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try body(folder.appendingPathComponent("categories.sqlite").path)
}
