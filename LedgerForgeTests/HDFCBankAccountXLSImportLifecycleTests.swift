import Foundation
import Testing
@testable import LedgerForge

@Suite(.serialized)
@MainActor
struct HDFCBankAccountXLSImportLifecycleTests {
    private let workspaceID = "workspace-hdfc-xls-v1"

    @Test(.globalRuntimeStateIsolation)
    func ordinaryPreparationIsWriteFreeConfirmationPersistsAndExactBytesReject() async throws {
        let context = try HDFCProviderContext(.inMemory)
        defer { context.cleanup() }
        let stores = HDFCRuntimeStores()
        let engine = makeEngine(provider: context.provider, stores: stores)
        let source = FixtureLocator.hdfcSyntheticXLS(
            HDFCXLSFixtureTestSupport.annualFixture
        )

        let prepared = try await engine.prepareImport(from: source)
        #expect(prepared.detectedInstitution == .hdfc)
        #expect(prepared.detectedDocumentType == .bankAccount)
        #expect(prepared.parserName == "HDFC Bank Account XLS")
        #expect(prepared.transactionCount == 4)
        #expect(prepared.validation.passed)
        #expect(
            prepared.fingerprintSet.duplicateAuthority?.algorithm
                == SourceContentSnapshot.algorithm
        )
        #expect(try context.provider.workspaceRepo.workspace(id: workspaceID) == nil)
        #expect(try context.provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
        #expect(
            try context.provider.transactionRepo.trustedTransactions(
                workspaceId: workspaceID
            ).isEmpty
        )
        #expect(
            try context.provider.importSessionRepo.importAttempts(
                workspaceId: workspaceID
            ).isEmpty
        )

        let accepted = await engine.commitPreparedImport(
            prepared,
            accountChoice: .createNewAccount
        )
        #expect(accepted.succeeded)
        #expect(stores.accounts.accounts.count == 1)
        #expect(stores.transactions.transactions.count == 4)

        let acceptedCounts = try graphCounts(context.provider)
        let duplicatePrepared = try await engine.prepareImport(from: source)
        #expect(
            duplicatePrepared.advisoryPreviousImport?.importSessionId
                == accepted.importSessionId
        )
        let duplicate = await engine.commitPreparedImport(duplicatePrepared)

        #expect(!duplicate.succeeded)
        #expect(duplicate.previousImport?.importSessionId == accepted.importSessionId)
        #expect(try graphCounts(context.provider) == acceptedCounts)
        let attempts = try context.provider.importSessionRepo.importAttempts(
            workspaceId: workspaceID
        )
        #expect(attempts.count == 2)
        #expect(attempts.filter {
            $0.outcomeCode == ImportAttemptOutcome.exactStatementDuplicate.rawValue
        }.count == 1)
    }

    @Test(.globalRuntimeStateIsolation)
    func inMemoryAndSQLiteCommitTheSameTwoAccountGraph() async throws {
        let memory = try await acceptedGraph(for: .inMemory)
        let sqlite = try await acceptedGraph(for: .sqlite)
        #expect(memory == sqlite)
        #expect(memory.accountCount == 2)
        #expect(memory.identifierCount == 2)
        #expect(memory.transactionCount == 8)
        #expect(memory.importSessionCount == 2)
        #expect(memory.successfulAttemptCount == 2)
        #expect(memory.valueDateCount == 8)
        #expect(memory.referencedTransactionCount > 0)
    }

    @Test(.globalRuntimeStateIsolation)
    func sqliteCloseReopenReconstructsAndHydratesTheCompleteGraph() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-HDFC-XLS-Relaunch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appendingPathComponent("hdfc.sqlite")
        let initialSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        let initialProvider = DatabaseProvider.verifiedSQLite(
            initialSQLite,
            protectsGeneration: false
        )
        let initialStores = HDFCRuntimeStores()
        let engine = makeEngine(provider: initialProvider, stores: initialStores)
        let results = try await importBoth(using: engine)
        let allImportsSucceeded = results.allSatisfy { $0.succeeded }
        #expect(allImportsSucceeded)
        #expect(initialStores.accounts.accounts.count == 2)
        #expect(initialStores.transactions.transactions.count == 8)
        initialSQLite.database.close()

        let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        defer { reopenedSQLite.database.close() }
        let reopenedProvider = DatabaseProvider.verifiedSQLite(
            reopenedSQLite,
            protectsGeneration: false
        )
        let reopenedStores = HDFCRuntimeStores()
        let hydration = try reopenedStores.hydrator(
            provider: reopenedProvider,
            workspaceID: workspaceID
        ).hydrateIfNeeded()

        #expect(hydration.didHydrate)
        #expect(hydration.accountCount == 2)
        #expect(hydration.transactionCount == 8)
        #expect(hydration.importSessionCount == 2)
        #expect(hydration.importAttemptCount == 2)
        #expect(reopenedStores.accounts.accounts.count == 2)
        #expect(reopenedStores.transactions.transactions.count == 8)
        #expect(reopenedStores.sessions.importSessions.count == 2)
        #expect(reopenedStores.transactions.transactions.allSatisfy {
            $0.valueDate != nil
                && $0.sourceProvenance.first?.parserProfileID
                    == HDFCBankAccountXLSParser.profileID
        })
        #expect(reopenedStores.transactions.transactions.contains {
            $0.reference != nil
        })
        #expect(try graphSnapshot(reopenedProvider).accountCount == 2)
    }

    @Test(.globalRuntimeStateIsolation)
    func malformedOrdinaryPreparationLeavesZeroAcceptedResidue() async throws {
        let context = try HDFCProviderContext(.sqlite)
        defer { context.cleanup() }
        let stores = HDFCRuntimeStores()
        let coordinator = DefaultImportCoordinator(
            readerRegistry: DefaultReaderRegistry(readers: [MalformedHDFCXLSReader()])
        )
        let engine = makeEngine(
            provider: context.provider,
            stores: stores,
            coordinator: coordinator
        )

        await #expect(throws: HDFCBankAccountXLSParserError.self) {
            try await engine.prepareImport(from: FixtureLocator.hdfcSyntheticXLS(
                HDFCXLSFixtureTestSupport.annualFixture
            ))
        }
        #expect(try context.provider.workspaceRepo.workspace(id: workspaceID) == nil)
        #expect(try context.provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
        #expect(
            try context.provider.transactionRepo.trustedTransactions(
                workspaceId: workspaceID
            ).isEmpty
        )
        #expect(
            try context.provider.importSessionRepo.importAttempts(
                workspaceId: workspaceID
            ).isEmpty
        )
        #expect(stores.accounts.accounts.isEmpty)
        #expect(stores.transactions.transactions.isEmpty)
    }

    private func acceptedGraph(
        for kind: HDFCProviderKind
    ) async throws -> HDFCGraphSnapshot {
        let context = try HDFCProviderContext(kind)
        defer { context.cleanup() }
        let stores = HDFCRuntimeStores()
        let engine = makeEngine(provider: context.provider, stores: stores)
        let results = try await importBoth(using: engine)
        let allImportsSucceeded = results.allSatisfy { $0.succeeded }
        let accountCount = Set(results.compactMap { $0.accountId }).count
        #expect(allImportsSucceeded)
        #expect(accountCount == 2)
        return try graphSnapshot(context.provider)
    }

    private func importBoth(using engine: ImportEngine) async throws -> [ImportEngineResult] {
        var results: [ImportEngineResult] = []
        for fixture in [
            HDFCXLSFixtureTestSupport.annualFixture,
            HDFCXLSFixtureTestSupport.recentFixture
        ] {
            let prepared = try await engine.prepareImport(
                from: FixtureLocator.hdfcSyntheticXLS(fixture)
            )
            results.append(await engine.commitPreparedImport(
                prepared,
                accountChoice: .createNewAccount
            ))
        }
        return results
    }

    private func makeEngine(
        provider: DatabaseProvider,
        stores: HDFCRuntimeStores,
        coordinator: (any ImportFramework.ImportCoordinator)? = nil
    ) -> ImportEngine {
        let persistence = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(
                workspaceId: workspaceID,
                workspaceName: "HDFC XLS v1 Tests"
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
            forcedHydration: {
                try hydrator.hydrateIfNeeded(forceRefresh: true)
            },
            rejectedAttemptHydration: {
                try hydrator.hydrateImportAttempts()
            },
            developmentProfileAcknowledgementGate:
                DevelopmentProfileAcknowledgementGate(stateProvider: { nil })
        )
    }

    private func graphCounts(
        _ provider: DatabaseProvider
    ) throws -> HDFCAcceptedGraphCounts {
        let accounts = try provider.accountRepo.accounts(workspaceId: workspaceID)
        return HDFCAcceptedGraphCounts(
            accountCount: accounts.count,
            transactionCount: try provider.transactionRepo.trustedTransactions(
                workspaceId: workspaceID
            ).count,
            identifierCount: try accounts.flatMap {
                try provider.accountRepo.identifiers(
                    accountId: $0.id,
                    workspaceId: workspaceID
                )
            }.count
        )
    }

    private func graphSnapshot(
        _ provider: DatabaseProvider
    ) throws -> HDFCGraphSnapshot {
        let accounts = try provider.accountRepo.accounts(workspaceId: workspaceID)
        let identifiers = try accounts.flatMap {
            try provider.accountRepo.identifiers(
                accountId: $0.id,
                workspaceId: workspaceID
            )
        }
        let transactions = try provider.transactionRepo.trustedTransactions(
            workspaceId: workspaceID
        )
        let attempts = try provider.importSessionRepo.importAttempts(
            workspaceId: workspaceID
        )
        return HDFCGraphSnapshot(
            accountCount: accounts.count,
            identifierCount: identifiers.count,
            transactionCount: transactions.count,
            importSessionCount: Set(attempts.compactMap(\.importSessionId)).count,
            successfulAttemptCount: attempts.filter {
                $0.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue
            }.count,
            valueDateCount: transactions.compactMap(\.valueDateISO).count,
            referencedTransactionCount: transactions.compactMap(\.reference).count,
            profileCount: Set(transactions.flatMap(\.rawRows).compactMap {
                $0.parserProfileId
            }).count,
            currencyCount: Set(accounts.map(\.nativeCurrency)).count,
            identifierSchemeCount: Set(identifiers.map(\.scheme)).count
        )
    }
}

private enum HDFCProviderKind {
    case inMemory
    case sqlite
}

@MainActor
private final class HDFCProviderContext {
    let provider: DatabaseProvider
    private let sqlite: SQLiteRepositoryProvider?
    private let directory: URL?

    init(_ kind: HDFCProviderKind) throws {
        switch kind {
        case .inMemory:
            provider = DatabaseProvider(inMemory: true)
            sqlite = nil
            directory = nil
        case .sqlite:
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("LedgerForge-HDFC-XLS-\(UUID().uuidString)")
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let sqlite = try SQLiteRepositoryProvider(
                path: directory.appendingPathComponent("hdfc.sqlite").path
            )
            provider = .verifiedSQLite(sqlite, protectsGeneration: false)
            self.sqlite = sqlite
            self.directory = directory
        }
    }

    func cleanup() {
        sqlite?.database.close()
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

@MainActor
private final class HDFCRuntimeStores {
    let accounts = AccountStore()
    let transactions = TransactionStore()
    let sessions = ImportSessionStore()
    let attempts = ImportAttemptStore()
    let categories = CategoryStore()

    func hydrator(
        provider: DatabaseProvider,
        workspaceID: String
    ) -> RepositoryStoreHydrator {
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

private struct HDFCAcceptedGraphCounts: Equatable {
    let accountCount: Int
    let transactionCount: Int
    let identifierCount: Int
}

private struct HDFCGraphSnapshot: Equatable {
    let accountCount: Int
    let identifierCount: Int
    let transactionCount: Int
    let importSessionCount: Int
    let successfulAttemptCount: Int
    let valueDateCount: Int
    let referencedTransactionCount: Int
    let profileCount: Int
    let currencyCount: Int
    let identifierSchemeCount: Int
}

private struct MalformedHDFCXLSReader: ImportFramework.DocumentReader {
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
        var changed = HDFCXLSFixtureTestSupport.replacingCell(
            in: raw,
            sourceRow: 23,
            sourceColumn: 5,
            with: "1.00"
        )
        changed = HDFCXLSFixtureTestSupport.replacingCell(
            in: changed,
            sourceRow: 23,
            sourceColumn: 6,
            with: "1.00"
        )
        return changed
    }
}
