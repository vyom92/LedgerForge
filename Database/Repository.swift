// Database/Repository.swift
// Repository protocol definitions for LedgerForge persistence layer
// Repository contracts are part of the frozen persistence boundary.

import Foundation

public enum RepositoryError: Error, LocalizedError {
    case providerNotConfigured(String)
    case persistenceUnavailable
    case recordNotFound(String)
    case relationshipViolation(String)
    case staleProviderGeneration
    case conflictingAccountIdentifier(workspaceId: String, scheme: String, identifier: String, existingAccountId: String, attemptedAccountId: String)

    public var errorDescription: String? {
        switch self {
        case .providerNotConfigured(let repositoryName):
            return "\(repositoryName) is not configured. Install a concrete DatabaseProvider before using repository APIs."
        case .persistenceUnavailable:
            return "Persistence is unavailable. No repository data was read or changed."
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

public enum PersistenceUnavailableReason: String, Equatable {
    case notInitialized
    case databaseOpenFailed
    case databaseInitializationFailed
    case migrationIntegrityFailed
    case migrationFailed
    case lifecycleUnavailable
    case unknown
}

enum PersistenceFailureClassifier {
    static func classify(_ error: Error) -> PersistenceUnavailableReason {
        switch error {
        case SQLiteRepositoryProviderError.databaseOpenFailed:
            return .databaseOpenFailed
        case SQLiteRepositoryProviderError.databaseInitializationFailed:
            return .databaseInitializationFailed
        case SQLiteRepositoryProviderError.migrationIntegrityFailed:
            return .migrationIntegrityFailed
        case SQLiteRepositoryProviderError.migrationFailed:
            return .migrationFailed
        case is MigrationIntegrityError:
            return .migrationIntegrityFailed
        default:
            return .unknown
        }
    }
}

enum PersistenceWorkflowError: Error, Equatable, LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Persistence is unavailable. The statement was not processed or saved."
    }
}

public enum PersistenceNonDurablePurpose: String, Equatable {
    case testMemory
    case debugMemory
    case debugTemporarySQLite
}

public enum PersistenceState: Equatable {
    case verifiedSQLite
    case unavailable(PersistenceUnavailableReason)
    case intentionalNonDurable(PersistenceNonDurablePurpose)

    var isUsable: Bool {
        if case .unavailable = self { return false }
        return true
    }

    var isDurable: Bool { self == .verifiedSQLite }

    var displayName: String {
        switch self {
        case .verifiedSQLite:
            return "Verified SQLite"
        case .unavailable:
            return "Persistence Unavailable"
        case .intentionalNonDurable(.testMemory):
            return "Intentional Test Memory"
        case .intentionalNonDurable(.debugMemory):
            return "Intentional Debug Memory"
        case .intentionalNonDurable(.debugTemporarySQLite):
            return "Temporary Debug SQLite"
        }
    }

    var statusMessage: String {
        switch self {
        case .verifiedSQLite:
            return "Durable persistence is verified and available."
        case .unavailable:
            return "Durable persistence is unavailable. Imports and saved-data operations are disabled."
        case .intentionalNonDurable(.testMemory):
            return "An explicitly selected in-memory test provider is active."
        case .intentionalNonDurable(.debugMemory):
            return "An explicitly selected in-memory Debug provider is active."
        case .intentionalNonDurable(.debugTemporarySQLite):
            return "An explicitly selected temporary Debug database is active for this process."
        }
    }

    var recoveryGuidance: String? {
        guard case .unavailable = self else { return nil }
        return "Quit and reopen LedgerForge. If persistence remains unavailable, preserve the database and seek support; do not reset or replace it."
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

/// This deliberately does not expose a generic transaction closure. Providers
/// own the full accepted-import graph and may only return bounded outcomes.
public protocol ConfirmedImportRepository {
    func commitConfirmedImport(_ plan: ConfirmedImportPlanDTO) -> ConfirmedImportRepositoryResult
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
    public static var shared: DatabaseProvider = .unavailable(reason: .notInitialized)

    public let persistenceState: PersistenceState
    public let workspaceRepo: WorkspaceRepository
    public let transactionRepo: TransactionRepository
    public let accountRepo: AccountRepository
    public let importSessionRepo: ImportSessionRepository
    /// Captured by a prepared import and compared only by the dormant
    /// confirmed-import provider. It is never presented or logged.
    public let generationToken: ProviderGenerationToken
    public let confirmedImportRepo: ConfirmedImportRepository
#if DEBUG
    private let generationValidity: ProviderGenerationValidity?
#endif

    public init(
        workspaceRepo: WorkspaceRepository,
        transactionRepo: TransactionRepository,
        accountRepo: AccountRepository,
        importSessionRepo: ImportSessionRepository,
        confirmedImportRepo: ConfirmedImportRepository = PlaceholderConfirmedImportRepo(),
        generationToken: ProviderGenerationToken = ProviderGenerationToken(),
        persistenceState: PersistenceState = .intentionalNonDurable(.testMemory),
        protectsGeneration: Bool = false
    ) {
        self.persistenceState = persistenceState
        self.generationToken = generationToken
        self.confirmedImportRepo = confirmedImportRepo
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
        self.persistenceState = .intentionalNonDurable(.testMemory)
        self.workspaceRepo = provider.workspaceRepo
        self.transactionRepo = provider.transactionRepo
        self.accountRepo = provider.accountRepo
        self.importSessionRepo = provider.importSessionRepo
        self.generationToken = provider.generationToken
        self.confirmedImportRepo = provider.confirmedImportRepo
#if DEBUG
        self.generationValidity = nil
#endif
    }

    static func unavailable(reason: PersistenceUnavailableReason) -> DatabaseProvider {
        DatabaseProvider(
            workspaceRepo: PlaceholderWorkspaceRepo(),
            transactionRepo: PlaceholderTransactionRepo(),
            accountRepo: PlaceholderAccountRepo(),
            importSessionRepo: PlaceholderImportSessionRepo(),
            confirmedImportRepo: PlaceholderConfirmedImportRepo(),
            persistenceState: .unavailable(reason)
        )
    }

    static func intentionalNonDurable(_ purpose: PersistenceNonDurablePurpose) -> DatabaseProvider {
        let provider = InMemoryRepositoryProvider()
        return DatabaseProvider(
            workspaceRepo: provider.workspaceRepo,
            transactionRepo: provider.transactionRepo,
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            confirmedImportRepo: provider.confirmedImportRepo,
            generationToken: provider.generationToken,
            persistenceState: .intentionalNonDurable(purpose)
        )
    }

    static func verifiedSQLite(_ provider: SQLiteRepositoryProvider, protectsGeneration: Bool = false) -> DatabaseProvider {
        DatabaseProvider(
            workspaceRepo: provider.workspaceRepo,
            transactionRepo: provider.transactionRepo,
            accountRepo: provider.accountRepo,
            importSessionRepo: provider.importSessionRepo,
            confirmedImportRepo: provider.confirmedImportRepo,
            generationToken: provider.generationToken,
            persistenceState: .verifiedSQLite,
            protectsGeneration: protectsGeneration
        )
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
        throw RepositoryError.persistenceUnavailable
    }

    func workspace(id: String) throws -> WorkspaceDTO? {
        throw RepositoryError.persistenceUnavailable
    }
}

struct PlaceholderTransactionRepo: TransactionRepository {
    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [TransactionDTO]) throws {
        throw RepositoryError.persistenceUnavailable
    }

    func transactions(workspaceId: String, importSessionId: String?) throws -> [TransactionDTO] {
        throw RepositoryError.persistenceUnavailable
    }

    func trustedTransactions(workspaceId: String) throws -> [TransactionDTO] {
        throw RepositoryError.persistenceUnavailable
    }
}

struct PlaceholderAccountRepo: AccountRepository {
    func upsertAccount(_ account: AccountDTO) throws -> String {
        throw RepositoryError.persistenceUnavailable
    }

    func updateAccountDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool {
        throw RepositoryError.persistenceUnavailable
    }

    func account(id: String) throws -> AccountDTO? {
        throw RepositoryError.persistenceUnavailable
    }

    func accounts(workspaceId: String) throws -> [AccountDTO] {
        throw RepositoryError.persistenceUnavailable
    }

    func attachIdentifier(_ identifier: AccountIdentifierDTO) throws -> String {
        throw RepositoryError.persistenceUnavailable
    }

    func identifiers(accountId: String, workspaceId: String) throws -> [AccountIdentifierDTO] {
        throw RepositoryError.persistenceUnavailable
    }

    func accountIds(workspaceId: String, scheme: String, identifier: String) throws -> [String] {
        throw RepositoryError.persistenceUnavailable
    }
}

struct PlaceholderImportSessionRepo: ImportSessionRepository {
    func createImportSession(_ payload: ImportSessionDTO) throws -> String {
        throw RepositoryError.persistenceUnavailable
    }
    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws {
        throw RepositoryError.persistenceUnavailable
    }

    func importSession(id: String) throws -> ImportSessionRecordDTO? {
        throw RepositoryError.persistenceUnavailable
    }

    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO? {
        throw RepositoryError.persistenceUnavailable
    }
    func transactionEventOwners(keys: Set<TransactionEventIdentityKeyDTO>) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] {
        throw RepositoryError.persistenceUnavailable
    }
    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String { throw RepositoryError.persistenceUnavailable }
    func importAttempts(workspaceId: String) throws -> [ImportAttemptDTO] { throw RepositoryError.persistenceUnavailable }

    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult {
        throw RepositoryError.persistenceUnavailable
    }
}

public struct PlaceholderConfirmedImportRepo: ConfirmedImportRepository {
    public init() {}

    public func commitConfirmedImport(_ plan: ConfirmedImportPlanDTO) -> ConfirmedImportRepositoryResult {
        .persistenceUnavailable
    }
}
