import Combine
import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct NetWorthMembershipTests {
    private func restoredCopy() throws -> (URL, SQLiteRepositoryProvider) {
        let path = try #require(ProcessInfo.processInfo.environment["LEDGERFORGE_S99_V26_BACKUP"], "Nominate the accepted V26 backup; ordinary Current is not a test source.")
        let source = URL(fileURLWithPath: path)
        let manifest = try BackupFiles.verifyPackage(source)
        #expect(manifest.schemaVersion == 26)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s99-membership-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let destination = folder.appendingPathComponent("qualification.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: source, manifest: manifest, destination: destination)
        #expect(try BackupFiles.verifyPackage(source) == manifest)
        return (folder, try SQLiteRepositoryProvider(path: destination.path, migrations: allMigrations, access: .existing))
    }

    @Test(.globalRuntimeStateIsolation)
    func authenticParentsParityFailureReopenAndBackupRestore() async throws {
        let (folder, sqlite) = try restoredCopy()
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: folder) }
        let workspaceID = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.only)
        let workspace = try #require(try sqlite.workspaceRepo.workspace(id: workspaceID))
        let accounts = try sqlite.accountRepo.accounts(workspaceId: workspaceID)
        let investments = try sqlite.investmentRepo.snapshot(workspaceID: workspaceID)
        let container = try #require(investments.containers.first)
        let member = NetWorthMemberID.investmentContainer(container.id)
        let memory = InMemoryRepositoryProvider()
        _ = try memory.workspaceRepo.upsertWorkspace(workspace)
        // Exact source-qualified identities, not authored financial DTOs.
        for account in accounts { _ = try memory.accountRepo.upsertAccount(account) }
        let baseline = try NetWorthTestSupport.financialDigest(sqlite.database)
        #expect(try sqlite.netWorthMembershipRepo.snapshot(workspaceID: workspaceID).excluded.isEmpty)
        for repository in [memory.netWorthMembershipRepo, sqlite.netWorthMembershipRepo] {
            for account in accounts where ["bank", "credit_card"].contains(account.accountType ?? "") {
                let target = NetWorthMemberID.account(account.id)
                #expect(try repository.setIncluded(false, member: target, workspaceID: workspaceID))
                #expect(try !repository.setIncluded(false, member: target, workspaceID: workspaceID))
                #expect(try repository.snapshot(workspaceID: workspaceID).excluded.contains(target))
                #expect(throws: (any Error).self) { try repository.setIncluded(false, member: target, workspaceID: "wrong-workspace") }
            }
            #expect(throws: (any Error).self) { try repository.setIncluded(false, member: .account("missing"), workspaceID: workspaceID) }
            #expect(throws: (any Error).self) { try repository.setIncluded(false, member: .investmentContainer("missing"), workspaceID: workspaceID) }
        }
        #expect(try memory.netWorthMembershipRepo.snapshot(workspaceID: workspaceID) == sqlite.netWorthMembershipRepo.snapshot(workspaceID: workspaceID))
        #expect(try sqlite.netWorthMembershipRepo.setIncluded(false, member: member, workspaceID: workspaceID))
        let saved = try sqlite.netWorthMembershipRepo.snapshot(workspaceID: workspaceID)
        try sqlite.database.execute(sql: "CREATE TRIGGER s99_fail_exclusion_delete BEFORE DELETE ON net_worth_exclusions BEGIN SELECT RAISE(ABORT,'test metadata failure'); END;")
        #expect(throws: (any Error).self) { try sqlite.netWorthMembershipRepo.setIncluded(true, member: member, workspaceID: workspaceID) }
        #expect(try sqlite.netWorthMembershipRepo.snapshot(workspaceID: workspaceID) == saved)
        try sqlite.database.execute(sql: "DROP TRIGGER s99_fail_exclusion_delete;")
        #expect(throws: (any Error).self) { try sqlite.database.executePrepared(sql: "INSERT INTO net_worth_exclusions(workspace_id,account_id,container_id) VALUES(?,?,?);", params: [workspaceID, accounts[0].id, container.id]) }
        #expect(throws: (any Error).self) { try sqlite.database.executePrepared(sql: "INSERT INTO net_worth_exclusions(workspace_id,container_id) VALUES(?,?);", params: [workspaceID, container.id]) }
        #expect(throws: (any Error).self) { try sqlite.database.executePrepared(sql: "INSERT INTO net_worth_exclusions(workspace_id,container_id) VALUES(?,?);", params: ["wrong-workspace", container.id]) }
        #expect(try NetWorthTestSupport.financialDigest(sqlite.database) == baseline)

        let backupDirectory = folder.appendingPathComponent("backups")
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: false)
        let coordinator = BackupRestoreCoordinator(testingAt: folder.appendingPathComponent("qualification.sqlite"))
        DatabaseProvider.shared = .verifiedSQLite(sqlite)
        coordinator.installTestProvider(sqlite)
        await coordinator.createBackup(to: backupDirectory)
        let package = try #require(coordinator.lastBackupURL)
        let manifest = try BackupFiles.verifyPackage(package)
        #expect(manifest.schemaVersion == BackupCompatibility.supportedSchemaVersion)
        let restored = folder.appendingPathComponent("restored.sqlite")
        _ = try BackupCompatibility.prepareCandidate(package: package, manifest: manifest, destination: restored)
        let restoredProvider = try SQLiteRepositoryProvider(path: restored.path, migrations: allMigrations, access: .existing)
        #expect(try restoredProvider.netWorthMembershipRepo.snapshot(workspaceID: workspaceID) == saved)
        #expect(try NetWorthTestSupport.financialDigest(restoredProvider.database) == baseline)
        try restoredProvider.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: restored.path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        #expect(try reopened.netWorthMembershipRepo.snapshot(workspaceID: workspaceID) == saved)
        #expect(try reopened.netWorthMembershipRepo.setIncluded(true, member: member, workspaceID: workspaceID))
        #expect(try !reopened.netWorthMembershipRepo.snapshot(workspaceID: workspaceID).excluded.contains(member))
        print("S99_MEMBERSHIP authentic parent parity, failed-save rollback, exact current-schema backup, reopen, and financial invariance PASS")
    }

    @Test(.globalRuntimeStateIsolation)
    func stagedMembershipIsCoherentAndStaleMutationCannotPublish() throws {
        let (folder, sqlite) = try restoredCopy()
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: folder) }
        let workspaceID = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.only)
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        let accounts = AccountStore(), investments = InvestmentStore(), membership = NetWorthMembershipStore()
        let hydrator = RepositoryStoreHydrator(accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo, cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo, fundingPlanRepo: provider.fundingPlanRepo, investmentRepo: provider.investmentRepo,
            netWorthMembershipRepo: provider.netWorthMembershipRepo, accountStore: accounts,
            transactionStore: TransactionStore(), categoryStore: CategoryStore(), cardStore: CardStore(), salaryStore: SalaryStore(),
            fundingPlanStore: FundingPlanStore(), investmentStore: investments, netWorthMembershipStore: membership,
            importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(), workspaceId: workspaceID,
            persistenceState: provider.persistenceState, providerGeneration: provider.generationToken,
            participatesInLifecycleGate: false)
        let staged = try hydrator.stageHydration()
        #expect(membership.snapshot == nil)
        var coherent = false
        let subscription = accounts.$accounts.dropFirst().sink { _ in
            coherent = membership.snapshot == staged.netWorthMembership && investments.snapshot == staged.investments
        }
        hydrator.publish(staged)
        #expect(coherent)
        let target = try #require(staged.accounts.first?.repositoryAccountId)
        var leaseHeld = false
        let coordinator = NetWorthMembershipCoordinator(provider: { provider }, forcedHydration: { _, _ in
            leaseHeld = DatabaseActivityGate.shared.hasActiveOperations
            _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        })
        #expect(throws: RepositoryError.self) {
            try coordinator.setIncluded(false, member: .account(target), workspaceID: workspaceID, expectedGeneration: ProviderGenerationToken())
        }
        #expect(try coordinator.setIncluded(false, member: .account(target), workspaceID: workspaceID, expectedGeneration: provider.generationToken))
        #expect(leaseHeld && membership.snapshot?.excluded == [.account(target)])
        try sqlite.database.execute(sql: "ALTER TABLE net_worth_exclusions RENAME TO s99_unavailable_membership;")
        #expect(throws: (any Error).self) { try hydrator.stageHydration() }
        #expect(membership.snapshot?.excluded == [.account(target)])
        try sqlite.database.execute(sql: "ALTER TABLE s99_unavailable_membership RENAME TO net_worth_exclusions;")
        provider.invalidateGeneration()
        #expect(throws: RepositoryError.self) { try provider.netWorthMembershipRepo.snapshot(workspaceID: workspaceID) }
        withExtendedLifetime(subscription) {}
    }

    @Test(.globalRuntimeStateIsolation)
    func publishedReportSurvivesMetadataAndCacheUpdatesAndWithdrawsAcrossFailureAndGenerationChange() async throws {
        let (folder, sqlite) = try restoredCopy()
        defer { sqlite.database.close(); try? FileManager.default.removeItem(at: folder) }
        let workspace = try #require(sqlite.database.query(sql: "SELECT id FROM workspaces;") { $0.string(at: 0) }.compactMap { $0 }.only)
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        DatabaseProvider.shared = provider
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, workspaceId: workspace)
        let oldSnapshot = try hydrator.stageHydration()
        hydrator.publish(oldSnapshot)
        let suite = "LedgerForge.s99.lifecycle." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ReportingCurrencyPreferences(defaults: defaults)
        let rates = AlDarReferenceSession(defaults: defaults, enabled: false)
        let prices = InvestmentPriceSession(defaults: defaults, enabled: false)
        prices.activate()
        let cache = try sqlite.backgroundPublicCacheRepo.snapshot(now: Date())
        rates.installShared(cache.alDarLegs, failures: [], busy: false)
        prices.installShared(cache.investmentQuotes, failures: [:], busy: false)
        let gmail = GmailIntakeSession(preferences: defaults)
        await gmail.reloadInbox()
        #expect(gmail.coverage?.generation == provider.generationToken)
        #expect(gmail.coverage?.inbox?.sources.isEmpty == false)
        let first = DashboardViewModel(reportingPreferences: preferences, reportingRates: rates, reportingPrices: prices, gmail: gmail, workspaceID: workspace)
        let second = DashboardViewModel(reportingPreferences: preferences, reportingRates: rates, reportingPrices: prices, gmail: gmail, workspaceID: workspace)
        let planner = SalaryWorkspaceViewModel(workspaceID: workspace)
        let plan = planner.plan, draft = planner.rawText
        let before = try NetWorthTestSupport.financialDigest(sqlite.database)
        #expect(first.netWorthReport.state == .ready)
        #expect(first.netWorthReport.scopeNotes.count > 1)
        let skipped = gmail.sources.filter { $0.attention == .skipped && !gmail.importedSourceIDs.contains($0.id) }
        #expect(!skipped.isEmpty)
        #expect(first.netWorthReport.scopeNotes.contains { $0.contains("\(Set(skipped.compactMap(\.sha256)).count) skipped or held") })
        #expect(first.netWorthReport == second.netWorthReport)
        preferences.setVisible(true, currency: .qar)
        await drainPresentation()
        #expect(first.netWorthReport.targets.map(\.currency) == ReportingCurrency.allCases)
        #expect(first.netWorthReport == second.netWorthReport)
        #expect(try sqlite.netWorthMembershipRepo.snapshot(workspaceID: workspace).excluded.isEmpty)
        #expect(try NetWorthTestSupport.financialDigest(sqlite.database) == before)
        #expect(rates.requestCount == 0 && prices.requestCount == 0)
        let member = try #require(first.netWorthReport.members.first?.id)
        let coordinator = NetWorthMembershipCoordinator()
        #expect(try coordinator.setIncluded(false, member: member, workspaceID: workspace, expectedGeneration: provider.generationToken))
        await drainPresentation()
        #expect(first.netWorthReport.members.first { $0.id == member }?.isIncluded == false)
        #expect(first.netWorthReport == second.netWorthReport)
        #expect(planner.plan == plan && planner.rawText == draft)
        let excluded = first.netWorthReport
        prices.installShared(cache.investmentQuotes, failures: [:], busy: false)
        rates.installShared(cache.alDarLegs, failures: [], busy: false)
        await drainPresentation()
        #expect(first.netWorthReport == excluded)
        try sqlite.database.execute(sql: "CREATE TRIGGER s99_fail_save BEFORE DELETE ON net_worth_exclusions BEGIN SELECT RAISE(ABORT,'test metadata failure'); END;")
        #expect(throws: (any Error).self) { try coordinator.setIncluded(true, member: member, workspaceID: workspace, expectedGeneration: provider.generationToken) }
        #expect(first.netWorthReport == excluded)
        try sqlite.database.execute(sql: "DROP TRIGGER s99_fail_save;")
        try sqlite.database.execute(sql: "ALTER TABLE net_worth_exclusions RENAME TO s99_unavailable_membership;")
        #expect(throws: (any Error).self) { try hydrator.hydrateIfNeeded(forceRefresh: true) }
        #expect(first.netWorthReport.state == .unavailable && first.netWorthReport.targets.isEmpty)
        try sqlite.database.execute(sql: "ALTER TABLE s99_unavailable_membership RENAME TO net_worth_exclusions;")
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        await drainPresentation()
        #expect(first.netWorthReport == excluded)

        let replacement = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("qualification.sqlite").path, migrations: allMigrations, access: .existing)
        defer { replacement.database.close() }
        let next = DatabaseProvider.verifiedSQLite(replacement)
        ApplicationAvailability.shared.begin()
        #expect(first.netWorthReport.state == .loading && first.netWorthReport.targets.isEmpty)
        DatabaseProvider.shared = next
        let nextHydrator = RepositoryStoreHydrator(databaseProvider: next, workspaceId: workspace)
        _ = try nextHydrator.hydrateIfNeeded(forceRefresh: true)
        await drainPresentation()
        #expect(first.netWorthReport.generation == next.generationToken)
        // A retained inbox is not current coverage for the replacement ledger.
        #expect(first.netWorthReport.scopeNotes.count == 1)
        try replacement.database.execute(sql: "ALTER TABLE gmail_inbox_state RENAME TO s99_unavailable_inbox;")
        await gmail.reloadInbox()
        await drainPresentation()
        #expect(gmail.coverage == nil)
        #expect(first.netWorthReport.scopeNotes.count == 1)
        try replacement.database.execute(sql: "ALTER TABLE s99_unavailable_inbox RENAME TO gmail_inbox_state;")
        await gmail.reloadInbox()
        await drainPresentation()
        #expect(gmail.coverage?.generation == next.generationToken)
        #expect(first.netWorthReport.scopeNotes == excluded.scopeNotes)
        #expect(first.netWorthReport.members.first { $0.id == member }?.isIncluded == false)
        // A stale completion is not allowed to make the old report current.
        hydrator.publish(oldSnapshot)
        await drainPresentation()
        #expect(first.netWorthReport.state == .membershipUnavailable && first.netWorthReport.targets.isEmpty)
        _ = try nextHydrator.hydrateIfNeeded(forceRefresh: true)
        await drainPresentation()
        #expect(first.netWorthReport.generation == next.generationToken)
        #expect(try NetWorthTestSupport.financialDigest(replacement.database) == before)
        #expect(rates.requestCount == 0 && prices.requestCount == 0)
        // An empty inbox in a genuinely different provider cannot retain the
        // accepted campaign's held counts. No authored financial rows are used.
        DatabaseProvider.shared = DatabaseProvider(inMemory: true)
        await gmail.reloadInbox()
        #expect(gmail.coverage?.inbox?.sources.isEmpty != false)
        #expect(NetWorthProjection.scopeNotes(inbox: gmail.coverage?.inbox, importedSourceIDs: gmail.coverage?.importedSourceIDs ?? []).count == 1)
        withExtendedLifetime((first, second, planner, prices, rates)) {}
    }

    private func drainPresentation() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

@MainActor
enum NetWorthTestSupport {
    /// Private financial bytes are hashed in RAM, never printed or retained as
    /// test fixtures. Membership is the only allowed ledger-table difference.
    static func financialDigest(_ database: SQLiteDatabase, excluding additionalMetadata: Set<String> = []) throws -> String {
        let tables = try database.query(sql: "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'net_worth_exclusions' ORDER BY name;") { $0.string(at: 0)! }
        var digest = SHA256()
        for table in tables where !additionalMetadata.contains(table) {
            let escaped = table.replacingOccurrences(of: "\"", with: "\"\"")
            let columns = try database.query(sql: "PRAGMA table_info(\"\(escaped)\");") { $0.string(at: 1)! }
            let fields = columns.map { "quote(\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\")" }.joined(separator: " || '|' || ")
            let rows = try database.query(sql: "SELECT \(fields) FROM \"\(escaped)\";") { $0.string(at: 0)! }.sorted()
            digest.update(data: Data(table.utf8))
            for row in rows { digest.update(data: Data((row + "\n").utf8)) }
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private extension Array {
    var only: Element? { count == 1 ? first : nil }
}
