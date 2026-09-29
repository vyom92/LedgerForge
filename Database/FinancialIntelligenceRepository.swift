import Foundation

public protocol FinancialIntelligenceRepository {
    /// Nil is only for an explicitly historical provider. Current read errors throw.
    func snapshot(workspaceID: String) throws -> FinancialIntelligenceSnapshot?
    func saveMovement(_ event: MovementEvent, replacing expected: MovementEvent?) throws
    func removeMovement(_ event: MovementEvent) throws
    func applyPlanning(_ edit: PlanningMetadataEdit) throws
}

struct UnavailableFinancialIntelligenceRepository: FinancialIntelligenceRepository {
    func snapshot(workspaceID: String) throws -> FinancialIntelligenceSnapshot? { nil }
    func saveMovement(_ event: MovementEvent, replacing expected: MovementEvent?) throws { throw FinancialIntelligenceError.unavailable }
    func removeMovement(_ event: MovementEvent) throws { throw FinancialIntelligenceError.unavailable }
    func applyPlanning(_ edit: PlanningMetadataEdit) throws { throw FinancialIntelligenceError.unavailable }
}

final class SQLiteFinancialIntelligenceRepository: FinancialIntelligenceRepository {
    let db: SQLiteDatabase
    let supportsBalanceDates: Bool
    init(db: SQLiteDatabase, supportsBalanceDates: Bool = true) {
        self.db = db; self.supportsBalanceDates = supportsBalanceDates
    }

    func snapshot(workspaceID: String) throws -> FinancialIntelligenceSnapshot? {
        try snapshot(workspaceID: workspaceID, replacingPlan: nil)
    }

    func snapshot(workspaceID: String, replacingPlan: FundingPlanDTO?) throws -> FinancialIntelligenceSnapshot? {
        try db.withExclusiveAccess {
            let events = try db.query(sql: "SELECT id,decision,event_json FROM movement_events WHERE workspace_id=? ORDER BY id;", params: [workspaceID]) { row in
                guard let data = row.string(at: 2)?.data(using: .utf8) else { throw FinancialIntelligenceError.invalidRecord }
                let value = try JSONDecoder().decode(MovementEvent.self, from: data)
                guard value.id == row.string(at: 0), value.workspaceID == workspaceID, value.decision.rawValue == row.string(at: 1) else { throw FinancialIntelligenceError.invalidRecord }
                return value
            }
            var observedLegs: [String: String] = [:]
            let facts = try canonicalFacts(ids: Set(events.flatMap(\.transactionIDs)), workspaceID: workspaceID)
            let accounts = try SQLiteAccountRepo(db: db, supportsBankSections: true).accounts(workspaceId: workspaceID)
            for event in events {
                try MovementValidation.validate(event, facts: event.transactionIDs.compactMap { facts[$0] }, accounts: accounts)
                for id in event.transactionIDs where event.decision == .confirmed {
                    guard observedLegs.updateValue(event.id, forKey: id) == nil else { throw FinancialIntelligenceError.occupiedLeg }
                }
            }
            let stored = try db.query(sql: "SELECT l.transaction_id,l.event_id FROM movement_legs l JOIN movement_events e ON e.id=l.event_id WHERE e.workspace_id=?;", params: [workspaceID]) {
                ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "")
            }
            guard Dictionary(uniqueKeysWithValues: stored) == observedLegs else { throw FinancialIntelligenceError.invalidRecord }
            var snapshot = FinancialIntelligenceSnapshot(workspaceID: workspaceID, movements: events)
            try loadPlanning(into: &snapshot)
            if let replacingPlan { try PlanningMetadataValidation.replaceSavedPlan(replacingPlan, in: &snapshot) }
            try validatePlanning(snapshot, replacingPlan: replacingPlan)
            return snapshot
        }
    }

    func saveMovement(_ event: MovementEvent, replacing expected: MovementEvent?) throws {
        try transaction {
            let current = try snapshot(workspaceID: event.workspaceID)
            guard current?.movements.first(where: { $0.id == event.id }) == expected else { throw FinancialIntelligenceError.staleReview }
            try validate(event)
            if event.decision == .confirmed, let occupied = current?.confirmedByTransaction {
                guard event.transactionIDs.allSatisfy({ occupied[$0] == nil || occupied[$0]?.id == event.id }) else { throw FinancialIntelligenceError.occupiedLeg }
            }
            try db.executePrepared(sql: "DELETE FROM movement_events WHERE id=? AND workspace_id=?;", params: [event.id,event.workspaceID])
            let json = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
            try db.executePrepared(sql: "INSERT INTO movement_events(id,workspace_id,decision,event_json) VALUES(?,?,?,?);", params: [event.id,event.workspaceID,event.decision.rawValue,json])
            if event.decision == .confirmed {
                for id in event.transactionIDs {
                    try db.executePrepared(sql: "INSERT INTO movement_legs(transaction_id,event_id) VALUES(?,?);", params: [id,event.id])
                }
            }
        }
    }

    func removeMovement(_ event: MovementEvent) throws {
        try transaction {
            guard try snapshot(workspaceID: event.workspaceID)?.movements.first(where: { $0.id == event.id }) == event else { throw FinancialIntelligenceError.staleReview }
            try db.executePrepared(sql: "DELETE FROM movement_events WHERE id=? AND workspace_id=?;", params: [event.id,event.workspaceID])
        }
    }

    private func validate(_ event: MovementEvent) throws {
        let facts = try canonicalFacts(ids: Set(event.transactionIDs), workspaceID: event.workspaceID)
        let accounts = try SQLiteAccountRepo(db: db, supportsBankSections: true).accounts(workspaceId: event.workspaceID)
        try MovementValidation.validate(event, facts: Array(facts.values), accounts: accounts)
    }

    func canonicalFacts(ids: Set<String>, workspaceID: String) throws -> [String: MovementValidation.Fact] {
        let ordered = ids.sorted()
        var result: [String: MovementValidation.Fact] = [:]
        for start in stride(from: 0, to: ordered.count, by: 500) {
            let batch = Array(ordered[start..<min(start + 500, ordered.count)])
            let placeholders = batch.map { _ in "?" }.joined(separator: ",")
            let values = try db.query(sql: "SELECT id,workspace_id,account_id,native_currency,direction,amount_minor,is_trusted,posted_date FROM transactions WHERE workspace_id=? AND id IN (\(placeholders));", params: [workspaceID] + batch) { row -> MovementValidation.Fact in
                guard let id = row.string(at: 0), let workspace = row.string(at: 1), let account = row.string(at: 2),
                      let currency = row.string(at: 3), let direction = row.string(at: 4), let amount = row.int64(at: 5) else { throw FinancialIntelligenceError.invalidRecord }
                return .init(id: id, workspaceID: workspace, accountID: account, currency: currency, direction: direction, amountMinor: amount, trusted: row.int64(at: 6) == 1, financialDate: row.string(at: 7).map { String($0.prefix(10)) })
            }
            for value in values { result[value.id] = value }
        }
        return result
    }

    func transaction<T>(_ body: () throws -> T) throws -> T {
        try db.withExclusiveAccess {
            try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
            do { let result = try body(); try db.execute(sql: "COMMIT;"); return result }
            catch { try? db.execute(sql: "ROLLBACK;"); throw error }
        }
    }
}

final class InMemoryFinancialIntelligenceRepository: FinancialIntelligenceRepository {
    let state: InMemoryRepositoryState
    init(state: InMemoryRepositoryState) { self.state = state }
    func snapshot(workspaceID: String) throws -> FinancialIntelligenceSnapshot? {
        try snapshot(workspaceID: workspaceID, replacingPlan: nil)
    }

    func snapshot(workspaceID: String, replacingPlan: FundingPlanDTO?) throws -> FinancialIntelligenceSnapshot? {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        let events = state.movementEvents.values.filter { $0.workspaceID == workspaceID }.sorted { $0.id < $1.id }
        var legs = Set<String>()
        for event in events {
            try validate(event)
            if event.decision == .confirmed {
                for id in event.transactionIDs { guard legs.insert(id).inserted else { throw FinancialIntelligenceError.occupiedLeg } }
            }
        }
        var snapshot = FinancialIntelligenceSnapshot(workspaceID: workspaceID, movements: events)
        loadPlanning(into: &snapshot)
        if let replacingPlan { try PlanningMetadataValidation.replaceSavedPlan(replacingPlan, in: &snapshot) }
        try validatePlanning(snapshot, replacingPlan: replacingPlan)
        return snapshot
    }
    func saveMovement(_ event: MovementEvent, replacing expected: MovementEvent?) throws {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard state.movementEvents[event.id] == expected else { throw FinancialIntelligenceError.staleReview }
        try validate(event)
        let current = try snapshot(workspaceID: event.workspaceID)
        if event.decision == .confirmed, let occupied = current?.confirmedByTransaction {
            guard event.transactionIDs.allSatisfy({ occupied[$0] == nil || occupied[$0]?.id == event.id }) else { throw FinancialIntelligenceError.occupiedLeg }
        }
        state.movementEvents[event.id] = event
    }
    func removeMovement(_ event: MovementEvent) throws {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard state.movementEvents[event.id] == event else { throw FinancialIntelligenceError.staleReview }
        state.movementEvents[event.id] = nil
    }
    private func validate(_ event: MovementEvent) throws {
        try MovementValidation.validate(event, facts: event.transactionIDs.compactMap { state.transactions[$0] }.map(MovementValidation.Fact.init), accounts: Array(state.accounts.values))
    }
}
