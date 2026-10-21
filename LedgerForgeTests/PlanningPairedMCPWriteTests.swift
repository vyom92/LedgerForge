import Foundation
import XCTest
@testable import LedgerForge

/// Synthetic planning values exercise the paired publication path without source statements.
@MainActor
final class PlanningPairedMCPWriteTests: XCTestCase {
    private let workspace = "paired-mcp-write-fixture"
    private let month = "2026-10"
    private let timestamp = "2026-10-21T00:00:00Z"

    private func plan() throws -> FundingPlan {
        let zero = try Money(canonicalDecimal: "0.00", currency: "QAR")
        return try FundingPlan(id: "paired-existing-plan", workspaceID: workspace,
            month: SelectedStatementMonth(canonical: month),
            expectedFixedEarnings: Money(canonicalDecimal: "100.00", currency: "QAR"),
            expectedFixedProvenance: .manual, expectedVariableEarnings: zero,
            expectedVariableProvenance: .manual, expectedDeductions: zero,
            expectedDeductionsProvenance: .manual, balances: [], qatarCommitments: [],
            indiaCommitments: [], configuredTransferFee: zero,
            configuredTransferFeeProvenance: .manual,
            planningFX: FundingPlanFX(inrPerQAR: 3,
                observationDate: StatementDate(canonical: "2026-10-18")),
            plannedInvestment: zero, plannedInvestmentProvenance: .manual,
            updatedAtISO: timestamp, calculationVersion: .budgetV1,
            keepInCBQ: zero, referenceMode: .manual)
    }

    private func hydrate(_ provider: DatabaseProvider, store: FundingPlanStore) throws {
        let plans = try provider.fundingPlanRepo.plans(workspaceId: workspace)
            .map { try $0.allocationCalculationInput() }
        let raw = try provider.fundingPlanRepo.scratchpads(workspaceId: workspace)
            .map(MonthlyPlanScratchpad.decode)
        let revision = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: workspace, month: month).monthRevision
        store.installWithoutObservation(plans, generation: provider.generationToken,
            scratchpads: raw, monthRevisions: [revision])
        store.notifyInstalledValue()
    }

    private func request(_ writeRevision: String) throws -> PlanningChangeRequest {
        let body: [String: Any] = [
            "request_id": UUID().uuidString.lowercased(), "workspace_id": workspace,
            "month": month, "plan_id": "paired-existing-plan",
            "expected_write_revision": writeRevision,
            "changes": [["type": "monthly_amount", "field": "expected_fixed",
                         "amount": ["currency": "QAR", "decimal": "200.00"]]]
        ]
        return try PlanningChangeRequest.decode(JSONSerialization.data(withJSONObject: body))
    }

    func testActualServiceApplyPublishesPairedMonthWithRetainedLocalesAndOneRevision() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LedgerForge-paired-mcp-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sqlite = try SQLiteRepositoryProvider(
            path: directory.appendingPathComponent("ledger.sqlite").path)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        let original = try plan()
        let raw = MonthlyPlanScratchpad(plan: original, canonical: original,
            rawText: ["fixed": "100,00", "fee": "0,00"], fieldErrors: [:],
            untouchedZeroFields: [], unavailableBalanceAccountIDs: [],
            preReductionBasis: [:], excludedRecurringOccurrenceIDs: [])
        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace,
            name: "Paired planning test", createdAtISO: timestamp))
        _ = try provider.accountRepo.upsertAccount(.init(id: "planning-bank", workspaceId: workspace,
            name: "Planning bank", accountType: "bank", nativeCurrency: "QAR",
            createdAtISO: timestamp))
        try provider.intelligenceRepo.applyPlanning(.preferences(
            .init(workspaceID: workspace, retentionAccountID: "planning-bank"), replacing: nil))
        _ = try provider.fundingPlanRepo.savePlan(original.persistenceDTO(), retaining: raw.dto())

        let session = CompanionSyncSessionDTO(sessionID: UUID().uuidString,
            workspaceID: workspace,
            activationEpoch: try provider.fundingPlanRepo.companionActivationEpoch(),
            phoneID: UUID().uuidString, protocolVersion: 1, disposition: "active")
        try provider.fundingPlanRepo.createCompanionSession(session)
        let scope = session.scope(month: month)
        let lexical = PlannerLexicalContext(defaultLocaleIdentifier: nil,
            localeIdentifiersByField: ["fixed": "de_DE", "fee": "de_DE"])
        let metadata = MonthlyPlanSyncAdapter.metadata(for: raw,
            lexicalContext: lexical, retaining: .init())
        let context = try CompanionMacMonthContext.make(scratchpad: raw, metadata: metadata,
            accounts: [.init(repositoryAccountId: "planning-bank", workspaceId: workspace,
                name: "Planning bank", type: .bank, nativeCurrency: CurrencyCode("QAR"),
                status: .active, preferredDisplayName: "Planning bank",
                selectionContext: "Local test")],
            manuallyExcludedPlanningAccountIDs: [], receiptTransactions: [],
            latestAlDarQuote: nil, selectedHistoryAccountIDs: [])
        let firstBinding = try context.binding(for: scope)
        let anchor = CompanionMonthAnchor(scratchpad: raw,
            metadata: firstBinding.baselineMetadata,
            bankCurrencies: context.bankCurrencies,
            fundingAccountIDs: context.fundingAccountIDs,
            excludedHistoryAccountIDs: context.excludedHistoryAccountIDs,
            context: context.context)
        let binding = try anchor.binding(for: scope)
        let initialRevision = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: workspace, month: month).monthRevision
        let initialized = try provider.fundingPlanRepo.commitCompanionMonth(.init(
            sessionID: session.sessionID, workspaceID: workspace, month: month,
            expectedActivationEpoch: session.activationEpoch, expectedStateRevision: nil,
            expectedMonthRevision: initialRevision, expectedScratchpad: raw.dto(),
            editor: raw.dto(), canonical: nil, binding: binding,
            metadata: anchor.metadata, operation: .initialize(binding.baselineDocument),
            currentAnchor: anchor))
        XCTAssertEqual(initialized.disposition, .initialized)

        let store = FundingPlanStore()
        try hydrate(provider, store: store)
        let before = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: workspace, month: month)
        let originalPaired = try XCTUnwrap(before.companionMonth)
        let oldAnchor = try originalPaired.decodedEnvelope(session: session).current
        XCTAssertEqual(MonthlyPlanSyncAdapter.lexicalContext(from: oldAnchor.metadata)
            .localeIdentifiersByField["fee"], "de_DE")
        let command = try request(try XCTUnwrap(before.writeRevision))
        let service = FinancialMCPPlanningWriteService(provider: { provider }, store: store,
            hydrate: { try self.hydrate($0, store: store) },
            now: { ISO8601DateFormatter().date(from: self.timestamp)! },
            inputLocale: Locale(identifier: "de_DE"))

        // A late receipt failure must roll back the canonical, raw, paired and
        // revision writes together; the same request can then succeed once.
        try sqlite.database.execute(sql: """
            CREATE TRIGGER paired_mcp_receipt_abort BEFORE INSERT ON planning_request_receipts
            BEGIN SELECT RAISE(ABORT, 'injected receipt failure'); END;
            """)
        let rejected = service.apply(command)
        XCTAssertEqual(rejected["outcome"] as? String, "rejected")
        try sqlite.database.execute(sql: "DROP TRIGGER paired_mcp_receipt_abort;")
        let afterFailure = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: workspace, month: month)
        XCTAssertEqual(afterFailure.plan, before.plan)
        XCTAssertEqual(afterFailure.scratchpad, before.scratchpad)
        XCTAssertEqual(afterFailure.monthRevision, before.monthRevision)
        XCTAssertEqual(afterFailure.companionMonth, before.companionMonth)
        XCTAssertNil(try provider.fundingPlanRepo.planningRequestReceipt(requestID: command.requestID))

        let applied = service.apply(command)
        XCTAssertEqual(applied["outcome"] as? String, "applied", "\(applied)")
        let after = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: workspace, month: month)
        let retained = try MonthlyPlanScratchpad.decode(XCTUnwrap(after.scratchpad))
        let paired = try XCTUnwrap(after.companionMonth)
        let published = try paired.decodedEnvelope(session: session).current
        let publishedLocales = MonthlyPlanSyncAdapter.lexicalContext(from: published.metadata)
        XCTAssertEqual(try after.plan?.allocationCalculationInput().expectedFixedEarnings,
            try Money(canonicalDecimal: "200.00", currency: "QAR"))
        XCTAssertEqual(after.monthRevision.counter, before.monthRevision.counter + 1)
        XCTAssertEqual(after.monthRevision.latestOrigin, .chatgpt)
        XCTAssertEqual(paired.stateRevision, originalPaired.stateRevision + 1)
        XCTAssertEqual(retained.rawText["fixed"], "200.00")
        XCTAssertEqual(retained.rawText["fee"], "0,00")
        XCTAssertEqual(published.scratchpad, retained)
        XCTAssertEqual(publishedLocales.localeIdentifiersByField["fixed"], "en_US_POSIX")
        XCTAssertEqual(publishedLocales.localeIdentifiersByField["fee"], "de_DE")
        XCTAssertEqual(try provider.fundingPlanRepo.planningRequestReceipt(requestID: command.requestID)?
            .committedRevision, after.monthRevision.counter)

        let replay = service.apply(command)
        XCTAssertEqual(replay["outcome"] as? String, "applied")
        XCTAssertEqual(replay["replayed"] as? Bool, true)
        XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: workspace, month: month).monthRevision, after.monthRevision)
        XCTAssertEqual(try provider.fundingPlanRepo.companionMonth(
            sessionID: session.sessionID, workspaceID: workspace, month: month), paired)
    }
}
