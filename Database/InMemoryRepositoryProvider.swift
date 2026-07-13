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
    var workspaces: [String: WorkspaceDTO] = [:]
    var accounts: [String: AccountDTO] = [:]
    var accountIdentifiers: [String: AccountIdentifierDTO] = [:]
    var importSessions: [String: ImportSessionRecordDTO] = [:]
    var transactions: [String: TransactionDTO] = [:]
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
