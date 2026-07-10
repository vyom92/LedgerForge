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

    @Test func failedValidationDoesNotPersistTrustedTransactionsOrTrustedImport() async throws {
        try runForEachProvider { provider in
            let fixture = makeFailedValidationFixture()
            let coordinator = DefaultImportPersistenceCoordinator(
                workspaceRepo: provider.workspaceRepo,
                accountRepo: provider.accountRepo,
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
            #expect(try provider.workspaceRepo.workspace(id: "workspace-failed-import") == nil)
            #expect(try provider.importSessionRepo.importSession(id: fixture.importSession.id.uuidString) == nil)
            #expect(try provider.transactionRepo.transactions(workspaceId: "workspace-failed-import", importSessionId: fixture.importSession.id.uuidString).isEmpty)
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
                validation: fixture.validation
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

    @Test func mapperUsesCleanAccountDisplayNameWithoutChangingStableAccountIdentity() async throws {
        let fixture = makeValidFixture()
        let mapper = ImportPersistenceMapper(
            workspaceId: "workspace-import-integration",
            workspaceName: "Import Integration Workspace"
        )

        let payload = try mapper.payload(
            financialDocument: fixture.financialDocument,
            importSession: fixture.importSession,
            validation: fixture.validation
        )

        #expect(payload.account.name == "Axis Bank INR")
        #expect(payload.account.institutionId == "Axis Bank")
        #expect(!payload.account.name.localizedCaseInsensitiveContains(".csv"))
        #expect(payload.account.id == "account-workspace-import-integration-axis-bank-repository-integration-csv")
    }

    @Test func repeatImportFromSameStableIdentityDoesNotCreateDuplicateRepositoryAccounts() async throws {
        try runForEachProvider { provider in
            let firstFixture = makeValidFixture(
                importSessionId: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
            )
            let secondFixture = makeValidFixture(
                importSessionId: UUID(uuidString: "66666666-7777-8888-9999-000000000000")!
            )
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

            let firstResult = try coordinator.persistValidatedImport(
                financialDocument: firstFixture.financialDocument,
                importSession: firstFixture.importSession,
                validation: firstFixture.validation
            )
            let secondResult = try coordinator.persistValidatedImport(
                financialDocument: secondFixture.financialDocument,
                importSession: secondFixture.importSession,
                validation: secondFixture.validation
            )

            #expect(firstResult.accountId == secondResult.accountId)
            #expect(try provider.accountRepo.accounts(workspaceId: "workspace-import-integration").count == 1)
            #expect(try provider.accountRepo.accounts(workspaceId: "workspace-import-integration").first?.institutionId == "Axis Bank")
        }
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
    importSessionId: UUID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
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
    let financialDocument = makeFinancialDocument(transactions: transactions)
    let validation = ImportValidator.validate(financialDocument: financialDocument)
    let importSession = makeImportSession(
        id: importSessionId,
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

private func makeFinancialDocument(transactions: [Transaction]) -> FinancialDocument {
    FinancialDocument(
        sourceDocument: Document(
            filename: "repository-integration.csv",
            url: URL(fileURLWithPath: "/tmp/repository-integration.csv"),
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
        selectionReasons: ["Repository integration test parser selection."],
        createdAt: Date(timeIntervalSince1970: 1_804_896_000)
    )
}

private func makeImportSession(
    id: UUID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
    transactionCount: Int,
    validation: ImportValidationResult
) -> ImportSession {
    ImportSession(
        id: id,
        importedAt: Date(timeIntervalSince1970: 1_804_896_000),
        fileName: "repository-integration.csv",
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
