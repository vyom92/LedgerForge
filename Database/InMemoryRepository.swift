// Database/InMemoryRepository.swift
// In-memory repository implementations used as the default provider for Sprint 10 Phase 1.

import Foundation

// NOTE: These implementations intentionally keep behavior simple and synchronous.
// They are placeholders and conform to the repository interfaces so later work can
// swap in a SQLite-backed implementation without changing higher-level code.

final class InMemoryTransactionRepository: TransactionRepository {
    private var storage: [Transaction] = []
    private let queue = DispatchQueue(label: "ledgerforge.db.transactions", attributes: .concurrent)

    func saveTransactions(_ transactions: [Transaction], importSession: ImportSession?) {
        queue.async(flags: .barrier) {
            // Simple upsert: append incoming transactions. Real implementations should deduplicate.
            self.storage.append(contentsOf: transactions)
        }
    }

    func replaceAll(_ transactions: [Transaction]) {
        queue.async(flags: .barrier) {
            self.storage = transactions
        }
    }

    func fetchAll() -> [Transaction] {
        queue.sync { storage }
    }

    func fetch(forAccount accountId: String) -> [Transaction] {
        queue.sync { storage.filter { $0.account == accountId } }
    }
}

final class InMemoryAccountRepository: AccountRepository {
    private var storage: [Account] = []
    private let queue = DispatchQueue(label: "ledgerforge.db.accounts", attributes: .concurrent)

    func saveAccounts(_ accounts: [Account]) {
        queue.async(flags: .barrier) {
            // Upsert by id if present, otherwise append.
            for acc in accounts {
                if let idx = self.storage.firstIndex(where: { $0.id == acc.id }) {
                    self.storage[idx] = acc
                } else {
                    self.storage.append(acc)
                }
            }
        }
    }

    func fetchAll() -> [Account] {
        queue.sync { storage }
    }

    func find(accountId: String) -> Account? {
        queue.sync { storage.first(where: { $0.id == accountId }) }
    }
}

final class InMemoryImportSessionRepository: ImportSessionRepository {
    private var storage: [ImportSession] = []
    private let queue = DispatchQueue(label: "ledgerforge.db.importsessions", attributes: .concurrent)

    func save(_ session: ImportSession) {
        queue.async(flags: .barrier) {
            self.storage.append(session)
        }
    }

    func fetchAll() -> [ImportSession] {
        queue.sync { storage }
    }
}

/// Convenience provider that creates default in-memory repositories.
final class InMemoryRepositoryProvider {
    let transactionRepo: TransactionRepository
    let accountRepo: AccountRepository
    let importSessionRepo: ImportSessionRepository

    init() {
        self.transactionRepo = InMemoryTransactionRepository()
        self.accountRepo = InMemoryAccountRepository()
        self.importSessionRepo = InMemoryImportSessionRepository()
    }
}
