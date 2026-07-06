// Database/Repository.swift
// Protocols that define persistence contracts for Sprint 10 Phase 1.
// Do not implement persistence details here; use adapters (in-memory, sqlite) that conform to these protocols.

import Foundation

protocol TransactionRepository {
    /// Save or upsert transactions produced by an import. Implementations should be idempotent for the same import.
    func saveTransactions(_ transactions: [Transaction], importSession: ImportSession?)

    /// Replace all persisted transactions (used for simple migration/testing scenarios).
    func replaceAll(_ transactions: [Transaction])

    /// Fetch all persisted transactions.
    func fetchAll() -> [Transaction]

    /// Fetch transactions belonging to a specific account identifier.
    func fetch(forAccount accountId: String) -> [Transaction]
}

protocol AccountRepository {
    /// Save or upsert accounts produced by import/account creation flows.
    func saveAccounts(_ accounts: [Account])

    /// Fetch all persisted accounts.
    func fetchAll() -> [Account]

    /// Find an account by a stable identifier.
    func find(accountId: String) -> Account?
}

protocol ImportSessionRepository {
    /// Persist an ImportSession record for audit/history.
    func save(_ session: ImportSession)

    /// Fetch all import sessions.
    func fetchAll() -> [ImportSession]
}

/// A minimal database provider exposing repositories. Implementations can be swapped in later (e.g. SQLite adapter).
final class DatabaseProvider {
    static var shared: DatabaseProvider = {
        // Default to in-memory provider; can be replaced during app startup in a future sprint.
        let inMemory = InMemoryRepositoryProvider()
        return DatabaseProvider(transactionRepo: inMemory.transactionRepo,
                                accountRepo: inMemory.accountRepo,
                                importSessionRepo: inMemory.importSessionRepo)
    }()

    let transactionRepo: TransactionRepository
    let accountRepo: AccountRepository
    let importSessionRepo: ImportSessionRepository

    init(transactionRepo: TransactionRepository, accountRepo: AccountRepository, importSessionRepo: ImportSessionRepository) {
        self.transactionRepo = transactionRepo
        self.accountRepo = accountRepo
        self.importSessionRepo = importSessionRepo
    }
}
