// Database/Repository.swift
// Repository protocol definitions for LedgerForge persistence layer
// Repository contracts are part of the frozen persistence boundary.

import Foundation

public enum RepositoryError: Error, LocalizedError {
    case providerNotConfigured(String)
    case recordNotFound(String)
    case relationshipViolation(String)
    case conflictingAccountIdentifier(workspaceId: String, scheme: String, identifier: String, existingAccountId: String, attemptedAccountId: String)

    public var errorDescription: String? {
        switch self {
        case .providerNotConfigured(let repositoryName):
            return "\(repositoryName) is not configured. Install a concrete DatabaseProvider before using repository APIs."
        case .recordNotFound(let message):
            return message
        case .relationshipViolation(let message):
            return message
        case .conflictingAccountIdentifier(let workspaceId, let scheme, _, let existingAccountId, let attemptedAccountId):
            return "Identifier \(scheme) is already assigned in workspace \(workspaceId) to account \(existingAccountId), not \(attemptedAccountId)."
        }
    }
}

/// Strongly-typed repository protocols used by the application. Implementations
/// must be provided by a DatabaseProvider (in-memory or SQLite-backed).
public protocol WorkspaceRepository {
    func upsertWorkspace(_ workspace: WorkspaceDTO) throws -> String
    func workspace(id: String) throws -> WorkspaceDTO?
}

public protocol TransactionRepository {
    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [TransactionDTO]) throws
    func transactions(workspaceId: String, importSessionId: String?) throws -> [TransactionDTO]
    func trustedTransactions(workspaceId: String) throws -> [TransactionDTO]
}

public protocol AccountRepository {
    func upsertAccount(_ account: AccountDTO) throws -> String
    @discardableResult
    func updateAccountDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool
    func account(id: String) throws -> AccountDTO?
    func accounts(workspaceId: String) throws -> [AccountDTO]
    func attachIdentifier(_ identifier: AccountIdentifierDTO) throws -> String
    func identifiers(accountId: String, workspaceId: String) throws -> [AccountIdentifierDTO]
    func accountIds(workspaceId: String, scheme: String, identifier: String) throws -> [String]
}

public protocol ImportSessionRepository {
    func createImportSession(_ payload: ImportSessionDTO) throws -> String
    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws
    func importSession(id: String) throws -> ImportSessionRecordDTO?
    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO?
    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult
}

public struct PartialImportSessionUpdate {
    public var validationStatus: String?
    public var completedAtISO: String?

    public init(validationStatus: String? = nil, completedAtISO: String? = nil) {
        self.validationStatus = validationStatus
        self.completedAtISO = completedAtISO
    }
}

/// DatabaseProvider exposes repository implementations. Set the shared
/// provider at application startup to swap implementations.
public final class DatabaseProvider {
    public static var shared: DatabaseProvider = DatabaseProvider(inMemory: true)

    public let workspaceRepo: WorkspaceRepository
    public let transactionRepo: TransactionRepository
    public let accountRepo: AccountRepository
    public let importSessionRepo: ImportSessionRepository

    public init(workspaceRepo: WorkspaceRepository, transactionRepo: TransactionRepository, accountRepo: AccountRepository, importSessionRepo: ImportSessionRepository) {
        self.workspaceRepo = workspaceRepo
        self.transactionRepo = transactionRepo
        self.accountRepo = accountRepo
        self.importSessionRepo = importSessionRepo
    }

    /// Convenience initializer for an isolated in-memory provider. This is
    /// intended for contract tests and non-persistent development fixtures.
    public init(inMemory: Bool) {
        let provider = InMemoryRepositoryProvider()
        self.workspaceRepo = provider.workspaceRepo
        self.transactionRepo = provider.transactionRepo
        self.accountRepo = provider.accountRepo
        self.importSessionRepo = provider.importSessionRepo
    }
}

// MARK: - Placeholder repos
struct PlaceholderWorkspaceRepo: WorkspaceRepository {
    func upsertWorkspace(_ workspace: WorkspaceDTO) throws -> String {
        throw RepositoryError.providerNotConfigured("WorkspaceRepository")
    }

    func workspace(id: String) throws -> WorkspaceDTO? {
        throw RepositoryError.providerNotConfigured("WorkspaceRepository")
    }
}

struct PlaceholderTransactionRepo: TransactionRepository {
    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [TransactionDTO]) throws {
        throw RepositoryError.providerNotConfigured("TransactionRepository")
    }

    func transactions(workspaceId: String, importSessionId: String?) throws -> [TransactionDTO] {
        throw RepositoryError.providerNotConfigured("TransactionRepository")
    }

    func trustedTransactions(workspaceId: String) throws -> [TransactionDTO] {
        throw RepositoryError.providerNotConfigured("TransactionRepository")
    }
}

struct PlaceholderAccountRepo: AccountRepository {
    func upsertAccount(_ account: AccountDTO) throws -> String {
        throw RepositoryError.providerNotConfigured("AccountRepository")
    }

    func updateAccountDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool {
        throw RepositoryError.providerNotConfigured("AccountRepository")
    }

    func account(id: String) throws -> AccountDTO? {
        throw RepositoryError.providerNotConfigured("AccountRepository")
    }

    func accounts(workspaceId: String) throws -> [AccountDTO] {
        throw RepositoryError.providerNotConfigured("AccountRepository")
    }

    func attachIdentifier(_ identifier: AccountIdentifierDTO) throws -> String {
        throw RepositoryError.providerNotConfigured("AccountRepository")
    }

    func identifiers(accountId: String, workspaceId: String) throws -> [AccountIdentifierDTO] {
        throw RepositoryError.providerNotConfigured("AccountRepository")
    }

    func accountIds(workspaceId: String, scheme: String, identifier: String) throws -> [String] {
        throw RepositoryError.providerNotConfigured("AccountRepository")
    }
}

struct PlaceholderImportSessionRepo: ImportSessionRepository {
    func createImportSession(_ payload: ImportSessionDTO) throws -> String {
        throw RepositoryError.providerNotConfigured("ImportSessionRepository")
    }
    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws {
        throw RepositoryError.providerNotConfigured("ImportSessionRepository")
    }

    func importSession(id: String) throws -> ImportSessionRecordDTO? {
        throw RepositoryError.providerNotConfigured("ImportSessionRepository")
    }

    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO? {
        throw RepositoryError.providerNotConfigured("ImportSessionRepository")
    }

    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult {
        throw RepositoryError.providerNotConfigured("ImportSessionRepository")
    }
}
