// LedgerForgeTests/RepositoryContractTests.swift

import Testing

struct RepositoryContractTests {

    @Test func repositoryPersistenceSmoke() async throws {
        // Use in-memory SQLite provider
        let provider = try SQLiteRepositoryProvider(path: ":memory:")

        let startedAt = ISO8601DateFormatter().string(from: Date())
        let importSession = ImportSessionDTO(workspaceId: "default", startedAtISO: startedAt)
        let importId = try provider.importSessionRepo.createImportSession(importSession)

        let account = AccountDTO(workspaceId: "default", name: "Test Account", nativeCurrency: "INR", createdAtISO: startedAt)
        let accountId = try provider.accountRepo.upsertAccount(account)

        let tx = TransactionDTO(workspaceId: "default", accountId: accountId, importSessionId: importId, postedDateISO: startedAt, nativeCurrency: "INR", amountMinor: 100, amountDecimal: "1.00", direction: "credit", createdAtISO: startedAt, rawRows: [TransactionRawRowDTO(normalizedRowId: "row1")])

        try provider.transactionRepo.replaceTransactions(workspaceId: "default", importSessionId: importId, transactions: [tx])

        let count = try provider.database.queryInt("SELECT COUNT(*) FROM transactions;")
        #expect(count == 1)
    }

}
