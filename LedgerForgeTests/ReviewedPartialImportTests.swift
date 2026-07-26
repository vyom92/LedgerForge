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

    @Test(.globalRuntimeStateIsolation)
    func hydrationRejectsPartialAttemptCountMismatchBeforeReplacingRuntimeStores() async throws {
        let provider = DatabaseProvider(inMemory: true)
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
        #expect(try context.coordinator.persistReviewedPartialImport(plan).persisted)

        let accountStore = AccountStore()
        let transactionStore = TransactionStore()
        let sessionStore = ImportSessionStore()
        let attemptStore = ImportAttemptStore()
        let validHydrator = RepositoryStoreHydrator(
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
        )
        _ = try validHydrator.hydrateIfNeeded(forceRefresh: true)
        let accountSnapshot = accountStore.accounts.map(\.id)
        let transactionSnapshot = transactionStore.transactions.map(\.id)
        let sessionSnapshot = sessionStore.importSessions
        let attemptSnapshot = attemptStore.attempts

        let corruptingRepo = PartialAttemptCountMismatchRepository(base: provider.importSessionRepo)
        let corruptHydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: corruptingRepo,
            transactionRepo: provider.transactionRepo,
            accountStore: accountStore,
            transactionStore: transactionStore,
            importSessionStore: sessionStore,
            importAttemptStore: attemptStore,
            workspaceId: workspaceID,
            persistenceState: provider.persistenceState,
            participatesInLifecycleGate: false
        )

        #expect(throws: RepositoryStoreHydrationError.invalidPartialImport("attempt counts disagree")) {
            try corruptHydrator.hydrateIfNeeded(forceRefresh: true)
        }
        #expect(accountStore.accounts.map(\.id) == accountSnapshot)
        #expect(transactionStore.transactions.map(\.id) == transactionSnapshot)
        #expect(sessionStore.importSessions == sessionSnapshot)
        #expect(attemptStore.attempts == attemptSnapshot)
    }

    @Test func ordinaryFullOverlapAndInterleavedShapesRemainDistinct() async throws {
        let provider = DatabaseProvider(inMemory: true)
        let context = try await preparedPair(provider: provider)
        let accountID = try #require(
            try provider.accountRepo.accounts(workspaceId: workspaceID).first?.id
        )
        let mapper = ImportPersistenceMapper(
            workspaceId: workspaceID,
            workspaceName: "Reviewed Partial Import"
        )

        let firstPlan = try mappedPlan(
            context.first,
            provider: provider,
            accountID: accountID,
            mapper: mapper
        )
        let beforeAttempts = try provider.importSessionRepo.importAttempts(workspaceId: workspaceID)
        #expect(provider.confirmedImportRepo.reviewPartialImport(firstPlan) == .fullSupportedOverlap(count: 4))

        let secondPlan = try mappedPlan(
            context.second,
            provider: provider,
            accountID: accountID,
            mapper: mapper
        )
        let uniqueTemplates = secondPlan.transactionTemplates.enumerated().map { index, template in
            ConfirmedImportTransactionTemplateDTO(
                transaction: template.transaction,
                eventEvidence: .axisUPI(
                    ConfirmedImportAxisUPIEventEvidenceDTO(
                        operation: .p2a,
                        reference: String(format: "900000000%03d", index),
                        subtype: .posting
                    )
                )
            )
        }
        let ordinaryPlan = copyPlan(secondPlan, transactionTemplates: uniqueTemplates)
        #expect(provider.confirmedImportRepo.reviewPartialImport(ordinaryPlan) == .ordinaryFullImport)

        let owners = try owners(for: secondPlan, provider: provider, accountID: accountID)
        let orderedKeys = try eventKeys(for: secondPlan, accountID: accountID)
        var interleavedOwners = owners
        interleavedOwners.removeValue(forKey: orderedKeys[1])
        let transactions = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
        let interleaved = ReviewedPartialImportPlanner.review(
            secondPlan,
            account: try provider.accountRepo.account(id: accountID),
            owners: interleavedOwners,
            transactionsByID: Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        )
        #expect(interleaved == .unsupportedEvidence)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 4)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: workspaceID) == beforeAttempts)
    }

    @Test(arguments: PartialEligibilityRejection.allCases)
    func everyFinancialEligibilityFenceRejectsWithoutAcceptedResidue(
        _ rejection: PartialEligibilityRejection
    ) async throws {
        let provider = DatabaseProvider(inMemory: true)
        let context = try await preparedPair(provider: provider)
        let accountID = try #require(
            try provider.accountRepo.accounts(workspaceId: workspaceID).first?.id
        )
        let mapper = ImportPersistenceMapper(
            workspaceId: workspaceID,
            workspaceName: "Reviewed Partial Import"
        )
        let base = try mappedPlan(
            context.second,
            provider: provider,
            accountID: accountID,
            mapper: mapper
        )
        let rejected = rejectedPlan(base, for: rejection)
        let transactionsBefore = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
        let attemptsBefore = try provider.importSessionRepo.importAttempts(workspaceId: workspaceID)

        let review = provider.confirmedImportRepo.reviewPartialImport(rejected)
        if case .eligible = review {
            Issue.record("Eligibility rejection unexpectedly produced a reviewed plan: \(rejection)")
        }
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID) == transactionsBefore)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: workspaceID) == attemptsBefore)
        #expect(try provider.importSessionRepo.partialImportSummary(
            importSessionId: rejected.historyTemplate.importSession.id
        ) == nil)
        #expect(try provider.importSessionRepo.incomingRowDispositions(
            importSessionId: rejected.historyTemplate.importSession.id
        ).isEmpty)
    }

    @Test(arguments: ReviewedPlanTamper.allCases)
    func reviewedPlanDigestAndExecutionTruthRejectEveryTamper(
        _ tamper: ReviewedPlanTamper
    ) async throws {
        let provider = DatabaseProvider(inMemory: true)
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
        let transactionsBefore = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
        let attemptsBefore = try provider.importSessionRepo.importAttempts(workspaceId: workspaceID)
        let changed = tamperedPlan(plan, for: tamper)

        #expect(provider.confirmedImportRepo.commitReviewedPartialImport(changed) == .reviewedPartialPlanStale)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID) == transactionsBefore)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: workspaceID) == attemptsBefore)
        #expect(try provider.importSessionRepo.partialImportSummary(
            importSessionId: plan.basePlan.historyTemplate.importSession.id
        ) == nil)
    }

    @Test(arguments: PartialRepositoryEvidenceFailure.allCases)
    func recognizedRepositoryEvidenceFailuresRejectReadOnly(
        _ failure: PartialRepositoryEvidenceFailure
    ) async throws {
        let provider = DatabaseProvider(inMemory: true)
        let context = try await preparedPair(provider: provider)
        let accountID = try #require(
            try provider.accountRepo.accounts(workspaceId: workspaceID).first?.id
        )
        let plan = try mappedPlan(
            context.second,
            provider: provider,
            accountID: accountID,
            mapper: ImportPersistenceMapper(
                workspaceId: workspaceID,
                workspaceName: "Reviewed Partial Import"
            )
        )
        var owners = try owners(for: plan, provider: provider, accountID: accountID)
        var transactions = Dictionary(uniqueKeysWithValues: try provider.transactionRepo
            .trustedTransactions(workspaceId: workspaceID)
            .map { ($0.id, $0) })
        let firstKey = try #require(try eventKeys(for: plan, accountID: accountID).first)
        let firstOwner = try #require(owners[firstKey])
        let expected: PartialImportReviewResult
        switch failure {
        case .anotherAccount:
            owners[firstKey] = TransactionEventIdentityOwnerDTO(
                eventIdentityId: firstOwner.eventIdentityId,
                accountId: "other-account",
                transactionId: firstOwner.transactionId,
                documentId: firstOwner.documentId,
                importSessionId: firstOwner.importSessionId
            )
            expected = .ownershipConflict
        case .missingTransaction:
            transactions.removeValue(forKey: firstOwner.transactionId)
            expected = .repositoryIntegrityConflict
        case .missingEventOwner:
            owners[firstKey] = TransactionEventIdentityOwnerDTO(
                eventIdentityId: "",
                accountId: firstOwner.accountId,
                transactionId: firstOwner.transactionId,
                documentId: firstOwner.documentId,
                importSessionId: firstOwner.importSessionId
            )
            expected = .repositoryIntegrityConflict
        case .projectionDisagreement:
            let transaction = try #require(transactions[firstOwner.transactionId])
            transactions[firstOwner.transactionId] = copyTransactionAmount(
                transaction,
                amountMinor: transaction.amountMinor + 1
            )
            expected = .repositoryIntegrityConflict
        }
        let attemptsBefore = try provider.importSessionRepo.importAttempts(workspaceId: workspaceID)
        #expect(ReviewedPartialImportPlanner.review(
            plan,
            account: try provider.accountRepo.account(id: accountID),
            owners: owners,
            transactionsByID: transactions
        ) == expected)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: workspaceID) == attemptsBefore)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 4)
    }

    @Test func inMemoryConcurrentReviewedPlansProduceOneCompletePartialGraph() async throws {
        let provider = DatabaseProvider(inMemory: true)
        let context = try await preparedPair(provider: provider)
        let first = try eligiblePlan(try context.coordinator.reviewPartialImport(
            financialDocument: context.second.financialDocument,
            importSession: context.second.importSession,
            validation: context.second.validation,
            fingerprint: context.second.fingerprint,
            accountChoice: nil,
            providerGeneration: provider.generationToken
        ))
        let second = try eligiblePlan(try context.coordinator.reviewPartialImport(
            financialDocument: context.second.financialDocument,
            importSession: context.second.importSession,
            validation: context.second.validation,
            fingerprint: context.second.fingerprint,
            accountChoice: nil,
            providerGeneration: provider.generationToken
        ))
        let results = concurrentCommits([
            (provider.confirmedImportRepo, first),
            (provider.confirmedImportRepo, second)
        ])
        #expect(results.filter { if case .partialCommitted = $0 { true } else { false } }.count == 1)
        #expect(results.filter { $0 == .reviewedPartialPlanStale }.count == 1)
        try assertSinglePartialGraph(provider: provider)
    }

    @Test func independentSQLiteProvidersRaceReviewedPartialConfirmation() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-PartialRace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("partial-race.sqlite").path
        let firstSQLite = try SQLiteRepositoryProvider(path: path)
        let firstProvider = DatabaseProvider.verifiedSQLite(firstSQLite, protectsGeneration: false)
        let context = try await preparedPair(provider: firstProvider)
        let secondSQLite = try SQLiteRepositoryProvider(path: path)
        let secondProvider = DatabaseProvider.verifiedSQLite(secondSQLite, protectsGeneration: false)
        defer {
            firstSQLite.database.close()
            secondSQLite.database.close()
        }
        let accountID = try #require(
            try firstProvider.accountRepo.accounts(workspaceId: workspaceID).first?.id
        )
        let mapper = ImportPersistenceMapper(
            workspaceId: workspaceID,
            workspaceName: "Reviewed Partial Import"
        )
        let firstBase = try mappedPlan(
            context.second,
            provider: firstProvider,
            accountID: accountID,
            mapper: mapper
        )
        let secondBase = try mappedPlan(
            context.second,
            provider: secondProvider,
            accountID: accountID,
            mapper: mapper
        )
        let first = try eligiblePlan(firstProvider.confirmedImportRepo.reviewPartialImport(firstBase))
        let second = try eligiblePlan(secondProvider.confirmedImportRepo.reviewPartialImport(secondBase))
        let results = concurrentCommits([
            (firstProvider.confirmedImportRepo, first),
            (secondProvider.confirmedImportRepo, second)
        ])
        #expect(results.filter { if case .partialCommitted = $0 { true } else { false } }.count == 1)
        #expect(results.filter {
            $0 == .reviewedPartialPlanStale ||
            $0 == .exactDuplicate ||
            $0 == .retryableContention
        }.count == 1)
        try assertSinglePartialGraph(provider: firstProvider)
    }

    @Test(arguments: PartialHydrationCorruption.allCases)
    func corruptedPartialGraphsFailBeforeAnyRuntimeStoreMutation(
        _ corruption: PartialHydrationCorruption
    ) async throws {
        let provider = DatabaseProvider(inMemory: true)
        let context = try await preparedPair(provider: provider)
        let plan = try eligiblePlan(try context.coordinator.reviewPartialImport(
            financialDocument: context.second.financialDocument,
            importSession: context.second.importSession,
            validation: context.second.validation,
            fingerprint: context.second.fingerprint,
            accountChoice: nil,
            providerGeneration: provider.generationToken
        ))
        #expect(try context.coordinator.persistReviewedPartialImport(plan).persisted)

        let accountStore = AccountStore()
        let transactionStore = TransactionStore()
        let sessionStore = ImportSessionStore()
        let attemptStore = ImportAttemptStore()
        let validHydrator = RepositoryStoreHydrator(
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
        )
        _ = try validHydrator.hydrateIfNeeded(forceRefresh: true)
        let accountSnapshot = accountStore.accounts.map(\.id)
        let transactionSnapshot = transactionStore.transactions.map(\.id)
        let sessionSnapshot = sessionStore.importSessions
        let attemptSnapshot = attemptStore.attempts

        let corruptRepo = CorruptPartialImportRepository(
            base: provider.importSessionRepo,
            corruption: corruption
        )
        let corruptHydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo,
            importSessionRepo: corruptRepo,
            transactionRepo: provider.transactionRepo,
            accountStore: accountStore,
            transactionStore: transactionStore,
            importSessionStore: sessionStore,
            importAttemptStore: attemptStore,
            workspaceId: workspaceID,
            persistenceState: provider.persistenceState,
            participatesInLifecycleGate: false
        )
        do {
            _ = try corruptHydrator.hydrateIfNeeded(forceRefresh: true)
            Issue.record("Corrupted partial graph hydrated: \(corruption)")
        } catch let error as RepositoryStoreHydrationError {
            guard case .invalidPartialImport = error else {
                Issue.record("Unexpected hydration error: \(error)")
                return
            }
        }
        #expect(accountStore.accounts.map(\.id) == accountSnapshot)
        #expect(transactionStore.transactions.map(\.id) == transactionSnapshot)
        #expect(sessionStore.importSessions == sessionSnapshot)
        #expect(attemptStore.attempts == attemptSnapshot)
    }

    @Test(arguments: ConfirmedImportFailureInjectionPoint.allCases.filter {
        $0 != .workspace && $0 != .account
    })
    func inMemoryLateFailureInjectionPublishesNoPartialResidue(
        _ point: ConfirmedImportFailureInjectionPoint
    ) async throws {
        let concrete = InMemoryRepositoryProvider()
        let provider = DatabaseProvider(
            workspaceRepo: concrete.workspaceRepo,
            transactionRepo: concrete.transactionRepo,
            accountRepo: concrete.accountRepo,
            importSessionRepo: concrete.importSessionRepo,
            confirmedImportRepo: concrete.confirmedImportRepo,
            generationToken: concrete.generationToken,
            persistenceState: .intentionalNonDurable(.testMemory)
        )
        let context = try await preparedPair(provider: provider)
        let plan = try eligiblePlan(try context.coordinator.reviewPartialImport(
            financialDocument: context.second.financialDocument,
            importSession: context.second.importSession,
            validation: context.second.validation,
            fingerprint: context.second.fingerprint,
            accountChoice: nil,
            providerGeneration: provider.generationToken
        ))
        let transactionsBefore = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
        let attemptsBefore = try provider.importSessionRepo.importAttempts(workspaceId: workspaceID)
        concrete.injectConfirmedImportFailure(after: point)

        #expect(provider.confirmedImportRepo.commitReviewedPartialImport(plan) == .repositoryIntegrityConflict)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID) == transactionsBefore)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: workspaceID) == attemptsBefore)
        #expect(try provider.importSessionRepo.partialImportSummary(
            importSessionId: plan.basePlan.historyTemplate.importSession.id
        ) == nil)
        #expect(try provider.importSessionRepo.incomingRowDispositions(
            importSessionId: plan.basePlan.historyTemplate.importSession.id
        ).isEmpty)
    }

    @Test func SQLiteLateAttemptConflictRollsBackEveryEarlierPartialWrite() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-PartialRollback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("rollback.sqlite").path)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        let context = try await preparedPair(provider: provider)
        let plan = try eligiblePlan(try context.coordinator.reviewPartialImport(
            financialDocument: context.second.financialDocument,
            importSession: context.second.importSession,
            validation: context.second.validation,
            fingerprint: context.second.fingerprint,
            accountChoice: nil,
            providerGeneration: provider.generationToken
        ))
        let transactionsBefore = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
        try sqlite.database.executePrepared(
            sql: "INSERT INTO import_attempts (id, workspace_id, created_at, outcome_code, coverage_code, account_decision_code, guidance_code, persistence_code, transaction_count) VALUES (?,?,?,?,?,?,?,?,?);",
            params: [
                plan.basePlan.historyTemplate.successfulAttempt.id,
                workspaceID,
                plan.basePlan.historyTemplate.completedAtISO,
                ImportAttemptOutcome.persistenceFailure.rawValue,
                ImportAttemptCoverage.unsupportedOrUnevaluated.rawValue,
                ImportAttemptAccountDecision.noFinancialMutation.rawValue,
                ImportAttemptGuidance.integrityReviewRequired.rawValue,
                ImportAttemptPersistence.rejectedRecorded.rawValue,
                0
            ]
        )
        let attemptsBefore = try provider.importSessionRepo.importAttempts(workspaceId: workspaceID)

        #expect(provider.confirmedImportRepo.commitReviewedPartialImport(plan) == .repositoryIntegrityConflict)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID) == transactionsBefore)
        #expect(try provider.importSessionRepo.importAttempts(workspaceId: workspaceID) == attemptsBefore)
        #expect(try provider.importSessionRepo.partialImportSummary(
            importSessionId: plan.basePlan.historyTemplate.importSession.id
        ) == nil)
        #expect(try provider.importSessionRepo.incomingRowDispositions(
            importSessionId: plan.basePlan.historyTemplate.importSession.id
        ).isEmpty)
        #expect(try sqlite.database.queryInt(
            "SELECT COUNT(*) FROM documents WHERE id = '\(plan.basePlan.historyTemplate.document.id)';"
        ) == 0)
        #expect(try sqlite.database.queryInt(
            "SELECT COUNT(*) FROM normalized_documents WHERE id = '\(plan.basePlan.historyTemplate.normalizedDocument?.id ?? "")';"
        ) == 0)
    }

    private func verifyApprovedPair(provider: DatabaseProvider) async throws {
        let context = try await preparedPair(provider: provider)
        let originalTransactions = try provider.transactionRepo
            .trustedTransactions(workspaceId: workspaceID)
        #expect(originalTransactions.count == 4)
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
        let sourceOrdinals = plan.rows.map(\.sourceOrdinal)
        #expect(sourceOrdinals == sourceOrdinals.sorted())
        #expect(zip(sourceOrdinals, sourceOrdinals.dropFirst()).allSatisfy { $1 == $0 + 1 })
        #expect(plan.rows.prefix(3).allSatisfy { $0.disposition == .recognizedExisting })
        #expect(plan.rows.last?.disposition == .importedUnique)
        let recognizedIDs = Set(plan.recognizedRows.compactMap(\.expectedTransactionId))
        #expect(recognizedIDs.count == 3)
        let originalRecognized = Dictionary(
            uniqueKeysWithValues: originalTransactions
                .filter { recognizedIDs.contains($0.id) }
                .map { ($0.id, $0) }
        )

        let result = try context.coordinator.persistReviewedPartialImport(plan)
        #expect(result.persisted)
        #expect(result.isPartialImport)
        #expect(result.transactionCount == 1)
        let finalTransactions = try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID)
        #expect(finalTransactions.count == 5)
        for transactionID in recognizedIDs {
            let before = try #require(originalRecognized[transactionID])
            let after = try #require(finalTransactions.first { $0.id == transactionID })
            #expect(after.accountId == before.accountId)
            #expect(after.importSessionId == before.importSessionId)
            #expect(after.documentId == before.documentId)
            #expect(after.postedDateISO == before.postedDateISO)
            #expect(after.nativeCurrency == before.nativeCurrency)
            #expect(after.amountMinor == before.amountMinor)
            #expect(after.amountDecimal == before.amountDecimal)
            #expect(after.direction == before.direction)
            #expect(after.runningBalanceMinor == before.runningBalanceMinor)
            #expect(after.rawRows.count == before.rawRows.count + 1)
        }
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
        let attempts = try provider.importSessionRepo.importAttempts(workspaceId: workspaceID)
        #expect(Set(attempts.compactMap(\.importSessionId)).count == 2)
        #expect(attempts.filter { $0.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue }.count == 1)
        #expect(attempts.filter { $0.outcomeCode == ImportAttemptOutcome.partialImportCommitted.rawValue }.count == 1)

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

    private func mappedPlan(
        _ prepared: PreparedImport,
        provider: DatabaseProvider,
        accountID: String,
        mapper: ImportPersistenceMapper
    ) throws -> ConfirmedImportPlanDTO {
        try mapper.confirmedImportPlan(
            financialDocument: prepared.financialDocument,
            importSession: prepared.importSession,
            validation: prepared.validation,
            fingerprint: prepared.fingerprint,
            providerGeneration: provider.generationToken,
            advisoryIdentity: .resolved(accountId: accountID),
            accountChoice: .useExistingAccount(accountId: accountID),
            selectedAccountId: accountID
        )
    }

    private func eventKeys(
        for plan: ConfirmedImportPlanDTO,
        accountID: String
    ) throws -> [TransactionEventIdentityKeyDTO] {
        try plan.transactionTemplates.map { template in
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
    }

    private func owners(
        for plan: ConfirmedImportPlanDTO,
        provider: DatabaseProvider,
        accountID: String
    ) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] {
        try provider.importSessionRepo.transactionEventOwners(
            keys: Set(eventKeys(for: plan, accountID: accountID))
        )
    }

    private func rejectedPlan(
        _ plan: ConfirmedImportPlanDTO,
        for rejection: PartialEligibilityRejection
    ) -> ConfirmedImportPlanDTO {
        switch rejection {
        case .newAccountChoice:
            return copyPlan(plan, accountChoice: .createProposedAccount)
        case .unsupportedCurrency:
            let account = AccountDTO(
                id: plan.proposedAccount.id,
                workspaceId: plan.proposedAccount.workspaceId,
                name: plan.proposedAccount.name,
                institutionId: plan.proposedAccount.institutionId,
                accountType: plan.proposedAccount.accountType,
                nativeCurrency: "USD",
                description: plan.proposedAccount.description,
                createdAtISO: plan.proposedAccount.createdAtISO
            )
            return copyPlan(plan, proposedAccount: account)
        case .unsupportedProfileID:
            return copyPlan(plan, historyTemplate: copyHistory(plan.historyTemplate, profileID: "axis.unsupported"))
        case .unsupportedProfileVersion:
            return copyPlan(plan, historyTemplate: copyHistory(plan.historyTemplate, profileVersion: "2"))
        case .missingDeclaredPeriod:
            return copyPlan(plan, declaredStart: .some(nil))
        case .malformedDeclaredPeriod:
            return copyPlan(plan, declaredStart: .some("not-a-date"))
        case .reversedDeclaredPeriod:
            return copyPlan(plan, declaredStart: .some("2026-12-31"), declaredEnd: .some("2026-01-01"))
        case .transactionOutsidePeriod:
            return copyPlan(plan, declaredStart: .some("2099-01-01"), declaredEnd: .some("2099-12-31"))
        case .missingOpeningBalance:
            return copyPlan(plan, openingMinor: .some(nil))
        case .missingClosingBalance:
            return copyPlan(plan, closingMinor: .some(nil))
        case .decimalMinorMismatch:
            return copyPlan(plan, openingDecimal: .some("0.01"))
        case .missingRunningBalance:
            let templates = replaceTransaction(
                in: plan,
                at: 0,
                with: copyTransaction(plan.transactionTemplates[0].transaction, runningBalanceMinor: .some(nil))
            )
            return copyPlan(plan, transactionTemplates: templates)
        case .incompleteReconciliation:
            let current = plan.transactionTemplates[0].transaction
            let templates = replaceTransaction(
                in: plan,
                at: 0,
                with: copyTransaction(current, runningBalanceMinor: .some((current.runningBalanceMinor ?? 0) + 1))
            )
            return copyPlan(plan, transactionTemplates: templates)
        case .missingEventEvidence:
            var templates = plan.transactionTemplates
            templates[0] = ConfirmedImportTransactionTemplateDTO(
                transaction: templates[0].transaction,
                eventEvidence: nil
            )
            return copyPlan(plan, transactionTemplates: templates)
        case .unsupportedEventEvidence:
            var templates = plan.transactionTemplates
            templates[0] = ConfirmedImportTransactionTemplateDTO(
                transaction: templates[0].transaction,
                eventEvidence: .axisUPI(
                    ConfirmedImportAxisUPIEventEvidenceDTO(
                        operation: .p2a,
                        reference: "invalid",
                        subtype: .posting
                    )
                )
            )
            return copyPlan(plan, transactionTemplates: templates)
        case .repeatedIncomingEvent:
            var templates = plan.transactionTemplates
            templates[1] = ConfirmedImportTransactionTemplateDTO(
                transaction: templates[1].transaction,
                eventEvidence: templates[0].eventEvidence
            )
            return copyPlan(plan, transactionTemplates: templates)
        case .duplicateNormalizedRow:
            var rows = plan.historyTemplate.normalizedRows
            rows[1] = NormalizedRowDTO(
                id: rows[0].id,
                normalizedDocumentId: rows[1].normalizedDocumentId,
                sourceOrdinal: rows[1].sourceOrdinal,
                digest: rows[1].digest
            )
            return copyPlan(plan, historyTemplate: copyHistory(plan.historyTemplate, rows: rows))
        case .duplicateSourceOrdinal:
            var rows = plan.historyTemplate.normalizedRows
            rows[1] = NormalizedRowDTO(
                id: rows[1].id,
                normalizedDocumentId: rows[1].normalizedDocumentId,
                sourceOrdinal: rows[0].sourceOrdinal,
                digest: rows[1].digest
            )
            return copyPlan(plan, historyTemplate: copyHistory(plan.historyTemplate, rows: rows))
        case .emptyIncomingRows:
            return copyPlan(
                plan,
                historyTemplate: copyHistory(plan.historyTemplate, rows: []),
                transactionTemplates: []
            )
        }
    }

    private func tamperedPlan(
        _ plan: ReviewedPartialImportPlanDTO,
        for tamper: ReviewedPlanTamper
    ) -> ReviewedPartialImportPlanDTO {
        var base = plan.basePlan
        var rows = plan.rows
        var accountID = plan.existingAccountId
        var sourceCount = plan.sourceRowCount
        var algorithm = plan.digestAlgorithm
        switch tamper {
        case .amount:
            rows[0] = copyReviewedRow(rows[0], amountMinor: rows[0].amountMinor + 1)
        case .direction:
            rows[0] = copyReviewedRow(rows[0], direction: rows[0].direction == "credit" ? "debit" : "credit")
        case .statementDate:
            rows[0] = copyReviewedRow(rows[0], statementDateISO: "2099-01-01")
        case .runningBalance:
            rows[0] = copyReviewedRow(rows[0], runningBalanceMinor: rows[0].runningBalanceMinor + 1)
        case .normalizedDigest:
            rows[0] = copyReviewedRow(rows[0], normalizedRecordDigest: rows[0].normalizedRecordDigest + "x")
        case .eventDigest:
            rows[0] = copyReviewedRow(rows[0], eventDigest: rows[0].eventDigest + "x")
        case .disposition:
            rows[0] = copyReviewedRow(rows[0], disposition: .importedUnique)
        case .recognizedTransactionOwner:
            rows[0] = copyReviewedRow(rows[0], expectedTransactionId: .some("other-transaction"))
        case .recognizedEventOwner:
            rows[0] = copyReviewedRow(rows[0], expectedEventIdentityId: .some("other-event"))
        case .counts:
            sourceCount += 1
        case .account:
            accountID += "-other"
        case .fingerprint:
            base = copyPlan(
                base,
                historyTemplate: copyHistory(base.historyTemplate, fingerprintValue: "other-fingerprint")
            )
        case .profile:
            base = copyPlan(
                base,
                historyTemplate: copyHistory(base.historyTemplate, profileVersion: "2")
            )
        case .declaredPeriod:
            base = copyPlan(base, declaredStart: .some("2099-01-01"))
        case .openingBalance:
            base = copyPlan(base, openingMinor: .some((base.openingBalanceMinor ?? 0) + 1))
        case .closingBalance:
            base = copyPlan(base, closingMinor: .some((base.closingBalanceMinor ?? 0) + 1))
        case .digestAlgorithm:
            algorithm = "unsupported"
        case .providerGeneration:
            base = copyPlan(base, providerGeneration: ProviderGenerationToken())
        }
        return ReviewedPartialImportPlanDTO(
            id: plan.id,
            basePlan: base,
            existingAccountId: accountID,
            rows: rows,
            sourceRowCount: sourceCount,
            recognizedCount: plan.recognizedCount,
            importedCount: plan.importedCount,
            blockedCount: plan.blockedCount,
            digestAlgorithm: algorithm,
            digest: plan.digest
        )
    }

    private func concurrentCommits(
        _ work: [(ConfirmedImportRepository, ReviewedPartialImportPlanDTO)]
    ) -> [ConfirmedImportRepositoryResult] {
        let lock = NSLock()
        let group = DispatchGroup()
        var results: [ConfirmedImportRepositoryResult] = []
        for (repository, plan) in work {
            group.enter()
            DispatchQueue.global().async {
                let result = repository.commitReviewedPartialImport(plan)
                lock.lock()
                results.append(result)
                lock.unlock()
                group.leave()
            }
        }
        #expect(group.wait(timeout: .now() + 5) == .success)
        return results
    }

    private func assertSinglePartialGraph(provider: DatabaseProvider) throws {
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).count == 5)
        let attempts = try provider.importSessionRepo.importAttempts(workspaceId: workspaceID)
        let partialAttempts = attempts.filter {
            $0.outcomeCode == ImportAttemptOutcome.partialImportCommitted.rawValue
        }
        #expect(partialAttempts.count == 1)
        let sessionID = try #require(partialAttempts.first?.importSessionId)
        #expect(try provider.importSessionRepo.partialImportSummary(importSessionId: sessionID) != nil)
        #expect(try provider.importSessionRepo.incomingRowDispositions(importSessionId: sessionID).count == 4)
    }
}

private enum ReviewedPartialImportTestError: Error {
    case expectedEligiblePlan
}

enum PartialEligibilityRejection: String, CaseIterable, CustomStringConvertible {
    case newAccountChoice
    case unsupportedCurrency
    case unsupportedProfileID
    case unsupportedProfileVersion
    case missingDeclaredPeriod
    case malformedDeclaredPeriod
    case reversedDeclaredPeriod
    case transactionOutsidePeriod
    case missingOpeningBalance
    case missingClosingBalance
    case decimalMinorMismatch
    case missingRunningBalance
    case incompleteReconciliation
    case missingEventEvidence
    case unsupportedEventEvidence
    case repeatedIncomingEvent
    case duplicateNormalizedRow
    case duplicateSourceOrdinal
    case emptyIncomingRows

    var description: String { rawValue }
}

enum ReviewedPlanTamper: String, CaseIterable {
    case amount
    case direction
    case statementDate
    case runningBalance
    case normalizedDigest
    case eventDigest
    case disposition
    case recognizedTransactionOwner
    case recognizedEventOwner
    case counts
    case account
    case fingerprint
    case profile
    case declaredPeriod
    case openingBalance
    case closingBalance
    case digestAlgorithm
    case providerGeneration
}

enum PartialHydrationCorruption: String, CaseIterable {
    case missingSummary
    case missingDisposition
    case duplicateDisposition
    case unknownDisposition
    case wrongDocument
    case wrongSession
    case missingNormalizedRow
    case wrongEventTransaction
    case malformedPeriod
    case malformedMoney
    case decimalMinorMismatch
    case summaryCount
}

enum PartialRepositoryEvidenceFailure: String, CaseIterable {
    case anotherAccount
    case missingTransaction
    case missingEventOwner
    case projectionDisagreement
}

private enum OptionalOverride<Value> {
    case unchanged
    case some(Value?)
}

private func copyPlan(
    _ plan: ConfirmedImportPlanDTO,
    providerGeneration: ProviderGenerationToken? = nil,
    proposedAccount: AccountDTO? = nil,
    accountChoice: ConfirmedImportAccountChoiceDTO? = nil,
    historyTemplate: ConfirmedImportHistoryTemplateDTO? = nil,
    transactionTemplates: [ConfirmedImportTransactionTemplateDTO]? = nil,
    declaredStart: OptionalOverride<String> = .unchanged,
    declaredEnd: OptionalOverride<String> = .unchanged,
    openingMinor: OptionalOverride<Int64> = .unchanged,
    openingDecimal: OptionalOverride<String> = .unchanged,
    closingMinor: OptionalOverride<Int64> = .unchanged,
    closingDecimal: OptionalOverride<String> = .unchanged
) -> ConfirmedImportPlanDTO {
    func resolved<T>(_ override: OptionalOverride<T>, current: T?) -> T? {
        switch override {
        case .unchanged: return current
        case .some(let value): return value
        }
    }
    return ConfirmedImportPlanDTO(
        providerGeneration: providerGeneration ?? plan.providerGeneration,
        workspace: plan.workspace,
        proposedAccount: proposedAccount ?? plan.proposedAccount,
        accountChoice: accountChoice ?? plan.accountChoice,
        advisoryIdentity: plan.advisoryIdentity,
        identifiers: plan.identifiers,
        historyTemplate: historyTemplate ?? plan.historyTemplate,
        transactionTemplates: transactionTemplates ?? plan.transactionTemplates,
        declaredStatementStartISO: resolved(declaredStart, current: plan.declaredStatementStartISO),
        declaredStatementEndISO: resolved(declaredEnd, current: plan.declaredStatementEndISO),
        openingBalanceMinor: resolved(openingMinor, current: plan.openingBalanceMinor),
        openingBalanceDecimal: resolved(openingDecimal, current: plan.openingBalanceDecimal),
        closingBalanceMinor: resolved(closingMinor, current: plan.closingBalanceMinor),
        closingBalanceDecimal: resolved(closingDecimal, current: plan.closingBalanceDecimal)
    )
}

private func copyHistory(
    _ history: ConfirmedImportHistoryTemplateDTO,
    profileID: String? = nil,
    profileVersion: String? = nil,
    fingerprintValue: String? = nil,
    rows: [NormalizedRowDTO]? = nil
) -> ConfirmedImportHistoryTemplateDTO {
    let document = history.normalizedDocument.map {
        NormalizedDocumentDTO(
            id: $0.id,
            importSessionId: $0.importSessionId,
            documentId: $0.documentId,
            profileId: profileID ?? $0.profileId,
            profileVersion: profileVersion ?? $0.profileVersion
        )
    }
    return ConfirmedImportHistoryTemplateDTO(
        document: history.document,
        fingerprint: DocumentFingerprintDTO(
            id: history.fingerprint.id,
            documentId: history.fingerprint.documentId,
            importSessionId: history.fingerprint.importSessionId,
            algorithm: history.fingerprint.algorithm,
            fingerprint: fingerprintValue ?? history.fingerprint.fingerprint,
            fingerprintData: history.fingerprint.fingerprintData,
            createdAtISO: history.fingerprint.createdAtISO
        ),
        importSession: history.importSession,
        completedAtISO: history.completedAtISO,
        successfulAttempt: history.successfulAttempt,
        normalizedDocument: document,
        normalizedRows: rows ?? history.normalizedRows
    )
}

private func copyReviewedRow(
    _ row: ReviewedPartialImportRowDTO,
    normalizedRecordDigest: String? = nil,
    statementDateISO: String? = nil,
    amountMinor: Int64? = nil,
    direction: String? = nil,
    runningBalanceMinor: Int64? = nil,
    eventDigest: String? = nil,
    disposition: PartialImportRowDisposition? = nil,
    expectedTransactionId: OptionalOverride<String> = .unchanged,
    expectedEventIdentityId: OptionalOverride<String> = .unchanged
) -> ReviewedPartialImportRowDTO {
    func resolved<T>(_ override: OptionalOverride<T>, current: T?) -> T? {
        switch override {
        case .unchanged: return current
        case .some(let value): return value
        }
    }
    return ReviewedPartialImportRowDTO(
        normalizedRowId: row.normalizedRowId,
        sourceOrdinal: row.sourceOrdinal,
        normalizedRecordDigest: normalizedRecordDigest ?? row.normalizedRecordDigest,
        statementDateISO: statementDateISO ?? row.statementDateISO,
        financialDateRole: row.financialDateRole,
        timezoneEvidence: row.timezoneEvidence,
        nativeCurrency: row.nativeCurrency,
        amountMinor: amountMinor ?? row.amountMinor,
        amountDecimal: row.amountDecimal,
        direction: direction ?? row.direction,
        runningBalanceMinor: runningBalanceMinor ?? row.runningBalanceMinor,
        eventAlgorithm: row.eventAlgorithm,
        eventDigest: eventDigest ?? row.eventDigest,
        disposition: disposition ?? row.disposition,
        expectedTransactionId: resolved(expectedTransactionId, current: row.expectedTransactionId),
        expectedEventIdentityId: resolved(expectedEventIdentityId, current: row.expectedEventIdentityId)
    )
}

private func copySummary(
    _ summary: PartialImportSummaryDTO,
    statementStartDateISO: String? = nil,
    openingBalanceDecimal: String? = nil,
    openingBalanceMinor: Int64? = nil,
    sourceRowCount: Int? = nil
) -> PartialImportSummaryDTO {
    PartialImportSummaryDTO(
        importSessionId: summary.importSessionId,
        documentId: summary.documentId,
        planDigestAlgorithm: summary.planDigestAlgorithm,
        planDigest: summary.planDigest,
        statementStartDateISO: statementStartDateISO ?? summary.statementStartDateISO,
        statementEndDateISO: summary.statementEndDateISO,
        nativeCurrency: summary.nativeCurrency,
        sourceRowCount: sourceRowCount ?? summary.sourceRowCount,
        importedTransactionCount: summary.importedTransactionCount,
        recognizedExistingRowCount: summary.recognizedExistingRowCount,
        blockedRowCount: summary.blockedRowCount,
        openingBalanceMinor: openingBalanceMinor ?? summary.openingBalanceMinor,
        openingBalanceDecimal: openingBalanceDecimal ?? summary.openingBalanceDecimal,
        closingBalanceMinor: summary.closingBalanceMinor,
        closingBalanceDecimal: summary.closingBalanceDecimal,
        createdAtISO: summary.createdAtISO
    )
}

private func copyDisposition(
    _ row: IncomingRowDispositionDTO,
    importSessionId: String? = nil,
    documentId: String? = nil,
    normalizedRowId: String? = nil,
    dispositionCode: String? = nil,
    amountDecimal: String? = nil,
    eventTransactionId: OptionalOverride<String> = .unchanged
) -> IncomingRowDispositionDTO {
    let eventTransaction: String?
    switch eventTransactionId {
    case .unchanged: eventTransaction = row.eventTransactionId
    case .some(let value): eventTransaction = value
    }
    return IncomingRowDispositionDTO(
        id: row.id,
        importSessionId: importSessionId ?? row.importSessionId,
        documentId: documentId ?? row.documentId,
        normalizedRowId: normalizedRowId ?? row.normalizedRowId,
        sourceOrdinal: row.sourceOrdinal,
        dispositionCode: dispositionCode ?? row.dispositionCode,
        transactionId: row.transactionId,
        transactionEventIdentityId: row.transactionEventIdentityId,
        statementDateISO: row.statementDateISO,
        financialDateRole: row.financialDateRole,
        statementTimezoneEvidence: row.statementTimezoneEvidence,
        nativeCurrency: row.nativeCurrency,
        amountMinor: row.amountMinor,
        amountDecimal: amountDecimal ?? row.amountDecimal,
        direction: row.direction,
        runningBalanceMinor: row.runningBalanceMinor,
        createdAtISO: row.createdAtISO,
        eventTransactionId: eventTransaction
    )
}

private func copyTransaction(
    _ transaction: TransactionDTO,
    runningBalanceMinor: OptionalOverride<Int64> = .unchanged
) -> TransactionDTO {
    let balance: Int64?
    switch runningBalanceMinor {
    case .unchanged: balance = transaction.runningBalanceMinor
    case .some(let value): balance = value
    }
    return TransactionDTO(
        id: transaction.id,
        workspaceId: transaction.workspaceId,
        accountId: transaction.accountId,
        importSessionId: transaction.importSessionId,
        documentId: transaction.documentId,
        originalRowId: transaction.originalRowId,
        postedDateISO: transaction.postedDateISO,
        financialDateRole: transaction.financialDateRole,
        statementTimezoneEvidence: transaction.statementTimezoneEvidence,
        valueDateISO: transaction.valueDateISO,
        description: transaction.description,
        payee: transaction.payee,
        reference: transaction.reference,
        nativeCurrency: transaction.nativeCurrency,
        amountMinor: transaction.amountMinor,
        amountDecimal: transaction.amountDecimal,
        direction: transaction.direction,
        runningBalanceMinor: balance,
        isReconciled: transaction.isReconciled,
        isTrusted: transaction.isTrusted,
        trustedAtISO: transaction.trustedAtISO,
        createdAtISO: transaction.createdAtISO,
        updatedAtISO: transaction.updatedAtISO,
        rawRows: transaction.rawRows
    )
}

private func copyTransactionAmount(
    _ transaction: TransactionDTO,
    amountMinor: Int64
) -> TransactionDTO {
    TransactionDTO(
        id: transaction.id,
        workspaceId: transaction.workspaceId,
        accountId: transaction.accountId,
        importSessionId: transaction.importSessionId,
        documentId: transaction.documentId,
        originalRowId: transaction.originalRowId,
        postedDateISO: transaction.postedDateISO,
        financialDateRole: transaction.financialDateRole,
        statementTimezoneEvidence: transaction.statementTimezoneEvidence,
        valueDateISO: transaction.valueDateISO,
        description: transaction.description,
        payee: transaction.payee,
        reference: transaction.reference,
        nativeCurrency: transaction.nativeCurrency,
        amountMinor: amountMinor,
        amountDecimal: transaction.amountDecimal,
        direction: transaction.direction,
        runningBalanceMinor: transaction.runningBalanceMinor,
        isReconciled: transaction.isReconciled,
        isTrusted: transaction.isTrusted,
        trustedAtISO: transaction.trustedAtISO,
        createdAtISO: transaction.createdAtISO,
        updatedAtISO: transaction.updatedAtISO,
        rawRows: transaction.rawRows
    )
}

private func replaceTransaction(
    in plan: ConfirmedImportPlanDTO,
    at index: Int,
    with transaction: TransactionDTO
) -> [ConfirmedImportTransactionTemplateDTO] {
    var templates = plan.transactionTemplates
    templates[index] = ConfirmedImportTransactionTemplateDTO(
        transaction: transaction,
        eventEvidence: templates[index].eventEvidence
    )
    return templates
}

private final class CorruptPartialImportRepository: ImportSessionRepository {
    private let base: ImportSessionRepository
    private let corruption: PartialHydrationCorruption

    init(base: ImportSessionRepository, corruption: PartialHydrationCorruption) {
        self.base = base
        self.corruption = corruption
    }

    func createImportSession(_ payload: ImportSessionDTO) throws -> String {
        try base.createImportSession(payload)
    }

    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws {
        try base.updateImportSession(id, updates: updates)
    }

    func importSession(id: String) throws -> ImportSessionRecordDTO? {
        try base.importSession(id: id)
    }

    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO? {
        try base.priorImportedStatement(algorithm: algorithm, fingerprint: fingerprint)
    }

    func transactionEventOwners(
        keys: Set<TransactionEventIdentityKeyDTO>
    ) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] {
        try base.transactionEventOwners(keys: keys)
    }

    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String {
        try base.recordImportAttempt(payload)
    }

    func importAttempts(workspaceId: String) throws -> [ImportAttemptDTO] {
        try base.importAttempts(workspaceId: workspaceId)
    }

    func partialImportSummary(importSessionId: String) throws -> PartialImportSummaryDTO? {
        guard let summary = try base.partialImportSummary(importSessionId: importSessionId) else {
            return nil
        }
        switch corruption {
        case .missingSummary:
            return nil
        case .malformedPeriod:
            return copySummary(summary, statementStartDateISO: "not-a-date")
        case .malformedMoney:
            return copySummary(summary, openingBalanceDecimal: "invalid")
        case .decimalMinorMismatch:
            return copySummary(summary, openingBalanceMinor: summary.openingBalanceMinor + 1)
        case .summaryCount:
            return copySummary(summary, sourceRowCount: summary.sourceRowCount + 1)
        default:
            return summary
        }
    }

    func incomingRowDispositions(importSessionId: String) throws -> [IncomingRowDispositionDTO] {
        var rows = try base.incomingRowDispositions(importSessionId: importSessionId)
        guard !rows.isEmpty else { return rows }
        switch corruption {
        case .missingDisposition:
            rows.removeLast()
        case .duplicateDisposition:
            rows.append(rows[0])
        case .unknownDisposition:
            rows[0] = copyDisposition(rows[0], dispositionCode: "future_private_code")
        case .wrongDocument:
            rows[0] = copyDisposition(rows[0], documentId: "other-document")
        case .wrongSession:
            rows[0] = copyDisposition(rows[0], importSessionId: "other-session")
        case .missingNormalizedRow:
            rows[0] = copyDisposition(rows[0], normalizedRowId: "missing-row")
        case .wrongEventTransaction:
            rows[0] = copyDisposition(rows[0], eventTransactionId: .some("other-transaction"))
        default:
            break
        }
        return rows
    }

    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult {
        try base.commitImportHistory(payload)
    }
}

private final class PartialAttemptCountMismatchRepository: ImportSessionRepository {
    private let base: ImportSessionRepository

    init(base: ImportSessionRepository) {
        self.base = base
    }

    func createImportSession(_ payload: ImportSessionDTO) throws -> String {
        try base.createImportSession(payload)
    }

    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws {
        try base.updateImportSession(id, updates: updates)
    }

    func importSession(id: String) throws -> ImportSessionRecordDTO? {
        try base.importSession(id: id)
    }

    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO? {
        try base.priorImportedStatement(algorithm: algorithm, fingerprint: fingerprint)
    }

    func transactionEventOwners(
        keys: Set<TransactionEventIdentityKeyDTO>
    ) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] {
        try base.transactionEventOwners(keys: keys)
    }

    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String {
        try base.recordImportAttempt(payload)
    }

    func importAttempts(workspaceId: String) throws -> [ImportAttemptDTO] {
        try base.importAttempts(workspaceId: workspaceId).map { attempt in
            guard attempt.outcomeCode == ImportAttemptOutcome.partialImportCommitted.rawValue else {
                return attempt
            }
            return ImportAttemptDTO(
                id: attempt.id,
                workspaceId: attempt.workspaceId,
                createdAtISO: attempt.createdAtISO,
                outcomeCode: attempt.outcomeCode,
                coverageCode: attempt.coverageCode,
                accountDecisionCode: attempt.accountDecisionCode,
                guidanceCode: attempt.guidanceCode,
                persistenceCode: attempt.persistenceCode,
                transactionCount: attempt.transactionCount,
                accountId: attempt.accountId,
                importSessionId: attempt.importSessionId,
                documentId: attempt.documentId,
                relatedImportSessionId: attempt.relatedImportSessionId,
                sourceRowCount: attempt.sourceRowCount,
                importedTransactionCount: (attempt.importedTransactionCount ?? 0) + 1,
                recognizedExistingRowCount: attempt.recognizedExistingRowCount,
                blockedRowCount: attempt.blockedRowCount
            )
        }
    }

    func partialImportSummary(importSessionId: String) throws -> PartialImportSummaryDTO? {
        try base.partialImportSummary(importSessionId: importSessionId)
    }

    func incomingRowDispositions(importSessionId: String) throws -> [IncomingRowDispositionDTO] {
        try base.incomingRowDispositions(importSessionId: importSessionId)
    }

    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult {
        try base.commitImportHistory(payload)
    }
}
