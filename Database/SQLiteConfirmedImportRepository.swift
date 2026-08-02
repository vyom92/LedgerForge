// Provider-owned confirmed-import transaction.

import Foundation
import SQLite3

/// Installed with the active V5 ownership schema and used by the production
/// confirmed-import cutover.
final class SQLiteConfirmedImportRepository: ConfirmedImportRepository {
    private let db: SQLiteDatabase
    private let generationToken: ProviderGenerationToken
    private let consumedPlanLock = NSLock()
    private var consumedPlanIDs = Set<String>()

    init(db: SQLiteDatabase, generationToken: ProviderGenerationToken) {
        self.db = db
        self.generationToken = generationToken
    }

    func reviewStatementEquivalence(_ plan: ConfirmedImportPlanDTO) -> StatementEquivalenceReviewResult {
        guard plan.providerGeneration == generationToken else { return .evidenceUnavailable }
        do {
            return try reviewStatementEquivalenceInsideTransaction(plan, resolvedAccountID: nil)
        } catch {
            return .evidenceUnavailable
        }
    }

    func reviewPartialImport(_ plan: ConfirmedImportPlanDTO) -> PartialImportReviewResult {
        guard plan.providerGeneration == generationToken else {
            return .repositoryIntegrityConflict
        }
        do {
            try plan.historyTemplate.validateFingerprints()
            return try reviewPartialImport(plan, planID: UUID().uuidString)
        } catch {
            return .repositoryIntegrityConflict
        }
    }

    func commitReviewedPartialImport(_ reviewedPlan: ReviewedPartialImportPlanDTO) -> ConfirmedImportRepositoryResult {
        guard consumePlan(reviewedPlan.id),
              reviewedPlan.basePlan.providerGeneration == generationToken,
              reviewedPlan.hasValidDigest(),
              (try? reviewedPlan.basePlan.historyTemplate.validateFingerprints()) != nil,
              let authority = reviewedPlan.basePlan.historyTemplate.duplicateAuthorityFingerprint else {
            return .reviewedPartialPlanStale
        }
        do {
            try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
            if try count("SELECT COUNT(*) FROM document_fingerprints WHERE algorithm = ? AND fingerprint = ? AND is_duplicate_authority = 1;", [authority.algorithm, authority.fingerprint]) > 0 {
                try db.execute(sql: "ROLLBACK;")
                return .reviewedPartialPlanStale
            }
            let currentReview = try reviewPartialImport(
                reviewedPlan.basePlan,
                planID: reviewedPlan.id
            )
            guard case .eligible(let currentPlan) = currentReview,
                  currentPlan == reviewedPlan else {
                try db.execute(sql: "ROLLBACK;")
                return .reviewedPartialPlanStale
            }
            guard try validateExistingIdentity(
                reviewedPlan.basePlan,
                accountID: reviewedPlan.existingAccountId
            ) else {
                try db.execute(sql: "ROLLBACK;")
                return .reviewedPartialPlanStale
            }
            try insert(reviewedPartialPlan: reviewedPlan)
            try db.execute(sql: "COMMIT;")
            let history = reviewedPlan.basePlan.historyTemplate
            return .partialCommitted(
                ConfirmedImportReceiptDTO(
                    workspaceId: reviewedPlan.basePlan.workspace.id,
                    accountId: reviewedPlan.existingAccountId,
                    importSessionId: history.importSession.id,
                    documentId: history.document.id
                )
            )
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

    func commitConfirmedImport(_ plan: ConfirmedImportPlanDTO) -> ConfirmedImportRepositoryResult {
        guard plan.providerGeneration == generationToken else { return .staleProviderGeneration }
        guard (try? plan.historyTemplate.validateFingerprints()) != nil else {
            return .repositoryIntegrityConflict
        }
        do {
            try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
            let result = try commitInsideTransaction(plan)
            switch result {
            case .committed, .equivalentSourceRecorded:
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
              plan.historyTemplate.successfulAttempt.workspaceId == plan.workspace.id,
              plan.historyTemplate.normalizedDocument != nil,
              Set(plan.transactionTemplates.map { $0.transaction.id }).count == plan.transactionTemplates.count,
              !plan.historyTemplate.normalizedRows.isEmpty,
              Set(plan.historyTemplate.normalizedRows.map(\.sourceOrdinal)).count == plan.historyTemplate.normalizedRows.count,
              plan.historyTemplate.normalizedRows.allSatisfy({ $0.sourceOrdinal > 0 && !$0.digest.isEmpty }),
              plan.transactionTemplates.allSatisfy({ !$0.transaction.rawRows.isEmpty }),
              hasValidTrustedProvenance(plan),
              !hasDuplicateIdentifierCandidates(plan.identifiers) else {
            return .repositoryIntegrityConflict
        }
        guard let authority = plan.historyTemplate.duplicateAuthorityFingerprint else {
            return .repositoryIntegrityConflict
        }
        if try count("SELECT COUNT(*) FROM document_fingerprints WHERE algorithm = ? AND fingerprint = ? AND is_duplicate_authority = 1;", [authority.algorithm, authority.fingerprint]) > 0 {
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

        let equivalenceReview = try reviewStatementEquivalenceInsideTransaction(
            plan,
            resolvedAccountID: account.id
        )
        let isSupportingSource: Bool
        switch equivalenceReview {
        case .notApplicable, .firstAcceptedSource:
            isSupportingSource = false
        case .equivalent:
            isSupportingSource = true
        case .conflict:
            return .statementEquivalenceConflict
        case .evidenceUnavailable:
            return .statementEquivalenceEvidenceUnavailable
        case .formatAlreadyRecorded:
            return .equivalentFormatAlreadyRecorded
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
        for template in plan.transactionTemplates where !isSupportingSource {
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

        try insert(
            history: history,
            transactions: transactions,
            events: events,
            observations: observations,
            projection: plan.statementFinancialProjection,
            equivalenceReview: equivalenceReview,
            workspaceID: plan.workspace.id,
            accountID: account.id
        )
        let receipt = ConfirmedImportReceiptDTO(workspaceId: plan.workspace.id, accountId: account.id, importSessionId: history.importSession.id, documentId: history.document.id)
        return isSupportingSource ? .equivalentSourceRecorded(receipt) : .committed(receipt)
    }

    private func insert(
        history: ConfirmedImportHistoryTemplateDTO,
        transactions: [TransactionDTO],
        events: [TransactionEventIdentityDTO],
        observations: [(String, ConfirmedImportIdentifierCandidateDTO)],
        projection: StatementFinancialProjectionDTO?,
        equivalenceReview: StatementEquivalenceReviewResult,
        workspaceID: String,
        accountID: String
    ) throws {
        let document = history.document
        try db.executePrepared(sql: "INSERT INTO import_sessions (id, workspace_id, user_visible_name, started_at, validation_status, created_at, reader_version, parser_version, layout_version) VALUES (?,?,?,?,?,?,?,?,?);", params: [history.importSession.id, history.importSession.workspaceId, history.importSession.userVisibleName ?? NSNull(), history.importSession.startedAtISO, history.importSession.validationStatus, history.importSession.startedAtISO, history.importSession.readerVersion ?? NSNull(), history.importSession.parserVersion ?? NSNull(), history.importSession.layoutVersion ?? NSNull()])
        try db.executePrepared(sql: "INSERT INTO documents (id, workspace_id, import_session_id, filename, mime_type, size_bytes, sha256, storage_path, extracted_text_snippet, page_count, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?);", params: [document.id, document.workspaceId, document.importSessionId, document.filename, document.mimeType ?? NSNull(), document.sizeBytes ?? NSNull(), document.legacyRawTextSHA256, NSNull(), NSNull(), NSNull(), document.createdAtISO])
        for fingerprint in history.fingerprints {
            try db.executePrepared(sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, fingerprint_data, created_at, is_duplicate_authority) VALUES (?,?,?,?,?,?,?,?);", params: [fingerprint.id, fingerprint.documentId, fingerprint.importSessionId, fingerprint.algorithm, fingerprint.fingerprint, fingerprint.fingerprintData ?? NSNull(), fingerprint.createdAtISO, fingerprint.isDuplicateAuthority ? 1 : 0])
        }
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
        if let projection {
            try insertStatementProjection(
                projection,
                workspaceID: workspaceID,
                accountID: accountID,
                documentID: history.document.id,
                importSessionID: history.importSession.id,
                createdAtISO: history.completedAtISO
            )
            try insertStatementEquivalenceMembership(
                projection,
                review: equivalenceReview,
                workspaceID: workspaceID,
                accountID: accountID,
                createdAtISO: history.completedAtISO
            )
        }
        let attempt: ImportAttemptDTO
        if case .equivalent(let authoritativeImportSessionID) = equivalenceReview {
            attempt = ImportAttemptDTO(
                id: history.successfulAttempt.id,
                workspaceId: workspaceID,
                createdAtISO: history.completedAtISO,
                outcomeCode: ImportAttemptOutcome.equivalentSourceRecorded.rawValue,
                coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue,
                accountDecisionCode: ImportAttemptAccountDecision.noFinancialMutation.rawValue,
                guidanceCode: ImportAttemptGuidance.equivalentSourceRecorded.rawValue,
                persistenceCode: ImportAttemptPersistence.committed.rawValue,
                transactionCount: 0,
                accountId: accountID,
                importSessionId: history.importSession.id,
                documentId: history.document.id,
                relatedImportSessionId: authoritativeImportSessionID,
                sourceRowCount: projection?.eventCount,
                importedTransactionCount: 0,
                recognizedExistingRowCount: projection?.eventCount,
                blockedRowCount: 0
            )
        } else {
            attempt = history.successfulAttempt
        }
        try db.executePrepared(sql: "INSERT INTO import_attempts (id, workspace_id, created_at, outcome_code, coverage_code, account_decision_code, guidance_code, persistence_code, transaction_count, account_id, import_session_id, document_id, related_import_session_id, source_row_count, imported_transaction_count, recognized_existing_row_count, blocked_row_count) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);", params: [attempt.id, attempt.workspaceId, attempt.createdAtISO, attempt.outcomeCode, attempt.coverageCode, attempt.accountDecisionCode, attempt.guidanceCode, attempt.persistenceCode, attempt.transactionCount, attempt.accountId ?? NSNull(), attempt.importSessionId ?? NSNull(), attempt.documentId ?? NSNull(), attempt.relatedImportSessionId ?? NSNull(), attempt.sourceRowCount ?? NSNull(), attempt.importedTransactionCount ?? NSNull(), attempt.recognizedExistingRowCount ?? NSNull(), attempt.blockedRowCount ?? NSNull()])
        try db.executePrepared(sql: "UPDATE import_sessions SET validation_status = ?, completed_at = ?, updated_at = ? WHERE id = ?;", params: ["passed", history.completedAtISO, history.completedAtISO, history.importSession.id])
    }

    private func reviewStatementEquivalenceInsideTransaction(
        _ plan: ConfirmedImportPlanDTO,
        resolvedAccountID: String?
    ) throws -> StatementEquivalenceReviewResult {
        guard let projection = plan.statementFinancialProjection else { return .notApplicable }
        guard projection.isValid(),
              let normalized = plan.historyTemplate.normalizedDocument,
              normalized.profileId == projection.parserProfileID,
              normalized.profileVersion == projection.parserProfileVersion,
              plan.historyTemplate.normalizedRows.count == projection.eventCount,
              plan.transactionTemplates.count == projection.eventCount,
              plan.declaredStatementStartISO == projection.statementStartDateISO,
              plan.declaredStatementEndISO == projection.statementEndDateISO,
              plan.proposedAccount.nativeCurrency == projection.nativeCurrency else {
            return .evidenceUnavailable
        }

        let accountID: String?
        if let resolvedAccountID {
            accountID = resolvedAccountID
        } else if case .useExistingAccount(let existingAccountID) = plan.accountChoice {
            accountID = existingAccountID
        } else {
            accountID = nil
        }
        guard let accountID else { return .firstAcceptedSource }

        let groupRows = try db.query(
            sql: "SELECT id, projection_algorithm, projection_digest, authoritative_projection_id FROM statement_equivalence_groups WHERE workspace_id = ? AND account_id = ? AND institution_code = ? AND statement_family_code = ? AND statement_start_date = ? AND statement_end_date = ? AND native_currency = ? LIMIT 1;",
            params: [plan.workspace.id, accountID, projection.institutionCode, projection.statementFamilyCode, projection.statementStartDateISO, projection.statementEndDateISO, projection.nativeCurrency]
        ) { row in
            (row.string(at: 0) ?? "", row.string(at: 1) ?? "", row.string(at: 2) ?? "", row.string(at: 3) ?? "")
        }
        if let group = groupRows.first {
            if try count(
                "SELECT COUNT(*) FROM statement_equivalence_members WHERE group_id = ? AND source_format_code = ?;",
                [group.0, projection.sourceFormatCode]
            ) > 0 {
                return .formatAlreadyRecorded
            }
            guard group.1 == projection.algorithmIdentifier,
                  group.2 == projection.digest,
                  let authoritative = try loadStatementProjection(id: group.3),
                  financiallyEquivalent(authoritative.projection, projection) else {
                return .conflict
            }
            return .equivalent(authoritativeImportSessionID: authoritative.importSessionID)
        }

        if try hasPreV10ExactEventOverlap(projection, accountID: accountID) {
            return .evidenceUnavailable
        }
        return .firstAcceptedSource
    }

    private func loadStatementProjection(id: String) throws -> StatementFinancialProjectionRecordDTO? {
        let records = try db.query(
            sql: "SELECT id, workspace_id, account_id, document_id, import_session_id, algorithm, digest, institution_code, statement_family_code, parser_profile_id, parser_profile_version, source_format_code, statement_start_date, statement_end_date, native_currency, event_count, opening_balance_minor, opening_balance_decimal, debit_count, credit_count, debit_total_minor, debit_total_decimal, credit_total_minor, credit_total_decimal, closing_balance_minor, closing_balance_decimal, created_at FROM statement_financial_projections WHERE id = ? LIMIT 1;",
            params: [id]
        ) { row in
            (
                row.string(at: 0) ?? "", row.string(at: 1) ?? "", row.string(at: 2) ?? "",
                row.string(at: 3) ?? "", row.string(at: 4) ?? "", row.string(at: 5) ?? "",
                row.string(at: 6) ?? "", row.string(at: 7) ?? "", row.string(at: 8) ?? "",
                row.string(at: 9) ?? "", row.string(at: 10) ?? "", row.string(at: 11) ?? "",
                row.string(at: 12) ?? "", row.string(at: 13) ?? "", row.string(at: 14) ?? "",
                Int(row.int64(at: 15) ?? 0), row.int64(at: 16) ?? 0, row.string(at: 17) ?? "",
                Int(row.int64(at: 18) ?? 0), Int(row.int64(at: 19) ?? 0), row.int64(at: 20) ?? 0,
                row.string(at: 21) ?? "", row.int64(at: 22) ?? 0, row.string(at: 23) ?? "",
                row.int64(at: 24) ?? 0, row.string(at: 25) ?? "", row.string(at: 26) ?? ""
            )
        }
        guard let record = records.first else { return nil }
        let projectionEvents = try db.query(
            sql: "SELECT id, event_ordinal, statement_date, value_date, direction, signed_amount_minor, signed_amount_decimal, running_balance_minor, running_balance_decimal, reference FROM statement_financial_projection_events WHERE projection_id = ? ORDER BY event_ordinal;",
            params: [id]
        ) { row in
            StatementFinancialProjectionEventDTO(
                id: row.string(at: 0) ?? "",
                ordinal: Int(row.int64(at: 1) ?? 0),
                statementDateISO: row.string(at: 2) ?? "",
                valueDateISO: row.string(at: 3) ?? "",
                direction: row.string(at: 4) ?? "",
                signedAmountMinor: row.int64(at: 5) ?? 0,
                signedAmountDecimal: row.string(at: 6) ?? "",
                runningBalanceMinor: row.int64(at: 7) ?? 0,
                runningBalanceDecimal: row.string(at: 8) ?? "",
                reference: row.string(at: 9)
            )
        }
        let projection = StatementFinancialProjectionDTO(
            id: record.0, algorithmIdentifier: record.5, digest: record.6,
            institutionCode: record.7, statementFamilyCode: record.8,
            parserProfileID: record.9, parserProfileVersion: record.10,
            sourceFormatCode: record.11, statementStartDateISO: record.12,
            statementEndDateISO: record.13, nativeCurrency: record.14,
            eventCount: record.15, openingBalanceMinor: record.16,
            openingBalanceDecimal: record.17, debitCount: record.18,
            creditCount: record.19, debitTotalMinor: record.20,
            debitTotalDecimal: record.21, creditTotalMinor: record.22,
            creditTotalDecimal: record.23, closingBalanceMinor: record.24,
            closingBalanceDecimal: record.25, events: projectionEvents
        )
        return StatementFinancialProjectionRecordDTO(
            projection: projection,
            workspaceID: record.1,
            accountID: record.2,
            documentID: record.3,
            importSessionID: record.4,
            createdAtISO: record.26
        )
    }

    private func hasPreV10ExactEventOverlap(
        _ projection: StatementFinancialProjectionDTO,
        accountID: String
    ) throws -> Bool {
        let sessionIDs = try db.query(
            sql: "SELECT DISTINCT t.import_session_id FROM transactions t JOIN normalized_documents n ON n.import_session_id = t.import_session_id LEFT JOIN statement_financial_projections p ON p.import_session_id = t.import_session_id WHERE t.account_id = ? AND n.profile_id IN ('hdfc.bank-account.pdf','hdfc.bank-account.xls') AND p.id IS NULL;",
            params: [accountID]
        ) { $0.string(at: 0) ?? "" }
        for sessionID in sessionIDs where !sessionID.isEmpty {
            let existingEvents = try db.query(
                sql: "SELECT t.posted_date, t.value_date, t.direction, t.amount_minor, t.amount_decimal, t.running_balance_minor, t.reference FROM transactions t LEFT JOIN normalized_rows r ON r.id = t.original_row_id WHERE t.account_id = ? AND t.import_session_id = ? ORDER BY COALESCE(r.row_index, 2147483647), t.id;",
                params: [accountID, sessionID]
            ) { row in
                (row.string(at: 0) ?? "", row.string(at: 1) ?? "", row.string(at: 2) ?? "", row.int64(at: 3) ?? 0, row.string(at: 4) ?? "", row.int64(at: 5) ?? 0, row.string(at: 6))
            }
            guard existingEvents.count == projection.events.count else { continue }
            var matches = true
            for (existing, incoming) in zip(existingEvents, projection.events) {
                if existing.0 != incoming.statementDateISO ||
                    existing.1 != incoming.valueDateISO ||
                    existing.2 != incoming.direction ||
                    existing.3 != incoming.signedAmountMinor ||
                    existing.4 != incoming.signedAmountDecimal ||
                    existing.5 != incoming.runningBalanceMinor ||
                    existing.6 != incoming.reference {
                    matches = false
                    break
                }
            }
            if matches { return true }
        }
        return false
    }

    private func financiallyEquivalent(
        _ lhs: StatementFinancialProjectionDTO,
        _ rhs: StatementFinancialProjectionDTO
    ) -> Bool {
        guard lhs.algorithmIdentifier == rhs.algorithmIdentifier,
              lhs.digest == rhs.digest,
              lhs.institutionCode == rhs.institutionCode,
              lhs.statementFamilyCode == rhs.statementFamilyCode,
              lhs.statementStartDateISO == rhs.statementStartDateISO,
              lhs.statementEndDateISO == rhs.statementEndDateISO,
              lhs.nativeCurrency == rhs.nativeCurrency,
              lhs.eventCount == rhs.eventCount,
              lhs.openingBalanceMinor == rhs.openingBalanceMinor,
              lhs.openingBalanceDecimal == rhs.openingBalanceDecimal,
              lhs.debitCount == rhs.debitCount,
              lhs.creditCount == rhs.creditCount,
              lhs.debitTotalMinor == rhs.debitTotalMinor,
              lhs.debitTotalDecimal == rhs.debitTotalDecimal,
              lhs.creditTotalMinor == rhs.creditTotalMinor,
              lhs.creditTotalDecimal == rhs.creditTotalDecimal,
              lhs.closingBalanceMinor == rhs.closingBalanceMinor,
              lhs.closingBalanceDecimal == rhs.closingBalanceDecimal else { return false }
        return zip(lhs.events, rhs.events).allSatisfy { left, right in
            left.ordinal == right.ordinal && left.statementDateISO == right.statementDateISO &&
            left.valueDateISO == right.valueDateISO && left.direction == right.direction &&
            left.signedAmountMinor == right.signedAmountMinor &&
            left.signedAmountDecimal == right.signedAmountDecimal &&
            left.runningBalanceMinor == right.runningBalanceMinor &&
            left.runningBalanceDecimal == right.runningBalanceDecimal &&
            left.reference == right.reference
        }
    }

    private func insertStatementProjection(
        _ projection: StatementFinancialProjectionDTO,
        workspaceID: String,
        accountID: String,
        documentID: String,
        importSessionID: String,
        createdAtISO: String
    ) throws {
        guard projection.isValid() else { throw RepositoryError.relationshipViolation("Statement financial projection is invalid.") }
        try db.executePrepared(
            sql: "INSERT INTO statement_financial_projections (id, workspace_id, account_id, document_id, import_session_id, algorithm, digest, institution_code, statement_family_code, parser_profile_id, parser_profile_version, source_format_code, statement_start_date, statement_end_date, native_currency, event_count, opening_balance_minor, opening_balance_decimal, debit_count, credit_count, debit_total_minor, debit_total_decimal, credit_total_minor, credit_total_decimal, closing_balance_minor, closing_balance_decimal, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);",
            params: [projection.id, workspaceID, accountID, documentID, importSessionID, projection.algorithmIdentifier, projection.digest, projection.institutionCode, projection.statementFamilyCode, projection.parserProfileID, projection.parserProfileVersion, projection.sourceFormatCode, projection.statementStartDateISO, projection.statementEndDateISO, projection.nativeCurrency, projection.eventCount, projection.openingBalanceMinor, projection.openingBalanceDecimal, projection.debitCount, projection.creditCount, projection.debitTotalMinor, projection.debitTotalDecimal, projection.creditTotalMinor, projection.creditTotalDecimal, projection.closingBalanceMinor, projection.closingBalanceDecimal, createdAtISO]
        )
        for event in projection.events {
            try db.executePrepared(
                sql: "INSERT INTO statement_financial_projection_events (id, projection_id, event_ordinal, statement_date, value_date, direction, signed_amount_minor, signed_amount_decimal, running_balance_minor, running_balance_decimal, reference, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?);",
                params: [event.id, projection.id, event.ordinal, event.statementDateISO, event.valueDateISO, event.direction, event.signedAmountMinor, event.signedAmountDecimal, event.runningBalanceMinor, event.runningBalanceDecimal, event.reference ?? NSNull(), createdAtISO]
            )
        }
    }

    private func insertStatementEquivalenceMembership(
        _ projection: StatementFinancialProjectionDTO,
        review: StatementEquivalenceReviewResult,
        workspaceID: String,
        accountID: String,
        createdAtISO: String
    ) throws {
        let groupID: String
        let role: StatementEquivalenceMemberRole
        switch review {
        case .firstAcceptedSource:
            groupID = "statement-equivalence-group-\(projection.id)"
            role = .authoritative
            try db.executePrepared(
                sql: "INSERT INTO statement_equivalence_groups (id, workspace_id, account_id, institution_code, statement_family_code, statement_start_date, statement_end_date, native_currency, projection_algorithm, projection_digest, authoritative_projection_id, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?);",
                params: [groupID, workspaceID, accountID, projection.institutionCode, projection.statementFamilyCode, projection.statementStartDateISO, projection.statementEndDateISO, projection.nativeCurrency, projection.algorithmIdentifier, projection.digest, projection.id, createdAtISO]
            )
        case .equivalent:
            guard let existingGroupID = try db.query(
                sql: "SELECT id FROM statement_equivalence_groups WHERE workspace_id = ? AND account_id = ? AND institution_code = ? AND statement_family_code = ? AND statement_start_date = ? AND statement_end_date = ? AND native_currency = ? LIMIT 1;",
                params: [workspaceID, accountID, projection.institutionCode, projection.statementFamilyCode, projection.statementStartDateISO, projection.statementEndDateISO, projection.nativeCurrency],
                map: { $0.string(at: 0) ?? "" }
            ).first, !existingGroupID.isEmpty else {
                throw RepositoryError.relationshipViolation("Statement equivalence group is unavailable.")
            }
            groupID = existingGroupID
            role = .supporting
        case .notApplicable:
            return
        case .conflict, .evidenceUnavailable, .formatAlreadyRecorded:
            throw RepositoryError.relationshipViolation("Statement equivalence review cannot be persisted.")
        }
        try db.executePrepared(
            sql: "INSERT INTO statement_equivalence_members (id, group_id, projection_id, role, source_format_code, created_at) VALUES (?,?,?,?,?,?);",
            params: ["statement-equivalence-member-\(projection.id)", groupID, projection.id, role.rawValue, projection.sourceFormatCode, createdAtISO]
        )
    }

    private func reviewPartialImport(
        _ plan: ConfirmedImportPlanDTO,
        planID: String
    ) throws -> PartialImportReviewResult {
        guard case .useExistingAccount(let accountID) = plan.accountChoice else {
            return .unsupportedEvidence
        }
        let account = try loadAccount(id: accountID)
        var owners: [TransactionEventIdentityKeyDTO: TransactionEventIdentityOwnerDTO] = [:]
        var transactions: [String: TransactionDTO] = [:]
        for template in plan.transactionTemplates {
            guard let evidence = template.eventEvidence,
                  let identity = try? TransactionEventIdentity.make(
                    transactionID: template.transaction.id,
                    evidence: evidence,
                    accountID: accountID
                  ) else {
                continue
            }
            let key = TransactionEventIdentityKeyDTO(
                algorithm: identity.algorithmIdentifier,
                digest: identity.digest
            )
            let owner = try db.query(
                sql: "SELECT id, account_id, transaction_id, document_id, import_session_id FROM transaction_event_identities WHERE algorithm = ? AND digest = ?;",
                params: [key.algorithm, key.digest]
            ) { row in
                TransactionEventIdentityOwnerDTO(
                    eventIdentityId: row.string(at: 0) ?? "",
                    accountId: row.string(at: 1) ?? "",
                    transactionId: row.string(at: 2) ?? "",
                    documentId: row.string(at: 3) ?? "",
                    importSessionId: row.string(at: 4) ?? ""
                )
            }.first
            if let owner {
                owners[key] = owner
                if let transaction = try loadTransaction(id: owner.transactionId) {
                    transactions[transaction.id] = transaction
                }
            }
        }
        return ReviewedPartialImportPlanner.review(
            plan,
            account: account,
            owners: owners,
            transactionsByID: transactions,
            planID: planID
        )
    }

    private func loadTransaction(id: String) throws -> TransactionDTO? {
        try db.query(
            sql: "SELECT id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at, financial_date_role, statement_timezone_evidence FROM transactions WHERE id = ?;",
            params: [id]
        ) { row in
            TransactionDTO(
                id: row.string(at: 0) ?? "",
                workspaceId: row.string(at: 1) ?? "",
                accountId: row.string(at: 2),
                importSessionId: row.string(at: 3),
                documentId: row.string(at: 4),
                originalRowId: row.string(at: 5),
                postedDateISO: row.string(at: 6) ?? "",
                financialDateRole: row.string(at: 21) ?? "",
                statementTimezoneEvidence: row.string(at: 22) ?? "",
                valueDateISO: row.string(at: 7),
                description: row.string(at: 8),
                payee: row.string(at: 9),
                reference: row.string(at: 10),
                nativeCurrency: row.string(at: 11) ?? "",
                amountMinor: row.int64(at: 12) ?? 0,
                amountDecimal: row.string(at: 13) ?? "",
                direction: row.string(at: 14) ?? "",
                runningBalanceMinor: row.int64(at: 15),
                isReconciled: row.bool(at: 16),
                isTrusted: row.bool(at: 17),
                trustedAtISO: row.string(at: 18),
                createdAtISO: row.string(at: 19) ?? "",
                updatedAtISO: row.string(at: 20),
                rawRows: []
            )
        }.first
    }

    private func validateExistingIdentity(
        _ plan: ConfirmedImportPlanDTO,
        accountID: String
    ) throws -> Bool {
        guard let account = try loadAccount(id: accountID),
              account.workspaceId == plan.workspace.id else { return false }
        for candidate in plan.identifiers {
            let owners = try db.query(
                sql: "SELECT account_id FROM account_identifiers WHERE workspace_id = ? AND scheme = ? AND identifier = ?;",
                params: [plan.workspace.id, candidate.scheme, candidate.normalizedValue]
            ) { $0.string(at: 0) ?? "" }
            if owners.contains(where: { $0 != accountID }) { return false }
        }
        switch plan.advisoryIdentity {
        case .resolved(let expected):
            return expected == accountID
        case .noMatch:
            return true
        case .ambiguous, .conflict:
            return false
        }
    }

    private func insert(reviewedPartialPlan reviewed: ReviewedPartialImportPlanDTO) throws {
        let plan = reviewed.basePlan
        let history = plan.historyTemplate
        guard let normalizedDocument = history.normalizedDocument,
              let start = plan.declaredStatementStartISO,
              let end = plan.declaredStatementEndISO,
              let openingMinor = plan.openingBalanceMinor,
              let openingDecimal = plan.openingBalanceDecimal,
              let closingMinor = plan.closingBalanceMinor,
              let closingDecimal = plan.closingBalanceDecimal else {
            throw RepositoryError.relationshipViolation("Reviewed partial import is missing document evidence.")
        }

        var observations = [(String, ConfirmedImportIdentifierCandidateDTO)]()
        for candidate in plan.identifiers {
            let existing = try db.query(
                sql: "SELECT id FROM account_identifiers WHERE account_id = ? AND workspace_id = ? AND scheme = ? AND identifier = ? LIMIT 1;",
                params: [reviewed.existingAccountId, plan.workspace.id, candidate.scheme, candidate.normalizedValue]
            ) { $0.string(at: 0) ?? "" }.first
            let ownershipID = existing ?? UUID().uuidString
            if existing == nil {
                try db.executePrepared(
                    sql: "INSERT INTO account_identifiers (id, account_id, workspace_id, scheme, identifier, provenance, created_at) VALUES (?,?,?,?,?,?,?);",
                    params: [ownershipID, reviewed.existingAccountId, plan.workspace.id, candidate.scheme, candidate.normalizedValue, Self.provenanceJSON(candidate), history.completedAtISO]
                )
            }
            observations.append((ownershipID, candidate))
        }

        let document = history.document
        try db.executePrepared(sql: "INSERT INTO import_sessions (id, workspace_id, user_visible_name, started_at, validation_status, created_at, reader_version, parser_version, layout_version) VALUES (?,?,?,?,?,?,?,?,?);", params: [history.importSession.id, history.importSession.workspaceId, history.importSession.userVisibleName ?? NSNull(), history.importSession.startedAtISO, history.importSession.validationStatus, history.importSession.startedAtISO, history.importSession.readerVersion ?? NSNull(), history.importSession.parserVersion ?? NSNull(), history.importSession.layoutVersion ?? NSNull()])
        try db.executePrepared(sql: "INSERT INTO documents (id, workspace_id, import_session_id, filename, mime_type, size_bytes, sha256, storage_path, extracted_text_snippet, page_count, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?);", params: [document.id, document.workspaceId, document.importSessionId, document.filename, document.mimeType ?? NSNull(), document.sizeBytes ?? NSNull(), document.legacyRawTextSHA256, NSNull(), NSNull(), NSNull(), document.createdAtISO])
        for fingerprint in history.fingerprints {
            try db.executePrepared(sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, fingerprint_data, created_at, is_duplicate_authority) VALUES (?,?,?,?,?,?,?,?);", params: [fingerprint.id, fingerprint.documentId, fingerprint.importSessionId, fingerprint.algorithm, fingerprint.fingerprint, fingerprint.fingerprintData ?? NSNull(), fingerprint.createdAtISO, fingerprint.isDuplicateAuthority ? 1 : 0])
        }
        try db.executePrepared(sql: "INSERT INTO normalized_documents (id, import_session_id, document_id, normalized_json, schema_version, created_at, profile_id, profile_version) VALUES (?,?,?,?,?,?,?,?);", params: [normalizedDocument.id, normalizedDocument.importSessionId, normalizedDocument.documentId, "{\"profile\":\"\(normalizedDocument.profileId)\",\"version\":\"\(normalizedDocument.profileVersion)\"}", "trusted-source-v1", history.completedAtISO, normalizedDocument.profileId, normalizedDocument.profileVersion])
        for row in history.normalizedRows {
            try db.executePrepared(sql: "INSERT INTO normalized_rows (id, normalized_document_id, row_index, row_original, extracted_text, created_at, record_digest) VALUES (?,?,?,?,?,?,?);", params: [row.id, row.normalizedDocumentId, row.sourceOrdinal, "{\"digest\":\"\(row.digest)\"}", NSNull(), history.completedAtISO, row.digest])
        }

        for (ownershipID, candidate) in observations {
            try db.executePrepared(sql: "INSERT INTO account_identifier_observations (id, ownership_id, import_session_id, document_id, parser_provenance_code, association_authority_code, created_at) VALUES (?,?,?,?,?,?,?);", params: [UUID().uuidString, ownershipID, history.importSession.id, history.document.id, candidate.provenanceCode, "confirmed-partial-import", history.completedAtISO])
        }

        for row in reviewed.rows {
            guard let template = plan.transactionTemplates.first(where: {
                $0.transaction.rawRows.first?.normalizedRowId == row.normalizedRowId
            }) else {
                throw RepositoryError.relationshipViolation("Reviewed row has no incoming transaction template.")
            }
            let transactionID: String
            let eventIdentityID: String
            switch row.disposition {
            case .recognizedExisting:
                guard let existingTransactionID = row.expectedTransactionId,
                      let existingEventIdentityID = row.expectedEventIdentityId else {
                    throw RepositoryError.relationshipViolation("Recognized row is missing its durable owner.")
                }
                transactionID = existingTransactionID
                eventIdentityID = existingEventIdentityID
                try db.executePrepared(
                    sql: "INSERT INTO transaction_raw_rows (id, transaction_id, normalized_row_id, contribution_type, created_at) VALUES (?,?,?,?,?);",
                    params: ["partial-source-\(history.importSession.id)-\(row.sourceOrdinal)", transactionID, row.normalizedRowId, PartialImportRowDisposition.recognizedExisting.rawValue, history.completedAtISO]
                )
            case .importedUnique:
                let transaction = finalTransaction(
                    template.transaction,
                    accountID: reviewed.existingAccountId,
                    history: history
                )
                transactionID = transaction.id
                eventIdentityID = "partial-event-\(transaction.id)"
                try db.executePrepared(sql: "INSERT INTO transactions (id, workspace_id, account_id, import_session_id, document_id, original_row_id, posted_date, value_date, description, payee, reference, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, is_reconciled, is_trusted, trusted_at, created_at, updated_at, financial_date_role, statement_timezone_evidence) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);", params: [transaction.id, transaction.workspaceId, transaction.accountId ?? NSNull(), transaction.importSessionId ?? NSNull(), transaction.documentId ?? NSNull(), row.normalizedRowId, transaction.postedDateISO, transaction.valueDateISO ?? NSNull(), transaction.description ?? NSNull(), transaction.payee ?? NSNull(), transaction.reference ?? NSNull(), transaction.nativeCurrency, transaction.amountMinor, transaction.amountDecimal, transaction.direction, transaction.runningBalanceMinor ?? NSNull(), transaction.isReconciled ? 1 : 0, transaction.isTrusted ? 1 : 0, transaction.trustedAtISO ?? NSNull(), transaction.createdAtISO, transaction.updatedAtISO ?? NSNull(), transaction.financialDateRole, transaction.statementTimezoneEvidence])
                try db.executePrepared(sql: "INSERT INTO transaction_raw_rows (id, transaction_id, normalized_row_id, contribution_type, created_at) VALUES (?,?,?,?,?);", params: [template.transaction.rawRows[0].id, transaction.id, row.normalizedRowId, PartialImportRowDisposition.importedUnique.rawValue, transaction.createdAtISO])
                try db.executePrepared(sql: "INSERT INTO transaction_event_identities (id, transaction_id, account_id, document_id, import_session_id, algorithm, digest, created_at) VALUES (?,?,?,?,?,?,?,?);", params: [eventIdentityID, transaction.id, reviewed.existingAccountId, history.document.id, history.importSession.id, row.eventAlgorithm, row.eventDigest, history.completedAtISO])
            }
            try db.executePrepared(
                sql: "INSERT INTO incoming_row_dispositions (id, import_session_id, document_id, normalized_row_id, source_ordinal, disposition_code, transaction_id, transaction_event_identity_id, statement_date, financial_date_role, statement_timezone_evidence, native_currency, amount_minor, amount_decimal, direction, running_balance_minor, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);",
                params: ["partial-disposition-\(history.importSession.id)-\(row.sourceOrdinal)", history.importSession.id, history.document.id, row.normalizedRowId, row.sourceOrdinal, row.disposition.rawValue, transactionID, eventIdentityID, row.statementDateISO, row.financialDateRole, row.timezoneEvidence, row.nativeCurrency, row.amountMinor, row.amountDecimal, row.direction, row.runningBalanceMinor, history.completedAtISO]
            )
        }

        let attempt = ImportAttemptDTO(
            id: history.successfulAttempt.id,
            workspaceId: plan.workspace.id,
            createdAtISO: history.completedAtISO,
            outcomeCode: ImportAttemptOutcome.partialImportCommitted.rawValue,
            coverageCode: ImportAttemptCoverage.allRowsSupportedAxisUPIReviewed.rawValue,
            accountDecisionCode: history.successfulAttempt.accountDecisionCode,
            guidanceCode: ImportAttemptGuidance.partialImportCompleted.rawValue,
            persistenceCode: ImportAttemptPersistence.committed.rawValue,
            transactionCount: reviewed.importedCount,
            accountId: reviewed.existingAccountId,
            importSessionId: history.importSession.id,
            documentId: history.document.id,
            sourceRowCount: reviewed.sourceRowCount,
            importedTransactionCount: reviewed.importedCount,
            recognizedExistingRowCount: reviewed.recognizedCount,
            blockedRowCount: reviewed.blockedCount
        )
        try db.executePrepared(sql: "INSERT INTO import_attempts (id, workspace_id, created_at, outcome_code, coverage_code, account_decision_code, guidance_code, persistence_code, transaction_count, account_id, import_session_id, document_id, related_import_session_id, source_row_count, imported_transaction_count, recognized_existing_row_count, blocked_row_count) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);", params: [attempt.id, attempt.workspaceId, attempt.createdAtISO, attempt.outcomeCode, attempt.coverageCode, attempt.accountDecisionCode, attempt.guidanceCode, attempt.persistenceCode, attempt.transactionCount, attempt.accountId ?? NSNull(), attempt.importSessionId ?? NSNull(), attempt.documentId ?? NSNull(), NSNull(), attempt.sourceRowCount ?? NSNull(), attempt.importedTransactionCount ?? NSNull(), attempt.recognizedExistingRowCount ?? NSNull(), attempt.blockedRowCount ?? NSNull()])
        try db.executePrepared(
            sql: "INSERT INTO partial_import_summaries (import_session_id, document_id, plan_digest_algorithm, plan_digest, statement_start_date, statement_end_date, native_currency, source_row_count, imported_transaction_count, recognized_existing_row_count, blocked_row_count, opening_balance_minor, opening_balance_decimal, closing_balance_minor, closing_balance_decimal, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);",
            params: [history.importSession.id, history.document.id, reviewed.digestAlgorithm, reviewed.digest, start, end, "INR", reviewed.sourceRowCount, reviewed.importedCount, reviewed.recognizedCount, reviewed.blockedCount, openingMinor, openingDecimal, closingMinor, closingDecimal, history.completedAtISO]
        )
        try db.executePrepared(sql: "UPDATE import_sessions SET validation_status = ?, completed_at = ?, updated_at = ? WHERE id = ?;", params: ["passed", history.completedAtISO, history.completedAtISO, history.importSession.id])
    }

    private func consumePlan(_ id: String) -> Bool {
        consumedPlanLock.lock()
        defer { consumedPlanLock.unlock() }
        return consumedPlanIDs.insert(id).inserted
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

    private func hasValidTrustedProvenance(_ plan: ConfirmedImportPlanDTO) -> Bool {
        guard let document = plan.historyTemplate.normalizedDocument,
              !document.profileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !document.profileVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        let rows = plan.historyTemplate.normalizedRows
        guard Set(rows.map(\.id)).count == rows.count,
              rows.allSatisfy({
                  !$0.id.isEmpty &&
                  $0.normalizedDocumentId == document.id &&
                  $0.sourceOrdinal > 0 &&
                  !$0.digest.isEmpty
              }) else {
            return false
        }
        let knownRowIDs = Set(rows.map(\.id))
        return plan.transactionTemplates.allSatisfy { template in
            let rawRows = template.transaction.rawRows
            return !rawRows.isEmpty &&
                Set(rawRows.map(\.normalizedRowId)).count == rawRows.count &&
                rawRows.allSatisfy { !$0.id.isEmpty && !$0.normalizedRowId.isEmpty && knownRowIDs.contains($0.normalizedRowId) }
        }
    }
}
