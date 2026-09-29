import Foundation

extension SQLiteFinancialIntelligenceRepository {
    func loadPlanning(into snapshot: inout FinancialIntelligenceSnapshot) throws {
        let workspace = snapshot.workspaceID
        snapshot.recurring = try db.query(sql: "SELECT id,account_id,definition_json FROM recurring_definitions WHERE workspace_id=? ORDER BY id;", params: [workspace]) { row in
            let value: RecurringDefinition = try Self.decode(row.string(at: 2))
            guard value.id == row.string(at: 0), value.accountID == row.string(at: 1), value.workspaceID == workspace else { throw FinancialIntelligenceError.invalidRecord }
            return value
        }
        snapshot.occurrences = try db.query(sql: "SELECT id,definition_id,occurrence_json FROM recurring_occurrences WHERE workspace_id=? ORDER BY id;", params: [workspace]) { row in
            let value: RecurringOccurrence = try Self.decode(row.string(at: 2))
            guard value.id == row.string(at: 0), value.definitionID == row.string(at: 1), value.workspaceID == workspace else { throw FinancialIntelligenceError.invalidRecord }
            return value
        }
        snapshot.reserves = try db.query(sql: "SELECT id,account_id,designation_json FROM reserve_designations WHERE workspace_id=? ORDER BY id;", params: [workspace]) { row in
            let value: ReserveDesignation = try Self.decode(row.string(at: 2))
            guard value.id == row.string(at: 0), value.accountID == row.string(at: 1), value.workspaceID == workspace else { throw FinancialIntelligenceError.invalidRecord }
            return value
        }
        snapshot.salaries = try db.query(sql: "SELECT transaction_id,assistance_json FROM salary_assistance WHERE workspace_id=? ORDER BY transaction_id;", params: [workspace]) { row in
            let value: SalaryAssistance = try Self.decode(row.string(at: 1))
            guard value.transactionID == row.string(at: 0), value.workspaceID == workspace else { throw FinancialIntelligenceError.invalidRecord }
            return value
        }
        snapshot.preferences = try db.query(sql: "SELECT preferences_json FROM intelligence_preferences WHERE workspace_id=?;", params: [workspace]) { row in
            let value: IntelligencePreferences = try Self.decode(row.string(at: 0))
            guard value.workspaceID == workspace else { throw FinancialIntelligenceError.invalidRecord }
            return value
        }.first
        snapshot.plans = try db.query(sql: "SELECT a.plan_month,a.assistance_json,p.id FROM plan_assistance a LEFT JOIN funding_plans p ON p.workspace_id=a.workspace_id AND p.plan_month=a.plan_month WHERE a.workspace_id=? ORDER BY a.plan_month;", params: [workspace]) { row in
            let value: PlanAssistance = try Self.decode(row.string(at: 1))
            guard value.month == row.string(at: 0), value.workspaceID == workspace, row.string(at: 2) != nil else { throw FinancialIntelligenceError.invalidRecord }
            return value
        }
    }

    func validatePlanning(_ snapshot: FinancialIntelligenceSnapshot, replacingPlan: FundingPlanDTO? = nil) throws {
        let ids = PlanningMetadataValidation.referencedTransactionIDs(snapshot)
        let facts = try canonicalFacts(ids: ids, workspaceID: snapshot.workspaceID)
        let cardStatements = try db.query(sql: "SELECT id,liability_account_id,statement_currency FROM card_statements WHERE workspace_id=?;", params: [snapshot.workspaceID]) { row in
            (row.string(at: 0) ?? "", (accountID: row.string(at: 1) ?? "", currency: row.string(at: 2) ?? ""))
        }
        try PlanningMetadataValidation.validate(snapshot, accounts: SQLiteAccountRepo(db: db, supportsBankSections: true).accounts(workspaceId: snapshot.workspaceID), facts: Array(facts.values), cardStatements: Dictionary(uniqueKeysWithValues: cardStatements), salaryStatements: SQLiteSalaryRepository.readSnapshot(db: db, workspaceId: snapshot.workspaceID).statements)
        var plans = try SQLiteFundingPlanRepository(db: db, supportsBalanceDates: supportsBalanceDates).plans(workspaceId: snapshot.workspaceID)
        if let replacingPlan { plans.removeAll { $0.planMonthISO == replacingPlan.planMonthISO }; plans.append(replacingPlan) }
        let accounts = try SQLiteAccountRepo(db: db, supportsBankSections: true).accounts(workspaceId: snapshot.workspaceID)
        for plan in plans { try PlanningMetadataValidation.validatePlanLinks(plan, snapshot: snapshot); try PlanningMetadataValidation.validateFunding(plan, accounts: accounts) }
    }

    func applyPlanning(_ edit: PlanningMetadataEdit) throws {
        try transaction {
            guard var candidate = try snapshot(workspaceID: edit.workspaceID) else { throw FinancialIntelligenceError.unavailable }
            try edit.apply(to: &candidate)
            try validatePlanning(candidate)
            // Global record IDs cannot be borrowed from another workspace by an upsert.
            let identity: (table: String, column: String, id: String)?
            switch edit {
            case .recurring(let value, _), .confirmRecurringCandidate(let value, _, _): identity = ("recurring_definitions", "id", value.id)
            case .occurrence(let value, _): identity = ("recurring_occurrences", "id", value.id)
            case .reserve(let value, _), .removeReserve(let value): identity = ("reserve_designations", "id", value.id)
            case .salary(let value, _): identity = ("salary_assistance", "transaction_id", value.id)
            case .preferences: identity = nil
            }
            if let identity {
                let workspaces = try db.query(sql: "SELECT workspace_id FROM \(identity.table) WHERE \(identity.column)=?;", params: [identity.id]) { $0.string(at: 0) }
                guard workspaces.allSatisfy({ $0 == edit.workspaceID }) else { throw FinancialIntelligenceError.invalidRecord }
            }
            switch edit {
            case .recurring(let value, _), .confirmRecurringCandidate(let value, _, _):
                try db.executePrepared(sql: "INSERT INTO recurring_definitions(id,workspace_id,account_id,definition_json) VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET account_id=excluded.account_id,definition_json=excluded.definition_json;", params: [value.id,value.workspaceID,value.accountID,try Self.encode(value)])
                if case .confirmRecurringCandidate = edit, let preferences = candidate.preferences {
                    try db.executePrepared(sql: "INSERT INTO intelligence_preferences(workspace_id,preferences_json) VALUES(?,?) ON CONFLICT(workspace_id) DO UPDATE SET preferences_json=excluded.preferences_json;", params: [preferences.workspaceID,try Self.encode(preferences)])
                }
            case .occurrence(let value, _):
                try db.executePrepared(sql: "INSERT INTO recurring_occurrences(id,workspace_id,definition_id,occurrence_json) VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET occurrence_json=excluded.occurrence_json;", params: [value.id,value.workspaceID,value.definitionID,try Self.encode(value)])
            case .reserve(let value, _):
                try db.executePrepared(sql: "INSERT INTO reserve_designations(id,workspace_id,account_id,designation_json) VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET account_id=excluded.account_id,designation_json=excluded.designation_json;", params: [value.id,value.workspaceID,value.accountID ?? NSNull(),try Self.encode(value)])
            case .removeReserve(let value):
                try db.executePrepared(sql: "DELETE FROM reserve_designations WHERE id=? AND workspace_id=?;", params: [value.id,value.workspaceID])
            case .salary(let value, _):
                try db.executePrepared(sql: "INSERT INTO salary_assistance(transaction_id,workspace_id,assistance_json) VALUES(?,?,?) ON CONFLICT(transaction_id) DO UPDATE SET assistance_json=excluded.assistance_json;", params: [value.transactionID,value.workspaceID,try Self.encode(value)])
            case .preferences(let value, _):
                try db.executePrepared(sql: "INSERT INTO intelligence_preferences(workspace_id,preferences_json) VALUES(?,?) ON CONFLICT(workspace_id) DO UPDATE SET preferences_json=excluded.preferences_json;", params: [value.workspaceID,try Self.encode(value)])
            }
        }
    }

    /// Called inside the ordinary FundingPlan save transaction, after its parent
    /// exists. A validation or write failure rolls back the complete plan.
    func savePlanAssistance(_ plan: FundingPlanDTO) throws {
        let value = plan.assistance, workspaceID = plan.workspaceId, month = plan.planMonthISO
        guard let candidate = try snapshot(workspaceID: workspaceID, replacingPlan: plan) else { throw FinancialIntelligenceError.unavailable }
        for id in value?.appliedSalaryIDs ?? [] {
            guard var salary = candidate.salaries.first(where: { $0.id == id && $0.draftState != .dismissed }) else { throw FinancialIntelligenceError.invalidRecord }
            salary.draftState = .consumed
            try db.executePrepared(sql: "UPDATE salary_assistance SET assistance_json=? WHERE transaction_id=? AND workspace_id=?;", params: [try Self.encode(salary),id,workspaceID])
        }
        try db.executePrepared(sql: "DELETE FROM plan_assistance WHERE workspace_id=? AND plan_month=?;", params: [workspaceID,month])
        if let value {
            try db.executePrepared(sql: "INSERT INTO plan_assistance(workspace_id,plan_month,assistance_json) VALUES(?,?,?);", params: [workspaceID,month,try Self.encode(value)])
        }
    }

    static func encode<T: Encodable>(_ value: T) throws -> String { String(decoding: try JSONEncoder().encode(value), as: UTF8.self) }
    static func decode<T: Decodable>(_ text: String?) throws -> T {
        guard let data = text?.data(using: .utf8) else { throw FinancialIntelligenceError.invalidRecord }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

extension InMemoryFinancialIntelligenceRepository {
    func loadPlanning(into snapshot: inout FinancialIntelligenceSnapshot) {
        let workspace = snapshot.workspaceID
        snapshot.recurring = state.recurringDefinitions.values.filter { $0.workspaceID == workspace }.sorted { $0.id < $1.id }
        snapshot.occurrences = state.recurringOccurrences.values.filter { $0.workspaceID == workspace }.sorted { $0.id < $1.id }
        snapshot.reserves = state.reserveDesignations.values.filter { $0.workspaceID == workspace }.sorted { $0.id < $1.id }
        snapshot.salaries = state.salaryAssistance.values.filter { $0.workspaceID == workspace }.sorted { $0.id < $1.id }
        snapshot.preferences = state.intelligencePreferences[workspace]
        snapshot.plans = state.fundingPlans.values.filter { $0.workspaceId == workspace }.compactMap(\.assistance).sorted { $0.month < $1.month }
    }
    func validatePlanning(_ snapshot: FinancialIntelligenceSnapshot, replacingPlan: FundingPlanDTO? = nil) throws {
        let ids = PlanningMetadataValidation.referencedTransactionIDs(snapshot)
        let cardStatements = Dictionary(uniqueKeysWithValues: state.cardStatements.values.filter { $0.workspaceId == snapshot.workspaceID }.map { ($0.id, (accountID: $0.liabilityAccountId, currency: $0.statementCurrency)) })
        try PlanningMetadataValidation.validate(snapshot, accounts: Array(state.accounts.values), facts: ids.compactMap { state.transactions[$0] }.map(MovementValidation.Fact.init), cardStatements: cardStatements, salaryStatements: Array(state.salaryStatements.values))
        var plans = state.fundingPlans.values.filter { $0.workspaceId == snapshot.workspaceID }
        if let replacingPlan { plans.removeAll { $0.planMonthISO == replacingPlan.planMonthISO }; plans.append(replacingPlan) }
        for plan in plans { try PlanningMetadataValidation.validatePlanLinks(plan, snapshot: snapshot); try PlanningMetadataValidation.validateFunding(plan, accounts: Array(state.accounts.values)) }
    }
    func applyPlanning(_ edit: PlanningMetadataEdit) throws {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard state.workspaces[edit.workspaceID] != nil, var candidate = try snapshot(workspaceID: edit.workspaceID) else { throw FinancialIntelligenceError.unavailable }
        try edit.apply(to: &candidate)
        try validatePlanning(candidate)
        switch edit {
        case .recurring(let value, _), .confirmRecurringCandidate(let value, _, _):
            guard state.recurringDefinitions[value.id].map({ $0.workspaceID == value.workspaceID }) ?? true else { throw FinancialIntelligenceError.invalidRecord }
            state.recurringDefinitions[value.id] = value
            if case .confirmRecurringCandidate = edit { state.intelligencePreferences[value.workspaceID] = candidate.preferences }
        case .occurrence(let value, _):
            guard state.recurringOccurrences[value.id].map({ $0.workspaceID == value.workspaceID }) ?? true else { throw FinancialIntelligenceError.invalidRecord }
            state.recurringOccurrences[value.id] = value
        case .reserve(let value, _):
            guard state.reserveDesignations[value.id].map({ $0.workspaceID == value.workspaceID }) ?? true else { throw FinancialIntelligenceError.invalidRecord }
            state.reserveDesignations[value.id] = value
        case .removeReserve(let value): state.reserveDesignations[value.id] = nil
        case .salary(let value, _): state.salaryAssistance[value.id] = value
        case .preferences(let value, _): state.intelligencePreferences[value.workspaceID] = value
        }
    }
    func validatePlanAssistance(_ plan: FundingPlanDTO) throws {
        guard try snapshot(workspaceID: plan.workspaceId, replacingPlan: plan) != nil else { throw FinancialIntelligenceError.unavailable }
    }
}
