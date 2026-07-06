// Database/Repository.swift
// Repository protocol definitions for LedgerForge persistence layer
// Generated for Sprint 10 Phase 2B

import Foundation

/// Minimal repository protocols used by the application. Implementations
/// must be provided by a DatabaseProvider (in-memory or SQLite-backed).
public protocol TransactionRepository {
    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [Any]) throws
    // Additional query methods will be added in later phases.
}

public protocol AccountRepository {
    func upsertAccount(_ account: [String: Any]) throws -> String
}

public protocol ImportSessionRepository {
    func createImportSession(_ payload: [String: Any]) throws -> String
    func updateImportSession(_ id: String, updates: [String: Any]) throws
}

/// DatabaseProvider exposes repository implementations. Set the shared
/// provider at application startup to swap implementations.
public final class DatabaseProvider {
    public static var shared: DatabaseProvider = DatabaseProvider(inMemory: true)

    public let transactionRepo: TransactionRepository
    public let accountRepo: AccountRepository
    public let importSessionRepo: ImportSessionRepository

    public init(transactionRepo: TransactionRepository, accountRepo: AccountRepository, importSessionRepo: ImportSessionRepository) {
        self.transactionRepo = transactionRepo
        self.accountRepo = accountRepo
        self.importSessionRepo = importSessionRepo
    }

    /// Convenience initializer for a statically tied in-memory provider when
    /// a concrete provider is not yet configured. The in-memory provider is
    /// implemented in later sprints; placeholder errors are thrown for now.
    public init(inMemory: Bool) {
        // lightweight placeholder implementations to avoid nils until provider is wired.
        self.transactionRepo = PlaceholderTransactionRepo()
        self.accountRepo = PlaceholderAccountRepo()
        self.importSessionRepo = PlaceholderImportSessionRepo()
    }
}

// MARK: - Placeholder repos
struct PlaceholderTransactionRepo: TransactionRepository {
    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [Any]) throws {
        // No-op placeholder; real implementation provided by SQLiteRepositoryProvider.
    }
}

struct PlaceholderAccountRepo: AccountRepository {
    func upsertAccount(_ account: [String: Any]) throws -> String {
        // Return a generated UUID so callers can proceed.
        return UUID().uuidString
    }
}

struct PlaceholderImportSessionRepo: ImportSessionRepository {
    func createImportSession(_ payload: [String: Any]) throws -> String {
        return UUID().uuidString
    }
    func updateImportSession(_ id: String, updates: [String: Any]) throws {
        // No-op
    }
}
