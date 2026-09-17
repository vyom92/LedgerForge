import Foundation

final class SQLiteInvestmentRepository: InvestmentRepository {
    private let db: SQLiteDatabase
    private let generationToken: ProviderGenerationToken
    private let supportsDirectSources: Bool

    init(db: SQLiteDatabase, generationToken: ProviderGenerationToken) {
        self.db = db
        self.generationToken = generationToken
        self.supportsDirectSources = ((try? db.query(sql: "PRAGMA table_info(investment_containers);") { $0.string(at: 1) }) ?? []).contains("source_kind")
    }

    func snapshot(workspaceID: String) throws -> InvestmentSnapshot {
        try db.withExclusiveAccess {
            let containers = try db.query(sql: """
                SELECT c.id, c.record_json, c.document_id, c.import_session_id,
                       d.workspace_id, d.import_session_id, s.workspace_id, s.validation_status,
                       \(supportsDirectSources ? "c.source_kind" : "'statement'")
                FROM investment_containers c
                LEFT JOIN documents d ON d.id = c.document_id
                LEFT JOIN import_sessions s ON s.id = c.import_session_id
                WHERE c.workspace_id = ? ORDER BY c.id;
                """, params: [workspaceID]) { row -> InvestmentContainer in
                    let value = try self.decode(InvestmentContainer.self, row.string(at: 1))
                    guard value.id == row.string(at: 0), value.workspaceID == workspaceID,
                          value.documentID == row.string(at: 2), value.importSessionID == row.string(at: 3) else {
                        throw InvestmentError.invalidPersistedState
                    }
                    if value.zioSource != nil {
                        guard row.string(at: 8) == "zurich-zio", value.documentID == nil, value.importSessionID == nil else {
                            throw InvestmentError.invalidPersistedState
                        }
                    } else {
                        guard row.string(at: 8) == "statement", row.string(at: 4) == workspaceID,
                              row.string(at: 5) == value.importSessionID, row.string(at: 6) == workspaceID,
                              row.string(at: 7) == "passed" else { throw InvestmentError.invalidPersistedState }
                    }
                    return value
                }
            let holdings = try db.query(sql: """
                SELECT h.id, h.record_json, h.container_id, h.document_id, h.import_session_id,
                       h.normalized_document_id, d.workspace_id, d.import_session_id,
                       s.workspace_id, s.validation_status, n.document_id, n.import_session_id,
                       n.profile_id, n.profile_version, \(supportsDirectSources ? "h.source_kind" : "'statement'")
                FROM investment_holdings h
                JOIN investment_containers c ON c.id = h.container_id
                LEFT JOIN documents d ON d.id = h.document_id
                LEFT JOIN import_sessions s ON s.id = h.import_session_id
                LEFT JOIN normalized_documents n ON n.id = h.normalized_document_id
                WHERE c.workspace_id = ? ORDER BY h.id;
                """, params: [workspaceID]) { row -> InvestmentHolding in
                    let value = try self.decode(InvestmentHolding.self, row.string(at: 1))
                    guard value.id == row.string(at: 0), value.containerID == row.string(at: 2),
                          value.documentID == row.string(at: 3), value.importSessionID == row.string(at: 4),
                          value.normalizedDocumentID == row.string(at: 5) else { throw InvestmentError.invalidPersistedState }
                    if value.zioObservationID != nil {
                        guard row.string(at: 14) == "zurich-zio", value.documentID == nil,
                              value.importSessionID == nil, value.normalizedDocumentID == nil else {
                            throw InvestmentError.invalidPersistedState
                        }
                    } else {
                        guard row.string(at: 14) == "statement", row.string(at: 6) == workspaceID,
                              row.string(at: 7) == value.importSessionID, row.string(at: 8) == workspaceID,
                              row.string(at: 9) == "passed", row.string(at: 10) == value.documentID,
                              row.string(at: 11) == value.importSessionID, row.string(at: 12) == value.parserProfile,
                              row.string(at: 13) == "1" else { throw InvestmentError.invalidPersistedState }
                    }
                    return value
                }
            return try InvestmentSnapshot(containers: containers, holdings: holdings).validated(workspaceID: workspaceID)
        }
    }

    func commitCurrentHoldings(_ plan: InvestmentImportPlan) -> InvestmentImportRepositoryResult {
        db.withExclusiveAccess {
            guard plan.providerGeneration == generationToken else { return .staleProviderGeneration }
            do {
                try plan.validate()
                try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
                if let duplicate = try duplicate(plan) {
                    try db.execute(sql: "COMMIT;")
                    return .exactSourceDuplicate(duplicate)
                }
                let current = try snapshot(workspaceID: plan.workspace.id)
                let review = try InvestmentUpdatePlanner.review(plan, current: current)
                guard review.mappingQuestions.isEmpty else { throw InvestmentError.identityChoiceRequired }
                guard !review.requiresChoice else { throw InvestmentError.sameDateConflict }
                try insertHistory(plan)
                for container in review.snapshot.containers where review.affectedContainerIDs.contains(container.id) {
                    try replace(container, holdings: review.snapshot.holdings.filter { $0.containerID == container.id })
                }
                // Read-back validates exact decoding and relationships before commit.
                guard try snapshot(workspaceID: plan.workspace.id) == review.snapshot else { throw InvestmentError.invalidPersistedState }
                try db.execute(sql: "COMMIT;")
                return .committed(importSessionID: plan.history.importSession.id)
            } catch let error as InvestmentError {
                try? db.execute(sql: "ROLLBACK;")
                return .rejected(error)
            } catch let error as SQLiteExecutionError where error.isRetryableContention {
                try? db.execute(sql: "ROLLBACK;")
                return .retryableContention
            } catch let SQLiteDatabaseError.execution(error) where error.isRetryableContention {
                try? db.execute(sql: "ROLLBACK;")
                return .retryableContention
            } catch {
                try? db.execute(sql: "ROLLBACK;")
                return .repositoryIntegrityConflict
            }
        }
    }

    func saveZurichHoldings(_ plan: ZurichISPHoldingsPlan) -> ZurichISPHoldingsResult {
        db.withExclusiveAccess {
            guard supportsDirectSources else { return .unavailable }
            guard plan.providerGeneration == generationToken else { return .staleProviderGeneration }
            do {
                try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
                let updated = try plan.applying(to: snapshot(workspaceID: plan.workspace.id), now: Date())
                try db.executePrepared(sql: "INSERT INTO workspaces (id,name,created_at,updated_at) VALUES (?,?,?,?) ON CONFLICT(id) DO NOTHING;",
                    params: [plan.workspace.id, plan.workspace.name, plan.workspace.createdAtISO, plan.workspace.updatedAtISO])
                for container in updated.containers where plan.source.policyIDs.contains(container.identity) && container.institution == "Zurich ISP" {
                    try replace(container, holdings: updated.holdings.filter { $0.containerID == container.id })
                }
                guard try snapshot(workspaceID: plan.workspace.id) == updated else { throw InvestmentError.invalidPersistedState }
                try db.execute(sql: "COMMIT;")
                return .saved
            } catch {
                try? db.execute(sql: "ROLLBACK;")
                if let error = error as? InvestmentError { return .rejected(error) }
                if let error = error as? SQLiteExecutionError, error.isRetryableContention { return .retryableContention }
                if case SQLiteDatabaseError.execution(let execution) = error, execution.isRetryableContention { return .retryableContention }
                return .unavailable
            }
        }
    }

    private func replace(_ container: InvestmentContainer, holdings: [InvestmentHolding]) throws {
        let kindColumn = supportsDirectSources ? ",source_kind" : ""
        let kindValue = supportsDirectSources ? ",?" : ""
        let kindUpdate = supportsDirectSources ? ",source_kind=excluded.source_kind" : ""
        var containerValues: [Any?] = [container.id, container.workspaceID, container.documentID, container.importSessionID, try encode(container)]
        if supportsDirectSources { containerValues.append(container.zioSource == nil ? "statement" : "zurich-zio") }
        try db.executePrepared(sql: """
            INSERT INTO investment_containers (id,workspace_id,document_id,import_session_id,record_json\(kindColumn))
            VALUES (?,?,?,?,?\(kindValue)) ON CONFLICT(id) DO UPDATE SET
            document_id=excluded.document_id,import_session_id=excluded.import_session_id,record_json=excluded.record_json\(kindUpdate);
            """, params: containerValues)
        try db.executePrepared(sql: "DELETE FROM investment_holdings WHERE container_id=?;", params: [container.id])
        for holding in holdings {
            var values: [Any?] = [holding.id, holding.containerID, holding.documentID, holding.importSessionID,
                                  holding.normalizedDocumentID, try encode(holding)]
            if supportsDirectSources { values.append(holding.zioObservationID == nil ? "statement" : "zurich-zio") }
            try db.executePrepared(sql: """
                INSERT INTO investment_holdings (id,container_id,document_id,import_session_id,normalized_document_id,record_json\(kindColumn))
                VALUES (?,?,?,?,?,?\(kindValue));
                """, params: values)
        }
    }

    func savePriceMappings(_ plan: InvestmentPriceMappingPlan) -> InvestmentPriceMappingResult {
        db.withExclusiveAccess {
            guard plan.providerGeneration == generationToken else { return .staleProviderGeneration }
            do {
                try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
                let updated = try plan.applying(to: snapshot(workspaceID: plan.workspaceID))
                for holding in updated.holdings where plan.assignments[holding.id] != nil {
                    try db.executePrepared(sql: "UPDATE investment_holdings SET record_json=? WHERE id=? AND container_id=?;",
                        params: [try encode(holding), holding.id, holding.containerID])
                }
                guard try snapshot(workspaceID: plan.workspaceID) == updated else { throw InvestmentError.invalidPersistedState }
                try db.execute(sql: "COMMIT;")
                return .saved
            } catch {
                try? db.execute(sql: "ROLLBACK;")
                if let error = error as? InvestmentError, error == .staleReview { return .staleSnapshot }
                if let error = error as? SQLiteExecutionError, error.isRetryableContention { return .retryableContention }
                if case SQLiteDatabaseError.execution(let execution) = error, execution.isRetryableContention { return .retryableContention }
                return .unavailable
            }
        }
    }

    private func duplicate(_ plan: InvestmentImportPlan) throws -> PriorImportedStatementDTO? {
        guard let authority = plan.history.duplicateAuthorityFingerprint else { throw InvestmentError.invalidEvidence }
        return try db.query(sql: """
            SELECT f.import_session_id,s.completed_at FROM document_fingerprints f
            LEFT JOIN import_sessions s ON s.id=f.import_session_id
            WHERE f.algorithm=? AND f.fingerprint=? AND f.is_duplicate_authority=1 AND s.validation_status='passed';
            """, params: [authority.algorithm, authority.fingerprint]) {
                PriorImportedStatementDTO(importSessionId: $0.string(at: 0) ?? "", completedAtISO: $0.string(at: 1),
                    transactionCount: 0, accountId: nil, accountDisplayName: nil)
            }.first
    }

    private func insertHistory(_ plan: InvestmentImportPlan) throws {
        let history = plan.history
        let document = history.document
        guard let normalized = history.normalizedDocument else { throw InvestmentError.invalidEvidence }
        try db.executePrepared(sql: "INSERT INTO workspaces (id,name,created_at,updated_at) VALUES (?,?,?,?) ON CONFLICT(id) DO NOTHING;",
            params: [plan.workspace.id, plan.workspace.name, plan.workspace.createdAtISO, plan.workspace.updatedAtISO ?? NSNull()])
        try db.executePrepared(sql: "INSERT INTO import_sessions (id,workspace_id,user_visible_name,started_at,validation_status,created_at,reader_version,parser_version,layout_version) VALUES (?,?,?,?,?,?,?,?,?);",
            params: [history.importSession.id, history.importSession.workspaceId, history.importSession.userVisibleName ?? NSNull(),
                     history.importSession.startedAtISO, "pending", history.importSession.startedAtISO,
                     history.importSession.readerVersion ?? NSNull(), history.importSession.parserVersion ?? NSNull(), history.importSession.layoutVersion ?? NSNull()])
        try db.executePrepared(sql: "INSERT INTO documents (id,workspace_id,import_session_id,filename,mime_type,size_bytes,sha256,storage_path,extracted_text_snippet,page_count,created_at) VALUES (?,?,?,?,?,?,?,NULL,NULL,NULL,?);",
            params: [document.id, document.workspaceId, document.importSessionId, document.filename, document.mimeType ?? NSNull(),
                     document.sizeBytes ?? NSNull(), document.legacyRawTextSHA256, document.createdAtISO])
        for fingerprint in history.fingerprints {
            try db.executePrepared(sql: "INSERT INTO document_fingerprints (id,document_id,import_session_id,algorithm,fingerprint,fingerprint_data,created_at,is_duplicate_authority) VALUES (?,?,?,?,?,NULL,?,?);",
                params: [fingerprint.id, fingerprint.documentId, fingerprint.importSessionId, fingerprint.algorithm,
                         fingerprint.fingerprint, fingerprint.createdAtISO, fingerprint.isDuplicateAuthority ? 1 : 0])
        }
        try db.executePrepared(sql: "INSERT INTO normalized_documents (id,import_session_id,document_id,normalized_json,schema_version,created_at,profile_id,profile_version) VALUES (?,?,?,?,?,?,?,?);",
            params: [normalized.id, normalized.importSessionId, normalized.documentId, "{}", "trusted-source-v1",
                     history.completedAtISO, normalized.profileId, normalized.profileVersion])
        let attempt = history.successfulAttempt
        try db.executePrepared(sql: "INSERT INTO import_attempts (id,workspace_id,created_at,outcome_code,coverage_code,account_decision_code,guidance_code,persistence_code,transaction_count,account_id,import_session_id,document_id,related_import_session_id,source_row_count,imported_transaction_count,recognized_existing_row_count,blocked_row_count) VALUES (?,?,?,?,?,?,?,?,?,NULL,?,?,NULL,?,?,?,?);",
            params: [attempt.id, attempt.workspaceId, attempt.createdAtISO, attempt.outcomeCode, attempt.coverageCode,
                     attempt.accountDecisionCode, attempt.guidanceCode, attempt.persistenceCode, 0, history.importSession.id, document.id,
                     attempt.sourceRowCount ?? NSNull(), 0, 0, 0])
        try db.executePrepared(sql: "UPDATE import_sessions SET validation_status='passed',completed_at=?,updated_at=? WHERE id=?;",
            params: [history.completedAtISO, history.completedAtISO, history.importSession.id])
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let text = String(data: try encoder.encode(value), encoding: .utf8) else { throw InvestmentError.invalidPersistedState }
        return text
    }

    private func decode<T: Decodable>(_ type: T.Type, _ text: String?) throws -> T {
        guard let text else { throw InvestmentError.invalidPersistedState }
        do { return try JSONDecoder().decode(type, from: Data(text.utf8)) }
        catch { throw InvestmentError.invalidPersistedState }
    }
}
