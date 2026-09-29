import Foundation

public protocol NetWorthMembershipRepository {
    func snapshot(workspaceID: String) throws -> NetWorthMembershipSnapshot
    @discardableResult
    func setIncluded(_ included: Bool, member: NetWorthMemberID, workspaceID: String) throws -> Bool
}

struct UnavailableNetWorthMembershipRepository: NetWorthMembershipRepository {
    func snapshot(workspaceID: String) throws -> NetWorthMembershipSnapshot {
        throw NetWorthMembershipError.unavailable
    }
    func setIncluded(_ included: Bool, member: NetWorthMemberID, workspaceID: String) throws -> Bool {
        throw NetWorthMembershipError.unavailable
    }
}

final class SQLiteNetWorthMembershipRepository: NetWorthMembershipRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func snapshot(workspaceID: String) throws -> NetWorthMembershipSnapshot {
        try db.withExclusiveAccess {
            let rows = try db.query(sql: "SELECT account_id, container_id FROM net_worth_exclusions WHERE workspace_id = ? ORDER BY account_id, container_id;", params: [workspaceID]) { row -> NetWorthMemberID in
                switch (row.string(at: 0), row.string(at: 1)) {
                case (let account?, nil) where !account.isEmpty: return .account(account)
                case (nil, let container?) where !container.isEmpty: return .investmentContainer(container)
                default: throw NetWorthMembershipError.invalidSnapshot
                }
            }
            guard Set(rows).count == rows.count else { throw NetWorthMembershipError.invalidSnapshot }
            for member in rows { try validate(member, workspaceID: workspaceID) }
            return NetWorthMembershipSnapshot(workspaceID: workspaceID, excluded: Set(rows))
        }
    }

    func setIncluded(_ included: Bool, member: NetWorthMemberID, workspaceID: String) throws -> Bool {
        try db.withExclusiveAccess {
            try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
            do {
                try validate(member, workspaceID: workspaceID)
                let before = try snapshot(workspaceID: workspaceID)
                let column: String
                let id: String
                switch member {
                case .account(let value): column = "account_id"; id = value
                case .investmentContainer(let value): column = "container_id"; id = value
                }
                if included {
                    try db.executePrepared(sql: "DELETE FROM net_worth_exclusions WHERE workspace_id = ? AND \(column) = ?;", params: [workspaceID, id])
                } else if !before.excluded.contains(member) {
                    try db.executePrepared(sql: "INSERT INTO net_worth_exclusions(workspace_id, \(column)) VALUES (?, ?);", params: [workspaceID, id])
                }
                var expected = before.excluded
                if included { expected.remove(member) } else { expected.insert(member) }
                guard try snapshot(workspaceID: workspaceID).excluded == expected else {
                    throw NetWorthMembershipError.invalidSnapshot
                }
                try db.execute(sql: "COMMIT;")
                return before.excluded != expected
            } catch {
                try? db.execute(sql: "ROLLBACK;")
                throw error
            }
        }
    }

    private func validate(_ member: NetWorthMemberID, workspaceID: String) throws {
        let valid: Bool
        switch member {
        case .account(let id):
            valid = try db.query(sql: "SELECT 1 FROM accounts WHERE id = ? AND workspace_id = ? AND account_type IN ('bank', 'credit_card');", params: [id, workspaceID]) { _ in true }.count == 1
        case .investmentContainer(let id):
            valid = try db.query(sql: "SELECT 1 FROM investment_containers WHERE id = ? AND workspace_id = ?;", params: [id, workspaceID]) { _ in true }.count == 1
        }
        guard valid else { throw NetWorthMembershipError.invalidTarget }
    }
}
