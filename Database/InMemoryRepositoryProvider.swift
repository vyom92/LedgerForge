// Database/InMemoryRepositoryProvider.swift
// In-memory repository provider for contract tests and isolated development fixtures

import Foundation

public final class InMemoryRepositoryProvider {
    public let workspaceRepo: WorkspaceRepository
    public let transactionRepo: TransactionRepository
    public let categoryRepo: CategoryRepository
    public let accountRepo: AccountRepository
    public let importSessionRepo: ImportSessionRepository
    public let generationToken: ProviderGenerationToken
    public let confirmedImportRepo: ConfirmedImportRepository

    private let state = InMemoryRepositoryState()

    public init() {
        let generationToken = ProviderGenerationToken()
        self.generationToken = generationToken
        self.workspaceRepo = InMemoryWorkspaceRepo(state: state)
        self.transactionRepo = InMemoryTransactionRepo(state: state)
        self.categoryRepo = InMemoryCategoryRepo(state: state)
        self.accountRepo = InMemoryAccountRepo(state: state)
        self.importSessionRepo = InMemoryImportSessionRepo(state: state)
        self.confirmedImportRepo = InMemoryConfirmedImportRepo(state: state, generationToken: generationToken)
    }

    /// Test-only deterministic failure boundary for proving that an accepted
    /// confirmed import never publishes a partial graph.
    func injectConfirmedImportFailure(after point: ConfirmedImportFailureInjectionPoint?) {
        state.stateLock.lock()
        state.confirmedImportFailureInjection = point
        state.stateLock.unlock()
    }

    func injectSupportingSourceFailure(after point: SupportingSourceFailureInjectionPoint?) {
        state.stateLock.lock()
        state.supportingSourceFailureInjection = point
        state.stateLock.unlock()
    }
}

enum ConfirmedImportFailureInjectionPoint: CaseIterable {
    case workspace
    case account
    case identifierOwnership
    case observation
    case document
    case fingerprint
    case importSession
    case transactions
    case eventIdentities
    case partialDispositions
    case partialSummary
    case successfulAttempt
    case sessionCompletion
}

enum SupportingSourceFailureInjectionPoint: CaseIterable {
    case document
    case fingerprint
    case importSession
    case normalizedDocument
    case normalizedRows
    case projection
    case projectionEvents
    case identifierObservation
    case equivalenceMember
    case successfulAttempt
    case completion
}

private final class InMemoryRepositoryState {
    /// One lock serializes every durable-state observation and mutation. The
    /// confirmed provider uses it once while preparing and publishing a full
    /// copy-on-write accepted graph.
    let stateLock = NSRecursiveLock()
    var workspaces: [String: WorkspaceDTO] = [:]
    var accounts: [String: AccountDTO] = [:]
    var accountIdentifiers: [String: AccountIdentifierDTO] = [:]
    var documents: [String: ImportedDocumentDTO] = [:]
    var documentFingerprints: [String: DocumentFingerprintDTO] = [:]
    var importSessions: [String: ImportSessionRecordDTO] = [:]
    var normalizedDocuments: [String: NormalizedDocumentDTO] = [:]
    var normalizedRows: [String: NormalizedRowDTO] = [:]
    var transactions: [String: TransactionDTO] = [:]
    var categories: [String: CategoryDTO] = [:]
    var categoryAssignments: [String: TransactionCategoryAssignmentDTO] = [:]
    var transactionEventIdentities: [String: TransactionEventIdentityDTO] = [:]
    var importAttempts: [String: ImportAttemptDTO] = [:]
    var partialImportSummaries: [String: PartialImportSummaryDTO] = [:]
    var incomingRowDispositions: [String: IncomingRowDispositionDTO] = [:]
    var identifierObservations: [String: IdentifierObservationDTO] = [:]
    var statementFinancialProjections: [String: StatementFinancialProjectionRecordDTO] = [:]
    var statementEquivalenceGroups: [String: StatementEquivalenceGroupDTO] = [:]
    var statementEquivalenceMembers: [String: StatementEquivalenceMemberDTO] = [:]
    var cbqSourceIdentityRecords: [String: CBQSourceIdentityRecordDTO] = [:]
    var cbqReviewedSourcePlans: [String: ReviewedCBQSourceOverlapPlanDTO] = [:]
    var cbqTransactionSourceReferenceDigests: [String: Set<String>] = [:]
    var confirmedImportFailureInjection: ConfirmedImportFailureInjectionPoint?
    var supportingSourceFailureInjection: SupportingSourceFailureInjectionPoint?
}

private final class InMemoryCategoryRepo: CategoryRepository {
    private let state: InMemoryRepositoryState

    init(state: InMemoryRepositoryState) {
        self.state = state
    }

    func categories(workspaceId: String) throws -> [CategoryDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.categories.values
            .filter { $0.workspaceId == workspaceId }
            .sorted(by: Self.categoryOrder)
    }

    func assignments(workspaceId: String) throws -> [TransactionCategoryAssignmentDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.categoryAssignments.values
            .filter { $0.workspaceId == workspaceId }
            .sorted { $0.transactionId < $1.transactionId }
    }

    func createCategory(_ category: CategoryDTO) throws -> CategoryDTO {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard state.workspaces[category.workspaceId] != nil else {
            throw CategoryRepositoryError.workspaceMismatch
        }
        let validated = try CategoryName.validated(category.name)
        guard category.normalizedName == validated.normalized else {
            throw CategoryRepositoryError.invalidName
        }
        guard state.categories[category.id] == nil else {
            throw CategoryRepositoryError.duplicateName
        }
        guard !state.categories.values.contains(where: {
            $0.workspaceId == category.workspaceId && $0.normalizedName == validated.normalized
        }) else {
            throw CategoryRepositoryError.duplicateName
        }
        let created = CategoryDTO(
            id: category.id,
            workspaceId: category.workspaceId,
            name: validated.display,
            normalizedName: validated.normalized,
            isArchived: category.isArchived,
            createdAtISO: category.createdAtISO,
            updatedAtISO: category.updatedAtISO
        )
        state.categories[created.id] = created
        return created
    }

    func renameCategory(id: String, workspaceId: String, name: String, updatedAtISO: String) throws -> Bool {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        let validated = try CategoryName.validated(name)
        guard let existing = state.categories[id] else {
            throw CategoryRepositoryError.categoryNotFound
        }
        guard existing.workspaceId == workspaceId else {
            throw CategoryRepositoryError.workspaceMismatch
        }
        guard !state.categories.values.contains(where: {
            $0.id != id && $0.workspaceId == workspaceId && $0.normalizedName == validated.normalized
        }) else {
            throw CategoryRepositoryError.duplicateName
        }
        guard existing.name != validated.display || existing.normalizedName != validated.normalized else {
            return false
        }
        state.categories[id] = CategoryDTO(
            id: existing.id,
            workspaceId: existing.workspaceId,
            name: validated.display,
            normalizedName: validated.normalized,
            isArchived: existing.isArchived,
            createdAtISO: existing.createdAtISO,
            updatedAtISO: updatedAtISO
        )
        return true
    }

    func setCategoryArchived(id: String, workspaceId: String, isArchived: Bool, updatedAtISO: String) throws -> Bool {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard let existing = state.categories[id] else {
            throw CategoryRepositoryError.categoryNotFound
        }
        guard existing.workspaceId == workspaceId else {
            throw CategoryRepositoryError.workspaceMismatch
        }
        guard existing.isArchived != isArchived else { return false }
        state.categories[id] = CategoryDTO(
            id: existing.id,
            workspaceId: existing.workspaceId,
            name: existing.name,
            normalizedName: existing.normalizedName,
            isArchived: isArchived,
            createdAtISO: existing.createdAtISO,
            updatedAtISO: updatedAtISO
        )
        return true
    }

    func deleteUnusedCategory(id: String, workspaceId: String) throws {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard let category = state.categories[id] else {
            throw CategoryRepositoryError.categoryNotFound
        }
        guard category.workspaceId == workspaceId else {
            throw CategoryRepositoryError.workspaceMismatch
        }
        guard !state.categoryAssignments.values.contains(where: {
            $0.workspaceId == workspaceId && $0.categoryId == id
        }) else {
            throw CategoryRepositoryError.categoryInUse
        }
        state.categories.removeValue(forKey: id)
    }

    func setCategory(categoryId: String?, transactionId: String, workspaceId: String) throws -> Bool {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard let transaction = state.transactions[transactionId], transaction.isTrusted else {
            throw CategoryRepositoryError.transactionNotFound
        }
        guard transaction.workspaceId == workspaceId else {
            throw CategoryRepositoryError.workspaceMismatch
        }
        guard let categoryId else {
            return state.categoryAssignments.removeValue(forKey: transactionId) != nil
        }
        guard let category = state.categories[categoryId] else {
            throw CategoryRepositoryError.categoryNotFound
        }
        guard category.workspaceId == workspaceId else {
            throw CategoryRepositoryError.workspaceMismatch
        }
        guard !category.isArchived else {
            throw CategoryRepositoryError.categoryArchived
        }
        if state.categoryAssignments[transactionId]?.categoryId == categoryId {
            return false
        }
        state.categoryAssignments[transactionId] = TransactionCategoryAssignmentDTO(
            workspaceId: workspaceId,
            transactionId: transactionId,
            categoryId: categoryId
        )
        return true
    }

    nonisolated private static func categoryOrder(_ lhs: CategoryDTO, _ rhs: CategoryDTO) -> Bool {
        if lhs.normalizedName != rhs.normalizedName { return lhs.normalizedName < rhs.normalizedName }
        return lhs.id < rhs.id
    }
}

private final class InMemoryWorkspaceRepo: WorkspaceRepository {
    private let state: InMemoryRepositoryState

    init(state: InMemoryRepositoryState) {
        self.state = state
    }

    func upsertWorkspace(_ workspace: WorkspaceDTO) throws -> String {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        state.workspaces[workspace.id] = workspace
        return workspace.id
    }

    func workspace(id: String) throws -> WorkspaceDTO? {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.workspaces[id]
    }
}

private final class InMemoryAccountRepo: AccountRepository {
    private let state: InMemoryRepositoryState

    init(state: InMemoryRepositoryState) {
        self.state = state
    }

    func upsertAccount(_ account: AccountDTO) throws -> String {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard state.workspaces[account.workspaceId] != nil else {
            throw RepositoryError.relationshipViolation("Workspace \(account.workspaceId) does not exist for account \(account.id).")
        }
        state.accounts[account.id] = account
        return account.id
    }

    func updateAccountDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDisplayName.isEmpty else {
            throw RepositoryError.relationshipViolation("Account display name cannot be empty.")
        }
        guard let existing = state.accounts[accountId] else {
            throw RepositoryError.recordNotFound("Account \(accountId) does not exist.")
        }
        guard existing.workspaceId == workspaceId else {
            throw RepositoryError.relationshipViolation("Account \(accountId) does not belong to workspace \(workspaceId).")
        }
        guard existing.name != trimmedDisplayName else {
            return false
        }

        state.accounts[accountId] = AccountDTO(
            id: existing.id,
            workspaceId: existing.workspaceId,
            name: trimmedDisplayName,
            institutionId: existing.institutionId,
            accountType: existing.accountType,
            nativeCurrency: existing.nativeCurrency,
            description: existing.description,
            createdAtISO: existing.createdAtISO
        )
        return true
    }

    func account(id: String) throws -> AccountDTO? {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.accounts[id]
    }

    func accounts(workspaceId: String) throws -> [AccountDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.accounts.values
            .filter { $0.workspaceId == workspaceId }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.id < rhs.id
                }
                return lhs.name < rhs.name
            }
    }

    func attachIdentifier(_ identifier: AccountIdentifierDTO) throws -> String {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard let account = state.accounts[identifier.accountId] else {
            throw RepositoryError.relationshipViolation("Account \(identifier.accountId) does not exist for identifier \(identifier.id).")
        }
        guard account.workspaceId == identifier.workspaceId else {
            throw RepositoryError.relationshipViolation("Account \(identifier.accountId) belongs to workspace \(account.workspaceId), not \(identifier.workspaceId).")
        }

        let existing = matchingIdentifiers(workspaceId: identifier.workspaceId, scheme: identifier.scheme, identifier: identifier.identifier)
        if let conflict = existing.first(where: { $0.accountId != identifier.accountId }) {
            throw RepositoryError.conflictingAccountIdentifier(
                workspaceId: identifier.workspaceId,
                scheme: identifier.scheme,
                identifier: identifier.identifier,
                existingAccountId: conflict.accountId,
                attemptedAccountId: identifier.accountId
            )
        }

        if let current = existing.sorted(by: { $0.id < $1.id }).first {
            return current.id
        }

        state.accountIdentifiers[identifier.id] = identifier
        return identifier.id
    }

    func identifiers(accountId: String, workspaceId: String) throws -> [AccountIdentifierDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.accountIdentifiers.values
            .filter { $0.accountId == accountId && $0.workspaceId == workspaceId }
            .sorted { lhs, rhs in
                if lhs.scheme == rhs.scheme {
                    if lhs.identifier == rhs.identifier {
                        return lhs.id < rhs.id
                    }
                    return lhs.identifier < rhs.identifier
                }
                return lhs.scheme < rhs.scheme
            }
    }

    func accountIds(workspaceId: String, scheme: String, identifier: String) throws -> [String] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return matchingIdentifiers(workspaceId: workspaceId, scheme: scheme, identifier: identifier)
            .map(\.accountId)
            .sorted()
    }

    func cbqSourceIdentityRecords(workspaceId: String) throws -> [CBQSourceIdentityRecordDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        let eligible = Set(state.accounts.values.filter { $0.workspaceId == workspaceId }.map(\.id))
        return state.cbqSourceIdentityRecords.values.filter { eligible.contains($0.accountId) }
            .sorted { ($0.accountId, $0.kind, $0.pattern) < ($1.accountId, $1.kind, $1.pattern) }
    }

    private func matchingIdentifiers(workspaceId: String, scheme: String, identifier: String) -> [AccountIdentifierDTO] {
        state.accountIdentifiers.values
            .filter {
                $0.workspaceId == workspaceId
                && $0.scheme == scheme
                && $0.identifier == identifier
            }
    }
}

private final class InMemoryImportSessionRepo: ImportSessionRepository {
    private let state: InMemoryRepositoryState

    init(state: InMemoryRepositoryState) {
        self.state = state
    }

    func createImportSession(_ payload: ImportSessionDTO) throws -> String {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard state.workspaces[payload.workspaceId] != nil else {
            throw RepositoryError.relationshipViolation("Workspace \(payload.workspaceId) does not exist for import session \(payload.id).")
        }

        state.importSessions[payload.id] = ImportSessionRecordDTO(
            id: payload.id,
            workspaceId: payload.workspaceId,
            userVisibleName: payload.userVisibleName,
            startedAtISO: payload.startedAtISO,
            completedAtISO: nil,
            validationStatus: payload.validationStatus,
            readerVersion: payload.readerVersion,
            parserVersion: payload.parserVersion,
            layoutVersion: payload.layoutVersion
        )
        return payload.id
    }

    func updateImportSession(_ id: String, updates: PartialImportSessionUpdate) throws {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard let existing = state.importSessions[id] else {
            throw RepositoryError.recordNotFound("Import session \(id) does not exist.")
        }

        state.importSessions[id] = ImportSessionRecordDTO(
            id: existing.id,
            workspaceId: existing.workspaceId,
            userVisibleName: existing.userVisibleName,
            startedAtISO: existing.startedAtISO,
            completedAtISO: updates.completedAtISO ?? existing.completedAtISO,
            validationStatus: updates.validationStatus ?? existing.validationStatus,
            readerVersion: existing.readerVersion,
            parserVersion: existing.parserVersion,
            layoutVersion: existing.layoutVersion
        )
    }

    func importSession(id: String) throws -> ImportSessionRecordDTO? {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.importSessions[id]
    }

    func importedDocument(id: String) throws -> ImportedDocumentDTO? {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.documents[id]
    }

    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO? {
        state.stateLock.lock()
        defer { state.stateLock.unlock() }
        return priorImportedStatementWithoutLock(algorithm: algorithm, fingerprint: fingerprint)
    }

    func transactionEventOwners(keys: Set<TransactionEventIdentityKeyDTO>) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        var result: [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] = [:]
        for event in state.transactionEventIdentities.values {
            let key = TransactionEventIdentityKeyDTO(algorithm: event.algorithm, digest: event.digest)
            if keys.contains(key) {
                result[key] = TransactionEventIdentityOwnerDTO(eventIdentityId: event.id, accountId: event.accountId, transactionId: event.transactionId, documentId: event.documentId, importSessionId: event.importSessionId)
            }
        }
        return result
    }

    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard state.workspaces[payload.workspaceId] != nil else {
            throw RepositoryError.relationshipViolation("Workspace does not exist for import attempt.")
        }
        guard state.importAttempts[payload.id] == nil else {
            throw RepositoryError.relationshipViolation("Import attempt identifier already exists.")
        }
        state.importAttempts[payload.id] = payload
        return payload.id
    }

    func importAttempts(workspaceId: String) throws -> [ImportAttemptDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.importAttempts.values.filter { $0.workspaceId == workspaceId }.sorted {
            if $0.createdAtISO == $1.createdAtISO { return $0.id > $1.id }
            return $0.createdAtISO > $1.createdAtISO
        }
    }

    func partialImportSummary(importSessionId: String) throws -> PartialImportSummaryDTO? {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.partialImportSummaries[importSessionId]
    }

    func incomingRowDispositions(importSessionId: String) throws -> [IncomingRowDispositionDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.incomingRowDispositions.values
            .filter { $0.importSessionId == importSessionId }
            .sorted { $0.sourceOrdinal < $1.sourceOrdinal }
    }

    func statementFinancialProjections(workspaceId: String) throws -> [StatementFinancialProjectionRecordDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.statementFinancialProjections.values
            .filter { $0.workspaceID == workspaceId }
            .sorted { $0.projection.id < $1.projection.id }
    }

    func statementEquivalenceGroups(workspaceId: String) throws -> [StatementEquivalenceGroupDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.statementEquivalenceGroups.values
            .filter { $0.workspaceID == workspaceId }
            .sorted { $0.id < $1.id }
    }

    func statementEquivalenceMembers(workspaceId: String) throws -> [StatementEquivalenceMemberDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        let groupIDs = Set(state.statementEquivalenceGroups.values
            .filter { $0.workspaceID == workspaceId }
            .map(\.id))
        return state.statementEquivalenceMembers.values
            .filter { groupIDs.contains($0.groupID) }
            .sorted { $0.id < $1.id }
    }

    func preferredTransactionSources(workspaceId: String) throws -> [PreferredTransactionSourceDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        var preferred: [String: (priority: Int, value: PreferredTransactionSourceDTO)] = [:]
        for reviewed in state.cbqReviewedSourcePlans.values where reviewed.basePlan.workspace.id == workspaceId {
            guard let format = reviewed.basePlan.cbqStatementSourceEvidence?.sourceFormatCode else { continue }
            let priority = format == "monthly-pdf" ? 3 : (format == "history-pdf" ? 2 : 1)
            for row in reviewed.rows {
                let transactionID = row.disposition == .new ? row.source.incomingTransactionId : row.expectedTransactionId
                guard let transactionID else { continue }
                let value = PreferredTransactionSourceDTO(
                    transactionId: transactionID,
                    documentId: reviewed.basePlan.historyTemplate.document.id,
                    importSessionId: reviewed.basePlan.historyTemplate.importSession.id,
                    sourceFormatCode: format,
                    sourceTransactionDateISO: row.source.sourceTransactionDateISO,
                    structuredReferenceDigest: row.source.structuredReferenceDigest
                )
                if preferred[transactionID]?.priority ?? 0 < priority { preferred[transactionID] = (priority, value) }
            }
        }
        return preferred.values.map(\.value).sorted { $0.transactionId < $1.transactionId }
    }

    func cbqSourceObservationSummaries(workspaceId: String) throws -> [CBQSourceObservationSummaryDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return state.cbqReviewedSourcePlans.values.compactMap { reviewed in
            guard reviewed.basePlan.workspace.id == workspaceId,
                  let format = reviewed.basePlan.cbqStatementSourceEvidence?.sourceFormatCode else { return nil }
            return CBQSourceObservationSummaryDTO(
                documentId: reviewed.basePlan.historyTemplate.document.id,
                importSessionId: reviewed.basePlan.historyTemplate.importSession.id,
                sourceFormatCode: format,
                sourceRowCount: reviewed.rows.count,
                importedTransactionCount: reviewed.newCount,
                representedTransactionCount: reviewed.representedCount,
                transactionObservationCount: reviewed.rows.count
            )
        }.sorted { $0.documentId < $1.documentId }
    }

    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult {
        state.stateLock.lock()
        defer { state.stateLock.unlock() }

        if let duplicate = priorImportedStatementWithoutLock(
            algorithm: payload.fingerprint.algorithm,
            fingerprint: payload.fingerprint.fingerprint
        ) {
            return .duplicate(duplicate)
        }

        guard state.workspaces[payload.document.workspaceId] != nil else {
            throw RepositoryError.relationshipViolation("Workspace does not exist for atomic import history.")
        }
        guard payload.document.importSessionId == payload.importSession.id,
              payload.importSession.workspaceId == payload.document.workspaceId,
              payload.fingerprint.documentId == payload.document.id,
              payload.fingerprint.importSessionId == payload.importSession.id,
              payload.document.legacyRawTextSHA256 == payload.fingerprint.fingerprint,
              payload.fingerprint.fingerprintData == nil else {
            throw RepositoryError.relationshipViolation("Atomic import-history document relationships are inconsistent.")
        }
        guard state.documents[payload.document.id] == nil,
              state.documentFingerprints[payload.fingerprint.id] == nil,
              state.importSessions[payload.importSession.id] == nil else {
            throw RepositoryError.relationshipViolation("Atomic import-history identifiers already exist.")
        }
        guard !state.documentFingerprints.values.contains(where: {
                  $0.isDuplicateAuthority &&
                  $0.algorithm == payload.fingerprint.algorithm && $0.fingerprint == payload.fingerprint.fingerprint
              }) else {
            throw RepositoryError.relationshipViolation("Atomic import-history fingerprint is not unique.")
        }
        let transactionIds = payload.transactions.map(\.id)
        guard Set(transactionIds).count == transactionIds.count,
              transactionIds.allSatisfy({ state.transactions[$0] == nil }) else {
            throw RepositoryError.relationshipViolation("Atomic import-history transaction identifiers already exist.")
        }

        let accountIds = Set(payload.transactions.compactMap(\.accountId))
        guard accountIds.count == 1,
              payload.transactions.allSatisfy({ $0.accountId != nil }),
              let accountId = accountIds.first,
              state.accounts[accountId] != nil else {
            throw RepositoryError.relationshipViolation("Atomic import-history transactions must use one existing account.")
        }

        for transaction in payload.transactions {
            guard transaction.workspaceId == payload.document.workspaceId,
                  transaction.importSessionId == payload.importSession.id,
                  transaction.documentId == payload.document.id else {
                throw RepositoryError.relationshipViolation("Atomic import-history transaction relationships are inconsistent.")
            }
        }
        let transactionById = Dictionary(uniqueKeysWithValues: payload.transactions.map { ($0.id, $0) })
        let eventKeys = payload.transactionEventIdentities.map { TransactionEventIdentityKeyDTO(algorithm: $0.algorithm, digest: $0.digest) }
        guard Set(eventKeys).count == eventKeys.count,
              payload.transactionEventIdentities.allSatisfy({ event in
                  transactionById[event.transactionId]?.accountId == event.accountId &&
                  event.documentId == payload.document.id && event.importSessionId == payload.importSession.id &&
                  state.transactionEventIdentities.values.allSatisfy { $0.algorithm != event.algorithm || $0.digest != event.digest }
              }) else {
            throw RepositoryError.relationshipViolation("Atomic import-history transaction event identities are inconsistent.")
        }

        var documents = state.documents
        var fingerprints = state.documentFingerprints
        var sessions = state.importSessions
        var transactions = state.transactions
        var eventIdentities = state.transactionEventIdentities
        var attempts = state.importAttempts

        documents[payload.document.id] = payload.document
        fingerprints[payload.fingerprint.id] = payload.fingerprint
        sessions[payload.importSession.id] = ImportSessionRecordDTO(
            id: payload.importSession.id,
            workspaceId: payload.importSession.workspaceId,
            userVisibleName: payload.importSession.userVisibleName,
            startedAtISO: payload.importSession.startedAtISO,
            completedAtISO: payload.completedAtISO,
            validationStatus: "passed",
            readerVersion: payload.importSession.readerVersion,
            parserVersion: payload.importSession.parserVersion,
            layoutVersion: payload.importSession.layoutVersion
        )
        for transaction in payload.transactions {
            transactions[transaction.id] = transaction
        }
        for event in payload.transactionEventIdentities { eventIdentities[event.id] = event }
        guard payload.successfulAttempt.workspaceId == payload.importSession.workspaceId,
              payload.successfulAttempt.outcomeCode == ImportAttemptOutcome.successfulImport.rawValue,
              payload.successfulAttempt.importSessionId == payload.importSession.id,
              payload.successfulAttempt.documentId == payload.document.id,
              payload.successfulAttempt.accountId == accountId,
              attempts[payload.successfulAttempt.id] == nil else {
            throw RepositoryError.relationshipViolation("Atomic import attempt relationships are inconsistent.")
        }
        attempts[payload.successfulAttempt.id] = payload.successfulAttempt

        state.documents = documents
        state.documentFingerprints = fingerprints
        state.importSessions = sessions
        state.transactions = transactions
        state.transactionEventIdentities = eventIdentities
        state.importAttempts = attempts
        return .committed
    }

    private func priorImportedStatementWithoutLock(
        algorithm: String,
        fingerprint: String
    ) -> PriorImportedStatementDTO? {
        guard let storedFingerprint = state.documentFingerprints.values.first(where: {
            $0.isDuplicateAuthority && $0.algorithm == algorithm && $0.fingerprint == fingerprint
        }),
        let session = state.importSessions[storedFingerprint.importSessionId],
        session.validationStatus == "passed" else {
            return nil
        }
        let importSessionId = storedFingerprint.importSessionId

        let importedTransactions = state.transactions.values
            .filter { $0.importSessionId == importSessionId }
        let accountId = importedTransactions.compactMap(\.accountId).sorted().first
        return PriorImportedStatementDTO(
            importSessionId: importSessionId,
            completedAtISO: session.completedAtISO,
            transactionCount: importedTransactions.count,
            accountId: accountId,
            accountDisplayName: accountId.flatMap { state.accounts[$0]?.name }
        )
    }
}

/// Dormant provider implementation used by contract and concurrency tests.
/// It deliberately publishes a complete accepted graph only after every
/// validation succeeds on local copies.
private final class InMemoryConfirmedImportRepo: ConfirmedImportRepository {
    private let state: InMemoryRepositoryState
    private let generationToken: ProviderGenerationToken
    private var consumedPartialPlanIDs = Set<String>()

    init(state: InMemoryRepositoryState, generationToken: ProviderGenerationToken) {
        self.state = state
        self.generationToken = generationToken
    }

    func reviewCBQSourceOverlap(_ plan: ConfirmedImportPlanDTO) -> CBQSourceOverlapReviewResult {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard plan.providerGeneration == generationToken else { return .staleProviderGeneration }
        guard (try? plan.historyTemplate.validateFingerprints()) != nil else { return .repositoryIntegrityConflict }
        return reviewCBQSourceOverlapWithoutLock(plan, planID: UUID().uuidString)
    }

    func commitReviewedCBQSourceOverlap(_ reviewed: ReviewedCBQSourceOverlapPlanDTO) -> ConfirmedImportRepositoryResult {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard consumedPartialPlanIDs.insert(reviewed.id).inserted,
              reviewed.basePlan.providerGeneration == generationToken,
              reviewed.hasValidDigest(), reviewed.blockedCount == 0,
              case .eligible(let current) = reviewCBQSourceOverlapWithoutLock(reviewed.basePlan, planID: reviewed.id),
              current == reviewed else { return .reviewedPartialPlanStale }
        let narrowed = narrowedCBQPlan(reviewed)
        let result = commitConfirmedImport(narrowed)
        guard case .committed(let receipt) = result else { return result }
        let history = reviewed.basePlan.historyTemplate
        for identity in reviewed.basePlan.cbqSourceIdentityPatterns {
            let key = "\(history.document.id)|\(identity.kind)"
            state.cbqSourceIdentityRecords[key] = CBQSourceIdentityRecordDTO(
                accountId: reviewed.accountId, kind: identity.kind, pattern: identity.pattern
            )
        }
        for row in reviewed.rows {
            guard let digest = row.source.structuredReferenceDigest else { continue }
            let transactionID = row.disposition == .new ? row.source.incomingTransactionId : row.expectedTransactionId
            guard let transactionID else { return .repositoryIntegrityConflict }
            state.cbqTransactionSourceReferenceDigests[transactionID, default: []].insert(digest)
        }
        state.cbqReviewedSourcePlans[history.document.id] = reviewed
        return .sourceOverlapCommitted(receipt, newTransactionCount: reviewed.newCount)
    }

    func reviewPartialImport(_ plan: ConfirmedImportPlanDTO) -> PartialImportReviewResult {
        state.stateLock.lock()
        defer { state.stateLock.unlock() }
        guard plan.providerGeneration == generationToken else {
            return .repositoryIntegrityConflict
        }
        guard (try? plan.historyTemplate.validateFingerprints()) != nil else {
            return .repositoryIntegrityConflict
        }
        return reviewPartialImportWithoutLock(plan, planID: UUID().uuidString)
    }

    func reviewStatementEquivalence(_ plan: ConfirmedImportPlanDTO) -> StatementEquivalenceReviewResult {
        state.stateLock.lock()
        defer { state.stateLock.unlock() }
        guard plan.providerGeneration == generationToken else {
            return .evidenceUnavailable
        }
        return reviewStatementEquivalenceWithoutLock(plan)
    }

    func commitReviewedPartialImport(_ reviewed: ReviewedPartialImportPlanDTO) -> ConfirmedImportRepositoryResult {
        state.stateLock.lock()
        defer { state.stateLock.unlock() }
        guard consumedPartialPlanIDs.insert(reviewed.id).inserted,
              reviewed.basePlan.providerGeneration == generationToken,
              reviewed.hasValidDigest(),
              (try? reviewed.basePlan.historyTemplate.validateFingerprints()) != nil,
              let authority = reviewed.basePlan.historyTemplate.duplicateAuthorityFingerprint else {
            return .reviewedPartialPlanStale
        }
        let plan = reviewed.basePlan
        guard !state.documentFingerprints.values.contains(where: {
            $0.isDuplicateAuthority &&
            $0.algorithm == authority.algorithm &&
            $0.fingerprint == authority.fingerprint
        }) else { return .reviewedPartialPlanStale }
        guard case .eligible(let current) = reviewPartialImportWithoutLock(
            plan,
            planID: reviewed.id
        ), current == reviewed,
              validateExistingIdentityWithoutLock(plan, accountID: reviewed.existingAccountId),
              let normalizedDocument = plan.historyTemplate.normalizedDocument,
              let start = plan.declaredStatementStartISO,
              let end = plan.declaredStatementEndISO,
              let openingMinor = plan.openingBalanceMinor,
              let openingDecimal = plan.openingBalanceDecimal,
              let closingMinor = plan.closingBalanceMinor,
              let closingDecimal = plan.closingBalanceDecimal else {
            return .reviewedPartialPlanStale
        }

        var identifiers = state.accountIdentifiers
        var documents = state.documents
        var fingerprints = state.documentFingerprints
        var sessions = state.importSessions
        var normalizedDocuments = state.normalizedDocuments
        var normalizedRows = state.normalizedRows
        var transactions = state.transactions
        var eventIdentities = state.transactionEventIdentities
        var attempts = state.importAttempts
        var observations = state.identifierObservations
        var summaries = state.partialImportSummaries
        var dispositions = state.incomingRowDispositions
        let history = plan.historyTemplate
        let injectedFailure = state.confirmedImportFailureInjection

        for candidate in plan.identifiers {
            let existing = identifiers.values.first {
                $0.workspaceId == plan.workspace.id &&
                $0.accountId == reviewed.existingAccountId &&
                $0.scheme == candidate.scheme &&
                $0.identifier == candidate.normalizedValue
            }
            let ownership = existing ?? AccountIdentifierDTO(
                accountId: reviewed.existingAccountId,
                workspaceId: plan.workspace.id,
                scheme: candidate.scheme,
                identifier: candidate.normalizedValue,
                strength: "strong",
                verificationState: "verified",
                provenance: candidate.provenanceCode,
                createdAtISO: history.completedAtISO
            )
            identifiers[ownership.id] = ownership
            if injectedFailure == .identifierOwnership { return .repositoryIntegrityConflict }
            let observation = IdentifierObservationDTO(
                ownershipId: ownership.id,
                importSessionId: history.importSession.id,
                documentId: history.document.id,
                parserProvenanceCode: candidate.provenanceCode,
                associationAuthorityCode: "confirmed-partial-import",
                createdAtISO: history.completedAtISO
            )
            observations["\(ownership.id)|\(history.importSession.id)|\(history.document.id)"] = observation
            if injectedFailure == .observation { return .repositoryIntegrityConflict }
        }

        guard documents[history.document.id] == nil,
              history.fingerprints.allSatisfy({ fingerprints[$0.id] == nil }),
              sessions[history.importSession.id] == nil,
              normalizedDocuments[normalizedDocument.id] == nil,
              history.normalizedRows.allSatisfy({ normalizedRows[$0.id] == nil }) else {
            return .repositoryIntegrityConflict
        }
        documents[history.document.id] = history.document
        if injectedFailure == .document { return .repositoryIntegrityConflict }
        for (index, fingerprint) in history.fingerprints.enumerated() {
            fingerprints[fingerprint.id] = fingerprint
            if index == min(1, history.fingerprints.count - 1), injectedFailure == .fingerprint {
                return .repositoryIntegrityConflict
            }
        }
        sessions[history.importSession.id] = ImportSessionRecordDTO(
            id: history.importSession.id,
            workspaceId: history.importSession.workspaceId,
            userVisibleName: history.importSession.userVisibleName,
            startedAtISO: history.importSession.startedAtISO,
            completedAtISO: history.completedAtISO,
            validationStatus: "passed",
            readerVersion: history.importSession.readerVersion,
            parserVersion: history.importSession.parserVersion,
            layoutVersion: history.importSession.layoutVersion
        )
        if injectedFailure == .importSession { return .repositoryIntegrityConflict }
        normalizedDocuments[normalizedDocument.id] = normalizedDocument
        history.normalizedRows.forEach { normalizedRows[$0.id] = $0 }

        for row in reviewed.rows {
            guard let template = plan.transactionTemplates.first(where: {
                $0.transaction.rawRows.first?.normalizedRowId == row.normalizedRowId
            }) else { return .repositoryIntegrityConflict }
            let transactionID: String
            let eventIdentityID: String
            switch row.disposition {
            case .recognizedExisting:
                guard let expectedTransactionID = row.expectedTransactionId,
                      let expectedEventID = row.expectedEventIdentityId,
                      let existing = transactions[expectedTransactionID],
                      !existing.rawRows.contains(where: { $0.normalizedRowId == row.normalizedRowId }) else {
                    return .repositoryIntegrityConflict
                }
                let incomingRaw = TransactionRawRowDTO(
                    id: "partial-source-\(history.importSession.id)-\(row.sourceOrdinal)",
                    normalizedRowId: row.normalizedRowId,
                    contributionType: PartialImportRowDisposition.recognizedExisting.rawValue,
                    sourceOrdinal: row.sourceOrdinal,
                    normalizedRecordDigest: row.normalizedRecordDigest,
                    normalizedDocumentId: normalizedDocument.id,
                    parserProfileId: normalizedDocument.profileId,
                    parserProfileVersion: normalizedDocument.profileVersion
                )
                transactions[existing.id] = replacingRawRows(
                    existing,
                    rawRows: existing.rawRows + [incomingRaw]
                )
                transactionID = existing.id
                eventIdentityID = expectedEventID
            case .importedUnique:
                let transaction = withFinalRelationships(
                    template.transaction,
                    accountID: reviewed.existingAccountId,
                    importSessionID: history.importSession.id,
                    documentID: history.document.id
                )
                guard transactions[transaction.id] == nil else {
                    return .repositoryIntegrityConflict
                }
                transactionID = transaction.id
                eventIdentityID = "partial-event-\(transaction.id)"
                transactions[transaction.id] = transaction
                eventIdentities[eventIdentityID] = TransactionEventIdentityDTO(
                    id: eventIdentityID,
                    transactionId: transaction.id,
                    accountId: reviewed.existingAccountId,
                    documentId: history.document.id,
                    importSessionId: history.importSession.id,
                    algorithm: row.eventAlgorithm,
                    digest: row.eventDigest,
                    createdAtISO: history.completedAtISO
                )
            }
            let disposition = IncomingRowDispositionDTO(
                id: "partial-disposition-\(history.importSession.id)-\(row.sourceOrdinal)",
                importSessionId: history.importSession.id,
                documentId: history.document.id,
                normalizedRowId: row.normalizedRowId,
                sourceOrdinal: row.sourceOrdinal,
                dispositionCode: row.disposition.rawValue,
                transactionId: transactionID,
                transactionEventIdentityId: eventIdentityID,
                statementDateISO: row.statementDateISO,
                financialDateRole: row.financialDateRole,
                statementTimezoneEvidence: row.timezoneEvidence,
                nativeCurrency: row.nativeCurrency,
                amountMinor: row.amountMinor,
                amountDecimal: row.amountDecimal,
                direction: row.direction,
                runningBalanceMinor: row.runningBalanceMinor,
                createdAtISO: history.completedAtISO,
                eventTransactionId: transactionID
            )
            guard dispositions[disposition.id] == nil else {
                return .repositoryIntegrityConflict
            }
            dispositions[disposition.id] = disposition
        }
        if injectedFailure == .transactions { return .repositoryIntegrityConflict }
        if injectedFailure == .eventIdentities { return .repositoryIntegrityConflict }
        if injectedFailure == .partialDispositions { return .repositoryIntegrityConflict }

        let attempt = ImportAttemptDTO(
            id: history.successfulAttempt.id,
            workspaceId: plan.workspace.id,
            createdAtISO: history.completedAtISO,
            outcomeCode: ImportAttemptOutcome.partialImportCommitted.rawValue,
            coverageCode: ImportAttemptCoverage.allRowsSupportedAxisUPIReviewed.rawValue,
            accountDecisionCode: history.successfulAttempt.accountDecisionCode,
            guidanceCode: ImportAttemptGuidance.partialImportCompleted.rawValue,
            persistenceCode: ImportAttemptPersistence.committed.rawValue,
            transactionCount: reviewed.importedCount,
            accountId: reviewed.existingAccountId,
            importSessionId: history.importSession.id,
            documentId: history.document.id,
            sourceRowCount: reviewed.sourceRowCount,
            importedTransactionCount: reviewed.importedCount,
            recognizedExistingRowCount: reviewed.recognizedCount,
            blockedRowCount: reviewed.blockedCount
        )
        attempts[attempt.id] = attempt
        if injectedFailure == .successfulAttempt { return .repositoryIntegrityConflict }
        summaries[history.importSession.id] = PartialImportSummaryDTO(
            importSessionId: history.importSession.id,
            documentId: history.document.id,
            planDigestAlgorithm: reviewed.digestAlgorithm,
            planDigest: reviewed.digest,
            statementStartDateISO: start,
            statementEndDateISO: end,
            nativeCurrency: "INR",
            sourceRowCount: reviewed.sourceRowCount,
            importedTransactionCount: reviewed.importedCount,
            recognizedExistingRowCount: reviewed.recognizedCount,
            blockedRowCount: reviewed.blockedCount,
            openingBalanceMinor: openingMinor,
            openingBalanceDecimal: openingDecimal,
            closingBalanceMinor: closingMinor,
            closingBalanceDecimal: closingDecimal,
            createdAtISO: history.completedAtISO
        )
        if injectedFailure == .partialSummary { return .repositoryIntegrityConflict }
        if injectedFailure == .sessionCompletion { return .repositoryIntegrityConflict }

        state.accountIdentifiers = identifiers
        state.identifierObservations = observations
        state.documents = documents
        state.documentFingerprints = fingerprints
        state.importSessions = sessions
        state.normalizedDocuments = normalizedDocuments
        state.normalizedRows = normalizedRows
        state.transactions = transactions
        state.transactionEventIdentities = eventIdentities
        state.importAttempts = attempts
        state.partialImportSummaries = summaries
        state.incomingRowDispositions = dispositions
        return .partialCommitted(
            ConfirmedImportReceiptDTO(
                workspaceId: plan.workspace.id,
                accountId: reviewed.existingAccountId,
                importSessionId: history.importSession.id,
                documentId: history.document.id
            )
        )
    }

    func commitConfirmedImport(_ plan: ConfirmedImportPlanDTO) -> ConfirmedImportRepositoryResult {
        state.stateLock.lock()
        defer { state.stateLock.unlock() }

        guard plan.providerGeneration == generationToken else { return .staleProviderGeneration }
        guard (try? plan.historyTemplate.validateFingerprints()) != nil,
              let authority = plan.historyTemplate.duplicateAuthorityFingerprint else {
            return .repositoryIntegrityConflict
        }
        guard plan.transactionTemplates.allSatisfy(\.isAccountIndependent),
              plan.transactionTemplates.allSatisfy({ $0.transaction.workspaceId == plan.workspace.id }),
              plan.historyTemplate.document.workspaceId == plan.workspace.id,
              plan.historyTemplate.document.importSessionId == plan.historyTemplate.importSession.id,
              plan.historyTemplate.importSession.workspaceId == plan.workspace.id,
              plan.historyTemplate.successfulAttempt.workspaceId == plan.workspace.id,
              plan.historyTemplate.normalizedDocument != nil,
              !plan.historyTemplate.normalizedRows.isEmpty,
              Set(plan.historyTemplate.normalizedRows.map(\.sourceOrdinal)).count == plan.historyTemplate.normalizedRows.count,
              plan.transactionTemplates.allSatisfy({ !$0.transaction.rawRows.isEmpty }),
              hasValidTrustedProvenance(plan),
              Set(plan.transactionTemplates.map { $0.transaction.id }).count == plan.transactionTemplates.count,
              !hasDuplicateIdentifierCandidates(plan.identifiers) else {
            return .repositoryIntegrityConflict
        }
        guard !state.documentFingerprints.values.contains(where: {
            $0.isDuplicateAuthority &&
            $0.algorithm == authority.algorithm &&
            $0.fingerprint == authority.fingerprint
        }) else { return .exactDuplicate }

        var workspaces = state.workspaces
        var accounts = state.accounts
        var identifiers = state.accountIdentifiers
        var documents = state.documents
        var fingerprints = state.documentFingerprints
        var sessions = state.importSessions
        var normalizedDocuments = state.normalizedDocuments
        var normalizedRows = state.normalizedRows
        var transactions = state.transactions
        var eventIdentities = state.transactionEventIdentities
        var attempts = state.importAttempts
        var observations = state.identifierObservations
        var statementProjections = state.statementFinancialProjections
        var equivalenceGroups = state.statementEquivalenceGroups
        var equivalenceMembers = state.statementEquivalenceMembers
        let injectedFailure = state.confirmedImportFailureInjection
        let supportingFailure = state.supportingSourceFailureInjection

        let ownerSets = plan.identifiers.map { candidate in
            Set(identifiers.values.filter {
                $0.workspaceId == plan.workspace.id && $0.scheme == candidate.scheme && $0.identifier == candidate.normalizedValue
            }.map(\.accountId))
        }
        if ownerSets.contains(where: { $0.count > 1 }) { return .identityAmbiguous }
        let resolvedOwners = Set(ownerSets.flatMap { $0 })
        if resolvedOwners.count > 1 { return .identityConflict }
        let currentOwner = resolvedOwners.first
        switch plan.advisoryIdentity {
        case .resolved(let accountID) where currentOwner != accountID: return .staleIdentityDecision
        case .noMatch where currentOwner != nil:
            if isCBQObservationPlan(plan), case .useExistingAccount(let selected) = plan.accountChoice, selected == currentOwner {
                break
            }
            if case .createProposedAccount = plan.accountChoice {
                return .identifierOwnershipConflict
            }
            return .staleIdentityDecision
        case .ambiguous where !isCBQObservationPlan(plan): return .identityAmbiguous
        case .conflict: return .identityConflict
        default: break
        }

        let account: AccountDTO
        switch plan.accountChoice {
        case .unspecified:
            return .explicitAccountChoiceRequired
        case .createProposedAccount:
            guard currentOwner == nil else { return .staleIdentityDecision }
            guard plan.proposedAccount.workspaceId == plan.workspace.id else { return .repositoryIntegrityConflict }
            workspaces[plan.workspace.id] = plan.workspace
            if injectedFailure == .workspace { return .repositoryIntegrityConflict }
            guard accounts[plan.proposedAccount.id] == nil else { return .repositoryIntegrityConflict }
            accounts[plan.proposedAccount.id] = plan.proposedAccount
            if injectedFailure == .account { return .repositoryIntegrityConflict }
            account = plan.proposedAccount
        case .useExistingAccount(let accountID):
            guard let existing = accounts[accountID] else { return .selectedAccountUnavailable }
            guard existing.workspaceId == plan.workspace.id else { return .selectedAccountWorkspaceMismatch }
            if let currentOwner {
                guard currentOwner == accountID else { return .identifierOwnershipConflict }
            } else if identifiers.values.contains(where: { $0.accountId == accountID && $0.workspaceId == plan.workspace.id }) {
                guard isCBQObservationPlan(plan), cbqAccountIsCompatible(plan, accountID: accountID) else {
                    return .selectedAccountIneligible
                }
            }
            account = existing
        }

        let equivalenceReview = reviewStatementEquivalenceWithoutLock(
            plan,
            resolvedAccountID: account.id
        )
        let isSupportingSource: Bool
        switch equivalenceReview {
        case .notApplicable, .firstAcceptedSource:
            isSupportingSource = false
        case .equivalent:
            guard case .useExistingAccount(let selectedAccountID) = plan.accountChoice,
                  selectedAccountID == account.id else {
                return .statementEquivalenceEvidenceUnavailable
            }
            isSupportingSource = true
        case .conflict:
            return .statementEquivalenceConflict
        case .evidenceUnavailable:
            return .statementEquivalenceEvidenceUnavailable
        case .formatAlreadyRecorded:
            return .equivalentFormatAlreadyRecorded
        }

        for candidate in plan.identifiers {
            let matching = identifiers.values.filter {
                $0.workspaceId == plan.workspace.id && $0.scheme == candidate.scheme && $0.identifier == candidate.normalizedValue
            }
            if matching.contains(where: { $0.accountId != account.id }) { return .identifierOwnershipConflict }
            let ownership = matching.first ?? AccountIdentifierDTO(
                accountId: account.id,
                workspaceId: plan.workspace.id,
                scheme: candidate.scheme,
                identifier: candidate.normalizedValue,
                strength: "strong",
                verificationState: "verified",
                provenance: candidate.provenanceCode,
                createdAtISO: plan.historyTemplate.completedAtISO
            )
            identifiers[ownership.id] = ownership
            if injectedFailure == .identifierOwnership { return .repositoryIntegrityConflict }
            let observation = IdentifierObservationDTO(
                ownershipId: ownership.id,
                importSessionId: plan.historyTemplate.importSession.id,
                documentId: plan.historyTemplate.document.id,
                parserProvenanceCode: candidate.provenanceCode,
                associationAuthorityCode: "confirmed-import",
                createdAtISO: plan.historyTemplate.completedAtISO
            )
            observations["\(ownership.id)|\(observation.importSessionId)|\(observation.documentId)"] = observation
            if injectedFailure == .observation { return .repositoryIntegrityConflict }
            if isSupportingSource, supportingFailure == .identifierObservation {
                return .repositoryIntegrityConflict
            }
        }

        var finalTransactions = [TransactionDTO]()
        var finalEvents = [TransactionEventIdentityDTO]()
        for template in plan.transactionTemplates where !isSupportingSource {
            let transaction = withFinalRelationships(
                template.transaction,
                accountID: account.id,
                importSessionID: plan.historyTemplate.importSession.id,
                documentID: plan.historyTemplate.document.id
            )
            guard transactions[transaction.id] == nil else { return .repositoryIntegrityConflict }
            finalTransactions.append(transaction)
            if let evidence = template.eventEvidence {
                let identity: TransactionEventIdentity
                do {
                    identity = try TransactionEventIdentity.make(transactionID: transaction.id, evidence: evidence, accountID: account.id)
                } catch { return .repositoryIntegrityConflict }
                let keyMatches = finalEvents.contains { $0.algorithm == identity.algorithmIdentifier && $0.digest == identity.digest }
                if keyMatches { return .repeatedIncomingEventEvidence }
                if let existing = eventIdentities.values.first(where: { $0.algorithm == identity.algorithmIdentifier && $0.digest == identity.digest }) {
                    return existing.accountId == account.id ? .existingEventDuplicate : .eventOwnershipConflict
                }
                finalEvents.append(TransactionEventIdentityDTO(
                    id: UUID().uuidString,
                    transactionId: transaction.id,
                    accountId: account.id,
                    documentId: plan.historyTemplate.document.id,
                    importSessionId: plan.historyTemplate.importSession.id,
                    algorithm: identity.algorithmIdentifier,
                    digest: identity.digest,
                    createdAtISO: plan.historyTemplate.completedAtISO
                ))
            }
        }

        let history = plan.historyTemplate
        guard documents[history.document.id] == nil,
              history.fingerprints.allSatisfy({ fingerprints[$0.id] == nil }),
              sessions[history.importSession.id] == nil,
              let normalizedDocument = history.normalizedDocument,
              normalizedDocument.importSessionId == history.importSession.id,
              normalizedDocument.documentId == history.document.id,
              normalizedDocuments[normalizedDocument.id] == nil,
              history.normalizedRows.allSatisfy({
                  $0.normalizedDocumentId == normalizedDocument.id &&
                  $0.sourceOrdinal > 0 &&
                  !$0.digest.isEmpty &&
                  normalizedRows[$0.id] == nil
              }),
              finalTransactions.allSatisfy({ transaction in
                  transaction.rawRows.allSatisfy { raw in
                      history.normalizedRows.contains { $0.id == raw.normalizedRowId }
                  }
              }),
              attempts[history.successfulAttempt.id] == nil,
              history.successfulAttempt.accountId == account.id,
              history.successfulAttempt.importSessionId == history.importSession.id,
              history.successfulAttempt.documentId == history.document.id else { return .repositoryIntegrityConflict }

        documents[history.document.id] = history.document
        if injectedFailure == .document { return .repositoryIntegrityConflict }
        if isSupportingSource, supportingFailure == .document { return .repositoryIntegrityConflict }
        for (index, fingerprint) in history.fingerprints.enumerated() {
            fingerprints[fingerprint.id] = fingerprint
            if index == min(1, history.fingerprints.count - 1), injectedFailure == .fingerprint {
                return .repositoryIntegrityConflict
            }
            if index == min(1, history.fingerprints.count - 1),
               isSupportingSource, supportingFailure == .fingerprint {
                return .repositoryIntegrityConflict
            }
        }
        sessions[history.importSession.id] = ImportSessionRecordDTO(
            id: history.importSession.id, workspaceId: history.importSession.workspaceId,
            userVisibleName: history.importSession.userVisibleName, startedAtISO: history.importSession.startedAtISO,
            completedAtISO: history.completedAtISO, validationStatus: "passed",
            readerVersion: history.importSession.readerVersion, parserVersion: history.importSession.parserVersion,
            layoutVersion: history.importSession.layoutVersion
        )
        if injectedFailure == .importSession { return .repositoryIntegrityConflict }
        if isSupportingSource, supportingFailure == .importSession { return .repositoryIntegrityConflict }
        normalizedDocuments[normalizedDocument.id] = normalizedDocument
        if isSupportingSource, supportingFailure == .normalizedDocument { return .repositoryIntegrityConflict }
        history.normalizedRows.forEach { normalizedRows[$0.id] = $0 }
        if isSupportingSource, supportingFailure == .normalizedRows { return .repositoryIntegrityConflict }

        if let projection = plan.statementFinancialProjection {
            guard projection.isValid(), statementProjections[projection.id] == nil else {
                return .repositoryIntegrityConflict
            }
            statementProjections[projection.id] = StatementFinancialProjectionRecordDTO(
                projection: projection,
                workspaceID: plan.workspace.id,
                accountID: account.id,
                documentID: history.document.id,
                importSessionID: history.importSession.id,
                createdAtISO: history.completedAtISO
            )
            if isSupportingSource, supportingFailure == .projection { return .repositoryIntegrityConflict }
            if isSupportingSource, supportingFailure == .projectionEvents { return .repositoryIntegrityConflict }
        }
        finalTransactions.forEach { transactions[$0.id] = $0 }
        if injectedFailure == .transactions { return .repositoryIntegrityConflict }
        finalEvents.forEach { eventIdentities[$0.id] = $0 }
        if injectedFailure == .eventIdentities { return .repositoryIntegrityConflict }
        if let projection = plan.statementFinancialProjection {
            switch equivalenceReview {
            case .firstAcceptedSource:
                let group = StatementEquivalenceGroupDTO(
                    id: "statement-equivalence-group-\(projection.id)",
                    workspaceID: plan.workspace.id,
                    accountID: account.id,
                    institutionCode: projection.institutionCode,
                    statementFamilyCode: projection.statementFamilyCode,
                    statementStartDateISO: projection.statementStartDateISO,
                    statementEndDateISO: projection.statementEndDateISO,
                    nativeCurrency: projection.nativeCurrency,
                    projectionAlgorithm: projection.algorithmIdentifier,
                    projectionDigest: projection.digest,
                    authoritativeProjectionID: projection.id,
                    createdAtISO: history.completedAtISO
                )
                guard equivalenceGroups[group.id] == nil else { return .repositoryIntegrityConflict }
                equivalenceGroups[group.id] = group
                let member = StatementEquivalenceMemberDTO(
                    id: "statement-equivalence-member-\(projection.id)",
                    groupID: group.id,
                    projectionID: projection.id,
                    role: .authoritative,
                    sourceFormatCode: projection.sourceFormatCode,
                    createdAtISO: history.completedAtISO
                )
                equivalenceMembers[member.id] = member
            case .equivalent:
                guard let group = matchingEquivalenceGroup(
                    projection,
                    workspaceID: plan.workspace.id,
                    accountID: account.id,
                    groups: equivalenceGroups
                ) else { return .repositoryIntegrityConflict }
                let member = StatementEquivalenceMemberDTO(
                    id: "statement-equivalence-member-\(projection.id)",
                    groupID: group.id,
                    projectionID: projection.id,
                    role: .supporting,
                    sourceFormatCode: projection.sourceFormatCode,
                    createdAtISO: history.completedAtISO
                )
                guard !equivalenceMembers.values.contains(where: {
                    $0.groupID == group.id && ($0.projectionID == projection.id || $0.sourceFormatCode == projection.sourceFormatCode)
                }) else { return .equivalentFormatAlreadyRecorded }
                equivalenceMembers[member.id] = member
                if supportingFailure == .equivalenceMember {
                    return .repositoryIntegrityConflict
                }
            case .notApplicable, .conflict, .evidenceUnavailable, .formatAlreadyRecorded:
                return .repositoryIntegrityConflict
            }
        }
        let acceptedAttempt: ImportAttemptDTO
        if isSupportingSource,
           case .equivalent(let authoritativeImportSessionID) = equivalenceReview {
            acceptedAttempt = ImportAttemptDTO(
                id: history.successfulAttempt.id,
                workspaceId: plan.workspace.id,
                createdAtISO: history.completedAtISO,
                outcomeCode: ImportAttemptOutcome.equivalentSourceRecorded.rawValue,
                coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
                accountDecisionCode: ImportAttemptAccountDecision.noFinancialMutation.rawValue,
                guidanceCode: ImportAttemptGuidance.equivalentSourceRecorded.rawValue,
                persistenceCode: ImportAttemptPersistence.committed.rawValue,
                transactionCount: 0,
                accountId: account.id,
                importSessionId: history.importSession.id,
                documentId: history.document.id,
                relatedImportSessionId: authoritativeImportSessionID,
                sourceRowCount: plan.statementFinancialProjection?.eventCount,
                importedTransactionCount: 0,
                recognizedExistingRowCount: plan.statementFinancialProjection?.eventCount,
                blockedRowCount: 0
            )
        } else {
            acceptedAttempt = history.successfulAttempt
        }
        attempts[acceptedAttempt.id] = acceptedAttempt
        if injectedFailure == .successfulAttempt { return .repositoryIntegrityConflict }
        if isSupportingSource, supportingFailure == .successfulAttempt { return .repositoryIntegrityConflict }
        if injectedFailure == .partialDispositions { return .repositoryIntegrityConflict }
        if injectedFailure == .partialSummary { return .repositoryIntegrityConflict }
        if injectedFailure == .sessionCompletion { return .repositoryIntegrityConflict }
        if isSupportingSource, supportingFailure == .completion { return .repositoryIntegrityConflict }

        state.workspaces = workspaces; state.accounts = accounts; state.accountIdentifiers = identifiers
        state.identifierObservations = observations; state.documents = documents; state.documentFingerprints = fingerprints
        state.importSessions = sessions; state.normalizedDocuments = normalizedDocuments; state.normalizedRows = normalizedRows
        state.transactions = transactions; state.transactionEventIdentities = eventIdentities
        state.importAttempts = attempts
        state.statementFinancialProjections = statementProjections
        state.statementEquivalenceGroups = equivalenceGroups
        state.statementEquivalenceMembers = equivalenceMembers
        let receipt = ConfirmedImportReceiptDTO(workspaceId: plan.workspace.id, accountId: account.id, importSessionId: history.importSession.id, documentId: history.document.id)
        return isSupportingSource ? .equivalentSourceRecorded(receipt) : .committed(receipt)
    }

    private func reviewCBQSourceOverlapWithoutLock(_ plan: ConfirmedImportPlanDTO, planID: String) -> CBQSourceOverlapReviewResult {
        guard isCBQObservationPlan(plan), let evidence = plan.cbqStatementSourceEvidence,
              evidence.sourceFormatCode == expectedCBQSourceFormat(plan),
              plan.cbqSourceRows.count == plan.transactionTemplates.count,
              plan.cbqSourceRows.count == plan.historyTemplate.normalizedRows.count,
              Set(plan.cbqSourceRows.map(\.sourceOrdinal)).count == plan.cbqSourceRows.count else { return .notApplicable }
        let compatible = compatibleCBQAccountIDs(plan)
        let accountID: String
        switch plan.accountChoice {
        case .createProposedAccount:
            guard compatible.isEmpty else { return .accountChoiceRequired(compatibleAccountIds: compatible) }
            accountID = plan.proposedAccount.id
        case .useExistingAccount(let selected):
            guard compatible.contains(selected) else { return .identityConflict }
            accountID = selected
        case .unspecified:
            return compatible.isEmpty ? .identityConflict : .accountChoiceRequired(compatibleAccountIds: compatible)
        }
        var rows = [ReviewedCBQSourceOverlapRowDTO]()
        var blocked = 0
        var used = Set<String>()
        for source in plan.cbqSourceRows.sorted(by: { $0.sourceOrdinal < $1.sourceOrdinal }) {
            guard source.nativeCurrency == "QAR", source.signedAmountMinor != 0,
                  plan.historyTemplate.normalizedRows.contains(where: {
                      $0.id == source.normalizedRowId && $0.sourceOrdinal == source.sourceOrdinal && $0.digest == source.normalizedRecordDigest
                  }) else { return .repositoryIntegrityConflict }
            if case .createProposedAccount = plan.accountChoice {
                rows.append(.init(source: source, disposition: .new)); continue
            }
            var candidates = state.transactions.values.filter {
                $0.accountId == accountID && $0.postedDateISO == source.postingDateISO &&
                $0.nativeCurrency == source.nativeCurrency && $0.amountMinor == source.signedAmountMinor &&
                $0.amountDecimal == source.signedAmountDecimal && $0.direction == source.direction &&
                $0.runningBalanceMinor == source.runningBalanceMinor
            }.map(\.id).sorted()
            if candidates.count > 1, let digest = source.structuredReferenceDigest {
                candidates = candidates.filter { state.cbqTransactionSourceReferenceDigests[$0]?.contains(digest) == true }
            }
            if candidates.isEmpty { rows.append(.init(source: source, disposition: .new)) }
            else if candidates.count == 1, let id = candidates.first, !used.contains(id) {
                used.insert(id); rows.append(.init(source: source, disposition: .representedExisting, expectedTransactionId: id))
            } else { blocked += 1 }
        }
        guard blocked == 0, rows.count == plan.cbqSourceRows.count else { return .blockedOrAmbiguousRows(count: blocked) }
        let newCount = rows.filter { $0.disposition == .new }.count
        return .eligible(.init(id: planID, basePlan: plan, accountId: accountID, rows: rows, newCount: newCount, representedCount: rows.count - newCount, blockedCount: 0))
    }

    private func narrowedCBQPlan(_ reviewed: ReviewedCBQSourceOverlapPlanDTO) -> ConfirmedImportPlanDTO {
        let plan = reviewed.basePlan
        let newIDs = Set(reviewed.rows.filter { $0.disposition == .new }.map(\.source.incomingTransactionId))
        let old = plan.historyTemplate.successfulAttempt
        let attempt = ImportAttemptDTO(
            id: old.id, workspaceId: old.workspaceId, createdAtISO: old.createdAtISO,
            outcomeCode: ImportAttemptOutcome.cbqSourceOverlapCommitted.rawValue,
            coverageCode: old.coverageCode, accountDecisionCode: old.accountDecisionCode,
            guidanceCode: old.guidanceCode, persistenceCode: old.persistenceCode,
            transactionCount: reviewed.newCount, accountId: reviewed.accountId,
            importSessionId: old.importSessionId, documentId: old.documentId,
            relatedImportSessionId: old.relatedImportSessionId, sourceRowCount: reviewed.rows.count,
            importedTransactionCount: reviewed.newCount, recognizedExistingRowCount: reviewed.representedCount, blockedRowCount: 0
        )
        let history = ConfirmedImportHistoryTemplateDTO(
            document: plan.historyTemplate.document, fingerprints: plan.historyTemplate.fingerprints,
            importSession: plan.historyTemplate.importSession, completedAtISO: plan.historyTemplate.completedAtISO,
            successfulAttempt: attempt, normalizedDocument: plan.historyTemplate.normalizedDocument,
            normalizedRows: plan.historyTemplate.normalizedRows
        )
        return ConfirmedImportPlanDTO(
            providerGeneration: plan.providerGeneration, workspace: plan.workspace, proposedAccount: plan.proposedAccount,
            accountChoice: plan.accountChoice, advisoryIdentity: plan.advisoryIdentity, identifiers: plan.identifiers,
            historyTemplate: history, transactionTemplates: plan.transactionTemplates.filter { newIDs.contains($0.transaction.id) },
            declaredStatementStartISO: plan.declaredStatementStartISO, declaredStatementEndISO: plan.declaredStatementEndISO,
            openingBalanceMinor: plan.openingBalanceMinor, openingBalanceDecimal: plan.openingBalanceDecimal,
            closingBalanceMinor: plan.closingBalanceMinor, closingBalanceDecimal: plan.closingBalanceDecimal,
            statementFinancialProjection: plan.statementFinancialProjection,
            cbqSourceIdentityPatterns: plan.cbqSourceIdentityPatterns, cbqSourceRows: plan.cbqSourceRows,
            cbqStatementSourceEvidence: plan.cbqStatementSourceEvidence
        )
    }

    private func expectedCBQSourceFormat(_ plan: ConfirmedImportPlanDTO) -> String? {
        switch plan.historyTemplate.normalizedDocument?.profileId {
        case "cbq.current-account.xls": return "history-xls"
        case "cbq.current-account.history.pdf": return "history-pdf"
        case "cbq.current-account.monthly.pdf": return "monthly-pdf"
        default: return nil
        }
    }

    private func isCBQObservationPlan(_ plan: ConfirmedImportPlanDTO) -> Bool {
        expectedCBQSourceFormat(plan) != nil && !plan.cbqSourceRows.isEmpty && plan.cbqStatementSourceEvidence != nil
    }

    private func compatibleCBQAccountIDs(_ plan: ConfirmedImportPlanDTO) -> [String] {
        state.accounts.values.filter {
            $0.workspaceId == plan.workspace.id && $0.institutionId == "Commercial Bank of Qatar" &&
            $0.accountType == "bank" && $0.nativeCurrency == "QAR" && cbqAccountIsCompatible(plan, accountID: $0.id)
        }.map(\.id).sorted()
    }

    private func cbqAccountIsCompatible(_ plan: ConfirmedImportPlanDTO, accountID: String) -> Bool {
        let fullIncoming = plan.identifiers.first { $0.scheme == "institution_account_id" && $0.normalizedValue.count == 13 }?.normalizedValue
        let strong = state.accountIdentifiers.values.filter {
            $0.accountId == accountID && $0.workspaceId == plan.workspace.id &&
            $0.scheme == "institution_account_id" && $0.identifier.count == 13
        }.map(\.identifier)
        let durableMasks = state.cbqSourceIdentityRecords.values.filter { $0.accountId == accountID }
        if !plan.cbqSourceIdentityPatterns.isEmpty {
            let fullMatch = strong.contains { candidate in plan.cbqSourceIdentityPatterns.allSatisfy { Self.mask($0.pattern, matches: candidate) } }
            let maskMatch = plan.cbqSourceIdentityPatterns.allSatisfy { incoming in
                durableMasks.filter { $0.kind == incoming.kind }.contains { Self.masksCompatible(incoming.pattern, $0.pattern) }
            }
            return fullMatch || maskMatch
        }
        if let fullIncoming {
            return strong.contains(fullIncoming) || (!durableMasks.isEmpty && durableMasks.allSatisfy { Self.mask($0.pattern, matches: fullIncoming) })
        }
        return false
    }

    private static func mask(_ pattern: String, matches full: String) -> Bool {
        let compared = pattern.count == 29 ? String(pattern.suffix(13)) : pattern
        return compared.count == 13 && full.count == 13 && zip(compared, full).allSatisfy { $0 == "X" || $0 == $1 }
    }

    private static func masksCompatible(_ lhs: String, _ rhs: String) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0 == "X" || $1 == "X" || $0 == $1 }
    }

    private func reviewStatementEquivalenceWithoutLock(
        _ plan: ConfirmedImportPlanDTO,
        resolvedAccountID: String? = nil
    ) -> StatementEquivalenceReviewResult {
        guard let projection = plan.statementFinancialProjection else {
            return .notApplicable
        }
        guard projection.isValid(),
              let normalized = plan.historyTemplate.normalizedDocument,
              normalized.profileId == projection.parserProfileID,
              normalized.profileVersion == projection.parserProfileVersion,
              plan.historyTemplate.normalizedRows.count == projection.eventCount,
              plan.transactionTemplates.count == projection.eventCount,
              plan.declaredStatementStartISO == projection.statementStartDateISO,
              plan.declaredStatementEndISO == projection.statementEndDateISO,
              plan.proposedAccount.nativeCurrency == projection.nativeCurrency else {
            return .evidenceUnavailable
        }

        let accountID: String?
        if let resolvedAccountID {
            accountID = resolvedAccountID
        } else if case .useExistingAccount(let existingAccountID) = plan.accountChoice {
            accountID = existingAccountID
        } else {
            accountID = nil
        }
        guard let accountID else { return .firstAcceptedSource }

        if let group = matchingEquivalenceGroup(
            projection,
            workspaceID: plan.workspace.id,
            accountID: accountID,
            groups: state.statementEquivalenceGroups
        ) {
            if state.statementEquivalenceMembers.values.contains(where: {
                $0.groupID == group.id && $0.sourceFormatCode == projection.sourceFormatCode
            }) {
                return .formatAlreadyRecorded
            }
            guard group.projectionAlgorithm == projection.algorithmIdentifier,
                  group.projectionDigest == projection.digest,
                  let authoritative = state.statementFinancialProjections[group.authoritativeProjectionID],
                  financiallyEquivalent(authoritative.projection, projection) else {
                return .conflict
            }
            return .equivalent(authoritativeImportSessionID: authoritative.importSessionID)
        }

        if hasPreV10ExactEventOverlap(projection, accountID: accountID) {
            return .evidenceUnavailable
        }
        return .firstAcceptedSource
    }

    private func matchingEquivalenceGroup(
        _ projection: StatementFinancialProjectionDTO,
        workspaceID: String,
        accountID: String,
        groups: [String: StatementEquivalenceGroupDTO]
    ) -> StatementEquivalenceGroupDTO? {
        groups.values.first {
            $0.workspaceID == workspaceID &&
            $0.accountID == accountID &&
            $0.institutionCode == projection.institutionCode &&
            $0.statementFamilyCode == projection.statementFamilyCode &&
            $0.statementStartDateISO == projection.statementStartDateISO &&
            $0.statementEndDateISO == projection.statementEndDateISO &&
            $0.nativeCurrency == projection.nativeCurrency
        }
    }

    private func financiallyEquivalent(
        _ lhs: StatementFinancialProjectionDTO,
        _ rhs: StatementFinancialProjectionDTO
    ) -> Bool {
        lhs.algorithmIdentifier == rhs.algorithmIdentifier &&
        lhs.digest == rhs.digest &&
        lhs.institutionCode == rhs.institutionCode &&
        lhs.statementFamilyCode == rhs.statementFamilyCode &&
        lhs.statementStartDateISO == rhs.statementStartDateISO &&
        lhs.statementEndDateISO == rhs.statementEndDateISO &&
        lhs.nativeCurrency == rhs.nativeCurrency &&
        lhs.eventCount == rhs.eventCount &&
        lhs.openingBalanceMinor == rhs.openingBalanceMinor &&
        lhs.openingBalanceDecimal == rhs.openingBalanceDecimal &&
        lhs.debitCount == rhs.debitCount &&
        lhs.creditCount == rhs.creditCount &&
        lhs.debitTotalMinor == rhs.debitTotalMinor &&
        lhs.debitTotalDecimal == rhs.debitTotalDecimal &&
        lhs.creditTotalMinor == rhs.creditTotalMinor &&
        lhs.creditTotalDecimal == rhs.creditTotalDecimal &&
        lhs.closingBalanceMinor == rhs.closingBalanceMinor &&
        lhs.closingBalanceDecimal == rhs.closingBalanceDecimal &&
        zip(lhs.events, rhs.events).allSatisfy { left, right in
            left.ordinal == right.ordinal &&
            left.statementDateISO == right.statementDateISO &&
            left.valueDateISO == right.valueDateISO &&
            left.direction == right.direction &&
            left.signedAmountMinor == right.signedAmountMinor &&
            left.signedAmountDecimal == right.signedAmountDecimal &&
            left.runningBalanceMinor == right.runningBalanceMinor &&
            left.runningBalanceDecimal == right.runningBalanceDecimal &&
            left.reference == right.reference
        }
    }

    private func hasPreV10ExactEventOverlap(
        _ projection: StatementFinancialProjectionDTO,
        accountID: String
    ) -> Bool {
        let projectedSessionIDs = Set(state.statementFinancialProjections.values.map(\.importSessionID))
        let hdfcSessionIDs = Set(state.normalizedDocuments.values.filter {
            $0.profileId == "hdfc.bank-account.xls" || $0.profileId == "hdfc.bank-account.pdf"
        }.map(\.importSessionId))
        let candidateSessionIDs: Set<String> = Set(state.transactions.values.compactMap { transaction -> String? in
            guard transaction.accountId == accountID,
                  let sessionID = transaction.importSessionId,
                  hdfcSessionIDs.contains(sessionID),
                  !projectedSessionIDs.contains(sessionID) else { return nil }
            return sessionID
        })
        for sessionID in candidateSessionIDs {
            let transactions = state.transactions.values
                .filter { $0.accountId == accountID && $0.importSessionId == sessionID }
                .sorted {
                    ($0.rawRows.first?.sourceOrdinal ?? Int.max) <
                    ($1.rawRows.first?.sourceOrdinal ?? Int.max)
                }
            guard transactions.count == projection.events.count else { continue }
            var allEventsMatch = true
            for (transaction, event) in zip(transactions, projection.events) {
                let matches = transaction.postedDateISO == event.statementDateISO &&
                    transaction.valueDateISO == event.valueDateISO &&
                    transaction.direction == event.direction &&
                    transaction.amountMinor == event.signedAmountMinor &&
                    transaction.amountDecimal == event.signedAmountDecimal &&
                    transaction.runningBalanceMinor == event.runningBalanceMinor &&
                    transaction.reference == event.reference
                if !matches {
                    allEventsMatch = false
                    break
                }
            }
            if allEventsMatch {
                return true
            }
        }
        return false
    }

    private func reviewPartialImportWithoutLock(
        _ plan: ConfirmedImportPlanDTO,
        planID: String
    ) -> PartialImportReviewResult {
        guard case .useExistingAccount(let accountID) = plan.accountChoice else {
            return .unsupportedEvidence
        }
        var owners: [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] = [:]
        var transactions: [String: TransactionDTO] = [:]
        for template in plan.transactionTemplates {
            guard let evidence = template.eventEvidence,
                  let identity = try? TransactionEventIdentity.make(
                    transactionID: template.transaction.id,
                    evidence: evidence,
                    accountID: accountID
                  ) else { continue }
            let key = TransactionEventIdentityKeyDTO(
                algorithm: identity.algorithmIdentifier,
                digest: identity.digest
            )
            if let event = state.transactionEventIdentities.values.first(where: {
                $0.algorithm == key.algorithm && $0.digest == key.digest
            }) {
                owners[key] = TransactionEventIdentityOwnerDTO(
                    eventIdentityId: event.id,
                    accountId: event.accountId,
                    transactionId: event.transactionId,
                    documentId: event.documentId,
                    importSessionId: event.importSessionId
                )
                if let transaction = state.transactions[event.transactionId] {
                    transactions[transaction.id] = transaction
                }
            }
        }
        return ReviewedPartialImportPlanner.review(
            plan,
            account: state.accounts[accountID],
            owners: owners,
            transactionsByID: transactions,
            planID: planID
        )
    }

    private func validateExistingIdentityWithoutLock(
        _ plan: ConfirmedImportPlanDTO,
        accountID: String
    ) -> Bool {
        guard state.accounts[accountID]?.workspaceId == plan.workspace.id else {
            return false
        }
        for candidate in plan.identifiers {
            if state.accountIdentifiers.values.contains(where: {
                $0.workspaceId == plan.workspace.id &&
                $0.scheme == candidate.scheme &&
                $0.identifier == candidate.normalizedValue &&
                $0.accountId != accountID
            }) {
                return false
            }
        }
        switch plan.advisoryIdentity {
        case .resolved(let expected): return expected == accountID
        case .noMatch: return true
        case .ambiguous, .conflict: return false
        }
    }

    private func withFinalRelationships(_ template: TransactionDTO, accountID: String, importSessionID: String, documentID: String) -> TransactionDTO {
        TransactionDTO(id: template.id, workspaceId: template.workspaceId, accountId: accountID, importSessionId: importSessionID, documentId: documentID, originalRowId: template.originalRowId, postedDateISO: template.postedDateISO, financialDateRole: template.financialDateRole, statementTimezoneEvidence: template.statementTimezoneEvidence, valueDateISO: template.valueDateISO, description: template.description, payee: template.payee, reference: template.reference, nativeCurrency: template.nativeCurrency, amountMinor: template.amountMinor, amountDecimal: template.amountDecimal, direction: template.direction, runningBalanceMinor: template.runningBalanceMinor, isReconciled: template.isReconciled, isTrusted: template.isTrusted, trustedAtISO: template.trustedAtISO, createdAtISO: template.createdAtISO, updatedAtISO: template.updatedAtISO, rawRows: template.rawRows)
    }

    private func replacingRawRows(
        _ transaction: TransactionDTO,
        rawRows: [TransactionRawRowDTO]
    ) -> TransactionDTO {
        TransactionDTO(id: transaction.id, workspaceId: transaction.workspaceId, accountId: transaction.accountId, importSessionId: transaction.importSessionId, documentId: transaction.documentId, originalRowId: transaction.originalRowId, postedDateISO: transaction.postedDateISO, financialDateRole: transaction.financialDateRole, statementTimezoneEvidence: transaction.statementTimezoneEvidence, valueDateISO: transaction.valueDateISO, description: transaction.description, payee: transaction.payee, reference: transaction.reference, nativeCurrency: transaction.nativeCurrency, amountMinor: transaction.amountMinor, amountDecimal: transaction.amountDecimal, direction: transaction.direction, runningBalanceMinor: transaction.runningBalanceMinor, isReconciled: transaction.isReconciled, isTrusted: transaction.isTrusted, trustedAtISO: transaction.trustedAtISO, createdAtISO: transaction.createdAtISO, updatedAtISO: transaction.updatedAtISO, rawRows: rawRows)
    }

    private func hasValidTrustedProvenance(_ plan: ConfirmedImportPlanDTO) -> Bool {
        guard let document = plan.historyTemplate.normalizedDocument,
              !document.profileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !document.profileVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        let rows = plan.historyTemplate.normalizedRows
        guard Set(rows.map(\.id)).count == rows.count,
              rows.allSatisfy({
                  !$0.id.isEmpty &&
                  $0.normalizedDocumentId == document.id &&
                  $0.sourceOrdinal > 0 &&
                  !$0.digest.isEmpty
              }) else {
            return false
        }
        let knownRowIDs = Set(rows.map(\.id))
        return plan.transactionTemplates.allSatisfy { template in
            let rawRows = template.transaction.rawRows
            return !rawRows.isEmpty &&
                Set(rawRows.map(\.normalizedRowId)).count == rawRows.count &&
                rawRows.allSatisfy { !$0.id.isEmpty && !$0.normalizedRowId.isEmpty && knownRowIDs.contains($0.normalizedRowId) }
        }
    }

    private func hasDuplicateIdentifierCandidates(_ candidates: [ConfirmedImportIdentifierCandidateDTO]) -> Bool {
        for index in candidates.indices {
            for laterIndex in candidates.indices where laterIndex > index {
                if candidates[index].scheme == candidates[laterIndex].scheme,
                   candidates[index].normalizedValue == candidates[laterIndex].normalizedValue {
                    return true
                }
            }
        }
        return false
    }
}

private final class InMemoryTransactionRepo: TransactionRepository {
    private let state: InMemoryRepositoryState

    init(state: InMemoryRepositoryState) {
        self.state = state
    }

    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [TransactionDTO]) throws {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard !transactions.contains(where: \.isTrusted) else {
            throw RepositoryError.trustedTransactionWriteForbidden
        }
        try validate(workspaceId: workspaceId, importSessionId: importSessionId, transactions: transactions)

        if let importSessionId {
            let existingCandidateIds = state.transactions.values
                .filter { $0.importSessionId == importSessionId && !$0.isTrusted }
                .map(\.id)
            for id in existingCandidateIds {
                state.transactions.removeValue(forKey: id)
            }
        }

        for transaction in transactions {
            state.transactions[transaction.id] = transaction
        }
    }

    func transactions(workspaceId: String, importSessionId: String?) throws -> [TransactionDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return try state.transactions.values
            .filter { transaction in
                transaction.workspaceId == workspaceId && (importSessionId == nil || transaction.importSessionId == importSessionId)
            }
            .map(enrichProvenance)
            .sorted(by: Self.sourceSupportedOrder)
    }

    func trustedTransactions(workspaceId: String) throws -> [TransactionDTO] {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return try state.transactions.values
            .filter { $0.workspaceId == workspaceId && $0.isTrusted }
            .map(enrichProvenance)
            .sorted(by: Self.sourceSupportedOrder)
    }

    private func enrichProvenance(_ transaction: TransactionDTO) throws -> TransactionDTO {
        let rawRows = transaction.rawRows.map { raw -> TransactionRawRowDTO in
            guard let row = state.normalizedRows[raw.normalizedRowId],
                  let document = state.normalizedDocuments[row.normalizedDocumentId] else {
                // Match SQLite's joined read boundary: an orphan must arrive as
                // incomplete evidence so the hydrator fails closed with its typed
                // hydration error before changing runtime stores.
                return TransactionRawRowDTO(
                    id: raw.id,
                    normalizedRowId: raw.normalizedRowId,
                    contributionType: raw.contributionType,
                    sourceOrdinal: raw.sourceOrdinal,
                    normalizedRecordDigest: raw.normalizedRecordDigest,
                    normalizedDocumentId: nil,
                    parserProfileId: nil,
                    parserProfileVersion: nil
                )
            }
            return TransactionRawRowDTO(id: raw.id, normalizedRowId: raw.normalizedRowId, contributionType: raw.contributionType, sourceOrdinal: row.sourceOrdinal, normalizedRecordDigest: row.digest, normalizedDocumentId: row.normalizedDocumentId, parserProfileId: document.profileId, parserProfileVersion: document.profileVersion)
        }
        return TransactionDTO(id: transaction.id, workspaceId: transaction.workspaceId, accountId: transaction.accountId, importSessionId: transaction.importSessionId, documentId: transaction.documentId, originalRowId: transaction.originalRowId, postedDateISO: transaction.postedDateISO, financialDateRole: transaction.financialDateRole, statementTimezoneEvidence: transaction.statementTimezoneEvidence, valueDateISO: transaction.valueDateISO, description: transaction.description, payee: transaction.payee, reference: transaction.reference, nativeCurrency: transaction.nativeCurrency, amountMinor: transaction.amountMinor, amountDecimal: transaction.amountDecimal, direction: transaction.direction, runningBalanceMinor: transaction.runningBalanceMinor, isReconciled: transaction.isReconciled, isTrusted: transaction.isTrusted, trustedAtISO: transaction.trustedAtISO, createdAtISO: transaction.createdAtISO, updatedAtISO: transaction.updatedAtISO, rawRows: rawRows)
    }

    nonisolated private static func sourceSupportedOrder(_ lhs: TransactionDTO, _ rhs: TransactionDTO) -> Bool {
        if lhs.postedDateISO != rhs.postedDateISO { return lhs.postedDateISO < rhs.postedDateISO }
        let lhsSource = lhs.rawRows.first
        let rhsSource = rhs.rawRows.first
        if lhsSource?.normalizedDocumentId == rhsSource?.normalizedDocumentId,
           let lhsOrdinal = lhsSource?.sourceOrdinal,
           let rhsOrdinal = rhsSource?.sourceOrdinal,
           lhsOrdinal != rhsOrdinal {
            return lhsOrdinal < rhsOrdinal
        }
        if lhsSource?.normalizedDocumentId != rhsSource?.normalizedDocumentId {
            return (lhsSource?.normalizedDocumentId ?? "~") < (rhsSource?.normalizedDocumentId ?? "~")
        }
        return lhs.id < rhs.id
    }

    private func validate(workspaceId: String, importSessionId: String?, transactions: [TransactionDTO]) throws {
        guard state.workspaces[workspaceId] != nil else {
            throw RepositoryError.relationshipViolation("Workspace \(workspaceId) does not exist.")
        }

        if let importSessionId, state.importSessions[importSessionId] == nil {
            throw RepositoryError.relationshipViolation("Import session \(importSessionId) does not exist.")
        }

        for transaction in transactions {
            guard transaction.workspaceId == workspaceId else {
                throw RepositoryError.relationshipViolation("Transaction \(transaction.id) belongs to workspace \(transaction.workspaceId), not \(workspaceId).")
            }

            if let accountId = transaction.accountId, state.accounts[accountId] == nil {
                throw RepositoryError.relationshipViolation("Account \(accountId) does not exist for transaction \(transaction.id).")
            }

            if let transactionImportSessionId = transaction.importSessionId,
               state.importSessions[transactionImportSessionId] == nil {
                throw RepositoryError.relationshipViolation("Import session \(transactionImportSessionId) does not exist for transaction \(transaction.id).")
            }
        }
    }
}
