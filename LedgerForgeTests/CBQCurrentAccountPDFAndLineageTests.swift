import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct CBQCurrentAccountPDFAndLineageTests {
    @Test(.globalRuntimeStateIsolation)
    func exactPDFProfilesPreserveDistinctSourceSemantics() async throws {
        let context = makeContext(workspaceID: "cbq-pdf-profile-workspace", inMemory: true)
        let history = try await context.engine.prepareImport(from: fixture("cbq_current_account_history_pdf_v1_synthetic.pdf"))
        #expect(history.validation.passed)
        #expect(history.transactionCount == 4)
        #expect(history.financialDocument.financialIdentifiers.count == 1)
        #expect(history.financialDocument.cbqSourceIdentityObservations.isEmpty)
        #expect(history.financialDocument.declaredStatementPeriod == nil)
        #expect(history.financialDocument.transactions.allSatisfy {
            $0.financialDateRole == .postingDate &&
            $0.sourceProvenance.first?.parserProfileID == CBQCurrentAccountPDFParser.historyProfileID &&
            $0.sourceProvenance.first?.sourceTransactionDate == nil
        })
        #expect(history.financialDocument.transactions.map(\.statementDate) == history.financialDocument.transactions.map(\.statementDate).sorted(by: { $0! > $1! }))

        let monthly = try await context.engine.prepareImport(from: fixture("cbq_current_account_monthly_pdf_v1_synthetic.pdf"))
        #expect(monthly.validation.passed)
        #expect(monthly.transactionCount == 4)
        #expect(monthly.financialDocument.financialIdentifiers.isEmpty)
        #expect(monthly.financialDocument.cbqSourceIdentityObservations.count == 2)
        #expect(CBQSourceIdentityObservation.validatePair(monthly.financialDocument.cbqSourceIdentityObservations))
        #expect(monthly.financialDocument.transactions.allSatisfy {
            $0.financialDateRole == .postingDate &&
            $0.sourceProvenance.first?.parserProfileID == CBQCurrentAccountPDFParser.monthlyProfileID &&
            $0.sourceProvenance.first?.sourceTransactionDate != nil
        })
        #expect(monthly.financialDocument.sourceStatementEvidence?.openingBalance?.amount == 0)
        #expect(monthly.financialDocument.sourceStatementEvidence?.closingBalance?.amount == 975)
    }

    @Test(.globalRuntimeStateIsolation)
    func historyThenMonthlyCreatesOneAccountFourTransactionsAndAllSourceRows() async throws {
        try await verifyHistoryThenMonthly(inMemory: true)
        try await verifyHistoryThenMonthly(inMemory: false)
    }

    @Test(.globalRuntimeStateIsolation)
    func monthlyMaskThenMaskThenFullAttachesOneAccountWithoutRewritingCanonicalProvenance() async throws {
        try await verifyMonthlyMaskThenMaskThenFull(inMemory: true)
        try await verifyMonthlyMaskThenMaskThenFull(inMemory: false)
    }

    @Test(.globalRuntimeStateIsolation)
    func compatibleIdentityAmbiguityRequiresExplicitChoiceAndHonorsIt() async throws {
        try await verifyCompatibleAmbiguity(inMemory: true)
        try await verifyCompatibleAmbiguity(inMemory: false)
    }

    @Test(.globalRuntimeStateIsolation)
    func explicitlySelectedIncompatibleAccountRejectsWithoutFinancialWrites() async throws {
        try await verifyIncompatibleSelectionRejection(inMemory: true)
        try await verifyIncompatibleSelectionRejection(inMemory: false)
    }

    @Test(.globalRuntimeStateIsolation)
    func staleProviderGenerationRejectsCBQPlanWithoutResidue() async throws {
        try await verifyStaleGeneration(inMemory: true)
        try await verifyStaleGeneration(inMemory: false)
    }

    @Test(.globalRuntimeStateIsolation)
    func sqliteRelaunchPreservesMasksAndAllowsFullIdentifierAttachment() async throws {
        let workspace = "cbq-relaunch-\(UUID().uuidString)"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-CBQ-Relaunch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("relaunch.sqlite").path

        var sqlite = try SQLiteRepositoryProvider(path: path)
        var context = makeContext(workspaceID: workspace, sqlite: sqlite)
        let monthly = try await context.engine.prepareImport(from: fixture("cbq_current_account_monthly_pdf_v1_synthetic.pdf"))
        let first = try context.coordinator.persistValidatedImport(
            financialDocument: monthly.financialDocument, importSession: monthly.importSession,
            validation: monthly.validation, fingerprintSet: monthly.fingerprintSet,
            providerGeneration: context.provider.generationToken
        )
        let accountID = try #require(first.accountId)
        sqlite.database.close()

        sqlite = try SQLiteRepositoryProvider(path: path)
        defer { sqlite.database.close() }
        context = makeContext(workspaceID: workspace, sqlite: sqlite)
        #expect(try context.provider.accountRepo.cbqSourceIdentityRecords(workspaceId: workspace).count == 2)
        let history = try await context.engine.prepareImport(from: fixture("cbq_current_account_history_pdf_v1_synthetic.pdf"))
        #expect(try context.coordinator.reviewValidatedImport(financialDocument: history.financialDocument, validation: history.validation) == .matchedExisting(accountId: accountID))
        let second = try context.coordinator.persistValidatedImport(
            financialDocument: history.financialDocument, importSession: history.importSession,
            validation: history.validation, fingerprintSet: history.fingerprintSet,
            providerGeneration: context.provider.generationToken
        )
        #expect(second.accountId == accountID)
        #expect(second.transactionCount == 0)
        #expect(try context.provider.accountRepo.identifiers(accountId: accountID, workspaceId: workspace).count == 1)
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspace).count == 4)
    }

    @Test
    func accountAndIBANMasksMustBeMutuallyConsistent() throws {
        let account = try CBQSourceIdentityObservation(kind: .maskedAccountNumber, rawPattern: "4700-1XXXX6-001")
        let incompatibleIBAN = try CBQSourceIdentityObservation(kind: .maskedIBAN, rawPattern: "QA62CBQA0000000047009XXXX6001")
        #expect(!CBQSourceIdentityObservation.validatePair([account, incompatibleIBAN]))
    }

    private func verifyHistoryThenMonthly(inMemory: Bool) async throws {
        let workspace = "cbq-lineage-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let context = try makePersistentContext(workspaceID: workspace, inMemory: inMemory)
        defer { context.cleanup() }
        let history = try await context.engine.prepareImport(from: fixture("cbq_current_account_history_pdf_v1_synthetic.pdf"))
        let first = try context.coordinator.persistValidatedImport(
            financialDocument: history.financialDocument, importSession: history.importSession,
            validation: history.validation, fingerprintSet: history.fingerprintSet,
            providerGeneration: context.provider.generationToken
        )
        #expect(first.persisted)
        #expect(first.transactionCount == 4)
        let monthly = try await context.engine.prepareImport(from: fixture("cbq_current_account_monthly_pdf_v1_synthetic.pdf"))
        let second = try context.coordinator.persistValidatedImport(
            financialDocument: monthly.financialDocument, importSession: monthly.importSession,
            validation: monthly.validation, fingerprintSet: monthly.fingerprintSet,
            providerGeneration: context.provider.generationToken
        )
        #expect(second.persisted)
        #expect(second.transactionCount == 0)
        #expect(second.sourceRowCount == 4)
        #expect(second.recognizedExistingRowCount == 4)
        #expect(try context.provider.accountRepo.accounts(workspaceId: workspace).count == 1)
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspace).count == 4)
        #expect(try context.provider.accountRepo.cbqSourceIdentityRecords(workspaceId: workspace).count == 2)
        let attempt = try #require(try context.provider.importSessionRepo.importAttempts(workspaceId: workspace)
            .first { $0.importSessionId == monthly.importSession.id.uuidString })
        #expect(attempt.sourceRowCount == 4)
        #expect(attempt.importedTransactionCount == 0)
        #expect(attempt.recognizedExistingRowCount == 4)
        #expect(attempt.blockedRowCount == 0)
        let summaries = try context.provider.importSessionRepo.cbqSourceObservationSummaries(workspaceId: workspace)
        #expect(summaries.count == 2)
        #expect(Set(summaries.map(\.sourceFormatCode)) == ["history-pdf", "monthly-pdf"])
        #expect(summaries.allSatisfy { $0.sourceRowCount == 4 && $0.transactionObservationCount == 4 })
        #expect(summaries.reduce(0) { $0 + $1.importedTransactionCount } == 4)
        #expect(summaries.reduce(0) { $0 + $1.representedTransactionCount } == 4)

        let accounts = AccountStore()
        let transactions = TransactionStore()
        let sessions = ImportSessionStore()
        let attempts = ImportAttemptStore()
        let categories = CategoryStore()
        let hydrator = RepositoryStoreHydrator(
            databaseProvider: context.provider,
            accountStore: accounts,
            transactionStore: transactions,
            categoryStore: categories,
            importSessionStore: sessions,
            importAttemptStore: attempts,
            workspaceId: workspace,
            categoryReconciliationGate: nil,
            participatesInLifecycleGate: false
        )
        let hydration = try hydrator.hydrateIfNeeded()
        #expect(hydration.transactionCount == 4)
        #expect(transactions.transactions.allSatisfy {
            $0.repositorySourceDocumentName?.contains("history") == true &&
            $0.repositoryPreferredSourceDocumentName?.contains("monthly") == true &&
            $0.repositoryPreferredSourceFormatCode == "monthly-pdf" &&
            $0.repositoryPreferredSourceTransactionDate != nil
        })
    }

    private func verifyMonthlyMaskThenMaskThenFull(inMemory: Bool) async throws {
        let workspace = "cbq-mask-order-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let context = try makePersistentContext(workspaceID: workspace, inMemory: inMemory)
        defer { context.cleanup() }

        let firstMonthly = try await context.engine.prepareImport(from: fixture("cbq_current_account_monthly_pdf_v1_synthetic.pdf"))
        let first = try persist(firstMonthly, with: context)
        #expect(first.persisted)
        #expect(first.transactionCount == 4)
        let accountID = try #require(first.accountId)
        #expect(try context.provider.accountRepo.identifiers(accountId: accountID, workspaceId: workspace).isEmpty)

        let secondMonthly = try await context.engine.prepareImport(from: fixture("cbq_current_account_monthly_pdf_v1_synthetic_variant.pdf"))
        #expect(try context.coordinator.reviewValidatedImport(financialDocument: secondMonthly.financialDocument, validation: secondMonthly.validation) == .matchedExisting(accountId: accountID))
        let second = try persist(secondMonthly, with: context)
        #expect(second.persisted)
        #expect(second.transactionCount == 0)

        let history = try await context.engine.prepareImport(from: fixture("cbq_current_account_history_pdf_v1_synthetic.pdf"))
        #expect(try context.coordinator.reviewValidatedImport(financialDocument: history.financialDocument, validation: history.validation) == .matchedExisting(accountId: accountID))
        let third = try persist(history, with: context)
        #expect(third.persisted)
        #expect(third.transactionCount == 0)

        #expect(try context.provider.accountRepo.accounts(workspaceId: workspace).count == 1)
        let identifiers = try context.provider.accountRepo.identifiers(accountId: accountID, workspaceId: workspace)
        #expect(identifiers.count == 1)
        #expect(identifiers.first?.scheme == FinancialIdentifierKind.institutionAccountId.rawValue)
        #expect(try context.provider.accountRepo.cbqSourceIdentityRecords(workspaceId: workspace).count == 4)
        let summaries = try context.provider.importSessionRepo.cbqSourceObservationSummaries(workspaceId: workspace)
        #expect(summaries.count == 3)
        #expect(summaries.allSatisfy { $0.sourceRowCount == 4 && $0.transactionObservationCount == 4 })

        let transactions = try context.provider.transactionRepo.trustedTransactions(workspaceId: workspace)
        #expect(transactions.count == 4)
        let canonicalDocumentID = "document-\(firstMonthly.importSession.id.uuidString.lowercased())"
        #expect(transactions.allSatisfy { $0.documentId == canonicalDocumentID })
        let preferred = try context.provider.importSessionRepo.preferredTransactionSources(workspaceId: workspace)
        #expect(preferred.count == 4)
        #expect(preferred.allSatisfy {
            $0.sourceFormatCode == "monthly-pdf" &&
            $0.sourceTransactionDateISO != nil &&
            $0.documentId != "document-\(history.importSession.id.uuidString.lowercased())"
        })
    }

    private func verifyCompatibleAmbiguity(inMemory: Bool) async throws {
        let workspace = "cbq-ambiguity-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let context = try makePersistentContext(workspaceID: workspace, inMemory: inMemory)
        defer { context.cleanup() }
        try seedStrongCBQAccount(id: "cbq-compatible-a", fullAccount: "4700123456001", workspace: workspace, provider: context.provider)
        try seedStrongCBQAccount(id: "cbq-compatible-b", fullAccount: "4700199996001", workspace: workspace, provider: context.provider)

        let monthly = try await context.engine.prepareImport(from: fixture("cbq_current_account_monthly_pdf_v1_synthetic.pdf"))
        #expect(try context.coordinator.reviewValidatedImport(financialDocument: monthly.financialDocument, validation: monthly.validation) == .choiceRequired(eligibleAccountIds: ["cbq-compatible-a", "cbq-compatible-b"]))
        let result = try context.coordinator.persistValidatedImport(
            financialDocument: monthly.financialDocument,
            importSession: monthly.importSession,
            validation: monthly.validation,
            fingerprintSet: monthly.fingerprintSet,
            accountChoice: .useExistingAccount(accountId: "cbq-compatible-b"),
            providerGeneration: context.provider.generationToken
        )
        #expect(result.persisted)
        #expect(result.accountId == "cbq-compatible-b")
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspace).allSatisfy { $0.accountId == "cbq-compatible-b" })
    }

    private func verifyIncompatibleSelectionRejection(inMemory: Bool) async throws {
        let workspace = "cbq-incompatible-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let context = try makePersistentContext(workspaceID: workspace, inMemory: inMemory)
        defer { context.cleanup() }
        try seedStrongCBQAccount(id: "cbq-compatible", fullAccount: "4700123456001", workspace: workspace, provider: context.provider)
        try seedStrongCBQAccount(id: "cbq-incompatible", fullAccount: "8800123456999", workspace: workspace, provider: context.provider)
        let monthly = try await context.engine.prepareImport(from: fixture("cbq_current_account_monthly_pdf_v1_synthetic.pdf"))
        #expect(try context.coordinator.reviewValidatedImport(financialDocument: monthly.financialDocument, validation: monthly.validation) == .matchedExisting(accountId: "cbq-compatible"))

        do {
            _ = try context.coordinator.persistValidatedImport(
                financialDocument: monthly.financialDocument,
                importSession: monthly.importSession,
                validation: monthly.validation,
                fingerprintSet: monthly.fingerprintSet,
                accountChoice: .useExistingAccount(accountId: "cbq-incompatible"),
                providerGeneration: context.provider.generationToken
            )
            Issue.record("Expected incompatible CBQ account selection to reject")
        } catch let failure as ImportPersistenceCommitFailure {
            #expect(failure.originalError as? ImportPersistenceCoordinationError == .conflictingIdentity)
        }
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspace).isEmpty)
        #expect(try context.provider.accountRepo.cbqSourceIdentityRecords(workspaceId: workspace).isEmpty)
        #expect(try context.provider.importSessionRepo.importSession(id: monthly.importSession.id.uuidString) == nil)
    }

    private func verifyStaleGeneration(inMemory: Bool) async throws {
        let workspace = "cbq-stale-generation-\(inMemory ? "memory" : "sqlite")-\(UUID().uuidString)"
        let context = try makePersistentContext(workspaceID: workspace, inMemory: inMemory)
        defer { context.cleanup() }
        let monthly = try await context.engine.prepareImport(from: fixture("cbq_current_account_monthly_pdf_v1_synthetic.pdf"))
        do {
            _ = try context.coordinator.persistValidatedImport(
                financialDocument: monthly.financialDocument,
                importSession: monthly.importSession,
                validation: monthly.validation,
                fingerprintSet: monthly.fingerprintSet,
                providerGeneration: ProviderGenerationToken()
            )
            Issue.record("Expected stale provider generation to reject")
        } catch let failure as ImportPersistenceCommitFailure {
            #expect(failure.originalError as? ImportPersistenceCoordinationError == .staleProviderGeneration)
        }
        #expect(try context.provider.accountRepo.accounts(workspaceId: workspace).isEmpty)
        #expect(try context.provider.transactionRepo.trustedTransactions(workspaceId: workspace).isEmpty)
        #expect(try context.provider.accountRepo.cbqSourceIdentityRecords(workspaceId: workspace).isEmpty)
    }

    private func persist(
        _ prepared: PreparedImport,
        with context: (engine: ImportEngine, coordinator: DefaultImportPersistenceCoordinator, provider: DatabaseProvider, cleanup: () -> Void)
    ) throws -> ImportPersistenceResult {
        try context.coordinator.persistValidatedImport(
            financialDocument: prepared.financialDocument,
            importSession: prepared.importSession,
            validation: prepared.validation,
            fingerprintSet: prepared.fingerprintSet,
            providerGeneration: context.provider.generationToken
        )
    }

    private func seedStrongCBQAccount(
        id: String,
        fullAccount: String,
        workspace: String,
        provider: DatabaseProvider
    ) throws {
        let now = "2026-08-17T00:00:00Z"
        _ = try provider.workspaceRepo.upsertWorkspace(WorkspaceDTO(id: workspace, name: "CBQ Synthetic", createdAtISO: now))
        _ = try provider.accountRepo.upsertAccount(AccountDTO(
            id: id, workspaceId: workspace, name: id,
            institutionId: Institution.cbq.rawValue, accountType: "bank", nativeCurrency: "QAR",
            createdAtISO: now
        ))
        _ = try provider.accountRepo.attachIdentifier(AccountIdentifierDTO(
            id: "identifier-\(id)", accountId: id, workspaceId: workspace,
            scheme: FinancialIdentifierKind.institutionAccountId.rawValue,
            identifier: fullAccount, strength: "strong", verificationState: "verified",
            provenance: "institution_structured_field", createdAtISO: now
        ))
    }

    private func makeContext(workspaceID: String, inMemory: Bool) -> (engine: ImportEngine, coordinator: DefaultImportPersistenceCoordinator, provider: DatabaseProvider) {
        let provider = DatabaseProvider(inMemory: inMemory)
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "CBQ Synthetic")
        )
        return (ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { .init(didHydrate: true, accountCount: 0, transactionCount: 0) }
        ), coordinator, provider)
    }

    private func makeContext(workspaceID: String, sqlite: SQLiteRepositoryProvider) -> (engine: ImportEngine, coordinator: DefaultImportPersistenceCoordinator, provider: DatabaseProvider) {
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "CBQ Synthetic")
        )
        return (ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { .init(didHydrate: true, accountCount: 0, transactionCount: 0) }
        ), coordinator, provider)
    }

    private func makePersistentContext(workspaceID: String, inMemory: Bool) throws -> (engine: ImportEngine, coordinator: DefaultImportPersistenceCoordinator, provider: DatabaseProvider, cleanup: () -> Void) {
        if inMemory {
            let context = makeContext(workspaceID: workspaceID, inMemory: true)
            return (context.engine, context.coordinator, context.provider, {})
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-CBQ-Lineage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sqlite = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("lineage.sqlite").path)
        let provider = DatabaseProvider.verifiedSQLite(sqlite, protectsGeneration: false)
        let coordinator = DefaultImportPersistenceCoordinator(
            databaseProvider: provider,
            mapper: ImportPersistenceMapper(workspaceId: workspaceID, workspaceName: "CBQ Synthetic")
        )
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            forcedHydration: { .init(didHydrate: true, accountCount: 0, transactionCount: 0) }
        )
        return (engine, coordinator, provider, {
            sqlite.database.close()
            try? FileManager.default.removeItem(at: folder)
        })
    }

    private func fixture(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/CBQ/Synthetic/\(name)")
    }
}
