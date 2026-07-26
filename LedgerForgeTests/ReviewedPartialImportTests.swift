import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct ReviewedPartialImportTests {
    private let workspaceID = "partial-overlap-quarantine-workspace"

    @Test(.globalRuntimeStateIsolation)
    func provenanceLessPartialPairFailsClosedWithProviderParity() async throws {
        try await verifyQuarantinedPair(provider: DatabaseProvider(inMemory: true))

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-PartialQuarantine-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("partial.sqlite").path
        )
        defer { sqlite.database.close() }
        try await verifyQuarantinedPair(
            provider: .verifiedSQLite(sqlite, protectsGeneration: false)
        )
    }

    @Test func conventionalFixtureArithmeticSurvivesParserAndValidation() async throws {
        let provider = DatabaseProvider(inMemory: true)
        let context = try await preparedPair(provider: provider)

        #expect(context.first.validation.passed)
        #expect(context.second.validation.passed)
        #expect(context.first.financialDocument.transactions.allSatisfy {
            $0.sourceProvenance.first?.parserProfileID == "axis.bank-account.csv" &&
            $0.sourceProvenance.first?.parserProfileVersion == "2"
        })
        #expect(context.first.financialDocument.transactions[0].credit == 100)
        #expect(context.first.financialDocument.transactions[1].debit == 40)
        #expect(context.second.financialDocument.transactions.last?.debit == 75)
    }

    @Test(.globalRuntimeStateIsolation)
    func explicitTypedPlanCannotBypassProductionSourceEligibility() async throws {
        try await verifyTypedPlanCannotBypassQuarantine(provider: DatabaseProvider(inMemory: true))

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-PartialReadback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(
            path: folder.appendingPathComponent("partial-readback.sqlite").path
        )
        defer { sqlite.database.close() }
        try await verifyTypedPlanCannotBypassQuarantine(
            provider: .verifiedSQLite(sqlite, protectsGeneration: false)
        )
    }

    private func verifyQuarantinedPair(provider: DatabaseProvider) async throws {
        let context = try await preparedPair(provider: provider)
        let accountID = try #require(
            try provider.accountRepo.accounts(workspaceId: workspaceID).first?.id
        )
        let originalTransactions = try provider.transactionRepo
            .trustedTransactions(workspaceId: workspaceID)
        let originalAttempts = try provider.importSessionRepo
            .importAttempts(workspaceId: workspaceID)

        let fullOverlap = try context.coordinator.reviewPartialImport(
            financialDocument: context.first.financialDocument,
            importSession: context.first.importSession,
            validation: context.first.validation,
            fingerprint: context.first.fingerprint,
            accountChoice: .useExistingAccount(accountId: accountID),
            providerGeneration: provider.generationToken
        )
        #expect(fullOverlap == .fullSupportedOverlap(count: 4))

        let mixedReview = try context.coordinator.reviewPartialImport(
            financialDocument: context.second.financialDocument,
            importSession: context.second.importSession,
            validation: context.second.validation,
            fingerprint: context.second.fingerprint,
            accountChoice: .useExistingAccount(accountId: accountID),
            providerGeneration: provider.generationToken
        )
        #expect(mixedReview == .unsupportedEvidence)

        #expect(try provider.transactionRepo.trustedTransactions(
            workspaceId: workspaceID
        ) == originalTransactions)
        #expect(try provider.importSessionRepo.importAttempts(
            workspaceId: workspaceID
        ) == originalAttempts)
        #expect(try provider.importSessionRepo.partialImportSummary(
            importSessionId: context.second.importSession.id.uuidString
        ) == nil)
        #expect(try provider.importSessionRepo.incomingRowDispositions(
            importSessionId: context.second.importSession.id.uuidString
        ).isEmpty)
        #expect(try provider.importSessionRepo.priorImportedStatement(
            algorithm: context.second.fingerprint.algorithm,
            fingerprint: context.second.fingerprint.digest
        ) == nil)
    }

    private func verifyTypedPlanCannotBypassQuarantine(provider: DatabaseProvider) async throws {
        let context = try await preparedPair(provider: provider)
        let accountID = try #require(
            try provider.accountRepo.accounts(workspaceId: workspaceID).first?.id
        )
        let mapper = ImportPersistenceMapper(
            workspaceId: workspaceID,
            workspaceName: "Partial Overlap Quarantine"
        )
        let base = try mapper.confirmedImportPlan(
            financialDocument: context.second.financialDocument,
            importSession: context.second.importSession,
            validation: context.second.validation,
            fingerprint: context.second.fingerprint,
            providerGeneration: provider.generationToken,
            advisoryIdentity: .resolved(accountId: accountID),
            accountChoice: .useExistingAccount(accountId: accountID),
            selectedAccountId: accountID
        )
        let normalizedRows = Dictionary(uniqueKeysWithValues: base.historyTemplate.normalizedRows.map {
            ($0.id, $0)
        })
        let keys = try base.transactionTemplates.map { template in
            let evidence = try #require(template.eventEvidence)
            let identity = try TransactionEventIdentity.make(
                transactionID: template.transaction.id,
                evidence: evidence,
                accountID: accountID
            )
            return TransactionEventIdentityKeyDTO(
                algorithm: identity.algorithmIdentifier,
                digest: identity.digest
            )
        }
        let owners = try provider.importSessionRepo.transactionEventOwners(keys: Set(keys))
        let rows = try zip(base.transactionTemplates, keys).map { template, key in
            let transaction = template.transaction
            let raw = try #require(transaction.rawRows.first)
            let normalized = try #require(normalizedRows[raw.normalizedRowId])
            let owner = owners[key]
            return ReviewedPartialImportRowDTO(
                normalizedRowId: normalized.id,
                sourceOrdinal: try #require(raw.sourceOrdinal),
                normalizedRecordDigest: try #require(raw.normalizedRecordDigest),
                statementDateISO: transaction.postedDateISO,
                financialDateRole: transaction.financialDateRole,
                timezoneEvidence: transaction.statementTimezoneEvidence,
                nativeCurrency: transaction.nativeCurrency,
                amountMinor: transaction.amountMinor,
                amountDecimal: transaction.amountDecimal,
                direction: transaction.direction,
                runningBalanceMinor: try #require(transaction.runningBalanceMinor),
                eventAlgorithm: key.algorithm,
                eventDigest: key.digest,
                disposition: owner == nil ? .importedUnique : .recognizedExisting,
                expectedTransactionId: owner?.transactionId,
                expectedEventIdentityId: owner?.eventIdentityId
            )
        }
        let recognized = rows.filter { $0.disposition == .recognizedExisting }.count
        let imported = rows.filter { $0.disposition == .importedUnique }.count
        let plan = ReviewedPartialImportPlanDTO(
            basePlan: base,
            existingAccountId: accountID,
            rows: rows,
            sourceRowCount: rows.count,
            recognizedCount: recognized,
            importedCount: imported,
            blockedCount: 0
        )
        #expect(provider.confirmedImportRepo.commitReviewedPartialImport(plan) == .reviewedPartialPlanStale)
        #expect(try provider.transactionRepo.trustedTransactions(
            workspaceId: workspaceID
        ).count == 4)
        #expect(try provider.importSessionRepo.partialImportSummary(
            importSessionId: context.second.importSession.id.uuidString
        ) == nil)
        #expect(try provider.importSessionRepo.incomingRowDispositions(
            importSessionId: context.second.importSession.id.uuidString
        ).isEmpty)
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
                workspaceName: "Partial Overlap Quarantine"
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
}
