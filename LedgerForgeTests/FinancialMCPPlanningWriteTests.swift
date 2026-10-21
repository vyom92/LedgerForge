import Foundation
import XCTest
@testable import LedgerForge

/// Repository-backed planning writes use invented worksheet values only.
@MainActor
final class FinancialMCPPlanningWriteTests: XCTestCase {
    private let workspace = "mcp-planning-write-mechanics"
    private let month = "2026-10"
    private let timestamp = "2026-10-21T04:00:00Z"

    private func money(_ amount: String, _ currency: String = "QAR") throws -> Money {
        try Money(canonicalDecimal: amount, currency: currency)
    }

    private func plan() throws -> FundingPlan {
        let zero = try money("0.00")
        return try FundingPlan(id: "mcp-existing-plan", workspaceID: workspace,
            month: SelectedStatementMonth(canonical: month),
            expectedFixedEarnings: money("1000.00"), expectedFixedProvenance: .manual,
            expectedVariableEarnings: zero, expectedVariableProvenance: .manual,
            expectedDeductions: zero, expectedDeductionsProvenance: .manual,
            balances: [.init(id: "mcp-qar-balance", accountID: "mcp-qatar", nativeCurrency: CurrencyCode("QAR"),
                included: true, money: money("100.00"), provenance: .manual)],
            qatarCommitments: [.init(id: "mcp-qatar-bill", label: "Existing bill", money: money("100.00"),
                included: true, fundingAccountID: "mcp-qatar", provenance: .manual)],
            indiaCommitments: [], configuredTransferFee: zero, configuredTransferFeeProvenance: .manual,
            planningFX: FundingPlanFX(inrPerQAR: 3, observationDate: StatementDate(canonical: "2026-10-18")),
            plannedInvestment: zero, plannedInvestmentProvenance: .manual, updatedAtISO: timestamp,
            calculationVersion: .budgetV1, keepInCBQ: zero, referenceMode: .manual,
            assistance: .init(workspaceID: workspace, month: month))
    }

    private func prepare(_ provider: DatabaseProvider, store: FundingPlanStore,
                         initial: FundingPlan? = nil) throws {
        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: workspace, name: "Planning write mechanics", createdAtISO: timestamp))
        _ = try provider.accountRepo.upsertAccount(.init(id: "mcp-qatar", workspaceId: workspace,
            name: "Planning bank", institutionId: nil, accountType: "bank", nativeCurrency: "QAR",
            createdAtISO: timestamp))
        try provider.intelligenceRepo.applyPlanning(.preferences(
            .init(workspaceID: workspace, retentionAccountID: "mcp-qatar"), replacing: nil))
        _ = try provider.fundingPlanRepo.savePlan((initial ?? plan()).persistenceDTO())
        try hydrate(provider, store: store)
    }

    private func hydrate(_ provider: DatabaseProvider, store: FundingPlanStore) throws {
        let plans = try provider.fundingPlanRepo.plans(workspaceId: workspace).map { try $0.allocationCalculationInput() }
        let raw = try provider.fundingPlanRepo.scratchpads(workspaceId: workspace).map(MonthlyPlanScratchpad.decode)
        let revision = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision
        store.installWithoutObservation(plans, generation: provider.generationToken,
            scratchpads: raw, monthRevisions: [revision])
        store.notifyInstalledValue()
    }

    private func revision(_ provider: DatabaseProvider) throws -> String {
        try XCTUnwrap(provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).writeRevision)
    }

    private func request(_ revision: String, requestID: String = UUID().uuidString.lowercased(),
                         field: String = "expected_fixed", decimal: String = "1100.00") throws -> PlanningChangeRequest {
        let body: [String: Any] = [
            "request_id": requestID, "workspace_id": workspace, "month": month,
            "plan_id": "mcp-existing-plan", "expected_write_revision": revision,
            "changes": [["type": "monthly_amount", "field": field,
                         "amount": ["currency": "QAR", "decimal": decimal]]]
        ]
        return try PlanningChangeRequest.decode(JSONSerialization.data(withJSONObject: body))
    }

    private func withProviders(_ run: (String, DatabaseProvider) throws -> Void) throws {
        try run("in-memory", DatabaseProvider(inMemory: true))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-planning-write-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let sqlite = try SQLiteRepositoryProvider(path: root.appendingPathComponent("isolated.sqlite").path)
        defer { sqlite.database.close() }
        try run("SQLite", .verifiedSQLite(sqlite))
    }

    func testSavedWriteHydratesReadbackAndRetryAfterManualEditReturnsHistoricalReceipt() throws {
        try withProviders { label, provider in
            let store = FundingPlanStore()
            try prepare(provider, store: store)
            let initial = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            let initialFinancial = initial.financial
            let initialAccounts = initial.accounts
            let initialRevision = try XCTUnwrap(initial.writeRevision)
            let service = FinancialMCPPlanningWriteService(provider: { provider }, store: store,
                hydrate: { try self.hydrate($0, store: store) }, now: { ISO8601DateFormatter().date(from: self.timestamp)! })
            let context = service.writeContext(workspaceID: workspace, month: try SelectedStatementMonth(canonical: month),
                saved: try plan(), retained: nil)
            XCTAssertEqual(context["state"] as? String, "available", label)
            XCTAssertEqual(context["write_revision"] as? String, initialRevision, label)
            let command = try request(initialRevision)
            let applied = service.apply(command)
            XCTAssertEqual(applied["outcome"] as? String, "applied", "\(label): \(applied)")
            XCTAssertEqual(applied["replayed"] as? Bool, false, label)
            XCTAssertEqual((applied["canonical_readback"] as? [String: Any])?["state"] as? String, "verified", label)
            let committed = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            XCTAssertEqual(committed.monthRevision.latestOrigin, .chatgpt, label)
            XCTAssertEqual(committed.financial, initialFinancial, label)
            XCTAssertEqual(committed.accounts, initialAccounts, label)
            XCTAssertEqual(try committed.plan?.allocationCalculationInput().expectedFixedEarnings, try money("1100.00"), label)
            XCTAssertEqual(try provider.fundingPlanRepo.planningRequestReceipt(requestID: command.requestID)?.committedRevision,
                           committed.monthRevision.counter, label)

            var native = try XCTUnwrap(committed.plan).allocationCalculationInput()
            native.expectedVariableEarnings = try money("25.00")
            native.expectedVariableProvenance = .manual
            _ = try provider.fundingPlanRepo.savePlan(native.persistenceDTO(), expected: committed.monthRevision, origin: .manual)
            try hydrate(provider, store: store)
            let afterManual = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            let replay = service.apply(command)
            XCTAssertEqual(replay["outcome"] as? String, "applied", "\(label): \(replay)")
            XCTAssertEqual(replay["replayed"] as? Bool, true, label)
            XCTAssertEqual(replay["committed_month_revision"] as? String, String(committed.monthRevision.counter), label)
            let afterReplay = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            XCTAssertEqual(afterReplay.monthRevision, afterManual.monthRevision, label)
            XCTAssertEqual(try afterReplay.plan?.allocationCalculationInput().expectedVariableEarnings, try money("25.00"), label)
            XCTAssertEqual(try afterReplay.plan?.allocationCalculationInput().expectedFixedEarnings, try money("1100.00"), label)
        }
    }

    func testNoOpReceiptDoesNotAdvanceRevisionAndConflictingRetryIsRejected() throws {
        try withProviders { label, provider in
            let store = FundingPlanStore(); try prepare(provider, store: store)
            let baseline = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            let service = FinancialMCPPlanningWriteService(provider: { provider }, store: store,
                hydrate: { try self.hydrate($0, store: store) })
            let id = UUID().uuidString.lowercased()
            let command = try request(try XCTUnwrap(baseline.writeRevision), requestID: id, decimal: "1000.00")
            let unchanged = service.apply(command)
            XCTAssertEqual(unchanged["outcome"] as? String, "no_change", "\(label): \(unchanged)")
            let after = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            XCTAssertEqual(after.monthRevision, baseline.monthRevision, label)
            XCTAssertNotNil(try provider.fundingPlanRepo.planningRequestReceipt(requestID: id), label)
            let conflict = service.apply(try request(try XCTUnwrap(baseline.writeRevision), requestID: id, decimal: "1001.00"))
            XCTAssertEqual((conflict["error"] as? [String: Any])?["code"] as? String, "request_id_conflict", label)
            XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision,
                           baseline.monthRevision, label)
        }
    }

    func testTwoDistinctRequestsFromOneContextPublishOnlyTheFirstAndIdenticalReplayPublishesOnce() throws {
        try withProviders { label, provider in
            let store = FundingPlanStore(); try prepare(provider, store: store)
            let service = FinancialMCPPlanningWriteService(provider: { provider }, store: store,
                hydrate: { try self.hydrate($0, store: store) })
            let baseline = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            let sameRevision = try XCTUnwrap(baseline.writeRevision)
            let first = try request(sameRevision, decimal: "1100.00")
            let competing = try request(sameRevision, field: "expected_variable", decimal: "25.00")

            let accepted = service.apply(first)
            XCTAssertEqual(accepted["outcome"] as? String, "applied", "\(label): \(accepted)")
            let afterFirst = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            let rejected = service.apply(competing)
            XCTAssertEqual((rejected["error"] as? [String: Any])?["code"] as? String,
                           "stale_revision", "\(label): \(rejected)")
            XCTAssertNil(try provider.fundingPlanRepo.planningRequestReceipt(requestID: competing.requestID), label)
            let replay = service.apply(first)
            XCTAssertEqual(replay["outcome"] as? String, "applied", "\(label): \(replay)")
            XCTAssertEqual(replay["replayed"] as? Bool, true, label)
            XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision,
                           afterFirst.monthRevision, label)
            XCTAssertEqual(afterFirst.monthRevision.counter, baseline.monthRevision.counter + 1, label)
            XCTAssertEqual(try afterFirst.plan?.allocationCalculationInput().expectedVariableEarnings, try money("0.00"), label)
        }
    }

    func testRejectedOverCapacityKeepLeavesCanonicalFinancialAndHoldingTablesUntouched() throws {
        try withProviders { label, provider in
            let store = FundingPlanStore(); try prepare(provider, store: store)
            let service = FinancialMCPPlanningWriteService(provider: { provider }, store: store,
                hydrate: { try self.hydrate($0, store: store) })
            let baseline = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            let beforePlans = try provider.fundingPlanRepo.plans(workspaceId: workspace)
            let beforeDrafts = try provider.fundingPlanRepo.scratchpads(workspaceId: workspace)
            let beforeTransactions = try provider.transactionRepo.transactions(workspaceId: workspace, importSessionId: nil)
            let beforeInvestments = try provider.investmentRepo.snapshot(workspaceID: workspace)
            let beforeMetadata = try provider.intelligenceRepo.snapshot(workspaceID: workspace)
            let beforeAccounts = try provider.accountRepo.accounts(workspaceId: workspace)
            let command = try request(try XCTUnwrap(baseline.writeRevision), field: "keep_in_cbq", decimal: "100000.00")

            let rejected = service.apply(command)
            XCTAssertEqual(rejected["outcome"] as? String, "rejected", "\(label): \(rejected)")
            XCTAssertEqual((rejected["error"] as? [String: Any])?["code"] as? String,
                           "insufficient_capacity", label)
            XCTAssertNil(try provider.fundingPlanRepo.planningRequestReceipt(requestID: command.requestID), label)
            XCTAssertEqual(try provider.fundingPlanRepo.plans(workspaceId: workspace), beforePlans, label)
            XCTAssertEqual(try provider.fundingPlanRepo.scratchpads(workspaceId: workspace), beforeDrafts, label)
            XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision,
                           baseline.monthRevision, label)
            XCTAssertEqual(try provider.transactionRepo.transactions(workspaceId: workspace, importSessionId: nil),
                           beforeTransactions, label)
            XCTAssertEqual(try provider.investmentRepo.snapshot(workspaceID: workspace), beforeInvestments, label)
            XCTAssertEqual(try provider.intelligenceRepo.snapshot(workspaceID: workspace), beforeMetadata, label)
            XCTAssertEqual(try provider.accountRepo.accounts(workspaceId: workspace), beforeAccounts, label)
        }
    }

    func testStaleRevisionAndRetainedDraftRejectWithoutPublishing() throws {
        try withProviders { label, provider in
            let store = FundingPlanStore(); try prepare(provider, store: store)
            let service = FinancialMCPPlanningWriteService(provider: { provider }, store: store,
                hydrate: { try self.hydrate($0, store: store) })
            let baseline = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            var changed = try XCTUnwrap(baseline.plan).allocationCalculationInput()
            changed.expectedVariableEarnings = try money("10.00")
            _ = try provider.fundingPlanRepo.savePlan(changed.persistenceDTO(), expected: baseline.monthRevision, origin: .manual)
            try hydrate(provider, store: store)
            let stale = service.apply(try request(try XCTUnwrap(baseline.writeRevision)))
            XCTAssertEqual((stale["error"] as? [String: Any])?["code"] as? String, "stale_revision", "\(label): \(stale)")
            let current = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            XCTAssertNil(try provider.fundingPlanRepo.planningRequestReceipt(requestID: stale["request_id"] as! String), label)

            var raw = MonthlyPlanScratchpad(plan: changed, canonical: changed,
                rawText: ["fixed": "1000."], fieldErrors: ["fixed": "Finish entering the amount."],
                untouchedZeroFields: [], unavailableBalanceAccountIDs: [], preReductionBasis: [:], excludedRecurringOccurrenceIDs: [])
            raw.plan = changed
            _ = try provider.fundingPlanRepo.saveScratchpad(raw.dto(), expected: current.monthRevision)
            try hydrate(provider, store: store)
            let retained = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            let blocked = service.apply(try request(try XCTUnwrap(retained.writeRevision)))
            XCTAssertEqual((blocked["error"] as? [String: Any])?["code"] as? String, "draft_conflict", "\(label): \(blocked)")
            XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).scratchpad,
                           retained.scratchpad, label)
            XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision,
                           retained.monthRevision, label)
        }
    }

    func testCommitSurvivesHydrationFailureAndIdenticalRetryRecovers() throws {
        try withProviders { label, provider in
            let store = FundingPlanStore(); try prepare(provider, store: store)
            var failHydration = true
            let service = FinancialMCPPlanningWriteService(provider: { provider }, store: store,
                hydrate: { active in
                    if failHydration { throw PlanningWriteError.unavailableContext }
                    try self.hydrate(active, store: store)
                })
            let command = try request(revision(provider))
            let committed = service.apply(command)
            XCTAssertEqual(committed["outcome"] as? String, "committed_refresh_needed", "\(label): \(committed)")
            let afterCommit = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            XCTAssertEqual(try afterCommit.plan?.allocationCalculationInput().expectedFixedEarnings, try money("1100.00"), label)
            XCTAssertNotNil(try provider.fundingPlanRepo.planningRequestReceipt(requestID: command.requestID), label)
            failHydration = false
            let recovered = service.apply(command)
            XCTAssertEqual(recovered["outcome"] as? String, "applied", "\(label): \(recovered)")
            XCTAssertEqual(recovered["replayed"] as? Bool, true, label)
            XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision,
                           afterCommit.monthRevision, label)
        }
    }

    func testLegacyCanonicalPlanIsOutsideWriteScope() throws {
        try withProviders { label, provider in
            var legacy = try plan()
            legacy.calculationVersion = .legacy
            legacy.keepInCBQ = nil
            legacy.referenceMode = .alDar
            legacy.planningFX = nil
            let store = FundingPlanStore()
            try prepare(provider, store: store, initial: legacy)
            let service = FinancialMCPPlanningWriteService(provider: { provider }, store: store,
                hydrate: { try self.hydrate($0, store: store) })
            let context = service.writeContext(workspaceID: workspace, month: legacy.month, saved: legacy, retained: nil)
            XCTAssertEqual(context["state"] as? String, "unavailable", label)
            let baseline = try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month)
            let response = service.apply(try request(try XCTUnwrap(baseline.writeRevision)))
            XCTAssertEqual((response["error"] as? [String: Any])?["code"] as? String,
                           "unsupported_scope", "\(label): \(response)")
            XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspace, month: month).monthRevision,
                           baseline.monthRevision, label)
        }
    }

    func testInvalidatedProviderCannotPublishAPlanningWrite() throws {
        let provider = DatabaseProvider(inMemory: true)
        let store = FundingPlanStore()
        try prepare(provider, store: store)
        let command = try request(revision(provider))
        let service = FinancialMCPPlanningWriteService(provider: { provider }, store: store,
            hydrate: { try self.hydrate($0, store: store) })
        provider.invalidateGeneration()
        let response = service.apply(command)
        XCTAssertEqual(response["outcome"] as? String, "unavailable")
        XCTAssertEqual(response["prior_attempt_status"] as? String, "unknown")
        XCTAssertEqual(store.plan(for: try SelectedStatementMonth(canonical: month), workspaceID: workspace), try plan())
    }
}
