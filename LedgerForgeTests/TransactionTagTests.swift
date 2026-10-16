import Combine
import Foundation
import Testing
@testable import LedgerForge

@Suite("Manual transaction tags", .serialized)
@MainActor
struct TransactionTagTests {
    @Test
    func tagNamesTrimOnlyBoundaryWhitespaceAndDoNotInventUniqueness() throws {
        #expect(try TransactionTagName.validated(" \nContext label\t ") == "Context label")
        #expect(try TransactionTagName.validated("  A  B  ") == "A  B")
        #expect(try TransactionTagName.validated(" \u{00E9} ") == "\u{00E9}")
        #expect(throws: TransactionTagError.invalidName) { try TransactionTagName.validated(" \t\n\u{00A0}") }
        #expect(throws: TransactionTagError.invalidName) { try TransactionTagName.validated("Context\0hidden") }
    }

    @Test(.globalRuntimeStateIsolation)
    func sourceIndependentDefinitionAndStaleEditContractsHaveProviderParity() throws {
        try withTagProviders { provider, _ in
            let workspace = "tag-mechanics"
            _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Tag mechanics", createdAtISO: "2026-10-04T00:00:00Z"))
            let first = TransactionTagDefinition(id: "tag-mechanics-first", workspaceID: workspace, name: "  Context  ")
            #expect(try provider.tagRepo.saveTag(first, replacing: nil))
            let saved = try first.canonicalized()
            let duplicateName = TransactionTagDefinition(id: "tag-mechanics-second", workspaceID: workspace, name: saved.name)
            #expect(try provider.tagRepo.saveTag(duplicateName, replacing: nil))
            #expect(try provider.tagRepo.snapshot(workspaceID: workspace)?.definitions.count == 2)
            #expect(try !provider.tagRepo.saveTag(saved, replacing: saved))
            #expect(throws: TransactionTagError.staleReview) { try provider.tagRepo.saveTag(saved, replacing: nil) }

            let renamed = TransactionTagDefinition(id: saved.id, workspaceID: workspace, name: "Renamed context")
            #expect(try provider.tagRepo.saveTag(renamed, replacing: saved))
            #expect(throws: TransactionTagError.staleReview) { try provider.tagRepo.saveTag(saved, replacing: saved) }
            #expect(throws: TransactionTagError.staleReview) { try provider.tagRepo.removeTag(saved, expectedTransactionIDs: []) }
            #expect(throws: TransactionTagError.emptySelection) {
                try provider.tagRepo.setMembership(tag: renamed, transactionIDs: [], isAttached: true, expectedAttachedTransactionIDs: [])
            }
            #expect(throws: TransactionTagError.transactionNotFound) {
                try provider.tagRepo.setMembership(tag: renamed, transactionIDs: ["missing-transaction"], isAttached: true, expectedAttachedTransactionIDs: [])
            }
            #expect(try provider.tagRepo.snapshot(workspaceID: workspace)?.memberships.isEmpty == true)
            #expect(throws: TransactionTagError.invalidName) {
                try provider.tagRepo.saveTag(.init(id: renamed.id, workspaceID: workspace, name: "\t\n"), replacing: renamed)
            }
            #expect(try provider.tagRepo.removeTag(renamed, expectedTransactionIDs: []))
            #expect(try provider.tagRepo.snapshot(workspaceID: workspace)?.definitions == [duplicateName])
            #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspace).isEmpty)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func explicitHistoricalCapabilityIsUnavailableAndCurrentReadErrorsThrow() throws {
        try withTagDatabase { path in
            let old = try SQLiteRepositoryProvider(path: path, migrations: Array(allMigrations.prefix(33)))
            #expect(try old.tagRepo.snapshot(workspaceID: "tag-mechanics") == nil)
            #expect(throws: TransactionTagError.unavailable) {
                try old.tagRepo.saveTag(.init(workspaceID: "tag-mechanics", name: "Context"), replacing: nil)
            }
            try old.database.checkpointAndClose()
            #expect(throws: SQLiteRepositoryProviderError.migrationIntegrityFailed(.missingPersistedVersion(34))) {
                _ = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing)
            }
            let current = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing, migrateExisting: true)
            defer { current.database.close() }
            _ = try current.workspaceRepo.upsertWorkspace(.init(id: "tag-mechanics", name: "Tag mechanics", createdAtISO: "2026-10-04T00:00:00Z"))
            let tag = TransactionTagDefinition(workspaceID: "tag-mechanics", name: "Context")
            #expect(try current.tagRepo.saveTag(tag, replacing: nil))
            try SQLiteTransactionTagRepository.verifyBackupContents(current.database)
            // SQLite trim does not cover all Foundation whitespace. Loading
            // present owner metadata must still reject an invalid name.
            try current.database.executePrepared(sql: "UPDATE tag_definitions SET name = ? WHERE id = ?;", params: ["\t", tag.id])
            #expect(throws: TransactionTagError.invalidName) { try current.tagRepo.snapshot(workspaceID: "tag-mechanics") }
            #expect(throws: TransactionTagError.invalidName) { try SQLiteTransactionTagRepository.verifyBackupContents(current.database) }
            try current.database.executePrepared(sql: "UPDATE tag_definitions SET name = ? WHERE id = ?;", params: [tag.name, tag.id])
            try current.database.executePrepared(sql: "UPDATE tag_definitions SET name = name || char(0) || 'hidden' WHERE id = ?;", params: [tag.id])
            #expect(throws: TransactionTagError.invalidState) { try SQLiteTransactionTagRepository.verifyBackupContents(current.database) }
            try current.database.executePrepared(sql: "UPDATE tag_definitions SET name = ? WHERE id = ?;", params: [tag.name, tag.id])
            try current.database.execute(sql: "ALTER TABLE transaction_tag_memberships RENAME TO missing_tag_memberships;")
            #expect(throws: (any Error).self) { try current.tagRepo.snapshot(workspaceID: "tag-mechanics") }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func currentTagEditsPublishCompleteMetadataWithoutFullHydration() throws {
        try withTagProviders { provider, _ in
            let workspace = "tag-current-refresh"
            _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Tag mechanics", createdAtISO: "2026-10-04T00:00:00Z"))
            let retained = TransactionTagDefinition(workspaceID: workspace, name: "Retained context")
            #expect(try provider.tagRepo.saveTag(retained, replacing: nil))
            let tags = TransactionTagStore(), gate = CategoryReconciliationGate()
            _ = try RepositoryStoreHydrator(databaseProvider: provider, tagStore: tags, workspaceId: workspace,
                categoryReconciliationGate: gate, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
            let unrelatedGeneration = ProviderGenerationToken()
            gate.requireReconciliation(for: unrelatedGeneration)
            var fullRefreshes = 0, financialPublications = 0
            var publications: [TransactionTagSnapshot] = []
            let tagObservation = tags.objectWillChange.sink {
                #expect(tags.generation == provider.generationToken)
                if let snapshot = tags.snapshot { publications.append(snapshot) }
            }
            let financialObservation = TransactionStore.shared.objectWillChange.sink { financialPublications += 1 }
            defer { tagObservation.cancel(); financialObservation.cancel() }
            let coordinator = TransactionTagCoordinator(provider: { provider }, tagStore: tags, gate: gate,
                refresh: { _, _, _ in fullRefreshes += 1; throw TagTestFailure.refresh })
            let created = TransactionTagDefinition(workspaceID: workspace, name: "New context")
            #expect(try coordinator.saveTag(created, replacing: nil, generation: provider.generationToken))
            let createdSnapshot = try #require(try provider.tagRepo.snapshot(workspaceID: workspace))
            #expect(tags.snapshot == createdSnapshot)
            #expect(createdSnapshot.definitions.contains(retained))
            let renamed = TransactionTagDefinition(id: created.id, workspaceID: workspace, name: "Renamed context")
            #expect(try coordinator.saveTag(renamed, replacing: created, generation: provider.generationToken))
            let renamedSnapshot = try #require(try provider.tagRepo.snapshot(workspaceID: workspace))
            #expect(tags.snapshot == renamedSnapshot)
            #expect(try !coordinator.saveTag(renamed, replacing: renamed, generation: provider.generationToken))
            #expect(publications.count == 2)
            #expect(try coordinator.removeTag(renamed, expectedTransactionIDs: [], generation: provider.generationToken))
            let finalSnapshot = try #require(try provider.tagRepo.snapshot(workspaceID: workspace))
            #expect(tags.snapshot == finalSnapshot && finalSnapshot.definitions == [retained])
            #expect(publications == [createdSnapshot, renamedSnapshot, finalSnapshot])
            #expect(fullRefreshes == 0 && financialPublications == 0)
            #expect(gate.isBlocked(for: unrelatedGeneration))
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func tagRefreshRequiresCurrentRuntimeAndRetryReconcilesOtherMetadata() throws {
        let provider = DatabaseProvider(inMemory: true)
        let workspace = "tag-recovery-refresh"
        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Tag mechanics", createdAtISO: "2026-10-04T00:00:00Z"))
        let tag = TransactionTagDefinition(workspaceID: workspace, name: "Context")
        #expect(try provider.tagRepo.saveTag(tag, replacing: nil))
        let tags = TransactionTagStore(), gate = CategoryReconciliationGate()
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, tagStore: tags, workspaceId: workspace,
            categoryReconciliationGate: gate, participatesInLifecycleGate: false)
        #expect(try !hydrator.refreshTransactionTagsIfCurrent())
        tags.installWithoutObservation(.empty(workspaceID: workspace), generation: ProviderGenerationToken())
        #expect(try !hydrator.refreshTransactionTagsIfCurrent())
        tags.installWithoutObservation(.empty(workspaceID: "other-workspace"), generation: provider.generationToken)
        #expect(try !hydrator.refreshTransactionTagsIfCurrent())
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        let savedTags = tags.snapshot
        let categoryName = try CategoryName.validated("Pending category metadata")
        let category = try provider.categoryRepo.createCategory(.init(id: UUID().uuidString, workspaceId: workspace,
            name: categoryName.display, normalizedName: categoryName.normalized, createdAtISO: "2026-10-04T00:00:00Z"))
        #expect(CategoryStore.shared.categories.isEmpty)
        gate.requireReconciliation(for: provider.generationToken)
        #expect(try !hydrator.refreshTransactionTagsIfCurrent())
        #expect(gate.isBlocked(for: provider.generationToken))
        let coordinator = TransactionTagCoordinator(provider: { provider }, tagStore: tags, gate: gate)
        #expect(throws: TransactionTagError.refreshRequired) {
            try coordinator.removeTag(tag, expectedTransactionIDs: [], generation: provider.generationToken)
        }
        try coordinator.retryRefresh(workspaceID: workspace, generation: provider.generationToken)
        #expect(!gate.hasPendingReconciliation)
        #expect(tags.snapshot == savedTags)
        #expect(CategoryStore.shared.categories.map(\.id) == [category.id])
        #expect(try provider.tagRepo.snapshot(workspaceID: workspace) == savedTags)
    }

    @Test(.globalRuntimeStateIsolation)
    func currentTagReadFailureRetainsRuntimeAndFullRetryDoesNotRepeatTheWrite() throws {
        let memory = InMemoryRepositoryProvider()
        let probe = TagRefreshReadFailureProbe(base: memory.tagRepo)
        let provider = DatabaseProvider(workspaceRepo: memory.workspaceRepo, transactionRepo: memory.transactionRepo,
            categoryRepo: memory.categoryRepo, accountRepo: memory.accountRepo, cardRepo: memory.cardRepo,
            importSessionRepo: memory.importSessionRepo, confirmedImportRepo: memory.confirmedImportRepo,
            salaryRepo: memory.salaryRepo, fundingPlanRepo: memory.fundingPlanRepo, investmentRepo: memory.investmentRepo,
            netWorthMembershipRepo: memory.netWorthMembershipRepo, intelligenceRepo: memory.intelligenceRepo,
            tagRepo: probe, generationToken: memory.generationToken, protectsGeneration: true)
        let workspace = "tag-read-failure"
        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Tag mechanics", createdAtISO: "2026-10-04T00:00:00Z"))
        let tags = TransactionTagStore(), gate = CategoryReconciliationGate()
        _ = try RepositoryStoreHydrator(databaseProvider: provider, tagStore: tags, workspaceId: workspace,
            categoryReconciliationGate: gate, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
        let before = tags.snapshot
        var publications = 0
        let observation = tags.objectWillChange.sink { publications += 1 }
        defer { observation.cancel() }
        let coordinator = TransactionTagCoordinator(provider: { provider }, tagStore: tags, gate: gate)
        let tag = TransactionTagDefinition(workspaceID: workspace, name: "Committed context")
        probe.failReadAfterNextSave = true
        #expect(throws: TransactionTagError.savedButRefreshFailed) {
            try coordinator.saveTag(tag, replacing: nil, generation: provider.generationToken)
        }
        #expect(try memory.tagRepo.snapshot(workspaceID: workspace)?.definitions == [tag])
        #expect(tags.snapshot == before && tags.generation == provider.generationToken && publications == 0)
        #expect(gate.isBlocked(for: provider.generationToken) && probe.saveCount == 1)
        #expect(throws: TransactionTagError.refreshRequired) {
            try coordinator.retryRefresh(workspaceID: workspace, generation: provider.generationToken)
        }
        #expect(tags.snapshot == before && publications == 0 && probe.saveCount == 1)
        let name = try CategoryName.validated("Pending unrelated metadata")
        let category = try provider.categoryRepo.createCategory(.init(id: UUID().uuidString, workspaceId: workspace,
            name: name.display, normalizedName: name.normalized, createdAtISO: "2026-10-04T00:00:00Z"))
        probe.readsFail = false
        try coordinator.retryRefresh(workspaceID: workspace, generation: provider.generationToken)
        #expect(tags.snapshot?.definitions == [tag] && publications == 1 && probe.saveCount == 1)
        #expect(CategoryStore.shared.categories.map(\.id) == [category.id])
        #expect(!gate.hasPendingReconciliation)
    }

    @Test(.globalRuntimeStateIsolation)
    func committedTagChangeRefreshesWithoutRepeatingItsMutationAndRejectsStaleGeneration() throws {
        let provider = DatabaseProvider(inMemory: true)
        let store = TransactionTagStore()
        let gate = CategoryReconciliationGate()
        let workspace = "tag-mechanics"
        var refreshShouldFail = true
        let coordinator = TransactionTagCoordinator(provider: { provider }, tagStore: store, gate: gate,
            refresh: { current, tags, workspace in
                if refreshShouldFail { throw TagTestFailure.refresh }
                _ = try RepositoryStoreHydrator(databaseProvider: current, tagStore: tags, workspaceId: workspace,
                    categoryReconciliationGate: gate, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
            })
        let tag = TransactionTagDefinition(workspaceID: workspace, name: "Context")
        #expect(throws: TransactionTagError.savedButRefreshFailed) {
            try coordinator.saveTag(tag, replacing: nil, generation: provider.generationToken)
        }
        #expect(try provider.tagRepo.snapshot(workspaceID: workspace)?.definitions == [tag])
        #expect(store.snapshot == nil)
        #expect(gate.isBlocked(for: provider.generationToken))
        #expect(throws: TransactionTagError.refreshRequired) {
            try coordinator.saveTag(.init(workspaceID: workspace, name: "Blocked"), replacing: nil, generation: provider.generationToken)
        }
        #expect(throws: TransactionTagError.refreshRequired) {
            try coordinator.removeTag(tag, expectedTransactionIDs: [], generation: provider.generationToken)
        }
        #expect(throws: TransactionTagError.refreshRequired) {
            try coordinator.setMembership(tag: tag, transactionIDs: ["missing-transaction"], isAttached: true,
                expectedAttachedTransactionIDs: [], generation: provider.generationToken)
        }
        #expect(throws: TransactionTagError.refreshRequired) {
            try coordinator.retryRefresh(workspaceID: workspace, generation: provider.generationToken)
        }
        refreshShouldFail = false
        try coordinator.retryRefresh(workspaceID: workspace, generation: provider.generationToken)
        #expect(!gate.hasPendingReconciliation)
        #expect(store.snapshot?.definitions == [tag])
        #expect(store.generation == provider.generationToken)
        do {
            _ = try coordinator.removeTag(tag, expectedTransactionIDs: [], generation: ProviderGenerationToken())
            Issue.record("An inactive generation must not mutate tags.")
        } catch RepositoryError.staleProviderGeneration {
            // The exact frozen provider generation is required.
        }
        #expect(try provider.tagRepo.snapshot(workspaceID: workspace)?.definitions == [tag])
        #expect(try coordinator.removeTag(tag, expectedTransactionIDs: [], generation: provider.generationToken))
        #expect(store.snapshot?.definitions.isEmpty == true)
    }

#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
    @Test(.globalRuntimeStateIsolation)
    func tagMutationCannotBypassDevelopmentProfileAcknowledgement() throws {
        let provider = DatabaseProvider(inMemory: true)
        let state = DevelopmentProfileAcknowledgementState(providerGeneration: provider.generationToken, profileKind: .temporarySession)
        let acknowledgement = DevelopmentProfileAcknowledgementGate(stateProvider: { state })
        let coordinator = TransactionTagCoordinator(provider: { provider }, tagStore: TransactionTagStore(),
            gate: CategoryReconciliationGate(), acknowledgementGate: acknowledgement)
        let tag = TransactionTagDefinition(workspaceID: "tag-mechanics", name: "Context")
        do {
            _ = try coordinator.saveTag(tag, replacing: nil, generation: provider.generationToken)
            Issue.record("A development profile must be acknowledged before a tag change.")
        } catch DevelopmentProfileAcknowledgementError.acknowledgementRequired(let challenge) {
            #expect(try provider.tagRepo.snapshot(workspaceID: tag.workspaceID)?.definitions.isEmpty == true)
            #expect(acknowledgement.acknowledge(challenge) == .granted)
            #expect(try coordinator.saveTag(tag, replacing: nil, generation: provider.generationToken))
        }
    }
#endif

    @Test(.globalRuntimeStateIsolation)
    func membershipBatchFilteringAndDeletionHaveProviderParityWithoutFinancialChanges() async throws {
        try await withImportedTagProviders { provider, sqlite in
            let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
            guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
                Issue.record("The synthetic source must commit before tag membership is exercised.")
                return
            }
            let workspace = plan.workspace.id
            let factsBefore = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
            let selected = Set(factsBefore.prefix(2).map(\.id))
            #expect(selected.count == 2, "This membership check requires two fixture transactions.")
            guard selected.count == 2, let firstID = selected.sorted().first else { return }
            let categoriesBefore = try provider.categoryRepo.assignments(workspaceId: workspace)
            let automationBefore = try provider.categoryRepo.automationSnapshot(workspaceId: workspace)
            let attemptsBefore = try provider.importSessionRepo.importAttempts(workspaceId: workspace)
            let digestBefore = try sqlite.map { try NetWorthTestSupport.financialDigest($0.database, excluding: tagTables) }
            let tag = TransactionTagDefinition(workspaceID: workspace, name: "Context qualification")
            let second = TransactionTagDefinition(workspaceID: workspace, name: tag.name)
            #expect(try provider.tagRepo.saveTag(tag, replacing: nil))
            #expect(try provider.tagRepo.saveTag(second, replacing: nil))
            #expect(try provider.tagRepo.setMembership(tag: tag, transactionIDs: selected, isAttached: true, expectedAttachedTransactionIDs: []))
            let attached = try #require(try provider.tagRepo.snapshot(workspaceID: workspace))
            let exactAttachment = attached.transactionIDs(tagID: tag.id) == selected
            #expect(exactAttachment)
            let tagFilterMatches = selected.allSatisfy { attached.matches(transactionID: $0, filter: .tag(tag.id)) }
            let taggedExcludedFromUntagged = selected.allSatisfy { !attached.matches(transactionID: $0, filter: .untagged) }
            #expect(tagFilterMatches)
            #expect(taggedExcludedFromUntagged)
            #expect(!attached.matches(transactionID: nil, filter: .tag(tag.id)))
            #expect(try !provider.tagRepo.setMembership(tag: tag, transactionIDs: selected, isAttached: true, expectedAttachedTransactionIDs: selected))
            #expect(throws: TransactionTagError.staleReview) {
                try provider.tagRepo.setMembership(tag: tag, transactionIDs: selected, isAttached: false, expectedAttachedTransactionIDs: [])
            }
            #expect(throws: TransactionTagError.staleReview) {
                try provider.tagRepo.removeTag(tag, expectedTransactionIDs: [firstID])
            }
            #expect(throws: TransactionTagError.transactionNotFound) {
                try provider.tagRepo.setMembership(tag: second, transactionIDs: [firstID, "missing-transaction"], isAttached: true, expectedAttachedTransactionIDs: [])
            }
            let failedBatchIsAtomic = try provider.tagRepo.snapshot(workspaceID: workspace) == attached
            #expect(failedBatchIsAtomic)

            let tags = TransactionTagStore(), gate = CategoryReconciliationGate()
            _ = try RepositoryStoreHydrator(databaseProvider: provider, tagStore: tags, workspaceId: workspace,
                categoryReconciliationGate: gate, participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
            let coordinator = TransactionTagCoordinator(provider: { provider }, tagStore: tags, gate: gate,
                refresh: { _, _, _ in throw TagTestFailure.refresh })
            let secondAttached = try coordinator.setMembership(tag: second, transactionIDs: [firstID], isAttached: true,
                expectedAttachedTransactionIDs: [], generation: provider.generationToken)
            let attachmentRefreshedExactly = try tags.snapshot == provider.tagRepo.snapshot(workspaceID: workspace)
            #expect(secondAttached && attachmentRefreshedExactly)
            let renamed = TransactionTagDefinition(id: tag.id, workspaceID: workspace, name: "Renamed qualification")
            let tagRenamed = try coordinator.saveTag(renamed, replacing: tag, generation: provider.generationToken)
            let renameRefreshedExactly = try tags.snapshot == provider.tagRepo.snapshot(workspaceID: workspace)
            #expect(tagRenamed && renameRefreshedExactly)
            #expect(throws: TransactionTagError.staleReview) {
                try provider.tagRepo.setMembership(tag: tag, transactionIDs: selected, isAttached: false, expectedAttachedTransactionIDs: selected)
            }
            let selectedDetached = try coordinator.setMembership(tag: renamed, transactionIDs: [firstID], isAttached: false,
                expectedAttachedTransactionIDs: [firstID], generation: provider.generationToken)
            let detachmentRefreshedExactly = try tags.snapshot == provider.tagRepo.snapshot(workspaceID: workspace)
            #expect(selectedDetached && detachmentRefreshedExactly)
            let tagRemoved = try coordinator.removeTag(renamed, expectedTransactionIDs: selected.subtracting([firstID]),
                generation: provider.generationToken)
            #expect(tagRemoved)
            let after = try #require(try provider.tagRepo.snapshot(workspaceID: workspace))
            let removalRefreshedExactly = tags.snapshot == after && tags.generation == provider.generationToken
            #expect(removalRefreshedExactly)
            let onlyOtherTagRemains = after.definitions == [second] && after.transactionIDs(tagID: second.id) == [firstID]
            #expect(onlyOtherTagRemains)
            let factsUnchanged = try provider.transactionRepo.trustedTransactions(workspaceId: workspace) == factsBefore
            let categoriesUnchanged = try provider.categoryRepo.assignments(workspaceId: workspace) == categoriesBefore
            let automationUnchanged = try provider.categoryRepo.automationSnapshot(workspaceId: workspace) == automationBefore
            let attemptsUnchanged = try provider.importSessionRepo.importAttempts(workspaceId: workspace) == attemptsBefore
            #expect(factsUnchanged)
            #expect(categoriesUnchanged)
            #expect(automationUnchanged)
            #expect(attemptsUnchanged)
            if let sqlite, let digestBefore {
                let financialGraphUnchanged = try NetWorthTestSupport.financialDigest(sqlite.database, excluding: tagTables) == digestBefore
                #expect(financialGraphUnchanged)
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func tagFiltersComposeWithSearchCategoryAndHistoricalAccounts() async throws {
        try await withImportedTagProviders { provider, _ in
            let plan = try await confirmedImportPlan(generationToken: provider.generationToken)
            guard case .committed = provider.confirmedImportRepo.commitConfirmedImport(plan) else {
                Issue.record("The synthetic source must commit before tag filtering is exercised.")
                return
            }
            let workspace = plan.workspace.id
            let facts = try provider.transactionRepo.trustedTransactions(workspaceId: workspace)
            guard facts.count >= 3 else {
                Issue.record("Tag filtering requires at least three fixture transactions.")
                return
            }
            let selected = Set(facts.prefix(2).map(\.id))
            let firstID = facts[0].id
            let categoryName = try CategoryName.validated("Filter qualification")
            let category = try provider.categoryRepo.createCategory(.init(id: UUID().uuidString, workspaceId: workspace,
                name: categoryName.display, normalizedName: categoryName.normalized, createdAtISO: "2026-10-04T00:00:00Z"))
            #expect(try provider.categoryRepo.setCategory(categoryId: category.id, transactionId: firstID, workspaceId: workspace))
            let tag = TransactionTagDefinition(workspaceID: workspace, name: "Filter context")
            #expect(try provider.tagRepo.saveTag(tag, replacing: nil))
            #expect(try provider.tagRepo.setMembership(tag: tag, transactionIDs: selected, isAttached: true, expectedAttachedTransactionIDs: []))

            let accounts = AccountStore()
            let transactions = TransactionStore()
            let categories = CategoryStore()
            let tags = TransactionTagStore()
            let imports = ImportSessionStore()
            let hydrator = RepositoryStoreHydrator(databaseProvider: provider, accountStore: accounts,
                transactionStore: transactions, categoryStore: categories, tagStore: tags, importSessionStore: imports,
                workspaceId: workspace, participatesInLifecycleGate: false)
            let snapshot = try hydrator.stageHydration()
            hydrator.publish(snapshot)
            let rows = TransactionPresentationEngine.rows(transactions: snapshot.transactions, accounts: snapshot.accounts,
                categories: snapshot.categorySnapshot.categories, assignments: snapshot.categorySnapshot.assignments)
            let first = try #require(rows.first { $0.transaction.repositoryTransactionId == firstID })
            let accountID = try #require(first.accountID)
            let date = try #require(first.sourceCivilDate)
            var combined = TransactionPresentationFilterSpec.empty
            combined.tag = .tag(tag.id)
            combined.categories = [.categoryID(category.id)]
            combined.searchText = first.transaction.description
            combined.accountIDs = [accountID]
            combined.currencies = [first.transaction.money.currency]
            combined.statementDateRange = .init(start: date, end: date)
            let model = TransactionListViewModel(transactionStore: transactions, importSessionStore: imports,
                accountStore: accounts, categoryStore: categories, tagStore: tags)
            model.synchronizePresentation(generation: provider.generationToken, availabilityState: .current)
            model.presentationFilter = combined
            let combinedIDsAreExact = model.transactionPresentationResult.rows.compactMap { $0.transaction.repositoryTransactionId } == [firstID]
            #expect(combinedIDsAreExact)
            model.presentationFilter.searchText = "ledgerforge-tag-filter-no-match-f057d0"
            #expect(model.transactionPresentationResult.state == .validEmpty)
            model.presentationFilter = combined

            var untagged = TransactionPresentationFilterSpec.empty
            untagged.accountIDs = Set(snapshot.accounts.compactMap(\.repositoryAccountId))
            untagged.tag = .untagged
            let untaggedResult = TransactionPresentationEngine.evaluate(rows: rows, accounts: snapshot.accounts,
                categories: snapshot.categorySnapshot.categories, filter: untagged, sort: .init(), availability: .available,
                tagSnapshot: snapshot.tags)
            let untaggedIDsAreExact = Set(untaggedResult.rows.compactMap { $0.transaction.repositoryTransactionId }) == Set(facts.map(\.id)).subtracting(selected)
            #expect(untaggedIDsAreExact)
            for filter in [combined, untagged] {
                let unavailableTags = TransactionPresentationEngine.evaluate(rows: rows, accounts: snapshot.accounts,
                    categories: snapshot.categorySnapshot.categories, filter: filter, sort: .init(), availability: .available)
                #expect(unavailableTags.state == .invalidSelection)
                #expect(unavailableTags.rows.isEmpty && unavailableTags.totals == .empty)
            }
            var unknownTag = untagged
            unknownTag.tag = .tag("unavailable-tag-definition")
            let unknown = TransactionPresentationEngine.evaluate(rows: rows, accounts: snapshot.accounts,
                categories: snapshot.categorySnapshot.categories, filter: unknownTag, sort: .init(), availability: .available,
                tagSnapshot: snapshot.tags)
            #expect(unknown.state == .invalidSelection)
            #expect(unknown.rows.isEmpty && unknown.totals == .empty)

            #expect(try provider.accountRepo.markAccountHistoryOnly(accountId: accountID, workspaceId: workspace,
                markedAtISO: "2026-10-04T00:01:00Z"))
            let historical = try hydrator.stageHydration()
            let historicalRows = TransactionPresentationEngine.rows(transactions: historical.transactions, accounts: historical.accounts,
                categories: historical.categorySnapshot.categories, assignments: historical.categorySnapshot.assignments)
            var historicalFilter = combined
            historicalFilter.accountIDs = []
            let currentOnly = TransactionPresentationEngine.evaluate(rows: historicalRows, accounts: historical.accounts,
                categories: historical.categorySnapshot.categories, filter: historicalFilter, sort: .init(), availability: .available,
                tagSnapshot: historical.tags)
            #expect(currentOnly.state == .validEmpty)
            historicalFilter.accountIDs = [accountID]
            let explicitHistory = TransactionPresentationEngine.evaluate(rows: historicalRows, accounts: historical.accounts,
                categories: historical.categorySnapshot.categories, filter: historicalFilter, sort: .init(), availability: .available,
                tagSnapshot: historical.tags)
            let historicalIDsAreExact = explicitHistory.rows.compactMap { $0.transaction.repositoryTransactionId } == [firstID]
            #expect(historicalIDsAreExact)

            let revision = model.canonicalContentRevision
            #expect(try provider.tagRepo.setMembership(tag: tag, transactionIDs: [firstID], isAttached: false,
                expectedAttachedTransactionIDs: [firstID]))
            hydrator.publish(try hydrator.stageHydration())
            for _ in 0..<100 where model.canonicalContentRevision == revision {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(model.canonicalContentRevision > revision)
            #expect(model.transactionPresentationResult.state == .validEmpty)
            let factsUnchanged = try provider.transactionRepo.trustedTransactions(workspaceId: workspace) == facts
            #expect(factsUnchanged)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func tagsSurviveCanonicalHydrationNativeBackupRestoreAndReopen() async throws {
        try await withAsyncTagDatabase { folder, path in
            let sqlite = try SQLiteRepositoryProvider(path: path)
            defer { sqlite.database.close() }
            let plan = try await confirmedImportPlan(generationToken: sqlite.generationToken)
            guard case .committed = sqlite.confirmedImportRepo.commitConfirmedImport(plan) else {
                Issue.record("The synthetic source must commit before tag recovery is exercised.")
                return
            }
            let workspace = plan.workspace.id
            let facts = try sqlite.transactionRepo.trustedTransactions(workspaceId: workspace)
            let id = try #require(facts.first?.id)
            let tag = TransactionTagDefinition(workspaceID: workspace, name: "Recovery qualification")
            #expect(try sqlite.tagRepo.saveTag(tag, replacing: nil))
            #expect(try sqlite.tagRepo.setMembership(tag: tag, transactionIDs: [id], isAttached: true, expectedAttachedTransactionIDs: []))
            let saved = try #require(try sqlite.tagRepo.snapshot(workspaceID: workspace))
            let digest = try NetWorthTestSupport.financialDigest(sqlite.database, excluding: tagTables)
            let provider = DatabaseProvider.verifiedSQLite(sqlite)
            let store = TransactionTagStore()
            _ = try RepositoryStoreHydrator(databaseProvider: provider, tagStore: store, workspaceId: workspace,
                participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
            let hydratedExactly = store.snapshot == saved
            #expect(hydratedExactly)
            #expect(store.generation == provider.generationToken)

            let backups = folder.appendingPathComponent("backups")
            try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: false)
            let coordinator = BackupRestoreCoordinator(testingAt: URL(fileURLWithPath: path))
            DatabaseProvider.shared = provider
            coordinator.installTestProvider(sqlite)
            await coordinator.createBackup(to: backups)
            let package = try #require(coordinator.lastBackupURL)
            let manifest = try BackupFiles.verifyPackage(package)
            #expect(manifest.schemaVersion == BackupCompatibility.supportedSchemaVersion)
            let destination = folder.appendingPathComponent("restored.sqlite")
            _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: destination)
            let restored = try SQLiteRepositoryProvider(path: destination.path, migrations: allMigrations, access: .existing)
            let restoredExactly = try restored.tagRepo.snapshot(workspaceID: workspace) == saved
            let restoredFinancialFacts = try NetWorthTestSupport.financialDigest(restored.database, excluding: tagTables) == digest
            #expect(restoredExactly)
            #expect(restoredFinancialFacts)
            try restored.database.checkpointAndClose()
            let reopened = try SQLiteRepositoryProvider(path: destination.path, migrations: allMigrations, access: .existing)
            defer { reopened.database.close() }
            let reopenedExactly = try reopened.tagRepo.snapshot(workspaceID: workspace) == saved
            #expect(reopenedExactly)
            let reopenedStore = TransactionTagStore()
            let reopenedProvider = DatabaseProvider.verifiedSQLite(reopened)
            _ = try RepositoryStoreHydrator(databaseProvider: reopenedProvider, tagStore: reopenedStore, workspaceId: workspace,
                participatesInLifecycleGate: false).hydrateIfNeeded(forceRefresh: true)
            let reopenedHydrationMatches = reopenedStore.snapshot == saved
            #expect(reopenedHydrationMatches)
        }
    }

    private var tagTables: Set<String> { ["tag_definitions", "transaction_tag_memberships"] }
}

private enum TagTestFailure: Error { case refresh }

/// A nonfinancial read fault after the real metadata repository has committed.
@MainActor
private final class TagRefreshReadFailureProbe: TransactionTagRepository {
    let base: any TransactionTagRepository
    var failReadAfterNextSave = false
    var readsFail = false
    private(set) var saveCount = 0

    init(base: any TransactionTagRepository) { self.base = base }

    func snapshot(workspaceID: String) throws -> TransactionTagSnapshot? {
        if readsFail { throw TagTestFailure.refresh }
        return try base.snapshot(workspaceID: workspaceID)
    }

    func saveTag(_ tag: TransactionTagDefinition, replacing expected: TransactionTagDefinition?) throws -> Bool {
        let changed = try base.saveTag(tag, replacing: expected)
        saveCount += 1
        if changed && failReadAfterNextSave { readsFail = true; failReadAfterNextSave = false }
        return changed
    }

    func removeTag(_ tag: TransactionTagDefinition, expectedTransactionIDs: Set<String>) throws -> Bool {
        try base.removeTag(tag, expectedTransactionIDs: expectedTransactionIDs)
    }

    func setMembership(tag: TransactionTagDefinition, transactionIDs: Set<String>, isAttached: Bool,
                       expectedAttachedTransactionIDs: Set<String>) throws -> Bool {
        try base.setMembership(tag: tag, transactionIDs: transactionIDs, isAttached: isAttached,
            expectedAttachedTransactionIDs: expectedAttachedTransactionIDs)
    }
}

@MainActor
private func withTagProviders(_ body: (DatabaseProvider, SQLiteRepositoryProvider?) throws -> Void) throws {
    try body(DatabaseProvider(inMemory: true), nil)
    try withTagDatabase { path in
        let sqlite = try SQLiteRepositoryProvider(path: path)
        defer { sqlite.database.close() }
        try body(DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false), sqlite)
    }
}

@MainActor
private func withImportedTagProviders(_ body: (DatabaseProvider, SQLiteRepositoryProvider?) async throws -> Void) async throws {
    try await body(DatabaseProvider(inMemory: true), nil)
    try await withAsyncTagDatabase { _, path in
        let sqlite = try SQLiteRepositoryProvider(path: path)
        defer { sqlite.database.close() }
        try await body(DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false), sqlite)
    }
}

@MainActor
private func withTagDatabase(_ body: (String) throws -> Void) throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForgeTagTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try body(folder.appendingPathComponent("tags.sqlite").path)
}

@MainActor
private func withAsyncTagDatabase(_ body: (URL, String) async throws -> Void) async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForgeTagTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try await body(folder, folder.appendingPathComponent("tags.sqlite").path)
}
