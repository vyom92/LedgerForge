// Dormant, provider-owned confirmed-import transaction.

import Foundation
import SQLite3

/// Installed only when the V5 ownership schema is present. The application
/// still runs V4 and the legacy import path until the explicit Task 4 cutover.
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
              plan.historyTemplate.document.workspaceId == plan.workspace.id,
              plan.historyTemplate.document.importSessionId == plan.historyTemplate.importSession.id,
              plan.historyTemplate.importSession.workspaceId == plan.workspace.id,
              plan.historyTemplate.fingerprint.documentId == plan.historyTemplate.document.id,
              plan.historyTemplate.fingerprint.importSessionId == plan.historyTemplate.importSession.id else {
            return .repositoryIntegrityConflict
        }
        if try count("SELECT COUNT(*) FROM document_fingerprints WHERE algorithm = ? AND fingerprint = ?;", [plan.historyTemplate.fingerprint.algorithm, plan.historyTemplate.fingerprint.fingerprint]) > 0 {
            return .exactDuplicate
        }

        let account: AccountDTO
        switch plan.accountChoice {
        case .createProposedAccount:
            guard plan.proposedAccount.workspaceId == plan.workspace.id else { return .repositoryIntegrityConflict }
            try db.executePrepared(sql: "INSERT INTO workspaces (id, name, created_at, updated_at) VALUES (?,?,?,?) ON CONFLICT(id) DO NOTHING;", params: [plan.workspace.id, plan.workspace.name, plan.workspace.createdAtISO, plan.workspace.updatedAtISO ?? NSNull()])
            guard try count("SELECT COUNT(*) FROM accounts WHERE id = ?;", [plan.proposedAccount.id]) == 0 else { return .repositoryIntegrityConflict }
            try db.executePrepared(sql: "INSERT INTO accounts (id, workspace_id, name, institution_id, account_type, native_currency, description, created_at) VALUES (?,?,?,?,?,?,?,?);", params: [plan.proposedAccount.id, plan.proposedAccount.workspaceId, plan.proposedAccount.name, plan.proposedAccount.institutionId ?? NSNull(), plan.proposedAccount.accountType ?? NSNull(), plan.proposedAccount.nativeCurrency, plan.proposedAccount.description ?? NSNull(), plan.proposedAccount.createdAtISO])
            account = plan.proposedAccount
        case .useExistingAccount(let accountID):
            guard let existing = try loadAccount(id: accountID) else { return .selectedAccountUnavailable }
            guard existing.workspaceId == plan.workspace.id else { return .selectedAccountWorkspaceMismatch }
            account = existing
        }

        switch plan.advisoryIdentity {
        case .resolved(let accountID) where accountID != account.id: return .staleIdentityDecision
        case .ambiguous: return .identityAmbiguous
        case .conflict: return .identityConflict
        default: break
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
                try db.executePrepared(sql: "INSERT INTO account_identifiers (id, account_id, workspace_id, scheme, identifier, provenance, created_at) VALUES (?,?,?,?,?,?,?);", params: [ownershipID, account.id, plan.workspace.id, candidate.scheme, candidate.normalizedValue, candidate.provenanceCode, plan.historyTemplate.completedAtISO])
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
                if try count("SELECT COUNT(*) FROM transaction_event_identities WHERE algorithm = ? AND digest = ?;", [identity.algorithmIdentifier, identity.digest]) > 0 { return .existingEventDuplicate }
                events.append(TransactionEventIdentityDTO(id: UUID().uuidString, transactionId: transaction.id, accountId: account.id, documentId: history.document.id, importSessionId: history.importSession.id, algorithm: identity.algorithmIdentifier, digest: identity.digest, createdAtISO: history.completedAtISO))
            }
        }
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
        for transaction in transactions {
            try db.executePrepared(sql: "INSERT INTO transactions (id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);", params: [transaction.id, transaction.workspaceId, transaction.accountId ?? NSNull(), transaction.importSessionId ?? NSNull(), transaction.documentId ?? NSNull(), transaction.originalRowId ?? NSNull(), transaction.postedDateISO, transaction.valueDateISO ?? NSNull(), transaction.description ?? NSNull(), transaction.payee ?? NSNull(), transaction.reference ?? NSNull(), transaction.nativeCurrency, transaction.amountMinor, transaction.amountDecimal, transaction.direction, transaction.runningBalanceMinor ?? NSNull(), transaction.isReconciled ? 1 : 0, transaction.isTrusted ? 1 : 0, transaction.trustedAtISO ?? NSNull(), transaction.createdAtISO, transaction.updatedAtISO ?? NSNull()])
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
    private func finalTransaction(_ t: TransactionDTO, accountID: String, history: ConfirmedImportHistoryTemplateDTO) -> TransactionDTO { TransactionDTO(id: t.id, workspaceId: t.workspaceId, accountId: accountID, importSessionId: history.importSession.id, documentId: history.document.id, originalRowId: t.originalRowId, postedDateISO: t.postedDateISO, valueDateISO: t.valueDateISO, description: t.description, payee: t.payee, reference: t.reference, nativeCurrency: t.nativeCurrency, amountMinor: t.amountMinor, amountDecimal: t.amountDecimal, direction: t.direction, runningBalanceMinor: t.runningBalanceMinor, isReconciled: t.isReconciled, isTrusted: t.isTrusted, trustedAtISO: t.trustedAtISO, createdAtISO: t.createdAtISO, updatedAtISO: t.updatedAtISO, rawRows: t.rawRows) }
}
