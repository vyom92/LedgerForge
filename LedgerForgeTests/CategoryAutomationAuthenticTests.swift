import Foundation
import Testing
@testable import LedgerForge

/// Rules are owner metadata nominated outside Git; every financial operand is
/// the exact accepted populated ledger restored through the normal backup path.
@Suite(.serialized)
@MainActor
struct CategoryAutomationAuthenticTests {
    private struct OwnerSeed: Decodable {
        let categoryID: String
        let categoryName: String
        let rule: CategoryRule
        let expectedTransactionIDs: [String]
    }
    private let metadataTables: Set<String> = ["categories", "transaction_category_assignments", "category_rules", "transaction_category_intent", "category_import_work"]

    private func seeds() throws -> [OwnerSeed] {
        return try JSONDecoder().decode([OwnerSeed].self, from: AuthenticSourceTestSupport.ramNomination("LEDGERFORGE_S99_CATEGORY_OWNER_DATA"))
    }
    private func copy(legacy: Bool = false) throws -> (URL, SQLiteRepositoryProvider) {
        let path = try #require(ProcessInfo.processInfo.environment["LEDGERFORGE_S99_V26_BACKUP"])
        let package = URL(fileURLWithPath: path)
        let manifest = try BackupFiles.verifyPackage(package)
        #expect(manifest.schemaVersion == 26)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s99-category-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let destination = folder.appendingPathComponent("qualification.sqlite")
        if legacy {
            try FileManager.default.copyItem(at: package.appendingPathComponent("ledger.sqlite"), to: destination)
        } else { _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: destination) }
        return (folder, try SQLiteRepositoryProvider(path: destination.path, migrations: legacy ? Array(allMigrations.prefix(26)) : allMigrations, access: .existing))
    }
    private func install(_ seeds: [OwnerSeed], in repository: CategoryRepository) throws {
        let existing = Set(try repository.categories(workspaceId: seeds[0].rule.workspaceID).map(\.id))
        var created = existing
        for seed in seeds {
            if created.insert(seed.categoryID).inserted {
                let name = try CategoryName.validated(seed.categoryName)
                _ = try repository.createCategory(.init(id: seed.categoryID, workspaceId: seed.rule.workspaceID,
                    name: name.display, normalizedName: name.normalized, createdAtISO: "2026-09-21T00:00:00Z"))
            }
            try repository.saveRule(seed.rule, previousVersion: nil)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func approvedRulesMatchIndependentSelectedIDsAndRestoreExactIntentWithoutFinancialChanges() async throws {
        let seeds = try seeds()
        let workspace = try #require(seeds.first?.rule.workspaceID)
        let (folder, sqlite) = try copy()
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: folder) }
        let before = try NetWorthTestSupport.financialDigest(sqlite.database, excluding: metadataTables)
        let facts = try sqlite.transactionRepo.trustedTransactions(workspaceId: workspace)
        #expect(facts.count == 8036)
        #expect(try sqlite.categoryRepo.automationSnapshot(workspaceId: workspace)?.work.isEmpty == true)
        try install(seeds, in: sqlite.categoryRepo)
        let active = Set(seeds.map(\.categoryID))
        let preview = CategoryEvaluation.evaluate(inputs: facts.map(CategoryRuleInput.init),
            snapshot: try #require(try sqlite.categoryRepo.automationSnapshot(workspaceId: workspace)), assignments: [:], activeCategoryIDs: active)
        for seed in seeds {
            let matched = Set(preview.decisions.filter { $0.matches.contains { $0.ruleID == seed.rule.id } }.map(\.transactionID))
            #expect(matched == Set(seed.expectedTransactionIDs))
            #expect(preview.decisions.filter { matched.contains($0.transactionID) }.allSatisfy { $0.categoryID == seed.categoryID && $0.outcome == .assigned })
        }
        #expect(preview.decisions.allSatisfy { [.assigned, .noMatch].contains($0.outcome) })
        let clock = ContinuousClock(); let started = clock.now
        #expect(try sqlite.categoryRepo.applyCategoryEvaluation(preview, workspaceId: workspace, historical: true) == facts.count)
        print("S99_CATEGORY historical apply \(facts.count) source rows: \(started.duration(to: clock.now))")
        let clearedID = try #require(seeds.first?.expectedTransactionIDs.first)
        #expect(try sqlite.categoryRepo.setCategory(categoryId: nil, transactionId: clearedID, workspaceId: workspace))
        let manualID = try #require(seeds.first?.expectedTransactionIDs.dropFirst().first)
        #expect(try sqlite.categoryRepo.setCategory(categoryId: seeds[0].categoryID, transactionId: manualID, workspaceId: workspace))
        let saved = try #require(try sqlite.categoryRepo.automationSnapshot(workspaceId: workspace))
        #expect(saved.intents[clearedID]?.kind == .deliberatelyCleared)
        #expect(saved.intents[manualID]?.kind == .manual)
        #expect(saved.work.values.allSatisfy { $0.origin == .historical })
        #expect(saved.pendingIDs.isEmpty)
        #expect(try NetWorthTestSupport.financialDigest(sqlite.database, excluding: metadataTables) == before)
        let backupDirectory = folder.appendingPathComponent("backups")
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: false)
        let coordinator = BackupRestoreCoordinator(testingAt: folder.appendingPathComponent("qualification.sqlite"))
        DatabaseProvider.shared = .verifiedSQLite(sqlite)
        coordinator.installTestProvider(sqlite)
        await coordinator.createBackup(to: backupDirectory)
        let package = try #require(coordinator.lastBackupURL), manifest = try BackupFiles.verifyPackage(package)
        #expect(manifest.schemaVersion == BackupCompatibility.supportedSchemaVersion)
        let destination = folder.appendingPathComponent("restored.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: destination)
        let restored = try SQLiteRepositoryProvider(path: destination.path, migrations: allMigrations, access: .existing)
        #expect(try restored.categoryRepo.automationSnapshot(workspaceId: workspace) == saved)
        #expect(try restored.transactionRepo.trustedTransactions(workspaceId: workspace) == facts)
        #expect(try NetWorthTestSupport.financialDigest(restored.database, excluding: metadataTables) == before)
        try restored.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: destination.path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        #expect(try reopened.categoryRepo.automationSnapshot(workspaceId: workspace) == saved)
        let provider = DatabaseProvider.verifiedSQLite(reopened)
        let snapshot = try RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace, participatesInLifecycleGate: false).stageHydration()
        #expect(snapshot.categorySnapshot.automation == saved)
        try reopened.database.execute(sql: "ALTER TABLE transaction_category_intent RENAME TO s99_unavailable_intent;")
        #expect(throws: (any Error).self) { try reopened.categoryRepo.automationSnapshot(workspaceId: workspace) }
        try reopened.database.execute(sql: "ALTER TABLE s99_unavailable_intent RENAME TO transaction_category_intent;")
        provider.invalidateGeneration()
        #expect(throws: (any Error).self) { try provider.categoryRepo.automationSnapshot(workspaceId: workspace) }
    }

    @Test(.globalRuntimeStateIsolation)
    func newlyImportedPendingWorkSurvivesBackupAndReopenWithoutRepeatingImport() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s99-pending-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("original.sqlite")
        let sqlite = try SQLiteRepositoryProvider(path: path.path)
        defer { sqlite.database.close() }
        let plan = try await confirmedImportPlan(generationToken: sqlite.generationToken)
        guard case .committed = sqlite.confirmedImportRepo.commitConfirmedImport(plan) else {
            Issue.record("The authentic source must commit before category retry is exercised."); return
        }
        let workspace = plan.workspace.id
        let facts = try sqlite.transactionRepo.trustedTransactions(workspaceId: workspace)
        let pending = try #require(try sqlite.categoryRepo.automationSnapshot(workspaceId: workspace))
        #expect(pending.pendingIDs == Set(facts.map(\.id)))
        #expect(pending.work.values.allSatisfy { $0.origin == .newImport })
        let before = try NetWorthTestSupport.financialDigest(sqlite.database, excluding: metadataTables)
        let backups = folder.appendingPathComponent("backups")
        try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: false)
        DatabaseProvider.shared = .verifiedSQLite(sqlite)
        let coordinator = BackupRestoreCoordinator(testingAt: path)
        coordinator.installTestProvider(sqlite)
        await coordinator.createBackup(to: backups)
        let package = try #require(coordinator.lastBackupURL)
        let manifest = try BackupFiles.verifyPackage(package)
        let destination = folder.appendingPathComponent("restored.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: destination)
        let restored = try SQLiteRepositoryProvider(path: destination.path, migrations: allMigrations, access: .existing)
        #expect(try restored.categoryRepo.automationSnapshot(workspaceId: workspace) == pending)
        try restored.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: destination.path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        let recovered = try #require(try reopened.categoryRepo.automationSnapshot(workspaceId: workspace))
        let evaluation = CategoryEvaluation.evaluate(inputs: facts.map(CategoryRuleInput.init), snapshot: recovered, assignments: [:], activeCategoryIDs: [])
        #expect(try reopened.categoryRepo.applyCategoryEvaluation(evaluation, workspaceId: workspace, historical: false) == facts.count)
        #expect(try reopened.categoryRepo.applyCategoryEvaluation(evaluation, workspaceId: workspace, historical: false) == 0)
        #expect(try reopened.categoryRepo.automationSnapshot(workspaceId: workspace)?.pendingIDs.isEmpty == true)
        #expect(try reopened.transactionRepo.trustedTransactions(workspaceId: workspace) == facts)
        #expect(try NetWorthTestSupport.financialDigest(reopened.database, excluding: metadataTables) == before)
    }

    @Test(.globalRuntimeStateIsolation)
    func legacyAssignmentSurvivesMigrationAndIsNeverInferredToBeAutomatic() throws {
        let seed = try #require(try seeds().first)
        let (folder, old) = try copy(legacy: true)
        defer { old.database.close(); try? FileManager.default.removeItem(at: folder) }
        let workspace = seed.rule.workspaceID, id = try #require(seed.expectedTransactionIDs.first)
        let name = try CategoryName.validated(seed.categoryName)
        _ = try old.categoryRepo.createCategory(.init(id: seed.categoryID, workspaceId: workspace, name: name.display, normalizedName: name.normalized, createdAtISO: "2026-09-21T00:00:00Z"))
        _ = try old.categoryRepo.setCategory(categoryId: seed.categoryID, transactionId: id, workspaceId: workspace)
        #expect(try old.categoryRepo.automationSnapshot(workspaceId: workspace) == nil)
        try old.database.checkpointAndClose()
        let current = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("qualification.sqlite").path, migrations: allMigrations, access: .existing, migrateExisting: true)
        defer { current.database.close() }
        let initial = try #require(try current.categoryRepo.automationSnapshot(workspaceId: workspace))
        #expect(initial.rules.isEmpty && initial.intents.isEmpty && initial.work.isEmpty)
        try current.categoryRepo.saveRule(seed.rule, previousVersion: nil)
        let fact = try #require(try current.transactionRepo.trustedTransactions(workspaceId: workspace).first { $0.id == id })
        let preview = CategoryEvaluation.evaluate(inputs: [.init(transaction: fact)], snapshot: try #require(try current.categoryRepo.automationSnapshot(workspaceId: workspace)), assignments: [id: seed.categoryID], activeCategoryIDs: [seed.categoryID])
        #expect(preview.decisions.first?.outcome == .protected)
        #expect(try current.categoryRepo.applyCategoryEvaluation(preview, workspaceId: workspace, historical: true) == 1)
        #expect(try current.categoryRepo.automationSnapshot(workspaceId: workspace)?.intents[id] == nil)
        #expect(try current.categoryRepo.assignments(workspaceId: workspace).first?.categoryId == seed.categoryID)
    }
}
