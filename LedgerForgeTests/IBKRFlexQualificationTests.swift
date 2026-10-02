import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

/// Explicit live qualification using the saved app credential, an approved
/// ledger backup and an unchanged original statement. Responses stay in RAM;
/// only ordinary isolated databases and their backups are written.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["LEDGERFORGE_S100_IBKR_QUALIFY"] == "1"))
@MainActor
struct IBKRFlexQualificationTests {
    private enum QualificationError: Error { case missingInput, missingCredential, originalMismatch }

    @Test(.globalRuntimeStateIsolation)
    func authenticFetchPersistenceReplayAndStatementPriority() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let ledgerPath = env["LEDGERFORGE_S100_IBKR_LEDGER"],
              let originalPath = env["LEDGERFORGE_S100_IBKR_ORIGINAL"],
              let originalSHA = env["LEDGERFORGE_S100_IBKR_ORIGINAL_SHA256"],
              ledgerPath.hasSuffix(".sqlite"),
              originalPath.hasPrefix("/Users/vyom/Documents/Ledger Forge/") else {
            throw QualificationError.missingInput
        }
        let originalURL = URL(fileURLWithPath: originalPath)
        guard try BackupFiles.hash(originalURL).sha256 == originalSHA else { throw QualificationError.originalMismatch }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-s100-flex-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("ledger.sqlite")
        let sourceDatabase = SQLiteDatabase(path: ledgerPath)
        try sourceDatabase.open(access: .readOnlySnapshot)
        try sourceDatabase.createBackup(at: databaseURL.path)
        sourceDatabase.close()
        let sqlite = try SQLiteRepositoryProvider(path: databaseURL.path, migrations: allMigrations, access: .existing, migrateExisting: true)
        defer { sqlite.database.close() }
        try BackupCompatibility.verifyDatabase(sqlite.database)

        // The separate ordinary importer obtains its plan from the authentic
        // original. No hand-authored statement/domain fixture enters this test.
        let memory = DatabaseProvider(inMemory: true)
        let importer = engine(memory)
        let prepared = try await importer.prepareImport(from: originalURL)
        guard prepared.investmentPlan != nil else { throw QualificationError.missingInput }
        let seed = await importer.commitPreparedImport(prepared)
        #expect(seed.succeeded)

        let keychain = IBKRFlexCredentialStore().forbiddingInteraction()
        guard let credentials = try await Task.detached(operation: { try keychain.load() }).value else {
            throw QualificationError.missingCredential
        }
        let capture = OriginalCapture()
        let source = try await IBKRFlexClient().fetch(credentials: credentials, observeOriginal: capture.install)
        let original = try #require(capture.read())
        let oracle = PositionOracle()
        let xml = XMLParser(data: original); xml.delegate = oracle
        #expect(xml.parse())
        #expect(oracle.positions.count == source.positionCount)
        let fingerprintMatches = SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined() == source.sourceSHA256
        #expect(fingerprintMatches)
        for position in source.positions {
            guard let row = oracle.positions.first(where: { $0["conid"] == position.conid }) else {
                throw QualificationError.originalMismatch
            }
            let exact = row["position"] == position.units.sourceText
                && row["costBasisPrice"] == position.averageCost.sourceText
                && row["costBasisMoney"] == position.totalCost.sourceText
                && row["markPrice"] == position.markPrice.sourceText
                && row["positionValue"] == position.reportedValue.sourceText
                && row["fifoPnlUnrealized"] == position.unrealizedPnL.sourceText
                && row["accountId"] == source.accountID
                && row["currency"] == position.currency
            #expect(exact)
        }

        for provider in [memory, DatabaseProvider.verifiedSQLite(sqlite)] {
            let before = try provider.investmentRepo.snapshot(workspaceID: "default-workspace")
            let workspace = try #require(try provider.workspaceRepo.workspace(id: "default-workspace"))
            let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: workspace.id)
            let members = try provider.netWorthMembershipRepo.snapshot(workspaceID: workspace.id)
            let plan = IBKRFlexHoldingsPlan(providerGeneration: provider.generationToken, workspace: workspace,
                                          baseline: before, source: source)
            #expect(provider.investmentRepo.saveIBKRFlexHoldings(plan) == .saved)
            let accepted = try provider.investmentRepo.snapshot(workspaceID: workspace.id)
            let receiptMatches = accepted.latestIBKRFlex == source
            let otherProvidersUnchanged = nonIBKR(accepted) == nonIBKR(before)
            let transactionsUnchanged = try provider.transactionRepo.trustedTransactions(workspaceId: workspace.id) == transactions
            let membershipUnchanged = try provider.netWorthMembershipRepo.snapshot(workspaceID: workspace.id) == members
            #expect(receiptMatches && otherProvidersUnchanged && transactionsUnchanged && membershipUnchanged)
            let container = try #require(accepted.containers.first { $0.ibkrSource != nil })
            let positions = accepted.holdings.filter { $0.containerID == container.id }
            #expect(positions.count == source.positionCount)
            for row in positions {
                let position = try #require(source.positions.first { $0.instrumentIdentity == row.instrumentIdentity })
                let exact = row.units == position.units && row.averageCost == position.averageCost
                    && row.totalCost == position.totalCost && row.currency == position.currency
                    && row.ibkrObservationID == source.observationID
                #expect(exact)
                if let old = before.holdings.first(where: { $0.containerID == container.id && $0.instrumentIdentity == row.instrumentIdentity }) {
                    #expect(old.id == row.id)
                }
            }
            let replay = IBKRFlexHoldingsPlan(providerGeneration: provider.generationToken, workspace: workspace,
                                            baseline: accepted, source: source)
            #expect(provider.investmentRepo.saveIBKRFlexHoldings(replay) == .saved)
            let replayUnchanged = try provider.investmentRepo.snapshot(workspaceID: workspace.id) == accepted
            #expect(replayUnchanged)
            #expect(provider.investmentRepo.saveIBKRFlexHoldings(plan) == .rejected(.staleReview))
            let wrongGeneration = IBKRFlexHoldingsPlan(providerGeneration: ProviderGenerationToken(), workspace: workspace,
                                                     baseline: accepted, source: source)
            #expect(provider.investmentRepo.saveIBKRFlexHoldings(wrongGeneration) == .staleProviderGeneration)
            let replayImporter = engine(provider)
            let statementReplay = try await replayImporter.prepareImport(from: originalURL)
            #expect(statementReplay.investmentReviewFailure == .directSourceRetained)
            replayImporter.cancelPreparedImport(statementReplay)
            let afterStatement = try provider.investmentRepo.snapshot(workspaceID: workspace.id) == accepted
            #expect(afterStatement)
        }

        let expected = try sqlite.investmentRepo.snapshot(workspaceID: "default-workspace")
        let backupURL = directory.appendingPathComponent("reopened.sqlite")
        try sqlite.database.createBackup(at: backupURL.path)
        let reopened = try SQLiteRepositoryProvider(path: backupURL.path, migrations: allMigrations, access: .existing, migrateExisting: false)
        defer { reopened.database.close() }
        try BackupCompatibility.verifyDatabase(reopened.database)
        let reopenedMatches = try reopened.investmentRepo.snapshot(workspaceID: "default-workspace") == expected
        #expect(reopenedMatches)
        let wrapped = DatabaseProvider.verifiedSQLite(reopened), store = InvestmentStore()
        let hydrator = RepositoryStoreHydrator(accountRepo: wrapped.accountRepo, importSessionRepo: wrapped.importSessionRepo,
            transactionRepo: wrapped.transactionRepo, categoryRepo: wrapped.categoryRepo, cardRepo: wrapped.cardRepo,
            salaryRepo: wrapped.salaryRepo, fundingPlanRepo: wrapped.fundingPlanRepo, investmentRepo: wrapped.investmentRepo,
            netWorthMembershipRepo: wrapped.netWorthMembershipRepo, intelligenceRepo: wrapped.intelligenceRepo,
            accountStore: AccountStore(), transactionStore: TransactionStore(), categoryStore: CategoryStore(),
            cardStore: CardStore(), salaryStore: SalaryStore(), fundingPlanStore: FundingPlanStore(), investmentStore: store,
            netWorthMembershipStore: NetWorthMembershipStore(), intelligenceStore: FinancialIntelligenceStore(),
            importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
            persistenceState: wrapped.persistenceState, providerGeneration: wrapped.generationToken,
            participatesInLifecycleGate: false)
        _ = try hydrator.hydrateIfNeeded(forceRefresh: true)
        let hydratedMatches = store.snapshot == expected
        #expect(hydratedMatches)
        print("IBKR focused qualification: authentic native capture, original XML values, provider parity, repeat/stale/generation checks, statement priority, unrelated data, backup/reopen/hydration passed.")
    }

    private func nonIBKR(_ value: InvestmentSnapshot) -> InvestmentSnapshot {
        let containers = value.containers.filter { $0.institution != "Interactive Brokers" }
        let ids = Set(containers.map(\.id))
        return .init(containers: containers, holdings: value.holdings.filter { ids.contains($0.containerID) })
    }

    private func engine(_ provider: DatabaseProvider) -> ImportEngine {
        let hydrator = RepositoryStoreHydrator(databaseProvider: provider, participatesInLifecycleGate: false)
        return ImportEngine(importPersistenceCoordinator: DefaultImportPersistenceCoordinator(databaseProvider: provider),
            persistenceStateProvider: { provider.persistenceState }, providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) }, rejectedAttemptHydration: {})
    }

    nonisolated private final class OriginalCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var bytes: Data?
        func install(_ value: Data) { lock.lock(); defer { lock.unlock() }; bytes = value }
        func read() -> Data? { lock.lock(); defer { lock.unlock() }; return bytes }
    }
    nonisolated private final class PositionOracle: NSObject, XMLParserDelegate {
        var positions: [[String: String]] = []
        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String] = [:]) {
            if name == "OpenPosition" { positions.append(attributes) }
        }
    }
}
