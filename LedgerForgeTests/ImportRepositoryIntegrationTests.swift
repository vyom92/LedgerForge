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
            #expect(account.institutionId == nil)
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
            #expect(transactions.map(\.amountMinor) == [10_000, -5_000])
            #expect(transactions.map(\.amountDecimal) == ["100", "-50"])
            #expect(transactions.map(\.direction) == ["credit", "debit"])
            #expect(transactions.map(\.runningBalanceMinor) == [110_000, 105_000])
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
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("LedgerForgeImportRepositoryIntegrationTests")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
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

private func makeValidFixture(currency: String = "INR") -> ImportRepositoryFixture {
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
    transactionCount: Int,
    validation: ImportValidationResult
) -> ImportSession {
    ImportSession(
        id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
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
