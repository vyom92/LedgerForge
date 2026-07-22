// Provider-owned confirmed-import transaction.

import Foundation
import SQLite3

/// Installed with the active V5 ownership schema and used by the production
/// confirmed-import cutover.
final class SQLiteConfirmedImportRepository: ConfirmedImportRepository {
    private let db: SQLiteDatabase
    private let generationToken: ProviderGenerationToken

    init(db: SQLiteDatabase, generationToken: ProviderGenerationToken) {
        self.db = db
        self.generationToken = generationToken
    }

    func commitConfirmedImport(_ plan: ConfirmedImportPlanDTO) -> ConfirmedImportRepositoryResult {
        guard plan.providerGeneration == generationToken else { return .staleProviderGeneration }
        do {
            try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
            let result = try commitInsideTransaction(plan)
            switch result {
            case .committed:
                try db.execute(sql: "COMMIT;")
            default:
                try db.execute(sql: "ROLLBACK;")
            }
            return result
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

    private func commitInsideTransaction(_ plan: ConfirmedImportPlanDTO) throws -> ConfirmedImportRepositoryResult {
        guard plan.transactionTemplates.allSatisfy(\.isAccountIndependent),
              plan.transactionTemplates.allSatisfy({ $0.transaction.workspaceId == plan.workspace.id }),
              plan.historyTemplate.document.workspaceId == plan.workspace.id,
              plan.historyTemplate.document.importSessionId == plan.historyTemplate.importSession.id,
              plan.historyTemplate.importSession.workspaceId == plan.workspace.id,
              plan.historyTemplate.fingerprint.documentId == plan.historyTemplate.document.id,
              plan.historyTemplate.fingerprint.importSessionId == plan.historyTemplate.importSession.id,
              plan.historyTemplate.successfulAttempt.workspaceId == plan.workspace.id,
              plan.historyTemplate.normalizedDocument != nil,
              Set(plan.transactionTemplates.map { $0.transaction.id }).count == plan.transactionTemplates.count,
              !plan.historyTemplate.normalizedRows.isEmpty,
              Set(plan.historyTemplate.normalizedRows.map(\.sourceOrdinal)).count == plan.historyTemplate.normalizedRows.count,
              plan.historyTemplate.normalizedRows.allSatisfy({ $0.sourceOrdinal > 0 && !$0.digest.isEmpty }),
              plan.transactionTemplates.allSatisfy({ !$0.transaction.rawRows.isEmpty }),
              !hasDuplicateIdentifierCandidates(plan.identifiers) else {
            return .repositoryIntegrityConflict
        }
        if try count("SELECT COUNT(*) FROM document_fingerprints WHERE algorithm = ? AND fingerprint = ?;", [plan.historyTemplate.fingerprint.algorithm, plan.historyTemplate.fingerprint.fingerprint]) > 0 {
            return .exactDuplicate
        }

        let ownerSets = try plan.identifiers.map { candidate in
            Set(try db.query(
                sql: "SELECT account_id FROM account_identifiers WHERE workspace_id = ? AND scheme = ? AND identifier = ?;",
                params: [plan.workspace.id, candidate.scheme, candidate.normalizedValue]
            ) { $0.string(at: 0) ?? "" })
        }
        if ownerSets.contains(where: { $0.count > 1 }) { return .identityAmbiguous }
        let resolvedOwners = Set(ownerSets.flatMap { $0 })
        if resolvedOwners.count > 1 { return .identityConflict }
        let currentOwner = resolvedOwners.first
        switch plan.advisoryIdentity {
        case .resolved(let accountID) where currentOwner != accountID: return .staleIdentityDecision
        case .noMatch where currentOwner != nil:
            if case .createProposedAccount = plan.accountChoice {
                return .identifierOwnershipConflict
            }
            return .staleIdentityDecision
        case .ambiguous: return .identityAmbiguous
        case .conflict: return .identityConflict
        default: break
        }

        let account: AccountDTO
        switch plan.accountChoice {
        case .unspecified:
            return .explicitAccountChoiceRequired
        case .createProposedAccount:
            guard currentOwner == nil else { return .staleIdentityDecision }
            guard plan.proposedAccount.workspaceId == plan.workspace.id else { return .repositoryIntegrityConflict }
            try db.executePrepared(sql: "INSERT INTO workspaces (id, name, created_at, updated_at) VALUES (?,?,?,?) ON CONFLICT(id) DO NOTHING;", params: [plan.workspace.id, plan.workspace.name, plan.workspace.createdAtISO, plan.workspace.updatedAtISO ?? NSNull()])
            guard try count("SELECT COUNT(*) FROM accounts WHERE id = ?;", [plan.proposedAccount.id]) == 0 else { return .repositoryIntegrityConflict }
            try ensureInstitutionExists(id: plan.proposedAccount.institutionId, createdAtISO: plan.proposedAccount.createdAtISO)
            try db.executePrepared(sql: "INSERT INTO accounts (id, workspace_id, name, institution_id, account_type, native_currency, description, created_at) VALUES (?,?,?,?,?,?,?,?);", params: [plan.proposedAccount.id, plan.proposedAccount.workspaceId, plan.proposedAccount.name, plan.proposedAccount.institutionId ?? NSNull(), plan.proposedAccount.accountType ?? NSNull(), plan.proposedAccount.nativeCurrency, plan.proposedAccount.description ?? NSNull(), plan.proposedAccount.createdAtISO])
            account = plan.proposedAccount
        case .useExistingAccount(let accountID):
            guard let existing = try loadAccount(id: accountID) else { return .selectedAccountUnavailable }
            guard existing.workspaceId == plan.workspace.id else { return .selectedAccountWorkspaceMismatch }
            if let currentOwner {
                guard currentOwner == accountID else { return .identifierOwnershipConflict }
            } else if try count("SELECT COUNT(*) FROM account_identifiers WHERE account_id = ? AND workspace_id = ?;", [accountID, plan.workspace.id]) > 0 {
                return .selectedAccountIneligible
            }
            account = existing
        }

        var observations = [(String, ConfirmedImportIdentifierCandidateDTO)]()
        for candidate in plan.identifiers {
            let ownerRows = try db.query(sql: "SELECT account_id FROM account_identifiers WHERE workspace_id = ? AND scheme = ? AND identifier = ?;", params: [plan.workspace.id, candidate.scheme, candidate.normalizedValue]) { $0.string(at: 0) ?? "" }
            if ownerRows.contains(where: { $0 != account.id }) { return .identifierOwnershipConflict }
            let ownershipID: String
            if let current = ownerRows.first {
                ownershipID = try db.query(sql: "SELECT id FROM account_identifiers WHERE account_id = ? AND workspace_id = ? AND scheme = ? AND identifier = ? LIMIT 1;", params: [current, plan.workspace.id, candidate.scheme, candidate.normalizedValue]) { $0.string(at: 0) ?? "" }.first ?? ""
            } else {
                ownershipID = UUID().uuidString
                try db.executePrepared(sql: "INSERT INTO account_identifiers (id, account_id, workspace_id, scheme, identifier, provenance, created_at) VALUES (?,?,?,?,?,?,?);", params: [ownershipID, account.id, plan.workspace.id, candidate.scheme, candidate.normalizedValue, Self.provenanceJSON(candidate), plan.historyTemplate.completedAtISO])
            }
            observations.append((ownershipID, candidate))
        }

        let history = plan.historyTemplate
        var transactions = [TransactionDTO]()
        var events = [TransactionEventIdentityDTO]()
        for template in plan.transactionTemplates {
            let transaction = finalTransaction(template.transaction, accountID: account.id, history: history)
            transactions.append(transaction)
            if let evidence = template.eventEvidence {
                let identity: TransactionEventIdentity
                do { identity = try TransactionEventIdentity.make(transactionID: transaction.id, evidence: evidence, accountID: account.id) }
                catch { return .repositoryIntegrityConflict }
                if events.contains(where: { $0.algorithm == identity.algorithmIdentifier && $0.digest == identity.digest }) { return .repeatedIncomingEventEvidence }
                let owners = try db.query(sql: "SELECT account_id FROM transaction_event_identities WHERE algorithm = ? AND digest = ?;", params: [identity.algorithmIdentifier, identity.digest]) { $0.string(at: 0) ?? "" }
                if let owner = owners.first { return owner == account.id ? .existingEventDuplicate : .eventOwnershipConflict }
                events.append(TransactionEventIdentityDTO(id: UUID().uuidString, transactionId: transaction.id, accountId: account.id, documentId: history.document.id, importSessionId: history.importSession.id, algorithm: identity.algorithmIdentifier, digest: identity.digest, createdAtISO: history.completedAtISO))
            }
        }
        guard let normalizedDocument = history.normalizedDocument,
              normalizedDocument.importSessionId == history.importSession.id,
              normalizedDocument.documentId == history.document.id,
              history.normalizedRows.allSatisfy({ $0.normalizedDocumentId == normalizedDocument.id }),
              transactions.allSatisfy({ transaction in
                  transaction.rawRows.allSatisfy { raw in
                      history.normalizedRows.contains { $0.id == raw.normalizedRowId }
                  }
              }) else { return .repositoryIntegrityConflict }
        guard history.successfulAttempt.accountId == account.id,
              history.successfulAttempt.importSessionId == history.importSession.id,
              history.successfulAttempt.documentId == history.document.id else { return .repositoryIntegrityConflict }

        try insert(history: history, transactions: transactions, events: events, observations: observations)
        return .committed(ConfirmedImportReceiptDTO(workspaceId: plan.workspace.id, accountId: account.id, importSessionId: history.importSession.id, documentId: history.document.id))
    }

    private func insert(history: ConfirmedImportHistoryTemplateDTO, transactions: [TransactionDTO], events: [TransactionEventIdentityDTO], observations: [(String, ConfirmedImportIdentifierCandidateDTO)]) throws {
        let document = history.document
        try db.executePrepared(sql: "INSERT INTO import_sessions (id, workspace_id, user_visible_name, started_at, validation_status, created_at, reader_version, parser_version, layout_version) VALUES (?,?,?,?,?,?,?,?,?);", params: [history.importSession.id, history.importSession.workspaceId, history.importSession.userVisibleName ?? NSNull(), history.importSession.startedAtISO, history.importSession.validationStatus, history.importSession.startedAtISO, history.importSession.readerVersion ?? NSNull(), history.importSession.parserVersion ?? NSNull(), history.importSession.layoutVersion ?? NSNull()])
        try db.executePrepared(sql: "INSERT INTO documents (id, workspace_id, import_session_id, filename, mime_type, size_bytes, sha256, storage_path, extracted_text_snippet, page_count, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?);", params: [document.id, document.workspaceId, document.importSessionId, document.filename, document.mimeType ?? NSNull(), document.sizeBytes ?? NSNull(), document.sha256, NSNull(), NSNull(), NSNull(), document.createdAtISO])
        try db.executePrepared(sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, fingerprint_data, created_at) VALUES (?,?,?,?,?,?,?);", params: [history.fingerprint.id, history.fingerprint.documentId, history.fingerprint.importSessionId, history.fingerprint.algorithm, history.fingerprint.fingerprint, history.fingerprint.fingerprintData ?? NSNull(), history.fingerprint.createdAtISO])
        guard let normalized = history.normalizedDocument else { throw RepositoryError.relationshipViolation("Trusted source provenance is missing its normalized document.") }
        try db.executePrepared(sql: "INSERT INTO normalized_documents (id, import_session_id, document_id, normalized_json, schema_version, created_at, profile_id, profile_version) VALUES (?,?,?,?,?,?,?,?);", params: [normalized.id, normalized.importSessionId, normalized.documentId, "{\"profile\":\"\(normalized.profileId)\",\"version\":\"\(normalized.profileVersion)\"}", "trusted-source-v1", history.completedAtISO, normalized.profileId, normalized.profileVersion])
        for row in history.normalizedRows {
            try db.executePrepared(sql: "INSERT INTO normalized_rows (id, normalized_document_id, row_index, row_original, extracted_text, created_at, record_digest) VALUES (?,?,?,?,?,?,?);", params: [row.id, row.normalizedDocumentId, row.sourceOrdinal, "{\"digest\":\"\(row.digest)\"}", NSNull(), history.completedAtISO, row.digest])
        }
        for transaction in transactions {
            try db.executePrepared(sql: "INSERT INTO transactions (id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at, financial_date_role, statement_timezone_evidence) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);", params: [transaction.id, transaction.workspaceId, transaction.accountId ?? NSNull(), transaction.importSessionId ?? NSNull(), transaction.documentId ?? NSNull(), transaction.rawRows.first?.normalizedRowId ?? NSNull(), transaction.postedDateISO, transaction.valueDateISO ?? NSNull(), transaction.description ?? NSNull(), transaction.payee ?? NSNull(), transaction.reference ?? NSNull(), transaction.nativeCurrency, transaction.amountMinor, transaction.amountDecimal, transaction.direction, transaction.runningBalanceMinor ?? NSNull(), transaction.isReconciled ? 1 : 0, transaction.isTrusted ? 1 : 0, transaction.trustedAtISO ?? NSNull(), transaction.createdAtISO, transaction.updatedAtISO ?? NSNull(), transaction.financialDateRole, transaction.statementTimezoneEvidence])
            for raw in transaction.rawRows {
                try db.executePrepared(sql: "INSERT INTO transaction_raw_rows (id, transaction_id, normalized_row_id, contribution_type, created_at) VALUES (?,?,?,?,?);", params: [raw.id, transaction.id, raw.normalizedRowId, raw.contributionType ?? NSNull(), transaction.createdAtISO])
            }
        }
        for event in events { try db.executePrepared(sql: "INSERT INTO transaction_event_identities (id, transaction_id, account_id, document_id, import_session_id, algorithm, digest, created_at) VALUES (?,?,?,?,?,?,?,?);", params: [event.id, event.transactionId, event.accountId, event.documentId, event.importSessionId, event.algorithm, event.digest, event.createdAtISO]) }
        for (ownershipID, candidate) in observations {
            try db.executePrepared(sql: "INSERT INTO account_identifier_observations (id, ownership_id, import_session_id, document_id, parser_provenance_code, association_authority_code, created_at) VALUES (?,?,?,?,?,?,?);", params: [UUID().uuidString, ownershipID, history.importSession.id, history.document.id, candidate.provenanceCode, "confirmed-import", history.completedAtISO])
        }
        let attempt = history.successfulAttempt
        try db.executePrepared(sql: "INSERT INTO import_attempts (id, workspace_id, created_at, outcome_code, coverage_code, account_decision_code, guidance_code, persistence_code, transaction_count, account_id, import_session_id, document_id, related_import_session_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?);", params: [attempt.id, attempt.workspaceId, attempt.createdAtISO, attempt.outcomeCode, attempt.coverageCode, attempt.accountDecisionCode, attempt.guidanceCode, attempt.persistenceCode, attempt.transactionCount, attempt.accountId ?? NSNull(), attempt.importSessionId ?? NSNull(), attempt.documentId ?? NSNull(), attempt.relatedImportSessionId ?? NSNull()])
        try db.executePrepared(sql: "UPDATE import_sessions SET validation_status = ?, completed_at = ?, updated_at = ? WHERE id = ?;", params: ["passed", history.completedAtISO, history.completedAtISO, history.importSession.id])
    }

    private func loadAccount(id: String) throws -> AccountDTO? { try db.query(sql: "SELECT id, workspace_id, name, institution_id, account_type, native_currency, description, created_at FROM accounts WHERE id = ?;", params: [id]) { row in AccountDTO(id: row.string(at: 0) ?? "", workspaceId: row.string(at: 1) ?? "", name: row.string(at: 2) ?? "", institutionId: row.string(at: 3), accountType: row.string(at: 4), nativeCurrency: row.string(at: 5) ?? "", description: row.string(at: 6), createdAtISO: row.string(at: 7) ?? "") }.first }
    private func count(_ sql: String, _ params: [Any?]) throws -> Int { Int(try db.query(sql: sql, params: params) { $0.int64(at: 0) ?? 0 }.first ?? 0) }
    private func finalTransaction(_ t: TransactionDTO, accountID: String, history: ConfirmedImportHistoryTemplateDTO) -> TransactionDTO { TransactionDTO(id: t.id, workspaceId: t.workspaceId, accountId: accountID, importSessionId: history.importSession.id, documentId: history.document.id, originalRowId: t.originalRowId, postedDateISO: t.postedDateISO, financialDateRole: t.financialDateRole, statementTimezoneEvidence: t.statementTimezoneEvidence, valueDateISO: t.valueDateISO, description: t.description, payee: t.payee, reference: t.reference, nativeCurrency: t.nativeCurrency, amountMinor: t.amountMinor, amountDecimal: t.amountDecimal, direction: t.direction, runningBalanceMinor: t.runningBalanceMinor, isReconciled: t.isReconciled, isTrusted: t.isTrusted, trustedAtISO: t.trustedAtISO, createdAtISO: t.createdAtISO, updatedAtISO: t.updatedAtISO, rawRows: t.rawRows) }

    private func ensureInstitutionExists(id: String?, createdAtISO: String) throws {
        guard let id, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let code = String(id.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" })
        try db.executePrepared(sql: "INSERT OR IGNORE INTO institutions (id, code, name, country, created_at) VALUES (?,?,?,?,?);", params: [id, code, id, NSNull(), createdAtISO])
    }

    private static func provenanceJSON(_ candidate: ConfirmedImportIdentifierCandidateDTO) -> String {
        let payload = ["strength": "strong", "verificationState": "verified", "provenance": candidate.provenanceCode]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let value = String(data: data, encoding: .utf8) else { return candidate.provenanceCode }
        return value
    }

    private func hasDuplicateIdentifierCandidates(_ candidates: [ConfirmedImportIdentifierCandidateDTO]) -> Bool {
        for index in candidates.indices {
            for laterIndex in candidates.indices where laterIndex > index {
                if candidates[index].scheme == candidates[laterIndex].scheme,
                   candidates[index].normalizedValue == candidates[laterIndex].normalizedValue {
                    return true
                }
            }
        }
        return false
    }
}
