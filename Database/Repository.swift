// Database/Repository.swift
// Repository protocol definitions for LedgerForge persistence layer
// Repository contracts are part of the frozen persistence boundary.

import Foundation

public enum RepositoryError: Error, LocalizedError {
    case providerNotConfigured(String)
    case persistenceUnavailable
    case recordNotFound(String)
    case relationshipViolation(String)
    case trustedTransactionWriteForbidden
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
        case .trustedTransactionWriteForbidden:
            return "Trusted transactions may be written only by confirmed import."
        case .staleProviderGeneration:
            return "This repository belongs to an inactive database provider generation."
        case .conflictingAccountIdentifier(let workspaceId, let scheme, _, let existingAccountId, let attemptedAccountId):
            return "Identifier \(scheme) is already assigned in workspace \(workspaceId) to account \(existingAccountId), not \(attemptedAccountId)."
        }
    }
}

public enum CategoryRepositoryError: Error, Equatable, LocalizedError {
    case invalidName
    case duplicateName
    case categoryNotFound
    case transactionNotFound
    case categoryArchived
    case categoryInUse
    case workspaceMismatch

    public var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Category names must contain 1 to 80 characters."
        case .duplicateName:
            return "A category with this name already exists."
        case .categoryNotFound:
            return "The category no longer exists."
        case .transactionNotFound:
            return "The imported transaction no longer exists."
        case .categoryArchived:
            return "Archived categories cannot receive new assignments."
        case .categoryInUse:
            return "This category is assigned to one or more transactions and cannot be deleted."
        case .workspaceMismatch:
            return "The category and transaction must belong to the active workspace."
        }
    }
}

enum CategoryName {
    static let maximumLength = 80

    static func validated(_ value: String) throws -> (display: String, normalized: String) {
        let display = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !display.isEmpty, display.count <= maximumLength else {
            throw CategoryRepositoryError.invalidName
        }
        let normalized = display
            .precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
        guard !normalized.isEmpty else {
            throw CategoryRepositoryError.invalidName
        }
        return (display, normalized)
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
#if DEBUG
    case debugMigrationSandboxSQLite
#endif
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
#if DEBUG
        case .intentionalNonDurable(.debugMigrationSandboxSQLite):
            return "Migration Sandbox SQLite"
#endif
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
#if DEBUG
        case .intentionalNonDurable(.debugMigrationSandboxSQLite):
            return "An explicitly selected migrated Debug sandbox is active for this process."
#endif
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

public protocol CategoryRepository {
    func categories(workspaceId: String) throws -> [CategoryDTO]
    func assignments(workspaceId: String) throws -> [TransactionCategoryAssignmentDTO]
    @discardableResult
    func createCategory(_ category: CategoryDTO) throws -> CategoryDTO
    @discardableResult
    func renameCategory(id: String, workspaceId: String, name: String, updatedAtISO: String) throws -> Bool
    @discardableResult
    func setCategoryArchived(id: String, workspaceId: String, isArchived: Bool, updatedAtISO: String) throws -> Bool
    func deleteUnusedCategory(id: String, workspaceId: String) throws
    @discardableResult
    func setCategory(categoryId: String?, transactionId: String, workspaceId: String) throws -> Bool
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
    func cbqSourceIdentityRecords(workspaceId: String) throws -> [CBQSourceIdentityRecordDTO]
}

public protocol CardRepository {
    func snapshot(workspaceId: String) throws -> CardRepositorySnapshotDTO
}

public extension AccountRepository {
    func cbqSourceIdentityRecords(workspaceId: String) throws -> [CBQSourceIdentityRecordDTO] { [] }
}

public protocol ImportSessionRepository {
    func createImportSession(_ payload: ImportSessionDTO) throws -> String
    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws
    func importSession(id: String) throws -> ImportSessionRecordDTO?
    func importedDocument(id: String) throws -> ImportedDocumentDTO?
    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO?
    func transactionEventOwners(keys: Set<TransactionEventIdentityKeyDTO>) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO]
    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String
    func importAttempts(workspaceId: String) throws -> [ImportAttemptDTO]
    func partialImportSummary(importSessionId: String) throws -> PartialImportSummaryDTO?
    func incomingRowDispositions(importSessionId: String) throws -> [IncomingRowDispositionDTO]
    func statementFinancialProjections(workspaceId: String) throws -> [StatementFinancialProjectionRecordDTO]
    func statementEquivalenceGroups(workspaceId: String) throws -> [StatementEquivalenceGroupDTO]
    func statementEquivalenceMembers(workspaceId: String) throws -> [StatementEquivalenceMemberDTO]
    func preferredTransactionSources(workspaceId: String) throws -> [PreferredTransactionSourceDTO]
    func cbqSourceObservationSummaries(workspaceId: String) throws -> [CBQSourceObservationSummaryDTO]
    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult
}

public extension ImportSessionRepository {
    func partialImportSummary(importSessionId: String) throws -> PartialImportSummaryDTO? { nil }
    func incomingRowDispositions(importSessionId: String) throws -> [IncomingRowDispositionDTO] { [] }
    func statementFinancialProjections(workspaceId: String) throws -> [StatementFinancialProjectionRecordDTO] { [] }
    func statementEquivalenceGroups(workspaceId: String) throws -> [StatementEquivalenceGroupDTO] { [] }
    func statementEquivalenceMembers(workspaceId: String) throws -> [StatementEquivalenceMemberDTO] { [] }
    func preferredTransactionSources(workspaceId: String) throws -> [PreferredTransactionSourceDTO] { [] }
    func cbqSourceObservationSummaries(workspaceId: String) throws -> [CBQSourceObservationSummaryDTO] { [] }
}

/// This deliberately does not expose a generic transaction closure. Providers
/// own the full accepted-import graph and may only return bounded outcomes.
public protocol ConfirmedImportRepository {
    func reviewPartialImport(_ plan: ConfirmedImportPlanDTO) -> PartialImportReviewResult
    func reviewStatementEquivalence(_ plan: ConfirmedImportPlanDTO) -> StatementEquivalenceReviewResult
    func commitConfirmedImport(_ plan: ConfirmedImportPlanDTO) -> ConfirmedImportRepositoryResult
    func commitReviewedPartialImport(_ plan: ReviewedPartialImportPlanDTO) -> ConfirmedImportRepositoryResult
    func reviewCBQSourceOverlap(_ plan: ConfirmedImportPlanDTO) -> CBQSourceOverlapReviewResult
    func commitReviewedCBQSourceOverlap(_ plan: ReviewedCBQSourceOverlapPlanDTO) -> ConfirmedImportRepositoryResult
}

public extension ConfirmedImportRepository {
    func reviewStatementEquivalence(_ plan: ConfirmedImportPlanDTO) -> StatementEquivalenceReviewResult {
        .notApplicable
    }

    func reviewCBQSourceOverlap(_ plan: ConfirmedImportPlanDTO) -> CBQSourceOverlapReviewResult { .notApplicable }
    func commitReviewedCBQSourceOverlap(_ plan: ReviewedCBQSourceOverlapPlanDTO) -> ConfirmedImportRepositoryResult { .persistenceUnavailable }
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
    public let categoryRepo: CategoryRepository
    public let accountRepo: AccountRepository
    public let cardRepo: CardRepository
    public let importSessionRepo: ImportSessionRepository
    /// Captured by a prepared import and compared only at confirmation. It is
    /// never presented or logged.
    public let generationToken: ProviderGenerationToken
    public let confirmedImportRepo: ConfirmedImportRepository
    public let salaryRepo: SalaryRepository
    public let fundingPlanRepo: FundingPlanRepository
    private let generationValidity: ProviderGenerationValidity?

    public init(
        workspaceRepo: WorkspaceRepository,
        transactionRepo: TransactionRepository,
        categoryRepo: CategoryRepository? = nil,
        accountRepo: AccountRepository,
        cardRepo: CardRepository = PlaceholderCardRepo(),
        importSessionRepo: ImportSessionRepository,
        confirmedImportRepo: ConfirmedImportRepository = PlaceholderConfirmedImportRepo(),
        salaryRepo: SalaryRepository? = nil,
        fundingPlanRepo: FundingPlanRepository? = nil,
        generationToken: ProviderGenerationToken = ProviderGenerationToken(),
        persistenceState: PersistenceState = .intentionalNonDurable(.testMemory),
        protectsGeneration: Bool = false
    ) {
        self.persistenceState = persistenceState
        self.generationToken = generationToken
        let resolvedCategoryRepo = categoryRepo ?? PlaceholderCategoryRepo()
        let resolvedSalaryRepo = salaryRepo ?? EmptySalaryRepo()
        let resolvedFundingPlanRepo = fundingPlanRepo ?? EmptyFundingPlanRepo()
        if protectsGeneration {
            let validity = ProviderGenerationValidity()
            self.generationValidity = validity
            self.workspaceRepo = GenerationCheckedWorkspaceRepository(base: workspaceRepo, validity: validity)
            self.transactionRepo = GenerationCheckedTransactionRepository(base: transactionRepo, validity: validity)
            self.categoryRepo = GenerationCheckedCategoryRepository(base: resolvedCategoryRepo, validity: validity)
            self.accountRepo = GenerationCheckedAccountRepository(base: accountRepo, validity: validity)
            self.cardRepo = GenerationCheckedCardRepository(base: cardRepo, validity: validity)
            self.importSessionRepo = GenerationCheckedImportSessionRepository(base: importSessionRepo, validity: validity)
            self.confirmedImportRepo = GenerationCheckedConfirmedImportRepository(base: confirmedImportRepo, validity: validity)
            self.salaryRepo = GenerationCheckedSalaryRepository(base: resolvedSalaryRepo, validity: validity)
            self.fundingPlanRepo = GenerationCheckedFundingPlanRepository(base: resolvedFundingPlanRepo, validity: validity)
            return
        }
        self.generationValidity = nil
        self.workspaceRepo = workspaceRepo
        self.transactionRepo = transactionRepo
        self.categoryRepo = resolvedCategoryRepo
        self.accountRepo = accountRepo
        self.cardRepo = cardRepo
        self.importSessionRepo = importSessionRepo
        self.confirmedImportRepo = confirmedImportRepo
        self.salaryRepo = resolvedSalaryRepo
        self.fundingPlanRepo = resolvedFundingPlanRepo
    }

    /// Convenience initializer for an isolated in-memory provider. This is
    /// intended for contract tests and non-persistent development fixtures.
    public convenience init(inMemory: Bool) {
        let provider = InMemoryRepositoryProvider()
        self.init(
            workspaceRepo: provider.workspaceRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            accountRepo: provider.accountRepo,
            cardRepo: provider.cardRepo,
            importSessionRepo: provider.importSessionRepo,
            confirmedImportRepo: provider.confirmedImportRepo,
            salaryRepo: provider.salaryRepo,
            fundingPlanRepo: provider.fundingPlanRepo,
            generationToken: provider.generationToken,
            persistenceState: .intentionalNonDurable(.testMemory),
            protectsGeneration: true
        )
    }

    static func unavailable(reason: PersistenceUnavailableReason) -> DatabaseProvider {
        DatabaseProvider(
            workspaceRepo: PlaceholderWorkspaceRepo(),
            transactionRepo: PlaceholderTransactionRepo(),
            categoryRepo: PlaceholderCategoryRepo(),
            accountRepo: PlaceholderAccountRepo(),
            cardRepo: PlaceholderCardRepo(),
            importSessionRepo: PlaceholderImportSessionRepo(),
            confirmedImportRepo: PlaceholderConfirmedImportRepo(),
            salaryRepo: PlaceholderSalaryRepo(),
            fundingPlanRepo: PlaceholderFundingPlanRepo(),
            persistenceState: .unavailable(reason)
        )
    }

    static func intentionalNonDurable(_ purpose: PersistenceNonDurablePurpose) -> DatabaseProvider {
        let provider = InMemoryRepositoryProvider()
        return DatabaseProvider(
            workspaceRepo: provider.workspaceRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            accountRepo: provider.accountRepo,
            cardRepo: provider.cardRepo,
            importSessionRepo: provider.importSessionRepo,
            confirmedImportRepo: provider.confirmedImportRepo,
            salaryRepo: provider.salaryRepo,
            fundingPlanRepo: provider.fundingPlanRepo,
            generationToken: provider.generationToken,
            persistenceState: .intentionalNonDurable(purpose),
            protectsGeneration: true
        )
    }

    static func verifiedSQLite(_ provider: SQLiteRepositoryProvider, protectsGeneration: Bool = true) -> DatabaseProvider {
        DatabaseProvider(
            workspaceRepo: provider.workspaceRepo,
            transactionRepo: provider.transactionRepo,
            categoryRepo: provider.categoryRepo,
            accountRepo: provider.accountRepo,
            cardRepo: provider.cardRepo,
            importSessionRepo: provider.importSessionRepo,
            confirmedImportRepo: provider.confirmedImportRepo,
            salaryRepo: provider.salaryRepo,
            fundingPlanRepo: provider.fundingPlanRepo,
            generationToken: provider.generationToken,
            persistenceState: .verifiedSQLite,
            protectsGeneration: protectsGeneration
        )
    }

    func invalidateGeneration() {
        generationValidity?.invalidate()
    }
}

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

private struct GenerationCheckedCategoryRepository: CategoryRepository {
    let base: CategoryRepository
    let validity: ProviderGenerationValidity
    func categories(workspaceId: String) throws -> [CategoryDTO] { try validity.check(); return try base.categories(workspaceId: workspaceId) }
    func assignments(workspaceId: String) throws -> [TransactionCategoryAssignmentDTO] { try validity.check(); return try base.assignments(workspaceId: workspaceId) }
    func createCategory(_ category: CategoryDTO) throws -> CategoryDTO { try validity.check(); return try base.createCategory(category) }
    func renameCategory(id: String, workspaceId: String, name: String, updatedAtISO: String) throws -> Bool { try validity.check(); return try base.renameCategory(id: id, workspaceId: workspaceId, name: name, updatedAtISO: updatedAtISO) }
    func setCategoryArchived(id: String, workspaceId: String, isArchived: Bool, updatedAtISO: String) throws -> Bool { try validity.check(); return try base.setCategoryArchived(id: id, workspaceId: workspaceId, isArchived: isArchived, updatedAtISO: updatedAtISO) }
    func deleteUnusedCategory(id: String, workspaceId: String) throws { try validity.check(); try base.deleteUnusedCategory(id: id, workspaceId: workspaceId) }
    func setCategory(categoryId: String?, transactionId: String, workspaceId: String) throws -> Bool { try validity.check(); return try base.setCategory(categoryId: categoryId, transactionId: transactionId, workspaceId: workspaceId) }
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
    func cbqSourceIdentityRecords(workspaceId: String) throws -> [CBQSourceIdentityRecordDTO] { try validity.check(); return try base.cbqSourceIdentityRecords(workspaceId: workspaceId) }
}

private struct GenerationCheckedCardRepository: CardRepository {
    let base: CardRepository
    let validity: ProviderGenerationValidity
    func snapshot(workspaceId: String) throws -> CardRepositorySnapshotDTO {
        try validity.check()
        return try base.snapshot(workspaceId: workspaceId)
    }
}

private struct GenerationCheckedImportSessionRepository: ImportSessionRepository {
    let base: ImportSessionRepository
    let validity: ProviderGenerationValidity
    func createImportSession(_ payload: ImportSessionDTO) throws -> String { try validity.check(); return try base.createImportSession(payload) }
    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws { try validity.check(); try base.updateImportSession(id, updates: updates) }
    func importSession(id: String) throws -> ImportSessionRecordDTO? { try validity.check(); return try base.importSession(id: id) }
    func importedDocument(id: String) throws -> ImportedDocumentDTO? { try validity.check(); return try base.importedDocument(id: id) }
    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO? { try validity.check(); return try base.priorImportedStatement(algorithm: algorithm, fingerprint: fingerprint) }
    func transactionEventOwners(keys: Set<TransactionEventIdentityKeyDTO>) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] { try validity.check(); return try base.transactionEventOwners(keys: keys) }
    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String { try validity.check(); return try base.recordImportAttempt(payload) }
    func importAttempts(workspaceId: String) throws -> [ImportAttemptDTO] { try validity.check(); return try base.importAttempts(workspaceId: workspaceId) }
    func partialImportSummary(importSessionId: String) throws -> PartialImportSummaryDTO? { try validity.check(); return try base.partialImportSummary(importSessionId: importSessionId) }
    func incomingRowDispositions(importSessionId: String) throws -> [IncomingRowDispositionDTO] { try validity.check(); return try base.incomingRowDispositions(importSessionId: importSessionId) }
    func statementFinancialProjections(workspaceId: String) throws -> [StatementFinancialProjectionRecordDTO] { try validity.check(); return try base.statementFinancialProjections(workspaceId: workspaceId) }
    func statementEquivalenceGroups(workspaceId: String) throws -> [StatementEquivalenceGroupDTO] { try validity.check(); return try base.statementEquivalenceGroups(workspaceId: workspaceId) }
    func statementEquivalenceMembers(workspaceId: String) throws -> [StatementEquivalenceMemberDTO] { try validity.check(); return try base.statementEquivalenceMembers(workspaceId: workspaceId) }
    func preferredTransactionSources(workspaceId: String) throws -> [PreferredTransactionSourceDTO] { try validity.check(); return try base.preferredTransactionSources(workspaceId: workspaceId) }
    func cbqSourceObservationSummaries(workspaceId: String) throws -> [CBQSourceObservationSummaryDTO] { try validity.check(); return try base.cbqSourceObservationSummaries(workspaceId: workspaceId) }
    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult { try validity.check(); return try base.commitImportHistory(payload) }
}

private struct GenerationCheckedConfirmedImportRepository: ConfirmedImportRepository {
    let base: ConfirmedImportRepository
    let validity: ProviderGenerationValidity

    func reviewPartialImport(_ plan: ConfirmedImportPlanDTO) -> PartialImportReviewResult {
        do {
            try validity.check()
            return base.reviewPartialImport(plan)
        } catch {
            // The read-only review result predates the shared stale-generation
            // case; fail closed without consulting the inactive provider.
            return .repositoryIntegrityConflict
        }
    }

    func reviewStatementEquivalence(_ plan: ConfirmedImportPlanDTO) -> StatementEquivalenceReviewResult {
        do {
            try validity.check()
            return base.reviewStatementEquivalence(plan)
        } catch {
            return .evidenceUnavailable
        }
    }

    func commitConfirmedImport(_ plan: ConfirmedImportPlanDTO) -> ConfirmedImportRepositoryResult {
        do {
            try validity.check()
            return base.commitConfirmedImport(plan)
        } catch {
            return .staleProviderGeneration
        }
    }

    func commitReviewedPartialImport(_ plan: ReviewedPartialImportPlanDTO) -> ConfirmedImportRepositoryResult {
        do {
            try validity.check()
            return base.commitReviewedPartialImport(plan)
        } catch {
            return .staleProviderGeneration
        }
    }


    func reviewCBQSourceOverlap(_ plan: ConfirmedImportPlanDTO) -> CBQSourceOverlapReviewResult {
        do { try validity.check(); return base.reviewCBQSourceOverlap(plan) }
        catch { return .repositoryIntegrityConflict }
    }

    func commitReviewedCBQSourceOverlap(_ plan: ReviewedCBQSourceOverlapPlanDTO) -> ConfirmedImportRepositoryResult {
        do { try validity.check(); return base.commitReviewedCBQSourceOverlap(plan) }
        catch { return .staleProviderGeneration }
    }
}

private struct GenerationCheckedSalaryRepository: SalaryRepository {
    let base: SalaryRepository
    let validity: ProviderGenerationValidity

    func commitImportedSalary(_ plan: SalaryImportPlanDTO) -> SalaryImportRepositoryResult {
        do { try validity.check(); return base.commitImportedSalary(plan) }
        catch { return .staleProviderGeneration }
    }

    func snapshot(workspaceId: String) throws -> SalaryRepositorySnapshotDTO {
        try validity.check()
        return try base.snapshot(workspaceId: workspaceId)
    }
}

private struct GenerationCheckedFundingPlanRepository: FundingPlanRepository {
    let base: FundingPlanRepository
    let validity: ProviderGenerationValidity

    func plans(workspaceId: String) throws -> [FundingPlanDTO] {
        try validity.check()
        return try base.plans(workspaceId: workspaceId)
    }

    func savePlan(_ plan: FundingPlanDTO) throws -> FundingPlanDTO {
        try validity.check()
        return try base.savePlan(plan)
    }
}

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

struct PlaceholderCategoryRepo: CategoryRepository {
    func categories(workspaceId: String) throws -> [CategoryDTO] { throw RepositoryError.persistenceUnavailable }
    func assignments(workspaceId: String) throws -> [TransactionCategoryAssignmentDTO] { throw RepositoryError.persistenceUnavailable }
    func createCategory(_ category: CategoryDTO) throws -> CategoryDTO { throw RepositoryError.persistenceUnavailable }
    func renameCategory(id: String, workspaceId: String, name: String, updatedAtISO: String) throws -> Bool { throw RepositoryError.persistenceUnavailable }
    func setCategoryArchived(id: String, workspaceId: String, isArchived: Bool, updatedAtISO: String) throws -> Bool { throw RepositoryError.persistenceUnavailable }
    func deleteUnusedCategory(id: String, workspaceId: String) throws { throw RepositoryError.persistenceUnavailable }
    func setCategory(categoryId: String?, transactionId: String, workspaceId: String) throws -> Bool { throw RepositoryError.persistenceUnavailable }
}

/// Compatibility read boundary for focused hydrator tests that inject only
/// pre-category repository protocols.
struct EmptyCategoryRepo: CategoryRepository {
    func categories(workspaceId: String) throws -> [CategoryDTO] { [] }
    func assignments(workspaceId: String) throws -> [TransactionCategoryAssignmentDTO] { [] }
    func createCategory(_ category: CategoryDTO) throws -> CategoryDTO { throw RepositoryError.persistenceUnavailable }
    func renameCategory(id: String, workspaceId: String, name: String, updatedAtISO: String) throws -> Bool { throw RepositoryError.persistenceUnavailable }
    func setCategoryArchived(id: String, workspaceId: String, isArchived: Bool, updatedAtISO: String) throws -> Bool { throw RepositoryError.persistenceUnavailable }
    func deleteUnusedCategory(id: String, workspaceId: String) throws { throw RepositoryError.persistenceUnavailable }
    func setCategory(categoryId: String?, transactionId: String, workspaceId: String) throws -> Bool { throw RepositoryError.persistenceUnavailable }
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
    func cbqSourceIdentityRecords(workspaceId: String) throws -> [CBQSourceIdentityRecordDTO] { throw RepositoryError.persistenceUnavailable }
}

public struct PlaceholderCardRepo: CardRepository {
    public init() {}

    public func snapshot(workspaceId: String) throws -> CardRepositorySnapshotDTO {
        throw RepositoryError.persistenceUnavailable
    }
}

struct EmptyCardRepo: CardRepository {
    func snapshot(workspaceId: String) throws -> CardRepositorySnapshotDTO { .empty }
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

    func importedDocument(id: String) throws -> ImportedDocumentDTO? {
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

    public func reviewPartialImport(_ plan: ConfirmedImportPlanDTO) -> PartialImportReviewResult {
        .repositoryIntegrityConflict
    }

    public func commitConfirmedImport(_ plan: ConfirmedImportPlanDTO) -> ConfirmedImportRepositoryResult {
        .persistenceUnavailable
    }

    public func commitReviewedPartialImport(_ plan: ReviewedPartialImportPlanDTO) -> ConfirmedImportRepositoryResult {
        .persistenceUnavailable
    }

    public func reviewCBQSourceOverlap(_ plan: ConfirmedImportPlanDTO) -> CBQSourceOverlapReviewResult { .repositoryIntegrityConflict }
    public func commitReviewedCBQSourceOverlap(_ plan: ReviewedCBQSourceOverlapPlanDTO) -> ConfirmedImportRepositoryResult { .persistenceUnavailable }
}
