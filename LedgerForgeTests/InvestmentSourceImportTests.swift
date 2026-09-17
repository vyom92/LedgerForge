import Foundation
import Testing
@testable import LedgerForge

/// Ordinary-path mechanics against unchanged originals. Independent financial
/// source qualification remains separate; parser output is not its own oracle.
@Suite(.serialized)
@MainActor
struct InvestmentSourceImportTests {
    private func originals() throws -> [URL] {
        guard let root = ProcessInfo.processInfo.environment["LEDGERFORGE_PRIVATE_ORIGINALS_DIRECTORY"] else {
            throw EnvironmentError.missingOriginals
        }
        let directory = URL(fileURLWithPath: root).appendingPathComponent("Investments")
        guard let enumerator = FileManager.default.enumerator(at: directory,
            includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { throw EnvironmentError.missingOriginals }
        let files = enumerator.compactMap { $0 as? URL }.filter { ["csv", "pdf"].contains($0.pathExtension.lowercased()) }
        guard !files.isEmpty else { throw EnvironmentError.missingOriginals }
        return files.sorted { $0.path < $1.path }
    }

    private enum EnvironmentError: Error { case missingOriginals, missingCurrentSources }

    private func currentSources() throws -> [URL] {
        let files = try originals().filter { source in
            // Older policy-only reports are regression evidence, not fund units.
            if source.deletingLastPathComponent().lastPathComponent == "ZurichISP" {
                guard source.pathExtension == "csv" else { return false }
                return try String(contentsOf: source, encoding: .utf8).contains("FundName2")
            }
            return ["IBKR", "IndianMutualFunds", "CBQPortfolio"].contains(source.deletingLastPathComponent().lastPathComponent)
        }
        guard !files.isEmpty else { throw EnvironmentError.missingCurrentSources }
        return files
    }

    private func engine(_ provider: DatabaseProvider, store: InvestmentStore = InvestmentStore()) -> ImportEngine {
        let hydrator = RepositoryStoreHydrator(accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo, cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo, fundingPlanRepo: provider.fundingPlanRepo, investmentRepo: provider.investmentRepo,
            accountStore: AccountStore(), transactionStore: TransactionStore(), categoryStore: CategoryStore(),
            cardStore: CardStore(), salaryStore: SalaryStore(), fundingPlanStore: FundingPlanStore(), investmentStore: store,
            importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
            persistenceState: provider.persistenceState, providerGeneration: provider.generationToken,
            participatesInLifecycleGate: false)
        return ImportEngine(importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
            persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {})
    }

    @Test func sameDateOriginalsRequireTheSameChoiceInEitherOrder() async throws {
        let sources = try currentSources().filter { $0.deletingLastPathComponent().lastPathComponent == "IBKR" }
        let csvs = sources.filter { $0.pathExtension == "csv" }
        guard csvs.count == 2 else { throw EnvironmentError.missingCurrentSources }
        for csv in csvs {
            let pdf = csv.deletingPathExtension().appendingPathExtension("pdf")
            guard sources.contains(pdf) else { throw EnvironmentError.missingCurrentSources }
            for order in [[csv, pdf], [pdf, csv]] {
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s96-order-\(UUID())")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
                defer { try? FileManager.default.removeItem(at: folder) }
                let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("holdings.sqlite").path)
                defer { sqlite.database.close() }
                for provider in [DatabaseProvider(inMemory: true), DatabaseProvider.verifiedSQLite(sqlite)] {
                    let importer = engine(provider)
                    let first = try await importer.prepareImport(from: order[0])
                    let firstResult = await importer.commitPreparedImport(first)
                    #expect(firstResult.succeeded)
                    let before = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
                    var second = try await importer.prepareImport(from: order[1])
                    guard let plan = second.investmentPlan, let review = second.investmentReview else {
                        throw EnvironmentError.missingCurrentSources
                    }
                    let held = second.investmentConfirmationBlocked && !review.sameDateConflictScopes.isEmpty
                    let rejected = provider.investmentRepo.commitCurrentHoldings(plan)
                    let unchanged = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == before
                    #expect(held && rejected == .rejected(.sameDateConflict) && unchanged)
                    var choices = plan.choices
                    choices.replaceSameDateScopes = Set(plan.evidence.scopes.map(\.key))
                    second.updateInvestmentChoices(choices)
                    let expected = second.investmentReview?.snapshot
                    let result = await importer.commitPreparedImport(second)
                    let chosen = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == expected
                    #expect(result.succeeded && chosen)
                }
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func populatedBackupRestoreAndStartupHydrationPreserveCurrentHoldings() async throws {
        let sources = try currentSources()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s96-recovery-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let current = folder.appendingPathComponent("holdings.sqlite")
        let sqlite = try SQLiteRepositoryProvider(path: current.path)
        defer { sqlite.database.close() }
        let runtime = DatabaseProvider.verifiedSQLite(sqlite)
        let importer = engine(runtime)
        // Choose the latest complete original per source scope; both same-date
        // representations remain covered by the separate order-reversal test.
        var selected: [String: (URL, String)] = [:]
        for source in sources where source.pathExtension == "csv" || source.deletingLastPathComponent().lastPathComponent != "IBKR" {
            let probe = engine(DatabaseProvider(inMemory: true))
            let prepared = try await probe.prepareImport(from: source)
            guard let evidence = prepared.investmentPlan?.evidence else { throw EnvironmentError.missingCurrentSources }
            let key = evidence.scopes.map(\.key).sorted().joined(separator: "\u{1E}")
            let date = evidence.scopes.map(\.holdingsDate).max()!
            if selected[key] == nil || selected[key]!.1 < date { selected[key] = (source, date) }
            probe.cancelPreparedImport(prepared)
        }
        for (source, _) in selected.values.sorted(by: { $0.0.path < $1.0.path }) {
            let prepared = try await importer.prepareImport(from: source)
            let result = await importer.commitPreparedImport(prepared)
            #expect(result.succeeded)
        }
        let expected = try runtime.investmentRepo.snapshot(workspaceID: "default-workspace")
        #expect(!expected.holdings.isEmpty && Set(expected.holdings.map(\.parserProfile)).count == 4)
        let saved = DatabaseProvider.shared
        DatabaseProvider.shared = runtime
        defer { DatabaseProvider.shared = saved }
        let coordinator = BackupRestoreCoordinator(testingAt: current)
        coordinator.installTestProvider(sqlite)
        defer { try? coordinator.closeTestProvider() }
        let destination = folder.appendingPathComponent("backups")
        try BackupFiles.createDirectory(destination)
        await coordinator.createBackup(to: destination)
        guard let package = coordinator.lastBackupURL else { throw EnvironmentError.missingCurrentSources }
        let manifest = try BackupFiles.verifyPackage(package)
        #expect(manifest.formatVersion == 1 && manifest.schemaVersion == 21)
        let originalPackageHash = try BackupFiles.hash(package.appendingPathComponent("ledger.sqlite")).sha256
        await coordinator.verifyRestore(from: package)
        #expect(coordinator.candidateManifest == manifest)
        await coordinator.replaceLedger()
        let restored = try DatabaseProvider.shared.investmentRepo.snapshot(workspaceID: "default-workspace") == expected
        #expect(restored && InvestmentStore.shared.snapshot == expected && coordinator.restoredReceipt?.phase == .activated)
        try coordinator.closeTestProvider()
        DatabaseProvider.shared.invalidateGeneration()
        DatabaseProvider.shared = .unavailable(reason: .notInitialized)

        // Exercise the actual startup recovery decision, a fresh connection,
        // complete staged hydration and publication before confirming relaunch.
        let startup = BackupRestoreCoordinator(testingAt: current)
        try startup.recoverBeforeStartup()
        let reopened = try SQLiteRepositoryProvider(path: current.path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        startup.installTestProvider(reopened)
        let reopenedRuntime = DatabaseProvider.verifiedSQLite(reopened)
        DatabaseProvider.shared = reopenedRuntime
        let hydrator = RepositoryStoreHydrator(databaseProvider: reopenedRuntime, participatesInLifecycleGate: false)
        let staged = try hydrator.stageHydration()
        #expect(staged.investments == expected)
        hydrator.publish(staged)
        await startup.startupDidHydrate()
        let reopenedExact = try reopened.investmentRepo.snapshot(workspaceID: "default-workspace") == expected
        let packageUnchanged = try BackupFiles.hash(package.appendingPathComponent("ledger.sqlite")).sha256 == originalPackageHash
        #expect(reopenedExact && InvestmentStore.shared.snapshot == expected && packageUnchanged)
        #expect(startup.restoredReceipt?.phase == .relaunchConfirmed && !DatabaseActivityGate.shared.hasExclusiveOperation)
        if let namespace = ProcessInfo.processInfo.environment["LEDGERFORGE_S96_RECOVERY_NAMESPACE"] {
            // Optional real-process continuation of this authentic recovery test.
            // It exports ordinary app data only into a fresh isolated namespace.
            guard namespace.hasPrefix("s93-recovery-s96-") else { throw EnvironmentError.missingCurrentSources }
            let identity = try DevelopmentDatabaseIdentity.applicationOwned(environment: [
                DevelopmentDatabaseIdentity.namespaceEnvironmentKey: namespace
            ])
            let target = identity.canonicalDevelopmentURL
            let parent = target.deletingLastPathComponent()
            guard identity.isIsolatedCanonicalNamespace, !FileManager.default.fileExists(atPath: parent.path) else {
                throw EnvironmentError.missingCurrentSources
            }
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            try reopened.database.createBackup(at: target.path)
            try BackupFiles.copyPackage(package, to: parent.appendingPathComponent("input.ledgerforgebackup"))
        }
        try startup.closeTestProvider()
    }

    @Test func currentLocalOriginalsPrepareAndCancelWithoutAcceptedResidue() async throws {
        let sources = try currentSources()
        for (index, source) in sources.enumerated() {
            let provider = DatabaseProvider(inMemory: true)
            let engine = engine(provider)
            do {
                let prepared = try await engine.prepareImport(from: source)
                let valid = prepared.validation.passed && prepared.investmentReview != nil
                    && !prepared.investmentConfirmationBlocked && prepared.financialDocument.transactions.isEmpty
                #expect(valid, "Current-source preparation failed at inventory index \(index).")
                engine.cancelPreparedImport(prepared)
                let unchanged = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == .empty
                let noAccounts = try provider.accountRepo.accounts(workspaceId: "default-workspace").isEmpty
                let noAttempts = try provider.importSessionRepo.importAttempts(workspaceId: "default-workspace").isEmpty
                #expect(unchanged && noAccounts && noAttempts)
            } catch {
                // Do not attach source values, raw errors, paths or parser output to result bundles.
                let reason = (error as? InvestmentError).map { String(describing: $0) } ?? ImportFailureSummary.from(error).family.rawValue
                Issue.record("Current-source preparation threw at inventory index \(index): \(reason).")
            }
        }
    }

    @Test func historicalPolicyOnlyOriginalsCannotCreateFundHoldings() async throws {
        let current = Set(try currentSources())
        let older = try originals().filter {
            $0.deletingLastPathComponent().lastPathComponent == "ZurichISP" && !current.contains($0)
        }
        guard older.count == 4 else { throw EnvironmentError.missingCurrentSources }
        let reader = DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry())
        for source in older {
            let result = try await reader.importDocument(ImportRequest(fileURL: source),
                snapshot: SourceContentSnapshot(bytes: Data(contentsOf: source)))
            guard let raw = result.rawDocument else { throw EnvironmentError.missingCurrentSources }
            #expect(!InvestmentStatementParser().canRecognize(raw))
        }
    }

    @Test func zurichPoliciesCommitReplayHydrateAndReopen() async throws {
        let sources = try currentSources().filter { $0.deletingLastPathComponent().lastPathComponent == "ZurichISP" }
        guard !sources.isEmpty else { throw EnvironmentError.missingCurrentSources }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s96-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("holdings.sqlite").path)
        defer { sqlite.database.close() }
        for provider in [DatabaseProvider(inMemory: true), DatabaseProvider.verifiedSQLite(sqlite)] {
            let store = InvestmentStore()
            let engine = engine(provider, store: store)
            for source in sources {
                let prepared = try await engine.prepareImport(from: source)
                guard let expected = prepared.investmentReview?.snapshot else {
                    Issue.record("Zurich closing preview unavailable."); engine.cancelPreparedImport(prepared); continue
                }
                let result = await engine.commitPreparedImport(prepared)
                #expect(result.succeeded)
                let exact = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == expected
                let hydrated = store.snapshot == expected
                let currentOnly = expected.holdings.allSatisfy { $0.units.value > 0 && $0.averageCost == nil && $0.totalCost == nil }
                #expect(exact && hydrated && currentOnly)
                let replay = try await engine.prepareImport(from: source)
                let replayResult = await engine.commitPreparedImport(replay)
                let unchanged = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == expected
                #expect(replayResult.previousImport != nil && !replayResult.persisted && unchanged)
            }
        }
        let before = try sqlite.investmentRepo.snapshot(workspaceID: "default-workspace")
        try sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("holdings.sqlite").path)
        defer { reopened.database.close() }
        let exact = try reopened.investmentRepo.snapshot(workspaceID: "default-workspace") == before
        #expect(exact)
        try BackupCompatibility.verifyDatabase(reopened.database)
    }

    @Test func authenticUpdatesCoupleUnitsAndCostAndHoldConflictsAndOlderSources() async throws {
        let sources = try currentSources()
        let csvs = sources.filter { $0.deletingLastPathComponent().lastPathComponent == "IBKR" && $0.pathExtension == "csv" }
        var dated: [(URL, String)] = []
        let inspection = engine(DatabaseProvider(inMemory: true))
        for source in csvs {
            let prepared = try await inspection.prepareImport(from: source)
            guard let date = prepared.investmentPlan?.evidence.scopes.first?.holdingsDate else {
                throw EnvironmentError.missingCurrentSources
            }
            dated.append((source, date)); inspection.cancelPreparedImport(prepared)
        }
        dated.sort { $0.1 < $1.1 }
        guard dated.count == 2, dated[0].1 < dated[1].1,
              let policy = sources.first(where: { $0.deletingLastPathComponent().lastPathComponent == "ZurichISP" }) else {
            throw EnvironmentError.missingCurrentSources
        }
        let olderPDF = dated[0].0.deletingPathExtension().appendingPathExtension("pdf")
        guard sources.contains(olderPDF) else { throw EnvironmentError.missingCurrentSources }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s96-updates-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("holdings.sqlite").path)
        defer { sqlite.database.close() }
        for provider in [DatabaseProvider(inMemory: true), DatabaseProvider.verifiedSQLite(sqlite)] {
            let store = InvestmentStore(), importer = engine(provider)
            for source in [policy, dated[0].0] {
                let prepared = try await importer.prepareImport(from: source)
                let result = await importer.commitPreparedImport(prepared)
                let succeeded = result.succeeded
                #expect(succeeded)
            }
            let beforeConflict = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
            var conflict = try await importer.prepareImport(from: olderPDF)
            let held = conflict.investmentConfirmationBlocked && !(conflict.investmentReview?.sameDateConflictScopes.isEmpty ?? true)
            #expect(held)
            guard let plan = conflict.investmentPlan else { throw EnvironmentError.missingCurrentSources }
            let rejected = provider.investmentRepo.commitCurrentHoldings(plan)
            let untouched = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == beforeConflict
            #expect(rejected == .rejected(.sameDateConflict) && untouched)
            var choices = plan.choices
            choices.replaceSameDateScopes = Set(plan.evidence.scopes.map(\.key))
            conflict.updateInvestmentChoices(choices)
            let explicitlyChosen = await importer.commitPreparedImport(conflict)
            let choiceCommitted = explicitlyChosen.succeeded
            #expect(choiceCommitted)

            let before = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
            let updater = engine(provider, store: store)
            let prepared = try await updater.prepareImport(from: dated[1].0)
            guard let expected = prepared.investmentReview?.snapshot else { throw EnvironmentError.missingCurrentSources }
            let simultaneousChange = expected.holdings.contains { after in
                before.holdings.contains { old in old.id == after.id && old.units != after.units && old.averageCost != after.averageCost }
            }
            #expect(simultaneousChange)
            let result = await updater.commitPreparedImport(prepared)
            let accepted = result.succeeded
            let exact = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == expected
            let policyIDs = Set(before.containers.filter { $0.identityKind == "policy" }.map(\.id))
            let unrelated = before.holdings.filter { policyIDs.contains($0.containerID) }
                == expected.holdings.filter { policyIDs.contains($0.containerID) }
            #expect(accepted && exact && store.snapshot == expected && unrelated)

            // A previously accepted original replays without changing the newer set.
            let oldReplay = try await updater.prepareImport(from: olderPDF)
            let replayResult = await updater.commitPreparedImport(oldReplay)
            let replayUnchanged = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == expected
            #expect(replayResult.previousImport != nil && replayUnchanged)
            // A fresh provider seeded only by July holds the older, unseen original.
            let fresh = DatabaseProvider(inMemory: true), freshEngine = engine(fresh)
            let newest = try await freshEngine.prepareImport(from: dated[1].0)
            let seed = await freshEngine.commitPreparedImport(newest)
            let seedSucceeded = seed.succeeded
            #expect(seedSucceeded)
            let older = try await freshEngine.prepareImport(from: olderPDF)
            let olderHeld = older.investmentConfirmationBlocked && older.investmentReview == nil
            #expect(olderHeld)
            freshEngine.cancelPreparedImport(older)
        }
    }

    @Test func failedAtomicPublicationAndStaleGenerationLeaveNoAcceptedHoldings() async throws {
        guard let source = try currentSources().first(where: { $0.deletingLastPathComponent().lastPathComponent == "ZurichISP" }) else {
            throw EnvironmentError.missingCurrentSources
        }
        let memory = InMemoryRepositoryProvider()
        let inMemory = DatabaseProvider(workspaceRepo: memory.workspaceRepo, transactionRepo: memory.transactionRepo,
            categoryRepo: memory.categoryRepo, accountRepo: memory.accountRepo, cardRepo: memory.cardRepo,
            importSessionRepo: memory.importSessionRepo, confirmedImportRepo: memory.confirmedImportRepo,
            salaryRepo: memory.salaryRepo, fundingPlanRepo: memory.fundingPlanRepo, investmentRepo: memory.investmentRepo,
            generationToken: memory.generationToken, persistenceState: .intentionalNonDurable(.testMemory), protectsGeneration: true)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s96-atomic-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("holdings.sqlite").path)
        defer { sqlite.database.close() }
        for (index, provider) in [inMemory, DatabaseProvider.verifiedSQLite(sqlite)].enumerated() {
            let importer = engine(provider)
            let prepared = try await importer.prepareImport(from: source)
            guard let plan = prepared.investmentPlan else { throw EnvironmentError.missingCurrentSources }
            if index == 0 { memory.injectInvestmentFailureBeforePublish(true) }
            else {
                try sqlite.database.execute(sql: "CREATE TEMP TRIGGER fail_investment_publication BEFORE INSERT ON investment_holdings BEGIN SELECT RAISE(ABORT,'injected publication boundary'); END;")
            }
            let failed = provider.investmentRepo.commitCurrentHoldings(plan)
            let empty = try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == .empty
            let noSession = try provider.importSessionRepo.importSession(id: plan.history.importSession.id) == nil
            let noDocument = try provider.importSessionRepo.importedDocument(id: plan.history.document.id) == nil
            #expect(failed == .repositoryIntegrityConflict && empty && noSession && noDocument)
            if index == 0 { memory.injectInvestmentFailureBeforePublish(false) }
            else { try sqlite.database.execute(sql: "DROP TRIGGER fail_investment_publication;") }
            provider.invalidateGeneration()
            let stale = provider.investmentRepo.commitCurrentHoldings(plan)
            #expect(stale == .staleProviderGeneration)
            importer.cancelPreparedImport(prepared)
            let rawRepository = index == 0 ? memory.investmentRepo : sqlite.investmentRepo
            let stillEmpty = try rawRepository.snapshot(workspaceID: "default-workspace") == .empty
            #expect(stillEmpty)
        }
    }
}
