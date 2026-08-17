import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct CBQCurrentAccountXLSImportLifecycleTests {
    private let workspaceID = "workspace-cbq-current-xls-v1"

    @Test(.globalRuntimeStateIsolation)
    func ordinaryDirectURLPreparationIsWriteFreeConfirmationPersistsAndExactBytesReject() async throws {
        let context = try CBQProviderContext(.inMemory)
        defer { context.cleanup() }
        let stores = CBQRuntimeStores()
        let engine = makeEngine(provider: context.provider, stores: stores)
        let source = FixtureLocator.cbqSyntheticXLS(CBQXLSFixtureTestSupport.fixture)

        let prepared = try await engine.prepareImport(from: source)
        defer { engine.cancelPreparedImport(prepared) }
        #expect(prepared.detectedInstitution == .cbq)
        #expect(prepared.detectedDocumentType == .bankAccount)
        #expect(prepared.parserName == "CBQ Current Account XLS")
        #expect(prepared.transactionCount == 4)
        #expect(prepared.validation.passed)
        #expect(prepared.financialDocument.declaredStatementPeriod == nil)
        #expect(prepared.validation.openingBalanceMoney == nil)
        #expect(prepared.validation.closingBalanceMoney == nil)
        #expect(
            prepared.fingerprintSet.duplicateAuthority?.algorithm
                == SourceContentSnapshot.algorithm
        )
        #expect(try context.provider.workspaceRepo.workspace(id: workspaceID) == nil)
        #expect(try graphSnapshot(context.provider).isEmpty)

        let accepted = await engine.commitPreparedImport(
            prepared,
            accountChoice: .createNewAccount
        )
        #expect(accepted.succeeded)
        #expect(stores.accounts.accounts.count == 1)
        #expect(stores.transactions.transactions.count == 4)
        let acceptedGraph = try graphSnapshot(context.provider)

        let duplicatePrepared = try await engine.prepareImport(from: source)
        defer { engine.cancelPreparedImport(duplicatePrepared) }
        let duplicate = await engine.commitPreparedImport(duplicatePrepared)
        #expect(!duplicate.succeeded)
        #expect(try financialGraphSnapshot(context.provider) == acceptedGraph.financial)
        #expect(
            try context.provider.importSessionRepo.importAttempts(workspaceId: workspaceID)
                .filter { $0.outcomeCode == ImportAttemptOutcome.exactStatementDuplicate.rawValue }
                .count == 1
        )
    }

    @Test(.globalRuntimeStateIsolation)
    func inMemoryAndSQLitePersistTheSameOneAccountGraph() async throws {
        let memory = try await acceptedGraph(for: .inMemory)
        let sqlite = try await acceptedGraph(for: .sqlite)
        #expect(memory == sqlite)
        #expect(memory.accountCount == 1)
        #expect(memory.identifierCount == 1)
        #expect(memory.transactionCount == 4)
        #expect(memory.successfulAttemptCount == 1)
        #expect(memory.valueDateCount == 0)
        #expect(memory.projectionCount == 0)
        #expect(memory.currencyCodes == ["QAR"])
        #expect(memory.profileIDs == [CBQCurrentAccountXLSParser.profileID])
    }

    @Test(.globalRuntimeStateIsolation)
    func sqliteCloseReopenCanonicalHydrationPreservesTheCompleteGraph() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-CBQ-XLS-Relaunch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("cbq.sqlite")
        let initialSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        let initialProvider = DatabaseProvider.verifiedSQLite(
            initialSQLite,
            protectsGeneration: false
        )
        let initialStores = CBQRuntimeStores()
        let engine = makeEngine(provider: initialProvider, stores: initialStores)
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.cbqSyntheticXLS(CBQXLSFixtureTestSupport.fixture)
        )
        defer { engine.cancelPreparedImport(prepared) }
        let accepted = await engine.commitPreparedImport(
            prepared,
            accountChoice: .createNewAccount
        )
        #expect(accepted.succeeded)
        initialSQLite.database.close()

        let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        defer { reopenedSQLite.database.close() }
        let reopenedProvider = DatabaseProvider.verifiedSQLite(
            reopenedSQLite,
            protectsGeneration: false
        )
        let reopenedStores = CBQRuntimeStores()
        let hydration = try reopenedStores.hydrator(
            provider: reopenedProvider,
            workspaceID: workspaceID
        ).hydrateIfNeeded()

        #expect(hydration.didHydrate)
        #expect(hydration.accountCount == 1)
        #expect(hydration.transactionCount == 4)
        #expect(hydration.importSessionCount == 1)
        #expect(reopenedStores.accounts.accounts.count == 1)
        #expect(reopenedStores.transactions.transactions.count == 4)
        #expect(reopenedStores.transactions.transactions.allSatisfy {
            $0.valueDate == nil
                && $0.currency == "QAR"
                && $0.runningBalanceMoney != nil
                && $0.sourceProvenance.first?.parserProfileID
                    == CBQCurrentAccountXLSParser.profileID
        })
        #expect(
            try reopenedProvider.importSessionRepo
                .statementFinancialProjections(workspaceId: workspaceID).isEmpty
        )
        #expect(try financialGraphSnapshot(reopenedProvider).transactionCount == 4)
    }

    @Test(.globalRuntimeStateIsolation)
    func rejectedOrdinaryPreparationLeavesZeroAcceptedResidue() async throws {
        let context = try CBQProviderContext(.sqlite)
        defer { context.cleanup() }
        let stores = CBQRuntimeStores()
        let coordinator = DefaultImportCoordinator(
            readerRegistry: DefaultReaderRegistry(readers: [ZeroAmountCBQXLSReader()])
        )
        let engine = makeEngine(
            provider: context.provider,
            stores: stores,
            coordinator: coordinator
        )

        await #expect(throws: CBQCurrentAccountXLSParserError.self) {
            try await engine.prepareImport(
                from: FixtureLocator.cbqSyntheticXLS(CBQXLSFixtureTestSupport.fixture)
            )
        }
        #expect(try graphSnapshot(context.provider).isEmpty)
        #expect(stores.accounts.accounts.isEmpty)
        #expect(stores.transactions.transactions.isEmpty)
    }

    private func acceptedGraph(for kind: CBQProviderKind) async throws -> CBQGraphSnapshot {
        let context = try CBQProviderContext(kind)
        defer { context.cleanup() }
        let stores = CBQRuntimeStores()
        let engine = makeEngine(provider: context.provider, stores: stores)
        let prepared = try await engine.prepareImport(
            from: FixtureLocator.cbqSyntheticXLS(CBQXLSFixtureTestSupport.fixture)
        )
        defer { engine.cancelPreparedImport(prepared) }
        let result = await engine.commitPreparedImport(
            prepared,
            accountChoice: .createNewAccount
        )
        #expect(result.succeeded)
        return try graphSnapshot(context.provider)
    }

    private func makeEngine(
        provider: DatabaseProvider,
        stores: CBQRuntimeStores,
        coordinator: (any ImportFramework.ImportCoordinator)? = nil
    ) -> ImportEngine {
        let persistence = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(
                workspaceId: workspaceID,
                workspaceName: "CBQ Current XLS v1 Tests"
            )
        )
        let hydrator = stores.hydrator(provider: provider, workspaceID: workspaceID)
        return ImportEngine(
            importCoordinator: coordinator ?? DefaultImportCoordinator(
                readerRegistry: DefaultReaderRegistry()
            ),
            importPersistenceCoordinator: persistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) },
            rejectedAttemptHydration: { try hydrator.hydrateImportAttempts() },
            developmentProfileAcknowledgementGate:
                DevelopmentProfileAcknowledgementGate(stateProvider: { nil })
        )
    }

    private func graphSnapshot(_ provider: DatabaseProvider) throws -> CBQGraphSnapshot {
        let financial = try financialGraphSnapshot(provider)
        let attempts = try provider.importSessionRepo.importAttempts(workspaceId: workspaceID)
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
        return CBQGraphSnapshot(
            financial: financial,
            successfulAttemptCount: attempts.filter {
                $0.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue
            }.count,
            valueDateCount: transactions.compactMap(\.valueDateISO).count,
            projectionCount: try provider.importSessionRepo
                .statementFinancialProjections(workspaceId: workspaceID).count,
            currencyCodes: Set(transactions.map(\.nativeCurrency)),
            profileIDs: Set(transactions.flatMap(\.rawRows).compactMap(\.parserProfileId))
        )
    }

    private func financialGraphSnapshot(
        _ provider: DatabaseProvider
    ) throws -> CBQFinancialGraphSnapshot {
        let accounts = try provider.accountRepo.accounts(workspaceId: workspaceID)
        let identifiers = try accounts.flatMap {
            try provider.accountRepo.identifiers(accountId: $0.id, workspaceId: workspaceID)
        }
        return CBQFinancialGraphSnapshot(
            accountCount: accounts.count,
            identifierCount: identifiers.count,
            transactionCount: try provider.transactionRepo
                .trustedTransactions(workspaceId: workspaceID).count
        )
    }
}

private enum CBQProviderKind { case inMemory, sqlite }

@MainActor
private final class CBQProviderContext {
    let provider: DatabaseProvider
    private let sqlite: SQLiteRepositoryProvider?
    private let directory: URL?

    init(_ kind: CBQProviderKind) throws {
        switch kind {
        case .inMemory:
            provider = DatabaseProvider(inMemory: true)
            sqlite = nil
            directory = nil
        case .sqlite:
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("LedgerForge-CBQ-XLS-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let sqlite = try SQLiteRepositoryProvider(
                path: directory.appendingPathComponent("cbq.sqlite").path
            )
            provider = .verifiedSQLite(sqlite, protectsGeneration: false)
            self.sqlite = sqlite
            self.directory = directory
        }
    }

    func cleanup() {
        sqlite?.database.close()
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }
}

@MainActor
private final class CBQRuntimeStores {
    let accounts = AccountStore()
    let transactions = TransactionStore()
    let sessions = ImportSessionStore()
    let attempts = ImportAttemptStore()
    let categories = CategoryStore()

    func hydrator(provider: DatabaseProvider, workspaceID: String) -> RepositoryStoreHydrator {
        RepositoryStoreHydrator(
            databaseProvider: provider,
            accountStore: accounts,
            transactionStore: transactions,
            categoryStore: categories,
            importSessionStore: sessions,
            importAttemptStore: attempts,
            workspaceId: workspaceID,
            categoryReconciliationGate: nil,
            participatesInLifecycleGate: false
        )
    }
}

private struct CBQFinancialGraphSnapshot: Equatable {
    let accountCount: Int
    let identifierCount: Int
    let transactionCount: Int
    var isEmpty: Bool { accountCount == 0 && identifierCount == 0 && transactionCount == 0 }
}

private struct CBQGraphSnapshot: Equatable {
    let financial: CBQFinancialGraphSnapshot
    let successfulAttemptCount: Int
    let valueDateCount: Int
    let projectionCount: Int
    let currencyCodes: Set<String>
    let profileIDs: Set<String>

    var accountCount: Int { financial.accountCount }
    var identifierCount: Int { financial.identifierCount }
    var transactionCount: Int { financial.transactionCount }
    var isEmpty: Bool {
        financial.isEmpty && successfulAttemptCount == 0 && projectionCount == 0
    }
}

private struct ZeroAmountCBQXLSReader: ImportFramework.DocumentReader {
    let supportedFileExtensions: Set<String> = ["xls"]

    func read(
        request: ImportRequest,
        snapshot: SourceContentSnapshot,
        password: String?
    ) async throws -> RawDocument {
        let raw = try await LegacyXLSDocumentReader().read(
            request: request,
            snapshot: snapshot,
            password: password
        )
        return CBQXLSFixtureTestSupport.replacingCell(
            in: raw,
            sourceRow: 8,
            sourceColumn: 3,
            with: "0.00"
        )
    }
}
