import Foundation

final class SQLiteSalaryRepository: SalaryRepository {
    private let db: SQLiteDatabase
    private let generationToken: ProviderGenerationToken

    init(db: SQLiteDatabase, generationToken: ProviderGenerationToken) {
        self.db = db
        self.generationToken = generationToken
    }

    func commitImportedSalary(_ plan: SalaryImportPlanDTO) -> SalaryImportRepositoryResult {
        guard plan.providerGeneration == generationToken else { return .staleProviderGeneration }
        do { try plan.history.validateFingerprints() } catch { return .repositoryIntegrityConflict }
        do { try SalaryPersistenceDTOValidator.validate(statement: plan.statement) } catch { return .repositoryIntegrityConflict }
        guard let authority = plan.history.duplicateAuthorityFingerprint,
              let normalized = plan.history.normalizedDocument,
              plan.workspace.id == plan.statement.workspaceId,
              plan.history.document.workspaceId == plan.workspace.id,
              plan.history.importSession.workspaceId == plan.workspace.id,
              plan.history.document.importSessionId == plan.history.importSession.id,
              plan.statement.documentId == plan.history.document.id,
              plan.statement.importSessionId == plan.history.importSession.id,
              plan.statement.normalizedDocumentId == normalized.id,
              plan.statement.sourceFingerprintAlgorithm == authority.algorithm,
              plan.statement.sourceFingerprintDigest == authority.fingerprint,
              plan.statement.components.allSatisfy({ $0.salaryStatementId == plan.statement.id }) else {
            return .repositoryIntegrityConflict
        }
        do {
            try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
            if let duplicate = try duplicate(algorithm: authority.algorithm, digest: authority.fingerprint) {
                try db.execute(sql: "COMMIT;")
                return .exactSourceDuplicate(duplicate)
            }
            try insert(plan, normalized: normalized)
            try db.execute(sql: "COMMIT;")
            return .committed(statementId: plan.statement.id, importSessionId: plan.history.importSession.id, documentId: plan.history.document.id)
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

    func snapshot(workspaceId: String) throws -> SalaryRepositorySnapshotDTO {
        let statements = try db.query(sql: """
            SELECT id, workspace_id, document_id, import_session_id, normalized_document_id,
                   source_fingerprint_algorithm, source_fingerprint_digest, source_authority,
                   parser_profile_id, parser_profile_version, financial_period, print_date,
                   document_kind, native_currency, printed_earnings_minor, printed_earnings_decimal,
                   printed_deductions_present, printed_deductions_minor, printed_deductions_decimal,
                   printed_net_minor, printed_net_decimal, printed_payment_minor, printed_payment_decimal, created_at
            FROM salary_statements WHERE workspace_id = ?
            ORDER BY financial_period, created_at, id;
            """, params: [workspaceId]) { row -> SalaryStatementDTO in
                let statementID = row.string(at: 0) ?? ""
                let components = try self.components(statementID: statementID)
                return SalaryStatementDTO(
                    id: statementID,
                    workspaceId: row.string(at: 1) ?? "",
                    documentId: row.string(at: 2) ?? "",
                    importSessionId: row.string(at: 3) ?? "",
                    normalizedDocumentId: row.string(at: 4) ?? "",
                    sourceFingerprintAlgorithm: row.string(at: 5) ?? "",
                    sourceFingerprintDigest: row.string(at: 6) ?? "",
                    sourceAuthorityCode: row.string(at: 7) ?? "",
                    parserProfileId: row.string(at: 8) ?? "",
                    parserProfileVersion: row.string(at: 9) ?? "",
                    financialPeriodISO: row.string(at: 10) ?? "",
                    printDateISO: row.string(at: 11),
                    documentKindCode: row.string(at: 12) ?? "",
                    nativeCurrency: row.string(at: 13) ?? "",
                    printedEarningsMinor: row.int64(at: 14) ?? 0,
                    printedEarningsDecimal: row.string(at: 15) ?? "",
                    printedDeductionsMinor: (row.int64(at: 16) == 1) ? row.int64(at: 17) : nil,
                    printedDeductionsDecimal: (row.int64(at: 16) == 1) ? row.string(at: 18) : nil,
                    printedNetMinor: row.int64(at: 19) ?? 0,
                    printedNetDecimal: row.string(at: 20) ?? "",
                    printedPaymentMinor: row.int64(at: 21) ?? 0,
                    printedPaymentDecimal: row.string(at: 22) ?? "",
                    createdAtISO: row.string(at: 23) ?? "",
                    components: components
                )
            }
        return SalaryRepositorySnapshotDTO(statements: statements)
    }

    private func duplicate(algorithm: String, digest: String) throws -> PriorImportedStatementDTO? {
        try db.query(sql: """
            SELECT f.import_session_id, s.completed_at
            FROM document_fingerprints f
            JOIN import_sessions s ON s.id = f.import_session_id
            WHERE f.algorithm = ? AND f.fingerprint = ? AND f.is_duplicate_authority = 1
            LIMIT 1;
            """, params: [algorithm, digest]) { row in
                PriorImportedStatementDTO(
                    importSessionId: row.string(at: 0) ?? "",
                    completedAtISO: row.string(at: 1),
                    transactionCount: 0,
                    accountId: nil,
                    accountDisplayName: nil
                )
            }.first
    }

    private func insert(_ plan: SalaryImportPlanDTO, normalized: NormalizedDocumentDTO) throws {
        let history = plan.history
        let document = history.document
        let statement = plan.statement
        try db.executePrepared(sql: "INSERT INTO workspaces (id, name, created_at, updated_at) VALUES (?,?,?,?) ON CONFLICT(id) DO UPDATE SET name = excluded.name, updated_at = excluded.updated_at;", params: [plan.workspace.id, plan.workspace.name, plan.workspace.createdAtISO, plan.workspace.updatedAtISO ?? NSNull()])
        try db.executePrepared(sql: "INSERT INTO import_sessions (id, workspace_id, user_visible_name, started_at, validation_status, created_at, reader_version, parser_version, layout_version) VALUES (?,?,?,?,?,?,?,?,?);", params: [history.importSession.id, history.importSession.workspaceId, history.importSession.userVisibleName ?? NSNull(), history.importSession.startedAtISO, history.importSession.validationStatus, history.importSession.startedAtISO, history.importSession.readerVersion ?? NSNull(), history.importSession.parserVersion ?? NSNull(), history.importSession.layoutVersion ?? NSNull()])
        try db.executePrepared(sql: "INSERT INTO documents (id, workspace_id, import_session_id, filename, mime_type, size_bytes, sha256, storage_path, extracted_text_snippet, page_count, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?);", params: [document.id, document.workspaceId, document.importSessionId, document.filename, document.mimeType ?? NSNull(), document.sizeBytes ?? NSNull(), document.legacyRawTextSHA256, NSNull(), NSNull(), NSNull(), document.createdAtISO])
        for fingerprint in history.fingerprints {
            try db.executePrepared(sql: "INSERT INTO document_fingerprints (id, document_id, import_session_id, algorithm, fingerprint, fingerprint_data, created_at, is_duplicate_authority) VALUES (?,?,?,?,?,?,?,?);", params: [fingerprint.id, fingerprint.documentId, fingerprint.importSessionId, fingerprint.algorithm, fingerprint.fingerprint, fingerprint.fingerprintData ?? NSNull(), fingerprint.createdAtISO, fingerprint.isDuplicateAuthority ? 1 : 0])
        }
        try db.executePrepared(sql: "INSERT INTO normalized_documents (id, import_session_id, document_id, normalized_json, schema_version, created_at, profile_id, profile_version) VALUES (?,?,?,?,?,?,?,?);", params: [normalized.id, normalized.importSessionId, normalized.documentId, "{\"profile\":\"qatar-airways.salary.pdf\",\"version\":\"1\"}", "trusted-source-v1", history.completedAtISO, normalized.profileId, normalized.profileVersion])
        try db.executePrepared(sql: """
            INSERT INTO salary_statements (
              id, workspace_id, document_id, import_session_id, normalized_document_id,
              source_fingerprint_algorithm, source_fingerprint_digest, source_authority,
              parser_profile_id, parser_profile_version, financial_period, print_date,
              document_kind, native_currency, printed_earnings_minor, printed_earnings_decimal,
              printed_deductions_present, printed_deductions_minor, printed_deductions_decimal,
              printed_net_minor, printed_net_decimal, printed_payment_minor, printed_payment_decimal, created_at
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);
            """, params: [
                statement.id, statement.workspaceId, statement.documentId, statement.importSessionId,
                statement.normalizedDocumentId, statement.sourceFingerprintAlgorithm, statement.sourceFingerprintDigest,
                statement.sourceAuthorityCode, statement.parserProfileId, statement.parserProfileVersion,
                statement.financialPeriodISO, statement.printDateISO ?? NSNull(), statement.documentKindCode,
                statement.nativeCurrency, statement.printedEarningsMinor, statement.printedEarningsDecimal,
                statement.printedDeductionsMinor == nil ? 0 : 1, statement.printedDeductionsMinor ?? NSNull(),
                statement.printedDeductionsDecimal ?? NSNull(), statement.printedNetMinor, statement.printedNetDecimal,
                statement.printedPaymentMinor, statement.printedPaymentDecimal, statement.createdAtISO
            ])
        for component in statement.components {
            try db.executePrepared(sql: "INSERT INTO salary_components (id, salary_statement_id, side, source_ordinal, source_label, amount_currency, amount_minor, amount_decimal) VALUES (?,?,?,?,?,?,?,?);", params: [component.id, component.salaryStatementId, component.sideCode, component.sourceOrdinal, component.sourceLabel, component.amountCurrency, component.amountMinor, component.amountDecimal])
        }
        let attempt = history.successfulAttempt
        try db.executePrepared(sql: "INSERT INTO import_attempts (id, workspace_id, created_at, outcome_code, coverage_code, account_decision_code, guidance_code, persistence_code, transaction_count, account_id, import_session_id, document_id, related_import_session_id, source_row_count, imported_transaction_count, recognized_existing_row_count, blocked_row_count) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);", params: [attempt.id, attempt.workspaceId, attempt.createdAtISO, attempt.outcomeCode, attempt.coverageCode, attempt.accountDecisionCode, attempt.guidanceCode, attempt.persistenceCode, attempt.transactionCount, attempt.accountId ?? NSNull(), attempt.importSessionId ?? NSNull(), attempt.documentId ?? NSNull(), attempt.relatedImportSessionId ?? NSNull(), attempt.sourceRowCount ?? NSNull(), attempt.importedTransactionCount ?? NSNull(), attempt.recognizedExistingRowCount ?? NSNull(), attempt.blockedRowCount ?? NSNull()])
        try db.executePrepared(sql: "UPDATE import_sessions SET validation_status = ?, completed_at = ?, updated_at = ? WHERE id = ?;", params: ["passed", history.completedAtISO, history.completedAtISO, history.importSession.id])
    }

    private func components(statementID: String) throws -> [SalaryComponentDTO] {
        try db.query(sql: "SELECT id, salary_statement_id, side, source_ordinal, source_label, amount_currency, amount_minor, amount_decimal FROM salary_components WHERE salary_statement_id = ? ORDER BY CASE side WHEN 'earning' THEN 0 ELSE 1 END, source_ordinal;", params: [statementID]) { row in
            SalaryComponentDTO(id: row.string(at: 0) ?? "", salaryStatementId: row.string(at: 1) ?? "", sideCode: row.string(at: 2) ?? "", sourceOrdinal: Int(row.int64(at: 3) ?? 0), sourceLabel: row.string(at: 4) ?? "", amountCurrency: row.string(at: 5) ?? "", amountMinor: row.int64(at: 6) ?? 0, amountDecimal: row.string(at: 7) ?? "")
        }
    }
}

final class SQLiteFundingPlanRepository: FundingPlanRepository {
    private let db: SQLiteDatabase
    init(db: SQLiteDatabase) { self.db = db }

    func plans(workspaceId: String) throws -> [FundingPlanDTO] {
        try db.query(sql: """
            SELECT id, workspace_id, plan_month, rollover_source_plan_id,
                   expected_fixed_minor, expected_fixed_decimal, expected_fixed_provenance,
                   expected_variable_minor, expected_variable_decimal, expected_variable_provenance,
                   expected_deductions_minor, expected_deductions_decimal, expected_deductions_provenance,
                   configured_fee_minor, configured_fee_decimal, configured_fee_provenance,
                   fx_inr_per_qar_decimal, fx_observation_date,
                   planned_investment_minor, planned_investment_decimal, planned_investment_provenance, updated_at
            FROM funding_plans WHERE workspace_id = ? ORDER BY plan_month;
            """, params: [workspaceId]) { row in
                let id = row.string(at: 0) ?? ""
                return FundingPlanDTO(
                    id: id, workspaceId: row.string(at: 1) ?? "", planMonthISO: row.string(at: 2) ?? "",
                    rolloverSourcePlanId: row.string(at: 3), expectedFixedMinor: row.int64(at: 4) ?? 0,
                    expectedFixedDecimal: row.string(at: 5) ?? "", expectedFixedProvenance: row.string(at: 6) ?? "",
                    expectedVariableMinor: row.int64(at: 7) ?? 0, expectedVariableDecimal: row.string(at: 8) ?? "",
                    expectedVariableProvenance: row.string(at: 9) ?? "", expectedDeductionsMinor: row.int64(at: 10) ?? 0,
                    expectedDeductionsDecimal: row.string(at: 11) ?? "", expectedDeductionsProvenance: row.string(at: 12) ?? "",
                    configuredFeeMinor: row.int64(at: 13) ?? 0, configuredFeeDecimal: row.string(at: 14) ?? "",
                    configuredFeeProvenance: row.string(at: 15) ?? "", fxINRPerQARDecimal: row.string(at: 16),
                    fxObservationDateISO: row.string(at: 17), plannedInvestmentMinor: row.int64(at: 18) ?? 0,
                    plannedInvestmentDecimal: row.string(at: 19) ?? "", plannedInvestmentProvenance: row.string(at: 20) ?? "",
                    updatedAtISO: row.string(at: 21) ?? "", balances: try self.balances(planID: id),
                    commitments: try self.commitments(planID: id)
                )
            }
    }

    func savePlan(_ plan: FundingPlanDTO) throws -> FundingPlanDTO {
        try SalaryPersistenceDTOValidator.validate(plan: plan)
        try validateRelationships(plan)
        try db.execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            try db.executePrepared(sql: """
                INSERT INTO funding_plans (
                  id, workspace_id, plan_month, rollover_source_plan_id,
                  expected_fixed_minor, expected_fixed_decimal, expected_fixed_provenance,
                  expected_variable_minor, expected_variable_decimal, expected_variable_provenance,
                  expected_deductions_minor, expected_deductions_decimal, expected_deductions_provenance,
                  configured_fee_minor, configured_fee_decimal, configured_fee_provenance,
                  fx_inr_per_qar_decimal, fx_observation_date, fx_provenance,
                  planned_investment_minor, planned_investment_decimal, planned_investment_provenance, updated_at
                ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                ON CONFLICT(id) DO UPDATE SET
                  rollover_source_plan_id=excluded.rollover_source_plan_id,
                  expected_fixed_minor=excluded.expected_fixed_minor, expected_fixed_decimal=excluded.expected_fixed_decimal, expected_fixed_provenance=excluded.expected_fixed_provenance,
                  expected_variable_minor=excluded.expected_variable_minor, expected_variable_decimal=excluded.expected_variable_decimal, expected_variable_provenance=excluded.expected_variable_provenance,
                  expected_deductions_minor=excluded.expected_deductions_minor, expected_deductions_decimal=excluded.expected_deductions_decimal, expected_deductions_provenance=excluded.expected_deductions_provenance,
                  configured_fee_minor=excluded.configured_fee_minor, configured_fee_decimal=excluded.configured_fee_decimal, configured_fee_provenance=excluded.configured_fee_provenance,
                  fx_inr_per_qar_decimal=excluded.fx_inr_per_qar_decimal, fx_observation_date=excluded.fx_observation_date, fx_provenance=excluded.fx_provenance,
                  planned_investment_minor=excluded.planned_investment_minor, planned_investment_decimal=excluded.planned_investment_decimal, planned_investment_provenance=excluded.planned_investment_provenance,
                  updated_at=excluded.updated_at;
                """, params: [
                    plan.id, plan.workspaceId, plan.planMonthISO, plan.rolloverSourcePlanId ?? NSNull(),
                    plan.expectedFixedMinor, plan.expectedFixedDecimal, plan.expectedFixedProvenance,
                    plan.expectedVariableMinor, plan.expectedVariableDecimal, plan.expectedVariableProvenance,
                    plan.expectedDeductionsMinor, plan.expectedDeductionsDecimal, plan.expectedDeductionsProvenance,
                    plan.configuredFeeMinor, plan.configuredFeeDecimal, plan.configuredFeeProvenance,
                    plan.fxINRPerQARDecimal ?? NSNull(), plan.fxObservationDateISO ?? NSNull(), plan.fxINRPerQARDecimal == nil ? NSNull() : "user_entered",
                    plan.plannedInvestmentMinor, plan.plannedInvestmentDecimal, plan.plannedInvestmentProvenance, plan.updatedAtISO
                ])
            try db.executePrepared(sql: "DELETE FROM funding_plan_balances WHERE funding_plan_id = ?;", params: [plan.id])
            try db.executePrepared(sql: "DELETE FROM funding_plan_commitments WHERE funding_plan_id = ?;", params: [plan.id])
            for balance in plan.balances {
                try db.executePrepared(sql: "INSERT INTO funding_plan_balances (id, funding_plan_id, source_ordinal, account_id, native_currency, included, amount_currency, amount_minor, amount_decimal, provenance, carried_source_plan_id, captured_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?);", params: [balance.id, balance.planId, balance.sourceOrdinal, balance.accountId, balance.nativeCurrency, balance.included ? 1 : 0, balance.amountCurrency ?? NSNull(), balance.amountMinor ?? NSNull(), balance.amountDecimal ?? NSNull(), balance.provenanceCode, balance.carriedSourcePlanId ?? NSNull(), balance.capturedAtISO ?? NSNull()])
            }
            for commitment in plan.commitments {
                try db.executePrepared(sql: "INSERT INTO funding_plan_commitments (id, funding_plan_id, region, source_ordinal, label, amount_currency, amount_minor, amount_decimal, included, funding_account_id, provenance, carried_source_plan_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?);", params: [commitment.id, commitment.planId, commitment.regionCode, commitment.sourceOrdinal, commitment.label, commitment.amountCurrency, commitment.amountMinor, commitment.amountDecimal, commitment.included ? 1 : 0, commitment.fundingAccountId ?? NSNull(), commitment.provenanceCode, commitment.carriedSourcePlanId ?? NSNull()])
            }
            try db.execute(sql: "COMMIT;")
            return plan
        } catch {
            try? db.execute(sql: "ROLLBACK;")
            throw error
        }
    }

    private func validateRelationships(_ plan: FundingPlanDTO) throws {
        let workspaceExists = try db.query(sql: "SELECT id FROM workspaces WHERE id = ? LIMIT 1;", params: [plan.workspaceId]) { $0.string(at: 0) }.first != nil
        guard workspaceExists else { throw RepositoryError.relationshipViolation("Funding plan workspace is invalid.") }
        if let existing = try db.query(sql: "SELECT workspace_id, plan_month FROM funding_plans WHERE id = ? LIMIT 1;", params: [plan.id], map: { (workspace: $0.string(at: 0) ?? "", month: $0.string(at: 1) ?? "") }).first { guard existing.workspace == plan.workspaceId, existing.month == plan.planMonthISO else { throw RepositoryError.relationshipViolation("Funding plan identity is immutable.") } }
        let monthCollision = try db.query(sql: "SELECT id FROM funding_plans WHERE workspace_id = ? AND plan_month = ? AND id <> ? LIMIT 1;", params: [plan.workspaceId, plan.planMonthISO, plan.id]) { $0.string(at: 0) }.first
        guard monthCollision == nil else { throw RepositoryError.relationshipViolation("Only one funding plan may exist for a workspace month.") }
        if let sourceID = plan.rolloverSourcePlanId { guard let source = try db.query(sql: "SELECT workspace_id, plan_month FROM funding_plans WHERE id = ? LIMIT 1;", params: [sourceID], map: { (workspace: $0.string(at: 0) ?? "", month: $0.string(at: 1) ?? "") }).first, source.workspace == plan.workspaceId, source.month < plan.planMonthISO else { throw RepositoryError.relationshipViolation("Funding plan rollover source is invalid.") } }
        func account(_ id: String) throws -> (workspace: String, currency: String)? { try db.query(sql: "SELECT workspace_id, native_currency FROM accounts WHERE id = ? LIMIT 1;", params: [id]) { (workspace: $0.string(at: 0) ?? "", currency: $0.string(at: 1) ?? "") }.first }
        for balance in plan.balances { guard balance.planId == plan.id, let linked = try account(balance.accountId), linked.workspace == plan.workspaceId, linked.currency == balance.nativeCurrency else { throw RepositoryError.relationshipViolation("Funding plan balance account relationship is invalid.") } }
        for commitment in plan.commitments { guard commitment.planId == plan.id else { throw RepositoryError.relationshipViolation("Funding commitment relationship is invalid.") }; if let accountID = commitment.fundingAccountId { guard let linked = try account(accountID), linked.workspace == plan.workspaceId, linked.currency == commitment.amountCurrency else { throw RepositoryError.relationshipViolation("Funding commitment account relationship is invalid.") } } }
    }

    private func balances(planID: String) throws -> [FundingPlanBalanceDTO] {
        try db.query(sql: "SELECT id, funding_plan_id, source_ordinal, account_id, native_currency, included, amount_currency, amount_minor, amount_decimal, provenance, carried_source_plan_id, captured_at FROM funding_plan_balances WHERE funding_plan_id = ? ORDER BY source_ordinal;", params: [planID]) { row in
            FundingPlanBalanceDTO(id: row.string(at: 0) ?? "", planId: row.string(at: 1) ?? "", sourceOrdinal: Int(row.int64(at: 2) ?? 0), accountId: row.string(at: 3) ?? "", nativeCurrency: row.string(at: 4) ?? "", included: row.int64(at: 5) == 1, amountCurrency: row.string(at: 6), amountMinor: row.int64(at: 7), amountDecimal: row.string(at: 8), provenanceCode: row.string(at: 9) ?? "", carriedSourcePlanId: row.string(at: 10), capturedAtISO: row.string(at: 11))
        }
    }

    private func commitments(planID: String) throws -> [FundingPlanCommitmentDTO] {
        try db.query(sql: "SELECT id, funding_plan_id, region, source_ordinal, label, amount_currency, amount_minor, amount_decimal, included, funding_account_id, provenance, carried_source_plan_id FROM funding_plan_commitments WHERE funding_plan_id = ? ORDER BY CASE region WHEN 'qatar' THEN 0 ELSE 1 END, source_ordinal;", params: [planID]) { row in
            FundingPlanCommitmentDTO(id: row.string(at: 0) ?? "", planId: row.string(at: 1) ?? "", regionCode: row.string(at: 2) ?? "", sourceOrdinal: Int(row.int64(at: 3) ?? 0), label: row.string(at: 4) ?? "", amountCurrency: row.string(at: 5) ?? "", amountMinor: row.int64(at: 6) ?? 0, amountDecimal: row.string(at: 7) ?? "", included: row.int64(at: 8) == 1, fundingAccountId: row.string(at: 9), provenanceCode: row.string(at: 10) ?? "", carriedSourcePlanId: row.string(at: 11))
        }
    }
}
