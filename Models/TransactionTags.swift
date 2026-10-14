import Foundation

/// Owner-created context only. A tag has no category or financial meaning.
nonisolated public struct TransactionTagDefinition: Identifiable, Equatable, Sendable {
    public let id: String
    public let workspaceID: String
    public let name: String

    public init(id: String = UUID().uuidString, workspaceID: String, name: String) {
        self.id = id
        self.workspaceID = workspaceID
        self.name = name
    }

    func canonicalized() throws -> Self {
        try TransactionTagValidation.validateIdentity(id)
        try TransactionTagValidation.validateIdentity(workspaceID)
        return Self(id: id, workspaceID: workspaceID, name: try TransactionTagName.validated(name))
    }
}

nonisolated public struct TransactionTagMembership: Hashable, Sendable {
    public let workspaceID: String
    public let transactionID: String
    public let tagID: String

    public init(workspaceID: String, transactionID: String, tagID: String) {
        self.workspaceID = workspaceID
        self.transactionID = transactionID
        self.tagID = tagID
    }
}

nonisolated enum TransactionTagFilter: Hashable, Sendable {
    case all
    case untagged
    case tag(String)
}

nonisolated public struct TransactionTagSnapshot: Equatable, Sendable {
    public let workspaceID: String
    public let definitions: [TransactionTagDefinition]
    public let memberships: Set<TransactionTagMembership>
    private let tagIDsByTransaction: [String: Set<String>]
    private let transactionIDsByTag: [String: Set<String>]

    public init(workspaceID: String, definitions: [TransactionTagDefinition], memberships: Set<TransactionTagMembership>) {
        self.workspaceID = workspaceID
        self.definitions = definitions
        self.memberships = memberships
        var byTransaction: [String: Set<String>] = [:]
        var byTag: [String: Set<String>] = [:]
        for membership in memberships {
            byTransaction[membership.transactionID, default: []].insert(membership.tagID)
            byTag[membership.tagID, default: []].insert(membership.transactionID)
        }
        self.tagIDsByTransaction = byTransaction
        self.transactionIDsByTag = byTag
    }

    public static func empty(workspaceID: String) -> Self {
        Self(workspaceID: workspaceID, definitions: [], memberships: [])
    }

    public func transactionIDs(tagID: String) -> Set<String> {
        transactionIDsByTag[tagID] ?? []
    }

    public func tagIDs(transactionID: String) -> Set<String> {
        tagIDsByTransaction[transactionID] ?? []
    }

    public func tags(transactionID: String) -> [TransactionTagDefinition] {
        let ids = tagIDs(transactionID: transactionID)
        return definitions.filter { ids.contains($0.id) }
    }

    func matches(transactionID: String?, filter: TransactionTagFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .untagged:
            guard let transactionID else { return false }
            return tagIDsByTransaction[transactionID]?.isEmpty ?? true
        case .tag(let tagID):
            guard let transactionID else { return false }
            return memberships.contains(.init(workspaceID: workspaceID, transactionID: transactionID, tagID: tagID))
        }
    }
}

nonisolated public enum TransactionTagError: Error, Equatable, LocalizedError {
    case unavailable
    case invalidName
    case invalidIdentity
    case invalidState
    case workspaceMismatch
    case transactionNotFound
    case staleReview
    case emptySelection
    case refreshRequired
    case savedButRefreshFailed
    case saveFailed

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Tags are unavailable for the active ledger."
        case .invalidName:
            return "Enter a tag name with at least one visible character."
        case .invalidIdentity, .invalidState:
            return "The saved tags could not be read consistently. Refresh the ledger before continuing."
        case .workspaceMismatch:
            return "The tag and selected transactions must belong to the active workspace."
        case .transactionNotFound:
            return "A selected imported transaction is no longer available. Reopen Tags from your selection."
        case .staleReview:
            return "The tag or selection changed. Review the current tags and try again."
        case .emptySelection:
            return "Select at least one imported transaction to change its tags."
        case .refreshRequired:
            return "Refresh the ledger before making another tag change."
        case .savedButRefreshFailed:
            return "The tag change was saved, but the app could not refresh. Retry refresh before making another change."
        case .saveFailed:
            return "The tag change could not be saved."
        }
    }
}

nonisolated enum TransactionTagName {
    static func validated(_ value: String) throws -> String {
        let display = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // SQLite text binding is NUL-terminated. Reject a value it cannot retain
        // exactly instead of silently publishing a truncated owner name.
        guard !display.isEmpty, !display.contains("\0") else { throw TransactionTagError.invalidName }
        return display
    }
}

nonisolated enum TransactionTagValidation {
    static func validateIdentity(_ value: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !value.contains("\0") else { throw TransactionTagError.invalidIdentity }
    }

    /// Structural checks only. Repositories separately verify actual trusted
    /// transaction and workspace parents before publishing this snapshot.
    static func validate(_ snapshot: TransactionTagSnapshot) throws {
        try validateIdentity(snapshot.workspaceID)
        var tagIDs = Set<String>()
        for tag in snapshot.definitions {
            guard try tag.canonicalized() == tag,
                  tag.workspaceID == snapshot.workspaceID,
                  tagIDs.insert(tag.id).inserted else { throw TransactionTagError.invalidState }
        }
        for membership in snapshot.memberships {
            try validateIdentity(membership.transactionID)
            guard membership.workspaceID == snapshot.workspaceID,
                  tagIDs.contains(membership.tagID) else { throw TransactionTagError.invalidState }
        }
    }

    static func definitionOrder(_ lhs: TransactionTagDefinition, _ rhs: TransactionTagDefinition) -> Bool {
        let order = lhs.name.compare(rhs.name, options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        if order != .orderedSame { return order == .orderedAscending }
        if lhs.name != rhs.name { return lhs.name < rhs.name }
        return lhs.id < rhs.id
    }

    static func validateSelection(_ transactionIDs: Set<String>, expected: Set<String>) throws {
        guard !transactionIDs.isEmpty else { throw TransactionTagError.emptySelection }
        guard expected.isSubset(of: transactionIDs) else { throw TransactionTagError.staleReview }
        for id in transactionIDs { try validateIdentity(id) }
    }
}
