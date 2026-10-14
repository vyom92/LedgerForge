import Foundation
import Combine
import Testing
@testable import LedgerForge

/// Source-independent metadata format checks only. Real matching, source
/// eligibility and treatment use the separate authentic RAM-fed campaign.
struct CategoryAutomationMetadataTests {
    private func rule() -> CategoryRule {
        .init(id: UUID().uuidString, workspaceID: UUID().uuidString, name: "Metadata format check", version: 1,
            isEnabled: true, categoryID: UUID().uuidString, accountID: nil, currency: nil, direction: nil,
            predicates: [.init(field: .narration, match: .contains, text: "Owner condition")])
    }

    @Test func earlierRulePayloadWithoutActionKeepsCategoryOnlyMeaning() throws {
        var original = rule()
        original.bankExpenseAction = .expense
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "bankExpenseAction")
        let decoded = try JSONDecoder().decode(CategoryRule.self, from: JSONSerialization.data(withJSONObject: json))
        var expected = original
        expected.bankExpenseAction = nil
        #expect(decoded == expected)
        try decoded.validate()
    }

    @Test func actionAndNarrationExclusionHaveExplicitRoundTripValues() throws {
        var original = rule()
        original.bankExpenseAction = .expense
        original.predicates.append(.init(field: .narration, match: .doesNotContain, text: "Owner exclusion"))
        try original.validate()
        let data = try JSONEncoder().encode(original)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["bankExpenseAction"] as? String == "expense")
        let predicates = try #require(json["predicates"] as? [[String: Any]])
        #expect(predicates.last?["match"] as? String == "doesNotContain")
        #expect(try JSONDecoder().decode(CategoryRule.self, from: data) == original)
    }

    @Test func unfamiliarActionOrPredicateCannotDecodeAsAnUnrestrictedRule() throws {
        let original = rule()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json["bankExpenseAction"] = "futureAction"
        let actionData = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(CategoryRule.self, from: actionData) }
        json.removeValue(forKey: "bankExpenseAction")
        var predicates = try #require(json["predicates"] as? [[String: Any]])
        predicates[0]["match"] = "futurePredicate"
        json["predicates"] = predicates
        let predicateData = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(CategoryRule.self, from: predicateData) }
    }

    @Test func exclusionsRequireNarrationAndAPositiveNonblankCondition() throws {
        var value = rule()
        value.predicates = [.init(field: .narration, match: .doesNotContain, text: "Owner exclusion")]
        #expect(throws: CategoryAutomationError.invalidRule) { try value.validate() }
        value.predicates.insert(.init(field: .narration, match: .contains, text: "Owner condition"), at: 0)
        try value.validate()
        value.predicates[1].field = .reference
        #expect(throws: CategoryAutomationError.invalidRule) { try value.validate() }
        value.predicates[1].field = .narration
        value.predicates[0].text = " \n\t"
        #expect(throws: CategoryAutomationError.invalidRule) { try value.validate() }
    }

    @Test func applyLookupRejectsChangedGlobalMetadataBeforeReadingAnyFinancialInput() throws {
        let original = rule()
        let active = Set([original.categoryID])
        let evaluated = CategoryEvaluation.evaluate(inputs: [], snapshot: .init(rules: [original]),
            assignments: [:], activeCategoryIDs: active)
        let unbound = CategoryEvaluation(rules: evaluated.rules, activeCategoryIDs: active, decisions: [])
        #expect(evaluated == unbound)
        for evaluation in [evaluated, unbound] {
            _ = try evaluation.validatedDecisionLookup(rules: [original], activeCategoryIDs: active)
            #expect(throws: CategoryAutomationError.stalePreview) {
                try evaluation.validatedDecisionLookup(rules: [original], activeCategoryIDs: [])
            }
            var changed = original
            changed.version += 1
            #expect(throws: CategoryAutomationError.stalePreview) {
                try evaluation.validatedDecisionLookup(rules: [changed], activeCategoryIDs: active)
            }
            changed = original
            changed.bankExpenseAction = .expense
            #expect(throws: CategoryAutomationError.stalePreview) {
                try evaluation.validatedDecisionLookup(rules: [changed], activeCategoryIDs: active)
            }
            changed = original
            changed.predicates.append(.init(field: .narration, match: .doesNotContain, text: "Owner exclusion"))
            #expect(throws: CategoryAutomationError.stalePreview) {
                try evaluation.validatedDecisionLookup(rules: [changed], activeCategoryIDs: active)
            }
        }
    }

    @Test func spendingProvenanceRejectsEmptyOrAmbiguousHistoryAndKeepsSuppressionDistinct() throws {
        let id = UUID().uuidString
        let automatic = TransactionSpendingIntent(kind: .automaticExpense, matches: [.init(ruleID: id, version: 3)])
        try automatic.validate()
        #expect(try JSONDecoder().decode(TransactionSpendingIntent.self, from: JSONEncoder().encode(automatic)) == automatic)
        #expect(throws: CategoryAutomationError.invalidState) {
            try TransactionSpendingIntent(kind: .automaticExpense, matches: []).validate()
        }
        #expect(throws: CategoryAutomationError.invalidState) {
            try TransactionSpendingIntent(kind: .automaticExpense,
                matches: [.init(ruleID: id, version: 2), .init(ruleID: id, version: 3)]).validate()
        }
        #expect(throws: CategoryAutomationError.invalidState) {
            try TransactionSpendingIntent(kind: .automaticExpense, matches: [.init(ruleID: id, version: 0)]).validate()
        }
        let suppression = TransactionSpendingIntent(kind: .deliberatelySuppressed, matches: [])
        try suppression.validate()
        #expect(try JSONDecoder().decode(TransactionSpendingIntent.self, from: JSONEncoder().encode(suppression)) == suppression)
        #expect(throws: CategoryAutomationError.invalidState) {
            try TransactionSpendingIntent(kind: .deliberatelySuppressed, matches: automatic.matches).validate()
        }
    }

    @Test func backupVerifierRunsOffMainActorForSupportedEmptySchemas() async throws {
        let checked = try await Task.detached {
            var checked = 0
            for version in [28, 33, 34] {
                let db = SQLiteDatabase(path: ":memory:")
                try db.open()
                defer { db.close() }
                try db.runMigrations(allMigrations.filter { $0.version <= version })
                try SQLiteCategoryRepo.verifyBackupContents(db, schemaVersion: version)
                checked += 1
            }
            return checked
        }.value
        #expect(checked == 3)
    }

    @Test(.globalRuntimeStateIsolation) @MainActor
    func hydrationReusesProviderMetadataAndKeepsFailureAndFallbackBoundaries() throws {
        let memory = InMemoryRepositoryProvider()
        let probe = HydrationMetadataReadProbe(memory)
        func makeProvider() -> DatabaseProvider {
            DatabaseProvider(workspaceRepo: memory.workspaceRepo, transactionRepo: memory.transactionRepo,
                categoryRepo: probe, accountRepo: memory.accountRepo, cardRepo: memory.cardRepo,
                importSessionRepo: memory.importSessionRepo, confirmedImportRepo: memory.confirmedImportRepo,
                salaryRepo: memory.salaryRepo, fundingPlanRepo: memory.fundingPlanRepo,
                investmentRepo: memory.investmentRepo, netWorthMembershipRepo: memory.netWorthMembershipRepo,
                intelligenceRepo: probe, tagRepo: memory.tagRepo,
                generationToken: memory.generationToken, protectsGeneration: true)
        }
        let provider = makeProvider()
        let accounts = AccountStore(), transactions = TransactionStore(), categories = CategoryStore()
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider,
            accountStore: accounts, transactionStore: transactions, categoryStore: categories,
            tagStore: TransactionTagStore(), importSessionStore: ImportSessionStore(),
            importAttemptStore: ImportAttemptStore(), categoryReconciliationGate: nil,
            participatesInLifecycleGate: false)
        let optimized = try hydrator.stageHydration()
        #expect(probe.intelligenceReads == 1)
        #expect(probe.capturedCategoryReads == 1)
        #expect(probe.ordinaryCategoryReads == 0)

        probe.resetCounts()
        let injected = RepositoryStoreHydrator(accountRepo: memory.accountRepo,
            importSessionRepo: memory.importSessionRepo, transactionRepo: memory.transactionRepo,
            categoryRepo: probe, cardRepo: memory.cardRepo, salaryRepo: memory.salaryRepo,
            fundingPlanRepo: memory.fundingPlanRepo, investmentRepo: memory.investmentRepo,
            netWorthMembershipRepo: memory.netWorthMembershipRepo, intelligenceRepo: probe,
            tagRepo: memory.tagRepo, accountStore: accounts, transactionStore: transactions,
            categoryStore: categories, providerGeneration: provider.generationToken,
            participatesInLifecycleGate: false)
        let ordinary = try injected.stageHydration()
        #expect(probe.intelligenceReads == 1)
        #expect(probe.capturedCategoryReads == 0)
        #expect(probe.ordinaryCategoryReads == 1)
        #expect(optimized.categorySnapshot == ordinary.categorySnapshot)
        #expect(optimized.intelligence == ordinary.intelligence)

        probe.resetCounts()
        probe.exposesIntelligence = false
        let historical = try hydrator.stageHydration()
        #expect(historical.intelligence == nil)
        #expect(historical.categorySnapshot == ordinary.categorySnapshot)
        #expect(probe.intelligenceReads == 1)
        #expect(probe.capturedCategoryReads == 0)
        #expect(probe.ordinaryCategoryReads == 1)

        probe.resetCounts()
        probe.exposesIntelligence = true
        probe.failIntelligence = true
        #expect(throws: HydrationMetadataReadProbe.Failure.self) { try hydrator.stageHydration() }
        #expect(probe.intelligenceReads == 1)
        #expect(probe.capturedCategoryReads == 0)
        #expect(probe.ordinaryCategoryReads == 0)
        #expect(accounts.accounts.isEmpty)
        #expect(transactions.transactions.isEmpty)
        #expect(categories.snapshot == .empty)

        probe.failIntelligence = false
        let otherProviderWithSameGeneration = makeProvider()
        try provider.withConsistentSnapshot {
            let inputs = try CategoryAutomationHydrationInputs.capture(from: provider, workspaceID: "default-workspace")
            #expect(throws: RepositoryError.self) {
                try otherProviderWithSameGeneration.categoryAutomationSnapshot(workspaceID: "default-workspace", hydrationInputs: inputs)
            }
            #expect(throws: RepositoryError.self) {
                try provider.categoryAutomationSnapshot(workspaceID: "another-workspace", hydrationInputs: inputs)
            }
            provider.invalidateGeneration()
            #expect(throws: RepositoryError.self) {
                try provider.categoryAutomationSnapshot(workspaceID: "default-workspace", hydrationInputs: inputs)
            }
        }
    }


    @Test(.globalRuntimeStateIsolation) @MainActor
    func copiedCategoryMetadataRequiresExactRuntimeCutAndCurrentReadCounter() async throws {
        let sqlite = try SQLiteRepositoryProvider(path: ":memory:")
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        let workspace = UUID().uuidString, timestamp = "2026-10-07T00:00:00Z"
        let originalWorkspace = WorkspaceDTO(id: workspace, name: "Metadata witness", createdAtISO: timestamp)
        _ = try provider.workspaceRepo.upsertWorkspace(originalWorkspace)
        let category = try provider.categoryRepo.createCategory(.init(workspaceId: workspace,
            name: "Metadata choice", normalizedName: "metadata choice", createdAtISO: timestamp))
        let store = CategoryStore(), transactions = TransactionStore(), gate = CategoryReconciliationGate()
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, transactionStore: transactions,
            categoryStore: store, workspaceId: workspace, categoryReconciliationGate: gate, participatesInLifecycleGate: false)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        let firstWitness = try #require(store.sourceWitness)
        #expect(!firstWitness.isCompact)
        let firstRevision = store.revision
        let intelligenceRevision = FinancialIntelligenceStore.shared.revision
        var financialNotifications = 0, categoryNotifications = 0
        let financialSubscription = transactions.$transactions.dropFirst().sink { _ in financialNotifications += 1 }
        let categorySubscription = store.$snapshot.dropFirst().sink { _ in categoryNotifications += 1 }
        defer { financialSubscription.cancel(); categorySubscription.cancel() }
        let otherGeneration = ProviderGenerationToken()
        gate.requireReconciliation(for: otherGeneration)
        // Unrelated legitimate metadata before the new read is not its source basis.
        let tag = TransactionTagDefinition(id: UUID().uuidString, workspaceID: workspace, name: "Before capture")
        _ = try provider.tagRepo.saveTag(tag, replacing: nil)
        #expect(try await hydrator.refreshCategoryOverrideIfCurrent())
        #expect(store.sourceWitness?.isCompact == true && store.sourceWitness == firstWitness)
        #expect(store.revision != firstRevision)
        #expect(try store.snapshot == hydrator.stageHydration().categorySnapshot)
        #expect(categoryNotifications == 1 && financialNotifications == 0)
        #expect(FinancialIntelligenceStore.shared.revision == intelligenceRevision)
        #expect(gate.isBlocked(for: otherGeneration))

        let request = try #require(provider.categoryOverrideReadRequest(workspaceID: workspace))
        let witness = try #require(store.sourceWitness), revision = store.revision, previous = store.snapshot
        let prepared = try await Task.detached { try await request.prepare(expected: witness) }.value
        let renamedTag = TransactionTagDefinition(id: tag.id, workspaceID: workspace, name: "After capture")
        _ = try provider.tagRepo.saveTag(renamedTag, replacing: tag)
        #expect(throws: CategoryAutomationError.stalePreview) {
            try hydrator.installCategoryOverride(prepared, expected: witness, revision: revision)
        }
        #expect(store.snapshot == previous && store.revision == revision && store.sourceWitness == witness)
        #expect(categoryNotifications == 1 && financialNotifications == 0)

        // A definition or rule write before capture still requires full
        // hydration, because its other consumers depend on that publication.
        _ = try provider.categoryRepo.renameCategory(id: category.id, workspaceId: workspace,
            name: "Changed definition before capture", updatedAtISO: timestamp)
        let definitionChange = try await Task.detached { try await request.prepare(expected: witness) }.value
        #expect(throws: CategoryAutomationError.stalePreview) {
            try hydrator.installCategoryOverride(definitionChange, expected: witness, revision: revision)
        }
        _ = try provider.categoryRepo.renameCategory(id: category.id, workspaceId: workspace,
            name: category.name, updatedAtISO: timestamp)
        let changedRule = CategoryRule(id: UUID().uuidString, workspaceID: workspace, name: "Metadata freshness rule",
            version: 1, isEnabled: false, categoryID: category.id, accountID: nil, currency: nil, direction: nil,
            predicates: [.init(field: .narration, match: .contains, text: "Owner condition")])
        try provider.categoryRepo.saveRule(changedRule, previousVersion: nil)
        let ruleChange = try await Task.detached { try await request.prepare(expected: witness) }.value
        #expect(throws: CategoryAutomationError.stalePreview) {
            try hydrator.installCategoryOverride(ruleChange, expected: witness, revision: revision)
        }
        #expect(store.snapshot == previous && store.revision == revision && categoryNotifications == 1)
        try provider.categoryRepo.deleteRule(id: changedRule.id, workspaceId: workspace, version: changedRule.version)

        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "New retained workspace metadata", createdAtISO: timestamp))
        await #expect(throws: CategoryAutomationError.stalePreview) {
            try await Task.detached { try await request.prepare(expected: witness) }.value
        }
        #expect(store.snapshot == previous && store.revision == revision)
        _ = try provider.workspaceRepo.upsertWorkspace(originalWorkspace)
        let sameGenerationOtherProvider = DatabaseProvider.verifiedSQLite(sqlite)
        let otherRequest = try #require(sameGenerationOtherProvider.categoryOverrideReadRequest(workspaceID: workspace))
        await #expect(throws: CategoryAutomationError.stalePreview) {
            try await Task.detached { try await otherRequest.prepare(expected: witness) }.value
        }
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        #expect(store.sourceWitness != witness && store.sourceWitness?.isCompact == false)
        #expect(throws: CategoryAutomationError.stalePreview) {
            try hydrator.installCategoryOverride(prepared, expected: witness, revision: revision)
        }
        provider.invalidateGeneration()
        await #expect(throws: RepositoryError.self) {
            try await Task.detached { try await request.prepare(expected: witness) }.value
        }
    }

    /// Pure SQLite storage mechanics only, with no statement/domain/Money input.
    @Test func sourceWitnessFramesNullTypesCompleteBytesOrderAndMultiplicity() async throws {
        let passed = try await Task.detached {
            let db = SQLiteDatabase(path: ":memory:"); try db.open(); defer { db.close() }
            let values = ["NULL", "CAST('' AS TEXT)", "X''", "1", "1.0", "'1'", "X'31'",
                          "CAST(X'610062' AS TEXT)", "CAST(X'610063' AS TEXT)"]
            let rows = try values.map { value in
                try db.query(sql: "SELECT typeof(value),CASE WHEN typeof(value)='real' THEN CAST(printf('%!.26g',value) AS BLOB) ELSE CAST(value AS BLOB) END FROM (SELECT \(value) AS value);") { $0 }[0]
            }
            func digest(_ rows: [SQLiteRow]) throws -> Data {
                try CategorySourceRows(schema: [], tables: [.init(name: "storage_mechanics", columns: ["value"], rows: rows)]).fingerprint()
            }
            return try Set(rows.map { try digest([$0]) }).count == values.count &&
                digest([rows[0], rows[1]]) == digest([rows[1], rows[0]]) &&
                digest([rows[0]]) != digest([rows[0], rows[0]])
        }.value
        #expect(passed)
    }

    @Test(.globalRuntimeStateIsolation) @MainActor
    func ownedSourceCutAllowsAnotherWriterBeforeOffActorHashing() async throws {
        let sqlite = try SQLiteRepositoryProvider(path: ":memory:")
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite), workspace = UUID().uuidString
        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Before copied read", createdAtISO: "2026-10-07T00:00:00Z"))
        let request = try #require(provider.categoryOverrideReadRequest(workspaceID: workspace))
        let baselineRows = try #require(try request.sourceRows())
        let baseline = try baselineRows.fingerprint(), pause = CategoryWitnessHashPause()
        let worker = Task.detached {
            guard let rows = try request.sourceRows() else { throw CategoryAutomationError.unavailable }
            await pause.afterCapture()
            return try rows.fingerprint()
        }
        defer { worker.cancel(); Task { await pause.release() } }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !(await pause.hasCaptured) && ContinuousClock.now < deadline { await Task.yield() }
        let captured = await pause.hasCaptured
        try #require(captured)
        let database = sqlite.database
        try await Task.detached {
            try database.executePrepared(sql: "UPDATE workspaces SET name=? WHERE id=?;", params: ["After copied read", workspace])
        }.value
        await pause.release()
        #expect(try await worker.value == baseline)
        let currentRows = try #require(try request.sourceRows())
        #expect(try currentRows.fingerprint() != baseline)
        try sqlite.database.execute(sql: "CREATE TABLE unexpected_metadata_table(value TEXT);")
        if let _ = try request.sourceRows() { Issue.record("Unexpected schema must not mint a category source witness") }
    }

#if DEBUG
    @Test(.globalRuntimeStateIsolation) @MainActor
    func segmentedCategoryCapturePreservesParityAndRejectsInterference() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
            "LedgerForgeCategoryCaptureTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("capture.sqlite").path)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite), workspace = UUID().uuidString
        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Capture slices", createdAtISO: "2026-10-07T00:00:00Z"))
        let store = CategoryStore(), gate = CategoryReconciliationGate()
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, categoryStore: store,
            workspaceId: workspace, categoryReconciliationGate: gate, participatesInLifecycleGate: false)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        let witness = try #require(store.sourceWitness), canonical = store.snapshot, revision = store.revision
        let request = try #require(provider.categoryOverrideReadRequest(workspaceID: workspace))
        let database = sqlite.database
        let ordinary = try hydrator.stageHydration().categorySnapshot
        let prepared = try await Task.detached { try await request.prepare(expected: witness) }.value
        #expect(prepared.snapshot == ordinary)

        // A second operation acquires generation, ledger AND connection while
        // capture is paused between slices. The timeout releases the first task
        // even if a regression retained one of those locks, so failure is bounded.
        let pause = CategoryWitnessHashPause()
        let capture = Task.detached {
            try await request.prepare(expected: witness, betweenCaptureSlices: { index in
                if index == 1 { await pause.afterCapture() }
            })
        }
        defer { capture.cancel(); Task { await pause.release() } }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !(await pause.hasCaptured) && ContinuousClock.now < deadline { await Task.yield() }
        let reachedSlice = await pause.hasCaptured
        try #require(reachedSlice)
        let releaseOnTimeout = Task.detached {
            try await Task.sleep(for: .seconds(2))
            await pause.release()
        }
        defer { releaseOnTimeout.cancel() }
        _ = try await Task.detached {
            try request.validity.withValidOperation {
                try database.withExclusiveAccess { try database.totalChangeCounter() }
            }
        }.value
        let releasedBeforeOtherRead = await pause.isReleased
        #expect(!releasedBeforeOtherRead)
        releaseOnTimeout.cancel()
        await pause.release()
        #expect(try await capture.value.snapshot == ordinary)

        await #expect(throws: CategoryAutomationError.stalePreview) {
            try await Task.detached {
                try await request.prepare(expected: witness, betweenCaptureSlices: { index in
                    if index == 1 {
                        try database.executePrepared(sql: "UPDATE workspaces SET name=? WHERE id=?;", params: ["Changed between slices", workspace])
                    }
                })
            }.value
        }
        try database.executePrepared(sql: "UPDATE workspaces SET name=? WHERE id=?;", params: ["Capture slices", workspace])
        let beforeDDL = try database.totalChangeCounter()
        await #expect(throws: CategoryAutomationError.stalePreview) {
            try await Task.detached {
                try await request.prepare(expected: witness, betweenCaptureSlices: { index in
                    if index == 1 { try database.execute(sql: "CREATE INDEX category_capture_schema_control ON categories(name);") }
                })
            }.value
        }
        #expect(try database.totalChangeCounter() == beforeDDL)
        try database.execute(sql: "DROP INDEX category_capture_schema_control;")
        let afterDDL = try await Task.detached { try await request.prepare(expected: witness) }.value
        #expect(afterDDL.snapshot == ordinary)

        let cancelled = Task.detached {
            try await request.prepare(expected: witness, betweenCaptureSlices: { index in
                if index == 1 { withUnsafeCurrentTask { $0?.cancel() } }
            })
        }
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        do {
            _ = try await Task.detached {
                try await request.prepare(expected: witness, betweenCaptureSlices: { index in
                    if index == 1 { request.validity.invalidate() }
                })
            }.value
            Issue.record("An invalidated generation must reject the remaining capture slices.")
        } catch RepositoryError.staleProviderGeneration { }
        #expect(store.snapshot == canonical && store.revision == revision && store.sourceWitness == witness)
    }
#endif

    @Test(.globalRuntimeStateIsolation) @MainActor
    func asyncApplyPreparedCutRejectsMetadataSchemaAndGenerationChanges() async throws {
        let sqlite = try SQLiteRepositoryProvider(path: ":memory:")
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite), workspace = UUID().uuidString
        let timestamp = "2026-10-07T00:00:00Z"
        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Apply cut", createdAtISO: timestamp))
        let category = try provider.categoryRepo.createCategory(.init(workspaceId: workspace,
            name: "Owner metadata", normalizedName: "owner metadata", createdAtISO: timestamp))
        let store = CategoryStore(), gate = CategoryReconciliationGate()
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, categoryStore: store,
            workspaceId: workspace, categoryReconciliationGate: gate, participatesInLifecycleGate: false)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        let witness = try #require(store.sourceWitness), canonical = store.snapshot, revision = store.revision
        let metadata = try #require(canonical.automation)
        let request = try #require(provider.categoryApplyWriteRequest(workspaceID: workspace))
        let prepared = try await Task.detached { try await request.read.prepare(expected: witness) }.value
        let evaluation = CategoryEvaluation.evaluate(inputs: [], snapshot: metadata, assignments: canonical.assignments,
            activeCategoryIDs: Set(canonical.activeCategories.map(\.id)))
        let database = sqlite.database, before = try database.totalChangeCounter()
        let unchanged = try await Task.detached {
            try request.apply(evaluation, historical: true, prepared: prepared, expected: witness, canonical: canonical)
        }.value
        let afterUnchanged = try database.totalChangeCounter()
        #expect(unchanged == 0 && afterUnchanged == before)

        let cancelled = Task.detached {
            withUnsafeCurrentTask { $0?.cancel() }
            return try request.apply(evaluation, historical: true, prepared: prepared, expected: witness, canonical: canonical)
        }
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(try database.totalChangeCounter() == before)

        let sameGenerationOtherProvider = DatabaseProvider.verifiedSQLite(sqlite)
        let other = try #require(sameGenerationOtherProvider.categoryApplyWriteRequest(workspaceID: workspace))
        await #expect(throws: CategoryAutomationError.stalePreview) {
            try await Task.detached {
                try other.apply(evaluation, historical: true, prepared: prepared, expected: witness, canonical: canonical)
            }.value
        }
        let tag = TransactionTagDefinition(id: UUID().uuidString, workspaceID: workspace, name: "Intervening owner metadata")
        _ = try provider.tagRepo.saveTag(tag, replacing: nil)
        let afterTag = try database.totalChangeCounter()
        await #expect(throws: CategoryAutomationError.stalePreview) {
            try await Task.detached {
                try request.apply(evaluation, historical: true, prepared: prepared, expected: witness, canonical: canonical)
            }.value
        }
        #expect(try database.totalChangeCounter() == afterTag)

        let beforeSchema = try await Task.detached { try await request.read.prepare(expected: witness) }.value
        try database.execute(sql: "CREATE INDEX category_apply_schema_control ON categories(name);")
        #expect(try database.totalChangeCounter() == afterTag)
        await #expect(throws: CategoryAutomationError.stalePreview) {
            try await Task.detached {
                try request.apply(evaluation, historical: true, prepared: beforeSchema, expected: witness, canonical: canonical)
            }.value
        }
        #expect(throws: CategoryAutomationError.stalePreview) {
            try hydrator.installCategoryOverride(beforeSchema, expected: witness, revision: revision)
        }
        try database.execute(sql: "DROP INDEX category_apply_schema_control;")
        #expect(try database.totalChangeCounter() == afterTag)

        _ = try provider.categoryRepo.renameCategory(id: category.id, workspaceId: workspace,
            name: "New definition before capture", updatedAtISO: timestamp)
        let renamed = try await Task.detached { try await request.read.prepare(expected: witness) }.value
        await #expect(throws: CategoryAutomationError.stalePreview) {
            try await Task.detached {
                try request.apply(evaluation, historical: true, prepared: renamed, expected: witness, canonical: canonical)
            }.value
        }
        _ = try provider.categoryRepo.renameCategory(id: category.id, workspaceId: workspace, name: category.name, updatedAtISO: timestamp)
        let rule = CategoryRule(id: UUID().uuidString, workspaceID: workspace, name: "New rule before capture", version: 1,
            isEnabled: false, categoryID: category.id, accountID: nil, currency: nil, direction: nil,
            predicates: [.init(field: .narration, match: .contains, text: "Owner condition")])
        try provider.categoryRepo.saveRule(rule, previousVersion: nil)
        let changedRule = try await Task.detached { try await request.read.prepare(expected: witness) }.value
        let currentEvaluation = CategoryEvaluation.evaluate(inputs: [], snapshot: try #require(changedRule.snapshot.automation),
            assignments: canonical.assignments, activeCategoryIDs: Set(canonical.activeCategories.map(\.id)))
        await #expect(throws: CategoryAutomationError.stalePreview) {
            try await Task.detached {
                try request.apply(currentEvaluation, historical: true, prepared: changedRule, expected: witness, canonical: canonical)
            }.value
        }
        try provider.categoryRepo.deleteRule(id: rule.id, workspaceId: workspace, version: rule.version)
        let current = try await Task.detached { try await request.read.prepare(expected: witness) }.value
        provider.invalidateGeneration()
        do {
            _ = try await Task.detached {
                try request.apply(evaluation, historical: true, prepared: current, expected: witness, canonical: canonical)
            }.value
            Issue.record("An invalidated generation must reject the prepared Apply request.")
        } catch RepositoryError.staleProviderGeneration { }
        #expect(store.snapshot == canonical && store.revision == revision && store.sourceWitness == witness)
    }

    @Test func backupVerifierValidatesRuleOnlyMetadataAndItsSchemaFence() throws {
        for version in [28, 34] {
            let db = SQLiteDatabase(path: ":memory:")
            try db.open()
            defer { db.close() }
            try db.runMigrations(allMigrations.filter { $0.version <= version })
            let original = rule()
            let timestamp = ISO8601DateFormatter().string(from: Date())
            try db.executePrepared(sql: "INSERT INTO workspaces(id,name,created_at) VALUES(?,?,?);",
                params: [original.workspaceID, "Metadata format check", timestamp])
            try db.executePrepared(sql: "INSERT INTO categories(id,workspace_id,name,normalized_name,created_at) VALUES(?,?,?,?,?);",
                params: [original.categoryID, original.workspaceID, "Metadata format check", "metadata format check", timestamp])
            func save(_ value: CategoryRule) throws {
                try db.executePrepared(sql: "INSERT INTO category_rules(id,workspace_id,category_id,version,rule_json) VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET rule_json=excluded.rule_json;",
                    params: [original.id, original.workspaceID, original.categoryID, original.version,
                        String(decoding: try JSONEncoder().encode(value), as: UTF8.self)])
            }
            try save(original)
            try SQLiteCategoryRepo.verifyBackupContents(db, schemaVersion: version)
            var value = original
            value.bankExpenseAction = .expense
            try save(value)
            if version < 34 {
                #expect(throws: CategoryAutomationError.unavailable) { try SQLiteCategoryRepo.verifyBackupContents(db, schemaVersion: version) }
            } else {
                try SQLiteCategoryRepo.verifyBackupContents(db, schemaVersion: version)
            }
            value = original
            value.predicates.append(.init(field: .narration, match: .doesNotContain, text: "Owner exclusion"))
            try save(value)
            if version < 34 {
                #expect(throws: CategoryAutomationError.unavailable) { try SQLiteCategoryRepo.verifyBackupContents(db, schemaVersion: version) }
            } else {
                try SQLiteCategoryRepo.verifyBackupContents(db, schemaVersion: version)
            }
            value = original
            value.workspaceID = UUID().uuidString
            try save(value)
            #expect(throws: CategoryAutomationError.invalidState) { try SQLiteCategoryRepo.verifyBackupContents(db, schemaVersion: version) }
            var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
            json["bankExpenseAction"] = "futureAction"
            try db.executePrepared(sql: "UPDATE category_rules SET rule_json=? WHERE id=?;",
                params: [String(decoding: try JSONSerialization.data(withJSONObject: json), as: UTF8.self), original.id])
            #expect(throws: DecodingError.self) { try SQLiteCategoryRepo.verifyBackupContents(db, schemaVersion: version) }
        }
    }
}

/// Delegates to empty real repositories. It creates no statement, financial
/// record, or replacement financial DTO; only read routing is observed.
@MainActor private final class HydrationMetadataReadProbe: CategoryRepository, FinancialIntelligenceRepository {
    enum Failure: Error { case intelligenceRead }
    private let base: InMemoryRepositoryProvider
    var intelligenceReads = 0, ordinaryCategoryReads = 0, capturedCategoryReads = 0
    var failIntelligence = false, exposesIntelligence = true
    init(_ base: InMemoryRepositoryProvider) { self.base = base }
    func resetCounts() { intelligenceReads = 0; ordinaryCategoryReads = 0; capturedCategoryReads = 0 }
    func snapshot(workspaceID: String) throws -> FinancialIntelligenceSnapshot? {
        intelligenceReads += 1
        if failIntelligence { throw Failure.intelligenceRead }
        guard exposesIntelligence else { return nil }
        return try base.intelligenceRepo.snapshot(workspaceID: workspaceID)
    }
    func automationSnapshot(workspaceId: String) throws -> CategoryAutomationSnapshot? {
        ordinaryCategoryReads += 1
        return try base.categoryRepo.automationSnapshot(workspaceId: workspaceId)
    }
    func automationSnapshot(workspaceId: String, hydrationInputs: CategoryAutomationHydrationInputs) throws -> CategoryAutomationSnapshot? {
        capturedCategoryReads += 1
        return try base.categoryRepo.automationSnapshot(workspaceId: workspaceId, hydrationInputs: hydrationInputs)
    }
    func saveMovement(_ event: MovementEvent, replacing expected: MovementEvent?) throws { try base.intelligenceRepo.saveMovement(event, replacing: expected) }
    func removeMovement(_ event: MovementEvent) throws { try base.intelligenceRepo.removeMovement(event) }
    func applyPlanning(_ edit: PlanningMetadataEdit) throws { try base.intelligenceRepo.applyPlanning(edit) }
    func categories(workspaceId: String) throws -> [CategoryDTO] { try base.categoryRepo.categories(workspaceId: workspaceId) }
    func assignments(workspaceId: String) throws -> [TransactionCategoryAssignmentDTO] { try base.categoryRepo.assignments(workspaceId: workspaceId) }
    func createCategory(_ category: CategoryDTO) throws -> CategoryDTO { try base.categoryRepo.createCategory(category) }
    func renameCategory(id: String, workspaceId: String, name: String, updatedAtISO: String) throws -> Bool { try base.categoryRepo.renameCategory(id: id, workspaceId: workspaceId, name: name, updatedAtISO: updatedAtISO) }
    func setCategoryArchived(id: String, workspaceId: String, isArchived: Bool, updatedAtISO: String) throws -> Bool { try base.categoryRepo.setCategoryArchived(id: id, workspaceId: workspaceId, isArchived: isArchived, updatedAtISO: updatedAtISO) }
    func deleteUnusedCategory(id: String, workspaceId: String) throws { try base.categoryRepo.deleteUnusedCategory(id: id, workspaceId: workspaceId) }
    func setCategory(categoryId: String?, transactionId: String, workspaceId: String) throws -> Bool { try base.categoryRepo.setCategory(categoryId: categoryId, transactionId: transactionId, workspaceId: workspaceId) }
}

private actor CategoryWitnessHashPause {
    private(set) var hasCaptured = false
    private var released = false
    var isReleased: Bool { released }
    private var continuation: CheckedContinuation<Void, Never>?
    func afterCapture() async {
        hasCaptured = true
        guard !released else { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func release() {
        released = true; continuation?.resume(); continuation = nil
    }
}
