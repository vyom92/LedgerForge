import CryptoKit
import Foundation
import Testing
@testable import LedgerForge

/// Mixed-format queue acceptance over unchanged registered originals and their
/// independent external oracles. This test creates no statement or financial DTO.
@Suite(.serialized)
@MainActor
struct ImportCentreAuthenticBatchTests {
    private enum ProviderKind: String, CaseIterable {
        case inMemory = "in-memory"
        case sqlite
    }

    private enum TestError: Error {
        case invalidOracle
        case sourceOutsideApprovedRoot
        case unexpectedIdentityReview
        case queueRejected
        case timedOut
    }

    private struct AxisOracle: Decodable {
        let carriers: [AxisCarrier]
    }

    private struct AxisCarrier: Decodable {
        let sourceSha256: String
        let sourceSize: Int
        let format: String
        let logicalStatementId: String
        let rowCount: Int
    }

    private struct HDFCOracle: Decodable {
        let carriers: HDFCCarriers
    }

    private struct HDFCCarriers: Decodable {
        let xls: [HDFCCarrier]
    }

    private struct HDFCCarrier: Decodable {
        let carrier: String
        let sha256: String
        let account: String
        let periodStart: String
        let periodEnd: String
        let currency: String
        let rows: [HDFCRow]

        var logicalStatementID: String {
            ["hdfc", account, periodStart, periodEnd, currency].joined(separator: "|")
        }
    }

    private struct HDFCRow: Decodable {}

    private struct SourceExpectation {
        let url: URL
        let sha256: String
        let byteCount: Int
        let format: FileFormat
        let logicalStatementID: String
        let rowCount: Int
        let institution: Institution
    }

    private struct GraphCounts: Equatable {
        let accounts: Int
        let transactions: Int
        let importSessions: Int
    }

    private struct CampaignEvidence: Equatable {
        let graph: GraphCounts
        let committedCount: Int
        let exactDuplicateCount: Int
        let terminalCount: Int
        let isComplete: Bool
    }

    @Test(.globalRuntimeStateIsolation)
    func mixedOriginalCSVAndXLSQueuePersistsSeriallyAndRejectsExactReplay() async throws {
        let expectations = try loadSourceExpectations()
        #expect(expectations.count == 2)
        #expect(Set(expectations.map(\.logicalStatementID)).count == 2)
        let originalDigests = try expectations.map { try sourceDigest($0.url) }

        var campaignEvidence: [CampaignEvidence] = []
        for providerKind in ProviderKind.allCases {
            campaignEvidence.append(
                try await runCampaign(providerKind: providerKind, expectations: expectations)
            )
            #expect(try expectations.map { try sourceDigest($0.url) } == originalDigests)
        }
        #expect(campaignEvidence.count == 2)
        #expect(campaignEvidence.first == campaignEvidence.last)
    }

    private func runCampaign(
        providerKind: ProviderKind,
        expectations: [SourceExpectation]
    ) async throws -> CampaignEvidence {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-ImportCentre-Batch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let databaseURL = folder.appendingPathComponent("batch.sqlite")
        let sqlite = providerKind == .sqlite
            ? try SQLiteRepositoryProvider(path: databaseURL.path)
            : nil
        defer { sqlite?.database.close() }
        let provider = sqlite.map {
            DatabaseProvider.verifiedSQLite($0, protectsGeneration: false)
        } ?? DatabaseProvider(inMemory: true)
        let workspace = "import-centre-batch-\(providerKind.rawValue)-\(UUID().uuidString.lowercased())"
        let stores = BatchRuntimeStores()
        let hydrator = makeHydrator(provider: provider, workspace: workspace, stores: stores)
        let password = try #require(
            ProcessInfo.processInfo.environment["LEDGERFORGE_PRIVATE_HDFC_PASSWORD"]
        )
        let credentialStore = InMemoryStatementPasswordCredentialStore(
            passwords: [Institution.hdfc.statementPasswordCredentialScope: password]
        )
        let engine = ImportEngine(
            importCoordinator: DefaultImportCoordinator(
                readerRegistry: DefaultReaderRegistry(),
                passwordProvider: DefaultPasswordProvider(
                    credentialStore: credentialStore,
                    supportedInstitutionCodes: [Institution.hdfc.statementPasswordCredentialScope],
                    challenge: { _ in nil }
                )
            ),
            importPersistenceCoordinator: DefaultImportPersistenceCoordinator(
                databaseProvider: provider,
                mapper: ImportPersistenceMapper(
                    workspaceId: workspace,
                    workspaceName: "Import Centre authentic batch"
                )
            ),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { try hydrator.hydrateIfNeeded(forceRefresh: true) },
            rejectedAttemptHydration: { try hydrator.hydrateImportAttempts() },
            developmentProfileAcknowledgementGate: DevelopmentProfileAcknowledgementGate(
                stateProvider: { nil }
            )
        )
        let coordinator = ImportCentreCoordinator<PreparedImport>.production(using: engine)
        let ownerID = UUID()
        coordinator.attachPresentationOwner(ownerID)
        defer { coordinator.detachPresentationOwner(ownerID) }

        let queueExpectations = [expectations[0], expectations[1], expectations[0]]
        guard coordinator.enqueueSources(queueExpectations.map(\.url)) else {
            throw TestError.queueRejected
        }

        var acceptedAccountIDs: [String] = []
        var acceptedImportSessionIDs: [String] = []
        for position in 0..<2 {
            let expected = queueExpectations[position]
            try await waitUntil {
                coordinator.currentItem?.queuePosition == position
                    && coordinator.currentItem?.phase == .awaitingConfirmation
            }
            let item = try #require(coordinator.currentItem)
            let preparation = try #require(item.preparation)
            try verify(preparation: preparation, expected: expected)

            if position == 0 {
                #expect(coordinator.items[1].phase == .pending)
                #expect(coordinator.items[2].phase == .pending)
                #expect(try graphCounts(
                    provider: provider,
                    hydrator: hydrator,
                    workspace: workspace
                ) == GraphCounts(accounts: 0, transactions: 0, importSessions: 0))
                #expect(stores.accounts.accounts.isEmpty)
                #expect(stores.transactions.transactions.isEmpty)
                #expect(stores.sessions.importSessions.isEmpty)
            }

            coordinator.updateAccountChoice(try accountChoice(for: item.identityReview))
            await coordinator.confirmCurrent(expectedPreparationID: preparation.id)

            let completed = try #require(coordinator.items.first { $0.id == item.id })
            #expect(completed.phase == .completed)
            #expect(completed.completionDisposition == .committed)
            #expect(completed.outcome?.persisted == true)
            acceptedAccountIDs.append(try #require(completed.outcome?.accountId))
            acceptedImportSessionIDs.append(try #require(completed.outcome?.importSessionId))

            if position == 0 {
                try await waitUntil {
                    coordinator.currentItem?.queuePosition == 1
                        && coordinator.currentItem?.phase == .awaitingConfirmation
                }
                #expect(coordinator.items[2].phase == .pending)
                #expect(try graphCounts(
                    provider: provider,
                    hydrator: hydrator,
                    workspace: workspace
                ) == GraphCounts(
                    accounts: 1,
                    transactions: expectations[0].rowCount,
                    importSessions: 1
                ))
                #expect(stores.accounts.accounts.count == 1)
                #expect(stores.transactions.transactions.count == expectations[0].rowCount)
                #expect(stores.sessions.importSessions.count == 1)
            }
        }

        #expect(Set(acceptedAccountIDs).count == 2)
        #expect(Set(acceptedImportSessionIDs).count == 2)
        let expectedTransactionCount = expectations.reduce(0) { $0 + $1.rowCount }
        let stableGraph = try graphCounts(provider: provider, hydrator: hydrator, workspace: workspace)
        #expect(stableGraph == GraphCounts(
            accounts: 2,
            transactions: expectedTransactionCount,
            importSessions: 2
        ))

        let replayExpected = queueExpectations[2]
        try await waitUntil {
            coordinator.currentItem?.queuePosition == 2
                && coordinator.currentItem?.phase == .awaitingConfirmation
        }
        let replayItem = try #require(coordinator.currentItem)
        let replayPreparation = try #require(replayItem.preparation)
        try verify(preparation: replayPreparation, expected: replayExpected)
        await coordinator.confirmCurrent(expectedPreparationID: replayPreparation.id)

        #expect(coordinator.currentItem?.id == replayItem.id)
        #expect(coordinator.currentItem?.completionDisposition == .exactDuplicate)
        #expect(coordinator.currentItem?.outcome?.persisted == false)
        #expect(coordinator.currentItem?.outcome?.isPreviouslyImported == true)
        #expect(try graphCounts(provider: provider, hydrator: hydrator, workspace: workspace) == stableGraph)
        #expect(coordinator.continueAfterCurrent())
        #expect(coordinator.batchSummary.committedCount == 2)
        #expect(coordinator.batchSummary.exactDuplicateCount == 1)
        #expect(coordinator.batchSummary.isComplete)

        let hydration = try hydrator.hydrateIfNeeded(forceRefresh: true)
        #expect(hydration.accountCount == 2)
        #expect(hydration.transactionCount == expectedTransactionCount)
        #expect(hydration.importSessionCount == 2)
        #expect(stores.accounts.accounts.count == 2)
        #expect(stores.transactions.transactions.count == expectedTransactionCount)
        #expect(stores.sessions.importSessions.count == 2)

        let evidence = CampaignEvidence(
            graph: stableGraph,
            committedCount: coordinator.batchSummary.committedCount,
            exactDuplicateCount: coordinator.batchSummary.exactDuplicateCount,
            terminalCount: coordinator.terminalItems.count,
            isComplete: coordinator.batchSummary.isComplete
        )

        guard let sqlite else { return evidence }
        try sqlite.database.checkpointAndClose()
        let reopenedSQLite = try SQLiteRepositoryProvider(path: databaseURL.path)
        defer { reopenedSQLite.database.close() }
        let reopenedProvider = DatabaseProvider.verifiedSQLite(
            reopenedSQLite,
            protectsGeneration: false
        )
        let reopenedStores = BatchRuntimeStores()
        let reopenedHydrator = makeHydrator(
            provider: reopenedProvider,
            workspace: workspace,
            stores: reopenedStores
        )
        let reopenedHydration = try reopenedHydrator.hydrateIfNeeded(forceRefresh: true)
        #expect(reopenedHydration.accountCount == 2)
        #expect(reopenedHydration.transactionCount == expectedTransactionCount)
        #expect(reopenedHydration.importSessionCount == 2)
        #expect(reopenedStores.accounts.accounts.count == 2)
        #expect(reopenedStores.transactions.transactions.count == expectedTransactionCount)
        #expect(reopenedStores.sessions.importSessions.count == 2)
        try reopenedSQLite.database.checkpointAndClose()
        return evidence
    }

    private func verify(
        preparation: PreparedImport,
        expected: SourceExpectation
    ) throws {
        #expect(try preparation.sourceSnapshot.withBytes(sourceDigest) == expected.sha256)
        #expect(preparation.sourceSnapshot.byteCount == expected.byteCount)
        #expect(preparation.detectedInstitution == expected.institution)
        #expect(preparation.detectedDocumentType == .bankAccount)
        #expect(preparation.financialDocument.metadata.fileFormat == expected.format)
        #expect(preparation.validation.passed)
        #expect(preparation.financialDocument.transactions.count == expected.rowCount)
    }

    private func accountChoice(for review: ImportIdentityReview) throws -> ImportAccountChoice {
        switch review {
        case .matchedExisting(let accountID):
            return .useExistingAccount(accountId: accountID)
        case .choiceRequired:
            return .createNewAccount
        case .unavailable, .liabilityAccountChoiceRequired, .ambiguous, .conflict,
                .cardChoiceRequired:
            throw TestError.unexpectedIdentityReview
        }
    }

    private func graphCounts(
        provider: DatabaseProvider,
        hydrator: RepositoryStoreHydrator,
        workspace: String
    ) throws -> GraphCounts {
        let staged = try hydrator.stageHydration()
        return GraphCounts(
            accounts: try provider.accountRepo.accounts(workspaceId: workspace).count,
            transactions: try provider.transactionRepo.trustedTransactions(workspaceId: workspace).count,
            importSessions: staged.importSessions.count
        )
    }

    private func makeHydrator(
        provider: DatabaseProvider,
        workspace: String,
        stores: BatchRuntimeStores
    ) -> RepositoryStoreHydrator {
        RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo,
            salaryRepo: provider.salaryRepo,
            fundingPlanRepo: provider.fundingPlanRepo,
            accountStore: stores.accounts,
            transactionStore: stores.transactions,
            categoryStore: stores.categories,
            cardStore: stores.cards,
            salaryStore: stores.salaries,
            fundingPlanStore: stores.fundingPlans,
            importSessionStore: stores.sessions,
            importAttemptStore: stores.attempts,
            workspaceId: workspace,
            persistenceState: provider.persistenceState,
            providerGeneration: provider.generationToken,
            categoryReconciliationGate: nil,
            participatesInLifecycleGate: false
        )
    }

    private func loadSourceExpectations() throws -> [SourceExpectation] {
        let environment = ProcessInfo.processInfo.environment
        let approvedRoot = URL(
            fileURLWithPath: "/Users/vyom/Documents/Ledger Forge",
            isDirectory: true
        )
        let axisURL = try AuthenticSourceTestSupport.axisBankCSV()
        try requireApprovedOriginal(axisURL, root: approvedRoot)
        let axisData = try Data(contentsOf: axisURL, options: .mappedIfSafe)
        let axisDigest = sourceDigest(axisData)
        let axisDecoder = JSONDecoder()
        axisDecoder.keyDecodingStrategy = .convertFromSnakeCase
        let axisOracle = try axisDecoder.decode(
            AxisOracle.self,
            from: Data(contentsOf: URL(fileURLWithPath: try #require(
                environment["LEDGERFORGE_AXIS_BANK_ORACLE"]
            )))
        )
        let axisMatches = axisOracle.carriers.filter { $0.sourceSha256 == axisDigest }
        guard axisMatches.count == 1,
              let axisCarrier = axisMatches.first,
              axisCarrier.sourceSize == axisData.count,
              axisCarrier.format.lowercased() == "csv" else {
            throw TestError.invalidOracle
        }

        let hdfcRoot = URL(
            fileURLWithPath: try #require(resolveHDFCOriginalsRoot(environment)),
            isDirectory: true
        )
        let hdfcOracle = try JSONDecoder().decode(
            HDFCOracle.self,
            from: Data(contentsOf: URL(fileURLWithPath: try #require(
                environment["LEDGERFORGE_PRIVATE_HDFC_ORACLE_FILE"]
            )))
        )
        let hdfcCarrier = try #require(
            hdfcOracle.carriers.xls.sorted { $0.sha256 < $1.sha256 }.first
        )
        let hdfcURL = hdfcRoot.appendingPathComponent(hdfcCarrier.carrier)
        try requireApprovedOriginal(hdfcURL, root: approvedRoot)
        let hdfcData = try Data(contentsOf: hdfcURL, options: .mappedIfSafe)
        guard sourceDigest(hdfcData) == hdfcCarrier.sha256 else {
            throw TestError.invalidOracle
        }

        return [
            SourceExpectation(
                url: axisURL,
                sha256: axisCarrier.sourceSha256,
                byteCount: axisCarrier.sourceSize,
                format: .csv,
                logicalStatementID: "axis|\(axisCarrier.logicalStatementId)",
                rowCount: axisCarrier.rowCount,
                institution: .axis
            ),
            SourceExpectation(
                url: hdfcURL,
                sha256: hdfcCarrier.sha256,
                byteCount: hdfcData.count,
                format: .xls,
                logicalStatementID: hdfcCarrier.logicalStatementID,
                rowCount: hdfcCarrier.rows.count,
                institution: .hdfc
            )
        ]
    }

    private func requireApprovedOriginal(_ sourceURL: URL, root: URL) throws {
        let sourcePath = sourceURL.resolvingSymlinksInPath().standardizedFileURL.path
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        guard sourcePath.hasPrefix(rootPath + "/") else {
            throw TestError.sourceOutsideApprovedRoot
        }
    }

    private func resolveHDFCOriginalsRoot(_ environment: [String: String]) -> String? {
        if let root = environment["LEDGERFORGE_PRIVATE_HDFC_ORIGINALS_ROOT"], !root.isEmpty {
            return root
        }
        guard let pointer = environment["LEDGERFORGE_PRIVATE_HDFC_ORIGINALS_FILE"],
              let root = try? String(contentsOfFile: pointer, encoding: .utf8) else {
            return nil
        }
        return root.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sourceDigest(_ url: URL) throws -> String {
        sourceDigest(try Data(contentsOf: url, options: .mappedIfSafe))
    }

    private func sourceDigest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func waitUntil(
        timeoutIterations: Int = 4_000,
        _ condition: () -> Bool
    ) async throws {
        for _ in 0..<timeoutIterations {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw TestError.timedOut
    }
}

@MainActor
private final class BatchRuntimeStores {
    let accounts = AccountStore()
    let transactions = TransactionStore()
    let categories = CategoryStore()
    let cards = CardStore()
    let salaries = SalaryStore()
    let fundingPlans = FundingPlanStore()
    let sessions = ImportSessionStore()
    let attempts = ImportAttemptStore()
}
