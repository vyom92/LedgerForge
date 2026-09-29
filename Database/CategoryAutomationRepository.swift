import Foundation

extension SQLiteCategoryRepo {
    func supportsCategoryAutomation() throws -> Bool {
        automationSupported
    }

    func automationSnapshot(workspaceId: String) throws -> CategoryAutomationSnapshot? {
        guard try supportsCategoryAutomation() else { return nil }
        return try db.withExclusiveAccess {
            let rules = try db.query(sql: "SELECT id, category_id, account_id, version, rule_json FROM category_rules WHERE workspace_id = ? ORDER BY id;", params: [workspaceId]) { row in
                let rule = try JSONDecoder().decode(CategoryRule.self, from: Data((row.string(at: 4) ?? "").utf8))
                try rule.validate()
                guard rule.id == row.string(at: 0), rule.workspaceID == workspaceId,
                      rule.categoryID == row.string(at: 1), rule.accountID == row.string(at: 2),
                      rule.version == Int(row.int64(at: 3) ?? 0) else { throw CategoryAutomationError.invalidState }
                return rule
            }
            for rule in rules { try validateRuleParents(rule, requireActive: false) }
            let intents = try db.query(sql: "SELECT transaction_id, kind, category_id, matches_json FROM transaction_category_intent WHERE workspace_id = ?;", params: [workspaceId]) { row -> (String, CategoryIntent) in
                guard let id = row.string(at: 0), let kind = CategoryIntent.Kind(rawValue: row.string(at: 1) ?? "") else { throw CategoryAutomationError.invalidState }
                let matches = try JSONDecoder().decode([CategoryRuleMatch].self, from: Data((row.string(at: 3) ?? "").utf8))
                return (id, CategoryIntent(kind: kind, categoryID: row.string(at: 2), matches: matches))
            }
            let work = try db.query(sql: "SELECT transaction_id, import_session_id, outcome, explanation, origin FROM category_import_work WHERE workspace_id = ?;", params: [workspaceId]) { row -> (String, CategoryImportWork) in
                guard let id = row.string(at: 0), let session = row.string(at: 1),
                      let outcome = CategoryImportWork.Outcome(rawValue: row.string(at: 2) ?? ""),
                      let origin = CategoryImportWork.Origin(rawValue: row.string(at: 4) ?? "") else { throw CategoryAutomationError.invalidState }
                return (id, CategoryImportWork(transactionID: id, importSessionID: session, outcome: outcome, explanation: row.string(at: 3) ?? "", origin: origin))
            }
            let assigned = Dictionary(uniqueKeysWithValues: try assignments(workspaceId: workspaceId).map { ($0.transactionId, $0.categoryId) })
            let trusted = Dictionary(uniqueKeysWithValues: try db.query(sql: "SELECT id,import_session_id FROM transactions WHERE workspace_id = ? AND is_trusted = 1;", params: [workspaceId]) { ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "") })
            for (id, intent) in intents {
                guard trusted[id] != nil,
                      assigned[id] == intent.categoryID,
                      (intent.kind == .deliberatelyCleared) == (intent.categoryID == nil),
                      intent.kind == .automatic ? !intent.matches.isEmpty : intent.matches.isEmpty,
                      intent.matches.allSatisfy({ !$0.ruleID.isEmpty && $0.version > 0 }) else { throw CategoryAutomationError.invalidState }
            }
            for (id, item) in work {
                guard trusted[id] == item.importSessionID else { throw CategoryAutomationError.invalidState }
            }
            return CategoryAutomationSnapshot(rules: rules, intents: Dictionary(uniqueKeysWithValues: intents), work: Dictionary(uniqueKeysWithValues: work))
        }
    }

    func saveRule(_ rule: CategoryRule, previousVersion: Int?) throws {
        try rule.validate()
        try withImmediateTransaction {
            guard try supportsCategoryAutomation() else { throw CategoryAutomationError.unavailable }
            try validateRuleParents(rule, requireActive: true)
            let stored = try db.query(sql: "SELECT version, workspace_id FROM category_rules WHERE id = ?;", params: [rule.id]) { (Int($0.int64(at: 0) ?? 0), $0.string(at: 1) ?? "") }.first
            guard stored?.0 == previousVersion, stored == nil || stored?.1 == rule.workspaceID,
                  rule.version == (previousVersion ?? 0) + 1 else { throw CategoryAutomationError.stalePreview }
            try db.executePrepared(sql: "INSERT INTO category_rules(id,workspace_id,category_id,account_id,version,rule_json) VALUES(?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET category_id=excluded.category_id,account_id=excluded.account_id,version=excluded.version,rule_json=excluded.rule_json;",
                params: [rule.id, rule.workspaceID, rule.categoryID, rule.accountID ?? NSNull(), rule.version, try metadataJSON(rule)])
        }
    }

    func deleteRule(id: String, workspaceId: String, version: Int) throws {
        try withImmediateTransaction {
            guard try count("SELECT COUNT(*) FROM category_rules WHERE id = ? AND workspace_id = ? AND version = ?;", [id, workspaceId, version]) == 1 else { throw CategoryAutomationError.stalePreview }
            try db.executePrepared(sql: "DELETE FROM category_rules WHERE id = ? AND workspace_id = ?;", params: [id, workspaceId])
        }
    }

    func applyCategoryEvaluation(_ evaluation: CategoryEvaluation, workspaceId: String, historical: Bool) throws -> Int {
        try withImmediateTransaction {
            guard let current = try automationSnapshot(workspaceId: workspaceId) else { throw CategoryAutomationError.unavailable }
            let active = Set(try categories(workspaceId: workspaceId).filter { !$0.isArchived }.map(\.id))
            guard current.rules == evaluation.rules, active == evaluation.activeCategoryIDs,
                  Set(evaluation.decisions.map(\.transactionID)).count == evaluation.decisions.count else { throw CategoryAutomationError.stalePreview }
            let assigned = Dictionary(uniqueKeysWithValues: try assignments(workspaceId: workspaceId).map { ($0.transactionId, $0.categoryId) })
            var updated = 0
            for proposal in evaluation.decisions {
                let id = proposal.transactionID
                guard let input = try ruleInput(id: id, workspaceID: workspaceId) else { throw CategoryAutomationError.invalidState }
                if !historical && !current.pendingIDs.contains(id) { continue }
                // Re-evaluate in the write transaction. A concurrent manual edit wins.
                let decision = CategoryEvaluation.evaluate(inputs: [input], snapshot: current, assignments: assigned, activeCategoryIDs: active).decisions[0]
                guard decision.outcome == .protected || decision == proposal else { throw CategoryAutomationError.stalePreview }
                if decision.outcome == .assigned, let category = decision.categoryID {
                    try writeAssignment(categoryID: category, transactionID: id, workspaceID: workspaceId)
                    try writeIntent(CategoryIntent(kind: .automatic, categoryID: category, matches: decision.matches), transactionID: id, workspaceID: workspaceId)
                }
                if historical && [.noMatch, .conflict].contains(decision.outcome), current.intents[id]?.kind == .automatic {
                    try writeAssignment(categoryID: nil, transactionID: id, workspaceID: workspaceId)
                    try db.executePrepared(sql: "DELETE FROM transaction_category_intent WHERE transaction_id = ?;", params: [id])
                }
                if historical && current.work[id] == nil {
                    try db.executePrepared(sql: "INSERT INTO category_import_work(transaction_id,workspace_id,import_session_id,outcome,explanation,origin) SELECT id,workspace_id,import_session_id,?,?,'historical' FROM transactions WHERE id = ? AND import_session_id IS NOT NULL;", params: [decision.outcome.rawValue, decision.explanation, id])
                } else {
                    try db.executePrepared(sql: "UPDATE category_import_work SET outcome = ?, explanation = ? WHERE transaction_id = ? AND workspace_id = ?;", params: [decision.outcome.rawValue, decision.explanation, id, workspaceId])
                }
                updated += 1
            }
            return updated
        }
    }

    func readIntent(transactionID: String) throws -> CategoryIntent? {
        try db.query(sql: "SELECT kind,category_id,matches_json FROM transaction_category_intent WHERE transaction_id = ?;", params: [transactionID]) { row in
            guard let kind = CategoryIntent.Kind(rawValue: row.string(at: 0) ?? "") else { throw CategoryAutomationError.invalidState }
            return CategoryIntent(kind: kind, categoryID: row.string(at: 1), matches: try JSONDecoder().decode([CategoryRuleMatch].self, from: Data((row.string(at: 2) ?? "").utf8)))
        }.first
    }

    func writeIntent(_ intent: CategoryIntent, transactionID: String, workspaceID: String) throws {
        try db.executePrepared(sql: "DELETE FROM transaction_category_intent WHERE transaction_id = ?;", params: [transactionID])
        try db.executePrepared(sql: "INSERT INTO transaction_category_intent(transaction_id,workspace_id,kind,category_id,matches_json) VALUES(?,?,?,?,?);", params: [transactionID, workspaceID, intent.kind.rawValue, intent.categoryID ?? NSNull(), try metadataJSON(intent.matches)])
    }

    func writeAssignment(categoryID: String?, transactionID: String, workspaceID: String) throws {
        if let categoryID {
            try db.executePrepared(sql: "INSERT INTO transaction_category_assignments(workspace_id,transaction_id,category_id) VALUES(?,?,?) ON CONFLICT(transaction_id) DO UPDATE SET category_id=excluded.category_id;", params: [workspaceID, transactionID, categoryID])
        } else {
            try db.executePrepared(sql: "DELETE FROM transaction_category_assignments WHERE transaction_id = ? AND workspace_id = ?;", params: [transactionID, workspaceID])
        }
    }

    private func validateRuleParents(_ rule: CategoryRule, requireActive: Bool) throws {
        guard let category = try category(id: rule.categoryID), category.workspaceId == rule.workspaceID else { throw CategoryRepositoryError.workspaceMismatch }
        if requireActive && category.isArchived { throw CategoryRepositoryError.categoryArchived }
        if let account = rule.accountID, try count("SELECT COUNT(*) FROM accounts WHERE id = ? AND workspace_id = ?;", [account, rule.workspaceID]) != 1 { throw CategoryRepositoryError.workspaceMismatch }
    }

    private func ruleInput(id: String, workspaceID: String) throws -> CategoryRuleInput? {
        try db.query(sql: "SELECT id,account_id,native_currency,direction,description,reference FROM transactions WHERE id = ? AND workspace_id = ? AND is_trusted = 1;", params: [id, workspaceID]) { row in
            CategoryRuleInput(transactionID: row.string(at: 0) ?? "", accountID: row.string(at: 1), currency: row.string(at: 2) ?? "", direction: row.string(at: 3) ?? "", narration: row.string(at: 4) ?? "", reference: row.string(at: 5) ?? "")
        }.first
    }

    private func metadataJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let text = String(data: try encoder.encode(value), encoding: .utf8) else { throw CategoryAutomationError.invalidState }
        return text
    }
}

extension InMemoryCategoryRepo {
    func automationSnapshot(workspaceId: String) throws -> CategoryAutomationSnapshot? {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        let transactionIDs = Set(state.transactions.values.filter { $0.workspaceId == workspaceId }.map(\.id))
        return CategoryAutomationSnapshot(rules: state.categoryRules.values.filter { $0.workspaceID == workspaceId }.sorted { $0.id < $1.id },
            intents: state.categoryIntents.filter { transactionIDs.contains($0.key) }, work: state.categoryWork.filter { transactionIDs.contains($0.key) })
    }

    func saveRule(_ rule: CategoryRule, previousVersion: Int?) throws {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        try rule.validate()
        guard let category = state.categories[rule.categoryID], category.workspaceId == rule.workspaceID,
              rule.accountID == nil || state.accounts[rule.accountID!]?.workspaceId == rule.workspaceID else { throw CategoryRepositoryError.workspaceMismatch }
        guard !category.isArchived else { throw CategoryRepositoryError.categoryArchived }
        let existing = state.categoryRules[rule.id]
        guard existing?.version == previousVersion, existing == nil || existing?.workspaceID == rule.workspaceID,
              rule.version == (previousVersion ?? 0) + 1 else { throw CategoryAutomationError.stalePreview }
        state.categoryRules[rule.id] = rule
    }

    func deleteRule(id: String, workspaceId: String, version: Int) throws {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard let existing = state.categoryRules[id], existing.workspaceID == workspaceId, existing.version == version else { throw CategoryAutomationError.stalePreview }
        state.categoryRules.removeValue(forKey: id)
    }

    func applyCategoryEvaluation(_ evaluation: CategoryEvaluation, workspaceId: String, historical: Bool) throws -> Int {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard let current = try automationSnapshot(workspaceId: workspaceId) else { throw CategoryAutomationError.unavailable }
        let active = Set(state.categories.values.filter { $0.workspaceId == workspaceId && !$0.isArchived }.map(\.id))
        guard current.rules == evaluation.rules, active == evaluation.activeCategoryIDs,
              Set(evaluation.decisions.map(\.transactionID)).count == evaluation.decisions.count else { throw CategoryAutomationError.stalePreview }
        let assigned = state.categoryAssignments.mapValues(\.categoryId)
        var intents = state.categoryIntents, assignments = state.categoryAssignments, work = state.categoryWork
        var updated = 0
        for proposal in evaluation.decisions {
            let id = proposal.transactionID
            guard let transaction = state.transactions[id], transaction.workspaceId == workspaceId, transaction.isTrusted else { throw CategoryAutomationError.invalidState }
            if !historical && !current.pendingIDs.contains(id) { continue }
            let decision = CategoryEvaluation.evaluate(inputs: [CategoryRuleInput(transaction: transaction)], snapshot: current, assignments: assigned, activeCategoryIDs: active).decisions[0]
            guard decision.outcome == .protected || decision == proposal else { throw CategoryAutomationError.stalePreview }
            if decision.outcome == .assigned, let category = decision.categoryID {
                assignments[id] = TransactionCategoryAssignmentDTO(workspaceId: workspaceId, transactionId: id, categoryId: category)
                intents[id] = CategoryIntent(kind: .automatic, categoryID: category, matches: decision.matches)
            }
            if historical && [.noMatch, .conflict].contains(decision.outcome), current.intents[id]?.kind == .automatic {
                assignments.removeValue(forKey: id); intents.removeValue(forKey: id)
            }
            if let session = transaction.importSessionId {
                work[id] = CategoryImportWork(transactionID: id, importSessionID: session, outcome: decision.outcome,
                    explanation: decision.explanation, origin: current.work[id]?.origin ?? .historical)
            }
            updated += 1
        }
        state.categoryIntents = intents; state.categoryAssignments = assignments; state.categoryWork = work
        return updated
    }
}
