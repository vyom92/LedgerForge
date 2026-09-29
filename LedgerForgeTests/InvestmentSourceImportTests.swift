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

    /// Explicit, one-time continuation of the owner-selected clean candidate.
    /// This uses the ordinary import path; independent original comparisons are
    /// performed separately in memory against the resulting candidate.
    @Test(.globalRuntimeStateIsolation)
    func populateFinalAdoptionCandidateFromSelectedInvestmentOriginals() async throws {
        let environment = ProcessInfo.processInfo.environment
        let directory = URL(fileURLWithPath: "/Users/vyom/Library/Containers/com.vyom.LedgerForge/Data/Library/Application Support/LedgerForge/Development/Namespaces/s98-adoption-candidate-01a0b713", isDirectory: true)
        let path = directory.appendingPathComponent("ledgerforge-development.sqlite").path
        guard environment["LEDGERFORGE_S98_ADOPTION_CANDIDATE"] == "1",
              environment["LEDGERFORGE_S98_ADOPTION_CANDIDATE_DIRECTORY"] == directory.path,
              FileManager.default.fileExists(atPath: path) else { throw EnvironmentError.missingCurrentSources }
        let originalsRoot = URL(fileURLWithPath: "/Users/vyom/Documents/Ledger Forge/Originals/Investments", isDirectory: true)
        let selected = [
            ("IBKR/IBKR_2.csv", "de800cb13b22a9e3827b0006ca21ff63b34457f79f8f20363911f1939dbcd46a"),
            ("IBKR/IBKR_1.csv", "587d64b73fdf8269b29a664c1100838d575487bf1a5408bc5ca087c17df2df84"),
            ("ZurichISP/Detail_by_txn_v1_-_since_2020.csv", "48c94d7e042abdf131ec97c2703b9b10fd5174f18c41874db1e8c6aff8faec63"),
            ("ZurichISP/Detail_by_txn_v1_-_since_2020(2).csv", "9a4a7687b90f0e68db382635a9471718360bc9a3cfbbb72566fb82c3cc8c1c03"),
            ("ZurichISP/Detail_by_txn_v1_-_since_2020(3).csv", "57debd801facc84fb17fae5ea9c1ba1bfd43938de50d902e3370e5698fe67a68")
        ]
        for (name, sha) in selected {
            guard try BackupFiles.hash(originalsRoot.appendingPathComponent(name)).sha256 == sha else {
                throw EnvironmentError.missingCurrentSources
            }
        }
        let sqlite = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing)
        defer { sqlite.database.close() }
        try BackupCompatibility.verifyDatabase(sqlite.database)
        guard try sqlite.database.queryInt("SELECT COUNT(*) FROM import_sessions;") == 333 else {
            throw EnvironmentError.missingCurrentSources
        }
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        let before = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
        guard before.containers.allSatisfy({ !["Interactive Brokers", "Zurich ISP"].contains($0.institution) }) else {
            throw EnvironmentError.missingCurrentSources
        }
        let accounts = try provider.accountRepo.accounts(workspaceId: "default-workspace")
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace")
        let cards = try provider.cardRepo.snapshot(workspaceId: "default-workspace")
        let sections = try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace")
        let inboxAccounts = try provider.gmailInboxRepo.storedAccounts()
        let inboxes = try inboxAccounts.map { try provider.gmailInboxRepo.load(account: $0) }
        guard inboxes.count == 1, inboxes[0].sources.count == 416, inboxes[0].messages.count == 557 else {
            throw EnvironmentError.missingCurrentSources
        }
        let store = InvestmentStore(), importer = engine(provider, store: store)
        for (name, sha) in selected {
            let prepared = try await importer.prepareImport(from: originalsRoot.appendingPathComponent(name))
            guard prepared.validation.passed, !prepared.investmentConfirmationBlocked,
                  let expected = prepared.investmentReview?.snapshot else {
                importer.cancelPreparedImport(prepared)
                throw EnvironmentError.missingCurrentSources
            }
            let result = await importer.commitPreparedImport(prepared)
            guard result.succeeded, result.persisted,
                  try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == expected,
                  store.snapshot == expected else { throw EnvironmentError.missingCurrentSources }
            print("ADOPTION_LOCAL_SOURCE_COMMITTED sha256=\(sha)")
        }
        let populated = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
        let originalContainerIDs = Set(before.containers.map(\.id))
        guard populated.containers.filter({ originalContainerIDs.contains($0.id) }) == before.containers,
              populated.holdings.filter({ originalContainerIDs.contains($0.containerID) }) == before.holdings,
              try provider.accountRepo.accounts(workspaceId: "default-workspace") == accounts,
              try provider.transactionRepo.trustedTransactions(workspaceId: "default-workspace") == transactions,
              try provider.cardRepo.snapshot(workspaceId: "default-workspace") == cards,
              try provider.importSessionRepo.bankSectionSnapshot(workspaceId: "default-workspace") == sections,
              try inboxAccounts.map({ try provider.gmailInboxRepo.load(account: $0) }) == inboxes,
              try sqlite.database.queryInt("SELECT COUNT(*) FROM import_sessions;") == 338 else {
            throw EnvironmentError.missingCurrentSources
        }
        for (name, sha) in selected {
            let source = originalsRoot.appendingPathComponent(name)
            let replay = try await importer.prepareImport(from: source)
            let result = await importer.commitPreparedImport(replay)
            guard result.previousImport != nil, !result.persisted,
                  try provider.investmentRepo.snapshot(workspaceID: "default-workspace") == populated,
                  try BackupFiles.hash(source).sha256 == sha else { throw EnvironmentError.missingCurrentSources }
        }
        try sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        try BackupCompatibility.verifyDatabase(reopened.database)
        guard try reopened.investmentRepo.snapshot(workspaceID: "default-workspace") == populated,
              try reopened.database.queryInt("SELECT COUNT(*) FROM import_sessions;") == 338 else {
            throw EnvironmentError.missingCurrentSources
        }
        print("ADOPTION_LOCAL_SOURCES_READY originals=5 exact_replays=5 total_imports=338 unchanged_existing_financial_state=true fresh_reopen=true")
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
        #expect(manifest.formatVersion == 1 && manifest.schemaVersion == 23)
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
            let reportingExcluded = try #require(before.containers.first(where: { $0.institution != "Zurich ISP" }))
            try provider.netWorthMembershipRepo.setIncluded(false, member: .investmentContainer(reportingExcluded.id), workspaceID: "default-workspace")
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
            #expect(try provider.netWorthMembershipRepo.snapshot(workspaceID: "default-workspace").excluded == [.investmentContainer(reportingExcluded.id)])

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

    @Test func publicPriceMappingWriteDoesNotInvalidateTheNextAuthenticBatchReview() async throws {
        let sources = try currentSources()
        let funds = sources.filter { $0.deletingLastPathComponent().lastPathComponent == "IndianMutualFunds" }
        let inspection = engine(DatabaseProvider(inMemory: true))
        var dated: [(URL, String)] = []
        for source in funds {
            let prepared = try await inspection.prepareImport(from: source)
            guard let date = prepared.investmentPlan?.evidence.scopes.first?.holdingsDate else { throw EnvironmentError.missingCurrentSources }
            dated.append((source, date)); inspection.cancelPreparedImport(prepared)
        }
        dated.sort { $0.1 < $1.1 }
        guard dated.count == 2, dated[0].1 < dated[1].1,
              let ibkr = sources.first(where: { $0.deletingLastPathComponent().lastPathComponent == "IBKR" && $0.pathExtension == "csv" }),
              let isp = sources.first(where: { $0.deletingLastPathComponent().lastPathComponent == "ZurichISP" }) else {
            throw EnvironmentError.missingCurrentSources
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s97-batch-review-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sqlite = try SQLiteRepositoryProvider(path: directory.appendingPathComponent("ledger.sqlite").path)
        defer { sqlite.database.close() }
        for provider in [DatabaseProvider(inMemory: true), DatabaseProvider.verifiedSQLite(sqlite)] {
            let importer = engine(provider)
            let first = try await importer.prepareImport(from: dated[0].0)
            let firstResult = await importer.commitPreparedImport(first)
            #expect(firstResult.succeeded)
            let next = try await importer.prepareImport(from: dated[1].0)
            guard next.investmentPlan != nil, !next.investmentConfirmationBlocked else { throw EnvironmentError.missingCurrentSources }
            let before = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
            let assignments = Dictionary(uniqueKeysWithValues: before.holdings.compactMap { holding in
                InvestmentPriceRegistry.confirmedMapping(for: holding).map { (holding.id, $0) }
            })
            #expect(!assignments.isEmpty)
            let saved = provider.investmentRepo.savePriceMappings(.init(providerGeneration: provider.generationToken,
                workspaceID: "default-workspace", baseline: before, assignments: assignments))
            #expect(saved == .saved)
            let mapped = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
            #expect(mapped.hasSameSource(as: before))
            let nextResult = await importer.commitPreparedImport(next)
            #expect(nextResult.succeeded, "A public mapping-only update must not require Prepare Again")
            let after = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
            let latestMappingsRetained = after.holdings.filter { assignments[$0.id] != nil }.allSatisfy { $0.priceMapping == assignments[$0.id] }
            #expect(latestMappingsRetained)

            // A genuine intervening source update still invalidates the reviewed snapshot.
            let pending = try await importer.prepareImport(from: ibkr)
            guard let plan = pending.investmentPlan else { throw EnvironmentError.missingCurrentSources }
            let intervening = try await importer.prepareImport(from: isp)
            let interveningResult = await importer.commitPreparedImport(intervening)
            #expect(interveningResult.succeeded)
            #expect(provider.investmentRepo.commitCurrentHoldings(plan) == .rejected(.staleReview))
            importer.cancelPreparedImport(pending)
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
