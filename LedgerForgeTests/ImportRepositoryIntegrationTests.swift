// LedgerForgeTests/ImportRepositoryIntegrationTests.swift

import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct ImportRepositoryIntegrationTests {

    @Test func validImportPersistsValidatedRepositoryRecords() async throws {
        try runForEachProvider { provider in
            let fixture = makeValidFixture()
            let coordinator = DefaultImportPersistenceCoordinator(
                workspaceRepo: provider.workspaceRepo,
                accountRepo: provider.accountRepo,
                importSessionRepo: provider.importSessionRepo,
                transactionRepo: provider.transactionRepo,
                mapper: ImportPersistenceMapper(
                    workspaceId: "workspace-import-integration",
                    workspaceName: "Import Integration Workspace"
                )
            )

            let result = try coordinator.persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation
            )

            #expect(result.persisted)
            #expect(result.workspaceId == "workspace-import-integration")
            #expect(result.importSessionId == fixture.importSession.id.uuidString)
            #expect(result.transactionCount == fixture.financialDocument.transactions.count)

            let storedWorkspace = try provider.workspaceRepo.workspace(id: "workspace-import-integration")
            let workspace = try #require(storedWorkspace)
            #expect(workspace.name == "Import Integration Workspace")

            let accountId = try #require(result.accountId)
            let storedAccount = try provider.accountRepo.account(id: accountId)
            let account = try #require(storedAccount)
            #expect(account.workspaceId == "workspace-import-integration")
            #expect(account.institutionId == "Axis Bank")
            #expect(account.accountType == "bank")
            #expect(account.nativeCurrency == "INR")

            let storedImportSession = try provider.importSessionRepo.importSession(id: fixture.importSession.id.uuidString)
            let importSession = try #require(storedImportSession)
            #expect(importSession.workspaceId == "workspace-import-integration")
            #expect(importSession.userVisibleName == fixture.importSession.fileName)
            #expect(importSession.validationStatus == "passed")
            #expect(importSession.completedAtISO != nil)
            #expect(importSession.parserVersion == fixture.importSession.parserName)

            let transactions = try provider.transactionRepo.transactions(
                workspaceId: "workspace-import-integration",
                importSessionId: fixture.importSession.id.uuidString
            )
            #expect(transactions.count == 2)
            #expect(transactions.allSatisfy { $0.isTrusted })
            #expect(transactions.allSatisfy { $0.trustedAtISO != nil })
            #expect(transactions.allSatisfy { $0.workspaceId == "workspace-import-integration" })
            #expect(transactions.allSatisfy { $0.accountId == result.accountId })
            #expect(transactions.allSatisfy { $0.importSessionId == fixture.importSession.id.uuidString })
            #expect(transactions.allSatisfy { $0.documentId == nil })

            let orderedTransactions = transactions.sorted {
                if $0.postedDateISO == $1.postedDateISO {
                    return $0.id < $1.id
                }
                return $0.postedDateISO < $1.postedDateISO
            }

            #expect(orderedTransactions.map(\.amountMinor) == [10_000, -5_000])
            #expect(orderedTransactions.map(\.amountDecimal) == ["100", "-50"])
            #expect(orderedTransactions.map(\.direction) == ["credit", "debit"])
            #expect(orderedTransactions.map(\.runningBalanceMinor) == [110_000, 105_000])
        }
    }

    @Test func firstVerifiedImportCreatesOpaqueAccountAndSeedsIdentifier() async throws {
        try runForEachProvider { provider in
            let identifier = try makeVerifiedAccountIdentifier("001234567890123")
            let fixture = makeValidFixture(
                fileName: "axis-first-verified-import.csv",
                financialIdentifiers: [identifier]
            )
            let coordinator = makePersistenceCoordinator(provider: provider)

            let result = try coordinator.persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation
            )

            let accountId = try #require(result.accountId)
            let storedAccountValue = try provider.accountRepo.account(id: accountId)
            let storedAccount = try #require(storedAccountValue)
            let storedIdentifiers = try provider.accountRepo.identifiers(
                accountId: accountId,
                workspaceId: "workspace-import-integration"
            )
            let transactions = try provider.transactionRepo.transactions(
                workspaceId: "workspace-import-integration",
                importSessionId: fixture.importSession.id.uuidString
            )
            let storedImportSessionValue = try provider.importSessionRepo.importSession(
                id: fixture.importSession.id.uuidString
            )
            let storedImportSession = try #require(storedImportSessionValue)

            #expect(result.persisted)
            #expect(try provider.accountRepo.accounts(workspaceId: "workspace-import-integration").count == 1)
            #expect(accountId == "account-\(fixture.importSession.id.uuidString.lowercased())")
            #expect(!accountId.localizedCaseInsensitiveContains(fixture.importSession.fileName))
            #expect(!accountId.localizedCaseInsensitiveContains("Axis Bank"))
            #expect(!accountId.localizedCaseInsensitiveContains(storedAccount.name))
            #expect(storedIdentifiers.count == 1)
            #expect(storedIdentifiers.first?.scheme == identifier.kind.rawValue)
            #expect(storedIdentifiers.first?.identifier == identifier.normalizedValue)
            #expect(storedIdentifiers.first?.strength == identifier.strength.rawValue)
            #expect(storedIdentifiers.first?.verificationState == identifier.verificationState.rawValue)
            #expect(storedIdentifiers.first?.provenance == identifier.provenance.rawValue)
            #expect(transactions.allSatisfy { $0.accountId == accountId })
            #expect(storedImportSession.workspaceId == "workspace-import-integration")
        }
    }

    @Test func failedValidationDoesNotPersistTrustedTransactionsOrTrustedImport() async throws {
        try runForEachProvider { provider in
            let fixture = makeFailedValidationFixture()
            let observedAccountRepo = ObservingAccountRepository(base: provider.accountRepo)
            let coordinator = DefaultImportPersistenceCoordinator(
                workspaceRepo: provider.workspaceRepo,
                accountRepo: observedAccountRepo,
                importSessionRepo: provider.importSessionRepo,
                transactionRepo: provider.transactionRepo,
                mapper: ImportPersistenceMapper(
                    workspaceId: "workspace-failed-import",
                    workspaceName: "Failed Import Workspace"
                )
            )

            let result = try coordinator.persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation
            )

            #expect(!result.persisted)
            #expect(result.workspaceId == nil)
            #expect(result.importSessionId == nil)
            #expect(result.transactionCount == 0)
            #expect(observedAccountRepo.accountIdsCallCount == 0)
            #expect(observedAccountRepo.upsertCallCount == 0)
            #expect(observedAccountRepo.attachCallCount == 0)
            #expect(try provider.workspaceRepo.workspace(id: "workspace-failed-import") == nil)
            #expect(try provider.importSessionRepo.importSession(id: fixture.importSession.id.uuidString) == nil)
            #expect(try provider.transactionRepo.transactions(workspaceId: "workspace-failed-import", importSessionId: fixture.importSession.id.uuidString).isEmpty)
        }
    }

    @Test func missingIdentifiersCreateUnseededOpaqueAccountWithoutMetadataIdentity() async throws {
        try runForEachProvider { provider in
            let fixture = makeValidFixture(fileName: "axis-missing-identifier.csv")
            let result = try makePersistenceCoordinator(provider: provider).persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation
            )

            let accountId = try #require(result.accountId)
            #expect(result.persisted)
            #expect(accountId == "account-\(fixture.importSession.id.uuidString.lowercased())")
            #expect(!accountId.localizedCaseInsensitiveContains("axis"))
            #expect(!accountId.localizedCaseInsensitiveContains("missing"))
            #expect(try provider.accountRepo.identifiers(
                accountId: accountId,
                workspaceId: "workspace-import-integration"
            ).isEmpty)
        }
    }

    @Test func weakAndUnverifiedIdentifiersNeitherResolveNorAttach() async throws {
        try runForEachProvider { provider in
            let weak = try FinancialIdentifier(
                kind: .accountSuffix,
                rawValue: "0123",
                verificationState: .verified,
                provenance: .parserDerivedText
            )
            let unverifiedStrong = try FinancialIdentifier(
                kind: .institutionAccountId,
                rawValue: "001234567890123",
                verificationState: .unverified,
                provenance: .institutionStructuredField
            )
            let fixture = makeValidFixture(
                financialIdentifiers: [weak, unverifiedStrong]
            )

            let result = try makePersistenceCoordinator(provider: provider).persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation
            )

            let accountId = try #require(result.accountId)
            #expect(result.persisted)
            #expect(try provider.accountRepo.accounts(workspaceId: "workspace-import-integration").count == 1)
            #expect(try provider.accountRepo.identifiers(
                accountId: accountId,
                workspaceId: "workspace-import-integration"
            ).isEmpty)
        }
    }

    @Test func mapperRejectsUnsupportedCurrencyBeforePersistence() async throws {
        let fixture = makeValidFixture(currency: "JPY")
        let mapper = ImportPersistenceMapper(
            workspaceId: "workspace-unsupported-currency",
            workspaceName: "Unsupported Currency Workspace"
        )

        do {
            _ = try mapper.payload(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation,
                accountId: "account-unsupported-currency"
            )
            Issue.record("Expected unsupported currency mapping to fail before persistence.")
        } catch let error as ImportPersistenceError {
            #expect(error == .unsupportedCurrency("JPY"))
        }
    }

    @Test func appPersistenceBootstrapConfiguresDurableSQLiteProvider() async throws {
        let folder = try temporaryFolder(named: "LedgerForgePersistenceBootstrapTests")
        defer {
            LedgerForgeApp.configureInMemoryPersistenceForTesting()
            try? FileManager.default.removeItem(at: folder)
        }

        let dbPath = folder.appendingPathComponent("bootstrap.sqlite").path
        #expect(LedgerForgeApp.configurePersistence(path: dbPath))

        let workspace = WorkspaceDTO(
            id: "workspace-bootstrap",
            name: "Bootstrap Workspace",
            createdAtISO: "2026-07-10T00:00:00Z"
        )
        #expect(try DatabaseProvider.shared.workspaceRepo.upsertWorkspace(workspace) == workspace.id)

        LedgerForgeApp.configureInMemoryPersistenceForTesting()
        #expect(LedgerForgeApp.configurePersistence(path: dbPath))

        let restoredWorkspace = try DatabaseProvider.shared.workspaceRepo.workspace(id: workspace.id)
        #expect(restoredWorkspace == workspace)
    }

    @Test func persistedImportHydratesRuntimeStoresAfterSQLiteProviderRecreation() async throws {
        let folder = try temporaryFolder(named: "LedgerForgePersistenceRelaunchRegressionTests")
        defer {
            resetRuntimeStoresForImportIntegration()
            try? FileManager.default.removeItem(at: folder)
        }

        let dbPath = folder.appendingPathComponent("relaunch.sqlite").path
        let fixture = makeValidFixture()
        let initialProvider = try SQLiteRepositoryProvider(path: dbPath)
        let coordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: initialProvider.workspaceRepo,
            accountRepo: initialProvider.accountRepo,
            importSessionRepo: initialProvider.importSessionRepo,
            transactionRepo: initialProvider.transactionRepo,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-import-integration",
                workspaceName: "Import Integration Workspace"
            )
        )

        let persistence = try coordinator.persistValidatedImport(
            financialDocument: fixture.financialDocument,
            importSession: fixture.importSession,
            validation: fixture.validation
        )
        #expect(persistence.persisted)

        resetRuntimeStoresForImportIntegration()
        let relaunchedProvider = try SQLiteRepositoryProvider(path: dbPath)
        let hydrator = RepositoryStoreHydrator(
            accountRepo: relaunchedProvider.accountRepo,
            transactionRepo: relaunchedProvider.transactionRepo,
            workspaceId: "workspace-import-integration"
        )

        let hydration = try hydrator.hydrateIfNeeded()

        #expect(hydration.didHydrate)
        #expect(hydration.accountCount == 1)
        #expect(hydration.transactionCount == 2)
        #expect(AccountStore.shared.accounts.first?.name == "Axis Bank INR")
        #expect(AccountStore.shared.accounts.first?.institution == "Axis Bank")
        #expect(TransactionStore.shared.transactions.count == 2)
        #expect(TransactionStore.shared.transactions.allSatisfy { !$0.account.contains(".csv") })
        #expect(TransactionStore.shared.transactions.allSatisfy { $0.sourceBank == "Axis Bank" })
    }

    @Test func mapperUsesSuppliedAccountIdForAccountAndEveryTransaction() async throws {
        let fixture = makeValidFixture()
        let renamedFixture = makeValidFixture(fileName: "renamed-axis-export.csv")
        let mapper = ImportPersistenceMapper(
            workspaceId: "workspace-import-integration",
            workspaceName: "Import Integration Workspace"
        )
        let selectedAccountId = "account-selected-opaque-id"

        let payload = try mapper.payload(
            financialDocument: fixture.financialDocument,
            importSession: fixture.importSession,
            validation: fixture.validation,
            accountId: selectedAccountId
        )
        let renamedPayload = try mapper.payload(
            financialDocument: renamedFixture.financialDocument,
            importSession: renamedFixture.importSession,
            validation: renamedFixture.validation,
            accountId: selectedAccountId
        )

        #expect(payload.account.name == "Axis Bank INR")
        #expect(payload.account.institutionId == "Axis Bank")
        #expect(!payload.account.name.localizedCaseInsensitiveContains(".csv"))
        #expect(payload.account.id == selectedAccountId)
        #expect(payload.transactions.allSatisfy { $0.accountId == selectedAccountId })
        #expect(renamedPayload.account.id == selectedAccountId)
        #expect(renamedPayload.transactions.allSatisfy { $0.accountId == selectedAccountId })
    }

    @Test func laterVerifiedImportWithDifferentFilenameReusesExistingAccountUnchanged() async throws {
        try runForEachProvider { provider in
            let identifier = try makeVerifiedAccountIdentifier("001234567890123")
            let firstFixture = makeValidFixture(
                importSessionId: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                fileName: "axis-original.csv",
                financialIdentifiers: [identifier]
            )
            let secondFixture = makeValidFixture(
                importSessionId: UUID(uuidString: "66666666-7777-8888-9999-000000000000")!,
                fileName: "renamed-axis-statement.csv",
                financialIdentifiers: [identifier]
            )
            let firstCoordinator = makePersistenceCoordinator(provider: provider)
            let secondCoordinator = makePersistenceCoordinator(
                provider: provider,
                workspaceName: "Replacement Workspace Name Must Not Persist"
            )

            let firstResult = try firstCoordinator.persistValidatedImport(
                financialDocument: firstFixture.financialDocument,
                importSession: firstFixture.importSession,
                validation: firstFixture.validation
            )
            let originalAccountId = try #require(firstResult.accountId)
            let originalAccountValue = try provider.accountRepo.account(id: originalAccountId)
            let originalAccount = try #require(originalAccountValue)
            let originalWorkspaceValue = try provider.workspaceRepo.workspace(
                id: "workspace-import-integration"
            )
            let originalWorkspace = try #require(originalWorkspaceValue)
            let secondResult = try secondCoordinator.persistValidatedImport(
                financialDocument: secondFixture.financialDocument,
                importSession: secondFixture.importSession,
                validation: secondFixture.validation
            )

            #expect(firstResult.accountId == secondResult.accountId)
            #expect(try provider.accountRepo.accounts(workspaceId: "workspace-import-integration").count == 1)
            #expect(try provider.accountRepo.account(id: originalAccountId) == originalAccount)
            #expect(try provider.workspaceRepo.workspace(id: "workspace-import-integration") == originalWorkspace)
            #expect(try provider.accountRepo.identifiers(
                accountId: originalAccountId,
                workspaceId: "workspace-import-integration"
            ).count == 1)
            let secondTransactions = try provider.transactionRepo.transactions(
                workspaceId: "workspace-import-integration",
                importSessionId: secondFixture.importSession.id.uuidString
            )
            #expect(secondTransactions.allSatisfy { $0.accountId == originalAccountId })
        }
    }

    @Test func ambiguousIdentityThrowsBeforeEveryRepositoryWrite() async throws {
        let provider = makeInMemoryProvider()
        let accountRepo = ObservingAccountRepository(
            base: provider.accountRepo,
            forcedCandidates: ["account-a", "account-b"]
        )
        let identifier = try makeVerifiedAccountIdentifier("001234567890123")
        let fixture = makeValidFixture(financialIdentifiers: [identifier])
        let coordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: provider.workspaceRepo,
            accountRepo: accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-import-integration",
                workspaceName: "Import Integration Workspace"
            )
        )

        do {
            _ = try coordinator.persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation
            )
            Issue.record("Expected ambiguous identity to reject persistence.")
        } catch let error as ImportPersistenceCoordinationError {
            #expect(error == .ambiguousIdentity)
            #expect(error.localizedDescription == "Financial identity is ambiguous; import was not persisted.")
        }

        #expect(accountRepo.accountIdsCallCount == 1)
        #expect(accountRepo.upsertCallCount == 0)
        #expect(accountRepo.attachCallCount == 0)
        #expect(try provider.workspaceRepo.workspace(id: "workspace-import-integration") == nil)
        #expect(try provider.accountRepo.accounts(workspaceId: "workspace-import-integration").isEmpty)
        #expect(try provider.importSessionRepo.importSession(id: fixture.importSession.id.uuidString) == nil)
        #expect(try provider.transactionRepo.transactions(
            workspaceId: "workspace-import-integration",
            importSessionId: fixture.importSession.id.uuidString
        ).isEmpty)
    }

    @Test func conflictingIdentityPreservesEveryExistingRelationshipAndWritesNothing() async throws {
        try runForEachProvider { provider in
            let firstIdentifier = try makeVerifiedAccountIdentifier("001234567890123")
            let secondIdentifier = try makeVerifiedAccountIdentifier("009876543210987")
            let workspace = WorkspaceDTO(
                id: "workspace-import-integration",
                name: "Existing Workspace",
                createdAtISO: "2026-07-10T00:00:00Z"
            )
            let firstAccount = makeAccountDTO(id: "account-existing-a")
            let secondAccount = makeAccountDTO(id: "account-existing-b")
            _ = try provider.workspaceRepo.upsertWorkspace(workspace)
            _ = try provider.accountRepo.upsertAccount(firstAccount)
            _ = try provider.accountRepo.upsertAccount(secondAccount)
            _ = try provider.accountRepo.attachIdentifier(
                firstIdentifier.repositoryDTO(
                    accountId: firstAccount.id,
                    workspaceId: workspace.id,
                    createdAtISO: firstAccount.createdAtISO,
                    id: "identifier-existing-a"
                )
            )
            _ = try provider.accountRepo.attachIdentifier(
                secondIdentifier.repositoryDTO(
                    accountId: secondAccount.id,
                    workspaceId: workspace.id,
                    createdAtISO: secondAccount.createdAtISO,
                    id: "identifier-existing-b"
                )
            )
            let originalAccounts = try provider.accountRepo.accounts(workspaceId: workspace.id)
            let originalFirstIdentifiers = try provider.accountRepo.identifiers(
                accountId: firstAccount.id,
                workspaceId: workspace.id
            )
            let originalSecondIdentifiers = try provider.accountRepo.identifiers(
                accountId: secondAccount.id,
                workspaceId: workspace.id
            )
            let fixture = makeValidFixture(
                financialIdentifiers: [firstIdentifier, secondIdentifier]
            )

            do {
                _ = try makePersistenceCoordinator(provider: provider).persistValidatedImport(
                    financialDocument: fixture.financialDocument,
                    importSession: fixture.importSession,
                    validation: fixture.validation
                )
                Issue.record("Expected conflicting identity to reject persistence.")
            } catch let error as ImportPersistenceCoordinationError {
                #expect(error == .conflictingIdentity)
                #expect(error.localizedDescription == "Financial identity conflicts across accounts; import was not persisted.")
            }

            #expect(try provider.workspaceRepo.workspace(id: workspace.id) == workspace)
            #expect(try provider.accountRepo.accounts(workspaceId: workspace.id) == originalAccounts)
            #expect(try provider.accountRepo.identifiers(
                accountId: firstAccount.id,
                workspaceId: workspace.id
            ) == originalFirstIdentifiers)
            #expect(try provider.accountRepo.identifiers(
                accountId: secondAccount.id,
                workspaceId: workspace.id
            ) == originalSecondIdentifiers)
            #expect(try provider.importSessionRepo.importSession(id: fixture.importSession.id.uuidString) == nil)
            #expect(try provider.transactionRepo.transactions(
                workspaceId: workspace.id,
                importSessionId: fixture.importSession.id.uuidString
            ).isEmpty)
        }
    }

    @Test func identityFailureDiagnosticsDoNotExposeIdentifierOrSourceFragmentText() async throws {
        let developerConsole = DeveloperConsole()
        let provider = makeInMemoryProvider()
        let accountRepo = ObservingAccountRepository(
            base: provider.accountRepo,
            forcedCandidates: ["account-a", "account-b"]
        )
        let rawIdentifier = "001234567890123"
        let sourceFragment = "Statement Account Number : \(rawIdentifier)"
        let fixture = makeValidFixture(
            financialIdentifiers: [try makeVerifiedAccountIdentifier(rawIdentifier)]
        )
        let coordinator = DefaultImportPersistenceCoordinator(
            workspaceRepo: provider.workspaceRepo,
            accountRepo: accountRepo,
            importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo,
            mapper: ImportPersistenceMapper(
                workspaceId: "workspace-import-integration",
                workspaceName: "Import Integration Workspace"
            ),
            developerConsole: developerConsole
        )

        do {
            _ = try coordinator.persistValidatedImport(
                financialDocument: fixture.financialDocument,
                importSession: fixture.importSession,
                validation: fixture.validation
            )
        } catch {
            #expect(error.localizedDescription == "Financial identity is ambiguous; import was not persisted.")
        }

        let diagnosticText = developerConsole.entries.map { entry in
            [
                entry.message,
                DeveloperConsole.metadataText(for: entry) ?? ""
            ].joined(separator: " ")
        }.joined(separator: "\n")
        #expect(!diagnosticText.contains(rawIdentifier))
        #expect(!diagnosticText.contains(sourceFragment))
        #expect(diagnosticText.contains("Ambiguous"))
    }

}

private struct ImportRepositoryHandles {
    let workspaceRepo: WorkspaceRepository
    let accountRepo: AccountRepository
    let importSessionRepo: ImportSessionRepository
    let transactionRepo: TransactionRepository
}

private struct ImportRepositoryFixture {
    let financialDocument: FinancialDocument
    let importSession: ImportSession
    let validation: ImportValidationResult
}

private final class ObservingAccountRepository: AccountRepository {
    private let base: AccountRepository
    private let forcedCandidates: [String]?

    private(set) var accountIdsCallCount = 0
    private(set) var upsertCallCount = 0
    private(set) var attachCallCount = 0

    init(base: AccountRepository, forcedCandidates: [String]? = nil) {
        self.base = base
        self.forcedCandidates = forcedCandidates
    }

    func upsertAccount(_ account: AccountDTO) throws -> String {
        upsertCallCount += 1
        return try base.upsertAccount(account)
    }

    func account(id: String) throws -> AccountDTO? {
        try base.account(id: id)
    }

    func accounts(workspaceId: String) throws -> [AccountDTO] {
        try base.accounts(workspaceId: workspaceId)
    }

    func attachIdentifier(_ identifier: AccountIdentifierDTO) throws -> String {
        attachCallCount += 1
        return try base.attachIdentifier(identifier)
    }

    func identifiers(accountId: String, workspaceId: String) throws -> [AccountIdentifierDTO] {
        try base.identifiers(accountId: accountId, workspaceId: workspaceId)
    }

    func accountIds(workspaceId: String, scheme: String, identifier: String) throws -> [String] {
        accountIdsCallCount += 1
        if let forcedCandidates {
            return forcedCandidates
        }
        return try base.accountIds(
            workspaceId: workspaceId,
            scheme: scheme,
            identifier: identifier
        )
    }
}

private func runForEachProvider(_ body: (ImportRepositoryHandles) throws -> Void) throws {
    try body(makeInMemoryProvider())
    try withTemporarySQLiteProvider(body)
}

private func makeInMemoryProvider() -> ImportRepositoryHandles {
    let provider = InMemoryRepositoryProvider()
    return ImportRepositoryHandles(
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo
    )
}

private func makePersistenceCoordinator(
    provider: ImportRepositoryHandles,
    workspaceName: String = "Import Integration Workspace"
) -> DefaultImportPersistenceCoordinator {
    DefaultImportPersistenceCoordinator(
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo,
        mapper: ImportPersistenceMapper(
            workspaceId: "workspace-import-integration",
            workspaceName: workspaceName
        )
    )
}

private func withTemporarySQLiteProvider<T>(_ body: (ImportRepositoryHandles) throws -> T) throws -> T {
    let folder = try temporaryFolder(named: "LedgerForgeImportRepositoryIntegrationTests")
    defer {
        try? FileManager.default.removeItem(at: folder)
    }

    let provider = try SQLiteRepositoryProvider(path: folder.appendingPathComponent("integration.sqlite").path)
    let handles = ImportRepositoryHandles(
        workspaceRepo: provider.workspaceRepo,
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo
    )
    return try body(handles)
}

private func temporaryFolder(named name: String) throws -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent(name)
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

private func resetRuntimeStoresForImportIntegration() {
    AccountStore.shared.replaceAccounts([])
    TransactionStore.shared.replaceTransactions([])
}

private func makeValidFixture(
    currency: String = "INR",
    importSessionId: UUID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
    fileName: String = "repository-integration.csv",
    financialIdentifiers: [FinancialIdentifier] = []
) -> ImportRepositoryFixture {
    let transactions = [
        makeTransaction(
            date: Date(timeIntervalSince1970: 1_804_896_000),
            description: "Opening credit",
            debit: nil,
            credit: 100,
            amount: 100,
            balance: 1_100,
            currency: currency
        ),
        makeTransaction(
            date: Date(timeIntervalSince1970: 1_804_982_400),
            description: "Card payment",
            debit: 50,
            credit: nil,
            amount: -50,
            balance: 1_050,
            currency: currency
        )
    ]
    let financialDocument = makeFinancialDocument(
        transactions: transactions,
        fileName: fileName,
        financialIdentifiers: financialIdentifiers
    )
    let validation = ImportValidator.validate(financialDocument: financialDocument)
    let importSession = makeImportSession(
        id: importSessionId,
        fileName: fileName,
        transactionCount: transactions.count,
        validation: validation
    )

    return ImportRepositoryFixture(
        financialDocument: financialDocument,
        importSession: importSession,
        validation: validation
    )
}

private func makeFailedValidationFixture() -> ImportRepositoryFixture {
    let financialDocument = makeFinancialDocument(transactions: [])
    let validation = ImportValidator.validate(financialDocument: financialDocument)
    let importSession = makeImportSession(transactionCount: 0, validation: validation)

    return ImportRepositoryFixture(
        financialDocument: financialDocument,
        importSession: importSession,
        validation: validation
    )
}

private func makeFinancialDocument(
    transactions: [Transaction],
    fileName: String = "repository-integration.csv",
    financialIdentifiers: [FinancialIdentifier] = []
) -> FinancialDocument {
    FinancialDocument(
        sourceDocument: Document(
            filename: fileName,
            url: URL(fileURLWithPath: "/tmp/\(fileName)"),
            fileType: "CSV",
            importedAt: Date(timeIntervalSince1970: 1_804_896_000)
        ),
        metadata: DocumentMetadata(
            institution: .axis,
            documentType: .bankAccount,
            fileFormat: .csv,
            confidence: 1.0
        ),
        parserName: "Axis Bank Account",
        transactions: transactions,
        financialIdentifiers: financialIdentifiers,
        selectionReasons: ["Repository integration test parser selection."],
        createdAt: Date(timeIntervalSince1970: 1_804_896_000)
    )
}

private func makeImportSession(
    id: UUID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
    fileName: String = "repository-integration.csv",
    transactionCount: Int,
    validation: ImportValidationResult
) -> ImportSession {
    ImportSession(
        id: id,
        importedAt: Date(timeIntervalSince1970: 1_804_896_000),
        fileName: fileName,
        institution: .axis,
        documentType: .bankAccount,
        parserName: "Axis Bank Account",
        transactionCount: transactionCount,
        validation: validation
    )
}

private func makeTransaction(
    date: Date,
    description: String,
    debit: Decimal?,
    credit: Decimal?,
    amount: Decimal,
    balance: Decimal?,
    currency: String
) -> Transaction {
    Transaction(
        date: date,
        description: description,
        debit: debit,
        credit: credit,
        amount: amount,
        balance: balance,
        currency: currency,
        account: "Axis NRE",
        sourceBank: "Axis Bank",
        sourceFile: "repository-integration.csv"
    )
}

private func makeVerifiedAccountIdentifier(_ rawValue: String) throws -> FinancialIdentifier {
    try FinancialIdentifier(
        kind: .institutionAccountId,
        rawValue: rawValue,
        verificationState: .verified,
        provenance: .institutionStructuredField
    )
}

private func makeAccountDTO(id: String) -> AccountDTO {
    AccountDTO(
        id: id,
        workspaceId: "workspace-import-integration",
        name: "Existing \(id)",
        institutionId: "Axis Bank",
        accountType: "bank",
        nativeCurrency: "INR",
        description: "Existing account",
        createdAtISO: "2026-07-10T00:00:00Z"
    )
}
