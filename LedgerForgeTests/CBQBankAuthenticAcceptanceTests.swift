import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

/// External authentic corpus and independently extracted source facts only.
@MainActor
struct CBQBankAuthenticAcceptanceTests {
    private struct Oracle: Decodable { let carriers: [Carrier] }
    private struct Carrier: Decodable {
        let carrier: String
        let sha256: String
        let statementDate: String
        let periodStart: String
        let maskedAccount: String
        let maskedIBAN: String
        let openingBalance: String
        let closingBalance: String
        let rows: [Row]
    }
    private struct Row: Decodable {
        let postingDate: String
        let description: String
        let sourceTransactionDate: String
        let signedAmount: String
        let balance: String
        let sourcePage: Int
    }

    @Test(.globalRuntimeStateIsolation)
    func completeOriginalsPersistReplayAndReopen() async throws {
        let env = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: try #require(env["LEDGERFORGE_CBQ_BANK_ROOT"]))
        let attachment = URL(fileURLWithPath: try #require(env["LEDGERFORGE_CBQ_BANK_ATTACHMENT"]))
        let oracle = try JSONDecoder().decode(Oracle.self, from: Data(contentsOf:
            URL(fileURLWithPath: try #require(env["LEDGERFORGE_CBQ_BANK_ORACLE"]))))
        let password = try #require(env["LEDGERFORGE_CBQ_PASSWORD"])
        #expect(oracle.carriers.count == 19)
        #expect(oracle.carriers.reduce(0) { $0 + $1.rows.count } == 187)
        for inMemory in [true, false] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-CBQ-Authentic-\(UUID())")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let path = directory.appendingPathComponent("acceptance.sqlite").path
            let sqlite = inMemory ? nil : try SQLiteRepositoryProvider(path: path)
            let provider = sqlite.map { DatabaseProvider.verifiedSQLite($0, protectsGeneration: false) }
                ?? DatabaseProvider(inMemory: true)
            let workspace = "cbq-authentic-\(UUID())"
            let store = TransactionStore()
            let hydrator = makeHydrator(provider, workspace: workspace, store: store)
            let coordinator = DefaultImportPersistenceCoordinator(databaseProvider: provider,
                mapper: ImportPersistenceMapper(workspaceId: workspace, workspaceName: "CBQ authentic acceptance"))
            let credentials = InMemoryStatementPasswordCredentialStore(passwords:
                [Institution.cbq.statementPasswordCredentialScope: password])
            let engine = ImportEngine(
                importCoordinator: DefaultImportCoordinator(readerRegistry: DefaultReaderRegistry(),
                    passwordProvider: DefaultPasswordProvider(credentialStore: credentials,
                        supportedInstitutionCodes: [Institution.cbq.statementPasswordCredentialScope], challenge: { _ in nil })),
                importPersistenceCoordinator: coordinator,
                persistenceStateProvider: { provider.persistenceState },
                providerGenerationProvider: { provider.generationToken },
                forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) },
                rejectedAttemptHydration: {},
                developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(stateProvider: { nil })
            )
            var successful = 0
            var expectedKeys: [String: Int] = [:]
            let firstCarrier = try #require(oracle.carriers.first)
            let firstURL = firstCarrier.carrier.contains("::") ? attachment : root.appendingPathComponent(firstCarrier.carrier)
            let cancelled = try await engine.prepareImport(from: firstURL)
            engine.cancelPreparedImport(cancelled)
            #expect(try provider.accountRepo.accounts(workspaceId: workspace).isEmpty)
            #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspace).isEmpty)
            #expect(try provider.importSessionRepo.cbqSourceObservationSummaries(workspaceId: workspace).isEmpty)
            for carrier in oracle.carriers {
                let url = carrier.carrier.contains("::") ? attachment : root.appendingPathComponent(carrier.carrier)
                do {
                    let prepared = try await engine.prepareImport(from: url)
                    defer { engine.cancelPreparedImport(prepared) }
                    let bytesDigest = try prepared.sourceSnapshot.withBytes {
                        SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined()
                    }
                    #expect(bytesDigest == carrier.sha256)
                    #expect(prepared.detectedInstitution == .cbq)
                    #expect(prepared.validation.passed, "\(carrier.carrier): \(prepared.validation)")
                    let document = prepared.financialDocument
                    #expect(document.transactions.count == carrier.rows.count, "\(carrier.carrier)")
                    #expect(document.sourceStatementEvidence?.openingBalance?.amount == decimal(carrier.openingBalance))
                    #expect(document.sourceStatementEvidence?.closingBalance?.amount == decimal(carrier.closingBalance))
                    #expect(document.sourceStatementEvidence?.statementBoundaryDate == date(carrier.statementDate.replacingOccurrences(of: " ", with: "-")))
                    for (transaction, row) in zip(document.transactions, carrier.rows) {
                        #expect(transaction.statementDate == date(row.postingDate), "\(carrier.carrier)")
                        #expect(transaction.money.amount == decimal(row.signedAmount), "\(carrier.carrier)")
                        #expect(transaction.money.currency.code == "QAR")
                        #expect(transaction.runningBalanceMoney?.amount == decimal(row.balance))
                        #expect(compact(transaction.description) == compact(row.description), "\(carrier.carrier): narration")
                        #expect(transaction.sourceProvenance.first?.sourceTransactionDate == date(row.sourceTransactionDate))
                        #expect(transaction.sourceProvenance.first?.sourcePage == row.sourcePage)
                        #expect(transaction.sourceProvenance.first?.parserProfileID == CBQCurrentAccountPDFParser.monthlyProfileID)
                        #expect(transaction.sourceProvenance.first?.parserProfileVersion == "1")
                    }
                    guard prepared.validation.passed else { continue }
                    let committed = await engine.commitPreparedImport(prepared)
                    #expect(committed.persisted, "\(carrier.carrier): \(committed.errorMessage ?? "no error")")
                    #expect(committed.hydrationOutcome == .committedAndHydrated)
                    guard committed.persisted else { continue }
                    successful += 1
                    for row in carrier.rows { expectedKeys[oracleKey(row), default: 0] += 1 }
                    let count = try provider.transactionRepo.trustedTransactions(workspaceId: workspace).count
                    let replay = try await engine.prepareImport(from: url)
                    defer { engine.cancelPreparedImport(replay) }
                    let replayed = await engine.commitPreparedImport(replay)
                    #expect(replayed.previousImport != nil, "\(carrier.carrier): exact replay")
                    #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspace).count == count)
                } catch {
                    Issue.record("\(carrier.carrier), memory=\(inMemory): \(error)")
                }
            }
            #expect(successful == oracle.carriers.count)
            try verifySourceObservations(provider, workspace: workspace)
            #expect(store.transactions.count == 187)
            #expect(multiset(store.transactions.map(transactionKey)) == expectedKeys)
            sqlite?.database.close()
            if !inMemory {
                let reopened = try SQLiteRepositoryProvider(path: path)
                defer { reopened.database.close() }
                let reopenedProvider = DatabaseProvider.verifiedSQLite(reopened, protectsGeneration: false)
                let reopenedStore = TransactionStore()
                let reopenedHydrator = makeHydrator(reopenedProvider, workspace: workspace, store: reopenedStore)
                let hydrated = try reopenedHydrator.hydrateIfNeeded(forceRefresh: true)
                #expect(hydrated.didHydrate && hydrated.transactionCount == 187)
                #expect(multiset(reopenedStore.transactions.map(transactionKey)) == expectedKeys)
                try verifySourceObservations(reopenedProvider, workspace: workspace)
                #expect(reopenedStore.transactions.allSatisfy {
                    $0.sourceProvenance.contains { $0.parserProfileID == CBQCurrentAccountPDFParser.monthlyProfileID && $0.parserProfileVersion == "1" }
                })
            }
        }
    }

    private func verifySourceObservations(_ provider: DatabaseProvider, workspace: String) throws {
        let observations = try provider.importSessionRepo.cbqSourceObservationSummaries(workspaceId: workspace)
        #expect(observations.count == 19)
        #expect(observations.reduce(0) { $0 + $1.sourceRowCount } == 187)
        #expect(observations.reduce(0) { $0 + $1.importedTransactionCount } == 187)
        // These monthly sources do not overlap: every row was imported,
        // and no row merely represents a previously accepted transaction.
        #expect(observations.reduce(0) { $0 + $1.representedTransactionCount } == 0)
        #expect(observations.reduce(0) { $0 + $1.transactionObservationCount } == 187)
    }

    private func makeHydrator(_ provider: DatabaseProvider, workspace: String, store: TransactionStore) -> RepositoryStoreHydrator {
        RepositoryStoreHydrator(accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo, cardRepo: provider.cardRepo,
            accountStore: AccountStore(), transactionStore: store, categoryStore: CategoryStore(), cardStore: CardStore(),
            importSessionStore: ImportSessionStore(), importAttemptStore: ImportAttemptStore(),
            workspaceId: workspace, persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken, participatesInLifecycleGate: false)
    }
    private func compact(_ value: String) -> String { value.filter { !$0.isWhitespace } }
    private func decimal(_ value: String) -> Decimal { Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))! }
    private func date(_ value: String) -> StatementDate {
        let p = value.split(separator: "-")
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return try! StatementDate(year: 2000 + Int(p[2])!, month: months.firstIndex(of: p[1].lowercased())! + 1, day: Int(p[0])!)
    }
    private func oracleKey(_ row: Row) -> String {
        [date(row.postingDate).canonical, decimal(row.signedAmount).description, decimal(row.balance).description,
         compact(row.description), date(row.sourceTransactionDate).canonical].joined(separator: "|")
    }
    private func transactionKey(_ row: Transaction) -> String {
        [row.statementDate?.canonical ?? "", row.money.amount.description, row.runningBalanceMoney?.amount.description ?? "",
         compact(row.description), row.repositoryPreferredSourceTransactionDate?.canonical ?? ""].joined(separator: "|")
    }
    private func multiset(_ values: [String]) -> [String: Int] {
        values.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }
}
