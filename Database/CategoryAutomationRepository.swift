import Foundation
import CryptoKit

extension SQLiteCategoryRepo {
    /// Backup verification runs on its owning database queue, without creating
    /// a main-actor repository or changing any owner metadata.
    nonisolated static func verifyBackupContents(_ db: SQLiteDatabase, schemaVersion: Int) throws {
        guard (28...34).contains(schemaVersion) else { throw CategoryAutomationError.unavailable }
        let supportsSpendingIntent = schemaVersion >= 34
        try db.withExclusiveAccess {
            func required(_ value: String?) throws -> String {
                guard let value, !value.isEmpty else { throw CategoryAutomationError.invalidState }
                return value
            }
            _ = try db.query(sql: """
                SELECT r.id,r.workspace_id,r.category_id,r.account_id,r.version,r.rule_json,
                       c.workspace_id,a.workspace_id,w.id
                FROM category_rules r
                LEFT JOIN categories c ON c.id=r.category_id
                LEFT JOIN accounts a ON a.id=r.account_id
                LEFT JOIN workspaces w ON w.id=r.workspace_id;
                """) { row in
                let id = try required(row.string(at: 0)), workspace = try required(row.string(at: 1))
                let rule = try JSONDecoder().decode(CategoryRule.self, from: Data(try required(row.string(at: 5)).utf8))
                try rule.validate()
                guard rule.id == id, rule.workspaceID == workspace,
                      rule.categoryID == row.string(at: 2), rule.accountID == row.string(at: 3),
                      rule.version == row.int64(at: 4).map(Int.init), row.string(at: 6) == workspace,
                      rule.accountID == nil || row.string(at: 7) == workspace,
                      row.string(at: 8) == workspace else { throw CategoryAutomationError.invalidState }
                guard supportsSpendingIntent || (rule.bankExpenseAction == nil && !rule.predicates.contains { $0.match == .doesNotContain }) else {
                    throw CategoryAutomationError.unavailable
                }
            }
            _ = try db.query(sql: """
                SELECT i.transaction_id,i.workspace_id,i.kind,i.category_id,i.matches_json,
                       t.workspace_id,t.is_trusted,c.workspace_id,a.category_id,a.workspace_id,w.id
                FROM transaction_category_intent i
                LEFT JOIN transactions t ON t.id=i.transaction_id
                LEFT JOIN categories c ON c.id=i.category_id
                LEFT JOIN transaction_category_assignments a ON a.transaction_id=i.transaction_id
                LEFT JOIN workspaces w ON w.id=i.workspace_id;
                """) { row in
                _ = try required(row.string(at: 0))
                let workspace = try required(row.string(at: 1))
                guard let kind = CategoryIntent.Kind(rawValue: try required(row.string(at: 2))) else { throw CategoryAutomationError.invalidState }
                let categoryID = row.string(at: 3)
                let matches = try JSONDecoder().decode([CategoryRuleMatch].self, from: Data(try required(row.string(at: 4)).utf8))
                guard row.string(at: 5) == workspace, row.int64(at: 6) == 1,
                      categoryID == nil || row.string(at: 7) == workspace,
                      row.string(at: 8) == categoryID,
                      categoryID == nil || row.string(at: 9) == workspace,
                      row.string(at: 10) == workspace,
                      (kind == .deliberatelyCleared) == (categoryID == nil),
                      kind == .automatic ? !matches.isEmpty : matches.isEmpty,
                      matches.allSatisfy({ !$0.ruleID.isEmpty && $0.version > 0 }) else { throw CategoryAutomationError.invalidState }
            }
            _ = try db.query(sql: """
                SELECT c.transaction_id,c.workspace_id,c.import_session_id,c.outcome,c.origin,
                       t.workspace_id,t.is_trusted,t.import_session_id,s.workspace_id,w.id
                FROM category_import_work c
                LEFT JOIN transactions t ON t.id=c.transaction_id
                LEFT JOIN import_sessions s ON s.id=c.import_session_id
                LEFT JOIN workspaces w ON w.id=c.workspace_id;
                """) { row in
                _ = try required(row.string(at: 0))
                let workspace = try required(row.string(at: 1)), session = try required(row.string(at: 2))
                guard CategoryImportWork.Outcome(rawValue: try required(row.string(at: 3))) != nil,
                      CategoryImportWork.Origin(rawValue: try required(row.string(at: 4))) != nil,
                      row.string(at: 5) == workspace, row.int64(at: 6) == 1,
                      row.string(at: 7) == session, row.string(at: 8) == workspace,
                      row.string(at: 9) == workspace else { throw CategoryAutomationError.invalidState }
            }
            guard supportsSpendingIntent else { return }
            var profilesByTransaction: [String: Set<String>] = [:]
            _ = try db.query(sql: """
                SELECT i.transaction_id,i.workspace_id,r.id,n.id,n.row_index,n.record_digest,
                       n.normalized_document_id,d.id,d.profile_id,d.profile_version,s.workspace_id
                FROM transaction_spending_intent i
                LEFT JOIN transaction_raw_rows r ON r.transaction_id=i.transaction_id
                LEFT JOIN normalized_rows n ON n.id=r.normalized_row_id
                LEFT JOIN normalized_documents d ON d.id=n.normalized_document_id
                LEFT JOIN import_sessions s ON s.id=d.import_session_id;
                """) { row in
                let id = try required(row.string(at: 0)), workspace = try required(row.string(at: 1))
                _ = try required(row.string(at: 2)); _ = try required(row.string(at: 3))
                _ = try required(row.string(at: 5)); _ = try required(row.string(at: 9))
                let document = try required(row.string(at: 6)), profile = try required(row.string(at: 8))
                guard (row.int64(at: 4) ?? 0) > 0, row.string(at: 7) == document,
                      row.string(at: 10) == workspace else { throw CategoryAutomationError.invalidState }
                profilesByTransaction[id, default: []].insert(profile)
            }
            _ = try db.query(sql: """
                SELECT i.transaction_id,i.workspace_id,i.kind,i.matches_json,
                       t.workspace_id,t.is_trusted,t.direction,t.amount_minor,t.amount_decimal,
                       t.native_currency,t.description,a.workspace_id,a.account_type,a.native_currency,w.id
                FROM transaction_spending_intent i
                LEFT JOIN transactions t ON t.id=i.transaction_id
                LEFT JOIN accounts a ON a.id=t.account_id
                LEFT JOIN workspaces w ON w.id=i.workspace_id;
                """) { row in
                let id = try required(row.string(at: 0)), workspace = try required(row.string(at: 1))
                guard let kind = TransactionSpendingIntent.Kind(rawValue: try required(row.string(at: 2))),
                      let minor = row.int64(at: 7), row.string(at: 4) == workspace, row.int64(at: 5) == 1,
                      row.string(at: 11) == workspace, row.string(at: 14) == workspace else { throw CategoryAutomationError.invalidState }
                let intent = TransactionSpendingIntent(kind: kind, matches: try JSONDecoder().decode([CategoryRuleMatch].self,
                    from: Data(try required(row.string(at: 3)).utf8)))
                try intent.validate()
                guard try CategorySpendingFacts.sourceEligible(domain: required(row.string(at: 12)),
                    direction: required(row.string(at: 6)), amountMinor: minor, amountDecimal: required(row.string(at: 8)),
                    currency: required(row.string(at: 9)), accountCurrency: required(row.string(at: 13)),
                    narration: row.string(at: 10) ?? "", profiles: profilesByTransaction[id] ?? []) else {
                    throw CategoryAutomationError.invalidState
                }
            }
        }
    }

    func supportsCategoryAutomation() throws -> Bool {
        automationSupported
    }

    func automationSnapshot(workspaceId: String) throws -> CategoryAutomationSnapshot? {
        try readAutomationSnapshot(workspaceId: workspaceId, hydrationInputs: nil).snapshot
    }

    func automationSnapshot(workspaceId: String, hydrationInputs: CategoryAutomationHydrationInputs) throws -> CategoryAutomationSnapshot? {
        try readAutomationSnapshot(workspaceId: workspaceId, hydrationInputs: hydrationInputs).snapshot
    }

    private func readAutomationSnapshot(workspaceId: String, hydrationInputs: CategoryAutomationHydrationInputs?) throws -> (snapshot: CategoryAutomationSnapshot?, transactions: [TransactionDTO]?) {
        guard try supportsCategoryAutomation() else { return (nil, nil) }
        return try db.withExclusiveAccess {
            let rows = try CategoryMetadataReadRows.capture(db, workspaceID: workspaceId, supportsSpendingIntent: spendingIntentSupported)
            try hydrationInputs?.validate(workspaceID: workspaceId, trustedImportSessions: rows.trustedImportSessions())
            let spending = spendingIntentSupported ? try spendingContexts(workspaceID: workspaceId, hydrationInputs: hydrationInputs) : nil
            return (try rows.decodeAutomation(workspaceID: workspaceId, supportsSpendingIntent: spendingIntentSupported,
                                              contexts: spending?.contexts ?? [:]), spending?.transactions)
        }
    }

    func saveRule(_ rule: CategoryRule, previousVersion: Int?) throws {
        try rule.validate()
        try withImmediateTransaction {
            guard try supportsCategoryAutomation() else { throw CategoryAutomationError.unavailable }
            guard spendingIntentSupported || (rule.bankExpenseAction == nil && !rule.predicates.contains { $0.match == .doesNotContain }) else {
                throw CategoryAutomationError.unavailable
            }
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
        try applyEvaluationReceipt(evaluation, workspaceId: workspaceId, historical: historical).changedIDs.count
    }

    func applyReviewedCategoryEvaluation(_ preview: CategoryHistoricalPreview, workspaceId: String) throws -> CategoryApplyReceipt {
        try applyEvaluationReceipt(preview.evaluation, workspaceId: workspaceId, historical: true, review: preview)
    }

    private func applyEvaluationReceipt(_ evaluation: CategoryEvaluation, workspaceId: String, historical: Bool,
                                        review: CategoryHistoricalPreview? = nil) throws -> CategoryApplyReceipt {
        try withImmediateTransaction {
            let captured = try readAutomationSnapshot(workspaceId: workspaceId, hydrationInputs: nil)
            guard let current = captured.snapshot else { throw CategoryAutomationError.unavailable }
            let inputs = captured.transactions.map { transactions in
                Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, CategoryRuleInput(transaction: $0)) })
            }
            let active = Set(try categories(workspaceId: workspaceId).filter { !$0.isArchived }.map(\.id))
            let assigned = Dictionary(uniqueKeysWithValues: try assignments(workspaceId: workspaceId).map { ($0.transactionId, $0.categoryId) })
            return try CategorySQLiteApply.apply(evaluation, database: db, workspaceId: workspaceId, historical: historical,
                current: current, inputs: inputs, active: active, assigned: assigned, review: review)
        }
    }

    func setSpendingSuppressed(_ suppressed: Bool, transactionID: String, workspaceId: String,
                               expected: TransactionSpendingIntent?) throws -> Bool {
        try withImmediateTransaction {
            guard spendingIntentSupported, let snapshot = try automationSnapshot(workspaceId: workspaceId) else { throw CategoryAutomationError.unavailable }
            guard snapshot.spendingIntents[transactionID] == expected else { throw CategoryAutomationError.stalePreview }
            guard snapshot.spendingContexts[transactionID]?.sourceEligible == true else { throw CategoryAutomationError.invalidState }
            if !suppressed && expected?.kind != .deliberatelySuppressed { return false }
            let proposed: TransactionSpendingIntent? = suppressed ? .init(kind: .deliberatelySuppressed, matches: []) : nil
            guard proposed != expected else { return false }
            try writeSpendingIntent(proposed, transactionID: transactionID, workspaceID: workspaceId)
            return true
        }
    }

    private func writeSpendingIntent(_ intent: TransactionSpendingIntent?, transactionID: String, workspaceID: String) throws {
        try CategorySQLiteApply.writeSpendingIntent(db, intent, transactionID: transactionID, workspaceID: workspaceID,
            supportsSpendingIntent: spendingIntentSupported)
    }

    private func spendingContexts(workspaceID: String, hydrationInputs: CategoryAutomationHydrationInputs?) throws -> (contexts: [String: CategorySpendingContext], transactions: [TransactionDTO]) {
        let transactions: [TransactionDTO]
        let accounts: [AccountDTO]
        let metadata: FinancialIntelligenceSnapshot
        if let hydrationInputs {
            guard let captured = hydrationInputs.intelligence, captured.workspaceID == workspaceID else { throw CategoryAutomationError.invalidState }
            transactions = hydrationInputs.transactions
            accounts = hydrationInputs.accounts
            metadata = captured
        } else {
            transactions = try SQLiteTransactionRepo(db: db).trustedTransactions(workspaceId: workspaceID)
            accounts = try SQLiteAccountRepo(db: db).accounts(workspaceId: workspaceID)
            guard let current = try SQLiteFinancialIntelligenceRepository(db: db, supportsBalanceDates: true,
                supportsRefundAllocations: true).snapshot(workspaceID: workspaceID) else { throw CategoryAutomationError.invalidState }
            metadata = current
        }
        let contexts = try CategorySpendingFacts.contexts(transactions: transactions, accounts: accounts,
            movements: metadata.movements, profiles: CategorySpendingFacts.profiles)
        return (contexts, transactions)
    }

    func readIntent(transactionID: String) throws -> CategoryIntent? {
        try db.query(sql: "SELECT kind,category_id,matches_json FROM transaction_category_intent WHERE transaction_id = ?;", params: [transactionID]) { row in
            guard let kind = CategoryIntent.Kind(rawValue: row.string(at: 0) ?? "") else { throw CategoryAutomationError.invalidState }
            return CategoryIntent(kind: kind, categoryID: row.string(at: 1), matches: try JSONDecoder().decode([CategoryRuleMatch].self, from: Data((row.string(at: 2) ?? "").utf8)))
        }.first
    }

    func writeIntent(_ intent: CategoryIntent, transactionID: String, workspaceID: String) throws {
        try CategorySQLiteApply.writeIntent(db, intent, transactionID: transactionID, workspaceID: workspaceID)
    }

    func writeAssignment(categoryID: String?, transactionID: String, workspaceID: String) throws {
        try CategorySQLiteApply.writeAssignment(db, categoryID: categoryID, transactionID: transactionID, workspaceID: workspaceID)
    }

    private func validateRuleParents(_ rule: CategoryRule, requireActive: Bool) throws {
        guard let category = try category(id: rule.categoryID), category.workspaceId == rule.workspaceID else { throw CategoryRepositoryError.workspaceMismatch }
        if requireActive && category.isArchived { throw CategoryRepositoryError.categoryArchived }
        if let account = rule.accountID, try count("SELECT COUNT(*) FROM accounts WHERE id = ? AND workspace_id = ?;", [account, rule.workspaceID]) != 1 { throw CategoryRepositoryError.workspaceMismatch }
    }

    private func metadataJSON<T: Encodable>(_ value: T) throws -> String {
        try CategorySQLiteApply.metadataJSON(value)
    }
}

/// One SQL apply implementation serves the ordinary repository and the app's
/// immutable worker request. Callers retain BEGIN IMMEDIATE through its return;
/// the complete validated inputs must belong to that same database cut.
nonisolated private enum CategorySQLiteApply {
    static func apply(_ evaluation: CategoryEvaluation, database db: SQLiteDatabase, workspaceId: String,
                      historical: Bool, current: CategoryAutomationSnapshot, inputs: [String: CategoryRuleInput]?,
                      active: Set<String>, assigned: [String: String], review: CategoryHistoricalPreview? = nil) throws -> CategoryApplyReceipt {
        try review?.requireCurrent(current, assignments: assigned)
        var receipt = CategoryApplyReceipt()
        let reviewedDecision = try evaluation.validatedDecisionLookup(rules: current.rules, activeCategoryIDs: active)
        let pendingIDs = current.pendingIDs
        var updated: Set<String> = []
        for proposal in evaluation.decisions {
            let id = proposal.transactionID
            let sourceInput: CategoryRuleInput?
            if let inputs { sourceInput = inputs[id] }
            else { sourceInput = try ruleInput(db, id: id, workspaceID: workspaceId) }
            guard let input = sourceInput else { throw CategoryAutomationError.invalidState }
            if !historical && !pendingIDs.contains(id) { continue }
            // Reuse only an evaluator-minted decision whose complete inputs
            // still agree with this write transaction. Manual edits miss
            // the witness and retain the existing re-evaluation behavior.
            let decision = reviewedDecision(input, current, assigned[id]) ??
                CategoryEvaluation.evaluate(inputs: [input], snapshot: current, assignments: assigned, activeCategoryIDs: active).decisions[0]
            guard decision.accepts(proposal) else { throw CategoryAutomationError.stalePreview }
            receipt.record(decision, assigned: assigned[id], intent: current.intents[id], work: current.work[id],
                importSessionID: input.importSessionID, historical: historical)
            var changed = false
            if decision.outcome == .assigned, let category = decision.categoryID {
                if assigned[id] != category {
                    try writeAssignment(db, categoryID: category, transactionID: id, workspaceID: workspaceId)
                    changed = true
                }
                let intent = CategoryIntent(kind: .automatic, categoryID: category, matches: decision.matches)
                if current.intents[id] != intent {
                    try writeIntent(db, intent, transactionID: id, workspaceID: workspaceId)
                    changed = true
                }
            }
            if historical && [.noMatch, .conflict].contains(decision.outcome), current.intents[id]?.kind == .automatic {
                try writeAssignment(db, categoryID: nil, transactionID: id, workspaceID: workspaceId)
                try db.executePrepared(sql: "DELETE FROM transaction_category_intent WHERE transaction_id = ?;", params: [id])
                changed = true
            }
            if let spending = decision.spending, spending.changesIntent,
               historical || !spending.removesIntent {
                try writeSpendingIntent(db, spending.proposed, transactionID: id, workspaceID: workspaceId, supportsSpendingIntent: current.supportsSpendingIntent)
                changed = true
            }
            let explanation = [decision.explanation, decision.spending?.explanation].compactMap { $0 }.joined(separator: " ")
            if historical && current.work[id] == nil {
                try db.executePrepared(sql: "INSERT INTO category_import_work(transaction_id,workspace_id,import_session_id,outcome,explanation,origin) SELECT id,workspace_id,import_session_id,?,?,'historical' FROM transactions WHERE id = ? AND workspace_id = ? AND import_session_id IS NOT NULL;", params: [decision.outcome.rawValue, explanation, id, workspaceId])
                let changes = try db.query(sql: "SELECT changes();") { Int($0.int64(at: 0) ?? 0) }.first ?? 0
                if changes > 0 { changed = true }
            } else if let work = current.work[id], work.outcome != decision.outcome || work.explanation != explanation {
                try db.executePrepared(sql: "UPDATE category_import_work SET outcome = ?, explanation = ? WHERE transaction_id = ? AND workspace_id = ?;", params: [decision.outcome.rawValue, explanation, id, workspaceId])
                changed = true
            }
            if changed { updated.insert(id) }
        }
        guard receipt.changedIDs == updated, review == nil || review?.receipt == receipt else {
            throw CategoryAutomationError.stalePreview
        }
        return receipt
    }

    static func writeSpendingIntent(_ db: SQLiteDatabase, _ intent: TransactionSpendingIntent?, transactionID: String, workspaceID: String, supportsSpendingIntent: Bool) throws {
        guard supportsSpendingIntent else { throw CategoryAutomationError.unavailable }
        try intent?.validate()
        try db.executePrepared(sql: "DELETE FROM transaction_spending_intent WHERE transaction_id=? AND workspace_id=?;", params: [transactionID, workspaceID])
        if let intent {
            try db.executePrepared(sql: "INSERT INTO transaction_spending_intent(transaction_id,workspace_id,kind,matches_json) VALUES(?,?,?,?);",
                params: [transactionID, workspaceID, intent.kind.rawValue, try metadataJSON(intent.matches)])
        }
    }

    static func writeIntent(_ db: SQLiteDatabase, _ intent: CategoryIntent, transactionID: String, workspaceID: String) throws {
        try db.executePrepared(sql: "DELETE FROM transaction_category_intent WHERE transaction_id = ?;", params: [transactionID])
        try db.executePrepared(sql: "INSERT INTO transaction_category_intent(transaction_id,workspace_id,kind,category_id,matches_json) VALUES(?,?,?,?,?);", params: [transactionID, workspaceID, intent.kind.rawValue, intent.categoryID ?? NSNull(), try metadataJSON(intent.matches)])
    }

    static func writeAssignment(_ db: SQLiteDatabase, categoryID: String?, transactionID: String, workspaceID: String) throws {
        if let categoryID {
            try db.executePrepared(sql: "INSERT INTO transaction_category_assignments(workspace_id,transaction_id,category_id) VALUES(?,?,?) ON CONFLICT(transaction_id) DO UPDATE SET category_id=excluded.category_id;", params: [workspaceID, transactionID, categoryID])
        } else {
            try db.executePrepared(sql: "DELETE FROM transaction_category_assignments WHERE transaction_id = ? AND workspace_id = ?;", params: [transactionID, workspaceID])
        }
    }

    static func metadataJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let text = String(data: try encoder.encode(value), encoding: .utf8) else { throw CategoryAutomationError.invalidState }
        return text
    }

    private static func ruleInput(_ db: SQLiteDatabase, id: String, workspaceID: String) throws -> CategoryRuleInput? {
        try db.query(sql: "SELECT id,account_id,native_currency,direction,description,reference,import_session_id FROM transactions WHERE id = ? AND workspace_id = ? AND is_trusted = 1;", params: [id, workspaceID]) { row in
            CategoryRuleInput(transactionID: row.string(at: 0) ?? "", accountID: row.string(at: 1), currency: row.string(at: 2) ?? "", direction: row.string(at: 3) ?? "", narration: row.string(at: 4) ?? "", reference: row.string(at: 5) ?? "", importSessionID: row.string(at: 6))
        }.first
    }
}

extension InMemoryCategoryRepo {
    func automationSnapshot(workspaceId: String) throws -> CategoryAutomationSnapshot? {
        try readAutomationSnapshot(workspaceId: workspaceId, hydrationInputs: nil)
    }

    func automationSnapshot(workspaceId: String, hydrationInputs: CategoryAutomationHydrationInputs) throws -> CategoryAutomationSnapshot? {
        try readAutomationSnapshot(workspaceId: workspaceId, hydrationInputs: hydrationInputs)
    }

    private func readAutomationSnapshot(workspaceId: String, hydrationInputs: CategoryAutomationHydrationInputs?) throws -> CategoryAutomationSnapshot? {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        let transactionIDs = Set(state.transactions.values.filter { $0.workspaceId == workspaceId }.map(\.id))
        var result = CategoryAutomationSnapshot(rules: state.categoryRules.values.filter { $0.workspaceID == workspaceId }.sorted { $0.id < $1.id },
            intents: state.categoryIntents.filter { transactionIDs.contains($0.key) }, work: state.categoryWork.filter { transactionIDs.contains($0.key) })
        result.supportsSpendingIntent = true
        let transactions: [TransactionDTO]
        let accounts: [AccountDTO]
        let metadata: FinancialIntelligenceSnapshot
        if let hydrationInputs {
            let trusted = Dictionary(uniqueKeysWithValues: state.transactions.values
                .filter { $0.workspaceId == workspaceId && $0.isTrusted }.map { ($0.id, $0.importSessionId ?? "") })
            try hydrationInputs.validate(workspaceID: workspaceId, trustedImportSessions: trusted)
            guard let captured = hydrationInputs.intelligence, captured.workspaceID == workspaceId else { throw CategoryAutomationError.invalidState }
            transactions = hydrationInputs.transactions
            accounts = hydrationInputs.accounts
            metadata = captured
        } else {
            transactions = state.transactions.values.filter { $0.workspaceId == workspaceId && $0.isTrusted }
            accounts = state.accounts.values.filter { $0.workspaceId == workspaceId }
            guard let current = try InMemoryFinancialIntelligenceRepository(state: state).snapshot(workspaceID: workspaceId) else { throw CategoryAutomationError.invalidState }
            metadata = current
        }
        result.spendingContexts = try CategorySpendingFacts.contexts(
            transactions: transactions, accounts: accounts, movements: metadata.movements) { transaction in
                var profiles = Set<String>()
                for raw in transaction.rawRows {
                    guard let row = self.state.normalizedRows[raw.normalizedRowId], row.sourceOrdinal > 0, !row.digest.isEmpty,
                          let document = self.state.normalizedDocuments[row.normalizedDocumentId],
                          !document.profileId.isEmpty, !document.profileVersion.isEmpty else { throw CategoryAutomationError.invalidState }
                    profiles.insert(document.profileId)
                }
                return profiles
            }
        for (id, intent) in state.spendingIntents {
            guard let parent = state.transactions[id], parent.isTrusted else { throw CategoryAutomationError.invalidState }
            guard parent.workspaceId == workspaceId else { continue }
            try intent.validate()
            guard result.spendingContexts[id]?.sourceEligible == true else { throw CategoryAutomationError.invalidState }
            result.spendingIntents[id] = intent
        }
        return result
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
        try applyEvaluationReceipt(evaluation, workspaceId: workspaceId, historical: historical).changedIDs.count
    }

    func applyReviewedCategoryEvaluation(_ preview: CategoryHistoricalPreview, workspaceId: String) throws -> CategoryApplyReceipt {
        try applyEvaluationReceipt(preview.evaluation, workspaceId: workspaceId, historical: true, review: preview)
    }

    private func applyEvaluationReceipt(_ evaluation: CategoryEvaluation, workspaceId: String, historical: Bool,
                                        review: CategoryHistoricalPreview? = nil) throws -> CategoryApplyReceipt {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard let current = try automationSnapshot(workspaceId: workspaceId) else { throw CategoryAutomationError.unavailable }
        let active = Set(state.categories.values.filter { $0.workspaceId == workspaceId && !$0.isArchived }.map(\.id))
        let reviewedDecision = try evaluation.validatedDecisionLookup(rules: current.rules, activeCategoryIDs: active)
        let assigned = state.categoryAssignments.mapValues(\.categoryId)
        let pendingIDs = current.pendingIDs
        var intents = state.categoryIntents, assignments = state.categoryAssignments, work = state.categoryWork
        var spendingIntents = state.spendingIntents
        try review?.requireCurrent(current, assignments: assigned)
        var receipt = CategoryApplyReceipt()
        var updated: Set<String> = []
        for proposal in evaluation.decisions {
            let id = proposal.transactionID
            guard let transaction = state.transactions[id], transaction.workspaceId == workspaceId, transaction.isTrusted else { throw CategoryAutomationError.invalidState }
            if !historical && !pendingIDs.contains(id) { continue }
            let input = CategoryRuleInput(transaction: transaction)
            let decision = reviewedDecision(input, current, assigned[id]) ??
                CategoryEvaluation.evaluate(inputs: [input], snapshot: current, assignments: assigned, activeCategoryIDs: active).decisions[0]
            guard decision.accepts(proposal) else { throw CategoryAutomationError.stalePreview }
            receipt.record(decision, assigned: assigned[id], intent: current.intents[id], work: current.work[id],
                importSessionID: input.importSessionID, historical: historical)
            var changed = false
            if decision.outcome == .assigned, let category = decision.categoryID {
                if assigned[id] != category {
                    assignments[id] = TransactionCategoryAssignmentDTO(workspaceId: workspaceId, transactionId: id, categoryId: category)
                    changed = true
                }
                let intent = CategoryIntent(kind: .automatic, categoryID: category, matches: decision.matches)
                if current.intents[id] != intent {
                    intents[id] = intent
                    changed = true
                }
            }
            if historical && [.noMatch, .conflict].contains(decision.outcome), current.intents[id]?.kind == .automatic {
                assignments.removeValue(forKey: id); intents.removeValue(forKey: id)
                changed = true
            }
            if let spending = decision.spending, spending.changesIntent,
               historical || !spending.removesIntent {
                try spending.proposed?.validate()
                spendingIntents[id] = spending.proposed
                changed = true
            }
            if let session = transaction.importSessionId {
                let proposedWork = CategoryImportWork(transactionID: id, importSessionID: session, outcome: decision.outcome,
                    explanation: [decision.explanation, decision.spending?.explanation].compactMap { $0 }.joined(separator: " "), origin: current.work[id]?.origin ?? .historical)
                if current.work[id] != proposedWork {
                    work[id] = proposedWork
                    changed = true
                }
            }
            if changed { updated.insert(id) }
        }
        guard receipt.changedIDs == updated, review == nil || review?.receipt == receipt else {
            throw CategoryAutomationError.stalePreview
        }
        if !updated.isEmpty {
            state.categoryIntents = intents; state.categoryAssignments = assignments; state.categoryWork = work
            state.spendingIntents = spendingIntents
        }
        return receipt
    }

    func setSpendingSuppressed(_ suppressed: Bool, transactionID: String, workspaceId: String,
                               expected: TransactionSpendingIntent?) throws -> Bool {
        state.stateLock.lock(); defer { state.stateLock.unlock() }
        guard let snapshot = try automationSnapshot(workspaceId: workspaceId) else { throw CategoryAutomationError.unavailable }
        guard snapshot.spendingIntents[transactionID] == expected else { throw CategoryAutomationError.stalePreview }
        guard snapshot.spendingContexts[transactionID]?.sourceEligible == true else { throw CategoryAutomationError.invalidState }
        if !suppressed && expected?.kind != .deliberatelySuppressed { return false }
        let proposed: TransactionSpendingIntent? = suppressed ? .init(kind: .deliberatelySuppressed, matches: []) : nil
        guard proposed != expected else { return false }
        state.spendingIntents[transactionID] = proposed
        return true
    }
}

/// Shared exact canonical eligibility. SQL and memory callers obtain provenance
/// from their own accepted source graphs; no display-only fact can enable it.
nonisolated private enum CategorySpendingFacts {
    static func sourceEligible(domain: String, direction: String, amountMinor: Int64, amountDecimal: String,
                               currency: String, accountCurrency: String, narration: String, profiles: Set<String>) throws -> Bool {
        guard domain == "bank", direction == "debit", amountMinor < 0 else { return false }
        let money = try Money(canonicalDecimal: amountDecimal, currency: currency)
        guard money == (try Money.fromMinorUnits(amountMinor, currency: currency)),
              money.amount < 0, currency == accountCurrency else { throw CategoryAutomationError.invalidState }
        return !profiles.isEmpty && !SpendingSourcePolicy.isLoanOrEMI(domain: domain,
            narration: narration, parserProfileIDs: profiles)
    }

    static func profiles(_ transaction: TransactionDTO) throws -> Set<String> {
            guard !transaction.rawRows.isEmpty else { return [] }
            var profiles = Set<String>()
            for raw in transaction.rawRows {
                guard let profile = raw.parserProfileId, !profile.isEmpty,
                      let version = raw.parserProfileVersion, !version.isEmpty,
                      let document = raw.normalizedDocumentId, !document.isEmpty,
                      let ordinal = raw.sourceOrdinal, ordinal > 0,
                      let digest = raw.normalizedRecordDigest, !digest.isEmpty else { throw CategoryAutomationError.invalidState }
                profiles.insert(profile)
            }
            return profiles
    }

    static func contexts(transactions: [TransactionDTO], accounts: [AccountDTO], movements: [MovementEvent],
                         profiles: (TransactionDTO) throws -> Set<String>) throws -> [String: CategorySpendingContext] {
        let accountMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        var interpretations: [String: [MovementEvent]] = [:]
        for event in movements.sorted(by: { $0.id < $1.id }) where event.decision == .confirmed || event.kind == .expense {
            for id in event.transactionIDs { interpretations[id, default: []].append(event) }
        }
        var result: [String: CategorySpendingContext] = [:]
        for transaction in transactions {
            guard transaction.isTrusted, let accountID = transaction.accountId, let account = accountMap[accountID],
                  account.workspaceId == transaction.workspaceId else { throw CategoryAutomationError.invalidState }
            guard let domain = account.accountType, domain == "bank", transaction.direction == "debit", transaction.amountMinor < 0 else { continue }
            let eligible = try sourceEligible(domain: domain, direction: transaction.direction,
                amountMinor: transaction.amountMinor, amountDecimal: transaction.amountDecimal,
                currency: transaction.nativeCurrency, accountCurrency: account.nativeCurrency,
                narration: transaction.description ?? "", profiles: profiles(transaction))
            result[transaction.id] = .init(sourceEligible: eligible, interpretations: interpretations[transaction.id] ?? [])
        }
        return result
    }
}

/// Purpose-specific copied rows. Ordinary reads and the async override path use
/// these same rule, intent, pending-work and spending-intent validators.
nonisolated struct CategoryMetadataReadRows: Sendable {
    let categoryRows, assignmentRows, ruleRows, intentRows, workRows, spendingRows, trustedRows, accountRows: [SQLiteRow]

    static func capture(_ db: SQLiteDatabase, workspaceID: String, supportsSpendingIntent: Bool) throws -> Self {
        func rows(_ sql: String) throws -> [SQLiteRow] { try db.query(sql: sql, params: [workspaceID]) { $0 } }
        return try Self(
            categoryRows: rows("SELECT id, workspace_id, name, normalized_name, is_archived, created_at, updated_at FROM categories WHERE workspace_id=?;"),
            assignmentRows: rows("SELECT workspace_id, transaction_id, category_id FROM transaction_category_assignments WHERE workspace_id=?;"),
            ruleRows: rows("SELECT id, category_id, account_id, version, rule_json FROM category_rules WHERE workspace_id=? ORDER BY id;"),
            intentRows: rows("SELECT transaction_id, kind, category_id, matches_json FROM transaction_category_intent WHERE workspace_id=?;"),
            workRows: rows("SELECT transaction_id, import_session_id, outcome, explanation, origin FROM category_import_work WHERE workspace_id=?;"),
            spendingRows: supportsSpendingIntent ? rows("SELECT transaction_id, kind, matches_json FROM transaction_spending_intent WHERE workspace_id=?;") : [],
            trustedRows: rows("SELECT id, import_session_id FROM transactions WHERE workspace_id=? AND is_trusted=1;"),
            accountRows: rows("SELECT id FROM accounts WHERE workspace_id=?;"))
    }

    func categories() -> [CategoryDTO] { categoryRows.map(SQLiteCategoryRepo.decodeCategory) }
    func assignments() -> [TransactionCategoryAssignmentDTO] { assignmentRows.map(SQLiteCategoryRepo.decodeAssignment) }
    func trustedImportSessions() throws -> [String: String] {
        let pairs = trustedRows.map { ($0.string(at: 0) ?? "", $0.string(at: 1) ?? "") }
        guard Set(pairs.map(\.0)).count == pairs.count else { throw CategoryAutomationError.invalidState }
        return Dictionary(uniqueKeysWithValues: pairs)
    }

    func decodeAutomation(workspaceID: String, supportsSpendingIntent: Bool,
                          contexts: [String: CategorySpendingContext]) throws -> CategoryAutomationSnapshot {
        let rules = try ruleRows.map { row in
            let rule = try JSONDecoder().decode(CategoryRule.self, from: Data((row.string(at: 4) ?? "").utf8))
            try rule.validate()
            guard rule.id == row.string(at: 0), rule.workspaceID == workspaceID,
                  rule.categoryID == row.string(at: 1), rule.accountID == row.string(at: 2),
                  rule.version == Int(row.int64(at: 3) ?? 0) else { throw CategoryAutomationError.invalidState }
            return rule
        }
        let categories = categories(), assignments = assignments()
        let accountIDs = Set(accountRows.compactMap { $0.string(at: 0) })
        for rule in rules {
            guard categories.contains(where: { $0.id == rule.categoryID && $0.workspaceId == workspaceID }),
                  rule.accountID == nil || accountIDs.contains(rule.accountID!) else { throw CategoryRepositoryError.workspaceMismatch }
        }
        guard supportsSpendingIntent || rules.allSatisfy({ $0.bankExpenseAction == nil && !$0.predicates.contains { $0.match == .doesNotContain } }) else {
            throw CategoryAutomationError.unavailable
        }
        let intents = try intentRows.map { row -> (String, CategoryIntent) in
            guard let id = row.string(at: 0), let kind = CategoryIntent.Kind(rawValue: row.string(at: 1) ?? "") else { throw CategoryAutomationError.invalidState }
            let matches = try JSONDecoder().decode([CategoryRuleMatch].self, from: Data((row.string(at: 3) ?? "").utf8))
            return (id, CategoryIntent(kind: kind, categoryID: row.string(at: 2), matches: matches))
        }
        let work = try workRows.map { row -> (String, CategoryImportWork) in
            guard let id = row.string(at: 0), let session = row.string(at: 1),
                  let outcome = CategoryImportWork.Outcome(rawValue: row.string(at: 2) ?? ""),
                  let origin = CategoryImportWork.Origin(rawValue: row.string(at: 4) ?? "") else { throw CategoryAutomationError.invalidState }
            return (id, CategoryImportWork(transactionID: id, importSessionID: session, outcome: outcome, explanation: row.string(at: 3) ?? "", origin: origin))
        }
        guard Set(assignments.map(\.transactionId)).count == assignments.count,
              Set(intents.map(\.0)).count == intents.count,
              Set(work.map(\.0)).count == work.count else { throw CategoryAutomationError.invalidState }
        let assigned = Dictionary(uniqueKeysWithValues: assignments.map { ($0.transactionId, $0.categoryId) })
        let trusted = try trustedImportSessions()
        for (id, intent) in intents {
            guard trusted[id] != nil, assigned[id] == intent.categoryID,
                  (intent.kind == .deliberatelyCleared) == (intent.categoryID == nil),
                  intent.kind == .automatic ? !intent.matches.isEmpty : intent.matches.isEmpty,
                  intent.matches.allSatisfy({ !$0.ruleID.isEmpty && $0.version > 0 }) else { throw CategoryAutomationError.invalidState }
        }
        for (id, item) in work {
            guard trusted[id] == item.importSessionID else { throw CategoryAutomationError.invalidState }
        }
        var result = CategoryAutomationSnapshot(rules: rules, intents: Dictionary(uniqueKeysWithValues: intents), work: Dictionary(uniqueKeysWithValues: work))
        result.supportsSpendingIntent = supportsSpendingIntent
        if supportsSpendingIntent {
            result.spendingContexts = contexts
            let stored = try spendingRows.map { row -> (String, TransactionSpendingIntent) in
                guard let id = row.string(at: 0), !id.isEmpty,
                      let kind = TransactionSpendingIntent.Kind(rawValue: row.string(at: 1) ?? "") else { throw CategoryAutomationError.invalidState }
                let matches = try JSONDecoder().decode([CategoryRuleMatch].self, from: Data((row.string(at: 2) ?? "").utf8))
                let intent = TransactionSpendingIntent(kind: kind, matches: matches)
                try intent.validate()
                return (id, intent)
            }
            guard Set(stored.map(\.0)).count == stored.count else { throw CategoryAutomationError.invalidState }
            for (id, _) in stored {
                guard trusted[id] != nil, contexts[id]?.sourceEligible == true else { throw CategoryAutomationError.invalidState }
            }
            result.spendingIntents = Dictionary(uniqueKeysWithValues: stored)
        }
        return result
    }
}

/// This RAM-only witness binds a previously validated complete runtime to its
/// exact provider, database handle and full retained source graph.
nonisolated struct CategorySourceBinding: Equatable, Sendable {
    let provider: ObjectIdentifier
    let database: ObjectIdentifier
    let generation: ProviderGenerationToken
    let workspaceID: String
}
nonisolated struct CategorySourceWitness: Equatable, Sendable {
    private enum Basis: Sendable { case pending(CategorySourceRows), compact(Data) }
    let binding: CategorySourceBinding
    private let cutID: UUID
    private let basis: Basis

    init(binding: CategorySourceBinding, source: CategorySourceRows) {
        self.binding = binding; cutID = UUID(); basis = .pending(source)
    }
    private init(binding: CategorySourceBinding, cutID: UUID, digest: Data) {
        self.binding = binding; self.cutID = cutID; basis = .compact(digest)
    }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.binding == rhs.binding && lhs.cutID == rhs.cutID }
    var isCompact: Bool { if case .compact = basis { return true }; return false }
    fileprivate func fingerprint() throws -> Data {
        switch basis { case .pending(let source): return try source.fingerprint(); case .compact(let digest): return digest }
    }
    fileprivate func compacted(digest: Data) -> Self { Self(binding: binding, cutID: cutID, digest: digest) }
}

nonisolated struct CategorySourceRows: Sendable {
    struct Table: Sendable {
        let name: String
        let columns: [String]
        let rows: [SQLiteRow]
    }
    let schema: [SQLiteRow]
    let tables: [Table]
    static let sourceTables = """
        account_balance_snapshots account_identifier_observations account_identifiers accounts
        bank_section_identity_observations bank_statement_sections bank_transaction_occurrences card_instrument_identifiers
        card_instrument_relationships card_instruments card_source_identity_observations card_statement_section_observations
        card_statement_sections card_statement_semantic_groups card_statement_semantic_members card_statement_semantic_projection_events
        card_statement_semantic_projection_sections card_statement_semantic_projections card_statement_summary_components card_statements
        card_transaction_evidence cbq_source_identity_observations currencies document_fingerprints
        documents exchange_rates funding_plan_al_dar_references funding_plan_balances
        funding_plan_commitments funding_plan_deduction_components funding_plan_effective_al_dar_references funding_plans
        import_attempts import_sessions incoming_row_dispositions institutions
        intelligence_preferences investment_containers investment_holdings monthly_plan_scratchpads
        movement_events movement_legs net_worth_exclusions normalized_documents
        normalized_rows partial_import_summaries plan_assistance recurring_definitions
        recurring_occurrences reserve_designations salary_assistance salary_components
        salary_statements schema_migrations statement_equivalence_groups statement_equivalence_members
        statement_financial_projection_events statement_financial_projections statement_source_observations statement_zero_activity_controls
        transaction_event_identities transaction_raw_rows transaction_source_observations transactions
        validation_issues workspaces
        """.split(whereSeparator: \.isWhitespace).map(String.init).sorted()
    static let otherTables = """
        categories category_rules transaction_category_assignments transaction_category_intent
        category_import_work transaction_spending_intent attachments background_al_dar_reference_cache
        background_investment_quote_cache background_public_progress background_schedule_configuration background_update_receipts
        companion_month_sync companion_sync_sessions fts_transactions gmail_inbox_state
        gmail_originals tag_definitions transaction_tag_memberships
        """.split(whereSeparator: \.isWhitespace).map(String.init)

    fileprivate struct TableColumns: Sendable {
        let name: String
        let columns: [String]
    }
    fileprivate struct Descriptor: Sendable {
        let schema: [SQLiteRow]
        let tables: [TableColumns]
    }

    /// Full hydration still captures its entire cut synchronously. Worker
    /// preparation calls the same descriptor/table readers in guarded slices.
    static func capture(_ db: SQLiteDatabase) throws -> Self? {
        guard let descriptor = try descriptor(db) else { return nil }
        return try Self(schema: descriptor.schema, tables: descriptor.tables.map { try captureTable(db, $0) })
    }

    fileprivate static func descriptor(_ db: SQLiteDatabase) throws -> Descriptor? {
        let schemaVersion = try db.query(sql: "SELECT MAX(version) FROM schema_migrations;") { $0.int64(at: 0) ?? 0 }.first
        guard schemaVersion == 34 else { return nil }
        let names = try db.query(sql: "SELECT name FROM sqlite_schema WHERE type='table';") { $0.string(at: 0) ?? "" }
            .filter { !$0.hasPrefix("sqlite_") }
        guard Set(names) == Set(sourceTables + otherTables) else { return nil }
        let schema = try db.query(sql: "SELECT CAST(type AS BLOB),CAST(name AS BLOB),CAST(tbl_name AS BLOB),CAST(sql AS BLOB) FROM sqlite_schema WHERE name NOT GLOB 'sqlite_*' ORDER BY type,name;") { $0 }
        let tables = try sourceTables.map { name in
            let columns = try db.query(sql: "PRAGMA table_info(\(quoted(name)));") { $0.string(at: 1) ?? "" }
            guard !columns.isEmpty, !columns.contains(""), Set(columns).count == columns.count else { throw CategoryAutomationError.invalidState }
            return TableColumns(name: name, columns: columns)
        }
        return Descriptor(schema: schema, tables: tables)
    }

    /// Every column keeps SQLite type and complete bytes, including embedded NULs.
    fileprivate static func captureTable(_ db: SQLiteDatabase, _ table: TableColumns) throws -> Table {
        let selection = table.columns.flatMap { column -> [String] in
            let value = quoted(column)
            return ["typeof(\(value))", "CASE WHEN typeof(\(value))='real' THEN CAST(printf('%!.26g',\(value)) AS BLOB) ELSE CAST(\(value) AS BLOB) END"]
        }.joined(separator: ",")
        return Table(name: table.name, columns: table.columns,
            rows: try db.query(sql: "SELECT \(selection) FROM \(quoted(table.name));") { $0 })
    }

    private static func quoted(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }

    /// Called after releasing all read ownership. Fixed row digests sort with
    /// multiplicity intact; schema, column inventory, type and byte length are
    /// framed independently, so equal counts cannot stand in for equal facts.
    func fingerprint() throws -> Data {
        func frame(_ bytes: Data?, into hash: inout SHA256) {
            hash.update(data: Data([bytes == nil ? 0 : 1]))
            guard let bytes else { return }
            var length = UInt64(bytes.count).bigEndian
            withUnsafeBytes(of: &length) { hash.update(data: Data($0)) }
            hash.update(data: bytes)
        }
        var total = SHA256()
        frame(Data("ledgerforge.category-source-witness.v1".utf8), into: &total)
        frame(Data(String(schema.count).utf8), into: &total)
        for row in schema { for column: Int32 in 0..<4 { frame(row.data(at: column), into: &total) } }
        frame(Data(String(tables.count).utf8), into: &total)
        for table in tables {
            frame(Data(table.name.utf8), into: &total)
            frame(Data(String(table.columns.count).utf8), into: &total)
            for column in table.columns { frame(Data(column.utf8), into: &total) }
            frame(Data(String(table.rows.count).utf8), into: &total)
            var rowDigests: [Data] = []
            rowDigests.reserveCapacity(table.rows.count)
            for row in table.rows {
                var hash = SHA256()
                for index in table.columns.indices {
                    guard let type = row.string(at: Int32(index * 2)), ["null", "integer", "real", "text", "blob"].contains(type) else { throw CategoryAutomationError.invalidState }
                    let bytes = row.data(at: Int32(index * 2 + 1))
                    guard (type == "null") == (bytes == nil) else { throw CategoryAutomationError.invalidState }
                    frame(Data(type.utf8), into: &hash)
                    frame(bytes, into: &hash)
                }
                rowDigests.append(Data(hash.finalize()))
            }
            for digest in rowDigests.sorted(by: { $0.lexicographicallyPrecedes($1) }) { frame(digest, into: &total) }
        }
        return Data(total.finalize())
    }
}

#if !BACKGROUND_WORKER && !SUBPROCESS_PROBE
/// A same-handle DDL change does not increment SQLite's row-change counter.
/// Pair both counters for every released/reacquired capture and publication cut.
nonisolated fileprivate struct CategoryReadStamp: Equatable, Sendable {
    let changes: Int64
    let schema: Int64

    static func read(_ database: SQLiteDatabase) throws -> Self {
        let changes = try database.totalChangeCounter()
        let schemaRows = try database.query(sql: "PRAGMA schema_version;") { $0.int64(at: 0) }
        guard let schema = schemaRows.first ?? nil else { throw CategoryAutomationError.invalidState }
        return Self(changes: changes, schema: schema)
    }
}

/// Purpose-specific Sendable request: no actor-bound provider/repository crosses
/// an await. Existing audited locks own every access to the live SQLite handle.
nonisolated struct CategoryOverrideReadRequest: Sendable {
    let database: SQLiteDatabase
    let validity: ProviderGenerationValidity
    let binding: CategorySourceBinding

    func sourceRows() throws -> CategorySourceRows? {
        try validity.withValidOperation { try database.withExclusiveAccess { try CategorySourceRows.capture(database) } }
    }

    struct Prepared: Sendable {
        let snapshot: CategorySnapshot
        let witness: CategorySourceWitness
        fileprivate let stamp: CategoryReadStamp
        fileprivate let inputs: [String: CategoryRuleInput]
        fileprivate init(snapshot: CategorySnapshot, stamp: CategoryReadStamp, witness: CategorySourceWitness,
                         inputs: [String: CategoryRuleInput]) {
            self.snapshot = snapshot; self.stamp = stamp; self.witness = witness; self.inputs = inputs
        }
    }
    private struct Raw: Sendable {
        let source: CategorySourceRows
        let metadata: CategoryMetadataReadRows
        let transactions: SQLiteTransactionReadRows
        let accounts, movements: [SQLiteRow]
        let stamp: CategoryReadStamp
    }

    /// The caller holds generation/ledger/connection ownership while checking.
    func requireCurrent(_ prepared: Prepared) throws {
        guard prepared.witness.binding == binding,
              try CategoryReadStamp.read(database) == prepared.stamp else { throw CategoryAutomationError.stalePreview }
    }

    func prepare(expected: CategorySourceWitness) async throws -> Prepared {
        try await prepareCaptured(expected: expected, betweenCaptureSlices: nil)
    }

#if DEBUG
    /// Deterministic nonfinancial interference controls run only after ALL
    /// ownership scopes have ended; no actor callback can run under a read lock.
    func prepare(expected: CategorySourceWitness,
                 betweenCaptureSlices: @escaping @Sendable (Int) async throws -> Void) async throws -> Prepared {
        try await prepareCaptured(expected: expected, betweenCaptureSlices: betweenCaptureSlices)
    }
#endif

    private func slice<T>(expected: CategoryReadStamp? = nil, _ body: () throws -> T) throws -> (T, CategoryReadStamp) {
        try validity.withValidOperation {
            try database.withExclusiveAccess {
#if DEBUG
                // Each span is one actually-held slice. Native reports retain
                // its maximum as well as the sum and complete mutation wall time.
                let timing = GmailQualificationTiming.begin(.categoryOverrideCapture)
                defer { GmailQualificationTiming.end(.categoryOverrideCapture, started: timing) }
#endif
                let stamp = try CategoryReadStamp.read(database)
                if let expected, stamp != expected { throw CategoryAutomationError.stalePreview }
                let result = try body()
                guard try CategoryReadStamp.read(database) == stamp else { throw CategoryAutomationError.stalePreview }
                return (result, stamp)
            }
        }
    }

    private func prepareCaptured(expected: CategorySourceWitness,
                                 betweenCaptureSlices: (@Sendable (Int) async throws -> Void)?) async throws -> Prepared {
        guard binding == expected.binding else { throw CategoryAutomationError.stalePreview }
        try Task.checkCancellation()
        let (descriptor, stamp) = try slice {
            guard let descriptor = try CategorySourceRows.descriptor(database) else { throw CategoryAutomationError.unavailable }
            return descriptor
        }
        var tables: [CategorySourceRows.Table] = []
        for (index, table) in descriptor.tables.enumerated() {
            try await betweenCaptureSlices?(index)
            await Task.yield()
            try Task.checkCancellation()
            tables.append(try slice(expected: stamp) { try CategorySourceRows.captureTable(database, table) }.0)
        }
        try await betweenCaptureSlices?(descriptor.tables.count)
        await Task.yield()
        try Task.checkCancellation()
        let raw = try slice(expected: stamp) {
            let metadata = try CategoryMetadataReadRows.capture(database, workspaceID: binding.workspaceID, supportsSpendingIntent: true)
            let transactions = try SQLiteTransactionRepo.captureRows(database, scope: "t.workspace_id=? AND t.is_trusted=1", params: [binding.workspaceID], ordered: false)
            let accounts = try database.query(sql: "SELECT id, workspace_id, name, institution_id, account_type, native_currency, description, created_at, closed_at FROM accounts WHERE workspace_id=?;", params: [binding.workspaceID]) { $0 }
            let movements = try database.query(sql: "SELECT id,decision,event_json FROM movement_events WHERE workspace_id=?;", params: [binding.workspaceID]) { $0 }
            return Raw(source: CategorySourceRows(schema: descriptor.schema, tables: tables), metadata: metadata,
                transactions: transactions, accounts: accounts, movements: movements, stamp: stamp)
        }.0
#if DEBUG
        let timing = GmailQualificationTiming.begin(.categoryOverrideDecode)
        defer { GmailQualificationTiming.end(.categoryOverrideDecode, started: timing) }
#endif
        let digest = try expected.fingerprint()
        guard try raw.source.fingerprint() == digest else { throw CategoryAutomationError.stalePreview }
        let transactions = raw.transactions.decode()
        let accounts = raw.accounts.map(SQLiteAccountRepo.decodeAccount)
        // The complete source graph is byte-identical to the fully validated
        // canonical graph. Decode current movement JSON with the ordinary row
        // guards; never reuse the earlier runtime's spending contexts.
        let movements = try raw.movements.map { try SQLiteFinancialIntelligenceRepository.decodeMovement($0, workspaceID: binding.workspaceID, supportsRefundAllocations: true) }
        let trusted = try raw.metadata.trustedImportSessions()
        guard transactions.count == trusted.count, Set(transactions.map(\.id)).count == transactions.count,
              transactions.allSatisfy({ $0.isTrusted && $0.workspaceId == binding.workspaceID && trusted[$0.id] == ($0.importSessionId ?? "") }),
              Set(accounts.map(\.id)).count == accounts.count,
              accounts.allSatisfy({ $0.workspaceId == binding.workspaceID }) else { throw CategoryAutomationError.invalidState }
        let contexts = try CategorySpendingFacts.contexts(transactions: transactions, accounts: accounts, movements: movements, profiles: CategorySpendingFacts.profiles)
        var snapshot = try RepositoryStoreHydrator.categorySnapshot(categories: raw.metadata.categories(), assignments: raw.metadata.assignments(), trustedTransactionIDs: Set(trusted.keys), workspaceID: binding.workspaceID)
        snapshot.automation = try raw.metadata.decodeAutomation(workspaceID: binding.workspaceID, supportsSpendingIntent: true, contexts: contexts)
        snapshot.providerGeneration = binding.generation
        let inputs = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, CategoryRuleInput(transaction: $0)) })
        try Task.checkCancellation()
        return Prepared(snapshot: snapshot, stamp: raw.stamp, witness: expected.compacted(digest: digest), inputs: inputs)
    }
}

/// Minted only by an actual current SQLite provider. The actor-bound provider
/// remains with its coordinator; this immutable request owns no runtime store.
nonisolated struct CategoryApplyWriteRequest: Sendable {
    let read: CategoryOverrideReadRequest

    func apply(_ evaluation: CategoryEvaluation, historical: Bool, prepared: CategoryOverrideReadRequest.Prepared,
               expected: CategorySourceWitness, canonical: CategorySnapshot) throws -> Int {
        try applyWithReceipt(evaluation, historical: historical, prepared: prepared, expected: expected,
                             canonical: canonical).changedIDs.count
    }

    func applyWithReceipt(_ evaluation: CategoryEvaluation, historical: Bool, prepared: CategoryOverrideReadRequest.Prepared,
                          expected: CategorySourceWitness, canonical: CategorySnapshot,
                          review: CategoryHistoricalPreview? = nil) throws -> CategoryApplyReceipt {
        guard expected.binding == read.binding, prepared.witness == expected,
              canonical.providerGeneration == read.binding.generation,
              prepared.snapshot.providerGeneration == read.binding.generation,
              prepared.snapshot.categories == canonical.categories,
              prepared.snapshot.automation?.rules == canonical.automation?.rules,
              let current = prepared.snapshot.automation else { throw CategoryAutomationError.stalePreview }
        try Task.checkCancellation()
        return try read.validity.withValidOperation {
            try read.database.withExclusiveAccess {
#if DEBUG
                let timing = GmailQualificationTiming.begin(.categoryApply, count: evaluation.decisions.count)
                defer { GmailQualificationTiming.end(.categoryApply, started: timing, count: evaluation.decisions.count) }
#endif
                try read.database.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
                do {
                    // Begin first, so another connection cannot commit between
                    // this freshness check and any metadata write in the batch.
                    try read.requireCurrent(prepared)
                    try Task.checkCancellation()
                    let changed = try CategorySQLiteApply.apply(evaluation, database: read.database,
                        workspaceId: read.binding.workspaceID, historical: historical, current: current,
                        inputs: prepared.inputs, active: Set(prepared.snapshot.activeCategories.map(\.id)),
                        assigned: prepared.snapshot.assignments, review: review)
                    try Task.checkCancellation()
                    try read.database.execute(sql: "COMMIT;")
                    // No cancellation check or refresh can hide this successful
                    // commit. The coordinator receives its exact result first.
                    return changed
                } catch {
                    try? read.database.execute(sql: "ROLLBACK;")
                    throw error
                }
            }
        }
    }
}
#endif
