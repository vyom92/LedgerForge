import Foundation
import Testing
@testable import LedgerForge

@MainActor
@Suite(.serialized)
struct PersistenceAvailabilityTests {
    @Test func unavailableProviderCentrallyRejectsEveryRepositoryOperation() {
        let provider = DatabaseProvider.unavailable(reason: .migrationIntegrityFailed)
        let workspace = WorkspaceDTO(name: "Unavailable", createdAtISO: "2026-07-20T00:00:00Z")
        let account = AccountDTO(
            workspaceId: workspace.id,
            name: "Unavailable",
            nativeCurrency: "INR",
            createdAtISO: "2026-07-20T00:00:00Z"
        )
        let identifier = AccountIdentifierDTO(
            accountId: account.id,
            workspaceId: workspace.id,
            scheme: "test",
            identifier: "redacted-test-value",
            strength: "strong",
            verificationState: "verified",
            provenance: "test",
            createdAtISO: "2026-07-20T00:00:00Z"
        )
        let session = ImportSessionDTO(
            workspaceId: workspace.id,
            startedAtISO: "2026-07-20T00:00:00Z"
        )
        let attempt = ImportAttemptDTO(
            workspaceId: workspace.id,
            createdAtISO: "2026-07-20T00:00:00Z",
            outcomeCode: "persistence_failure",
            coverageCode: "unsupported_or_unevaluated",
            accountDecisionCode: "no_financial_mutation",
            guidanceCode: "persistence_unavailable",
            persistenceCode: "audit_write_unavailable",
            transactionCount: 0
        )
        let history = makeAtomicHistory(workspaceID: workspace.id, session: session, attempt: attempt)

        #expect(provider.persistenceState == .unavailable(.migrationIntegrityFailed))
        expectUnavailable { try provider.workspaceRepo.upsertWorkspace(workspace) }
        expectUnavailable { try provider.workspaceRepo.workspace(id: workspace.id) }
        expectUnavailable { try provider.transactionRepo.replaceTransactions(workspaceId: workspace.id, importSessionId: nil, transactions: []) }
        expectUnavailable { try provider.transactionRepo.transactions(workspaceId: workspace.id, importSessionId: nil) }
        expectUnavailable { try provider.transactionRepo.trustedTransactions(workspaceId: workspace.id) }
        expectUnavailable { try provider.accountRepo.upsertAccount(account) }
        expectUnavailable { try provider.accountRepo.updateAccountDisplayName(accountId: account.id, workspaceId: workspace.id, displayName: "Blocked") }
        expectUnavailable { try provider.accountRepo.account(id: account.id) }
        expectUnavailable { try provider.accountRepo.accounts(workspaceId: workspace.id) }
        expectUnavailable { try provider.accountRepo.attachIdentifier(identifier) }
        expectUnavailable { try provider.accountRepo.identifiers(accountId: account.id, workspaceId: workspace.id) }
        expectUnavailable { try provider.accountRepo.accountIds(workspaceId: workspace.id, scheme: "test", identifier: "redacted-test-value") }
        expectUnavailable { try provider.importSessionRepo.createImportSession(session) }
        expectUnavailable { try provider.importSessionRepo.updateImportSession(session.id, updates: PartialImportSessionUpdate(validationStatus: "failed")) }
        expectUnavailable { try provider.importSessionRepo.importSession(id: session.id) }
        expectUnavailable { try provider.importSessionRepo.priorImportedStatement(algorithm: "test", fingerprint: "test") }
        expectUnavailable { try provider.importSessionRepo.transactionEventOwners(keys: []) }
        expectUnavailable { try provider.importSessionRepo.recordImportAttempt(attempt) }
        expectUnavailable { try provider.importSessionRepo.importAttempts(workspaceId: workspace.id) }
        expectUnavailable { try provider.importSessionRepo.commitImportHistory(history) }
    }

    @Test func explicitTestAndDebugMemoryProvidersRemainUsableAndTruthful() throws {
        for purpose in [PersistenceNonDurablePurpose.testMemory, .debugMemory] {
            let provider = DatabaseProvider.intentionalNonDurable(purpose)
            let workspace = WorkspaceDTO(name: purpose.rawValue, createdAtISO: "2026-07-20T00:00:00Z")

            #expect(provider.persistenceState == .intentionalNonDurable(purpose))
            #expect(try provider.workspaceRepo.upsertWorkspace(workspace) == workspace.id)
            #expect(try provider.workspaceRepo.workspace(id: workspace.id) == workspace)
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func defaultProviderStartsUnavailableRatherThanMutableMemory() {
        DatabaseProvider.shared = .unavailable(reason: .notInitialized)

        #expect(DatabaseProvider.shared.persistenceState == .unavailable(.notInitialized))
        expectUnavailable { try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "default-workspace") }
    }

    @Test(.globalRuntimeStateIsolation)
    func SQLiteOpenFailurePublishesUnavailableWithoutMemoryFallbackOrRawDetails() throws {
        let folder = try temporaryFolder(named: "OpenFailure")
        defer {
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
            try? FileManager.default.removeItem(at: folder)
        }
        DeveloperConsole.shared.clear()

        #expect(!LedgerForgeApp.configurePersistence(path: folder.path))
        #expect(DatabaseProvider.shared.persistenceState == .unavailable(.databaseOpenFailed))
        expectUnavailable { try DatabaseProvider.shared.workspaceRepo.workspace(id: "blocked") }
        assertDiagnosticsArePrivacySafe(forbiddenPath: folder.path)
    }

    @Test(.globalRuntimeStateIsolation)
    func migrationIntegrityFailurePublishesUnavailableAndNeverPublishesDurableProvider() throws {
        let folder = try temporaryFolder(named: "IntegrityFailure")
        defer {
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
            try? FileManager.default.removeItem(at: folder)
        }
        let path = folder.appendingPathComponent("database.sqlite").path
        let seed = try SQLiteRepositoryProvider(path: path)
        try seed.database.executePrepared(
            sql: "UPDATE schema_migrations SET checksum = ? WHERE version = ?;",
            params: [String(repeating: "0", count: 64), 2]
        )
        seed.database.close()
        DeveloperConsole.shared.clear()

        #expect(!LedgerForgeApp.configurePersistence(path: path))
        #expect(DatabaseProvider.shared.persistenceState == .unavailable(.migrationIntegrityFailed))
        expectUnavailable { try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "default-workspace") }
        assertDiagnosticsArePrivacySafe(forbiddenPath: path)
    }

    @Test(.globalRuntimeStateIsolation)
    func migrationExecutionFailurePublishesBoundedUnavailableState() throws {
        let folder = try temporaryFolder(named: "ExecutionFailure")
        defer {
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
            try? FileManager.default.removeItem(at: folder)
        }
        let path = folder.appendingPathComponent("database.sqlite").path
        let seed = SQLiteDatabase(path: path)
        try seed.runMigrations([migrationV1])
        try seed.execute(sql: "ALTER TABLE import_sessions ADD COLUMN reader_version TEXT;")
        seed.close()
        DeveloperConsole.shared.clear()

        #expect(!LedgerForgeApp.configurePersistence(path: path))
        #expect(DatabaseProvider.shared.persistenceState == .unavailable(.migrationFailed))
        expectUnavailable { try DatabaseProvider.shared.importSessionRepo.importAttempts(workspaceId: "default-workspace") }
        assertDiagnosticsArePrivacySafe(forbiddenPath: path)
    }

    @Test(.globalRuntimeStateIsolation)
    func successfulBootstrapPublishesVerifiedSQLiteOnlyAfterValidation() throws {
        let folder = try temporaryFolder(named: "Verified")
        defer {
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
            try? FileManager.default.removeItem(at: folder)
        }
        let path = folder.appendingPathComponent("database.sqlite").path
        DatabaseProvider.shared = .unavailable(reason: .notInitialized)

        #expect(LedgerForgeApp.configurePersistence(path: path))
        #expect(DatabaseProvider.shared.persistenceState == .verifiedSQLite)
        #expect(try DatabaseProvider.shared.accountRepo.accounts(workspaceId: "default-workspace").isEmpty)
#if DEBUG
        #expect(DevelopmentDatabaseLifecycleCoordinator.shared.activeProfile?.kind == .current)
        #expect(DevelopmentDatabaseLifecycleCoordinator.shared.currentDatabaseURL == URL(fileURLWithPath: path).standardizedFileURL)
#endif
    }

    @Test(.globalRuntimeStateIsolation)
    func explicitTestingConfigurationPublishesIntentionalMemory() {
        LedgerForgeApp.configureInMemoryPersistenceForTesting()

        #expect(DatabaseProvider.shared.persistenceState == .intentionalNonDurable(.testMemory))
    }

    @Test func testHostConfigurationSelectsIsolatedPersistenceOnlyWhenExplicitlyEnabled() {
        #expect(LedgerForgeApp.usesIsolatedTestPersistence(environment: [:]) == false)
        #expect(LedgerForgeApp.usesIsolatedTestPersistence(environment: ["LEDGERFORGE_TEST_HOST": "0"]) == false)
        #expect(LedgerForgeApp.usesIsolatedTestPersistence(environment: ["LEDGERFORGE_TEST_HOST": "1"]))
    }

    @Test func persistencePresentationIsTruthfulBoundedAndPathFree() {
        let states: [PersistenceState] = [
            .verifiedSQLite,
            .unavailable(.migrationIntegrityFailed),
            .intentionalNonDurable(.testMemory),
            .intentionalNonDurable(.debugMemory),
            .intentionalNonDurable(.debugTemporarySQLite),
            .intentionalNonDurable(.debugMigrationSandboxSQLite)
        ]

        #expect(PersistenceState.verifiedSQLite.displayName == "Verified SQLite")
        #expect(PersistenceState.unavailable(.databaseOpenFailed).displayName == "Persistence Unavailable")
        #expect(PersistenceState.intentionalNonDurable(.testMemory).displayName == "Intentional Test Memory")
        #expect(PersistenceState.unavailable(.migrationFailed).recoveryGuidance != nil)

        for state in states {
            let presentation = [state.displayName, state.statusMessage, state.recoveryGuidance ?? ""].joined(separator: " ")
            #expect(!presentation.contains("/"))
            #expect(!presentation.localizedCaseInsensitiveContains("SQLITE_"))
            #expect(!presentation.localizedCaseInsensitiveContains("raw error"))
        }
    }

    @Test func importPreparationRejectsBeforeAttemptingToReadTheSource() async {
        var sourceAcquisitionCount = 0
        let engine = ImportEngine(
            sourceSnapshotAcquirer: { _ in
                sourceAcquisitionCount += 1
                throw SourceContentSnapshotError.acquisitionFailed
            },
            persistenceStateProvider: { .unavailable(.databaseOpenFailed) }
        )
        let nonexistent = URL(fileURLWithPath: "/private/path-that-must-not-be-read/statement.csv")

        await #expect(throws: PersistenceWorkflowError.unavailable) {
            try await engine.prepareImport(from: nonexistent)
        }
        #expect(sourceAcquisitionCount == 0)
    }

    @Test func preparedImportConfirmationRechecksAvailabilityBeforePersistence() async {
        let persistence = AvailabilityCountingPersistenceCoordinator()
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            persistenceStateProvider: { .unavailable(.migrationIntegrityFailed) }
        )

        let prepared = makePreparedImport()
        let result = await engine.commitPreparedImport(prepared)

        #expect(!result.persisted)
        #expect(result.validationPassed)
        #expect(result.errorMessage == PersistenceWorkflowError.unavailable.localizedDescription)
        #expect(result.recoveryRoute == .prepareAgain(.persistenceUnavailable))
        #expect(persistence.persistCallCount == 0)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }
    }

    @Test func unavailableLikeLocalizedErrorCannotGainFreshPreparationEligibility() async {
        let message = ImportPersistenceCoordinationError.persistenceUnavailable.localizedDescription
        let persistence = HostileAvailabilityPersistenceCoordinator(message: message)
        let engine = ImportEngine(
            importPersistenceCoordinator: persistence,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { .intentionalNonDurable(.testMemory) }
        )
        let prepared = makePreparedImport()

        let result = await engine.commitPreparedImport(prepared)

        #expect(!result.persisted)
        #expect(result.errorMessage == "The confirmed import could not be completed.")
        #expect(!result.errorMessage!.contains(message))
        #expect(result.recoveryRoute == .unavailable)
        #expect(persistence.persistCallCount == 1)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }
    }

    @Test func retryableContentionRecordsPrepareAgainWithoutAcceptedWrites() async throws {
        let memory = InMemoryRepositoryProvider()
        let confirmedRepository = RetryableContentionConfirmedImportRepository()
        let provider = DatabaseProvider(
            workspaceRepo: memory.workspaceRepo,
            transactionRepo: memory.transactionRepo,
            categoryRepo: memory.categoryRepo,
            accountRepo: memory.accountRepo,
            importSessionRepo: memory.importSessionRepo,
            confirmedImportRepo: confirmedRepository,
            generationToken: memory.generationToken,
            persistenceState: .intentionalNonDurable(.testMemory)
        )
        let workspaceID = "default-workspace"
        _ = try provider.workspaceRepo.upsertWorkspace(
            WorkspaceDTO(
                id: workspaceID,
                name: "Default Workspace",
                createdAtISO: "2026-07-29T00:00:00Z"
            )
        )
        let coordinator = DefaultImportPersistenceCoordinator(databaseProvider: provider)
        let engine = ImportEngine(
            importPersistenceCoordinator: coordinator,
            developerConsole: DeveloperConsole(),
            persistenceStateProvider: { provider.persistenceState },
            providerGenerationProvider: { provider.generationToken },
            rejectedAttemptHydration: {}
        )
        let prepared = makePreparedImport(providerGeneration: provider.generationToken)

        let result = await engine.commitPreparedImport(prepared)
        let attempts = try provider.importSessionRepo.importAttempts(workspaceId: workspaceID)
        let attempt = try #require(attempts.first)

        #expect(attempts.count == 1)
        #expect(result.recoveryRoute == .prepareAgain(.persistenceContention))
        #expect(!result.persisted)
        #expect(confirmedRepository.commitCount == 1)
        #expect(attempt.outcomeCode == ImportAttemptOutcome.sqliteContention.rawValue)
        #expect(attempt.guidanceCode == ImportAttemptGuidance.prepareAgain.rawValue)
        #expect(attempt.guidanceCode != ImportAttemptGuidance.retryConfirmation.rawValue)
        #expect(try provider.accountRepo.accounts(workspaceId: workspaceID).isEmpty)
        #expect(try provider.transactionRepo.trustedTransactions(workspaceId: workspaceID).isEmpty)
        #expect(try provider.importSessionRepo.importSession(id: prepared.importSession.id.uuidString) == nil)
        #expect(throws: SourceContentSnapshotError.invalidated) {
            try prepared.sourceSnapshot.withBytes { $0 }
        }
    }

    @Test func unavailableHydrationPreservesEveryExistingRuntimeStore() {
        let provider = DatabaseProvider.unavailable(reason: .migrationFailed)
        let accountStore = AccountStore()
        let transactionStore = TransactionStore()
        let importSessionStore = ImportSessionStore()
        let importAttemptStore = ImportAttemptStore()
        let existingAccount = Account(
            institution: "Existing",
            name: "Existing Account",
            type: .bank,
            currencyCode: "INR",
            currentBalance: 10
        )
        let existingTransaction = Transaction(
            statementDate: try! StatementDate(canonical: "2027-03-13"),
            description: "Existing transaction",
            debit: nil,
            credit: 10,
            amount: 10,
            balance: 10,
            currency: "INR",
            account: "Existing Account",
            sourceBank: "Existing",
            sourceFile: "existing.csv"
        )
        accountStore.replaceAccounts([existingAccount])
        transactionStore.replaceTransactions([existingTransaction])
        let hydrator = RepositoryStoreHydrator(
            databaseProvider: provider,
            accountStore: accountStore,
            transactionStore: transactionStore,
            importSessionStore: importSessionStore,
            importAttemptStore: importAttemptStore
        )

        #expect(throws: RepositoryStoreHydrationError.persistenceUnavailable) {
            try hydrator.hydrateIfNeeded(forceRefresh: true)
        }
        #expect(accountStore.accounts.map(\.id) == [existingAccount.id])
        #expect(transactionStore.transactions.map(\.id) == [existingTransaction.id])
        #expect(importSessionStore.importSessions.isEmpty)
        #expect(importAttemptStore.attempts.isEmpty)
    }

    @Test func accountMetadataMutationReportsPersistenceUnavailableWithoutMutation() {
        let provider = DatabaseProvider.unavailable(reason: .migrationIntegrityFailed)
        let coordinator = AccountMetadataCoordinator(databaseProvider: provider, developerConsole: nil)

        #expect(throws: AccountMetadataCoordinatorError.persistenceUnavailable) {
            try coordinator.updateDisplayName(
                accountId: "account-blocked",
                workspaceId: "workspace-blocked",
                displayName: "Blocked"
            )
        }
    }

    private func expectUnavailable<T>(_ operation: () throws -> T) {
        do {
            _ = try operation()
            Issue.record("Expected persistence-unavailable rejection")
        } catch let error as RepositoryError {
            guard case .persistenceUnavailable = error else {
                Issue.record("Expected persistence-unavailable rejection, received \(error)")
                return
            }
        } catch {
            Issue.record("Expected RepositoryError, received \(error)")
        }
    }

    private func makeAtomicHistory(
        workspaceID: String,
        session: ImportSessionDTO,
        attempt: ImportAttemptDTO
    ) -> AtomicImportHistoryDTO {
        let document = ImportedDocumentDTO(
            id: "document-unavailable",
            workspaceId: workspaceID,
            importSessionId: session.id,
            filename: "sanitized.csv",
            mimeType: "text/csv",
            sizeBytes: 0,
            sha256: "test",
            createdAtISO: "2026-07-20T00:00:00Z"
        )
        return AtomicImportHistoryDTO(
            document: document,
            fingerprint: DocumentFingerprintDTO(
                id: "fingerprint-unavailable",
                documentId: document.id,
                importSessionId: session.id,
                algorithm: "test",
                fingerprint: "test",
                fingerprintData: nil,
                createdAtISO: "2026-07-20T00:00:00Z"
            ),
            importSession: session,
            completedAtISO: "2026-07-20T00:00:00Z",
            transactions: [],
            successfulAttempt: attempt
        )
    }

    private func temporaryFolder(named name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-PersistenceAvailabilityTests", isDirectory: true)
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func assertDiagnosticsArePrivacySafe(forbiddenPath: String) {
        let text = DeveloperConsole.logText(from: DeveloperConsole.shared.entries)
        #expect(!text.contains(forbiddenPath))
        #expect(!text.localizedCaseInsensitiveContains("SQL:"))
        #expect(!text.localizedCaseInsensitiveContains("duplicate column"))
        #expect(!text.localizedCaseInsensitiveContains("unable to open database"))
    }

    private func makePreparedImport(
        providerGeneration suppliedProviderGeneration: ProviderGenerationToken? = nil
    ) -> PreparedImport {
        let transaction = Transaction(
            statementDate: try! StatementDate(canonical: "2027-03-13"),
            description: "Prepared credit",
            debit: nil,
            credit: 10,
            amount: 10,
            balance: 10,
            currency: "INR",
            account: "Prepared Account",
            sourceBank: "Axis Bank",
            sourceFile: "prepared.csv",
            statementTimezoneEvidence: .iana("Asia/Kolkata"),
            sourceProvenance: [
                TransactionSourceProvenance(
                    normalizedDocumentID: "availability-normalized-document",
                    normalizedRowID: "availability-normalized-row-1",
                    sourceOrdinal: 1,
                    normalizedRecordDigest: String.normalizedRecordDigest(values: ["availability", "1"]),
                    parserProfileID: AxisBankAccountParser.profileID,
                    parserProfileVersion: AxisBankAccountParser.profileVersion
                )
            ]
        )
        let document = FinancialDocument(
            sourceDocument: Document(
                filename: "prepared.csv",
                url: URL(fileURLWithPath: "/tmp/prepared.csv"),
                fileType: "CSV",
                importedAt: Date(timeIntervalSince1970: 1_804_896_000)
            ),
            metadata: DocumentMetadata(
                institution: .axis,
                documentType: .bankAccount,
                fileFormat: .csv,
                confidence: 1
            ),
            parserName: "Availability Test Parser",
            bookedCurrency: try! CurrencyCode("INR"),
            transactions: [transaction],
            selectionReasons: ["Availability test"],
            createdAt: Date(timeIntervalSince1970: 1_804_896_000)
        )
        let validation = ImportValidator.validate(financialDocument: document)
        return PreparedImport(
            sourceURL: document.sourceDocument.url,
            rawContents: "date,description,amount",
            fileName: document.sourceDocument.filename,
            detectedInstitution: document.metadata.institution,
            detectedDocumentType: document.metadata.documentType,
            parserName: document.parserName,
            financialDocument: document,
            validation: validation,
            importSession: ImportSession(
                importedAt: Date(timeIntervalSince1970: 1_804_896_000),
                fileName: document.sourceDocument.filename,
                institution: document.metadata.institution,
                documentType: document.metadata.documentType,
                parserName: document.parserName,
                transactionCount: document.transactions.count,
                validation: validation
            ),
            providerGeneration: suppliedProviderGeneration ?? DatabaseProvider.shared.generationToken
        )
    }
}

private final class AvailabilityCountingPersistenceCoordinator: ImportPersistenceCoordinating {
    private(set) var persistCallCount = 0

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        persistCallCount += 1
        return .skipped
    }
}

private struct HostileAvailabilityError: LocalizedError {
    let errorDescription: String?
}

private final class HostileAvailabilityPersistenceCoordinator: ImportPersistenceCoordinating {
    private let message: String
    private(set) var persistCallCount = 0

    init(message: String) {
        self.message = message
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult
    ) throws -> ImportPersistenceResult {
        persistCallCount += 1
        throw HostileAvailabilityError(errorDescription: message)
    }

    func persistValidatedImport(
        financialDocument: FinancialDocument,
        importSession: ImportSession,
        validation: ImportValidationResult,
        fingerprintSet: PreparedDocumentFingerprintSet,
        accountChoice: ImportAccountChoice?,
        providerGeneration: ProviderGenerationToken
    ) throws -> ImportPersistenceResult {
        persistCallCount += 1
        throw HostileAvailabilityError(errorDescription: message)
    }
}

private final class RetryableContentionConfirmedImportRepository: ConfirmedImportRepository {
    private(set) var commitCount = 0

    func reviewPartialImport(_ plan: ConfirmedImportPlanDTO) -> PartialImportReviewResult {
        .ordinaryFullImport
    }

    func commitConfirmedImport(_ plan: ConfirmedImportPlanDTO) -> ConfirmedImportRepositoryResult {
        commitCount += 1
        return .retryableContention
    }

    func commitReviewedPartialImport(
        _ plan: ReviewedPartialImportPlanDTO
    ) -> ConfirmedImportRepositoryResult {
        commitCount += 1
        return .retryableContention
    }
}
