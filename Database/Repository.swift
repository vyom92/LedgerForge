// Database/Repository.swift
// Repository protocol definitions for LedgerForge persistence layer
// Repository contracts are part of the frozen persistence boundary.

import Foundation

public enum RepositoryError: Error, LocalizedError {
    case providerNotConfigured(String)
    case recordNotFound(String)
    case relationshipViolation(String)
    case staleProviderGeneration
    case conflictingAccountIdentifier(workspaceId: String, scheme: String, identifier: String, existingAccountId: String, attemptedAccountId: String)

    public var errorDescription: String? {
        switch self {
        case .providerNotConfigured(let repositoryName):
            return "\(repositoryName) is not configured. Install a concrete DatabaseProvider before using repository APIs."
        case .recordNotFound(let message):
            return message
        case .relationshipViolation(let message):
            return message
        case .staleProviderGeneration:
            return "This repository belongs to an inactive database provider generation."
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
    func transactionEventOwners(keys: Set<TransactionEventIdentityKeyDTO>) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO]
    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String
    func importAttempts(workspaceId: String) throws -> [ImportAttemptDTO]
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
#if DEBUG
    private let generationValidity: ProviderGenerationValidity?
#endif

    public init(workspaceRepo: WorkspaceRepository, transactionRepo: TransactionRepository, accountRepo: AccountRepository, importSessionRepo: ImportSessionRepository, protectsGeneration: Bool = false) {
#if DEBUG
        if protectsGeneration {
            let validity = ProviderGenerationValidity()
            self.generationValidity = validity
            self.workspaceRepo = GenerationCheckedWorkspaceRepository(base: workspaceRepo, validity: validity)
            self.transactionRepo = GenerationCheckedTransactionRepository(base: transactionRepo, validity: validity)
            self.accountRepo = GenerationCheckedAccountRepository(base: accountRepo, validity: validity)
            self.importSessionRepo = GenerationCheckedImportSessionRepository(base: importSessionRepo, validity: validity)
            return
        }
        self.generationValidity = nil
#endif
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
#if DEBUG
        self.generationValidity = nil
#endif
    }

#if DEBUG
    func invalidateGeneration() {
        generationValidity?.invalidate()
    }
#endif
}

#if DEBUG
private final class ProviderGenerationValidity {
    private(set) var isValid = true
    func invalidate() { isValid = false }
    func check() throws {
        guard isValid else { throw RepositoryError.staleProviderGeneration }
    }
}

private struct GenerationCheckedWorkspaceRepository: WorkspaceRepository {
    let base: WorkspaceRepository
    let validity: ProviderGenerationValidity
    func upsertWorkspace(_ workspace: WorkspaceDTO) throws -> String { try validity.check(); return try base.upsertWorkspace(workspace) }
    func workspace(id: String) throws -> WorkspaceDTO? { try validity.check(); return try base.workspace(id: id) }
}

private struct GenerationCheckedTransactionRepository: TransactionRepository {
    let base: TransactionRepository
    let validity: ProviderGenerationValidity
    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [TransactionDTO]) throws { try validity.check(); try base.replaceTransactions(workspaceId: workspaceId, importSessionId: importSessionId, transactions: transactions) }
    func transactions(workspaceId: String, importSessionId: String?) throws -> [TransactionDTO] { try validity.check(); return try base.transactions(workspaceId: workspaceId, importSessionId: importSessionId) }
    func trustedTransactions(workspaceId: String) throws -> [TransactionDTO] { try validity.check(); return try base.trustedTransactions(workspaceId: workspaceId) }
}

private struct GenerationCheckedAccountRepository: AccountRepository {
    let base: AccountRepository
    let validity: ProviderGenerationValidity
    func upsertAccount(_ account: AccountDTO) throws -> String { try validity.check(); return try base.upsertAccount(account) }
    func updateAccountDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool { try validity.check(); return try base.updateAccountDisplayName(accountId: accountId, workspaceId: workspaceId, displayName: displayName) }
    func account(id: String) throws -> AccountDTO? { try validity.check(); return try base.account(id: id) }
    func accounts(workspaceId: String) throws -> [AccountDTO] { try validity.check(); return try base.accounts(workspaceId: workspaceId) }
    func attachIdentifier(_ identifier: AccountIdentifierDTO) throws -> String { try validity.check(); return try base.attachIdentifier(identifier) }
    func identifiers(accountId: String, workspaceId: String) throws -> [AccountIdentifierDTO] { try validity.check(); return try base.identifiers(accountId: accountId, workspaceId: workspaceId) }
    func accountIds(workspaceId: String, scheme: String, identifier: String) throws -> [String] { try validity.check(); return try base.accountIds(workspaceId: workspaceId, scheme: scheme, identifier: identifier) }
}

private struct GenerationCheckedImportSessionRepository: ImportSessionRepository {
    let base: ImportSessionRepository
    let validity: ProviderGenerationValidity
    func createImportSession(_ payload: ImportSessionDTO) throws -> String { try validity.check(); return try base.createImportSession(payload) }
    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws { try validity.check(); try base.updateImportSession(id, updates: updates) }
    func importSession(id: String) throws -> ImportSessionRecordDTO? { try validity.check(); return try base.importSession(id: id) }
    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO? { try validity.check(); return try base.priorImportedStatement(algorithm: algorithm, fingerprint: fingerprint) }
    func transactionEventOwners(keys: Set<TransactionEventIdentityKeyDTO>) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] { try validity.check(); return try base.transactionEventOwners(keys: keys) }
    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String { try validity.check(); return try base.recordImportAttempt(payload) }
    func importAttempts(workspaceId: String) throws -> [ImportAttemptDTO] { try validity.check(); return try base.importAttempts(workspaceId: workspaceId) }
    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult { try validity.check(); return try base.commitImportHistory(payload) }
}
#endif

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
    func transactionEventOwners(keys: Set<TransactionEventIdentityKeyDTO>) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] {
        throw RepositoryError.providerNotConfigured("ImportSessionRepository")
    }
    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String { throw RepositoryError.providerNotConfigured("ImportSessionRepository") }
    func importAttempts(workspaceId: String) throws -> [ImportAttemptDTO] { throw RepositoryError.providerNotConfigured("ImportSessionRepository") }

    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult {
        throw RepositoryError.providerNotConfigured("ImportSessionRepository")
    }
}
