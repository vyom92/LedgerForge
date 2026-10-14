import Foundation

public protocol TransactionTagRepository {
    /// Nil is only an explicitly unsupported historical capability. A current
    /// provider never disguises a failed or malformed read as an empty result.
    func snapshot(workspaceID: String) throws -> TransactionTagSnapshot?
    @discardableResult
    func saveTag(_ tag: TransactionTagDefinition, replacing expected: TransactionTagDefinition?) throws -> Bool
    @discardableResult
    func removeTag(_ tag: TransactionTagDefinition, expectedTransactionIDs: Set<String>) throws -> Bool
    @discardableResult
    func setMembership(tag: TransactionTagDefinition, transactionIDs: Set<String>, isAttached: Bool,
                       expectedAttachedTransactionIDs: Set<String>) throws -> Bool
}

struct UnavailableTransactionTagRepository: TransactionTagRepository {
    func snapshot(workspaceID: String) throws -> TransactionTagSnapshot? { nil }
    func saveTag(_ tag: TransactionTagDefinition, replacing expected: TransactionTagDefinition?) throws -> Bool {
        throw TransactionTagError.unavailable
    }
    func removeTag(_ tag: TransactionTagDefinition, expectedTransactionIDs: Set<String>) throws -> Bool {
        throw TransactionTagError.unavailable
    }
    func setMembership(tag: TransactionTagDefinition, transactionIDs: Set<String>, isAttached: Bool,
                       expectedAttachedTransactionIDs: Set<String>) throws -> Bool {
        throw TransactionTagError.unavailable
    }
}

final class SQLiteTransactionTagRepository: TransactionTagRepository {
    private let db: SQLiteDatabase
    private let supportsTags: Bool

    /// Capability comes from the provider's verified migration prefix, never a
    /// best-effort table probe. V34 is the first supported tag schema.
    init(db: SQLiteDatabase, supportsTags: Bool) {
        self.db = db
        self.supportsTags = supportsTags
    }

    func snapshot(workspaceID: String) throws -> TransactionTagSnapshot? {
        guard supportsTags else { return nil }
        return try Self.readSnapshot(db, workspaceID: workspaceID)
    }

    /// Backup verification has already established the exact V34 schema and
    /// migration chain. Inspect present metadata off the UI actor with the same
    /// validator as canonical hydration; an orphan workspace cannot hide rows.
    nonisolated static func verifyBackupContents(_ db: SQLiteDatabase) throws {
        try db.withExclusiveAccess {
            let workspaces = try db.query(sql: """
                SELECT workspace_id, instr(workspace_id, char(0)) FROM tag_definitions
                UNION SELECT workspace_id, instr(workspace_id, char(0)) FROM transaction_tag_memberships;
                """) { row -> String in
                guard let value = row.string(at: 0), row.int64(at: 1) == 0 else { throw TransactionTagError.invalidState }
                try TransactionTagValidation.validateIdentity(value)
                return value
            }
            for workspace in workspaces { _ = try readSnapshot(db, workspaceID: workspace) }
        }
    }

    nonisolated private static func readSnapshot(_ db: SQLiteDatabase, workspaceID: String) throws -> TransactionTagSnapshot {
        try TransactionTagValidation.validateIdentity(workspaceID)
        return try db.withExclusiveAccess {
            let definitions = try db.query(sql: """
                SELECT d.id, d.workspace_id, d.name, w.id,
                       instr(d.id, char(0)), instr(d.workspace_id, char(0)), instr(d.name, char(0))
                FROM tag_definitions d LEFT JOIN workspaces w ON w.id = d.workspace_id
                WHERE d.workspace_id = ? ORDER BY d.id;
                """, params: [workspaceID]) { row -> TransactionTagDefinition in
                guard let id = row.string(at: 0), let workspace = row.string(at: 1),
                      let name = row.string(at: 2), row.string(at: 3) == workspace,
                      row.int64(at: 4) == 0, row.int64(at: 5) == 0, row.int64(at: 6) == 0 else {
                    throw TransactionTagError.invalidState
                }
                return TransactionTagDefinition(id: id, workspaceID: workspace, name: name)
            }
            let rows = try db.query(sql: """
                SELECT m.workspace_id, m.transaction_id, m.tag_id,
                       t.workspace_id, t.is_trusted, d.workspace_id,
                       instr(m.workspace_id, char(0)), instr(m.transaction_id, char(0)), instr(m.tag_id, char(0))
                FROM transaction_tag_memberships m
                LEFT JOIN transactions t ON t.id = m.transaction_id AND t.workspace_id = m.workspace_id
                LEFT JOIN tag_definitions d ON d.id = m.tag_id AND d.workspace_id = m.workspace_id
                WHERE m.workspace_id = ? ORDER BY m.transaction_id, m.tag_id;
                """, params: [workspaceID]) { row -> TransactionTagMembership in
                guard row.string(at: 0) == workspaceID,
                      let transactionID = row.string(at: 1), let tagID = row.string(at: 2),
                      row.string(at: 3) == workspaceID, row.int64(at: 4) == 1,
                      row.string(at: 5) == workspaceID,
                      row.int64(at: 6) == 0, row.int64(at: 7) == 0, row.int64(at: 8) == 0 else {
                    throw TransactionTagError.invalidState
                }
                return TransactionTagMembership(workspaceID: workspaceID, transactionID: transactionID, tagID: tagID)
            }
            let memberships = Set(rows)
            guard memberships.count == rows.count else { throw TransactionTagError.invalidState }
            let result = TransactionTagSnapshot(workspaceID: workspaceID,
                definitions: definitions.sorted(by: TransactionTagValidation.definitionOrder), memberships: memberships)
            try TransactionTagValidation.validate(result)
            return result
        }
    }

    func saveTag(_ tag: TransactionTagDefinition, replacing expected: TransactionTagDefinition?) throws -> Bool {
        try transaction {
            let value = try tag.canonicalized()
            if let expected {
                guard try expected.canonicalized() == expected, expected.id == value.id,
                      expected.workspaceID == value.workspaceID else { throw TransactionTagError.staleReview }
            }
            try validateWorkspace(value.workspaceID)
            _ = try requiredSnapshot(workspaceID: value.workspaceID)
            let current = try definition(id: value.id)
            guard current == expected else { throw TransactionTagError.staleReview }
            guard current != value else { return false }
            if current == nil {
                try db.executePrepared(sql: "INSERT INTO tag_definitions(id, workspace_id, name) VALUES(?,?,?);",
                                       params: [value.id, value.workspaceID, value.name])
            } else {
                try db.executePrepared(sql: "UPDATE tag_definitions SET name = ? WHERE id = ? AND workspace_id = ?;",
                                       params: [value.name, value.id, value.workspaceID])
            }
            guard try definition(id: value.id) == value else { throw TransactionTagError.invalidState }
            _ = try requiredSnapshot(workspaceID: value.workspaceID)
            return true
        }
    }

    func removeTag(_ tag: TransactionTagDefinition, expectedTransactionIDs: Set<String>) throws -> Bool {
        try transaction {
            try validateCurrent(tag)
            let current = try requiredSnapshot(workspaceID: tag.workspaceID)
            guard current.transactionIDs(tagID: tag.id) == expectedTransactionIDs else {
                throw TransactionTagError.staleReview
            }
            guard try membershipCount(tagID: tag.id) == Int64(expectedTransactionIDs.count) else {
                throw TransactionTagError.invalidState
            }
            // The sole cascading effect is its membership junction. No
            // category, financial interpretation or source table is written.
            try db.executePrepared(sql: "DELETE FROM tag_definitions WHERE id = ? AND workspace_id = ?;",
                                   params: [tag.id, tag.workspaceID])
            guard try definition(id: tag.id) == nil,
                  try membershipCount(tagID: tag.id) == 0 else { throw TransactionTagError.invalidState }
            return true
        }
    }

    func setMembership(tag: TransactionTagDefinition, transactionIDs: Set<String>, isAttached: Bool,
                       expectedAttachedTransactionIDs: Set<String>) throws -> Bool {
        try transaction {
            try TransactionTagValidation.validateSelection(transactionIDs, expected: expectedAttachedTransactionIDs)
            try validateCurrent(tag)
            try validateTransactions(transactionIDs, workspaceID: tag.workspaceID)
            let current = try requiredSnapshot(workspaceID: tag.workspaceID)
            let attached = current.transactionIDs(tagID: tag.id).intersection(transactionIDs)
            guard attached == expectedAttachedTransactionIDs else { throw TransactionTagError.staleReview }
            let changedIDs = isAttached ? transactionIDs.subtracting(attached) : attached
            guard !changedIDs.isEmpty else { return false }
            for id in changedIDs.sorted() {
                if isAttached {
                    try db.executePrepared(sql: """
                        INSERT INTO transaction_tag_memberships(transaction_id, tag_id, workspace_id) VALUES(?,?,?);
                        """, params: [id, tag.id, tag.workspaceID])
                } else {
                    try db.executePrepared(sql: """
                        DELETE FROM transaction_tag_memberships WHERE transaction_id = ? AND tag_id = ? AND workspace_id = ?;
                        """, params: [id, tag.id, tag.workspaceID])
                }
            }
            let after = try requiredSnapshot(workspaceID: tag.workspaceID)
            var expectedMemberships = current.memberships
            for id in changedIDs {
                let membership = TransactionTagMembership(workspaceID: tag.workspaceID, transactionID: id, tagID: tag.id)
                if isAttached { expectedMemberships.insert(membership) }
                else { expectedMemberships.remove(membership) }
            }
            guard after.definitions == current.definitions, after.memberships == expectedMemberships else {
                throw TransactionTagError.invalidState
            }
            return true
        }
    }

    private func requiredSnapshot(workspaceID: String) throws -> TransactionTagSnapshot {
        guard let value = try snapshot(workspaceID: workspaceID) else { throw TransactionTagError.unavailable }
        return value
    }

    private func definition(id: String) throws -> TransactionTagDefinition? {
        let values = try db.query(sql: "SELECT workspace_id, name, instr(workspace_id, char(0)), instr(name, char(0)) FROM tag_definitions WHERE id = ?;", params: [id]) {
            row -> TransactionTagDefinition in
            guard let workspace = row.string(at: 0), let name = row.string(at: 1),
                  row.int64(at: 2) == 0, row.int64(at: 3) == 0 else {
                throw TransactionTagError.invalidState
            }
            let tag = TransactionTagDefinition(id: id, workspaceID: workspace, name: name)
            guard try tag.canonicalized() == tag else { throw TransactionTagError.invalidState }
            return tag
        }
        guard values.count <= 1 else { throw TransactionTagError.invalidState }
        return values.first
    }

    private func validateCurrent(_ tag: TransactionTagDefinition) throws {
        guard try tag.canonicalized() == tag else { throw TransactionTagError.invalidState }
        try validateWorkspace(tag.workspaceID)
        guard try definition(id: tag.id) == tag else { throw TransactionTagError.staleReview }
    }

    private func validateWorkspace(_ workspaceID: String) throws {
        try TransactionTagValidation.validateIdentity(workspaceID)
        guard try db.query(sql: "SELECT 1 FROM workspaces WHERE id = ?;", params: [workspaceID], map: { _ in true }).count == 1 else {
            throw TransactionTagError.workspaceMismatch
        }
    }

    private func validateTransactions(_ ids: Set<String>, workspaceID: String) throws {
        // Exact-ID batches stay comfortably below SQLite's bind limit and do
        // not read narration, amounts or any other private source payload.
        let ordered = ids.sorted()
        for start in stride(from: 0, to: ordered.count, by: 400) {
            let batch = Array(ordered[start..<min(start + 400, ordered.count)])
            let placeholders = Array(repeating: "?", count: batch.count).joined(separator: ",")
            let rows = try db.query(sql: "SELECT id, workspace_id, is_trusted FROM transactions WHERE id IN (\(placeholders));",
                                   params: batch.map { $0 as Any? }) { row -> (String, String, Bool) in
                guard let id = row.string(at: 0), let workspace = row.string(at: 1) else { throw TransactionTagError.invalidState }
                return (id, workspace, row.int64(at: 2) == 1)
            }
            guard rows.count == batch.count, Set(rows.map { $0.0 }) == Set(batch), rows.allSatisfy({ $0.2 }) else {
                throw TransactionTagError.transactionNotFound
            }
            guard rows.allSatisfy({ $0.1 == workspaceID }) else { throw TransactionTagError.workspaceMismatch }
        }
    }

    private func membershipCount(tagID: String) throws -> Int64 {
        try db.query(sql: "SELECT COUNT(*) FROM transaction_tag_memberships WHERE tag_id = ?;", params: [tagID]) { $0.int64(at: 0) ?? -1 }.first ?? -1
    }

    private func transaction<Result>(_ body: () throws -> Result) throws -> Result {
        guard supportsTags else { throw TransactionTagError.unavailable }
        return try db.withExclusiveAccess {
            try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
            do {
                let result = try body()
                try db.execute(sql: "COMMIT;")
                return result
            } catch {
                try? db.execute(sql: "ROLLBACK;")
                throw error
            }
        }
    }
}

final class InMemoryTransactionTagRepository: TransactionTagRepository {
    private let state: InMemoryRepositoryState
    init(state: InMemoryRepositoryState) { self.state = state }

    func snapshot(workspaceID: String) throws -> TransactionTagSnapshot? {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        return try validatedSnapshot(workspaceID: workspaceID, definitions: state.tagDefinitions, memberships: state.tagMemberships)
    }

    func saveTag(_ tag: TransactionTagDefinition, replacing expected: TransactionTagDefinition?) throws -> Bool {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        let value = try tag.canonicalized()
        if let expected {
            guard try expected.canonicalized() == expected, expected.id == value.id,
                  expected.workspaceID == value.workspaceID else { throw TransactionTagError.staleReview }
        }
        try validateWorkspace(value.workspaceID)
        _ = try validatedSnapshot(workspaceID: value.workspaceID, definitions: state.tagDefinitions, memberships: state.tagMemberships)
        let current = state.tagDefinitions[value.id]
        if let current, try current.canonicalized() != current { throw TransactionTagError.invalidState }
        guard current == expected else { throw TransactionTagError.staleReview }
        guard current != value else { return false }
        var definitions = state.tagDefinitions
        definitions[value.id] = value
        _ = try validatedSnapshot(workspaceID: value.workspaceID, definitions: definitions, memberships: state.tagMemberships)
        state.tagDefinitions = definitions
        return true
    }

    func removeTag(_ tag: TransactionTagDefinition, expectedTransactionIDs: Set<String>) throws -> Bool {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        try validateCurrent(tag)
        let current = try validatedSnapshot(workspaceID: tag.workspaceID, definitions: state.tagDefinitions, memberships: state.tagMemberships)
        guard current.transactionIDs(tagID: tag.id) == expectedTransactionIDs else { throw TransactionTagError.staleReview }
        guard state.tagMemberships.filter({ $0.tagID == tag.id }).count == expectedTransactionIDs.count else {
            throw TransactionTagError.invalidState
        }
        var definitions = state.tagDefinitions
        definitions.removeValue(forKey: tag.id)
        let memberships = state.tagMemberships.filter { $0.tagID != tag.id }
        _ = try validatedSnapshot(workspaceID: tag.workspaceID, definitions: definitions, memberships: memberships)
        state.tagDefinitions = definitions
        state.tagMemberships = memberships
        return true
    }

    func setMembership(tag: TransactionTagDefinition, transactionIDs: Set<String>, isAttached: Bool,
                       expectedAttachedTransactionIDs: Set<String>) throws -> Bool {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        try TransactionTagValidation.validateSelection(transactionIDs, expected: expectedAttachedTransactionIDs)
        try validateCurrent(tag)
        try validateTransactions(transactionIDs, workspaceID: tag.workspaceID)
        let current = try validatedSnapshot(workspaceID: tag.workspaceID, definitions: state.tagDefinitions, memberships: state.tagMemberships)
        let attached = current.transactionIDs(tagID: tag.id).intersection(transactionIDs)
        guard attached == expectedAttachedTransactionIDs else { throw TransactionTagError.staleReview }
        let changedIDs = isAttached ? transactionIDs.subtracting(attached) : attached
        guard !changedIDs.isEmpty else { return false }
        var memberships = state.tagMemberships
        for id in changedIDs {
            let membership = TransactionTagMembership(workspaceID: tag.workspaceID, transactionID: id, tagID: tag.id)
            if isAttached { memberships.insert(membership) }
            else { memberships.remove(membership) }
        }
        _ = try validatedSnapshot(workspaceID: tag.workspaceID, definitions: state.tagDefinitions, memberships: memberships)
        // Publish only after every selected parent, exact expected value and
        // resulting junction has validated. A failed batch changes no member.
        state.tagMemberships = memberships
        return true
    }

    private func validatedSnapshot(workspaceID: String, definitions: [String: TransactionTagDefinition],
                                   memberships: Set<TransactionTagMembership>) throws -> TransactionTagSnapshot {
        let selected = definitions.values.filter { $0.workspaceID == workspaceID }
        for tag in selected {
            guard definitions[tag.id] == tag else { throw TransactionTagError.invalidState }
        }
        let result = TransactionTagSnapshot(workspaceID: workspaceID,
            definitions: selected.sorted(by: TransactionTagValidation.definitionOrder),
            memberships: memberships.filter { $0.workspaceID == workspaceID })
        try TransactionTagValidation.validate(result)
        do {
            if !result.definitions.isEmpty || !result.memberships.isEmpty { try validateWorkspace(workspaceID) }
            try validateTransactions(Set(result.memberships.map(\.transactionID)), workspaceID: workspaceID)
        } catch {
            throw TransactionTagError.invalidState
        }
        return result
    }

    private func validateCurrent(_ tag: TransactionTagDefinition) throws {
        guard try tag.canonicalized() == tag else { throw TransactionTagError.invalidState }
        try validateWorkspace(tag.workspaceID)
        guard state.tagDefinitions[tag.id] == tag else { throw TransactionTagError.staleReview }
    }

    private func validateWorkspace(_ workspaceID: String) throws {
        try TransactionTagValidation.validateIdentity(workspaceID)
        guard state.workspaces[workspaceID] != nil else { throw TransactionTagError.workspaceMismatch }
    }

    private func validateTransactions(_ ids: Set<String>, workspaceID: String) throws {
        let facts = ids.compactMap { state.transactions[$0] }
        guard facts.count == ids.count, facts.allSatisfy(\.isTrusted), Set(facts.map(\.id)) == ids else {
            throw TransactionTagError.transactionNotFound
        }
        guard facts.allSatisfy({ $0.workspaceId == workspaceID }) else { throw TransactionTagError.workspaceMismatch }
    }
}
