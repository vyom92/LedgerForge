import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct ReviewedPartialImportTests {
    private let workspaceID = "partial-overlap-workspace"

    @Test(.globalRuntimeStateIsolation)
    func approvedOraclePairCommitsOneUniqueSuffixWithProviderParity() async throws {
        try await verifyApprovedPair(provider: DatabaseProvider(inMemory: true))

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-PartialOverlap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("partial.sqlite").path
        )
        defer { sqlite.database.close() }
        try await verifyApprovedPair(
            provider: .verifiedSQLite(sqlite, protectsGeneration: false)
        )
    }

    @Test func reviewedPlanDigestIsDeterministicAndBindsEveryRow() async throws {
        let provider = DatabaseProvider(inMemory: true)
        let context = try await preparedPair(provider: provider)
        let firstReview = try context.coordinator.reviewPartialImport(
            financialDocument: context.second.financialDocument,
            importSession: context.second.importSession,
            validation: context.second.validation,
            fingerprint: context.second.fingerprint,
            accountChoice: nil,
            providerGeneration: provider.generationToken
        )
        let firstPlan = try eligiblePlan(firstReview)
        let rebuilt = ReviewedPartialImportPlanDTO(
            id: firstPlan.id,
            basePlan: firstPlan.basePlan,
            existingAccountId: firstPlan.existingAccountId,
            rows: firstPlan.rows,
            sourceRowCount: firstPlan.sourceRowCount,
            recognizedCount: firstPlan.recognizedCount,
            importedCount: firstPlan.importedCount,
            blockedCount: firstPlan.blockedCount
        )
        #expect(firstPlan.digestAlgorithm == "ledgerforge.partial-import-plan.sha256.v1")
        #expect(firstPlan.digest == rebuilt.digest)
        #expect(firstPlan.hasValidDigest())

        var changedRows = firstPlan.rows
        let changed = changedRows[changedRows.count - 1]
        changedRows[changedRows.count - 1] = ReviewedPartialImportRowDTO(
            normalizedRowId: changed.normalizedRowId,
            sourceOrdinal: changed.sourceOrdinal,
            normalizedRecordDigest: changed.normalizedRecordDigest,
            statementDateISO: changed.statementDateISO,
            financialDateRole: changed.financialDateRole,
            timezoneEvidence: changed.timezoneEvidence,
            nativeCurrency: changed.nativeCurrency,
            amountMinor: changed.amountMinor + 1,
            amountDecimal: changed.amountDecimal,
            direction: changed.direction,
            runningBalanceMinor: changed.runningBalanceMinor,
            eventAlgorithm: changed.eventAlgorithm,
            eventDigest: changed.eventDigest,
            disposition: changed.disposition,
            expectedTransactionId: changed.expectedTransactionId,
            expectedEventIdentityId: changed.expectedEventIdentityId
        )
        let tampered = ReviewedPartialImportPlanDTO(
            id: firstPlan.id,
            basePlan: firstPlan.basePlan,
            existingAccountId: firstPlan.existingAccountId,
            rows: changedRows,
            sourceRowCount: firstPlan.sourceRowCount,
            recognizedCount: firstPlan.recognizedCount,
            importedCount: firstPlan.importedCount,
            blockedCount: firstPlan.blockedCount,
            digest: firstPlan.digest
        )
        #expect(!tampered.hasValidDigest())
        #expect(provider.confirmedImportRepo.commitReviewedPartialImport(tampered) == .reviewedPartialPlanStale)
    }

    private func verifyApprovedPair(provider: DatabaseProvider) async throws {
        let context = try await preparedPair(provider: provider)
        let review = try context.coordinator.reviewPartialImport(
            financialDocument: context.second.financialDocument,
            importSession: context.second.importSession,
            validation: context.second.validation,
            fingerprint: context.second.fingerprint,
            accountChoice: nil,
            providerGeneration: provider.generationToken
        )
        let plan = try eligiblePlan(review)
        #expect(plan.sourceRowCount == 4)
        #expect(plan.recognizedCount == 3)
        #expect(plan.importedCount == 1)
        #expect(plan.blockedCount == 0)
        #expect(plan.rows.prefix(3).allSatisfy { $0.disposition == .recognizedExisting })
        #expect(plan.rows.last?.disposition == .importedUnique)

        let result = try context.coordinator.persistReviewedPartialImport(plan)
        #expect(result.persisted)
        #expect(result.isPartialImport)
        #expect(result.transactionCount == 1)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 5)
        let sessionID = try #require(result.importSessionId)
        let loadedSummary = try provider.importSessionRepo.partialImportSummary(importSessionId: sessionID)
        let summary = try #require(loadedSummary)
        let dispositions = try provider.importSessionRepo.incomingRowDispositions(importSessionId: sessionID)
        #expect(summary.sourceRowCount == 4)
        #expect(summary.importedTransactionCount == 1)
        #expect(summary.recognizedExistingRowCount == 3)
        #expect(dispositions.count == 4)
        #expect(dispositions.filter { $0.dispositionCode == "recognized_existing" }.count == 3)
        #expect(dispositions.filter { $0.dispositionCode == "imported_unique" }.count == 1)

        let exactDuplicate = try context.coordinator.priorImportedStatement(
            fingerprint: context.second.fingerprint
        )
        #expect(exactDuplicate?.importSessionId == sessionID)
        #expect(provider.confirmedImportRepo.commitReviewedPartialImport(plan) == .reviewedPartialPlanStale)

        let accountStore = AccountStore()
        let transactionStore = TransactionStore()
        let sessionStore = ImportSessionStore()
        let attemptStore = ImportAttemptStore()
        let hydration = try RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            accountStore: accountStore,
            transactionStore: transactionStore,
            importSessionStore: sessionStore,
            importAttemptStore: attemptStore,
            workspaceId: workspaceID,
            persistenceState: provider.persistenceState,
            participatesInLifecycleGate: false
        ).hydrateIfNeeded(forceRefresh: true)
        #expect(hydration.transactionCount == 5)
        #expect(sessionStore.importSessions.count == 2)
        let partialSession = try #require(sessionStore.importSessions.first { $0.id == sessionID })
        #expect(partialSession.partialImportSummary?.recognizedExistingRowCount == 3)
        #expect(partialSession.incomingRowDispositions.count == 4)
    }

    private func preparedPair(
        provider: DatabaseProvider
    ) async throws -> (
        coordinator: DefaultImportPersistenceCoordinator,
        first: PreparedImport,
        second: PreparedImport
    ) {
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(
                workspaceId: workspaceID,
                workspaceName: "Reviewed Partial Import"
            )
        )
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: {
                RepositoryStoreHydrationResult(
                    didHydrate: true,
                    accountCount: 0,
                    transactionCount: 0
                )
            }
        )
        let first = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_partial_overlap_source_a.csv")
        )
        let firstResult = try coordinator.persistValidatedImport(
            financialDocument: first.financialDocument,
            importSession: first.importSession,
            validation: first.validation,
            fingerprint: first.fingerprint,
            accountChoice: .createNewAccount,
            providerGeneration: provider.generationToken
        )
        #expect(firstResult.persisted)
        #expect(firstResult.transactionCount == 4)
        let second = try await engine.prepareImport(
            from: FixtureLocator.axisCSV("axis_bank_partial_overlap_source_b.csv")
        )
        return (coordinator, first, second)
    }

    private func eligiblePlan(_ review: PartialImportReviewResult) throws -> ReviewedPartialImportPlanDTO {
        guard case .eligible(let plan) = review else {
            throw ReviewedPartialImportTestError.expectedEligiblePlan
        }
        return plan
    }
}

private enum ReviewedPartialImportTestError: Error {
    case expectedEligiblePlan
}
