import Foundation
import Testing
@testable import LedgerForge

@MainActor
struct SalaryPersistenceHydrationTests {
    @Test func migrationV16IsAdditiveOnFreshAndV15Databases() throws {
        let folder = try temporaryFolder("migration")
        defer { try? FileManager.default.removeItem(at: folder) }
        let fresh = SQLiteDatabase(path: folder.appendingPathComponent("fresh.sqlite").path)
        try fresh.runMigrations(allMigrations)
        #expect(try fresh.queryInt("SELECT MAX(version) FROM schema_migrations;") == 16)
        #expect(try fresh.queryInt("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('salary_statements','salary_components','funding_plans','funding_plan_balances','funding_plan_commitments');") == 5)
        try fresh.checkpointAndClose()

        let upgraded = SQLiteDatabase(path: folder.appendingPathComponent("upgrade.sqlite").path)
        try upgraded.runMigrations(Array(allMigrations.prefix(15)))
        let v15Checksums = try upgraded.query(sql: "SELECT version, checksum FROM schema_migrations ORDER BY version;") { ($0.int64(at: 0), $0.string(at: 1)) }
        try upgraded.runMigrations(allMigrations)
        #expect(try upgraded.queryInt("SELECT MAX(version) FROM schema_migrations;") == 16)
        let preserved = try upgraded.query(sql: "SELECT version, checksum FROM schema_migrations WHERE version <= 15 ORDER BY version;") { ($0.int64(at: 0), $0.string(at: 1)) }
        let v15HistoryPreserved = preserved.elementsEqual(v15Checksums, by: { $0.0 == $1.0 && $0.1 == $1.1 })
        #expect(v15HistoryPreserved)
        try upgraded.checkpointAndClose()
    }

    @Test func salaryActualParityDuplicateMultiplicityAndReopen() throws {
        let setup = try providers("salary")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        let sqliteFirst = salaryPlan(token: setup.sqlite.generationToken, suffix: "first", digest: String(repeating: "a", count: 64), kind: "regular_salary", deductionsPresent: true)
        let memoryFirst = salaryPlan(token: setup.memory.generationToken, suffix: "first", digest: String(repeating: "a", count: 64), kind: "regular_salary", deductionsPresent: true)
        #expect(isCommitted(setup.sqlite.salaryRepo.commitImportedSalary(sqliteFirst)))
        #expect(isCommitted(setup.memory.salaryRepo.commitImportedSalary(memoryFirst)))
        #expect(try setup.sqlite.salaryRepo.snapshot(workspaceId: "workspace-salary") == setup.memory.salaryRepo.snapshot(workspaceId: "workspace-salary"))

        let sqliteSecond = salaryPlan(token: setup.sqlite.generationToken, suffix: "second", digest: String(repeating: "b", count: 64), kind: "adhoc_payment", deductionsPresent: false)
        let memorySecond = salaryPlan(token: setup.memory.generationToken, suffix: "second", digest: String(repeating: "b", count: 64), kind: "adhoc_payment", deductionsPresent: false)
        #expect(isCommitted(setup.sqlite.salaryRepo.commitImportedSalary(sqliteSecond)))
        #expect(isCommitted(setup.memory.salaryRepo.commitImportedSalary(memorySecond)))
        let snapshot = try setup.sqlite.salaryRepo.snapshot(workspaceId: "workspace-salary")
        #expect(snapshot.statements.count == 2)
        #expect(snapshot.statements.allSatisfy { $0.financialPeriodISO == "2026-03" })
        #expect(snapshot.statements.first?.components.map(\.sourceLabel) == ["Basic Salary", "Flying Pay", "Flying Pay", "Deduction"])
        #expect(snapshot.statements.last?.printedDeductionsMinor == nil)

        let duplicate = salaryPlan(token: setup.sqlite.generationToken, suffix: "duplicate", digest: String(repeating: "a", count: 64), kind: "regular_salary", deductionsPresent: true)
        guard case .exactSourceDuplicate = setup.sqlite.salaryRepo.commitImportedSalary(duplicate) else { Issue.record("Expected exact source duplicate"); return }
        #expect(try setup.sqlite.salaryRepo.snapshot(workspaceId: "workspace-salary").statements.count == 2)

        let invalid = salaryPlan(token: setup.memory.generationToken, suffix: "invalid", digest: String(repeating: "c", count: 64), kind: "regular_salary", deductionsPresent: true, invalidTotal: true)
        #expect(setup.memory.salaryRepo.commitImportedSalary(invalid) == .repositoryIntegrityConflict)
        #expect(try setup.memory.salaryRepo.snapshot(workspaceId: "workspace-salary").statements.count == 2)

        let path = setup.folder.appendingPathComponent("provider.sqlite").path
        try setup.sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path)
        defer { reopened.database.close() }
        #expect(try reopened.salaryRepo.snapshot(workspaceId: "workspace-salary") == snapshot)
        #expect(try reopened.importSessionRepo.importSession(id: "session-first") != nil)
    }

    @Test func fundingPlanSQLiteInMemoryParityAndExactReload() throws {
        let setup = try providers("plan")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        let workspace = WorkspaceDTO(id: "workspace-plan", name: "Plan", createdAtISO: timestamp)
        _ = try setup.sqlite.workspaceRepo.upsertWorkspace(workspace)
        _ = try setup.memory.workspaceRepo.upsertWorkspace(workspace)
        for account in planAccounts() {
            _ = try setup.sqlite.accountRepo.upsertAccount(account)
            _ = try setup.memory.accountRepo.upsertAccount(account)
        }
        let plan = fundingPlan()
        #expect(try setup.sqlite.fundingPlanRepo.savePlan(plan) == plan)
        #expect(try setup.memory.fundingPlanRepo.savePlan(plan) == plan)
        #expect(try setup.sqlite.fundingPlanRepo.plans(workspaceId: workspace.id) == setup.memory.fundingPlanRepo.plans(workspaceId: workspace.id))

        let invalid = FundingPlanDTO(
            id: plan.id, workspaceId: plan.workspaceId, planMonthISO: plan.planMonthISO, rolloverSourcePlanId: nil,
            expectedFixedMinor: 999, expectedFixedDecimal: plan.expectedFixedDecimal, expectedFixedProvenance: "manual",
            expectedVariableMinor: plan.expectedVariableMinor, expectedVariableDecimal: plan.expectedVariableDecimal, expectedVariableProvenance: "manual",
            expectedDeductionsMinor: plan.expectedDeductionsMinor, expectedDeductionsDecimal: plan.expectedDeductionsDecimal, expectedDeductionsProvenance: "manual",
            configuredFeeMinor: plan.configuredFeeMinor, configuredFeeDecimal: plan.configuredFeeDecimal, configuredFeeProvenance: "manual",
            fxINRPerQARDecimal: plan.fxINRPerQARDecimal, fxObservationDateISO: plan.fxObservationDateISO,
            plannedInvestmentMinor: plan.plannedInvestmentMinor, plannedInvestmentDecimal: plan.plannedInvestmentDecimal, plannedInvestmentProvenance: "manual",
            updatedAtISO: plan.updatedAtISO, balances: plan.balances, commitments: plan.commitments)
        #expect(throws: RepositoryError.self) { try setup.sqlite.fundingPlanRepo.savePlan(invalid) }
        #expect(throws: RepositoryError.self) { try setup.memory.fundingPlanRepo.savePlan(invalid) }
        #expect(try setup.sqlite.fundingPlanRepo.plans(workspaceId: workspace.id) == [plan])

        let path = setup.folder.appendingPathComponent("provider.sqlite").path
        try setup.sqlite.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path)
        defer { reopened.database.close() }
        #expect(try reopened.fundingPlanRepo.plans(workspaceId: workspace.id) == [plan])
    }


    @Test func fundingPlanRelationshipIntegrityMatchesAcrossProviders() throws {
        let setup = try providers("plan-integrity")
        defer { setup.sqlite.database.close(); try? FileManager.default.removeItem(at: setup.folder) }
        let primary = WorkspaceDTO(id: "workspace-plan", name: "Plan", createdAtISO: timestamp)
        let other = WorkspaceDTO(id: "workspace-other", name: "Other", createdAtISO: timestamp)
        for workspace in [primary, other] { _ = try setup.sqlite.workspaceRepo.upsertWorkspace(workspace); _ = try setup.memory.workspaceRepo.upsertWorkspace(workspace) }
        for account in planAccounts() + [AccountDTO(id: "outside", workspaceId: other.id, name: "Outside", institutionId: "CBQ", accountType: "bank", nativeCurrency: "QAR", createdAtISO: timestamp)] { _ = try setup.sqlite.accountRepo.upsertAccount(account); _ = try setup.memory.accountRepo.upsertAccount(account) }
        let base = fundingPlan(); #expect(try setup.sqlite.fundingPlanRepo.savePlan(base) == base); #expect(try setup.memory.fundingPlanRepo.savePlan(base) == base)
        let movedMonth = copyPlan(base, planMonthISO: "2026-09"); #expect(throws: RepositoryError.self) { try setup.sqlite.fundingPlanRepo.savePlan(movedMonth) }; #expect(throws: RepositoryError.self) { try setup.memory.fundingPlanRepo.savePlan(movedMonth) }
        let outsideBalance = FundingPlanBalanceDTO(id: "outside-balance", planId: base.id, sourceOrdinal: 1, accountId: "outside", nativeCurrency: "QAR", included: true, amountCurrency: "QAR", amountMinor: 100, amountDecimal: "1.00", provenanceCode: "manual", carriedSourcePlanId: nil, capturedAtISO: nil)
        let crossWorkspace = copyPlan(base, balances: [outsideBalance]); #expect(throws: RepositoryError.self) { try setup.sqlite.fundingPlanRepo.savePlan(crossWorkspace) }; #expect(throws: RepositoryError.self) { try setup.memory.fundingPlanRepo.savePlan(crossWorkspace) }
        let wrongCurrency = FundingPlanBalanceDTO(id: "currency-balance", planId: base.id, sourceOrdinal: 1, accountId: "cbq", nativeCurrency: "INR", included: true, amountCurrency: "INR", amountMinor: 100, amountDecimal: "1.00", provenanceCode: "manual", carriedSourcePlanId: nil, capturedAtISO: nil)
        let currencyMismatch = copyPlan(base, balances: [wrongCurrency]); #expect(throws: RepositoryError.self) { try setup.sqlite.fundingPlanRepo.savePlan(currencyMismatch) }; #expect(throws: RepositoryError.self) { try setup.memory.fundingPlanRepo.savePlan(currencyMismatch) }
        let indiaViaQAR = FundingPlanCommitmentDTO(id: "bad-routing", planId: base.id, regionCode: "india", sourceOrdinal: 1, label: "India", amountCurrency: "INR", amountMinor: 100, amountDecimal: "1.00", included: true, fundingAccountId: "cbq", provenanceCode: "manual", carriedSourcePlanId: nil)
        let routingMismatch = copyPlan(base, commitments: [indiaViaQAR]); #expect(throws: RepositoryError.self) { try setup.sqlite.fundingPlanRepo.savePlan(routingMismatch) }; #expect(throws: RepositoryError.self) { try setup.memory.fundingPlanRepo.savePlan(routingMismatch) }
        let qatarInINR = FundingPlanCommitmentDTO(id: "qatar-in-inr", planId: base.id, regionCode: "qatar", sourceOrdinal: 1, label: "Qatar", amountCurrency: "INR", amountMinor: 100, amountDecimal: "1.00", included: true, fundingAccountId: nil, provenanceCode: "manual", carriedSourcePlanId: nil)
        let qatarCurrencyMismatch = copyPlan(base, commitments: [qatarInINR]); #expect(throws: RepositoryError.self) { try setup.sqlite.fundingPlanRepo.savePlan(qatarCurrencyMismatch) }; #expect(throws: RepositoryError.self) { try setup.memory.fundingPlanRepo.savePlan(qatarCurrencyMismatch) }
        let indiaInQAR = FundingPlanCommitmentDTO(id: "india-in-qar", planId: base.id, regionCode: "india", sourceOrdinal: 1, label: "India", amountCurrency: "QAR", amountMinor: 100, amountDecimal: "1.00", included: true, fundingAccountId: nil, provenanceCode: "manual", carriedSourcePlanId: nil)
        let indiaCurrencyMismatch = copyPlan(base, commitments: [indiaInQAR]); #expect(throws: RepositoryError.self) { try setup.sqlite.fundingPlanRepo.savePlan(indiaCurrencyMismatch) }; #expect(throws: RepositoryError.self) { try setup.memory.fundingPlanRepo.savePlan(indiaCurrencyMismatch) }
        let badCarried = FundingPlanBalanceDTO(id: "carried-balance", planId: base.id, sourceOrdinal: 1, accountId: "cbq", nativeCurrency: "QAR", included: true, amountCurrency: "QAR", amountMinor: 100, amountDecimal: "1.00", provenanceCode: "carried", carriedSourcePlanId: "not-the-rollover-source", capturedAtISO: nil)
        let carriedMismatch = copyPlan(base, rolloverSourcePlanId: "plan-source", balances: [badCarried]); #expect(throws: RepositoryError.self) { try setup.sqlite.fundingPlanRepo.savePlan(carriedMismatch) }; #expect(throws: RepositoryError.self) { try setup.memory.fundingPlanRepo.savePlan(carriedMismatch) }
    }

    @Test func canonicalHydratorPublishesSalaryAndItsImportSessionTogether() throws {
        let provider = InMemoryRepositoryProvider()
        let plan = salaryPlan(token: provider.generationToken, suffix: "hydrate", digest: String(repeating: "d", count: 64), kind: "regular_salary", deductionsPresent: true)
        #expect(isCommitted(provider.salaryRepo.commitImportedSalary(plan)))
        let accounts = AccountStore(), transactions = TransactionStore(), categories = CategoryStore()
        let sessions = ImportSessionStore(), attempts = ImportAttemptStore()
        let salary = SalaryStore(), funding = FundingPlanStore(), cards = CardStore()
        let hydrator = RepositoryStoreHydrator(
            accountRepo: provider.accountRepo, importSessionRepo: provider.importSessionRepo,
            transactionRepo: provider.transactionRepo, categoryRepo: provider.categoryRepo,
            cardRepo: provider.cardRepo, salaryRepo: provider.salaryRepo, fundingPlanRepo: provider.fundingPlanRepo,
            accountStore: accounts, transactionStore: transactions, categoryStore: categories,
            cardStore: cards, salaryStore: salary, fundingPlanStore: funding,
            importSessionStore: sessions, importAttemptStore: attempts,
            workspaceId: "workspace-salary", persistenceState: .intentionalNonDurable(.testMemory),
            providerGeneration: provider.generationToken, categoryReconciliationGate: nil,
            participatesInLifecycleGate: false)
        let staged = try hydrator.stageHydration()
        #expect(salary.statements.isEmpty)
        #expect(sessions.importSessions.isEmpty)
        hydrator.publish(staged)
        #expect(salary.statements.count == 1)
        #expect(salary.statements.first?.evidence.earnings.map(\.sourceLabel) == ["Basic Salary", "Flying Pay", "Flying Pay"])
        #expect(sessions.importSessions.map(\.id) == ["session-hydrate"])
        #expect(attempts.attempts.count == 1)
    }

    private func isCommitted(_ result: SalaryImportRepositoryResult) -> Bool {
        if case .committed = result { return true }
        return false
    }
}

private let timestamp = "2026-08-28T00:00:00Z"

private func temporaryFolder(_ name: String) throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-S79-\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

private func providers(_ name: String) throws -> (sqlite: SQLiteRepositoryProvider, memory: InMemoryRepositoryProvider, folder: URL) {
    let folder = try temporaryFolder(name)
    return (try SQLiteRepositoryProvider(path: folder.appendingPathComponent("provider.sqlite").path), InMemoryRepositoryProvider(), folder)
}

private func salaryPlan(token: ProviderGenerationToken, suffix: String, digest: String, kind: String, deductionsPresent: Bool, invalidTotal: Bool = false) -> SalaryImportPlanDTO {
    let workspace = WorkspaceDTO(id: "workspace-salary", name: "Salary", createdAtISO: timestamp)
    let session = ImportSessionDTO(id: "session-\(suffix)", workspaceId: workspace.id, userVisibleName: "sanitized.pdf", startedAtISO: timestamp, validationStatus: "pending", readerVersion: "PDFDocumentReader", parserVersion: SalaryStatementEvidence.profileVersion, layoutVersion: nil)
    let document = ImportedDocumentDTO(id: "document-\(suffix)", workspaceId: workspace.id, importSessionId: session.id, filename: "sanitized.pdf", mimeType: "application/pdf", sizeBytes: 1, sha256: digest, createdAtISO: timestamp)
    let fingerprint = DocumentFingerprintDTO(id: "fingerprint-\(suffix)", documentId: document.id, importSessionId: session.id, algorithm: DocumentFingerprintDTO.sourceBytesSHA256Algorithm, fingerprint: digest, fingerprintData: nil, isDuplicateAuthority: true, createdAtISO: timestamp)
    let normalized = NormalizedDocumentDTO(id: "normalized-\(suffix)", importSessionId: session.id, documentId: document.id, profileId: SalaryStatementEvidence.profileID, profileVersion: SalaryStatementEvidence.profileVersion)
    let attempt = ImportAttemptDTO(id: "attempt-\(suffix)", workspaceId: workspace.id, createdAtISO: timestamp, outcomeCode: ImportAttemptOutcome.successfulImport.rawValue, coverageCode: ImportAttemptCoverage.evaluatedSupportedOnly.rawValue, accountDecisionCode: ImportAttemptAccountDecision.noFinancialMutation.rawValue, guidanceCode: ImportAttemptGuidance.importCompleted.rawValue, persistenceCode: ImportAttemptPersistence.committed.rawValue, transactionCount: 0, accountId: nil, importSessionId: session.id, documentId: document.id)
    let statementID = "salary-\(suffix)"
    let components = [
        SalaryComponentDTO(id: "e1-\(suffix)", salaryStatementId: statementID, sideCode: "earning", sourceOrdinal: 1, sourceLabel: "Basic Salary", amountCurrency: "QAR", amountMinor: 10000, amountDecimal: "100.00"),
        SalaryComponentDTO(id: "e2-\(suffix)", salaryStatementId: statementID, sideCode: "earning", sourceOrdinal: 2, sourceLabel: "Flying Pay", amountCurrency: "QAR", amountMinor: 2000, amountDecimal: "20.00"),
        SalaryComponentDTO(id: "e3-\(suffix)", salaryStatementId: statementID, sideCode: "earning", sourceOrdinal: 3, sourceLabel: "Flying Pay", amountCurrency: "QAR", amountMinor: 2000, amountDecimal: "20.00")
    ] + (deductionsPresent ? [SalaryComponentDTO(id: "d1-\(suffix)", salaryStatementId: statementID, sideCode: "deduction", sourceOrdinal: 1, sourceLabel: "Deduction", amountCurrency: "QAR", amountMinor: 500, amountDecimal: "5.00")] : [])
    let netMinor: Int64 = deductionsPresent ? 13500 : 14000
    let netDecimal = deductionsPresent ? "135.00" : "140.00"
    let statement = SalaryStatementDTO(id: statementID, workspaceId: workspace.id, documentId: document.id, importSessionId: session.id, normalizedDocumentId: normalized.id, sourceFingerprintAlgorithm: fingerprint.algorithm, sourceFingerprintDigest: fingerprint.fingerprint, sourceAuthorityCode: "qatar_airways", parserProfileId: SalaryStatementEvidence.profileID, parserProfileVersion: SalaryStatementEvidence.profileVersion, financialPeriodISO: "2026-03", printDateISO: "2026-04-02", documentKindCode: kind, nativeCurrency: "QAR", printedEarningsMinor: invalidTotal ? 13999 : 14000, printedEarningsDecimal: "140.00", printedDeductionsMinor: deductionsPresent ? 500 : nil, printedDeductionsDecimal: deductionsPresent ? "5.00" : nil, printedNetMinor: netMinor, printedNetDecimal: netDecimal, printedPaymentMinor: netMinor, printedPaymentDecimal: netDecimal, createdAtISO: timestamp, components: components)
    return SalaryImportPlanDTO(providerGeneration: token, workspace: workspace, history: ConfirmedImportHistoryTemplateDTO(document: document, fingerprint: fingerprint, importSession: session, completedAtISO: timestamp, successfulAttempt: attempt, normalizedDocument: normalized), statement: statement)
}

private func planAccounts() -> [AccountDTO] {
    [
        AccountDTO(id: "cbq", workspaceId: "workspace-plan", name: "CBQ Current", institutionId: "CBQ", accountType: "bank", nativeCurrency: "QAR", createdAtISO: timestamp),
        AccountDTO(id: "axis", workspaceId: "workspace-plan", name: "Axis NRE", institutionId: "Axis", accountType: "bank", nativeCurrency: "INR", createdAtISO: timestamp)
    ]
}


private func copyPlan(_ plan: FundingPlanDTO, planMonthISO: String? = nil, rolloverSourcePlanId: String? = nil, balances: [FundingPlanBalanceDTO]? = nil, commitments: [FundingPlanCommitmentDTO]? = nil) -> FundingPlanDTO {
    FundingPlanDTO(id: plan.id, workspaceId: plan.workspaceId, planMonthISO: planMonthISO ?? plan.planMonthISO, rolloverSourcePlanId: rolloverSourcePlanId ?? plan.rolloverSourcePlanId, expectedFixedMinor: plan.expectedFixedMinor, expectedFixedDecimal: plan.expectedFixedDecimal, expectedFixedProvenance: plan.expectedFixedProvenance, expectedVariableMinor: plan.expectedVariableMinor, expectedVariableDecimal: plan.expectedVariableDecimal, expectedVariableProvenance: plan.expectedVariableProvenance, expectedDeductionsMinor: plan.expectedDeductionsMinor, expectedDeductionsDecimal: plan.expectedDeductionsDecimal, expectedDeductionsProvenance: plan.expectedDeductionsProvenance, configuredFeeMinor: plan.configuredFeeMinor, configuredFeeDecimal: plan.configuredFeeDecimal, configuredFeeProvenance: plan.configuredFeeProvenance, fxINRPerQARDecimal: plan.fxINRPerQARDecimal, fxObservationDateISO: plan.fxObservationDateISO, plannedInvestmentMinor: plan.plannedInvestmentMinor, plannedInvestmentDecimal: plan.plannedInvestmentDecimal, plannedInvestmentProvenance: plan.plannedInvestmentProvenance, updatedAtISO: plan.updatedAtISO, balances: balances ?? plan.balances, commitments: commitments ?? plan.commitments)
}

private func fundingPlan() -> FundingPlanDTO {
    FundingPlanDTO(id: "plan", workspaceId: "workspace-plan", planMonthISO: "2026-08", rolloverSourcePlanId: nil,
        expectedFixedMinor: 100000, expectedFixedDecimal: "1000.00", expectedFixedProvenance: "manual",
        expectedVariableMinor: 20000, expectedVariableDecimal: "200.00", expectedVariableProvenance: "manual",
        expectedDeductionsMinor: 10000, expectedDeductionsDecimal: "100.00", expectedDeductionsProvenance: "manual",
        configuredFeeMinor: 2500, configuredFeeDecimal: "25.00", configuredFeeProvenance: "manual",
        fxINRPerQARDecimal: "22.7500", fxObservationDateISO: "2026-08-28",
        plannedInvestmentMinor: 50000, plannedInvestmentDecimal: "500.00", plannedInvestmentProvenance: "manual", updatedAtISO: timestamp,
        balances: [
            FundingPlanBalanceDTO(id: "balance-q", planId: "plan", sourceOrdinal: 1, accountId: "cbq", nativeCurrency: "QAR", included: true, amountCurrency: "QAR", amountMinor: 200000, amountDecimal: "2000.00", provenanceCode: "captured_account_balance", carriedSourcePlanId: nil, capturedAtISO: timestamp),
            FundingPlanBalanceDTO(id: "balance-i", planId: "plan", sourceOrdinal: 2, accountId: "axis", nativeCurrency: "INR", included: false, amountCurrency: nil, amountMinor: nil, amountDecimal: nil, provenanceCode: "manual", carriedSourcePlanId: nil, capturedAtISO: nil)
        ],
        commitments: [
            FundingPlanCommitmentDTO(id: "commit-q", planId: "plan", regionCode: "qatar", sourceOrdinal: 1, label: "Rent", amountCurrency: "QAR", amountMinor: 100000, amountDecimal: "1000.00", included: true, fundingAccountId: "cbq", provenanceCode: "manual", carriedSourcePlanId: nil),
            FundingPlanCommitmentDTO(id: "commit-i", planId: "plan", regionCode: "india", sourceOrdinal: 1, label: "India", amountCurrency: "INR", amountMinor: 1000000, amountDecimal: "10000.00", included: true, fundingAccountId: "axis", provenanceCode: "manual", carriedSourcePlanId: nil)
        ])
}
