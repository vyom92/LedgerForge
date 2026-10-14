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
    let supportsRefundAllocations: Bool
    init(db: SQLiteDatabase, supportsBalanceDates: Bool = true, supportsRefundAllocations: Bool = false) {
        self.db = db; self.supportsBalanceDates = supportsBalanceDates
        self.supportsRefundAllocations = supportsRefundAllocations
    }

    func snapshot(workspaceID: String) throws -> FinancialIntelligenceSnapshot? {
        try snapshot(workspaceID: workspaceID, replacingPlan: nil)
    }

    func snapshot(workspaceID: String, replacingPlan: FundingPlanDTO?) throws -> FinancialIntelligenceSnapshot? {
        try db.withExclusiveAccess {
            let events = try db.query(sql: "SELECT id,decision,event_json FROM movement_events WHERE workspace_id=? ORDER BY id;", params: [workspaceID]) { row in
                try Self.decodeMovement(row, workspaceID: workspaceID, supportsRefundAllocations: supportsRefundAllocations)
            }
            var observedLegs: [String: String] = [:]
            let facts = try canonicalFacts(ids: Set(events.flatMap(\.transactionIDs)), workspaceID: workspaceID)
            let accounts = try SQLiteAccountRepo(db: db, supportsBankSections: true).accounts(workspaceId: workspaceID)
            let sources = try Self.refundSourceFacts(db, ids: Set(events.filter { $0.refundAllocations != nil }.flatMap(\.transactionIDs)), workspaceID: workspaceID)
            for event in events {
                try MovementValidation.validate(event, facts: event.transactionIDs.compactMap { facts[$0] }, accounts: accounts)
                try RefundSourceValidation.validate(event, sources: sources)
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

    nonisolated static func decodeMovement(_ row: SQLiteRow, workspaceID: String, supportsRefundAllocations: Bool) throws -> MovementEvent {
        guard let data = row.string(at: 2)?.data(using: .utf8) else { throw FinancialIntelligenceError.invalidRecord }
        let value = try JSONDecoder().decode(MovementEvent.self, from: data)
        guard supportsRefundAllocations || value.refundAllocations == nil else { throw FinancialIntelligenceError.unavailable }
        guard value.id == row.string(at: 0), value.workspaceID == workspaceID, value.decision.rawValue == row.string(at: 1) else { throw FinancialIntelligenceError.invalidRecord }
        return value
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
        guard supportsRefundAllocations || event.refundAllocations == nil else { throw FinancialIntelligenceError.unavailable }
        let facts = try canonicalFacts(ids: Set(event.transactionIDs), workspaceID: event.workspaceID)
        let accounts = try SQLiteAccountRepo(db: db, supportsBankSections: true).accounts(workspaceId: event.workspaceID)
        try MovementValidation.validate(event, facts: Array(facts.values), accounts: accounts)
        if event.refundAllocations != nil {
            try RefundSourceValidation.validate(event, sources: Self.refundSourceFacts(db, ids: Set(event.transactionIDs), workspaceID: event.workspaceID))
        }
    }

    func canonicalFacts(ids: Set<String>, workspaceID: String) throws -> [String: MovementValidation.Fact] {
        try Self.canonicalFacts(db, ids: ids, workspaceID: workspaceID)
    }

    nonisolated private static func canonicalFacts(_ db: SQLiteDatabase, ids: Set<String>, workspaceID: String) throws -> [String: MovementValidation.Fact] {
        let ordered = ids.sorted()
        var result: [String: MovementValidation.Fact] = [:]
        for start in stride(from: 0, to: ordered.count, by: 500) {
            let batch = Array(ordered[start..<min(start + 500, ordered.count)])
            let placeholders = batch.map { _ in "?" }.joined(separator: ",")
            let values = try db.query(sql: "SELECT id,workspace_id,account_id,native_currency,direction,amount_minor,is_trusted,posted_date,amount_decimal FROM transactions WHERE workspace_id=? AND id IN (\(placeholders));", params: [workspaceID] + batch) { row -> MovementValidation.Fact in
                guard let id = row.string(at: 0), let workspace = row.string(at: 1), let account = row.string(at: 2),
                      let currency = row.string(at: 3), let direction = row.string(at: 4), let amount = row.int64(at: 5) else { throw FinancialIntelligenceError.invalidRecord }
                return .init(id: id, workspaceID: workspace, accountID: account, currency: currency, direction: direction, amountMinor: amount, trusted: row.int64(at: 6) == 1, financialDate: row.string(at: 7).map { String($0.prefix(10)) }, amountDecimal: row.string(at: 8))
            }
            for value in values { result[value.id] = value }
        }
        return result
    }

    /// Backup verification owns a sealed database, without a runtime provider
    /// or main-actor repository. Reuse the same financial validator off-thread.
    nonisolated static func verifyBackupContents(_ db: SQLiteDatabase, supportsRefundAllocations: Bool) throws {
        try db.withExclusiveAccess {
            let events = try db.query(sql: "SELECT id,workspace_id,decision,event_json FROM movement_events ORDER BY id;") { row -> MovementEvent in
                guard let data = row.string(at: 3)?.data(using: .utf8) else { throw FinancialIntelligenceError.invalidRecord }
                let event = try JSONDecoder().decode(MovementEvent.self, from: data)
                guard event.id == row.string(at: 0), event.workspaceID == row.string(at: 1),
                      event.decision.rawValue == row.string(at: 2),
                      supportsRefundAllocations || event.refundAllocations == nil else { throw FinancialIntelligenceError.invalidRecord }
                return event
            }
            let accounts = try db.query(sql: "SELECT id,workspace_id,name,institution_id,account_type,native_currency,description,created_at,closed_at FROM accounts ORDER BY id;") { row -> AccountDTO in
                guard let id = row.string(at: 0), let workspace = row.string(at: 1), let name = row.string(at: 2),
                      let currency = row.string(at: 5), let created = row.string(at: 7) else { throw FinancialIntelligenceError.invalidRecord }
                return .init(id: id, workspaceId: workspace, name: name, institutionId: row.string(at: 3),
                    accountType: row.string(at: 4), nativeCurrency: currency, description: row.string(at: 6),
                    createdAtISO: created, closedAtISO: row.string(at: 8))
            }
            var observed: [String: String] = [:]
            for (workspace, values) in Dictionary(grouping: events, by: \.workspaceID) {
                let facts = try canonicalFacts(db, ids: Set(values.flatMap(\.transactionIDs)), workspaceID: workspace)
                let sources = try refundSourceFacts(db, ids: Set(values.filter { $0.refundAllocations != nil }.flatMap(\.transactionIDs)), workspaceID: workspace)
                for event in values {
                    try MovementValidation.validate(event, facts: event.transactionIDs.compactMap { facts[$0] }, accounts: accounts)
                    try RefundSourceValidation.validate(event, sources: sources)
                    for id in event.transactionIDs where event.decision == .confirmed {
                        guard observed.updateValue(event.id, forKey: id) == nil else { throw FinancialIntelligenceError.occupiedLeg }
                    }
                }
            }
            let stored = try db.query(sql: "SELECT transaction_id,event_id FROM movement_legs ORDER BY transaction_id;") { row -> (String, String) in
                guard let transaction = row.string(at: 0), let event = row.string(at: 1) else { throw FinancialIntelligenceError.invalidRecord }
                return (transaction, event)
            }
            guard Set(stored.map(\.0)).count == stored.count,
                  Dictionary(uniqueKeysWithValues: stored) == observed else { throw FinancialIntelligenceError.invalidRecord }
        }
    }

    /// Read only the actual allocation legs. Ordering matches canonical hydration:
    /// card date, preferred source date, first raw provenance date, statement date.
    nonisolated private static func refundSourceFacts(_ db: SQLiteDatabase, ids: Set<String>, workspaceID: String) throws -> [String: RefundSourceValidation.Fact] {
        let ordered = ids.sorted()
        var result: [String: RefundSourceValidation.Fact] = [:]
        for start in stride(from: 0, to: ordered.count, by: 500) {
            let batch = Array(ordered[start..<min(start + 500, ordered.count)])
            let placeholders = batch.map { _ in "?" }.joined(separator: ",")
            let params: [Any?] = [workspaceID] + batch
            let scope = "t.workspace_id=? AND t.id IN (\(placeholders))"
            let transactions = try db.query(sql: "SELECT t.id,a.account_type,t.description,t.posted_date FROM transactions t JOIN accounts a ON a.id=t.account_id AND a.workspace_id=t.workspace_id WHERE \(scope);", params: params) { row in
                (try RefundSourceValidation.required(row.string(at: 0)),
                 try RefundSourceValidation.required(row.string(at: 1)), row.string(at: 2) ?? "",
                 try RefundSourceValidation.required(row.string(at: 3)))
            }
            let links = try db.query(sql: """
                SELECT trr.transaction_id,trr.normalized_row_id,nr.normalized_document_id,nr.row_index,
                       nr.record_digest,nd.profile_id,nd.profile_version,b.source_transaction_date
                FROM transaction_raw_rows trr JOIN transactions t ON t.id=trr.transaction_id
                LEFT JOIN normalized_rows nr ON nr.id=trr.normalized_row_id
                LEFT JOIN normalized_documents nd ON nd.id=nr.normalized_document_id
                LEFT JOIN bank_transaction_occurrences b ON b.normalized_row_id=trr.normalized_row_id AND b.canonical_transaction_id=t.id
                WHERE \(scope) ORDER BY trr.transaction_id ASC,nr.row_index ASC,trr.id ASC;
                """, params: params) { row in
                (try RefundSourceValidation.required(row.string(at: 0)),
                 try RefundSourceValidation.Provenance(rowID: row.string(at: 1), documentID: row.string(at: 2),
                    ordinal: row.int64(at: 3), digest: row.string(at: 4), profile: row.string(at: 5),
                    version: row.string(at: 6), date: row.string(at: 7)))
            }
            var provenance: [String: [RefundSourceValidation.Provenance]] = [:]
            for (id, source) in links { provenance[id, default: []].append(source) }
            let cards = try db.query(sql: "SELECT c.transaction_id,c.source_transaction_date,c.summary_membership_code FROM card_transaction_evidence c JOIN transactions t ON t.id=c.transaction_id WHERE \(scope);", params: params) { row in
                (try RefundSourceValidation.required(row.string(at: 0)),
                 try RefundSourceValidation.required(row.string(at: 1)), row.string(at: 2))
            }
            var cardByID: [String: (date: String, membership: String?)] = [:]
            for (id, date, membership) in cards {
                guard cardByID.updateValue((date, membership), forKey: id) == nil else { throw FinancialIntelligenceError.invalidRecord }
            }
            let preferred = try db.query(sql: """
                SELECT o.canonical_transaction_id,o.source_transaction_date FROM transaction_source_observations o
                JOIN statement_source_observations s ON s.document_id=o.document_id
                JOIN transactions t ON t.id=o.canonical_transaction_id WHERE \(scope)
                ORDER BY o.canonical_transaction_id,CASE s.source_format_code WHEN 'monthly-pdf' THEN 3 WHEN 'history-pdf' THEN 2 ELSE 1 END DESC,o.created_at DESC,o.document_id;
                """, params: params) { row in
                (try RefundSourceValidation.required(row.string(at: 0)), row.string(at: 1))
            }
            var seen = Set<String>(), preferredDates: [String: String] = [:]
            for (id, date) in preferred where seen.insert(id).inserted {
                // A preferred observation with no explicit date still wins its
                // selection; do not substitute a lower-priority observation.
                preferredDates[id] = date
            }
            for (id, domain, narration, postedDate) in transactions {
                result[id] = try RefundSourceValidation.fact(domain: domain, narration: narration, postedDate: postedDate,
                    provenance: provenance[id] ?? [], cardDate: cardByID[id]?.date,
                    preferredDate: preferredDates[id], summaryMembership: cardByID[id]?.membership)
            }
        }
        guard Set(result.keys) == ids else { throw FinancialIntelligenceError.invalidRecord }
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
        guard event.refundAllocations != nil else { return }
        let ids = Set(event.transactionIDs)
        var preferred: [String: (priority: Int, date: String?)] = [:]
        // Match InMemoryImportSessionRepo exactly, including first selection on
        // equal priority and a selected nil date. The state lock is already held.
        for reviewed in state.cbqReviewedSourcePlans.values where reviewed.basePlan.workspace.id == event.workspaceID {
            guard let format = reviewed.basePlan.cbqStatementSourceEvidence?.sourceFormatCode else { continue }
            let priority = format == "monthly-pdf" ? 3 : (format == "history-pdf" ? 2 : 1)
            for row in reviewed.rows {
                let id = row.disposition == .new ? row.source.incomingTransactionId : row.expectedTransactionId
                guard let id, ids.contains(id) else { continue }
                if preferred[id]?.priority ?? 0 < priority { preferred[id] = (priority, row.source.sourceTransactionDateISO) }
            }
        }
        var occurrences: [String: BankTransactionOccurrencePlanDTO] = [:]
        let rawIDs = Set(event.transactionIDs.flatMap { state.transactions[$0]?.rawRows.map(\.normalizedRowId) ?? [] })
        for section in state.bankSectionPlans.values where state.accounts[section.accountId]?.workspaceId == event.workspaceID {
            for row in section.rows where rawIDs.contains(row.normalizedRowId) {
                guard occurrences.updateValue(row, forKey: row.normalizedRowId) == nil else { throw FinancialIntelligenceError.invalidRecord }
            }
        }
        var cards: [String: CardTransactionEvidenceDTO] = [:]
        for card in state.cardTransactionEvidence.values where ids.contains(card.transactionId) {
            guard cards.updateValue(card, forKey: card.transactionId) == nil else { throw FinancialIntelligenceError.invalidRecord }
        }
        var sources: [String: RefundSourceValidation.Fact] = [:]
        for id in event.transactionIDs {
            guard let transaction = state.transactions[id], let accountID = transaction.accountId,
                  let domain = state.accounts[accountID]?.accountType else { throw FinancialIntelligenceError.invalidRecord }
            // In-memory hydration preserves the accepted rawRows order.
            let provenance = try transaction.rawRows.map { raw -> RefundSourceValidation.Provenance in
                let row = state.normalizedRows[raw.normalizedRowId]
                let document = row.flatMap { state.normalizedDocuments[$0.normalizedDocumentId] }
                return try .init(rowID: raw.normalizedRowId, documentID: row?.normalizedDocumentId,
                    ordinal: row.map { Int64($0.sourceOrdinal) }, digest: row?.digest,
                    profile: document?.profileId, version: document?.profileVersion,
                    date: occurrences[raw.normalizedRowId]?.source.sourceTransactionDateISO)
            }
            sources[id] = try RefundSourceValidation.fact(domain: domain, narration: transaction.description ?? "",
                postedDate: transaction.postedDateISO, provenance: provenance,
                cardDate: cards[id]?.sourceTransactionDateISO, preferredDate: preferred[id]?.date,
                summaryMembership: cards[id]?.summaryMembershipCode)
        }
        try RefundSourceValidation.validate(event, sources: sources)
    }
}

/// New allocation metadata may never reserve source-excluded legs or dates
/// that cannot support original-purchase attribution. Historical nil metadata
/// retains its existing validation and remains reviewable without reinterpretation.
nonisolated private enum RefundSourceValidation {
    struct Fact {
        let date: StatementDate
        let isLoanOrEMI: Bool
    }
    struct Provenance {
        let rowID: String, documentID: String, digest: String, profile: String, version: String
        let ordinal: Int64
        let date: StatementDate?
        init(rowID: String?, documentID: String?, ordinal: Int64?, digest: String?, profile: String?, version: String?, date: String?) throws {
            self.rowID = try RefundSourceValidation.required(rowID); self.documentID = try RefundSourceValidation.required(documentID)
            guard let ordinal, ordinal > 0 else { throw FinancialIntelligenceError.invalidRecord }
            self.ordinal = ordinal; self.digest = try RefundSourceValidation.required(digest)
            self.profile = try RefundSourceValidation.required(profile); self.version = try RefundSourceValidation.required(version)
            self.date = try date.map { try StatementDate(canonical: $0) }
        }
    }
    static func required(_ value: String?) throws -> String {
        guard let value, !value.isEmpty else { throw FinancialIntelligenceError.invalidRecord }
        return value
    }
    static func fact(domain: String, narration: String, postedDate: String, provenance: [Provenance],
                     cardDate: String?, preferredDate: String?, summaryMembership: String?) throws -> Fact {
        guard !provenance.isEmpty, Set(provenance.map(\.rowID)).count == provenance.count,
              domain != "credit_card" || cardDate != nil else { throw FinancialIntelligenceError.invalidRecord }
        for rows in Dictionary(grouping: provenance, by: \.documentID).values {
            guard Set(rows.map(\.ordinal)).count == rows.count,
                  Set(rows.map { "\($0.profile)|\($0.version)" }).count == 1 else { throw FinancialIntelligenceError.invalidRecord }
        }
        let membership = try summaryMembership.map { value in
            guard let result = CardTransactionSummaryMembership(rawValue: value) else { throw FinancialIntelligenceError.invalidRecord }
            return result
        }
        let statement = try StatementDate(canonical: postedDate)
        let card = try cardDate.map { try StatementDate(canonical: $0) }
        let preferred = try preferredDate.map { try StatementDate(canonical: $0) }
        return .init(date: card ?? preferred ?? provenance.first?.date ?? statement,
            isLoanOrEMI: SpendingSourcePolicy.isLoanOrEMI(domain: domain, narration: narration,
                parserProfileIDs: Set(provenance.map(\.profile)), summaryMembership: membership))
    }
    static func validate(_ event: MovementEvent, sources: [String: Fact]) throws {
        guard let allocations = event.refundAllocations else { return }
        guard event.transactionIDs.allSatisfy({ sources[$0]?.isLoanOrEMI == false }) else { throw FinancialIntelligenceError.invalidLegs }
        for allocation in allocations {
            guard let purchase = sources[allocation.purchaseTransactionID], let credit = sources[allocation.creditTransactionID],
                  credit.date >= purchase.date else { throw FinancialIntelligenceError.invalidLegs }
        }
    }
}
