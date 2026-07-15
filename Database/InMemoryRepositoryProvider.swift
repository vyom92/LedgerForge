// Database/InMemoryRepositoryProvider.swift
// In-memory repository provider for contract tests and isolated development fixtures

import Foundation

public final class InMemoryRepositoryProvider {
    public let workspaceRepo: WorkspaceRepository
    public let transactionRepo: TransactionRepository
    public let accountRepo: AccountRepository
    public let importSessionRepo: ImportSessionRepository

    private let state = InMemoryRepositoryState()

    public init() {
        self.workspaceRepo = InMemoryWorkspaceRepo(state: state)
        self.transactionRepo = InMemoryTransactionRepo(state: state)
        self.accountRepo = InMemoryAccountRepo(state: state)
        self.importSessionRepo = InMemoryImportSessionRepo(state: state)
    }
}

private final class InMemoryRepositoryState {
    let importHistoryLock = NSLock()
    var workspaces: [String: WorkspaceDTO] = [:]
    var accounts: [String: AccountDTO] = [:]
    var accountIdentifiers: [String: AccountIdentifierDTO] = [:]
    var documents: [String: ImportedDocumentDTO] = [:]
    var documentFingerprints: [String: DocumentFingerprintDTO] = [:]
    var importSessions: [String: ImportSessionRecordDTO] = [:]
    var transactions: [String: TransactionDTO] = [:]
    var transactionEventIdentities: [String: TransactionEventIdentityDTO] = [:]
    var importAttempts: [String: ImportAttemptDTO] = [:]
}

private final class InMemoryWorkspaceRepo: WorkspaceRepository {
    private let state: InMemoryRepositoryState

    init(state: InMemoryRepositoryState) {
        self.state = state
    }

    func upsertWorkspace(_ workspace: WorkspaceDTO) throws -> String {
        state.workspaces[workspace.id] = workspace
        return workspace.id
    }

    func workspace(id: String) throws -> WorkspaceDTO? {
        state.workspaces[id]
    }
}

private final class InMemoryAccountRepo: AccountRepository {
    private let state: InMemoryRepositoryState

    init(state: InMemoryRepositoryState) {
        self.state = state
    }

    func upsertAccount(_ account: AccountDTO) throws -> String {
        guard state.workspaces[account.workspaceId] != nil else {
            throw RepositoryError.relationshipViolation("Workspace \(account.workspaceId) does not exist for account \(account.id).")
        }
        state.accounts[account.id] = account
        return account.id
    }

    func updateAccountDisplayName(accountId: String, workspaceId: String, displayName: String) throws -> Bool {
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
        state.accounts[id]
    }

    func accounts(workspaceId: String) throws -> [AccountDTO] {
        state.accounts.values
            .filter { $0.workspaceId == workspaceId }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.id < rhs.id
                }
                return lhs.name < rhs.name
            }
    }

    func attachIdentifier(_ identifier: AccountIdentifierDTO) throws -> String {
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
        state.accountIdentifiers.values
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
        matchingIdentifiers(workspaceId: workspaceId, scheme: scheme, identifier: identifier)
            .map(\.accountId)
            .sorted()
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
        state.importSessions[id]
    }

    func priorImportedStatement(algorithm: String, fingerprint: String) throws -> PriorImportedStatementDTO? {
        state.importHistoryLock.lock()
        defer { state.importHistoryLock.unlock() }
        return priorImportedStatementWithoutLock(algorithm: algorithm, fingerprint: fingerprint)
    }

    func transactionEventOwners(keys: Set<TransactionEventIdentityKeyDTO>) throws -> [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] {
        state.importHistoryLock.lock(); defer { state.importHistoryLock.unlock() }
        var result: [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] = [:]
        for event in state.transactionEventIdentities.values {
            let key = TransactionEventIdentityKeyDTO(algorithm: event.algorithm, digest: event.digest)
            if keys.contains(key) {
                result[key] = TransactionEventIdentityOwnerDTO(accountId: event.accountId, transactionId: event.transactionId, documentId: event.documentId, importSessionId: event.importSessionId)
            }
        }
        return result
    }

    func recordImportAttempt(_ payload: ImportAttemptDTO) throws -> String {
        state.importHistoryLock.lock(); defer { state.importHistoryLock.unlock() }
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
        state.importHistoryLock.lock(); defer { state.importHistoryLock.unlock() }
        return state.importAttempts.values.filter { $0.workspaceId == workspaceId }.sorted {
            if $0.createdAtISO == $1.createdAtISO { return $0.id > $1.id }
            return $0.createdAtISO > $1.createdAtISO
        }
    }

    func commitImportHistory(_ payload: AtomicImportHistoryDTO) throws -> AtomicImportHistoryResult {
        state.importHistoryLock.lock()
        defer { state.importHistoryLock.unlock() }

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
              payload.document.sha256 == payload.fingerprint.fingerprint,
              payload.fingerprint.fingerprintData == nil else {
            throw RepositoryError.relationshipViolation("Atomic import-history document relationships are inconsistent.")
        }
        guard state.documents[payload.document.id] == nil,
              state.documentFingerprints[payload.fingerprint.id] == nil,
              state.importSessions[payload.importSession.id] == nil else {
            throw RepositoryError.relationshipViolation("Atomic import-history identifiers already exist.")
        }
        guard !state.documents.values.contains(where: { $0.sha256 == payload.document.sha256 }),
              !state.documentFingerprints.values.contains(where: {
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
            $0.algorithm == algorithm && $0.fingerprint == fingerprint
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

private final class InMemoryTransactionRepo: TransactionRepository {
    private let state: InMemoryRepositoryState

    init(state: InMemoryRepositoryState) {
        self.state = state
    }

    func replaceTransactions(workspaceId: String, importSessionId: String?, transactions: [TransactionDTO]) throws {
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
        state.transactions.values
            .filter { transaction in
                transaction.workspaceId == workspaceId && (importSessionId == nil || transaction.importSessionId == importSessionId)
            }
            .sorted { lhs, rhs in
                if lhs.postedDateISO == rhs.postedDateISO {
                    return lhs.id < rhs.id
                }
                return lhs.postedDateISO < rhs.postedDateISO
            }
    }

    func trustedTransactions(workspaceId: String) throws -> [TransactionDTO] {
        try transactions(workspaceId: workspaceId, importSessionId: nil)
            .filter(\.isTrusted)
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
